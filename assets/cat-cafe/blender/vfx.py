"""Particle sprites: textures for ParticleEmitters, not meshes. White on transparent so the
emitter's Color tints them; the vfx-animator's Effects presets own the emitter itself.

CatCafe_VFX_ShinySparkle.png (128 px): a fat four-point star with small diagonal glints, a hot
core and a soft halo. The arms are drawn thick so the shape still reads at Size 0.4 to 0.6 on a
phone at 30 studs (effects-list "shiny on sight"). Upload it in Studio (Asset Manager > Import),
then put the id in the ShinySparkle preset's Texture; until then the built-in
rbxasset://textures/particles/sparkles_main.dds stands in.
"""

import math
import os

import bpy
from mathutils import Matrix, Vector

import common
import palette

SPARKLE = "CatCafe_VFX_ShinySparkle"
SIZE = 128
SUPERSAMPLE = 3

# Suggested emitter values, matching docs/vfx/cat-cafe/effects-list.md (shiny on sight).
SPARKLE_EMITTER = {
    "Texture": "the uploaded CatCafe_VFX_ShinySparkle.png",
    "Color": "sparkle #FFF4B0 (Mythical cats: rarity_mythic #FF5E7E)",
    "LightEmission": 1,
    "LightInfluence": 0,
    "Brightness": 2,
    "Size": "NumberSequence 0 -> 0.55 at 0.3 -> 0 (a twinkle)",
    "Transparency": "NumberSequence 0 -> 0 at 0.6 -> 1",
    "Lifetime": "0.6 to 1.0",
    "Rate": 3,
    "Speed": "0.2 to 0.5",
    "SpreadAngle": "180, 180",
    "Rotation": "0 to 45",
    "RotSpeed": "-40 to 40",
    "ZOffset": 0.5,
    "parent": "the cat's Body (emits from its box)",
}


def _smooth(edge, x, soft):
    """1 inside (x < edge), 0 outside, with a soft band `soft` wide."""
    return min(1.0, max(0.0, (edge - x) / soft + 0.5))


def _arm(along, across, length, width, soft):
    if along >= length:
        return 0.0
    half = width * (1.0 - along / length) ** 1.3
    return _smooth(half, across, soft)


def sparkle_alpha(x, y, soft=0.02):
    """Coverage at (x, y) in -1..1."""
    ax, ay = abs(x), abs(y)
    star = max(_arm(ax, ay, 0.98, 0.2, soft), _arm(ay, ax, 0.98, 0.2, soft))
    u, v = abs(x + y) / math.sqrt(2), abs(x - y) / math.sqrt(2)
    glint = 0.7 * max(_arm(u, v, 0.5, 0.11, soft), _arm(v, u, 0.5, 0.11, soft))
    r = math.hypot(x, y)
    core = _smooth(0.22, r, soft)
    halo = 0.4 * max(0.0, 1.0 - r / 0.8) ** 2
    return min(1.0, max(star, glint, core) + halo * (1.0 - max(star, core)))


def write_sparkle_png(path, size=SIZE):
    img = bpy.data.images.get(SPARKLE) or bpy.data.images.new(SPARKLE, size, size, alpha=True)
    px = [0.0] * (size * size * 4)
    n = SUPERSAMPLE
    for j in range(size):
        for i in range(size):
            a = 0.0
            for sj in range(n):
                for si in range(n):
                    x = ((i + (si + 0.5) / n) / size) * 2 - 1
                    y = ((j + (sj + 0.5) / n) / size) * 2 - 1
                    a += sparkle_alpha(x, y)
            o = (j * size + i) * 4
            px[o], px[o + 1], px[o + 2], px[o + 3] = 1.0, 1.0, 1.0, a / (n * n)
    img.pixels.foreach_set(px)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return path


def _sprite_material(png, swatch):
    mat = bpy.data.materials.get("_SparkleMat_" + swatch)
    if mat:
        return mat
    mat = bpy.data.materials.new("_SparkleMat_" + swatch)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png, check_existing=True)
    col = (*palette.rgb_linear(swatch), 1)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Emission Color"].default_value = col
    bsdf.inputs["Emission Strength"].default_value = 4.0
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    return mat


def _billboard(name, center, size, mat, facing):
    me = bpy.data.meshes.new(name)
    h = size / 2
    me.from_pydata([(-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for k, (u, v) in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
        uv.data[k].uv = (u, v)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = Matrix.Translation(Vector(center)) @ facing.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bpy.context.scene.collection.objects.link(ob)
    return ob


def render_sparkle_preview(built, png, path, samples=32, cat="CatCafe_Cat_Tabby_Gold", azimuth=25, elevation=12):
    """A gold stray at night: the gold cat with a few sparkles at the suggested sizes around its body."""
    cat_objs = built.get(cat)
    if not cat_objs:
        return None
    az, el = math.radians(azimuth), math.radians(elevation)
    facing = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    mat = _sprite_material(png, "sparkle")
    spots = ((-0.55, -0.6, 1.55, 0.55), (0.6, -0.2, 1.75, 0.45), (0.35, -1.1, 2.0, 0.4),
             (-0.4, 0.5, 1.9, 0.5), (0.7, 0.6, 0.9, 0.35), (-0.75, -0.9, 0.7, 0.4))
    cards = [_billboard(f"_v_Sparkle{i}", (x, y, z), s, mat, facing) for i, (x, y, z, s) in enumerate(spots)]
    common.hide_all_meshes()
    common.show(cat_objs)
    common.render_preview(cat_objs + cards, path, samples=samples, warm=False, floor=True,
                          azimuth=azimuth, elevation=elevation)
    for ob in cards:
        bpy.data.objects.remove(ob, do_unlink=True)
    return path


def manifest_entry(png, root):
    return {"file": os.path.relpath(png, root), "size_px": SIZE, "format": "PNG RGBA, white, alpha shaped",
            "use": "ParticleEmitter.Texture for the ShinySparkle preset; tint with Color",
            "suggested_emitter": SPARKLE_EMITTER}
