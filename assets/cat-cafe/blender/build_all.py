"""Build every Cat Cafe asset: mesh, FBX + GLB export, preview PNGs, manifest.

Run with the bpy module:      python build_all.py [--render] [--scenes] [--only Tabby,Counter]
Run inside Blender headless:  blender -b -P build_all.py -- [--render] [--scenes]
Run inside the Blender GUI:   Scripting tab, open this file, Run Script (add --no-reset
                               to keep your current scene; objects appear at the origin).

Outputs (relative to the repo root, override with --out and --docs):
  assets/cat-cafe/exports/<Name>.fbx and .glb, CatCafe_Palette.png, manifest.json, gates.md
  docs/concepts/cat-cafe/previews/<Name>.png, views/<Name>.png (five-view sheet), contact sheets, vignettes

Every asset runs through gates.check (budget, transforms, material, UVs, naming as FAIL; pivot
and centering as WARN). The build exits 1 on any FAIL; read exports/gates.md for the reasons.
"""

import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402

import alley  # noqa: E402
import cats  # noqa: E402
import common  # noqa: E402
import decor  # noqa: E402
import furniture  # noqa: E402
import gates  # noqa: E402
import items  # noqa: E402
import npc  # noqa: E402
import palette  # noqa: E402
import park  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODULES = [cats, npc, furniture, decor, alley, park, items]

PIVOT_NOTES = {
    "CatCafe_Furniture_WallShelf": "wall: back-bottom center",
    "CatCafe_Decor_WindowPlants": "wall: back-bottom center",
    "CatCafe_Decor_NeonSign": "wall: back-bottom center",
    "CatCafe_Decor_MenuBoard": "wall: back-bottom center",
    "CatCafe_Decor_HangingLamp": "ceiling hook (geometry hangs below the pivot)",
}
STUDIO_NOTES = {
    "CatCafe_Decor_NeonSign": "Tube: Material Neon, add PointLight (neon_pink). Board stays SmoothPlastic.",
    "CatCafe_Decor_FishTank": "Glass: Transparency 0.5. Water: Transparency 0.3, Material Glass.",
    "CatCafe_Decor_HangingLamp": "Bulb: Material Neon + PointLight 255,214,170 range 14.",
    "CatCafe_Alley_StreetLamp": "Bulb: Material Neon + SpotLight pointing down, warm.",
    "CatCafe_Park_Fountain": "Water: Transparency 0.3. Optional ParticleEmitter at the top ball.",
    "CatCafe_Park_Gate": "LeafL and LeafR pivot at their hinge pillars; rotate about Y to open.",
    "CatCafe_Cat_Void": "Head eyes are amber in the texture; add a Neon eye Part or Highlight for the glow.",
    "CatCafe_Furniture_Counter": "CollisionFidelity Hull. Sit pad on the left end is the counter spot.",
    "CatCafe_Furniture_CatTree": "CollisionFidelity Hull.",
    "CatCafe_Alley_Dumpster": "CollisionFidelity Hull.",
}


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else (argv[1:] if not bpy.app.binary_path or argv[0].endswith(".py") else [])
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=os.path.join(ROOT, "assets", "cat-cafe", "exports"))
    p.add_argument("--docs", default=os.path.join(ROOT, "docs", "concepts", "cat-cafe"))
    p.add_argument("--render", action="store_true", help="render a preview PNG and a five-view sheet per asset")
    p.add_argument("--no-views", action="store_true", help="with --render: skip the five-view sheets")
    p.add_argument("--scenes", action="store_true", help="render the cafe and alley vignettes")
    p.add_argument("--no-export", action="store_true")
    p.add_argument("--no-reset", action="store_true", help="keep the current scene (GUI use)")
    p.add_argument("--only", default="", help="comma list of name fragments to build")
    p.add_argument("--samples", type=int, default=32)
    return p.parse_args(argv)


def all_assets():
    out = {}
    for m in MODULES:
        for name, (fn, budget) in m.ASSETS.items():
            out[name] = (fn, budget, m.__name__)
    return out


def main():
    args = parse_args()
    t0 = time.time()
    if not args.no_reset:
        common.reset_scene()
    os.makedirs(args.out, exist_ok=True)
    png = os.path.join(args.out, palette.TEXTURE_NAME + ".png")
    palette.write_palette_png(png)
    mat = common.palette_material(png)

    wanted = [s.strip() for s in args.only.split(",") if s.strip()]
    manifest, failed, built = [], [], {}
    for name, (fn, budget, module) in all_assets().items():
        if wanted and not any(w.lower() in name.lower() for w in wanted):
            continue
        objs = fn(mat)
        built[name] = objs
        tris = common.tri_count(objs)
        lo, hi = common.bounds(objs)
        size = [round(v, 2) for v in (hi - lo)]
        entry = {
            "name": name, "category": name.split("_")[1], "module": module,
            "objects": [o.name for o in objs], "triangles": tris, "budget": budget,
            "size_studs": {"x": size[0], "y": size[1], "z": size[2]},
            "bounds_min": [round(v, 2) for v in lo], "bounds_max": [round(v, 2) for v in hi],
            "pivot": PIVOT_NOTES.get(name, "base center (floor contact)"),
            "front": "-Z in Roblox (Blender -Y)",
        }
        if name in furniture.SIT_POINTS:
            entry["sit_point"] = list(furniture.SIT_POINTS[name])
        if name.startswith("CatCafe_Cat_"):
            spec = cats.ROSTER[name.split("_")[-1]]
            entry["rarity"] = spec["rarity"]
            entry["joints"] = {"Head": list(cats.NECK), "Tail": list(cats.TAIL_ROOT)}
        if name in STUDIO_NOTES:
            entry["studio"] = STUDIO_NOTES[name]
        if not args.no_export:
            entry["files"] = [os.path.relpath(p, ROOT) for p in common.export_asset(objs, name, args.out)]
        entry["gates"] = gates.check(objs, name, budget, tris, lo, hi, PIVOT_NOTES.get(name), mat)
        if args.render:
            path = os.path.join(args.docs, "previews", name + ".png")
            visible = [o for o in objs if not o.name.endswith("_Glass")] or objs   # glass is opaque in Cycles here
            common.render_preview(visible, path, samples=args.samples,
                                 warm=not name.startswith("CatCafe_Alley_"), floor=lo.z > -0.1)
            entry["preview"] = os.path.relpath(path, ROOT)
            if not args.no_views:
                vpath = os.path.join(args.docs, "views", name + ".png")
                common.render_views(visible, vpath)
                entry["views"] = os.path.relpath(vpath, ROOT)
        g = entry["gates"]
        flag = "ok" if g["pass"] else "FAIL " + ",".join(g["failed"])
        if g["warnings"]:
            flag += "  warn " + ",".join(g["warnings"])
        if not g["pass"]:
            failed.append(name)
        print(f"{name:44s} tris {tris:5d} / {budget:5d} {flag}  size {size}")
        manifest.append(entry)

    mpath = os.path.join(args.out, "manifest.json")
    if wanted and os.path.exists(mpath):          # partial build: merge into the existing manifest
        with open(mpath) as f:
            old = {e["name"]: e for e in json.load(f).get("assets", [])}
        old.update({e["name"]: e for e in manifest})
        order = list(all_assets().keys())
        manifest = sorted(old.values(), key=lambda e: order.index(e["name"]) if e["name"] in order else 999)
    with open(mpath, "w") as f:
        json.dump({"generated": time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime()), "units": "studs",
                   "palette": os.path.relpath(png, ROOT), "assets": manifest}, f, indent=2)
    gates.write_report(os.path.join(args.out, "gates.md"), manifest, ROOT)

    if args.render:
        import contact_sheet
        contact_sheet.build_sheets(args.docs, manifest)
    if args.scenes:
        import scenes
        scenes.render_all(built, mat, args.docs, samples=max(args.samples, 48))

    print(f"built {len(manifest)} assets in {time.time() - t0:.0f}s; gates report: {os.path.join(args.out, 'gates.md')}")
    if failed:
        print("GATES FAILED:", ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
