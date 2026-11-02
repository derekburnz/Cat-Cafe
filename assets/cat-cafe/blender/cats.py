"""Signature cats: two blocky chibi bodies and twenty coats, picked by Derek from the stray body drafts
(2026-10-27 14:24: "A for walking around B while they are sitting").

  CatCafe_Cat_<Name>       body A, on all fours: strays, carried and stuck cats, cats walking about. Loaf and sleep
                           are poses of A (body lowered, legs folded; poses.CAT_POSES), not extra models.
  CatCafe_Cat_<Name>_Sit   body B, sitting up: cats resting in the cafe, and working cats at their stations in
                           their role's outfit (accessories.SIT_SLOTS).
  CatCafe_Cat_<Name>_Work  body S, standing at work (Derek 2026-11-02 12:02, row S of the worker sheet): B's chest on
                           two short legs with A's bigger head, the front legs as arms, and the role's held thing
                           (a cup, a tray with a cake, a microphone) riding an arm as its own Model; it wears the
                           sitting role outfit, which fits the same chest.

Roster and swatches follow docs/design/cat-cafe/data-model.md section 3. Each model is a Body (the Roblox
PrimaryPart; pivot at the base centre on the floor, facing -Y in Blender, -Z in Roblox) and hinged pieces, each its
own object pivoted at its joint so code can turn it without a rig: Head (neck), Tail (root), the legs (hip or
shoulder: LegF1 LegF2 LegB1 LegB2 on A and S, LegF1 LegF2 on B; F front, B back, 1 the cat's left, Blender +X, 2
its right; on S the front legs are the arms), and riding the Head, Eye1 and Eye2 (eye centre, for blinks) and EarL and EarR (ear base, for twitches). The
Roblox models nest the eyes and ears in the Head Model (rbx_export.NEST). No collars (Derek, 2026-10-27): a working
cat dresses for its role instead (accessories.ROLE_OUTFITS).
"""

import math

from mathutils import Euler, Matrix, Vector

import palette
from common import Builder, scale_mesh

# Each cat's colors are data, so they survive a model swap (Derek, 2026-10-27: "unique / different color schemes";
# the manifest repeats them as hex under `coat`). Keys: fur (main coat), second and third (markings), eyes (and eyes2
# for an odd-eyed cat, right eye), muzzle, nose, ruff. No two cats share a main coat color.
# pattern: solid | stripes | patches | points | spots | gradient; extra flags: sparkle (star specks),
# petals, flower, ruff, ear_tufts, persian (long coat, flat face), tail_thick, sphynx (thin, big ears),
# body_scale (x, y, z of the body or the haunches), scale (the whole cat); v0.6: short_legs (A's body 0.12 lower),
# fold_ears (folded forward), toes (a paint dip per paw: LegF1, LegF2, LegB1 or B's right back paw, LegB2 or left),
# fluffy (long coat with a normal face), sprinkles (colours of the sprinkle specks), tip (tail tip colour), leafy
# (spots turned into leaves), mane (colours from the forehead down the back), socks (the colour of all four paws);
# v0.13: stripes2 (stripes alternate the second and third colours), checker (two colours: a checkered band along
# each flank, the Taxi Cat's); v0.18 (F96): blaze (a stripe of that colour up the face from the muzzle between the
# eyes), curl (the tail tip curls over: up and forward on A, up off the floor and back on B), exclusive (no gold
# twins). Themed cats wear a prop, some two (props.py).
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
    # v0.6 themed cats of the Neighbourhood, Woods and Sewer (data-model 3c, coats from areas-and-stations Part A)
    "Munchkin":    dict(rarity="Rare", fur="fur_grey", second="fur_white", third="fur_white", eyes="eye_copper", pattern="patches",
                        muzzle="fur_white", nose="nose_dark", short_legs=True),
    "Fold":        dict(rarity="Rare", fur="fur_oat", second="fur_oat", eyes="eye_green", pattern="solid", muzzle="fur_vanilla",
                        fold_ears=True, toes=("neon_pink", "sign_teal", "rarity_legend", "shirt_blue")),
    "Chonk":       dict(rarity="Epic", fur="fur_apricot", second="fur_white", eyes="eye_green", pattern="patches", muzzle="fur_white",
                        tuxedo=True, scale=1.25, body_scale=(1.25, 1.05, 1.15)),
    "Postie":      dict(rarity="Epic", fur="fur_slate", second="fur_slate", eyes="eye_copper", pattern="solid", muzzle="fur_blue",
                        nose="nose_dark"),
    "Marshmallow": dict(rarity="Legendary", fur="milk", second="fur_white", eyes="eye_blue", pattern="solid", muzzle=None,
                        ruff="fur_white", fluffy=True, tail_thick=0.3, body_scale=(1.1, 1.0, 1.08)),
    "Comet":       dict(rarity="Mythical", fur="fur_vanilla", second="fur_strawberry", eyes="pastel_sky", pattern="stripes",
                        muzzle=None, glow_eyes=True, sprinkles=("neon_pink", "sign_teal", "rarity_legend", "shirt_blue", "mint")),
    "Pinecone":    dict(rarity="Rare", fur="fur_hazel", second="fur_brown", eyes="eye_green", pattern="stripes", muzzle="fur_cream",
                        nose="nose_brick"),
    "ForestCat":   dict(rarity="Rare", fur="fur_russet", second="fur_seal", eyes="eye_amber", pattern="stripes", muzzle="fur_cream",
                        nose="nose_brick", scale=1.2, body_scale=(1.1, 1.05, 1.05), ruff="fur_cream", ear_tufts=True, tail_thick=0.28),
    "Toadstool":   dict(rarity="Epic", fur="cream", second="fur_rust_red", third="fur_rust_red", eyes="eye_amber", pattern="patches",
                        muzzle=None),
    "Firefly":     dict(rarity="Epic", fur="choco", second="choco", eyes="eye_amber", pattern="solid", muzzle="fur_brown",
                        nose="nose_brick", tip="sparkle"),
    "OldOak":      dict(rarity="Legendary", fur="dark_wood", second="leaf_green", eyes="eye_amber", pattern="spots", muzzle="fur_hazel",
                        nose="nose_brick", leafy=True),
    "Wisp":        dict(rarity="Mythical", fur="fur_white", second="fur_white", eyes="pastel_sky", pattern="solid", muzzle=None,
                        glow_eyes=True, sparkle=True,
                        mane=("fur_rose", "fur_apricot", "pastel_butter", "mint", "pastel_sky", "pastel_lilac")),
    "Lantern":     dict(rarity="Rare", fur="fur_soot", second="fur_soot", eyes="eye_amber", pattern="solid", muzzle="fur_grey",
                        nose="nose_dark"),
    "Bubbles":     dict(rarity="Rare", fur="fur_mist", second="fur_mist", eyes="eye_blue", pattern="solid", muzzle="fur_white"),
    "Gears":       dict(rarity="Epic", fur="fur_copper", second="rust", eyes="eye_green", pattern="stripes", muzzle="fur_cream",
                        nose="nose_brick"),
    "Glimmer":     dict(rarity="Epic", fur="fur_teal_grey", second="fur_teal_grey", eyes="eye_copper", pattern="solid",
                        muzzle="fur_white"),
    "Bottlecap":   dict(rarity="Legendary", fur="fur_caramel", second="bronze", third="bronze", eyes="eye_green", pattern="patches",
                        muzzle="fur_oat", nose="nose_brick"),
    "Eclipse":     dict(rarity="Mythical", fur="fur_emerald", second="sign_teal", third="dumpster_green", eyes="eye_amber",
                        pattern="gradient", muzzle=None, glow_eyes=True, nose="nose_dark"),
    # v0.6 plain Commons of the Neighbourhood, Woods and Sewer (data-model 3c): no prop, a coat that reads at a glance
    "Biscuit":     dict(rarity="Common", fur="treat_tan", second="treat_tan", eyes="eye_green", pattern="solid",
                        muzzle="fur_white", nose="nose_brick", socks="choco", tip="choco"),
    "Pepper":      dict(rarity="Common", fur="fur_pepper", second="fur_pepper", eyes="eye_amber", pattern="solid",
                        muzzle="fur_silver", nose="nose_dark", sprinkles=("fur_white", "fur_black")),
    "Socks":       dict(rarity="Common", fur="fur_ink", second="fur_ink", eyes="eye_chartreuse", pattern="solid",
                        muzzle="fur_white", socks="fur_white", tip="fur_white"),
    "Butter":      dict(rarity="Common", fur="pastel_butter", second="pastel_butter", eyes="eye_blue", pattern="solid",
                        muzzle="fur_white", body_scale=(1.08, 1.0, 1.05)),
    "Moss":        dict(rarity="Common", fur="fur_moss", second="fur_moss", eyes="eye_amber", pattern="solid", muzzle="fur_cream",
                        nose="nose_brick", ear_tufts=True),
    "Acorn":       dict(rarity="Common", fur="fur_acorn", second="fur_acorn", eyes="eye_green", pattern="solid", muzzle="fur_oat",
                        nose="nose_brick", tip="fur_brown"),
    "Bramble":     dict(rarity="Common", fur="fur_bramble", second="fur_seal", eyes="eye_chartreuse", pattern="stripes",
                        muzzle="fur_hazel", nose="nose_dark"),
    "Fern":        dict(rarity="Common", fur="fur_fern", second="leaf_dark", eyes="eye_amber", pattern="stripes", muzzle="fur_white"),
    "Rusty":       dict(rarity="Common", fur="fur_rust_red", second="fur_smoke_light", eyes="eye_green", pattern="patches",
                        muzzle="fur_cream", nose="nose_brick"),
    "Soot":        dict(rarity="Common", fur="fur_ash", second="fur_ash", eyes="eye_copper", pattern="solid", muzzle="fur_soot",
                        nose="nose_dark", tip="fur_soot"),
    "Pipes":       dict(rarity="Common", fur="fur_smoke_light", second="fur_charcoal", eyes="eye_green", pattern="stripes",
                        muzzle="fur_white", nose="nose_dark"),
    "Puddle":      dict(rarity="Common", fur="fur_puddle", second="fur_puddle", eyes="eye_amber", pattern="solid", muzzle="fur_mist",
                        nose="nose_dark", tip="fur_mist"),
    # v0.13 area-themed cats (F78, data-model 3, Derek 2026-10-27 23:59): they replace ten themed cats, which stay
    # built for whoever owns them (the spare pool)
    "Binbag":      dict(rarity="Rare", fur="fur_dusty", second="fur_soot", eyes="eye_green", pattern="stripes", muzzle="fur_white",
                        nose="nose_dark"),
    "Taxi":        dict(rarity="Epic", fur="fur_marmalade", second="fur_orange_dark", eyes="eye_green", pattern="stripes",
                        muzzle="fur_cream", nose="nose_brick", checker=("fur_white", "fur_black")),
    "Neon":        dict(rarity="Mythical", fur="fur_indigo", second="neon_pink", third="sign_teal", eyes="sign_teal",
                        pattern="stripes", muzzle=None, glow_eyes=True, stripes2=True),
    "Birdwatch":   dict(rarity="Rare", fur="fur_dune", second="fur_hazel", eyes="eye_copper", pattern="stripes", muzzle="fur_cream",
                        nose="nose_brick"),
    "Duckling":    dict(rarity="Epic", fur="fur_white", second="fur_silver", third="fur_mist", eyes="eye_blue", pattern="patches",
                        muzzle=None),
    "Balloon":     dict(rarity="Mythical", fur="fur_bubblegum", second="mint", third="pastel_butter", eyes="pastel_sky",
                        pattern="patches", muzzle=None, glow_eyes=True),
    "Builder":     dict(rarity="Rare", fur="fur_toffee", second="fur_seal", eyes="eye_amber", pattern="stripes", muzzle="fur_white",
                        nose="nose_brick", socks="fur_white"),
    "Gardener":    dict(rarity="Epic", fur="fur_cream", second="fur_grey", third="fur_smoke_light", eyes="eye_green", pattern="patches",
                        muzzle="fur_white"),
    "Gnome":       dict(rarity="Legendary", fur="fur_pewter", second="fur_white", third="fur_white", eyes="eye_green",
                        pattern="patches", muzzle="fur_white", fluffy=True, tail_thick=0.28, body_scale=(1.08, 1.0, 1.05)),
    "Plumber":     dict(rarity="Rare", fur="fur_gunmetal", second="fur_white", eyes="eye_copper", pattern="patches", muzzle="fur_white",
                        nose="nose_dark", tuxedo=True, socks="fur_gunmetal", tip="fur_gunmetal"),
    # F96 (starter-cat.md): the free Bellhop Cat, an exclusive cat earning at the Rare rate. Ginger and white: a ginger
    # tabby with a white chest, muzzle and blaze, white socks and a white curl at the tip of its tail; its cap, collar
    # and bell are props (props.py). Exclusive cats are never gold (no _Gold twins) and never roll rainbow.
    "BellhopCat":  dict(rarity="Rare", fur="fur_ginger", second="fur_russet", eyes="eye_green", pattern="stripes",
                        muzzle="fur_white", socks="fur_white", tip="fur_white", blaze="fur_white", curl=True,
                        exclusive=True),
}

COAT_FIELDS = ("fur", "second", "third", "ruff", "muzzle", "eyes", "eyes2", "nose", "tip", "socks", "blaze")


def has_gold(name):
    """Whether a roster cat has gold twins: every cat but the exclusives (the Bellhop Cat, F96)."""
    return not ROSTER[name].get("exclusive")


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
    # socks when the coat names them, else dark socks on points and white on a tuxedo
    c["paw"] = c.get("socks") or (c["second"] if pat == "points" or tux else c["fur"])
    c["ear"] = c["second"] if pat == "points" else c["third"] if pat == "gradient" else c["fur"]
    c.setdefault("tip", c["second"] if pat in ("points", "stripes") or tux else c["third"] if pat == "gradient" else c["fur"])
    belly = c.get("muzzle") or (c["second"] if tux else None)
    c["belly"] = belly if belly != c["fur"] else None
    return c


# -------------------------------------------------------------------------------------------- skeleton --
BODIES = ("walk", "sit", "work")
SUFFIX = {"walk": "", "sit": "_Sit", "work": "_Work"}
SIT_SCALE = 0.95            # B is drawn a touch smaller, so a sitting cat is no taller than a walking one
HEAD_PIECES = ("Eye1", "Eye2", "EarL", "EarR")
LEGS = {"walk": ("LegF1", "LegF2", "LegB1", "LegB2"), "sit": ("LegF1", "LegF2"), "work": ("LegF1", "LegF2", "LegB1", "LegB2")}

# Body A on all fours, unscaled studs. The belly is 0.33 off the floor and the legs reach up inside it to the hips.
A_BODY_C, A_BODY_S = (0.0, 0.12, 0.62), (0.78, 0.95, 0.58)
A_BELLY_Z, A_HIP_Z = 0.33, 0.42
A_LEG_XY = {"LegF1": (0.22, -0.2), "LegF2": (-0.22, -0.2), "LegB1": (0.22, 0.42), "LegB2": (-0.22, 0.42)}
A_NECK, A_TAIL = (0.0, -0.3, 0.85), (0.0, 0.58, 0.8)
SHORT_LEGS = 0.12           # how much lower a short-legged cat's body is on A (the Munchkin)
# Body B sitting up: haunches on the floor and an upright chest, the same on every cat so one outfit fits all.
# The haunches are a little narrower, shallower and further forward than the first B's (0.9 x 0.75 x 0.56 at y 0.18),
# and a big cat's body_scale widens them by half as much, so the rump is no shelf from behind (Derek 11-02: "the butt's
# look way too big" on a sitting Chonk).
B_HAUNCH_C, B_HAUNCH_S = (0.0, 0.13, 0.23), (0.78, 0.64, 0.46)
B_HAUNCH_BS = 0.5           # how much of a cat's body_scale over 1 its haunches take
S_HAUNCH_FRAME = ((0.0, 0.18, 0.28), (0.9, 0.75, 0.56))   # S keeps the first B's haunches for its back props' frames
B_CHEST_C, B_CHEST_S = (0.0, -0.06, 0.74), (0.7, 0.55, 0.72)
B_SHOULDER_Z = 0.62
B_LEG_XY = {"LegF1": (0.17, -0.3), "LegF2": (-0.17, -0.3)}
B_NECK, B_TAIL = (0.0, -0.1, 1.02), (0.2, 0.54)   # the tail root (x, y); it lies on the floor
# Heads, relative to the neck: centre, size, eye height, face scale, eye spacing, ear spacing, ear width and height
HEADS = {"walk": dict(c=(0.0, -0.22, 0.32), s=(1.0, 0.8, 0.84), fz=0.26, k=1.15, eye_dx=0.22, ear_x=0.3, ear=(0.32, 0.3)),
         "sit": dict(c=(0.0, -0.14, 0.28), s=(0.92, 0.74, 0.76), fz=0.24, k=1.05, eye_dx=0.21, ear_x=0.28, ear=(0.3, 0.3))}
EYE_H = 0.26
# Body S standing at work: B's chest at B's height (so the sitting outfit and B's back props fit as they are) on two
# short legs, A's head with its back over B's, and the front legs hanging from the shoulders as arms. Drawn at
# SIT_SCALE like B, so a working cat is no taller than a sitting one.
S_HIP_Z = 0.44
S_LEG_XY = {"LegB1": (0.17, -0.06), "LegB2": (-0.17, -0.06)}
S_SHOULDER = (0.475, -0.06, 0.82)             # LegF1's, the cat's left; LegF2 mirrors it
S_PAW_Z = -0.36                               # the paw's centre below the shoulder, the arm hanging straight down
S_TAIL = (0.0, B_CHEST_C[1] + B_CHEST_S[1] / 2 - 0.015, 0.5)
HEADS["work"] = dict(HEADS["walk"], c=(0.0, -0.17, 0.32), arms=True)
# Each role's held thing (HELD) rides one arm, and the role's pose turns the arms (Blender XYZ degrees about the
# shoulders; poses.CAT_POSES work_<role>): the barista holds out a cup in the right paw, the waiter a tray with a
# cake at its left side, the greeter waves its left paw, the entertainer holds a microphone up under its chin in the
# right paw with the left paw down at its side (Derek 11-02 picked Animation-Engineer's option A: Roblox angles
# LegF2 18, 84, 30 and LegF1 9.9, -1, -5.9, the barista's free paw).
WORK_ARMS = {
    "barista": {"LegF2": (-60, 25, 0), "LegF1": (-10, -6, 0)},
    "waiter": {"LegF1": (-45, -40, 0), "LegF2": (-10, 6, 0)},
    "greeter": {"LegF1": (-165, 60, 0), "LegF2": (-10, 6, 0)},
    "entertainer": {"LegF2": (-2.76, 47.87, 82.24), "LegF1": (-10, -6, 0)},
}
# How far a held thing leans from upright in its pose (Blender XYZ degrees, world): the microphone tips 15 toward
# the cat's middle, to the mouth; at 20 it touches the head or the cape's collar on some cats
HELD_LEAN = {"entertainer": (0, 15, 0)}
HELD = {"barista": "LegF2", "waiter": "LegF1", "entertainer": "LegF2"}      # role -> the arm its Held_<Role> rides


def scale_of(spec, body="walk"):
    """How much the built model is scaled: the cat's own scale, times SIT_SCALE for B."""
    return spec.get("scale", 1.0) * (SIT_SCALE if body in ("sit", "work") else 1.0)


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
    if spec.get("fold_ears"):                           # short and folded forward (_ear)
        ew, eh = ew * 0.95, eh * 0.6
    h["ear"] = (ew, eh)
    h["fy"] = cy - sy / 2                               # the face plane
    h["top"] = cz + sz / 2
    return h


def dims(spec, body="walk"):
    """Every box and joint of one cat's body, unscaled (scale_of applies after)."""
    bs = _body_scale(spec)
    d = {"head": _head_dims(spec, body),
         "leg_w": 0.2 if spec.get("sphynx") else 0.24 if body in ("walk", "work") else 0.2}
    tt = spec.get("tail_thick", 0.2) / 0.2
    tail_k = 0.7 if spec.get("sphynx") else 1 + (tt - 1) * 0.6
    if body == "walk":
        low = -SHORT_LEGS if spec.get("short_legs") else 0.0
        size = (A_BODY_S[0] * bs[0], A_BODY_S[1] * bs[1], A_BODY_S[2] * bs[2])
        d["body"] = ((A_BODY_C[0], A_BODY_C[1], A_BELLY_Z + low + size[2] / 2), size)
        dy, dz = (size[1] - A_BODY_S[1]) / 2, size[2] - A_BODY_S[2] + low
        d["neck"] = (A_NECK[0], A_NECK[1] - dy, A_NECK[2] + dz)
        d["tail"] = (A_TAIL[0], A_TAIL[1] + dy, A_TAIL[2] + dz)
        d["legs"] = {n: (x * bs[0], A_BODY_C[1] + (y - A_BODY_C[1]) * bs[1], A_HIP_Z + low)
                     for n, (x, y) in A_LEG_XY.items()}
        d["tail_chain"] = dict(angles=(35, 80), seg=0.3, thick=0.24 * tail_k, plane="X", taper=0.02,
                               curl=bool(spec.get("curl")))
    elif body == "work":
        d["chest"] = (B_CHEST_C, B_CHEST_S)
        d["haunch"] = S_HAUNCH_FRAME                     # only for props.Ctx's frames
        d["neck"] = B_NECK
        d["tail"] = S_TAIL
        sx, sy, sz = S_SHOULDER
        d["legs"] = {"LegF1": S_SHOULDER, "LegF2": (-sx, sy, sz), **{n: (x, y, S_HIP_Z) for n, (x, y) in S_LEG_XY.items()}}
        # out of the base of the back and up in a curve, the tip hooked over, leaning a little to the cat's left, so
        # it reads from behind, over the cape and above an apron's bow (Derek 11-02: "tail seems off"); a curled
        # tail stops a segment short and its curl (CURL) hooks it over instead
        d["tail_chain"] = dict(angles=(-15, 15, 45, 75) if spec.get("curl") else (-15, 15, 45, 75, 100), seg=0.24,
                               thick=0.2 * tail_k, plane="X", taper=0.015, lean=10, curl=bool(spec.get("curl")))
    else:
        size = tuple(B_HAUNCH_S[i] * (1 + (bs[i] - 1) * B_HAUNCH_BS) for i in range(3))
        d["haunch"] = ((B_HAUNCH_C[0], B_HAUNCH_C[1], size[2] / 2), size)
        d["chest"] = (B_CHEST_C, B_CHEST_S)
        d["back_paws"] = [(sx * (size[0] / 2 - 0.08), -0.1) for sx in (1, -1)]
        d["neck"] = B_NECK
        d["tail"] = (B_TAIL[0] * bs[0], B_HAUNCH_C[1] + size[1] / 2 - 0.015, 0.09 * tail_k + 0.02)   # lying just off the floor
        d["legs"] = {n: (x, y, B_SHOULDER_Z) for n, (x, y) in B_LEG_XY.items()}
        # out behind the haunches first, so it shows from behind, then forward along the left side; a curled tail's
        # tip rises there beside the front of the haunch, clear of the front paws
        d["tail_chain"] = dict(angles=(20, -45, -115), seg=0.35, thick=0.18 * tail_k, plane="Z", taper=0.0,
                               curl=bool(spec.get("curl")))
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


def carry_at(spec, body="walk"):
    """Where a carried thing rests on the head (F90: the Waiter's tray, the tip coin bag), relative to the neck and
    unscaled: over the middle of the head, at the ear tips (a Maine Coon's tufts too), so a tray pivoted at its
    underside rests flat on the ears. The cat models carry it as the Attachment `Carry` in the Head part."""
    h = dims(spec, body)["head"]
    ew, eh = h["ear"]
    if spec.get("fold_ears"):                           # tipped forward (_ear): the highest corner of the folded ear
        fold = Matrix.Rotation(math.radians(14), 3, "Y") @ Matrix.Rotation(math.radians(62), 3, "X")
        mid = fold @ Vector((0, 0, eh / 2))
        pts = [(sx * ew / 2, sy * ew / 2, -eh / 2) for sx in (1, -1) for sy in (1, -1)] + [(0, 0, eh / 2)]
        tip = h["top"] - 0.03 + max((mid + fold @ Vector(p)).z for p in pts)
    else:
        tip = h["top"] - 0.03 + eh + (0.12 if spec.get("ear_tufts") else 0.0)
    return (0.0, round(h["c"][1], 4), round(tip - 0.01, 4))


def back_rise(spec):
    """How far the coat's extras stand above the top of A's body box (_body_a, _coat_extras): a mane 0.09, star specks
    0.07, sprinkles 0.045, stripes, patches, spots and petals 0.03. The walking back pieces cover it."""
    if spec.get("mane"):
        return 0.09
    if spec.get("sparkle"):
        return 0.07
    if spec.get("sprinkles"):
        return 0.045
    return 0.03


def pose_lift(spec, pose):
    """A CAT_POSES lift for this cat, unscaled: a short-legged cat's body is already nearer the floor, so it drops
    less to lie down."""
    x, y, z = pose.get("lift", (0.0, 0.0, 0.0))
    if z < 0 and spec.get("short_legs") and pose["body"] == "walk":
        z = min(0.0, z + SHORT_LEGS)
    return (x, y, z)


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
        for i, x in enumerate((-0.2, 0.0, 0.2)):
            b.box((x * w, cy + 0.05, top + 0.01), (0.08, sy * 0.68, 0.06), _stripe(spec, c, i), bevel=False)
    elif pat == "patches" and not spec.get("tuxedo"):
        b.box((-0.22 * w, cy + 0.05, top + 0.01), (0.34 * w, sy * 0.55, 0.06), c["second"], bevel=False)
        b.box((0.3 * w, fy + 0.01, fz + 0.12), (0.2, 0.06, 0.26), c["third"], bevel=False)
    elif pat == "points":                               # a small dark muzzle under the eyes, not a mask round them
        b.box((0, fy + 0.005, fz - 0.24), (0.3 * w, 0.05, 0.24), c["second"], bevel=False)
    elif pat == "gradient":                             # the back of the head fades into the second colour
        lift = 0.06 if h.get("arms") else 0.0           # S: the band's sharp lower corners keep off a waving arm
        b.box((0, cy + sy * 0.3, cz + lift / 2), (sx + 0.03, sy * 0.42, sz + 0.03 - lift), c["second"], bevel=False)
    surf, under = fy, c["fur"]                          # the face the mouth is drawn on, and its colour
    if pat == "points":
        surf, under = fy - 0.02, c["second"]
    if c.get("muzzle") and c["muzzle"] != c["fur"]:
        # 0.02 proud like the points muzzle, so its front keeps 0.025 behind the eyes': on B and S (drawn at 0.95)
        # 0.015 came out under rbx_zfight's reach, which pushed the muzzle out over the nose and mouth (Derek 11-02)
        b.box((0, fy + 0.015, fz - 0.15 * k), (0.36 * k, 0.07, 0.2 * k), c["muzzle"], bevel=False)
        surf, under = fy - 0.02, c["muzzle"]
    if c.get("blaze"):                                  # up from the muzzle between the eyes, narrowing to the brow
        # each box starts where the one below it ends, so no two fronts overlap for rbx_zfight to push apart
        lo = fz - 0.05 * k                              # the muzzle's top
        b.box((0, fy + 0.012, (lo + fz) / 2), (0.16 * k, 0.06, fz - lo), c["blaze"], bevel=False)
        b.box((0, fy + 0.014, fz + 0.11), (0.11 * k, 0.06, 0.22), c["blaze"], bevel=False)
    b.box((0, fy - 0.025, fz - 0.11 * k), (0.1 * k, 0.06, 0.07 * k), c["nose"], bevel=False)
    _mouth(b, surf, fz - 0.145 * k, k, "fur_grey" if palette.lstar(under) < 35 else "fur_black")
    for side in (-1, 1):
        bx = side * (h["eye_dx"] + 0.15) * k
        b.box((bx, fy, fz - 0.14 * k), (0.12 * k, 0.05, 0.05 * k), "blush", bevel=False)
    if spec.get("persian") or spec.get("fluffy"):       # cheek fluff either side of the face
        for side in (-1, 1):
            b.box((side * (sx / 2 + 0.02), fy + 0.14, fz - 0.2), (0.14, 0.26, 0.3), c["second"])
    if spec.get("moon"):                                # crescent on the forehead
        b.box((0.02, fy - 0.015, fz + 0.24), (0.16, 0.04, 0.06), "sparkle", bevel=False)
        b.box((-0.05, fy - 0.012, fz + 0.19), (0.06, 0.04, 0.08), "sparkle", bevel=False)     # a hair behind the top bar
    if spec.get("sparkle") and spec["rarity"] == "Mythical":   # star specks on the face too
        for (x, z) in ((0.36 * w, fz + 0.2), (-0.37 * w, fz - 0.17)):
            b.box((x, fy - 0.015, z), (0.06, 0.04, 0.06), "sparkle", bevel=False)      # proud of the blush
    if spec.get("sprinkles"):                           # a few sprinkles on the cheeks and brow
        for i, (x, z, a) in enumerate(((0.37 * w, fz + 0.18, 30), (-0.36 * w, fz - 0.2, -40), (-0.3 * w, fz + 0.27, 70))):
            b.box((x, fy - 0.012, z), (0.1, 0.04, 0.035), spec["sprinkles"][i % len(spec["sprinkles"])], bevel=False,
                  rot=_rot(a, "Y"))
    if spec.get("mane"):                                # over the crown from the brow and down the back of the head
        m = spec["mane"]
        for i in range(3):
            b.box((0, cy - 0.12 + i * 0.13, top + 0.03 + 0.01 * (i % 2)), (0.16 + 0.02 * (i % 2), 0.15, 0.1 + 0.02 * (i % 2)),
                  m[i % len(m)], bevel=False)
        for i in range(2):
            b.box((0, cy + sy / 2 + 0.03 + 0.01 * (i % 2), top - 0.1 - i * 0.16), (0.17 + 0.02 * ((i + 1) % 2), 0.1, 0.17),
                  m[(i + 3) % len(m)], bevel=False)
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
    if spec.get("fold_ears"):                           # Scottish Fold: tipped forward over the brow, no pink showing
        fold = Matrix.Rotation(math.radians(side * 14), 3, "Y") @ Matrix.Rotation(math.radians(62), 3, "X")
        mid = fold @ Vector((0, 0, eh / 2))
        b.pyramid((mid.x, mid.y, mid.z - eh / 2), ew, eh, c["ear"], rot=fold)
        return b
    tilt = _rot(side * 12, "Y")
    b.pyramid((0, 0, 0), ew, eh, c["ear"], rot=tilt)
    lean = math.sin(math.radians(12)) * side
    b.box((lean * eh * 0.3, -ew * 0.36, eh * 0.3), (ew * 0.36, 0.03, eh * 0.38), "nose_pink", bevel=False, rot=tilt)
    if spec.get("ear_tufts"):
        b.pyramid((lean * eh, 0, eh * math.cos(math.radians(12)) - 0.04), 0.08, 0.16, c["second"], rot=tilt)
    return b


# A curled tip (spec curl), segment by segment: (turn, rise) in degrees from the last segment's heading, length,
# thickness (times the tail's) and whether it takes the tip colour. Plane X (A, the tail up behind) only rises: it
# goes on round over the back like a question mark. Plane Z (B, the tail on the floor) turns outward and back as it
# rises, a C beside the haunch clear of the front paws.
CURL = {"X": ((0, 50, 0.17, 0.85, False), (0, 105, 0.15, 0.75, True), (0, 160, 0.12, 0.65, True)),
        "Z": ((60, 35, 0.16, 0.85, False), (120, 50, 0.14, 0.75, True), (170, 30, 0.12, 0.65, True))}


def _tail(c, t):
    """Boxes chained from the tail root. Plane X: each angle tips the segment up from +Y toward +Z. Plane Z: lying
    on the floor, each angle is a heading in XY from +X. A curl adds two short tip segments bending on: on plane X
    on round over the back, on plane Z up off the floor and back over (CURL)."""
    b = Builder()
    pos = [0.0, 0.0, 0.0]
    n = len(t["angles"])
    curl = t.get("curl")
    lean = Matrix.Rotation(math.radians(t.get("lean", 0)), 3, "Y")      # tips the whole chain toward +X
    for i, deg in enumerate(t["angles"]):
        a = math.radians(deg)
        if t["plane"] == "X":
            d, rot = (0.0, math.cos(a), math.sin(a)), (a, "X")
            if t.get("lean"):
                d, rot = tuple(lean @ Vector(d)), lean @ Matrix.Rotation(a, 3, "X")
        else:
            d, rot = (math.cos(a), math.sin(a), 0.0), (a - math.pi / 2, "Z")
        seg, th = t["seg"], t["thick"] - i * t["taper"]
        b.box(tuple(pos[j] + d[j] * seg / 2 for j in range(3)), (th, seg + 0.06, th),
              c["tip"] if i == n - 1 and not curl else c["fur"], rot=rot)
        pos = [pos[j] + d[j] * seg for j in range(3)]
    if curl:
        last, th = math.radians(t["angles"][-1]), t["thick"] - (n - 1) * t["taper"]
        for turn, rise, seg, k, white in CURL[t["plane"]]:
            if t["plane"] == "X":
                a = last + math.radians(rise)
                d, rot = (0.0, math.cos(a), math.sin(a)), Matrix.Rotation(a, 3, "X")
                if t.get("lean"):
                    d, rot = tuple(lean @ Vector(d)), lean @ rot
            else:                                       # turn the heading, then rise from it toward +Z
                h, e = last + math.radians(turn), math.radians(rise)
                d = (math.cos(h) * math.cos(e), math.sin(h) * math.cos(e), math.sin(e))
                rot = Matrix.Rotation(h - math.pi / 2, 3, "Z") @ Matrix.Rotation(e, 3, "X")
            b.box(tuple(pos[j] + d[j] * seg / 2 for j in range(3)), (th * k, seg + 0.05, th * k),
                  c["tip"] if white else c["fur"], rot=rot)
            pos = [pos[j] + d[j] * seg for j in range(3)]
    return b


def _leg(c, hip_z, w, paw, paw_y=-0.01, toe=None):
    """A leg hanging from its hip pivot to the floor, with a paw (its front dipped in paint when `toe` is set)."""
    b = Builder()
    b.box_base((0, 0, 0.05 - hip_z), (w, w, hip_z - 0.05), c["leg"])          # the leg ends inside the paw
    b.box_base((0, paw_y, -hip_z), paw, c["paw"])
    if toe:
        _toe(b, (0, paw_y, -hip_z), paw, toe)
    return b


def _toe(b, base, paw, swatch):
    """Paint on the front third of a paw standing at `base` (bottom centre), a little proud all round."""
    x, y, z = base
    front = y - paw[1] / 2
    b.box_base((x, front + 0.045, z + 0.004), (paw[0] + 0.02, 0.11, paw[2] + 0.012), swatch, bevel=False)


def _coat_extras(b, spec, c, centre, size, sides=True, front=True, top=True):
    """Ruff, long-coat fringe, petals and star specks on one body box (A's body, or B's haunches and chest)."""
    (x0, y0, z0), (sx, sy, sz) = centre, size
    hx, hy, tz = sx / 2, sy / 2, z0 + sz / 2
    if spec.get("ruff") and front:                      # chest ruff under the chin
        b.box((0, y0 - hy - 0.04, z0 + sz * 0.1), (sx * 1.08, 0.12, sz * 0.7), spec["ruff"])
    if spec.get("persian") or spec.get("fluffy"):       # long coat: fringe along the flanks and down the chest
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
    if spec.get("sprinkles"):                           # sprinkles, each at its own angle, proud of the fur
        cols, i = spec["sprinkles"], 0
        if top:
            for (x, y, a) in ((0.18, 0.2, 30), (-0.16, -0.12, -50), (0.05, 0.02, 80), (-0.2, 0.3, 10), (0.2, -0.25, -20)):
                b.box((x * sx / 0.78, y0 + y * sy / 0.95, tz + 0.02), (0.12, 0.04, 0.05), cols[i % len(cols)], bevel=False,
                      rot=_rot(a, "Z"))
                i += 1
        if sides:
            for (side, y, z, a) in ((1, 0.15, 0.06, 40), (1, -0.18, -0.04, -30), (-1, 0.05, 0.08, -60), (-1, -0.25, -0.06, 20)):
                b.box((side * (hx + 0.01), y0 + y * sy / 0.95, z0 + z), (0.04, 0.12, 0.04), cols[i % len(cols)], bevel=False,
                      rot=_rot(a, "X"))
                i += 1


def _stripe(spec, c, i):
    """The colour of stripe i: the second colour, or second and third in turn on a stripes2 coat."""
    return c["third"] if spec.get("stripes2") and i % 2 else c["second"]


def _checker(b, cols, side, x, yc, length, zc, h, n=8):
    """A checkered band on one flank (x is the flank's outer face, past any stripes): a strip of the first colour
    0.02 proud, and two rows of squares in the second colour 0.01 proud of it, offset like a taxi's, a hair inside
    the strip's edges so no faces share a plane."""
    light, dark = cols
    b.box((side * (x - 0.0025), yc, zc), (0.045, length + 0.02, h), light, bevel=False)
    q, qh = length / n, h / 2 - 0.01
    for row, dz in enumerate((qh / 2, -qh / 2)):
        for j in range(row % 2, n, 2):
            b.box((side * (x + 0.0225), yc - length / 2 + q * (j + 0.5), zc + dz), (0.015, q, qh), dark, bevel=False)


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
        for i, f in enumerate((-0.28, 0.05, 0.36)):
            b.box((0, y0 + f * sy, z0 + 0.04), (sx + 0.04, 0.13, sz - 0.02), _stripe(spec, c, i), bevel=False)
    elif pat == "patches":
        b.box((-hx - 0.01, y0 + 0.12, z0 + 0.05), (0.04, 0.45, 0.32), c["second"], bevel=False)      # right flank
        b.box((hx + 0.01, y0 - 0.15, z0 - 0.02), (0.04, 0.34, 0.26), c["third"], bevel=False)        # left flank
        b.box((0.12, y0 + 0.2, top + 0.01), (0.36, 0.42, 0.04), c["third"], bevel=False)             # saddle
        b.box((-0.16, y0 - 0.18, top + 0.01), (0.28, 0.32, 0.04), c["second"], bevel=False)
    elif pat == "spots":                                # leafy: each spot a leaf, a long diamond
        top_rot, side_rot, ls = (_rot(45, "Z"), _rot(45, "X"), 0.13) if spec.get("leafy") else (None, None, 0.16)
        for (x, y) in ((0.15, 0.2), (-0.18, -0.15), (0.2, -0.3), (-0.1, 0.35)):
            b.box((x, y0 + y, top + 0.01), (ls, ls * (1.6 if top_rot else 1), 0.04), c["second"], bevel=False, rot=top_rot)
        for (side, y, z) in ((-1, 0.2, 0.06), (-1, -0.2, -0.06), (1, 0.0, 0.04), (1, 0.32, -0.08)):
            b.box((side * (hx + 0.01), y0 + y, z0 + z), (0.04, ls * (1.6 if side_rot else 1), ls), c["second"], bevel=False,
                  rot=side_rot)
    elif pat == "gradient":                             # front to back: fur, second, third
        b.box((0, y0 + 0.04, z0), (sx + 0.03, sy * 0.3, sz + 0.03), c["second"], bevel=False)
        b.box((0, y0 + hy * 0.66, z0), (sx + 0.04, sy * 0.36, sz + 0.04), c["third"], bevel=False)
    if c["belly"] and not spec.get("tuxedo") and not spec.get("ruff"):    # a pale chest under the chin (the ruff covers it)
        b.box((0, y0 - hy - 0.01, z0 - 0.04), (0.36, 0.06, sz * 0.6), c["belly"], bevel=False)
    _coat_extras(b, spec, c, d["body"][0], d["body"][1])
    if spec.get("checker"):                             # along each flank, over the stripes
        for side in (-1, 1):
            _checker(b, spec["checker"], side, hx + 0.02, y0 - 0.02, sy * 0.78, z0 - 0.02, 0.14)
    if spec.get("mane"):                                # down the neck and along the front of the back
        for i in range(3):
            b.box((0, y0 - hy + 0.08 + i * 0.15, top + 0.03 + 0.01 * (i % 2)), (0.16 + 0.02 * (i % 2), 0.17, 0.1),
                  spec["mane"][(i + 5) % len(spec["mane"])], bevel=False)
    return b


def _body_b(spec, c, d):
    b = Builder()
    (hx0, hy0, hz0), (hsx, hsy, hsz) = d["haunch"]
    (cx0, cy0, cz0), (csx, csy, csz) = d["chest"]
    b.box(d["haunch"][0], d["haunch"][1], c["fur"])
    b.box(d["chest"][0], d["chest"][1], c["fur"])
    for i, (x, y) in enumerate(d["back_paws"]):
        b.box_base((x, y, 0.01), (0.24, 0.4, 0.11), c["paw"])                  # 0.01 up: no shared floor plane
        if spec.get("toes"):
            _toe(b, (x, y, 0.01), (0.24, 0.4, 0.11), spec["toes"][2 + i])
    front, htop = cy0 - csy / 2, hsz
    pat = spec["pattern"]
    if spec.get("tuxedo"):
        b.box((0, front - 0.01, cz0), (0.42, 0.06, 0.6), c["second"], bevel=False)                   # bib
    elif c["belly"] and not spec.get("ruff"):
        b.box((0, front - 0.01, cz0 + 0.02), (0.34, 0.06, 0.5), c["belly"], bevel=False)
    if pat == "stripes":
        for i, z in enumerate((0.5, 0.75, 1.0)):
            b.box((0, cy0 + 0.05, z), (csx + 0.04, csy - 0.06, 0.1), _stripe(spec, c, i), bevel=False)
        for i, y in enumerate((0.05, 0.35)):
            b.box((0, y, hz0), (hsx + 0.04, 0.12, hsz - 0.08), _stripe(spec, c, i + 1), bevel=False)
    elif pat == "patches" and not spec.get("tuxedo"):
        b.box((-hsx / 2 - 0.01, hy0 + 0.02, hz0 + 0.04), (0.04, 0.4, 0.3), c["second"], bevel=False)   # right haunch
        b.box((csx / 2 + 0.01, cy0 + 0.05, 0.85), (0.04, 0.3, 0.3), c["third"], bevel=False)          # left of the chest
        b.box((0.1, hy0 + 0.12, htop + 0.01), (0.4, 0.3, 0.04), c["third"], bevel=False)              # on the haunches
    elif pat == "spots":
        top_rot, side_rot, ls = (_rot(45, "Z"), _rot(45, "X"), 0.13) if spec.get("leafy") else (None, None, 0.16)
        lw = ls * (1.6 if top_rot else 1)
        for (side, y, z) in ((-1, 0.25, 0.3), (-1, 0.0, 0.18), (1, 0.08, 0.36), (1, 0.34, 0.2)):
            b.box((side * (hsx / 2 + 0.01), y, z), (0.04, lw, ls), c["second"], bevel=False, rot=side_rot)
        for (x, y) in ((0.16, 0.36), (-0.2, 0.3)):
            b.box((x, y, htop + 0.01), (ls, lw, 0.04), c["second"], bevel=False, rot=top_rot)
        for side in (-1, 1):
            b.box((side * (csx / 2 + 0.01), cy0, 0.86), (0.04, lw, ls), c["second"], bevel=False, rot=side_rot)
    elif pat == "gradient":                             # chest in the fur, haunches in second, the rump in third
        b.box_base((0, hy0 - 0.02, 0.005), (hsx + 0.03, hsy * 0.62, hsz + 0.01), c["second"], bevel=False)   # off the floor
        b.box_base((0, hy0 + hsy * 0.36, 0.008), (hsx + 0.04, hsy * 0.3, hsz + 0.012), c["third"], bevel=False)
    _coat_extras(b, spec, c, d["haunch"][0], d["haunch"][1], front=False)
    if spec.get("checker"):                             # along each haunch, over the stripes
        for side in (-1, 1):
            _checker(b, spec["checker"], side, hsx / 2 + 0.02, hy0 + 0.02, hsy * 0.8, hz0 + 0.02, 0.14)
    _coat_extras(b, {**spec, "petals": False}, c, d["chest"][0], d["chest"][1], top=False)
    if spec.get("mane"):                                # down the back of the chest
        for i in range(3):
            b.box((0, cy0 + csy / 2 + 0.03 + 0.01 * (i % 2), 1.0 - i * 0.16), (0.16 + 0.02 * (i % 2), 0.1, 0.17),
                  spec["mane"][(i + 5) % len(spec["mane"])], bevel=False)
    return b


def _body_s(spec, c, d):
    """S: B's chest alone, with B's chest markings, a little more of the pattern where B's haunches were."""
    b = Builder()
    (cx0, cy0, cz0), (csx, csy, csz) = d["chest"]
    b.box(d["chest"][0], d["chest"][1], c["fur"])
    front, bottom = cy0 - csy / 2, cz0 - csz / 2
    pat = spec["pattern"]
    if spec.get("tuxedo"):
        b.box((0, front - 0.01, cz0), (0.42, 0.06, 0.6), c["second"], bevel=False)                   # bib
        b.box((0, cy0, bottom - 0.01), (0.46, csy * 0.7, 0.04), c["second"], bevel=False)            # under the chest
    elif c["belly"] and not spec.get("ruff"):
        b.box((0, front - 0.01, cz0 + 0.02), (0.34, 0.06, 0.5), c["belly"], bevel=False)
    if pat == "stripes":
        for i, z in enumerate((0.5, 0.75, 1.0)):
            b.box((0, cy0 + 0.05, z), (csx + 0.04, csy - 0.06, 0.1), _stripe(spec, c, i), bevel=False)
    elif pat == "patches" and not spec.get("tuxedo"):
        b.box((csx / 2 + 0.01, cy0 + 0.05, 0.85), (0.04, 0.3, 0.3), c["third"], bevel=False)          # left of the chest
        b.box((-csx / 2 - 0.01, cy0 + 0.02, 0.58), (0.04, 0.34, 0.28), c["second"], bevel=False)      # right, lower
        b.box((0.08, cy0 + csy / 2 + 0.01, 0.62), (0.3, 0.04, 0.3), c["third"], bevel=False)          # on the back
    elif pat == "spots":
        top_rot, side_rot, ls = (_rot(45, "Z"), _rot(45, "X"), 0.13) if spec.get("leafy") else (None, None, 0.16)
        lw = ls * (1.6 if top_rot else 1)
        for (side, y, z) in ((-1, cy0 + 0.1, 0.86), (-1, cy0 - 0.1, 0.56), (1, cy0 - 0.06, 0.86), (1, cy0 + 0.1, 0.6)):
            b.box((side * (csx / 2 + 0.01), y, z), (0.04, lw, ls), c["second"], bevel=False, rot=side_rot)
    elif pat == "gradient":                             # the chest in the fur, its lower part second, the bottom third
        b.box_base((0, cy0, bottom - 0.015), (csx + 0.03, csy + 0.03, 0.3), c["second"], bevel=False)
        b.box_base((0, cy0, bottom - 0.02), (csx + 0.04, csy + 0.04, 0.13), c["third"], bevel=False)
    for side in (1, -1):                                # the shoulders the arms turn on (S_SHOULDER), in the fur
        b.box((side * (csx / 2 + 0.06), S_SHOULDER[1], S_SHOULDER[2] - 0.03), (0.16, 0.17, 0.17), c["fur"])
    _coat_extras(b, spec, c, d["chest"][0], d["chest"][1], top=False)
    if spec.get("checker"):                             # along each side of the chest, over the stripes
        for side in (-1, 1):
            _checker(b, spec["checker"], side, csx / 2 + 0.02, cy0, csy * 0.8, 0.62, 0.14)
    if spec.get("mane"):                                # down the back of the chest
        for i in range(3):
            b.box((0, cy0 + csy / 2 + 0.03 + 0.01 * (i % 2), 1.0 - i * 0.16), (0.16 + 0.02 * (i % 2), 0.1, 0.17),
                  spec["mane"][(i + 5) % len(spec["mane"])], bevel=False)
    return b


def _arm(c, side, toe=None):
    """S's front leg as an arm hanging from its shoulder pivot (the shoulder itself is on the Body, _body_s): the
    arm, ending just over the pivot so it turns clear of the head, and a paw at its end (its front dipped in paint
    when `toe` is set)."""
    b = Builder()
    b.box_base((0, 0, S_PAW_Z + 0.02), (0.15, 0.16, 0.04 - S_PAW_Z), c["leg"])     # ends inside the paw
    paw = (0.18, 0.19, 0.13)
    b.box((0, -0.01, S_PAW_Z), paw, c["paw"])
    if toe:
        _toe(b, (0, -0.01, S_PAW_Z - paw[2] / 2), paw, toe)
    return b


def _held(role, arm):
    """A role's held thing, drawn standing up at the paw (the origin) as it is held in the role's pose, then turned
    back by that arm's pose, so the arm Model carries it upright (or leaning by HELD_LEAN) when the game turns the arm
    (WORK_ARMS)."""
    from props import Pen                               # props imports this module
    R = Euler([math.radians(a) for a in WORK_ARMS[role][arm]], "XYZ").to_matrix().inverted() @ \
        Euler([math.radians(a) for a in HELD_LEAN.get(role, (0, 0, 0))], "XYZ").to_matrix()
    b = Builder()
    P = Pen(b, (0.0, 0.0, 0.0), R, 1.0)                 # the object sits at the paw (build_cat at_)
    if role == "barista":                               # a takeaway cup with a sleeve and a lid
        P.cyl((0, -0.02, 0.1), 0.085, 0.2, "offwhite", r2=0.105, segments=10)
        P.cyl((0, -0.02, 0.1), 0.098, 0.07, "dark_wood", r2=0.104, segments=10)
        P.cyl((0, -0.02, 0.215), 0.112, 0.03, "choco", segments=10)
    elif role == "waiter":                              # a round tray at the side with a cup and a slice of cake
        t = (0.14, -0.04, 0.085)
        P.cyl(t, 0.3, 0.03, "metal", segments=14)
        P.cyl((t[0] - 0.12, t[1] + 0.06, t[2] + 0.08), 0.07, 0.13, "offwhite", r2=0.085, segments=10)
        P.box((t[0] + 0.1, t[1] - 0.05, t[2] + 0.075), (0.18, 0.15, 0.12), "pastel_butter")
        P.box((t[0] + 0.1, t[1] - 0.05, t[2] + 0.15), (0.19, 0.16, 0.035), "blush")
        P.sphere((t[0] + 0.1, t[1] - 0.05, t[2] + 0.19), 0.035, "shirt_red", segments=8, rings=5)
    elif role == "entertainer":                         # a microphone, gripped at the paw's outer side, clear of a wide head
        P.cyl((-0.06, -0.03, 0.09), 0.035, 0.3, "fur_black", r2=0.045, segments=8)
        P.sphere((-0.06, -0.03, 0.27), 0.075, "metal", segments=8, rings=5)
    return b


def build_cat(name, mat, spec=None, base=None, body="walk"):
    """One cat model. `spec` and `base` override the roster entry and the asset name (gold.py builds the gold cats
    here); `body` is "walk" (A), "sit" (B) or "work" (S)."""
    spec = spec or ROSTER[name]
    base = base or f"CatCafe_Cat_{name}{SUFFIX[body]}"
    c = look(spec)
    d = dims(spec, body)
    h = d["head"]
    k = scale_of(spec, body)
    w = d["leg_w"]
    paw = {"walk": (w + 0.03, w + 0.03, 0.11), "sit": (w + 0.04, w + 0.08, 0.11), "work": (w + 0.03, w + 0.1, 0.11)}[body]
    paw_y = {"walk": -0.01, "sit": -0.05, "work": -0.05}[body]
    pieces = [("Body", {"walk": _body_a, "sit": _body_b, "work": _body_s}[body](spec, c, d)),
              ("Head", _head(spec, c, h)),
              ("Eye1", _eye(spec, c, h, 1)), ("Eye2", _eye(spec, c, h, -1)),
              ("EarL", _ear(spec, c, h, 1)), ("EarR", _ear(spec, c, h, -1)),
              ("Tail", _tail(c, d["tail_chain"]))]
    toes = spec.get("toes") or (None,) * 4
    rides, at_ = {}, {}
    if body == "work":                                  # arms, then legs; each role's held thing rides its arm
        pieces += [(n, _arm(c, 1 if n == "LegF1" else -1, toes[i])) for i, n in enumerate(("LegF1", "LegF2"))]
        pieces += [(n, _leg(c, d["legs"][n][2], w, paw, paw_y, toes[2 + i])) for i, n in enumerate(("LegB1", "LegB2"))]
        for role, arm in HELD.items():
            piece = "Held_" + role.capitalize()
            pieces.append((piece, _held(role, arm)))
            rides[piece] = arm
            at_[piece] = tuple(d["legs"][arm][i] + (0.0, -0.01, S_PAW_Z)[i] for i in range(3))
    else:
        pieces += [(n, _leg(c, d["legs"][n][2], w, paw, paw_y, toes[i])) for i, n in enumerate(LEGS[body])]
    import props                                        # themed cats' props (props imports this module)
    shift = {}
    if name in props.PROPS:                             # S wears B's props: the same chest, its own head
        for suffix, (b, at) in props.build(name, spec, body, d).items():
            pieces.append((suffix, b))
            rides[suffix] = props.follows(props.piece_slot(name, suffix))
            shift[suffix] = at                          # a prop pivoted at its own hinge (the Bellhop's cap, its bell)
    objs = []
    for piece, b in pieces:
        at = at_.get(piece) or d["pivots"][rides.get(piece, piece)]
        at = tuple(at[i] + shift.get(piece, (0.0, 0.0, 0.0))[i] for i in range(3))
        ob = b.finalize(f"{base}_{piece}", mat, location=tuple(v * k for v in at))
        if k != 1.0:
            scale_mesh(ob, k)
        if piece in rides:
            ob["rides"] = rides[piece]                  # poses.py turns a prop with the piece it rides
        objs.append(ob)
    return objs


def parse(asset):
    """CatCafe_Cat_<Name>[_Gold][_Sit|_Work] -> (name, gold, body)."""
    rest = asset[len("CatCafe_Cat_"):]
    body = "sit" if rest.endswith("_Sit") else "work" if rest.endswith("_Work") else "walk"
    rest = rest.removesuffix("_Sit").removesuffix("_Work")
    gold = rest.endswith("_Gold")
    return rest.removesuffix("_Gold"), gold, body


ASSETS = {}
for _n in ROSTER:
    for _body in BODIES:
        ASSETS[f"CatCafe_Cat_{_n}{SUFFIX[_body]}"] = (lambda mat, n=_n, bd=_body: build_cat(n, mat, body=bd),
                                                      2400 if _body == "work" else 1500)
