"""The Corner Shop (corner-shop.md section 4, #1052): a little coin shop stall in the Town Square beside the Golden
Fish Market. A strawberry and cream striped awning over a mint counter with glass jars of treats on its ledge, shelves
behind with what it sells (Swift Potions, Cat Snack boxes, a Big Cat Snack bag, a bubble machine and firework rockets),
a CORNER SHOP sign with its lamp, a toffee and white shop cat in a green shopkeeper's visor sitting behind the counter,
a basket of snack bags on a crate at one end and a chalkboard at the other. From behind, the back board shows its
planks and a painted paw over a fish.

  CatCafe_Street_CornerShop              counter, posts, back board, shelves, awning, sign, basket and chalkboard
                                         (collides), with an Attachment PromptAnchor in its PrimaryPart where
                                         WorldBuilder hangs the prompt: the middle of the counter front, 3 studs up
  CatCafe_Street_CornerShop_Glass        the jars' glass (rbx_export makes _Glass parts see-through)
  CatCafe_Street_CornerShop_Bulb         the sign lamp, lit at night
  CatCafe_Street_CornerShop_Cat_<Piece>  the shopkeeper, the same hinged pieces as every sitting cat; its visor
                                         (_Cat_Prop) rides inside the Head Model

Pivot at the base centre, the counter front (-Z) toward the players. Footprint about 11.6 x 4.6 studs. The server
places it at Layout.cornerShop and tags it CornerShop.
"""

import math

from mathutils import Matrix, Vector

import cats
import props
from alleyway import label
from common import RB, scale_mesh, text_width
from plot import rot_x, rot_y, rot_z

NAME = "CatCafe_Street_CornerShop"
HW, C_FRONT, C_BACK, C_H = 3.4, -1.3, 0.0, 2.5       # the counter: half width, front, back, height
TOP = C_H + 0.15                                     # the ledge top
SEAT_Y, CAT_Z = 2.1, 0.95                            # the stool top and the cat's pivot (Roblox z)
WALL_Z, WALL_TOP = 1.9, 7.2                          # the back board's front face and top
AWN_FRONT, AWN_Y = -1.75, 6.3                        # the awning's front edge (the posts)
VAL_H, STRIPES = 0.45, 9                             # the valance hanging from it, and the stripes
PROMPT_ROBLOX = (0.0, 3.0, C_FRONT - 0.4)
AWNING = ("fur_strawberry", "cream")
TRIM = "choco"

# Toffee and white with copper eyes: no collectable cat has this coat, and the green visor says shopkeeper.
CAT = dict(rarity="Common", fur="fur_toffee", second="fur_white", eyes="eye_copper", pattern="patches", muzzle="fur_white",
           nose="nose_brick", scale=1.5)

# The jars on the ledge: what is inside (two colours) and the lid
JARS = ((("treat_tan", "kibble"), "fur_strawberry"), (("fur_strawberry", "offwhite"), "mint"),
        (("mint", "pastel_sky"), "pastel_butter"), (("pastel_butter", "rarity_legend"), "fur_strawberry"),
        (("pastel_lilac", "fur_bubblegum"), "mint"))


def visor(ctx):
    """A green shopkeeper's visor: a band round the head under the ears' fronts and a wide brim tipped down."""
    P = ctx.pen("head")
    P.cyl((0, 0.0, 0.05), 0.47, 0.1, "shirt_green", segments=14)                  # band
    P.cyl((0, 0.0, 0.1), 0.475, 0.025, "cream", segments=14)                      # its piping
    P.box((0, -0.52, 0.04), (0.78, 0.42, 0.04), "shirt_green", rot=props._rx(14))   # brim


def _paw(b, x, y, z, s, sw):
    """A paw print standing on a face at depth z (facing -Z)."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, 0.03, sw, axis="Z", segments=8)
    for dx, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x + dx * s, y + dy * s, z), 0.075 * s, 0.03, sw, axis="Z", segments=6)


def _paw_back(b, x, y, z, s, sw):
    """A paw print on a face at depth z that faces +Z (the back)."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, 0.03, sw, axis="Z", segments=8)
    for dx, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x + dx * s, y + dy * s, z), 0.075 * s, 0.03, sw, axis="Z", segments=6)


def _counter(b):
    b.span((-HW, 0, C_FRONT), (HW, C_H, C_BACK), "mint")
    b.span((-HW - 0.05, 0, C_FRONT - 0.05), (HW + 0.05, 0.3, C_BACK + 0.05), TRIM)                   # kick
    b.span((-HW - 0.05, 2.1, C_FRONT - 0.05), (HW + 0.05, C_H, C_BACK + 0.05), "fur_strawberry")     # band
    for sx in (-1, 1):                                                              # cream panels with a paw print
        x0, x1 = sorted((sx * 0.95, sx * 3.05))
        b.span((x0, 0.6, C_FRONT - 0.04), (x1, 1.85, C_FRONT + 0.01), "cream")
        _paw(b, sx * 2.0, 1.2, C_FRONT - 0.06, 1.3, TRIM)
    b.span((-0.75, 0.75, C_FRONT - 0.04), (0.75, 1.7, C_FRONT + 0.01), "offwhite")    # the price card in the middle
    b.span((-0.82, 1.62, C_FRONT - 0.06), (0.82, 1.78, C_FRONT + 0.01), TRIM)
    b.cyl((0, 1.16, C_FRONT - 0.07), 0.24, 0.04, "rarity_legend", axis="Z", segments=8)               # a coin on it
    b.cyl((0, 1.16, C_FRONT - 0.09), 0.15, 0.03, "gold_light", axis="Z", segments=8)
    b.span((-HW - 0.15, C_H - 0.01, C_FRONT - 0.15), (HW + 0.15, TOP, C_BACK + 0.1), "caramel_wood")   # ledge


def _jars(b, glass):
    """Five glass jars of treats along the ledge, each with a lid and a cream label."""
    z = -0.62
    for i, ((c1, c2), lid) in enumerate(JARS):
        x = -2.6 + i * 1.3
        h = 0.8 if i % 2 == 0 else 0.68
        glass.cyl((x, TOP + h / 2, z), 0.33, h, "glass", segments=8)
        for j in range(4):                                                          # the treats, tumbled
            a = j * 2.4 + i
            r = 0.13 if j < 3 else 0.0
            yy = TOP + 0.1 + (j // 2) * 0.17
            b.box((x + r * math.cos(a), yy, z + r * math.sin(a)), (0.15, 0.13, 0.15), (c1, c2)[j % 2],
                  rot=rot_y(a * 30) @ rot_z(20))
        b.cyl((x, TOP + h + 0.05, z), 0.36, 0.1, lid, segments=8)
        b.span((x - 0.2, TOP + 0.25, z - 0.345), (x + 0.2, TOP + 0.45, z - 0.33), "cream")


def _bottle(b, x, y, z, sw):
    """A Swift Potion: a teal bottle with a short neck and a cork."""
    b.cyl((x, y + 0.2, z), 0.15, 0.4, sw, segments=6)
    b.cyl((x, y + 0.47, z), 0.07, 0.14, "offwhite", segments=6)
    b.cyl((x, y + 0.58, z), 0.075, 0.08, "caramel_wood", segments=6)
    b.span((x - 0.11, y + 0.12, z - 0.16), (x + 0.11, y + 0.28, z - 0.14), "cream")


def _snack_box(b, x, y, z, sw, big=False):
    """A Cat Snack box (or the Big Cat Snack bag): a coloured box with a cream fish on the front."""
    w, h, d = (0.62, 0.8, 0.36) if big else (0.42, 0.52, 0.26)
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), sw)
    f = z - d / 2 - 0.01
    b.ball((x - 0.03, y + h * 0.48, f), w * 0.3, "cream", scale=(1.0, 0.55, 0.12))
    b.fan_z(f, (x + w * 0.18, y + h * 0.48), [(x + w * 0.36, y + h * 0.62), (x + w * 0.3, y + h * 0.48),
                                             (x + w * 0.36, y + h * 0.34)], 0.03, "cream")
    if big:
        b.span((x - w / 2 - 0.01, y + h - 0.16, z - d / 2 - 0.01), (x + w / 2 + 0.01, y + h - 0.06, z + d / 2 + 0.01),
               "rarity_legend")


def _rocket(b, x, y, z, sw):
    """A firework rocket: a striped tube, a cone and a stick, standing in a cup."""
    b.cyl((x, y + 0.3, z), 0.08, 0.5, sw, segments=6)
    b.cyl((x, y + 0.42, z), 0.085, 0.08, "cream", segments=6)
    b.cyl((x, y + 0.63, z), 0.085, 0.16, "rarity_legend", r2=0.01, segments=6)
    b.cyl((x, y + 0.03, z), 0.02, 0.1, "caramel_wood", segments=4)


def _back(b, bulb):
    """Stool, back board with three shelves of goods, posts, the striped awning and the sign with its lamp."""
    b.span((-0.75, 0, CAT_Z - 0.75), (0.75, SEAT_Y, CAT_Z + 0.75), "dark_wood")                         # stool
    b.span((-0.85, SEAT_Y - 0.01, CAT_Z - 0.8), (0.85, SEAT_Y + 0.12, CAT_Z + 0.8), "fur_strawberry")   # cushion
    bw = HW + 0.25
    b.span((-bw, 0, WALL_Z), (bw, WALL_TOP, WALL_Z + 0.3), "pastel_butter")
    bz = WALL_Z + 0.31                                                              # the board's back face
    for x in (-bw + 0.9, -bw + 1.8, -bw + 2.7, -bw + 3.6, -bw + 4.5, -bw + 5.4, -bw + 6.3):   # planks from behind
        b.span((x - 0.04, 0.3, bz - 0.01), (x + 0.04, WALL_TOP - 0.3, bz + 0.02), "caramel_wood")
    b.span((-bw, 0, bz - 0.01), (bw, 0.3, bz + 0.04), TRIM)                          # a skirting board
    b.span((-bw, WALL_TOP - 0.3, bz - 0.01), (bw, WALL_TOP, bz + 0.04), TRIM)        # and a cap rail
    b.span((-1.5, 2.2, bz + 0.01), (1.5, 5.0, bz + 0.04), "cream")                   # a painted sign: paw over fish
    _paw_back(b, 0.0, 4.0, bz + 0.05, 1.8, "fur_strawberry")
    b.ball((-0.15, 2.9, bz + 0.06), 0.55, "mint", scale=(1.0, 0.5, 0.06))
    b.fan_z(bz + 0.03, (0.3, 2.9), [(0.75, 3.2), (0.6, 2.9), (0.75, 2.6)], 0.05, "mint")
    for x in (-bw + 0.6, -bw + 1.4, bw - 1.4, bw - 0.6):                            # wallpaper stripes, low down
        b.span((x - 0.12, 0.3, WALL_Z - 0.02), (x + 0.12, 2.6, WALL_Z + 0.01), "cream")
    # shelves: two short ones either side of the cat, one long one above its head
    shelf_d = 0.55
    for x0, x1, y in ((-bw + 0.1, -1.25, 3.2), (1.25, bw - 0.1, 3.2), (-bw + 0.1, -1.25, 4.4), (1.25, bw - 0.1, 4.4),
                      (-bw + 0.1, bw - 0.1, 5.55)):
        b.span((x0, y - 0.1, WALL_Z - shelf_d), (x1, y, WALL_Z + 0.01), "caramel_wood")
        b.span((x0 - 0.01, y - 0.13, WALL_Z - shelf_d - 0.04), (x1 + 0.01, y + 0.02, WALL_Z - shelf_d + 0.02), TRIM)  # lip
        for bx in (x0 + 0.2, x1 - 0.2):                                             # brackets
            b.span((bx - 0.05, y - 0.4, WALL_Z - 0.3), (bx + 0.05, y - 0.1, WALL_Z + 0.01), TRIM)
    sz = WALL_Z - 0.28
    for i, x in enumerate((-3.2, -2.75, -2.3, -1.85)):                              # Swift Potions
        _bottle(b, x, 3.2, sz, ("sign_teal", "mint")[i % 2])
    for i, x in enumerate((1.6, 2.15, 2.7, 3.25)):                                  # Cat Snack boxes
        _snack_box(b, x, 3.2, sz, ("fur_strawberry", "shirt_blue")[i % 2])
    _snack_box(b, -2.9, 4.4, sz, "shirt_blue", big=True)                           # the Big Cat Snack bag
    _snack_box(b, -2.15, 4.4, sz, "shirt_blue", big=True)
    b.span((1.55, 4.4, sz - 0.25), (2.35, 4.95, sz + 0.25), "pastel_lilac")       # the bubble machine
    b.cyl((1.95, 4.67, sz - 0.27), 0.16, 0.04, TRIM, axis="Z", segments=10)
    for dx, dy, r in ((0.0, 0.67, 0.13), (0.14, 0.82, 0.09)):  # bubbles resting on top, the small one on the big one
        b.ball((1.95 + dx, 4.4 + dy, sz), r, "pastel_sky")
    b.cyl((3.0, 4.55, sz), 0.28, 0.3, "fur_strawberry", segments=8)               # a cup of rockets
    for i, (dx, dz) in enumerate(((-0.12, -0.08), (0.12, -0.05), (0.0, 0.1))):
        _rocket(b, 3.0 + dx, 4.6, sz + dz, ("shirt_red", "sign_teal", "pastel_lilac")[i])
    for i, x in enumerate((-2.8, -2.0, -1.2, 1.2, 2.0, 2.8)):                       # the top shelf: more jars and boxes
        if i % 2 == 0:
            b.cyl((x, 5.55 + 0.3, sz), 0.24, 0.6, ("mint", "fur_strawberry", "pastel_butter")[i // 2], segments=6)
            b.cyl((x, 5.55 + 0.64, sz), 0.26, 0.08, TRIM, segments=6)
        else:
            _snack_box(b, x, 5.55, sz, ("pastel_lilac", "mint", "fur_strawberry")[i // 2])
    for sx in (-1, 1):                                                              # front posts
        b.span((sx * bw - 0.15, 0, AWN_FRONT - 0.15), (sx * bw + 0.15, AWN_Y, AWN_FRONT + 0.15), TRIM)
        for y in (1.2, 2.4, 3.6, 4.8):                                              # a candy stripe up each post
            b.span((sx * bw - 0.16, y, AWN_FRONT - 0.16), (sx * bw + 0.16, y + 0.35, AWN_FRONT + 0.16), "cream")
    vz = AWN_FRONT - 0.22                                                           # the valance, before the posts
    zc = vz - 0.05                                                                  # the canopy's front edge
    depth, rise = WALL_Z + 0.3 - zc, WALL_TOP - AWN_Y
    tilt = math.atan2(rise, depth)
    w = 2 * bw + 0.4
    sw_w = w / STRIPES
    cy = AWN_Y - VAL_H + 0.01                                                       # the scallops' top edge
    for i in range(STRIPES):                                                        # the striped awning
        x = -w / 2 + sw_w * (i + 0.5)
        sw = AWNING[i % 2]
        b.box((x, (AWN_Y + WALL_TOP) / 2 + 0.07, (zc + WALL_Z + 0.3) / 2), (sw_w, 0.12, math.hypot(depth, rise)),
              sw, rot=rot_x(-math.degrees(tilt)))                                   # a negative turn lifts the back
        b.span((x - sw_w / 2, AWN_Y - VAL_H, vz - 0.05), (x + sw_w / 2, AWN_Y + 0.06, vz + 0.05), sw)
        arc = [(x + sw_w / 2 * math.cos(math.radians(a)), cy + sw_w / 2 * math.sin(math.radians(a)))
               for a in (180, 240, 300, 360)]
        b.fan_z(vz, (x, cy), arc, 0.1, sw)
    text, px = "CORNER SHOP", 0.2
    sw_ = text_width(text, px) + 1.2
    y0, y1, zf = WALL_TOP + 0.2, WALL_TOP + 1.7, WALL_Z - 0.05
    b.span((-sw_ / 2, y0 - 0.01, zf), (sw_ / 2, y1, zf + 0.3), "cream")
    for (xa, xb, ya, yb) in ((-sw_ / 2 - 0.15, sw_ / 2 + 0.15, y0 - 0.03, y0 + 0.15),
                             (-sw_ / 2 - 0.15, sw_ / 2 + 0.15, y1 - 0.15, y1 + 0.01),
                             (-sw_ / 2 - 0.15, -sw_ / 2 + 0.01, y0, y1), (sw_ / 2 - 0.01, sw_ / 2 + 0.15, y0, y1)):
        b.span((xa, ya, zf - 0.08), (xb, yb, zf + 0.34), TRIM)
    label(b, text, 0, (y0 + y1) / 2 - 2.5 * px, zf + 0.01, px, 0.07, "fur_strawberry", -1)
    _paw_back(b, 0.0, (y0 + y1) / 2 - 0.1, zf + 0.31, 1.4, "fur_strawberry")                 # a paw on its back
    b.span((-sw_ / 2 + 0.3, WALL_TOP - 0.01, zf + 0.05), (-sw_ / 2 + 0.5, y0, zf + 0.25), TRIM)  # legs
    b.span((sw_ / 2 - 0.5, WALL_TOP - 0.01, zf + 0.05), (sw_ / 2 - 0.3, y0, zf + 0.25), TRIM)
    b.span((-0.05, y1, zf + 0.1), (0.05, y1 + 0.6, zf + 0.2), "fur_black")                      # lamp
    b.span((-0.05, y1 + 0.5, zf - 0.6), (0.05, y1 + 0.6, zf + 0.2), "fur_black")
    b.cyl((0, y1 + 0.35, zf - 0.6), 0.32, 0.18, "fur_black", r2=0.12)
    bulb.ball((0, y1 + 0.2, zf - 0.6), 0.16, "lamp_warm")


def _basket(b):
    """At the left: a crate with a wicker basket of snack bags on it."""
    cx, cz = -HW - 1.2, -0.55
    b.span((cx - 0.65, 0, cz - 0.55), (cx + 0.65, 1.0, cz + 0.55), "caramel_wood")
    for y in (0.25, 0.65):                                                          # slats
        b.span((cx - 0.67, y, cz - 0.57), (cx + 0.67, y + 0.12, cz + 0.57), "dark_wood")
    b.span((cx - 0.55, 0.99, cz - 0.45), (cx + 0.55, 1.5, cz + 0.45), "treat_tan")       # basket
    for y in (1.1, 1.3):
        b.span((cx - 0.57, y, cz - 0.47), (cx + 0.57, y + 0.06, cz + 0.47), "kibble")     # weave bands
    for sx in (-1, 1):                                                              # handle
        b.span((cx + sx * 0.5 - 0.04, 1.5, cz - 0.04), (cx + sx * 0.5 + 0.04, 2.0, cz + 0.04), "kibble")
    b.span((cx - 0.54, 1.96, cz - 0.04), (cx + 0.54, 2.04, cz + 0.04), "kibble")
    for i, (dx, dz, a) in enumerate(((-0.25, -0.1, -12), (0.05, 0.12, 6), (0.28, -0.12, 15))):
        b.box((cx + dx, 1.62, cz + dz), (0.3, 0.42, 0.14), ("fur_strawberry", "shirt_blue", "mint")[i],
              rot=rot_z(a))                                                         # bags standing up in it
        b.box((cx + dx, 1.85, cz + dz), (0.3, 0.06, 0.15), "cream", rot=rot_z(a))


BOARD_X, BOARD_Z, BOARD_LEAN = HW + 1.55, -1.75, 12        # the chalkboard's foot centre and its lean back


def _chalkboard(b):
    """At the right, before the counter's end: a sandwich board, the chalk face toward the street with a cream header
    reading TREATS and chalk drawings of a potion, a fish and a star."""
    R = rot_x(BOARD_LEAN)                                   # leans the front board's top back, away from the street
    Rb = rot_x(-BOARD_LEAN)                                 # and the back board's top forward, so the tops meet
    back_foot = (BOARD_X, 0.0, BOARD_Z + 2 * 2.0 * math.sin(math.radians(BOARD_LEAN)))

    def at(p, Rm=R, base=(BOARD_X, 0.0, BOARD_Z)):
        v = Rm @ Vector(p)
        return (base[0] + v.x, base[1] + v.y, base[2] + v.z)

    b.box(at((0, 1.0, 0)), (1.4, 2.0, 0.08), "caramel_wood", rot=R)                 # the front board's frame
    b.box(at((0, 1.0, 0), Rm=Rb, base=back_foot), (1.4, 2.0, 0.08), "caramel_wood", rot=Rb)   # the back board
    b.box(at((0, 0.95, -0.05)), (1.2, 1.4, 0.03), "fur_black", rot=R)               # chalk
    b.box(at((0, 1.83, -0.05)), (1.2, 0.26, 0.03), "cream", rot=R)                  # header
    px = 0.035
    hz = at((0, 1.74, -0.065))
    label(b, "TREATS", BOARD_X, hz[1], hz[2], px, 0.02, TRIM, -1)
    for p, s in (((-0.3, 1.35, -0.07), (0.18, 0.3, 0.02)), ((-0.3, 1.55, -0.07), (0.07, 0.12, 0.02)),   # potion
                 ((0.22, 1.32, -0.07), (0.4, 0.16, 0.02)), ((0.48, 1.32, -0.07), (0.1, 0.22, 0.02)),    # fish
                 ((0.0, 0.62, -0.07), (0.3, 0.07, 0.02)), ((0.0, 0.62, -0.07), (0.07, 0.3, 0.02))):    # star
        b.box(at(p), s, "offwhite", rot=R)
    b.box(at((0.0, 0.62, -0.07)), (0.24, 0.07, 0.02), "offwhite", rot=R @ rot_z(45))
    b.box(at((0.0, 0.62, -0.07)), (0.24, 0.07, 0.02), "offwhite", rot=R @ rot_z(-45))
    gap = back_foot[2] - BOARD_Z
    b.box((BOARD_X, 0.5, BOARD_Z + gap / 2), (1.3, 0.05, gap - 0.1), "dark_wood")    # the stay between them


def build_corner_shop(mat):
    b, bulb, glass = RB(), RB(), RB()
    _counter(b)
    _jars(b, glass)
    _back(b, bulb)
    _basket(b)
    _chalkboard(b)
    out = [b.finalize(NAME, mat), glass.finalize(NAME + "_Glass", mat), bulb.finalize(NAME + "_Bulb", mat)]
    base = NAME + "_Cat"                                                                 # the shopkeeper
    cat = cats.build_cat("CornerShopCat", mat, spec=CAT, base=base, body="sit")
    d = cats.dims(CAT, "sit")
    ctx = props.Ctx(CAT, "sit", d)
    visor(ctx)
    k = cats.scale_of(CAT, "sit")
    hat = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hat, k)
    hat["rides"] = "Head"
    for ob in cat + [hat]:
        ob.location = ob.location + Vector(RB.p(0, SEAT_Y + 0.11, CAT_Z))
    return out + cat + [hat]


def prompt_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor on the stall."""
    return (NAME, "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX))))


ASSETS = {
    NAME: (build_corner_shop, 6000),
}
