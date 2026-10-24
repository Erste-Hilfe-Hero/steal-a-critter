# Soccer Jam: Stuermer schiesst einen brennenden Ball aufs Tor, Torwart fliegt, Flutlicht-Stadion.
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def soccer_ball(loc, r):
    root = R.empty(loc, (20, 10, 30))
    R.ball(r, (0, 0, 0), m=R.mat("#ffffff", rough=0.35, coat=0.6), parent=root)
    k = R.mat("#14141c", rough=0.35, coat=0.6)
    phi = (1 + 5 ** 0.5) / 2
    for v in ((0, 1, phi), (0, -1, phi), (0, 1, -phi), (0, -1, -phi), (1, phi, 0), (-1, phi, 0), (1, -phi, 0), (-1, -phi, 0),
              (phi, 0, 1), (-phi, 0, 1), (phi, 0, -1), (-phi, 0, -1)):
        n = math.sqrt(sum(c * c for c in v))
        d = [c / n for c in v]
        p = R.ball(r * 0.33, tuple(c * r * 0.93 for c in d), (1, 1, 0.3), m=k, parent=root, seg=5 * 2)
        p.rotation_euler = R.Vector(d).to_track_quat("Z", "Y").to_euler()
    return root


def fire_trail(start, end, r):
    a, b = R.Vector(start), R.Vector(end)
    d = b - a
    flame = R.gradient_mat([(0.0, "#ff2a1a"), (0.45, "#ff7a1a"), (0.8, "#ffc23a"), (1.0, "#fff3a0")], axis="Z", emit=3.0)
    for k, (rr, off) in enumerate(((1.0, 0.0), (0.7, 0.25), (0.55, -0.3))):
        c = R.cone(0.02, r * rr, d.length * (1 - 0.18 * k), m=flame)
        c.rotation_euler = (-d).to_track_quat("Z", "Y").to_euler()
        c.location = a + d * (0.5 - 0.09 * k) + R.Vector((0, 0, off))
        c.visible_shadow = False
    for i in range(8):
        t = 0.25 + i * 0.1
        p = a + d * t + R.Vector((random.uniform(-0.6, 0.6), random.uniform(-0.6, 0.6), random.uniform(-1.0, 1.0)))
        R.ball(0.12 + random.uniform(0, 0.1), tuple(p), m=R.emit_mat("#ffb02e", 6))
    R.point(start, 3000, "#ff8a2a", 1.0)


def stadium():
    grass = R.mat("#1f8a2c", rough=0.75, coat=0)
    R.ground(m=grass, size=120)
    for i in range(-10, 11):
        R.box((5.0, 120, 0.02), (i * 10, 0, 0.01), m=R.mat("#2aa53a", rough=0.75, coat=0), bevel=0)
    line = R.emit_mat("#ffffff", 0.8)
    R.box((0.25, 60, 0.03), (-2, 0, 0.03), m=line, bevel=0)
    # Tribuenen mit Zuschauern
    random.seed(4)
    crowd = [R.mat(c, rough=0.6, emit=0.4) for c in ("#ff3b6b", "#25b8ff", "#ffd21f", "#ff8a1f", "#ffffff", "#7dff6a")]
    for tier in range(5):
        y = 34 + tier * 2.5
        z = 1.2 + tier * 1.6
        R.box((140, 2.5, 1.6), (0, y, z - 0.8), m=R.mat("#1c2140", rough=0.6), bevel=0.05)
        for x in range(-40, 41, 2):
            if random.random() < 0.85:
                R.box((1.0, 0.8, 1.2), (x + random.uniform(-0.3, 0.3), y, z + 0.6), m=random.choice(crowd), bevel=0.15)
    # Flutlichter
    for x in (-28, 30):
        R.cyl(0.5, 26, (x, 46, 13), m=R.mat("#3a3f5a"))
        R.box((7, 1, 4), (x, 45.5, 26), m=R.emit_mat("#ffffff", 30), bevel=0.2)
        R.area((x, 40, 26), (0, 0, 0), 9000, "#eaf4ff", 6)


def goal(x, y):
    post = R.mat("#ffffff", rough=0.3, coat=0.6)
    R.cyl(0.25, 6, (x, y - 6, 3), m=post)
    R.cyl(0.25, 6, (x, y + 6, 3), m=post)
    R.cyl(0.25, 12.5, (x, y, 6), (90, 0, 0), m=post)
    net = R.mat("#e8eef8", rough=0.5, emit=0.2)
    for k in range(-12, 13):
        R.cyl(0.03, 6.3, (x + 3, y + k * 0.5, 3), (0, -26, 0), m=net)
    for k in range(13):
        R.cyl(0.03, 12, (x + 0.2 + k * 0.23, y, 0.3 + k * 0.46), (90, 0, 0), m=net)


def striker(loc, rot, scale=1.0):
    pose = {"rl": (-75, 0, 0), "ll": (25, 0, 0), "la": (-50, 0, 40), "ra": (40, 0, -45), "torso": (12, 0, 0)}
    return R.noob(loc, rot, shirt="#2f7cff", pants="#ffffff", mood="grin", pose=pose, hair="#2a1a10", scale=scale)


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#0a1030", 0.4, top="#1a2a6a")
    stadium()
    R.sun((50, 0, -30), 1.6, "#cfe0ff")
    if kind == "thumb":
        cam = R.camera((0, -22, 4.0), (2.5, 0, 3.6), lens=30)
        goal(15, 4)
        striker((-5.0, -1.0, 0.0), (0, 0, 55))
        soccer_ball((4.2, -3.2, 3.4), 1.15)
        fire_trail((3.4, -2.9, 3.3), (-3.0, -0.8, 1.0), 1.05)
        R.noob((16.0, 3.0, 2.6), (0, -72, 0), shirt="#eb3737", pants="#1e1b2e", mood="shock",
               pose={"la": (0, 0, -150), "ra": (0, 0, 150)}, scale=0.95)
        R.area((-10, -14, 12), (0, 0, 3), 6000, "#ffffff", 10)
        R.area((10, -8, 6), (0, 0, 3), 5000, "#5ad8ff", 6)
        R.place_title(cam, "SOCCER", -0.46, 0.74, 6, 0.13, tilt=8, italic_shear=0.18, colors=(("0", "#ffffff"), ("1", "#e6f0ff")),
                      outline="#0a1640", emit=0.35)
        R.place_title(cam, "JAM!", -0.44, 0.38, 6, 0.22, tilt=8, italic_shear=0.18, colors=(("0.05", "#ff4a1a"), ("0.6", "#ff9a1a"), ("1", "#ffe08a")),
                      outline="#1a0802")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((-1.2, -15, 4.4), (-0.5, 0, 4.4), lens=32)
        goal(15, 4)
        striker((-4.0, -0.5, 0.0), (0, 0, 55))
        soccer_ball((2.6, -2.6, 5.0), 1.5)
        fire_trail((1.6, -2.3, 4.8), (-4.0, -0.5, 2.0), 1.35)
        R.area((-10, -14, 12), (0, 0, 3), 6000, "#ffffff", 10)
        R.place_title(cam, "SOCCER", 0.0, -0.68, 6, 0.16, tilt=6, italic_shear=0.18, colors=(("0.05", "#ff4a1a"), ("0.6", "#ff9a1a"), ("1", "#ffe08a")),
                      outline="#1a0802")
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
