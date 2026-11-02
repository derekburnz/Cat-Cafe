"""The Rally Crate's furniture and decorations (F101, rescue-rally.md section 2: "The Rally Crate holds twelve pieces
made for it ... at the Classic Crate's rarity odds"), in the Rally colours: red (shirt_red), blue (shirt_blue), navy
(pants_navy), gold (rarity_legend) and off-white. They stand on a decor spot like every crate piece (crate_decor.py):
about 4 wide and 2.5 deep round the pivot, base centre, front -Z, nothing collides.

  CatCafe_Decor_BleacherBench   (Rare furniture) two tiers of seat planks, red below and blue above, with footboards
                                on three aluminium frames; a megaphone on the low seat, a gold foam finger on the high
                                one and a pennant on the back rail
  CatCafe_Decor_TrophyShelf     (Epic furniture) a wooden trophy case with a navy back under a red CHAMPS fascia: a big
                                gold cup and a silver one, a framed team photo of two cats, a gold star trophy, a ball,
                                two folded team shirts and a board of gold, silver and bronze medals
  CatCafe_Decor_CheerBunting    (Rare decoration) two striped poles on weighted feet with a string of Rally pennants
                                between them, each flag its own Model `_FlagNN_Pennant` (VFX-Agent's bunting flutter:
                                `_Pennant` inside a Model named *Bunting*), and a pom-pom at each foot
  CatCafe_Decor_VictoryPodium   (Legendary decoration) a 1-2-3 podium with gold, silver and bronze tops and the numbers
                                on its front, marquee bulbs along each step (`_Glow`) and on the top step a gold cup
                                with a paw that turns (`_Trophy_Spin`, F89 2c: a Legendary has a moving part and a
                                light); a silver and a bronze medal lie on the lower steps

The wallpapers, floors and paints are style samples (style_icons.py), the Medal Door and the Finish Line Flap are in
doorsets.py and the crate itself is crates.py's CatCafe_Prop_Crate_Rally.
"""

import math

from common import RB
from icon_art import _glyphs
from plot import rot_y, rot_z

FLAGS = ("shirt_red", "offwhite", "shirt_blue", "rarity_legend")
FRAME = "fur_silver"                 # brushed aluminium
DIGITS = {"1": ("010", "110", "010", "010", "111"), "2": ("111", "001", "111", "100", "111"),
          "3": ("111", "001", "111", "001", "111"), "7": ("111", "001", "010", "010", "010")}


def digit(b, ch, cx, y, z, px, depth, swatch):
    """A block digit 3 x 5 px centred on x = cx, bottom at y, on a face at depth z read from -Z."""
    _glyphs(b, ch, (cx + 1.5 * px, y, z), px, depth, swatch, (-1, 0, 0), (0, 1, 0), DIGITS)


def cup(b, x, y, z, k, main="gold_mid", dark="gold_dark", light="gold_light", seg=12, knot=True, handles=True):
    """A loving cup standing on (x, y, z), 2.1 * k tall: foot, stem, knot, round bowl, rim and ring handles (the Rally
    board's trophy at scale k)."""
    b.cyl((x, y + 0.1 * k, z), 0.5 * k, 0.2 * k, dark, segments=seg)                         # foot
    b.cyl((x, y + 0.45 * k, z), 0.14 * k, 0.5 * k, main, segments=max(6, seg - 4))           # stem
    if knot:
        b.ball((x, y + 0.7 * k, z), 0.22 * k, main)                                         # knot
    b.ball((x, y + 1.35 * k, z), 0.72 * k, main, scale=(1, 0.9, 1))                         # bowl
    b.cyl((x, y + 1.68 * k, z), 0.72 * k, 0.66 * k, main, segments=seg + 2)                 # its sides
    b.cyl((x, y + 2.05 * k, z), 0.8 * k, 0.1 * k, light, segments=seg + 2)                  # rim
    if handles:
        for s in (-1, 1):
            b.b.ring(RB.p(x + s * 0.86 * k, y + 1.55 * k, z), 0.34 * k, 0.13 * k, 0.13 * k, main, segments=seg,
                     rot=(math.pi / 2, "X"))


def cup_paw(b, x, y, z, k, swatch="offwhite"):
    """A paw on the front of cup(x, y, z, k): a pad and four toes, discs sunk into the bowl's side."""
    zf = z - 0.76 * k
    b.cyl((x, y + 1.58 * k, zf), 0.17 * k, 0.16 * k, swatch, axis="Z", segments=10)
    for (dx, dy) in ((-0.19, 0.17), (-0.07, 0.26), (0.07, 0.26), (0.19, 0.17)):
        b.cyl((x + dx * k, y + (1.58 + dy) * k, zf), 0.065 * k, 0.16 * k, swatch, axis="Z", segments=8)


def _pompom(b, x, z, colour, s=0.18):
    """A cheer pom-pom lying on the floor at (x, z): a ball of streamers in the colour and white, its handle out
    toward +X."""
    for k, (dx, dy, dz) in enumerate(((0, 1.0, 0), (1.1, 1.3, -0.4), (-1.0, 1.4, 0.3), (0.2, 2.1, 0.1),
                                      (0.3, 1.3, -1.1), (-0.4, 1.2, 1.0))):
        b.ball((x + dx * s, dy * s, z + dz * s), (1.0 - 0.04 * k) * s, colour if k % 2 == 0 else "offwhite")
    b.cyl((x + 2.6 * s, 0.05, z), 0.05, 0.9 * s * 2, "fur_black", axis="X", segments=6)


# --------------------------------------------------------------------------------------------- bleacher bench --
def build_bleacher_bench(mat):
    name = "CatCafe_Decor_BleacherBench"
    b = RB()
    x0, x1 = -1.95, 1.95
    for fx in (-1.75, 0.0, 1.75):                                                            # three frames
        lo, hi = fx - 0.06, fx + 0.06
        b.span((lo, 0.0, -1.2), (hi, 0.1, 1.12), FRAME)                                        # floor runner
        b.span((lo, 0.1, -1.16), (hi, 0.45, -1.04), FRAME)                                     # under the low step
        for zp in (-0.62, -0.12):
            b.span((lo, 0.1, zp - 0.06), (hi, 0.9, zp + 0.06), FRAME)                          # under the low seat
        b.span((lo, 0.9, -0.85), (hi, 1.0, 0.05), FRAME)                                       # its beam
        b.span((lo, 0.1, 0.29), (hi, 1.75, 0.41), FRAME)                                       # under the high seat
        b.span((lo, 0.1, 0.96), (hi, 2.55, 1.08), FRAME)                                       # the back post
        b.span((lo, 1.75, 0.1), (hi, 1.85, 0.96), FRAME)                                       # the high beam
    b.span((x0, 0.45, -1.25), (x1, 0.55, -0.95), FRAME)                                         # low footboard
    b.span((x0, 1.0, -0.85), (x1, 1.14, -0.35), "shirt_red")                                    # low seat
    b.span((x0, 1.0, -0.25), (x1, 1.1, 0.05), FRAME)                                            # high footboard
    b.span((x0, 1.85, 0.15), (x1, 1.99, 0.65), "shirt_blue")                                    # high seat
    b.span((x0, 2.55, 0.94), (x1, 2.67, 1.1), "offwhite")                                       # back rail
    for (xa, xb) in ((x0, x0 + 0.12), (x1 - 0.12, x1)):                                         # white end caps
        b.span((xa, 1.14, -0.85), (xb, 1.16, -0.35), "offwhite")
        b.span((xa, 1.99, 0.15), (xb, 2.01, 0.65), "offwhite")
    # a pennant on a little pole off the back rail
    px = -1.45
    b.span((px - 0.03, 2.67, 0.99), (px + 0.03, 3.45, 1.05), "dark_wood")
    b.fan_z(1.02, (px + 0.78, 3.17), [(px + 0.03, 3.42), (px + 0.03, 2.92)], 0.04, "shirt_red")
    # a megaphone on its side on the low seat, the bell toward +X
    my, mz = 1.14, -0.6
    for (xa, xb, r, sw) in ((0.45, 0.6, 0.08, "offwhite"), (0.6, 0.8, 0.13, "offwhite"),
                            (0.8, 1.0, 0.18, "offwhite"), (1.0, 1.08, 0.22, "shirt_blue")):
        b.cyl(((xa + xb) / 2, my + r * 0.97, mz), r, xb - xa, sw, axis="X", segments=10)
    b.span((0.62, my, mz - 0.03), (0.72, my + 0.07, mz + 0.03), "fur_black")                  # its handle
    # a gold foam finger lying on the high seat, pointing to +X
    fy = 1.99
    b.span((-1.15, fy, 0.25), (-0.7, fy + 0.16, 0.55), "rarity_legend")                        # the hand
    b.span((-0.7, fy, 0.34), (-0.36, fy + 0.1, 0.46), "rarity_legend")                         # the finger
    b.span((-1.0, fy, 0.18), (-0.84, fy + 0.08, 0.25), "rarity_legend")                        # the thumb
    b.span((-1.4, fy, 0.3), (-1.15, fy + 0.12, 0.5), "shirt_blue")                             # the cuff
    return [b.finalize(name, mat)]


# ---------------------------------------------------------------------------------------------- trophy shelf --
def _star(b, x, y, z, s):
    """A gold four-point star s across standing 0.03 proud of a face at depth z (front -Z)."""
    b.box((x, y, z - 0.015), (0.42 * s, 0.42 * s, 0.03), "rarity_legend", rot=rot_z(45))
    b.span((x - 0.07 * s, y - 0.5 * s, z - 0.03), (x + 0.07 * s, y + 0.5 * s, z), "rarity_legend")
    b.span((x - 0.5 * s, y - 0.07 * s, z - 0.03), (x + 0.5 * s, y + 0.07 * s, z), "rarity_legend")


def _photo(b, x0, x1, y0, y1, zf):
    """A framed team photo standing on a shelf, the frame's front at depth zf: two cats in Rally shirts on a sky.
    Each layer stands 0.04 proud of the one behind, clear of the Part export's z-fight settling (rbx_zfight.LIFT)."""
    p, c, e = zf - 0.04, zf - 0.08, zf - 0.11                                                 # photo, cats, eyes
    b.span((x0, y0, zf), (x1, y1, zf + 0.1), "gold_mid")                                       # the frame
    b.span((x0 + 0.08, y0 + 0.08, p), (x1 - 0.08, y1 - 0.08, zf), "pastel_sky")               # the photo
    b.span((x0 + 0.08, y0 + 0.08, c), (x1 - 0.08, y0 + 0.2, p), "leaf_green")                 # grass
    for cx, fur, shirt in ((x0 + 0.3, "fur_ginger", "shirt_red"), (x1 - 0.3, "fur_grey", "shirt_blue")):
        b.span((cx - 0.13, y0 + 0.2, c), (cx + 0.13, y0 + 0.38, p), shirt)                      # shirt
        b.span((cx - 0.11, y0 + 0.38, c), (cx + 0.11, y0 + 0.56, p), fur)                       # head
        for s in (-1, 1):                                                                       # ears
            b.span((cx + s * 0.1 - 0.035, y0 + 0.56, c), (cx + s * 0.1 + 0.035, y0 + 0.62, p), fur)
        for s in (-1, 1):                                                                       # eyes
            b.span((cx + s * 0.045 - 0.015, y0 + 0.47, e), (cx + s * 0.045 + 0.015, y0 + 0.5, c), "fur_black")


def build_trophy_shelf(mat):
    name = "CatCafe_Decor_TrophyShelf"
    b = RB()
    W, X, D0, D1, H = 1.8, 1.68, -0.45, 0.45, 4.0
    wood = "caramel_wood"
    for s in (-1, 1):
        b.span((min(s * X, s * W), 0.0, D0), (max(s * X, s * W), H, D1), wood)                 # sides
    b.span((-W - 0.05, H, D0 - 0.06), (W + 0.05, H + 0.14, D1 + 0.02), "dark_wood")           # top
    b.span((-X, 0.0, D0), (X, 0.3, D1), "dark_wood")                                            # plinth
    b.span((-X, 0.3, 0.33), (X, H, D1), "pants_navy")                                           # navy back
    shelves = (1.45, 2.75)
    for y in shelves:
        b.span((-X, y, D0), (X, y + 0.1, 0.33), wood)
    b.span((-X, 3.7, D0 - 0.05), (X, H, D0), "shirt_red")                                       # fascia
    for x in (-1.1, 0.0, 1.1):                                                                # three gold stars
        _star(b, x, 3.85, D0 - 0.05, 0.3)
    # top: the big gold cup with a paw, a silver cup
    cup(b, -0.45, 2.85, -0.05, 0.38, seg=10)
    cup_paw(b, -0.45, 2.85, -0.05, 0.38)
    cup(b, 0.95, 2.85, -0.05, 0.28, "fur_silver", "metal", "fur_white", seg=8, knot=False, handles=False)
    # middle: the team photo and a gold star trophy
    _photo(b, -1.35, -0.3, 1.55, 2.45, 0.12)
    sx = 0.85
    b.span((sx - 0.3, 1.55, -0.25), (sx + 0.3, 1.77, 0.1), "dark_wood")                        # its base
    b.span((sx - 0.2, 1.6, -0.26), (sx + 0.2, 1.72, -0.25), "gold_light")                       # plaque
    b.cyl((sx, 1.97, -0.08), 0.05, 0.4, "gold_mid", segments=8)                                # stem
    b.box((sx, 2.37, -0.08), (0.4, 0.4, 0.08), "rarity_legend", rot=rot_z(45))                  # the star
    b.span((sx - 0.07, 2.03, -0.12), (sx + 0.07, 2.71, -0.04), "rarity_legend")
    b.span((sx - 0.34, 2.3, -0.12), (sx + 0.34, 2.44, -0.04), "rarity_legend")
    # bottom: a ball, two folded team shirts, a board of medals
    b.ball((-1.2, 0.62, -0.1), 0.32, "shirt_red")
    jx = -0.35
    b.span((jx - 0.38, 0.3, -0.32), (jx + 0.38, 0.48, 0.18), "shirt_blue")                     # shirts
    b.span((jx - 0.34, 0.48, -0.28), (jx + 0.34, 0.66, 0.14), "shirt_red")
    digit(b, "1", jx, 0.3 + (0.18 - 5 * 0.028) / 2, -0.32, 0.028, 0.02, "offwhite")
    digit(b, "7", jx, 0.48 + (0.18 - 5 * 0.028) / 2, -0.28, 0.028, 0.02, "offwhite")
    mb = (0.45, 1.6, 0.35, 1.3)                                                                # the medal board
    b.span((mb[0], mb[2], 0.23), (mb[1], mb[3], 0.33), "offwhite")
    for k, (mx, metal) in enumerate(((1.33, "gold_mid"), (1.025, "fur_silver"), (0.72, "bronze"))):
        for dx, sw in ((-0.05, "shirt_red"), (0.05, "shirt_blue")):                             # ribbon halves
            b.span((mx + dx - 0.05, 0.8, 0.205), (mx + dx + 0.05, 1.18, 0.23), sw)
        b.cyl((mx, 0.72, 0.2), 0.11, 0.06, metal, axis="Z", segments=10)
    return [b.finalize(name, mat)]


# --------------------------------------------------------------------------------------------- cheer bunting --
POLE_X, POLE_TOP, LINE_Y, SAG = 1.8, 3.4, 3.1, 0.35


def _line_y(x):
    return LINE_Y - SAG * (1 - (x / (POLE_X - 0.07)) ** 2)


def build_cheer_bunting(mat):
    name = "CatCafe_Decor_CheerBunting"
    b = RB()
    for s in (-1, 1):
        x = s * POLE_X
        b.cyl((x, 0.09, 0.0), 0.32, 0.18, "pants_navy", segments=12)                           # weighted foot
        b.span((x - 0.07, 0.18, -0.07), (x + 0.07, POLE_TOP, 0.07), "shirt_blue")               # pole
        for y in (0.8, 1.9, 2.95):
            b.span((x - 0.09, y, -0.09), (x + 0.09, y + 0.16, 0.09), "offwhite")                # stripes
        b.ball((x, POLE_TOP + 0.1, 0.0), 0.14, "rarity_legend")                                # finial
    half = POLE_X - 0.07
    n = 10
    xs = [-half + 2 * half * k / n for k in range(n + 1)]
    for xa, xb in zip(xs, xs[1:]):                                                             # the cord
        ya, yb = _line_y(xa), _line_y(xb)
        length = math.hypot(xb - xa, yb - ya) + 0.04
        ang = math.degrees(math.atan2(yb - ya, xb - xa))
        b.box(((xa + xb) / 2, (ya + yb) / 2, 0), (length, 0.05, 0.05), "offwhite", rot=rot_z(ang))
    _pompom(b, -1.2, -0.35, "shirt_red")
    _pompom(b, 1.05, -0.3, "shirt_blue")
    out = [b.finalize(name, mat)]
    count = 6
    for k in range(count):                       # each flag its own Model, pivot on the cord (VFX flutter, #640)
        x = -1.3 + k * 2.6 / (count - 1)
        xl, xr = x - 0.2, x + 0.2
        yl, yr = _line_y(xl) - 0.025, _line_y(xr) - 0.025
        ym = (yl + yr) / 2
        flag = RB()
        flag.fan_z(0.0, (0, -0.55), [(xl - x, yl - ym), (xr - x, yr - ym)], 0.04, FLAGS[k % len(FLAGS)])
        out.append(flag.finalize(f"{name}_Flag{k + 1:02d}_Pennant", mat, location=(x, ym, 0)))
    return out


# -------------------------------------------------------------------------------------------- victory podium --
STEPS = ((0.0, 1.7, "gold_mid", "1"), (1.3, 1.25, "fur_silver", "2"), (-1.3, 0.95, "bronze", "3"))  # x, top
BASE = 0.1
TOP = 0.1                           # the metal plate on each step


def _lying_medal(b, x, y, z, metal):
    """A medal lying on a step top at height y, its ribbon trailing back."""
    b.cyl((x, y + 0.025, z), 0.17, 0.05, metal, segments=12)
    for dx, sw in ((-0.06, "shirt_red"), (0.06, "shirt_blue")):
        b.span((x + dx - 0.055, y, z + 0.12), (x + dx + 0.055, y + 0.02, z + 0.5), sw)


def build_victory_podium(mat):
    name = "CatCafe_Decor_VictoryPodium"
    b, glow, trophy = RB(), RB(), RB()
    b.span((-2.0, 0.0, -0.66), (2.0, BASE, 0.66), "pants_navy")                                  # plinth
    for (cx, top, metal, num) in STEPS:
        x0, x1 = cx - 0.65, cx + 0.65
        b.span((x0, BASE, -0.6), (x1, top, 0.6), "offwhite")                                    # the step
        b.span((x0 - 0.02, top, -0.62), (x1 + 0.02, top + TOP, 0.62), metal)                   # its plate
        b.span((x0, BASE, -0.62), (x1, BASE + 0.14, -0.6), "shirt_red")                          # kick stripes
        b.span((x0, BASE + 0.14, -0.62), (x1, BASE + 0.22, -0.6), "shirt_blue")
        px = 0.12 if num == "1" else 0.08
        y = BASE + 0.22 + (top - 0.18 - BASE - 0.22 - 5 * px) / 2
        digit(b, num, cx, y, -0.6, px, 0.04, "pants_navy")
        bulbs = 5 if num == "1" else 4                                                          # marquee bulbs
        for k in range(bulbs):
            bx = x0 + 0.18 + k * (1.3 - 0.36) / (bulbs - 1)
            glow.span((bx - 0.05, top - 0.14, -0.66), (bx + 0.05, top - 0.04, -0.6), "lamp_warm")
    # confetti on the top step round the cup
    top1 = STEPS[0][1] + TOP
    bits = ("shirt_red", "shirt_blue", "rarity_legend", "offwhite")
    for k, (r, a) in enumerate(((0.45, 20), (0.5, 75), (0.42, 130), (0.52, 200), (0.47, 250), (0.5, 310))):
        cx, cz = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
        b.box((cx, top1 + 0.01, cz), (0.1, 0.02, 0.06), bits[k % 4], rot=rot_y(a * 1.7))
    _lying_medal(b, 1.25, STEPS[1][1] + TOP, -0.25, "fur_silver")
    _lying_medal(b, -1.3, STEPS[2][1] + TOP, -0.25, "bronze")
    # the cup on top, its own Model so it can turn about its pivot (the middle of its foot)
    k = 0.55
    cup(trophy, 0.0, 0.0, 0.0, k)
    cup_paw(trophy, 0.0, 0.0, 0.0, k)
    return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat),
            trophy.finalize(name + "_Trophy_Spin", mat, location=(0.0, top1, 0.0))]


ASSETS = {
    "CatCafe_Decor_BleacherBench": (build_bleacher_bench, 1800),
    "CatCafe_Decor_TrophyShelf": (build_trophy_shelf, 1800),
    "CatCafe_Decor_CheerBunting": (build_cheer_bunting, 1800),
    "CatCafe_Decor_VictoryPodium": (build_victory_podium, 2400),
}
