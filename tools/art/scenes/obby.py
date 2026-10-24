# Mega Rainbow Obby: Figur springt ueber Lava von Regenbogen-Plattform zu Plattform.
import colorsys
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv
RAINBOW = ["#ff3b4e", "#ff8a1f", "#ffd21f", "#3fd65a", "#25b8ff", "#5b6bff", "#b35bff"]
RB_STOPS = tuple((str(i / 6), c) for i, c in enumerate(RAINBOW))


def course(z0=0.0):
    R.ground(m=R.lava_mat(), size=300, z=z0)
    # Plattformen, die in die Ferne fuehren
    path = [(-8.5, -3, 3.0), (2.5, 3, 3.6), (9.5, 4, 3.0), (6, 12, 3.6), (14, 16, 4.2), (6, 24, 4.8), (16, 30, 5.4),
            (-6, 16, 3.2), (-14, 28, 4.6), (2, 40, 6.0), (24, 42, 6.4)]
    for i, (x, y, z) in enumerate(path):
        c = RAINBOW[i % len(RAINBOW)]
        R.box((4.2, 4.2, 1.6), (x, y, z), m=R.mat(c, rough=0.22, coat=0.8, emit=0.08), bevel=0.3)
    # rotierender Kill-Balken
    R.cyl(0.35, 9, (9.5, 4, 4.4), (0, 90, 25), m=R.emit_mat("#ff2244", 3))
    R.cyl(0.6, 1.0, (9.5, 4, 4.0), m=R.mat("#33223f"))
    # Lava-Blasen und Glut-Licht von unten
    for x, y in ((-3, -6), (5, -3), (-12, 4), (12, -6), (0, 10), (-6, -9)):
        R.ball(0.5, (x, y, 0.1), (1, 1, 0.5), m=R.emit_mat("#ffb02e", 3))
    R.area((0, 0, 0.5), (0, 0, 10), 6000, "#ff6a1a", 30)
    for x, y, z, s in ((-30, 70, 18, 3.5), (25, 80, 22, 4.2), (60, 90, 14, 5), (-60, 85, 26, 4.5), (5, 120, 30, 6)):
        R.cloud((x, y, z), s)


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#d9f1ff", 1.0, top="#2f7bff")
    course()
    pose = {"la": (160, 0, 35), "ra": (150, 0, -40), "ll": (60, 0, 0), "rl": (-25, 0, 0), "torso": (-12, 0, 0)}
    R.sun((50, 0, 35), 4.5)
    if kind == "thumb":
        cam = R.camera((-1.0, -18, 7.5), (1.5, 0, 7.4), lens=28)
        R.noob((-3.0, -0.5, 6.4), (0, 0, -40), shirt="#ff3b8b", pants="#2d4bff", mood="grin", pose=pose, cap="#ffd21f")
        for i, (x, y, z) in enumerate(((-6.8, -0.5, 4.2), (-7.6, -1.0, 3.2), (-8.3, -1.5, 2.4))):
            R.sparkle((x, y, z), 0.5 - i * 0.1, RAINBOW[i * 2])
        R.area((-12, -14, 16), (-3, 0, 7), 7000, "#fff1d8", 10)
        R.area((10, 10, 12), (-3, 1, 8), 9000, "#ff9cf0", 6)
        R.place_title(cam, "MEGA RAINBOW", 0.42, 0.8, 6, 0.085, tilt=-4, axis="X", colors=RB_STOPS, emit=0.35)
        R.place_title(cam, "OBBY", 0.42, 0.42, 6, 0.21, tilt=-4, colors=(("0.05", "#ff9a1a"), ("0.6", "#ffe03a"), ("1", "#fff7a8")))
        R.place_title(cam, "100 STAGES!", 0.44, 0.03, 6, 0.06, tilt=-4, colors=(("0", "#ffffff"), ("1", "#ffffff")), emit=0.4,
                      outline="#c2134a")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((-1.5, -11.5, 8.0), (-1.8, 0, 7.6), lens=34)
        R.noob((-2.6, -0.5, 6.4), (0, 0, -28), shirt="#ff3b8b", pants="#2d4bff", mood="grin", pose=pose, cap="#ffd21f")
        R.area((-12, -14, 16), (-3, 0, 8), 7000, "#fff1d8", 10)
        R.area((10, 10, 12), (-3, 1, 9), 9000, "#ff9cf0", 6)
        R.place_title(cam, "OBBY", 0.0, -0.66, 6, 0.24, tilt=4, axis="X", colors=RB_STOPS, emit=0.3)
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
