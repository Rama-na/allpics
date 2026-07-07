"""Tests for pure image operations using synthetic images."""

import io
import random

import pytest
from PIL import Image, ImageDraw, ImageFilter

from app.processors import image_ops


def _noise_photo(size=(640, 480), seed=7) -> bytes:
    """A detailed, high-frequency synthetic 'photo'."""
    rng = random.Random(seed)
    img = Image.new("RGB", size)
    pixels = [
        (rng.randrange(256), rng.randrange(256), rng.randrange(256))
        for _ in range(size[0] * size[1])
    ]
    img.putdata(pixels)
    draw = ImageDraw.Draw(img)
    for i in range(0, size[0], 20):
        draw.line([(i, 0), (i, size[1])], fill=(255, 255, 255), width=2)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=92)
    return buf.getvalue()


def _blurred(data: bytes, radius=8) -> bytes:
    with Image.open(io.BytesIO(data)) as img:
        out = io.BytesIO()
        img.filter(ImageFilter.GaussianBlur(radius)).save(out, format="JPEG")
        return out.getvalue()


def _gradient_photo(size=(400, 300), shift=0) -> bytes:
    img = Image.new("RGB", size)
    img.putdata([
        ((x + shift) % 256, y % 256, (x + y) % 256)
        for y in range(size[1])
        for x in range(size[0])
    ])
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


class TestThumbnail:
    def test_resizes_within_bounds_and_is_jpeg(self):
        thumb = image_ops.make_thumbnail(_noise_photo((2000, 1000)), 512)
        with Image.open(io.BytesIO(thumb)) as img:
            assert img.format == "JPEG"
            assert max(img.size) <= 512
            # Aspect ratio preserved (2:1).
            assert abs(img.width / img.height - 2.0) < 0.05

    def test_dimensions_helper(self):
        width, height = image_ops.image_dimensions(_noise_photo((640, 480)))
        assert (width, height) == (640, 480)


class TestPhash:
    def test_identical_images_have_zero_distance(self):
        a = image_ops.compute_phash(_noise_photo(seed=1))
        b = image_ops.compute_phash(_noise_photo(seed=1))
        assert image_ops.hamming_distance(a, b) == 0

    def test_resized_copy_is_near_duplicate(self):
        original = _noise_photo((640, 480), seed=2)
        with Image.open(io.BytesIO(original)) as img:
            small = io.BytesIO()
            img.resize((320, 240)).save(small, format="JPEG", quality=80)
        a = image_ops.compute_phash(original)
        b = image_ops.compute_phash(small.getvalue())
        assert image_ops.hamming_distance(a, b) <= 6

    def test_different_images_are_far_apart(self):
        a = image_ops.compute_phash(_gradient_photo(shift=0))
        b = image_ops.compute_phash(_noise_photo(seed=9))
        assert image_ops.hamming_distance(a, b) > 6

    def test_hash_is_64_bit_hex(self):
        value = image_ops.compute_phash(_noise_photo())
        assert len(value) == 16
        int(value, 16)  # parses


class TestBlur:
    def test_sharp_image_scores_high(self):
        assert image_ops.blur_score(_noise_photo()) > 60

    def test_blurred_image_scores_low_and_flags(self):
        score = image_ops.blur_score(_blurred(_noise_photo(), radius=10))
        assert score < image_ops.blur_score(_noise_photo())
        assert image_ops.is_blurry(score, threshold=60) or score < 200

    def test_ordering_sharp_vs_blurry(self):
        sharp = image_ops.blur_score(_noise_photo(seed=3))
        soft = image_ops.blur_score(_blurred(_noise_photo(seed=3), 4))
        very_soft = image_ops.blur_score(_blurred(_noise_photo(seed=3), 12))
        assert sharp > soft > very_soft


class TestQualityAndEnhance:
    def test_quality_prefers_sharp_and_large(self):
        small_soft = image_ops.quality_score(20, 640, 480)
        large_sharp = image_ops.quality_score(400, 4000, 3000)
        assert large_sharp > small_soft

    def test_enhance_returns_valid_jpeg(self):
        out = image_ops.enhance_image(_noise_photo())
        with Image.open(io.BytesIO(out)) as img:
            assert img.format == "JPEG"
            assert img.size == (640, 480)


class TestHamming:
    @pytest.mark.parametrize(
        ("a", "b", "expected"),
        [
            ("0000000000000000", "0000000000000000", 0),
            ("0000000000000000", "0000000000000001", 1),
            ("ffffffffffffffff", "0000000000000000", 64),
        ],
    )
    def test_known_distances(self, a, b, expected):
        assert image_ops.hamming_distance(a, b) == expected
