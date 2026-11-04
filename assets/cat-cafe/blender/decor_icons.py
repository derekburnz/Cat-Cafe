"""Decor menu pictures (#1072): one clean picture per decor and front lawn item, by catalog id, for the Decor screen's
cards and strips, the Decor Index and the crate reel. Same look as the food and potion pictures (icons.py): the item's
own model straight from its generator, a bright even light, a transparent background and a dark outline, 512 px.

The list comes from games/cat-cafe/src/shared/Catalog.luau, read the way Catalog builds it, so a piece added there gets
a picture on the next run:
  - the crate pieces (CRATE_PIECES, every pool): asset `row.asset`, else CatCafe_Door_<Name> (the set's _Front is
    drawn), CatCafe_CatFlap_<Name>, CatCafe_Style_<Name> (wallpaper, floor, paint) or CatCafe_Decor_<Name>
  - the four old Classic pieces (Catalog.decor, their `asset`)
  - the front lawn pieces (Catalog.lawn) and its path and fence styles (Catalog.lawnStyles), their `model`

    python decor_icons.py [--only rug,tulip] [--samples 32]

writes assets/cat-cafe/exports/icons/decor/CatCafe_DecorIcon_<id>.png and decor/index.json (catalog id -> file and the
model drawn), which Tools-Agent's upload and UI-Engineer's ShopIcons table read. Glass parts (_Glass) are left out: in
Cycles they would be opaque and hide what is behind them. A style's _Swatch parts are drawn in the style's colour
(rbx_export.LOOKS, read from the catalog by style_icons.py), as Roblox shows them, and a lawn fence shows one of its two
runs, seen along its length, so the picture is a fence, not two thin slivers far apart.
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import common  # noqa: E402
import icons  # noqa: E402

CATALOG = os.path.join(ROOT, "games", "cat-cafe", "src", "shared", "Catalog.luau")
OUT = os.path.join(icons.OUT, "decor")
STYLE_KINDS = ("wallpaper", "floor", "paint")
FACE_ON = (-14.0, 10.0)          # flat pieces (wallpaper, floor and paint swatches, doors, flaps): nearly face on
ALONG = (-60.0, 26.0)            # a lawn fence: one of its two runs, looking along it so it fills more of the square


def _one_run(objs):
    """A lawn fence model is both runs across the lawn's front, either side of the path; keep the -X run (Blender
    +X, the cat's left as it faces the street) for the picture, so it is not two thin slivers far apart."""
    import bmesh
    for ob in objs:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        M = ob.matrix_world
        gone = [v for v in bm.verts if (M @ v.co).x < -0.05]
        bmesh.ops.delete(bm, geom=gone, context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()


def _srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _tint_swatches(objs):
    """A style's _Swatch parts take the style's colour in Roblox (rbx_export.LOOKS); the palette draws them cream, so
    give each its colour here too. Returns the materials made, to remove afterwards."""
    import rbx_export
    made = []
    for ob in objs:
        look = rbx_export.LOOKS.get(ob.name.split(".")[0])
        if not look or not ob.name.split(".")[0].endswith("_Swatch"):
            continue
        rgb = [_srgb_to_linear(v) for v in look[0]]
        m = bpy.data.materials.new("_SwatchTint")
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6
        for slot in ob.material_slots:
            slot.link = "OBJECT"
            slot.material = m
        made.append(m)
    return made


def _plain(name):
    return re.sub(r"[^A-Za-z0-9]", "", name)


def catalog_items():
    """[(id, name, kind, asset)] for every decor and lawn item, in catalog order."""
    s = open(CATALOG, encoding="utf-8").read()
    out = []
    block = s[s.index("local CRATE_PIECES"):s.index("Catalog.crateDecor = {}")]
    for m in re.finditer(r"\{\s*\n\s*id = \"([^\"]+)\",(.*?)\n\t\t\}", block, re.S):
        cid, body = m.group(1), m.group(2)
        name = re.search(r"name = \"([^\"]+)\"", body).group(1)
        kind = re.search(r"kind = \"(\w+)\"", body).group(1)
        own = re.search(r"asset = \"([^\"]+)\"", body)
        if own:
            asset = own.group(1)
        elif kind == "door":
            asset = "CatCafe_Door_" + _plain(re.sub(r" Door$", "", name))
        elif kind == "catflap":
            asset = "CatCafe_CatFlap_" + _plain(re.sub(r" Flap$", "", name))
        elif kind in STYLE_KINDS:
            asset = "CatCafe_Style_" + _plain(name)
        else:
            asset = "CatCafe_Decor_" + _plain(name)
        out.append((cid, name, kind, asset))
    old = s[s.index("Catalog.decor = {"):s.index("Catalog.decorById")]
    for m in re.finditer(r"id = \"(\w+)\",\s*\n\s*name = \"([^\"]+)\",.*?asset = \"([^\"]+)\"", old, re.S):
        out.append((m.group(1), m.group(2), "decoration", m.group(3)))
    lawn = s[s.index("Catalog.lawn = {"):s.index("Catalog.lawnStyles")]
    for m in re.finditer(r"\{\s*\n\s*id = \"(\w+)\",(.*?)\n\t\}", lawn, re.S):     # one row at a time
        body = m.group(2)
        name = re.search(r"name = \"([^\"]+)\"", body)
        model = re.search(r"(?:model|asset) = \"([^\"]+)\"", body)
        if name and model:
            out.append((m.group(1), name.group(1), "lawn", model.group(1)))
    styles = s[s.index("Catalog.lawnStyles = {"):s.index("Catalog.lawnById")]
    for m in re.finditer(r"\{\s*\n\s*id = \"(\w+)\",(.*?)\n\t\}", styles, re.S):     # the path and fence styles
        body = m.group(2)
        name = re.search(r"name = \"([^\"]+)\"", body)
        kind = re.search(r"kind = \"(\w+)\"", body)
        model = re.search(r"(?:model|asset) = \"([^\"]+)\"", body)
        if name and model:
            out.append((m.group(1), name.group(1), "lawn_" + (kind.group(1) if kind else "style"), model.group(1)))
    return out


def render(cid, kind, model, build, mat, samples):
    objs = build(mat)
    shown = [ob for ob in objs if not ob.name.split(".")[0].endswith("_Glass")]
    for ob in objs:
        if ob not in shown:
            ob.hide_render = True
    tints = _tint_swatches(shown)
    if kind == "lawn_fence":
        _one_run(shown)
        shown = [ob for ob in shown if len(ob.data.vertices)]
    view = (FACE_ON if kind in STYLE_KINDS or kind in ("door", "catflap")
            else ALONG if kind == "lawn_fence" else icons.QUARTER)
    icons.ICONS[cid] = (lambda m: shown, icons.INK, 10, view)   # render_icon's table: builder, ink, width, view
    name = "CatCafe_DecorIcon_" + cid
    icons.ICONS[name] = icons.ICONS.pop(cid)
    old_out = icons.OUT
    icons.OUT = OUT
    try:
        path = icons.render_icon(name, mat, samples)
    finally:
        icons.OUT = old_out
        del icons.ICONS[name]
    for ob in objs:                                   # render_icon removed what it drew; the glass is left
        if ob not in shown:
            bpy.data.objects.remove(ob, do_unlink=True)
    for m in tints:
        bpy.data.materials.remove(m)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=32)
    args = ap.parse_args()
    wanted = [w for w in args.only.split(",") if w]
    import build_all
    builders = build_all.all_assets()
    common.reset_scene()
    mat = common.palette_material(os.path.join(ROOT, "assets", "cat-cafe", "exports", "CatCafe_Palette.png"))
    os.makedirs(OUT, exist_ok=True)
    index_path = os.path.join(OUT, "index.json")
    index = json.load(open(index_path)) if os.path.exists(index_path) else {}
    missing = []
    for cid, name, kind, asset in catalog_items():
        if wanted and not any(w in cid for w in wanted):
            continue
        model = asset + "_Front" if asset + "_Front" in builders else asset
        if model not in builders:
            missing.append((cid, asset))
            continue
        path = render(cid, kind, model, builders[model][0], mat, args.samples)
        index[cid] = {"name": name, "kind": kind, "model": model,
                      "file": os.path.relpath(path, ROOT).replace(os.sep, "/")}
        print("decor icon", cid, "->", path, flush=True)
    with open(index_path, "w") as f:
        json.dump(dict(sorted(index.items())), f, indent=2)
    if missing:
        print("NO MODEL:", missing)
        sys.exit(1)


if __name__ == "__main__":
    main()
