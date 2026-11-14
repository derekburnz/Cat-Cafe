"""Store v2 outfit packs (#4026, Derek OK'd the draft 2026-11-13 20:13 UTC): each pack is a cafe sign, a decor piece,
a staff uniform and a cat wearable. The uniforms are colour sets in Looks.UNIFORMS (Club Suit, Winter Coat, Chef Whites,
Space Suit, see UNIFORM_COLOURS), so they need no model here. Wearables sit on the head or face only, never the neck.

  Stylish  CatCafe_Plot_SignClubBanner     a black board in a neon pink and violet tube frame, music notes, a small
                                           disco ball hung over the top centre
           CatCafe_Decor_DiscoBall         a mirror ball on a chrome floor stand, coloured spots on a little stage
           CatCafe_Accessory_CoolShades    chunky black shades, deep blue lenses with a white glint, gold rivets
  Winter   CatCafe_Plot_SignSnowyBanner    a pale ice board in a log frame with snow on top and icicles under it, pine
                                           sprigs at the corners and a big snowflake over the top centre
           CatCafe_Decor_CocoaStand        a cafe-sized cocoa cart: red and white awning with snow, a cocoa pot on a lit
                                           warmer, mugs with marshmallows (the Snowy camp station's little cousin)
           CatCafe_Accessory_WinterBobble  a red knit bobble hat, cream band and stripes, an ice blue snowflake
  Chef     CatCafe_Plot_SignBakeryBanner   a butter board in a cocoa and cream checked frame with bunting under it, a
                                           loaf, a croissant and a rolling pin over the top centre
           CatCafe_Decor_PastryCase        a glass pastry case on a wooden base: cupcakes, croissants and donuts
           CatCafe_Accessory_PackChefHat   a short chef's toque with a cocoa stripe on its band
  Space    CatCafe_Plot_SignStarBanner     a deep space board in a silver and mint frame, a ringed planet, a rocket
                                           with a lit flame over the top centre and twinkles
           CatCafe_Decor_RocketLamp        a rocket floor lamp on a launch pad: portholes and a flame that glow
           CatCafe_Accessory_BubbleHelmet  a glass bubble over the head (no collar), an antenna and two ear pods

The accessories are built about the cats' existing Outfit_Hat (head top) and Outfit_Glasses (face) spots, like
CatCafe_Accessory_Hat and _Glasses, so no cat model changes: the Looks entry names that spot (ACCESSORY_SLOTS). The
signs sit at the Plot's pivot like signstyles.py's (a SignBoard part for the cafe's name, `_Frame` its own part), and
the decor stands on a decor spot (crate_decor.py: about 4 wide and 2.5 deep, base centre, front -Z). Lights are
`_Glow` (Neon), glass the glass swatch.
"""

import math

from mathutils import Matrix

from common import RB, Builder
from plot import rot_x, rot_y, rot_z
from signstyles import FACE, X0, X1, Y0, Y1, _frame, _star

N = "CatCafe_"
# Looks.UNIFORMS rows for Gameplay (main, trim), RGB
UNIFORM_COLOURS = {
    "uniform_club_suit": ("Club Suit", (40, 38, 48), (242, 193, 78)),
    "uniform_winter_coat": ("Winter Coat", (196, 48, 56), (250, 248, 244)),
    "uniform_chef_whites": ("Chef Whites", (250, 248, 242), (92, 62, 44)),
    "uniform_space_suit": ("Space Suit", (222, 228, 240), (96, 200, 180)),
}
ACCESSORY_SLOTS = {"CoolShades": "Glasses", "WinterBobble": "Hat", "PackChefHat": "Hat", "BubbleHelmet": "Hat"}


# ------------------------------------------------------------------------------------------- cat wearables --
def build_cool_shades(mat):
    """At the face spot (0.05 in front of the face, eye height; Blender axes, front -Y)."""
    b = Builder()
    for sx in (-1, 1):
        b.box((sx * 0.21, 0, -0.01), (0.38, 0.06, 0.24), "fur_black", bevel=False)            # frames
        b.box((sx * 0.21, -0.02, -0.015), (0.31, 0.04, 0.18), "galaxy_blue", bevel=False)     # lenses
        b.box((sx * 0.21 - 0.06, -0.045, 0.02), (0.05, 0.012, 0.13), "milk", bevel=False,
              rot=(math.radians(-35), "Y"))                                                    # glint
        b.box((sx * 0.39, -0.035, 0.07), (0.04, 0.02, 0.04), "gold_mid", bevel=False)         # rivets
        b.box((sx * 0.43, 0.3, 0.06), (0.05, 0.62, 0.05), "fur_black", bevel=False)           # arms
    b.box((0, 0, 0.085), (0.86, 0.065, 0.07), "fur_black", bevel=False)                       # the brow bar
    return [b.finalize(N + "Accessory_CoolShades", mat)]


def build_winter_bobble(mat):
    """At the head top spot."""
    b = Builder()
    b.cyl((0, 0, 0.05), 0.37, 0.1, "fur_cream", segments=16, bevel=False)                    # band
    b.cyl((0, 0, 0.16), 0.36, 0.14, "shirt_red", segments=16, bevel=False, radius2=0.26)
    b.cyl((0, 0, 0.27), 0.26, 0.08, "shirt_red", segments=12, bevel=False, radius2=0.12)
    for k in range(8):                                                                       # cream knit stripe
        a = 2 * math.pi * (k + 0.5) / 8
        b.box((0.31 * math.cos(a), 0.31 * math.sin(a), 0.2), (0.07, 0.05, 0.035), "fur_cream", bevel=False,
              rot=(a, "Z"))
    for a in (0, 60, 120):                                                                   # the snowflake, front
        b.box((0, -0.335, 0.15), (0.17, 0.02, 0.03), "pastel_sky", bevel=False,
              rot=Matrix.Rotation(math.radians(a), 3, "Y"))
    b.sphere((0, 0, 0.39), 0.13, "fur_cream", segments=10, rings=6)                         # the bobble
    return [b.finalize(N + "Accessory_WinterBobble", mat)]


def build_pack_chef_hat(mat):
    """At the head top spot: shorter than Chonk's tall toque, with a cocoa stripe."""
    b = Builder()
    b.cyl((0, 0, 0.06), 0.3, 0.12, "offwhite", segments=14, bevel=False)                     # band
    b.cyl((0, 0, 0.07), 0.305, 0.035, "choco", segments=14, bevel=False)                    # its stripe
    b.cyl((0, 0, 0.22), 0.27, 0.2, "milk", segments=14, bevel=False, radius2=0.31)          # crown
    for (x, y) in ((0.15, 0.0), (-0.15, 0.0), (0.0, 0.15), (0.0, -0.15)):
        b.ico((x, y, 0.36), 0.15, "milk")
    b.ico((0, 0, 0.4), 0.16, "milk")
    return [b.finalize(N + "Accessory_PackChefHat", mat)]


def build_bubble_helmet(mat):
    """At the head top spot: a glass bubble over the head and ears down to the chin, no collar."""
    b = Builder()
    b.sphere((0, 0, -0.32), 0.7, "glass", segments=14, rings=8, scale=(1.0, 0.9, 0.88))
    b.cyl((0, 0.05, 0.36), 0.025, 0.24, "fur_lilac_silver", segments=6, bevel=False)        # antenna
    b.sphere((0, 0.05, 0.5), 0.06, "mint", segments=8, rings=4)
    for sx in (-1, 1):                                                                       # ear pods on the glass
        b.cyl((sx * 0.69, 0, -0.3), 0.14, 0.1, "offwhite", segments=10, bevel=False,
              rot=(math.radians(90), "Y"))
        b.cyl((sx * 0.745, 0, -0.3), 0.07, 0.03, "mint", segments=8, bevel=False, rot=(math.radians(90), "Y"))
    return [b.finalize(N + "Accessory_BubbleHelmet", mat)]


# ------------------------------------------------------------------------------------------------- signs --
def _sign(name, board_sw, frame_sw, f=0.35):
    b, board, frame = RB(), RB(), RB()
    board.span((X0, Y0, FACE), (X1, Y1, FACE + 0.1), board_sw)                               # SignBoard
    zf, zb = FACE - 0.12, FACE + 0.1
    if frame_sw:
        _frame(frame, f, zf, zb, frame_sw)
    return b, board, frame, f, zf, zb


def _done(name, mat, b, board, frame, glow=None):
    out = [b.finalize(name, mat), board.finalize(name + "_SignBoard", mat), frame.finalize(name + "_Frame", mat)]
    if glow is not None:
        out.append(glow.finalize(name + "_Glow", mat))
    return out


def _note(b, x, y, z, s, sw):
    b.cyl((x, y, z), 0.22 * s, 0.08, sw, axis="Z", segments=8)
    b.box((x + 0.19 * s, y + 0.45 * s, z), (0.07 * s, 0.9 * s, 0.08), sw)
    b.box((x + 0.36 * s, y + 0.84 * s, z), (0.36 * s, 0.1 * s, 0.08), sw, rot=rot_z(-25))


def build_club_banner(mat):
    name = N + "Plot_SignClubBanner"
    b, board, frame, f, zf, zb = _sign(name, "fur_ink", "fur_black", f=0.4)
    glow = RB()
    for (xa, xb, ya, yb, sw) in ((X0 - 0.25, X1 + 0.25, Y0 - 0.25, Y0 - 0.12, "neon_pink"),
                                 (X0 - 0.25, X1 + 0.25, Y1 + 0.12, Y1 + 0.25, "aurora_violet"),
                                 (X0 - 0.25, X0 - 0.12, Y0 - 0.12, Y1 + 0.12, "neon_pink"),
                                 (X1 + 0.12, X1 + 0.25, Y0 - 0.12, Y1 + 0.12, "aurora_violet")):
        glow.span((xa, ya, zf - 0.08), (xb, yb, zf - 0.02), sw)                              # the tube frame
    for (x, y, s, sw) in ((-7.0, 13.8, 0.8, "neon_pink"), (6.4, 15.3, 0.7, "aurora_violet")):
        _note(glow, x, y, FACE - 0.03, s, sw)
    cy = Y1 + f + 1.6                                                                        # the little disco ball
    b.box((0, Y1 + f + 0.45, zf + 0.02), (0.06, 0.9, 0.06), "metal")
    b.ball((0, cy, zf - 0.2), 0.75, "fur_silver")
    for k in range(10):
        a = math.radians(k * 36)
        b.box((0.62 * math.cos(a), cy + 0.62 * math.sin(a), zf - 0.72), (0.22, 0.22, 0.04),
              ("metal", "pearl")[k % 2], rot=rot_z(k * 36))
    for (x, sw) in ((-1.6, "neon_pink"), (1.6, "pastel_sky")):                               # two sparkles by it
        glow.box((x, cy + 0.3, zf - 0.1), (0.35, 0.08, 0.06), sw, rot=rot_z(45))
        glow.box((x, cy + 0.3, zf - 0.1), (0.35, 0.08, 0.06), sw, rot=rot_z(-45))
    b.span((-1.0, Y1 + f, zf + 0.02), (1.0, Y1 + f + 0.12, zb), "fur_black")
    return _done(name, mat, b, board, frame, glow)


def build_snowy_banner(mat):
    name = N + "Plot_SignSnowyBanner"
    b, board, frame, f, zf, zb = _sign(name, "pearl", "dark_wood", f=0.45)
    for x0 in range(int(X0) - 1, int(X1) + 1, 2):                                            # snow on the top log
        b.box((x0 + 1.0, Y1 + f + 0.08, zf + 0.08), (2.1, 0.22, 0.4), "milk")
    for k in range(13):                                                                      # icicles under it
        x = X0 + 0.4 + k * (X1 - X0 - 0.8) / 12
        h = (0.5, 0.8, 0.4, 0.65)[k % 4]
        b.box((x, Y0 - f - h / 2, zf + 0.06), (0.14, h, 0.14), "pastel_sky", rot=rot_z(45 if k % 2 else 0) @ rot_x(0))
    for sx in (-1, 1):                                                                       # pine sprigs
        for k in range(3):
            b.box((sx * (X1 + 0.2), Y1 + 0.2 - k * 0.35, zf - 0.1), (0.9 - k * 0.15, 0.18, 0.08), "leaf_dark",
                  rot=rot_z(sx * (25 + 15 * k)))
        b.ball((sx * (X1 - 0.2), Y1 + 0.05, zf - 0.12), 0.16, "bowl_red")
    cy = Y1 + f + 1.5                                                                        # the snowflake
    b.span((-0.9, Y1 + f, zf + 0.02), (0.9, Y1 + f + 0.12, zb), "dark_wood")
    for a in (0, 60, 120):
        b.box((0, cy, zf - 0.02), (2.4, 0.22, 0.12), "pastel_sky", rot=rot_z(a))
        for sgn in (-1, 1):
            r = rot_z(a)
            tip = r @ Matrix.Translation((sgn * 0.85, 0, 0)).to_translation()
            for t in (35, -35):
                b.box((tip.x, cy + tip.y, zf - 0.04), (0.5, 0.12, 0.1), "milk", rot=rot_z(a + sgn * t + (180 if sgn < 0 else 0)))
    b.ball((0, cy, zf - 0.1), 0.25, "milk")
    return _done(name, mat, b, board, frame)


def build_bakery_banner(mat):
    name = N + "Plot_SignBakeryBanner"
    b, board, frame, f, zf, zb = _sign(name, "pastel_butter", None, f=0.4)
    n = 22                                                                                   # checked frame
    w = (X1 - X0 + 2 * f) / n
    for k in range(n):
        for (ya, yb, j) in ((Y0 - f, Y0, 0), (Y1, Y1 + f, 1)):
            frame.span((X0 - f + k * w, ya, zf), (X0 - f + (k + 1) * w, yb, zb), ("choco", "fur_cream")[(k + j) % 2])
    for (xa, xb) in ((X0 - f, X0), (X1, X1 + f)):
        for k in range(4):
            y = Y0 + k * (Y1 - Y0) / 4
            frame.span((xa, y, zf), (xb, y + (Y1 - Y0) / 4, zb), ("fur_cream", "choco")[k % 2])
    for k in range(9):                                                                       # bunting under it
        x = X0 + 0.9 + k * (X1 - X0 - 1.8) / 8
        b.fan_z(zf + 0.04, (x, Y0 - f - 1.0), [(x - 0.45, Y0 - f), (x + 0.45, Y0 - f)], 0.06,
                ("apron_pink", "pastel_sky", "pastel_butter")[k % 3])
    b.span((X0, Y0 - f - 0.06, zf + 0.02), (X1, Y0 - f + 0.02, zf + 0.08), "dark_wood")       # its string
    cy = Y1 + f + 0.9                                                                        # loaf, croissant, pin
    b.span((-2.6, Y1 + f, zf + 0.02), (2.6, Y1 + f + 0.12, zb), "caramel_wood")
    b.ball((-1.3, cy, zf - 0.1), 0.85, "fur_toffee", scale=(1.3, 0.75, 0.8))
    for k in range(3):
        b.box((-1.3 + (k - 1) * 0.45, cy + 0.5, zf - 0.6), (0.12, 0.3, 0.06), "fur_croissant_dark", rot=rot_z(30))
    for i in range(5):
        t = (i - 2) / 2
        b.box((1.4 + t * 0.6, cy - 0.1 + 0.15 * abs(t), zf - 0.15), (0.42 - 0.08 * abs(i - 2), 0.55 - 0.1 * abs(i - 2), 0.4),
              "fur_croissant", rot=rot_z(-t * 22))
    b.cyl((0.1, cy + 1.1, zf - 0.2), 0.16, 3.6, "caramel_wood", axis="X", segments=8)
    for sx in (-1, 1):
        b.cyl((0.1 + sx * 2.05, cy + 1.1, zf - 0.2), 0.08, 0.5, "dark_wood", axis="X", segments=6)
    return _done(name, mat, b, board, frame)


def build_star_banner(mat):
    name = N + "Plot_SignStarBanner"
    b, board, frame, f, zf, zb = _sign(name, "galaxy_blue", "fur_lilac_silver", f=0.4)
    glow = RB()
    for x in (X0 - f / 2, X1 + f / 2):                                                       # mint lights on the ends
        for y in (Y0 + 0.5, (Y0 + Y1) / 2, Y1 - 0.5):
            glow.cyl((x, y, zf - 0.03), 0.1, 0.06, "mint", axis="Z", segments=8)
    for k, (x, y, r) in enumerate(((-7.2, 16.1, 0.16), (-4.8, 13.8, 0.12), (4.6, 16.2, 0.12), (7.1, 13.9, 0.17),
                                   (2.4, 13.7, 0.1), (-2.6, 16.3, 0.1))):
        glow.box((x, y, FACE - 0.015), (r * 2.2, r * 0.45, 0.03), "sparkle", rot=rot_z(12 * k))
        glow.box((x, y, FACE - 0.016), (r * 0.45, r * 2.2, 0.03), "sparkle", rot=rot_z(12 * k))
    b.ball((X1 + 0.4, Y1 + 0.5, zf - 0.3), 0.8, "fur_apricot")                               # a ringed planet
    b.cyl((X1 + 0.4, Y1 + 0.5, zf - 0.3), 1.35, 0.08, "pastel_lilac", axis="Z", segments=16)
    b.span((-1.0, Y1 + f, zf + 0.02), (1.0, Y1 + f + 0.12, zb), "fur_lilac_silver")         # the rocket
    base = Y1 + f + 0.9
    b.cyl((0, base + 0.9, zf - 0.3), 0.5, 1.8, "milk", segments=10)
    b.cyl((0, base + 2.1, zf - 0.3), 0.5, 0.6, "bowl_red", segments=10, r2=0.05)
    b.cyl((0, base + 1.1, zf - 0.82), 0.2, 0.06, "fish_blue", axis="Z", segments=10)
    for sx in (-1, 1):
        b.wedge((sx * 0.6, base + 0.3, zf - 0.3), (0.12, 0.7, 0.5), "bowl_red", rot=rot_x(-90) @ rot_y(0))
    glow.cyl((0, base - 0.25, zf - 0.3), 0.32, 0.5, "fur_orange", segments=8, r2=0.1)       # flame (points down)
    for sx in (-1, 1):
        _star(b, sx * 2.0, base + 1.6, zf - 0.06, 0.4, "sparkle", d=0.1)
    return _done(name, mat, b, board, frame, glow)


# ------------------------------------------------------------------------------------------------- decor --
def build_disco_ball(mat):
    b, glow = RB(), RB()
    b.cyl((0, 0.15, 0), 1.2, 0.3, "fur_ink", segments=14)                                   # a little stage
    b.cyl((0, 0.32, 0), 1.08, 0.05, "fur_black", segments=14)
    for k, sw in enumerate(("neon_pink", "pastel_sky", "rarity_legend", "aurora_violet", "mint")):
        a = math.radians(k * 72 + 20)
        glow.cyl((0.72 * math.cos(a), 0.36, 0.6 * math.sin(a)), 0.18, 0.03, sw, segments=8)   # light spots
    b.cyl((0.75, 0.5, 0.45), 0.14, 0.3, "metal", segments=8)                                    # chrome stand
    b.cyl((0.75, 2.6, 0.45), 0.07, 4.0, "fur_silver", segments=8)
    b.box((0.38, 4.6, 0.22), (0.95, 0.08, 0.08), "fur_silver", rot=rot_y(-30))
    b.box((0, 4.35, 0), (0.05, 0.5, 0.05), "metal")
    cy = 3.6
    b.ball((0, cy, 0), 0.7, "fur_silver")
    for ring, (yy, rr, n) in enumerate(((0.0, 0.7, 12), (0.38, 0.6, 10), (-0.38, 0.6, 10), (0.6, 0.36, 6),
                                        (-0.6, 0.36, 6))):
        for k in range(n):
            a = math.radians(k * 360 / n + ring * 9)
            b.box((rr * math.cos(a), cy + yy, rr * math.sin(a)), (0.2, 0.2, 0.04), ("metal", "pearl", "pastel_lilac")[k % 3],
                  rot=rot_y(-math.degrees(a) + 90) @ rot_x(-math.degrees(math.atan2(yy, rr))))
    return [b.finalize(N + "Decor_DiscoBall", mat), glow.finalize(N + "Decor_DiscoBall_Glow", mat)]


def build_cocoa_stand(mat):
    b, glow = RB(), RB()
    b.span((-1.7, 0, -0.9), (1.7, 1.9, 0.9), "shirt_red")                                    # the cart's body
    b.span((-1.8, 1.9, -1.0), (1.8, 2.05, 1.0), "caramel_wood")                              # its counter
    for sx in (-1, 1):
        for k in range(2):
            b.box((sx * 0.9 - 0.25 + k * 0.5, 1.0, -0.92), (0.08, 0.4, 0.02), "milk", rot=rot_z(45 + 90 * k))  # flakes
    for sx in (-1, 1):
        b.cyl((sx * 1.4, 0.35, -0.95), 0.35, 0.12, "dark_wood", axis="Z", segments=10)          # wheels
        b.box((sx * 1.65, 2.9, 0.75), (0.1, 1.7, 0.1), "caramel_wood")                      # awning posts
    for k in range(6):                                                                        # striped awning
        x = -1.9 + k * 0.633
        b.box((x + 0.316, 3.75, -0.1), (0.633, 0.12, 2.2), ("shirt_red", "milk")[k % 2], rot=rot_x(-14))
    b.box((0, 3.92, 0.15), (3.8, 0.12, 1.4), "milk", rot=rot_x(-14))                          # snow on it
    glow.cyl((-0.6, 2.12, 0.15), 0.38, 0.1, "fur_orange", segments=10)                       # warmer
    b.cyl((-0.6, 2.5, 0.15), 0.33, 0.6, "bowl_red", segments=10, r2=0.26)                    # cocoa pot
    b.box((-0.25, 2.65, 0.15), (0.3, 0.07, 0.07), "bowl_red", rot=rot_z(-30))
    for k, x in enumerate((0.3, 0.85, 1.35)):
        b.cyl((x, 2.26, -0.35 + 0.25 * (k % 2)), 0.16, 0.36, ("milk", "pastel_sky", "milk")[k], segments=8)
        b.cyl((x, 2.45, -0.35 + 0.25 * (k % 2)), 0.13, 0.03, "choco", segments=8)
        b.box((x, 2.5, -0.35 + 0.25 * (k % 2)), (0.1, 0.07, 0.1), "fur_cream")
    b.span((-1.2, 2.9, 0.9), (1.2, 3.35, 1.0), "dark_wood")                                  # HOT COCOA board
    b.text("COCOA", (-1.0, 2.98, 0.88), 0.07, 0.03, "fur_cream")
    return [b.finalize(N + "Decor_CocoaStand", mat), glow.finalize(N + "Decor_CocoaStand_Glow", mat)]


def build_pastry_case(mat):
    b = RB()
    b.span((-1.85, 0, -1.0), (1.85, 1.4, 1.0), "caramel_wood")                               # base
    b.span((-1.9, 1.4, -1.05), (1.9, 1.52, 1.05), "dark_wood")
    for k in range(3):
        b.box((-1.2 + k * 1.2, 0.7, -1.01), (0.9, 0.9, 0.02), "fur_toffee")                   # panels
    b.span((-1.8, 2.25, -0.95), (1.8, 2.3, 0.95), "milk")                                    # the middle shelf
    b.span((-1.9, 3.05, -1.05), (1.9, 3.2, 1.05), "dark_wood")                               # the lid
    for sx in (-1, 1):
        b.span((sx * 1.85 - 0.05, 1.52, -1.0), (sx * 1.85 + 0.05, 3.05, 1.0), "dark_wood")   # end posts
    b.span((-1.8, 1.55, -0.98), (1.8, 3.0, -0.92), "glass")                                  # the glass front
    for k, x in enumerate((-1.2, -0.4, 0.4, 1.2)):                                            # lower shelf: cupcakes
        b.cyl((x, 1.68, -0.1), 0.24, 0.28, "caramel_wood", segments=8, r2=0.3)
        b.ball((x, 1.92, -0.1), 0.28, ("apron_pink", "fur_cream", "pastel_sky", "fur_strawberry")[k], scale=(1, 0.7, 1))
        b.ball((x, 2.1, -0.1), 0.07, "bowl_red")
    for k, x in enumerate((-1.2, -0.3, 0.6)):                                                 # upper: croissants
        for i in range(3):
            t = i - 1
            b.box((x + t * 0.28, 2.45, 0.0), (0.26, 0.24 - 0.04 * abs(t), 0.35), "fur_croissant", rot=rot_z(-t * 20))
    b.cyl((1.35, 2.38, 0.0), 0.32, 0.14, "fur_toffee", segments=10)                          # a donut
    b.cyl((1.35, 2.46, 0.0), 0.28, 0.04, "apron_pink", segments=10)
    b.cyl((1.35, 2.49, 0.0), 0.1, 0.03, "caramel_wood", segments=8)
    return [b.finalize(N + "Decor_PastryCase", mat)]


def build_rocket_lamp(mat):
    b, glow = RB(), RB()
    b.cyl((0, 0.15, 0), 1.3, 0.3, "fur_lilac_silver", segments=12)                          # launch pad
    for k in range(4):
        a = math.radians(45 + 90 * k)
        b.box((1.0 * math.cos(a), 0.32, 1.0 * math.sin(a)), (0.3, 0.06, 0.3), "rarity_legend")
    glow.cyl((0, 0.75, 0), 0.4, 0.9, "fur_orange", segments=8, r2=0.6)                      # the flame
    glow.cyl((0, 0.85, 0), 0.22, 0.8, "rarity_legend", segments=8, r2=0.4)
    b.cyl((0, 2.6, 0), 0.72, 2.8, "milk", segments=12)                                        # body
    b.cyl((0, 4.45, 0), 0.72, 0.9, "milk", segments=12, r2=0.4)
    b.cyl((0, 5.15, 0), 0.4, 0.5, "bowl_red", segments=12, r2=0.06)                          # nose
    b.cyl((0, 1.35, 0), 0.62, 0.3, "fur_lilac_silver", segments=12)                         # nozzle
    for k in range(3):                                                                        # fins
        a = 90 + 120 * k
        b.wedge((0.95 * math.cos(math.radians(a)), 1.8, -0.95 * math.sin(math.radians(a))), (0.12, 1.3, 0.7),
                "bowl_red", rot=rot_y(a + 90))
    for y in (3.3, 2.2):                                                                      # portholes (lamps)
        b.cyl((0, y, -0.7), 0.3, 0.1, "fur_lilac_silver", axis="Z", segments=12)
        glow.cyl((0, y, -0.74), 0.22, 0.06, "pastel_butter", axis="Z", segments=12)
    b.cyl((0, 3.9, 0), 0.74, 0.12, "bowl_red", segments=12)                                  # a stripe
    return [b.finalize(N + "Decor_RocketLamp", mat), glow.finalize(N + "Decor_RocketLamp_Glow", mat)]


ASSETS = {
    N + "Accessory_CoolShades": (build_cool_shades, 300),
    N + "Accessory_WinterBobble": (build_winter_bobble, 500),
    N + "Accessory_PackChefHat": (build_pack_chef_hat, 500),
    N + "Accessory_BubbleHelmet": (build_bubble_helmet, 600),
    N + "Plot_SignClubBanner": (build_club_banner, 3000),
    N + "Plot_SignSnowyBanner": (build_snowy_banner, 3000),
    N + "Plot_SignBakeryBanner": (build_bakery_banner, 3000),
    N + "Plot_SignStarBanner": (build_star_banner, 3000),
    N + "Decor_DiscoBall": (build_disco_ball, 3000),
    N + "Decor_CocoaStand": (build_cocoa_stand, 3000),
    N + "Decor_PastryCase": (build_pastry_case, 3000),
    N + "Decor_RocketLamp": (build_rocket_lamp, 3000),
}
