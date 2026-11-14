"""Gold as a recolour (#3918, #3743): each base cat part that looks different on the cat's gold twin says how.

A gold cat (gold.py) is the base cat on the same shapes with its coat in three gold tones. Shipping it as a second
model costs every device a copy of every cat, so the base cat's parts carry the difference instead, and the game can
recolour a clone:

  GoldTone   1, 2 or 3: Color becomes TONES[n] (gold_light, gold_mid, gold_dark) and Material becomes Metal
  GoldColor  a Color3, for the few parts that change to some other colour (Material stays)
  GoldSolid  true: Transparency becomes 0 (a see-through coat is solid in gold); CastShadow as any solid part

`stamp(base_path, gold_path)` reads the two .model.json files, matches parts by CFrame, Size and Shape, and writes
the attributes into the base file. A base part with no twin (a marking the gold coat swallowed, mouth lines that
sit a hair differently) takes the look of the same-sized gold part next to it, or else of the gold part it sits on.
build_all.py calls it whenever either file of a pair is written.   python3 goldtone.py [rbx dir]  stamps and checks all.
"""
import glob
import json
import os
import sys

TONES = {(0.9843, 0.8941, 0.6039): 1, (0.949, 0.7569, 0.3059): 2, (0.7882, 0.5608, 0.1647): 3}   # light, mid, dark
KEYS = ("GoldTone", "GoldColor", "GoldSolid")


def _parts(tree):
    out = []

    def walk(x):
        p = x.get("properties")
        if p and "Size" in p and "CFrame" in p:
            out.append(x)
        for c in x.get("children", []):
            walk(c)
    walk(tree)
    return out


def _key(p):
    return (json.dumps(p["CFrame"], sort_keys=True), tuple(p["Size"]), p.get("Shape"))


def _pos(p):
    return p["CFrame"]["CFrame"]["position"]


def _dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(_pos(a), _pos(b))) ** 0.5


def _local(p, point):
    """`point` in the part's own axes (orientation rows are the rotation matrix's rows)."""
    d = [a - b for a, b in zip(point, _pos(p))]
    R = p["CFrame"]["CFrame"]["orientation"]
    return [sum(R[r][c] * d[r] for r in range(3)) for c in range(3)]


def _holds(g, p, slack):
    loc = _local(g, _pos(p))
    return all(abs(v) <= s / 2 + slack for v, s in zip(loc, g["Size"]))


def _look(base, twin):
    """The attributes that turn `base` into `twin` (their properties), or {} when they look the same."""
    a = {}
    if twin["Color"] != base["Color"] or twin.get("Material") != base.get("Material"):
        tone = TONES.get(tuple(twin["Color"])) if twin.get("Material") == "Metal" else None
        if tone:
            a["GoldTone"] = tone
        elif twin["Color"] != base["Color"]:
            a["GoldColor"] = {"Color3": list(twin["Color"])}
    if base.get("Transparency") and not twin.get("Transparency"):
        a["GoldSolid"] = True
    return a


def stamp_trees(base, gold):
    """Put the Gold attributes on `base`'s parts. Returns counts: same, recolour, near, under, lost."""
    bp, gp = [x for x in _parts(base)], [x["properties"] for x in _parts(gold)]
    twins = {}
    for g in gp:
        twins.setdefault(_key(g), []).append(g)
    base_keys = {_key(x["properties"]) for x in bp}
    spare = [g for g in gp if _key(g) not in base_keys]
    n = {"same": 0, "recolour": 0, "near": 0, "under": 0, "lost": 0}
    for x in bp:
        p = x["properties"]
        attrs = x.get("attributes") or {}
        for k in KEYS:
            attrs.pop(k, None)
        c = twins.get(_key(p))
        if c:
            twin, how = next((g for g in c if g["Color"] == p["Color"]), c[0]), None
        else:
            near = [g for g in spare if all(abs(a - b) < 2e-3 for a, b in zip(g["Size"], p["Size"])) and _dist(g, p) < 0.15]
            under = [g for g in gp if _holds(g, p, min(p["Size"]) / 2 + 0.02)]
            if near:
                twin, how = min(near, key=lambda g: _dist(g, p)), "near"
            elif under:
                twin, how = min(under, key=lambda g: g["Size"][0] * g["Size"][1] * g["Size"][2]), "under"
            else:
                twin, how = None, "lost"
        look = _look(p, twin) if twin else {}
        n[how or ("recolour" if look else "same")] += 1
        attrs.update(look)
        if attrs:
            x["attributes"] = attrs
        elif "attributes" in x:
            del x["attributes"]
    return n


def stamp(base_path, gold_path):
    with open(base_path) as f:
        base = json.load(f)
    with open(gold_path) as f:
        gold = json.load(f)
    n = stamp_trees(base, gold)
    with open(base_path, "w") as f:
        json.dump(base, f, indent=1)
        f.write("\n")
    return n


def twin_paths(path):
    """(base path, gold path) for either file of a cat pair, or None when the cat has no gold twin on disk."""
    d, f = os.path.split(path)
    stem = f[:-len(".model.json")]
    for sfx in ("_Sit", "_Work", ""):
        if stem.endswith(sfx):
            head = stem[:len(stem) - len(sfx)] if sfx else stem
            break
    base = head.removesuffix("_Gold")
    b, g = os.path.join(d, base + sfx + ".model.json"), os.path.join(d, base + "_Gold" + sfx + ".model.json")
    return (b, g) if os.path.exists(b) and os.path.exists(g) else None


if __name__ == "__main__":
    rbx = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rbx")
    total = {}
    for g in sorted(glob.glob(os.path.join(rbx, "CatCafe_Cat_*_Gold*.model.json"))):
        pair = twin_paths(g)
        if not pair:
            continue
        for k, v in stamp(*pair).items():
            total[k] = total.get(k, 0) + v
            if k == "lost" and v:
                print("lost", v, os.path.basename(pair[0]))
    print(total)
