"""Area gates (data-model section 9, world-and-feel.md section 2): an arch over each area's opening with a
see-through barrier and a sign board, the way simulator zone gates work, themed per area with our own art.

  CatCafe_Park_Gate            32 wide opening, street's south end (0, -125)
  CatCafe_Neighbourhood_Gate   32 wide, street's north end (0, 125)
  CatCafe_Woods_Gate           24 wide, west back alley's outer wall (-94, 0), turned -90
  CatCafe_Sewer_Gate           24 wide, east back alley's outer wall (94, 0), turned 90
  CatCafe_Desert_Gate          24 wide, Tier 6 (#2651): the Desert's camp opening
  CatCafe_Ruins_Gate           24 wide, Tier 7 (#2651): the Ruins' camp opening
  CatCafe_Snowy_Gate           24 wide, Tier 8 (#3997): the Snowy Mountain's camp opening
  CatCafe_WaterPark_Gate       24 wide, Tier 9 (#4066): the Water Park's camp opening
  CatCafe_Castle_Gate          24 wide, Tier 10 (#4067): the Medieval Castle's camp opening

The Park and Neighbourhood openings follow the street (town-layout-v3.md: StreetHalfWidth 16); the Woods and Sewer
openings are SideGateHalfWidth 12 either side of z 0 (section 7, v3.1).

Pivot at the base centre of the opening. The front (-Z) faces the side players come from (Layout.gateTurn).
WorldBuilder's area walls (1 thick, at local z 0.5 to 1.5, ending at the edge of the opening) meet each gate, and on
the Woods and Sewer gates the back alley's outer wall runs the same way just in front (local z -1 to 0), so the pillars
reach INSET into the opening and FRONT and BACK either side of the gate line, which buries every wall end inside a
pillar, and nothing beside a pillar sits on the wall line (local z -1 to 1.6).
Objects per gate:
  <asset>              pillars, lintel with the area name on both faces, decoration (collides)
  <asset>_Bars         one box filling the opening up to 12 studs: exported as a ForceField part named Bars directly
                       under the gate, the only part WorldController makes walkable once the gate opens
  <asset>_SignBoard    10 x 2.5 board hanging in front of the barrier; its -Z face takes the requirement SurfaceGui
  <asset>_Lamp_Bulb    lanterns, lit at night
  <asset>_Flowers      planters and flower beds, where the effects code sends butterflies
"""

import math

from alleyway import bar, flower_clump, label, lantern
from common import RB, text_width
from plot import TRIM, rot_y, rot_z

BARS_TOP = 12.0
PILLAR = 2.6
INSET = 0.12                                       # the pillars start this far inside the opening, past the wall ends
FRONT, BACK = 1.3, 1.75                            # pillar depth either side of the gate line: the walls behind it
                                                   # (z 0.5 to 1.5) end inside, the alley's building backs stay clear
SIGN = (-5.0, 5.0, 8.4, 10.9)                      # x0, x1, y0, y1 of the hanging sign board, at z -0.85..-0.65
SIGN_PX = 0.26                                     # the hanging board's lettering: 1.3 studs tall, WELCOME! 8.6 wide
SIGN_INFO = {"part": "SignBoard", "face": "Front (-Z)", "size": [10.0, 2.5], "centre": [0.0, 9.65, -0.85]}


def _sign(b, sign, frame, top):
    x0, x1, y0, y1 = SIGN
    sign.span((x0, y0, -0.85), (x1, y1, -0.65), "offwhite")
    for (xa, xb, ya, yb) in ((x0 - 0.2, x1 + 0.2, y0 - 0.2, y0), (x0 - 0.2, x1 + 0.2, y1, y1 + 0.2),
                             (x0 - 0.2, x0, y0, y1), (x1, x1 + 0.2, y0, y1)):
        b.span((xa, ya, -0.9), (xb, yb, -0.6), frame)
    for x in (x0 + 0.8, x1 - 0.8):                                                         # chains
        b.span((x - 0.06, y1 + 0.2, -0.8), (x + 0.06, top, -0.7), "metal")
    # #1192: the area's lock and progress are a BillboardGui over the gate (UI GateSigns), so nothing draws on this
    # board; it reads WELCOME! toward the approach side (-Z) and SEE YOU! toward the area, in the frame's colour
    ym = (y0 + y1) / 2 - 2.5 * SIGN_PX
    label(b, "WELCOME!", 0, ym, -0.85, SIGN_PX, 0.05, frame, -1)
    label(b, "SEE YOU!", 0, ym, -0.65, SIGN_PX, 0.05, frame, 1)


def _title(b, text, y, px, z_front, z_back, swatch):
    label(b, text, 0, y, z_front, px, 0.06, swatch, -1)
    label(b, text, 0, y, z_back, px, 0.06, swatch, 1)


def _gate(name, mat, width, barrier, frame, build):
    b, bars, sign, lamps, flowers = RB(), RB(), RB(), RB(), RB()
    half = width / 2
    bars.span((-half, 0, -0.2), (half, BARS_TOP, 0.2), barrier)
    top = build(b, lamps, flowers, half)
    _sign(b, sign, frame, top)
    out = [b.finalize(name, mat), bars.finalize(name + "_Bars", mat), sign.finalize(name + "_SignBoard", mat),
           lamps.finalize(name + "_Lamp_Bulb", mat)]
    if flowers.b.prims:
        out.append(flowers.finalize(name + "_Flowers", mat))
    return out


def _pillar_x(s, half):
    """The pillar on side s: its x range and centre."""
    x0, x1 = sorted((s * (half - INSET), s * (half + PILLAR)))
    return x0, x1, (x0 + x1) / 2


def _brick_pillars(b, half, cap="concrete", h=13.5):
    for s in (-1, 1):
        x0, x1, _ = _pillar_x(s, half)
        b.span((x0 - 0.2, 0, -FRONT - 0.2), (x1 + 0.2, 0.8, BACK + 0.2), "concrete")
        b.span((x0, 0.8, -FRONT), (x1, h, BACK), "brick")
        for y in (4.5, 9.0):
            b.span((x0 - 0.12, y, -FRONT - 0.12), (x1 + 0.12, y + 0.4, BACK + 0.12), "concrete")
        b.span((x0 - 0.2, h, -FRONT - 0.2), (x1 + 0.2, h + 0.6, BACK + 0.2), cap)


# --------------------------------------------------------------------------------------------- park --
def _park(b, lamps, flowers, half):
    _brick_pillars(b, half)
    for s in (-1, 1):
        cx = _pillar_x(s, half)[2]
        lantern(b, lamps, cx, 14.1, 0, 1.1)
        for (y, dz) in ((2.0, -1.0), (5.6, -0.5), (8.3, -1.1), (11.2, -0.4)):              # ivy on the outer face,
            b.ball((s * (half + PILLAR + 0.2), y, dz), 0.7, "leaf_dark", scale=(0.6, 1.0, 1.0))   # off the wall line
        for z in (-2.6, 2.6):                                                              # planters
            b.span((cx - 1.2, 0, z - 0.5), (cx + 1.2, 1.0, z + 0.5), "terracotta")
            flowers.span((cx - 1.1, 1.0, z - 0.4), (cx + 1.1, 1.15, z + 0.4), "leaf_green")
            for k in range(3):
                flower_clump(flowers, cx - 0.7 + 0.7 * k, 1.15, z, n=3, spread=0.3)
        b.ball((s * (half + PILLAR + 0.8), 1.05, -2.3), 1.2, "leaf_green", scale=(1.0, 0.85, 0.9))  # bush by the planter
    # green iron frame and the name board
    for y0, y1 in ((12.2, 12.6), (15.0, 15.4)):
        b.span((-half, y0, -0.3), (half, y1, 0.3), "dumpster_green")
    px = 0.45
    bw = text_width("THE PARK", px) + 3.0
    b.span((-bw / 2, 12.6, -0.25), (bw / 2, 15.0, 0.25), "mint")
    _title(b, "THE PARK", 12.68, px, -0.25, 0.25, "offwhite")
    for s in (-1, 1):                                                                      # scrolls beside the board
        for k in range(3):
            x = s * (bw / 2 + 0.9 + k * (half - bw / 2 - 1.2) / 2.5)
            b.cyl((x, 13.8, 0), 0.55, 0.15, "dumpster_green", axis="Z", segments=10)
            b.cyl((x, 13.8, 0), 0.38, 0.2, "mint", axis="Z", segments=10)
    for dx in (-0.9, 0, 0.9):                                                              # leaf crest
        b.ball((dx, 16.1 + (0.3 if dx == 0 else 0), 0), 0.7, "leaf_green")
    b.cyl((0, 15.9, 0), 0.6, 0.35, "rarity_legend", axis="Z", segments=12)
    return 12.2


def build_park_gate(mat):
    return _gate("CatCafe_Park_Gate", mat, 32.0, "mint", "dumpster_green", _park)


def build_park_gate_f85(mat):
    """F85: the same gate over the long Park's 24 stud opening (Config.World.CampOpeningWidth)."""
    return _gate("CatCafe_Park_GateF85", mat, 24.0, "mint", "dumpster_green", _park)


# -------------------------------------------------------------------------------------------- woods --
def _spruce(b, x, z, s=1.0):
    b.cyl((x, 0.6 * s, z), 0.3 * s, 1.2 * s, "fur_brown", segments=8)
    for k, (y, r) in enumerate(((1.2, 1.7), (2.6, 1.35), (3.9, 1.0))):
        b.cyl((x, (y + 1.2) * s, z), r * s, 2.4 * s, "leaf_dark" if k % 2 == 0 else "leaf_green", r2=0.15 * s,
              segments=10)


def _woods(b, lamps, flowers, half):
    for s in (-1, 1):                                  # square timber posts on stone footings, so the walls end inside
        x0, x1, cx = _pillar_x(s, half)
        b.span((x0 - 0.25, 0, -FRONT - 0.25), (x1 + 0.25, 0.9, BACK + 0.25), "fur_smoke_light")
        b.span((x0, 0.9, -FRONT), (x1, 14.0, BACK), "fur_brown")
        for xa in (x0, x1):                                                                # corner battens
            for za in (-FRONT, BACK):
                b.span((xa - 0.17, 0.9, za - 0.17), (xa + 0.17, 13.9, za + 0.17), "dark_wood")
        for y in (3.0, 7.0, 11.0):                                                         # bands
            b.span((x0 - 0.22, y, -FRONT - 0.22), (x1 + 0.22, y + 0.25, BACK + 0.22), "dark_wood")
        b.ball((cx, 14.0, (BACK - FRONT) / 2), 1.7, "leaf_green", scale=(1.0, 0.5, 1.3))
        # mushrooms, clear of the alley wall; #3349: the first stood at dx 0.9, round the Woods camp's lantern post
        for (dx, dz, h, r) in ((-0.25, -2.3, 0.7, 0.45), (1.6, -2.15, 0.45, 0.3), (0.2, 2.35, 0.6, 0.4)):
            mx = cx + s * dx
            b.cyl((mx, h / 2, dz), 0.1, h, "offwhite", segments=6)
            b.cyl((mx, h + r * 0.3, dz), r, r * 0.6, "bowl_red", r2=0.05, segments=10)
            b.span((mx + r * 0.3 - 0.06, h + r * 0.45, dz - r * 0.5 - 0.02), (mx + r * 0.3 + 0.06, h + r * 0.57, dz - r * 0.5 + 0.1),
                   "offwhite")
        _spruce(b, s * (half + PILLAR + 1.9), 3.4)                                         # inside the area
        _spruce(b, s * (half + PILLAR + 0.6), 6.8, 0.7)
        fx = cx + s * 0.8
        flowers.span((fx - 0.7, 0, -3.6), (fx + 0.7, 0.15, -2.8), "leaf_green")
        flower_clump(flowers, fx, 0.15, -3.2, colours=("sparkle", "offwhite", "pastel_lilac"), n=4, spread=0.4)
    length = 2 * (half + PILLAR + 0.6)
    b.cyl((0, 13.3, 0), 1.1, length, "fur_brown", axis="X", segments=12)                  # beam log
    for s in (-1, 1):
        b.cyl((s * length / 2, 13.3, 0), 1.0, 0.06, "treat_tan", axis="X", segments=12)
        b.cyl((s * length / 2, 13.3, 0), 0.5, 0.08, "caramel_wood", axis="X", segments=10)
    for x in (-6.0, 1.5, 8.0):
        b.ball((x, 14.25, 0.2), 0.8, "leaf_green", scale=(1.4, 0.5, 1.0))
    px = 0.45
    bw = text_width("THE WOODS", px) + 2.4
    b.span((-bw / 2, 14.4, -0.2), (bw / 2, 16.9, 0.2), "caramel_wood")                    # carved plank
    for s in (-1, 1):
        b.span((s * bw / 2 - 0.3, 14.35, -0.25), (s * bw / 2 + 0.3, 16.95, 0.25), "dark_wood")
    _title(b, "THE WOODS", 14.52, px, -0.2, 0.2, "dark_wood")
    for x in (-half / 2, half / 2):                                                        # hanging lanterns
        b.span((x - 0.05, 11.6, -1.3), (x + 0.05, 12.25, -1.2), "fur_black")
        lantern(b, lamps, x, 10.2, -1.25, 0.8)
    return 12.2


def build_woods_gate(mat):
    return _gate("CatCafe_Woods_Gate", mat, 24.0, "leaf_green", "dark_wood", _woods)


# -------------------------------------------------------------------------------------------- sewer --
def _sewer(b, lamps, flowers, half):
    for s in (-1, 1):
        x0, x1, cx = _pillar_x(s, half)
        b.span((x0 - 0.2, 0, -FRONT - 0.2), (x1 + 0.2, 0.8, BACK + 0.2), "concrete")
        b.span((x0, 0.8, -FRONT), (x1, 13.6, BACK), "concrete_dark")
        for k in range(4):                                                                 # hazard collar
            y = 0.9 + k * 0.4
            b.span((x0 - 0.06, y, -FRONT - 0.06), (x1 + 0.06, y + 0.4, BACK + 0.06),
                   "rarity_legend" if k % 2 == 0 else "fur_black")
        b.span((x0 - 0.2, 13.6, -FRONT - 0.2), (x1 + 0.2, 14.0, BACK + 0.2), "concrete")
        b.span((cx - 0.5, 14.0, -0.5), (cx + 0.5, 14.3, 0.5), "fur_black")               # warning lamp
        lamps.span((cx - 0.35, 14.3, -0.35), (cx + 0.35, 15.0, 0.35), "bowl_red")
        b.span((cx - 0.45, 15.0, -0.45), (cx + 0.45, 15.15, 0.45), "fur_black")
        px_, pz = s * (half + PILLAR + 0.4), -1.75                                         # side pipe with a valve,
        b.cyl((px_, 6.0, pz), 0.35, 12.0, "rust", segments=10)                             # in front of the alley wall
        for y in (3.0, 9.0):                                                               # brackets back to it
            b.span((px_ - 0.12, y - 0.12, pz + 0.3), (px_ + 0.12, y + 0.12, -0.95), "metal")
        b.cyl((px_ + s * 0.45, 4.2, pz), 0.6, 0.12, "bowl_red", axis="X", segments=12)
        b.cyl((px_ + s * 0.45, 4.2, pz), 0.25, 0.2, "metal", axis="X", segments=8)
        for y in (2.0, 10.0):
            b.cyl((px_, y, pz), 0.45, 0.3, "metal", segments=10)
    length = 2 * (half + PILLAR + 0.4)
    b.cyl((0, 13.4, 0), 1.25, length, "metal", axis="X", segments=14)                     # big pipe
    for x in (-half - PILLAR / 2, -half / 2, 0.0, half / 2, half + PILLAR / 2):
        b.cyl((x, 13.4, 0), 1.45, 0.3, "rust", axis="X", segments=14)
    for (x, ln) in ((-9.0, 0.9), (-3.5, 0.5), (4.0, 1.1), (10.5, 0.6)):                    # slime drips
        b.span((x - 0.15, 12.15 - ln, -0.25), (x + 0.15, 12.25, -0.05), "leaf_green")         # hanging from the pipe
    px = 0.45
    bw = text_width("THE SEWER", px) + 2.4
    b.span((-bw / 2, 14.6, -0.18), (bw / 2, 17.0, 0.18), "concrete_dark")                 # name plate
    for k in range(int(bw / 0.8)):                                                         # hazard top edge
        x = -bw / 2 + k * 0.8
        b.span((x, 17.0, -0.2), (x + 0.8, 17.3, 0.2), "rarity_legend" if k % 2 == 0 else "fur_black")
    _title(b, "THE SEWER", 14.68, px, -0.18, 0.18, "rarity_legend")
    for k in range(-2, 3):                                                                 # floor grate and slime
        b.span((k * 0.8 - 0.08, 0, -3.6), (k * 0.8 + 0.08, 0.06, -2.4), "fur_black")
    b.span((-2.0, 0, -3.65), (2.0, 0.06, -3.5), "fur_black")
    b.span((-2.0, 0, -2.5), (2.0, 0.06, -2.35), "fur_black")
    for (x, z, r) in ((-9.5, -2.0, 1.3), (8.0, -1.8, 0.9), (11.0, -2.6, 0.6)):
        b.cyl((x, 0.03, z), r, 0.06, "leaf_green", segments=12)
    return 12.15


def build_sewer_gate(mat):
    return _gate("CatCafe_Sewer_Gate", mat, 24.0, "eye_green", "rarity_legend", _sewer)


# ------------------------------------------------------------------------------------ neighbourhood --
def _neighbourhood(b, lamps, flowers, half):
    _brick_pillars(b, half, cap="offwhite", h=12.0)
    for s in (-1, 1):
        cx = _pillar_x(s, half)[2]
        for z, sg in ((-FRONT - 0.02, -1), (BACK + 0.02, 1)):                             # plaque with a paw
            b.span((cx - 0.6, 6.4, min(z, z + sg * 0.06)), (cx + 0.6, 7.6, max(z, z + sg * 0.06)), "offwhite")
            zz = z + sg * 0.06
            for (dx, dy, r) in ((0, -0.15, 0.22), (-0.28, 0.2, 0.09), (0, 0.3, 0.09), (0.28, 0.2, 0.09)):
                b.span((cx + dx - r, 7.0 + dy - r, min(zz, zz + sg * 0.03)), (cx + dx + r, 7.0 + dy + r, max(zz, zz + sg * 0.03)),
                       "blush")
        hx = s * (half + PILLAR + 1.7)                                                     # hedge and flowers, in
        b.span((hx - 1.5, 0, -2.9), (hx + 1.5, 2.4, -0.6), "leaf_dark")                    # front of the wall line
        b.ball((hx, 2.4, -1.75), 1.3, "leaf_dark", scale=(1.1, 0.4, 0.85))
        flowers.span((hx - 1.5, 0, -4.0), (hx + 1.5, 0.2, -2.9), "leaf_green")
        for k in range(4):
            flower_clump(flowers, hx - 1.1 + 0.75 * k, 0.2, -3.45, n=2, spread=0.25)
    # mailbox by the right pillar, in front of the hedge
    mx, mz = half + PILLAR + 3.8, -4.6
    b.span((mx - 0.08, 0, mz - 0.08), (mx + 0.08, 3.0, mz + 0.08), "dark_wood")
    b.span((mx - 0.35, 3.0, mz - 0.6), (mx + 0.35, 3.6, mz + 0.6), "shirt_blue")
    b.cyl((mx, 3.6, mz), 0.35, 1.2, "shirt_blue", axis="Z", segments=10)
    b.span((mx + 0.35, 3.3, mz + 0.1), (mx + 0.42, 4.1, mz + 0.25), "bowl_red")
    # white pergola: beams front and back, rafters across, a street sign on top
    reach = half + PILLAR + 0.9
    for z0, z1 in ((-1.2, -0.75), (0.75, 1.2)):
        b.span((-reach, 12.0, z0), (reach, 12.7, z1), TRIM)
    for k in range(int(2 * reach / 2.0) + 1):
        x = -reach + 0.2 + k * (2 * reach - 0.4) / int(2 * reach / 2.0)
        b.span((x - 0.15, 12.7, -1.7), (x + 0.15, 13.15, 1.7), TRIM)
    for x in (-reach + 1.5, -6.0, 2.5, 9.0, reach - 2.0):                                 # climbing rose
        b.ball((x, 13.2, 1.2), 0.6, "leaf_green", scale=(1.3, 0.6, 0.8))
        flowers.span((x - 0.2, 13.4, 0.9), (x + 0.2, 13.75, 1.3), "blush")
    px = 0.4
    bw = text_width("NEIGHBOURHOOD", px) + 2.0
    for x in (-bw / 2 + 1.0, bw / 2 - 1.0):
        b.span((x - 0.12, 13.15, -0.12), (x + 0.12, 13.6, 0.12), "fur_black")
    # #1192: the board is tall enough that the letters (5 px = 2.0) sit clear of its cream rails; they used to run
    # into both rails in the same colour, so the word read as a jumble
    b.span((-bw / 2, 13.62, -0.15), (bw / 2, 16.38, 0.15), "sign_teal")
    for (ya, yb) in ((13.6, 13.78), (16.22, 16.4)):
        b.span((-bw / 2 - 0.05, ya, -0.2), (bw / 2 + 0.05, yb, 0.2), TRIM)
    _title(b, "NEIGHBOURHOOD", 14.0, px, -0.15, 0.15, "offwhite")
    for s in (-1, 1):
        lantern(b, lamps, _pillar_x(s, half)[2], 13.15, 0, 0.8)
    return 12.0


def build_neighbourhood_gate(mat):
    return _gate("CatCafe_Neighbourhood_Gate", mat, 32.0, "rarity_rare", "sign_teal", _neighbourhood)


def build_neighbourhood_gate_f85(mat):
    """F85: the same gate over the long Neighbourhood's 24 stud opening (Config.World.CampOpeningWidth)."""
    return _gate("CatCafe_Neighbourhood_GateF85", mat, 24.0, "rarity_rare", "sign_teal", _neighbourhood)


# ------------------------------------------------------------------------------------------- desert --
def _cactus(b, x, z, h):
    b.cyl((x, h / 2, z), 0.42, h, "leaf_green", segments=8)
    b.cyl((x, h, z), 0.42, 0.3, "leaf_green", r2=0.2, segments=8)
    for sx, y, ln in ((-1, h * 0.45, 0.8), (1, h * 0.62, 0.6)):                         # arms
        b.span((x + sx * 0.4, y - 0.2, z - 0.22), (x + sx * 0.95, y + 0.2, z + 0.22), "leaf_green")
        b.cyl((x + sx * 0.95, y + ln / 2, z), 0.24, ln + 0.3, "leaf_green", segments=8)


def _desert(b, lamps, flowers, half):
    for s in (-1, 1):                                  # sandstone pylons with clay bands, sand drifting at the feet
        x0, x1, cx = _pillar_x(s, half)
        b.span((x0 - 0.25, 0, -FRONT - 0.25), (x1 + 0.25, 0.9, BACK + 0.25), "fur_caramel")
        b.span((x0, 0.9, -FRONT), (x1, 13.6, BACK), "paving_tan")
        for y in (3.0, 6.4, 9.8):
            b.span((x0 - 0.1, y, -FRONT - 0.1), (x1 + 0.1, y + 0.5, BACK + 0.1), "terracotta")
        b.span((x0 - 0.3, 13.6, -FRONT - 0.3), (x1 + 0.3, 14.0, BACK + 0.3), "fur_caramel")
        b.span((x0 - 0.1, 14.0, -FRONT - 0.1), (x1 + 0.1, 14.3, BACK + 0.1), "paving_tan")
        lantern(b, lamps, cx, 14.3, (BACK - FRONT) / 2, 0.8)
        b.ball((cx + s * 0.9, 0.0, -2.45), 1.4, "fur_oat", scale=(1.4, 0.35, 0.8))        # drift, clear of the wall
        _cactus(b, s * (half + PILLAR + 1.9), -3.0, 2.6)
        b.cyl((s * (half + PILLAR + 0.5), 0.55, -3.6), 0.55, 1.1, "terracotta", r2=0.38, segments=10)   # clay pot
        b.cyl((s * (half + PILLAR + 0.5), 1.15, -3.6), 0.4, 0.1, "fur_copper", segments=10)
    reach = half + PILLAR + 0.3
    b.span((-reach, 12.2, -1.0), (reach, 13.25, 1.0), "fur_caramel")                     # lintel
    inner = half - INSET
    n = 12                                                                                 # striped awning, scalloped
    w = 2 * inner / n
    for k in range(n):
        x = -inner + k * w
        y0 = 11.45 if k % 2 == 0 else 11.75
        b.span((x, y0, -1.52), (x + w, 13.25, -1.32), "terracotta" if k % 2 == 0 else "offwhite")
    px = 0.45
    bw = text_width("THE DESERT", px) + 2.4
    b.span((-bw / 2, 13.3, -0.22), (bw / 2, 15.8, 0.22), "terracotta")                    # name plate
    for (ya, yb) in ((13.3, 13.48), (15.62, 15.8)):
        b.span((-bw / 2 - 0.06, ya, -0.27), (bw / 2 + 0.06, yb, 0.27), "eye_amber")
    _title(b, "THE DESERT", 14.4 - 2.5 * px, px, -0.22, 0.22, "offwhite")
    b.cyl((0, 17.1, 0), 1.25, 0.34, "eye_amber", axis="Z", segments=16)                  # sun disc with rays
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        cxr, cyr = 1.85 * math.cos(a), 17.1 + 1.85 * math.sin(a)
        if cyr < 16.0:
            continue
        b.span((cxr - 0.2, cyr - 0.2, -0.12), (cxr + 0.2, cyr + 0.2, 0.12), "eye_amber")
    b.span((-0.25, 15.8, -0.12), (0.25, 16.0, 0.12), "fur_caramel")
    return 12.2


def build_desert_gate(mat):
    """Tier 6: the Desert's 24 stud opening (Config.World.CampOpeningWidth)."""
    return _gate("CatCafe_Desert_Gate", mat, 24.0, "eye_amber", "terracotta", _desert)


# ------------------------------------------------------------------------------------------- ruins --
def _brazier(b, lamps, x, z):
    b.span((x - 0.6, 0, z - 0.6), (x + 0.6, 0.3, z + 0.6), "fur_soot")
    b.cyl((x, 1.25, z), 0.22, 1.9, "fur_soot", segments=8)
    b.cyl((x, 2.45, z), 0.75, 0.5, "fur_golden", r2=0.45, segments=12)
    lamps.cyl((x, 3.05, z), 0.5, 0.8, "lamp_warm", r2=0.08, segments=8)


def _ruins(b, lamps, flowers, half):
    for s in (-1, 1):                                  # fluted stone piers, one with its corner broken away
        x0, x1, cx = _pillar_x(s, half)
        b.span((x0 - 0.3, 0, -FRONT - 0.3), (x1 + 0.3, 0.9, BACK + 0.3), "fur_soot")
        b.span((x0, 0.9, -FRONT), (x1, 12.6, BACK), "fur_dusty")
        for k in range(3):                                                                 # flutes on the faces
            fx = x0 + (k + 1) * (x1 - x0) / 4
            for z, d in ((-FRONT, -1), (BACK, 1)):
                b.span((fx - 0.08, 1.3, min(z, z + d * 0.08)), (fx + 0.08, 12.2, max(z, z + d * 0.08)), "fur_pewter")
        b.span((x0 - 0.3, 12.6, -FRONT - 0.3), (x1 + 0.3, 13.2, BACK + 0.3), "fur_pewter")   # capital
        # rubble in front, each stone against the footing or the next stone (#3349: they stood loose, and the
        # brazier now stands nearer)
        for (dx, dz, sz) in ((0.9, -2.0, 0.7), (0.3, -2.4, 0.5), (-0.3, -2.1, 0.45)):
            rx = cx + s * dx
            b.box((rx, sz / 2, dz), (sz * 1.3, sz, sz), "fur_dusty", rot=rot_y(25.0 * s + dx * 30))
        _brazier(b, lamps, s * (half + PILLAR + 1.2), -3.0)       # #3349: 1.6 put its foot in the Relic Museum's base
    reach = half + PILLAR + 0.3
    b.span((-reach, 13.2, -1.1), (reach, 14.6, 1.1), "fur_dusty")                        # lintel, with a crack
    b.span((5.5, 13.2, -1.13), (5.62, 14.6, -1.1), "fur_soot")
    b.span((-reach + 0.6, 14.6, -0.9), (-reach + 2.6, 15.0, 0.9), "fur_pewter")          # fallen coping end
    for (x, ln) in ((-9.6, 2.2), (-8.9, 1.4), (-2.0, 1.0), (7.4, 1.8), (8.2, 2.6), (10.3, 1.2)):  # hanging vines
        b.span((x - 0.16, 13.2 - ln, -1.27), (x + 0.16, 14.6, -1.13), "leaf_dark")
        b.ball((x, 13.2 - ln, -1.2), 0.3, "leaf_green", scale=(1.0, 1.0, 0.5))
    px = 0.45
    bw = text_width("THE RUINS", px) + 2.4
    b.span((-bw / 2, 14.75, -0.25), (bw / 2, 17.0, 0.25), "fur_soot")                     # name tablet, its ends
                                                                                           # inside the gold bands
    for (ya, yb) in ((14.65, 14.83), (16.92, 17.1)):
        b.span((-bw / 2 - 0.06, ya, -0.3), (bw / 2 + 0.06, yb, 0.3), "fur_golden")
    _title(b, "THE RUINS", 15.88 - 2.5 * px, px, -0.25, 0.25, "fur_golden")
    for i, w in enumerate((bw * 0.55, bw * 0.38, bw * 0.2)):                               # stepped crest
        b.span((-w / 2, 17.1 + i * 0.55, -0.4 + i * 0.03), (w / 2, 17.65 + i * 0.55, 0.4 - i * 0.03), "fur_dusty")
    b.span((-0.6, 18.75, -0.3), (0.6, 19.75, 0.3), "fur_emerald")                          # jade cat head
    for xa in (-0.6, 0.2):                                                                 # ears
        b.span((xa, 19.75, -0.2), (xa + 0.4, 20.25, 0.2), "fur_emerald")
    return 13.2


def build_ruins_gate(mat):
    """Tier 7: the Ruins' 24 stud opening (Config.World.CampOpeningWidth)."""
    return _gate("CatCafe_Ruins_Gate", mat, 24.0, "fur_emerald", "fur_golden", _ruins)


# ------------------------------------------------------------------------------------------- snowy --
def _snow_pine(b, x, z, h):
    """A small snowy pine beside a pillar, stepped like the area's: a trunk, three tiers, snow on each step."""
    b.cyl((x, h * 0.45, z), 0.18, h * 0.9, "fur_brown", segments=8)
    for i, (y, r) in enumerate(((0.16, 0.34), (0.38, 0.26), (0.58, 0.17))):
        b.cyl((x, h * y + h * 0.1, z), r * h, h * 0.2, ("leaf_dark", "paw_woods")[i % 2], segments=8)
        b.cyl((x, h * y + h * 0.215, z), r * h * 0.8, h * 0.03, "milk", segments=8)
    b.cyl((x, h * 0.85, z), 0.07 * h, 0.1 * h, "milk", segments=8)


def _snowy(b, lamps, flowers, half):
    for s in (-1, 1):                                  # timber posts on grey stone, snow on every top
        x0, x1, cx = _pillar_x(s, half)
        b.span((x0 - 0.3, 0, -FRONT - 0.3), (x1 + 0.3, 1.6, BACK + 0.3), "concrete")
        b.span((x0 - 0.35, 1.6, -FRONT - 0.35), (x1 + 0.35, 1.8, BACK + 0.35), "milk")
        b.span((x0, 1.8, -FRONT), (x1, 13.0, BACK), "fur_brown")
        for y in (3.6, 6.2, 8.8, 11.4):                                                     # log courses
            b.span((x0 - 0.06, y, -FRONT - 0.06), (x1 + 0.06, y + 0.14, BACK + 0.06), "dark_wood")
        b.span((x0 - 0.3, 13.0, -FRONT - 0.3), (x1 + 0.3, 13.5, BACK + 0.3), "dark_wood")
        b.span((x0 - 0.2, 13.5, -FRONT - 0.2), (x1 + 0.2, 13.9, BACK + 0.2), "milk")
        lantern(b, lamps, cx, 13.9, (BACK - FRONT) / 2, 0.8)
        _snow_pine(b, s * (half + PILLAR + 1.6), -3.0, 6.0)                                # off the wall line
        b.ball((cx + s * 0.6, 0.0, -2.2), 1.3, "milk", scale=(1.4, 0.4, 0.7))             # drift, clear of the wall
    reach = half + PILLAR + 0.3
    b.cyl((0, 12.75, 0), 0.75, 2 * reach, "fur_brown", axis="X", segments=12)            # the log lintel
    b.span((-reach + 0.3, 13.4, -0.55), (reach - 0.3, 13.7, 0.55), "milk")                 # snow along it
    for x in range(-int(half) + 2, int(half) - 1, 2):                                      # icicles off its front
        ln = (0.6, 1.0, 0.8, 1.3)[(x // 2) % 4]
        b.span((x - 0.1, 12.0 - ln, -0.76), (x + 0.1, 12.0, -0.6), "pastel_sky")
    px = 0.45
    text = "SNOWY MOUNTAIN"
    bw = text_width(text, px) + 2.4
    b.span((-bw / 2, 13.7, -0.22), (bw / 2, 16.2, 0.22), "shirt_red")                      # name plate
    for (ya, yb) in ((13.7, 13.88), (16.02, 16.2)):
        b.span((-bw / 2 - 0.06, ya, -0.27), (bw / 2 + 0.06, yb, 0.27), "eye_blue")
    b.span((-bw / 2 - 0.1, 16.2, -0.35), (bw / 2 + 0.1, 16.45, 0.35), "milk")
    _title(b, text, 14.8 - 2.5 * px, px, -0.22, 0.22, "offwhite")
    for k in range(3):                                                                     # a snowflake on top
        b.box((0, 18.2, 0), (0.32, 3.0, 0.24), "eye_blue", rot=rot_z(60 * k))
        for sgn in (-1, 1):
            a = math.radians(60 * k + 90)
            tx, ty = sgn * 1.0 * math.cos(a), 18.2 + sgn * 1.0 * math.sin(a)
            b.box((tx, ty, 0), (0.22, 0.8, 0.2), "pastel_sky", rot=rot_z(60 * k + 45 * sgn))
    b.span((-0.2, 16.45, -0.12), (0.2, 16.75, 0.12), "fur_brown")
    return 12.0


# --------------------------------------------------------------------------------------- water park --
def _waterpark(b, lamps, flowers, half):
    for s in (-1, 1):                                  # candy striped towers on blue feet, a cone roof and a ball
        x0, x1, cx = _pillar_x(s, half)
        b.span((x0 - 0.3, 0, -FRONT - 0.3), (x1 + 0.3, 1.2, BACK + 0.3), "shirt_blue")
        for k in range(6):
            b.span((x0, 1.2 + 1.95 * k, -FRONT), (x1, 1.2 + 1.95 * (k + 1), BACK), ("milk", "shirt_red")[k % 2])
        b.span((x0 - 0.3, 12.9, -FRONT - 0.3), (x1 + 0.3, 13.4, BACK + 0.3), "rarity_legend")
        cz = (BACK - FRONT) / 2
        b.cyl((cx, 14.6, cz), 2.1, 2.4, "shirt_blue", r2=0.3, segments=10)
        lantern(b, lamps, cx, 15.7, cz, 0.7)
        for k, (dx, dy) in enumerate(((0.0, 0.0), (0.9, -1.1), (-0.8, -1.3))):                # balloons off the wall line
            b.ball((s * (half + PILLAR + 1.6) + dx, 7.4 + dy, -3.0), 0.8,
                   ("shirt_red", "pastel_butter", "shirt_blue")[(k + (s > 0)) % 3], scale=(1.0, 1.2, 1.0))
        b.span((s * (half + PILLAR + 1.6) - 0.05, 0.6, -3.05), (s * (half + PILLAR + 1.6) + 0.05, 6.4, -2.95), "milk")
        b.span((s * (half + PILLAR + 1.6) - 0.45, 0, -3.45), (s * (half + PILLAR + 1.6) + 0.45, 0.6, -2.55), "shirt_red")
    reach = half + PILLAR + 0.3
    b.span((-reach, 12.2, -0.9), (reach, 13.0, 0.9), "rarity_legend")                       # the beam
    inner = half - INSET
    n = 12                                                                                 # striped valance
    w = 2 * inner / n
    for k in range(n):
        x = -inner + k * w
        y0 = 11.3 if k % 2 == 0 else 11.6
        b.span((x, y0, -1.12), (x + w, 12.2, -0.92), "shirt_red" if k % 2 == 0 else "milk")
    for k in range(13):                                                                    # bulbs along the beam
        lamps.ball((-inner + 0.9 + k * (2 * inner - 1.8) / 12, 13.25, -0.95), 0.26, "lamp_warm")
    px = 0.45
    text = "WATER PARK"
    bw = text_width(text, px) + 2.4
    b.span((-bw / 2, 13.5, -0.22), (bw / 2, 16.0, 0.22), "shirt_blue")                      # name plate
    for (ya, yb) in ((13.5, 13.68), (15.82, 16.0)):
        b.span((-bw / 2 - 0.06, ya, -0.27), (bw / 2 + 0.06, yb, 0.27), "rarity_legend")
    _title(b, text, 14.6 - 2.5 * px, px, -0.22, 0.22, "offwhite")
    for k in range(8):                                                                     # a little wheel on top
        b.box((0, 18.3, 0), (0.16, 3.6, 0.14), "milk", rot=rot_z(22.5 * k))
    for k in range(8):
        a = math.radians(45 * k)
        b.ball((1.8 * math.cos(a), 18.3 + 1.8 * math.sin(a), 0), 0.34,
               ("shirt_red", "pastel_butter", "shirt_blue", "leaf_green")[k % 4])
    b.cyl((0, 18.3, 0), 0.45, 0.4, "rarity_legend", axis="Z", segments=10)
    b.span((-0.2, 16.0, -0.12), (0.2, 16.6, 0.12), "rarity_legend")
    return 12.0


# ------------------------------------------------------------------------------------------- castle --
def _castle(b, lamps, flowers, half):
    for s in (-1, 1):                                  # grey stone towers with merlons and a navy cone roof
        x0, x1, cx = _pillar_x(s, half)
        cz = (BACK - FRONT) / 2
        b.span((x0 - 0.3, 0, -FRONT - 0.3), (x1 + 0.3, 1.4, BACK + 0.3), "concrete_dark")
        b.span((x0, 1.4, -FRONT), (x1, 12.4, BACK), "concrete")
        for y in (4.2, 7.0, 9.8):                                                           # stone courses
            b.span((x0 - 0.05, y, -FRONT - 0.05), (x1 + 0.05, y + 0.12, BACK + 0.05), "concrete_dark")
        b.span((x0 - 0.4, 12.4, -FRONT - 0.4), (x1 + 0.4, 13.0, BACK + 0.4), "concrete_dark")
        for dx in (-1, 1):                                                                  # merlons on the corners
            for dz in (-1, 1):
                mx, mz = cx + dx * (PILLAR / 2 + 0.05), cz + dz * ((FRONT + BACK) / 2 + 0.05)
                b.span((mx - 0.4, 13.0, mz - 0.4), (mx + 0.4, 13.8, mz + 0.4), "metal")
        b.cyl((cx, 14.7, cz), 1.5, 3.4, "pants_navy", r2=0.15, segments=10)
        lantern(b, lamps, cx, 16.4, cz, 0.6)
        b.span((cx - 0.9, 5.6, -FRONT - 0.1), (cx + 0.9, 9.6, -FRONT - 0.02), ("shirt_red", "pants_navy")[s > 0])   # banner
        b.span((cx - 1.1, 9.6, -FRONT - 0.16), (cx + 1.1, 9.84, -FRONT - 0.02), "rarity_legend")
        b.box((cx, 7.8, -FRONT - 0.13), (0.8, 0.8, 0.06), "rarity_legend", rot=rot_z(45))
        px_ = s * (half + PILLAR + 1.6)                                                     # a torch off the wall line
        b.span((px_ - 0.45, 0, -3.45), (px_ + 0.45, 0.6, -2.55), "concrete_dark")
        b.span((px_ - 0.12, 0.6, -3.12), (px_ + 0.12, 5.2, -2.88), "dark_wood")
        b.span((px_ - 0.3, 5.2, -3.3), (px_ + 0.3, 5.6, -2.7), "fur_soot")
        lamps.ball((px_, 5.95, -3.0), 0.36, "lamp_warm", scale=(1.0, 1.4, 1.0))
    reach = half + PILLAR + 0.3
    b.span((-reach, 11.6, -0.9), (reach, 13.0, 0.9), "concrete")                             # the stone lintel
    b.span((-reach, 11.4, -1.0), (reach, 11.6, 1.0), "concrete_dark")
    inner = half - INSET
    n = 16                                                                                 # merlons along it
    w = 2 * inner / n
    for k in range(0, n, 2):
        b.span((-inner + k * w + 0.1, 13.0, -0.9), (-inner + (k + 1) * w - 0.1, 13.5, -0.5), "metal")
    for k in range(13):                                                                    # the portcullis' teeth
        x = -inner + 0.9 + k * (2 * inner - 1.8) / 12
        b.span((x - 0.14, 10.4, -0.14), (x + 0.14, 11.4, 0.14), "fur_soot")
        b.box((x, 10.36, 0), (0.28, 0.28, 0.24), "fur_soot", rot=rot_z(45))
    b.span((-inner, 10.9, -0.1), (inner, 11.1, 0.1), "fur_soot")
    px = 0.34
    text = "MEDIEVAL CASTLE"
    bw = text_width(text, px) + 2.4
    b.span((-bw / 2, 13.5, -0.22), (bw / 2, 16.0, 0.22), "pants_navy")                      # name plate
    for (ya, yb) in ((13.5, 13.68), (15.82, 16.0)):
        b.span((-bw / 2 - 0.06, ya, -0.27), (bw / 2 + 0.06, yb, 0.27), "rarity_legend")
    _title(b, text, 14.6 - 2.5 * px, px, -0.22, 0.22, "offwhite")
    b.span((-1.3, 16.0, -0.2), (1.3, 16.7, 0.2), "rarity_legend")                           # a gold crown on top
    for k, x in enumerate((-1.1, -0.55, 0.0, 0.55, 1.1)):
        b.span((x - 0.2, 16.7, -0.2), (x + 0.2, 17.3 + 0.3 * (k % 2 == 0), 0.2), "rarity_legend")
        b.ball((x, 17.5 + 0.3 * (k % 2 == 0), 0), 0.2, ("shirt_red", "milk")[k % 2])
    b.span((-1.3, 16.2, -0.24), (1.3, 16.4, 0.24), "shirt_red")
    return 12.0


def build_castle_gate(mat):
    """Tier 10: the Medieval Castle's 24 stud opening (the camp opening, as every area since F85)."""
    return _gate("CatCafe_Castle_Gate", mat, 24.0, "pants_navy", "concrete_dark", _castle)


def build_waterpark_gate(mat):
    """Tier 9: the Water Park's 24 stud opening (the camp opening, as every area since F85)."""
    return _gate("CatCafe_WaterPark_Gate", mat, 24.0, "shirt_red", "shirt_blue", _waterpark)


def build_snowy_gate(mat):
    """Tier 8: the Snowy Mountain's 24 stud opening (the camp opening, as every area since F85)."""
    return _gate("CatCafe_Snowy_Gate", mat, 24.0, "eye_blue", "shirt_red", _snowy)


ASSETS = {
    "CatCafe_Park_Gate": (build_park_gate, 6000),
    "CatCafe_Park_GateF85": (build_park_gate_f85, 6000),
    "CatCafe_Neighbourhood_Gate": (build_neighbourhood_gate, 6000),
    "CatCafe_Neighbourhood_GateF85": (build_neighbourhood_gate_f85, 6000),
    "CatCafe_Woods_Gate": (build_woods_gate, 6000),
    "CatCafe_Sewer_Gate": (build_sewer_gate, 6000),
    "CatCafe_Desert_Gate": (build_desert_gate, 6000),
    "CatCafe_Ruins_Gate": (build_ruins_gate, 6000),
    "CatCafe_Snowy_Gate": (build_snowy_gate, 6000),
    "CatCafe_WaterPark_Gate": (build_waterpark_gate, 6000),
    "CatCafe_Castle_Gate": (build_castle_gate, 6000),
}
