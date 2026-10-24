# Soccer Jam: Logo = Fussball vor gekreuzten CS-Messern; Vorschaubild = Messerangriff auf den Ballfuehrer
# in der dreckigen soccerjam-Arena.
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


def knife(loc, rot, s=1.0, golden=False):
    """CS-Messer entlang +Z (Griff unten bei 0): schwarzer Gummigriff, Parierstange, Klinge mit Spitze."""
    root = R.empty(loc, rot)
    bm = R.mat("#ffc21a", rough=0.15, metal=0.95, coat=0.6) if golden else R.mat("#d8dee8", rough=0.12, metal=0.95, coat=0.7)
    R.box((0.62 * s, 0.1 * s, 3.0 * s), (0, 0, 2.15 * s), m=bm, parent=root, bevel=0.035 * s)
    tip = R.cone(0.44 * s, 0.0, 0.9 * s, (0.0, 0, 4.1 * s), m=bm, parent=root, verts=4)
    tip.rotation_euler = (0, 0, math.radians(45))
    tip.scale = (1, 0.16, 1)
    # Blutrinne
    R.box((0.08 * s, 0.12 * s, 2.2 * s), (-0.12 * s, 0, 2.0 * s), m=R.mat("#8a929e", rough=0.2, metal=0.9), parent=root, bevel=0.02 * s)
    R.box((1.15 * s, 0.32 * s, 0.22 * s), (0, 0, 0.6 * s), m=R.mat("#2a2c30", rough=0.4, metal=0.7), parent=root, bevel=0.06 * s)
    grip = R.mat("#141416", rough=0.8)
    R.box((0.5 * s, 0.38 * s, 1.5 * s), (0, 0, -0.25 * s), m=grip, parent=root, bevel=0.15 * s)
    for i in range(4):
        R.box((0.56 * s, 0.42 * s, 0.08 * s), (0, 0, (-0.8 + i * 0.35) * s), m=R.mat("#24262a", rough=0.7), parent=root, bevel=0.03 * s)
    R.box((0.58 * s, 0.44 * s, 0.2 * s), (0, 0, -1.05 * s), m=R.mat("#2a2c30", rough=0.4, metal=0.7), parent=root, bevel=0.06 * s)
    return root


def dirty_arena():
    """Dreckige soccerjam-Map: abgenutzter Rasen mit Erde, Betonmauer mit Graffiti-Flecken, Natriumlicht."""
    random.seed(7)
    R.ground(m=R.mat("#4f6b2e", rough=0.9, coat=0), size=140)
    for i in range(-10, 11):
        R.box((5.0, 140, 0.02), (i * 10, 0, 0.01), m=R.mat("#587636", rough=0.9, coat=0), bevel=0)
    dirts = [R.mat(c, rough=1.0, coat=0) for c in ("#6a5a36", "#5f5634", "#72603a")]
    for _ in range(22):
        R.cyl(random.uniform(0.8, 2.4), 0.01, (random.uniform(-25, 25), random.uniform(-4, 30), 0.022 + random.random() * 0.004),
              m=random.choice(dirts), scale=(1, random.uniform(0.4, 0.9), 1), verts=9)
    R.box((0.25, 80, 0.04), (-2, 0, 0.04), m=R.mat("#cfcab4", rough=0.8, coat=0), bevel=0)
    concrete = [R.mat(c, rough=0.95, coat=0) for c in ("#7d786c", "#736e62", "#86806f")]
    for i in range(-8, 9):
        R.box((6.0, 1.5, 10), (i * 6.05, 34, 5), m=random.choice(concrete), bevel=0.04)
        R.box((6.0, 0.1, random.uniform(1.0, 2.2)), (i * 6.05, 33.2, 0.8), m=R.mat("#3e3a32", rough=1, coat=0), bevel=0)
        if random.random() < 0.6:
            R.box((random.uniform(0.3, 1.2), 0.1, random.uniform(2, 6)), (i * 6.05 + random.uniform(-2, 2), 33.2, 7), m=R.mat("#6b3d22", rough=1, coat=0), bevel=0)
    for x, c in ((-14, "#e0463a"), (6, "#3a8ce0"), (20, "#e8d04a")):
        R.box((5, 0.1, 1.6), (x, 33.15, 4.5), (0, random.uniform(-8, 8), 0), m=R.mat(c, rough=0.9, emit=0.15, coat=0), bevel=0)
    R.cyl(0.6, 100, (0, 33.0, 9.0), (0, 90, 0), m=R.mat("#7a4626", rough=0.6, metal=0.6))
    crate = R.mat("#9a7442", rough=0.85, coat=0)
    for x, z, sz in ((-22, 0, 4), (-22, 4, 3), (-17.5, 0, 3.2), (24, 0, 4.2)):
        R.box((sz, sz, sz), (x, 30, z + sz / 2), (0, 0, random.uniform(-10, 10)), m=crate, bevel=0.08)
    for x in (-30, 32):
        R.cyl(0.5, 26, (x, 40, 13), m=R.mat("#6b4126", rough=0.6, metal=0.5))
        R.box((7, 1, 4), (x, 39.5, 26), m=R.emit_mat("#ffc06a", 30), bevel=0.2)
        R.area((x, 34, 26), (0, 0, 0), 9000, "#ffcf8a", 6)


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#1a1612", 0.35, top="#3a2c22")
    R.sun((50, 0, -30), 1.4, "#ffe2b8")
    if kind == "thumb":
        dirty_arena()
        cam = R.camera((0, -22, 4.0), (2.5, 0, 3.6), lens=30)
        # Blauer Spieler mit Messer greift den roten Ballfuehrer von hinten an
        R.noob((8.0, 2.0, 0.0), (0, 0, 120), shirt="#eb3737", pants="#1e1b2e", mood="shock",
               pose={"rl": (-40, 0, 0), "ll": (30, 0, 0), "la": (-40, 0, 20), "ra": (40, 0, -20)})
        soccer_ball((5.6, -0.6, 0.75), 0.75)
        striker((-0.8, -2.0, 0.0), (0, 0, 70))
        knife((1.0, -4.2, 3.3), (0, 62, -15), s=0.85)
        R.area((-10, -14, 12), (0, 0, 3), 6000, "#fff0d8", 10)
        R.area((10, -8, 6), (0, 0, 3), 3000, "#ff9a4a", 6)
        R.place_title(cam, "SOCCER", -0.46, 0.74, 6, 0.13, tilt=8, italic_shear=0.18, colors=(("0", "#ffffff"), ("1", "#d8dce6")),
                      outline="#141414", emit=0.3)
        R.place_title(cam, "JAM!", -0.44, 0.38, 6, 0.22, tilt=8, italic_shear=0.18, colors=(("0.05", "#ff4a1a"), ("0.6", "#ff9a1a"), ("1", "#ffe08a")),
                      outline="#1a0802")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        # Logo: Fussball vor zwei gekreuzten CS-Messern, darunter SOCCER JAM
        cam = R.camera((0, -16, 0), (0, 0, 0), lens=40)
        R.backdrop(cam, 22, [(0.0, "#e0601c"), (0.4, "#6a240c"), (1.0, "#100a06")], rays=14, ray_color="#ffb060", ray_strength=0.08, center=(0.0, 0.25))
        # zwei grosse Messer als X, Kreuzung hinter dem Ball
        for side in (-1, 1):
            a = math.radians(48)
            ks = 1.8
            mid = 2.4 * ks
            knife((side * mid * math.sin(a), 1.0 + side * 0.15, 1.9 - mid * math.cos(a)), (0, -side * 48, 0), s=ks)
        soccer_ball((0, -1.5, 1.9), 1.7)
        R.area((-6, -12, 8), (0, 0, 1), 5000, "#ffffff", 8)
        R.area((7, -8, -2), (0, 0, 1), 2500, "#ffb070", 6)
        R.point((0, 3, 4), 2500, "#ff8a2a", 2.0)
        R.place_title(cam, "SOCCER", 0.0, -0.5, 6, 0.15, tilt=5, italic_shear=0.15, colors=(("0", "#ffffff"), ("1", "#d8dce6")),
                      outline="#141414", emit=0.3)
        R.place_title(cam, "JAM!", 0.0, -0.8, 6, 0.17, tilt=5, italic_shear=0.15, colors=(("0.05", "#ff4a1a"), ("0.6", "#ff9a1a"), ("1", "#ffe08a")),
                      outline="#1a0802")
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
