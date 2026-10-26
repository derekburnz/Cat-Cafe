"""Signature cats: one parametric blocky cat, twelve variants by swatch swap.

Roster and swatches follow docs/design/cat-cafe/data-model.md section 3.
Each cat exports as three objects (Body with legs, Head, Tail) so Studio can
tween head and tail without a rig. Facing -Y in Blender (Roblox front),
pivot at base center between the feet.
"""

import math

from mathutils import Matrix

from common import Builder

# pattern: solid | stripes | patches | points | spots | sparkle(extra flag)
ROSTER = {
    "Tabby":   dict(rarity="Common", fur="fur_orange", second="fur_orange_dark", eyes="eye_amber", pattern="stripes", muzzle="fur_white"),
    "Tuxedo":  dict(rarity="Common", fur="fur_black", second="fur_white", eyes="eye_green", pattern="patches", muzzle="fur_white", tuxedo=True),
    "Ginger":  dict(rarity="Common", fur="fur_orange", second="fur_orange", eyes="eye_green", pattern="solid", muzzle="fur_cream", body_scale=(1.1, 1.05, 1.05)),
    "Smoke":   dict(rarity="Common", fur="fur_grey", second="fur_white", eyes="eye_green", pattern="solid", muzzle=None),
    "Snow":    dict(rarity="Common", fur="fur_white", second="fur_white", eyes="eye_blue", pattern="solid", muzzle=None),
    "Calico":  dict(rarity="Rare", fur="fur_white", second="fur_orange", third="fur_black", eyes="eye_green", pattern="patches", muzzle=None),
    "Siamese": dict(rarity="Rare", fur="fur_cream", second="fur_brown", eyes="eye_blue", pattern="points", muzzle=None),
    "Tortie":  dict(rarity="Rare", fur="fur_brown", second="fur_orange", third="fur_black", eyes="eye_amber", pattern="patches", muzzle=None),
    "Bengal":  dict(rarity="Rare", fur="fur_orange", second="fur_brown", eyes="eye_green", pattern="spots", muzzle="fur_cream", body_scale=(0.95, 1.05, 0.95)),
    "Sphynx":  dict(rarity="Epic", fur="blush", second="blush", eyes="eye_blue", pattern="solid", muzzle=None, sphynx=True),
    "Ragdoll": dict(rarity="Epic", fur="fur_white", second="fur_grey", eyes="eye_blue", pattern="points", muzzle="fur_white", scale=1.2, body_scale=(1.1, 1.0, 1.05)),
    "Void":    dict(rarity="Legendary", fur="fur_black", second="sparkle", eyes="eye_amber", pattern="solid", muzzle=None, glow_eyes=True, sparkle=True),
}

COLLAR = {"Common": "rarity_common", "Rare": "rarity_rare", "Epic": "rarity_epic", "Legendary": "rarity_legend"}

# Skeleton in studs. Head and Tail objects hang off these joints.
BODY_C = (0.0, 0.05, 0.78)
BODY_S = (0.9, 1.4, 0.7)
NECK = (0.0, -0.6, 1.0)        # Head pivot
TAIL_ROOT = (0.0, 0.75, 0.95)  # Tail pivot
LEG_XY = [(-0.28, -0.45), (0.28, -0.45), (-0.28, 0.5), (0.28, 0.5)]


def _body(b, spec):
    fur, second, pattern = spec["fur"], spec["second"], spec["pattern"]
    bs = spec.get("body_scale", (1, 1, 1))
    if spec.get("sphynx"):
        bs = (0.82, 0.95, 0.85)
    size = (BODY_S[0] * bs[0], BODY_S[1] * bs[1], BODY_S[2] * bs[2])
    center = (BODY_C[0], BODY_C[1], 0.43 + size[2] / 2)
    top = center[2] + size[2] / 2
    hx, hy = size[0] / 2, size[1] / 2
    b.box(center, size, fur)
    leg_col = second if pattern == "points" else fur
    leg_w = 0.24 if spec.get("sphynx") else 0.28
    for x, y in LEG_XY:
        b.box_base((x * bs[0], y, 0), (leg_w, leg_w, 0.5), leg_col)
    if spec.get("tuxedo"):
        b.box((0, center[1] - hy - 0.01, center[2]), (0.5, 0.08, size[2] * 0.7), second)        # bib
        b.box((0, center[1], 0.42), (0.6, 1.0, 0.06), second, bevel=False)                      # belly
        for x, y in LEG_XY[:2]:
            b.box_base((x, y, 0), (0.32, 0.32, 0.18), second)                                   # socks
    elif pattern == "stripes":
        for y in (-0.35, 0.0, 0.35):
            b.box((0, y + 0.05, center[2]), (size[0] + 0.04, 0.16, size[2] + 0.04), second, bevel=False)
    elif pattern == "patches" and not spec.get("tuxedo"):
        third = spec.get("third", second)
        b.box((-hx - 0.01, 0.15, center[2] + 0.05), (0.04, 0.55, 0.4), second, bevel=False)    # left flank
        b.box((hx + 0.01, -0.2, center[2] - 0.05), (0.04, 0.4, 0.3), third, bevel=False)       # right flank
        b.box((0.15, 0.3, top + 0.01), (0.4, 0.5, 0.04), third, bevel=False)                    # saddle
        b.box((-0.2, -0.3, top + 0.01), (0.3, 0.4, 0.04), second, bevel=False)
    elif pattern == "spots":
        for (x, y, z) in [(-hx - 0.01, 0.25, 0.9), (-hx - 0.01, -0.25, 0.75), (hx + 0.01, 0.0, 0.85), (hx + 0.01, 0.4, 0.7),
                          (0.15, 0.3, top + 0.01), (-0.2, -0.2, top + 0.01), (0.2, -0.45, top + 0.01)]:
            sz = (0.04, 0.18, 0.18) if abs(x) > 0.3 else (0.18, 0.18, 0.04)
            b.box((x, y, z), sz, second, bevel=False)
    if spec.get("sparkle"):
        for (x, y, z) in [(-hx - 0.03, 0.2, 0.9), (hx + 0.03, -0.1, 0.7), (0.2, 0.4, top + 0.03), (-0.25, -0.3, top + 0.03), (hx + 0.03, 0.45, 0.95)]:
            b.box((x, y, z), (0.08, 0.08, 0.08), "sparkle", bevel=False)
    # collar in the rarity color, tag below it
    # collar: a vertical ring just in front of the body, under the chin, in the rarity color
    r = 0.5
    cy = center[1] - hy - 0.05
    b.ring((0, cy, 0.95), r, 0.12, 0.16, COLLAR[spec["rarity"]], segments=12, rot=(math.pi / 2, "X"))
    b.box((0, cy, 0.95 - r - 0.06), (0.16, 0.12, 0.16), "rarity_legend" if spec["rarity"] == "Legendary" else "metal", bevel=False)


def _head(b, spec):
    """Built relative to NECK so the Head pivots there."""
    fur, second, pattern = spec["fur"], spec["second"], spec["pattern"]
    hc = (0.0, -0.18, 0.18)
    hs = (0.8, 0.7, 0.64)
    if spec.get("sphynx"):
        hs = (0.72, 0.66, 0.6)
    b.box(hc, hs, fur)
    front_y = hc[1] - hs[1] / 2
    top_z = hc[2] + hs[2] / 2
    ear_col = second if pattern == "points" else fur
    ear_w, ear_h = (0.36, 0.44) if spec.get("sphynx") else (0.28, 0.3)
    for x in (-0.25, 0.25):
        b.pyramid((x, hc[1] + 0.05, top_z - 0.02), ear_w, ear_h, ear_col)
        b.box((x, hc[1] - 0.05 - ear_w * 0.2, top_z + ear_h * 0.3), (ear_w * 0.35, 0.03, ear_h * 0.35), "nose_pink", bevel=False)
    if pattern == "points":
        b.box((0, front_y - 0.02, 0.12), (0.5, 0.06, 0.42), second, bevel=False)           # mask
    if pattern == "patches" and not spec.get("tuxedo"):
        b.box((-0.22, hc[1], top_z + 0.01), (0.34, 0.5, 0.04), second, bevel=False)
        b.box((0.3, front_y - 0.015, 0.25), (0.2, 0.05, 0.28), spec.get("third", second), bevel=False)
    if pattern == "stripes":
        for x in (-0.22, 0.0, 0.22):
            b.box((x, hc[1] + 0.05, top_z + 0.01), (0.08, 0.5, 0.04), second, bevel=False)
    if spec.get("muzzle"):
        b.box((0, front_y - 0.02, 0.0), (0.38, 0.08, 0.22), spec["muzzle"], bevel=False)
    for x in (-0.2, 0.2):
        b.box((x, front_y - 0.04, 0.2), (0.24, 0.06, 0.26), spec["eyes"], bevel=False)
        if not spec.get("glow_eyes"):
            b.box((x, front_y - 0.06, 0.18), (0.12, 0.04, 0.18), "fur_black", bevel=False)
        b.box((x - 0.05, front_y - 0.08, 0.24), (0.05, 0.03, 0.06), "milk", bevel=False)   # glossy highlight
    b.box((0, front_y - 0.05, 0.02), (0.14, 0.06, 0.1), "nose_pink", bevel=False)


def _tail(b, spec):
    """Three segments curling up, relative to TAIL_ROOT."""
    fur, pattern = spec["fur"], spec["pattern"]
    tip = spec["second"] if pattern in ("points", "stripes") or spec.get("tuxedo") else fur
    thick = 0.14 if spec.get("sphynx") else 0.2
    seg = 0.38
    pos = [0.0, 0.0, 0.0]
    for i, deg in enumerate((15, 55, 95)):
        a = math.radians(deg)
        d = (0.0, math.cos(a), math.sin(a))
        c = (pos[0], pos[1] + d[1] * seg / 2, pos[2] + d[2] * seg / 2)
        b.box(c, (thick - i * 0.02, seg + 0.06, thick - i * 0.02), tip if i == 2 else fur, rot=(a, "X"))
        pos = [pos[0], pos[1] + d[1] * seg, pos[2] + d[2] * seg]


def build_cat(name, mat):
    spec = ROSTER[name]
    base = f"CatCafe_Cat_{name}"
    s = spec.get("scale", 1.0)
    body = Builder()
    _body(body, spec)
    head = Builder()
    _head(head, spec)
    tail = Builder()
    _tail(tail, spec)
    objs = [
        body.finalize(base + "_Body", mat),
        head.finalize(base + "_Head", mat, location=tuple(v * s for v in NECK)),
        tail.finalize(base + "_Tail", mat, location=tuple(v * s for v in TAIL_ROOT)),
    ]
    if s != 1.0:
        for ob in objs:
            ob.data.transform(Matrix.Scale(s, 4))
    return objs


ASSETS = {f"CatCafe_Cat_{n}": (lambda mat, n=n: build_cat(n, mat), 1500) for n in ROSTER}
