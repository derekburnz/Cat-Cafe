"""Roblox badge pictures (#1934, docs/design/cat-cafe/release.md section 1), rendered by icons.py as
CatCafe_Icon_Badge_<Name> (transparent, outlined, 512 px). Roblox crops badge icons to a circle, so every badge is the
same round medal that fills that crop (icons.STORE_FIT): a gold rim, a pastel field with a thin cream ring, and one
simple picture standing out in front of it. Every picture stays inside the medal, so all 20 frame the same way.

The order is the spec's creation order (5 badges a day from 2026-11-07):
   1 Welcome        Welcome to the Cafe: the little cafe front, mint walls, a pink and white awning, an arched door
                    and a welcome mat, on sky blue
   2 FirstCatch     First Catch: a ginger cat sitting inside the hoop of a catching net, on mint
   3 CozyCafe       Cozy Cafe (Tier 2): a big cream mug of cocoa with a paw in the foam and curls of steam, on blush
   4 GrandOpening   Grand Opening: the red ribbon with its big bow, and gold scissors about to snip it, on butter
   5 Purrfect       Purrfect!: a pink and cream target with a gold paw print in the bullseye and twinkles, on lilac

Built in Blender axes (x right, -y toward the camera, z up), the medal's face in the XZ plane; nothing here is a game
model.
"""

import math

from mathutils import Vector

from common import Builder
from icon_compose import place
from store_icons import _cat, _paw, _twinkle

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


# name -> builder, in the spec's creation order (release.md section 1)
BADGES = {"Welcome": welcome, "FirstCatch": first_catch, "CozyCafe": cozy_cafe, "GrandOpening": grand_opening,
          "Purrfect": purrfect}
