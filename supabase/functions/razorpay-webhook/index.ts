// AllPics · razorpay-webhook
//
// Razorpay server webhook. The HMAC signature IS the authentication — no
// client tokens are involved. Idempotent by razorpay_order_id.
//
// payment.captured → mark payment captured, upgrade the event's quota and
//                    expiry from the purchased plan, issue an invoice number.
// payment.failed   → mark payment failed.

import { createClient } from "npm:@supabase/supabase-js@2";
import { errorResponse, jsonResponse } from "../_shared/http.ts";

async function verifySignature(
  body: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  // Constant-time comparison
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405);
  }

  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  if (!secret) {
    return errorResponse("not_configured", "Webhook not configured.", 503);
  }

  const signature = req.headers.get("x-razorpay-signature") ?? "";
  const rawBody = await req.text();
  if (!signature || !(await verifySignature(rawBody, signature, secret))) {
    return errorResponse("unauthorized", "Invalid signature.", 401);
  }

  let payload: {
    event?: string;
    payload?: { payment?: { entity?: Record<string, unknown> } };
  };
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return errorResponse("bad_request", "Invalid JSON.", 400);
  }

  const eventType = payload.event;
  const payment = payload.payload?.payment?.entity as
    | {
      id?: string;
      order_id?: string;
      status?: string;
    }
    | undefined;
  if (!eventType || !payment?.order_id) {
    return jsonResponse({ ok: true, ignored: true });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: row } = await admin
    .from("payments")
    .select("id, event_id, plan_id, status")
    .eq("razorpay_order_id", payment.order_id)
    .maybeSingle();
  if (!row) {
    console.warn("webhook for unknown order", payment.order_id);
    return jsonResponse({ ok: true, ignored: true });
  }

  if (eventType === "payment.failed") {
    if (row.status === "created" || row.status === "authorized") {
      await admin
        .from("payments")
        .update({ status: "failed", razorpay_payment_id: payment.id })
        .eq("id", row.id);
    }
    return jsonResponse({ ok: true });
  }

  if (eventType !== "payment.captured") {
    return jsonResponse({ ok: true, ignored: true });
  }

  // ---- Idempotency: only the first captured webhook applies the upgrade ----
  if (row.status === "captured") {
    return jsonResponse({ ok: true, idempotent: true });
  }

  const { data: plan } = await admin
    .from("plans")
    .select("photo_limit, storage_days")
    .eq("id", row.plan_id)
    .single();

  const invoiceNumber = `AP-${new Date().getFullYear()}-${
    (row.id as string).replaceAll("-", "").slice(0, 8).toUpperCase()
  }`;

  const { error: payError } = await admin
    .from("payments")
    .update({
      status: "captured",
      razorpay_payment_id: payment.id,
      invoice_number: invoiceNumber,
    })
    .eq("id", row.id)
    .neq("status", "captured"); // guard against concurrent delivery
  if (payError) {
    console.error("payment update failed", payError);
    return errorResponse("internal", "Could not record the payment.", 500);
  }

  // ---- Apply the upgrade: new quota + expiry extended from now ----
  const newExpiry = new Date(
    Date.now() + plan.storage_days * 24 * 60 * 60 * 1000,
  ).toISOString();
  const { error: eventError } = await admin
    .from("events")
    .update({
      plan_id: row.plan_id,
      photo_limit: plan.photo_limit,
      expires_at: newExpiry,
      status: "active", // an expired event revives on upgrade
    })
    .eq("id", row.event_id);
  if (eventError) {
    console.error("event upgrade failed", eventError);
    return errorResponse("internal", "Could not apply the upgrade.", 500);
  }

  return jsonResponse({ ok: true, invoice_number: invoiceNumber });
});
