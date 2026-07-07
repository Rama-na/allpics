// AllPics · event-expiry
//
// Scheduled daily. Marks past-expiry events `expired` and creates
// "album expiring soon" notifications (deduped in SQL, once per day).
//
// Auth: requires the service-role key (scheduled invocations only).

import { createClient } from "npm:@supabase/supabase-js@2";
import { errorResponse, jsonResponse } from "../_shared/http.ts";

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

  const { data: expired, error: expireError } = await admin.rpc(
    "expire_events",
  );
  if (expireError) {
    console.error("expire_events failed", expireError);
    return errorResponse("internal", "Expiry sweep failed.", 500);
  }

  const { data: warned, error: warnError } = await admin.rpc(
    "notify_expiring_events",
  );
  if (warnError) {
    console.error("notify_expiring_events failed", warnError);
    return errorResponse("internal", "Expiry warnings failed.", 500);
  }

  return jsonResponse({ ok: true, expired, warned });
});
