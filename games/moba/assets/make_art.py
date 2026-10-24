# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) fuer Lanebreakers.
# Aufruf: python3 games/moba/assets/make_art.py <ausgabeordner>
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TITLE_FONT = os.path.join(HERE, "fonts", "LuckiestGuy-Regular.ttf")
BODY_FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
SS = 2
INK = (14, 18, 34)
DAWN = (255, 184, 64)
DUSK = (150, 110, 255)
CREAM = (255, 240, 220)


def shade(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(size):
    """Tintenblau, links goldenes, rechts violettes Leuchten, diagonal getrennt."""
    w, h = size
    img = Image.new("RGBA", size, INK + (255,))
    for color, cx in ((DAWN, -0.05), (DUSK, 1.05)):
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        r = max(w, h) * 0.75
        d.ellipse((cx * w - r, h * 0.5 - r, cx * w + r, h * 0.5 + r), fill=color + (150,))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(max(w, h) * 0.18)))
    # Diagonaler Lichtstreifen in der Mitte
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon([(w * 0.47, 0), (w * 0.55, 0), (w * 0.53, h), (w * 0.45, h)], fill=CREAM + (60,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(w * 0.02)))
    return img


def glow(img, xy, radius, color, strength=200):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    x, y = xy
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (strength,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * 0.5)))


def crystal(img, center, size, color, outline=INK):
    """Facettierter Kristall (Raute mit hellen und dunklen Flaechen)."""
    d = ImageDraw.Draw(img)
    x, y = center
    top, bottom = (x, y - size * 1.25), (x, y + size * 1.25)
    left, right = (x - size * 0.8, y), (x + size * 0.8, y)
    mid = (x, y - size * 0.1)
    ow = max(3, int(size * 0.08))
    d.polygon([top, right, bottom, left], fill=outline)
    s = size * 0.9
    top2, bottom2 = (x, y - s * 1.25), (x, y + s * 1.25)
    left2, right2 = (x - s * 0.8, y), (x + s * 0.8, y)
    d.polygon([top2, mid, left2], fill=mix(color, (255, 255, 255), 0.45))
    d.polygon([top2, right2, mid], fill=mix(color, (255, 255, 255), 0.15))
    d.polygon([left2, mid, bottom2], fill=color)
    d.polygon([mid, right2, bottom2], fill=shade(color, 0.7))
    d.line([top2, mid, bottom2], fill=outline, width=max(1, ow // 3))
    d.polygon([(x - s * 0.35, y - s * 0.75), (x - s * 0.18, y - s * 0.9), (x - s * 0.1, y - s * 0.45)], fill=(255, 255, 255))


def sword(img, start, end, width, blade, hilt):
    d = ImageDraw.Draw(img)
    sx, sy = start
    ex, ey = end
    ang = math.atan2(ey - sy, ex - sx)
    nx, ny = -math.sin(ang), math.cos(ang)
    length = math.hypot(ex - sx, ey - sy)

    def p(t, o):
        return (sx + (ex - sx) * t + nx * o, sy + (ey - sy) * t + ny * o)

    ow = width * 0.18
    # Klinge mit Umriss
    d.polygon([p(0.28, -width / 2 - ow), p(0.92, -width / 2 - ow), p(1.0 + ow / length, 0), p(0.92, width / 2 + ow), p(0.28, width / 2 + ow)], fill=INK)
    d.polygon([p(0.29, -width / 2), p(0.92, -width / 2), p(1.0, 0), p(0.92, width / 2), p(0.29, width / 2)], fill=blade)
    d.polygon([p(0.29, 0), p(0.92, 0), p(1.0, 0), p(0.92, width / 2), p(0.29, width / 2)], fill=shade(blade, 0.78))
    # Parierstange und Griff
    d.polygon([p(0.24, -width * 1.6), p(0.3, -width * 1.6), p(0.3, width * 1.6), p(0.24, width * 1.6)], fill=hilt, outline=INK, width=int(ow))
    d.polygon([p(0.04, -width * 0.35), p(0.24, -width * 0.35), p(0.24, width * 0.35), p(0.04, width * 0.35)], fill=shade(hilt, 0.6), outline=INK, width=int(ow))
    cx, cy = p(0.03, 0)
    r = width * 0.55
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hilt, outline=INK, width=int(ow))


def sparks(img, count, rng, area):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = area
    for _ in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        s = rng.uniform(4, 12) * SS
        t = s * 0.25
        color = rng.choice([DAWN, DUSK, CREAM])
        d.polygon([(x, y - s), (x + t, y - t), (x + s, y), (x + t, y + t), (x, y + s), (x - t, y + t), (x - s, y), (x - t, y - t)], fill=color)


def gradient_text(img, xy, string, size, colors, stroke, anchor="mm"):
    font = ImageFont.truetype(TITLE_FONT, size)
    sw = max(4, size // 11)
    d = ImageDraw.Draw(img)
    x, y = xy
    # Schatten und Umriss
    d.text((x + sw * 0.5, y + sw * 0.9), string, font=font, fill=(0, 0, 0, 170), anchor=anchor, stroke_width=sw, stroke_fill=(0, 0, 0, 170))
    d.text(xy, string, font=font, fill=stroke, anchor=anchor, stroke_width=sw, stroke_fill=stroke)
    # Farbverlauf ueber eine Maske
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text(xy, string, font=font, fill=255, anchor=anchor)
    left, top, right, bottom = mask.getbbox()
    grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for gx in range(left, right):
        t = (gx - left) / max(1, right - left - 1)
        if t < 0.5:
            c = mix(colors[0], colors[1], t * 2)
        else:
            c = mix(colors[1], colors[2], (t - 0.5) * 2)
        gd.line([(gx, top), (gx, bottom)], fill=c + (255,))
    # Glanz oben
    shine = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shine).rectangle((left, top, right, top + (bottom - top) * 0.42), fill=(255, 255, 255, 70))
    grad.alpha_composite(shine)
    img.paste(grad, (0, 0), mask)


def pill(img, center, string, size, color, text_color=INK):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(BODY_FONT, size)
    l, t, r, b = d.textbbox((0, 0), string, font=font)
    w, h = r - l + size * 1.3, b - t + size * 0.8
    x, y = center
    d.rounded_rectangle((x - w / 2 + 4, y - h / 2 + 6, x + w / 2 + 4, y + h / 2 + 6), radius=h / 2, fill=(0, 0, 0, 120))
    d.rounded_rectangle((x - w / 2, y - h / 2, x + w / 2, y + h / 2), radius=h / 2, fill=color, outline=INK, width=max(3, size // 9))
    d.text((x, y), string, font=font, fill=text_color, anchor="mm")


def tower(img, base, height, color):
    """Turm im Spielstil: Sockel, Saeule mit Leuchtringen, schwebender Kristall."""
    d = ImageDraw.Draw(img)
    x, y = base
    w = height * 0.22
    ow = max(3, int(w * 0.08))
    stone = (232, 220, 196) if color == DAWN else (120, 110, 160)
    d.rounded_rectangle((x - w * 0.9, y - w * 0.5, x + w * 0.9, y + w * 0.15), radius=w * 0.15, fill=shade(stone, 0.75), outline=INK, width=ow)
    d.rectangle((x - w / 2, y - height, x + w / 2, y - w * 0.5), fill=stone, outline=INK, width=ow)
    d.rectangle((x - w / 2, y - height, x - w * 0.1, y - w * 0.5), fill=mix(stone, (255, 255, 255), 0.25))
    for t in (0.3, 0.85):
        yy = y - height * t
        d.rectangle((x - w * 0.58, yy - w * 0.12, x + w * 0.58, yy + w * 0.12), fill=color, outline=INK, width=ow // 2)
    d.rounded_rectangle((x - w * 0.75, y - height - w * 0.25, x + w * 0.75, y - height + w * 0.05), radius=w * 0.1, fill=(90, 84, 110), outline=INK, width=ow)
    glow(img, (x, y - height - w * 1.2), w * 1.4, color, 170)
    crystal(img, (x, y - height - w * 1.2), w * 0.75, color)


def make_icon(path):
    size = 512 * SS
    img = background((size, size))
    glow(img, (size // 2, int(size * 0.47)), size * 0.36, CREAM, 120)
    sword(img, (size * 0.12, size * 0.9), (size * 0.84, size * 0.14), size * 0.07, (230, 236, 250), DAWN)
    sword(img, (size * 0.88, size * 0.9), (size * 0.16, size * 0.14), size * 0.07, (230, 236, 250), DUSK)
    glow(img, (size // 2, int(size * 0.47)), size * 0.2, (255, 255, 255), 160)
    crystal(img, (size // 2, int(size * 0.47)), size * 0.19, mix(mix(DAWN, DUSK, 0.5), (255, 255, 255), 0.3))
    rng = random.Random(4)
    sparks(img, 14, rng, (size * 0.08, size * 0.06, size * 0.92, size * 0.7))
    pill(img, (size // 2, int(size * 0.86)), "5v5", int(size * 0.085), CREAM)
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(path)


def make_thumbnail(path):
    w, h = 1920 * SS, 1080 * SS
    img = background((w, h))
    d = ImageDraw.Draw(img)
    # Lane in Perspektive, die sich in der Mitte trifft
    horizon = h * 0.62
    d.polygon([(w * 0.5 - w * 0.03, horizon), (w * 0.5 + w * 0.03, horizon), (w * 0.78, h), (w * 0.22, h)], fill=(214, 192, 150, 255))
    d.polygon([(w * 0.5 - w * 0.03, horizon), (w * 0.5, horizon), (w * 0.5, h), (w * 0.22, h)], fill=(232, 212, 172, 255))
    for i in range(1, 7):
        t = (i / 7) ** 1.7
        y = horizon + (h - horizon) * t
        half = w * 0.03 + (w * 0.28 - w * 0.03) * t
        d.line([(w * 0.5 - half, y), (w * 0.5 + half, y)], fill=(180, 156, 118, 255), width=max(2, int(6 * SS * t)))
    # Tuerme links (Dawn) und rechts (Dusk)
    tower(img, (int(w * 0.12), int(h * 0.97)), h * 0.42, DAWN)
    tower(img, (int(w * 0.88), int(h * 0.97)), h * 0.42, DUSK)
    # Gekreuzte Klingen und Kern in der Mitte
    cx, cy = w * 0.5, h * 0.66
    sword(img, (cx - h * 0.32, cy + h * 0.24), (cx + h * 0.3, cy - h * 0.26), h * 0.045, (230, 236, 250), DAWN)
    sword(img, (cx + h * 0.32, cy + h * 0.24), (cx - h * 0.3, cy - h * 0.26), h * 0.045, (230, 236, 250), DUSK)
    glow(img, (int(cx), int(cy)), h * 0.16, (255, 255, 255), 150)
    crystal(img, (int(cx), int(cy)), h * 0.11, mix(mix(DAWN, DUSK, 0.5), (255, 255, 255), 0.3))
    rng = random.Random(8)
    sparks(img, 30, rng, (w * 0.05, h * 0.03, w * 0.95, h * 0.6))
    gradient_text(img, (w // 2, int(h * 0.2)), "LANEBREAKERS", int(h * 0.19), (DAWN, CREAM, DUSK), INK)
    gradient_text(img, (w // 2, int(h * 0.36)), "HERO ARENA", int(h * 0.08), ((235, 235, 245), (255, 255, 255), (235, 235, 245)), INK)
    pill(img, (int(w * 0.265), int(h * 0.92)), "5v5 MOBA", int(h * 0.04), DAWN)
    pill(img, (int(w * 0.425), int(h * 0.92)), "8 HEROES", int(h * 0.04), CREAM)
    pill(img, (int(w * 0.665), int(h * 0.92)), "PLAY SOLO WITH BOTS", int(h * 0.04), DUSK, (255, 255, 255))
    img.convert("RGB").resize((1920, 1080), Image.LANCZOS).save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else HERE
    make_icon(f"{out}/icon.png")
    make_thumbnail(f"{out}/thumbnail.png")
