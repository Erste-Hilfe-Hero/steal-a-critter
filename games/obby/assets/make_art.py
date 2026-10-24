# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) fuer Mega Rainbow Obby.
# Aufruf: python3 games/obby/assets/make_art.py <ausgabeordner>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
SS = 2  # Supersampling fuer glatte Kanten
INK = (24, 16, 48)
RAINBOW = [(255, 80, 80), (255, 165, 50), (255, 222, 70), (80, 215, 110), (70, 160, 255), (165, 95, 255)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color)


def sky(size, top, bottom):
    w, h = size
    small = Image.new("RGB", (1, 64))
    for y in range(64):
        small.putpixel((0, y), lerp(top, bottom, y / 63))
    img = small.resize(size, Image.BICUBIC).convert("RGBA")
    # Sonnenstrahlen von oben rechts
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = w * 0.82, -h * 0.1
    for i in range(16):
        a0 = math.pi * 0.25 + i * math.pi / 22
        a1 = a0 + math.pi / 60
        r = w * 2
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, 26))
    img.alpha_composite(layer)
    return img


def cloud(img, cx, cy, s, alpha=210):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for dx, dy, r in [(-0.9, 0.15, 0.55), (-0.3, -0.2, 0.75), (0.45, -0.05, 0.62), (1.0, 0.2, 0.45), (0.1, 0.25, 0.6)]:
        d.ellipse((cx + (dx - r) * s, cy + (dy - r) * s, cx + (dx + r) * s, cy + (dy + r) * s), fill=(255, 255, 255, alpha))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(s * 0.04)))


def block(img, x, y, w, h, depth, color, outline):
    """Isometrischer Block: Vorderseite (x, y, w, h), Oberseite und rechte Seite mit Tiefe."""
    d = ImageDraw.Draw(img)
    dx, dy = depth, -depth * 0.55
    top = [(x, y), (x + w, y), (x + w + dx, y + dy), (x + dx, y + dy)]
    side = [(x + w, y), (x + w + dx, y + dy), (x + w + dx, y + h + dy), (x + w, y + h)]
    front = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    # Schatten
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(p[0] + depth * 0.3, p[1] + depth * 0.6) for p in front + side[1:3]], fill=(20, 10, 60, 90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(depth * 0.35)))
    d = ImageDraw.Draw(img)
    d.polygon(side, fill=shade(color, 0.72), outline=INK, width=outline)
    d.polygon(front, fill=shade(color, 0.9), outline=INK, width=outline)
    d.polygon(top, fill=lerp(color, (255, 255, 255), 0.22), outline=INK, width=outline)
    # Glanz auf der Oberseite
    d.line([(x + w * 0.12 + dx * 0.3, y + dy * 0.3), (x + w * 0.55 + dx * 0.3, y + dy * 0.3)], fill=(255, 255, 255), width=max(2, outline))


def hero(img, cx, feet, s, angle=0):
    """Blockige Spielfigur (eigenes Design), s = Hoehe."""
    fig = Image.new("RGBA", (int(s * 1.4), int(s * 1.4)), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    o = max(3, int(s * 0.035))
    W = fig.width
    bx = W / 2
    # Beine
    for sxl in (-1, 1):
        d.rounded_rectangle((bx + sxl * s * 0.12 - s * 0.09, s * 0.95, bx + sxl * s * 0.12 + s * 0.09, s * 1.28), radius=o, fill=(60, 70, 200), outline=INK, width=o)
    # Arme (jubelnd)
    for sxl in (-1, 1):
        d.line([(bx + sxl * s * 0.22, s * 0.68), (bx + sxl * s * 0.42, s * 0.42)], fill=INK, width=int(s * 0.13))
        d.line([(bx + sxl * s * 0.22, s * 0.68), (bx + sxl * s * 0.42, s * 0.42)], fill=(255, 205, 60), width=int(s * 0.09))
    # Koerper
    d.rounded_rectangle((bx - s * 0.24, s * 0.6, bx + s * 0.24, s * 1.0), radius=o * 2, fill=(255, 90, 120), outline=INK, width=o)
    # Kopf
    d.rounded_rectangle((bx - s * 0.2, s * 0.22, bx + s * 0.2, s * 0.6), radius=o * 3, fill=(255, 205, 60), outline=INK, width=o)
    for sxl in (-1, 1):
        ex = bx + sxl * s * 0.08
        d.ellipse((ex - s * 0.035, s * 0.34, ex + s * 0.035, s * 0.42), fill=INK)
    d.arc((bx - s * 0.09, s * 0.38, bx + s * 0.09, s * 0.52), 20, 160, fill=INK, width=o)
    fig = fig.rotate(angle, resample=Image.BICUBIC, center=(W / 2, s * 0.7))
    img.alpha_composite(fig, (int(cx - W / 2), int(feet - s * 1.28)))


def text_outlined(img, xy, txt, size, fill, outline, anchor="mm", stroke=None, gradient=None, shadow=True):
    font = ImageFont.truetype(FONT, size)
    stroke = stroke or max(4, size // 9)
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((xy[0] + size * 0.05, xy[1] + size * 0.08), txt, font=font, fill=(20, 10, 50, 160), anchor=anchor, stroke_width=stroke, stroke_fill=(20, 10, 50, 160))
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.04)))
    d = ImageDraw.Draw(img)
    d.text(xy, txt, font=font, fill=outline, anchor=anchor, stroke_width=stroke, stroke_fill=outline)
    if gradient:
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).text(xy, txt, font=font, fill=255, anchor=anchor)
        box = mask.getbbox()
        grad = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gp = ImageDraw.Draw(grad)
        x0, x1 = box[0], box[2]
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0) * (len(gradient) - 1)
            i = min(int(t), len(gradient) - 2)
            gp.line([(x, box[1]), (x, box[3])], fill=lerp(gradient[i], gradient[i + 1], t - i) + (255,))
        img.paste(grad, (0, 0), mask)
        # Glanzlinie oben
        hl = Image.new("L", img.size, 0)
        ImageDraw.Draw(hl).rectangle((box[0], box[1], box[2], box[1] + (box[3] - box[1]) * 0.38), fill=70)
        hl = Image.composite(hl, Image.new("L", img.size, 0), mask)
        img.paste(Image.new("RGBA", img.size, (255, 255, 255, 255)), (0, 0), hl)
    else:
        d.text(xy, txt, font=font, fill=fill, anchor=anchor)


def badge(img, cx, cy, r, top, bottom):
    d = ImageDraw.Draw(img)
    o = max(4, r // 10)
    pts = []
    for i in range(24):
        rr = r if i % 2 == 0 else r * 0.84
        a = i * math.pi / 12
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=(255, 205, 50), outline=INK, width=o)
    text_outlined(img, (cx, cy - r * 0.12), top, int(r * 0.72), (255, 255, 255), INK, shadow=False)
    text_outlined(img, (cx, cy + r * 0.42), bottom, int(r * 0.26), (255, 255, 255), INK, shadow=False)


def staircase(img, x0, base, step_w, step_h, rise, depth, outline, count=6):
    for i in range(count):
        color = RAINBOW[i % len(RAINBOW)]
        x = x0 + i * step_w * 1.32
        y = base - i * rise
        block(img, x, y, step_w, step_h, depth, color, outline)
    return [(x0 + i * step_w * 1.32, base - i * rise) for i in range(count)]


def thumbnail(path):
    W, H = 1920 * SS, 1080 * SS
    img = sky((W, H), (90, 175, 255), (205, 170, 255))
    rnd = random.Random(4)
    for _ in range(7):
        cloud(img, rnd.uniform(0, W), rnd.uniform(H * 0.15, H * 0.7), rnd.uniform(60, 120) * SS)
    # Lava unten
    d = ImageDraw.Draw(img)
    for y in range(int(H * 0.88), H):
        t = (y - H * 0.88) / (H * 0.12)
        d.line([(0, y), (W, y)], fill=lerp((255, 120, 40), (220, 40, 40), t))
    for i in range(40):
        x = rnd.uniform(0, W)
        r = rnd.uniform(10, 30) * SS
        d.ellipse((x - r, H * 0.89 - r * 0.4, x + r, H * 0.89 + r * 0.4), fill=(255, 210, 90))
    # Regenbogen-Treppe von links unten nach rechts oben
    stairs = staircase(img, 110 * SS, H * 0.86, 180 * SS, 78 * SS, 62 * SS, 66 * SS, 5 * SS, count=7)
    # Kill-Balken (dreht sich) ueber der dritten Stufe
    bx, by = stairs[2]
    kb = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(kb).rounded_rectangle((bx - 50 * SS, by - 78 * SS, bx + 300 * SS, by - 40 * SS), radius=18 * SS, fill=(255, 45, 70), outline=INK, width=6 * SS)
    kb = kb.rotate(-10, resample=Image.BICUBIC, center=(bx + 125 * SS, by - 59 * SS))
    img.alpha_composite(kb.filter(ImageFilter.GaussianBlur(22 * SS)))
    img.alpha_composite(kb)
    # Figur springt zur obersten Stufe
    sx, sy = stairs[5]
    hero(img, sx + 100 * SS, sy - 110 * SS, 210 * SS, angle=-12)
    # Titel links oben
    text_outlined(img, (W * 0.33, H * 0.15), "MEGA RAINBOW", 128 * SS, None, INK, stroke=18 * SS, gradient=RAINBOW)
    text_outlined(img, (W * 0.33, H * 0.34), "OBBY", 220 * SS, None, INK, stroke=24 * SS, gradient=[(255, 245, 140), (255, 175, 30)])
    badge(img, W * 0.87, H * 0.2, 135 * SS, "100", "STAGES")
    img = img.resize((1920, 1080), Image.LANCZOS).convert("RGB")
    img.save(path, optimize=True)


def icon(path):
    S = 512 * SS
    img = sky((S, S), (90, 175, 255), (205, 170, 255))
    cloud(img, S * 0.15, S * 0.4, 60 * SS)
    cloud(img, S * 0.88, S * 0.3, 50 * SS)
    stairs = staircase(img, 16 * SS, S * 0.9, 62 * SS, 34 * SS, 36 * SS, 26 * SS, 4 * SS, count=6)
    sx, sy = stairs[4]
    hero(img, sx + 20 * SS, sy - 30 * SS, 150 * SS, angle=-8)
    text_outlined(img, (S * 0.5, S * 0.13), "OBBY", 150 * SS, None, INK, stroke=18 * SS, gradient=RAINBOW)
    badge(img, S * 0.19, S * 0.44, 66 * SS, "100", "STAGES")
    img = img.resize((512, 512), Image.LANCZOS).convert("RGB")
    img.save(path, optimize=True)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    icon(f"{out}/icon.png")
    thumbnail(f"{out}/thumbnail.png")
