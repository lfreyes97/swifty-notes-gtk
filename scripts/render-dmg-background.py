#!/usr/bin/env python3
# Render the DMG background via Pillow so we can pull system Helvetica
# straight from /System/Library/Fonts/, instead of going through
# rsvg-convert + fontconfig (which doesn't find macOS system fonts on
# this machine and falls back to DejaVu Sans with visibly different
# metrics — letters look condensed compared to native Helvetica).

import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont


def gradient_bg(width: int, height: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """Vertical linear gradient between two RGB tuples."""
    img = Image.new("RGB", (width, height), top)
    drawer = ImageDraw.Draw(img)
    for y in range(height):
        ratio = y / max(height - 1, 1)
        r = round(top[0] + (bottom[0] - top[0]) * ratio)
        g = round(top[1] + (bottom[1] - top[1]) * ratio)
        b = round(top[2] + (bottom[2] - top[2]) * ratio)
        drawer.line([(0, y), (width, y)], fill=(r, g, b))
    return img


def dashed_line(drawer: ImageDraw.ImageDraw, x1: int, x2: int, y: int, dash: int, gap: int, fill, width: int) -> None:
    x = x1
    while x < x2:
        end = min(x + dash, x2)
        drawer.line([(x, y), (end, y)], fill=fill, width=width)
        x = end + gap


def main(out_path: str, scale: int) -> None:
    base_w, base_h = 600, 400
    w, h = base_w * scale, base_h * scale

    img = gradient_bg(w, h, (247, 247, 249), (232, 232, 236))
    drawer = ImageDraw.Draw(img)

    helv = "/System/Library/Fonts/Helvetica.ttc"
    h1 = ImageFont.truetype(helv, 26 * scale, index=1)   # Helvetica-Bold
    h2 = ImageFont.truetype(helv, 15 * scale, index=0)   # Helvetica regular
    caption = ImageFont.truetype(helv, 12 * scale, index=0)

    title_color = (29, 29, 31)
    subtitle_color = (110, 110, 117)
    arrow_color = (134, 134, 139)

    drawer.text((w // 2, 60 * scale), "Install Swifty Notes", fill=title_color, font=h1, anchor="ma")
    drawer.text((w // 2, 92 * scale), "Drag the app icon onto the Applications folder", fill=subtitle_color, font=h2, anchor="ma")

    # Arrow between the two icons. Icons in the .DS_Store layout sit at
    # (150, 200) and (450, 200) in 1x coordinates; the shaft starts at
    # x=225 (= just past the app icon's right edge) and the head ends at
    # x=385 (= just before the Applications shortcut's left edge).
    shaft_y = 210 * scale
    dashed_line(drawer, 225 * scale, 360 * scale, shaft_y, dash=10 * scale, gap=8 * scale, fill=arrow_color, width=3 * scale)
    drawer.polygon(
        [
            (360 * scale, (shaft_y - 11 * scale)),
            (385 * scale, shaft_y),
            (360 * scale, (shaft_y + 11 * scale)),
        ],
        fill=arrow_color,
    )

    # (No "DRAG TO INSTALL" caption under the arrow on purpose. The
    # title + subtitle already say it; an additional label rendered at
    # the arrow's Y coordinate ends up running under the Applications
    # icon's right half because Finder draws the icon label on the same
    # row, and the result is half-occluded ghost text. The dashed
    # arrow alone is the universally-recognised "drag along this
    # path" affordance and reads cleaner.)
    _ = caption  # keep the font load lazy — harmless, removes flake8 unused-var.

    img.save(out_path, optimize=True)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/dmg-bg.png"
    scale = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    main(out, scale)
