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
    body, Glasses and Hat on the walking one (just in front of the face at eye height, and the head top)."""
    if body == "sit":
        return dict(SIT_SLOTS)
    h = cats.dims(spec, "walk")["head"]
    return {"Glasses": ("Head", (0.0, round(h["fy"] - 0.05, 4), h["fz"]), (0, 0, 0)),
            "Hat": ("Head", (0.0, h["c"][1], round(h["top"], 4)), (0, 0, 0)), **walk_slots(spec)}


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
            "Cape": ("Body", back, (90, 0, 0)), **{p: ("Body", on_back, (0, 0, 0)) for p in WALK_MESHES}}

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
    f.box((0, Y1 + 0.04, Z0 + 0.32), (0.22, 0.04, 0.1), "mint", bevel=False)                    # bow at the back
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
    return f.finalize("CatCafe_Accessory_Vest", mat)


def build_cape(mat):
    """Entertainer's stage cape: teal outside, pink lining and gold stars, hung from a pink collar at the back of the
    shoulders, with straps along the sides to two gold clasps at the front."""
    f = _Fit("Cape")
    w, fy = 2 * X1, Y0 - 0.015
    cw, tall = w + 0.36, NECK_Z - Z0 + 0.3
    f.box((0, Y1 + 0.06, MID - 0.08), (cw, 0.05, tall), "sign_teal", rot=_x(-8))
    f.box((0, Y1 + 0.03, MID - 0.08), (cw - 0.06, 0.02, tall - 0.06), "neon_pink", bevel=False, rot=_x(-8))
    f.box((0, Y1 + 0.02, NECK_Z + 0.04), (cw, 0.16, 0.12), "neon_pink", bevel=False)              # collar
    for sx in (-1, 1):
        f.box((sx * (X1 + 0.015), (fy + Y1) / 2, NECK_Z - 0.04), (0.03, Y1 - fy, 0.08), "sign_teal", bevel=False)
        f.box((sx * w * 0.36, fy - 0.01, NECK_Z - 0.04), (0.12, 0.04, 0.12), "rarity_legend", bevel=False)  # clasps
    for (x, z) in ((-0.2, 0.15), (0.18, -0.05), (0.0, -0.3)):
        f.box((x, Y1 + 0.095, MID + z), (0.09, 0.03, 0.09), "rarity_legend", bevel=False, rot=_y(45))
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
