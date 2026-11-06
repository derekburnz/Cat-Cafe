"""One extra at each camp from the Park on (F100, docs/design/cat-cafe/camp-extras.md): small models in the area's
theme, about the size of an Index Board, each with one moving touch for Animation-Engineer and VFX-Agent.
Every extra has since become a camp station in campstations.py: the Park, Neighbourhood and Woods ones in #1319 (their
old PicnicBasket, YardSale and FishPond models were removed in #1368) and the Sewer's Lost and Found crate in #1732
(CatCafe_Camp_Sewer_LostFoundBooth; the crate, CatCafe_Camp_Sewer_LostFound, was removed once the Catalog used the
booth). What is left here are helpers: gold_fish (campstations uses it), label, prompt and SPOTS.
"""

from mathutils import Matrix, Vector

from cannon import frame_at
from icon_art import _glyphs

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


def rbx_attachments(name):
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACHMENTS.get(name, [])]


ASSETS = {}
