"""The camp stations (#1319, camp-stations.md): the Picnic Basket, Yard Sale and Fish Pond camp extras grown into
stations that read from across the camp, each solid, climbable and finished on every side, with a PromptAnchor for
its prompt card and a BangAnchor 2 studs over its sign for the owner's red "!" (UI/Components/ReadyBang).

  CatCafe_Camp_Park_PicnicStation     (#1133, section 2) a wooden picnic table with its benches on a red checked
                                      blanket, under a red and white checked parasol; on the table the wicker basket
                                      with a Money Potion peeking out, a teal thermos (Attachment Steam on its mouth),
                                      a mug and a plate of sandwiches; beside it a chalk A-frame sign reading PICNIC.
                                      Attachments: PromptAnchor (the table's front, 1.5 up), BangAnchor (2 over the
                                      sign), GlowAnchor (under the parasol, for VFX's ready glow, #1328), Steam.
  CatCafe_Camp_Neighbourhood_YardSaleStall (#1154, section 3) a folding table with a gingham cloth under a little
                                      pastel blue and white striped awning on four posts; on it cardboard boxes, the
                                      middle one holding the free zone crate with a FREE tag, a lamp, books, a teapot
                                      and a cash tin; boxes stacked on the rug; a hand-painted YARD SALE board nailed to
                                      a stake. Attachments: PromptAnchor (the table's front, 1.5 up), BangAnchor (2
                                      over the board), GlowAnchor (under the awning).

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


# ------------------------------------------------------------------------------------------ yard sale --
YARD = "CatCafe_Camp_Neighbourhood_YardSaleStall"
YT_X0, YT_X1, YT_Z0, YT_Z1, YT_H = -2.5, 2.5, -0.8, 0.8, 2.3   # the folding table
POST_X, POST_ZF, POST_ZB = 2.9, -1.35, 1.15                    # the awning's posts
AWN_F, AWN_B = 5.0, 5.5                                        # the canopy's front and back edge heights
YSIGN_X, YSIGN_Z = 4.0, -1.5                                   # the stake


def _cardboard_box(b, x, y, z, w, h, d, open_flaps=True):
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), "cardboard")
    b.span((x - w / 2, y + h, z - d / 2), (x + w / 2, y + h + 0.02, z - d / 2 + 0.04), "kibble")       # tape
    if open_flaps:
        b.box((x - w / 2 + 0.1, y + h + 0.15, z), (0.3, 0.04, d * 0.7), "cardboard", rot=_rz(-40))
        b.box((x + w / 2 - 0.1, y + h + 0.15, z), (0.3, 0.04, d * 0.7), "cardboard", rot=_rz(40))


def _rz(deg):
    from plot import rot_z
    return rot_z(deg)


def _yard_table(b):
    x0, x1, z0, z1, h = YT_X0, YT_X1, YT_Z0, YT_Z1, YT_H
    b.span((x0 - 0.6, 0, z0 - 0.7), (x1 + 0.6, 0.04, z1 + 0.5), "pastel_lilac")                 # rug
    b.span((x0 - 0.5, 0.04, z0 - 0.6), (x1 + 0.5, 0.06, z1 + 0.4), "blush")
    b.span((x0, h, z0), (x1, h + 0.1, z1), "offwhite")
    leg = math.hypot(h, 1.4)
    for x in (x0 + 0.3, x1 - 0.3):                                                              # X legs
        for sgn in (-1, 1):
            b.box((x + sgn * 0.06, h / 2 + 0.03, 0), (0.08, leg, 0.08), "metal",
                  rot=rot_x(sgn * math.degrees(math.atan2(1.4, h))))
        for zz in (-0.72, 0.72):
            b.span((x - 0.16, 0.06, zz - 0.08), (x + 0.16, 0.1, zz + 0.08), "fur_black")       # feet
    b.span((x0 + 0.1, h + 0.1, z0 - 0.02), (x1 - 0.1, h + 0.13, z1 - 0.3), "pastel_sky")       # gingham cloth
    b.span((x0 + 0.1, h - 0.45, z0 - 0.05), (x1 - 0.1, h + 0.13, z0 - 0.02), "pastel_sky")
    for k in range(11):
        cx = x0 + 0.35 + k * (x1 - x0 - 0.7) / 10
        b.span((cx - 0.09, h - 0.45, z0 - 0.07), (cx + 0.09, h + 0.1, z0 - 0.05), "offwhite")
    top = h + 0.13
    # the boxes: the middle one holds the free zone crate, with a FREE tag on its front
    _cardboard_box(b, -1.5, top, 0.0, 0.9, 0.6, 0.7)
    b.span((-1.85, top + 0.6, -0.2), (-1.15, top + 0.7, 0.2), "fur_pewter")                    # odds and ends
    _cardboard_box(b, 0.2, top, 0.0, 1.0, 0.6, 0.75)
    b.span((-0.18, top + 0.6, -0.27), (0.58, top + 0.98, 0.27), "rarity_rare")                 # the crate in it
    for dx in (-0.12, 0.32):
        b.span((0.2 + dx - 0.04, top + 0.6, -0.285), (0.2 + dx + 0.04, top + 0.99, 0.285), "dark_wood")   # bands
    b.span((-0.18, top + 0.1, -0.41), (0.58, top + 0.48, -0.375), "offwhite")                  # FREE tag
    _label_front(b, "FREE", 0.2, top + 0.17, -0.405, 0.045, 0.02, "bowl_red")
    # a lamp, books, a teapot and a cash tin
    b.cyl((1.75, top + 0.04, 0.35), 0.18, 0.08, "brass", segments=10)
    b.span((1.72, top + 0.08, 0.32), (1.78, top + 0.6, 0.38), "brass")
    b.cyl((1.75, top + 0.75, 0.35), 0.3, 0.35, "pastel_butter", segments=10)
    for k, sw in enumerate(("shirt_blue", "bowl_red", "mint")):
        b.span((-2.35 + 0.03 * k, top + 0.12 * k, 0.15), (-1.95 - 0.02 * k, top + 0.12 * (k + 1), 0.6), sw)
    b.ball((1.5, top + 0.18, -0.3), 0.2, "pastel_lilac", scale=(1, 0.85, 1))                    # teapot
    b.span((1.67, top + 0.2, -0.33), (1.83, top + 0.26, -0.27), "pastel_lilac")
    b.span((1.25, top + 0.12, -0.32), (1.33, top + 0.3, -0.28), "pastel_lilac")
    b.span((1.45, top + 0.33, -0.35), (1.55, top + 0.4, -0.25), "offwhite")
    b.span((0.95, top, 0.25), (1.3, top + 0.18, 0.55), "metal")                                 # cash tin
    # a stack of boxes on the rug at the -X end, under the awning
    _cardboard_box(b, x0 - 0.05, 0.06, 1.0, 0.8, 0.55, 0.6, open_flaps=False)
    _cardboard_box(b, x0 - 0.05, 0.63, 1.0, 0.7, 0.45, 0.55, open_flaps=False)


def _yard_awning(b):
    """Four white posts and a little pastel blue and white striped canopy sloping to the front, a scalloped valance."""
    for x in (-POST_X, POST_X):
        for z, top in ((POST_ZF, AWN_F), (POST_ZB, AWN_B)):
            b.span((x - 0.09, 0, z - 0.09), (x + 0.09, top, z + 0.09), "offwhite")
            b.span((x - 0.18, 0, z - 0.18), (x + 0.18, 0.12, z + 0.18), "fur_black")               # a foot
    n = 8
    w = 2 * POST_X + 0.5
    sw_w = w / n
    depth, rise = POST_ZB - POST_ZF + 0.5, AWN_B - AWN_F
    tilt = math.degrees(math.atan2(rise, depth))
    zc = (POST_ZF + POST_ZB) / 2
    for k in range(n):
        x = -w / 2 + sw_w * (k + 0.5)
        sw = ("pastel_sky", "offwhite")[k % 2]
        b.box((x, (AWN_F + AWN_B) / 2 + 0.06, zc), (sw_w, 0.1, math.hypot(depth, rise)), sw, rot=rot_x(-tilt))
        vz = POST_ZF - 0.32                                                                     # valance
        b.span((x - sw_w / 2, AWN_F - 0.35, vz - 0.04), (x + sw_w / 2, AWN_F + 0.03, vz + 0.04), sw)
        cy = AWN_F - 0.34
        arc = [(x + sw_w / 2 * math.cos(math.radians(a)), cy + sw_w / 2 * math.sin(math.radians(a)))
               for a in (180, 240, 300, 360)]
        b.fan_z(vz, (x, cy), arc, 0.08, sw)


def _yard_sign(b):
    """A hand-painted YARD SALE board nailed to a stake, its painted face toward -Z. Returns its top (Roblox)."""
    x, z = YSIGN_X, YSIGN_Z
    b.span((x - 0.08, 0, z - 0.08), (x + 0.08, 3.4, z + 0.08), DARK)                             # the stake
    y0, y1 = 2.0, 3.25
    b.span((x - 0.8, y0, z - 0.14), (x + 0.8, y1, z - 0.08), "cardboard")                       # the board
    b.span((x - 0.84, y0 - 0.04, z - 0.12), (x + 0.84, y1 + 0.04, z - 0.1), "kibble")           # its torn edge
    _label_front(b, "YARD", x, y0 + 0.7, z - 0.14, 0.075, 0.02, "bowl_red")
    _label_front(b, "SALE", x, y0 + 0.2, z - 0.14, 0.075, 0.02, "bowl_red")
    for nx in (-0.6, 0.6):
        b.span((x + nx - 0.03, y1 - 0.15, z - 0.17), (x + nx + 0.03, y1 - 0.09, z - 0.12), "metal")   # nails
    return (x, y1 + 0.04, z - 0.11)


def build_yardsale_stall(mat):
    b = RB()
    _yard_table(b)
    _yard_awning(b)
    top = _yard_sign(b)
    _anchor(YARD, "PromptAnchor", (0.0, 1.5, YT_Z0 - 1.1))
    _anchor(YARD, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    _anchor(YARD, "GlowAnchor", (0.0, AWN_F - 0.5, (POST_ZF + POST_ZB) / 2))
    return [b.finalize(YARD, mat)]


def rbx_attachments(name):
    seen = {}
    for n, p in ATTACHMENTS.get(name, []):
        seen[n] = p                                       # a rebuild in the same run replaces, never duplicates
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in seen.items()]


ASSETS = {
    PIC: (build_picnic_station, 4000),
    YARD: (build_yardsale_stall, 4000),
}
