"""The Rift Realm for the Rift Run, the cutscene on a Mythic or better trait pull (Motion-FX-Agent's storyboard,
Library Motion-FX-Agent/for-derek-2026-11-13/rift-run/, Derek OK'd it 2026-11-13 20:09 UTC). Motion-FX builds the
scene far off the map on the roller's client only, from these pieces. They go in their own folder,
ReplicatedStorage.Assets.RiftRun (rbx/RiftRun/), and none of them has a script or collides.

  CatCafe_RiftRun_Path            the floating stone path the cat runs along: 20 slabs, 120 long and 10 wide, from
                                  its start along -Z, a rock keel under each and a violet light seam down both sides
  CatCafe_RiftRun_IslandA/B/C     floating islands, 10, 16 and 24 across, a stone top over a rock cone, glowing
                                  crystals on top (and a broken pillar on the big one)
  CatCafe_RiftRun_Ring            the rift at the path's end: a 30 across stone ring standing upright, facing the
                                  path (+Z), three pink light rings inside it round a dark void, on a rock plinth
  CatCafe_RiftRun_Gate_<Tier>     one arch per trait rarity, Common, Uncommon, Rare, Epic, Legendary and Mythic, in
                                  that rarity's colour, plus a white Secret one with a constellation over it; 12 wide
                                  and 14 tall inside, on two stone plinths
  CatCafe_RiftRun_Meteor          a rock about 3.6 across with glowing embers; its trail is Motion-FX's particles

Pivots (each Model's pivot; the PrimaryPart is the biggest part, with PivotOffset set so GetPivot / PivotTo use these):
  Path: the middle of its start edge, on the walking top (y 0 is where the cat's feet are), front -Z (the way it
  runs). Islands: the middle of the walking top. Ring and gates: the base centre, on the path's top. Meteor: its
  centre. Lights are the <Name>_Glow child Model (Neon); a gate's arch is all _Glow, so Motion-FX can set its Color
  from Traits.RARITIES for the exact pool colour.
"""

import math

from common import RB
from plot import rot_y, rot_z

RBX_DIR = "RiftRun"                         # build_all writes these into rbx/RiftRun/ (a Folder in Assets)
N = "CatCafe_RiftRun_"
TOP, SIDE, KEEL, TIP = "velvet_lilac", "galaxy_blue", "fur_indigo", "fur_ash"
LIGHT, PINK, HOT = "aurora_violet", "neon_pink", "rarity_mythic"

PATH_LEN, PATH_W, SLABS = 120.0, 10.0, 20
GATE_IN_W, GATE_IN_H, POST = 12.0, 14.0, 1.5
TIERS = (("Common", "rarity_common"), ("Uncommon", "leaf_green"), ("Rare", "rarity_rare"), ("Epic", "rarity_epic"),
         ("Legendary", "rarity_legend"), ("Mythic", "rarity_mythic"), ("Secret", "milk"))


def _ring(b, cy, r, thick, depth, n, swatch, z=0.0, a0=0.0, a1=360.0):
    """Blocks round a circle in the XY plane (centre (0, cy)), from angle a0 to a1."""
    span = a1 - a0
    seg = math.radians(span) * r / n
    for k in range(n):
        a = a0 + span * (k + 0.5) / n
        x, y = r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))
        b.box((x, y, z), (seg + 0.12, thick, depth), swatch, rot=rot_z(a + 90))


# ------------------------------------------------------------------------------------------------- the path --
def build_path(mat):
    b, glow = RB(), RB()
    step = PATH_LEN / SLABS
    for i in range(SLABS):
        z = -(i + 0.5) * step
        w = PATH_W if i % 3 else PATH_W - 0.3                       # every third slab a touch narrower, hand laid
        b.box((0, -0.5, z), (w, 1.0, step - 0.2), TOP)
        b.box((0, -1.6, z), (w - 1.6, 1.2, step - 1.2), SIDE)
        b.box((0.4 * (1 if i % 2 else -1), -2.8, z), (w - 4.4, 1.2, step - 2.6), KEEL)
        if i % 2 == 0:
            b.box((0, -4.0, z), (2.2, 1.2, 1.6), TIP)
    for sx in (-1, 1):                                              # the light seam down both sides
        glow.box((sx * (PATH_W / 2 + 0.12), -0.4, -PATH_LEN / 2), (0.2, 0.3, PATH_LEN), LIGHT)
    return [b.finalize(N + "Path", mat), glow.finalize(N + "Path_Glow", mat)]


# ---------------------------------------------------------------------------------------------- the islands --
def _crystal(glow, x, z, h, lean, swatch):
    glow.box((x, h / 2 - 0.2, z), (0.7, h, 0.7), swatch, rot=rot_z(lean) @ rot_y(45))


def _island(r, crystals, pillar, seed):
    def build(mat):
        b, glow = RB(), RB()
        b.cyl((0, -0.6, 0), r, 1.2, TOP, segments=8)
        b.cyl((0, -1.6, 0), r * 0.92, 0.8, SIDE, segments=8)
        b.cyl((0, -1.2 - r * 0.35, 0), r * 0.25, r * 0.55, KEEL, r2=r * 0.85, segments=7)
        b.cyl((0, -1.2 - r * 0.72, 0), r * 0.06, r * 0.3, TIP, r2=r * 0.26, segments=6)
        for k in range(3):                                          # loose stones on the top
            a = math.radians(seed * 40 + k * 120)
            b.ball((r * 0.55 * math.cos(a), 0.25, r * 0.55 * math.sin(a)), 0.5 + 0.15 * k, "pastel_lilac",
                   scale=(1.2, 0.6, 1.0))
        for k, (dx, dz, h, lean) in enumerate(crystals):
            _crystal(glow, dx * r, dz * r, h, lean, (LIGHT, PINK)[k % 2])
        if pillar:                                                  # a broken pillar on the big island
            b.box((-r * 0.35, 0.5, r * 0.2), (2.2, 1.0, 2.2), KEEL)
            b.cyl((-r * 0.35, 2.6, r * 0.2), 0.8, 3.2, "fur_lilac_silver", segments=8)
            b.box((-r * 0.35 + 1.6, 0.3, r * 0.2 - 1.0), (1.4, 0.6, 1.0), "fur_lilac_silver", rot=rot_y(30))
        return [b.finalize(build.name, mat), glow.finalize(build.name + "_Glow", mat)]
    return build


ISLANDS = {
    N + "IslandA": _island(5.0, ((0.1, -0.2, 2.4, 8), (-0.25, 0.1, 1.6, -12)), False, 1),
    N + "IslandB": _island(8.0, ((0.3, -0.1, 3.2, 6), (0.12, 0.25, 2.2, -10), (-0.3, -0.3, 1.8, 14)), False, 2),
    N + "IslandC": _island(12.0, ((0.35, -0.2, 4.0, 5), (0.2, 0.3, 2.8, -9), (0.45, 0.15, 2.0, 15),
                                   (-0.1, -0.45, 2.4, -6)), True, 3),
}
for _name, _fn in ISLANDS.items():
    _fn.name = _name


# -------------------------------------------------------------------------------------------------- the rift --
RING_R = 15.0                                  # outer radius: 30 across
RING_CY = RING_R + 0.8                         # the ring's middle above its base


def build_ring(mat):
    b, glow = RB(), RB()
    _ring(b, RING_CY, RING_R - 1.3, 2.6, 2.4, 20, KEEL)                         # the stone frame
    _ring(b, RING_CY, RING_R - 0.15, 0.4, 1.6, 20, SIDE)                        # its outer lip
    _ring(glow, RING_CY, RING_R - 3.0, 0.8, 2.6, 24, HOT)                       # three light rings, stepping back (-Z)
    _ring(glow, RING_CY, RING_R - 4.5, 0.5, 0.6, 24, PINK, z=-0.4)
    _ring(glow, RING_CY, RING_R - 6.2, 0.4, 0.5, 20, HOT, z=-0.9)
    b.cyl((0, RING_CY, -1.3), RING_R - 3.2, 0.3, "night_sky", axis="Z", segments=16)   # the void behind them
    b.box((0, 0.6, 0), (9.0, 1.2, 4.6), KEEL)                                   # the plinth it stands in
    b.box((0, 1.5, 0), (5.4, 1.0, 3.4), SIDE)
    for k, (a, rr) in enumerate(((35, 1.2), (150, 1.0), (215, 0.8), (320, 0.9))):   # shards floating round it
        x, y = (RING_R + 2.6) * math.cos(math.radians(a)), RING_CY + (RING_R + 2.6) * math.sin(math.radians(a))
        b.box((x, y, k * 0.3 - 0.5), (rr, rr * 1.8, rr), KEEL, rot=rot_z(a + 20))
        glow.box((x * 1.08, y + 0.4, 0.6), (0.3, 0.3, 0.3), "sparkle", rot=rot_z(45))
    return [b.finalize(N + "Ring", mat), glow.finalize(N + "Ring_Glow", mat)]


# ------------------------------------------------------------------------------------------------- the gates --
def _gate(tier, swatch):
    name = N + "Gate_" + tier

    def build(mat):
        b, glow = RB(), RB()
        x = GATE_IN_W / 2 + POST / 2
        leg_h = GATE_IN_H - GATE_IN_W / 2                                       # 8: the straight part
        for sx in (-1, 1):
            b.box((sx * x, 0.6, 0), (2.6, 1.2, 2.6), KEEL)                      # the stone plinths
            b.box((sx * x, 1.45, 0), (2.0, 0.5, 2.0), SIDE)
            glow.box((sx * x, (1.7 + leg_h) / 2, 0), (POST, leg_h - 1.7, POST), swatch)
        _ring(glow, leg_h, GATE_IN_W / 2 + POST / 2, POST, POST, 9, swatch, a0=0, a1=180)
        glow.box((0, GATE_IN_H + POST + 0.5, 0), (1.0, 1.0, 0.6), "sparkle", rot=rot_z(45))   # the keystone gem
        if tier == "Secret":                                                    # the star cat over the arch
            stars = [(-6.5, 17.2), (-4.0, 19.6), (-1.0, 20.8), (1.6, 20.0), (4.2, 21.2), (6.4, 18.6)]
            for (sx_, sy) in stars:
                glow.ball((sx_, sy, 0), 0.42, "milk")
            for (ax, ay), (bx, by) in zip(stars, stars[1:]):
                d = math.hypot(bx - ax, by - ay)
                glow.box(((ax + bx) / 2, (ay + by) / 2, 0.05), (d, 0.12, 0.12), "milk",
                         rot=rot_z(math.degrees(math.atan2(by - ay, bx - ax))))
        return [b.finalize(name, mat), glow.finalize(name + "_Glow", mat)]
    return name, build


GATES = dict(_gate(t, s) for t, s in TIERS)


# ------------------------------------------------------------------------------------------------ the meteor --
def build_meteor(mat):
    b, glow = RB(), RB()
    b.ball((0, 0, 0), 1.5, TIP)
    for (x, y, z, r, sw) in ((0.9, 0.5, 0.3, 0.8, "concrete_dark"), (-0.8, -0.4, 0.5, 0.75, TIP),
                             (0.2, -0.7, -0.9, 0.7, "concrete_dark"), (-0.4, 0.9, -0.6, 0.6, KEEL)):
        b.ball((x, y, z), r, sw)
    for (x, y, z) in ((1.25, 0.1, -0.7), (-1.3, 0.4, -0.3), (0.2, 1.35, 0.4), (0.5, -1.2, 0.6), (-0.3, -0.2, 1.45)):
        glow.ball((x, y, z), 0.36, "fur_orange")
    return [b.finalize(N + "Meteor", mat), glow.finalize(N + "Meteor_Glow", mat)]


ASSETS = {
    N + "Path": (build_path, 2500),
    **{n: (fn, 1500) for n, fn in ISLANDS.items()},
    N + "Ring": (build_ring, 3000),
    **{n: (fn, 1000) for n, fn in GATES.items()},
    N + "Meteor": (build_meteor, 800),
}
