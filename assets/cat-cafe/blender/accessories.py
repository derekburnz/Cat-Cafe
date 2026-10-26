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
    "BowTie":  ("Body", (0.0, -0.72, 0.95)),  # front of the collar
    "Apron":   ("Body", (0.0, -0.70, 1.0)),   # chest, hangs down the front
}


# Upright slots: when a cat stands (poses.POSES["upright"]) its belly faces forward, so the
# Body accessories move to the belly and turn +90 degrees about X (part-local) to stay upright.
# (part, offset, rotation_xyz_deg). Head slots are unchanged.
ATTACH_UPRIGHT = {
    "BowTie":   ("Body", (0.0, -0.72, 0.22), (90, 0, 0)),   # on the collar, above the raised paws
    "Apron":    ("Body", (0.0, -0.45, 0.38), (90, 0, 0)),
    "Sash":     ("Body", (0.0, -0.32, 0.40), (90, 0, 0)),   # shoulder to hip across the chest
    "PartyHat": ("Head", (0.0, -0.12, 0.5), (0, 0, 0)),     # between the ears, same in every pose
}

# v0.3 roles (data-model section 5): each working cat stands upright in its role's uniform.
ROLE_UNIFORMS = {"barista": "Apron", "waiter": "BowTie", "greeter": "Sash", "entertainer": "PartyHat"}


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
}
