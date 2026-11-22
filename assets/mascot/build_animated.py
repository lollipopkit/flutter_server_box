"""Build the rigged, multi-animation GLB file for the ServerBox Pig mascot.

Produces:
  - `assets/mascot/pig/serverbox_pig.glb`
  - `assets/mascot/pig/serverbox_pig_animated.blend`

Contains 5 organically eased looping animations (`idle`, `working`, `confused`,
`happy`, `crying`) for smooth cross-fade transitions in `<model-viewer>` and
Flutter 3D viewers.
"""

from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT_DIR))

import common as C  # noqa: E402


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _parent_to_bone(obj: bpy.types.Object, arm: bpy.types.Object, bone_name: str) -> None:
    """Attach `obj` rigidly to `bone_name` while preserving its world transform."""
    bpy.context.view_layer.update()
    world_mat = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    pose_bone = arm.pose.bones[bone_name]
    obj.matrix_parent_inverse = (arm.matrix_world @ pose_bone.matrix).inverted()
    obj.matrix_world = world_mat


def _create_rig(col: bpy.types.Collection, head_z: float = 1.47, shoulder_x: float = 0.31) -> bpy.types.Object:
    arm_data = bpy.data.armatures.new("MascotRig")
    arm = bpy.data.objects.new("MascotRig", arm_data)
    C.link_obj(arm, col)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")

    def add_bone(name: str, loc: tuple[float, float, float], parent_name: str | None = None, length: float = 0.15):
        eb = arm_data.edit_bones.new(name)
        eb.head = Vector(loc)
        eb.tail = Vector((loc[0], loc[1], loc[2] + length))
        eb.roll = 0.0
        if parent_name:
            eb.parent = arm_data.edit_bones[parent_name]
        return eb

    add_bone("Root", (0.0, 0.0, 0.0))
    add_bone("Body", (0.0, 0.0, 0.25), "Root")
    add_bone("Head", (0.0, -0.02, head_z), "Body")
    add_bone("Arm_L", (shoulder_x, 0.02, 0.86), "Body")
    add_bone("Arm_R", (-shoulder_x, 0.02, 0.86), "Body")
    add_bone("Tail", (0.0, 0.39, 0.29), "Body")

    for pose in C.POSES:
        add_bone(f"Expr_{pose}", (0.0, -0.02, head_z), "Head", length=0.10)

    add_bone("Prop_working", (0.0, -0.56, 0.62), "Root", length=0.10)
    add_bone("Prop_confused", (0.62, -0.15, 2.02), "Root", length=0.10)
    add_bone("Prop_happy", (0.0, -0.14, 1.98), "Root", length=0.10)

    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


def _create_rest_arms(
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    arm: bpy.types.Object,
    shoulder_x: float = 0.31,
) -> None:
    """Create straight-down rest-pose Pig arms with hooves, parented to Arm_L / Arm_R."""
    for side in (-1, 1):
        tag = "L" if side > 0 else "R"
        bone_name = f"Arm_{tag}"
        sx = side * shoulder_x
        pts = [
            (sx, 0.02, 0.86, 1.02),
            (sx + side * 0.06, 0.00, 0.70, 0.96),
            (sx + side * 0.09, -0.03, 0.55, 0.92),
        ]
        limb = C.create_tube_curve(f"RigArm_{tag}", col, mats["pig_pink"], pts, bevel_depth=0.102)
        _parent_to_bone(limb, arm, bone_name)

        px, py, pz = sx + side * 0.09, -0.04, 0.52
        paw = C.create_sphere(f"RigPaw_{tag}", col, mats["pig_hoof"], loc=(px, py, pz), scale=(0.108, 0.108, 0.108))
        _parent_to_bone(paw, arm, bone_name)


def _remove_objects_matching(col: bpy.types.Collection, prefixes: tuple[str, ...]) -> None:
    to_remove = [o for o in list(col.objects) if o.name.startswith(prefixes)]
    for obj in to_remove:
        bpy.data.objects.remove(obj, do_unlink=True)


def _collect_new_objects(col: bpy.types.Collection, before: set[str]) -> list[bpy.types.Object]:
    return [o for o in col.objects if o.name not in before]


def _add_visor_symbols(
    pose: str,
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    goggle_pivot: bpy.types.Object,
    visor_y: float,
) -> None:
    py = visor_y - 0.088
    pz = 0.08
    if pose in ("idle", "working"):
        C.create_capsule("VisorSym_Top", col, mats["prompt_green"], radius=0.013, length=0.066, loc=(-0.095, py, pz + 0.023), rot=(0.0, math.radians(-56), 0.0), parent=goggle_pivot)
        C.create_capsule("VisorSym_Bot", col, mats["prompt_green"], radius=0.013, length=0.066, loc=(-0.095, py, pz - 0.023), rot=(0.0, math.radians(56), 0.0), parent=goggle_pivot)
        C.create_capsule("VisorSym_Cursor", col, mats["prompt_green"], radius=0.013, length=0.086, loc=(0.040, py, pz - 0.038), rot=(0.0, math.radians(90), 0.0), parent=goggle_pivot)
        if pose == "working":
            for i in range(3):
                C.create_sphere(f"VisorSym_Dot_{i}", col, mats["holo_cyan"], loc=(0.135 + i * 0.036, py, pz + 0.015), scale=(0.011, 0.011, 0.011), subsurf=0, parent=goggle_pivot)
    elif pose == "confused":
        C.create_tube_curve(
            "VisorSym_Q", col, mats["prompt_yellow"],
            [(-0.035, py, pz + 0.028, 0.9), (0.0, py, pz + 0.052, 1.0), (0.040, py, pz + 0.025, 0.95), (0.0, py, pz - 0.012, 0.9)],
            bevel_depth=0.013, resolution_u=16, bevel_res=6, parent=goggle_pivot,
        )
        C.create_sphere("VisorSym_QDot", col, mats["prompt_yellow"], loc=(0.0, py, pz - 0.045), scale=(0.015, 0.015, 0.015), subsurf=0, parent=goggle_pivot)
    elif pose == "happy":
        for side in (-1, 1):
            tag = "L" if side > 0 else "R"
            cx = side * 0.095
            C.create_capsule(f"VisorSym_A_{tag}", col, mats["prompt_green"], radius=0.012, length=0.052, loc=(cx - 0.018, py, pz + 0.005), rot=(0.0, math.radians(38), 0.0), parent=goggle_pivot)
            C.create_capsule(f"VisorSym_B_{tag}", col, mats["prompt_green"], radius=0.012, length=0.052, loc=(cx + 0.018, py, pz + 0.005), rot=(0.0, math.radians(-38), 0.0), parent=goggle_pivot)
    elif pose == "crying":
        C.create_capsule("VisorSym_Bang", col, mats["prompt_red"], radius=0.014, length=0.062, loc=(0.0, py, pz + 0.016), parent=goggle_pivot)
        C.create_sphere("VisorSym_BangDot", col, mats["prompt_red"], loc=(0.0, py, pz - 0.044), scale=(0.016, 0.016, 0.016), subsurf=0, parent=goggle_pivot)


def _build_all_expressions(
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    arm: bpy.types.Object,
    head_pivot: bpy.types.Object,
    visor_y: float,
) -> None:
    goggle_pivot = next((o for o in col.objects if o.name == "GogglesPivot"), None)
    assert goggle_pivot is not None

    for pose in C.POSES:
        before = {o.name for o in col.objects}

        C.create_expression_eyes(
            pose, col, mats, parent=head_pivot,
            eye_x=0.245, eye_y=-0.505, eye_z=0.045,
            brow_mat=mats["brow_cream"] if pose in ("idle", "happy") else mats["pig_nostril"],
            blush_x=0.39, blush_y=-0.46, blush_z=-0.08,
        )
        C.create_expression_mouth(
            pose, col, mats, parent=head_pivot,
            mouth_mat=mats["pig_nostril"], mouth_y=-0.635, mouth_z=-0.225, cat_style=False,
        )
        _add_visor_symbols(pose, col, mats, goggle_pivot, visor_y)

        created = _collect_new_objects(col, before)
        bpy.context.view_layer.update()
        for obj in created:
            obj.name = f"{pose}_{obj.name}"
            _parent_to_bone(obj, arm, f"Expr_{pose}")


def _build_all_props(
    col: bpy.types.Collection,
    mats: dict[str, bpy.types.Material],
    arm: bpy.types.Object,
) -> None:
    for pose in ("working", "confused", "happy"):
        before = {o.name for o in col.objects}
        C.create_pose_props(pose, col, mats)
        for obj in _collect_new_objects(col, before):
            _parent_to_bone(obj, arm, f"Prop_{pose}")


def _deg_euler(x_deg: float, y_deg: float, z_deg: float) -> Euler:
    return Euler((math.radians(x_deg), math.radians(y_deg), math.radians(z_deg)), "XYZ")


def _key(pb: bpy.types.PoseBone, frame: int, *, loc=None, rot_deg=None, scale=None) -> None:
    if loc is not None:
        pb.location = Vector(loc)
        pb.keyframe_insert("location", frame=frame)
    if rot_deg is not None:
        pb.rotation_euler = _deg_euler(*rot_deg)
        pb.keyframe_insert("rotation_euler", frame=frame)
    if scale is not None:
        pb.scale = Vector((scale, scale, scale)) if isinstance(scale, (int, float)) else Vector(scale)
        pb.keyframe_insert("scale", frame=frame)


def _ease_in_out_cubic(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return 4.0 * u * u * u if u < 0.5 else 1.0 - ((-2.0 * u + 2.0) ** 3) / 2.0


def _ease_out_cubic(u: float) -> float:
    u = max(0.0, min(1.0, u))
    return 1.0 - (1.0 - u) ** 3


def _pulse_window(t: float, start: float, end: float) -> float:
    if t <= start or t >= end:
        return 0.0
    u = (t - start) / (end - start)
    return 0.5 - 0.5 * math.cos(2.0 * math.pi * u)


def _hop_arc(u: float) -> tuple[float, float]:
    if u < 0.16:
        k = _ease_in_out_cubic(u / 0.16)
        return -0.022 * math.sin(k * math.pi), 6.0 * math.sin(k * math.pi)
    if u < 0.72:
        v = (u - 0.16) / 0.56
        h = (4.0 * v * (1.0 - v)) ** 0.82
        return 0.095 * h, -8.0 * math.sin(v * math.pi)
    w = (u - 0.72) / 0.28
    squash = math.sin(w * math.pi) * (1.0 - 0.35 * w)
    return -0.018 * squash, 5.0 * squash


def _create_animations(arm: bpy.types.Object) -> None:
    """Author 5 non-linear, organically eased 60-frame (2.5s @ 24fps) looping actions."""
    bpy.context.scene.render.fps = 24
    arm.animation_data_create()

    total_frames = 60
    frames = list(range(1, total_frames + 2, 2))

    def reset_pose():
        for pb in arm.pose.bones:
            pb.location = Vector((0.0, 0.0, 0.0))
            pb.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
            pb.scale = Vector((1.0, 1.0, 1.0))

    def key_visibility(active_pose: str, frame: int):
        for p in C.POSES:
            _key(arm.pose.bones[f"Expr_{p}"], frame, scale=1.0 if p == active_pose else 0.0001)
        for p in ("working", "confused", "happy"):
            _key(arm.pose.bones[f"Prop_{p}"], frame, scale=1.0 if p == active_pose else 0.0001)

    for pose in C.POSES:
        reset_pose()
        act = bpy.data.actions.new(pose)
        arm.animation_data.action = act

        pb_root = arm.pose.bones["Root"]
        pb_body = arm.pose.bones["Body"]
        pb_head = arm.pose.bones["Head"]
        pb_arm_l = arm.pose.bones["Arm_L"]
        pb_arm_r = arm.pose.bones["Arm_R"]
        pb_tail = arm.pose.bones["Tail"]
        pb_prop_w = arm.pose.bones["Prop_working"]
        pb_prop_c = arm.pose.bones["Prop_confused"]
        pb_prop_h = arm.pose.bones["Prop_happy"]

        for f in frames:
            t = (f - 1) / float(total_frames)
            breath = 0.5 - 0.5 * math.cos(2.0 * math.pi * t)
            breath_lag = 0.5 - 0.5 * math.cos(2.0 * math.pi * (t - 0.09))
            tail_lag = math.sin(2.0 * math.pi * (t - 0.14))

            key_visibility(pose, f)

            if pose == "idle":
                wave_env = _pulse_window(t, 0.08, 0.62)
                wave_osc = math.sin(2.0 * math.pi * ((t - 0.08) / 0.27)) if 0.08 < t < 0.62 else 0.0
                _key(pb_root, f, loc=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0))
                _key(pb_body, f, loc=(0.0, 0.018 * (breath - 0.5), 0.0), rot_deg=(2.0 * (breath - 0.5), 0.0, -2.0 * wave_env))
                _key(pb_head, f, rot_deg=(3.0 * (breath_lag - 0.5), 6.0 * wave_env, 4.5 * wave_env + 2.0 * tail_lag))
                _key(pb_arm_r, f, rot_deg=(-36.0 - 6.0 * wave_env, 0.0, -112.0 - 12.0 * wave_env + 22.0 * wave_env * wave_osc))
                _key(pb_arm_l, f, rot_deg=(-7.0 + 4.0 * (breath_lag - 0.5), 0.0, 14.0 + 4.0 * (breath - 0.5)))
                _key(pb_tail, f, rot_deg=(0.0, 18.0 * tail_lag, 6.0 * (breath - 0.5)))

            elif pose == "working":
                burst1 = _pulse_window(t, 0.04, 0.44)
                burst2 = _pulse_window(t, 0.52, 0.82)
                typing = burst1 + burst2
                enter_hit = _pulse_window(t, 0.84, 0.96)
                fast_tap = math.sin(2.0 * math.pi * t * 10.0) * typing
                _key(pb_root, f, loc=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0))
                _key(pb_body, f, loc=(0.0, 0.012 * (breath - 0.5) - 0.008 * enter_hit, 0.0), rot_deg=(4.5 + 2.0 * typing + 3.0 * enter_hit, 0.0, 0.0))
                _key(pb_head, f, rot_deg=(11.0 + 3.5 * enter_hit + 2.0 * (breath_lag - 0.5), 4.5 * math.sin(2.0 * math.pi * t), 2.5 * burst1 - 2.5 * burst2))
                _key(pb_arm_l, f, rot_deg=(-68.0 + 11.0 * fast_tap, -24.0, -18.0))
                _key(pb_arm_r, f, rot_deg=(-68.0 - 11.0 * fast_tap + 14.0 * enter_hit, 24.0, 18.0))
                _key(pb_tail, f, rot_deg=(0.0, 10.0 * tail_lag, 0.0))
                _key(pb_prop_w, f, loc=(0.0, 0.014 * (breath_lag - 0.5) - 0.006 * enter_hit, 0.0), rot_deg=(2.0 * (breath - 0.5), 0.0, 0.0), scale=1.0)

            elif pose == "confused":
                if t < 0.25:
                    tilt_k = _ease_in_out_cubic(t / 0.25)
                elif t < 0.75:
                    tilt_k = 1.0
                else:
                    tilt_k = 1.0 - _ease_in_out_cubic((t - 0.75) / 0.25)
                scratch_env = _pulse_window(t, 0.28, 0.70)
                scratch_osc = math.sin(2.0 * math.pi * ((t - 0.28) / 0.21)) if 0.28 < t < 0.70 else 0.0
                _key(pb_root, f, loc=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0))
                _key(pb_body, f, loc=(0.0, 0.012 * (breath - 0.5), 0.0), rot_deg=(0.0, 0.0, -3.5 * tilt_k))
                _key(pb_head, f, rot_deg=(-2.0 + 3.0 * tilt_k, -6.0 * tilt_k, 8.0 + 11.0 * tilt_k))
                _key(pb_arm_r, f, rot_deg=(-108.0 + 8.0 * scratch_env * scratch_osc, 14.0, -12.0 + 6.0 * tilt_k))
                _key(pb_arm_l, f, rot_deg=(-6.0, 0.0, 14.0 + 3.0 * (breath - 0.5)))
                _key(pb_tail, f, rot_deg=(0.0, 10.0 * tail_lag, 0.0))
                _key(pb_prop_c, f, loc=(0.0, 0.055 * (breath_lag - 0.5), 0.0), rot_deg=(0.0, 14.0 * tilt_k, 10.0 * (breath - 0.5)), scale=0.95 + 0.10 * tilt_k)

            elif pose == "happy":
                u = (t * 2.0) % 1.0
                hop_y, hop_pitch = _hop_arc(u)
                hop_lag_y, _ = _hop_arc((t * 2.0 - 0.08) % 1.0)
                sway = math.sin(2.0 * math.pi * t)
                _key(pb_root, f, loc=(0.0, max(-0.01, hop_y), 0.0), rot_deg=(0.0, 0.0, 0.0))
                _key(pb_body, f, loc=(0.0, 0.25 * hop_y, 0.0), rot_deg=(hop_pitch, 0.0, 5.5 * sway))
                _key(pb_head, f, rot_deg=(-7.0 + 0.6 * hop_pitch, 7.0 * sway, 6.0 * sway))
                arm_pump = 18.0 * (hop_lag_y / 0.095)
                _key(pb_arm_l, f, rot_deg=(-24.0, 0.0, 142.0 + arm_pump))
                _key(pb_arm_r, f, rot_deg=(-24.0, 0.0, -142.0 - arm_pump))
                _key(pb_tail, f, rot_deg=(0.0, 32.0 * math.sin(4.0 * math.pi * (t - 0.06)), 8.0 * sway))
                pulse = 1.0 + 0.22 * max(0.0, hop_lag_y / 0.095)
                _key(pb_prop_h, f, loc=(0.0, 0.045 * max(0.0, hop_lag_y / 0.095), 0.0), rot_deg=(0.0, 0.0, 9.0 * sway), scale=pulse)

            else:  # crying
                u = (t * 2.0) % 1.0
                sob = _ease_out_cubic(u / 0.22) if u < 0.22 else (1.0 - _ease_in_out_cubic((u - 0.22) / 0.78))
                tremble = math.sin(2.0 * math.pi * t * 6.0) * (0.35 + 0.65 * sob)
                _key(pb_root, f, loc=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0))
                _key(pb_body, f, loc=(0.0, -0.018 + 0.022 * sob, 0.0), rot_deg=(5.0 + 4.0 * sob, 0.0, 0.0))
                _key(pb_head, f, rot_deg=(12.0 + 4.5 * sob, 3.5 * tremble, 2.5 * math.sin(2.0 * math.pi * t)))
                rub = 9.0 * math.sin(2.0 * math.pi * t * 3.0)
                _key(pb_arm_l, f, rot_deg=(-106.0 + rub + 4.0 * sob, -26.0, -14.0))
                _key(pb_arm_r, f, rot_deg=(-106.0 - rub + 4.0 * sob, 26.0, 14.0))
                _key(pb_tail, f, rot_deg=(15.0 + 4.0 * sob, 3.0 * tremble, 0.0))

        trk = arm.animation_data.nla_tracks.new()
        trk.name = pose
        strip = trk.strips.new(pose, 1, act)
        strip.action_frame_start = 1
        strip.action_frame_end = total_frames + 1

    arm.animation_data.action = None
    reset_pose()


def build_animated_pig() -> None:
    C.clear_scene()
    mascot_col = C.get_or_create_collection("Mascot")
    pedestal_col = C.get_or_create_collection("Pedestal")

    mod = _load_module("build_pig", ROOT_DIR / "pig" / "build_pig.py")
    out_dir = ROOT_DIR / "pig"
    mats = mod.build_pig_materials()
    C.create_pedestal(pedestal_col, mats, radius=0.90)
    mod.create_pig_body_and_limbs("idle", mascot_col, mats)
    head_pivot = mod.create_pig_head("idle", mascot_col, mats)
    mod.create_pig_curly_tail(mascot_col, mats)

    head_pivot.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    _remove_objects_matching(
        mascot_col,
        (
            "PigArm_", "PigHandHoof_",
            "Eye_", "EyeHi", "HappyEye_", "Brow", "Blush_", "Tear",
            "IdleSmile", "HappyMouth", "ConfusedMouth", "CryingMouth", "WorkingMouth",
            "VisorSym_", "PromptChevron", "PromptCursor", "VisorWorkDot_", "VisorQ", "VisorAlert", "VisorJoy",
        ),
    )

    arm = _create_rig(mascot_col, head_z=1.47, shoulder_x=0.31)

    top_level = [o for o in mascot_col.objects if o.parent is None and o is not arm]
    for obj in top_level:
        if obj is head_pivot:
            _parent_to_bone(obj, arm, "Head")
        elif obj.name.startswith("PigCurlyTail"):
            _parent_to_bone(obj, arm, "Tail")
        elif obj.name.startswith(("PigFoot_", "PigLeg_", "PigHoof_")):
            _parent_to_bone(obj, arm, "Root")
        else:
            _parent_to_bone(obj, arm, "Body")

    _create_rest_arms(mascot_col, mats, arm, shoulder_x=0.31)
    _build_all_expressions(mascot_col, mats, arm, head_pivot, visor_y=-0.535)
    _build_all_props(mascot_col, mats, arm)
    _create_animations(arm)

    blend_path = out_dir / "serverbox_pig_animated.blend"
    glb_path = out_dir / "serverbox_pig.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    bpy.ops.object.select_all(action="DESELECT")
    for col in (mascot_col, pedestal_col):
        for obj in col.objects:
            obj.select_set(True)

    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_bake_animation=False,
        export_draco_mesh_compression_enable=True,
        export_draco_mesh_compression_level=6,
    )
    print(f"Exported animated pig: {glb_path.name} ({glb_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    build_animated_pig()
