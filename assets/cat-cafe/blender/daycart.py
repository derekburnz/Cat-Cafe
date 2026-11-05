"""The Day Cart (#1577, day-cart.md section 1): the Corner Shop's coin stock moved onto a wooden market cart in the
Town Square, on the side opposite the Golden Fish Market. The same toffee and white shopkeeper in its green visor
(cornershop.CAT) now sits on a cushion on the cart's back half, behind a two-step display of what the cart sells:
potions in their own bottle shapes, the Cat Whistle, kibble sacks, tuna tins and a salmon on a board, with little
coin price tags (coins only). Over it a strawberry and cream striped awning on candy-striped posts, and on top a
DAY CART sign with a sun at each end (a big painted sun on its back). Two spoked wheels, two legs at the other end
and a pair of shafts resting on the paving. From behind, the cart's back shows its planks and a painted paw over a
fish, and the awning and sign are finished on every side.

  CatCafe_Town_DayCart              the cart, display, awning and sign (collides), with an Attachment PromptAnchor in
                                    its PrimaryPart where WorldBuilder hangs the shop prompt: the middle of the cart's
                                    front, 3 studs up
  CatCafe_Town_DayCart_Bulb         the lantern hanging off the front right post, lit at night
  CatCafe_Town_DayCart_Cat_<Piece>  the shopkeeper, the same hinged pieces as every sitting cat; its visor
                                    (_Cat_Prop) rides inside the Head Model

Pivot at the base centre, the display (-Z) toward the players. Footprint about 8.4 x 3.6 studs, 7.6 tall. The
suggested spot is SPOT, in the Codes Cat's quarter (the Golden Fish Market's opposite): see SPOT's comment.
"""

import math

from mathutils import Matrix, Vector

import cats
import cornershop
import props
from alleyway import label
from common import RB, scale_mesh, text_width
from plot import rot_x, rot_z

NAME = "CatCafe_Town_DayCart"

OX = -1.0                                   # the cart body's centre x: the shafts reach out to +X, so the whole
HX, HZ = 3.0, 1.3                           # footprint stays centred on the pivot; the body's half width and depth
BODY_Y0, BODY_Y1 = 1.25, 2.3                # the body's bottom and top
TOP = BODY_Y1 + 0.15                        # the top board's top, where the goods stand
WHEEL_X, WHEEL_R, WHEEL_Z = OX + 1.2, 1.05, HZ + 0.25
LEG_X = OX - HX + 0.3
SHAFT_Z, SHAFT_TIP = 0.85, OX + 5.1         # the shafts' half spacing and where their feet rest
POST_X, POST_FZ, POST_BZ = HX - 0.05, -1.2, 1.2
AWN_FY, AWN_BY = 5.45, 6.05                 # the awning's front and back edge heights
AWN_FZ, AWN_BZ = -1.8, 1.65                 # and its front and back edge depths
STRIPES, VAL_H = 9, 0.42
AWNING = cornershop.AWNING
TRIM = cornershop.TRIM
CUSHION = (OX + 0.0, 0.75)                  # the shopkeeper's cushion centre (x, z) on the top board
CUSHION_H = 0.2
PROMPT_ROBLOX = (OX, 3.0, -HZ - 0.4)        # the prompt: before the cart's front, 3 up
SIGN_PX = 0.15

# Model-Agent's spot (world x, y, z, rotY, turned to face the cannon as Layout's station() does): the Golden Fish
# Market stands in the north-east quarter, so the cart goes in the south-west one, the Codes Cat's quarter, near where
# the Thank You board stood until #1388. Its footprint clears the Codes Cat by 5.0 studs and its CodesCircle by 3.9,
# the south sign arch's west post by 3.9, the edge lamp by 6.1, the bunting line by 8.2, the street lane by 4.4, the
# cross by 14 and the cannon's landing pad by 9.6.
SPOT = (-17.0, 0.1, -24.0, math.degrees(math.atan2(-(0 - -17.0), -(0 - -24.0))))


def _paw(b, x, y, z, s, sw, facing=-1):
    """A paw print standing on a face at depth z (facing -Z, or +Z with facing 1)."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, 0.03, sw, axis="Z", segments=8)
    for dx, dy in ((-0.2, 0.16), (-0.07, 0.25), (0.07, 0.25), (0.2, 0.16)):
        b.cyl((x + dx * s, y + dy * s, z), 0.075 * s, 0.03, sw, axis="Z", segments=6)


def _wheel(b, z):
    """A spoked wheel at depth z, the axle along Z: a rim, six spokes and a gold hub."""
    side = 1 if z > 0 else -1
    b.b.ring(RB.p(WHEEL_X, WHEEL_R, z), WHEEL_R, 0.2, 0.2, "dark_wood", segments=16, bevel=False,
             rot=(math.radians(90), "X"))
    for k in range(3):                                                              # three bars make six spokes
        b.box((WHEEL_X, WHEEL_R, z), (2 * WHEEL_R - 0.3, 0.12, 0.12), "caramel_wood", rot=rot_z(k * 60 + 15))
    b.cyl((WHEEL_X, WHEEL_R, z + side * 0.04), 0.24, 0.3, "rarity_legend", axis="Z", segments=8)
    b.cyl((WHEEL_X, WHEEL_R, z + side * 0.2), 0.12, 0.06, TRIM, axis="Z", segments=6)


def _body(b):
    x0, x1 = OX - HX, OX + HX
    b.span((x0, BODY_Y0, -HZ), (x1, BODY_Y1, HZ), "caramel_wood")
    b.span((x0 - 0.1, BODY_Y1, -HZ - 0.1), (x1 + 0.1, TOP, HZ + 0.1), "dark_wood")             # the top board
    b.span((x0 - 0.05, BODY_Y0 - 0.02, -HZ - 0.05), (x1 + 0.05, BODY_Y0 + 0.18, HZ + 0.05), TRIM)   # skirt
    for x in (x0, x1):                                                                            # corner posts
        for z in (-HZ, HZ):
            b.span((x - 0.08, BODY_Y0 + 0.18, z - 0.08), (x + 0.08, BODY_Y1, z + 0.08), TRIM)
    # the front: two mint panels with a paw print each, the cream price card in the middle with a coin on it
    for sx in (-1, 1):
        a, c = sorted((OX + sx * 0.95, OX + sx * 2.7))
        b.span((a, BODY_Y0 + 0.3, -HZ - 0.03), (c, BODY_Y1 - 0.15, -HZ + 0.01), "mint")
        _paw(b, OX + sx * 1.82, 1.72, -HZ - 0.05, 1.1, "cream")
    b.span((OX - 0.7, BODY_Y0 + 0.3, -HZ - 0.03), (OX + 0.7, BODY_Y1 - 0.15, -HZ + 0.01), "cream")
    b.cyl((OX, 1.77, -HZ - 0.05), 0.26, 0.04, "rarity_legend", axis="Z", segments=8)
    b.cyl((OX, 1.77, -HZ - 0.08), 0.16, 0.03, "gold_light", axis="Z", segments=8)
    # the back: planks, and a painted paw over a fish
    for i in range(1, 7):
        x = x0 + i * (2 * HX) / 7
        b.span((x - 0.04, BODY_Y0 + 0.2, HZ - 0.01), (x + 0.04, BODY_Y1 - 0.05, HZ + 0.02), TRIM)
    b.span((OX - 0.9, BODY_Y0 + 0.25, HZ + 0.01), (OX + 0.9, BODY_Y1 - 0.08, HZ + 0.04), "cream")
    _paw(b, OX, 1.95, HZ + 0.06, 0.9, "fur_strawberry")
    b.ball((OX - 0.12, 1.47, HZ + 0.06), 0.36, "mint", scale=(1.0, 0.45, 0.06))
    b.fan_z(HZ + 0.05, (OX + 0.18, 1.47), [(OX + 0.48, 1.65), (OX + 0.38, 1.47), (OX + 0.48, 1.29)], 0.04, "mint")
    # the ends: a cream band under the top board
    for x in (x0, x1):
        b.span((x - 0.03, BODY_Y1 - 0.4, -HZ + 0.1), (x + 0.03, BODY_Y1 - 0.15, HZ - 0.1), "fur_strawberry")


def _under(b):
    """Under the body: two beams that run on as the shafts, the axle and wheels, and the legs at the other end."""
    for z in (-SHAFT_Z, SHAFT_Z):
        b.span((OX - HX + 0.1, BODY_Y0 - 0.12, z - 0.11), (OX + HX, BODY_Y0, z + 0.11), "dark_wood")   # beam
        p0, p1 = (OX + HX - 0.05, BODY_Y0 - 0.06), (SHAFT_TIP - 0.2, 0.42)                               # shaft
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        b.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, z), (math.hypot(dx, dy) + 0.1, 0.16, 0.16), "dark_wood",
              rot=rot_z(math.degrees(math.atan2(dy, dx))))
        b.span((SHAFT_TIP - 0.4, 0.0, z - 0.16), (SHAFT_TIP, 0.36, z + 0.16), TRIM)                     # its foot
        b.cyl((SHAFT_TIP - 0.25, 0.45, z), 0.1, 0.08, "rarity_legend", axis="Z", segments=6)              # a gold cap
    b.cyl((SHAFT_TIP - 0.75, 0.62, 0), 0.07, 2 * SHAFT_Z - 0.1, "caramel_wood", axis="Z", segments=6)      # crossbar
    b.cyl((WHEEL_X, WHEEL_R, 0), 0.09, 2 * WHEEL_Z - 0.1, TRIM, axis="Z", segments=6)                       # axle
    for z in (-HZ + 0.25, HZ - 0.25):                                                                       # legs
        b.span((LEG_X - 0.13, 0.0, z - 0.13), (LEG_X + 0.13, BODY_Y0, z + 0.13), "dark_wood")
        b.span((LEG_X - 0.18, 0.0, z - 0.18), (LEG_X + 0.18, 0.12, z + 0.18), TRIM)
    b.span((LEG_X - 0.06, 0.5, -HZ + 0.3), (LEG_X + 0.06, 0.62, HZ - 0.3), "caramel_wood")                 # brace
    for z in (-WHEEL_Z, WHEEL_Z):
        _wheel(b, z)


# ------------------------------------------------------------------ goods ----

def _potion(b, x, y, z, shape, sw):
    """A potion bottle standing at (x, y, z): round flask, tall bottle or squat jar, with a cork and a cream label."""
    if shape == "round":
        b.ball((x, y + 0.2, z), 0.21, sw)
        b.cyl((x, y + 0.45, z), 0.07, 0.14, "offwhite", segments=6)
        b.cyl((x, y + 0.55, z), 0.08, 0.07, "caramel_wood", segments=6)
    elif shape == "tall":
        b.cyl((x, y + 0.23, z), 0.13, 0.46, sw, segments=6)
        b.cyl((x, y + 0.52, z), 0.06, 0.12, "offwhite", segments=6)
        b.cyl((x, y + 0.62, z), 0.07, 0.08, "caramel_wood", segments=6)
        b.span((x - 0.1, y + 0.12, z - 0.14), (x + 0.1, y + 0.28, z - 0.12), "cream")
    else:
        b.cyl((x, y + 0.14, z), 0.17, 0.28, sw, segments=8)
        b.cyl((x, y + 0.32, z), 0.12, 0.08, "caramel_wood", segments=8)
        b.span((x - 0.11, y + 0.08, z - 0.18), (x + 0.11, y + 0.2, z - 0.16), "cream")


def _sack(b, x, y, z, sw):
    """A kibble sack: a fat bag, its top rolled over in a cream band, a little fish on the front."""
    b.span((x - 0.26, y, z - 0.18), (x + 0.26, y + 0.5, z + 0.18), sw)
    b.span((x - 0.27, y + 0.5, z - 0.19), (x + 0.27, y + 0.6, z + 0.19), "cream")
    b.ball((x - 0.02, y + 0.25, z - 0.19), 0.12, "cream", scale=(1.0, 0.55, 0.15))
    b.fan_z(z - 0.195, (x + 0.08, y + 0.25), [(x + 0.16, y + 0.32), (x + 0.13, y + 0.25), (x + 0.16, y + 0.18)],
            0.02, "cream")


def _tin(b, x, y, z, n=1):
    """A stack of n tuna tins: silver with a blue label band and a cream lid."""
    for i in range(n):
        yy = y + i * 0.2
        b.cyl((x, yy + 0.09, z), 0.15, 0.18, "metal", segments=8)
        b.cyl((x, yy + 0.09, z), 0.155, 0.09, "fish_blue", segments=8)
        b.cyl((x, yy + 0.185, z), 0.13, 0.015, "offwhite", segments=8)


def _salmon(b, x, y, z):
    """A salmon lying on a little wooden board, head to the left."""
    b.span((x - 0.55, y, z - 0.2), (x + 0.55, y + 0.07, z + 0.2), "caramel_wood")
    b.ball((x - 0.05, y + 0.17, z), 0.4, "fur_peach", scale=(1.0, 0.28, 0.4))
    b.ball((x - 0.05, y + 0.12, z), 0.36, "fish_belly", scale=(1.0, 0.18, 0.36))
    b.fan_z(z, (x + 0.3, y + 0.17), [(x + 0.55, y + 0.33), (x + 0.48, y + 0.17), (x + 0.55, y + 0.02)], 0.06,
            "fur_rose")
    b.ball((x - 0.33, y + 0.2, z - 0.1), 0.035, "fur_black")


def _whistle(b, x, y, z):
    """The Cat Whistle on a cream card: a silver whistle with a gold ring."""
    b.box((x, y + 0.3, z), (0.4, 0.55, 0.04), "cream", rot=rot_x(-14))
    b.cyl((x, y + 0.36, z - 0.06), 0.07, 0.3, "metal", axis="X", segments=6)
    b.cyl((x + 0.13, y + 0.36, z - 0.06), 0.11, 0.12, "metal", axis="X", segments=8)
    b.cyl((x - 0.12, y + 0.36, z - 0.06), 0.08, 0.03, "rarity_legend", axis="X", segments=6)


def _tag(b, x, y, z):
    """A coin price tag on a pin: a cream card with a gold coin."""
    b.span((x - 0.015, y, z - 0.015), (x + 0.015, y + 0.3, z + 0.015), TRIM)
    b.span((x - 0.16, y + 0.28, z - 0.02), (x + 0.16, y + 0.48, z + 0.02), "cream")
    b.cyl((x - 0.07, y + 0.38, z - 0.03), 0.06, 0.02, "rarity_legend", axis="Z", segments=6)


def _goods(b):
    """A two-step display along the front half of the top board: the low row at the front, a riser behind."""
    riser = (-0.55, 0.05, 0.42)                                                     # its front, back and height
    b.span((OX - HX + 0.2, TOP, riser[0]), (OX + HX - 0.2, TOP + riser[2], riser[1]), "caramel_wood")
    b.span((OX - HX + 0.18, TOP + riser[2] - 0.14, riser[0] - 0.03), (OX + HX - 0.18, TOP + riser[2] - 0.03,
                                                                           riser[0] + 0.03), "fur_strawberry")   # its lip
    y1, y2, zf, zb = TOP, TOP + riser[2], -0.95, -0.25
    # the front row, left to right: kibble sacks, potions, the salmon, tuna tins
    _sack(b, OX - 2.45, y1, zf, "kibble")
    _sack(b, OX - 1.85, y1, zf, "treat_tan")
    for i, (shape, sw) in enumerate((("round", "sign_teal"), ("tall", "fur_strawberry"), ("squat", "pastel_lilac"),
                                     ("round", "rarity_legend"))):
        _potion(b, OX - 1.15 + i * 0.42, y1, zf + (0.05 if i % 2 else -0.05), shape, sw)
    _salmon(b, OX + 1.05, y1, zf + 0.05)
    _tin(b, OX + 2.0, y1, zf - 0.05, 2)
    _tin(b, OX + 2.45, y1, zf + 0.08, 1)
    # the riser: more potions, the Cat Whistle, a big sack and a tin pyramid
    for i, (shape, sw) in enumerate((("tall", "mint"), ("round", "pastel_sky"), ("tall", "shirt_blue"),
                                     ("squat", "fur_bubblegum"), ("round", "aurora_violet"))):
        _potion(b, OX - 2.5 + i * 0.4, y2, zb + (0.04 if i % 2 else -0.04), shape, sw)
    _whistle(b, OX - 0.35, y2, zb)
    _sack(b, OX + 0.4, y2, zb, "fur_strawberry")
    for x, n in ((OX + 1.3, 2), (OX + 1.62, 1), (OX + 1.94, 2)):
        _tin(b, x, y2, zb, n)
    _sack(b, OX + 2.55, y2, zb, "mint")
    for x in (OX - 2.15, OX - 0.45, OX + 1.5):                                      # price tags at the front edge
        _tag(b, x, y1, -HZ + 0.05)


def _cushion(b):
    cx, cz = CUSHION
    b.span((cx - 0.75, TOP, cz - 0.5), (cx + 0.75, TOP + CUSHION_H, cz + 0.5), "fur_strawberry")
    b.span((cx - 0.76, TOP + CUSHION_H / 2 - 0.03, cz - 0.51), (cx + 0.76, TOP + CUSHION_H / 2 + 0.03, cz + 0.51),
           "cream")                                                                 # piping
    for sx in (-1, 1):                                                              # a crate of goods either side
        x = cx + sx * 1.9
        b.span((x - 0.55, TOP, cz - 0.42), (x + 0.55, TOP + 0.55, cz + 0.42), "caramel_wood")
        for yy in (TOP + 0.15, TOP + 0.38):
            b.span((x - 0.57, yy, cz - 0.44), (x + 0.57, yy + 0.08, cz + 0.44), TRIM)
        for i, dx in enumerate((-0.25, 0.0, 0.25)):
            if sx < 0:
                _potion(b, x + dx, TOP + 0.55, cz + (0.12 if i % 2 else -0.12), "tall",
                        ("pastel_butter", "mint", "fur_strawberry")[i])
            else:
                b.ball((x + dx, TOP + 0.66, cz + (0.1 if i % 2 else -0.1)), 0.14, ("kibble", "treat_tan")[i % 2])


# ------------------------------------------------------------------ awning ---

def _awning(b, bulb):
    for x in (OX - POST_X, OX + POST_X):                                            # four candy-striped posts
        for z, top in ((POST_FZ, AWN_FY), (POST_BZ, AWN_BY)):
            b.span((x - 0.11, TOP, z - 0.11), (x + 0.11, top, z + 0.11), TRIM)
            for y in (3.0, 3.8, 4.6):
                b.span((x - 0.12, y, z - 0.12), (x + 0.12, y + 0.3, z + 0.12), "cream")
    depth, rise = AWN_BZ - AWN_FZ, AWN_BY - AWN_FY
    tilt = math.degrees(math.atan2(rise, depth))
    w = 2 * POST_X + 0.6
    sw_w = w / STRIPES
    vz = AWN_FZ + 0.06                                                              # the front valance's depth
    cy = AWN_FY - VAL_H + 0.01                                                      # its scallops' top edge
    for i in range(STRIPES):
        x = OX - w / 2 + sw_w * (i + 0.5)
        sw = AWNING[i % 2]
        b.box((x, (AWN_FY + AWN_BY) / 2 + 0.08, (AWN_FZ + AWN_BZ) / 2), (sw_w, 0.12, math.hypot(depth, rise)), sw,
              rot=rot_x(-tilt))                       # a negative turn lifts the back
        b.span((x - sw_w / 2, AWN_FY - VAL_H, vz - 0.05), (x + sw_w / 2, AWN_FY + 0.06, vz + 0.05), sw)
        arc = [(x + sw_w / 2 * math.cos(math.radians(a)), cy + sw_w / 2 * math.sin(math.radians(a)))
               for a in (180, 240, 300, 360)]
        b.fan_z(vz, (x, cy), arc, 0.1, sw)
        b.span((x - sw_w / 2, AWN_BY - 0.3, AWN_BZ - 0.12), (x + sw_w / 2, AWN_BY + 0.1, AWN_BZ - 0.02), sw)  # back
    for s in (-1, 1):                                                               # side edges
        x = OX + s * (w / 2 + 0.03)
        b.box((x, (AWN_FY + AWN_BY) / 2 + 0.08, (AWN_FZ + AWN_BZ) / 2), (0.06, 0.18, math.hypot(depth, rise)), TRIM,
              rot=rot_x(-tilt))
    # the lantern: an arm off the front right post's top, a chain, a cap and the bulb
    lx, ly, lz = OX + POST_X + 0.6, AWN_FY - 0.85, POST_FZ - 0.05
    b.span((OX + POST_X + 0.11, AWN_FY - 0.62, lz - 0.04), (lx + 0.04, AWN_FY - 0.54, lz + 0.04), "fur_black")
    b.span((lx - 0.03, ly + 0.22, lz - 0.03), (lx + 0.03, AWN_FY - 0.54, lz + 0.03), "fur_black")
    b.cyl((lx, ly + 0.18, lz), 0.22, 0.1, "fur_black", r2=0.08, segments=8)
    b.cyl((lx, ly - 0.24, lz), 0.17, 0.06, "fur_black", segments=8)
    bulb.ball((lx, ly - 0.03, lz), 0.16, "lamp_warm")


def _sun(b, x, y, z, r, rays=8, depth=0.05):
    """A painted sun on a face at depth z: a gold disc with short rays."""
    b.cyl((x, y, z), r, depth, "rarity_legend", axis="Z", segments=12)
    for k in range(rays):
        a = math.radians(k * 360 / rays)
        b.box((x + math.cos(a) * r * 1.35, y + math.sin(a) * r * 1.35, z), (r * 0.5, r * 0.18, depth), "pastel_butter",
              rot=rot_z(k * 360 / rays))


def _sign(b):
    """The DAY CART board standing on the awning's back half: a cream board in a choco frame, a sun at each end of the
    words, and a big sun painted on its back."""
    text = "DAY CART"
    tw = text_width(text, SIGN_PX)
    w = tw + 1.7
    zf = 0.6                                                                        # the board's front face
    y0 = AWN_FY + (AWN_BY - AWN_FY) * (zf - AWN_FZ) / (AWN_BZ - AWN_FZ) + 0.32
    y1 = y0 + 1.3
    b.span((OX - w / 2, y0, zf), (OX + w / 2, y1, zf + 0.25), "cream")
    for (xa, xb, ya, yb) in ((OX - w / 2 - 0.14, OX + w / 2 + 0.14, y0 - 0.12, y0 + 0.02),
                             (OX - w / 2 - 0.14, OX + w / 2 + 0.14, y1 - 0.02, y1 + 0.12),
                             (OX - w / 2 - 0.14, OX - w / 2 + 0.01, y0, y1), (OX + w / 2 - 0.01, OX + w / 2 + 0.14, y0, y1)):
        b.span((xa, ya, zf - 0.07), (xb, yb, zf + 0.32), TRIM)
    label(b, text, OX, (y0 + y1) / 2 - 2.5 * SIGN_PX, zf + 0.01, SIGN_PX, 0.07, "fur_strawberry", -1)
    for s in (-1, 1):
        _sun(b, OX + s * (tw / 2 + 0.45), (y0 + y1) / 2, zf - 0.02, 0.22)
    _sun(b, OX, (y0 + y1) / 2, zf + 0.27, 0.36, rays=12)                          # on its back
    for s in (-1, 1):                                                               # two legs down to the canopy
        x = OX + s * (w / 2 - 0.5)
        b.span((x - 0.1, y0 - 0.75, zf + 0.03), (x + 0.1, y0 - 0.1, zf + 0.22), TRIM)


def build_day_cart(mat):
    b, bulb = RB(), RB()
    _body(b)
    _under(b)
    _goods(b)
    _cushion(b)
    _awning(b, bulb)
    _sign(b)
    out = [b.finalize(NAME, mat), bulb.finalize(NAME + "_Bulb", mat)]
    spec = cornershop.CAT
    base = NAME + "_Cat"                                                            # the shopkeeper, as before
    cat = cats.build_cat("DayCartCat", mat, spec=spec, base=base, body="sit")
    d = cats.dims(spec, "sit")
    ctx = props.Ctx(spec, "sit", d)
    cornershop.visor(ctx)
    k = cats.scale_of(spec, "sit")
    hat = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hat, k)
    hat["rides"] = "Head"
    cx, cz = CUSHION
    for ob in cat + [hat]:
        ob.location = ob.location + Vector(RB.p(cx, TOP + CUSHION_H - 0.01, cz))
    return out + cat + [hat]


def prompt_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor on the cart."""
    return (NAME, "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX))))


ASSETS = {
    NAME: (build_day_cart, 7000),
}
