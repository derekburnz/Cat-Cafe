"""The Mystic Pool (#3314, trait-station.md section 1): the Park's Picnic Basket reworked into the trait station. Sage
Sorrel, an old sorrel-coated wizard cat with a silver beard, a starry midnight blue cape over a starry bib and a
violet pointed hat, stands behind a round pool ringed with twelve chunky stones, his staff with its glowing orb in
his right paw. The pool's glowing liquid (`_Liquid_Glow`) is its own Model so Effects/MysticPool can recolour it grey,
green, blue, gold or mythic purple as a roll lands. A violet and white checked pad under it all, and a MYSTIC POOL
A-frame sign at the front right (the players' left).

  CatCafe_Camp_Park_MysticPool                 pad, stone ring, pool floor and sign (collides)
  CatCafe_Camp_Park_MysticPool_Liquid_Glow     the liquid's disc, Neon and walk-through (rbx_export's "_Glow"); at
                                               rest aurora violet, Effects/MysticPool sets its Color during a roll
  CatCafe_Camp_Park_MysticPool_Sage_<Piece>    Sorrel, the hinged pieces of a working (body S) cat; his hat and beard
                                               (_Sage_Prop) ride the Head Model, his cape (_Sage_Prop2) rides the Body,
                                               and his staff (_Sage_Staff) rides the right arm (LegF2), so turning the
                                               arm Model about its pivot (the shoulder) raises the staff with it

Attachments (root PrimaryPart): PromptAnchor (the pool's front, 1.5 up), BangAnchor (2 over the sign), GlowAnchor
(over the pool, for CampGlow), PoolDrop (the middle of the liquid's surface, where a rolled cat drops in) and, in the
staff's part, StaffTip (the orb, where Effects/MysticPool's sparkle starts).

Pivot at the base centre on the camp's ground, front -Z, no turn of its own: the same spot as the Picnic station
(Layout.campExtras), so Gameplay swaps the asset name when the `traits` flag goes on. Footprint about 10 x 9 studs.
"""

import math

from mathutils import Matrix, Vector

import cats
import props
from common import PRIMS, RB, Builder, scale_mesh, text_width
from plot import rot_x

NAME = "CatCafe_Camp_Park_MysticPool"
PAD_X, PAD_Z0, PAD_Z1, PAD_Y = 5.0, -4.2, 4.6, 0.12      # the checked pad: half width, front, back, top
POOL_C = (0.9, 0.4)                                      # the pool's centre (x, z)
POOL_R, STONES, STONE_H = 3.0, 12, 1.05                  # stone ring: radius to the stones' middle, count, height
LIQUID_R, LIQUID_Y = 2.55, 0.85                          # the liquid disc's radius and surface
SAGE_AT = (-3.5, 2.9)                                    # where Sorrel stands (x, z), turned a little to the pool
SAGE_TURN = -20.0                                        # degrees about Y: his front toward the pool's front
SIGN_X, SIGN_Z = 4.0, -3.3                               # the A-frame's foot centre
CHECK = ("pastel_lilac", "offwhite")
STONE = ("paving_light", "paving_tan", "concrete")

# Sorrel: a reddish-brown (sorrel) coat, white muzzle and socks, amber eyes. No collectable cat wears this coat. His
# starry bib (cats.ROSTER's apron flag) is the robe's front; the cape in props-style below is its back.
CAT = dict(rarity="Common", fur="fur_russet", second="fur_white", third="fur_white", eyes="eye_amber",
           pattern="patches", muzzle="fur_white", nose="nose_brick", scale=2.1,
           apron=("galaxy_blue", ("rarity_legend", "sparkle", "rarity_legend")))
SAGE = "SageSorrel"
STAFF_ARM = "LegF2"
STAFF_UP = 2.05                                          # the pole above the paw (unscaled); it reaches down to the ground

ATTACH = []                                              # (object suffix, name, Roblox point)


def _r(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


# ------------------------------------------------------------------------------------------------ props --
def _sage_hat(ctx):
    """The wizard hat (Midnight's shape) and a long silver beard (the Gnome's, in silver)."""
    props.wizard_hat(ctx)
    F = ctx.pen("face")
    beard = "fur_silver"
    top, bot = ctx.mouth_z - 0.07, ctx.fbot - 0.22
    F.box((0, -0.075, (top + bot + 0.08) / 2), (0.46, 0.1, top - bot - 0.08), beard)
    for x, dz in ((-0.15, 0.05), (0.0, 0.0), (0.15, 0.05)):
        F.ico((x, -0.075, bot + 0.09 + dz), 0.11, beard, scale=(1.1, 0.6, 0.9))
    for sx in (-1, 1):
        lo, hi = bot + 0.12, ctx.mouth_z + 0.05
        F.box((sx * 0.3, -0.05, (lo + hi) / 2), (0.16, 0.11, hi - lo), beard)


def _sage_cape(ctx):
    """A midnight blue cape with a gold collar and gold and white stars down the back."""
    U, a, b, n, tilt, hb, ht = props._cape_body(ctx, "galaxy_blue", "rarity_legend")
    up = Matrix.Rotation(math.radians(90 - tilt), 3, "X")
    for t, x, r, sw in ((0.25, -0.22, 0.09, "rarity_legend"), (0.45, 0.2, 0.07, "sparkle"),
                        (0.7, -0.05, 0.1, "rarity_legend"), (0.9, 0.25, 0.06, "sparkle")):
        p = a + (b - a) * t + n * 0.03
        U.star((x, p.y, p.z), r, r * 0.45, 0.025, sw, rot=up)
    for x, z, r, sw in ((-0.28, -0.35, 0.08, "sparkle"), (0.22, -0.6, 0.09, "rarity_legend")):
        U.star((x, hb + 0.09, z), r, r * 0.45, 0.025, sw, rot=Matrix.Rotation(math.radians(90), 3, "X"))


def _staff(d):
    """The staff, drawn at the paw (the origin), standing straight up as the arm hangs: a knotted dark wood pole from
    the ground to a gold cup holding a glowing orb. Returns (Builder, the orb's centre)."""
    b = Builder()
    paw = Vector(d["legs"][STAFF_ARM]) + Vector((0.0, -0.01, cats.S_PAW_Z))
    down = paw.z                                          # unscaled; the cat's feet are at z 0
    h = STAFF_UP + down
    b.cyl((0, 0, STAFF_UP - h / 2), 0.055, h, "dark_wood", segments=8)
    for z in (-0.35, 0.6, 1.4):                           # knots
        b.cyl((0, 0, z), 0.075, 0.07, "caramel_wood", segments=8)
    b.cyl((0, 0, STAFF_UP + 0.04), 0.12, 0.1, "rarity_legend", segments=10, radius2=0.07)
    for k in range(4):                                    # the cup's prongs
        a = math.radians(45 + 90 * k)
        b.box((0.11 * math.cos(a), 0.11 * math.sin(a), STAFF_UP + 0.16), (0.04, 0.04, 0.16), "rarity_legend")
    orb = (0.0, 0.0, STAFF_UP + 0.26)
    b.ico(orb, 0.17, "neon_pink", subdivisions=2)
    return b, orb


# ---------------------------------------------------------------------------------------------- the pool --
def _pad(b):
    """The checked pad, 1-stud tiles, violet and white."""
    nx, nz = int(2 * PAD_X), int(PAD_Z1 - PAD_Z0)
    w, dz = 2 * PAD_X / nx, (PAD_Z1 - PAD_Z0) / nz
    for i in range(nx):
        for j in range(nz):
            x0, z0 = -PAD_X + i * w, PAD_Z0 + j * dz
            b.span((x0, 0.0, z0), (x0 + w, PAD_Y, z0 + dz), CHECK[(i + j) % 2])


def _pool(b, liquid):
    """Twelve chunky stones round a dark floor, each a little turned and a little higher or lower than its
    neighbours; the liquid disc sits 0.02 inside the stones so their faces never share a plane with it."""
    cx, cz = POOL_C
    b.cyl((cx, PAD_Y + 0.05, cz), POOL_R - 0.2, 0.1, "night_sky", segments=24)          # the pool's floor
    for k in range(STONES):
        a = 2 * math.pi * (k + 0.5) / STONES
        h = STONE_H + (0.15, -0.05, 0.08, 0.0)[k % 4]
        w = 2 * math.pi * POOL_R / STONES * 0.92
        c = (cx + POOL_R * math.cos(a), PAD_Y + h / 2, cz + POOL_R * math.sin(a))
        b.box(c, (w, h, 1.0), STONE[k % 3], rot=_r(-math.degrees(a) + 90 + (4, -3, 2)[k % 3]))
        b.box((c[0], PAD_Y + h + 0.06, c[2]), (w - 0.15, 0.12, 0.85), "paving_light",       # a lighter cap
              rot=_r(-math.degrees(a) + 90 + (4, -3, 2)[k % 3]))
    liquid.cyl((cx, (PAD_Y + 0.1 + LIQUID_Y) / 2, cz), LIQUID_R, LIQUID_Y - PAD_Y - 0.1, "aurora_violet",
               segments=24)
    ATTACH.append(("", "PoolDrop", (cx, LIQUID_Y, cz)))
    ATTACH.append(("", "GlowAnchor", (cx, LIQUID_Y + 1.5, cz)))


def _sign(b):
    """A violet A-frame with a chalk face: MYSTIC / POOL, a gold star band, TRAITS under it. Returns its top."""
    lean = 12
    R, Rb = rot_x(lean), rot_x(-lean)
    H, W = 2.6, 1.9
    base = (SIGN_X, PAD_Y, SIGN_Z)
    back_foot = (SIGN_X, PAD_Y, SIGN_Z + 2 * H * math.sin(math.radians(lean)))

    def at(p, Rm=R, o=base):
        v = Rm @ Vector(p)
        return (o[0] + v.x, o[1] + v.y, o[2] + v.z)

    b.box(at((0, H / 2, 0)), (W, H, 0.1), "caramel_wood", rot=R)
    b.box(at((0, H / 2, 0), Rm=Rb, o=back_foot), (W, H, 0.1), "caramel_wood", rot=Rb)
    b.box(at((0, H / 2 - 0.1, -0.06)), (W - 0.2, H - 0.45, 0.03), "fur_charcoal", rot=R)      # chalk
    for k in range(7):                                                                        # violet check band
        b.box(at((-W / 2 + 0.13 + (k + 0.5) * (W - 0.26) / 7, H - 0.4, -0.065)), ((W - 0.26) / 7, 0.2, 0.025),
              ("aurora_violet", "offwhite")[k % 2], rot=R)
    right, upv = tuple(R @ Vector((-1, 0, 0))), tuple(R @ Vector((0, 1, 0)))
    for word, y, px, sw in (("MYSTIC", H / 2 + 0.45, 0.05, "offwhite"), ("POOL", H / 2 - 0.05, 0.05, "offwhite"),
                            ("TRAITS", 0.55, 0.03, "rarity_legend")):
        w = text_width(word, px)
        b.text(word, at((w / 2, y, -0.075)), px, 0.02, sw, right=right, up=upv)
    for x in (-0.62, 0.62):                                                                   # stars by TRAITS
        b.box(at((x, 0.62, -0.08)), (0.1, 0.1, 0.02), "rarity_legend",
              rot=R @ Matrix.Rotation(math.radians(45), 3, "Z"))
    gap = back_foot[2] - SIGN_Z
    b.box((SIGN_X, PAD_Y + 0.6, SIGN_Z + gap / 2), (W - 0.1, 0.06, gap - 0.12), "dark_wood")   # the stay
    return at((0, H, 0))


# ---------------------------------------------------------------------------------------------- Sorrel --
def _sage(mat):
    """Sorrel, standing (body S), his hat and beard, cape and staff, moved to SAGE_AT and turned SAGE_TURN."""
    base = NAME + "_Sage"
    saved = props.PROPS.get(SAGE), props.PROPS2.get(SAGE)
    props.PROPS[SAGE], props.PROPS2[SAGE] = ("Head", _sage_hat), ("Back", _sage_cape)
    try:
        objs = [o for o in cats.build_cat(SAGE, mat, spec=CAT, base=base, body="work") if "_Held_" not in o.name]
    finally:
        for table, old in ((props.PROPS, saved[0]), (props.PROPS2, saved[1])):
            if old is None:
                table.pop(SAGE, None)
            else:
                table[SAGE] = old
    _drop_held()
    d = cats.dims(CAT, "work")
    k = cats.scale_of(CAT, "work")
    sb, orb = _staff(d)
    paw = Vector(d["legs"][STAFF_ARM]) + Vector((0.0, -0.01, cats.S_PAW_Z))
    staff = sb.finalize(base + "_Staff", mat, location=tuple(v * k for v in paw))
    scale_mesh(staff, k)
    staff["rides"] = STAFF_ARM
    objs.append(staff)
    # turn about the model's origin (his feet), then move him to his spot on the pad; the turn goes into each
    # piece's mesh and primitive log (as scale_mesh), so every object keeps an unturned transform (the gates)
    R = Matrix.Rotation(math.radians(SAGE_TURN), 4, "Z")
    T = Matrix.Translation(Vector(RB.p(SAGE_AT[0], PAD_Y, SAGE_AT[1]))) @ R
    for ob in objs:
        ob.data.transform(R)
        PRIMS[ob.data.name] = [(kd, R @ m, sw, ex) for kd, m, sw, ex in PRIMS.get(ob.data.name, [])]
        ob.location = T @ Vector(ob.location)
    tip = T @ (Vector(paw) * k + Vector(orb) * k)
    ATTACH.append(("_Sage_Staff", "StaffTip", (-tip.x, tip.z, tip.y)))
    return objs


def _drop_held():
    """build_cat made the working body's held things too; remove the ones left out of the model from the scene."""
    import bpy
    for ob in [o for o in bpy.data.objects if o.name.startswith(NAME + "_Sage_Held_")]:
        bpy.data.objects.remove(ob, do_unlink=True)


def build_mystic_pool(mat):
    ATTACH.clear()
    b, liquid = RB(), RB()
    _pad(b)
    _pool(b, liquid)
    top = _sign(b)
    ATTACH.append(("", "PromptAnchor", (POOL_C[0], 1.5, POOL_C[1] - POOL_R - 1.4)))
    ATTACH.append(("", "BangAnchor", (top[0], top[1] + 2.0, top[2])))
    return [b.finalize(NAME, mat), liquid.finalize(NAME + "_Liquid_Glow", mat)] + _sage(mat)


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export; "" is the root (the pad's object, NAME)."""
    out = []
    for suffix, n, p in ATTACH:
        out.append((NAME if suffix == "" else suffix, n, Matrix.Translation(Vector(RB.p(*p)))))
    return out


NEST = {"_Prop": "_Head", "_Staff": "_LegF2"}

ASSETS = {
    NAME: (build_mystic_pool, 9000),
}
