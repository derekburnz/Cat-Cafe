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
      CatCafe_Plot_BackDoor_FlapFrame        the default flap's surround and hood (hide it with _Flap when an F80
                                             flap, which brings its own frame, is in use)
      CatCafe_Plot_BackDoor_Flap             the default cat flap's swinging panel, pivot on its top hinge: turn it
                                             about its X (up to about 60 degrees either way) as a cat goes through
      CatCafe_Plot_BackDoor_Sign             "CLOSED / UNTIL SUNRISE" on the leaf's lock rail, for the night
      CatCafe_Plot_BackDoor_Sign_Bulb        the sign's letters and moon (_Bulb: Neon at night)
Nothing here needs to collide: the code-built back door panel stays the
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


def _flap_frame(b):
    """The flap's surround on both faces of the leaf and a little hood over it on the yard side, in the leaf's frame.
    Its own object, so the game can hide it with the panel when an F80 flap (which brings its own frame) is in use."""
    fx0, fx1 = FC - FW / 2, FC + FW / 2
    for (z0, z1) in ((0.0, 0.08), (-LT - 0.08, -LT)):
        _frame(b, fx0 - 0.18, fx1 + 0.18, FY0 - 0.15, FY1 + 0.18, 0.18, z0, z1, TRIM)
    b.span((fx0 - 0.3, FY1 + 0.18, 0.0), (fx1 + 0.3, FY1 + 0.36, 0.24), TRIM)


def _flap(b):
    """The flap's panel in its own frame: hung from its top hinge (y 0), hanging to y -(FY1 - FY0), faced with a
    paw print on its yard side (+Z)."""
    h = FY1 - FY0
    b.span((-FW / 2 + 0.03, -h + 0.03, -0.03), (FW / 2 - 0.03, -0.02, 0.03), "fur_charcoal")
    b.cyl((0, -0.02, 0), 0.06, FW - 0.04, "metal", axis="X", segments=8)
    b.span((-0.27, -h + 0.42, 0.03), (0.27, -h + 0.84, 0.05), TRIM)                         # pad
    for (x, y) in ((-0.36, -h + 1.0), (-0.12, -h + 1.14), (0.12, -h + 1.14), (0.36, -h + 1.0)):
        b.span((x - 0.09, y - 0.09, 0.03), (x + 0.09, y + 0.09, 0.05), TRIM)                # toes


MOON = ("..##.....", ".##......", "###......", "###......", "###......", "###......", "###......", ".####....",
        "..#####..")                             # the front ClosedSign's moon: from the front, horns toward the text


def _sign(b, glow, z=0.06, y0=3.1, bh=1.1, cu=2.6, both=False, face=0.0):
    """The night sign on the leaf's yard face (Derek 2026-10-30: it showed through the window and its moon faced the
    wrong way). A board bh tall from y0 on the lock rail, under the window and over any F80 flap (they stay under
    y 2.97), clear of the handle; its back at depth z, on short posts back to depth `face` (the leaf's face there)
    when it stands off it.
    The moon reads like the front ClosedSign's: left of CLOSED with its horns toward the text. both: the sign hangs
    over glass, so its back reads CLOSED too (seen from inside through the window)."""
    big, small, px, spx, mp, t = "CLOSED", "UNTIL SUNRISE", 0.095, 0.048, 0.09, 0.08
    tw, sw = text_width(big, px), text_width(small, spx)
    mw = 7 * mp                                                   # the moon's width (its widest row)
    bw = 0.15 + mw + 0.18 + max(tw, sw) + 0.15
    left, y1 = cu - bw / 2, y0 + bh
    b.span((left, y0, z), (left + bw, y1, z + 0.12), SIGN_BOARD)
    _frame(b, left - t, left + bw + t, y0 - t, y1 + t, t, z, z + 0.14, SIGN_INK)
    for x in (left - t / 2, left + bw + t / 2):                   # brass screws in the frame's corners, and posts
        for y in (y0 - t / 2, y1 + t / 2):                       # behind them when the board stands off the face
            b.span((x - 0.03, y - 0.03, z + 0.14), (x + 0.03, y + 0.03, z + 0.16), "brass")
            if z - face > 0.005:
                b.span((x - 0.04, y - 0.04, face), (x + 0.04, y + 0.04, z), "metal")
    block = 5 * spx + 0.1 + 5 * px                                # UNTIL SUNRISE under CLOSED, the two centred
    ys = y0 + (bh - block) / 2
    yb = ys + 5 * spx + 0.1
    tx = left + 0.15 + mw + 0.18 + max(tw, sw) / 2
    mtop = y0 + bh / 2 + 4.5 * mp
    faces = ((z + 0.12, 1, 1),) + (((z, -1, -1),) if both else ())
    for zf, s, facing in faces:                                   # facing 1: read from the yard (+Z)
        # from the back the sign reads mirrored in x: the moon on the right of the text as seen from inside
        mx = (lambda x: x) if facing > 0 else (lambda x: 2 * cu - x)
        label(b, big, mx(tx), yb, zf, px, 0.03, SIGN_INK, facing)
        if facing > 0:                                            # the back keeps to CLOSED and the moon
            label(glow, small, mx(tx), ys, zf, spx, 0.03, SIGN_GLOW, facing)
        for r, row in enumerate(MOON):
            for c, ch in enumerate(row):
                if ch == "#":
                    x = mx(left + 0.15 + (c + 0.5) * mp)
                    glow.span((x - mp / 2, mtop - (r + 1) * mp, min(zf, zf + s * 0.03)),
                              (x + mp / 2, mtop - r * mp, max(zf, zf + s * 0.03)), SIGN_GLOW)


def build_back_door(mat):
    b, leaf, glass, frame, flap, sign, glow = RB(), RB(), RB(), RB(), RB(), RB(), RB()
    # the threshold, and the inside architrave the shell's doorway lacks (its outside frame is the shell's)
    b.span((X0 + 0.01, 0.0, BACK - 1.0), (X1 - 0.01, 0.08, BACK - 0.02), "dark_wood")
    zi = BACK - 1.0                                             # the wall's inside face
    # the architrave stands 0.32 proud of it, past the Interior's dado rail, and covers the wainscot's ends
    b.span((X0 - 0.45, 0.0, zi - 0.32), (X0 + 0.02, DH + 0.45, zi), TRIM)
    b.span((X1 - 0.02, 0.0, zi - 0.32), (X1 + 0.45, DH + 0.45, zi), TRIM)
    b.span((X0 + 0.02, DH + 0.01, zi - 0.32), (X1 - 0.02, DH + 0.45, zi), TRIM)
    _leaf(leaf, glass)
    _flap_frame(frame)
    _flap(flap)
    _sign(sign, glow)
    hinge = (HX, 0.0, HZ)
    flap_at = (HX + FC, FY1, HZ - LT / 2)
    return [b.finalize(NAME, mat), leaf.finalize(NAME + "_Leaf", mat, location=hinge),
            glass.finalize(NAME + "_Leaf_Glass", mat, location=hinge),
            frame.finalize(NAME + "_FlapFrame", mat, location=hinge),
            flap.finalize(NAME + "_Flap", mat, location=flap_at),
            sign.finalize(NAME + "_Sign", mat, location=hinge), glow.finalize(NAME + "_Sign_Bulb", mat, location=hinge)]


def cat_flap_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: CatFlap at the foot of the shut leaf's yard face,
    in the middle, turned so its -Z (an F80 flap's front) faces the yard (+Z in plot space)."""
    at = Vector(RB.p(HX + FC, LY0, HZ))
    return ("_Leaf", "CatFlap", Matrix.Translation(at) @ Matrix.Rotation(math.pi, 4, "Z"))


NEST = {"_Leaf_Glass": "_Leaf", "_FlapFrame": "_Leaf", "_Flap": "_Leaf", "_Sign": "_Leaf", "_Sign_Bulb": "_Leaf"}

ASSETS = {
    NAME: (build_back_door, 4000),
}
