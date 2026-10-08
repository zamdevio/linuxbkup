#!/usr/bin/env python3
"""Generate apps/docs/public/og.png — 1200×630 social card (slate + terminal green).

Regenerate: python3 apps/docs/scripts/make-og.py
Brand: match apps/docs/public/linuxbkup.svg + custom.css (no purple AI default).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 1200, 630
BG = (11, 18, 32)  # #0b1220
GREEN = (61, 214, 140)  # #3dd68c
AMBER = (232, 197, 71)  # #e8c547
TEXT = (232, 241, 236)
MUTED = (148, 163, 184)

OUT = Path(__file__).resolve().parents[1] / "public" / "og.png"


def font(size: int, mono: bool = False) -> ImageFont.FreeTypeFont:
    candidates = (
        [
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf",
        ]
        if mono
        else [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
            "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
        ]
    )
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_logo_mark(img: Image.Image, x: int, y: int, size: int) -> None:
    """Terminal-green chevron + amber bar on rounded slate tile (from linuxbkup.svg)."""
    d = ImageDraw.Draw(img)
    r = size // 8
    d.rounded_rectangle((x, y, x + size, y + size), radius=r, fill=BG, outline=(36, 48, 72), width=3)
    # chevron: M16 22 L28 32 L16 42 on 64 → scale
    s = size / 64
    pts = [
        (x + 16 * s, y + 22 * s),
        (x + 28 * s, y + 32 * s),
        (x + 16 * s, y + 42 * s),
    ]
    d.line(pts, fill=GREEN, width=max(4, int(5 * s)), joint="curve")
    d.line([(x + 34 * s, y + 42 * s), (x + 48 * s, y + 42 * s)], fill=AMBER, width=max(4, int(5 * s)))


def main() -> None:
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # subtle top rule
    d.rectangle((0, 0, W, 6), fill=(24, 36, 56))
    d.rectangle((0, 0, int(W * 0.35), 6), fill=GREEN)

    mark = 148
    mx, my = 72, (H - mark) // 2 - 18
    draw_logo_mark(img, mx, my, mark)

    f_name = font(84, mono=True)
    f_tag = font(36)
    f_sub = font(28)

    tx = mx + mark + 40
    ty = my + 4
    d.text((tx, ty), "linuxbkup", font=f_name, fill=TEXT)
    d.text((tx, ty + 100), "Backup what can't be regenerated", font=f_tag, fill=GREEN)
    d.text((tx, ty + 160), "Universal Linux backup — desktop · VPS · WSL", font=f_sub, fill=MUTED)
    d.text((tx, ty + 210), "Bash-first · atomic tar.zst · schema · age secrets", font=f_sub, fill=MUTED)

    f_url = font(24, mono=True)
    d.text((72, H - 48), "linuxbkup.pages.dev", font=f_url, fill=MUTED)
    d.text((W - 72 - d.textlength("github.com/zamdevio/linuxbkup", font=f_url), H - 48),
           "github.com/zamdevio/linuxbkup", font=f_url, fill=MUTED)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
