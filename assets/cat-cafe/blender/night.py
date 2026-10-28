"""The short night (features.md F66, data-model section 9): at dusk the catching areas close until sunrise. Each
gate (and the street arch into the Alley Square) gets a night fence with a moon sign, the long back-alley edges
get fence pieces, and each cafe's back door is shut with a "Closed until sunrise" sign. All of it only stands at
night, so the boards are a night blue that reads in the dark, and the moon, stars and letters are _Bulb parts
(Neon at night, WorldController).

  CatCafe_<Area>_NightFence       across a gate's opening, behind its Bars (Park, Neighbourhood, Woods, Sewer),
                                  or behind the posts of the street arch (Alley); place it at the gate's or arch's
                                  pivot with no offset
  CatCafe_Alley_NightFenceSegment an 8 stud piece that tiles end to end along the back alleys' inner edges and
                                  across the side passages; pivot at its base centre, front -Z toward the cafes
  CatCafe_Plot_BackDoorClosed     a door shut in the back door opening with the sign on its alley side; place it
                                  at the Plot's pivot like the other plot pieces

Every fence is 8 studs tall to the rail tops, above a player's jump, and collides; the sign parts do not.
"""

import math

from alleyway import label
from areas import BARS_TOP
from common import RB, text_width
from plot import BACK, BACK_DOOR, rot_z

HEIGHT = 8.0                     # top rail; the picket tips stand 0.45 above it
PLANK = 0.9
Z_FRONT, Z_BACK = 0.35, 0.75     # the pickets, just behind a gate's Bars (z -0.2..0.2)
POST = 0.6
BOARD, RAIL, POSTC = "galaxy_blue", "pants_navy", "pants_navy"
GLOW = "pastel_butter"           # moon and stars
INK = "offwhite"                 # sign letters

# area id -> (asset, gate or arch it closes, opening width, half width the fence spans, depth offset)
GATES = {
    "park": ("CatCafe_Park_NightFence", "CatCafe_Park_Gate", 32.0, 0.0),
    "neighbourhood": ("CatCafe_Neighbourhood_NightFence", "CatCafe_Neighbourhood_Gate", 32.0, 0.0),
    "woods": ("CatCafe_Woods_NightFence", "CatCafe_Woods_Gate", 30.0, 0.0),
    "sewer": ("CatCafe_Sewer_NightFence", "CatCafe_Sewer_Gate", 30.0, 0.0),
    # the arch has no Bars and hangs flower baskets in its opening, so its fence stands behind the posts and their
    # plinths (z 1.3), as wide as the arch: 36 inner plus two 2 stud posts
    "alley": ("CatCafe_Alley_NightFence", "CatCafe_Alley_ArchStreet", 40.0, 1.05),
}


def _star(glow, x, y, z, r):
    """A small star standing on the fence's front, its back at depth z."""
    glow.b.star(RB.p(x, y, z - 0.02), r, r * 0.45, 0.06, GLOW, rot=(1.5708, "X"))


def _fence(b, glow, x0, x1, dz=0.0, posts_every=4.5, end_studs=True):
    """Posts, pickets and two rails from x0 to x1, the pickets' front at Z_FRONT + dz. Each post carries a round
    glowing stud: a star costs 20 wedges in the Part export and the fences are cloned at every dusk. Without
    end_studs the two end posts go plain (behind the arch's posts, where a stud would sit inside them)."""
    zf, zb = Z_FRONT + dz, Z_BACK + dz
    n = max(1, round((x1 - x0 - POST) / posts_every))
    xs = [x0 + POST / 2 + (x1 - x0 - POST) * k / n for k in range(n + 1)]
    for i, x in enumerate(xs):
        b.span((x - POST / 2, 0, zf - 0.15), (x + POST / 2, HEIGHT + 0.3, zb + 0.1), POSTC)
        b.b.pyramid(RB.p(x, HEIGHT + 0.29, (zf + zb) / 2 - 0.025), POST + 0.1, 0.35, RAIL)
        if end_studs or 0 < i < n:
            glow.ball((x, HEIGHT - 0.6, zf - 0.23), 0.2, GLOW)           # half sunk in the post's front
    for a, c in zip(xs, xs[1:]):
        inner0, inner1 = a + POST / 2, c - POST / 2
        k = max(1, round((inner1 - inner0) / PLANK))
        w = (inner1 - inner0) / k
        for i in range(k):
            cx = inner0 + w * (i + 0.5)
            lo, hi = cx - w / 2 + 0.03, cx + w / 2 - 0.03          # a slim gap between pickets
            b.span((lo, 0, zf), (hi, HEIGHT, zb), BOARD)
            d = (w - 0.06) / 2 ** 0.5                                    # a diamond, half sunk: the point
            b.box((cx, HEIGHT, (zf + zb) / 2), (d, d, zb - zf - 0.02), BOARD, rot=rot_z(45))
        for y in (1.2, HEIGHT - 1.3):                                                    # rails on the front
            b.span((inner0 - 0.01, y, zf - 0.13), (inner1 + 0.01, y + 0.45, zf + 0.01), RAIL)
    return zf


# 5 x 7 letters for the gate signs: thinner strokes than the 3 x 5 GLYPHS, so CLOSED reads up close
GLYPHS7 = {
    "A": ("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
    "C": ("01110", "10001", "10000", "10000", "10000", "10001", "01110"),
    "D": ("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
    "I": ("111", "010", "010", "010", "010", "010", "111"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "N": ("10001", "11001", "11001", "10101", "10011", "10011", "10001"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "P": ("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
    "R": ("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
    "S": ("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
}


def text7_width(s, px):
    """Width of _text7(s) in studs, without the gap after the last letter (a space is 3 px)."""
    return (sum(len(GLYPHS7[ch][0]) + 1 if ch in GLYPHS7 else 3 for ch in s.upper()) - 1) * px


def _text7(b, s, cx, y, z, px, depth, swatch):
    """5 x 7 letters centred on x = cx, bottom at y, standing depth proud of a face at z toward -Z (read from -Z).
    Runs of pixels merge across rows into one block where they line up."""
    w = text7_width(s, px)
    cur = 0
    for ch in s.upper():
        g = GLYPHS7.get(ch)
        if g is None:
            cur += 3
            continue
        runs = []                                                      # (col, end, top row, rows)
        for row, bits in enumerate(g):
            col = 0
            while col < len(bits):
                if bits[col] != "1":
                    col += 1
                    continue
                end = col
                while end < len(bits) and bits[end] == "1":
                    end += 1
                above = next((r for r in runs if r[0] == col and r[1] == end and r[2] + r[3] == row), None)
                if above is not None:
                    above[3] += 1
                else:
                    runs.append([col, end, row, 1])
                col = end
        for col, end, top, rows in runs:
            xa, xb = cx + w / 2 - (cur + end) * px, cx + w / 2 - (cur + col) * px
            ya = y + (7 - top - rows) * px
            b.span((xa, ya, z - depth), (xb, ya + rows * px, z), swatch)
        cur += len(g[0]) + 1


def _crescent(glow, cx, cy, z, r, tilt=35.0, bite=0.5, n=10):
    """A thin crescent moon (a circle r with a circle 0.85 r bitten out, its centre bite * r toward tilt degrees),
    its horns toward the tilt, flat on the plane z (0.06 thick about it). Quads between the outer and the inner
    edge, so it reads as a moon and not as a letter C."""
    a = math.radians(tilt)
    ri, d = 0.85 * r, bite * r
    bx, by = cx + d * math.cos(a), cy + d * math.sin(a)
    # where the two circles cross, as angles about each centre
    xh = (d * d + r * r - ri * ri) / (2 * d)
    hh = math.sqrt(r * r - xh * xh)
    ao = math.atan2(hh, xh)                                            # about the moon's centre, from the tilt
    ai = math.atan2(hh, xh - d)                                        # about the bite's centre, from the tilt
    outer = [(cx + r * math.cos(a + ao + (2 * math.pi - 2 * ao) * k / n),
              cy + r * math.sin(a + ao + (2 * math.pi - 2 * ao) * k / n)) for k in range(n + 1)]
    inner = [(bx + ri * math.cos(a + ai + (2 * math.pi - 2 * ai) * k / n),
              by + ri * math.sin(a + ai + (2 * math.pi - 2 * ai) * k / n)) for k in range(n + 1)]
    for k in range(n):
        if k == 0:
            chain = [inner[1], outer[1]]
        elif k == n - 1:
            chain = [inner[k], outer[n]]
        else:
            chain = [inner[k], inner[k + 1], outer[k + 1]]
        glow.fan_z(z, outer[k], chain, 0.06, GLOW)
    return bx, by, ri


def _moon_sign(b, glow, zf, y=5.6, r=1.6):
    """A round night-blue badge with a glowing rim, a thin crescent moon and three stars in its bite, hung on the
    upper rail."""
    zs = zf - 0.13                                                     # the rail's front face
    b.cyl((0, y, zs - 0.055), r, 0.13, "night_sky", axis="Z", segments=16)
    glow.b.ring(RB.p(0, y, zs - 0.075), r + 0.08, 0.18, 0.16, GLOW, segments=16, bevel=False, rot=(1.5708, "X"))
    bx, by, ri = _crescent(glow, -0.25, y - 0.05, zs - 0.13, 1.0)
    for (dx, dy, s) in ((0.22, 0.2, 0.22), (0.62, -0.28, 0.14), (-0.08, -0.42, 0.12)):
        _star(glow, bx + dx, by + dy, zs - 0.12, s)


def _closed_board(b, glow, zf, y0=0.85, small="OPENS AT SUNRISE"):
    """The CLOSED board under the moon, on the lower rail: a dark plate, a glowing rim and thin 5 x 7 letters."""
    big, px, spx = "CLOSED", 0.2, 0.09
    w = max(text7_width(big, px), text7_width(small, spx)) + 0.9
    zs = zf - 0.13
    b.span((-w / 2, y0, zs - 0.12), (w / 2, y0 + 2.6, zs + 0.01), "night_sky")
    for (xa, xb, ya, yb) in ((-w / 2 - 0.12, w / 2 + 0.12, y0 - 0.12, y0), (-w / 2 - 0.12, w / 2 + 0.12, y0 + 2.6, y0 + 2.72),
                             (-w / 2 - 0.12, -w / 2, y0, y0 + 2.6), (w / 2, w / 2 + 0.12, y0, y0 + 2.6)):
        glow.span((xa, ya, zs - 0.14), (xb, yb, zs + 0.01), GLOW)
    _text7(glow, big, 0, y0 + 1.1, zs - 0.11, px, 0.05, INK)
    _text7(glow, small, 0, y0 + 0.38, zs - 0.11, spx, 0.05, GLOW)


def build_gate_fence(area, mat):
    name, _host, width, dz = GATES[area]
    b, glow = RB(), RB()
    half = width / 2 - 0.02                                            # clear of the pillars' inner faces
    zf = _fence(b, glow, -half, half, dz=dz, end_studs=area != "alley")
    _moon_sign(b, glow, zf)
    _closed_board(b, glow, zf)
    return [b.finalize(name, mat), glow.finalize(name + "_Moon_Bulb", mat)]


def build_segment(mat):
    name = "CatCafe_Alley_NightFenceSegment"
    b, glow = RB(), RB()
    zf = _fence(b, glow, -4.0, 4.0, dz=-(Z_FRONT + Z_BACK) / 2, posts_every=8.0)      # pickets centred on z 0
    zs = zf - 0.13                                                     # a small moon plaque on the upper rail
    y = HEIGHT - 1.3 + 0.22
    b.cyl((0, y, zs - 0.045), 0.75, 0.11, "night_sky", axis="Z", segments=12)
    _crescent(glow, -0.12, y - 0.03, zs - 0.12, 0.5, n=6)               # the gate signs' thin moon, fewer parts
    return [b.finalize(name, mat), glow.finalize(name + "_Moon_Bulb", mat)]


def build_back_door(mat):
    """A plank door shut in the back door opening (x -11..-5, 7.5 high, in the back wall z 14..15) with the sign
    hung on its alley side (+Z), where players in the back alley read it."""
    name = "CatCafe_Plot_BackDoorClosed"
    b, glow = RB(), RB()
    x0, x1, h = BACK_DOOR
    zi, zo = BACK - 0.6, BACK - 0.2                                    # the leaf, inside the 1 stud wall
    cx = (x0 + x1) / 2
    k = 6
    for i in range(k):                                                 # planks, a slim groove between them
        a = x0 + 0.01 + (x1 - x0 - 0.02) * i / k
        c = x0 + 0.01 + (x1 - x0 - 0.02) * (i + 1) / k
        b.span((a + 0.02, 0, zi), (c - 0.02, h - 0.01, zo), "caramel_wood")
    b.span((x0 + 0.01, 0, zi + 0.05), (x1 - 0.01, h - 0.05, zo - 0.05), "dark_wood")       # behind the grooves
    for y in (1.1, h - 1.5):                                           # braces on the alley side
        b.span((x0 + 0.3, y, zo - 0.01), (x1 - 0.3, y + 0.5, zo + 0.09), "dark_wood")
    b.span((x1 - 0.9, 3.4, zo - 0.01), (x1 - 0.5, 3.6, zo + 0.17), "metal")                # latch
    # the sign: a night-blue board hung from a nail by a string, CLOSED over UNTIL SUNRISE
    big, small, px, spx = "CLOSED", "UNTIL SUNRISE", 0.15, 0.07
    w = max(text_width(big, px), text_width(small, spx)) + 0.6
    y0, y1, nail = 3.2, 5.6, 6.36
    zs = zo + 0.09                                                     # the braces' face
    b.span((cx - w / 2, y0, zs - 0.01), (cx + w / 2, y1, zs + 0.11), "night_sky")
    for (xa, xb, ya, yb) in ((cx - w / 2 - 0.1, cx + w / 2 + 0.1, y0 - 0.1, y0), (cx - w / 2 - 0.1, cx + w / 2 + 0.1, y1, y1 + 0.1),
                             (cx - w / 2 - 0.1, cx - w / 2, y0, y1), (cx + w / 2, cx + w / 2 + 0.1, y0, y1)):
        b.span((xa, ya, zs - 0.01), (xb, yb, zs + 0.13), INK)
    b.span((cx - 0.06, nail - 0.06, zo + 0.05), (cx + 0.06, nail + 0.06, zo + 0.25), "metal")     # in the brace
    for sx in (-1, 1):                                                 # the string, from two top corners to the nail
        dx, dy = w / 4, nail - y1 - 0.1
        b.box((cx + sx * dx / 2, (y1 + 0.1 + nail) / 2, zs + 0.06), (0.05, math.hypot(dx, dy) + 0.05, 0.05), "fur_black",
              rot=rot_z(sx * math.degrees(math.atan2(dx, dy))))
    glow.b.crescent(RB.p(cx - 0.05, h - 0.62, zo + 0.02), 0.25, 0.16, 0.05, GLOW)          # on the door, over the brace
    label(glow, big, cx, y0 + 0.8, zs + 0.11, px, 0.04, INK, 1)
    label(glow, small, cx, y0 + 0.3, zs + 0.11, spx, 0.04, GLOW, 1)
    return [b.finalize(name, mat), glow.finalize(name + "_Sign_Bulb", mat)]


assert HEIGHT < BARS_TOP

ASSETS = {
    **{GATES[a][0]: ((lambda a: lambda mat: build_gate_fence(a, mat))(a), 6000) for a in GATES},
    "CatCafe_Alley_NightFenceSegment": (build_segment, 2000),
    "CatCafe_Plot_BackDoorClosed": (build_back_door, 2500),
}
HOSTS = {GATES[a][0]: GATES[a][1] for a in GATES}
