"""Harvest Hollow's pumpkin as a picture (#4251): the area's points, shown beside every count in the Harvest Stall,
the catch card and the HUD in place of the pumpkin emoji, which draws differently on every device. A chunky pumpkin
seen a little from above: five fat ribs, a pale shine, a curled stem and one leaf, so it still reads at 28 px.
icons.py renders it as CatCafe_Icon_Harvest_Pumpkin.
"""
import math

from common import Builder

N = "CatCafe_IconArt_Harvest_"
R = math.radians


def pumpkin(mat):
    b = Builder()
    for k, x in enumerate((-0.78, -0.42, 0.0, 0.42, 0.78)):                 # the ribs, the middle one nearest
        edge = abs(x) / 0.78
        b.ico((x, -0.22 * (1.0 - edge), 0.74), 0.5, ("fur_marmalade", "fur_orange")[k % 2],
              scale=(0.86 - 0.12 * edge, 1.0, 1.42 - 0.2 * edge), subdivisions=3)
    b.ico((0.0, 0.0, 0.2), 0.5, "fur_orange", scale=(1.9, 1.0, 0.36), subdivisions=2)   # the base, closing the gaps
    b.box((-0.44, -0.7, 0.98), (0.12, 0.05, 0.3), "milk", bevel=False, rot=(R(18), "Y"))  # the shine
    b.cyl_base((0.0, -0.05, 1.3), 0.14, 0.34, "leaf_dark", segments=8, bevel=False, radius2=0.1)
    b.box((0.12, -0.05, 1.68), (0.34, 0.2, 0.14), "leaf_dark", rot=(R(-22), "Y"))        # the stem's curl
    b.ico((0.5, -0.12, 1.44), 0.24, "leaf_green", scale=(1.5, 0.5, 0.7), subdivisions=2)  # the leaf
    return [b.finalize(N + "Pumpkin", mat)]


BUILDERS = {"Pumpkin": pumpkin}
VIEWS = {"Pumpkin": (0.0, 10.0)}
