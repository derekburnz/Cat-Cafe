"""The update poster (#4362): a poster stand on the Town Square that shows the next update (Config.UpdateEvents): its
picture, its name, a countdown and a "Notify Me" tap. A wide wooden frame with gold piping round a dark face, a gold
bell on top between two little pennants (the bell is Roblox's Notify Me sign), on two posts with feet. From behind
the face is planked with a painted bell.

  CatCafe_Square_UpdatePoster       frame, bell, pennants, posts, back (collides)
    Screen                          the 8.0 x 4.5 face (16:9, the _Screen object), Front (-Z) toward the player: the
                                    UI's SurfaceGui (Adornee = Screen) draws the update's picture and words, so
                                    nothing stands in front of it. Night blue while the picture loads

Pivot at the base centre on the square's floor top (y 0.1), front -Z. Footprint about 9.3 x 1.2 studs, 9.2 tall. The
root Model streams Atomic (rbx_export.MODEL_PROPS) so the Screen is there whenever the stand is. The suggested spot is
SPOT: see its comment.
"""

import math

from common import RB
from pitysign import _paw

NAME = "CatCafe_Square_UpdatePoster"

SW, SH = 8.0, 4.5                   # the Screen, 16:9
SY0 = 2.6                           # its bottom
FZ = -0.2                           # its front face
F = 0.4                             # the frame round it
HX = SW / 2 + F
Y_LO, Y_HI = SY0 - F, SY0 + SH + F
FRONT, BACK = -0.35, 0.3
FRAME, PIPE = "caramel_wood", "rarity_legend"
POST_X = SW / 2 - 0.7

# Model-Agent's spot (world x, y, z, rotY): the pity sign's mirror in the south-west quarter (pitysign.SPOT is at
# x 13.5, z -23), turned to face the spawn (0, -14), so a player who lands sees the rare cat sign on one side and the
# next update on the other. The server's Layout owns the final spot.
SPOT = (-13.5, 0.1, -23.0, math.degrees(math.atan2(-(0 - -13.5), -(-14 - -23.0))))


def _frame(b, screen):
    screen.span((-SW / 2, SY0, FZ), (SW / 2, SY0 + SH, 0.05), "night_sky")
    b.span((-SW / 2, SY0, 0.05), (SW / 2, SY0 + SH, BACK), "caramel_wood")
    for (x0, x1, y0, y1) in ((-HX, HX, Y_LO, SY0), (-HX, HX, SY0 + SH, Y_HI),
                             (-HX, -SW / 2, SY0, SY0 + SH), (SW / 2, HX, SY0, SY0 + SH)):
        b.span((x0, y0, FRONT), (x1, y1, BACK), FRAME)
    for (x0, x1, y0, y1) in ((-SW / 2 - 0.12, SW / 2 + 0.12, SY0 - 0.12, SY0),
                             (-SW / 2 - 0.12, SW / 2 + 0.12, SY0 + SH, SY0 + SH + 0.12),
                             (-SW / 2 - 0.12, -SW / 2, SY0, SY0 + SH), (SW / 2, SW / 2 + 0.12, SY0, SY0 + SH)):
        b.span((x0, y0, FRONT - 0.045), (x1, y1, FRONT - 0.005), PIPE)
    # gold corner studs on the frame's front
    for sx in (-1, 1):
        for y in (Y_LO + F / 2, Y_HI - F / 2):
            b.cyl((sx * (HX - F / 2), y, FRONT - 0.03), 0.13, 0.06, PIPE, axis="Z", segments=8)
    # the back: planks, a cream panel and a painted paw
    for i in range(1, 8):
        x = -SW / 2 + i * SW / 8
        b.span((x - 0.04, SY0 + 0.1, BACK - 0.01), (x + 0.04, SY0 + SH - 0.1, BACK + 0.02), "dark_wood")
    b.span((-1.1, SY0 + 1.1, BACK + 0.01), (1.1, SY0 + SH - 1.1, BACK + 0.04), "cream")
    _paw(b, 0.0, SY0 + SH / 2 - 0.05, BACK + 0.05, 2.0, "aurora_violet")


def _bell(b):
    """A gold bell standing on the frame's top, between two pennants."""
    zc = (FRONT + BACK) / 2
    y = Y_HI
    b.span((-0.75, y - 0.01, FRONT + 0.08), (0.75, y + 0.14, BACK - 0.08), PIPE)          # its plinth
    b.cyl((0.0, y + 0.26, zc), 0.62, 0.22, PIPE, axis="Y", segments=10)                    # the lip
    b.cyl((0.0, y + 0.62, zc), 0.5, 0.56, PIPE, axis="Y", segments=10)                     # the body
    b.cyl((0.0, y + 1.0, zc), 0.36, 0.3, PIPE, axis="Y", segments=10)                      # the shoulder
    b.cyl((0.0, y + 1.22, zc), 0.14, 0.2, PIPE, axis="Y", segments=8)                      # the crown
    b.cyl((0.0, y + 0.12, zc), 0.16, 0.16, "dark_wood", axis="Y", segments=8)              # the clapper
    for s in (-1, 1):                                                                      # pennants on short poles
        x = s * (HX - 0.9)
        b.span((x - 0.07, y - 0.01, zc - 0.07), (x + 0.07, y + 1.15, zc + 0.07), "dark_wood")
        b.fan_z(zc, (x + s * 0.85, y + 0.85), [(x + s * 0.07, y + 1.12), (x + s * 0.07, y + 0.58)], 0.06,
                "fur_bubblegum" if s < 0 else "aurora_violet")


def _posts(b):
    for s in (-1, 1):
        x = s * POST_X
        b.span((x - 0.22, 0.0, -0.18), (x + 0.22, Y_LO + 0.01, 0.18), "dark_wood")
        b.span((x - 0.38, 0.0, -0.6), (x + 0.38, 0.22, 0.6), "dark_wood")
        b.span((x - 0.24, 0.6, -0.2), (x + 0.24, 0.85, 0.2), PIPE)
        b.span((x - 0.24, 1.45, -0.2), (x + 0.24, 1.7, 0.2), PIPE)
    b.span((-POST_X, 1.0, -0.08), (POST_X, 1.2, 0.08), "dark_wood")                       # a cross rail


def build_update_poster(mat):
    b, screen = RB(), RB()
    _frame(b, screen)
    _bell(b)
    _posts(b)
    return [b.finalize(NAME, mat), screen.finalize(NAME + "_Screen", mat)]


ASSETS = {
    NAME: (build_update_poster, 4000),
}
