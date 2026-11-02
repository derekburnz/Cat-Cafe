"""The Lucky Cat statue by every cafe's front door (F88, luck-and-rare-moments.md 1a: "Every cafe gets a Lucky Cat
statue beside its front door, waving one paw ... clay, bronze, silver, gold and jade with a rainbow shimmer ... Level 0
is an empty plinth with a 'Lucky Cat' sign, so new players see that it is there to buy").

  CatCafe_Plot_LuckyCat_0        the stone plinth with a little LUCKY CAT board on top.
  CatCafe_Plot_LuckyCat_1 .. _5  the plinth, a red cushion and the statue: a round-faced cat sitting up, happy closed
                                 eyes, a red collar with a bell, a gold coin held to its chest in its right paw and its
                                 left paw raised by its ear. Clay, bronze, silver, gold, jade; from gold up the plinth
                                 has a gold cap and the cushion gold tassels.
    <asset>_Paw                  the raised left paw and its forearm, a child Model whose pivot is the shoulder: the
                                 wave turns it about its own X axis (Animation-Engineer), the paw tipping forward and
                                 back. The body also has an Attachment PawHinge at the same point.

Plot space (Layout.plot): place it at (-5.1, 0, -16.1) with no turn, front -Z to the street, in place of the shell's
left potted shrub (plot.py), left of the door. The plinth is 1.5 square. Bronze and silver are Metal and jade is
Marble (rbx_export.SWATCH_MATERIALS); gold is Metal like every gold swatch.
"""

from mathutils import Matrix, Vector

import rbx_export
from common import RB
from plot import rot_z

N = "CatCafe_Plot_LuckyCat_"
SPOT = (-5.1, 0.0, -16.1)            # plot space, for Layout.plot.luckyCat
SEAT = 1.2                           # the cushion's top, where the cat sits
PAW_PIVOT = (-0.64, SEAT + 0.7, -0.12)   # the left shoulder, the _Paw model's pivot and PawHinge

# level: (look, body, light, painted details, {swatch: material})
LEVELS = {
    1: ("clay", "terracotta", "fur_peach", "dark_wood", {}),
    2: ("bronze", "bronze", "brass", "fur_seal", {"bronze": "Metal", "brass": "Metal"}),
    3: ("silver", "fur_silver", "metal", "fur_charcoal", {"fur_silver": "Metal", "metal": "Metal"}),
    4: ("gold", "gold_mid", "gold_light", "fur_black", {}),
    5: ("jade", "fur_emerald", "mint", "leaf_dark", {"fur_emerald": "Marble", "mint": "Marble"}),
}


def plinth(rb, level):
    """A stone plinth 1.5 square: foot, block, cap (gold from level 4), then the red cushion with tassels."""
    rb.span((-0.75, 0.0, -0.75), (0.75, 0.25, 0.75), "paving_grout")
    rb.span((-0.64, 0.25, -0.64), (0.64, 0.9, 0.64), "paving_light")
    rb.span((-0.72, 0.9, -0.72), (0.72, 1.04, 0.72), "gold_mid" if level >= 4 else "paving_sand")
    rb.span((-0.6, 0.47, -0.66), (0.6, 0.53, -0.64), "paving_sand")           # a groove line across the front
    if level == 0:
        return
    rb.span((-0.62, 1.04, -0.62), (0.62, SEAT, 0.62), "bowl_red")
    if level >= 4:
        for sx in (-1, 1):
            for sz in (-1, 1):
                rb.ball((sx * 0.62, 1.06, sz * 0.62), 0.07, "gold_light")


def sign(rb):
    """Level 0's board on the empty plinth: LUCKY over CAT in cream on dark wood, on two little legs."""
    zf = -0.05
    rb.span((-0.55, 1.04, zf + 0.05), (-0.47, 1.25, zf + 0.13), "dark_wood")
    rb.span((0.47, 1.04, zf + 0.05), (0.55, 1.25, zf + 0.13), "dark_wood")
    rb.span((-0.66, 1.25, zf), (0.66, 2.25, zf + 0.1), "dark_wood")
    rb.span((-0.6, 1.31, zf - 0.02), (0.6, 2.19, zf + 0.04), "sign_teal")
    px = 0.055
    for text, y in (("LUCKY", 1.82), ("CAT", 1.42)):
        w = sum(len(_glyph(c)[0]) + 1 for c in text) - 1
        x0 = w * px / 2                                   # reading along -X for someone in front (-Z)
        rb.text(text, (x0, y, zf - 0.01), px, 0.05, "cream", right=(-1, 0, 0), up=(0, 1, 0))


def _glyph(c):
    from common import GLYPHS
    return GLYPHS.get(c, ("00",))


def statue(rb, paw, level):
    """The sitting cat on the cushion, front -Z. `paw` is built round the shoulder (PAW_PIVOT at its origin)."""
    _, body, light, detail, _ = LEVELS[level]
    y = SEAT
    rb.span((-0.5, y, -0.35), (0.5, y + 1.0, 0.45), body)                      # body
    rb.span((-0.33, y + 0.08, -0.37), (0.33, y + 0.78, -0.3), light)           # bib
    for s in (-1, 1):
        rb.span((s * 0.22 - 0.14, y, -0.52), (s * 0.22 + 0.14, y + 0.22, -0.3), body)          # front feet
        rb.span((s * 0.56 - 0.1, y, -0.05), (s * 0.56 + 0.1, y + 0.45, 0.4), body)            # haunches
    rb.span((0.1, y, 0.43), (0.66, y + 0.18, 0.6), body)                       # tail round the back
    rb.span((0.48, y + 0.18, 0.43), (0.66, y + 0.5, 0.6), body)
    rb.span((0.48, y + 0.5, 0.43), (0.66, y + 0.62, 0.6), light)               # its tip
    # head: a broad block with cheeks, ears, happy closed eyes, nose and whiskers
    hy0, hy1, hz0, hz1 = y + 0.95, y + 1.82, -0.45, 0.35
    rb.span((-0.55, hy0, hz0), (0.55, hy1, hz1), body)
    rb.span((-0.6, hy0 + 0.08, hz0 + 0.05), (0.6, hy0 + 0.42, hz1 - 0.15), body)               # cheeks
    rb.span((-0.3, hy0 + 0.06, hz0 - 0.03), (0.3, hy0 + 0.36, hz0 + 0.05), light)               # muzzle
    for s in (-1, 1):
        ex = s * 0.33
        rb.box((ex, hy1 - 0.02, -0.05), (0.32, 0.32, 0.22), body, rot=rot_z(45))               # ear
        rb.box((ex, hy1 - 0.02, -0.17), (0.18, 0.18, 0.04), "nose_pink", rot=rot_z(45))        # inner ear
        rb.span((ex - 0.12, hy0 + 0.52, hz0 - 0.02), (ex + 0.12, hy0 + 0.57, hz0 + 0.02), detail)   # closed eye
        rb.span((ex - 0.16, hy0 + 0.47, hz0 - 0.02), (ex - 0.11, hy0 + 0.52, hz0 + 0.02), detail)
        rb.span((ex + 0.11, hy0 + 0.47, hz0 - 0.02), (ex + 0.16, hy0 + 0.52, hz0 + 0.02), detail)
        for k, wy in enumerate((0.16, 0.26)):                                                   # whiskers
            rb.span((s * 0.31, hy0 + wy - 0.015, hz0 - 0.04), (s * 0.58, hy0 + wy + 0.015, hz0 + 0.02), detail)
        rb.span((s * 0.38 - 0.08, hy0 + 0.36, hz0 - 0.015), (s * 0.38 + 0.08, hy0 + 0.42, hz0 + 0.02),
                "nose_pink")                                                                    # blush
    rb.span((-0.07, hy0 + 0.3, hz0 - 0.06), (0.07, hy0 + 0.38, hz0 + 0.02), "nose_pink")       # nose
    rb.span((-0.11, hy0 + 0.17, hz0 - 0.06), (-0.01, hy0 + 0.21, hz0 + 0.02), detail)          # mouth
    rb.span((0.01, hy0 + 0.17, hz0 - 0.06), (0.11, hy0 + 0.21, hz0 + 0.02), detail)
    # collar and bell
    rb.span((-0.53, y + 0.88, -0.38), (0.53, y + 1.02, 0.48), "bowl_red")
    rb.ball((0.0, y + 0.86, -0.45), 0.11, "gold_mid")
    # the coin held to the chest in the right paw (+X)
    rb.ball((0.18, y + 0.47, -0.42), 1.0, "gold_light", scale=(0.24, 0.33, 0.06))
    for dy in (-0.12, 0.0, 0.12):
        rb.span((0.08, y + 0.47 + dy - 0.015, -0.49), (0.28, y + 0.47 + dy + 0.015, -0.44), "gold_dark")
    rb.span((0.5, y + 0.35, -0.3), (0.72, y + 0.85, -0.03), body)              # right arm down the side
    rb.span((0.34, y + 0.32, -0.52), (0.62, y + 0.6, -0.26), body)             # its paw over the coin's edge
    # the raised left paw, round the shoulder
    paw.ball((0.0, 0.0, 0.0), 0.2, body)
    paw.span((-0.23, 0.05, -0.18), (0.03, 0.85, 0.08), body)                   # forearm, up beside the head
    paw.span((-0.27, 0.8, -0.25), (0.07, 1.12, 0.07), body)                    # the paw
    paw.span((-0.18, 0.86, -0.27), (-0.02, 1.0, -0.23), "nose_pink")           # its pad
    for k in range(3):
        paw.span((-0.22 + k * 0.08, 1.02, -0.27), (-0.17 + k * 0.08, 1.07, -0.23), "nose_pink")
    paw.span((-0.25, 0.62, -0.22), (0.05, 0.72, 0.1), light)                   # a cuff at the wrist


def hinge_attachments(name):
    """PawHinge on the body at the shoulder, for build_all (rbx_export attachments)."""
    import cannon
    return [(name, "PawHinge", cannon.frame_at(Vector(PAW_PIVOT), Matrix.Identity(3)))]


def builder(level):
    name = f"{N}{level}"
    if level:
        rbx_export.SWATCH_MATERIALS[name] = LEVELS[level][4]

    def build(mat):
        rb, paw = RB(), RB()
        plinth(rb, level)
        if level == 0:
            sign(rb)
            return [rb.finalize(name, mat)]
        statue(rb, paw, level)
        return [rb.finalize(name, mat), paw.finalize(name + "_Paw", mat, location=PAW_PIVOT)]

    return build


ASSETS = {f"{N}{level}": (builder(level), 4000) for level in range(6)}
ATTACHED = {f"{N}{level}" for level in range(1, 6)}
