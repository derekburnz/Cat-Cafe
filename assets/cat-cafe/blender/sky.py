"""CatCafe_Sky: a soft daytime skybox in place of the Roblox default (Derek, 2026-10-27 22:37: "the sky shouldn't
be the roblox default pick something simple"). Pale blue overhead fading to a warm cream horizon, no clouds.

All six faces come from one gradient that depends only on how high in the sky a pixel looks, so neighbouring faces
meet with no seams and no face can be the wrong way up. Nothing is painted in for the sun, moon or stars: Roblox
draws those itself (CelestialBodiesShown, StarCount), and WorldController's lighting presets set the time of day.

  python sky.py [--preview]   ../exports/sky/CatCafe_Sky_{Side,Up,Dn}.png (512 px), and
                              ../rbx/CatCafe_Sky.model.json once every image has an uploaded id in IDS below;
                              --preview also renders docs/concepts/cat-cafe/previews/CatCafe_Sky.png

The four side faces (SkyboxBk, Ft, Lf, Rt) are the same picture, so there are three images. Upload each once with
the upload-image workflow (Actions, type Image) and put its id in IDS next to the first 12 hex digits of the file's
SHA-256 (printed by this script). The model is only written when every hash still matches, so an image that changed
after upload cannot keep a stale id. Gameplay code clones Assets.CatCafe_Sky into
Lighting.
"""

import hashlib
import json
import math
import os
import struct
import sys
import tempfile
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
NAME = "CatCafe_Sky"
SIZE = 512
FACES = {"Bk": "Side", "Dn": "Dn", "Ft": "Side", "Lf": "Side", "Rt": "Side", "Up": "Up"}   # Sky property -> image
IMAGES = ("Side", "Up", "Dn")

# (elevation in degrees, colour): warm ground haze below the horizon, cream at it, pale blue above.
# Kept off pure white so the sky never out-glows the lit cafes (Derek: "everything is too bright").
STOPS = (
    (-90, "#D8CBB6"),
    (-8, "#E4D5BE"),
    (0, "#EFDDC1"),
    (4, "#ECE2D0"),
    (12, "#D3E3EA"),
    (32, "#AACFEA"),
    (90, "#88BDE6"),
)
SOFTEN = 3.0        # degrees of blur over the stops, so no band shows where two stops meet

# image -> (uploaded rbxassetid number, first 12 hex of the PNG's SHA-256)
IDS = {}


def _rgb(h):
    return [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]


def _lut():
    """Colour for every 0.1 degree from -90 to 90, softened."""
    deg = np.linspace(-90, 90, 1801)
    elev = [e for e, _ in STOPS]
    cols = np.array([_rgb(c) for _, c in STOPS])
    lut = np.stack([np.interp(deg, elev, cols[:, k]) for k in range(3)], axis=1)
    sig = SOFTEN * 10
    r = int(sig * 3)
    kern = np.exp(-0.5 * (np.arange(-r, r + 1) / sig) ** 2)
    kern /= kern.sum()
    padded = np.pad(lut, ((r, r), (0, 0)), mode="edge")
    return deg, np.stack([np.convolve(padded[:, k], kern, mode="valid") for k in range(3)], axis=1)


def colour(elevation_deg):
    deg, lut = _lut()
    e = np.asarray(elevation_deg, dtype=float)
    return np.stack([np.interp(e, deg, lut[:, k]) for k in range(3)], axis=-1)


def face_elevation(face, size=SIZE):
    """Elevation (degrees) seen through each pixel of a cube face. Row 0 is the top of the image; side faces have
    up at the top, as Roblox draws them. The gradient is the same all round, so which side is which does not
    matter, and the up and down faces are rings."""
    c = (np.arange(size) + 0.5) / size * 2 - 1
    u, v = np.meshgrid(c, -c)
    if face == "Up":
        return np.degrees(np.arctan2(1.0, np.hypot(u, v)))
    if face == "Dn":
        return -np.degrees(np.arctan2(1.0, np.hypot(u, v)))
    return np.degrees(np.arctan2(v, np.hypot(u, 1.0)))


_BAYER = np.array([[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
                   [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
                   [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
                   [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]) / 64 - 0.5


def face_rgb8(face, size=SIZE):
    """The face as 8-bit RGB, with an ordered dither so the slow gradient does not step into bands."""
    rgb = colour(face_elevation(face, size)) * 255
    reps = (size + 7) // 8
    dither = np.tile(_BAYER, (reps, reps))[:size, :size, None]
    return np.clip(np.floor(rgb + 0.5 + dither), 0, 255).astype(np.uint8)


def write_png(path, rgb8):
    h, w, _ = rgb8.shape
    raw = b"".join(b"\x00" + rgb8[y].tobytes() for y in range(h))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    return path


def sha12(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:12]


def check_seams(size=SIZE):
    """Largest step (0 to 255) across any edge where two faces meet, before dithering."""
    side = colour(face_elevation("Ft", size)) * 255
    up = colour(face_elevation("Up", size)) * 255
    dn = colour(face_elevation("Dn", size)) * 255
    steps = [np.abs(side[0] - up[-1]).max(), np.abs(side[-1] - dn[0]).max(),  # side top to Up, bottom to Dn
             np.abs(side[:, 0] - side[:, -1]).max()]                         # side to side
    return float(max(steps))


def write_faces(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    return {img: write_png(os.path.join(out_dir, f"{NAME}_{img}.png"), face_rgb8("Ft" if img == "Side" else img))
            for img in IMAGES}


def write_model(paths, rbx_dir):
    """rbx/CatCafe_Sky.model.json, or None while any image lacks an id or changed after upload."""
    stale = [i for i in IMAGES if i not in IDS or IDS[i][1] != sha12(paths[i])]
    if stale:
        return None, stale
    props = {f"Skybox{f}": f"rbxassetid://{IDS[img][0]}" for f, img in FACES.items()}
    props.update({"CelestialBodiesShown": True})
    path = os.path.join(rbx_dir, NAME + ".model.json")
    with open(path, "w") as f:
        json.dump({"className": "Sky", "properties": props}, f, indent=1)
        f.write("\n")
    return path, []


def write_panorama(path, width=2048):
    """Equirectangular copy of the sky, for the Blender preview's world."""
    h = width // 2
    elev = 90 - (np.arange(h) + 0.5) / h * 180
    row = colour(elev) * 255
    img = np.repeat(np.clip(np.floor(row + 0.5), 0, 255).astype(np.uint8)[:, None, :], width, axis=1)
    return write_png(path, img)


def render_preview(path, rbx_dir, samples=32):
    """The Park gate with a sitting tabby and a street lamp in front of the sky, from a little below eye level."""
    import bpy
    from mathutils import Vector

    import common
    import rbx_preview

    common.reset_scene()
    CT = common.TO_ROBLOX.transposed().to_4x4()

    def B(p):
        return (CT @ Vector((*p, 1.0))).to_3d()

    walk = rbx_preview._walk

    def walk_no_bars(node, out):                      # the gate's ForceField would veil the sky behind it
        if node.get("name") != "Bars":
            walk(dict(node, children=[c for c in node.get("children", []) if c.get("name") != "Bars"]), out)

    rbx_preview._walk = walk_no_bars
    for asset, at in (("CatCafe_Park_Gate", (0, 0, 0)), ("CatCafe_Cat_Tabby_Sit", (-5, 0, -9)),
                      ("CatCafe_Alley_StreetLamp", (11, 0, -6))):
        for ob in rbx_preview.build(os.path.join(rbx_dir, asset + ".model.json"), asset):
            ob.location = ob.location + B(at)
    rbx_preview._walk = walk
    common._ensure_floor(size=2000)
    common._ensure_lights(True)
    pano = write_panorama(os.path.join(tempfile.mkdtemp(), NAME + "_pano.png"))
    w = bpy.context.scene.world
    nt = w.node_tree
    for n in list(nt.nodes):
        if n.type not in ("OUTPUT_WORLD",):
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
    tex = nt.nodes.new("ShaderNodeTexEnvironment")
    tex.image = bpy.data.images.load(pano)
    seen, lit = nt.nodes.new("ShaderNodeBackground"), nt.nodes.new("ShaderNodeBackground")
    seen.inputs["Strength"].default_value, lit.inputs["Strength"].default_value = 1.0, 0.6
    nt.links.new(tex.outputs["Color"], seen.inputs["Color"])
    nt.links.new(tex.outputs["Color"], lit.inputs["Color"])
    mix, lp = nt.nodes.new("ShaderNodeMixShader"), nt.nodes.new("ShaderNodeLightPath")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(lit.outputs["Background"], mix.inputs[1])
    nt.links.new(seen.outputs["Background"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    sc.view_settings.view_transform = "Standard"
    cd = bpy.data.cameras.new("_Cam")
    cd.lens = 22
    cd.clip_end = 3000
    cam = bpy.data.objects.new("_Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    at, look = (7, 2.6, -24), (0, 9, 0)
    cam.location = B(at)
    cam.rotation_euler = (B(look) - B(at)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def main():
    root = os.path.normpath(os.path.join(HERE, ".."))
    out = os.path.join(root, "exports", "sky")
    rbx = os.path.join(root, "rbx")
    paths = write_faces(out)
    print(f"seams: largest step {check_seams():.2f} of 255")
    for img in IMAGES:
        print(f"{NAME}_{img}.png sha12 {sha12(paths[img])} id {IDS.get(img, ('-',))[0]}")
    model, stale = write_model(paths, rbx)
    print("model:", model or f"not written, images without a current id: {', '.join(stale)}")
    if "--preview" in sys.argv:
        docs = os.path.normpath(os.path.join(root, "..", "..", "docs", "concepts", "cat-cafe", "previews"))
        print("preview:", render_preview(os.path.join(docs, NAME + ".png"), rbx))


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    main()
