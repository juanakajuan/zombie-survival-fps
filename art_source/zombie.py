# Builds the cartoon Shambler zombie in the style of art_source/pistol.blend
# (beveled primitives, flat colors, an inverted-hull ink outline).
# Run from the project root: blender -b --factory-startup --python art_source/zombie.py [-- <preview.png>]
# It writes art_source/zombie.blend and zombie/zombie_model.glb, split into the parts in PARTS. With a path, it also renders
# <preview>_front.png and <preview>_side.png there.
# Blender is Z up. The zombie faces +Y, which the glTF exporter makes Godot -Z (forward).
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_source", "zombie.blend")
GLB = os.path.join(ROOT, "zombie", "zombie_model.glb")
RENDER = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""
INK_THICKNESS = 0.012


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name: str, rgb: tuple, rough: float = 0.75) -> bpy.types.Material:
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*rgb, 1.0)
    return m


def ink() -> bpy.types.Material:
    m = material("Ink", (0.01, 0.01, 0.01), 1.0)
    m.use_backface_culling = True
    return m


class Builder:
    def __init__(self, name: str) -> None:
        self.col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(self.col)
        self.root = bpy.data.objects.new(name, None)
        self.col.objects.link(self.root)

    def part(self, name: str, kind: str, loc: tuple, size: tuple, mat: bpy.types.Material,
             rot: tuple = (0, 0, 0), bevel: float = 0.03, outline: bool = True,
             segments: int = 12) -> bpy.types.Object:
        if kind == "box":
            bpy.ops.mesh.primitive_cube_add(size=1.0)
        elif kind == "ball":
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=segments, ring_count=max(6, segments // 2))
        elif kind == "cyl":
            bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1.0, vertices=segments)
        elif kind == "cone":
            bpy.ops.mesh.primitive_cone_add(radius1=0.5, radius2=0.0, depth=1.0, vertices=segments)
        else:
            raise ValueError(kind)
        o = bpy.context.active_object
        o.name = f"{self.root.name}_{name}"
        for c in o.users_collection:
            c.objects.unlink(o)
        self.col.objects.link(o)
        o.location = loc
        o.scale = size
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.data.materials.append(mat)
        if kind != "box":
            bpy.ops.object.shade_smooth()
        if kind == "box" and bevel > 0:
            b = o.modifiers.new("Bevel", "BEVEL")
            b.width = bevel
            b.segments = 2
        if outline:
            o.data.materials.append(ink())
            s = o.modifiers.new("Outline", "SOLIDIFY")
            s.thickness = INK_THICKNESS
            s.offset = 1.0
            s.use_flip_normals = True
            s.use_rim = False
            s.material_offset = 1
        o.parent = self.root
        return o

    def mirror(self, name: str, kind: str, loc: tuple, size: tuple, mat: bpy.types.Material,
               rot: tuple = (0, 0, 0), **kw) -> None:
        x, y, z = loc
        rx, ry, rz = rot
        self.part(name + "L", kind, (x, y, z), size, mat, (rx, ry, rz), **kw)
        self.part(name + "R", kind, (-x, y, z), size, mat, (rx, -ry, -rz), **kw)

    def limb(self, name: str, a: tuple, b: tuple, radius: float, mat: bpy.types.Material,
             kind: str = "cyl", **kw) -> bpy.types.Object:
        """A cylinder or box from point a to point b."""
        va, vb = Vector(a), Vector(b)
        d = vb - va
        o = self.part(name, kind, tuple((va + vb) / 2), (radius * 2, radius * 2, d.length), mat, **kw)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        return o

    def on_surface(self, name: str, center: tuple, radii: tuple, azimuth: float, elevation: float,
                   size: tuple, mat: bpy.types.Material, kind: str = "box", roll: float = 0.0,
                   **kw) -> bpy.types.Object:
        """A part on an ellipsoid's surface. Azimuth turns from +Y toward +X; the part's Y axis is the normal."""
        az, el = math.radians(azimuth), math.radians(elevation)
        d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
        point = Vector(center) + Vector((radii[0] * d.x, radii[1] * d.y, radii[2] * d.z))
        normal = Vector((d.x / radii[0], d.y / radii[1], d.z / radii[2])).normalized()
        o = self.part(name, kind, tuple(point), size, mat, bevel=0.0, **kw)
        o.rotation_euler = (Quaternion(normal, math.radians(roll)) @ normal.to_track_quat("Y", "Z")).to_euler()
        return o



def eyes(z: Builder, left: tuple, right: tuple, r_left: float, r_right: float) -> None:
    white = material("EyeWhite", (0.95, 0.93, 0.78), 0.3)
    pupil = material("Pupil", (0.02, 0.02, 0.02), 0.3)
    for side, pos, r in (("L", left, r_left), ("R", right, r_right)):
        z.part("Eye" + side, "ball", pos, (r * 2, r * 2, r * 2), white)
        # Pupils look in different directions for a dazed look.
        drift = Vector((r * 0.25 if side == "L" else -r * 0.15, 0, r * 0.15 if side == "L" else -r * 0.2))
        p = Vector(pos) + Vector((0, r * 0.82, 0)) + drift
        z.part("Pupil" + side, "ball", tuple(p), (r * 0.9, r * 0.45, r * 0.9), pupil, outline=False, segments=10)


def teeth(z: Builder, x0: float, x1: float, y: float, ztop: float, count: int, size: float,
          mat: bpy.types.Material, down: bool = True) -> None:
    for i in range(count):
        x = x0 + (x1 - x0) * i / max(1, count - 1)
        h = size * (1.0 if i % 2 == 0 else 0.7)
        z.part(f"Tooth{i}", "box", (x, y, ztop - h / 2 if down else ztop + h / 2),
               (size * 0.8, size * 0.5, h), mat, bevel=0.004, outline=False)


def build_shambler() -> Builder:
    """The classic: green skin, big lopsided head, torn shirt, hunched with arms out in front."""
    z = Builder("Shambler")
    skin = material("ShamblerSkin", (0.42, 0.68, 0.24))
    rot = material("ShamblerRot", (0.27, 0.46, 0.16))
    socket = material("ShamblerSocket", (0.2, 0.32, 0.12), 0.9)
    shirt = material("ShamblerShirt", (0.85, 0.42, 0.12))
    shirt_dark = material("ShamblerShirtDark", (0.55, 0.24, 0.07))
    pants = material("ShamblerPants", (0.12, 0.2, 0.42))
    shoe = material("Shoe", (0.18, 0.1, 0.06))
    dark = material("Mouth", (0.15, 0.02, 0.04), 0.9)
    tooth = material("Tooth", (0.96, 0.92, 0.7), 0.4)
    bone = material("Bone", (0.92, 0.88, 0.76), 0.6)
    stitch = material("Stitch", (0.08, 0.05, 0.04), 0.9)

    # Legs in a shuffling stance: the left foot forward, the right foot back, knees bent.
    z.limb("ThighL", (0.12, 0.0, 0.82), (0.13, 0.1, 0.44), 0.095, pants, kind="box")
    z.limb("ShinL", (0.13, 0.1, 0.44), (0.13, 0.08, 0.1), 0.085, pants, kind="box")
    z.limb("ThighR", (-0.12, 0.0, 0.82), (-0.13, -0.02, 0.44), 0.095, pants, kind="box")
    z.part("CuffR", "box", (-0.13, -0.04, 0.4), (0.2, 0.2, 0.06), pants, bevel=0.01)
    for i, x in enumerate((-0.2, -0.13, -0.06)):
        z.part(f"RagR{i}", "cone", (x, 0.04, 0.35), (0.05, 0.03, 0.07), pants, rot=(180, 0, i * 10 - 10), segments=4, outline=False)
    z.limb("ShinR", (-0.13, -0.04, 0.42), (-0.14, -0.12, 0.1), 0.055, skin)
    z.part("ShoeL", "box", (0.13, 0.13, 0.06), (0.2, 0.32, 0.12), shoe, bevel=0.04)
    z.part("ShoeR", "box", (-0.14, -0.07, 0.06), (0.2, 0.3, 0.12), shoe, rot=(0, 0, -8), bevel=0.04)
    z.part("Belt", "box", (0, 0.0, 0.83), (0.46, 0.27, 0.08), shoe)

    # Torso leans forward; the shirt is torn at the hem and has a hole over the ribs.
    z.part("Torso", "box", (0, 0.06, 1.08), (0.5, 0.3, 0.55), shirt, rot=(-12, 0, 4), bevel=0.06)
    for i, x in enumerate((-0.19, -0.1, 0.0, 0.09, 0.18)):
        z.part(f"Hem{i}", "cone", (x, 0.1, 0.79), (0.08, 0.04, 0.07 + 0.03 * (i % 2)), shirt, rot=(180, 0, 0), segments=4, outline=False)
    z.part("Hole", "box", (0.11, 0.19, 1.0), (0.16, 0.03, 0.13), socket, rot=(-12, 0, 4), bevel=0.02, outline=False)
    for i in range(2):
        z.part(f"Rib{i}", "box", (0.11, 0.205, 0.98 + i * 0.05), (0.13, 0.02, 0.022), bone, rot=(-12, 0, 4), bevel=0.005, outline=False)
    z.part("Collar", "cyl", (0, 0.12, 1.35), (0.24, 0.2, 0.05), shirt_dark, rot=(-12, 0, 0))
    z.part("Patch", "box", (-0.13, 0.2, 1.17), (0.11, 0.02, 0.09), pants, rot=(-12, 0, 15), bevel=0.0)
    for i in range(3):
        z.part(f"PatchStitch{i}", "box", (-0.17 + i * 0.04, 0.215, 1.22 - i * 0.01), (0.008, 0.01, 0.03), stitch, rot=(-12, 0, 15), bevel=0.0, outline=False)

    # The head pokes forward of the shoulders.
    head_c, head_r = (0.02, 0.18, 1.57), (0.23, 0.21, 0.22)
    z.part("Head", "ball", head_c, tuple(r * 2 for r in head_r), skin, segments=16)
    z.on_surface("SocketL", head_c, head_r, 28, 14, (0.2, 0.03, 0.19), socket, kind="ball")
    z.on_surface("SocketR", head_c, head_r, -27, 6, (0.12, 0.03, 0.11), socket, kind="ball")
    eyes(z, (0.1, 0.35, 1.63), (-0.1, 0.36, 1.6), 0.08, 0.045)
    z.part("LidR", "ball", (-0.1, 0.365, 1.618), (0.105, 0.1, 0.06), skin, rot=(0, 0, -12))
    z.part("BrowL", "box", (0.11, 0.37, 1.74), (0.13, 0.04, 0.03), stitch, rot=(0, 0, 14), bevel=0.01, outline=False)
    z.part("Nose", "ball", (0.0, 0.39, 1.55), (0.06, 0.06, 0.05), rot, segments=8)
    z.part("Mouth", "box", (0.0, 0.36, 1.46), (0.21, 0.06, 0.075), dark, rot=(0, -6, 0), bevel=0.02)
    teeth(z, -0.07, 0.07, 0.385, 1.495, 3, 0.04, tooth)
    z.on_surface("EarL", head_c, head_r, 88, 2, (0.07, 0.1, 0.12), skin, kind="ball")
    z.on_surface("EarR", head_c, head_r, -88, 0, (0.06, 0.08, 0.08), rot, kind="ball")
    # A stitched scar across the right side of the scalp.
    z.on_surface("Scar", head_c, head_r, -40, 40, (0.2, 0.012, 0.014), stitch, roll=-25, outline=False)
    for i in range(4):
        z.on_surface(f"ScarStitch{i}", head_c, head_r, -55 + i * 10, 33 + i * 4.5, (0.01, 0.014, 0.06), stitch, roll=-25, outline=False)
    z.on_surface("RotHead", head_c, head_r, 60, 45, (0.1, 0.02, 0.08), rot, kind="ball", outline=False)
    for i, (x, rz) in enumerate(((-0.06, -15), (0.01, 5), (0.08, 20))):
        z.part(f"Hair{i}", "cone", (x + 0.02, 0.12, 1.8), (0.06, 0.06, 0.12), stitch, rot=(rz * 0.5 - 15, rz, 0), segments=6)

    # The left arm reaches out; the right sleeve is torn off and that arm droops, bone showing at the elbow.
    z.limb("UpperArmL", (0.29, 0.1, 1.27), (0.33, 0.36, 1.33), 0.075, shirt)
    z.limb("ForeArmL", (0.33, 0.36, 1.33), (0.34, 0.56, 1.37), 0.06, skin)
    z.part("RotArmL", "ball", (0.37, 0.46, 1.36), (0.04, 0.09, 0.06), rot, outline=False)
    z.part("SleeveR", "cyl", (-0.3, 0.1, 1.27), (0.17, 0.17, 0.12), shirt, rot=(90, 0, 0))
    for i in range(3):
        z.part(f"SleeveRag{i}", "cone", (-0.36 + i * 0.06, 0.17, 1.2), (0.04, 0.03, 0.06), shirt, rot=(150, 0, 0), segments=4, outline=False)
    z.limb("UpperArmR", (-0.3, 0.12, 1.27), (-0.31, 0.32, 1.18), 0.058, skin)
    z.part("ElbowBone", "ball", (-0.31, 0.32, 1.17), (0.07, 0.07, 0.07), bone, segments=8)
    z.limb("ForeArmR", (-0.31, 0.32, 1.18), (-0.29, 0.52, 1.1), 0.055, skin)
    for side, wrist, down in (("L", (0.34, 0.58, 1.37), -4), ("R", (-0.29, 0.54, 1.09), -18)):
        x, y, h = wrist
        z.part("Palm" + side, "box", (x, y + 0.04, h), (0.12, 0.11, 0.05), skin, rot=(down, 0, 0), bevel=0.02)
        for i in range(3):
            fx = x - 0.038 + i * 0.038
            z.limb(f"Finger{side}{i}", (fx, y + 0.08, h), (fx, y + 0.16 - 0.015 * (i % 2), h - 0.03 + down * 0.002), 0.022, skin)
    return z


# The posable parts that the Godot animator moves, each with its pivot (Blender coordinates).
# A part takes every piece whose name starts with one of its prefixes; the Torso takes the rest.
# Head, ArmL, and ArmR are children of the Torso, so they follow its bob and sway.
PARTS = {
    "LegL": ((0.12, 0.0, 0.82), ("ThighL", "ShinL", "ShoeL")),
    "LegR": ((-0.12, 0.0, 0.82), ("ThighR", "CuffR", "RagR", "ShinR", "ShoeR")),
    "ArmL": ((0.29, 0.1, 1.27), ("UpperArmL", "ForeArmL", "RotArmL", "PalmL", "FingerL")),
    "ArmR": ((-0.3, 0.1, 1.27), ("SleeveR", "UpperArmR", "ElbowBone", "ForeArmR", "PalmR", "FingerR")),
    "Head": ((0.02, 0.1, 1.38), ("Head", "Socket", "Eye", "Pupil", "Lid", "Brow", "Nose", "Mouth", "Tooth", "Ear",
                                  "Scar", "Hair", "RotHead")),
    "Torso": ((0.0, 0.0, 0.82), ()),
}
TORSO_CHILDREN = ("Head", "ArmL", "ArmR")


def assemble(b: Builder) -> bpy.types.Object:
    """Applies every modifier and joins the pieces into the parts in PARTS, each with its origin on its pivot."""
    groups: dict = {name: [] for name in PARTS}
    for o in b.root.children:
        piece = o.name.removeprefix(b.root.name + "_")
        part = next((n for n, (_, prefixes) in PARTS.items() if piece.startswith(prefixes)), "Torso")
        groups[part].append(o)
    joined: dict = {}
    for name, pieces in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in pieces:
            o.select_set(True)
        bpy.context.view_layer.objects.active = pieces[0]
        bpy.ops.object.convert(target="MESH")
        bpy.ops.object.join()
        mesh = bpy.context.active_object
        mesh.name = name
        mesh.data.name = name
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.context.scene.cursor.location = PARTS[name][0]
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        joined[name] = mesh
    for name in TORSO_CHILDREN:
        child = joined[name]
        world = child.matrix_world.copy()
        child.parent = joined["Torso"]
        child.matrix_world = world
    return b.root


def export_glb(root: bpy.types.Object, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in root.children_recursive:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)


def preview_render(path: str) -> None:
    """Renders a three-quarter front view and a side view next to the .blend, to check the model."""
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.data.materials.append(material("Ground", (0.32, 0.34, 0.36), 0.9))
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 40
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.5
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(150))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.62, 0.7, 1.0)
    bg.inputs["Strength"].default_value = 0.8
    scene.world = world
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else engines[0]
    scene.render.resolution_x = 640
    scene.render.resolution_y = 720
    scene.view_settings.view_transform = "Standard"
    target = Vector((0, 0, 1.0))
    for view, offset in (("front", (1.2, 2.6, 0.6)), ("side", (2.9, 0.0, 0.4))):
        cam.location = target + Vector(offset)
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = path.replace(".png", f"_{view}.png")
        bpy.ops.render.render(write_still=True)


def main() -> None:
    reset()
    export_glb(assemble(build_shambler()), GLB)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    if RENDER:
        preview_render(RENDER)


main()
