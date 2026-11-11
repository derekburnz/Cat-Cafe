"""The Mystic Pool (#3314, trait-station.md section 1): the Park's Picnic Basket reworked into the trait station. Sage
Sorrel, an old sorrel-coated wizard cat with a silver beard, a starry midnight blue cape over a starry bib and a
violet pointed hat, stands behind a round pool ringed with twelve chunky stones, his staff with its glowing orb in
his right paw. The pool's glowing liquid (`_Liquid_Glow`) is its own Model so Effects/MysticPool can recolour it grey,
green, blue, gold or mythic purple as a roll lands. A violet and white checked pad inside a low stone kerb under it
all, and a MYSTIC POOL A-frame sign at the front right (the players' left).

Dressing (2026-11-11, toward the Fish Market bar): a moon arch behind the pool (two banded stone pillars, a stepped
lintel, a gold crescent and two hanging lanterns), a footing course and moss tufts on the stone ring, glowing star
runes on three front stones, amethyst crystal clusters on the pad, and Sorrel's spell books with a candle.

  CatCafe_Camp_Park_MysticPool                 pad, stone ring, pool floor and sign (collides)
  CatCafe_Camp_Park_MysticPool_Liquid_Glow     the liquid's disc, Neon and walk-through (rbx_export's "_Glow"); at
                                               rest aurora violet, Effects/MysticPool sets its Color during a roll
  CatCafe_Camp_Park_MysticPool_Runes_Glow      the star runes on the front stones, Neon and walk-through, always lit
  CatCafe_Camp_Park_MysticPool_Lantern_Bulb    the arch's two lantern lights; WorldController lights _Bulb at night
  CatCafe_Camp_Park_MysticPool_Sage_<Piece>    Sorrel, the hinged pieces of a working (body S) cat; his hat and beard
                                               (_Sage_Prop) ride the Head Model, his cape (_Sage_Prop2) rides the Body,
                                               and his staff (_Sage_Staff) rides the right arm (LegF2), so turning the
                                               arm Model about its pivot (the shoulder) raises the staff with it

Attachments (root PrimaryPart): PromptAnchor (the pool's front, 1.5 up), BangAnchor (2 over the sign), GlowAnchor
(over the pool, for CampGlow), PoolDrop (the middle of the liquid's surface, where a rolled cat drops in) and, in the
staff's part, StaffTip (the orb, where Effects/MysticPool's sparkle starts).

Pivot at the base centre on the camp's ground, front -Z, no turn of its own: the same spot as the Picnic station
(Layout.campExtras), so Gameplay swaps the asset name when the `traits` flag goes on. Footprint about 10 x 9 studs,
8 tall at the crescent.
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
BORDER, BORDER_Y = 0.3, 0.2                              # the pad's stone kerb: width, top
ARCH_X, ARCH_Z, ARCH_H = (-1.3, 3.1), 4.05, 5.4          # the moon arch behind the pool: pillar x, z, pillar top
RUNE_STONES = (6, 8, 10)                                 # front-facing stones that carry a glowing rune

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
    top, foot = ht - 0.03, 0.04 - 0.98                     # the cape's drop to the floor (props._cape_body)
    for x, z, r, sw in ((-0.28, -0.35, 0.08, "sparkle"), (0.22, -0.6, 0.09, "rarity_legend")):
        face = hb + 0.03 + 0.04 * (top - z) / (top - foot) + 0.02     # the drop's outer face at this height
        U.star((x, face + 0.008, z), r, r * 0.45, 0.025, sw, rot=Matrix.Rotation(math.radians(90), 3, "X"))


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
    """The checked pad, violet and white tiles inside a low stone kerb (its top 0.08 over the tiles)."""
    x0, x1, z0, z1 = -PAD_X + BORDER, PAD_X - BORDER, PAD_Z0 + BORDER, PAD_Z1 - BORDER
    nx, nz = 9, 8
    w, dz = (x1 - x0) / nx, (z1 - z0) / nz
    for i in range(nx):
        for j in range(nz):
            a, c = x0 + i * w, z0 + j * dz
            b.span((a, 0.0, c), (a + w, PAD_Y, c + dz), CHECK[(i + j) % 2])
    for lo, hi in (((-PAD_X, 0.0, PAD_Z0), (PAD_X, BORDER_Y, z0)), ((-PAD_X, 0.0, z1), (PAD_X, BORDER_Y, PAD_Z1)),
                   ((-PAD_X, 0.0, z0), (x0, BORDER_Y, z1)), ((x1, 0.0, z0), (PAD_X, BORDER_Y, z1))):
        b.span(lo, hi, "paving_tan")
    for x in (-PAD_X + 0.21, PAD_X - 0.21):                                                # corner posts
        for z in (PAD_Z0 + 0.21, PAD_Z1 - 0.21):
            b.box((x, BORDER_Y + 0.09, z), (0.42, 0.18, 0.42), "paving_light")


def _pool(b, liquid, runes):
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
        turn = _r(-math.degrees(a) + 90 + (4, -3, 2)[k % 3])
        b.box((c[0], PAD_Y + h + 0.06, c[2]), (w - 0.15, 0.12, 0.85), "paving_light", rot=turn)   # a lighter cap
        out = (math.cos(a), math.sin(a))
        f = POOL_R + 0.62                                                                     # the footing course
        b.box((cx + f * out[0], PAD_Y + 0.15, cz + f * out[1]), (w * 1.08, 0.3, 0.36), "paving_grout", rot=_r(
            -math.degrees(a) + 90))
        if k % 3 == 1:                                                                        # a moss tuft on the cap
            m = (c[0] + 0.12 * out[0], PAD_Y + h + 0.13, c[2] + 0.12 * out[1])
            b.ball(m, 0.22, "leaf_green", scale=(1.3, 0.45, 1.0))
            b.ball((m[0] + 0.2 * out[1], m[1] - 0.02, m[2] - 0.2 * out[0]), 0.14, "leaf_dark", scale=(1.2, 0.5, 1.0))
        if k in RUNE_STONES:                                                                  # a glowing rune
            _rune(runes, c, out, h, turn)
    liquid.cyl((cx, (PAD_Y + 0.1 + LIQUID_Y) / 2, cz), LIQUID_R, LIQUID_Y - PAD_Y - 0.1, "aurora_violet",
               segments=24)
    ATTACH.append(("", "PoolDrop", (cx, LIQUID_Y, cz)))
    ATTACH.append(("", "GlowAnchor", (cx, LIQUID_Y + 1.5, cz)))


def _rune(r, c, out, h, turn):
    """A star rune on a stone's outer face: a diamond with a dot over it and a bar under it, standing 0.04 proud."""
    d = 0.5 + 0.015
    fx, fz = c[0] + d * out[0], c[2] + d * out[1]
    y = PAD_Y + h * 0.5
    r.box((fx, y, fz), (0.3, 0.3, 0.06), "rarity_epic", rot=turn @ Matrix.Rotation(math.radians(45), 3, "Z"))
    r.box((fx, y + 0.34, fz), (0.1, 0.1, 0.06), "rarity_epic", rot=turn)
    r.box((fx, y - 0.32, fz), (0.36, 0.07, 0.06), "rarity_epic", rot=turn)


def _crystals(b, at, n, seed, size=1.0):
    """A cluster of amethyst crystals on the pad: tall square prisms with a turned point, leaning out from a shared
    foot sunk into the tiles."""
    sw = ("eye_violet", "aurora_violet", "rarity_epic", "velvet_lilac")
    for k in range(n):
        a = seed + k * 2.4
        lean = 12 + 9 * (k % 3)
        hh = size * (1.3 - 0.22 * k + 0.1 * (k % 2))
        t = 0.3 * size * (1 - 0.1 * k)
        R = _r(math.degrees(a)) @ Matrix.Rotation(math.radians(lean), 3, "X")
        foot = Vector((at[0] + 0.14 * k * math.cos(a), PAD_Y - 0.06, at[1] + 0.14 * k * math.sin(a)))
        mid = foot + R @ Vector((0, hh / 2, 0))
        b.box(tuple(mid), (t, hh, t), sw[k % 4], rot=R)
        tip = foot + R @ Vector((0, hh + 0.08 * size, 0))
        b.box(tuple(tip), (t * 0.62, t * 0.62, t * 0.62), sw[(k + 2) % 4],
              rot=R @ Matrix.Rotation(math.radians(45), 3, "Y") @ Matrix.Rotation(math.radians(45), 3, "X"))


def _arch(b, lamps):
    """A moon arch behind the pool: two stone pillars on footings, a stepped stone lintel with a gold crescent moon
    in the middle, and a star lantern hanging under each end."""
    xa, xb = ARCH_X
    for x in (xa, xb):
        b.box((x, PAD_Y + 0.25, ARCH_Z), (1.0, 0.5, 1.0), "paving_grout")                     # footing
        b.box((x, PAD_Y + 0.5 + (ARCH_H - 0.5) / 2, ARCH_Z), (0.7, ARCH_H - 0.5, 0.7), "paving_light")
        for y in (1.6, 3.2):                                                                  # stone bands
            b.box((x, PAD_Y + y, ARCH_Z), (0.8, 0.22, 0.8), "paving_tan")
        b.box((x, PAD_Y + ARCH_H + 0.12, ARCH_Z), (0.95, 0.24, 0.95), "paving_tan")           # capital
    span = xb - xa + 0.95
    steps = (0.0, 0.22, 0.38, 0.22, 0.0)
    w = span / len(steps)
    top = PAD_Y + ARCH_H + 0.24
    for k, rise in enumerate(steps):                                                          # the stepped lintel
        x = xa - 0.475 + (k + 0.5) * w
        b.box((x, top + (0.5 + rise) / 2, ARCH_Z), (w + 0.02 * (k % 2), 0.5 + rise, 0.62 - 0.04 * (k % 2)),
              ("paving_light", "paving_tan")[k % 2])
    mx, my = (xa + xb) / 2, top + 0.88 + 0.6
    n = 12
    for k in range(n):                                                                        # a gold crescent moon
        t = math.radians(40 + 280 * k / (n - 1))
        thick = 0.14 + 0.16 * math.sin(math.pi * k / (n - 1))
        b.box((mx + 0.62 * math.cos(t), my + 0.62 * math.sin(t), ARCH_Z), (0.34, thick, 0.2 + 0.04 * (k % 2)),
              "rarity_legend", rot=Matrix.Rotation(t + math.pi / 2, 3, "Z"))
    for x in (xa + 0.6, xb - 0.6):                                                           # hanging star lanterns
        b.box((x, top - 0.35, ARCH_Z), (0.04, 0.7, 0.04), "dark_wood")
        b.box((x, top - 0.78, ARCH_Z), (0.34, 0.08, 0.34), "brass")
        lamps.box((x, top - 1.02, ARCH_Z), (0.28, 0.4, 0.28), "lamp_warm")
        b.box((x, top - 1.26, ARCH_Z), (0.34, 0.08, 0.34), "brass")
    return mx, my


def _books(b):
    """A stack of three spell books and a candle by Sorrel's feet."""
    x, z = -4.0, 0.9
    y = PAD_Y
    for k, (sw, w, d, h, turn) in enumerate((("royal_berry", 0.9, 0.65, 0.2, 6), ("galaxy_blue", 0.8, 0.6, 0.18, -8),
                                             ("shirt_green", 0.7, 0.55, 0.16, 15))):
        b.box((x, y + h / 2, z), (w, h, d), sw, rot=_r(turn))
        b.box((x + 0.02, y + h / 2, z - d / 2 + 0.005), (w - 0.1, h - 0.06, 0.03), "offwhite", rot=_r(turn))
        y += h
    b.cyl((x + 0.1, y + 0.2, z + 0.05), 0.09, 0.4, "cream", segments=8)
    b.box((x + 0.1, y + 0.03, z + 0.05), (0.3, 0.06, 0.3), "brass")


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
    b, liquid, runes, lamps = RB(), RB(), RB(), RB()
    _pad(b)
    _pool(b, liquid, runes)
    _arch(b, lamps)
    _books(b)
    _crystals(b, (POOL_C[0] + 3.1, POOL_C[1] + 2.5), 4, 0.3)
    _crystals(b, (POOL_C[0] - 3.3, POOL_C[1] - 3.0), 3, 2.0, size=0.8)
    _crystals(b, (4.4, -1.8), 2, 4.1, size=0.6)
    top = _sign(b)
    ATTACH.append(("", "PromptAnchor", (POOL_C[0], 1.5, POOL_C[1] - POOL_R - 1.4)))
    ATTACH.append(("", "BangAnchor", (top[0], top[1] + 2.0, top[2])))
    return [b.finalize(NAME, mat), liquid.finalize(NAME + "_Liquid_Glow", mat), runes.finalize(NAME + "_Runes_Glow", mat),
            lamps.finalize(NAME + "_Lantern_Bulb", mat)] + _sage(mat)


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
