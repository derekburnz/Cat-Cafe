"""The Rescue Rally weekend in the Town Square (F101, rescue-rally.md section 4: "The Town Square gets bunting in the
Rally colours and a big Rally board by the cannon showing the bar"). The Rally colours: red (shirt_red), blue
(shirt_blue), navy (pants_navy), gold (rarity_legend) and off-white.

  CatCafe_Square_RallyBoard          a sporty scoreboard on two striped posts: a navy frame with marquee bulbs round
                                     a dark face, a checkered finish-line apron under it, a red header reading RESCUE
                                     RALLY (front and back) with gold stars, and on top a gold trophy on a wooden
                                     plinth between two pom-poms; a pennant flag flies off each post
    Screen                           the 10 x 4 face (the _Screen object), Front (-Z) toward the player: the UI's
                                     SurfaceGui (Adornee = Screen) draws the bar, its three steps, the lap and the time
                                     left on it, so nothing stands in front of it
    _Bulbs                           the marquee bulbs: lit at night
  CatCafe_Square_RallyBunting        the edge bunting (square.build_bunting) in the Rally colours, the same 22 and 16.5
  CatCafe_Square_RallyBuntingShort   stud spans with the same pennant Models (`_Pennant` in a Model named *Bunting*,
                                     VFX-Agent's flutter), so the Rally swaps them in at the edge bunting's placements

Pivots at the base centre on the square's floor top (y 0.1), front -Z. The board stands in the north-east quarter at
SPOT, turned to face the spawn, off the cross and off the cannon's four firing lines.
"""

import math

from alleyway import label
from common import RB, text_width
from plot import rot_z
from square import BUNTING_SPAN, SHORT_SPAN, build_bunting

N = "CatCafe_Square_RallyBoard"
SPOT = (15.0, 0.1, 12.0, 30.0)      # world (x, y, z, rotY): faces the player spawn at (0, -14)
FLAGS = ("shirt_red", "offwhite", "shirt_blue", "rarity_legend")

SW, SH = 10.0, 4.0                  # the Screen
SY0 = 4.6                           # its bottom
FZ = -0.25                          # its front face
F = 0.45                            # the frame round it
HX = SW / 2 + F                     # the frame's outer half width
Y_LO, Y_HI = SY0 - F, SY0 + SH + F
FRONT, BACK = -0.45, 0.3
APRON = Y_LO - 1.0                  # the checkered apron's bottom
HEAD_TOP = Y_HI + 1.6               # the header plank's top
T0 = HEAD_TOP + 0.12                # the white band's top: the trophy and pom-poms stand on it
POST_X, POST_TOP = 4.6, 12.0
TITLE = "RESCUE RALLY"


def _frame(b, screen, bulbs):
    screen.span((-SW / 2, SY0, FZ), (SW / 2, SY0 + SH, 0.05), "night_sky")
    for (x0, y0, x1, y1) in ((-HX, Y_LO, HX, SY0 + 0.01), (-HX, SY0 + SH - 0.01, HX, Y_HI),
                             (-HX, SY0, -SW / 2 + 0.01, SY0 + SH), (SW / 2 - 0.01, SY0, HX, SY0 + SH)):
        b.span((x0, y0, FRONT), (x1, y1, BACK), "pants_navy")
    b.span((-SW / 2 - 0.1, SY0 - 0.1, 0.0), (SW / 2 + 0.1, SY0 + SH + 0.1, 0.25), "pants_navy")   # back panel
    n = 12                                                                                  # marquee bulbs
    for k in range(n):
        x = -HX + 0.35 + k * (2 * HX - 0.7) / (n - 1)
        for y in ((Y_LO + SY0) / 2, (SY0 + SH + Y_HI) / 2):
            bulbs.span((x - 0.1, y - 0.1, FRONT - 0.08), (x + 0.1, y + 0.1, FRONT), "lamp_warm")
    for s in (-1, 1):
        for k in range(4):
            y = SY0 + 0.5 + k * (SH - 1.0) / 3
            x = s * (SW / 2 + F / 2)
            bulbs.span((x - 0.1, y - 0.1, FRONT - 0.08), (x + 0.1, y + 0.1, FRONT), "lamp_warm")
    b.span((-HX, APRON, -0.35), (HX, Y_LO, 0.25), "offwhite")                                # finish-line apron
    cols = 22
    w = 2 * HX / cols
    for row in range(2):
        for c in range(cols):
            if (c + row) % 2 == 0:
                x0 = -HX + c * w
                y0 = APRON + row * 0.5
                b.span((x0, y0, -0.39), (x0 + w, y0 + 0.5, -0.35), "fur_black")
    py = SY0 + SH / 2 - 0.15                                                                # a paw on the back
    b.span((-0.48, py - 0.5, 0.25), (0.48, py + 0.17, 0.29), "offwhite")
    for (dx, dy) in ((-0.62, 0.48), (-0.21, 0.7), (0.21, 0.7), (0.62, 0.48)):
        b.span((dx - 0.17, py + dy - 0.17, 0.25), (dx + 0.17, py + dy + 0.17, 0.29), "offwhite")


def _star(b, x, y, z, s=1.0):
    """A gold four-point star standing 0.08 proud of a face at depth z (front -Z)."""
    b.box((x, y, z - 0.04), (0.42 * s, 0.42 * s, 0.08), "rarity_legend", rot=rot_z(45))
    b.span((x - 0.08 * s, y - 0.45 * s, z - 0.08), (x + 0.08 * s, y + 0.45 * s, z), "rarity_legend")
    b.span((x - 0.45 * s, y - 0.08 * s, z - 0.08), (x + 0.45 * s, y + 0.08 * s, z), "rarity_legend")


def _header(b):
    b.span((-HX, Y_HI, -0.4), (HX, HEAD_TOP, BACK), "shirt_red")
    b.span((-HX - 0.05, HEAD_TOP, -0.45), (HX + 0.05, T0, BACK + 0.05), "offwhite")          # white band on top
    px = 0.19
    y = Y_HI + (HEAD_TOP - Y_HI - 5 * px) / 2
    label(b, TITLE, 0, y, -0.4, px, 0.07, "offwhite", -1)
    label(b, TITLE, 0, y, BACK, px, 0.07, "offwhite", 1)
    edge = text_width(TITLE, px) / 2 + 0.62
    for s in (-1, 1):
        _star(b, s * edge, (Y_HI + HEAD_TOP) / 2, -0.4, 0.8)


def _trophy(b):
    b.span((-0.75, T0, -0.45), (0.75, T0 + 0.4, 0.35), "dark_wood")                          # plinth
    b.span((-0.45, T0 + 0.1, -0.49), (0.45, T0 + 0.3, -0.45), "gold_light")                   # its plaque
    z = -0.05
    b.cyl((0, T0 + 0.5, z), 0.5, 0.2, "gold_dark", segments=12)                               # foot
    b.cyl((0, T0 + 0.85, z), 0.14, 0.5, "gold_mid", segments=8)                               # stem
    b.ball((0, T0 + 1.1, z), 0.22, "gold_mid")                                                # knot
    b.ball((0, T0 + 1.75, z), 0.72, "gold_mid", scale=(1, 0.9, 1))                           # the cup's bowl
    b.cyl((0, T0 + 2.08, z), 0.72, 0.66, "gold_mid", segments=14)                             # and its sides
    b.cyl((0, T0 + 2.45, z), 0.8, 0.1, "gold_light", segments=14)                             # rim
    for s in (-1, 1):                                                                         # handles
        b.b.ring(RB.p(s * 0.86, T0 + 1.95, z), 0.34, 0.13, 0.13, "gold_mid", segments=12, rot=(math.pi / 2, "X"))
    zf = z - 0.76                                                                             # a paw on the cup
    b.cyl((0, T0 + 1.98, zf), 0.17, 0.16, "offwhite", axis="Z", segments=10)
    for (dx, dy) in ((-0.19, 0.17), (-0.07, 0.26), (0.07, 0.26), (0.19, 0.17)):
        b.cyl((dx, T0 + 1.98 + dy, zf), 0.065, 0.16, "offwhite", axis="Z", segments=8)


def _pompom(b, x, colour):
    """A cheer pom-pom lying on the band: a ball of streamers in the colour and white, with its handle."""
    for k, (dx, dy, dz) in enumerate(((0, 0.3, 0), (0.3, 0.42, -0.1), (-0.28, 0.45, 0.08), (0.05, 0.68, 0.05),
                                      (0.1, 0.42, -0.3), (-0.1, 0.4, 0.3))):
        b.ball((x + dx * 1.25, T0 + 0.08 + dy * 1.2, dz * 1.2), 0.42 - 0.012 * k,
               colour if k % 2 == 0 else "offwhite")
    s = 1 if x > 0 else -1
    b.cyl((x + s * 0.75, T0 + 0.25, 0.0), 0.09, 0.7, "fur_black", axis="X", segments=8)


def _posts(b):
    for s in (-1, 1):
        x = s * POST_X
        b.span((x - 0.7, 0, 0.0), (x + 0.7, 0.4, 1.1), "concrete")                             # footing
        b.span((x - 0.25, 0.4, 0.3), (x + 0.25, POST_TOP, 0.8), "shirt_blue")
        for y in (1.5, 2.6, 11.3):
            b.span((x - 0.31, y, 0.24), (x + 0.31, y + 0.22, 0.86), "offwhite")
        b.ball((x, POST_TOP + 0.2, 0.55), 0.3, "rarity_legend")                                # finial
        tip = x + s * 1.5                                                                      # pennant flag
        b.fan_z(0.55, (tip, POST_TOP - 0.75), [(x + s * 0.25, POST_TOP - 0.2), (x + s * 0.25, POST_TOP - 1.3)],
                0.06, "shirt_red" if s > 0 else "shirt_blue")


def build(mat):
    b, screen, bulbs = RB(), RB(), RB()
    _frame(b, screen, bulbs)
    _header(b)
    _trophy(b)
    _pompom(b, 3.3, "shirt_red")
    _pompom(b, -3.3, "shirt_blue")
    _posts(b)
    return [b.finalize(N, mat), screen.finalize(N + "_Screen", mat), bulbs.finalize(N + "_Bulbs", mat)]


ASSETS = {
    N: (build, 8000),
    "CatCafe_Square_RallyBunting": (lambda mat: build_bunting(mat, BUNTING_SPAN, "CatCafe_Square_RallyBunting",
                                                              FLAGS), 1500),
    "CatCafe_Square_RallyBuntingShort": (lambda mat: build_bunting(mat, SHORT_SPAN, "CatCafe_Square_RallyBuntingShort",
                                                                   FLAGS), 1200),
}
