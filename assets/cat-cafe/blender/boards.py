"""Index Boards (areas-and-stations B4, F50): a noticeboard at each area's entry, inside the gate, styled to the
area: brick for the Alleyway, wood for the Park and the Woods, cork for the Neighbourhood, tin for the Sewer.
Laid out in Roblox axes through common.RB, front -Z, sizes in studs.

  CatCafe_<Area>_IndexBoard          posts, frame, back, header with "INDEX" and the area's trim (collides)
  CatCafe_<Area>_IndexBoard_Screen   the 8 x 5 board face, exported as a part named Screen whose Front (-Z) face
                                     looks at the player; the UI's SurfaceGui (in PlayerGui, Adornee = Screen) draws
                                     the area's ten cats on it, so nothing stands in front of that face

Pivot at the base centre, front (-Z) toward the player. The root Model carries the IndexBoard tag, an Area
attribute (alley, park, neighbourhood, woods, sewer) and ModelStreamingMode Atomic, so the Screen streams in with
the board (reviewer S37). PLACEMENT gives each board's spot in the frame of the gate or arch it stands behind
(x across, y up, z into the area, studs, turn about Y): inside the opening on the right of the path as you walk in,
turned a little toward it. A locked area's board shows through the gate's bars as a teaser.
"""

import math

from mathutils import Matrix

from alleyway import label
from common import RB

W, H = 8.0, 5.0                     # the Screen
Y0 = 2.6                            # bottom of the Screen, so its middle sits at a standing player's eye line
FZ = -0.25                          # the Screen's front face
F = 0.5                             # frame width round the Screen
HX = W / 2 + F                      # outer half width of the frame
HY = Y0 + H + F                     # top of the frame
HEAD = 1.5                          # header plank above the frame
TOP = HY + HEAD
PX = 0.2                            # letter pixel size on the header
FRONT = FZ - 0.15                   # the frame's front face

# area id -> asset name, then frame, back panel, header plank, header letters, Screen colour (under the SurfaceGui)
STYLES = {
    "alley": ("CatCafe_Alley_IndexBoard", "concrete", "concrete_dark", "dark_wood", "lamp_warm", "cream"),
    "park": ("CatCafe_Park_IndexBoard", "dumpster_green", "dark_wood", "cream", "dumpster_green", "cream"),
    "neighbourhood": ("CatCafe_Neighbourhood_IndexBoard", "sign_teal", "dark_wood", "sign_teal", "offwhite",
                      "cardboard"),
    "woods": ("CatCafe_Woods_IndexBoard", "dark_wood", "dark_wood", "caramel_wood", "fur_seal", "cream"),
    "sewer": ("CatCafe_Sewer_IndexBoard", "metal", "concrete_dark", "concrete_dark", "eye_green", "cream"),
}

# Each board's spot in its gate's or arch's own frame: (x, y, z, turn about Y in degrees). The openings are 24
# (Park, Neighbourhood), 30 (Woods, Sewer) and 28 (the street arch into the Alley Square) wide.
PLACEMENT = {
    "alley": ("CatCafe_Alley_ArchStreet", (-9.0, 0.0, 8.0, -20.0)),
    "park": ("CatCafe_Park_Gate", (-7.0, 0.0, 8.0, -20.0)),
    "neighbourhood": ("CatCafe_Neighbourhood_Gate", (-7.0, 0.0, 8.0, -20.0)),
    "woods": ("CatCafe_Woods_Gate", (-10.0, 0.0, 8.0, -20.0)),
    "sewer": ("CatCafe_Sewer_Gate", (-10.0, 0.0, 8.0, -20.0)),
}


def _rot(deg, axis):
    return Matrix.Rotation(math.radians(deg), 3, axis)


def _board(b, screen, frame, back, plank, ink, face):
    """The shared noticeboard: Screen, its frame (0.15 proud of it), the back panel and the header plank."""
    screen.span((-W / 2, Y0, FZ), (W / 2, Y0 + H, 0.06), face)
    b.span((-HX, Y0 - F, 0.05), (HX, HY, 0.35), back)
    for (x0, y0, x1, y1) in ((-HX, Y0 - F, HX, Y0 + 0.01), (-HX, Y0 + H - 0.01, HX, HY),
                             (-HX, Y0, -W / 2 + 0.01, Y0 + H), (W / 2 - 0.01, Y0, HX, Y0 + H)):
        b.span((x0, y0, FRONT), (x1, y1, 0.06), frame)
    b.span((-HX + 0.3, HY - 0.01, -0.15), (HX - 0.3, TOP, 0.3), plank)
    label(b, "INDEX", 0, HY + (HEAD - 5 * PX) / 2, -0.15, PX, 0.06, ink, -1)


def _paw(b, x, y, z, sw):
    """A paw print standing 0.05 proud of a face at depth z."""
    b.span((x - 0.18, y - 0.22, z - 0.05), (x + 0.18, y + 0.06, z + 0.01), sw)
    for dx, dy in ((-0.22, 0.17), (-0.08, 0.27), (0.08, 0.27), (0.22, 0.17)):
        b.span((x + dx - 0.06, y + dy - 0.06, z - 0.05), (x + dx + 0.06, y + dy + 0.06, z + 0.01), sw)


def _gable(b, roof, eave, y, rise=1.2, z0=-0.9, z1=0.9):
    """A small pitched roof over the board: two wedges meeting at x = 0, with an eave board under them."""
    hw = HX + 1.3
    for s in (-1, 1):                     # each wedge's tall face turned to the ridge
        b.wedge((s * hw / 2, y + rise / 2, (z0 + z1) / 2), (z1 - z0, rise, hw), roof,
                rot=_rot(90 if s < 0 else -90, "Y"))
    b.span((-hw - 0.05, y - 0.15, z0 - 0.05), (hw + 0.05, y + 0.01, z1 + 0.05), eave)


def _alley(b, screen, st):
    _board(b, screen, *st)
    for s in (-1, 1):                                                                    # brick pillars, capped
        x0, x1 = sorted((s * (HX - 0.05), s * (HX + 1.15)))
        b.span((x0 - 0.15, 0, -0.65), (x1 + 0.15, 0.6, 0.85), "concrete")
        b.span((x0, 0.59, -0.5), (x1, TOP + 0.01, 0.7), "brick")
        b.span((x0 - 0.12, Y0 - 0.2, -0.62), (x1 + 0.12, Y0 + 0.15, 0.82), "concrete")
        b.span((x0 - 0.15, TOP, -0.65), (x1 + 0.15, TOP + 0.4, 0.85), "concrete")
        cx = (x0 + x1) / 2                                                               # a lamp on each pillar
        b.span((cx - 0.25, TOP + 0.39, -0.05), (cx + 0.25, TOP + 0.5, 0.25), "fur_black")
        b.span((cx - 0.18, TOP + 0.49, 0.02), (cx + 0.18, TOP + 1.0, 0.18), "lamp_warm")
        b.b.pyramid(RB.p(cx, TOP + 0.99, 0.1), 0.6, 0.3, "fur_black")
    for x in (-HX + 0.9, HX - 0.9):                                                      # paw prints on the plank
        _paw(b, x, HY + HEAD / 2, -0.15, "lamp_warm")


def _park(b, screen, st):
    _board(b, screen, *st)
    roof = TOP + 0.4                                                                     # clear of the header
    for s in (-1, 1):                                                                    # wooden posts
        x = s * (HX + 0.3)
        b.span((x - 0.35, 0, -0.25), (x + 0.35, roof, 0.45), "caramel_wood")
    _gable(b, "dumpster_green", "caramel_wood", roof, z0=-0.7, z1=0.9)
    for dx in (-0.7, 0, 0.7):                                                            # leaf crest on the ridge
        b.ball((dx, roof + 1.3 + (0.2 if dx == 0 else 0), 0.1), 0.45, "leaf_green")
    b.cyl((0, roof + 0.6, -0.75), 0.32, 0.12, "rarity_legend", axis="Z", segments=10)    # gold medal on the gable
    for s in (-1, 1):                                                                    # flower boxes on the posts
        x0, x1 = sorted((s * 0.9, s * 4.6))
        b.span((x0, 0, -0.9), (x1, 0.7, -0.2), "terracotta")
        b.span((x0 + 0.1, 0.69, -0.8), (x1 - 0.1, 0.78, -0.3), "leaf_green")
        for k in range(4):
            b.ball((x0 + 0.6 + 0.8 * k, 0.9, -0.55), 0.2, ("blush", "sparkle", "offwhite", "nose_pink")[k])


def _neighbourhood(b, screen, st):
    _board(b, screen, *st)
    for s in (-1, 1):                                                                    # white posts, teal caps
        x = s * (HX + 0.25)
        b.span((x - 0.3, 0, -0.2), (x + 0.3, TOP, 0.4), "offwhite")
        b.b.pyramid(RB.p(x, TOP - 0.01, 0.1), 0.75, 0.45, "sign_teal")
    pins = (("neon_pink", -1, Y0 - F / 2), ("pastel_butter", 1, Y0 - F / 2), ("pastel_butter", -1, HY - F / 2),
            ("neon_pink", 1, HY - F / 2))
    for sw, sx, y in pins:                                                               # push pins on the frame
        b.cyl((sx * (W / 2 + F / 2), y, FRONT - 0.04), 0.12, 0.1, sw, axis="Z", segments=8)
    for k, x in enumerate((-2.25, -1.5, -0.75, 0.0, 0.75, 1.5, 2.25)):                   # bunting off the plank
        b.box((x, HY, FRONT - 0.01), (0.32, 0.32, 0.04), ("neon_pink", "pastel_butter", "mint")[k % 3],
              rot=_rot(45, "Z"))


def _woods(b, screen, st):
    _board(b, screen, *st)
    for s in (-1, 1):                                                                    # log posts
        x = s * (HX + 0.4)
        b.cyl((x, TOP / 2, 0.1), 0.45, TOP, "dark_wood", segments=8)
        b.cyl((x, TOP + 0.04, 0.1), 0.4, 0.1, "caramel_wood", segments=8)
    b.cyl((0, TOP + 0.45, 0.1), 0.42, 2 * HX + 1.9, "dark_wood", axis="X", segments=8)   # log across the top
    for sx in (-1, 1):
        b.cyl((sx * (HX + 0.96), TOP + 0.45, 0.1), 0.37, 0.1, "caramel_wood", axis="X", segments=8)
    for (x, z, r) in ((-2.8, -0.05, 0.32), (-2.2, 0.25, 0.26), (1.9, 0.0, 0.3), (2.6, 0.3, 0.24)):   # moss
        b.ball((x, TOP + 0.85, z), r, "leaf_dark", scale=(1.3, 0.6, 1.0))
    mx = HX - 0.8                                                                        # a mushroom on the log
    b.cyl((mx, TOP + 0.95, 0.1), 0.12, 0.35, "offwhite", segments=8)
    b.cyl((mx, TOP + 1.18, 0.1), 0.38, 0.18, "bowl_red", r2=0.22, segments=10)
    for (dx, dz) in ((-0.13, -0.08), (0.12, -0.06), (0.0, 0.13)):
        b.span((mx + dx - 0.05, TOP + 1.25, 0.1 + dz - 0.05), (mx + dx + 0.05, TOP + 1.29, 0.1 + dz + 0.05),
               "offwhite")


def _sewer(b, screen, st):
    _board(b, screen, *st)
    for s in (-1, 1):                                                                    # pipe posts with flanges
        x = s * (HX + 0.35)
        b.cyl((x, (TOP + 0.1) / 2, 0.1), 0.35, TOP + 0.1, "metal", segments=10)
        for y in (0.3, Y0 - 0.2, TOP - 0.3):
            b.cyl((x, y, 0.1), 0.47, 0.25, "rust", segments=10)
    b.cyl((0, TOP + 0.35, 0.1), 0.35, 2 * HX + 0.8, "metal", axis="X", segments=10)      # pipe across the top
    b.cyl((0, TOP + 0.85, 0.1), 0.12, 0.4, "rust", segments=6)                           # valve
    b.cyl((0, TOP + 1.5, 0.1), 0.55, 0.12, "eye_green", axis="Z", segments=10)
    b.cyl((0, TOP + 1.5, 0.1), 0.38, 0.14, "concrete_dark", axis="Z", segments=10)
    for x in (-3.0, -1.0, 1.0, 3.0):                                                     # rivets on the frame
        for y in (Y0 - F / 2, HY - F / 2):
            b.cyl((x, y, FRONT - 0.02), 0.08, 0.06, "rust", axis="Z", segments=6)
    for (x, length) in ((-(W / 2 + F / 2), 1.6), (W / 2 + F / 2, 0.9)):                  # slime down the frame
        b.span((x - 0.1, HY - length, FRONT - 0.04), (x + 0.1, HY - 0.03, FRONT + 0.01), "eye_green")
        b.ball((x, HY - length, FRONT - 0.015), 0.13, "eye_green")


BUILD = {"alley": _alley, "park": _park, "neighbourhood": _neighbourhood, "woods": _woods, "sewer": _sewer}


def build(area, mat):
    st = STYLES[area]
    b, screen = RB(), RB()
    BUILD[area](b, screen, st[1:])
    return [b.finalize(st[0], mat), screen.finalize(st[0] + "_Screen", mat)]


ASSETS = {STYLES[a][0]: ((lambda a: lambda mat: build(a, mat))(a), 1500) for a in STYLES}
AREA_OF = {STYLES[a][0]: a for a in STYLES}
