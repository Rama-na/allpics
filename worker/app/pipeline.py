"""Job handlers: the bridge between the queue and the processors."""

from __future__ import annotations

import logging
from typing import Any

from .config import Settings
from .processors import image_ops, video_ops
from .processors.highlights import select_highlights
from .supabase_api import SupabaseApi

log = logging.getLogger("pipeline")


def _split_path(storage_path: str) -> tuple[str, str]:
    bucket, _, path = storage_path.partition("/")
    return bucket, path


class Pipeline:
    def __init__(self, api: SupabaseApi, settings: Settings):
        self.api = api
        self.settings = settings

    # ---------------- dispatch ----------------

    def handle(self, job: dict[str, Any]) -> dict[str, Any]:
        job_type = job["job_type"]
        if job_type == "thumbnail":
            return self.process_upload(job["upload_id"])
        if job_type == "enhance":
            return self.enhance_upload(job["upload_id"])
        if job_type == "highlights":
            return self.build_highlights(job["event_id"])
        if job_type == "slideshow":
            return self.build_slideshow(job["event_id"])
        raise ValueError(f"unsupported job type: {job_type}")

    # ---------------- per-upload pipeline ----------------

    def process_upload(self, upload_id: str) -> dict[str, Any]:
        rows = self.api.select("uploads", f"id=eq.{upload_id}&select=*")
        if not rows:
            return {"skipped": "upload missing"}
        upload = rows[0]
        bucket, path = _split_path(upload["storage_path"])
        data = self.api.download(bucket, path)
        event_id = upload["event_id"]
        thumb_path = f"{event_id}/{upload_id}.jpg"

        if upload["media_type"] == "video":
            result: dict[str, Any] = {}
            try:
                thumb = video_ops.video_thumbnail(data, self.settings.thumb_size)
                self.api.upload("thumbs", thumb_path, thumb, "image/jpeg")
                result["thumb"] = True
            except video_ops.FfmpegUnavailableError:
                log.warning("ffmpeg unavailable — video thumb skipped")
                result["thumb"] = False
            self.api.update(
                "uploads",
                f"id=eq.{upload_id}",
                {
                    "status": "ready",
                    "thumb_path": f"thumbs/{thumb_path}" if result.get("thumb") else None,
                    "bytes": len(data),
                },
            )
            return result

        # ---- photo ----
        thumb = image_ops.make_thumbnail(data, self.settings.thumb_size)
        self.api.upload("thumbs", thumb_path, thumb, "image/jpeg")

        width, height = image_ops.image_dimensions(data)
        phash = image_ops.compute_phash(data)
        sharpness = image_ops.blur_score(data)
        quality = image_ops.quality_score(sharpness, width, height)

        # Dedupe against already-processed photos in the same event.
        peers = self.api.select(
            "uploads",
            f"event_id=eq.{event_id}&media_type=eq.photo&status=eq.ready"
            f"&phash=not.is.null&is_duplicate=eq.false&id=neq.{upload_id}"
            f"&select=id,phash,quality_score",
        )
        duplicate_of = None
        for peer in peers:
            distance = image_ops.hamming_distance(phash, peer["phash"])
            if distance <= self.settings.dedupe_hamming_threshold:
                if quality > float(peer.get("quality_score") or 0):
                    # This photo is the better copy — demote the peer.
                    self.api.update(
                        "uploads",
                        f"id=eq.{peer['id']}",
                        {"is_duplicate": True, "duplicate_of": upload_id},
                    )
                else:
                    duplicate_of = peer["id"]
                break

        self.api.update(
            "uploads",
            f"id=eq.{upload_id}",
            {
                "status": "ready",
                "thumb_path": f"thumbs/{thumb_path}",
                "width": width,
                "height": height,
                "bytes": len(data),
                "phash": phash,
                "blur_score": sharpness,
                "quality_score": quality,
                "is_duplicate": duplicate_of is not None,
                "duplicate_of": duplicate_of,
            },
        )
        return {
            "phash": phash,
            "blur_score": round(sharpness, 2),
            "is_duplicate": duplicate_of is not None,
        }

    # ---------------- enhancement ----------------

    def enhance_upload(self, upload_id: str) -> dict[str, Any]:
        rows = self.api.select("uploads", f"id=eq.{upload_id}&select=*")
        if not rows:
            return {"skipped": "upload missing"}
        upload = rows[0]
        if upload["media_type"] != "photo":
            return {"skipped": "videos are not enhanced"}
        bucket, path = _split_path(upload["storage_path"])
        data = self.api.download(bucket, path)
        enhanced = image_ops.enhance_image(data)
        self.api.upload(bucket, path, enhanced, "image/jpeg", upsert=True)
        thumb = image_ops.make_thumbnail(enhanced, self.settings.thumb_size)
        thumb_path = f"{upload['event_id']}/{upload_id}.jpg"
        self.api.upload("thumbs", thumb_path, thumb, "image/jpeg")
        self.api.update(
            "uploads", f"id=eq.{upload_id}", {"bytes": len(enhanced)}
        )
        return {"enhanced": True}

    # ---------------- event-level jobs ----------------

    def _ready_photos(self, event_id: str) -> list[dict[str, Any]]:
        return self.api.select(
            "uploads",
            f"event_id=eq.{event_id}&select=id,guest_id,media_type,status,"
            f"is_duplicate,blur_score,quality_score,storage_path"
            f"&order=created_at.asc",
        )

    def build_highlights(self, event_id: str) -> dict[str, Any]:
        picked = select_highlights(
            self._ready_photos(event_id),
            max_items=self.settings.highlights_max_items,
            blur_threshold=self.settings.blur_threshold,
        )
        existing = self.api.select(
            "albums", f"event_id=eq.{event_id}&kind=eq.highlights&select=id"
        )
        if existing:
            album_id = existing[0]["id"]
        else:
            album_id = self.api.insert(
                "albums",
                {"event_id": event_id, "kind": "highlights", "title": "Highlights"},
            )[0]["id"]
        self.api.delete("album_items", f"album_id=eq.{album_id}")
        if picked:
            self.api.insert(
                "album_items",
                [
                    {"album_id": album_id, "upload_id": u["id"], "position": i}
                    for i, u in enumerate(picked)
                ],
            )
        self.api.update(
            "albums", f"id=eq.{album_id}", {"generated_at": "now()"}
        )
        return {"album_id": album_id, "items": len(picked)}

    def build_slideshow(self, event_id: str) -> dict[str, Any]:
        picked = select_highlights(
            self._ready_photos(event_id),
            max_items=self.settings.slideshow_max_items,
            blur_threshold=self.settings.blur_threshold,
        )
        if not picked:
            return {"skipped": "no eligible photos"}
        photos = []
        for upload in picked:
            bucket, path = _split_path(upload["storage_path"])
            photos.append(self.api.download(bucket, path))
        video = video_ops.build_slideshow(
            photos, self.settings.slideshow_seconds_per_photo
        )
        out_path = f"{event_id}/slideshow.mp4"
        self.api.upload("exports", out_path, video, "video/mp4")

        existing = self.api.select(
            "albums", f"event_id=eq.{event_id}&kind=eq.slideshow&select=id"
        )
        if existing:
            self.api.update(
                "albums",
                f"id=eq.{existing[0]['id']}",
                {"output_path": f"exports/{out_path}", "generated_at": "now()"},
            )
            album_id = existing[0]["id"]
        else:
            album_id = self.api.insert(
                "albums",
                {
                    "event_id": event_id,
                    "kind": "slideshow",
                    "title": "Slideshow",
                    "output_path": f"exports/{out_path}",
                    "generated_at": "now()",
                },
            )[0]["id"]
        return {"album_id": album_id, "items": len(picked)}
