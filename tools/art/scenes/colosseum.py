# Colosseum Catcher: Feuer- und Eis-Bestie treten in der Arena gegeneinander an, Trainer wirft einen Fang-Orb.
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def arena():
    R.ground(m=R.mat("#c99a66", rough=0.9, coat=0), size=300)
    stone = R.mat("#d8b48a", rough=0.75, coat=0.0)
    dark = R.mat("#7a4a2a", rough=0.8)
    rad = 34
    for i in range(44):
        a = math.radians(30 + i * (120 / 43))
        x, y = rad * math.cos(a), rad * math.sin(a)
        rot = (0, 0, math.degrees(a) + 90)
        for tier in range(3):
            z = tier * 7
            R.box((1.2, 3.0, 6.0), (x, y, z + 3.0), rot, m=stone, bevel=0.15)
            R.box((5.4, 3.0, 1.2), (x, y, z + 6.4), rot, m=stone, bevel=0.15)
        R.box((4.0, 0.4, 5.0), (x * 1.02, y * 1.02, 2.8), rot, m=dark, bevel=0)
    # Fahnen
    for x in (-16, 16):
        R.cyl(0.2, 10, (x, 30, 25), m=R.mat("#5a3420"))
        R.box((3, 0.1, 4), (x + 1.5, 30, 28), m=R.mat("#e8323c", rough=0.6), bevel=0.05)


def flames(parent, z, r, n=7):
    cols = ["#ffd23a", "#ff9a1a", "#ff4a1a"]
    for i in range(n):
        a = (i - (n - 1) / 2) * 22
        h = r * (1.4 - abs(i - (n - 1) / 2) * 0.18)
        R.cone(0.32 * r, 0.0, h, (math.sin(math.radians(a)) * 0.8 * r, 0.25 * r, z + h * 0.45), (0, a, 0),
               m=R.emit_mat(cols[i % 3], 3.5), parent=parent)


def fire_beast(loc, rot, r):
    b = R.critter(loc, r=r, color="#ff7a2a", mood="angry", ears="bear", rot=rot, m=R.mat("#ff7a2a", rough=0.35, coat=0.5))
    R.ball(0.42 * r, (0, -0.82 * r, -0.32 * r), (1.2, 0.6, 0.8), m=R.mat("#ffd7a8", rough=0.5), parent=b)
    R.ball(0.1 * r, (0, -1.08 * r, -0.2 * r), m=R.mat("#3a1a10"), parent=b)
    flames(b, 0.65 * r, r)
    R.point((0, -1.5 * r, 1.5 * r), 800 * r, "#ff8a2a", r).parent = b
    return b


def ice_beast(loc, rot, r):
    b = R.critter(loc, r=r, color="#3a8cff", mood="angry", ears="horn", rot=rot, m=R.mat("#3a8cff", rough=0.3, coat=0.6))
    R.ball(0.42 * r, (0, -0.82 * r, -0.32 * r), (1.2, 0.6, 0.8), m=R.mat("#cfe9ff", rough=0.5), parent=b)
    ice = R.mat("#bff0ff", rough=0.05, coat=1, emit=0.6)
    for i, a in enumerate((-60, -30, 0, 30, 60)):
        R.cone(0.22 * r, 0.0, 1.0 * r, (math.sin(math.radians(a)) * 0.9 * r, 0.4 * r, math.cos(math.radians(a)) * 0.9 * r),
               (0, a, 0), m=ice, parent=b, verts=6)
    return b


def orb(loc, r):
    root = R.empty(loc, (20, 0, 25))
    R.ball(r, (0, 0, 0), m=R.mat("#9b3bff", rough=0.15, coat=1, emit=0.25), parent=root)
    R.torus(r * 1.0, r * 0.12, (0, 0, 0), (90, 0, 0), m=R.mat("#ffc21a", rough=0.15, metal=1), parent=root)
    R.ball(r * 0.3, (0, -r * 0.98, 0), (1, 0.4, 1), m=R.emit_mat("#ffffff", 4), parent=root)
    R.point(loc, 600, "#c48bff", r)
    return root


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#ffb36b", 1.0, top="#5a3fd6")
    arena()
    R.sun((40, 0, 150), 2.2, "#ffd6a0")
    if kind == "thumb":
        cam = R.camera((0, -21, 2.6), (0, 0, 5.4), lens=30)
        fire_beast((-6.5, 0, 3.2), (0, 0, -30), 3.0)
        ice_beast((6.5, 0, 3.2), (0, 0, 30), 3.0)
        orb((0, -3, 3.4), 1.2)
        for x, z, s in ((-2.5, 9.5, 0.5), (2.8, 8.5, 0.4), (0.5, 3.0, 0.35)):
            R.sparkle((x, -3, z), s, "#ffe6ff")
        R.area((-10, -14, 12), (0, 0, 4), 6000, "#fff1d8", 10)
        R.area((0, 12, 10), (0, 0, 4), 6000, "#ff6ad8", 8)
        R.place_title(cam, "COLOSSEUM", 0.0, 0.8, 6, 0.13, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.place_title(cam, "CATCHER", 0.0, 0.5, 6, 0.1, colors=(("0", "#ffffff"), ("1", "#ffe6e6")), emit=0.4, outline="#7a0d1a")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((0, -13.5, 3.4), (0, 0, 5.6), lens=34)
        fire_beast((0, 0, 3.6), (0, 0, -8), 3.3)
        orb((3.6, -4, 2.4), 1.0)
        R.sparkle((-3.5, -3, 9.5), 0.5, "#ffe6ff")
        R.area((-10, -14, 12), (0, 0, 4), 6000, "#fff1d8", 10)
        R.area((0, 12, 10), (0, 0, 4), 6000, "#ff6ad8", 8)
        R.place_title(cam, "CATCH!", 0.0, -0.7, 6, 0.17, tilt=4, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
