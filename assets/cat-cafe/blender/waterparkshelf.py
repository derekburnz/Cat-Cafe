"""The Ticket Booth's shelf items (#4061, ticket-booth-and-dragon-keep.md 1.3): six Water Park decor pieces and four
cat wearables, bought with tickets. Wearables sit on the head or face only, never the neck.

  CatCafe_Decor_FlamingoFloat     a pink flamingo pool float on a round paddling pool
  CatCafe_Decor_SplashFountain    a three-tier splash fountain, a striped ball riding its jet
  CatCafe_Decor_TicketArch        a red and white striped arch with a row of lit bulbs and a ticket over the top
  CatCafe_Decor_WavePoolTiles     a tiled wave pool corner: a blue pool with white wave crests and a little ladder
  CatCafe_Decor_LifeguardChair    a tall white lifeguard chair with a red umbrella and a life ring
  CatCafe_Decor_SnackHut          a snack hut with a thatch roof, a counter with ice lollies and a menu board
  CatCafe_Accessory_SnorkelMask   a mint dive mask with a glass lens and a yellow snorkel up one side (face)
  CatCafe_Accessory_SwimCap       a snug blue swim cap with a white stripe (head)
  CatCafe_Accessory_SunVisor      a white visor band with a see-through pink peak (head)
  CatCafe_Accessory_StarfishShades  star-shaped coral shades with dark lenses (face)

The decor stands on a decor spot like the store packs' (about 4 wide and 2.5 deep, base centre, front -Z); lights are
`_Glow` (Neon), water `_Water`. The accessories are built about the cats' Outfit_Hat (head top) and Outfit_Glasses
(face) spots, like storepacks.py's, so no cat model changes (ACCESSORY_SLOTS names the spot for Looks).
"""

import math

from mathutils import Matrix

from common import RB, Builder
from plot import rot_x, rot_y, rot_z

N = "CatCafe_"
ACCESSORY_SLOTS = {"SnorkelMask": "Glasses", "SwimCap": "Hat", "SunVisor": "Hat", "StarfishShades": "Glasses"}
# money bonus each gives while placed or worn (the spec's +4% to +8% decor, +5% wearables), for Gameplay's Catalog
BONUS = {"FlamingoFloat": 0.04, "WavePoolTiles": 0.04, "LifeguardChair": 0.05, "TicketArch": 0.06,
         "SplashFountain": 0.07, "SnackHut": 0.08, "SnorkelMask": 0.05, "SwimCap": 0.05, "SunVisor": 0.05,
         "StarfishShades": 0.05}


# ------------------------------------------------------------------------------------------- cat wearables --
def build_snorkel_mask(mat):
    """At the face spot (0.05 in front of the face, eye height; Blender axes, front -Y)."""
    b = Builder()
    b.box((0, 0, 0), (0.8, 0.07, 0.3), "mint", bevel=False)                                   # the frame
    b.box((0, -0.025, 0), (0.68, 0.04, 0.2), "glass", bevel=False)                            # one wide lens
    b.box((-0.2, -0.05, 0.03), (0.05, 0.012, 0.12), "milk", bevel=False, rot=(math.radians(-35), "Y"))   # glint
    b.box((0, -0.03, -0.13), (0.16, 0.06, 0.08), "mint", bevel=False)                         # the nose piece
    for sx in (-1, 1):
        b.box((sx * 0.43, 0.3, 0.02), (0.05, 0.62, 0.07), "sign_teal", bevel=False)           # the strap
    b.box((0.47, 0.05, 0.25), (0.07, 0.07, 0.6), "rarity_legend", bevel=False)                # the snorkel
    b.box((0.47, 0.05, 0.58), (0.09, 0.09, 0.08), "shirt_red", bevel=False)
    return [b.finalize(N + "Accessory_SnorkelMask", mat)]


def build_swim_cap(mat):
    """At the head top spot: a snug cap over the head top, the ears poking through like every hat."""
    b = Builder()
    b.cyl((0, 0, 0.05), 0.47, 0.14, "shirt_blue", segments=16, bevel=False)
    b.cyl((0, 0, 0.19), 0.46, 0.14, "shirt_blue", segments=16, bevel=False, radius2=0.34)
    b.cyl((0, 0, 0.31), 0.34, 0.1, "shirt_blue", segments=14, bevel=False, radius2=0.16)
    b.cyl((0, 0, 0.035), 0.475, 0.04, "milk", segments=16, bevel=False)                       # the stripe
    b.box((0, -0.47, 0.16), (0.16, 0.03, 0.16), "milk", bevel=False, rot=Matrix.Rotation(math.radians(45), 3, "Y"))
    return [b.finalize(N + "Accessory_SwimCap", mat)]


def build_sun_visor(mat):
    """At the head top spot: a band round the head with a tinted peak out over the eyes."""
    b = Builder()
    b.ring((0, 0, 0.0), 0.5, 0.05, 0.12, "milk", segments=16, bevel=False)
    b.cyl((0, -0.5, -0.02), 0.42, 0.03, "neon_pink", segments=12, bevel=False, scale=(1.0, 0.7, 1.0))   # the peak
    b.box((0, -0.5, 0.06), (0.3, 0.03, 0.06), "rarity_legend", bevel=False)                   # a little sun badge
    return [b.finalize(N + "Accessory_SunVisor", mat)]


def build_starfish_shades(mat):
    """At the face spot: two star-shaped frames, dark lenses."""
    b = Builder()
    for sx in (-1, 1):
        for k in range(5):                                                                    # five arms
            a = math.radians(90 + 72 * k)
            b.box((sx * 0.22 + 0.12 * math.cos(a), 0, 0.12 * math.sin(a)), (0.1, 0.06, 0.2), "nose_brick", bevel=False,
                  rot=Matrix.Rotation(-(a - math.pi / 2), 3, "Y"))
        b.cyl((sx * 0.22, 0, 0), 0.14, 0.065, "fur_apricot", segments=10, bevel=False, rot=(math.radians(90), "X"))
        b.cyl((sx * 0.22, -0.02, 0), 0.1, 0.05, "fur_ink", segments=10, bevel=False, rot=(math.radians(90), "X"))
        b.box((sx * 0.43, 0.3, 0.03), (0.05, 0.62, 0.05), "nose_brick", bevel=False)          # arms
    b.box((0, 0, 0.02), (0.14, 0.05, 0.05), "nose_brick", bevel=False)                        # the bridge
    return [b.finalize(N + "Accessory_StarfishShades", mat)]


# ------------------------------------------------------------------------------------------------- decor --
def build_flamingo_float(mat):
    b, water = RB(), RB()
    b.cyl((0, 0.3, 0), 1.9, 0.6, "pastel_sky", segments=16)                                   # a paddling pool
    b.cyl((0, 0.62, 0), 1.9, 0.08, "milk", segments=16)
    water.cyl((0, 0.6, 0), 1.7, 0.1, "fish_blue", segments=16)
    b.cyl((0, 0.85, 0.1), 1.0, 0.45, "fur_bubblegum", segments=12)                            # the float's ring
    b.cyl((0, 1.09, 0.1), 0.5, 0.06, "fish_blue", segments=10)
    for k in range(4):                                                                        # the neck, curving up
        b.box((0, 1.2 + 0.42 * k, -0.85 - 0.1 * math.sin(k * 1.1)), (0.3, 0.5, 0.3), "fur_bubblegum",
              rot=rot_x(12 - 8 * k))
    b.box((0, 2.75, -1.1), (0.42, 0.42, 0.6), "fur_bubblegum")                                # the head
    b.box((0, 2.66, -1.5), (0.22, 0.2, 0.3), "milk")                                          # the beak
    b.box((0, 2.6, -1.7), (0.2, 0.2, 0.18), "fur_black", rot=rot_x(25))
    for sx in (-1, 1):
        b.box((sx * 0.215, 2.82, -1.2), (0.03, 0.1, 0.1), "fur_black")
        b.box((sx * 0.75, 1.15, 0.35), (0.25, 0.5, 0.9), "fur_strawberry", rot=rot_x(-15))      # wings
    b.box((0, 1.2, 1.05), (0.4, 0.5, 0.3), "fur_strawberry", rot=rot_x(-25))                  # the tail
    return [b.finalize(N + "Decor_FlamingoFloat", mat), water.finalize(N + "Decor_FlamingoFloat_Water", mat)]


def build_splash_fountain(mat):
    b, water, glow = RB(), RB(), RB()
    for k, (r, y, h) in enumerate(((1.9, 0.3, 0.6), (1.2, 1.5, 0.4), (0.7, 2.5, 0.3))):
        b.cyl((0, y, 0), r, h, ("milk", "pastel_sky")[k % 2], r2=r * 1.08, segments=14)
        water.cyl((0, y + h / 2 + 0.02, 0), r * 0.92, 0.08, "fish_blue", segments=14)
        if k < 2:
            b.cyl((0, y + h / 2 + 0.45, 0), 0.3, 0.9, "milk", segments=8)
    for k in range(6):                                                                        # mosaic dots on the rim
        a = math.radians(60 * k)
        b.box((1.98 * math.cos(a), 0.35, 1.98 * math.sin(a)), (0.3, 0.3, 0.08), ("shirt_red", "rarity_legend")[k % 2],
              rot=rot_y(-60 * k + 90) @ rot_z(45))
    water.cyl((0, 3.2, 0), 0.14, 1.1, "fish_belly", segments=6)                               # the jet
    b.ball((0, 4.0, 0), 0.42, "shirt_red")                                                    # the ball it holds up
    b.cyl((0, 4.0, 0), 0.435, 0.16, "milk", segments=10)
    for k in range(4):
        a = math.radians(90 * k + 45)
        glow.ball((1.5 * math.cos(a), 0.7, 1.5 * math.sin(a)), 0.13, "sparkle")
    return [b.finalize(N + "Decor_SplashFountain", mat), water.finalize(N + "Decor_SplashFountain_Water", mat),
            glow.finalize(N + "Decor_SplashFountain_Glow", mat)]


def build_ticket_arch(mat):
    b, glow = RB(), RB()
    for sx in (-1, 1):
        b.box((sx * 1.7, 0.15, 0), (0.9, 0.3, 0.9), "shirt_blue")
        for k in range(6):
            b.box((sx * 1.7, 0.55 + 0.5 * k, 0), (0.55, 0.5, 0.55), ("shirt_red", "milk")[k % 2])
    for k in range(9):                                                                        # the arch
        a = 180.0 * (k + 0.5) / 9
        ar = math.radians(a)
        b.box((1.7 * math.cos(ar), 3.3 + 1.2 * math.sin(ar), 0), (0.68, 0.55, 0.55), ("milk", "shirt_red")[k % 2],
              rot=rot_z(a + 90))
        glow.ball((1.7 * math.cos(ar), 3.3 + 1.2 * math.sin(ar), -0.33), 0.12, "sparkle")
    b.box((0, 4.95, 0), (1.5, 0.75, 0.16), "pastel_butter", rot=rot_z(-6))                    # a big ticket on top
    b.box((0, 4.95, -0.1), (0.4, 0.4, 0.06), "shirt_red", rot=rot_z(39))
    for sx in (-1, 1):
        b.box((sx * 0.6, 4.95 - sx * 0.06, -0.1), (0.08, 0.5, 0.06), "shirt_red", rot=rot_z(-6))
    return [b.finalize(N + "Decor_TicketArch", mat), glow.finalize(N + "Decor_TicketArch_Glow", mat)]


def build_wave_pool_tiles(mat):
    b, water = RB(), RB()
    b.span((-2.0, 0, -1.25), (2.0, 0.5, 1.25), "milk")
    for i in range(8):                                                                        # the tiled edge
        for (z0, z1) in ((-1.25, -0.95), (0.95, 1.25)):
            b.span((-2.0 + 0.5 * i + 0.03, 0.5, z0 + 0.03), (-1.5 + 0.5 * i - 0.03, 0.56, z1 - 0.03),
                   ("pastel_sky", "sign_teal")[i % 2])
    for i in range(4):
        for (x0, x1) in ((-2.0, -1.7), (1.7, 2.0)):
            b.span((x0 + 0.03, 0.5, -0.95 + 0.475 * i + 0.03), (x1 - 0.03, 0.56, -0.475 + 0.475 * i - 0.03),
                   ("sign_teal", "pastel_sky")[i % 2])
    water.span((-1.7, 0.42, -0.95), (1.7, 0.52, 0.95), "fish_blue")
    for k, (x, z, w) in enumerate(((-0.9, -0.4, 1.2), (0.6, 0.1, 1.5), (-0.3, 0.6, 1.0))):    # wave crests
        b.box((x, 0.56, z), (w, 0.12, 0.16), "fish_belly", rot=rot_y(8 - 8 * k))
        b.box((x + w * 0.3, 0.64, z + 0.05), (w * 0.4, 0.1, 0.12), "milk", rot=rot_y(8 - 8 * k))
    for sx in (-1, 1):                                                                        # a little ladder
        b.box((1.45 + sx * 0.2, 0.95, 0.95), (0.07, 1.0, 0.07), "fur_silver")
    for y in (0.75, 1.05, 1.35):
        b.box((1.45, y, 0.95), (0.4, 0.06, 0.07), "fur_silver")
    b.ball((-1.2, 0.72, 0.35), 0.3, "rarity_legend")                                          # a beach ball
    b.cyl((-1.2, 0.72, 0.35), 0.31, 0.1, "shirt_red", segments=8)
    return [b.finalize(N + "Decor_WavePoolTiles", mat), water.finalize(N + "Decor_WavePoolTiles_Water", mat)]


def build_lifeguard_chair(mat):
    b = RB()
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.box((sx * 0.75, 1.5, sz * 0.75), (0.16, 3.1, 0.16), "milk", rot=rot_z(-sx * 6) @ rot_x(sz * 6))
    for y in (0.7, 1.4, 2.1):                                                                 # the rungs, in front
        b.box((0, y, -0.95 + y * 0.1), (1.6 - y * 0.15, 0.1, 0.12), "milk")
    b.box((0, 3.05, 0), (1.5, 0.14, 1.4), "milk")                                             # the seat
    b.box((0, 3.75, 0.62), (1.5, 1.3, 0.14), "shirt_red")                                     # the back
    b.box((0, 3.85, 0.54), (0.5, 0.5, 0.04), "milk", rot=rot_z(45))
    for sx in (-1, 1):
        b.box((sx * 0.72, 3.4, 0), (0.1, 0.1, 1.3), "milk")                                   # arm rests
    b.box((0.72, 4.6, 0.5), (0.08, 2.6, 0.08), "fur_silver")                                  # the umbrella
    b.cyl((0.5, 5.95, 0.2), 1.5, 0.5, "shirt_red", r2=0.1, segments=8)
    b.cyl((0.5, 5.72, 0.2), 1.52, 0.08, "milk", segments=8)
    b.cyl((-0.86, 2.2, -0.2), 0.4, 0.16, "bowl_red", axis="X", segments=12)                   # a life ring on the side
    b.cyl((-0.88, 2.2, -0.2), 0.22, 0.18, "milk", axis="X", segments=10)
    return [b.finalize(N + "Decor_LifeguardChair", mat)]


def build_snack_hut(mat):
    b, glow = RB(), RB()
    b.span((-1.9, 0, -1.0), (1.9, 0.2, 1.1), "caramel_wood")
    b.span((-1.7, 0.2, -0.2), (1.7, 1.5, 1.0), "fur_vanilla")                                 # the hut's base
    for k in range(6):
        b.span((-1.7 + 0.57 * k, 0.2, -0.26), (-1.7 + 0.57 * k + 0.5, 1.5, -0.2), ("sign_teal", "milk")[k % 2])
    b.span((-1.9, 1.5, -0.7), (1.9, 1.68, 1.05), "caramel_wood")                              # the counter
    for sx in (-1, 1):
        b.box((sx * 1.6, 2.6, 0.85), (0.16, 1.9, 0.16), "dark_wood")
        b.box((sx * 1.6, 2.6, -0.5), (0.16, 1.9, 0.16), "dark_wood")
    for k, (y, w) in enumerate(((3.65, 4.3), (3.95, 3.5), (4.25, 2.6), (4.5, 1.5))):          # the thatch roof
        b.box((0, y, 0.15), (w, 0.32, 2.5 - 0.35 * k), ("fur_sand", "fur_dune")[k % 2])
    for k, (x, sw) in enumerate(((-1.1, "neon_pink"), (-0.6, "fur_orange"), (-0.1, "mint"))):  # ice lollies in a rack
        b.box((x, 2.05, -0.3), (0.26, 0.5, 0.14), sw)
        b.box((x, 1.76, -0.3), (0.06, 0.16, 0.06), "fur_cream")
    b.cyl((0.9, 1.95, -0.2), 0.28, 0.55, "milk", r2=0.36, segments=10)                        # a big drink
    b.cyl((0.9, 2.25, -0.2), 0.37, 0.06, "shirt_red", segments=10)
    b.box((1.0, 2.55, -0.2), (0.05, 0.6, 0.05), "shirt_red", rot=rot_z(-12))
    b.box((0, 3.1, 0.95), (1.6, 0.8, 0.08), "fur_ink")                                        # the menu board
    for k, sw in enumerate(("milk", "pastel_butter", "milk")):
        b.box((-0.1, 3.3 - 0.2 * k, 0.9), (1.0 - 0.2 * k, 0.07, 0.03), sw)
    for sx in (-1, 0, 1):
        glow.ball((sx * 1.2, 3.42, -0.75), 0.14, "lamp_warm")                                 # a string of lights
    b.box((0, 3.48, -0.75), (3.0, 0.04, 0.04), "dark_wood")
    return [b.finalize(N + "Decor_SnackHut", mat), glow.finalize(N + "Decor_SnackHut_Glow", mat)]


ASSETS = {
    N + "Accessory_SnorkelMask": (build_snorkel_mask, 300),
    N + "Accessory_SwimCap": (build_swim_cap, 500),
    N + "Accessory_SunVisor": (build_sun_visor, 500),
    N + "Accessory_StarfishShades": (build_starfish_shades, 600),
    N + "Decor_FlamingoFloat": (build_flamingo_float, 3000),
    N + "Decor_SplashFountain": (build_splash_fountain, 3000),
    N + "Decor_TicketArch": (build_ticket_arch, 3000),
    N + "Decor_WavePoolTiles": (build_wave_pool_tiles, 3000),
    N + "Decor_LifeguardChair": (build_lifeguard_chair, 3000),
    N + "Decor_SnackHut": (build_snack_hut, 3000),
}
