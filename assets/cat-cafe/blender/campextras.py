"""One extra at each camp from the Park on (F100, docs/design/cat-cafe/camp-extras.md): small models in the area's
theme, about the size of an Index Board, each with one moving touch for Animation-Engineer and VFX-Agent.
The Park, Neighbourhood and Woods extras became the camp stations in campstations.py (#1319); their old
PicnicBasket, YardSale and FishPond models were removed in #1368. gold_fish stays here because campstations uses it.

  CatCafe_Camp_Sewer_LostFound         a battered wooden crate stencilled LOST AND / FOUND under a dripping pipe, a
                                       sock, an umbrella handle and a teddy's ear poking out under the lid, a list
                                       pinned to its side, a boot and a puddle. `_Lid`: pivot on the back hinge, so
                                       a rattle is a small turn about X. Attachment `Drip` at the pipe's mouth.

Every one: pivot at the base centre on the camp's ground, front -Z toward the camp, no turn, and an Attachment
`PromptAnchor` in front at 1.5 studs. Spots (area space, the camp sets as of F84, clear of every theme prop):
SPOTS below, beside the way out across from the Index Board.
"""

import math

from mathutils import Matrix, Vector

from cannon import frame_at
from common import RB
from icon_art import _glyphs
from plot import rot_x

# area space (x, z) for Layout.camps[area].campExtra, from CatCafe_Camp_<Area>'s props
SPOTS = {"Park": (23.0, -65.5), "Neighbourhood": (26.0, -145.5), "Woods": (21.5, -125.0), "Sewer": (20.0, -94.5)}
DIGITS = {"4": ("101", "101", "111", "001", "001"), "0": ("111", "101", "101", "101", "111")}
ATTACHMENTS = {}        # asset -> [(name, Roblox point)]


def label(b, s, cx, y, z, px, depth, swatch):
    """Block letters centred on x = cx, bottom at y, on a face at depth z read from -Z."""
    cols = sum((len(DIGITS[c][0]) if c in DIGITS else 3) + 1 if c != " " else 2 for c in s) - 1
    w = cols * px
    _glyphs(b, s, (cx + w / 2, y, z), px, depth, swatch, (-1, 0, 0), (0, 1, 0), DIGITS)


def gold_fish(b, x, y, z, s=1.0, up=False):
    """A little gold fish, side on along X (head -X), or standing on its head when `up` (a tail out of a bucket)."""
    if up:
        b.span((x - 0.09 * s, y, z - 0.05 * s), (x + 0.09 * s, y + 0.34 * s, z + 0.05 * s), "gold_mid")
        b.span((x - 0.16 * s, y + 0.34 * s, z - 0.03 * s), (x + 0.16 * s, y + 0.46 * s, z + 0.03 * s), "gold_light")
        return
    b.span((x - 0.22 * s, y, z - 0.05 * s), (x + 0.12 * s, y + 0.18 * s, z + 0.05 * s), "gold_mid")
    b.span((x + 0.12 * s, y - 0.03 * s, z - 0.03 * s), (x + 0.24 * s, y + 0.21 * s, z + 0.03 * s), "gold_light")


def prompt(name, p=(0.0, 1.5, -2.0)):
    ATTACHMENTS.setdefault(name, []).append(("PromptAnchor", p))


# ----------------------------------------------------------------------------------------------- lost and found --
def build_lost_found(mat):
    name = "CatCafe_Camp_Sewer_LostFound"
    b, lid = RB(), RB()
    W, H, D = 2.6, 1.4, 1.6
    b.span((-W / 2, 0, -D / 2), (W / 2, H, D / 2), "kibble")                                    # the crate
    for x in (-W / 2, W / 2 - 0.16):                                                            # corner posts
        for z in (-D / 2 - 0.03, D / 2 - 0.13):
            b.span((x - 0.02, -0.02, z), (x + 0.18, H + 0.02, z + 0.16), "dark_wood")
    for y in (0.0, H - 0.16):                                                                   # top and bottom bands
        b.span((-W / 2 + 0.16, y, -D / 2 - 0.03), (W / 2 - 0.16, y + 0.16, -D / 2), "caramel_wood")
        b.span((-W / 2 + 0.16, y, D / 2), (W / 2 - 0.16, y + 0.16, D / 2 + 0.03), "caramel_wood")
    label(b, "LOST AND", 0, 0.78, -D / 2, 0.06, 0.02, "offwhite")                               # stencil
    label(b, "FOUND", 0, 0.38, -D / 2, 0.06, 0.02, "offwhite")
    b.span((-0.95, 0.22, -D / 2 - 0.02), (-0.6, 0.3, -D / 2), "rust")                            # a scrape
    b.span((W / 2, 0.35, -0.45), (W / 2 + 0.02, 1.05, 0.25), "offwhite")                         # the list on its side
    for k in range(5):
        b.span((W / 2 + 0.02, 0.48 + 0.11 * k, -0.38), (W / 2 + 0.03, 0.52 + 0.11 * k, 0.1 - 0.06 * (k % 2)),
               "fur_charcoal")
    b.span((W / 2 + 0.02, 0.98, -0.12), (W / 2 + 0.05, 1.03, -0.07), "bowl_red")                 # its pin
    # things poking out under the lid at the front: a striped sock, an umbrella's hook, a teddy's ear
    for k in range(4):
        b.span((-1.1, H - 0.12 - 0.15 * k, -D / 2 - 0.08), (-0.92, H + 0.03 - 0.15 * k, -D / 2 - 0.03),
               "bowl_red" if k % 2 == 0 else "offwhite")
    b.span((0.35, H, -D / 2 + 0.1), (0.45, H + 0.42, -D / 2 + 0.2), "fur_black")                  # umbrella hook
    b.span((0.45, H + 0.32, -D / 2 + 0.1), (0.7, H + 0.42, -D / 2 + 0.2), "fur_black")
    b.span((0.62, H + 0.18, -D / 2 + 0.1), (0.7, H + 0.32, -D / 2 + 0.2), "fur_black")
    b.ball((-0.05, H + 0.08, -D / 2 + 0.3), 0.16, "fur_caramel")                                 # teddy's ear
    # the lid, ajar: in lid space, its origin on the back hinge, tipped up 7 degrees at the front
    t = math.radians(7)
    lid.box((0, 0.06 + 0.83 * math.sin(t), -0.83 * math.cos(t)), (W + 0.1, 0.12, D + 0.06), "caramel_wood",
            rot=rot_x(7))
    for x in (-0.8, 0.0, 0.8):
        lid.box((x, 0.13 + 0.83 * math.sin(t), -0.83 * math.cos(t)), (0.12, 0.04, D + 0.02), "dark_wood",
                rot=rot_x(7))
    lid.box((0.75, 0.155 + 0.55 * math.sin(t), -0.55 * math.cos(t)), (0.5, 0.01, 0.4), "puddle", rot=rot_x(7))
    # the dripping pipe behind: a standpipe with a valve, an elbow and its mouth over the lid
    px, pz, top = 0.75, D / 2 + 0.55, 3.4
    b.span((px - 0.45, 0, pz - 0.45), (px + 0.45, 0.12, pz + 0.45), "concrete")                  # base
    b.cyl((px, 0.12 + (top - 0.12) / 2, pz), 0.24, top - 0.12, "metal", segments=12)
    for y in (0.6, 2.3):
        b.cyl((px, y, pz), 0.29, 0.14, "rust", segments=12)                                       # rusty collars
    b.cyl((px, 1.55, pz - 0.3), 0.08, 0.12, "metal", axis="Z", segments=8)                        # valve stem
    b.cyl((px, 1.55, pz - 0.38), 0.3, 0.06, "bowl_red", axis="Z", segments=12)                    # valve wheel
    b.ball((px, top, pz), 0.3, "metal")                                                         # elbow
    mz, low = 0.25, top - 0.75                                                                  # over the lid
    b.cyl((px, top, (pz + mz) / 2), 0.24, pz - mz, "metal", axis="Z", segments=12)
    b.ball((px, top, mz), 0.3, "metal")                                                         # elbow down
    b.cyl((px, (top + low) / 2, mz), 0.24, top - low, "metal", segments=12)
    b.cyl((px, low + 0.04, mz), 0.3, 0.12, "rust", segments=12)                                  # flange
    b.cyl((px, low - 0.025, mz), 0.17, 0.01, "fur_black", segments=10)                           # the open mouth
    ATTACHMENTS.setdefault(name, []).append(("Drip", (px, low - 0.08, mz)))
    for (mx, mz2) in ((px - 0.4, pz + 0.3), (px + 0.35, pz - 0.35)):
        b.span((mx - 0.15, 0.12, mz2 - 0.12), (mx + 0.15, 0.2, mz2 + 0.12), "fur_moss")
    # a lost boot and a puddle
    b.span((-1.9, 0, -0.5), (-1.6, 0.7, -0.15), "choco")
    b.span((-2.15, 0, -0.5), (-1.6, 0.22, -0.15), "choco")
    b.span((-1.92, 0.6, -0.52), (-1.58, 0.72, -0.13), "dark_wood")
    b.span((0.9, 0, -1.35), (1.9, 0.02, -0.7), "puddle")
    prompt(name, (0.0, 1.5, -1.8))
    return [b.finalize(name, mat), lid.finalize(name + "_Lid", mat, location=(0.0, H, D / 2))]


def rbx_attachments(name):
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACHMENTS.get(name, [])]


ASSETS = {
    "CatCafe_Camp_Sewer_LostFound": (build_lost_found, 3000),
}
