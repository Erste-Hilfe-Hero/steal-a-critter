# surf_ski: Surfer gleitet mit hohem Tempo eine verschneite Neon-Rampe entlang, Polarlicht am Himmel.
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rblx as R  # noqa: E402

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
FAST = "--fast" in sys.argv


def ramp(x, y0, length, ztop, w=6.0, h=7.0):
    """Dachfoermige Surf-Rampe (Dreiecksprisma) entlang Y."""
    import bpy
    verts = [(x, y0, ztop), (x + w, y0, ztop - h), (x - w, y0, ztop - h),
             (x, y0 + length, ztop), (x + w, y0 + length, ztop - h), (x - w, y0 + length, ztop - h)]
    faces = [(0, 1, 4, 3), (0, 3, 5, 2), (1, 2, 5, 4), (0, 2, 1), (3, 4, 5)]
    me = bpy.data.meshes.new("ramp")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("ramp", me)
    bpy.context.collection.objects.link(o)
    bv = o.modifiers.new("bv", "BEVEL")
    bv.width = 0.15
    bv.segments = 3
    R.assign(o, R.mat("#c9d6f0", rough=0.45, coat=0.5))
    edge = R.emit_mat("#3ae8ff", 6)
    pink = R.emit_mat("#ff4fd8", 5)
    R.cyl(0.18, length, (x, y0 + length / 2, ztop + 0.05), (90, 0, 0), m=edge, verts=12)
    for s in (-1, 1):
        R.cyl(0.14, length, (x + s * w, y0 + length / 2, ztop - h), (90, 0, 0), m=pink, verts=12)
    return o


def aurora():
    for i, (c, z, y) in enumerate((("#3affb0", 40, 200), ("#3ae8ff", 52, 220), ("#b35bff", 64, 240))):
        o = R.box((420, 0.5, 30), (0, y + 60, z + 10), (0, 0, 0), m=R.emit_mat(c, 0.9), bevel=0)
        sw = o.modifiers.new("w", "SIMPLE_DEFORM")
        o.visible_shadow = False


def world_bits():
    R.ground(m=R.mat("#cfe0f5", rough=0.3, coat=0.5), size=500, z=-30)
    for x, y, s in ((-90, 220, 70), (-20, 260, 90), (60, 230, 80), (130, 250, 70), (-150, 260, 80)):
        R.cone(s, 0, s * 1.0, (x, y, -30 + s * 0.5), m=R.mat("#2a3466", rough=0.7), verts=5)
        R.cone(s * 0.35, 0, s * 0.35, (x, y, -30 + s * 0.83), m=R.mat("#f2f7ff", rough=0.4), verts=5)
    random.seed(9)
    star = R.emit_mat("#ffffff", 6)
    for _ in range(140):
        R.ball(random.uniform(0.2, 0.5), (random.uniform(-200, 200), 300, random.uniform(20, 140)), m=star, seg=8)


def surfer(loc, rot, scale=1.0):
    pose = {"la": (-10, 75, 0), "ra": (10, -70, 0), "ll": (0, 8, 0), "rl": (0, -8, 0), "head": (0, 0, -20)}
    p = R.noob(loc, rot, shirt="#ff3b8b", pants="#1e1b3e", mood="cool", pose=pose, cap="#25b8ff", scale=scale)
    return p


def speed_lines(cam_target, n=26):
    random.seed(2)
    m = R.emit_mat("#ffffff", 3)
    for _ in range(n):
        x = cam_target[0] + random.uniform(-10, 3)
        z = cam_target[2] + random.uniform(-4, 6)
        y = random.uniform(-4, 10)
        L = random.uniform(4, 12)
        o = R.cyl(random.uniform(0.03, 0.07), L, (x, y + L / 2, z), (90, 0, 0), m=m, verts=8)
        o.visible_shadow = False


def scene(kind):
    w, h = (1920, 1080) if kind == "thumb" else (1024, 1024)
    R.reset(w // (2 if FAST else 1), h // (2 if FAST else 1), samples=16 if FAST else 64)
    R.world("#2a2f6b", 0.7, top="#060818")
    world_bits()
    aurora()
    R.sun((35, 0, 200), 1.8, "#c9dcff")
    ramp(0, -40, 200, 8)
    ramp(-22, 10, 150, 14)
    ramp(26, 30, 150, 4)
    # Surfer auf der rechten Flanke, senkrecht zur Rampe
    tilt = math.degrees(math.atan2(6.0, 7.0))
    fx, fz = 0.45 * 6.0, 8 - 0.45 * 7.0
    sx = surfer((fx + 0.2, 0, fz + 0.1), (0, tilt, 0))
    speed_lines((fx, 0, fz + 3))
    R.area((14, -12, 16), (fx, 0, fz), 2500, "#d0e4ff", 10)
    R.area((-8, 6, 14), (fx, 0, fz), 4000, "#ff4fd8", 6)
    if kind == "thumb":
        cam = R.camera((17, -17, fz + 5.5), (fx - 4, 14, fz + 1.0), lens=30)
        R.place_title(cam, "surf_ski", -0.4, 0.72, 6, 0.19, tilt=6, italic_shear=0.2,
                      colors=(("0", "#25b8ff"), ("0.6", "#7df3ff"), ("1", "#ffffff")), outline="#0a1640")
        R.place_title(cam, "10 STAGES  WORLD RECORDS", -0.4, 0.44, 6, 0.05, tilt=6, colors=(("0", "#ffffff"), ("1", "#ffffff")),
                      emit=0.5, outline="#c2134a")
        R.render(os.path.join(OUT, "thumbnail.png"))
    else:
        cam = R.camera((10.5, -9.5, fz + 4.5), (fx - 0.5, 2, fz + 2.2), lens=28)
        R.place_title(cam, "SURF", 0.0, -0.7, 6, 0.17, tilt=6, italic_shear=0.2,
                      colors=(("0", "#25b8ff"), ("0.6", "#7df3ff"), ("1", "#ffffff")), outline="#0a1640")
        R.render(os.path.join(OUT, "icon.png"))


for k in [a for a in ("thumb", "icon") if a in sys.argv] or ["thumb", "icon"]:
    scene(k)
