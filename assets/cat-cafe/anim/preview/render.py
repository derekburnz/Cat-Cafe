"""Render the frames dump.luau wrote (the game's own cat motion on the Part cats) to PNG frames, an MP4 and a strip.

  python render.py <frames.json> <out dir> [--samples 12] [--res 480] [--strip 6]

Draws each part from its Roblox shape the way rbx_preview.py does, moved and sized per frame, plus the floating z's
where Cats.luau's BillboardGui would put them (up and to the right of the head on screen). Cycles on the CPU, as
the cloud threads have no GPU. Needs the bpy module (pip install bpy) and ffmpeg for the MP4.
"""

import argparse
import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.path.abspath(os.path.join(HERE, "..", "..", "blender"))
if BLENDER not in sys.path:
    sys.path.insert(0, BLENDER)

import bpy  # noqa: E402
import bmesh  # noqa: E402,I001  (bmesh only imports once bpy has)
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402

CT = common.TO_ROBLOX.transposed().to_4x4()  # Roblox -> Blender
OFFWHITE = (1.0, 0.976, 0.949)  # palette offwhite, the z's fill
DARK_WOOD = (94 / 255, 70 / 255, 52 / 255)  # the z's outline
# Where the camera sits for each view, as a direction from the cat in Roblox axes (the cat faces -Z, +X is its right).
# "three" is Model-Agent's pose sheet camera (azimuth 35, elevation 22: front left, the face towards the camera) and
# "side" sees the left side, a little from the front, so the cat faces left on screen as in the sheets.
VIEWS = {
    "side": Vector((-1.0, 0.3, -0.45)),
    "front": Vector((0.0, 0.3, -1.0)),
    "three": Vector((-0.53, 0.37, -0.76)),
}


def linear(rgb):
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)


def to_blender(v):
    return (CT @ Vector((v[0], v[1], v[2], 1.0))).to_3d()


def cframe_matrix(cf):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def unit_mesh(shape, name):
    """A shape at unit size; the object's scale gives it the part's Size each frame."""
    bm = bmesh.new()
    if shape == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
    elif shape == "Cylinder":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.5, radius2=0.5, depth=1,
                              matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))  # along local X, as in Roblox
    elif shape == "Wedge":
        pts = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (0.5, 0.5, 0.5),
               (-0.5, 0.5, 0.5)]
        vs = [bm.verts.new(p) for p in pts]
        for f in ((0, 1, 2, 3), (3, 2, 4, 5), (0, 3, 5), (1, 4, 2), (0, 5, 4, 1)):
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def part_scale(shape, size):
    sx, sy, sz = size
    if shape == "Ball":
        d = min(sx, sy, sz)
        return d, d, d
    if shape == "Cylinder":
        d = min(sy, sz)
        return sx, d, d
    return sx, sy, sz


def material(info):
    m = bpy.data.materials.new("part")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*linear(info["color"]), 1)
    bsdf.inputs["Roughness"].default_value = 0.6
    if info.get("transparency", 0) > 0:
        bsdf.inputs["Alpha"].default_value = 1 - info["transparency"]
    if info.get("material") == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*linear(info["color"]), 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


def z_material(rgb):
    """Unlit (LightInfluence 0 in the game) and fading: a mix of a transparent and an emission shader."""
    m = bpy.data.materials.new("z")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    clear = nodes.new("ShaderNodeBsdfTransparent")
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs["Color"].default_value = (*linear(rgb), 1)
    glow.inputs["Strength"].default_value = 1.0
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(glow.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    return m, mix.inputs["Fac"]


def z_text(text, rgb, outline):
    curve = bpy.data.curves.new("z", type="FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = 1.0
    if outline:
        curve.offset = 0.06
    mat, fac = z_material(rgb)
    curve.materials.append(mat)
    ob = bpy.data.objects.new("z", curve)
    bpy.context.scene.collection.objects.link(ob)
    return ob, fac


def checker_floor():
    """Two-stud squares in two floor tones on the preview floor."""
    mat = bpy.data.materials["_PreviewFloor"]
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coords = nodes.new("ShaderNodeTexCoord")
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 0.5
    base = nodes["Principled BSDF"].inputs["Base Color"].default_value
    checker.inputs["Color1"].default_value = base
    checker.inputs["Color2"].default_value = (base[0] * 0.85, base[1] * 0.85, base[2] * 0.85, 1)
    links.new(coords.outputs["Object"], checker.inputs["Vector"])
    links.new(checker.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])


def setup_camera(res, lens=50):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("_Cam")
    cd.lens = lens
    cd.clip_start = 0.05
    cam = bpy.data.objects.new("_Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res, res * 3 // 4
    return cam


def aim(cam, center, direction, radius):
    dist = radius * 1.25 / math.sin(cam.data.angle_y / 2)  # the frame is wider than tall
    cam.location = center + direction.normalized() * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    p = argparse.ArgumentParser()
    p.add_argument("frames")
    p.add_argument("out")
    p.add_argument("--samples", type=int, default=12)
    p.add_argument("--res", type=int, default=480)
    p.add_argument("--strip", type=int, default=6, help="frames in the contact strip")
    p.add_argument("--every", type=int, default=1, help="render every nth frame")
    p.add_argument("--zoom", type=float, default=0.65, help="under 1 frames the cat tighter")
    args = p.parse_args(argv)

    with open(args.frames) as f:
        data = json.load(f)
    frames = data["frames"][:: args.every]
    fps = data["fps"] / args.every
    name = os.path.splitext(os.path.basename(args.frames))[0]
    out = os.path.join(args.out, name)
    os.makedirs(out, exist_ok=True)

    common.reset_scene()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = args.samples
    sc.cycles.use_denoising = True
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    common._ensure_floor()
    common._ensure_lights(True)
    if frames[0]["pivot"] != frames[-1]["pivot"]:
        checker_floor()  # so a walking cat is seen to move while the camera follows it

    objs = []
    for i, info in enumerate(data["parts"]):
        ob = bpy.data.objects.new("part%d" % i, unit_mesh(info["shape"], "part%d" % i))
        ob.data.materials.append(material(info))
        sc.collection.objects.link(ob)
        objs.append(ob)

    # Frame the cat as it lies in its first frame, from the scenario's view; a walking cat is followed.
    first = frames[0]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for part in first["parts"]:
        c = Vector(part["cf"][:3])
        r = Vector(part["size"]) / 2
        lo = Vector(map(min, lo, c - r))
        hi = Vector(map(max, hi, c + r))
    has_z = any(fr.get("zs") for fr in frames)
    if has_z:
        hi.y += 1.6  # room for the z's above the head
    center_rbx = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.6) * args.zoom
    view = VIEWS.get(data.get("camera") or "three", VIEWS["three"])
    cam = setup_camera(args.res)
    view_b = (CT.to_3x3() @ view)

    zs = []
    if has_z:
        for k in range(3):
            text = "Z" if k == 2 else "z"
            stroke, stroke_fac = z_text(text, DARK_WOOD, True)
            fill, fill_fac = z_text(text, OFFWHITE, False)
            zs.append((stroke, stroke_fac, fill, fill_fac))
    nap = data.get("nap")

    paths = []
    for n, frame in enumerate(frames):
        pivot = Vector(frame["pivot"])
        aim(cam, to_blender(center_rbx + pivot), view_b, radius)
        for ob, info, part in zip(objs, data["parts"], frame["parts"]):
            sx, sy, sz = part_scale(info["shape"], part["size"])
            ob.matrix_world = CT @ cframe_matrix(part["cf"]) @ Matrix.Diagonal((sx, sy, sz, 1))
        bpy.context.view_layer.update()
        cam_rot = cam.matrix_world.to_3x3()
        right, up, back = cam_rot.col[0], cam_rot.col[1], cam_rot.col[2]
        for k, (stroke, stroke_fac, fill, fill_fac) in enumerate(zs):
            z = (frame.get("zs") or [None] * 3)[k] if frame.get("zs") else None
            if z is None or data.get("zOn") is None:
                stroke_fac.default_value = fill_fac.default_value = 0
                continue
            head = to_blender(frame["parts"][data["zOn"] - 1]["cf"][:3])
            box_w, box_h = nap["box"]
            middle = head + right * nap["offset"][0] + up * nap["offset"][1]
            at = middle + right * ((z["x"] - 0.5) * box_w) + up * ((0.5 - z["y"]) * box_h)
            height = nap["zSize"][1] * z["size"] * box_h
            spin = Matrix.Rotation(math.radians(-z["tilt"]), 4, "Z")
            basis = cam_rot.to_4x4() @ spin @ Matrix.Diagonal((height, height, height, 1))
            fill.matrix_world = Matrix.Translation(at) @ basis
            stroke.matrix_world = Matrix.Translation(at - back * 0.01) @ basis
            alpha = 1 - z["fade"]
            fill_fac.default_value = alpha
            stroke_fac.default_value = alpha * (1 - (0.3 + 0.7 * z["fade"]))  # TextStrokeTransparency
        path = os.path.join(out, "%04d.png" % n)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
        print("frame", n + 1, "of", len(frames), flush=True)

    mp4 = os.path.join(args.out, name + ".mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i",
                    os.path.join(out, "%04d.png"), "-pix_fmt", "yuv420p", "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
                    mp4], check=True)
    gif = os.path.join(args.out, name + ".gif")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i",
                    os.path.join(out, "%04d.png"), "-vf",
                    "fps=12,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse", gif], check=True)
    strip = os.path.join(args.out, name + "_strip.png")
    make_strip(paths, frames, args.strip, strip)
    print("wrote", mp4, gif, strip)


def make_strip(paths, frames, count, path):
    """Evenly spaced frames side by side, each labelled with its time."""
    from PIL import Image, ImageDraw

    picks = [round(i * (len(paths) - 1) / max(count - 1, 1)) for i in range(count)]
    tiles = [Image.open(paths[i]).convert("RGB") for i in picks]
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * len(tiles), h), (255, 249, 242))
    draw = ImageDraw.Draw(sheet)
    for k, (i, tile) in enumerate(zip(picks, tiles)):
        sheet.paste(tile, (k * w, 0))
        draw.text((k * w + 8, 6), "%.2f s" % frames[i]["t"], fill=(94, 70, 52))
    sheet.save(path)


if __name__ == "__main__":
    main()
