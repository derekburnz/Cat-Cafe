"""Z-fighting in the Part-built models (assets/cat-cafe/rbx/*.model.json): two visible faces of different colour or
material in (nearly) the same plane, facing the same way and overlapping. Roblox draws them as a flicker that
crawls as the camera moves (Derek 2026-10-30: table tops that "spin", the night fence "shaking", window frames).

The toolkit's z-fight test runs on the Blender meshes, but the Part export rebuilds them from Roblox's own shapes
(a smooth Cylinder for a 16 sided disc, boxes for a ring), so faces that were apart in Blender can meet in game.
This looks at the Parts themselves: Block faces, Cylinder caps and WedgePart flat faces. A pair counts when its
faces are within NEAR of one plane and the spot just in front of the overlap is not inside a third solid part.

`unfight(tree)` (rbx_export runs it on every model it writes) settles each pair by moving the smaller face: out to
LIFT in front of the bigger one when it was level with it or in front, so trims, rims and bulbs stand proud; back
to LIFT behind it when it was set in, so it hides. Only that face moves (the part grows or shrinks on that side);
pivots and attachments keep their places.

  python3 rbx_zfight.py [--only TableRound,Plot_] [--with CatCafe_Plot_Interior,...] [--out report.md] [--where]
"""

import argparse
import glob
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
RBX = os.path.join(HERE, "..", "rbx")
NEAR = 0.015            # studs: faces this close along their normal fight in Roblox's depth buffer at range
LIFT = 0.03             # studs: how far a settled face sits in front of (or behind) the face it fought
COS_EPS = 0.9995        # normals this close count as the same direction
CAP_SEGMENTS = 24
GROUND = 0.05           # studs: undersides at or below this height sit on the floor
MIN_AREA = 0.002        # studs squared


def _walk(node, out, path=""):
    cls = node.get("className")
    here = f"{path}/{node.get('name', '?')}"
    if cls in ("Part", "WedgePart"):
        p = node["properties"]
        mesh = any(c.get("className") == "SpecialMesh" for c in node.get("children", []))
        if p.get("Transparency", 0) < 0.95 and not mesh and p.get("Material") != "ForceField":
            cf = p["CFrame"]["CFrame"]
            out.append({"name": here, "cls": cls, "shape": p.get("Shape", "Block"), "size": p["Size"],
                        "pos": cf["position"], "rot": cf["orientation"], "color": p.get("Color", [0, 0, 0]),
                        "mat": p.get("Material", "Plastic"), "alpha": p.get("Transparency", 0), "node": node})
    for c in node.get("children", []):
        _walk(c, out, here)


def _axis(rot, j):
    return (rot[0][j], rot[1][j], rot[2][j])


def _add(a, b, k=1.0):
    return (a[0] + k * b[0], a[1] + k * b[1], a[2] + k * b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _local(part, x, y, z):
    p = part["pos"]
    for j, t in enumerate((x, y, z)):
        p = _add(p, _axis(part["rot"], j), t)
    return p


def faces(part):
    """(sign, axis, normal, [world points]) for each flat face of the part: the face is on the part's local
    axis `axis` at `sign` times its half size."""
    sx, sy, sz = part["size"]
    hx, hy, hz = sx / 2, sy / 2, sz / 2

    def L(*q):
        return _local(part, *q)
    out = []
    if part["cls"] == "WedgePart":
        out.append((-1, 1, [L(-hx, -hy, -hz), L(hx, -hy, -hz), L(hx, -hy, hz), L(-hx, -hy, hz)]))   # bottom
        out.append((1, 2, [L(-hx, -hy, hz), L(hx, -hy, hz), L(hx, hy, hz), L(-hx, hy, hz)]))        # back
        for s in (-1, 1):
            out.append((s, 0, [L(s * hx, -hy, -hz), L(s * hx, -hy, hz), L(s * hx, hy, hz)]))
    elif part["shape"] == "Cylinder":
        r = min(sy, sz) / 2
        for s in (-1, 1):
            out.append((s, 0, [L(s * hx, r * math.cos(2 * math.pi * k / CAP_SEGMENTS),
                                 r * math.sin(2 * math.pi * k / CAP_SEGMENTS)) for k in range(CAP_SEGMENTS)]))
    elif part["shape"] == "Block":
        half = (hx, hy, hz)
        for j in range(3):
            a, b = [i for i in range(3) if i != j]
            for s in (-1, 1):
                pts = []
                for (u, v) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    q = [0.0, 0.0, 0.0]
                    q[j], q[a], q[b] = s * half[j], u * half[a], v * half[b]
                    pts.append(L(*q))
                out.append((s, j, pts))
    result = []
    for s, j, pts in out:
        n = _axis(part["rot"], j)
        result.append((s, j, (s * n[0], s * n[1], s * n[2]), pts))
    return result


def _basis(n):
    t = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
    u = (n[1] * t[2] - n[2] * t[1], n[2] * t[0] - n[0] * t[2], n[0] * t[1] - n[1] * t[0])
    lu = math.sqrt(_dot(u, u))
    u = (u[0] / lu, u[1] / lu, u[2] / lu)
    v = (n[1] * u[2] - n[2] * u[1], n[2] * u[0] - n[0] * u[2], n[0] * u[1] - n[1] * u[0])
    return u, v


def _ccw(poly):
    area = sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))
    return poly if area > 0 else poly[::-1]


def _clip(subject, clip):
    """Convex polygon intersection (Sutherland-Hodgman), both counter-clockwise."""
    out = subject
    for i in range(len(clip)):
        a, b = clip[i - 1], clip[i]
        inp, out = out, []
        if not inp:
            break

        def side(w):
            return (b[0] - a[0]) * (w[1] - a[1]) - (b[1] - a[1]) * (w[0] - a[0])
        for k in range(len(inp)):
            p, q = inp[k - 1], inp[k]
            sp, sq = side(p), side(q)
            if sq >= 0:
                if sp < 0:
                    t = sp / (sp - sq)
                    out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
                out.append(q)
            elif sp >= 0:
                t = sp / (sp - sq)
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


def _area(poly):
    return abs(sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))) / 2


def _inside(part, q):
    d = [q[i] - part["pos"][i] for i in range(3)]
    loc = [_dot(d, _axis(part["rot"], j)) for j in range(3)]
    sx, sy, sz = part["size"]
    if part["cls"] == "WedgePart":
        if abs(loc[0]) > sx / 2 or abs(loc[1]) > sy / 2 or abs(loc[2]) > sz / 2:
            return False
        return (loc[1] + sy / 2) / sy <= (loc[2] + sz / 2) / sz       # under the slope
    if part["shape"] == "Cylinder":
        r = min(sy, sz) / 2
        return abs(loc[0]) < sx / 2 and loc[1] ** 2 + loc[2] ** 2 < r * r
    if part["shape"] == "Ball":
        return sum(c * c for c in loc) < (min(part["size"]) / 2) ** 2
    return all(abs(loc[j]) < part["size"][j] / 2 for j in range(3))


def _looks_same(a, b):
    return a["mat"] == b["mat"] and a["alpha"] == b["alpha"] and \
        max(abs(a["color"][i] - b["color"][i]) for i in range(3)) < 0.01


def find(parts, min_area=MIN_AREA):
    """Fighting face pairs among `parts` (records from _walk), biggest overlap first: (area, (part, sign, axis,
    plane, face area), (the other), centre, normal)."""
    for p in parts:
        r = math.sqrt(sum(s * s for s in p["size"])) / 2
        p["lo"] = [p["pos"][i] - r for i in range(3)]
        p["hi"] = [p["pos"][i] + r for i in range(3)]
    groups = {}
    for p in parts:
        for s, j, n, pts in faces(p):
            key = tuple(round(c, 2) + 0.0 for c in n)
            groups.setdefault(key, []).append((_dot(n, pts[0]), s, j, n, pts, p))
    cell = 8.0
    grid = {}
    for p in parts:
        if p["alpha"] > 0:
            continue
        for gx in range(int(p["lo"][0] // cell), int(p["hi"][0] // cell) + 1):
            for gy in range(int(p["lo"][1] // cell), int(p["hi"][1] // cell) + 1):
                for gz in range(int(p["lo"][2] // cell), int(p["hi"][2] // cell) + 1):
                    grid.setdefault((gx, gy, gz), []).append(p)
    found = []
    for fs in groups.values():
        fs.sort(key=lambda f: f[0])
        for i in range(len(fs)):
            d1, s1, j1, n1, pts1, p1 = fs[i]
            k = i + 1
            while k < len(fs) and fs[k][0] - d1 < NEAR:
                d2, s2, j2, n2, pts2, p2 = fs[k]
                k += 1
                if p2 is p1 or _dot(n1, n2) < COS_EPS or _looks_same(p1, p2):
                    continue
                if n1[1] < -0.9 and -max(d1, d2) <= GROUND:      # an underside on the floor: the ground hides it
                    continue
                u, v = _basis(n1)
                a = _ccw([(_dot(q, u), _dot(q, v)) for q in pts1])
                b = _ccw([(_dot(q, u), _dot(q, v)) for q in pts2])
                if max(x for x, _ in a) <= min(x for x, _ in b) or max(x for x, _ in b) <= min(x for x, _ in a):
                    continue
                if max(y for _, y in a) <= min(y for _, y in b) or max(y for _, y in b) <= min(y for _, y in a):
                    continue
                inter = _clip(a, b)
                if len(inter) < 3:
                    continue
                area = _area(inter)
                if area < min_area:
                    continue
                cu = sum(x for x, _ in inter) / len(inter)
                cv = sum(y for _, y in inter) / len(inter)
                c = _add(_add((n1[0] * d2, n1[1] * d2, n1[2] * d2), u, cu), v, cv)
                q = _add(c, n1, LIFT + 0.01)
                cellk = tuple(int(q[i] // cell) for i in range(3))
                if any(o is not p1 and o is not p2 and _inside(o, q) for o in grid.get(cellk, [])):
                    continue                                      # covered by a third part
                found.append((area, (p1, s1, j1, d1, _area(a)), (p2, s2, j2, d2, _area(b)), c, n1))
    found.sort(key=lambda f: -f[0])
    return found


def _move_face(rec, s, j, t):
    """Move the part's face on local axis j, side s, by t along its outward normal (the part grows by t)."""
    props = rec["node"]["properties"]
    size = props["Size"]
    if size[j] + t < 0.02:
        return False
    size[j] = round(size[j] + t, 4)
    n = _axis(rec["rot"], j)
    cf = props["CFrame"]["CFrame"]
    cf["position"] = [round(cf["position"][i] + s * n[i] * t / 2, 4) for i in range(3)]
    shift = s * t / 2            # the part's centre moved this far along its own axis j: keep children in place
    if "PivotOffset" in props:
        po = props["PivotOffset"]["CFrame"]["position"]
        po[j] = round(po[j] - shift, 4)
    for c in rec["node"].get("children", []):
        if c.get("className") == "Attachment":
            ap = c["properties"]["CFrame"]["CFrame"]["position"]
            ap[j] = round(ap[j] - shift, 4)
    return True


def _key(face):
    return (id(face[0]), face[1], face[2])


def _target(small, big, planes):
    """Where the small face goes: LIFT in front of the big one (behind it when it was set in), or further out in the
    same direction when that would land within NEAR of another face it overlaps (`planes`), so a face between two
    others does not hop from one to the other pass after pass."""
    gap = small[3] - big[3]             # how far the small face is in front of the big one
    way = 1 if gap > -0.002 else -1
    tries = [big[3] + way * m * LIFT for m in (1.0, 1.5, 2.0, 2.5, 3.0)]
    for d in tries:
        if all(abs(d - p) >= NEAR + 0.003 for p in planes):
            return d - small[3]
    return tries[0] - small[3]


def unfight(tree, passes=6):
    """Settle every fighting pair in a model tree in place. Returns the number of faces moved."""
    global NEAR
    moved = 0
    for _ in range(passes):
        parts = []
        _walk(tree, parts)
        pairs = find(parts)
        if not pairs:
            break
        near, NEAR = NEAR, NEAR + 3 * LIFT        # every face each one overlaps within reach of a move
        try:
            wide = find(parts)
        finally:
            NEAR = near
        planes = {}
        for _, f1, f2, _, _ in wide:
            planes.setdefault(_key(f1), []).append(f2[3])
            planes.setdefault(_key(f2), []).append(f1[3])
        done = set()
        for _, f1, f2, _, _ in pairs:      # a face moves at most once a pass and its partner stays put that pass
            small, big = (f1, f2) if f1[4] < f2[4] else (f2, f1)
            if _key(small) in done:
                small, big = big, small
                if _key(small) in done:
                    continue
            rec, s, j, _, _ = small
            t = _target(small, big, planes.get(_key(small), [big[3]]))
            if _move_face(rec, s, j, t) or _move_face(rec, s, j, LIFT - (small[3] - big[3])):
                done.add(_key(small))
                done.add(_key(big))
                moved += 1
    return moved


def check(path, extra=()):
    parts = []
    _walk(json.load(open(path)), parts)
    for e in extra:
        _walk(json.load(open(e)), parts)
    return find(parts), len(parts)


def _short(p):
    return p["name"].split("/")[-1] + " [" + ",".join(f"{s:g}" for s in p["size"]) + "]"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--with", dest="extra", default="", help="models checked together with each one, same frame")
    ap.add_argument("--out", default="")
    ap.add_argument("--where", action="store_true")
    args = ap.parse_args()
    keys = [k for k in args.only.split(",") if k]
    extra = [os.path.join(RBX, e + ".model.json") for e in args.extra.split(",") if e]
    rows, detail = [], []
    for path in sorted(glob.glob(os.path.join(RBX, "*.model.json"))):
        name = os.path.basename(path)[:-len(".model.json")]
        if keys and not any(k in name for k in keys):
            continue
        found, count = check(path, [e for e in extra if not e.endswith(name + ".model.json")])
        total = sum(f[0] for f in found)
        rows.append((name, count, len(found), total))
        print(f"{name} parts {count} zfight {len(found)} area {total:.3f}", flush=True)
        if args.where and found:
            detail.append(f"\n### {name}\n")
            for area, f1, f2, c, n in found[:40]:
                detail.append(f"- {area:.3f} at ({c[0]:.2f}, {c[1]:.2f}, {c[2]:.2f}) facing "
                              f"({n[0]:.2f}, {n[1]:.2f}, {n[2]:.2f}), {abs(f1[3] - f2[3]):.3f} apart: "
                              f"{_short(f1[0])} / {_short(f2[0])}\n")
    if args.out:
        with open(args.out, "w") as f:
            f.write("# Part z-fighting report\n\nGenerated by `assets/cat-cafe/blender/rbx_zfight.py`: visible faces "
                    f"of different colour or material within {NEAR} studs of one plane, facing the same way, "
                    "overlapping, and not covered by a third part.\n\n"
                    "| Model | Parts | Z-fight pairs | Area (studs²) |\n|---|---|---|---|\n")
            for name, count, n, total in rows:
                f.write(f"| {name} | {count} | {n} | {total:.3f} |\n")
            f.writelines(detail)


if __name__ == "__main__":
    main()
