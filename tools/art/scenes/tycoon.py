# Magic Garden Tycoon: Gaertner mit Giesskanne vor riesigen, leuchtenden Zauberfruechten.
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv
LEAF = "#3fbf4a"


def fruit(loc, r, m, leaves=5, glow=None):
    x, y, z = loc
    root = R.empty(loc)
    R.ball(r, (0, 0, 0), (1, 1, 0.92), m=m, parent=root)
    R.cyl(0.08 * r, 0.4 * r, (0, 0, 0.98 * r), m=R.mat("#4a7a2a"), parent=root)
    lm = R.mat(LEAF, rough=0.35, coat=0.5)
    for i in range(leaves):
        a = i / leaves * 360
        lf = R.ball(0.32 * r, (0.32 * r * math.cos(math.radians(a)), 0.32 * r * math.sin(math.radians(a)), 0.95 * r),
                    (1.0, 0.45, 0.12), m=lm, parent=root)
        lf.rotation_euler = (0, math.radians(-25), math.radians(a))
    return root


def plant(loc, h, fm, fr):
    x, y, z = loc
    R.cyl(0.12, h, (x, y, z + h / 2), m=R.mat("#3d9a3a"))
    lm = R.mat(LEAF, rough=0.35, coat=0.5)
    for k, side in enumerate((-1, 1)):
        R.ball(0.5, (x + side * 0.45, y, z + h * (0.35 + 0.2 * k)), (1.0, 0.45, 0.14), (0, side * -30, 0), m=lm)
    fruit((x, y, z + h + fr * 0.8), fr, fm)


def garden():
    R.ground(m=R.mat("#5fcf55", rough=0.8, coat=0), size=300)
    soil = R.mat("#7a4a2a", rough=0.85, coat=0)
    cols = ["#ff3b6b", "#ffcc22", "#8a5bff", "#ff8a1f", "#25b8ff", "#ff5ad1"]
    random.seed(3)
    for row in range(5):
        y = 4 + row * 4.2
        R.box((34, 2.6, 0.6), (0, y, 0.3), m=soil, bevel=0.2)
        for i in range(9):
            x = -16 + i * 4 + random.uniform(-0.6, 0.6)
            c = cols[(i + row) % len(cols)]
            plant((x, y, 0.6), 1.4 + random.uniform(0, 0.6), R.mat(c, rough=0.25, coat=0.8, emit=0.05), 0.45 + random.uniform(0, 0.15))
    # Zaun
    wood = R.mat("#e8c08a", rough=0.6, coat=0.1)
    for i in range(-12, 13):
        R.box((0.35, 0.35, 1.8), (i * 3, 26, 0.9), m=wood, bevel=0.08)
    R.box((75, 0.25, 0.3), (0, 26, 1.4), m=wood, bevel=0.06)
    for x, y, z, s in ((-35, 90, 18, 4.5), (20, 100, 24, 5.5), (60, 95, 12, 5), (-70, 110, 28, 6)):
        R.cloud((x, y, z), s)
    # Baeume im Hintergrund
    for x, y in ((-30, 40), (-22, 46), (24, 44), (34, 38), (-40, 50), (44, 52)):
        R.cyl(0.8, 6, (x, y, 3), m=R.mat("#8a5a34", rough=0.7))
        R.ball(4.2, (x, y, 8.5), (1, 1, 0.9), m=R.mat("#2fa84a", rough=0.6, coat=0.1))


def gardener(loc, rot, scale=1.0):
    pose = {"ra": (-75, 0, -20), "la": (10, 0, 12), "ll": (12, 0, 0), "rl": (-12, 0, 0), "head": (0, 0, 10)}
    p = R.noob(loc, rot, shirt="#39c46a", pants="#3b5bdb", mood="grin", pose=pose, scale=scale)
    # Strohhut
    straw = R.mat("#f3cf6a", rough=0.6, coat=0.1)
    R.cyl(1.25, 0.12, (0, 0, 1.25), m=straw, parent=p["head"], bevel=0.04)
    R.cyl(0.72, 0.55, (0, 0, 1.5), m=straw, parent=p["head"], bevel=0.12)
    R.cyl(0.74, 0.16, (0, 0, 1.33), m=R.mat("#e8323c"), parent=p["head"])
    # Giesskanne in der rechten Hand
    can = R.mat("#25b8ff", rough=0.25, metal=0.3, coat=0.8)
    hand = R.empty((0, -0.2, -1.9), (0, 0, 0), parent=p["ra"])
    R.cyl(0.6, 1.1, (0, -0.2, -0.2), (90, 0, 0), m=can, parent=hand, bevel=0.1)
    R.cone(0.18, 0.08, 1.6, (0.9, -0.2, 0.1), (0, 60, 0), m=can, parent=hand)
    R.torus(0.45, 0.09, (-0.5, -0.2, -0.2), (90, 0, 0), m=can, parent=hand)
    return p


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#d6f3ff", 1.0, top="#3a9bff")
    garden()
    R.sun((52, 0, 30), 4.0)
    rain = R.rainbow_mat(emit=0.25)
    gold = R.mat("#ffcc22", rough=0.15, metal=0.6, coat=0.9, emit=0.1)
    if kind == "thumb":
        cam = R.camera((0, -17, 4.2), (0, 0, 4.4), lens=30)
        gardener((-5.6, -1.0, 0), (0, 0, 32))
        fruit((2.4, 0.5, 2.75), 2.9, rain, glow="#ffe8ff")
        fruit((8.0, 2.5, 1.95), 2.1, gold, glow="#fff1a0")
        fruit((-1.2, -4.0, 0.92), 1.0, R.mat("#ff3b6b", rough=0.25, coat=0.8))
        for x, y, z in ((-2.5, -5, 6.0), (5.5, -4, 7.5), (11.5, -3, 5.5), (-0.8, -6, 3.2), (6.0, -6, 2.2)):
            R.coin((x, y, z), (75, 0, x * 15), 0.55)
        for x, y, z, sc in ((2.5, -2, 7.6, 0.6), (-0.6, -3, 5.2, 0.4), (9.6, -2, 5.0, 0.45), (5.2, -3, 3.6, 0.3)):
            R.sparkle((x, y, z), sc, "#fff8d0")
        R.area((-10, -14, 12), (0, 0, 3), 5000, "#ffffff", 10)
        R.area((12, 10, 10), (3, 0, 4), 7000, "#ffd2f6", 6)
        R.place_title(cam, "MAGIC GARDEN", -0.36, 0.77, 6, 0.1, tilt=5, colors=(("0", "#c03bff"), ("0.5", "#ff5ad1"), ("1", "#ffb3f0")),
                      outline="#2a0a3a")
        R.place_title(cam, "TYCOON", -0.36, 0.5, 6, 0.13, tilt=5, colors=(("0.05", "#21a33a"), ("0.6", "#7dff6a"), ("1", "#e5ffb0")),
                      outline="#0d2a12")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((0, -12.5, 4.6), (0, 0, 4.2), lens=34)
        fruit((0.8, 0, 3.4), 3.2, rain, glow="#ffe8ff")
        gardener((-4.0, -2.0, 0), (0, 0, 35), 0.9)
        for x, y, z in ((3.8, -4, 1.6), (4.8, -3, 7.8), (-3.6, -3, 8.2)):
            R.coin((x, y, z), (75, 0, x * 15), 0.55)
        R.sparkle((2.8, -3, 8.2), 0.6, "#fff8d0")
        R.sparkle((-1.0, -4, 6.4), 0.4, "#fff8d0")
        R.area((-10, -14, 12), (0, 0, 3), 5000, "#ffffff", 10)
        R.area((12, 10, 10), (0, 0, 4), 7000, "#ffd2f6", 6)
        R.place_title(cam, "GARDEN", 0.0, -0.72, 6, 0.15, tilt=4, colors=(("0.05", "#21a33a"), ("0.6", "#7dff6a"), ("1", "#e5ffb0")),
                      outline="#0d2a12")
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
