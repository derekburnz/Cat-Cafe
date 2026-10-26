"""Park set (features.md priority 9). Pivot base center, front -Y."""

import math

from common import Builder
from furniture import build_bench


def build_park_bench(mat):
    b = build_bench("CatCafe_Park_Bench", seat="caramel_wood", frame="concrete_dark")
    return [b.finalize("CatCafe_Park_Bench", mat)]


def build_tree(mat):
    b = Builder()
    b.cyl_base((0, 0, 0), 0.5, 4.0, "fur_brown", segments=10, radius2=0.35)
    b.ico((0, 0, 5.2), 2.0, "leaf_green")
    b.ico((1.2, 0.4, 4.4), 1.3, "leaf_dark")
    b.ico((-1.1, -0.5, 4.6), 1.2, "leaf_green")
    b.ico((0.2, -1.0, 6.3), 1.1, "leaf_dark")
    return [b.finalize("CatCafe_Park_Tree", mat)]


def build_fountain(mat):
    """Basin + Water objects; Water gets Transparency 0.3 in Studio."""
    basin = Builder()
    basin.ring((0, 0, 0.5), 2.5, 0.35, 1.0, "concrete", segments=16, bevel=False)
    basin.cyl_base((0, 0, 0), 2.5, 0.2, "concrete_dark", segments=16, bevel=False)
    basin.cyl_base((0, 0, 0.2), 0.35, 2.2, "concrete", segments=10)
    basin.cyl_base((0, 0, 2.4), 1.0, 0.2, "concrete", segments=12, radius2=1.1)
    basin.ring((0, 0, 2.75), 1.15, 0.15, 0.35, "concrete", segments=12, bevel=False)
    basin.sphere((0, 0, 3.4), 0.3, "sign_teal", segments=10, rings=6)
    water = Builder()
    water.cyl_base((0, 0, 0.2), 2.15, 0.6, "puddle", segments=16, bevel=False)
    water.cyl_base((0, 0, 2.6), 1.0, 0.25, "puddle", segments=16, bevel=False)
    return [basin.finalize("CatCafe_Park_Fountain_Basin", mat), water.finalize("CatCafe_Park_Fountain_Water", mat)]


def build_gate(mat):
    """Two pillars and a double gate, 4 wide inside, 7 tall. Pillars + GateL + GateR objects
    so the engineer can swing the leaves open. Leaves pivot at their hinge pillar."""
    pillars = Builder()
    for x in (-2.4, 2.4):
        pillars.box_base((x, 0, 0), (0.8, 0.8, 7.5), "brick")
        pillars.box_base((x, 0, 7.5), (1.0, 1.0, 0.3), "concrete")
        pillars.sphere((x, 0, 8.1), 0.35, "concrete", segments=10, rings=6)
    pillars.box((0, 0.1, 7.3), (5.6, 0.2, 0.4), "fur_black")                     # top sign bar
    pillars.box((0, 0.1, 7.3), (0.8, 0.3, 0.3), "rarity_legend")                 # paw badge spot

    def leaf(name, hinge_x, sgn):
        g = Builder()
        for i in range(5):
            x = sgn * (0.2 + i * 0.4)
            h = 6.2 + (0.5 if i == 4 else 0.2 * i)
            g.cyl_base((x, 0, 0.3), 0.06, h, "fur_black", segments=6, bevel=False)
            g.sphere((x, 0, 0.3 + h + 0.08), 0.1, "fur_black", segments=6, rings=4)
        for z in (1.0, 5.5):
            g.box((sgn * 1.0, 0, z), (2.0, 0.12, 0.15), "fur_black", bevel=False)
        return g.finalize(name, mat, location=(hinge_x, 0, 0))

    return [pillars.finalize("CatCafe_Park_Gate_Pillars", mat),
            leaf("CatCafe_Park_Gate_LeafL", -2.0, 1), leaf("CatCafe_Park_Gate_LeafR", 2.0, -1)]


ASSETS = {
    "CatCafe_Park_Bench": (build_park_bench, 800),
    "CatCafe_Park_Tree": (build_tree, 800),
    "CatCafe_Park_Fountain": (build_fountain, 1200),
    "CatCafe_Park_Gate": (build_gate, 1200),
}
