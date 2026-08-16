#!/usr/bin/env python3
"""Apply Desktop Image.txt (hex PNG) to RustDesk logo/icon assets."""

from __future__ import annotations

import base64
import io
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
HEX_PATH = Path(r"c:\Users\Ole\Desktop\Image.txt")
SRC_CACHE = Path(r"C:\Users\Ole\AppData\Local\Temp\dcs_hex_logo.png")


def load_source() -> Image.Image:
    if not SRC_CACHE.exists() or SRC_CACHE.stat().st_size < 1000:
        raw = re.sub(r"\s+", "", HEX_PATH.read_text(encoding="utf-8", errors="ignore"))
        SRC_CACHE.write_bytes(bytes.fromhex(raw))
    img = Image.open(SRC_CACHE).convert("RGBA")
    if img.size != (1024, 1024):
        raise SystemExit(f"unexpected source size {img.size}, want 1024x1024")
    return img


def save_png(img: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(path, format="PNG", optimize=True)
    print(f"PNG {size:4d} -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


def save_ico(img: Image.Image, path: Path, sizes: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    icons = [img.resize((s, s), Image.Resampling.LANCZOS) for s in sizes]
    icons[-1].save(path, format="ICO", sizes=[(s, s) for s in sizes])
    print(f"ICO {sizes} -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


def write_icon_svg(img: Image.Image, path: Path, size: int = 128) -> None:
    write_icon_svg_size(img, path, size)


def write_icon_svg_size(img: Image.Image, path: Path, size: int) -> None:
    buf = io.BytesIO()
    img.resize((size, size), Image.Resampling.LANCZOS).save(buf, format="PNG", optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    path.write_text(
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{size}" height="{size}" viewBox="0 0 {size} {size}">\n'
            f'  <image width="{size}" height="{size}" '
            f'xlink:href="data:image/png;base64,{b64}"/>\n'
            f"</svg>\n"
        ),
        encoding="utf-8",
    )
    print(f"SVG embed -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


def main() -> None:
    img = load_source()
    assets = ROOT / "flutter" / "assets"
    res = ROOT / "res"

    save_png(img, assets / "icon.png", 256)
    save_png(img, assets / "logo.png", 256)
    save_png(img, assets / "logo_light.png", 256)
    save_png(img, assets / "logo_dark.png", 256)
    # Keep flutter/assets/dcs_norway_logo.png — product header brand (Hetlebakken), not RustDesk.
    save_ico(img, assets / "icon.ico", [16, 32, 48, 64, 128, 256])
    write_icon_svg(img, assets / "icon.svg")

    save_png(img, res / "icon.png", 512)
    save_png(img, res / "32x32.png", 32)
    save_png(img, res / "64x64.png", 64)
    save_png(img, res / "128x128.png", 128)
    save_png(img, res / "128x128@2x.png", 256)
    save_png(img, res / "mac-icon.png", 1024)
    save_ico(img, res / "icon.ico", [16, 32, 48, 64, 128, 256])
    save_ico(img, res / "tray-icon.ico", [16, 24, 32])
    write_icon_svg(img, res / "logo.svg")
    # Wider header slot historically; keep square brand mark at higher res.
    write_icon_svg_size(img, res / "logo-header.svg", 256)
    save_ico(
        img,
        ROOT / "flutter" / "windows" / "runner" / "resources" / "app_icon.ico",
        [16, 32, 48, 64, 128, 256],
    )

    msi_icon = res / "msi" / "Package" / "Resources" / "icon.ico"
    if msi_icon.parent.exists():
        save_ico(img, msi_icon, [16, 32, 48, 64, 128, 256])

    print("DONE")


if __name__ == "__main__":
    main()
