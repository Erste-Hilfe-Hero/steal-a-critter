import math, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = sys.argv[1]
NAVY = (16, 22, 52)
NAVY2 = (32, 42, 90)
LIME = (190, 255, 60)
ORANGE = (255, 110, 30)
CYAN = (40, 200, 255)
WHITE = (255, 255, 255)
DARK = (10, 14, 34)
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-BlackItalic.otf"


def stripes(img, width, alpha=40, angle=24):
    w, h = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = width * 3
    slope = math.tan(math.radians(angle))
    i = 0
    for x in range(-h, w + h, step):
        col = (LIME if i % 2 == 0 else ORANGE) + (alpha,)
        d.polygon([(x, h), (x + width, h), (x + width + h * slope, 0), (x + h * slope, 0)], fill=col)
        i += 1
    img.alpha_composite(layer)


def ball(img, cx, cy, r, angle=15):
    d = ImageDraw.Draw(img)
    # Schatten
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r * 0.9, cy + r * 0.95, cx + r * 0.9, cy + r * 1.2], fill=(0, 0, 0, 110))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(r * 0.08)))
    d.ellipse([cx - r - r * 0.08, cy - r - r * 0.08, cx + r + r * 0.08, cy + r + r * 0.08], fill=DARK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)

    def pent(px, py, pr, rot):
        pts = [(px + pr * math.cos(math.radians(rot + 72 * k - 90)), py + pr * math.sin(math.radians(rot + 72 * k - 90))) for k in range(5)]
        d.polygon(pts, fill=NAVY)
        return pts

    center = pent(cx, cy, r * 0.33, angle)
    for k in range(5):
        a = math.radians(angle + 72 * k - 90)
        px, py = cx + r * 0.78 * math.cos(a), cy + r * 0.78 * math.sin(a)
        pent(px, py, r * 0.24, angle + 36)
        d.line([center[k], (cx + r * 0.6 * math.cos(a), cy + r * 0.6 * math.sin(a))], fill=NAVY, width=max(2, int(r * 0.05)))
    # Glanz
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([cx - r * 0.65, cy - r * 0.8, cx - r * 0.05, cy - r * 0.35], fill=(255, 255, 255, 120))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    img.paste(Image.alpha_composite(img, gl.filter(ImageFilter.GaussianBlur(r * 0.05))), (0, 0), mask)
    # Lime-Glow-Ring
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([cx - r * 1.12, cy - r * 1.12, cx + r * 1.12, cy + r * 1.12], outline=LIME + (200,), width=max(3, int(r * 0.06)))
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(r * 0.03)))


def streaks(img, cx, cy, r):
    d = ImageDraw.Draw(img)
    for k, (dy, length, col) in enumerate([(-0.55, 1.6, LIME), (0.0, 2.2, ORANGE), (0.55, 1.4, LIME), (-0.95, 0.9, WHITE), (0.95, 0.8, WHITE)]):
        y = cy + dy * r
        x1 = cx - r * 1.05
        x0 = x1 - length * r
        th = r * (0.16 if col != WHITE else 0.07)
        d.rounded_rectangle([x0, y - th / 2, x1, y + th / 2], radius=th / 2, fill=col)


def outlined_text(img, xy, text, size, fill, outline=DARK, stroke=None, anchor="mm", rot=0):
    font = ImageFont.truetype(FONT, size)
    stroke = stroke or max(4, size // 12)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # harter Schatten nach rechts unten
    off = max(3, size // 18)
    d.text((xy[0] + off, xy[1] + off), text, font=font, fill=DARK, anchor=anchor, stroke_width=stroke, stroke_fill=DARK)
    d.text(xy, text, font=font, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=outline)
    if rot:
        layer = layer.rotate(rot, center=xy, resample=Image.BICUBIC)
    img.alpha_composite(layer)


def background(w, h):
    img = Image.new("RGBA", (w, h), NAVY + (255,))
    # radialer Lichtschein
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([w * 0.1, h * 0.05, w * 0.9, h * 0.95], fill=NAVY2 + (255,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(min(w, h) * 0.15)))
    return img


def icon():
    w = h = 512
    img = background(w, h)
    stripes(img, 46, 50)
    # Rasen-Streifen unten
    d = ImageDraw.Draw(img)
    d.polygon([(0, 400), (512, 360), (512, 512), (0, 512)], fill=(58, 150, 60))
    d.polygon([(0, 400), (512, 360), (512, 372), (0, 412)], fill=WHITE)
    streaks(img, 300, 205, 120)
    ball(img, 300, 205, 120)
    outlined_text(img, (256, 378), "TURBO", 112, LIME, rot=6)
    outlined_text(img, (262, 448), "SOCCER", 64, ORANGE, rot=6)
    # Rahmen
    ImageDraw.Draw(img).rounded_rectangle([6, 6, w - 7, h - 7], radius=40, outline=LIME, width=10)
    img.convert("RGB").save(f"{OUT}/icon.png")


def rrect(d, cx, cy, w, h, ang, fill):
    a = math.radians(ang)
    pts = []
    for dx, dy in [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]:
        pts.append((cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)))
    d.polygon(pts, fill=fill, outline=DARK, width=5)


def player_silhouette(img, x, y, s, color, facing=1):
    d = ImageDraw.Draw(img)
    leg = (30, 34, 60)
    skin = (255, 220, 190)
    # Beine im Laufschritt (um die Huefte gedreht)
    rrect(d, x - 0.25 * s - 0.35 * s * facing, y + 0.55 * s, 0.5 * s, 1.5 * s, 25 * facing, leg)
    rrect(d, x + 0.25 * s + 0.35 * s * facing, y + 0.55 * s, 0.5 * s, 1.5 * s, -30 * facing, leg)
    # Arme
    rrect(d, x - 0.95 * s, y - 0.9 * s, 0.45 * s, 1.3 * s, 35 * facing, skin)
    rrect(d, x + 0.95 * s, y - 0.9 * s, 0.45 * s, 1.3 * s, 35 * facing, skin)
    # Trikot und Kopf
    d.rounded_rectangle([x - 0.7 * s, y - 1.6 * s, x + 0.7 * s, y - 0.1 * s], radius=s * 0.12, fill=color, outline=DARK, width=5)
    d.rounded_rectangle([x - 0.45 * s, y - 2.55 * s, x + 0.45 * s, y - 1.65 * s], radius=s * 0.2, fill=skin, outline=DARK, width=5)
    d.ellipse([x - 0.2 * s, y - 2.25 * s, x - 0.08 * s, y - 2.1 * s], fill=DARK)
    d.ellipse([x + 0.08 * s, y - 2.25 * s, x + 0.2 * s, y - 2.1 * s], fill=DARK)


def thumbnail():
    w, h = 1920, 1080
    img = background(w, h)
    stripes(img, 120, 38)
    d = ImageDraw.Draw(img)
    # Perspektivischer Rasen mit Streifen
    horizon = 640
    d.rectangle([0, horizon, w, h], fill=(58, 150, 60))
    for i in range(10):
        x0 = -400 + i * 272
        col = (70, 170, 70) if i % 2 == 0 else (58, 150, 60)
        d.polygon([(x0 * 0.45 + 528, horizon), ((x0 + 272) * 0.45 + 528, horizon), (x0 + 272 + (x0 - 960) * 0.4, h), (x0 + (x0 - 960) * 0.4, h)], fill=col)
    d.line([(0, horizon), (w, horizon)], fill=WHITE, width=6)
    # Mittelkreis angedeutet
    d.ellipse([560, 800, 1360, 1180], outline=WHITE, width=10)
    # Tor rechts (Blaze, Orange-Neon)
    gx = 1500
    d.rectangle([gx, 420, gx + 380, 650], outline=ORANGE, width=16)
    for k in range(1, 8):
        d.line([(gx + k * 47, 420), (gx + k * 47, 650)], fill=ORANGE + (120,), width=3)
    for k in range(1, 5):
        d.line([(gx, 420 + k * 46), (gx + 380, 420 + k * 46)], fill=ORANGE, width=3)
    # Spieler
    player_silhouette(img, 520, 820, 95, CYAN, facing=-1)
    player_silhouette(img, 1300, 760, 70, ORANGE, facing=1)
    # Ball fliegt aufs Tor
    streaks(img, 1080, 520, 120)
    ball(img, 1080, 520, 120, angle=30)
    # Logo oben links
    outlined_text(img, (520, 170), "TURBO", 230, LIME, rot=5)
    outlined_text(img, (560, 330), "SOCCER", 140, ORANGE, rot=5)
    # Feature-Leiste
    font = ImageFont.truetype(FONT, 54)
    bar = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    bd.rounded_rectangle([80, 950, 1840, 1040], radius=45, fill=DARK + (230,), outline=LIME, width=6)
    bd.text((960, 995), "SHOOT  •  TACKLE  •  LEVEL UP 5 SKILLS  •  PLAY WITH FRIENDS", font=font, fill=WHITE, anchor="mm")
    img.alpha_composite(bar)
    img.convert("RGB").save(f"{OUT}/thumbnail.png")


icon()
thumbnail()
