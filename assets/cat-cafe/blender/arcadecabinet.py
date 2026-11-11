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

Pivot at the base centre, the screen and the panel (-Z) toward the players. Footprint 3.7 x 3.1 (the panel
overhangs the front), 7.9 tall to the ear tips. The root Model streams Atomic so the Screen is there whenever the
cabinet is.
"""

import math

from mathutils import Matrix, Vector

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


def build_arcade_cabinet(mat):
    b = RB()
    _body(b)
    _controls(b)
    slot = _coin_door(b)
    _screen_frame(b)
    glow = RB()
    _marquee(b, glow)
    _ears(b)
    sc = RB()
    x0, y0, x1, y1 = SCREEN
    sc.span((x0, y0, SCREEN_Z), (x1, y1, UP_Z0 - 0.07), "night_sky")
    out = [b.finalize(NAME, mat), sc.finalize(NAME + "_Screen", mat), glow.finalize(NAME + "_Glow", mat)]
    ATTACH[:] = [("PromptAnchor", (0.0, 1.5, PANEL_Z0 - 0.5)), ("SlotAnchor", slot),
                 ("ScreenAnchor", (0.0, (y0 + y1) / 2, SCREEN_Z - 0.05)), ("BangAnchor", (0.0, MARQ_Y1 + 1.5, 0.0))]
    return out


ATTACH = []


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export."""
    return [(NAME, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACH]


assert text_width(WORDS, WORD_PX) < 2 * (HW - 0.2)

ASSETS = {
    NAME: (build_arcade_cabinet, 4000),
}
