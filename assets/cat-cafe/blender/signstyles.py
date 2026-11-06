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
  CatCafe_Plot_SignVipPlate              the VIP pass's plate (store-pass-looks.md section 1): a small gold plate with
                                          a cream paw, under the cafe's name on the bottom of the sign and proud of
                                          every style's frame, shown only for an owner of the pass. No glow, no
                                          animation
  CatCafe_Plot_SignGarden                the Garden Cafe theme's sign (store-pass-looks.md section 3, themes.py): a sage
                                          board (SignBoard; cocoa name text), a brass frame (`_Frame`) with a leafy
                                          sprig and two small flowers on each top corner, and a terracotta "GARDEN"
                                          plate with cream letters standing on the frame's top centre
  CatCafe_Plot_SignGrand                 the Grand Cafe theme's sign (section 4): a cream board (SignBoard; plum name
                                          text) inside a plum inner border, a deep gold frame (`_Frame`) with gold
                                          corner blocks, and a plum "GRAND" plate with gold letters in a gold rim on
                                          the frame's top centre
  CatCafe_Plot_SignFlowerBox             the Sign Style Pack's (#1168, #1850) cottage style: a warm white board
                                          (SignBoard; cocoa name text) in a mint painted frame (`_Frame`) with ivy
                                          climbing both ends and a flower on each top corner, over a wooden window
                                          box hung from it on two iron straps, full of pink, yellow, white and blue
                                          flowers with ivy trailing over its front
  CatCafe_Plot_SignStarryNight           the Sign Style Pack's night style: a navy board (SignBoard; cream name text)
                                          with tiny pale twinkles painted round its edges, a gold frame (`_Frame`) with
                                          a gold star on each corner, and a gold crescent moon with three stars over
                                          the top centre
  CatCafe_Plot_SignPawChalkboard         the Sign Style Pack's chalkboard style: a green chalkboard (SignBoard; chalk
                                          white name text) in a wooden frame (`_Frame`), two little trails of chalk
                                          paw prints in its corners, a chalk ledge under it with three sticks of
                                          chalk and a felt eraser, and a big wooden paw plaque with pink pads over
                                          the top centre

Every model is placed at the Plot's pivot like the tier sets (Plot.cframe: floor top centre, -Z toward the street)
with no offset; WorldBuilder or the UI shows the one the plot uses. Nothing collides (the signs are high on the
gable). Roblox axes through common.RB.
"""

import math

from mathutils import Matrix

from common import RB, text_width
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


def build_vip_plate(mat):
    b = RB()
    cy, z, d = Y0 + 0.05, FRONT - 0.69, 0.12                                               # proud of every frame
    w, h = 2.2, 0.8

    def stadium(r, n=5):                                                                    # a plate with round ends
        return arc(w / 2, cy, r, -90, 90, n) + arc(-w / 2, cy, r, 90, 270, n) + [(w / 2, cy - r)]

    b.fan_z(z + d / 2, (0.0, cy), stadium(h / 2), d, GOLD_DK)                               # the plate's back
    b.fan_z(z - 0.01, (0.0, cy), stadium(h / 2 - 0.08), 0.06, GOLD)                          # its raised face
    for sx in (-1, 1):                                                                      # rivets
        b.cyl((sx * (w / 2 + 0.05), cy, z - 0.06), 0.08, 0.06, GOLD_LT, axis="Z", segments=8)
    zp = z - 0.07                                                                           # the paw, on the face
    b.cyl((0.0, cy - 0.1, zp), 0.2, 0.06, "cream", axis="Z", segments=12)                   # its pad
    for x, y in ((-0.25, 0.08), (-0.09, 0.2), (0.09, 0.2), (0.25, 0.08)):                   # its toes
        b.cyl((x, cy + y, zp), 0.085, 0.06, "cream", axis="Z", segments=8)
    return [b.finalize("CatCafe_Plot_SignVipPlate", mat)]


def _tag_plate(b, word, board, letters, rim, px=0.16):
    """A small name plate standing on the frame's top centre: `word` in block letters on a `board` plate in a `rim`."""
    w = text_width(word, px)
    pw, ph = w + 0.7, 5 * px + 0.5
    y0, z = Y1 + 0.38, FACE - 0.2
    b.span((-pw / 2 - 0.08, y0, z), (pw / 2 + 0.08, y0 + ph + 0.16, z + 0.3), rim)
    b.span((-pw / 2, y0 + 0.08, z - 0.04), (pw / 2, y0 + ph + 0.08, z + 0.01), board)
    b.text(word, (w / 2, y0 + 0.33, z - 0.04), px, 0.05, letters, right=(-1, 0, 0))


def _frame(frame, f, zf, zb, sw):
    for (xa, xb, ya, yb) in ((X0 - f, X1 + f, Y0 - f, Y0), (X0 - f, X1 + f, Y1, Y1 + f),
                             (X0 - f, X0, Y0, Y1), (X1, X1 + f, Y0, Y1)):
        frame.span((xa, ya, zf), (xb, yb, zb), sw)


def build_garden(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "fur_fern")                         # SignBoard
    f, zf, zb = 0.35, FACE - 0.12, FACE + 0.1
    _frame(frame, f, zf, zb, "brass")
    for sx in (-1, 1):                                                                      # sprigs on the top corners
        x, y = sx * (X1 + f / 2), Y1 + f / 2
        for k, (dx, dy, a) in enumerate(((0.0, 0.0, 0), (-sx * 0.55, 0.12, sx * 60), (0.0, -0.55, 0),
                                         (-sx * 0.95, 0.15, sx * 75))):
            b.ball((x + dx, y + dy, zf - 0.05), 0.24, ("fur_moss", "leaf_green")[k % 2], scale=(1.5, 0.8, 0.5))
        for dx, sw in ((-sx * 0.3, "offwhite"), (-sx * 0.75, "blush")):
            b.ball((x + dx, y + 0.2, zf - 0.14), 0.12, sw)
    _tag_plate(b, "GARDEN", "terracotta", "cream", "brass")
    return [b.finalize("CatCafe_Plot_SignGarden", mat), board.finalize("CatCafe_Plot_SignGarden_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignGarden_Frame", mat)]


def build_grand(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "cream")                               # SignBoard
    i = 0.18                                                                                # plum inner border
    for (xa, xb, ya, yb) in ((X0, X1, Y0, Y0 + i), (X0, X1, Y1 - i, Y1), (X0, X0 + i, Y0, Y1), (X1 - i, X1, Y0, Y1)):
        b.span((xa, ya, FACE - 0.03), (xb, yb, FACE + 0.01), "royal_berry")
    f, zf, zb = 0.5, FACE - 0.16, FACE + 0.1
    _frame(frame, f, zf, zb, GOLD)
    b.span((X0 - f, Y0 - f - 0.12, zf + 0.02), (X1 + f, Y0 - f + 0.01, zb), GOLD_DK)          # a deeper lip under it
    for sx in (-1, 1):                                                                      # corner blocks
        for y in (Y0 - f / 2, Y1 + f / 2):
            b.span((sx * (X1 + f / 2) - 0.4, y - 0.4, zf - 0.08), (sx * (X1 + f / 2) + 0.4, y + 0.4, zf + 0.01), GOLD_LT)
            b.cyl((sx * (X1 + f / 2), y, zf - 0.1), 0.15, 0.06, "royal_berry", axis="Z", segments=8)
    _tag_plate(b, "GRAND", "royal_berry", GOLD_LT, GOLD)
    return [b.finalize("CatCafe_Plot_SignGrand", mat), board.finalize("CatCafe_Plot_SignGrand_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignGrand_Frame", mat)]


def _star(b, cx, cy, z, r, sw, d=0.08, turn=0.0):
    """A five-point star `r` studs to its tips, flat on the plane z (its middle) and facing -Z."""
    pts = []
    for k in range(11):
        a = math.radians(turn + 36 * k)
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.sin(a), cy + rr * math.cos(a)))
    b.fan_z(z, (cx, cy), pts, d, sw)


def _flower(b, cx, cy, z, r, petal, middle="rarity_legend", d=0.06):
    """A flat flower facing -Z on the plane z, `r` studs to the petal tips: five round petals and a middle."""
    for k in range(5):
        a = math.radians(72 * k + 90)
        b.cyl((cx + 0.55 * r * math.cos(a), cy + 0.55 * r * math.sin(a), z), 0.45 * r, d, petal, axis="Z",
              segments=8)
    b.cyl((cx, cy, z - d / 2 - 0.02), r * 0.32, 0.05, middle, axis="Z", segments=8)


BLOOMS = ("apron_pink", "rarity_legend", "offwhite", "pastel_sky", "blush")


def build_flower_box(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "offwhite")                           # SignBoard
    f, zf, zb = 0.35, FACE - 0.12, FACE + 0.1
    _frame(frame, f, zf, zb, "mint")
    for sx in (-1, 1):                                                                      # ivy up both ends
        x = sx * (X1 + f / 2)
        for k in range(5):
            y = Y0 + 0.1 + k * 0.72
            b.ball((x + sx * (0.12 if k % 2 else -0.1), y, zf - 0.06), 0.2, ("leaf_green", "leaf_dark")[k % 2],
                   scale=(1.3, 0.8, 0.45))
        _flower(b, x, Y1 + f / 2 + 0.1, zf - 0.12, 0.42, ("apron_pink", "pastel_sky")[sx > 0])
    # the window box, hung from the frame on two iron straps, its back on the gable wall; it stays above the
    # window awnings' head rails (plot._awning, y 11.6) and its flowers below the board
    top, bot, zfr = Y0 - f - 0.45, 11.8, FRONT - 1.1
    x0, x1 = X0 + 1.2, X1 - 1.2
    b.span((x0, bot + 0.1, zfr), (x1, top - 0.12, FRONT), "caramel_wood")                    # the box
    b.span((x0 - 0.1, top - 0.12, zfr - 0.08), (x1 + 0.1, top, FRONT), "dark_wood")         # its rim
    b.span((x0 - 0.1, bot, zfr - 0.08), (x1 + 0.1, bot + 0.1, FRONT), "dark_wood")          # and foot
    for k in range(1, 4):                                                                   # three panel battens
        x = x0 + k * (x1 - x0) / 4
        b.span((x - 0.07, bot + 0.1, zfr - 0.05), (x + 0.07, top - 0.12, zfr), "dark_wood")
    b.span((x0 + 0.1, top - 0.02, zfr + 0.12), (x1 - 0.1, top + 0.04, FRONT - 0.12), "choco")   # soil
    for x in (x0 + 0.6, x1 - 0.6):                                                          # the straps
        b.span((x - 0.08, bot + 0.1, zfr - 0.13), (x + 0.08, Y0 - f + 0.05, zfr - 0.09), "concrete_dark")
        b.span((x - 0.08, Y0 - f - 0.05, zfr - 0.13), (x + 0.08, Y0 - f + 0.05, zf + 0.01), "concrete_dark")
    n = 9                                                                                   # leaves and flowers
    for k in range(n):
        x = x0 + 0.55 + k * (x1 - x0 - 1.1) / (n - 1)
        zc = zfr + 0.45
        b.ball((x, top + 0.18, zc), 0.36, ("leaf_green", "leaf_dark")[k % 2], scale=(1.3, 0.7, 0.9))
        h = 0.32 + 0.1 * ((k * 7) % 3)
        b.box((x + 0.15, top + h / 2, zc - 0.25), (0.06, h, 0.06), "leaf_dark")             # a stem
        _flower(b, x + 0.15, top + h, zc - 0.4, 0.3 + 0.03 * (k % 2), BLOOMS[k % len(BLOOMS)])
    for k, x in enumerate((x0 + 1.4, x0 + 3.3, x1 - 2.6, x1 - 1.3)):                       # ivy over the front
        for j in range(2 + (k % 2 == 0)):
            b.box((x + 0.1 * (j % 2), top - 0.12 - 0.26 * j, zfr - 0.12), (0.28, 0.22, 0.06),
                  ("leaf_green", "leaf_dark")[(j + k) % 2], rot=_rz(30 if j % 2 else -30))
    return [b.finalize("CatCafe_Plot_SignFlowerBox", mat), board.finalize("CatCafe_Plot_SignFlowerBox_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignFlowerBox_Frame", mat)]


def _crescent(b, cx, cy, z, r, sw, d=0.16):
    """A crescent moon r studs to its outer edge, its horns toward +X: a strip of quads round the outer circle from
    60 to 300 degrees, fattest in the middle and coming to a point at each horn."""
    n = 12
    outer, inner = [], []
    for k in range(n + 1):
        t = k / n
        a = math.radians(60 + 240 * t)
        w = 0.02 * r + 0.46 * r * math.sin(math.pi * t)
        outer.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        inner.append((cx + (r - w) * math.cos(a), cy + (r - w) * math.sin(a)))
    for k in range(n):
        b.fan_z(z, outer[k], [inner[k], inner[k + 1], outer[k + 1]], d, sw)


def build_starry_night(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "night_sky")                          # SignBoard
    f, zf, zb = 0.35, FACE - 0.12, FACE + 0.1
    _frame(frame, f, zf, zb, GOLD)
    # tiny stars painted round the board's edges, clear of the middle where the cafe's name goes
    dots = ((-7.4, 16.15, 0.17), (-6.3, 13.85, 0.13), (-5.1, 16.3, 0.11), (-3.6, 13.75, 0.15), (-1.9, 16.25, 0.12),
            (1.4, 13.8, 0.12), (2.9, 16.3, 0.15), (4.4, 13.75, 0.11), (5.8, 16.2, 0.13), (7.3, 13.9, 0.17),
            (-7.5, 14.9, 0.11), (7.45, 15.3, 0.12))
    for k, (x, y, r) in enumerate(dots):
        sw = ("sparkle", "lamp_warm")[k % 2]                                               # a four-point twinkle
        b.box((x, y, FACE - 0.015), (r * 2.2, r * 0.45, 0.03), sw, rot=_rz(10 * k))
        b.box((x, y, FACE - 0.016), (r * 0.45, r * 2.2, 0.03), sw, rot=_rz(10 * k))
    for sx in (-1, 1):                                                                      # a gold star on each corner
        for y in (Y0 - f / 2, Y1 + f / 2):
            _star(b, sx * (X1 + f / 2), y, zf - 0.06, 0.5, GOLD_LT, d=0.12, turn=sx * 10)
    cy = Y1 + f + 1.4                                                                       # the moon and its stars
    b.span((-1.6, Y1 + f, zf + 0.02), (1.6, Y1 + f + 0.12, zb), GOLD)                       # their plinth
    _crescent(b, -0.5, cy, zf + 0.02, 1.35, GOLD)                                           # its foot in the plinth
    for (x, y, r) in ((0.95, cy + 0.6, 0.48), (1.75, cy - 0.2, 0.34), (0.7, cy - 0.65, 0.26)):
        _star(b, x, y, zf - 0.02, r, GOLD_LT, d=0.12)
        b.box((x, (y + Y1 + f) / 2, zf + 0.06), (0.05, y - Y1 - f, 0.05), GOLD_DK)          # each on a fine wire
    return [b.finalize("CatCafe_Plot_SignStarryNight", mat),
            board.finalize("CatCafe_Plot_SignStarryNight_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignStarryNight_Frame", mat)]


def _paw(b, cx, cy, z, s, sw, d=0.03, turn=0.0):
    """A paw print `s` studs across, flat on the plane z and facing -Z, toes toward `turn` degrees off up."""
    a = math.radians(turn)
    ca, sa = math.cos(a), math.sin(a)

    def at(x, y):
        return cx + x * ca - y * sa, cy + x * sa + y * ca

    px, py = at(0.0, -0.12 * s)
    b.cyl((px, py, z), 0.27 * s, d, sw, axis="Z", segments=10)                              # the pad
    for x, y in ((-0.3, 0.15), (-0.11, 0.3), (0.11, 0.3), (0.3, 0.15)):                     # the toes
        tx, ty = at(x * s, y * s)
        b.cyl((tx, ty, z), 0.11 * s, d, sw, axis="Z", segments=8)


def build_paw_chalkboard(mat):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), "dumpster_green")                     # SignBoard, the slate
    f, zf, zb = 0.4, FACE - 0.12, FACE + 0.1
    _frame(frame, f, zf, zb, "caramel_wood")
    for sx in (-1, 1):                                                                      # nails at the corners
        for y in (Y0 - f / 2, Y1 + f / 2):
            b.cyl((sx * (X1 + f / 2), y, zf - 0.02), 0.07, 0.05, "metal", axis="Z", segments=6)
    zc = FACE - 0.012                                                                       # chalk, on the slate
    for k, (x, y, t) in enumerate(((7.35, 13.85, 35), (6.8, 14.45, 25), (7.3, 15.05, 35))):
        _paw(b, x, y, zc, 0.6 - 0.04 * k, "offwhite", turn=t)                               # a trail up one end
    for k, (x, y, t) in enumerate(((-7.35, 16.15, 215), (-6.8, 15.55, 205), (-7.3, 14.95, 215))):
        _paw(b, x, y, zc, 0.6 - 0.04 * k, "offwhite", turn=t)                               # and down the other
    # the chalk ledge under the frame, its back on the gable wall, with three sticks of chalk and an eraser
    y0, zl = Y0 - f - 0.16, FACE - 0.55
    b.span((X0 - f, y0, zl), (X1 + f, Y0 - f, FRONT), "caramel_wood")
    b.span((X0 - f, y0 + 0.16, zl - 0.06), (X1 + f, y0 + 0.28, zl + 0.06), "dark_wood")     # its lip
    for k, (x, sw) in enumerate(((-4.2, "offwhite"), (-3.4, "apron_pink"), (3.6, "pastel_sky"))):
        b.cyl((x, Y0 - f + 0.06, zl + 0.22), 0.06, 0.6, sw, axis="X", segments=6)
    b.span((4.6, Y0 - f, zl + 0.08), (5.6, Y0 - f + 0.18, zl + 0.4), "dark_wood")           # the eraser's back
    b.span((4.6, Y0 - f + 0.18, zl + 0.08), (5.6, Y0 - f + 0.3, zl + 0.4), "cream")          # and its felt
    # a big wooden paw over the top centre, on a little bar standing on the frame
    cy = Y1 + f + 1.1
    b.span((-1.2, Y1 + f, zf + 0.02), (1.2, Y1 + f + 0.12, zb), "dark_wood")
    b.cyl((0.0, cy - 0.25, zf + 0.06), 0.85, 0.16, "caramel_wood", axis="Z", segments=14)   # the paw's pad
    for x, y, r in ((-0.95, 0.42, 0.36), (-0.36, 0.92, 0.36), (0.36, 0.92, 0.36), (0.95, 0.42, 0.36)):
        b.cyl((x, cy + y, zf + 0.06), r, 0.16, "caramel_wood", axis="Z", segments=10)       # its toes
    b.cyl((0.0, cy - 0.3, zf - 0.04), 0.6, 0.06, "apron_pink", axis="Z", segments=14)        # pink pads on it
    for x, y in ((-0.95, 0.42), (-0.36, 0.92), (0.36, 0.92), (0.95, 0.42)):
        b.cyl((x, cy + y, zf - 0.04), 0.22, 0.06, "apron_pink", axis="Z", segments=8)
    return [b.finalize("CatCafe_Plot_SignPawChalkboard", mat),
            board.finalize("CatCafe_Plot_SignPawChalkboard_SignBoard", mat),
            frame.finalize("CatCafe_Plot_SignPawChalkboard_Frame", mat)]


ASSETS = {
    "CatCafe_Plot_SignRoyalCrest": (build_royal_crest, 3000),
    "CatCafe_Plot_SignBakeryStripes": (build_bakery_stripes, 3000),
    "CatCafe_Plot_SignKingCrest": (build_king_crest, 1200),
    "CatCafe_Plot_SignGoldenLeaf": (build_golden_leaf, 3000),
    "CatCafe_Plot_SignVipPlate": (build_vip_plate, 600),
    "CatCafe_Plot_SignGarden": (build_garden, 3000),
    "CatCafe_Plot_SignGrand": (build_grand, 3000),
    "CatCafe_Plot_SignFlowerBox": (build_flower_box, 3000),
    "CatCafe_Plot_SignStarryNight": (build_starry_night, 3000),
    "CatCafe_Plot_SignPawChalkboard": (build_paw_chalkboard, 3000),
}
