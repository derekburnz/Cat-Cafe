"""Cat poses expressed as transforms of the cat's hinged pieces, so any cat can take them.

POSES (carried, the rescue traps) move the whole walking cat (every piece together) by `rot` degrees (Blender XYZ
Euler) about the cat-local point `pivot`, then by `offset`, and add a local rotation to the Head (with its eyes and
ears) and the Tail about their own joints. An optional `head_offset` (cat-local) moves the Head joint, for poses
where the neck sits somewhere else on the body. Working cats no longer stand up: they sit on body B
(CatCafe_Cat_<Name>_Sit), so `upright` is only the base of the bin traps.
CAT_POSES turn single pieces about their joints (cats.joints: Head, Tail, the legs) on body A or B, after an
optional `lift` of the whole cat: lick (B), loaf, sleep and eat (A). In Roblox each piece is a Model pivoted at its
joint: piece:PivotTo(piece:GetPivot() * CFrame.Angles(...)) with the manifest's angles_roblox_deg, Head first (its
eyes and ears are Models inside it and ride along), then model:PivotTo(model:GetPivot() + lift_roblox * Scale).
Positions are in studs, Blender axes (Z up, -Y forward); the manifest also gives every
value in Roblox axes.
Roblox: position (x, y, z) -> (-x, z, y), so the front is -Z (LookVector). *_angles_roblox_deg
go to CFrame.Angles(math.rad(x), math.rad(y), math.rad(z)); body_cframe_roblox is the
same Body CFrame as CFrame.new(table.unpack(t)), relative to the prop pivot or HumanoidRootPart.
For a cat with `scale` s (Ragdoll, Maine Coon 1.2) multiply every pose position by s.
"""

import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

import common

# name -> pose. Rescue poses are relative to the prop's pivot.
POSES = {
    "upright": dict(pivot=(0, 0.5, 0), rot=(-90, 0, 0), offset=(0, -1.22, 0.3), head=(90, 0, 0), tail=(80, 0, 0),
                    head_offset=(0, -0.32, 0),  # standing, -Y is up: seats the head on the chest, clear of the paws
                    note="Stands on the hind legs, the base of the bin traps. Working cats sit on body B instead "
                         "(CatCafe_Cat_<Name>_Sit)."),
    "carried": dict(pivot=(0, 0, 0), rot=(0, 0, 90), offset=(0, -1.05, -0.4), head=(-10, 0, 0), tail=(-40, 0, 0),
                    note="Cradled across the chest, facing the character's left, so the camera behind the player "
                         "sees the cat side on. Relative to the HumanoidRootPart centre (R15: 3 studs above the floor)."),
}


def _upright_at(offset, head=(90, 0, 0), note=""):
    """The upright pose moved by `offset`: the cat stands inside a bin, head and paws over the rim."""
    up = POSES["upright"]
    return dict(up, offset=tuple(a + b for a, b in zip(up["offset"], offset)), head=head, note=note)


# Rescue traps (features.md section 5): prop name -> where the stuck cat goes, relative to the prop pivot.
STUCK_POSES = {
    "CatCafe_Alley_TrashBin": _upright_at((0, -0.08, 1.25), head=(80, 0, 12),
                                          note="Stands inside the bin, front paws over the front rim, head tilted up at the player."),
    "CatCafe_Alley_GarbageBags": dict(pivot=(0, 0, 0), rot=(0, 0, 0), offset=(0.45, 0.4, 0), head=(-15, 12, 0), tail=(-10, 0, 0),
                                      note="Buried in the front bag: head and front paws out the front, tail out the back."),
    "CatCafe_Park_RescueTree": dict(pivot=(0, 0, 0), rot=(0, 0, 0), offset=(2.35, 0, 3.96), head=(20, 0, 0), tail=(-30, 0, 0),
                                    note="Draped across the Branch between the trunk and the leaf tuft, facing the tree's "
                                         "front, looking down at the player (the engineer's #200; along the branch put the "
                                         "longer cats' heads and tails in the trunk and the leaves). Place it, then "
                                         "WeldConstraint the cat Body to the Branch so it wobbles with it."),
    "CatCafe_Park_TrashCan": _upright_at((0, -0.08, 0.95), head=(80, 0, -12),
                                         note="Stands inside the can, front paws over the rim, head tilted up at the player."),
}


# Piece poses (cats.py joints). Angles are Blender XYZ degrees about each piece's joint; lift is unscaled studs.
# lick: the left front paw (LegF1) swings forward and up to the mouth and the head tips down and toward it.
# Lying down, the folded legs turn out a little so the paws show at the sides (Derek 2026-10-27; the game's
# Presets.catPoses, Animation-Engineer #291: Roblox LegF1 -90, 0, -30, LegF2 -90, 0, 30, LegB1 90, 0, -26, LegB2 90, 0, 26).
LYING_LEGS = {"LegF1": (90, 0, -30), "LegF2": (90, 0, 30), "LegB1": (-90, 0, 26), "LegB2": (-90, 0, -26)}
CAT_POSES = {
    "lick": dict(body="sit", parts={"LegF1": (-128, -14, 0), "Head": (16, 0, 14)},
                 note="Sitting, washing a paw: the left front paw up at the mouth, head tipped down to it "
                      "(Derek 2026-10-27: the paw-up sit is licking a paw)."),
    "loaf": dict(body="walk", lift=(0, 0, -0.31),
                 parts=dict(LYING_LEGS, Tail=(-38, 0, 30)),
                 note="Lying down, belly on the floor, paws folded under and turned out so they show at the sides."),
    "sleep": dict(body="walk", lift=(0, 0, -0.31),
                  parts=dict(LYING_LEGS, Head=(24, 0, 28), Tail=(-38, 0, 75)),
                  note="The loaf with the head down and turned, tail curled round the side."),
    "eat": dict(body="walk", parts={"Head": (42, 0, 0), "Tail": (-10, 0, 0)},
                note="Standing, head down to a bowl in front of the front paws."),
}


def _about(point, angles):
    """Turn by `angles` (Blender XYZ degrees) about `point`."""
    p = Vector(point)
    return Matrix.Translation(p) @ _local(angles) @ Matrix.Translation(-p)


def _piece(ob):
    return ob.name.split(".")[0].rsplit("_", 1)[-1]


def _on_head(ob):
    """The Head's own riders: eyes, ears and a Head or Face prop (props.py marks a prop with what it rides)."""
    import cats
    return _piece(ob) in cats.HEAD_PIECES or ob.get("rides") == "Head"


def cat_pose_matrices(cat_objs, pose, spec, body):
    """Object -> the matrix that puts it in a CAT_POSES pose (applied on the left of its rest matrix_world)."""
    import cats
    bpy.context.view_layer.update()                     # fresh models: matrix_world catches up with location
    joints = cats.joints(spec, body)
    k = cats.scale_of(spec, body)
    lift = Matrix.Translation(Vector(cats.pose_lift(spec, pose)) * k)
    turn = {p: _about(joints[p], a) for p, a in pose["parts"].items()}
    out = {}
    for ob in cat_objs:
        piece = _piece(ob)
        M = lift
        if _on_head(ob):
            M = M @ turn.get("Head", Matrix.Identity(4))
        out[ob] = M @ turn.get(piece, Matrix.Identity(4))
    return out


def cat_pose_copies(cat_objs, pose, spec, body, world=Matrix.Identity(4), prefix="_v_"):
    """Copies of a cat's pieces in a CAT_POSES pose, under an optional world transform."""
    mats = cat_pose_matrices(cat_objs, pose, spec, body)
    out = []
    for ob in cat_objs:
        c = ob.copy()
        c.name = prefix + ob.name
        c.matrix_world = world @ mats[ob] @ ob.matrix_world
        c.hide_render = False
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def pose_matrix(pose):
    p = Vector(pose["pivot"])
    R = Euler([math.radians(a) for a in pose["rot"]], "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector(pose["offset"])) @ Matrix.Translation(p) @ R @ Matrix.Translation(-p)


def _local(angles):
    return Euler([math.radians(a) for a in angles], "XYZ").to_matrix().to_4x4()


def _head_shift(pose):
    return Matrix.Translation(Vector(pose.get("head_offset", (0, 0, 0))))


def posed_copies(cat_objs, pose, world=Matrix.Identity(4), prefix="_v_"):
    """Copy a walking cat's pieces and put them in a POSES pose, under an optional world transform."""
    import cats
    bpy.context.view_layer.update()
    M = world @ pose_matrix(pose)
    head = next((ob for ob in cat_objs if _piece(ob) == "Head"), None)
    turn_head = (_head_shift(pose) @ head.matrix_world @ _local(pose["head"]) @ head.matrix_world.inverted()
                 if head else Matrix.Identity(4))
    out = []
    for ob in cat_objs:
        c = ob.copy()
        c.name = prefix + ob.name
        piece = _piece(ob)
        extra = Matrix.Identity(4)
        if _on_head(ob) or piece == "Head":
            extra = turn_head
        elif piece == "Tail":
            extra = ob.matrix_world @ _local(pose["tail"]) @ ob.matrix_world.inverted()
        c.matrix_world = M @ extra @ ob.matrix_world
        c.hide_render = False
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def accessory_copies(built, cat_objs, spec, body, names, world=Matrix.Identity(4), pose=None):
    """Copies of accessories in their slots (accessories.slots) on a cat, optionally in a CAT_POSES pose."""
    import accessories
    bpy.context.view_layer.update()
    slots = accessories.slots(spec, body)
    s = spec.get("scale", 1.0)
    parts = {_piece(ob): ob for ob in cat_objs}
    mats = cat_pose_matrices(cat_objs, pose, spec, body) if pose else {}
    out = []
    for n in names:
        src = built.get(f"CatCafe_Accessory_{n}")
        if not src or n not in slots:
            continue
        part, off, r = slots[n]
        host = parts[part]
        base = (world @ mats.get(host, Matrix.Identity(4)) @ host.matrix_world @ Matrix.Translation(Vector(off) * s)
                @ _local(r) @ Matrix.Scale(s, 4))
        for ob in src:
            c = ob.copy()
            c.name = "_v_" + ob.name
            c.matrix_world = base @ ob.matrix_world
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
        "head_offset_blender": list(pose.get("head_offset", (0, 0, 0))),
        "head_offset_roblox": common.to_roblox(pose.get("head_offset", (0, 0, 0))),
        "tail_angles_roblox_deg": common.euler_to_roblox(pose["tail"]),
        "note": pose.get("note", ""),
    }


def manifest_cat_pose(pose):
    """A CAT_POSES pose as the engineer reads it: which body, the lift and each piece's turn about its joint."""
    lift = pose.get("lift", (0, 0, 0))
    return {
        "body": pose["body"],
        "lift_blender": list(lift), "lift_roblox": common.to_roblox(lift),
        "parts": {p: {"xyz_deg_blender": list(a), "angles_roblox_deg": common.euler_to_roblox(a)}
                  for p, a in pose["parts"].items()},
        "note": pose.get("note", ""),
    }


# A default R15 character's HumanoidRootPart centre is 3 studs above the floor (HipHeight 2 + half the 2-stud HRP)
HRP_HEIGHT = 3.0


def render_pose_previews(built, mat, docs, samples=32, cat="CatCafe_Cat_Tabby"):
    """Rescue props with the stuck cat, the accessory set, the role outfits on sitting cats, every piece pose and
    the carried pose."""
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
    import accessories
    import cats
    spec = cats.ROSTER[cats.parse(cat)[0]]
    # accessory set on a walking cat (Glasses, Hat)
    copies = posed_copies(cat_objs, dict(pivot=(0, 0, 0), rot=(0, 0, 0), offset=(0, 0, 0), head=(0, 0, 0), tail=(0, 0, 0)))
    acc = accessory_copies(built, cat_objs, spec, "walk", ("Glasses", "Hat"))
    path = os.path.join(docs, "previews", "CatCafe_Accessory_Set.png")
    common.hide_all_meshes()
    common.show(copies + acc)
    common.render_preview(copies + acc, path, samples=samples, warm=True, azimuth=25, elevation=12)
    cleanup(copies + acc)
    made["CatCafe_Accessory_Set"] = path
    sit_objs = built.get(cat + "_Sit")
    if sit_objs:
        # the four role outfits on sitting cats, in role order (barista, waiter, greeter, entertainer)
        objs = []
        still = dict(body="sit", parts={})
        for i, role in enumerate(("barista", "waiter", "greeter", "entertainer")):
            world = Matrix.Translation(((i - 1.5) * 1.5, 0, 0))
            objs += cat_pose_copies(sit_objs, still, spec, "sit", world=world)
            objs += accessory_copies(built, sit_objs, spec, "sit", accessories.ROLE_OUTFITS[role], world=world)
        path = os.path.join(docs, "previews", "Pose_Uniforms.png")
        common.hide_all_meshes()
        common.show(objs)
        common.render_preview(objs, path, samples=samples, warm=True, azimuth=20, elevation=10, margin=0.8)
        cleanup(objs)
        made["Pose_Uniforms"] = path
        # every piece pose next to the two bodies at rest: walk, sit, then CAT_POSES in order
        objs = []
        row = [("walk", dict(body="walk", parts={})), ("sit", still)] + [(k, v) for k, v in CAT_POSES.items()]
        for i, (_k, pose) in enumerate(row):
            world = Matrix.Translation(((i - (len(row) - 1) / 2) * 1.6, 0, 0))
            src = cat_objs if pose["body"] == "walk" else sit_objs
            objs += cat_pose_copies(src, pose, spec, pose["body"], world=world)
        path = os.path.join(docs, "previews", "Pose_Cats.png")
        common.hide_all_meshes()
        common.show(objs)
        common.render_preview(objs, path, samples=samples, warm=True, azimuth=28, elevation=14, margin=0.7)   # a long row
        cleanup(objs)
        made["Pose_Cats"] = path
    # carried, at its height in a character's arms (no stand-in figure in renders: Derek, 2026-10-27)
    copies = posed_copies(cat_objs, POSES["carried"], world=Matrix.Translation((0, 0, HRP_HEIGHT)))
    path = os.path.join(docs, "previews", "Pose_Carried.png")
    common.hide_all_meshes()
    common.show(copies)
    common.render_preview(copies, path, samples=samples, warm=True, azimuth=25, elevation=8, floor=False)
    cleanup(copies)
    made["Pose_Carried"] = path
    return made
