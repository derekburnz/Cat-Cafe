"""Gold cats (features.md F42, data-model.md section 4; called "shiny" until Derek renamed them on 2026-10-27):
every cat has a gold version on the same shapes, `CatCafe_Cat_<Name>_Gold`, gold-modeled as Derek asked. Eyes,
nose, inner ears and star specks keep their colours, so the cat still reads as itself.

The coat roles of a cat (fur, second, third, ruff; not `sparkle` specks) are ranked lightest first by CIE L*: the
lightest takes gold_light, the next gold_mid, the next gold_dark, and any very dark coat colour (black,
chocolate) takes palette.GOLD_DEEP (gold_dark), so patterns, points and stripes stay visible in three golds. The
muzzle turns gold_light. The golds are palette.METAL_SWATCHES, so these parts are Material Metal in Roblox and
metallic in the renders.

The gold cats are Part models only (rbx/ and previews): the FBX meshes are the same as the base cats', and a
MeshPart route would swap the texture instead.
"""

import cats
import palette

COAT_KEYS = ("fur", "second", "third", "ruff")
TONES = ("gold_light", "gold_mid", "gold_dark")
DEEP_LSTAR = 35.0              # coat colours darker than this take the deep gold


def lstar(swatch):
    """CIE L* (0 black to 100 white) of a palette swatch."""
    r, g, b = (palette.srgb_to_linear(c) for c in palette.hex_to_rgb(palette.SWATCHES[palette.idx(swatch)][1]))
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return 116 * y ** (1 / 3) - 16 if y > 0.008856 else 903.3 * y


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


def build_gold(name, mat):
    return cats.build_cat(name, mat, spec=gold_spec(name), base=f"CatCafe_Cat_{name}_Gold")


ASSETS = {f"CatCafe_Cat_{n}_Gold": (lambda mat, n=n: build_gold(n, mat), 1500) for n in cats.ROSTER}
