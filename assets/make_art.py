# Erzeugt Icon (512x512) und Vorschaubild (1920x1080) in drei Varianten.
# Aufruf: python3 assets/make_art.py <ausgabeordner>
import colorsys
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Black.otf"
FONT_ITALIC = "/usr/share/fonts/opentype/inter/Inter-BlackItalic.otf"
SS = 2  # Supersampling fuer glatte Kanten
INK = (20, 14, 34)


def burst(size, inner, outer, center, rays=24, ray_alpha=40):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    cx, cy = center
    maxd = math.hypot(max(cx, w - cx), max(cy, h - cy))
    # Radialer Verlauf in kleiner Aufloesung, dann hochskalieren (schnell)
    small = Image.new("RGB", (w // 8, h // 8))
    sp = small.load()
    for y in range(small.height):
        for x in range(small.width):
            t = min(1, math.hypot(x * 8 - cx, y * 8 - cy) / maxd)
            t = t ** 0.8
            sp[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    img = small.resize(size, Image.BICUBIC)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(rays):
        a0 = (i / rays) * 2 * math.pi
        a1 = a0 + math.pi / rays
        r = maxd * 1.5
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)), (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(255, 255, 255, ray_alpha))
    img = img.convert("RGBA")
    img.alpha_composite(layer)
    return img


def glow(img, xy, radius, color, strength=200):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = xy
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color + (strength,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    img.alpha_composite(layer)


def shadow_shape(img, draw_fn, offset, blur):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer), (0, 0, 0, 120))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    shifted = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shifted.paste(layer, offset, layer)
    img.alpha_composite(shifted)


def critter(img, cx, cy, r, color, mood="happy", rainbow=False, crown=0, sparkle=False):
    d = ImageDraw.Draw(img)
    o = max(4, r // 12)
    shadow_shape(img, lambda dd, c: dd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c), (o, o * 2), o * 2)
    d.ellipse((cx - r - o, cy - r - o, cx + r + o, cy + r + o), fill=INK)
    if rainbow:
        body = Image.new("RGBA", (2 * r, 2 * r))
        bp = body.load()
        for y in range(2 * r):
            for x in range(2 * r):
                hue = ((x + y) / (4 * r)) % 1
                rr, gg, bb = colorsys.hsv_to_rgb(hue, 0.75, 1)
                bp[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), 255)
        mask = Image.new("L", (2 * r, 2 * r), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, 2 * r - 1, 2 * r - 1), fill=255)
        img.paste(body, (cx - r, cy - r), mask)
    else:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
    # Glanzlicht
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse((cx - r * 0.6, cy - r * 0.8, cx - r * 0.05, cy - r * 0.35), fill=(255, 255, 255, 110))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(r * 0.06)))
    d = ImageDraw.Draw(img)
    # Augen
    er = r * 0.24
    for sx in (-1, 1):
        ex, ey = cx + sx * r * 0.36, cy - r * 0.08
        d.ellipse((ex - er - o / 2, ey - er - o / 2, ex + er + o / 2, ey + er + o / 2), fill=INK)
        d.ellipse((ex - er, ey - er, ex + er, ey + er), fill="white")
        pr = er * 0.55
        px_ = ex + sx * er * 0.15 if mood != "shock" else ex
        d.ellipse((px_ - pr, ey - pr + er * 0.1, px_ + pr, ey + pr + er * 0.1), fill=INK)
        d.ellipse((px_ - pr * 0.25 - pr * 0.3, ey - pr * 0.6, px_ + pr * 0.25 - pr * 0.3, ey - pr * 0.1), fill="white")
        if mood == "angry":
            d.line((ex - er * 1.1, ey - er * (1.6 if sx < 0 else 1.0), ex + er * 1.1, ey - er * (1.0 if sx < 0 else 1.6)), fill=INK, width=int(o * 1.6))
    mw = int(o * 1.3)
    if mood == "happy":
        d.arc((cx - r * 0.35, cy + r * 0.05, cx + r * 0.35, cy + r * 0.55), 20, 160, fill=INK, width=mw)
    elif mood == "shock":
        d.ellipse((cx - r * 0.13, cy + r * 0.3, cx + r * 0.13, cy + r * 0.62), fill=INK)
    elif mood == "angry":
        d.arc((cx - r * 0.3, cy + r * 0.35, cx + r * 0.3, cy + r * 0.75), 200, 340, fill=INK, width=mw)
    elif mood == "grin":
        d.chord((cx - r * 0.4, cy + r * 0.05, cx + r * 0.4, cy + r * 0.6), 0, 180, fill=INK)
        d.chord((cx - r * 0.3, cy + r * 0.12, cx + r * 0.3, cy + r * 0.35), 0, 180, fill="white")
    # Sterne fuer Fusion
    if crown:
        sr = r * 0.22
        for i in range(crown):
            off = (i - (crown - 1) / 2) * sr * 2.2
            star(d, cx + off, cy - r - sr * 0.9, sr, (255, 215, 40))
    if sparkle:
        rnd = random.Random(cx * 7 + cy)
        for _ in range(7):
            a = rnd.uniform(0, 2 * math.pi)
            dist = r * rnd.uniform(1.1, 1.45)
            twinkle(d, cx + dist * math.cos(a), cy + dist * math.sin(a), r * rnd.uniform(0.08, 0.16))


def star(d, cx, cy, r, color, points=5):
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * 0.45
        a = -math.pi / 2 + i * math.pi / points
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=color, outline=INK, width=max(3, int(r * 0.18)))


def twinkle(d, cx, cy, r):
    pts = [(cx, cy - r), (cx + r * 0.25, cy - r * 0.25), (cx + r, cy), (cx + r * 0.25, cy + r * 0.25), (cx, cy + r), (cx - r * 0.25, cy + r * 0.25), (cx - r, cy), (cx - r * 0.25, cy - r * 0.25)]
    d.polygon(pts, fill=(255, 255, 220))


def bill(img, cx, cy, s, angle):
    b = Image.new("RGBA", (int(s * 2.2), int(s * 1.1)), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    w, h = b.size
    o = max(3, int(s * 0.07))
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=o * 2, fill=INK)
    d.rounded_rectangle((o, o, w - 1 - o, h - 1 - o), radius=o, fill=(110, 220, 90))
    d.ellipse((w / 2 - h * 0.3, h * 0.2, w / 2 + h * 0.3, h * 0.8), fill=(70, 170, 60))
    f = ImageFont.truetype(FONT, int(h * 0.5))
    d.text((w / 2, h / 2), "$", font=f, anchor="mm", fill=(230, 255, 220))
    b = b.rotate(angle, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(b, (int(cx - b.width / 2), int(cy - b.height / 2)))


def robloxian(img, cx, cy, s, shirt, pants, skin=(255, 205, 150), arms_up=True, run=True, face="grin", mirror=False):
    """Blockiger Avatar. (cx, cy) = Mitte des Oberkoerpers, s = Torso-Breite."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    o = max(4, int(s * 0.06))

    def box(x0, y0, x1, y1, fill, angle=0, pivot=None):
        if angle == 0:
            d.rounded_rectangle((x0 - o, y0 - o, x1 + o, y1 + o), radius=o * 2, fill=INK)
            d.rounded_rectangle((x0, y0, x1, y1), radius=o, fill=fill)
            return
        piece = Image.new("RGBA", img.size, (0, 0, 0, 0))
        pd = ImageDraw.Draw(piece)
        pd.rounded_rectangle((x0 - o, y0 - o, x1 + o, y1 + o), radius=o * 2, fill=INK)
        pd.rounded_rectangle((x0, y0, x1, y1), radius=o, fill=fill)
        piece = piece.rotate(angle, center=pivot, resample=Image.BICUBIC)
        layer.alpha_composite(piece)

    tw, th = s, s * 1.0
    lw, lh = s * 0.48, s * 0.95
    aw, ah = s * 0.4, s * 0.9
    top = cy - th / 2
    hip = cy + th / 2
    # Beine (laufend)
    la, ra = (-14, 14) if run else (0, 0)
    box(cx - tw / 2, hip, cx - tw / 2 + lw, hip + lh, pants, la, (cx - tw / 4, hip))
    box(cx + tw / 2 - lw, hip, cx + tw / 2, hip + lh, pants, ra, (cx + tw / 4, hip))
    # Arme
    if arms_up:
        box(cx - tw / 2 - aw, top - ah * 0.95, cx - tw / 2, top + ah * 0.05, skin, -12, (cx - tw / 2, top))
        box(cx + tw / 2, top - ah * 0.95, cx + tw / 2 + aw, top + ah * 0.05, skin, 12, (cx + tw / 2, top))
    else:
        box(cx - tw / 2 - aw, top, cx - tw / 2, top + ah, shirt, -35, (cx - tw / 2, top))
        box(cx + tw / 2, top, cx + tw / 2 + aw, top + ah, shirt, 70, (cx + tw / 2, top))
    box(cx - tw / 2, top, cx + tw / 2, hip, shirt)
    # Kopf
    hs = s * 0.62
    hy = top - hs * 0.55
    box(cx - hs / 2, hy - hs / 2, cx + hs / 2, hy + hs / 2, skin)
    ex = hs * 0.18
    for sx in (-1, 1):
        d.ellipse((cx + sx * ex - hs * 0.06, hy - hs * 0.15, cx + sx * ex + hs * 0.06, hy + hs * 0.02), fill=INK)
    if face == "grin":
        d.chord((cx - hs * 0.25, hy + hs * 0.02, cx + hs * 0.25, hy + hs * 0.3), 0, 180, fill=INK)
    elif face == "angry":
        for sx in (-1, 1):
            d.line((cx + sx * ex - hs * 0.1, hy - hs * (0.3 if sx < 0 else 0.2), cx + sx * ex + hs * 0.1, hy - hs * (0.2 if sx < 0 else 0.3)), fill=INK, width=o)
        d.ellipse((cx - hs * 0.12, hy + hs * 0.1, cx + hs * 0.12, hy + hs * 0.3), fill=INK)
    alpha = layer.getchannel("A").point(lambda a: int(a * 0.45))
    sh = Image.new("RGBA", img.size, (0, 0, 0, 255))
    sh.putalpha(alpha)
    sh = sh.filter(ImageFilter.GaussianBlur(o * 2))
    moved = Image.new("RGBA", img.size, (0, 0, 0, 0))
    moved.alpha_composite(sh, (o * 2, o * 3))
    img.alpha_composite(moved)
    img.alpha_composite(layer)


def text(img, xy, s, size, fill, stroke=None, italic=True, anchor="mm", angle=0, gradient=None):
    f = ImageFont.truetype(FONT_ITALIC if italic else FONT, size)
    sw = stroke if stroke is not None else max(6, size // 9)
    probe = ImageDraw.Draw(img).textbbox((0, 0), s, font=f, stroke_width=sw)
    w, h = probe[2] - probe[0] + sw * 4, probe[3] - probe[1] + sw * 6
    t = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    pos = (w / 2, h / 2)
    # Schatten, Umriss, Fuellung
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((pos[0] + sw * 0.4, pos[1] + sw * 0.9), s, font=f, anchor="mm", fill=INK + (255,), stroke_width=sw, stroke_fill=INK)
    t.alpha_composite(sh)
    d.text(pos, s, font=f, anchor="mm", fill=INK, stroke_width=sw, stroke_fill=INK)
    if gradient:
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).text(pos, s, font=f, anchor="mm", fill=255)
        grad = Image.new("RGBA", (w, h))
        gp = ImageDraw.Draw(grad)
        top_c, bot_c = gradient
        for y in range(h):
            k = y / h
            gp.line((0, y, w, y), fill=tuple(int(top_c[i] + (bot_c[i] - top_c[i]) * k) for i in range(3)))
        t.paste(grad, (0, 0), mask)
    else:
        d.text(pos, s, font=f, anchor="mm", fill=fill)
    if angle:
        t = t.rotate(angle, expand=True, resample=Image.BICUBIC)
    x, y = xy
    img.alpha_composite(t, (int(x - t.width / 2), int(y - t.height / 2)))


YELLOW = ((255, 240, 90), (255, 170, 20))
RED = ((255, 110, 90), (220, 20, 40))
WHITE = ((255, 255, 255), (210, 225, 255))


def scene_heist(W, H, icon):
    """Variante A: Dieb rennt mit Regenbogen-Critter ueber dem Kopf, Geld fliegt."""
    k = W / 1920 if not icon else W / 512
    img = burst((W, H), (255, 214, 80), (200, 30, 90), (W * 0.5, H * 0.45), rays=22, ray_alpha=45)
    rnd = random.Random(3)
    for _ in range(14 if not icon else 6):
        bill(img, rnd.uniform(0, W), rnd.uniform(H * 0.1, H * 0.95), rnd.uniform(40, 70) * k * (0.8 if icon else 1), rnd.uniform(-40, 40))
    if icon:
        robloxian(img, int(W * 0.5), int(H * 0.74), int(105 * k), (230, 40, 50), (40, 40, 60))
        glow(img, (int(W * 0.5), int(H * 0.4)), int(130 * k), (255, 255, 255), 230)
        critter(img, int(W * 0.5), int(H * 0.4), int(95 * k), None, "shock", rainbow=True, sparkle=True)
        text(img, (W * 0.5, H * 0.1), "STEAL!", int(96 * k), None, angle=6, gradient=RED)
    else:
        # verfolgender, wuetender Besitzer + kleine Critters
        robloxian(img, int(W * 0.2), int(H * 0.68), int(150 * k), (40, 120, 255), (30, 30, 60), arms_up=False, face="angry")
        critter(img, int(W * 0.09), int(H * 0.88), int(70 * k), (255, 90, 170), "angry")
        robloxian(img, int(W * 0.56), int(H * 0.66), int(190 * k), (230, 40, 50), (40, 40, 60))
        glow(img, (int(W * 0.56), int(H * 0.3)), int(220 * k), (255, 255, 255), 230)
        critter(img, int(W * 0.56), int(H * 0.3), int(150 * k), None, "shock", rainbow=True, sparkle=True)
        text(img, (W * 0.56, H * 0.06), "RAINBOW x10", int(54 * k), None, gradient=WHITE)
        critter(img, int(W * 0.86), int(H * 0.8), int(110 * k), (255, 210, 40), "happy", crown=3)
        text(img, (W * 0.25, H * 0.16), "STEAL A", int(150 * k), None, angle=4, gradient=WHITE)
        text(img, (W * 0.24, H * 0.36), "CRITTER!", int(170 * k), None, angle=4, gradient=YELLOW)
        text(img, (W * 0.84, H * 0.52), "FUSE ★★★", int(64 * k), None, angle=-6, gradient=YELLOW)
    return img


def scene_mythic(W, H, icon):
    """Variante B: riesiger goldener Mythic-Critter mit Sternen, Diebeshand greift danach."""
    k = W / 1920 if not icon else W / 512
    img = burst((W, H), (120, 70, 255), (20, 10, 60), (W * 0.5, H * 0.52), rays=28, ray_alpha=35)
    cx, cy = int(W * 0.5), int(H * (0.58 if icon else 0.55))
    r = int((125 if icon else 260) * k)
    glow(img, (cx, cy), int(r * 1.6), (255, 200, 40), 255)
    critter(img, cx, cy, r, (255, 200, 30), "grin", crown=3, sparkle=True)
    rnd = random.Random(9)
    for _ in range(18 if not icon else 8):
        a = rnd.uniform(0, 2 * math.pi)
        dist = r * rnd.uniform(1.7, 2.6)
        twinkle(ImageDraw.Draw(img), cx + dist * math.cos(a), cy + dist * math.sin(a), rnd.uniform(10, 26) * k)
    if icon:
        text(img, (W * 0.5, H * 0.12), "MYTHIC", int(92 * k), None, angle=-4, gradient=YELLOW)
        text(img, (W * 0.5, H * 0.9), "STEAL IT!", int(78 * k), None, angle=-4, gradient=RED)
    else:
        for i, (x, col, mood) in enumerate([(0.13, (90, 200, 255), "shock"), (0.87, (255, 90, 170), "angry")]):
            critter(img, int(W * x), int(H * 0.72), int(120 * k), col, mood)
        text(img, (W * 0.5, H * 0.1), "STEAL A CRITTER", int(150 * k), None, gradient=WHITE)
        text(img, (W * 0.5, H * 0.92), "FUSE · MUTATE · STEAL MYTHICS!", int(78 * k), None, gradient=YELLOW)
        text(img, (W * 0.17, H * 0.38), "GOLDEN x2", int(56 * k), None, angle=8, gradient=YELLOW)
        text(img, (W * 0.84, H * 0.36), "DIAMOND x4", int(56 * k), None, angle=-8, gradient=((200, 250, 255), (90, 200, 255)))
    return img


def scene_revenge(W, H, icon):
    """Variante C: Zwei Spieler zerren am selben Critter, 'STEAL IT BACK!'."""
    k = W / 1920 if not icon else W / 512
    img = burst((W, H), (60, 230, 255), (20, 60, 200), (W * 0.5, H * 0.45), rays=20, ray_alpha=50)
    if icon:
        glow(img, (int(W * 0.5), int(H * 0.5)), int(150 * k), (255, 255, 255), 200)
        critter(img, int(W * 0.5), int(H * 0.52), int(120 * k), (120, 255, 140), "shock", sparkle=True)
        critter(img, int(W * 0.17), int(H * 0.8), int(62 * k), (255, 90, 170), "angry")
        critter(img, int(W * 0.83), int(H * 0.8), int(62 * k), (255, 200, 40), "grin")
        text(img, (W * 0.5, H * 0.13), "STEAL A", int(84 * k), None, angle=-3, gradient=WHITE)
        text(img, (W * 0.5, H * 0.88), "CRITTER", int(90 * k), None, angle=-3, gradient=YELLOW)
    else:
        robloxian(img, int(W * 0.27), int(H * 0.62), int(170 * k), (230, 40, 50), (40, 40, 60), arms_up=False, face="angry")
        robloxian(img, int(W * 0.73), int(H * 0.62), int(170 * k), (255, 170, 20), (40, 40, 60), arms_up=False, face="grin", mirror=True)
        glow(img, (int(W * 0.5), int(H * 0.5)), int(200 * k), (255, 255, 255), 220)
        critter(img, int(W * 0.5), int(H * 0.5), int(150 * k), (120, 255, 140), "shock", crown=2, sparkle=True)
        rnd = random.Random(4)
        for _ in range(10):
            bill(img, rnd.uniform(W * 0.05, W * 0.95), rnd.uniform(H * 0.25, H * 0.9), 50 * k, rnd.uniform(-40, 40))
        text(img, (W * 0.5, H * 0.12), "STEAL A CRITTER", int(150 * k), None, gradient=WHITE)
        text(img, (W * 0.5, H * 0.9), "STEAL IT BACK! · REVENGE MODE", int(78 * k), None, gradient=YELLOW)
    return img


def render(fn, size, icon):
    big = fn(size[0] * SS, size[1] * SS, icon)
    return big.resize(size, Image.LANCZOS).convert("RGB")


if __name__ == "__main__":
    out = sys.argv[1]
    for name, fn in [("a_heist", scene_heist), ("b_mythic", scene_mythic), ("c_revenge", scene_revenge)]:
        render(fn, (512, 512), True).save(f"{out}/icon_{name}.png")
        render(fn, (1920, 1080), False).save(f"{out}/thumbnail_{name}.png")
        print("ok", name)
