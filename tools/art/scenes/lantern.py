# Lantern Legends: Ritter mit leuchtendem Schwert und Laterne im Dungeon, Schleim-Monster, Beute in Lichtsaeulen.
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def dungeon():
    random.seed(5)
    floor = [R.mat(c, rough=0.75, coat=0.05) for c in ("#3a3550", "#433d5c", "#36314a")]
    for i in range(-8, 9):
        for j in range(-3, 12):
            R.box((3.9, 3.9, 0.5), (i * 4, j * 4, -0.25 + random.uniform(-0.05, 0.05)), m=random.choice(floor), bevel=0.15)
    wall = [R.mat(c, rough=0.8) for c in ("#2a2640", "#322d4a")]
    for i in range(-9, 10):
        for k in range(6):
            R.box((3.9, 2.5, 1.9), (i * 4 + (2 if k % 2 else 0), 46, 1 + k * 2), m=random.choice(wall), bevel=0.15)
    for x in (-14, 14):
        R.cyl(1.6, 14, (x, 30, 7), m=R.mat("#4a4466", rough=0.7), bevel=0.2, verts=8)
        R.cyl(0.5, 0.6, (x, 28.2, 8), (90, 0, 0), m=R.mat("#2a2018"))
        R.cone(0.5, 0, 1.4, (x, 27.8, 9), m=R.emit_mat("#ff9a2a", 8))
        R.point((x, 27.5, 9.5), 3000, "#ff8a2a", 1)


def lantern(loc, parent=None, s=1.0):
    root = R.empty(loc, parent=parent)
    frame = R.mat("#3a2a1a", rough=0.4, metal=0.6)
    gold = R.mat("#ffc21a", rough=0.2, metal=0.9)
    R.box((1.1 * s, 1.1 * s, 0.2 * s), (0, 0, 0.85 * s), m=frame, parent=root, bevel=0.06)
    R.box((1.1 * s, 1.1 * s, 0.2 * s), (0, 0, -0.85 * s), m=frame, parent=root, bevel=0.06)
    R.cone(0.75 * s, 0.1 * s, 0.6 * s, (0, 0, 1.25 * s), m=gold, parent=root, verts=4).rotation_euler[2] = math.radians(45)
    R.torus(0.25 * s, 0.06 * s, (0, 0, 1.75 * s), (90, 0, 0), m=gold, parent=root)
    R.box((0.85 * s, 0.85 * s, 1.5 * s), (0, 0, 0), m=R.mat("#ffcf6a", rough=0.05, coat=1, emit=3.0), parent=root, bevel=0.05)
    for sx in (-1, 1):
        for sy in (-1, 1):
            R.box((0.12 * s, 0.12 * s, 1.6 * s), (sx * 0.5 * s, sy * 0.5 * s, 0), m=frame, parent=root, bevel=0.02)
    R.point((0, 0, 0), 1500 * s, "#ffb84a", 0.4 * s).parent = root
    return root


def slime(loc, r, color, mood="angry"):
    return R.critter(loc, r=r, m=R.mat(color, rough=0.1, coat=1.0, emit=0.12), mood=mood, ears=None, blush=False)


def knight(loc, rot, scale=1.0):
    pose = {"ra": (172, 0, -12), "la": (-65, 0, 18), "ll": (20, 0, 0), "rl": (-20, 0, 0)}
    p = R.noob(loc, rot, skin="#f2c27a", shirt="#7a8399", pants="#3a3f55", mood="grin", pose=pose, scale=scale)
    steel = R.mat("#c9d2e3", rough=0.18, metal=0.9, coat=0.5)
    R.cyl(0.7, 0.5, (0, 0.04, 1.32), m=steel, parent=p["head"], bevel=0.2)
    R.box((0.2, 0.9, 0.6), (0, 0.1, 1.75), m=R.mat("#e8323c"), parent=p["head"], bevel=0.08)
    R.box((2.2, 1.15, 1.2), (0, 0, 1.6), m=steel, parent=p["torso"], bevel=0.2)
    for sd in ("la", "ra"):
        R.box((1.2, 1.2, 0.8), (0, 0, 0.1), m=steel, parent=p[sd], bevel=0.25)
    R.sword((0, 0, -1.9), (180, 0, 0), 1.0, parent=p["ra"], glow="#7fe8ff")
    lantern((0, -0.3, -2.6), parent=p["la"], s=0.7)
    return p


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#0c0a1a", 0.3)
    dungeon()
    if kind == "thumb":
        cam = R.camera((0, -18, 4.2), (0, 4, 5.0), lens=30)
        knight((-3.5, 0, 0), (0, 0, -20))
        slime((5.5, 3.5, 1.6), 1.8, "#4ad66a")
        slime((10.5, 8, 2.2), 2.4, "#9b5bff")
        slime((-11.5, 7, 1.2), 1.3, "#ff6a4a")
        for x, y, c in ((2.5, 10, "#ffb21a"), (-8, 14, "#b35bff"), (13, 16, "#25b8ff"), (-14, 20, "#ff3b6b")):
            R.light_pillar((x, y, 0), c)
            R.box((1.2, 0.5, 0.8), (x, y, 0.4), m=R.mat(c, rough=0.2, metal=0.6, emit=0.5), bevel=0.15)
        R.area((-10, -14, 12), (0, 0, 3), 4000, "#a8c0ff", 10)
        R.area((8, 10, 10), (0, 0, 4), 6000, "#b35bff", 6)
        R.place_title(cam, "LANTERN", 0.0, 0.8, 6, 0.12, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.place_title(cam, "LEGENDS", 0.0, 0.52, 6, 0.1, colors=(("0", "#ffffff"), ("1", "#dfe8ff")), emit=0.4, outline="#1a1240")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((0, -12.5, 4.0), (0, 2, 5.6), lens=32)
        knight((-0.6, 0, 0), (0, 0, -15))
        slime((4.6, 3.5, 1.5), 1.6, "#9b5bff")
        R.light_pillar((-4.6, 6, 0), "#ffb21a")
        R.area((-10, -14, 12), (0, 0, 3), 4000, "#a8c0ff", 10)
        R.area((8, 10, 10), (0, 0, 4), 6000, "#b35bff", 6)
        R.place_title(cam, "LOOT!", 0.0, -0.7, 6, 0.17, tilt=4, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
