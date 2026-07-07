"""Pure image operations: thumbnails, perceptual hashing, blur detection,
quality scoring, and enhancement. No network or database access — fully
unit-testable.
"""

from __future__ import annotations

import io

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

# ---------------- thumbnails ----------------


def make_thumbnail(data: bytes, max_size: int = 512) -> bytes:
    """JPEG thumbnail with EXIF orientation applied."""
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img)
        img = img.convert("RGB")
        img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=82, optimize=True)
        return out.getvalue()


def image_dimensions(data: bytes) -> tuple[int, int]:
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img)
        return img.width, img.height


# ---------------- perceptual hash (DCT pHash, 64-bit) ----------------


def _dct_matrix(n: int) -> np.ndarray:
    k = np.arange(n)
    m = np.sqrt(2.0 / n) * np.cos(np.pi * (2 * k[None, :] + 1) * k[:, None] / (2 * n))
    m[0, :] = np.sqrt(1.0 / n)
    return m


def compute_phash(data: bytes) -> str:
    """64-bit DCT perceptual hash, hex-encoded (16 chars)."""
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img).convert("L").resize(
            (32, 32), Image.Resampling.LANCZOS
        )
        pixels = np.asarray(img, dtype=np.float64)

    m = _dct_matrix(32)
    dct = m @ pixels @ m.T
    low = dct[:8, :8].copy()
    # Exclude the DC coefficient from the median so flat images do not
    # collapse to all-zeros.
    coeffs = low.flatten()[1:]
    median = np.median(coeffs)
    bits = (low.flatten() > median).astype(np.uint8)
    value = 0
    for bit in bits:
        value = (value << 1) | int(bit)
    return f"{value:016x}"


def hamming_distance(hash_a: str, hash_b: str) -> int:
    return bin(int(hash_a, 16) ^ int(hash_b, 16)).count("1")


# ---------------- blur detection (Laplacian variance) ----------------


def blur_score(data: bytes) -> float:
    """Variance of the Laplacian — higher is sharper. < ~60 is blurry."""
    with Image.open(io.BytesIO(data)) as img:
        gray = ImageOps.exif_transpose(img).convert("L")
        # Bound the work for very large photos.
        gray.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        arr = np.asarray(gray, dtype=np.float64)

    lap = (
        -4 * arr[1:-1, 1:-1]
        + arr[:-2, 1:-1]
        + arr[2:, 1:-1]
        + arr[1:-1, :-2]
        + arr[1:-1, 2:]
    )
    return float(lap.var())


def is_blurry(score: float, threshold: float = 60.0) -> bool:
    return score < threshold


# ---------------- quality scoring ----------------


def quality_score(sharpness: float, width: int, height: int) -> float:
    """Ranking score combining sharpness and resolution (log-scaled)."""
    megapixels = max(width * height, 1) / 1_000_000
    return float(np.log1p(sharpness) * np.log1p(megapixels * 4))


# ---------------- enhancement ----------------


def enhance_image(data: bytes) -> bytes:
    """Deterministic auto-enhancement: brightness, contrast, sharpening,
    and light noise reduction."""
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img).convert("RGB")
        img = img.filter(ImageFilter.MedianFilter(size=3))  # denoise
        img = ImageEnhance.Brightness(img).enhance(1.05)
        img = ImageEnhance.Contrast(img).enhance(1.08)
        img = ImageEnhance.Sharpness(img).enhance(1.35)
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=90, optimize=True)
        return out.getvalue()
