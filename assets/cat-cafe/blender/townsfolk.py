"""Townsfolk cats (#2687, claim #2688): the non-interactive NPC cats that gather round a camp once its station
unlocks, sitting at a camp growth model's Townsfolk_1..3 spots (campgrowth.py). They are not collection cats: coats no
roster cat wears, each in a work apron in its area's colours and a hat, so they read as the camp's people.

  CatCafe_NPC_Townsfolk_<Name>   a sitting cat (body B, no new rig), front -Z, pivot at its feet on the floor, at
                                 scale 1. Its pieces are child Models with their own pivots, like the Garden Nursery's
                                 gardener: _Body, _Head (with _Eye1, _Eye2, _EarL, _EarR inside it), _Tail, _LegF1,
                                 _LegF2, and its hat _Prop riding inside the Head Model, so the idle and greet loops
                                 turn them as on any sitting cat (manifest part_pivots_roblox). Nothing collides (they
                                 are scenery, and players walk round).

One per area by default (AREA), and any of them can sit at any camp.
"""

import cats
import props
from common import scale_mesh

# name -> (the area it belongs to, its coat); HATS: each one's hat (a props.py head prop), riding its Head
TOWNSFOLK = {
    "Picnicker": ("Park", dict(rarity="Common", fur="fur_cream", second="fur_toffee", third="fur_toffee",
                               eyes="eye_green", pattern="patches", muzzle="fur_white", nose="nose_pink",
                               apron=("shirt_green", ("leaf_dark", "offwhite", "bowl_red")))),
    "Neighbour": ("Neighbourhood", dict(rarity="Common", fur="fur_grey", second="fur_charcoal", eyes="eye_amber",
                                        pattern="stripes", muzzle="fur_white", nose="nose_dark",
                                        apron=("blush", ("offwhite", "pastel_sky", "mint")))),
    "Camper": ("Woods", dict(rarity="Common", fur="fur_russet", second="fur_brown", eyes="eye_green",
                             pattern="stripes", muzzle="fur_cream", nose="nose_brick",
                             apron=("fur_orange", ("cream", "leaf_dark", "dark_wood")))),
    "Tinker": ("Sewer", dict(rarity="Common", fur="fur_slate", second="fur_slate", eyes="eye_chartreuse",
                             pattern="solid", muzzle="fur_white", nose="nose_dark",
                             apron=("sign_teal", ("pastel_butter", "metal", "offwhite")))),
    "Trader": ("Desert", dict(rarity="Common", fur="fur_sand", second="fur_caramel", eyes="eye_amber",
                              pattern="points", muzzle=None, nose="nose_brick",
                              apron=("terracotta", ("cream", "eye_amber", "dark_wood")))),
    "Explorer": ("Ruins", dict(rarity="Common", fur="fur_hazel", second="fur_cream", third="fur_cream",
                               eyes="eye_blue", pattern="patches", muzzle="fur_cream", nose="nose_pink",
                               apron=("fur_emerald", ("fur_golden", "offwhite", "leaf_dark")))),
}
HATS = {"Picnicker": props.beret, "Neighbour": props.plaid_cap, "Camper": props.ranger_hat, "Tinker": props.work_cap,
        "Trader": props.fedora, "Explorer": props.safari_hat}
AREA = {area: f"CatCafe_NPC_Townsfolk_{n}" for n, (area, _) in TOWNSFOLK.items()}


def build_townsfolk(n):
    name = f"CatCafe_NPC_Townsfolk_{n}"

    def build(mat):
        spec = TOWNSFOLK[n][1]
        objs = cats.build_cat("Townsfolk" + n, mat, spec=spec, base=name, body="sit")
        d = cats.dims(spec, "sit")
        ctx = props.Ctx(spec, "sit", d)
        HATS[n](ctx)
        k = cats.scale_of(spec, "sit")
        hat = ctx.main.finalize(name + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
        if k != 1.0:
            scale_mesh(hat, k)
        hat["rides"] = "Head"
        extra = []
        for suffix, (pb, at) in ctx.extra.items():    # a prop's own pieces, the fedora's lit band (#2739) among them
            piece = pb.finalize(name + "_" + suffix, mat,
                                location=tuple((h + a) * k for h, a in zip(d["pivots"]["Head"], at)))
            if k != 1.0:
                scale_mesh(piece, k)
            piece["rides"] = "Head"
            extra.append(piece)
        return objs + [hat] + extra
    return build


ASSETS = {f"CatCafe_NPC_Townsfolk_{n}": (build_townsfolk(n), 1500) for n in TOWNSFOLK}
