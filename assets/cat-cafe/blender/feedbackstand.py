"""The Town Square's feedback stand (#3066, Derek2 11-10: "make a feedback stand with a mailbox and maybe postie cat
there in the town square for people to leave feedback"): a red pillar post box with a FEEDBACK plate under its slot
and a letter going in, on a little paved plinth, a teal board on two posts behind it reading FEEDBACK over
"Tell us!", and the Postie Cat (cats.ROSTER Postie at 1.5 times, its mail cap and letter) sitting on a stack of
parcels beside the box.

  CatCafe_Town_FeedbackStand            plinth, post box, board and parcels (collides); Attachments PromptAnchor (the
                                        box's front, 1.5 up: the feedback prompt), BangAnchor (2 over the board) and
                                        CatSeat (the cat's pivot on the parcels, facing -Z)
  CatCafe_Town_FeedbackStand_Cat_<Piece> the Postie Cat, the same hinged pieces as every sitting cat (Head with its
                                        eyes and ears, Tail, LegF1, LegF2); its cap _Cat_Prop and letter _Cat_Prop2
                                        ride inside the Head Model

Pivot at the base centre, the box's slot and the board's words (-Z) toward the players. The plinth is 6.4 x 3.6; the
board's top is 6.2 up.
"""

from mathutils import Matrix, Vector

import cats
from alleyway import label
from cannon import frame_at
from common import RB

NAME = "CatCafe_Town_FeedbackStand"
PLINTH_W, PLINTH_D, PLINTH_H = 6.4, 3.6, 0.3
BOX_X, BOX_R, BOX_H = -1.5, 0.8, 3.4               # the pillar box: its centre x, radius, body height over the plinth
PARCEL_X = 1.55                                    # the parcel stack's centre x
SEAT_Y = PLINTH_H + 0.95 + 0.8                     # the top parcel's top: the cat's pivot
CAT_SCALE = 1.5
BOARD_Z, BOARD_Y0, BOARD_Y1 = 1.2, 4.6, 6.2        # the board: its face's z, bottom and top
CAT = dict(cats.ROSTER["Postie"], scale=CAT_SCALE)
RED, DARK, CREAM, TEAL = "shirt_red", "fur_black", "cream", "sign_teal"


def _plinth(b):
    b.span((-PLINTH_W / 2, 0, -PLINTH_D / 2), (PLINTH_W / 2, PLINTH_H, PLINTH_D / 2), "paving_light")
    b.span((-PLINTH_W / 2 - 0.1, 0, -PLINTH_D / 2 - 0.1), (PLINTH_W / 2 + 0.1, 0.12, PLINTH_D / 2 + 0.1), "concrete")


def _post_box(b):
    """A red pillar box: a black foot, the body, a rim, a domed cap, the slot with a letter going in and a cream
    FEEDBACK plate under it."""
    y0 = PLINTH_H
    b.cyl((BOX_X, y0 + 0.15, 0), BOX_R + 0.1, 0.3, DARK, segments=16)
    b.cyl((BOX_X, y0 + 0.3 + (BOX_H - 0.3) / 2, 0), BOX_R, BOX_H - 0.3, RED, segments=16)
    b.cyl((BOX_X, y0 + BOX_H + 0.08, 0), BOX_R + 0.1, 0.16, RED, segments=16)                     # the rim
    b.ball((BOX_X, y0 + BOX_H + 0.16, 0), BOX_R + 0.05, RED, scale=(1, 0.55, 1))                 # the cap
    b.ball((BOX_X, y0 + BOX_H + 0.62, 0), 0.14, "rarity_legend")                                 # its knob
    zf = -BOX_R * 0.98
    slot_y = y0 + BOX_H - 0.6
    b.span((BOX_X - 0.45, slot_y, zf - 0.06), (BOX_X + 0.45, slot_y + 0.16, zf + 0.05), DARK)    # the slot
    b.span((BOX_X - 0.52, slot_y + 0.16, zf - 0.12), (BOX_X + 0.52, slot_y + 0.24, zf + 0.05), RED)   # its hood
    b.span((BOX_X - 0.2, slot_y + 0.05, zf - 0.22), (BOX_X + 0.22, slot_y + 0.1, zf + 0.05), "offwhite")   # a letter in
    py = y0 + 1.45
    b.span((BOX_X - 0.58, py, zf - 0.04), (BOX_X + 0.58, py + 0.5, zf + 0.4), CREAM)              # the plate
    label(b, "FEEDBACK", BOX_X, py + 0.17, zf - 0.04, 0.033, 0.02, RED, -1)
    return (BOX_X, 1.5, zf - 0.6)


def _board(b):
    """A teal board on two dark posts behind the stand, FEEDBACK over "Tell us!" in cream, a cream frame."""
    for x in (-2.2, 2.2):
        b.span((x - 0.12, PLINTH_H, BOARD_Z), (x + 0.12, BOARD_Y1 + 0.2, BOARD_Z + 0.24), "dark_wood")
    b.span((-2.5, BOARD_Y0, BOARD_Z - 0.1), (2.5, BOARD_Y1, BOARD_Z + 0.1), CREAM)               # the frame
    b.span((-2.35, BOARD_Y0 + 0.12, BOARD_Z - 0.14), (2.35, BOARD_Y1 - 0.12, BOARD_Z), TEAL)
    label(b, "FEEDBACK", 0.0, BOARD_Y0 + 0.72, BOARD_Z - 0.14, 0.13, 0.05, CREAM, -1)
    label(b, "TELL US!", 0.0, BOARD_Y0 + 0.24, BOARD_Z - 0.14, 0.07, 0.05, "rarity_legend", -1)
    return (0.0, BOARD_Y1, BOARD_Z)


def _parcels(b):
    """Two brown parcels tied with string, the cat's seat on top, and a small one at their foot."""
    y = PLINTH_H
    for (w, h, d, sw) in ((1.5, 0.95, 1.3, "cardboard"), (1.2, 0.8, 1.1, "kibble")):
        b.span((PARCEL_X - w / 2, y, -d / 2), (PARCEL_X + w / 2, y + h, d / 2), sw)
        b.span((PARCEL_X - 0.05, y - 0.01, -d / 2 - 0.02), (PARCEL_X + 0.05, y + h + 0.02, d / 2 + 0.02), "offwhite")
        b.span((PARCEL_X - w / 2 - 0.02, y - 0.01, -0.05), (PARCEL_X + w / 2 + 0.02, y + h + 0.02, 0.05), "offwhite")
        y += h
    b.span((PARCEL_X + 0.2, PLINTH_H, -1.6), (PARCEL_X + 0.9, PLINTH_H + 0.45, -1.05), "cardboard")


def build_feedback_stand(mat):
    b = RB()
    _plinth(b)
    prompt = _post_box(b)
    top = _board(b)
    _parcels(b)
    out = [b.finalize(NAME, mat)]
    cat = cats.build_cat("Postie", mat, spec=CAT, base=NAME + "_Cat", body="sit")
    for ob in cat:
        ob.location = ob.location + Vector(RB.p(PARCEL_X, SEAT_Y, 0))
    ATTACH[:] = [("PromptAnchor", prompt), ("BangAnchor", (top[0], top[1] + 2.0, top[2])),
                 ("CatSeat", (PARCEL_X, SEAT_Y, 0.0))]
    return out + cat


ATTACH = []


def attachments():
    """(object suffix, Attachment name, Blender 4x4) for rbx_export."""
    return [(NAME, n, frame_at(Vector(p), Matrix.Identity(3))) for n, p in ATTACH]


# the cat's cap and letter ride inside its Head Model (as on the Bellhop's stand)
NEST = {"_Cat_Prop": "_Cat_Head", "_Cat_Prop2": "_Cat_Head"}
FOLLOWS = {"_Cat_Prop": {"Follows": "Head"}, "_Cat_Prop2": {"Follows": "Head"}}

ASSETS = {
    NAME: (build_feedback_stand, 9000),
}
