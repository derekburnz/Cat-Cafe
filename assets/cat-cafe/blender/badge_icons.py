"""Roblox badge pictures (#1934, docs/design/cat-cafe/release.md section 1), rendered by icons.py as
CatCafe_Icon_Badge_<Name> (transparent, outlined, 512 px). Roblox crops badge icons to a circle, so every badge is the
same round medal that fills that crop (icons.STORE_FIT): a gold rim, a pastel field with a thin cream ring, and one
simple picture standing out in front of it. Every picture stays inside the medal, so all 22 frame the same way.

The order is the spec's creation order (5 badges a day from 2026-11-07):
   1 Welcome        Welcome to the Cafe: the little cafe front, mint walls, a pink and white awning, an arched door
                    and a welcome mat, on sky blue
   2 FirstCatch     First Catch: a ginger cat sitting inside the hoop of a catching net, on mint
   3 CozyCafe       Cozy Cafe (Tier 2): a big cream mug of cocoa with a paw in the foam and curls of steam, on blush
   4 GrandOpening   Grand Opening: the red ribbon with its big bow, and gold scissors about to snip it, on butter
   5 Purrfect       Purrfect!: a pink and cream target with a gold paw print in the bullseye and twinkles, on lilac
   6 BaitCat        a tabby sitting by a red bowl heaped with kibble, a heart over her head, on butter
   7 RareFind       a Persian (Epic) sitting in front of a big purple star, on lilac
   8 LegendaryFind  Marshmallow (Legendary) in front of a big gold star, on butter
   9 MythicalFind   Comet (Mythical) in front of a big pink star, on night blue
  10 BusyCafe       Busy Cafe (Tier 3): a brass service bell ringing, on mint
  11 FamousCafe     Famous Cafe (Tier 4): five gold stars over a pink heart with a paw, on sky blue
  12 GrandCafe      Grand Cafe (Tier 5): a gold crown with berry and mint gems, on velvet lilac
  13 CatCollector   the open cat Index, both pages full of paw stamps, on mint
  14 CatExpert      a tuxedo cat in a scholar's cap with a gold tassel, on sky blue
  15 GoldenCoat     a gold tabby (gold.py) with twinkles, on lilac
  16 RainbowCoat    a white cat under a rainbow with clouds, on sky blue
  17 PageComplete   an Index page with every stamp filled and a big green tick, on blush
  18 HelpingPaw     two paws meeting in a high five over a pink heart, on mint
  19 FirstTrade     two gift boxes with arrows there and back, on butter
  20 PurrfectStreak five gold footprints walking up to a star, on lilac
  21 PartyGuest     Cafe Party Guest (live-events.md section 2e): a strawberry-cream cat in a pink party hat under a string of
                    bunting, with confetti, on sky blue
  22 MetOwner       Met the Owner (#3324): Blossom (Legendary) in a little gold crown waving a raised paw, with
                    wave marks and a twinkle, on sky blue

Built in Blender axes (x right, -y toward the camera, z up), the medal's face in the XZ plane; nothing here is a game
model.
"""

import math

from mathutils import Vector

from common import Builder
from icon_compose import place
import gold
from store_icons import _cat, _heart, _paw, _star, _twinkle

X = (math.radians(90), "X")
R = 2.0                      # the medal's outer radius; every picture stays inside R - 0.25
VIEW = (-10.0, 8.0)          # a little from the left and above, so the pictures read as solid


def _medal(b, field):
    """The round medal every badge shares: a gold rim and back, the pastel field, a thin cream ring inside."""
    b.cyl((0, 0.12, 0), R, 0.2, "gold_dark", segments=48, rot=X)                       # the back
    b.ring((0, 0.0, 0), R, 0.24, 0.16, "gold_mid", segments=48, rot=X)                 # the rim
    b.cyl((0, 0.03, 0), R - 0.2, 0.1, field, segments=48, rot=X)                       # the field
    b.ring((0, -0.03, 0), R - 0.38, 0.06, 0.04, "cream", segments=48, rot=X)           # a thin cream ring


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_Badge_" + name, mat)]


def welcome(mat):
    """The cafe front: mint walls, a gable roof, a pink and white striped awning, an arched pink door, a mat."""
    b = Builder()
    _medal(b, "pastel_sky")
    y = -0.2
    b.box((0, y, -0.1), (2.0, 0.3, 1.7), "mint", bevel=False)                                  # the walls
    b.box((0, y + 0.02, -0.92), (2.1, 0.34, 0.08), "offwhite", bevel=False)                     # the base
    roof = [(-1.25, 0.0), (1.25, 0.0), (0.0, 0.8)]
    b.prism((0, y + 0.02, 0.75), roof, 0.36, "bowl_red", rot=X)                                  # the roof
    b.prism((0, y - 0.1, 0.81), [(-0.95, 0.0), (0.95, 0.0), (0.0, 0.6)], 0.2, "mint", rot=X)   # the gable
    b.cyl((0, y - 0.2, 1.07), 0.16, 0.06, "offwhite", segments=16, rot=X)                       # a round window
    b.cyl((0, y - 0.23, 1.07), 0.1, 0.04, "pastel_sky", segments=16, rot=X)
    for k in range(6):                                                                         # the awning
        sw = "apron_pink" if k % 2 == 0 else "offwhite"
        x = -0.875 + 0.35 * k
        b.box((x, y - 0.32, 0.56), (0.35, 0.36, 0.2), sw, bevel=False, rot=(math.radians(-24), "X"))
        b.cyl((x, y - 0.5, 0.4), 0.175, 0.12, sw, segments=12, rot=X)                         # its scallops
    b.box((0, y - 0.18, -0.5), (0.66, 0.08, 0.8), "apron_pink", bevel=False)                    # the door frame
    b.cyl((0, y - 0.18, -0.1), 0.33, 0.08, "apron_pink", segments=20, rot=X)
    b.box((0, y - 0.22, -0.53), (0.48, 0.08, 0.74), "caramel_wood", bevel=False)                # the door
    b.cyl((0, y - 0.22, -0.16), 0.24, 0.08, "caramel_wood", segments=20, rot=X)
    b.cyl((0.14, y - 0.28, -0.5), 0.05, 0.06, "brass", segments=10, rot=X)                      # its knob
    for sx in (-1, 1):                                                                         # two windows
        b.box((sx * 0.68, y - 0.17, -0.25), (0.5, 0.06, 0.55), "offwhite", bevel=False)
        b.box((sx * 0.68, y - 0.2, -0.25), (0.4, 0.04, 0.45), "pastel_sky", bevel=False)
        b.box((sx * 0.68, y - 0.23, -0.25), (0.04, 0.03, 0.45), "offwhite", bevel=False)
    b.box((0, y - 0.45, -0.97), (0.8, 0.5, 0.06), "apron_pink", bevel=False)                    # the welcome mat
    _paw(b, 0, y - 0.72, -0.8, 0.5, "cream")
    return _fin(b, "Welcome", mat)


def first_catch(mat):
    """A ginger cat sitting inside the hoop of a catching net, its pole running off to the lower right."""
    b = Builder()
    _medal(b, "mint")
    hc, hr = (-0.1, -0.12, 0.2), 1.12                                                         # the hoop, behind the cat
    for th in (math.radians(45), math.radians(-45)):                                          # the netting
        n = Vector((-math.sin(th), 0, math.cos(th)))
        for k in range(-4, 5):
            d = 0.24 * k
            L = 2 * math.sqrt(max(hr * hr - d * d, 0.0))
            c = Vector(hc) + n * d + Vector((0, 0.02, 0))
            b.box(tuple(c), (L, 0.03, 0.035), "offwhite", bevel=False, rot=(-th, "Y"))
    b.ring(hc, hr + 0.08, 0.12, 0.14, "caramel_wood", segments=32, rot=X)                      # the hoop
    a = math.radians(-40)
    p0 = (hc[0] + (hr + 0.04) * math.cos(a), hc[2] + (hr + 0.04) * math.sin(a))
    L = 0.75
    b.box((p0[0] + L / 2 * math.cos(a), hc[1], p0[1] + L / 2 * math.sin(a)), (L, 0.12, 0.13), "caramel_wood",
          rot=(-a, "Y"))                                                                       # the pole
    b.box((p0[0] + (L - 0.14) * math.cos(a), hc[1] - 0.01, p0[1] + (L - 0.14) * math.sin(a)), (0.28, 0.15, 0.16),
          "dark_wood", rot=(-a, "Y"))                                                          # its grip
    cat = place(_cat("Ginger", mat), at=(-0.1, -0.5, -0.85), scale=1.05, yaw=-14)
    _twinkle(b, 1.05, -0.3, 1.2, 0.36)
    return _fin(b, "FirstCatch", mat) + cat


def cozy_cafe(mat):
    """A big cream mug of cocoa with a pink band, a paw drawn in the foam and three curls of steam."""
    b = Builder()
    _medal(b, "blush")
    y = -0.6
    b.cyl((0, y + 0.05, -1.05), 1.05, 0.1, "offwhite", segments=32, scale=(1, 0.5, 1))           # the saucer
    b.cyl((0, y, -0.35), 0.72, 1.3, "cream", segments=32, radius2=0.78)                          # the mug
    b.cyl((0, y, -0.45), 0.75, 0.24, "apron_pink", segments=32, radius2=0.765)                   # its band
    b.cyl((0, y, 0.31), 0.7, 0.04, "choco", segments=32)                                         # the cocoa
    b.cyl((0, y, 0.33), 0.56, 0.04, "milk", segments=28)                                         # the foam
    for (dx, dy) in ((0.0, 0.0), (-0.13, 0.1), (-0.05, 0.17), (0.05, 0.17), (0.13, 0.1)):         # a paw in the foam
        r = 0.16 if dx == 0 and dy == 0 else 0.065
        b.cyl((dx * 1.5, y - 0.05 + dy * 1.5 - 0.1, 0.35), r, 0.03, "choco", segments=12)
    b.ring((0.78, y, -0.3), 0.36, 0.11, 0.16, "cream", segments=16, rot=X)                      # the handle
    for k, x in enumerate((-0.36, 0.0, 0.36)):                                                 # steam curls
        for j in range(14):
            t = j / 13
            b.sphere((x + 0.13 * math.sin(t * math.pi * 2.0 + k * 1.3), y + 0.2, 0.62 + (0.75 + 0.1 * (k == 1)) * t),
                     0.075 * (1 - 0.45 * t), "offwhite", segments=8, rings=5)
    return _fin(b, "CozyCafe", mat)


def grand_opening(mat):
    """The red ribbon across the medal with a big bow, and a pair of gold scissors about to snip it."""
    b = Builder()
    _medal(b, "pastel_butter")
    y = -0.15
    for k in range(10):                                                                        # the ribbon
        x0, x1 = -1.75 + 0.35 * k, -1.75 + 0.35 * (k + 1)
        z0, z1 = 0.1 - 0.35 * (1 - (x0 / 1.75) ** 2), 0.1 - 0.35 * (1 - (x1 / 1.75) ** 2)
        b.box(((x0 + x1) / 2, y - 0.004 * (k % 2), (z0 + z1) / 2), (math.hypot(x1 - x0, z1 - z0) + 0.04, 0.06, 0.32),
              "shirt_red", bevel=False, rot=(-math.atan2(z1 - z0, x1 - x0), "Y"))
    by = y - 0.12                                                                              # the bow
    for sx in (-1, 1):
        for dz, a, L in ((0.18, 28, 0.85), (-0.15, -22, 0.75)):
            b.box((sx * 0.36, by, -0.25 + dz), (L, 0.12, 0.28), "shirt_red", bevel=False,
                  rot=(math.radians(-sx * a), "Y"))
        b.box((sx * 0.76, by - 0.01, -0.25 + 0.02), (0.12, 0.13, 0.55), "shirt_red", bevel=False)
        b.box((sx * 0.3, by + 0.02, -0.85), (0.22, 0.06, 0.9), "shirt_red", bevel=False,
              rot=(math.radians(sx * 16), "Y"))                                                # its tails
        b.prism((sx * 0.43, by + 0.02, -1.32), [(-0.11, 0.0), (0.11, 0.0), (0.0, 0.12)], 0.06, "pastel_butter",
                rot=(math.radians(90), "X"))
    b.box((0, by - 0.06, -0.24), (0.42, 0.16, 0.4), "bowl_red", bevel=False)                   # the knot
    sy, cx, cz, L = -0.55, 0.55, 0.6, 0.95                                                     # the scissors, open
    for s, sw in ((1, "gold_light"), (-1, "gold_mid")):                                        # over the ribbon
        a = math.radians(-43 + s * 22)
        u, n = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
        pts = [(-L / 2 * u[0] + w * n[0], -L / 2 * u[1] + w * n[1]) for w in (-0.11, 0.11)] + [(L / 2 * u[0], L / 2 * u[1])]
        pts = [pts[0], pts[2], pts[1]] if s > 0 else [pts[1], pts[2], pts[0]]
        b.prism((cx + L / 2 * u[0], sy - 0.03 * s, cz + L / 2 * u[1]), pts, 0.05, sw, rot=X)  # a blade
        ha = a + math.pi
        hc = (cx + 0.62 * math.cos(ha), cz + 0.62 * math.sin(ha))
        b.ring((hc[0], sy - 0.03 * s, hc[1]), 0.21, 0.08, 0.08, "royal_berry", segments=16, rot=X)  # a handle
        b.box(((cx + hc[0]) / 2 - 0.1 * math.cos(ha), sy - 0.03 * s, (cz + hc[1]) / 2 - 0.1 * math.sin(ha)),
              (0.28, 0.05, 0.1), sw, bevel=False, rot=(-ha, "Y"))
    b.cyl((cx, sy - 0.08, cz), 0.07, 0.06, "gold_dark", segments=10, rot=X)                    # the pivot
    _twinkle(b, -1.0, -0.3, 0.95, 0.4)
    return _fin(b, "GrandOpening", mat)


def purrfect(mat):
    """A target of pink and cream rings with a gold paw print in the bullseye, and twinkles."""
    b = Builder()
    _medal(b, "pastel_lilac")
    y = -0.06
    for k, (r, sw) in enumerate(((1.35, "apron_pink"), (1.05, "cream"), (0.75, "apron_pink"), (0.45, "cream"))):
        b.cyl((0, y - 0.05 * k, -0.05), r, 0.06, sw, segments=40, rot=X)
    _paw(b, 0, y - 0.3, -0.03, 1.05, "gold_mid")
    _paw(b, 0, y - 0.24, -0.03, 1.2, "gold_dark")
    _twinkle(b, 1.05, -0.4, 0.95, 0.5)
    _twinkle(b, -1.15, -0.4, -0.75, 0.35)
    _twinkle(b, -0.95, -0.4, 1.05, 0.25, "gold_light")
    return _fin(b, "Purrfect", mat)


def _sitter(mat, name, at=(0.0, -0.5, -0.85), scale=1.05, yaw=-14, gilded=False):
    """A roster cat sitting (body B) in front of the medal; `gilded` for its gold coat (gold.py)."""
    objs = gold.build_gold(name, mat, body="sit") if gilded else _cat(name, mat)
    return place(objs, at=at, scale=scale, yaw=yaw)


def _arc(b, cx, cz, r, a0, a1, w, d, y, sw, n=16, k0=0):
    """A band of boxes along a circle in the medal's plane, from angle a0 to a1 (degrees)."""
    for k in range(n):
        t0, t1 = math.radians(a0 + (a1 - a0) * k / n), math.radians(a0 + (a1 - a0) * (k + 1) / n)
        tm = (t0 + t1) / 2
        L = 2 * r * math.sin(abs(t1 - t0) / 2) + 0.03
        b.box((cx + r * math.cos(tm), y - 0.003 * ((k + k0) % 2), cz + r * math.sin(tm)), (L, d, w), sw, bevel=False,
              rot=(-(tm + math.pi / 2), "Y"))


def bait_cat(mat):
    """A tabby sitting beside a red food bowl heaped with kibble, a little heart over her head."""
    b = Builder()
    _medal(b, "pastel_butter")
    bx, by, bz = 0.68, -0.75, -0.95
    b.cyl((bx, by, bz + 0.18), 0.5, 0.36, "bowl_red", segments=28, radius2=0.62)              # the bowl
    b.cyl((bx, by, bz + 0.37), 0.6, 0.04, "shirt_red", segments=28)                           # its rim
    for k in range(9):                                                                        # the kibble heap
        a = 2 * math.pi * k / 9
        r = 0.3 if k % 2 else 0.18
        b.ico((bx + r * math.cos(a), by + 0.15 * math.sin(a), bz + 0.43 + 0.05 * (k % 3)), 0.11, "kibble")
    b.ico((bx, by, bz + 0.55), 0.12, "kibble")
    b.prism((-0.4, -0.45, 1.15), _heart(0.32), 0.08, "apron_pink", rot=X)
    return _fin(b, "BaitCat", mat) + _sitter(mat, "Tabby", at=(-0.4, -0.45, -0.9), scale=1.0, yaw=-24)


def _find(mat, key, field, star, cat, scale=1.0):
    """The rarity finds: a roster cat of that rarity sitting in front of a big star of the rarity's colour."""
    b = Builder()
    _medal(b, field)
    b.star((0, -0.08, 0.05), 1.55, 0.78, 0.08, star, rot=X)
    b.star((0, -0.12, 0.05), 1.3, 0.62, 0.04, "offwhite" if field != "night_sky" else "gold_light", rot=X)
    b.star((0, -0.15, 0.05), 1.18, 0.56, 0.04, star, rot=X)
    _twinkle(b, 1.1, -0.4, 1.05, 0.4, "offwhite")
    _twinkle(b, -1.15, -0.4, -0.55, 0.3, "offwhite")
    return _fin(b, key, mat) + _sitter(mat, cat, at=(0.0, -0.6, -0.95), scale=scale, yaw=-12)


def rare_find(mat):
    return _find(mat, "RareFind", "pastel_lilac", "rarity_epic", "Persian")


def legendary_find(mat):
    return _find(mat, "LegendaryFind", "pastel_butter", "rarity_legend", "Marshmallow")


def mythical_find(mat):
    return _find(mat, "MythicalFind", "night_sky", "rarity_mythic", "Comet")


def busy_cafe(mat):
    """A brass service bell on a little wooden block, ringing: ding lines either side."""
    b = Builder()
    _medal(b, "mint")
    y, z0 = -0.5, -0.95
    b.box((0, y, z0 + 0.14), (1.9, 0.9, 0.28), "caramel_wood")                                 # the block
    b.cyl((0, y, z0 + 0.34), 0.95, 0.12, "dark_wood", segments=32)                            # the bell's base
    n, R = 8, 0.82                                                                            # the dome
    for i in range(n):
        za, zb = R * i / n, R * (i + 1) / n
        b.cyl((0, y, z0 + 0.4 + (za + zb) / 2), R * math.sqrt(1 - (za / R) ** 2), zb - za + 0.004,
              "gold_mid", segments=28, radius2=R * math.sqrt(max(1 - (zb / R) ** 2, 0.04)))
    b.cyl((0, y, z0 + 1.3), 0.06, 0.24, "gold_dark", segments=10)                              # the plunger
    b.sphere((0, y, z0 + 1.43), 0.14, "gold_light", segments=12, rings=6)
    b.sphere((-0.3, y - 0.55, z0 + 0.85), 0.11, "gold_light", segments=10, rings=6, scale=(1, 0.4, 1.4))  # a shine
    for sx in (-1, 1):                                                                        # ding lines
        for k, (dz, L, a) in enumerate(((0.95, 0.5, 30), (0.55, 0.45, 0), (0.15, 0.4, -30))):
            r = 1.15
            t = math.radians(a)
            b.box((sx * (r + 0.2) * math.cos(t) * 1.0, y, z0 + 0.6 + (r * math.sin(t))), (L, 0.06, 0.11), "offwhite",
                  bevel=False, rot=(-sx * t, "Y"))
    return _fin(b, "BusyCafe", mat)


def famous_cafe(mat):
    """Five gold stars in an arc over a big pink heart: everyone loves the cafe."""
    b = Builder()
    _medal(b, "pastel_sky")
    b.prism((0, -0.2, -0.45), _heart(1.0), 0.18, "apron_pink", rot=X)
    b.prism((0, -0.3, -0.42), _heart(0.78), 0.06, "blush", rot=X)
    _paw(b, 0, -0.36, -0.5, 1.0, "cream")
    for k in range(5):
        a = math.radians(150 - 30 * k)
        _star(b, 1.15 * math.cos(a), -0.35, 0.05 + 1.0 * math.sin(a), 0.36 if k == 2 else 0.3, "gold_mid")
    return _fin(b, "FamousCafe", mat)


def grand_cafe(mat):
    """A gold crown with berry and mint gems, on velvet."""
    b = Builder()
    _medal(b, "velvet_lilac")
    y = -0.4
    b.box((0, y, -0.58), (2.3, 0.5, 0.6), "gold_mid")                                          # the band
    b.box((0, y - 0.27, -0.55), (2.1, 0.06, 0.12), "gold_dark", bevel=False)
    for x, h, w in ((-0.95, 0.75, 0.3), (-0.48, 0.95, 0.34), (0.0, 1.2, 0.4), (0.48, 0.95, 0.34),
                    (0.95, 0.75, 0.3)):                                                       # the points
        b.prism((x, y + 0.02, -0.3), [(-w, 0.0), (w, 0.0), (0.0, h)], 0.36, "gold_mid", rot=X)
        b.ico((x, y - 0.05, -0.3 + h + 0.08), 0.12 if x else 0.15, "gold_light" if x else "royal_berry")
    for k, x in enumerate((-0.7, 0.0, 0.7)):                                                  # gems on the band
        b.ico((x, y - 0.3, -0.55), 0.17 if k == 1 else 0.13, "royal_berry" if k == 1 else "mint",
              scale=(1, 0.6, 1))
    _twinkle(b, 1.1, -0.5, 0.95, 0.4)
    _twinkle(b, -1.15, -0.5, -1.05, 0.3)
    return _fin(b, "GrandCafe", mat)


def cat_collector(mat):
    """The open cat Index: two pages of little cat stamps, a paw ribbon down the middle."""
    b = Builder()
    _medal(b, "mint")
    y = -0.35
    for sx in (-1, 1):
        b.box((sx * 0.68, y, -0.1), (1.3, 0.12, 1.6), "cream", bevel=False,
              rot=(math.radians(sx * 6), "Z"))                                                 # a page
        b.box((sx * 0.72, y + 0.08, -0.12), (1.38, 0.08, 1.7), "royal_berry", bevel=False,
              rot=(math.radians(sx * 6), "Z"))                                                 # the cover
        for r in range(3):
            for c in range(2):
                x, z = sx * (0.38 + 0.6 * c), 0.42 - 0.52 * r
                b.cyl((x, y - 0.14 + sx * 0.06 * (0.38 + 0.6 * c) * 0.1, z), 0.2, 0.04,
                      ("blush", "pastel_sky", "pastel_butter")[(r + c) % 3], segments=16, rot=X)
                _paw(b, x, y - 0.18, z, 0.45, "fur_charcoal")
    b.box((0.05, y - 0.15, -0.4), (0.16, 0.04, 1.6), "apron_pink", bevel=False)                # the ribbon
    b.prism((0.05, y - 0.15, -1.25), [(-0.08, 0.08), (0.08, 0.08), (0.0, -0.06)], 0.04, "apron_pink", rot=X)
    return _fin(b, "CatCollector", mat)


def cat_expert(mat):
    """A tuxedo cat in a scholar's cap with a gold tassel."""
    b = Builder()
    _medal(b, "pastel_sky")
    cat = _sitter(mat, "Tuxedo", at=(0.0, -0.5, -0.95), scale=1.0, yaw=-12)
    from store_icons import _top
    x, yy, z = _top(cat)
    b.cyl((x, yy, z + 0.02), 0.32, 0.22, "fur_charcoal", segments=16)                          # the cap
    b.box((x, yy, z + 0.16), (0.95, 0.95, 0.07), "fur_charcoal", bevel=False, rot=(math.radians(45), "Z"))
    b.cyl((x, yy, z + 0.21), 0.06, 0.04, "gold_mid", segments=8)
    b.box((x + 0.3, yy - 0.3, z + 0.18), (0.04, 0.5, 0.04), "gold_mid", bevel=False,
          rot=(math.radians(45), "Z"))
    b.box((x + 0.47, yy - 0.47, z - 0.05), (0.07, 0.07, 0.42), "gold_mid", bevel=False)        # the tassel
    b.cyl((x + 0.47, yy - 0.47, z - 0.3), 0.08, 0.12, "gold_light", segments=8)
    _star(b, 1.15, -0.4, 0.95, 0.35, "gold_mid")
    _star(b, -1.2, -0.4, 0.55, 0.25, "gold_mid")
    return _fin(b, "CatExpert", mat) + cat


def golden_coat(mat):
    """A gold tabby sitting, with twinkles all round."""
    b = Builder()
    _medal(b, "pastel_lilac")
    _twinkle(b, 1.0, -0.4, 0.95, 0.5, "gold_light")
    _twinkle(b, -1.1, -0.4, 0.45, 0.4, "offwhite")
    _twinkle(b, 1.15, -0.4, -0.45, 0.3, "offwhite")
    return _fin(b, "GoldenCoat", mat) + _sitter(mat, "Tabby", at=(0.0, -0.45, -1.0), scale=1.1, yaw=-14,
                                                gilded=True)


RAINBOW = ("bowl_red", "fur_orange", "pastel_butter", "leaf_green", "pastel_sky", "aurora_violet")


def rainbow_coat(mat):
    """A white cat sitting under a rainbow, little clouds at its feet."""
    b = Builder()
    _medal(b, "pastel_sky")
    for k, sw in enumerate(RAINBOW):
        _arc(b, 0, -0.55, 1.45 - 0.17 * k, 0, 180, 0.17, 0.08, -0.12 - 0.01 * k, sw, n=18, k0=k)
    for sx in (-1, 1):                                                                        # clouds
        for dx, dz, r in ((0.0, 0.0, 0.26), (0.24, 0.05, 0.2), (-0.22, 0.04, 0.19), (0.1, 0.2, 0.18)):
            b.sphere((sx * 1.28 + dx, -0.3, -0.62 + dz), r, "offwhite", segments=12, rings=8)
    return _fin(b, "RainbowCoat", mat) + _sitter(mat, "Snow", at=(0.0, -0.5, -1.0), scale=0.95, yaw=-12)


def page_complete(mat):
    """An Index page with every stamp filled in and a big green tick."""
    b = Builder()
    _medal(b, "blush")
    y = -0.3
    b.box((0, y, 0.0), (1.9, 0.1, 2.3), "cream", bevel=False, rot=(math.radians(-5), "Y"))       # the page
    b.box((0.05, y + 0.06, -0.04), (1.9, 0.06, 2.3), "treat_tan", bevel=False, rot=(math.radians(-5), "Y"))
    for r in range(3):
        for c in range(3):
            x, z = -0.56 + 0.56 * c, 0.6 - 0.56 * r
            b.cyl((x, y - 0.07, z), 0.21, 0.04, ("pastel_sky", "mint", "pastel_butter")[(r + c) % 3], segments=16,
                  rot=X)
            _paw(b, x, y - 0.1, z, 0.45, "fur_charcoal")
    tk = [(-0.85, -0.45), (-0.45, -0.85), (0.6, 0.25)]                                         # the tick
    for k, ((x0, z0), (x1, z1)) in enumerate(zip(tk, tk[1:])):
        L = math.hypot(x1 - x0, z1 - z0)
        b.box(((x0 + x1) / 2 + 0.1, y - 0.25 - 0.03 * k, (z0 + z1) / 2 - 0.35), (L + 0.22, 0.12, 0.28), "leaf_green",
              bevel=False,
              rot=(-math.atan2(z1 - z0, x1 - x0), "Y"))
    return _fin(b, "PageComplete", mat)


def helping_paw(mat):
    """Two paws meeting in a high five over a pink heart."""
    b = Builder()
    _medal(b, "mint")
    b.prism((0, -0.15, -0.35), _heart(0.95), 0.12, "apron_pink", rot=X)
    for sx, sw, a in ((-1, "cream", -18), (1, "fur_orange", 18)):
        x, z = sx * 0.55, 0.35
        lx, lz = sx * 1.05, -1.2
        L = math.hypot(x - lx, z - lz) - 0.15
        ux, uz = (x - lx) / (L + 0.15), (z - lz) / (L + 0.15)
        b.box((lx + ux * L / 2, -0.27, lz + uz * L / 2), (0.46, 0.22, L), sw,
              rot=(math.atan2(x - lx, z - lz), "Y"))                                         # a foreleg
        b.cyl((x, -0.35, z), 0.36, 0.3, sw, segments=20, rot=X)                                    # the paw
        b.cyl((x, -0.52, z - 0.06), 0.17, 0.04, "nose_pink", segments=12, rot=X)                   # its pad
        for dx, dz in ((-0.17, 0.15), (-0.06, 0.24), (0.06, 0.24), (0.17, 0.15)):
            b.cyl((x + dx, -0.52, z + dz), 0.06, 0.04, "nose_pink", segments=8, rot=X)
    _twinkle(b, 0, -0.6, 1.05, 0.45)
    return _fin(b, "HelpingPaw", mat)


def _box_gift(b, x, z, s, body, ribbon):
    b.box((x, -0.4, z), (0.9 * s, 0.7 * s, 0.8 * s), body)
    b.box((x, -0.4, z + 0.45 * s), (1.0 * s, 0.8 * s, 0.18 * s), body)
    b.box((x, -0.4, z + 0.05 * s), (0.16 * s, 0.74 * s, 1.0 * s), ribbon, bevel=False)
    for sx in (-1, 1):
        b.box((x + sx * 0.18 * s, -0.4, z + 0.66 * s), (0.34 * s, 0.14 * s, 0.22 * s), ribbon, bevel=False,
              rot=(math.radians(sx * -30), "Y"))


def first_trade(mat):
    """Two gift boxes swapping places: a pink one and a mint one with curved arrows between."""
    b = Builder()
    _medal(b, "pastel_butter")
    _box_gift(b, -0.75, -0.75, 0.95, "apron_pink", "cream")
    _box_gift(b, 0.75, -0.75, 0.95, "mint", "cream")
    for r, a0, a1, sw in ((0.95, 160, 20, "royal_berry"), (0.55, 20, 160, "sign_teal")):  # there and back
        _arc(b, 0, 0.0, r, a0, a1, 0.16, 0.08, -0.55, sw, n=10)
        end = (r * math.cos(math.radians(a1)), r * math.sin(math.radians(a1)))
        b.prism((end[0], -0.55, end[1] - 0.05), [(-0.22, 0.12), (0.22, 0.12), (0.0, -0.2)], 0.08, sw, rot=X)
    return _fin(b, "FirstTrade", mat)


def purrfect_streak(mat):
    """Five gold paw prints climbing an arc to a big star."""
    b = Builder()
    _medal(b, "pastel_lilac")
    for k in range(5):                                                                        # footprints
        side = 0.13 if k % 2 else -0.13
        _paw(b, -1.05 + 0.4 * k - side, -0.3 - 0.01 * k, -0.95 + 0.3 * k + side, 0.78 + 0.07 * k, "gold_mid")
    _star(b, 0.88, -0.35, 0.85, 0.45, "gold_mid")
    _twinkle(b, -1.05, -0.45, 0.95, 0.4)
    return _fin(b, "PurrfectStreak", mat)


def party_guest(mat):
    """Cafe Party Guest: a strawberry-cream cat in a pink party hat under a swag of bunting, with confetti all round."""
    b = Builder()
    _medal(b, "pastel_sky")
    y, ends, top, sag = -0.2, 1.18, 1.12, 0.26                                               # the bunting
    flags = ("rarity_mythic", "pastel_butter", "sign_teal", "bowl_red", "aurora_violet", "leaf_green")
    n = 7

    def at(t):
        return -ends + 2 * ends * t, top - sag * (1 - (2 * t - 1) ** 2)

    for k in range(16):
        (x0, z0), (x1, z1) = at(k / 16), at((k + 1) / 16)
        b.box(((x0 + x1) / 2, y, (z0 + z1) / 2), (math.hypot(x1 - x0, z1 - z0) + 0.03, 0.05, 0.06), "dark_wood",
              bevel=False, rot=(-math.atan2(z1 - z0, x1 - x0), "Y"))
    for k in range(n):
        x, z = at((k + 0.5) / n)
        b.prism((x, y - 0.03, z - 0.02), [(-0.2, 0.0), (0.2, 0.0), (0.0, -0.44)], 0.07, flags[k % len(flags)], rot=X)
    for x, z, a, sw in ((-1.3, 0.2, 30, "rarity_mythic"), (-1.0, -0.3, -20, "pastel_butter"),
                        (-1.38, -0.62, 55, "sign_teal"), (1.28, 0.3, -35, "bowl_red"), (1.02, -0.18, 15, "leaf_green"),
                        (1.32, -0.6, 60, "aurora_violet"), (1.12, -1.0, 25, "pastel_butter"),
                        (-1.12, -1.02, -45, "bowl_red")):                                      # confetti
        b.box((x, -0.45, z), (0.26, 0.06, 0.12), sw, bevel=False, rot=(math.radians(a), "Y"))
    cat = _sitter(mat, "Cream", at=(0.0, -0.5, -1.05), scale=0.95, yaw=-14)
    from store_icons import _top
    x, yy, z = _top(cat)
    tilt, h, r0 = math.radians(-12), 0.78, 0.3                                                # the party hat
    ux, uz = math.sin(tilt), math.cos(tilt)                                                   # its axis
    bx, bz = x - 0.05, z - 0.12                                                               # its base

    def on(f):
        return (bx + ux * h * f, yy, bz + uz * h * f)

    b.cyl(on(0.5), r0, h, "rarity_mythic", segments=20, radius2=0.03, rot=(tilt, "Y"))
    for f in (0.2, 0.5):                                                                      # its stripes
        r = r0 + (0.03 - r0) * f + 0.02
        b.cyl(on(f), r, 0.08, "pastel_butter", segments=20, radius2=r - 0.03, rot=(tilt, "Y"))
    b.sphere(on(1.0), 0.12, "pastel_butter")                                                  # the pompom
    _twinkle(b, 0.95, -0.6, 0.15, 0.3)
    return _fin(b, "PartyGuest", mat) + cat


def met_owner(mat):
    """Met the Owner: Blossom in a little gold crown with a berry gem, waving her raised right paw (the viewer's
    left), with wave marks by the paw and a twinkle."""
    b = Builder()
    _medal(b, "pastel_sky")
    cat = _sitter(mat, "Blossom", at=(0.2, -0.5, -1.0), scale=0.95, yaw=-12)
    from store_icons import _top
    import bpy
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for ob in cat for c in ob.bound_box]
    x0 = min(p.x for p in pts)
    x, yy, z = _top(cat)
    z -= 0.2                                                                                  # down between the ears
    cy = min(p.y for p in pts)                                                                # the cat's front
    y = cy + 0.25
    # the crown: a gold band with five points, gems at the tips and a berry gem in the middle
    b.cyl((x, yy, z + 0.08), 0.36, 0.18, "gold_mid", segments=20)
    for k in range(5):
        a = math.radians(-90 + 72 * k)
        px, py = x + 0.3 * math.cos(a), yy + 0.3 * math.sin(a)
        b.cyl((px, py, z + 0.28), 0.1, 0.24, "gold_mid", segments=8, radius2=0.02)
        b.ico((px, py, z + 0.42), 0.055, "gold_light")
    b.ico((x, yy - 0.37, z + 0.08), 0.09, "royal_berry", scale=(1, 0.6, 1))
    # the waving paw: a foreleg raised from the shoulder, tilted out, with a round paw and pink pads
    sx, sz = x0 + 0.25, z - 0.65                                                             # the shoulder
    px, pz = x0 - 0.3, z + 0.15                                                              # the paw
    L = math.hypot(px - sx, pz - sz)
    b.box(((sx + px) / 2, y, (sz + pz) / 2), (0.3, 0.26, L), "fur_rose",
          rot=(math.atan2(px - sx, pz - sz), "Y"))
    b.cyl((px, y - 0.04, pz), 0.24, 0.26, "fur_white", segments=20, rot=X)
    b.cyl((px, y - 0.18, pz - 0.04), 0.11, 0.04, "nose_pink", segments=12, rot=X)
    for dx, dz in ((-0.12, 0.1), (-0.04, 0.16), (0.05, 0.16), (0.13, 0.1)):
        b.cyl((px + dx, y - 0.18, pz + dz), 0.04, 0.04, "nose_pink", segments=8, rot=X)
    for r in (0.45, 0.65):                                                                    # wave marks
        _arc(b, px, pz, r, 120, 200, 0.07, 0.05, y - 0.1, "offwhite", n=5)
    _twinkle(b, 1.15, -0.45, 0.9, 0.38)
    _twinkle(b, 0.75, -0.45, 1.35, 0.22)
    return _fin(b, "MetOwner", mat) + cat


# name -> builder, in the spec's creation order (release.md section 1)
BADGES = {"Welcome": welcome, "FirstCatch": first_catch, "CozyCafe": cozy_cafe, "GrandOpening": grand_opening,
          "Purrfect": purrfect, "BaitCat": bait_cat, "RareFind": rare_find, "LegendaryFind": legendary_find,
          "MythicalFind": mythical_find, "BusyCafe": busy_cafe, "FamousCafe": famous_cafe, "GrandCafe": grand_cafe,
          "CatCollector": cat_collector, "CatExpert": cat_expert, "GoldenCoat": golden_coat,
          "RainbowCoat": rainbow_coat, "PageComplete": page_complete, "HelpingPaw": helping_paw,
          "FirstTrade": first_trade, "PurrfectStreak": purrfect_streak, "PartyGuest": party_guest,
          "MetOwner": met_owner}
