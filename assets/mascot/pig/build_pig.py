"""ServerBox 3D Mascot — Pig Edition ("ServerPig") across 5 states:
`idle`, `working`, `confused`, `happy`, `crying`.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT_DIR.parent))

import common as C  # noqa: E402


def build_pig_materials() -> dict[str, bpy.types.Material]:
    mats = C.base_materials()
    mats.update(
        {
            "pig_pink": C.make_material("PigPink", "#F6B5BC", roughness=0.56, subsurface=0.22, coat=0.05),
            "pig_belly": C.make_material("PigBelly", "#FDE4E6", roughness=0.60, subsurface=0.22, coat=0.04),
            "pig_snout": C.make_material("PigSnout", "#EC8E99", roughness=0.50, subsurface=0.20, coat=0.08),
            "pig_nostril": C.make_material("PigNostril", "#7D3E48", roughness=0.42, subsurface=0.04, coat=0.12),
            "pig_hoof": C.make_material("PigHoof", "#7A454E", roughness=0.40, subsurface=0.05, coat=0.20),
            "pig_ear_inner": C.make_material("PigEarInner", "#E58B96", roughness=0.58, subsurface=0.22, coat=0.03),
            "collar_blue": C.make_material("PigCollarBlue", "#4A8FC2", roughness=0.48, subsurface=0.08, coat=0.10),
            "brow_cream": C.make_material("PigBrowCream", "#FFF2F0", roughness=0.58, subsurface=0.18, coat=0.04),
        }
    )
    return mats


def create_pig_head(
    pose: str,
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
) -> bpy.types.Object:
    head_pivot = C.create_empty("HeadPivot", col, loc=(0.0, -0.02, 1.47), rot=C.head_pose_rot(pose))

    mesh = bpy.data.meshes.new("PigHead")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=32, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        nx = x * 0.64
        ny = y * 0.58
        nz = z * 0.53
        if z < 0.0:
            jowl = math.exp(-((z + 0.30) / 0.40) ** 2)
            nx *= 1.0 + 0.08 * jowl
        v.co = Vector((nx, ny, nz))
    bm.to_mesh(mesh)
    bm.free()
    head = bpy.data.objects.new("PigHead", mesh)
    head.parent = head_pivot
    C.link_obj(head, col)
    C.assign_mat(head, mats["pig_pink"])
    C.set_smooth(head)
    C.add_subsurf(head, 1)

    for side in (-1, 1):
        create_pig_ear(side, col, mats, head_pivot)

    C.create_sphere(
        "PigSnout",
        col,
        mats["pig_snout"],
        loc=(0.0, -0.58, -0.09),
        scale=(0.23, 0.14, 0.155),
        rot=(math.radians(8), 0.0, 0.0),
        parent=head_pivot,
    )
    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        C.create_sphere(
            f"PigNostril_{tag}",
            col,
            mats["pig_nostril"],
            loc=(side * 0.072, -0.708, -0.08),
            scale=(0.032, 0.022, 0.052),
            rot=(math.radians(8), math.radians(-side * 8), 0.0),
            subsurf=0,
            parent=head_pivot,
        )

    C.create_expression_eyes(
        pose,
        col,
        mats,
        parent=head_pivot,
        eye_x=0.255,
        eye_y=-0.505,
        eye_z=0.035,
        brow_mat=mats["brow_cream"] if pose in ("idle", "happy") else mats["pig_nostril"],
        blush_x=0.395,
        blush_y=-0.445,
        blush_z=-0.115,
    )
    C.create_expression_mouth(
        pose,
        col,
        mats,
        parent=head_pivot,
        mouth_mat=mats["pig_nostril"],
        mouth_y=-0.625,
        mouth_z=-0.23,
        cat_style=False,
    )

    C.create_terminal_goggles(
        col,
        mats,
        parent=head_pivot,
        pose=pose,
        tilt_deg=-31.0,
        band_rx=0.675,
        band_ry=0.60,
        visor_y=-0.555,
        frame_w=0.66,
    )
    return head_pivot


def create_pig_ear(
    side: int,
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    parent: bpy.types.Object,
) -> None:
    tag = "L" if side > 0 else "R"

    def make_floppy_ear(name: str, scale_xy: tuple[float, float], height: float, y_off: float) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=24, radius=1.0)
        for v in bm.verts:
            t = (v.co.z + 1.0) * 0.5
            width_prof = math.sin(t * math.pi) ** 0.55 * (0.95 - 0.15 * t) + 0.22 * (1.0 - t)
            nx = v.co.x * scale_xy[0] * max(width_prof, 0.12)
            ny = v.co.y * scale_xy[1] * max(width_prof, 0.12) + y_off
            fold = max(0.0, (t - 0.42) / 0.58)
            ny -= 0.22 * (fold ** 1.8)
            nz = t * height - 0.11 * (fold ** 2.1)
            v.co = Vector((nx, ny, nz))
        bm.to_mesh(mesh)
        bm.free()
        return bpy.data.objects.new(name, mesh)

    outer = make_floppy_ear(f"PigEarOuter_{tag}", (0.28, 0.11), 0.48, 0.0)
    outer.parent = parent
    outer.location = (side * 0.42, 0.05, 0.26)
    outer.rotation_euler = (math.radians(8), math.radians(side * 34), math.radians(-side * 16))
    C.link_obj(outer, col)
    C.assign_mat(outer, mats["pig_pink"])
    C.set_smooth(outer)
    C.add_subsurf(outer, 1)

    inner = make_floppy_ear(f"PigEarInner_{tag}", (0.18, 0.045), 0.34, -0.042)
    inner.parent = outer
    inner.location = (0.0, -0.015, 0.05)
    C.link_obj(inner, col)
    C.assign_mat(inner, mats["pig_ear_inner"])
    C.set_smooth(inner)
    C.add_subsurf(inner, 1)


def create_pig_body_and_limbs(
    pose: str,
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
) -> None:
    mesh = bpy.data.meshes.new("PigTorso")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=42, v_segments=30, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        t = (z + 1.0) * 0.5
        width = 0.49 * (1.12 - 0.26 * (t ** 1.4))
        depth = 0.43 * (1.12 - 0.24 * (t ** 1.4))
        v.co = Vector((x * width, y * depth, z * 0.46))
    bm.to_mesh(mesh)
    bm.free()
    body = bpy.data.objects.new("PigTorso", mesh)
    body.location = (0.0, 0.01, 0.61)
    C.link_obj(body, col)
    C.assign_mat(body, mats["pig_pink"])
    C.set_smooth(body)
    C.add_subsurf(body, 1)

    C.create_sphere("PigBelly", col, mats["pig_belly"], loc=(0.0, -0.22, 0.58), scale=(0.31, 0.24, 0.34), rot=(math.radians(8), 0.0, 0.0))

    pts = []
    for i in range(18):
        ang = 2.0 * math.pi * i / 18
        rx = 0.35 * math.cos(ang)
        ry = 0.32 * math.sin(ang)
        rz = 1.01 - 0.035 * max(0.0, -math.sin(ang))
        rad = 1.0 + 0.22 * max(0.0, -math.sin(ang))
        pts.append((rx, ry, rz, rad))
    C.create_tube_curve("PigCollar", col, mats["collar_blue"], pts, bevel_depth=0.068, cyclic=True)

    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        C.create_sphere(f"PigLeg_{tag}", col, mats["pig_pink"], loc=(side * 0.23, 0.0, 0.27), scale=(0.15, 0.15, 0.15))
        for lobe_i, lx in enumerate((-0.042, 0.042)):
            C.create_sphere(
                f"PigHoof_{tag}_{lobe_i}",
                col,
                mats["pig_hoof"],
                loc=(side * 0.23 + lx, -0.055, 0.165),
                scale=(0.088, 0.175, 0.095),
                rot=(0.0, 0.0, math.radians(-side * 10)),
            )

    left_pts, right_pts = C.arm_pose_points(pose, shoulder_x=0.31)
    C.create_tube_curve("PigArm_L", col, mats["pig_pink"], left_pts, bevel_depth=0.104)
    C.create_tube_curve("PigArm_R", col, mats["pig_pink"], right_pts, bevel_depth=0.102)
    lp, rp = left_pts[-1], right_pts[-1]
    C.create_sphere("PigHandHoof_L", col, mats["pig_hoof"], loc=(lp[0], lp[1] - 0.02, lp[2] - 0.02), scale=(0.105, 0.108, 0.102))
    C.create_sphere("PigHandHoof_R", col, mats["pig_hoof"], loc=(rp[0], rp[1] - 0.02, rp[2] + (0.02 if pose in ("idle", "happy") else 0.0)), scale=(0.108, 0.104, 0.108))


def create_pig_curly_tail(col: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    pts = []
    steps = 26
    for i in range(steps):
        t = i / (steps - 1)
        theta = t * 2.0 * math.pi * 1.45
        loop_r = 0.085 * math.sin(min(1.0, t * 1.4) * math.pi * 0.7) + 0.03
        x = loop_r * math.cos(theta)
        y = 0.39 + 0.34 * t
        z = 0.29 + 0.08 * t + loop_r * math.sin(theta)
        rad = 1.0 - 0.35 * (t ** 1.4)
        pts.append((x, y, z, rad))
    C.create_tube_curve("PigCurlyTail", col, mats["pig_pink"], pts, bevel_depth=0.038, resolution_u=32, bevel_res=8)


def build_pose(pose: str) -> None:
    C.clear_scene()
    mats = build_pig_materials()
    mascot_col = C.get_or_create_collection("Mascot")
    pedestal_col = C.get_or_create_collection("Pedestal")
    studio_col = C.get_or_create_collection("Studio")

    C.create_pedestal(pedestal_col, mats, radius=0.90)
    create_pig_body_and_limbs(pose, mascot_col, mats)
    create_pig_head(pose, mascot_col, mats)
    create_pig_curly_tail(mascot_col, mats)
    C.create_pose_props(pose, mascot_col, mats)

    C.setup_studio(studio_col, mats)
    C.configure_cycles(samples=64)
    C.export_pose_assets(
        OUT_DIR,
        "serverbox_pig",
        pose,
        mascot_col,
        pedestal_col,
        studio_col,
        target=(0.02, 0.06, 1.14),
        render_back=(pose == "idle"),
    )


def main() -> None:
    requested = [a for a in sys.argv[sys.argv.index("--") + 1 :] if a in C.POSES] if "--" in sys.argv else list(C.POSES)
    for pose in requested:
        build_pose(pose)


if __name__ == "__main__":
    main()
