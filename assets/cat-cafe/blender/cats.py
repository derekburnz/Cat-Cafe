"""Signature cats: one parametric blocky cat, twenty variants by swatch swap and a few shape flags.

Roster and swatches follow docs/design/cat-cafe/data-model.md section 3.
Each cat exports as three objects (Body with legs, Head, Tail) so Studio can
tween head and tail without a rig. Facing -Y in Blender (Roblox front),
pivot at base center between the feet. No collars (Derek, 2026-10-27): a working cat
dresses for its role instead (accessories.ROLE_OUTFITS).
"""

import math

from common import Builder, scale_mesh

# Each cat's colors are data, so they survive a model swap (Derek, 2026-10-27: "unique / different color schemes";
# the manifest repeats them as hex under `coat`). Keys: fur (main coat), second and third (markings), eyes (and eyes2
# for an odd-eyed cat, right eye), muzzle, nose, ruff. No two cats share a main coat color.
# pattern: solid | stripes | patches | points | spots | gradient; extra flags: sparkle (star specks),
# petals, flower, ruff, ear_tufts, persian (long coat, flat face), tail_thick
ROSTER = {
    "Tabby":   dict(rarity="Common", fur="fur_orange", second="fur_orange_dark", eyes="eye_amber", pattern="stripes", muzzle="fur_white"),
    "Tuxedo":  dict(rarity="Common", fur="fur_black", second="fur_white", eyes="eye_green", pattern="patches", muzzle="fur_white", tuxedo=True),
    "Ginger":  dict(rarity="Common", fur="fur_ginger", second="fur_ginger", eyes="eye_green", pattern="solid", muzzle="fur_cream",
                    nose="nose_brick", body_scale=(1.1, 1.05, 1.05)),
    "Smoke":   dict(rarity="Common", fur="fur_charcoal", second="fur_charcoal", eyes="eye_chartreuse", pattern="solid",
                    muzzle="fur_smoke_light", nose="nose_dark"),
    "Snow":    dict(rarity="Common", fur="fur_white", second="fur_white", eyes="eye_blue", eyes2="eye_amber", pattern="solid", muzzle=None),
    "Calico":  dict(rarity="Rare", fur="fur_white", second="fur_orange", third="fur_black", eyes="eye_green", pattern="patches", muzzle=None),
    "Siamese": dict(rarity="Rare", fur="fur_cream", second="fur_seal", eyes="eye_blue", pattern="points", muzzle=None, nose="nose_dark"),
    "Tortie":  dict(rarity="Rare", fur="fur_black", second="fur_ginger", third="fur_apricot", eyes="eye_copper", pattern="patches",
                    muzzle=None, nose="nose_brick"),
    "Bengal":  dict(rarity="Rare", fur="fur_sand", second="fur_seal", eyes="eye_green", pattern="spots", muzzle="fur_cream",
                    nose="nose_brick", body_scale=(0.95, 1.05, 0.95)),
    "Sphynx":  dict(rarity="Epic", fur="fur_peach", second="fur_peach", eyes="eye_violet", pattern="solid", muzzle=None, sphynx=True),
    "Ragdoll": dict(rarity="Epic", fur="fur_white", second="fur_blue", eyes="eye_blue", pattern="points", muzzle="fur_white", scale=1.2,
                    body_scale=(1.1, 1.0, 1.05)),
    "Void":    dict(rarity="Legendary", fur="fur_black", second="sparkle", eyes="eye_amber", pattern="solid", muzzle=None, glow_eyes=True,
                    sparkle=True, nose="nose_dark"),
    # v0.3 additions (data-model 3a and 3b)
    "MaineCoon": dict(rarity="Epic", fur="fur_silver", second="fur_black", eyes="eye_amber", pattern="stripes", muzzle="fur_white",
                      nose="nose_brick", scale=1.2, body_scale=(1.1, 1.05, 1.05), ruff="fur_white", ear_tufts=True, tail_thick=0.28),
    "Midnight":  dict(rarity="Mythical", fur="night_sky", second="sparkle", eyes="sparkle", pattern="solid", muzzle=None,
                      glow_eyes=True, sparkle=True, moon=True, nose="nose_dark"),
    "Cream":     dict(rarity="Common", fur="fur_latte", second="fur_latte", eyes="eye_chartreuse", pattern="solid", muzzle="fur_cream"),
    "Brownie":   dict(rarity="Common", fur="fur_brown", second="choco", eyes="eye_amber", pattern="stripes", muzzle="fur_cream",
                      nose="nose_brick"),
    "Blue":      dict(rarity="Common", fur="fur_blue", second="fur_blue", eyes="eye_green", pattern="solid", muzzle=None, nose="nose_dark"),
    "Persian":   dict(rarity="Epic", fur="fur_lavender", second="pastel_lilac", eyes="eye_copper", pattern="solid", muzzle=None,
                      body_scale=(1.15, 1.0, 1.1), persian=True, tail_thick=0.3),
    "Blossom":   dict(rarity="Legendary", fur="fur_rose", second="fur_white", third="nose_pink", eyes="eye_blue", pattern="patches",
                      muzzle=None, petals=True, flower=True),
    "Aurora":    dict(rarity="Mythical", fur="galaxy_blue", second="aurora_violet", third="mint", eyes="mint", pattern="gradient",
                      muzzle=None, glow_eyes=True, sparkle=True),
}

COAT_FIELDS = ("fur", "second", "third", "ruff", "muzzle", "eyes", "eyes2", "nose")


def coat(spec):
    """A cat's colors by field, defaults filled in (nose pink, both eyes alike): the model-independent part."""
    out = {k: spec[k] for k in COAT_FIELDS if spec.get(k)}
    out.setdefault("nose", "nose_pink")
    out.setdefault("eyes2", out["eyes"])
    return out


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
    for x, y in ([] if spec.get("tucked") else LEG_XY):         # tucked: lying down, legs under the body
        b.box_base((x * bs[0], y, 0), (leg_w, leg_w, 0.5), leg_col)
    if spec.get("tuxedo"):
        b.box((0, center[1] - hy - 0.01, center[2]), (0.5, 0.08, size[2] * 0.7), second)        # bib
        b.box((0, center[1], 0.42), (0.6, 1.0, 0.06), second, bevel=False)                      # belly
        for x, y in ([] if spec.get("tucked") else LEG_XY[:2]):
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
    elif pattern == "gradient":                                 # front to back: fur, second, third
        third = spec.get("third", second)
        for y, sw in ((0.0, second), (0.45, third)):
            b.box((0, y + 0.05, center[2]), (size[0] + 0.04, 0.5, size[2] + 0.04), sw, bevel=False)
    elif pattern == "spots":
        for (x, y, z) in [(-hx - 0.01, 0.25, 0.9), (-hx - 0.01, -0.25, 0.75), (hx + 0.01, 0.0, 0.85), (hx + 0.01, 0.4, 0.7),
                          (0.15, 0.3, top + 0.01), (-0.2, -0.2, top + 0.01), (0.2, -0.45, top + 0.01)]:
            sz = (0.04, 0.18, 0.18) if abs(x) > 0.3 else (0.18, 0.18, 0.04)
            b.box((x, y, z), sz, second, bevel=False)
    if spec.get("ruff"):                                        # chest ruff under the chin
        b.box((0, center[1] - hy - 0.04, center[2] - 0.06), (size[0] * 1.08, 0.14, size[2] * 0.85), spec["ruff"])
    if spec.get("persian"):                                     # long coat: fringe along the flanks and chest
        for sx in (-1, 1):
            b.box((sx * (hx + 0.03), center[1], center[2] - size[2] * 0.22), (0.08, size[1] * 0.9, size[2] * 0.55), second)
        b.box((0, center[1] - hy - 0.04, center[2] - 0.05), (size[0] * 0.85, 0.1, size[2] * 0.8), second)
    if spec.get("petals"):
        for (x, y, z) in [(-hx - 0.01, 0.3, 0.95), (hx + 0.01, -0.15, 0.8), (0.18, 0.35, top + 0.01), (-0.15, -0.25, top + 0.01)]:
            sz = (0.03, 0.14, 0.1) if abs(x) > 0.3 else (0.14, 0.1, 0.03)
            b.box((x, y, z), sz, spec.get("third", "nose_pink"), bevel=False)
    if spec.get("sparkle") and spec["rarity"] == "Mythical":   # denser star field on the heroes
        for (x, y, z) in [(-hx - 0.03, -0.35, 0.95), (hx + 0.03, 0.3, 0.98), (0.0, 0.05, top + 0.03), (hx + 0.03, -0.4, 0.75)]:
            b.box((x, y, z), (0.07, 0.07, 0.07), "sparkle", bevel=False)
    if spec.get("sparkle"):
        for (x, y, z) in [(-hx - 0.03, 0.2, 0.9), (hx + 0.03, -0.1, 0.7), (0.2, 0.4, top + 0.03), (-0.25, -0.3, top + 0.03), (hx + 0.03, 0.45, 0.95)]:
            b.box((x, y, z), (0.08, 0.08, 0.08), "sparkle", bevel=False)


def _head(b, spec):
    """Built relative to NECK so the Head pivots there."""
    fur, second, pattern = spec["fur"], spec["second"], spec["pattern"]
    hc = (0.0, -0.18, 0.18)
    hs = (0.8, 0.7, 0.64)
    if spec.get("sphynx"):
        hs = (0.72, 0.66, 0.6)
    if spec.get("persian"):                                     # wide, short and flat-faced
        hc, hs = (0.0, -0.12, 0.17), (0.9, 0.58, 0.62)
    b.box(hc, hs, fur)
    front_y = hc[1] - hs[1] / 2
    top_z = hc[2] + hs[2] / 2
    ear_col = second if pattern == "points" else fur
    if pattern == "gradient":
        ear_col = spec.get("third", ear_col)
    ear_w, ear_h = (0.36, 0.44) if spec.get("sphynx") else (0.22, 0.2) if spec.get("persian") else (0.28, 0.3)
    for x in (-0.25, 0.25):
        b.pyramid((x, hc[1] + 0.05, top_z - 0.02), ear_w, ear_h, ear_col)
        if spec.get("ear_tufts"):                               # lynx tips
            b.pyramid((x, hc[1] + 0.05, top_z - 0.02 + ear_h - 0.04), 0.08, 0.16, second)
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
    if spec.get("persian"):                                     # cheek fluff either side of the flat face
        for x in (-0.4, 0.4):
            b.box((x, front_y + 0.12, 0.02), (0.14, 0.26, 0.3), second)
    if spec.get("moon"):                                        # crescent on the forehead
        b.box((0.02, front_y - 0.02, 0.42), (0.16, 0.04, 0.06), "sparkle", bevel=False)
        b.box((-0.05, front_y - 0.02, 0.37), (0.06, 0.04, 0.08), "sparkle", bevel=False)
    if spec.get("sparkle") and spec["rarity"] == "Mythical":   # star specks on the head too
        for (x, z) in ((0.33, 0.36), (-0.34, 0.05)):
            b.box((x, front_y - 0.01, z), (0.06, 0.03, 0.06), "sparkle", bevel=False)
    if spec.get("flower"):                                      # a blossom tucked by the left ear
        fx, fz = 0.3, top_z + 0.02
        b.box((fx, hc[1] - 0.1, fz + 0.03), (0.08, 0.08, 0.08), "sparkle", bevel=False)
        for dx, dz in ((0.09, 0), (-0.09, 0), (0, 0.09), (0, -0.07)):
            b.box((fx + dx, hc[1] - 0.1, fz + 0.03 + dz), (0.1, 0.06, 0.1), spec.get("second", "blush"), bevel=False)
    for x in (-0.2, 0.2):
        eye = spec.get("eyes2", spec["eyes"]) if x < 0 else spec["eyes"]   # an odd-eyed cat's right eye (screen left)
        b.box((x, front_y - 0.04, 0.2), (0.24, 0.06, 0.26), eye, bevel=False)
        if not spec.get("glow_eyes"):
            b.box((x, front_y - 0.06, 0.18), (0.12, 0.04, 0.18), "fur_black", bevel=False)
        b.box((x - 0.05, front_y - 0.08, 0.24), (0.05, 0.03, 0.06), "milk", bevel=False)   # glossy highlight
    b.box((0, front_y - 0.05, 0.02), (0.14, 0.06, 0.1), spec.get("nose", "nose_pink"), bevel=False)


def _tail(b, spec):
    """Three segments curling up, relative to TAIL_ROOT."""
    fur, pattern = spec["fur"], spec["pattern"]
    tip = spec["second"] if pattern in ("points", "stripes") or spec.get("tuxedo") else fur
    if pattern == "gradient":
        tip = spec.get("third", tip)
    thick = 0.14 if spec.get("sphynx") else spec.get("tail_thick", 0.2)
    seg = 0.38
    pos = [0.0, 0.0, 0.0]
    for i, deg in enumerate((15, 55, 95)):
        a = math.radians(deg)
        d = (0.0, math.cos(a), math.sin(a))
        c = (pos[0], pos[1] + d[1] * seg / 2, pos[2] + d[2] * seg / 2)
        b.box(c, (thick - i * 0.02, seg + 0.06, thick - i * 0.02), tip if i == 2 else fur, rot=(a, "X"))
        pos = [pos[0], pos[1] + d[1] * seg, pos[2] + d[2] * seg]


def build_cat(name, mat, spec=None, base=None):
    """`spec` and `base` override the roster entry and the asset name (gold.py builds the gold cats here)."""
    spec = spec or ROSTER[name]
    base = base or f"CatCafe_Cat_{name}"
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
            scale_mesh(ob, s)
    return objs


ASSETS = {f"CatCafe_Cat_{n}": (lambda mat, n=n: build_cat(n, mat), 1500) for n in ROSTER}
