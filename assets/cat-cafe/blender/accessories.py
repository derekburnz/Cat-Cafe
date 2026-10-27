"""Cat accessories: small meshes that weld to a cat part at a named attachment point.

Each accessory's pivot is its attachment point, so in Studio: Motor6D or WeldConstraint
to the part named in ATTACH, with the accessory's pivot at that part-local offset.
The same offsets hold for an upright variant because they live on the Head and Body.
"""

import math

from common import Builder

# attachment name -> (cat part, offset local to that part's pivot, in studs, Blender axes)
# Quadruped (default) slots. Glasses and Hat ride the Head, so they are the same in every pose.
ATTACH = {
    "Glasses": ("Head", (0.0, -0.57, 0.2)),   # just in front of the face, eye height
    "Hat":     ("Head", (0.0, -0.18, 0.5)),   # head top center
    "BowTie":  ("Body", (0.0, -0.72, 0.95)),  # under the chin
    "Apron":   ("Body", (0.0, -0.70, 1.0)),   # chest, hangs down the front
}


# Upright slots: when a cat stands (poses.POSES["upright"]) its belly faces forward, so the
# Body accessories move to the belly and turn +90 degrees about X (part-local) to stay upright.
# (part, offset, rotation_xyz_deg). Head slots are unchanged.
ATTACH_UPRIGHT = {
    "BowTie":     ("Body", (0.0, -0.72, 0.22), (90, 0, 0)),   # at the throat, above the raised paws
    "Apron":      ("Body", (0.0, -0.45, 0.38), (90, 0, 0)),
    "Sash":       ("Body", (0.0, -0.32, 0.40), (90, 0, 0)),   # shoulder to hip across the chest
    "Vest":       ("Body", (0.0, -0.40, 0.40), (90, 0, 0)),   # chest and flanks; the paws come out through it
    "Cape":       ("Body", (0.0, -0.40, 0.40), (90, 0, 0)),   # hangs down the back from the shoulders
    "PartyHat":   ("Head", (0.0, -0.12, 0.5), (0, 0, 0)),     # between the ears, same in every pose
    "BaristaCap": ("Head", (0.0, -0.16, 0.48), (0, 0, 0)),    # head top, brim to the front
    "Boater":     ("Head", (0.0, -0.16, 0.48), (0, 0, 0)),
}

# Roles (data-model section 5): each working cat stands upright in its role's outfit, two pieces welded at the
# slots above. Cats wear no collar (Derek, 2026-10-27), so the outfit is what marks a cat as staff.
ROLE_OUTFITS = {"barista": ("Apron", "BaristaCap"), "waiter": ("BowTie", "Vest"), "greeter": ("Sash", "Boater"),
                "entertainer": ("PartyHat", "Cape")}


def face_shift(spec):
    """Per-cat nudge for slots that sit on the face, so one accessory set fits every cat."""
    return 0.12 if spec.get("persian") else 0.0     # the Persian's flat face sits 0.12 further back


def attach_for(spec, upright=False):
    """(part, offset, rotation) per accessory for one cat, before the cat's scale."""
    out = {}
    for n, (part, off) in ATTACH.items():
        out[n] = (part, off, (0, 0, 0))
    if upright:
        out.update(ATTACH_UPRIGHT)
    dy = face_shift(spec)
    if dy and "Glasses" in out:
        part, off, rot = out["Glasses"]
        out["Glasses"] = (part, (off[0], off[1] + dy, off[2]), rot)
    return out


def build_glasses(mat):
    b = Builder()
    for x in (-0.2, 0.2):
        b.box((x, 0, 0), (0.3, 0.05, 0.3), "fur_black", bevel=False)                  # rims
        b.box((x, -0.005, 0), (0.22, 0.03, 0.22), "glass", bevel=False)              # lenses
    b.box((0, 0, 0.02), (0.14, 0.05, 0.05), "fur_black", bevel=False)               # bridge
    for x in (-0.37, 0.37):
        b.box((x, 0.3, 0.05), (0.05, 0.7, 0.05), "fur_black", bevel=False)          # arms back along the head
    return [b.finalize("CatCafe_Accessory_Glasses", mat)]


def build_bow_tie(mat):
    b = Builder()
    b.box((0, 0, 0), (0.14, 0.12, 0.14), "blush")                                  # knot
    b.box((-0.2, 0.02, 0), (0.3, 0.1, 0.26), "blush", rot=(math.radians(10), "Y"))
    b.box((0.2, 0.02, 0), (0.3, 0.1, 0.26), "blush", rot=(math.radians(-10), "Y"))
    return [b.finalize("CatCafe_Accessory_BowTie", mat)]


def build_apron(mat):
    b = Builder()
    b.box((0, 0, -0.32), (0.6, 0.06, 0.6), "mint")                                 # bib down the chest
    b.box((0, 0.0, 0.0), (0.7, 0.05, 0.08), "dark_wood", bevel=False)              # neck strap front
    b.box((0, -0.02, -0.45), (0.3, 0.03, 0.2), "cream", bevel=False)               # pocket
    return [b.finalize("CatCafe_Accessory_Apron", mat)]


def build_sash(mat):
    """Greeter sash, built standing (Z up, front -Y): shoulder to hip with a gold rosette."""
    b = Builder()
    a = math.radians(-38)
    tilt = (a, "Y")
    b.box((0, 0, 0), (0.24, 0.05, 1.25), "shirt_red", bevel=False, rot=tilt)                  # band
    for dx in (-0.13, 0.13):                                                                  # gold edges
        b.box((dx * math.cos(a), -0.005, -dx * math.sin(a)), (0.03, 0.05, 1.2), "rarity_legend", bevel=False, rot=tilt)
    b.cyl((0.18, -0.05, 0.24), 0.14, 0.05, "rarity_legend", segments=10, rot=(math.radians(90), "X"))   # rosette
    b.cyl((0.18, -0.08, 0.24), 0.07, 0.04, "shirt_red", segments=8, rot=(math.radians(90), "X"))
    return [b.finalize("CatCafe_Accessory_Sash", mat)]


def build_party_hat(mat):
    """Entertainer's party hat: striped cone and a pom-pom."""
    b = Builder()
    rings = [(0.0, 0.2, 0.15, "neon_pink"), (0.15, 0.15, 0.1, "sign_teal"), (0.3, 0.1, 0.06, "neon_pink"),
             (0.45, 0.06, 0.02, "sign_teal")]
    for z, r1, r2, sw in rings:
        b.cyl_base((0, 0, z), r1, 0.15, sw, segments=10, radius2=r2, bevel=False)
    b.ico((0, 0, 0.64), 0.08, "sparkle", subdivisions=1)                                      # pom-pom
    return [b.finalize("CatCafe_Accessory_PartyHat", mat)]


def build_barista_cap(mat):
    """Barista's cap: a soft mint crown on a cream band, a short brim to the front and a coffee bean badge."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.24, 0.05, "cream", segments=12)                                    # band
    b.cyl_base((0, 0, 0.05), 0.24, 0.12, "mint", segments=12, radius2=0.2)                       # crown
    b.box((0, -0.3, 0.015), (0.4, 0.2, 0.03), "mint", bevel=False, rot=(math.radians(12), "X"))   # brim, tipped down
    b.box((0, -0.235, 0.105), (0.08, 0.03, 0.1), "dark_wood", bevel=False)                       # bean badge
    b.box((0, -0.252, 0.105), (0.015, 0.01, 0.08), "cream", bevel=False)                         # the bean's crease
    return [b.finalize("CatCafe_Accessory_BaristaCap", mat)]


def build_vest(mat):
    """Waiter's waistcoat, built standing (Z up, front -Y) like the sash: dark front panels with a stepped V of
    white shirt between them, gold buttons, sides and a back. Roomy, so one size fits the big cats."""
    b = Builder()
    w, top, mid, bot = 0.52, 0.2, -0.14, -0.6          # half width; top of the V, where it closes, the hem (z)
    b.box((0, 0, (mid + bot) / 2), (2 * w, 0.05, mid - bot), "dark_wood")                     # lower front
    for sx in (-1, 1):
        b.box((sx * (w + 0.09) / 2, 0, (mid + 0.04) / 2), (w - 0.09, 0.05, 0.04 - mid), "dark_wood")   # V, lower step
        b.box((sx * (w + 0.2) / 2, 0, (0.04 + top) / 2), (w - 0.2, 0.05, top - 0.04), "dark_wood")     # V, upper step
        b.box((sx * (w - 0.025), 0.4, (top + bot) / 2 - 0.03), (0.05, 0.8, top - bot - 0.06), "dark_wood")  # side
    b.box((0, 0.8, (top + bot) / 2 - 0.03), (2 * w, 0.05, top - bot - 0.06), "dark_wood")               # back
    b.box((0, 0.01, (mid + top) / 2 + 0.02), (0.4, 0.03, top - mid + 0.04), "offwhite", bevel=False)  # shirt
    for z in (-0.22, -0.36, -0.5):
        b.box((0, -0.035, z), (0.06, 0.03, 0.06), "rarity_legend", bevel=False)                   # buttons
    return [b.finalize("CatCafe_Accessory_Vest", mat)]


def build_cape(mat):
    """Entertainer's stage cape, built standing (Z up, front -Y): teal outside, pink lining and gold stars, hung
    behind the back of the roomiest cat from two straps over the shoulders, flaring out at the hem."""
    b = Builder()
    y0, flare = 0.92, (math.radians(8), "X")
    b.box((0, y0, -0.3), (0.96, 0.05, 1.0), "sign_teal", rot=flare)                             # cape
    b.box((0, y0 - 0.03, -0.3), (0.9, 0.02, 0.94), "neon_pink", bevel=False, rot=flare)         # lining
    for (x, z) in ((-0.25, -0.05), (0.2, -0.3), (-0.1, -0.6), (0.3, -0.65)):                      # stars, outside
        b.box((x, y0 + 0.03 - z * math.sin(flare[0]), z - 0.0), (0.09, 0.03, 0.09), "rarity_legend", bevel=False,
              rot=(math.radians(45), "Y"))
    for sx in (-1, 1):
        b.box((sx * 0.33, y0 / 2, 0.22), (0.1, y0, 0.05), "sign_teal", bevel=False)              # shoulder straps
        b.box((sx * 0.33, -0.03, 0.22), (0.12, 0.04, 0.12), "rarity_legend", bevel=False)        # gold clasps
    return [b.finalize("CatCafe_Accessory_Cape", mat)]


def build_boater(mat):
    """Greeter's straw boater: a wide flat brim and a flat-topped crown with a red band that matches the sash."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.4, 0.04, "treat_tan", segments=12, bevel=False)                    # brim
    b.cyl_base((0, 0, 0.04), 0.25, 0.05, "shirt_red", segments=12, bevel=False)                 # band
    b.cyl_base((0, 0, 0.09), 0.25, 0.09, "treat_tan", segments=12)                              # crown
    b.box((0.2, -0.13, 0.065), (0.08, 0.03, 0.08), "offwhite", bevel=False, rot=(math.radians(-30), "Z"))  # bow
    return [b.finalize("CatCafe_Accessory_Boater", mat)]


def build_hat(mat):
    """A small beret-style cap."""
    b = Builder()
    b.cyl_base((0, 0, 0), 0.36, 0.1, "blush", segments=12)
    b.cyl_base((0, 0, 0.1), 0.3, 0.12, "blush", segments=12, radius2=0.2)
    b.sphere((0, 0, 0.26), 0.06, "dark_wood", segments=6, rings=4)
    return [b.finalize("CatCafe_Accessory_Hat", mat)]


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
}
