"""The rare cat sign (#1572, luck-and-rare-moments.md section 1h, "the pity sign"): a board on the Town Square that
counts down to the next game-wide Legendary cat (every 30 min) and Mythical cat (every 2 h). Shaped like a cat's
head: a violet frame with gold piping round a dark face, two pointed ears on top with pink insides, three cream
whiskers out of each side and a gold paw on the brow between the ears, on two posts with feet. A gold star (the
Legendary) and a violet gem (the Mythical) sit on the frame's bottom bar under the face. From behind, the face's
back is planked with a painted paw, and the ears are pink there too.

  CatCafe_Square_PitySign           frame, ears, whiskers, posts, back (collides)
    Screen                          the 5.6 x 2.8 face (the _Screen object), Front (-Z) toward the player: the UI's
                                    SurfaceGui (Adornee = Screen) draws the two countdown lines ("Legendary cat in
                                    12:30", "Mythical cat in 1:42:10"), or "Now in the Woods!" and "Secured by Sam",
                                    so nothing stands in front of it. Night blue, so gold and white text reads on it

Pivot at the base centre on the square's floor top (y 0.1), front -Z. Footprint about 8.2 x 1.2 studs, 7.7 tall.
The root Model streams Atomic (rbx_export.MODEL_PROPS) so the Screen is there whenever the board is. The suggested
spot is SPOT, across the street from the Day Cart: see SPOT's comment.
"""

import math

from common import RB
from plot import rot_z

NAME = "CatCafe_Square_PitySign"

SW, SH = 5.6, 2.8                   # the Screen
SY0 = 2.85                          # its bottom
FZ = -0.2                           # its front face
F = 0.45                            # the frame round it
HX = SW / 2 + F                     # the frame's outer half width
Y_LO, Y_HI = SY0 - F, SY0 + SH + F
FRONT, BACK = -0.35, 0.3            # the frame's front and back faces
EAR_W, EAR_H = 2.0, 1.55            # an ear's base width and height over the frame's top
FRAME, PIPE = "aurora_violet", "rarity_legend"
POST_X = SW / 2 - 0.5

# Model-Agent's spot (world x, y, z, rotY): in the south-east quarter, across the street from the Day Cart
# (daycart.SPOT), turned to face the cannon's landing pad and the spawn (0, -14) 16 studs away. The finger signpost's
# old spot left of the cannon would stand in the way from the spawn to the Codes Cat and hide the kiosk, so the board
# went here. Its footprint clears the street lane by 2.7 studs, the landing pad's outer ring (7 studs round the
# spawn) by 8.6, the night dealer's cart by 9.2 (and stays off the sightline to it from the spawn), the south sign
# arch's east post by 7.0 and the square's south edge by 5.2.
SPOT = (13.5, 0.1, -23.0, math.degrees(math.atan2(-(0 - 13.5), -(-14 - -23.0))))


def _paw(b, x, y, z, s, sw, depth=0.04):
    """A paw print standing on a face at depth z."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, depth, sw, axis="Z", segments=8)
    for dx, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x + dx * s, y + dy * s, z), 0.075 * s, depth, sw, axis="Z", segments=6)


def _star(b, x, y, z, r, sw):
    """A five-point star standing on a face at depth z (facing -Z)."""
    pts = []
    for k in range(11):
        a = math.radians(90 + k * 36)
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    b.fan_z(z, (x, y), pts, 0.08, sw)


def _gem(b, x, y, z, r, sw):
    """A cut gem (a flat diamond with a pale facet) standing on a face at depth z."""
    b.fan_z(z, (x, y), [(x, y + r), (x - r * 0.8, y + r * 0.25), (x, y - r), (x + r * 0.8, y + r * 0.25), (x, y + r)],
            0.08, sw)
    b.fan_z(z - 0.03, (x - r * 0.15, y + r * 0.35), [(x - r * 0.15, y + r * 0.75), (x - r * 0.5, y + r * 0.3),
                                                     (x - r * 0.1, y + r * 0.1)], 0.04, "pearl")


def _frame(b, screen):
    screen.span((-SW / 2, SY0, FZ), (SW / 2, SY0 + SH, 0.05), "night_sky")
    b.span((-SW / 2, SY0, 0.05), (SW / 2, SY0 + SH, BACK), "caramel_wood")                    # the face's back
    for (x0, x1, y0, y1) in ((-HX, HX, Y_LO, SY0), (-HX, HX, SY0 + SH, Y_HI),             # bottom and top bars
                             (-HX, -SW / 2, SY0, SY0 + SH), (SW / 2, HX, SY0, SY0 + SH)):  # the sides
        b.span((x0, y0, FRONT), (x1, y1, BACK), FRAME)
    # gold piping round the face's edge, on the frame's front
    for (x0, x1, y0, y1) in ((-SW / 2 - 0.12, SW / 2 + 0.12, SY0 - 0.12, SY0), (-SW / 2 - 0.12, SW / 2 + 0.12,
                                                                                SY0 + SH, SY0 + SH + 0.12),
                             (-SW / 2 - 0.12, -SW / 2, SY0, SY0 + SH), (SW / 2, SW / 2 + 0.12, SY0, SY0 + SH)):
        b.span((x0, y0, FRONT - 0.045), (x1, y1, FRONT - 0.005), PIPE)        # just proud of the frame
    # the back: planks and a painted paw
    for i in range(1, 6):
        x = -SW / 2 + i * SW / 6
        b.span((x - 0.04, SY0 + 0.1, BACK - 0.01), (x + 0.04, SY0 + SH - 0.1, BACK + 0.02), "dark_wood")
    b.span((-0.75, SY0 + 0.45, BACK + 0.01), (0.75, SY0 + SH - 0.45, BACK + 0.04), "cream")
    _paw(b, 0.0, SY0 + SH / 2 - 0.05, BACK + 0.05, 1.5, FRAME)
    # the Legendary star and the Mythical gem on the bottom bar, under the face
    _star(b, -0.55, (Y_LO + SY0) / 2 - 0.02, FRONT - 0.05, 0.27, PIPE)
    _gem(b, 0.55, (Y_LO + SY0) / 2 - 0.02, FRONT - 0.05, 0.25, "rarity_mythic")


def _ears(b):
    zc, depth = (FRONT + BACK) / 2, BACK - FRONT
    for s in (-1, 1):
        xo, xi = s * HX, s * (HX - EAR_W)                                           # outer and inner base corners
        tip = (s * (HX - 0.55), Y_HI + EAR_H)
        b.fan_z(zc, tip, [(xi, Y_HI - 0.02), (xo, Y_HI - 0.02)], depth, FRAME)
        # the pink insides, front and back, and a gold edge up the outer side
        inner = [(s * (HX - EAR_W + 0.45), Y_HI + 0.05), (s * (HX - 0.2), Y_HI + 0.05)]
        itip = (s * (HX - 0.6), Y_HI + EAR_H - 0.45)
        for z, d in ((FRONT - 0.02, 0.05), (BACK + 0.02, 0.05)):
            b.fan_z(z, itip, inner, d, "fur_bubblegum")
    _paw(b, 0.0, Y_HI + 0.32, (FRONT + BACK) / 2, 1.0, PIPE, depth=0.14)                      # a paw standing on the brow
    b.span((-0.55, Y_HI - 0.01, FRONT + 0.1), (0.55, Y_HI + 0.12, BACK - 0.1), PIPE)    # its little plinth


def _whiskers(b):
    for s in (-1, 1):
        for i, a in enumerate((14, 0, -14)):
            y = SY0 + SH / 2 + 0.3 - i * 0.35
            L = 0.95
            x = s * (HX + L / 2 * math.cos(math.radians(a)) - 0.08)
            b.box((x, y + L / 2 * math.sin(math.radians(a)), (FRONT + BACK) / 2), (L, 0.09, 0.09), "cream",
                  rot=rot_z(a * s))


def _posts(b):
    for s in (-1, 1):
        x = s * POST_X
        b.span((x - 0.2, 0.0, -0.17), (x + 0.2, Y_LO + 0.01, 0.17), "dark_wood")
        b.span((x - 0.35, 0.0, -0.6), (x + 0.35, 0.22, 0.6), "dark_wood")            # feet
        b.span((x - 0.22, 0.6, -0.19), (x + 0.22, 0.85, 0.19), PIPE)                 # gold bands
        b.span((x - 0.22, 1.5, -0.19), (x + 0.22, 1.75, 0.19), PIPE)


def build_pity_sign(mat):
    b, screen = RB(), RB()
    _frame(b, screen)
    _ears(b)
    _whiskers(b)
    _posts(b)
    return [b.finalize(NAME, mat), screen.finalize(NAME + "_Screen", mat)]


ASSETS = {
    NAME: (build_pity_sign, 4000),
}
