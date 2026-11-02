"""Items: food bowls, lure foods (kibble, tuna, salmon, the four dealer foods), nets, the rich
customer's tip pile. Pivot base center. Dealer foods sit on the kibble in CatCafe_Item_FoodBowl:
put their pivot at the bowl's pivot plus FOOD_IN_BOWL up."""

import math

from mathutils import Matrix, Vector

from common import Builder

FOOD_IN_BOWL = 0.18      # kibble top in CatCafe_Item_FoodBowl, studs above its pivot
GRIP = 0.36              # a net's grip wrap centre, studs along the pole from its end
FOODS = ("Sardines", "Caviar", "MoonMilk", "StarTreat")     # the dealer foods that sit in a bowl


def _bowl(b, outer, rim, food, premium=False):
    b.cyl_base((0, 0, 0), 0.45, 0.06, outer, segments=12, bevel=False)
    b.ring((0, 0, 0.18), 0.46, 0.08, 0.26, outer, segments=12, bevel=False)
    if premium:
        b.ring((0, 0, 0.32), 0.48, 0.06, 0.06, rim, segments=12, bevel=False)
    if food:
        b.cyl_base((0, 0, 0.06), 0.38, 0.12, food, segments=12, bevel=False)


def build_food_bowl(mat):
    b = Builder()
    _bowl(b, "bowl_red", None, "kibble")
    return [b.finalize("CatCafe_Item_FoodBowl", mat)]


def build_food_bowl_premium(mat):
    b = Builder()
    _bowl(b, "blush", "rarity_legend", "fish_belly", premium=True)
    b.sphere((0, 0.05, 0.3), 0.22, "fish_blue", segments=8, rings=4, scale=(0.7, 1.3, 0.6))
    b.pyramid((0, 0.42, 0.22), 0.22, 0.22, "fish_blue", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_FoodBowl_Premium", mat)]


def build_kibble(mat):
    """Small kibble bag."""
    b = Builder()
    b.box_base((0, 0, 0), (0.7, 0.4, 0.9), "treat_tan")
    b.box((0, -0.21, 0.5), (0.5, 0.02, 0.4), "bowl_red", bevel=False)
    b.box((0, -0.22, 0.5), (0.3, 0.02, 0.2), "fur_black", bevel=False)
    b.box_base((0, 0, 0.9), (0.72, 0.42, 0.1), "treat_tan")
    return [b.finalize("CatCafe_Item_Kibble", mat)]


def build_tuna_can(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.35, 0.3, "metal", segments=12)
    b.cyl_base((0, 0, 0.07), 0.36, 0.16, "fish_blue", segments=12, bevel=False)
    b.ring((0, 0, 0.28), 0.36, 0.05, 0.04, "metal", segments=12, bevel=False)
    b.box((0, -0.365, 0.15), (0.3, 0.01, 0.1), "offwhite", bevel=False)
    return [b.finalize("CatCafe_Item_TunaCan", mat)]


def build_salmon(mat):
    """A whole fish, head toward -Y."""
    b = Builder()
    b.sphere((0, 0, 0.22), 0.35, "fish_blue", segments=10, rings=6, scale=(0.55, 1.0, 0.62))
    b.sphere((0, 0.02, 0.17), 0.3, "fish_belly", segments=10, rings=6, scale=(0.5, 0.9, 0.5))
    b.cyl((0, 0.45, 0.24), 0.24, 0.05, "fish_blue", segments=3, bevel=False, rot=(math.radians(90), "Y"))
    b.cyl((0, 0.0, 0.45), 0.12, 0.04, "fish_blue", segments=3, bevel=False, rot=(math.radians(90), "Y"))
    for x in (-0.12, 0.12):
        b.box((x, -0.2, 0.3), (0.07, 0.07, 0.07), "fur_black", bevel=False)
    return [b.finalize("CatCafe_Item_Salmon", mat)]


def _bar(b, a, c, w, t, swatch, up=(0, 0, 1)):
    """A rod from point a to point c: width w across, thickness t along `up`."""
    a, c = Vector(a), Vector(c)
    y = (c - a).normalized()
    z = Vector(up)
    z = (z - y * z.dot(y)).normalized()
    R = Matrix((y.cross(z), y, z)).transposed()
    b.box(tuple((a + c) / 2), (w, (c - a).length, t), swatch, bevel=False, rot=R)


def _hoop(b, hy, r, t, h, swatch, n=10):
    """A net's rim: n bars round a ring lying flat in XY at (0, hy, 0), outer faces at r, `t` wide, `h` tall. Each bar
    is as long as the outer polygon's side, so the outer corners meet with no notch (the inner ends tuck into the
    neighbours, and every other bar stands 0.008 taller each side so no two tops share a plane)."""
    side = 2 * r * math.tan(math.pi / n)
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        c = (math.cos(a) * (r - t / 2), hy + math.sin(a) * (r - t / 2), 0)
        b.box(c, (t, side, h + 0.016 * (i % 2)), swatch, bevel=False, rot=(a, "Z"))   # never coplanar


def _ear(b, base, out, width, height, thick, swatch):
    """A cat ear lying flat in XY: a triangle `width` across its base at `base`, pointing along `out`, `thick` along
    Z. Two wedges back to back (two WedgeParts in Roblox)."""
    R = Matrix(((0, out.y, out.x), (0, -out.x, out.y), (1, 0, 0)))     # local X up (Z), Y across, Z out
    for side in (-1, 1):
        c = base + R @ Vector((0, side * width / 4, height / 2))
        rot = R if side < 0 else R @ Matrix.Rotation(math.pi, 3, "Z")
        b.wedge(tuple(c), (thick, width / 2, height), swatch, bevel=False, rot=rot)


NET_NAMES = ("Basic", "Sturdy", "Pro", "Master")     # CatCafe_Item_Net_L1 to L4 (catch-rework.md, F93)


def build_net(level, mat):
    """Catching net, held in the right hand all the time (F93; Effects' NetHold puts the Grip in the hand). Pivot at
    the grip end; the pole runs forward (-Y in Blender, -Z in Roblox) to a hoop lying flat at the far end, its open
    face up, and the netting hangs below it. Three objects: `_Handle` (pole, wrap, collar and the level's trims),
    `_Hoop` (the rim) and `_Bag` (strands in a mesh over a see-through netting cone, `_Bag_Glass`). Each level looks
    better than the last: L1 Basic, a plain wooden net; L2 Sturdy, a mint pole with steel bands and a steel hoop;
    L3 Pro, a blue pole and hoop with brass trims, sky blue netting; L4 Master, a dark wood pole with gold bands
    and a gold pommel, a gold hoop with cat ears and gems, lilac netting. The rim's far edge stays the farthest point
    from the Grip (VFX-Agent's NetTrail trails the whoosh off it)."""
    k = level - 1
    pole_col = ("caramel_wood", "mint", "shirt_blue", "dark_wood")[k]
    hoop_col = ("dark_wood", "metal", "shirt_blue", "rarity_legend")[k]
    trim_col = (None, "metal", "brass", "rarity_legend")[k]
    net_col = ("offwhite", "offwhite", "pastel_sky", "pastel_lilac")[k]
    strand_col = "fur_white"
    pole = 3.0 + 0.3 * k
    hoop_r = 0.9 + 0.15 * k
    X = (math.radians(90), "X")
    h, hoop, bag, glass = Builder(), Builder(), Builder(), Builder()
    h.cyl((0, -(pole - 0.08) / 2 - 0.04, 0), 0.1, pole - 0.08, pole_col, segments=8, rot=X)
    h.cyl((0, -GRIP, 0), 0.13, 0.68, "fur_black" if k < 2 else ("pants_navy", "fur_black")[k - 2], segments=8, rot=X)
    if trim_col:
        bands = ((-1.3, -2.1), (-1.25, -2.0, -2.75), (-1.3, -2.2, -3.1))[k - 1]
        for y in bands:
            h.cyl((0, y, 0), 0.125, 0.1, trim_col, segments=8, rot=X)                           # bands
    if k >= 2:
        h.cyl((0, -0.02, 0), 0.15, 0.08, trim_col, segments=8, rot=X)                           # end cap
    if k == 3:
        h.sphere((0, 0.1, 0), 0.15, trim_col, segments=8, rings=4)                               # pommel
        h.box((0, -0.36, 0.13), (0.08, 0.2, 0.04), "neon_pink", bevel=False)                     # gem on the wrap
    hy = -pole - hoop_r                       # hoop centre
    rim_t, rim_h = 0.1 + 0.02 * (k >= 1), 0.12 + 0.02 * (k >= 2)
    h.box((0, -pole + 0.06, 0), (0.22, 0.32, 0.22), trim_col or "dark_wood")                   # collar onto the rim
    _hoop(hoop, hy, hoop_r, rim_t, rim_h, hoop_col)
    if k == 3:                                # Master: cat ears on the far rim, pink inside
        for sx in (-1, 1):
            a = math.radians(-90 + sx * 32)
            u = Vector((math.cos(a), math.sin(a), 0))
            base = Vector((0, hy, 0)) + u * (hoop_r - 0.03)
            _ear(hoop, base, u, 0.42, 0.38, rim_h - 0.02, hoop_col)
            t = Vector((-u.y, u.x, 0))
            tri = [base + u * 0.1 + t * 0.1, base + u * 0.3, base + u * 0.1 - t * 0.1]
            c = sum(tri, Vector()) / 3
            r = [((v - c).x, (v - c).y) for v in tri]    # pink inside the ear on its open face, proud of the gold
            hoop.fan((c.x, c.y, (rim_h - 0.02) / 2 + 0.003), r[0], r[1:], 0.016, "nose_pink")
    # the netting: a see-through cone hung inside the rim, four strands from the rim to its tip over it and a ring
    # of eight round its middle, so it reads as mesh
    top_z, top_r = -rim_h / 2 + 0.01, hoop_r - rim_t + 0.01
    depth = 1.0 + 0.1 * k
    tip_r = 0.18
    glass.cyl((0, hy, top_z - depth / 2), tip_r, depth, net_col, segments=10, radius2=top_r, bevel=False)
    slope = (top_r - tip_r) / depth
    off = 0.025 * math.sqrt(1 + slope * slope)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        u = (math.cos(a), math.sin(a))
        p0 = (u[0] * (top_r + off), hy + u[1] * (top_r + off), top_z - 0.005)
        p1 = (u[0] * (tip_r + off), hy + u[1] * (tip_r + off), top_z - depth + 0.02)
        _bar(bag, p0, p1, 0.04, 0.04, strand_col, up=(u[0], u[1], 0))
    ring_z = top_z - 0.45 * depth
    rv = (top_r - slope * 0.45 * depth + 0.035) / math.cos(math.pi / 8)
    for i in range(8):
        a0, a1, am = math.radians(45 * i), math.radians(45 * (i + 1)), math.radians(45 * i + 22.5)
        _bar(bag, (math.cos(a0) * rv, hy + math.sin(a0) * rv, ring_z), (math.cos(a1) * rv, hy + math.sin(a1) * rv, ring_z),
             0.04, 0.035, strand_col, up=(math.cos(am), math.sin(am), 0))
    name = f"CatCafe_Item_Net_L{level}"
    return [h.finalize(name + "_Handle", mat), hoop.finalize(name + "_Hoop", mat), bag.finalize(name + "_Bag", mat),
            glass.finalize(name + "_Bag_Glass", mat)]


def grip_attachment():
    """The hand's spot on a net: the Attachment `Grip` in the middle of the black wrap, on the Handle, with the
    net's own axes (the pole runs -Z in Roblox, the hoop's open face up +Y)."""
    return ("_Handle", "Grip", Matrix.Translation((0.0, -GRIP, 0.0)))


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def build_sardines(mat):
    """Three sardines fanned on the kibble, silver bellies, heads toward -Y."""
    b = Builder()
    for (x, y, z, a) in ((-0.15, 0.02, 0.06, 14), (0.16, 0.0, 0.06, -12), (0.0, -0.04, 0.15, 2)):
        R = _rz(a)
        b.sphere((x, y, z), 0.27, "fish_blue", segments=8, rings=4, scale=(0.32, 1.0, 0.3), rot=R)
        b.sphere((x, y, z - 0.025), 0.26, "metal", segments=8, rings=4, scale=(0.3, 0.92, 0.22), rot=R)
        tx, ty = -math.sin(math.radians(a)) * 0.3, math.cos(math.radians(a)) * 0.3
        b.cyl((x + tx, y + ty, z), 0.1, 0.03, "fish_blue", segments=3, bevel=False,
              rot=R @ Matrix.Rotation(math.radians(90), 3, "Y"))                                   # tail fin
        ex, ey = math.sin(math.radians(a)) * 0.2, -math.cos(math.radians(a)) * 0.2
        b.box((x + ex + 0.05, y + ey, z + 0.04), (0.04, 0.04, 0.04), "fur_black", bevel=False)  # eye
    return [b.finalize("CatCafe_Item_Sardines", mat)]


def build_caviar(mat):
    """A little round tin of caviar with a gold rim and a pearl spoon."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.3, 0.12, "galaxy_blue", segments=12)
    b.ring((0, 0, 0.13), 0.31, 0.04, 0.03, "rarity_legend", segments=12, bevel=False)
    b.cyl_base((0, 0, 0.12), 0.27, 0.04, "fur_black", segments=12, bevel=False)
    b.sphere((0, 0, 0.15), 0.22, "fur_black", segments=10, rings=4, scale=(1, 1, 0.35))         # heaped pearls
    for (x, y) in ((0.08, -0.05), (-0.1, 0.06), (0.02, 0.12), (-0.04, -0.12), (0.14, 0.08)):
        b.ico((x, y, 0.21), 0.035, "galaxy_blue", subdivisions=1)
    b.box((0.18, -0.22, 0.2), (0.07, 0.42, 0.03), "offwhite", bevel=False, rot=_rz(-35))       # spoon
    b.sphere((0.05, -0.04, 0.21), 0.07, "offwhite", segments=8, rings=4, scale=(1, 1.3, 0.3))
    b.ring((0, 0, 0.0), 0.32, 0.05, 0.02, "rarity_legend", segments=12, bevel=False)
    return [b.finalize("CatCafe_Item_Caviar", mat)]


def build_moon_milk(mat):
    """A pool of moon milk on the kibble with a small crescent moon and two stars over it."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.04, "milk", segments=14, bevel=False)
    b.sphere((0, 0, 0.04), 0.3, "milk", segments=10, rings=4, scale=(1, 1, 0.12))
    b.crescent((0, 0.0, 0.42), 0.17, 0.12, 0.06, "sparkle")
    b.cyl((0, 0, 0.2), 0.02, 0.14, "sparkle", segments=4, bevel=False)                        # moon stalk
    b.star((-0.22, -0.05, 0.35), 0.07, 0.03, 0.03, "sparkle", rot=(math.radians(90), "X"))
    b.star((0.24, 0.02, 0.48), 0.06, 0.025, 0.03, "sparkle", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_MoonMilk", mat)]


def build_star_treat(mat):
    """A gold star biscuit leaning on a smaller one, flecked with sparkle."""
    b = Builder()
    b.star((0.1, 0.08, 0.04), 0.2, 0.09, 0.06, "treat_tan")
    tilt = Matrix.Rotation(math.radians(55), 3, "X")
    b.star((-0.02, -0.04, 0.2), 0.27, 0.12, 0.08, "rarity_legend", rot=tilt)
    for (x, z) in ((-0.08, 0.27), (0.07, 0.2), (0.0, 0.33)):
        b.box((x, -0.11, z), (0.04, 0.02, 0.04), "sparkle", bevel=False, rot=tilt)
    return [b.finalize("CatCafe_Item_StarTreat", mat)]


def build_tip_pile(mat):
    """The rich customer's tip: a heap of gold coins with a few short stacks. Sits on a table."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.42, 0.18, "rarity_legend", segments=10, radius2=0.18, bevel=False)    # heap core
    coin = dict(segments=10, bevel=False)
    for (x, y, n) in ((-0.42, 0.15, 4), (0.38, 0.25, 3), (0.15, -0.4, 2)):                     # stacks
        for k in range(n):
            b.cyl_base((x + 0.015 * (k % 2), y, 0.06 * k), 0.16, 0.055, "rarity_legend", **coin)
    for (x, y, z, a, ax) in ((0.0, 0.0, 0.22, 20, "X"), (-0.15, -0.2, 0.12, -30, "Y"), (0.25, -0.05, 0.12, 25, "Y"),
                             (-0.1, 0.25, 0.12, 30, "X"), (0.55, -0.35, 0.03, 0, "X")):
        b.cyl((x, y, z), 0.16, 0.05, "rarity_legend", rot=(math.radians(a), ax), **coin)         # loose coins
    for (x, y, z) in ((0.0, 0.0, 0.26), (-0.42, 0.15, 0.25)):
        b.box((x, y, z), (0.06, 0.06, 0.02), "sparkle", bevel=False)                           # glints
    return [b.finalize("CatCafe_Prop_TipPile", mat)]


ASSETS = {
    "CatCafe_Item_FoodBowl": (build_food_bowl, 300),
    "CatCafe_Item_FoodBowl_Premium": (build_food_bowl_premium, 400),
    "CatCafe_Item_Kibble": (build_kibble, 300),
    "CatCafe_Item_TunaCan": (build_tuna_can, 300),
    "CatCafe_Item_Salmon": (build_salmon, 400),
    "CatCafe_Item_Net_L1": (lambda m: build_net(1, m), 600),
    "CatCafe_Item_Net_L2": (lambda m: build_net(2, m), 750),
    "CatCafe_Item_Net_L3": (lambda m: build_net(3, m), 900),
    "CatCafe_Item_Net_L4": (lambda m: build_net(4, m), 1100),
    "CatCafe_Item_Sardines": (build_sardines, 400),
    "CatCafe_Item_Caviar": (build_caviar, 600),
    "CatCafe_Item_MoonMilk": (build_moon_milk, 300),
    "CatCafe_Item_StarTreat": (build_star_treat, 300),
    "CatCafe_Prop_TipPile": (build_tip_pile, 600),
}
