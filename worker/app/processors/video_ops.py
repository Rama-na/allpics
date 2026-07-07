"""Video operations via ffmpeg (thumbnails + slideshow rendering)."""

from __future__ import annotations

import io
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageOps


class FfmpegUnavailableError(RuntimeError):
    pass


def _require_ffmpeg() -> str:
    path = shutil.which("ffmpeg")
    if not path:
        raise FfmpegUnavailableError("ffmpeg is not installed on this host")
    return path


def video_thumbnail(data: bytes, max_size: int = 512) -> bytes:
    """Extracts a JPEG frame from ~1s into the video."""
    ffmpeg = _require_ffmpeg()
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "input"
        out = Path(tmp) / "frame.jpg"
        src.write_bytes(data)
        subprocess.run(
            [
                ffmpeg, "-y", "-ss", "1", "-i", str(src),
                "-frames:v", "1", "-q:v", "3", str(out),
            ],
            check=True,
            capture_output=True,
            timeout=120,
        )
        with Image.open(out) as img:
            img = img.convert("RGB")
            img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=82)
            return buf.getvalue()


def build_slideshow(
    photos: list[bytes],
    seconds_per_photo: float = 2.0,
    size: tuple[int, int] = (1280, 720),
) -> bytes:
    """Renders an MP4 slideshow from photo bytes (letterboxed to [size])."""
    ffmpeg = _require_ffmpeg()
    if not photos:
        raise ValueError("no photos to render")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for index, data in enumerate(photos):
            with Image.open(io.BytesIO(data)) as img:
                img = ImageOps.exif_transpose(img).convert("RGB")
                img = ImageOps.pad(img, size, color=(12, 12, 16))
                img.save(tmp_path / f"frame_{index:04d}.jpg", quality=88)

        out = tmp_path / "slideshow.mp4"
        subprocess.run(
            [
                ffmpeg, "-y",
                "-framerate", f"1/{seconds_per_photo}",
                "-i", str(tmp_path / "frame_%04d.jpg"),
                "-c:v", "libx264", "-pix_fmt", "yuv420p",
                "-vf", "format=yuv420p",
                "-movflags", "+faststart",
                str(out),
            ],
            check=True,
            capture_output=True,
            timeout=600,
        )
        return out.read_bytes()
