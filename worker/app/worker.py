"""Queue polling loop: claim → handle → complete/fail."""

from __future__ import annotations

import json
import logging
import threading
import time

from .config import Settings
from .pipeline import Pipeline
from .supabase_api import SupabaseApi

log = logging.getLogger("worker")


class Worker:
    def __init__(self, api: SupabaseApi, settings: Settings):
        self.api = api
        self.settings = settings
        self.pipeline = Pipeline(api, settings)
        self._stop = threading.Event()
        self.jobs_done = 0
        self.jobs_failed = 0

    def stop(self) -> None:
        self._stop.set()

    def run_once(self) -> bool:
        """Claims and processes one job. Returns False when idle."""
        jobs = self.api.rpc("claim_processing_job") or []
        if not jobs:
            return False
        job = jobs[0]
        log.info("job %s (%s) claimed", job["id"], job["job_type"])
        try:
            result = self.pipeline.handle(job)
            self.api.update(
                "processing_jobs",
                f"id=eq.{job['id']}",
                {"status": "done", "result": json.loads(json.dumps(result))},
            )
            self.jobs_done += 1
            log.info("job %s done: %s", job["id"], result)
        except Exception as exc:  # noqa: BLE001 — jobs must never kill the loop
            message = str(exc)[:500]
            log.exception("job %s failed", job["id"])
            status = "failed" if job["attempts"] >= 3 else "queued"
            self.api.update(
                "processing_jobs",
                f"id=eq.{job['id']}",
                {"status": status, "last_error": message},
            )
            self.jobs_failed += 1
        return True

    def run_forever(self) -> None:
        log.info("worker loop started (poll %.1fs)", self.settings.poll_interval_s)
        while not self._stop.is_set():
            try:
                busy = self.run_once()
            except Exception:  # noqa: BLE001 — e.g. transient network errors
                log.exception("poll iteration failed")
                busy = False
            if not busy:
                self._stop.wait(self.settings.poll_interval_s)
