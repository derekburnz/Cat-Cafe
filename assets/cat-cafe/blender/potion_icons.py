"""Potion flask pictures (#1176, the potion rework): one clear coloured flask per potion in Catalog.potions, for the HUD
potion slots and the shop rows, rendered by icons.py as CatCafe_Icon_PotionFlask_<Name> (transparent, outlined, 512 px).

The liquid is the potion's exact colour from the UI's Theme.potionColors (read from Theme.luau at build time), so the
slot, the drink pop and the picture agree. A badge on the front says what it does, and the flask's size says how
strong it is within its family:

  weak    a small round flask                         Tip (a coin), Lucky (a clover)
  mid     a round flask                               Swift (a lightning bolt), Steady (a paw), QuickBait (a fish)
  strong  a bigger flask, a gold collar and sparkles  BigTip (a coin stack), GoldRush (a star)

Each potion also has its own bottle shape (#1369, SHAPES), from the same family as its 3D bottle in potions.py:
Tip a round flask, Lucky a tall bottle, Swift a slim bottle with wings, Steady a squat jar with a wooden lid,
QuickBait a labelled bottle, BigTip a mug with a handle and a gold screw cap, GoldRush an egg on a gold foot with a
star stopper, and the Cat Whistle a cone flask.

Tip, BigTip and GoldRush share warm yellows in the Theme, so their badges and sizes carry the difference. The Corner
Shop's Cat Whistle (a whistle badge) comes in three sizes, CatWhistleSmall, CatWhistle and CatWhistleBig, drawn weak,
mid and strong; its colour is FALLBACK_COLOURS' until Theme lists it.
Built in Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math
import os
import re

import bpy

from common import Builder

THEME = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "games", "cat-cafe", "src",
                     "client", "UI", "Theme.luau")
X = (math.radians(90), "X")                       # turns a Z-axis primitive to face the camera (-Y)

# name -> (theme id, tier, badge)
POTIONS = {
    "Tip": ("tip_potion", "weak", "coin"),
    "Lucky": ("lucky_potion", "weak", "clover"),
    "Swift": ("swift_potion", "mid", "bolt"),
    "Steady": ("steady_potion", "mid", "paw"),
    "QuickBait": ("quick_bait_potion", "mid", "fish"),
    "BigTip": ("big_tip_potion", "strong", "coins"),
    "GoldRush": ("gold_rush_potion", "strong", "star"),
    # the Corner Shop's Cat Whistle (corner-shop-v2.md section 1, #1180) in its three sizes, sized like the tiers
    "CatWhistleSmall": ("cat_whistle", "weak", "whistle"),
    "CatWhistle": ("cat_whistle", "mid", "whistle"),
    "CatWhistleBig": ("cat_whistle", "strong", "whistle"),
}
# A colour for a potion Theme.potionColors does not list yet; UI-Engineer adds the same hex there so the slot, the
# drink pop and the picture agree (the Cat Whistle: sign_teal, the colour its in-game puff and ring already use,
# Effects/Presets potionWhistle; darker than Steady's pale mint)
FALLBACK_COLOURS = {"cat_whistle": "1FA58F"}
SIZE = {"weak": 0.78, "mid": 0.92, "strong": 1.05}  # the flask body's radius


def theme_colours():
    """theme id -> (r, g, b) 0..1 sRGB, from Theme.potionColors."""
    src = open(THEME, encoding="utf-8").read()
    block = src[src.index("Theme.potionColors = {"):]
    block = block[:block.index("}")]
    out = {}
    for pid, hexv in re.findall(r"(\w+) = Color3\.fromHex\(\"([0-9A-Fa-f]{6})\"\)", block):
        out[pid] = tuple(int(hexv[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return out


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _tint(ob, rgb, emit=0.0):
    m = bpy.data.materials.new("_PotionLiquid")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    lin = tuple(_lin(v) for v in rgb)
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.25
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    ob.data.materials.clear()
    ob.data.materials.append(m)


BADGE_K = 1.3                                     # the badge's size against its first drawing


def _badge(b0, kind, z, y, k=1.0):
    """The badge on the flask's front: a cream disc with the potion's sign, its face at depth y (toward -Y)."""
    b = _Scaled(b0, (0.0, y, z), BADGE_K * k)
    b.cyl((0, y + 0.03, z), 0.36, 0.06, "cream", segments=18, rot=X)
    f = y - 0.005                                   # the sign stands just proud of the disc
    if kind == "coin":
        b.cyl((0, f, z), 0.2, 0.05, "gold_mid", segments=14, rot=X)
        b.cyl((0, f - 0.03, z), 0.12, 0.03, "gold_light", segments=12, rot=X)
    elif kind == "coins":
        for k, dz in enumerate((-0.12, 0.0, 0.12)):
            b.cyl((0.02 * k, f - 0.01 * k, z + dz), 0.17, 0.05, ("gold_mid", "gold_light")[k % 2], segments=14,
                  rot=(math.radians(70), "X"))
    elif kind == "clover":
        for a in (90, 210, 330):
            r = math.radians(a)
            b.cyl((0.1 * math.cos(r), f, z + 0.1 * math.sin(r)), 0.1, 0.05, "leaf_green", segments=10, rot=X)
        b.box((0.03, f, z - 0.16), (0.04, 0.05, 0.16), "leaf_dark", rot=(math.radians(-15), "Y"))
    elif kind == "bolt":
        b.box((0.04, f, z + 0.08), (0.08, 0.05, 0.22), "rarity_legend", rot=(math.radians(-25), "Y"))
        b.box((-0.04, f, z - 0.08), (0.08, 0.05, 0.22), "rarity_legend", rot=(math.radians(-25), "Y"))
        b.box((0.0, f, z), (0.16, 0.05, 0.06), "rarity_legend")
    elif kind == "paw":
        b.cyl((0, f, z - 0.05), 0.11, 0.05, "fur_brown", segments=10, rot=X)
        for dx, dz in ((-0.11, 0.08), (-0.04, 0.13), (0.04, 0.13), (0.11, 0.08)):
            b.cyl((dx, f, z + dz), 0.04, 0.05, "fur_brown", segments=8, rot=X)
    elif kind == "fish":
        b.ico((-0.03, f, z), 0.13, "fish_blue", scale=(1.3, 0.3, 0.7))
        b.prism((0.17, f + 0.02, z), [(-0.04, 0.0), (0.1, 0.09), (0.1, -0.09)], 0.04, "fish_blue", rot=X)
        b.cyl((-0.1, f - 0.04, z + 0.03), 0.025, 0.02, "fur_black", segments=6, rot=X)
    elif kind == "star":
        b.star((0, f, z), 0.2, 0.09, 0.05, "rarity_legend", rot=X)
    elif kind == "whistle":                         # a gold whistle, mouthpiece to the left, two sound lines
        b.cyl((0.04, f, z - 0.02), 0.12, 0.05, "gold_mid", segments=14, rot=X)                  # its round body
        b.box((-0.13, f, z + 0.05), (0.2, 0.05, 0.08), "gold_mid")                             # mouthpiece
        b.box((0.02, f - 0.03, z + 0.06), (0.06, 0.02, 0.04), "fur_black")                     # the hole on top
        b.cyl((0.04, f - 0.03, z - 0.02), 0.05, 0.02, "gold_light", segments=10, rot=X)         # a shine
        for k, (dx, dz, a) in enumerate(((0.23, 0.1, -35), (0.26, -0.02, 0))):                  # sound lines
            b.box((dx, f, z + dz), (0.1, 0.05, 0.03), "fur_brown", rot=(math.radians(a), "Y"))


class _Scaled:
    """Draws on a Builder with every position and size scaled by k about a centre (for the badge)."""

    def __init__(self, b, centre, k):
        self.b, self.c, self.k = b, centre, k

    def _p(self, p):
        return tuple(self.c[i] + (p[i] - self.c[i]) * self.k for i in range(3))

    def cyl(self, c, r, h, sw, **kw):
        if "radius2" in kw and kw["radius2"] is not None:
            kw["radius2"] *= self.k
        self.b.cyl(self._p(c), r * self.k, h * self.k, sw, **kw)

    def box(self, c, size, sw, **kw):
        self.b.box(self._p(c), tuple(v * self.k for v in size), sw, **kw)

    def ico(self, c, r, sw, **kw):
        self.b.ico(self._p(c), r * self.k, sw, **kw)

    def prism(self, c, pts, h, sw, **kw):
        self.b.prism(self._p(c), [(x * self.k, y * self.k) for x, y in pts], h * self.k, sw, **kw)

    def star(self, c, outer, inner, h, sw, **kw):
        self.b.star(self._p(c), outer * self.k, inner * self.k, h * self.k, sw, **kw)


FRAME = (1.3, 2.85)                               # half width and height of the shared frame: the strong flask fits


def _frame(mat, mat_name="_PotionFrame"):
    """An invisible box the size of the biggest flask, so every picture shares one scale and the tiers show."""
    b = Builder()
    b.box((0, 0, FRAME[1] / 2), (2 * FRAME[0], 0.02, FRAME[1]), "glass")
    ob = b.finalize("CatCafe_IconArt_PotionFlask_Frame", mat)
    m = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.0
    ob.data.materials.clear()
    ob.data.materials.append(m)
    ob.visible_shadow = False
    return ob


# name -> bottle shape (#1369): every potion its own silhouette, the same family as its 3D bottle in potions.py, so
# a player can tell them apart by shape alone, not just by colour and badge
SHAPES = {"Tip": "round", "Lucky": "tall", "Swift": "slim", "Steady": "jar", "QuickBait": "label", "BigTip": "mug",
          "GoldRush": "egg", "CatWhistleSmall": "cone", "CatWhistle": "cone", "CatWhistleBig": "cone"}
TIER_K = {"weak": 0.86, "mid": 1.0, "strong": 1.1}  # cone sizes for the Cat Whistle's three bottles


def _neck(shell, z, rn, h=0.42, cork="treat_tan"):
    """A clear neck standing at z, its lip and a cork. Returns the cork's top."""
    shell.cyl((0, 0, z + h / 2), rn, h, "milk", segments=14)
    top = z + h
    shell.cyl((0, 0, top), rn * 1.2, 0.08, "milk", segments=14)
    shell.cyl((0, 0, top + 0.12), rn * 0.8, 0.22, cork, segments=12, radius2=rn * 0.92)
    return top + 0.23


def _glints(shell, r, z, h, y=None):
    """The two white highlights, up and to the left of a body of half width r with its front at y."""
    y = -r * 0.9 if y is None else y
    shell.box((-r * 0.5, y, z), (0.08, 0.04, h), "milk", rot=(math.radians(-15), "Y"))
    shell.box((-r * 0.3, y - 0.02, z + h * 0.65), (0.06, 0.03, 0.08), "milk")


def _straight(shell, liquid, r, h, shoulder=0.3, foot=0.08):
    """A straight bottle body: a clear foot, the potion from the foot to h and a rounded shoulder. Returns its top."""
    shell.cyl((0, 0, foot / 2), r + 0.02, foot, "milk", segments=18)
    liquid.cyl((0, 0, foot + (h - foot) / 2), r, h - foot, "glass", segments=18)
    liquid.sphere((0, 0, h), r, "glass", segments=18, rings=10, scale=(1, 1, shoulder / r))
    return h + shoulder * 0.9


def _sparkles(shell, w, z0, z1):
    for (x, z, s) in ((-w - 0.1, z1 - 0.2, 0.16), (w + 0.05, z1 + 0.15, 0.12), (w + 0.02, z0 + 0.2, 0.1)):
        shell.star((x, -0.1, z), s, s * 0.42, 0.04, "pastel_butter", rot=X)


def flask(name, mat):
    pid, tier, badge = POTIONS[name]
    fallback = FALLBACK_COLOURS.get(pid, "BF7DFF")
    rgb = theme_colours().get(pid) or tuple(int(fallback[i:i + 2], 16) / 255 for i in (0, 2, 4))
    shape = SHAPES[name]
    shell, liquid = Builder(), Builder()
    bk = 1.0                                          # the badge's size against BADGE_K
    if shape == "round":                              # Tip: a small round flask
        r = SIZE[tier]
        liquid.sphere((0, 0, r), r, "glass", segments=20, rings=12)
        _neck(shell, r * 1.86, r * 0.32)
        _glints(shell, r, r * 1.35, r * 0.45)
        bz, by = r * 0.88, -r - 0.07
    elif shape == "tall":                             # Lucky: a tall straight bottle with round shoulders
        r = 0.6
        top = _straight(shell, liquid, r, 1.55, shoulder=0.3)
        _neck(shell, top - 0.05, 0.2, h=0.45)
        _glints(shell, r, 1.2, 0.4)
        bz, by, bk = 0.8, -r - 0.07, 0.92
    elif shape == "slim":                             # Swift: a slim tall bottle with a wing on each side
        r = 0.42
        top = _straight(shell, liquid, r, 1.7, shoulder=0.22)
        _neck(shell, top - 0.04, 0.15, h=0.4)
        for sx in (-1, 1):
            for dz, ln in ((0.12, 0.62), (0.0, 0.5), (-0.12, 0.38)):
                shell.box((sx * (r + 0.05 + ln / 2), 0.05, 1.2 + dz), (ln, 0.06, 0.1), "milk",
                          rot=(math.radians(sx * 22), "Y"))
        _glints(shell, r, 1.35, 0.4)
        bz, by, bk = 0.85, -r - 0.07, 0.78
    elif shape == "jar":                              # Steady: a squat wide jar with a wooden lid and a knob
        r = 1.0
        shell.cyl((0, 0, 0.04), r + 0.02, 0.08, "milk", segments=20)
        liquid.cyl((0, 0, 0.08 + 0.6), r, 1.2, "glass", segments=20)
        liquid.sphere((0, 0, 1.28), r, "glass", segments=20, rings=10, scale=(1, 1, 0.18))
        shell.cyl((0, 0, 1.47), r * 0.62, 0.1, "milk", segments=18)                        # the jar's mouth
        shell.cyl((0, 0, 1.6), r * 0.78, 0.2, "caramel_wood", segments=18)                  # the lid
        shell.cyl((0, 0, 1.76), 0.12, 0.14, "choco", segments=10)                           # its knob
        _glints(shell, r, 1.0, 0.35)
        bz, by = 0.68, -r - 0.07
    elif shape == "label":                            # Quick Bait: a shouldered bottle with a cream label round it
        r = 0.72
        top = _straight(shell, liquid, r, 1.35, shoulder=0.3)
        shell.cyl((0, 0, 0.72), r + 0.015, 0.62, "cream", segments=18)                     # the label band
        _neck(shell, top - 0.05, 0.22, h=0.42)
        _glints(shell, r, 1.38, 0.18, y=-r * 0.86)
        bz, by = 0.72, -r - 0.06
    elif shape == "mug":                              # Big Tip: a big mug with a loop handle and a gold screw cap
        r = 0.8
        top = _straight(shell, liquid, r, 1.6, shoulder=0.24)
        shell.cyl((0, 0, 0.85), r + 0.015, 0.72, "cream", segments=20)                     # the label band
        liquid.ring((r + 0.18, 0, 0.95), 0.32, 0.13, 0.2, "glass", segments=14, rot=(math.radians(90), "X"))
        shell.cyl((0, 0, top + 0.06), 0.38, 0.14, "milk", segments=16)                      # a short neck
        shell.cyl((0, 0, top + 0.22), 0.5, 0.2, "gold_mid", segments=16)                    # the screw cap
        shell.cyl((0, 0, top + 0.34), 0.42, 0.05, "gold_light", segments=16)
        _glints(shell, r, 1.55, 0.14, y=-r * 0.86)
        _sparkles(shell, r + 0.2, 0.3, top)
        bz, by = 0.85, -r - 0.06
    elif shape == "egg":                              # Gold Rush: a tall egg on a gold foot, a star for a stopper
        r = 0.72
        shell.cyl((0, 0, 0.06), 0.55, 0.12, "gold_mid", segments=16)                        # the foot
        shell.cyl((0, 0, 0.17), 0.3, 0.12, "gold_mid", segments=12)
        zc = 0.22 + r * 1.3
        liquid.sphere((0, 0, zc), r, "glass", segments=20, rings=12, scale=(1, 1, 1.3))
        n = zc + r * 1.25
        shell.cyl((0, 0, n + 0.12), 0.18, 0.26, "milk", segments=12)
        shell.cyl((0, 0, n + 0.3), 0.07, 0.14, "gold_mid", segments=8)
        shell.star((0, 0, n + 0.48), 0.26, 0.11, 0.08, "rarity_legend", rot=X)              # the star stopper
        for (x, z) in ((0.45, zc + 0.55), (-0.5, zc - 0.5), (0.55, zc - 0.35)):             # gold flecks
            shell.box((x, -0.72, z), (0.1, 0.03, 0.1), "gold_light", rot=(math.radians(45), "Y"))
        _glints(shell, r, zc + 0.55, 0.35)
        _sparkles(shell, r + 0.2, 0.3, n)
        bz, by = zc - 0.1, -r - 0.07
    else:                                             # the Cat Whistle: a cone flask with a wide foot, three sizes
        k = TIER_K[tier]
        r, h = 0.95 * k, 1.5 * k
        liquid.cyl((0, 0, h / 2), r, h, "glass", segments=20, radius2=r * 0.3)
        _neck(shell, h - 0.02, r * 0.3, h=0.42 * k)
        shell.box((-r * 0.45, -r * 0.62, h * 0.4), (0.08, 0.04, h * 0.3), "milk", rot=(math.radians(20), "Y"))
        if tier == "strong":
            shell.cyl((0, 0, h + 0.02), r * 0.36, 0.1, "gold_mid", segments=14)            # gold collar
            _sparkles(shell, r, 0.2, h + 0.3)
        bz, by, bk = h * 0.33, -r * 0.7 - 0.07, 0.75 + 0.15 * (tier != "weak")
    _badge(shell, badge, bz, by, bk)
    objs = [shell.finalize(f"CatCafe_IconArt_PotionFlask_{name}", mat),
            liquid.finalize(f"CatCafe_IconArt_PotionFlask_{name}_Liquid", mat)]
    _tint(objs[1], rgb, emit=0.25)
    return objs + [_frame(mat)]


BUILDERS = {n: (lambda m, n=n: flask(n, m)) for n in POTIONS}
