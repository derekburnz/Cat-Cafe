"""Town buildings for the back alleys' outer walls (Derek 2026-10-27 22:37: "the random staff writing and repeated
walls should be full buildings that are on the side of the map and need more variety"). Eight buildings, each its own
colour, height, roof and details, with picture signs instead of words, to stand where the brick building backs
(alleyway.py: WallWindows, WallDoor, FireEscape) stand now.

  CatCafe_Alley_Building_<Name>   Bakery, Townhouses, Warehouse, Grocer, Apartments, ClockHouse, MusicShop,
                                  NarrowHouses. 30.6 wide like the backs they replace, so Layout's BACK_WIDTH and
                                  slots hold. Pivot on the back plane at the bottom centre, -Z into the lane, like the
                                  other wall pieces, but the body is 3 deep and stands over the 1 thick outer wall:
                                  set the back plane (the line of the back sills and eaves) 2.25 behind the wall's
                                  inner face; the body's back is then 2 behind, where the Woods' and the Sewer's own
                                  walls start, and the facade 1 out into the lane, where the old backs' faces were.
                                  Its roof, chimneys and rooftop pieces sit on top; the lane side keeps within 3.5 of
                                  the facade (the Warehouse's fire escape 4, as before). The back faces the area
                                  behind with plain windows. `_Pane` holds the lit windows (glow at night),
                                  `_Lamp_Bulb` the door lamps, `_Flowers` window boxes and planters (no collision
                                  needed).
  The Warehouse carries the walkable fire escape of CatCafe_Alley_FireEscape at the same place on its facade (LEDGES,
  in its own frame), so the crate stack beside it still climbs onto landing 1; its parapet tops out at 26.3, out of
  reach from landing 2.
"""

import math

from mathutils import Matrix

from alleyway import _ac, _drainpipe, bar, fire_escape_kit, flower_clump
from common import RB, bake_transform
from plot import arc, rot_x, rot_y, rot_z

N = "CatCafe_Alley_Building_"
HW = 15.0                    # half the body; eaves and cornices reach 15.3, the 30.6 of the backs they replace
F, BK = -1.0, 2.0            # the facade's face toward the lane (-Z) and the back face, from the wall's inner face
                             # (the alley kit's frame, which fire_escape_kit uses); _parts moves the pivot to the back
BODY_Y = 0.05                # bodies start inside the plinth, so no face lies on the plinth's bottom
BACK = BK + 0.25             # the back sills and eaves: the pivot's back plane, 2.25 behind the wall's inner face


# ---------------------------------------------------------------------------------------------- helpers --
def _body(b, x0, x1, h, sw):
    b.span((x0, BODY_Y, F), (x1, h, BK), sw)


def _plinth(b, x0, x1, sw="concrete", h=0.9):
    b.span((x0 - 0.06, 0, F - 0.15), (x1 + 0.06, h, BK + 0.06), sw)


def _band(b, x0, x1, y, sw, h=0.3, out=0.15):
    b.span((x0 - out, y, F - out), (x1 + out, y + h, BK + 0.03), sw)


def _cornice(b, x0, x1, y, sw, h=0.55, out=0.45):
    b.span((x0 - 0.3, y, F - out), (x1 + 0.3, y + h, BK + 0.1), sw)


def _parapet(b, x0, x1, y, h, sw, cap):
    """A low wall round a flat roof, with a coping cap."""
    b.span((x0, y, F), (x1, y + h, F + 0.5), sw)
    b.span((x0, y, BK - 0.5), (x1, y + h, BK), sw)
    for xa, xb in ((x0, x0 + 0.5), (x1 - 0.5, x1)):
        b.span((xa, y, F + 0.5), (xb, y + h, BK - 0.5), sw)
    b.span((x0 - 0.15, y + h, F - 0.15), (x1 + 0.15, y + h + 0.3, F + 0.6), cap)
    b.span((x0 - 0.15, y + h, BK - 0.6), (x1 + 0.15, y + h + 0.3, BK + 0.15), cap)
    for xa, xb in ((x0 - 0.15, x0 + 0.6), (x1 - 0.6, x1 + 0.15)):
        b.span((xa, y + h, F + 0.6), (xb, y + h + 0.3, BK - 0.6), cap)


def _shed_roof(b, x0, x1, y, rise, sw, eave=0.6, rows=0, row_sw=None):
    """A roof slope over the whole depth, from its eave in front of the facade at y up to the back at y + rise, with
    `rows` tile courses across it."""
    z0 = F - eave
    run = BK - z0
    b.wedge(((x0 + x1) / 2, y + rise / 2, (z0 + BK) / 2), (x1 - x0 + 0.6, rise, run), sw)
    for k in range(1, rows + 1):
        t = k / (rows + 1)
        b.span((x0 - 0.27, y + rise * t - 0.06, z0 + run * t - 0.12), (x1 + 0.27, y + rise * t + 0.06, z0 + run * t),
               row_sw or sw)
    return lambda z: y + rise * (z - z0) / run         # the slope's height at depth z


def _gable(b, x0, x1, y, rise, wall, roof, eave=0.6, thick=0.45):
    """A gable end toward the lane: the triangle of wall the full depth, and two roof boards from its sloped edges
    over the depth with an eave all round."""
    cx, hw = (x0 + x1) / 2, (x1 - x0) / 2
    # the triangle stands 0.01 proud of the facade and dips 0.02 into the body: none of its faces shares a plane
    b.fan_z((F - 0.01 + BK) / 2, (cx, y + rise), [(x0, y - 0.02), (x1, y - 0.02)], BK - F + 0.01, wall)
    ln = math.hypot(hw, rise)
    a = math.degrees(math.atan2(rise, hw))
    for s in (-1, 1):
        nx, ny = s * rise / ln, hw / ln                                                   # outward normal
        lx, ly = s * hw / ln, -rise / ln                                                  # toward the low end
        if abs(cx + s * hw) > HW - 0.01:     # a gable on the building's edge keeps its eave within the 30.6
            e = max(0.0, (0.3 - thick * rise / ln) / (hw / ln))
        else:
            e = eave
        c = (cx + s * hw / 2 + nx * thick / 2 + lx * e / 2, y + rise / 2 + ny * thick / 2 + ly * e / 2,
             (F - eave + BACK) / 2)
        b.box(c, (ln + e, thick, BACK - (F - eave)), roof, rot=rot_z(-s * a))
    b.span((cx - 0.35, y + rise - 0.1, F - eave), (cx + 0.35, y + rise + thick + 0.2, BACK), roof)  # ridge cap


def _win(b, panes, x, y0, y1, w=2.8, frame="offwhite", sill="concrete", lit=False, curtain=None, shutters=None,
         flowers=None, arch=False, grid=1, glass="fur_blue"):
    """A window on the facade: sill, frame, glass (lit glass on `panes`), glazing bars, and optional curtains,
    shutters, a window box with flowers or an arched top."""
    x0, x1 = x - w / 2, x + w / 2
    b.span((x0 - 0.3, y0 - 0.3, F - 0.4), (x1 + 0.3, y0, F), sill)
    for xa, xb in ((x0 - 0.2, x0), (x1, x1 + 0.2)):
        b.span((xa, y0, F - 0.2), (xb, y1, F), frame)
    (panes if lit else b).span((x0, y0, F - 0.06), (x1, y1, F - 0.02), "glass" if lit else glass)
    for k in range(1, grid + 1):
        xm = x0 + w * k / (grid + 1)
        b.span((xm - 0.07, y0, F - 0.12), (xm + 0.07, y1, F - 0.06), frame)
    ym = (y0 + y1) / 2
    b.span((x0, ym - 0.07, F - 0.12), (x1, ym + 0.07, F - 0.06), frame)
    if arch:
        r = w / 2
        # the fans start 0.02 down inside the window, the frame's back sunk in the wall and the glass clear of
        # its front, so no fan face shares a plane with the boxes
        ya = y1 - 0.02
        b.fan_z(F - 0.09, (x, ya), arc(x, ya, r + 0.2, 0, 180, 4), 0.22, frame)
        (panes if lit else b).fan_z(F - 0.23, (x, ya), arc(x, ya, r - 0.08, 0, 180, 4), 0.04,
                                    "glass" if lit else glass)
    else:
        b.span((x0 - 0.2, y1, F - 0.2), (x1 + 0.2, y1 + 0.35, F), frame)
    if curtain:
        for xa, xb in ((x0, x0 + w * 0.28), (x1 - w * 0.28, x1)):
            b.span((xa, ym + 0.1, F - 0.09), (xb, y1, F - 0.06), curtain)
    if shutters:
        for xa, xb in ((x0 - 1.25, x0 - 0.22), (x1 + 0.22, x1 + 1.25)):
            b.span((xa, y0, F - 0.15), (xb, y1, F), shutters)
            for k in range(1, 4):
                yy = y0 + (y1 - y0) * k / 4
                b.span((xa + 0.12, yy - 0.05, F - 0.2), (xb - 0.12, yy + 0.05, F - 0.15), "offwhite")
    if flowers is not None:
        b.span((x0 - 0.2, y0 - 1.0, F - 0.95), (x1 + 0.2, y0 - 0.3, F), "terracotta")
        flowers.span((x0 - 0.1, y0 - 0.3, F - 0.85), (x1 + 0.1, y0 - 0.15, F - 0.1), "leaf_green")
        for k in range(4):
            flower_clump(flowers, x0 + w * (k + 0.5) / 4, y0 - 0.15, F - 0.5, n=2, spread=0.22)


def _door(b, lamps, x, w=3.2, h=6.6, leaf="dark_wood", frame="offwhite", step="concrete", window=None,
          canopy=None, lamp=True, y0=0.9, arch=False):
    """A back door on the plinth: frame, leaf, handle, a step, and a canopy and a wall lamp if asked."""
    x0, x1 = x - w / 2, x + w / 2
    for xa, xb in ((x0 - 0.35, x0), (x1, x1 + 0.35)):
        b.span((xa, y0, F - 0.3), (xb, h, F), frame)
    b.span((x0, y0, F - 0.12), (x1, h, F), leaf)
    if arch:
        b.fan_z(F - 0.14, (x, h - 0.02), arc(x, h - 0.02, w / 2 + 0.35, 0, 180, 4), 0.32, frame)   # as _win's
        b.fan_z(F - 0.04, (x, h - 0.04), arc(x, h - 0.04, w / 2 - 0.05, 0, 180, 5), 0.16, leaf)   # 5: seams apart
    else:
        b.span((x0 - 0.35, h, F - 0.3), (x1 + 0.35, h + 0.4, F), frame)
    if window:
        b.span((x - w * 0.25, h - 2.2, F - 0.16), (x + w * 0.25, h - 0.7, F - 0.12), window)
    b.span((x1 - 0.7, h * 0.48, F - 0.3), (x1 - 0.4, h * 0.48 + 0.3, F - 0.12), "brass")
    b.span((x0 - 0.9, 0, F - 1.5), (x1 + 0.9, 0.45, F - 0.15), step)
    b.span((x0 - 0.5, 0.45, F - 0.8), (x1 + 0.5, y0, F - 0.15), step)
    top = h + (w / 2 + 0.35 if arch else 0.4)
    if canopy:
        b.span((x0 - 0.9, top + 0.3, F - 1.8), (x1 + 0.9, top + 0.6, F), canopy)
        b.span((x0 - 0.95, top + 0.15, F - 1.85), (x1 + 0.95, top + 0.3, F - 1.65), "offwhite")
        for xx in (x0 - 0.6, x1 + 0.6):
            bar(b, (xx, top - 1.0), (xx, top + 0.3), 0.12, F - 1.3, F - 1.18, "fur_black")
    if lamp:
        lx, ly = x1 + 1.2, top - 0.6
        b.span((lx - 0.1, ly, F - 0.6), (lx + 0.1, ly + 0.2, F), "fur_black")
        lamps.span((lx - 0.3, ly - 0.75, F - 0.85), (lx + 0.3, ly, F - 0.35), "lamp_warm")
        b.b.pyramid(RB.p(lx, ly + 0.2, F - 0.6), 0.85, 0.4, "fur_black")


def _hang_sign(b, x, y, board, edge, pic):
    """A sign hung on an iron arm out from the wall at height y, its board across the lane's length (faces +-X) with
    a picture on both faces: pic(b, side, x_face, cy, cz) draws one face."""
    b.span((x - 0.08, y, F - 3.0), (x + 0.08, y + 0.18, F), "fur_black")                # arm
    bar(b, (x, y - 1.2), (x, y), 0.1, F - 0.15, F - 0.02, "fur_black")                     # stay down the wall
    b.box((x, y - 0.6, F - 0.9), (0.1, 0.1, 1.7), "fur_black", rot=None)                 # brace
    z0, z1, yb0, yb1 = F - 2.8, F - 0.6, y - 2.5, y - 0.3
    for zz in (z0 + 0.25, z1 - 0.25):
        b.span((x - 0.04, yb1, zz - 0.04), (x + 0.04, y, zz + 0.04), "fur_black")       # chains
    b.span((x - 0.1, yb0, z0), (x + 0.1, yb1, z1), board)
    for ya, yb, za, zb in ((yb0 - 0.08, yb0 + 0.12, z0 - 0.08, z1 + 0.08),
                           (yb1 - 0.12, yb1 + 0.08, z0 - 0.08, z1 + 0.08),
                           (yb0 + 0.12, yb1 - 0.12, z0 - 0.08, z0 + 0.12),
                           (yb0 + 0.12, yb1 - 0.12, z1 - 0.12, z1 + 0.08)):
        b.span((x - 0.14, ya, za), (x + 0.14, yb, zb), edge)
    for s in (-1, 1):
        pic(b, s, x + s * 0.1, (yb0 + yb1) / 2, (z0 + z1) / 2)


def _flat(b, s, xf, c, sw, t=0.04):
    """A flat picture piece on a sign face at x xf (side s): c = (y0, y1, z0, z1)."""
    y0, y1, z0, z1 = c
    xa, xb = sorted((xf, xf + s * t))
    b.span((xa, y0, z0), (xb, y1, z1), sw)


def _pic_bread(b, s, xf, cy, cz):
    _flat(b, s, xf, (cy - 0.45, cy + 0.2, cz - 0.75, cz + 0.75), "caramel_wood")
    _flat(b, s, xf, (cy + 0.2, cy + 0.5, cz - 0.55, cz + 0.55), "caramel_wood")
    for dz in (-0.35, 0.0, 0.35):
        _flat(b, s, xf + s * 0.04, (cy + 0.05, cy + 0.38, cz + dz - 0.06, cz + dz + 0.06), "treat_tan", 0.02)


def _pic_apple(b, s, xf, cy, cz):
    _flat(b, s, xf, (cy - 0.55, cy + 0.35, cz - 0.5, cz + 0.5), "bowl_red")
    _flat(b, s, xf, (cy - 0.4, cy + 0.2, cz - 0.62, cz + 0.62), "bowl_red", 0.03)
    _flat(b, s, xf, (cy + 0.35, cy + 0.7, cz - 0.05, cz + 0.05), "dark_wood")
    _flat(b, s, xf, (cy + 0.42, cy + 0.6, cz + 0.08, cz + 0.42), "leaf_green")
    _flat(b, s, xf + s * 0.04, (cy + 0.0, cy + 0.18, cz - 0.32, cz - 0.16), "offwhite", 0.02)


def _pic_note(b, s, xf, cy, cz):
    _flat(b, s, xf, (cy - 0.7, cy - 0.25, cz - 0.55, cz - 0.05), "fur_black")
    _flat(b, s, xf, (cy - 0.45, cy + 0.75, cz - 0.17, cz - 0.05), "fur_black", 0.03)
    _flat(b, s, xf, (cy + 0.45, cy + 0.75, cz - 0.17, cz + 0.45), "fur_black", 0.03)
    _flat(b, s, xf, (cy + 0.15, cy + 0.45, cz + 0.3, cz + 0.45), "fur_black", 0.03)


def _back_windows(b, xs, ys, w=2.4, h=2.8):
    """Plain windows on the back face, toward the area behind the wall."""
    for y in ys:
        for x in xs:
            b.span((x - w / 2 - 0.2, y - 0.25, BK), (x + w / 2 + 0.2, y, BK + 0.25), "concrete")
            b.span((x - w / 2, y, BK), (x + w / 2, y + h, BK + 0.05), "fur_blue")


def _chimney(b, x, z, y0, y1, sw="brick", cap="concrete", w=1.6):
    b.span((x - w / 2, y0, z - w / 2), (x + w / 2, y1, z + w / 2), sw)
    b.span((x - w / 2 - 0.2, y1, z - w / 2 - 0.2), (x + w / 2 + 0.2, y1 + 0.4, z + w / 2 + 0.2), cap)
    for dx in (-0.35, 0.35):
        b.cyl((x + dx, y1 + 0.75, z), 0.22, 0.7, "terracotta", segments=8)


def _dormer(b, panes, x, z, y_slope, top, wall, roof, w=3.4, lit=False):
    """A dormer standing out of a roof slope: its face at depth z, from below the slope (y_slope there) to `top`."""
    b.span((x - w / 2, y_slope - 0.6, z), (x + w / 2, top, BK - 0.3), wall)
    b.span((x - w / 2 - 0.3, top, z - 0.35), (x + w / 2 + 0.3, top + 0.35, BK - 0.3), roof)
    gy0, gy1 = y_slope + 0.4, top - 0.45
    b.span((x - w / 2 + 0.3, gy0, z - 0.06), (x + w / 2 - 0.3, gy0 + 0.2, z), "offwhite")
    b.span((x - w / 2 + 0.3, gy1 - 0.2, z - 0.06), (x + w / 2 - 0.3, gy1, z), "offwhite")
    (panes if lit else b).span((x - w / 2 + 0.45, gy0 + 0.2, z - 0.04), (x + w / 2 - 0.45, gy1 - 0.2, z - 0.01),
                               "glass" if lit else "fur_blue")
    b.span((x - 0.06, gy0 + 0.2, z - 0.08), (x + 0.06, gy1 - 0.2, z - 0.04), "offwhite")


def _siding(b, x0, x1, y0, y1, sw, step=1.0):
    y = y0
    while y < y1:
        b.span((x0, y, F - 0.04), (x1, y + 0.1, F), sw)
        y += step


def _quoins(b, x0, x1, y0, y1, sw):
    for xs in (x0, x1):
        y, k = y0, 0
        while y + 0.7 <= y1:
            wq = 1.2 if k % 2 == 0 else 0.8
            xa, xb = sorted((xs, xs + (wq if xs == x0 else -wq)))
            b.span((xa, y, F - 0.08), (xb, y + 0.7, F), sw)
            y += 1.4
            k += 1


def _parts(name, mat, b, panes, lamps=None, flowers=None):
    out = [b.finalize(name, mat), panes.finalize(name + "_Pane", mat)]
    if lamps is not None:
        out.append(lamps.finalize(name + "_Lamp_Bulb", mat))
    if flowers is not None:
        out.append(flowers.finalize(name + "_Flowers", mat))
    for ob in out:                           # the pivot onto the back plane
        ob.matrix_world = Matrix.Translation(RB.p(0, 0, -BACK))
        bake_transform(ob)
    return out


# ------------------------------------------------------------------------------------------ the buildings --
def build_bakery(mat):
    """Butter stucco, two floors, a terracotta roof with two dormers and a chimney, a blush canopy over the door and
    a bread loaf sign."""
    name = N + "Bakery"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 15.0
    _plinth(b, -HW, HW)
    _body(b, -HW, HW, h, "pastel_butter")
    _band(b, -HW, HW, 7.4, "offwhite")
    _cornice(b, -HW, HW, h, "offwhite")
    slope = _shed_roof(b, -HW, HW, h + 0.55, 5.0, "terracotta", rows=4, row_sw="nose_brick")
    for x in (-7.5, 7.5):
        _dormer(b, panes, x, -0.5, slope(-0.5), h + 4.6, "pastel_butter", "terracotta", lit=x < 0)
    _chimney(b, 11.5, 1.0, h + 1.0, h + 8.2)
    _door(b, lamps, -6.0, leaf="caramel_wood", window="pastel_butter", canopy="blush")
    _hang_sign(b, -11.0, 7.0, "offwhite", "caramel_wood", _pic_bread)
    _win(b, panes, 3.0, 2.4, 5.8, w=3.4, lit=True, curtain="offwhite")
    _win(b, panes, 10.0, 2.4, 5.8, w=3.4)
    for x, sh, fl in ((-11.0, "mint", True), (-4.0, None, False), (3.0, "mint", True), (10.0, None, False)):
        _win(b, panes, x, 9.4, 12.8, lit=x == 3.0, curtain="blush" if x == 3.0 else None, shutters=sh,
             flowers=flowers if fl else None)
    b.cyl((13.6, 6.0, F - 0.1), 0.55, 0.2, "metal", axis="Z", segments=10)               # oven vent
    b.span((13.5, 6.6, F - 0.25), (13.7, 8.0, F - 0.05), "metal")
    _drainpipe(b, -14.2, h)
    _back_windows(b, (-9.0, 0.0, 9.0), (3.0, 10.0))
    return _parts(name, mat, b, panes, lamps, flowers)


def build_townhouses(mat):
    """Sky blue clapboard, three floors, two balconies with plants, a slate mansard with three dormers, chimneys at
    both ends."""
    name = N + "Townhouses"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 21.0
    _plinth(b, -HW, HW, "concrete_dark")
    _body(b, -HW, HW, h, "pastel_sky")
    _siding(b, -HW, HW, 1.4, h - 0.4, "offwhite", 1.1)
    for x in (-HW, HW):                                                                    # corner boards
        xa, xb = sorted((x, x - 0.5 if x > 0 else x + 0.5))
        b.span((xa, 0.9, F - 0.12), (xb, h, F), "offwhite")
    _cornice(b, -HW, HW, h, "offwhite")
    slope = _shed_roof(b, -HW, HW, h + 0.55, 5.5, "concrete_dark", eave=0.8, rows=3, row_sw="night_sky")
    for x in (-9.0, 0.0, 9.0):
        _dormer(b, panes, x, -0.4, slope(-0.4), h + 5.0, "offwhite", "concrete_dark", w=3.0, lit=x == 9.0)
    for x in (-13.6, 13.6):
        _chimney(b, x, 1.0, h + 1.5, h + 8.0)
    _door(b, lamps, 0.0, leaf="sign_teal", window="glass", canopy="concrete_dark")
    for x in (-11.0, -5.5, 5.5, 11.0):
        _win(b, panes, x, 2.4, 5.8, w=2.6, lit=x == -5.5, curtain="pastel_butter" if x == -5.5 else None)
    for x0, x1 in ((-13.0, -3.5), (3.5, 13.0)):                                           # balconies on floor 2
        b.span((x0, 8.0, F - 2.2), (x1, 8.35, F), "offwhite")
        for k in range(int((x1 - x0) / 1.6) + 1):
            px = x0 + 0.1 + (x1 - x0 - 0.2) * k / int((x1 - x0) / 1.6)
            b.span((px - 0.06, 8.35, F - 2.15), (px + 0.06, 9.75, F - 2.03), "offwhite")
        b.span((x0, 9.75, F - 2.2), (x1, 9.95, F - 1.98), "offwhite")
        for xs in (x0, x1):
            b.span((xs - 0.1 if xs == x0 else xs - 0.12, 9.75, F - 2.2),
                   (xs + 0.12 if xs == x0 else xs + 0.1, 9.95, F), "offwhite")
        for xx in (x0 + 0.9, x1 - 0.9):
            b.cyl((xx, 8.75, F - 1.2), 0.4, 0.8, "terracotta", r2=0.5, segments=8)
            flowers.ball((xx, 9.55, F - 1.2), 0.55, "leaf_green")
    for x in (-11.0, -5.5, 5.5, 11.0):
        _win(b, panes, x, 8.6, 12.4, w=2.4, lit=x == 11.0, curtain="blush" if x == 11.0 else None)
    for x in (-11.0, -5.5, 0.0, 5.5, 11.0):
        _win(b, panes, x, 15.0, 18.4, w=2.4, shutters="offwhite" if x in (-11.0, 11.0) else None,
             lit=x == 0.0, curtain="pastel_lilac" if x == 0.0 else None)
    _drainpipe(b, 14.2, h)
    _back_windows(b, (-9.0, 0.0, 9.0), (3.0, 10.0, 16.0))
    return _parts(name, mat, b, panes, lamps, flowers)


def _pic_fish(b, x0, x1, y0, y1):
    """A big faded fish painted on the wall between x0 and x1 (head toward +X)."""
    cy, w, hh = (y0 + y1) / 2, x1 - x0, (y1 - y0) / 2
    z0, z1 = F - 0.04, F
    for k, (fx0, fx1, f) in enumerate(((0.12, 0.78, 1.0), (0.2, 0.7, 1.25), (0.3, 0.6, 1.45))):
        b.span((x0 + w * fx0, cy - hh * 0.55 * f, z0 + k * -0.01), (x0 + w * fx1, cy + hh * 0.55 * f, z1), "fish_blue")
    b.span((x0 + w * 0.3, cy - hh * 0.75, F - 0.07), (x0 + w * 0.62, cy - hh * 0.2, F - 0.03), "fish_belly")
    b.span((x0 + w * 0.78, cy - hh * 0.35, z0), (x0 + w * 0.9, cy + hh * 0.35, z1), "fish_blue")
    b.span((x0 + w * 0.82, cy + 0.05, F - 0.08), (x0 + w * 0.86, cy + hh * 0.25, F - 0.03), "fur_black")   # eye
    for s in (-1, 1):                                                                       # tail
        b.box((x0 + w * 0.08, cy + s * hh * 0.4, F - 0.02), (w * 0.2, hh * 0.35, 0.04), "fish_blue",
              rot=rot_z(s * 35))


def build_warehouse(mat):
    """Brick, three tall floors with grid windows, the walkable fire escape, a steel loading door, a painted fish
    and a water tower on the flat roof."""
    name = N + "Warehouse"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 24.0
    _plinth(b, -HW, HW, "concrete_dark", 1.2)
    _body(b, -HW, HW, h, "brick")
    _band(b, -HW, HW, 8.6, "concrete", 0.35)
    _band(b, -HW, HW, 16.6, "concrete", 0.35)
    _parapet(b, -HW, HW, h, 2.0, "brick", "concrete")
    _quoins(b, -HW, HW, 1.2, h, "concrete")
    fire_escape_kit(b)
    _win(b, panes, -2.0, 2.6, 6.2, w=3.6, frame="concrete_dark", grid=2)     # the crate stack stands at x -12
    _win(b, panes, -3.5, 10.0, 13.6, w=3.2, frame="concrete_dark", grid=2, lit=True, curtain="pastel_lilac")
    _win(b, panes, 3.5, 10.0, 13.6, w=3.2, frame="concrete_dark", grid=2)
    _win(b, panes, -11.8, 10.0, 13.6, w=3.6, frame="concrete_dark", grid=2, shutters="dumpster_green",
         flowers=flowers)
    _win(b, panes, 11.5, 10.0, 13.6, w=3.6, frame="concrete_dark", grid=2)
    _win(b, panes, -11.8, 18.0, 21.6, w=3.6, frame="concrete_dark", grid=2, lit=True, curtain="pastel_butter")
    _win(b, panes, -3.0, 18.0, 21.6, w=3.2, frame="concrete_dark", grid=2)
    _pic_fish(b, 8.7, 14.6, 18.0, 22.8)                    # right of landing 2, which ends at x 8
    # steel loading door right of the ladder
    x0, x1, dt = 9.0, 14.0, 7.4
    for xa, xb in ((x0 - 0.4, x0), (x1, x1 + 0.4)):
        b.span((xa, 1.2, F - 0.3), (xb, dt, F), "concrete")
    b.span((x0 - 0.4, dt, F - 0.3), (x1 + 0.4, dt + 0.5, F), "concrete")
    b.span((x0, 1.2, F - 0.1), (x1, dt, F), "metal")
    y = 1.6
    while y < dt - 0.2:
        b.span((x0, y, F - 0.14), (x1, y + 0.08, F - 0.1), "concrete_dark")
        y += 0.5
    b.span((x0 - 0.6, 0, F - 2.4), (x1 + 0.6, 1.2, F - 0.15), "concrete")                   # loading step
    lx, ly = (x0 + x1) / 2, dt + 1.0
    b.span((lx - 0.1, ly, F - 0.7), (lx + 0.1, ly + 0.2, F), "fur_black")
    lamps.span((lx - 0.35, ly - 0.7, F - 1.0), (lx + 0.35, ly, F - 0.4), "lamp_warm")
    b.b.pyramid(RB.p(lx, ly + 0.2, F - 0.7), 1.0, 0.45, "fur_black")
    _drainpipe(b, -14.4, h)
    # water tower on the roof
    tx, tz, ty = 8.5, 0.35, h + 0.3
    for dx in (-1.2, 1.2):
        for dz in (-0.9, 0.9):
            b.span((tx + dx - 0.15, ty, tz + dz - 0.15), (tx + dx + 0.15, ty + 4.0, tz + dz + 0.15), "concrete_dark")
    b.span((tx - 1.7, ty + 4.0, tz - 1.3), (tx + 1.7, ty + 4.3, tz + 1.3), "dark_wood")
    b.cyl((tx, ty + 6.2, tz), 1.7, 3.8, "dark_wood", segments=12)
    for yy in (ty + 5.0, ty + 7.4):
        b.cyl((tx, yy, tz), 1.76, 0.18, "metal", segments=12)
    b.cyl((tx, ty + 8.7, tz), 1.9, 1.2, "concrete_dark", r2=0.25, segments=12)
    _back_windows(b, (-9.0, 0.0, 9.0), (3.0, 10.5, 18.5), w=3.0)
    return _parts(name, mat, b, panes, lamps, flowers)


def _awning(b, x0, x1, y, out, drop, a="mint", c="offwhite"):
    """A striped awning from the wall at height y, sloping down to `drop` lower `out` from the wall."""
    n = max(2, int(round((x1 - x0) / 1.0)))
    ln = math.hypot(out, drop)
    ang = math.degrees(math.atan2(drop, out))
    for k in range(n):
        xa, xb = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
        b.box(((xa + xb) / 2, y - drop / 2, F - out / 2), (xb - xa, 0.12, ln), a if k % 2 == 0 else c,
              rot=rot_x(-ang))
    for k in range(n):                                                                     # valance
        xa, xb = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
        b.span((xa, y - drop - 0.6, F - out - 0.08), (xb, y - drop, F - out + 0.02), a if k % 2 == 0 else c)
    for xx in (x0 + 0.3, x1 - 0.3):
        bar(b, (xx, y - drop - 0.2), (xx, y), 0.1, F - 0.12, F - 0.02, "fur_black")


def build_grocer(mat):
    """Mint painted boards, two floors, a striped awning over the door, an apple sign and a rooftop garden with a
    little glasshouse behind the parapet."""
    name = N + "Grocer"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 14.0
    _plinth(b, -HW, HW)
    _body(b, -HW, HW, h, "mint")
    for x in range(-13, 15, 2):                                                             # board joints
        b.span((x - 0.05, 0.9, F - 0.04), (x + 0.05, h, F), "leaf_dark")
    _band(b, -HW, HW, 7.0, "offwhite", 0.4)
    _parapet(b, -HW, HW, h, 1.2, "mint", "offwhite")
    _door(b, lamps, 7.0, leaf="offwhite", frame="leaf_dark", window="glass", lamp=False)
    _awning(b, 3.6, 10.4, 8.6, 2.6, 1.1)
    _hang_sign(b, 12.6, 6.6, "offwhite", "leaf_dark", _pic_apple)
    _win(b, panes, -8.5, 2.2, 5.8, w=6.0, frame="leaf_dark", grid=2, lit=True, curtain="pastel_butter")
    _win(b, panes, 0.0, 2.6, 5.8, w=2.6, frame="leaf_dark")
    for x in (-11.0, -4.0, 3.5, 10.5):
        _win(b, panes, x, 9.2, 12.4, w=2.6, frame="offwhite", flowers=flowers, lit=x == -4.0, curtain="blush")
    # rooftop garden: planters along the front, a glasshouse on the left
    for x0, x1 in ((-2.0, 4.0), (6.0, 13.6)):
        b.span((x0, h, F + 0.6), (x1, h + 0.9, F + 1.5), "dark_wood")
        flowers.span((x0 + 0.1, h + 0.9, F + 0.7), (x1 - 0.1, h + 1.05, F + 1.4), "leaf_green")
        for k in range(int(x1 - x0)):
            flowers.ball((x0 + 0.5 + k, h + 1.4, F + 1.05), 0.42 + 0.06 * (k % 3), "leaf_dark" if k % 2 else
                         "leaf_green")
        flower_clump(flowers, x0 + 1.4, h + 1.05, F + 1.05, n=3, spread=0.3)
        flower_clump(flowers, x1 - 1.6, h + 1.05, F + 1.05, colours=("bowl_red", "sparkle", "blush"), n=3,
                     spread=0.3)
    gx0, gx1, gz0, gz1, gy = -13.2, -5.0, F + 0.6, BK - 0.5, h
    panes.span((gx0, gy, gz0), (gx1, gy + 2.8, gz1), "glass")
    for xx in (gx0, (gx0 + gx1) / 2, gx1):
        b.span((xx - 0.1, gy, gz0 - 0.1), (xx + 0.1, gy + 2.8, gz1 + 0.1), "offwhite")
    b.span((gx0 - 0.1, gy + 2.8, gz0 - 0.1), (gx1 + 0.1, gy + 3.0, gz1 + 0.1), "offwhite")
    b.wedge(((gx0 + gx1) / 2, gy + 3.6, (gz0 + gz1) / 2), (gx1 - gx0 + 0.2, 1.2, gz1 - gz0 + 0.2), "glass")
    _back_windows(b, (-9.0, 0.0, 9.0), (3.0, 9.6))
    return _parts(name, mat, b, panes, lamps, flowers)


def build_apartments(mat):
    """Cream stucco, four floors, blush shutters, a laundry line on a little balcony, air conditioners and
    drainpipes, a stair hut and an aerial on the roof."""
    name = N + "Apartments"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 26.5
    _plinth(b, -HW, HW, "concrete_dark", 1.1)
    _body(b, -HW, HW, h, "cream")
    for y in (7.3, 13.8, 20.3):
        _band(b, -HW, HW, y, "pastel_butter", 0.3, 0.1)
    _cornice(b, -HW, HW, h, "terracotta", 0.6, 0.5)
    _parapet(b, -HW, HW, h + 0.6, 1.0, "cream", "terracotta")
    _door(b, lamps, 0.0, leaf="bowl_red", window="glass", canopy="terracotta", y0=1.1)
    for fl, y in enumerate((2.4, 8.9, 15.4, 21.9)):
        for x in (-11.5, -5.0, 5.0, 11.5):
            if fl == 0 and abs(x) == 5.0:
                continue
            lit = (fl, x) in ((0, -11.5), (1, 5.0), (2, -5.0), (3, 11.5))
            _win(b, panes, x, y, y + 3.3, w=2.5, shutters="blush" if fl % 2 else None, lit=lit,
                 curtain=("pastel_lilac", "pastel_butter", "mint", "blush")[fl] if lit else None)
    # a little balcony with a laundry line on floor 3
    bx0, bx1 = 2.2, 8.0
    b.span((bx0, 14.5, F - 1.8), (bx1, 14.8, F), "concrete")
    for xx in (bx0 + 0.1, bx1 - 0.1):
        b.span((xx - 0.08, 14.8, F - 1.75), (xx + 0.08, 16.0, F - 1.6), "fur_black")
    b.span((bx0, 16.0, F - 1.8), (bx1, 16.15, F - 1.6), "fur_black")
    for xx in (bx0 - 0.3, bx1 + 0.3):
        b.span((xx - 0.06, 14.8, F - 1.2), (xx + 0.06, 18.6, F - 1.08), "metal")
    b.span((bx0 - 0.3, 18.5, F - 1.18), (bx1 + 0.3, 18.56, F - 1.1), "offwhite")
    for k, (sw, w, d) in enumerate((("blush", 0.9, 1.1), ("pastel_sky", 0.7, 0.8), ("offwhite", 1.0, 1.3),
                                    ("pastel_butter", 0.6, 0.9), ("mint", 0.8, 1.0))):
        cx = bx0 + 0.6 + k * 1.15
        b.span((cx - w / 2, 18.5 - d, F - 1.19 - 0.01 * k), (cx + w / 2, 18.5, F - 1.12 + 0.005 * k), sw)
    _ac(b, -8.25, 11.0)
    _ac(b, 8.25, 23.6)
    _ac(b, -11.5, 18.3)
    _drainpipe(b, -14.3, h)
    _drainpipe(b, 14.3, h)
    # roof: a stair hut and an aerial
    ry = h + 0.6
    b.span((-11.0, ry, F + 0.6), (-6.5, ry + 3.0, BK - 0.6), "cream")
    b.span((-11.3, ry + 3.0, F + 0.3), (-6.2, ry + 3.3, BK - 0.3), "terracotta")
    b.span((-9.5, ry, F + 0.55), (-8.0, ry + 2.4, F + 0.6), "dark_wood")
    b.span((10.0, ry, 0.4), (10.2, ry + 5.5, 0.6), "metal")
    for yy, ww in ((ry + 3.6, 2.2), (ry + 4.4, 1.6), (ry + 5.1, 1.0)):
        b.span((10.1 - ww / 2, yy, 0.42), (10.1 + ww / 2, yy + 0.1, 0.58), "metal")
    _back_windows(b, (-9.0, 0.0, 9.0), (3.0, 9.5, 16.0, 22.5))
    return _parts(name, mat, b, panes, lamps, flowers)


def build_clock_house(mat):
    """Grey stone, two tall floors of arched windows, a grand door, a slate mansard and a clock cupola with a cat
    weather vane."""
    name = N + "ClockHouse"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 17.0
    _plinth(b, -HW, HW, "concrete_dark", 1.2)
    _body(b, -HW, HW, h, "concrete")
    _quoins(b, -HW, HW, 1.2, h, "concrete_dark")
    _band(b, -HW, HW, 8.4, "concrete_dark", 0.4)
    _cornice(b, -HW, HW, h, "concrete_dark", 0.6, 0.55)
    _shed_roof(b, -HW, HW, h + 0.6, 3.4, "night_sky", rows=2, row_sw="concrete_dark")
    _door(b, lamps, 0.0, w=4.4, h=6.2, leaf="dark_wood", frame="concrete_dark", step="concrete_dark", arch=True,
          y0=1.2, lamp=False)
    for lx in (-3.6, 3.6):                                                                  # lamps either side
        b.span((lx - 0.1, 6.4, F - 0.6), (lx + 0.1, 6.6, F), "fur_black")
        lamps.span((lx - 0.3, 5.65, F - 0.85), (lx + 0.3, 6.4, F - 0.35), "lamp_warm")
        b.b.pyramid(RB.p(lx, 6.6, F - 0.6), 0.85, 0.4, "fur_black")
    for x in (-10.5, 10.5):
        _win(b, panes, x, 2.4, 5.6, w=3.0, frame="offwhite", sill="concrete_dark", arch=True, lit=x < 0,
             curtain="mint" if x < 0 else None)
    for x in (-10.5, -4.2, 4.2, 10.5):
        _win(b, panes, x, 10.2, 13.6, w=2.6, frame="offwhite", sill="concrete_dark", arch=True, lit=x == 4.2,
             curtain="pastel_butter" if x == 4.2 else None, flowers=flowers if abs(x) == 10.5 else None)
    # the clock cupola
    cy0, cy1 = h + 1.5, h + 8.0
    b.span((-2.6, cy0 - 0.6, -0.3), (2.6, cy1, BK - 0.02), "concrete")                    # sunk in the roof
    b.span((-2.8, cy1, -0.5), (2.8, cy1 + 0.4, BK + 0.2), "concrete_dark")
    b.span((-2.8, cy0, -0.5), (2.8, cy0 + 0.4, BK - 0.04), "concrete_dark")
    ccy = (cy0 + cy1) / 2 + 0.2
    b.cyl((0, ccy, -0.4), 2.0, 0.2, "concrete_dark", axis="Z", segments=16)
    b.cyl((0, ccy, -0.55), 1.75, 0.1, "offwhite", axis="Z", segments=16)
    for k in range(12):                                                                     # hour marks
        a = math.radians(90 - 30 * k)
        ln = 0.35 if k % 3 == 0 else 0.18
        b.box((1.45 * math.cos(a), ccy + 1.45 * math.sin(a), -0.62), (0.1, ln, 0.04), "fur_black",
              rot=rot_z(-30 * k))
    b.box((0.0, ccy + 0.55, -0.66), (0.12, 1.1, 0.04), "fur_black")                        # hands at ten past
    b.box((0.45, ccy + 0.14, -0.7), (0.9, 0.12, 0.04), "fur_black", rot=rot_z(18))
    b.span((-0.12, ccy - 0.12, -0.74), (0.12, ccy + 0.12, -0.62), "brass")
    for zc, turn in ((0.15, None), (1.55, rot_y(180))):                                   # the pitched cap
        b.wedge((0, cy1 + 2.0, zc), (6.0, 3.2, 1.4), "night_sky", rot=turn)
    vy = cy1 + 3.4
    b.span((-0.06, vy, 0.79), (0.06, vy + 2.2, 0.91), "fur_black")                       # weather vane
    b.span((-1.0, vy + 1.0, 0.8), (1.0, vy + 1.08, 0.9), "fur_black")
    b.span((-0.1, vy + 1.3, 0.76), (1.0, vy + 1.75, 0.94), "fur_black")                  # the cat on it
    b.span((0.8, vy + 1.75, 0.76), (1.25, vy + 2.15, 0.94), "fur_black")
    for ex in (0.86, 1.14):
        b.span((ex - 0.06, vy + 2.15, 0.78), (ex + 0.06, vy + 2.35, 0.92), "fur_black")
    b.box((-0.27, vy + 1.85, 0.85), (0.1, 0.7, 0.12), "fur_black", rot=rot_z(25))
    _back_windows(b, (-9.0, 0.0, 9.0), (3.0, 10.5))
    return _parts(name, mat, b, panes, lamps, flowers)


def build_music_shop(mat):
    """Lilac with teal trim, a tall gable toward the lane with a round window, an arched teal door, a music note
    sign and window boxes."""
    name = N + "MusicShop"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    h = 13.0
    _plinth(b, -HW, HW)
    _body(b, -HW, HW, h, "pastel_lilac")
    _band(b, -HW, HW, 6.8, "sign_teal", 0.35)
    _band(b, -HW, HW, h - 0.35, "sign_teal", 0.3)
    _gable(b, -HW, HW, h, 7.5, "pastel_lilac", "galaxy_blue")
    gy = h + 3.0                                                                           # round window
    b.cyl((0, gy, F - 0.1), 1.7, 0.2, "sign_teal", axis="Z", segments=14)
    panes.cyl((0, gy, F - 0.23), 1.35, 0.06, "glass", axis="Z", segments=14)
    b.span((-1.35, gy - 0.07, F - 0.3), (1.35, gy + 0.07, F - 0.26), "sign_teal")
    b.span((-0.07, gy - 1.35, F - 0.3), (0.07, gy + 1.35, F - 0.26), "sign_teal")
    _chimney(b, 9.0, 0.8, h + 2.0, h + 7.4, "brick")
    _door(b, lamps, -8.0, w=3.0, h=5.4, leaf="sign_teal", frame="offwhite", arch=True, window="glass")
    _hang_sign(b, -12.8, 6.4, "offwhite", "sign_teal", _pic_note)
    _win(b, panes, 1.0, 2.2, 5.6, w=5.2, frame="sign_teal", grid=2, lit=True, curtain="pastel_butter")
    _win(b, panes, 9.5, 2.4, 5.6, w=3.0, frame="sign_teal")
    for x, fl in ((-9.5, True), (-3.2, False), (3.2, False), (9.5, True)):
        _win(b, panes, x, 8.4, 11.6, w=2.6, frame="offwhite", flowers=flowers if fl else None,
             shutters="sign_teal" if not fl else None)
    _drainpipe(b, 14.3, h)
    _back_windows(b, (-9.0, 0.0, 9.0), (2.8, 8.6))
    return _parts(name, mat, b, panes, lamps, flowers)


def build_narrow_houses(mat):
    """Two narrow houses side by side: a terracotta one with a stepped gable on the left, a timber-framed one with a
    steep roof on the right."""
    name = N + "NarrowHouses"
    b, panes, lamps, flowers = RB(), RB(), RB(), RB()
    # left: terracotta brick, three floors and a stepped gable
    h1 = 19.0
    _plinth(b, -HW, 0.0, "concrete")
    b.span((-HW, BODY_Y, F), (0.0, h1, BK), "nose_brick")
    for y in (6.9, 12.9):
        _band(b, -HW, -0.05, y, "offwhite", 0.25, 0.1)
    steps = ((-HW, 0.0), (-13.4, -1.6), (-11.8, -3.2), (-10.2, -4.8), (-8.6, -6.4))
    y = h1
    for k, (xa, xb) in enumerate(steps):
        top = y + 1.6
        b.span((xa, y, F), (xb, top, BK), "nose_brick")
        b.span((xa - (0.3 if k == 0 else 0.15), top, F - 0.15), (xb + 0.15, top + 0.3, BK + 0.1), "offwhite")
        y = top + 0.3 if k < len(steps) - 1 else top
    _win(b, panes, -7.5, h1 + 1.4, h1 + 4.0, w=2.0, frame="offwhite", lit=True, curtain="blush")
    _door(b, lamps, -4.2, w=2.8, h=6.0, leaf="dark_wood", window="glass")
    _win(b, panes, -11.5, 2.4, 5.6, w=2.6)
    for y0 in (8.2, 14.2):
        for x in (-11.0, -4.0):
            _win(b, panes, x, y0, y0 + 3.0, w=2.4, shutters="pastel_butter" if y0 > 10 else None,
                 lit=(x, y0) == (-11.0, 8.2), curtain="mint", flowers=flowers if y0 < 10 else None)
    _chimney(b, -1.4, 1.0, h1 - 0.5, h1 + 6.0)
    # right: timber frame over cream, two floors and a steep roof
    h2 = 13.5
    _plinth(b, 0.0, HW, "concrete_dark")
    b.span((0.0, BODY_Y, F), (HW, h2, BK), "cream")
    for x in (0.35, 7.5, HW - 0.35):                                                       # posts
        b.span((x - 0.35, 0.9, F - 0.15), (x + 0.35, h2, F), "dark_wood")
    for y in (0.9, 6.7, h2 - 0.6):                                                         # beams
        b.span((0.0, y, F - 0.17), (HW, y + 0.6, F), "dark_wood")
    for xa, xb in ((0.7, 7.15), (7.85, HW - 0.7)):                                         # braces, upper floor
        for s in (1, -1):
            x0, y0, x1, y1 = (xa, 7.3, xb, h2 - 0.6) if s > 0 else (xa, h2 - 0.6, xb, 7.3)
            if (xa < 7) == (s > 0):
                bar(b, (x0, y0), (x1, y1), 0.35, F - 0.13, F - 0.01, "dark_wood")
    _gable(b, 0.0, HW, h2, 7.0, "cream", "rust")
    for xa, xb, y in ((2.5, 12.5, h2 + 0.25), (5.0, 10.0, h2 + 3.9)):    # gable timbers, clear of its window
        b.span((xa, y, F - 0.15), (xb, y + 0.45, F), "dark_wood")
    _win(b, panes, 7.5, h2 + 1.2, h2 + 3.0, w=2.0, frame="offwhite")
    _win(b, panes, 3.8, 2.4, 5.6, w=2.4, frame="offwhite", lit=True, curtain="pastel_butter")
    _door(b, lamps, 11.2, w=2.8, h=5.6, leaf="bowl_red", window="glass", canopy="rust")
    for x in (3.8, 11.2):
        _win(b, panes, x, 8.4, 11.4, w=2.4, frame="offwhite", flowers=flowers)
    _chimney(b, 12.4, 1.15, h2 + 2.0, h2 + 6.6, "concrete_dark")                         # back off the gable's
    _back_windows(b, (-11.0, -4.0, 4.0, 11.0), (3.0, 9.5))
    return _parts(name, mat, b, panes, lamps, flowers)


BUILDERS = {"Bakery": build_bakery, "Townhouses": build_townhouses, "Warehouse": build_warehouse,
            "Grocer": build_grocer, "Apartments": build_apartments, "ClockHouse": build_clock_house,
            "MusicShop": build_music_shop, "NarrowHouses": build_narrow_houses}
ASSETS = {N + k: (f, 6000 if k == "Warehouse" else 5000) for k, f in BUILDERS.items()}
LEDGES = {N + "Warehouse": {"landing_1": (0.0, 9.35, -2.8 - BACK), "landing_2": (-5.5, 17.35, -2.8 - BACK)}}
