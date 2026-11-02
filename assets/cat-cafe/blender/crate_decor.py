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

from mathutils import Vector

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


def _half_disc(b, cx, cy, z, r, a0, a1, n, d, sw):
    """A flat fan in the XY plane: half a disc from angle a0 to a1."""
    pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)),
            cy + r * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]
    b.fan_z(z, (cx, cy), pts, d, sw)


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


def build_retro_jukebox(mat):
    """An arched jukebox: neon tubes round the arch, records behind a window, buttons, a gold speaker grille."""
    name = "CatCafe_Decor_RetroJukebox"
    b, glow, glass = RB(), RB(), RB()
    W, D, H = 1.2, 0.65, 3.3                                   # half width, half depth, the arch's centre height
    zf = -D
    b.span((-W - 0.05, 0, -D - 0.05), (W + 0.05, 0.25, D + 0.05), "dark_wood")
    b.span((-W, 0.24, -D), (W, H, D), "caramel_wood")
    b.cyl((0, H, 0), W, 2 * D, "caramel_wood", axis="Z", segments=16)
    _arc(b, 0, H, zf - 0.02, 1.13, 0, 180, 12, 0.1, 0.04, "gold_mid")                     # gold trim
    _arc(glow, 0, H, zf - 0.03, 0.98, 0, 180, 12, 0.12, 0.06, "neon_pink")                  # neon arches
    _arc(glow, 0, H, zf - 0.03, 0.8, 0, 180, 10, 0.1, 0.06, "sign_teal")
    for sx in (-1, 1):
        glow.span((sx * 0.98 - 0.06, 0.45, zf - 0.06), (sx * 0.98 + 0.06, H, zf), "neon_pink")
        glow.span((sx * 0.8 - 0.05, H - 0.95, zf - 0.06), (sx * 0.8 + 0.05, H, zf), "sign_teal")
    _half_disc(b, 0, H, zf - 0.01, 0.7, 0, 180, 8, 0.02, HOLE)                              # the window
    b.span((-0.7, H - 0.9, zf - 0.02), (0.7, H, zf), HOLE)
    for i, (x, y, lab) in enumerate(((-0.36, H - 0.3, "shirt_red"), (0.36, H - 0.3, "pastel_butter"),
                                     (0.0, H + 0.15, "mint"))):
        z = zf - 0.04 - 0.02 * i
        b.cyl((x, y, z), 0.3, 0.02, "fur_black", axis="Z", segments=12)
        b.cyl((x, y, z - 0.02), 0.1, 0.02, lab, axis="Z", segments=8)
    _half_disc(glass, 0, H, zf - 0.13, 0.72, 0, 180, 8, 0.02, "glass")
    glass.span((-0.72, H - 0.92, zf - 0.14), (0.72, H, zf - 0.12), "glass")
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
    b.ball((0, H + W, 0), 0.16, "gold_mid")
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat), glass.finalize(name + "_Glass", mat)]


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


def _duckling(b, x, y, z, sw="pastel_butter"):
    b.ball((x, y, z), 0.17, sw, scale=(1.0, 0.75, 1.2))
    b.ball((x, y + 0.17, z - 0.12), 0.11, sw)
    b.box((x, y + 0.15, z - 0.24), (0.09, 0.04, 0.08), "fur_orange")


def build_duck_fountain(mat):
    """A round stone fountain with a duck on top spouting water into the basin, two ducklings and lily pads."""
    name = "CatCafe_Decor_DuckFountain"
    b, wat = RB(), RB()
    b.cyl((0, 0.36, 0), 1.15, 0.72, "cream", segments=16)
    b.cyl((0, 0.12, 0), 1.17, 0.12, "floor_tile", segments=16)
    _ring_flat(b, (0, 0.79, 0), 1.22, 0.2, 0.14, "offwhite", segments=16)
    b.cyl((0, 0.73, 0), 1.03, 0.02, "pastel_sky", segments=16)
    wat.cyl((0, 0.77, 0), 1.03, 0.04, WATER, segments=16)
    b.cyl((0, 1.22, 0), 0.3, 1.0, "cream", segments=10)                                     # pedestal
    b.cyl((0, 1.0, 0), 0.34, 0.1, "floor_tile", segments=10)
    b.cyl((0, 1.88, 0), 0.32, 0.32, "cream", r2=0.72, segments=12)                          # upper bowl
    wat.cyl((0, 2.05, 0), 0.66, 0.03, WATER, segments=12)
    b.ball((0, 2.4, 0.08), 0.42, "pastel_butter", scale=(1.0, 0.8, 1.25))                   # the duck
    b.ball((0, 2.88, -0.2), 0.28, "pastel_butter")
    b.box((0, 2.84, -0.5), (0.26, 0.1, 0.22), "fur_orange")
    for sx in (-1, 1):
        b.cyl((sx * 0.13, 2.95, -0.44), 0.05, 0.03, "fur_black", axis="Z", segments=8)
        b.ball((sx * 0.38, 2.45, 0.12), 0.2, "fur_golden", scale=(0.4, 0.7, 1.2))
    b.ball((0, 2.62, 0.56), 0.14, "pastel_butter", scale=(1.0, 1.4, 1.0))
    pts = [(0, 2.82 - 2.02 * t * t, -0.62 - 0.33 * t) for t in (0.0, 0.25, 0.5, 0.7, 0.85, 1.0)]
    for p0, p1 in zip(pts, pts[1:]):                                                       # the stream
        _rod(wat, p0, p1, 0.09, WATER)
    for dx, dz in ((0, 0), (0.15, 0.08), (-0.14, 0.05)):
        wat.ball((dx, 0.82, -0.95 + dz), 0.07, WATER)
    _duckling(b, 0.62, 0.84, 0.2)
    _duckling(b, -0.5, 0.84, 0.45)
    for x, z in ((-0.55, -0.45), (0.45, -0.55)):
        b.cyl((x, 0.8, z), 0.18, 0.02, "leaf_green", segments=10)
    b.ball((-0.55, 0.85, -0.45), 0.07, "blush")
    return [b.finalize(name, mat), wat.finalize(name + "_Water", mat)]


def build_blossom_tree(mat):
    """A cherry blossom in a big round pot: pink clouds of blossom, a twisting trunk, petals fallen round the pot.
    The petals drifting down are the VFX's: they fall from the child Model `_Canopy`."""
    name = "CatCafe_Decor_BlossomTree"
    b, canopy = RB(), RB()
    b.cyl((0, 0.5, 0), 0.68, 1.0, "offwhite", r2=0.85, segments=14)
    b.cyl((0, 1.0, 0), 0.9, 0.14, "blush", segments=14)
    b.cyl((0, 1.085, 0), 0.78, 0.04, "choco", segments=14)
    trunk = (((0, 1.05, 0), (0.15, 2.6, 0), 0.34), ((0.15, 2.6, 0), (-0.1, 3.9, 0.05), 0.3),
             ((0.1, 3.2, 0), (1.05, 4.05, 0), 0.18), ((0.0, 3.5, 0), (-1.0, 3.95, 0), 0.18),
             ((-0.1, 3.9, 0.05), (0.2, 4.8, 0), 0.16))
    for p0, p1, t in trunk:
        _rod(b, p0, p1, t, "dark_wood")
    b.ball((0.15, 2.6, 0), 0.19, "dark_wood")
    for x, y, z, r, sw in ((0.0, 4.6, 0.0, 1.0, "fur_rose"), (-1.05, 4.15, 0.1, 0.72, "blush"),
                           (1.1, 4.25, -0.05, 0.75, "blush"), (0.35, 5.35, 0.05, 0.7, "fur_rose"),
                           (-0.55, 5.1, -0.05, 0.6, "fur_strawberry"), (0.95, 4.95, 0.1, 0.5, "fur_strawberry")):
        canopy.ball((x, y, z), r, sw, scale=(1.0, 0.85, 0.62))
    for x, y, z in ((-0.3, 4.9, -0.55), (0.6, 4.45, -0.52), (-1.0, 4.3, -0.38), (0.4, 5.55, -0.35), (1.25, 4.2, -0.4)):
        canopy.ball((x, y, z), 0.2, "offwhite", scale=(1.0, 0.85, 0.6))
    petals = [(0.64 * math.cos(math.radians(a)), 0.01, 0.64 * math.sin(math.radians(a))) for a in (205, 245, 290, 335, 30)]
    for i, (x, y, z) in enumerate(petals + [(0.2, 1.11, -0.3), (-0.35, 1.11, 0.25)]):
        ox, oz = (-math.copysign(1, x), math.copysign(1, z)) if y < 1 else (1, 1)   # floor petals poke out from the pot
        b.b.fan(RB.p(x, y, z), (0, 0), [(0.13 * ox, 0.04 * oz), (0.05 * ox, 0.13 * oz)], 0.02,
                ("fur_rose", "blush")[i % 2])
    return [b.finalize(name, mat), canopy.finalize(name + "_Canopy", mat)]


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


def build_ice_cream_counter(mat):
    """A striped ice cream counter: five tubs under a glass hood, cones and spoons, and a cone sign whose scoop
    is a cat."""
    name = "CatCafe_Decor_IceCreamCounter"
    b, glass = RB(), RB()
    b.span((-1.82, 0, -0.62), (1.82, 0.26, 0.62), "mint")
    b.span((-1.8, 0.25, -0.6), (1.8, 2.4, 0.6), "offwhite")
    for k, sw in ((0, "blush"), (2, "pastel_sky"), (4, "blush")):
        b.span((-1.8 + 0.6 * k, 0.26, -0.61), (-1.2 + 0.6 * k, 2.38, -0.6), sw)
    b.span((-1.9, 2.39, -0.7), (1.9, 2.52, 0.7), "caramel_wood")
    b.span((-1.65, 2.51, -0.15), (1.65, 2.58, 0.62), "metal")
    for x, sw in zip((-1.28, -0.64, 0.0, 0.64, 1.28), ("blush", "mint", "pastel_butter", "choco", "pastel_lilac")):
        b.span((x - 0.28, 2.57, 0.0), (x + 0.28, 2.75, 0.5), "offwhite")
        b.ball((x, 2.82, 0.25), 0.24, sw, scale=(1.0, 0.75, 1.0))
    glass.box((0, 2.94, 0.025), (3.3, 0.8, 0.04), "glass", rot=rot_x(25.9))
    glass.span((-1.65, 3.28, 0.18), (1.65, 3.32, 0.62), "glass")
    for sx in (-1, 1):
        glass.span((sx * 1.63, 2.58, -0.15), (sx * 1.67, 3.3, 0.62), "glass")
    b.span((-1.65, 2.51, -0.57), (-1.35, 2.6, -0.27), "metal")                               # cones
    for dx, dz in ((-0.08, -0.42), (0.08, -0.42), (0.0, -0.32)):
        b.cyl((-1.5 + dx, 2.78, dz), 0.02, 0.36, "treat_tan", r2=0.12, segments=8)
    b.cyl((1.5, 2.65, -0.42), 0.12, 0.28, "pastel_sky", segments=8)                          # spoons
    for dx, sw in ((-0.04, "blush"), (0.04, "mint")):
        _rod(b, (1.5 + dx, 2.6, -0.42), (1.5 + dx * 2, 2.95, -0.45), 0.03, sw)
    b.cyl((1.55, 3.45, 0.45), 0.07, 1.9, "offwhite", segments=8)                             # the sign
    for y in (2.9, 3.4, 3.9):
        b.cyl((1.55, y, 0.45), 0.075, 0.12, "blush", segments=8)
    b.cyl((1.55, 4.65, 0.45), 0.04, 0.6, "treat_tan", r2=0.32, segments=10)
    b.ball((1.55, 5.22, 0.45), 0.4, "blush")
    for sx in (-1, 1):
        x = 1.55 + sx * 0.24
        b.fan_z(0.45, (x + sx * 0.04, 5.86), [(x - 0.17, 5.42), (x + 0.17, 5.42)], 0.14, "blush")
        b.fan_z(0.37, (x + sx * 0.03, 5.74), [(x - 0.09, 5.5), (x + 0.09, 5.5)], 0.02, "nose_pink")
        b.cyl((1.55 + sx * 0.13, 5.27, 0.09), 0.05, 0.03, "fur_black", axis="Z", segments=8)
    b.box((1.55, 5.17, 0.08), (0.08, 0.05, 0.03), "nose_pink")
    return [b.finalize(name, mat), glass.finalize(name + "_Glass", mat)]


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


def build_hollow_log_booth(mat):
    """A giant log cut open along its length: a bench inside with cushions, a lantern hung from the roof, moss and
    toadstools on top. The cut faces the room."""
    name = "CatCafe_Decor_HollowLogBooth"
    b, glow = RB(), RB()
    R, L, z0, TB, TL = 2.3, 4.0, -1.15, 0.3, 0.12
    y0, n = R + 0.02, 12

    def at(r, t):
        return (z0 + r * math.cos(t), y0 + r * math.sin(t))

    def chord(r):
        return 2 * r * math.sin(math.radians(180 / n / 2)) * 1.06

    for k in range(n):
        t = math.radians(-90 + 180 * (k + 0.5) / n)
        rot = rot_x(-math.degrees(t))
        z, y = at(R - TB / 2, t)
        b.box((0, y, z), (L + 0.12, chord(R), TB), "dark_wood", rot=rot)                       # bark
        z, y = at(R - TB - TL / 2, t)
        b.box((0, y, z), (L, chord(R - TB), TL), "treat_tan", rot=rot)                         # the hollowed inside
        for sx in (-1, 1):                                                                     # the sawn ends
            z, y = at(R - (TB + TL + 0.1) / 2, t)
            b.box((sx * (L / 2 + 0.04), y, z), (0.08, chord(R - 0.1), TB + TL - 0.1), "caramel_wood", rot=rot)
    b.span((-1.7, 0.42, -0.6), (1.7, 1.15, 0.45), "caramel_wood")                            # the bench
    b.span((-1.6, 1.14, -0.55), (1.6, 1.32, 0.3), "mint")
    b.box((-0.9, 1.68, 0.3), (0.8, 0.7, 0.22), "pastel_butter", rot=rot_x(20))
    b.box((0.9, 1.68, 0.3), (0.8, 0.7, 0.22), "blush", rot=rot_x(20))
    b.span((-0.015, 3.32, -0.215), (0.015, 3.98, -0.185), "cream")                           # the lantern
    b.cyl((0, 3.32, -0.2), 0.14, 0.06, "concrete_dark", segments=8)
    glow.box((0, 3.12, -0.2), (0.22, 0.32, 0.22), "lamp_warm")
    b.cyl((0, 2.94, -0.2), 0.14, 0.05, "concrete_dark", segments=8)
    for x, y, z, r in ((-1.2, 4.52, -0.75, 0.45), (0.4, 4.47, -0.55, 0.5), (1.45, 4.3, -0.25, 0.35)):
        b.ball((x, y, z), r, "leaf_green", scale=(1.0, 0.35, 1.0))
    _mushroom(b, 1.55, 4.3, -0.35, 1.3)
    _mushroom(b, 1.8, 4.22, -0.18, 0.9, "fur_orange")
    _leaves(b, ((-1.7, 4.55, -1.1, 0.14), (-0.9, 4.58, -1.12, 0.12), (0.6, 4.56, -1.1, 0.13)))
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]


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


def build_bathtub_sofa(mat):
    """A clawfoot tub piled with cushions: sky blue outside, white rim, gold feet, a brass tap and a rubber duck."""
    b = RB()
    b.span((-1.0, 0.5, -0.85), (1.0, 1.85, 0.85), "pastel_sky")
    for sx in (-1, 1):
        b.cyl((sx * 1.0, 1.175, 0), 0.85, 1.35, "pastel_sky", segments=14)
        b.cyl((sx * 1.0, 1.9, 0), 0.92, 0.12, "offwhite", segments=14)
        b.cyl((sx * 1.0, 1.96, 0), 0.72, 0.02, "cream", segments=14)
        for sz in (-1, 1):
            b.cyl((sx * 1.25, 0.35, sz * 0.5), 0.1, 0.4, "gold_mid", segments=8)
            b.ball((sx * 1.28, 0.14, sz * 0.53), 0.16, "gold_mid", scale=(1.2, 0.9, 1.2))
    b.span((-1.0, 1.84, -0.92), (1.0, 1.96, 0.92), "offwhite")
    b.span((-1.0, 1.95, -0.72), (1.0, 1.97, 0.72), "cream")
    for x0, x1, sw in ((-1.45, -0.5, "blush"), (-0.48, 0.48, "pastel_butter"), (0.5, 1.45, "mint")):
        b.span((x0, 1.96, -0.58), (x1, 2.3, 0.45), sw)
    for x, sw in ((-0.95, "pastel_lilac"), (0.0, "blush"), (0.95, "pastel_butter")):
        b.box((x, 2.68, 0.5), (0.85, 0.85, 0.28), sw, rot=rot_x(14))
    b.cyl((1.72, 2.25, 0), 0.07, 0.6, "brass", segments=8)                                   # the tap
    b.box((1.55, 2.52, 0), (0.4, 0.09, 0.09), "brass")
    b.cyl((1.37, 2.46, 0), 0.05, 0.12, "brass", segments=8)
    for sz in (-1, 1):
        b.cyl((1.72, 2.4, sz * 0.13), 0.05, 0.12, "brass", axis="Z", segments=8)
        b.box((1.72, 2.4, sz * 0.22), (0.18, 0.04, 0.04), "offwhite")
    _rubber_duck(b, -1.55, 1.95, -0.66, 0.6, "pastel_butter")
    return [b.finalize("CatCafe_Decor_BathtubSofa", mat)]


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


def _sisal_post(b, x, z, y0, y1):
    b.cyl((x, (y0 + y1) / 2, z), 0.2, y1 - y0, "treat_tan", segments=10)
    for f in (0.33, 0.66):
        b.cyl((x, y0 + (y1 - y0) * f, z), 0.215, 0.05, "kibble", segments=10)


# F79 bedtime (data-model 12c; see furniture.TREE_SPOTS): the tower's two sleep spots, best first (the bed on top,
# then the blush platform; the other platforms have a post through them), the perches a cat only hops through, clear
# of their posts, and the floor it sets off from.
TOWER_SPOTS = {"Sleep_1": (0.0, 9.9, 0.1), "Sleep_2": (1.05, 5.2, -0.15),
               "Hop_1": (-0.7, 1.55, -0.85), "Hop_2": (-1.2, 3.2, 0.0), "Hop_3": (0.5, 3.4, -0.5),
               "Hop_4": (-0.85, 6.2, -0.1), "Hop_5": (-1.25, 7.9, -0.55), "Foot": (-0.7, 0.0, -1.8)}


def build_cat_tree_tower(mat):
    """A cat tree nearly to the ceiling: sisal posts, carpeted platforms, a cubby with a round door, dangling toys
    and a round bed on top with cat ears on its rim."""
    b = RB()
    b.span((-1.5, 0, -1.1), (1.5, 0.3, 1.1), "blush")
    for px in (-0.9, -0.45):                                                                 # paw prints
        b.cyl((px, 0.15, -1.11), 0.08, 0.02, "offwhite", axis="Z", segments=8)
        for dx, dy in ((-0.08, 0.1), (0.0, 0.13), (0.08, 0.1)):
            b.cyl((px + dx, 0.15 + dy - 0.02, -1.11), 0.035, 0.02, "offwhite", axis="Z", segments=6)
    _sisal_post(b, -0.9, 0.4, 0.3, 3.0)
    b.cyl((-0.9, 3.1, 0.3), 0.75, 0.2, "mint", segments=14)
    _sisal_post(b, 0.9, -0.2, 0.3, 2.0)
    b.span((0.2, 2.0, -0.85), (1.55, 3.3, 0.45), "pastel_lilac")                              # the cubby
    b.cyl((0.88, 2.6, -0.86), 0.38, 0.02, HOLE, axis="Z", segments=12)
    _ring_front(b, (0.88, 2.6, -0.865), 0.44, 0.06, 0.03, "offwhite", segments=12)
    b.span((0.15, 3.29, -0.9), (1.6, 3.4, 0.5), "blush")
    _sisal_post(b, -0.75, 0.3, 3.2, 6.0)
    b.cyl((-0.45, 6.1, 0.15), 0.75, 0.2, "pastel_butter", segments=14)
    _sisal_post(b, 1.0, -0.1, 3.4, 5.0)
    b.cyl((1.05, 5.1, -0.15), 0.72, 0.2, "blush", segments=14)
    _sisal_post(b, -0.3, 0.2, 6.2, 9.6)
    # two step pads so no hop rises more than 2.6: a low one off the floor, a high one on a bracket under the bed
    _sisal_post(b, -0.7, -0.85, 0.3, 1.45)
    b.cyl((-0.7, 1.5, -0.85), 0.45, 0.1, "pastel_lilac", segments=12)
    dx, dz = -1.25 - (-0.3), -0.55 - 0.2
    b.box((-0.3 + dx / 2, 7.74, 0.2 + dz / 2), (0.16, 0.16, math.hypot(dx, dz)), "treat_tan",
          rot=rot_y(math.degrees(math.atan2(dx, dz))))
    b.cyl((-1.25, 7.85, -0.55), 0.45, 0.1, "pastel_lilac", segments=12)
    b.cyl((0.0, 9.75, 0.1), 0.85, 0.3, "mint", segments=14)                                   # the bed on top
    _ring_flat(b, (0.0, 10.05, 0.1), 0.85, 0.22, 0.3, "blush", segments=14)
    for sx in (-1, 1):
        x = sx * 0.45
        b.fan_z(-0.49, (x, 10.62), [(x - 0.22, 10.15), (x + 0.22, 10.15)], 0.14, "blush")
        b.fan_z(-0.57, (x, 10.5), [(x - 0.11, 10.24), (x + 0.11, 10.24)], 0.02, "nose_pink")
    _rod(b, (1.45, 5.0, -0.45), (1.45, 4.2, -0.45), 0.02, "cream")                          # toys
    b.ball((1.45, 4.08, -0.45), 0.13, "neon_pink")
    _rod(b, (-1.05, 6.0, -0.4), (-1.05, 5.4, -0.4), 0.02, "cream")
    b.ball((-1.05, 5.28, -0.4), 0.12, "fish_blue", scale=(1.6, 0.8, 0.6))
    b.fan_z(-0.4, (-0.88, 5.28), [(-0.75, 5.4), (-0.75, 5.16)], 0.05, "fish_blue")
    return [b.finalize("CatCafe_Decor_CatTreeTower", mat)]


ASSETS = {
    "CatCafe_Decor_MilkCrateStools": (build_milk_crate_stools, 1500),
    "CatCafe_Decor_RetroJukebox": (build_retro_jukebox, 2400),
    "CatCafe_Decor_JarLights": (build_jar_lights, 1800),
    "CatCafe_Decor_PicnicTableSet": (build_picnic_table_set, 1800),
    "CatCafe_Decor_DuckFountain": (build_duck_fountain, 2400),
    "CatCafe_Decor_BlossomTree": (build_blossom_tree, 2400),
    "CatCafe_Decor_PorchSwing": (build_porch_swing, 1800),
    "CatCafe_Decor_IceCreamCounter": (build_ice_cream_counter, 2400),
    "CatCafe_Decor_BicyclePlanter": (build_bicycle_planter, 1800),
    "CatCafe_Decor_MailboxPlanter": (build_mailbox_planter, 1800),
    "CatCafe_Decor_LogStools": (build_log_stools, 1500),
    "CatCafe_Decor_HollowLogBooth": (build_hollow_log_booth, 2400),
    "CatCafe_Decor_LanternStump": (build_lantern_stump, 1800),
    "CatCafe_Decor_MushroomLamp": (build_mushroom_lamp, 1800),
    "CatCafe_Decor_CrateShelf": (build_crate_shelf, 1500),
    "CatCafe_Decor_BathtubSofa": (build_bathtub_sofa, 2400),
    "CatCafe_Decor_RubberDuckRow": (build_rubber_duck_row, 1800),
    "CatCafe_Decor_PipeFountain": (build_pipe_fountain, 1800),
    "CatCafe_Decor_BistroSet": (build_bistro_set, 1800),
    "CatCafe_Decor_VelvetBooth": (build_velvet_booth, 1800),
    "CatCafe_Decor_HangingPlants": (build_hanging_plants, 1800),
    "CatCafe_Decor_CatTreeTower": (build_cat_tree_tower, 2400),
}
