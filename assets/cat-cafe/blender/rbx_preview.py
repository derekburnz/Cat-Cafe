"""Render the Part-built models in assets/cat-cafe/rbx/ the way Roblox will draw them.

Rebuilds each .model.json from Roblox's own shapes (Block, Ball, Cylinder along local X, WedgePart tall at +Z,
SpecialMesh Sphere) so a wrong axis or a missing part shows up before anyone opens Studio.

  python rbx_preview.py [--only Counter,Tabby] [--out docs/concepts/cat-cafe/rbx] [--sheet]
"""

import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
import bmesh  # noqa: E402,I001
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CT = common.TO_ROBLOX.transposed()     # Roblox -> Blender
_mats = {}


def _material(rgb, alpha, neon, metal=False):
    key = (tuple(round(c, 3) for c in rgb), alpha, neon, metal)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("rbx_%d" % len(_mats))
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = 0.3 if metal else 0.6
    if metal:
        bsdf.inputs["Metallic"].default_value = 1.0
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    if neon:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    _mats[key] = m
    return m


def _cframe(cf):
    pos = Vector(cf["CFrame"]["position"])
    rot = Matrix(cf["CFrame"]["orientation"])
    return pos, rot


def _shape(bm, cls, props, mesh_type):
    sx, sy, sz = props["Size"]
    shape = props.get("Shape", "Block")
    if cls == "WedgePart":
        pts = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2),
               (-sx / 2, -sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2), (-sx / 2, sy / 2, sz / 2)]
        vs = [bm.verts.new(p) for p in pts]
        for f in ((0, 1, 2, 3), (3, 2, 4, 5), (0, 3, 5), (1, 4, 2), (0, 5, 4, 1)):
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    elif mesh_type == "Sphere":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5,
                                  matrix=Matrix.Diagonal((sx, sy, sz, 1)))
    elif shape == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=min(sx, sy, sz) / 2)
    elif shape == "Cylinder":
        d = min(sy, sz)
        bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=d / 2, radius2=d / 2, depth=sx,
                              matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))      # Blender cone axis Z -> local X
    else:
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((sx, sy, sz, 1)))


def _walk(node, out):
    cls = node.get("className")
    if cls in ("Part", "WedgePart"):
        mesh_type = None
        for c in node.get("children", []):
            if c.get("className") == "SpecialMesh":
                mesh_type = c["properties"].get("MeshType")
        out.append((node["name"], cls, node["properties"], mesh_type))
    for c in node.get("children", []):
        _walk(c, out)


def build(path, name):
    with open(path) as f:
        tree = json.load(f)
    parts = []
    _walk(tree, parts)
    objs = []
    for i, (pname, cls, props, mesh_type) in enumerate(parts):
        bm = bmesh.new()
        _shape(bm, cls, props, mesh_type)
        pos, rot = _cframe(props["CFrame"])
        world = CT.to_4x4() @ Matrix.Translation(pos) @ rot.to_4x4()
        bmesh.ops.transform(bm, matrix=world, verts=bm.verts)
        me = bpy.data.meshes.new(f"{name}_{i}")
        bm.to_mesh(me)
        bm.free()
        transparency = props.get("Transparency", 0)
        neon = props.get("Material") == "Neon"
        if props.get("Material") == "ForceField":            # a see-through shimmer in Roblox
            transparency, neon = max(transparency, 0.6), True
        me.materials.append(_material(props["Color"], 1 - transparency, neon, props.get("Material") == "Metal"))
        ob = bpy.data.objects.new(f"{name}_{i}", me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    p = argparse.ArgumentParser()
    p.add_argument("--rbx", default=os.path.join(ROOT, "assets", "cat-cafe", "rbx"))
    p.add_argument("--out", default=os.path.join(ROOT, "docs", "concepts", "cat-cafe", "rbx"))
    p.add_argument("--only", default="")
    p.add_argument("--samples", type=int, default=24)
    p.add_argument("--azimuth", type=float, default=35)
    p.add_argument("--elevation", type=float, default=22)
    p.add_argument("--res", type=int, default=640, help="image width; height is 3/4 of it")
    args = p.parse_args(argv)
    wanted = [w.strip().lower() for w in args.only.split(",") if w.strip()]
    common.reset_scene()
    os.makedirs(args.out, exist_ok=True)
    files = sorted(f for f in os.listdir(args.rbx) if f.endswith(".model.json"))
    done = []
    for fn in files:
        name = fn[: -len(".model.json")]
        if wanted and not any(w in name.lower() for w in wanted):
            continue
        objs = build(os.path.join(args.rbx, fn), name)
        common.hide_all_meshes()
        common.show(objs)
        out = os.path.join(args.out, name + ".png")
        common.render_preview(objs, out, res=(args.res, args.res * 3 // 4), samples=args.samples,
                              warm=not name.startswith("CatCafe_Alley_"),
                              floor=True, azimuth=args.azimuth, elevation=args.elevation)
        for ob in objs:
            bpy.data.objects.remove(ob, do_unlink=True)
        done.append(out)
        print("rendered", out)
    return done


if __name__ == "__main__":
    main()
