"""The two cafe themes sold in the Store (#1624, store-pass-looks.md sections 3 to 5): Garden Cafe (the Cafe Style
pass) and Grand Cafe. A theme adds parts to the cafe's front and a few pieces inside; it never moves the walls, the
door, collision, the camera or a station. The engineer puts each theme's models in a `CatCafe_Theme_Garden` or
`CatCafe_Theme_Grand` folder, hides the shell's `_Awning` child Model and shows the theme's own `_Awning` while the
plot's `Theme` attribute names it. The recolours in the spec (Garden's sage wall trim; Grand's cream walls through the
shell's `Paint` tag, gold trim through `PaintTrim` and on the counter, and plum chair cushions as a prop) are
code's; the swatches to use are in each builder's notes and in the style guide section 13.

Swatches (all already in the palette, so no new rows): sage `fur_fern` with `fur_moss` for its shade, warm white
`offwhite`, `terracotta`, `brass`; Grand's cream `cream`, the golds, and plum `royal_berry`.

  CatCafe_Plot_ThemeGarden              the Garden front, placed at the Plot pivot like the shell: two terracotta
                                        troughs of small flowers against the wall either side of the door (clear of
                                        the Lucky Cat plinth and the potted shrub), a hanging brass lamp over the
                                        door on a bracket (`_Bulb`, Neon at night), and `_Awning`: sage and warm white
                                        striped awnings in the shell's awnings' place (the shell's head rails stay)
  CatCafe_Plot_ThemeGrand               the Grand front at the Plot pivot: two cream pilasters with gold bases and
                                        capitals either side of the door under a cream lintel with a gold band, a
                                        plum carpet with gold edges down the path, two black and gold lantern posts on
                                        the path's front corners (`_Bulb`), and `_Awning`: plum and gold stripes
  CatCafe_Plot_ThemeGrandChandelier     the Grand room's small chandelier, at the Plot pivot: a gold rod set between the
                                        first two tie beams over the middle (clear of the pendant lamps), a chain, a
                                        gold ring with six candle arms (`_Glow` flames) and plum drops
  CatCafe_Prop_GardenGarland            Garden's leafy garland over the counter: a sagging swag of sage and green
                                        leaves with small white flowers, 8 studs between its two hooks; pivot at the
                                        middle of the line between the hooks, front -Z
  CatCafe_Prop_GardenTablePot           Garden's terracotta pot with a green sprig for each table top; pivot base centre
  CatCafe_Prop_GrandCushion             Grand's plum cushion with gold piping and four gold tassels for a chair seat;
                                        pivot base centre

The two theme signs are sign styles in signstyles.py (CatCafe_Plot_SignGarden, CatCafe_Plot_SignGrand).
"""

import math

from common import RB
from plot import BEAMS, FRONT, H, WX, _awning, _Route, rot_y

SAGE, SAGE_DK, PLUM = "fur_fern", "fur_moss", "royal_berry"
GOLD, GOLD_LT, GOLD_DK = "gold_mid", "gold_light", "gold_dark"
FLOWERS = ("blush", "offwhite", "pastel_butter", "nose_pink")


def _theme_awning(name, mat, accent, remap):
    """The shell's two window awnings (plot._awning: the same places and shapes) in the theme's colours: `remap`
    turns the shell's offwhite stripes into the theme's, the accent stripes are `accent`. The head rails are left
    out: the shell's stay (on its _Trim, which a paint or theme recolours) and a copy would sit on them."""
    aw, rails = RB(remap=lambda s: remap.get(s, s)), RB()
    route = _Route(aw, rails, ("dark_wood",), chunk=0.0)
    _awning(route, accent, -WX - 5.0, -WX + 6.0)
    _awning(route, accent, WX - 6.0, WX + 5.0)
    return aw.finalize(name + "_Awning", mat)


def build_garden(mat):
    name = "CatCafe_Plot_ThemeGarden"
    b, bulb = RB(), RB()
    F = FRONT
    for sx in (-1, 1):                                                                   # flower troughs
        x0, x1 = sorted((sx * 5.95, sx * 6.85))
        b.span((x0, 0.0, F - 0.85), (x1, 0.7, F - 0.02), "terracotta")
        b.span((x0 - 0.06, 0.62, F - 0.91), (x1 + 0.06, 0.78, F - 0.02), "terracotta")   # its lip
        b.span((x0 + 0.06, 0.7, F - 0.79), (x1 - 0.06, 0.8, F - 0.08), "choco")         # soil
        for k, (dx, dz) in enumerate(((0.2, -0.25), (0.65, -0.6), (0.45, -0.3), (0.25, -0.62), (0.7, -0.2))):
            x, z = x0 + dx, F + dz
            b.box((x, 1.0, z), (0.06, 0.4, 0.06), "leaf_green")                         # stem
            b.ball((x, 1.25, z), 0.16, FLOWERS[(k + (sx > 0)) % len(FLOWERS)])          # bloom
        for dx in (0.15, 0.45, 0.75):
            b.ball((x0 + dx, 0.88, F - 0.45), 0.14, SAGE_DK, scale=(1.4, 0.7, 1.4))     # leaves round the stems
    # the hanging brass lamp over the door, on a bracket above the keystone
    yb, zl = 12.45, F - 1.3
    b.span((-0.25, yb - 0.3, F - 0.12), (0.25, yb + 0.3, F + 0.01), "brass")             # wall plate, into the wall
    b.span((-0.06, yb - 0.06, zl), (0.06, yb + 0.06, F - 0.11), "brass")                  # arm
    b.span((-0.03, 11.55, zl - 0.03), (0.03, yb - 0.06, zl + 0.03), "brass")              # chain
    b.b.pyramid(RB.p(0.0, 11.3, zl), 0.9, 0.3, "brass")                                  # lamp cap
    b.span((-0.45, 11.2, zl - 0.45), (0.45, 11.3, zl + 0.45), "brass")
    for dx in (-0.4, 0.4):                                                               # corner bars
        for dz in (-0.4, 0.4):
            b.span((dx - 0.04, 10.55, zl + dz - 0.04), (dx + 0.04, 11.2, zl + dz + 0.04), "brass")
    b.span((-0.45, 10.45, zl - 0.45), (0.45, 10.55, zl + 0.45), "brass")                  # base
    bulb.span((-0.32, 10.55, zl - 0.32), (0.32, 11.2, zl + 0.32), "lamp_warm")
    return [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat),
            _theme_awning(name, mat, SAGE, {})]


def _lantern_post(b, bulb, x, z):
    b.span((x - 0.35, 0.0, z - 0.35), (x + 0.35, 0.3, z + 0.35), "fur_black")             # foot
    b.cyl((x, 0.36, z), 0.25, 0.12, GOLD, segments=10)                                   # gold collar
    b.cyl((x, 2.8, z), 0.12, 4.9, "fur_black", segments=8)                               # post
    b.cyl((x, 5.2, z), 0.2, 0.1, GOLD, segments=10)
    b.span((x - 0.38, 5.25, z - 0.38), (x + 0.38, 5.35, z + 0.38), "fur_black")
    for dx in (-0.34, 0.34):
        for dz in (-0.34, 0.34):
            b.span((x + dx - 0.04, 5.35, z + dz - 0.04), (x + dx + 0.04, 6.15, z + dz + 0.04), GOLD)
    bulb.span((x - 0.26, 5.35, z - 0.26), (x + 0.26, 6.1, z + 0.26), "lamp_warm")
    b.b.pyramid(RB.p(x, 6.15, z), 0.95, 0.45, "fur_black")
    b.ball((x, 6.7, z), 0.1, GOLD)


def build_grand(mat):
    name = "CatCafe_Plot_ThemeGrand"
    b, bulb = RB(), RB()
    F = FRONT
    for sx in (-1, 1):                                                                   # pilasters by the door
        x0, x1 = sorted((sx * 4.15, sx * 5.05))
        b.span((x0, 0.74, F - 0.32), (x1, 10.65, F + 0.01), "cream")                     # shaft, into the wall
        b.span((x0 - 0.12, 0.0, F - 0.42), (x1 + 0.12, 0.6, F + 0.01), GOLD)            # base
        b.span((x0 - 0.06, 0.6, F - 0.37), (x1 + 0.06, 0.75, F + 0.01), GOLD_LT)
        b.span((x0 - 0.12, 10.6, F - 0.42), (x1 + 0.12, 11.0, F + 0.01), GOLD)          # capital
        b.span((x0 - 0.2, 11.0, F - 0.5), (x1 + 0.2, 11.2, F + 0.01), GOLD_LT)
        for k in range(3):                                                               # fluting
            x = x0 + 0.22 + 0.23 * k
            b.span((x - 0.04, 1.0, F - 0.35), (x + 0.04, 10.3, F - 0.31), GOLD_DK)
    b.span((-5.35, 11.8, F - 0.5), (5.35, 12.6, F + 0.01), "cream")                       # lintel over the keystone
    b.span((-5.3, 11.95, F - 0.53), (5.3, 12.08, F - 0.49), GOLD)                        # its gold band
    b.span((-5.45, 12.58, F - 0.6), (5.45, 12.75, F + 0.01), GOLD)                       # and cornice
    for sx in (-1, 1):                                                                   # the lintel on the capitals
        b.span((sx * 4.6 - 0.25, 11.18, F - 0.4), (sx * 4.6 + 0.25, 11.82, F + 0.01), "cream")
    # the carpet down the path, over the door mat
    b.span((-1.34, 0.08, F - 4.29), (1.34, 0.12, F - 0.05), PLUM)
    for sx in (-1, 1):
        b.span((sx * 1.45 - 0.12, 0.081, F - 4.3), (sx * 1.45 + 0.12, 0.13, F - 0.05), GOLD)
    b.span((-1.57, 0.081, F - 4.42), (1.57, 0.13, F - 4.28), GOLD)
    for sx in (-1, 1):                                                                   # lanterns on the path corners
        _lantern_post(b, bulb, sx * 2.95, F - 4.35)
    return [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat),
            _theme_awning(name, mat, PLUM, {"offwhite": GOLD_LT})]


def build_chandelier(mat):
    name = "CatCafe_Plot_ThemeGrandChandelier"
    b, glow = RB(), RB()
    z0, z1 = BEAMS[0] + 0.3, BEAMS[1] - 0.3                                              # the beams' facing sides
    zc = (z0 + z1) / 2
    y = H - 0.45                                                                         # in the beams' depth
    b.span((-0.12, y, z0 - 0.02), (0.12, y + 0.2, z1 + 0.02), GOLD)                      # rod between the beams
    b.cyl((0.0, y - 0.05, zc), 0.3, 0.1, GOLD, segments=10)                              # ceiling rose
    b.span((-0.04, 10.2, zc - 0.04), (0.04, y - 0.1, zc + 0.04), GOLD_DK)                  # chain
    for yy in (11.6, 10.9):
        b.ball((0.0, yy, zc), 0.1, GOLD)                                                 # chain beads
    yc = 9.9
    b.ball((0.0, yc, zc), 0.32, GOLD, scale=(1.0, 1.2, 1.0))                             # the body
    b.ball((0.0, yc - 0.55, zc), 0.12, PLUM)                                             # its drop
    for k in range(6):                                                                   # ring of arms
        a = 2 * math.pi * k / 6
        cx, cz = 1.0 * math.cos(a), zc + 1.0 * math.sin(a)
        b.box((0.5 * math.cos(a), yc, zc + 0.5 * math.sin(a)), (1.0, 0.08, 0.08), GOLD,
              rot=rot_y(-math.degrees(a)))
        b.cyl((cx, yc + 0.05, cz), 0.16, 0.08, GOLD, segments=8)                         # drip pan
        b.cyl((cx, yc + 0.3, cz), 0.07, 0.42, "offwhite", segments=6)                    # candle
        glow.ball((cx, yc + 0.6, cz), 0.08, "lamp_warm", scale=(1.0, 1.6, 1.0))          # flame
        b.ball((cx, yc - 0.2, cz), 0.08, PLUM)                                           # a plum drop under it
        b.box((cx, yc - 0.06, cz), (0.02, 0.18, 0.02), GOLD_DK)
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]


def build_garland(mat):
    b = RB()
    L, sag = 8.0, 0.8
    n = 20
    for sx in (-1, 1):                                                                   # the hooks
        b.cyl((sx * L / 2, 0.0, 0.0), 0.1, 0.25, "brass", axis="Z", segments=6)
    for k in range(n + 1):
        t = k / n
        x = -L / 2 + L * t
        y = -sag * 4 * t * (1 - t) - 0.1
        sw = (SAGE, "leaf_green", SAGE_DK)[k % 3]
        b.ball((x, y, -0.15), 0.26, sw, scale=(1.3, 0.8, 0.8))
        if k % 3 == 1:
            b.ball((x + 0.1, y - 0.12, -0.38), 0.1, ("offwhite", "pastel_butter")[k % 2])   # small flowers
        if 0 < k < n and k % 4 == 2:                                                     # trailing ends
            b.ball((x, y - 0.35, -0.12), 0.15, SAGE_DK, scale=(0.8, 1.4, 0.8))
    return [b.finalize("CatCafe_Prop_GardenGarland", mat)]


def build_table_pot(mat):
    b = RB()
    b.cyl((0.0, 0.2, 0.0), 0.22, 0.4, "terracotta", r2=0.17, segments=10)
    b.cyl((0.0, 0.39, 0.0), 0.25, 0.08, "terracotta", segments=10)                       # rim
    b.cyl((0.0, 0.42, 0.0), 0.19, 0.03, "choco", segments=10)                            # soil
    b.box((0.0, 0.62, 0.0), (0.04, 0.42, 0.04), "leaf_dark")                             # the sprig
    for k, (dx, y, a) in enumerate(((-0.1, 0.62, 40), (0.1, 0.72, -40), (-0.09, 0.82, 35), (0.06, 0.88, -30))):
        b.ball((dx, y, 0.0), 0.08, (SAGE, "leaf_green")[k % 2], scale=(1.6, 0.6, 1.0))
    return [b.finalize("CatCafe_Prop_GardenTablePot", mat)]


def build_cushion(mat):
    b = RB()
    b.ball((0.0, 0.11, 0.0), 0.55, PLUM, scale=(1.0, 0.2, 1.0))                          # the cushion
    b.cyl((0.0, 0.11, 0.0), 0.56, 0.05, GOLD, segments=12)                               # gold piping round it
    b.cyl((0.0, 0.215, 0.0), 0.06, 0.02, GOLD_LT, segments=8)                            # button
    for a in (45, 135, 225, 315):                                                        # tassels
        x, z = 0.6 * math.cos(math.radians(a)), 0.6 * math.sin(math.radians(a))
        b.ball((x, 0.09, z), 0.06, GOLD)
    return [b.finalize("CatCafe_Prop_GrandCushion", mat)]


ASSETS = {
    "CatCafe_Plot_ThemeGarden": (build_garden, 3000),
    "CatCafe_Plot_ThemeGrand": (build_grand, 3000),
    "CatCafe_Plot_ThemeGrandChandelier": (build_chandelier, 1500),
    "CatCafe_Prop_GardenGarland": (build_garland, 2500),
    "CatCafe_Prop_GardenTablePot": (build_table_pot, 400),
    "CatCafe_Prop_GrandCushion": (build_cushion, 400),
}
