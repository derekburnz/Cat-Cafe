"""Shiny coats (features.md F42, data-model.md section 4): every cat has a shiny version on the same shapes with
its coat recoloured, `CatCafe_Cat_<Name>_Shiny`. Eyes, nose, inner ears, muzzle and star specks keep their
colours, so the cat still reads as itself.

The coat roles of a cat (fur, second, third; not `sparkle` specks) are ranked lightest first by CIE L*: the
lightest takes shiny_light, the next shiny_mid, the next shiny_dark, and any very dark coat colour (black,
chocolate) takes the style's deep swatch, so patterns, points and stripes stay visible; a dark coat already close
to the deep swatch (night sky under frost) takes shiny_dark so it still changes. A cream muzzle turns white.
The tones come from palette.SHINY_STYLE, so changing that one line (frost, gold, lavender) and rebuilding restyles
every shiny cat.

The shiny cats are Part models only (rbx/ and previews): the FBX meshes are the same as the base cats', and a
MeshPart route would swap the texture instead.
"""

import colorsys

import cats
import palette

COAT_KEYS = ("fur", "second", "third")
TONES = ("shiny_light", "shiny_mid", "shiny_dark")
DEEP_LSTAR = 35.0              # coat colours darker than this take the deep swatch


def lstar(swatch):
    """CIE L* (0 black to 100 white) of a palette swatch."""
    r, g, b = (palette.srgb_to_linear(c) for c in palette.hex_to_rgb(palette.SWATCHES[palette.idx(swatch)][1]))
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return 116 * y ** (1 / 3) - 16 if y > 0.008856 else 903.3 * y


def _like_deep(swatch):
    """A dark coat already in the deep swatch's colour family (Midnight's night sky against frost's galaxy blue)
    would barely change, so it takes shiny_dark instead."""
    def hs(name):
        h, _, sat = colorsys.rgb_to_hls(*palette.hex_to_rgb(palette.SWATCHES[palette.idx(name)][1]))
        return h * 360, sat
    (h1, s1), (h2, _) = hs(swatch), hs(palette.SHINY_DEEP)
    return s1 > 0.3 and min(abs(h1 - h2), 360 - abs(h1 - h2)) < 30


def coat_map(spec):
    """Base coat swatch -> shiny swatch for one cat."""
    coat = {spec[k] for k in COAT_KEYS if spec.get(k) and spec[k] != "sparkle"}
    out, rank = {}, 0
    for sw in sorted(coat, key=lstar, reverse=True):
        if lstar(sw) < DEEP_LSTAR and not _like_deep(sw):
            out[sw] = palette.SHINY_DEEP
        elif lstar(sw) < DEEP_LSTAR:
            out[sw] = TONES[-1]
        else:
            out[sw] = TONES[min(rank, len(TONES) - 1)]
            rank += 1
    return out


def shiny_spec(name):
    spec = dict(cats.ROSTER[name])
    m = coat_map(spec)
    for k in COAT_KEYS:
        if spec.get(k) in m:
            spec[k] = m[spec[k]]
    if spec.get("muzzle") == "fur_cream":
        spec["muzzle"] = "fur_white"
    return spec


def build_shiny(name, mat):
    return cats.build_cat(name, mat, spec=shiny_spec(name), base=f"CatCafe_Cat_{name}_Shiny")


ASSETS = {f"CatCafe_Cat_{n}_Shiny": (lambda mat, n=n: build_shiny(n, mat), 1500) for n in cats.ROSTER}
