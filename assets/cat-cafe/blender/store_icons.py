"""Store pictures for the game passes and developer products (#1623, docs/growth/store-skus.md section 1), rendered
by icons.py as CatCafe_Icon_Pass_<Name> and CatCafe_Icon_Product_<Name> (transparent, outlined, 512 px). Roblox
crops pass and product icons to a circle, so icons.py frames these with a wide margin (STORE_PAD) that keeps every
subject inside the middle 80%. One picture serves the Creator Hub icon and the in-game Store card.

Passes
  Money2x, Money3x, Money4x  the gold coin stack (icon_art.coins) with a cream tag reading x2, x3 or x4
  LongNap         a ginger cat asleep on a plump blush cushion, a crescent moon and Zz above
  VIP             a gold plate reading VIP with a cream crest and a gold paw on top
  Accessories     a cream cat in a bow tie and a straw boater (the accessories' own pieces)
  Uniforms        a ginger barista cat in the apron and cap
  CafeStyle       a cosy cafe front: mint and cream striped awning, a round cat sign, a cake in the window
  GrandTheme      the grand cafe front: cream with gold trim, columns, a pediment with a gold crown, gold awning
  ExtraSlot       an empty cafe stool with a mint +1 tag
  RoyalCat        Duchess Marzipan (the Royal Cat) in her crown
  KingPack        King Croissant on his red velvet cushion throne (shopcats.py)
  GoldenPond      a little stone pond with lily pads and a golden fish leaping out
  SecondBaitBowl  two food bowls heaped with kibble, a +1 tag on the second
Products
  StarterBundle   the pink gift box with Sprinkles, a Big Money and a Swift Potion, and a striped little sign
  PotionXS        2 Big Money Potions
  PotionS         5 bottles in a wicker basket (3 Big Money, a Swift, a Steady Paw)
  PotionM         a wooden crate of 10 bottles
  PotionL         a big crate of bottles with a pink bow on it
  CafePass        a season badge: a gold rosette with a berry centre, a paw and a star, two ribbon tails

Built in Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math

import accessories
import cats
import hud_icons
import icon_art
import poses
import potion_icons
import shopcats
from common import GLYPHS, Builder
from icon_compose import place

X = (math.radians(90), "X")
INK = "fur_charcoal"
# block digits and signs for the tags (common.GLYPHS has the letters)
SIGNS = {
    "1": ("010", "110", "010", "010", "111"), "2": ("111", "001", "111", "100", "111"),
    "3": ("111", "001", "111", "001", "111"), "4": ("101", "101", "111", "001", "001"),
    "+": ("000", "010", "111", "010", "000"),
}


def _text(b, s, cx, y, zb, px, depth, sw):
    """Block letters standing in the XZ plane, centred on x = cx, bottom at zb, their front face at y."""
    gl = {**GLYPHS, **SIGNS}
    widths = [len(gl[ch][0]) for ch in s]
    cur = cx - (sum(widths) + len(s) - 1) * px / 2
    for ch, w in zip(s, widths):
        for row, bits in enumerate(gl[ch]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    c = (cur + (col + 0.5) * px, y + depth / 2, zb + (4 - row + 0.5) * px)
                    b.box(c, (px * 1.02, depth, px * 1.02), sw, bevel=False)
        cur += (w + 1) * px


def _tag(b, s, cx, cz, r, ink="royal_berry", disc="cream", y=-0.6):
    """A round tag facing the camera at (cx, y, cz), r across its radius, with `s` on it."""
    b.cyl((cx, y + 0.06, cz), r + 0.07, 0.1, "gold_mid", segments=24, rot=X)
    b.cyl((cx, y, cz), r, 0.1, disc, segments=24, rot=X)
    px = min(r * 1.25 / 5, r * 1.5 / ((sum(len({**GLYPHS, **SIGNS}[c][0]) for c in s) + len(s) - 1)))
    _text(b, s, cx, y - 0.08, cz - 2.5 * px, px, 0.06, ink)


def _star(b, x, y, z, s, sw="rarity_legend"):
    b.star((x, y, z), s, s * 0.45, 0.06, sw, rot=X)


def _twinkle(b, x, y, z, s, sw="offwhite"):
    """A four-pointed twinkle facing the camera."""
    pts = []
    for k in range(9):
        a = math.radians(90 + 45 * k)
        r = s / 2 if k % 2 == 0 else s * 0.12
        pts.append((r * math.cos(a), r * math.sin(a)))
    b.fan((x, y, z), (0, 0), pts, 0.05, sw, rot=X)


def _paw(b, x, y, z, s, sw):
    """A paw print facing the camera."""
    b.cyl((x, y, z - 0.05 * s), 0.26 * s, 0.05, sw, segments=14, rot=X)
    for (dx, dz) in ((-0.27, 0.2), (-0.1, 0.34), (0.1, 0.34), (0.27, 0.2)):
        b.cyl((x + dx * s, y, z + dz * s), 0.09 * s, 0.05, sw, segments=10, rot=X)


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_Store_" + name, mat)]


# --- cats ---------------------------------------------------------------------------------------------------------

ACCESSORY_BUILDS = {"BowTie": accessories.build_bow_tie, "Boater": accessories.build_boater,
                    "Apron": accessories.build_apron, "BaristaCap": accessories.build_barista_cap}


def _cat(name, mat, body="sit", dress=(), pose=None):
    """A roster cat, optionally in role pieces (accessories.slots) and a poses.CAT_POSES pose."""
    spec = cats.ROSTER[name]
    objs = cats.build_cat(name, mat, body=body)
    built = {f"CatCafe_Accessory_{n}": ACCESSORY_BUILDS[n](mat) for n in dress}
    pz = poses.CAT_POSES[pose] if pose else None
    worn = poses.accessory_copies(built, objs, spec, body, list(dress), pose=pz) if dress else []
    if pz:
        posed = poses.cat_pose_copies(objs, pz, spec, body)
        poses.cleanup(objs)
        objs = posed
    for src in built.values():
        poses.cleanup(src)
    return objs + worn


# --- passes -------------------------------------------------------------------------------------------------------

def money(mark):
    def build(mat):
        coins = place(icon_art.coins(mat), at=(-0.25, 0.3, 0.0))
        b = Builder()
        _tag(b, "X" + mark, 0.95, 0.35, 0.62, y=-1.0)
        return coins + _fin(b, "Money" + mark, mat)
    return build


def long_nap(mat):
    b = Builder()
    b.sphere((0, 0, 0.32), 1.0, "blush", segments=24, rings=12, scale=(1.35, 1.0, 0.34))       # the cushion
    b.cyl((0, 0, 0.64), 0.09, 0.04, "fur_bubblegum", segments=10)                             # its button
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.ico((sx * 1.25, sy * 0.88, 0.3), 0.12, "fur_bubblegum")                         # corner tufts
    _moon(b, (0.95, 0.0, 2.1), 0.42, 0.24, 0.08, "rarity_legend")
    _text(b, "Z", -0.55, -0.1, 1.75, 0.09, 0.06, "pastel_sky")
    _text(b, "Z", -0.2, -0.1, 2.1, 0.065, 0.06, "pastel_sky")
    cat = place(_cat("Ginger", mat, body="walk", pose="sleep"), at=(0.0, 0.05, 0.45), yaw=-90)
    return _fin(b, "LongNap", mat) + cat


def _moon(b, c, R, W, depth, sw, n=14):
    """A smooth crescent standing up and facing the camera, its horns toward -x."""
    a0, a1 = math.radians(-140), math.radians(140)
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        w = W * math.sin(math.pi * t) + 0.02
        outer.append((R * math.cos(a), R * math.sin(a)))
        inner.append(((R - w) * math.cos(a), (R - w) * math.sin(a)))
    for i in range(n):
        b.fan(c, outer[i], [inner[i], inner[i + 1], outer[i + 1]], depth, sw, rot=X)


def vip(mat):
    b = Builder()
    b.box((0, 0, 0.75), (2.9, 0.24, 1.5), "gold_mid")                                          # the plate
    b.box((0, -0.1, 0.75), (2.6, 0.08, 1.22), "gold_light", bevel=False)
    _text(b, "VIP", 0.0, -0.2, 0.75 - 2.5 * 0.2, 0.2, 0.08, "royal_berry")
    for sx in (-1, 1):                                                                        # screws
        b.cyl((sx * 1.2, -0.15, 0.75), 0.06, 0.05, "gold_dark", segments=8, rot=X)
    b.cyl((0, 0, 1.55), 0.5, 0.2, "cream", segments=24, rot=X)                                 # the crest
    b.cyl((0, 0.02, 1.55), 0.56, 0.18, "gold_mid", segments=24, rot=X)
    _paw(b, 0, -0.13, 1.55, 1.05, "gold_mid")
    for (x, z, s) in ((-1.45, 1.75, 0.2), (1.5, 1.85, 0.16)):
        _star(b, x, -0.1, z, s)
    return _fin(b, "VIP", mat)


def accessories_pass(mat):
    b = Builder()
    _twinkle(b, 0.75, -0.3, 1.6, 0.35)
    _twinkle(b, -0.7, -0.3, 1.2, 0.22)
    return place(_cat("Cream", mat, dress=("BowTie", "Boater")), yaw=-8) + _fin(b, "Accessories", mat)


def uniforms(mat):
    b = Builder()
    b.cyl((0.75, -0.35, 0.18), 0.17, 0.32, "cream", segments=14, radius2=0.21)                  # a coffee cup
    b.cyl((0.75, -0.35, 0.35), 0.19, 0.03, "choco", segments=14)
    b.ring((0.95, -0.35, 0.2), 0.08, 0.03, 0.04, "cream", segments=10, rot=X)
    _twinkle(b, -0.75, -0.3, 1.5, 0.3)
    return place(_cat("Ginger", mat, dress=("Apron", "BaristaCap")), yaw=-8) + _fin(b, "Uniforms", mat)


def _awning(b, x0, x1, z, depth, colours, n):
    """A striped awning sloping out from the wall over x0..x1 at height z, with a scalloped edge."""
    w = (x1 - x0) / n
    for i in range(n):
        x = x0 + w * (i + 0.5)
        sw = colours[i % 2]
        b.box((x, -depth / 2, z), (w, depth, 0.1), sw, rot=(math.radians(18), "X"))
        b.fan((x, -depth - 0.01, z - depth * math.sin(math.radians(18)) - 0.03), (0, 0),
              [(w / 2 * math.cos(a), w / 2 * math.sin(a)) for a in (math.radians(-15 * k) for k in range(13))],
              0.05, sw, rot=X)


def cafe_style(mat):
    b = Builder()
    W, H = 2.6, 2.2
    b.box((0, 0.2, H / 2), (W, 0.4, H), "cream")                                               # the wall
    b.box((0, 0.2, H + 0.08), (W + 0.12, 0.5, 0.16), "fur_strawberry")                        # cornice
    b.box((0.55, -0.02, 0.85), (1.1, 0.06, 0.9), "pastel_sky")                                 # window
    b.box((0.55, -0.04, 0.85), (1.18, 0.04, 0.08), "offwhite", bevel=False)
    b.cyl((0.55, -0.12, 0.52), 0.26, 0.06, "offwhite", segments=14)                           # a cake on a stand
    b.cyl((0.55, -0.12, 0.66), 0.2, 0.22, "fur_bubblegum", segments=14)
    b.ico((0.55, -0.12, 0.83), 0.06, "shirt_red")
    b.box((-0.7, -0.02, 0.62), (0.62, 0.06, 1.24), "caramel_wood")                             # door
    b.cyl((-0.48, -0.08, 0.62), 0.05, 0.04, "gold_mid", segments=8, rot=X)
    b.box((-0.7, -0.06, 0.95), (0.36, 0.03, 0.34), "pastel_sky", bevel=False)
    b.box((0, -0.05, 0.03), (W + 0.1, 0.12, 0.06), "mint")                                    # step trim
    _awning(b, -W / 2 - 0.05, W / 2 + 0.05, 1.55, 0.7, ("mint", "cream"), 6)
    b.cyl((0, 0.02, 2.55), 0.5, 0.12, "fur_strawberry", segments=24, rot=X)                    # the round sign
    b.cyl((0, -0.05, 2.55), 0.42, 0.06, "cream", segments=24, rot=X)
    hud = place(hud_icons.cat_face(mat), at=(0, -0.12, 2.27), scale=0.32)                     # a cat face on it
    return _fin(b, "CafeStyle", mat) + hud


def grand_theme(mat):
    b = Builder()
    W, H = 3.2, 2.3
    b.box((0, 0.2, H / 2), (W, 0.4, H), "cream")                                               # the wall
    b.box((0, -0.05, 0.06), (W + 0.3, 0.6, 0.12), "gold_mid")                                  # plinth and steps
    b.box((0, -0.2, 0.15), (1.4, 0.5, 0.06), "cream")
    for x in (-1.35, -0.75, 0.75, 1.35):                                                       # columns
        b.cyl_base((x, -0.15, 0.12), 0.13, H - 0.25, "offwhite", segments=12)
        b.box((x, -0.15, 0.17), (0.34, 0.34, 0.1), "gold_mid")
        b.box((x, -0.15, H - 0.08), (0.36, 0.36, 0.12), "gold_mid")
    b.box((0, -0.05, H + 0.05), (W + 0.3, 0.6, 0.18), "gold_mid")                              # entablature
    b.prism((0, 0.0, H + 0.14), [(-W / 2 - 0.1, 0), (W / 2 + 0.1, 0), (0, 0.85)], 0.5, "cream", rot=X)   # pediment
    b.prism((0, -0.02, H + 0.2), [(-W / 2 + 0.15, 0), (W / 2 - 0.15, 0), (0, 0.64)], 0.5, "gold_light", rot=X)
    crown = H + 0.45                                                                           # a gold crown in it
    b.box((0, -0.3, crown), (0.6, 0.1, 0.16), "rarity_legend", bevel=False)
    for dx in (-0.25, 0.0, 0.25):
        b.pyramid((dx, -0.3, crown + 0.08), 0.16, 0.2 if dx else 0.26, "rarity_legend")
    b.box((0, 0.0, 0.9), (1.0, 0.06, 1.55), "royal_berry")                                     # double doors
    b.box((0, -0.04, 0.9), (0.04, 0.04, 1.5), "gold_mid", bevel=False)
    for sx in (-1, 1):
        b.cyl((sx * 0.1, -0.06, 0.85), 0.04, 0.04, "gold_mid", segments=8, rot=X)
        b.box((sx * 1.05, -0.02, 1.25), (0.42, 0.06, 0.9), "pastel_sky")                       # windows
        b.box((sx * 1.05, -0.04, 1.25), (0.46, 0.04, 0.06), "gold_mid", bevel=False)
    _awning(b, -0.6, 0.6, 1.85, 0.45, ("rarity_legend", "cream"), 4)
    for (x, z, s) in ((-1.75, 2.9, 0.2), (1.8, 2.75, 0.16)):
        _star(b, x, -0.2, z, s)
    return _fin(b, "GrandTheme", mat)


def extra_slot(mat):
    b = Builder()
    b.cyl((0, 0, 1.15), 0.62, 0.22, "blush", segments=24)                                      # seat cushion
    b.cyl((0, 0, 1.0), 0.6, 0.1, "caramel_wood", segments=24)
    for k in range(4):                                                                         # legs
        a = math.radians(45 + 90 * k)
        b.cyl((0.42 * math.cos(a), 0.42 * math.sin(a), 0.5), 0.06, 1.0, "caramel_wood", segments=8)
    b.ring((0, 0, 0.4), 0.48, 0.05, 0.06, "dark_wood", segments=20)                           # foot ring
    _tag(b, "+1", 0.85, 1.65, 0.48, ink="leaf_dark", disc="mint", y=-0.7)
    return _fin(b, "ExtraSlot", mat)


def royal_cat(mat):
    b = Builder()
    _twinkle(b, 0.8, -0.3, 1.7, 0.35)
    _twinkle(b, -0.75, -0.3, 1.3, 0.24)
    return place(_cat("DuchessMarzipan", mat), yaw=-8) + _fin(b, "RoyalCat", mat)


def king_pack(mat):
    b = Builder()
    _twinkle(b, 1.3, -1.4, 2.9, 0.45)
    _twinkle(b, -1.3, -1.4, 2.3, 0.3)
    cushion = place(shopcats.build_king_cushion(mat))
    cat = place(_cat("KingCroissant", mat), at=(0, 0, shopcats.SEAT_Y), yaw=-8)
    return cushion + cat + _fin(b, "KingPack", mat)


def golden_pond(mat):
    b = Builder()
    b.cyl((0, 0, 0.1), 1.25, 0.12, "pastel_sky", segments=28, scale=(1, 0.75, 1))              # the water
    for k in range(18):                                                                        # stones round it
        a = 2 * math.pi * k / 18
        b.ico((1.32 * math.cos(a), 1.0 * math.sin(a), 0.14), 0.2 + 0.04 * (k % 3), ("concrete", "concrete_dark")[k % 2],
              scale=(1.0, 1.0, 0.7))
    for (x, y, r) in ((-0.55, 0.2, 0.28), (0.5, 0.35, 0.22)):                                  # lily pads
        b.cyl((x, y, 0.18), r, 0.03, "leaf_green", segments=14)
    b.ico((-0.5, 0.18, 0.24), 0.08, "blush")                                                   # a flower
    for (x, z, s) in ((-0.35, 0.45, 0.07), (0.2, 0.5, 0.06), (-0.15, 0.7, 0.05)):            # splash drops
        b.ico((x, -0.3, z), s, "pastel_sky")
    fish = place(icon_art.golden_fish(mat), at=(0.1, -0.2, 1.2), scale=0.62, roll=-30)          # leaping, nose up
    _twinkle(b, -1.0, -0.4, 1.9, 0.4)
    return _fin(b, "GoldenPond", mat) + fish


def second_bait_bowl(mat):
    back = place(hud_icons.bait(mat), at=(-0.55, 0.45, 0.0), scale=1.6)
    front = place(hud_icons.bait(mat), at=(0.5, -0.35, 0.0), scale=1.6)
    b = Builder()
    _tag(b, "+1", 1.25, 0.95, 0.36, ink="leaf_dark", disc="mint", y=-0.9)
    return back + front + _fin(b, "SecondBaitBowl", mat)


# --- products -----------------------------------------------------------------------------------------------------

def _flask(name, mat, at, scale, yaw=0.0):
    return place(potion_icons.flask(name, mat), at=at, scale=scale, yaw=yaw)


def starter_bundle(mat):
    box = place(hud_icons.gift(mat), at=(0.1, 0.5, 0.0), scale=0.9)
    cat = place(_cat("Sprinkles", mat), at=(-0.95, -0.35, 0.0), scale=0.85, yaw=10)
    pots = _flask("BigTip", mat, (0.85, -0.55, 0.0), 0.36) + _flask("Swift", mat, (1.3, -0.25, 0.0), 0.36)
    b = Builder()
    b.cyl_base((-1.45, 0.55, 0.0), 0.04, 1.0, "caramel_wood", segments=6)                      # a little sign
    for i in range(4):
        b.box((-1.45 - 0.27 + 0.18 * i, 0.5, 1.15), (0.18, 0.06, 0.5), ("fur_bubblegum", "cream")[i % 2], bevel=False)
    b.box((-1.45, 0.47, 1.15), (0.6, 0.02, 0.06), "fur_strawberry", bevel=False)
    return box + cat + pots + _fin(b, "StarterBundle", mat)


def potion_xs(mat):
    return _flask("BigTip", mat, (-0.5, 0.3, 0.0), 0.9, yaw=8) + _flask("BigTip", mat, (0.55, -0.3, 0.0), 0.9, yaw=-8)


def _basket(b, w, d, h, sw="caramel_wood", band="dark_wood"):
    """A wicker basket w x d x h: a floor, woven walls (alternating bands) and a handle over the top."""
    b.box((0, 0, 0.05), (w, d, 0.1), sw)
    for k in range(4):
        z = 0.1 + (h - 0.1) * (k + 0.5) / 4
        b.box((0, 0, z), (w, d, (h - 0.1) / 4 * 0.92), (sw, band)[k % 2], bevel=False)


def potion_s(mat):
    b = Builder()
    _basket(b, 2.4, 1.3, 0.7)
    b.ring((0, 0.0, 0.7), 1.15, 0.08, 0.1, "caramel_wood", segments=20, rot=X)                   # handle
    out = _fin(b, "PotionS", mat)
    for (n, x, y) in (("BigTip", -0.7, 0.2), ("BigTip", 0.0, 0.25), ("BigTip", 0.7, 0.2), ("Swift", -0.35, -0.25),
                      ("Steady", 0.4, -0.25)):
        out += _flask(n, mat, (x, y, 0.3), 0.42)
    return out


def _crate(b, w, d, h):
    """An open wooden crate: slatted sides, dark corner posts."""
    b.box((0, 0, 0.06), (w, d, 0.12), "caramel_wood")
    for k in range(3):
        z = 0.12 + (h - 0.12) * (k + 0.5) / 3
        hh = (h - 0.12) / 3 * 0.8
        b.box((0, -d / 2, z), (w, 0.08, hh), "caramel_wood", bevel=False)
        b.box((0, d / 2, z), (w, 0.08, hh), "caramel_wood", bevel=False)
        b.box((-w / 2, 0, z), (0.08, d, hh), "caramel_wood", bevel=False)
        b.box((w / 2, 0, z), (0.08, d, hh), "caramel_wood", bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * w / 2, sy * d / 2, h / 2), (0.14, 0.14, h), "dark_wood", bevel=False)


def potion_m(mat):
    b = Builder()
    _crate(b, 2.6, 1.4, 0.75)
    out = _fin(b, "PotionM", mat)
    rows = (("BigTip", "BigTip", "Swift", "Swift", "Steady"), ("BigTip", "BigTip", "BigTip", "Swift", "Steady"))
    for r, row in enumerate(rows):
        for i, n in enumerate(row):
            out += _flask(n, mat, (-1.0 + 0.5 * i, 0.3 - 0.6 * r, 0.2 + 0.08 * (1 - r)), 0.36)
    return out


def potion_l(mat):
    b = Builder()
    _crate(b, 3.2, 1.9, 0.85)
    b.box((0, -0.97, 0.45), (3.22, 0.04, 0.22), "fur_bubblegum", bevel=False)                  # the ribbon round it
    for sx in (-1, 1):                                                                         # the bow on its front
        b.ico((sx * 0.3, -1.05, 0.62), 0.26, "fur_bubblegum", scale=(1.3, 0.5, 0.8))
        b.box((sx * 0.22, -1.03, 0.25), (0.12, 0.04, 0.4), "fur_bubblegum", rot=(math.radians(sx * 20), "Y"))
    b.ico((0, -1.08, 0.6), 0.13, "blush")
    out = _fin(b, "PotionL", mat)
    names = ("BigTip", "Swift", "Steady")
    for r in range(3):
        for i in range(6):
            n = names[(i + r) % 3]
            out += _flask(n, mat, (-1.25 + 0.5 * i, 0.55 - 0.5 * r, 0.2 + 0.07 * (2 - r)), 0.34)
    out += _flask("BigTip", mat, (-0.4, -0.2, 1.05), 0.34, yaw=-20)                              # the two bonus ones
    out += _flask("Steady", mat, (0.45, -0.2, 1.05), 0.34, yaw=15)
    return out


def cafe_pass(mat):
    b = Builder()
    for sx in (-1, 1):                                                                         # ribbon tails
        b.box((sx * 0.35, 0.1, -0.55), (0.42, 0.06, 1.3), "royal_berry", rot=(math.radians(sx * -14), "Y"))
        b.prism((sx * 0.5, 0.06, -1.2), [(-0.22, 0.0), (0.22, 0.0), (0.0, 0.22)], 0.07, "cream", rot=X)
    n = 16                                                                                     # the scalloped rosette
    for k in range(n):
        a = 2 * math.pi * k / n
        b.cyl((1.0 * math.cos(a), 0.04, 0.5 + 1.0 * math.sin(a)), 0.26, 0.12, "gold_mid", segments=12, rot=X)
    b.cyl((0, 0.0, 0.5), 1.0, 0.16, "gold_mid", segments=32, rot=X)
    b.cyl((0, -0.06, 0.5), 0.82, 0.1, "royal_berry", segments=32, rot=X)
    b.cyl((0, -0.1, 0.5), 0.62, 0.06, "cream", segments=32, rot=X)
    _paw(b, 0, -0.14, 0.42, 1.25, "royal_berry")
    _star(b, 0, -0.14, 0.95, 0.16)
    _twinkle(b, 1.1, -0.3, 1.55, 0.4)
    return _fin(b, "CafePass", mat)


PASSES = {"Money2x": money("2"), "Money3x": money("3"), "Money4x": money("4"), "LongNap": long_nap, "VIP": vip,
          "Accessories": accessories_pass, "Uniforms": uniforms, "CafeStyle": cafe_style, "GrandTheme": grand_theme,
          "ExtraSlot": extra_slot, "RoyalCat": royal_cat, "KingPack": king_pack, "GoldenPond": golden_pond,
          "SecondBaitBowl": second_bait_bowl}
PRODUCTS = {"StarterBundle": starter_bundle, "PotionXS": potion_xs, "PotionS": potion_s, "PotionM": potion_m,
            "PotionL": potion_l, "CafePass": cafe_pass}
# name -> (yaw, pitch) for icons.py
VIEWS = {"Money2x": (-16.0, 30.0), "Money3x": (-16.0, 30.0), "Money4x": (-16.0, 30.0), "LongNap": (-20.0, 26.0),
         "VIP": (-10.0, 8.0), "Accessories": (-24.0, 8.0), "Uniforms": (-24.0, 8.0), "CafeStyle": (-24.0, 12.0),
         "GrandTheme": (-20.0, 10.0), "ExtraSlot": (-20.0, 18.0), "RoyalCat": (-24.0, 8.0), "KingPack": (-24.0, 12.0),
         "GoldenPond": (-14.0, 30.0), "SecondBaitBowl": (-20.0, 28.0), "StarterBundle": (-20.0, 16.0),
         "PotionXS": (-12.0, 8.0), "PotionS": (-14.0, 22.0), "PotionM": (-16.0, 26.0), "PotionL": (-16.0, 24.0),
         "CafePass": (0.0, 0.0)}
# a wider margin for the square shop fronts, whose corners would reach the circle crop at STORE_PAD
PADS = {"CafeStyle": 0.42, "GrandTheme": 0.42}
