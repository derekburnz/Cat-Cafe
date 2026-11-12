"""Cut-outs for the phone ads (#3441): models from rbx/ on a clear film, framed to fit.
Run: python cut.py <out.png> <size> "Model@x,y,z,yaw,scale[,pitch[,roll]];Model2@..."   env: CUT_AZ, CUT_EL, CUT_LENS,
CUT_HIDE (substrings of part names to hide), CUT_GLASS=1 keeps see-through parts, CUT_NEON, CUT_KEY, CUT_W (aspect w/h)"""
import math
import os
import sys

HERE = "/home/user/Cat-Cafe/assets/cat-cafe/blender"
RBX = "/home/user/Cat-Cafe/assets/cat-cafe/rbx"
sys.path.insert(0, HERE)
import bpy  # noqa
from mathutils import Euler, Matrix, Vector  # noqa
import common  # noqa
import rbx_preview  # noqa

OUT = os.path.abspath(sys.argv[1])
SIZE = int(sys.argv[2])
SPEC = sys.argv[3]
E = lambda n, d: float(os.environ.get(n, d))
common.reset_scene()
objs = []
for part in SPEC.split(";"):
    name, _, rest = part.partition("@")
    v = [float(x) for x in rest.split(",")] if rest else []
    v += [0, 0, 0, 0, 1, 0, 0][len(v):]
    got = rbx_preview.build(os.path.join(RBX, name + ".model.json"), name + str(len(objs)))
    M = (Matrix.Translation(Vector(v[0:3])) @ Matrix.Rotation(math.radians(v[3]), 4, "Z")
         @ Matrix.Rotation(math.radians(v[5]), 4, "X") @ Matrix.Rotation(math.radians(v[6]), 4, "Y") @ Matrix.Scale(v[4], 4))
    for ob in got:
        ob.matrix_world = M @ ob.matrix_world
    objs += got
only = os.environ.get("CUT_ONLY")
if only:
    print("NAMES", sorted({ob.name for ob in objs})[:400])
    for ob in objs:
        if only not in ob.name:
            ob.hide_render = True
box = os.environ.get("CUT_BOX")
if box:
    b = [float(x) for x in box.split(",")]
    for ob in objs:
        cc = sum(((ob.matrix_world @ Vector(c)) for c in ob.bound_box), Vector()) / 8
        if not (b[0] <= cc.x <= b[1] and b[2] <= cc.y <= b[3] and b[4] <= cc.z <= b[5]):
            ob.hide_render = True
hide = [h for h in os.environ.get("CUT_HIDE", "").split(",") if h]
for ob in objs:
    bs = ob.data.materials[0].node_tree.nodes.get("Principled BSDF") if ob.data.materials else None
    if bs and bs.inputs["Alpha"].default_value < 0.99 and not os.environ.get("CUT_GLASS"):
        ob.hide_render = True
    if any(h in ob.name for h in hide):
        ob.hide_render = True
    if bs and bs.inputs["Emission Strength"].default_value > 0:
        bs.inputs["Emission Strength"].default_value = E("CUT_NEON", "1.2")
if os.environ.get("CUT_RAINBOW"):                    # the rainbow coat's six bands by height (rainbow-coat.md), for the ad only
    import colorsys
    zs = [(ob.matrix_world @ Vector(ob.bound_box[0])).z for ob in objs] + [(ob.matrix_world @ Vector(ob.bound_box[6])).z for ob in objs]
    z0, z1 = min(zs), max(zs)
    for ob in objs:
        bs = ob.data.materials[0].node_tree.nodes.get("Principled BSDF")
        col = bs.inputs["Base Color"].default_value
        h, sat, val = colorsys.rgb_to_hsv(col[0], col[1], col[2])
        if val < 0.12 or (sat < 0.12 and val > 0.9 and ob.dimensions.length < 0.5):
            continue                                 # pupils and eye glints stay
        zc = sum(((ob.matrix_world @ Vector(c)).z for c in ob.bound_box)) / 8
        band = min(5, int((z1 - zc) / (z1 - z0) * 6))
        r, g, b = colorsys.hsv_to_rgb((0.0, 0.08, 0.15, 0.36, 0.58, 0.78)[band], 0.62, 1.0)
        m = ob.data.materials[0].copy(); ob.data.materials[0] = m
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (r ** 2.2, g ** 2.2, b ** 2.2, 1)
lo = Vector((1e9, 1e9, 1e9)); hi = -lo
for ob in objs:
    if ob.hide_render:
        continue
    for vv in ob.data.vertices:
        w = ob.matrix_world @ vv.co
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
c = (lo + hi) / 2
r = (hi - lo).length / 2
print("BOUNDS", lo, hi)
sc = bpy.context.scene
for ob in list(bpy.data.objects):
    if ob.type == "LIGHT":
        bpy.data.objects.remove(ob, do_unlink=True)
az, el = math.radians(E("CUT_AZ", "25")), math.radians(E("CUT_EL", "12"))
d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
cam = bpy.data.objects.new("_Cam", bpy.data.cameras.new("_Cam"))
sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = E("CUT_LENS", "70")
fov = 2 * math.atan(18 / cam.data.lens)
cam.location = c + d * (r / math.sin(fov / 2) * 1.02)
cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.clip_end = 5000


def light(kind, loc, energy, rgb, size=1.0, rot=None):
    L = bpy.data.lights.new("_L", kind); L.energy = energy; L.color = rgb
    if kind == "AREA":
        L.size = size
    ob = bpy.data.objects.new("_L", L); ob.location = loc
    if rot:
        ob.rotation_euler = Euler([math.radians(x) for x in rot], "XYZ")
    else:
        ob.rotation_euler = (c - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(ob)


side = Vector((d.y, -d.x, 0)).normalized()
k = E("CUT_KEY", "1.0")
light("SUN", (0, 0, 10), 2.6 * k, (1.0, 0.97, 0.92), rot=(48, 0, math.degrees(az) - 35))
light("AREA", c + d * r * 3 + side * r * 2.5 + Vector((0, 0, r * 1.5)), 60 * r * r * k, (1.0, 0.95, 0.95), size=r * 3)
light("AREA", c + d * r * 2 - side * r * 3, 25 * r * r * k, (0.85, 0.9, 1.0), size=r * 3)
light("AREA", c - d * r * 3 + Vector((0, 0, r * 2.5)), 70 * r * r * k, (1.0, 0.85, 0.95), size=r * 2)
w = sc.world or bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1, 0.96, 0.98, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = int(E("CUT_S", "40")); sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x = int(SIZE * E("CUT_W", "1")); sc.render.resolution_y = SIZE; sc.render.resolution_percentage = 100
sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("wrote", OUT)
