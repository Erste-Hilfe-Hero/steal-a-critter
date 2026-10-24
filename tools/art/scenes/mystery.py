# Midnight Mystery: Flur einer Villa um Mitternacht. Vorne ein erschrockener Unschuldiger mit Taschenlampe,
# dahinter der maskierte Murderer mit leuchtendem Messer, hinten der Sheriff mit goldenem Blaster, grosser Mond im Fenster.
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def hallway():
    random.seed(7)
    planks = [R.mat(c, rough=0.55, coat=0.35) for c in ("#5a3a26", "#6a442c", "#4e3222")]
    for i in range(-10, 11):
        for j in range(-4, 14):
            R.box((1.9, 3.9, 0.4), (i * 2, j * 4 + (1.5 if i % 2 else 0), -0.2), m=random.choice(planks), bevel=0.06)
    # Teppichlaeufer
    R.box((6, 60, 0.06), (0, 20, 0.03), m=R.mat("#7a1f3a", rough=0.8, coat=0), bevel=0)
    R.box((5, 60, 0.07), (0, 20, 0.04), m=R.mat("#9a2a4c", rough=0.8, coat=0), bevel=0)
    # Rueckwand mit Fenster
    wall = R.mat("#2c2650", rough=0.7)
    R.box((44, 1, 9), (0, 30, 4.5), m=wall, bevel=0.1)
    R.box((44, 1, 6), (0, 30, 18), m=wall, bevel=0.1)
    R.box((15, 1, 6), (-14.5, 30, 12), m=wall, bevel=0.1)
    R.box((15, 1, 6), (14.5, 30, 12), m=wall, bevel=0.1)
    frame = R.mat("#4a3020", rough=0.5)
    for x in (-7, 0, 7):
        R.box((0.5, 1.2, 6.4), (x, 29.8, 12), m=frame, bevel=0.08)
    for z in (9, 15):
        R.box((14.5, 1.2, 0.5), (0, 29.8, z), m=frame, bevel=0.08)
    # Nachthimmel und Mond hinter dem Fenster
    R.box((40, 0.5, 20), (0, 46, 12), m=R.emit_mat("#1a1650", 1.2), bevel=0)
    R.ball(5.5, (2.5, 44, 13.5), m=R.emit_mat("#ffe08a", 7))
    R.ball(5.0, (5.2, 43, 15.2), m=R.mat("#1a1650", rough=1, coat=0))
    for _ in range(40):
        R.ball(random.uniform(0.05, 0.14), (random.uniform(-14, 14), 45.5, random.uniform(9.5, 18)), m=R.emit_mat("#ffffff", 8))
    R.area((2, 36, 14), (0, 0, 2), 9000, "#8fa8ff", 14)
    # Seitenwaende mit Bildern und Kerzenleuchtern
    for sx in (-1, 1):
        R.box((1, 60, 22), (sx * 20, 20, 11), m=R.mat("#3a2c5c", rough=0.7), bevel=0.1)
        R.box((1.2, 60, 1.2), (sx * 19.6, 20, 2), m=frame, bevel=0.08)
        for y in (6, 18):
            R.box((0.3, 5, 6), (sx * 19.3, y, 9), m=R.mat("#c9a040", rough=0.3, metal=0.8), bevel=0.15)
            R.box((0.32, 4, 5), (sx * 19.2, y, 9), m=R.mat(random.choice(("#3a5c7a", "#7a3a4a", "#4a6a3a")), rough=0.6), bevel=0.05)
        for y in (0, 12, 24):
            R.cyl(0.25, 1.4, (sx * 19, y, 13), m=R.mat("#f2ead8"))
            R.ball(0.25, (sx * 19, y, 13.9), (1, 1, 1.6), m=R.emit_mat("#ffb24a", 12))
            R.point((sx * 18.4, y, 14), 400, "#ffa040", 0.3)


def knife(loc, rot, parent=None, s=1.0, glow="#ff3b5c"):
    root = R.empty(loc, rot, parent=parent)
    R.box((0.12 * s, 0.55 * s, 2.3 * s), (0, 0, 1.6 * s), m=R.emit_mat(glow, 3.5), parent=root, bevel=0.04 * s)
    tip = R.cone(0.4 * s, 0.0, 0.7 * s, (0, 0, 3.1 * s), m=R.emit_mat(glow, 3.5), parent=root, verts=4)
    tip.scale = (0.2, 1, 1)
    R.box((0.3 * s, 1.0 * s, 0.2 * s), (0, 0, 0.4 * s), m=R.mat("#ffd666", rough=0.2, metal=0.9), parent=root, bevel=0.05 * s)
    R.cyl(0.16 * s, 0.9 * s, (0, 0, -0.15 * s), m=R.mat("#1a1420", rough=0.5), parent=root)
    R.point((0, -0.3, 1.8 * s), 120 * s, glow, 0.2).parent = root
    return root


def blaster(loc, rot, parent=None, s=1.0):
    root = R.empty(loc, rot, parent=parent)
    gold = R.mat("#ffc83a", rough=0.18, metal=0.9, coat=0.6)
    R.box((0.5 * s, 1.6 * s, 0.6 * s), (0, -0.6 * s, 0.3 * s), m=gold, parent=root, bevel=0.1 * s)
    R.cyl(0.18 * s, 1.4 * s, (0, -1.9 * s, 0.4 * s), (90, 0, 0), m=gold, parent=root)
    R.box((0.4 * s, 0.5 * s, 1.0 * s), (0, 0, -0.3 * s), m=R.mat("#4a2a18", rough=0.5), parent=root, bevel=0.08 * s)
    for i in range(3):
        R.torus(0.26 * s, 0.05 * s, (0, -1.2 * s - i * 0.35 * s, 0.4 * s), (90, 0, 0), m=R.emit_mat("#7fe8ff", 4), parent=root)
    return root


def flashlight_beam(start, direction, length=14):
    beam = R.cone(0.3, 3.2, length, m=R.emit_mat("#fff2c0", 0.25))
    d = R.Vector(direction).normalized()
    beam.rotation_euler = (-d).to_track_quat("Z", "Y").to_euler()
    beam.location = R.Vector(start) + d * length / 2
    beam.visible_shadow = False
    return beam


def murderer(loc, rot, scale=1.0):
    pose = {"ra": (150, 0, -25), "la": (40, 0, 20), "ll": (25, 0, 0), "rl": (-20, 0, 0), "torso": (12, 0, 0)}
    p = R.noob(loc, rot, skin="#2a2238", shirt="#1c1828", pants="#14121c", mood="angry", pose=pose, scale=scale)
    # Kapuze und leuchtende Augen
    hood = R.mat("#1c1828", rough=0.6)
    R.box((1.5, 1.5, 1.5), (0, 0.12, 0.85), m=hood, parent=p["head"], bevel=0.35)
    R.box((1.0, 0.3, 0.75), (0, -0.62, 0.75), m=R.mat("#06050a", rough=0.9), parent=p["head"], bevel=0.1)
    for sx in (-1, 1):
        R.ball(0.1, (sx * 0.22, -0.78, 0.82), (1.4, 0.5, 0.8), m=R.emit_mat("#ff3b5c", 10), parent=p["head"])
    knife((0, -0.2, -1.8), (180, 0, 0), parent=p["ra"], s=1.0)
    return p


def innocent(loc, rot, scale=1.0):
    pose = {"ra": (85, 0, -10), "la": (150, 0, 25), "ll": (-25, 0, 0), "rl": (35, 0, 0), "torso": (-6, 0, 0)}
    p = R.noob(loc, rot, skin="#f5c56b", shirt="#3fa8ff", pants="#2b2f45", mood="shock", pose=pose, scale=scale, hair="#5a3420")
    # Taschenlampe in der rechten Hand
    R.cyl(0.22, 1.1, (0, -0.4, -1.75), (90, 0, 0), m=R.mat("#d8dce8", metal=0.8, rough=0.2), parent=p["ra"])
    R.cyl(0.26, 0.1, (0, -0.98, -1.75), (90, 0, 0), m=R.emit_mat("#fff2c0", 20), parent=p["ra"])
    return p


def sheriff(loc, rot, scale=1.0):
    pose = {"ra": (95, 0, 8), "la": (80, 0, -25), "ll": (10, 0, 0), "rl": (-10, 0, 0)}
    p = R.noob(loc, rot, skin="#e8b07a", shirt="#2f5bd6", pants="#1f2a4a", mood="cool", pose=pose, scale=scale)
    hat = R.mat("#6a4422", rough=0.5)
    R.cyl(1.1, 0.12, (0, 0, 1.3), m=hat, parent=p["head"])
    R.cyl(0.62, 0.6, (0, 0, 1.62), m=hat, parent=p["head"], bevel=0.15)
    R.box((0.5, 0.1, 0.5), (0.5, -0.55, 1.5), (0, 0, 45), m=R.mat("#ffd666", metal=0.9, rough=0.2), parent=p["torso"], bevel=0.05)
    blaster((0, -0.3, -2.0), (0, 0, 0), parent=p["ra"], s=1.0)
    return p


def coins(n, area, z=0.25):
    for _ in range(n):
        x = random.uniform(*area[0])
        y = random.uniform(*area[1])
        R.coin((x, y, z), (random.uniform(-30, 30), random.uniform(60, 90), random.uniform(0, 180)), r=0.45)


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#0a0820", 0.35)
    hallway()
    random.seed(3)
    if kind == "thumb":
        cam = R.camera((0, -17, 5.2), (0, 6, 5.6), lens=30)
        innocent((-5.2, -1.5, 0), (0, 0, 18))
        R.point((-4.6, -3.6, 4.2), 600, "#fff2c0", 0.4)
        murderer((3.4, 3.5, 0), (0, 0, -28), 1.1)
        sheriff((-10, 13, 0), (0, 0, 25), 0.95)
        coins(9, ((-8, 8), (-4, 10)))
        R.area((-12, -14, 14), (0, 0, 4), 3500, "#a8b8ff", 10)
        R.area((10, -6, 10), (3, 3, 5), 2500, "#ff4a7a", 6)
        R.point((3.4, 1.0, 6), 900, "#ff3b5c", 0.5)
        R.place_title(cam, "MIDNIGHT", 0.0, 0.78, 6, 0.13, colors=(("0.05", "#ffb23a"), ("0.6", "#ffd666"), ("1", "#fff6c0")), outline="#120c30")
        R.place_title(cam, "MYSTERY", 0.0, 0.5, 6, 0.1, tilt=-3, colors=(("0", "#ff5caa"), ("1", "#ffb0e0")), emit=0.4, outline="#120c30")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((0, -9.5, 5.4), (0, 2, 6.0), lens=34)
        murderer((0.4, 1.5, 0), (0, 0, -12), 1.15)
        R.area((-10, -12, 12), (0, 0, 4), 3500, "#a8b8ff", 10)
        R.area((10, -6, 10), (0, 2, 5), 3000, "#ff4a7a", 6)
        R.point((0.5, -1.0, 6.5), 1000, "#ff3b5c", 0.5)
        R.place_title(cam, "?", -0.6, 0.5, 6, 0.3, tilt=10, colors=(("0", "#ffb23a"), ("1", "#fff6c0")), outline="#120c30")
        R.place_title(cam, "WHO?", 0.0, -0.72, 6, 0.16, tilt=3, colors=(("0", "#ff5caa"), ("1", "#ffb0e0")), outline="#120c30")
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
