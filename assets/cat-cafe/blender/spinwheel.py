"""The Spin Wheel station (F49, areas-and-stations.md B3) as a game show set. Derek, 2026-10-28 00:48: "Upload new
spinning wheel model and have a game show looking cat with it so it looks good"; 01:03: the wheel must spin round
its axle, not flip, and stay in one piece. A prize wheel in a gold cat-ear frame with chasing rim lights, on a
purple stage with marquee bulbs, the host (Dazzle, a tuxedo cat in a sequin jacket, pink bow tie and a little top
hat) at a microphone on its right and a pile of prizes on its left.

  CatCafe_Street_SpinWheel             stage, stand, frame, ears, host podium, mic and the prize pile (collides);
                                       an Attachment PromptAnchor in its PrimaryPart for the Spin prompt, 3 studs up
                                       at the front of the stage
  CatCafe_Street_SpinWheel_Wheel       everything that turns, one Model pivoted at the hub with its Z axis along the
                                       axle (the wheel faces -Z): the disc (its biggest part and PrimaryPart, thinnest
                                       along the axle), the six slices with their prize pictures, the spokes, rim
                                       band, pegs and hub cap. Slice 1 is under the pointer at rest and slice n is
                                       (n - 1) sixths of a turn round from it, clockwise seen from the front, in
                                       Catalog.spinWheel order: coins, Tuna, more coins, Salmon, golden fish, crate
  CatCafe_Street_SpinWheel_Pointer     one part, the pink diamond at the top, outside the Wheel
  CatCafe_Street_SpinWheel_RimLight    16 bulbs on the frame (Neon), outside the Wheel, for the chase and blink
  CatCafe_Street_SpinWheel_Bulbs       the stage's marquee bulbs, lit at night
  CatCafe_Street_SpinWheel_Cat_<Piece> the host, the same hinged pieces as every sitting cat; its hat (_Cat_Prop)
                                       rides inside the Head Model; its jacket and bow tie are _Cat_Outfit

Pivot at the base centre, the wheel's face (-Z) toward the players. Footprint 13.4 x 4.8 studs, 12.9 tall.
"""

import math

from mathutils import Matrix, Vector

import accessories as acc
import cats
import props
from alleyway import label
from common import GLYPHS, RB, Builder, scale_mesh
from plot import rot_z

HUB_Y = 6.5                                    # the axle's height
R_DISC, R_SLICE = 4.22, 4.0                    # the turning disc, and its slices
R_FRAME_IN, R_FRAME_OUT = 4.35, 4.85           # the still frame round it
STAGE_W, STAGE_F, STAGE_B, STAGE_H = 6.7, -2.6, 2.2, 0.8
TOP = STAGE_H + 0.06                           # the stage's top
HOST_X, HOST_Z, PODIUM_H = 5.35, -0.75, 1.3
PROMPT_ROBLOX = (0.0, 3.0, STAGE_F - 0.3)
SLICES = (                                     # (colour, picture) in Catalog.spinWheel order
    ("pastel_butter", "coin"), ("pastel_sky", "tuna"), ("mint", "coins"),
    ("blush", "salmon"), ("pastel_lilac", "golden_fish"), ("galaxy_blue", "crate"),
)
HOST = dict(rarity="Common", fur="fur_black", second="fur_white", eyes="eye_amber", pattern="patches",
            muzzle="fur_white", tuxedo=True, scale=1.5)
JACKET, LAPEL, BOW = "aurora_violet", "rarity_legend", "neon_pink"


def _slice_at(k):
    """Slice k's middle (1-based), degrees about +Z from the top: (k - 1) sixths of a turn, so its middle is at
    (-sin, cos) times the radius, clockwise seen from the front (-Z)."""
    return 60.0 * (k - 1)


class _Icon:
    """A prize picture on a slice: (u, v) across and out along the slice, drawn on the wheel's face (z < 0)."""

    def __init__(self, w, deg, r):
        self.w, self.t = w, math.radians(deg)
        self.R = rot_z(deg)
        self.r = r

    def xy(self, u, v):
        u, v = -u, v + self.r                                     # +u to the viewer's right (-X seen from the front)
        c, s = math.cos(self.t), math.sin(self.t)
        return u * c - v * s, u * s + v * c

    def box(self, u, v, z, size, sw, deg=0.0):
        x, y = self.xy(u, v)
        self.w.box((x, y, z), size, sw, rot=self.R @ rot_z(deg))

    def coin(self, u, v, z, r, dollar=True):
        x, y = self.xy(u, v)
        self.w.cyl((x, y, z), r, 0.08, "rarity_legend", axis="Z", segments=16)
        self.w.cyl((x, y, z - 0.03), r * 0.74, 0.04, "fur_golden", axis="Z", segments=16)
        if dollar:                                                           # the $ the game shows coins with
            px = r * 0.17
            rows = GLYPHS["$"]
            for row, bits in enumerate(rows):
                for col, bit in enumerate(bits):
                    if bit == "1":
                        self.box(u + (col - 1) * px, v + (2 - row) * px, z - 0.07, (px, px, 0.03), "fur_orange_dark")
            self.box(u, v, z - 0.075, (px * 0.5, px * 7, 0.03), "fur_orange_dark")    # the stroke through it

    def fish(self, u, v, z, length, body, fin, eye="fur_black"):
        """A fish side on, its head toward +u."""
        x, y = self.xy(u, v)
        self.w.b.ico(RB.p(x, y, z), length / 2, body, scale=(1.0, 0.28, 0.5), rot=RB._rot(self.R))
        tail = [self.xy(u - length * 0.38, v), self.xy(u - length * 0.72, v + length * 0.24),
                self.xy(u - length * 0.72, v - length * 0.24)]
        self.w.fan_z(z, tail[0], tail[1:], 0.08, fin)
        fins = [self.xy(u - length * 0.05, v + length * 0.2), self.xy(u + length * 0.12, v + length * 0.36),
                self.xy(u - length * 0.2, v + length * 0.3)]
        self.w.fan_z(z, fins[0], fins[1:], 0.06, fin)
        ex, ey = self.xy(u + length * 0.28, v + length * 0.04)
        self.w.ball((ex, ey, z - length * 0.13), length * 0.06, eye)


def _sparkle(icon, u, v, z, s, sw="offwhite"):
    icon.box(u, v, z, (s, s * 0.28, 0.03), sw)
    icon.box(u, v, z, (s * 0.28, s, 0.03), sw)
    icon.box(u, v, z - 0.005, (s * 0.5, s * 0.5, 0.03), sw, deg=45)


def _vring(b, cy, z0, z1, r_in, r_out, sw, n=48):
    """A ring standing in the XY plane round (0, cy) from n boxes; every other one stands 0.01 proud front and back,
    so neighbours never share a face where they overlap."""
    rm, wd = (r_in + r_out) / 2, r_out - r_in
    chord = 2 * r_out * math.sin(math.pi / n) * 1.04
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        e = 0.01 if k % 2 else 0.0
        b.box((-math.sin(a) * rm, cy + math.cos(a) * rm, (z0 + z1) / 2), (chord, wd, z1 - z0 + 2 * e), sw,
              rot=rot_z(math.degrees(a)))


def _wheel(w):
    """The turning wheel, hub at the origin, its face toward -Z."""
    w.cyl((0, 0, 0), R_DISC, 0.3, "galaxy_blue", axis="Z", segments=40)          # the disc, z -0.15 to 0.15
    zf = -0.15                                                                   # the disc's face
    for k, (sw, pic) in enumerate(SLICES, start=1):
        mid = _slice_at(k)
        pts = []
        for j in range(7):                                                       # the slice's arc, 6 segments
            a = math.radians(mid - 30 + 10 * j)
            pts.append((-math.sin(a) * R_SLICE, math.cos(a) * R_SLICE))
        w.fan_z(zf - 0.03, (0.0, 0.0), pts, 0.06, sw)                            # z -0.15 to -0.21
        icon = _Icon(w, mid, 2.55)
        zi = zf - 0.1                                                            # pictures on the slice
        if pic == "coin":
            icon.coin(0, 0, zi, 0.78)
        elif pic == "coins":
            for (u, v, r) in ((-0.48, -0.32, 0.5), (0.48, -0.32, 0.5), (0.0, 0.35, 0.56)):
                icon.coin(u, v, zi - (0.03 if v > 0 else 0), r)
        elif pic == "tuna":
            for j, v in enumerate((-0.62, 0.0, 0.62)):
                icon.fish(0.08 * (j - 1), v, zi - 0.025 * j, 1.0, "fish_blue", "shirt_blue")
        elif pic == "salmon":
            for j, v in enumerate((-0.45, 0.45)):
                icon.fish(0, v, zi - 0.025 * j, 1.4, "fur_peach", "nose_pink")
        elif pic == "golden_fish":
            icon.fish(0.12, 0, zi, 1.7, "fur_golden", "rarity_legend")   # tail clear of the spoke
            _sparkle(icon, 0.85, 0.75, zi - 0.03, 0.45)
            _sparkle(icon, -0.95, -0.6, zi - 0.03, 0.32)
        elif pic == "crate":
            icon.box(0, -0.05, zi, (1.5, 1.15, 0.12), "caramel_wood")
            for dv in (-0.36, 0.3):                                              # bands
                icon.box(0, -0.05 + dv, zi - 0.07, (1.56, 0.14, 0.04), "dark_wood")
            icon.box(0, 0.62, zi, (1.6, 0.26, 0.14), "caramel_wood")             # lid
            icon.box(0, -0.02, zi - 0.1, (0.32, 0.36, 0.04), "rarity_legend")    # the lock
            _sparkle(icon, 0.95, 0.95, zi - 0.03, 0.42, "rarity_legend")
            _sparkle(icon, -0.95, 0.8, zi - 0.03, 0.3, "rarity_legend")
            _sparkle(icon, 0.85, -0.85, zi - 0.03, 0.26, "offwhite")
    for k in range(6):                                                           # spokes on the slice edges
        a = math.radians(30 + 60 * k)
        ux, uy = -math.sin(a), math.cos(a)
        r0, r1 = 0.9, R_SLICE
        c = (r0 + r1) / 2
        w.box((ux * c, uy * c, zf - 0.075), (0.13, r1 - r0, 0.03), "offwhite", rot=rot_z(math.degrees(a)))
        w.cyl((ux * 4.07, uy * 4.07, zf - 0.15), 0.09, 0.2, "offwhite", axis="Z", segments=8)   # pegs, to -0.4
    _vring(w, 0, zf - 0.1, zf, R_DISC - 0.26, R_DISC, "rarity_legend")          # the rim band, z -0.15 to -0.25
    w.cyl((0, 0, zf - 0.075), 0.95, 0.15, "rarity_legend", axis="Z", segments=20)   # hub, to -0.3
    w.cyl((0, 0, zf - 0.19), 0.62, 0.08, BOW, axis="Z", segments=16)              # its cap, to -0.38
    w.cyl((0, -0.1, zf - 0.24), 0.22, 0.03, "offwhite", axis="Z", segments=12)    # a paw on the cap
    for (dx, dy) in ((-0.24, 0.14), (-0.08, 0.27), (0.08, 0.27), (0.24, 0.14)):
        w.cyl((dx, -0.1 + dy, zf - 0.24), 0.075, 0.03, "offwhite", axis="Z", segments=8)


def _stage(b, bulbs):
    b.span((-STAGE_W, 0, STAGE_F), (STAGE_W, STAGE_H, STAGE_B), JACKET)
    b.span((-STAGE_W + 0.1, STAGE_H, STAGE_F + 0.1), (STAGE_W - 0.1, TOP, STAGE_B - 0.1), "galaxy_blue")
    b.span((-STAGE_W - 0.08, STAGE_H - 0.12, STAGE_F - 0.08), (STAGE_W + 0.08, STAGE_H + 0.1, STAGE_F + 0.12),
           "rarity_legend")                                                         # gold trim along the front
    for s in (-1, 1):
        x0, x1 = sorted((s * (STAGE_W - 0.12), s * (STAGE_W + 0.08)))
        b.span((x0, STAGE_H - 0.12, STAGE_F + 0.12), (x1, STAGE_H + 0.1, STAGE_B + 0.08), "rarity_legend")
    n = 14                                                                          # skirt panels and bulbs
    for i in range(n):
        x0 = -STAGE_W + 2 * STAGE_W * i / n
        x1 = x0 + 2 * STAGE_W / n
        if i % 2:
            b.span((x0, 0.06, STAGE_F - 0.03), (x1, STAGE_H - 0.12, STAGE_F), "pastel_lilac")
    for i in range(1, n):
        x = -STAGE_W + 2 * STAGE_W * i / n
        bulbs.ball((x, 0.42, STAGE_F - 0.06), 0.11, "lamp_warm")


def _stand(b):
    b.span((-0.65, TOP, 0.42), (0.65, HUB_Y + 0.7, 1.5), JACKET)                    # the pillar behind the wheel
    b.span((-0.75, HUB_Y + 0.7, 0.32), (0.75, HUB_Y + 0.95, 1.6), "rarity_legend")
    b.span((-1.1, TOP, 0.3), (1.1, TOP + 0.35, 1.7), "rarity_legend")               # its foot
    b.cyl((0, HUB_Y, 0.3), 0.36, 0.3, "rarity_legend", axis="Z", segments=12)       # the axle, z 0.15 to 0.45
    b.span((-4.6, HUB_Y - 0.22, 0.2), (4.6, HUB_Y + 0.22, 0.6), "rarity_legend")    # cross bar to the frame
    for s in (-1, 1):                                                               # A-frame legs to the frame
        p0, p1 = (s * 3.4, TOP), (s * 2.35, HUB_Y - 4.25)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(dx, dy) + 0.3
        b.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 0.33), (0.36, L, 0.36), "rarity_legend",
              rot=rot_z(math.degrees(math.atan2(dy, dx)) - 90))
        b.span((s * 3.4 - 0.45, TOP, 0.2), (s * 3.4 + 0.45, TOP + 0.2, 0.72), "rarity_legend")   # feet


def _frame(b, lights, bulbs):
    _vring(b, HUB_Y, -0.25, 0.25, R_FRAME_IN, R_FRAME_OUT, "rarity_legend")      # the frame
    for k in range(16):                                                             # rim lights, none at the top
        a = math.radians(11.25 + 22.5 * k)
        r = (R_FRAME_IN + R_FRAME_OUT) / 2
        lights.ball((-math.sin(a) * r, HUB_Y + math.cos(a) * r, -0.3), 0.16, "lamp_warm")
    for s in (-1, 1):                                                               # cat ears on the frame
        mid = math.radians(s * 36)
        def at(deg_off, r):
            a = mid + math.radians(deg_off)
            return (-math.sin(a) * r, HUB_Y + math.cos(a) * r)
        b.fan_z(0.0, at(0, 6.35), [at(-15, R_FRAME_OUT - 0.2), at(15, R_FRAME_OUT - 0.2)], 0.4, "rarity_legend")
        b.fan_z(-0.22, at(0, 5.85), [at(-9, R_FRAME_OUT + 0.15), at(9, R_FRAME_OUT + 0.15)], 0.04, "nose_pink")
    b.span((-0.18, HUB_Y + R_FRAME_OUT - 0.1, -0.5), (0.18, HUB_Y + R_FRAME_OUT + 0.35, -0.2), "rarity_legend")
    b.cyl((0, HUB_Y + R_FRAME_OUT + 0.45, -0.36), 0.24, 0.3, BOW, axis="Z", segments=12)   # the pointer's hinge cap
    y0, y1, hw = HUB_Y + 5.7, HUB_Y + 7.0, 2.25                                   # a SPIN marquee between the ears
    for x in (-1.3, 1.3):
        b.span((x - 0.12, HUB_Y + R_FRAME_OUT - 0.1, -0.05), (x + 0.12, y0 + 0.05, 0.15), "rarity_legend")
    b.span((-hw, y0, -0.15), (hw, y1, 0.15), "offwhite")
    for (xa, xb, ya, yb) in ((-hw - 0.15, hw + 0.15, y0 - 0.15, y0 + 0.02), (-hw - 0.15, hw + 0.15, y1 - 0.02, y1 + 0.15),
                             (-hw - 0.15, -hw + 0.02, y0, y1), (hw - 0.02, hw + 0.15, y0, y1)):
        b.span((xa, ya, -0.22), (xb, yb, 0.22), "rarity_legend")
    px = 0.22
    for z, facing in ((-0.15, -1), (0.15, 1)):
        label(b, "SPIN", 0, (y0 + y1) / 2 - 2.5 * px, z, px, 0.07, BOW, facing)
    for k in range(9):                                                              # bulbs along its top
        bulbs.ball((-hw + 0.1 + k * (2 * hw - 0.2) / 8, y1 + 0.22, -0.12), 0.1, "lamp_warm")


def _pointer(p):
    """One part: a pink diamond hanging from the top of the frame, in front of the pegs."""
    p.box((0, HUB_Y + 4.62, -0.6), (0.8, 0.8, 0.22), BOW, rot=rot_z(45))


def _podium(b):
    b.cyl((HOST_X, TOP + PODIUM_H / 2, HOST_Z), 0.95, PODIUM_H, "rarity_legend", segments=18)
    b.cyl((HOST_X, TOP + PODIUM_H * 0.55, HOST_Z), 0.98, 0.3, JACKET, segments=18)
    b.cyl((HOST_X, TOP + PODIUM_H + 0.04, HOST_Z), 1.0, 0.08, JACKET, segments=18)
    b.b.star(RB.p(HOST_X, TOP + PODIUM_H * 0.55, HOST_Z - 0.97), 0.32, 0.14, 0.06, "offwhite",
             rot=Matrix.Rotation(math.radians(90), 3, "X"))


def _mic(b, mouth):
    """A microphone on a stand in front of the host, its head just under the chin."""
    mx, my, mz = mouth
    bx, bz = mx, mz - 1.05
    b.cyl((bx, TOP + 0.04, bz), 0.32, 0.08, "fur_black", segments=12)              # base on the stage
    top = my - 0.55
    b.cyl((bx, (TOP + top) / 2, bz), 0.05, top - TOP, "metal", segments=8)          # pole
    hx, hy, hz = mx, my - 0.45, mz - 0.6                                             # under the chin, face clear
    d = Vector((hx - bx, hy - top, hz - bz))
    tilt = math.degrees(math.atan2(d.z, d.y))
    b.box(((bx + hx) / 2, (top + hy) / 2, (bz + hz) / 2), (0.08, d.length, 0.08), "metal",
          rot=Matrix.Rotation(math.radians(tilt), 3, "X"))                          # gooseneck
    b.ball((hx, hy, hz), 0.2, "fur_black")                                          # the mic's head
    b.cyl((hx, hy - 0.16, hz), 0.12, 0.14, "rarity_legend", segments=10)            # gold band


def _prizes(b):
    """A pile of prizes on a little plinth on the other side: a crate, coins and a golden fish."""
    x, z = -5.35, -0.6
    b.cyl((x, TOP + 0.3, z), 1.0, 0.6, "rarity_legend", segments=18)
    b.cyl((x, TOP + 0.35, z), 1.03, 0.16, JACKET, segments=18)
    y = TOP + 0.6
    b.span((x - 0.55, y, z + 0.0), (x + 0.45, y + 0.8, z + 0.75), "caramel_wood")     # the crate
    for dy in (0.18, 0.6):
        b.span((x - 0.57, y + dy - 0.05, z - 0.02), (x + 0.47, y + dy + 0.05, z + 0.77), "dark_wood")
    b.span((x - 0.14, y + 0.3, z - 0.04), (x + 0.04, y + 0.5, z), "rarity_legend")    # its lock
    for (dx, dz, n) in ((0.45, -0.45, 3), (-0.45, -0.5, 2), (0.65, 0.3, 4)):         # coin stacks
        for i in range(n):
            b.cyl((x + dx + 0.02 * (i % 2), y + 0.05 + 0.1 * i, z + dz), 0.24, 0.09, "rarity_legend", segments=12)
    fx, fy, fz = x - 0.1, y + 0.15, z - 0.55                                         # the golden fish, lying down
    b.ball((fx, fy, fz), 0.4, "gold_mid", scale=(1.0, 0.36, 0.5))
    b.b.fan(RB.p(0, fy, 0), (-(fx + 0.32), fz), [(-(fx + 0.6), fz - 0.2), (-(fx + 0.6), fz + 0.2)], 0.08,
            "gold_mid")


def _top_hat(ctx):
    """A little purple top hat with a gold band, worn at a tilt."""
    P = ctx.pen("head")
    tilt = Matrix.Rotation(math.radians(-10), 3, "Y")                                     # between the ears
    P.cyl((0.0, 0.02, 0.01), 0.21, 0.04, JACKET, rot=tilt, segments=14)                   # brim
    P.cyl((0.03, 0.02, 0.19), 0.14, 0.32, JACKET, rot=tilt, segments=12)                  # crown
    P.cyl((0.01, 0.02, 0.07), 0.145, 0.07, LAPEL, rot=tilt, segments=12)                  # band
    P.box((0.0, -0.125, 0.075), (0.06, 0.02, 0.06), "offwhite", rot=tilt)                 # a sparkle on the band


def _outfit(mat):
    """The jacket and bow tie in the sitting body's own space (accessories' chest numbers), unscaled."""
    b = Builder()
    pad = 0.05
    front = acc.Y0 - pad
    z0, z1 = acc.Z0 + 0.02, acc.NECK_Z
    b.box((0, (acc.Y0 + acc.Y1) / 2, (z0 + z1) / 2), (2 * acc.X1 + 2 * pad, acc.Y1 - acc.Y0 + 2 * pad, z1 - z0),
          JACKET, bevel=False)                                                         # the jacket all round
    b.box((0, front - 0.006, z1 - 0.17), (2 * acc.X1 * 0.36, 0.03, 0.34), "offwhite", bevel=False)   # shirt
    for s in (-1, 1):                                                                  # gold lapels
        b.box((s * 0.15, front - 0.012, z1 - 0.22), (0.07, 0.03, 0.42), LAPEL, bevel=False,
              rot=(math.radians(s * 22), "Y"))
    for (x, z) in ((-0.24, z0 + 0.14), (0.22, z0 + 0.3), (-0.2, z0 + 0.42), (0.26, z0 + 0.1), (0.0, z0 + 0.06)):
        b.box((x, front - 0.01, z), (0.05, 0.02, 0.05), LAPEL, bevel=False, rot=(math.radians(45), "Y"))   # sequins
    for side in (-1, 1):                                                               # sequins on the sides
        for z in (z0 + 0.12, z0 + 0.36):
            b.box((side * (acc.X1 + pad + 0.006), (acc.Y0 + acc.Y1) / 2, z), (0.02, 0.05, 0.05), LAPEL, bevel=False)
    by, bz = front - 0.06, z1 - 0.05                                                   # the bow tie
    b.box((0, by, bz), (0.12, 0.1, 0.12), BOW)
    for s in (-1, 1):
        b.box((s * 0.18, by + 0.01, bz), (0.26, 0.08, 0.22), BOW, rot=(math.radians(-s * 12), "Y"))
    return b.finalize("CatCafe_Street_SpinWheel_Cat_Outfit", mat)


def _mouth(k, at):
    """The host's mouth in the station's Roblox space."""
    d = cats.dims(HOST, "sit")
    h, n = d["head"], d["neck"]
    m = (0.0, n[1] + h["fy"], n[2] + h["fz"] - 0.2 * h["k"])
    return (at[0] - m[0] * k, at[1] + m[2] * k, at[2] + m[1] * k)


def build_spin_wheel(mat):
    name = "CatCafe_Street_SpinWheel"
    b, w, ptr, lights, bulbs = RB(), RB(), RB(), RB(), RB()
    _stage(b, bulbs)
    _stand(b)
    _frame(b, lights, bulbs)
    _podium(b)
    _prizes(b)
    _wheel(w)
    _pointer(ptr)
    k = cats.scale_of(HOST, "sit")
    seat = (HOST_X, TOP + PODIUM_H + 0.08, HOST_Z)
    _mic(b, _mouth(k, seat))
    out = [b.finalize(name, mat), w.finalize(name + "_Wheel", mat, location=(0, HUB_Y, 0)),
           ptr.finalize(name + "_Pointer", mat), lights.finalize(name + "_RimLight", mat),
           bulbs.finalize(name + "_Bulbs", mat)]
    base = name + "_Cat"                                                              # the host
    cat = cats.build_cat("SpinHostCat", mat, spec=HOST, base=base, body="sit")
    d = cats.dims(HOST, "sit")
    ctx = props.Ctx(HOST, "sit", d)
    _top_hat(ctx)
    hat = ctx.main.finalize(base + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hat, k)
    hat["rides"] = "Head"
    outfit = _outfit(mat)
    scale_mesh(outfit, k)
    for ob in cat + [hat, outfit]:
        ob.location = ob.location + Vector(RB.p(*seat))
    return out + cat + [hat, outfit]


def prompt_attachment():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: PromptAnchor at the front of the stage."""
    return ("CatCafe_Street_SpinWheel", "PromptAnchor", Matrix.Translation(Vector(RB.p(*PROMPT_ROBLOX))))


ASSETS = {
    "CatCafe_Street_SpinWheel": (build_spin_wheel, 9000),
}
