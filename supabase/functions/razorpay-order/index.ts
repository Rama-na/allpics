// AllPics · razorpay-order
//
// Creates a Razorpay order for a plan purchase. Host-only.
//   1. caller must own the event
//   2. plan must exist, be active, and be a paid plan
//   3. creates a Razorpay order (server-side secret) and a `payments` row
//
// The client never sees the Razorpay secret — only the public key id.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405);
  }

  let body: { event_id?: string; plan_code?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("bad_request", "Invalid JSON body.", 400);
  }
  const { event_id, plan_code } = body;
  if (!event_id || !plan_code) {
    return errorResponse(
      "bad_request",
      "event_id and plan_code are required.",
      400,
    );
  }

  // ---- Identify caller ----
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user || userData.user.is_anonymous) {
    return errorResponse("unauthorized", "Host sign-in required.", 401);
  }
  const userId = userData.user.id;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // ---- Ownership ----
  const { data: event } = await admin
    .from("events")
    .select("id, host_id, title, status")
    .eq("id", event_id)
    .maybeSingle();
  if (!event || event.host_id !== userId) {
    return errorResponse("forbidden", "You do not own this event.", 403);
  }
  if (event.status === "deleted") {
    return errorResponse("bad_request", "This event was deleted.", 400);
  }

  // ---- Plan ----
  const { data: plan } = await admin
    .from("plans")
    .select("id, code, name, price_inr, photo_limit, storage_days, is_active")
    .eq("code", plan_code)
    .maybeSingle();
  if (!plan || !plan.is_active) {
    return errorResponse("bad_request", "Unknown plan.", 400);
  }
  if (plan.price_inr <= 0) {
    return errorResponse("bad_request", "The free plan cannot be purchased.", 400);
  }

  // ---- Razorpay order ----
  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) {
    return errorResponse(
      "not_configured",
      "Payments are not configured yet.",
      503,
    );
  }

  const receipt = crypto.randomUUID();
  const orderRes = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
    },
    body: JSON.stringify({
      amount: plan.price_inr,
      currency: "INR",
      receipt,
      notes: { event_id, plan_code, user_id: userId },
    }),
  });
  if (!orderRes.ok) {
    console.error("razorpay order failed", await orderRes.text());
    return errorResponse("internal", "Could not start the payment.", 502);
  }
  const order = await orderRes.json();

  // ---- Persist the payment lifecycle row ----
  const { error: insertError } = await admin.from("payments").insert({
    event_id,
    host_id: userId,
    plan_id: plan.id,
    razorpay_order_id: order.id,
    amount_inr: plan.price_inr,
    currency: "INR",
    status: "created",
  });
  if (insertError) {
    console.error("payments insert failed", insertError);
    return errorResponse("internal", "Could not start the payment.", 500);
  }

  return jsonResponse({
    order_id: order.id,
    amount: plan.price_inr,
    currency: "INR",
    key_id: keyId,
    plan_name: plan.name,
    event_title: event.title,
  });
});
