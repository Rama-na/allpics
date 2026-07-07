// AllPics · create-upload-url
//
// Issues a signed upload URL for a guest's photo/video after validating:
//   1. caller has a valid session (anonymous guest or host)
//   2. caller is a non-banned guest of the event
//   3. event is active and not expired
//   4. event quota has room (photos + videos vs photo_limit)
//   5. mime type is allowed and size within caps
//   6. per-guest rate limit (uploads requested in the last minute)
//
// On success: inserts a `pending` uploads row (the DB trigger re-checks the
// quota under a row lock — race-safe) and returns a signed upload URL.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/http.ts";

const ALLOWED_MIME: Record<string, { kind: "photo" | "video"; ext: string }> = {
  "image/jpeg": { kind: "photo", ext: "jpg" },
  "image/png": { kind: "photo", ext: "png" },
  "image/webp": { kind: "photo", ext: "webp" },
  "image/heic": { kind: "photo", ext: "heic" },
  "image/heif": { kind: "photo", ext: "heif" },
  "video/mp4": { kind: "video", ext: "mp4" },
  "video/quicktime": { kind: "video", ext: "mov" },
  "video/webm": { kind: "video", ext: "webm" },
};

const MAX_PHOTO_BYTES = 25 * 1024 * 1024; // 25 MB
const MAX_VIDEO_BYTES = 250 * 1024 * 1024; // 250 MB
const RATE_LIMIT_PER_MINUTE = 30;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405);
  }

  let body: {
    event_id?: string;
    file_name?: string;
    mime_type?: string;
    bytes?: number;
  };
  try {
    body = await req.json();
  } catch {
    return errorResponse("bad_request", "Invalid JSON body.", 400);
  }

  const { event_id, file_name, mime_type, bytes } = body;
  if (!event_id || !file_name || !mime_type || !bytes || bytes <= 0) {
    return errorResponse(
      "bad_request",
      "event_id, file_name, mime_type and bytes are required.",
      400,
    );
  }

  // ---- 1. Identify the caller from their JWT ----
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return errorResponse("unauthorized", "Sign-in required.", 401);
  }
  const userId = userData.user.id;

  // Service-role client for privileged reads/writes (RLS bypass by design).
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // ---- 5. Media validation (cheap checks first) ----
  const media = ALLOWED_MIME[mime_type];
  if (!media) {
    return errorResponse(
      "unsupported_media",
      "Only JPEG, PNG, WebP, HEIC photos and MP4, MOV, WebM videos are allowed.",
      415,
    );
  }
  const maxBytes = media.kind === "photo" ? MAX_PHOTO_BYTES : MAX_VIDEO_BYTES;
  if (bytes > maxBytes) {
    return errorResponse(
      "too_large",
      `File exceeds the ${Math.round(maxBytes / 1024 / 1024)} MB limit.`,
      413,
    );
  }

  // ---- 2. Guest membership ----
  const { data: guest } = await admin
    .from("event_guests")
    .select("id, is_banned")
    .eq("event_id", event_id)
    .eq("auth_user_id", userId)
    .maybeSingle();
  if (!guest) {
    return errorResponse("not_joined", "Join the event before uploading.", 401);
  }
  if (guest.is_banned) {
    return errorResponse("banned", "Uploads are disabled for this guest.", 403);
  }

  // ---- 3 + 4. Event state and quota ----
  const { data: event } = await admin
    .from("events")
    .select("status, expires_at, photo_limit, photo_count, video_count")
    .eq("id", event_id)
    .maybeSingle();
  if (!event || event.status !== "active") {
    return errorResponse("event_expired", "This event is no longer active.", 410);
  }
  if (new Date(event.expires_at) < new Date()) {
    return errorResponse("event_expired", "This event has expired.", 410);
  }
  if (event.photo_count + event.video_count >= event.photo_limit) {
    return errorResponse(
      "quota_exceeded",
      "This event has reached its photo limit.",
      409,
    );
  }

  // ---- 6. Rate limit: uploads requested by this guest in the last minute ----
  const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
  const { count } = await admin
    .from("uploads")
    .select("id", { count: "exact", head: true })
    .eq("guest_id", guest.id)
    .gte("created_at", oneMinuteAgo);
  if ((count ?? 0) >= RATE_LIMIT_PER_MINUTE) {
    return errorResponse(
      "rate_limited",
      "Too many uploads at once — wait a moment and try again.",
      429,
    );
  }

  // ---- Insert the pending row (DB trigger re-checks quota race-safely) ----
  const uploadId = crypto.randomUUID();
  const storagePath = `${event_id}/${uploadId}.${media.ext}`;
  const { error: insertError } = await admin.from("uploads").insert({
    id: uploadId,
    event_id,
    guest_id: guest.id,
    storage_path: `media/${storagePath}`,
    media_type: media.kind,
    mime_type,
    bytes,
    status: "pending",
  });
  if (insertError) {
    if (insertError.message.includes("QUOTA_EXCEEDED")) {
      return errorResponse(
        "quota_exceeded",
        "This event has reached its photo limit.",
        409,
      );
    }
    if (
      insertError.message.includes("EVENT_EXPIRED") ||
      insertError.message.includes("EVENT_NOT_ACTIVE")
    ) {
      return errorResponse("event_expired", "This event has expired.", 410);
    }
    console.error("uploads insert failed", insertError);
    return errorResponse("internal", "Could not prepare the upload.", 500);
  }

  // ---- Signed upload URL (short-lived, single path) ----
  const { data: signed, error: signError } = await admin.storage
    .from("media")
    .createSignedUploadUrl(storagePath);
  if (signError || !signed) {
    // Roll back the pending row so quota is not consumed by a dead slot.
    await admin.from("uploads").delete().eq("id", uploadId);
    console.error("sign failed", signError);
    return errorResponse("internal", "Could not prepare the upload.", 500);
  }

  return jsonResponse({
    upload_id: uploadId,
    storage_path: `media/${storagePath}`,
    signed_url: signed.signedUrl,
    token: signed.token,
  });
});
