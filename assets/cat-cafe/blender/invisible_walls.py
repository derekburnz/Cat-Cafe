"""Invisible walls: where a set's collision stands out past what a player can see (#2897).

Reads rbx/<Name>.model.json (no Blender needed), voxelises it at --step (default 0.5) from the floor up to --top
(default 16, a jump off anything a player can stand on) and marks every voxel that is solid (inside a CanCollide
part's collision shape) and every voxel that is drawn (inside a visible part's drawn shape, grown by --tol, default
0.35, so a face a hair behind a drawn face does not count). A solid voxel that is not drawn and touches open air is a
place a player bumps into nothing. Each collision part with such voxels is listed with the area of its invisible
faces (voxel faces open to air, in square studs) and where they are.

Collision shapes are Roblox's: a Part is its box, a WedgePart its wedge, a Ball its sphere, a Cylinder its cylinder,
and a Part with a SpecialMesh Sphere collides as its Part box while it draws the ellipsoid of its size times the
mesh Scale (rbx_export's ELLIPSOID_FIT). Transparency 1 draws nothing.

  python3 blender/invisible_walls.py --only CatCafe_Desert_Set [--edge 71.5,276.5] [--min 2]

--edge x,z leaves out everything at or past |x| or |z| (the area's border band, which keeps its barrier on purpose),
--min hides parts with less than that many square studs. The exit code is 0 either way: it is a report.
"""

import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RBX = os.path.join(HERE, "..", "rbx")


def _parts(node, out):
    for c in node.get("children", []):
        cls = c.get("className")
        if cls in ("Part", "WedgePart", "TrussPart"):
            p = c["properties"]
            cf = p["CFrame"].get("CFrame", p["CFrame"])
            mesh = next((k for k in c.get("children", []) if k.get("className") == "SpecialMesh"), None)
            out.append({
                "name": c["name"], "cls": cls, "pos": np.array(cf["position"], float),
                "rot": np.array(cf["orientation"], float), "size": np.array(p["Size"], float),
                "shape": p.get("Shape", "Block"), "collide": p.get("CanCollide", True),
                "visible": p.get("Transparency", 0.0) < 0.95,
                "mesh": (mesh["properties"].get("MeshType"), np.array(mesh["properties"].get("Scale", [1, 1, 1]), float))
                if mesh else None,
            })
        _parts(c, out)


def _inside(part, P, drawn, tol):
    """Boolean mask: which world points P (n x 3) are inside the part's collision (drawn False) or drawn shape."""
    L = (P - part["pos"]) @ part["rot"]          # world -> local: R^T (p - pos), rows of P
    half = part["size"] / 2
    if part["mesh"] and part["mesh"][0] == "Sphere":
        if not drawn:
            return np.all(np.abs(L) <= half, axis=1)
        a = half * part["mesh"][1] + tol
        return np.sum((L / a) ** 2, axis=1) <= 1.0
    t = tol if drawn else 0.0
    if part["shape"] == "Ball":
        return np.sum(L ** 2, axis=1) <= (min(half) + t) ** 2
    if part["shape"] == "Cylinder":
        r = min(half[1], half[2]) + t
        return (np.abs(L[:, 0]) <= half[0] + t) & (L[:, 1] ** 2 + L[:, 2] ** 2 <= r * r)
    box = np.all(np.abs(L) <= half + t, axis=1)
    if part["cls"] == "WedgePart":
        # tall at +Z, sloping down to -Z: inside below the plane through (y -h/2, z -d/2) and (y h/2, z d/2)
        h, d = part["size"][1], part["size"][2]
        n = np.array([h, -d]) / math.hypot(h, d)          # normal of the slope, pointing out (up and toward -Z)
        box &= L[:, 1] * n[0] + L[:, 2] * n[1] <= t          # the slope's plane runs through the middle
    return box


def _aabb(part, drawn, tol):
    half = part["size"] / 2
    if drawn and part["mesh"] and part["mesh"][0] == "Sphere":
        half = half * part["mesh"][1]
    ext = np.abs(part["rot"]) @ half + (tol if drawn else 0.0)
    return part["pos"] - ext, part["pos"] + ext


def run(name, step, top, tol, edge, min_area, floor=0.0):
    model = json.load(open(os.path.join(RBX, name + ".model.json")))
    parts = []
    _parts(model, parts)
    lo = np.min([_aabb(p, False, 0)[0] for p in parts], axis=0)
    hi = np.max([_aabb(p, False, 0)[1] for p in parts], axis=0)
    lo[1], hi[1] = floor, floor + top
    nx, ny, nz = (np.ceil((hi - lo) / step).astype(int) + 1)
    solid = np.zeros((nx, ny, nz), bool)
    drawn = np.zeros((nx, ny, nz), bool)
    owner = {}

    def cells(part, is_drawn):
        a, b = _aabb(part, is_drawn, tol)
        i0 = np.maximum(np.floor((a - lo) / step).astype(int), 0)
        i1 = np.minimum(np.ceil((b - lo) / step).astype(int), [nx - 1, ny - 1, nz - 1])
        if np.any(i1 < i0):
            return None
        gx, gy, gz = (np.arange(i0[k], i1[k] + 1) for k in range(3))
        G = np.stack(np.meshgrid(gx, gy, gz, indexing="ij"), -1).reshape(-1, 3)
        P = lo + G * step
        m = _inside(part, P, is_drawn, tol)
        return G[m]

    for idx, p in enumerate(parts):
        if p["visible"]:
            g = cells(p, True)
            if g is not None and len(g):
                drawn[g[:, 0], g[:, 1], g[:, 2]] = True
        if p["collide"]:
            g = cells(p, False)
            if g is not None and len(g):
                solid[g[:, 0], g[:, 1], g[:, 2]] = True
                owner[idx] = g
    ghost = solid & ~drawn
    air = ~solid
    rows = []
    for idx, g in owner.items():
        gg = g[ghost[g[:, 0], g[:, 1], g[:, 2]]]
        if not len(gg):
            continue
        faces = 0
        for axis in range(3):
            for d in (-1, 1):
                nb = gg.copy()
                nb[:, axis] += d
                ok = (nb[:, axis] >= 0) & (nb[:, axis] < solid.shape[axis])
                open_ = np.zeros(len(gg), bool)
                open_[ok] = air[nb[ok, 0], nb[ok, 1], nb[ok, 2]]
                if axis == 1 and d == -1:
                    open_[gg[:, 1] == 0] = False        # the floor is solid
                faces += int(open_.sum())
        if not faces:
            continue
        P = lo + gg * step
        if edge is not None:
            keep = (np.abs(P[:, 0]) < edge[0]) & (np.abs(P[:, 2]) < edge[1])
            if not keep.any():
                continue
        area = faces * step * step
        if area < min_area:
            continue
        p = parts[idx]
        rows.append((area, p["name"], p["cls"] + ("+Sphere" if p["mesh"] else ""), p["pos"],
                     (P[:, 1].min(), P[:, 1].max())))
    rows.sort(key=lambda r: -r[0])
    return rows, len(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", required=True)
    ap.add_argument("--step", type=float, default=0.5)
    ap.add_argument("--top", type=float, default=16.0)
    ap.add_argument("--tol", type=float, default=0.35)
    ap.add_argument("--edge", default=None)
    ap.add_argument("--min", type=float, default=2.0)
    a = ap.parse_args()
    edge = tuple(float(v) for v in a.edge.split(",")) if a.edge else None
    total = 0.0
    for name in a.only.split(","):
        rows, n = run(name, a.step, a.top, a.tol, edge, a.min)
        print(f"{name}: {n} parts, {len(rows)} with invisible collision of {a.min} sq studs or more")
        for area, pname, cls, pos, (y0, y1) in rows:
            total += area
            print(f"  {area:8.1f}  {pname:44s} {cls:16s} at ({pos[0]:7.1f}, {pos[1]:5.1f}, {pos[2]:7.1f})"
                  f"  y {y0:.1f} to {y1:.1f}")
    print(f"total {total:.1f} sq studs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
