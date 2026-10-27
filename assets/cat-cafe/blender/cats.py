"""Signature cats: two blocky chibi bodies and twenty coats, picked by Derek from the stray body drafts
(2026-10-27 14:24: "A for walking around B while they are sitting").

  CatCafe_Cat_<Name>       body A, on all fours: strays, carried and stuck cats, cats walking about. Loaf and sleep
                           are poses of A (body lowered, legs folded; poses.CAT_POSES), not extra models.
  CatCafe_Cat_<Name>_Sit   body B, sitting up: cats resting in the cafe, and working cats at their stations in
                           their role's outfit (accessories.SIT_SLOTS).

Roster and swatches follow docs/design/cat-cafe/data-model.md section 3. Each model is a Body (the Roblox
PrimaryPart; pivot at the base centre on the floor, facing -Y in Blender, -Z in Roblox) and hinged pieces, each its
own object pivoted at its joint so code can turn it without a rig: Head (neck), Tail (root), the legs (hip or
shoulder: LegF1 LegF2 LegB1 LegB2 on A, LegF1 LegF2 on B; F front, B back, 1 the cat's left, Blender +X, 2 its
right), and riding the Head, Eye1 and Eye2 (eye centre, for blinks) and EarL and EarR (ear base, for twitches). The
Roblox models nest the eyes and ears in the Head Model (rbx_export.NEST). No collars (Derek, 2026-10-27): a working
cat dresses for its role instead (accessories.ROLE_OUTFITS).
"""

import math

import palette
from common import Builder, scale_mesh

# Each cat's colors are data, so they survive a model swap (Derek, 2026-10-27: "unique / different color schemes";
# the manifest repeats them as hex under `coat`). Keys: fur (main coat), second and third (markings), eyes (and eyes2
# for an odd-eyed cat, right eye), muzzle, nose, ruff. No two cats share a main coat color.
# pattern: solid | stripes | patches | points | spots | gradient; extra flags: sparkle (star specks),
# petals, flower, ruff, ear_tufts, persian (long coat, flat face), tail_thick, sphynx (thin, big ears),
# body_scale (x, y, z of the body or the haunches), scale (the whole cat)
ROSTER = {
    "Tabby":   dict(rarity="Common", fur="fur_orange", second="fur_orange_dark", eyes="eye_amber", pattern="stripes", muzzle="fur_white"),
    "Tuxedo":  dict(rarity="Common", fur="fur_black", second="fur_white", eyes="eye_green", pattern="patches", muzzle="fur_white", tuxedo=True),
    "Ginger":  dict(rarity="Common", fur="fur_ginger", second="fur_ginger", eyes="eye_green", pattern="solid", muzzle="fur_cream",
                    nose="nose_brick", body_scale=(1.1, 1.05, 1.05)),
    "Smoke":   dict(rarity="Common", fur="fur_charcoal", second="fur_charcoal", eyes="eye_chartreuse", pattern="solid",
                    muzzle="fur_smoke_light", nose="nose_dark"),
    "Snow":    dict(rarity="Common", fur="fur_white", second="fur_white", eyes="eye_blue", eyes2="eye_amber", pattern="solid", muzzle=None),
    "Calico":  dict(rarity="Rare", fur="fur_white", second="fur_orange", third="fur_black", eyes="eye_green", pattern="patches", muzzle=None),
    # Derek 14:24 found the old Siamese "kinda looks off": the dark mask round the eyes is now a small dark muzzle
    # under them, with a pink nose, cream legs and dark paws (every points cat draws it this way)
    "Siamese": dict(rarity="Rare", fur="fur_cream", second="fur_seal", eyes="eye_blue", pattern="points", muzzle=None),
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


def look(spec):
    """The coat plus where each colour goes on these bodies: legs, paws, ears, tail tip and the chest patch."""
    c = coat(spec)
    c.setdefault("second", c["fur"])
    c.setdefault("third", c["second"])
    pat, tux = spec["pattern"], spec.get("tuxedo")
    c["leg"] = c["fur"]
    c["paw"] = c["second"] if pat == "points" or tux else c["fur"]           # dark socks on points, white on a tuxedo
    c["ear"] = c["second"] if pat == "points" else c["third"] if pat == "gradient" else c["fur"]
    c["tip"] = c["second"] if pat in ("points", "stripes") or tux else c["third"] if pat == "gradient" else c["fur"]
    belly = c.get("muzzle") or (c["second"] if tux else None)
    c["belly"] = belly if belly != c["fur"] else None
    return c


# -------------------------------------------------------------------------------------------- skeleton --
BODIES = ("walk", "sit")
SUFFIX = {"walk": "", "sit": "_Sit"}
SIT_SCALE = 0.95            # B is drawn a touch smaller, so a sitting cat is no taller than a walking one
HEAD_PIECES = ("Eye1", "Eye2", "EarL", "EarR")
LEGS = {"walk": ("LegF1", "LegF2", "LegB1", "LegB2"), "sit": ("LegF1", "LegF2")}

# Body A on all fours, unscaled studs. The belly is 0.33 off the floor and the legs reach up inside it to the hips.
A_BODY_C, A_BODY_S = (0.0, 0.12, 0.62), (0.78, 0.95, 0.58)
A_BELLY_Z, A_HIP_Z = 0.33, 0.42
A_LEG_XY = {"LegF1": (0.22, -0.2), "LegF2": (-0.22, -0.2), "LegB1": (0.22, 0.42), "LegB2": (-0.22, 0.42)}
A_NECK, A_TAIL = (0.0, -0.3, 0.85), (0.0, 0.58, 0.8)
# Body B sitting up: haunches on the floor and an upright chest, the same on every cat so one outfit fits all.
B_HAUNCH_C, B_HAUNCH_S = (0.0, 0.18, 0.28), (0.9, 0.75, 0.56)
B_CHEST_C, B_CHEST_S = (0.0, -0.06, 0.74), (0.7, 0.55, 0.72)
B_SHOULDER_Z = 0.62
B_LEG_XY = {"LegF1": (0.17, -0.3), "LegF2": (-0.17, -0.3)}
B_NECK, B_TAIL = (0.0, -0.1, 1.02), (0.2, 0.54)   # the tail root (x, y); it lies on the floor
# Heads, relative to the neck: centre, size, eye height, face scale, eye spacing, ear spacing, ear width and height
HEADS = {"walk": dict(c=(0.0, -0.22, 0.32), s=(1.0, 0.8, 0.84), fz=0.26, k=1.15, eye_dx=0.22, ear_x=0.3, ear=(0.32, 0.3)),
         "sit": dict(c=(0.0, -0.14, 0.28), s=(0.92, 0.74, 0.76), fz=0.24, k=1.05, eye_dx=0.21, ear_x=0.28, ear=(0.3, 0.3))}
EYE_H = 0.26


def scale_of(spec, body="walk"):
    """How much the built model is scaled: the cat's own scale, times SIT_SCALE for B."""
    return spec.get("scale", 1.0) * (SIT_SCALE if body == "sit" else 1.0)


def _body_scale(spec):
    return (0.82, 0.95, 0.85) if spec.get("sphynx") else spec.get("body_scale", (1.0, 1.0, 1.0))


def _head_dims(spec, body):
    h = dict(HEADS[body])
    (cx, cy, cz), (sx, sy, sz) = h["c"], h["s"]
    if spec.get("sphynx"):
        sx, sy, sz = sx * 0.92, sy * 0.95, sz * 0.94
    if spec.get("persian"):                             # wide and flat-faced: the face sits further back
        cy += sy * 0.08
        sx, sy, sz = sx * 1.08, sy * 0.84, sz * 0.95
    h["c"], h["s"] = (cx, cy, cz), (sx, sy, sz)
    ew, eh = h["ear"]
    if spec.get("sphynx"):
        ew, eh = ew * 1.25, eh * 1.45
    if spec.get("persian"):
        ew, eh = ew * 0.72, eh * 0.7
    h["ear"] = (ew, eh)
    h["fy"] = cy - sy / 2                               # the face plane
    h["top"] = cz + sz / 2
    return h


def dims(spec, body="walk"):
    """Every box and joint of one cat's body, unscaled (scale_of applies after)."""
    bs = _body_scale(spec)
    d = {"head": _head_dims(spec, body), "leg_w": 0.2 if spec.get("sphynx") else 0.24 if body == "walk" else 0.2}
    tt = spec.get("tail_thick", 0.2) / 0.2
    tail_k = 0.7 if spec.get("sphynx") else 1 + (tt - 1) * 0.6
    if body == "walk":
        size = (A_BODY_S[0] * bs[0], A_BODY_S[1] * bs[1], A_BODY_S[2] * bs[2])
        d["body"] = ((A_BODY_C[0], A_BODY_C[1], A_BELLY_Z + size[2] / 2), size)
        dy, dz = (size[1] - A_BODY_S[1]) / 2, size[2] - A_BODY_S[2]
        d["neck"] = (A_NECK[0], A_NECK[1] - dy, A_NECK[2] + dz)
        d["tail"] = (A_TAIL[0], A_TAIL[1] + dy, A_TAIL[2] + dz)
        d["legs"] = {n: (x * bs[0], A_BODY_C[1] + (y - A_BODY_C[1]) * bs[1], A_HIP_Z) for n, (x, y) in A_LEG_XY.items()}
        d["tail_chain"] = dict(angles=(35, 80), seg=0.3, thick=0.24 * tail_k, plane="X", taper=0.02)
    else:
        size = (B_HAUNCH_S[0] * bs[0], B_HAUNCH_S[1] * bs[1], B_HAUNCH_S[2] * bs[2])
        d["haunch"] = ((B_HAUNCH_C[0], B_HAUNCH_C[1], size[2] / 2), size)
        d["chest"] = (B_CHEST_C, B_CHEST_S)
        d["back_paws"] = [(sx * (size[0] / 2 - 0.08), -0.1) for sx in (1, -1)]
        d["neck"] = B_NECK
        d["tail"] = (B_TAIL[0] * bs[0], B_HAUNCH_C[1] + size[1] / 2 - 0.015, 0.09 * tail_k + 0.02)   # lying just off the floor
        d["legs"] = {n: (x, y, B_SHOULDER_Z) for n, (x, y) in B_LEG_XY.items()}
        d["tail_chain"] = dict(angles=(-30, -90, -150), seg=0.38, thick=0.18 * tail_k, plane="Z", taper=0.0)
    h = d["head"]
    n = d["neck"]
    for piece, sx in (("Eye1", 1), ("Eye2", -1)):
        d[piece] = (sx * h["eye_dx"] * h["k"], h["fy"] - 0.01, h["fz"])
    for piece, sx in (("EarL", 1), ("EarR", -1)):
        d[piece] = (sx * h["ear_x"], h["c"][1] + 0.06, h["top"] - 0.03)
    d["pivots"] = {"Body": (0.0, 0.0, 0.0), "Head": n, "Tail": d["tail"], **d["legs"],
                   **{p: tuple(n[i] + d[p][i] for i in range(3)) for p in HEAD_PIECES}}
    return d


def joints(spec, body="walk"):
    """Each piece's pivot in the built model's space (scale included): where the Roblox Model of that piece pivots."""
    k = scale_of(spec, body)
    return {p: tuple(v * k for v in at) for p, at in dims(spec, body)["pivots"].items()}


# -------------------------------------------------------------------------------------------- builders --
def _rot(deg, axis):
    return (math.radians(deg), axis)


def _head(spec, c, h):
    """The Head (built relative to the neck): fur, markings, muzzle, nose, blush and coat extras."""
    b = Builder()
    (cx, cy, cz), (sx, sy, sz) = h["c"], h["s"]
    fy, top, fz, k = h["fy"], h["top"], h["fz"], h["k"]
    w = sx / 0.92                                       # marking spread, 1 on B's head
    b.box(h["c"], h["s"], c["fur"])
    pat = spec["pattern"]
    if pat == "stripes":                                # three stripes over the crown
        for x in (-0.2, 0.0, 0.2):
            b.box((x * w, cy + 0.05, top + 0.01), (0.08, sy * 0.68, 0.06), c["second"], bevel=False)
    elif pat == "patches" and not spec.get("tuxedo"):
        b.box((-0.22 * w, cy + 0.05, top + 0.01), (0.34 * w, sy * 0.55, 0.06), c["second"], bevel=False)
        b.box((0.3 * w, fy + 0.01, fz + 0.12), (0.2, 0.06, 0.26), c["third"], bevel=False)
    elif pat == "points":                               # a small dark muzzle under the eyes, not a mask round them
        b.box((0, fy + 0.005, fz - 0.24), (0.3 * w, 0.05, 0.24), c["second"], bevel=False)
    elif pat == "gradient":                             # the back of the head fades into the second colour
        b.box((0, cy + sy * 0.3, cz), (sx + 0.03, sy * 0.42, sz + 0.03), c["second"], bevel=False)
    surf, under = fy, c["fur"]                          # the face the mouth is drawn on, and its colour
    if pat == "points":
        surf, under = fy - 0.02, c["second"]
    if c.get("muzzle") and c["muzzle"] != c["fur"]:
        b.box((0, fy + 0.01, fz - 0.15 * k), (0.36 * k, 0.08, 0.2 * k), c["muzzle"], bevel=False)
        surf, under = fy - 0.03, c["muzzle"]
    b.box((0, fy - 0.025, fz - 0.11 * k), (0.1 * k, 0.06, 0.07 * k), c["nose"], bevel=False)
    _mouth(b, surf, fz - 0.145 * k, k, "fur_grey" if palette.lstar(under) < 35 else "fur_black")
    for side in (-1, 1):
        bx = side * (h["eye_dx"] + 0.15) * k
        b.box((bx, fy, fz - 0.14 * k), (0.12 * k, 0.05, 0.05 * k), "blush", bevel=False)
    if spec.get("persian"):                             # cheek fluff either side of the flat face
        for side in (-1, 1):
            b.box((side * (sx / 2 + 0.02), fy + 0.14, fz - 0.2), (0.14, 0.26, 0.3), c["second"])
    if spec.get("moon"):                                # crescent on the forehead
        b.box((0.02, fy - 0.015, fz + 0.24), (0.16, 0.04, 0.06), "sparkle", bevel=False)
        b.box((-0.05, fy - 0.012, fz + 0.19), (0.06, 0.04, 0.08), "sparkle", bevel=False)     # a hair behind the top bar
    if spec.get("sparkle") and spec["rarity"] == "Mythical":   # star specks on the face too
        for (x, z) in ((0.36 * w, fz + 0.2), (-0.37 * w, fz - 0.17)):
            b.box((x, fy - 0.015, z), (0.06, 0.04, 0.06), "sparkle", bevel=False)      # proud of the blush
    if spec.get("flower"):                              # a blossom tucked by the left ear
        fx, fzz = h["ear_x"] + 0.16, top + 0.02
        b.box((fx, cy - 0.12, fzz), (0.08, 0.08, 0.08), "sparkle", bevel=False)
        for dx, dz in ((0.085, 0), (-0.085, 0), (0, 0.085), (0, -0.075)):   # petals overlap the centre; the low one sinks into the head
            b.box((fx + dx, cy - 0.12, fzz + dz), (0.1, 0.06 if dz == 0 else 0.05, 0.1), c["second"], bevel=False)
    return b


def _mouth(b, surf, nz, k, ink):
    """The W mouth (Derek 2026-10-27 15:48, option 2): a short line down from the nose, then two little u curves,
    standing 0.02 proud of `surf` (the muzzle or face front) under the nose bottom `nz`. Dark on light fur, light grey
    on dark fur."""
    y, t = surf - 0.005, 0.028
    b.box((0, y, nz - 0.03 * k + 0.005), (t, 0.03, 0.06 * k + 0.01), ink, bevel=False)      # top end inside the nose
    for sx in (-1, 1):                                  # inner strokes 0.003 proud, so no two strokes share a plane
        b.box((sx * 0.025 * k, y - 0.003, nz - 0.07 * k), (0.05 * k, 0.03, t), ink, bevel=False, rot=_rot(sx * 30, "Y"))
        b.box((sx * 0.085 * k, y, nz - 0.07 * k), (0.05 * k, 0.03, t), ink, bevel=False, rot=_rot(-sx * 30, "Y"))


def _eye(spec, c, h, side):
    """One eye about its centre: iris, pupil (none on glowing eyes) and a glossy highlight."""
    b = Builder()
    k = h["k"]
    eye = c["eyes"] if side > 0 else c["eyes2"]         # an odd-eyed cat's right eye (Eye2, screen left) is eyes2
    b.box((0, 0, 0), (0.2 * k, 0.07, EYE_H * k), eye, bevel=False)
    if not spec.get("glow_eyes"):
        b.box((side * 0.01, -0.025, -0.02 * k), (0.12 * k, 0.04, EYE_H * 0.72 * k), "fur_black", bevel=False)
    b.box((-0.045 * k, -0.045, EYE_H * 0.28 * k), (0.06 * k, 0.03, 0.07 * k), "milk", bevel=False)
    return b


def _ear(spec, c, h, side):
    """One ear about the middle of its base, splayed outward, with a pink inside (and a lynx tuft on the Maine Coon)."""
    b = Builder()
    ew, eh = h["ear"]
    tilt = _rot(side * 12, "Y")
    b.pyramid((0, 0, 0), ew, eh, c["ear"], rot=tilt)
    lean = math.sin(math.radians(12)) * side
    b.box((lean * eh * 0.3, -ew * 0.36, eh * 0.3), (ew * 0.36, 0.03, eh * 0.38), "nose_pink", bevel=False, rot=tilt)
    if spec.get("ear_tufts"):
        b.pyramid((lean * eh, 0, eh * math.cos(math.radians(12)) - 0.04), 0.08, 0.16, c["second"], rot=tilt)
    return b


def _tail(c, t):
    """Boxes chained from the tail root. Plane X: each angle tips the segment up from +Y toward +Z. Plane Z: lying
    on the floor, each angle is a heading in XY from +X."""
    b = Builder()
    pos = [0.0, 0.0, 0.0]
    n = len(t["angles"])
    for i, deg in enumerate(t["angles"]):
        a = math.radians(deg)
        if t["plane"] == "X":
            d, rot = (0.0, math.cos(a), math.sin(a)), (a, "X")
        else:
            d, rot = (math.cos(a), math.sin(a), 0.0), (a - math.pi / 2, "Z")
        seg, th = t["seg"], t["thick"] - i * t["taper"]
        b.box(tuple(pos[j] + d[j] * seg / 2 for j in range(3)), (th, seg + 0.06, th), c["tip"] if i == n - 1 else c["fur"],
              rot=rot)
        pos = [pos[j] + d[j] * seg for j in range(3)]
    return b


def _leg(c, hip_z, w, paw, paw_y=-0.01):
    """A leg hanging from its hip pivot to the floor, with a paw."""
    b = Builder()
    b.box_base((0, 0, 0.05 - hip_z), (w, w, hip_z - 0.05), c["leg"])          # the leg ends inside the paw
    b.box_base((0, paw_y, -hip_z), paw, c["paw"])
    return b


def _coat_extras(b, spec, c, centre, size, sides=True, front=True, top=True):
    """Ruff, long-coat fringe, petals and star specks on one body box (A's body, or B's haunches and chest)."""
    (x0, y0, z0), (sx, sy, sz) = centre, size
    hx, hy, tz = sx / 2, sy / 2, z0 + sz / 2
    if spec.get("ruff") and front:                      # chest ruff under the chin
        b.box((0, y0 - hy - 0.04, z0 + sz * 0.1), (sx * 1.08, 0.12, sz * 0.7), spec["ruff"])
    if spec.get("persian"):                             # long coat: fringe along the flanks and down the chest
        if sides:
            for side in (-1, 1):
                b.box((side * (hx + 0.03), y0, z0 - sz * 0.22), (0.08, sy * 0.9, sz * 0.55), c["second"])
        if front:
            b.box((0, y0 - hy - 0.04, z0 - sz * 0.05), (sx * 0.8, 0.1, sz * 0.75), c["second"])
    if spec.get("petals"):
        spots = []
        if sides:
            spots += [((-hx - 0.01, y0 + 0.12, z0 + 0.08), (0.03, 0.14, 0.1)), ((hx + 0.01, y0 - 0.12, z0 - 0.05), (0.03, 0.14, 0.1))]
        if top:
            spots += [((0.14, y0 + 0.16, tz + 0.01), (0.14, 0.1, 0.03)), ((-0.12, y0 - 0.12, tz + 0.01), (0.14, 0.1, 0.03))]
        for at, sz_ in spots:
            b.box(at, sz_, c["third"], bevel=False)
    if spec.get("sparkle"):
        specks = []
        if sides:
            specks += [(-hx - 0.03, y0 + 0.1, z0 + 0.08), (hx + 0.03, y0 - 0.08, z0 - 0.08), (hx + 0.03, y0 + 0.26, z0 + 0.12)]
        if top:
            specks += [(0.16, y0 + 0.22, tz + 0.03), (-0.18, y0 - 0.16, tz + 0.03)]
        if spec["rarity"] == "Mythical":                # a denser star field on the heroes
            if sides:
                specks += [(-hx - 0.03, y0 - 0.2, z0 + 0.13), (hx + 0.03, y0 + 0.1, z0 + 0.17)]
            if top:
                specks += [(0.0, y0, tz + 0.03)]
        for at in specks:
            b.box(at, (0.08, 0.08, 0.08), "sparkle", bevel=False)


def _body_a(spec, c, d):
    b = Builder()
    (x0, y0, z0), (sx, sy, sz) = d["body"]
    hx, hy, top, bottom = sx / 2, sy / 2, z0 + sz / 2, z0 - sz / 2
    b.box(d["body"][0], d["body"][1], c["fur"])
    pat = spec["pattern"]
    if spec.get("tuxedo"):
        b.box((0, y0 - hy - 0.01, z0), (0.46, 0.08, sz * 0.75), c["second"], bevel=False)            # bib
        b.box((0, y0, bottom - 0.01), (0.5, sy * 0.7, 0.04), c["second"], bevel=False)               # belly
    elif pat == "stripes":
        for f in (-0.28, 0.05, 0.36):
            b.box((0, y0 + f * sy, z0 + 0.04), (sx + 0.04, 0.13, sz - 0.02), c["second"], bevel=False)
    elif pat == "patches":
        b.box((-hx - 0.01, y0 + 0.12, z0 + 0.05), (0.04, 0.45, 0.32), c["second"], bevel=False)      # right flank
        b.box((hx + 0.01, y0 - 0.15, z0 - 0.02), (0.04, 0.34, 0.26), c["third"], bevel=False)        # left flank
        b.box((0.12, y0 + 0.2, top + 0.01), (0.36, 0.42, 0.04), c["third"], bevel=False)             # saddle
        b.box((-0.16, y0 - 0.18, top + 0.01), (0.28, 0.32, 0.04), c["second"], bevel=False)
    elif pat == "spots":
        for (x, y) in ((0.15, 0.2), (-0.18, -0.15), (0.2, -0.3), (-0.1, 0.35)):
            b.box((x, y0 + y, top + 0.01), (0.16, 0.16, 0.04), c["second"], bevel=False)
        for (side, y, z) in ((-1, 0.2, 0.06), (-1, -0.2, -0.06), (1, 0.0, 0.04), (1, 0.32, -0.08)):
            b.box((side * (hx + 0.01), y0 + y, z0 + z), (0.04, 0.16, 0.16), c["second"], bevel=False)
    elif pat == "gradient":                             # front to back: fur, second, third
        b.box((0, y0 + 0.04, z0), (sx + 0.03, sy * 0.3, sz + 0.03), c["second"], bevel=False)
        b.box((0, y0 + hy * 0.66, z0), (sx + 0.04, sy * 0.36, sz + 0.04), c["third"], bevel=False)
    if c["belly"] and not spec.get("tuxedo") and not spec.get("ruff"):    # a pale chest under the chin (the ruff covers it)
        b.box((0, y0 - hy - 0.01, z0 - 0.04), (0.36, 0.06, sz * 0.6), c["belly"], bevel=False)
    _coat_extras(b, spec, c, d["body"][0], d["body"][1])
    return b


def _body_b(spec, c, d):
    b = Builder()
    (hx0, hy0, hz0), (hsx, hsy, hsz) = d["haunch"]
    (cx0, cy0, cz0), (csx, csy, csz) = d["chest"]
    b.box(d["haunch"][0], d["haunch"][1], c["fur"])
    b.box(d["chest"][0], d["chest"][1], c["fur"])
    for (x, y) in d["back_paws"]:
        b.box_base((x, y, 0.01), (0.24, 0.4, 0.11), c["paw"])                  # 0.01 up: no shared floor plane
    front, htop = cy0 - csy / 2, hsz
    pat = spec["pattern"]
    if spec.get("tuxedo"):
        b.box((0, front - 0.01, cz0), (0.42, 0.06, 0.6), c["second"], bevel=False)                   # bib
    elif c["belly"] and not spec.get("ruff"):
        b.box((0, front - 0.01, cz0 + 0.02), (0.34, 0.06, 0.5), c["belly"], bevel=False)
    if pat == "stripes":
        for z in (0.5, 0.75, 1.0):
            b.box((0, cy0 + 0.05, z), (csx + 0.04, csy - 0.06, 0.1), c["second"], bevel=False)
        for y in (0.05, 0.35):
            b.box((0, y, hz0), (hsx + 0.04, 0.12, hsz - 0.08), c["second"], bevel=False)
    elif pat == "patches" and not spec.get("tuxedo"):
        b.box((-hsx / 2 - 0.01, hy0 + 0.02, hz0 + 0.04), (0.04, 0.4, 0.3), c["second"], bevel=False)   # right haunch
        b.box((csx / 2 + 0.01, cy0 + 0.05, 0.85), (0.04, 0.3, 0.3), c["third"], bevel=False)          # left of the chest
        b.box((0.1, hy0 + 0.12, htop + 0.01), (0.4, 0.3, 0.04), c["third"], bevel=False)              # on the haunches
    elif pat == "spots":
        for (side, y, z) in ((-1, 0.25, 0.3), (-1, 0.0, 0.18), (1, 0.08, 0.36), (1, 0.34, 0.2)):
            b.box((side * (hsx / 2 + 0.01), y, z), (0.04, 0.16, 0.16), c["second"], bevel=False)
        for (x, y) in ((0.16, 0.36), (-0.2, 0.3)):
            b.box((x, y, htop + 0.01), (0.16, 0.16, 0.04), c["second"], bevel=False)
        for side in (-1, 1):
            b.box((side * (csx / 2 + 0.01), cy0, 0.86), (0.04, 0.16, 0.16), c["second"], bevel=False)
    elif pat == "gradient":                             # chest in the fur, haunches in second, the rump in third
        b.box_base((0, hy0 - 0.02, 0.005), (hsx + 0.03, hsy * 0.62, hsz + 0.01), c["second"], bevel=False)   # off the floor
        b.box_base((0, hy0 + hsy * 0.36, 0.008), (hsx + 0.04, hsy * 0.3, hsz + 0.012), c["third"], bevel=False)
    _coat_extras(b, spec, c, d["haunch"][0], d["haunch"][1], front=False)
    _coat_extras(b, {**spec, "petals": False}, c, d["chest"][0], d["chest"][1], top=False)
    return b


def build_cat(name, mat, spec=None, base=None, body="walk"):
    """One cat model. `spec` and `base` override the roster entry and the asset name (gold.py builds the gold cats
    here); `body` is "walk" (A) or "sit" (B)."""
    spec = spec or ROSTER[name]
    base = base or f"CatCafe_Cat_{name}{SUFFIX[body]}"
    c = look(spec)
    d = dims(spec, body)
    h = d["head"]
    k = scale_of(spec, body)
    w = d["leg_w"]
    paw = (w + 0.03, w + 0.03, 0.11) if body == "walk" else (w + 0.04, w + 0.08, 0.11)
    paw_y = -0.01 if body == "walk" else -0.05
    pieces = [("Body", _body_a(spec, c, d) if body == "walk" else _body_b(spec, c, d)),
              ("Head", _head(spec, c, h)),
              ("Eye1", _eye(spec, c, h, 1)), ("Eye2", _eye(spec, c, h, -1)),
              ("EarL", _ear(spec, c, h, 1)), ("EarR", _ear(spec, c, h, -1)),
              ("Tail", _tail(c, d["tail_chain"]))]
    pieces += [(n, _leg(c, d["legs"][n][2], w, paw, paw_y)) for n in LEGS[body]]
    objs = []
    for piece, b in pieces:
        at = d["pivots"][piece]
        ob = b.finalize(f"{base}_{piece}", mat, location=tuple(v * k for v in at))
        if k != 1.0:
            scale_mesh(ob, k)
        objs.append(ob)
    return objs


def parse(asset):
    """CatCafe_Cat_<Name>[_Gold][_Sit] -> (name, gold, body)."""
    rest = asset[len("CatCafe_Cat_"):]
    body = "sit" if rest.endswith("_Sit") else "walk"
    rest = rest.removesuffix("_Sit")
    gold = rest.endswith("_Gold")
    return rest.removesuffix("_Gold"), gold, body


ASSETS = {}
for _n in ROSTER:
    for _body in BODIES:
        ASSETS[f"CatCafe_Cat_{_n}{SUFFIX[_body]}"] = (lambda mat, n=_n, bd=_body: build_cat(n, mat, body=bd), 1500)
