"""The Golden Fish Market (golden-fish.md section 3, F53): a fishmonger's stall in the street plaza where golden fish
buy crates, perks and Star Treats. A blue and white striped awning over a counter with golden fish laid on ice, the
golden fish coin on the counter front, a FISH MARKET sign, and behind the counter a grey and white cat in a yellow
sou'wester. A crate of fish and a barrel stand at the sides.

  CatCafe_Street_FishMarket               counter, posts, back board, awning, sign, crate and barrel (collides),
                                          with an Attachment PromptAnchor in its PrimaryPart where WorldBuilder hangs
                                          the Shop prompt: the middle of the counter front, 3 studs up
  CatCafe_Street_FishMarket_Coin          the golden fish coin on the counter front (coins.py, smaller)
  CatCafe_Street_FishMarket_Bulb          the sign lamp, lit at night
  CatCafe_Street_FishMarket_Cat_<Piece>   the shopkeeper, the same hinged pieces as every sitting cat; its hat
                                          (_Cat_Prop) rides inside the Head Model

Pivot at the base centre, the counter front (-Z) toward the players. Footprint about 11 x 4.5 studs. The server
places it at street plaza x -8.5, z 64, turned -90 degrees, and tags it FishMarket.
"""

import math

from mathutils import Matrix, Vector

import cats
import coins
import props
from alleyway import label
from common import RB, scale_mesh, text_width
from plot import rot_x, rot_z

HW, C_FRONT, C_BACK, C_H = 3.6, -1.3, 0.0, 2.5       # the counter: half width, front, back, height
TOP = C_H + 0.15                                     # the ledge top
SEAT_Y, CAT_Z = 2.1, 0.95                            # the stool top and the cat's pivot (Roblox z)
WALL_Z, WALL_TOP = 1.9, 7.2                          # the back board's front face and top
AWN_FRONT, AWN_Y = -1.75, 6.3                        # the awning's front edge (the posts)
VAL_H, STRIPES = 0.45, 10                           # the valance hanging from it, and the stripes
PROMPT_ROBLOX = (0.0, 3.0, C_FRONT - 0.4)
COIN_K = 0.62                                        # the coin on the counter front, scaled from coins.R = 1

# Grey and white: not a collectable coat, and the yellow hat says fishmonger.
CAT = dict(rarity="Common", fur="fur_grey", second="fur_white", eyes="eye_green", pattern="patches", muzzle="fur_white",
           scale=1.5)
FISH = ("gold_mid", "gold_light")
ICE = "milk"


def souwester(ctx):
    """A yellow sou'wester: a rounded crown and a wide brim that runs longer down the back."""
    P = ctx.pen("head")
    P.cyl((0, 0.03, 0.16), 0.46, 0.32, "fur_golden", r2=0.34, segments=14)                  # crown, over the ears
    P.cyl((0, 0.03, 0.335), 0.34, 0.05, "fur_golden", r2=0.2, segments=14)
    P.cyl((0, 0.06, 0.02), 0.66, 0.05, "fur_golden", segments=16)                           # brim
    P.box((0, 0.66, -0.1), (0.96, 0.4, 0.05), "fur_golden", rot=props._rx(-26))             # the long back flap
    P.cyl((0, 0.03, 0.07), 0.455, 0.06, "fur_orange_dark", segments=14)                      # band


def _fish_flat(b, x, y, z, d, sw, s=1.0):
    """A golden fish lying on its side on a flat bed whose top is y; its tail toward +x when d is 1."""
    b.ball((x, y + 0.1 * s, z), 0.5 * s, sw, scale=(1.0, 0.22, 0.42))
    tx = x + d * 0.42 * s                                                              # the tail, flat on the bed
    pts = [(tx + d * 0.32 * s, z + 0.22 * s), (tx + d * 0.25 * s, z), (tx + d * 0.32 * s, z - 0.22 * s)]
    b.b.fan(RB.p(0, y + 0.06 * s, 0), (-tx, z), [(-px, pz) for px, pz in pts], 0.08 * s, sw)
    b.cyl((x - d * 0.3 * s, y + 0.2 * s, z + 0.03 * s), 0.06 * s, 0.04, "fur_black", segments=8)


def _counter(b):
    b.span((-HW, 0, C_FRONT), (HW, C_H, C_BACK), "offwhite")
    b.span((-HW - 0.05, 0, C_FRONT - 0.05), (HW + 0.05, 0.3, C_BACK + 0.05), "pants_navy")             # kick
    b.span((-HW - 0.05, 2.1, C_FRONT - 0.05), (HW + 0.05, C_H, C_BACK + 0.05), "shirt_blue")           # band
    for sx in (-1, 1):                                                               # side panels with a blue fish
        x0, x1 = sorted((sx * 1.15, sx * 3.25))
        b.span((x0, 0.6, C_FRONT - 0.04), (x1, 1.85, C_FRONT + 0.01), "pastel_sky")
        cx = sx * 2.2
        b.ball((cx, 1.22, C_FRONT - 0.05), 0.55, "shirt_blue", scale=(1.0, 0.42, 0.1))
        b.fan_z(C_FRONT - 0.06, (cx + sx * 0.45, 1.22), [(cx + sx * 0.8, 1.5), (cx + sx * 0.72, 1.22),
                                                        (cx + sx * 0.8, 0.94)], 0.05, "shirt_blue")
        b.cyl((cx - sx * 0.3, 1.28, C_FRONT - 0.1), 0.06, 0.03, "offwhite", axis="Z", segments=8)
    b.span((-HW - 0.15, C_H - 0.01, C_FRONT - 0.15), (HW + 0.15, TOP, C_BACK + 0.1), "caramel_wood")    # ledge


def _ice(b):
    """Two steps of ice on the ledge, golden fish laid on them, lemon slices and parsley."""
    f0, f1, b0, b1 = C_FRONT + 0.1, -0.62, -0.62, C_BACK - 0.05
    yf, yb = TOP + 0.3, TOP + 0.65
    b.span((-HW + 0.2, TOP - 0.01, f0), (HW - 0.2, yf, f1 + 0.01), ICE)
    b.span((-HW + 0.2, TOP - 0.01, b0), (HW - 0.2, yb, b1), ICE)
    for i, x in enumerate((-2.4, -0.8, 0.8, 2.4)):
        _fish_flat(b, x, yf, (f0 + f1) / 2, (-1, 1)[i % 2], FISH[i % 2])
    for i, x in enumerate((-1.6, 0.0, 1.6)):
        _fish_flat(b, x, yb, (b0 + b1) / 2, (1, -1)[i % 2], FISH[(i + 1) % 2])
    for x, z in ((-3.15, -0.9), (-0.02, -0.82), (3.12, -1.0)):                         # lemon slices
        b.cyl((x, yf + 0.02, z), 0.2, 0.06, "fur_golden", segments=10)
        b.cyl((x, yf + 0.045, z), 0.14, 0.03, "pastel_butter", segments=10)
    for x, z in ((-1.6, -1.0), (1.62, -0.78), (-2.9, -0.3), (2.85, -0.36)):           # parsley
        y = yf if z < f1 else yb
        for dx, dz in ((0, 0), (0.12, 0.08), (-0.1, 0.1)):
            b.ball((x + dx, y + 0.05, z + dz), 0.11, "leaf_green")
    for x, z in ((-2.0, -0.4), (1.1, -0.32), (2.0, -1.12), (-1.1, -0.95)):           # ice cubes
        y = yf if z < f1 else yb
        b.box((x, y + 0.08, z), (0.2, 0.2, 0.2), "pastel_sky", rot=rot_z(45))


def _back(b, bulb):
    """Stool, back board, posts, the striped awning and the FISH MARKET sign with its lamp."""
    b.span((-0.75, 0, CAT_Z - 0.75), (0.75, SEAT_Y, CAT_Z + 0.75), "dark_wood")                         # stool
    b.span((-0.85, SEAT_Y - 0.01, CAT_Z - 0.8), (0.85, SEAT_Y + 0.12, CAT_Z + 0.8), "pastel_sky")       # cushion
    bw = HW + 0.25
    b.span((-bw, 0, WALL_Z), (bw, WALL_TOP, WALL_Z + 0.3), "pastel_sky")
    for y in (0.9, 2.2, 3.5, 4.8, 6.1):                                             # tile lines on the board
        b.span((-bw + 0.01, y, WALL_Z - 0.02), (bw - 0.01, y + 0.08, WALL_Z + 0.01), "offwhite")
    for x in (-2.4, 0.0, 2.4):                                                      # a net hung on the board
        b.span((x - 0.03, 3.6, WALL_Z - 0.06), (x + 0.03, 5.4, WALL_Z - 0.02), "caramel_wood")
    for sx in (-1, 1):                                                              # front posts
        b.span((sx * (HW + 0.25) - 0.15, 0, AWN_FRONT - 0.15), (sx * (HW + 0.25) + 0.15, AWN_Y, AWN_FRONT + 0.15),
               "pants_navy")
    vz = AWN_FRONT - 0.22                                                           # the valance, before the posts
    zc = vz - 0.05                                                                  # the canopy's front edge
    depth, rise = WALL_Z + 0.3 - zc, WALL_TOP - AWN_Y
    tilt = math.atan2(rise, depth)
    w = 2 * bw + 0.4
    sw_w = w / STRIPES
    cy = AWN_Y - VAL_H + 0.01                                                       # the scallops' top edge
    for i in range(STRIPES):                                                        # the striped awning
        x = -w / 2 + sw_w * (i + 0.5)
        sw = ("shirt_blue", "offwhite")[i % 2]
        b.box((x, (AWN_Y + WALL_TOP) / 2 + 0.07, (zc + WALL_Z + 0.3) / 2), (sw_w, 0.12, math.hypot(depth, rise)),
              sw, rot=rot_x(-math.degrees(tilt)))                          # a negative turn lifts the back
        b.span((x - sw_w / 2, AWN_Y - VAL_H, vz - 0.05), (x + sw_w / 2, AWN_Y + 0.06, vz + 0.05), sw)
        arc = [(x + sw_w / 2 * math.cos(math.radians(a)), cy + sw_w / 2 * math.sin(math.radians(a)))
               for a in (180, 240, 300, 360)]
        b.fan_z(vz, (x, cy), arc, 0.1, sw)
    text, px = "FISH MARKET", 0.2
    sw_ = text_width(text, px) + 1.2
    y0, y1, zf = WALL_TOP + 0.2, WALL_TOP + 1.7, WALL_Z - 0.05
    b.span((-sw_ / 2, y0 - 0.01, zf), (sw_ / 2, y1, zf + 0.3), "offwhite")
    for (xa, xb, ya, yb) in ((-sw_ / 2 - 0.15, sw_ / 2 + 0.15, y0 - 0.03, y0 + 0.15),
                             (-sw_ / 2 - 0.15, sw_ / 2 + 0.15, y1 - 0.15, y1 + 0.01),
                             (-sw_ / 2 - 0.15, -sw_ / 2 + 0.01, y0, y1), (sw_ / 2 - 0.01, sw_ / 2 + 0.15, y0, y1)):
        b.span((xa, ya, zf - 0.08), (xb, yb, zf + 0.34), "shirt_blue")
    label(b, text, 0, (y0 + y1) / 2 - 2.5 * px, zf + 0.01, px, 0.07, "shirt_blue", -1)
    label(b, text, 0, (y0 + y1) / 2 - 2.5 * px, zf + 0.29, px, 0.07, "shirt_blue", 1)           # and from behind
    b.span((-sw_ / 2 + 0.3, WALL_TOP - 0.01, zf + 0.05), (-sw_ / 2 + 0.5, y0, zf + 0.25), "pants_navy")   # legs
    b.span((sw_ / 2 - 0.5, WALL_TOP - 0.01, zf + 0.05), (sw_ / 2 - 0.3, y0, zf + 0.25), "pants_navy")
    b.span((-0.05, y1, zf + 0.1), (0.05, y1 + 0.6, zf + 0.2), "fur_black")                          # lamp
    b.span((-0.05, y1 + 0.5, zf - 0.6), (0.05, y1 + 0.6, zf + 0.2), "fur_black")
    b.cyl((0, y1 + 0.35, zf - 0.6), 0.32, 0.18, "fur_black", r2=0.12)
    bulb.ball((0, y1 + 0.2, zf - 0.6), 0.16, "lamp_warm")


def _sides(b):
    """A crate of fish on the left and a barrel with fish on ice on the right."""
    cx, cz = -HW - 1.25, -0.55
    b.span((cx - 0.65, 0, cz - 0.55), (cx + 0.65, 1.1, cz + 0.55), "caramel_wood")
    for y in (0.3, 0.75):                                                           # slats
        b.span((cx - 0.67, y, cz - 0.57), (cx + 0.67, y + 0.12, cz + 0.57), "dark_wood")
    b.span((cx - 0.55, 1.09, cz - 0.45), (cx + 0.55, 1.15, cz + 0.45), ICE)
    for i, (dx, dz, a) in enumerate(((-0.25, -0.15, 20), (0.2, 0.1, -25), (0.0, 0.25, 5))):
        x, z = cx + dx, cz + dz
        b.ball((x, 1.25, z), 0.32, FISH[i % 2], scale=(0.45, 1.0, 0.25))           # standing up, heads down
        b.b.fan(RB.p(x, 1.6, z), (0, 0), [(0.18, 0.28), (0.0, 0.2), (-0.18, 0.28)], 0.05, FISH[i % 2],
                rot=(math.radians(90), "X"))
    bx, bz = HW + 1.2, -0.5
    b.cyl((bx, 0.65, bz), 0.6, 1.3, "dark_wood", segments=12)
    for y in (0.25, 1.05):
        b.cyl((bx, y, bz), 0.62, 0.1, "metal", segments=12)
    b.cyl((bx, 1.31, bz), 0.52, 0.06, ICE, segments=12)
    _fish_flat(b, bx, 1.34, bz, -1, FISH[0], s=0.75)


def build_fish_market(mat):
    name = "CatCafe_Street_FishMarket"
    b, bulb = RB(), RB()
    _counter(b)
    _ice(b)
    _back(b, bulb)
    _sides(b)
    out = [b.finalize(name, mat), bulb.finalize(name + "_Bulb", mat)]
    coin = coins.build_fish_coin(mat, name + "_Coin")[0]                                # on the counter front
    scale_mesh(coin, COIN_K)
    coin.location = coin.location + Vector(RB.p(0, 0.55, C_FRONT - coins.T * COIN_K / 2 + 0.01))
    out.append(coin)
    base = name + "_Cat"                                                                 # the shopkeeper
    cat = cats.build_cat("FishMarketCat", mat, spec=CAT, base=base, body="sit")
    d = cats.dims(CAT, "sit")
    ctx = props.Ctx(CAT, "sit", d)
    souwester(ctx)
    k = cats.scale_of(CAT, "sit")
    hat = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hat, k)
    hat["rides"] = "Head"
    for ob in cat + [hat]:
        ob.location = ob.location + Vector(RB.p(0, SEAT_Y + 0.11, CAT_Z))
    return out + cat + [hat]


def prompt_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor on the stall."""
    return ("CatCafe_Street_FishMarket", "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX))))


ASSETS = {
    "CatCafe_Street_FishMarket": (build_fish_market, 6000),
}
