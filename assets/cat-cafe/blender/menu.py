"""Cats make the orders (F90, docs/design/cat-cafe/cats-make-orders.md): the twelve menu items, each chunky food on
its plate, the rich customer's gold-rimmed plate, the Waiter's head tray, the coin bag for the tip sweep and the
oven behind the counter. Bright flat colours that read across the cafe; each item's icon is a render of it.

  CatCafe_Menu_<Id>       the food, with its plate as the child Model `<name>_Plate`. Pivot at the plate's base
                          centre, front -Z, no collision. The plate is PLATE_R across the rim band and its top is
                          PLATE_TOP up; the food stays inside the plate and under ITEM_H tall, so an item stands on
                          the round table's top beside a tip pile.
                            Tier 1: Coffee, Milk, CakeSlice, PawCookie   Tier 2: Tea, FishBiscuit
                            Tier 3: KittyCupcake, HotCocoa               Tier 4: PancakeStack, Sundae
                            Tier 5: StrawberryRoll, RainbowCake
  CatCafe_Menu_GoldPlate  the rich customer's plate: the same size and pivot as `_Plate` with a gold rim, so the
                          code hides an item's `_Plate` and pivots this to the item's pivot.
  CatCafe_Menu_Tray       a round silver tray with a raised lip, pivot at its underside centre (it rides a cat's
                          head, on the Carry Attachment), and an Attachment `Item` at its top centre (TRAY_TOP up):
                          an item's pivot goes on it.
  CatCafe_Menu_CoinBag    a little burlap sack tied with a red cord, a gold paw on the front and coins peeking out of
                          the top. Pivot at its base centre; it rides the head the same way as the tray.
  CatCafe_Cafe_Oven       a mint enamel oven with cat ears on its top, a dial and knobs, a warm window in the door
                          and a flue pipe, so it reads over the counter. Pivot at its base centre, front -Z; it
                          collides like furniture. `_Door` is a child Model pivoted on its bottom hinge (it would
                          swing open about X), and an Attachment `DoorGlow` sits at the window's centre on its face.
"""

import math

from mathutils import Matrix, Vector

from cannon import frame_at
from common import RB, Builder

PLATE_R, PLATE_TOP, ITEM_H = 0.58, 0.12, 1.1
TRAY_R, TRAY_TOP = 0.7, 0.15
ITEMS = ("Coffee", "Milk", "CakeSlice", "PawCookie", "Tea", "FishBiscuit", "KittyCupcake", "HotCocoa", "PancakeStack",
         "Sundae", "StrawberryRoll", "RainbowCake")
OVEN = "CatCafe_Cafe_Oven"
OVEN_W, OVEN_D, OVEN_H = 3.0, 2.4, 3.5          # the body; ears and flue rise over it
ATTACHMENTS = {}                                  # asset -> [(name, Roblox point)]
PT = PLATE_TOP
NO = dict(bevel=False)


def _rx(deg):
    return (math.radians(deg), "X")


def _rz(deg):
    return (math.radians(deg), "Z")


def _plate(rim="mint", foot="offwhite"):
    """The plate: a foot, the plate and a coloured band round its edge. Blender axes, front -Y, base at z 0."""
    p = Builder()
    p.cyl_base((0, 0, 0), 0.38, 0.04, foot, segments=12, **NO)
    p.cyl_base((0, 0, 0.04), 0.55, PT - 0.04, "offwhite", segments=14, **NO)
    p.cyl_base((0, 0, 0.06), PLATE_R, 0.035, rim, segments=14, **NO)
    return p


def _item(name, food, mat):
    n = "CatCafe_Menu_" + name
    return [food.finalize(n, mat), _plate().finalize(n + "_Plate", mat)]


def _paw(b, x, y, z, s, swatch, h=0.03):
    """A paw print lying flat on a top at height z: a pad and four toe beans toward the back (+Y)."""
    b.cyl_base((x, y - 0.02 * s, z), 0.11 * s, h, swatch, segments=10, **NO)
    for (dx, dy) in ((-0.13, 0.08), (-0.05, 0.15), (0.05, 0.15), (0.13, 0.08)):
        b.cyl_base((x + dx * s, y + dy * s, z), 0.045 * s, h, swatch, segments=8, **NO)


def _handle(b, x, z, r, swatch):
    """A mug handle: a loop standing in the XZ plane on the side at x, so it shows from the front."""
    b.ring((x, 0, z), r, 0.045, 0.06, swatch, segments=8, rot=_rx(90), **NO)


def _mug(b, body, inside, r=0.25, h=0.36):
    """A round mug on the plate: a floor, a wall and the drink 0.04 under the rim."""
    b.cyl_base((0, 0, PT), r, 0.03, body, segments=12, **NO)
    b.ring((0, 0, PT + h / 2), r, 0.06, h, body, segments=12, **NO)
    b.cyl_base((0, 0, PT + 0.03), r - 0.05, h - 0.07, inside, segments=12, **NO)
    _handle(b, r + 0.07, PT + h * 0.55, 0.11, body)
    return PT + h - 0.04                      # the drink's top


def build_coffee(mat):
    """A round blush mug of latte with a heart in the foam."""
    b = Builder()
    top = _mug(b, "blush", "kibble")
    for dx in (-0.06, 0.06):                  # the heart: two lobes and a point toward the front
        b.cyl_base((dx, 0.04, top - 0.01), 0.075, 0.04, "offwhite", segments=8, **NO)
    b.box((0, -0.02, top + 0.01), (0.125, 0.125, 0.04), "offwhite", rot=_rz(45), **NO)
    return _item("Coffee", b, mat)


def build_milk(mat):
    """A tall glass of milk with a red and white striped straw."""
    b = Builder()
    b.cyl_base((0, 0, PT), 0.18, 0.04, "glass", segments=12, **NO)
    b.ring((0, 0, PT + 0.29), 0.18, 0.04, 0.5, "glass", segments=12, **NO)
    b.cyl_base((0, 0, PT + 0.04), 0.14, 0.42, "milk", segments=12, **NO)
    tilt = Matrix.Rotation(math.radians(-14), 3, "Y")
    d = tilt @ Vector((0, 0, 1))
    base = Vector((0.03, 0.02, PT + 0.3))
    for k in range(5):                        # stripes up the straw, red at both ends
        c = base + d * (0.08 + 0.12 * k)
        b.box(tuple(c), (0.06, 0.06, 0.12), "shirt_red" if k % 2 == 0 else "offwhite", rot=tilt, **NO)
    tip = base + d * 0.6
    b.box((tip.x - 0.07, tip.y, tip.z - 0.02), (0.18, 0.06, 0.06), "shirt_red", **NO)   # the bend
    return _item("Milk", b, mat)


def _layers(b, z, layers, front=0.42, back=0.3, half=0.32):
    """A cake slice in layers from height z: seen from above a triangle with its point toward the front (-Y) and
    its back across +Y, each layer two wedges (left and right halves) so it stays two WedgeParts in Roblox."""
    d, c = front + back, (back - front) / 2
    for (h, swatch) in layers:
        for sx in (-1, 1):
            b.wedge((sx * half / 2, c, z + h / 2), (h, d, half), swatch, bevel=False, rot=(math.radians(sx * 90), "Y"))
        z += h
    return z


def build_cake_slice(mat):
    """A pink-iced sponge slice with a cream layer, a dollop and a cherry."""
    b = Builder()
    top = _layers(b, PT, ((0.15, "fur_vanilla"), (0.06, "offwhite"), (0.15, "fur_vanilla"), (0.08, "fur_rose")))
    b.ico((0, 0.12, top + 0.05), 0.1, "offwhite", subdivisions=1)
    b.ico((0, 0.12, top + 0.18), 0.085, "shirt_red", subdivisions=1)
    b.box((0.03, 0.12, top + 0.3), (0.025, 0.025, 0.12), "leaf_dark", rot=(math.radians(-20), "Y"), **NO)
    return _item("CakeSlice", b, mat)


def build_paw_cookie(mat):
    """Two round cookies, the top one with a chocolate paw print and a few chips."""
    b = Builder()
    b.cyl_base((0.08, 0.1, PT), 0.34, 0.1, "fur_caramel", segments=12, **NO)
    b.cyl_base((-0.03, -0.04, PT + 0.1), 0.4, 0.11, "treat_tan", segments=14, **NO)
    top = PT + 0.21
    _paw(b, -0.03, -0.06, top - 0.01, 1.15, "choco", 0.04)
    for (x, y) in ((-0.3, -0.18), (0.24, -0.22), (0.25, 0.14), (-0.27, 0.15)):
        b.box((x, y, top + 0.01), (0.06, 0.06, 0.04), "choco", rot=_rz(30), **NO)
    return _item("PawCookie", b, mat)


def build_tea(mat):
    """A teacup on a sky blue saucer, the tea bag's string over the rim and its tag hanging at the front."""
    b = Builder()
    b.cyl_base((0, 0, PT), 0.36, 0.04, "pastel_sky", segments=14, **NO)
    s0 = PT + 0.04
    b.cyl_base((0, 0, s0), 0.15, 0.24, "offwhite", segments=12, radius2=0.24, **NO)
    b.ring((0, 0, s0 + 0.265), 0.25, 0.05, 0.05, "offwhite", segments=12, **NO)
    b.cyl_base((0, 0, s0 + 0.2), 0.21, 0.07, "fur_caramel", segments=12, **NO)
    _handle(b, 0.29, s0 + 0.15, 0.09, "offwhite")
    b.box((-0.08, -0.215, s0 + 0.17), (0.015, 0.015, 0.22), "fur_white", rot=(math.radians(-10), "X"), **NO)
    b.box((-0.08, -0.26, s0 + 0.03), (0.12, 0.02, 0.11), "pastel_butter", **NO)      # the tag
    b.box((-0.08, -0.275, s0 + 0.03), (0.05, 0.02, 0.05), "shirt_red", **NO)
    return _item("Tea", b, mat)


def _ear(b, x, y, z, w, h, swatch, lean=0.0, turn=0.0, t=0.05):
    """A flat triangle standing up from (x, y, z), facing the front: a cat ear or a wafer (two WedgeParts' worth)."""
    rot = (Matrix.Rotation(math.radians(turn), 3, "Z") @ Matrix.Rotation(math.radians(lean), 3, "Y")
           @ Matrix.Rotation(math.radians(90), 3, "X"))
    b.prism((x, y, z), [(-w / 2, 0.0), (w / 2, 0.0), (0.0, h)], t, swatch, rot=rot)


def _fish(b, x, y, z, s, swatch, h=0.12):
    """A flat fish biscuit lying on a top at z, head toward +X: an oval body, a fanned tail, an eye and two scale
    smiles across its back."""
    b.sphere((x, y, z + h / 2), 0.3 * s, swatch, segments=12, rings=5, scale=(1, 0.6, h / (0.6 * s)))
    tx = x - 0.24 * s
    b.prism((tx, y, z + h * 0.4), [(0.0, 0.0), (-0.24 * s, 0.17 * s), (-0.2 * s, 0.0), (-0.24 * s, -0.17 * s)],
            h * 0.6, swatch)
    b.cyl_base((x + 0.17 * s, y - 0.02 * s, z + h * 0.7), 0.04 * s, h * 0.4, "choco", segments=6, **NO)
    for k in range(2):
        b.box((x + (0.04 - 0.11 * k) * s, y, z + h * 0.82), (0.035 * s, 0.24 * s, h * 0.3), "fur_caramel", **NO)


def build_fish_biscuit(mat):
    """Two fish biscuits side by side, a big golden one behind and a smaller toasted one in front."""
    b = Builder()
    _fish(b, 0.06, 0.17, PT, 1.15, "fur_golden", 0.13)
    _fish(b, 0.06, -0.21, PT, 0.95, "treat_tan", 0.11)
    return _item("FishBiscuit", b, mat)


def build_kitty_cupcake(mat):
    """A cupcake in a sky blue case, pink icing in three tiers with two icing ears, a little face and sprinkles."""
    b = Builder()
    b.cyl_base((0, 0, PT), 0.19, 0.26, "pastel_sky", segments=12, radius2=0.25, **NO)
    z = PT + 0.26
    for (r, h) in ((0.27, 0.11), (0.21, 0.1), (0.12, 0.08)):
        b.cyl_base((0, 0, z), r, h, "fur_rose", segments=12, **NO)
        z += h
    for sx in (1, -1):
        _ear(b, sx * 0.13, 0.02, PT + 0.45, 0.15, 0.17, "fur_rose", lean=-sx * 10)
        b.box((sx * 0.08, -0.2, PT + 0.42), (0.04, 0.03, 0.05), "choco", **NO)        # eyes
    b.box((0, -0.205, PT + 0.39), (0.035, 0.03, 0.03), "nose_pink", **NO)
    for (x, y, c) in ((0.2, -0.1, "mint"), (-0.19, -0.12, "shirt_blue"), (0.12, 0.17, "pastel_butter"),
                      (-0.15, 0.15, "mint"), (0.0, 0.23, "shirt_blue")):
        b.box((x, y, PT + 0.375), (0.05, 0.03, 0.03), c, rot=_rz(x * 200), **NO)
    return _item("KittyCupcake", b, mat)


def build_hot_cocoa(mat):
    """A mint mug of cocoa with a marshmallow cat floating in it."""
    b = Builder()
    top = _mug(b, "mint", "choco")
    rz = Matrix.Rotation(math.radians(15), 3, "Z")
    b.box((0, 0, top + 0.02), (0.2, 0.17, 0.08), "offwhite", rot=rz, **NO)
    for sx in (1, -1):
        e = rz @ Vector((sx * 0.065, 0.05, 0))
        _ear(b, e.x, e.y, top + 0.055, 0.08, 0.08, "offwhite", turn=15, t=0.04)
        f = rz @ Vector((sx * 0.045, -0.03, 0))
        b.box((f.x, f.y, top + 0.065), (0.025, 0.025, 0.02), "choco", rot=rz, **NO)
    return _item("HotCocoa", b, mat)


def build_pancake_stack(mat):
    """Three pancakes, syrup running down, and a pat of butter."""
    b = Builder()
    z = PT
    for (dx, dy) in ((0.0, 0.0), (0.03, -0.02), (-0.02, 0.02)):
        b.cyl_base((dx, dy, z), 0.4, 0.1, "treat_tan", segments=14, **NO)
        z += 0.1
    b.cyl_base((-0.02, 0.02, z - 0.01), 0.3, 0.04, "fur_caramel", segments=12, **NO)
    for a in (-100, -60, 20):                 # drips down the front and side
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        b.box((0.4 * c, 0.4 * s, z - 0.09), (0.07, 0.07, 0.17), "fur_caramel", rot=_rz(a), **NO)
        b.box((0.32 * c, 0.32 * s, z + 0.005), (0.18, 0.07, 0.04), "fur_caramel", rot=_rz(a), **NO)
    b.box((0.02, 0.0, z + 0.06), (0.18, 0.18, 0.08), "pastel_butter", rot=_rz(20), **NO)
    return _item("PancakeStack", b, mat)


def build_sundae(mat):
    """A glass dish on a stem with strawberry, vanilla and chocolate scoops, cream, a cherry and two wafer ears."""
    b = Builder()
    b.cyl_base((0, 0, PT), 0.19, 0.04, "glass", segments=12, **NO)
    b.cyl_base((0, 0, PT + 0.04), 0.05, 0.16, "glass", segments=8, **NO)
    b.cyl_base((0, 0, PT + 0.2), 0.1, 0.2, "glass", segments=12, radius2=0.3, **NO)
    for (x, y, z, c) in ((-0.12, 0.03, 0.47, "fur_rose"), (0.12, 0.03, 0.47, "fur_vanilla"), (0.0, -0.02, 0.62, "choco")):
        b.ico((x, y, PT + z), 0.17, c, subdivisions=1)
    b.ico((0, -0.02, PT + 0.77), 0.11, "offwhite", subdivisions=1)
    b.ico((0, -0.02, PT + 0.9), 0.065, "shirt_red", subdivisions=1)
    for sx in (1, -1):                        # wafer ears tucked in behind the top scoop
        _ear(b, sx * 0.15, 0.08, PT + 0.62, 0.18, 0.25, "treat_tan", lean=-sx * 18)
    return _item("Sundae", b, mat)


def build_strawberry_roll(mat):
    """A slice of roll cake standing on its edge, its cream spiral to the front, a dollop and a strawberry on top."""
    b = Builder()
    r, w, y0 = 0.32, 0.26, 0.02
    zc = PT + r
    b.cyl((0, y0, zc), r, w, "treat_tan", segments=14, rot=_rx(90), **NO)
    face = y0 - w / 2
    b.cyl((0, face - 0.02, zc), r - 0.035, 0.04, "fur_vanilla", segments=14, rot=_rx(90), **NO)
    turns, n = 2.0, 14                        # the cream spiral, in short dashes on the face
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        a0, a1 = t0 * turns * 2 * math.pi, t1 * turns * 2 * math.pi
        r0, r1 = 0.03 + t0 * 0.22, 0.03 + t1 * 0.22
        p0 = Vector((r0 * math.cos(a0), r0 * math.sin(a0)))
        p1 = Vector((r1 * math.cos(a1), r1 * math.sin(a1)))
        m, d = (p0 + p1) / 2, p1 - p0
        ang = math.atan2(d.y, d.x)
        b.box((m.x, face - 0.06, zc + m.y), (d.length + 0.04, 0.04, 0.055), "offwhite",
              rot=Matrix.Rotation(-ang, 3, "Y"), **NO)
    top = PT + 2 * r
    b.ico((0, y0, top + 0.02), 0.12, "offwhite", subdivisions=1)
    b.ico((0, y0, top + 0.17), 0.09, "shirt_red", scale=(1, 1, 1.25), subdivisions=1)
    b.pyramid((0, y0, top + 0.26), 0.12, 0.07, "leaf_green", rot=_rz(45))
    return _item("StrawberryRoll", b, mat)


def build_rainbow_cake(mat):
    """A tall slice in six rainbow layers, white frosting, sprinkles, a cream dollop and a cherry."""
    b = Builder()
    top = _layers(b, PT, ((0.1, "shirt_red"), (0.1, "fur_marmalade"), (0.1, "fur_golden"), (0.1, "shirt_green"),
                          (0.1, "shirt_blue"), (0.1, "aurora_violet"), (0.07, "offwhite")), half=0.3)
    for (x, y, c) in ((-0.12, 0.12, "shirt_red"), (0.1, 0.18, "shirt_blue"), (0.0, -0.12, "shirt_green"),
                      (0.15, 0.02, "fur_marmalade"), (-0.05, 0.22, "aurora_violet")):
        b.box((x, y, top + 0.005), (0.05, 0.025, 0.03), c, rot=_rz(x * 300 + 30), **NO)
    b.ico((0, 0.08, top + 0.07), 0.1, "offwhite", subdivisions=1)
    b.ico((0, 0.08, top + 0.2), 0.075, "shirt_red", subdivisions=1)
    return _item("RainbowCake", b, mat)


def build_gold_plate(mat):
    return [_plate("gold_mid", "gold_light").finalize("CatCafe_Menu_GoldPlate", mat)]


def build_tray(mat):
    """A round silver tray with a raised lip. Its underside centre is the pivot; `Item` is its top centre."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.6, 0.05, "metal", segments=14, **NO)
    b.cyl_base((0, 0, 0.05), TRAY_R, TRAY_TOP - 0.05, "fur_silver", segments=16, **NO)
    b.ring((0, 0, TRAY_TOP + 0.05), TRAY_R, 0.07, 0.1, "metal", segments=16, **NO)
    ATTACHMENTS["CatCafe_Menu_Tray"] = [("Item", (0.0, TRAY_TOP, 0.0))]
    return [b.finalize("CatCafe_Menu_Tray", mat)]


def build_coin_bag(mat):
    """A burlap sack tied with a red cord, a gold paw on its front and a coin peeking out of the top."""
    b = Builder()
    b.sphere((0, 0, 0.31), 0.32, "cardboard", segments=12, rings=6, scale=(1, 1, 0.97))
    b.cyl_base((0, 0, 0.55), 0.13, 0.12, "cardboard", segments=10, **NO)
    b.cyl_base((0, 0, 0.6), 0.155, 0.05, "shirt_red", segments=10, **NO)
    b.cyl_base((0, 0, 0.67), 0.12, 0.1, "cardboard", segments=10, radius2=0.2, **NO)
    up = Matrix.Rotation(math.radians(12), 3, "Y") @ Matrix.Rotation(math.radians(90), 3, "X")
    b.cyl((0.02, 0.02, 0.8), 0.12, 0.04, "rarity_legend", segments=12, rot=up, **NO)   # a coin peeking out
    tilt = Matrix.Rotation(math.radians(90), 3, "X")                  # the paw stands on the sack's front
    b.cyl((0, -0.31, 0.27), 0.08, 0.04, "rarity_legend", segments=10, rot=tilt, **NO)
    for (dx, dz) in ((-0.1, 0.06), (-0.035, 0.12), (0.035, 0.12), (0.1, 0.06)):
        b.cyl((dx, -0.3, 0.27 + dz + 0.02), 0.033, 0.04, "rarity_legend", segments=8, rot=tilt, **NO)
    return [b.finalize("CatCafe_Menu_CoinBag", mat)]


def build_oven(mat):
    """The oven behind the counter (Roblox axes, front -Z): body, top, ears, dial and knobs, door, flue."""
    b, door = RB(), RB()
    hw, hd = OVEN_W / 2, OVEN_D / 2
    for sx in (-1, 1):                                                       # feet
        for sz in (-1, 1):
            b.span((sx * hw * 0.8 - 0.15, 0, sz * hd * 0.75 - 0.15), (sx * hw * 0.8 + 0.15, 0.3, sz * hd * 0.75 + 0.15),
                   "dark_wood")
    b.span((-hw, 0.3, -hd), (hw, OVEN_H - 0.2, hd), "mint")
    b.span((-hw - 0.1, OVEN_H - 0.2, -hd - 0.1), (hw + 0.1, OVEN_H, hd + 0.1), "offwhite")    # the top
    b.span((-hw - 0.04, 0.26, -hd - 0.04), (hw + 0.04, 0.5, hd + 0.04), "offwhite")           # skirting band
    for sx in (-1, 1):                                                       # cat ears on the top's front corners
        x0 = sx * (hw - 0.55)
        b.fan_z(-hd + 0.35, (x0, OVEN_H + 0.62), [(x0 - 0.38, OVEN_H), (x0 + 0.38, OVEN_H)], 0.3, "mint")
        b.fan_z(-hd + 0.17, (x0, OVEN_H + 0.42), [(x0 - 0.22, OVEN_H), (x0 + 0.22, OVEN_H)], 0.06, "blush")
    yb = 2.75                                                                # the control band over the door
    b.span((-hw + 0.15, yb - 0.3, -hd - 0.04), (hw - 0.15, yb + 0.3, -hd), "offwhite")
    b.cyl((0, yb, -hd - 0.07), 0.26, 0.06, "offwhite", axis="Z", segments=14)                 # the timer dial
    b.cyl((0, yb, -hd - 0.11), 0.2, 0.04, "lamp_warm", axis="Z", segments=12)
    b.span((-0.02, yb - 0.02, -hd - 0.15), (0.02, yb + 0.16, -hd - 0.13), "dark_wood")       # its hand
    for x in (-1.0, -0.55, 0.55, 1.0):
        b.cyl((x, yb, -hd - 0.08), 0.12, 0.08, "dark_wood", axis="Z", segments=10)           # knobs
        b.span((x - 0.02, yb, -hd - 0.13), (x + 0.02, yb + 0.1, -hd - 0.12), "offwhite")
    # the door, built about its bottom hinge at (0, HINGE_Y, front)
    hy, fz = 0.6, -hd
    door.span((-1.25, 0.0, -0.08), (1.25, 1.75, 0.0), "offwhite")
    door.span((-0.85, 0.42, -0.12), (0.85, 1.32, -0.08), "dark_wood")                       # window frame
    door.span((-0.75, 0.5, -0.16), (0.75, 1.24, -0.12), "lamp_warm")                        # the warm window
    for x in (-0.25, 0.25):                                                                   # a rack's bars inside
        door.span((x - 0.02, 0.5, -0.18), (x + 0.02, 1.24, -0.16), "fur_orange_dark")
    for x in (-0.9, 0.9):                                                                     # handle posts and bar
        door.span((x - 0.05, 1.45, -0.26), (x + 0.05, 1.55, -0.08), "metal")
    door.span((-1.0, 1.45, -0.36), (1.0, 1.55, -0.26), "metal")
    py = 0.2                                                                                  # a paw under the window
    door.span((-0.12, py, -0.12), (0.12, py + 0.13, -0.08), "mint")
    for (dx, dy) in ((-0.16, 0.18), (-0.055, 0.24), (0.055, 0.24), (0.16, 0.18)):
        door.span((dx - 0.045, py + dy - 0.04, -0.12), (dx + 0.045, py + dy + 0.04, -0.08), "mint")
    fx, fzz, fr = hw - 0.6, hd - 0.55, 0.26                                  # the flue pipe at the back
    b.cyl((fx, OVEN_H + 0.5, fzz), fr, 1.0, "metal")
    b.cyl((fx, OVEN_H + 1.05, fzz), fr + 0.08, 0.1, "metal")
    b.cyl((fx, OVEN_H + 0.35, fzz), fr + 0.04, 0.08, "fur_silver")
    ATTACHMENTS[OVEN] = [("DoorGlow", (0.0, hy + 0.87, fz - 0.16))]
    return [b.finalize(OVEN, mat), door.finalize(OVEN + "_Door", mat, location=(0.0, hy, fz))]


def rbx_attachments(name):
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACHMENTS.get(name, [])]


_BUILDS = {"Coffee": build_coffee, "Milk": build_milk, "CakeSlice": build_cake_slice, "PawCookie": build_paw_cookie,
           "Tea": build_tea, "FishBiscuit": build_fish_biscuit, "KittyCupcake": build_kitty_cupcake,
           "HotCocoa": build_hot_cocoa, "PancakeStack": build_pancake_stack, "Sundae": build_sundae,
           "StrawberryRoll": build_strawberry_roll, "RainbowCake": build_rainbow_cake}
ASSETS = {
    **{"CatCafe_Menu_" + n: (_BUILDS[n], 500) for n in ITEMS},
    "CatCafe_Menu_GoldPlate": (build_gold_plate, 200),
    "CatCafe_Menu_Tray": (build_tray, 400),
    "CatCafe_Menu_CoinBag": (build_coin_bag, 500),
    OVEN: (build_oven, 1500),
}
