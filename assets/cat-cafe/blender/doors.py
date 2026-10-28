"""The cafe's own back door (Derek 2026-10-28 01:28: a real door where the back door opening is, players walk
through it, cats use a flap in it).

  CatCafe_Plot_BackDoor            a panelled wooden door hung in the back door opening (x -11..-5, 7.5 high, in the
                                   back wall z 14..15), with a cat flap low in the middle; place it at the Plot's
                                   pivot like the other plot pieces (and like CatCafe_Plot_BackDoorClosed)

Model layout (rbx_export):
  CatCafe_Plot_BackDoor                      the threshold and the inside architrave (they stay put)
    CatCafe_Plot_BackDoor_Leaf               the door leaf, modelled shut; its pivot is the hinge, at the opening's
                                             x -10.88 on the leaf's yard face (z 14.72), so turning the pivot about
                                             its Y swings the leaf: -90 degrees is wide open, out into the yard,
                                             flat along the jamb. A `CatFlap` Attachment sits at the foot of its
                                             yard face in the middle (x -8), facing the yard, where an F80 flap goes
      CatCafe_Plot_BackDoor_Leaf_Glass       the four panes in its window
      CatCafe_Plot_BackDoor_Flap             the default cat flap's swinging panel, pivot on its top hinge: turn it
                                             about its X (up to about 60 degrees either way) as a cat goes through
      CatCafe_Plot_BackDoor_Sign             "CLOSED / UNTIL SUNRISE" hung on the leaf's yard face, for the night
      CatCafe_Plot_BackDoor_Sign_Bulb        the sign's letters and moon (_Bulb: Neon at night)
The flap's surround is part of the leaf. Nothing here needs to collide: the code-built back door panel stays the
collider, made invisible.
"""

import math

from mathutils import Matrix, Vector

from alleyway import label
from common import RB, text_width
from plot import BACK, BACK_DOOR

NAME = "CatCafe_Plot_BackDoor"
X0, X1, DH = BACK_DOOR                          # the opening: x -11..-5, 7.5 high
HX, HZ = X0 + 0.12, BACK - 0.28                 # the hinge: the leaf's yard face, at its hinge edge
LW, LY0, LY1, LT = X1 - X0 - 0.15, 0.22, DH - 0.05, 0.3    # leaf width, bottom (clear of a Tier 4 deck), top, thickness
FC, FW, FY0, FY1 = (X1 - X0) / 2 - 0.12, 1.8, 0.45, 2.35   # flap: centre (leaf x), width, bottom and top of its hole
WIN = (0.8, LW - 0.8, 4.3, 6.9)                # the window in the leaf: x0, x1, y0, y1
WOOD, MOULD, TRIM, IRON, BRASS = "caramel_wood", "treat_tan", "offwhite", "fur_black", "brass"
SIGN_BOARD, SIGN_INK, SIGN_GLOW = "night_sky", "offwhite", "pastel_butter"


def _frame(b, x0, x1, y0, y1, t, z0, z1, swatch):
    """A rectangular outline t wide from (x0, y0) to (x1, y1), between depths z0 and z1."""
    b.span((x0, y0, z0), (x0 + t, y1, z1), swatch)
    b.span((x1 - t, y0, z0), (x1, y1, z1), swatch)
    b.span((x0 + t, y0, z0), (x1 - t, y0 + t, z1), swatch)
    b.span((x0 + t, y1 - t, z0), (x1 - t, y1, z1), swatch)


def _leaf(b, glass):
    """The leaf in its own frame: x 0..LW from the hinge, y up, z -LT..0 with z 0 its yard face."""
    fx0, fx1 = FC - FW / 2, FC + FW / 2
    wx0, wx1, wy0, wy1 = WIN
    b.span((0, LY0, -LT), (LW, FY0, 0), WOOD)                                  # bottom rail, under the flap
    b.span((0, FY0, -LT), (fx0, FY1, 0), WOOD)                                 # either side of the flap
    b.span((fx1, FY0, -LT), (LW, FY1, 0), WOOD)
    b.span((0, FY1, -LT), (LW, wy0, 0), WOOD)                                  # lock rail
    b.span((0, wy0, -LT), (wx0, wy1, 0), WOOD)                                 # window stiles and top rail
    b.span((wx1, wy0, -LT), (LW, wy1, 0), WOOD)
    b.span((0, wy1, -LT), (LW, LY1, 0), WOOD)
    # four panes behind glazing bars, a putty bead round them on both faces
    glass.span((wx0, wy0, -0.17), (wx1, wy1, -0.13), "glass")
    cx, cy = (wx0 + wx1) / 2, (wy0 + wy1) / 2
    b.span((cx - 0.07, wy0, -0.21), (cx + 0.07, wy1, -0.09), TRIM)
    b.span((wx0, cy - 0.07, -0.21), (cx - 0.07, cy + 0.07, -0.09), TRIM)
    b.span((cx + 0.07, cy - 0.07, -0.21), (wx1, cy + 0.07, -0.09), TRIM)
    for (z0, z1) in ((-0.06, 0.0), (-LT, -LT + 0.06)):                         # putty beads, inside the opening
        _frame(b, wx0, wx1, wy0, wy1, 0.12, z0, z1, TRIM)
    # a raised moulding on both faces across the lock rail, short of the handle
    for (z0, z1) in ((0.0, 0.06), (-LT - 0.06, -LT)):
        _frame(b, 0.45, LW - 1.1, FY1 + 0.5, wy0 - 0.35, 0.14, z0, z1, MOULD)
    # the flap's surround on both faces, a little hood over it on the yard side
    for (z0, z1) in ((0.0, 0.08), (-LT - 0.08, -LT)):
        _frame(b, fx0 - 0.18, fx1 + 0.18, FY0 - 0.15, FY1 + 0.18, 0.18, z0, z1, TRIM)
    b.span((fx0 - 0.3, FY1 + 0.18, 0.0), (fx1 + 0.3, FY1 + 0.36, 0.24), TRIM)
    # iron strap hinges with their knuckles on the hinge edge, a brass lever handle each side, a keyhole
    for y in (0.95, LY1 - 0.47):
        b.span((0.02, y, 0.0), (1.55, y + 0.24, 0.04), IRON)
        b.cyl((0.0, y + 0.12, 0.0), 0.08, 0.42, IRON, axis="Y", segments=8)
    hx = LW - 0.55
    for (zf, s) in ((0.0, 1), (-LT, -1)):                                     # each face, s its outward side
        b.cyl((hx, 3.3, zf + s * 0.04), 0.17, 0.08, BRASS, axis="Z", segments=10)
        b.span((hx - 0.08, 3.24, min(zf, zf + s * 0.17)), (hx + 0.08, 3.36, max(zf, zf + s * 0.17)), BRASS)
        b.span((hx - 0.62, 3.24, zf + s * 0.17 - 0.06), (hx + 0.02, 3.36, zf + s * 0.17 + 0.06), BRASS)
        b.span((hx - 0.05, 2.75, min(zf, zf + s * 0.03)), (hx + 0.05, 2.95, max(zf, zf + s * 0.03)), IRON)


def _flap(b):
    """The flap's panel in its own frame: hung from its top hinge (y 0), hanging to y -(FY1 - FY0), faced with a
    paw print on its yard side (+Z)."""
    h = FY1 - FY0
    b.span((-FW / 2 + 0.03, -h + 0.03, -0.03), (FW / 2 - 0.03, -0.02, 0.03), "fur_charcoal")
    b.cyl((0, -0.02, 0), 0.06, FW - 0.04, "metal", axis="X", segments=8)
    b.span((-0.27, -h + 0.42, 0.03), (0.27, -h + 0.84, 0.05), TRIM)                         # pad
    for (x, y) in ((-0.36, -h + 1.0), (-0.12, -h + 1.14), (0.12, -h + 1.14), (0.36, -h + 1.0)):
        b.span((x - 0.09, y - 0.09, 0.03), (x + 0.09, y + 0.09, 0.05), TRIM)                # toes


def _sign(b, glow):
    """The night sign on the leaf's yard face, hung from a nail in the top rail over the window."""
    big, small, px, spx, moon = "CLOSED", "UNTIL SUNRISE", 0.13, 0.07, 0.22
    cx = LW / 2
    w = 0.3 + 2 * moon + 0.15 + text_width(big, px) + 0.3      # the moon, then CLOSED beside it on the top line
    left = cx - w / 2
    y0, y1, nail = 4.55, 6.45, LY1 - 0.3
    z = 0.1                                                     # the board's back, clear of the window bead
    b.span((left, y0, z), (left + w, y1, z + 0.12), SIGN_BOARD)
    _frame(b, left - 0.1, left + w + 0.1, y0 - 0.1, y1 + 0.1, 0.1, z, z + 0.14, SIGN_INK)
    b.span((cx - 0.06, nail - 0.06, 0.0), (cx + 0.06, nail + 0.06, 0.26), "metal")
    for sx in (-1, 1):
        dx, dy = w / 4, nail - y1 - 0.1
        b.box((cx + sx * dx / 2, (y1 + 0.1 + nail) / 2, z + 0.07), (0.05, math.hypot(dx, dy) + 0.05, 0.05), "fur_black",
              rot=Matrix.Rotation(sx * math.atan2(dx, dy), 3, "Z"))
    big_y = y0 + 0.85
    label(glow, big, left + 0.3 + 2 * moon + 0.15 + text_width(big, px) / 2, big_y, z + 0.12, px, 0.04, SIGN_INK, 1)
    label(glow, small, cx, y0 + 0.28, z + 0.12, spx, 0.04, SIGN_GLOW, 1)
    glow.b.crescent(RB.p(left + 0.3 + moon, big_y + 2.5 * px, z + 0.14), moon, 0.14, 0.04, SIGN_GLOW)


def build_back_door(mat):
    b, leaf, glass, flap, sign, glow = RB(), RB(), RB(), RB(), RB(), RB()
    # the threshold, and the inside architrave the shell's doorway lacks (its outside frame is the shell's)
    b.span((X0 + 0.01, 0.0, BACK - 1.0), (X1 - 0.01, 0.08, BACK - 0.02), "dark_wood")
    zi = BACK - 1.0                                             # the wall's inside face
    # the architrave stands 0.32 proud of it, past the Interior's dado rail, and covers the wainscot's ends
    b.span((X0 - 0.45, 0.0, zi - 0.32), (X0 + 0.02, DH + 0.45, zi), TRIM)
    b.span((X1 - 0.02, 0.0, zi - 0.32), (X1 + 0.45, DH + 0.45, zi), TRIM)
    b.span((X0 + 0.02, DH + 0.01, zi - 0.32), (X1 - 0.02, DH + 0.45, zi), TRIM)
    _leaf(leaf, glass)
    _flap(flap)
    _sign(sign, glow)
    hinge = (HX, 0.0, HZ)
    flap_at = (HX + FC, FY1, HZ - LT / 2)
    return [b.finalize(NAME, mat), leaf.finalize(NAME + "_Leaf", mat, location=hinge),
            glass.finalize(NAME + "_Leaf_Glass", mat, location=hinge),
            flap.finalize(NAME + "_Flap", mat, location=flap_at),
            sign.finalize(NAME + "_Sign", mat, location=hinge), glow.finalize(NAME + "_Sign_Bulb", mat, location=hinge)]


def cat_flap_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: CatFlap at the foot of the shut leaf's yard face,
    in the middle, turned so its -Z (an F80 flap's front) faces the yard (+Z in plot space)."""
    at = Vector(RB.p(HX + FC, LY0, HZ))
    return ("_Leaf", "CatFlap", Matrix.Translation(at) @ Matrix.Rotation(math.pi, 4, "Z"))


NEST = {"_Leaf_Glass": "_Leaf", "_Flap": "_Leaf", "_Sign": "_Leaf", "_Sign_Bulb": "_Leaf"}

ASSETS = {
    NAME: (build_back_door, 4000),
}
