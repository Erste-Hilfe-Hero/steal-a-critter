# Gemeinsame Bausteine fuer die 3D-Vorschaubilder (Blender als Python-Modul "bpy").
# Jede Szene in tools/art/scenes/*.py baut mit diesen Funktionen Figuren, Titel und Licht
# und ruft am Ende render() auf. Aufruf: siehe tools/art/README.md
import colorsys
import math
import os
import random

import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "fonts")
INK = (0.03, 0.02, 0.06)


def hexc(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # sRGB -> linear, damit die Farben so aussehen wie angegeben
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (c[0], c[1], c[2], a)


_mats = {}


def reset(w=1920, h=1080, samples=64):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 6
    s.render.resolution_x = w
    s.render.resolution_y = h
    s.render.film_transparent = False
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGB"
    random.seed(7)
    return s


# ---------------------------------------------------------------- Materialien


def mat(color, rough=0.38, metal=0.0, emit=0.0, coat=0.25, name=None):
    key = name or (tuple(color) if not isinstance(color, str) else color, rough, metal, emit, coat)
    if key in _mats:
        return _mats[key]
    c = hexc(color) if isinstance(color, str) else tuple(color)[:3] + (1.0,)
    m = bpy.data.materials.new(name or "m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.15
    if emit:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emit
    _mats[key] = m
    return m


def gradient_mat(stops, axis="Y", emit=0.0, rough=0.3, coat=0.4, coords="Generated"):
    """Farbverlauf entlang einer Achse der (lokalen) Objektbox. stops = [(pos, '#hex'), ...]"""
    m = bpy.data.materials.new("grad")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs[coords], sep.inputs[0])
    nt.links.new(sep.outputs[axis], ramp.inputs[0])
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], hexc(stops[0][1])
    els[1].position, els[1].color = stops[-1][0], hexc(stops[-1][1])
    for p, c in stops[1:-1]:
        e = els.new(p)
        e.color = hexc(c)
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    if emit:
        nt.links.new(ramp.outputs[0], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit
    return m


def rainbow_mat(scale=1.6, emit=0.15, sat=0.85):
    """Regenbogen, der sich diagonal ueber das Objekt zieht (fuer mythische Critter)."""
    stops = []
    for i in range(7):
        r, g, b = colorsys.hsv_to_rgb(i / 6 * 0.92, sat, 1)
        stops.append((i / 6, "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))))
    m = bpy.data.materials.new("rainbow")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0.6, 0.4, 0.8)
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    grad = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "PINGPONG"
    fr.inputs[1].default_value = 1.0
    nt.links.new(tc.outputs["Generated"], mp.inputs[0])
    nt.links.new(mp.outputs[0], grad.inputs[0])
    nt.links.new(grad.outputs["X"], fr.inputs[0])
    nt.links.new(fr.outputs[0], ramp.inputs[0])
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], hexc(stops[0][1])
    els[1].position, els[1].color = stops[-1][0], hexc(stops[-1][1])
    for p, c in stops[1:-1]:
        els.new(p).color = hexc(c)
    nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    nt.links.new(ramp.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = emit
    b.inputs["Roughness"].default_value = 0.25
    b.inputs["Coat Weight"].default_value = 0.6
    return m


def emit_mat(color, strength=4.0):
    m = bpy.data.materials.new("emit")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = hexc(color) if isinstance(color, str) else color
    e.inputs[1].default_value = strength
    nt.links.new(e.outputs[0], nt.nodes["Material Output"].inputs[0])
    return m


def assign(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


# ---------------------------------------------------------------- Grundformen

def _finish(o, loc, rot, m, parent):
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if m is not None:
        assign(o, m)
    if parent is not None:
        o.parent = parent
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.12, parent=None, segs=4):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bv = o.modifiers.new("bv", "BEVEL")
        bv.width = bevel
        bv.segments = segs
        bv.limit_method = "NONE"
    return _finish(o, loc, rot, m, parent)


def ball(r, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), m=None, parent=None, seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=seg // 2)
    o = bpy.context.object
    o.scale = scale
    return _finish(o, loc, rot, m, parent)


def cyl(r, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, parent=None, bevel=0.0, verts=48, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts)
    o = bpy.context.object
    o.scale = scale
    if bevel:
        bv = o.modifiers.new("bv", "BEVEL")
        bv.width = bevel
        bv.segments = 4
        bv.limit_method = "ANGLE"
    return _finish(o, loc, rot, m, parent)


def cone(r1, r2, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, parent=None, verts=32):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, vertices=verts)
    o = bpy.context.object
    return _finish(o, loc, rot, m, parent)


def torus(R, r, loc=(0, 0, 0), rot=(0, 0, 0), m=None, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=64, minor_segments=24)
    o = bpy.context.object
    return _finish(o, loc, rot, m, parent)


def empty(loc=(0, 0, 0), rot=(0, 0, 0), parent=None):
    o = bpy.data.objects.new("e", None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if parent:
        o.parent = parent
    return o


def arc(radius, a0, a1, thick, loc, rot=(90, 0, 0), m=None, parent=None):
    """Gebogene Linie (z. B. Laecheln) als Kurve mit Rundprofil."""
    cu = bpy.data.curves.new("arc", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    n = 16
    sp.points.add(n - 1)
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        sp.points[i].co = (radius * math.cos(a), radius * math.sin(a), 0, 1)
    cu.bevel_depth = thick
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    o = bpy.data.objects.new("arc", cu)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if m:
        o.data.materials.append(m)
    if parent:
        o.parent = parent
    return o


# ---------------------------------------------------------------- Roblox-Figur

def face(head, size=1.0, mood="happy", z=0.0, front=0.62, eye_white=False):
    """Gesicht auf die Vorderseite (-Y) eines Kopfes setzen."""
    k = mat(INK, rough=0.2, coat=0.8)
    s = size
    ey = -front * s
    if mood == "angry":
        for sx in (-1, 1):
            ball(0.11 * s, (sx * 0.24 * s, ey, z + 0.08 * s), (1, 0.4, 1.0), m=k, parent=head)
            box((0.32 * s, 0.06 * s, 0.07 * s), (sx * 0.24 * s, ey - 0.02 * s, z + 0.26 * s), (0, -sx * 22, 0), m=k, parent=head, bevel=0.02)
        arc(0.17 * s, 30, 150, 0.035 * s, (0, ey - 0.01, z - 0.34 * s), m=k, parent=head)
        return
    if mood == "shock":
        for sx in (-1, 1):
            ball(0.13 * s, (sx * 0.24 * s, ey, z + 0.12 * s), (1, 0.4, 1.3), m=k, parent=head)
            ball(0.045 * s, (sx * 0.22 * s - 0.03 * s, ey - 0.05 * s, z + 0.19 * s), m=mat("#ffffff", emit=0.5), parent=head)
        ball(0.12 * s, (0, ey, z - 0.25 * s), (1, 0.4, 1.25), m=k, parent=head)
        return
    if mood == "grin":
        for sx in (-1, 1):
            arc(0.1 * s, 20, 160, 0.04 * s, (sx * 0.24 * s, ey - 0.01, z + 0.08 * s), m=k, parent=head)
        arc(0.26 * s, 200, 340, 0.045 * s, (0, ey - 0.01, z - 0.04 * s), m=k, parent=head)
        return
    if mood == "cool":
        box((0.78 * s, 0.08 * s, 0.2 * s), (0, ey - 0.02, z + 0.12 * s), m=mat("#111111", rough=0.05, coat=1), parent=head, bevel=0.04)
        arc(0.2 * s, 205, 335, 0.04 * s, (0.04 * s, ey - 0.01, z - 0.05 * s), m=k, parent=head)
        return
    # happy
    for sx in (-1, 1):
        ball(0.1 * s, (sx * 0.24 * s, ey, z + 0.1 * s), (1, 0.4, 1.35), m=k, parent=head)
        ball(0.035 * s, (sx * 0.24 * s - 0.03 * s, ey - 0.04 * s, z + 0.16 * s), m=mat("#ffffff", emit=0.5), parent=head)
    arc(0.22 * s, 205, 335, 0.04 * s, (0, ey - 0.01, z - 0.02 * s), m=k, parent=head)


def noob(loc=(0, 0, 0), rot=(0, 0, 0), skin="#f5c56b", shirt="#2f7cf6", pants="#2b2f45",
         mood="happy", pose=None, hair=None, scale=1.0, cap=None, mask=None):
    """Blockige Roblox-Figur. pose: dict mit Winkeln (Grad) fuer Glieder:
    la/ra = (x, y, z) Arme, ll/rl = Beine, head, torso. +x = nach vorne heben."""
    pose = pose or {}
    root = empty(loc, rot)
    root.scale = (scale,) * 3
    torso_p = empty((0, 0, 2.0), pose.get("torso", (0, 0, 0)), parent=root)
    sm = mat(skin)
    box((2.0, 1.0, 2.0), (0, 0, 1.0), m=mat(shirt), parent=torso_p, bevel=0.14)
    # Kopf (zylinderfoermig, wie bei Roblox)
    neck = empty((0, 0, 2.0), pose.get("head", (0, 0, 0)), parent=torso_p)
    head = cyl(0.62, 1.15, (0, 0, 0.66), (0, 0, 0), m=sm, parent=neck, bevel=0.28)
    head.scale = (1.0, 0.95, 1.0)
    face(neck, 1.0, mood, z=0.68, front=0.6)
    if hair:
        box((1.32, 1.32, 0.42), (0, 0.06, 1.28), m=mat(hair), parent=neck, bevel=0.18)
        box((1.32, 0.4, 0.75), (0, 0.5, 0.95), m=mat(hair), parent=neck, bevel=0.15)
    if cap:
        box((1.36, 1.36, 0.45), (0, 0, 1.3), m=mat(cap), parent=neck, bevel=0.2)
        box((1.2, 0.7, 0.12), (0, -0.85, 1.12), m=mat(cap), parent=neck, bevel=0.05)
    if mask:
        box((1.34, 1.3, 0.34), (0, 0, 0.82), m=mat(mask, rough=0.5), parent=neck, bevel=0.1)
        for sx in (-1, 1):
            ball(0.13, (sx * 0.25, -0.64, 0.84), (1.2, 0.4, 0.9), m=mat("#ffffff", emit=0.3), parent=neck)
            ball(0.07, (sx * 0.25, -0.69, 0.82), (1, 0.5, 1.1), m=mat(INK), parent=neck)
    parts = {}
    for side, sx in (("la", -1), ("ra", 1)):
        sh = empty((sx * 1.5, 0, 1.75), pose.get(side, (0, 0, 0)), parent=torso_p)
        box((0.95, 0.95, 2.0), (0, 0, -0.75), m=sm, parent=sh, bevel=0.14)
        box((0.98, 0.98, 0.7), (0, 0, 0.0), m=mat(shirt), parent=sh, bevel=0.14)
        parts[side] = sh
    for side, sx in (("ll", -1), ("rl", 1)):
        hp = empty((sx * 0.5, 0, 2.0), pose.get(side, (0, 0, 0)), parent=root)
        box((0.96, 0.96, 2.0), (0, 0, -1.0), m=mat(pants), parent=hp, bevel=0.14)
        parts[side] = hp
    parts["root"], parts["torso"], parts["head"] = root, torso_p, neck
    return parts


# ---------------------------------------------------------------- Critter

def critter(loc, r=1.0, color="#58c7ff", m=None, mood="happy", ears="cat", rot=(0, 0, 0), crown=False, blush=True):
    root = empty(loc, rot)
    body_m = m or mat(color, rough=0.32, coat=0.5)
    ball(r, (0, 0, 0), (1, 0.94, 0.92), m=body_m, parent=root)
    if ears == "cat":
        for sx in (-1, 1):
            cone(0.32 * r, 0.04 * r, 0.6 * r, (sx * 0.55 * r, 0, 0.78 * r), (0, sx * 28, 0), m=body_m, parent=root)
    elif ears == "bear":
        for sx in (-1, 1):
            ball(0.3 * r, (sx * 0.62 * r, 0.05 * r, 0.7 * r), (1, 0.7, 1), m=body_m, parent=root)
    elif ears == "bunny":
        for sx in (-1, 1):
            ball(0.22 * r, (sx * 0.35 * r, 0.05 * r, 1.15 * r), (0.8, 0.6, 2.2), (0, sx * 12, 0), m=body_m, parent=root)
    elif ears == "horn":
        cone(0.18 * r, 0.0, 0.7 * r, (0, -0.1 * r, 1.1 * r), (-15, 0, 0), m=mat("#ffe27a", rough=0.2, metal=0.6), parent=root)
    k = mat(INK, rough=0.15, coat=1)
    w = mat("#ffffff", emit=1.0)
    ey = -0.86 * r
    if mood == "shock":
        for sx in (-1, 1):
            ball(0.22 * r, (sx * 0.34 * r, ey, 0.15 * r), (1, 0.45, 1.15), m=mat("#ffffff", rough=0.2), parent=root)
            ball(0.12 * r, (sx * 0.34 * r, ey - 0.07 * r, 0.15 * r), (1, 0.5, 1.1), m=k, parent=root)
        ball(0.14 * r, (0, ey + 0.02 * r, -0.3 * r), (1, 0.4, 1.3), m=k, parent=root)
    elif mood == "angry":
        for sx in (-1, 1):
            ball(0.15 * r, (sx * 0.34 * r, ey, 0.1 * r), (1, 0.45, 0.8), m=k, parent=root)
            box((0.42 * r, 0.08 * r, 0.09 * r), (sx * 0.34 * r, ey - 0.06 * r, 0.33 * r), (0, -sx * 25, 0), m=k, parent=root, bevel=0.02)
        arc(0.2 * r, 30, 150, 0.045 * r, (0, ey - 0.02 * r, -0.42 * r), m=k, parent=root)
    else:
        for sx in (-1, 1):
            ball(0.17 * r, (sx * 0.34 * r, ey, 0.12 * r), (1, 0.45, 1.25), m=k, parent=root)
            ball(0.06 * r, (sx * 0.34 * r - 0.05 * r, ey - 0.08 * r, 0.22 * r), m=w, parent=root)
        arc(0.15 * r, 205, 335, 0.04 * r, (0, ey + 0.02 * r, -0.12 * r), m=k, parent=root)
    if blush:
        for sx in (-1, 1):
            ball(0.12 * r, (sx * 0.58 * r, ey + 0.2 * r, -0.12 * r), (1, 0.3, 0.6), m=mat("#ff7aa8", rough=0.6, coat=0), parent=root)
    if crown:
        gold = mat("#ffcf33", rough=0.2, metal=0.9, coat=0.5)
        cyl(0.45 * r, 0.25 * r, (0, 0, 1.0 * r), m=gold, parent=root)
        for i in range(5):
            a = i / 5 * 2 * math.pi
            cone(0.12 * r, 0, 0.35 * r, (0.4 * r * math.cos(a), 0.4 * r * math.sin(a), 1.28 * r), m=gold, parent=root)
    return root


# ---------------------------------------------------------------- Requisiten

def cash(loc, rot=(0, 0, 0), s=1.0):
    root = empty(loc, rot)
    box((1.6 * s, 0.04 * s, 0.8 * s), (0, 0, 0), m=mat("#3fc46a", rough=0.5, coat=0.1), parent=root, bevel=0.02)
    box((1.3 * s, 0.05 * s, 0.55 * s), (0, 0, 0), m=mat("#2a9a4e", rough=0.5, coat=0.1), parent=root, bevel=0.02)
    cyl(0.2 * s, 0.07 * s, (0, 0, 0), (90, 0, 0), m=mat("#bff5cf", rough=0.5), parent=root)
    return root


def coin(loc, rot=(0, 0, 0), r=0.5):
    gold = mat("#ffc21a", rough=0.18, metal=1.0, coat=0.6, name="gold")
    root = empty(loc, rot)
    cyl(r, r * 0.22, (0, 0, 0), (90, 0, 0), m=gold, parent=root, bevel=r * 0.06)
    cyl(r * 0.62, r * 0.26, (0, 0, 0), (90, 0, 0), m=mat("#ffe066", rough=0.15, metal=1.0, name="gold2"), parent=root)
    return root


def sparkle(loc, s=0.5, color="#ffffff", strength=12):
    m = emit_mat(color, strength)
    root = empty(loc)
    for rot in ((0, 0, 0), (0, 90, 0)):
        o = ball(s, (0, 0, 0), (0.12, 0.12, 1.0), (rot[0], rot[1], 0), m=m, parent=root, seg=16)
    ball(s * 0.25, (0, 0, 0), m=m, parent=root, seg=16)
    return root


# ---------------------------------------------------------------- Titel-Schrift

def title(text, font="lilita-one", size=1.0, loc=(0, 0, 0), rot=(90, 0, 0),
          colors=(("0", "#fff36b"), ("1", "#ffa31a")), outline="#1b0f2e", outline_w=0.075,
          depth=0.14, align="CENTER", spacing=1.0, italic_shear=0.0, emit=0.25, parent=None, axis="Y"):
    """Dicke 3D-Schrift mit Farbverlauf, Fase und dunkler Kontur, wie auf Roblox-Thumbnails."""
    fpath = os.path.join(FONTS, font + ".ttf")
    vf = bpy.data.fonts.load(fpath, check_existing=True)
    root = empty(loc, rot, parent=parent)

    def mk(off, extr, z, m, bev):
        cu = bpy.data.curves.new("t", "FONT")
        cu.body = text
        cu.font = vf
        cu.size = size
        cu.align_x = align
        cu.align_y = "CENTER"
        cu.space_character = spacing
        cu.shear = italic_shear
        cu.offset = off
        cu.extrude = extr
        cu.bevel_depth = bev
        cu.bevel_resolution = 4
        cu.resolution_u = 24
        o = bpy.data.objects.new("t", cu)
        bpy.context.collection.objects.link(o)
        o.parent = root
        o.location = (0, 0, z)
        o.data.materials.append(m)
        return o

    depth = depth * size
    stops = [(float(p), c) for p, c in colors]
    face_m = gradient_mat(stops, axis=axis, emit=emit, rough=0.22, coat=0.8)
    mk(0.0, depth * 0.3, depth * 0.35, face_m, size * 0.018)
    side = mat(outline, rough=0.35, coat=0.3)
    mk(size * outline_w, depth, -depth * 0.75, side, size * 0.02)
    return root


# ---------------------------------------------------------------- Kamera, Licht, Welt

def camera(loc, look_at, lens=50, dof=None, fstop=4.0):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    o = bpy.data.objects.new("cam", cd)
    bpy.context.collection.objects.link(o)
    o.location = loc
    d = Vector(look_at) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = o
    if dof:
        cd.dof.use_dof = True
        cd.dof.focus_distance = dof
        cd.dof.aperture_fstop = fstop
    bpy.context.view_layer.update()
    return o


def in_front(cam, nx, ny, dist):
    """Weltposition fuer Bildkoordinate (nx, ny in -1..1, ny nach oben) in Abstand dist vor der Kamera."""
    s = bpy.context.scene
    aspect = s.render.resolution_x / s.render.resolution_y
    cd = cam.data
    half_w = dist * (cd.sensor_width / 2) / cd.lens
    if aspect < 1:
        half_w *= aspect
    half_h = half_w / aspect
    local = Vector((nx * half_w, ny * half_h, -dist))
    return cam.matrix_world @ local


def face_cam(obj, cam, tilt=0.0, yaw=0.0):
    """Objekt (Schrift liegt in XY) so drehen, dass es zur Kamera zeigt."""
    obj.rotation_euler = (cam.matrix_world.to_3x3() @ Euler((0, 0, math.radians(tilt))).to_matrix()
                          @ Euler((math.radians(yaw), 0, 0)).to_matrix()).to_euler()


def place_title(cam, text, nx, ny, dist, height_frac, tilt=0, **kw):
    """Titel im Bild platzieren: height_frac = Schrifthoehe als Anteil der Bildhoehe."""
    s = bpy.context.scene
    aspect = s.render.resolution_x / s.render.resolution_y
    cd = cam.data
    half_w = dist * (cd.sensor_width / 2) / cd.lens
    if aspect < 1:
        half_w *= aspect
    half_h = half_w / aspect
    size = height_frac * 2 * half_h / 0.72  # Versalhoehe ~0.72 * size
    t = title(text, size=size, loc=in_front(cam, nx, ny, dist), rot=(0, 0, 0), **kw)
    face_cam(t, cam, tilt)
    t.location = in_front(cam, nx, ny, dist)
    return t


def sun(rot=(50, 0, 30), strength=4.0, color="#fff4e0", angle=3.0):
    ld = bpy.data.lights.new("sun", "SUN")
    ld.energy = strength
    ld.color = hexc(color)[:3]
    ld.angle = math.radians(angle)
    o = bpy.data.objects.new("sun", ld)
    bpy.context.collection.objects.link(o)
    o.rotation_euler = [math.radians(a) for a in rot]
    return o


def area(loc, look_at, power=1000, color="#ffffff", size=5.0):
    ld = bpy.data.lights.new("area", "AREA")
    ld.energy = power
    ld.color = hexc(color)[:3]
    ld.size = size
    o = bpy.data.objects.new("area", ld)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(look_at) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o


def point(loc, power=500, color="#ffffff", radius=0.5):
    ld = bpy.data.lights.new("pt", "POINT")
    ld.energy = power
    ld.color = hexc(color)[:3]
    ld.shadow_soft_size = radius
    o = bpy.data.objects.new("pt", ld)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return o


def world(color="#9fd8ff", strength=1.0, top=None):
    w = bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    if top:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        nt.links.new(tc.outputs["Window"], sep.inputs[0])
        nt.links.new(sep.outputs["Y"], ramp.inputs[0])
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = hexc(color)
        ramp.color_ramp.elements[1].position = 1.0
        ramp.color_ramp.elements[1].color = hexc(top)
        nt.links.new(ramp.outputs[0], bg.inputs[0])
    else:
        bg.inputs[0].default_value = hexc(color)
    bg.inputs[1].default_value = strength
    return w


def backdrop(cam, dist, stops, rays=0, ray_color="#ffffff", ray_strength=0.12, center=(0.0, 0.0)):
    """Grosse leuchtende Flaeche hinter der Szene: radialer Verlauf + optional Strahlenkranz."""
    s = bpy.context.scene
    aspect = s.render.resolution_x / s.render.resolution_y
    cd = cam.data
    half_w = dist * (cd.sensor_width / 2) / cd.lens
    if aspect < 1:
        half_w *= aspect
    half_h = half_w / aspect
    bpy.ops.mesh.primitive_plane_add(size=2)
    o = bpy.context.object
    o.scale = (half_w * 1.15, half_h * 1.15, 1)
    m = bpy.data.materials.new("bd")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (-center[0], -center[1], 0)
    mp.inputs["Scale"].default_value = (aspect, 1, 1)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    gr = nt.nodes.new("ShaderNodeTexGradient")
    gr.gradient_type = "SPHERICAL"
    nt.links.new(mp.outputs[0], gr.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(gr.outputs["Fac"], ramp.inputs[0])
    els = ramp.color_ramp.elements
    # Fac der Kugel: 1 in der Mitte, 0 am Rand -> stops von aussen (0) nach innen (1)
    els[0].position, els[0].color = stops[0][0], hexc(stops[0][1])
    els[1].position, els[1].color = stops[-1][0], hexc(stops[-1][1])
    for p, c in stops[1:-1]:
        els.new(p).color = hexc(c)
    col = ramp.outputs[0]
    if rays:
        # Strahlen: Winkel um die Mitte -> Sinus -> harte Kante
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(mp.outputs[0], sep.inputs[0])
        at = nt.nodes.new("ShaderNodeMath")
        at.operation = "ARCTAN2"
        nt.links.new(sep.outputs["Y"], at.inputs[0])
        nt.links.new(sep.outputs["X"], at.inputs[1])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = rays
        nt.links.new(at.outputs[0], mul.inputs[0])
        sn = nt.nodes.new("ShaderNodeMath")
        sn.operation = "SINE"
        nt.links.new(mul.outputs[0], sn.inputs[0])
        gt = nt.nodes.new("ShaderNodeMath")
        gt.operation = "GREATER_THAN"
        gt.inputs[1].default_value = 0.0
        nt.links.new(sn.outputs[0], gt.inputs[0])
        sc = nt.nodes.new("ShaderNodeMath")
        sc.operation = "MULTIPLY"
        sc.inputs[1].default_value = ray_strength
        nt.links.new(gt.outputs[0], sc.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "ADD"
        nt.links.new(sc.outputs[0], mix.inputs["Factor"])
        nt.links.new(col, mix.inputs[6])
        mix.inputs[7].default_value = hexc(ray_color)
        col = mix.outputs[2]
    nt.links.new(col, em.inputs[0])
    em.inputs[1].default_value = 1.0
    nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs[0])
    assign(o, m)
    o.visible_shadow = False
    o.visible_diffuse = False
    o.visible_glossy = False
    face_cam(o, cam)
    o.location = in_front(cam, 0, 0, dist)
    return o


def ground(color="#56c25a", size=200, z=0.0, m=None):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z))
    o = bpy.context.object
    assign(o, m or mat(color, rough=0.7, coat=0.0))
    return o


def lava_mat():
    m = bpy.data.materials.new("lava")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    e = nt.nodes.new("ShaderNodeEmission")
    n = nt.nodes.new("ShaderNodeTexNoise")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    n.inputs["Scale"].default_value = 0.09
    n.inputs["Detail"].default_value = 6
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.35, hexc("#7a0d00")
    els[1].position, els[1].color = 0.62, hexc("#ffd23a")
    els.new(0.5).color = hexc("#ff4a0a")
    nt.links.new(n.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], e.inputs[0])
    e.inputs[1].default_value = 2.2
    nt.links.new(e.outputs[0], nt.nodes["Material Output"].inputs[0])
    return m


def cloud(loc, s=1.0, color="#ffffff"):
    m = mat(color, rough=0.9, coat=0.0, emit=0.15)
    root = empty(loc)
    for x, z, r in ((0, 0, 1.4), (1.5, -0.2, 1.1), (-1.5, -0.3, 1.0), (0.7, 0.7, 1.0), (-0.7, 0.5, 0.9), (2.6, -0.4, 0.7), (-2.5, -0.5, 0.6)):
        ball(r * s, (x * s, 0, z * s), (1, 0.8, 0.85), m=m, parent=root, seg=32)
    return root


def egg(loc, r=1.0, m=None, rot=(0, 0, 0), cut=None, spots=None, top=False):
    """Ei. cut = Hoehe (relativ zu r) des Zickzack-Bruchs; top=True liefert die obere Schale."""
    root = empty(loc, rot)
    o = ball(r, (0, 0, 0), (1, 1, 1.28), m=m, parent=root, seg=64)
    if cut is not None:
        zc = cut * r * 1.28
        bpy.ops.mesh.primitive_cube_add(size=1)
        c = bpy.context.object
        c.scale = (4 * r, 4 * r, 4 * r)
        c.location = (o.matrix_world.translation.x, o.matrix_world.translation.y, 0)
        c.parent = root
        c.location = (0, 0, zc + (2 * r if not top else -2 * r))
        bl = o.modifiers.new("cut", "BOOLEAN")
        bl.operation = "DIFFERENCE"
        bl.object = c
        bl.solver = "EXACT"
        c.hide_render = True
        c.display_type = "WIRE"
        sol = o.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.06 * r
        # Zacken am Rand
        n = 9
        rr = r * (1 - (cut ** 2)) ** 0.5 * 0.98
        for i in range(n):
            a = i / n * 2 * math.pi
            cn = cone(0.5 * r * math.pi / n * 2, 0.0, 0.26 * r, (rr * math.cos(a), rr * math.sin(a), zc + (0.11 * r if not top else -0.11 * r)),
                      (0 if not top else 180, 0, 0), m=m, parent=root, verts=4)
            cn.rotation_euler[2] = a + math.pi / 4
            cn.scale = (1, 0.35, 1)
    if spots:
        for i in range(7):
            a = i * 2.4
            zz = (0.9 - i * 0.28)
            if cut is not None and ((not top and zz * 1.28 > cut * 1.28) or (top and zz < cut)):
                continue
            rad = r * (1 - min(0.95, zz * zz)) ** 0.5
            ball(0.17 * r, (rad * math.cos(a), rad * math.sin(a), zz * r * 1.28), (1, 1, 0.4), m=spots, parent=root, seg=24
                 ).rotation_euler = Vector((math.cos(a), math.sin(a), zz)).to_track_quat("Z", "Y").to_euler()
    return root


def finish(path, size=None, bloom=0.35, vignette=0.22):
    """Nachbearbeitung: leichtes Leuchten heller Stellen, Vignette, Kontrast, Zielgroesse."""
    import numpy as np
    from PIL import Image, ImageFilter
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255
    bright = np.clip((a - 0.72) / 0.28, 0, 1) * a
    bl = Image.fromarray((bright * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(im.width / 90))
    a = a + bloom * np.asarray(bl).astype(np.float32) / 255
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 1.414
    a = a * (1 - vignette * np.clip(d - 0.35, 0, 1) ** 1.5 / 0.27)[..., None]
    a = np.clip((a - 0.5) * 1.06 + 0.5, 0, 1)
    out = Image.fromarray((a * 255 + 0.5).astype(np.uint8))
    if size and out.size != size:
        out = out.resize(size, Image.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))
    out.save(path, optimize=True)


def sword(loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, parent=None, blade="#dfe8f5", hilt="#ffc21a", glow=None):
    """Schwert entlang +Z (Griff bei 0)."""
    root = empty(loc, rot, parent=parent)
    bm = emit_mat(glow, 2.5) if glow else mat(blade, rough=0.12, metal=0.9, coat=0.6)
    box((0.42 * s, 0.12 * s, 3.2 * s), (0, 0, 2.0 * s), m=bm, parent=root, bevel=0.05 * s)
    tip = cone(0.3 * s, 0.0, 0.5 * s, (0, 0, 3.85 * s), m=bm, parent=root, verts=4)
    tip.rotation_euler = (0, 0, math.radians(45))
    tip.scale = (1, 0.28, 1)
    hm = mat(hilt, rough=0.2, metal=0.8, coat=0.5)
    box((1.4 * s, 0.3 * s, 0.25 * s), (0, 0, 0.35 * s), m=hm, parent=root, bevel=0.08 * s)
    cyl(0.13 * s, 0.75 * s, (0, 0, -0.1 * s), m=mat("#5a3420", rough=0.6), parent=root)
    ball(0.2 * s, (0, 0, -0.55 * s), m=hm, parent=root)
    return root


def crystal(loc, s=1.0, color="#ff6bd6", emit=1.2, rot=(0, 0, 0), parent=None):
    root = empty(loc, rot, parent=parent)
    m = mat(color, rough=0.08, coat=1.0, emit=emit)
    cone(0.8 * s, 0.0, 1.4 * s, (0, 0, 0.7 * s), m=m, parent=root, verts=6)
    cone(0.8 * s, 0.0, 0.9 * s, (0, 0, -0.45 * s), (180, 0, 0), m=m, parent=root, verts=6)
    for o in root.children:
        for p in o.data.polygons:
            p.use_smooth = False
    return root


def light_pillar(loc, color, h=14, r=0.35):
    m = emit_mat(color, 5)
    o = cyl(r, h, (loc[0], loc[1], loc[2] + h / 2), m=m)
    o.visible_shadow = False
    cyl(r * 4, 0.05, (loc[0], loc[1], loc[2] + 0.03), m=emit_mat(color, 2.5)).visible_shadow = False
    return o


def render(path, post=True):
    s = bpy.context.scene
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if post:
        icon = s.render.resolution_x == s.render.resolution_y
        finish(path, (512, 512) if icon else (1920, 1080) if s.render.resolution_x >= 1920 else None)
    print("wrote", path)
