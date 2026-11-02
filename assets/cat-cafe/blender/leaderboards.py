"""The Town Square's leaderboards (F98, leaderboards.md section 2: "Three standing boards in a row at the edge of the
Town Square, facing the Cat Cannon ... Each board is a framed chalkboard on two legs with a painted header icon
(book, clock, coin) and the board's name").

  CatCafe_Town_LeaderboardRow            a low brick plinth with a cream cap under the three boards, and at each end
                                         a terracotta planter with a clipped bush and a lamp post
    CatCafe_Town_LeaderboardRow_Index    one board each: a wooden frame round a chalk face, standing on two posts with
    CatCafe_Town_LeaderboardRow_Playtime feet and gold finials; a chalk tray with chalk and a duster; a header plank
    CatCafe_Town_LeaderboardRow_Money    in the board's colour with its name in cream letters; and a round crest on
                                         top in a gold ring with laurels, painted with the board's icon (an open book,
                                         a red alarm clock, a gold paw coin with a little stack)
      Screen                             the board's 5 x 6.4 chalk face, a part named Screen (the _Screen object,
                                         nested in its board's Model) whose Front (-Z) face looks at the player; the
                                         UI's SurfaceGui (Adornee = Screen) draws the top 10 and the player's own line
                                         on it, so nothing stands in front of that face
    _Lamp_Bulb                           the two lanterns: lit at night
    _Flowers                             the planters' flowers (butterflies)

Read from the front (looking +Z) the boards stand Index, Playtime, Money from left to right, as the spec lists them.
Pivot at the plinth's base centre on the paving (world y 0.1), front -Z toward the cannon. The row runs along local X
(BOARD_X gives each board's middle) and is ROW_HALF long either side of the pivot and DEPTH deep either side of it.
Each board Model's pivot is its own base centre on the plinth. The root Model streams Atomic, so the Screens are
there whenever the row is, and each board Model carries the Leaderboard tag.
"""

import math

from alleyway import flower_clump, label, lantern
from common import RB
from plot import rot_z

N = "CatCafe_Town_LeaderboardRow"
BOARD = N + "_"             # a board Model: CatCafe_Town_LeaderboardRow_Index, _Playtime, _Money

PLINTH = 0.35               # the plinth's top: the boards and planters stand on it
W, H = 5.0, 6.4             # the Screen
Y0 = 2.1                    # the Screen's bottom, so its middle sits a little over a standing player's eye line
FZ = -0.2                   # the Screen's front face
F = 0.32                    # the frame's width round the Screen
HX = W / 2 + F              # the frame's outer half width
HY = Y0 + H + F             # the frame's top
HEAD = 1.15                 # the header plank over the frame
TOP = HY + HEAD
FRONT, BACK = -0.35, 0.3    # the frame's front and back faces
PX = 0.15                   # letter pixel on the plank: PLAYTIME is 4.95 wide
PW = 0.36                   # a post's width; the posts lap 0.02 onto the frame's sides
CY = TOP + 0.95             # the crest's middle
ZI = -0.4                   # the crest disc's front face: the icon is painted on it
PITCH = 2 * (HX - 0.02 + PW) + 0.4    # board to board, a 0.4 gap between the posts
BOARD_X = {"Index": PITCH, "Playtime": 0.0, "Money": -PITCH}   # +X is the viewer's left
POT = 1.5                   # a planter's width
POT_X = PITCH + HX - 0.02 + PW + 0.25 + POT / 2               # each planter's middle
ROW_HALF = POT_X + POT / 2 + 0.2      # the plinth's half length
DEPTH = 1.3                 # the plinth's half depth

# board -> header plank and crest colour, letters
STYLES = {"Index": ("sign_teal", "offwhite"), "Playtime": ("galaxy_blue", "offwhite"),
          "Money": ("paw_park", "offwhite")}


def _frame(b, screen, plank, ink, name):
    """The chalkboard: Screen, frame, back panel, posts with feet, the header plank and the chalk tray."""
    screen.span((-W / 2, Y0, FZ), (W / 2, Y0 + H, 0.05), "dumpster_green")
    for (x0, y0, x1, y1) in ((-HX, Y0 - F, HX, Y0 + 0.01), (-HX, Y0 + H - 0.01, HX, HY),
                             (-HX, Y0, -W / 2 + 0.01, Y0 + H), (W / 2 - 0.01, Y0, HX, Y0 + H)):
        b.span((x0, y0, FRONT), (x1, y1, BACK), "caramel_wood")
    b.span((-W / 2 - 0.1, Y0 - 0.1, 0.0), (W / 2 + 0.1, Y0 + H + 0.1, 0.24), "dark_wood")       # back panel
    for s in (-1, 1):                                                                        # posts
        x0, x1 = sorted((s * (HX - 0.02), s * (HX - 0.02 + PW)))
        cx = (x0 + x1) / 2
        b.span((x0, PLINTH, -0.18), (x1, TOP + 0.25, 0.18), "dark_wood")
        b.span((x0 - 0.04, PLINTH, -0.8), (x1 + 0.04, PLINTH + 0.22, 0.8), "dark_wood")       # foot
        b.span((x0 - 0.06, TOP + 0.25, -0.24), (x1 + 0.06, TOP + 0.37, 0.24), "caramel_wood")  # cap
        b.ball((cx, TOP + 0.53, 0), 0.19, "gold_mid")                                        # finial
    b.span((-HX, HY, -0.3), (HX, TOP, 0.25), plank)                                         # header plank
    b.span((-HX, TOP, -0.36), (HX, TOP + 0.1, 0.3), "cream")                                # moulding
    label(b, name.upper(), 0, HY + (HEAD - 5 * PX) / 2, -0.3, PX, 0.06, ink, -1)
    b.span((-W / 2, Y0 - 0.16, -0.75), (W / 2, Y0 - 0.04, FRONT), "caramel_wood")            # chalk tray
    b.span((-W / 2, Y0 - 0.04, -0.75), (W / 2, Y0 + 0.04, -0.69), "caramel_wood")            # its lip
    for (x, length, sw) in ((1.7, 0.42, "offwhite"), (1.05, 0.3, "pastel_butter"), (0.55, 0.36, "nose_pink"),
                            (-0.2, 0.26, "offwhite")):
        b.span((x - length / 2, Y0 - 0.04, -0.62), (x + length / 2, Y0 + 0.05, -0.53), sw)
    b.span((-1.85, Y0 - 0.04, -0.66), (-1.15, Y0 + 0.02, -0.42), "fur_charcoal")              # duster: felt
    b.span((-1.82, Y0 + 0.02, -0.63), (-1.18, Y0 + 0.16, -0.45), "dark_wood")                 # and its back
    for y in (Y0 + 1.2, Y0 + H - 1.5):                                                       # battens on the back
        b.span((-W / 2, y, 0.24), (W / 2, y + 0.3, BACK), "caramel_wood")
    py = Y0 + H / 2
    b.span((-0.34, py - 0.36, 0.24), (0.34, py + 0.12, 0.28), "cream")                       # a paw on the back
    for (dx, dy) in ((-0.44, 0.34), (-0.15, 0.5), (0.15, 0.5), (0.44, 0.34)):
        b.span((dx - 0.12, py + dy - 0.12, 0.24), (dx + 0.12, py + dy + 0.12, 0.28), "cream")


def _crest(b, colour):
    """The round crest on top: a gold ring with a dark green laurel round its lower half and a disc in the board's
    colour, its back plain."""
    b.cyl((0, CY, -0.18), 0.97, 0.26, "gold_mid", axis="Z", segments=16)
    b.cyl((0, CY, -0.35), 0.84, 0.1, colour, axis="Z", segments=16)
    b.cyl((0, CY, 0.0), 0.84, 0.12, colour, axis="Z", segments=16)
    for s in (-1, 1):
        for k, a in enumerate((-72, -48, -24, 0, 24)):
            t = math.radians(a)
            x, y = s * 0.98 * math.cos(t), CY + 0.98 * math.sin(t)
            b.leaf((x, y, -0.35), 0.2 - 0.012 * k, "paw_woods" if k % 2 else "leaf_dark", rot_z(s * (a + 30)))


def _sleeper(b):
    """A ginger cat asleep on the Playtime board's header, curled up beside the crest on the viewer's right."""
    y = TOP + 0.1                                                          # the moulding's top
    b.ball((-2.0, y + 0.27, -0.02), 0.42, "fur_orange", scale=(1.45, 0.72, 1.0))           # body
    b.cyl((-2.15, y + 0.1, -0.36), 0.1, 0.75, "fur_orange", axis="X", segments=8)        # tail round the front
    b.ball((-2.52, y + 0.1, -0.36), 0.12, "fur_white")                                    # its tip
    hx, hy, hz = -1.42, y + 0.3, -0.16
    b.ball((hx, hy, hz), 0.3, "fur_orange")                                               # head on its paws
    for s in (-1, 1):
        b.box((hx + s * 0.15, hy + 0.25, hz), (0.17, 0.17, 0.08), "fur_orange", rot=rot_z(45))   # ears
        b.box((hx + s * 0.11, hy + 0.04, hz - 0.27), (0.12, 0.03, 0.04), "fur_black")        # shut eyes
        b.ball((hx + s * 0.12, y + 0.09, hz - 0.22), 0.1, "fur_white")                      # front paws
    b.ball((hx, hy - 0.08, hz - 0.24), 0.11, "fur_white")                                 # muzzle
    b.span((hx - 0.03, hy - 0.02, hz - 0.36), (hx + 0.03, hy + 0.02, hz - 0.33), "nose_pink")
    for s in (-1, 1):                                                                     # the W mouth
        b.box((hx + s * 0.035, hy - 0.08, hz - 0.345), (0.06, 0.018, 0.02), "fur_black", rot=rot_z(s * 30))


def _book(b):
    """An open book: a red cover, two pages tipped up from the spine with lines on them, a ribbon."""
    b.span((-0.6, CY - 0.36, ZI - 0.04), (0.6, CY + 0.24, ZI + 0.01), "bowl_red")
    b.span((-0.04, CY - 0.56, ZI - 0.05), (0.04, CY - 0.3, ZI - 0.01), "neon_pink")
    for s in (-1, 1):
        a = s * 8
        px, py = s * 0.27, CY - 0.03
        b.box((px, py, ZI - 0.05), (0.5, 0.54, 0.04), "offwhite", rot=rot_z(a))
        t = math.radians(a)
        for dy in (0.13, 0.0, -0.13):
            b.box((px - math.sin(t) * dy, py + math.cos(t) * dy, ZI - 0.08), (0.34, 0.04, 0.02), "concrete",
                  rot=rot_z(a))
    b.span((-0.03, CY - 0.33, ZI - 0.06), (0.03, CY + 0.22, ZI - 0.02), "dark_wood")


def _clock(b):
    """A red alarm clock with gold bells and feet, its hands at ten past ten."""
    for s in (-1, 1):
        b.ball((s * 0.36, CY + 0.42, ZI - 0.02), 0.17, "gold_mid")
        b.box((s * 0.3, CY - 0.47, ZI - 0.03), (0.08, 0.22, 0.05), "fur_black", rot=rot_z(s * 30))
    b.span((-0.03, CY + 0.45, ZI - 0.05), (0.03, CY + 0.62, ZI - 0.01), "fur_black")             # bell hammer
    b.cyl((0, CY, ZI - 0.03), 0.5, 0.08, "bowl_red", axis="Z", segments=16)
    b.cyl((0, CY, ZI - 0.08), 0.41, 0.04, "offwhite", axis="Z", segments=16)
    for (x0, y0, x1, y1) in ((-0.025, 0.29, 0.025, 0.36), (-0.025, -0.36, 0.025, -0.29), (0.29, -0.025, 0.36, 0.025),
                             (-0.36, -0.025, -0.29, 0.025)):
        b.span((x0, CY + y0, ZI - 0.12), (x1, CY + y1, ZI - 0.1), "fur_black")
    for (a, length, w, z) in ((-60, 0.22, 0.06, ZI - 0.105), (60, 0.32, 0.045, ZI - 0.115)):   # +X is the viewer's left
        t = math.radians(a)
        dx, dy = -math.sin(t), math.cos(t)
        b.box((dx * length / 2, CY + dy * length / 2, z), (w, length, 0.03 if a < 0 else 0.05), "fur_black",
              rot=rot_z(a))
    b.cyl((0, CY, ZI - 0.13), 0.05, 0.04, "gold_mid", axis="Z", segments=8)


def _coin(b):
    """A gold coin with a paw on it, and two sparkles."""
    b.cyl((0, CY, ZI - 0.03), 0.56, 0.08, "gold_dark", axis="Z", segments=16)
    b.cyl((0, CY, ZI - 0.08), 0.47, 0.04, "gold_mid", axis="Z", segments=16)
    b.cyl((0, CY - 0.1, ZI - 0.105), 0.16, 0.03, "gold_dark", axis="Z", segments=10)
    for (dx, dy) in ((0.17, 0.08), (0.06, 0.17), (-0.06, 0.17), (-0.17, 0.08)):
        b.cyl((dx, CY + dy, ZI - 0.105), 0.065, 0.03, "gold_dark", axis="Z", segments=8)
    for (x, y, r) in ((-0.55, CY + 0.42, 0.11), (0.6, CY - 0.4, 0.08)):                    # +X is the viewer's left
        b.box((x, y, ZI - 0.01), (r, r, 0.04), "sparkle", rot=rot_z(45))
        b.box((x, y, ZI - 0.015), (r * 0.45, r * 2.4, 0.03), "sparkle")


ICONS = {"Index": _book, "Playtime": _clock, "Money": _coin}


class _At:
    """An RB seen through a shift, so a board drawn in row space (round x 0) is logged relative to its own pivot."""

    def __init__(self, rb, dx, dy):
        self.rb, self.dx, self.dy = rb, dx, dy

    def _p(self, c):
        return (c[0] + self.dx, c[1] + self.dy, c[2])

    def span(self, lo, hi, swatch, rot=None):
        self.rb.span(self._p(lo), self._p(hi), swatch, rot)

    def box(self, c, s, swatch, rot=None):
        self.rb.box(self._p(c), s, swatch, rot)

    def cyl(self, c, r, h, swatch, axis="Y", r2=None, segments=12):
        self.rb.cyl(self._p(c), r, h, swatch, axis=axis, r2=r2, segments=segments)

    def ball(self, c, r, swatch, scale=(1, 1, 1)):
        self.rb.ball(self._p(c), r, swatch, scale)

    def text(self, s, origin, px, depth, swatch, right=(1, 0, 0), up=(0, 1, 0)):
        return self.rb.text(s, self._p(origin), px, depth, swatch, right, up)

    def leaf(self, c, r, swatch, rot):
        """A flat ellipsoid leaf r * 2 long along its own Y, turned by rot (an ellipsoid Part in Roblox)."""
        self.rb.b.ico(RB.p(*self._p(c)), r, swatch, scale=(0.42, 0.3, 1.0), rot=RB._rot(rot))


def board(name, mat):
    """One board drawn round x 0, its pivot (and its Screen's) at (BOARD_X[name], PLINTH, 0): [board, Screen]."""
    bx = BOARD_X[name]
    plank, ink = STYLES[name]
    b, screen = RB(), RB()
    at = _At(b, 0, -PLINTH)
    _frame(at, _At(screen, 0, -PLINTH), plank, ink, name)
    _crest(at, plank)
    ICONS[name](at)
    if name == "Playtime":
        _sleeper(at)
    return [b.finalize(BOARD + name, mat, location=(bx, PLINTH, 0)),
            screen.finalize(BOARD + name + "_Screen", mat, location=(bx, PLINTH, 0))]


def planter(b, lamps, flowers, s):
    """A terracotta planter with a clipped bush and a lamp post, at one end of the row."""
    cx = s * POT_X
    h = POT / 2
    b.span((cx - h, PLINTH, -h), (cx + h, PLINTH + 0.9, h), "terracotta")
    b.span((cx - h - 0.06, PLINTH + 0.9, -h - 0.06), (cx + h + 0.06, PLINTH + 1.02, h + 0.06), "cream")   # rim
    b.span((cx - h + 0.1, PLINTH + 1.02, -h + 0.1), (cx + h - 0.1, PLINTH + 1.06, h - 0.1), "fur_bramble")  # soil
    b.ball((cx, PLINTH + 1.45, 0), 0.74, "leaf_green", scale=(1, 0.75, 1))
    flower_clump(flowers, cx - 0.15, PLINTH + 1.6, -0.35, n=4, spread=0.4)
    flower_clump(flowers, cx + 0.2, PLINTH + 1.7, 0.3, colours=("pastel_lilac", "sparkle", "blush"), n=3,
                 spread=0.35)
    b.span((cx - 0.12, PLINTH + 1.0, -0.12), (cx + 0.12, 5.3, 0.12), "fur_black")             # lamp post
    b.span((cx - 0.2, 4.0, -0.2), (cx + 0.2, 4.15, 0.2), "fur_black")                         # collar
    lantern(b, lamps, cx, 5.3, 0, s=0.75)


def build(mat):
    b, lamps, flowers = RB(), RB(), RB()
    b.span((-ROW_HALF, 0, -DEPTH), (ROW_HALF, PLINTH - 0.1, DEPTH), "brick")
    b.span((-ROW_HALF - 0.06, PLINTH - 0.1, -DEPTH - 0.06), (ROW_HALF + 0.06, PLINTH, DEPTH + 0.06), "cream")
    for s in (-1, 1):
        planter(b, lamps, flowers, s)
    objs = [b.finalize(N, mat), flowers.finalize(N + "_Flowers", mat), lamps.finalize(N + "_Lamp_Bulb", mat)]
    for name in BOARD_X:
        objs += board(name, mat)
    return objs


ASSETS = {N: (build, 8000)}
NEST = {"_Screen": ""}       # each Screen rides its board's Model
