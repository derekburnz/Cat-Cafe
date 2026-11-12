"""Camp growth (#2687, claim #2688): what a camp grows when its station unlocks, so ranking up changes the area and
not only the cafe. One model per area beside its station: a second canopy with a stall table under it, a string of
lanterns on two poles in front of it and a few pieces in the area's theme, with spots where the townsfolk cats
(non-interactive NPCs) stand.

  CatCafe_Camp_<Area>_Growth   Park, Neighbourhood, Woods, Sewer, Desert, Ruins. Pivot at the area's camp extra spot
                               (Layout.campExtras, the area's set space; the Desert's and Ruins' at (20, 3.5 in from
                               the gate line), where their stations will stand), front -Z, no turn of its own, so it
                               is placed exactly like the station (Layout.campExtraAt). The pieces stand off to the
                               side (C below), clear of the station's 9 x 8 footprint and the camp's own props.
                               Everything solid collides (the canopy is a `_Stall`, not a walk-through `_Canopy`);
                               lanterns are `_Bulbs` (lit at night like the others).
                               Attachments `Townsfolk_1`..`Townsfolk_3`: where a townsfolk cat sits, on the floor,
                               its LookVector the way the cat faces (toward the camp's middle).

Client-only (the epic): the game shows it from the area's tier, so each player sees their own camp.
"""

import math

from mathutils import Vector

import alley
import alleyway
import desertset as ds
import neighbourhood as nb
import park
import ruinsset as rs
import sewer as sw
import woods
from areakit import Set
from camps import AREAS as CAMP_AREAS
from camps import gate_line
from cannon import frame_at
from common import RB
from plot import rot_x, rot_y

# area -> (camp, the camp extra's spot as (x, in from the gate line), the cluster's centre (x, in from the gate line),
#          cloth, stripe, post, lantern, the theme)
SPOTS = {
    "Park": ("ParkF85", (19.0, 4.5), (47.0, 10.0), "shirt_green", "offwhite", "caramel_wood", "lamp_warm"),
    "Neighbourhood": ("NeighbourhoodF85", (22.0, 4.5), (40.0, 10.0), "blush", "offwhite", "offwhite", "lamp_warm"),
    "Woods": ("WoodsF85", (21.5, 4.0), (40.0, 10.0), "fur_orange", "cream", "dark_wood", "lamp_warm"),
    "Sewer": ("SewerF85", (20.0, 3.5), (38.0, 9.0), "sign_teal", "offwhite", "metal", "pastel_butter"),
    # the Desert's station is the Oasis Spa at (25, 8.5 in) (#2790, about 23 x 12): the growth stands east of the
    # oasis pool, clear of the spa, the pool and its palms
    "Desert": ("Desert", (25.0, 8.5), (63.0, 10.0), "terracotta", "cream", "dark_wood", "lamp_warm"),
    "Ruins": ("Ruins", (20.0, 3.5), (48.0, 10.0), "fur_emerald", "fur_golden", "paving_grout", "lamp_warm"),
}
ATTACHMENTS = {}         # asset -> [(name, Roblox point, Roblox rotation)]
H = 4.2                  # the canopy's eaves


def stall_canopy(mat, name, cloth, stripe, post, w=6.5, d=5.0):
    """A market canopy on four posts, front -Z: striped cloth sloping down to the front, a scalloped valance on the
    front and sides, and a stall table across the back with jars and parcels on it."""
    b, deco = RB(), RB()
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.cyl((sx * (w / 2 - 0.2), (H + 0.5) / 2, sz * (d / 2 - 0.2)), 0.14, H + 0.5, post, segments=8)
    n = 7
    slope = math.degrees(math.atan2(0.5, d))
    for i in range(n):
        x = -w / 2 + (i + 0.5) * w / n
        sw_ = (cloth, stripe)[i % 2]
        b.box((x, H + 0.5 + 0.004 * (i % 2), 0), (w / n + 0.01, 0.12, d + 0.3), sw_,
              rot=rot_x(-slope))
        b.span((x - w / n / 2 + 0.06, H - 0.35, -d / 2 - 0.2), (x + w / n / 2 - 0.06, H + 0.25, -d / 2 - 0.13), sw_)
    for sx in (-1, 1):                                                     # side valances
        for k in range(3):
            z = -d / 2 + (k + 0.5) * d / 3
            up = 0.5 * z / d                                               # follow the cloth's slope and touch its edge
            b.span((sx * (w / 2), H - 0.1 + up, z - d / 6 + 0.06), (sx * (w / 2 + 0.07), H + 0.5 + up, z + d / 6 - 0.06),
                   (cloth, stripe)[k % 2])
    # the stall table along the back
    tz = d / 2 - 1.1
    b.span((-w / 2 + 0.6, 0.95, tz - 0.55), (w / 2 - 0.6, 1.1, tz + 0.55), "caramel_wood")
    for sx in (-1, 1):
        b.span((sx * (w / 2 - 0.85) - 0.1, 0, tz - 0.4), (sx * (w / 2 - 0.85) + 0.1, 0.95, tz - 0.2), "dark_wood")
        b.span((sx * (w / 2 - 0.85) - 0.1, 0, tz + 0.2), (sx * (w / 2 - 0.85) + 0.1, 0.95, tz + 0.4), "dark_wood")
    b.span((-w / 2 + 0.6, 0.55, tz - 0.52), (w / 2 - 0.6, 0.95, tz - 0.5), stripe)              # a cloth skirt
    for k, (x, sw_, r, h) in enumerate(((-1.9, "glass", 0.22, 0.5), (-1.3, cloth, 0.2, 0.4), (-0.4, "cardboard", 0, 0),
                                        (0.6, "treat_tan", 0.28, 0.3), (1.5, "pastel_butter", 0.2, 0.55))):
        if r:
            deco.cyl((x, 1.1 + h / 2, tz), r, h, sw_, segments=8)
            deco.cyl((x, 1.1 + h + 0.05, tz), r * 0.8, 0.1, "dark_wood", segments=8)
        else:                                                           # a parcel tied with string
            deco.span((x - 0.35, 1.1, tz - 0.3), (x + 0.35, 1.5, tz + 0.3), sw_)
            deco.span((x - 0.36, 1.1, tz - 0.04), (x + 0.36, 1.51, tz + 0.04), "offwhite")
    return [b.finalize(name, mat), deco.finalize(name + "_Decor", mat)]


def lantern_string(mat, name, post, lamp, L=11.0, top=6.0, sag=1.0, n=8):
    """Two poles L apart along X with a sagging wire between and n - 1 paper lanterns hung on it (`_Bulbs`)."""
    b, wire, bulbs = RB(), RB(), RB()
    for x in (-L / 2, L / 2):
        b.span((x - 0.45, 0, -0.45), (x + 0.45, 0.3, 0.45), "concrete_dark")
        b.cyl((x, (top + 0.3) / 2, 0), 0.15, top + 0.3, post, segments=8)
        b.span((x - 0.22, top + 0.3, -0.22), (x + 0.22, top + 0.6, 0.22), post)
    pts = alleyway._sag(-L / 2, L / 2, top, sag, n)
    for p0, p1 in zip(pts, pts[1:]):
        alleyway.bar(wire, p0, p1, 0.05, -0.025, 0.025, "fur_black")
    for k, (x, y) in enumerate(pts[1:-1]):
        bulbs.cyl((x, y - 0.45, 0), 0.26, 0.55, lamp if k % 2 == 0 else "lamp_warm", segments=8)
        wire.span((x - 0.02, y - 0.17, -0.02), (x + 0.02, y, 0.02), "fur_black")
    return [b.finalize(name, mat), wire.finalize(name + "_Decor", mat), bulbs.finalize(name + "_Bulbs", mat)]


def _theme(s, mat, area, cx, cz):
    """The area's pieces round the cluster at (cx, cz) (model space, canopy at cx + 3 facing -X)."""
    if area == "Park":
        s.put(nb.flowerbed(mat), cx + 3.0, cz - 5.0, 0)
        s.put(park.build_park_bench(mat), cx + 3.0, cz + 5.2, 180)
    elif area == "Neighbourhood":
        s.put(nb.flowerbed(mat), cx + 3.0, cz - 5.0, 0)
        s.put(nb.flowerbed(mat), cx + 3.0, cz + 5.0, 180)
    elif area == "Woods":
        s.put(woods.log_bench(mat), cx + 3.0, cz - 5.0, 0)
        s.put(woods.fern(mat), cx + 5.5, cz + 4.8, 30)
    elif area == "Sewer":
        s.put(sw.barrel(mat), cx + 4.5, cz - 4.6, 0)
        s.put(alley.build_crate(mat), cx + 2.2, cz - 4.8, 15)
        s.put(sw.tyre_stack(mat), cx + 4.0, cz + 4.8, 0)
    elif area == "Desert":
        s.put(ds.pot(mat, 0.9), cx + 5.0, cz - 4.2, 0)
        s.put(ds.pot(mat, 0.7), cx + 3.8, cz - 4.6, 0)
        s.put(ds.crate(mat), cx + 4.5, cz + 4.2, 10)
    elif area == "Ruins":
        s.put(rs.stone_urn(mat), cx + 4.5, cz - 4.4, 0)
        s.put(rs.stone_urn(mat, 1.8), cx + 2.8, cz - 4.6, 0)
        s.put(rs.brazier(mat), cx + 4.5, cz + 4.6, 0)


def build_growth(area):
    camp, (sx_, s_in), (cx_, c_in), cloth, stripe, post, lamp = SPOTS[area]
    name = f"CatCafe_Camp_{area}_Growth"

    def build(mat):
        G = gate_line(camp)
        S = (sx_, G - s_in)                                                # the station's spot = this model's pivot
        cx, cz = cx_ - S[0], (G - c_in) - S[1]
        s = Set(name)
        g = RB()
        g.span((cx - 6.0, 0, cz - 5.5), (cx + 7.5, 0.02, cz + 5.5), CAMP_AREAS[camp]["path"])   # a trodden patch
        s.put(stall_canopy(mat, "CatCafe_Camp_Stall", cloth, stripe, post), cx + 3.0, cz, 90)
        s.put(lantern_string(mat, "CatCafe_Camp_Lanterns", post, lamp), cx - 3.6, cz, 90)
        _theme(s, mat, area, cx, cz)
        R = rot_y(90)                                                       # the cats face -X, to the camp's middle
        ATTACHMENTS[name] = [(f"Townsfolk_{k + 1}", Vector((cx - 1.2, 0, cz + dz)), R)
                             for k, dz in enumerate((-2.6, 0.2, 2.8))]
        return s.finish(g, mat)
    return build


def rbx_attachments(name):
    return [(name, n, frame_at(p, R)) for n, p, R in ATTACHMENTS.get(name, [])]


ASSETS = {f"CatCafe_Camp_{a}_Growth": (build_growth(a), 8000) for a in SPOTS}
