"""The Christmas Advent Calendar board (#5502, advent-calendar-spec section 8): a big wooden calendar for the Town
Square beside the giant snow globe. Built in Roblox axes (RB: x across, +x on the viewer's left, y up, -Z the
front); the pivot is the base centre between the posts, on the paving.

  CatCafe_Square_AdventBoard   a green board in a red and gold frame under a snowy gable with ADVENT on it and a
                               lit star on top, 24 numbered doors in 6 rows of 4, on two posts over a planter.
                               Each door is its own object, `_Door01` to `_Door24`, pivoted on its hinge (the
                               viewer's left edge), so code swings it open by turning it about Y (negative turns
                               open it out to the front). Doors 6, 12, 18 and 24 hide the calendar cats: they are
                               gold with a star. Behind each door is a cream nook with an Attachment `Prize01` to
                               `Prize24` at its middle, facing the front, for the prize picture. `PromptAnchor`
                               sits at chest height in front of the board's middle. The star is `_Star_Glow`.
"""

import math

from mathutils import Matrix, Vector

from cannon import frame_at
from common import GLYPHS, RB, _glyph_rects

NAME = "CatCafe_Square_AdventBoard"
GOLD, FRAME, BOARD, NOOK, SNOW = "rarity_legend", "shirt_red", "leaf_dark", "cream", "milk"
DIGITS = {"0": ("111", "101", "101", "101", "111"), "1": ("010", "110", "010", "010", "111"),
          "2": ("111", "001", "111", "100", "111"), "3": ("111", "001", "011", "001", "111"),
          "4": ("101", "101", "111", "001", "001"), "5": ("111", "100", "111", "001", "111"),
          "6": ("111", "100", "111", "101", "111"), "7": ("111", "001", "010", "010", "010"),
          "8": ("111", "101", "111", "101", "111"), "9": ("111", "101", "111", "001", "111")}
LETTERS = {**GLYPHS, **DIGITS}
CAT_DOORS = (6, 12, 18, 24)

COLS, ROWS = 4, 6
DOOR, GAP = 1.25, 0.22                     # a door is 1.25 studs square; numbers are 0.6 tall (readable at 15 studs)
GRID_W = COLS * DOOR + (COLS + 1) * GAP
GRID_H = ROWS * DOOR + (ROWS + 1) * GAP
BOTTOM = 1.7                               # the grid's bottom edge above the paving
FACE_Z = -0.25                             # the board's front face; doors stand just proud of it
NOOK_Z = -0.08                             # the back of each nook
SPOT = (-30.0, 0.1, 44.0, 180.0)           # suggested Town Square spot (x, y, z, turn): GE places it by the globe


def _width(s, px):
    return (sum(len(LETTERS[ch][0]) + 1 for ch in s) - 1) * px


def _text(b, s, cx, y, z, px, depth, swatch):
    """Block letters and digits centred on cx, reading left to right from the front (-Z), standing proud of z."""
    rx, ux, nrm = Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, -1))
    origin = Vector((cx + _width(s, px) / 2, y, z))
    cur = 0
    for ch in s:
        g = LETTERS[ch]
        for r, c, e, h in _glyph_rects(g):
            a = origin + rx * ((cur + c) * px) + ux * ((5 - h) * px)
            bv = a + rx * ((e - c) * px) + ux * ((h - r) * px) + nrm * depth
            b.span([min(a[i], bv[i]) for i in range(3)], [max(a[i], bv[i]) for i in range(3)], swatch)
        cur += len(g[0]) + 1


def door_centre(n):
    """The middle of door n's opening (1 at the top left seen from the front, reading across then down)."""
    i = n - 1
    col, row = i % COLS, i // COLS
    x = GRID_W / 2 - GAP - DOOR / 2 - col * (DOOR + GAP)          # +x is the viewer's left
    y = BOTTOM + GRID_H - GAP - DOOR / 2 - row * (DOOR + GAP)
    return x, y


def _door(n, mat):
    cat = n in CAT_DOORS
    d = RB()
    wx, wy = door_centre(n)
    hinge = (wx + DOOR / 2, wy, FACE_Z - 0.02)
    x, y = -DOOR / 2, 0.0                                          # drawn about the hinge, the object's pivot
    z0, z1 = -0.08, 0.0
    face = GOLD if cat else ("bowl_red", "cream", "shirt_green")[n % 3]
    ink = "dark_wood" if face in (GOLD, "cream") else "cream"
    d.span((x - DOOR / 2 + 0.02, y - DOOR / 2 + 0.02, z0), (x + DOOR / 2 - 0.02, y + DOOR / 2 - 0.02, z1), face)
    rim = "bowl_red" if cat else GOLD                              # a thin frame round the door's face
    for lo, hi in (((x - DOOR / 2 + 0.02, y + DOOR / 2 - 0.1), (x + DOOR / 2 - 0.02, y + DOOR / 2 - 0.02)),
                   ((x - DOOR / 2 + 0.02, y - DOOR / 2 + 0.02), (x + DOOR / 2 - 0.02, y - DOOR / 2 + 0.1))):
        d.span((lo[0], lo[1], z0 - 0.02), (hi[0], hi[1], z0), rim)
    label = str(n)
    _text(d, label, x, y - 0.3, z0, 0.12, 0.03, ink)
    if cat:                                                        # red stars in the top corners of the cat doors
        for sx in (-1, 1):
            d.b.star(RB.p(x + sx * 0.44, y + 0.4, z0 - 0.02), 0.13, 0.055, 0.04, "bowl_red", rot=(math.radians(90), "X"))
    d.cyl((x - DOOR / 2 + 0.16, y - 0.05, z0 - 0.04), 0.06, 0.06, "brass", axis="Z", segments=8)   # the knob
    return d.finalize(f"{NAME}_Door{n:02d}", mat, location=hinge)


def build_board(mat):
    b, star = RB(), RB()
    W, H = GRID_W + 0.7, GRID_H + 0.7
    y0 = BOTTOM - 0.35
    # the posts and the planter at their feet
    for sx in (-1, 1):
        b.span((sx * (W / 2 - 0.15) - 0.25, 0, -0.1), (sx * (W / 2 - 0.15) + 0.25, y0 + 0.1, 0.4), "dark_wood")
    b.span((-W / 2 - 0.2, 0, -0.55), (W / 2 + 0.2, 0.7, 0.5), "caramel_wood")
    b.span((-W / 2 - 0.25, 0.62, -0.6), (W / 2 + 0.25, 0.76, 0.55), "dark_wood")
    for k in range(7):                                             # little fir sprigs and berries in the planter
        x = -W / 2 + 0.45 + k * (W - 0.9) / 6
        b.b.pyramid(RB.p(x, 0.76, -0.05), 0.5, 0.55, "leaf_green")
        b.ball((x + 0.12, 0.95, -0.3), 0.07, "bowl_red")
    # the board: frame, green face, nooks behind the doors
    b.span((-W / 2, y0, -0.05), (W / 2, y0 + H, 0.35), FRAME)
    b.span((-W / 2 + 0.15, y0 + 0.15, FACE_Z), (W / 2 - 0.15, y0 + H - 0.15, -0.05), BOARD)
    for edge in ((y0 + 0.05, y0 + 0.15), (y0 + H - 0.15, y0 + H - 0.05)):
        b.span((-W / 2 + 0.05, edge[0], FACE_Z - 0.01), (W / 2 - 0.05, edge[1], -0.05), GOLD)
    for n in range(1, 25):
        x, y = door_centre(n)
        b.span((x - DOOR / 2, y - DOOR / 2, NOOK_Z - 0.03), (x + DOOR / 2, y + DOOR / 2, NOOK_Z), NOOK)
        for sx in (-1, 1):                                         # the nook's sides, so it reads as a little box
            b.span((x + sx * DOOR / 2 - 0.02, y - DOOR / 2, FACE_Z - 0.005), (x + sx * DOOR / 2 + 0.02, y + DOOR / 2, NOOK_Z),
                   "dark_wood")
    # the gable with ADVENT, snow on its slopes and the lit star on top
    top = y0 + H
    gh = 1.9
    b.fan_z(0.15, (0, top + gh), [(W / 2 + 0.2, top), (-W / 2 - 0.2, top)], 0.4, FRAME)
    b.span((-W / 2 + 0.6, top + 0.15, -0.1), (W / 2 - 0.6, top + 0.95, 0.0), "dark_wood")
    _text(b, "ADVENT", 0.0, top + 0.27, -0.1, 0.11, 0.03, "cream")
    for sx in (-1, 1):                                             # snow along each slope
        a, c = Vector((sx * (W / 2 + 0.25), top - 0.02, 0.15)), Vector((0, top + gh + 0.05, 0.15))
        d = c - a
        R = Matrix.Rotation(math.atan2(d.y, d.x), 3, "Z")
        b.box(tuple((a + c) / 2 + Vector((0, 0.12, 0))), (d.length, 0.18, 0.6), SNOW, rot=R)
    b.span((-W / 2 - 0.1, top - 0.02, -0.12), (W / 2 + 0.1, top + 0.12, 0.42), SNOW)
    b.cyl((0, top + gh + 0.2, 0.15), 0.06, 0.4, "brass")
    star.b.star(RB.p(0, top + gh + 0.65, 0.15), 0.55, 0.24, 0.16, GOLD, rot=(math.radians(90), "X"))
    star.b.star(RB.p(0, top + gh + 0.65, 0.06), 0.26, 0.11, 0.04, "sparkle", rot=(math.radians(90), "X"))
    # a string of lights along the frame's top edge
    lights = RB()
    for k in range(11):
        x = -W / 2 + 0.3 + k * (W - 0.6) / 10
        lights.ball((x, top - 0.25 - 0.08 * math.sin(k * 1.4), -0.1), 0.09,
                    ("bowl_red", GOLD, "leaf_green", "fish_blue")[k % 4])
    out = [b.finalize(NAME, mat), star.finalize(NAME + "_Star_Glow", mat), lights.finalize(NAME + "_Bulbs", mat)]
    out += [_door(n, mat) for n in range(1, 25)]
    return out


def rbx_attachments(name):
    out = []
    for n in range(1, 25):
        x, y = door_centre(n)
        out.append((name, f"Prize{n:02d}", frame_at(Vector((x, y, NOOK_Z - 0.05)), Matrix.Identity(3))))
    out.append((name, "PromptAnchor", frame_at(Vector((0, 3.2, FACE_Z - 2.5)), Matrix.Identity(3))))
    return out


ASSETS = {NAME: (build_board, 9000)}
