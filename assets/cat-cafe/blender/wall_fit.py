"""Wall fit check (#1187): nothing hung on a cafe wall may sit over a window, a door or another wall piece, at any tier.

The friend's 11-04 screenshot showed the Classic Neon cat sign on top of "a garden and picket fence picture": the
back window (plot.BACK_WIN), with the yard's garden and fence seen through it. The sign and the Alley Mural Print
both hung over that window. This check finds that kind of clash before it ships.

It reads, with no Blender scene:
  - the openings and the fixed wall dressing from plot.py (doors, the front, side and back windows with their
    curtains, the menu board, the back wall shelves, the cat pictures on the side walls)
  - the wall points from games/cat-cafe/src/server/World/Layout.luau: decorAnchors (the Classic pieces and the F48
    Index pieces) and the eight decorSpots (crate furniture and decorations, every one of which can stand at every
    spot)
  - each piece's bounds from exports/manifest.json (so build the pieces first)

On every wall it lays each thing out as a rectangle in the wall's plane (along the wall, and height) and reports:
  WALL   a hung piece (a "wall:" pivot, like the neon sign or a print) over an opening, a fixture or another hung piece
  FLOOR  a floor piece that stands against the wall (its back within FLOOR_NEAR of it) and reaches over a hung piece
         or a fixture, or into a door
  SPOTS  two floor spots on the same wall whose pieces would overlap
Every decor spot is filled at Tier 5 with the Extra Decor Spot perk, so the check takes all eight at once; the tier
sets add nothing on the inside walls apart from the Tier 3 OPEN sign, which stands in its window on purpose (as do
the Window plants on their sill), so those two are allowed in their window.

    python wall_fit.py            # prints the table, exits 1 on any clash
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)

import bpy  # noqa: E402,F401  (plot needs mathutils, which bpy brings)
import plot  # noqa: E402

LAYOUT = os.path.join(ROOT, "games", "cat-cafe", "src", "server", "World", "Layout.luau")
CATALOG = os.path.join(ROOT, "games", "cat-cafe", "src", "shared", "Catalog.luau")
MANIFEST = os.path.join(ROOT, "assets", "cat-cafe", "exports", "manifest.json")
NEAR = 2.6            # a point this close to a wall's inner face is on that wall
FLOOR_NEAR = 0.6      # a floor piece whose back is this close to the wall reads as pressed against it
GAP = 0.1             # rectangles closer than this count as touching

# decorAnchors id -> the models that stand on it (an Index piece and its gold twin share the anchor)
ANCHOR_MODELS = {
    "plants": ["CatCafe_Decor_WindowPlants"],
    "neon_sign": ["CatCafe_Decor_NeonSign"],
    "fish_tank": ["CatCafe_Decor_FishTank"],
    "index_alley": ["CatCafe_Decor_MuralPrint", "CatCafe_Decor_MuralPrint_Gold"],
    "index_park": ["CatCafe_Decor_ParkBench", "CatCafe_Decor_ParkBench_Gold"],
    "index_neighbourhood": ["CatCafe_Decor_MailboxPlanter"],
    "index_woods": ["CatCafe_Decor_MushroomLamp"],
    "index_sewer": ["CatCafe_Decor_PipeFountain"],
}
IN_WINDOW = {"plants"}            # stands in its window on purpose


def _num(expr, env):
    expr = expr.strip()
    for k, v in env.items():
        expr = re.sub(r"\b%s\b" % k, repr(v), expr)
    return float(eval(expr, {"__builtins__": {}}, {}))         # only numbers and + - * / are left


def _point(body, env):
    p = {}
    for key in ("x", "y", "z", "rotY"):
        m = re.search(r"\b%s = ([^,}]+)" % key, body)
        p[key] = _num(m.group(1), env) if m else 0.0
    return p


def layout_points():
    """(anchors {id: point}, spots [point]) in plot space, read from Layout.luau."""
    src = open(LAYOUT, encoding="utf-8").read()
    env = {"halfW": plot.HWI, "halfD": plot.HDI}
    index = {}
    block = src[src.index("local INDEX_SPOTS"):]
    block = block[:block.index("\n}")]
    for name, body in re.findall(r"\n\t(\w+) = (\{[^}]*\})", block):
        index[name] = _point(body, env)
    anchors = {}
    block = src[src.index("decorAnchors = {"):]
    block = block[:block.index("} :: {")]
    for name, rest in re.findall(r"\n\t\t(\w+) = ([^\n]+)", block):
        m = re.match(r"INDEX_SPOTS\.(\w+)", rest)
        anchors[name] = dict(index[m.group(1)]) if m else _point(rest, env)
    block = src[src.index("decorSpots = {"):]
    block = block[:block.index("} :: {")]
    spots = [_point(body, env) for body in re.findall(r"\{[^{}]*\}", block)]
    return anchors, spots


def spot_models():
    """Every crate piece that stands on a decor spot (Catalog CRATE_PIECES furniture and decorations without their own
    asset, which are the anchored Index pieces)."""
    s = open(CATALOG, encoding="utf-8").read()
    block = s[s.index("local CRATE_PIECES"):s.index("Catalog.crateDecor = {}")]
    out = []
    for m in re.finditer(r"\{\s*\n\s*id = \"([^\"]+)\",(.*?)\n\t\t\}", block, re.S):
        body = m.group(2)
        kind = re.search(r"kind = \"(\w+)\"", body).group(1)
        if kind not in ("furniture", "decoration") or re.search(r"asset = ", body):
            continue
        name = re.search(r"name = \"([^\"]+)\"", body).group(1)
        out.append("CatCafe_Decor_" + re.sub(r"[^A-Za-z0-9]", "", name))
    return out


def manifest_bounds():
    """name -> (pivot note, Roblox bounds min, max) from the manifest."""
    m = json.load(open(MANIFEST, encoding="utf-8"))
    out = {}
    for a in m["assets"]:
        if "bounds_min" not in a:
            continue
        bmin, bmax = a["bounds_min"], a["bounds_max"]
        # Blender (x, y, z) -> Roblox (-x, z, y)
        rmin = (-bmax[0], bmin[2], bmin[1])
        rmax = (-bmin[0], bmax[2], bmax[1])
        out[a["name"]] = (str(a.get("pivot", "")), rmin, rmax)
    return out


def _walls_of(p):
    """The walls a plot-space point stands on: 'front', 'back', 'left' (-X), 'right' (+X)."""
    out = []
    if abs(p["z"] + plot.HDI) < NEAR:
        out.append("front")
    if abs(p["z"] - plot.HDI) < NEAR:
        out.append("back")
    if abs(p["x"] + plot.HWI) < NEAR:
        out.append("left")
    if abs(p["x"] - plot.HWI) < NEAR:
        out.append("right")
    return out


def _place(p, rmin, rmax):
    """World box (min, max) of a model with Roblox bounds rmin..rmax pivoted at point p turned rotY about Y."""
    a = math.radians(p.get("rotY", 0.0))
    c, s = math.cos(a), math.sin(a)
    xs_, zs_ = [], []
    for x in (rmin[0], rmax[0]):
        for z in (rmin[2], rmax[2]):
            xs_.append(p["x"] + x * c + z * s)                 # CFrame.Angles(0, a, 0) * (x, _, z)
            zs_.append(p["z"] - x * s + z * c)
    return (min(xs_), p["y"] + rmin[1], min(zs_)), (max(xs_), p["y"] + rmax[1], max(zs_))


def _on_wall(box, wall):
    """(u0, u1, y0, y1, gap): the box seen on the wall (u along it) and how far its nearest face stands off it."""
    (x0, y0, z0), (x1, y1, z1) = box
    if wall == "front":
        return x0, x1, y0, y1, z0 + plot.HDI
    if wall == "back":
        return x0, x1, y0, y1, plot.HDI - z1
    if wall == "left":
        return z0, z1, y0, y1, x0 + plot.HWI
    return z0, z1, y0, y1, plot.HWI - x1


def fixed_rects():
    """{wall: [(label, kind, u0, u1, y0, y1)]}: the openings and the fixed dressing from plot.py. kind is 'door',
    'window' or 'fixture'."""
    HWI, HDI = plot.HWI, plot.HDI
    W = {"front": [], "back": [], "left": [], "right": []}
    d0, d1, dh = plot.DOOR
    W["front"].append(("front door", "door", d0, d1, 0.0, dh + (d1 - d0) / 2))
    for cx in plot.WINDOWS:
        top = plot.SPRING + plot.WIN_R
        W["front"].append((f"front window x {cx:g}", "window", cx - plot.WIN_R, cx + plot.WIN_R, plot.SILL, top))
        for a0, a1 in ((cx - plot.WIN_R - 0.6, cx - plot.WIN_R), (cx + plot.WIN_R, cx + plot.WIN_R + 0.6)):
            W["front"].append((f"curtain rod x {cx:g}", "fixture", a0, a1, 8.6, 8.9))
    z0, z1, y0, y1 = plot.SIDE_WIN
    for wall in ("left", "right"):
        W[wall].append(("side window", "window", z0 - 0.4, z1 + 0.4, y0 - 0.2, y1 + 0.55))     # with its curtains
    b0, b1, bh = plot.BACK_DOOR
    W["back"].append(("back door", "door", b0 - 0.5, b1 + 0.5, 0.0, bh + 0.6))
    if plot.BACK_WIN is not None:
        w0, w1, wy0, wy1 = plot.BACK_WIN
        W["back"].append(("back window", "window", w0, w1, wy0, wy1))
    W["back"].append(("menu board", "fixture", -3.3, 3.3, 5.7, 9.7))
    for (x0, x1, y) in plot.SHELVES:
        W["back"].append((f"wall shelf x {x0:g}", "fixture", x0, x1, y - 0.6, y + 1.9))      # with what stands on it
    for s_, z in plot.PICTURES:
        W["left" if s_ < 0 else "right"].append((f"cat picture z {z:.2f}", "fixture", z - 1.2, z + 1.2, 7.3, 9.5))
    return W


def _overlap(a, b):
    return a[2] < b[3] - GAP and b[2] < a[3] - GAP and a[4] < b[5] - GAP and b[4] < a[5] - GAP


def check():
    anchors, spots = layout_points()
    bounds = manifest_bounds()
    walls = fixed_rects()
    missing, problems, hung, floor = [], [], {w: [] for w in walls}, {w: [] for w in walls}
    for aid, p in anchors.items():
        for model in ANCHOR_MODELS.get(aid, []):
            if model not in bounds:
                missing.append(model)
                continue
            pivot, rmin, rmax = bounds[model]
            box = _place(p, rmin, rmax)
            for wall in _walls_of(p):
                u0, u1, y0, y1, gap = _on_wall(box, wall)
                rect = (f"{aid} ({model})", "wall" if pivot.startswith("wall") else "floor", u0, u1, y0, y1, gap, aid)
                (hung if rect[1] == "wall" else floor)[wall].append(rect)
    for n, p in enumerate(spots, 1):
        for model in spot_models():
            if model not in bounds:
                missing.append(model)
                continue
            _, rmin, rmax = bounds[model]
            box = _place(p, rmin, rmax)
            for wall in _walls_of(p):
                u0, u1, y0, y1, gap = _on_wall(box, wall)
                floor[wall].append((f"spot {n} ({model})", "floor", u0, u1, y0, y1, gap, f"spot{n}"))
    for wall, fixed in walls.items():
        for h in hung[wall]:
            for f in fixed:
                if _overlap(h, f) and not (f[1] == "window" and h[7] in IN_WINDOW):
                    problems.append(("WALL", wall, h[0], f[0]))
            for h2 in hung[wall]:
                if h2[7] < h[7] and _overlap(h, h2):
                    problems.append(("WALL", wall, h[0], h2[0]))
        for fl in floor[wall]:
            if fl[6] > FLOOR_NEAR:
                continue
            for f in fixed:
                if f[1] != "window" and _overlap(fl, f):
                    problems.append(("FLOOR", wall, fl[0], f[0]))
            for h in hung[wall]:
                if _overlap(fl, h):
                    problems.append(("FLOOR", wall, fl[0], h[0]))
        by_spot = {}
        for fl in floor[wall]:
            by_spot.setdefault(fl[7], []).append(fl)
        keys = sorted(by_spot)
        for i, ka in enumerate(keys):
            for kb in keys[i + 1:]:
                ua = (min(r[2] for r in by_spot[ka]), max(r[3] for r in by_spot[ka]))
                ub = (min(r[2] for r in by_spot[kb]), max(r[3] for r in by_spot[kb]))
                if ua[0] < ub[1] - GAP and ub[0] < ua[1] - GAP:
                    problems.append(("SPOTS", wall, f"{ka} {ua[0]:.2f}..{ua[1]:.2f}", f"{kb} {ub[0]:.2f}..{ub[1]:.2f}"))
    return problems, sorted(set(missing))


def main():
    problems, missing = check()
    seen = set()
    for p in problems:
        if p in seen:
            continue
        seen.add(p)
        print("%-5s %-5s %s  over  %s" % p)
    if missing:
        print("NOT BUILT (left out):", ", ".join(missing))
    print("wall fit:", "PASS" if not problems else f"FAIL ({len(seen)} clashes)")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
