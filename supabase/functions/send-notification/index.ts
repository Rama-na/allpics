// AllPics · send-notification
//
// Scheduled fan-out (cron: every minute). Sends FCM pushes for notification
// rows that have not been pushed yet, then stamps `pushed_at`.
//
// FCM uses the HTTP v1 API with a service-account JSON stored in the
// FCM_SERVICE_ACCOUNT_JSON secret. When the secret is absent the function
// still stamps rows (in-app realtime delivery already happened) so nothing
// backs up — fully modular until Firebase is provisioned.
//
// Auth: requires the service-role key (scheduled invocations only).

import { createClient } from "npm:@supabase/supabase-js@2";
import { errorResponse, jsonResponse } from "../_shared/http.ts";

const BATCH = 100;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  const claims = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");

  const pem = sa.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\n", "");
  const keyData = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const jwt = `${header}.${claims}.${
    btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")
  }`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`token exchange failed: ${await res.text()}`);
  return (await res.json()).access_token as string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405);
  }
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const provided = (req.headers.get("Authorization") ?? "").replace(
    "Bearer ",
    "",
  );
  if (provided !== serviceKey) {
    return errorResponse("unauthorized", "Service key required.", 401);
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serviceKey);

  const { data: rows } = await admin
    .from("notifications")
    .select("id, user_id, type, title, body, data")
    .is("pushed_at", null)
    .order("created_at")
    .limit(BATCH);
  if (!rows || rows.length === 0) {
    return jsonResponse({ ok: true, pushed: 0 });
  }

  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  let pushed = 0;

  if (saRaw) {
    const sa = JSON.parse(saRaw) as ServiceAccount;
    const accessToken = await getAccessToken(sa);

    // Resolve tokens for the affected users in one query.
    const userIds = [...new Set(rows.map((r) => r.user_id))];
    const { data: profiles } = await admin
      .from("profiles")
      .select("id, fcm_token")
      .in("id", userIds)
      .not("fcm_token", "is", null);
    const tokens = new Map(
      (profiles ?? []).map((p) => [p.id as string, p.fcm_token as string]),
    );

    for (const row of rows) {
      const token = tokens.get(row.user_id);
      if (!token) continue;
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: row.title, body: row.body },
              data: Object.fromEntries(
                Object.entries(row.data ?? {}).map(([k, v]) => [k, String(v)]),
              ),
            },
          }),
        },
      );
      if (res.ok) {
        pushed++;
      } else if (res.status === 404 || res.status === 410) {
        // Stale token — clear it so we stop trying.
        await admin
          .from("profiles")
          .update({ fcm_token: null })
          .eq("id", row.user_id);
      } else {
        console.error("fcm send failed", row.id, await res.text());
      }
    }
  }

  // Stamp every row: in-app delivery already happened via Realtime.
  await admin
    .from("notifications")
    .update({ pushed_at: new Date().toISOString() })
    .in("id", rows.map((r) => r.id));

  return jsonResponse({ ok: true, processed: rows.length, pushed });
});
