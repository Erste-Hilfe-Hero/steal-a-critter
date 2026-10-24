# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) fuer Colosseum Catcher.
# Stil: Kolosseum im Abendrot, Gold und Purpur, eigene Bestien (keine fremden Figuren).
# Aufruf: python3 assets/make_art.py <ausgabeordner>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

TITLE_FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
SS = 2  # Supersampling fuer glatte Kanten
INK = (28, 14, 26)
GOLD = (242, 193, 78)
GOLD_LIGHT = (255, 236, 160)
GOLD_DARK = (176, 112, 36)
CRIMSON = (150, 28, 40)
CREAM = (250, 238, 215)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def sky(size):
    w, h = size
    stops = [(0, (38, 18, 52)), (0.45, (120, 30, 60)), (0.78, (228, 112, 60)), (1, (252, 196, 110))]
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                local = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                img.putpixel((0, y), lerp(stops[i][1], stops[i + 1][1], local))
                break
    return img.resize(size).convert("RGBA")


def glow(base, center, radius, color, alpha=170):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    base.alpha_composite(layer)


def colosseum(base, top, height, arches):
    """Silhouette mit zwei Reihen leuchtender Boegen."""
    w, h = base.size
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # leicht gewoelbter Rand (Ellipse) fuer Tiefe
    d.ellipse([-w * 0.15, top, w * 1.15, top + height * 0.5], fill=INK + (255,))
    d.rectangle([0, top + height * 0.22, w, h], fill=INK + (255,))
    for row, (y0, y1) in enumerate([(0.3, 0.55), (0.65, 0.92)]):
        n = arches + row * 0
        for i in range(n):
            cx = (i + 0.5) / n * w
            aw = w / n * 0.55
            ay0 = top + height * y0
            ay1 = top + height * y1
            color = lerp((255, 170, 90), (255, 120, 60), row)
            d.rectangle([cx - aw / 2, ay0 + aw / 2, cx + aw / 2, ay1], fill=color + (170,))
            d.ellipse([cx - aw / 2, ay0, cx + aw / 2, ay0 + aw], fill=color + (170,))
    # Banner
    for i in range(1, arches, 3):
        cx = i / arches * w
        bw = w / arches * 0.4
        d.rectangle([cx - bw / 2, top + height * 0.02, cx + bw / 2, top + height * 0.28], fill=CRIMSON + (255,))
        d.rectangle([cx - bw / 2, top + height * 0.26, cx + bw / 2, top + height * 0.29], fill=GOLD + (255,))
    base.alpha_composite(layer)


def flame(d, cx, cy, size, colors):
    for i, color in enumerate(colors):
        s = size * (1 - i * 0.28)
        d.polygon([
            (cx - s * 0.5, cy),
            (cx - s * 0.35, cy - s * 0.7),
            (cx - s * 0.1, cy - s * 0.45),
            (cx, cy - s * 1.15),
            (cx + s * 0.15, cy - s * 0.5),
            (cx + s * 0.38, cy - s * 0.8),
            (cx + s * 0.5, cy),
        ], fill=color)
        d.ellipse([cx - s * 0.5, cy - s * 0.42, cx + s * 0.5, cy + s * 0.42], fill=color)


def eye(d, cx, cy, r, side, pupil=INK):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255), outline=INK, width=max(2, int(r * 0.14)))
    pr = r * 0.6
    px = cx + side * r * 0.12
    d.ellipse([px - pr, cy - pr * 0.9, px + pr, cy + pr * 1.05], fill=pupil)
    sr = r * 0.22
    d.ellipse([px - pr * 0.45 - sr, cy - pr * 0.55 - sr, px - pr * 0.45 + sr, cy - pr * 0.55 + sr], fill=(255, 255, 255))
    # entschlossene Augenbraue
    d.line([(cx - r * 1.05, cy - r * (1.25 if side < 0 else 1.0)), (cx + r * 1.05, cy - r * (1.0 if side < 0 else 1.25))], fill=INK, width=int(r * 0.32))


def fire_beast(base, cx, cy, s, facing=1):
    """Infernox-artiger Feuerfuchs (eigenes Design): Kopf, Ohren, Maehne aus Flammen."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    body = (235, 100, 45)
    dark = (170, 55, 30)
    light = (255, 205, 150)
    # Flammen-Maehne hinter dem Kopf
    for i in range(7):
        a = math.pi + (i / 6) * math.pi
        fx = cx + math.cos(a) * s * 0.62
        fy = cy + math.sin(a) * s * 0.55 + s * 0.05
        flame(d, fx, fy, s * 0.42, [(255, 90, 30), (255, 160, 40), (255, 230, 120)])
    # Ohren
    for side in (-1, 1):
        ex = cx + side * s * 0.38
        d.polygon([(ex - s * 0.2, cy - s * 0.25), (ex + side * s * 0.12, cy - s * 0.78), (ex + s * 0.2, cy - s * 0.2)], fill=body, outline=INK)
        d.polygon([(ex - s * 0.09, cy - s * 0.3), (ex + side * s * 0.08, cy - s * 0.6), (ex + s * 0.09, cy - s * 0.28)], fill=dark)
    # Kopf
    d.ellipse([cx - s * 0.55, cy - s * 0.48, cx + s * 0.55, cy + s * 0.5], fill=body, outline=INK, width=int(s * 0.04))
    # Schnauze
    d.ellipse([cx - s * 0.3 + facing * s * 0.05, cy + s * 0.02, cx + s * 0.3 + facing * s * 0.05, cy + s * 0.42], fill=light, outline=INK, width=int(s * 0.025))
    d.ellipse([cx - s * 0.07 + facing * s * 0.05, cy + s * 0.06, cx + s * 0.07 + facing * s * 0.05, cy + s * 0.16], fill=INK)
    # Grinsen mit Reisszahn
    mx = cx + facing * s * 0.05
    d.arc([mx - s * 0.16, cy + s * 0.12, mx + s * 0.16, cy + s * 0.34], 20, 160, fill=INK, width=int(s * 0.03))
    d.polygon([(mx + s * 0.07, cy + s * 0.31), (mx + s * 0.12, cy + s * 0.4), (mx + s * 0.13, cy + s * 0.3)], fill=(255, 255, 255))
    # Augen
    for side in (-1, 1):
        eye(d, cx + side * s * 0.24 + facing * s * 0.04, cy - s * 0.1, s * 0.13, side)
    base.alpha_composite(layer)


def water_beast(base, cx, cy, s, facing=-1):
    """Abyssaur-artiger Wasserdrache (eigenes Design): Kopf mit Flosse und Hoernern."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    body = (55, 125, 225)
    dark = (30, 70, 160)
    light = (170, 220, 255)
    # Rueckenflosse
    d.polygon([(cx - s * 0.2, cy - s * 0.35), (cx + s * 0.05, cy - s * 0.95), (cx + s * 0.32, cy - s * 0.3)], fill=light, outline=INK)
    for side in (-1, 1):
        hx = cx + side * s * 0.36
        d.polygon([(hx - s * 0.08, cy - s * 0.3), (hx + side * s * 0.2, cy - s * 0.72), (hx + s * 0.08, cy - s * 0.26)], fill=(245, 235, 210), outline=INK)
        # Seitenflossen
        d.polygon([(cx + side * s * 0.5, cy - s * 0.05), (cx + side * s * 0.85, cy - s * 0.25), (cx + side * s * 0.62, cy + s * 0.15)], fill=light, outline=INK)
    d.ellipse([cx - s * 0.55, cy - s * 0.45, cx + s * 0.55, cy + s * 0.5], fill=body, outline=INK, width=int(s * 0.04))
    d.ellipse([cx - s * 0.32 + facing * s * 0.06, cy + s * 0.05, cx + s * 0.32 + facing * s * 0.06, cy + s * 0.44], fill=light, outline=INK, width=int(s * 0.025))
    for side in (-1, 1):
        d.ellipse([cx + side * s * 0.1 + facing * s * 0.06 - s * 0.03, cy + s * 0.12, cx + side * s * 0.1 + facing * s * 0.06 + s * 0.03, cy + s * 0.17], fill=dark)
    mx = cx + facing * s * 0.06
    d.arc([mx - s * 0.18, cy + s * 0.14, mx + s * 0.18, cy + s * 0.36], 20, 160, fill=INK, width=int(s * 0.03))
    # Schuppen-Punkte
    for i in range(4):
        d.ellipse([cx - s * 0.42 + i * s * 0.07, cy - s * 0.32 + i * s * 0.02, cx - s * 0.38 + i * s * 0.07, cy - s * 0.28 + i * s * 0.02], fill=dark)
    for side in (-1, 1):
        eye(d, cx + side * s * 0.24 + facing * s * 0.04, cy - s * 0.1, s * 0.13, side, pupil=(20, 30, 70))
    base.alpha_composite(layer)


def orb(base, cx, cy, r):
    # Crest-Orb: purpurne Glaskugel mit goldenem Ring und Stern-Juwel (eigenes Design)
    glow(base, (cx, cy), int(r * 2.2), (255, 220, 140), 150)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = int(r * 0.12)
    for i in range(12):
        t = i / 11
        rr = r * (1 - t * 0.55)
        ox, oy = -r * 0.18 * t, -r * 0.2 * t
        d.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr], fill=lerp((90, 20, 70), (200, 60, 140), t))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK, width=w)
    # schraeger Goldring
    ring = Image.new("RGBA", base.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([cx - r * 1.32, cy - r * 0.34, cx + r * 1.32, cy + r * 0.34], outline=INK, width=int(r * 0.26))
    rd.ellipse([cx - r * 1.3, cy - r * 0.32, cx + r * 1.3, cy + r * 0.32], outline=GOLD, width=int(r * 0.16))
    ring = ring.rotate(-18, center=(cx, cy), resample=Image.BICUBIC)
    layer.alpha_composite(ring)
    # Stern-Juwel
    pts = []
    for k in range(8):
        a = math.radians(k * 45 - 90)
        rad = r * (0.42 if k % 2 == 0 else 0.15)
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    d = ImageDraw.Draw(layer)
    d.polygon(pts, fill=CREAM, outline=INK, width=max(2, int(r * 0.05)))
    d.ellipse([cx - r * 0.62, cy - r * 0.74, cx - r * 0.32, cy - r * 0.5], fill=(255, 210, 235))
    base.alpha_composite(layer)


def laurel(d, cx, cy, radius, side, leaf, color=(140, 175, 70)):
    for i in range(8):
        t = i / 7
        a = math.radians(110 + t * 120) if side < 0 else math.radians(70 - t * 120)
        x = cx + math.cos(a) * radius
        y = cy - math.sin(a) * radius * 0.9
        rot = a + math.pi / 2
        pts = []
        for k in range(16):
            u = k / 15 * 2 * math.pi
            px = math.cos(u) * leaf * 0.38
            py = math.sin(u) * leaf
            pts.append((x + px * math.cos(rot) - py * math.sin(rot), y + px * math.sin(rot) + py * math.cos(rot)))
        d.polygon(pts, fill=lerp(color, GOLD, 0.5), outline=INK)


def outlined_text(d, xy, text, font, fill, stroke, width, anchor="mm"):
    d.text(xy, text, font=font, fill=fill, stroke_width=width, stroke_fill=stroke, anchor=anchor)


def logo(base, cx, cy, scale):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    title = ImageFont.truetype(TITLE_FONT, int(150 * scale))
    sub = ImageFont.truetype(TITLE_FONT, int(78 * scale))
    laurel(d, cx - 560 * scale, cy + 40 * scale, 120 * scale, -1, 34 * scale)
    laurel(d, cx + 560 * scale, cy + 40 * scale, 120 * scale, 1, 34 * scale)
    # Schatten
    outlined_text(d, (cx + 8 * scale, cy + 10 * scale), "COLOSSEUM", title, INK, INK, int(14 * scale))
    outlined_text(d, (cx, cy), "COLOSSEUM", title, GOLD, INK, int(12 * scale))
    # Glanz oben auf dem Gold
    shine = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(shine).text((cx, cy), "COLOSSEUM", font=title, fill=GOLD_LIGHT + (255,), anchor="mm")
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).rectangle([0, 0, base.size[0], cy - 10 * scale], fill=200)
    layer.paste(shine, (0, 0), Image.composite(shine.split()[3], Image.new("L", base.size, 0), mask))
    # Purpur-Band mit "CATCHER"
    bw, bh = 520 * scale, 104 * scale
    by = cy + 120 * scale
    d.rounded_rectangle([cx - bw / 2 - 6 * scale, by - bh / 2 - 6 * scale, cx + bw / 2 + 6 * scale, by + bh / 2 + 6 * scale], radius=int(26 * scale), fill=INK)
    d.rounded_rectangle([cx - bw / 2, by - bh / 2, cx + bw / 2, by + bh / 2], radius=int(22 * scale), fill=CRIMSON, outline=GOLD, width=int(6 * scale))
    outlined_text(d, (cx, by + 2 * scale), "CATCHER", sub, CREAM, INK, int(6 * scale))
    base.alpha_composite(layer)


def sparkles(base, count, seed, area):
    rnd = random.Random(seed)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = area
    for _ in range(count):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        r = rnd.uniform(2, 7) * SS
        d.polygon([(x, y - r * 2), (x + r * 0.5, y - r * 0.5), (x + r * 2, y), (x + r * 0.5, y + r * 0.5), (x, y + r * 2), (x - r * 0.5, y + r * 0.5), (x - r * 2, y), (x - r * 0.5, y - r * 0.5)], fill=(255, 240, 200, rnd.randint(120, 230)))
    base.alpha_composite(layer)


def make_icon(path):
    size = 512 * SS
    img = sky((size, size))
    glow(img, (size // 2, int(size * 0.66)), int(size * 0.3), (255, 210, 130), 200)
    colosseum(img, int(size * 0.62), int(size * 0.42), 9)
    sparkles(img, 24, 3, (0, 0, size, size * 0.55))
    fire_beast(img, int(size * 0.47), int(size * 0.5), int(size * 0.5))
    orb(img, int(size * 0.8), int(size * 0.8), int(size * 0.13))
    # goldener Rahmen
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6 * SS, 6 * SS, size - 6 * SS, size - 6 * SS], radius=40 * SS, outline=GOLD, width=10 * SS)
    img = img.resize((512, 512), Image.LANCZOS).convert("RGB")
    img.save(path)


def make_thumbnail(path):
    w, h = 1920 * SS, 1080 * SS
    img = sky((w, h))
    glow(img, (w // 2, int(h * 0.74)), int(h * 0.36), (255, 210, 130), 200)
    colosseum(img, int(h * 0.62), int(h * 0.45), 16)
    sparkles(img, 60, 5, (0, 0, w, h * 0.6))
    # Duell: Feuer links gegen Wasser rechts, Blitze dazwischen
    glow(img, (int(w * 0.24), int(h * 0.62)), int(h * 0.24), (255, 120, 40), 160)
    glow(img, (int(w * 0.76), int(h * 0.62)), int(h * 0.24), (60, 150, 255), 160)
    fire_beast(img, int(w * 0.23), int(h * 0.64), int(h * 0.42), facing=1)
    water_beast(img, int(w * 0.77), int(h * 0.64), int(h * 0.42), facing=-1)
    orb(img, w // 2, int(h * 0.7), int(h * 0.09))
    logo(img, w // 2, int(h * 0.2), 1.0 * SS)
    img = img.resize((1920, 1080), Image.LANCZOS).convert("RGB")
    img.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    make_icon(f"{out}/icon.png")
    make_thumbnail(f"{out}/thumbnail.png")
    print("ok")
