"""The Mystery Visitor and its gift (F64, data-model.md 12b; contract from the Gameplay-Engineer, PR #459).

  CatCafe_NPC_MysteryVisitor           a smoky grey cat in a starry blue hood and capelet, sitting on a cafe chair. The client
                                       pivots it on the floor under the chair seat's centre, facing the table (-Z),
                                       so the cat sits at the chair's seat height (1.57) a little forward of the
                                       seat's middle, clear of the backrest and of the table top's edge (0.6 in front).
                                       The usual hinged sitting-cat pieces (Head, Eye1, Eye2, EarL, EarR, Tail, LegF1,
                                       LegF2); the hood is `_Prop` inside the Head and the capelet `_Cloak`, open in
                                       front so the chest and paws show. Nothing collides.
  CatCafe_Item_MysteryGift             a violet gift box with a pink ribbon and bow, pale gold stars and a "?" tag,
                                       about 1 stud; pivot at its base centre, which the client puts on the bottom of
                                       the plot's MysteryGiftAnchor (a 1 stud box on the table top).
"""

import math

from mathutils import Matrix, Vector

import cats
import props
from common import RB, Builder, scale_mesh

SIDE_FLARE = 20.0           # degrees the capelet's sides lean out toward the hem
SEAT = 1.57                 # furniture.build_chair: the cushion's top
CAT_Z = -0.15               # the cat's pivot, forward of the seat's middle (Roblox z)
CLOAK, TRIM, STAR = "galaxy_blue", "aurora_violet", "sparkle"
PAPER = "aurora_violet"     # the gift's wrapping
VISITOR = dict(rarity="Common", fur="fur_charcoal", second="fur_charcoal", eyes="eye_amber", pattern="solid",
               muzzle="fur_silver", nose="nose_dark", scale=1.3)


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def _rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _sparkle(b, c, s, face, rot=None):
    """A four-point sparkle on a face: two thin crossed bars, "x" / "-x" on a side, "-y" on the back."""
    R = rot if rot is not None else Matrix.Identity(3)
    t = 0.03
    if face in ("x", "-x"):
        bars = ((t, s, s * 0.26), (t, s * 0.26, s))
    else:
        bars = ((s, t, s * 0.26), (s * 0.26, t, s))
    for k, size in enumerate(bars):
        dx = 0.004 * k * (1 if face == "x" else -1 if face == "-x" else 0)
        dy = 0.004 * k if face == "-y" else 0.0
        b.box((c[0] + dx, c[1] + dy, c[2]), size, STAR, rot=R) if isinstance(b, props.Pen) else \
            b.box((c[0] + dx, c[1] + dy, c[2]), size, STAR, bevel=False, rot=R)


def _pwedge(P, c, size, sw, rot):
    """Builder.wedge in a Pen's frame (a WedgePart in Roblox)."""
    P.b.wedge(P.p(c), tuple(v * P.s for v in size), sw, bevel=False, rot=P._r(rot))


def _hood(ctx):
    """The hood on the head frame (origin on the head's top, y to the back; the head is 0.92 wide, 0.74 deep and
    0.76 tall): a shell over the top, sides and back with chamfered shoulders, two cat ear points lined in violet
    over the cat's own ears, a violet trim framing the face, a gold crescent on the brow and a few sparkles."""
    P = ctx.pen("head")
    W, Y0, Y1, BOT = 0.53, -0.38, 0.46, -0.86                      # outer half width, front, back, bottom edge
    yc, dep = (Y0 + Y1) / 2, Y1 - Y0
    P.box((0, yc, 0.06), (0.72, dep, 0.12), CLOAK)                                          # top
    P.box((0, Y1 - 0.04125, BOT / 2), (0.92, 0.0775, -BOT), CLOAK)                          # back, a hair in
    P.box((0, Y1 + 0.0075, BOT + 0.025), (1.08, 0.02, 0.06), TRIM)                           # hem round the back
    for sx in (1, -1):
        P.box((sx * 0.495, yc, (BOT - 0.08) / 2), (0.07, dep, -0.08 - BOT), CLOAK)          # sides
        _pwedge(P, (sx * 0.445, yc, 0.02), (dep, 0.17, 0.2), CLOAK, _rz(90 * sx))           # chamfered shoulders
        P.fan((0, 0.06, 0), (sx * 0.3, 0.46), [(sx * 0.08, 0.1), (sx * 0.47, -0.01)], 0.3, CLOAK,
              rot=_rx(90))                                                                  # ear points
        P.fan((0, -0.095, 0), (sx * 0.29, 0.37), [(sx * 0.15, 0.11), (sx * 0.41, 0.03)], 0.02, TRIM,
              rot=_rx(90))                                                                  # their lining
        P.box((sx * 0.4975, Y0 - 0.02, (BOT - 0.08) / 2), (0.075, 0.04, -0.08 - BOT), TRIM)  # trim by the face
        P.box((sx * (W + 0.005), yc, BOT + 0.025), (0.02, dep + 0.03, 0.06), TRIM)               # and the sides
        P.box((sx * 0.399, Y0 - 0.02, -0.019), (0.282, 0.045, 0.13), TRIM, rot=_ry(49.6 * sx))   # a hair proud
    P.box((0, Y0 - 0.02, 0.0625), (0.72, 0.04, 0.125), TRIM)                                # trim over the brow
    ctx.main.crescent(P.p((0, Y0 - 0.055, 0.13)), 0.09 * P.s, 0.05 * P.s, 0.03 * P.s, "gold_mid")
    for x, y, z, s in ((W + 0.015, 0.2, -0.3, 0.2), (-W - 0.015, 0.0, -0.5, 0.16), (W + 0.015, -0.05, -0.64, 0.12),
                       (-W - 0.015, 0.3, -0.22, 0.12)):
        _sparkle(P, (x, y, z), s, "x" if x > 0 else "-x")
    for x, z, s in ((0.2, -0.3, 0.18), (-0.24, -0.58, 0.14)):
        _sparkle(P, (x, Y1 + 0.01, z), s, "-y")


def _cloak(b):
    """The capelet in the sitting body's frame (Blender axes, unscaled; the pivot is on the seat; the chest is 0.7
    wide and runs up to 1.1, the haunch 0.9 wide and 0.56 tall): a back and two flared sides tucked under the hood,
    open in front, with a pointed hem and a gold bead on each point, tied across the chest with a gold clasp. It
    stays above the haunches so the chair's back and the tail stay clear."""
    TOP, HEM, TIP, BY, T = 0.92, 0.7, 0.585, 0.25, 0.07             # back: top, hem, points, centre y, thickness
    b.box((0, BY, (TOP + HEM) / 2), (0.86, T, TOP - HEM), CLOAK, bevel=False)
    w = 0.86 / 3
    for i in range(3):
        x0 = -0.43 + i * w
        b.fan((0, BY, 0), (x0 + w / 2, TIP), [(x0, HEM + 0.01), (x0 + w, HEM + 0.01)], T, CLOAK, rot=_rx(90))
        b.sphere((x0 + w / 2, BY, TIP), 0.035, "gold_mid", segments=6, rings=4)
    for x, z, s in ((0.2, 0.79, 0.1), (-0.22, 0.76, 0.08)):
        _sparkle(b, (x, BY + T / 2 + 0.01, z), s, "-y")
    a = math.radians(SIDE_FLARE)
    L = (TOP - 0.58) / math.cos(a)                                 # each side's length down its slope
    y0, y1 = -0.3, BY + T / 2                                     # each side's front and back
    for sx in (1, -1):
        X, Y = Vector((0, sx, 0)), Vector((-sx * math.sin(a), 0, math.cos(a)))
        M = Matrix((X, Y, X.cross(Y))).transposed()               # u along y, v up the slope, w out
        hinge = Vector((sx * 0.395, 0, TOP))

        def at(y, v, n=0.0):
            return tuple(hinge + M @ Vector((0, v, n)) + Vector((0, y, 0)))

        b.box(at((y0 + y1) / 2, -L / 2), (y1 - y0, L, T), CLOAK, bevel=False, rot=M)
        b.box(at(y0 - 0.015, -L / 2), (0.03, L, T + 0.02), TRIM, bevel=False, rot=M)       # front edge
        for ya, yb in ((y0, (y0 + y1) / 2), ((y0 + y1) / 2, y1)):
            u0, u1 = sx * ya, sx * yb
            b.fan(at(0, 0), ((u0 + u1) / 2, -L - 0.16), [(u0, -L + 0.01), (u1, -L + 0.01)], T, CLOAK, rot=M)
            b.sphere(at((ya + yb) / 2, -L - 0.16), 0.035, "gold_mid", segments=6, rings=4)
        for k, size in enumerate(((0.11, 0.03, 0.03), (0.03, 0.11, 0.03))):           # a sparkle
            b.box(at(0.02, -L * 0.45, T / 2 + 0.01 + 0.004 * k), size, STAR, bevel=False, rot=M)
    b.box((0, -0.345, 0.86), (0.78, 0.03, 0.06), TRIM, bevel=False)                        # the tie
    b.cyl((0, -0.37, 0.86), 0.075, 0.03, "gold_mid", segments=10, bevel=False, rot=(math.radians(90), "X"))
    b.box((0, -0.39, 0.86), (0.06, 0.02, 0.06), STAR, bevel=False, rot=_ry(45))             # its gem


def build_visitor(mat):
    name = "CatCafe_NPC_MysteryVisitor"
    cat = cats.build_cat("MysteryVisitor", mat, spec=VISITOR, base=name, body="sit")
    d = cats.dims(VISITOR, "sit")
    k = cats.scale_of(VISITOR, "sit")
    ctx = props.Ctx(VISITOR, "sit", d)
    _hood(ctx)
    hood = ctx.main.finalize(name + "_Prop", mat, location=tuple(v * k for v in d["pivots"]["Head"]))
    scale_mesh(hood, k)
    hood["rides"] = "Head"
    cb = Builder()
    _cloak(cb)
    cloak = cb.finalize(name + "_Cloak", mat)
    scale_mesh(cloak, k)
    for ob in cat + [hood, cloak]:
        ob.location = ob.location + Vector(RB.p(0, SEAT, CAT_Z))
    return cat + [hood, cloak]


def _question(b, x0, y0, z, px, sw):
    """A 3 x 5 pixel question mark facing -Z, its bottom left at (x0, y0) as the viewer sees it."""
    rows = ("111", "001", "011", "000", "010")
    for r, bits in enumerate(rows):
        for c, bit in enumerate(bits):
            if bit == "1":
                x = x0 - c * px                      # the viewer's right is -X
                y = y0 + (4 - r) * px
                b.span((x - px, y, z - 0.012), (x, y + px, z + 0.004), sw)


def build_gift(mat):
    b = RB()
    b.span((-0.45, 0.0, -0.45), (0.45, 0.62, 0.45), PAPER)                                   # box
    b.span((-0.49, 0.62, -0.49), (0.49, 0.78, 0.49), PAPER)                                  # lid
    for lo, hi in (((-0.08, 0.01, -0.465), (0.08, 0.62, 0.465)), ((-0.465, 0.01, -0.08), (0.465, 0.62, 0.08)),
                   ((-0.08, 0.62, -0.505), (0.08, 0.795, 0.505)), ((-0.505, 0.62, -0.08), (0.505, 0.795, 0.08))):
        b.span(lo, hi, "fur_strawberry")                                                     # ribbon
    for sx in (1, -1):                                                                       # bow loops
        b.box((sx * 0.17, 0.89, 0.0), (0.3, 0.17, 0.16), "fur_strawberry", rot=_rz(sx * 28))
    b.box((0.0, 0.85, 0.0), (0.14, 0.14, 0.18), "neon_pink")                                 # knot
    for x, y in ((0.27, 0.45), (0.3, 0.15)):                                                  # stars: front, left
        b.box((x, y, -0.452), (0.07, 0.07, 0.07), STAR, rot=_rz(45))
    for x, y in ((0.27, 0.42), (-0.27, 0.2), (-0.3, 0.48), (0.25, 0.14)):                     # back and sides
        b.box((-x, y, 0.452), (0.07, 0.07, 0.07), STAR, rot=_rz(45))
        for sx in (1, -1):
            b.box((sx * 0.452, y, sx * x), (0.07, 0.07, 0.07), STAR, rot=_rx(45))
    tag_x, tag_y = -0.13, 0.16                                                               # the "?" tag
    b.span((tag_x - 0.26, tag_y, -0.475), (tag_x, tag_y + 0.3, -0.455), "milk")
    _question(b, tag_x - 0.06, tag_y + 0.04, -0.475, 0.045, PAPER)
    return [b.finalize("CatCafe_Item_MysteryGift", mat)]


ASSETS = {
    "CatCafe_NPC_MysteryVisitor": (build_visitor, 2600),
    "CatCafe_Item_MysteryGift": (build_gift, 700),
}
