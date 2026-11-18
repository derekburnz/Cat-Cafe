"""#5219 (Derek 2026-11-18: "update all cat food images"): one matching set of food pictures. Every food is heaped
high in the same cat bowl (cream with a coloured band, two ears on the back rim and a paw on the front), seen from
the same three-quarter view and framed the same size, so the eleven read as one family and the food, not the bowl,
fills the picture on a phone. icons.py renders each as CatCafe_Icon_FoodBowl_<Food>.

  kibble, tuna, sardines, salmon        the shop's everyday foods: no twinkle
  caviar, moon_milk, star_treat         the dear ones: one twinkle
  honey_cream, comet_treat              the Day Cart's two
  eclipse_treat                         the Secret tier bait, in a dark bowl
  royal_feast                           the 50,000 XP cat food, in a gold bowl with a crown

Built with RB in Roblox axes (x across, y up, the front toward -Z), the bowl's floor at y 0 and its rim at y 0.8.
Pictures only: nothing here is placed in the game.
"""

import math

from mathutils import Matrix

from common import RB
from icon_art import _crescent, _sb, _star_up, _twinkle
from plot import rot_z

RIM = 0.8          # the bowl's rim height
R_TOP = 1.3        # its radius at the rim


def _rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _bowl(b, band="bowl_red", body="cream", ears=True):
    """The cat bowl: a cream body flaring from 1.0 to 1.3 across, a coloured band and rim, two ears on the back rim
    and a paw print on the front. Its floor is y 0, its rim y RIM."""
    b.cyl((0, RIM / 2, 0), 1.0, RIM, body, r2=R_TOP, segments=28)
    b.cyl((0, RIM * 0.42, 0), 1.17, RIM * 0.34, band, r2=1.21, segments=28)                  # the band
    b.cyl((0, RIM - 0.04, 0), R_TOP + 0.06, 0.1, band, segments=28)                          # the rim
    if ears:
        for s in (-1, 1):
            x = s * 0.82
            b.fan_z(0.95, (x - 0.4, RIM - 0.02), [(x, RIM + 0.78), (x + 0.4, RIM - 0.02)], 0.18, band)
            b.fan_z(0.87, (x - 0.21, RIM + 0.06), [(x, RIM + 0.48), (x + 0.21, RIM + 0.06)], 0.1, "nose_pink")
    pz = -1.2                                                                                # the paw, on the band
    b.cyl((0, RIM * 0.4, pz), 0.17, 0.06, "offwhite", axis="Z", segments=14)
    for dx, dy in ((-0.2, 0.17), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.17)):
        b.cyl((dx, RIM * 0.4 + dy, pz + 0.02), 0.065, 0.06, "offwhite", axis="Z", segments=10)


def _frame(mat, name):
    """#5219: an object that only frames the camera (icons.py hides it), the same box for every food, so every bowl
    lands the same size and place in its picture."""
    f = RB()
    f.span((-1.42, -0.05, -1.42), (1.42, 2.5, 1.42), "cream")
    ob = f.finalize(name + "_Frame", mat)
    ob["fit_only"] = True
    return ob


def _mound(b, sw, h=0.42, r=1.2):
    """The food's bed, domed a little over the rim."""
    _sb(b, (0, RIM - 0.05, 0), r, sw, scale=(1.0, h / r, 1.0), segments=28, rings=12)


def _bits(b, pts, r, swatches, scale=(1.0, 0.8, 1.0)):
    for i, p in enumerate(pts):
        _sb(b, p, r, swatches[i % len(swatches)], scale=scale, segments=12, rings=6)


def _heap(n, r_out, y0, rise, seed):
    """n points in a dome: rings from the rim inward, rising toward the middle."""
    pts = []
    k = 0
    rings = ((1.0, 0.0), (0.66, 0.5), (0.3, 0.85), (0.0, 1.0))
    per = (max(1, n // 2), max(1, n // 3), max(1, n // 6), 1)
    for (f, up), m in zip(rings, per):
        for i in range(m):
            a = 2 * math.pi * (i + 0.37 * seed + 0.5 * (k % 2)) / m
            pts.append((r_out * f * math.cos(a), y0 + rise * up, r_out * f * math.sin(a)))
        k += 1
    return pts


def _fish(b, x, y, z, yaw, length, body, back, tilt=0.0):
    """A little whole fish lying on the heap, head toward +x before `yaw` (degrees about y) turns it."""
    ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def at(u, v, w):
        return (x + u * ca + w * sa, y + v, z - u * sa + w * ca)
    rot = rot_z(tilt) if tilt else None
    b.b.sphere(RB.p(*at(0, 0, 0)), length / 2, body, segments=16, rings=8,
               scale=(1.0, 0.42, 0.36), rot=RB._rot(Matrix.Rotation(math.radians(yaw), 3, "Y")))
    b.b.sphere(RB.p(*at(0.04, 0.08, 0)), length * 0.42, back, segments=16, rings=8,
               scale=(1.0, 0.3, 0.26), rot=RB._rot(Matrix.Rotation(math.radians(yaw), 3, "Y")))
    tail = at(-length / 2 - 0.02, 0, 0)
    for s in (-1, 1):
        b.box(at(-length / 2 - 0.16, 0.02, s * 0.13), (0.34, 0.08, 0.22), back,
              rot=Matrix.Rotation(math.radians(yaw), 3, "Y") @ _rot_x(s * 28))
    b.box(at(length * 0.33, 0.06, -length * 0.17), (0.12, 0.12, 0.06), "fur_black",
          rot=Matrix.Rotation(math.radians(yaw), 3, "Y"))
    del tail, rot


def kibble(mat):
    """A heap of kibble: round bits in two browns over a brown bed."""
    b = RB()
    _bowl(b)
    _mound(b, "kibble", h=0.62)
    _bits(b, _heap(30, 1.0, RIM + 0.24, 0.72, 1), 0.22, ("kibble", "fur_brown", "fur_caramel"))
    return [b.finalize("CatCafe_IconArt_FoodBowl_Kibble", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_Kibble")]


def tuna(mat):
    """Flaked pink tuna heaped up, a sprig of green on top."""
    b = RB()
    _bowl(b, band="fish_blue")
    _mound(b, "fur_peach", h=0.62)
    _bits(b, _heap(24, 0.95, RIM + 0.26, 0.7, 2), 0.26, ("fur_peach", "fur_apricot", "fur_rose"),
          scale=(1.2, 0.7, 0.9))
    for dx, deg in ((-0.08, 30), (0.08, -30), (0.0, 0)):
        b.box((dx, RIM + 1.12, -0.05), (0.09, 0.4, 0.09), "leaf_green", rot=rot_z(deg))
    return [b.finalize("CatCafe_IconArt_FoodBowl_Tuna", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_Tuna")]


def sardines(mat):
    """Three silver sardines lying across a little heap, heads out."""
    b = RB()
    _bowl(b, band="pastel_sky")
    _mound(b, "fish_belly", h=0.55)
    for (x, z, yaw, y) in ((-0.1, 0.4, 16, 0.18), (0.15, -0.05, -12, 0.42), (-0.05, -0.55, 6, 0.28)):
        _fish(b, x, RIM + 0.4 + y, z, yaw, 2.0, "fur_grey", "fish_blue")
    return [b.finalize("CatCafe_IconArt_FoodBowl_Sardines", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_Sardines")]


def salmon(mat):
    """Two thick salmon steaks leaning on each other, pale stripes across them."""
    b = RB()
    _bowl(b, band="leaf_green")
    _mound(b, "fur_vanilla", h=0.4)
    for (x, deg, z) in ((-0.36, 16, 0.12), (0.38, -14, -0.12)):
        rot = rot_z(deg) @ _rot_x(-8)
        b.b.cyl(RB.p(x, RIM + 0.75, z), 0.7, 0.46, "fur_apricot", segments=20, bevel=False,
                rot=RB._rot(rot @ Matrix.Rotation(math.radians(90), 3, "X")), radius2=None)
        for k in (-1, 0, 1):
            b.box((x + k * 0.28 * math.cos(math.radians(deg)), RIM + 0.75 + k * 0.28 * math.sin(math.radians(deg)),
                   z - 0.24), (0.07, 1.05, 0.04), "offwhite", rot=rot_z(deg + 60))
        b.cyl((x, RIM + 0.75, z - 0.24), 0.15, 0.04, "fur_rust_red", axis="Z", segments=10)
    return [b.finalize("CatCafe_IconArt_FoodBowl_Salmon", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_Salmon")]


def caviar(mat):
    """A dark heap of caviar beads with a shine on each, a small gold spoon in it."""
    b = RB()
    _bowl(b, band="pants_navy")
    _mound(b, "fur_ink", h=0.6)
    pts = _heap(44, 1.05, RIM + 0.2, 0.66, 3)
    _bits(b, pts, 0.14, ("fur_black", "fur_ink"), scale=(1, 1, 1))
    for (x, y, z) in pts[::2]:
        b.box((x - 0.04, y + 0.08, z - 0.1), (0.05, 0.05, 0.03), "offwhite")
    b.box((0.5, RIM + 1.15, 0.1), (0.12, 1.0, 0.07), "gold_mid", rot=rot_z(-30))
    _sb(b, (0.28, RIM + 0.78, 0.05), 0.2, "gold_light", scale=(1.0, 0.5, 1.3))
    _twinkle(b, -1.1, RIM + 1.25, -0.4, 0.55)
    return [b.finalize("CatCafe_IconArt_FoodBowl_Caviar", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_Caviar")]


def moon_milk(mat):
    """A bowl brimming with milk, a crescent moon rising out of it and two little stars."""
    b = RB()
    _bowl(b, band="velvet_lilac")
    b.cyl((0, RIM - 0.02, 0), R_TOP - 0.04, 0.08, "milk", segments=28)
    _sb(b, (0.1, RIM + 0.02, 0), 0.75, "milk", scale=(1.0, 0.12, 1.0))
    _crescent(b, 0.05, RIM + 1.0, -0.05, 0.85, 0.4, 0.24, "pastel_butter")
    _star_up(b, -0.8, RIM + 1.2, -0.1, 0.2, 0.09, 0.08, "sparkle")
    _star_up(b, 0.85, RIM + 0.6, -0.3, 0.15, 0.07, 0.08, "sparkle")
    _twinkle(b, -1.15, RIM + 0.55, -0.6, 0.5)
    return [b.finalize("CatCafe_IconArt_FoodBowl_MoonMilk", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_MoonMilk")]


def star_treat(mat):
    """Gold star cookies heaped up and standing every way."""
    b = RB()
    _bowl(b, band="rarity_legend")
    _mound(b, "pastel_butter", h=0.45)
    for (x, y, z, tilt, s, sw) in ((-0.55, 0.7, 0.2, 18, 0.58, "rarity_legend"), (0.55, 0.65, 0.15, -22, 0.56, "fur_golden"),
                                   (0.0, 1.05, -0.05, 4, 0.72, "rarity_legend"), (-0.35, 0.45, -0.6, -10, 0.46, "fur_golden"),
                                   (0.45, 0.42, -0.55, 14, 0.44, "rarity_legend")):
        _star_up(b, x, RIM + y, z, s, s * 0.45, 0.16, sw, rot=Matrix.Rotation(math.radians(tilt), 3, "Z"))
    _twinkle(b, 1.15, RIM + 1.3, -0.4, 0.55)
    return [b.finalize("CatCafe_IconArt_FoodBowl_StarTreat", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_StarTreat")]


def honey_cream(mat):
    """A tall swirl of whipped cream with honey running down it and a honey dipper leaning in."""
    b = RB()
    _bowl(b, band="eye_amber")
    _mound(b, "fur_vanilla", h=0.3)
    for i, (r, y) in enumerate(((1.0, 0.3), (0.82, 0.7), (0.6, 1.05), (0.36, 1.35))):
        _sb(b, (0, RIM + y, 0), r, "offwhite", scale=(1.0, 0.34, 1.0), segments=24, rings=10)
    _sb(b, (0, RIM + 1.55, 0), 0.16, "offwhite", scale=(1.0, 1.4, 1.0))
    for a in range(0, 360, 60):
        x, z = 0.6 * math.cos(math.radians(a)), 0.6 * math.sin(math.radians(a))
        _sb(b, (x, RIM + 0.72, z), 0.15, "eye_amber", scale=(1.0, 1.8, 1.0))
    _sb(b, (0, RIM + 1.38, 0), 0.36, "eye_amber", scale=(1.0, 0.3, 1.0))
    b.box((0.82, RIM + 1.15, 0.25), (0.12, 1.6, 0.12), "fur_caramel", rot=rot_z(-32))
    _sb(b, (0.45, RIM + 0.55, 0.25), 0.2, "fur_caramel", scale=(1.0, 1.4, 1.0))
    _twinkle(b, -1.15, RIM + 1.3, -0.4, 0.5)
    return [b.finalize("CatCafe_IconArt_FoodBowl_HoneyCream", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_HoneyCream")]


def _treat(b, body, icing, star, tails):
    """A round biscuit standing up in the bowl, facing the front, with three tails of light streaming up behind."""
    cx, cy = 0.0, RIM + 0.9
    ux, uy = math.cos(math.radians(55)), math.sin(math.radians(55))
    for (off, length, sw, w) in ((0.36, 0.95, tails[0], 0.22), (0.0, 1.25, tails[1], 0.3), (-0.36, 0.8, tails[2], 0.2)):
        b.box((cx - ux * length / 2 - uy * off, cy + uy * length / 2 - ux * off, 0.3), (length, w, 0.08), sw,
              rot=rot_z(-55))
    _sb(b, (cx, cy, 0), 0.85, body, scale=(1.0, 1.0, 0.5))
    _sb(b, (cx, cy, -0.26), 0.6, icing, scale=(1.0, 1.0, 0.4))
    _star_up(b, cx, cy, -0.5, 0.42, 0.19, 0.06, star)


def comet_treat(mat):
    """The Comet Treat standing in its bowl: a sky-blue biscuit with a white star, three tails streaming behind."""
    b = RB()
    _bowl(b, band="pastel_sky")
    _mound(b, "offwhite", h=0.3)
    _treat(b, "pastel_sky", "galaxy_blue", "offwhite", ("pastel_sky", "offwhite", "sparkle"))
    _twinkle(b, -1.15, RIM + 1.4, -0.4, 0.5)
    return [b.finalize("CatCafe_IconArt_FoodBowl_CometTreat", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_CometTreat")]


def eclipse_treat(mat):
    """The Eclipse Treat in a dark bowl: an indigo biscuit with near black icing and a gold star, purple tails."""
    b = RB()
    _bowl(b, band="aurora_violet", body="fur_ink")
    _mound(b, "fur_indigo", h=0.3)
    _treat(b, "fur_indigo", "fur_black", "rarity_legend", ("rarity_epic", "sparkle", "aurora_violet"))
    _twinkle(b, -1.15, RIM + 1.4, -0.4, 0.5, sw="rarity_epic")
    return [b.finalize("CatCafe_IconArt_FoodBowl_EclipseTreat", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_EclipseTreat")]


def royal_feast(mat):
    """The Royal Feast in a gold bowl: a fish, a salmon steak and star cookies heaped high, a little crown on top."""
    b = RB()
    _bowl(b, band="royal_berry", body="gold_light", ears=True)
    _mound(b, "fur_vanilla", h=0.4)
    _fish(b, -0.1, RIM + 0.45, 0.2, 12, 1.6, "fur_silver", "fish_blue")
    b.b.cyl(RB.p(0.5, RIM + 0.5, -0.2), 0.45, 0.32, "fur_apricot", segments=18, bevel=False,
            rot=RB._rot(rot_z(-20) @ Matrix.Rotation(math.radians(90), 3, "X")))
    _star_up(b, -0.6, RIM + 0.45, -0.45, 0.36, 0.16, 0.14, "rarity_legend", rot=Matrix.Rotation(math.radians(14), 3, "Z"))
    cy = RIM + 0.95                                                                        # the crown
    b.cyl((0, cy, 0), 0.42, 0.22, "gold_mid", segments=16)
    for a in range(0, 360, 72):
        x, z = 0.36 * math.cos(math.radians(a + 90)), 0.36 * math.sin(math.radians(a + 90))
        b.cyl((x, cy + 0.25, z), 0.09, 0.3, "gold_mid", r2=0.01, segments=8)
        _sb(b, (x, cy + 0.42, z), 0.06, "rarity_mythic")
    _twinkle(b, 1.15, RIM + 1.4, -0.4, 0.55)
    return [b.finalize("CatCafe_IconArt_FoodBowl_RoyalFeast", mat), _frame(mat, "CatCafe_IconArt_FoodBowl_RoyalFeast")]


FOODS = {"Kibble": kibble, "Tuna": tuna, "Sardines": sardines, "Salmon": salmon, "Caviar": caviar,
         "MoonMilk": moon_milk, "StarTreat": star_treat, "HoneyCream": honey_cream, "CometTreat": comet_treat,
         "EclipseTreat": eclipse_treat, "RoyalFeast": royal_feast}
