"""The Garden Nursery (#1200, lawn-nursery.md section 2): the lawn decor stall at the Park camp. A small wooden potting
stall under a leaf green and white striped awning, a GARDEN / NURSERY chalk sign over it, and on the potting bench
tiny copies of the lawn pieces it sells (a tulip pot, a gnome cat, a mini lamp post with a lit lantern) and a crate of
seed packets. The shelves behind hold potted plants, succulents and a trailing ivy. A copper and white gardener cat
in a straw sun hat and a green apron stands behind the bench on a hidden step, so the apron shows over it. At one end
a crate of seedlings, at the other a sack of potting soil and a teal watering can; ivy climbs the right post.

  CatCafe_Camp_Park_GardenNursery              bench, posts, back board, shelves, plants, awning, sign, crates and
                                               sack (collides), tagged LawnStall (rbx_export.TAGS), with an Attachment
                                               PromptAnchor in its PrimaryPart: the middle of the bench front, 3 up
  CatCafe_Camp_Park_GardenNursery_Bulb         the mini lamp post's lantern, lit at night
  CatCafe_Camp_Park_GardenNursery_Cat_<Piece>  the gardener, the same hinged pieces as a working (body S) cat without
                                               the held things; its sun hat (_Cat_Prop) rides inside the Head Model,
                                               and the Head part carries the Attachment BubbleAnchor over the hat for
                                               the speech bubble (cat-bubbles.md)

Pivot at the base centre on the camp's ground, the bench front (-Z) toward the players. Footprint about 10.4 x 4.2
studs, 8.1 tall. Its spot (SPOT) is in the Park's set space (Layout.campExtras' space, the long F85 Park): x 34, z -166,
turned 90 so the front faces -X, across the camp toward the landing pad, 12.5 past the Picnic Basket and clear of the
flower beds, the trees, the bench and the paths.
"""

import math

from mathutils import Matrix, Vector

import cats
import props
from alleyway import label
from common import RB, scale_mesh, text_width
from plot import rot_x, rot_y, rot_z

NAME = "CatCafe_Camp_Park_GardenNursery"
SPOT = (34.0, 0.0, -166.0, 90.0)                     # Park set space (x, y, z, turn about Y): front -X, to the pad
HW, C_FRONT, C_BACK, C_H = 3.2, -1.4, 0.0, 1.6       # the potting bench: half width, front, back, top
STEP_H, CAT_Z = 1.0, 0.85                            # the hidden step the cat stands on, and its pivot (Roblox z)
WALL_Z, WALL_TOP = 1.9, 5.6                          # the back board's front face and top
BW = 3.6                                             # the back board's and posts' half width
AWN_FRONT, AWN_Y = -1.75, 5.0                        # the awning's front edge (the posts)
VAL_H, STRIPES = 0.4, 9                              # its valance, and the stripes
PROMPT_ROBLOX = (0.0, 3.0, C_FRONT - 0.4)
BUBBLE_LIFT = 0.75                                   # over the ear tips, unscaled, as build_all's shop cats
AWNING = ("leaf_green", "offwhite")
WOOD, DARK, POT = "caramel_wood", "dark_wood", "terracotta"

# Copper and white with green eyes: no collectable cat wears this coat. A green apron (cats.ROSTER's apron flag) with
# leaf flecks, and the sun hat says gardener.
CAT = dict(rarity="Common", fur="fur_copper", second="fur_white", third="fur_white", eyes="eye_green",
           pattern="patches", muzzle="fur_white", nose="nose_brick", scale=1.5,
           apron=("shirt_green", ("leaf_dark", "leaf_green", "offwhite")))


# --------------------------------------------------------------------------------------------- small bits --
def _pot(b, x, y, z, r, h, sw=POT):
    """A flower pot standing at (x, y, z): a tapered six-sided pot with a rim, its top at y + h."""
    b.cyl((x, y + (h - 0.08) / 2, z), r, h - 0.08, sw, r2=r * 0.78, segments=6)
    b.cyl((x, y + h - 0.06, z), r * 1.12, 0.12, sw, segments=6)                     # rim (the plant hides the soil)
    return y + h


def _bush(b, x, y, z, r, sw="leaf_green", sw2="leaf_dark"):
    """A round leafy plant sitting in a pot whose soil is at y."""
    b.ball((x, y + r * 0.7, z), r, sw)
    b.box((x + r * 0.45, y + r * 1.2, z - r * 0.3), (r * 0.7, r * 0.18, r * 0.5), sw2, rot=rot_z(25))


def _tulip(b, x, y, z, h, sw, leaf=True):
    """One tulip: a stem from y, a leaf and a cup flower at y + h."""
    b.cyl((x, y + h / 2, z), 0.025, h, "leaf_dark", segments=4)
    if leaf:
        b.box((x + 0.05, y + h * 0.3, z), (0.06, h * 0.45, 0.03), "leaf_green", rot=rot_z(-20))
    b.cyl((x, y + h + 0.06, z), 0.07, 0.16, sw, r2=0.05, segments=5)


def _tulip_pot(b, x, y, z):
    """The Tulip Bed in little: a terracotta trough of red, pink and yellow tulips."""
    w, d, h = 0.9, 0.42, 0.3
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), POT)
    b.span((x - w / 2 - 0.04, y + h - 0.08, z - d / 2 - 0.04), (x + w / 2 + 0.04, y + h, z + d / 2 + 0.04), POT)
    b.span((x - w / 2 + 0.04, y + h, z - d / 2 + 0.04), (x + w / 2 - 0.04, y + h + 0.03, z + d / 2 - 0.04), "choco")
    for i, (dx, dz, hh) in enumerate(((-0.3, -0.06, 0.42), (-0.12, 0.08, 0.5), (0.06, -0.07, 0.46), (0.24, 0.06, 0.4),
                                      (0.33, -0.08, 0.36))):
        _tulip(b, x + dx, y + h + 0.03, z + dz, hh, ("shirt_red", "fur_bubblegum", "pastel_butter")[i % 3])


def _gnome_cat(b, x, y, z, s=1.0):
    """The Garden Gnome Cat in little: a sitting grey cat with a red pointy hat and a white beard, on a round base."""
    b.cyl((x, y + 0.03 * s, z), 0.24 * s, 0.06 * s, "leaf_green", segments=8)                 # grass base
    b.span((x - 0.15 * s, y + 0.05 * s, z - 0.12 * s), (x + 0.15 * s, y + 0.36 * s, z + 0.13 * s), "fur_grey")  # body
    b.span((x - 0.1 * s, y + 0.1 * s, z - 0.135 * s), (x + 0.1 * s, y + 0.3 * s, z - 0.11 * s), "shirt_blue")  # coat
    b.span((x - 0.14 * s, y + 0.35 * s, z - 0.12 * s), (x + 0.14 * s, y + 0.58 * s, z + 0.1 * s), "fur_grey")   # head
    b.ball((x, y + 0.36 * s, z - 0.13 * s), 0.1 * s, "offwhite", scale=(1.1, 0.9, 0.5))       # beard
    for sx in (-1, 1):                                                                        # ears, under the hat
        b.span((x + sx * 0.13 * s - 0.035 * s, y + 0.55 * s, z - 0.02 * s),
               (x + sx * 0.13 * s + 0.035 * s, y + 0.65 * s, z + 0.04 * s), "fur_grey")
        b.span((x + sx * 0.06 * s - 0.02 * s, y + 0.47 * s, z - 0.125 * s),
               (x + sx * 0.06 * s + 0.02 * s, y + 0.51 * s, z - 0.115 * s), "fur_black")       # eyes
    b.cyl((x, y + 0.75 * s, z - 0.01 * s), 0.15 * s, 0.38 * s, "shirt_red", r2=0.01, segments=8)  # hat


def _mini_lamp(b, bulb, x, y, z):
    """The Lamp Post in little: a dark post on a round foot with a lantern on top (its glass the _Bulb)."""
    b.cyl((x, y + 0.04, z), 0.16, 0.08, "fur_black", segments=8)
    b.cyl((x, y + 0.6, z), 0.035, 1.05, "fur_black", segments=6)
    b.span((x - 0.11, y + 1.12, z - 0.11), (x + 0.11, y + 1.15, z + 0.11), "fur_black")       # lantern floor
    bulb.span((x - 0.09, y + 1.15, z - 0.09), (x + 0.09, y + 1.37, z + 0.09), "lamp_warm")
    for sx in (-1, 1):                                                                       # its corner bars
        for sz in (-1, 1):
            b.span((x + sx * 0.1 - 0.015, y + 1.15, z + sz * 0.1 - 0.015),
                   (x + sx * 0.1 + 0.015, y + 1.37, z + sz * 0.1 + 0.015), "fur_black")
    b.cyl((x, y + 1.42, z), 0.14, 0.1, "fur_black", r2=0.03, segments=8)                     # cap


def _seed_crate(b, x, y, z):
    """A little crate of seed packets standing up, each a colour with a cream picture panel."""
    w, d, h = 0.8, 0.45, 0.22
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), WOOD)
    b.span((x - w / 2 - 0.01, y + 0.08, z - d / 2 - 0.01), (x + w / 2 + 0.01, y + 0.13, z + d / 2 + 0.01), DARK)
    for i, dx in enumerate((-0.27, -0.09, 0.09, 0.27)):
        sw = ("fur_strawberry", "pastel_butter", "mint", "pastel_lilac")[i]
        top = y + h + 0.16 + 0.03 * (i % 2)
        b.box((x + dx, (y + 0.06 + top) / 2, z + 0.02 * (i % 2)), (0.15, top - y - 0.06, 0.03), sw, rot=rot_z(4 - 3 * i))
        b.box((x + dx, top - 0.1, z - 0.02 + 0.02 * (i % 2)), (0.1, 0.08, 0.012), "cream", rot=rot_z(4 - 3 * i))


def _trowel(b, x, y, z):
    """A hand trowel lying on the bench: a metal blade and a wooden handle."""
    b.box((x, y + 0.02, z), (0.26, 0.04, 0.14), "metal", rot=rot_y(25))
    b.box((x + 0.24 * math.cos(math.radians(25)), y + 0.04, z + 0.24 * math.sin(math.radians(25))),
          (0.26, 0.07, 0.07), WOOD, rot=rot_y(25))


# ------------------------------------------------------------------------------------------------- bench --
def _bench(b):
    """The potting bench: planked wood, a dark top with a soil spill, and a painted flower panel on the front."""
    b.span((-HW, 0, C_FRONT), (HW, C_H - 0.12, C_BACK), WOOD)
    b.span((-HW - 0.04, 0, C_FRONT - 0.04), (HW + 0.04, 0.2, C_BACK + 0.04), DARK)                   # kick
    for y in (0.62, 1.05):                                                                        # plank lines
        b.span((-HW - 0.02, y - 0.03, C_FRONT - 0.02), (HW + 0.02, y + 0.03, C_BACK + 0.02), DARK)
    for sx in (-1, 1):                                                                            # end battens
        x0, x1 = sorted((sx * (HW - 0.18), sx * (HW + 0.03)))
        b.span((x0, 0.2, C_FRONT - 0.03), (x1, C_H - 0.12, C_FRONT + 0.01), DARK)
    # a cream panel on the front with a painted flower on it, over the plank lines
    pz = C_FRONT - 0.05
    b.span((-0.95, 0.32, pz), (0.95, 1.3, C_FRONT - 0.025), "cream")
    b.cyl((0, 0.86, pz - 0.01), 0.1, 0.02, "pastel_butter", axis="Z", segments=8)                   # the flower
    for k in range(6):
        a = math.radians(60 * k + 30)
        b.cyl((0.17 * math.cos(a), 0.86 + 0.17 * math.sin(a), pz - 0.005), 0.09, 0.02, "fur_bubblegum", axis="Z",
              segments=6)
    b.span((-0.02, 0.4, pz - 0.006), (0.02, 0.7, pz + 0.004), "leaf_dark")                           # stem
    for sx in (-1, 1):                                                                            # leaves
        b.fan_z(pz - 0.004, (0, 0.52), [(sx * 0.25, 0.62), (sx * 0.2, 0.5), (sx * 0.08, 0.46)], 0.01, "leaf_green")
    top = C_H
    b.span((-HW - 0.12, C_H - 0.12, C_FRONT - 0.12), (HW + 0.12, top, C_BACK + 0.1), DARK)          # the top
    b.box((-0.75, top + 0.015, -0.45), (0.5, 0.03, 0.34), "choco", rot=rot_y(20))                     # a soil spill
    _tulip_pot(b, -2.35, top, -0.72)
    _seed_crate(b, -1.15, top, -0.68)
    _trowel(b, -0.55, top, -0.95)
    _gnome_cat(b, 1.35, top, -0.72, 1.2)
    _pot(b, 0.55, top, -0.85, 0.15, 0.28)                                                           # a seedling pot
    for dx, dz, a in ((-0.04, 0.0, 15), (0.05, 0.03, -20)):
        b.box((0.55 + dx, top + 0.33, -0.85 + dz), (0.03, 0.14, 0.03), "leaf_green", rot=rot_z(a))
        b.box((0.55 + dx * 2.5, top + 0.4, -0.85 + dz), (0.13, 0.03, 0.08), "leaf_green", rot=rot_z(a))


# -------------------------------------------------------------------------------------------------- back --
def _back(b, bulb):
    """The step, the planked back board with its shelves of plants, the posts with ivy, the striped awning and the
    chalk sign."""
    b.span((-0.8, 0, CAT_Z - 0.6), (0.8, STEP_H, CAT_Z + 0.65), DARK)                                # hidden step
    b.span((-BW, 0, WALL_Z), (BW, WALL_TOP, WALL_Z + 0.3), WOOD)
    bz = WALL_Z + 0.31                                                                            # its back face
    for x in [-BW + 0.6 + 0.8 * i for i in range(9)]:                                             # planks behind
        b.span((x - 0.04, 0.3, bz - 0.01), (x + 0.04, WALL_TOP - 0.3, bz + 0.02), DARK)
    b.span((-BW, 0, bz - 0.01), (BW, 0.3, bz + 0.04), DARK)                                        # skirting
    b.span((-BW, WALL_TOP - 0.3, bz - 0.01), (BW, WALL_TOP, bz + 0.04), DARK)                      # cap rail
    _leaf_sprig_back(b, 0.0, 2.8, bz + 0.05)
    for x in [-BW + 0.45 + 0.9 * i for i in range(8)]:                                            # board lines in front
        b.span((x - 0.03, 0.2, WALL_Z - 0.02), (x + 0.03, WALL_TOP - 0.05, WALL_Z + 0.01), DARK)
    shelf_d = 0.55
    shelves = ((1.3, BW - 0.1, 2.6), (-BW + 0.1, -1.3, 2.6), (1.3, BW - 0.1, 3.7), (-BW + 0.1, -1.3, 3.7),
               (-BW + 0.1, BW - 0.1, 4.75))
    for x0, x1, y in shelves:
        b.span((x0, y - 0.1, WALL_Z - shelf_d), (x1, y, WALL_Z - 0.019), WOOD)
        b.span((x0 - 0.01, y - 0.13, WALL_Z - shelf_d - 0.04), (x1 + 0.01, y + 0.02, WALL_Z - shelf_d + 0.02), DARK)
        for bx in (x0 + 0.2, x1 - 0.2):                                                           # brackets
            b.span((bx - 0.05, y - 0.4, WALL_Z - 0.3), (bx + 0.05, y - 0.1, WALL_Z - 0.019), DARK)
    sz = WALL_Z - 0.28
    for i, x in enumerate((1.75, 2.45, 3.15)):                                                    # bushes, low left
        _bush(b, x, _pot(b, x, 2.6, sz, 0.2, 0.36), sz, 0.24, ("leaf_green", "fur_fern", "leaf_green")[i])
    for i, x in enumerate((-1.75, -2.45, -3.15)):                                                 # flowers, low right
        top = _pot(b, x, 2.6, sz, 0.18, 0.32, ("terracotta", "sign_teal", "terracotta")[i])
        for j, (dx, dz) in enumerate(((-0.07, -0.05), (0.08, 0.0), (0.0, 0.08))):
            _tulip(b, x + dx, top, sz + dz, 0.3 + 0.05 * j, ("fur_bubblegum", "pastel_lilac", "pastel_butter")[(i + j) % 3],
                   leaf=False)
    for i, x in enumerate((1.7, 2.3, 2.9, 3.35)):                                                 # succulents, up left
        top = _pot(b, x, 3.7, sz, 0.14, 0.24, ("offwhite", "terracotta", "mint", "terracotta")[i])
        for k in range(4):
            a = math.radians(90 * k + 20 * i)
            b.box((x + 0.07 * math.cos(a), top + 0.06, sz + 0.07 * math.sin(a)), (0.1, 0.07, 0.05), "fur_fern",
                  rot=rot_y(-math.degrees(a)) @ rot_z(30))
        b.box((x, top + 0.09, sz), (0.08, 0.1, 0.08), "leaf_green", rot=rot_y(45))
    _sack(b, -2.4, 3.7, sz + 0.02, 0.55)                                                          # a seed bag, up right
    b.span((-3.35, 3.7, sz - 0.12), (-2.95, 3.98, sz + 0.12), "sign_teal")                         # a tin of twine
    b.cyl((-3.15, 4.02, sz), 0.1, 0.08, "kibble", segments=8)
    for i, x in enumerate((-1.75, -1.4)):                                                         # stacked spare pots
        for j in range(3 - i):
            _pot(b, x, 3.7 + j * 0.16, sz, 0.13 - 0.01 * j, 0.2) if j == 0 else \
                b.cyl((x, 3.7 + 0.2 + j * 0.12 - 0.06, sz), 0.15 - 0.01 * j, 0.12, POT, segments=8)
    for i, x in enumerate((-2.9, -1.5, 1.5, 2.9)):                                               # top shelf: pots
        top = _pot(b, x, 4.75, sz, 0.17, 0.3, ("terracotta", "offwhite")[i % 2])
        if i in (1, 2):                                                                           # trailing ivy
            b.box((x, top + 0.1, sz), (0.38, 0.2, 0.34), "leaf_green", rot=rot_y(30))
            for k in range(4):
                b.box((x + 0.08 * (-1) ** k, top - 0.25 - 0.28 * k, sz - 0.2), (0.2, 0.14, 0.06),
                      ("leaf_dark", "leaf_green")[k % 2], rot=rot_z(35 * (-1) ** k))
            b.span((x - 0.015, top - 1.1, sz - 0.215), (x + 0.015, top, sz - 0.185), "leaf_dark")
        else:
            _bush(b, x, top, sz, 0.2, ("leaf_green", "fur_fern", "leaf_dark")[i % 3], "leaf_green")
    _posts(b)
    _awning(b)
    _sign(b)


def _leaf_sprig_back(b, x, y, z):
    """A painted leaf sprig on the back board's back face (seen from behind the stall)."""
    b.span((x - 0.03, y - 1.0, z - 0.02), (x + 0.03, y + 0.9, z + 0.01), "leaf_dark")
    for k in range(4):
        yy = y - 0.6 + 0.45 * k
        for sx in (-1, 1):
            b.fan_z(z + 0.005, (x + sx * 0.02, yy), [(x + sx * 0.3, yy + 0.3), (x + sx * 0.6, yy + 0.22),
                                                    (x + sx * 0.3, yy - 0.02)], -0.03, "leaf_green")


def _sack(b, x, y, z, h):
    """A paper sack of seed or soil standing at (x, y, z): a cream bag with a rolled top and a green leaf on it."""
    w, d = h * 0.62, h * 0.36
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), "cardboard")
    b.span((x - w / 2 - 0.02, y + h - 0.1, z - d / 2 - 0.02), (x + w / 2 + 0.02, y + h + 0.02, z + d / 2 + 0.02),
           "treat_tan")
    c, r = y + h * 0.5, w * 0.24
    b.fan_z(z - d / 2 - 0.01, (x, c - r * 1.3), [(x + r * 0.7, c), (x, c + r * 1.3), (x - r * 0.7, c)], 0.01,
            "leaf_green")


def _posts(b):
    for sx in (-1, 1):
        b.span((sx * BW - 0.15, 0, AWN_FRONT - 0.15), (sx * BW + 0.15, AWN_Y, AWN_FRONT + 0.15), "offwhite")
        b.span((sx * BW - 0.18, 0, AWN_FRONT - 0.18), (sx * BW + 0.18, 0.3, AWN_FRONT + 0.18), DARK)   # foot
    # ivy up the +X post: leaves spiralling round it
    for k in range(12):
        a = math.radians(k * 95)
        y = 0.5 + k * 0.36
        b.box((BW + 0.17 * math.cos(a), y, AWN_FRONT + 0.17 * math.sin(a)), (0.24, 0.16, 0.1),
              ("leaf_green", "leaf_dark")[k % 2], rot=rot_y(-math.degrees(a) - 90) @ rot_z(30 * (-1) ** k))


def _awning(b):
    vz = AWN_FRONT - 0.22                                                           # the valance, before the posts
    zc = vz - 0.05                                                                  # the canopy's front edge
    depth, rise = WALL_Z + 0.3 - zc, WALL_TOP - AWN_Y
    tilt = math.atan2(rise, depth)
    w = 2 * BW + 0.4
    sw_w = w / STRIPES
    cy = AWN_Y - VAL_H + 0.01                                                       # the scallops' top edge
    for i in range(STRIPES):
        x = -w / 2 + sw_w * (i + 0.5)
        sw = AWNING[i % 2]
        b.box((x, (AWN_Y + WALL_TOP) / 2 + 0.07, (zc + WALL_Z + 0.3) / 2), (sw_w, 0.12, math.hypot(depth, rise)),
              sw, rot=rot_x(-math.degrees(tilt)))
        b.span((x - sw_w / 2, AWN_Y - VAL_H, vz - 0.05), (x + sw_w / 2, AWN_Y + 0.06, vz + 0.05), sw)
        arc = [(x + sw_w / 2 * math.cos(math.radians(a)), cy + sw_w / 2 * math.sin(math.radians(a)))
               for a in (180, 240, 300, 360)]
        b.fan_z(vz, (x, cy), arc, 0.1, sw)


def _sign(b):
    """The chalk sign over the awning: a black board in a wooden frame reading GARDEN / NURSERY in chalk, a chalk
    flower either side, on two legs from the back board's top."""
    px = 0.17
    lines = ("GARDEN", "NURSERY")
    w = max(text_width(t, px) for t in lines) + 2.0
    y0, y1, zf = WALL_TOP + 0.25, WALL_TOP + 0.25 + 2.2, WALL_Z - 0.05
    b.span((-w / 2, y0, zf), (w / 2, y1, zf + 0.25), "fur_black")
    for (xa, xb, ya, yb) in ((-w / 2 - 0.15, w / 2 + 0.15, y0 - 0.15, y0 + 0.01),
                             (-w / 2 - 0.15, w / 2 + 0.15, y1 - 0.01, y1 + 0.15),
                             (-w / 2 - 0.15, -w / 2 + 0.01, y0, y1), (w / 2 - 0.01, w / 2 + 0.15, y0, y1)):
        b.span((xa, ya, zf - 0.08), (xb, yb, zf + 0.3), WOOD)
    label(b, lines[0], 0, y1 - 0.3 - 5 * px, zf + 0.01, px, 0.06, "offwhite", -1)
    label(b, lines[1], 0, y0 + 0.3, zf + 0.01, px, 0.06, "offwhite", -1)
    for sx, sw in ((-1, "fur_bubblegum"), (1, "pastel_butter")):                    # chalk flowers
        cx, cyy = sx * (w / 2 - 0.55), (y0 + y1) / 2
        b.box((cx, cyy + 0.15, zf - 0.015), (0.13, 0.13, 0.04), "offwhite", rot=rot_z(45))
        for k in range(5):
            a = math.radians(72 * k + 90)
            b.box((cx + 0.16 * math.cos(a), cyy + 0.15 + 0.16 * math.sin(a), zf - 0.01), (0.16, 0.11, 0.03), sw,
                  rot=rot_z(72 * k))
        b.span((cx - 0.02, cyy - 0.5, zf - 0.02), (cx + 0.02, cyy, zf + 0.005), "leaf_green")
        b.fan_z(zf - 0.015, (cx, cyy - 0.3), [(cx + sx * 0.25, cyy - 0.15), (cx + sx * 0.2, cyy - 0.3),
                                              (cx + sx * 0.05, cyy - 0.38)], 0.015, "leaf_green")
    for sx in (-1, 1):                                                              # legs onto the back board
        b.span((sx * 1.6 - 0.1, WALL_TOP - 0.01, zf + 0.03), (sx * 1.6 + 0.1, y0 - 0.14, zf + 0.23), WOOD)


# -------------------------------------------------------------------------------------------------- ends --
def _seedlings(b):
    """At the +X end: two crates, the top one a tray of seedlings in little pots."""
    cx, cz = HW + 1.3, -0.5
    for i, (y0, h) in enumerate(((0.0, 0.8), (0.8, 0.55))):
        w, d = (1.3, 1.1) if i == 0 else (1.2, 1.0)
        b.span((cx - w / 2, y0, cz - d / 2), (cx + w / 2, y0 + h, cz + d / 2), WOOD)
        for y in (y0 + h * 0.3, y0 + h * 0.7):                                       # slats
            b.span((cx - w / 2 - 0.02, y - 0.05, cz - d / 2 - 0.02), (cx + w / 2 + 0.02, y + 0.05, cz + d / 2 + 0.02),
                   DARK)
    top = 1.35
    b.span((cx - 0.55, top, cz - 0.45), (cx + 0.55, top + 0.05, cz + 0.45), "choco")
    for i in range(3):
        for j in range(3):
            x, z = cx - 0.36 + 0.36 * i, cz - 0.3 + 0.3 * j
            b.span((x - 0.12, top + 0.05, z - 0.11), (x + 0.12, top + 0.23, z + 0.11), POT)
            for a in (30, 120):
                b.box((x, top + 0.29, z), (0.2, 0.05, 0.07), ("leaf_green", "fur_fern")[(i * 3 + j) % 2],
                      rot=rot_y(a + 15 * i) @ rot_z(20))


def _soil_and_can(b):
    """At the -X end: a big sack of potting soil leaning on the bench and a teal watering can on the ground."""
    _sack(b, -HW - 0.75, 0.0, -0.2, 1.3)
    x, z = -HW - 0.8, -1.25
    r, h = 0.26, 0.42
    b.cyl((x, h / 2, z), r, h, "sign_teal", segments=12)
    b.cyl((x, h + 0.02, z), r * 0.75, 0.04, "sign_teal", segments=12)
    b.cyl((x, 0.12, z), r + 0.015, 0.06, "leaf_dark", segments=12)                       # a band
    a = math.radians(40)                                                              # the spout, out to -X
    L = 0.5
    sx0 = x - r + 0.04
    b.box((sx0 - L / 2 * math.sin(a), 0.12 + L / 2 * math.cos(a), z), (0.07, L, 0.07), "sign_teal", rot=rot_z(40))
    tip = (sx0 - L * math.sin(a), 0.12 + L * math.cos(a), z)
    b.cyl((tip[0] - 0.02, tip[1] + 0.02, z), 0.075, 0.06, "metal", segments=8)
    for dx in (-0.1, 0.1):                                                            # handle
        b.span((x + dx - 0.03, h, z - 0.03), (x + dx + 0.03, h + 0.18, z + 0.03), "sign_teal")
    b.span((x - 0.13, h + 0.16, z - 0.03), (x + 0.13, h + 0.22, z + 0.03), "sign_teal")


# ------------------------------------------------------------------------------------------------- build --
def build_garden_nursery(mat):
    b, bulb = RB(), RB()
    _bench(b)
    _mini_lamp(b, bulb, 2.45, C_H, -0.75)
    _back(b, bulb)
    _seedlings(b)
    _soil_and_can(b)
    out = [b.finalize(NAME, mat), bulb.finalize(NAME + "_Bulb", mat)]
    base = NAME + "_Cat"                                                             # the gardener, standing
    cat = [o for o in cats.build_cat("GardenNurseryCat", mat, spec=CAT, base=base, body="work")
           if "_Held_" not in o.name]
    d = cats.dims(CAT, "work")
    ctx = props.Ctx(CAT, "sit", d)                                                   # body S wears on B's frames
    ctx.work = True
    props.sun_hat(ctx)
    k = cats.scale_of(CAT, "work")
    hat = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hat, k)
    hat["rides"] = "Head"
    for ob in cat + [hat]:
        ob.location = ob.location + Vector(RB.p(0, STEP_H, CAT_Z))
    _drop_held(mat)
    return out + cat + [hat]


def _drop_held(mat):
    """build_cat made the working body's held things too; remove the ones left out of the model from the scene."""
    import bpy
    for ob in [o for o in bpy.data.objects if o.name.startswith(NAME + "_Cat_Held_")]:
        bpy.data.objects.remove(ob, do_unlink=True)


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor on the stall, BubbleAnchor over the
    gardener's hat in its Head part."""
    k = cats.scale_of(CAT, "work")
    head = Vector(cats.joints(CAT, "work")["Head"])
    carry = Vector(cats.carry_at(CAT, "work")) + Vector((0.0, 0.0, BUBBLE_LIFT))
    bubble = Vector(RB.p(0, STEP_H, CAT_Z)) + head + carry * k
    return [(NAME, "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX)))),
            ("_Cat_Head", "BubbleAnchor", Matrix.Translation(bubble))]


ASSETS = {
    NAME: (build_garden_nursery, 7500),
}
