"""Generates the zombie model: game/zombie/zombie.glb and game/zombie/zombie_albedo.png.

Usage: blender -b --python tools/zombie_model.py

A high-poly body is painted per vertex. Its colors are baked to a 128 px texture on a
low-poly copy of about 800 triangles. The glb has UVs and no materials. The game
material (game/zombie/zombie_material.tres) supplies the texture.
The model faces +Y in Blender, which is -Z in Godot.
"""
import bpy, json, math, os, struct
from mathutils import Vector, noise

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "zombie")
TEXTURE_SIZE = 128
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return Vector([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])


# Walker skeleton. Z up, front +Y. (position, radius)
J = {
    "pelvis": ((0, 0, 0.95), 0.15), "spine": ((0, 0.04, 1.15), 0.15), "chest": ((0, 0.11, 1.34), 0.18),
    "neck": ((0.01, 0.2, 1.5), 0.06), "neck2": ((0.015, 0.245, 1.565), 0.055),
    "shL": ((-0.21, 0.12, 1.4), 0.07), "elL": ((-0.27, 0.38, 1.33), 0.045), "wrL": ((-0.24, 0.62, 1.36), 0.035),
    "hL": ((-0.23, 0.7, 1.35), 0.04),
    "f1L": ((-0.27, 0.79, 1.32), 0.014), "f2L": ((-0.23, 0.81, 1.33), 0.014), "f3L": ((-0.19, 0.79, 1.32), 0.013),
    "shR": ((0.21, 0.1, 1.39), 0.07), "elR": ((0.29, 0.13, 1.1), 0.045), "wrR": ((0.31, 0.25, 0.88), 0.035),
    "hR": ((0.31, 0.3, 0.81), 0.04),
    "f1R": ((0.29, 0.36, 0.73), 0.013), "f2R": ((0.32, 0.37, 0.74), 0.013), "f3R": ((0.35, 0.33, 0.75), 0.012),
    "hipL": ((-0.1, 0, 0.88), 0.09), "knL": ((-0.12, 0.06, 0.5), 0.06), "anL": ((-0.12, 0.0, 0.1), 0.045),
    "toL": ((-0.12, 0.17, 0.04), 0.045),
    "hipR": ((0.1, 0, 0.88), 0.09), "knR": ((0.14, 0.15, 0.52), 0.06), "anR": ((0.15, 0.0, 0.1), 0.045),
    "toR": ((0.15, 0.16, 0.04), 0.045),
}
E = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck"), ("neck", "neck2"),
     ("chest", "shL"), ("shL", "elL"), ("elL", "wrL"), ("wrL", "hL"), ("hL", "f1L"), ("hL", "f2L"), ("hL", "f3L"),
     ("chest", "shR"), ("shR", "elR"), ("elR", "wrR"), ("wrR", "hR"), ("hR", "f1R"), ("hR", "f2R"), ("hR", "f3R"),
     ("pelvis", "hipL"), ("hipL", "knL"), ("knL", "anL"), ("anL", "toL"),
     ("pelvis", "hipR"), ("hipR", "knR"), ("knR", "anR"), ("anR", "toR")]
HEAD = Vector((0.02, 0.27, 1.62))
MOUTH = HEAD + Vector((0, 0.1, -0.065))
WOUND = Vector((0.06, 0.22, 1.16))


def head_shape(d):
    """Unit-sphere point -> skull point (metres, before HEAD offset)."""
    x, y, z = d
    g = lambda u, w: math.exp(-u * u / w)
    front = max(y, 0.0)
    if y < 0:
        y *= 1.15
    if z < -0.1:
        y += 0.4 * (-z - 0.1)
        x *= 1 - 0.35 * (-z - 0.1)
    x *= 1 + 0.1 * g(z + 0.05, 0.03)
    y += 0.12 * g(z - 0.38, 0.012) * front
    y -= 0.2 * g(abs(x) - 0.36, 0.02) * g(z - 0.16, 0.02) * front
    y += 0.14 * g(x, 0.006) * g(z + 0.08, 0.01) * front
    y -= 0.35 * g(x, 0.05) * g(z + 0.5, 0.012) * front
    return Vector((x * 0.095, y * 0.112, z * 0.13))


EYE_DIRS = [Vector((s * 0.36, 0.0, 0.16)) for s in (-1, 1)]
for e in EYE_DIRS:
    e.y = math.sqrt(1 - e.x ** 2 - e.z ** 2)
EYES = [head_shape(e) + HEAD - Vector((0, 0.002, 0)) for e in EYE_DIRS]


def sculpt_head(subdiv):
    seg = (12, 10) if subdiv == 0 else (16, 12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg[0], ring_count=seg[1], radius=1)
    h = bpy.context.object
    for v in h.data.vertices:
        v.co = head_shape(v.co.normalized()) + HEAD
    return h


def skin_body(name, subdiv, displace):
    names = list(J)
    me = bpy.data.meshes.new(name)
    me.from_pydata([J[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in E], [])
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    sk = o.modifiers.new("skin", "SKIN")
    sk.branch_smoothing = 0.5
    sk.use_smooth_shade = True
    for i, n in enumerate(names):
        r = J[n][1]
        o.data.skin_vertices[0].data[i].radius = (r, r * (0.8 if n in ("chest", "spine", "pelvis") else 1.0))
    o.data.skin_vertices[0].data[0].use_root = True
    if subdiv:
        s = o.modifiers.new("sub", "SUBSURF")
        s.levels = s.render_levels = subdiv
    if displace:
        for tex_type, size, strength in (("CLOUDS", 0.05, 0.012), ("VORONOI", 0.02, -0.006)):
            t = bpy.data.textures.new(name + tex_type, tex_type)
            t.noise_scale = size
            d = o.modifiers.new("d" + tex_type, "DISPLACE")
            d.texture = t
            d.texture_coords = "OBJECT"
            d.strength = strength
            d.mid_level = 0.5
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers)[:2 if subdiv else 1]:
        bpy.ops.object.modifier_apply(modifier=m.name)
    head = sculpt_head(subdiv)
    if subdiv:
        hs = head.modifiers.new("sub", "SUBSURF")
        hs.levels = subdiv
        bpy.context.view_layer.objects.active = head
        bpy.ops.object.modifier_apply(modifier="sub")
    bpy.ops.object.select_all(action="DESELECT")
    head.select_set(True)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def fbm(p, s):
    return noise.noise(p * s) * 0.5 + noise.noise(p * s * 2.3) * 0.25 + noise.noise(p * s * 5.1) * 0.125


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


SKIN_A, SKIN_B, SKIN_V = srgb("8d9a80"), srgb("857080"), srgb("4f6a63")
SHIRT, PANTS = srgb("c4c0b0"), srgb("2f3b4f")
BLOOD, GORE, DIRT = srgb("4a0a0a"), srgb("6b1a16"), srgb("3b3226")


def albedo(p, n):
    """Paint one surface point. p = position, n = normal."""
    x, y, z = p
    c = lerp(SKIN_A, SKIN_B, smooth(-0.2, 0.4, fbm(p, 4)))
    c = lerp(c, SKIN_V, 0.5 * smooth(0.82, 0.95, abs(noise.noise(p * Vector((9, 9, 3))))))  # veins
    c *= 0.82 + 0.18 * (fbm(p, 30) + 0.5)
    rag = 0.04 * fbm(p, 18)
    in_torso = abs(x) < 0.2 + rag and 0.96 + rag < z < 1.47 and y < 0.25
    sleeve = z > 1.3 + rag * 2 and abs(x) < 0.32 and y < 0.3
    if in_torso or sleeve:
        c = SHIRT * (0.75 + 0.3 * (fbm(p, 12) + 0.5))
        c = lerp(c, DIRT, 0.5 * smooth(0.0, 0.4, fbm(p * Vector((1, 1, 3)), 6)))
        c = lerp(c, BLOOD, 0.7 * smooth(0.15, 0.35, fbm(p + Vector((5, 0, 0)), 9)))
        if fbm(p + Vector((9, 9, 9)), 7) > 0.22:
            c = lerp(SKIN_A, SKIN_B, 0.5) * 0.8
    leg_end = 0.14 if x < 0 else 0.48 + rag * 3
    if 0.2 < z < 1.0 + rag and leg_end < z:
        weave = 0.9 + 0.1 * math.sin(z * 900) * math.sin(x * 900)
        c = PANTS * weave * (0.8 + 0.3 * (fbm(p, 10) + 0.5))
    if z < 0.12:
        c = lerp(c, DIRT, 0.6)
    # blood running from the mouth down the chest, and a torn belly
    drip = smooth(0.1, 0.35, fbm(p * Vector((4, 4, 0.6)), 8)) * smooth(0.25, 0.0, abs(x - 0.02)) * smooth(1.05, 1.3, z)
    c = lerp(c, BLOOD, 0.85 * drip * (1 if n.y > -0.2 else 0))
    w = (p - WOUND).length + 0.03 * fbm(p, 20)
    c = lerp(c, lerp(GORE, BLOOD, fbm(p, 40) + 0.5), smooth(0.11, 0.07, w))
    m = (p - MOUTH).length + 0.01 * fbm(p, 50)
    teeth = 0.5 + 0.5 * math.sin((x - MOUTH.x) * 260)
    c = lerp(c, srgb("b8ad86") * (0.6 + 0.4 * teeth), smooth(0.05, 0.04, m))
    c = lerp(c, srgb("1a0505"), smooth(0.04, 0.025, m))
    for e in EYES:
        c = lerp(c, srgb("3a1a1e"), 0.8 * smooth(0.04, 0.018, (p - e).length))
    c *= 0.65 + 0.35 * smooth(-0.6, 0.6, n.z + n.y * 0.3)  # painted cavity / ambient darkening
    return c


def paint(o):
    me = o.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for v in me.vertices:
        c = albedo(v.co, v.normal)
        attr.data[v.index].color = (c.x, c.y, c.z, 1)


def vc_material(o):
    m = bpy.data.materials.new(o.name + "_vc")
    m.use_nodes = True
    nt = m.node_tree
    a = nt.nodes.new("ShaderNodeVertexColor")
    a.layer_name = "Col"
    nt.links.new(a.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    o.data.materials.append(m)


def bake(high, low):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    m = bpy.data.materials.new(low.name + "_mat")
    m.use_nodes = True
    low.data.materials.append(m)
    img = bpy.data.images.new("zombie_albedo", TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    node = m.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    node.interpolation = "Closest"
    m.node_tree.nodes.active = node
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.04
    scene.render.bake.max_ray_distance = 0.1
    scene.render.bake.margin = 4
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    img.filepath_raw = os.path.join(OUT, "zombie_albedo.png")
    img.file_format = "PNG"
    img.save()
    high.select_set(False)


high = skin_body("High", 3, True)
paint(high)
vc_material(high)
zombie = skin_body("Zombie", 0, False)
bake(high, zombie)
bpy.data.objects.remove(high)

bpy.ops.object.select_all(action="DESELECT")
zombie.select_set(True)
bpy.context.view_layer.objects.active = zombie
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT, "zombie.glb"),
    use_selection=True,
    export_materials="NONE",
    export_image_format="NONE",
)


def sort_triangles(path):
    """The exporter writes the same triangles in a different order on each run. Sort them so the file is stable."""
    with open(path, "rb") as f:
        data = bytearray(f.read())
    json_length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + json_length])
    bin_start = 20 + json_length + 8
    view = gltf["bufferViews"][gltf["accessors"][gltf["meshes"][0]["primitives"][0]["indices"]]["bufferView"]]
    first, count = bin_start + view.get("byteOffset", 0), view["byteLength"] // 2
    indices = struct.unpack_from("<%dH" % count, data, first)
    triangles = []
    for i in range(0, count, 3):
        t = list(indices[i:i + 3])
        k = t.index(min(t))
        triangles.append(tuple(t[k:] + t[:k]))
    struct.pack_into("<%dH" % count, data, first, *[i for t in sorted(triangles) for i in t])
    with open(path, "wb") as f:
        f.write(data)


sort_triangles(os.path.join(OUT, "zombie.glb"))
