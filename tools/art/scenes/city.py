# Turbo City: Raeuber flieht mit Geldsack, Polizeiauto mit Blaulicht jagt ihn durch die Stadt bei Abendrot.
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def police_car(loc, rot):
    root = R.empty(loc, rot)
    white = R.mat("#f4f6fb", rough=0.2, coat=1.0)
    navy = R.mat("#1d2b6b", rough=0.2, coat=1.0)
    R.box((4.4, 9.0, 1.5), (0, 0, 1.4), m=navy, parent=root, bevel=0.45)
    R.box((4.5, 4.0, 1.52), (0, 0.4, 1.42), m=white, parent=root, bevel=0.45)
    R.box((3.8, 4.4, 1.5), (0, 0.8, 2.75), m=white, parent=root, bevel=0.5)
    glass = R.mat("#9fd8ff", rough=0.05, coat=1, emit=0.15)
    R.box((3.5, 0.2, 1.1), (0, -1.45, 2.8), (-18, 0, 0), m=glass, parent=root, bevel=0.1)
    for sx in (-1, 1):
        R.box((0.2, 3.6, 1.0), (sx * 1.92, 0.8, 2.8), m=glass, parent=root, bevel=0.08)
    R.box((1.2, 0.8, 0.45), (-0.7, 0.8, 3.7), m=R.emit_mat("#ff2244", 12), parent=root, bevel=0.15)
    R.box((1.2, 0.8, 0.45), (0.7, 0.8, 3.7), m=R.emit_mat("#2a6bff", 12), parent=root, bevel=0.15)
    R.point((-1.5, -1, 5), 2500, "#ff2244", 0.5).parent = root
    R.point((1.5, -1, 5), 2500, "#2a6bff", 0.5).parent = root
    for sx in (-1, 1):
        R.box((1.0, 0.2, 0.5), (sx * 1.4, -4.5, 1.6), m=R.emit_mat("#fff6d0", 10), parent=root, bevel=0.1)
    tire = R.mat("#1a1a22", rough=0.7)
    for sx in (-1, 1):
        for sy in (-1, 1):
            R.cyl(0.95, 0.8, (sx * 2.1, sy * 2.9, 0.95), (0, 90, 0), m=tire, parent=root, bevel=0.2)
            R.cyl(0.5, 0.85, (sx * 2.15, sy * 2.9, 0.95), (0, 90, 0), m=R.mat("#c9ced8", metal=0.8, rough=0.2), parent=root)
    
    return root


def money_bag(parent, loc):
    bag = R.mat("#c99a5a", rough=0.7, coat=0.0)
    R.ball(1.1, loc, (1, 0.95, 1.05), m=bag, parent=parent)
    R.cyl(0.35, 0.5, (loc[0], loc[1], loc[2] + 1.15), m=bag, parent=parent)
    R.torus(0.38, 0.1, (loc[0], loc[1], loc[2] + 1.0), m=R.mat("#7a4a2a"), parent=parent)
    R.box((0.7, 0.12, 0.9), (loc[0], loc[1] - 1.02, loc[2] + 0.05), m=R.mat("#2fae4e", rough=0.4), parent=parent, bevel=0.06)


def city():
    R.ground(m=R.mat("#2a2d3a", rough=0.5, coat=0.3), size=300)
    R.box((10, 300, 0.05), (0, 0, 0.02), m=R.mat("#3a3e4e", rough=0.45, coat=0.4), bevel=0)
    for y in range(-40, 120, 8):
        R.box((0.4, 3.5, 0.06), (0, y, 0.05), m=R.emit_mat("#ffd23a", 1.2), bevel=0)
    random.seed(11)
    wins = [R.emit_mat(c, 2.5) for c in ("#ffd88a", "#ffe9b8", "#8fd8ff")]
    bodies = ["#3b2f6b", "#4a3a7c", "#2f3f6b", "#5a3a6b", "#2c2f55"]
    for side in (-1, 1):
        for i in range(10):
            y = 10 + i * 11
            w, d, h = random.uniform(7, 10), random.uniform(7, 10), random.uniform(12, 34)
            x = side * (12 + w / 2 + random.uniform(0, 3))
            R.box((w, d, h), (x, y, h / 2), m=R.mat(random.choice(bodies), rough=0.6, coat=0.1), bevel=0.2)
            for fz in range(2, int(h) - 1, 3):
                for fy in range(-1, 2):
                    if random.random() < 0.6:
                        R.box((0.1, 1.4, 1.4), (x - side * w / 2, y + fy * 2.6, fz), m=random.choice(wins), bevel=0)
    # Palmen
    for x, y in ((-8, 8), (8, 22), (-8, 36)):
        R.cyl(0.35, 7, (x, y, 3.5), m=R.mat("#8a5a34", rough=0.7))
        for a in range(0, 360, 60):
            import math
            R.ball(1.6, (x + 1.2 * math.cos(math.radians(a)), y + 1.2 * math.sin(math.radians(a)), 7.0), (1.6, 0.6, 0.18),
                   (0, -20, a), m=R.mat("#2fae4a", rough=0.5))


def robber(loc, rot, scale=1.0):
    pose = {"la": (-55, 0, 10), "ra": (-20, 0, -25), "ll": (40, 0, 0), "rl": (-45, 0, 0), "torso": (-10, 0, 0)}
    p = R.noob(loc, rot, shirt="#1f1f2a", pants="#2a2a3a", mood="grin", pose=pose, mask="#111118", scale=scale)
    for z in (0.6, 1.4):
        R.box((2.04, 1.04, 0.3), (0, 0, z), m=R.mat("#f4f4f4"), parent=p["torso"], bevel=0.05)
    money_bag(p["ra"], (0.3, -0.4, -3.3))
    return p


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#ff8a4a", 0.8, top="#3a1d6b")
    city()
    R.sun((80, 0, 180), 2.2, "#ffb070")
    if kind == "thumb":
        cam = R.camera((3, -15, 3.2), (0.5, 4, 4.6), lens=28)
        robber((3.5, -1.5, 0), (0, 0, 20))
        police_car((-3.2, 7.0, 0), (0, 0, 10))
        for x, y, z, a, b, c in ((6.5, -3, 7.0, 20, 30, 10), (8.0, -1, 4.0, -30, 60, 40), (1.0, -4, 8.5, 50, -20, 0), (9.5, 0, 8.0, 10, 80, -30)):
            R.cash((x, y, z), (a, b, c), 0.8)
        R.area((-8, -12, 10), (2, 0, 4), 6000, "#ffd9b0", 10)
        R.area((10, 6, 8), (3, 0, 5), 7000, "#ff5ad1", 6)
        R.place_title(cam, "TURBO CITY", -0.42, 0.74, 6, 0.15, tilt=5, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.place_title(cam, "COPS & ROBBERS", -0.42, 0.42, 6, 0.065, tilt=5, colors=(("0", "#ffffff"), ("1", "#dff4ff")), emit=0.4,
                      outline="#1d2b6b")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((1.5, -11.5, 4.4), (0.5, 4, 5.4), lens=32)
        robber((1.6, -1.5, 0), (0, 0, 15))
        police_car((-4.5, 9.5, 0), (0, 0, 8))
        R.cash((-2.8, -3, 7.5), (20, 30, 10), 0.8)
        R.cash((4.8, -3, 8.5), (-30, 60, 40), 0.8)
        R.area((-8, -12, 10), (2, 0, 4), 6000, "#ffd9b0", 10)
        R.area((10, 6, 8), (3, 0, 5), 7000, "#ff5ad1", 6)
        R.place_title(cam, "CITY", 0.0, -0.7, 6, 0.18, tilt=4, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
