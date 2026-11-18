"""Day 1 return hooks (Design-Agent d1-hooks-spec, Nov 18 2026): the props behind the Away Jar, the Sleepover Bowl
and the Tomorrow Board. Built in Roblox axes (RB: x across, y up, -Z the front); pivots at the base centre.

  CatCafe_Prop_AwayJar             a glass tip jar for the counter, a paw label and a wooden lid ring. The coins are
                                   their own object, `_Coins`, pivoted at the jar's floor, so code scales it in Y
                                   from empty to full (0.05 to 1 of its height).
  CatCafe_Prop_TreatBoard          the Daily Treat Board for the cafe wall: a cork board with 7 paper tags, Day 1 to
                                   Day 7, each with a picture and a stamp spot. The stamps are their own objects
                                   (`_Stamp1` to `_Stamp7`, hidden until a day is claimed) and day 2's gold edge is
                                   `_Glow` (lit when it is tomorrow's prize). The back is at z = 0, flat on the wall.
  CatCafe_Prop_TomorrowGift        a wrapped red present with a gold ribbon and bow, about knee high (1.3 studs).
  CatCafe_Item_FoodBowl_Sleepover  the bait bowl in soft blue with a little pillow in it, for the Sleepover cat.
"""

import math

from mathutils import Vector

from common import GLYPHS, RB, _glyph_rects
from plot import rot_x, rot_z

GOLD, PAPER, CORK, FRAME = "rarity_legend", "offwhite", "cardboard", "caramel_wood"
DIGITS = {"1": ("010", "110", "010", "010", "111"), "2": ("111", "001", "111", "100", "111"),
          "3": ("111", "001", "011", "001", "111"), "4": ("101", "101", "111", "001", "001"),
          "5": ("111", "100", "111", "001", "111"), "6": ("111", "100", "111", "101", "111"),
          "7": ("111", "001", "010", "010", "010")}
LETTERS = {**GLYPHS, **DIGITS}


def _width(s, px):
    return (sum(len(LETTERS[ch][0]) + 1 if ch in LETTERS else 2 for ch in s.upper()) - 1) * px


def _text(b, s, cx, y, z, px, depth, swatch):
    """Block letters and digits centred on cx, reading left to right from the front (-Z), standing proud of z."""
    rx, ux, nrm = Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, -1))
    origin = Vector((cx + _width(s, px) / 2, y, z))
    cur = 0
    for ch in s.upper():
        g = LETTERS.get(ch)
        if g is None:
            cur += 2
            continue
        for r, c, e, h in _glyph_rects(g):
            a = origin + rx * ((cur + c) * px) + ux * ((5 - h) * px)
            bv = a + rx * ((e - c) * px) + ux * ((h - r) * px) + nrm * depth
            b.span([min(a[i], bv[i]) for i in range(3)], [max(a[i], bv[i]) for i in range(3)], swatch)
        cur += len(g[0]) + 1


def build_away_jar(mat):
    name = "CatCafe_Prop_AwayJar"
    b, glass, coins = RB(), RB(), RB()
    b.cyl((0, 0.04, 0), 0.5, 0.08, "dark_wood", segments=14)                         # wooden foot
    glass.cyl((0, 0.66, 0), 0.47, 1.16, "glass", segments=14)                        # the jar
    b.cyl((0, 1.27, 0), 0.5, 0.08, FRAME, segments=14)                               # lid ring, open top
    b.cyl((0, 1.33, 0), 0.4, 0.04, "dark_wood", segments=14)
    b.span((-0.32, 0.45, -0.49), (0.32, 0.85, -0.47), PAPER)                         # paw label on the front
    b.cyl((0, 0.6, -0.5), 0.09, 0.02, "nose_pink", axis="Z", segments=8)
    for dx, dy in ((-0.12, 0.74), (-0.04, 0.78), (0.04, 0.78), (0.12, 0.74)):
        b.cyl((dx, dy, -0.5), 0.035, 0.02, "nose_pink", axis="Z", segments=6)
    # the coin fill: a column of coins up to just under the rim, a heaped top and a few loose coins
    top = 1.08
    coins.cyl((0, 0.08 + (top - 0.08) / 2, 0), 0.43, top - 0.08, GOLD, segments=14)
    for k, (x, z, a) in enumerate(((-0.18, -0.1, 20), (0.15, 0.12, -25), (0.05, -0.2, 35), (-0.05, 0.18, -10))):
        coins.box((x, top + 0.04, z), (0.22, 0.05, 0.22), GOLD, rot=rot_z(a) @ rot_x(10 * (k % 2)))
    for x, z in ((-0.2, -0.3), (0.22, -0.22)):
        coins.box((x, top - 0.25, z), (0.05, 0.05, 0.05), "sparkle")                # glints through the glass
    return [b.finalize(name, mat), glass.finalize(name + "_Glass", mat),
            coins.finalize(name + "_Coins", mat, location=(0, 0.08, 0))]


# The seven days' pictures, simple shapes in a 0.5 stud square about (x, y) on the tag's face at depth z.
def _coin(b, x, y, z, r=0.17):
    b.cyl((x, y, z), r, 0.04, GOLD, axis="Z", segments=10)
    b.cyl((x, y, z - 0.025), r * 0.55, 0.02, "eye_amber", axis="Z", segments=8)


def _fish(b, x, y, z, s=1.0, sw=GOLD, turn=0):
    R = rot_z(turn)
    b.box((x, y, z), (0.3 * s, 0.14 * s, 0.04), sw, rot=R)
    tail = (x + 0.19 * s * math.cos(math.radians(turn)), y + 0.19 * s * math.sin(math.radians(turn)), z)
    b.box(tail, (0.1 * s, 0.14 * s, 0.04), sw, rot=R @ rot_z(45))


def _pic(b, day, x, y, z):
    if day == 1:                                   # a bowl of kibble
        b.span((x - 0.2, y - 0.14, z - 0.02), (x + 0.2, y + 0.02, z), "bowl_red")
        b.span((x - 0.16, y + 0.02, z - 0.02), (x + 0.16, y + 0.1, z), "kibble")
    elif day == 2:                                 # the golden fish pile (500 Golden Fish)
        for (dx, dy, t) in ((-0.13, -0.12, 10), (0.12, -0.12, -10), (0.0, -0.03, 0), (-0.08, 0.07, 15), (0.1, 0.08, -15),
                            (0.0, 0.17, 0)):
            _fish(b, x + dx, y + dy, z - 0.01, 0.75, GOLD, t)
        b.box((x + 0.2, y + 0.22, z - 0.03), (0.06, 0.06, 0.02), "sparkle")
    elif day == 3:                                 # a coin
        _coin(b, x, y, z - 0.01)
    elif day == 4:                                 # a blue fish
        _fish(b, x - 0.04, y, z - 0.01, 1.1, "fish_blue")
    elif day == 5:                                 # a stack of coins
        for k in range(3):
            b.span((x - 0.16, y - 0.18 + 0.1 * k, z - 0.03), (x + 0.16, y - 0.1 + 0.1 * k, z), GOLD)
    elif day == 6:                                 # a star treat
        b.b.star(RB.p(x, y, z - 0.01), 0.18, 0.08, 0.04, "sparkle", rot=(math.radians(90), "X"))
    elif day == 7:                                 # a gift box (never a crate with the coin picture)
        b.span((x - 0.18, y - 0.18, z - 0.02), (x + 0.18, y + 0.1, z), "shirt_red")
        b.span((x - 0.03, y - 0.18, z - 0.035), (x + 0.03, y + 0.1, z - 0.02), GOLD)
        b.span((x - 0.18, y - 0.07, z - 0.035), (x + 0.18, y - 0.01, z - 0.02), GOLD)
        b.span((x - 0.1, y + 0.1, z - 0.035), (x + 0.1, y + 0.17, z - 0.02), GOLD)


def build_treat_board(mat):
    name = "CatCafe_Prop_TreatBoard"
    b, glow = RB(), RB()
    stamps = [RB() for _ in range(7)]
    W, H, D = 6.2, 2.8, 0.12
    b.span((-W / 2, 0, -D), (W / 2, H, 0), FRAME)                                    # frame
    b.span((-W / 2 + 0.15, 0.15, -D - 0.02), (W / 2 - 0.15, H - 0.65, -D + 0.01), CORK)
    b.span((-W / 2 + 0.15, H - 0.6, -D - 0.03), (W / 2 - 0.15, H - 0.15, -D + 0.01), "dark_wood")   # title strip
    _text(b, "DAILY TREATS", 0.0, H - 0.54, -D - 0.03, 0.065, 0.02, "cream")
    tw_, th, gap = 0.72, 1.6, (W - 0.3 - 7 * 0.72) / 8
    for i in range(7):
        day = i + 1
        x0 = -W / 2 + 0.15 + gap + i * (tw_ + gap)
        y0, z = 0.32, -D - 0.04
        x0 = -(x0 + tw_)                                                           # day 1 on the left seen from the front
        cx = x0 + tw_ / 2
        if day == 2:                                                                 # the gold edge, lit as tomorrow
            glow.span((x0 - 0.06, y0 - 0.06, z + 0.005), (x0 + tw_ + 0.06, y0 + th + 0.06, z + 0.025), GOLD)
        b.span((x0, y0, z), (x0 + tw_, y0 + th, z + 0.03), "pastel_butter" if day == 2 else PAPER)
        b.cyl((cx, y0 + th - 0.08, z - 0.01), 0.05, 0.03, "bowl_red", axis="Z", segments=8)   # the pin
        _text(b, f"DAY {day}", cx, y0 + th - 0.4, z, 0.04, 0.015, "dark_wood")
        _pic(b, day, cx, y0 + 0.88, z)
        b.b.ring(RB.p(cx, y0 + 0.32, z - 0.005), 0.22, 0.04, 0.02, "fur_hazel", segments=12, rot=(math.radians(90), "X"))  # stamp spot
        s = stamps[i]                                                                # the paw stamp, hidden until claimed
        s.cyl((cx, y0 + 0.29, z - 0.02), 0.11, 0.02, "bowl_red", axis="Z", segments=8)
        for dx, dy in ((-0.11, 0.1), (-0.04, 0.15), (0.04, 0.15), (0.11, 0.1)):
            s.cyl((cx + dx, y0 + 0.29 + dy, z - 0.02), 0.04, 0.02, "bowl_red", axis="Z", segments=6)
    out = [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]
    out += [s.finalize(f"{name}_Stamp{i + 1}", mat) for i, s in enumerate(stamps)]
    return out


def build_tomorrow_gift(mat):
    name = "CatCafe_Prop_TomorrowGift"
    b = RB()
    S, Hh = 1.2, 1.0
    b.span((-S / 2, 0, -S / 2), (S / 2, Hh, S / 2), "shirt_red")                     # the box
    b.span((-S / 2 - 0.03, Hh - 0.12, -S / 2 - 0.03), (S / 2 + 0.03, Hh + 0.04, S / 2 + 0.03), "bowl_red")   # lid
    for rot in (False, True):                                                        # ribbon round both ways
        if rot:
            b.span((-0.1, -0.005, -S / 2 - 0.045), (0.1, Hh + 0.055, S / 2 + 0.045), GOLD)
        else:
            b.span((-S / 2 - 0.045, -0.005, -0.1), (S / 2 + 0.045, Hh + 0.055, 0.1), GOLD)
    for sx in (-1, 1):                                                               # the bow: two loops and tails
        b.box((sx * 0.2, Hh + 0.18, 0), (0.32, 0.22, 0.12), GOLD, rot=rot_z(sx * -25))
        b.box((sx * 0.16, Hh + 0.07, -0.18), (0.08, 0.04, 0.3), GOLD, rot=rot_z(sx * 15))
    b.ball((0, Hh + 0.12, 0), 0.1, "brass")
    b.span((0.25, 0.35, -S / 2 - 0.06), (0.5, 0.6, -S / 2 - 0.04), PAPER)            # a little gift tag
    b.cyl((0.3, 0.55, -S / 2 - 0.07), 0.025, 0.02, "dark_wood", axis="Z", segments=6)
    return [b.finalize(name, mat)]


def build_sleepover_bowl(mat):
    """The bait bowl's shape in soft blue with a little striped pillow resting in it, for the Sleepover cat."""
    name = "CatCafe_Item_FoodBowl_Sleepover"
    b = RB()
    b.cyl((0, 0.03, 0), 0.45, 0.06, "pastel_sky", segments=12)
    b.b.ring(RB.p(0, 0.18, 0), 0.46, 0.08, 0.26, "pastel_sky", segments=12, bevel=False)
    b.b.ring(RB.p(0, 0.32, 0), 0.48, 0.05, 0.05, "milk", segments=12, bevel=False)
    b.cyl((0, 0.12, 0), 0.38, 0.12, "fish_belly", segments=12)                      # soft blanket
    b.ball((0.05, 0.27, 0.12), 0.26, "pastel_lilac", scale=(1.2, 0.42, 0.8))          # pillow
    b.span((-0.26, 0.3, 0.06), (0.36, 0.33, 0.1), "milk")                            # its stripe
    for x, y in ((-0.15, 0.36), (0.12, 0.4), (0.28, 0.33)):
        b.box((x, y + 0.05, -0.3), (0.05, 0.05, 0.02), "sparkle")                    # little stars on the rim
    return [b.finalize(name, mat)]


ASSETS = {
    "CatCafe_Prop_AwayJar": (build_away_jar, 900),
    "CatCafe_Prop_TreatBoard": (build_treat_board, 5500),      # 7 lettered tags with pictures and stamps
    "CatCafe_Prop_TomorrowGift": (build_tomorrow_gift, 500),
    "CatCafe_Item_FoodBowl_Sleepover": (build_sleepover_bowl, 500),
}
