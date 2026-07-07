"""Worker configuration from environment variables."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    service_role_key: str
    poll_interval_s: float = 3.0
    thumb_size: int = 512
    dedupe_hamming_threshold: int = 6
    blur_threshold: float = 60.0
    highlights_max_items: int = 30
    slideshow_max_items: int = 40
    slideshow_seconds_per_photo: float = 2.0

    @property
    def configured(self) -> bool:
        return bool(self.supabase_url and self.service_role_key)


def load_settings() -> Settings:
    return Settings(
        supabase_url=os.environ.get("SUPABASE_URL", "").rstrip("/"),
        service_role_key=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
        poll_interval_s=float(os.environ.get("POLL_INTERVAL_S", "3")),
    )
