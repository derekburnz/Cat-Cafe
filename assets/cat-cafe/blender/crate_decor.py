"""Crate furniture and decorations (F53, golden-fish.md section 4): the pieces a Cafe Crate gives that stand on a decor
spot in the cafe, two per crate plus the zone's Epic. A decor spot sits 1.4 studs out from a wall, so every piece keeps
to about 4 studs wide and 2.5 deep around its pivot: base centre, the front toward -Z. Lights are `_Glow` objects (Neon
day and night), water `_Water`, clear jars and bubbles the glass swatch, and a window to look through `_Glass`.

  Alley          CatCafe_Decor_MilkCrateStools (C), _RetroJukebox (L), _JarLights (R); MuralPrint (E) is in decor.py
  Park           _PicnicTableSet (R), _DuckFountain (L), _BlossomTree (M); ParkBench (E) is in decor.py
  Neighbourhood  _PorchSwing (R), _IceCreamCounter (L), _BicyclePlanter (R), _MailboxPlanter (E, on the Index anchor)
  Woods          _LogStools (C), _HollowLogBooth (L), _LanternStump (R), _MushroomLamp (E, on the Index anchor)
  Sewer          _CrateShelf (C), _BathtubSofa (L), _RubberDuckRow (R), _PipeFountain (E, on the Index anchor)
  Classic        _BistroSet (R), _VelvetBooth (E), _HangingPlants (R), _CatTreeTower (L)

The names come from Catalog.luau CRATE_PIECES: CatCafe_Decor_ and the piece name without spaces.
"""

import math

from mathutils import Matrix, Vector

from common import RB
from plot import rot_x, rot_y, rot_z

HOLE = "night_sky"            # the dark of an opening: crate handles, the mailbox, the cubby door
WATER = "fish_blue"


def _rod(b, p0, p1, t, sw):
    """A square rod t thick from p0 to p1: legs, cords, chains, bike tubes. A leaning leg that starts on the floor
    is lifted until its lowest corner touches it."""
    a, c = Vector(p0), Vector(p1)
    rot = Vector((0, 1, 0)).rotation_difference((c - a).normalized()).to_matrix()
    if a.y == 0:
        a.y = t / 2 * (abs(rot[1][0]) + abs(rot[1][2]))
        rot = Vector((0, 1, 0)).rotation_difference((c - a).normalized()).to_matrix()
    d = c - a
    b.box(tuple((a + c) / 2), (t, d.length, t), sw, rot=rot)


def _arc(b, cx, cy, z, r, a0, a1, n, w, d, sw):
    """Boxes along a circle of radius r in the XY plane at depth z, from angle a0 to a1 (degrees): neon tubes,
    fenders, basket handles."""
    step = math.radians(abs(a1 - a0) / n)
    length = 2 * r * math.sin(step / 2) * 1.06
    for k in range(n):
        t = math.radians(a0 + (a1 - a0) * (k + 0.5) / n)
        b.box((cx + r * math.cos(t), cy + r * math.sin(t), z), (length, w, d), sw, rot=rot_z(math.degrees(t) + 90))


def _arc_flat(b, cx, y, cz, r, a0, a1, n, t, sw):
    """Boxes along a circle of radius r lying flat at height y (a chair's back rail); angle 0 is +X, 90 is +Z."""
    step = math.radians(abs(a1 - a0) / n)
    length = 2 * r * math.sin(step / 2) * 1.08
    for k in range(n):
        a = math.radians(a0 + (a1 - a0) * (k + 0.5) / n)
        b.box((cx + r * math.cos(a), y, cz + r * math.sin(a)), (length, t, t), sw, rot=rot_y(-(90 + math.degrees(a))))


def _half_disc(b, cx, cy, z, r, a0, a1, n, d, sw, stagger=False):
    """A flat fan in the XY plane: half a disc from angle a0 to a1. `stagger` makes each slice 0.002 deeper than the
    last, so no two slices share a face or the apex (a clean, consistently wound mesh)."""
    pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)),
            cy + r * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]
    if not stagger:
        b.fan_z(z, (cx, cy), pts, d, sw)
        return
    for k in range(n):
        b.fan_z(z, (cx, cy), pts[k:k + 2], d + 0.002 * k, sw)


def _ring_front(b, c, r, t, d, sw, segments=12):
    """A ring standing up and facing the front (-Z): wheels, a valve wheel, a cubby door's rim."""
    b.b.ring(RB.p(*c), r, t, d, sw, segments=segments, bevel=False, rot=(math.pi / 2, "X"))


def _ring_flat(b, c, r, t, h, sw, segments=12):
    """A ring lying flat: basin rims, a bed's plush rim, a chair's leg ring."""
    b.b.ring(RB.p(*c), r, t, h, sw, segments=segments, bevel=False)


def _mushroom(b, x, y, z, s, cap="shirt_red"):
    """A little toadstool standing on y: a cream stem and a cap with one white spot."""
    b.cyl((x, y + 0.1 * s, z), 0.06 * s, 0.22 * s, "offwhite", segments=8)
    b.cyl((x, y + 0.25 * s, z), 0.17 * s, 0.11 * s, cap, r2=0.05 * s, segments=10)
    b.ball((x - 0.05 * s, y + 0.27 * s, z - 0.1 * s), 0.035 * s, "offwhite")


def _rubber_duck(b, x, y, z, s, sw):
    """A rubber duck sitting on y, looking toward -Z."""
    b.ball((x, y + 0.2 * s, z + 0.03 * s), 0.27 * s, sw, scale=(1.0, 0.75, 1.2))
    b.ball((x, y + 0.46 * s, z - 0.12 * s), 0.17 * s, sw)
    b.box((x, y + 0.43 * s, z - 0.3 * s), (0.15 * s, 0.06 * s, 0.12 * s), "fur_orange")
    for sx in (-1, 1):
        b.cyl((x + sx * 0.075 * s, y + 0.51 * s, z - 0.28 * s), 0.03 * s, 0.03 * s, "fur_black", axis="Z", segments=6)
    b.ball((x, y + 0.33 * s, z + 0.33 * s), 0.08 * s, sw, scale=(1.0, 1.3, 1.0))


def _leaves(b, pts):
    """Leaf clumps (x, y, z, r), alternating light and dark green."""
    for i, (x, y, z, r) in enumerate(pts):
        b.ball((x, y, z), r, ("leaf_green", "leaf_dark")[i % 2])


# Alley -----------------------------------------------------------------------------------------------------------

CRATE = 1.2


def _milk_crate(b, x, y0, sw, faces=("front", "left", "right")):
    """A plastic milk crate CRATE on a side, with a handle slot and three slots on each face that shows."""
    h = CRATE / 2
    b.span((x - h, y0, -h), (x + h, y0 + CRATE, h), sw)
    holes = ((-0.25, 0.25, 0.88, 1.04), (-0.4, -0.22, 0.2, 0.7), (-0.09, 0.09, 0.2, 0.7), (0.22, 0.4, 0.2, 0.7))
    for f in faces:
        for u0, u1, v0, v1 in holes:
            if f == "front":
                b.span((x + u0, y0 + v0, -h - 0.01), (x + u1, y0 + v1, -h + 0.01), HOLE)
            else:
                sx = -1 if f == "left" else 1
                b.span((x + sx * (h - 0.01), y0 + v0, u0), (x + sx * (h + 0.01), y0 + v1, u1), HOLE)


def build_milk_crate_stools(mat):
    """Two milk crate stools with cushions and a two-crate table between them, a board, a mug and a little plant."""
    b = RB()
    for x, sw, cushion in ((-1.3, "shirt_red", "blush"), (1.3, "sign_teal", "mint")):
        _milk_crate(b, x, 0, sw)
        b.cyl((x, CRATE + 0.11, 0), 0.6, 0.26, cushion, segments=14)                           # a round seat pad
        b.cyl((x, CRATE + 0.25, 0), 0.08, 0.04, "offwhite", segments=8)
    _milk_crate(b, 0, 0, "shirt_blue")
    _milk_crate(b, 0, CRATE, "rarity_legend")
    top = 2 * CRATE + 0.09
    b.span((-0.7, top - 0.1, -0.7), (0.7, top, 0.7), "caramel_wood")
    b.cyl((0.25, top + 0.15, -0.15), 0.16, 0.32, "offwhite", segments=10)                     # mug
    b.cyl((0.25, top + 0.31, -0.15), 0.13, 0.02, "choco", segments=10)
    _ring_front(b, (0.42, top + 0.16, -0.15), 0.09, 0.04, 0.05, "offwhite", segments=8)
    b.cyl((-0.3, top + 0.11, 0.2), 0.15, 0.24, "terracotta", segments=8)                     # plant
    _leaves(b, ((-0.3, top + 0.3, 0.2, 0.13), (-0.38, top + 0.36, 0.12, 0.1), (-0.22, top + 0.38, 0.28, 0.1)))
    return [b.finalize("CatCafe_Decor_MilkCrateStools", mat)]


def _record(b, r, label):
    """A record facing the room round (0, 0, 0): a black disc, a label and spindle standing 0.02 proud, an
    off-centre sticker on the label and a pale sheen across the grooves, so a turn reads."""
    b.cyl((0, 0, 0), r, 0.03, "fur_black", axis="Z", segments=14)
    b.cyl((0, 0, 0), 0.33 * r, 0.07, label, axis="Z", segments=10)
    b.box((0, 0.06 * r / 0.36, -0.045), (0.05, 0.1 * r / 0.36, 0.02), "offwhite")
    b.cyl((0, 0, 0), 0.02, 0.15, "metal", axis="Z", segments=6)
    b.box((0, -0.66 * r, 0), (0.035, 0.36 * r, 0.07), "fur_pewter")


def build_retro_jukebox(mat):
    """An arched jukebox with cat ears: neon tubes round the arch, a lit window where a record turns under a tone arm
    with two more records above it, bubble tubes up the front corners, a selector, a coin slot, a gold-framed speaker
    grille with a medallion, inlaid sides and a chrome kick strip. Legendary, Alley."""
    name = "CatCafe_Decor_RetroJukebox"
    b, glow, glass = RB(), RB(), RB()
    W, D, H = 1.2, 0.65, 3.3                                   # half width, half depth, the arch's centre height
    zf = -D
    b.span((-W - 0.05, 0, -D - 0.07), (W + 0.05, 0.24, D + 0.07), "dark_wood")
    b.span((-W + 0.02, 0.06, -D - 0.1), (W - 0.02, 0.15, -D - 0.07), "metal")               # kick strip
    b.span((-W, 0.24, -D), (W, H - 0.01, D), "caramel_wood")
    b.cyl((0, H, 0), W, 2 * D, "caramel_wood", axis="Z", segments=16)
    for sx in (-1, 1):                                                                         # inlaid sides
        b.span((sx * W, 0.6, -0.45), (sx * (W + 0.03), 2.9, 0.45), "fur_toffee")
        a_ = 58 if sx > 0 else 122                                                             # cat ears
        pts = [(1.08 * math.cos(math.radians(a_ + d)), H + 1.08 * math.sin(math.radians(a_ + d))) for d in (-12, 12)]
        tip = (1.72 * math.cos(math.radians(a_ - sx * 4)), H + 1.72 * math.sin(math.radians(a_ - sx * 4)))
        b.fan_z(0.0, tip, pts, 0.36, "caramel_wood")
        cx, cy = (tip[0] + pts[0][0] + pts[1][0]) / 3, (tip[1] + pts[0][1] + pts[1][1]) / 3
        inner = [(cx + 0.55 * (px - cx), cy + 0.55 * (py - cy)) for px, py in (tip, *pts)]
        glow.fan_z(-0.19, inner[0], inner[1:], 0.02, "neon_pink")
    _arc(b, 0, H, zf - 0.02, 1.13, 0, 180, 12, 0.1, 0.04, "gold_mid")                     # gold trim
    _arc(glow, 0, H, zf - 0.03, 0.98, 0, 180, 12, 0.12, 0.06, "neon_pink")                  # neon arches
    _arc(glow, 0, H, zf - 0.03, 0.8, 0, 180, 10, 0.1, 0.06, "sign_teal")
    for sx, liquid in ((-1, "neon_pink"), (1, "sign_teal")):                                   # bubble tubes
        x = sx * 0.98
        b.cyl((x, 0.5, zf - 0.08), 0.1, 0.1, "gold_mid", segments=8)
        b.cyl((x, H - 0.05, zf - 0.08), 0.1, 0.1, "gold_mid", segments=8)
        b.cyl((x, (0.55 + H - 0.1) / 2, zf - 0.08), 0.08, H - 0.65, "glass", segments=8)
        glow.cyl((x, (0.5 + H - 0.05) / 2, zf - 0.08), 0.04, H - 0.55, liquid, segments=6)
        for k, y in enumerate((0.9, 1.45, 2.05, 2.6)):
            glow.ball((x + 0.05 * (-1) ** k, y, zf - 0.08), 0.03, "offwhite")
        glow.span((sx * 0.8 - 0.05, H - 0.95, zf - 0.06), (sx * 0.8 + 0.05, H, zf), "sign_teal")
    _half_disc(glow, 0, H, zf - 0.012, 0.7, 0, 180, 8, 0.02, "lamp_warm", stagger=True)     # the lit window
    glow.span((-0.7, H - 0.9, zf - 0.02), (0.7, H + 0.05, zf), "lamp_warm")
    for x, lab in ((-0.4, "pastel_butter"), (0.4, "mint")):                                    # records waiting
        b.cyl((x, H + 0.3, zf - 0.035), 0.17, 0.03, "fur_black", axis="Z", segments=12)
        b.cyl((x, H + 0.3, zf - 0.06), 0.06, 0.02, lab, axis="Z", segments=8)
    b.cyl((0.6, H - 0.72, zf - 0.07), 0.07, 0.1, "metal", axis="Z", segments=8)               # the tone arm
    _rod(b, (0.6, H - 0.72, zf - 0.125), (0.3, H - 0.2, zf - 0.125), 0.04, "metal")
    b.box((0.29, H - 0.17, zf - 0.122), (0.08, 0.1, 0.054), "fur_charcoal")
    _half_disc(glass, 0, H, zf - 0.16, 0.72, 0, 180, 8, 0.02, "glass", stagger=True)
    glass.span((-0.72, H - 0.92, zf - 0.17), (0.72, H + 0.05, zf - 0.15), "glass")
    b.span((-0.75, H - 1.28, zf - 0.02), (0.75, H - 1.02, zf), "offwhite")                  # the selector
    for k in range(8):
        x = -0.6 + k * 0.17
        b.span((x - 0.05, H - 1.22, zf - 0.05), (x + 0.05, H - 1.08, zf - 0.01), ("shirt_red", "rarity_legend")[k % 2])
    b.span((0.35, H - 1.62, zf - 0.02), (0.65, H - 1.38, zf), "gold_mid")                   # coin slot
    b.span((0.47, H - 1.58, zf - 0.03), (0.53, H - 1.42, zf - 0.01), HOLE)
    b.span((-0.8, 0.5, zf - 0.02), (0.8, 1.6, zf), "choco")                                # speaker grille
    for k in range(5):
        x = -0.6 + k * 0.3
        b.span((x - 0.05, 0.55, zf - 0.05), (x + 0.05, 1.55, zf - 0.01), "gold_mid")
    for y0, y1 in ((0.44, 0.5), (1.6, 1.66)):
        b.span((-0.9, y0, zf - 0.04), (0.9, y1, zf), "gold_dark")
    for sx in (-1, 1):
        b.span((sx * 0.79, 0.5, zf - 0.04), (sx * 0.86, 1.6, zf), "gold_dark")
    b.cyl((0, 1.05, zf - 0.07), 0.17, 0.04, "gold_light", axis="Z", segments=12)
    b.cyl((0, 1.05, zf - 0.1), 0.08, 0.02, "neon_pink", axis="Z", segments=8)
    rec = RB()
    _record(rec, 0.36, "shirt_red")
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat), glass.finalize(name + "_Glass", mat),
            rec.finalize(name + "_Record_Spin", mat, location=(0, H - 0.25, zf - 0.07))]


def _jar(b, glow, x, y0, z, lid):
    """A glass jar standing on y0 with a warm bulb inside and a lid."""
    b.cyl((x, y0 + 0.21, z), 0.2, 0.42, "glass", segments=10)
    b.cyl((x, y0 + 0.45, z), 0.21, 0.08, lid, segments=10)
    glow.cyl((x, y0 + 0.31, z), 0.08, 0.26, "lamp_warm", segments=8)                      # hangs from the lid


def build_jar_lights(mat):
    """Fairy lights in jam jars hung from a wooden frame on twine, two more on a crate, leaves along the beam."""
    name = "CatCafe_Decor_JarLights"
    b, glow = RB(), RB()
    for sx in (-1, 1):
        b.span((sx * 1.5 - 0.1, 0, -0.1), (sx * 1.5 + 0.1, 3.9, 0.1), "dark_wood")
        b.span((sx * 1.5 - 0.12, 0, -0.5), (sx * 1.5 + 0.12, 0.15, 0.5), "dark_wood")
    b.span((-1.75, 3.88, -0.12), (1.75, 4.1, 0.12), "caramel_wood")
    lids = ("metal", "shirt_red", "metal", "rarity_legend", "metal")
    for (x, y0), lid in zip(((-1.05, 2.3), (-0.52, 1.9), (0.0, 2.55), (0.52, 2.0), (1.05, 2.4)), lids):
        b.span((x - 0.015, y0 + 0.48, -0.015), (x + 0.015, 3.89, 0.015), "cream")
        _jar(b, glow, x, y0, 0, lid)
    b.span((-0.65, 0, -0.4), (0.65, 0.7, 0.4), "caramel_wood")
    for y in (0.22, 0.47):
        b.span((-0.66, y, -0.41), (0.66, y + 0.06, 0.41), "dark_wood")
    _jar(b, glow, -0.3, 0.69, 0, "shirt_red")
    _jar(b, glow, 0.3, 0.69, 0, "metal")
    _leaves(b, ((-1.3, 4.12, 0.02, 0.15), (-0.45, 4.14, -0.04, 0.13), (0.55, 4.12, 0.03, 0.16), (1.3, 4.13, -0.02, 0.13),
                (-1.6, 3.7, -0.12, 0.1), (1.6, 3.6, -0.12, 0.1)))
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]


# Park ------------------------------------------------------------------------------------------------------------


def build_picnic_table_set(mat):
    """An A-frame picnic table with its benches, a red checked cloth, a picnic basket and a lattice pie."""
    b = RB()
    for k in range(3):                                                                    # planks
        z0 = -0.6 + k * 0.41
        b.span((-1.8, 2.3, z0), (1.8, 2.42, z0 + 0.38), "caramel_wood")
    for sz in (-1, 1):
        b.span((-1.8, 1.32, sz * 0.78), (1.8, 1.46, sz * 1.22), "caramel_wood")            # benches
    for sx in (-1.25, 1.25):
        for sz in (-1, 1):
            _rod(b, (sx, 0, sz * 1.15), (sx, 2.31, sz * 0.3), 0.18, "dark_wood")
        b.span((sx - 0.09, 1.2, -1.2), (sx + 0.09, 1.32, 1.2), "dark_wood")
        b.span((sx - 0.09, 2.18, -0.6), (sx + 0.09, 2.3, 0.6), "dark_wood")
    cx0, cx1, cz0, cz1, top = -1.45, 1.45, -0.63, 0.63, 2.44
    b.span((cx0, top - 0.03, cz0), (cx1, top, cz1), "offwhite")                              # the cloth
    for sz in (-1, 1):
        b.span((cx0, 2.12, sz * 0.63), (cx1, top, sz * 0.65), "offwhite")
    cw, ch = (cx1 - cx0) / 10, (cz1 - cz0) / 4
    for i in range(10):
        for j in range(4):
            if (i + j) % 2 == 0:
                x0, x1 = max(cx0 + i * cw, cx0 + 0.01), min(cx0 + (i + 1) * cw, cx1 - 0.01)
                z0, z1 = max(cz0 + j * ch, cz0 + 0.01), min(cz0 + (j + 1) * ch, cz1 - 0.01)
                b.span((x0, top - 0.005, z0), (x1, top + 0.01, z1), "shirt_red")
        if i % 2 == 1:
            x0, x1 = max(cx0 + i * cw, cx0 + 0.01), min(cx0 + (i + 1) * cw, cx1 - 0.01)
            b.span((x0, 2.13, -0.66), (x1, top - 0.01, -0.645), "shirt_red")
    b.span((0.5, top - 0.01, -0.15), (1.2, 2.8, 0.25), "caramel_wood")                       # basket
    for y in (2.56, 2.68):
        b.span((0.49, y, -0.16), (1.21, y + 0.04, 0.26), "kibble")
    b.span((0.6, 2.79, -0.08), (1.1, 2.83, 0.18), "shirt_red")
    _arc(b, 0.85, 2.82, 0.05, 0.3, 0, 180, 6, 0.06, 0.06, "dark_wood")
    b.cyl((-0.75, top + 0.06, -0.1), 0.3, 0.12, "terracotta", r2=0.36, segments=12)          # pie
    b.cyl((-0.75, top + 0.14, -0.1), 0.32, 0.05, "treat_tan", segments=12)
    for a in (45, -45):
        b.box((-0.75, top + 0.17, -0.1), (0.56, 0.03, 0.06), "fur_orange_dark", rot=rot_y(a))
    return [b.finalize("CatCafe_Decor_PicnicTableSet", mat)]


def _swimming_duckling(b, a_deg, rad, sw="pastel_butter"):
    """A duckling on the water at angle a (degrees; 0 is +X, 90 is +Z) and radius rad round (0, 0, 0), facing the
    way a positive turn about +Y carries it, so it swims beak first."""
    a = math.radians(a_deg)
    c = Vector((rad * math.cos(a), 0.05, rad * math.sin(a)))
    f = Vector((math.sin(a), 0, -math.cos(a)))
    side = Vector((f.z, 0, -f.x))
    up = Vector((0, 1, 0))
    b.ball(tuple(c), 0.17, sw, scale=(1.05, 0.7, 1.05))
    h = c + f * 0.12 + up * 0.15
    b.ball(tuple(h), 0.11, sw)
    b.box(tuple(h + f * 0.11 - up * 0.02), (0.09, 0.04, 0.08), "fur_orange",
          rot=rot_y(math.degrees(math.atan2(f.x, f.z))))
    for s in (-1, 1):
        b.ball(tuple(h + f * 0.08 + side * (0.06 * s) + up * 0.03), 0.025, "fur_black")
    b.ball(tuple(c - f * 0.16 + up * 0.07), 0.06, sw, scale=(1.0, 1.3, 1.0))


def build_duck_fountain(mat):
    """A park fountain: a stepped plinth, a round basin banded with blue and white tiles under a moulded rim, four
    globe lamps on the rim, a banded column and a scalloped bowl that spills over at three sides, and on top a duck
    in a gold crown spouting an arc into the basin, where three ducklings paddle round the column. Legendary,
    Park."""
    name = "CatCafe_Decor_DuckFountain"
    b, wat, glow, ducks = RB(), RB(), RB(), RB()
    b.cyl((0, 0.06, 0), 1.32, 0.12, "paving_sand", segments=16)                              # plinth and basin
    b.cyl((0, 0.42, 0), 1.15, 0.6, "cream", segments=16)
    for k in range(16):
        a = 11.25 + 22.5 * k
        t = math.radians(a)
        b.box((1.155 * math.cos(t), 0.4, 1.155 * math.sin(t)), (0.492, 0.24, 0.07),
              ("pastel_sky", "offwhite")[k % 2], rot=rot_y(90 - a))
    _ring_flat(b, (0, 0.79, 0), 1.24, 0.24, 0.14, "offwhite", segments=16)
    b.cyl((0, 0.73, 0), 1.03, 0.02, "pastel_sky", segments=16)
    wat.cyl((0, 0.77, 0), 1.03, 0.04, WATER, segments=16)
    for a in (45, 135, 225, 315):                                                             # globe lamps
        t = math.radians(a)
        x, z = 1.12 * math.cos(t), 1.12 * math.sin(t)
        b.cyl((x, 0.89, z), 0.08, 0.06, "dumpster_green", segments=8)
        b.cyl((x, 1.15, z), 0.04, 0.6, "dumpster_green", segments=6)
        b.cyl((x, 1.47, z), 0.07, 0.04, "gold_mid", segments=8)
        glow.ball((x, 1.58, z), 0.11, "lamp_warm")
        b.cyl((x, 1.71, z), 0.09, 0.06, "dumpster_green", r2=0.02, segments=8)
    b.cyl((0, 0.81, 0), 0.36, 0.16, "offwhite", segments=10)                                 # the column
    b.cyl((0, 1.31, 0), 0.25, 0.9, "cream", segments=10)
    for y in (1.15, 1.55):
        b.cyl((0, y, 0), 0.28, 0.06, "pastel_sky", segments=10)
    b.cyl((0, 1.9, 0), 0.3, 0.32, "cream", r2=0.8, segments=12)                              # the scalloped bowl
    for k in range(10):
        t = math.radians(36 * k)
        b.ball((0.78 * math.cos(t), 2.06, 0.78 * math.sin(t)), 0.15, "offwhite", scale=(1.0, 0.45, 1.0))
    wat.cyl((0, 2.05, 0), 0.7, 0.03, WATER, segments=12)
    for a in (0, 90, 180):                                                                    # the overflow
        t = math.radians(a)
        pts = [((0.84 + 0.12 * s) * math.cos(t), 2.02 - 1.23 * s * s, (0.84 + 0.12 * s) * math.sin(t))
               for s in (0.0, 0.4, 0.7, 1.0)]
        for p0, p1 in zip(pts, pts[1:]):
            _rod(wat, p0, p1, 0.05, WATER)
    b.ball((0, 2.36, 0.08), 0.42, "pastel_butter", scale=(1.0, 0.8, 1.25))                  # the duck
    b.ball((0, 2.84, -0.2), 0.28, "pastel_butter")
    b.box((0, 2.8, -0.5), (0.26, 0.1, 0.22), "fur_orange")
    for sx in (-1, 1):
        e = Vector((sx * 0.48, 0.26, -0.84)).normalized()
        _disc_on(b, tuple(Vector((0, 2.84, -0.2)) + e * 0.28 * 0.89), tuple(e), 0.05, 0.072, "fur_black")
        b.ball((sx * 0.38, 2.41, 0.12), 0.2, "fur_golden", scale=(0.4, 0.7, 1.2))
    b.ball((0, 2.58, 0.56), 0.14, "pastel_butter", scale=(1.0, 1.4, 1.0))
    b.cyl((0, 3.1, -0.2), 0.14, 0.08, "gold_mid", segments=10)                                # its crown
    for k in range(5):
        t = math.radians(90 + 72 * k)
        b.b.pyramid(RB.p(0.1 * math.cos(t), 3.13, -0.2 + 0.1 * math.sin(t)), 0.08, 0.11, "gold_light")
    b.ball((0, 3.1, -0.33), 0.035, "rarity_mythic")
    pts = [(0, 2.78 - 1.99 * t * t, -0.6 - 0.35 * t) for t in (0.0, 0.2, 0.4, 0.55, 0.7, 0.85, 1.0)]
    for p0, p1 in zip(pts, pts[1:]):                                                         # the beak's arc
        _rod(wat, p0, p1, 0.07, WATER)
    for dx, dz in ((0.12, -0.97), (-0.12, -0.97), (0.0, -1.0)):
        wat.ball((dx, 0.81, dz), 0.06, WATER)
    for a in (90, 210, 330):                                                                  # paddling round
        _swimming_duckling(ducks, a, 0.68)
    return [b.finalize(name, mat), wat.finalize(name + "_Water", mat), glow.finalize(name + "_Glow", mat),
            ducks.finalize(name + "_Ducklings_Spin", mat, location=(0, 0.79, 0))]


def _limb(b, p0, p1, r0, r1, sw, segments=8):
    """A round limb from p0 (radius r0) to p1 (radius r1): a trunk, a branch, a twig."""
    a, c = Vector(p0), Vector(p1)
    d = c - a
    turn = Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix()
    b.b.cyl(RB.p(*((a + c) / 2)), r0, d.length, sw, segments=segments, bevel=False, rot=RB._rot(turn), radius2=r1)


def _disc_on(b, c, n, r, t, sw, segments=8):
    """A flat disc t thick centred on c, its faces toward the direction n (Roblox axes): a painted flower."""
    turn = Vector((0, 1, 0)).rotation_difference(Vector(n).normalized()).to_matrix()
    b.b.cyl(RB.p(*c), r, t, sw, segments=segments, bevel=False, rot=RB._rot(turn))


def _paper_lantern(b, glow, drop, r, cat=False, paper="lamp_warm"):
    """A round paper lantern hanging `drop` below its hook at (0, 0, 0): a red cord, dark caps, the glowing paper on
    `glow` and a tassel with a gold bead. `cat` adds ears and two eyes (the cafe's own lantern)."""
    b.span((-0.016, -drop, -0.016), (0.016, 0.03, 0.016), "shirt_red")
    top = -drop - 0.035
    b.cyl((0, top, 0), 0.13, 0.07, "dark_wood", segments=10)
    cy, ry = top - 0.03 - 0.9 * r, 0.9 * r
    glow.ball((0, cy, 0), r, paper, scale=(1, 0.9, 1))
    bottom = cy - ry + 0.02
    b.cyl((0, bottom, 0), 0.12, 0.07, "dark_wood", segments=10)
    b.cyl((0, bottom - 0.16, 0), 0.035, 0.28, "shirt_red", segments=6)
    b.cyl((0, bottom - 0.33, 0), 0.06, 0.08, "gold_mid", segments=8)
    if cat:
        for sx in (-1, 1):
            x = sx * 0.63 * r
            ys = cy + ry * math.sqrt(1 - (x / r) ** 2)
            glow.b.pyramid(RB.p(x, ys - 0.05, 0), 0.15, 0.2, paper)
            e = Vector((sx * 0.3, 0.05 / 0.9, -1.0)).normalized()          # out through the paper, 0.22 r deep
            out = Vector((e.x * r, e.y * ry, e.z * r))
            n = Vector((e.x / r, e.y / ry, e.z / r)).normalized()
            c = Vector((0, cy, 0)) + out * 0.89 + n * 0.005
            _disc_on(b, tuple(c), tuple(n), 0.04, 0.22 * r + 0.01, "fur_black", segments=6)


def _wind_chime(b, drop):
    """A small wind chime hanging `drop` below its hook: a wooden disc, four gold tubes, a clapper and a pink paper
    strip for the wind to catch. Sound-Agent's chime plays when it is used."""
    b.span((-0.012, -drop, -0.012), (0.012, 0.03, 0.012), "offwhite")
    top = -drop - 0.025
    b.cyl((0, top, 0), 0.12, 0.05, "dark_wood", segments=10)
    for k, ln in enumerate((0.44, 0.38, 0.32, 0.27)):
        a = math.radians(45 + 90 * k)
        b.cyl((0.075 * math.cos(a), top - 0.015 - ln / 2, 0.075 * math.sin(a)), 0.022, ln, "gold_light", segments=6)
    b.span((-0.008, top - 0.5, -0.008), (0.008, top - 0.02, 0.008), "offwhite")
    b.cyl((0, top - 0.3, 0), 0.045, 0.03, "gold_mid", segments=8)
    b.span((-0.07, top - 0.78, -0.008), (0.07, top - 0.49, 0.008), "fur_rose")


def build_blossom_tree(mat):
    """A cherry blossom on a wooden stand: a cobalt pot banded in cream with painted blossoms and gold rims, a
    twisting trunk with roots in the moss, a cloud of blossom in three pinks with white highlights, two paper
    lanterns (one with cat ears) and a wind chime hanging from the branches, petals fallen round the pot.
    VFX-Agent (F89 2c): the petals drifting down fall from the child Model `_Canopy`; the lanterns and the chime are
    child Models `_LanternL_Swing`, `_LanternR_Swing` and `_Chime_Swing` with their pivots on the hooks, the
    lanterns' glowing paper nested inside them as `_Glow`, so the effects code can swing them (every Part
    anchored, nothing welded)."""
    name = "CatCafe_Decor_BlossomTree"
    b, canopy = RB(), RB()
    # the stand
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((sx * 0.78 - 0.1, 0, sz * 0.78 - 0.1), (sx * 0.78 + 0.1, 0.2, sz * 0.78 + 0.1), "dark_wood")
    b.span((-0.95, 0.18, -0.95), (0.95, 0.3, 0.95), "caramel_wood")
    # the pot: a gold foot, cobalt glaze in two tiers round a cream band, a gold rim, soil and moss
    b.cyl((0, 0.355, 0), 0.56, 0.13, "gold_mid", segments=16)
    b.cyl((0, 0.6, 0), 0.66, 0.38, "galaxy_blue", segments=16)
    b.cyl((0, 0.91, 0), 0.72, 0.26, "offwhite", segments=16)
    b.cyl((0, 1.19, 0), 0.78, 0.32, "galaxy_blue", segments=16)
    b.cyl((0, 1.39, 0), 0.86, 0.1, "gold_mid", segments=16)
    b.cyl((0, 1.455, 0), 0.78, 0.05, "choco", segments=16)
    for k in range(8):                                                                  # blossoms on the band
        a = math.radians(22.5 + 45 * k)
        n = (math.sin(a), 0, -math.cos(a))
        _disc_on(b, (0.722 * n[0], 0.91, 0.722 * n[2]), n, 0.085, 0.03, ("fur_strawberry", "fur_rose")[k % 2], 6)
        _disc_on(b, (0.74 * n[0], 0.91, 0.74 * n[2]), n, 0.03, 0.03, "gold_mid", 6)
    for x, z, r, sw in ((0.38, -0.3, 0.2, "leaf_green"), (-0.42, 0.22, 0.17, "fur_moss"), (0.3, 0.38, 0.15, "leaf_green"),
                        (-0.12, -0.36, 0.13, "fur_moss")):
        b.ball((x, 1.47, z), r, sw, scale=(1.2, 0.6, 1.0))
    b.ball((-0.3, 1.49, -0.42), 0.08, "concrete", scale=(1.25, 0.7, 1.0))
    # the trunk, its roots and branches
    trunk = ((0.0, 1.3, 0.0, 0.26), (0.16, 2.25, 0.04, 0.22), (-0.06, 3.05, -0.03, 0.18), (0.1, 3.85, 0.02, 0.15),
             (-0.05, 4.6, 0.0, 0.11))
    for (x0, y0, z0, r0), (x1, y1, z1, r1) in zip(trunk, trunk[1:]):
        _limb(b, (x0, y0, z0), (x1, y1, z1), r0, r1, "dark_wood")
    for x, y, z, r in trunk[1:4]:
        b.ball((x, y, z), r * 1.04, "dark_wood")
    for rx, rz in ((0.44, -0.16), (-0.42, -0.2), (0.05, 0.44)):
        _limb(b, (0, 1.56, 0), (rx, 1.47, rz), 0.1, 0.05, "dark_wood", segments=6)
    for p0, p1, r0, r1 in (((-0.06, 3.05, -0.03), (-0.85, 3.6, -0.05), 0.1, 0.08),
                           ((-0.85, 3.6, -0.05), (-1.5, 3.95, 0.0), 0.08, 0.055),
                           ((0.1, 2.6, 0.02), (0.9, 3.3, 0.0), 0.11, 0.085),
                           ((0.9, 3.3, 0.0), (1.45, 3.9, 0.02), 0.085, 0.055),
                           ((0.1, 3.85, 0.02), (-0.7, 4.5, 0.1), 0.08, 0.06),
                           ((0.1, 3.85, 0.02), (0.75, 4.4, -0.05), 0.08, 0.06),
                           ((-0.06, 3.05, -0.03), (0.3, 3.85, -0.7), 0.06, 0.04)):
        _limb(b, p0, p1, r0, r1, "dark_wood", segments=6)
    b.ball((-0.85, 3.6, -0.05), 0.085, "dark_wood")
    b.ball((0.9, 3.3, 0.0), 0.09, "dark_wood")
    # the blossom: deep pinks underneath, paler on top, a few white highlights in front
    clouds = ((-1.45, 4.2, 0.1, 0.48, "fur_strawberry"), (-0.75, 4.05, -0.15, 0.5, "fur_bubblegum"),
              (0.05, 4.1, 0.2, 0.55, "fur_strawberry"), (0.8, 4.0, -0.1, 0.5, "fur_bubblegum"),
              (1.5, 4.15, 0.1, 0.45, "fur_strawberry"),
              (-1.2, 4.75, -0.05, 0.6, "fur_bubblegum"), (-0.4, 4.85, 0.15, 0.68, "fur_rose"),
              (0.45, 4.8, -0.05, 0.66, "fur_bubblegum"), (1.25, 4.7, 0.1, 0.58, "fur_rose"),
              (-0.75, 5.4, 0.05, 0.55, "fur_rose"), (0.1, 5.55, -0.05, 0.6, "fur_rose"),
              (0.85, 5.35, 0.1, 0.5, "fur_bubblegum"), (-0.25, 5.95, 0.05, 0.42, "fur_rose"),
              (0.45, 5.9, 0.0, 0.38, "fur_rose"),
              (-1.0, 4.45, -0.55, 0.36, "fur_rose"), (0.3, 4.05, -0.55, 0.35, "fur_rose"),
              (-0.15, 4.95, -0.5, 0.38, "fur_rose"), (0.95, 4.65, -0.55, 0.34, "fur_rose"),
              (0.5, 5.4, -0.5, 0.32, "fur_rose"), (-0.6, 4.6, 0.6, 0.45, "fur_strawberry"),
              (0.7, 4.9, 0.6, 0.45, "fur_bubblegum"))
    for x, y, z, r, sw in clouds:
        canopy.ball((x, y, z), r, sw, scale=(1.0, 0.85, 0.9))
    for k, (host, dx, dy) in enumerate(((14, -0.3, 0.3), (14, 0.35, -0.2), (15, 0.0, 0.25), (16, -0.25, 0.35),
                                        (16, 0.4, -0.15), (17, 0.1, 0.3), (18, 0.0, 0.2), (9, 0.0, 0.5),
                                        (4, 0.45, 0.2), (0, -0.45, 0.25))):
        x, y, z, r, _ = clouds[host]                       # a white blossom set into the front of a cloud
        d = Vector((dx, dy, -1.0)).normalized()
        sc = Vector((1.0, 0.85, 0.9))
        c = Vector((x, y, z)) + Vector(tuple(d[i] * sc[i] * r * 0.84 for i in range(3)))
        canopy.ball(tuple(c), 0.13, ("offwhite", "fur_vanilla")[k % 2])
    # petals fallen on the stand and the soil
    petals = [(0.84 * math.cos(math.radians(a)), 0.305, 0.84 * math.sin(math.radians(a)))
              for a in (200, 235, 268, 300, 335, 20, 140)]
    petals += [(0.15, 1.485, -0.45), (-0.5, 1.485, -0.1)]
    for i, (x, y, z) in enumerate(petals):
        ox, oz = (1, 1) if i % 2 else (-1, 1)
        b.b.fan(RB.p(x, y, z), (0, 0), [(0.13 * ox, 0.04 * oz), (0.05 * ox, 0.13 * oz)], 0.02,
                ("fur_rose", "fur_strawberry")[i % 2])
    # the hanging pieces, each built round its hook and finalized there (the hook is the pivot)
    objs = [b.finalize(name, mat), canopy.finalize(name + "_Canopy", mat)]
    for side, hook, drop, r, cat, paper in (("L", (-1.3, 3.8, -0.02), 0.45, 0.3, True, "lamp_warm"),
                                            ("R", (1.3, 3.69, 0.01), 0.32, 0.26, False, "fur_strawberry")):
        sw, gl = RB(), RB()
        _paper_lantern(sw, gl, drop, r, cat, paper)
        objs += [sw.finalize(f"{name}_Lantern{side}_Swing", mat, location=hook),
                 gl.finalize(f"{name}_Lantern{side}_Glow", mat, location=hook)]
    ch = RB()
    _wind_chime(ch, 0.2)
    objs.append(ch.finalize(name + "_Chime_Swing", mat, location=(0.156, 3.48, -0.43)))
    return objs


# Neighbourhood ---------------------------------------------------------------------------------------------------


def build_porch_swing(mat):
    """A mint porch swing hung on chains from a white A-frame, with a cushion and two pillows."""
    b = RB()
    for sx in (-1.85, 1.85):
        for sz in (-1, 1):
            _rod(b, (sx, 0, sz * 1.1), (sx, 4.35, sz * 0.05), 0.2, "offwhite")
        b.span((sx - 0.08, 1.55, -0.72), (sx + 0.08, 1.7, 0.72), "offwhite")
    b.span((-2.0, 4.3, -0.13), (2.0, 4.55, 0.13), "offwhite")
    b.span((-1.32, 1.18, -0.52), (1.32, 1.3, 0.34), "sign_teal")                              # seat frame
    for z0 in (-0.5, -0.22, 0.06):
        b.span((-1.3, 1.29, z0), (1.3, 1.42, z0 + 0.24), "mint")
    for y, z in ((1.65, 0.36), (1.95, 0.4), (2.25, 0.44)):
        b.box((0, y, z), (2.5, 0.22, 0.08), "mint", rot=rot_x(7))
    for sx in (-1, 1):
        _rod(b, (sx * 1.3, 1.3, 0.3), (sx * 1.3, 2.6, 0.46), 0.12, "sign_teal")
        b.span((sx * 1.3 - 0.07, 1.9, -0.5), (sx * 1.3 + 0.07, 2.0, 0.38), "sign_teal")
        b.span((sx * 1.3 - 0.06, 1.41, -0.5), (sx * 1.3 + 0.06, 1.91, -0.4), "sign_teal")
        _rod(b, (sx * 1.25, 4.3, -0.05), (sx * 1.25, 1.99, -0.45), 0.05, "concrete_dark")
        _rod(b, (sx * 1.25, 4.3, 0.05), (sx * 1.25, 2.6, 0.46), 0.05, "concrete_dark")
    b.span((-1.2, 1.41, -0.48), (1.2, 1.6, 0.28), "blush")
    b.box((-0.65, 1.86, 0.2), (0.6, 0.55, 0.18), "pastel_butter", rot=rot_x(10))
    b.box((0.7, 1.86, 0.2), (0.6, 0.55, 0.18), "offwhite", rot=rot_x(10))
    return [b.finalize("CatCafe_Decor_PorchSwing", mat)]


def _cat_scoop_sign(b, r=0.38):
    """The parlour's turning sign, built round its foot at (0, 0, 0): a candy pole, a waffle cone and a strawberry
    scoop that is a cat's head (ears, eyes, a nose) with sprinkles."""
    b.cyl((0, 0.395, 0), 0.05, 0.81, "offwhite", segments=8)
    for y in (0.25, 0.55):
        b.cyl((0, y, 0), 0.056, 0.1, "blush", segments=8)
    b.cyl((0, 1.05, 0), 0.04, 0.5, "treat_tan", r2=0.3, segments=10)
    b.cyl((0, 1.33, 0), 0.32, 0.06, "fur_caramel", segments=10)
    cy = 1.36 + 0.8 * r
    b.ball((0, cy, 0), r, "fur_strawberry")
    for sx in (-1, 1):
        x = sx * 0.55 * r
        b.b.pyramid(RB.p(x, cy + r * math.sqrt(1 - 0.55 ** 2) - 0.06, 0), 0.2, 0.25, "fur_strawberry")
        e = Vector((sx * 0.32, 0.12, -1.0)).normalized()
        _disc_on(b, tuple(Vector((0, cy, 0)) + e * r * 0.89), tuple(e), 0.05, 0.22 * r + 0.01, "fur_black",
                 segments=6)
    nose = Vector((0, -0.08, -1.0)).normalized()
    _disc_on(b, tuple(Vector((0, cy, 0)) + nose * r * 0.89), tuple(nose), 0.045, 0.22 * r + 0.01, "nose_pink",
             segments=6)
    for k, (az, el) in enumerate(((40, 30), (110, 55), (160, 20), (215, 45), (290, 25), (330, 60))):
        d = Vector((math.cos(math.radians(az)) * math.cos(math.radians(el)), math.sin(math.radians(el)),
                    math.sin(math.radians(az)) * math.cos(math.radians(el))))
        c = Vector((0, cy, 0))
        _limb(b, tuple(c + d * r * 0.75), tuple(c + d * r * 1.12), 0.022, 0.022,
              ("mint", "pastel_butter", "fur_white", "pastel_sky")[k % 4], segments=4)


def build_ice_cream_counter(mat):
    """An ice cream parlour counter: pink and white candy stripes with a scalloped mint trim and a painted cone
    plaque, a lit glass case of five tubs (two with their scoops in), a rack of waffle cones, sprinkle jars and a
    service bell, a striped awning on candy posts with a scalloped valance and marquee bulbs, and on top a cone
    sign whose scoop is a cat, turning slowly. Legendary, Neighbourhood."""
    name = "CatCafe_Decor_IceCreamCounter"
    b, glass, glow = RB(), RB(), RB()
    # the counter
    b.span((-1.78, 0, -0.62), (1.78, 0.22, 0.6), "mint")
    b.span((-1.7, 0.22, -0.55), (1.7, 2.06, 0.55), "offwhite")
    w = 3.36 / 8
    for k in range(0, 8, 2):
        x0 = -1.68 + k * w
        b.span((x0, 0.22, -0.57), (x0 + w, 2.0, -0.55), "blush")
    for sx in (-1, 1):                                                                         # the ends
        for z0 in (-0.36, 0.14):
            b.span((sx * 1.72, 0.22, z0), (sx * 1.7, 2.0, z0 + 0.22), "blush")
    b.span((-1.73, 1.98, -0.6), (1.73, 2.08, 0.58), "mint")                                  # the trim band
    for k in range(8):
        b.cyl((-1.5 + 3.0 * k / 7, 1.98, -0.58), 0.15, 0.03, "mint", axis="Z", segments=10)
    b.span((-1.86, 2.08, -0.7), (1.86, 2.2, 0.64), "caramel_wood")                           # the top
    # the painted cone plaque
    b.cyl((0, 1.1, -0.595), 0.5, 0.05, "pastel_sky", axis="Z", segments=14)
    b.cyl((0, 1.1, -0.63), 0.43, 0.02, "fur_vanilla", axis="Z", segments=14)
    b.fan_z(-0.65, (0, 0.76), [(-0.14, 1.12), (0.14, 1.12)], 0.02, "treat_tan")
    for x, y, sw in ((-0.12, 1.2, "blush"), (0.12, 1.2, "mint"), (0.0, 1.42, "choco")):
        b.cyl((x, y, -0.665), 0.12, 0.03, sw, axis="Z", segments=10)
    # the lit case: a tray, five tubs, scoops left in two, a glass hood with a light strip under its lid
    b.span((-1.66, 2.2, -0.05), (1.66, 2.3, 0.6), "metal")
    for k, (x, sw) in enumerate(zip((-1.28, -0.64, 0.0, 0.64, 1.28),
                                    ("blush", "mint", "pastel_butter", "choco", "pastel_lilac"))):
        b.cyl((x, 2.41, 0.28), 0.25, 0.22, "offwhite", segments=10)
        b.ball((x, 2.53, 0.28), 0.25, sw, scale=(1.0, 0.55, 1.0))
        if k in (1, 3):
            _rod(b, (x + 0.06, 2.6, 0.22), (x + 0.2, 2.86, 0.12), 0.035, "metal")
            b.ball((x + 0.05, 2.6, 0.23), 0.06, "metal")
    glass.box((0, 2.665, 0.025), (3.3, 0.8, 0.04), "glass", rot=rot_x(25.9))
    glass.span((-1.65, 3.02, 0.18), (1.65, 3.06, 0.62), "glass")
    for sx in (-1, 1):
        glass.span((sx * 1.63, 2.3, -0.08), (sx * 1.67, 3.02, 0.62), "glass")
    b.span((-1.68, 3.06, 0.15), (1.68, 3.12, 0.64), "metal")                                 # the hood's lid
    glow.span((-1.5, 2.98, 0.3), (1.5, 3.02, 0.46), "lamp_warm")
    # on the counter: a rack of waffle cones, sprinkle jars and a service bell
    b.span((-1.7, 2.2, -0.62), (-1.22, 2.3, -0.24), "metal")
    for k, (dx, dz) in enumerate(((-0.12, -0.52), (0.1, -0.5), (-0.01, -0.34))):
        b.cyl((-1.46 + dx, 2.42, dz), 0.025, 0.36, "treat_tan", r2=0.11, segments=8)
        if k == 1:
            b.ball((-1.46 + dx, 2.64, dz), 0.12, "blush")
    for x, sw in ((0.5, "neon_pink"), (0.78, "mint"), (1.06, "rarity_legend")):
        b.cyl((x, 2.32, -0.42), 0.09, 0.24, "glass", segments=8)
        b.cyl((x, 2.275, -0.42), 0.08, 0.17, sw, segments=8)                                 # sprinkles, set in the top
        b.cyl((x, 2.465, -0.42), 0.095, 0.05, "pastel_sky", segments=8)
    b.cyl((1.48, 2.215, -0.42), 0.13, 0.03, "gold_dark", segments=10)
    b.ball((1.48, 2.28, -0.42), 0.1, "gold_light", scale=(1.0, 0.8, 1.0))
    b.cyl((1.48, 2.37, -0.42), 0.02, 0.06, "gold_dark", segments=6)
    # the awning on candy posts: a striped canopy, a scalloped valance and marquee bulbs
    for sx in (-1, 1):
        b.cyl((sx * 1.74, 3.25, 0.52), 0.06, 2.1, "offwhite", segments=8)
        for y in (2.7, 3.3, 3.9):
            b.cyl((sx * 1.74, y, 0.52), 0.066, 0.14, "blush", segments=8)
    b.span((-1.84, 4.24, 0.44), (1.84, 4.36, 0.6), "caramel_wood")
    z0, y0, z1, y1 = 0.52, 4.36, -0.78, 3.86
    slope = math.degrees(math.atan2(y0 - y1, z0 - z1))
    ln = math.hypot(z0 - z1, y0 - y1)
    mid = ((z0 + z1) / 2, (y0 + y1) / 2)
    b.box((0, mid[1] + 0.02, mid[0]), (3.66, 0.05, ln), "offwhite", rot=rot_x(-slope))
    sw_ = 3.72 / 8
    for k in range(1, 8, 2):
        b.box((-1.86 + (k + 0.5) * sw_, mid[1] + 0.02, mid[0]), (sw_, 0.11, ln + 0.06), "blush", rot=rot_x(-slope))
    b.span((-1.8, 3.7, -0.81), (1.8, 3.88, -0.76), "blush")                                  # the valance
    for k in range(9):
        b.cyl((-1.68 + 3.36 * k / 8, 3.7, -0.765), 0.15, 0.03, ("offwhite", "pastel_sky")[k % 2], axis="Z",
              segments=10)
    for k in range(10):
        glow.ball((-1.71 + 3.42 * k / 9, 3.79, -0.81), 0.045, ("lamp_warm", "sparkle")[k % 2])
    # the turning sign's collar on the beam; the sign is built round its foot and finalized there (its pivot)
    b.cyl((0, 4.39, 0.52), 0.1, 0.06, "caramel_wood", segments=8)
    sign = RB()
    _cat_scoop_sign(sign)
    return [b.finalize(name, mat), glass.finalize(name + "_Glass", mat), glow.finalize(name + "_Glow", mat),
            sign.finalize(name + "_Sign_Spin", mat, location=(0, 4.42, 0.52))]


def _wheel(b, x, y, r):
    _ring_front(b, (x, y, 0), r, 0.12, 0.12, "fur_black", segments=14)
    _ring_front(b, (x, y, 0), r - 0.12, 0.05, 0.08, "metal", segments=14)
    b.cyl((x, y, 0), 0.08, 0.16, "metal", axis="Z", segments=8)
    for a in (0, 45, 90, 135):
        b.box((x, y, 0), (2 * (r - 0.17), 0.025, 0.025), "metal", rot=rot_z(a))


def build_bicycle_planter(mat):
    """An old mint bicycle on its stand with a basket of flowers on the front and a crate of flowers on the back."""
    b = RB()
    R_, F_ = (1.12, 0.75), (-1.12, 0.75)
    for x, y in (R_, F_):
        _wheel(b, x, y, 0.75)
    B, S, H, Hb = (0.2, 0.72), (0.5, 1.75), (-0.78, 1.95), (-0.86, 1.55)
    frame = ((B, S, 0.1), (S, R_, 0.07), (B, R_, 0.09), (B, Hb, 0.1), ((0.43, 1.45), (-0.8, 1.72), 0.09),
             (Hb, H, 0.12), (Hb, F_, 0.09))
    for p0, p1, t in frame:
        _rod(b, (p0[0], p0[1], 0), (p1[0], p1[1], 0), t, "mint")
    for cx, a0 in ((F_[0], 25), (R_[0], 15)):                                              # fenders
        _arc(b, cx, 0.75, 0, 0.84, a0, 180 - a0 + 10, 7, 0.06, 0.18, "offwhite")
    b.cyl((B[0], B[1], 0), 0.1, 0.18, "concrete_dark", axis="Z", segments=8)
    _ring_front(b, (B[0], B[1], -0.11), 0.22, 0.05, 0.04, "concrete_dark", segments=10)
    _rod(b, (B[0], B[1], -0.12), (B[0] + 0.22, B[1] - 0.22, -0.14), 0.05, "concrete_dark")
    b.span((B[0] + 0.1, B[1] - 0.27, -0.3), (B[0] + 0.34, B[1] - 0.2, -0.14), "fur_black")
    _rod(b, (B[0], B[1], 0.05), (0.05, 0.0, 0.35), 0.05, "metal")                           # kickstand
    _rod(b, (H[0], H[1], 0), (H[0] + 0.03, 2.12, 0), 0.08, "metal")
    b.box((-0.73, 2.12, 0), (0.08, 0.08, 0.9), "metal")
    for sz in (-1, 1):
        b.box((-0.73, 2.12, sz * 0.47), (0.11, 0.11, 0.2), "choco")
    b.cyl((-0.73, 2.2, 0.28), 0.06, 0.05, "gold_mid", segments=8)
    b.box((0.55, 1.84, 0), (0.5, 0.12, 0.3), "choco")                                       # saddle
    b.span((-1.5, 1.6, -0.3), (-0.95, 2.05, 0.3), "caramel_wood")                           # front basket
    for y in (1.72, 1.88):
        b.span((-1.51, y, -0.31), (-0.94, y + 0.05, 0.31), "kibble")
    _rod(b, (-1.2, 1.6, 0), (-1.0, 1.05, 0), 0.04, "metal")
    for x, y, z, r, sw in ((-1.35, 2.15, -0.12, 0.15, "blush"), (-1.1, 2.18, 0.1, 0.14, "pastel_butter"),
                           (-1.3, 2.12, 0.16, 0.13, "pastel_lilac"), (-1.08, 2.12, -0.16, 0.13, "offwhite")):
        b.ball((x, y, z), r, sw)
    _leaves(b, ((-1.22, 2.08, 0.0, 0.17), (-1.48, 1.95, -0.22, 0.1), (-1.52, 1.75, -0.2, 0.09), (-1.5, 1.55, -0.25, 0.08)))
    b.span((0.7, 1.6, -0.25), (1.45, 1.64, 0.25), "metal")                                   # rear rack
    _rod(b, (1.42, 1.6, 0), (R_[0], R_[1], 0), 0.04, "metal")
    b.span((0.75, 1.63, -0.3), (1.5, 2.07, 0.3), "caramel_wood")
    b.span((0.74, 1.8, -0.31), (1.51, 1.85, 0.31), "dark_wood")
    for x, z, sw in ((0.9, -0.12, "fur_strawberry"), (1.15, 0.1, "pastel_butter"), (1.35, -0.1, "offwhite")):
        b.ball((x, 2.15, z), 0.14, sw)
    _leaves(b, ((1.1, 2.1, -0.15, 0.15), (1.38, 2.1, 0.15, 0.13)))
    return [b.finalize("CatCafe_Decor_BicyclePlanter", mat)]


def build_mailbox_planter(mat):
    """A round-topped blue mailbox on a post in a planter box, its door down and flowers spilling out, flag up."""
    b = RB()
    b.span((-0.65, 0, -0.65), (0.65, 0.6, 0.65), "caramel_wood")
    b.span((-0.7, 0.58, -0.7), (0.7, 0.66, 0.7), "dark_wood")
    b.span((-0.6, 0.65, -0.6), (0.6, 0.68, 0.6), "choco")
    for x, y, z, r, sw in ((-0.4, 0.82, -0.4, 0.16, "blush"), (0.42, 0.8, -0.38, 0.15, "pastel_butter"),
                           (0.4, 0.82, 0.42, 0.15, "pastel_lilac"), (-0.4, 0.8, 0.4, 0.14, "offwhite")):
        b.ball((x, y, z), r, sw)
    _leaves(b, ((0.0, 0.78, -0.45, 0.18), (-0.45, 0.76, 0.0, 0.17), (0.45, 0.76, 0.02, 0.17), (0.02, 0.76, 0.45, 0.16)))
    b.span((-0.12, 0.6, -0.12), (0.12, 1.95, 0.12), "offwhite")
    b.span((-0.32, 1.95, -0.55), (0.32, 2.35, 0.55), "shirt_blue")
    b.cyl((0, 2.35, 0), 0.32, 1.1, "shirt_blue", axis="Z", segments=12)
    b.span((-0.26, 2.0, -0.565), (0.26, 2.35, -0.55), HOLE)                                  # the open front
    _half_disc(b, 0, 2.35, -0.5575, 0.26, 0, 180, 6, 0.015, HOLE)
    b.span((-0.32, 1.55, -0.62), (0.32, 1.95, -0.56), "shirt_blue")                         # the door, hanging down
    _half_disc(b, 0, 1.55, -0.59, 0.32, 180, 360, 6, 0.06, "shirt_blue")
    b.span((-0.08, 1.38, -0.635), (0.08, 1.46, -0.615), "offwhite")
    b.span((0.33, 2.0, 0.1), (0.39, 2.8, 0.16), "shirt_red")                                # the flag, up
    b.span((0.33, 2.55, 0.16), (0.39, 2.8, 0.5), "shirt_red")
    b.cyl((0.37, 2.1, 0.13), 0.07, 0.06, "offwhite", axis="X", segments=8)
    for x, y, z, r, sw in ((-0.12, 2.15, -0.62, 0.12, "blush"), (0.13, 2.25, -0.6, 0.11, "pastel_butter"),
                           (0.0, 2.05, -0.66, 0.1, "offwhite"), (-0.14, 1.62, -0.67, 0.07, "fur_strawberry")):
        b.ball((x, y, z), r, sw)
    _leaves(b, ((-0.2, 1.98, -0.66, 0.12), (0.22, 2.02, -0.64, 0.12), (-0.15, 1.8, -0.66, 0.08),
                (-0.08, 1.45, -0.67, 0.08), (0.06, 1.3, -0.66, 0.07)))
    return [b.finalize("CatCafe_Decor_MailboxPlanter", mat)]


# Woods -----------------------------------------------------------------------------------------------------------


def _stump(b, x, z, r, h, ridges=4, roots=3):
    """A sawn log standing on the floor: bark, a light cut top with a ring, bark ridges and roots."""
    b.cyl((x, h / 2, z), r, h, "dark_wood", segments=10)
    b.cyl((x, h + 0.01, z), r - 0.05, 0.04, "treat_tan", segments=10)
    b.cyl((x, h + 0.03, z), (r - 0.05) * 0.55, 0.03, "caramel_wood", segments=10)
    for k in range(ridges):
        a = math.radians(30 + 360 * k / ridges)
        b.box((x + (r - 0.01) * math.cos(a), h * 0.48, z + (r - 0.01) * math.sin(a)), (0.1, h * 0.8, 0.06), "choco",
              rot=rot_y(90 - math.degrees(a)))
    for k in range(roots):
        a = math.radians(70 + 360 * k / roots)
        b.wedge((x + (r + 0.1) * math.cos(a), 0.15, z + (r + 0.1) * math.sin(a)), (0.26, 0.3, 0.32), "dark_wood",
                rot=rot_y(math.degrees(math.atan2(-math.cos(a), -math.sin(a)))))


def build_log_stools(mat):
    """Three sawn log stools of different heights, moss on the tallest and toadstools at its foot."""
    b = RB()
    _stump(b, -1.22, 0.0, 0.5, 1.45)
    _stump(b, 0.13, -0.1, 0.45, 1.15)
    _stump(b, 1.38, 0.05, 0.52, 1.75)
    b.ball((1.58, 1.79, 0.22), 0.26, "leaf_green", scale=(1.0, 0.35, 1.0))
    _mushroom(b, 1.83, 0, -0.42, 1.0)
    _mushroom(b, 1.63, 0, -0.62, 0.7, "fur_orange")
    b.span((-1.54, 1.47, -0.3), (-0.9, 1.6, 0.3), "mint")                                   # a knitted pad
    return [b.finalize("CatCafe_Decor_LogStools", mat)]


def _firefly_jar(b, glow, drop):
    """A glass jar of fireflies hanging `drop` below its hook at (0, 0, 0): a twine cord, a wire bail, a brass lid
    and base, and a sprig of grass inside with a glowing firefly on each tip (the fireflies are on `glow`)."""
    top = -drop - 0.14                                                                      # the lid's top
    b.cyl((0, (top + 0.14 + 0.03) / 2, 0), 0.014, 0.03 - top - 0.14, "fur_hazel", segments=6)
    _arc(b, 0, top, 0, 0.14, 4, 176, 7, 0.025, 0.025, "metal")                             # the wire bail
    b.cyl((0, top - 0.03, 0), 0.16, 0.06, "brass", segments=10)
    b.cyl((0, top - 0.26, 0), 0.2, 0.4, "glass", segments=10)
    b.cyl((0, top - 0.48, 0), 0.205, 0.04, "brass", segments=10)
    floor = top - 0.46
    for k, (dx, dz, h) in enumerate(((-0.07, 0.03, 0.24), (0.06, -0.05, 0.3), (0.01, 0.07, 0.19), (0.09, 0.06, 0.15),
                                     (-0.05, -0.07, 0.2))):
        _limb(b, (0, floor - 0.005, 0), (dx, floor + h, dz), 0.018, 0.01, ("leaf_green", "leaf_dark")[k % 2],
              segments=5)
        glow.ball((dx, floor + h + 0.01, dz), 0.042, ("sparkle", "lamp_warm")[k % 2])


def build_hollow_log_booth(mat):
    """A giant hollow log lying on its side with its front cut away: bark with ridges and a knot, pale sawn ends with a
    growth ring, a plank floor, a bench with cushions and a plaid throw, a stump side table with a mug and two books,
    a jar of fireflies that swings from the roof and fairy lights along the front lip; moss, toadstools and a sapling
    on top. The opening faces the room (-Z). Legendary, Woods."""
    name = "CatCafe_Decor_HollowLogBooth"
    b, lights = RB(), RB()
    L, R, TB, RI = 4.0, 1.75, 0.2, 1.25                    # length, outer radius, bark, inner radius
    zc, yc = -0.45, R + 0.005                              # the log's axis: its back 0.1 off the wall
    n, step = 15, 14.0
    a0 = -90 - 1.5 * step                                  # a facet sits flat on the floor; the lips at -111 and 99

    def at(r, t, off=0.0):
        """(z, y) at radius r and angle t (radians; 0 is the back, 90 the top) on the log's end, `off` along it."""
        return (zc + r * math.cos(t) - off * math.sin(t), yc + r * math.sin(t) + off * math.cos(t))

    def chord(r):
        return 2 * r * math.sin(math.radians(step / 2)) * 1.06

    angles = [math.radians(a0 + step * (k + 0.5)) for k in range(n)]
    for k, t in enumerate(angles):
        rot = rot_x(-math.degrees(t))
        e = 0.01 * (k % 2)                     # every other facet's end stands 0.01 proud: no two ends share a plane
        z, y = at(R - TB / 2, t)
        b.box((0, y, z), (L + 0.28 + 2 * e, chord(R), TB), "dark_wood", rot=rot)               # bark
        z, y = at((R - TB + RI) / 2, t)
        b.box((0, y, z), (L, chord(R - TB), R - TB - RI), "treat_tan", rot=rot)               # the hollow
        z2, y2 = at(1.42, t)
        for sx in (-1, 1):                                                                     # the sawn ends
            b.box((sx * (L / 2 + 0.05 + e / 2), y, z), (0.1 + e, chord(R - TB) * 0.995, R - TB - RI - 0.006),
                  "fur_oat", rot=rot)
            b.box((sx * (L / 2 + 0.1125 + 1.5 * e), y2, z2), (0.025 + e, chord(1.44), 0.04), "caramel_wood", rot=rot)
    for t_deg, off, x0, x1 in ((92, 0.08, -1.9, 0.5), (78, -0.07, -0.3, 2.05), (50, 0.05, -2.05, -0.4),
                               (22, -0.06, 0.2, 1.95), (-104, -0.06, -2.0, -0.2), (-104, 0.07, 0.4, 2.0)):
        t = math.radians(t_deg)
        z, y = at(R + 0.03, t, off)
        b.box(((x0 + x1) / 2, y, z), (x1 - x0, 0.12, 0.08), "choco", rot=rot_x(-t_deg))
    for t_deg, x, r in ((64, 1.25, 0.17), (-104, 1.3, 0.13)):                                  # knots
        t = math.radians(t_deg)
        z, y = at(R + 0.02, t)
        _disc_on(b, (x, y, z), (0, math.sin(t), math.cos(t)), r, 0.1, "choco", segments=8)
        z, y = at(R + 0.05, t)
        _disc_on(b, (x, y, z), (0, math.sin(t), math.cos(t)), r * 0.45, 0.06, "fur_toffee", segments=6)
    # inside: a plank floor, a bench with cushions and a throw
    yf = 0.72
    zf0, zf1 = -1.12, zc + 0.73
    w = (zf1 - zf0) / 4
    for k in range(4):
        b.span((-L / 2, yf - 0.14, zf0 + k * w + 0.006), (L / 2, yf, zf0 + (k + 1) * w - 0.006),
               ("caramel_wood", "fur_caramel")[k % 2])
    b.span((-1.75, yf, -0.35), (1.75, 1.12, 0.6), "fur_toffee")                               # the bench
    b.span((-1.65, 1.12, -0.3), (1.65, 1.3, 0.5), "mint")
    for x, sw, tilt in ((-1.1, "pastel_butter", 14), (0.0, "blush", 10), (1.1, "pastel_lilac", 16)):
        b.box((x, 1.64, 0.45), (0.95, 0.72, 0.22), sw, rot=rot_x(tilt))
    b.span((0.45, 1.3, -0.36), (1.25, 1.34, 0.25), "fur_rust_red")                             # a plaid throw
    b.span((0.45, 0.88, -0.38), (1.25, 1.34, -0.35), "fur_rust_red")
    for x in (0.65, 1.05):
        b.span((x - 0.07, 1.292, -0.388), (x + 0.07, 1.348, 0.258), "pastel_butter")
        b.span((x - 0.07, 0.872, -0.388), (x + 0.07, 1.32, -0.352), "pastel_butter")
    # a stump side table with a mug and two books
    sx_, sz_, sr, sh = 1.35, -0.75, 0.25, 0.46
    b.cyl((sx_, yf + sh / 2, sz_), sr, sh, "dark_wood", segments=10)
    b.cyl((sx_, yf + sh + 0.015, sz_), sr - 0.04, 0.03, "fur_oat", segments=10)
    b.cyl((sx_, yf + sh + 0.035, sz_), 0.1, 0.02, "caramel_wood", segments=8)
    ty = yf + sh + 0.03
    b.cyl((sx_ + 0.09, ty + 0.07, sz_ - 0.06), 0.075, 0.14, "offwhite", segments=8)
    b.span((sx_ + 0.16, ty + 0.03, sz_ - 0.075), (sx_ + 0.2, ty + 0.11, sz_ - 0.045), "offwhite")
    b.cyl((sx_ + 0.09, ty + 0.144, sz_ - 0.06), 0.06, 0.008, "choco", segments=8)
    b.box((sx_ - 0.08, ty + 0.03, sz_ + 0.06), (0.26, 0.06, 0.2), "shirt_blue", rot=rot_y(12))
    b.box((sx_ - 0.07, ty + 0.085, sz_ + 0.05), (0.22, 0.05, 0.17), "bowl_red", rot=rot_y(-8))
    # the hook the firefly jar swings from, and the fairy lights' pegs and swags under the front lip
    hook = (-0.7, 2.93, -0.3)
    b.span((-0.75, 2.93, -0.35), (-0.65, 3.03, -0.25), "dark_wood")
    pegs = (-1.9, -0.65, 0.65, 1.9)
    lz, ly = -0.6, 2.97
    for x in pegs:
        b.span((x - 0.03, ly - 0.02, lz - 0.03), (x + 0.03, 3.03, lz + 0.03), "dark_wood")
    bulbs = ("lamp_warm", "fur_strawberry", "mint", "pastel_butter")
    k = 0
    for x0, x1 in zip(pegs, pegs[1:]):
        mid = ((x0 + x1) / 2, ly - 0.24, lz)
        _rod(b, (x0, ly, lz), mid, 0.02, "dark_wood")
        _rod(b, mid, (x1, ly, lz), 0.02, "dark_wood")
        for f in (0.25, 0.5, 0.75):
            x = x0 + (x1 - x0) * f
            y = ly - 0.24 * (1 - abs(2 * f - 1))
            lights.ball((x, y - 0.045, lz), 0.055, bulbs[k % len(bulbs)])
            k += 1
    # on top: a moss blanket, toadstools and a sapling
    def top_y(z):
        return yc + math.sqrt(R * R - (z - zc) ** 2)

    for x, z, r in ((-1.25, -0.35, 0.5), (0.35, -0.55, 0.42), (1.45, -0.2, 0.36), (-0.4, 0.1, 0.3)):
        b.ball((x, top_y(z) + 0.02, z), r, ("leaf_green", "leaf_dark")[int(x > 0)], scale=(1.0, 0.32, 0.9))
    _mushroom(b, 1.55, top_y(-0.45) + 0.05, -0.45, 1.3)
    _mushroom(b, 1.85, top_y(-0.25) + 0.04, -0.25, 0.9, "fur_orange")
    base = (-1.55, top_y(-0.4) - 0.02, -0.4)
    tip = (-1.75, base[1] + 0.75, -0.5)
    _limb(b, base, tip, 0.06, 0.03, "fur_hazel", segments=6)
    _limb(b, (-1.62, base[1] + 0.35, -0.43), (-1.4, base[1] + 0.62, -0.42), 0.03, 0.02, "fur_hazel", segments=5)
    _leaves(b, ((-1.75, tip[1] + 0.06, -0.5, 0.16), (-1.9, tip[1] - 0.06, -0.42, 0.13),
                (-1.62, tip[1] - 0.02, -0.6, 0.12), (-1.38, base[1] + 0.66, -0.42, 0.12)))
    _leaves(b, ((-1.95, 0.08, -0.97, 0.2), (1.95, 0.08, -0.97, 0.17)))                     # tufts at the foot
    for x, drop in ((1.55, 0.62), (-1.4, 0.8)):                                            # ivy over the top lip
        lip = at(R - 0.05, math.radians(99))
        _limb(b, (x, lip[1], lip[0] - 0.02), (x + 0.04, lip[1] - drop, lip[0] - 0.05), 0.022, 0.016, "leaf_dark",
              segments=5)
        _leaves(b, tuple((x + 0.04 * f + 0.05 * (-1) ** k, lip[1] - drop * f, lip[0] - 0.02 - 0.03 * f, 0.085)
                         for k, f in enumerate((0.3, 0.62, 0.95))))
    objs = [b.finalize(name, mat), lights.finalize(name + "_Lights_Glow", mat)]
    jar, flies = RB(), RB()
    _firefly_jar(jar, flies, 0.2)
    objs += [jar.finalize(name + "_Lantern_Swing", mat, location=hook),
             flies.finalize(name + "_Lantern_Glow", mat, location=hook)]
    return objs


def build_lantern_stump(mat):
    """A tree stump holding a lantern with a candle, toadstools round its roots and a tuft of moss."""
    name = "CatCafe_Decor_LanternStump"
    b, glow, glass = RB(), RB(), RB()
    _stump(b, 0, 0, 0.62, 1.3, ridges=5, roots=4)
    b.cyl((0, 1.38, 0), 0.25, 0.08, "concrete_dark", segments=8)
    glass.span((-0.17, 1.4, -0.17), (0.17, 1.92, 0.17), "glass")
    b.cyl((0, 1.53, 0), 0.07, 0.22, "offwhite", segments=8)
    glow.ball((0, 1.72, 0), 0.08, "lamp_warm", scale=(1.0, 1.5, 1.0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.span((sx * 0.18 - 0.03, 1.42, sz * 0.18 - 0.03), (sx * 0.18 + 0.03, 1.9, sz * 0.18 + 0.03), "concrete_dark")
    b.cyl((0, 2.02, 0), 0.3, 0.24, "concrete_dark", r2=0.06, segments=8)
    _ring_front(b, (0, 2.25, 0), 0.12, 0.03, 0.03, "concrete_dark", segments=8)
    _mushroom(b, 0.72, 0, -0.38, 1.0, "fur_orange")
    _mushroom(b, 0.82, 0, 0.08, 0.7)
    _mushroom(b, -0.62, 0, -0.55, 0.85)
    b.ball((-0.5, 0.95, -0.38), 0.22, "leaf_green", scale=(1.0, 0.6, 0.6))
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat), glass.finalize(name + "_Glass", mat)]


def build_mushroom_lamp(mat):
    """A glowing toadstool lamp on a mossy mound: a red stepped cap with white spots, its gills lit warm."""
    name = "CatCafe_Decor_MushroomLamp"
    b, glow = RB(), RB()
    b.cyl((0, 0.12, 0), 1.0, 0.24, "leaf_dark", r2=0.8, segments=14)                        # the mossy mound
    b.ball((0, 0.24, 0), 0.8, "leaf_dark", scale=(1.0, 0.2, 1.0))
    _leaves(b, ((-0.6, 0.3, -0.5, 0.14), (0.7, 0.3, -0.3, 0.13), (0.3, 0.35, 0.6, 0.12)))
    b.cyl((0, 1.25, 0), 0.32, 2.1, "offwhite", r2=0.26, segments=10)
    b.cyl((0, 1.6, 0), 0.4, 0.08, "cream", r2=0.36, segments=10)
    b.cyl((0, 2.45, 0), 1.1, 0.3, "shirt_red", r2=0.95, segments=14)
    b.cyl((0, 2.75, 0), 0.95, 0.3, "shirt_red", r2=0.62, segments=14)
    b.cyl((0, 3.02, 0), 0.62, 0.24, "shirt_red", r2=0.18, segments=14)
    for r, y, angles in ((1.03, 2.45, (200, 260, 320, 20, 140)), (0.8, 2.75, (230, 300, 80))):
        for a in angles:
            t = math.radians(a)
            b.ball((r * math.cos(t), y, r * math.sin(t)), 0.15, "offwhite", scale=(1.0, 0.5, 1.0))
    b.ball((0.05, 3.1, -0.12), 0.13, "offwhite", scale=(1.0, 0.5, 1.0))
    glow.cyl((0, 2.28, 0), 1.0, 0.04, "lamp_warm", segments=14)
    _mushroom(b, 0.62, 0.24, -0.5, 1.5, "fur_orange")
    _mushroom(b, -0.7, 0.24, -0.35, 1.2)
    glow.cyl((0.35, 0.34, -0.72), 0.03, 0.2, "sparkle", segments=6)                         # a tiny glowing one
    glow.cyl((0.35, 0.47, -0.72), 0.1, 0.07, "sparkle", r2=0.03, segments=8)
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]


# Sewer -----------------------------------------------------------------------------------------------------------


def _open_crate(b, x0, x1, y0, y1, sw, inner):
    """A wooden crate on its side, open to the front: a darker back and four walls."""
    t = 0.1
    b.span((x0, y0, 0.4), (x1, y1, 0.5), inner)
    b.span((x0, y0, -0.5), (x0 + t, y1, 0.4), sw)
    b.span((x1 - t, y0, -0.5), (x1, y1, 0.4), sw)
    b.span((x0 + t, y0, -0.5), (x1 - t, y0 + t, 0.4), sw)
    b.span((x0 + t, y1 - t, -0.5), (x1 - t, y1, 0.4), sw)


def build_crate_shelf(mat):
    """Four salvaged crates stacked into shelves: books and yarn, tins and a duck, jars, and a plant whose vine
    hangs down the side."""
    b = RB()
    _open_crate(b, -1.8, -0.05, 0, 1.5, "caramel_wood", "kibble")
    _open_crate(b, 0.15, 1.9, 0, 1.5, "cardboard", "kibble")
    _open_crate(b, -1.8, -0.05, 1.5, 3.0, "cardboard", "kibble")
    _open_crate(b, 0.15, 1.9, 1.5, 3.0, "caramel_wood", "kibble")
    for x0, x1, top, sw in ((-1.6, -1.42, 1.0, "shirt_blue"), (-1.42, -1.24, 0.9, "shirt_green"),
                            (-1.24, -1.06, 1.05, "rarity_epic")):
        b.span((x0, 0.09, -0.3), (x1, top, 0.3), sw)
    b.box((-0.92, 0.5, 0.0), (0.18, 0.85, 0.56), "pastel_butter", rot=rot_z(-15))
    b.ball((-0.42, 0.32, -0.1), 0.22, "blush")
    for x, y, z, sw in ((0.4, 0.27, 0.0, "sign_teal"), (0.85, 0.27, -0.05, "shirt_red"), (0.62, 0.62, 0.0, "pastel_butter")):
        b.cyl((x, y, z), 0.2, 0.35, sw, segments=10)
        b.cyl((x, y, z), 0.205, 0.12, "offwhite", segments=10)
    _rubber_duck(b, 1.4, 0.1, -0.1, 0.8, "pastel_butter")
    for x, lid in ((-1.5, "shirt_red"), (-1.08, "pastel_butter"), (-0.66, "mint")):
        b.cyl((x, 1.81, 0), 0.18, 0.42, "glass", segments=10)
        b.cyl((x, 2.05, 0), 0.19, 0.07, lid, segments=10)
    b.cyl((0.6, 1.79, 0), 0.25, 0.4, "terracotta", r2=0.3, segments=10)
    _leaves(b, ((0.6, 2.1, 0.0, 0.25), (0.42, 2.22, -0.1, 0.16), (0.78, 2.25, 0.05, 0.15)))
    _rubber_duck(b, 1.35, 1.59, -0.1, 0.7, "blush")
    b.cyl((-1.2, 3.14, 0), 0.22, 0.3, "terracotta", segments=10)                             # on top, with a vine
    _leaves(b, ((-1.2, 3.38, 0.0, 0.2), (-1.4, 3.3, -0.12, 0.13), (-1.62, 3.12, -0.15, 0.1), (-1.85, 2.85, -0.2, 0.1),
                (-1.87, 2.55, -0.18, 0.09), (-1.86, 2.25, -0.2, 0.09), (-1.88, 1.95, -0.18, 0.08)))
    return [b.finalize("CatCafe_Decor_CrateShelf", mat)]


def _stadium(b, cx, y0, y1, r, sw, segments=14):
    """A tub-shaped slab from y0 to y1: a box between two round ends centred at x = +-cx. The box keeps 0.003
    inside the ends' rims, so its corners never weld onto a vertex of the ends."""
    b.span((-cx, y0, -r + 0.003), (cx, y1, r - 0.003), sw)
    for sx in (-1, 1):
        b.cyl((sx * cx, (y0 + y1) / 2, 0), r, y1 - y0, sw, segments=segments)


def build_bathtub_sofa(mat):
    """A clawfoot tub made into a sofa: sky blue with a gold band and painted bubbles, a rolled white rim, gold claw
    feet, a tufted seat, three plump cushions and a bolster, a knitted throw over the front. At the tap end a
    bubble bath: water, foam, bubbles and a rubber duck, fed by a brass gooseneck tap, under a brass rain lamp.
    VFX-Agent (F89 2c): the duck is the child Model `_Duck_Bob` (pivot where it floats) and the lamp's face
    `_Lamp_Glow`; Sound-Agent's squeak plays when it is used."""
    name = "CatCafe_Decor_BathtubSofa"
    b, glow, wat, duck = RB(), RB(), RB(), RB()
    CX = 0.9
    _stadium(b, CX, 0.45, 1.0, 0.76, "pastel_sky")                                       # the tub, flaring out
    _stadium(b, CX, 0.98, 1.84, 0.85, "pastel_sky")
    _stadium(b, CX, 0.96, 1.04, 0.87, "gold_mid")                                         # a gold band at the flare
    _stadium(b, CX, 1.82, 1.96, 0.93, "offwhite")                                         # the rolled rim
    for k, (x, y, r) in enumerate(((0.28, 1.48, 0.12), (0.52, 1.24, 0.07), (0.7, 1.6, 0.08), (0.42, 1.74, 0.05),
                                   (0.8, 1.3, 0.06))):                                   # painted bubbles
        b.cyl((x, y, -0.86), r, 0.03, ("offwhite", "fish_belly")[k % 2], axis="Z", segments=10)
    for sx in (-1, 1):                                                                     # claw feet
        for sz in (-1, 1):
            b.span((sx * 1.12 - 0.12, 0.5, sz * 0.62 - 0.1), (sx * 1.12 + 0.12, 0.72, sz * 0.62 + 0.1), "gold_mid")
            _limb(b, (sx * 1.12, 0.55, sz * 0.62), (sx * 1.3, 0.2, sz * 0.72), 0.08, 0.06, "gold_mid")
            b.ball((sx * 1.32, 0.13, sz * 0.74), 0.15, "gold_mid", scale=(1.15, 0.9, 1.15))
            for k in (-1, 0, 1):                                                           # three toes
                a = math.atan2(sz * 0.74, sx * 1.32) + 0.5 * k
                b.cyl((sx * 1.32 + 0.15 * math.cos(a), 0.06, sz * 0.74 + 0.15 * math.sin(a)), 0.05, 0.12,
                      "gold_dark", segments=6)
    # the sofa half: a tufted seat, three cushions on the back, a bolster at the end, a throw over the front
    b.span((-0.9, 1.94, -0.657), (0.0, 2.22, 0.657), "pastel_lilac")
    for x in (-0.9, 0.0):
        b.cyl((x, 2.08, 0), 0.66, 0.28, "pastel_lilac", segments=14)
    for x in (-1.25, -0.65, -0.05):
        for z in (-0.3, 0.12):
            b.cyl((x + (0.3 if z > 0 else 0.0), 2.225, z), 0.045, 0.03, "gold_mid", segments=6)
    for x, sw in ((-0.95, "blush"), (-0.3, "pastel_butter"), (0.35, "mint")):
        b.box((x, 2.62, 0.5), (0.62, 0.82, 0.3), sw, rot=rot_x(14))
        b.cyl((x, 2.64, 0.32), 0.05, 0.04, "offwhite", axis="Z", segments=6)
    b.cyl((-1.36, 2.42, 0.0), 0.2, 0.7, "sign_teal", axis="Z", segments=10)               # bolster
    for sz in (-1, 1):
        b.cyl((-1.36, 2.42, sz * 0.36), 0.15, 0.02, "offwhite", axis="Z", segments=10)
    x0, x1 = -0.75, 0.15                                                                   # the throw
    throw = (((2.22, -0.68), (2.26, -0.2)), ((1.96, -0.7), (2.25, -0.66)), ((1.96, -0.97), (2.0, -0.69)),
             ((1.25, -0.97), (1.99, -0.93)))                                              # (y, z) corners
    for (ya, za), (yb, zb) in throw:
        b.span((x0, ya, za), (x1, yb, zb), "mint")
    for k in (1, 3):                                                                      # two cream stripes
        a, c = x0 + (x1 - x0) * k / 5, x0 + (x1 - x0) * (k + 1) / 5
        for (ya, za), (yb, zb) in throw:
            b.span((a, ya - 0.008, za - 0.008), (c, yb + 0.008, zb + 0.008), "offwhite")
    for k in range(6):
        x = x0 + 0.08 + k * (x1 - x0 - 0.16) / 5
        b.span((x - 0.025, 1.12, -0.96), (x + 0.025, 1.25, -0.94), "offwhite")
    # the bubble bath at the tap end
    wat.cyl((CX, 1.87, 0), 0.75, 0.06, WATER, segments=14)
    for x, z, r in ((1.5, -0.32, 0.17), (1.6, 0.18, 0.16), (1.25, 0.5, 0.15), (1.2, -0.52, 0.14), (1.65, -0.05, 0.13)):
        b.ball((x, 1.92, z), r, "offwhite", scale=(1.0, 0.7, 1.0))
    for x, y, z, r in ((1.5, 2.12, -0.3, 0.09), (1.42, 2.22, -0.18, 0.06), (1.6, 2.08, 0.2, 0.07)):
        b.ball((x, y, z), r, "glass")
    _rubber_duck(duck, 0, 0, 0, 0.55, "pastel_butter")
    # the brass gooseneck tap on the rim and its two handles
    tx = 1.72
    b.cyl((tx, 1.99, 0), 0.12, 0.06, "brass", segments=10)
    b.cyl((tx, 2.35, 0), 0.06, 0.72, "brass", segments=8)
    _arc(b, tx - 0.2, 2.7, 0, 0.2, 0, 180, 7, 0.1, 0.1, "brass")
    b.cyl((tx - 0.4, 2.62, 0), 0.055, 0.16, "brass", segments=8)
    for sz, cap in ((-1, "shirt_blue"), (1, "shirt_red")):
        b.cyl((tx, 2.2, sz * 0.12), 0.04, 0.14, "brass", axis="Z", segments=6)
        b.box((tx, 2.2, sz * 0.2), (0.22, 0.04, 0.04), "brass")
        b.box((tx, 2.2, sz * 0.2), (0.04, 0.22, 0.04), "brass")
        b.cyl((tx, 2.2, sz * 0.23), 0.04, 0.03, cap, axis="Z", segments=6)
    # the rain lamp: a brass stand behind the tap end, its rose over the bath with a glowing face
    lx, lz = 1.7, 1.05
    b.cyl((lx, 0.04, lz), 0.2, 0.08, "brass", segments=12)
    b.cyl((lx, 2.04, lz), 0.055, 3.95, "brass", segments=8)
    b.ball((lx, 4.02, lz), 0.08, "brass")
    _limb(b, (lx, 4.02, lz), (1.25, 3.98, 0.12), 0.055, 0.05, "brass")
    b.cyl((1.25, 3.86, 0.12), 0.06, 0.2, "brass", segments=8)
    b.cyl((1.25, 3.72, 0.12), 0.36, 0.1, "brass", r2=0.12, segments=14)
    glow.cyl((1.25, 3.655, 0.12), 0.33, 0.03, "lamp_warm", segments=14)
    return [b.finalize(name, mat), glow.finalize(name + "_Lamp_Glow", mat), wat.finalize(name + "_Water", mat),
            duck.finalize(name + "_Duck_Bob", mat, location=(1.3, 1.86, 0.02))]


def build_rubber_duck_row(mat):
    """Rubber ducks on parade along a pipe-and-plank shelf, a gold one in the middle; soap, bubbles, a sponge and
    a rolled towel below."""
    b = RB()
    for sx in (-1, 1):
        b.cyl((sx * 1.4, 0.55, 0), 0.07, 1.1, "concrete_dark", segments=8)
        b.cyl((sx * 1.4, 0.03, 0), 0.16, 0.06, "concrete_dark", segments=8)
        b.cyl((sx * 1.4, 0.53, 0), 0.1, 0.16, "concrete_dark", segments=8)
    b.span((-1.7, 1.08, -0.32), (1.7, 1.2, 0.32), "caramel_wood")
    b.span((-1.6, 0.48, -0.28), (1.6, 0.58, 0.28), "caramel_wood")
    ducks = ((-1.25, 0.9, "pastel_butter"), (-0.62, 1.0, "blush"), (0.0, 1.2, "gold_mid"), (0.62, 1.0, "pastel_sky"),
             (1.25, 0.85, "pastel_butter"))
    for x, s, sw in ducks:
        _rubber_duck(b, x, 1.19, 0.0, s, sw)
    b.cyl((0.62, 1.19 + 0.64, -0.12), 0.11, 0.06, "offwhite", segments=8)                    # a sailor hat
    b.cyl((0.62, 1.19 + 0.61, -0.12), 0.115, 0.03, "shirt_blue", segments=8)
    b.span((-1.2, 0.57, -0.15), (-0.75, 0.72, 0.1), "pastel_lilac")
    for x, y, z, r in ((-0.8, 0.86, -0.05, 0.1), (-0.62, 0.98, 0.02, 0.07), (-0.95, 0.95, -0.1, 0.06)):
        b.ball((x, y, z), r, "glass")
    b.span((0.4, 0.57, -0.18), (0.95, 0.77, 0.12), "pastel_butter")
    for x, z in ((0.52, -0.08), (0.7, 0.02), (0.84, -0.06)):
        b.cyl((x, 0.775, z), 0.04, 0.02, "fur_golden", segments=6)
    b.cyl((1.25, 0.7, 0), 0.12, 0.5, "mint", axis="X", segments=10)
    return [b.finalize("CatCafe_Decor_RubberDuckRow", mat)]


def build_pipe_fountain(mat):
    """A teal tiled basin fed by a brass pipe: up, over and down into the water, with a red valve wheel, a gauge
    and a duck floating below."""
    name = "CatCafe_Decor_PipeFountain"
    b, wat = RB(), RB()
    b.cyl((0, 0.3, 0), 0.95, 0.6, "sign_teal", segments=14)
    b.cyl((0, 0.3, 0), 0.96, 0.05, "offwhite", segments=14)
    _ring_flat(b, (0, 0.66, 0), 1.0, 0.18, 0.12, "concrete", segments=14)
    b.cyl((0, 0.61, 0), 0.83, 0.02, "pastel_sky", segments=14)
    wat.cyl((0, 0.65, 0), 0.83, 0.04, WATER, segments=14)
    b.cyl((0, 1.6, 0.55), 0.12, 2.0, "brass", segments=10)
    b.cyl((0, 0.7, 0.55), 0.17, 0.08, "brass", segments=10)
    b.ball((0, 2.6, 0.55), 0.15, "brass")
    b.cyl((0, 2.6, 0.2), 0.12, 0.7, "brass", axis="Z", segments=10)
    b.ball((0, 2.6, -0.15), 0.15, "brass")
    b.cyl((0, 2.42, -0.15), 0.12, 0.36, "brass", segments=10)
    b.cyl((0, 2.22, -0.15), 0.15, 0.06, "brass", segments=10)
    for y in (1.2, 1.95):
        b.cyl((0, y, 0.55), 0.15, 0.08, "bronze", segments=10)
    b.cyl((0, 1.6, 0.4), 0.04, 0.12, "brass", axis="Z", segments=8)                          # valve wheel
    _ring_front(b, (0, 1.6, 0.33), 0.25, 0.05, 0.05, "bowl_red", segments=10)
    for a in (45, -45):
        b.box((0, 1.6, 0.33), (0.44, 0.04, 0.04), "bowl_red", rot=rot_z(a))
    b.cyl((0, 1.6, 0.31), 0.06, 0.06, "bowl_red", axis="Z", segments=8)
    b.cyl((0, 2.25, 0.38), 0.04, 0.12, "brass", axis="Z", segments=8)                         # gauge
    b.cyl((0, 2.25, 0.29), 0.16, 0.06, "offwhite", axis="Z", segments=12)
    _ring_front(b, (0, 2.25, 0.29), 0.18, 0.03, 0.08, "brass", segments=12)
    b.box((0.03, 2.28, 0.255), (0.12, 0.025, 0.01), "shirt_red", rot=rot_z(40))
    wat.cyl((0, 1.45, -0.15), 0.07, 1.54, WATER, segments=8)
    wat.ball((0, 0.69, -0.15), 0.15, WATER, scale=(1.4, 0.4, 1.4))
    for dx, dz in ((0.2, -0.05), (-0.18, -0.25), (0.05, -0.38)):
        wat.ball((dx, 0.74, -0.15 + dz), 0.05, WATER)
    _rubber_duck(b, 0.45, 0.62, -0.42, 0.55, "pastel_butter")
    return [b.finalize(name, mat), wat.finalize(name + "_Water", mat)]


# Classic ---------------------------------------------------------------------------------------------------------


def _bistro_chair(b, cx, face):
    """A bistro chair whose seat centre is at x cx, facing +X when face is 1."""
    b.cyl((cx, 1.42, 0), 0.42, 0.08, "concrete_dark", segments=12)
    b.cyl((cx, 1.5, 0), 0.4, 0.08, "bowl_red", segments=12)
    for a in (45, 135, 225, 315):
        x, z = cx + 0.3 * math.cos(math.radians(a)), 0.3 * math.sin(math.radians(a))
        b.span((x - 0.035, 0, z - 0.035), (x + 0.035, 1.39, z + 0.035), "concrete_dark")
    _ring_flat(b, (cx, 0.55, 0), 0.33, 0.05, 0.04, "concrete_dark", segments=10)
    away = 180 if face > 0 else 0
    for da in (-55, 0, 55):
        a = math.radians(away + da)
        x, z = cx + 0.38 * math.cos(a), 0.38 * math.sin(a)
        b.span((x - 0.035, 1.46, z - 0.035), (x + 0.035, 2.7, z + 0.035), "concrete_dark")
    _arc_flat(b, cx, 2.7, 0, 0.38, away - 62, away + 62, 5, 0.07, "concrete_dark")
    _arc_flat(b, cx, 2.15, 0, 0.38, away - 58, away + 58, 5, 0.05, "concrete_dark")


def build_bistro_set(mat):
    """A little round marble bistro table with a gold edge, two red-cushioned bistro chairs, coffee and a flower."""
    b = RB()
    b.cyl((0, 0.04, 0), 0.42, 0.08, "concrete_dark", segments=12)
    b.cyl((0, 1.2, 0), 0.07, 2.3, "concrete_dark", segments=8)
    b.cyl((0, 2.36, 0), 0.62, 0.08, "offwhite", segments=16)
    b.cyl((0, 2.36, 0), 0.64, 0.04, "brass", segments=16)
    _bistro_chair(b, -1.3, 1)
    _bistro_chair(b, 1.3, -1)
    b.cyl((0.15, 2.55, 0.15), 0.08, 0.3, "mint", r2=0.05, segments=8)
    _rod(b, (0.15, 2.65, 0.15), (0.18, 2.95, 0.15), 0.025, "leaf_green")
    b.ball((0.18, 2.97, 0.15), 0.08, "blush")
    for x, z in ((-0.3, -0.1), (0.25, -0.28)):
        b.cyl((x, 2.41, z), 0.14, 0.02, "offwhite", segments=10)
        b.cyl((x, 2.49, z), 0.08, 0.14, "offwhite", r2=0.1, segments=10)
        b.cyl((x, 2.56, z), 0.085, 0.01, "choco", segments=10)
    return [b.finalize("CatCafe_Decor_BistroSet", mat)]


def build_velvet_booth(mat):
    """A deep red velvet booth with a channel-tufted back shaped like a shell, buttons, brass trim and pillows."""
    b = RB()
    vel, button = "shirt_red", "fur_russet"
    b.span((-1.95, 0, -0.83), (1.95, 0.35, 0.82), "dark_wood")
    b.span((-1.96, 0.33, -0.84), (1.96, 0.37, 0.83), "brass")
    b.span((-1.9, 0.36, -0.78), (1.9, 1.2, 0.47), vel)
    b.cyl((0, 1.08, -0.78), 0.17, 3.8, vel, axis="X", segments=10)
    for x in (-1.0, 0.0, 1.0):
        b.cyl((x, 1.205, -0.23), 0.05, 0.03, button, segments=6)
    for k in range(7):                                           # channels that touch, rising to a shell
        x = -1.62 + 0.54 * k
        t = (k - 3) / 3
        top = 3.0 + 0.8 * (1 - t * t)
        b.cyl((x, (1.2 + top) / 2, 0.65), 0.3, top - 1.2, vel, segments=10)
        b.ball((x, top, 0.65), 0.3, vel)
        for y in (2.0, 2.8):
            if y < top - 0.2:
                b.cyl((x, y, 0.345), 0.05, 0.03, button, axis="Z", segments=6)
    b.box((-1.0, 1.55, 0.12), (0.6, 0.6, 0.2), "pastel_butter", rot=rot_x(12))
    b.box((1.0, 1.55, 0.12), (0.6, 0.6, 0.2), "offwhite", rot=rot_x(12))
    return [b.finalize("CatCafe_Decor_VelvetBooth", mat)]


def build_hanging_plants(mat):
    """Three potted plants in macrame hangers from a wooden frame, vines trailing, one more pot on the low shelf."""
    b = RB()
    for sx in (-1, 1):
        b.span((sx * 1.6 - 0.1, 0, -0.1), (sx * 1.6 + 0.1, 4.4, 0.1), "caramel_wood")
        b.span((sx * 1.6 - 0.12, 0, -0.55), (sx * 1.6 + 0.12, 0.15, 0.55), "dark_wood")
    b.span((-1.8, 4.38, -0.12), (1.8, 4.6, 0.12), "caramel_wood")
    b.span((-1.5, 0.75, -0.35), (1.5, 0.85, 0.35), "caramel_wood")
    for x, py, sw in ((-1.0, 1.75, "terracotta"), (0.0, 2.3, "offwhite"), (1.0, 1.95, "mint")):
        b.ball((x, 4.3, 0), 0.07, "cream")
        _rod(b, (x, 4.3, 0), (x, 3.7, 0), 0.05, "cream")
        b.ball((x, 3.7, 0), 0.08, "cream")
        b.cyl((x, py + 0.25, 0), 0.26, 0.5, sw, r2=0.34, segments=10)
        for a in (90, 210, 330):
            t = math.radians(a)
            rim = (x + 0.35 * math.cos(t), py + 0.45, 0.35 * math.sin(t))
            low = (x + 0.28 * math.cos(t), py + 0.02, 0.28 * math.sin(t))
            _rod(b, (x, 3.7, 0), rim, 0.035, "cream")
            b.ball(tuple((Vector((x, 3.7, 0)) + Vector(rim)) / 2), 0.05, "cream")
            _rod(b, rim, low, 0.035, "cream")
            _rod(b, low, (x, py - 0.2, 0), 0.035, "cream")
        b.cyl((x, py - 0.38, 0), 0.1, 0.3, "cream", r2=0.03, segments=8)
        b.ball((x, py + 0.62, 0), 0.3, "leaf_green", scale=(1.0, 0.7, 1.0))
        b.ball((x - 0.2, py + 0.75, -0.08), 0.18, "leaf_dark")
        for side in (-1, 1):
            for i in range(4):
                b.ball((x + side * 0.36, py + 0.35 - 0.22 * i, -0.12), 0.09, ("leaf_green", "leaf_dark")[i % 2])
    b.ball((0.12, 2.98, -0.2), 0.08, "blush")
    b.cyl((0, 1.05, 0), 0.3, 0.4, "terracotta", r2=0.35, segments=10)
    _leaves(b, ((0, 1.33, 0.0, 0.22), (-0.2, 1.3, -0.12, 0.14), (0.22, 1.3, 0.1, 0.14)))
    return [b.finalize("CatCafe_Decor_HangingPlants", mat)]


def _sisal_post(b, x, z, y0, y1, rings=2):
    b.cyl((x, (y0 + y1) / 2, z), 0.2, y1 - y0, "treat_tan", segments=10)
    for k in range(rings):
        b.cyl((x, y0 + (y1 - y0) * (k + 1) / (rings + 1), z), 0.215, 0.05, "kibble", segments=10)


def _platform(b, x, top, z, r, sw, trim):
    """A carpeted platform whose top is at `top` (the cats' spots stand on it), with a trim band round its edge."""
    b.cyl((x, top - 0.1, z), r, 0.2, sw, segments=14)
    b.cyl((x, top - 0.11, z), r + 0.04, 0.1, trim, segments=14)


# F79 bedtime (data-model 12c; see furniture.TREE_SPOTS): the tower's two sleep spots, best first (the bed on top,
# then the blush platform; the other platforms have a post through them), the perches a cat only hops through, clear
# of their posts, and the floor it sets off from.
TOWER_SPOTS = {"Sleep_1": (0.0, 9.9, 0.1), "Sleep_2": (1.05, 5.2, -0.15),
               "Hop_1": (-0.7, 1.55, -0.85), "Hop_2": (-1.2, 3.2, 0.0), "Hop_3": (0.5, 3.4, -0.5),
               "Hop_4": (-0.85, 6.2, -0.1), "Hop_5": (-1.25, 7.9, -0.55), "Foot": (-0.7, 0.0, -1.8)}


def build_cat_tree_tower(mat):
    """A cat tree nearly to the ceiling: sisal posts, carpeted platforms with trims, a cubby whose dark door shows two
    glowing eyes, a food bowl on the base, two toys and a moon lamp that swing, and a round bed on top with a cat's
    face and ears on its rim. The platforms keep the F79 sleep and hop spots (TOWER_SPOTS). Legendary, Classic."""
    name = "CatCafe_Decor_CatTreeTower"
    b, glow = RB(), RB()
    b.span((-1.5, 0, -1.1), (1.5, 0.3, 1.1), "blush")
    b.span((-1.53, 0.0, -1.13), (1.53, 0.08, 1.13), "pastel_lilac")                          # base trim
    for px in (-0.9, -0.45):                                                                 # paw prints
        b.cyl((px, 0.17, -1.11), 0.08, 0.02, "offwhite", axis="Z", segments=8)
        for dx, dy in ((-0.08, 0.1), (0.0, 0.13), (0.08, 0.1)):
            b.cyl((px + dx, 0.17 + dy - 0.02, -1.11), 0.035, 0.02, "offwhite", axis="Z", segments=6)
    b.cyl((1.0, 0.38, -0.7), 0.2, 0.16, "bowl_red", r2=0.25, segments=10)                     # a food bowl
    b.cyl((1.0, 0.465, -0.7), 0.21, 0.02, "fur_white", segments=10)
    for dx, dz in ((-0.07, 0.02), (0.06, -0.05), (0.02, 0.08)):
        b.ball((1.0 + dx, 0.48, -0.7 + dz), 0.06, "kibble")
    b.ball((-1.15, 0.42, 0.72), 0.14, "fur_rose")                                            # a ball of yarn
    _rod(b, (-1.05, 0.31, 0.64), (-0.55, 0.31, 0.75), 0.025, "fur_rose")
    _sisal_post(b, -0.9, 0.4, 0.3, 3.0, rings=4)
    _platform(b, -0.9, 3.2, 0.3, 0.75, "mint", "offwhite")
    _sisal_post(b, 0.9, -0.2, 0.3, 2.0, rings=2)
    b.span((0.2, 2.0, -0.85), (1.55, 3.3, 0.45), "pastel_lilac")                              # the cubby
    b.cyl((0.88, 2.6, -0.86), 0.39, 0.02, HOLE, axis="Z", segments=12)
    _ring_front(b, (0.88, 2.6, -0.865), 0.44, 0.06, 0.03, "offwhite", segments=12)
    for dx in (-0.08, 0.08):                                                                  # someone's home
        glow.ball((0.88 + dx, 2.64, -0.87), 0.045, "eye_chartreuse", scale=(1.0, 1.25, 1.0))
    b.span((0.15, 3.29, -0.9), (1.6, 3.4, 0.5), "blush")
    b.span((0.12, 3.24, -0.93), (1.63, 3.32, 0.53), "fur_bubblegum")
    for y, z in ((2.45, -0.25), (2.9, 0.15)):                                                 # paw prints
        b.cyl((1.56, y, z), 0.12, 0.02, "offwhite", axis="X", segments=8)
        for dz, dy in ((-0.11, 0.13), (0.0, 0.17), (0.11, 0.13)):
            b.cyl((1.56, y + dy, z + dz), 0.05, 0.02, "offwhite", axis="X", segments=6)
    _sisal_post(b, -0.75, 0.3, 3.2, 6.0, rings=4)
    _platform(b, -0.45, 6.2, 0.15, 0.75, "pastel_butter", "fur_sand")
    _sisal_post(b, 1.0, -0.1, 3.4, 5.0, rings=3)
    _platform(b, 1.05, 5.2, -0.15, 0.72, "blush", "fur_bubblegum")
    _sisal_post(b, -0.3, 0.2, 6.2, 9.6, rings=5)
    # two step pads so no hop rises more than 2.6: a low one off the floor, a high one on a bracket under the bed
    _sisal_post(b, -0.7, -0.85, 0.3, 1.45, rings=1)
    b.cyl((-0.7, 1.5, -0.85), 0.45, 0.1, "pastel_lilac", segments=12)
    dx, dz = -1.25 - (-0.3), -0.55 - 0.2
    b.box((-0.3 + dx / 2, 7.74, 0.2 + dz / 2), (0.16, 0.16, math.hypot(dx, dz)), "treat_tan",
          rot=rot_y(math.degrees(math.atan2(dx, dz))))
    b.cyl((-1.25, 7.85, -0.55), 0.45, 0.1, "pastel_lilac", segments=12)
    b.cyl((0.0, 9.75, 0.1), 0.85, 0.3, "mint", segments=14)                                   # the bed on top
    _ring_flat(b, (0.0, 10.04, 0.1), 0.85, 0.22, 0.3, "blush", segments=14)
    for sx in (-1, 1):
        x = sx * 0.45
        b.fan_z(-0.49, (x, 10.62), [(x - 0.22, 10.15), (x + 0.22, 10.15)], 0.14, "blush")
        b.fan_z(-0.57, (x, 10.5), [(x - 0.11, 10.24), (x + 0.11, 10.24)], 0.02, "nose_pink")
        a = math.radians(sx * 20)                                                             # the bed's face
        n = (math.sin(a), 0, -math.cos(a))
        _disc_on(b, (0.84 * n[0], 10.08, 0.1 + 0.84 * n[2]), n, 0.07, 0.09, "fur_black")
    _disc_on(b, (0, 9.98, 0.1 - 0.84), (0, 0, -1), 0.05, 0.09, "nose_pink", segments=6)
    b.cyl((0.0, 9.8, 0.1), 0.87, 0.08, "shirt_red", segments=14)                              # a collar and bell
    b.ball((0.0, 9.75, 0.1 - 0.9), 0.08, "gold_light")
    objs = [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]
    # two toys and a moon lamp that swing, each built round its hook under a platform (the hook is the pivot)
    t1 = RB()
    t1.cyl((0, -0.385, 0), 0.012, 0.83, "cream", segments=5)
    t1.ball((0, -0.88, 0), 0.13, "neon_pink")
    objs.append(t1.finalize(name + "_Toy1_Swing", mat, location=(1.45, 5.0, -0.45)))
    t2 = RB()
    t2.cyl((0, -0.285, 0), 0.012, 0.63, "cream", segments=5)
    t2.ball((0, -0.68, 0), 0.12, "fish_blue", scale=(1.6, 0.8, 0.6))
    t2.fan_z(0.0, (0.12, -0.68), [(0.3, -0.56), (0.3, -0.8)], 0.05, "fish_blue")
    objs.append(t2.finalize(name + "_Toy2_Swing", mat, location=(-0.95, 6.0, -0.35)))
    mo, mg = RB(), RB()
    mo.cyl((0, -0.21, 0), 0.012, 0.48, "offwhite", segments=5)
    mo.cyl((0, -0.47, 0), 0.07, 0.06, "gold_mid", segments=8)
    mg.ball((0, -0.62, 0), 0.15, "sparkle")
    objs += [mo.finalize(name + "_Moon_Swing", mat, location=(0.55, 9.6, -0.45)),
             mg.finalize(name + "_Moon_Glow", mat, location=(0.55, 9.6, -0.45))]
    return objs


# F89 2c moving parts (VFX-Agent drives them): a child Model ending _Swing swings about its pivot's Z axis, _Spin turns
# about its Y axis, _Bob rises and falls; a light inside one is a nested _Glow that moves with it. Each moving Model
# carries its own numbers as attributes (Angle in degrees, Rise in studs, Seconds per cycle; Effects defaults to 2 s).
def _f(v):
    return {"Float64": float(v)}


MOVING = {
    "CatCafe_Decor_BlossomTree": {"nest": {"_Glow": "_Swing"}, "model_attributes": {"_Swing": {"Angle": _f(8)}}},
    "CatCafe_Decor_BathtubSofa": {"model_attributes": {"_Bob": {"Rise": _f(0.05)}}},
    "CatCafe_Decor_HollowLogBooth": {"nest": {"_Glow": "_Swing"}, "model_attributes": {"_Swing": {"Angle": _f(8)}}},
    "CatCafe_Decor_IceCreamCounter": {"model_attributes": {"_Spin": {"Seconds": _f(8)}}},
    "CatCafe_Decor_DuckFountain": {"model_attributes": {"_Spin": {"Seconds": _f(12)}}},
    "CatCafe_Decor_RetroJukebox": {"model_attributes": {"_Spin": {"Seconds": _f(1.8)}},
                                   "pivot_turns": {"_Spin": Matrix.Rotation(math.radians(-90), 3, "X")}},
    "CatCafe_Decor_CatTreeTower": {"nest": {"_Glow": "_Swing"}, "model_attributes": {"_Swing": {"Angle": _f(12)}}},
}

ASSETS = {
    "CatCafe_Decor_MilkCrateStools": (build_milk_crate_stools, 1500),
    "CatCafe_Decor_RetroJukebox": (build_retro_jukebox, 3000),
    "CatCafe_Decor_JarLights": (build_jar_lights, 1800),
    "CatCafe_Decor_PicnicTableSet": (build_picnic_table_set, 1800),
    "CatCafe_Decor_DuckFountain": (build_duck_fountain, 3000),
    "CatCafe_Decor_BlossomTree": (build_blossom_tree, 3000),
    "CatCafe_Decor_PorchSwing": (build_porch_swing, 1800),
    "CatCafe_Decor_IceCreamCounter": (build_ice_cream_counter, 3000),
    "CatCafe_Decor_BicyclePlanter": (build_bicycle_planter, 1800),
    "CatCafe_Decor_MailboxPlanter": (build_mailbox_planter, 1800),
    "CatCafe_Decor_LogStools": (build_log_stools, 1500),
    "CatCafe_Decor_HollowLogBooth": (build_hollow_log_booth, 3000),
    "CatCafe_Decor_LanternStump": (build_lantern_stump, 1800),
    "CatCafe_Decor_MushroomLamp": (build_mushroom_lamp, 1800),
    "CatCafe_Decor_CrateShelf": (build_crate_shelf, 1500),
    "CatCafe_Decor_BathtubSofa": (build_bathtub_sofa, 3000),
    "CatCafe_Decor_RubberDuckRow": (build_rubber_duck_row, 1800),
    "CatCafe_Decor_PipeFountain": (build_pipe_fountain, 1800),
    "CatCafe_Decor_BistroSet": (build_bistro_set, 1800),
    "CatCafe_Decor_VelvetBooth": (build_velvet_booth, 1800),
    "CatCafe_Decor_HangingPlants": (build_hanging_plants, 1800),
    "CatCafe_Decor_CatTreeTower": (build_cat_tree_tower, 3000),
}
