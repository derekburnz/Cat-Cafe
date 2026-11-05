"""Decor from data-model section 7 plus a few cheap extras.
Multi-object assets split out parts that need a Studio material (Neon, glass)."""

import math

from alleyway import FACE, MURAL_CATS
from common import RB, Builder, text_width
from plot import rot_z


def build_window_plants(mat):
    """Planter on a sill. Pivot back-bottom center (window side +Y)."""
    b = Builder()
    b.box((0, -0.3, 0.3), (3.0, 0.6, 0.6), "terracotta")
    b.box((0, -0.3, 0.58), (2.8, 0.5, 0.06), "choco", bevel=False)                          # soil, 0.01 proud
    for i, x in enumerate((-1.1, -0.55, 0.0, 0.55, 1.1)):
        b.ico((x, -0.3, 0.85), 0.24, "leaf_green" if i % 2 == 0 else "leaf_dark")
        b.sphere((x + 0.08, -0.4, 1.08), 0.12, ("blush", "offwhite", "rarity_legend")[i % 3], segments=8, rings=5)
    return [b.finalize("CatCafe_Decor_WindowPlants", mat)]


def build_rug(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 2.0, 0.05, "blush", segments=20, bevel=False)
    b.cyl_base((0, 0, 0.05), 1.5, 0.03, "cream", segments=20, bevel=False)
    b.cyl_base((0, 0, 0.08), 0.5, 0.02, "mint", segments=12, bevel=False)
    return [b.finalize("CatCafe_Decor_Rug", mat)]


def build_neon_sign(mat):
    """Wall sign. Board + Tube objects; set the Tube MeshPart to Neon in Studio.
    Pivot at the wall, back-bottom center. The tube spells a cat face outline."""
    board = Builder()
    board.box((0, -0.06, 1.0), (3.0, 0.12, 2.0), "night_sky")
    tube = Builder()
    t, d = 0.12, 0.08
    y = -0.16
    # head outline: a rounded square made of four bars
    for (c, s) in [((0, y, 1.9), (1.8, t, t)), ((0, y, 0.4), (1.8, t, t)), ((-0.9, y, 1.15), (t, t, 1.6)), ((0.9, y, 1.15), (t, t, 1.6))]:
        tube.box(c, s, "neon_pink", bevel=False)
    # ears
    for sx in (-1, 1):
        tube.box((sx * 0.75, y, 2.15), (t, t, 0.55), "neon_pink", bevel=False, rot=(math.radians(sx * 25), "Y"))
        tube.box((sx * 0.5, y, 2.2), (0.55, t, t), "neon_pink", bevel=False, rot=(math.radians(sx * -35), "Y"))
    # eyes and nose
    for sx in (-1, 1):
        tube.box((sx * 0.4, y - 0.01, 1.3), (0.3, t, t), "sign_teal", bevel=False)             # teal sits 0.01 in front of pink
        tube.box((sx * 0.9, y - 0.01, 0.85), (0.5, t, t), "sign_teal", bevel=False, rot=(math.radians(sx * 10), "Y"))
    tube.box((0, y, 0.95), (0.25, t, 0.12), "neon_pink", bevel=False)
    return [board.finalize("CatCafe_Decor_NeonSign_Board", mat), tube.finalize("CatCafe_Decor_NeonSign_Tube", mat)]


def build_fish_tank(mat):
    """Stand + Water + Glass + Fish objects. Set Glass Transparency 0.5 and
    Water Transparency 0.3 in Studio. Pivot base center."""
    stand = Builder()
    stand.box_base((0, 0, 0), (3.2, 1.4, 1.6), "dark_wood")
    stand.box((0, -0.71, 0.8), (2.6, 0.04, 1.0), "caramel_wood", bevel=False)
    stand.box_base((0, 0, 1.6), (3.3, 1.5, 0.12), "concrete_dark")
    stand.box_base((0, 0, 1.72), (2.96, 1.16, 0.25), "kibble")                # gravel, inside the glass
    for i, x in enumerate((-1.0, -0.2, 0.9)):
        stand.cyl_base((x, 0.2 - i * 0.15, 1.97), 0.08, 0.9 + i * 0.2, "leaf_dark", segments=6, bevel=False)
    stand.sphere((0.4, -0.2, 2.15), 0.22, "concrete", segments=8, rings=5)   # rock
    stand.box_base((0, 0, 3.7), (3.1, 1.3, 0.15), "dark_wood")               # lid
    water = Builder()
    water.box_base((0, 0, 1.97), (2.96, 1.16, 1.6), "puddle")
    glass = Builder()
    glass.box_base((0, 0, 1.72), (3.0, 1.2, 2.0), "glass", bevel=False)
    fish = Builder()
    for (x, y, z, c, f) in [(-0.6, 0.0, 2.8, "fish_blue", 1), (0.5, 0.2, 3.1, "rarity_legend", -1), (0.1, -0.3, 2.5, "neon_pink", 1)]:
        fish.sphere((x, y, z), 0.16, c, segments=8, rings=5, scale=(1.2, 0.6, 0.8))
        fish.pyramid((x - f * 0.22, y, z - 0.1), 0.18, 0.2, c, rot=(math.radians(-f * 90), "Y"))
    return [stand.finalize("CatCafe_Decor_FishTank_Stand", mat), water.finalize("CatCafe_Decor_FishTank_Water", mat),
            glass.finalize("CatCafe_Decor_FishTank_Glass", mat), fish.finalize("CatCafe_Decor_FishTank_Fish", mat)]


def build_hanging_lamp(mat):
    """Pivot at the ceiling hook; geometry hangs down. Bulb is its own object for Neon."""
    lamp = Builder()
    lamp.cyl((0, 0, -0.8), 0.04, 1.6, "dark_wood", segments=6, bevel=False)
    lamp.cyl((0, 0, -1.95), 0.8, 0.7, "mint", segments=16, radius2=0.3)
    lamp.cyl((0, 0, -1.58), 0.34, 0.08, "dark_wood", segments=12, bevel=False)
    bulb = Builder()
    bulb.sphere((0, 0, -2.4), 0.2, "lamp_warm", segments=10, rings=6)
    return [lamp.finalize("CatCafe_Decor_HangingLamp_Shade", mat), bulb.finalize("CatCafe_Decor_HangingLamp_Bulb", mat)]


def build_plant_pot(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.4, 0.8, "terracotta", segments=10, radius2=0.5)
    b.ring((0, 0, 0.74), 0.56, 0.1, 0.12, "terracotta", segments=12, bevel=False)
    b.cyl_base((0, 0, 0.78), 0.45, 0.04, "choco", segments=12, bevel=False)
    b.cyl_base((0, 0, 0.8), 0.06, 0.5, "leaf_dark", segments=6, bevel=False)
    b.ico((0, 0, 1.45), 0.45, "leaf_green")
    b.ico((0.3, 0.1, 1.2), 0.3, "leaf_dark")
    b.ico((-0.25, -0.2, 1.3), 0.28, "leaf_green")
    return [b.finalize("CatCafe_Decor_PlantPot", mat)]


def build_menu_board(mat):
    """Wall board, pivot back-bottom center."""
    b = Builder()
    b.box((0, -0.05, 0.75), (2.0, 0.1, 1.5), "dark_wood")
    for (c, s) in [((0, -0.075, 1.46), (2.1, 0.14, 0.08)), ((0, -0.075, 0.04), (2.1, 0.14, 0.08)), ((-1.02, -0.075, 0.75), (0.08, 0.14, 1.5)), ((1.02, -0.075, 0.75), (0.08, 0.14, 1.5))]:
        b.box(c, s, "caramel_wood", bevel=False)
    for i, z in enumerate((1.25, 1.0, 0.75, 0.5)):
        b.box((-0.15, -0.115, z), (1.2 - i * 0.15, 0.03, 0.1), "offwhite" if i else "mint", bevel=False)
        b.box((0.75, -0.115, z), (0.3, 0.03, 0.1), "rarity_legend", bevel=False)
    b.box((0, -0.115, 0.25), (0.8, 0.03, 0.12), "blush", bevel=False)
    return [b.finalize("CatCafe_Decor_MenuBoard", mat)]


def build_cup(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.16, 0.3, "offwhite", segments=12, radius2=0.19)
    b.cyl_base((0, 0, 0.28), 0.16, 0.03, "choco", segments=12, bevel=False)                 # coffee, 0.01 above the rim
    b.box((0.25, 0, 0.16), (0.06, 0.06, 0.18), "offwhite", bevel=False)
    b.box((0.21, 0, 0.25), (0.14, 0.06, 0.05), "offwhite", bevel=False)
    b.box((0.21, 0, 0.07), (0.14, 0.06, 0.05), "offwhite", bevel=False)
    b.cyl_base((0, 0, 0), 0.35, 0.03, "offwhite", segments=12, bevel=False)   # saucer
    return [b.finalize("CatCafe_Decor_Cup", mat)]


FONT = {  # 3 x 5 pixel letters, top row first
    "O": ["111", "101", "101", "101", "111"], "P": ["111", "101", "111", "100", "100"],
    "E": ["111", "100", "111", "100", "111"], "N": ["1001", "1101", "1011", "1001", "1001"],
    "C": ["111", "100", "100", "100", "111"], "L": ["100", "100", "100", "100", "111"],
    "S": ["111", "100", "111", "001", "111"], "D": ["110", "101", "101", "101", "110"],
}


def _text_cols(text):
    """Width of a word in pixel columns, one blank column between letters."""
    return sum(len(FONT[ch][0]) for ch in text) + len(text) - 1


def _letters(b, text, center, px, swatch, y):
    """Pixel letters as flat boxes on the plane y, centered on center=(x, z)."""
    x = center[0] - _text_cols(text) * px / 2
    for ch in text:
        rows = FONT[ch]
        for r, row in enumerate(rows):
            for c, bit in enumerate(row):
                if bit == "1":
                    b.box((x + c * px + px / 2, y, center[1] + (2 - r) * px), (px, 0.04, px), swatch, bevel=False)
        x += (len(rows[0]) + 1) * px


SIGN_W, SIGN_H, SIGN_T = 2.2, 1.1, 0.1         # #1140 door-sign.md section 2: the board
SIGN_TOP = -0.5                                 # its top edge under the hook (the pivot); its middle at -1.05
MOON = ("..##.....", ".##......", "###......", "###......", "###......", ".####....", "..#####..")


def _rounded(cx, cy, w, h, r, steps=2):
    """A rounded rectangle's outline (Roblox x, y), counter-clockwise from the right edge."""
    pts = []
    for (qx, qy, a0) in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180),
                         (w / 2 - r, -h / 2 + r, 270)):
        for k in range(steps + 1):
            a = math.radians(a0 + 90 * k / steps)
            pts.append((cx + qx + r * math.cos(a), cy + qy + r * math.sin(a)))
    return pts + pts[:1]                                 # closed: the fan draws one wedge per pair


def build_door_sign(mat):
    """#1140 (door-sign.md): the cafe's one Open/Closed sign, hung on the front door from the cafe shell's SignHook
    (under the transom bar). A rounded two-sided wooden board on a twine V from a brass hook. Pivot at the hook point
    (the board hangs below it, centred on it in x and z), front -Z toward the street:
      CatCafe_Decor_DoorSign_Open     (parts in the root) the cream OPEN face on the front (-Z), cocoa letters and a
                                      pink paw print
      CatCafe_Decor_DoorSign_Hanger   (child Model) the brass hook, the twine and the wooden board with its darker rim:
                                      always shown
      CatCafe_Decor_DoorSign_Closed   (child Model) the dusky blue CLOSED face on the back (+Z), cream letters, and
        ..._Closed_Moon_Bulb          its crescent moon (child Model inside it), which glows with the night parts
    By day OPEN faces the street; at nightfall Effects/DoorSign turns the whole sign 180 degrees about the hook's
    vertical axis so CLOSED does (the board is centred on that axis, so it turns in place)."""
    opn, hang, cls, moon = RB(), RB(), RB(), RB()
    cy = SIGN_TOP - SIGN_H / 2
    hang.b.ring(RB.p(0, -0.09, 0), 0.06, 0.018, 0.018, "brass", segments=8, rot=(math.radians(90), "X"))   # hook eye
    hang.span((-0.015, -0.03, -0.015), (0.015, 0.0, 0.015), "brass")                       # its screw, into the bar
    for sx in (-1, 1):                                                                      # the twine V
        ax, ay, bx, by = 0.0, -0.14, sx * 0.75, SIGN_TOP - 0.02
        L = math.hypot(bx - ax, by - ay)
        hang.box(((ax + bx) / 2, (ay + by) / 2, 0), (0.03, L + 0.02, 0.03), "treat_tan",
                 rot=rot_z(math.degrees(math.atan2(bx - ax, ay - by))))
        hang.cyl((bx, SIGN_TOP - 0.06, 0), 0.04, SIGN_T + 0.02, "brass", axis="Z", segments=6)  # an eyelet
    hang.fan_z(0, (0, cy), _rounded(0, cy, SIGN_W, SIGN_H, 0.22), SIGN_T, "dark_wood")    # board with its rim
    fw, fh, ft = SIGN_W - 0.16, SIGN_H - 0.16, 0.02
    fz = SIGN_T / 2 + ft / 2 - 0.005                                                        # 0.005 into the board
    opn.fan_z(-fz, (0, cy), _rounded(0, cy, fw, fh, 0.16), ft, "cream")
    cls.fan_z(fz, (0, cy), _rounded(0, cy, fw, fh, 0.16), ft, "night_sky")
    # OPEN: cocoa letters, a pink paw after the word (read from the street, -Z)
    px = 0.085
    w = text_width("OPEN", px)
    paw_w = 0.32
    x0 = -(w + 0.12 + paw_w) / 2
    face_o = -(fz + ft / 2) + 0.004                      # letters start 0.004 inside the face
    # x0 is in the street viewer's left-to-right terms, which run along Roblox -X: the first letter sits at x -x0
    opn.text("OPEN", (-x0, cy - 2.5 * px, face_o), px, 0.03, "choco", right=(-1, 0, 0))
    pcx = -(x0 + w + 0.12 + paw_w / 2)                                                      # the paw, after the word
    for dx, dy, r in ((0.0, -0.06, 0.09), (-0.1, 0.07, 0.04), (-0.035, 0.12, 0.04), (0.035, 0.12, 0.04),
                      (0.1, 0.07, 0.04)):
        opn.cyl((pcx + dx, cy + dy, face_o - 0.012), r, 0.025, "fur_bubblegum", axis="Z", segments=6)
    # CLOSED: cream letters and the crescent moon, read from behind (+Z), which faces the street once turned
    px2 = 0.07
    w2 = text_width("CLOSED", px2)
    mp = 0.05
    mw = 9 * mp
    face_c = fz + ft / 2 - 0.004
    xs = -(w2 + 0.1 + mw) / 2                                                               # from the viewer's left
    cls.text("CLOSED", (xs + mw + 0.1, cy - 2.5 * px2, face_c), px2, 0.03, "offwhite", right=(1, 0, 0))
    mtop = cy + len(MOON) * mp / 2
    for r, row in enumerate(MOON):                       # one block per run; seen from +Z, left to right is +X,
        c0 = row.index("#")                              # so the horns point toward the text
        c1 = row.rindex("#") + 1
        moon.span((xs + c0 * mp, mtop - (r + 1) * mp, face_c - 0.002), (xs + c1 * mp, mtop - r * mp, face_c + 0.025),
                  "sparkle")
    return [opn.finalize("CatCafe_Decor_DoorSign_Open", mat), hang.finalize("CatCafe_Decor_DoorSign_Hanger", mat),
            cls.finalize("CatCafe_Decor_DoorSign_Closed", mat), moon.finalize("CatCafe_Decor_DoorSign_Closed_Moon_Bulb", mat)]


DOOR_SIGN_NEST = {"_Closed_Moon_Bulb": "_Closed"}


def build_string_lights(mat):
    """8 stud strand of cafe lights. Pivot at the left end; the strand runs +X and sags
    in the middle. Wire + Bulbs objects; Bulbs get Neon and a soft PointLight at night."""
    wire = Builder()
    bulbs = Builder()
    n, length, sag = 16, 8.0, 0.7
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((t * length, 0, -sag * (1 - (2 * t - 1) ** 2)))
    for a, c in zip(pts, pts[1:]):
        mid = ((a[0] + c[0]) / 2, 0, (a[2] + c[2]) / 2)
        dx, dz = c[0] - a[0], c[2] - a[2]
        ang = math.atan2(dz, dx)
        wire.box(mid, (math.hypot(dx, dz) + 0.02, 0.05, 0.05), "fur_black", bevel=False, rot=(-ang, "Y"))
    for i in range(1, n, 2):
        x, _, z = pts[i]
        wire.cyl((x, 0, z - 0.1), 0.07, 0.14, "fur_black", segments=6, bevel=False)
        bulbs.sphere((x, 0, z - 0.3), 0.16, "lamp_warm", segments=6, rings=4)
    return [wire.finalize("CatCafe_Decor_StringLights_Wire", mat), bulbs.finalize("CatCafe_Decor_StringLights_Bulbs", mat)]


# Book decor (data-model section 7, F48): a reward piece per area, never sold, plus a gold version.
def _rects(grid):
    """Pixel grid (rows of chars, top first, '.' empty) as rectangles (r0, r1, c0, c1, ch): runs of a char in a
    row, merged down while the next row has the same run."""
    out, open_ = [], {}
    for r, row in enumerate(list(grid) + [""]):
        runs, c = set(), 0
        while c < len(row):
            if row[c] == ".":
                c += 1
                continue
            e = c
            while e < len(row) and row[e] == row[c]:
                e += 1
            runs.add((c, e, row[c]))
            c = e
        for key in list(open_):
            if key not in runs:
                out.append((open_.pop(key), r) + key)
        for key in runs:
            open_.setdefault(key, r)
    return out


def _mural_face(b, rows, colours, x0, y_top, px, z):
    """One mural cat face on a print, reading toward -X from x0, in three layers out from depth z: the head
    and ears, then the markings, eyes (pupils filled), nose and muzzle, then the pupils."""
    base = [row if r < 2 else "".join("F" if ch != "." else "." for ch in row) for r, row in enumerate(rows)]
    marks = ["." * len(row) if r < 2 else "".join("E" if ch == "P" else ch if colours.get(ch) != colours["F"] else "."
                                                    for ch in row) for r, row in enumerate(rows)]
    pupils = ["".join(ch if ch == "P" else "." for ch in row) for row in rows]
    for k, grid in enumerate((base, marks, pupils)):
        for r0, r1, c0, c1, ch in _rects(grid):
            b.span((x0 - c1 * px, y_top - r1 * px, z - 0.02 * (k + 1)), (x0 - c0 * px, y_top - r0 * px, z - 0.02 * k),
                   colours[ch])


def build_mural_print(mat, name="CatCafe_Decor_MuralPrint", frame="caramel_wood", lip="dark_wood", plaque=None):
    """Book decor for the Alleyway: the Alley mural (alleyway.build_mural) as a small framed print, at 0.11 scale
    with its colour bands, sun and five cat faces. Wall piece, hung like the neon sign: pivot back-bottom centre,
    the back on the wall, the front facing -Z (Roblox), 3.6 x 1.8 x 0.2 studs (the engineer's spot is 3.6 wide)."""
    b = RB()
    fr, mat_w = 0.2, 0.12                               # frame width, mat border at the sides
    ow, oh = 1.8, 1.8                                   # outer half width, outer height
    s = (2 * ow - 2 * (mat_w + fr)) / 27                # mural studs -> print studs
    w, h = 27 * s, 11 * s                               # canvas
    mat_h = (oh - h) / 2 - fr                           # mat border above and below
    iw = ow - fr
    zm = -0.06                                          # the mat's face; the picture builds out from it
    b.span((-ow, 0, -0.18), (ow, fr, 0), frame)                                           # frame
    b.span((-ow, oh - fr, -0.18), (ow, oh, 0), frame)
    for sx in (-1, 1):
        b.span((sx * iw, fr, -0.18), (sx * ow, oh - fr, 0), frame)
        b.span((sx * (iw - 0.05), fr, -0.19), (sx * iw, oh - fr, zm), lip)                # inner lip, sides
    b.span((-iw + 0.05, fr, -0.19), (iw - 0.05, fr + 0.05, zm), lip)
    b.span((-iw + 0.05, oh - fr - 0.05, -0.19), (iw - 0.05, oh - fr, zm), lip)
    b.span((-iw + 0.05, fr + 0.05, zm), (iw - 0.05, oh - fr - 0.05, 0), "offwhite")      # mat and backing

    y0 = fr + mat_h

    def y(my):                                          # mural height -> print height
        return y0 + (my - 1.5) * s

    for (ya, yb, sw) in ((1.5, 3.0, "leaf_green"), (3.0, 6.0, "lamp_warm"), (6.0, 9.0, "blush"), (9.0, 12.5, "pastel_lilac")):
        b.span((-w / 2, y(ya), zm - 0.02), (w / 2, y(yb), zm), sw)
    b.cyl((10.4 * s, y(10.4), zm - 0.03), 1.5 * s, 0.02, "sparkle", axis="Z", segments=12)
    for k in range(8):                                                                    # sun rays
        a = math.radians(22.5 + 45 * k)
        b.box((10.4 * s + 2.0 * s * math.cos(a), y(10.4) + 2.0 * s * math.sin(a), zm - 0.03), (0.7 * s, 0.2 * s, 0.02),
              "sparkle", rot=rot_z(math.degrees(a)))
    px = 0.55 * s
    for k, (_, colours, override) in enumerate(MURAL_CATS):
        rows = [override.get(r, row) for r, row in enumerate(FACE)]
        cx = (-10.8 + 5.4 * (4 - k)) * s                # the first cat reads leftmost, as on the mural
        _mural_face(b, rows, colours, cx + 4 * px, y(3.5 + 8 * 0.55), px, zm - 0.02)
    if plaque:                                                                            # name plate on the frame
        b.span((-0.45, 0.04, -0.2), (0.45, 0.16, -0.18), plaque)
    return [b.finalize(name, mat)]


def build_book_bench(mat, name="CatCafe_Decor_ParkBench", slat="caramel_wood", iron="concrete_dark", cap="concrete_dark"):
    """Book decor for the Park: a little indoor copy of the Park bench (3 x 1.3 x 2.4, seat at 1.1) with curled
    armrests and a mint cushion with a paw print. Pivot base centre, front -Y."""
    b = Builder()
    for sx in (-1, 1):
        x = sx * 1.4
        b.box_base((x, -0.45, 0), (0.16, 0.16, 0.89), iron)                               # front leg
        b.box_base((x, 0.5, 0), (0.16, 0.16, 2.2), iron)                                  # back post
        b.box_base((x, -0.065, 0.89), (0.16, 0.97, 0.12), iron)                           # seat rail, leg to post
        b.box_base((x, -0.45, 1.11), (0.16, 0.16, 0.39), iron)                            # arm post
        b.box_base((x, -0.09, 1.5), (0.16, 1.02, 0.12), iron)                             # armrest
        b.cyl((x, -0.6, 1.56), 0.1, 0.16, iron, segments=8, rot=(math.radians(90), "Y"))  # scroll at its front
        b.sphere((x, 0.5, 2.28), 0.1, cap, segments=8, rings=5)                           # post finial
    for yc in (-0.45, -0.2, 0.05, 0.3):                                                    # seat slats
        b.box_base((0, yc, 1.01), (3.0, 0.19, 0.1), slat)
    for z in (1.25, 1.62, 1.96):                                                           # back slats
        b.box_base((0, 0.37, z), (3.0, 0.1, 0.18), slat)
    b.box_base((0.62, -0.1, 1.11), (0.9, 0.66, 0.14), "mint")                              # cushion
    b.box_base((0.62, -0.13, 1.25), (0.24, 0.18, 0.02), "offwhite", bevel=False)           # paw print
    for dx, dy in ((-0.15, 0.06), (0, 0.13), (0.15, 0.06)):
        b.box_base((0.62 + dx, -0.13 + dy + 0.1, 1.25), (0.08, 0.08, 0.02), "offwhite", bevel=False)
    return [b.finalize(name, mat)]


ASSETS = {
    "CatCafe_Decor_DoorSign": (build_door_sign, 1500),   # #1140: one two-sided board (block letters, no texture)
    "CatCafe_Decor_StringLights": (build_string_lights, 800),
    "CatCafe_Decor_WindowPlants": (build_window_plants, 800),
    "CatCafe_Decor_Rug": (build_rug, 500),
    "CatCafe_Decor_NeonSign": (build_neon_sign, 500),
    "CatCafe_Decor_FishTank": (build_fish_tank, 1200),
    "CatCafe_Decor_HangingLamp": (build_hanging_lamp, 500),
    "CatCafe_Decor_PlantPot": (build_plant_pot, 500),
    "CatCafe_Decor_MenuBoard": (build_menu_board, 500),
    "CatCafe_Decor_Cup": (build_cup, 300),
    "CatCafe_Decor_MuralPrint": (build_mural_print, 1500),
    "CatCafe_Decor_MuralPrint_Gold": (lambda mat: build_mural_print(
        mat, "CatCafe_Decor_MuralPrint_Gold", frame="gold_mid", lip="gold_light", plaque="gold_light"), 1500),
    "CatCafe_Decor_ParkBench": (build_book_bench, 1200),
    "CatCafe_Decor_ParkBench_Gold": (lambda mat: build_book_bench(
        mat, "CatCafe_Decor_ParkBench_Gold", slat="gold_light", iron="gold_dark", cap="gold_mid"), 1200),
}
