"""Cafe sign styles sold in the shop packs (#1191, Design-Agent's briefs on #1191): each a board, a frame and its
decoration over the cafe's name sign, and King Croissant's crest for the sign's corner. CafeSigns (UI) draws the
cafe's name on whichever part named SignBoard it finds, so each style carries its own SignBoard, a hair in front of
the shell's (plot.SIGN_INFO), and the name colour is the UI's (cream on the Royal Crest, cocoa on Bakery Stripes).

  CatCafe_Plot_SignRoyalCrest            the King Cat Pack's style: a deep royal_berry board (the SignBoard part),
                                          a raised gold frame round it (`_Frame`, its own part so VFX can sweep a
                                          shine across it every 8 s), a jewel dot at each frame corner and a gold
                                          crest over the top centre, a crown resting on a croissant
  CatCafe_Plot_SignBakeryStripes         the Starter Bundle's style: a cream board (SignBoard) in a pastel pink and
                                          cream striped frame with painted sprinkles on it, a striped bakery awning
                                          valance with scallops over the board and a little cupcake beside its left
                                          end; no effect (the brief keeps it plain so the bigger packs stay special)
  CatCafe_Plot_SignKingCrest             King Croissant's mark, shown on the owner's sign while he works (the plot's
                                          KingCroissantWorking attribute): the same gold croissant-and-crown crest,
                                          small, standing proud of the sign's top right corner. Deliberately not the
                                          crown emoji the leaderboard crowns use on signs (Screens/Crowns.luau)
  CatCafe_Plot_SignGoldenLeaf            the Cafe Pass season 1 name plate frame (cafe-pass.md section 3, level 29): a
                                          warm russet board (SignBoard; cream name text reads best on it), a gold
                                          frame round it (`_Frame`, its own part like the Royal Crest's) with a gold
                                          maple leaf on each corner, and a cluster of three maple leaves in gold,
                                          rust and orange with two acorns over the top centre

Every model is placed at the Plot's pivot like the tier sets (Plot.cframe: floor top centre, -Z toward the street)
with no offset; WorldBuilder or the UI shows the one the plot uses. Nothing collides (the signs are high on the
gable). Roblox axes through common.RB.
"""

import math

from mathutils import Matrix

from common import RB
from plot import FRONT, SIGN, arc
from seasondecor import maple_leaf

X0, X1, Y0, Y1 = SIGN                       # the shell's board: x -8 to 8, y 13.4 to 16.6, its face at FRONT - 0.35
FACE = FRONT - 0.38                          # a style's board face, 0.03 in front of the shell's
GOLD, GOLD_LT, GOLD_DK = "gold_mid", "gold_light", "gold_dark"


def _crest(b, cx, cy, z, s):
    """A crown resting on a croissant, s studs wide, standing on the plane z (its back) and facing -Z, centred on
    (cx, cy): the croissant's five lobes, the crown's band with three points and a jewel each."""
    d = 0.12 * s                                                                    # how far it stands out
    for i in range(5):                                                              # the croissant, a soft arc
        t = (i - 2) / 2
        w = (0.26 - 0.05 * abs(i - 2)) * s
        h = (0.3 - 0.06 * abs(i - 2)) * s
        b.box((cx + t * 0.36 * s, cy - 0.12 * s + 0.07 * s * abs(t), z - d / 2), (w, h, d), GOLD,
              rot=_rz(-t * 18))
    b.span((cx - 0.28 * s, cy + 0.05 * s, z - d * 1.25), (cx + 0.28 * s, cy + 0.17 * s, z - d * 0.25), GOLD_LT)  # band
    for i, x in enumerate((-0.2, 0.0, 0.2)):                                        # points with jewels
        h = (0.32 if i == 1 else 0.24) * s
        base = cy + 0.17 * s - 0.01 * s                                             # a hair into the band
        b.fan_z(z - d * 0.75, (cx + x * s, base + h),
                [(cx + (x - 0.1) * s, base), (cx + (x + 0.1) * s, base)], d * 0.9, GOLD_LT)
        b.cyl((cx + x * s, base + h + 0.02 * s, z - d * 0.75), 0.05 * s, d * 1.1,   # proud of the point
              ("bowl_red", "shirt_blue", "leaf_green")[i], axis="Z", segments=8)


def _rz(deg):
    from plot import rot_z
    return rot_z(deg)


def build_royal_crest(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "royal_berry")                       # SignBoard, 0.1 thick
    f, zf, zb = 0.45, FACE - 0.14, FACE + 0.1                                               # the raised gold frame
    for (xa, xb, ya, yb) in ((X0 - f, X1 + f, Y0 - f, Y0), (X0 - f, X1 + f, Y1, Y1 + f),
                             (X0 - f, X0, Y0, Y1), (X1, X1 + f, Y0, Y1)):
        frame.span((xa, ya, zf), (xb, yb, zb), GOLD)
    for sx in (-1, 1):                                                                      # jewel dots at the corners
        for sy, y in ((-1, Y0 - f / 2), (1, Y1 + f / 2)):
            b.cyl((sx * (X1 + f / 2), y, zf - 0.04), 0.14, 0.08, "bowl_red" if sy > 0 else "shirt_blue", axis="Z",
                  segments=10)
    b.span((-1.5, Y1 + f, zf + 0.02), (1.5, Y1 + f + 0.12, zb), GOLD)                       # the crest's plinth
    cy = Y1 + f + 1.0
    b.cyl((0.0, cy, zf + 0.12), 1.0, 0.24, GOLD, axis="Z", segments=20)                     # its medallion,
    b.cyl((0.0, cy, zf - 0.02), 0.85, 0.06, "royal_berry", axis="Z", segments=20)           # berry in a gold ring
    _crest(b, 0.0, cy - 0.05, zf - 0.05, 1.6)
    return [b.finalize("CatCafe_Plot_SignRoyalCrest", mat), board.finalize("CatCafe_Plot_SignRoyalCrest_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignRoyalCrest_Frame", mat)]


SPRINKLES = ("neon_pink", "sign_teal", "rarity_legend", "shirt_blue", "mint")


def build_bakery_stripes(mat):
    b, board = RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "cream")                              # SignBoard
    f, zf, zb = 0.4, FACE - 0.1, FACE + 0.1
    n = 24                                                                                  # striped frame, top and bottom
    w = (X1 - X0 + 2 * f) / n
    for k in range(n):
        sw = "apron_pink" if k % 2 == 0 else "offwhite"
        x = X0 - f + k * w
        b.span((x, Y0 - f, zf), (x + w, Y0, zb), sw)
        b.span((x, Y1, zf), (x + w, Y1 + f, zb), sw)
    for xa, xb in ((X0 - f, X0), (X1, X1 + f)):                                             # and its ends
        for k in range(4):
            y = Y0 + k * (Y1 - Y0) / 4
            b.span((xa, y, zf), (xb, y + (Y1 - Y0) / 4, zb), "apron_pink" if k % 2 == 0 else "offwhite")
    i = 0
    for k in range(n):                                                                      # sprinkles on the frame
        x = X0 - f + (k + 0.5) * w
        for y, a in ((Y0 - f / 2, 30 + 40 * (k % 3)), (Y1 + f / 2, -20 - 35 * (k % 3))):
            b.box((x, y, zf - 0.015), (0.2, 0.07, 0.03), SPRINKLES[i % len(SPRINKLES)], rot=_rz(a))
            i += 1
    # the bakery awning's valance over the board: a striped board hung flat from the head rail, a scallop under
    # each stripe
    top, drop = Y1 + f + 1.0, 0.7
    zv0, zv1 = FRONT - 0.42, FRONT - 0.3
    m = 12
    vw = (X1 - X0 + 2 * f + 0.6) / m
    for k in range(m):
        sw = "apron_pink" if k % 2 == 0 else "offwhite"
        x = X0 - f - 0.3 + k * vw
        b.span((x, top - drop, zv0), (x + vw, top - 0.14, zv1), sw)                           # stripe
        sx, sy = x + vw / 2, top - drop + 0.01                                              # scallop, a hair up into it
        b.fan_z((zv0 + zv1) / 2, (sx, sy), arc(sx, sy, vw / 2, 180, 360, 6), zv1 - zv0, sw)
    b.span((X0 - f - 0.3, top - 0.14, FRONT - 0.42), (X1 + f + 0.3, top + 0.14, FRONT - 0.02), "cream")   # head rail
    for x in (X0 - f + 0.15, X1 + f - 0.15):                                                # its brackets, onto the frame
        b.span((x - 0.1, Y1 + f, zf + 0.02), (x + 0.1, top - 0.14, zb), "cream")
    # a cupcake beside the board's left end (the street's left; Roblox +X is the board's left seen from the street),
    # on a little cream shelf out from the gable wall
    cx, sy, cz = X1 + f + 1.05, Y0 - 0.1, FRONT - 0.6
    b.span((cx - 0.6, sy - 0.1, FRONT - 1.15), (cx + 0.6, sy, FRONT), "cream")             # shelf, into the wall
    b.cyl((cx, sy + 0.3, cz), 0.45, 0.6, "caramel_wood", r2=0.36, axis="Y", segments=12)    # case, on the shelf
    for k in range(6):                                                                      # its ribs
        a = math.radians(k * 60 + 30)
        b.box((cx + 0.41 * math.cos(a), sy + 0.3, cz + 0.41 * math.sin(a)), (0.05, 0.56, 0.05), "dark_wood")
    b.ball((cx, sy + 0.78, cz), 0.48, "apron_pink", scale=(1.0, 0.75, 1.0))                # frosting, on the case
    b.ball((cx, sy + 1.18, cz), 0.14, "bowl_red")                                          # cherry, in it
    for k, (dx, dz) in enumerate(((-0.25, -0.3), (0.2, -0.32), (0.0, -0.42), (-0.32, 0.0), (0.34, -0.05))):
        b.box((cx + dx, sy + 0.98, cz + dz), (0.14, 0.05, 0.05), SPRINKLES[k], rot=_rz(30 * k))
    return [b.finalize("CatCafe_Plot_SignBakeryStripes", mat),
            board.finalize("CatCafe_Plot_SignBakeryStripes_SignBoard", mat)]


def _rx(deg):
    from plot import rot_x
    return rot_x(deg)


def build_king_crest(mat):
    b = RB()
    cx, cy, z = X1 - 0.35, Y1 + 0.1, FRONT - 0.62                                          # proud of either frame
    b.cyl((cx, cy, z + 0.04), 0.75, 0.08, "royal_berry", axis="Z", segments=16)            # a round berry badge
    b.b.ring(RB.p(cx, cy, z - 0.01), 0.75, 0.1, 0.1, GOLD, segments=16, rot=(math.radians(90), "X"))
    _crest(b, cx, cy - 0.05, z, 1.1)
    return [b.finalize("CatCafe_Plot_SignKingCrest", mat)]


def _maple(b, x, y, z, s, sw, turn=0.0, d=0.08):
    """A maple leaf standing up on the plane z (its back) and facing -Z, `s` studs tall, turned `turn` degrees in
    its own plane, with a little stem below it."""
    maple_leaf(b.b, RB.p(x, y, z - d / 2), s, d, sw,
               rot=Matrix.Rotation(math.radians(90), 3, "X") @ Matrix.Rotation(math.radians(-turn), 3, "Z"))
    a = math.radians(turn)
    sx, sy = math.sin(a), -math.cos(a)                                                      # down the leaf
    b.box((x + sx * 0.32 * s, y + sy * 0.32 * s, z - d / 2), (0.05 * s, 0.22 * s, d), sw, rot=_rz(turn))


def _acorn(b, x, y, z, s):
    b.ball((x, y, z - 0.12 * s), 0.16 * s, "caramel_wood", scale=(1.0, 1.25, 1.0))         # the nut
    b.ball((x, y + 0.12 * s, z - 0.12 * s), 0.17 * s, "dark_wood", scale=(1.0, 0.6, 1.0))   # its cap
    b.box((x, y + 0.26 * s, z - 0.12 * s), (0.04 * s, 0.1 * s, 0.04 * s), "dark_wood")


def build_golden_leaf(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "fur_russet")                        # SignBoard, 0.1 thick
    f, zf, zb = 0.4, FACE - 0.12, FACE + 0.1                                                # the gold frame
    for (xa, xb, ya, yb) in ((X0 - f, X1 + f, Y0 - f, Y0), (X0 - f, X1 + f, Y1, Y1 + f),
                             (X0 - f, X0, Y0, Y1), (X1, X1 + f, Y0, Y1)):
        frame.span((xa, ya, zf), (xb, yb, zb), GOLD)
    for k in range(9):                                                                      # a vine of tiny gold leaves
        x = X0 + 1.4 + k * (X1 - X0 - 2.8) / 8                                              # along the bottom rail
        b.box((x, Y0 - f / 2, zf - 0.03), (0.28, 0.16, 0.06), GOLD_LT, rot=_rz(35 if k % 2 else -35))
    for sx in (-1, 1):                                                                      # a gold leaf on each corner
        for sy in (-1, 1):
            x, y = sx * (X1 + f / 2), (Y1 + f / 2) if sy > 0 else (Y0 - f / 2)
            _maple(b, x, y, zf, 1.3, GOLD_LT, turn=sx * sy * -30)
    cy = Y1 + f                                                                             # the cluster on top
    b.span((-1.9, cy - 0.02, zf + 0.02), (1.9, cy + 0.12, zb), GOLD)                        # its gold twig
    _maple(b, 0.0, cy + 1.25, zf + 0.02, 2.4, GOLD)
    _maple(b, -1.35, cy + 0.85, zf, 1.8, "fur_rust_red", turn=35)
    _maple(b, 1.35, cy + 0.85, zf, 1.8, "fur_orange", turn=-35)
    for x in (-0.5, 0.5):
        _acorn(b, x, cy + 0.15, zf - 0.1, 1.4)
    return [b.finalize("CatCafe_Plot_SignGoldenLeaf", mat), board.finalize("CatCafe_Plot_SignGoldenLeaf_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignGoldenLeaf_Frame", mat)]


ASSETS = {
    "CatCafe_Plot_SignRoyalCrest": (build_royal_crest, 3000),
    "CatCafe_Plot_SignBakeryStripes": (build_bakery_stripes, 3000),
    "CatCafe_Plot_SignKingCrest": (build_king_crest, 1200),
    "CatCafe_Plot_SignGoldenLeaf": (build_golden_leaf, 3000),
}
