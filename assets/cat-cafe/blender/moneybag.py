"""The rich customer's money bag (#3360, rich-money-bags.md section 5): the bag a rich customer leaves on table 1,
which the owner walks into or taps to collect the rich payout.

  CatCafe_Prop_MoneyBag        a plump cream sack tied with a gold cord and a bow, a big gold coin with a paw on its
                               front, a darker patch on one side and two gold coins spilled at its foot
  CatCafe_Prop_MoneyBag_Glow   one small sparkle star over the knot, Neon and walk-through (rbx_export's "_Glow")

Pivot at the base centre, front -Z (the coin faces the way a player walks up to table 1). About 1.9 studs wide and
2.1 tall, so it reads from across the cafe and still fits beside the tip pile ring. The gold parts are Metal.
The client clones one per waiting bag (up to RichBagsMax 3) and fades it over the last RichBagFadeSeconds.
"""

import math

from common import RB
from plot import rot_x, rot_y, rot_z

NAME = "CatCafe_Prop_MoneyBag"
CLOTH, SHADE, CORD, COIN, COIN_HI, COIN_LO = "fur_oat", "fur_sand", "gold_mid", "gold_mid", "gold_light", "gold_dark"
R = 0.82                                           # the sack's belly radius


def _coin(b, c, r, rot=None):
    """A flat coin lying down (rot stands or tilts it): a rim, a lighter face."""
    b.b.cyl(RB.p(*c), r, 0.09, COIN, segments=8, bevel=False, rot=RB._rot(rot))
    b.b.cyl(RB.p(*c), r * 0.7, 0.11, COIN_HI, segments=8, bevel=False, rot=RB._rot(rot))


def build_money_bag(mat):
    b, glow = RB(), RB()
    b.b.sphere(RB.p(0, 0.72, 0), R, CLOTH, segments=8, rings=5, scale=(1.0, 0.95, 0.88))   # the belly, squashed
    b.ball((0, 0.3, 0), R * 0.9, CLOTH, scale=(1.08, 0.4, 1.02))              # its sagging foot
    b.cyl((0, 1.38, 0), 0.42, 0.3, CLOTH, r2=0.26, segments=8)                 # the shoulders, up to the neck
    b.cyl((0, 1.56, 0), 0.25, 0.12, CORD, segments=8)                          # the gold cord
    b.cyl((0, 1.78, 0), 0.24, 0.34, CLOTH, r2=0.46, segments=8)                # the gathered top, flaring
    for sx in (-1, 1):                                                         # the bow at the front
        b.box((sx * 0.2, 1.56, -0.3), (0.3, 0.2, 0.08), CORD, rot=rot_z(sx * 22))
    b.box((0, 1.56, -0.33), (0.13, 0.13, 0.1), COIN_LO)                        # the knot
    # the coin on the front: rim, face and a paw
    face = rot_x(90)
    b.b.cyl(RB.p(0, 0.74, -0.74), 0.4, 0.08, COIN_LO, segments=10, bevel=False, rot=RB._rot(face))
    b.b.cyl(RB.p(0, 0.74, -0.77), 0.33, 0.08, COIN, segments=10, bevel=False, rot=RB._rot(face))
    b.b.cyl(RB.p(0, 0.67, -0.81), 0.12, 0.04, COIN_HI, segments=6, bevel=False, rot=RB._rot(face))
    for dx, dy in ((-0.15, 0.13), (0.0, 0.2), (0.15, 0.13)):
        b.box((dx, 0.74 + dy, -0.81), (0.08, 0.08, 0.04), COIN_HI, rot=rot_z(45))
    # a stitched patch on the right side
    b.box((0.76, 0.8, 0.1), (0.06, 0.34, 0.34), SHADE, rot=rot_z(-6))
    # coins spilled at the foot
    _coin(b, (-0.95, 0.045, -0.45), 0.24)
    _coin(b, (0.88, 0.13, -0.5), 0.24, rot=rot_z(-20))
    # a sparkle over the knot: two crossed bars
    for a in (0, 90):
        glow.box((0.42, 2.25, -0.1), (0.36, 0.08, 0.08), "sparkle", rot=rot_z(a))
    return [b.finalize(NAME, mat), glow.finalize(NAME + "_Glow", mat)]


ASSETS = {
    NAME: (build_money_bag, 500),
}
