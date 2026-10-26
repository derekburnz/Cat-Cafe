"""Cat poses expressed as transforms of the three cat parts, so any cat can take them.

A pose moves the whole cat (Body, Head, Tail together) by `rot` degrees (Blender XYZ
Euler) about the cat-local point `pivot`, then by `offset`, and adds a local rotation
to the Head and the Tail about their own joints. Positions are in studs, Blender axes
(Z up, -Y forward); the manifest also gives every value in Roblox axes.
Roblox: position (x, y, z) -> (-x, z, y), so the front is -Z (LookVector). *_angles_roblox_deg
go to CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)); body_cframe_roblox is the
same Body CFrame as CFrame.new(table.unpack(t)), relative to the prop pivot or HumanoidRootPart.
"""

import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

import common

# name -> pose. Rescue poses are relative to the prop's pivot.
POSES = {
    "upright": dict(pivot=(0, 0.5, 0), rot=(-90, 0, 0), offset=(0, 0, 0.3), head=(90, 0, 0), tail=(80, 0, 0),
                    note="Stands on the hind legs. Same parts; Head pitched back to face forward. Accessories keep their offsets."),
    "carried": dict(pivot=(0, 0, 0), rot=(0, 0, 90), offset=(0, -1.05, -0.4), head=(-10, 0, 0), tail=(-40, 0, 0),
                    note="Cradled across the chest, facing the character's left, so the camera behind the player "
                         "sees the cat side on. Relative to the HumanoidRootPart centre (R15: 3 studs above the floor)."),
}
STUCK_POSES = {
    "CatCafe_Alley_StuckTree": dict(pivot=(0, 0, 0), rot=(0, 20, 0), offset=(1.4, 0, 4.4), head=(30, 0, 0), tail=(10, 0, 0),
                                    note="Clings to the low branch, rolled toward the trunk, looking down."),
    "CatCafe_Alley_StuckBox": dict(pivot=(0, 0, 0), rot=(0, 0, 180), offset=(0, -0.6, 0), head=(0, 0, 0), tail=(30, 0, 0),
                                   note="Head inside the box opening (hidden by the box walls), tail up."),
    "CatCafe_Alley_Drainpipe": dict(pivot=(0, 0, 0), rot=(0, 0, 0), offset=(0, -2.0, 0.0), head=(-10, 0, 0), tail=(60, 0, 0),
                                    note="Body inside the outlet, head poking out of the open end, tail against the back."),
}


def pose_matrix(pose):
    p = Vector(pose["pivot"])
    R = Euler([math.radians(a) for a in pose["rot"]], "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(pose["offset"])) @ Matrix.Translation(p) @ R @ Matrix.Translation(-p)


def _local(angles):
    return Euler([math.radians(a) for a in angles], "XYZ").to_matrix().to_4x4()


def posed_copies(cat_objs, pose, world=Matrix.Identity(4), prefix="_v_"):
    """Copy a cat's parts and put them in `pose`, under an optional world transform."""
    M = world @ pose_matrix(pose)
    out = []
    for ob in cat_objs:
        c = ob.copy()
        c.name = prefix + ob.name
        extra = Matrix.Identity(4)
        if ob.name.endswith("_Head"):
            extra = _local(pose["head"])
        elif ob.name.endswith("_Tail"):
            extra = _local(pose["tail"])
        c.matrix_world = M @ ob.matrix_world @ extra
        c.hide_render = False
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def accessory_copies(built, cat_objs, world=Matrix.Identity(4), pose=None, names=("Glasses", "BowTie", "Apron", "Hat")):
    """Copies of accessories attached to a cat (optionally posed) for previews."""
    import accessories
    import cats
    out = []
    parts = {ob.name.split("_")[-1]: ob for ob in cat_objs}
    M = world @ (pose_matrix(pose) if pose else Matrix.Identity(4))
    for n in names:
        src = built.get(f"CatCafe_Accessory_{n}")
        if not src:
            continue
        part, off = accessories.ATTACH[n]
        acc_rot = Matrix.Identity(4)
        if pose is POSES["upright"] and n in accessories.ATTACH_UPRIGHT:
            part, off, r = accessories.ATTACH_UPRIGHT[n]
            acc_rot = _local(r)
        extra = Matrix.Identity(4)
        if pose and part == "Head":
            extra = _local(pose["head"])
        elif pose and part == "Tail":
            extra = _local(pose["tail"])
        base = parts[part].matrix_world @ extra @ Matrix.Translation(Vector(off)) @ acc_rot
        for ob in src:
            c = ob.copy()
            c.name = "_v_" + ob.name
            c.matrix_world = M @ base
            c.hide_render = False
            bpy.context.scene.collection.objects.link(c)
            out.append(c)
    return out


def cleanup(objs):
    for ob in objs:
        bpy.data.objects.remove(ob, do_unlink=True)


def manifest_pose(pose):
    """Pose as the engineer reads it: Body CFrame relative to the prop pivot plus local part angles."""
    M = pose_matrix(pose)
    loc = M.to_translation()
    pos = common.to_roblox(loc)
    angles, Rr = common.rotation_to_roblox(M)
    return {
        "body_position_blender": [round(v, 2) for v in loc],
        "body_rotation_xyz_deg_blender": [round(math.degrees(a), 1) for a in M.to_euler("XYZ")],
        "head_local_xyz_deg_blender": list(pose["head"]), "tail_local_xyz_deg_blender": list(pose["tail"]),
        "body_position_roblox": pos,
        "body_angles_roblox_deg": angles,
        "body_cframe_roblox": pos + [round(Rr[i][j], 4) + 0.0 for i in range(3) for j in range(3)],
        "head_angles_roblox_deg": common.euler_to_roblox(pose["head"]),
        "tail_angles_roblox_deg": common.euler_to_roblox(pose["tail"]),
        "note": pose.get("note", ""),
    }


# R15-sized stand-in, floor at z 0, HumanoidRootPart centre at z 3 (HipHeight 2 + half the 2-stud HRP)
HRP_HEIGHT = 3.0


def r15_proxy(mat):
    b = common.Builder()
    for x in (-0.5, 0.5):
        b.box((x, 0, 1.0), (0.9, 1.0, 2.0), "concrete_dark", bevel=False)       # legs
    b.box((0, 0, 3.1), (2.0, 1.0, 2.2), "concrete_dark", bevel=False)          # torso
    b.box((0, 0, 4.85), (1.2, 1.2, 1.2), "concrete_dark", bevel=False)         # head
    for x in (-1.5, 1.5):
        b.box((x, 0, 3.2), (1.0, 1.0, 2.0), "concrete_dark", bevel=False)       # arms
    return b.finalize("_Proxy_R15", mat)


def render_pose_previews(built, mat, docs, samples=32, cat="CatCafe_Cat_Tabby"):
    """Rescue props with the stuck cat, the accessory set, the upright and carried poses."""
    cat_objs = built.get(cat)
    if not cat_objs:
        return {}
    made = {}
    for prop, pose in STUCK_POSES.items():
        objs = built.get(prop)
        if not objs:
            continue
        copies = posed_copies(cat_objs, pose)
        path = os.path.join(docs, "previews", prop + ".png")
        common.hide_all_meshes()
        common.show(objs + copies)
        common.render_preview(objs + copies, path, samples=samples, warm=False, floor=True, azimuth=25, elevation=18)
        cleanup(copies)
        made[prop] = path
    # accessory set on a standing cat
    copies = posed_copies(cat_objs, dict(pivot=(0, 0, 0), rot=(0, 0, 0), offset=(0, 0, 0), head=(0, 0, 0), tail=(0, 0, 0)))
    acc = accessory_copies(built, cat_objs)
    path = os.path.join(docs, "previews", "CatCafe_Accessory_Set.png")
    common.hide_all_meshes()
    common.show(copies + acc)
    common.render_preview(copies + acc, path, samples=samples, warm=True, azimuth=25, elevation=12)
    cleanup(copies + acc)
    made["CatCafe_Accessory_Set"] = path
    # upright test with apron, bow tie and glasses
    pose = POSES["upright"]
    copies = posed_copies(cat_objs, pose)
    acc = accessory_copies(built, cat_objs, pose=pose, names=("Glasses", "BowTie", "Apron"))
    path = os.path.join(docs, "previews", "Pose_Upright.png")
    common.hide_all_meshes()
    common.show(copies + acc)
    common.render_preview(copies + acc, path, samples=samples, warm=True, azimuth=25, elevation=10)
    cleanup(copies + acc)
    made["Pose_Upright"] = path
    # carried, against an R15-sized stand-in
    proxy = r15_proxy(mat)
    copies = posed_copies(cat_objs, POSES["carried"], world=Matrix.Translation((0, 0, HRP_HEIGHT)))
    path = os.path.join(docs, "previews", "Pose_Carried.png")
    common.hide_all_meshes()
    common.show([proxy] + copies)
    common.render_preview([proxy] + copies, path, samples=samples, warm=True, azimuth=25, elevation=8)
    cleanup(copies + [proxy])
    made["Pose_Carried"] = path
    return made
