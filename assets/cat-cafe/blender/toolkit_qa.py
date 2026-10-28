"""Run the EL4CTEO blender-skills toolkit over the asset library and say where each finding lives in our code.

    python toolkit_qa.py [--only Counter,Plot] [--out ../exports/toolkit_qa.md]

For every asset in build_all it runs, from .claude/skills:
  blender-asset-qa          qa_check.run(profile="roblox"): z-fighting, floating parts, normals, n-gons, UVs, scale
  blender-game-optimization mesh_stats.run(budget="roblox"): triangles, draw calls, texture memory
then a locator pass that repeats qa_check's z-fighting and floating tests with every face tagged by its palette
swatch and the builder call (file:line) that made it, so a finding points at the line to change.

How to read it (Cat Cafe specifics, see docs/art/style-guide.md section 10):
- "zero-area UV faces" is by design: every face is UV'd to one palette swatch centre. Dropped from the counts.
- A z-fight pair only shows in game when the two faces have different colours and nothing covers them. The locator
  counts those as "visible"; same-colour pairs, undersides on the floor and faces buried inside another part are
  listed as hidden. Fix visible ones by moving one face 0.01 studs (proud, recessed or past the other's edge).
- Floating parts with a gap under 0.05 studs cannot be seen. Bigger gaps are listed with their code line; some are
  meant (sparkles, litter lying on the ground, add-on parts that touch the cafe shell, not each other).
"""
import argparse
import inspect
import os
import sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SKILLS = os.path.join(ROOT, ".claude", "skills")
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(SKILLS, "blender-asset-qa", "scripts"))
sys.path.insert(0, os.path.join(SKILLS, "blender-game-optimization", "scripts"))

import bpy  # noqa: E402  (first: the bpy module provides bmesh and mathutils)
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import common  # noqa: E402
import mesh_stats  # noqa: E402  (blender-game-optimization)
import palette  # noqa: E402
import qa_check  # noqa: E402  (blender-asset-qa)

EPS, TOL, VISIBLE_GAP = 0.001, 0.002, 0.05
CALLERS = {}
SWN = [s[0] for s in palette.SWATCHES]

# tag every face with the builder call that made it (kept off the normal build path)
_init, _log, _tag, _fin = common.Builder.__init__, common.Builder._log, common.Builder._tag, common.Builder.finalize


def _p_init(self, *a, **kw):
    _init(self, *a, **kw)
    self.pr = self.bm.faces.layers.int.new("prim")
    self.callers = []


def _p_log(self, kind, matrix, swatch, extra=None):
    _log(self, kind, matrix, swatch, extra)
    site = "?"
    for fr in inspect.stack()[1:12]:
        fn = os.path.basename(fr.filename)
        if fn != "common.py" and fn.endswith(".py"):
            site = f"{fn}:{fr.lineno}"
            break
    self.callers.append(f"{kind}@{site}")


def _p_tag(self, verts, swatch, bevel):
    out = _tag(self, verts, swatch, bevel)
    k = len(self.prims) - 1
    for v in verts:
        for f in v.link_faces:
            f[self.pr] = k
    return out


def _p_fin(self, name, mat, *a, **kw):
    callers = self.callers
    ob = _fin(self, name, mat, *a, **kw)
    CALLERS[ob.data.name] = callers
    return ob


common.Builder.__init__, common.Builder._log = _p_init, _p_log
common.Builder._tag, common.Builder.finalize = _p_tag, _p_fin
import build_all  # noqa: E402  (after the patch, so every module builds through it)


def _solids(objs):
    out = []
    for ob in objs:
        for kind, m, _sw, _ex in common.PRIMS.get(ob.data.name, []):
            if kind in ("box", "cyl", "sphere"):
                try:
                    out.append((kind, (ob.matrix_world @ m).inverted()))
                except ValueError:
                    pass
    return out


def _inside_prim(solids, q):
    for kind, inv in solids:
        p = inv @ q
        if kind == "box" and max(abs(p.x), abs(p.y), abs(p.z)) < 0.5 - 1e-4:
            return True
        if kind == "cyl" and p.x * p.x + p.y * p.y < 0.249 and abs(p.z) < 0.4999:
            return True
        if kind == "sphere" and p.length < 0.499:
            return True
    return False


def locate(objs):
    """qa_check's z-fight and floating tests, per face swatch and builder line."""
    verts, tris, meta = [], [], []           # meta: (object index, swatch, prim, normal, island)
    dg = bpy.context.evaluated_depsgraph_get()
    base_island = 0
    for oi, ob in enumerate(objs):
        bm = bmesh.new()
        bm.from_object(ob, dg)
        bm.transform(ob.matrix_world)
        sw, pr = bm.faces.layers.int.get("swatch"), bm.faces.layers.int.get("prim")
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.verts.ensure_lookup_table()
        isl = qa_check._islands(bm)
        base = len(verts)
        verts += [v.co.copy() for v in bm.verts]
        for f in bm.faces:
            tris.append(tuple(base + v.index for v in f.verts))
            meta.append((oi, f[sw] if sw else -1, f[pr] if pr else -1, f.normal.copy(),
                         base_island + isl[f.verts[0].index]))
        base_island += (max(isl) + 1) if isl else 0
        bm.free()
    if not tris:
        return {"visible": [], "hidden": 0, "floating": {}}
    bvh = BVHTree.FromPolygons(verts, tris, epsilon=0.0)
    tri_sets = [set(t) for t in tris]
    pairs = set()
    for ti, t in enumerate(tris):
        n = meta[ti][3]
        if n.length < 0.5:
            continue
        a, b, c = (verts[i] for i in t)
        cen = (a + b + c) / 3
        for p in (cen, cen.lerp(a, .6), cen.lerp(b, .6), cen.lerp(c, .6)):
            for _, _, tj, _ in bvh.find_nearest_range(p, EPS):
                if tj is None or tj == ti or tri_sets[ti] & tri_sets[tj]:
                    continue
                n2 = meta[tj][3]
                if n.dot(n2) < 0.999:
                    continue
                a2, b2, c2 = (verts[i] for i in tris[tj])
                if qa_check._point_in_tri(p - n2 * n2.dot(p - a2), a2, b2, c2, n2):
                    pairs.add((min(ti, tj), max(ti, tj)))

    def site(ti):
        oi, _, pk, _, _ = meta[ti]
        cl = CALLERS.get(objs[oi].data.name, [])
        return cl[pk] if 0 <= pk < len(cl) else "?"

    solids, zmin = _solids(objs), min(v.z for v in verts)
    visible, hidden = Counter(), 0
    for i, j in pairs:
        si, sj = meta[i][1], meta[j][1]
        c0 = sum((verts[k] for k in tris[i]), Vector()) / 3
        n = meta[i][3]
        oi, oj = objs[meta[i][0]].name, objs[meta[j][0]].name
        if (si == sj or (n.z < -0.99 and (c0.z < zmin + 0.01 or abs(c0.z) < 0.01))
                or (oi != oj and {oi.rsplit("_", 1)[-1], oj.rsplit("_", 1)[-1]} == {"Open", "Closed"})
                or _inside_prim(solids, c0 + n * 0.004)):
            hidden += 1
            continue
        key = tuple(sorted((f"{site(i)} [{SWN[si]}]", f"{site(j)} [{SWN[sj]}]")))
        visible[key] += 1
        if os.environ.get("QA_WHERE"):                                  # where each visible pair sits, Roblox x y z
            print(f"   overlap {SWN[si]} vs {SWN[sj]} at ({-c0.x:.2f}, {c0.z:.2f}, {c0.y:.2f}) facing "
                  f"({-n.x:.2f}, {n.z:.2f}, {n.y:.2f})", flush=True)
    isl_tris = defaultdict(list)
    for ti, m in enumerate(meta):
        isl_tris[m[4]].append(ti)
    tri_isl = [m[4] for m in meta]
    biggest = max(isl_tris, key=lambda g: len(isl_tris[g]))
    floating = {}
    for g, ts in isl_tris.items():
        if g == biggest:
            continue
        vs = sorted({v for t in ts for v in tris[t]})
        touching = any(tj is not None and tri_isl[tj] != g
                       for vi in vs[::max(1, len(vs) // 400)] for _, _, tj, _ in bvh.find_nearest_range(verts[vi], TOL))
        if not touching:
            sub = BVHTree.FromPolygons(verts, [tris[t] for t in ts], epsilon=0.0)
            touching = any(tri_isl[j] != g for _, j in sub.overlap(bvh))
        if touching:
            continue
        mine = BVHTree.FromPolygons(verts, [tris[t] for t in ts], epsilon=0.0)
        others = BVHTree.FromPolygons(verts, [t for k, t in enumerate(tris) if tri_isl[k] != g], epsilon=0.0)
        vset = set(vs)
        gap = min(min((mine.find_nearest(verts[v])[3] for v in range(len(verts)) if v not in vset), default=0.0),
                  min((others.find_nearest(verts[v])[3] for v in vs[::max(1, len(vs) // 50)]), default=0.0))
        if gap <= TOL:
            continue                                         # another part rests flush on this one
        k = site(ts[0])
        floating[k] = max(floating.get(k, 0.0), round(gap, 3))
        if os.environ.get("QA_WHERE") and gap >= VISIBLE_GAP:          # where each floating island sits, Roblox x z y
            c = sum((verts[v] for v in vs), Vector()) / len(vs)
            print(f"   floating {gap:.3f} {k} at ({-c.x:.2f}, {c.y:.2f}, {c.z:.2f})", flush=True)
    return {"visible": visible.most_common(), "hidden": hidden, "floating": floating}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "cat-cafe", "exports", "toolkit_qa.md"))
    args = ap.parse_args(argv)
    wanted = [w.strip().lower() for w in args.only.split(",") if w.strip()]
    common.reset_scene()
    mat = common.palette_material(os.path.join(ROOT, "assets", "cat-cafe", "exports", palette.TEXTURE_NAME + ".png"))
    rows, details = [], []
    for name, (fn, _budget, _module) in build_all.all_assets().items():
        if wanted and not any(w in name.lower() for w in wanted):
            continue
        for ob in list(bpy.data.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        objs = [o for o in fn(mat) if o.type == "MESH" and not o.name.endswith(("_Climb", "_Fireflies", "_Barrier"))]
        bpy.context.view_layer.update()
        names = [o.name for o in objs]
        q = qa_check.run(objects=names, profile="roblox")
        st = mesh_stats.run(objects=names, budget="roblox")
        errs = [e for e in q["errors"] if "zero-area UV" not in e]
        loc = locate(objs)
        vis = sum(n for _, n in loc["visible"])
        far = {k: g for k, g in loc["floating"].items() if g >= VISIBLE_GAP}
        rows.append(f"| {name} | {st.get('total_tris')} | {st.get('draw_calls_est')} | {len(errs)} | "
                    f"{len(q['warnings'])} | {vis} | {loc['hidden']} | {len(far)} |")
        if vis or far:
            details.append(f"\n### {name}\n")
            details += [f"- overlap, {n} tri pairs: {a} vs {b}" for (a, b), n in loc["visible"]]
            details += [f"- floating {g} studs: {k}" for k, g in sorted(far.items(), key=lambda kv: -kv[1])]
        print(name, "visible", vis, "floating", len(far), flush=True)
    with open(args.out, "w") as f:
        f.write("# Toolkit QA report\n\nGenerated by `assets/cat-cafe/blender/toolkit_qa.py` with the EL4CTEO "
                "blender-skills (blender-asset-qa `roblox` profile, blender-game-optimization `roblox` budget). "
                "Zero-area UV errors are left out (palette swatch UVs are deliberate).\n\n"
                "| Asset | Tris | Draw calls | qa_check errors | warnings | visible overlaps | hidden overlaps | "
                "floating parts (gap >= 0.05) |\n|---|---|---|---|---|---|---|---|\n")
        f.write("\n".join(rows) + "\n\n## Where to look\n" + ("\n".join(details) if details else "\nNothing visible.") + "\n")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
