"""UI pictures rendered from the models: a straight-on view on a transparent background with a dark outline, so a
picture reads on any panel. Each lands in assets/cat-cafe/exports/icons/<Icon>.png, ready for the upload-image
workflow (Actions) to turn into an rbxassetid for an ImageLabel.

    python icons.py [--only GoldenFish]

  CatCafe_Icon_GoldenFish   the golden fish coin's cat face (coins.py), for the HUD counter, prize chips and prices
  CatCafe_Icon_Crate_<Pool>[_Gold]   each Cafe Crate and golden crate (crates.py), three-quarter view
  CatCafe_Icon_StarTreat    the Star Treat (items.py), the Golden Fish Market's food
  CatCafe_Icon_Perk_<Perk>  the market perks: GoldenEspresso (a gold espresso), BigBowl (a heaped bowl and a quick
                            clock), ExtraDecorSpot (a plant on a new decor spot with a plus)
  CatCafe_Icon_Net_L<n>     the catching net at each level (items.py)
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
import crates  # noqa: E402
import items  # noqa: E402
import potions  # noqa: E402
from common import RB  # noqa: E402

OUT = os.path.join(ROOT, "assets", "cat-cafe", "exports", "icons")
INK, GOLD_INK = (0.24, 0.16, 0.12), (0.42, 0.24, 0.04)
QUARTER = (-32.0, 24.0)          # (yaw, pitch) in degrees: the front and the right side, from a little above


def _perk_golden_espresso(mat):
    """A gold espresso cup on its saucer, steaming, with two glints."""
    b = RB()
    b.cyl((0, 0.05, 0), 0.8, 0.1, "gold_mid", segments=16)
    b.cyl((0, 0.13, 0), 0.6, 0.06, "gold_light", segments=16)
    b.cyl((0, 0.5, 0), 0.4, 0.7, "gold_light", r2=0.5, segments=16)
    b.cyl((0, 0.86, 0), 0.44, 0.02, "choco", segments=16)
    b.b.ring(RB.p(0.56, 0.52, 0), 0.2, 0.07, 0.1, "gold_mid", segments=10, bevel=False, rot=(math.radians(90), "X"))
    for (x, y, r) in ((-0.12, 1.12, 0.14), (0.08, 1.34, 0.12), (-0.06, 1.55, 0.1)):
        b.ball((x, y, 0), r, "offwhite")
    for (x, y) in ((-0.38, 0.62), (0.3, 0.3)):
        b.box((x, y, -0.5), (0.08, 0.08, 0.02), "sparkle")
    return [b.finalize("CatCafe_IconArt_GoldenEspresso", mat)]


def _perk_big_bowl(mat):
    """A wide red bowl heaped with kibble and a little clock that says the wait is short."""
    b = RB()
    b.cyl((0, 0.06, 0), 0.85, 0.12, "bowl_red", segments=16)
    b.b.ring(RB.p(0, 0.3, 0), 1.05, 0.2, 0.5, "bowl_red", segments=16, bevel=False)
    b.b.ring(RB.p(0, 0.44, 0), 1.08, 0.08, 0.08, "offwhite", segments=16, bevel=False)
    b.cyl((0, 0.5, 0), 0.88, 0.1, "kibble", segments=16)
    for k, (r, n, y) in enumerate(((0.62, 9, 0.62), (0.32, 6, 0.74), (0.0, 1, 0.84))):
        for i in range(n):
            a = 2 * math.pi * i / n + 0.4 * k
            b.ball((r * math.cos(a), y, r * math.sin(a)), 0.17, "kibble" if (i + k) % 2 else "treat_tan")
    b.cyl((-0.9, 1.05, -0.62), 0.4, 0.1, "mint", axis="Z", segments=16)
    b.cyl((-0.9, 1.05, -0.68), 0.32, 0.02, "offwhite", axis="Z", segments=16)
    b.span((-0.92, 1.03, -0.71), (-0.88, 1.29, -0.69), "fur_black")
    b.span((-1.1, 1.03, -0.71), (-0.88, 1.07, -0.69), "fur_black")
    return [b.finalize("CatCafe_IconArt_BigBowl", mat)]


def _perk_extra_decor_spot(mat):
    """A potted plant standing on a fresh decor spot, a plus floating beside it."""
    b = RB()
    b.span((-0.95, 0.0, -0.95), (0.95, 0.06, 0.95), "mint")
    b.span((-0.8, 0.06, -0.8), (0.8, 0.09, 0.8), "sparkle")
    b.cyl((0, 0.4, 0), 0.32, 0.62, "terracotta", r2=0.4, segments=12)
    b.cyl((0, 0.74, 0), 0.34, 0.04, "choco", segments=12)
    for (x, y, z, r) in ((0, 1.1, 0, 0.32), (-0.26, 0.95, -0.1, 0.22), (0.27, 0.98, 0.05, 0.24), (0.05, 1.38, -0.05, 0.2)):
        b.ball((x, y, z), r, "leaf_green" if r > 0.21 else "leaf_dark")
    b.span((-0.95, 1.12, -0.52), (-0.75, 1.72, -0.36), "rarity_legend")  # the arms abut the upright, one depth,
    for x0, x1 in ((-1.15, -0.95), (-0.75, -0.55)):                         # so no outline crosses the middle
        b.span((x0, 1.32, -0.52), (x1, 1.52, -0.36), "rarity_legend")
    return [b.finalize("CatCafe_IconArt_ExtraDecorSpot", mat)]


# icon -> (builder, outline colour, outline width in pixels at 512, (yaw, pitch) of the view)
ICONS = {
    "CatCafe_Icon_GoldenFish": (coins.build_fish_coin, GOLD_INK, 10, (0.0, 0.0)),
    **{f"CatCafe_Icon_Crate_{p}{'_Gold' if g else ''}": ((lambda m, p=p, g=g: crates.build_crate(p, m, g)),
                                                         GOLD_INK if g else INK, 10, QUARTER)
       for p in crates.POOLS for g in (False, True)},
    "CatCafe_Icon_StarTreat": (items.build_star_treat, INK, 10, (-20.0, 12.0)),
    "CatCafe_Icon_Perk_GoldenEspresso": (_perk_golden_espresso, GOLD_INK, 10, (-20.0, 22.0)),
    "CatCafe_Icon_Perk_BigBowl": (_perk_big_bowl, INK, 10, (-20.0, 28.0)),
    "CatCafe_Icon_Perk_ExtraDecorSpot": (_perk_extra_decor_spot, INK, 10, (-28.0, 26.0)),
    **{f"CatCafe_Icon_Net_L{n}": ((lambda m, n=n: items.build_net(n, m)), INK, 10, (-62.0, 40.0)) for n in (1, 2, 3)},
    **{f"CatCafe_Icon_Potion_{k}": ((lambda m, k=k: potions.build_potion(k, m)), INK, 10, (8.0, 10.0))
       for k in potions.POTIONS},
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


def _camera(objs, view=(0.0, 0.0)):
    """Orthographic, looking at the model's front (-Y in Blender) turned `yaw` degrees about the up axis and
    tilted `pitch` degrees down, framing every vertex with PAD around."""
    yaw, pitch = view
    cd = bpy.data.cameras.get("_IconCam") or bpy.data.cameras.new("_IconCam")
    cam = bpy.data.objects.get("_IconCam") or bpy.data.objects.new("_IconCam", cd)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    cd.type = "ORTHO"
    cd.clip_start, cd.clip_end = 0.01, 100.0
    cam.rotation_euler = (math.radians(90 - pitch), 0, math.radians(yaw))
    bpy.context.view_layer.update()
    R = cam.rotation_euler.to_matrix()
    right, up, fwd = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
    pts = [ob.matrix_world @ v.co for ob in objs for v in ob.data.vertices]
    us, vs = [p.dot(right) for p in pts], [p.dot(up) for p in pts]
    cd.ortho_scale = max(max(us) - min(us), max(vs) - min(vs)) * (1 + 2 * PAD)
    centre = right * (max(us) + min(us)) / 2 + up * (max(vs) + min(vs)) / 2
    depth = min(p.dot(fwd) for p in pts)
    cam.location = centre + fwd * (depth - 10.0)
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
    build, colour, width, view = ICONS[name]
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
    _camera(objs, view)
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
