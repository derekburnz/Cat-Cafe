"""Items: food bowls, lure foods (kibble, tuna, salmon, the four dealer foods), nets, the rich
customer's tip pile. Pivot base center. Dealer foods sit on the kibble in CatCafe_Item_FoodBowl:
put their pivot at the bowl's pivot plus FOOD_IN_BOWL up."""

import math

from mathutils import Matrix, Vector

from common import Builder

FOOD_IN_BOWL = 0.18      # kibble top in CatCafe_Item_FoodBowl, studs above its pivot
GRIP = 0.36              # a net's grip wrap centre, studs along the pole from its end
FOODS = ("Sardines", "Caviar", "MoonMilk", "StarTreat", "HoneyCream", "CometTreat")     # the dealer and Day Cart (#3462) foods that sit in a bowl


def _bowl(b, outer, rim, food, premium=False):
    b.cyl_base((0, 0, 0), 0.45, 0.06, outer, segments=12, bevel=False)
    b.ring((0, 0, 0.18), 0.46, 0.08, 0.26, outer, segments=12, bevel=False)
    if premium:
        b.ring((0, 0, 0.32), 0.48, 0.06, 0.06, rim, segments=12, bevel=False)
    if food:
        b.cyl_base((0, 0, 0.06), 0.38, 0.12, food, segments=12, bevel=False)


def build_food_bowl(mat):
    b = Builder()
    _bowl(b, "bowl_red", None, "kibble")
    return [b.finalize("CatCafe_Item_FoodBowl", mat)]


def build_food_bowl_premium(mat):
    b = Builder()
    _bowl(b, "blush", "rarity_legend", "fish_belly", premium=True)
    b.sphere((0, 0.05, 0.3), 0.22, "fish_blue", segments=8, rings=4, scale=(0.7, 1.3, 0.6))
    b.pyramid((0, 0.42, 0.22), 0.22, 0.22, "fish_blue", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_FoodBowl_Premium", mat)]


# Studio 2026-11-13 (Review-QA): each food's top is at least 0.3 studs over the bowl's rim once placed (food x1.2 on
# the floor, bowl x2), so it reads from the side: a top of 0.5 above the food's pivot. The kibble heap is HEAP_UP of a
# 0.72 ball, centred HEAP_Z up; _heap_top(x, y) is its surface there.
HEAP_Z, HEAP_UP = 0.14, 0.85


def _heap_top(x, y, z0=HEAP_Z, r=0.36, up=HEAP_UP):
    q = max(0.0, 1 - (x * x + y * y) / (r * r))
    return z0 + r * up * math.sqrt(q)


def _bed(b, r, top):
    """A low heap of kibble under a food that lies flat (the salmon, the sardines): its top `top` up, `r` across,
    with a few round bits on it."""
    up = top / r
    b.sphere((0, 0, 0), r, "kibble", segments=12, rings=5, scale=(1, 1, up))
    for (x, y, sw) in ((0.18, 0.12, "treat_tan"), (-0.2, -0.08, "fur_caramel"), (0.06, -0.22, "kibble"),
                       (-0.1, 0.2, "treat_tan")):
        q = max(0.0, 1 - (x * x + y * y) / (r * r))
        b.cyl((x, y, r * up * math.sqrt(q)), 0.06, 0.04, sw, segments=8, bevel=False,
              rot=_rz(40 * x / 0.2) @ Matrix.Rotation(math.radians(25), 3, "X"))


def build_kibble(mat):
    """#3945 a heap of kibble on the bowl's floor: round bits and little fish-shaped bits in three bakes, a few tipped
    up on the heap so it reads as a pile from the street (it was a bag standing in the bowl)."""
    b = Builder()
    # Studio 2026-11-13: heaped up so it shows over the bowl's rim (it sat level with it)
    b.sphere((0, 0, HEAP_Z), 0.36, "kibble", segments=12, rings=6, scale=(1, 1, HEAP_UP))     # the heap under them
    bits = ((0.0, 0.0, 0.1, 0, 0, "kibble"), (0.14, 0.06, 0.08, 30, 20, "treat_tan"),
            (-0.13, 0.09, 0.08, -25, 60, "fur_caramel"), (0.05, -0.15, 0.08, 15, -40, "treat_tan"),
            (-0.07, -0.1, 0.1, -10, 10, "kibble"), (0.2, -0.1, 0.05, 40, 80, "fur_caramel"),
            (-0.22, -0.04, 0.05, -35, 30, "treat_tan"), (0.08, 0.2, 0.05, 20, -15, "kibble"),
            (-0.1, 0.22, 0.04, -30, 45, "treat_tan"), (0.25, 0.12, 0.03, 45, 0, "kibble"))
    for (x, y, z, tilt, turn, sw) in bits:                                                       # round bits
        x, y = 1.25 * x, 1.25 * y                                                                # spread over it
        z += _heap_top(x, y) - 0.05                                                              # on the heap's top
        R = _rz(turn) @ Matrix.Rotation(math.radians(tilt), 3, "X")
        b.cyl((x, y, z), 0.065, 0.04, sw, segments=8, bevel=False, rot=R)
        b.cyl((x, y, z), 0.022, 0.045, "fur_toffee", segments=6, bevel=False, rot=R)           # the hole's shadow
    for (x, y, z, turn, sw) in ((0.02, 0.08, 0.15, 35, "fur_caramel"), (-0.16, -0.14, 0.1, -60, "kibble"),
                                (0.15, -0.2, 0.08, 100, "fur_caramel")):                       # fish-shaped bits
        R = _rz(turn)
        z += _heap_top(x, y) - 0.08
        b.sphere((x, y, z), 0.07, sw, segments=8, rings=4, scale=(0.6, 1.0, 0.45), rot=R)
        tx, ty = -math.sin(math.radians(turn)) * 0.08, math.cos(math.radians(turn)) * 0.08
        b.cyl((x + tx, y + ty, z), 0.04, 0.03, sw, segments=3, bevel=False, rot=R @ _rz(-90))
    return [b.finalize("CatCafe_Item_Kibble", mat)]


def build_tuna_can(mat):
    """#3945 an opened tuna can: a steel can with a blue label and a fish on it, the lid peeled up at the back, flaked
    tuna heaped over the rim."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.33, 0.26, "metal", segments=14)
    b.cyl_base((0, 0, 0.05), 0.335, 0.15, "shirt_blue", segments=14, bevel=False)               # the label
    b.ring((0, 0, 0.255), 0.34, 0.035, 0.03, "fur_silver", segments=14, bevel=False)          # the rolled rim
    b.ring((0, 0, 0.01), 0.34, 0.03, 0.02, "fur_silver", segments=14, bevel=False)
    b.sphere((0.0, -0.338, 0.125), 0.07, "offwhite", segments=8, rings=4, scale=(1.0, 0.15, 0.55))   # fish on it
    b.cyl((0.075, -0.338, 0.125), 0.035, 0.012, "offwhite", segments=3, bevel=False,
          rot=Matrix.Rotation(math.radians(90), 3, "X") @ _rz(180))
    b.sphere((0, 0, 0.27), 0.29, "fur_peach", segments=12, rings=5, scale=(1, 1, 0.32))         # the flaked tuna
    for (x, y, z, r, sw) in ((0.1, 0.05, 0.33, 0.07, "fur_apricot"), (-0.12, 0.02, 0.32, 0.065, "fur_peach"),
                             (0.0, -0.12, 0.33, 0.06, "fur_apricot"), (-0.03, 0.12, 0.35, 0.06, "skin_light"),
                             (0.15, -0.1, 0.3, 0.05, "skin_light")):
        b.ico((x, y, z), r, sw, subdivisions=1, scale=(1.2, 1, 0.7))
    tilt = Matrix.Rotation(math.radians(-70), 3, "X")                                           # the lid, peeled up
    b.cyl((0, 0.36, 0.4), 0.3, 0.025, "fur_silver", segments=14, bevel=False, rot=tilt)
    b.ring((0, 0.355, 0.4), 0.3, 0.03, 0.03, "metal", segments=14, bevel=False, rot=tilt)
    b.box((0, 0.32, 0.43), (0.12, 0.02, 0.05), "metal", bevel=False, rot=tilt)                  # the ring pull
    return [b.finalize("CatCafe_Item_TunaCan", mat)]


def _fish(b, x, y, z, turn, length, back, side, belly, fin, eye=True, tilt=0.0):
    """#3945 a fish lying on its side, head toward -Y before `turn` (degrees about Z), `length` long: a `side` body,
    a `back` stripe along its top edge (+X) and a `belly` along the other, a forked tail, a back fin, a side fin, a
    gill line and an eye with a white."""
    R = _rz(turn) @ Matrix.Rotation(math.radians(tilt), 3, "X")     # tilt < 0 lifts the head
    L = length

    def at(px, py, pz):
        v = R @ Vector((px * L, py * L, pz * L))
        return (x + v.x, y + v.y, z + v.z)

    b.sphere(at(0, 0, 0), 0.5 * L, side, segments=12, rings=6, scale=(0.42, 1.0, 0.24), rot=R)
    b.sphere(at(0.09, 0.02, 0.01), 0.42 * L, back, segments=10, rings=5, scale=(0.26, 1.0, 0.24), rot=R)
    b.sphere(at(-0.09, 0.0, 0.01), 0.4 * L, belly, segments=10, rings=5, scale=(0.24, 0.95, 0.235), rot=R)
    for side_ in (-1, 1):                                                                        # the forked tail
        b.cyl(at(side_ * 0.07, 0.56, 0), 0.13 * L, 0.035 * L, fin, segments=3, bevel=False,
              rot=R @ _rz(-90 + side_ * 25))
    b.cyl(at(0.19, 0.08, 0), 0.12 * L, 0.03 * L, fin, segments=3, bevel=False, rot=R)           # the back fin
    b.sphere(at(-0.04, -0.16, 0.11), 0.09 * L, fin, segments=8, rings=4, scale=(0.5, 1.0, 0.25),
             rot=R @ _rz(25))                                                                    # the side fin
    b.box(at(-0.01, -0.27, 0.095), (0.2 * L, 0.022 * L, 0.03 * L), fin, bevel=False, rot=R @ _rz(-8))  # gill line
    if eye:
        b.sphere(at(0.03, -0.37, 0.09), 0.055 * L, "offwhite", segments=8, rings=4, scale=(1, 1, 0.5), rot=R)
        b.sphere(at(0.03, -0.38, 0.115), 0.032 * L, "fur_black", segments=8, rings=4, scale=(1, 1, 0.5), rot=R)


def build_salmon(mat):
    """#3945 a whole salmon lying on heaped kibble, across the bowl: a peach body with a deeper back, a pearl belly, a
    forked tail and fins (it was a blue fish standing up)."""
    b = Builder()
    _bed(b, 0.34, 0.2)                                                                           # on heaped kibble
    _fish(b, 0, 0, 0.32, 20, 0.95, "fur_ginger", "fur_apricot", "pearl", "fur_copper", tilt=-12)
    return [b.finalize("CatCafe_Item_Salmon", mat)]


def _bar(b, a, c, w, t, swatch, up=(0, 0, 1)):
    """A rod from point a to point c: width w across, thickness t along `up`."""
    a, c = Vector(a), Vector(c)
    y = (c - a).normalized()
    z = Vector(up)
    z = (z - y * z.dot(y)).normalized()
    R = Matrix((y.cross(z), y, z)).transposed()
    b.box(tuple((a + c) / 2), (w, (c - a).length, t), swatch, bevel=False, rot=R)


def _rod(b, a, c, radius, swatch, segments=8, extend=0.0):
    """A round rod from point a to point c (a Cylinder Part), `extend` longer at each end."""
    a, c = Vector(a), Vector(c)
    d = (c - a).normalized()
    helper = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = helper.cross(d).normalized()
    R = Matrix((u, d.cross(u), d)).transposed()
    b.cyl(tuple((a + c) / 2), radius, (c - a).length + 2 * extend, swatch, segments=segments, bevel=False, rot=R)


def _tube_ring(b, hy, rc, rho, swatch, n=12):
    """A round rim: n rods round a ring lying flat in XY at (0, hy, 0), centre line at radius rc, `rho` thick (radius).
    Each rod runs a little past its corner so the outer faces meet; rod 0 is centred on the far point (-Y), so the
    rim's far end is the part farthest from the grip (VFX-Agent's NetTrail trails the whoosh off it)."""
    step = 2 * math.pi / n
    for i in range(n):
        a0 = -math.pi / 2 - step / 2 + i * step
        p0 = (rc * math.cos(a0), hy + rc * math.sin(a0), 0)
        p1 = (rc * math.cos(a0 + step), hy + rc * math.sin(a0 + step), 0)
        _rod(b, p0, p1, rho, swatch, extend=rho * math.tan(step / 2))


def _ear(b, base, out, width, height, thick, swatch):
    """A cat ear lying flat in XY: a triangle `width` across its base at `base`, pointing along `out`, `thick` along
    Z. Two wedges back to back (two WedgeParts in Roblox)."""
    R = Matrix(((0, out.y, out.x), (0, -out.x, out.y), (1, 0, 0)))     # local X up (Z), Y across, Z out
    for side in (-1, 1):
        c = base + R @ Vector((0, side * width / 4, height / 2))
        rot = R if side < 0 else R @ Matrix.Rotation(math.pi, 3, "Z")
        b.wedge(tuple(c), (thick, width / 2, height), swatch, bevel=False, rot=rot)


NET_NAMES = ("Basic", "Sturdy", "Pro", "Master")     # CatCafe_Item_Net_L1 to L4 (catch-rework.md, F93)
# Per level (Derek 2026-11-03: "The net designs should be improved also as they are seen all the time"): pole,
# grip wrap and its rings, metal fittings, rim and netting. L1 Basic is a bamboo garden net with a
# twine grip, L2 Sturdy a mint pole with steel fittings and a steel rim, L3 Pro a blue pole with brass fittings and
# a brass paw badge, L4 Master dark wood and shining gold with cat ears, gems and a little bell.
NET_LOOK = (
    dict(pole="fur_sand", wrap="fur_oat", wrap_ring="fur_toffee", fit="fur_caramel", rim="caramel_wood",
         strand="fur_vanilla"),
    dict(pole="mint", wrap="fur_black", wrap_ring="metal", fit="metal", rim="metal", strand="offwhite"),
    dict(pole="shirt_blue", wrap="pants_navy", wrap_ring="brass", fit="brass", rim="shirt_blue", strand="pastel_sky"),
    dict(pole="dark_wood", wrap="fur_black", wrap_ring="gold_mid", fit="gold_mid", rim="gold_mid",
         strand="pastel_lilac"),
)


def net_knots(level):
    """The netting's knots in the net's own space, (rows, tip): rows[m] is a list of (x, y, z) round the bag, the
    first row tucked under the rim, each next row turned half a mesh so the strands cross in diamonds."""
    k = level - 1
    pole, r = 3.0 + 0.3 * k, 0.9 + 0.15 * k
    rho = 0.07 + 0.01 * k
    hy = -pole - r
    n = 6 if k < 2 else 7
    depth = 1.25 * r                                     # deeper than the 2026-10 bag (1.0 + 0.1 a level)
    rb = r - 2 * rho + 0.02                              # just inside the rim's centre line
    rows = []
    for m, (s, f) in enumerate(((0.0, 1.0), (0.38, 0.92), (0.72, 0.62))):
        off = (math.pi / n) * (m % 2)
        rows.append([(f * rb * math.cos(off + 2 * math.pi * j / n), hy + f * rb * math.sin(off + 2 * math.pi * j / n),
                      -rho * 0.4 - s * depth) for j in range(n)])
    return rows, (0.0, hy, -rho * 0.4 - depth)


def build_net(level, mat):
    """Catching net, held in the right hand all the time (F93; Effects' NetHold puts the Grip in the hand). Pivot at
    the grip end; the pole runs forward (-Y in Blender, -Z in Roblox) to a ferrule and a Y-shaped neck that holds a
    round rim lying flat at the far end, its open face up, and the netting hangs below it. The pole's length, the
    rim's outer size and the Grip are the same as the 2026-10 nets, so the hold, the swing and the reach are
    unchanged. Three objects: `_Handle` (pole, grip wrap, ferrule, neck and the level's trims), `_Hoop` (the rim and
    its trims) and `_Bag` (open diamond-mesh netting in the level's colour, knots crossing in rows round the bag down
    to a knot at its tip; no see-through lining, so it reads as a net and not a lens)."""
    k = level - 1
    L = NET_LOOK[k]
    pole = 3.0 + 0.3 * k
    r = 0.9 + 0.15 * k                        # the rim's outer radius
    rho = 0.07 + 0.01 * k                     # the rim's tube radius
    rc = r - rho
    hy = -pole - r                            # rim centre
    h, hoop, bag = Builder(), Builder(), Builder()
    # pole, from the grip end to the ferrule
    neck_y = -pole + 0.42                     # where the neck leaves the ferrule
    _rod(h, (0, 0.0, 0), (0, neck_y + 0.05, 0), 0.1, L["pole"])
    h.cyl((0, 0.02, 0), 0.135, 0.08, L["fit"], segments=10, rot=(math.radians(90), "X"))             # end cap
    h.cyl((0, -GRIP, 0), 0.13, 0.68, L["wrap"], segments=10, rot=(math.radians(90), "X"))            # grip wrap
    for y in (-0.16, -0.56):
        h.cyl((0, y, 0), 0.138, 0.05, L["wrap_ring"], segments=10, rot=(math.radians(90), "X"))
    h.cyl((0, neck_y + 0.12, 0), 0.13, 0.26, L["fit"], segments=10, rot=(math.radians(90), "X"))    # ferrule
    # the neck: two arms from the ferrule out to the rim, 40 degrees either side of its near point
    for sx in (-1, 1):
        a = math.radians(90 + sx * 40)
        _rod(h, (sx * 0.05, neck_y + 0.02, 0), (rc * math.cos(a), hy + rc * math.sin(a), 0), 0.05 + 0.005 * k,
             L["fit"] if k else L["rim"])
    if k == 0:                                # bamboo: node rings up the pole, twine lashing on the ferrule
        for y in (-1.15, -1.85, -2.5):
            h.cyl((0, y, 0), 0.112, 0.05, "fur_caramel", segments=10, rot=(math.radians(90), "X"))
        for y in (neck_y + 0.06, neck_y + 0.18):
            h.cyl((0, y, 0), 0.142, 0.04, "fur_toffee", segments=10, rot=(math.radians(90), "X"))
    else:                                     # metal bands up the pole
        bands = ((-1.3, -2.1), (-1.25, -2.0, -2.75), (-1.3, -2.2, -3.1))[k - 1]
        for y in bands:
            h.cyl((0, y, 0), 0.118, 0.08, L["fit"], segments=10, rot=(math.radians(90), "X"))
    if k == 2:                                # Pro: a brass paw badge on top of the ferrule
        bz = 0.13
        h.cyl((0, neck_y + 0.12, bz + 0.01), 0.07, 0.03, L["fit"], segments=10)
        for dx, dy in ((-0.075, -0.07), (-0.03, -0.1), (0.03, -0.1), (0.075, -0.07)):
            h.cyl((dx, neck_y + 0.12 + dy, bz + 0.005), 0.025, 0.03, L["fit"], segments=8)
    if k == 3:                                # Master: gold pommel with a pink gem
        h.sphere((0, 0.14, 0), 0.15, L["fit"], segments=10, rings=6)
        h.box((0, -GRIP, 0.13), (0.09, 0.18, 0.04), "neon_pink", bevel=False)
    # the rim
    _tube_ring(hoop, hy, rc, rho, L["rim"])
    if k == 1:                                # Sturdy: steel rivets round the rim
        for a in (0, 90, 180):
            ar = math.radians(a)
            hoop.sphere((rc * math.cos(ar), hy + rc * math.sin(ar), rho * 0.9), rho * 0.55, "concrete_dark",
                        segments=8, rings=4)
    if k == 3:                                # Master: cat ears on the far rim, pink inside, gems at the sides
        for sx in (-1, 1):
            a = math.radians(-90 + sx * 45)      # at 45 degrees the ears stay nearer the grip than the rim's far end
            u = Vector((math.cos(a), math.sin(a), 0))
            base = Vector((0, hy, 0)) + u * (r - 0.04)
            _ear(hoop, base, u, 0.4, 0.34, 2 * rho - 0.02, L["rim"])
            t = Vector((-u.y, u.x, 0))
            tri = [base + u * 0.08 + t * 0.1, base + u * 0.27, base + u * 0.08 - t * 0.1]
            c = sum(tri, Vector()) / 3
            rr = [((v - c).x, (v - c).y) for v in tri]   # pink inside the ear on its open face, proud of the gold
            hoop.fan((c.x, c.y, rho - 0.01 + 0.003), rr[0], rr[1:], 0.016, "nose_pink")
            ag = math.radians(90 + sx * 90)
            hoop.ico((rc * math.cos(ag), hy + rc * math.sin(ag), rho * 0.85), rho * 0.75, "rarity_epic", subdivisions=1)
    # the netting: diamond mesh strands from knot row to knot row, then to the tip knot
    rows, tip = net_knots(level)
    n = len(rows[0])
    w = 0.045
    for m in range(len(rows) - 1):
        for j in range(n):
            a = rows[m][j]
            for jj in ((j, j - 1) if m % 2 == 0 else (j, j + 1)):
                c = rows[m + 1][jj % n]
                mid = Vector(((a[0] + c[0]) / 2, (a[1] + c[1]) / 2 - hy, 0))
                _bar(bag, a, c, w, w, L["strand"], up=tuple(mid.normalized()) if mid.length > 1e-6 else (0, 0, 1))
    for j in range(n):
        a = rows[-1][j]
        mid = Vector(((a[0]) / 2, (a[1] - hy) / 2, 0))
        _bar(bag, a, tip, w, w, L["strand"], up=tuple(mid.normalized()))
    if k == 3:                                # Master: a little gold bell at the tip
        bag.sphere((0, hy, tip[2] - 0.1), 0.13, L["fit"], segments=10, rings=6)
    else:
        bag.sphere((0, hy, tip[2]), 0.06, L["strand"], segments=8, rings=4)
    name = f"CatCafe_Item_Net_L{level}"
    return [h.finalize(name + "_Handle", mat), hoop.finalize(name + "_Hoop", mat), bag.finalize(name + "_Bag", mat)]


def grip_attachment():
    """The hand's spot on a net: the Attachment `Grip` in the middle of the black wrap, on the Handle, with the
    net's own axes (the pole runs -Z in Roblox, the hoop's open face up +Y)."""
    return ("_Handle", "Grip", Matrix.Translation((0.0, -GRIP, 0.0)))


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def build_sardines(mat):
    """#3945 three silver sardines fanned on heaped kibble with blue backs, the middle one on top, head up."""
    b = Builder()
    _bed(b, 0.34, 0.2)                                                                           # on heaped kibble
    for (x, y, z, a, t) in ((-0.15, 0.03, 0.27, 14, 0), (0.16, 0.01, 0.27, -12, 0), (0.0, -0.04, 0.36, 2, -14)):
        _fish(b, x, y, z, a, 0.55, "fish_blue", "fur_silver", "pearl", "fur_mist", tilt=t)
    return [b.finalize("CatCafe_Item_Sardines", mat)]


def build_caviar(mat):
    """#3945 a round caviar tin, navy with a gold rim, heaped with shining black pearls, its lid with a gold fish
    leaning on its side and a pearl spoon across the top."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.27, 0.13, "galaxy_blue", segments=14)
    b.ring((0, 0, 0.13), 0.28, 0.04, 0.03, "gold_mid", segments=14, bevel=False)
    b.ring((0, 0, 0.0), 0.28, 0.04, 0.025, "gold_mid", segments=14, bevel=False)
    b.sphere((0, 0, 0.14), 0.24, "fur_black", segments=12, rings=5, scale=(1, 1, 0.38))         # heaped pearls
    pearls = ((0.08, -0.05, 0.215), (-0.1, 0.06, 0.21), (0.02, 0.12, 0.205), (-0.04, -0.12, 0.205),
              (0.14, 0.08, 0.19), (-0.15, -0.06, 0.19), (0.0, 0.0, 0.23), (0.12, -0.13, 0.18))
    for i, (px, py, pz) in enumerate(pearls):
        b.ico((px, py, pz), 0.04, ("fur_ink", "night_sky")[i % 2], subdivisions=1)
        b.ico((px - 0.012, py - 0.012, pz + 0.025), 0.012, "fur_silver", subdivisions=1)      # each one's shine
    tilt = Matrix.Rotation(math.radians(-72), 3, "X")                                           # the lid, leaning
    b.cyl((0, 0.31, 0.2), 0.27, 0.03, "galaxy_blue", segments=14, bevel=False, rot=tilt)
    b.ring((0, 0.305, 0.2), 0.28, 0.035, 0.035, "gold_mid", segments=14, bevel=False, rot=tilt)
    b.sphere((0, 0.29, 0.21), 0.09, "gold_light", segments=8, rings=4, scale=(1.0, 0.2, 0.5))   # its gold fish
    b.cyl((0.1, 0.29, 0.21), 0.045, 0.015, "gold_light", segments=3, bevel=False,
          rot=Matrix.Rotation(math.radians(90), 3, "X") @ _rz(180))
    b.box((0.12, -0.2, 0.25), (0.05, 0.32, 0.025), "pearl", bevel=False, rot=_rz(-35))           # the spoon
    b.sphere((0.02, -0.05, 0.255), 0.07, "pearl", segments=8, rings=4, scale=(1, 1.35, 0.3), rot=_rz(-35))
    return [b.finalize("CatCafe_Item_Caviar", mat)]


def build_moon_milk(mat):
    """#3945 a lilac saucer of moon milk on the kibble, a pale swirl on the milk, a crescent moon and three stars
    over it."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.05, "pastel_lilac", segments=16, radius2=0.4)                # the saucer
    b.ring((0, 0, 0.07), 0.41, 0.05, 0.04, "velvet_lilac", segments=16, bevel=False)
    b.cyl_base((0, 0, 0.04), 0.35, 0.04, "milk", segments=16, bevel=False)                      # the milk
    b.ring((0, 0, 0.085), 0.2, 0.035, 0.01, "pearl", segments=12, bevel=False)                 # its swirl
    b.ring((0.04, 0.02, 0.087), 0.1, 0.03, 0.01, "pearl", segments=10, bevel=False)
    for (x, y) in ((0.22, -0.12), (-0.2, 0.16), (0.12, 0.22)):                                   # bubbles
        b.sphere((x, y, 0.085), 0.025, "milk", segments=6, rings=3, scale=(1, 1, 0.6))
    b.crescent((0, 0.0, 0.5), 0.17, 0.12, 0.06, "sparkle")
    b.cyl((0, 0, 0.24), 0.018, 0.2, "pastel_butter", segments=6, bevel=False)                   # the moon's stalk
    for (x, z, r) in ((-0.24, 0.38, 0.07), (0.25, 0.56, 0.06), (0.12, 0.3, 0.045)):
        b.star((x, -0.02, z), r, r * 0.45, 0.03, "sparkle", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_MoonMilk", mat)]


def build_star_treat(mat):
    """#3945 two baked star biscuits with gold icing, one flat and one leaning on it, sugar sparkles on top."""
    b = Builder()
    b.star((0.1, 0.08, 0.03), 0.2, 0.09, 0.06, "treat_tan")
    b.star((0.1, 0.08, 0.065), 0.16, 0.072, 0.02, "fur_golden")                                # its icing
    tilt = Matrix.Rotation(math.radians(62), 3, "X")
    b.star((-0.02, -0.04, 0.27), 0.27, 0.12, 0.08, "treat_tan", rot=tilt)                     # stood up higher
    b.star((-0.02, -0.075, 0.295), 0.22, 0.1, 0.02, "rarity_legend", rot=tilt)               # its icing
    for (x, y, z) in ((-0.08, -0.12, 0.34), (0.07, -0.11, 0.27), (0.0, -0.1, 0.4), (-0.1, -0.08, 0.24),
                      (0.12, 0.1, 0.08), (0.05, 0.02, 0.08)):
        b.box((x, y, z), (0.035, 0.02, 0.035), "sparkle", bevel=False, rot=tilt)
    return [b.finalize("CatCafe_Item_StarTreat", mat)]


def build_honey_cream(mat):
    """#3462, #3945 a tall swirl of whipped cream on the kibble, honey running down it and pooled round its foot, a
    grooved wooden dipper leaning in."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.035, "fur_golden", segments=16, bevel=False)                 # the honey pool
    for i, (r, z, h) in enumerate(((0.29, 0.03, 0.12), (0.23, 0.13, 0.11), (0.17, 0.23, 0.1), (0.11, 0.32, 0.09))):
        dx = 0.015 * (-1) ** i
        b.sphere((dx, 0.0, z + h / 2), r, "milk", segments=12, rings=5, scale=(1, 1, h / r))   # the swirl's turns
    b.cyl((0.0, 0.0, 0.44), 0.06, 0.08, "milk", segments=8, radius2=0.0)                        # its tip
    for k in range(5):                                                                            # honey down it
        a = math.radians(30 + 72 * k)
        rr, z = 0.24 - 0.02 * k, 0.24 - 0.025 * k
        b.box((rr * math.cos(a), rr * math.sin(a), z), (0.05, 0.035, 0.18), "rarity_legend", bevel=False,
              rot=_rz(math.degrees(a) + 90) @ Matrix.Rotation(math.radians(-22), 3, "X"))
        b.sphere((0.27 * math.cos(a), 0.27 * math.sin(a), 0.07), 0.035, "rarity_legend", segments=6, rings=3)
    b.ring((0, 0, 0.36), 0.12, 0.04, 0.025, "rarity_legend", segments=10, bevel=False)          # honey on top
    tilt = Matrix.Rotation(math.radians(35), 3, "Y")
    b.cyl((0.24, 0.0, 0.4), 0.02, 0.42, "caramel_wood", segments=6, bevel=False, rot=tilt)     # the dipper
    for k in range(3):                                                                            # its grooved head
        t = 0.15 + 0.03 * k
        b.cyl((0.24 - 0.57 * t, 0.0, 0.4 - 0.82 * t), 0.055, 0.025, "fur_toffee" if k % 2 else "caramel_wood",
              segments=8, bevel=False, rot=tilt)
    return [b.finalize("CatCafe_Item_HoneyCream", mat)]


def build_comet_treat(mat):
    """#3462, #3945 a round sky-blue biscuit with a darker baked rim and a white star, tipped up on the kibble, a
    tapering three-colour tail of light behind it and sparkles round it."""
    b = Builder()
    tilt = Matrix.Rotation(math.radians(60), 3, "X")
    b.cyl((0, 0, 0.2), 0.24, 0.1, "pastel_sky", segments=16, rot=tilt)
    b.ring((0, -0.003, 0.2), 0.245, 0.04, 0.105, "fur_puddle", segments=16, bevel=False, rot=tilt)   # baked rim
    b.star((0, -0.05, 0.23), 0.14, 0.065, 0.03, "offwhite", rot=tilt)
    b.star((0, -0.06, 0.235), 0.08, 0.036, 0.02, "sparkle", rot=tilt)
    back = Matrix.Rotation(math.radians(-68), 3, "X")                                          # out behind, a little up
    for (x, sw, h, r) in ((-0.11, "pastel_sky", 0.3, 0.05), (0.0, "offwhite", 0.4, 0.06),
                          (0.11, "sparkle", 0.26, 0.045)):
        b.cyl((x, 0.1 + 0.46 * h, 0.3 + 0.19 * h), r, h, sw, segments=8, bevel=False, radius2=0.008, rot=back)
    for (x, y, z, r) in ((0.24, 0.05, 0.5, 0.06), (-0.24, 0.1, 0.45, 0.05), (0.05, 0.25, 0.68, 0.045)):
        b.star((x, y, z), r, r * 0.45, 0.03, "sparkle", rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Item_CometTreat", mat)]


def build_tip_pile(mat):
    """The rich customer's tip: a heap of gold coins with a few short stacks. Sits on a table."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.42, 0.18, "rarity_legend", segments=10, radius2=0.18, bevel=False)    # heap core
    coin = dict(segments=10, bevel=False)
    for (x, y, n) in ((-0.42, 0.15, 4), (0.38, 0.25, 3), (0.15, -0.4, 2)):                     # stacks
        for k in range(n):
            b.cyl_base((x + 0.015 * (k % 2), y, 0.06 * k), 0.16, 0.055, "rarity_legend", **coin)
    for (x, y, z, a, ax) in ((0.0, 0.0, 0.22, 20, "X"), (-0.15, -0.2, 0.12, -30, "Y"), (0.25, -0.05, 0.12, 25, "Y"),
                             (-0.1, 0.25, 0.12, 30, "X"), (0.55, -0.35, 0.03, 0, "X")):
        b.cyl((x, y, z), 0.16, 0.05, "rarity_legend", rot=(math.radians(a), ax), **coin)         # loose coins
    for (x, y, z) in ((0.0, 0.0, 0.26), (-0.42, 0.15, 0.25)):
        b.box((x, y, z), (0.06, 0.06, 0.02), "sparkle", bevel=False)                           # glints
    return [b.finalize("CatCafe_Prop_TipPile", mat)]


ASSETS = {
    "CatCafe_Item_FoodBowl": (build_food_bowl, 300),
    "CatCafe_Item_FoodBowl_Premium": (build_food_bowl_premium, 400),
    "CatCafe_Item_Kibble": (build_kibble, 900),
    "CatCafe_Item_TunaCan": (build_tuna_can, 900),
    "CatCafe_Item_Salmon": (build_salmon, 900),
    "CatCafe_Item_Net_L1": (lambda m: build_net(1, m), 2200),     # 2026-11-03 redesign: round rim, diamond mesh
    "CatCafe_Item_Net_L2": (lambda m: build_net(2, m), 2200),
    "CatCafe_Item_Net_L3": (lambda m: build_net(3, m), 2600),
    "CatCafe_Item_Net_L4": (lambda m: build_net(4, m), 2600),
    "CatCafe_Item_Sardines": (build_sardines, 1600),
    "CatCafe_Item_Caviar": (build_caviar, 1400),
    "CatCafe_Item_MoonMilk": (build_moon_milk, 900),
    "CatCafe_Item_StarTreat": (build_star_treat, 600),
    "CatCafe_Item_HoneyCream": (build_honey_cream, 1100),     # #3462 the Day Cart's own baits
    "CatCafe_Item_CometTreat": (build_comet_treat, 900),
    "CatCafe_Prop_TipPile": (build_tip_pile, 600),
}
