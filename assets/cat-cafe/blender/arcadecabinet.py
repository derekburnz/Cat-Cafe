"""The Cat Arcade's cabinet (#3062, Circle Streak; Derek2 11-10 from player its_cuzu098's idea): an upright arcade
cabinet in the Town Square that takes 1 golden fish a play. A teal body with cream side panels and pink edging, a
dark screen in a black bezel, a sloped chin under a cream control panel with a big red paw button, a joystick and a
blue button, a coin door with a gold slot plate and a fish under it, a marquee whose CAT ARCADE letters glow, and two
cat ears on top. A teal paw print on each side.

  CatCafe_Town_ArcadeCabinet          the cabinet (collides); Attachments PromptAnchor (in front of the panel, 1.5 up:
                                      the "Play" prompt), SlotAnchor (the coin slot's front, where the fish drops in),
                                      ScreenAnchor (the screen's middle, just in front of it), BangAnchor (over the ears)
    Screen                            the 2.4 x 1.9 screen (the _Screen object), front -Z: night blue, for a SurfaceGui
                                      (the idle "attract" glow, the server best) and its glow effect
    CatCafe_Town_ArcadeCabinet_Glow   the marquee's CAT ARCADE letters, Neon, for the idle pulse

    CatCafe_Town_ArcadeCabinet_Cat_*  #4272: the mouse cat on his cheese stool (a keeper cat, walk-through), his round
                                      ears in _Cat_Prop riding the Head

Pivot at the base centre of the cabinet, the screen and the panel (-Z) toward the players. The cabinet is 3.7 x 3.1
(the panel overhangs the front), 7.9 tall to the ear tips; with the #4272 corner (rug, joystick stand, gumball
machine, plush, sign) the footprint is 11.2 x 5.0. The root Model streams Atomic so the Screen is there whenever the
cabinet is.
"""

import math

from mathutils import Matrix, Vector

import cats
from alleyway import label
from cannon import frame_at
from common import RB, text_width

NAME = "CatCafe_Town_ArcadeCabinet"
HW = 1.8                                    # the half width over the side panels
CORE = 1.6                                  # the teal core's half width (the side panels are HW - CORE thick)
LOW_Z0, UP_Z0, BACK_Z = -1.2, -0.55, 1.25   # the lower body's front, the upper body's front, the back
PANEL_Y = 3.0                               # the control panel's underside
PANEL_T = 0.25
PANEL_Z0 = -1.75                            # its front edge
TOP_Y = 6.0                                 # the upper body's top, the marquee's underside
MARQ_Y1, MARQ_Z0 = 7.0, -0.95               # the marquee's top and front
SCREEN = (-1.2, 3.7, 1.2, 5.6)              # x0, y0, x1, y1
SCREEN_Z = -0.66                            # its front face
BODY, SIDE, EDGE, INK = "sign_teal", "cream", "fur_bubblegum", "fur_black"
WORDS = "CAT ARCADE"
WORD_PX = 0.085


def _side_paw(b, x, y, z, s, sw, depth=0.04):
    """A paw print standing on a side face at x (in the YZ plane), toes up."""
    b.cyl((x, y - 0.06 * s, z), 0.2 * s, depth, sw, axis="X", segments=8)
    for dz, dy in ((-0.21, 0.15), (-0.08, 0.25), (0.08, 0.25), (0.21, 0.15)):
        b.cyl((x, y + dy * s, z + dz * s), 0.075 * s, depth, sw, axis="X", segments=6)


def _body(b):
    b.span((-HW + 0.05, 0, LOW_Z0 - 0.05), (HW - 0.05, 0.3, BACK_Z), INK)                      # the kick plinth
    b.span((-CORE, 0.3, LOW_Z0), (CORE, PANEL_Y, BACK_Z), BODY)                                # the lower body
    b.wedge((0, PANEL_Y - 0.25, (PANEL_Z0 + LOW_Z0) / 2), (2 * CORE, 0.5, LOW_Z0 - PANEL_Z0), BODY,
            rot=Matrix.Rotation(math.pi, 3, "Z"))      # the chin: flat under the panel, sloping back to the body
    b.span((-CORE, PANEL_Y + PANEL_T, UP_Z0), (CORE, TOP_Y, BACK_Z), BODY)                     # the upper body
    for s in (-1, 1):
        lo, hi = sorted((s * CORE, s * HW))
        b.span((lo, 0.3, LOW_Z0 - 0.1), (hi, PANEL_Y, BACK_Z + 0.05), SIDE)                    # the side panel, low
        b.span((lo, PANEL_Y, UP_Z0), (hi, TOP_Y, BACK_Z + 0.05), SIDE)                         # and high
        e0, e1 = sorted((s * (HW - 0.06), s * (HW + 0.03)))
        b.span((e0, 0.3, LOW_Z0 - 0.14), (e1, PANEL_Y, LOW_Z0 - 0.04), EDGE)                   # pink edging
        b.span((e0, PANEL_Y + PANEL_T, UP_Z0 - 0.09), (e1, TOP_Y, UP_Z0 + 0.01), EDGE)
        _side_paw(b, s * (HW + 0.02), 1.7, 0.05, 1.9, BODY)
    b.span((-1.2, 0.7, BACK_Z), (1.2, 4.6, BACK_Z + 0.05), "fur_charcoal")                     # the back door
    for k in range(4):                                                                          # its vents
        y = 4.9 + k * 0.22
        b.span((-0.8, y, BACK_Z), (0.8, y + 0.1, BACK_Z + 0.06), INK)
    # the control panel: a cream slab overhanging the chin, pink along its front edge
    b.span((-HW, PANEL_Y, PANEL_Z0), (HW, PANEL_Y + PANEL_T, UP_Z0), SIDE)
    b.span((-HW, PANEL_Y - 0.04, PANEL_Z0 - 0.08), (HW, PANEL_Y + PANEL_T + 0.02, PANEL_Z0 + 0.02), EDGE)


def _controls(b):
    """A big red paw button (pink toe beans), a joystick and a small blue button on the panel."""
    y = PANEL_Y + PANEL_T
    px, pz = 0.55, -1.2
    b.cyl((px, y + 0.03, pz), 0.46, 0.06, INK, segments=16)                                    # its collar
    b.cyl((px, y + 0.1, pz), 0.38, 0.16, "shirt_red", segments=16)                             # the paw pad
    for dx, dz in ((-0.3, 0.38), (0.0, 0.5), (0.3, 0.38)):
        b.cyl((px + dx, y + 0.07, pz + dz), 0.12, 0.14, EDGE, segments=8)                     # toe beans
    jx, jz = -0.75, -1.15
    b.cyl((jx, y + 0.03, jz), 0.24, 0.06, INK, segments=12)
    b.cyl((jx, y + 0.22, jz), 0.05, 0.36, INK, segments=6)
    b.ball((jx, y + 0.44, jz), 0.15, "rarity_legend")
    b.cyl((-0.1, y + 0.05, -0.9), 0.14, 0.1, "rarity_rare", segments=10)


def _coin_door(b):
    """A charcoal door low on the front with a gold plate round a vertical slot and a fish under it."""
    z = LOW_Z0
    b.span((-0.7, 0.95, z - 0.05), (0.7, 2.4, z), "fur_charcoal")
    b.span((-0.36, 1.6, z - 0.09), (0.36, 2.2, z - 0.05), "rarity_legend")
    b.span((-0.06, 1.7, z - 0.11), (0.06, 2.1, z - 0.08), INK)                                 # the slot
    fz = z - 0.07
    b.ball((-0.08, 1.25, fz), 0.2, "fish_blue", scale=(1.35, 0.75, 0.15))                      # the fish
    b.fan_z(fz, (0.12, 1.25), [(0.4, 1.43), (0.4, 1.07)], 0.05, "fish_blue")
    b.cyl((-0.23, 1.29, fz - 0.03), 0.035, 0.02, INK, axis="Z", segments=6)                    # its eye
    return (0.0, 2.05, z - 0.12)


def _screen_frame(b):
    x0, y0, x1, y1 = SCREEN
    b.span((x0 - 0.2, y0 - 0.15, UP_Z0 - 0.07), (x1 + 0.2, y1 + 0.15, UP_Z0), INK)             # the bezel
    # a speaker grille between the screen and the marquee
    for k in range(5):
        x = -0.6 + k * 0.3
        b.span((x - 0.05, y1 + 0.2, UP_Z0 - 0.04), (x + 0.05, TOP_Y - 0.08, UP_Z0), "fur_charcoal")


def _marquee(b, glow):
    b.span((-HW - 0.05, TOP_Y, MARQ_Z0), (HW + 0.05, MARQ_Y1, BACK_Z + 0.05), SIDE)            # the hood
    b.span((-HW + 0.1, TOP_Y + 0.1, MARQ_Z0 - 0.04), (HW - 0.1, MARQ_Y1 - 0.1, MARQ_Z0), "night_sky")
    b.span((-HW - 0.05, TOP_Y - 0.06, MARQ_Z0 - 0.08), (HW + 0.05, TOP_Y + 0.06, MARQ_Z0 + 0.02), EDGE)
    h = 5 * WORD_PX
    label(glow, WORDS, 0.0, TOP_Y + (MARQ_Y1 - TOP_Y - h) / 2, MARQ_Z0 - 0.04, WORD_PX, 0.03, "neon_pink", -1)


def _ears(b):
    zc, depth = 0.1, 0.5
    base = MARQ_Y1 - 0.02
    for s in (-1, 1):
        xo, xi = s * (HW - 0.05), s * (HW - 1.35)
        tip = (s * (HW - 0.45), MARQ_Y1 + 0.9)
        b.fan_z(zc, tip, [(xi, base), (xo, base)], depth, SIDE)
        inner = [(s * (HW - 1.1), base + 0.06), (s * (HW - 0.25), base + 0.06)]
        b.fan_z(zc - depth / 2 - 0.02, (s * (HW - 0.5), MARQ_Y1 + 0.6), inner, 0.05, EDGE)


# #4272 (Derek 2026-11-14: "make the cat arcade area cooler maybe have a mouse cat with it and a stand with a joystick
# in front of him"): the corner round the cabinet. A checked rug, a mouse cat on a cheese stool at his own little
# joystick stand on the right, a gumball machine and a plush mouse on the left, and a mouse head sign that glows with
# the marquee. Everything stays beside or behind the cabinet, so the Play prompt in front of the panel is clear.
RUG = (-5.6, -2.9, 5.6, 2.1)               # x0, z0, x1, z1
PAL_X, PAL_Z = 3.65, -0.1                  # the mouse cat's stool
STOOL_Y = 1.15
PAL_SCALE = 1.45
PAL = dict(rarity="Common", fur="metal", second="fur_white", eyes="fur_black", pattern="solid", muzzle="fur_white",
           nose="nose_pink", scale=PAL_SCALE)
NEST = {"_Cat_Prop": "_Cat_Head"}
FOLLOWS = {"_Cat_Prop": {"Follows": "Head"}}


def _rug(b):
    x0, z0, x1, z1 = RUG
    b.span((x0, 0, z0), (x1, 0.08, z1), "fur_bubblegum")
    b.span((x0 + 0.25, 0.08, z0 + 0.25), (x1 - 0.25, 0.12, z1 - 0.25), SIDE)
    nx, nz = 8, 4
    tw, td = (x1 - x0 - 0.9) / nx, (z1 - z0 - 0.9) / nz
    for i in range(nx):
        for k in range(nz):
            if (i + k) % 2 == 0:
                cx, cz = x0 + 0.45 + (i + 0.5) * tw, z0 + 0.45 + (k + 0.5) * td
                b.span((cx - tw / 2, 0.12, cz - td / 2), (cx + tw / 2, 0.15, cz + td / 2), BODY)


def _cheese_stool(b):
    """A fat cheese wheel the mouse cat sits on, a wedge cut out of its front, darker holes."""
    b.cyl((PAL_X, STOOL_Y / 2, PAL_Z), 0.95, STOOL_Y, "pastel_butter", segments=14)
    b.cyl((PAL_X, STOOL_Y + 0.02, PAL_Z), 0.86, 0.04, "fur_custard", segments=14)
    for dx, dy, r in ((-0.5, 0.75, 0.16), (0.1, 0.4, 0.2), (0.55, 0.8, 0.12), (-0.15, 0.9, 0.1), (0.6, 0.3, 0.1)):
        b.cyl((PAL_X + dx, dy, PAL_Z - (0.95 ** 2 - dx ** 2) ** 0.5 + 0.02), r, 0.06, "fur_golden", axis="Z", segments=8)


def _joystick_stand(b):
    """The mouse cat's own little console in front of him: a teal post, a cream top tipped toward him, a big red
    joystick and two buttons."""
    x, z = PAL_X, -1.75
    b.span((x - 0.75, 0, z - 0.45), (x + 0.75, 0.2, z + 0.45), INK)
    b.span((x - 0.6, 0.2, z - 0.35), (x + 0.6, 2.05, z + 0.35), BODY)
    b.span((x - 0.62, 0.9, z - 0.38), (x + 0.62, 1.1, z - 0.33), EDGE)
    _star(b, x, 1.5, z - 0.36)
    b.span((x - 0.9, 2.05, z - 0.55), (x + 0.9, 2.25, z + 0.55), SIDE)
    b.span((x - 0.9, 2.01, z - 0.61), (x + 0.9, 2.27, z - 0.53), EDGE)
    b.cyl((x - 0.3, 2.28, z), 0.26, 0.06, INK, segments=12)
    b.cyl((x - 0.3, 2.55, z), 0.06, 0.5, INK, segments=6)
    b.ball((x - 0.3, 2.86, z), 0.2, "shirt_red")
    b.cyl((x + 0.35, 2.3, z - 0.15), 0.15, 0.1, "rarity_legend", segments=10)
    b.cyl((x + 0.55, 2.3, z + 0.2), 0.15, 0.1, "rarity_rare", segments=10)


def _star(b, x, y, z):
    b.span((x - 0.3, y - 0.08, z - 0.03), (x + 0.3, y + 0.08, z), "rarity_legend")
    b.span((x - 0.08, y - 0.3, z - 0.03), (x + 0.08, y + 0.3, z), "rarity_legend")
    b.span((x - 0.17, y - 0.17, z - 0.035), (x + 0.17, y + 0.17, z), "rarity_legend")


def _gumball(b):
    """A gumball machine on the left: red foot and body, a glass globe of coloured balls, a gold turn handle."""
    x, z = -3.5, -0.9
    b.cyl((x, 0.1, z), 0.75, 0.2, INK, segments=12)
    b.cyl((x, 0.95, z), 0.55, 1.5, "shirt_red", segments=12, r2=0.42)
    b.cyl((x, 1.8, z), 0.62, 0.22, "shirt_red", segments=12)
    b.span((x - 0.22, 1.0, z - 0.56), (x + 0.22, 1.4, z - 0.48), "rarity_legend")
    b.cyl((x, 1.2, z - 0.6), 0.1, 0.1, INK, axis="Z", segments=8)
    b.span((x - 0.2, 0.45, z - 0.52), (x + 0.2, 0.7, z - 0.44), INK)
    b.ball((x, 2.75, z), 0.95, "pastel_sky")
    for az, el, sw in ((-50, -25, "shirt_red"), (0, -35, "rarity_legend"), (50, -20, "leaf_green"), (-25, 10, "fur_bubblegum"),
                       (28, 15, "rarity_rare"), (-70, 20, "neon_pink"), (70, 25, "shirt_red"), (0, 45, "rarity_legend"),
                       (-110, -10, "rarity_rare"), (110, -5, "fur_bubblegum")):
        a, e = math.radians(az), math.radians(el)                       # gumballs pressed against the glass
        b.ball((x + 0.86 * math.sin(a) * math.cos(e), 2.75 + 0.86 * math.sin(e), z - 0.86 * math.cos(a) * math.cos(e)), 0.2, sw)
    b.cyl((x, 3.72, z), 0.5, 0.2, "shirt_red", segments=12, r2=0.3)
    b.ball((x, 3.9, z), 0.14, "rarity_legend")


def _plush(b):
    """A prize plush mouse sitting on a little gift box by the gumball machine."""
    x, z = -4.75, -1.9
    b.span((x - 0.5, 0.15, z - 0.5), (x + 0.5, 1.0, z + 0.5), "rarity_rare")
    b.span((x - 0.08, 0.15, z - 0.52), (x + 0.08, 1.02, z + 0.52), "rarity_legend")
    b.span((x - 0.52, 0.15, z - 0.08), (x + 0.52, 1.02, z + 0.08), "rarity_legend")
    b.ball((x, 1.4, z), 0.42, "fur_silver", scale=(1, 1, 0.95))
    b.ball((x, 1.98, z - 0.05), 0.36, "fur_silver")
    for s in (-1, 1):
        b.cyl((x + s * 0.34, 2.3, z), 0.24, 0.08, "fur_silver", axis="Z", segments=10)
        b.cyl((x + s * 0.34, 2.3, z - 0.045), 0.15, 0.02, EDGE, axis="Z", segments=8)
        b.ball((x + s * 0.13, 2.05, z - 0.38), 0.05, INK)
    b.ball((x, 1.93, z - 0.4), 0.07, EDGE)


def _mouse_sign(b, glow):
    """A mouse head sign on a post behind the gumball machine; its face glows with the marquee."""
    x, z, y = -3.5, 1.55, 5.3
    b.span((x - 0.12, 0, z - 0.12), (x + 0.12, y - 0.9, z + 0.12), INK)
    b.cyl((x, 0.12, z), 0.45, 0.24, INK, segments=10)
    b.cyl((x, y, z), 1.05, 0.2, "night_sky", axis="Z", segments=16)
    for s in (-1, 1):
        b.cyl((x + s * 0.95, y + 0.95, z), 0.6, 0.2, "night_sky", axis="Z", segments=12)
        glow.cyl((x + s * 0.95, y + 0.95, z - 0.12), 0.42, 0.05, "neon_pink", axis="Z", segments=12)
        glow.cyl((x + s * 0.36, y + 0.2, z - 0.12), 0.13, 0.05, "neon_pink", axis="Z", segments=8)
    glow.cyl((x, y - 0.2, z - 0.12), 0.1, 0.05, "neon_pink", axis="Z", segments=8)
    glow.span((x - 0.3, y - 0.6, z - 0.145), (x + 0.3, y - 0.52, z - 0.095), "neon_pink")            # a little smile
    for s in (-1, 1):
        glow.span((x + s * 0.3 - 0.04, y - 0.56, z - 0.145), (x + s * 0.3 + 0.04, y - 0.44, z - 0.095), "neon_pink")


def _mouse_ears(head):
    """The mouse cat's big round ears, riding his head (the _Cat_Prop object). `head`: the head's corners in Blender
    space (RB.p: Blender x, y, z = Roblox -x, z, y)."""
    xs, ys, zs = [-v[0] for v in head], [v[2] for v in head], [v[1] for v in head]
    cx, top, cz, w = (min(xs) + max(xs)) / 2, max(ys), (min(zs) + max(zs)) / 2, max(xs) - min(xs)
    p = RB()
    for s in (-1, 1):
        x = cx + s * w * 0.5
        p.cyl((x, top + w * 0.1, cz + 0.05), w * 0.4, 0.14, "metal", axis="Z", segments=14)
        p.cyl((x, top + w * 0.1, cz - 0.03), w * 0.27, 0.03, EDGE, axis="Z", segments=12)
    return p


def build_arcade_cabinet(mat):
    b = RB()
    _rug(b)
    _cheese_stool(b)
    _joystick_stand(b)
    _gumball(b)
    _plush(b)
    _body(b)
    _controls(b)
    slot = _coin_door(b)
    _screen_frame(b)
    glow = RB()
    _mouse_sign(b, glow)
    _marquee(b, glow)
    _ears(b)
    sc = RB()
    x0, y0, x1, y1 = SCREEN
    sc.span((x0, y0, SCREEN_Z), (x1, y1, UP_Z0 - 0.07), "night_sky")
    out = [b.finalize(NAME, mat), sc.finalize(NAME + "_Screen", mat), glow.finalize(NAME + "_Glow", mat)]
    cat = cats.build_cat("ArcadeMouse", mat, spec=PAL, base=NAME + "_Cat", body="sit")
    for ob in cat:
        ob.location = ob.location + Vector(RB.p(PAL_X, STOOL_Y, PAL_Z))
    import bpy
    bpy.context.view_layer.update()
    head = next(ob for ob in cat if ob.name.endswith("_Cat_Head"))
    ears = _mouse_ears([tuple(head.matrix_world @ Vector(c)) for c in head.bound_box])
    out += cat + [ears.finalize(NAME + "_Cat_Prop", mat)]
    ATTACH[:] = [("PromptAnchor", (0.0, 1.5, PANEL_Z0 - 0.5)), ("SlotAnchor", slot),
                 ("ScreenAnchor", (0.0, (y0 + y1) / 2, SCREEN_Z - 0.05)), ("BangAnchor", (0.0, MARQ_Y1 + 1.5, 0.0))]
    return out


ATTACH = []


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export."""
    return [(NAME, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACH]


assert text_width(WORDS, WORD_PX) < 2 * (HW - 0.2)

ASSETS = {
    NAME: (build_arcade_cabinet, 6500),
}
