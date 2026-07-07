"""Highlights selection — pure ranking logic over upload metadata."""

from __future__ import annotations

from typing import Any


def select_highlights(
    uploads: list[dict[str, Any]],
    max_items: int = 30,
    blur_threshold: float = 60.0,
) -> list[dict[str, Any]]:
    """Picks the best photos for the highlights album.

    Rules:
      - photos only, status 'ready'
      - duplicates excluded
      - blurry photos excluded (when a blur score is known)
      - at most 3 photos per guest for variety
      - ranked by quality_score descending
    """
    candidates = [
        u
        for u in uploads
        if u.get("media_type") == "photo"
        and u.get("status") == "ready"
        and not u.get("is_duplicate")
        and (
            u.get("blur_score") is None
            or float(u["blur_score"]) >= blur_threshold
        )
    ]
    candidates.sort(key=lambda u: float(u.get("quality_score") or 0), reverse=True)

    per_guest: dict[str, int] = {}
    picked: list[dict[str, Any]] = []
    for upload in candidates:
        guest = str(upload.get("guest_id"))
        if per_guest.get(guest, 0) >= 3:
            continue
        per_guest[guest] = per_guest.get(guest, 0) + 1
        picked.append(upload)
        if len(picked) >= max_items:
            break
    return picked
