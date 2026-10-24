# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) fuer surf_ski im "Alpine Aurora"-Stil.
# Aufruf: python3 games/surf/assets/make_art.py <ausgabeordner>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_ITALIC = "/usr/share/fonts/opentype/inter/Inter-BlackItalic.otf"
FONT_BOLD = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
SS = 2  # Supersampling fuer glatte Kanten

NAVY = (11, 21, 48)
ICE = (92, 225, 255)
AURORA = (255, 79, 163)
MINT = (110, 255, 190)
SNOW = (240, 248, 255)
GOLD = (255, 205, 64)


def gradient(size, stops):
    w, h = size
    strip = Image.new("RGB", (1, 512))
    for y in range(512):
        t = y / 511
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                k = (t - t0) / max(1e-6, t1 - t0)
                strip.putpixel((0, y), tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)))
                break
    return strip.resize(size, Image.BICUBIC).convert("RGBA")


def aurora(img, rng, bands):
    w, h = img.size
    for color, y0, amp, thick, phase in bands:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        pts_top, pts_bottom = [], []
        for i in range(0, 101):
            x = w * i / 100
            y = h * y0 + math.sin(i / 100 * math.pi * 2.2 + phase) * h * amp
            pts_top.append((x, y - h * thick))
            pts_bottom.append((x, y + h * thick * 0.4))
        d.polygon(pts_top + pts_bottom[::-1], fill=color + (150,))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(h * thick * 0.6)))


def stars(img, rng, count):
    d = ImageDraw.Draw(img)
    w, h = img.size
    for _ in range(count):
        x, y = rng.random() * w, rng.random() * h * 0.6
        r = rng.choice([1, 1, 1, 2]) * SS
        a = rng.randint(120, 255)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, a))


def snowfall(img, rng, count):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = img.size
    for _ in range(count):
        x, y = rng.random() * w, rng.random() * h
        r = rng.uniform(1.5, 4.5) * SS
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randint(90, 200)))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8 * SS)))


def mountains(img, rng, base_y, color, peaks, height):
    w, h = img.size
    d = ImageDraw.Draw(img)
    pts = [(0, h)]
    x = -w * 0.1
    while x < w * 1.1:
        step = w / peaks * rng.uniform(0.7, 1.3)
        pts.append((x, base_y))
        pts.append((x + step / 2, base_y - height * rng.uniform(0.6, 1.0)))
        x += step
    pts.append((w * 1.1, base_y))
    pts.append((w, h))
    d.polygon(pts, fill=color)


def ramp(img, a, b, width, height, glow=True):
    """Dach-Rampe von a nach b (Grat), mit heller und schattiger Seite und Leuchtgrat."""
    d = ImageDraw.Draw(img)
    ax, ay = a
    bx, by = b
    # Seiten: nach unten versetzt (Perspektive: helle Seite vorn)
    light = [(ax, ay), (bx, by), (bx - width * 0.15, by + height), (ax - width * 0.6, ay + height * 0.9)]
    dark = [(ax, ay), (bx, by), (bx + width * 0.35, by + height * 0.7), (ax + width * 0.25, ay + height * 0.6)]
    d.polygon(dark, fill=(120, 150, 205))
    # Helle Seite mit Verlauf (oben weiss, unten eisblau)
    face = Image.new("RGBA", img.size, (0, 0, 0, 0))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(light, fill=255)
    top = min(p[1] for p in light)
    bottom = max(p[1] for p in light)
    grad = gradient((img.size[0], int(bottom - top) + 2), [(0, SNOW), (1, (170, 215, 250))])
    face.paste(grad, (0, int(top)))
    img.paste(face, (0, 0), mask)
    # Neonkanten
    if glow:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).line([a, b], fill=ICE + (255,), width=int(10 * SS))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(9 * SS)))
    d.line([a, b], fill=ICE, width=int(4 * SS))
    d.line([light[3], light[2]], fill=MINT, width=int(3 * SS))


def surfer(img, pos, scale, lean=-28):
    """Stilisierter Surfer auf Skiern, lehnt sich in die Rampe."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = pos
    s = scale
    # Skier
    d.line([(x - 70 * s, y + 8 * s), (x + 80 * s, y - 14 * s)], fill=AURORA, width=int(9 * s))
    d.line([(x + 80 * s, y - 14 * s), (x + 96 * s, y - 30 * s)], fill=AURORA, width=int(9 * s))
    # Koerper (Navy mit Eis-Kontur)
    # Beine (gebeugt) und Oberkoerper
    d.line([(x - 20 * s, y + 2 * s), (x - 4 * s, y - 34 * s), (x + 4 * s, y - 52 * s)], fill=NAVY, width=int(14 * s), joint="curve")
    d.line([(x + 30 * s, y - 6 * s), (x + 22 * s, y - 36 * s), (x + 10 * s, y - 52 * s)], fill=NAVY, width=int(14 * s), joint="curve")
    body = [(x - 8 * s, y - 50 * s), (x + 24 * s, y - 52 * s), (x + 26 * s, y - 92 * s), (x - 6 * s, y - 96 * s)]
    d.polygon(body, fill=AURORA)
    # Arme ausgebreitet
    d.line([(x + 6 * s, y - 80 * s), (x - 52 * s, y - 104 * s)], fill=NAVY, width=int(12 * s))
    d.line([(x + 14 * s, y - 78 * s), (x + 70 * s, y - 58 * s)], fill=NAVY, width=int(12 * s))
    # Kopf mit Muetze
    d.ellipse((x - 4 * s, y - 132 * s, x + 30 * s, y - 98 * s), fill=NAVY, outline=ICE, width=int(2 * s))
    d.pieslice((x - 6 * s, y - 140 * s, x + 32 * s, y - 104 * s), 180, 360, fill=AURORA)
    layer = layer.rotate(lean, center=pos, resample=Image.BICUBIC)
    img.alpha_composite(layer)


def trail(img, start, end, width):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps):
        t = i / steps
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t
        c = tuple(int(MINT[j] + (AURORA[j] - MINT[j]) * t) for j in range(3))
        r = width * (0.25 + 0.75 * t)
        d.ellipse((x - r, y - r * 0.5, x + r, y + r * 0.5), fill=c + (int(40 + 160 * t),))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(width * 0.3)))


def logo(img, text, center, size, tilt=-6):
    font = ImageFont.truetype(FONT_ITALIC, int(size))
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    x, y = center[0] - tw / 2 - box[0], center[1] - th / 2 - box[1]
    outline = max(4, int(size * 0.07))
    d.text((x, y), text, font=font, fill=NAVY + (255,), stroke_width=outline, stroke_fill=NAVY + (255,))
    shadow = layer.copy().filter(ImageFilter.GaussianBlur(size * 0.06))
    # Text-Fuellung mit Verlauf eis -> weiss -> pink
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
    fill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    grad = Image.new("RGBA", (int(tw) + 4, 1))
    for i in range(grad.size[0]):
        t = i / max(1, grad.size[0] - 1)
        if t < 0.55:
            k = t / 0.55
            c = tuple(int(ICE[j] + (SNOW[j] - ICE[j]) * k) for j in range(3))
        else:
            k = (t - 0.55) / 0.45
            c = tuple(int(SNOW[j] + (AURORA[j] - SNOW[j]) * k) for j in range(3))
        grad.putpixel((i, 0), c + (255,))
    grad = grad.resize((int(tw) + 4, h))
    fill.paste(grad, (int(x + box[0]), 0))
    result = Image.new("RGBA", img.size, (0, 0, 0, 0))
    result.alpha_composite(shadow)
    result.alpha_composite(layer)
    result.paste(fill, (0, 0), mask)
    result = result.rotate(tilt, center=center, resample=Image.BICUBIC)
    img.alpha_composite(result)


def pill(img, xy, text, size, bg, fg):
    font = ImageFont.truetype(FONT_BOLD, int(size))
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    pad = size * 0.55
    x, y = xy
    d.rounded_rectangle((x, y, x + tw + pad * 2, y + th + pad * 1.4), radius=(th + pad * 1.4) / 2, fill=bg)
    d.text((x + pad - box[0], y + pad * 0.7 - box[1]), text, font=font, fill=fg)


def scene(size, seed):
    rng = random.Random(seed)
    w, h = size
    img = gradient(size, [(0, (6, 12, 32)), (0.55, NAVY), (1, (52, 62, 128))])
    stars(img, rng, int(w * h / 9000))
    aurora(img, rng, [
        (MINT, 0.22, 0.05, 0.07, 0.3),
        (ICE, 0.3, 0.06, 0.06, 1.9),
        (AURORA, 0.38, 0.05, 0.05, 3.4),
    ])
    mountains(img, rng, h * 0.78, (44, 58, 104), 5, h * 0.32)
    mountains(img, rng, h * 0.86, (70, 88, 140), 7, h * 0.2)
    return img, rng


def make_icon(path):
    size = (512 * SS, 512 * SS)
    img, rng = scene(size, 4)
    w, h = size
    ramp(img, (w * -0.05, h * 0.42), (w * 1.05, h * 0.70), w * 0.5, h * 0.42)
    trail(img, (w * 0.02, h * 0.42), (w * 0.43, h * 0.53), w * 0.05)
    surfer(img, (w * 0.5, h * 0.58), SS * 1.25)
    snowfall(img, rng, 60)
    logo(img, "surf_ski", (w * 0.5, h * 0.2), w * 0.2, tilt=6)
    img = img.resize((512, 512), Image.LANCZOS).convert("RGB")
    img.save(path)


def make_thumbnail(path):
    size = (1920 * SS, 1080 * SS)
    img, rng = scene(size, 9)
    w, h = size
    ramp(img, (w * -0.05, h * 0.86), (w * 0.42, h * 1.02), w * 0.2, h * 0.3, glow=True)
    ramp(img, (w * 0.3, h * 0.5), (w * 1.08, h * 0.78), w * 0.3, h * 0.34)
    trail(img, (w * 0.32, h * 0.52), (w * 0.64, h * 0.62), w * 0.03)
    surfer(img, (w * 0.7, h * 0.665), SS * 2.0)
    snowfall(img, rng, 220)
    logo(img, "surf_ski", (w * 0.27, h * 0.2), w * 0.12, tilt=5)
    pill(img, (w * 0.06, h * 0.36), "CLASSIC CS SURF  ·  10 STAGES  ·  WORLD RECORDS", h * 0.034, ICE, NAVY)
    pill(img, (w * 0.73, h * 0.08), "2767 u/s", h * 0.05, AURORA, (255, 255, 255))
    img = img.resize((1920, 1080), Image.LANCZOS).convert("RGB")
    img.save(path)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    make_icon(f"{out}/icon.png")
    make_thumbnail(f"{out}/thumbnail.png")
    print("ok")
