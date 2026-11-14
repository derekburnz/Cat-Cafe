"""Store v2 pack card renders (#4026): three sitting cats close up in the pack's uniform and wearable, the decor beside
them and the sign with the pack's word behind; icon mode is one cat close up at 512. The cats' own props come off
(as CatDress takes them off for outfit pieces) and glass renders a little clearer than Cycles' default, closer to
how Roblox draws it. Run with the bpy venv: python store_cards.py -- <blender dir> <out dir> <pack> [icon]"""
import json, math, os, sys
args = sys.argv[sys.argv.index("--") + 1:]
B, OUT, PACK = args[0], args[1], args[2]
ICON = len(args) > 3 and args[3] == "icon"
sys.path.insert(0, B)
import bpy, bmesh
from mathutils import Matrix, Vector
import common, rbx_preview
from rbx_preview import _shape, _material, CT
R = os.path.join(B, "..", "rbx")

PACKS = {
    "stylish": dict(sign="CatCafe_Plot_SignClubBanner", decor="CatCafe_Decor_DiscoBall", acc="CatCafe_Accessory_CoolShades",
                    slot="Outfit_Glasses", uni=((40, 38, 48), (242, 193, 78)), cats=("Calico", "Siamese", "Cream"),
                    hats=True, bg=(0.06, 0.04, 0.1), word="STYLISH", ink=(0.95, 0.76, 0.31)),
    "winter": dict(sign="CatCafe_Plot_SignSnowyBanner", decor="CatCafe_Decor_CocoaStand", acc="CatCafe_Accessory_WinterBobble",
                   slot="Outfit_Hat", uni=((196, 48, 56), (250, 248, 244)), cats=("Smoke", "Snow", "Persian"),
                   hats=False, bg=(0.55, 0.7, 0.85), word="WINTER", ink=(0.77, 0.19, 0.22)),
    "chef": dict(sign="CatCafe_Plot_SignBakeryBanner", decor="CatCafe_Decor_PastryCase", acc="CatCafe_Accessory_PackChefHat",
                 slot="Outfit_Hat", uni=((250, 248, 242), (92, 62, 44)), cats=("Rusty", "Cream", "Munchkin"),
                 hats=False, bg=(0.93, 0.82, 0.68), word="CHEF", ink=(0.36, 0.24, 0.17)),
    "space": dict(sign="CatCafe_Plot_SignStarBanner", decor="CatCafe_Decor_RocketLamp", acc="CatCafe_Accessory_BubbleHelmet",
                  slot="Outfit_Hat", uni=((222, 228, 240), (96, 200, 180)), cats=("Fold", "Siamese", "Sandy"),
                  hats=False, bg=(0.05, 0.06, 0.16), word="SPACE", ink=(0.38, 0.85, 0.75)),
}
P = PACKS[PACK]
ROLES = (("Apron", "BaristaCap"), ("BowTie", "Vest"), ("Sash", "Boater"))


def cfm(cf):
    pos, rot = Vector(cf["CFrame"]["CFrame"]["position"]), Matrix(cf["CFrame"]["CFrame"]["orientation"])
    return Matrix.Translation(pos) @ rot.to_4x4()


def parts_of(tree):
    out = []

    def walk(n):
        if n.get("className") == "Model" and "_Prop" in str(n.get("name")):
            return                                          # the cat's own prop comes off for the pack's pieces
        if n.get("className") in ("Part", "WedgePart", "TrussPart"):
            mesh = None
            for c in n.get("children", []):
                if c.get("className") == "SpecialMesh":
                    mesh = ("Sphere", c["properties"].get("Scale", [1, 1, 1]))
            out.append(n)
            n["_mesh"] = mesh
        for c in n.get("children", []):
            walk(c)
    walk(tree)
    return out


def attachment(tree, name):
    found = []

    def walk(n):
        if n.get("className") in ("Part", "WedgePart"):
            for c in n.get("children", []):
                if c.get("className") == "Attachment" and c["name"] == name:
                    found.append(cfm(n["properties"]) @ cfm(c["properties"]))
        for c in n.get("children", []):
            walk(c)
    walk(tree)
    return found[0]


def load(name, M, recolor=None):
    tree = json.load(open(os.path.join(R, name + ".model.json")))
    ps = parts_of(tree)
    colors = {}
    if recolor:
        areas = {}
        for n in ps:
            s = n["properties"]["Size"]
            k = tuple(round(c, 3) for c in n["properties"]["Color"])
            areas[k] = areas.get(k, 0) + s[0] * s[1] + s[1] * s[2] + s[0] * s[2]
        order = sorted(areas, key=lambda k: -areas[k])
        for i, k in enumerate(order[:2]):
            colors[k] = tuple(c / 255 for c in recolor[i])
    objs = []
    for i, n in enumerate(ps):
        props = n["properties"]
        bm = bmesh.new()
        _shape(bm, n["className"], props, n["_mesh"])
        world = CT.to_4x4() @ M @ cfm(props)
        bmesh.ops.transform(bm, matrix=world, verts=bm.verts)
        me = bpy.data.meshes.new(f"{name}_{i}")
        bm.to_mesh(me)
        bm.free()
        col = colors.get(tuple(round(c, 3) for c in props["Color"]), props["Color"])
        tr = props.get("Transparency", 0)
        me.materials.append(_material(col, (1 - tr) * (0.7 if 0 < tr < 0.8 else 1), props.get("Material") == "Neon", props.get("Material") == "Metal"))
        ob = bpy.data.objects.new(f"{name}_{i}", me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    return tree, objs


def at(x, y, z, turn=0.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(turn), 4, "Y")


common.reset_scene()
sc = bpy.context.scene
# the sign: move its board's middle to (0, 6.2, 6)
sign = json.load(open(os.path.join(R, P["sign"] + ".model.json")))
board = [n for n in parts_of(sign) if n["name"] == "SignBoard"][0]
bp = Vector(board["properties"]["CFrame"]["CFrame"]["position"])
None if ICON else load(P["sign"], Matrix.Translation((0, 3.9, 5.5)) @ Matrix.Diagonal((0.4, 0.4, 0.4, 1)) @ Matrix.Translation(-bp))
# the pack's word on the board's front (the sign faces -Z, the camera's side)
tc = bpy.data.curves.new("Word", "FONT"); tc.body = P["word"]; tc.align_x = "CENTER"; tc.align_y = "CENTER"
tc.size = 0.95; tc.extrude = 0.02
tm = bpy.data.materials.new("Ink"); tm.use_nodes = True
bsdf = tm.node_tree.nodes["Principled BSDF"]; bsdf.inputs["Base Color"].default_value = (*[c ** 2.2 for c in P["ink"]], 1)
bsdf.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in P["ink"]], 1); bsdf.inputs["Emission Strength"].default_value = 0.4
tc.materials.append(tm)
to = bpy.data.objects.new("Word", tc); sc.collection.objects.link(to) if not ICON else None
to.location = (0, 5.5 - 0.08, 3.9); to.rotation_euler = (math.radians(90), 0, 0)
if not ICON:
    load(P["decor"], at(4.6, 0, 2.0, 200))
    load(P["decor"], at(-4.6, 0, 2.0, 160)) if PACK == "stylish" else None
# floor
fl = bpy.data.meshes.new("floor"); bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0, matrix=CT.to_4x4() @ Matrix.Translation((0, -0.05, 4)) @ Matrix.Diagonal((60, 0.1, 30, 1)))
bm.to_mesh(fl); bm.free()
fl.materials.append(_material({"stylish": (0.16, 0.13, 0.2), "winter": (0.95, 0.97, 1.0), "chef": (0.8, 0.62, 0.45),
                               "space": (0.2, 0.22, 0.32)}[PACK], 1, False))
ob = bpy.data.objects.new("floor", fl); sc.collection.objects.link(ob)
xs = ((-2.1, 0, 0.5, 14), (0.0, 0, -0.3, 0), (2.1, 0, 0.5, -14)) if not ICON else ((0.0, 0, 0, 0),)
for i, (x, y, z, turn) in enumerate(xs):
    cat = P["cats"][i if not ICON else 1]
    nm = f"CatCafe_Cat_{cat}_Sit"
    M = at(x, y, z, turn)
    tree, _ = load(nm, M)
    role = ROLES[i if not ICON else 1]
    for piece in role:
        if piece in ("BaristaCap", "Boater") and not P["hats"]:
            continue
        load("CatCafe_Accessory_" + piece, M @ attachment(tree, "Outfit_" + piece), recolor=P["uni"])
    load(P["acc"], M @ attachment(tree, P["slot"]))
# lights, world, camera
w = sc.world or bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (*P["bg"], 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
for (rx, rz, e, col) in ((55, 25, 3.0, (1, 0.96, 0.9)), (70, -140, 1.2, (0.85, 0.9, 1.0))):
    ld = bpy.data.lights.new("Sun%d" % rz, "SUN"); ld.energy = e; ld.color = col
    lo = bpy.data.objects.new(ld.name, ld); sc.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(rx), 0, math.radians(rz))
cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam


def rb(x, y, z):
    return Vector((-x, z, y))


if ICON:
    eye, look, cd.lens = rb(0, 1.6, -4.3), rb(0, 1.2, 0), 50
    sc.render.resolution_x = sc.render.resolution_y = 512
else:
    eye, look, cd.lens = rb(0, 2.3, -10.0), rb(0, 1.95, 1.0), 40
    sc.render.resolution_x, sc.render.resolution_y = 1600, 800
cam.location = eye
cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48
sc.render.film_transparent = False
sc.render.filepath = os.path.join(OUT, f"{PACK}{'-icon' if ICON else ''}.png")
bpy.ops.render.render(write_still=True)
print("rendered", sc.render.filepath)
