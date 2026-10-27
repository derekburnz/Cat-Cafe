"""UI pictures rendered from the models: a straight-on view on a transparent background with a dark outline, so a
picture reads on any panel. Each lands in assets/cat-cafe/exports/icons/<Icon>.png, ready for the upload-image
workflow (Actions) to turn into an rbxassetid for an ImageLabel.

    python icons.py [--only GoldenFish]

  CatCafe_Icon_GoldenFish   the golden fish coin's cat face (coins.py), for the HUD counter, prize chips and prices
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import coins  # noqa: E402
import common  # noqa: E402

OUT = os.path.join(ROOT, "assets", "cat-cafe", "exports", "icons")
# icon -> (builder, outline colour, outline width in pixels at 512)
ICONS = {
    "CatCafe_Icon_GoldenFish": (coins.build_fish_coin, (0.42, 0.24, 0.04), 10),
}
SIZE, PAD = 512, 0.05


def _lights():
    """A bright, even studio light from the upper left front, and a white world so the colours stay true."""
    for name in ("_IconKey", "_IconFill"):
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)
    key = bpy.data.lights.new("_IconKey", "SUN")
    key.energy, key.angle = 2.6, math.radians(10)
    ko = bpy.data.objects.new("_IconKey", key)
    ko.rotation_euler = (math.radians(55), 0, math.radians(-30))
    bpy.context.scene.collection.objects.link(ko)
    fill = bpy.data.lights.new("_IconFill", "SUN")
    fill.energy = 0.8
    fo = bpy.data.objects.new("_IconFill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(40))
    bpy.context.scene.collection.objects.link(fo)
    w = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.7


def _camera(objs):
    """Orthographic, looking at the model's front (-Y in Blender) and framing it with PAD around."""
    lo, hi = common.bounds(objs)
    cd = bpy.data.cameras.get("_IconCam") or bpy.data.cameras.new("_IconCam")
    cam = bpy.data.objects.get("_IconCam") or bpy.data.objects.new("_IconCam", cd)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cd.type = "ORTHO"
    cd.ortho_scale = max(hi.x - lo.x, hi.z - lo.z) * (1 + 2 * PAD)
    cd.clip_start, cd.clip_end = 0.01, 100.0
    cam.location = Vector(((lo.x + hi.x) / 2, lo.y - 10.0, (lo.z + hi.z) / 2))
    cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = cam


def _outline(path, colour, width):
    """Paint a solid outline of `width` pixels behind the picture, from its alpha."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    a = px[:, :, 3]
    grown = a.copy()
    for dy in range(-width, width + 1):
        for dx in range(-width, width + 1):
            if dx * dx + dy * dy <= width * width:
                grown = np.maximum(grown, np.roll(np.roll(a, dy, 0), dx, 1))
    out = np.empty_like(px)
    k = a[:, :, None]                                  # the picture over its outline (straight alpha)
    out[:, :, :3] = px[:, :, :3] * k + np.array(colour, dtype=np.float32) * (1 - k)
    out[:, :, 3] = grown
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render_icon(name, mat, samples=48):
    build, colour, width = ICONS[name]
    objs = build(mat)
    common.hide_all_meshes()
    common.show(objs)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    fl = bpy.data.objects.get("_PreviewFloor")
    if fl:
        fl.hide_render = True
    _lights()
    _camera(objs)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    _outline(path, colour, width)
    for ob in objs:
        bpy.data.objects.remove(ob, do_unlink=True)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    wanted = [w for w in args.only.split(",") if w]
    common.reset_scene()
    mat = common.palette_material(os.path.join(ROOT, "assets", "cat-cafe", "exports", "CatCafe_Palette.png"))
    for name in ICONS:
        if not wanted or any(w in name for w in wanted):
            print("icon", render_icon(name, mat), flush=True)


if __name__ == "__main__":
    main()
