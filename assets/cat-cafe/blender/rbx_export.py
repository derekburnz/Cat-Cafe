"""Part-built Roblox models: assets/cat-cafe/rbx/<Name>.model.json from the Builder's primitive log.

Rojo syncs assets/cat-cafe/rbx/ into ReplicatedStorage.Assets, and AssetRegistry clones a model found there
before it builds a placeholder, so these files replace the placeholders by name with no Studio import and no
code change. Every Builder primitive becomes one or a few Parts:

  box -> Part, wedge -> WedgePart (Roblox wedges are tall at +Z and slope down to -Z, like ours at +Y),
  cylinder -> Cylinder Part (axis turned onto Roblox X; a cone or lamp shade becomes stacked bands),
  sphere -> Ball, or a Part with a SpecialMesh Sphere when squashed, pyramid -> stacked blocks,
  ring -> blocks around the circle, flat star or badge outline -> two WedgeParts per triangle.

Bevels are dropped, which suits the blocky style. Colours are the palette swatches. Glass and water are Glass at
0.45 and 0.3 transparency, a gate barrier (_Bars) is ForceField, the gold coat tones (palette.METAL_SWATCHES) are
Metal. Hanging lamp bulbs (lit all day) are Neon; other
_Bulb, _Bulbs, _Pane and _Tube parts keep their day look and WorldController lights them at night. _Glow parts are
Neon day and night (WorldController leaves them alone), and a walk-in circle (_CodesCircle) is Neon at 0.85.

Model layout (pivots match the FBX exports and manifest.json, so placement code works with either):
  <Name>                     Model, pivot at the asset origin (base centre, front -Z), PrimaryPart = biggest
                             part of the main object (a cat's Body)
    <object name> parts      the main object: the object named like the asset, else the first one
    <object name>            a Model per other object (Head, Tail, Lid, Branch, LeafL, Bulb...), pivot at that
                             object's origin, which is its hinge or joint (manifest part_pivots_roblox)
      <object name>          a Model nested in another (NEST): a cat's Eye1, Eye2, EarL and EarR ride its Head,
                             and so does a themed cat's Head or Face prop (_Prop, _Prop_Glass)
Every part keeps its object's name, so name checks such as the night suffixes keep working. An asset can add
Attachments to the biggest part of one object (a cat's Outfit_<Piece> slots) and attributes on the root Model.

The FBX files stay the detailed source: a MeshPart import saved as <Name>.rbxm replaces the JSON (delete the
.model.json of that name).
"""

import json
import os

import bpy
from mathutils import Matrix, Vector

import common
import palette

C = common.TO_ROBLOX              # Blender (x, y, z) -> Roblox (-x, z, y), a proper rotation
CT = C.transposed()
RZ90 = Matrix(((0, -1, 0), (1, 0, 0), (0, 0, 1)))   # Roblox local X (cylinder axis) onto local Y

# Asset families whose big parts block players. Everything else (cats, people, items, wall decor) is walk-through.
COLLIDE_PREFIXES = ("CatCafe_Furniture_", "CatCafe_Alley_", "CatCafe_Park_", "CatCafe_Plot_", "CatCafe_Street_",
                    "CatCafe_Neighbourhood_", "CatCafe_Woods_", "CatCafe_Sewer_")
NO_COLLIDE_OBJECTS = ("_Bulb", "_Bulbs", "_Tube", "_Water", "_Decor", "_Lights", "_Fireflies", "_Glow", "_CodesCircle")
INVISIBLE_OBJECTS = ("_Fireflies",)   # volumes the effects code reads (where fireflies drift), never drawn
TOUCH_OBJECTS = ("_CodesCircle",)    # parts the game code may watch with Touched; every other part has CanTouch off
MIN_COLLIDE = 0.35                # thinner parts (trim, handles, bulbs) never collide
ALWAYS_LIT = ("HangingLamp",)     # matches WorldController: indoor lamps glow all day
ROUND = 4

# Names the game looks up. The round table's biggest part is its Top (CustomerController turns a seated customer
# toward it).
# An object ending in _SignBoard or _Screen keeps its child Model but its part is named SignBoard or Screen (found
# with a recursive FindFirstChild); a one-part object ending in _Bars goes straight into the root as a ForceField
# part named Bars, because the gate code looks for a direct child.
RENAME_BIGGEST = {"CatCafe_Furniture_TableRound": "Top"}
PART_NAMES = {"_SignBoard": "SignBoard", "_Bars": "Bars", "_Screen": "Screen", "_CodesCircle": "CodesCircle"}
# CollectionService tags, keyed by object name, or by name suffix when the key starts with "_": the audio code plays
# world loops from FishTank and Fountain (assets/cat-cafe/audio, PR #69), from the Model's PrimaryPart, and the UI
# hangs each player's Index page on an IndexBoard. The Codes Cat's prompt finds its kiosk by CodesCat, and the night
# code shows and hides every NightFence piece (gate fences, alley pieces, shut back doors). CafeDoor and WorkingCat
# are tagged by WorldBuilder at placement.
TAGS = {"CatCafe_Decor_FishTank": ["FishTank"], "CatCafe_Plot_Tier4_Water": ["FishTank"],
        "CatCafe_Park_Fountain": ["Fountain"], "_IndexBoard": ["IndexBoard"],
        "CatCafe_Street_CodesCat": ["CodesCat"], "_NightFence": ["NightFence"],
        "CatCafe_Alley_NightFenceSegment": ["NightFence"], "CatCafe_Plot_BackDoorClosed": ["NightFence"]}
# Tags on every part of an object, by object name suffix: the crate styles (F53, StyleController) recolour the cafe
# shell's outer wall layer (Paint) and inner wall layer (Wallpaper), and give each part its own look back after.
PART_TAGS = {"_Paint": ["Paint"], "_Wallpaper": ["Wallpaper"]}
# Root Model properties by asset name suffix: an Index Board streams in whole, so its Screen is there whenever the
# board is (reviewer S37, as for the cats).
MODEL_PROPS = {"_IndexBoard": {"ModelStreamingMode": "Atomic"}}
# Objects whose Model goes inside another object's Model rather than the root: name suffix -> the suffix of the
# object it rides, with the same prefix. Turning the Head Model (PivotTo) carries the eyes and ears with it.
NEST = {"_Eye1": "_Head", "_Eye2": "_Head", "_EarL": "_Head", "_EarR": "_Head"}


def _r(v):
    x = round(float(v), ROUND)
    return 0.0 if x == 0 else x


def _color(swatch):
    return [_r(c) for c in palette.hex_to_rgb(palette.SWATCHES[palette.idx(swatch)][1])]


def _split(m3):
    """3x3 -> (rotation with det +1, axis lengths). A mirrored frame flips its X axis; every unit shape is
    symmetric in X, so the part is the same."""
    cols = [Vector((m3[0][i], m3[1][i], m3[2][i])) for i in range(3)]
    scl = [c.length for c in cols]
    unit = [c / s if s > 1e-9 else Vector((1, 0, 0)) for c, s in zip(cols, scl)]
    if unit[0].cross(unit[1]).dot(unit[2]) < 0:
        unit[0] = -unit[0]
    R = Matrix((unit[0], unit[1], unit[2])).transposed()
    return R, scl


def _cf(pos, rot):
    """Roblox CFrame JSON from a Roblox position Vector and 3x3 rotation."""
    return {"CFrame": {"position": [_r(v) for v in pos], "orientation": [[_r(rot[i][j]) for j in range(3)] for i in range(3)]}}


def _to_rbx(M4):
    """Blender 4x4 (unit shape -> asset space) -> Roblox (position, rotation, size along Blender local x, y, z)."""
    R, scl = _split(M4.to_3x3())
    return C @ M4.translation, C @ R @ CT, scl


def _part(cls, name, pos, rot, size, swatch, shape=None, mesh=None):
    return {"cls": cls, "name": name, "pos": pos, "rot": rot, "size": size, "swatch": swatch, "shape": shape,
            "mesh": mesh}


def _cyl_parts(name, M4, swatch, fr):
    """A cylinder band (or several for a cone): Roblox cylinders run along local X."""
    f0, f1 = fr
    taper = abs(f0 - f1)
    n = 1 if taper < 0.12 else (2 if taper < 0.35 else 3)
    out = []
    for i in range(n):
        t = (i + 0.5) / n
        f = f0 + (f1 - f0) * t
        if f < 0.04:
            continue
        band = M4 @ Matrix.Translation((0, 0, -0.5 + t)) @ Matrix.Diagonal((f, f, 1.0 / n, 1.0))
        pos, rot, (sx, sy, sz) = _to_rbx(band)
        d = (sx + sy) / 2
        out.append(_part("Part", name, pos, rot @ RZ90, (sz, d, d), swatch, shape="Cylinder"))
    return out


def _tri_parts(name, M4, swatch, extra):
    """Flat triangle of a given thickness as two right-angle WedgeParts (the usual Roblox triangle trick)."""
    (pa, pb, pc), thick = extra
    a, b, c = (C @ (M4 @ Vector((p[0], p[1], 0.0))) for p in (pa, pb, pc))
    ab, ac, bc = b - a, c - a, c - b
    if ab.dot(ab) > ac.dot(ac) and ab.dot(ab) > bc.dot(bc):
        a, c = c, a
    elif ac.dot(ac) > bc.dot(bc) and ac.dot(ac) > ab.dot(ab):
        a, b = b, a
    ab, ac, bc = b - a, c - a, c - b
    n = ac.cross(ab)
    if n.length < 1e-6 or bc.length < 1e-6:
        return []
    right = n.normalized()
    up = bc.cross(right).normalized()
    back = bc.normalized()
    height = abs(ab.dot(up))
    _, _, scl = _to_rbx(M4)
    t = thick * scl[2]
    out = []
    for center, rt, bk, depth in (((a + b) / 2, right, back, abs(ab.dot(back))),
                                  ((a + c) / 2, -right, -back, abs(ac.dot(back)))):
        if depth > 1e-4 and height > 1e-4:
            rot = Matrix((rt, up, bk)).transposed()
            out.append(_part("WedgePart", name, center, rot, (t, height, depth), swatch))
    return out


def prim_parts(name, kind, M4, swatch, extra):
    if kind == "cyl":
        return _cyl_parts(name, M4, swatch, extra)
    if kind == "tri":
        return _tri_parts(name, M4, swatch, extra)
    if kind == "pyramid":
        out = []
        for i in range(3):
            t = (i + 0.5) / 3
            band = M4 @ Matrix.Translation((0, 0, -0.5 + t)) @ Matrix.Diagonal((1 - t, 1 - t, 1 / 3, 1.0))
            pos, rot, (sx, sy, sz) = _to_rbx(band)
            out.append(_part("Part", name, pos, rot, (sx, sz, sy), swatch))
        return out
    pos, rot, (sx, sy, sz) = _to_rbx(M4)
    size = (sx, sz, sy)            # Blender local x, z, y -> Roblox local X, Y, Z
    if kind == "box":
        return [_part("Part", name, pos, rot, size, swatch)]
    if kind == "wedge":
        return [_part("WedgePart", name, pos, rot, size, swatch)]
    if kind == "sphere":
        if max(size) - min(size) < 0.02 * max(size):
            return [_part("Part", name, pos, rot, size, swatch, shape="Ball")]
        return [_part("Part", name, pos, rot, size, swatch, mesh="Sphere")]
    raise ValueError(f"unknown primitive {kind}")


def _material(obname, swatch):
    """(Material, Transparency) for a part."""
    if swatch == "glass" or obname.endswith("_Glass"):
        return "Glass", 0.45
    if swatch == "puddle" or obname.endswith("_Water"):
        return "Glass", 0.3
    if obname.endswith("_Bars"):
        return "ForceField", 0.0
    if obname.endswith(INVISIBLE_OBJECTS):
        return "SmoothPlastic", 1.0
    if any(k in obname for k in ALWAYS_LIT) and obname.endswith("_Bulb"):
        return "Neon", 0.0
    if obname.endswith("_Glow"):
        return "Neon", 0.0
    if obname.endswith("_CodesCircle"):           # a see-through glowing pad you walk into, calm enough that the
        return "Neon", 0.85                       # ticket on it reads
    if swatch in palette.METAL_SWATCHES:          # gold cats
        return "Metal", 0.0
    return "SmoothPlastic", 0.0


def _props(p, asset, uid):
    material, transparency = _material(p["name"], p["swatch"])
    collide = ((asset.startswith(COLLIDE_PREFIXES) and min(p["size"]) >= MIN_COLLIDE
                and not p["name"].endswith(NO_COLLIDE_OBJECTS) and material != "Glass")
               or (asset.startswith("CatCafe_Plot_") and p["name"].endswith(("_Wall", "_Glass")))
               or p["name"].endswith("_Bars"))
    props = {
        "CFrame": _cf(p["pos"], p["rot"]),
        "Size": [_r(max(v, 0.01)) for v in p["size"]],
        "Color": _color(p["swatch"]),
        "Material": material,
        "Anchored": True,
        "CanCollide": bool(collide),
        "CanTouch": p["name"].endswith(TOUCH_OBJECTS),
        "CastShadow": material not in ("Glass", "ForceField") and transparency < 1,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    if transparency:
        props["Transparency"] = transparency
    part_tags = [t for sfx, tags in PART_TAGS.items() if p["name"].endswith(sfx) for t in tags]
    if part_tags:
        props["Tags"] = part_tags
    if p["shape"]:
        props["Shape"] = p["shape"]
    node = {"name": p["name"], "className": p["cls"], "properties": props}
    if uid:
        node["attributes"] = {"Rojo_Id": uid}
    if p["mesh"]:
        node["children"] = [{"name": "Mesh", "className": "SpecialMesh", "properties": {"MeshType": p["mesh"]}}]
    return node


def _volume(p):
    return p["size"][0] * p["size"][1] * p["size"][2]


def _tags(obname):
    return [t for key, tags in TAGS.items() for t in tags
            if obname == key or (key.startswith("_") and obname.endswith(key))]


def _group(asset, label, parts, pivot_pos, pivot_rot, uid, part_name=None):
    """Model JSON: parts, PrimaryPart = biggest, PivotOffset so the model pivot is (pivot_pos, pivot_rot)."""
    big = max(range(len(parts)), key=lambda i: _volume(parts[i]))
    children = []
    for i, p in enumerate(parts):
        node = _props(p, asset, uid if i == big else None)
        if part_name:
            node["name"] = part_name
        if i == big:
            inv = p["rot"].transposed()
            node["properties"]["PivotOffset"] = _cf(inv @ (pivot_pos - p["pos"]), inv @ pivot_rot)
            children.insert(0, node)
        else:
            children.append(node)
    model = {"className": "Model", "attributes": {"Rojo_Target_PrimaryPart": uid}, "children": children,
             "properties": {"WorldPivotData": {"OptionalCFrame": _cf(pivot_pos, pivot_rot)["CFrame"]}}}
    if label is not None:
        model["name"] = label
    tags = _tags(label or asset)
    if tags:
        model["properties"]["Tags"] = tags
    return model


def _attachment(name, parts, M4):
    """An Attachment in the biggest of `parts` at the Blender asset-space frame M4 (position and rotation)."""
    big = max(parts, key=_volume)
    R, _ = _split(M4.to_3x3())
    inv = big["rot"].transposed()
    return {"name": name, "className": "Attachment",
            "properties": {"CFrame": _cf(inv @ (C @ M4.translation - big["pos"]), inv @ (C @ R @ CT))}}


def _add_attachments(node, parts, wanted):
    """Put the Attachments in `wanted` into the PrimaryPart node of a group made by _group (always children[0])."""
    if wanted:
        target = node["children"][0]
        target.setdefault("children", []).extend(_attachment(n, parts, M4) for n, M4 in wanted)


def model_json(objs, asset, attachments=(), attributes=None, nest=None, part_attributes=None):
    """The .model.json tree for one asset, or None when no object has a primitive log. `attachments` is a list of
    (object name suffix, Attachment name, Blender asset-space 4x4); `attributes` go on the root Model. `nest` adds
    to NEST for this asset (a themed cat's Head or Face prop rides the Head), and `part_attributes` puts attributes
    on every part of the objects whose names end with a key (a prop's parts say what they follow)."""
    nests = {**NEST, **(nest or {})}
    bpy.context.view_layer.update()
    main = next((o for o in objs if o.name == asset), objs[0])
    groups = []
    for o in [main] + [o for o in objs if o is not main]:
        prims = common.PRIMS.get(o.data.name) if o.type == "MESH" else None
        if not prims:
            continue
        parts = []
        for kind, m, swatch, extra in prims:
            parts.extend(prim_parts(o.name, kind, o.matrix_world @ m, swatch, extra))
        if parts:
            groups.append((o, parts))
    if not groups or groups[0][0] is not main:
        return None
    _, main_parts = groups[0]
    if asset in RENAME_BIGGEST:
        max(main_parts, key=_volume)["name"] = RENAME_BIGGEST[asset]
    root = _group(asset, None, main_parts, Vector((0, 0, 0)), Matrix.Identity(3), f"{asset}/0")
    root["attributes"]["PartBuilt"] = True
    root["attributes"].update(attributes or {})
    for suffix, props_ in MODEL_PROPS.items():
        if asset.endswith(suffix):
            root["properties"].update(props_)

    def wanted(o):
        return [(n, M4) for suffix, n, M4 in attachments if o.name.endswith(suffix)]

    _add_attachments(root, main_parts, wanted(groups[0][0]))
    subs, nested = {}, []
    for k, (o, parts) in enumerate(groups[1:], start=1):
        part_name = next((n for suffix, n in PART_NAMES.items() if o.name.endswith(suffix)), None)
        if part_name == "Bars" and len(parts) == 1:
            node = _props(parts[0], asset, None)
            node["name"] = part_name
            root["children"].append(node)
            continue
        R, _ = _split(o.matrix_world.to_3x3())
        sub = _group(asset, o.name, parts, C @ o.matrix_world.translation, C @ R @ CT, f"{asset}/{k}", part_name)
        for suffix, attrs in (part_attributes or {}).items():
            if o.name.endswith(suffix):
                for node in sub["children"]:
                    node.setdefault("attributes", {}).update(attrs)
        _add_attachments(sub, parts, wanted(o))
        subs[o.name] = sub
        host = next((o.name[:-len(sfx)] + to for sfx, to in nests.items() if o.name.endswith(sfx)), None)
        nested.append((sub, host))
    for sub, host in nested:
        (subs[host]["children"] if host in subs else root["children"]).append(sub)
    return root


def count_parts(tree):
    n = 1 if tree.get("className") in ("Part", "WedgePart") else 0
    return n + sum(count_parts(c) for c in tree.get("children", []))


def write_model(objs, asset, out_dir, attachments=(), attributes=None, nest=None, part_attributes=None):
    """Write <out_dir>/<asset>.model.json. Returns (path, part count) or (None, 0)."""
    tree = model_json(objs, asset, attachments, attributes, nest, part_attributes)
    if tree is None:
        return None, 0
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, asset + ".model.json")
    with open(path, "w") as f:
        json.dump(tree, f, indent=1)
        f.write("\n")
    return path, count_parts(tree)
