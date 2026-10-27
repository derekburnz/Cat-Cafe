"""Cafe plot set pieces (docs/design/cat-cafe/world-and-feel.md sections 3 to 5): the building shell in four
pastels, its interior dressing, the For Rent dressing for empty plots and the tier sets seen from the street.

Every piece is placed at the Plot's pivot (Plot.cframe: floor top centre, -Z toward the street) with no offset,
and is laid out in Roblox plot-local axes through common.RB. The engineer's floor stays; the shell brings the
walls. Inside is 36 x 28 with 1-stud walls outside the floor edge (front z -15..-14, back z 14..15, sides
x +-18..+-19), walls 12.8 tall, the front door 7 wide at x 0 and the back door 6 wide at x -8 (both 7.5 high),
two arched front windows, a gable roof with its ridge running front to back, and a 5-stud front garden from
z -20 to -15 with a path, beds, a bench and a lamp post.

Objects per shell (the exporter turns each extra object into a child Model):
  CatCafe_Plot_Cafe_<Colour>             walls, trim, awning, garden (collidable walls)
  ..._Glass                              window and fanlight glass (collidable, Transparency 0.45)
  ..._Roof                               roof, ridge and chimney: the engineer fades this Model for the owner
  ..._SignBoard                          one part named SignBoard; its -Z face takes the owner's SurfaceGui
  ..._LampPost_Bulb, _SignLamp_Bulb, _BackLamp_Bulb    Neon at night
"""

import math

import bpy
from mathutils import Matrix

import cats
import poses
from common import RB, bake_transform, text_width

H = 12.8                 # wall height to the eave
HW = 19.0                # outer half width (walls x 18..19)
PITCH = math.radians(25)
RIDGE = H + HW * math.tan(PITCH)            # 21.66, underside of the roof at the ridge
FRONT, BACK = -15.0, 15.0                    # outer faces
DOOR = (-3.5, 3.5, 7.5)
WINDOWS = (-11.0, 11.0)                      # arched window centres
WIN_R, SILL, SPRING = 4.25, 1.0, 5.0         # arch radius = half width, sill and springing heights
SIDE_WIN = (-8.5, -5.5, 3.8, 7.3)            # z0, z1, y0, y1 on both side walls
BACK_DOOR = (-11.0, -5.0, 7.5)
BACK_WIN = (12.5, 15.5, 4.0, 7.5)            # x0, x1, y0, y1
SIGN = (-8.0, 8.0, 13.4, 16.6)               # x0, x1, y0, y1 on the front gable
SIGN_INFO = {"part": "SignBoard", "face": "Front (-Z)", "size": [16.0, 3.2], "centre": [0.0, 15.0, -15.35]}
CHIMNEY_TOP = (11.1, 25.1, 9.1)              # Roblox plot-local, where chimney smoke starts

COLOURS = {                                  # facade, accent (awning stripes, door frame, shutters)
    "Mint": ("mint", "blush"),
    "Blush": ("blush", "mint"),
    "Butter": ("pastel_butter", "sign_teal"),
    "Lilac": ("pastel_lilac", "pastel_butter"),
}
TRIM = "offwhite"
INNER = "cream"


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def arc(cx, cy, r, a0, a1, n):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def arch_ring(b, cx, cy, r, w, z0, z1, swatch, n=10):
    """Half ring of blocks round an arch, inner radius r, w wide, between depths z0 and z1."""
    for k in range(n):
        a = math.radians(180 * (k + 0.5) / n)
        rr = r + w / 2
        chord = 2 * (r + w) * math.sin(math.pi / (2 * n)) * 1.12
        dz = 0.015 * (k % 2)                   # stagger so neighbouring blocks never share a face
        b.box((cx + rr * math.cos(a), cy + rr * math.sin(a), (z0 + z1) / 2 - dz), (w, chord, abs(z1 - z0)), swatch,
              rot=rot_z(math.degrees(a)))


def spandrels(b, cx, cy, r, z_out, z_in, facade, n=5):
    """The wall left in the two corners above an arch (between the arc and its bounding box), pastel outside
    and cream inside like the rest of the wall."""
    split = z_out + (z_in - z_out) * 0.8
    for (za, zb), sw in (((z_out, split), facade), ((split, z_in), INNER)):
        zc, d = (za + zb) / 2, abs(zb - za)
        b.fan_z(zc, (cx + r, cy + r), arc(cx, cy, r, 0, 90, n), d, sw)
        b.fan_z(zc, (cx - r, cy + r), arc(cx, cy, r, 90, 180, n), d, sw)


def layered(b, x0, x1, y0, y1, z_out, z_in, facade, axis="z"):
    """A wall piece in two layers: pastel outside (0.8) and cream inside (0.2). For axis z the piece spans
    x0..x1 at depth z_out (outer face) to z_in (inner face); for axis x the roles of x and z swap."""
    split = z_out + (z_in - z_out) * 0.8
    if axis == "z":
        b.span((x0, y0, min(z_out, split)), (x1, y1, max(z_out, split)), facade)
        b.span((x0, y0, min(split, z_in)), (x1, y1, max(split, z_in)), INNER)
    else:
        b.span((min(z_out, split), y0, x0), (max(z_out, split), y1, x1), facade)
        b.span((min(split, z_in), y0, x0), (max(split, z_in), y1, x1), INNER)


# --------------------------------------------------------------------------------------------- shell --
def _front_wall(b, glass, facade, accent):
    zo, zi = FRONT, FRONT + 1
    d0, d1, dh = DOOR
    x_edges = [-HW]
    for cx in WINDOWS[:1]:
        x_edges += [cx - WIN_R, cx + WIN_R]
    x_edges += [d0, d1]
    for cx in WINDOWS[1:]:
        x_edges += [cx - WIN_R, cx + WIN_R]
    x_edges += [HW]
    # full-height piers between openings
    for x0, x1 in ((x_edges[0], x_edges[1]), (x_edges[2], x_edges[3]), (x_edges[4], x_edges[5]),
                   (x_edges[6], x_edges[7])):
        layered(b, x0, x1, 0, H, zo, zi, facade)
    for cx in WINDOWS:
        layered(b, cx - WIN_R, cx + WIN_R, 0, SILL, zo, zi, facade)                 # under the sill
        layered(b, cx - WIN_R, cx + WIN_R, SPRING + WIN_R, H, zo, zi, facade)       # over the arch
        spandrels(b, cx, SPRING, WIN_R, zo, zi, facade)
        # glass and its cross bars
        glass.span((cx - WIN_R, SILL, -14.58), (cx + WIN_R, SPRING, -14.42), "glass")
        glass.fan_z(-14.5, (cx, SPRING), arc(cx, SPRING, WIN_R, 0, 180, 6), 0.16, "glass")
        b.span((cx - 0.1, SILL, -14.7), (cx + 0.1, SPRING + WIN_R, -14.6), TRIM)
        b.span((cx - WIN_R, SPRING - 0.1, -14.7), (cx + WIN_R, SPRING + 0.1, -14.6), TRIM)
        # frame: jambs, arch ring, sill and keystone
        for x0, x1 in ((cx - WIN_R - 0.4, cx - WIN_R), (cx + WIN_R, cx + WIN_R + 0.4)):
            b.span((x0, SILL, zo - 0.25), (x1, SPRING, zo + 0.05), TRIM)
        arch_ring(b, cx, SPRING, WIN_R, 0.4, zo - 0.25, zo + 0.05, TRIM)
        b.span((cx - WIN_R - 0.6, SILL - 0.35, zo - 0.45), (cx + WIN_R + 0.6, SILL, zi), TRIM)
        b.span((cx - 0.4, SPRING + WIN_R - 0.1, zo - 0.35), (cx + 0.4, SPRING + WIN_R + 0.7, zo + 0.05), accent)
    # door: open arch with a sunburst fanlight
    layered(b, d0, d1, dh + (d1 - d0) / 2, H, zo, zi, facade)
    spandrels(b, 0, dh, (d1 - d0) / 2, zo, zi, facade)
    r = (d1 - d0) / 2
    glass.fan_z(-14.5, (0, dh), arc(0, dh, r, 0, 180, 6), 0.16, "glass")
    for a in (30, 60, 90, 120, 150):
        b.box((0.5 * r * math.cos(math.radians(a)), dh + 0.5 * r * math.sin(math.radians(a)), -14.65),
              (r, 0.14, 0.12), TRIM, rot=rot_z(a))
    b.span((d0, dh - 0.15, -14.75), (d1, dh + 0.15, -14.25), TRIM)
    for x0, x1 in ((d0 - 0.55, d0), (d1, d1 + 0.55)):
        b.span((x0, 0, zo - 0.35), (x1, dh, zo + 0.05), accent)
    arch_ring(b, 0, dh, r, 0.55, zo - 0.35, zo + 0.05, accent, n=8)
    b.span((-0.35, dh + r - 0.1, zo - 0.45), (0.35, dh + r + 0.75, zo + 0.05), TRIM)


def _side_walls(b, glass, facade, accent):
    z0, z1, y0, y1 = SIDE_WIN
    for s in (-1, 1):
        xo, xi = s * HW, s * (HW - 1)
        for (a0, a1, b0, b1) in ((-14, z0, 0, H), (z1, 14, 0, H), (z0, z1, 0, y0), (z0, z1, y1, H)):
            split = xo + (xi - xo) * 0.8
            b.span((min(xo, split), b0, a0), (max(xo, split), b1, a1), facade)
            b.span((min(split, xi), b0, a0), (max(split, xi), b1, a1), INNER)
        gx = s * (HW - 0.5)
        glass.span((gx - 0.08, y0, z0), (gx + 0.08, y1, z1), "glass")
        b.span((min(gx - 0.1, gx + 0.1), (y0 + y1) / 2 - 0.08, z0), (max(gx - 0.1, gx + 0.1), (y0 + y1) / 2 + 0.08, z1),
               TRIM)
        out = s * (HW + 0.25)
        lo, hi = min(xo, out), max(xo, out)
        b.span((lo, y1, z0 - 0.3), (hi, y1 + 0.35, z1 + 0.3), TRIM)                       # head
        b.span((min(xo, s * (HW + 0.45)), y0 - 0.3, z0 - 0.4), (max(xo, s * (HW + 0.45)), y0, z1 + 0.4), TRIM)
        for a0, a1 in ((z0 - 0.3, z0), (z1, z1 + 0.3)):
            b.span((lo, y0, a0), (hi, y1, a1), TRIM)
        for a0, a1 in ((z0 - 1.6, z0 - 0.35), (z1 + 0.35, z1 + 1.6)):                     # shutters
            b.span((min(xo, s * (HW + 0.15)), y0, a0), (max(xo, s * (HW + 0.15)), y1, a1), accent)
            for k in range(3):
                yy = y0 + (y1 - y0) * (k + 1) / 4
                b.span((min(xo, s * (HW + 0.22)), yy - 0.06, a0 + 0.15), (max(xo, s * (HW + 0.22)), yy + 0.06, a1 - 0.15),
                       TRIM)
        b.cyl((s * (HW + 0.3), (H - 0.4) / 2, 13.6), 0.18, H - 0.4, "metal", axis="Y", segments=8)  # downpipe


def _back_wall(b, glass, facade, accent):
    zo, zi = BACK, BACK - 1
    bd0, bd1, bdh = BACK_DOOR
    w0, w1, wy0, wy1 = BACK_WIN
    for x0, x1 in ((-HW, bd0), (bd1, w0), (w1, HW)):
        layered(b, x0, x1, 0, H, zo, zi, facade)
    layered(b, bd0, bd1, bdh, H, zo, zi, facade)
    layered(b, w0, w1, 0, wy0, zo, zi, facade)
    layered(b, w0, w1, wy1, H, zo, zi, facade)
    glass.span((w0, wy0, 14.42), (w1, wy1, 14.58), "glass")
    b.span((w0, (wy0 + wy1) / 2 - 0.08, 14.62), (w1, (wy0 + wy1) / 2 + 0.08, 14.72), TRIM)
    b.span((w0 - 0.3, wy1, zo - 0.05), (w1 + 0.3, wy1 + 0.35, zo + 0.25), TRIM)
    b.span((w0 - 0.4, wy0 - 0.3, zo - 0.05), (w1 + 0.4, wy0, zo + 0.45), TRIM)
    # back door frame, canopy and mat
    for x0, x1 in ((bd0 - 0.5, bd0), (bd1, bd1 + 0.5)):
        b.span((x0, 0, zo - 0.05), (x1, bdh, zo + 0.3), accent)
    b.span((bd0 - 0.5, bdh, zo - 0.05), (bd1 + 0.5, bdh + 0.6, zo + 0.3), accent)
    b.span((bd0 - 1.0, 9.0, zo), (bd1 + 1.0, 9.25, zo + 1.8), TRIM)
    for x in (bd0 - 0.7, bd1 + 0.7):
        b.box((x, 8.5, zo + 0.55), (0.2, 1.3, 0.2), "dark_wood", rot=rot_x(-45))
    b.span((bd0 + 1.0, 0, zo + 0.2), (bd1 - 1.0, 0.06, zo + 1.8), "blush")


def _base_and_trim(b):
    for x0, x1 in ((-HW - 0.2, DOOR[0]), (DOOR[1], HW + 0.2)):
        b.span((x0, 0, FRONT - 0.2), (x1, 0.9, FRONT), "terracotta")
    for x0, x1 in ((-HW - 0.2, BACK_DOOR[0]), (BACK_DOOR[1], HW + 0.2)):
        b.span((x0, 0, BACK), (x1, 0.9, BACK + 0.2), "terracotta")
    for s in (-1, 1):
        b.span((min(s * HW, s * (HW + 0.2)), 0, FRONT), (max(s * HW, s * (HW + 0.2)), 0.9, BACK), "terracotta")
    for s in (-1, 1):                                                                    # corner pilasters
        for z in (FRONT, BACK):
            b.span((min(s * 18.2, s * 19.4), 0, z - 0.4), (max(s * 18.2, s * 19.4), H, z + 0.4), TRIM)
    b.span((-HW - 0.35, H - 0.6, FRONT - 0.35), (HW + 0.35, H, FRONT), TRIM)            # eave cornice
    b.span((-HW - 0.35, H - 0.6, BACK), (HW + 0.35, H, BACK + 0.35), TRIM)
    for s in (-1, 1):
        b.span((min(s * HW, s * (HW + 0.35)), H - 0.6, FRONT), (max(s * HW, s * (HW + 0.35)), H, BACK), TRIM)


def _gables(b, facade):
    tri = [(-HW, H), (HW, H)]
    for zo, zi in ((FRONT, FRONT + 1), (BACK, BACK - 1)):
        split = zo + (zi - zo) * 0.8
        b.fan_z((zo + split) / 2, (0, RIDGE), tri, abs(split - zo), facade)
        b.fan_z((split + zi) / 2, (0, RIDGE), tri, abs(zi - split), INNER)
    b.cyl((0, 19.1, FRONT - 0.05), 1.25, 0.3, TRIM, axis="Z", segments=16)              # attic vent
    b.cyl((0, 19.1, FRONT - 0.2), 0.85, 0.12, "night_sky", axis="Z", segments=16)
    for a in (0, 90):
        b.box((0, 19.1, FRONT - 0.28), (1.7, 0.12, 0.06), TRIM, rot=rot_z(a))


def _awning(b, accent, x0=-16.0, x1=16.0, top=11.6, drop=1.4, out=3.0):
    """Striped awning over a window: sloped stripes, a short valance and two scallops per stripe."""
    z_wall = FRONT
    L = math.hypot(drop, out)
    ang = math.degrees(math.atan2(drop, out))
    n = int(round((x1 - x0) / 2))
    w = (x1 - x0) / n
    edge = top - drop
    for k in range(n):
        x = x0 + w * (k + 0.5)
        sw = accent if k % 2 == 0 else "offwhite"
        b.box((x, top - drop / 2, z_wall - out / 2), (w, 0.15, L), sw, rot=rot_x(-ang))
        b.span((x - w / 2, edge - 0.35, z_wall - out - 0.06), (x + w / 2, edge, z_wall - out + 0.06), sw)
        for dx in (-w / 4, w / 4):
            b.cyl((x + dx, edge - 0.35, z_wall - out), w / 4, 0.08, sw, axis="Z", segments=12)
    for x in (x0, x1):
        b.wedge((x, top - drop / 2, z_wall - out / 2), (0.15, drop, out), accent)
    b.span((x0 - 0.1, top - 0.1, z_wall - 0.25), (x1 + 0.1, top + 0.25, z_wall), "dark_wood")


def _sign(b, sign, bulbs, accent):
    x0, x1, y0, y1 = SIGN
    z = FRONT
    b.span((x0 - 0.35, y0 - 0.35, z - 0.2), (x1 + 0.35, y1 + 0.35, z), "dark_wood")
    sign.span((x0, y0, z - 0.35), (x1, y1, z - 0.2), "offwhite")
    for s in (-1, 1):                                                                      # cat ears on the frame
        ex = s * (x1 - 1.6)
        b.fan_z(z - 0.1, (ex, y1 + 1.6), [(ex - 1.1, y1 + 0.35), (ex + 1.1, y1 + 0.35)], 0.2, "dark_wood")
        b.fan_z(z - 0.25, (ex, y1 + 1.1), [(ex - 0.55, y1 + 0.4), (ex + 0.55, y1 + 0.4)], 0.1, accent)
    for x in (-4.5, 4.5):                                                                  # gooseneck sign lamps
        b.span((x - 0.08, y1 + 0.35, z - 1.3), (x + 0.08, y1 + 0.5, z), "fur_black")
        b.span((x - 0.3, y1 + 0.1, z - 1.6), (x + 0.3, y1 + 0.5, z - 1.0), "fur_black")
        bulbs.span((x - 0.2, y1 - 0.05, z - 1.5), (x + 0.2, y1 + 0.12, z - 1.1), "lamp_warm")


def _roof(r, chimney):
    t = 0.6
    tan, cos, sin = math.tan(PITCH), math.cos(PITCH), math.sin(PITCH)
    eave_x = HW + 1.6
    zlen = 2 * 16.4
    L = eave_x / cos
    for s in (-1, 1):
        mid = eave_x / 2
        uy = RIDGE - mid * tan
        cx, cy = s * (mid + 0.5 * t * sin), uy + 0.5 * t * cos
        ang = -s * math.degrees(PITCH)
        r.box((cx, cy, 0), (L, t, zlen), "terracotta", rot=rot_z(ang))
        ex, ey = eave_x + t * sin, RIDGE - eave_x * tan + t * cos                            # top of the eave edge
        for k in range(10):
            d = 1.0 + 2.1 * k
            px, py = ex - d * cos, ey + d * sin
            r.box((s * (px + 0.08 * sin), py + 0.08 * cos, 0), (0.32, 0.16, zlen), "brick", rot=rot_z(ang))
        for zf in (-16.5, 16.5):                                                             # barge boards
            r.box((cx, cy - 0.1, zf), (L, t + 0.35, 0.2), TRIM, rot=rot_z(ang))
        r.span((min(s * eave_x, s * (eave_x + 0.2)), RIDGE - eave_x * tan - 0.35, -16.6),
               (max(s * eave_x, s * (eave_x + 0.2)), RIDGE - eave_x * tan + t, 16.6), TRIM)
    r.span((-0.7, RIDGE + t / cos - 0.2, -16.7), (0.7, RIDGE + t / cos + 0.45, 16.7), "brick")   # ridge cap
    r.span((10.0, RIDGE - 12.2 * tan, 8.0), (12.2, 24.5, 10.2), "brick")                        # chimney
    r.span((9.7, 24.5, 7.7), (12.5, 25.0, 10.5), "concrete_dark")
    chimney.span((10.5, 25.0, 8.5), (11.7, 25.1, 9.7), "fur_black")                             # smoke starts here


def _garden(b, bulbs, flowers, fireflies):
    gz0, gz1 = -20.0, FRONT
    b.span((DOOR[0], -0.2, gz0), (DOOR[1], 0.02, gz1), "floor_tile")                         # path
    for z in (-19.0, -17.6, -16.2):
        b.span((DOOR[0] + 0.2, 0.02, z - 0.06), (DOOR[1] - 0.2, 0.05, z + 0.06), "concrete")
    b.span((-2.2, 0.02, -17.3), (2.2, 0.08, -15.3), "blush")                                # door mat
    for x0, x1 in ((-HW + 0.2, DOOR[0] - 0.5), (DOOR[1] + 0.5, HW - 0.2)):                  # beds
        flowers.span((x0, -0.2, -19.6), (x1, 0.15, gz1 - 0.2), "leaf_green")
        fireflies.span((x0, 0.6, -19.6), (x1, 4.0, gz1 - 0.4), "leaf_green")                 # air they drift in
        b.span((x0 - 0.15, -0.2, -19.75), (x1 + 0.15, 0.3, -19.6), "terracotta")
    for x0, x1 in ((-HW, DOOR[0] - 0.4), (DOOR[1] + 0.4, HW)):                              # picket fence
        n = int((x1 - x0) / 1.5)
        for k in range(n + 1):
            x = x0 + (x1 - x0) * k / n
            b.span((x - 0.1, 0, -19.95), (x + 0.1, 1.15, -19.75), TRIM)
        for y in (0.45, 0.9):
            b.span((x0, y - 0.07, -19.92), (x1, y + 0.07, -19.78), TRIM)
    flowers = ((-17.0, -18.4, "blush"), (-16.2, -16.6, "sparkle"), (-9.0, -18.9, "offwhite"),
               (-7.6, -16.4, "nose_pink"), (-5.4, -18.2, "sparkle"), (6.0, -18.6, "blush"),
               (7.4, -16.2, "sparkle"), (12.2, -16.5, "nose_pink"), (13.4, -19.0, "offwhite"),
               (17.4, -16.6, "blush"))
    for x, z, sw in flowers:
        for dx, dz in ((0, 0), (0.45, 0.3), (-0.35, 0.4)):
            b.span((x + dx - 0.18, 0.15, z + dz - 0.18), (x + dx + 0.18, 0.5, z + dz + 0.18), sw)
    # bench on the left bed, facing the street
    bx = -12.5
    b.span((bx - 1.8, 0.95, -18.3), (bx + 1.8, 1.15, -17.2), "caramel_wood")
    b.span((bx - 1.8, 1.15, -17.3), (bx + 1.8, 2.3, -17.1), "caramel_wood")
    for x in (bx - 1.5, bx + 1.5):
        for z0, z1 in ((-18.2, -17.95), (-17.4, -17.15)):
            b.span((x - 0.12, 0.15, z0), (x + 0.12, 0.95, z1), "dark_wood")
    # lamp post on the right bed
    lx, lz = 15.6, -18.6
    b.span((lx - 0.35, 0.15, lz - 0.35), (lx + 0.35, 0.5, lz + 0.35), "fur_black")
    b.cyl((lx, 3.45, lz), 0.14, 5.9, "fur_black", segments=8)
    b.span((lx - 0.45, 6.4, lz - 0.45), (lx + 0.45, 6.5, lz + 0.45), "fur_black")
    for dx in (-0.4, 0.4):
        for dz in (-0.4, 0.4):
            b.span((lx + dx - 0.05, 6.5, lz + dz - 0.05), (lx + dx + 0.05, 7.3, lz + dz + 0.05), "fur_black")
    bulbs.span((lx - 0.3, 6.55, lz - 0.3), (lx + 0.3, 7.25, lz + 0.3), "lamp_warm")
    b.b.pyramid(RB.p(lx, 7.3, lz), 1.1, 0.6, "fur_black")
    # potted shrubs by the door and a round bush
    for x in (DOOR[0] - 1.6, DOOR[1] + 1.6):
        b.cyl((x, 0.45, -16.0), 0.55, 0.9, "terracotta", r2=0.65, segments=10)
        b.ball((x, 1.55, -16.0), 0.8, "leaf_dark")
    b.ball((6.6, 0.8, -18.6), 0.9, "leaf_green", scale=(1.2, 0.9, 1.0))


def build_cafe(colour, mat):
    facade, accent = COLOURS[colour]
    name = f"CatCafe_Plot_Cafe_{colour}"
    b, glass, roof, sign, bulbs_post, bulbs_sign, bulbs_back = RB(), RB(), RB(), RB(), RB(), RB(), RB()
    chimney, flowers, fireflies = RB(), RB(), RB()
    _front_wall(b, glass, facade, accent)
    _side_walls(b, glass, facade, accent)
    _back_wall(b, glass, facade, accent)
    _base_and_trim(b)
    _gables(b, facade)
    _awning(b, accent, -16.0, -5.0)
    _awning(b, accent, 5.0, 16.0)
    _sign(b, sign, bulbs_sign, accent)
    _garden(b, bulbs_post, flowers, fireflies)
    x = BACK_DOOR[1] + 1.4                                                                   # back door lamp
    b.span((x - 0.1, 6.6, BACK), (x + 0.1, 6.8, BACK + 0.6), "fur_black")
    bulbs_back.span((x - 0.25, 6.0, BACK + 0.4), (x + 0.25, 6.6, BACK + 0.9), "lamp_warm")
    _roof(roof, chimney)
    return [b.finalize(name, mat), glass.finalize(name + "_Glass", mat), roof.finalize(name + "_Roof", mat),
            sign.finalize(name + "_SignBoard", mat), bulbs_post.finalize(name + "_LampPost_Bulb", mat),
            bulbs_sign.finalize(name + "_SignLamp_Bulb", mat), bulbs_back.finalize(name + "_BackLamp_Bulb", mat),
            chimney.finalize(name + "_Chimney", mat), flowers.finalize(name + "_Flowers", mat),
            fireflies.finalize(name + "_Fireflies", mat)]


# ------------------------------------------------------------------------------------------ interior --
TABLES = ((-9, -6), (0, -6), (9, -6), (-9, 1), (0, 1), (9, 1))      # Layout.plot.tables
BEAMS = (-6.0, 1.0, 8.0)                                            # tie beams; the pendant lamps hang from them


def _wainscot(b):
    """Plank wainscot to 3.4 with a chair rail and baseboard on every inner wall face, skipping the openings."""
    top = 3.4
    runs = []                                                   # (axis, fixed, a0, a1, height, inward sign)
    for a0, a1 in ((-18, -15.25), (-6.75, DOOR[0]), (DOOR[1], 6.75), (15.25, 18)):
        runs.append(("z", -14.0, a0, a1, top, 1))
    for cx in WINDOWS:
        runs.append(("z", -14.0, cx - WIN_R, cx + WIN_R, SILL, 1))
    for a0, a1 in ((-18, BACK_DOOR[0]), (BACK_DOOR[1], 18)):
        runs.append(("z", 14.0, a0, a1, top, -1))
    for s_ in (-1, 1):
        runs.append(("x", s_ * 18.0, -14, 14, top, -s_))
    for axis, f, a0, a1, h, inward in runs:
        def slab(t0, t1, y0, y1, sw, a0=a0, a1=a1, f=f, inward=inward, axis=axis):
            lo, hi = sorted((f + inward * t0, f + inward * t1))
            if axis == "z":
                b.span((a0, y0, lo), (a1, y1, hi), sw)
            else:
                b.span((lo, y0, a0), (hi, y1, a1), sw)
        slab(0, 0.15, 0, h, "caramel_wood")
        slab(0, 0.23, 0, 0.35, "dark_wood")
        if h >= top:
            slab(0, 0.27, top - 0.05, top + 0.2, "dark_wood")
            n = int((a1 - a0) / 2.0)
            for k in range(1, n):
                t = a0 + (a1 - a0) * k / n
                lo, hi = sorted((f + inward * 0.15, f + inward * 0.18))
                if axis == "z":
                    b.span((t - 0.06, 0.35, lo), (t + 0.06, top - 0.05, hi), "kibble")
                else:
                    b.span((lo, 0.35, t - 0.06), (hi, top - 0.05, t + 0.06), "kibble")
        else:
            slab(0, 0.45, h - 0.12, h, "offwhite")                                          # inner window sill
    # crown moulding
    b.span((-18, H - 0.6, -14), (18, H, -13.75), TRIM)
    b.span((-18, H - 0.6, 13.75), (18, H, 14), TRIM)
    for s_ in (-1, 1):
        lo, hi = sorted((s_ * 18, s_ * 17.75))
        b.span((lo, H - 0.6, -14), (hi, H, 14), TRIM)


def _curtains(b):
    for cx in WINDOWS:
        for x0, x1 in ((cx - WIN_R + 0.05, cx - WIN_R + 1.15), (cx + WIN_R - 1.15, cx + WIN_R - 0.05)):
            b.span((x0, SILL + 0.1, -13.85), (x1, 8.6, -13.6), "mint")
            b.span((x0 - 0.05, 3.8, -13.95), (x1 + 0.05, 4.1, -13.5), "blush")              # tie-back
        b.span((cx - WIN_R - 0.3, 8.65, -13.85), (cx + WIN_R + 0.3, 8.85, -13.6), "dark_wood")
    z0, z1, y0, y1 = SIDE_WIN
    for s_ in (-1, 1):
        lo, hi = sorted((s_ * 17.85, s_ * 17.65))
        for a0, a1 in ((z0 - 0.4, z0 + 0.5), (z1 - 0.5, z1 + 0.4)):
            b.span((lo, y0 - 0.2, a0), (hi, y1 + 0.3, a1), "blush")
        b.span((lo, y1 + 0.3, z0 - 0.6), (hi, y1 + 0.5, z1 + 0.6), "dark_wood")


def _menu_board(b):
    z = 13.75
    b.span((-3.3, 5.7, z - 0.02), (3.3, 9.7, 14.0), "dark_wood")
    b.span((-3.0, 6.0, z - 0.12), (3.0, 9.4, z), "fur_black")
    w = b.text("MENU", (2.0, 8.3, z - 0.12), 0.22, 0.05, "offwhite", right=(-1, 0, 0))
    for k, (ln, dot) in enumerate(((2.6, "rarity_legend"), (2.0, "blush"), (2.9, "mint"))):
        y = 7.6 - 0.55 * k
        b.span((2.4 - ln, y, z - 0.16), (2.4, y + 0.14, z - 0.12), "offwhite")
        b.span((-2.6, y - 0.03, z - 0.16), (-2.2, y + 0.17, z - 0.12), dot)
    return w


def _shelves(b):
    for (x0, x1, y) in ((5.5, 10.5, 7.0), (-17.5, -12.5, 8.2)):
        b.span((x0, y, 13.1), (x1, y + 0.2, 14.0), "caramel_wood")
        for x in (x0 + 0.5, x1 - 0.5):
            b.span((x - 0.1, y - 0.6, 13.6), (x + 0.1, y, 14.0), "dark_wood")
    for x, plant in ((6.3, "ball"), (8.0, "cactus"), (9.7, "ball")):
        b.cyl((x, 7.55, 13.55), 0.35, 0.7, "terracotta", r2=0.42, segments=10)
        if plant == "ball":
            b.ball((x, 8.25, 13.55), 0.45, "leaf_green")
        else:
            b.span((x - 0.15, 7.9, 13.4), (x + 0.15, 8.9, 13.7), "leaf_dark")
            b.span((x - 0.45, 8.2, 13.45), (x - 0.15, 8.35, 13.65), "leaf_dark")
            b.span((x - 0.45, 8.35, 13.45), (x - 0.3, 8.7, 13.65), "leaf_dark")
    for x, sw in ((-16.8, "offwhite"), (-15.8, "mint"), (-14.8, "blush")):                  # mugs
        b.cyl((x, 8.75, 13.55), 0.3, 0.7, sw, segments=10)
    # a little cat figurine on the mug shelf
    b.span((-13.8, 8.4, 13.3), (-13.0, 8.85, 13.8), "fur_orange")
    b.span((-13.75, 8.85, 13.3), (-13.25, 9.3, 13.6), "fur_orange")
    for x in (-13.7, -13.35):
        b.span((x, 9.3, 13.4), (x + 0.1, 9.5, 13.5), "fur_orange")


def _frames(b):
    """Pictures of our cats on the side walls: frame, mat and a pixel cat."""
    pics = ((-1, 0.0, "fur_orange", "mint"), (-1, 4.6, "fur_black", "blush"), (1, 0.0, "fur_grey", "pastel_butter"),
            (1, -11.2, "fur_white", "mint"))
    for s_, z, fur, bg in pics:
        f = s_ * 18.0
        def sl(t0, t1, y0, y1, za, zb, sw, f=f, s_=s_):
            lo, hi = sorted((f - s_ * t0, f - s_ * t1))
            b.span((lo, y0, za), (hi, y1, zb), sw)
        sl(0, 0.12, 7.3, 9.5, z - 1.2, z + 1.2, "dark_wood")
        sl(0.12, 0.16, 7.5, 9.3, z - 1.0, z + 1.0, bg)
        sl(0.16, 0.2, 7.8, 8.4, z - 0.6, z + 0.3, fur)                                    # body
        sl(0.16, 0.2, 8.2, 8.8, z + 0.3, z + 0.8, fur)                                    # head
        sl(0.16, 0.2, 8.8, 9.0, z + 0.35, z + 0.45, fur)                                  # ears
        sl(0.16, 0.2, 8.8, 9.0, z + 0.65, z + 0.75, fur)
        sl(0.16, 0.2, 8.4, 9.0, z - 0.75, z - 0.6, fur)                                   # tail


def _string_lights(b, bulbs, x0, x1, y, z, sag, n_bulbs, cols=("sparkle", "fur_orange", "mint", "blush")):
    pts = []
    n = 8
    for k in range(n + 1):
        t = k / n
        pts.append((x0 + (x1 - x0) * t, y - sag * 4 * t * (1 - t)))
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, by - ay)
        b.box(((ax + bx) / 2, (ay + by) / 2, z), (L + 0.05, 0.06, 0.06), "fur_black",
              rot=rot_z(math.degrees(math.atan2(by - ay, bx - ax))))
    for k in range(n_bulbs):
        t = (k + 0.5) / n_bulbs
        x, yy = x0 + (x1 - x0) * t, y - sag * 4 * t * (1 - t)
        bulbs.ball((x, yy - 0.3, z), 0.2, cols[k % len(cols)], scale=(1, 1.25, 1))


def build_interior(mat):
    name = "CatCafe_Plot_Interior"
    b, lamps, bulbs = RB(), RB(), RB()
    _wainscot(b)
    _curtains(b)
    _menu_board(b)
    _shelves(b)
    _frames(b)
    for z in BEAMS:
        b.span((-18, H - 0.55, z - 0.3), (18, H - 0.05, z + 0.3), "dark_wood")
    for x, z in TABLES:
        b.span((x - 0.05, 9.95, z - 0.05), (x + 0.05, H - 0.55, z + 0.05), "fur_black")
        b.cyl((x, 9.6, z), 0.95, 0.7, "mint", r2=0.3, segments=12)
        lamps.ball((x, 9.2, z), 0.3, "lamp_warm")
    _string_lights(b, bulbs, -17.0, -1.0, 11.6, 13.6, 0.9, 7)
    _string_lights(b, bulbs, 1.0, 17.0, 11.6, 13.6, 0.9, 7)
    _string_lights(b, bulbs, -17.0, 17.0, 11.9, -13.6, 0.7, 13)
    return [b.finalize(name, mat), lamps.finalize(name + "_HangingLamp_Bulb", mat),
            bulbs.finalize(name + "_StringLights_Bulbs", mat)]


# ------------------------------------------------------------------------------------------ for rent --
SLEEP = dict(pivot=(0, 0, 0), rot=(0, 0, 0), offset=(0, 0, -0.42), head=(-28, 0, 22), tail=(0, 0, 75))


def _roller(b, shutter, x0, x1, top, bottom, z):
    """Housing on b; the curtain goes on `shutter` (_Shutter, which the effects code rolls up on a claim)."""
    b.span((x0 - 0.2, top, z - 0.45), (x1 + 0.2, top + 0.55, z), "concrete_dark")
    shutter.span((x0, bottom, z - 0.3), (x1, top, z - 0.18), "metal")
    y = top - 0.3
    while y > bottom + 0.1:
        shutter.span((x0, y - 0.04, z - 0.34), (x1, y + 0.04, z - 0.3), "concrete")
        y -= 0.4
    shutter.span((x0, bottom, z - 0.38), (x1, bottom + 0.15, z - 0.18), "concrete_dark")


def _sleeping_cat(asset, mat, at, turn):
    built = cats.build_cat("Tabby", mat, spec=dict(cats.ROSTER["Tabby"], tucked=True))   # no legs under the floor
    world = Matrix.Translation(RB.p(*at)) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    bpy.context.view_layer.update()
    out = poses.posed_copies(built, SLEEP, world=world, prefix="")
    bpy.context.view_layer.update()
    for c, ob in zip(out, built):
        c.name = asset + "_Cat" + ob.name.split(".")[0][len("CatCafe_Cat_Tabby"):]
        bpy.data.objects.remove(ob, do_unlink=True)
        bake_transform(c)
    return out


def build_for_rent(mat):
    name = "CatCafe_Plot_ForRent"
    b, sign, shutter = RB(), RB(), RB()
    for cx in WINDOWS:                                                       # roller shutters, half down
        _roller(b, shutter, cx - WIN_R - 0.4, cx + WIN_R + 0.4, SPRING, (SILL + SPRING) / 2, FRONT - 0.05)
    _roller(b, shutter, DOOR[0] - 0.55, DOOR[1] + 0.55, DOOR[2], DOOR[2] - 0.9, FRONT - 0.3)
    # hanging blade sign beside the door: FOR / RENT both sides and a cat silhouette
    sx = DOOR[1] + 0.9
    b.span((sx - 0.1, 8.25, -17.9), (sx + 0.1, 8.45, FRONT), "fur_black")
    b.span((sx - 0.1, 7.9, FRONT - 0.2), (sx + 0.1, 8.45, FRONT), "fur_black")
    for z in (-17.5, -15.4):
        b.span((sx - 0.04, 7.8, z - 0.04), (sx + 0.04, 8.25, z + 0.04), "metal")
    z0, z1, y0, y1 = -17.75, -15.15, 5.0, 7.8
    sign.span((sx - 0.12, y0, z0), (sx + 0.12, y1, z1), "offwhite")
    b.span((sx - 0.1, y0 - 0.12, z0 - 0.12), (sx + 0.1, y1 + 0.12, z1 + 0.12), "blush")
    for side in (1, -1):
        fx = sx + side * 0.12
        right = (0, 0, -1) if side == 1 else (0, 0, 1)
        start = z1 - 0.25 if side == 1 else z0 + 0.25
        px = 0.13
        for word, y in (("FOR", 7.0), ("RENT", 6.25)):
            b.text(word, (fx, y, start), px, 0.04, "shirt_red", right=right)
        cat_z = (z0 + z1) / 2
        d = side * 0.04
        lo, hi = sorted((fx, fx + d))
        for (a, c, ya, yb) in ((-0.5, 0.3, 5.3, 5.75), (0.3, 0.7, 5.6, 6.0), (0.33, 0.43, 6.0, 6.15),
                               (0.57, 0.67, 6.0, 6.15), (-0.75, -0.5, 5.6, 6.0)):
            za, zb = sorted((cat_z + side * a, cat_z + side * c))
            b.span((lo, ya, za), (hi, yb, zb), "fur_black")
    # dust sheets: over the counter and two pieces of stored furniture
    b.span((-4.5, 0, 9.4), (4.5, 3.0, 12.6), "offwhite")
    b.span((0.4, 3.0, 9.9), (4.2, 4.4, 12.1), "offwhite")
    for z, sgn in ((9.25, -1), (12.75, 1)):
        b.wedge((0, 0.6, z), (9.0, 1.2, 0.35), "offwhite", rot=rot_y(0 if sgn < 0 else 180))
    for x, z in ((-9.0, -2.0), (8.0, 3.0)):
        b.span((x - 1.2, 0, z - 1.2), (x + 1.2, 2.2, z + 1.2), "offwhite")
        b.ball((x, 2.3, z), 1.2, "offwhite", scale=(1, 0.45, 1))
    # boxes and a broom by the door
    for (x, y, z, w, h) in ((-6.3, 0.15, -16.4, 1.4, 1.1), (-7.7, 0.15, -16.2, 1.2, 0.9), (-6.6, 1.25, -16.3, 1.0, 0.8)):
        b.span((x - w / 2, y, z - w / 2), (x + w / 2, y + h, z + w / 2), "cardboard")
        b.span((x - w / 2 - 0.01, y + h - 0.12, z - 0.12), (x + w / 2 + 0.01, y + h + 0.01, z + 0.12), "kibble")
    b.box((-4.55, 2.0, -15.35), (0.12, 3.8, 0.12), "caramel_wood", rot=rot_z(-12))
    b.box((-4.15, 0.42, -15.35), (0.7, 0.7, 0.3), "treat_tan", rot=rot_z(-12))       # tilted, its low corner at the floor
    out = [b.finalize(name, mat), sign.finalize(name + "_Sign", mat), shutter.finalize(name + "_Shutter", mat)]
    out += _sleeping_cat(name, mat, (1.9, 0.02, -16.3), -25)
    zz = RB()
    for k, (y, px) in enumerate(((1.6, 0.07), (2.1, 0.09), (2.75, 0.11))):
        zz.text("Z", (1.6 - 0.3 * k, y, -16.6), px, 0.05, "offwhite", right=(-1, 0, 0))
    out.append(zz.finalize(name + "_Zzz", mat))
    return out


# --------------------------------------------------------------------------------------------- tiers --
def _bistro(b, x, z, accent, parasol=True):
    b.cyl((x, 0.2, z), 0.45, 0.1, "fur_black", segments=10)
    b.cyl((x, 1.2, z), 0.08, 2.0, "fur_black", segments=8)
    b.cyl((x, 2.25, z), 0.75, 0.1, "offwhite", segments=14)
    for dx in (-1.25, 1.25):
        cx = x + dx
        b.span((cx - 0.4, 1.3, z - 0.4), (cx + 0.4, 1.45, z + 0.4), accent)
        sgn = 1 if dx > 0 else -1
        bx = cx + sgn * 0.35
        b.span((bx - 0.06, 1.45, z - 0.4), (bx + 0.06, 2.6, z + 0.4), "fur_black")
        for lx in (cx - 0.33, cx + 0.33):
            for lz in (z - 0.33, z + 0.33):
                b.span((lx - 0.05, 0.15, lz - 0.05), (lx + 0.05, 1.3, lz + 0.05), "fur_black")
    if parasol:
        b.cyl((x, 3.6, z), 0.06, 2.7, "offwhite", segments=6)
        b.cyl((x, 4.75, z), 1.9, 0.8, accent, r2=0.15, segments=16)
        b.cyl((x, 5.2, z), 0.12, 0.2, "offwhite", segments=6)


def build_tier(n, mat):
    name = f"CatCafe_Plot_Tier{n}"
    b = RB()
    extra = []
    if n == 1:                                                                # chalkboard stand on the path
        x, z, hw = -2.95, -18.9, 0.5                  # path's left edge, clear of Tier 5's rope line at x -2.3
        b.span((x - hw, 0.15, z - 0.06), (x + hw, 2.3, z + 0.06), "dark_wood")
        b.span((x - hw + 0.12, 0.45, z - 0.1), (x + hw - 0.12, 2.15, z - 0.06), "fur_black")
        b.box((x, 1.2, z + 0.45), (2 * hw, 2.1, 0.1), "dark_wood", rot=rot_x(-25))
        px = 0.66 / text_width("CAFE", 1.0)
        b.text("CAFE", (x + 0.33, 1.6, z - 0.1), px, 0.03, "offwhite", right=(-1, 0, 0))
        b.cyl((x + 0.17, 0.95, z - 0.12), 0.18, 0.3, "offwhite", segments=10)             # a cup
        for dx, dy in ((-0.2, 1.05), (-0.3, 0.85), (-0.1, 0.85), (-0.2, 0.7)):            # a paw
            b.span((x + dx - 0.06, dy, z - 0.14), (x + dx + 0.06, dy + 0.1, z - 0.1), "blush")
    elif n == 2:                                                              # flower boxes and a bistro set
        flowers = RB()                                                        # _Flowers: butterflies by day
        for cx in WINDOWS:                            # hung under the sill's front edge (z -15.45), above the beds
            b.span((cx - 4.4, 0.5, -16.2), (cx + 4.4, 1.0, -15.45), "terracotta")
            flowers.span((cx - 4.3, 1.0, -16.1), (cx + 4.3, 1.15, -15.55), "leaf_green")
            for k in range(9):
                fx = cx - 3.9 + k * 0.975
                b.span((fx - 0.2, 1.1, -16.0 + 0.2 * (k % 2)), (fx + 0.2, 1.5, -15.6 + 0.2 * (k % 2)),
                       ("blush", "sparkle", "offwhite", "nose_pink")[k % 4])
        _bistro(b, 11.0, -17.3, "mint")
        extra = [flowers.finalize(name + "_Flowers", mat)]
    elif n == 3:                                                              # neon OPEN, string lights, 2nd bistro
        tube, bulbs = RB(), RB()
        cx = WINDOWS[0]
        tube.text("OPEN", (cx + 2.4, 2.4, -14.3), 0.3, 0.1, "neon_pink", right=(-1, 0, 0))
        for (x0, x1, y0, y1) in ((cx - 2.75, cx + 2.75, 2.05, 2.15), (cx - 2.75, cx + 2.75, 4.15, 4.25),
                                 (cx - 2.75, cx - 2.65, 2.05, 4.25), (cx + 2.65, cx + 2.75, 2.05, 4.25)):
            tube.span((x0, y0, -14.32), (x1, y1, -14.22), "neon_pink")
        b.span((cx - 2.9, 1.9, -14.15), (cx + 2.9, 4.4, -14.1), "fur_black")
        for x in (cx - 2.2, cx + 2.2):
            b.span((x - 0.03, 4.4, -14.15), (x + 0.03, SPRING + 2.0, -14.1), "metal")
        # a festoon under each awning's scalloped edge (awnings x 5..16 each side, lip at z -18, scallops to y 9.35)
        _string_lights(b, bulbs, -15.8, -5.2, 9.25, FRONT - 3.2, 0.6, 7)
        _string_lights(b, bulbs, 5.2, 15.8, 9.25, FRONT - 3.2, 0.6, 7)
        _bistro(b, -7.6, -17.4, "blush")
        extra = [tube.finalize(name + "_Sign_Tube", mat), bulbs.finalize(name + "_StringLights_Bulbs", mat)]
    elif n == 4:                                                              # fish tank in the window, back patio
        glass, water = RB(), RB()
        cx, dz = WINDOWS[1], 1.6                       # 1.6 back from the window, clear of the Window plants decor
        b.span((cx - 2.6, 0, -13.85 + dz), (cx + 2.6, 1.0, -12.2 + dz), "dark_wood")
        glass.span((cx - 2.5, 1.0, -13.75 + dz), (cx + 2.5, 3.4, -12.3 + dz), "glass")
        water.span((cx - 2.4, 1.1, -13.65 + dz), (cx + 2.4, 3.0, -12.4 + dz), "fish_blue")
        b.span((cx - 2.6, 3.4, -13.85 + dz), (cx + 2.6, 3.55, -12.2 + dz), "fur_black")
        for (fx, fy, sw) in ((cx - 1.0, 2.2, "fur_orange"), (cx + 0.8, 1.7, "sparkle"), (cx + 1.6, 2.5, "fur_orange")):
            b.span((fx - 0.25, fy - 0.12, -13.1 + dz), (fx + 0.25, fy + 0.12, -12.9 + dz), sw)
            b.span((fx + 0.25, fy - 0.15, -13.08 + dz), (fx + 0.4, fy + 0.15, -12.92 + dz), sw)
        for px in (cx - 1.8, cx + 0.2, cx + 1.9):
            b.span((px - 0.1, 1.1, -13.2 + dz), (px + 0.1, 2.3, -13.0 + dz), "leaf_green")
        # back patio: deck path to the yard gate, pergola over the back door, planters, lights
        bd0, bd1 = BACK_DOOR[0], BACK_DOOR[1]
        b.span((bd0 - 0.5, 0, BACK + 0.2), (bd1 + 0.5, 0.15, 24.8), "caramel_wood")
        for k in range(12):
            z = BACK + 0.6 + k * 0.8
            b.span((bd0 - 0.5, 0.15, z - 0.04), (bd1 + 0.5, 0.17, z + 0.04), "kibble")
        for x in (bd0 - 0.9, bd1 + 0.9):
            for z in (BACK + 1.2, BACK + 4.2):
                b.span((x - 0.2, 0, z - 0.2), (x + 0.2, 8.2, z + 0.2), TRIM)
        for z in (BACK + 1.2, BACK + 4.2):
            b.span((bd0 - 1.4, 8.2, z - 0.2), (bd1 + 1.4, 8.6, z + 0.2), TRIM)
        for k in range(6):
            x = bd0 - 1.0 + k * (bd1 - bd0 + 2.0) / 5
            b.span((x - 0.1, 8.6, BACK + 0.8), (x + 0.1, 8.85, BACK + 4.6), TRIM)
        for x in (bd0 - 2.2, bd1 + 2.2):
            for z in (19.0, 23.0):
                b.span((x - 0.7, 0, z - 0.7), (x + 0.7, 1.0, z + 0.7), "terracotta")
                b.ball((x, 1.5, z), 0.8, "leaf_green")
        bulbs = RB()
        _string_lights(b, bulbs, bd0 - 1.0, bd1 + 1.0, 8.4, BACK + 4.2, 0.8, 6)
        extra = [glass.finalize(name + "_Glass", mat), water.finalize(name + "_Water", mat),
                 bulbs.finalize(name + "_StringLights_Bulbs", mat)]
    elif n == 5:                                                              # gold trim, rooftop sign, red carpet
        gold = "rarity_legend"
        b.span((-18.2, H - 0.75, FRONT - 0.42), (18.2, H - 0.6, FRONT - 0.3), gold)       # between the pilasters
        x0, x1, y0, y1 = SIGN
        top = [(x0 - 0.45, -4.6), (-4.4, 4.4), (4.6, x1 + 0.45)]                    # gaps for the gooseneck arms
        strips = [(a0, a1, y1 + 0.3, y1 + 0.45) for a0, a1 in top]
        strips += [(x0 - 0.45, x1 + 0.45, y0 - 0.45, y0 - 0.3), (x0 - 0.45, x0 - 0.3, y0 - 0.45, y1 + 0.45),
                   (x1 + 0.3, x1 + 0.45, y0 - 0.45, y1 + 0.45)]
        for (a0, a1, c0, c1) in strips:
            b.span((a0, c0, FRONT - 0.3), (a1, c1, FRONT - 0.21), gold)
        for xx in (DOOR[0] - 0.65, DOOR[1] + 0.55):
            b.span((xx, 0.15, FRONT - 0.45), (xx + 0.1, DOOR[2], FRONT - 0.35), gold)    # from the bed top
        # rooftop sign: a cup with cat ears and a star, standing on the front of the ridge cap
        cy = RIDGE + 0.6 / math.cos(PITCH) + 0.45
        b.cyl((0, cy + 1.3, FRONT - 0.2), 1.5, 2.6, "offwhite", r2=1.75, segments=16)
        b.cyl((0, cy + 1.2, FRONT - 0.2), 1.58, 0.5, "blush", segments=16)
        for sgn in (-1, 1):
            b.wedge((sgn * 1.0, cy + 3.0, FRONT - 0.2), (0.15, 0.8, 0.9), "offwhite", rot=rot_y(90 * sgn))
        b.span((1.6, cy + 0.6, FRONT - 0.35), (2.4, cy + 0.8, FRONT - 0.05), "offwhite")
        b.span((2.2, cy + 0.6, FRONT - 0.35), (2.4, cy + 2.0, FRONT - 0.05), "offwhite")
        b.span((1.6, cy + 1.8, FRONT - 0.35), (2.4, cy + 2.0, FRONT - 0.05), "offwhite")
        b.b.star(RB.p(0, cy + 4.6, FRONT - 0.2), 0.9, 0.4, 0.25, gold, rot=(math.radians(90), "X"))
        b.span((-0.08, cy, FRONT - 0.25), (0.08, cy + 0.1, FRONT - 0.15), gold)
        # red carpet with gold posts and ropes
        b.span((-1.6, 0.08, -20.0), (1.6, 0.15, FRONT - 0.2), "shirt_red")              # over the stones and mat
        for x in (-2.3, 2.3):
            for z in (-19.6, -16.4):
                b.cyl((x, 0.2, z), 0.3, 0.15, gold, segments=10)
                b.cyl((x, 0.95, z), 0.08, 1.6, gold, segments=8)
                b.ball((x, 1.8, z), 0.16, gold)
            b.span((x - 0.06, 1.45, -19.6), (x + 0.06, 1.6, -16.4), "shirt_red")
    else:
        raise ValueError(n)
    return [b.finalize(name, mat)] + extra


def build_closed_sign(mat):
    """F44: the cafe closes at night. A night-sky board hung from the front door's transom bar on two chains, with a
    crescent moon through it and CLOSED on both faces, so it reads from the street and from inside. It hangs above
    head height (5.5 to 7.1) and nothing on it collides. Place it at the Plot pivot like the tiers, nights only."""
    name = "CatCafe_Plot_ClosedSign"
    b, moon = RB(), RB()
    zc, t = -14.5, 0.12                                   # in the doorway, centred under the transom (z -14.75..-14.25)
    x0, x1, y0, y1 = -2.9, 2.9, 5.5, 7.1
    zf, zb = zc - t / 2 - 0.04, zc + t / 2 + 0.04         # board faces, proud of the frame
    for x in (-2.2, 2.2):
        b.span((x - 0.04, y1 + 0.1, zc - 0.04), (x + 0.04, DOOR[2] - 0.15, zc + 0.04), "metal")      # chains
    b.span((x0 - 0.12, y0 - 0.12, zc - t / 2), (x1 + 0.12, y1 + 0.12, zc + t / 2), "dark_wood")    # frame
    b.span((x0, y0, zf), (x1, y1, zb), "night_sky")
    px = 0.16
    w = text_width("CLOSED", px)
    cx = -0.75                                            # text left of the moon from the street, right of it inside
    b.text("CLOSED", (cx + w / 2, 5.8, zf), px, 0.03, "offwhite", right=(-1, 0, 0))
    b.text("CLOSED", (cx - w / 2, 5.8, zb), px, 0.03, "offwhite", right=(1, 0, 0))
    rows = ("..##.....", ".##......", "###......", "###......", "###......", "###......", "###......", ".####....",
            "..#####..")
    mx, mtop, mp = 2.05, 6.9, 0.13                        # a tilted crescent through the board, horns toward the text
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == "#":
                x = mx - (c - 4) * mp
                moon.span((x - mp / 2, mtop - (r + 1) * mp, zf - 0.03), (x + mp / 2, mtop - r * mp, zb + 0.03), "sparkle")
    for x, y in ((1.62, 6.5), (1.2, 6.92)):               # two stars by the horns, both faces
        for z0, z1 in ((zf - 0.03, zf), (zb, zb + 0.03)):
            b.span((x - 0.06, y - 0.06, z0), (x + 0.06, y + 0.06, z1), "sparkle")
    return [b.finalize(name, mat), moon.finalize(name + "_Moon_Bulb", mat)]


ASSETS = {f"CatCafe_Plot_Cafe_{c}": (lambda m, c=c: build_cafe(c, m), 12000) for c in COLOURS}
ASSETS["CatCafe_Plot_Interior"] = (build_interior, 8000)
ASSETS["CatCafe_Plot_ForRent"] = (build_for_rent, 4000)
ASSETS.update({f"CatCafe_Plot_Tier{n}": (lambda m, n=n: build_tier(n, m), 3000) for n in range(1, 6)})
ASSETS["CatCafe_Plot_ClosedSign"] = (build_closed_sign, 1500)
