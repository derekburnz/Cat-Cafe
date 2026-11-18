"""#5225 (Derek 2026-11-18: redo the cat food for XP in the same style as the bait food set): the five XP cat foods,
fed to one cat for XP, each on the same mint cake plate so they never read as bait (bait sits in the cat bowl,
foodbowls.py). The plate and the food grow with the XP: a small plate with one shrimp, then fish cookies, a cupcake,
a feast platter, and the Royal Feast on a gold platter with a crown. Each carries a little mint star pick, the XP
mark. Same three-quarter view, outline and frame box as the bait set; icons.py renders each as CatCafe_Icon_XpFood_<Food>.

  SmallSnack   small_cat_snack   600 XP     one pink shrimp
  CatSnack     cat_snack         2,000 XP   two fish cookies
  BigSnack     big_cat_snack     6,000 XP   a cupcake with a fish cookie on top
  CatFeast     cat_feast         20,000 XP  a platter: a whole fish, a cupcake, cookies and shrimp
  RoyalFeast   royal_feast       50,000 XP  the feast on a gold platter with a crown

Built with RB in Roblox axes (x across, y up, the front toward -Z). Pictures only: nothing here is placed in the game.
"""

import math

from mathutils import Matrix

from common import RB
from foodbowls import _fish
from icon_art import _sb, _star_up, _twinkle
from plot import rot_z

FOOT = 0.2         # the plate's foot height
DISH = 0.16        # the plate's thickness; its top is FOOT + DISH


def _frame(mat, name):
    """The same framing box for every XP food (icons.py hides it), just wider than the Royal Feast's platter, so the
    plates show their growth and the small one still reads on a phone."""
    f = RB()
    f.span((-1.62, -0.05, -1.62), (1.62, 2.55, 1.62), "cream")
    ob = f.finalize(name + "_Frame", mat)
    ob["fit_only"] = True
    return ob


def _rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _plate(b, r, rim="mint", body="offwhite", foot="mint"):
    """The XP cake plate: a short foot, a wide flat dish with a raised coloured rim and a ring of dots on it."""
    b.cyl((0, FOOT / 2, 0), r * 0.42, FOOT, foot, r2=r * 0.3, segments=24)
    b.cyl((0, FOOT + DISH / 2, 0), r * 0.86, DISH, body, r2=r, segments=32)
    b.cyl((0, FOOT + DISH + 0.04, 0), r + 0.06, 0.12, rim, segments=32)
    b.cyl((0, FOOT + DISH + 0.06, 0), r - 0.12, 0.1, body, segments=32)
    for k in range(14):
        a = 2 * math.pi * (k + 0.5) / 14
        _sb(b, (r * 0.97 * math.cos(a), FOOT + DISH + 0.12, r * 0.97 * math.sin(a)), 0.06, "offwhite", segments=8,
            rings=4)
    return FOOT + DISH + 0.1


def _pick(b, x, y, z, h, s=0.34, sw="mint"):
    """The XP mark: a little star on a stick, stuck in the food."""
    b.box((x, y + h / 2, z), (0.05, h, 0.05), "caramel_wood")
    _star_up(b, x, y + h + s * 0.35, z - 0.02, s, s * 0.45, 0.1, sw)
    _star_up(b, x, y + h + s * 0.35, z - 0.07, s * 0.5, s * 0.22, 0.04, "offwhite")


def _shrimp(b, x, y, z, s, yaw=0.0):
    """A curled pink shrimp lying on its side: beads along a C, a fan tail and two feelers."""
    ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def at(u, v):
        return (x + u * ca, y + v, z - u * sa)
    n, R = 8, s * 0.42
    a_head, a_tail = 250.0, -40.0                         # a tight C opening to the picture's right
    for i in range(n):
        a = math.radians(a_head + (a_tail - a_head) * i / (n - 1))
        rr = s * (0.3 - 0.022 * i)
        c = at(R * math.cos(a), R * math.sin(a) + R + s * 0.12)
        _sb(b, c, rr, "fur_strawberry", scale=(1.0, 1.0, 0.85), segments=14, rings=8)
        if 0 < i < n - 1:
            b.box((c[0], c[1], c[2] - rr * 0.8), (rr * 0.3, rr * 1.5, 0.03), "offwhite",
                  rot=rot_z(math.degrees(a) + 90))
    ta = math.radians(a_tail)
    tx, ty, tz = at(R * math.cos(ta), R * math.sin(ta) + R + s * 0.12)
    for deg in (-35, 0, 35):
        b.box((tx - s * 0.1, ty - s * 0.12, tz), (s * 0.12, s * 0.34, s * 0.16), "fur_rose", rot=rot_z(deg + 40))
    ha = math.radians(a_head)
    hx, hy, hz = at(R * math.cos(ha), R * math.sin(ha) + R + s * 0.12)
    _sb(b, (hx + s * 0.05, hy + s * 0.04, hz - s * 0.22), s * 0.07, "fur_black", segments=10, rings=5)
    for deg in (20, 38):
        b.box((hx + s * 0.32, hy + s * 0.05, hz), (s * 0.03, s * 0.75, s * 0.03), "fur_rose", rot=rot_z(-deg - 30))


def _fish_cookie(b, x, y, z, s, sw="treat_tan", icing="offwhite", lean=0.0, yaw=0.0):
    """A fish shaped biscuit standing up and facing the front, an icing eye and stripes."""
    rot = Matrix.Rotation(math.radians(yaw), 3, "Y") @ rot_z(lean)
    b.b.sphere(RB.p(x, y, z), s * 0.5, sw, segments=18, rings=8, scale=(1.0, 0.18, 0.62),
               rot=RB._rot(rot))
    ux, uy = math.cos(math.radians(lean)), math.sin(math.radians(lean))
    tx, ty = x - ux * s * 0.6, y - uy * s * 0.6
    b.fan_z(z + 0.0, (tx + ux * s * 0.12, ty + uy * s * 0.12),
            [(tx - ux * s * 0.2 - uy * s * 0.28, ty - uy * s * 0.2 + ux * s * 0.28),
             (tx - ux * s * 0.2 + uy * s * 0.28, ty - uy * s * 0.2 - ux * s * 0.28)], s * 0.16, sw)
    _sb(b, (x + ux * s * 0.24 - uy * s * 0.06, y + uy * s * 0.24 + ux * s * 0.06, z - s * 0.1), s * 0.07, icing,
        scale=(1.0, 1.0, 0.5), segments=10, rings=5)
    for k in (-1, 0):
        b.box((x + ux * k * s * 0.18, y + uy * k * s * 0.18, z - s * 0.095), (s * 0.04, s * 0.42, s * 0.02), icing,
              rot=rot_z(lean))


def _cupcake(b, x, y, z, s, frosting="fur_strawberry", cup="mint"):
    """A cupcake: a striped paper cup, a domed swirl of frosting, sprinkles and a cherry."""
    b.cyl((x, y + s * 0.3, z), s * 0.42, s * 0.6, cup, r2=s * 0.56, segments=20)
    for k in range(10):
        a = 2 * math.pi * (k + 0.25) / 10
        b.box((x + s * 0.5 * math.cos(a), y + s * 0.3, z + s * 0.5 * math.sin(a)), (s * 0.06, s * 0.58, s * 0.06),
              "offwhite", rot=Matrix.Rotation(-a, 3, "Y"))
    for (r, dy) in ((0.62, 0.68), (0.48, 0.92), (0.3, 1.1)):
        _sb(b, (x, y + s * dy, z), s * r, frosting, scale=(1.0, 0.45, 1.0), segments=22, rings=10)
    for k in range(9):
        a = 2 * math.pi * k / 9
        b.box((x + s * 0.38 * math.cos(a), y + s * (0.88 + 0.06 * (k % 2)), z + s * 0.38 * math.sin(a)),
              (s * 0.12, s * 0.035, s * 0.035), ("pastel_butter", "pastel_sky", "offwhite")[k % 3], rot=rot_z(25 * k))
    return y + s * 1.18


def small_snack(mat):
    """Small Snack: one curled pink shrimp on the small XP plate."""
    b = RB()
    top = _plate(b, 1.12)
    _shrimp(b, 0.0, top + 0.02, 0.0, 1.55, yaw=-6)
    _pick(b, 0.78, top, 0.3, 1.15, s=0.4)
    return [b.finalize("CatCafe_IconArt_XpFood_SmallSnack", mat), _frame(mat, "CatCafe_IconArt_XpFood_SmallSnack")]


def cat_snack(mat):
    """Cat Snack: two fish cookies leaning together on a slightly bigger plate."""
    b = RB()
    top = _plate(b, 1.24)
    _fish_cookie(b, -0.4, top + 0.62, 0.12, 1.45, sw="treat_tan", lean=14, yaw=-8)
    _fish_cookie(b, 0.44, top + 0.6, -0.12, 1.4, sw="fur_caramel", icing="fur_strawberry", lean=-16, yaw=10)
    _pick(b, 0.05, top + 0.7, 0.4, 1.05, s=0.42)
    return [b.finalize("CatCafe_IconArt_XpFood_CatSnack", mat), _frame(mat, "CatCafe_IconArt_XpFood_CatSnack")]


def big_snack(mat):
    """Big Snack: a tall cupcake with a fish cookie standing in its frosting."""
    b = RB()
    top = _plate(b, 1.36)
    peak = _cupcake(b, 0.0, top, 0.0, 1.45)
    _fish_cookie(b, 0.02, peak + 0.14, -0.05, 0.9, lean=18)
    _sb(b, (-0.45, peak - 0.22, -0.3), 0.15, "bowl_red")
    _pick(b, 0.8, top + 0.9, 0.3, 1.0, s=0.42)
    return [b.finalize("CatCafe_IconArt_XpFood_BigSnack", mat), _frame(mat, "CatCafe_IconArt_XpFood_BigSnack")]


def _feast(b, top, crown=False):
    """The feast heap: a whole fish across the back, a cupcake, two fish cookies and two shrimp in front."""
    _sb(b, (0, top + 0.05, 0.1), 1.15, "fur_vanilla", scale=(1.0, 0.35, 0.85), segments=26, rings=10)
    _fish(b, 0.05, top + 0.62, 0.45, 4, 2.5, "fur_silver", "fish_blue")
    _cupcake(b, -0.62, top + 0.15, -0.05, 1.0, frosting="pastel_lilac" if crown else "fur_strawberry")
    _fish_cookie(b, 0.6, top + 0.72, -0.12, 1.1, lean=-16, yaw=8)
    _shrimp(b, -0.05, top + 0.05, -0.72, 0.8, yaw=8)
    if crown:
        cy = top + 1.55
        b.cyl((0.05, cy, 0.2), 0.42, 0.22, "gold_mid", segments=16)
        for a in range(0, 360, 72):
            x, z = 0.36 * math.cos(math.radians(a + 90)), 0.36 * math.sin(math.radians(a + 90))
            b.cyl((0.05 + x, cy + 0.25, 0.2 + z), 0.09, 0.3, "gold_mid", r2=0.01, segments=8)
            _sb(b, (0.05 + x, cy + 0.42, 0.2 + z), 0.06, "rarity_mythic")


def cat_feast(mat):
    """Cat Feast: the feast heap on a big platter."""
    b = RB()
    top = _plate(b, 1.5)
    _feast(b, top)
    _pick(b, 0.9, top + 0.55, 0.35, 1.0, s=0.42)
    return [b.finalize("CatCafe_IconArt_XpFood_CatFeast", mat), _frame(mat, "CatCafe_IconArt_XpFood_CatFeast")]


def royal_feast(mat):
    """Royal Feast: the feast heap on a gold platter with a berry rim, a crown on top and a twinkle."""
    b = RB()
    top = _plate(b, 1.54, rim="royal_berry", body="gold_light", foot="gold_mid")
    _feast(b, top, crown=True)
    _pick(b, 0.95, top + 0.55, 0.35, 1.0, s=0.42, sw="mint")
    _twinkle(b, -1.15, top + 1.6, -0.4, 0.55)
    return [b.finalize("CatCafe_IconArt_XpFood_RoyalFeast", mat), _frame(mat, "CatCafe_IconArt_XpFood_RoyalFeast")]


FOODS = {"SmallSnack": small_snack, "CatSnack": cat_snack, "BigSnack": big_snack, "CatFeast": cat_feast,
         "RoyalFeast": royal_feast}
