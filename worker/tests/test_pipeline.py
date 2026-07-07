"""Pipeline tests with a stubbed Supabase API (no network)."""

import io

from PIL import Image

from app.config import Settings
from app.pipeline import Pipeline


def _photo_bytes(seed=0, size=(320, 240)) -> bytes:
    img = Image.new("RGB", size)
    img.putdata([
        ((x * 7 + seed * 31) % 256, (y * 3) % 256, (x + y) % 256)
        for y in range(size[1])
        for x in range(size[0])
    ])
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


class StubApi:
    """Records calls; serves canned rows and bytes."""

    def __init__(self):
        self.rows: dict[str, list[dict]] = {}
        self.updates: list[tuple[str, str, dict]] = []
        self.inserts: list[tuple[str, object]] = []
        self.deletes: list[tuple[str, str]] = []
        self.uploads: list[tuple[str, str, str]] = []
        self.blobs: dict[str, bytes] = {}

    def select(self, table, query):
        for key, value in self.rows.items():
            if key[0] == table and key[1] in query:
                return value
        # Fallback: first entry for the table.
        for key, value in self.rows.items():
            if key[0] == table:
                return value
        return []

    def update(self, table, query, values):
        self.updates.append((table, query, values))

    def insert(self, table, values):
        self.inserts.append((table, values))
        return [{"id": "new-album-id"}]

    def delete(self, table, query):
        self.deletes.append((table, query))

    def download(self, bucket, path):
        return self.blobs[f"{bucket}/{path}"]

    def upload(self, bucket, path, data, content_type, upsert=True):
        self.uploads.append((bucket, path, content_type))
        self.blobs[f"{bucket}/{path}"] = data


def _settings():
    return Settings(supabase_url="http://test", service_role_key="k")


def test_process_upload_photo_full_pipeline():
    api = StubApi()
    api.rows[("uploads", "id=eq.u1")] = [{
        "id": "u1",
        "event_id": "e1",
        "media_type": "photo",
        "storage_path": "media/e1/u1.jpg",
        "status": "uploaded",
    }]
    api.rows[("uploads", "event_id=eq.e1")] = []  # no peers yet
    api.blobs["media/e1/u1.jpg"] = _photo_bytes()

    result = Pipeline(api, _settings()).process_upload("u1")

    # Thumbnail uploaded to the thumbs bucket.
    assert ("thumbs", "e1/u1.jpg", "image/jpeg") in api.uploads
    # Row promoted to ready with analysis fields.
    table, query, values = api.updates[-1]
    assert (table, query) == ("uploads", "id=eq.u1")
    assert values["status"] == "ready"
    assert values["thumb_path"] == "thumbs/e1/u1.jpg"
    assert len(values["phash"]) == 16
    assert values["width"] == 320 and values["height"] == 240
    assert values["is_duplicate"] is False
    assert result["is_duplicate"] is False


def test_process_upload_marks_duplicate_of_better_peer():
    api = StubApi()
    photo = _photo_bytes(seed=5)
    api.rows[("uploads", "id=eq.u2")] = [{
        "id": "u2",
        "event_id": "e1",
        "media_type": "photo",
        "storage_path": "media/e1/u2.jpg",
        "status": "uploaded",
    }]
    from app.processors.image_ops import compute_phash

    api.rows[("uploads", "event_id=eq.e1")] = [{
        "id": "u1",
        "phash": compute_phash(photo),
        "quality_score": 10_000.0,  # peer is 'better'
    }]
    api.blobs["media/e1/u2.jpg"] = photo

    result = Pipeline(api, _settings()).process_upload("u2")

    assert result["is_duplicate"] is True
    _, _, values = api.updates[-1]
    assert values["duplicate_of"] == "u1"


def test_build_highlights_creates_album_and_items():
    api = StubApi()
    api.rows[("uploads", "event_id=eq.e1")] = [
        {
            "id": f"u{i}",
            "guest_id": f"g{i}",
            "media_type": "photo",
            "status": "ready",
            "is_duplicate": False,
            "blur_score": 500.0,
            "quality_score": float(i),
            "storage_path": f"media/e1/u{i}.jpg",
        }
        for i in range(4)
    ]
    api.rows[("albums", "kind=eq.highlights")] = []

    result = Pipeline(api, _settings()).build_highlights("e1")

    assert result["items"] == 4
    inserted_tables = [t for t, _ in api.inserts]
    assert "albums" in inserted_tables
    assert "album_items" in inserted_tables
    # Old items cleared before rewrite.
    assert api.deletes and api.deletes[0][0] == "album_items"
