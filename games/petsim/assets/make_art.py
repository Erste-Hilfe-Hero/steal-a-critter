# Erzeugt Icon (512x512) und zwei Vorschaubilder (1920x1080).
# Aufruf: python3 games/petsim/assets/make_art.py <ausgabeordner> <Fredoka.ttf>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
FONT = sys.argv[2] if len(sys.argv) > 2 else "Fredoka.ttf"
SS = 2  # Supersampling fuer glatte Kanten
INK = (34, 22, 50)


def font(size, weight=b"Bold"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def background(size, inner, outer, center, rays=20, ray_alpha=34):
    w, h = size
    small = Image.new("RGB", (w // 8, h // 8))
    sp = small.load()
    cx, cy = center
    maxd = math.hypot(max(cx, w - cx), max(cy, h - cy))
    for y in range(small.height):
        for x in range(small.width):
            t = min(1, math.hypot(x * 8 - cx, y * 8 - cy) / maxd) ** 0.85
            sp[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    img = small.resize(size, Image.BICUBIC).convert("RGBA")
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = maxd * 1.6
    for i in range(rays):
        a0 = (i / rays) * 2 * math.pi
        a1 = a0 + math.pi / rays
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, ray_alpha))
    img.alpha_composite(layer)
    return img


def glow(img, xy, radius, color, strength=170):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x, y = xy
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (strength,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.5)))


def shadow(img, box, blur, alpha=90):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=(20, 10, 40, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def darker(c, f=0.75):
    return tuple(int(v * f) for v in c[:3])


def lighter(c, f=0.45):
    return tuple(int(v + (255 - v) * f) for v in c[:3])


def sparkle(d, x, y, r, color=(255, 255, 255)):
    d.polygon([(x, y - r), (x + r * 0.22, y - r * 0.22), (x + r, y), (x + r * 0.22, y + r * 0.22), (x, y + r), (x - r * 0.22, y + r * 0.22), (x - r, y), (x - r * 0.22, y - r * 0.22)], fill=color)


def pet(img, cx, cy, s, color, ears="round", horn=False, wings=False, golden=False, crown=False, look=0.0):
    """Rundes Haustier: Koerper, Ohren, grosse Augen, Baeckchen. s = Radius."""
    if golden:
        color = (255, 205, 60)
    d = ImageDraw.Draw(img)
    outline = max(2, int(s * 0.07))
    shadow(img, (cx - s * 0.9, cy + s * 0.75, cx + s * 0.9, cy + s * 1.1), s * 0.12)
    d = ImageDraw.Draw(img)
    if wings:
        for side in (-1, 1):
            wx = cx + side * s * 1.05
            d.ellipse((wx - s * 0.55, cy - s * 0.55, wx + s * 0.55, cy + s * 0.15), fill=(255, 255, 255), outline=INK, width=outline)
    if ears == "round":
        for side in (-1, 1):
            ex, ey = cx + side * s * 0.62, cy - s * 0.72
            d.ellipse((ex - s * 0.3, ey - s * 0.3, ex + s * 0.3, ey + s * 0.3), fill=darker(color, 0.85), outline=INK, width=outline)
            d.ellipse((ex - s * 0.15, ey - s * 0.15, ex + s * 0.15, ey + s * 0.15), fill=(255, 170, 190))
    elif ears == "pointy":
        for side in (-1, 1):
            bx = cx + side * s * 0.55
            d.polygon([(bx - s * 0.32, cy - s * 0.55), (bx + side * s * 0.12, cy - s * 1.25), (bx + s * 0.32, cy - s * 0.5)], fill=darker(color, 0.85), outline=INK, width=outline)
    if horn:
        d.polygon([(cx - s * 0.16, cy - s * 0.85), (cx, cy - s * 1.55), (cx + s * 0.16, cy - s * 0.85)], fill=(255, 225, 110), outline=INK, width=outline)
    # Koerper mit Licht oben links
    d.ellipse((cx - s, cy - s * 0.95, cx + s, cy + s * 0.95), fill=color, outline=INK, width=outline)
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((cx - s * 0.7, cy - s * 0.8, cx + s * 0.1, cy - s * 0.15), fill=lighter(color, 0.6) + (150,))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(s * 0.12)))
    d = ImageDraw.Draw(img)
    # Bauch
    d.ellipse((cx - s * 0.55, cy + s * 0.05, cx + s * 0.55, cy + s * 0.85), fill=lighter(color, 0.5))
    # Augen
    for side in (-1, 1):
        ex, ey = cx + side * s * 0.36 + look * s * 0.08, cy - s * 0.12
        d.ellipse((ex - s * 0.2, ey - s * 0.26, ex + s * 0.2, ey + s * 0.26), fill=INK)
        d.ellipse((ex - s * 0.09, ey - s * 0.2, ex + s * 0.05, ey - s * 0.05), fill=(255, 255, 255))
        d.ellipse((ex + s * 0.04, ey + s * 0.06, ex + s * 0.11, ey + s * 0.13), fill=(255, 255, 255))
        bx = cx + side * s * 0.62
        d.ellipse((bx - s * 0.15, cy + s * 0.12, bx + s * 0.15, cy + s * 0.3), fill=(255, 130, 160))
    # Laecheln
    d.arc((cx - s * 0.16, cy + s * 0.05, cx + s * 0.16, cy + s * 0.3), 20, 160, fill=INK, width=outline)
    if crown:
        y0 = cy - s * 1.05
        pts = [(cx - s * 0.4, y0), (cx - s * 0.4, y0 - s * 0.35), (cx - s * 0.2, y0 - s * 0.15), (cx, y0 - s * 0.45), (cx + s * 0.2, y0 - s * 0.15), (cx + s * 0.4, y0 - s * 0.35), (cx + s * 0.4, y0)]
        d.polygon(pts, fill=(255, 210, 40), outline=INK, width=outline)
    if golden:
        for _ in range(6):
            a = random.random() * math.tau
            r = s * random.uniform(1.0, 1.35)
            sparkle(d, cx + math.cos(a) * r, cy + math.sin(a) * r, s * random.uniform(0.08, 0.16), (255, 245, 180))


def egg(img, cx, cy, s, color, spots=(255, 255, 255), cracked=False):
    """Ei mit Punkten. s = halbe Breite."""
    d = ImageDraw.Draw(img)
    outline = max(2, int(s * 0.06))
    shadow(img, (cx - s * 0.9, cy + s * 1.05, cx + s * 0.9, cy + s * 1.4), s * 0.12)
    d = ImageDraw.Draw(img)
    d.ellipse((cx - s, cy - s * 1.35, cx + s, cy + s * 1.25), fill=color, outline=INK, width=outline)
    for ox, oy, r in ((-0.45, -0.5, 0.2), (0.35, -0.1, 0.26), (-0.2, 0.55, 0.18), (0.5, 0.65, 0.12)):
        d.ellipse((cx + ox * s - r * s, cy + oy * s - r * s, cx + ox * s + r * s, cy + oy * s + r * s), fill=spots)
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((cx - s * 0.7, cy - s * 1.15, cx - s * 0.1, cy - s * 0.4), fill=(255, 255, 255, 120))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(s * 0.1)))
    if cracked:
        d = ImageDraw.Draw(img)
        y = cy - s * 0.2
        pts = [(cx - s, y)]
        for i in range(1, 8):
            pts.append((cx - s + i * s * 2 / 7, y + (-1) ** i * s * 0.14))
        d.line(pts, fill=INK, width=outline, joint="curve")


def coin(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    w = max(2, int(r * 0.12))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 200, 40), outline=INK, width=w)
    d.ellipse((cx - r * 0.68, cy - r * 0.68, cx + r * 0.68, cy + r * 0.68), outline=(255, 235, 140), width=w)
    d.ellipse((cx - r * 0.55, cy - r * 0.6, cx - r * 0.1, cy - r * 0.2), fill=(255, 245, 190))


def outlined_text(img, xy, text, f, fill, stroke, width, anchor="mm", shadow_offset=None):
    d = ImageDraw.Draw(img)
    if shadow_offset:
        x, y = xy
        d.text((x + shadow_offset, y + shadow_offset), text, font=f, fill=(30, 15, 50, 160), anchor=anchor, stroke_width=width, stroke_fill=(30, 15, 50, 160))
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=width, stroke_fill=stroke)


def finish(img, size, path):
    img.resize(size, Image.LANCZOS).save(path, optimize=True)
    print("wrote", path)


def make_icon(path):
    random.seed(4)
    W = 512 * SS
    img = background((W, W), (120, 255, 220), (60, 90, 230), (W / 2, W * 0.55), rays=18, ray_alpha=40)
    glow(img, (W / 2, W * 0.58), W * 0.36, (255, 245, 170), 200)
    s = W * 0.27
    # Aufgebrochenes goldenes Ei, aus dem ein Haustier schaut
    egg(img, W / 2, W * 0.66, s, (255, 205, 60), spots=(255, 236, 150))
    cut = Image.new("RGBA", img.size, (0, 0, 0, 0))
    img.alpha_composite(cut)
    pet(img, W / 2, W * 0.42, s * 0.85, (130, 205, 255), ears="pointy", look=0.2)
    d = ImageDraw.Draw(img)
    # Zackiger Eierschalen-Rand vor dem Haustier
    y = W * 0.56
    pts = [(W / 2 - s * 1.0, y + s * 0.15)]
    for i in range(9):
        pts.append((W / 2 - s + (i + 0.5) * s * 2 / 9, y + (s * 0.22 if i % 2 else -s * 0.05)))
    pts.append((W / 2 + s * 1.0, y + s * 0.15))
    # Fuellung bis weit in das untere Ei, sichtbar ist nur die Zackenkante
    d.polygon(pts + [(W / 2 + s * 0.9, y + s * 0.6), (W / 2 - s * 0.9, y + s * 0.6)], fill=(255, 205, 60))
    d.line(pts, fill=INK, width=int(s * 0.06), joint="curve")
    # Schalenstueck oben auf dem Kopf
    d.polygon([(W * 0.4, W * 0.17), (W * 0.47, W * 0.11), (W * 0.53, W * 0.15), (W * 0.6, W * 0.1), (W * 0.62, W * 0.18), (W * 0.5, W * 0.21)], fill=(255, 205, 60), outline=INK, width=int(s * 0.06))
    for x, y, r in ((0.16, 0.2, 0.05), (0.84, 0.28, 0.04), (0.12, 0.62, 0.035), (0.88, 0.7, 0.05), (0.75, 0.12, 0.03)):
        sparkle(d, W * x, W * y, W * r)
    coin(img, W * 0.18, W * 0.86, W * 0.07)
    coin(img, W * 0.83, W * 0.88, W * 0.06)
    finish(img, (512, 512), path)


def make_thumbnail(path, variant):
    random.seed(7 + variant)
    W, H = 1920 * SS, 1080 * SS
    if variant == 0:
        img = background((W, H), (140, 255, 230), (70, 80, 220), (W / 2, H * 0.62))
    else:
        img = background((W, H), (255, 225, 120), (240, 90, 160), (W / 2, H * 0.62))
    glow(img, (W / 2, H * 0.68), H * 0.38, (255, 250, 200), 170)
    d = ImageDraw.Draw(img)
    for _ in range(26):
        sparkle(d, random.uniform(0, W), random.uniform(0, H), random.uniform(10, 26) * SS)
    # Eier im Hintergrund
    egg(img, W * 0.1, H * 0.72, H * 0.1, (150, 230, 120))
    egg(img, W * 0.9, H * 0.7, H * 0.11, (110, 90, 220), spots=(190, 170, 255))
    for x, y, r in ((0.2, 0.92, 40), (0.27, 0.85, 30), (0.75, 0.93, 42), (0.82, 0.86, 28), (0.5, 0.95, 34)):
        coin(img, W * x, H * y, r * SS)
    # Haustiere in einer Reihe, das goldene in der Mitte
    pet(img, W * 0.24, H * 0.7, H * 0.12, (255, 160, 80), ears="pointy", look=0.5)
    pet(img, W * 0.37, H * 0.66, H * 0.14, (130, 205, 255), ears="round", look=0.4)
    pet(img, W * 0.5, H * 0.63, H * 0.19, (255, 205, 60), ears="pointy", golden=True, crown=True)
    pet(img, W * 0.63, H * 0.66, H * 0.14, (200, 140, 255), ears="round", horn=True, look=-0.4)
    pet(img, W * 0.76, H * 0.7, H * 0.12, (110, 220, 140), ears="none", look=-0.5)
    title = "CRITTER HATCH" if variant == 0 else "HATCH GOLDEN PETS!"
    outlined_text(img, (W / 2, H * 0.15), title, font(150 * SS), (255, 230, 70), INK, 12 * SS, shadow_offset=10 * SS)
    sub = "SIMULATOR" if variant == 0 else "6 WORLDS  •  32 PETS  •  1 IN 2000 MYTHIC"
    outlined_text(img, (W / 2, H * 0.3), sub, font((110 if variant == 0 else 64) * SS), (255, 255, 255), INK, 9 * SS, shadow_offset=7 * SS)
    finish(img, (1920, 1080), path)


if __name__ == "__main__":
    make_icon(f"{OUT}/icon.png")
    make_thumbnail(f"{OUT}/thumbnail.png", 0)
    make_thumbnail(f"{OUT}/thumbnail_golden.png", 1)
