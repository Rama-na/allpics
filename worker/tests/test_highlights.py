"""Tests for highlights selection logic."""

from app.processors.highlights import select_highlights


def _upload(id_, guest="g1", quality=10.0, blur=200.0, **overrides):
    base = {
        "id": id_,
        "guest_id": guest,
        "media_type": "photo",
        "status": "ready",
        "is_duplicate": False,
        "blur_score": blur,
        "quality_score": quality,
    }
    base.update(overrides)
    return base


def test_ranks_by_quality_descending():
    picked = select_highlights([
        _upload("a", quality=1),
        _upload("b", quality=9),
        _upload("c", quality=5),
    ])
    assert [u["id"] for u in picked] == ["b", "c", "a"]


def test_excludes_duplicates_blurry_videos_and_unready():
    picked = select_highlights([
        _upload("keep", quality=5),
        _upload("dup", is_duplicate=True),
        _upload("blurry", blur=10.0),
        _upload("video", media_type="video"),
        _upload("pending", status="uploaded"),
    ])
    assert [u["id"] for u in picked] == ["keep"]


def test_caps_three_per_guest_for_variety():
    uploads = [
        _upload(f"g1-{i}", guest="g1", quality=100 - i) for i in range(5)
    ] + [_upload("g2-0", guest="g2", quality=1)]
    picked = select_highlights(uploads)
    g1_count = sum(1 for u in picked if u["guest_id"] == "g1")
    assert g1_count == 3
    assert any(u["guest_id"] == "g2" for u in picked)


def test_respects_max_items():
    uploads = [
        _upload(f"u{i}", guest=f"g{i}", quality=i) for i in range(50)
    ]
    picked = select_highlights(uploads, max_items=10)
    assert len(picked) == 10


def test_unknown_blur_score_is_allowed():
    picked = select_highlights([_upload("no-blur-info", blur=None)])
    assert len(picked) == 1
