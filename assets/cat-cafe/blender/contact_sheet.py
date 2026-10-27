"""Tile preview PNGs into contact sheets (cats, cafe, alley and park, items) using bpy images."""

import os

import bpy


def _load(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = [0.0] * (w * h * 4)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return w, h, px


def _downscale(w, h, px, f):
    """Box downscale by integer factor f."""
    nw, nh = w // f, h // f
    out = [0.0] * (nw * nh * 4)
    inv = 1.0 / (f * f)
    for y in range(nh):
        for x in range(nw):
            acc = [0.0, 0.0, 0.0, 0.0]
            for dy in range(f):
                row = ((y * f + dy) * w + x * f) * 4
                for dx in range(f):
                    o = row + dx * 4
                    acc[0] += px[o]; acc[1] += px[o + 1]; acc[2] += px[o + 2]; acc[3] += px[o + 3]
            o = (y * nw + x) * 4
            out[o:o + 4] = [acc[0] * inv, acc[1] * inv, acc[2] * inv, acc[3] * inv]
    return nw, nh, out


def _over(px, bg):
    """Straight-alpha pixels composited over the opaque sheet colour (Cycles view tiles)."""
    out = list(px)
    for i in range(0, len(px), 4):
        a = px[i + 3]
        if a < 1.0:
            out[i] = px[i] * a + bg[0] * (1.0 - a)
            out[i + 1] = px[i + 1] * a + bg[1] * (1.0 - a)
            out[i + 2] = px[i + 2] * a + bg[2] * (1.0 - a)
            out[i + 3] = 1.0
    return out


def sheet(paths, out_path, cols=4, factor=2, bg=(0.96, 0.92, 0.87, 1.0)):
    tiles = []
    for p in paths:
        if os.path.exists(p):
            w, h, px = _load(p)
            if min(px[3::4]) < 1.0:
                px = _over(px, bg)
            tiles.append(_downscale(w, h, px, factor))
    if not tiles:
        return None
    tw, th = tiles[0][0], tiles[0][1]
    rows = (len(tiles) + cols - 1) // cols
    W, H = cols * tw, rows * th
    out = list(bg) * (W * H)
    for i, (w, h, px) in enumerate(tiles):
        cx, cy = i % cols, rows - 1 - i // cols     # bpy rows start at the bottom
        for y in range(h):
            src = (y * w) * 4
            dst = ((cy * th + y) * W + cx * tw) * 4
            out[dst:dst + w * 4] = px[src:src + w * 4]
    img = bpy.data.images.new(os.path.basename(out_path), W, H)
    img.pixels.foreach_set(out)
    img.filepath_raw = out_path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out_path


def build_sheets(docs_dir, manifest):
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    groups = {
        "sheet_cats": [e for e in manifest if e["category"] == "Cat" and not e["name"].endswith("_Gold")],
        "sheet_cafe": [e for e in manifest if e["category"] in ("Furniture", "Decor", "NPC")],
        "sheet_outdoors": [e for e in manifest if e["category"] in ("Alley", "Park", "Street", "Neighbourhood", "Woods",
                                                                   "Sewer")],
        "sheet_items": [e for e in manifest if e["category"] in ("Item", "Accessory", "Prop")],
        "sheet_plot": [e for e in manifest if e["category"] == "Plot"],
    }
    extras = [os.path.join(docs_dir, "previews", n + ".png") for n in
              ("CatCafe_Accessory_Set", "Pose_Upright", "Pose_Uniforms", "Pose_Carried",
               "CatCafe_Alley_TrashBin", "CatCafe_Alley_GarbageBags", "CatCafe_Park_RescueTree", "CatCafe_Park_TrashCan",
               "CatCafe_VFX_ShinySparkle")]
    extras = [p for p in extras if os.path.exists(p)]
    if extras:
        sheet(extras, os.path.join(docs_dir, "sheet_poses.png"), cols=3)
    made = []
    gold = {e["name"]: e for e in manifest if e["name"].endswith("_Gold") and "preview" in e}
    pairs = []                                            # each cat beside its gold version
    for e in groups["sheet_cats"]:
        if e["name"] + "_Gold" in gold and "preview" in e:
            pairs += [os.path.join(root, e["preview"]), os.path.join(root, gold[e["name"] + "_Gold"]["preview"])]
    if pairs:
        made.append(sheet(pairs, os.path.join(docs_dir, "sheet_gold.png"), cols=8))
    for name, entries in groups.items():
        paths = [os.path.join(root, e["preview"]) for e in entries if "preview" in e]
        if paths:
            made.append(sheet(paths, os.path.join(docs_dir, name + ".png")))
    return made
