"""UI pictures rendered from the models: a straight-on view on a transparent background with a dark outline, so a
picture reads on any panel. Each lands in assets/cat-cafe/exports/icons/<Icon>.png, ready for the upload-image
workflow (Actions) to turn into an rbxassetid for an ImageLabel.

    python icons.py [--only GoldenFish]

  CatCafe_Icon_GoldenFish   the one Golden Fish picture (F97): a shiny gold fish (icon_art.py), for the HUD counter,
                            prices, prize chips, toasts and the Market badge
  CatCafe_Icon_Crate_<Pool>[_Gold]   each Cafe Crate and golden crate (crates.py), three-quarter view
  CatCafe_Icon_<Food>       the seven foods by game id: Kibble, Tuna, Sardines, Salmon, Caviar, MoonMilk, StarTreat
                            (icon_art.py, F97 section 3)
  CatCafe_Icon_Perk_<Perk>  the Golden Fish Market perks: GoldenEspresso (a paw in the foam), BigBowl (a "-2:00" tag),
                            ExtraDecorSpot (a dotted square, a plus and a tiny plant) (icon_art.py)
  CatCafe_Icon_Coins, _Spin the prize pictures: a stack of three gold coins and the Spin Wheel's wheel (icon_art.py)
  CatCafe_Icon_Net_L<n>     the catching net at each level, L1 Basic to L4 Master (items.py)
  CatCafe_Icon_Decor        the HUD's Decor button: a cat-eared armchair and a potted plant (Set 5 Q10)
  CatCafe_Icon_PotionFlask_<Name>  the potion rework (#1176, potion_icons.py): a clear flask per potion in its Theme
                            colour, sized weak, mid or strong within its family, with a badge for what it does
  CatCafe_Icon_Hud_<Name>   the HUD buttons (#1176, hud_icons.py): Store, Cats, Index, Quests, Upgrades, Decor,
                            Rewards, Tutorial, Feedback, Menu, MyCafe, Cannon, Areas, Potions, Bait and
                            NightMarket (the Night Market map bubble, #1607)
  CatCafe_Icon_Cat_<Name>   the shop-only cats' Store card and cat book picture (#1191): the sitting cat in its props
  CatCafe_Icon_StoreTab_<Tab>  the Store's sidebar tabs (#1674, store_tabs.py): Featured, Passes, Cats, Potions and
                            Codes, in place of the tabs' emoji
  CatCafe_Icon_Menu_<Id>    the F90 order bubble pictures (#950): each of the 12 menu dishes on its plate (menu.py),
                            Coffee, Milk, CakeSlice, PawCookie, Tea, FishBiscuit, KittyCupcake, HotCocoa,
                            PancakeStack, Sundae, StrawberryRoll and RainbowCake, from the front and a little above
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

import common  # noqa: E402
import cats  # noqa: E402
import crates  # noqa: E402
import icon_art  # noqa: E402
import hud_icons  # noqa: E402
import items  # noqa: E402
import market_icons  # noqa: E402
import menu  # noqa: E402
import potion_icons  # noqa: E402
import potions  # noqa: E402
import store_icons  # noqa: E402
import store_tabs  # noqa: E402
from common import RB  # noqa: E402

OUT = os.path.join(ROOT, "assets", "cat-cafe", "exports", "icons")
INK, GOLD_INK = (0.24, 0.16, 0.12), (0.42, 0.24, 0.04)
QUARTER = (-32.0, 24.0)          # (yaw, pitch) in degrees: the front and the right side, from a little above


def _hud_decor(mat):
    """The HUD's Decor button (Set 5 Q10): a plump blush armchair with cat ears on its back and a paw on it, a cream
    cushion, and a potted plant beside it."""
    b = RB()
    for x in (-0.72, 0.72):                                                     # short dark legs
        for z in (-0.52, 0.48):
            b.span((x - 0.09, 0.0, z - 0.09), (x + 0.09, 0.3, z + 0.09), "dark_wood")
    b.span((-0.92, 0.26, -0.7), (0.92, 0.78, 0.62), "blush")                    # the seat's body
    b.span((-0.76, 0.76, -0.78), (0.76, 1.0, 0.44), "offwhite")                 # the cushion
    b.span((-0.92, 0.7, 0.42), (0.92, 2.05, 0.78), "blush")                     # the back
    for sx in (-1, 1):
        b.span((sx * 0.86 - 0.17, 0.26, -0.8), (sx * 0.86 + 0.17, 1.3, 0.78), "blush")   # arms
        b.cyl((sx * 0.86, 1.3, -0.02), 0.19, 1.64, "blush", axis="Z", segments=12)   # rolled tops, proud of the arm
        b.b.pyramid(RB.p(sx * 0.52, 2.04, 0.6), 0.56, 0.5, "blush")             # cat ears on the back
        b.b.pyramid(RB.p(sx * 0.52, 2.04, 0.4), 0.3, 0.3, "nose_pink")
    b.span((-0.2, 1.3, 0.38), (0.2, 1.62, 0.43), "nose_pink")                   # a paw on the back
    for dx, dy in ((-0.27, 1.72), (0.0, 1.8), (0.27, 1.72)):
        b.span((dx - 0.09, dy - 0.07, 0.38), (dx + 0.09, dy + 0.09, 0.43), "nose_pink")
    b.cyl((1.62, 0.36, -0.15), 0.3, 0.72, "terracotta", r2=0.37, segments=12)   # a potted plant beside it
    b.cyl((1.62, 0.7, -0.15), 0.33, 0.04, "choco", segments=12)
    for (x, y, z, r) in ((1.62, 1.05, -0.15, 0.32), (1.38, 0.92, -0.25, 0.22), (1.86, 0.95, -0.1, 0.24),
                         (1.66, 1.34, -0.2, 0.2)):
        b.ball((x, y, z), r, "leaf_green" if r > 0.21 else "leaf_dark")
    return [b.finalize("CatCafe_IconArt_Decor", mat)]


# icon -> (builder, outline colour, outline width in pixels at 512, (yaw, pitch) of the view)
STORE_PAD = 0.34                # the margin each side for the Store icons: the subject stays inside the middle 80%
MARKET_VIEWS = {"Crates": QUARTER, "Treats": (-14.0, 14.0), "FreshCatch": (-16.0, 24.0)}

ICONS = {
    "CatCafe_Icon_GoldenFish": (icon_art.golden_fish, GOLD_INK, 10, (0.0, 8.0)),
    **{f"CatCafe_Icon_Crate_{p}{'_Gold' if g else ''}": ((lambda m, p=p, g=g: crates.build_crate(p, m, g)),
                                                         GOLD_INK if g else INK, 10, QUARTER)
       for p in crates.POOLS for g in ((False,) if p in crates.NO_GOLD else (False, True))},
    "CatCafe_Icon_Kibble": (icon_art.kibble, INK, 10, (-24.0, 20.0)),
    "CatCafe_Icon_Tuna": (icon_art.tuna, INK, 10, (-18.0, 30.0)),
    "CatCafe_Icon_Sardines": (icon_art.sardines, INK, 10, (-16.0, 34.0)),
    "CatCafe_Icon_Salmon": (icon_art.salmon, INK, 10, (-16.0, 42.0)),
    "CatCafe_Icon_Caviar": (icon_art.caviar, INK, 10, (-18.0, 32.0)),
    "CatCafe_Icon_MoonMilk": (icon_art.moon_milk, INK, 10, (-14.0, 12.0)),
    "CatCafe_Icon_StarTreat": (icon_art.star_treat, INK, 10, (-16.0, 8.0)),
    "CatCafe_Icon_Perk_GoldenEspresso": (icon_art.golden_espresso, GOLD_INK, 10, (-20.0, 34.0)),
    "CatCafe_Icon_Perk_BigBowl": (icon_art.big_bowl, INK, 10, (-18.0, 26.0)),
    "CatCafe_Icon_Perk_ExtraDecorSpot": (icon_art.extra_decor_spot, INK, 10, (-26.0, 40.0)),
    "CatCafe_Icon_Coins": (icon_art.coins, GOLD_INK, 10, (-16.0, 34.0)),
    "CatCafe_Icon_Spin": (icon_art.spin_wheel, INK, 10, (-12.0, 6.0)),
    "CatCafe_Icon_Decor": (_hud_decor, INK, 10, (-24.0, 16.0)),
    **{f"CatCafe_Icon_Net_L{n}": ((lambda m, n=n: items.build_net(n, m)), INK, 10, (-62.0, 40.0)) for n in (1, 2, 3, 4)},
    **{f"CatCafe_Icon_Potion_{k}": ((lambda m, k=k: potions.build_potion(k, m)), INK, 10, (8.0, 10.0))
       for k in potions.POTIONS},
    **{f"CatCafe_Icon_PotionFlask_{n}": (fn, INK, 10, (-12.0, 8.0)) for n, fn in potion_icons.BUILDERS.items()},
    **{f"CatCafe_Icon_Menu_{n}": ((lambda m, n=n: menu._BUILDS[n](m)), INK, 10, (-22.0, 30.0)) for n in menu.ITEMS},
    # #1628: the Golden Fish Market's three tabs (market_icons.py)
    **{f"CatCafe_Icon_Market_{n}": (fn, INK, 10, MARKET_VIEWS[n]) for n, fn in market_icons.BUILDERS.items()},
    # #1674: the Store's sidebar tabs (store_tabs.py)
    **{f"CatCafe_Icon_StoreTab_{n}": (fn, INK, 10, store_tabs.VIEWS[n]) for n, fn in store_tabs.BUILDERS.items()},
    # #1623: the Store's passes and products, framed wide (STORE_PAD) for Roblox's circle crop (store_icons.py)
    **{f"CatCafe_Icon_Pass_{n}": (fn, INK, 10, store_icons.VIEWS[n], store_icons.PADS.get(n, STORE_PAD))
       for n, fn in store_icons.PASSES.items()},
    **{f"CatCafe_Icon_Product_{n}": (fn, INK, 10, store_icons.VIEWS[n], store_icons.PADS.get(n, STORE_PAD))
       for n, fn in store_icons.PRODUCTS.items()},
    # #1191: the shop-only cats' Store card and cat book picture, the sitting cat in its props, three-quarter front
    **{f"CatCafe_Icon_Cat_{n}": ((lambda m, n=n: cats.build_cat(n, m, body="sit")), INK, 10, (-24.0, 8.0))
       for n, spec in cats.ROSTER.items() if spec.get("shop")},
}
# The HUD buttons (#1176): name -> (yaw, pitch); builders in hud_icons.py
HUD_VIEWS = {"Store": (24.0, 18.0), "Cats": (-14.0, 8.0), "Index": (-8.0, 52.0), "Quests": (-14.0, 8.0),
             "Upgrades": (-20.0, 10.0), "Decor": (-24.0, 16.0), "Rewards": (-26.0, 22.0), "Tutorial": (-12.0, 6.0),
             "Feedback": (-14.0, 8.0), "Menu": (-16.0, 8.0), "MyCafe": (-28.0, 16.0), "Cannon": (-32.0, 12.0),
             "Areas": (-20.0, 24.0), "Potions": (8.0, 10.0), "Bait": (-24.0, 20.0),
             "NightMarket": (-22.0, 24.0)}


def _hud_icons():
    return {f"CatCafe_Icon_Hud_{n}": (fn, INK, 10, HUD_VIEWS[n]) for n, fn in hud_icons.builders().items()}


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


def _camera(objs, view=(0.0, 0.0), pad=None):
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
    cd.ortho_scale = max(max(us) - min(us), max(vs) - min(vs)) * (1 + 2 * (PAD if pad is None else pad))
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
    build, colour, width, view = ICONS[name][:4]
    pad = ICONS[name][4] if len(ICONS[name]) > 4 else None
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
    _camera(objs, view, pad)
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
    ICONS.update(_hud_icons())
    for name in ICONS:
        if not wanted or any(w in name for w in wanted):
            print("icon", render_icon(name, mat), flush=True)


if __name__ == "__main__":
    main()
