"""Cat spots clear of solid props (Laptop-Tester's Studio pass on #2675, 2026-11-09: 18 of the Desert's spots and 17
of the Ruins' were inside crates, canyon walls, rocks, urns, columns and the like, and a stray spawned inside a crate).

A set's cat spots (manifest points_roblox, every label but the trap_ rescue spots, which stand inside their trap on
purpose) each need a cat-sized box clear of every CanCollide part of the set's Part model: CAT_HALF across in x and
z (the cat may face any way) from LIFT above the spot to CAT_TOP, and any two stand MIN_GAP apart. The check reads
the written rbx model, so it sees the parts as Roblox will, invisible barriers and colliders included.

`settle` moves a blocked spot to the nearest place beside it that is clear by MARGIN more (at the same height when
a top holds it there, else on the floor), keeping its zone (near z < 0, deep z > 0), MIN_GAP from the other cat spots
and TRAP_GAP from the rescue spots. build_all runs it on the sets in SETTLE as it writes them and then `check` as
their cat_spots gate (FAIL), so a blocked spot can't come back. The older sets keep some spots on purpose inside a
piece (the camps' basket, porches, the Lost Lounge's sofa); this script reports them all.

  python3 spot_clear.py [--only Desert,Ruins]     # report from the written models and the manifest
"""

import argparse
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")                   # assets/cat-cafe
REPO = os.path.join(ROOT, "..", "..")
CAT_HALF = 1.1          # studs: half the cat's footprint, any facing (a walking Tabby is about 2.2 long)
LIFT = 0.2              # the box starts this far above the spot, clear of the floor and low ground pieces
CAT_TOP = 2.0           # and ends this far above it
MIN_GAP = 4.0           # a moved spot keeps this far from every other cat spot (Layout.spec: spawn points 4 apart)
TRAP_GAP = 6.0          # and this far from every rescue spot
EDGE = 6.0              # and this far inside the set's footprint
MARGIN = 0.4           # a moved spot's box is this much wider all round, so it stands clear rather than touching
SUPPORT = 0.2           # a spot above the floor needs a collidable top within this of its height under it
SETTLE = ("CatCafe_Desert_Set", "CatCafe_Ruins_Set", "CatCafe_Snowy_Set", "CatCafe_WaterPark_Set")


def _walk(node, out):
    if node.get("className") in ("Part", "WedgePart"):
        p = node["properties"]
        if p.get("CanCollide", True):
            cf = p["CFrame"]["CFrame"]
            rot = cf["orientation"]
            out.append({"name": node.get("name", "?"), "pos": cf["position"], "size": p["Size"],
                        "axes": [(rot[0][j], rot[1][j], rot[2][j]) for j in range(3)]})
    for c in node.get("children", []):
        _walk(c, out)


def parts(rbx_path):
    """The model's collidable parts as boxes (a ball or cylinder by its bounding box, which is the safe side)."""
    with open(rbx_path) as f:
        tree = json.load(f)
    out = []
    _walk(tree, out)
    for p in out:
        p["half"] = [s / 2 for s in p["size"]]
        p["reach"] = math.sqrt(sum(h * h for h in p["half"]))
    return out


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


WORLD = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def _overlap(p, c, h, eps=0.02):
    """Whether part p overlaps the world-aligned box at centre c with half sizes h by more than eps (separating
    axis test)."""
    d = (p["pos"][0] - c[0], p["pos"][1] - c[1], p["pos"][2] - c[2])
    axes = list(WORLD) + p["axes"] + [_cross(a, b) for a in WORLD for b in p["axes"]]
    for ax in axes:
        n = math.sqrt(_dot(ax, ax))
        if n < 1e-6:
            continue
        ax = (ax[0] / n, ax[1] / n, ax[2] / n)
        ra = sum(h[i] * abs(ax[i]) for i in range(3))
        rb = sum(p["half"][j] * abs(_dot(p["axes"][j], ax)) for j in range(3))
        if abs(_dot(d, ax)) >= ra + rb - eps:
            return False
    return True


def blockers(ps, x, y, z, pad=0.0):
    """Names of the collidable parts in the cat box over the spot (x, y, z), its sides out by pad."""
    c = (x, y + (LIFT + CAT_TOP) / 2, z)
    h = (CAT_HALF + pad, (CAT_TOP - LIFT) / 2, CAT_HALF + pad)
    reach = math.sqrt(sum(v * v for v in h))
    out = []
    for p in ps:
        if math.dist(p["pos"], c) > p["reach"] + reach:
            continue
        if _overlap(p, c, h):
            out.append(p["name"])
    return out


def _held(ps, x, y, z):
    """Whether a collidable top within SUPPORT of height y lies under (x, z)."""
    for p in ps:
        if math.hypot(p["pos"][0] - x, p["pos"][2] - z) > p["reach"]:
            continue
        d = (x - p["pos"][0], y - SUPPORT / 2 - p["pos"][1], z - p["pos"][2])
        local = [_dot(d, a) for a in p["axes"]]
        if all(abs(local[j]) <= p["half"][j] + (SUPPORT / 2 if j == 1 else 0.0) for j in range(3)):
            top = p["pos"][1] + sum(p["half"][j] * abs(p["axes"][j][1]) for j in range(3))
            if abs(top - y) <= SUPPORT:
                return True
    return False


def cat_labels(points):
    return [k for k in points if not k.startswith("trap_")]


def check(rbx_path, points):
    """(ok, detail, [(label, index, (x, y, z), [blocker names])]) for every cat spot of the set."""
    ps = parts(rbx_path)
    bad = []
    n = 0
    for label in cat_labels(points):
        for i, pt in enumerate(points[label]):
            n += 1
            hit = blockers(ps, pt[0], pt[1], pt[2])
            if hit:
                bad.append((label, i, tuple(pt[:3]), sorted(set(hit))))
    flat = [(lb, i, p) for lb in cat_labels(points) for i, p in enumerate(points[lb])]
    close = [(a, b) for k, a in enumerate(flat) for b in flat[k + 1:]
             if math.hypot(a[2][0] - b[2][0], a[2][2] - b[2][2]) < MIN_GAP]
    if close:
        return False, f"{len(close)} pairs of cat spots under {MIN_GAP} apart: " + "; ".join(
            f"{a[0]}[{a[1]}] and {b[0]}[{b[1]}]" for a, b in close[:8]), bad
    if not bad:
        return True, f"{n} cat spots clear of every collidable part", bad
    return False, f"{len(bad)} of {n} cat spots in a collidable part: " + "; ".join(
        f"{lb}[{i}] ({p[0]}, {p[1]}, {p[2]}) in {', '.join(h[:2])}" for lb, i, p, h in bad[:8]), bad


def settle(rbx_path, points, lo, hi):
    """Move each blocked cat spot of `points` (edited in place) to the nearest clear place beside it within the
    footprint lo..hi (area-space x, z). Returns [(label, from, to)] and the spots it could not move."""
    ps = parts(rbx_path)
    traps = [p for k, v in points.items() if k.startswith("trap_") for p in v]
    moved, stuck = [], []
    for label in cat_labels(points):
        for i, pt in enumerate(points[label]):
            x0, y0, z0 = pt[0], pt[1], pt[2]
            if not blockers(ps, x0, y0, z0):
                continue
            others = [q for k in cat_labels(points) for q in points[k] if q is not pt]
            best = None
            for r10 in range(5, 121, 5):                     # nearest first: rings 0.5 to 12 studs out
                r = r10 / 10
                steps = max(12, int(2 * math.pi * r / 0.5))
                for k in range(steps):
                    a = 2 * math.pi * k / steps
                    x, z = round(x0 + r * math.cos(a), 2), round(z0 + r * math.sin(a), 2)
                    inside = lo[0] + EDGE <= x <= hi[0] - EDGE and lo[1] + EDGE <= z <= hi[1] - EDGE
                    if (z < 0) != (z0 < 0) or not inside:
                        continue
                    if any(math.hypot(x - q[0], z - q[2]) < MIN_GAP for q in others):
                        continue
                    if any(math.hypot(x - q[0], z - q[2]) < TRAP_GAP for q in traps):
                        continue
                    for y in ((y0, 0.0) if y0 > 0.05 else (0.0,)):
                        if y > 0.05 and not _held(ps, x, y, z):
                            continue
                        if not blockers(ps, x, y, z, MARGIN):
                            best = (x, y, z)
                            break
                    if best:
                        break
                if best:
                    break
            if best is None:
                stuck.append((label, i, (x0, y0, z0)))
                continue
            new = [best[0], round(best[1], 2), best[2]] + list(pt[3:])
            if isinstance(pt, list):
                pt[:] = new
            else:
                points[label][i] = tuple(new)
            moved.append((label, (x0, y0, z0), best))
    return moved, stuck


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    with open(os.path.join(ROOT, "exports", "manifest.json")) as f:
        assets = json.load(f)["assets"]
    only = [s for s in args.only.split(",") if s]
    for e in assets:
        if "points_roblox" not in e or "rbx_model" not in e or (only and not any(o in e["name"] for o in only)):
            continue
        ok, detail, _ = check(os.path.join(REPO, e["rbx_model"]), e["points_roblox"])
        print(f"{e['name']:32s} {'ok  ' if ok else 'FAIL'} {detail}")


if __name__ == "__main__":
    main()
