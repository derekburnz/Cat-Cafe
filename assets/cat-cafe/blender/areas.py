"""Area gates (data-model section 9, world-and-feel.md section 2): an arch over each area's opening with a
see-through barrier and a sign board, the way simulator zone gates work, themed per area with our own art.

  CatCafe_Park_Gate            24 wide opening, street's south end (0, -101)
  CatCafe_Neighbourhood_Gate   24 wide, gap in the Alley Square's north wall (0, 151.5)
  CatCafe_Woods_Gate           30 wide, west back alley's south end (-74, -101)
  CatCafe_Sewer_Gate           30 wide, east back alley's south end (74, -101)

Pivot at the base centre of the opening. The front (-Z) faces the side players come from, so the Park, Woods and
Sewer gates are placed turned 180 degrees. The pillars stand outside the opening, so the walls end where they start.
Objects per gate:
  <asset>              pillars, lintel with the area name on both faces, decoration (collides)
  <asset>_Bars         one box filling the opening up to 12 studs: exported as a ForceField part named Bars directly
                       under the gate, the only part WorldController makes walkable once the gate opens
  <asset>_SignBoard    10 x 2.5 board hanging in front of the barrier; its -Z face takes the requirement SurfaceGui
  <asset>_Lamp_Bulb    lanterns, lit at night
  <asset>_Flowers      planters and flower beds, where the effects code sends butterflies
"""

import math

from alleyway import bar, flower_clump, label, lantern
from common import RB, text_width
from plot import TRIM

BARS_TOP = 12.0
PILLAR = 2.6
SIGN = (-5.0, 5.0, 8.4, 10.9)                      # x0, x1, y0, y1 of the hanging sign board, at z -0.85..-0.65
SIGN_INFO = {"part": "SignBoard", "face": "Front (-Z)", "size": [10.0, 2.5], "centre": [0.0, 9.65, -0.85]}


def _sign(b, sign, frame, top):
    x0, x1, y0, y1 = SIGN
    sign.span((x0, y0, -0.85), (x1, y1, -0.65), "offwhite")
    for (xa, xb, ya, yb) in ((x0 - 0.2, x1 + 0.2, y0 - 0.2, y0), (x0 - 0.2, x1 + 0.2, y1, y1 + 0.2),
                             (x0 - 0.2, x0, y0, y1), (x1, x1 + 0.2, y0, y1)):
        b.span((xa, ya, -0.9), (xb, yb, -0.6), frame)
    for x in (x0 + 0.8, x1 - 0.8):                                                         # chains
        b.span((x - 0.06, y1 + 0.2, -0.8), (x + 0.06, top, -0.7), "metal")


def _title(b, text, y, px, z_front, z_back, swatch):
    label(b, text, 0, y, z_front, px, 0.06, swatch, -1)
    label(b, text, 0, y, z_back, px, 0.06, swatch, 1)


def _gate(name, mat, width, barrier, frame, build):
    b, bars, sign, lamps, flowers = RB(), RB(), RB(), RB(), RB()
    half = width / 2
    bars.span((-half, 0, -0.2), (half, BARS_TOP, 0.2), barrier)
    top = build(b, lamps, flowers, half)
    _sign(b, sign, frame, top)
    out = [b.finalize(name, mat), bars.finalize(name + "_Bars", mat), sign.finalize(name + "_SignBoard", mat),
           lamps.finalize(name + "_Lamp_Bulb", mat)]
    if flowers.b.prims:
        out.append(flowers.finalize(name + "_Flowers", mat))
    return out


def _brick_pillars(b, half, cap="concrete", h=13.5):
    for s in (-1, 1):
        x0, x1 = sorted((s * half, s * (half + PILLAR)))
        b.span((x0 - 0.2, 0, -1.5), (x1 + 0.2, 0.8, 1.5), "concrete")
        b.span((x0, 0.8, -1.3), (x1, h, 1.3), "brick")
        for y in (4.5, 9.0):
            b.span((x0 - 0.12, y, -1.42), (x1 + 0.12, y + 0.4, 1.42), "concrete")
        b.span((x0 - 0.2, h, -1.5), (x1 + 0.2, h + 0.6, 1.5), cap)


# --------------------------------------------------------------------------------------------- park --
def _park(b, lamps, flowers, half):
    _brick_pillars(b, half)
    for s in (-1, 1):
        cx = s * (half + PILLAR / 2)
        lantern(b, lamps, cx, 14.1, 0, 1.1)
        for (y, dz) in ((2.0, 1.0), (5.6, -0.6), (8.3, 0.9), (11.2, -0.3)):                 # ivy on the outer face
            b.ball((s * (half + PILLAR + 0.2), y, dz), 0.7, "leaf_dark", scale=(0.6, 1.0, 1.0))
        for z in (-2.3, 2.3):                                                              # planters
            b.span((cx - 1.2, 0, z - 0.5), (cx + 1.2, 1.0, z + 0.5), "terracotta")
            flowers.span((cx - 1.1, 1.0, z - 0.4), (cx + 1.1, 1.15, z + 0.4), "leaf_green")
            for k in range(3):
                flower_clump(flowers, cx - 0.7 + 0.7 * k, 1.15, z, n=3, spread=0.3)
        b.ball((s * (half + PILLAR + 1.4), 1.1, 0), 1.2, "leaf_green", scale=(1.0, 0.85, 1.2))
    # green iron frame and the name board
    for y0, y1 in ((12.2, 12.6), (15.0, 15.4)):
        b.span((-half, y0, -0.3), (half, y1, 0.3), "dumpster_green")
    px = 0.45
    bw = text_width("THE PARK", px) + 3.0
    b.span((-bw / 2, 12.6, -0.25), (bw / 2, 15.0, 0.25), "mint")
    _title(b, "THE PARK", 12.68, px, -0.25, 0.25, "offwhite")
    for s in (-1, 1):                                                                      # scrolls beside the board
        for k in range(3):
            x = s * (bw / 2 + 0.9 + k * (half - bw / 2 - 1.2) / 2.5)
            b.cyl((x, 13.8, 0), 0.55, 0.15, "dumpster_green", axis="Z", segments=10)
            b.cyl((x, 13.8, 0), 0.38, 0.2, "mint", axis="Z", segments=10)
    for dx in (-0.9, 0, 0.9):                                                              # leaf crest
        b.ball((dx, 16.1 + (0.3 if dx == 0 else 0), 0), 0.7, "leaf_green")
    b.cyl((0, 15.9, 0), 0.6, 0.35, "rarity_legend", axis="Z", segments=12)
    return 12.2


def build_park_gate(mat):
    return _gate("CatCafe_Park_Gate", mat, 24.0, "mint", "dumpster_green", _park)


# -------------------------------------------------------------------------------------------- woods --
def _spruce(b, x, z, s=1.0):
    b.cyl((x, 0.6 * s, z), 0.3 * s, 1.2 * s, "fur_brown", segments=8)
    for k, (y, r) in enumerate(((1.2, 1.7), (2.6, 1.35), (3.9, 1.0))):
        b.cyl((x, (y + 1.2) * s, z), r * s, 2.4 * s, "leaf_dark" if k % 2 == 0 else "leaf_green", r2=0.15 * s,
              segments=10)


def _woods(b, lamps, flowers, half):
    for s in (-1, 1):
        cx = s * (half + PILLAR / 2)
        b.cyl((cx, 7.0, 0), 1.4, 14.0, "fur_brown", segments=12)
        for y in (3.0, 7.0, 11.0):
            b.cyl((cx, y, 0), 1.48, 0.25, "dark_wood", segments=12)
        b.ball((cx, 14.0, 0), 1.6, "leaf_green", scale=(1.0, 0.5, 1.0))
        for (dx, dz, h, r) in ((0.9, -1.9, 0.7, 0.45), (-0.6, -2.2, 0.45, 0.3), (0.2, 2.0, 0.6, 0.4)):  # mushrooms
            mx = cx + s * dx
            b.cyl((mx, h / 2, dz), 0.1, h, "offwhite", segments=6)
            b.cyl((mx, h + r * 0.3, dz), r, r * 0.6, "bowl_red", r2=0.05, segments=10)
            b.span((mx + r * 0.3 - 0.06, h + r * 0.45, dz - r * 0.5 - 0.02), (mx + r * 0.3 + 0.06, h + r * 0.57, dz - r * 0.5 + 0.1),
                   "offwhite")
        _spruce(b, s * (half + PILLAR + 2.4), 0.6)
        _spruce(b, s * (half + PILLAR + 1.6), -2.4, 0.7)
        flowers.span((cx - 1.0, 0, -3.4), (cx + 1.0, 0.15, -2.6), "leaf_green")
        flower_clump(flowers, cx, 0.15, -3.0, colours=("sparkle", "offwhite", "pastel_lilac"), n=4, spread=0.5)
    length = 2 * (half + PILLAR + 0.6)
    b.cyl((0, 13.3, 0), 1.1, length, "fur_brown", axis="X", segments=12)                  # beam log
    for s in (-1, 1):
        b.cyl((s * length / 2, 13.3, 0), 1.0, 0.06, "treat_tan", axis="X", segments=12)
        b.cyl((s * length / 2, 13.3, 0), 0.5, 0.08, "caramel_wood", axis="X", segments=10)
    for x in (-6.0, 1.5, 8.0):
        b.ball((x, 14.25, 0.2), 0.8, "leaf_green", scale=(1.4, 0.5, 1.0))
    px = 0.45
    bw = text_width("THE WOODS", px) + 2.4
    b.span((-bw / 2, 14.4, -0.2), (bw / 2, 16.9, 0.2), "caramel_wood")                    # carved plank
    for s in (-1, 1):
        b.span((s * bw / 2 - 0.3, 14.4, -0.25), (s * bw / 2 + 0.3, 16.9, 0.25), "dark_wood")
    _title(b, "THE WOODS", 14.52, px, -0.2, 0.2, "dark_wood")
    for x in (-half / 2, half / 2):                                                        # hanging lanterns
        b.span((x - 0.05, 11.6, -1.3), (x + 0.05, 12.25, -1.2), "fur_black")
        lantern(b, lamps, x, 10.2, -1.25, 0.8)
    return 12.2


def build_woods_gate(mat):
    return _gate("CatCafe_Woods_Gate", mat, 30.0, "leaf_green", "dark_wood", _woods)


# -------------------------------------------------------------------------------------------- sewer --
def _sewer(b, lamps, flowers, half):
    for s in (-1, 1):
        x0, x1 = sorted((s * half, s * (half + PILLAR)))
        cx = (x0 + x1) / 2
        b.span((x0 - 0.2, 0, -1.5), (x1 + 0.2, 0.8, 1.5), "concrete")
        b.span((x0, 0.8, -1.3), (x1, 13.6, 1.3), "concrete_dark")
        for k in range(4):                                                                 # hazard collar
            y = 0.9 + k * 0.4
            b.span((x0 - 0.06, y, -1.36), (x1 + 0.06, y + 0.4, 1.36), "rarity_legend" if k % 2 == 0 else "fur_black")
        b.span((x0 - 0.2, 13.6, -1.5), (x1 + 0.2, 14.0, 1.5), "concrete")
        b.span((cx - 0.5, 14.0, -0.5), (cx + 0.5, 14.3, 0.5), "fur_black")               # warning lamp
        lamps.span((cx - 0.35, 14.3, -0.35), (cx + 0.35, 15.0, 0.35), "bowl_red")
        b.span((cx - 0.45, 15.0, -0.45), (cx + 0.45, 15.15, 0.45), "fur_black")
        px_ = s * (half + PILLAR + 0.4)                                                    # side pipe with a valve
        b.cyl((px_, 6.0, 0.6), 0.35, 12.0, "rust", segments=10)
        b.cyl((px_ + s * 0.45, 4.2, 0.6), 0.6, 0.12, "bowl_red", axis="X", segments=12)
        b.cyl((px_ + s * 0.45, 4.2, 0.6), 0.25, 0.2, "metal", axis="X", segments=8)
        for y in (2.0, 10.0):
            b.cyl((px_, y, 0.6), 0.45, 0.3, "metal", segments=10)
    length = 2 * (half + PILLAR + 0.4)
    b.cyl((0, 13.4, 0), 1.25, length, "metal", axis="X", segments=14)                     # big pipe
    for x in (-half - PILLAR / 2, -half / 2, 0.0, half / 2, half + PILLAR / 2):
        b.cyl((x, 13.4, 0), 1.45, 0.3, "rust", axis="X", segments=14)
    for (x, ln) in ((-9.0, 0.9), (-3.5, 0.5), (4.0, 1.1), (10.5, 0.6)):                    # slime drips
        b.span((x - 0.15, 12.15 - ln, -1.05), (x + 0.15, 12.2, -0.85), "leaf_green")
    px = 0.45
    bw = text_width("THE SEWER", px) + 2.4
    b.span((-bw / 2, 14.6, -0.18), (bw / 2, 17.0, 0.18), "concrete_dark")                 # name plate
    for k in range(int(bw / 0.8)):                                                         # hazard top edge
        x = -bw / 2 + k * 0.8
        b.span((x, 17.0, -0.2), (x + 0.8, 17.3, 0.2), "rarity_legend" if k % 2 == 0 else "fur_black")
    _title(b, "THE SEWER", 14.68, px, -0.18, 0.18, "rarity_legend")
    for k in range(-2, 3):                                                                 # floor grate and slime
        b.span((k * 0.8 - 0.08, 0, -3.6), (k * 0.8 + 0.08, 0.06, -2.4), "fur_black")
    b.span((-2.0, 0, -3.65), (2.0, 0.06, -3.5), "fur_black")
    b.span((-2.0, 0, -2.5), (2.0, 0.06, -2.35), "fur_black")
    for (x, z, r) in ((-9.5, -2.0, 1.3), (8.0, -1.8, 0.9), (11.0, -2.6, 0.6)):
        b.cyl((x, 0.03, z), r, 0.06, "leaf_green", segments=12)
    return 12.15


def build_sewer_gate(mat):
    return _gate("CatCafe_Sewer_Gate", mat, 30.0, "eye_green", "rarity_legend", _sewer)


# ------------------------------------------------------------------------------------ neighbourhood --
def _neighbourhood(b, lamps, flowers, half):
    _brick_pillars(b, half, cap="offwhite", h=12.0)
    for s in (-1, 1):
        cx = s * (half + PILLAR / 2)
        for z, sg in ((-1.32, -1), (1.32, 1)):                                             # plaque with a paw
            b.span((cx - 0.6, 6.4, min(z, z + sg * 0.06)), (cx + 0.6, 7.6, max(z, z + sg * 0.06)), "offwhite")
            zz = z + sg * 0.06
            for (dx, dy, r) in ((0, -0.15, 0.22), (-0.28, 0.2, 0.09), (0, 0.3, 0.09), (0.28, 0.2, 0.09)):
                b.span((cx + dx - r, 7.0 + dy - r, min(zz, zz + sg * 0.03)), (cx + dx + r, 7.0 + dy + r, max(zz, zz + sg * 0.03)),
                       "blush")
        hx = s * (half + PILLAR + 1.7)                                                     # hedge and flowers
        b.span((hx - 1.5, 0, -1.2), (hx + 1.5, 2.4, 1.2), "leaf_dark")
        b.ball((hx, 2.4, 0), 1.3, "leaf_dark", scale=(1.1, 0.4, 0.9))
        flowers.span((hx - 1.5, 0, -2.4), (hx + 1.5, 0.2, -1.3), "leaf_green")
        for k in range(4):
            flower_clump(flowers, hx - 1.1 + 0.75 * k, 0.2, -1.85, n=2, spread=0.25)
    # mailbox by the right pillar
    mx = half + PILLAR + 3.8
    b.span((mx - 0.08, 0, -0.08), (mx + 0.08, 3.0, 0.08), "dark_wood")
    b.span((mx - 0.35, 3.0, -0.6), (mx + 0.35, 3.6, 0.6), "shirt_blue")
    b.cyl((mx, 3.6, 0), 0.35, 1.2, "shirt_blue", axis="Z", segments=10)
    b.span((mx + 0.35, 3.3, 0.1), (mx + 0.42, 4.1, 0.25), "bowl_red")
    # white pergola: beams front and back, rafters across, a street sign on top
    reach = half + PILLAR + 0.9
    for z0, z1 in ((-1.2, -0.75), (0.75, 1.2)):
        b.span((-reach, 12.0, z0), (reach, 12.7, z1), TRIM)
    for k in range(int(2 * reach / 2.0) + 1):
        x = -reach + 0.2 + k * (2 * reach - 0.4) / int(2 * reach / 2.0)
        b.span((x - 0.15, 12.7, -1.7), (x + 0.15, 13.15, 1.7), TRIM)
    for x in (-reach + 1.5, -6.0, 2.5, 9.0, reach - 2.0):                                 # climbing rose
        b.ball((x, 13.2, 1.2), 0.6, "leaf_green", scale=(1.3, 0.6, 0.8))
        flowers.span((x - 0.2, 13.4, 0.9), (x + 0.2, 13.75, 1.3), "blush")
    px = 0.4
    bw = text_width("NEIGHBOURHOOD", px) + 2.0
    for x in (-bw / 2 + 1.0, bw / 2 - 1.0):
        b.span((x - 0.12, 13.15, -0.12), (x + 0.12, 13.6, 0.12), "fur_black")
    b.span((-bw / 2, 13.6, -0.15), (bw / 2, 15.9, 0.15), "sign_teal")
    for (ya, yb) in ((13.6, 13.78), (15.72, 15.9)):
        b.span((-bw / 2, ya, -0.2), (bw / 2, yb, 0.2), TRIM)
    _title(b, "NEIGHBOURHOOD", 13.75, px, -0.15, 0.15, "offwhite")
    for s in (-1, 1):
        lantern(b, lamps, s * (half + PILLAR / 2), 13.15, 0, 0.8)
    return 12.0


def build_neighbourhood_gate(mat):
    return _gate("CatCafe_Neighbourhood_Gate", mat, 24.0, "rarity_rare", "sign_teal", _neighbourhood)


ASSETS = {
    "CatCafe_Park_Gate": (build_park_gate, 6000),
    "CatCafe_Neighbourhood_Gate": (build_neighbourhood_gate, 6000),
    "CatCafe_Woods_Gate": (build_woods_gate, 6000),
    "CatCafe_Sewer_Gate": (build_sewer_gate, 6000),
}
