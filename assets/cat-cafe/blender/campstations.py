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
                                      pastel blue and white striped awning on four posts; on it the crates the lucky pick
                                      lands on (#3615: a Classic crate, a golden one on a riser with a FREE card, the
                                      Neighbourhood parcel) and a lamp; boxes stacked on the rug; a hand-painted YARD SALE board hanging
                                      on two chains from an arm on a post, the child Model _Sign_Swing pivoted at its
                                      ring, which Effects/Motion swings (#1800). Attachments: PromptAnchor (the table's
                                      front, 1.5 up), BangAnchor (2 over the arm), GlowAnchor (under the awning).
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

  CatCafe_Camp_Desert_OasisSpa        (late-stations.md section 1) a tiled pool about 9 wide in a sandstone deck with a
                                      terracotta and cream checked edge, white tile rim, teal mosaic band and gold
                                      corner caps, between two date palms in planters; three striped lounge cushions, a
                                      stack of rolled towels and an OASIS SPA board on a carved post. Child Model
                                      `_Water` (see-through, walk-through). Attachments: PromptAnchor (the pool's front,
                                      1.5 up), BangAnchor (2 over the sign), Steam (the water), Soak_1..3 (where the
                                      owner's soaking cats sit, their feet under the water).
  CatCafe_Camp_Desert_SpaTowel        the towel a soaking cat wears on its head, folded in three, white with a teal
                                      stripe and a terracotta hem; pivot at its underside's middle; nothing collides.
  CatCafe_Camp_Ruins_RelicMuseum      (late-stations.md section 2) a carved sandstone front about 10 wide with jade
                                      trim: three steps, two columns with jade rings, a dark doorway in a jade frame,
                                      an entablature and pediment with a gold sun disc, a RELIC MUSEUM board on the
                                      beam, a velvet rope on brass posts at the top of the steps, and by the steps a
                                      glass case (`_Glass`) holding a little gold cat idol with jade eyes. Attachments:
                                      PromptAnchor (the rope, 1.5 up), BangAnchor (2 over the sign), SparkleAnchor (the
                                      idol).
  CatCafe_Camp_Snowy_CocoaStand      (tier8-snowy-mountain.md section 5, #3997) a little log cocoa hut on a plank deck:
                                      a log back wall and sides, a counter with a red front, a red and white striped
                                      awning with snow on top and icicles, a red cocoa pot on a warmer (`_Glow`) with
                                      four mugs of cocoa and marshmallows, a HOT COCOA board on a log post, a snowy
                                      pine and a stack of logs. Attachments: PromptAnchor (the counter's front, 1.5
                                      up), BangAnchor (2 over the sign), GlowAnchor (under the awning), Steam (the
                                      pot's mouth). It sells nothing: it gives Warm Paws.

  CatCafe_Camp_Snowy_FusionObservatory (fusion-observatory.md section 3, #4104) a round stone tower about 10 wide
                                      under a white dome split front to back by a brass slit, a short brass
                                      telescope out of the slit, snow on the ledge, a door with a lantern, star
                                      windows and a FUSION OBSERVATORY board on a log post. It stands on Summit Peak.
                                      `_Slit_Glow` is the slit's lit strip (Neon; Effects recolours every `_Glow`
                                      part to the coat's colour while a fusion runs); `_Bulb` (the lantern and the
                                      star windows) is always lit and is left alone. Attachments: PromptAnchor (the
                                      door, 1.5 up), BangAnchor (2 over the sign), GlowAnchor (the dome's middle, 70%
                                      of the height up, where the paw lights circle at 1.15 times the half width).

Every model: pivot at the base centre on the camp's ground, front -Z, no turn of its own, placed where its camp extra
stands (Layout.campExtras, the area's set space) so Gameplay only swaps the asset name.
"""

import math

from mathutils import Matrix, Vector

from cannon import frame_at
from campextras import gold_fish
from common import RB, text_width
from plot import rot_x, rot_y, rot_z

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
            # the leg's foot is cut level with the ground: a corner below it sank the walk-up ring under the floor
            ca, sa = math.cos(math.radians(ang)), abs(math.sin(math.radians(ang)))
            cut = ((L + 0.1) / 2 * ca + 0.1 * sa - (TOP_Y - 0.3) / 2) / ca
            uy, uz = (TOP_Y - 0.3) / L, (top_z - foot_z) / L
            b.box((x, (TOP_Y - 0.3) / 2 + uy * cut / 2, (foot_z + top_z) / 2 + uz * cut / 2), (0.2, L + 0.1 - cut, 0.2),
                  DARK, rot=rot_x(ang))
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
    lift = 0.05 * math.sin(math.radians(lean)) + 0.001                 # the leaning boards' lower edges on the ground
    back_foot = (SIGN_X, lift, SIGN_Z + 2 * H * math.sin(math.radians(lean)))

    def at(p, Rm=R, base=(SIGN_X, lift, SIGN_Z)):
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
YSIGN_X, YSIGN_Z = 3.45, -1.5                                  # the post the sign hangs from
ARM_X1, ARM_Y = 5.4, 4.0                                       # the arm's far end and its underside
HINGE_X = 4.65                                                 # the sign's swing pivot under the arm (#1800)
SIGN_ANGLE = 6.0                                               # its swing either way, clear of the post (Motion's Angle)


def _cardboard_box(b, x, y, z, w, h, d, open_flaps=True):
    b.span((x - w / 2, y, z - d / 2), (x + w / 2, y + h, z + d / 2), "cardboard")
    b.span((x - w / 2, y + h, z - d / 2), (x + w / 2, y + h + 0.02, z - d / 2 + 0.04), "kibble")       # tape
    if open_flaps:
        b.box((x - w / 2 + 0.1, y + h + 0.15, z), (0.3, 0.04, d * 0.7), "cardboard", rot=_rz(-40))
        b.box((x + w / 2 - 0.1, y + h + 0.15, z), (0.3, 0.04, d * 0.7), "cardboard", rot=_rz(40))


def _mini_crate(b, x, y, z, kind):
    """A small crate on the table (#3615), 0.96 wide, 0.76 deep and about 0.75 tall, front -Z: "classic" (cream
    boards in a mint frame, a blush ribbon and bow), "gold" (the same in the metal golds) or "parcel" (the
    Neighbourhood Crate: cardboard, a white string and bow, a label)."""
    w, d, h = 0.48, 0.38, 0.62
    if kind == "parcel":
        body, rim, lid, tie = "cardboard", "cardboard", "treat_tan", "offwhite"
    elif kind == "gold":
        body, rim, lid, tie = "gold_light", "gold_mid", "gold_light", "blush"
    else:
        body, rim, lid, tie = "cream", "mint", "cream", "blush"
    b.span((x - w + 0.03, y, z - d + 0.03), (x + w - 0.03, y + h, z + d - 0.03), body)
    if kind != "parcel":
        for sx in (-1, 1):
            for sz in (-1, 1):                                                                  # corner posts
                b.span((x + min(sx * w, sx * (w - 0.08)), y, z + min(sz * d, sz * (d - 0.08))),
                       (x + max(sx * w, sx * (w - 0.08)), y + h, z + max(sz * d, sz * (d - 0.08))), rim)
    b.span((x - w - 0.02, y + h, z - d - 0.02), (x + w + 0.02, y + h + 0.06, z + d + 0.02), rim)   # lid
    b.span((x - w + 0.04, y + h + 0.06, z - d + 0.04), (x + w - 0.04, y + h + 0.1, z + d - 0.04), lid)
    t = 0.03 if kind == "parcel" else 0.08                                                      # ribbon or string
    b.span((x - t, y, z - d - 0.035), (x + t, y + h + 0.115, z + d + 0.035), tie)
    b.span((x - w - 0.035, y, z - t), (x + w + 0.035, y + h + 0.117, z + t), tie)
    for sx in (-1, 1):                                                                          # the bow
        b.box((x + sx * 0.12, y + h + 0.19, z), (0.2, 0.12, 0.07), tie, rot=_rz(sx * 28))
    b.span((x - 0.05, y + h + 0.11, z - 0.05), (x + 0.05, y + h + 0.2, z + 0.05), tie)
    if kind == "parcel":
        b.span((x - 0.4, y + 0.2, z - d - 0.045), (x - 0.12, y + 0.42, z - d + 0.03), "offwhite")   # the label
    else:
        b.span((x - 0.4, y + 0.16, z - d - 0.045), (x - 0.18, y + 0.38, z - d + 0.03), "offwhite")  # the tag
        b.span((x - 0.34, y + 0.22, z - d - 0.055), (x - 0.24, y + 0.32, z - d - 0.045), "blush")


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
    # the crates the lucky pick can land on (#3615): a Classic crate, a golden one on a riser in the middle and the
    # Neighbourhood parcel, each a small copy of its crates.py design; a FREE card stands in front of the riser
    _mini_crate(b, -1.55, top, 0.05, "classic")
    b.span((-0.55, top, -0.4), (0.55, top + 0.22, 0.5), "caramel_wood")                         # the riser
    b.span((-0.6, top + 0.22, -0.45), (0.6, top + 0.27, 0.55), "blush")
    _mini_crate(b, 0.0, top + 0.27, 0.05, "gold")
    b.span((-0.38, top, -0.62), (0.38, top + 0.38, -0.585), "offwhite")                        # FREE card
    _label_front(b, "FREE", 0.0, top + 0.07, -0.615, 0.045, 0.02, "bowl_red")
    _mini_crate(b, 1.5, top, 0.05, "parcel")
    # a lamp at the +X end
    b.cyl((2.2, top + 0.04, 0.4), 0.16, 0.08, "brass", segments=10)
    b.span((2.17, top + 0.08, 0.37), (2.23, top + 0.6, 0.43), "brass")
    b.cyl((2.2, top + 0.75, 0.4), 0.26, 0.35, "pastel_butter", segments=10)
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


def _yard_sign(b, mat):
    """A hand-painted YARD SALE board hanging from an arm on a post, its painted face toward -Z. The board and its two
    chains are the child Model YARD_Sign_Swing, pivoted at the ring under the arm, so Effects/Motion swings it side to
    side (#1800). Returns the swing object and the arm's top (Roblox)."""
    x, z = YSIGN_X, YSIGN_Z
    b.span((x - 0.09, 0, z - 0.09), (x + 0.09, ARM_Y + 0.35, z + 0.09), DARK)                   # the post
    b.span((x - 0.14, ARM_Y + 0.35, z - 0.14), (x + 0.14, ARM_Y + 0.45, z + 0.14), DARK)       # its cap
    b.span((x, ARM_Y, z - 0.07), (ARM_X1, ARM_Y + 0.14, z + 0.07), DARK)                        # the arm
    b.box((x + 0.45, ARM_Y - 0.33, z), (0.09, 0.95, 0.09), DARK, rot=_rz(-45))                 # its brace
    b.span((HINGE_X - 0.05, ARM_Y - 0.12, z - 0.05), (HINGE_X + 0.05, ARM_Y, z + 0.05), "metal")   # the hook
    sg = RB()                                                         # built about its pivot, the ring's top
    hy = 0.0                                                          # local: the pivot at (0, 0, 0)
    y1 = -0.38                                                        # the board's top
    y0 = y1 - 1.2
    for cx in (-0.6, 0.6):                                            # two chains up to the ring
        L = math.hypot(cx, y1 + 0.08)
        a = math.degrees(math.atan2(cx, -0.08 - y1))
        sg.box((cx / 2, (y1 - 0.08) / 2, 0), (0.05, L, 0.05), "metal", rot=_rz(a))
    sg.span((-0.07, hy - 0.08, -0.07), (0.07, hy, 0.07), "metal")                               # the ring
    sg.span((-0.8, y0, -0.04), (0.8, y1, 0.04), "cardboard")                                    # the board
    sg.span((-0.84, y0 - 0.04, -0.02), (0.84, y1 + 0.04, 0.02), "kibble")                       # torn edge
    _label_front(sg, "YARD", 0.0, y0 + 0.7, -0.04, 0.075, 0.02, "bowl_red")
    _label_front(sg, "SALE", 0.0, y0 + 0.2, -0.04, 0.075, 0.02, "bowl_red")
    for nx in (-0.6, 0.6):
        sg.span((nx - 0.03, y1 - 0.12, -0.07), (nx + 0.03, y1 - 0.06, -0.03), "metal")         # nails
    swing = sg.finalize(YARD + "_Sign_Swing", mat, location=(HINGE_X, ARM_Y - 0.12, z))
    return swing, (HINGE_X, ARM_Y + 0.14, z)


def build_yardsale_stall(mat):
    b = RB()
    _yard_table(b)
    _yard_awning(b)
    swing, top = _yard_sign(b, mat)
    _anchor(YARD, "PromptAnchor", (0.0, 1.5, YT_Z0 - 1.1))
    _anchor(YARD, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    _anchor(YARD, "GlowAnchor", (0.0, AWN_F - 0.5, (POST_ZF + POST_ZB) / 2))
    return [b.finalize(YARD, mat), swing]


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
        hy = (0.12 + 0.62 * r) / 2                                    # same top as before, underside on the ground:
        b.ball(((PA + 0.15) * math.cos(a), hy, PZ + (PC + 0.15) * math.sin(a)), r, stones[k % 4],   # a stone below
               scale=(1.0, hy / r, 0.9))                              # the ground sank the walk-up ring under the floor
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
SIGN_Y0, SIGN_Y1, LF_SIGN_Z = 5.15, 6.65, -0.85    # the sign board's bottom, top and face
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
        b.span((sx * 2.0 - 0.06, ROOF_Y + 0.2, LF_SIGN_Z + 0.15), (sx * 2.0 + 0.06, SIGN_Y0 + 0.9, LF_SIGN_Z + 0.27),
               "metal")
    b.span((-hw, SIGN_Y0 + 0.1, LF_SIGN_Z + 0.05), (hw, SIGN_Y1 - 0.1, LF_SIGN_Z + 0.15), "cream")
    for y0, y1 in ((SIGN_Y0, SIGN_Y0 + 0.1), (SIGN_Y1 - 0.1, SIGN_Y1)):                          # the frame
        b.span((-hw - 0.15, y0, LF_SIGN_Z), (hw + 0.15, y1, LF_SIGN_Z + 0.15), "dark_wood")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw + 0.15)))
        b.span((x0, SIGN_Y0 + 0.1, LF_SIGN_Z), (x1, SIGN_Y1 - 0.1, LF_SIGN_Z + 0.15), "dark_wood")
    _label_front(b, "LOST &", 0.0, SIGN_Y0 + 0.78, LF_SIGN_Z + 0.05, 0.1, 0.04, "bowl_red")
    _label_front(b, "FOUND", 0.0, SIGN_Y0 + 0.2, LF_SIGN_Z + 0.05, 0.1, 0.04, "bowl_red")
    for k in range(9):                                                                          # bulbs, top and bottom
        x = -2.4 + 0.6 * k
        for y in (SIGN_Y0 + 0.05, SIGN_Y1 - 0.05):
            (blink if (k, y) == (4, SIGN_Y1 - 0.05) else bulb).cyl((x, y, LF_SIGN_Z - 0.03), 0.07, 0.06, "lamp_warm",
                                                                    axis="Z", segments=6)
    for sx in (-1, 1):
        for y in (SIGN_Y0 + 0.55, SIGN_Y1 - 0.55):
            bulb.cyl((sx * (hw + 0.075), y, LF_SIGN_Z - 0.03), 0.07, 0.06, "lamp_warm", axis="Z", segments=6)
    return (0.0, SIGN_Y1, LF_SIGN_Z + 0.07)


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


# ------------------------------------------------------------------------------------------ oasis spa --
# late-stations.md section 1 (#2651 part 4): the Desert camp's Oasis Spa, a small tiled pool between two palms
SPA = "CatCafe_Camp_Desert_OasisSpa"
SPA_TOWEL = "CatCafe_Camp_Desert_SpaTowel"
DECK_X, DECK_Z0, DECK_Z1, DECK_Y = 7.5, -5.0, 5.5, 0.3      # the tiled deck: half width, front, back, top
POOL_X, POOL_Z0, POOL_Z1 = 4.5, -2.0, 4.0                   # the pool's outer rim
RIM_T, RIM_Y, WATER_Y = 0.5, 0.95, 0.75                     # rim thickness and top, the water's surface
SAND_STONE, SAND_LIGHT = "fur_caramel", "paving_tan"


def _spa_deck(b):
    """The deck: a sandstone slab with a terracotta and cream checked border round its edge."""
    b.span((-DECK_X, 0, DECK_Z0), (DECK_X, DECK_Y, DECK_Z1), SAND_LIGHT)
    n = 15
    for k in range(n):                                                   # a checked band along the front edge
        x0 = -DECK_X + 2 * DECK_X * k / n
        b.span((x0, DECK_Y, DECK_Z0), (x0 + 2 * DECK_X / n, DECK_Y + 0.03, DECK_Z0 + 0.6),
               ("terracotta", "cream")[k % 2])


def _spa_pool(b, water):
    """The pool: a raised rim of white tiles with a teal mosaic band round its outside, teal water inside."""
    x0, x1, z0, z1 = -POOL_X, POOL_X, POOL_Z0, POOL_Z1
    for lo, hi in (((x0, DECK_Y, z0), (x1, RIM_Y, z0 + RIM_T)), ((x0, DECK_Y, z1 - RIM_T), (x1, RIM_Y, z1)),
                   ((x0, DECK_Y, z0 + RIM_T), (x0 + RIM_T, RIM_Y, z1 - RIM_T)),
                   ((x1 - RIM_T, DECK_Y, z0 + RIM_T), (x1, RIM_Y, z1 - RIM_T))):
        b.span(lo, hi, "offwhite")
    b.span((x0 + RIM_T, DECK_Y, z0 + RIM_T), (x1 - RIM_T, DECK_Y + 0.05, z1 - RIM_T), "sign_teal")   # the pool floor
    n = 18                                                                # the mosaic band on the front face
    for k in range(n):
        xa = x0 + (x1 - x0) * k / n
        b.span((xa, DECK_Y + 0.15, z0 - 0.04), (xa + (x1 - x0) / n, DECK_Y + 0.45, z0),
               ("sign_teal", "fish_blue")[k % 2])
    for sx in (-1, 1):                                                    # and on each side
        for k in range(12):
            za = z0 + (z1 - z0) * k / 12
            xa = sx * POOL_X
            b.span((min(xa, xa + 0.04 * sx), DECK_Y + 0.15, za), (max(xa, xa + 0.04 * sx), DECK_Y + 0.45,
                   za + (z1 - z0) / 12), ("sign_teal", "fish_blue")[k % 2])
    for (x, z) in ((x0, z0), (x1, z0), (x0, z1), (x1, z1)):               # gold caps on the corners
        b.span((x - 0.05 if x < 0 else x - RIM_T + 0.05 - 0.1, RIM_Y, z - 0.05 if z < 0 else z - RIM_T - 0.05),
               (x + RIM_T + 0.05 if x < 0 else x + 0.05, RIM_Y + 0.12, z + RIM_T + 0.05 if z < 0 else z + 0.05),
               "gold_light")
    # the water reaches 0.02 into the rim, so its sides never share a plane with the rim's inside faces
    water.span((x0 + RIM_T - 0.02, DECK_Y + 0.05, z0 + RIM_T - 0.02), (x1 - RIM_T + 0.02, WATER_Y, z1 - RIM_T + 0.02),
               "sign_teal")
    for (x, z) in ((-2.6, 1.0), (0.0, 1.6), (2.6, 1.0)):                  # where the owner's soaking cats sit
        _anchor(SPA, f"Soak_{[-2.6, 0.0, 2.6].index(x) + 1}", (x, WATER_Y - 0.55, z))
    _anchor(SPA, "Steam", (0.0, WATER_Y + 0.05, 1.0))


def _spa_palm(b, x, z, lean):
    """A date palm in a sandstone planter: a ringed trunk curving outward, eight drooping fronds."""
    b.span((x - 0.9, DECK_Y, z - 0.9), (x + 0.9, DECK_Y + 0.8, z + 0.9), SAND_STONE)
    b.span((x - 0.75, DECK_Y + 0.8, z - 0.75), (x + 0.75, DECK_Y + 0.85, z + 0.75), "fur_hazel")
    h, n, tx = 7.5, 7, x
    y = DECK_Y + 0.8
    for j in range(n):
        t = j / (n - 1)
        tx = x + lean * t * t * 2.0
        b.cyl((tx, y + (j + 0.5) * h / n, z), 0.38 - 0.025 * j, h / n + 0.04, ("fur_hazel", "fur_brown")[j % 2],
              segments=8)
    top = (tx, y + h + 0.15, z)
    b.ball(top, 0.55, "fur_brown")
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.3
        for i, (r, dy, pitch) in enumerate(((0.9, 0.15, 12), (2.03, 0.09, -18), (3.03, -0.48, -40))):
            c = (top[0] + r * math.cos(a), top[1] + dy, top[2] + r * math.sin(a))
            R = Matrix.Rotation(-a, 3, "Y") @ Matrix.Rotation(math.radians(pitch), 3, "Z")
            b.box(c, (1.2, 0.1, 0.7 - 0.15 * i), ("leaf_green", "leaf_dark")[(k + i) % 2], rot=R)
    for k in range(4):                                                    # dates
        a = 2 * math.pi * k / 4
        b.ball((top[0] + 0.45 * math.cos(a), top[1] - 0.6, top[2] + 0.45 * math.sin(a)), 0.18, "fur_toffee")


def _spa_cushion(b, x, z, cols):
    """A striped lounge cushion lying along Z, its head end raised on a wedge of a back rest."""
    w, L = 1.3, 2.6
    b.span((x - w / 2, DECK_Y, z - L / 2), (x + w / 2, DECK_Y + 0.15, z + L / 2), "dark_wood")       # the frame
    n = 6
    for k in range(n):
        za = z - L / 2 + L * k / n
        b.span((x - w / 2 + 0.05, DECK_Y + 0.15, za), (x + w / 2 - 0.05, DECK_Y + 0.45, za + L / n), cols[k % 2])
    b.box((x, DECK_Y + 0.75, z + L / 2 - 0.35), (w - 0.1, 0.25, 0.9), cols[0], rot=rot_x(-35))       # the back rest


def _spa_towels(b, x, z):
    """A stack of rolled towels on a little teak stand."""
    b.span((x - 0.75, DECK_Y, z - 0.5), (x + 0.75, DECK_Y + 0.7, z + 0.5), "caramel_wood")
    cols = ("offwhite", "sign_teal", "terracotta", "offwhite", "pastel_butter", "sign_teal")
    k = 0
    for row, n in enumerate((3, 2, 1)):
        for i in range(n):
            cx = x + (i - (n - 1) / 2) * 0.46
            b.cyl((cx, DECK_Y + 0.92 + row * 0.42, z), 0.21, 0.9, cols[k], axis="Z", segments=8)
            k += 1


def _spa_sign(b, x, z):
    """OASIS SPA on a cream board on a carved sandstone post with a teal cap. Returns the board's top."""
    b.span((x - 0.25, DECK_Y, z - 0.25), (x + 0.25, DECK_Y + 3.3, z + 0.25), SAND_STONE)
    for y in (DECK_Y + 0.6, DECK_Y + 1.6):                               # carved bands
        b.span((x - 0.29, y, z - 0.29), (x + 0.29, y + 0.15, z + 0.29), "fur_latte")
    hw, y0, y1 = 1.6, DECK_Y + 3.3, DECK_Y + 4.7
    b.span((-hw + x, y0, z - 0.12), (hw + x, y1, z + 0.12), "dark_wood")
    b.span((-hw + 0.12 + x, y0 + 0.12, z - 0.15), (hw - 0.12 + x, y1 - 0.12, z - 0.12), "cream")
    _label_front(b, "OASIS", x, y0 + 0.75, z - 0.15, 0.09, 0.04, "sign_teal")
    _label_front(b, "SPA", x, y0 + 0.2, z - 0.15, 0.09, 0.04, "terracotta")
    b.span((-hw - 0.1 + x, y1, z - 0.2), (hw + 0.1 + x, y1 + 0.15, z + 0.2), "sign_teal")
    return (x, y1 + 0.15, z)


def build_oasis_spa(mat):
    b, water = RB(), RB()
    _spa_deck(b)
    _spa_pool(b, water)
    _spa_palm(b, -6.0, 3.8, -1.0)
    _spa_palm(b, 6.0, 3.8, 1.0)
    for z, cols in ((-2.2, ("sign_teal", "offwhite")), (0.8, ("terracotta", "offwhite"))):
        _spa_cushion(b, -5.9, z, cols)
    _spa_cushion(b, 5.9, 0.2, ("pastel_butter", "offwhite"))
    _spa_towels(b, 5.9, -2.9)
    top = _spa_sign(b, -6.0, -4.1)
    _anchor(SPA, "PromptAnchor", (0.0, 1.5, POOL_Z0 - 1.2))
    _anchor(SPA, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    return [b.finalize(SPA, mat), water.finalize(SPA + "_Water", mat)]


def build_spa_towel(mat):
    """The towel a soaking cat wears on its head: folded in three, white with a teal stripe and a terracotta hem.
    Pivot at the middle of its underside, to sit on top of a cat's head; nothing collides."""
    b = RB()
    b.span((-0.36, 0.0, -0.26), (0.36, 0.08, 0.26), "offwhite")
    b.span((-0.34, 0.08, -0.24), (0.34, 0.16, 0.24), "offwhite")
    b.span((-0.32, 0.16, -0.22), (0.32, 0.24, 0.22), "offwhite")
    b.span((-0.33, 0.165, -0.08), (0.33, 0.25, 0.08), "sign_teal")
    b.span((-0.37, 0.0, -0.27), (0.37, 0.04, -0.2), "terracotta")
    _anchor(SPA_TOWEL, "HeadAttach", (0.0, 0.0, 0.0))        # #2909: the underside's middle, on top of the Head
    return [b.finalize(SPA_TOWEL, mat)]


# ------------------------------------------------------------------------------------------ relic museum --
# late-stations.md section 2: the Ruins camp's Relic Museum, a little carved sandstone front with jade trim
MUSEUM = "CatCafe_Camp_Ruins_RelicMuseum"
MX, MZ0, MZ1 = 5.0, -1.0, 3.0                    # the building block: half width, front face, back
STEP_H, STEP_D, FLOOR_Y = 0.35, 0.8, 1.05        # three steps up to the floor
MUS_TOP_Y = 6.2                                  # the wall top under the entablature
DOOR_X, DOOR_Y = 1.3, 4.2                        # the door's half width and top
COL_X, COL_Z = 3.7, -1.9                         # the two columns
STONE_M, STONE_ML, JADE, GOLD = "fur_caramel", "paving_tan", "fur_emerald", "gold_light"
CASE_X = -MX - 1.6                               # the idol's glass case, by the steps on the -X side (#2908)
# #2908: the exhibit gallery, a roofed wing on the +X side: eight stepped rows, one per room in Catalog.areas order
# (front row the Alleyway, back row the Snowy Mountain, added with its crate), ten plinths a row, where the owner's client stands the cats given
# (a sitting cat at scale 0.6 fits a plinth and shows over the row in front)
ROOMS = (("alley", "ALLEYWAY", "brick"), ("park", "PARK", "leaf_green"), ("neighbourhood", "NEIGHBOURHOOD", "shirt_blue"),
         ("woods", "WOODS", "leaf_dark"), ("sewer", "SEWER", "puddle"), ("desert", "DESERT", "terracotta"),
         ("ruins", "RUINS", "fur_emerald"), ("snowy", "SNOWY MOUNTAIN", "eye_blue"),
         ("waterpark", "WATER PARK", "fish_blue"), ("castle", "CASTLE", "shirt_red"))
EXHIBITS = 10
PLINTH_STEP, PLINTH_W, PLINTH_H = 1.25, 0.8, 0.3   # spacing, top size, height of an exhibit plinth
ROW_D, ROW_RISE = 0.9, 0.8                       # each row's depth and how much higher than the one in front
PLAQUE_W = 2.6                                   # each row's name plaque, at the museum end
GX0 = MX + 0.4                                   # the wing's museum side
GX1 = GX0 + PLAQUE_W + EXHIBITS * PLINTH_STEP + 0.5
GZ0 = MZ0 - 1.6                                  # the first row's front, in line with the museum's platform
GZ1 = GZ0 + len(ROOMS) * ROW_D + 0.45            # the back wall's back
G_ROOF = FLOOR_Y + (len(ROOMS) - 1) * ROW_RISE + 3.4    # the wing's roof underside, 3.4 over the back row (2.75
# until the tenth room: Review-QA measured 2.39 clear over the ninth row's plinths, tight for a big Mythical)


def _museum_steps(b):
    """The platform and its three steps across the whole front, the floor running back under the building."""
    z_front = MZ0 - 1.6
    b.span((-MX - 0.4, 0, z_front), (MX + 0.4, FLOOR_Y, MZ1 + 0.3), STONE_ML)
    for k in range(3):
        y0, y1 = k * STEP_H, (k + 1) * STEP_H
        zf = z_front - (3 - k) * STEP_D
        b.span((-MX + 0.6, y0, zf), (MX - 0.6, y1, zf + STEP_D), (STONE_M, STONE_ML)[k % 2])
    b.span((-MX - 0.45, FLOOR_Y, z_front - 0.05), (MX + 0.45, FLOOR_Y + 0.08, z_front + 0.3), JADE)   # jade edge


def _museum_front(b):
    """The walls round the door: a recessed dark doorway, jade trim bands, the entablature and a pediment."""
    y0 = FLOOR_Y
    b.span((-MX, y0, MZ0 + 0.4), (MX, MUS_TOP_Y, MZ1), STONE_M)                                    # the block
    for sx in (-1, 1):                                                                          # the front wall
        x0, x1 = sorted((sx * DOOR_X, sx * MX))
        b.span((x0, y0, MZ0), (x1, MUS_TOP_Y, MZ0 + 0.4), STONE_ML)
    b.span((-DOOR_X, DOOR_Y, MZ0), (DOOR_X, MUS_TOP_Y, MZ0 + 0.4), STONE_ML)                        # over the door
    b.span((-DOOR_X, y0, MZ0 + 0.4), (DOOR_X, DOOR_Y, MZ0 + 0.5), "fur_ink")                   # the dark doorway
    for sx in (-1, 1):                                                                          # jade door frame
        x0, x1 = sorted((sx * DOOR_X, sx * (DOOR_X + 0.25)))
        b.span((x0, y0, MZ0 - 0.08), (x1, DOOR_Y + 0.25, MZ0), JADE)
    b.span((-DOOR_X - 0.25, DOOR_Y, MZ0 - 0.08), (DOOR_X + 0.25, DOOR_Y + 0.25, MZ0), JADE)
    b.span((-MX, y0 + 0.6, MZ0 - 0.06), (-DOOR_X - 0.25, y0 + 0.8, MZ0), JADE)                 # a jade dado band
    b.span((DOOR_X + 0.25, y0 + 0.6, MZ0 - 0.06), (MX, y0 + 0.8, MZ0), JADE)
    for sx in (-1, 1):                                                                          # carved panels
        cx = sx * (MX + DOOR_X) / 2
        b.span((cx - 0.9, y0 + 1.4, MZ0 - 0.05), (cx + 0.9, y0 + 3.6, MZ0), "fur_latte")
        b.span((cx - 0.25, y0 + 2.2, MZ0 - 0.09), (cx + 0.25, y0 + 2.8, MZ0 - 0.05), JADE)    # a jade cat-eye
    # the entablature over the columns: a beam, a jade frieze, a cornice
    b.span((-MX - 0.3, MUS_TOP_Y, COL_Z - 0.6), (MX + 0.3, MUS_TOP_Y + 0.6, MZ1), STONE_ML)
    b.span((-MX - 0.3, MUS_TOP_Y + 0.6, COL_Z - 0.6), (MX + 0.3, MUS_TOP_Y + 0.85, MZ1), JADE)
    b.span((-MX - 0.5, MUS_TOP_Y + 0.85, COL_Z - 0.8), (MX + 0.5, MUS_TOP_Y + 1.1, MZ1 + 0.2), STONE_M)
    # the pediment: a low triangle on the cornice, a gold sun disc in it
    apex = MUS_TOP_Y + 2.6
    base = MUS_TOP_Y + 1.1
    b.fan_z(COL_Z - 0.6, (0.0, apex), [(MX + 0.2, base), (-MX - 0.2, base)], 0.5, STONE_ML)
    b.cyl((0.0, base + 0.6, COL_Z - 0.65), 0.35, 0.1, GOLD, axis="Z", segments=12)
    return apex


def _museum_columns(b):
    for sx in (-1, 1):
        x = sx * COL_X
        b.span((x - 0.55, FLOOR_Y, COL_Z - 0.55), (x + 0.55, FLOOR_Y + 0.4, COL_Z + 0.55), STONE_M)   # base
        b.cyl((x, (FLOOR_Y + 0.4 + MUS_TOP_Y - 0.4) / 2, COL_Z), 0.4, MUS_TOP_Y - 0.8 - FLOOR_Y, STONE_ML, segments=10)
        for y in (FLOOR_Y + 1.6, FLOOR_Y + 3.4):                                                   # jade rings
            b.cyl((x, y, COL_Z), 0.43, 0.15, JADE, segments=10)
        b.span((x - 0.6, MUS_TOP_Y - 0.4, COL_Z - 0.6), (x + 0.6, MUS_TOP_Y, COL_Z + 0.6), STONE_M)         # capital


def _museum_sign(b):
    """RELIC MUSEUM in gold on a jade board fixed to the beam's front. Returns its top."""
    z = COL_Z - 0.6
    hw, y0, y1 = 3.0, MUS_TOP_Y + 0.02, MUS_TOP_Y + 0.58
    b.span((-hw, y0, z - 0.06), (hw, y1, z), "night_sky")
    _label_front(b, "RELIC MUSEUM", 0.0, y0 + 0.07, z - 0.06, 0.085, 0.03, GOLD)
    return (0.0, MUS_TOP_Y + 2.6, z)


def _museum_rope(b):
    """A velvet rope on two brass posts across the top of the steps, sagging in the middle."""
    z = MZ0 - 1.2
    y = FLOOR_Y
    for x in (-2.0, 2.0):
        b.cyl((x, y + 0.05, z), 0.22, 0.1, "brass", segments=10)
        b.cyl((x, y + 0.55, z), 0.06, 1.0, "brass", segments=8)
        b.ball((x, y + 1.1, z), 0.11, "brass")
    for x0, x1, ya, yb in ((-1.95, 0.0, 1.0, 0.75), (0.0, 1.95, 0.75, 1.0)):
        L = math.hypot(x1 - x0, yb - ya)
        ang = math.degrees(math.atan2(yb - ya, x1 - x0))
        b.box(((x0 + x1) / 2, y + (ya + yb) / 2, z), (L, 0.09, 0.09), "royal_berry",
              rot=Matrix.Rotation(math.radians(ang), 3, "Z"))
    return (0.0, y + 0.9, z)


def _museum_case(b, glass):
    """A glass case on a dark plinth by the steps, a little golden cat idol inside on a velvet cushion."""
    x, z = CASE_X, MZ0 - 2.6
    b.span((x - 0.6, 0, z - 0.6), (x + 0.6, 1.2, z + 0.6), "dark_wood")
    b.span((x - 0.66, 1.2, z - 0.66), (x + 0.66, 1.3, z + 0.66), "brass")
    b.span((x - 0.4, 1.3, z - 0.4), (x + 0.4, 1.45, z + 0.4), "royal_berry")
    y = 1.45                                                              # the idol: a sitting cat in gold
    b.span((x - 0.17, y, z - 0.12), (x + 0.17, y + 0.38, z + 0.16), GOLD)
    b.span((x - 0.2, y + 0.38, z - 0.17), (x + 0.2, y + 0.68, z + 0.13), GOLD)
    for sx in (-1, 1):
        b.span((x + sx * 0.14 - 0.05, y + 0.68, z - 0.05), (x + sx * 0.14 + 0.05, y + 0.8, z + 0.03), GOLD)
    b.span((x - 0.1, y + 0.5, z - 0.19), (x - 0.04, y + 0.56, z - 0.17), JADE)                 # jade eyes
    b.span((x + 0.04, y + 0.5, z - 0.19), (x + 0.1, y + 0.56, z - 0.17), JADE)
    b.span((x + 0.17, y + 0.02, z + 0.1), (x + 0.3, y + 0.08, z + 0.16), GOLD)                 # its tail
    for sx in (-1, 1):                                                    # the case's brass corner posts and top
        for sz in (-1, 1):
            b.span((x + sx * 0.55 - 0.04, 1.3, z + sz * 0.55 - 0.04), (x + sx * 0.55 + 0.04, 2.5, z + sz * 0.55 + 0.04),
                   "brass")
    b.span((x - 0.6, 2.5, z - 0.6), (x + 0.6, 2.58, z + 0.6), "brass")
    glass.span((x - 0.51, 1.3, z - 0.51), (x + 0.51, 2.5, z + 0.51), "glass")


def _gallery(b, plaques):
    """#2908: the exhibit gallery on the museum's +X side, open at the front: seven stepped rows of sandstone, each
    with a coloured band in its room's colour, a name plaque at the museum end and ten plinths, every plinth an
    ExhibitSpot_<area>_<1-10> Attachment on its top (1 at the museum end), facing -Z; a back wall with a jade frieze,
    an end wall, three front columns and a flat roof with a cornice, so the rows stay in shade like a hall. Each
    plaque's letters go in `plaques[area]` (#3129; Derek2 11-10: "have the title of the area glow gold when its
    completed"), a child Model <name>_Plaque_<area> that the client lights (Effects/MuseumPlaques)."""
    back = GZ0 + len(ROOMS) * ROW_D                                      # the back wall's front face
    for k, (area, label, colour) in enumerate(ROOMS):
        z0 = GZ0 + k * ROW_D
        y0, y1 = (0.0 if k == 0 else FLOOR_Y + (k - 1) * ROW_RISE), FLOOR_Y + k * ROW_RISE
        b.span((GX0, y0, z0), (GX1, y1, back), (STONE_ML, STONE_M)[k % 2])                      # the row
        b.span((GX0 + 0.05, y1 - 0.2, z0 - 0.05), (GX1 - 0.05, y1 - 0.08, z0), colour)           # its band
        zc = z0 + ROW_D / 2
        px = min(0.06, (PLAQUE_W - 0.55) / text_width(label, 1.0))                             # its plaque
        b.span((GX0 + 0.2, y1, zc - 0.06), (GX0 + PLAQUE_W - 0.2, y1 + 0.5, zc + 0.06), "night_sky")
        plaques[area] = RB()                    # #3129: its letters, their own Plaque_<area> Model, lit when the room is full
        _label_front(plaques[area], label, GX0 + PLAQUE_W / 2, y1 + 0.13, zc - 0.06, px, 0.03, GOLD)
        for i in range(EXHIBITS):                                                               # its plinths
            x = GX0 + PLAQUE_W + (i + 0.5) * PLINTH_STEP
            b.span((x - PLINTH_W / 2, y1, zc - PLINTH_W / 2), (x + PLINTH_W / 2, y1 + PLINTH_H, zc + PLINTH_W / 2),
                   "offwhite")
            b.span((x - PLINTH_W / 2 - 0.04, y1 + PLINTH_H, zc - PLINTH_W / 2 - 0.04),
                   (x + PLINTH_W / 2 + 0.04, y1 + PLINTH_H + 0.06, zc + PLINTH_W / 2 + 0.04), colour)
            _anchor(MUSEUM, f"ExhibitSpot_{area}_{i + 1}", (x, y1 + PLINTH_H + 0.06, zc))
    top = FLOOR_Y + (len(ROOMS) - 1) * ROW_RISE
    b.span((GX0, 0, back), (GX1, G_ROOF, GZ1), STONE_M)                                         # the back wall
    b.span((GX0, top + 1.6, back - 0.06), (GX1, top + 1.9, back), JADE)                         # its frieze
    b.span((GX1, 0, GZ0 - 0.6), (GX1 + 0.5, G_ROOF, GZ1), STONE_M)                              # the end wall
    for x in (GX0 + 0.45, (GX0 + GX1) / 2, GX1 - 0.45):                                       # the front columns
        b.span((x - 0.45, 0, GZ0 - 1.0), (x + 0.45, 0.4, GZ0 - 0.1), STONE_M)
        b.cyl((x, (0.4 + G_ROOF - 0.4) / 2, GZ0 - 0.55), 0.32, G_ROOF - 0.8, STONE_ML, segments=10)
        b.cyl((x, 2.2, GZ0 - 0.55), 0.35, 0.15, JADE, segments=10)
        b.span((x - 0.5, G_ROOF - 0.4, GZ0 - 1.05), (x + 0.5, G_ROOF, GZ0 - 0.05), STONE_M)
    b.span((GX0, G_ROOF, GZ0 - 1.1), (GX1 + 0.5, G_ROOF + 0.5, GZ1), STONE_ML)                 # the roof
    b.span((GX0, G_ROOF + 0.5, GZ0 - 1.1), (GX1 + 0.5, G_ROOF + 0.72, GZ1), JADE)
    b.span((GX0, G_ROOF + 0.72, GZ0 - 1.3), (GX1 + 0.7, G_ROOF + 0.95, GZ1 + 0.2), STONE_M)   # its cornice
    _label_front(b, "THE CAT GALLERY", (GX0 + GX1) / 2, G_ROOF + 0.1, GZ0 - 1.1, 0.07, 0.03, GOLD)


def build_relic_museum(mat):
    b, glass = RB(), RB()
    _museum_steps(b)
    plaques = {}
    _gallery(b, plaques)
    _museum_front(b)
    _museum_columns(b)
    top = _museum_sign(b)
    rope = _museum_rope(b)
    _museum_case(b, glass)
    _anchor(MUSEUM, "PromptAnchor", (rope[0], 1.5, rope[2] - 0.5))
    _anchor(MUSEUM, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    _anchor(MUSEUM, "SparkleAnchor", (CASE_X, 2.0, MZ0 - 2.6))
    return ([b.finalize(MUSEUM, mat), glass.finalize(MUSEUM + "_Glass", mat)]
            + [rb.finalize(f"{MUSEUM}_Plaque_{area}", mat) for area, rb in plaques.items()])


# ------------------------------------------------------------------------------------------ rummage bin --
# #3050 (Derek2 11-10: "rummage bin ... make it often also like every 15 minutes"): the Alleyway camp's Rummage Bin,
# about 4 tall, a round painted bin in the cafe's teal with a cream band and a big cream paw print on its front, on a
# little pallet, so it reads as the camp's own (not a rescue trap's green wheelie bin or grey can) and as tappable
# from across the camp on a phone. Two looks: `_Ready` (the lid flung back, a tuna and a golden fish tail and a crate
# corner poking out, sparkles over the mouth) and `_Empty` (the lid shut, a fish bone on it); Gameplay shows one
BIN = "CatCafe_Camp_Alley_RummageBin"
BIN_R0, BIN_R1, BIN_H, BIN_BASE = 1.25, 1.4, 3.0, 0.3       # bottom and top radius, body height, the pallet's top


def _bin_body(b):
    for x in (-1.1, 0.0, 1.1):                                                          # the pallet's boards
        b.span((x - 0.48, 0.12, -1.6), (x + 0.48, BIN_BASE, 1.6), WOOD)
    for z in (-1.3, 1.3):
        b.span((-1.6, 0.0, z - 0.2), (1.6, 0.12, z + 0.2), DARK)
    y0 = BIN_BASE
    b.b.cyl(RB.p(0, y0 + BIN_H / 2, 0), BIN_R0, BIN_H, "sign_teal", segments=16, radius2=BIN_R1)
    for (y, r) in ((y0 + 0.75, 1.32), (y0 + BIN_H - 0.1, BIN_R1 + 0.06)):           # a hoop and the rim, its top
        b.cyl((0, y, 0), r, 0.16, "metal", segments=16)                                # just under the mouth's
    b.cyl((0, y0 + 2.3, 0), BIN_R1 - 0.03 + 0.05, 0.45, "cream", segments=16)        # the cream band
    for sx in (-1, 1):                                                                 # handles
        b.span((sx * 1.38, y0 + 2.05, -0.3), (sx * 1.6, y0 + 2.15, 0.3), "metal")
    # the paw print on the front (-Z), cream on the teal: a big pad and four toes
    zf = -1.3
    b.cyl((0, y0 + 1.2, zf - 0.02), 0.36, 0.1, "cream", axis="Z", segments=12)
    for (dx, dy, r) in ((-0.42, 1.68, 0.15), (-0.15, 1.83, 0.16), (0.15, 1.83, 0.16), (0.42, 1.68, 0.15)):
        b.cyl((dx, y0 + dy, zf - 0.03), r, 0.1, "cream", axis="Z", segments=8)
    return y0 + BIN_H


def _bin_ready(r, top):
    """The lid flung back on its hinge, the prizes poking out of the mouth, sparkles over it."""
    a = math.radians(-105)                                                         # past upright, resting back
    hinge = Vector(RB.p(0, top + 0.1, BIN_R1))
    lid_c = hinge + Matrix.Rotation(a, 3, "X") @ Vector((0, -BIN_R1, 0))
    r.b.cyl(tuple(lid_c), BIN_R1 + 0.1, 0.14, "metal", segments=16, rot=Matrix.Rotation(a, 3, "X"))
    r.cyl((0, top + 0.02, 0), BIN_R1 - 0.12, 0.03, "dark_wood", segments=16)         # the dark inside
    r.span((0.2, top - 0.3, -0.1), (1.0, top + 0.5, 0.7), WOOD)                       # a crate's corner
    r.span((0.2, top + 0.15, -0.12), (1.0, top + 0.25, -0.1), DARK)
    r.ball((-0.2, top + 0.1, -0.35), 0.45, "fish_blue", scale=(1.6, 0.8, 0.8))          # the tuna, side on
    r.box((-1.0, top + 0.3, -0.35), (0.12, 0.6, 0.45), "fish_blue")                    # its tail
    r.ball((0.4, top + 0.18, -0.68), 0.08, "fur_black")                                 # its eye (front)
    gold_fish(r, -0.75, top - 0.25, 0.35, s=2.2, up=True)                              # a golden fish tail up
    for (x, y, z, s) in ((-0.7, top + 1.3, -0.3, 0.22), (0.6, top + 1.1, -0.5, 0.16), (0.0, top + 1.6, 0.2, 0.18)):
        r.box((x, y, z), (s, s, 0.06), "sparkle", rot=Matrix.Rotation(math.radians(45), 3, "Z"))


def _bin_empty(e, top):
    """The lid shut, its knob, and a fish bone left on top."""
    e.cyl((0, top + 0.08, 0), BIN_R1 + 0.1, 0.16, "metal", segments=16)
    e.cyl((0, top + 0.22, 0), BIN_R1 - 0.25, 0.12, "metal", segments=16)
    e.span((-0.25, top + 0.28, -0.08), (0.25, top + 0.42, 0.08), "concrete_dark")      # the knob
    e.span((-0.9, top + 0.17, 0.55), (-0.2, top + 0.22, 0.6), "fish_belly")            # a fish bone
    for x in (-0.75, -0.55, -0.35):
        e.span((x - 0.02, top + 0.17, 0.45), (x + 0.02, top + 0.22, 0.7), "fish_belly")


def build_rummage_bin(mat):
    b, ready, empty = RB(), RB(), RB()
    top = _bin_body(b)
    _bin_ready(ready, top)
    _bin_empty(empty, top)
    _anchor(BIN, "PromptAnchor", (0.0, 1.5, -2.2))
    _anchor(BIN, "BangAnchor", (0.0, top + 2.6, 0.0))
    _anchor(BIN, "GlowAnchor", (0.0, top + 0.6, 0.0))
    return [b.finalize(BIN, mat), ready.finalize(BIN + "_Ready", mat), empty.finalize(BIN + "_Empty", mat)]


# ------------------------------------------------------------------------------------------- cocoa stand --
# tier8-snowy-mountain.md section 5: the Snowy camp's Cocoa Stand, free every 2 hours, gives Warm Paws. About 9 x 6,
# inside the camp extra's radius 8 ring.
COCOA = "CatCafe_Camp_Snowy_CocoaStand"
CD_X, CD_Z0, CD_Z1, CD_Y = 4.6, -2.6, 3.0, 0.3            # the plank deck: half width, front, back, top
HUT_X, HUT_Z0, HUT_Z1 = 3.5, -0.6, 2.5                    # the log walls: half width, the sides' front, the back
CTR_Y, CTR_Z0, CTR_Z1 = 2.4, -1.35, -0.35                 # the counter: top, front, back
AWN_TILT, AWN_C, AWN_D = -14.0, (0.0, 4.95, 0.55), 4.8     # the awning: tilt (back up), centre, depth
LOG, LOG_DARK = "fur_brown", "dark_wood"


def _cocoa_deck(b):
    b.span((-CD_X, 0, CD_Z0), (CD_X, CD_Y, CD_Z1), LOG_DARK)
    for k in range(9):                                                    # planks, a hair proud of the deck
        x0 = -CD_X + 2 * CD_X * k / 9
        b.span((x0 + 0.04, CD_Y, CD_Z0 + 0.04), (x0 + 2 * CD_X / 9 - 0.04, CD_Y + 0.03, CD_Z1 - 0.04), WOOD)
    for (x, z, w) in ((-CD_X + 0.6, CD_Z1 - 0.6, 1.4), (CD_X - 0.7, CD_Z0 + 0.5, 1.2), (CD_X - 0.5, CD_Z1 - 0.4, 1.0)):
        b.ball((x, CD_Y + 0.05, z), w * 0.6, "milk", scale=(1.2, 0.35, 1.0))       # snow drifts on the corners


def _cocoa_hut(b):
    """Log walls: the back wall and two sides of round logs, ends crossing at the corners, a snow line on top."""
    n, r = 9, 0.26
    for i in range(n):
        y = CD_Y + r + i * 2 * r * 0.96
        b.cyl((0, y, HUT_Z1), r, 2 * HUT_X + 0.7, (LOG, "fur_hazel")[i % 2], axis="X", segments=8)
        if i < n - 1:
            for sx in (-1, 1):
                b.cyl((sx * HUT_X, y + r * 0.96, (HUT_Z0 + HUT_Z1) / 2 - 0.1), r, HUT_Z1 - HUT_Z0 + 0.6,
                      (LOG, "fur_hazel")[(i + 1) % 2], axis="Z", segments=8)
    top = CD_Y + r + (n - 1) * 2 * r * 0.96
    b.span((-HUT_X - 0.3, top + r * 0.6, HUT_Z1 - 0.32), (HUT_X + 0.3, top + r + 0.18, HUT_Z1 + 0.32), "milk")
    b.span((-HUT_X + 0.4, CD_Y + 2.6, HUT_Z1 - 0.3), (HUT_X - 0.4, CD_Y + 3.6, HUT_Z1 - 0.26), "cream")   # a shelf back
    b.span((-HUT_X + 0.4, CD_Y + 2.5, HUT_Z1 - 0.62), (HUT_X - 0.4, CD_Y + 2.62, HUT_Z1 - 0.3), LOG_DARK)  # the shelf
    for k, sw in enumerate(("shirt_red", "milk", "eye_blue", "leaf_green", "shirt_red", "pastel_butter")):
        b.cyl((-2.5 + k * 1.0, CD_Y + 2.84, HUT_Z1 - 0.46), 0.17, 0.44, sw, segments=8)      # spare mugs, upturned


def _cocoa_counter(b):
    b.span((-HUT_X + 0.2, CD_Y, CTR_Z0), (HUT_X - 0.2, CTR_Y - 0.15, CTR_Z1), WOOD)
    b.span((-HUT_X + 0.5, CD_Y + 0.4, CTR_Z0 - 0.04), (HUT_X - 0.5, CTR_Y - 0.55, CTR_Z0), "shirt_red")   # its front
    for k in range(5):                                                    # little white snowflake dots on it
        x = -2.4 + k * 1.2
        b.span((x - 0.18, CD_Y + 1.05, CTR_Z0 - 0.07), (x + 0.18, CD_Y + 1.15, CTR_Z0 - 0.04), "milk")
        b.span((x - 0.05, CD_Y + 0.92, CTR_Z0 - 0.07), (x + 0.05, CD_Y + 1.28, CTR_Z0 - 0.04), "milk")
    b.span((-HUT_X, CTR_Y - 0.15, CTR_Z0 - 0.15), (HUT_X, CTR_Y, CTR_Z1 + 0.1), LOG_DARK)              # the top


def _cocoa_awning(b):
    """A red and white striped awning over the counter on two log posts, tilted back up, snow on it and icicles."""
    R = rot_x(AWN_TILT)
    c = Vector(AWN_C)
    n, w = 8, (2 * HUT_X + 0.9) / 8
    for k in range(n):
        x = -(2 * HUT_X + 0.9) / 2 + w * (k + 0.5)
        b.box(tuple(c + R @ Vector((x, 0, 0))), (w + 0.002, 0.12, AWN_D), ("shirt_red", "milk")[k % 2], rot=R)
    b.box(tuple(c + R @ Vector((0, 0.15, AWN_D * 0.22))), (2 * HUT_X + 0.7, 0.18, AWN_D * 0.5), "milk", rot=R)  # snow
    for k, (x, d) in enumerate(((-2.6, 0.9), (0.4, 1.3), (2.9, 0.7))):          # drifts of it reaching down the front
        b.box(tuple(c + R @ Vector((x, 0.14, -AWN_D * 0.05 - d / 2))), (1.6 - 0.3 * k, 0.16, d), "milk", rot=R)
    front = c + R @ Vector((0, 0, -AWN_D / 2))
    for k in range(n):                                                    # its scalloped front, a flap a stripe
        x = -(2 * HUT_X + 0.9) / 2 + w * (k + 0.5)
        b.span((x - w / 2 + 0.03, front.y - 0.42, front.z - 0.08), (x + w / 2 - 0.03, front.y + 0.02, front.z - 0.02),
               ("shirt_red", "milk")[k % 2])
    for k in range(6):                                                    # icicles under the flap
        x = -3.0 + k * 1.2 + 0.3 * (k % 2)
        h = 0.35 + 0.2 * (k % 3)
        b.span((x - 0.07, front.y - 0.42 - h, front.z - 0.09), (x + 0.07, front.y - 0.4, front.z - 0.01), "pastel_sky")
    for sx in (-1, 1):                                                    # the posts
        b.cyl((sx * (HUT_X + 0.15), (CD_Y + front.y) / 2, front.z + 0.25), 0.16, front.y - CD_Y, LOG, segments=8)
    return front


def _cocoa_pot(b, glow):
    """A big red cocoa pot with a white rim on a round warmer (lit), a ladle in it, cocoa inside."""
    x, z = 2.1, -0.85
    glow.cyl((x, CTR_Y + 0.06, z), 0.52, 0.12, "eye_amber", segments=12)
    b.cyl((x, CTR_Y + 0.02, z), 0.6, 0.04, "concrete", segments=12)
    b.cyl((x, CTR_Y + 0.66, z), 0.5, 1.0, "shirt_red", r2=0.56, segments=12)
    b.cyl((x, CTR_Y + 1.18, z), 0.6, 0.08, "milk", segments=12)
    b.cyl((x, CTR_Y + 1.13, z), 0.5, 0.04, "choco", segments=12)
    for sx in (-1, 1):
        b.span((x + sx * 0.56, CTR_Y + 0.85, z - 0.08), (x + sx * 0.7, CTR_Y + 0.95, z + 0.08), "milk")   # handles
    b.box((x - 0.15, CTR_Y + 1.45, z + 0.15), (0.06, 0.9, 0.06), "metal", rot=rot_x(18))               # the ladle
    _anchor(COCOA, "Steam", (x, CTR_Y + 1.25, z))


def _cocoa_mugs(b):
    for k, sw in enumerate(("milk", "eye_blue", "leaf_green", "pastel_butter")):
        x, z = -2.6 + k * 0.85, -0.85 + 0.12 * (k % 2)
        b.cyl((x, CTR_Y + 0.2, z), 0.2, 0.4, sw, segments=10)
        b.cyl((x, CTR_Y + 0.39, z), 0.165, 0.03, "choco", segments=10)
        b.span((x + 0.19, CTR_Y + 0.1, z - 0.04), (x + 0.3, CTR_Y + 0.3, z + 0.04), sw)                  # handle
        b.span((x - 0.07, CTR_Y + 0.39, z - 0.05), (x + 0.05, CTR_Y + 0.48, z + 0.07), "offwhite")       # marshmallow


def _cocoa_sign(b, x, z):
    """HOT COCOA on a cream board on a log post with a snowy cap. Returns the board's top."""
    b.cyl((x, CD_Y + 1.7, z), 0.22, 3.4, LOG, segments=8)
    hw, y0, y1 = 1.55, CD_Y + 3.4, CD_Y + 4.8
    b.span((x - hw, y0, z - 0.12), (x + hw, y1, z + 0.12), LOG_DARK)
    b.span((x - hw + 0.12, y0 + 0.12, z - 0.15), (x + hw - 0.12, y1 - 0.12, z - 0.12), "cream")
    _label_front(b, "HOT", x, y0 + 0.75, z - 0.15, 0.09, 0.04, "shirt_red")
    _label_front(b, "COCOA", x, y0 + 0.2, z - 0.15, 0.09, 0.04, "choco")
    b.span((x - hw - 0.12, y1, z - 0.22), (x + hw + 0.12, y1 + 0.22, z + 0.22), "milk")                  # snow on it
    return (x, y1 + 0.22, z)


def _cocoa_pine(b, x, z):
    b.cyl((x, CD_Y + 0.5, z), 0.2, 1.0, LOG, segments=6)
    for i, (r, y) in enumerate(((1.0, 1.4), (0.75, 2.3), (0.45, 3.1))):
        b.cyl((x, CD_Y + y, z), r, 1.0, "leaf_dark", r2=r * 0.35, segments=8)
        b.cyl((x, CD_Y + y + 0.38, z), r * 0.55, 0.22, "milk", r2=r * 0.3, segments=8)


def _cocoa_logs(b, x, z):
    for i, (dx, dy) in enumerate(((-0.3, 0.0), (0.3, 0.0), (0.0, 0.5))):
        b.cyl((x + dx, CD_Y + 0.26 + dy, z), 0.26, 1.3, (LOG, "fur_hazel", LOG)[i], axis="Z", segments=8)
    b.ball((x, CD_Y + 1.0, z), 0.4, "milk", scale=(1.3, 0.35, 1.6))


def build_cocoa_stand(mat):
    b, glow = RB(), RB()
    _cocoa_deck(b)
    _cocoa_hut(b)
    _cocoa_counter(b)
    _cocoa_pot(b, glow)
    _cocoa_mugs(b)
    _cocoa_awning(b)
    top = _cocoa_sign(b, -CD_X + 0.4, CD_Z0 + 0.45)
    _cocoa_pine(b, CD_X - 0.55, 1.2)
    _cocoa_logs(b, CD_X - 0.6, -1.6)
    _anchor(COCOA, "PromptAnchor", (0.0, 1.5, CTR_Z0 - 1.0))
    _anchor(COCOA, "BangAnchor", (top[0], top[1] + 2.0, top[2]))
    _anchor(COCOA, "GlowAnchor", (0.0, CTR_Y + 1.6, -0.6))
    return [b.finalize(COCOA, mat), glow.finalize(COCOA + "_Glow", mat)]


# ------------------------------------------------------------------------------------------- the Dragon Keep --
KEEP = "CatCafe_Camp_Castle_DragonKeep"
KEEP_R, KEEP_WALL_H, KEEP_FLOOR = 7.0, 1.7, 0.3                # the yard: radius, wall height, paving top
KEEP_GATE = 44.0                                              # the gate's opening, degrees round the front (-Z)
STONE, STONE_DARK, STONE_LIGHT = "concrete", "concrete_dark", "fur_pewter"


def build_dragon_keep(mat):
    """#4062 (ticket-booth-and-dragon-keep.md 2.10): a round stone keep yard 14 across. A low wall with merlons rings
    it, open at the front (-Z) under a gate arch with a banner; a crescent of gold lies round the back, with the
    dragon's spot in the middle (Attachment DragonSpot) and a cushion for the Hatchling (`_Cushion`, pivot at its top
    centre; hide it from stage 2). Four torches burn on the wall (`_Flame`, Neon). The gold is `_Gold` (and its
    jewels `_Gold_Glow`), so the pile can be shown fuller as he grows. Attachments: PromptAnchor (the gate, 1.5 up),
    BangAnchor (2 over the arch), DragonSpot (the yard's middle, on the paving), CatSpot1 to CatSpot12 (where the
    cats that moved in nap, round the gold)."""
    b, gold_, glow, flame, cush = RB(), RB(), RB(), RB(), RB()
    b.cyl((0, KEEP_FLOOR / 2, 0), KEEP_R + 0.5, KEEP_FLOOR, STONE_DARK, segments=20)
    b.cyl((0, KEEP_FLOOR + 0.02, 0), KEEP_R - 0.7, 0.04, "paving_tan", segments=20)
    b.cyl((0, KEEP_FLOOR + 0.05, 0), 3.2, 0.04, "paving_light", segments=16)        # the dragon's round
    n = 20
    for k in range(n):                                                             # the wall, open at the gate
        a = 360.0 * (k + 0.5) / n - 90.0                                           # -90 is the front
        if abs(((a + 90 + 180) % 360) - 180) < KEEP_GATE / 2:
            continue
        ar = math.radians(a)
        x, z = KEEP_R * math.cos(ar), KEEP_R * math.sin(ar)
        seg = 2 * math.pi * KEEP_R / n
        R = rot_y(-a + 90)
        b.box((x, KEEP_FLOOR + KEEP_WALL_H / 2, z), (seg + 0.1, KEEP_WALL_H, 0.9), (STONE, STONE_LIGHT)[k % 2], rot=R)
        b.box((x, KEEP_FLOOR + KEEP_WALL_H + 0.3, z), (seg * 0.5, 0.6, 0.9), STONE_LIGHT, rot=R)      # merlon
        b.box((x * 0.985, KEEP_FLOOR + 0.25, z * 0.985), (seg * 0.6, 0.5, 1.1), "fur_moss" if k % 3 == 0 else STONE_DARK,
              rot=R)                                                               # footing, mossy here and there
    gx = KEEP_R * math.sin(math.radians(KEEP_GATE / 2)) + 0.5                       # the gate posts
    gz = -KEEP_R * math.cos(math.radians(KEEP_GATE / 2))
    top = KEEP_FLOOR + 4.6
    for sx in (-1, 1):
        b.box((sx * gx, KEEP_FLOOR + 2.3, gz), (1.5, 4.6, 1.5), STONE)
        b.box((sx * gx, top + 0.25, gz), (1.9, 0.5, 1.9), STONE_LIGHT)
        for (dx, dz) in ((-0.65, -0.65), (0.65, -0.65), (-0.65, 0.65), (0.65, 0.65)):
            b.box((sx * gx + dx, top + 0.75, gz + dz), (0.5, 0.5, 0.5), STONE_LIGHT)
        b.cyl((sx * gx, top + 1.5, gz), 0.75, 1.3, "royal_berry", r2=0.05, segments=8)   # a little roof
    for k in range(7):                                                             # the arch between them
        a = math.radians(180.0 * (k + 0.5) / 7)
        b.box((gx * math.cos(a) * 0.86, KEEP_FLOOR + 3.4 + 1.3 * math.sin(a), gz), (gx * 0.5, 0.7, 1.1),
              (STONE_LIGHT, STONE)[k % 2], rot=rot_z(math.degrees(a) + 90))
    b.box((0, KEEP_FLOOR + 3.55, gz - 0.6), (1.5, 1.7, 0.08), "royal_berry")         # the banner
    b.box((0, KEEP_FLOOR + 3.7, gz - 0.66), (0.7, 0.7, 0.06), "gold_mid", rot=rot_z(45))
    b.box((0, KEEP_FLOOR + 4.45, gz - 0.6), (1.8, 0.14, 0.14), "dark_wood")
    # the gold: a crescent of heaps round the back, coins spilling toward the middle
    heaps = ((-4.0, 1.6, 1.5, 1.2), (-2.6, 3.6, 1.9, 1.7), (0.0, 4.6, 2.3, 2.2), (2.6, 3.6, 1.9, 1.6),
             (4.0, 1.6, 1.5, 1.1), (-1.3, 4.9, 1.4, 1.3), (1.4, 5.0, 1.4, 1.2))
    for k, (x, z, r, h) in enumerate(heaps):
        gold_.cyl((x, KEEP_FLOOR + h * 0.3, z), r, h * 0.6, "gold_mid", r2=r * 0.62, segments=10)
        gold_.cyl((x, KEEP_FLOOR + h * 0.8, z), r * 0.62, h * 0.4, "gold_light", r2=r * 0.2, segments=8)
    for k in range(18):                                                            # loose coins
        a = math.radians(20 + k * 23.0)
        r = 3.4 + (k * 37 % 10) * 0.12
        if math.sin(a) < -0.2:
            continue
        gold_.cyl((r * math.cos(a), KEEP_FLOOR + 0.1, r * math.sin(a)), 0.22, 0.07, ("gold_light", "gold_dark")[k % 2],
                  segments=8)
    for k, (x, y, z, sw) in enumerate(((-2.4, 2.0, 3.5, "rarity_mythic"), (0.3, 2.55, 4.5, "fish_blue"),
                                       (2.7, 1.95, 3.4, "eye_green"), (-3.9, 1.5, 1.7, "rarity_epic"),
                                       (4.0, 1.4, 1.5, "fish_blue"), (1.2, 1.5, 5.2, "rarity_mythic"))):
        glow.box((x, KEEP_FLOOR + y - 0.3, z), (0.4, 0.4, 0.4), sw, rot=rot_x(45) @ rot_z(45))
    gold_.box((-0.9, KEEP_FLOOR + 1.95, 4.2), (0.9, 0.7, 0.7), "dark_wood", rot=rot_y(20))          # a half-buried chest
    gold_.box((-0.9, KEEP_FLOOR + 2.32, 4.2), (0.96, 0.12, 0.76), "brass", rot=rot_y(20))
    gold_.cyl((2.0, KEEP_FLOOR + 1.75, 4.6), 0.4, 0.5, "gold_dark", r2=0.25, segments=8)             # a goblet
    # the Hatchling's cushion, in front of the gold
    cush.box((0, -0.2, 0), (2.1, 0.4, 2.1), "royal_berry")
    cush.box((0, -0.03, 0), (1.7, 0.08, 1.7), "blush")
    for (dx, dz) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cush.box((dx * 1.05, -0.2, dz * 1.05), (0.22, 0.22, 0.22), "gold_mid", rot=rot_y(45))
    # torches on the wall
    for a in (-35.0, 35.0, 145.0, 215.0):
        ar = math.radians(a)
        x, z = (KEEP_R - 0.75) * math.cos(ar), (KEEP_R - 0.75) * math.sin(ar)
        b.box((x, KEEP_FLOOR + 1.5, z), (0.18, 3.0, 0.18), "dark_wood")
        b.cyl((x, KEEP_FLOOR + 3.05, z), 0.3, 0.3, "fur_gunmetal", r2=0.2, segments=8)
        flame.box((x, KEEP_FLOOR + 3.45, z), (0.34, 0.5, 0.34), "fur_orange", rot=rot_y(45))
        flame.box((x, KEEP_FLOOR + 3.8, z), (0.2, 0.36, 0.2), "sparkle", rot=rot_y(45))
    _anchor(KEEP, "PromptAnchor", (0.0, KEEP_FLOOR + 1.5, gz - 1.2))
    _anchor(KEEP, "BangAnchor", (0.0, KEEP_FLOOR + 7.0, gz))
    _anchor(KEEP, "DragonSpot", (0.0, KEEP_FLOOR + 0.07, 0.0))
    spots = [(5.3, d) for d in (200, 220, 240, 300, 320, 340, 180, 0)] + [(3.9, d) for d in (205, 335, 250, 290)]
    for k, (r, deg) in enumerate(spots):                                           # the cats' nap spots
        a = math.radians(deg)
        _anchor(KEEP, "CatSpot%d" % (k + 1), (r * math.cos(a), KEEP_FLOOR + 0.07, r * math.sin(a)))
    return [b.finalize(KEEP, mat), gold_.finalize(KEEP + "_Gold", mat), glow.finalize(KEEP + "_Gold_Glow", mat),
            flame.finalize(KEEP + "_Flame", mat),
            cush.finalize(KEEP + "_Cushion", mat, location=(0.0, KEEP_FLOOR + 0.47, 0.0))]


# ------------------------------------------------------------------------------------------ the Ticket Booth --
BOOTH = "CatCafe_Camp_WaterPark_TicketBooth"
TB_X, TB_Z0, TB_Z1, TB_H = 4.0, -1.6, 1.6, 5.2                 # the kiosk: half width, front, back, wall top
TB_SIGN_Y, TB_SIGN_R = 9.4, 2.3                               # the ticket wheel sign: hub height, radius


def build_ticket_booth(mat):
    """#4061 (ticket-booth-and-dragon-keep.md 1.5): a red and white striped kiosk 8 wide on a blue deck, a round
    ticket window in its front (-Z) with a counter under it and prize plushies hanging inside, a scalloped awning,
    and a big ticket wheel sign on the roof. The sign is `_Sign_Spin`, one Model pivoted at its hub with the pivot's Y
    axis to the front, so Effects spins it like every _Spin; it is for looks only. `_Glow` is the bulbs round the
    window and on the sign's post (Neon). Attachments: PromptAnchor (the window's counter, 1.5 up), BangAnchor (2
    over the sign)."""
    b, glow, spin = RB(), RB(), RB()
    b.span((-TB_X - 0.6, 0, TB_Z0 - 1.4), (TB_X + 0.6, 0.3, TB_Z1 + 0.5), "shirt_blue")          # the deck
    b.span((-TB_X - 0.4, 0.3, TB_Z0 - 1.2), (TB_X + 0.4, 0.34, TB_Z1 + 0.3), "pastel_sky")
    n = 8
    for k in range(n):                                                                         # striped walls
        x0 = -TB_X + 2 * TB_X * k / n
        sw = ("shirt_red", "milk")[k % 2]
        if k in (3, 4):                                                                        # the window's column
            b.span((x0, 0.3, TB_Z0), (x0 + 2 * TB_X / n, 1.9, TB_Z0 + 0.3), sw)
            b.span((x0, 4.3, TB_Z0), (x0 + 2 * TB_X / n, TB_H, TB_Z0 + 0.3), sw)
        else:
            b.span((x0, 0.3, TB_Z0), (x0 + 2 * TB_X / n, TB_H, TB_Z0 + 0.3), sw)
        b.span((x0, 0.3, TB_Z1 - 0.3), (x0 + 2 * TB_X / n, TB_H, TB_Z1), sw)
    for sx in (-1, 1):
        for k in range(4):
            z0 = TB_Z0 + 0.3 + (TB_Z1 - TB_Z0 - 0.6) * k / 4
            b.span((sx * TB_X - (0.3 if sx > 0 else 0), 0.3, z0), (sx * TB_X + (0.3 if sx < 0 else 0), TB_H,
                                                                 z0 + (TB_Z1 - TB_Z0 - 0.6) / 4),
                   ("milk", "shirt_red")[k % 2])
    b.span((-TB_X + 0.3, 0.3, TB_Z0 + 0.3), (TB_X - 0.3, 0.5, TB_Z1 - 0.3), "dark_wood")         # the floor inside
    b.span((-0.95, 1.9, TB_Z0 + 0.32), (0.95, 4.3, TB_Z0 + 0.4), "night_sky")                   # the dark inside
    for k in range(12):                                                                        # the round window's rim
        a = math.radians(30.0 * k + 15)
        b.box((1.25 * math.cos(a), 3.1 + 1.25 * math.sin(a), TB_Z0 - 0.06), (0.72, 0.3, 0.2), "gold_mid",
              rot=rot_z(30.0 * k + 15 + 90))
        if k % 2 == 0:
            glow.ball((1.62 * math.cos(a), 3.1 + 1.62 * math.sin(a), TB_Z0 - 0.1), 0.14, "sparkle")
    b.span((-1.7, 1.75, TB_Z0 - 0.75), (1.7, 1.95, TB_Z0 + 0.1), "caramel_wood")                # the counter
    b.span((-1.5, 1.2, TB_Z0 - 0.5), (-1.3, 1.75, TB_Z0), "dark_wood")
    b.span((1.3, 1.2, TB_Z0 - 0.5), (1.5, 1.75, TB_Z0), "dark_wood")
    b.span((0.5, 1.95, TB_Z0 - 0.6), (1.2, 2.12, TB_Z0 - 0.2), "pastel_butter")                 # a roll of tickets
    b.cyl((0.85, 2.3, TB_Z0 - 0.4), 0.2, 0.3, "pastel_butter", axis="X", segments=8)
    # prize plushies hanging in the window: a cat, a fish and a star
    b.span((-0.72, 3.3, TB_Z0 + 0.05), (-0.28, 3.7, TB_Z0 + 0.3), "fur_orange")
    for sx in (-1, 1):
        b.box((-0.5 + sx * 0.15, 3.76, TB_Z0 + 0.17), (0.12, 0.14, 0.12), "fur_orange")
    b.span((-0.6, 3.05, TB_Z0 + 0.1), (-0.4, 3.3, TB_Z0 + 0.26), "fur_cream")
    b.box((0.0, 3.3, TB_Z0 + 0.17), (0.5, 0.26, 0.16), "fish_blue")
    b.box((0.3, 3.3, TB_Z0 + 0.17), (0.2, 0.2, 0.12), "fish_blue", rot=rot_z(45))
    b.box((0.55, 3.55, TB_Z0 + 0.17), (0.3, 0.3, 0.14), "rarity_legend", rot=rot_z(45))
    for x in (-0.5, 0.0, 0.55):
        b.span((x - 0.02, 3.72, TB_Z0 + 0.15), (x + 0.02, 4.3, TB_Z0 + 0.19), "milk")
    # the roof and the scalloped awning over the front
    b.span((-TB_X - 0.3, TB_H, TB_Z0 - 0.3), (TB_X + 0.3, TB_H + 0.35, TB_Z1 + 0.3), "shirt_blue")
    b.span((-TB_X + 0.4, TB_H + 0.35, TB_Z0 + 0.4), (TB_X - 0.4, TB_H + 0.7, TB_Z1 - 0.4), "pastel_sky")
    for k in range(n):
        x0 = -TB_X - 0.3 + (2 * TB_X + 0.6) * k / n
        w = (2 * TB_X + 0.6) / n
        sw = ("milk", "shirt_red")[k % 2]
        b.box((x0 + w / 2, TB_H - 0.25, TB_Z0 - 0.95), (w, 0.12, 1.5), sw, rot=rot_x(-20))
        b.cyl((x0 + w / 2, TB_H - 0.6, TB_Z0 - 1.62), w / 2, 0.1, sw, axis="Z", segments=8)      # the scallop
    # the sign: a post, and the ticket wheel that spins on it
    b.span((-0.25, TB_H + 0.7, -0.25), (0.25, TB_SIGN_Y, 0.25), "dark_wood")
    b.span((-1.6, TB_H + 0.7, -0.5), (1.6, TB_H + 1.5, -0.3), "milk")                           # TICKETS board
    b.text("TICKETS", (1.4, TB_H + 0.85, -0.5), 0.1, 0.05, "shirt_red", right=(-1, 0, 0))   # read from the front
    for sx in (-1, 1):
        glow.ball((sx * 1.75, TB_H + 1.1, -0.4), 0.16, "sparkle")
    hub = (0.0, TB_SIGN_Y, -0.45)
    spin.cyl((0, 0, 0), TB_SIGN_R, 0.2, "milk", axis="Z", segments=16)
    spin.cyl((0, 0, -0.06), TB_SIGN_R - 0.3, 0.2, "shirt_red", axis="Z", segments=16)
    spin.cyl((0, 0, -0.14), 0.4, 0.2, "gold_mid", axis="Z", segments=10)
    for k in range(8):                                                                         # eight tickets round it
        a = 45.0 * k
        ar = math.radians(a)
        r = TB_SIGN_R - 1.05
        spin.box((r * math.cos(ar), r * math.sin(ar), -0.19), (1.0, 0.55, 0.08), ("pastel_butter", "milk")[k % 2],
                 rot=rot_z(a))
        spin.box((r * math.cos(ar), r * math.sin(ar), -0.24), (0.3, 0.3, 0.06), ("shirt_red", "shirt_blue")[k % 2],
                 rot=rot_z(a + 45))
        spin.box((TB_SIGN_R * math.cos(ar + 0.39), TB_SIGN_R * math.sin(ar + 0.39), 0.0), (0.3, 0.3, 0.24), "gold_mid",
                 rot=rot_z(a + 22.5))
    _anchor(BOOTH, "PromptAnchor", (0.0, 1.5 + 0.3, TB_Z0 - 1.3))
    _anchor(BOOTH, "BangAnchor", (0.0, TB_SIGN_Y + TB_SIGN_R + 2.0, -0.45))
    return [b.finalize(BOOTH, mat), glow.finalize(BOOTH + "_Glow", mat),
            spin.finalize(BOOTH + "_Sign_Spin", mat, location=hub)]


# #1800: the moving child Models' own numbers for Effects/Motion (rbx_export model_attributes), by asset
MOVING = {YARD: {"model_attributes": {"_Sign_Swing": {"Angle": {"Float64": SIGN_ANGLE}}}},
          KEEP: {"nest": {"_Gold_Glow": "_Gold"}},   # #4062: the jewels ride the gold
          # #4061: the ticket wheel faces the front, so its _Spin pivot's Y axis is turned onto -Z
          BOOTH: {"pivot_turns": {"_Spin": Matrix.Rotation(math.radians(-90), 3, "X")}}}


# ------------------------------------------------------------------------------------ the Fusion Observatory --
OBS = "CatCafe_Camp_Snowy_FusionObservatory"
OBS_R, OBS_WALL, OBS_DOME = 5.0, 4.2, 4.7                      # the tower: radius, wall top, the dome's radius
OBS_TOP = OBS_WALL + 0.5 + OBS_DOME                            # the dome's crown


def _obs_arc(b, r, a0, a1, n, width, thick, swatch):
    """A band over the dome along the front to back meridian, from a0 to a1 degrees up from the front (-Z) horizon."""
    y0 = OBS_WALL + 0.5
    seg = math.radians(a1 - a0) / n * r + 0.06
    for k in range(n):
        a = a0 + (a1 - a0) * (k + 0.5) / n
        ar = math.radians(a)
        b.box((0, y0 + r * math.sin(ar), -r * math.cos(ar)), (width, seg, thick), swatch, rot=rot_x(a))


def build_fusion_observatory(mat):
    b, glow, bulb = RB(), RB(), RB()
    R, W = OBS_R, OBS_WALL
    # the tower: a dark foot, grey stone in two courses, a pale ledge with snow on it
    b.cyl((0, 0.35, 0), R + 0.35, 0.7, "concrete_dark", segments=16)
    b.cyl((0, 0.7 + (W - 0.7) / 2, 0), R, W - 0.7, "concrete", segments=16)
    b.cyl((0, 2.4, 0), R + 0.06, 0.14, "concrete_dark", segments=16)
    b.cyl((0, W + 0.2, 0), R + 0.3, 0.4, "fur_pewter", segments=16)
    b.cyl((0, W + 0.47, 0), R + 0.34, 0.14, "milk", segments=16)                              # snow on the ledge
    # the dome: white, in five rings up to a brass cap
    y0, D = W + 0.5, OBS_DOME
    n = 7
    for k in range(n):
        a0, a1 = math.radians(90.0 * k / n), math.radians(90.0 * (k + 1) / n)
        r0, r1 = D * math.cos(a0), max(D * math.cos(a1), 0.5)
        h = D * (math.sin(a1) - math.sin(a0))
        b.cyl((0, y0 + D * math.sin(a0) + h / 2, 0), r0, h, ("milk", "offwhite")[k % 2], r2=r1, segments=16)
    b.cyl((0, y0 + 0.12, 0), D + 0.12, 0.24, "brass", segments=16)                            # the dome's brass ring
    # the slit: a brass frame from the front horizon over the crown, the lit strip in it
    _obs_arc(b, D + 0.0, 5.0, 119.0, 9, 1.6, 0.3, "brass")
    _obs_arc(glow, D + 0.1, 8.0, 116.0, 9, 1.0, 0.3, "pastel_butter")
    # the telescope out of the slit, short enough to stay inside the paw lights' circle (1.15 R)
    ta = math.radians(52.0)
    for (d, w, ln, sw) in ((D + 0.5, 0.75, 2.6, "brass"), (D + 1.9, 0.95, 0.5, "gold_dark"), (D - 0.6, 1.05, 0.5, "gold_dark")):
        b.box((0, y0 + d * math.sin(ta), -d * math.cos(ta)), (w, ln, w), sw, rot=rot_x(52.0 - 90.0))
    # the door, two steps, a lantern over it
    b.span((-1.1, 0.7, -R - 0.12), (1.1, 3.5, -R + 0.3), "dark_wood")
    b.span((-0.9, 0.7, -R - 0.2), (0.9, 3.3, -R - 0.1), "caramel_wood")
    b.span((-0.06, 0.7, -R - 0.24), (0.06, 3.3, -R - 0.18), "dark_wood")
    b.ball((0.55, 1.95, -R - 0.26), 0.12, "brass")
    b.span((-1.3, 3.5, -R - 0.3), (1.3, 3.75, -R + 0.3), "fur_pewter")
    b.span((-1.35, 3.75, -R - 0.34), (1.35, 3.87, -R + 0.3), "milk")
    b.span((-1.6, 0.0, -R - 1.5), (1.6, 0.35, -R + 0.2), "fur_pewter")
    b.span((-1.3, 0.35, -R - 0.9), (1.3, 0.7, -R + 0.2), "fur_pewter")
    b.span((1.5, 2.9, -R - 0.5), (1.62, 3.0, -R + 0.1), "dark_wood")                           # the lantern's arm
    b.span((1.4, 2.25, -R - 0.62), (1.72, 2.3, -R - 0.3), "dark_wood")
    b.span((1.4, 2.85, -R - 0.62), (1.72, 2.9, -R - 0.3), "dark_wood")
    bulb.span((1.44, 2.3, -R - 0.58), (1.68, 2.85, -R - 0.34), "lamp_warm")
    # star windows round the wall and a snowdrift or two at its foot
    for k, deg in enumerate((-40.0, 40.0, 130.0, 180.0, 230.0)):
        a = math.radians(deg - 90.0)
        x, z = (R + 0.02) * math.cos(a), (R + 0.02) * math.sin(a)
        Rm = rot_y(-(deg - 90.0) + 90.0)
        b.box((x, 3.0, z), (1.0, 1.0, 0.16), "dark_wood", rot=Rm @ rot_z(45))
        bulb.box((x * 1.012, 3.0, z * 1.012), (0.72, 0.72, 0.16), "lamp_warm", rot=Rm @ rot_z(45))
    for (x, z, s) in ((-4.6, 2.6, 1.0), (4.4, 3.0, 1.2), (3.9, -3.6, 0.8), (-0.4, 5.3, 1.1)):
        b.ball((x, 0.0, z), 1.3 * s, "milk", scale=(1.3, 0.45, 1.0))
    # the sign on a log post, left of the door, outside the lights' circle and under it
    sx_, sz_ = -6.9, -3.6
    b.cyl((sx_, 1.7, sz_), 0.22, 3.4, "fur_brown", segments=8)
    hw, s0, s1 = 2.1, 3.4, 4.9
    b.span((sx_ - hw, s0, sz_ - 0.12), (sx_ + hw, s1, sz_ + 0.12), "dark_wood")
    b.span((sx_ - hw + 0.12, s0 + 0.12, sz_ - 0.15), (sx_ + hw - 0.12, s1 - 0.12, sz_ - 0.12), "pants_navy")
    _label_front(b, "FUSION", sx_, s0 + 0.8, sz_ - 0.15, 0.09, 0.04, "pastel_butter")
    _label_front(b, "OBSERVATORY", sx_, s0 + 0.22, sz_ - 0.15, 0.065, 0.04, "offwhite")
    b.span((sx_ - hw - 0.12, s1, sz_ - 0.22), (sx_ + hw + 0.12, s1 + 0.22, sz_ + 0.22), "milk")
    b.box((sx_, s1 + 0.75, sz_), (0.7, 0.7, 0.14), "rarity_legend", rot=rot_z(45))               # a gold star on it
    _anchor(OBS, "PromptAnchor", (0.0, 1.5 + 0.7, -R - 1.6))
    _anchor(OBS, "BangAnchor", (sx_, s1 + 1.25 + 2.0, sz_))
    _anchor(OBS, "GlowAnchor", (0.0, 0.7 * OBS_TOP, 0.0))
    return [b.finalize(OBS, mat), glow.finalize(OBS + "_Slit_Glow", mat), bulb.finalize(OBS + "_Bulb", mat)]


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
    SPA: (build_oasis_spa, 5000),
    SPA_TOWEL: (build_spa_towel, 200),
    MUSEUM: (build_relic_museum, 12000),
    BIN: (build_rummage_bin, 2500),
    COCOA: (build_cocoa_stand, 6000),
    KEEP: (build_dragon_keep, 6000),
    BOOTH: (build_ticket_booth, 6000),
    OBS: (build_fusion_observatory, 6000),
}
