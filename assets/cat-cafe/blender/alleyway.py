"""Alleyway set pieces for layout v2 (docs/design/cat-cafe/world-and-feel.md section 2): arches over the mouths
of the Alley Square, building backs that line the back alleys and the square, a crate stack to climb onto the fire
escape, a laundry line, long string lights and the Sewer manhole. Laid out in Roblox axes through common.RB,
front -Z, sizes in studs.

  CatCafe_Alley_ArchStreet   28 stud opening between 2 stud posts, over the street's north end at (0, 87.5)
  CatCafe_Alley_Arch         26 stud opening between 2 stud posts (30 overall), over each back alley at (+-74, 87.5)
                             Both: pivot at the base centre of the opening, -Z face toward the street or back alley
                             (reads ALLEY SQUARE), +Z face toward the square (reads CAFE STREET or BACK ALLEY).
  CatCafe_Alley_WallWindows  Building backs, 30 wide, 1 thick plus whatever sticks out. Pivot on the back plane
  CatCafe_Alley_WallDoor     (local z 0) at the bottom centre: put it against the inner face of an alley wall with
  CatCafe_Alley_FireEscape   -Z facing into the alley. They are taller than the 10 stud walls, so the alley reads
  CatCafe_Alley_Mural        as a street of buildings. The fire escape's landings are walkable (LEDGES).
  CatCafe_Alley_CrateStack   Three columns of solid crates and a pallet, steps of 2.6: the hop up to the first
                             fire escape landing.
  CatCafe_Alley_LaundryLine  Two poles 24 apart with clothes on two lines at 10 studs.
  CatCafe_Alley_StringLightsLong   Two poles 28 apart, bulbs on a sagging wire, spans a back alley.
  CatCafe_Sewer_Manhole      Cover (its own _Cover model, slide it away to open), barricades and a SignBoard.
"""

import math

from common import RB, text_width
from plot import TRIM, rot_x, rot_y, rot_z

WALL_W = 30.0
# Walkable fire escape landings (top surface centre, Roblox local), for spawn points up there
LEDGES = {"CatCafe_Alley_FireEscape": {"landing_1": (0.0, 9.35, -2.8), "landing_2": (-5.5, 17.35, -2.8)}}


def label(b, s, cx, y, z, px, depth, swatch, facing):
    """Block letters centred on x = cx, bottom at y, standing on a face at depth z. facing -1: read from -Z."""
    w = text_width(s, px)
    if facing < 0:
        b.text(s, (cx + w / 2, y, z), px, depth, swatch, right=(-1, 0, 0))
    else:
        b.text(s, (cx - w / 2, y, z), px, depth, swatch, right=(1, 0, 0))


def bar(b, p0, p1, t, z0, z1, swatch):
    """A straight bar t thick in the XY plane from p0 to p1 (Roblox x, y), between depths z0 and z1."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) + t * 0.5
    b.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (z0 + z1) / 2), (length, t, abs(z1 - z0)), swatch,
          rot=rot_z(math.degrees(math.atan2(dy, dx))))


def lantern(b, lamps, x, y, z, s=1.0):
    """Square post lantern standing on (x, y, z); the glass block goes on `lamps` (a _Bulb object)."""
    b.span((x - 0.55 * s, y, z - 0.55 * s), (x + 0.55 * s, y + 0.2 * s, z + 0.55 * s), "fur_black")
    lamps.span((x - 0.38 * s, y + 0.2 * s, z - 0.38 * s), (x + 0.38 * s, y + 1.2 * s, z + 0.38 * s), "lamp_warm")
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            b.span((x + dx * s - 0.06, y + 0.2 * s, z + dz * s - 0.06),
                   (x + dx * s + 0.06, y + 1.2 * s, z + dz * s + 0.06), "fur_black")
    b.b.pyramid(RB.p(x, y + 1.2 * s, z), 1.3 * s, 0.6 * s, "fur_black")


def flower_clump(f, x, y, z, colours=("blush", "sparkle", "offwhite", "nose_pink"), n=4, spread=0.5):
    for k in range(n):
        a = 2.3 * k
        fx, fz = x + spread * math.cos(a) * (k % 2 + 0.5) / 1.5, z + spread * math.sin(a) * 0.5
        f.span((fx - 0.18, y, fz - 0.18), (fx + 0.18, y + 0.36, fz + 0.18), colours[k % len(colours)])


# ------------------------------------------------------------------------------------------------ arches --
def _arch(name, mat, inner, front, back):
    b, flowers, lamps, bulbs = RB(), RB(), RB(), RB()
    half, post, top = inner / 2, 2.0, 13.0
    for s in (-1, 1):
        x0, x1 = sorted((s * half, s * (half + post)))
        b.span((x0 - 0.3, 0, -1.3), (x1 + 0.3, 1.2, 1.3), "concrete")                     # plinth
        b.span((x0, 1.2, -1.0), (x1, top, 1.0), "brick")
        for y in (4.6, 9.2):                                                               # stone bands
            b.span((x0 - 0.12, y, -1.12), (x1 + 0.12, y + 0.4, 1.12), "concrete")
        b.span((x0 - 0.3, top, -1.3), (x1 + 0.3, top + 0.6, 1.3), "concrete")              # cap
        lantern(b, lamps, s * (half + post / 2), top + 0.6, 0)
        bx = s * (half - 0.7)                                                              # hanging basket
        b.span((min(s * half, bx), 8.4, -0.08), (max(s * half, bx), 8.55, 0.08), "fur_black")
        b.span((bx - 0.04, 7.7, -0.04), (bx + 0.04, 8.4, 0.04), "fur_black")
        b.cyl((bx, 7.35, 0), 0.55, 0.6, "terracotta", r2=0.7, segments=10)
        flowers.span((bx - 0.55, 7.65, -0.55), (bx + 0.55, 7.8, 0.55), "leaf_green")
        flower_clump(flowers, bx, 7.8, 0, n=5, spread=0.5)
        for dz in (-0.45, 0.45):                                                           # trailing ivy
            b.span((bx - 0.15, 6.2, dz - 0.15), (bx + 0.15, 7.1, dz + 0.15), "leaf_dark")
    # iron beam, sign board and the curved top
    b.span((-half, 10.0, -0.35), (half, 10.5, 0.35), "fur_black")
    bw = inner - 3.0
    b.span((-bw / 2, 10.5, -0.25), (bw / 2, 13.3, 0.25), "sign_teal")
    for (xa, xb, ya, yb) in ((-bw / 2 - 0.2, bw / 2 + 0.2, 10.5, 10.75), (-bw / 2 - 0.2, bw / 2 + 0.2, 13.05, 13.3),
                             (-bw / 2 - 0.2, -bw / 2 + 0.05, 10.5, 13.3), (bw / 2 - 0.05, bw / 2 + 0.2, 10.5, 13.3)):
        b.span((xa, ya, -0.32), (xb, yb, 0.32), TRIM)
    px = 0.42
    label(b, front, 0, 10.85, -0.25, px, 0.07, "offwhite", -1)
    label(b, back, 0, 10.85, 0.25, px, 0.07, "offwhite", 1)
    n, rise, y0 = 12, 2.0, 13.3
    pts = [(-half + inner * k / n, y0 + rise * (1 - (2 * k / n - 1) ** 2)) for k in range(n + 1)]
    for p0, p1 in zip(pts, pts[1:]):
        bar(b, p0, p1, 0.3, -0.15, 0.15, "fur_black")
    for p in pts[1:-1]:
        bulbs.span((p[0] - 0.17, p[1] + 0.2, -0.17), (p[0] + 0.17, p[1] + 0.54, 0.17), "lamp_warm")
    for x in (-bw / 4, bw / 4):                                                            # scroll bars
        yt = y0 + rise * (1 - (x / half) ** 2)
        b.span((x - 0.1, y0, -0.1), (x + 0.1, yt, 0.1), "fur_black")
        b.cyl((x, y0 + 0.55, 0), 0.4, 0.2, "fur_black", axis="Z", segments=10)
    # cat medallion at the top: gold disc with ears and a paw on both faces
    b.cyl((0, y0 + rise + 0.55, 0), 1.1, 0.3, "rarity_legend", axis="Z", segments=14)
    for s in (-1, 1):
        b.box((s * 0.65, y0 + rise + 1.45, 0), (0.6, 0.6, 0.3), "rarity_legend", rot=rot_z(45))
        zf = s * 0.17
        for (dx, dy, r) in ((0, -0.15, 0.32), (-0.42, 0.3, 0.14), (0, 0.45, 0.14), (0.42, 0.3, 0.14)):
            b.span((dx - r, y0 + rise + 0.55 + dy - r, min(zf, zf + s * 0.05)),
                   (dx + r, y0 + rise + 0.55 + dy + r, max(zf, zf + s * 0.05)), "blush")
    return [b.finalize(name, mat), flowers.finalize(name + "_Flowers", mat), lamps.finalize(name + "_Lamp_Bulb", mat),
            bulbs.finalize(name + "_Bulbs", mat)]


def build_arch_street(mat):
    return _arch("CatCafe_Alley_ArchStreet", mat, 28.0, "ALLEY SQUARE", "CAFE STREET")


def build_arch(mat):
    return _arch("CatCafe_Alley_Arch", mat, 26.0, "ALLEY SQUARE", "BACK ALLEY")


# -------------------------------------------------------------------------------------- building backs --
ACCENT_BRICKS = ((-11.3, 1.6), (-6.2, 4.4), (-1.4, 2.2), (3.8, 5.6), (8.9, 1.9), (12.1, 7.8), (-12.6, 9.4),
                 (-4.7, 12.6), (6.6, 10.3), (11.0, 14.9), (-8.8, 16.1), (2.1, 18.7), (-2.9, 21.2), (9.4, 20.0))


def _facade(b, h, base="brick"):
    """Wall slab (front face at z -1, back plane at z 0), plinth, cornice and parapet, quoins, accent bricks."""
    hw = WALL_W / 2
    b.span((-hw, 0, -1.0), (hw, h, 0), base)
    b.span((-hw - 0.05, 0, -1.2), (hw + 0.05, 1.0, -1.0), "concrete")
    b.span((-hw - 0.3, h, -1.5), (hw + 0.3, h + 0.6, 0), "concrete")
    b.span((-hw, h + 0.6, -1.0), (hw, h + 1.6, 0), base)
    b.span((-hw - 0.15, h + 1.6, -1.15), (hw + 0.15, h + 1.85, 0), "concrete")
    for s in (-1, 1):
        y, k = 1.0, 0
        while y + 0.7 <= h:
            wq = 1.2 if k % 2 == 0 else 0.8
            x0, x1 = sorted((s * hw, s * (hw - wq)))
            b.span((x0, y, -1.08), (x1, y + 0.7, -1.0), "concrete")
            y += 1.4
            k += 1
    for k, (x, y) in enumerate(ACCENT_BRICKS):
        if y + 0.4 < h:
            b.span((x - 0.45, y, -1.04), (x + 0.45, y + 0.4, -1.0), ("terracotta", "rust")[k % 2])


def _band(b, y):
    hw = WALL_W / 2
    b.span((-hw, y, -1.15), (hw, y + 0.35, -1.0), "concrete")


def _window(b, panes, x, y0, y1, w=3.2, lit=False, curtain=None, shutters=None, flowers=None, bars=False):
    x0, x1, ym = x - w / 2, x + w / 2, (y0 + y1) / 2
    b.span((x0 - 0.3, y0 - 0.35, -1.4), (x1 + 0.3, y0, -1.0), "concrete")                  # sill
    b.span((x0 - 0.2, y1, -1.2), (x1 + 0.2, y1 + 0.45, -1.0), "concrete")                   # lintel
    for xa, xb in ((x0 - 0.2, x0), (x1, x1 + 0.2)):
        b.span((xa, y0, -1.2), (xb, y1, -1.0), "offwhite")
    (panes if lit else b).span((x0, y0, -1.06), (x1, y1, -1.02), "glass" if lit else "fur_blue")
    b.span((x - 0.07, y0, -1.12), (x + 0.07, y1, -1.06), "offwhite")
    b.span((x0, ym - 0.07, -1.12), (x1, ym + 0.07, -1.06), "offwhite")
    if curtain:
        for xa, xb in ((x0, x0 + w * 0.28), (x1 - w * 0.28, x1)):
            b.span((xa, ym + 0.1, -1.09), (xb, y1, -1.06), curtain)
    if shutters:
        for xa, xb in ((x0 - 1.35, x0 - 0.25), (x1 + 0.25, x1 + 1.35)):
            b.span((xa, y0, -1.15), (xb, y1, -1.0), shutters)
            for k in range(1, 4):
                yy = y0 + (y1 - y0) * k / 4
                b.span((xa + 0.12, yy - 0.05, -1.2), (xb - 0.12, yy + 0.05, -1.15), TRIM)
    if flowers is not None:
        b.span((x0 - 0.2, y0 - 1.05, -1.95), (x1 + 0.2, y0 - 0.35, -1.0), "terracotta")
        flowers.span((x0 - 0.1, y0 - 0.35, -1.85), (x1 + 0.1, y0 - 0.2, -1.1), "leaf_green")
        for k in range(5):
            fx = x0 + w * (k + 0.5) / 5
            flower_clump(flowers, fx, y0 - 0.2, -1.5, n=2, spread=0.25)
    if bars:
        for k in range(1, 6):
            bx = x0 + w * k / 6
            b.span((bx - 0.06, y0, -1.32), (bx + 0.06, y1, -1.2), "fur_black")


def _ac(b, x, y):
    b.span((x - 1.3, y, -2.6), (x + 1.3, y + 1.7, -1.0), "offwhite")
    b.cyl((x + 0.4, y + 0.85, -2.65), 0.6, 0.1, "concrete_dark", axis="Z", segments=12)
    for k in range(4):
        yy = y + 0.4 + k * 0.3
        b.span((x - 0.2, yy - 0.03, -2.74), (x + 1.0, yy + 0.03, -2.7), "metal")
    for k in range(4):
        b.span((x - 1.15, y + 0.35 + k * 0.32, -2.66), (x - 0.5, y + 0.45 + k * 0.32, -2.6), "concrete_dark")
    for xx in (x - 1.0, x + 1.0):
        b.span((xx - 0.08, y - 0.7, -2.3), (xx + 0.08, y, -1.0), "metal")
    b.cyl((x + 1.1, y - 0.6, -1.3), 0.06, 1.2, "metal", segments=6)                       # drip pipe


def _drainpipe(b, x, h):
    b.cyl((x, h / 2, -1.3), 0.22, h - 0.6, "metal", segments=8)
    b.span((x - 0.4, h - 0.6, -1.7), (x + 0.4, h, -1.0), "metal")
    b.span((x - 0.28, 0, -2.0), (x + 0.28, 0.45, -1.0), "metal")
    for y in range(3, int(h) - 1, 4):
        b.span((x - 0.3, y, -1.4), (x + 0.3, y + 0.15, -1.0), "concrete_dark")


def build_wall_windows(mat):
    name = "CatCafe_Alley_WallWindows"
    b, panes, flowers = RB(), RB(), RB()
    h = 18.0
    _facade(b, h)
    _band(b, 8.2)
    for x, lit in ((-9, False), (0, True), (9, False)):
        _window(b, panes, x, 2.6, 6.2, lit=lit, curtain="blush" if lit else None)
    for x, lit, sh in ((-9, True, "mint"), (0, False, "blush"), (9, True, "sign_teal")):
        _window(b, panes, x, 10.4, 14.0, lit=lit, curtain="pastel_butter" if lit else None, shutters=sh,
                flowers=flowers if x != 0 else None)
    _ac(b, 0, 8.6)
    _drainpipe(b, -13.6, h)
    for k in range(4):                                                                     # vent grille
        b.span((11.8, 1.4 + k * 0.3, -1.12), (14.0, 1.5 + k * 0.3, -1.0), "concrete_dark")
    return [b.finalize(name, mat), panes.finalize(name + "_Pane", mat), flowers.finalize(name + "_Flowers", mat)]


def build_wall_door(mat):
    name = "CatCafe_Alley_WallDoor"
    b, panes, lamp = RB(), RB(), RB()
    h = 16.0
    _facade(b, h)
    _band(b, 8.6)
    dx = -6.0
    for xa, xb in ((dx - 2.5, dx - 2.0), (dx + 2.0, dx + 2.5)):                           # door frame
        b.span((xa, 0.6, -1.4), (xb, 7.7, -1.0), "concrete")
    b.span((dx - 2.5, 7.2, -1.4), (dx + 2.5, 7.7, -1.0), "concrete")
    b.span((dx - 2.0, 0.6, -1.15), (dx + 2.0, 7.2, -1.0), "dumpster_green")
    b.span((dx - 1.6, 3.4, -1.32), (dx + 1.6, 3.65, -1.15), "metal")                      # push bar
    b.span((dx - 2.0, 0.6, -1.2), (dx + 2.0, 1.4, -1.15), "metal")                        # kick plate
    b.span((dx - 1.2, 5.3, -1.22), (dx + 1.2, 6.2, -1.15), "offwhite")                    # STAFF plate
    label(b, "STAFF", dx, 5.5, -1.22, 0.1, 0.03, "fur_black", -1)
    b.span((dx - 2.8, 0, -3.4), (dx + 2.8, 0.3, -1.0), "concrete")                        # steps
    b.span((dx - 2.5, 0.3, -2.2), (dx + 2.5, 0.6, -1.0), "concrete")
    b.span((dx - 3.0, 8.0, -3.0), (dx + 3.0, 8.35, -1.0), "sign_teal")                    # canopy
    b.span((dx - 3.05, 7.85, -3.05), (dx + 3.05, 8.0, -2.85), TRIM)
    for x in (dx - 2.6, dx + 2.6):
        bar(b, (x, 6.6), (x, 8.0), 0.12, -1.6, -1.45, "metal")
    b.span((dx - 0.1, 8.35, -1.6), (dx + 0.1, 8.55, -1.0), "fur_black")                   # wall lamp
    lamp.span((dx - 0.3, 8.55, -1.85), (dx + 0.3, 9.25, -1.35), "lamp_warm")
    b.b.pyramid(RB.p(dx, 9.25, -1.6), 0.9, 0.4, "fur_black")
    _window(b, panes, 9.0, 2.8, 6.2, bars=True)
    _ac(b, 3.0, 3.6)
    for x, lit, sh in ((-10, False, None), (-2, True, "blush"), (6, False, None)):
        _window(b, panes, x, 9.8, 13.2, lit=lit, curtain="mint" if lit else None, shutters=sh)
    _ac(b, 11.5, 10.6)
    _drainpipe(b, 13.6, h)
    for y in (7.75, 8.25):                                                                 # pipes along the wall
        b.cyl((-12.0, y, -1.25), 0.16, 6.0, "metal", axis="X", segments=8)
    for x in (-14.2, -10.5):
        b.span((x - 0.1, 7.5, -1.45), (x + 0.1, 8.5, -1.0), "concrete_dark")
    return [b.finalize(name, mat), panes.finalize(name + "_Pane", mat), lamp.finalize(name + "_Lamp_Bulb", mat)]


def _landing(b, x0, x1, top, z0=-4.6, z1=-1.0, rail_gap=None, sides=(True, True)):
    b.span((x0, top - 0.35, z0), (x1, top, z1), "fur_black")
    for k in range(1, int((x1 - x0) / 0.8)):                                               # grating lines
        x = x0 + k * 0.8
        b.span((x - 0.03, top, z0 + 0.1), (x + 0.03, top + 0.03, z1 - 0.1), "concrete_dark")
    posts = [x0 + 0.07 + (x1 - x0 - 0.14) * k / max(1, round((x1 - x0) / 3.5)) for k in
             range(round((x1 - x0) / 3.5) + 1)]
    for x in posts:
        b.span((x - 0.07, top, z0), (x + 0.07, top + 3.0, z0 + 0.14), "fur_black")
    spans = [(x0, x1)] if rail_gap is None else [(x0, rail_gap[0]), (rail_gap[1], x1)]
    for a0, a1 in spans:
        for y in (1.5, 2.9):
            b.span((a0, top + y, z0), (a1, top + y + 0.12, z0 + 0.14), "fur_black")
    for x, has_rail in zip((x0, x1), sides):
        if has_rail:
            for y in (1.5, 2.9):
                b.span((min(x, x + 0.14), top + y, z0), (max(x, x + 0.14), top + y + 0.12, z1), "fur_black")
            b.span((x - 0.07, top, z1 - 0.14), (x + 0.07, top + 3.0, z1), "fur_black")


def build_fire_escape(mat):
    name = "CatCafe_Alley_FireEscape"
    b, panes, flowers = RB(), RB(), RB()
    h = 24.0
    _facade(b, h)
    _band(b, 8.6)
    _band(b, 16.6)
    _window(b, panes, -9.0, 2.6, 6.2, lit=True, curtain="pastel_lilac")
    _window(b, panes, 9.0, 2.6, 6.2)
    _window(b, panes, -3.5, 10.0, 13.6, lit=True, curtain="blush")
    _window(b, panes, 3.5, 10.0, 13.6)
    _window(b, panes, 11.5, 10.0, 13.6, shutters="mint", flowers=flowers)
    _window(b, panes, -10.0, 18.0, 21.6, lit=True, curtain="pastel_butter")
    _window(b, panes, -3.0, 18.0, 21.6)
    _window(b, panes, 6.0, 18.0, 21.6, shutters="blush")
    # landing 1 (x -8..8, top 9.35): a gap in the front rail for the ladder, no rail on the left end so players can
    # hop on from the crate stack beside it
    _landing(b, -8.0, 8.0, 9.35, rail_gap=(4.4, 6.6), sides=(False, True))
    brace = math.degrees(math.atan2(9.0 - 6.6, 4.4 - 1.0))
    for x in (-7.6, 7.6):                                                                  # wall braces
        b.box((x, 7.8, -2.7), (0.2, 0.2, math.hypot(2.4, 3.4)), "fur_black", rot=rot_x(brace))
    # ladder down to the ground: rungs a stud apart, climbable
    for x in (4.5, 6.5):
        b.span((x - 0.18, 0, -5.05), (x + 0.18, 12.35, -4.7), "fur_black")
    for k in range(9):
        y = 0.8 + k * 1.0
        b.span((4.5, y, -4.95), (6.5, y + 0.35, -4.6), "metal")
    # stair from landing 1 up to landing 2, against the wall
    x_lo, x_hi, y_lo, y_hi = 6.0, -3.0, 9.35, 17.35
    for z0, z1 in ((-3.0, -2.85), (-1.15, -1.0)):
        bar(b, (x_lo, y_lo - 0.3), (x_hi, y_hi - 0.3), 0.4, z0, z1, "fur_black")
    steps = 10
    for k in range(steps):
        t = (k + 0.5) / steps
        sx, sy = x_lo + (x_hi - x_lo) * t, y_lo + (y_hi - y_lo) * t
        b.span((sx - 0.5, sy - 0.2, -2.85), (sx + 0.5, sy, -1.15), "concrete_dark")
    for k in range(4):                                                                     # stair handrail posts
        t = (k + 0.5) / 4
        sx, sy = x_lo + (x_hi - x_lo) * t, y_lo + (y_hi - y_lo) * t
        b.span((sx - 0.06, sy, -3.0), (sx + 0.06, sy + 2.6, -2.86), "fur_black")
    bar(b, (x_lo, y_lo + 2.6), (x_hi, y_hi + 2.6), 0.12, -3.0, -2.86, "fur_black")
    # landing 2: a block on the left and a front walkway past the stair
    _landing(b, -8.0, -3.0, 17.35, sides=(True, False))
    _landing(b, -3.0, 8.0, 17.35, z1=-3.1, sides=(False, False))
    b.span((7.86, 17.35, -4.6), (8.0, 20.35, -3.1), "fur_black")
    # a potted plant and a sleeping cushion on landing 1, a little watering can
    b.cyl((-6.6, 9.85, -3.6), 0.45, 1.0, "terracotta", r2=0.55, segments=10)
    b.ball((-6.6, 10.85, -3.6), 0.7, "leaf_green")
    b.cyl((-2.5, 9.5, -2.2), 0.8, 0.3, "blush", segments=12)
    b.cyl((-2.5, 9.7, -2.2), 0.5, 0.12, "cream", segments=12)
    b.cyl((-5.2, 9.7, -3.8), 0.3, 0.7, "sign_teal", segments=8)
    return [b.finalize(name, mat), panes.finalize(name + "_Pane", mat), flowers.finalize(name + "_Flowers", mat)]


# The mural: our own cats as 8 x 8 pixel faces. Letters map to colour slots per cat.
FACE = ("F......F",
        "FK....KF",
        "FFFFFFFF",
        "FEEFFEEF",
        "FEPFFPEF",
        "FFFNNFFF",
        "FMMMMMMF",
        ".FFFFFF.")
MURAL_CATS = (
    ("Tabby", {"F": "fur_orange", "K": "nose_pink", "E": "eye_green", "P": "fur_black", "N": "nose_pink",
               "M": "fur_cream", "D": "fur_orange_dark"}, {2: "FDFDDFDF"}),
    ("Tuxedo", {"F": "fur_black", "K": "nose_pink", "E": "eye_green", "P": "fur_black", "N": "nose_pink",
                "M": "fur_white"}, {}),
    ("Siamese", {"F": "fur_cream", "K": "nose_pink", "E": "eye_blue", "P": "fur_black", "N": "choco",
                 "M": "choco", "D": "choco"}, {0: "D......D", 1: "DD....DD", 5: "FFDNNDFF"}),
    ("Void", {"F": "fur_black", "K": "galaxy_blue", "E": "eye_amber", "P": "fur_black", "N": "nose_pink",
              "M": "fur_black"}, {}),
    ("Calico", {"F": "fur_white", "K": "nose_pink", "E": "eye_amber", "P": "fur_black", "N": "nose_pink",
                "M": "fur_white", "O": "fur_orange", "B": "fur_black"},
     {0: "O......B", 1: "OK....KB", 2: "OOOFFBBB", 3: "OEEFFEEB"}),
)


def _pixels(b, rows, colours, x0, y_top, px, z0, z1):
    """Pixel art rows (top first) as spans, one per run of a colour, starting at x0 and reading toward -X."""
    for r, row in enumerate(rows):
        c = 0
        while c < len(row):
            ch = row[c]
            if ch == ".":
                c += 1
                continue
            e = c
            while e < len(row) and row[e] == ch:
                e += 1
            xa, xb = x0 - e * px, x0 - c * px
            b.span((xa, y_top - (r + 1) * px, z0), (xb, y_top - r * px, z1), colours[ch])
            c = e


def build_mural(mat):
    name = "CatCafe_Alley_Mural"
    b, sun = RB(), RB()
    h = 14.0
    _facade(b, h)
    x0, x1, y0, y1 = -13.5, 13.5, 1.5, 12.5
    b.span((x0 - 0.35, y0 - 0.35, -1.12), (x1 + 0.35, y1 + 0.35, -1.0), TRIM)               # frame
    for (ya, yb, sw) in ((y0, 3.0, "leaf_green"), (3.0, 6.0, "lamp_warm"), (6.0, 9.0, "blush"),
                         (9.0, y1, "pastel_lilac")):
        b.span((x0, ya, -1.17), (x1, yb, -1.12), sw)
    sun.cyl((10.4, 10.4, -1.2), 1.5, 0.06, "sparkle", axis="Z", segments=16)
    for k in range(8):                                                                     # sun rays
        a = math.radians(22.5 + 45 * k)
        sun.box((10.4 + 2.0 * math.cos(a), 10.4 + 2.0 * math.sin(a), -1.2), (0.7, 0.2, 0.06), "sparkle",
                rot=rot_z(math.degrees(a)))
    label(b, "PURR POT", -1.5, 9.7, -1.17, 0.48, 0.05, "offwhite", -1)
    px = 0.55
    for k, (_, colours, override) in enumerate(MURAL_CATS):
        rows = [override.get(r, row) for r, row in enumerate(FACE)]
        cx = -10.8 + 5.4 * (4 - k)                     # the first cat reads leftmost from the alley (+X)
        _pixels(b, rows, colours, cx + 4 * px, 3.5 + 8 * px, px, -1.22, -1.17)
    for k in range(7):                                                                     # paw prints on the grass
        x, y = 12.0 - k * 3.9, 2.0 + 0.45 * (k % 2)
        b.span((x - 0.22, y, -1.22), (x + 0.22, y + 0.32, -1.17), "offwhite")
        for dx, dy in ((-0.28, 0.42), (0, 0.55), (0.28, 0.42)):
            b.span((x + dx - 0.09, y + dy, -1.22), (x + dx + 0.09, y + dy + 0.16, -1.17), "offwhite")
    for k, (x, sw) in enumerate(((12.2, "blush"), (13.1, "mint"), (12.6, "sign_teal"))):    # paint cans and brush
        z = -1.9 - 0.8 * (k % 2)
        b.cyl((x, 0.45, z), 0.38, 0.9, "metal", segments=10)
        b.cyl((x, 0.92, z), 0.34, 0.06, sw, segments=10)
    b.box((11.2, 0.12, -2.4), (1.2, 0.12, 0.25), "caramel_wood", rot=rot_z(8))
    b.span((10.45, 0.05, -2.52), (10.7, 0.3, -2.28), "blush")
    return [b.finalize(name, mat), sun.finalize(name + "_Sun", mat)]


# --------------------------------------------------------------------------------------------- props --
def _crate(b, x, y, z, s=2.6, stencil=None):
    i = s - 0.1
    b.span((x - i / 2, y, z - i / 2), (x + i / 2, y + i, z + i / 2), "caramel_wood")
    for dx in (-1, 1):
        for dz in (-1, 1):
            b.span((x + dx * s / 2 - (0.25 if dx > 0 else 0), y, z + dz * s / 2 - (0.25 if dz > 0 else 0)),
                   (x + dx * s / 2 + (0.25 if dx < 0 else 0), y + i, z + dz * s / 2 + (0.25 if dz < 0 else 0)),
                   "dark_wood")
    for k in (1, 2):                                                                       # plank seams
        yy = y + i * k / 3
        b.span((x - i / 2, yy - 0.04, z - i / 2 - 0.03), (x + i / 2, yy + 0.04, z - i / 2), "dark_wood")
        b.span((x - i / 2 - 0.03, yy - 0.04, z - i / 2), (x - i / 2, yy + 0.04, z + i / 2), "dark_wood")
        b.span((x + i / 2, yy - 0.04, z - i / 2), (x + i / 2 + 0.03, yy + 0.04, z + i / 2), "dark_wood")
    for k in (1, 2):
        xx = x - i / 2 + i * k / 3
        b.span((xx - 0.04, y + i, z - i / 2), (xx + 0.04, y + i + 0.03, z + i / 2), "dark_wood")
    if stencil:
        label(b, stencil, x, y + i * 0.42, z - i / 2 - 0.03, 0.12, 0.02, "rust", -1)


def build_crate_stack(mat):
    name = "CatCafe_Alley_CrateStack"
    b = RB()
    s = 2.6
    cols = ((2.6, 3), (0.0, 2), (-2.6, 1))                    # x and height in crates; steps of 2.6 up to 7.8
    for x, n in cols:
        for k in range(n):
            _crate(b, x, k * s, 0, s, stencil=("FISH" if (x, k) == (0.0, 0) else "MILK" if (x, k) == (2.6, 1)
                                                else None))
    px0 = -5.2                                                                             # pallet step
    for k in range(5):
        b.span((px0 - 1.2, 0.35, -1.2 + k * 0.6), (px0 + 1.2, 0.5, -0.8 + k * 0.6), "caramel_wood")
    for z in (-1.1, 0, 1.1):
        b.span((px0 - 1.2, 0, z - 0.2), (px0 + 1.2, 0.35, z + 0.2), "dark_wood")
    b.span((px0 - 1.15, 0.0, -1.15), (px0 + 1.15, 0.5, 1.15), "caramel_wood")              # solid core to stand on
    return [b.finalize(name, mat)]


def _sag(x0, x1, y, sag, n):
    return [(x0 + (x1 - x0) * k / n, y - sag * (1 - (2 * k / n - 1) ** 2)) for k in range(n + 1)]


def build_laundry_line(mat):
    name = "CatCafe_Alley_LaundryLine"
    b, decor = RB(), RB()
    for x in (-12.0, 12.0):
        b.span((x - 0.6, 0, -0.6), (x + 0.6, 0.4, 0.6), "concrete")
        b.cyl((x, 5.6, 0), 0.2, 10.8, "dark_wood", segments=8)
        b.span((x - 0.15, 10.4, -0.9), (x + 0.15, 10.7, 0.9), "dark_wood")
    clothes = (
        ("shirt", -9.0, "shirt_blue"), ("sock", -6.6, "blush"), ("sock", -5.9, "mint"), ("pants", -3.8, "pants_navy"),
        ("towel", -0.6, "pastel_butter"), ("shirt", 2.6, "blush"), ("sock", 4.8, "rarity_rare"),
        ("shirt", 7.4, "mint"), ("sock", 9.6, "sparkle"),
    )
    for z in (-0.7, 0.7):
        pts = _sag(-12.0, 12.0, 10.55, 1.0, 10)
        for p0, p1 in zip(pts, pts[1:]):
            bar(decor, p0, p1, 0.06, z - 0.03, z + 0.03, "offwhite")
    for k, (kind, x, sw) in enumerate(clothes):
        y = 10.55 - 1.0 * (1 - (x / 12.0) ** 2)
        z = -0.7 if k % 2 == 0 else 0.7
        zz = (z - 0.05, z + 0.05)
        if kind == "shirt":
            decor.span((x - 0.8, y - 2.0, zz[0]), (x + 0.8, y, zz[1]), sw)
            for s in (-1, 1):
                decor.span((min(x + s * 0.8, x + s * 1.4), y - 0.9, zz[0]), (max(x + s * 0.8, x + s * 1.4), y, zz[1]), sw)
            decor.span((x - 0.25, y - 0.35, zz[0] - 0.01), (x + 0.25, y, zz[1] + 0.01), "offwhite")
        elif kind == "pants":
            decor.span((x - 0.8, y - 0.6, zz[0]), (x + 0.8, y, zz[1]), sw)
            for s in (-1, 1):
                decor.span((min(x + s * 0.05, x + s * 0.8), y - 2.6, zz[0]), (max(x + s * 0.05, x + s * 0.8), y - 0.6, zz[1]), sw)
        elif kind == "towel":
            decor.span((x - 1.0, y - 2.2, zz[0]), (x + 1.0, y, zz[1]), sw)
            for yy in (y - 1.7, y - 0.5):
                decor.span((x - 1.0, yy - 0.12, zz[0] - 0.01), (x + 1.0, yy + 0.12, zz[1] + 0.01), "blush")
            for dx, dy in ((0, -1.15), (-0.28, -0.8), (0, -0.7), (0.28, -0.8)):            # a paw on the towel
                r = 0.22 if dy == -1.15 else 0.1
                decor.span((x + dx - r, y + dy - r, zz[0] - 0.02), (x + dx + r, y + dy + r, zz[1] + 0.02), "offwhite")
        else:
            decor.span((x - 0.2, y - 1.0, zz[0]), (x + 0.2, y, zz[1]), sw)
            decor.span((x - 0.2, y - 1.2, zz[0]), (x + 0.45, y - 0.9, zz[1]), sw)
        for dx in ((-0.6, 0.6) if kind in ("shirt", "pants", "towel") else (0.0,)):          # pegs
            decor.span((x + dx - 0.06, y - 0.2, zz[0] - 0.04), (x + dx + 0.06, y + 0.15, zz[1] + 0.04), "caramel_wood")
    return [b.finalize(name, mat), decor.finalize(name + "_Decor", mat)]


def build_string_lights_long(mat):
    name = "CatCafe_Alley_StringLightsLong"
    b, wire, bulbs = RB(), RB(), RB()
    for x in (-14.0, 14.0):
        b.span((x - 0.5, 0, -0.5), (x + 0.5, 0.3, 0.5), "concrete_dark")
        b.cyl((x, 6.15, 0), 0.16, 11.7, "fur_black", segments=8)
        b.span((x - 0.25, 11.6, -0.25), (x + 0.25, 12.1, 0.25), "fur_black")
    pts = _sag(-14.0, 14.0, 11.8, 2.0, 16)
    for p0, p1 in zip(pts, pts[1:]):
        bar(wire, p0, p1, 0.06, -0.03, 0.03, "fur_black")
    colours = ("lamp_warm", "sparkle", "neon_pink", "lamp_warm", "mint")
    for k, (x, y) in enumerate(pts[1:-1]):
        bulbs.span((x - 0.16, y - 0.55, -0.16), (x + 0.16, y - 0.12, 0.16), colours[k % len(colours)])
    return [b.finalize(name, mat), wire.finalize(name + "_Decor", mat), bulbs.finalize(name + "_Bulbs", mat)]


def build_manhole(mat):
    name = "CatCafe_Sewer_Manhole"
    b, cover, sign, lamps = RB(), RB(), RB(), RB()
    b.cyl((0, 0.06, 0), 2.4, 0.12, "concrete_dark", segments=20)                          # frame
    cover.cyl((0, 0.17, 0), 2.0, 0.1, "metal", segments=20)
    for k in range(-3, 4):                                                                 # grip lines
        w = 2 * math.sqrt(max(0.0, 2.0 ** 2 - (k * 0.5) ** 2)) - 0.5
        cover.span((-w / 2, 0.22, k * 0.5 - 0.06), (w / 2, 0.26, k * 0.5 + 0.06), "concrete")
    for dx, dz, r in ((0, 0.25, 0.42), (-0.55, -0.35, 0.18), (0, -0.55, 0.18), (0.55, -0.35, 0.18)):
        cover.span((dx - r, 0.26, dz - r), (dx + r, 0.32, dz + r), "concrete_dark")            # paw
    # barricades on four sides: striped boards on A-frame legs, a warning lamp on each
    for k in range(4):
        a = math.radians(45 + 90 * k)
        nx, nz = math.cos(a), math.sin(a)                         # outward normal; the board runs along the tangent
        tx, tz = -nz, nx
        cx, cz = 4.0 * nx, 4.0 * nz
        turn = rot_y(-math.degrees(a) - 90)                       # local X onto the tangent
        for s in (-1, 1):
            for t in (-1, 1):
                b.box((cx + s * 1.3 * tx + t * 0.25 * nx, 0.8, cz + s * 1.3 * tz + t * 0.25 * nz), (0.15, 1.7, 0.15),
                      "offwhite", rot=turn @ rot_x(12 * t))
        for j in range(5):
            o = -1.4 + 0.7 * j
            b.box((cx + o * tx, 1.55, cz + o * tz), (0.7, 0.45, 0.12), "shirt_red" if j % 2 == 0 else "offwhite",
                  rot=turn)
        lamps.box((cx, 1.95, cz), (0.3, 0.3, 0.3), "eye_amber", rot=turn)
    # sign on a post at the front: name and a board for the requirement
    b.span((-0.12, 0, -5.4), (0.12, 4.6, -5.16), "metal")
    b.span((-1.8, 3.4, -5.5), (1.8, 4.6, -5.4), "concrete_dark")
    label(b, "SEWER", 0, 3.7, -5.5, 0.12, 0.03, "rarity_legend", -1)
    sign.span((-1.6, 2.0, -5.5), (1.6, 3.2, -5.4), "offwhite")
    return [b.finalize(name, mat), cover.finalize(name + "_Cover", mat), sign.finalize(name + "_SignBoard", mat),
            lamps.finalize(name + "_Lamp_Bulb", mat)]


ASSETS = {
    "CatCafe_Alley_ArchStreet": (build_arch_street, 5000),
    "CatCafe_Alley_Arch": (build_arch, 5000),
    "CatCafe_Alley_WallWindows": (build_wall_windows, 5000),
    "CatCafe_Alley_WallDoor": (build_wall_door, 5000),
    "CatCafe_Alley_FireEscape": (build_fire_escape, 6000),
    "CatCafe_Alley_Mural": (build_mural, 6000),
    "CatCafe_Alley_CrateStack": (build_crate_stack, 3000),
    "CatCafe_Alley_LaundryLine": (build_laundry_line, 2500),
    "CatCafe_Alley_StringLightsLong": (build_string_lights_long, 1500),
    "CatCafe_Sewer_Manhole": (build_manhole, 2500),
}
