"""Wall perches (tier9-10-spots.md, #4066 and #4067): cafe work spots that use no floor. The room is full after
Tier 8, so the Tier 9 and Tier 10 spots sit on shelves 7 to 8 studs up the walls, over head height.

  CatCafe_Furniture_WallPerch_Greeter      a shelf with a red cushion, a brass bell on an arm (`_Bell`, pivot at
                                           its top) and a WELCOME board hanging under it: over the front door
  CatCafe_Furniture_WallPerch_Barista      a shelf with a teal cushion, a mug and a jar, and a MENU chalk board
                                           hanging under it: on the back wall over the counter
  CatCafe_Furniture_WallPerch_Entertainer  a shelf with a butter cushion, a toy on a string from an arm (`_Toy`,
                                           pivot at the string's top, for Effects to swing) and a PLAY board

Every model: pivot on the wall's face at the middle of the shelf's top, front -Z (the shelf runs 1.9 out from the
wall), so it is placed with its pivot on the wall and turned to face the room. Attachment `Seat` is where the cat
sits (the cushion's top). Nothing touches the floor. CanCollide is left to the game (the shelf is over head height).
"""

from mathutils import Matrix, Vector

from cannon import frame_at
from common import RB, text_width
from plot import rot_x, rot_z

N = "CatCafe_Furniture_WallPerch_"
ROLES = {
    "Greeter": dict(cushion="shirt_red", board="cream", ink="shirt_red", word="WELCOME"),
    "Barista": dict(cushion="sign_teal", board="fur_soot", ink="offwhite", word="MENU"),
    "Entertainer": dict(cushion="pastel_butter", board="pants_navy", ink="pastel_butter", word="PLAY"),
}
SHELF_W, SHELF_D, SEAT_Z, SEAT_Y = 1.5, 1.9, -0.95, 0.24      # half width, depth, the cushion's centre and top
ATTACHMENTS = {}        # asset -> [(name, Roblox point)]


def _shelf(b, look):
    b.span((-SHELF_W - 0.2, -2.3, -0.14), (SHELF_W + 0.2, 0.5, 0.0), "dark_wood")            # the wall plate
    b.span((-SHELF_W, -0.24, -SHELF_D), (SHELF_W, 0.0, -0.14), "caramel_wood")              # the board
    b.span((-SHELF_W - 0.06, -0.3, -SHELF_D - 0.08), (SHELF_W + 0.06, 0.1, -SHELF_D), "dark_wood")   # its front lip
    for sx in (-1, 1):
        x = sx * (SHELF_W - 0.35)
        b.span((x - 0.1, -1.9, -0.34), (x + 0.1, -0.24, -0.14), "dark_wood")                 # brackets
        b.box((x, -1.05, -0.95), (0.18, 0.18, 2.2), "dark_wood", rot=rot_x(-45))
        b.span((sx * SHELF_W - 0.03, 0.0, -SHELF_D), (sx * SHELF_W + 0.03, 0.28, -0.14), "dark_wood")   # side rails
    b.cyl((0, 0.07, SEAT_Z), 0.92, 0.14, look["cushion"], segments=12)                       # the cushion
    b.cyl((0, 0.19, SEAT_Z), 0.74, 0.1, "offwhite", segments=12)
    # the role board, hanging under the front lip on two chains
    px = 0.085 if len(look["word"]) > 5 else 0.11
    hw = max(text_width(look["word"], px) / 2 + 0.22, 0.8)
    z = -SHELF_D - 0.04
    for sx in (-1, 1):
        b.span((sx * (hw - 0.2) - 0.03, -0.72, z - 0.03), (sx * (hw - 0.2) + 0.03, -0.3, z + 0.03), "fur_soot")
    b.span((-hw, -1.5, z - 0.07), (hw, -0.72, z + 0.07), "dark_wood")
    b.span((-hw + 0.08, -1.42, z - 0.1), (hw - 0.08, -0.8, z - 0.07), look["board"])
    w = text_width(look["word"], px)
    b.text(look["word"], (w / 2, -1.11 - 2.5 * px, z - 0.1), px, 0.03, look["ink"], right=(-1, 0, 0))


def _arm(b, sx, y, out):
    """A little iron arm off the wall plate's side at height y, reaching `out` from the wall."""
    x = sx * (SHELF_W + 0.55)
    b.span((x - 0.05, y - 0.05, -out), (x + 0.05, y + 0.05, -0.14), "fur_soot")
    b.span((min(x, sx * SHELF_W), y - 0.4, -0.2), (max(x, sx * SHELF_W), y + 0.1, -0.14), "dark_wood")
    b.box((x, y - 0.22, -0.48), (0.07, 0.07, 0.62), "fur_soot", rot=rot_x(-45))
    return x


def build_perch(role):
    name, look = N + role, ROLES[role]

    def build(mat):
        b = RB()
        _shelf(b, look)
        parts = []
        if role == "Greeter":
            bell = RB()
            x = _arm(b, 1, 1.5, 1.3)
            bell.span((-0.02, -0.2, -0.02), (0.02, 0.0, 0.02), "fur_soot")
            bell.cyl((0, -0.42, 0), 0.3, 0.44, "brass", r2=0.14, segments=10)
            bell.cyl((0, -0.66, 0), 0.34, 0.06, "gold_dark", segments=10)
            bell.ball((0, -0.74, 0), 0.08, "gold_dark")
            parts.append(bell.finalize(name + "_Bell", mat, location=(x, 1.45, -1.2)))
            b.box((-0.95, 0.42, -0.4), (0.5, 0.5, 0.08), "shirt_red", rot=rot_z(45))          # a little heart flag
            b.span((-0.98, 0.0, -0.42), (-0.92, 0.42, -0.38), "dark_wood")
        elif role == "Barista":
            b.cyl((1.0, 0.22, -0.5), 0.2, 0.44, "milk", segments=10)                          # a mug
            b.span((1.18, 0.12, -0.54), (1.3, 0.34, -0.46), "milk")
            b.cyl((1.0, 0.45, -0.5), 0.16, 0.02, "choco", segments=10)
            b.cyl((-1.05, 0.3, -0.45), 0.24, 0.6, "pastel_sky", segments=10)                  # a jar of beans
            b.cyl((-1.05, 0.63, -0.45), 0.26, 0.08, "caramel_wood", segments=10)
            b.span((-0.9, 0.9, -0.2), (0.9, 2.1, -0.14), "dark_wood")                         # the chalk board on the wall
            b.span((-0.8, 1.0, -0.23), (0.8, 2.0, -0.2), "fur_soot")
            for k, (wd, sw) in enumerate(((1.1, "offwhite"), (0.8, "pastel_butter"), (1.0, "offwhite"))):
                b.span((-0.6, 1.75 - 0.28 * k, -0.25), (-0.6 + wd, 1.81 - 0.28 * k, -0.23), sw)
        else:
            toy = RB()
            x = _arm(b, -1, 1.7, 1.5)
            toy.span((-0.015, -1.0, -0.015), (0.015, 0.0, 0.015), "offwhite")                  # the string
            toy.ball((0, -1.12, 0), 0.2, "shirt_red")
            toy.box((0.0, -1.42, 0.0), (0.12, 0.5, 0.03), "sign_teal", rot=rot_z(18))          # two feathers
            toy.box((0.0, -1.42, 0.0), (0.12, 0.5, 0.03), "pastel_butter", rot=rot_z(-18))
            parts.append(toy.finalize(name + "_Toy", mat, location=(x, 1.65, -1.4)))
            b.ball((1.0, 0.2, -0.45), 0.2, "sign_teal")                                       # a ball of yarn
            b.cyl((1.0, 0.2, -0.45), 0.205, 0.06, "offwhite", segments=10)
        ATTACHMENTS[name] = [("Seat", (0.0, SEAT_Y, SEAT_Z))]
        return [b.finalize(name, mat)] + parts
    return build


def rbx_attachments(name):
    return [(name, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACHMENTS.get(name, [])]


ASSETS = {N + role: (build_perch(role), 1200) for role in ROLES}
