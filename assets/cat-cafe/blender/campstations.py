"""The camp stations (#1319, camp-stations.md): the Picnic Basket, Yard Sale and Fish Pond camp extras grown into
stations that read from across the camp, each solid, climbable and finished on every side, with a PromptAnchor for
its prompt card and a BangAnchor 2 studs over its sign for the owner's red "!" (UI/Components/ReadyBang).

  CatCafe_Camp_Park_PicnicStation     (#1133, section 2) a wooden picnic table with its benches on a red checked
                                      blanket, under a red and white checked parasol; on the table the wicker basket
                                      with a Money Potion peeking out, a teal thermos (Attachment Steam on its mouth),
                                      a mug and a plate of sandwiches; beside it a chalk A-frame sign reading PICNIC.
                                      Attachments: PromptAnchor (the table's front, 1.5 up), BangAnchor (2 over the
                                      sign), GlowAnchor (under the parasol, for VFX's ready glow, #1328), Steam.

Every model: pivot at the base centre on the camp's ground, front -Z, no turn of its own, placed where its camp extra
stands (Layout.campExtras, the area's set space) so Gameplay only swaps the asset name.
"""

import math

from mathutils import Matrix, Vector

from cannon import frame_at
from campextras import gold_fish
from common import RB, text_width
from plot import rot_x

ATTACHMENTS = {}        # asset -> [(name, Roblox point)]
WOOD, DARK = "caramel_wood", "dark_wood"


def _anchor(name, att, p):
    ATTACHMENTS.setdefault(name, []).append((att, p))


def _tri(b, p0, p1, p2, t, swatch):
    """One flat triangle t thick through three Roblox points (a fan wedge in its own plane), for sloped panels."""
    P0, P1, P2 = (Vector(RB.p(*p)) for p in (p0, p1, p2))
    e1 = (P1 - P0).normalized()
    n = e1.cross(P2 - P0).normalized()
    e2 = n.cross(e1)
    M = Matrix((e1, e2, n)).transposed()                       # columns e1, e2, n
    a = (P1 - P0)
    c = (P2 - P0)
    b.b.fan(tuple(P0), (0.0, 0.0), [(a.dot(e1), 0.0), (c.dot(e1), c.dot(e2))], t, swatch, rot=M)


def _label_front(b, s, cx, y, z, px, depth, swatch):
    """Block letters centred on x = cx, bottom at y, on a face at depth z, read from -Z."""
    w = text_width(s, px)
    b.text(s, (cx + w / 2, y, z), px, depth, swatch, right=(-1, 0, 0))


# --------------------------------------------------------------------------------------------- picnic --
PIC = "CatCafe_Camp_Park_PicnicStation"
TOP_W, TOP_D, TOP_Y = 4.8, 2.4, 2.5          # the table top: length (x), depth, top
SEAT_Z, SEAT_Y, SEAT_D = 1.95, 1.45, 0.8     # the benches' centres (z +-), top, depth
POLE_TOP, CAN_R, CAN_RIM = 7.2, 3.7, 6.0     # the parasol: apex, radius, rim height
SEGS = 12
SIGN_X, SIGN_Z = 4.15, -2.2                  # the A-frame's foot centre


def _picnic_table(b):
    for k in range(5):                                                                      # top planks
        z0 = -TOP_D / 2 + k * TOP_D / 5
        b.span((-TOP_W / 2, TOP_Y - 0.16, z0 + 0.02), (TOP_W / 2, TOP_Y, z0 + TOP_D / 5 - 0.02), WOOD)
    b.span((-TOP_W / 2 + 0.3, TOP_Y - 0.3, -TOP_D / 2 + 0.1), (TOP_W / 2 - 0.3, TOP_Y - 0.15, TOP_D / 2 - 0.1), DARK)
    for sz in (-1, 1):                                                                      # benches
        for k in range(2):
            z0 = sz * SEAT_Z - SEAT_D / 2 + k * SEAT_D / 2
            b.span((-TOP_W / 2, SEAT_Y - 0.14, z0 + 0.02), (TOP_W / 2, SEAT_Y, z0 + SEAT_D / 2 - 0.02), WOOD)
    for x in (-TOP_W / 2 + 0.55, TOP_W / 2 - 0.55):                                         # A-frame legs
        b.span((x - 0.12, SEAT_Y - 0.3, -SEAT_Z - SEAT_D / 2), (x + 0.12, SEAT_Y - 0.14, SEAT_Z + SEAT_D / 2), DARK)
        for sz in (-1, 1):
            foot_z, top_z = sz * (SEAT_Z + 0.2), sz * 0.55
            L = math.hypot(foot_z - top_z, TOP_Y - 0.3)
            ang = math.degrees(math.atan2(top_z - foot_z, TOP_Y - 0.3))      # leaning in toward the top: an A
            b.box((x, (TOP_Y - 0.3) / 2, (foot_z + top_z) / 2), (0.2, L + 0.1, 0.2), DARK, rot=rot_x(ang))
    # the parasol pole through the middle of the top, on a weighted base under the table
    b.cyl((0, 0.12, 0), 0.5, 0.24, "metal", segments=10)
    b.cyl((0, POLE_TOP / 2 + 0.1, 0), 0.07, POLE_TOP - 0.2, "offwhite", segments=8)


def _parasol(b):
    """A checked canopy: SEGS panels from the apex to the rim, each split at half way into an inner and an outer
    piece of opposite colours, so the checks alternate round and down; a scalloped edge and a finial."""
    cols = ("bowl_red", "offwhite")
    apex = (0.0, POLE_TOP, 0.0)
    rim = [(CAN_R * math.cos(2 * math.pi * k / SEGS), CAN_RIM, CAN_R * math.sin(2 * math.pi * k / SEGS))
           for k in range(SEGS + 1)]
    mid = [tuple((a + r) / 2 for a, r in zip(apex, p)) for p in rim]
    t = 0.08
    for k in range(SEGS):
        c0, c1 = cols[k % 2], cols[(k + 1) % 2]
        _tri(b, apex, mid[k + 1], mid[k], t, c0)                 # wound so the panel faces up and out
        _tri(b, mid[k], mid[k + 1], rim[k + 1], t, c1)
        _tri(b, mid[k], rim[k + 1], rim[k], t, c1)
        cx, cz = (rim[k][0] + rim[k + 1][0]) / 2, (rim[k][2] + rim[k + 1][2]) / 2   # a scallop under each panel
        ang = math.degrees(math.atan2(cz, cx))
        b.box((cx * 0.99, CAN_RIM - 0.17, cz * 0.99), (0.12, 0.3, 2 * CAN_R * math.sin(math.pi / SEGS) * 0.95), c0,
              rot=Matrix.Rotation(math.radians(-ang), 3, "Y"))
    b.ball((0, POLE_TOP + 0.12, 0), 0.16, "bowl_red")
    for k in range(SEGS // 2):                                    # ribs under the canopy, from the pole to the rim
        p = rim[2 * k]
        L = math.hypot(p[0], p[2])
        drop = POLE_TOP - CAN_RIM
        mx, mz = p[0] / 2, p[2] / 2
        ang = math.degrees(math.atan2(p[2], p[0]))
        tilt = math.degrees(math.atan2(drop, L))
        b.box((mx, (POLE_TOP + CAN_RIM) / 2 - 0.1, mz), (math.hypot(L, drop), 0.05, 0.05), "offwhite",
              rot=Matrix.Rotation(math.radians(-ang), 3, "Y") @ Matrix.Rotation(math.radians(-tilt), 3, "Z"))


def _blanket(b):
    W, D = 7.0, 5.6
    b.span((-W / 2, 0, -D / 2), (W / 2, 0.04, D / 2), "offwhite")
    nx, nz = 10, 8
    for i in range(nx):
        for j in range(nz):
            if (i + j) % 2 == 0:
                x0, z0 = -W / 2 + i * W / nx, -D / 2 + j * D / nz
                b.span((x0, 0.04, z0), (x0 + W / nx, 0.06, z0 + D / nz), "bowl_red")


def _on_table(b):
    y = TOP_Y
    bx, bz = -1.3, 0.25                                                                     # the basket
    b.span((bx - 0.75, y, bz - 0.45), (bx + 0.75, y + 0.8, bz + 0.45), WOOD)
    for dy in (0.3, 0.58):
        b.span((bx - 0.78, y + dy, bz - 0.48), (bx + 0.78, y + dy + 0.08, bz + 0.48), "kibble")
    b.span((bx - 0.79, y + 0.8, bz - 0.49), (bx + 0.79, y + 0.88, bz + 0.49), DARK)
    b.span((bx - 0.66, y + 0.88, bz - 0.36), (bx + 0.05, y + 0.98, bz + 0.36), "blush")    # the cloth
    b.span((bx, y + 0.88, bz - 0.49), (bx + 0.79, y + 0.95, bz + 0.49), WOOD)             # the closed half lid
    b.span((bx - 0.79, y + 0.88, bz + 0.42), (bx, y + 1.6, bz + 0.5), WOOD)               # the open half
    for x in (bx - 0.55, bx + 0.55):
        b.span((x - 0.04, y + 0.95, bz - 0.04), (x + 0.04, y + 1.45, bz + 0.04), DARK)
    b.span((bx - 0.59, y + 1.45, bz - 0.04), (bx + 0.59, y + 1.53, bz + 0.04), DARK)
    px, pz = bx - 0.35, bz - 0.05                                                           # the Money Potion
    b.cyl((px, y + 1.08, pz), 0.17, 0.32, "gold_light", segments=10)
    b.cyl((px, y + 1.31, pz), 0.07, 0.14, "glass", segments=8)
    b.cyl((px, y + 1.42, pz), 0.08, 0.08, "kibble", segments=8)
    tx, tz = 1.45, 0.45                                                                     # thermos: Steam
    b.cyl((tx, y + 0.42, tz), 0.22, 0.84, "sign_teal", segments=12)
    b.cyl((tx, y + 0.9, tz), 0.24, 0.12, "cream", segments=12)
    b.cyl((tx, y + 0.99, tz), 0.12, 0.06, "fur_black", segments=10)
    _anchor(PIC, "Steam", (tx, y + 1.05, tz))
    b.cyl((1.95, y + 0.15, -0.2), 0.16, 0.3, "cream", segments=10)                         # mug
    b.cyl((1.95, y + 0.31, -0.2), 0.12, 0.02, "choco", segments=10)
    b.span((2.11, y + 0.06, -0.23), (2.19, y + 0.24, -0.17), "cream")
    b.cyl((0.4, y + 0.025, -0.45), 0.5, 0.05, "offwhite", segments=14)                     # sandwiches
    for sx, sz in ((0.2, -0.55), (0.6, -0.3)):
        yy = y + 0.05
        b.span((sx - 0.22, yy, sz - 0.2), (sx + 0.22, yy + 0.08, sz + 0.2), "treat_tan")
        b.span((sx - 0.24, yy + 0.08, sz - 0.22), (sx + 0.24, yy + 0.12, sz + 0.22), "pastel_butter")
        b.span((sx - 0.2, yy + 0.12, sz - 0.18), (sx + 0.2, yy + 0.15, sz + 0.18), "leaf_green")
        b.span((sx - 0.22, yy + 0.15, sz - 0.2), (sx + 0.22, yy + 0.23, sz + 0.2), "treat_tan")
    b.cyl((-0.3, y + 0.09, -0.75), 0.3, 0.18, "pastel_sky", segments=12)                   # fish crackers
    for k in range(4):
        a = k * 1.6
        gold_fish(b, -0.3 + 0.12 * math.cos(a), y + 0.18 + 0.02 * k, -0.75 + 0.11 * math.sin(a), 0.55)


def _a_frame(b):
    """The chalk A-frame sign reading PICNIC, its chalk face toward -Z, a red check band over the word."""
    lean = 12
    R, Rb = rot_x(lean), rot_x(-lean)
    H, W = 2.4, 1.6
    back_foot = (SIGN_X, 0.0, SIGN_Z + 2 * H * math.sin(math.radians(lean)))

    def at(p, Rm=R, base=(SIGN_X, 0.0, SIGN_Z)):
        v = Rm @ Vector(p)
        return (base[0] + v.x, base[1] + v.y, base[2] + v.z)

    b.box(at((0, H / 2, 0)), (W, H, 0.1), WOOD, rot=R)
    b.box(at((0, H / 2, 0), Rm=Rb, base=back_foot), (W, H, 0.1), WOOD, rot=Rb)
    b.box(at((0, H / 2 - 0.1, -0.06)), (W - 0.2, H - 0.45, 0.03), "fur_black", rot=R)   # chalk
    for k in range(6):                                                                    # the check band
        b.box(at((-W / 2 + 0.13 + (k + 0.5) * (W - 0.26) / 6, H - 0.4, -0.065)), ((W - 0.26) / 6, 0.2, 0.025),
              ("bowl_red", "offwhite")[k % 2], rot=R)
    px = 0.05
    w = text_width("PICNIC", px)
    o = at((w / 2, H / 2 + 0.25, -0.075))
    b.text("PICNIC", o, px, 0.02, "offwhite", right=tuple(R @ Vector((-1, 0, 0))), up=tuple(R @ Vector((0, 1, 0))))
    for p, s in (((-0.3, 0.75, -0.08), (0.36, 0.08, 0.02)), ((-0.3, 0.6, -0.08), (0.08, 0.25, 0.02)),   # a mug
                 ((0.3, 0.7, -0.08), (0.4, 0.3, 0.02))):                                              # a sandwich
        b.box(at(p), s, "offwhite", rot=R)
    gap = back_foot[2] - SIGN_Z
    b.box((SIGN_X, 0.6, SIGN_Z + gap / 2), (W - 0.1, 0.06, gap - 0.12), DARK)               # the stay
    top = at((0, H, 0))
    return top


def build_picnic_station(mat):
    b = RB()
    _blanket(b)
    _picnic_table(b)
    _parasol(b)
    _on_table(b)
    top = _a_frame(b)
    _anchor(PIC, "PromptAnchor", (0.0, 1.5, -SEAT_Z - SEAT_D / 2 - 0.6))
    _anchor(PIC, "BangAnchor", (SIGN_X, top[1] + 2.0, top[2]))
    _anchor(PIC, "GlowAnchor", (0.0, CAN_RIM - 0.4, 0.0))
    return [b.finalize(PIC, mat)]


def rbx_attachments(name):
    seen = {}
    for n, p in ATTACHMENTS.get(name, []):
        seen[n] = p                                       # a rebuild in the same run replaces, never duplicates
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in seen.items()]


ASSETS = {
    PIC: (build_picnic_station, 4000),
}
