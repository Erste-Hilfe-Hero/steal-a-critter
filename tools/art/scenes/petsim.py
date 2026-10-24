# Critter Hatch Simulator: goldenes Ei platzt auf, legendaerer Critter kommt heraus, Haustiere drumherum.
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def hatch(loc, r):
    x, y, z = loc
    gold = R.mat("#ffcc33", rough=0.22, metal=0.45, coat=0.9, name="eggGold")
    R.egg((x, y, z + r * 1.28), r, m=gold, cut=0.05, spots=R.mat("#fff2a8", rough=0.15, metal=0.6))
    R.egg((x + 1.9 * r, y + 0.2, z + r * 3.0), r, m=gold, rot=(0, 38, 0), cut=0.05, top=True)
    R.point((x, y - 0.3 * r, z + r * 1.5), 2500 * r, "#ffd86b", 0.8 * r)
    # Lichtstrahlen aus dem Ei
    beam = R.emit_mat("#fff1b0", 1.3)
    for i, a in enumerate((-40, -20, 0, 18, 38)):
        b = R.cone(0.04 * r, 0.6 * r, 7 * r, (x, y + 0.3, z + r * 1.4), (0, a, 0), m=beam)
        b.location = (x + 3.5 * r * __import__("math").sin(__import__("math").radians(a)), y + 0.6, z + r * 1.4 + 3.5 * r * __import__("math").cos(__import__("math").radians(a)))
        b.visible_shadow = False
    R.critter((x, y - 0.1, z + r * 1.85), r=0.8 * r, color="#ffd23f", mood="happy", ears="cat", crown=True,
              m=R.mat("#ffd84a", rough=0.25, coat=0.7, emit=0.15))


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#1d1050", 0.5)
    R.ground(m=R.mat("#6b4dd8", rough=0.45, coat=0.3), size=60)
    R.sun((55, 0, 20), 2.5)
    if kind == "thumb":
        cam = R.camera((0, -16.5, 4.6), (0, 0, 4.4), lens=32)
        R.backdrop(cam, 50, [(0.0, "#24105e"), (0.55, "#5a2fd6"), (1.0, "#9d7bff")], rays=16, ray_strength=0.06, center=(0.0, 0.1))
        hatch((0, 0, 0), 2.0)
        pets = [(-6.5, -2.0, "#58c7ff", "bear", 1.25), (-10.0, 0.5, "#7dff8a", "bunny", 1.05), (6.5, -2.0, "#ff6fae", "cat", 1.25),
                (10.0, 0.5, "#c38bff", "horn", 1.05), (-13.0, 3, "#ffb347", "cat", 0.9), (13.0, 3, "#5ef0d2", "bear", 0.9)]
        for x, y, c, e, r in pets:
            R.critter((x, y, r * 0.92), r=r, color=c, ears=e, rot=(0, 0, -x * 2.2))
        for x, y, z in ((-3.5, -5, 0.4), (3.8, -5.5, 0.4), (-4.5, -3, 0.4), (2.6, -7, 0.4), (-2.2, -7.5, 0.4), (4.8, -3.6, 0.4)):
            R.coin((x, y, z), (90, 0, x * 13), 0.5)
        for x, y, z, sc in ((-3.2, -2, 7.5, 0.5), (3.6, -2, 6.6, 0.4), (-5.4, -1, 4.6, 0.35), (5.4, -1, 4.0, 0.3), (0.2, -1, 9.0, 0.45)):
            R.sparkle((x, y, z), sc, "#fff3b0")
        R.area((-10, -14, 12), (0, 0, 3), 6000, "#ffffff", 10)
        R.area((12, 10, 10), (0, 0, 4), 8000, "#ff7ae0", 6)
        R.area((-12, 10, 10), (0, 0, 4), 8000, "#5ad8ff", 6)
        R.place_title(cam, "CRITTER HATCH", 0.0, 0.78, 6, 0.13, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.place_title(cam, "SIMULATOR", 0.0, 0.5, 6, 0.085, colors=(("0", "#ffffff"), ("1", "#dff4ff")), emit=0.4, outline="#2a1270")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((0, -12, 4.6), (0, 0, 4.0), lens=34)
        R.backdrop(cam, 40, [(0.0, "#24105e"), (0.55, "#5a2fd6"), (1.0, "#a98bff")], rays=12, ray_strength=0.07, center=(0.0, 0.15))
        hatch((0, 0, 0), 2.1)
        R.critter((-4.6, -1.5, 1.1), r=1.2, color="#58c7ff", ears="bear", rot=(0, 0, 15))
        R.critter((4.6, -1.5, 1.1), r=1.2, color="#ff6fae", ears="bunny", rot=(0, 0, -15))
        for x, y, z, sc in ((-2.8, -2, 7.5, 0.5), (3.2, -2, 6.6, 0.45), (-3.6, -1, 4.2, 0.3)):
            R.sparkle((x, y, z), sc, "#fff3b0")
        R.area((-10, -14, 12), (0, 0, 3), 6000, "#ffffff", 10)
        R.area((12, 10, 10), (0, 0, 4), 8000, "#ff7ae0", 6)
        R.area((-12, 10, 10), (0, 0, 4), 8000, "#5ad8ff", 6)
        R.place_title(cam, "HATCH!", 0.0, -0.72, 6, 0.17, tilt=4, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
