"""Hidden nooks (#2687 part 2, claim #2688): the little walled corner each area opens when its station unlocks, with
one extra rescue spot inside, so ranking up opens a new place to look and not only a new menu.

  CatCafe_Nook_<Area>   Park, Neighbourhood, Woods, Sewer, Desert, Ruins, Snowy, WaterPark. An 8 x 7 walled nook in the area's
                        theme, open at the front (-Z) through a two-leaf gate, with four stepping stones leading
                        out 10.5 studs in front of it. Pivot at the middle of the nook's floor, front -Z: stand it
                        with its back to a wall or a hedge and its stones toward the path. Footprint x -4.3 to 4.3,
                        z -11 to 3.8 (the stones included); everything but the stones and the floor patch is 2.4 to
                        2.9 high, so it reads as a nook, not a building.
                        Child Models `<Name>_GateL` and `<Name>_GateR`: the gate's two leaves, closed, each pivoted
                        on its hinge (x -1.5 and 1.5, z -3.5). A leaf opens by turning about its pivot's Y, the
                        left one by -100 degrees and the right one by +100, so both swing in toward the nook.
                        Attachments: `RescueSpot` in the middle of the floor (0, 0, 0.4), where the area's trap piece
                        goes, a 3 x 3 square kept clear for it; `PathEnd` at the last stone (0, 0, -10.4).
                        Everything collides except the floor patch, the stones and the flowers (`_Decor`).
                        The Woods, Sewer, Desert, Ruins and Snowy nooks carry their trap piece (TRAPS, child Model
                        `<Name>_Trap`): the area's own bramble, grate, clay urn, stone urn or snowdrift, so
                        Layout.setStuckPoses fits the stuck cat as in the set. `RescueSpot` stands on that piece's spot, turned by its
                        turn. The Park and Neighbourhood traps are the bin props the game stands at `RescueSpot`.

Where each nook stands is Layout's (Layout.<area>.nook, #2687): against a side wall in the set's far half, its
stones toward the middle, 9 or more from every cat spot. Every player who can enter an area already owns its station
(the station's tier is the area's), so WorldBuilder builds the nooks for everyone with their gates open.
"""

import math

from mathutils import Matrix, Vector

import common
import desertset
import ruinsset
import snowyset
import waterparkset
import woods
from alleyway import flower_clump
from cannon import frame_at
from common import RB, Builder
from plot import rot_y, rot_z

HW, BACK, FRONT = 4.0, 3.5, -3.5     # the walls' middle lines: sides x +-4, back z 3.5, front z -3.5
T = 0.6                              # wall thickness
WALL_H = 2.4
GATE = 1.5                           # each leaf's width; the opening is 2 * GATE between the hinge posts
STONES = (-5.0, -6.8, -8.6, -10.4)

# area -> wall, cap, gate, stone, floor patch, theme
THEMES = {
    "Park": ("leaf_dark", "leaf_green", "offwhite", "concrete", "leaf_green", "park"),
    "Neighbourhood": ("caramel_wood", "offwhite", "offwhite", "paving_light", "leaf_green", "garden"),
    "Woods": ("fur_brown", "leaf_green", "dark_wood", "fur_dusty", "leaf_dark", "woods"),
    "Sewer": ("brick", "concrete", "fur_soot", "concrete", "concrete_dark", "sewer"),
    "Desert": ("terracotta", "paving_tan", "dark_wood", "paving_tan", "paving_sand", "desert"),
    "Ruins": ("fur_dusty", "leaf_dark", "fur_soot", "fur_pewter", "fur_pewter", "ruins"),
    "Snowy": ("fur_white", "milk", "dark_wood", "fur_silver", "fur_mist", "snowy"),      # a snow fort (#3997)
    "WaterPark": ("milk", "shirt_red", "shirt_blue", "pastel_butter", "paving_light", "funfair"),   # a prize stall (#4066)
}
ATTACHMENTS = {}         # asset -> [(name, Roblox point, Roblox rotation)]


def _grate(mat):
    """The Sewer's grate (sewer.grate) cut down to 3.2 square for the nook: the same heights, so the grate pose fits."""
    b = Builder()
    b.box_base((0, 0, 0), (3.2, 3.2, 0.3), "concrete")
    b.box_base((0, 0, 0.05), (2.5, 2.5, 0.2), "fur_black", bevel=False)
    for i in range(4):
        b.box((-0.9 + i * 0.6, 0, 0.36), (0.2, 2.5, 0.15), "metal", bevel=False)
    b.box((0, 0, 0.4), (2.7, 0.25, 0.12), "metal", bevel=False)
    b.box((1.45, 0, 0.44), (0.25, 0.9, 0.3), "rust", bevel=False)                             # lift handle
    return [b.finalize("CatCafe_Sewer_Grate", mat)]


# area -> (TrapType, piece, spot z, turn): the piece stands on the floor at (0, spot z) turned by turn (Roblox rotY),
# and RescueSpot with it. The clay urn's mouth (its local -X) turns to the gate, so the cat's back end shows through
# it; the urn sits 0.3 forward of the middle so its drift stays inside the back wall.
TRAPS = {
    "Woods": ("bramble_bush", woods.bramble, 0.4, 0),
    "Sewer": ("grate", _grate, 0.4, 0),
    "Desert": ("clay_urn", desertset.trap_clay_urn, -0.3, -90),
    "Ruins": ("stone_urn", ruinsset.trap_stone_urn, 0.4, 0),
    "Snowy": ("snowdrift", snowyset.trap_snowdrift, 0.4, 0),
    "WaterPark": ("plush_pile", waterparkset.trap_plush_nook, 0.4, 0),
}


def _walls(b, wall, cap):
    """Back, sides and the front either side of the gate, a cap along the top, and the two hinge posts."""
    h = WALL_H
    b.span((-HW - T / 2, 0, BACK - T / 2), (HW + T / 2, h, BACK + T / 2), wall)                    # back
    for s in (-1, 1):
        x0, x1 = sorted((s * (HW - T / 2), s * (HW + T / 2)))
        b.span((x0, 0, FRONT - T / 2), (x1, h, BACK - T / 2), wall)                                # sides
        x0, x1 = sorted((s * (GATE + 0.25), s * (HW - T / 2)))                                    # to the side's inner face
        b.span((x0, 0, FRONT - T / 2), (x1, h, FRONT + T / 2), wall)                               # front
    for lo, hi in (((-HW - T / 2 - 0.08, h, BACK - T / 2 - 0.08), (HW + T / 2 + 0.08, h + 0.2, BACK + T / 2 + 0.08)),):
        b.span(lo, hi, cap)
    for s in (-1, 1):
        x0, x1 = sorted((s * (HW - T / 2 - 0.08), s * (HW + T / 2 + 0.08)))
        b.span((x0, h, FRONT - T / 2 - 0.08), (x1, h + 0.2, BACK - T / 2 - 0.08), cap)            # up to the back cap
        x0, x1 = sorted((s * (GATE + 0.25), s * (HW - T / 2 - 0.08)))
        b.span((x0, h, FRONT - T / 2 - 0.08), (x1, h + 0.2, FRONT + T / 2 + 0.08), cap)
        b.span((s * (GATE + 0.25) - 0.25, 0, FRONT - 0.25), (s * (GATE + 0.25) + 0.25, h + 0.5, FRONT + 0.25), cap)
        b.ball((s * (GATE + 0.25), h + 0.62, FRONT), 0.2, cap)


def _leaf(g, side, gate, theme):
    """One gate leaf, closed, built round its hinge at (0, 0, 0): it runs toward the middle (+X for the left leaf)."""
    s = 1 if side == "L" else -1
    w = GATE - 0.04

    def sp(x0, y0, x1, y1, d=0.12):
        a, c = sorted((s * x0, s * x1))
        g.span((a, y0, -d / 2), (c, y1, d / 2), gate)

    sp(0.0, 0.25, 0.12, 2.0)                                                                    # the hinge stile
    sp(w - 0.12, 0.25, w, 1.8)                                                                  # the meeting stile
    sp(0.0, 0.35, w, 0.5)                                                                       # rails
    sp(0.0, 1.55, w, 1.7)
    n = 4
    for k in range(n):                                                                          # pickets or bars
        x = 0.25 + k * (w - 0.5) / (n - 1)
        top = 1.95 - 0.12 * abs(k - (n - 1) / 2) if theme in ("park", "garden") else 1.7
        sp(x - 0.06, 0.35, x + 0.06, top, d=0.08)
    if theme in ("park", "garden"):                                                             # pointed picket tops
        for k in range(n):
            x = s * (0.25 + k * (w - 0.5) / (n - 1))
            top = 1.95 - 0.12 * abs(k - (n - 1) / 2)
            g.box((x, top, 0), (0.12, 0.12, 0.08), gate, rot=rot_z(45))


def _cushion(b, x, z, sw):
    b.cyl((x, 0.18, z), 0.75, 0.32, sw, segments=12)
    b.cyl((x, 0.36, z), 0.55, 0.06, "offwhite", segments=12)


def _pot(b, d, x, z):
    b.cyl((x, 0.35, z), 0.32, 0.7, "terracotta", r2=0.42, segments=10)
    b.ball((x, 0.95, z), 0.42, "leaf_green")
    flower_clump(d, x, 1.05, z, n=3, spread=0.25)


def _theme(b, d, theme):
    """The nook's own pieces in its back corners and along the walls; the middle stays clear for the trap."""
    if theme == "park":
        _cushion(b, -2.4, 2.1, "blush")
        _pot(b, d, 2.6, 2.3)
        for k in range(6):                                                                      # flowers on the hedge
            flower_clump(d, -3.2 + k * 1.28, WALL_H + 0.2, BACK - 0.1, n=3, spread=0.3)
    elif theme == "garden":
        _cushion(b, -2.4, 2.1, "pastel_sky")
        _pot(b, d, 2.6, 2.3)
        b.cyl((2.7, 0.3, 0.4), 0.3, 0.6, "metal", segments=10)                                  # a watering can
        b.box((2.4, 0.5, 0.4), (0.5, 0.08, 0.08), "metal", rot=rot_z(-30))
        b.span((-3.4, 1.0, 3.18), (-1.4, 1.1, 3.2), "dark_wood")                                # a little shelf
        for k in range(3):
            b.cyl((-3.0 + 0.7 * k, 1.3, 2.95), 0.18, 0.4, ("blush", "mint", "pastel_butter")[k], segments=8)
    elif theme == "woods":
        _cushion(b, -2.4, 2.1, "fur_orange")
        for x, z, s in ((2.4, 2.4, 1.0), (3.0, 1.4, 0.7), (2.0, 1.2, 0.55)):                     # mushrooms
            b.cyl((x, 0.25 * s, z), 0.12 * s, 0.5 * s, "cream", segments=8)
            b.cyl((x, 0.55 * s, z), 0.4 * s, 0.22 * s, "shirt_red", r2=0.1 * s, segments=10)
        for k in range(5):                                                                      # moss on the logs
            b.ball((-3.4 + k * 1.7, WALL_H + 0.25, BACK), 0.35, "leaf_green", scale=(1.6, 0.6, 1.0))
    elif theme == "sewer":
        _cushion(b, -2.4, 2.1, "sign_teal")
        b.cyl((0, 1.6, BACK - T / 2 - 0.25), 0.25, 2 * HW - T, "metal", axis="X", segments=10)    # a pipe along the back
        b.span((1.7, 0, 1.6), (3.3, 1.1, 3.1), "caramel_wood")                                  # a crate
        b.span((1.6, 1.1, 1.5), (3.4, 1.2, 3.2), "dark_wood")
    elif theme == "desert":
        _cushion(b, -2.4, 2.1, "eye_amber")
        for x, z, s in ((2.6, 2.3, 1.0), (3.1, 1.2, 0.7)):                                      # urns
            b.cyl((x, 0.45 * s, z), 0.35 * s, 0.9 * s, "terracotta", r2=0.22 * s, segments=10)
            b.ball((x, 0.5 * s, z), 0.45 * s, "terracotta", scale=(1.0, 0.8, 1.0))
            b.cyl((x, 0.95 * s, z), 0.2 * s, 0.12 * s, "fur_copper", segments=10)
        b.span((-3.6, WALL_H + 0.2, BACK - 0.35), (3.6, WALL_H + 0.24, BACK + 0.35), "eye_amber")  # a cloth on the wall
    elif theme == "ruins":
        _cushion(b, -2.4, 2.1, "fur_emerald")
        b.span((1.8, 0, 2.0), (3.2, 1.6, 3.0), "fur_pewter")                                    # a rune stone
        b.span((1.75, 1.0, 1.95), (3.25, 1.15, 3.05), "fur_emerald")
        for x, z, r in ((2.8, 0.6, 0.35),):                                                     # rubble
            b.box((x, r * 0.7, z), (2 * r, 1.4 * r, 2 * r), "fur_dusty", rot=rot_y(30))
        for k in range(4):                                                                      # moss on the stones
            b.ball((-3.0 + k * 2.0, WALL_H + 0.25, BACK), 0.35, "leaf_dark", scale=(1.4, 0.6, 1.0))

    elif theme == "snowy":
        _cushion(b, -2.4, 2.1, "eye_blue")
        for k in range(9):                                                                      # snow blocks on top
            b.span((-3.9 + k * 0.9, WALL_H, BACK - 0.36), (-3.9 + k * 0.9 + 0.8, WALL_H + 0.35 + 0.02 * (k % 2),
                   BACK + 0.36), ("milk", "fur_white")[k % 2])
        for (y, r) in ((0.45, 0.45), (1.1, 0.32), (1.6, 0.22)):                                 # a little snowman
            b.ball((2.8, y, 2.4), r, "milk")
        b.cyl((2.8, 1.6, 2.15), 0.04, 0.22, "fur_orange", axis="Z", segments=6)
        b.cyl((2.8, 1.33, 2.4), 0.3, 0.08, "shirt_red", segments=10)
        b.ball((2.9, 0.25, 1.2), 0.25, "milk")                                                  # snowballs
        b.ball((3.3, 0.25, 1.5), 0.25, "fur_white")

    elif theme == "funfair":
        _cushion(b, -2.9, 2.5, "shirt_red")
        for k in range(8):                                                                      # a striped top rail
            b.span((-3.9 + k * 1.0, WALL_H, BACK - 0.36), (-3.9 + k * 1.0 + 0.9, WALL_H + 0.3, BACK + 0.36),
                   ("shirt_red", "milk")[k % 2])
        b.span((2.95, 0, 2.55), (3.05, 2.6, 2.65), "milk")                                      # a balloon on a stick
        b.ball((3.0, 3.0, 2.6), 0.5, "pastel_butter", scale=(1.0, 1.2, 1.0))
        b.span((2.3, 0, 0.7), (3.4, 0.9, 1.6), "shirt_red")                                     # a popcorn tub
        b.span((2.3, 0.3, 0.68), (3.4, 0.6, 0.7), "milk")
        for k, (x, z) in enumerate(((2.6, 0.95), (3.1, 1.3), (2.85, 1.15))):
            b.ball((x, 1.0 + 0.08 * k, z), 0.24, ("pastel_butter", "cream", "pastel_butter")[k])


def build_nook(area):
    wall, cap, gate, stone, patch, theme = THEMES[area]
    name = f"CatCafe_Nook_{area}"

    def build(mat):
        b, d = RB(), RB()
        _walls(b, wall, cap)
        _theme(b, d, theme)
        d.span((-HW + T / 2, 0, FRONT + T / 2), (HW - T / 2, 0.04, BACK - T / 2), patch)        # the floor patch
        for k, z in enumerate(STONES):                                                          # stepping stones
            d.cyl((0.5 * (-1) ** k, 0.04, z), 0.6, 0.08, stone, segments=10)
        objs = [b.finalize(name, mat), d.finalize(name + "_Decor", mat)]
        for side, x in (("L", -GATE), ("R", GATE)):
            leaf = RB()
            _leaf(leaf, side, gate, theme)
            objs.append(leaf.finalize(f"{name}_Gate{side}", mat, location=(x, 0.0, FRONT)))
        spot_z, turn = 0.4, 0
        if area in TRAPS:
            _, piece, spot_z, turn = TRAPS[area]
            M = Matrix.Translation(RB.p(0.0, 0.0, spot_z)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
            for k, ob in enumerate(piece(mat)):
                ob.matrix_world = M @ ob.matrix_world
                common.bake_transform(ob)
                ob.name = f"{name}_Trap" + ("" if k == 0 else f"{k}")
                objs.append(ob)
        ATTACHMENTS[name] = [("RescueSpot", Vector((0.0, 0.0, spot_z)), rot_y(turn)),
                             ("PathEnd", Vector((0.0, 0.0, STONES[-1])), rot_y(0))]
        return objs
    return build


def rbx_attachments(name):
    return [(name, n, frame_at(p, R)) for n, p, R in ATTACHMENTS.get(name, [])]


ASSETS = {f"CatCafe_Nook_{a}": (build_nook(a), 3000) for a in THEMES}
