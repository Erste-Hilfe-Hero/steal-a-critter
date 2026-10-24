# Steal a Critter: Dieb rennt mit einem leuchtenden Regenbogen-Critter davon, Besitzer jagt hinterher.
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def stage():
    R.ground(m=R.mat("#3a2c5c", rough=0.55, coat=0.2), size=46)
    # Basis-Platten des Spielers (Plot) mit Laserschranke
    for i in range(-3, 4):
        for j in range(0, 6):
            c = "#5a4890" if (i + j) % 2 else "#4c3c7c"
            R.box((3.9, 3.9, 0.3), (i * 4, j * 4 + 2, 0.15), m=R.mat(c, rough=0.5), bevel=0.08)
    # Sockel mit Crittern im Hintergrund (die Basis, die man ausraubt)
    cols = ["#58c7ff", "#7dff8a", "#ffb347", "#c38bff", "#ff6fae", "#5ef0d2"]
    ears = ["bear", "cat", "bunny", "cat", "bear", "horn"]
    for i, x in enumerate((-13, -8, -3, 6, 11, 16)):
        R.cyl(1.3, 1.0, (x, 13, 0.5), m=R.mat("#2b2140", rough=0.4), bevel=0.1)
        R.cyl(1.35, 0.12, (x, 13, 1.02), m=R.emit_mat(cols[i], 3))
        R.critter((x, 13, 2.2), r=0.95, color=cols[i], ears=ears[i], rot=(0, 0, (i - 2.5) * 8))


def thief(loc, rot, carry=True):
    pose = {"la": (170, 0, 18), "ra": (170, 0, -18), "ll": (35, 0, 0), "rl": (-40, 0, 0), "torso": (-8, 0, 0)}
    p = R.noob(loc, rot, skin="#f2c27a", shirt="#e8323c", pants="#1e1b2e", mood="grin", pose=pose, mask="#1a1626")
    return p


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#2a0d3a", 0.6)
    stage()

    if kind == "thumb":
        cam = R.camera((2.5, -17, 3.2), (1.5, 0, 4.9), lens=30)
        R.backdrop(cam, 60, [(0.0, "#3a0a4a"), (0.45, "#b0154f"), (1.0, "#ff5a3c")], rays=14, ray_strength=0.07,
                   center=(0.35, 0.15))
        thief((4.2, 0, 0), (0, 0, -28))
        R.critter((4.0, -0.6, 7.5), r=2.0, m=R.rainbow_mat(scale=2.6), mood="happy", ears="cat", rot=(28, 0, -18))
        R.point((4.0, -5.5, 6.5), 500, "#ffffff", 1.5)
        owner = R.noob((-4.2, 4, 0), (0, 0, -35), shirt="#2f7cf6", pants="#23314f", mood="angry",
                       pose={"ra": (110, 0, -10), "la": (-30, 0, 0), "ll": (-30, 0, 0), "rl": (30, 0, 0), "torso": (-10, 0, 0)},
                       hair="#3b2416", scale=0.95)
        R.critter((-0.8, 6, 1.0), r=1.0, color="#ff6fae", mood="angry", ears="bear")
        R.critter((9.8, 5, 1.1), r=1.1, color="#ffd23f", mood="happy", ears="bunny", rot=(0, 0, 20))
        bills = [(0.2, -4, 7.5, 20, 30, 10), (8.2, -3, 8.5, -30, 60, 40), (9.0, -5, 4.5, 50, -20, 0), (-6.5, -6, 6.5, 10, 80, -30),
                 (6.4, -8, 9.0, 60, 10, 60), (11.5, 0, 7.0, -10, -40, 20), (12.0, 2, 2.5, 30, 50, 80), (2.5, -10, 0.8, 0, 30, -10)]
        for x, y, z, a, b, c in bills:
            R.cash((x, y, z), (a, b, c), 0.9)
        for x, y, z in ((6.8, -6, 1.5), (8.5, -2, 1.0), (-1.5, -5, 0.8), (10.5, -4, 3.0)):
            R.coin((x, y, z), (70, 0, 30), 0.55)
        for x, y, z, s in ((1.3, -2, 9.8, 0.6), (6.8, -2, 9.4, 0.45), (6.6, -1, 6.4, 0.35), (2.0, -3, 6.5, 0.3)):
            R.sparkle((x, y, z), s)
        R.sun((55, 0, 25), 3.2)
        R.area((-10, -14, 14), (2, 0, 5), 9000, "#ffd9b0", 10)
        R.area((14, 12, 10), (3, 0, 6), 12000, "#ff4fd8", 6)   # pinkes Kantenlicht
        R.area((-12, 10, 8), (-4, 4, 4), 8000, "#3ad7ff", 6)  # cyanes Kantenlicht
        R.place_title(cam, "STEAL A", -0.5, 0.76, 6, 0.09, tilt=6, colors=(("0", "#ffffff"), ("1", "#ffffff")), emit=0.4)
        R.place_title(cam, "CRITTER!", -0.47, 0.52, 6, 0.17, tilt=6, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((1.6, -12.5, 6.0), (0.6, 0, 5.6), lens=38)
        R.backdrop(cam, 40, [(0.0, "#3a0a4a"), (0.5, "#c0164f"), (1.0, "#ff7a3c")], rays=12, ray_strength=0.08, center=(0.0, 0.25))
        thief((0.8, 0, 0), (0, 0, -18))
        R.critter((0.8, -0.6, 7.9), r=2.3, m=R.rainbow_mat(scale=2.6), mood="happy", ears="cat", rot=(18, 0, -10))
        R.point((0.8, -5.5, 6.5), 500, "#ffffff", 1.5)
        for x, y, z, a, b, c in ((-3.8, -3, 8.5, 20, 30, 10), (4.6, -3, 9.5, -30, 60, 40), (-3.6, -4, 4.0, 50, -20, 0), (4.6, -5, 4.5, 10, 80, -30)):
            R.cash((x, y, z), (a, b, c), 0.8)
        R.sparkle((-1.8, -3, 10.2), 0.6)
        R.sparkle((3.6, -3, 6.8), 0.45)
        R.sun((55, 0, 25), 3.2)
        R.area((-10, -14, 14), (0, 0, 8), 9000, "#ffd9b0", 10)
        R.area((12, 10, 12), (0, 0, 9), 12000, "#ff4fd8", 6)
        R.area((-12, 10, 10), (0, 0, 9), 8000, "#3ad7ff", 6)
        R.place_title(cam, "STEAL!", 0.0, -0.72, 7, 0.2, tilt=5, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
