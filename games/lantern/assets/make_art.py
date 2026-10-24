# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) fuer Lantern Legends.
# Stil: Nachtblau/Violett mit warmem Bernstein-Laternenlicht und Beute-Lichtsaeulen.
# Aufruf: python3 games/lantern/assets/make_art.py <ausgabeordner>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
SS = 2  # Supersampling fuer glatte Kanten
INK = (14, 12, 30)
AMBER = (255, 184, 74)
RARITY = [(90, 220, 110), (80, 160, 255), (190, 90, 255), (255, 160, 40), (255, 70, 120)]


def gradient(size, stops):
    w, h = size
    small = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                small.putpixel((0, y), tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)))
                break
    return small.resize(size, Image.BICUBIC).convert("RGBA")


def glow(img, xy, radius, color, strength=200):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x, y = xy
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (strength,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.45)))


def stars(img, rng, count, max_y):
    d = ImageDraw.Draw(img)
    w, _ = img.size
    for _ in range(count):
        x, y = rng.uniform(0, w), rng.uniform(0, max_y)
        r = rng.uniform(1, 3) * SS
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 240, 210, rng.randint(120, 255)))


def beam(img, x, ground, height, width, color):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle((x - width, ground - height, x + width, ground), fill=color + (150,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(width * 0.9)))
    d2 = ImageDraw.Draw(img)
    d2.rectangle((x - width * 0.35, ground - height, x + width * 0.35, ground), fill=tuple(min(255, c + 80) for c in color) + (230,))
    # Edelstein am Fuss
    s = width * 1.4
    d2.polygon([(x, ground - s * 2.2), (x + s, ground - s * 1.1), (x, ground), (x - s, ground - s * 1.1)], fill=color, outline=INK, width=max(2, int(width * 0.25)))


def lantern(img, cx, top, scale, swing=0.0, light=1.0):
    """Grosse Laterne: Kette, Dach, leuchtendes Glas mit Flamme, Boden."""
    d = ImageDraw.Draw(img)
    s = scale
    out = max(3, int(s * 0.06))
    metal = (78, 58, 44)
    chain_bottom = top + s * 0.9
    d.line((cx, top, cx + swing * s, chain_bottom), fill=metal, width=int(s * 0.07))
    x = cx + swing * s
    glow(img, (int(x), int(chain_bottom + s * 1.35)), s * 2.2 * light, AMBER, int(170 * light))
    glow(img, (int(x), int(chain_bottom + s * 1.35)), s * 1.1, (255, 230, 150), 200)
    d = ImageDraw.Draw(img)
    # Ring und Dach
    d.ellipse((x - s * 0.18, chain_bottom - s * 0.1, x + s * 0.18, chain_bottom + s * 0.26), outline=metal, width=int(s * 0.07))
    d.polygon([(x - s * 0.7, chain_bottom + s * 0.55), (x, chain_bottom + s * 0.18), (x + s * 0.7, chain_bottom + s * 0.55)], fill=metal, outline=INK, width=out)
    d.rounded_rectangle((x - s * 0.62, chain_bottom + s * 0.5, x + s * 0.62, chain_bottom + s * 0.7), radius=s * 0.06, fill=metal, outline=INK, width=out)
    # Glas
    gx0, gy0, gx1, gy1 = x - s * 0.5, chain_bottom + s * 0.7, x + s * 0.5, chain_bottom + s * 2.0
    d.rounded_rectangle((gx0, gy0, gx1, gy1), radius=s * 0.12, fill=(255, 160, 50), outline=INK, width=out)
    d.rounded_rectangle((gx0 + s * 0.08, gy0 + s * 0.06, gx1 - s * 0.08, gy1 - s * 0.06), radius=s * 0.1, fill=(255, 196, 90))
    # Flamme
    fx, fy = x, gy0 + (gy1 - gy0) * 0.6
    d.ellipse((fx - s * 0.2, fy - s * 0.38, fx + s * 0.2, fy + s * 0.22), fill=(255, 245, 190))
    d.polygon([(fx - s * 0.17, fy - s * 0.12), (fx, fy - s * 0.62), (fx + s * 0.17, fy - s * 0.12)], fill=(255, 245, 190))
    d.ellipse((fx - s * 0.09, fy - s * 0.12, fx + s * 0.09, fy + s * 0.14), fill=(255, 255, 240))
    # Streben
    for k in (-1, 1):
        d.line((x + k * s * 0.22, gy0, x + k * s * 0.22, gy1), fill=metal, width=int(s * 0.06))
    d.rounded_rectangle((x - s * 0.62, gy1 - s * 0.02, x + s * 0.62, gy1 + s * 0.2), radius=s * 0.06, fill=metal, outline=INK, width=out)


def sword(img, cx, cy, length, angle, blade=(220, 225, 235)):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = length * 0.08
    pts = [(-w, -length * 0.5), (0, -length * 0.62), (w, -length * 0.5), (w, length * 0.25), (-w, length * 0.25)]
    guard = [(-w * 3.2, length * 0.25), (w * 3.2, length * 0.25), (w * 3.2, length * 0.31), (-w * 3.2, length * 0.31)]
    grip = [(-w * 0.6, length * 0.31), (w * 0.6, length * 0.31), (w * 0.6, length * 0.5), (-w * 0.6, length * 0.5)]
    a = math.radians(angle)

    def tr(p):
        return (cx + p[0] * math.cos(a) - p[1] * math.sin(a), cy + p[0] * math.sin(a) + p[1] * math.cos(a))

    ow = max(3, int(length * 0.02))
    d.polygon([tr(p) for p in pts], fill=blade, outline=INK, width=ow)
    d.polygon([tr(p) for p in guard], fill=AMBER, outline=INK, width=ow)
    d.polygon([tr(p) for p in grip], fill=(110, 70, 50), outline=INK, width=ow)
    img.alpha_composite(layer)


def slime(img, cx, ground, r, color):
    d = ImageDraw.Draw(img)
    out = max(3, int(r * 0.08))
    d.ellipse((cx - r, ground - r * 1.5, cx + r, ground + r * 0.1), fill=color, outline=INK, width=out)
    d.ellipse((cx - r * 0.55, ground - r * 1.25, cx - r * 0.2, ground - r * 0.95), fill=(255, 255, 255, 200))
    for k in (-1, 1):
        ex = cx + k * r * 0.38
        d.ellipse((ex - r * 0.2, ground - r * 0.95, ex + r * 0.2, ground - r * 0.5), fill=(255, 255, 255), outline=INK, width=max(2, out // 2))
        d.ellipse((ex - r * 0.09, ground - r * 0.8, ex + r * 0.09, ground - r * 0.55), fill=INK)


def text(img, xy, string, size, fill, stroke, anchor="mm"):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    sw = max(4, size // 9)
    x, y = xy
    d.text((x + sw * 0.5, y + sw * 0.9), string, font=font, fill=(0, 0, 0, 160), anchor=anchor, stroke_width=sw, stroke_fill=(0, 0, 0, 160))
    d.text(xy, string, font=font, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)


def pill(img, center, string, size, color):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    l, t, r, b = d.textbbox((0, 0), string, font=font)
    w, h = r - l + size * 1.2, b - t + size * 0.7
    x, y = center
    d.rounded_rectangle((x - w / 2, y - h / 2, x + w / 2, y + h / 2), radius=h / 2, fill=color, outline=INK, width=max(3, size // 10))
    d.text((x, y), string, font=font, fill=(255, 255, 255), anchor="mm")


def make_icon(path):
    size = 512 * SS
    img = gradient((size, size), [(0, (30, 34, 84)), (0.65, (62, 40, 104)), (1, (22, 16, 44))])
    rng = random.Random(4)
    stars(img, rng, 40, size * 0.7)
    d = ImageDraw.Draw(img)
    d.ellipse((-size * 0.2, size * 0.8, size * 1.2, size * 1.4), fill=(30, 26, 52))
    beam(img, size * 0.16, size * 0.86, size * 0.5, size * 0.03, RARITY[3])
    beam(img, size * 0.84, size * 0.86, size * 0.42, size * 0.03, RARITY[2])
    sword(img, size * 0.5, size * 0.5, size * 0.85, -38)
    sword(img, size * 0.5, size * 0.5, size * 0.85, 38, blade=(200, 230, 255))
    lantern(img, size * 0.5, size * 0.1, size * 0.24, light=0.55)
    pill(img, (size // 2, int(size * 0.9)), "LOOT", int(size * 0.075), (210, 70, 60))
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(path)


def make_thumbnail(path):
    w, h = 1920 * SS, 1080 * SS
    img = gradient((w, h), [(0, (26, 30, 76)), (0.6, (66, 42, 108)), (1, (20, 16, 40))])
    rng = random.Random(9)
    stars(img, rng, 120, h * 0.6)
    d = ImageDraw.Draw(img)
    ground = h * 0.86
    d.rectangle((0, ground, w, h), fill=(34, 30, 58))
    d.rectangle((0, ground, w, ground + h * 0.012), fill=(70, 60, 100))
    for i, x in enumerate((0.08, 0.2, 0.8, 0.92)):
        beam(img, w * x, ground, h * (0.45 + 0.08 * (i % 2)), h * 0.018, RARITY[(i + 1) % 5])
    slime(img, w * 0.27, ground, h * 0.1, (110, 220, 90))
    slime(img, w * 0.13, ground, h * 0.06, (255, 110, 40))
    slime(img, w * 0.75, ground, h * 0.13, (170, 120, 255))
    slime(img, w * 0.88, ground, h * 0.07, (90, 230, 210))
    sword(img, w * 0.5, h * 0.62, h * 0.62, -32)
    sword(img, w * 0.5, h * 0.62, h * 0.62, 32, blade=(200, 230, 255))
    lantern(img, w * 0.5, h * 0.3, h * 0.17)
    text(img, (w // 2, int(h * 0.14)), "LANTERN LEGENDS", int(h * 0.13), AMBER, INK)
    pill(img, (int(w * 0.3), int(h * 0.94)), "CO-OP DUNGEONS", int(h * 0.042), (60, 120, 220))
    pill(img, (int(w * 0.7), int(h * 0.94)), "LEGENDARY LOOT", int(h * 0.042), (230, 130, 30))
    img.convert("RGB").resize((1920, 1080), Image.LANCZOS).save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    make_icon(f"{out}/icon.png")
    make_thumbnail(f"{out}/thumbnail.png")
