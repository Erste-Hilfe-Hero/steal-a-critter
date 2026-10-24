# Erzeugt Icon (512x512) und Vorschaubilder (1920x1080) fuer Turbo City im Comic-Pop-Stil des Ladebildschirms.
# Aufruf: python3 games/city/assets/make_art.py <LuckiestGuy.ttf> <ausgabeordner>
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFont

INK = (23, 21, 59)
INK2 = (42, 38, 96)
CREAM = (255, 248, 231)
ORANGE = (255, 122, 26)
PINK = (255, 61, 127)
TEAL = (25, 211, 197)
LEMON = (255, 225, 77)
BLUE = (60, 130, 255)
RED = (255, 60, 60)
SS = 2  # Supersampling


def stripes(img, angle=30, width=90):
    d = ImageDraw.Draw(img)
    w, h = img.size
    step = width * 2
    t = math.tan(math.radians(angle))
    for x in range(-h * 2, w + h * 2, step):
        d.polygon([(x, 0), (x + width, 0), (x + width - h * t, h), (x - h * t, h)], fill=INK2)


def sun(img, cx, cy, r):
    grad = Image.new("RGB", (1, 256))
    for y in range(256):
        k = y / 255
        grad.putpixel((0, y), tuple(int(LEMON[i] + (PINK[i] - LEMON[i]) * k) for i in range(3)))
    grad = grad.resize((r * 2, r * 2))
    mask = Image.new("L", (r * 2, r * 2), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, r * 2 - 1, r * 2 - 1), fill=255)
    img.paste(grad, (cx - r, cy - r), mask)


def skyline(img, base_y, scale, seed=7):
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    w = img.size[0]
    x = -20 * scale
    while x < w:
        bw = rng.randint(50, 95) * scale
        bh = rng.randint(60, 200) * scale
        d.rectangle((x, base_y - bh, x + bw, base_y), fill=INK2)
        for wy in range(int(base_y - bh + 14 * scale), int(base_y - 14 * scale), int(22 * scale)):
            for wx in range(int(x + 10 * scale), int(x + bw - 18 * scale), int(20 * scale)):
                if rng.random() < 0.45:
                    d.rectangle((wx, wy, wx + 8 * scale, wy + 10 * scale), fill=(230, 205, 90))
        x += bw + rng.randint(-6, 6) * scale


def road(img, top, height, scale):
    d = ImageDraw.Draw(img)
    w = img.size[0]
    d.rectangle((0, top, w, top + height), fill=(35, 33, 70))
    d.rectangle((0, top, w, top + 7 * scale), fill=ORANGE)
    y = top + height // 2
    for x in range(0, w, int(60 * scale)):
        d.rectangle((x, y - 4 * scale, x + 34 * scale, y + 4 * scale), fill=LEMON)


def rounded(d, box, r, fill, outline=INK, width=8):
    d.rounded_rectangle(box, r, fill=fill, outline=outline, width=width)


def car(img, x, y, s, body, cabin, police=False, flip=False):
    """Seitenansicht wie im Ladebildschirm. x,y = linke untere Ecke der Karosserie."""
    layer = Image.new("RGBA", (int(260 * s), int(150 * s)), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lw = max(4, int(7 * s))
    rounded(d, (int(60 * s), int(10 * s), int(170 * s), int(70 * s)), int(18 * s), cabin, width=lw)
    if police:
        d.rectangle((int(85 * s), int(0 * s), int(112 * s), int(14 * s)), fill=RED, outline=INK, width=lw // 2)
        d.rectangle((int(115 * s), int(0 * s), int(142 * s), int(14 * s)), fill=BLUE, outline=INK, width=lw // 2)
    rounded(d, (int(8 * s), int(50 * s), int(250 * s), int(110 * s)), int(22 * s), body, width=lw)
    if police:
        d.rectangle((int(14 * s), int(78 * s), int(244 * s), int(88 * s)), fill=BLUE)
    d.rectangle((int(232 * s), int(64 * s), int(252 * s), int(78 * s)), fill=LEMON, outline=INK, width=lw // 2)
    d.rectangle((int(6 * s), int(64 * s), int(22 * s), int(78 * s)), fill=RED, outline=INK, width=lw // 2)
    for wx in (40, 190):
        cx, cy, r = int(wx * s), int(112 * s), int(30 * s)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK)
        hr = int(13 * s)
        d.ellipse((cx - hr, cy - hr, cx + hr, cy + hr), fill=LEMON)
    if flip:
        layer = layer.transpose(Image.FLIP_LEFT_RIGHT)
    img.paste(layer, (int(x), int(y - 110 * s)), layer)


def speed_lines(img, x, y, length, count, s):
    d = ImageDraw.Draw(img)
    for i in range(count):
        yy = y + i * 18 * s
        d.rounded_rectangle((x - length + i * 20 * s, yy, x + i * 10 * s, yy + 7 * s), 4 * s, fill=CREAM)


def logo(img, font_path, cx, top, size, sub=True):
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(font_path, size)
    mid = ImageFont.truetype(font_path, int(size * 0.78))
    stroke = max(6, size // 13)
    off = max(6, size // 16)

    def word(text, font, y, color):
        bbox = d.textbbox((0, 0), text, font=font, stroke_width=stroke)
        w = bbox[2] - bbox[0]
        x = cx - w / 2
        d.text((x + off, y + off), text, font=font, fill=PINK, stroke_width=stroke, stroke_fill=INK)
        d.text((x, y), text, font=font, fill=color, stroke_width=stroke, stroke_fill=INK)
        return bbox[3] - bbox[1]

    h1 = word("TURBO", big, top, LEMON)
    h2 = word("CITY", mid, top + h1 * 0.98, CREAM)
    bottom = top + h1 * 0.98 + h2
    if sub:
        rib = ImageFont.truetype(font_path, int(size * 0.3))
        text = "COPS & ROBBERS"
        bbox = d.textbbox((0, 0), text, font=rib)
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        pad = size * 0.12
        layer = Image.new("RGBA", (int(w + pad * 2 + 20), int(h + pad * 1.6 + 20)), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.rectangle((10, 10, layer.size[0] - 10, layer.size[1] - 10), fill=TEAL, outline=INK, width=max(5, stroke // 2))
        ld.text((10 + pad, 10 + pad * 0.6 - bbox[1]), text, font=rib, fill=INK)
        layer = layer.rotate(4, resample=Image.BICUBIC, expand=True)
        img.paste(layer, (int(cx - layer.size[0] / 2), int(bottom + size * 0.12)), layer)
        bottom += size * 0.12 + layer.size[1]
    return bottom


def thumbnail(font, out):
    W, H = 1920 * SS, 1080 * SS
    img = Image.new("RGB", (W, H), INK)
    stripes(img, width=110 * SS)
    sun(img, W // 2, int(H * 0.62), int(420 * SS))
    skyline(img, int(H * 0.8), 2 * SS)
    road(img, int(H * 0.8), int(H * 0.2), SS)
    # Verfolgungsjagd: Raeuber vorn (pink), Polizei hinten
    speed_lines(img, int(W * 0.56), int(H * 0.73), 260 * SS, 4, SS)
    car(img, W * 0.56, H * 0.93, 2.6 * SS, PINK, TEAL)
    speed_lines(img, int(W * 0.12), int(H * 0.73), 200 * SS, 4, SS)
    car(img, W * 0.12, H * 0.93, 2.6 * SS, (245, 245, 255), (150, 210, 255), police=True)
    # Geldsaecke fliegen
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(font, 80 * SS)
    for i, (x, y) in enumerate([(0.86, 0.6), (0.92, 0.48), (0.8, 0.45)]):
        cx, cy, r = int(W * x), int(H * y), int(52 * SS)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(150, 105, 60), outline=INK, width=8 * SS)
        d.text((cx, cy + 4 * SS), "$", font=f, fill=(80, 220, 120), anchor="mm", stroke_width=4 * SS, stroke_fill=INK)
    logo(img, font, W // 2, int(60 * SS), int(230 * SS))
    img.resize((1920, 1080), Image.LANCZOS).save(f"{out}/thumbnail.png", optimize=True)


def thumbnail_heist(font, out):
    """Zweites Vorschaubild: Bank-Ueberfall bei Nacht."""
    W, H = 1920 * SS, 1080 * SS
    img = Image.new("RGB", (W, H), INK)
    stripes(img, width=110 * SS)
    d = ImageDraw.Draw(img)
    # Bank
    bx, by, bw, bh = int(W * 0.08), int(H * 0.36), int(W * 0.42), int(H * 0.5)
    d.polygon([(bx - 30 * SS, by), (bx + bw / 2, by - 140 * SS), (bx + bw + 30 * SS, by)], fill=CREAM, outline=INK, width=10 * SS)
    d.rectangle((bx, by, bx + bw, by + bh), fill=CREAM, outline=INK, width=10 * SS)
    for i in range(5):
        cx = bx + 60 * SS + i * (bw - 120 * SS) / 4
        d.rectangle((cx - 22 * SS, by + 40 * SS, cx + 22 * SS, by + bh - 20 * SS), fill=(235, 230, 220), outline=INK, width=6 * SS)
    f = ImageFont.truetype(font, 110 * SS)
    d.text((bx + bw / 2, by - 50 * SS), "$ BANK $", font=f, fill=(80, 220, 120), anchor="mm", stroke_width=6 * SS, stroke_fill=INK)
    road(img, int(H * 0.86), int(H * 0.14), SS)
    car(img, W * 0.5, H * 0.97, 2.4 * SS, (245, 245, 255), (150, 210, 255), police=True, flip=True)
    logo(img, font, int(W * 0.74), int(90 * SS), int(200 * SS))
    img.resize((1920, 1080), Image.LANCZOS).save(f"{out}/thumbnail_heist.png", optimize=True)


def icon(font, out):
    S = 512 * SS
    img = Image.new("RGB", (S, S), INK)
    stripes(img, width=60 * SS)
    sun(img, S // 2, int(S * 0.7), int(200 * SS))
    skyline(img, int(S * 0.86), SS, seed=3)
    road(img, int(S * 0.86), int(S * 0.14), SS * 0.6)
    logo(img, font, S // 2, int(40 * SS), int(150 * SS), sub=False)
    car(img, S * 0.24, S * 0.98, 1.2 * SS, PINK, TEAL)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, S - 1, S - 1), outline=INK, width=10 * SS)
    img.resize((512, 512), Image.LANCZOS).save(f"{out}/icon.png", optimize=True)


if __name__ == "__main__":
    font_path, out_dir = sys.argv[1], sys.argv[2]
    icon(font_path, out_dir)
    thumbnail(font_path, out_dir)
    thumbnail_heist(font_path, out_dir)
