"""Area gates for areas 3 to 5 (Neighbourhood, Woods, Sewer). Same opening as CatCafe_Park_Gate:
4 studs wide inside, leaves about 7 tall, pillars at x = +-2.4. Each gate is Pillars + LeafL + LeafR;
the leaves pivot at their hinge (x = -2 and +2) so the engineer's Park gate code opens all four.
Pivot base center, front -Y. The area sets behind them come after the slice."""

import math


from common import Builder


def _leaves(mat, name, draw):
    """draw(builder, sgn) fills one leaf in hinge-local space (the leaf runs from x=0 toward sgn*2)."""
    out = []
    for suffix, hinge_x, sgn in (("LeafL", -2.0, 1), ("LeafR", 2.0, -1)):
        g = Builder()
        draw(g, sgn)
        out.append(g.finalize(f"{name}_{suffix}", mat, location=(hinge_x, 0, 0)))
    return out


def build_neighbourhood_gate(mat):
    """Garden gate between brick pillars: white pickets, a white arch with a street sign, a mailbox."""
    name = "CatCafe_Neighbourhood_Gate"
    p = Builder()
    for x in (-2.4, 2.4):
        p.box_base((x, 0, 0), (0.8, 0.8, 6.0), "brick")
        p.box_base((x, 0, 6.0), (1.0, 1.0, 0.25), "offwhite")
        p.box((x, -0.42, 4.6), (0.5, 0.04, 0.35), "offwhite", bevel=False)                     # house number plate
        p.box((x, -0.44, 4.6), (0.2, 0.02, 0.2), "dark_wood", bevel=False)
    n = 9                                                                                        # arch over the opening
    for i in range(n):
        t = math.pi * (i + 0.5) / n
        x, z = -2.4 * math.cos(t), 6.25 + 1.3 * math.sin(t)
        p.box((x, 0, z), (0.95, 0.35, 0.3), "offwhite", rot=(-math.atan2(1.3 * math.cos(t), 2.4 * math.sin(t)), "Y"))
    p.box((0, -0.25, 7.0), (2.6, 0.12, 0.7), "sign_teal")                                       # area sign
    p.box((0, -0.32, 7.0), (2.3, 0.02, 0.45), "offwhite", bevel=False)
    p.box((0, -0.34, 7.0), (0.25, 0.02, 0.25), "rarity_rare", bevel=False)                      # paw badge spot
    p.cyl_base((3.4, -0.2, 0), 0.07, 3.0, "dark_wood", segments=6, bevel=False)                # mailbox post
    p.box((3.4, -0.2, 3.25), (0.5, 0.9, 0.5), "shirt_blue")
    p.box((3.68, 0.0, 3.45), (0.05, 0.08, 0.4), "bowl_red", bevel=False)                       # flag
    p.box_base((-3.75, 0.2, 0), (1.4, 0.9, 1.4), "leaf_dark")                                 # hedge stub

    def picket(g, sgn):
        for i in range(5):
            x = sgn * (0.2 + i * 0.4)
            g.box_base((x, 0, 0.3), (0.28, 0.1, 5.2), "offwhite", bevel=False)
            g.pyramid((x, 0, 5.5), 0.28, 0.3, "offwhite")
        for z in (1.2, 4.6):
            g.box((sgn * 1.0, 0.08, z), (2.0, 0.08, 0.25), "offwhite", bevel=False)
        g.box((sgn * 1.0, 0.1, 2.9), (0.2, 0.08, 3.4), "offwhite", rot=(math.radians(sgn * -32), "Y"), bevel=False)

    return [p.finalize(name + "_Pillars", mat)] + _leaves(mat, name, picket)


def build_woods_gate(mat):
    """Log gate: two log posts with a log beam, moss and mushrooms, plank leaves with a brace."""
    name = "CatCafe_Woods_Gate"
    p = Builder()
    for x in (-2.4, 2.4):
        p.cyl_base((x, 0, 0), 0.45, 7.2, "fur_brown", segments=8, radius2=0.38)
        for z in (1.5, 4.2):
            p.cyl((x, 0, z), 0.48, 0.12, "dark_wood", segments=8, bevel=False)                  # bark rings
        p.ico((x, 0, 7.3), 0.6, "leaf_green")                                                   # moss cap
    p.cyl((0, 0, 7.0), 0.32, 6.2, "fur_brown", segments=8, rot=(math.radians(90), "Y"))        # beam log
    for x in (-3.1, 3.1):
        p.cyl((x, 0, 7.0), 0.3, 0.04, "treat_tan", segments=8, bevel=False, rot=(math.radians(90), "Y"))  # cut ends
    p.ico((-0.9, 0.1, 7.35), 0.5, "leaf_dark")
    p.ico((1.2, -0.1, 7.3), 0.42, "leaf_green")
    p.box((0, -0.36, 6.3), (2.2, 0.1, 0.6), "dark_wood")                                        # carved sign
    p.box((0, -0.42, 6.3), (1.8, 0.02, 0.3), "treat_tan", bevel=False)
    for (x, y, h, r) in ((-3.3, -0.5, 0.55, 0.32), (-3.0, -0.9, 0.35, 0.22), (3.2, -0.6, 0.45, 0.28)):
        p.cyl_base((x, y, 0), 0.08, h, "offwhite", segments=6, bevel=False)                     # mushrooms
        p.cyl_base((x, y, h), r, r * 0.6, "bowl_red", segments=8, radius2=0.04, bevel=False)
        p.box((x + r * 0.4, y - r * 0.3, h + r * 0.25), (0.06, 0.06, 0.06), "offwhite", bevel=False)

    def planks(g, sgn):
        for i, h in enumerate((5.6, 5.9, 5.5, 5.8, 5.4)):
            x = sgn * (0.2 + i * 0.4)
            g.box_base((x, 0, 0.3), (0.36, 0.14, h), ("dark_wood", "caramel_wood")[i % 2], bevel=False)
        for z in (1.0, 4.8):
            g.box((sgn * 1.0, 0.12, z), (2.0, 0.1, 0.3), "fur_brown", bevel=False)
        g.box((sgn * 1.0, 0.14, 2.9), (0.3, 0.1, 4.3), "fur_brown", rot=(math.radians(sgn * -28), "Y"), bevel=False)

    return [p.finalize(name + "_Pillars", mat)] + _leaves(mat, name, planks)


def build_sewer_gate(mat):
    """Tunnel mouth: a concrete arch with a pipe and slime, iron grate leaves with rust."""
    name = "CatCafe_Sewer_Gate"
    p = Builder()
    for x in (-2.5, 2.5):
        p.box_base((x, 0, 0), (1.0, 1.2, 6.0), "concrete_dark")
        p.box_base((x, 0, 0), (1.15, 1.3, 0.6), "concrete")                                     # plinth
    n = 9
    for i in range(n):
        t = math.pi * (i + 0.5) / n
        x, z = -2.5 * math.cos(t), 6.0 + 1.2 * math.sin(t)
        p.box((x, 0, z), (1.0, 1.2, 0.5), "concrete_dark", rot=(-math.atan2(1.2 * math.cos(t), 2.5 * math.sin(t)), "Y"))
    p.box((0, -0.62, 7.0), (0.9, 0.06, 0.6), "metal")                                           # keystone plate
    p.cyl((0, -0.66, 7.0), 0.22, 0.04, "concrete", segments=10, bevel=False, rot=(math.radians(90), "X"))
    p.cyl((3.4, 0.2, 4.6), 0.35, 1.4, "rust", segments=10, rot=(math.radians(90), "X"))        # side pipe
    p.ring((3.4, -0.52, 4.6), 0.38, 0.1, 0.12, "metal", segments=10, bevel=False, rot=(math.radians(90), "X"))
    p.box((3.4, -0.6, 3.6), (0.3, 0.05, 1.6), "leaf_green", bevel=False)                       # slime drip
    p.cyl_base((3.4, -0.9, 0), 0.6, 0.03, "leaf_green", segments=10, bevel=False)
    p.box((-2.5, -0.62, 2.6), (0.5, 0.04, 1.6), "leaf_dark", bevel=False)                       # moss streak

    def grate(g, sgn):
        for i in range(5):
            x = sgn * (0.2 + i * 0.4)
            g.box_base((x, 0, 0.3), (0.12, 0.12, 5.9), "metal", bevel=False)
            g.pyramid((x, 0, 6.2), 0.16, 0.25, "metal")
        for z in (0.8, 3.2, 5.6):
            g.box((sgn * 1.0, 0, z), (2.0, 0.16, 0.18), "fur_black", bevel=False)
        for (x, z) in ((0.6, 3.2), (1.5, 0.8), (1.0, 5.6)):
            g.box((sgn * x, -0.09, z), (0.35, 0.04, 0.2), "rust", bevel=False)

    return [p.finalize(name + "_Pillars", mat)] + _leaves(mat, name, grate)


ASSETS = {
    "CatCafe_Neighbourhood_Gate": (build_neighbourhood_gate, 1200),
    "CatCafe_Woods_Gate": (build_woods_gate, 1200),
    "CatCafe_Sewer_Gate": (build_sewer_gate, 1200),
}
