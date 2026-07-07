"""FastAPI entrypoint: health endpoint + background worker loop."""

from __future__ import annotations

import logging
import threading
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .config import load_settings
from .supabase_api import SupabaseApi
from .worker import Worker

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("main")

settings = load_settings()
worker: Worker | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global worker
    if settings.configured:
        worker = Worker(SupabaseApi(settings), settings)
        thread = threading.Thread(target=worker.run_forever, daemon=True)
        thread.start()
        log.info("worker thread started")
    else:
        log.warning(
            "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set — "
            "worker idle (health endpoint only)"
        )
    yield
    if worker:
        worker.stop()


app = FastAPI(title="AllPics Worker", lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict:
    return {
        "ok": True,
        "configured": settings.configured,
        "jobs_done": worker.jobs_done if worker else 0,
        "jobs_failed": worker.jobs_failed if worker else 0,
    }
