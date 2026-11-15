"""Harvest Hollow decor (#4251, the limited area, Wed Nov 25 to Sun Dec 6 2026): the six pieces the Harvest Stall
swaps for pumpkins and the Feast Pie everyone who helped fill the shared pie gets. Autumn and harvest only.

  CatCafe_Decor_HayBaleSofa     two hay bales as a bench with a back, red twine, a cream cushion and a small pumpkin
  CatCafe_Decor_PawPumpkin     a fat pumpkin on a crate with a paw print cut in its front that glows (`_Glow`)
  CatCafe_Decor_AppleBushel      a slatted crate heaped with red and green apples, a basket beside it
  CatCafe_Decor_CornSheaf       a tied sheaf of corn stalks with ears of corn, two pumpkins at its foot
  CatCafe_Decor_PieCounter      a little counter with a checked cloth, three lattice pies and a PIES board
  CatCafe_Decor_HarvestWreath   a wreath of autumn leaves, wheat and berries with a bow, on a wooden easel
  CatCafe_Decor_FeastPie        the Feast Pie: a giant lattice pie on a round table, one slice out on a plate,
                                steam curls (`_Glow`) and a little THANKS flag

Each stands on a decor spot like crate_decor.py's and storepacks.py's (about 4 wide and 2.5 deep, base centre at the
pivot, front -Z). Lights are `_Glow` (Neon). Season 1 already has a Hay Bale Seat, a Pumpkin Lantern and an Apple Crate
Shelf (seasondecor.py), so these three are the Hay Bale Sofa, the Paw Pumpkin and the Apple Bushel.
"""

import math

from common import RB
from plot import rot_x, rot_y, rot_z

N = "CatCafe_"
HAY, HAY_D, TWINE = "fur_sand", "fur_toffee", "bowl_red"
LEAVES = ("bowl_red", "fur_orange", "eye_amber", "fur_rust_red", "fur_golden")


def _pumpkin(b, c, r, sw="fur_marmalade"):
    x, y, z = c
    for k in range(6):
        a = math.radians(60 * k)
        b.ball((x + 0.42 * r * math.cos(a), y + r * 0.6, z + 0.42 * r * math.sin(a)), r * 0.68, sw, scale=(1, 0.85, 1))
    b.box((x, y + r * 1.22, z), (r * 0.24, r * 0.34, r * 0.24), "leaf_dark", rot=rot_z(10))


def _bale(b, lo, hi, along="X"):
    """A hay bale from corner lo to hi with two twine bands across its long side and darker end caps."""
    b.span(lo, hi, HAY)
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    e = 0.02
    if along == "X":
        for f in (0.28, 0.72):
            x = x0 + (x1 - x0) * f
            b.span((x - 0.05, y0 - e, z0 - e), (x + 0.05, y1 + e, z1 + e), TWINE)
        for x in (x0, x1):
            b.span((x - e, y0 + 0.1, z0 + 0.1), (x + e, y1 - 0.1, z1 - 0.1), HAY_D)
    for k in range(5):                                                                        # loose straws
        x = x0 + (x1 - x0) * (0.12 + 0.19 * k)
        b.box((x, y1 + 0.02, z0 + (z1 - z0) * (0.3 + 0.1 * (k % 3))), (0.3, 0.04, 0.05), "fur_custard",
              rot=rot_y(25 * (k % 3) - 20))


def build_hay_bale_sofa(mat):
    b = RB()
    _bale(b, (-1.7, 0, -0.9), (1.7, 1.1, 0.5))                                               # the seat
    _bale(b, (-1.7, 0, 0.5), (1.7, 2.2, 1.15))                                               # the back
    b.span((-1.2, 1.1, -0.75), (0.5, 1.28, 0.4), "fur_cream")                                # a cushion
    b.span((-1.2, 1.28, -0.75), (0.5, 1.31, 0.4), "fur_vanilla")
    for k in range(3):
        b.box((-1.0 + 0.65 * k, 1.3, -0.18), (0.12, 0.05, 1.14), "fur_rust_red")             # its stripes
    _pumpkin(b, (1.15, 1.1, -0.2), 0.38)
    b.box((0.2, 2.24, 0.82), (0.5, 0.05, 0.32), "fur_orange", rot=rot_y(30))                 # a leaf on the back
    return [b.finalize(N + "Decor_HayBaleSofa", mat)]


def build_paw_pumpkin(mat):
    b, glow = RB(), RB()
    b.span((-0.95, 0, -0.8), (0.95, 0.7, 0.8), "caramel_wood")                               # the crate
    for y in (0.18, 0.5):
        b.span((-0.98, y - 0.04, -0.83), (0.98, y + 0.04, 0.83), "dark_wood")
    cy, r = 0.7, 1.05
    _pumpkin(b, (0, cy, 0), r)
    b.box((0.25, cy + r * 1.3, 0.05), (0.5, 0.05, 0.3), "leaf_green", rot=rot_z(15))
    z = -(r * 1.07)
    glow.box((0, cy + r * 0.5, z), (0.46, 0.38, 0.1), "eye_amber")                           # the paw print: pad
    for k, (dx, dy) in enumerate(((-0.34, 0.3), (-0.12, 0.44), (0.12, 0.44), (0.34, 0.3))):  # and four toes
        glow.box((dx, cy + r * 0.5 + dy, z + 0.02 * abs(dx)), (0.17, 0.2, 0.1), "eye_amber")
    glow.cyl((0, cy + 0.04, 0), 0.5, 0.05, "eye_amber", segments=10)                         # a warm spill under it
    return [b.finalize(N + "Decor_PawPumpkin", mat), glow.finalize(N + "Decor_PawPumpkin_Glow", mat)]


def build_apple_bushel(mat):
    b = RB()
    b.span((-1.3, 0.0, -0.8), (1.3, 0.12, 0.8), "dark_wood")                                 # floor of the crate
    for k in range(3):                                                                        # slats, front and back
        y = 0.28 + 0.34 * k
        for z in (-0.8, 0.8):
            b.span((-1.3, y - 0.13, z - 0.05), (1.3, y + 0.13, z + 0.05), "caramel_wood")
        for x in (-1.3, 1.3):
            b.span((x - 0.05, y - 0.13, -0.8), (x + 0.05, y + 0.13, 0.8), "caramel_wood")
    for x in (-1.3, 1.3):
        for z in (-0.8, 0.8):
            b.span((x - 0.09, 0, z - 0.09), (x + 0.09, 1.2, z + 0.09), "dark_wood")          # corner posts
    b.span((-1.2, 0.12, -0.72), (1.2, 0.85, 0.72), "bowl_red")                               # the heap's core
    k = 0
    for iz in range(3):
        for ix in range(5):
            x, z = -0.98 + 0.49 * ix, -0.5 + 0.5 * iz
            sw = "leaf_green" if (ix + 2 * iz) % 4 == 1 else "bowl_red"
            b.ball((x, 1.0 + 0.12 * ((ix + iz) % 2), z), 0.27, sw)
            if k % 3 == 0:
                b.box((x, 1.3 + 0.12 * ((ix + iz) % 2), z), (0.04, 0.12, 0.04), "fur_seal")
            k += 1
    b.ball((0.1, 1.42, 0.0), 0.28, "bowl_red")                                                # one on top with a leaf
    b.box((0.1, 1.72, 0.0), (0.04, 0.12, 0.04), "fur_seal")
    b.box((0.26, 1.74, 0.0), (0.26, 0.04, 0.14), "leaf_green", rot=rot_z(20))
    b.cyl((1.75, 0.3, -0.45), 0.42, 0.6, "fur_toffee", segments=10, r2=0.5)                  # a basket beside it
    b.cyl((1.75, 0.6, -0.45), 0.52, 0.08, "fur_brown", segments=10)
    for dx, dz, sw in ((-0.15, -0.1, "bowl_red"), (0.18, 0.05, "leaf_green"), (0.0, 0.2, "bowl_red")):
        b.ball((1.75 + dx, 0.72, -0.45 + dz), 0.22, sw)
    b.span((-0.75, 0.3, -0.9), (0.75, 0.82, -0.85), "fur_cream")                             # APPLES board
    b.text("APPLES", (0.66, 0.42, -0.9), 0.055, 0.03, "bowl_red", right=(-1, 0, 0))
    return [b.finalize(N + "Decor_AppleBushel", mat)]


def build_corn_sheaf(mat):
    b = RB()
    b.cyl((0, 0.08, 0), 1.1, 0.16, "fur_toffee", segments=12)                                # a straw mat
    for k in range(10):                                                                       # the stalks, fanned
        a = math.radians(36 * k)
        lean = 5 + 2 * (k % 3)
        R = rot_y(-math.degrees(a)) @ rot_z(-lean)
        x, z = 0.3 * math.cos(a), 0.3 * math.sin(a)
        top = 2.0
        b.box((x + math.sin(math.radians(lean)) * top * math.cos(a), top, z + math.sin(math.radians(lean)) * top * math.sin(a)),
              (0.22, 4.0, 0.22), ("fur_sand", "fur_custard")[k % 2], rot=R)
    b.cyl((0, 2.1, 0), 0.48, 0.26, TWINE, segments=10)                                       # the tie
    b.box((0.3, 2.05, -0.48), (0.5, 0.3, 0.06), TWINE, rot=rot_z(25))                        # its bow
    b.box((-0.3, 2.05, -0.48), (0.5, 0.3, 0.06), TWINE, rot=rot_z(-25))
    for k in range(8):                                                                        # dry leaves up top
        a = math.radians(45 * k + 10)
        out = 0.75 + 0.1 * (k % 2)
        b.box((out * math.cos(a), 3.3 + 0.25 * (k % 3), out * math.sin(a)), (0.8, 0.06, 0.24),
              ("leaf_green", "fur_golden")[k % 2], rot=rot_y(-math.degrees(a)) @ rot_z(35))
    for k, a in enumerate((250, 290, 215)):                                                   # ears of corn, front
        ar = math.radians(a)
        x, z = 0.62 * math.cos(ar), 0.62 * math.sin(ar)
        b.cyl((x, 2.75 + 0.2 * k, z), 0.15, 0.7, "fur_golden", segments=8, r2=0.09)
        b.box((x, 2.55 + 0.2 * k, z - 0.12), (0.3, 0.55, 0.06), "leaf_green", rot=rot_x(-15))
    _pumpkin(b, (0.95, 0.12, -0.55), 0.5)
    _pumpkin(b, (-0.9, 0.12, -0.6), 0.36, "fur_orange")
    return [b.finalize(N + "Decor_CornSheaf", mat)]


def _pie(b, c, r, crust="fur_croissant", fill="fur_marmalade"):
    x, y, z = c
    b.cyl((x, y + 0.07, z), r * 0.85, 0.14, "fur_pewter", segments=12, r2=r)                 # the tin
    b.cyl((x, y + 0.17, z), r * 1.06, 0.07, crust, segments=12)                              # the crust's rim
    b.cyl((x, y + 0.2, z), r * 0.86, 0.05, fill, segments=12)                                # filling
    for o in (-0.45, 0.0, 0.45):                                                              # lattice
        w = 2 * r * math.sqrt(max(0.05, 0.74 - o * o))
        b.box((x + o * r, y + 0.235, z), (r * 0.2, 0.04, w), "fur_croissant_dark")
        b.box((x, y + 0.25, z + o * r), (w, 0.04, r * 0.2), crust)


def build_pie_counter(mat):
    b = RB()
    b.span((-1.8, 0, -0.85), (1.8, 1.7, 0.85), "caramel_wood")                               # the counter
    b.span((-1.9, 1.7, -0.95), (1.9, 1.84, 0.95), "dark_wood")
    b.span((-1.6, 1.84, -0.98), (1.6, 1.88, 0.8), "fur_cream")                               # the cloth, checked
    b.span((-1.6, 1.25, -1.0), (1.6, 1.88, -0.96), "fur_cream")
    for k in range(8):
        x = -1.4 + 0.4 * k
        b.span((x - 0.1, 1.3 + 0.28 * (k % 2), -1.02), (x + 0.1, 1.5 + 0.28 * (k % 2), -0.99), "bowl_red")
    for k in range(4):
        b.box((-1.2 + 0.8 * k, 0.75, -0.87), (0.5, 0.7, 0.03), "fur_toffee")                 # panels
    _pie(b, (-1.05, 1.88, -0.25), 0.42)
    _pie(b, (1.05, 1.88, -0.3), 0.42, fill="bowl_red")
    b.cyl((0, 2.0, 0.1), 0.2, 0.24, "milk", segments=8, r2=0.1)                              # a cake stand
    b.cyl((0, 2.15, 0.1), 0.6, 0.06, "milk", segments=12)
    _pie(b, (0, 2.18, 0.1), 0.48, fill="fur_golden")
    for sx in (-1, 1):
        b.span((sx * 1.7 - 0.06, 1.84, 0.7), (sx * 1.7 + 0.06, 3.5, 0.82), "dark_wood")      # board posts
    b.span((-1.8, 2.9, 0.68), (1.8, 3.6, 0.8), "dark_wood")
    b.span((-1.65, 3.0, 0.64), (1.65, 3.5, 0.68), "choco")
    b.text("PIES", (0.62, 3.08, 0.64), 0.07, 0.03, "fur_cream", right=(-1, 0, 0))
    for k in range(7):                                                                        # bunting under it
        x = -1.5 + 0.5 * k
        b.box((x, 2.75, 0.66), (0.26, 0.26, 0.03), LEAVES[k % 5], rot=rot_z(45))
    return [b.finalize(N + "Decor_PieCounter", mat)]


def build_harvest_wreath(mat):
    b = RB()
    for sx in (-1, 1):                                                                        # the easel
        b.box((sx * 0.75, 1.9, 0.25), (0.14, 3.9, 0.14), "caramel_wood", rot=rot_z(sx * 9))
    b.box((0, 1.8, 1.0), (0.14, 3.8, 0.14), "caramel_wood", rot=rot_x(-22))
    b.span((-1.1, 1.0, 0.1), (1.1, 1.14, 0.4), "dark_wood")                                  # its ledge
    cy, r = 2.55, 1.05
    n = 12
    for k in range(n):                                                                        # the twig ring
        a = 2 * math.pi * k / n
        b.box((r * math.cos(a), cy + r * math.sin(a), 0.1), (0.62, 0.26, 0.22), "fur_brown",
              rot=rot_z(math.degrees(a) + 90))
    for k in range(18):                                                                       # leaves, two rows
        a = math.radians(20 * k)
        rr = r + (0.16 if k % 2 else -0.14)
        b.box((rr * math.cos(a), cy + rr * math.sin(a), -0.06 - 0.02 * (k % 3)), (0.44, 0.44, 0.05 + 0.006 * (k % 3)),
              LEAVES[k % 5], rot=rot_z(20 * k + 45))
    for k, deg in enumerate((35, 75, 145, 105)):                                              # wheat ears, top
        a = math.radians(deg)
        for j in range(3):
            rr = r + 0.3 + 0.17 * j
            b.box((rr * math.cos(a), cy + rr * math.sin(a), -0.02 * j), (0.16 - 0.03 * j, 0.16 - 0.03 * j, 0.1),
                  "fur_golden", rot=rot_z(deg + 45))
    for deg in (200, 215, 232, 308, 325, 340):                                                # berries, low
        a = math.radians(deg)
        b.ball((r * math.cos(a), cy + r * math.sin(a), -0.14), 0.1, "bowl_red")
    for sx in (-1, 1):                                                                        # the bow, bottom
        b.box((sx * 0.26, cy - r - 0.02, -0.16), (0.46, 0.3, 0.08), "fur_rust_red", rot=rot_z(sx * 20))
        b.box((sx * 0.2, cy - r - 0.42, -0.16), (0.18, 0.56, 0.06), "fur_rust_red", rot=rot_z(sx * 12))
    b.box((0, cy - r - 0.02, -0.19), (0.2, 0.22, 0.1), "eye_amber")
    return [b.finalize(N + "Decor_HarvestWreath", mat)]


def build_feast_pie(mat):
    b, glow = RB(), RB()
    b.cyl((0, 0.1, 0), 0.9, 0.2, "dark_wood", segments=12)                                   # the table's foot
    b.cyl((0, 0.8, 0), 0.3, 1.2, "caramel_wood", segments=10)
    b.cyl((0, 1.5, 0), 1.9, 0.2, "caramel_wood", segments=16)                                # its top
    b.cyl((0, 1.63, 0), 1.75, 0.06, "fur_cream", segments=16)                                # a cloth
    for k in range(8):
        a = math.radians(45 * k + 22.5)
        b.box((1.78 * math.cos(a), 1.4, 1.78 * math.sin(a)), (0.5, 0.36, 0.04), ("bowl_red", "fur_cream")[k % 2],
              rot=rot_y(-math.degrees(a) + 90))
    y, r = 1.66, 1.35
    b.cyl((0, y + 0.16, 0), r * 0.88, 0.32, "fur_pewter", segments=16, r2=r)                 # the tin
    b.cyl((0, y + 0.36, 0), r * 1.07, 0.12, "fur_croissant", segments=16)                    # crust rim
    b.cyl((0, y + 0.42, 0), r * 0.88, 0.08, "fur_marmalade", segments=16)                    # filling
    for o in (-0.6, -0.2, 0.2, 0.6):                                                          # lattice
        w = 2 * r * math.sqrt(0.76 - o * o)
        b.box((o * r, y + 0.48, 0), (r * 0.17, 0.06, w), "fur_croissant_dark")
        b.box((0, y + 0.51, o * r), (w, 0.06, r * 0.17), "fur_croissant")
    for k in range(10):                                                                       # crimped edge
        a = math.radians(36 * k)
        b.ball((r * 1.02 * math.cos(a), y + 0.42, r * 1.02 * math.sin(a)), 0.17, "fur_croissant", scale=(1, 0.7, 1))
    b.cyl((1.25, 1.69, -1.1), 0.42, 0.05, "milk", segments=10)                               # a slice on a plate
    b.wedge((1.25, 1.83, -1.1), (0.34, 0.22, 0.62), "fur_marmalade", rot=rot_y(40))
    b.box((1.43, 1.85, -0.9), (0.36, 0.26, 0.1), "fur_croissant", rot=rot_y(40))
    b.box((0, y + 0.95, 0), (0.05, 0.9, 0.05), "dark_wood")                                  # the flag
    b.span((0.02, y + 1.05, -0.02), (0.95, y + 1.4, 0.02), "bowl_red")
    b.text("THANKS", (0.9, y + 1.12, -0.02), 0.028, 0.02, "fur_cream", right=(-1, 0, 0))
    for k, (dx, dz) in enumerate(((-0.55, -0.3), (0.5, 0.45), (-0.2, 0.6))):                 # steam curls
        for j in range(3):
            glow.box((dx + 0.1 * math.sin(j * 1.7 + k), y + 0.85 + 0.32 * j, dz), (0.14, 0.24, 0.06), "milk",
                     rot=rot_z(22 * (-1) ** (j + k)))
    return [b.finalize(N + "Decor_FeastPie", mat), glow.finalize(N + "Decor_FeastPie_Glow", mat)]


ASSETS = {
    N + "Decor_HayBaleSofa": (build_hay_bale_sofa, 3000),
    N + "Decor_PawPumpkin": (build_paw_pumpkin, 3000),
    N + "Decor_AppleBushel": (build_apple_bushel, 3000),
    N + "Decor_CornSheaf": (build_corn_sheaf, 3000),
    N + "Decor_PieCounter": (build_pie_counter, 3000),
    N + "Decor_HarvestWreath": (build_harvest_wreath, 3000),
    N + "Decor_FeastPie": (build_feast_pie, 3000),
}
