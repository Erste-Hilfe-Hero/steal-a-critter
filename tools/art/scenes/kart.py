# Fire Blaster Race: Karts mit Feuer-Turbo rasen auf die Kamera zu, Item-Boxen schweben ueber der Strecke.
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def kart(loc, rot, body="#ff7a1a", shirt="#2f7cff", helmet="#ffffff", flame=True, mood="grin"):
    root = R.empty(loc, rot)
    bm = R.mat(body, rough=0.2, coat=1.0)
    R.box((3.4, 5.6, 0.9), (0, 0, 0.9), m=bm, parent=root, bevel=0.35)
    R.box((2.6, 2.0, 0.9), (0, -1.9, 1.4), (-12, 0, 0), m=bm, parent=root, bevel=0.35)
    R.box((3.8, 0.6, 0.4), (0, -3.0, 0.7), m=R.mat("#22222c", rough=0.4), parent=root, bevel=0.15)
    R.box((3.6, 0.5, 0.3), (0, 2.9, 2.2), m=bm, parent=root, bevel=0.12)
    for sx in (-1, 1):
        R.box((0.2, 0.3, 1.1), (sx * 1.3, 2.7, 1.6), m=R.mat("#22222c"), parent=root, bevel=0.05)
    tire = R.mat("#15151c", rough=0.6)
    rim = R.mat("#ffd21f", rough=0.2, metal=0.6)
    for sx in (-1, 1):
        for sy, rr in ((-1, 0.75), (1, 0.9)):
            R.cyl(rr, 0.9, (sx * 1.95, sy * 1.9, rr), (0, 90, 0), m=tire, parent=root, bevel=0.2)
            R.cyl(rr * 0.5, 0.95, (sx * 2.0, sy * 1.9, rr), (0, 90, 0), m=rim, parent=root)
    # Fahrer
    drv = R.noob((0, 0.6, -0.4), (0, 0, 0), shirt=shirt, pants="#2b2f45", mood=mood,
                 pose={"la": (-70, 0, 10), "ra": (-70, 0, -10), "ll": (-90, 0, 0), "rl": (-90, 0, 0)}, scale=0.62)
    drv["root"].parent = root
    R.ball(0.92, (0, 0, 0.7), (1, 1, 0.95), m=R.mat(helmet, rough=0.15, coat=1), parent=drv["head"])
    R.box((1.3, 0.3, 0.55), (0, -0.78, 0.66), m=R.mat("#1a1a2a", rough=0.05, coat=1), parent=drv["head"], bevel=0.12)
    R.cyl(0.35, 1.0, (0, -0.2, 0.0), (0, 0, 0), m=R.mat("#22222c"), parent=root).location = (0, -0.9, 2.1)
    # Auspuff + Feuer
    for sx in (-0.7, 0.7):
        R.cyl(0.3, 1.0, (sx, 3.0, 1.0), (90, 0, 0), m=R.mat("#9aa0ad", metal=1, rough=0.2), parent=root)
        if flame:
            fm = R.gradient_mat([(0.0, "#ff2a1a"), (0.5, "#ff8a1a"), (1.0, "#fff3a0")], axis="Z", emit=4.0)
            c = R.cone(0.05, 0.55, 4.5, (sx, 5.6, 1.0), (-90, 0, 0), m=fm, parent=root)
            c.visible_shadow = False
    if flame:
        R.point((0, 5, 1.5), 1800, "#ff7a2a", 1.0).parent = root
    return root


def item_box(loc, s=1.0):
    root = R.empty(loc, (20, 15, 30))
    R.box((2 * s, 2 * s, 2 * s), (0, 0, 0), m=R.mat("#ffb81a", rough=0.1, coat=1, emit=0.35), parent=root, bevel=0.3 * s)
    t = R.title("?", font="lilita-one", size=1.6 * s, loc=(0, -1.02 * s, 0), rot=(90, 0, 0), colors=(("0", "#ffffff"), ("1", "#ffffff")),
                outline="#7a3a00", parent=root, emit=0.6)
    return root


def track():
    R.ground(m=R.mat("#3fae4a", rough=0.8, coat=0), size=400)
    R.box((22, 300, 0.1), (0, 60, 0.05), m=R.mat("#2c2c38", rough=0.45, coat=0.4), bevel=0)
    for side in (-1, 1):
        for i in range(-10, 80):
            R.box((1.4, 2.0, 0.4), (side * 11.6, i * 2.0, 0.2), m=R.mat("#e8323c" if i % 2 else "#ffffff", rough=0.4), bevel=0.05)
    for i in range(-5, 40):
        R.box((0.4, 3, 0.06), (0, i * 7, 0.12), m=R.emit_mat("#ffffff", 0.6), bevel=0)
    # Boost-Pads
    for y in (14, 30):
        R.box((5, 4, 0.08), (-4, y, 0.13), m=R.emit_mat("#25b8ff", 3), bevel=0.1)
    # Berge
    for x, y, s, c in ((-60, 160, 40, "#6a5acd"), (10, 190, 55, "#5a4abd"), (80, 170, 45, "#7a6add"), (-120, 200, 50, "#5a4abd")):
        R.cone(s, 0, s * 1.1, (x, y, s * 0.55), m=R.mat(c, rough=0.8))


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#ffb36b", 1.0, top="#3a5bd6")
    track()
    R.sun((40, 0, 160), 3.5, "#ffe0b0")
    if kind == "thumb":
        cam = R.camera((-1.0, -14, 3.0), (0.5, 6, 2.6), lens=30)
        kart((2.0, 0, 0), (0, 0, 32), body="#ff7a1a", shirt="#2f7cff")
        kart((-5.5, 9, 0), (0, 0, -28), body="#25b8ff", shirt="#e8323c", helmet="#ffd21f")
        kart((6.5, 16, 0), (0, 0, 6), body="#b35bff", shirt="#3fd65a", helmet="#ff5ad1")
        item_box((-4.5, 1.5, 4.2), 0.9)
        item_box((7.5, 7, 5.0), 0.8)
        R.area((-10, -14, 10), (0, 2, 2), 6000, "#ffffff", 10)
        R.area((10, 10, 8), (0, 0, 2), 6000, "#ff9cf0", 6)
        R.place_title(cam, "FIRE BLASTER", 0.0, 0.8, 6, 0.12, italic_shear=0.15, colors=(("0.05", "#ff3a1a"), ("0.6", "#ff9a1a"), ("1", "#ffe08a")),
                      outline="#1a0802")
        R.place_title(cam, "RACE", 0.0, 0.5, 6, 0.12, italic_shear=0.15, colors=(("0", "#ffffff"), ("1", "#e6f0ff")), emit=0.4, outline="#1a0802")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((-0.5, -10.5, 3.4), (0.2, 2, 2.3), lens=32)
        kart((0.6, 0, 0), (0, 0, 35), body="#ff7a1a", shirt="#2f7cff")
        item_box((-3.4, 2, 5.0), 0.8)
        R.area((-10, -14, 10), (0, 2, 2), 6000, "#ffffff", 10)
        R.area((10, 10, 8), (0, 0, 2), 6000, "#ff9cf0", 6)
        R.place_title(cam, "RACE!", 0.0, -0.7, 6, 0.17, tilt=4, italic_shear=0.15, colors=(("0.05", "#ff3a1a"), ("0.6", "#ff9a1a"), ("1", "#ffe08a")),
                      outline="#1a0802")
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
