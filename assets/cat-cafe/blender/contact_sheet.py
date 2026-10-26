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


def sheet(paths, out_path, cols=4, factor=2, bg=(0.96, 0.92, 0.87, 1.0)):
    tiles = []
    for p in paths:
        if os.path.exists(p):
            w, h, px = _load(p)
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
        "sheet_cats": [e for e in manifest if e["category"] == "Cat"],
        "sheet_cafe": [e for e in manifest if e["category"] in ("Furniture", "Decor", "NPC")],
        "sheet_outdoors": [e for e in manifest if e["category"] in ("Alley", "Park")],
        "sheet_items": [e for e in manifest if e["category"] == "Item"],
    }
    made = []
    for name, entries in groups.items():
        paths = [os.path.join(root, e["preview"]) for e in entries if "preview" in e]
        if paths:
            made.append(sheet(paths, os.path.join(docs_dir, name + ".png")))
    return made
