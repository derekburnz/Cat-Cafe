"""Gold cats (features.md F42, data-model.md section 4; called "shiny" until Derek renamed them on 2026-10-27):
every cat has a gold version on the same shapes, `CatCafe_Cat_<Name>_Gold` (walking, body A) and
`CatCafe_Cat_<Name>_Gold_Sit` (sitting, body B), gold-modeled as Derek asked. Eyes,
nose, inner ears and star specks keep their colours, so the cat still reads as itself.

The coat roles of a cat (fur, second, third, ruff, a tail tip and socks; not `sparkle` specks) are ranked lightest first by CIE L*: the
lightest takes gold_light, the next gold_mid, the next gold_dark, and any very dark coat colour (black,
chocolate) takes palette.GOLD_DEEP (gold_dark), so patterns, points and stripes stay visible in three golds. The
muzzle turns gold_light. The golds are palette.METAL_SWATCHES, so these parts are Material Metal in Roblox and
metallic in the renders.

The gold cats are Part models only (rbx/ and previews): the FBX meshes are the same as the base cats', and a
MeshPart route would swap the texture instead.
"""

import cats
import palette

COAT_KEYS = ("fur", "second", "third", "ruff", "tip", "socks")
TONES = ("gold_light", "gold_mid", "gold_dark")
DEEP_LSTAR = 35.0              # coat colours darker than this take the deep gold


lstar = palette.lstar


def coat_map(spec):
    """Base coat swatch -> gold swatch for one cat."""
    coat = {spec[k] for k in COAT_KEYS if spec.get(k) and spec[k] != "sparkle"}
    out, rank = {}, 0
    for sw in sorted(coat, key=lstar, reverse=True):
        if lstar(sw) < DEEP_LSTAR:
            out[sw] = palette.GOLD_DEEP
        else:
            out[sw] = TONES[min(rank, len(TONES) - 1)]
            rank += 1
    return out


def gold_spec(name):
    spec = dict(cats.ROSTER[name])
    m = coat_map(spec)
    for k in COAT_KEYS:
        if spec.get(k) in m:
            spec[k] = m[spec[k]]
    if spec.get("muzzle"):
        spec["muzzle"] = TONES[0]
    return spec


def build_gold(name, mat, body="walk"):
    return cats.build_cat(name, mat, spec=gold_spec(name), base=f"CatCafe_Cat_{name}_Gold{cats.SUFFIX[body]}", body=body)


ASSETS = {f"CatCafe_Cat_{n}_Gold{cats.SUFFIX[bd]}": (lambda mat, n=n, bd=bd: build_gold(n, mat, bd), 1500)
          for n in cats.ROSTER for bd in cats.BODIES}
