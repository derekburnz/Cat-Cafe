"""Cat accessories: small meshes that sit on a cat part at a named slot.

Each accessory's pivot is its slot, so in Studio: pivot the accessory to the cat's Outfit_<Piece> Attachment (or to
the part in its slot at that part-local offset, times the cat's Scale) and weld or anchor it there.

Role outfits (data-model section 5): working cats sit at their stations on body B (CatCafe_Cat_<Name>_Sit; the
engineer, 2026-10-27) in their role's two pieces, so the pieces are built to fit B's chest and head, which are the
same on every cat (cats.B_CHEST_*, cats.HEADS["sit"]), each around its slot in SIT_SLOTS. The sitting models carry
one Outfit_<Piece> Attachment per piece at those slots. Cats wear no collar (Derek, 2026-10-27), so the outfit is
what marks a cat as staff. Glasses and Hat are the first generic accessories, on the walking head (slots()). Walking
staff (F90) wear the pieces that fit A (WALK_PIECES), so the walking models carry those Outfit_<Piece> slots too.
"""

import math

from mathutils import Matrix, Vector

import cats
from common import Builder, scale_mesh

K = cats.SIT_SCALE
# B's chest, unscaled: half width, front and back, the bottom of the outfit and the line under the chin
X1 = cats.B_CHEST_S[0] / 2
Y0, Y1 = cats.B_CHEST_C[1] - cats.B_CHEST_S[1] / 2, cats.B_CHEST_C[1] + cats.B_CHEST_S[1] / 2
Z0 = cats.B_CHEST_C[2] - cats.B_CHEST_S[2] / 2 + 0.02
NECK_Z = cats.B_NECK[2] + cats.HEADS["sit"]["c"][2] - cats.HEADS["sit"]["s"][2] / 2
MID = (Z0 + NECK_Z) / 2
HAT_AT, HAT_K = (0.0, -0.2, 0.65), 1.25      # on top of B's head, relative to the neck; hats a quarter bigger

# piece -> (cat part, slot offset from that part's pivot, unscaled)
_SLOTS = {
    "Apron":      ("Body", (0.0, Y0, MID)),                 # middle of the chest front
    "BowTie":     ("Body", (0.0, Y0 - 0.035, NECK_Z - 0.18)),   # under the chin
    "Vest":       ("Body", (0.0, (Y0 + Y1) / 2, MID)),      # middle of the chest
    "Sash":       ("Body", (0.0, (Y0 + Y1) / 2, MID)),
    "Cape":       ("Body", (0.0, Y1, NECK_Z)),              # back of the shoulders
    "BaristaCap": ("Head", HAT_AT),
    "Boater":     ("Head", HAT_AT),
    "PartyHat":   ("Head", HAT_AT),
}
# The same in the sitting model's space before the cat's Scale: (part, offset, rotation_xyz_deg)
SIT_SLOTS = {n: (part, tuple(round(v * K, 4) for v in at), (0, 0, 0)) for n, (part, at) in _SLOTS.items()}

ROLE_OUTFITS = {"barista": ("Apron", "BaristaCap"), "waiter": ("BowTie", "Vest"), "greeter": ("Sash", "Boater"),
                "entertainer": ("PartyHat", "Cape")}


def slots(spec, body="sit"):
    """(part, offset, rotation) per accessory on one cat's model before its Scale: the role pieces on the sitting
    body, Glasses and Hat on the walking one (just in front of the face at eye height, and the head top). Body S
    (working, cats.py) has B's chest, so it wears the sitting pieces at B's slots, and the hats on its own head's top
    as on A."""
    if body == "sit":
        return dict(SIT_SLOTS)
    if body == "work":
        h = cats.dims(spec, "work")["head"]
        hat = tuple(round(v * K, 4) for v in (0.0, h["c"][1] - 0.06, h["top"] - 0.01))
        return {**SIT_SLOTS, **{n: ("Head", hat, (0, 0, 0)) for n in ("BaristaCap", "Boater", "PartyHat")}}
    h = cats.dims(spec, "walk")["head"]
    return {"Glasses": ("Head", (0.0, round(h["fy"] - 0.05, 4), h["fz"]), (0, 0, 0)),
            "Hat": ("Head", (0.0, h["c"][1], round(h["top"], 4)), (0, 0, 0)),
            "LeafBeret": ("Head", (0.0, h["c"][1], round(h["top"], 4)), (0, 0, 0)),
            "AcornHairClip": ("Head", (0.0, h["c"][1], round(h["top"], 4)), (0, 0, 0)),
            "MushroomCap": ("Head", (0.0, h["c"][1], round(h["top"], 4)), (0, 0, 0)),
            "ReadingGlasses": ("Head", (0.0, round(h["fy"] - 0.05, 4), h["fz"]), (0, 0, 0)), **walk_slots(spec)}


# Role pieces on the walking body A (Animation-Engineer, 2026-11-02): the three hats, the bow tie and the cape fit A as
# built for B. The apron, waistcoat and sash wrap B's upright chest and would be buried in A's wider level body, so A
# wears its own versions of them, CatCafe_Accessory_<Piece>_Walk (WALK_MESHES): pieces that lie on the back, the part
# of a walking cat the camera sees, narrow enough for the slimmest back (the Sphynx's) so they never hang in the air.
# A cat with a Back prop has no walking slot for them, as it has none for the cape.
WALK_PIECES = ("BaristaCap", "Boater", "PartyHat", "BowTie", "Cape", "Vest", "Sash", "Apron")
WALK_MESHES = ("Vest", "Sash", "Apron")
BACK_W = 0.6                                  # the back pieces' width: the Sphynx's back is 0.64
BACK_TOP = 0.07                               # their base's top above the slot (the back's top, or the coat's extras)


def walk_slots(spec):
    """(part, offset, rotation) of each WALK_PIECES slot on one cat's walking model before its Scale. The hats sit on
    the head top as on B; the bow tie hangs under the chin from the Head, since A's chest is tucked under the head;
    the cape is turned 90 about X so it lies along the back from just behind the head instead of hanging down; the
    walking waistcoat, sash and apron start on the back's middle line just under the back of the head."""
    d = cats.dims(spec, "walk")
    h, (bc, bs), n = d["head"], d["body"], d["neck"]
    hat = (0.0, round(h["c"][1] - 0.06, 4), round(h["top"] - 0.01, 4))
    chin = (0.0, round(h["fy"] + 0.12, 4), round(h["c"][2] - h["s"][2] / 2 - 0.05, 4))
    head_back = n[1] + h["c"][1] + h["s"][1] / 2
    back = (0.0, round(head_back + 0.06, 4), round(bc[2] + bs[2] / 2 - 0.02, 4))
    lift = max(0.0, cats.back_rise(spec) - (BACK_TOP - 0.02))      # a mane or star specks: sit on them, not under
    on_back = (0.0, round(head_back - 0.04, 4), round(bc[2] + bs[2] / 2 + lift, 4))
    return {"BaristaCap": ("Head", hat, (0, 0, 0)), "Boater": ("Head", hat, (0, 0, 0)),
            "PartyHat": ("Head", hat, (0, 0, 0)), "BowTie": ("Head", chin, (0, 0, 0)),
            "Cape": ("Body", back, (90, 0, 0)), "TinyLantern": ("Body", on_back, (0, 0, 0)),
            **{p: ("Body", on_back, (0, 0, 0)) for p in WALK_MESHES}}

def _x(deg):
    return (math.radians(deg), "X")


def _y(deg):
    return (math.radians(deg), "Y")


class _Fit:
    """A Builder in B's unscaled space, around one piece's slot: draw at chest coordinates, get a mesh pivoted at
    the slot and scaled to the sitting model."""

    def __init__(self, piece):
        self.b = Builder()
        self.at = _SLOTS[piece][1]

    def _p(self, p):
        return tuple(p[i] - self.at[i] for i in range(3))

    def box(self, c, size, swatch, **kw):
        self.b.box(self._p(c), size, swatch, **kw)

    def cyl(self, c, r, h, swatch, **kw):
        self.b.cyl(self._p(c), r, h, swatch, **kw)

    def band(self, za, zb, swatch, pad=0.03):
        """A strap all round the chest between heights za and zb."""
        self.box((0, (Y0 + Y1) / 2, (za + zb) / 2), (2 * X1 + 2 * pad, Y1 - Y0 + 2 * pad, zb - za + 2 * pad), swatch,
                 bevel=False)

    def finalize(self, name, mat):
        ob = self.b.finalize(name, mat)
        scale_mesh(ob, K)
        return [ob]


def _scaled(objs, k):
    for ob in objs:
        scale_mesh(ob, k)
    return objs


def build_glasses(mat):
    b = Builder()
    for x in (-0.2, 0.2):
        b.box((x, 0, 0), (0.3, 0.05, 0.3), "fur_black", bevel=False)                  # rims
        b.box((x, -0.005, 0), (0.22, 0.03, 0.22), "glass", bevel=False)              # lenses
    b.box((0, 0, 0.02), (0.14, 0.05, 0.05), "fur_black", bevel=False)               # bridge
    for x in (-0.37, 0.37):
        b.box((x, 0.3, 0.05), (0.05, 0.7, 0.05), "fur_black", bevel=False)          # arms back along the head
    return [b.finalize("CatCafe_Accessory_Glasses", mat)]


def _bow_tie(name, mat):
    b = Builder()
    b.box((0, 0, 0), (0.14, 0.12, 0.14), "blush")                                  # knot
    b.box((-0.2, 0.02, 0), (0.3, 0.1, 0.26), "blush", rot=(math.radians(10), "Y"))
    b.box((0.2, 0.02, 0), (0.3, 0.1, 0.26), "blush", rot=(math.radians(-10), "Y"))
    return [b.finalize(name, mat)]


def build_bow_tie(mat):
    """Waiter's bow tie, under the chin of the sitting cat, in front of the waistcoat."""
    return _scaled(_bow_tie("CatCafe_Accessory_BowTie", mat), 0.9 * K)


def build_apron(mat):
    """Barista's apron: a mint bib down the chest with a cream pocket, tied round the waist with a bow at the back."""
    f = _Fit("Apron")
    fy, w = Y0 - 0.015, 2 * X1
    f.box((0, fy, MID), (w * 0.62, 0.04, NECK_Z - Z0 - 0.04), "mint")                          # bib
    f.box((0, fy - 0.02, Z0 + 0.16), (w * 0.34, 0.03, 0.16), "cream", bevel=False)              # pocket
    f.band(Z0 + 0.3, Z0 + 0.34, "mint")                                                          # tie
    bz, by = Z0 + 0.32, Y1 + 0.045                                                              # the bow at the back
    f.box((0, by, bz), (0.08, 0.05, 0.08), "mint", bevel=False)                                 # knot
    for sx in (-1, 1):
        f.box((sx * 0.11, by - 0.005, bz + 0.02), (0.15, 0.035, 0.1), "mint", bevel=False, rot=_y(sx * 18))   # loop
        f.box((sx * 0.105, by - 0.008, bz + 0.02), (0.07, 0.03, 0.05), "cream", bevel=False, rot=_y(sx * 18))
        f.box((sx * 0.17, by - 0.01, bz - 0.07), (0.06, 0.025, 0.11), "mint", bevel=False, rot=_y(sx * 35))  # tail
    return f.finalize("CatCafe_Accessory_Apron", mat)


def build_sash(mat):
    """Greeter's sash: red, from the shoulder across the chest and back, with a gold rosette."""
    f = _Fit("Sash")
    fy, w, length = Y0 - 0.015, 2 * X1, (NECK_Z - Z0) * 1.25
    f.box((0, fy - 0.01, MID), (0.17, 0.04, length), "shirt_red", bevel=False, rot=_y(-36))
    f.box((0, Y1 + 0.025, MID), (0.17, 0.04, length), "shirt_red", bevel=False, rot=_y(36))
    f.cyl((w * 0.26, fy - 0.05, NECK_Z - 0.12), 0.12, 0.05, "rarity_legend", segments=10, rot=_x(90))   # rosette
    f.cyl((w * 0.26, fy - 0.08, NECK_Z - 0.12), 0.06, 0.04, "shirt_red", segments=8, rot=_x(90))
    return f.finalize("CatCafe_Accessory_Sash", mat)


def build_party_hat(mat):
    """Entertainer's party hat: striped cone and a pom-pom."""
    b = Builder()
    rings = [(0.0, 0.2, 0.15, "neon_pink"), (0.15, 0.15, 0.1, "sign_teal"), (0.3, 0.1, 0.06, "neon_pink"),
             (0.45, 0.06, 0.02, "sign_teal")]
    for z, r1, r2, sw in rings:
        b.cyl_base((0, 0, z), r1, 0.15, sw, segments=10, radius2=r2, bevel=False)
    b.ico((0, 0, 0.64), 0.08, "sparkle", subdivisions=1)                                      # pom-pom
    return _scaled([b.finalize("CatCafe_Accessory_PartyHat", mat)], HAT_K * K)


def build_barista_cap(mat):
    """Barista's cap: a soft mint crown on a cream band, a short brim to the front and a coffee bean badge."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.24, 0.05, "cream", segments=12)                                    # band
    b.cyl_base((0, 0, 0.05), 0.24, 0.12, "mint", segments=12, radius2=0.2)                       # crown
    b.box((0, -0.3, 0.015), (0.4, 0.2, 0.03), "mint", bevel=False, rot=(math.radians(12), "X"))   # brim, tipped down
    b.box((0, -0.235, 0.105), (0.08, 0.03, 0.1), "dark_wood", bevel=False)                       # bean badge
    b.box((0, -0.252, 0.105), (0.015, 0.01, 0.08), "cream", bevel=False)                         # the bean's crease
    return _scaled([b.finalize("CatCafe_Accessory_BaristaCap", mat)], HAT_K * K)


def build_vest(mat):
    """Waiter's waistcoat: dark all round the chest, a white shirt V at the neck and three gold buttons. It stands a
    little off the chest so the chest patch and the tuxedo bib stay under it."""
    f = _Fit("Vest")
    pad = 0.045
    front = Y0 - pad
    f.band(Z0 + 0.04, NECK_Z, "dark_wood", pad=pad)
    f.box((0, front - 0.005, NECK_Z - 0.13), (2 * X1 * 0.3, 0.03, 0.26), "offwhite", bevel=False)     # shirt V
    for i in range(3):
        f.box((0, front - 0.012, NECK_Z - 0.32 - 0.12 * i), (0.06, 0.03, 0.06), "rarity_legend", bevel=False)
    back = Y1 + pad
    f.box((0, back + 0.005, (Z0 + NECK_Z) / 2 + 0.02), (2 * X1 * 0.78, 0.03, NECK_Z - Z0 - 0.16), "choco",
          bevel=False)                                                                               # satin back
    f.box((0, back + 0.02, Z0 + 0.27), (2 * X1 * 0.66, 0.03, 0.07), "dark_wood", bevel=False)           # cinch strap
    f.box((0, back + 0.034, Z0 + 0.27), (0.12, 0.02, 0.1), "rarity_legend", bevel=False)               # buckle
    f.box((0, back + 0.04, Z0 + 0.27), (0.06, 0.02, 0.05), "choco", bevel=False)
    return f.finalize("CatCafe_Accessory_Vest", mat)


def build_cape(mat):
    """Entertainer's stage cape: teal outside, pink lining and gold stars, hung from a pink collar at the back of the
    shoulders, with straps along the sides to two gold clasps at the front. It is split up the back from the hem, the
    lining turned back pink along the split, so a working cat's tail comes out through it (Derek 11-02: the cape
    looked odd from behind, a board with the tail poking through), with a gold hem, a twinkle on each panel
    and a big gold star above the split."""
    from mathutils import Matrix, Vector
    f = _Fit("Cape")
    w, fy = 2 * X1, Y0 - 0.015
    cw, tall = w + 0.36, NECK_Z - Z0 + 0.3
    C, R = Vector((0, Y1 + 0.06, MID - 0.08)), Matrix.Rotation(math.radians(-8), 3, "X")
    hx, hz = cw / 2, tall / 2
    s_top, sw = -hz + 0.5, 0.17                         # the split: up to here from the hem, this far either side

    def box(c, size, swatch, bevel=True, rot=None):     # in the cape's own frame (x across, y out the back, z up)
        f.box(tuple(C + R @ Vector(c)), size, swatch, bevel=bevel, rot=R if rot is None else R @ rot)

    def star(c, outer, inner, swatch="rarity_legend"):  # standing up, one point up, facing out the back
        f.b.star(f._p(tuple(C + R @ Vector(c))), outer, inner, 0.03, swatch, rot=R @ Matrix.Rotation(math.pi / 2, 3, "X"))

    top0 = s_top - 0.04                                 # the upper part runs down into the panels' tops
    box((0, 0, (top0 + hz) / 2), (cw, 0.05, hz - top0), "sign_teal")
    box((0, -0.03, (top0 + 0.01 + hz - 0.03) / 2), (cw - 0.06, 0.02, hz - 0.04 - top0), "neon_pink", bevel=False)
    for sx in (-1, 1):
        x0, x1 = sw, hx - 0.004
        box((sx * (x0 + x1) / 2, 0, (s_top - hz) / 2), (x1 - x0, 0.045, s_top + hz), "sign_teal", bevel=False)
        box((sx * (x0 + x1) / 2, -0.03, (top0 + 0.03 - hz + 0.03) / 2), (x1 - x0 - 0.06, 0.018, top0 + 0.03 + hz - 0.03),
            "neon_pink", bevel=False)
        box((sx * (x0 + 0.026), 0.018, (top0 - 0.005 - hz + 0.065) / 2), (0.068, 0.02, top0 - 0.005 + hz - 0.065),
            "neon_pink", bevel=False)                   # the lining turned back along the split
        box((sx * (x0 + x1) / 2, 0, -hz + 0.03), (x1 - x0 + 0.006, 0.06, 0.07), "rarity_legend", bevel=False)   # hem
        box((sx * 0.33, 0.02, -0.15), (0.09, 0.03, 0.09), "rarity_legend", bevel=False, rot=Matrix.Rotation(math.pi / 4, 3, "Y"))
    star((0, 0.024, 0.24), 0.13, 0.055)
    f.box((0, Y1 + 0.02, NECK_Z + 0.04), (cw, 0.16, 0.12), "neon_pink", bevel=False)              # collar
    for sx in (-1, 1):
        f.box((sx * (X1 + 0.015), (fy + Y1) / 2, NECK_Z - 0.04), (0.03, Y1 - fy, 0.08), "sign_teal", bevel=False)
        f.box((sx * w * 0.36, fy - 0.01, NECK_Z - 0.04), (0.12, 0.04, 0.12), "rarity_legend", bevel=False)  # clasps
    return f.finalize("CatCafe_Accessory_Cape", mat)


def build_boater(mat):
    """Greeter's straw boater: a wide flat brim and a flat-topped crown with a red band that matches the sash."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.4, 0.04, "treat_tan", segments=12, bevel=False)                    # brim
    b.cyl_base((0, 0, 0.04), 0.25, 0.05, "shirt_red", segments=12, bevel=False)                 # band
    b.cyl_base((0, 0, 0.09), 0.25, 0.09, "treat_tan", segments=12)                              # crown
    b.box((0.2, -0.13, 0.065), (0.08, 0.03, 0.08), "offwhite", bevel=False, rot=(math.radians(-30), "Z"))  # bow
    return _scaled([b.finalize("CatCafe_Accessory_Boater", mat)], HAT_K * K)


def build_hat(mat):
    """A small beret-style cap."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.1, "blush", segments=12)
    b.cyl_base((0, 0, 0.1), 0.3, 0.12, "blush", segments=12, radius2=0.2)
    b.sphere((0, 0, 0.26), 0.06, "dark_wood", segments=6, rings=4)
    return [b.finalize("CatCafe_Accessory_Hat", mat)]


def build_leaf_beret(mat):
    """#1637 the Cafe Pass Leaf Beret (cafe-pass.md section 3, level 5; Maple Muffin wears the same one as its prop):
    a small forest-green knitted beret tipped to the right, a ribbed band, a stalk and a red maple leaf pin. It sits
    on the Hat slot of the walking head (slots())."""
    b = Builder()
    for k in range(8):                                                                  # ribbed band
        a = 2 * math.pi * (k + 0.5) / 8
        b.box((0.345 * math.cos(a), 0.345 * math.sin(a), 0.035), (0.04, 0.04, 0.07), "leaf_dark", bevel=False,
              rot=(a, "Z"))
    b.cyl_base((0, 0, 0), 0.33, 0.07, "leaf_green", segments=12, bevel=False)
    b.cyl_base((0, 0, 0.07), 0.35, 0.09, "leaf_dark", segments=12, radius2=0.29, bevel=False)   # the knit crown
    b.cyl_base((0, 0, 0.16), 0.28, 0.05, "leaf_dark", segments=12, radius2=0.18, bevel=False)
    b.cyl_base((0, 0, 0.21), 0.03, 0.07, "leaf_dark", segments=6, bevel=False)                  # stalk
    leaf = Matrix.Translation((0.15, -0.3, 0.1)) @ Matrix.Rotation(math.radians(-70), 4, "X")
    r3 = leaf.to_3x3()
    b.star(tuple(leaf @ Vector((0, 0, 0))), 0.14, 0.065, 0.025, "fur_rust_red", rot=r3)       # maple leaf pin
    b.star(tuple(leaf @ Vector((0, 0.045, 0))), 0.085, 0.042, 0.025, "fur_rust_red", rot=r3)
    b.box(tuple(leaf @ Vector((0, -0.14, 0))), (0.02, 0.09, 0.022), "fur_russet", bevel=False, rot=r3)
    b.box(tuple(leaf @ Vector((0, 0, 0.022))), (0.03, 0.03, 0.03), "gold_mid", bevel=False, rot=r3)
    ob = b.finalize("CatCafe_Accessory_LeafBeret", mat)
    ob.data.transform(Matrix.Translation((0, 0, 0.07)) @ Matrix.Rotation(math.radians(-12), 4, "Y"))   # tipped,
    return [ob]                                                                         # its low side on the slot


# #1637 the Cafe Pass season 1 accessories (cafe-pass.md section 3): looks any cat can wear, on the walking head's
# Hat or Glasses slot or on the back (walk_slots). Each is one mesh built about its slot.
def build_acorn_hair_clip(mat):
    """Level 16: a little acorn and an oak leaf on a gold hair clip, sitting by the right ear (the slot is the head
    top's middle, so it is built off to the side)."""
    b = Builder()
    x, y = -0.24, -0.05                                                                 # by the right ear
    b.box((x + 0.02, y, 0.015), (0.2, 0.06, 0.03), "gold_mid", bevel=False)            # the clip
    b.sphere((x, y - 0.02, 0.13), 0.09, "caramel_wood", segments=10, rings=6, scale=(1, 1, 1.25))   # the nut
    b.ico((x, y - 0.02, 0.06), 0.03, "fur_brown")                                       # its tip
    b.cyl_base((x, y - 0.02, 0.17), 0.105, 0.07, "dark_wood", segments=10, radius2=0.08, bevel=False)   # the cup
    for k in range(6):                                                                  # its scales
        a = 2 * math.pi * k / 6
        b.box((x + 0.1 * math.cos(a), y - 0.02 + 0.1 * math.sin(a), 0.2), (0.03, 0.03, 0.03), "fur_brown",
              bevel=False)
    b.cyl_base((x, y - 0.02, 0.24), 0.012, 0.05, "dark_wood", segments=5, bevel=False)  # stalk
    leaf = Matrix.Translation((x + 0.13, y + 0.02, 0.06)) @ Matrix.Rotation(math.radians(-60), 4, "Y")
    b.ico(tuple(leaf @ Vector((0, 0, 0))), 0.09, "fur_rust_red", scale=(1.6, 0.25, 0.7))   # an oak leaf
    return [b.finalize("CatCafe_Accessory_AcornHairClip", mat)]


def build_mushroom_cap(mat):
    """Level 10: a small autumn toadstool cap, rust red in three steps with cream gills, white spots and a fallen
    leaf stuck to its side."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.34, 0.04, "cream", segments=12, bevel=False)                # gills
    b.cyl_base((0, 0, 0.04), 0.37, 0.08, "fur_rust_red", segments=12, radius2=0.32, bevel=False)
    b.cyl_base((0, 0, 0.12), 0.32, 0.08, "fur_rust_red", segments=12, radius2=0.22, bevel=False)
    b.cyl_base((0, 0, 0.2), 0.22, 0.06, "fur_rust_red", segments=12, radius2=0.0, bevel=False)
    for (az, rad, z, r) in ((-30, 0.35, 0.08, 0.05), (70, 0.35, 0.08, 0.045), (160, 0.35, 0.08, 0.05),
                            (250, 0.35, 0.08, 0.045), (20, 0.26, 0.16, 0.045), (200, 0.26, 0.16, 0.04),
                            (0, 0.0, 0.24, 0.05)):
        a = math.radians(az)
        b.box((rad * math.sin(a), -rad * math.cos(a), z), (r * 1.6, r * 1.6, r * 0.8), "offwhite", bevel=False,
              rot=(a, "Z"))
    b.ico((0.24, -0.2, 0.11), 0.07, "pastel_butter", scale=(1.4, 0.3, 0.8))            # a fallen leaf
    return [b.finalize("CatCafe_Accessory_MushroomCap", mat)]


def build_reading_glasses(mat):
    """Level 22: round tortoiseshell reading glasses with gold bridges, arms back along the head (the Glasses
    slot, like CatCafe_Accessory_Glasses)."""
    b = Builder()
    for x in (-0.2, 0.2):
        b.ring((x, 0, 0), 0.15, 0.035, 0.05, "caramel_wood", segments=12, bevel=False, rot=_x(90))   # rims
        b.cyl((x, 0.005, 0), 0.12, 0.02, "glass", segments=12, bevel=False, rot=_x(90))              # lenses
    b.box((0, 0, 0.03), (0.12, 0.04, 0.035), "gold_mid", bevel=False)                   # bridge
    for x in (-0.36, 0.36):
        b.box((x, 0.3, 0.03), (0.04, 0.62, 0.04), "caramel_wood", bevel=False)          # arms
        b.box((x, -0.01, 0.03), (0.07, 0.05, 0.055), "gold_mid", bevel=False)          # hinges
    return [b.finalize("CatCafe_Accessory_ReadingGlasses", mat)]


def build_tiny_lantern(mat):
    """Level 26: a tiny lantern standing on a little saddle pad on the back, a warm glow inside a black frame, a
    gold cap and a ring handle (on the back slot, like the walking pieces: +Y runs back along the spine)."""
    b = Builder()
    b.box((0, 0.12, 0.02), (0.36, 0.42, 0.04), "fur_rust_red", bevel=False)            # the saddle pad
    b.box((0, 0.12, 0.045), (0.28, 0.34, 0.02), "pastel_butter", bevel=False)
    b.box((0, 0.12, 0.08), (0.2, 0.2, 0.05), "fur_black", bevel=False)                  # lantern base
    b.box((0, 0.12, 0.2), (0.14, 0.14, 0.2), "lamp_warm", bevel=False)                  # the glow
    for dx in (-0.08, 0.08):                                                            # frame posts
        for dy in (-0.08, 0.08):
            b.box((dx, 0.12 + dy, 0.2), (0.025, 0.025, 0.22), "fur_black", bevel=False)
    b.pyramid((0, 0.12, 0.31), 0.22, 0.1, "gold_mid")                                   # cap
    b.ring((0, 0.12, 0.43), 0.05, 0.015, 0.02, "fur_black", segments=8, bevel=False, rot=_x(90))   # handle
    return [b.finalize("CatCafe_Accessory_TinyLantern", mat)]


# The walking versions (WALK_MESHES): built about the slot on the back's middle line just under the back of the head,
# +Y running back along the spine, each 0.03 into the back so the coat's stripes and specks stay under it.
def _back_panel(b, y0, y1, swatch, top=BACK_TOP, w=BACK_W):
    b.box((0, (y0 + y1) / 2, (top - 0.03) / 2), (w, y1 - y0, top + 0.03), swatch)


def build_vest_walk(mat):
    """The waiter's waistcoat on a walking cat: a dark back with a white shirt collar under the head, two gold
    buttons by the collar and a half belt with a gold buckle."""
    b = Builder()
    _back_panel(b, -0.02, 0.5, "dark_wood")
    b.box((0, 0.025, 0.04), (BACK_W - 0.08, 0.09, 0.08), "offwhite", bevel=False)               # shirt collar
    for sx in (-1, 1):
        b.box((sx * 0.1, 0.07, 0.085), (0.12, 0.08, 0.02), "offwhite", bevel=False,
              rot=(math.radians(sx * 25), "Z"))                                                    # collar points
        b.box((sx * 0.26, 0.17, 0.08), (0.05, 0.05, 0.03), "rarity_legend", bevel=False)          # buttons
    b.box((0, 0.36, 0.078), (0.4, 0.07, 0.02), "choco", bevel=False)                              # half belt
    b.box((0, 0.36, 0.088), (0.09, 0.08, 0.02), "rarity_legend", bevel=False)                     # buckle
    b.box((0, 0.36, 0.093), (0.045, 0.04, 0.012), "choco", bevel=False)
    return [b.finalize("CatCafe_Accessory_Vest_Walk", mat)]


def build_sash_walk(mat):
    """The greeter's sash on a walking cat: a red band across the back from the left shoulder to the right hip, with
    the gold rosette on the shoulder."""
    b = Builder()
    (x0, y0), (x1, y1) = (0.2, 0.04), (-0.2, 0.46)
    L, ang = math.hypot(x1 - x0, y1 - y0), math.atan2(y1 - y0, x1 - x0)
    b.box(((x0 + x1) / 2, (y0 + y1) / 2, 0.02), (L, 0.17, 0.1), "shirt_red", bevel=False, rot=(ang, "Z"))
    b.box(((x0 + x1) / 2, (y0 + y1) / 2, 0.072), (L - 0.04, 0.04, 0.012), "offwhite", bevel=False,
          rot=(ang, "Z"))                                                                          # a white stripe
    b.cyl_base((x0, y0 + 0.02, 0.04), 0.11, 0.05, "rarity_legend", segments=10)                 # rosette
    b.cyl_base((x0, y0 + 0.02, 0.09), 0.055, 0.03, "shirt_red", segments=8)
    for sx in (-1, 1):                                                                             # its two tails
        b.box((x0 + sx * 0.04, y0 + 0.15, 0.005), (0.05, 0.12, 0.07), "shirt_red", bevel=False,
              rot=(math.radians(sx * 15), "Z"))
    return [b.finalize("CatCafe_Accessory_Sash_Walk", mat)]


def build_apron_walk(mat):
    """The barista's apron on a walking cat: the mint neck strap behind the head and the waist tie across the back
    with a bow, the apron itself being under the cat."""
    b = Builder()
    b.box((0, 0.03, 0.02), (BACK_W, 0.07, 0.1), "mint", bevel=False)                              # neck strap
    b.box((0, 0.36, 0.02), (BACK_W, 0.08, 0.1), "mint", bevel=False)                              # waist tie
    for sx in (-1, 1):
        b.box((sx * 0.1, 0.36, 0.095), (0.16, 0.11, 0.05), "mint", rot=(math.radians(sx * 20), "Z"))  # bow loops
        b.box((sx * 0.05, 0.47, 0.005), (0.05, 0.14, 0.07), "mint", bevel=False,
              rot=(math.radians(sx * 18), "Z"))                                                    # tails
    b.box((0, 0.36, 0.105), (0.07, 0.08, 0.06), "cream", bevel=False)                             # knot
    return [b.finalize("CatCafe_Accessory_Apron_Walk", mat)]


ASSETS = {
    "CatCafe_Accessory_Glasses": (build_glasses, 200),
    "CatCafe_Accessory_BowTie": (build_bow_tie, 200),
    "CatCafe_Accessory_Apron": (build_apron, 200),
    "CatCafe_Accessory_Hat": (build_hat, 300),
    "CatCafe_Accessory_LeafBeret": (build_leaf_beret, 500),
    "CatCafe_Accessory_AcornHairClip": (build_acorn_hair_clip, 500),
    "CatCafe_Accessory_MushroomCap": (build_mushroom_cap, 500),
    "CatCafe_Accessory_ReadingGlasses": (build_reading_glasses, 500),
    "CatCafe_Accessory_TinyLantern": (build_tiny_lantern, 500),
    "CatCafe_Accessory_Sash": (build_sash, 300),
    "CatCafe_Accessory_PartyHat": (build_party_hat, 300),
    "CatCafe_Accessory_BaristaCap": (build_barista_cap, 300),
    "CatCafe_Accessory_Vest": (build_vest, 300),
    "CatCafe_Accessory_Boater": (build_boater, 300),
    "CatCafe_Accessory_Cape": (build_cape, 300),
    "CatCafe_Accessory_Vest_Walk": (build_vest_walk, 300),
    "CatCafe_Accessory_Sash_Walk": (build_sash_walk, 300),
    "CatCafe_Accessory_Apron_Walk": (build_apron_walk, 300),
}
