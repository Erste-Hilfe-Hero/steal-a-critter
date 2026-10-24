# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) fuer Magic Garden Tycoon.
# Aufruf: python3 games/tycoon/assets/make_art.py <ausgabeordner>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
SS = 2  # Supersampling fuer glatte Kanten
INK = (18, 40, 22)


def gradient(size, top, bottom):
    w, h = size
    small = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        small.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return small.resize(size, Image.BICUBIC).convert("RGBA")


def glow(img, xy, radius, color, strength=200):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x, y = xy
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (strength,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.45)))


def rays(img, center, count, alpha):
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    r = math.hypot(w, h)
    for i in range(count):
        a0 = i / count * 2 * math.pi
        a1 = a0 + math.pi / count
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(6 * SS)))


def shade(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color)


def fruit(img, center, radius, color, shine=True):
    """Glaenzende Kugel-Frucht mit dunklem Rand, Blattkrone und Glanzpunkt."""
    d = ImageDraw.Draw(img)
    x, y = center
    out = max(2, radius // 9)
    # Schatten
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius * 0.2 + radius, x + radius, y + radius * 0.35 + radius), fill=(0, 0, 0, 90))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.15)))
    d.ellipse((x - radius - out, y - radius - out, x + radius + out, y + radius + out), fill=INK)
    # Kugel mit Schattierung (konzentrische Kreise von dunkel nach hell)
    steps = 24
    for i in range(steps):
        t = i / steps
        r = radius * (1 - t * 0.85)
        ox, oy = -radius * 0.28 * t, -radius * 0.32 * t
        c = shade(color, 0.72 + 0.5 * t)
        d.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=c)
    if shine:
        d.ellipse((x - radius * 0.55, y - radius * 0.62, x - radius * 0.2, y - radius * 0.3), fill=(255, 255, 255, 230))
    # Blaetter oben
    leaf = (70, 190, 70)
    for ang in (-35, 0, 35):
        a = math.radians(ang - 90)
        lx, ly = x + math.cos(a) * radius * 0.95, y + math.sin(a) * radius * 0.95
        poly = []
        for k in range(16):
            t = k / 15 * math.pi * 2
            px = math.cos(t) * radius * 0.16
            py = math.sin(t) * radius * 0.36
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            poly.append((lx + px * ca - py * sa, ly + px * sa + py * ca - radius * 0.12))
        d.polygon(poly, fill=leaf, outline=INK, width=out)


def sparkle(img, xy, size, color=(255, 255, 210)):
    d = ImageDraw.Draw(img)
    x, y = xy
    s, t = size, size * 0.22
    d.polygon([(x, y - s), (x + t, y - t), (x + s, y), (x + t, y + t), (x, y + s), (x - t, y + t), (x - s, y), (x - t, y - t)], fill=color)


def text(img, xy, string, size, fill, stroke, anchor="mm", stroke_width=None):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    sw = stroke_width if stroke_width is not None else max(4, size // 9)
    x, y = xy
    d.text((x + sw * 0.6, y + sw * 0.9), string, font=font, fill=(0, 0, 0, 150), anchor=anchor, stroke_width=sw, stroke_fill=(0, 0, 0, 150))
    d.text(xy, string, font=font, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)


def pill(img, center, string, size, color):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    l, t, r, b = d.textbbox((0, 0), string, font=font)
    w, h = r - l + size * 1.2, b - t + size * 0.7
    x, y = center
    d.rounded_rectangle((x - w / 2, y - h / 2, x + w / 2, y + h / 2), radius=h / 2, fill=color, outline=INK, width=max(3, size // 10))
    d.text((x, y), string, font=font, fill=(255, 255, 255), anchor="mm")


def soil_rows(img, horizon, rng):
    """Beete in Perspektive mit kleinen Pflanzen."""
    w, h = img.size
    d = ImageDraw.Draw(img)
    d.rectangle((0, horizon, w, h), fill=(96, 176, 70))
    rows = 6
    for i in range(rows):
        t0, t1 = i / rows, (i + 0.62) / rows
        y0 = horizon + (h - horizon) * (t0 ** 1.6)
        y1 = horizon + (h - horizon) * (t1 ** 1.6)
        d.rectangle((0, y0, w, y1), fill=(122, 82, 50))
        d.rectangle((0, y0, w, y0 + max(2, (y1 - y0) * 0.15)), fill=(150, 104, 66))
        n = 7 + i * 2
        scale = 0.25 + t1 * 1.1
        for k in range(n):
            px = (k + 0.5 + rng.uniform(-0.2, 0.2)) / n * w
            py = (y0 + y1) / 2
            color = rng.choice([(235, 40, 60), (255, 140, 30), (60, 80, 230), (255, 220, 50), (255, 60, 170)])
            stem = 40 * SS * scale
            d.line((px, py, px, py - stem), fill=(50, 150, 50), width=int(max(2, 7 * SS * scale)))
            fruit(img, (int(px), int(py - stem)), int(16 * SS * scale), color, shine=scale > 0.6)


def make_icon(path):
    size = 512 * SS
    img = gradient((size, size), (120, 220, 255), (90, 200, 90))
    rays(img, (size // 2, size // 2), 20, 45)
    glow(img, (size // 2, size // 2), size * 0.38, (255, 250, 180), 220)
    # Beet unten
    d = ImageDraw.Draw(img)
    d.ellipse((-size * 0.2, size * 0.72, size * 1.2, size * 1.35), fill=INK)
    d.ellipse((-size * 0.18, size * 0.74, size * 1.18, size * 1.35), fill=(122, 82, 50))
    # Stiel und grosse goldene Frucht, daneben kleine Fruechte
    d.line((size * 0.5, size * 0.78, size * 0.5, size * 0.5), fill=INK, width=int(size * 0.05))
    d.line((size * 0.5, size * 0.78, size * 0.5, size * 0.5), fill=(60, 170, 60), width=int(size * 0.032))
    fruit(img, (int(size * 0.24), int(size * 0.7)), int(size * 0.11), (235, 40, 60))
    fruit(img, (int(size * 0.78), int(size * 0.68)), int(size * 0.12), (60, 90, 235))
    fruit(img, (size // 2, int(size * 0.42)), int(size * 0.24), (255, 200, 40))
    rng = random.Random(3)
    for _ in range(9):
        sparkle(img, (rng.uniform(0.1, 0.9) * size, rng.uniform(0.08, 0.6) * size), rng.uniform(10, 26) * SS)
    pill(img, (size // 2, int(size * 0.88)), "x50", int(size * 0.075), (255, 70, 160))
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(path)


def make_thumbnail(path):
    w, h = 1920 * SS, 1080 * SS
    img = gradient((w, h), (110, 200, 255), (190, 240, 255))
    rays(img, (w // 2, int(h * 0.3)), 28, 30)
    glow(img, (w // 2, int(h * 0.28)), h * 0.3, (255, 250, 200), 200)
    rng = random.Random(7)
    soil_rows(img, int(h * 0.5), rng)
    # Grosse Heldenfruechte vorne
    fruit(img, (int(w * 0.14), int(h * 0.72)), int(h * 0.16), (255, 60, 170))
    fruit(img, (int(w * 0.86), int(h * 0.7)), int(h * 0.18), (255, 200, 40))
    glow(img, (int(w * 0.86), int(h * 0.7)), h * 0.2, (255, 230, 120), 90)
    for _ in range(18):
        sparkle(img, (rng.uniform(0.03, 0.97) * w, rng.uniform(0.04, 0.5) * h), rng.uniform(12, 30) * SS)
    text(img, (w // 2, int(h * 0.17)), "MAGIC GARDEN", int(h * 0.15), (255, 236, 90), INK)
    text(img, (w // 2, int(h * 0.33)), "TYCOON", int(h * 0.13), (120, 255, 120), INK)
    pill(img, (int(w * 0.3), int(h * 0.92)), "GROWS WHILE OFFLINE", int(h * 0.045), (60, 160, 255))
    pill(img, (int(w * 0.7), int(h * 0.92)), "RAINBOW FRUITS x50", int(h * 0.045), (255, 70, 160))
    img.convert("RGB").resize((1920, 1080), Image.LANCZOS).save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    make_icon(f"{out}/icon.png")
    make_thumbnail(f"{out}/thumbnail.png")
