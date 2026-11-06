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
  CatCafe_Camp_Woods_FishingHut       (#1232, section 4) a small wooden fishing hut with a pitched roof on a deck on
                                      stilts over the back of a stone-ringed pond, reached by a plank jetty; a FISH POND
                                      sign on the roof's front slope, a lantern by the door, a rod rack, a bucket of
                                      golden fish and a rod in its holder with its line in the water; lily pads, reeds.
                                      Child Models `_Water` (see-through), `_Rod` (pivot at its butt), `_Fish` (pivot at
                                      its middle, under the water). Attachments: FishJump (the water over the fish),
                                      PromptAnchor (the jetty's foot, 1.5 up), BangAnchor (2 over the sign), GlowAnchor
                                      (in the doorway). `_Gold` is the Golden Pond pass look: gold trim, sign frame,
                                      ridge and gold lily pads, the same parts and attachments.
  CatCafe_Camp_Sewer_LostFoundBooth   (#1732, section 4b) a little lost-property kiosk built into a bit of brick camp
                                      wall: a teal counter window under a red and white striped awning, a brass desk
                                      bell on the counter (`_Bell`, pivot at its base), shelves of odd finds behind (a
                                      teddy bear, one boot, a lamp, a cat bed, a duck, a mitten, parcels, each tagged)
                                      and an umbrella in the corner; a LOST & FOUND board on the roof ringed with
                                      bulbs (`_Bulb`, one `_Blink_Bulb`), and the old dripping pipe up the wall and
                                      over the roof. Attachments: PromptAnchor (the counter's front, 1.5 up),
                                      BangAnchor (2 over the sign), Drip (the pipe's mouth).

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


# --------------------------------------------------------------------------------------------- fishing hut --
HUT = "CatCafe_Camp_Woods_FishingHut"
PA, PC, PZ = 3.3, 2.5, 0.6                      # the pond's half axes (x, z) and its centre z
JY = 0.5                                        # the jetty's and the hut deck's top
DECK = (-1.7, 1.7, 0.9, 3.0)                    # the hut's deck over the back of the pond: x0, x1, z0, z1
HUT_W, HUT_D, HUT_H = 2.9, 1.8, 2.9             # the hut on it: width, depth, walls' height above the deck
RIDGE = 1.3                                     # the roof's rise above the walls


def _pond(b, water, gold):
    b.ball((0, 0.1, PZ), 1.0, "pants_navy", scale=(PA, 0.06, PC))                               # its deep bottom
    water.ball((0, 0.22, PZ), 1.0, "fish_blue", scale=(PA - 0.05, 0.06, PC - 0.05))
    stones = ("paving_grout", "fur_ash", "concrete", "fur_pewter")
    n = 20
    for k in range(n):
        a = 2 * math.pi * k / n
        if abs(a - 1.5 * math.pi) < 0.3:                                                         # the jetty's gap
            continue
        r = 0.55 + 0.07 * ((k * 7) % 3)
        b.ball(((PA + 0.15) * math.cos(a), 0.12, PZ + (PC + 0.15) * math.sin(a)), r, stones[k % 4],
               scale=(1.0, 0.62, 0.9))
    pad = "gold_mid" if gold else "leaf_green"
    for (lx, lz, r, flower) in ((-2.1, -0.4, 0.4, True), (-1.4, -1.2, 0.3, False), (2.2, -0.6, 0.36, False),
                                (1.4, -1.4, 0.3, True)):
        b.cyl((lx, 0.29, PZ + lz), r, 0.03, pad, segments=10)                                   # lily pads
        b.span((lx + 0.1 - 0.025, 0.08, PZ + lz - 0.025), (lx + 0.1 + 0.025, 0.28, PZ + lz + 0.025), "leaf_dark")
        if flower:
            b.span((lx - 0.08, 0.3, PZ + lz - 0.08), (lx + 0.08, 0.42, PZ + lz + 0.08),
                   "gold_light" if gold else "nose_pink")
            b.span((lx - 0.04, 0.42, PZ + lz - 0.04), (lx + 0.04, 0.47, PZ + lz + 0.04), "pastel_butter")
    for k, (rx, rz, h) in enumerate(((-2.9, 1.9, 1.5), (-2.6, 2.3, 1.2), (-3.2, 1.4, 1.1), (2.8, 2.0, 1.3),
                                     (3.1, 1.5, 1.0), (2.5, 2.4, 1.6))):
        sc = math.hypot(rx / (PA + 0.15), (rz) / (PC + 0.15))                                   # rooted in the stones
        rx, rz = rx / sc, rz / sc
        b.span((rx - 0.04, 0.0, PZ + rz - 0.04), (rx + 0.04, 0.2 + h, PZ + rz + 0.04), "leaf_dark")   # reeds
        if k % 2 == 0:
            b.span((rx - 0.07, 0.2 + h - 0.35, PZ + rz - 0.07), (rx + 0.07, 0.2 + h - 0.05, PZ + rz + 0.07),
                   "choco")


def _jetty(b):
    """Planks on stringers from the bank (z -3.6) out to the hut's deck, on posts."""
    z0, z1 = -3.6, DECK[2]
    for x in (-0.5, 0.5):
        b.span((x - 0.07, JY - 0.16, z0), (x + 0.07, JY, z1), DARK)
        for z in (z0 + 0.25, (z0 + z1) / 2, z1 - 0.25):
            b.span((x - 0.09, 0.0, z - 0.09), (x + 0.09, JY - 0.16, z + 0.09), DARK)
    k, z = 0, z0
    while z + 0.34 <= z1 + 1e-6:
        b.span((-0.7, JY, z), (0.7, JY + 0.09, z + 0.34), WOOD if k % 2 else "kibble")
        z += 0.36
        k += 1


def _hut(b, gold):
    x0, x1, z0, z1 = DECK
    trim = "gold_mid" if gold else "offwhite"
    for x in (x0 + 0.15, x1 - 0.15):                                                            # stilts
        for z in (z0 + 0.15, z1 - 0.15):
            b.span((x - 0.12, 0.0, z - 0.12), (x + 0.12, JY - 0.12, z + 0.12), DARK)
    b.span((x0, JY - 0.12, z0), (x1, JY + 0.09, z1), WOOD)                                       # the deck
    for k in range(int((x1 - x0) / 0.38)):
        x = x0 + 0.19 + k * 0.38
        b.span((x - 0.015, JY + 0.09, z0 + 0.02), (x + 0.015, JY + 0.1, z1 - 0.02), DARK)        # board lines
    y0 = JY + 0.09
    hz0, hz1 = z1 - 0.1 - HUT_D, z1 - 0.1                                                       # the hut, at the back
    hw = HUT_W / 2
    t = 0.14
    b.span((-hw, y0, hz1 - t), (hw, y0 + HUT_H, hz1), WOOD)                                      # back wall
    for sx in (-1, 1):                                                                          # side walls
        xa, xb = sorted((sx * hw, sx * (hw - t)))
        b.span((xa, y0, hz0), (xb, y0 + HUT_H, hz1 - t), WOOD)
    # front wall either side of the doorway, and over it
    dw, dh = 1.2, 2.2
    for xa, xb in ((-hw, -dw / 2), (dw / 2, hw)):
        b.span((xa, y0, hz0), (xb, y0 + HUT_H, hz0 + t), WOOD)
    b.span((-dw / 2, y0 + dh, hz0), (dw / 2, y0 + HUT_H, hz0 + t), WOOD)
    for xa, xb in ((-dw / 2 - 0.1, -dw / 2 + 0.04), (dw / 2 - 0.04, dw / 2 + 0.1)):              # door frame,
        b.span((xa, y0, hz0 - 0.04), (xb, y0 + dh + 0.1, hz0 + t + 0.01), trim)                 # a hair into the
    b.span((-dw / 2 - 0.1, y0 + dh - 0.04, hz0 - 0.04), (dw / 2 + 0.1, y0 + dh + 0.1, hz0 + t + 0.01), trim)   # opening
    for sx in (-1, 1):                                                                          # plank lines
        for k in range(3):
            x = sx * (dw / 2 + 0.25 + k * 0.28)
            b.span((x - 0.02, y0 + 0.1, hz0 - 0.015), (x + 0.02, y0 + HUT_H - 0.1, hz0 + 0.01), DARK)
    b.span((-hw - 0.05, y0, hz0 - 0.05), (hw + 0.05, y0 + 0.12, hz1 + 0.05), DARK)              # a sill round it
    # a pitched roof (ridge along x), its gable ends filled, a trim board on the front edge
    yt = y0 + HUT_H
    over = 0.35
    run = HUT_D / 2 + over
    slope = math.hypot(run, RIDGE)
    ang = math.degrees(math.atan2(RIDGE, run))
    zc = (hz0 + hz1) / 2
    for sz in (-1, 1):
        b.box((0, yt + RIDGE / 2 - 0.02, zc + sz * run / 2), (HUT_W + 2 * over, 0.14, slope + 0.05),
              "fur_charcoal", rot=rot_x(sz * ang))
    for sx in (-1, 1):                                                                          # the gables: a
        x = sx * (hw - t / 2)                                                                   # triangle each end,
        _tri(b, (x, yt - 0.01, hz0 + 0.02), (x, yt - 0.01, hz1 - 0.02), (x, yt + RIDGE - 0.08, zc), t, WOOD)   # under the roof
    b.span((-hw - over - 0.03, yt + RIDGE - 0.05, zc - 0.1), (hw + over + 0.03, yt + RIDGE + 0.12, zc + 0.1), trim)  # ridge
    # the FISH POND sign standing on the roof's front slope, its face toward -Z
    sy0 = yt + 0.25
    sz_ = hz0 - over * 0.5
    b.span((-1.15, sy0, sz_ - 0.06), (1.15, sy0 + 0.75, sz_ + 0.06), "cream")
    frame = "gold_mid" if gold else DARK
    for (xa, xb, ya, yb) in ((-1.25, 1.25, sy0 - 0.08, sy0 + 0.01), (-1.25, 1.25, sy0 + 0.74, sy0 + 0.83),
                             (-1.25, -1.14, sy0, sy0 + 0.75), (1.14, 1.25, sy0, sy0 + 0.75)):
        b.span((xa, ya, sz_ - 0.08), (xb, yb, sz_ + 0.08), frame)
    _label_front(b, "FISH POND", 0, sy0 + 0.22, sz_ - 0.06, 0.06, 0.02, "fish_blue")
    for sx in (-1, 1):                                                                          # its legs on the roof
        b.span((sx * 0.8 - 0.05, yt - 0.1, sz_ - 0.04), (sx * 0.8 + 0.05, sy0, sz_ + 0.04), frame)
    # a lantern by the door, the rod rack against the left wall and a stool inside
    b.span((dw / 2 + 0.25, y0 + 1.9, hz0 - 0.25), (dw / 2 + 0.31, y0 + 2.0, hz0 + 0.01), "fur_black")
    b.cyl((dw / 2 + 0.28, y0 + 1.7, hz0 - 0.25), 0.11, 0.3, "lamp_warm", segments=8)
    b.cyl((dw / 2 + 0.28, y0 + 1.88, hz0 - 0.25), 0.13, 0.06, "fur_black", segments=8)
    rx = -hw                                                                                    # against the wall
    b.span((rx - 0.08, y0, hz0 + 0.2), (rx, y0 + 0.2, hz1 - 0.3), DARK)                          # rack foot
    b.span((rx - 0.08, y0 + 1.6, hz0 + 0.2), (rx, y0 + 1.75, hz1 - 0.3), DARK)                   # rack bar
    for k, sw in enumerate(("fur_black", "shirt_blue", "bowl_red")):
        z = hz0 + 0.4 + k * 0.4
        b.box((rx - 0.1, y0 + 1.3, z), (0.05, 2.6, 0.05), sw, rot=rot_x(6 - 4 * k))               # rods
    return (0.0, sy0 + 0.83, sz_)


def build_fishing_hut(mat, gold=False):
    name = HUT + ("_Gold" if gold else "")
    b, water, rod, fish = RB(), RB(), RB(), RB()
    _pond(b, water, gold)
    _jetty(b)
    top = _hut(b, gold)
    # a bucket of golden fish on the jetty
    bz = -2.4
    b.cyl((-0.35, JY + 0.09 + 0.18, bz), 0.24, 0.36, "metal", segments=12)
    b.cyl((-0.35, JY + 0.09 + 0.3675, bz), 0.2, 0.015, "fish_blue", segments=12)
    gold_fish(b, -0.41, JY + 0.47, bz - 0.03, 0.9, up=True)
    gold_fish(b, -0.27, JY + 0.44, bz + 0.07, 0.8, up=True)
    # the rod holder at the jetty's side, the rod in it (pivot at its butt) leaning out over the water to the +X
    hx, hz = 0.6, -0.6
    b.span((hx - 0.08, JY + 0.09, hz - 0.08), (hx + 0.08, JY + 0.5, hz + 0.08), DARK)
    butt = (hx, JY + 0.5, hz)
    L, ang = 2.6, 50.0
    dy, dz = L * math.cos(math.radians(ang)), L * math.sin(math.radians(ang))
    R = Matrix.Rotation(math.radians(-90), 3, "Y")                     # the rod leans toward +X, out over the pond
    def turned(p):
        v = R @ Vector(p)
        return (v.x, v.y, v.z)
    rod.box(turned((0, dy / 2, dz / 2)), (0.06, L, 0.06), "fur_black", rot=R @ rot_x(ang))
    rod.box(turned((0, 0.235 * math.cos(math.radians(ang)), 0.235 * math.sin(math.radians(ang)))), (0.1, 0.53, 0.1),
            "kibble", rot=R @ rot_x(ang))
    by = 0.3 - butt[1]
    tip = turned((0, dy, dz))
    rod.span((tip[0] - 0.012, by, tip[2] - 0.012), (tip[0] + 0.012, tip[1], tip[2] + 0.012), "offwhite")   # line
    rod.ball((tip[0], by, tip[2]), 0.07, "bowl_red")                                                # bobber
    fx, fz = -1.3, PZ - 0.9                                                                         # the fish
    fish.span((-0.22, -0.06, -0.07), (0.16, 0.06, 0.07), "fur_orange")
    fish.span((0.16, -0.09, -0.03), (0.3, 0.09, 0.03), "fur_orange_dark")
    _anchor(name, "FishJump", (fx, 0.3, fz))
    _anchor(name, "PromptAnchor", (0.0, 1.5, -3.6 - 0.6))
    _anchor(name, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    _anchor(name, "GlowAnchor", (0.0, JY + 2.0, DECK[2] - 0.1 - HUT_D / 2))
    return [b.finalize(name, mat), water.finalize(name + "_Water", mat),
            rod.finalize(name + "_Rod", mat, location=butt),
            fish.finalize(name + "_Fish", mat, location=(fx, 0.16, fz))]


# --------------------------------------------------------------------------------------------- lost and found --
LOST = "CatCafe_Camp_Sewer_LostFoundBooth"
KX, KZ0, KZ1 = 2.8, -0.8, 1.0                   # the kiosk: half width, front, back (against the wall)
CTR_Y, WIN_TOP, ROOF_Y = 2.0, 4.3, 4.8          # the counter's top, the window's top, the roof's underside
WALL_X, WALL_Z0, WALL_Z1, WALL_Y = 3.6, 1.0, 1.6, 5.6      # the brick wall section it is built into
LAWN_F, LAWN_B = 4.15, 4.7                      # the awning's front and back edge heights
AWN_Z = -1.95                                   # the awning's front edge
SIGN_Y0, SIGN_Y1, SIGN_Z = 5.15, 6.65, -0.85    # the sign board's bottom, top and face
PIPE_X, PIPE_Z, PIPE_TOP, PIPE_MOUTH = 3.2, 0.72, 7.25, 1.2
KIOSK, TRIM = "sign_teal", "offwhite"


def _label_back(b, s, cx, y, z, px, depth, swatch):
    """Block letters centred on x = cx, bottom at y, on a face at depth z, read from +Z."""
    w = text_width(s, px)
    b.text(s, (cx - w / 2, y, z), px, depth, swatch, right=(1, 0, 0))


def _lost_wall(b):
    """The bit of camp wall the kiosk is built into: brick between two concrete piers under a coping."""
    b.span((-WALL_X, 0, WALL_Z0), (WALL_X, WALL_Y, WALL_Z1), "brick")
    b.span((-WALL_X, WALL_Y, WALL_Z0 - 0.05), (WALL_X, WALL_Y + 0.2, WALL_Z1 + 0.05), "concrete")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * WALL_X, sx * (WALL_X + 0.5)))
        b.span((x0, 0, WALL_Z0 - 0.1), (x1, WALL_Y + 0.4, WALL_Z1 + 0.1), "concrete")
        b.span((x0 - 0.05, WALL_Y + 0.4, WALL_Z0 - 0.15), (x1 + 0.05, WALL_Y + 0.55, WALL_Z1 + 0.15),
               "concrete_dark")
    for k in range(1, 9):                                                                       # mortar courses
        y = k * WALL_Y / 9
        b.span((-WALL_X, y - 0.03, WALL_Z1), (WALL_X, y + 0.03, WALL_Z1 + 0.015), "concrete")
    b.span((-1.2, 2.0, WALL_Z1 + 0.015), (0.2, 3.8, WALL_Z1 + 0.03), "offwhite")               # a FOUND! poster
    _label_back(b, "FOUND!", -0.5, 3.05, WALL_Z1 + 0.03, 0.045, 0.02, "bowl_red")
    for (px, pz) in ((-1.1, 3.7), (0.1, 3.7)):
        b.span((px - 0.03, pz - 0.03, WALL_Z1 + 0.03), (px + 0.03, pz + 0.03, WALL_Z1 + 0.045), "metal")
    b.span((-1.0, 2.3, WALL_Z1 + 0.03), (0.0, 2.85, WALL_Z1 + 0.04), "fur_ginger")             # a cat on it


def _lost_kiosk(b):
    """The kiosk: teal sides and fascia, a panelled counter front, a wooden counter, a flat roof."""
    for sx in (-1, 1):
        x0, x1 = sorted((sx * KX, sx * (KX - 0.2)))
        b.span((x0, 0, KZ0), (x1, ROOF_Y, KZ1), KIOSK)                                         # sides
        b.span((x0 - 0.02 * sx, 0, KZ0 - 0.04), (x1 + 0.02 * sx, ROOF_Y, KZ0), TRIM)           # corner trim
    b.span((-KX + 0.2, 0, KZ0), (KX - 0.2, CTR_Y, KZ0 + 0.2), KIOSK)                            # counter front
    for x0, x1 in ((-2.35, -0.2), (0.2, 2.35)):                                                  # its two panels
        b.span((x0, 0.35, KZ0 - 0.03), (x1, CTR_Y - 0.3, KZ0), "pastel_butter")
    b.span((-KX - 0.1, CTR_Y, KZ0 - 0.35), (KX + 0.1, CTR_Y + 0.15, KZ0 + 0.4), "caramel_wood")  # the counter
    b.span((-KX + 0.2, WIN_TOP, KZ0), (KX - 0.2, ROOF_Y, KZ0 + 0.2), KIOSK)                     # the fascia
    b.span((-KX - 0.2, ROOF_Y, KZ0 - 0.1), (KX + 0.2, ROOF_Y + 0.2, KZ1), "concrete_dark")       # the roof
    b.span((-KX + 0.2, 0, KZ1 - 0.1), (KX - 0.2, ROOF_Y, KZ1), "dark_wood")                     # inside back
    b.span((-KX + 0.2, 0, KZ0 + 0.2), (KX - 0.2, 0.05, KZ1 - 0.1), "dark_wood")                 # inside floor
    for y in (2.5, 3.25):                                                                        # the shelves
        b.span((-KX + 0.2, y, 0.4), (KX - 0.2, y + 0.08, KZ1 - 0.1), "caramel_wood")


def _lost_finds(b):
    """The odd finds on the shelves (a teddy bear, one boot, a lamp, a cat bed, a duck, a mitten) and an umbrella
    standing in the corner, a paper tag on each."""
    s1, s2 = 2.58, 3.33                                                                          # the shelf tops
    tx = -1.75                                                                                   # the teddy bear
    b.ball((tx, s1 + 0.2, 0.7), 0.2, "fur_caramel", scale=(1, 1.05, 0.9))
    b.ball((tx, s1 + 0.52, 0.66), 0.15, "fur_caramel")
    for sx in (-1, 1):
        b.ball((tx + sx * 0.12, s1 + 0.65, 0.66), 0.06, "fur_caramel")                          # ears
        b.ball((tx + sx * 0.17, s1 + 0.08, 0.53), 0.07, "fur_caramel")                          # feet
    b.span((tx - 0.04, s1 + 0.5, 0.5), (tx + 0.04, s1 + 0.54, 0.52), "fur_black")               # nose
    b.span((-0.75, s1, 0.5), (-0.5, s1 + 0.5, 0.75), "choco")                                   # the boot
    b.span((-0.98, s1, 0.5), (-0.5, s1 + 0.16, 0.75), "choco")
    b.span((-0.77, s1 + 0.46, 0.48), (-0.48, s1 + 0.54, 0.77), "dark_wood")
    b.cyl((0.6, s1 + 0.03, 0.7), 0.15, 0.06, "brass", segments=10)                             # the lamp
    b.span((0.58, s1 + 0.06, 0.68), (0.62, s1 + 0.4, 0.72), "brass")
    b.cyl((0.6, s1 + 0.5, 0.7), 0.22, 0.24, "pastel_butter", r2=0.14, segments=10)
    b.cyl((1.75, s1 + 0.08, 0.68), 0.38, 0.16, "bowl_red", segments=14)                         # the cat bed
    b.cyl((1.75, s1 + 0.165, 0.68), 0.27, 0.01, "cream", segments=12)
    b.ball((-1.5, s2 + 0.14, 0.7), 0.15, "pastel_butter")                                        # a rubber duck
    b.ball((-1.4, s2 + 0.32, 0.68), 0.1, "pastel_butter")
    b.span((-1.31, s2 + 0.3, 0.6), (-1.22, s2 + 0.34, 0.66), "fur_ginger")
    b.span((0.1, s2, 0.55), (0.45, s2 + 0.35, 0.75), "shirt_red")                              # a mitten
    b.span((0.4, s2 + 0.12, 0.6), (0.52, s2 + 0.26, 0.72), "shirt_red")
    b.span((0.12, s2, 0.53), (0.43, s2 + 0.08, 0.55), "offwhite")
    for k, sw in enumerate(("pastel_lilac", "mint", "cardboard")):                              # parcels
        b.span((1.0 + 0.55 * k, s2, 0.5), (1.45 + 0.55 * k, s2 + 0.32 - 0.06 * k, 0.85), sw)
    for (x, y, z) in ((-1.8, s1 + 0.3, 0.52), (-0.7, s1 + 0.3, 0.5), (1.95, s1 + 0.14, 0.34),
                      (0.25, s2 + 0.2, 0.55)):                                                 # paper tags
        b.span((x, y - 0.12, z - 0.02), (x + 0.12, y, z), "offwhite")
    ux, uz = 2.3, 0.15                                                                           # the umbrella
    b.cyl((ux, 1.6, uz), 0.035, 3.2, "fur_black", segments=6)
    b.cyl((ux, 2.55, uz), 0.15, 1.1, "shirt_blue", r2=0.05, segments=8)
    b.span((ux - 0.03, 3.2, uz - 0.03), (ux + 0.03, 3.42, uz + 0.03), "fur_black")
    b.span((ux - 0.25, 3.36, uz - 0.03), (ux + 0.03, 3.42, uz + 0.03), "fur_black")             # its hook
    b.span((ux - 0.25, 3.22, uz - 0.03), (ux - 0.19, 3.42, uz + 0.03), "fur_black")
    b.span((-2.2, CTR_Y + 0.15, KZ0 - 0.2), (-1.6, CTR_Y + 0.23, KZ0 + 0.2), "offwhite")         # the ledger
    b.span((-2.2, CTR_Y + 0.23, KZ0 - 0.2), (-1.92, CTR_Y + 0.25, KZ0 + 0.2), "pants_navy")


def _lost_awning(b):
    """A red and white striped awning over the window on two struts, with a scalloped valance."""
    n, w = 8, 2 * KX + 0.4
    sw_w = w / n
    depth, rise = (KZ0 - 0.05) - AWN_Z, LAWN_B - LAWN_F
    tilt = math.degrees(math.atan2(rise, depth))
    zc = (KZ0 - 0.05 + AWN_Z) / 2
    for k in range(n):
        x = -w / 2 + sw_w * (k + 0.5)
        sw = ("bowl_red", "offwhite")[k % 2]
        b.box((x, (LAWN_F + LAWN_B) / 2 + 0.05, zc), (sw_w, 0.1, math.hypot(depth, rise)), sw, rot=rot_x(-tilt))
        vz = AWN_Z - 0.04
        b.span((x - sw_w / 2, LAWN_F - 0.3, vz - 0.04), (x + sw_w / 2, LAWN_F + 0.03, vz + 0.04), sw)
        cy = LAWN_F - 0.29
        arc = [(x + sw_w / 2 * math.cos(math.radians(a)), cy + sw_w / 2 * math.sin(math.radians(a)))
               for a in (180, 240, 300, 360)]
        b.fan_z(vz, (x, cy), arc, 0.08, sw)
    for sx in (-1, 1):                                                                          # the struts
        p0, p1 = Vector((sx * (KX - 0.1), 3.5, KZ0 - 0.02)), Vector((sx * (KX - 0.1), LAWN_F - 0.05, AWN_Z + 0.25))
        d = p1 - p0
        b.box(tuple((p0 + p1) / 2), (0.07, 0.07, d.length), "metal",
              rot=rot_x(-math.degrees(math.atan2(d.y, -d.z))))


def _lost_sign(b, bulb, blink):
    """LOST & FOUND on a cream board framed in dark wood on the roof, bulbs round its frame. Returns its top."""
    hw = 2.6
    for sx in (-1, 1):                                                                          # its legs
        b.span((sx * 2.0 - 0.06, ROOF_Y + 0.2, SIGN_Z + 0.15), (sx * 2.0 + 0.06, SIGN_Y0 + 0.9, SIGN_Z + 0.27),
               "metal")
    b.span((-hw, SIGN_Y0 + 0.1, SIGN_Z + 0.05), (hw, SIGN_Y1 - 0.1, SIGN_Z + 0.15), "cream")
    for y0, y1 in ((SIGN_Y0, SIGN_Y0 + 0.1), (SIGN_Y1 - 0.1, SIGN_Y1)):                          # the frame
        b.span((-hw - 0.15, y0, SIGN_Z), (hw + 0.15, y1, SIGN_Z + 0.15), "dark_wood")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw + 0.15)))
        b.span((x0, SIGN_Y0 + 0.1, SIGN_Z), (x1, SIGN_Y1 - 0.1, SIGN_Z + 0.15), "dark_wood")
    _label_front(b, "LOST &", 0.0, SIGN_Y0 + 0.78, SIGN_Z + 0.05, 0.1, 0.04, "bowl_red")
    _label_front(b, "FOUND", 0.0, SIGN_Y0 + 0.2, SIGN_Z + 0.05, 0.1, 0.04, "bowl_red")
    for k in range(9):                                                                          # bulbs, top and bottom
        x = -2.4 + 0.6 * k
        for y in (SIGN_Y0 + 0.05, SIGN_Y1 - 0.05):
            (blink if (k, y) == (4, SIGN_Y1 - 0.05) else bulb).cyl((x, y, SIGN_Z - 0.03), 0.07, 0.06, "lamp_warm",
                                                                    axis="Z", segments=6)
    for sx in (-1, 1):
        for y in (SIGN_Y0 + 0.55, SIGN_Y1 - 0.55):
            bulb.cyl((sx * (hw + 0.075), y, SIGN_Z - 0.03), 0.07, 0.06, "lamp_warm", axis="Z", segments=6)
    return (0.0, SIGN_Y1, SIGN_Z + 0.07)


def _lost_pipe(b):
    """The dripping pipe, kept from the old Lost and Found: up the wall beside the kiosk and over its roof, a rusty
    collar and a red valve wheel, its open mouth over the roof behind the sign. Returns the mouth (Roblox)."""
    b.span((PIPE_X - 0.3, 0, PIPE_Z - 0.3), (PIPE_X + 0.3, 0.1, PIPE_Z + 0.25), "concrete")
    b.cyl((PIPE_X, (0.1 + PIPE_TOP) / 2, PIPE_Z), 0.18, PIPE_TOP - 0.1, "metal", segments=10)
    for y in (0.7, 3.6):
        b.cyl((PIPE_X, y, PIPE_Z), 0.23, 0.12, "rust", segments=10)
    b.cyl((PIPE_X, 1.6, PIPE_Z - 0.24), 0.06, 0.1, "metal", axis="Z", segments=6)               # valve stem
    b.cyl((PIPE_X, 1.6, PIPE_Z - 0.32), 0.24, 0.05, "bowl_red", axis="Z", segments=10)          # valve wheel
    b.ball((PIPE_X, PIPE_TOP, PIPE_Z), 0.23, "metal")
    b.cyl(((PIPE_X + PIPE_MOUTH) / 2, PIPE_TOP, PIPE_Z), 0.18, PIPE_X - PIPE_MOUTH, "metal", axis="X", segments=10)
    b.ball((PIPE_MOUTH, PIPE_TOP, PIPE_Z), 0.23, "metal")
    low = PIPE_TOP - 0.45
    b.cyl((PIPE_MOUTH, (PIPE_TOP + low) / 2, PIPE_Z), 0.18, PIPE_TOP - low, "metal", segments=10)
    b.cyl((PIPE_MOUTH, low + 0.04, PIPE_Z), 0.23, 0.1, "rust", segments=10)                     # flange
    b.cyl((PIPE_MOUTH, low - 0.015, PIPE_Z), 0.12, 0.01, "fur_black", segments=8)               # the open mouth
    b.span((PIPE_MOUTH - 0.35, ROOF_Y + 0.2, PIPE_Z - 0.3), (PIPE_MOUTH + 0.35, ROOF_Y + 0.22, PIPE_Z + 0.2),
           "puddle")                                                                             # the wet patch
    return (PIPE_MOUTH, low - 0.08, PIPE_Z)


def _lost_ground(b):
    """A crate of unclaimed things by the wall and a puddle at the counter."""
    cx0, cx1, cz0, cz1 = -3.95, -2.95, -0.1, 0.9
    b.span((cx0, 0, cz0), (cx1, 0.8, cz1), "kibble")
    for y in (0.0, 0.64):
        b.span((cx0 - 0.02, y, cz0 - 0.02), (cx1 + 0.02, y + 0.16, cz0), "dark_wood")
    b.span((cx0 + 0.2, 0.8, cz0 + 0.2), (cx0 + 0.6, 0.95, cz0 + 0.6), "shirt_red")              # odds poking out
    b.ball((cx1 - 0.3, 0.92, cz0 + 0.5), 0.15, "pastel_sky")
    b.span((-0.4, 0, KZ0 - 0.9), (1.2, 0.02, KZ0), "puddle")                                 # a puddle at the counter


def _lost_bell(bell):
    """The brass desk bell on the counter, built about its base (the `_Bell` pivot) for its ring-wobble."""
    bell.cyl((0, 0.025, 0), 0.17, 0.05, "dark_wood", segments=12)
    bell.ball((0, 0.06, 0), 0.14, "brass", scale=(1, 0.75, 1))
    bell.cyl((0, 0.19, 0), 0.03, 0.06, "brass", segments=6)
    bell.cyl((0, 0.23, 0), 0.05, 0.02, "metal", segments=8)


def build_lost_found_booth(mat):
    b, bulb, blink, bell = RB(), RB(), RB(), RB()
    _lost_wall(b)
    _lost_kiosk(b)
    _lost_finds(b)
    _lost_awning(b)
    top = _lost_sign(b, bulb, blink)
    drip = _lost_pipe(b)
    _lost_ground(b)
    _lost_bell(bell)
    bell_at = (1.7, CTR_Y + 0.15, KZ0 + 0.0)
    _anchor(LOST, "PromptAnchor", (0.0, 1.5, KZ0 - 1.4))
    _anchor(LOST, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    _anchor(LOST, "Drip", drip)
    return [b.finalize(LOST, mat), bulb.finalize(LOST + "_Bulb", mat), blink.finalize(LOST + "_Blink_Bulb", mat),
            bell.finalize(LOST + "_Bell", mat, location=bell_at)]


def rbx_attachments(name):
    seen = {}
    for n, p in ATTACHMENTS.get(name, []):
        seen[n] = p                                       # a rebuild in the same run replaces, never duplicates
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in seen.items()]


ASSETS = {
    PIC: (build_picnic_station, 4000),
    YARD: (build_yardsale_stall, 4000),
    HUT: (build_fishing_hut, 5000),
    HUT + "_Gold": (lambda m: build_fishing_hut(m, gold=True), 5000),
    LOST: (build_lost_found_booth, 5000),
}
