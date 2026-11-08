"""Walk-up ring icons (#2449, Derek2 2026-11-08): a flat, cute picture lying inside each station's walk-up floor ring,
in the style of the Codes Cat's paw-stamped ticket (stations._circle). One per station; the cannon gets none.

  CatCafe_Street_SpinWheel_RingIcon_Decor    the Spin Wheel: a carnival wheel with a gold rim, eight bulbs round it,
                                             four spokes, a pointer at the top and a paw on the hub
  CatCafe_Street_FishMarket_RingIcon_Decor   the Fish Market: a plump gold fish with a forked tail, a fin, scales
                                             and a big eye
  CatCafe_Street_CornerShop_RingIcon_Decor   the Corner Shop and the Day Cart: a pink shopping bag with a handle,
                                             a folded top and a paw on the front
  CatCafe_Street_DealerCart_RingIcon_Decor   the night market: an orange paper lantern with a warm glow, a cap, a handle
                                             ring and a little crescent moon beside it

Each is one Model of plain parts (not Neon, so a glowing ring does not wash it out), CanCollide, CanTouch and
CanQuery off (rbx_export: the `_RingIcon_Decor` suffix), no scripts. Flat: under 0.1 studs thick in all, a 0.04
base and two thin detail layers on top, each piece a hair higher than the last so no two faces share a plane. At most 4 x 4 studs across. Pivot at the centre of the bottom face; the picture's
top points +Z (away from a player walking in from the front, so it reads upright as they approach).
"""

import math

from common import RB
from plot import rot_y, rot_z

SPIN = "CatCafe_Street_SpinWheel_RingIcon_Decor"
FISH = "CatCafe_Street_FishMarket_RingIcon_Decor"
SHOP = "CatCafe_Street_CornerShop_RingIcon_Decor"
DEALER = "CatCafe_Street_DealerCart_RingIcon_Decor"
NAMES = (SPIN, FISH, SHOP, DEALER)

Y0, Y1, Y2, Y3 = 0.0, 0.04, 0.06, 0.075     # base, first detail layer, second detail layer tops
OUTLINE = 0.14                                # how far each dark outline shows past the fill
STEP = 0.0004                                 # each later piece's top sits this much higher, so no two tops share a
_k = [0]                                      # plane (Roblox would z-fight them, Blender's joined mesh shades black)


_off = [0.0, 0.0]                             # each build's shift, so its footprint centres on the pivot
FLIP = -1


def _top(y1):
    _k[0] += 1
    return y1 + STEP * _k[0]


def disc(b, x, z, r, y0, y1, swatch, segments=20):
    y1 = _top(y1)
    b.cyl((x + _off[0], (y0 + y1) / 2, z + _off[1]), r, y1 - y0, swatch, segments=segments)


def tri(b, x, z, w, d, y0, y1, swatch, turn=0.0):
    """A flat isosceles triangle in plan, its point toward -Z at turn 0, turned by `turn` degrees about Y, `w` across its base
    and `d` from base to point, centred on (x, z): two wedges laid on their sides, mirrored (a WedgePart's
    cross-section is a right triangle)."""
    y1 = _top(y1)
    a = math.radians(turn)
    for side in (-1, 1):
        ox = side * w / 4
        px, pz = ox * math.cos(a) + 0 * math.sin(a), -ox * math.sin(a)
        rot = rot_y(turn) @ rot_z(90 * side * FLIP)
        b.wedge((x + px + _off[0], (y0 + y1) / 2, z + pz + _off[1]), (y1 - y0, w / 2, d), swatch, rot=rot)


def flat_box(b, x, z, w, d, y0, y1, swatch, turn=0.0):
    y1 = _top(y1)
    b.box((x + _off[0], (y0 + y1) / 2, z + _off[1]), (w, y1 - y0, d), swatch, rot=rot_y(turn) if turn else None)


def paw(b, x, z, s, y0, y1, swatch, turn=0.0):
    """A paw print, toes toward +Z (turned by `turn`), `s` the pad's radius; the Codes Cat ticket's stamp."""
    disc(b, x, z - 0.25 * s / 0.55, s, y0, y1, swatch, segments=14)
    for dx, dz in ((-0.62, 0.38), (-0.22, 0.72), (0.22, 0.72), (0.62, 0.38)):
        a = math.radians(turn)
        rx = dx * math.cos(a) + dz * math.sin(a)
        rz = -dx * math.sin(a) + dz * math.cos(a)
        disc(b, x + rx * s / 0.55, z + rz * s / 0.55, 0.22 * s / 0.55, y0, y1, swatch, segments=10)


def build_spin(mat):
    """A carnival wheel 3.6 across: a gold rim with red and butter bulbs, a sky face, four teal spokes, a red hub
    with a white paw, and a red pointer over the top."""
    b = RB()
    _k[0], _off[:] = 0, (0.0, -0.11)
    R = 1.55
    disc(b, 0, -0.1, R + OUTLINE, Y0, Y1, "fur_ink", segments=24)                   # outline
    disc(b, 0, -0.1, R, Y0 + 0.01, Y1 + 0.005, "gold_mid", segments=24)              # rim
    disc(b, 0, -0.1, R - 0.3, Y1, Y2, "pastel_sky", segments=24)                     # the face
    for k in range(4):                                                                # spokes
        flat_box(b, 0, -0.1, 2 * (R - 0.32), 0.16, Y1, Y2 + 0.005, "sign_teal", turn=45 * k)
    for k in range(8):                                                                # bulbs on the rim
        a = math.radians(22.5 + 45 * k)
        disc(b, (R - 0.15) * math.sin(a), -0.1 + (R - 0.15) * math.cos(a), 0.13, Y1, Y2,
             "bowl_red" if k % 2 else "pastel_butter", segments=10)
    disc(b, 0, -0.1, 0.62, Y1, Y2 + 0.005, "bowl_red", segments=18)                 # hub
    paw(b, 0, -0.08, 0.24, Y2, Y3, "offwhite")
    tri(b, 0, R + 0.08, 0.7 + OUTLINE * 2, 0.62 + OUTLINE, Y0, Y2, "fur_ink", turn=0)     # pointer, tip down
    tri(b, 0, R + 0.12, 0.56, 0.5, Y0 + 0.01, Y2 + 0.01, "bowl_red", turn=0)
    return [b.finalize(SPIN, mat)]


def build_fish(mat):
    """A plump gold fish 3.6 long, its head toward -X: an oval body from overlapping discs, a forked tail, a dorsal fin,
    three scale arcs, a big eye and a smile line."""
    b = RB()
    _k[0], _off[:] = 0, (-0.20, -0.11)
    body = ((-0.35, 0, 1.0), (0.35, 0, 0.92), (-0.85, 0, 0.62), (0.85, 0, 0.6))
    for x, z, r in body:                                                              # outline
        disc(b, x, z, r + OUTLINE, Y0, Y1, "gold_dark", segments=22)
    tri(b, 1.55, 0.42, 0.95 + OUTLINE, 0.9 + OUTLINE, Y0, Y1, "gold_dark", turn=-60)    # tail outline
    tri(b, 1.55, -0.42, 0.95 + OUTLINE, 0.9 + OUTLINE, Y0, Y1, "gold_dark", turn=-120)
    tri(b, 0.05, 0.95, 1.0 + OUTLINE, 0.55 + OUTLINE, Y0, Y1, "gold_dark", turn=8)     # fin outline
    for x, z, r in body:
        disc(b, x, z, r, Y0 + 0.01, Y1 + 0.005, "gold_mid", segments=22)
    tri(b, 1.55, 0.42, 0.95, 0.9, Y0 + 0.01, Y1 + 0.005, "gold_mid", turn=-60)       # forked tail
    tri(b, 1.55, -0.42, 0.95, 0.9, Y0 + 0.01, Y1 + 0.005, "gold_mid", turn=-120)
    tri(b, 0.05, 0.95, 1.0, 0.55, Y0 + 0.01, Y1 + 0.005, "gold_light", turn=8)         # dorsal fin
    disc(b, -0.45, -0.38, 0.38, Y1, Y2, "gold_light", segments=16)                   # belly shine
    for k, x in enumerate((0.15, 0.6, 1.0)):                                          # scale arcs
        flat_box(b, x, 0.1, 0.12, 0.85 - 0.18 * k, Y1, Y2, "gold_dark", turn=0)
    disc(b, -0.95, 0.18, 0.3, Y1, Y2, "offwhite", segments=16)                      # eye
    disc(b, -1.02, 0.18, 0.16, Y2, Y3, "fur_ink", segments=12)
    disc(b, -1.07, 0.24, 0.05, Y2 + 0.005, Y3 + 0.005, "offwhite", segments=8)
    flat_box(b, -1.3, -0.3, 0.32, 0.09, Y1, Y2, "gold_dark", turn=-25)              # smile
    return [b.finalize(FISH, mat)]


def build_shop(mat):
    """A pink shopping bag 3.0 wide: a darker outline, a folded cream top band, a looping handle and a white paw on
    the front."""
    b = RB()
    _k[0], _off[:] = 0, (0.0, -0.08)
    w, d, zc = 2.5, 2.3, -0.35
    flat_box(b, 0, zc, w + 2 * OUTLINE, d + 2 * OUTLINE, Y0, Y1, "royal_berry")         # outline
    flat_box(b, 0, zc, w, d, Y0 + 0.01, Y1 + 0.005, "rarity_mythic")                    # bag
    top = zc + d / 2
    flat_box(b, 0, top - 0.22, w, 0.44, Y1, Y2, "cream")                                # folded top band
    for sx in (-1, 1):                                                                   # handle
        flat_box(b, sx * 0.55, top + 0.42, 0.18 + 2 * OUTLINE * 0.6, 0.95, Y0, Y1, "royal_berry")
    flat_box(b, 0, top + 0.82, 1.28 + 0.36, 0.18 + 2 * OUTLINE * 0.6, Y0, Y1, "royal_berry")
    for sx in (-1, 1):
        flat_box(b, sx * 0.55, top + 0.45, 0.18, 0.8, Y0 + 0.01, Y1 + 0.005, "gold_mid")
    flat_box(b, 0, top + 0.82, 1.28, 0.18, Y0 + 0.01, Y1 + 0.005, "gold_mid")
    paw(b, 0, zc - 0.15, 0.42, Y1, Y2, "offwhite")
    for sx in (-1, 1):                                                                   # side creases
        flat_box(b, sx * (w / 2 - 0.22), zc - 0.2, 0.08, d - 0.75, Y1, Y2, "fur_strawberry")
    return [b.finalize(SHOP, mat)]


def build_dealer(mat):
    """A paper lantern 2.4 wide with a crescent moon over its shoulder: a night-blue outline, a warm glowing body
    with ribs, a dark cap and base, a gold handle ring and a red tassel, and two star dots."""
    b = RB()
    _k[0], _off[:] = 0, (-0.24, 0.0)
    x0, zc = -0.35, -0.2
    for r, sw, ya, yb in ((1.05 + OUTLINE, "night_sky", Y0, Y1), (1.05, "fur_orange", Y0 + 0.01, Y1 + 0.005)):
        disc(b, x0, zc, r, ya, yb, sw, segments=22)
        flat_box(b, x0, zc, 2 * r - 0.2, 2 * (r - 0.25) + 0.6 * (r / 1.05), ya, yb, sw)    # a fat lantern shape
    disc(b, x0, zc, 0.6, Y1, Y2, "lamp_warm", segments=16)                          # the glow
    for dx in (-0.55, 0.0, 0.55):                                                     # ribs
        flat_box(b, x0 + dx, zc, 0.07, 2.0 - abs(dx) * 0.9, Y1, Y2, "fur_orange_dark")
    flat_box(b, x0, zc + 1.18, 1.3, 0.34, Y1 - 0.01, Y2 + 0.005, "fur_ink")           # cap
    flat_box(b, x0, zc - 1.18, 1.3, 0.34, Y1 - 0.01, Y2 + 0.005, "fur_ink")           # base
    flat_box(b, x0, zc + 1.52, 0.12, 0.34, Y0, Y1, "gold_mid")                        # hanger
    b.b.ring(RB.p(x0 + _off[0], (Y0 + Y1) / 2, zc + 1.88 + _off[1]), 0.26, 0.1, Y1 - Y0, "gold_mid", segments=14, bevel=False)
    flat_box(b, x0, zc - 1.47, 0.12, 0.22, Y0, Y1, "bowl_red")                         # tassel
    disc(b, x0, zc - 1.62, 0.13, Y0, Y1, "bowl_red", segments=10)
    # the crescent: a fat-to-thin chain of gold discs round an arc, horns up and down, opening left
    mx, mz, mr = 1.15, 0.95, 0.5
    for k in range(-4, 5):
        a = math.radians(22 * k)
        r = 0.27 * (1 - (abs(k) / 5.5) ** 1.6)
        disc(b, mx + mr * math.cos(a), mz + mr * math.sin(a), r + 0.08, Y0, Y1, "night_sky", segments=12)
    for k in range(-4, 5):
        a = math.radians(22 * k)
        r = 0.27 * (1 - (abs(k) / 5.5) ** 1.6)
        disc(b, mx + mr * math.cos(a), mz + mr * math.sin(a), r, Y0 + 0.01, Y2, "gold_mid", segments=12)
    for sx, sz, r in ((1.55, -0.2, 0.12), (1.2, -0.75, 0.09)):                         # two star dots
        disc(b, sx, sz, r, Y0, Y1, "pastel_butter", segments=8)
    return [b.finalize(DEALER, mat)]


ASSETS = {
    SPIN: (build_spin, 1500),
    FISH: (build_fish, 1500),
    SHOP: (build_shop, 1500),
    DEALER: (build_dealer, 1500),
}
