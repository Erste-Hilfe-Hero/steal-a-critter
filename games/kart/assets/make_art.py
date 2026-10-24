# Erzeugt Logo, Icon (512x512) und Thumbnail (1920x1080) fuer Fire Blaster Race.
# Aufruf: python3 make_art.py <Pfad zu Sarpanch-Black.ttf> <Ausgabeordner>
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

FONT = sys.argv[1]
OUT = sys.argv[2]
INK = (16, 13, 22)
FLAME = [(255, 236, 120), (255, 150, 34), (232, 57, 42)]

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def flame_color(t):
    return lerp(FLAME[0], FLAME[1], t / 0.55) if t < 0.55 else lerp(FLAME[1], FLAME[2], (t - 0.55) / 0.45)

def vertical_gradient(size, fn):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        g.putpixel((0, y), fn(y / max(1, h - 1)))
    return g.resize((w, h))

def background(w, h, seed):
    random.seed(seed)
    img = vertical_gradient((w, h), lambda t: lerp((22, 14, 34), (70, 18, 22), t ** 1.6))
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse([w * 0.1, h * 0.55, w * 0.9, h * 1.5], fill=(255, 90, 20))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    img = ImageChops.add(img, ImageChops.multiply(glow, Image.new("RGB", (w, h), (150, 150, 150))))
    # Geschwindigkeits-Streifen
    streaks = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(streaks)
    for _ in range(int(w / 18)):
        x = random.uniform(-w * 0.3, w * 1.2)
        y = random.uniform(0, h)
        length = random.uniform(w * 0.08, w * 0.35)
        thick = random.uniform(1, w / 260)
        c = flame_color(random.random())
        d.line([(x, y), (x + length, y - length * 0.36)], fill=c + (random.randint(40, 110),), width=max(1, int(thick)))
    streaks = streaks.filter(ImageFilter.GaussianBlur(1))
    img.paste(streaks, (0, 0), streaks)
    # Funken
    sparks = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(sparks)
    for _ in range(int(w / 6)):
        x, y = random.uniform(0, w), random.uniform(h * 0.3, h)
        r = random.uniform(1, w / 400 + 1)
        d.ellipse([x - r, y - r, x + r, y + r], fill=flame_color(random.random()) + (random.randint(120, 255),))
    img.paste(sparks, (0, 0), sparks)
    return img.convert("RGBA")

def road(img, horizon, curve):
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rows = 60
    for i in range(rows):
        t0, t1 = i / rows, (i + 1) / rows
        def edge(t, side):
            y = horizon + (h - horizon) * t ** 1.0
            half = w * (0.04 + 0.62 * t)
            cx = w * 0.5 + curve * w * (1 - t) ** 2
            return (cx + side * half, y)
        a, b, c, e = edge(t0, -1), edge(t0, 1), edge(t1, 1), edge(t1, -1)
        d.polygon([a, b, c, e], fill=(46, 42, 54, 255))
        stripe = (235, 50, 40, 255) if i % 2 == 0 else (245, 240, 235, 255)
        for side in (-1, 1):
            o0, o1 = edge(t0, side), edge(t1, side)
            k0 = (w * (0.004 + 0.05 * t0)) * side
            k1 = (w * (0.004 + 0.05 * t1)) * side
            d.polygon([o0, (o0[0] + k0, o0[1]), (o1[0] + k1, o1[1]), o1], fill=stripe)
        if i % 3 == 0:
            m0, m1 = edge(t0, 0), edge(t1, 0)
            k0, k1 = w * 0.003 * (1 + 10 * t0), w * 0.003 * (1 + 10 * t1)
            d.polygon([(m0[0] - k0, m0[1]), (m0[0] + k0, m0[1]), (m1[0] + k1, m1[1]), (m1[0] - k1, m1[1])], fill=(255, 200, 60, 200))
    img.alpha_composite(layer)

def glow_blob(img, cx, cy, rx, ry, color, blur, alpha=255):
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color + (alpha,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))

def kart(img, cx, cy, s, body=(255, 120, 40), accent=(30, 26, 36), helmet=(245, 245, 250), facing=1):
    """Kart in Dreiviertel-Seitenansicht, faehrt nach rechts (facing=1)."""
    w, h = img.size
    # Flammen hinten
    for k in range(6):
        t = k / 5
        glow_blob(img, cx - facing * s * (1.25 + t * 1.1), cy - s * 0.05, s * (0.55 - t * 0.3), s * (0.28 - t * 0.12), flame_color(t), s * 0.08, 230)
    glow_blob(img, cx - facing * s * 1.2, cy - s * 0.05, s * 0.35, s * 0.18, (255, 250, 210), s * 0.05, 255)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    def P(x, y):
        return (cx + facing * x * s, cy + y * s)
    # Schatten
    d.ellipse([cx - s * 1.4, cy + s * 0.55, cx + s * 1.4, cy + s * 0.85], fill=(0, 0, 0, 110))
    # Hinterrad (hinten)
    def wheel(x, y, r):
        d.ellipse([P(x, y)[0] - r * s, P(x, y)[1] - r * s, P(x, y)[0] + r * s, P(x, y)[1] + r * s], fill=(24, 22, 28, 255))
        d.ellipse([P(x, y)[0] - r * 0.5 * s, P(x, y)[1] - r * 0.5 * s, P(x, y)[0] + r * 0.5 * s, P(x, y)[1] + r * 0.5 * s], fill=(255, 170, 40, 255))
    wheel(-0.78, 0.38, 0.36)
    wheel(0.9, 0.42, 0.3)
    # Karosserie
    d.polygon([P(-1.15, 0.25), P(-1.1, -0.2), P(-0.6, -0.3), P(0.2, -0.22), P(1.0, -0.05), P(1.35, 0.12), P(1.3, 0.32), P(-1.0, 0.36)], fill=body + (255,))
    d.polygon([P(-1.15, 0.25), P(1.3, 0.32), P(1.2, 0.42), P(-1.05, 0.42)], fill=lerp(body, (0, 0, 0), 0.35) + (255,))
    # Streifen
    d.polygon([P(-1.0, -0.12), P(0.9, -0.02), P(0.95, 0.06), P(-1.02, -0.02)], fill=(255, 230, 120, 255))
    # Spoiler am Heck
    d.polygon([P(-1.38, -0.6), P(-0.92, -0.6), P(-0.98, -0.48), P(-1.4, -0.48)], fill=accent + (255,))
    d.polygon([P(-1.2, -0.5), P(-1.06, -0.5), P(-0.98, -0.12), P(-1.14, -0.12)], fill=accent + (255,))
    # Sitz und Fahrer
    d.polygon([P(-0.62, -0.2), P(-0.5, -0.62), P(-0.36, -0.62), P(-0.4, -0.2)], fill=lerp(accent, (0, 0, 0), 0.2) + (255,))
    d.polygon([P(-0.42, -0.22), P(0.02, -0.22), P(0.04, -0.6), P(-0.36, -0.66)], fill=(40, 36, 50, 255))
    hx, hy, hr = -0.16, -0.86, 0.3
    c = P(hx, hy)
    d.ellipse([c[0] - hr * s, c[1] - hr * s, c[0] + hr * s, c[1] + hr * s], fill=helmet + (255,))
    d.polygon([P(hx + 0.04, hy - 0.12), P(hx + 0.3, hy - 0.06), P(hx + 0.28, hy + 0.1), P(hx + 0.02, hy + 0.08)], fill=(30, 40, 70, 255))
    d.polygon([P(hx - 0.28, hy - 0.06), P(hx + 0.06, hy - 0.2), P(hx + 0.08, hy - 0.12), P(hx - 0.28, hy + 0.02)], fill=body + (255,))
    # Arm zum Lenkrad
    d.line([P(-0.05, -0.5), P(0.38, -0.3)], fill=(40, 36, 50, 255), width=max(2, int(s * 0.11)))
    d.ellipse([P(0.34, -0.42)[0] - s * 0.08, P(0.34, -0.42)[1] - s * 0.12, P(0.34, -0.42)[0] + s * 0.08, P(0.34, -0.42)[1] + s * 0.12], fill=(24, 22, 28, 255))
    # Vorderrad (vorne, ueberdeckt)
    wheel(-0.62, 0.45, 0.4)
    wheel(1.0, 0.47, 0.34)
    img.alpha_composite(layer)

def fit_font(text, max_w, max_h):
    size = int(max_h)
    while size > 10:
        f = ImageFont.truetype(FONT, size)
        bb = f.getbbox(text)
        if bb[2] - bb[0] <= max_w and bb[3] - bb[1] <= max_h:
            return f
        size -= 4
    return ImageFont.truetype(FONT, size)

def logo(size):
    """Logo als RGBA: FIRE BLASTER (Flammenverlauf) + RACE (weiss), kursiv geschert, mit Kontur und Glow."""
    w, h = size
    big = fit_font("FIRE BLASTER", w * 0.84, h * 0.46)
    small = fit_font("RACE", w * 0.4, h * 0.3)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    bb = md.textbbox((0, 0), "FIRE BLASTER", font=big)
    md.text(((w - (bb[2] - bb[0])) / 2 - bb[0], h * 0.06 - bb[1]), "FIRE BLASTER", font=big, fill=255)
    top1, bottom1 = h * 0.06, h * 0.06 + (bb[3] - bb[1])
    mask2 = Image.new("L", (w, h), 0)
    md2 = ImageDraw.Draw(mask2)
    bb2 = md2.textbbox((0, 0), "RACE", font=small)
    y2 = bottom1 + h * 0.08
    md2.text(((w - (bb2[2] - bb2[0])) / 2 - bb2[0], y2 - bb2[1]), "RACE", font=small, fill=255)
    bar_y = y2 + (bb2[3] - bb2[1]) / 2
    for side in (-1, 1):
        x_in = (w / 2) + side * ((bb2[2] - bb2[0]) / 2 + w * 0.03)
        x_out = x_in + side * w * 0.2
        md2.polygon([(x_in, bar_y - h * 0.03), (x_out, bar_y - h * 0.03), (x_out - side * w * 0.02, bar_y + h * 0.03), (x_in - side * w * 0.02, bar_y + h * 0.03)], fill=255)
    shear = (1, 0.22, -0.11 * h, 0, 1, 0)
    mask = mask.transform((w, h), Image.AFFINE, shear, resample=Image.BICUBIC)
    mask2 = mask2.transform((w, h), Image.AFFINE, shear, resample=Image.BICUBIC)
    both = ImageChops.lighter(mask, mask2)
    outline = both.filter(ImageFilter.MaxFilter(int(h * 0.045) | 1))
    glow = outline.filter(ImageFilter.GaussianBlur(h * 0.05))
    def layer(color, m):
        l = Image.new("RGBA", (w, h), color)
        l.putalpha(ImageChops.multiply(m, Image.new("L", (w, h), color[3])))
        return l
    canvas.alpha_composite(layer((255, 90, 20, 190), glow))
    canvas.alpha_composite(layer((60, 10, 0, 255), outline))
    grad = vertical_gradient((w, h), lambda t: flame_color(min(1, max(0, (t * h - top1) / max(1, bottom1 - top1)))) ).convert("RGBA")
    grad.putalpha(mask)
    canvas.alpha_composite(grad)
    canvas.alpha_composite(layer((255, 255, 255, 255), mask2))
    # Glanzlicht auf der oberen Haelfte der Buchstaben
    hl = Image.new("L", (w, h), 0)
    ImageDraw.Draw(hl).rectangle([0, 0, w, top1 + (bottom1 - top1) * 0.38], fill=110)
    canvas.alpha_composite(layer((255, 255, 240, 255), ImageChops.multiply(mask, hl.filter(ImageFilter.GaussianBlur(h * 0.01)))))
    return canvas

def fireball(img, cx, cy, r):
    glow_blob(img, cx, cy, r * 1.8, r * 1.8, (255, 90, 20), r * 0.6, 160)
    glow_blob(img, cx, cy, r, r, (255, 140, 30), r * 0.2, 255)
    glow_blob(img, cx - r * 0.2, cy - r * 0.2, r * 0.5, r * 0.5, (255, 240, 170), r * 0.15, 255)

def item_box(img, cx, cy, s):
    w, h = img.size
    glow_blob(img, cx, cy, s * 1.2, s * 1.2, (255, 160, 40), s * 0.4, 140)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2], radius=s * 0.15, fill=(255, 170, 50, 170), outline=(255, 240, 180, 255), width=max(2, int(s * 0.05)))
    f = ImageFont.truetype(FONT, int(s * 0.75))
    bb = d.textbbox((0, 0), "?", font=f)
    d.text((cx - (bb[2] + bb[0]) / 2, cy - (bb[3] + bb[1]) / 2), "?", font=f, fill=(255, 255, 255, 255), stroke_width=max(1, int(s * 0.04)), stroke_fill=(180, 60, 0, 255))
    img.alpha_composite(layer.rotate(-12, center=(cx, cy), resample=Image.BICUBIC))

def thumbnail(path):
    W, H = 1920 * 2, 1080 * 2
    img = background(W, H, 4)
    road(img, H * 0.5, -0.12)
    kart(img, W * 0.36, H * 0.74, H * 0.13, body=(60, 140, 255), accent=(240, 240, 255), helmet=(255, 220, 60))
    kart(img, W * 0.62, H * 0.8, H * 0.2, body=(255, 120, 40))
    fireball(img, W * 0.86, H * 0.66, H * 0.05)
    item_box(img, W * 0.18, H * 0.56, H * 0.1)
    item_box(img, W * 0.8, H * 0.5, H * 0.08)
    lg = logo((int(W * 0.84), int(H * 0.44)))
    img.alpha_composite(lg, (int(W * 0.08), int(H * 0.02)))
    img = img.convert("RGB").resize((1920, 1080), Image.LANCZOS)
    img.save(path)

def icon(path):
    S = 1024
    img = background(S, S, 9)
    road(img, S * 0.55, 0.08)
    kart(img, S * 0.57, S * 0.75, S * 0.2, body=(255, 120, 40))
    fireball(img, S * 0.15, S * 0.62, S * 0.045)
    lg = logo((S, int(S * 0.52)))
    img.alpha_composite(lg, (-int(S * 0.035), int(S * 0.03)))
    # Rahmen
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 6, S - 6, S - 6], radius=60, outline=(255, 150, 34, 255), width=12)
    img = img.convert("RGB").resize((512, 512), Image.LANCZOS)
    img.save(path)

def logo_file(path):
    lg = logo((2400, 1000))
    lg.resize((1200, 500), Image.LANCZOS).save(path)

if __name__ == "__main__":
    logo_file(f"{OUT}/logo.png")
    icon(f"{OUT}/icon.png")
    thumbnail(f"{OUT}/thumbnail.png")
    print("ok")
