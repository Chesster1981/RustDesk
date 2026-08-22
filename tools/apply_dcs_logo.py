#!/usr/bin/env python3
"""Apply the DCS Norway logo to Windows, Android, and Linux icon assets."""

from __future__ import annotations

import base64
import io
import struct
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
LOCAL_SOURCE = ROOT / "res" / "dcs-norway-logo-source.png"
# User-uploaded original (RGB, white corners). Prefer this over a previously punched source.
ORIGINAL_UPLOAD = Path("/opt/cursor/artifacts/assets/dcs_norway_logo_source.png")

IOS_ICONS = [
    ("Icon-App-20x20@1x.png", 20, False),
    ("Icon-App-20x20@2x.png", 40, False),
    ("Icon-App-20x20@3x.png", 60, False),
    ("Icon-App-29x29@1x.png", 29, False),
    ("Icon-App-29x29@2x.png", 58, False),
    ("Icon-App-29x29@3x.png", 87, False),
    ("Icon-App-40x40@1x.png", 40, False),
    ("Icon-App-40x40@2x.png", 80, False),
    ("Icon-App-40x40@3x.png", 120, False),
    ("Icon-App-60x60@2x.png", 120, False),
    ("Icon-App-60x60@3x.png", 180, False),
    ("Icon-App-76x76@1x.png", 76, False),
    ("Icon-App-76x76@2x.png", 152, False),
    ("Icon-App-83.5x83.5@2x.png", 167, False),
    ("Icon-App-1024x1024@1x.png", 1024, True),
]


def circular_knockout(img: Image.Image) -> Image.Image:
    # Inscribed circle only. Flood-filling near-white also deletes the sky
    # because the top of the ring is white and connects to the corners.
    rgb = img.convert("RGB")
    w, h = rgb.size
    opaque = rgb.convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(opaque, (0, 0), mask)
    return out


def load_source() -> Image.Image:
    src = ORIGINAL_UPLOAD if ORIGINAL_UPLOAD.exists() else LOCAL_SOURCE
    if not src.exists():
        raise SystemExit(f"missing logo source {src}")
    img = Image.open(src)
    if img.size != (1024, 1024):
        img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    return circular_knockout(img)


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


def flatten_rgb(img: Image.Image, size: int) -> Image.Image:
    rgba = img.resize((size, size), Image.Resampling.LANCZOS)
    bg = Image.new("RGB", (size, size), (13, 17, 23))
    bg.paste(rgba, mask=rgba.split()[-1])
    return bg


def write_icns(img: Image.Image, path: Path) -> None:
    specs = [
        (b"ic07", 128),
        (b"ic08", 256),
        (b"ic09", 512),
        (b"ic10", 1024),
        (b"ic11", 32),
        (b"ic12", 64),
        (b"ic13", 256),
        (b"ic14", 512),
    ]
    chunks: list[bytes] = []
    for ostype, size in specs:
        buf = io.BytesIO()
        img.resize((size, size), Image.Resampling.LANCZOS).save(buf, format="PNG", optimize=True)
        data = buf.getvalue()
        chunks.append(ostype + struct.pack(">I", 8 + len(data)) + data)
    body = b"".join(chunks)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"icns" + struct.pack(">I", 8 + len(body)) + body)
    print(f"ICNS -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")


ANDROID_LAUNCHER = [
    ("mipmap-mdpi", 48, 108, 24),
    ("mipmap-hdpi", 72, 162, 36),
    ("mipmap-xhdpi", 96, 216, 48),
    ("mipmap-xxhdpi", 144, 324, 72),
    ("mipmap-xxxhdpi", 192, 432, 96),
]


def apply_android_icons(img: Image.Image) -> None:
    res = ROOT / "flutter" / "android" / "app" / "src" / "main" / "res"
    for folder, launcher, foreground, status in ANDROID_LAUNCHER:
        d = res / folder
        d.mkdir(parents=True, exist_ok=True)
        icon = img.resize((launcher, launcher), Image.Resampling.LANCZOS)
        icon.save(d / "ic_launcher.png", format="PNG", optimize=True)
        icon.save(d / "ic_launcher_round.png", format="PNG", optimize=True)
        # Adaptive-icon safe zone is the inner 66% of the foreground canvas.
        fg = Image.new("RGBA", (foreground, foreground), (0, 0, 0, 0))
        inner = int(foreground * 0.66)
        placed = img.resize((inner, inner), Image.Resampling.LANCZOS)
        off = (foreground - inner) // 2
        fg.paste(placed, (off, off), placed)
        fg.save(d / "ic_launcher_foreground.png", format="PNG", optimize=True)
        flatten_rgb(img, status).save(d / "ic_stat_logo.png", format="PNG", optimize=True)
        print(f"Android {folder} launcher={launcher} fg={foreground}")


def apply_apple_icons(img: Image.Image) -> None:
    ios_dir = ROOT / "flutter" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size, marketing in IOS_ICONS:
        path = ios_dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if marketing:
            flatten_rgb(img, size).save(path, format="PNG", optimize=True)
        else:
            img.resize((size, size), Image.Resampling.LANCZOS).save(
                path, format="PNG", optimize=True
            )
        print(f"iOS {size:4d} -> {path.relative_to(ROOT)} ({path.stat().st_size} bytes)")
    write_icns(img, ROOT / "flutter" / "macos" / "Runner" / "AppIcon.icns")


def main() -> None:
    img = load_source()
    LOCAL_SOURCE.parent.mkdir(parents=True, exist_ok=True)
    img.save(LOCAL_SOURCE, format="PNG", optimize=True)
    print(f"source -> {LOCAL_SOURCE.relative_to(ROOT)} ({LOCAL_SOURCE.stat().st_size} bytes)")
    assets = ROOT / "flutter" / "assets"
    res = ROOT / "res"

    save_png(img, assets / "icon.png", 256)
    save_png(img, assets / "logo.png", 256)
    save_png(img, assets / "logo_light.png", 256)
    save_png(img, assets / "logo_dark.png", 256)
    save_png(img, assets / "dcs_norway_logo.png", 512)
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
    write_icon_svg(img, res / "scalable.svg")
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

    apply_android_icons(img)
    print("DONE")


if __name__ == "__main__":
    main()
