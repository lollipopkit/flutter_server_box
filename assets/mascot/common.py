"""Shared Blender 5.2 procedural modeling, expression/pose system, material,
studio lighting, rendering, and Draco-compressed glTF export helpers for
ServerBox 3D mascots (`fox`, `cat`, `pig`).

Supported poses/states:
    idle, working, confused, happy, crying
"""

from __future__ import annotations

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

POSES = ("idle", "working", "confused", "happy", "crying")


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    h = h.lstrip("#")
    r = srgb_to_linear(int(h[0:2], 16) / 255.0)
    g = srgb_to_linear(int(h[2:4], 16) / 255.0)
    b = srgb_to_linear(int(h[4:6], 16) / 255.0)
    return (r, g, b, alpha)


def make_material(
    name: str,
    hex_color: str,
    *,
    roughness: float = 0.55,
    metallic: float = 0.0,
    subsurface: float = 0.12,
    coat: float = 0.06,
    coat_roughness: float = 0.25,
    emission_hex: str | None = None,
    emission_strength: float = 0.0,
    transmission: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = hex_rgba(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = subsurface
    if "Subsurface Scale" in bsdf.inputs:
        bsdf.inputs["Subsurface Scale"].default_value = 0.03
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if "Coat Roughness" in bsdf.inputs:
        bsdf.inputs["Coat Roughness"].default_value = coat_roughness
    if "Transmission Weight" in bsdf.inputs and transmission > 0.0:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if emission_hex and emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value = hex_rgba(emission_hex)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def base_materials() -> dict[str, bpy.types.Material]:
    return {
        "eye_dark": make_material("EyeDark", "#121216", roughness=0.05, subsurface=0.0, coat=1.0, coat_roughness=0.02),
        "eye_white": make_material(
            "EyeCatchlight", "#FFFFFF", roughness=0.05, subsurface=0.0, emission_hex="#FFFFFF", emission_strength=0.65
        ),
        "blush": make_material("Blush", "#F28B82", roughness=0.65, subsurface=0.25, coat=0.0),
        "blush_happy": make_material("BlushHappy", "#F26E6E", roughness=0.62, subsurface=0.28, coat=0.0),
        "mouth_inner": make_material("MouthInner", "#D96672", roughness=0.45, subsurface=0.15, coat=0.1),
        "tear": make_material(
            "TearBlue",
            "#7FD4FF",
            roughness=0.04,
            subsurface=0.10,
            coat=1.0,
            coat_roughness=0.02,
            transmission=0.55,
            emission_hex="#6CC8FF",
            emission_strength=0.45,
        ),
        "sparkle_gold": make_material(
            "SparkleGold",
            "#FFD24C",
            roughness=0.18,
            metallic=0.2,
            subsurface=0.0,
            coat=0.6,
            emission_hex="#FFD24C",
            emission_strength=2.2,
        ),
        "question_yellow": make_material(
            "QuestionYellow",
            "#FCC153",
            roughness=0.22,
            subsurface=0.0,
            coat=0.5,
            emission_hex="#FCC153",
            emission_strength=2.0,
        ),
        "holo_deck": make_material(
            "HoloDeck", "#1D2633", roughness=0.18, metallic=0.30, subsurface=0.0, coat=0.8, coat_roughness=0.08
        ),
        "holo_screen": make_material(
            "HoloScreen", "#0E1A26", roughness=0.06, metallic=0.10, subsurface=0.0, coat=1.0, coat_roughness=0.02
        ),
        "holo_cyan": make_material(
            "HoloCyan", "#5CE1FF", roughness=0.18, subsurface=0.0, emission_hex="#5CE1FF", emission_strength=3.6
        ),
        "strap": make_material("StrapCharcoal", "#444850", roughness=0.50, subsurface=0.03, coat=0.08),
        "buckle_blue": make_material("BuckleBlue", "#56AEE0", roughness=0.32, metallic=0.15, subsurface=0.0, coat=0.35),
        "buckle_red": make_material("BuckleRed", "#EC6B5E", roughness=0.32, metallic=0.15, subsurface=0.0, coat=0.35),
        "server_body": make_material(
            "ServerBody", "#5D6169", roughness=0.38, metallic=0.14, subsurface=0.0, coat=0.22, coat_roughness=0.2
        ),
        "server_core": make_material("ServerCore", "#3B3E45", roughness=0.45, metallic=0.20, subsurface=0.0, coat=0.12),
        "server_bezel": make_material("ServerBezel", "#2B2E34", roughness=0.35, metallic=0.25, subsurface=0.0, coat=0.15),
        "goggle_frame": make_material(
            "GoggleFrame", "#4E535C", roughness=0.34, metallic=0.18, subsurface=0.0, coat=0.28, coat_roughness=0.18
        ),
        "goggle_hinge": make_material("GoggleHinge", "#9BA3AF", roughness=0.25, metallic=0.65, subsurface=0.0, coat=0.2),
        "visor_glass": make_material(
            "VisorGlass", "#0F171F", roughness=0.06, metallic=0.05, subsurface=0.0, coat=1.0, coat_roughness=0.02
        ),
        "led_red": make_material(
            "LedRed", "#EC6B5E", roughness=0.22, subsurface=0.0, coat=0.4, emission_hex="#EC6B5E", emission_strength=2.8
        ),
        "led_green": make_material(
            "LedGreen", "#82C352", roughness=0.22, subsurface=0.0, coat=0.4, emission_hex="#82C352", emission_strength=3.2
        ),
        "led_yellow": make_material(
            "LedYellow", "#FCC153", roughness=0.22, subsurface=0.0, coat=0.4, emission_hex="#FCC153", emission_strength=2.8
        ),
        "led_blue": make_material(
            "LedBlue", "#56AEE0", roughness=0.22, subsurface=0.0, coat=0.4, emission_hex="#56AEE0", emission_strength=3.0
        ),
        "prompt_green": make_material(
            "PromptGreen", "#8BE05A", roughness=0.18, subsurface=0.0, emission_hex="#8BE05A", emission_strength=5.0
        ),
        "prompt_yellow": make_material(
            "PromptYellow", "#FFD25A", roughness=0.18, subsurface=0.0, emission_hex="#FFD25A", emission_strength=5.0
        ),
        "prompt_red": make_material(
            "PromptRed", "#FF6B63", roughness=0.18, subsurface=0.0, emission_hex="#FF6B63", emission_strength=5.0
        ),
        "pedestal": make_material("Pedestal", "#E3E6EC", roughness=0.52, subsurface=0.05, coat=0.12),
        "pedestal_ring": make_material("PedestalRing", "#5D6169", roughness=0.40, metallic=0.12, subsurface=0.0),
        "backdrop": make_material("Backdrop", "#F2F4F8", roughness=0.92, subsurface=0.0, coat=0.0),
    }


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def get_or_create_collection(name: str) -> bpy.types.Collection:
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def link_obj(obj: bpy.types.Object, col: bpy.types.Collection) -> bpy.types.Object:
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def set_smooth(obj: bpy.types.Object) -> None:
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True


def assign_mat(obj: bpy.types.Object, mat: bpy.types.Material) -> None:
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def add_subsurf(obj: bpy.types.Object, levels: int = 1) -> None:
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels


def create_empty(
    name: str,
    col: bpy.types.Collection,
    *,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.location = loc
    obj.rotation_euler = rot
    if parent is not None:
        obj.parent = parent
    link_obj(obj, col)
    return obj


def create_sphere(
    name: str,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    *,
    loc=(0.0, 0.0, 0.0),
    scale=(1.0, 1.0, 1.0),
    rot=(0.0, 0.0, 0.0),
    segments: int = 36,
    rings: int = 24,
    subsurf: int = 1,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.scale = scale
    obj.rotation_euler = rot
    if parent is not None:
        obj.parent = parent
    link_obj(obj, col)
    assign_mat(obj, mat)
    set_smooth(obj)
    if subsurf > 0:
        add_subsurf(obj, subsurf)
    return obj


def create_rounded_box(
    name: str,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    *,
    size=(1.0, 1.0, 1.0),
    bevel: float = 0.08,
    bevel_segments: int = 5,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.bevel(
        bm,
        geom=list(bm.edges),
        offset=bevel,
        offset_type="OFFSET",
        segments=bevel_segments,
        profile=0.5,
        affect="EDGES",
        clamp_overlap=True,
    )
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.rotation_euler = rot
    if parent is not None:
        obj.parent = parent
    link_obj(obj, col)
    assign_mat(obj, mat)
    set_smooth(obj)
    return obj


def create_cylinder(
    name: str,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    *,
    radius: float = 0.1,
    depth: float = 0.2,
    vertices: int = 36,
    bevel: float = 0.0,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    scale=(1.0, 1.0, 1.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=vertices,
        radius1=radius,
        radius2=radius,
        depth=depth,
    )
    if bevel > 0:
        cap_edges = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-4]
        bmesh.ops.bevel(
            bm,
            geom=cap_edges,
            offset=bevel,
            offset_type="OFFSET",
            segments=4,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.rotation_euler = rot
    obj.scale = scale
    if parent is not None:
        obj.parent = parent
    link_obj(obj, col)
    assign_mat(obj, mat)
    set_smooth(obj)
    return obj


def create_capsule(
    name: str,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    *,
    radius: float,
    length: float,
    loc=(0.0, 0.0, 0.0),
    rot=(0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=radius)
    half = length * 0.5
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z += half
        elif v.co.z < 0:
            v.co.z -= half
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.rotation_euler = rot
    if parent is not None:
        obj.parent = parent
    link_obj(obj, col)
    assign_mat(obj, mat)
    set_smooth(obj)
    return obj


def create_tube_curve(
    name: str,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    points: list[tuple[float, float, float, float]],
    *,
    bevel_depth: float = 0.05,
    resolution_u: int = 24,
    bevel_res: int = 8,
    cyclic: bool = False,
    fill_caps: bool = True,
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name=name, type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution_u
    curve.bevel_depth = bevel_depth
    curve.bevel_resolution = bevel_res
    curve.use_fill_caps = fill_caps

    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for i, (x, y, z, rad) in enumerate(points):
        spline.points[i].co = (x, y, z, 1.0)
        spline.points[i].radius = rad
    spline.use_cyclic_u = cyclic
    spline.use_endpoint_u = not cyclic
    spline.order_u = min(4, len(points))

    obj = bpy.data.objects.new(name, curve)
    if parent is not None:
        obj.parent = parent
    link_obj(obj, col)
    assign_mat(obj, mat)
    return obj


# ---------------------------------------------------------------------------
# Pose / Expression System
# ---------------------------------------------------------------------------

def head_pose_rot(pose: str) -> tuple[float, float, float]:
    """Euler rotation (X pitch, Y roll, Z yaw) for the head pivot in each state.
    Remember: -Y is front, so +X pitches head DOWN, -X tilts head UP, +Y tilts head right-ear-down.
    """
    return {
        "idle": (0.0, 0.0, 0.0),
        "working": (math.radians(9), 0.0, 0.0),
        "confused": (math.radians(-4), math.radians(-14), math.radians(-5)),
        "happy": (math.radians(-8), math.radians(4), 0.0),
        "crying": (math.radians(11), math.radians(5), 0.0),
    }[pose]


def arm_pose_points(pose: str, shoulder_x: float = 0.31) -> tuple[list[tuple[float, float, float, float]], list[tuple[float, float, float, float]]]:
    """Returns `(left_arm_pts, right_arm_pts)` in world coords (`+X` is mascot's left, `-X` is mascot's right)."""
    sx = shoulder_x
    if pose == "idle":
        left = [(sx, 0.02, 0.86, 1.02), (sx + 0.15, -0.05, 0.70, 0.98), (sx + 0.13, -0.16, 0.54, 0.92)]
        right = [(-sx, 0.02, 0.86, 1.02), (-sx - 0.18, -0.08, 0.89, 0.96), (-sx - 0.29, -0.19, 1.04, 0.94)]
    elif pose == "working":
        # Both arms forward typing on the floating mini terminal deck!
        left = [(sx, 0.02, 0.84, 1.02), (sx + 0.12, -0.24, 0.72, 0.96), (0.19, -0.54, 0.70, 0.92)]
        right = [(-sx, 0.02, 0.84, 1.02), (-sx - 0.12, -0.24, 0.72, 0.96), (-0.19, -0.54, 0.70, 0.92)]
    elif pose == "confused":
        # Left arm relaxed, right arm raised scratching near cheek/temple!
        left = [(sx, 0.02, 0.85, 1.02), (sx + 0.16, -0.04, 0.68, 0.96), (sx + 0.14, -0.14, 0.52, 0.92)]
        right = [(-sx, 0.02, 0.86, 1.02), (-sx - 0.22, -0.16, 0.96, 0.95), (-0.42, -0.36, 1.24, 0.90)]
    elif pose == "happy":
        # Both arms cheering high in the air!
        left = [(sx, 0.02, 0.87, 1.02), (sx + 0.20, -0.08, 1.02, 0.96), (sx + 0.28, -0.16, 1.24, 0.93)]
        right = [(-sx, 0.02, 0.87, 1.02), (-sx - 0.20, -0.08, 1.02, 0.96), (-sx - 0.28, -0.16, 1.24, 0.93)]
    else:  # crying
        # Both paws raised near lower cheeks/eyes rubbing tears!
        left = [(sx, 0.02, 0.84, 1.00), (sx + 0.16, -0.20, 0.92, 0.94), (0.31, -0.44, 1.13, 0.90)]
        right = [(-sx, 0.02, 0.84, 1.00), (-sx - 0.16, -0.20, 0.92, 0.94), (-0.31, -0.44, 1.13, 0.90)]
    return left, right


def create_expression_eyes(
    pose: str,
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    *,
    parent: bpy.types.Object,
    eye_x: float = 0.24,
    eye_y: float = -0.50,
    eye_z: float = 0.02,
    brow_mat: bpy.types.Material | None = None,
    blush_x: float = 0.37,
    blush_y: float = -0.46,
    blush_z: float = -0.11,
    tear_y_offset: float = 0.0,
) -> None:
    """Creates pose-specific eyes, eyebrows, blush, and tears in head-pivot local space."""
    blush_mat = mats["blush_happy"] if pose == "happy" else mats["blush"]
    b_mat = brow_mat or mats["eye_dark"]

    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        ex, ey, ez = side * eye_x, eye_y, eye_z

        if pose == "happy":
            # Joyful arched crescent eyes (`^ ^`)
            create_tube_curve(
                f"HappyEye_{tag}",
                col,
                mats["eye_dark"],
                [
                    (ex - 0.085, ey - 0.015, ez - 0.025, 0.9),
                    (ex, ey - 0.045, ez + 0.055, 1.15),
                    (ex + 0.085, ey - 0.015, ez - 0.025, 0.9),
                ],
                bevel_depth=0.022,
                resolution_u=16,
                bevel_res=6,
                parent=parent,
            )
        else:
            # Open glossy eyes (slightly asymmetric scale when confused, watery when crying)
            sx = 0.095
            sz = 0.105
            if pose == "confused" and side < 0:
                sx, sz = 0.080, 0.084
            elif pose == "working":
                sz = 0.092
            elif pose == "crying":
                sz = 0.096

            create_sphere(
                f"Eye_{tag}",
                col,
                mats["eye_dark"],
                loc=(ex, ey, ez),
                scale=(sx, 0.085, sz),
                rot=(0.0, 0.0, math.radians(-side * 10)),
                parent=parent,
            )
            create_sphere(
                f"EyeHiBig_{tag}",
                col,
                mats["eye_white"],
                loc=(ex - 0.030, ey - 0.075, ez + 0.034),
                scale=(0.030 if pose != "crying" else 0.038, 0.018, 0.032 if pose != "crying" else 0.040),
                subsurf=0,
                parent=parent,
            )
            create_sphere(
                f"EyeHiSmall_{tag}",
                col,
                mats["eye_white"],
                loc=(ex + 0.028, ey - 0.072, ez - 0.030),
                scale=(0.014 if pose != "crying" else 0.022, 0.012, 0.015 if pose != "crying" else 0.024),
                subsurf=0,
                parent=parent,
            )

        # Expressive eyebrows
        if pose == "working":
            # Focused angled brows
            create_capsule(
                f"Brow_{tag}",
                col,
                b_mat,
                radius=0.020,
                length=0.085,
                loc=(side * (eye_x - 0.01), eye_y + 0.01, ez + 0.14),
                rot=(0.0, math.radians(90 - side * 18), math.radians(-side * 12)),
                parent=parent,
            )
        elif pose == "confused":
            # Asymmetric raised/lowered brows
            dz = 0.175 if side > 0 else 0.135
            tilt = -16 if side > 0 else 12
            create_capsule(
                f"Brow_{tag}",
                col,
                b_mat,
                radius=0.020,
                length=0.080,
                loc=(side * (eye_x - 0.01), eye_y + 0.015, ez + dz),
                rot=(0.0, math.radians(90 + tilt), math.radians(-side * 12)),
                parent=parent,
            )
        elif pose == "crying":
            # Sad drooping brows (inner corners raised)
            create_capsule(
                f"Brow_{tag}",
                col,
                b_mat,
                radius=0.020,
                length=0.085,
                loc=(side * (eye_x - 0.005), eye_y + 0.01, ez + 0.155),
                rot=(0.0, math.radians(90 + side * 22), math.radians(-side * 12)),
                parent=parent,
            )
            # Translucent watery tear stream + glossy tear drop!
            ty = ey + tear_y_offset
            create_tube_curve(
                f"TearStream_{tag}",
                col,
                mats["tear"],
                [
                    (ex + side * 0.01, ty - 0.055, ez - 0.065, 0.75),
                    (ex + side * 0.03, ty - 0.068, ez - 0.145, 0.95),
                    (ex + side * 0.04, ty - 0.060, ez - 0.225, 1.15),
                ],
                bevel_depth=0.022,
                resolution_u=14,
                bevel_res=6,
                parent=parent,
            )
            create_sphere(
                f"TearDrop_{tag}",
                col,
                mats["tear"],
                loc=(ex + side * 0.07, ty - 0.082, ez - 0.19),
                scale=(0.028, 0.026, 0.042),
                subsurf=1,
                parent=parent,
            )
        else:
            # Cute soft brow dots for idle & happy
            create_sphere(
                f"BrowDot_{tag}",
                col,
                b_mat,
                loc=(side * (eye_x - 0.02), eye_y + 0.02, ez + (0.175 if pose == "happy" else 0.16)),
                scale=(0.050, 0.028, 0.028),
                rot=(math.radians(-16), math.radians(-side * 12), math.radians(-side * 10)),
                parent=parent,
            )

        # Cheek blush
        create_sphere(
            f"Blush_{tag}",
            col,
            blush_mat,
            loc=(side * blush_x, blush_y, blush_z),
            scale=(0.078 if pose == "happy" else 0.068, 0.025, 0.042 if pose == "happy" else 0.036),
            rot=(0.0, 0.0, math.radians(-side * 26)),
            parent=parent,
        )


def create_expression_mouth(
    pose: str,
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    *,
    parent: bpy.types.Object,
    mouth_mat: bpy.types.Material,
    mouth_y: float,
    mouth_z: float,
    cat_style: bool = True,
) -> None:
    """Pose-specific mouth in head-pivot local space."""
    if pose == "happy":
        # Open joyful 'D' smile with rosy inner mouth
        create_sphere(
            "HappyMouthOpen",
            col,
            mats["mouth_inner"],
            loc=(0.0, mouth_y + 0.015, mouth_z - 0.025),
            scale=(0.088, 0.032, 0.058),
            subsurf=1,
            parent=parent,
        )
        create_tube_curve(
            "HappyMouthRim",
            col,
            mouth_mat,
            [
                (-0.095, mouth_y + 0.005, mouth_z + 0.012, 0.9),
                (0.0, mouth_y - 0.012, mouth_z + 0.018, 1.0),
                (0.095, mouth_y + 0.005, mouth_z + 0.012, 0.9),
            ],
            bevel_depth=0.013,
            resolution_u=14,
            bevel_res=6,
            parent=parent,
        )
    elif pose == "confused":
        # Cute small surprised 'o' mouth
        pts = []
        for i in range(14):
            a = 2.0 * math.pi * i / 14
            pts.append((0.038 * math.cos(a), mouth_y - 0.005, mouth_z - 0.015 + 0.042 * math.sin(a), 1.0))
        create_tube_curve("ConfusedMouth", col, mouth_mat, pts, bevel_depth=0.012, cyclic=True, parent=parent)
    elif pose == "crying":
        # Wobbly sad downturned frown
        create_tube_curve(
            "CryingMouth",
            col,
            mouth_mat,
            [
                (-0.095, mouth_y + 0.012, mouth_z - 0.045, 0.85),
                (0.0, mouth_y - 0.010, mouth_z + 0.005, 1.0),
                (0.095, mouth_y + 0.012, mouth_z - 0.045, 0.85),
            ],
            bevel_depth=0.014,
            resolution_u=14,
            bevel_res=6,
            parent=parent,
        )
    elif pose == "working":
        # Concentrated tiny straight/slight smirk
        create_tube_curve(
            "WorkingMouth",
            col,
            mouth_mat,
            [
                (-0.068, mouth_y + 0.005, mouth_z - 0.015, 0.85),
                (0.0, mouth_y - 0.008, mouth_z - 0.018, 1.0),
                (0.068, mouth_y + 0.005, mouth_z - 0.008, 0.85),
            ],
            bevel_depth=0.013,
            resolution_u=12,
            bevel_res=6,
            parent=parent,
        )
    else:  # idle
        if cat_style:
            for side in (-1, 1):
                tag = "L" if side > 0 else "R"
                create_tube_curve(
                    f"IdleSmile_{tag}",
                    col,
                    mouth_mat,
                    [
                        (0.0, mouth_y - 0.005, mouth_z + 0.005, 0.9),
                        (side * 0.046, mouth_y - 0.008, mouth_z - 0.032, 1.0),
                        (side * 0.098, mouth_y + 0.016, mouth_z - 0.010, 0.85),
                    ],
                    bevel_depth=0.013,
                    resolution_u=14,
                    bevel_res=6,
                    parent=parent,
                )
        else:
            create_tube_curve(
                "IdleSmile",
                col,
                mouth_mat,
                [
                    (-0.105, mouth_y + 0.025, mouth_z + 0.005, 0.85),
                    (0.0, mouth_y - 0.005, mouth_z - 0.028, 1.0),
                    (0.105, mouth_y + 0.025, mouth_z + 0.005, 0.85),
                ],
                bevel_depth=0.014,
                resolution_u=16,
                bevel_res=6,
                parent=parent,
            )


def create_pose_props(pose: str, col: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    """Adds iconic floating 3D props for working / confused / happy states."""
    if pose == "working":
        # Floating mini laptop oriented toward the mascot:
        # keyboard closer to paws (+Y), screen hinged at far edge (-Y) facing mascot (+Y)!
        deck = create_empty("WorkDeckPivot", col, loc=(0.0, -0.66, 0.63), rot=(math.radians(-12), 0.0, 0.0))
        create_rounded_box(
            "WorkDeckBody",
            col,
            mats["holo_deck"],
            size=(0.64, 0.34, 0.042),
            bevel=0.016,
            bevel_segments=4,
            parent=deck,
        )
        # Screen hinged at far front edge (-Y), tilted ~108 deg open facing the mascot (+Y)
        screen_piv = create_empty("WorkScreenPivot", col, loc=(0.0, -0.20, 0.155), rot=(math.radians(-72), 0.0, 0.0), parent=deck)
        create_rounded_box(
            "WorkScreenFrame",
            col,
            mats["holo_deck"],
            size=(0.60, 0.30, 0.028),
            bevel=0.012,
            bevel_segments=3,
            parent=screen_piv,
        )
        # Inner display glass facing mascot (+Z local -> +Y/+Z world)
        create_rounded_box(
            "WorkScreenGlass",
            col,
            mats["holo_screen"],
            size=(0.54, 0.24, 0.014),
            bevel=0.006,
            bevel_segments=2,
            loc=(0.0, 0.0, 0.012),
            parent=screen_piv,
        )
        # Glowing code bars on the inner screen facing the mascot
        for row_i, (ry, rw, mkey) in enumerate(((-0.06, 0.26, "prompt_green"), (0.0, 0.36, "holo_cyan"), (0.06, 0.18, "led_yellow"))):
            create_capsule(
                f"WorkCodeBar_{row_i}",
                col,
                mats[mkey],
                radius=0.010,
                length=rw,
                loc=(-0.22 + rw * 0.5, ry, 0.021),
                rot=(0.0, math.radians(90), 0.0),
                parent=screen_piv,
            )
        # Glowing ServerBox `>_` lid emblem on the back of the laptop (-Z local -> facing viewer)
        create_capsule("WorkLidChevTop", col, mats["prompt_green"], radius=0.009, length=0.048, loc=(-0.042, -0.014, -0.017), rot=(0.0, math.radians(90), math.radians(32)), parent=screen_piv)
        create_capsule("WorkLidChevBot", col, mats["prompt_green"], radius=0.009, length=0.048, loc=(-0.042, 0.014, -0.017), rot=(0.0, math.radians(90), math.radians(-32)), parent=screen_piv)
        create_capsule("WorkLidCursor", col, mats["prompt_green"], radius=0.009, length=0.056, loc=(0.045, 0.024, -0.017), rot=(0.0, math.radians(90), 0.0), parent=screen_piv)
        # Cute glowing keycaps on the deck closer to the mascot's paws
        for r_i, ky in enumerate((-0.03, 0.06)):
            for c_i in range(5):
                kx = -0.20 + c_i * 0.10
                mkey = "prompt_green" if (r_i == 1 and c_i == 4) else "holo_cyan"
                create_rounded_box(
                    f"WorkKey_{r_i}_{c_i}",
                    col,
                    mats[mkey],
                    size=(0.068, 0.048, 0.016),
                    bevel=0.006,
                    bevel_segments=2,
                    loc=(kx, ky, 0.025),
                    parent=deck,
                )

    elif pose == "confused":
        # Floating glossy golden '?' question mark beside the tilted head!
        q = create_empty("QuestionPivot", col, loc=(0.68, -0.18, 2.02), rot=(0.0, math.radians(12), math.radians(-10)))
        create_tube_curve(
            "QuestionHook",
            col,
            mats["question_yellow"],
            [
                (-0.08, 0.0, 0.14, 0.95),
                (-0.04, 0.0, 0.23, 1.0),
                (0.06, 0.0, 0.22, 1.0),
                (0.09, 0.0, 0.13, 0.98),
                (0.01, 0.0, 0.05, 0.95),
                (0.0, 0.0, -0.02, 0.92),
            ],
            bevel_depth=0.034,
            resolution_u=24,
            bevel_res=8,
            parent=q,
        )
        create_sphere("QuestionDot", col, mats["question_yellow"], loc=(0.0, 0.0, -0.115), scale=(0.040, 0.040, 0.040), parent=q)

    elif pose == "happy":
        # Floating glossy golden 4-point sparkles beside the cheering ears!
        for idx, (sx, sy, sz, sc) in enumerate(((-0.74, -0.14, 1.98, 1.0), (0.76, -0.12, 1.88, 0.82))):
            sp = create_empty(f"Sparkle_{idx}", col, loc=(sx, sy, sz), rot=(0.0, math.radians(15 * (-1 if idx else 1)), 0.0))
            create_sphere(f"SparkleV_{idx}", col, mats["sparkle_gold"], scale=(0.032 * sc, 0.032 * sc, 0.13 * sc), subsurf=0, parent=sp)
            create_sphere(f"SparkleH_{idx}", col, mats["sparkle_gold"], scale=(0.13 * sc, 0.032 * sc, 0.032 * sc), subsurf=0, parent=sp)


# ---------------------------------------------------------------------------
# Shared Hardware: Pedestal, Terminal Goggles & ServerBox Backpack
# ---------------------------------------------------------------------------

def create_pedestal(col: bpy.types.Collection, mats: dict[str, bpy.types.Material], radius: float = 0.88) -> None:
    create_cylinder(
        "StandBase",
        col,
        mats["pedestal"],
        radius=radius,
        depth=0.08,
        vertices=64,
        bevel=0.022,
        loc=(0.0, 0.04, 0.04),
    )
    create_cylinder(
        "StandRing",
        col,
        mats["pedestal_ring"],
        radius=radius - 0.12,
        depth=0.012,
        vertices=64,
        bevel=0.004,
        loc=(0.0, 0.04, 0.078),
    )


def create_terminal_goggles(
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    *,
    parent: bpy.types.Object,
    pose: str = "idle",
    tilt_deg: float = -30.0,
    band_rx: float = 0.64,
    band_ry: float = 0.56,
    visor_y: float = -0.52,
    frame_w: float = 0.66,
) -> None:
    """Forehead terminal visor goggles parented to the head pivot so they tilt
    naturally with every pose, showing state-aware glowing symbols!"""
    pivot = create_empty("GogglesPivot", col, loc=(0.0, 0.0, 0.0), rot=(math.radians(tilt_deg), 0.0, 0.0), parent=parent)

    pts = []
    n = 32
    for i in range(n):
        ang = 2.0 * math.pi * i / n
        pts.append((band_rx * math.cos(ang), band_ry * math.sin(ang), 0.08, 1.0))
    create_tube_curve("GoggleBand", col, mats["strap"], pts, bevel_depth=0.036, cyclic=True, parent=pivot)

    create_rounded_box(
        "GoggleFrame",
        col,
        mats["goggle_frame"],
        size=(frame_w, 0.15, 0.245),
        bevel=0.058,
        bevel_segments=5,
        loc=(0.0, visor_y, 0.08),
        parent=pivot,
    )
    create_rounded_box(
        "GoggleVisor",
        col,
        mats["visor_glass"],
        size=(frame_w - 0.09, 0.10, 0.172),
        bevel=0.036,
        bevel_segments=5,
        loc=(0.0, visor_y - 0.035, 0.08),
        parent=pivot,
    )
    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        create_cylinder(
            f"GoggleHinge_{tag}",
            col,
            mats["goggle_hinge"],
            radius=0.046,
            depth=0.064,
            bevel=0.01,
            loc=(side * (frame_w * 0.5 + 0.02), visor_y + 0.03, 0.08),
            rot=(0.0, math.radians(90), 0.0),
            parent=pivot,
        )

    py = visor_y - 0.088
    pz = 0.08
    if pose == "confused":
        # Glowing yellow '?' on visor
        create_tube_curve(
            "VisorQHook",
            col,
            mats["prompt_yellow"],
            [
                (-0.035, py, pz + 0.028, 0.9),
                (0.0, py, pz + 0.052, 1.0),
                (0.040, py, pz + 0.025, 0.95),
                (0.0, py, pz - 0.012, 0.9),
            ],
            bevel_depth=0.013,
            resolution_u=16,
            bevel_res=6,
            parent=pivot,
        )
        create_sphere("VisorQDot", col, mats["prompt_yellow"], loc=(0.0, py, pz - 0.045), scale=(0.015, 0.015, 0.015), subsurf=0, parent=pivot)
    elif pose == "crying":
        # Glowing coral-red '!' alert on visor
        create_capsule("VisorAlertBar", col, mats["prompt_red"], radius=0.014, length=0.062, loc=(0.0, py, pz + 0.016), parent=pivot)
        create_sphere("VisorAlertDot", col, mats["prompt_red"], loc=(0.0, py, pz - 0.044), scale=(0.016, 0.016, 0.016), subsurf=0, parent=pivot)
    elif pose == "happy":
        # Glowing green '^ ^' on visor
        for side in (-1, 1):
            cx = side * 0.095
            create_capsule(f"VisorJoyL_{side}", col, mats["prompt_green"], radius=0.012, length=0.052, loc=(cx - 0.018, py, pz + 0.005), rot=(0.0, math.radians(38), 0.0), parent=pivot)
            create_capsule(f"VisorJoyR_{side}", col, mats["prompt_green"], radius=0.012, length=0.052, loc=(cx + 0.018, py, pz + 0.005), rot=(0.0, math.radians(-38), 0.0), parent=pivot)
    else:
        # Classic glowing green `>_` (with cyan progress dot when working)
        create_capsule("PromptChevronTop", col, mats["prompt_green"], radius=0.013, length=0.066, loc=(-0.095, py, pz + 0.023), rot=(0.0, math.radians(-56), 0.0), parent=pivot)
        create_capsule("PromptChevronBot", col, mats["prompt_green"], radius=0.013, length=0.066, loc=(-0.095, py, pz - 0.023), rot=(0.0, math.radians(56), 0.0), parent=pivot)
        create_capsule("PromptCursor", col, mats["prompt_green"], radius=0.013, length=0.086, loc=(0.040, py, pz - 0.038), rot=(0.0, math.radians(90), 0.0), parent=pivot)
        if pose == "working":
            for dot_i in range(3):
                create_sphere(
                    f"VisorWorkDot_{dot_i}",
                    col,
                    mats["holo_cyan"],
                    loc=(0.135 + dot_i * 0.036, py, pz + 0.015),
                    scale=(0.011, 0.011, 0.011),
                    subsurf=0,
                    parent=pivot,
                )


# ---------------------------------------------------------------------------
# Studio & Export
# ---------------------------------------------------------------------------

def setup_studio(col: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    scene = bpy.context.scene
    world = bpy.data.worlds.new("StudioWorld")
    scene.world = world
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = hex_rgba("#F5F7FA")
    bg.inputs["Strength"].default_value = 0.95

    mesh = bpy.data.meshes.new("StudioFloor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=14.0)
    bm.to_mesh(mesh)
    bm.free()
    floor = bpy.data.objects.new("StudioFloor", mesh)
    floor.location = (0.0, 0.0, -0.002)
    floor.is_shadow_catcher = True
    link_obj(floor, col)
    assign_mat(floor, mats["backdrop"])

    def add_area_light(name: str, loc, target, energy: float, size: float, color_hex: str) -> None:
        ld = bpy.data.lights.new(name=name, type="AREA")
        ld.energy = energy
        ld.shape = "DISK"
        ld.size = size
        c = hex_rgba(color_hex)
        ld.color = (c[0], c[1], c[2])
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        lo.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        link_obj(lo, col)

    add_area_light("KeyLight", (-3.4, -3.8, 4.2), (0.0, 0.0, 1.15), 260.0, 2.8, "#FFF8EE")
    add_area_light("FillLight", (3.8, -2.6, 2.4), (0.0, 0.0, 1.10), 115.0, 3.4, "#E6F0FF")
    add_area_light("RimLight", (0.6, 3.8, 3.6), (0.0, 0.0, 1.20), 210.0, 2.4, "#FFFFFF")
    add_area_light("BackFill", (-2.6, 3.2, 1.8), (0.0, 0.3, 0.85), 90.0, 2.4, "#F5FAFF")


def configure_cycles(samples: int = 64) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    has_gpu = False
    for d in prefs.devices:
        if d.type == "METAL":
            d.use = True
            has_gpu = True
        else:
            d.use = False
    scene.cycles.device = "GPU" if has_gpu else "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 8
    scene.cycles.diffuse_bounces = 4
    scene.cycles.glossy_bounces = 4
    scene.cycles.transparent_max_bounces = 4

    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Punchy"
    except Exception:
        scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.15
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"


def create_camera(name: str, col: bpy.types.Collection, loc, target, lens: float = 60.0) -> bpy.types.Object:
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = lens
    cam_data.sensor_width = 36.0
    cam_obj = bpy.data.objects.new(name, cam_data)
    cam_obj.location = loc
    cam_obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    link_obj(cam_obj, col)
    return cam_obj


def export_pose_assets(
    out_dir: Path,
    stem: str,
    pose: str,
    mascot_col: bpy.types.Collection,
    pedestal_col: bpy.types.Collection,
    studio_col: bpy.types.Collection,
    *,
    target=(0.02, 0.04, 1.14),
    render_back: bool = False,
) -> None:
    """Renders hero (and optional back) PNG + exports Draco-compressed GLB & `.blend`."""
    out_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    floor = bpy.data.objects.get("StudioFloor")

    hero_loc = (-2.45, -4.55, 2.02) if pose != "working" else (-2.65, -4.50, 2.18)
    cam_hero = create_camera("CamHero", studio_col, hero_loc, target, lens=58.0)
    scene.camera = cam_hero
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    if floor is not None:
        floor.hide_render = False
    scene.render.filepath = str(out_dir / f"render_{pose}.png")
    bpy.ops.render.render(write_still=True)

    if render_back:
        cam_back = create_camera("CamBack", studio_col, (2.35, 4.45, 1.92), target, lens=60.0)
        scene.camera = cam_back
        scene.render.filepath = str(out_dir / "render_back.png")
        bpy.ops.render.render(write_still=True)
        scene.camera = cam_hero

    blend_path = out_dir / f"{stem}_{pose}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    glb_path = out_dir / f"{stem}_{pose}.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for col in (mascot_col, pedestal_col):
        for obj in col.objects:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_draco_mesh_compression_enable=True,
        export_draco_mesh_compression_level=6,
    )
    print(f"Exported {pose}: {blend_path.name}, {glb_path.name}")
