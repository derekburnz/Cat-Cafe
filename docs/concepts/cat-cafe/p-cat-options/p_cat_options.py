"""#1032: hero cat options for the store picture P (the cafe picture), rendered from the game's own models.

Each option is a working cat on body S (CatCafe_Cat_<Name>_Work) in the barista pose with its takeaway cup, standing
in the cafe at the front left, the cafe behind it out of focus, and the right half left clear for the logo (the
compose step adds it). Plus a lineup at true scale next to the current P cat (Ginger) and two everyday cats.

Run: .venv-bpy/bin/python p_cat_options.py <repo>/assets/cat-cafe/blender <out_dir> [--samples N] [--only Name]
"""

import math
import os
import sys

BL = os.path.abspath(sys.argv[1])
OUT = os.path.abspath(sys.argv[2])
SAMPLES = int(sys.argv[sys.argv.index("--samples") + 1]) if "--samples" in sys.argv else 64
ONLY = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
PCT = int(sys.argv[sys.argv.index("--pct") + 1]) if "--pct" in sys.argv else 100
sys.argv = [sys.argv[0]]
sys.path.insert(0, BL)

import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import build_all  # noqa: E402
import cats  # noqa: E402
import common  # noqa: E402
import palette  # noqa: E402
import poses  # noqa: E402

# name -> (extra outfit pieces, why)
OPTIONS = {
    "BellhopCat": ((), "the free Bellhop Cat every new player gets: ginger tabby, white blaze and socks, red cap and gold bell"),
    "Blossom": (("Apron",), "Blossom (Legendary): rose and white patches, blue eyes, the flower and petals, fairy wings, barista apron"),
    "ForestCat": (("Apron",), "Forest Cat (Rare): russet tabby with a cream ruff and ear tufts in its plaid cap, barista apron; the same cat as icon D"),
}
LINEUP_EXTRA = ("Ginger", "Tabby", "Tuxedo")

BACKGROUND = [
    # (asset, location, rot_deg): a cafe like scenes.cafe, seen from the front door
    ("CatCafe_Furniture_Counter", (2.6, 3.4, 0), 0),
    ("CatCafe_Furniture_EspressoMachine_L2", (4.8, 3.6, 3.0), 0),
    ("CatCafe_Decor_MenuBoard", (2.6, 6.0, 4.8), 0),
    ("CatCafe_Decor_NeonSign", (7.6, 6.0, 4.4), 0),
    ("CatCafe_Furniture_WallShelf", (-2.0, 6.0, 5.2), 0),
    ("CatCafe_Furniture_WindowSeat", (-6.0, 5.3, 0), 0),
    ("CatCafe_Decor_WindowPlants", (-6.0, 5.7, 3.0), 0),
    ("CatCafe_Furniture_CatTree", (-9.5, 4.0, 0), 0),
    ("CatCafe_Furniture_TableRound", (-3.5, 0.0, 0), 0),
    ("CatCafe_Furniture_Chair", (-3.5, -2.2, 0), 180),
    ("CatCafe_Furniture_Chair", (-1.3, 0.0, 0), 90),
    ("CatCafe_Decor_Cup", (-3.8, -0.2, 2.6), 0),
    ("CatCafe_Furniture_TableRound", (5.0, -0.5, 0), 0),
    ("CatCafe_Furniture_Chair", (5.0, -2.7, 0), 180),
    ("CatCafe_Decor_PlantPot", (9.0, 1.0, 0), 0),
    ("CatCafe_Decor_HangingLamp", (-3.5, 0.0, 8.6), 0),
    ("CatCafe_Decor_HangingLamp", (5.0, -0.5, 8.6), 0),
    ("CatCafe_Cat_Tuxedo_Sit", (0.2, 3.2, 3.0), 195),      # on the counter
    ("CatCafe_Cat_Smoke_Sit", (-6.0, 5.2, 1.6), 170),      # window seat
    ("CatCafe_Cat_Calico_Sit", (-2.0, 5.5, 5.32), 185),    # shelf
    ("CatCafe_Cat_Siamese", (-9.0, 3.6, 4.45), 150),       # cat tree top
]
HERO_AT = (-0.55, -6.2, 0.0)


def wanted_assets():
    names = {a for a, _, _ in BACKGROUND}
    for n in list(OPTIONS) + list(LINEUP_EXTRA):
        names |= {f"CatCafe_Cat_{n}", f"CatCafe_Cat_{n}_Sit", f"CatCafe_Cat_{n}_Work"}
    names |= {"CatCafe_Accessory_Apron", "CatCafe_Accessory_BaristaCap"}
    return names


def build(mat):
    allx = build_all.all_assets()
    built = {}
    for name in sorted(wanted_assets()):
        if name in allx:
            built[name] = allx[name][0](mat)
            for ob in built[name]:
                ob.hide_render = True
        else:
            print("missing asset", name)
    return built


def slab(name, center, size, swatch, mat):
    b = common.Builder()
    b.box(center, size, swatch, bevel=False)
    return [b.finalize(name, mat)]


def place(built, name, loc, rot=0.0):
    src = built.get(name, [])
    T = Matrix.Translation(Vector(loc)) @ Euler((0, 0, math.radians(rot))).to_matrix().to_4x4()
    out = []
    for ob in src:
        if ob.name.endswith("_Glass"):
            continue
        c = ob.copy()
        c.name = "_v_" + ob.name
        c.matrix_world = T @ ob.matrix_world
        c.hide_render = False
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def hero(built, name, extra, world):
    spec = cats.ROSTER[name]
    src = [ob for ob in built[f"CatCafe_Cat_{name}_Work"]
           if "_Held_" not in ob.name or ob.name.split(".")[0].endswith("_Held_Barista")]
    pose = poses.CAT_POSES["work_barista"]
    objs = poses.cat_pose_copies(src, pose, spec, "work", world=world)
    objs += poses.accessory_copies(built, src, spec, "work", extra, world=world, pose=pose)
    return objs


def room(mat, built):
    objs = []
    objs += slab("_v_Floor", (0, -2, -0.1), (30, 24, 0.2), "caramel_wood", mat)
    objs += slab("_v_WallBack", (0, 6.2, 4.5), (30, 0.4, 9), "blush", mat)
    objs += slab("_v_Wainscot", (0, 6.0, 1.2), (30, 0.1, 2.4), "cream", mat)
    objs += slab("_v_WindowFrame", (-6.0, 5.95, 5.0), (5.3, 0.1, 4.3), "offwhite", mat)
    objs += slab("_v_Window", (-6.0, 5.88, 5.0), (5, 0.06, 4), "pastel_sky", mat)
    objs += slab("_v_WallLeft", (-12.2, 0, 4.5), (0.4, 24, 9), "blush", mat)
    for a, loc, rot in BACKGROUND:
        objs += place(built, a, loc, rot)
    return objs


def lights():
    out = []
    for loc, e, col in (((-3.5, 0.0, 6.0), 700, (1.0, 0.84, 0.66)), ((5.0, -0.5, 6.0), 700, (1.0, 0.84, 0.66)),
                        ((-2.5, -9.5, 3.5), 260, (1.0, 0.93, 0.85)), ((2.5, -7.0, 4.5), 120, (1.0, 0.75, 0.75))):
        ld = bpy.data.lights.new("_v_lamp", "POINT")
        ld.energy = e
        ld.color = col
        ld.shadow_soft_size = 1.2
        lo = bpy.data.objects.new("_v_lamp", ld)
        lo.location = loc
        bpy.context.scene.collection.objects.link(lo)
        out.append(lo)
    return out


def setup_render(res, samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = PCT
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    common._ensure_lights(True)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5


def camera(loc, target, lens, focus=None, fstop=None, shift=(0.0, 0.0)):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("_PCam")
    if cam is None:
        cam = bpy.data.objects.new("_PCam", bpy.data.cameras.new("_PCam"))
        sc.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_start = 0.05
    cam.data.clip_end = 500
    cam.data.shift_x, cam.data.shift_y = shift
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.dof.use_dof = focus is not None
    if focus is not None:
        cam.data.dof.focus_distance = (Vector(focus) - Vector(loc)).length
        cam.data.dof.aperture_fstop = fstop
    sc.camera = cam


def render(path, objs):
    common.hide_all_meshes()
    common.show(objs)
    fl = bpy.data.objects.get("_PreviewFloor")
    if fl:
        fl.hide_render = True
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("wrote", path)


def head_height(objs):
    head = [o for o in objs if o.name.split(".")[0].endswith("_Head")]
    lo, hi = common.bounds(head)
    return (lo + hi) / 2


def main():
    os.makedirs(OUT, exist_ok=True)
    common.reset_scene()
    png = os.path.join(OUT, "_palette.png")
    palette.write_palette_png(png)
    mat = common.palette_material(png)
    built = build(mat)
    scene = room(mat, built) + lights()
    for name, (extra, _why) in OPTIONS.items():
        if ONLY and ONLY not in name:
            continue
        world = Matrix.Translation(HERO_AT) @ Euler((0, 0, math.radians(-14))).to_matrix().to_4x4()
        h = hero(built, name, extra, world)
        hc = head_height(h)
        lo, hi = common.bounds(h)
        tall = hi.z - lo.z
        # the cat fills about 80% of the height on the left; the right half stays clear for the logo
        # 50 mm, 16:9: the frame is 0.404 d high and 0.72 d wide at distance d
        cx = (lo.x + hi.x) / 2
        d = tall / (0.9 * 0.404)
        cam_loc = Vector((cx + 0.21 * 0.72 * d, hc.y - d, lo.z + 0.5 * tall))
        target = cam_loc + Vector((0.0, d, -0.02 * tall))
        setup_render((1920, 1080), SAMPLES)
        camera(cam_loc, target, 50, focus=hc, fstop=0.45)
        render(os.path.join(OUT, f"P_cat_option_{name}.png"), scene + h)
        poses.cleanup(h)
    if not ONLY or ONLY == "lineup":
        lineup = list(OPTIONS) + list(LINEUP_EXTRA)
        objs, x = [], 0.0
        for i, name in enumerate(lineup):
            world = Matrix.Translation((-4.2 + i * 1.4, -6.2, 0)) @ Euler((0, 0, math.radians(-8))).to_matrix().to_4x4()
            if name in OPTIONS:
                objs += hero(built, name, OPTIONS[name][0], world)
            elif name == "Ginger":                     # the current P cat: barista cap and apron, cup in paw
                objs += hero(built, name, ("Apron", "BaristaCap"), world)
            else:
                objs += place(built, f"CatCafe_Cat_{name}_Sit", world.to_translation(), -8)
        setup_render((1920, 820), SAMPLES)
        lo, hi = common.bounds(objs)
        c = (lo + hi) / 2
        d = ((hi.x - lo.x) + 1.6) / 0.72
        camera((c.x, c.y - d, 1.1), (c.x, c.y, 0.9), 50)
        render(os.path.join(OUT, "P_cat_options_lineup.png"), objs + [o for o in scene if "Floor" in o.name or "Wall" in o.name or "Wainscot" in o.name] + [o for o in scene if o.type == "LIGHT"])
        poses.cleanup(objs)


main()
