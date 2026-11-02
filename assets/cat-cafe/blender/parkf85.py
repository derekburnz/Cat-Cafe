"""The F85 Park (hometown-cannon.md section 6b): a long rectangle, 120 x 340 with the camp, so the run home with a cat
is long and in view. The set is the wild part, 120 x 310; the camp (CatCafe_Camp_ParkF85, camps.py) lies across its
-Z end, outside it, as in F84.

  CatCafe_Park_SetF85   the wild part dressed, in area space (areakit): place it at the area's centre on its floor,
                        gate side -Z toward the camp, like every set. Walls at x +-60 and z +-155 (WorldBuilder's);
                        the way in is a 24 stud opening (CampOpeningWidth) at x 0 on z -155, where the gate stands.

Four low obstacles stand across the way, each short enough to walk round (Derek 11-02: "it should be easily
navigatable just little areas to walk around to continue forward"), so the far end is never in a straight line but
nothing walls you off: a box hedge island (z -112, x -30 to 6), two short railings on a plinth with flower boxes
(z -50, x +-18 to +-40, open in the middle and by both walls), a stream out of the west wall that ends in a drain at
x 10 (z 9 to 15; cross on the footbridge at x -24, deck 10 wide, or walk round its end) and a second hedge island
(z 74, x -14 to 24). They are about 4 high, so a hunter sees a carrier coming over them; a `_Barrier` 30 high on each
stops anyone jumping one.
The tall pieces that break the view now and then are the willow and the kiosk by the duck pond, the glasshouse past
the railing, the oaks and the bandstand, the far landmark.

From the camp's pad the shortest walk is close to a straight line with a few steps round each obstacle: the plaza
and the picnic lawn, round the hedge island, round the duck pond, between the railings, past the glasshouse and the
orchard, round the stream's end (or over the footbridge), through the rose garden, round the second hedge, past the
playground to the bandstand loop.

Points (manifest points_roblox): [x, y, z, zone], zone "near" (the camp half, z < 0) or "deep" (the far half). The
trap spots (trap_tree, trap_trashcan) add a fifth number, the turn in degrees for the world-placed
CatCafe_Park_RescueTree or CatCafe_Park_TrashCan standing there (a tree's branch points along its -X). Five traps, four
deep, none within 100 studs of the camp.
"""

import math

from mathutils import Matrix

import neighbourhood as nb
from areakit import PI, Set, flowers, turned
from common import Builder
from parkset import (BARRIER_H, GRAVEL, KERB, LINK_W, PATH_W, ROUNDABOUT_TOP, WALL_D, _path, _ring_path, _run, _spot,
                     _strip, bandstand, bench, bin_, bistro, bl, blanket, face, flower_bed, garden_fountain, kiosk, lamp,
                     map_board, oak, picnic_table, pillar, planter, pond, poplar, ring_point, rose_arch, rose_bed,
                     roundabout, seesaw, spring_rider, sundial, topiary_cat, urn, wall_segment, willow)

NAME = "CatCafe_Park_SetF85"
N = "CatCafe_Park_"
HALF_X, HALF_Z = 60.0, 155.0          # WorldBuilder's walls at +-60, +-155 (ParkWidth 120, ParkDepth 310)
IN_X, IN_Z = HALF_X - 0.5 - WALL_D, HALF_Z - 0.5 - WALL_D
GATE_HALF = 17.5                      # CatCafe_Park_GateF85 is 32.95 wide, centred on the path
PLAZA = (0.0, -140.0)
HEDGE_A, ISLE_A = -112.0, [(-30.0, 6.0)]     # islands to walk round (Derek 11-02: "easily navigatable")
POND, RING_R = (-4.0, -80.0), 20.5
FENCE_B, ISLE_B = -50.0, [(-40.0, -18.0), (18.0, 40.0)]   # two short railings, open in the middle and by the walls
GLASS = (-30.0, -20.0)                # the glasshouse, front -Z
STREAM_Z, BRIDGE_X = 12.0, -24.0      # the stream's middle line and the footbridge
STREAM_END = 10.0                     # the stream runs from the west wall to its drain here; east of it is lawn
BRIDGE_W = 10.0                       # its deck (5.2 until Derek 11-02: not cramped)
BRIDGE_HX = BRIDGE_W / 2 + 0.3        # the kerbs and rails stop this far either side of it
GARDEN = (6.0, 46.0)
HEDGE_D, ISLE_D = 74.0, [(-14.0, 24.0)]
PLAY = (-36.0, 98.0, 36.0, 24.0)      # the playground mat's centre and size
BAND, LOOP_R = (8.0, 130.0), 13.5

RING_IN, RING_OUT = ring_point(POND, RING_R, -40), ring_point(POND, RING_R, 100)
LOOP_IN = ring_point(BAND, LOOP_R, 225)
PATH_1 = [(0, -155), PLAZA, (14, -133), (18, -122), (18, -104), (16, -100), RING_IN]
PATH_2 = [RING_OUT, (-5, -52), (0, -45)]
PATH_3 = [(0, -45), (6, -34), (14, -20), (18, -8), (18, 3.2), (18, 22), (GARDEN[0] + 6, 30)]
PATH_4 = [(GARDEN[0] + 6, 30), (GARDEN[0], 33.5)]
PATH_5 = [(GARDEN[0] - 12.5, GARDEN[1]), (-22, 52), (-26, 62), (-26, 80), (-12, 88), (-6, 106), LOOP_IN]


# ------------------------------------------------------------------------------------------------- ground --
def _ground():
    g = Builder()
    for pts in (PATH_1, PATH_2, PATH_3, PATH_5):
        _path(g, pts, PATH_W)
    _path(g, PATH_4, PATH_W)
    _ring_path(g, POND, RING_R, 5.0, GRAVEL, 0.05, 40)
    _ring_path(g, BAND, LOOP_R, LINK_W, GRAVEL, 0.05, 32)
    _strip(g, (BAND[0], BAND[1] - LOOP_R - 1.0), (BAND[0], BAND[1] - 8.0), LINK_W, GRAVEL, 0.058)   # bandstand approach
    g.cyl_base(bl(*PLAZA), 6.5, 0.075, "paving_light", segments=24, bevel=False)                  # entrance plaza
    g.cyl_base(bl(*PLAZA), 6.9, 0.07, KERB, segments=24, bevel=False)
    x, z = GLASS
    g.box_base(bl(x, z - 10.5), (22.0, 6.0, 0.075), "paving_light", bevel=False)                 # glasshouse forecourt
    g.box_base(bl(x, z - 10.5), (22.8, 6.8, 0.07), KERB, bevel=False)
    g.cyl_base(bl(*GARDEN), 5.5, 0.075, "paving_light", segments=20, bevel=False)                 # rose garden centre
    _strip(g, (GARDEN[0], 33.5), (GARDEN[0], GARDEN[1] - 5.0), LINK_W, GRAVEL, 0.058)
    _strip(g, (GARDEN[0] - 5.0, GARDEN[1]), (GARDEN[0] - 12.5, GARDEN[1]), LINK_W, GRAVEL, 0.058)
    _strip(g, (GARDEN[0] + 5.0, GARDEN[1]), (44.0, 50.0), LINK_W, GRAVEL, 0.05)                 # to the sundial nook
    g.cyl_base(bl(44.0, 50.0), 3.2, 0.075, "paving_light", segments=16, bevel=False)
    _strip(g, LOOP_IN, (PLAY[0] + PLAY[2] / 2 + 0.5, 104.0), LINK_W, GRAVEL, 0.058)              # loop to playground
    x, z, w, d = PLAY
    g.box_base(bl(x, z), (w, d, 0.045), "terracotta", bevel=False)                                 # safety surface
    return g


# -------------------------------------------------------------------------------------------------- walls --
def _walls(s, mat):
    _run(s, mat, ("hedge", "brick", "rail", "stone"), 5, 2 * IN_X, lambda t: (-IN_X + t, IN_Z, 0))            # far
    _run(s, mat, ("stone", "rail", "hedge", "brick", "rail", "hedge"), 12, 2 * IN_Z,
         lambda t: (IN_X, -IN_Z + t, 90))                                                                       # east
    _run(s, mat, ("brick", "hedge", "stone", "rail", "hedge", "rail"), 12, 2 * IN_Z,
         lambda t: (-IN_X, IN_Z - t, -90))                                                                      # west
    for sx in (-1, 1):
        s.put(pillar(mat, h=11.2, w=2.4), sx * (IN_X + 1.2), IN_Z, 0)                       # far corners
        s.put(pillar(mat, h=6.0, w=2.4), sx * (IN_X + 1.2), -IN_Z, 180)                     # camp corners
        x0, x1 = GATE_HALF + 0.9, IN_X
        L = (x1 - x0 - 2 * 1.8) / 3
        for i in range(3):                                                                    # camp side, low
            c = x0 + i * (L + 1.8) + L / 2
            s.put(wall_segment(mat, "low", L, i + (sx > 0)), sx * c, -IN_Z, 180)
            if i < 2:
                s.put(pillar(mat, h=5.2), sx * (c + L / 2 + 0.9), -IN_Z, 180)
        s.put(pillar(mat, top="lantern", h=7.0), sx * GATE_HALF, -IN_Z, 180)                 # by the way in
    bar = Builder()                       # all round but the way in: a jump from a bench clears WorldBuilder's walls
    ox = IN_X + WALL_D
    bar.box_base((0, IN_Z + WALL_D / 2, 0), (2 * ox, WALL_D, BARRIER_H), "offwhite", bevel=False)            # far
    for sx in (-1, 1):
        bar.box_base((sx * (IN_X + WALL_D / 2), 0, 0), (WALL_D, 2 * IN_Z, BARRIER_H), "offwhite", bevel=False)  # sides
        bar.box_base((sx * (GATE_HALF + ox) / 2, -(IN_Z + WALL_D / 2), 0), (ox - GATE_HALF, WALL_D, BARRIER_H),
                     "offwhite", bevel=False)                                                               # camp side
    s.put([bar.finalize(N + "Walls_Barrier", mat)], 0, 0, 0)


# ------------------------------------------------------------------------------------------------ blockers --
def _low_hedge(s, mat, z, runs):
    """Clipped box hedge islands on the line z, 3.4 to 4 high, so a hunter sees over them, each run (x0, x1) with
    rounded ends and an urn just past each end, open ground all round. Its `_Barrier` 30 high on each run's footprint
    stops anyone jumping it."""
    b, bar = Builder(), Builder()
    for (a0, a1) in runs:
        n = max(1, round((a1 - a0) / 6.0))
        step = (a1 - a0) / n
        for i in range(n):
            c, h = a0 + (i + 0.5) * step, 3.4 + 0.3 * (i % 3)
            sw = ("leaf_dark", "leaf_green")[i % 2]
            x, y, _ = bl(c, z)
            b.box_base((x, y, 0), (step + 0.02 * (i % 2), 2.0 + 0.02 * (i % 2), h), sw, bevel=False)
            b.ico((x, y, h), 1.2, sw, subdivisions=1, scale=(step / 2.4, 0.85, 0.4))
        for (xe, sx) in ((a0, -1), (a1, 1)):                                    # rounded ends
            x, y, _ = bl(xe, z)
            b.cyl_base((x, y, 0), 1.0, 3.4, "leaf_dark", segments=10, bevel=False)
            b.ico((x, y, 3.4), 1.05, "leaf_dark", subdivisions=1, scale=(1, 1, 0.45))
        x, y, _ = bl((a0 + a1) / 2, z)
        bar.box_base((x, y, 0), (a1 - a0 + 2.0, 2.0, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "LowHedge", mat), bar.finalize(N + "LowHedge_Barrier", mat)], 0, 0, 0)
    for (a0, a1) in runs:
        for x in (a0 - 2.1, a1 + 2.1):
            if abs(x) < IN_X - 1.5:
                s.put(urn(mat), x, z, 0)


def _railing(s, mat, z, runs):
    """Short low railings on the line z (the camp side's own look: a plinth, railings 4.6 high and flower boxes facing
    the camp), each run (x0, x1) between 1.8 pillars with a lantern pillar at each end, open ground all round. Its face
    is at z, its back at z + 2.4."""
    bar = Builder()
    for (a0, a1) in runs:
        n = max(1, round((a1 - a0 - 1.8) / 9.0))
        L = (a1 - a0 - (n + 1) * 1.8) / n
        s.put(pillar(mat, top="lantern", h=6.0), a0 + 0.9, z, 0)
        for i in range(n):
            c = a0 + 1.8 + i * (L + 1.8) + L / 2
            s.put(wall_segment(mat, "low", L, i), c, z, 0)
            p = c + L / 2 + 0.9
            s.put(pillar(mat, top="lantern", h=6.0) if i == n - 1 else pillar(mat, h=5.2), p, z, 0)
        x, y, _ = bl((a0 + a1) / 2, z + WALL_D / 2)
        bar.box_base((x, y, 0), (a1 - a0, WALL_D, BARRIER_H), "offwhite", bevel=False)
    s.put([bar.finalize(N + "Railing_Barrier", mat)], 0, 0, 0)


def _stream(s, mat):
    """A stream 6 wide between stone kerbs 0.7 high, out of a culvert in the west wall and into a drain at
    STREAM_END, where a kerb closes it and an iron grate takes the water; east of it is open lawn, so a player walks
    round its end or crosses on the footbridge. An iron rail 3 high on each kerb and round the end, its `_Barrier` a
    0.5 thick wall on the rail's line (style guide: a barrier always stands on something a player can see)."""
    b, water, decor, bar = Builder(), Builder(), Builder(), Builder()
    z0, z1 = STREAM_Z - 3.0, STREAM_Z + 3.0
    E = STREAM_END
    L, cx = E + IN_X, (E - IN_X) / 2
    b.box_base(bl(cx, STREAM_Z), (L, 6.0, 0.02), "concrete_dark", bevel=False)                   # the bed
    water.box_base(bl(cx, STREAM_Z, 0.02), (L, 6.0, 0.33), "fish_blue", bevel=False)
    runs = ((-IN_X, BRIDGE_X - BRIDGE_HX), (BRIDGE_X + BRIDGE_HX, E + 0.8))
    for i, zc in enumerate((z0 - 0.4, z1 + 0.4)):                        # the kerbs, broken by the bridge's abutments
        for (a0, a1) in runs:
            b.box_base(bl((a0 + a1) / 2, zc), (a1 - a0, 0.8, 0.7 + 0.006 * i), "concrete", bevel=False)
    b.box_base(bl(E + 0.4, STREAM_Z), (0.8, 6.0, 0.7), "concrete", bevel=False)                  # the end kerb
    b.box_base(bl(E - 1.2, STREAM_Z, 0.02), (2.0, 4.4, 0.36), "concrete_dark", bevel=False)      # the drain's sill, 0.03 proud of the water
    for k in range(7):                                                                            # its grate
        b.box_base(bl(E - 1.2, STREAM_Z - 1.8 + 0.6 * k, 0.36), (1.8, 0.14, 0.06), "metal", bevel=False)
    for (dx, dz, r) in ((-2.6, -2.0, 0.45), (-3.4, 2.1, 0.35), (-1.0, 2.3, 0.3)):                  # stones by it
        decor.ico(bl(E + dx, STREAM_Z + dz, 0.3), r, "concrete", subdivisions=1, scale=(1.2, 1, 0.7))
    for sx in (-1,):                                                                              # the culvert
        x = sx * IN_X
        b.box_base(bl(x - sx * 0.2, STREAM_Z), (0.4, 8.4, 3.0), "concrete", bevel=False)
        b.box_base(bl(x - sx * 0.45, STREAM_Z), (0.1, 5.2, 1.9), "fur_black", bevel=False)
        for k in range(5):
            b.box_base(bl(x - sx * 0.55, STREAM_Z - 2.0 + k), (0.12, 0.14, 1.9), "metal", bevel=False)
        b.box_base(bl(x - sx * 0.5, STREAM_Z), (0.2, 6.0, 0.3), "concrete_dark", bevel=False, rot=None)
    for k in range(8):                                                                            # lily pads, reeds
        x = -IN_X + 5.0 + k * (E + IN_X - 12.0) / 7
        if abs(x - BRIDGE_X) < BRIDGE_HX + 3.0:
            continue
        dz = (-1.6, 1.2, -0.4, 1.9)[k % 4]
        decor.cyl_base(bl(x, STREAM_Z + dz, 0.35), 0.5 + 0.1 * (k % 3), 0.03, "leaf_green", segments=8, bevel=False)
        if k % 3 == 0:
            decor.ico(bl(x + 0.2, STREAM_Z + dz, 0.45), 0.15, "blush", subdivisions=1)
        side = z0 + 0.35 if k % 2 else z1 - 0.35
        for j in range(3):
            decor.box_base(bl(x + 1.5 + 0.35 * j, side, 0.3), (0.12, 0.12, 1.1 + 0.35 * j),
                           ("leaf_dark", "leaf_green")[j % 2], bevel=False)
    for (x, rot) in ((-38.0, 30.0), (-8.0, 200.0)):                                              # ducks
        a = math.radians(rot)
        decor.ico(bl(x, STREAM_Z + 0.8, 0.55), 0.5, "offwhite", subdivisions=1, scale=(1.3, 0.9, 0.7))
        hx, hz = x + 0.55 * math.cos(a), STREAM_Z + 0.8 + 0.55 * math.sin(a)
        decor.ico(bl(hx, hz, 1.05), 0.28, "offwhite", subdivisions=1)
        decor.box(bl(hx + 0.3 * math.cos(a), hz + 0.3 * math.sin(a), 1.02), (0.22, 0.14, 0.08), "fur_orange",
                  bevel=False, rot=(-a, "Z"))
    for i, zc in enumerate((z0 - 0.4, z1 + 0.4)):      # an iron rail on each kerb, its barrier a wall on the rail's line
        kt = 0.7 + 0.006 * i
        for (a0, a1) in ((-IN_X + 0.45, BRIDGE_X - BRIDGE_HX), (BRIDGE_X + BRIDGE_HX, E + 0.4)):    # clear of the culvert
            n = max(1, round((a1 - a0 - 0.6) / 2.0))
            for k in range(n + 1):
                b.box_base(bl(a0 + 0.3 + (a1 - a0 - 0.6) * k / n, zc, kt), (0.16, 0.16, 3.0 - kt), "fur_black",
                           bevel=False)
            for (h, t) in ((1.6, 0.14), (2.85, 0.2)):
                b.box(bl((a0 + a1) / 2, zc, h), (a1 - a0 - 0.4, 0.12, t), "fur_black", bevel=False)
        for (a0, a1) in ((-IN_X, BRIDGE_X - BRIDGE_HX), (BRIDGE_X + BRIDGE_HX, E + 0.65)):
            bar.box_base(bl((a0 + a1) / 2, zc), (a1 - a0, 0.5, BARRIER_H), "offwhite", bevel=False)
    xe = E + 0.4                                                          # the rail round the end
    for k in range(4):
        b.box_base(bl(xe, z0 - 0.4 + (z1 - z0 + 0.8) * k / 3, 0.7), (0.16, 0.16, 2.3), "fur_black", bevel=False)
    for (h, t) in ((1.6, 0.14), (2.85, 0.2)):
        b.box(bl(xe, STREAM_Z, h), (0.12, z1 - z0 + 0.8, t), "fur_black", bevel=False)
    bar.box_base(bl(xe, STREAM_Z), (0.5, z1 - z0 + 1.3, BARRIER_H), "offwhite", bevel=False)
    s.put([b.finalize(N + "Stream", mat), water.finalize(N + "Stream_Water", mat),
           decor.finalize(N + "Stream_Decor", mat), bar.finalize(N + "Stream_Barrier", mat)], 0, 0, 0)


def footbridge(mat):
    """The timber footbridge over the stream, pivot at its middle on the ground, its length along Z: a deck 10 wide
    at 1.6 over 10 studs, a ramp of 4 at each end (22 degrees), stone abutments on the kerb lines, and solid railings
    3 high along the deck and both ramps, with a lantern on each deck-end post."""
    b, bulb = Builder(), Builder()
    W, top, half, ramp = BRIDGE_W, 1.6, 5.0, 4.0
    b.box_base((0, 0, top - 0.35), (W, 2 * half, 0.35), "caramel_wood", bevel=False)
    for i in range(12):
        b.box_base((0, -half + (i + 0.5) * 2 * half / 12, top), (W - 0.3, 0.06, 0.012), "dark_wood", bevel=False)
    for sy in (-1, 1):
        b.wedge((0, sy * (half + ramp / 2), top / 2), (W, ramp, top), "caramel_wood", bevel=False,
                rot=None if sy < 0 else (PI, "Z"))
        b.box_base((0, sy * 3.4, 0), (W + 0.6, 1.2, top - 0.35), "concrete", bevel=False)     # abutments
    for x in (-(W / 2 - 0.4), 0.0, W / 2 - 0.4):                                                   # the stringers
        b.box_base((x, 0, top - 0.95), (0.5, 2 * half - 0.2, 0.6), "dark_wood", bevel=False)

    def surf(y):
        return top if abs(y) <= half else top * (half + ramp - abs(y)) / ramp

    posts = (-8.8, -7.0, -5.0, -2.5, 0.0, 2.5, 5.0, 7.0, 8.8)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.15)
        for y in posts:
            h = 3.6 if abs(y) == half else 3.0
            b.box_base((x, y, surf(y)), (0.3, 0.3, h), "dark_wood", bevel=False)
            if abs(y) == half:
                b.box_base((x, y, surf(y) + h), (0.5, 0.5, 0.15), "fur_black", bevel=False)
                bulb.box_base((x, y, surf(y) + h + 0.15), (0.4, 0.4, 0.55), "lamp_warm", bevel=False)
                b.pyramid((x, y, surf(y) + h + 0.7), 0.6, 0.35, "fur_black")
        for (y0, y1) in ((-half - ramp, -half), (-half, half), (half, half + ramp)):
            dy, dz = y1 - y0, surf(y1) - surf(y0)
            a = math.atan2(dz, dy)
            Lr = math.hypot(dy, dz)
            for k, (hh, th) in enumerate(((2.72, 0.3), (1.5, 0.2))):
                b.box((x, (y0 + y1) / 2, (surf(y0) + surf(y1)) / 2 + hh), (0.22, Lr, th), "caramel_wood",
                      bevel=False, rot=(a, "X"))
    return [b.finalize(N + "FootBridge", mat), bulb.finalize(N + "FootBridge_Bulb", mat)]


# --------------------------------------------------------------------------------------------- glasshouse --
def _palm(d, x, y, h, z0=1.2):
    d.cyl_base((x, y, z0), 0.3, h, "fur_brown", segments=6, radius2=0.2)
    for k in range(6):
        a = 2 * PI * k / 6 + 0.3
        rot = Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(math.radians(-20), 3, "Y")
        d.box((x + 1.2 * math.cos(a), y + 1.2 * math.sin(a), z0 + h - 0.2), (2.6, 0.6, 0.1),
              ("leaf_green", "leaf_dark")[k % 2], bevel=False, rot=rot)


def glasshouse(mat):
    """A Victorian palm house, front -Y (Roblox -Z), pivot at its base centre: a white-framed octagonal glass tower
    under a glass roof and a lantern (top 15.6), two pitched glass wings (26 across, 9 deep), a brick plinth and front
    steps, palms and ferns inside. Not for going in: a `_Barrier` over the plinth up to 16 keeps everyone outside."""
    b, glass, decor, bulb, bar = Builder(), Builder(), Builder(), Builder(), Builder()
    b.box_base((0, 0, 0), (26.4, 12.4, 1.0), "brick", bevel=False)
    b.box_base((0, 0, 1.0), (26.8, 12.8, 0.2), "concrete", bevel=False)
    b.box_base((0, -7.5, 0), (5.2, 0.8, 0.5), "concrete", bevel=False)                             # front steps
    b.box_base((0, -6.75, 0), (5.2, 0.7, 1.0), "concrete", bevel=False)
    R, h0, h1 = 5.4, 1.2, 8.6
    oct_rot = (PI / 8, "Z")
    glass.cyl((0, 0, (h0 + h1) / 2), R, h1 - h0, "glass", segments=8, bevel=False, rot=oct_rot)
    corners = [PI / 8 + PI / 4 * k for k in range(8)]
    for a in corners:
        b.box_base((R * math.cos(a), R * math.sin(a), h0), (0.4, 0.4, h1 - h0), "offwhite", bevel=False,
                   rot=(a, "Z"))
    for z, t in ((h0 + 0.15, 0.3), (4.9, 0.25), (h1 - 0.15, 0.3)):
        b.ring((0, 0, z), R + 0.2, 0.5, t, "offwhite", segments=8, bevel=False, rot=oct_rot)
    ap = R * math.cos(PI / 8)                                                                      # the front face
    b.box((0, -ap - 0.12, h0 + 1.85), (2.9, 0.25, 3.7), "offwhite", bevel=False)                    # the door
    b.box((0, -ap - 0.27, h0 + 1.7), (2.2, 0.1, 3.3), "sign_teal", bevel=False)
    b.box((0, -ap - 0.33, h0 + 1.7), (0.08, 0.04, 3.3), "offwhite", bevel=False)
    for sx in (-1, 1):
        b.sphere((sx * 0.35, -ap - 0.36, h0 + 1.6), 0.08, "brass", segments=6, rings=4)
    b.box((0, -ap - 0.2, h0 + 3.95), (3.4, 0.45, 0.3), "offwhite", bevel=False)                    # the hood
    # the roof: a glass slope up to the lantern, ribs on the corners
    rr, r2, rh = R + 0.3, 1.8, 3.2
    glass.cyl((0, 0, h1 + rh / 2), rr, rh, "glass", segments=8, bevel=False, rot=oct_rot, radius2=r2)
    tilt = math.atan2(rr - r2, rh)
    Lr = math.hypot(rr - r2, rh)
    for a in corners:
        m = (rr + r2) / 2
        rot = Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-tilt, 3, "Y")
        b.box((m * math.cos(a), m * math.sin(a), h1 + rh / 2), (0.3, 0.3, Lr + 0.2), "offwhite", bevel=False, rot=rot)
    lt = h1 + rh
    bulb.cyl((0, 0, lt + 0.8), 1.6, 1.6, "lamp_warm", segments=8, bevel=False, rot=oct_rot)
    b.cyl((0, 0, lt + 0.05), 2.0, 0.1, "offwhite", segments=8, bevel=False, rot=oct_rot)
    b.cyl((0, 0, lt + 2.1), 2.0, 1.0, "offwhite", segments=8, bevel=False, rot=oct_rot, radius2=0.2)
    for a in corners:
        b.box_base((1.6 * math.cos(a), 1.6 * math.sin(a), lt + 0.1), (0.2, 0.2, 1.5), "offwhite", bevel=False,
                   rot=(a, "Z"))
    b.cyl_base((0, 0, lt + 2.6), 0.08, 0.6, "gold_mid", segments=6, bevel=False)
    b.sphere((0, 0, lt + 3.35), 0.25, "gold_mid", segments=8, rings=5)
    # the wings, ridge along X
    ww, wd, wz0, wz1, ridge = 8.0, 9.0, h0, 7.0, 9.2
    t = math.atan2(ridge - wz1, wd / 2 + 0.2)
    Ls = math.hypot(wd / 2 + 0.2, ridge - wz1) + 0.15
    gable_rot = Matrix(((0, 0, 1), (1, 0, 0), (0, 1, 0)))
    for sx in (-1, 1):
        xc = sx * 9.0
        glass.box_base((xc, 0, wz0 + 0.03), (ww, wd, wz1 - wz0 - 0.08), "glass", bevel=False)
        for i in range(7):
            x = xc - ww / 2 + i * ww / 6
            for sy in (-1, 1):
                b.box_base((x, sy * (wd / 2 + 0.05), wz0), (0.25, 0.25, wz1 - wz0), "offwhite", bevel=False)
        for k in range(5):
            y = -wd / 2 + (k + 1) * wd / 6
            b.box_base((sx * (ww / 2 + 9.05), y, wz0), (0.25, 0.25, wz1 - wz0), "offwhite", bevel=False)
        for z in (wz0 + 0.12, 4.1, wz1 - 0.12):
            for sy in (-1, 1):
                b.box((xc, sy * (wd / 2 + 0.05), z), (ww, 0.3, 0.25), "offwhite", bevel=False)
            b.box((sx * (ww / 2 + 9.05), 0, z), (0.3, wd, 0.25), "offwhite", bevel=False)
        for sy in (-1, 1):                                                                          # the roof
            glass.box((xc, sy * (wd / 4 + 0.1), (wz1 + ridge) / 2), (ww + 0.1, Ls, 0.12), "glass", bevel=False,
                      rot=(-sy * t, "X"))
            for i in range(7):
                x = xc - ww / 2 + i * ww / 6
                b.box((x, sy * (wd / 4 + 0.1), (wz1 + ridge) / 2 + 0.12), (0.2, Ls, 0.18), "offwhite", bevel=False,
                      rot=(-sy * t, "X"))
        b.box((xc, 0, ridge + 0.1), (ww + 0.4, 0.4, 0.35), "offwhite", bevel=False)
        glass.fan((sx * (ww / 2 + 9.0), 0, wz1), (0, ridge - wz1), [(-wd / 2, 0), (wd / 2, 0)], 0.12, "glass",
                  rot=gable_rot)
        b.box((sx * (ww / 2 + 9.1), 0, (wz1 + ridge) / 2), (0.25, 0.25, ridge - wz1), "offwhite", bevel=False)
        for (px, py, ph) in ((xc - 2.0, 1.5, 4.0), (xc + 2.2, -1.6, 3.2)):
            _palm(decor, px, py, ph)
        for k in range(4):
            decor.ico((xc - 3.0 + 2.0 * k, 3.4 - 1.0 * (k % 2), h0 + 0.6), 0.8, ("leaf_dark", "leaf_green")[k % 2],
                      subdivisions=1, scale=(1, 1, 0.7))
    _palm(decor, 0.0, 0.5, 9.0)
    for k in range(5):
        a = 2 * PI * k / 5
        decor.cyl_base((3.2 * math.cos(a), 3.2 * math.sin(a), h0), 0.55, 0.7, "terracotta", segments=8, bevel=False)
        decor.ico((3.2 * math.cos(a), 3.2 * math.sin(a), h0 + 1.2), 0.7, ("leaf_green", "blush")[k % 2],
                  subdivisions=1)
    bar.box_base((0, 0, 0), (26.8, 12.8, 16.0), "offwhite", bevel=False)
    return [b.finalize(N + "Glasshouse", mat), glass.finalize(N + "Glasshouse_Glass", mat),
            decor.finalize(N + "Glasshouse_Decor", mat), bulb.finalize(N + "Glasshouse_Bulb", mat),
            bar.finalize(N + "Glasshouse_Barrier", mat)]


def apple_tree(mat, seed=0):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.5, 3.4, "fur_brown", segments=8, radius2=0.38)
    b.ico((0, 0, 4.8), 2.6, "leaf_green", subdivisions=1, scale=(1, 1, 0.85))
    b.ico((1.5, 0.6, 4.2), 1.6, "leaf_dark", subdivisions=1)
    b.ico((-1.4, -0.7, 4.4), 1.7, "leaf_dark", subdivisions=1)
    for k in range(7):
        a = 2 * PI * k / 7 + seed
        b.ico((2.3 * math.cos(a), 2.3 * math.sin(a), 4.8 + 0.25 * ((k + seed) % 3 - 1)), 0.25, "shirt_red",
              subdivisions=1)
    return [b.finalize(N + "AppleTree", mat)]


def flower_patch(mat, seed=0, r=3.2):
    """A patch of wildflowers in longer grass, flat on the lawn (walk through it: _Flowers never collide)."""
    b, fl = Builder(), Builder()
    b.cyl_base((0, 0, 0), r, 0.08, "leaf_dark", segments=12, bevel=False)
    n = 9 + seed % 3
    for k in range(n):
        a = 2 * PI * k / n + seed
        rr = r * (0.3 + 0.55 * ((k * 5 + seed) % 4) / 3)
        flowers(fl, rr * math.cos(a), rr * math.sin(a), 0.08, n=3, r=0.35, seed=k + seed)
    return [b.finalize(N + "FlowerPatch", mat), fl.finalize(N + "FlowerPatch_Flowers", mat)]


def beehives(mat):
    """Two white beehives on a plank stand by the orchard, front -Y, a little honey pot in front."""
    b = Builder()
    b.box_base((0, 0, 0), (4.4, 1.6, 0.5), "dark_wood", bevel=False)
    for x in (-1.2, 1.2):
        for k in range(3):
            b.box_base((x, 0, 0.5 + 0.55 * k), (1.5 - 0.02 * k, 1.3 - 0.02 * k, 0.55), "offwhite")
        b.box_base((x, 0, 2.15), (1.8, 1.6, 0.2), "concrete_dark", bevel=False)
        b.box((x, -0.66, 0.62), (0.6, 0.04, 0.12), "fur_black", bevel=False)
    b.cyl_base((0, -0.2, 0.5), 0.3, 0.45, "pastel_butter", segments=8)                         # a honey pot
    return [b.finalize(N + "Beehives", mat)]


# ------------------------------------------------------------------------------------------------- the set --
def build_set(mat):
    s = Set(NAME)
    _walls(s, mat)
    _low_hedge(s, mat, HEDGE_A, ISLE_A)
    _railing(s, mat, FENCE_B, ISLE_B)
    _stream(s, mat)
    s.put(footbridge(mat), BRIDGE_X, STREAM_Z, 0)
    _low_hedge(s, mat, HEDGE_D, ISLE_D)

    # the way in: the plaza with its planter, the map, lamps and benches; flower beds along the path east
    s.put(planter(mat), *PLAZA, 0)
    _spot(s, "plaza", -4.0, -145.0)
    s.put(map_board(mat), 12, -148, face(12, -148, *PLAZA))
    for (x, z) in ((-12, -150), (10, -152), (-12, -129), (42, -118)):
        s.put(lamp(mat), x, z, 0)
    for x in (-6.5, 6.5):
        s.put(bench(mat), x, -131.5, face(x, -131.5, *PLAZA))
    for i, (x, z) in enumerate(((18, -143), (32, -136), (46, -130))):
        s.put(flower_bed(mat, i), x, z, 0)
        _spot(s, "flowerbed", x, z, y=0.62)
    s.put(bench(mat), 52, -141, 90)
    _spot(s, "bench", *turned(52, -141, 90, 0, -2.4))
    for (x, z) in ((-11, -134), (52, -122)):
        s.put(bin_(mat), x, z, 0)

    # the picnic lawn, west of the plaza
    for i, (x, z, r) in enumerate(((-24, -143, 8), (-42, -138, -12), (-30, -122, 5))):
        s.put(picnic_table(mat), x, z, r)
        if i < 2:
            _spot(s, "picnic", *turned(x, z, r, 0, -4.0))
    s.put(blanket(mat), -45, -124, 15)
    _spot(s, "blanket", -45, -124, y=0.06)
    s.put(oak(mat), -48, -146, 20)
    _spot(s, "oak", -44.5, -147.5)          # 4 studs clear of the picnic spot at (-41.2, -141.9) (Layout)
    s.put(oak(mat, blossom=True), 46, -146, 40)
    _spot(s, "blossom", 42, -148)

    # the duck pond and the lawns either side of it
    s.put(pond(mat), *POND, 0)
    _spot(s, "jetty", POND[0] + 10, POND[1], y=1.2)
    for deg in (215, 70):
        _spot(s, "bank", *ring_point(POND, 19.0, deg))
    for deg in (20, 100, 200, 280):
        x, z = ring_point(POND, 24.0, deg)
        s.put(bench(mat), x, z, face(x, z, *POND))
    for deg in (60, 160, 240, 345):
        s.put(lamp(mat), *ring_point(POND, 23.6, deg), 0)
    s.put(willow(mat), -44, -94, 0)
    _spot(s, "willow", -40, -98)
    s.put(kiosk(mat), 48, -80, 90)
    _spot(s, "kiosk", 42.5, -86.5)
    for z in (-72, -90):
        s.put(bistro(mat), 36, z, 0)
    s.put(oak(mat), -44, -66, 140)
    _spot(s, "lawn", -46, -60)
    s.put(oak(mat), 40, -60, 260)

    # past the railing: the glasshouse and its forecourt, the orchard, the meadow
    s.put(glasshouse(mat), *GLASS, 0)
    for x in (-27.0, -33.0):
        _spot(s, "glasshouse", x, GLASS[1] - 8.3, y=0.5)
    for x in (-42.5, -17.5):
        s.put(urn(mat), x, GLASS[1] - 9.0, 0)
    for (x, z) in ((-38, -44), (-16, -38), (14, -12), (38, 0)):
        s.put(lamp(mat), x, z, 0)
    for i, (x, z) in enumerate(((22, -42), (36, -44), (50, -40), (18, -30))):
        s.put(apple_tree(mat, i), x, z, 0)
    _spot(s, "orchard", 29, -37)
    s.put(blanket(mat), -6, -10, -20)
    _spot(s, "blanket", -6, -10, y=0.06)
    s.put(bench(mat), -6, -32, face(-6, -32, -30, -24))
    for (x, z) in ((-52, -10), (52, -10)):
        s.put(poplar(mat), x, z, 0)

    # the stream's far bank and the rose garden
    _spot(s, "stream", 16, 20)
    _spot(s, "stream", -40, 20)
    s.put(bench(mat), 42, 22, face(42, 22, STREAM_END, STREAM_Z))
    s.put(lamp(mat), 22, 22, 0)
    s.put(garden_fountain(mat), *GARDEN, 0)
    _spot(s, "fountain", GARDEN[0], GARDEN[1] + 4.5)
    for i, deg in enumerate((0, 45, 135, 225, 315)):
        s.put(rose_bed(mat, i), *ring_point(GARDEN, 9.0, deg), 0)
    _spot(s, "roses", *ring_point(GARDEN, 9.0, 45), y=0.57)
    _spot(s, "roses", *ring_point(GARDEN, 12.8, 135))
    s.put(rose_arch(mat), GARDEN[0], 34.5, 0)
    s.put(rose_arch(mat), GARDEN[0] - 11.5, GARDEN[1], 90)
    s.put(topiary_cat(mat), 22, 60, face(22, 60, *GARDEN))
    _spot(s, "topiary", 20, 63)
    s.put(topiary_cat(mat), -10, 30, face(-10, 30, *GARDEN))
    s.put(sundial(mat), 44, 50, 0)
    _spot(s, "sundial", 44, 46)
    s.put(bench(mat), 52, 36, -90)
    _spot(s, "bench", *turned(52, 36, -90, 0, -2.4))
    for (x, z) in ((-46, 50), (40, 66)):
        _spot(s, "lawn", x, z)
    s.put(oak(mat), -40, 58, 30)
    s.put(oak(mat), 48, 60, 200)
    s.put(bench(mat), -50, 40, -90)
    s.put(lamp(mat), -16, 60, 0)
    s.put(lamp(mat), -48, 70, 0)
    s.put(bin_(mat), -46, 66, 0)

    # past the second hedge: the playground (west) and the picnic lawn (east)
    s.put(nb.swings(mat), -44, 106, 0)
    _spot(s, "swings", -44, 102)
    s.put(nb.slide(mat), -26, 105, 180)
    _spot(s, "slide", -23, 109)
    s.put(nb.sandbox(mat), -50, 91, 0)
    _spot(s, "sandbox", -51.5, 89.5, y=0.55)
    s.put(seesaw(mat), -38, 90, 0)
    _spot(s, "seesaw", -38, 87)
    s.put(roundabout(mat), -26, 92, 0)
    _spot(s, "roundabout", -26, 92, y=ROUNDABOUT_TOP)
    s.put(spring_rider(mat), -33, 98, 30)
    s.put(spring_rider(mat, "sign_teal"), -21, 99, -40)
    s.put(bench(mat), -50, 114, 180)
    _spot(s, "playground", -36, 96)
    s.put(lamp(mat), -10, 82, 0)
    s.put(lamp(mat), 2, 108, 0)
    for i, (x, z, r) in enumerate(((32, 84, 10), (46, 112, -8))):
        s.put(picnic_table(mat), x, z, r)
        _spot(s, "picnic", *turned(x, z, r, 0, -4.0))
    s.put(blanket(mat), 24, 100, 25)
    _spot(s, "blanket", 24, 100, y=0.06)
    _spot(s, "lawn", 50, 80)

    # the far end: the bandstand on its loop
    s.put(bandstand(mat), *BAND, 0)
    for (x, z) in ((-3, 0.5), (3, 1), (0, 4)):
        _spot(s, "bandstand", BAND[0] + x, BAND[1] + z, y=1.15)
    for deg in (45, 135, 225, 315):
        s.put(lamp(mat), *ring_point(BAND, LOOP_R + 2.8, deg), 0)
    for deg in (250, 290):
        x, z = ring_point(BAND, LOOP_R + 3.4, deg)
        s.put(bench(mat), x, z, face(x, z, *BAND))
    for deg in (20, 160):
        _spot(s, "loop", *ring_point(BAND, 17.0, deg))
    for (x, z) in ((-30, 146), (40, 146), (-14, 132)):
        _spot(s, "far", x, z)
    for i, (x, z) in enumerate(((-36, 136), (-24, 148), (34, 134), (48, 126))):
        s.put(flower_bed(mat, i + 3), x, z, 0 if i % 2 else 90)

    # more trees, flower patches and the beehives
    for (x, z, r) in ((-40, 2, 0), (-42, 30, 0)):
        s.put(willow(mat), x, z, r)
    for (x, z, r) in ((36, -150, 60), (16, 88, 110), (-36, 124, 200), (47, 25, 300), (-2, -118, 30)):
        s.put(oak(mat), x, z, r)
    s.put(oak(mat, blossom=True), 30, 64, 150)
    s.put(beehives(mat), 52, -54, 180)
    for i, (x, z) in enumerate(((-10, -40), (-8, -24), (22, -56), (30, 44), (-30, 36), (34, 96), (24, 120),
                                (-12, 142), (-48, -132), (48, 70), (-54, 100), (40, -10))):
        s.put(flower_patch(mat, i), x, z, 0)

    # the border trees along the walls
    for (x, z) in ((-52, 148), (-6, 148.5), (22, 148.5), (52, 148), (52, 96), (-52, 120), (52, -100), (-52, -104),
                   (-52, 30), (52, 30), (-52, -36), (52, -150), (-52, 80)):
        s.put(poplar(mat, h=12.0 + (x * 7 + z) % 3), x, z, 0)

    # rescue traps (props placed by the world): 3 trees, 2 bins, four of the five deep, none near the camp
    for (x, z, turn) in ((46, -24, 0), (-46, 30, 180), (46, 98, 0)):
        _spot(s, "trap_tree", x, z, turn=turn)
    for (x, z, turn) in ((-8, 64, 0), (-46, 140, 90)):
        _spot(s, "trap_trashcan", x, z, turn=turn)
    return s.finish(_ground(), mat), s


def build_park_set(mat):
    objs, _ = build_set(mat)
    return objs


ASSETS = {
    NAME: (build_park_set, 150000),
}
