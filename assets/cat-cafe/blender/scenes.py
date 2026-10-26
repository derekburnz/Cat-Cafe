"""Two vignettes for docs/concepts: cafe interior and the alley. Uses copies of built assets."""

import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

import common
from common import Builder


def _place(built, name, loc, rot_deg=0.0, scale=1.0):
    """Copy every object of asset `name` and move the copy as a unit."""
    src = built.get(name)
    if not src:
        return []
    T = Matrix.Translation(Vector(loc)) @ Euler((0, 0, math.radians(rot_deg))).to_matrix().to_4x4() @ Matrix.Scale(scale, 4)
    out = []
    for ob in src:
        if ob.name.endswith("_Glass"):      # opaque in Cycles here; transparent in Studio
            continue
        c = ob.copy()
        c.name = "_v_" + ob.name
        c.matrix_world = T @ ob.matrix_world
        c.hide_render = False
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def _slab(name, center, size, swatch, mat):
    b = Builder()
    b.box(center, size, swatch, bevel=False)
    ob = b.finalize(name, mat)
    return [ob]


def _cleanup(objs):
    for ob in objs:
        bpy.data.objects.remove(ob, do_unlink=True)


def cafe(built, mat, docs, samples):
    objs = []
    objs += _slab("_v_Floor", (0, 0, -0.1), (22, 16, 0.2), "floor_tile", mat)
    objs += _slab("_v_WallBack", (0, 6.2, 4.5), (22, 0.4, 9), "cream", mat)
    objs += _slab("_v_WindowFrame", (-5.5, 5.95, 5.0), (5.3, 0.1, 4.3), "offwhite", mat)
    objs += _slab("_v_Window", (-5.5, 5.88, 5.0), (5, 0.06, 4), "puddle", mat)
    objs += _slab("_v_WallLeft", (-11.2, 0, 4.5), (0.4, 16, 9), "cream", mat)
    objs += _place(built, "CatCafe_Furniture_Counter", (2.0, 3.2, 0))
    objs += _place(built, "CatCafe_Furniture_EspressoMachine_L2", (4.6, 3.4, 3.0))
    objs += _place(built, "CatCafe_Decor_MenuBoard", (2.0, 6.0, 4.6))
    objs += _place(built, "CatCafe_Decor_NeonSign", (7.5, 6.0, 4.0))
    objs += _place(built, "CatCafe_Furniture_WallShelf", (-1.5, 6.0, 5.2))
    objs += _place(built, "CatCafe_Furniture_WindowSeat", (-5.5, 5.3, 0))
    objs += _place(built, "CatCafe_Furniture_CatTree", (-9.0, 4.0, 0))
    objs += _place(built, "CatCafe_Decor_FishTank", (9.0, 4.5, 0))
    objs += _place(built, "CatCafe_Decor_Rug", (-4.0, -1.0, 0))
    objs += _place(built, "CatCafe_Furniture_TableRound", (-4.0, -1.0, 0))
    objs += _place(built, "CatCafe_Furniture_Chair", (-4.0, -3.2, 0), 180)
    objs += _place(built, "CatCafe_Furniture_Chair", (-4.0, 1.2, 0), 0)
    objs += _place(built, "CatCafe_Decor_Cup", (-4.4, -1.2, 2.6))
    objs += _place(built, "CatCafe_Furniture_TableRound", (4.0, -2.0, 0))
    objs += _place(built, "CatCafe_Furniture_Chair", (4.0, -4.2, 0), 180)
    objs += _place(built, "CatCafe_Furniture_Chair", (6.2, -2.0, 0), 90)
    objs += _place(built, "CatCafe_Furniture_Cushion", (-7.5, -4.0, 0))
    objs += _place(built, "CatCafe_Decor_PlantPot", (9.5, -4.5, 0))
    objs += _place(built, "CatCafe_Decor_WindowPlants", (-5.5, 5.7, 3.0))
    objs += _place(built, "CatCafe_Decor_HangingLamp", (-4.0, -1.0, 8.6))
    objs += _place(built, "CatCafe_Decor_HangingLamp", (4.0, -2.0, 8.6))
    objs += _place(built, "CatCafe_Cat_Tabby", (-1.0, 3.2, 3.0), 200)       # counter spot
    objs += _place(built, "CatCafe_Cat_Tuxedo", (-5.5, 5.2, 1.6), 160)      # window seat
    objs += _place(built, "CatCafe_Cat_Calico", (-7.5, -4.0, 0.46), 30)      # cushion
    objs += _place(built, "CatCafe_Cat_Siamese", (-8.5, 3.6, 4.45), 140)     # cat tree top
    objs += _place(built, "CatCafe_Cat_Void", (-1.5, 5.4, 5.32), 190)       # shelf
    objs += _place(built, "CatCafe_Cat_Ginger", (1.0, -4.5, 0), -20)
    objs += _place(built, "CatCafe_NPC_Customer_A", (0.5, 0.2, 0), 180)
    objs += _place(built, "CatCafe_NPC_Customer_B", (-2.0, -3.0, 0), 160)
    objs += _place(built, "CatCafe_NPC_Customer_C", (7.5, 0.5, 0), 200)
    # lamp lights
    lights = []
    for loc in ((-4.0, -1.0, 6.0), (4.0, -2.0, 6.0)):
        ld = bpy.data.lights.new("_v_lamp", "POINT")
        ld.energy = 800
        ld.color = (1.0, 0.84, 0.66)
        ld.shadow_soft_size = 0.5
        lo = bpy.data.objects.new("_v_lamp", ld)
        lo.location = loc
        bpy.context.scene.collection.objects.link(lo)
        lights.append(lo)
    common.hide_all_meshes()
    common.show(objs)
    path = os.path.join(docs, "vignette_cafe.png")
    common.render_preview(objs, path, res=(1280, 720), samples=samples, azimuth=12, elevation=16, warm=True,
                          margin=0.72, floor=False)
    _cleanup(objs + lights)
    return path


def alley(built, mat, docs, samples):
    objs = []
    objs += _slab("_v_Ground", (0, 0, -0.1), (26, 18, 0.2), "concrete", mat)
    objs += _slab("_v_WallBack", (0, 5.2, 5.5), (26, 0.5, 11), "brick", mat)
    objs += _slab("_v_WallLeft", (-12.5, -1, 5.5), (0.5, 14, 11), "brick", mat)
    objs += _slab("_v_Door", (6.0, 4.9, 3.5), (4, 0.2, 7), "dark_wood", mat)
    objs += _slab("_v_DoorLight", (6.0, 4.85, 6.0), (3.2, 0.2, 1.2), "lamp_warm", mat)
    objs += _slab("_v_Curb", (0, -7.5, 0.15), (26, 1.0, 0.3), "concrete_dark", mat)
    objs += _place(built, "CatCafe_Alley_Dumpster", (-5.0, 3.0, 0))
    objs += _place(built, "CatCafe_Alley_TrashCan", (0.5, 3.8, 0))
    objs += _place(built, "CatCafe_Alley_TrashCan", (2.2, 4.0, 0), 30)
    objs += _place(built, "CatCafe_Alley_Crate", (-9.5, 3.8, 0), 15)
    objs += _place(built, "CatCafe_Alley_Pallet", (-9.5, 0.5, 0), 80)
    objs += _place(built, "CatCafe_Alley_CardboardBox", (-9.6, 0.4, 0.3), 25)
    objs += _place(built, "CatCafe_Alley_CardboardBox", (-1.5, 4.0, 0), -10)
    objs += _place(built, "CatCafe_Alley_StreetLamp", (9.5, 2.5, 0))
    objs += _place(built, "CatCafe_Alley_Puddle", (-1.0, -3.0, 0), 20)
    objs += _place(built, "CatCafe_Alley_Puddle", (5.0, -1.5, 0), -40, 0.7)
    objs += _place(built, "CatCafe_Item_FoodBowl_Premium", (-2.0, -0.5, 0))
    objs += _place(built, "CatCafe_Item_TunaCan", (-1.2, -0.9, 0), 40)
    objs += _place(built, "CatCafe_Cat_Void", (-2.0, 1.6, 0), 0)
    objs += _place(built, "CatCafe_Cat_Smoke", (-6.5, 3.0, 3.65), 15)        # on the closed dumpster lid
    objs += _place(built, "CatCafe_Cat_Tortie", (-10.0, -4.5, 0), -120)
    objs += _place(built, "CatCafe_Cat_Bengal", (3.5, -3.5, 0), 210)
    objs += _place(built, "CatCafe_NPC_Customer_A", (2.5, -5.0, 0), 160)
    lights = []
    for loc, e, col in (((9.5, 1.0, 8.6), 2500, (1.0, 0.8, 0.6)), ((6.0, 3.5, 6.0), 400, (1.0, 0.85, 0.7))):
        ld = bpy.data.lights.new("_v_lamp", "POINT")
        ld.energy = e
        ld.color = col
        ld.shadow_soft_size = 0.6
        lo = bpy.data.objects.new("_v_lamp", ld)
        lo.location = loc
        bpy.context.scene.collection.objects.link(lo)
        lights.append(lo)
    key = bpy.data.objects.get("_Key")
    old = None
    if key:
        old = key.data.energy
        key.data.energy = 0.6
    common.hide_all_meshes()
    common.show(objs)
    path = os.path.join(docs, "vignette_alley.png")
    common.render_preview(objs, path, res=(1280, 720), samples=samples, azimuth=-18, elevation=18, warm=False,
                          margin=0.7, floor=False)
    if key:
        key.data.energy = old
    _cleanup(objs + lights)
    return path


def render_all(built, mat, docs, samples=48):
    os.makedirs(docs, exist_ok=True)
    return [cafe(built, mat, docs, samples), alley(built, mat, docs, samples)]
