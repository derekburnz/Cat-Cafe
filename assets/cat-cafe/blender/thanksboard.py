"""The Thank You board (#1083, idea-credits.md section 3): "A wooden board with a cat-paw header, 'Thank you for the
ideas!', in the Town Square near the Codes Cat ... a world SurfaceGui". Players whose idea we build are thanked on it
by display name, under a line about the idea in our words, newest 12 rows with an "Older ideas" arrow (the UI draws
all of that on the Screen).

  CatCafe_Street_ThanksBoard          two posts with feet and gold paw finials, a wooden frame round the face, a
                                      header plank reading THANK YOU over FOR THE IDEAS! between two paw prints, a
                                      little ledge under the face with two potted plants, a flower planter at each
                                      foot, and from behind a planked back with a painted heart and paw (collides)
    CatCafe_Street_ThanksBoard_Screen the 7.6 x 5.2 face, a part named Screen whose Front (-Z) face looks at the
                                      player; the UI's SurfaceGui (Adornee = Screen) draws the rows on it, so nothing
                                      stands in front of that face. Cream, so dark text reads on it day and night
    _Bulb                             the idea bulb on the crest above the header: lit at night
    _Flowers                          the planters' flowers

Pivot at the base centre on the paving, the face (-Z) toward the players. Footprint about 10.6 x 2.4 studs, 10.6 tall.
The root Model streams Atomic (rbx_export.MODEL_PROPS) so the Screen is there whenever the board is, and it carries the
ThanksBoard tag (rbx_export.TAGS). WorldBuilder places it at Layout.thanksBoard; the suggested spot is station(-15, -23)
(turned to face the cannon), the Corner Shop's mirror in the Codes Cat's quarter: it clears the Codes Cat and its circle
by 2.8 studs, the south sign arch by 3.5 and the street lane by 1.6.
"""

import math

from alleyway import flower_clump, label
from common import RB, text_width

NAME = "CatCafe_Street_ThanksBoard"
W, H = 7.6, 5.2                 # the Screen
Y0 = 2.2                        # its bottom, so its middle sits a little over a standing player's eye line
FZ = -0.15                      # its front face
F = 0.34                        # the frame's width round it
HX = W / 2 + F                  # the frame's outer half width
POST_X = HX + 0.28              # the posts' middles
HEAD_Y0, HEAD_Y1 = Y0 + H + F, Y0 + H + F + 1.6    # the header plank
TRIM, WOOD, FACE = "dark_wood", "caramel_wood", "cream"


def _paw(b, x, y, z, s, sw, facing=-1):
    """A paw print standing on a face at depth z; facing -1 for a -Z face, 1 for +Z."""
    d = 0.03 * facing
    b.cyl((x, y - 0.06 * s, z + d / 2), 0.2 * s, 0.03, sw, axis="Z", segments=8)
    for dx, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x + dx * s, y + dy * s, z + d / 2), 0.075 * s, 0.03, sw, axis="Z", segments=6)


def _posts(b):
    for sx in (-1, 1):
        x = sx * POST_X
        b.span((x - 0.22, 0, -0.22), (x + 0.22, HEAD_Y1 + 0.2, 0.22), TRIM)              # post
        b.span((x - 0.34, 0, -0.75), (x + 0.34, 0.22, 0.75), TRIM)                         # foot
        b.span((x - 0.26, HEAD_Y1 + 0.2, -0.26), (x + 0.26, HEAD_Y1 + 0.34, 0.26), "gold_mid")   # cap
        b.ball((x, HEAD_Y1 + 0.58, 0), 0.24, "gold_mid", scale=(1.0, 0.85, 0.7))           # paw finial: pad
        for dx in (-0.16, 0.0, 0.16):
            b.ball((x + dx, HEAD_Y1 + 0.86, -0.02), 0.09, "gold_light")                    # toes


def _board(b, screen):
    # the face, its frame, a back board and the planks seen from behind
    screen.span((-W / 2, Y0, FZ), (W / 2, Y0 + H, FZ + 0.06), FACE)
    b.span((-HX, Y0 - F, FZ + 0.06), (HX, Y0 + H + F, FZ + 0.3), WOOD)                     # back board
    for (xa, xb, ya, yb) in ((-HX, HX, Y0 - F, Y0), (-HX, HX, Y0 + H, Y0 + H + F),
                             (-HX, -W / 2, Y0, Y0 + H), (W / 2, HX, Y0, Y0 + H)):
        b.span((xa, ya, FZ - 0.1), (xb, yb, FZ + 0.06), TRIM)                              # frame, proud of the face
    for sx in (-1, 1):                                                                     # the board onto the posts
        x0, x1 = sorted((sx * (HX - 0.01), sx * POST_X))
        for y in (Y0 + 0.4, Y0 + H - 0.75):
            b.span((x0, y, -0.12), (x1, y + 0.35, 0.12), TRIM)
    bz = FZ + 0.31                                                                         # the back face
    for k in range(1, 8):                                                                  # planks from behind
        x = -HX + k * (2 * HX / 8)
        b.span((x - 0.03, Y0 - F + 0.05, bz - 0.01), (x + 0.03, Y0 + H + F - 0.05, bz + 0.02), TRIM)
    hx, hy = 0.0, Y0 + H / 2                                                               # a painted heart and paw
    b.ball((hx - 0.42, hy + 0.3, bz + 0.03), 0.55, "blush", scale=(1.0, 1.0, 0.06))
    b.ball((hx + 0.42, hy + 0.3, bz + 0.03), 0.55, "blush", scale=(1.0, 1.0, 0.06))
    b.box((hx, hy - 0.2, bz + 0.03), (0.95, 0.95, 0.05), "blush", rot=_rz(45))
    _paw(b, hx, hy + 0.05, bz + 0.05, 1.1, "cream", facing=1)


def _rz(deg):
    from plot import rot_z
    return rot_z(deg)


def _header(b):
    """The header plank over the frame: THANK YOU, FOR THE IDEAS! under it, a paw print either side."""
    hx = HX + 0.12
    z0, z1 = -0.3, FZ + 0.3
    b.span((-hx, HEAD_Y0, z0), (hx, HEAD_Y1, z1), WOOD)
    b.span((-hx - 0.06, HEAD_Y0 - 0.02, z0 - 0.04), (hx + 0.06, HEAD_Y0 + 0.14, z1 + 0.02), TRIM)   # bottom rail
    b.span((-hx - 0.06, HEAD_Y1 - 0.14, z0 - 0.04), (hx + 0.06, HEAD_Y1 + 0.02, z1 + 0.02), TRIM)   # top rail
    big, small = 0.15, 0.09
    zf = z0 - 0.005
    label(b, "THANK YOU", 0, HEAD_Y0 + 0.68, zf, big, 0.05, FACE, -1)         # 5 px tall: to 1.43
    label(b, "FOR THE IDEAS!", 0, HEAD_Y0 + 0.16, zf, small, 0.05, "pastel_butter", -1)   # to 0.61
    edge = text_width("THANK YOU", big) / 2 + 0.75
    for sx in (-1, 1):
        _paw(b, sx * edge, HEAD_Y0 + 0.8, zf, 1.25, "blush")
    zb = z1 + 0.005                                                                        # its back: a paw each end
    for sx in (-1, 1):
        _paw(b, sx * (hx - 0.8), HEAD_Y0 + 0.72, zb, 1.25, "cream", facing=1)
    b.span((-1.6, HEAD_Y0 + 0.5, zb - 0.01), (1.6, HEAD_Y0 + 0.95, zb + 0.03), "blush")   # a painted ribbon


def _crest(b, bulb):
    """The idea bulb over the header: a brass screw base on a gold stand, the bulb lit at night."""
    y = HEAD_Y1 + 0.02
    b.span((-0.75, y, -0.2), (0.75, y + 0.18, 0.2), "gold_mid")                           # stand
    b.cyl((0, y + 0.32, -0.02), 0.2, 0.28, "brass", segments=10)                            # screw base
    for k in range(3):
        b.cyl((0, y + 0.22 + k * 0.09, -0.02), 0.215, 0.03, "gold_dark", segments=10)       # its threads
    bulb.ball((0, y + 0.78, -0.02), 0.42, "lamp_warm", scale=(1.0, 1.1, 1.0))               # the bulb
def _ledge(b):
    """A little ledge under the face with two potted plants."""
    y = Y0 - F
    b.span((-HX + 0.3, y - 0.12, -0.55), (HX - 0.3, y, FZ + 0.06), WOOD)
    b.span((-HX + 0.3, y - 0.32, -0.12), (HX - 0.3, y - 0.12, FZ + 0.06), TRIM)            # its bracket rail
    for x in (-HX + 0.85, HX - 0.85):
        b.cyl((x, y + 0.2, -0.33), 0.17, 0.4, "terracotta", segments=8)
        b.cyl((x, y + 0.42, -0.33), 0.19, 0.06, "choco", segments=8)
        for dx, dy, r in ((0.0, 0.62, 0.17), (-0.1, 0.55, 0.12), (0.11, 0.56, 0.12)):
            b.ball((x + dx, y + dy, -0.33), r, "leaf_green")


def _planters(b, flowers):
    for sx in (-1, 1):
        x = sx * (POST_X + 0.95)
        b.span((x - 0.55, 0, -0.55), (x + 0.55, 0.7, 0.55), "terracotta")
        b.span((x - 0.62, 0.62, -0.62), (x + 0.62, 0.78, 0.62), "cream")
        b.span((x - 0.48, 0.62, -0.48), (x + 0.48, 0.74, 0.48), "choco")
        for dx, dz in ((-0.25, -0.2), (0.22, -0.18), (0.0, 0.2)):
            b.ball((x + dx, 0.98, dz), 0.26, "leaf_green")
        flower_clump(flowers, x, 1.1, 0.0, spread=0.62)


def build_thanks_board(mat):
    b, screen, bulb, flowers = RB(), RB(), RB(), RB()
    _posts(b)
    _board(b, screen)
    _header(b)
    _crest(b, bulb)
    _ledge(b)
    _planters(b, flowers)
    return [b.finalize(NAME, mat), screen.finalize(NAME + "_Screen", mat), bulb.finalize(NAME + "_Bulb", mat),
            flowers.finalize(NAME + "_Flowers", mat)]


ASSETS = {
    NAME: (build_thanks_board, 6000),
}
