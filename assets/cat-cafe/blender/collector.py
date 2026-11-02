"""The Cat Collector (F63, data-model.md 12b; contract from the Gameplay-Engineer, PR #499).

  CatCafe_NPC_Collector                a big grey tabby gentleman (scale 1.45) in a long tweed coat with a faint light
                                       check and a bowler hat, sitting on the floor and holding a magnifying glass up
                                       to his right eye, which shows through it half as big again. The client pivots
                                       him on the plot's CollectorSpot by the counter: the pivot is on the floor under
                                       him, front -Z into the room. The usual hinged sitting-cat pieces (Head, Eye1,
                                       Eye2, EarL, EarR, Tail, LegF1, LegF2); the hat is `_Prop` inside the Head, the
                                       coat `_Coat` on the body and the magnifying glass `_Lens` inside the raised
                                       LegF2. Nothing collides; he fits a 2 x 2 footprint and sits 2.7 tall to the top
                                       of his hat.
"""

import math

from mathutils import Matrix, Vector

import cats
import props
from common import PRIMS, Builder, scale_mesh

NAME = "CatCafe_NPC_Collector"
COLLECTOR = dict(rarity="Common", fur="fur_grey", second="fur_charcoal", eyes="eye_green", pattern="stripes",
                 muzzle="fur_white", nose="nose_pink", scale=1.45)
TWEED, CHECK = "fur_hazel", "fur_latte"
LAPEL, ACCENT, BRASS, HAT = "fur_bramble", "fur_emerald", "brass", "choco"
PAW_LIFT = -125.0           # degrees LegF2 turns about X: the paw comes up in front of the chest
# Objects whose Model goes inside another's in the export (rbx_export.NEST).
NEST = {NAME: {"_Prop": "_Head", "_Lens": "_LegF2"}}


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def _turn_mesh(ob, R):
    """Turn an object's mesh about its origin, keeping its primitive log in step (scale_mesh's twin)."""
    R4 = R.to_4x4()
    ob.data.transform(R4)
    PRIMS[ob.data.name] = [(k, R4 @ m, sw, extra) for k, m, sw, extra in PRIMS.get(ob.data.name, [])]


def _hat(ctx):
    """A bowler perched a little forward on the head frame (origin on the head's top, y to the back), with an
    emerald band; the cat's ears come up through the brim."""
    P = ctx.pen("head")
    tilt = _rx(-8)
    at = Vector((0, -0.08, 0.0))
    P.cyl(tuple(at + tilt @ Vector((0, 0, 0.03))), 0.37, 0.04, HAT, rot=tilt, segments=14)            # brim
    P.sphere(tuple(at + tilt @ Vector((0, 0, 0.05))), 0.25, HAT, scale=(1, 1, 0.92), rot=tilt, segments=12,
             rings=6)                                                                                 # crown
    P.cyl(tuple(at + tilt @ Vector((0, 0, 0.1))), 0.252, 0.06, ACCENT, rot=tilt, segments=14)          # band


def _lines(b, face, lo, hi, at, us, vs):
    """A faint windowpane check on one flat face: `face` "x", "-x", "y" for a side or the back, `lo`/`hi` the face's
    extent in its two other axes, `at` its outer coordinate, `us`/`vs` where the lines cross each axis. Thin light
    lines, the cross ones a hair further out."""
    (u0, v0), (u1, v1) = lo, hi
    out = 1 if face in ("x", "y") else -1
    side = face in ("x", "-x")
    for u in us:
        c = (at + out * 0.005, u, (v0 + v1) / 2) if side else (u, at + 0.005, (v0 + v1) / 2)
        b.box(c, (0.01, 0.015, v1 - v0) if side else (0.015, 0.01, v1 - v0), CHECK, bevel=False)
    for v in vs:
        c = (at + out * 0.0075, (u0 + u1) / 2, v) if side else ((u0 + u1) / 2, at + 0.0075, v)
        b.box(c, (0.015, u1 - u0, 0.015) if side else (u1 - u0, 0.015, 0.015), CHECK, bevel=False)


# The coat's back drapes from the shoulders (y 0.265, z 1.1) to the top of the skirt (y 0.605, z 0.56).
DRAPE_D, DRAPE_H = 0.34, 0.54
DRAPE_L = math.hypot(DRAPE_D, DRAPE_H)
DRAPE_TILT = math.degrees(math.atan2(DRAPE_D, DRAPE_H))         # turning the Z axis up the drape
DRAPE_N = Vector((0, DRAPE_H, DRAPE_D)) / DRAPE_L               # its outward normal


def _coat(b):
    """The coat in the sitting body's frame (Blender axes, unscaled; the chest is 0.7 wide, 0.55 deep and runs from
    0.38 to 1.1, the haunch 0.9 wide from y -0.2 to 0.56 and 0.56 tall; the head covers the chest front above
    0.92): a stout coat a stud wide from the shoulders to a hem above the tail, open in a V over the white bib with
    dark lapels, an emerald bow tie and brass buttons, cut away in front of the front legs, its back draped over the
    haunches with a vent, and a faint light check all round."""
    for sx in (1, -1):
        b.box((sx * 0.475, -0.035, 0.83), (0.05, 0.6, 0.54), TWEED, bevel=False)            # sides
        b.box((sx * 0.475, 0.135, 0.39), (0.05, 0.94, 0.34), TWEED, bevel=False)            # and below the waist
        b.box((sx * 0.32, -0.355, 0.83), (0.36, 0.04, 0.54), TWEED, bevel=False)             # fronts
        b.box((sx * 0.4, -0.355, 0.39), (0.2, 0.04, 0.34), TWEED, bevel=False)               # tails, clear of the legs
        b.fan((0, -0.38, 0), (sx * 0.14, 0.64), [(sx * 0.14, 0.92), (sx * 0.33, 0.92)], 0.02, LAPEL,
              rot=_rx(90))                                                                   # lapels
        b.box((sx * 0.07, -0.37, 0.88), (0.12, 0.04, 0.1), ACCENT, bevel=False, rot=_ry(sx * 20))   # bow tie
    b.box((0, -0.385, 0.88), (0.05, 0.03, 0.06), ACCENT, bevel=False)
    b.box((0, -0.035, 1.125), (1.0, 0.6, 0.05), TWEED, bevel=False)                          # shoulders
    for z in (0.74, 0.62):                                                                    # buttons
        b.cyl((0.26, -0.38, z), 0.035, 0.02, BRASS, segments=8, bevel=False, rot=(math.radians(90), "X"))
    b.wedge((0, 0.435, 0.83), (1.0, DRAPE_D, DRAPE_H), TWEED, bevel=False, rot=_rz(180))     # the drape
    b.box((0, 0.58, 0.39), (0.9, 0.05, 0.34), TWEED, bevel=False)                            # skirt back
    b.box((0, 0.61, 0.38), (0.02, 0.01, 0.3), LAPEL, bevel=False)                            # the vent
    # the check: lines 0.2 apart across, at z 0.39, 0.74 and 0.92 up
    for sx, face in ((1, "x"), (-1, "-x")):
        _lines(b, face, (-0.335, 0.56), (0.265, 1.1), sx * 0.5, (-0.135, 0.065), (0.74, 0.92))
        _lines(b, face, (-0.335, 0.22), (0.605, 0.56), sx * 0.5, (-0.135, 0.065, 0.265, 0.465), (0.39,))
    _lines(b, "y", (-0.45, 0.22), (0.45, 0.56), 0.605, (-0.3, -0.1, 0.1, 0.3), (0.39,))
    tilt = _rx(DRAPE_TILT)
    for x in (-0.3, -0.1, 0.1, 0.3):
        b.box(tuple(Vector((x, 0.435, 0.83)) + DRAPE_N * 0.005), (0.015, 0.01, DRAPE_L - 0.02), CHECK, bevel=False,
              rot=tilt)
    for z in (0.74, 0.92):
        t = (1.1 - z) / DRAPE_H
        b.box(tuple(Vector((0, 0.265 + DRAPE_D * t, z)) + DRAPE_N * 0.0075), (0.98, 0.015, 0.015), CHECK,
              bevel=False, rot=tilt)


def _lens(b, pivot, lift):
    """The magnifying glass, in LegF2's frame (`pivot` is the leg's shoulder, `lift` the turn that raises its paw): a
    tweed sleeve with a white cuff on the raised leg, a brass rim and glass in front of the right eye on a dark wood
    handle through the paw, and that eye on the glass, half as big again."""
    def p(x, y, z):
        return (x - pivot[0], y - pivot[1], z - pivot[2])

    for z, h, sw in ((-0.24, 0.4, TWEED), (-0.46, 0.04, "offwhite")):                   # sleeve and cuff
        b.box(tuple(lift @ Vector((0, 0, z))), (0.28 + 0.02 * (sw != TWEED), 0.28 + 0.02 * (sw != TWEED), h), sw,
              bevel=False, rot=lift)
    cx, cy, cz, r = -0.21, -0.76, 1.33, 0.26
    up = _rx(90)
    b.ring(p(cx, cy, cz), r, 0.05, 0.05, BRASS, segments=12, bevel=False, rot=up)            # rim, y -0.785..-0.735
    b.cyl(p(cx, cy, cz), r - 0.015, 0.02, "glass", segments=12, bevel=False, rot=up)       # glass, front at -0.77
    b.cyl(p(cx, cy, cz - r - 0.03), 0.035, 0.08, BRASS, segments=8, bevel=False)           # ferrule
    b.cyl(p(cx, cy, cz - r - 0.22), 0.045, 0.3, "dark_wood", segments=8, bevel=False)      # handle
    # the eye seen through it, laid on the glass's front inside the rim, drawn like the cats' own (cats._eye)
    b.box(p(cx, cy - 0.015, cz), (0.24, 0.01, 0.34), "eye_green", bevel=False)             # iris
    b.box(p(cx + 0.01, cy - 0.0225, cz - 0.03), (0.145, 0.005, 0.245), "fur_black", bevel=False)   # pupil
    b.box(p(cx - 0.05, cy - 0.02625, cz + 0.08), (0.07, 0.0025, 0.08), "milk", bevel=False)        # highlight


def build_collector(mat):
    cat = cats.build_cat("Collector", mat, spec=COLLECTOR, base=NAME, body="sit")
    d = cats.dims(COLLECTOR, "sit")
    k = cats.scale_of(COLLECTOR, "sit")
    ctx = props.Ctx(COLLECTOR, "sit", d)
    _hat(ctx)
    hat = ctx.main.finalize(NAME + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hat, k)
    hat["rides"] = "Head"
    cb = Builder()
    _coat(cb)
    coat = cb.finalize(NAME + "_Coat", mat)
    scale_mesh(coat, k)
    pivot, lift = d["pivots"]["LegF2"], _rx(PAW_LIFT)
    leg = next(ob for ob in cat if ob.name == NAME + "_LegF2")
    _turn_mesh(leg, lift)                   # the paw comes up holding the glass
    lb = Builder()
    _lens(lb, pivot, lift)
    lens = lb.finalize(NAME + "_Lens", mat, location=tuple(v * k for v in pivot))
    scale_mesh(lens, k)
    return cat + [hat, coat, lens]


ASSETS = {NAME: (build_collector, 2600)}
