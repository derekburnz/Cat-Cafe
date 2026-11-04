"""The shop-only cats' own furniture (#1191, Design-Agent's briefs on #1191). The cats themselves are roster cats
(cats.ROSTER Sprinkles, DuchessMarzipan, KingCroissant) with their props in props.py.

  CatCafe_Furniture_KingCushion   King Croissant's cushion throne for his role spot: a plump red velvet cushion with
                                  gold piping and a gold tassel at each corner, on a low red-and-gold base with four
                                  gold bun feet and a small gold croissant-and-crown crest on its front. Attachment
                                  Seat at the middle of the cushion's top, where the sitting cat's pivot goes (facing
                                  -Z); 2.4 x 2.4 studs, the seat 1.0 up, so the 1.3-scale King sits on it with room.

Pivot at the base centre on the floor, front -Z (Roblox). Drawn in Blender axes (front -Y).
"""

from mathutils import Matrix, Vector

from common import RB, Builder

CUSHION_W = 2.4                 # the cushion and base, square
BASE_H, CUSHION_H = 0.55, 0.45  # the base's top, and the cushion on it
SEAT_Y = BASE_H + CUSHION_H     # the Seat (Roblox y)
RED, GOLD, GOLD_LT, GOLD_DK = "shirt_red", "gold_mid", "gold_light", "gold_dark"


def build_king_cushion(mat):
    b = Builder()
    w = CUSHION_W
    for x in (-1, 1):                                                                       # bun feet
        for y in (-1, 1):
            b.ico((x * (w / 2 - 0.25), y * (w / 2 - 0.25), 0.11), 0.13, GOLD, scale=(1.0, 1.0, 0.85))
    b.box_base((0, 0, 0.2), (w - 0.1, w - 0.1, BASE_H - 0.2), RED)                          # base
    b.box_base((0, 0, 0.18), (w, w, 0.06), GOLD)                                            # its gold foot band
    b.box_base((0, 0, BASE_H - 0.06), (w + 0.02, w + 0.02, 0.06), GOLD)                     # and top band
    b.box_base((0, 0, BASE_H), (w - 0.06, w - 0.06, CUSHION_H - 0.12), RED)                 # cushion
    b.box_base((0, 0, SEAT_Y - 0.12), (w - 0.3, w - 0.3, 0.12), RED)                        # its plump top
    for s in (-1, 1):                                                                       # gold piping round it
        b.box((0, s * (w / 2 - 0.03), BASE_H + 0.17), (w - 0.02, 0.06, 0.06), GOLD_LT, bevel=False)
        b.box((s * (w / 2 - 0.03), 0, BASE_H + 0.17), (0.06, w - 0.14, 0.06), GOLD_LT, bevel=False)
    for x in (-1, 1):                                                                       # tassels
        for y in (-1, 1):
            cx, cy = x * (w / 2 - 0.02), y * (w / 2 - 0.02)
            b.ico((cx, cy, BASE_H + 0.2), 0.07, GOLD_LT)
            b.box((cx + x * 0.06, cy + y * 0.06, BASE_H + 0.04), (0.08, 0.08, 0.22), GOLD, bevel=False)
    fy = -(w - 0.1) / 2                                                                     # the crest on the front
    b.box((0, fy - 0.02, 0.37), (0.62, 0.04, 0.22), GOLD_DK, bevel=False)                   # its plate
    for i, x in enumerate((-0.2, -0.1, 0.0, 0.1, 0.2)):                                     # a croissant: five lobes
        b.box((x, fy - 0.05, 0.35 - 0.02 * abs(2 - i)), (0.11, 0.03, 0.12 - 0.015 * abs(2 - i)), GOLD_LT, bevel=False)
    for x in (-0.08, 0.0, 0.08):                                                            # and a little crown on it
        b.box((x, fy - 0.05, 0.47), (0.05, 0.03, 0.06 if x else 0.08), GOLD_LT, bevel=False)
    return [b.finalize("CatCafe_Furniture_KingCushion", mat)]


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export: the Seat on the cushion's top."""
    return [("CatCafe_Furniture_KingCushion", "Seat", Matrix.Translation(Vector(RB.p(0, SEAT_Y, 0))))]


ASSETS = {
    "CatCafe_Furniture_KingCushion": (build_king_cushion, 1200),
}
