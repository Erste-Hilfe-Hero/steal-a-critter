# Lanebreakers: Gold-Held gegen Lila-Magierin vor dem Kristall-Kern auf der schwebenden Insel.
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv
GOLD = "#ffb21a"
VIO = "#9b5bff"


def tower(loc, color):
    x, y, z = loc
    stone = R.mat("#9aa3b8", rough=0.6)
    R.cyl(1.4, 8, (x, y, z + 4), m=stone, bevel=0.2, verts=8)
    R.cyl(1.9, 0.8, (x, y, z + 8.2), m=R.mat(color, rough=0.3, metal=0.5), bevel=0.15, verts=8)
    R.crystal((x, y, z + 10.2), 1.0, color)
    R.point((x, y - 1.5, z + 10), 1500, color, 0.8)


def island():
    R.cyl(40, 6, (0, 15, -3), m=R.mat("#5fcf55", rough=0.8), verts=64)
    R.cone(40, 6, 22, (0, 15, -17), (180, 0, 0), m=R.mat("#7a5a3a", rough=0.9), verts=64)
    R.box((7, 70, 0.1), (0, 15, 0.02), m=R.mat("#b89a6a", rough=0.9, coat=0), bevel=0)
    R.box((80, 5, 0.1), (0, 12, 0.03), m=R.mat("#4ab8ff", rough=0.05, coat=1, emit=0.2), bevel=0)
    tower((-9, 4, 0), GOLD)
    tower((9, 24, 0), VIO)
    R.crystal((0, 34, 6.0), 3.0, VIO, emit=1.5)
    R.point((0, 31, 6), 6000, VIO, 2)
    for x, y in ((-20, 26), (18, 6), (-26, 8), (24, 30)):
        R.cyl(0.6, 4, (x, y, 2), m=R.mat("#8a5a34"))
        R.ball(2.6, (x, y, 5.4), m=R.mat("#2fa84a", rough=0.6))
    for x, y, z, s in ((-50, 80, 10, 5), (40, 90, 18, 6), (70, 60, -5, 5), (-75, 50, -8, 6)):
        R.cloud((x, y, z), s)


def hero(loc, rot):
    pose = {"ra": (172, 0, -12), "la": (-30, 0, 30), "ll": (25, 0, 0), "rl": (-25, 0, 0), "torso": (-5, 0, 0)}
    p = R.noob(loc, rot, shirt=GOLD, pants="#5a3a1a", mood="grin", pose=pose, hair="#ffe08a")
    gold = R.mat("#ffcf33", rough=0.2, metal=0.9)
    R.box((2.3, 1.2, 1.0), (0, 0, 1.65), m=gold, parent=p["torso"], bevel=0.25)
    R.box((2.0, 0.2, 2.6), (0, 0.65, 0.6), (8, 0, 0), m=R.mat("#e8323c", rough=0.6), parent=p["torso"], bevel=0.08)
    R.sword((0, 0, -1.9), (180, 0, 0), 1.3, parent=p["ra"], glow="#ffe066")
    return p


def mage(loc, rot):
    pose = {"la": (-110, 0, 20), "ra": (-60, 0, -25), "ll": (10, 0, 0), "rl": (-10, 0, 0)}
    p = R.noob(loc, rot, skin="#f5d0b0", shirt=VIO, pants="#3a1f6b", mood="angry", pose=pose)
    hat = R.mat("#4a2a8a", rough=0.5)
    R.cyl(1.3, 0.15, (0, 0, 1.25), m=hat, parent=p["head"])
    R.cone(0.8, 0.05, 2.2, (0.2, 0.2, 2.3), (12, 10, 0), m=hat, parent=p["head"])
    R.cyl(0.12, 4.5, (0, -0.2, -1.6), (90, 0, 0), m=R.mat("#5a3420"), parent=p["la"]).location = (0, -1.6, -1.9)
    R.ball(0.45, (0, -3.8, -1.9), m=R.emit_mat("#c070ff", 3), parent=p["la"])
    R.point((0, -4.2, -1.9), 600, "#c070ff", 0.5).parent = p["la"]
    return p


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#ffd6a0", 1.0, top="#5a3fd6")
    island()
    R.sun((50, 0, 30), 2.4, "#fff0d0")
    if kind == "thumb":
        cam = R.camera((0, -16, 3.4), (0, 4, 5.6), lens=30)
        hero((-5.0, 0, 0), (0, 0, -30))
        mage((5.0, 1, 0), (0, 0, 30))
        R.area((-10, -14, 12), (0, 0, 3), 3000, "#ffffff", 10)
        R.area((-12, 8, 8), (-5, 0, 4), 3000, GOLD, 6)
        R.area((12, 8, 8), (5, 0, 4), 4000, VIO, 6)
        R.place_title(cam, "LANEBREAKERS", 0.0, 0.8, 6, 0.12, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.place_title(cam, "HERO ARENA 5v5", 0.0, 0.54, 6, 0.065, colors=(("0", "#ffffff"), ("1", "#efe6ff")), emit=0.4, outline="#2a1270")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((0, -12.5, 3.6), (0, 2, 6.0), lens=32)
        hero((-0.6, 0, 0), (0, 0, -20))
        R.area((-10, -14, 12), (0, 0, 3), 3000, "#ffffff", 10)
        R.area((12, 8, 8), (0, 0, 4), 4000, VIO, 6)
        R.place_title(cam, "5v5", 0.0, -0.7, 6, 0.17, tilt=4, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
