"""Cafe customers (F15, F37): cosy townsfolk instead of blocky stand-ins, each with a face, hair and an outfit of
its own, and a seated twin for the chairs.

  CatCafe_NPC_Customer_<V>        standing, the pivot at the feet, front -Z (Blender -Y). Everyday looks A to F
                                  (CustomerController picks among them) and Rich (F31, top hat and cane):
                                  A  bob, mint cardigan, butter skirt, a takeaway cup
                                  B  a kid in a cap and red tee with a backpack (4 studs tall)
                                  C  an elder with a silver bun, glasses, lilac cardigan and a cane
                                  D  ginger curls and beard, striped sky sweater, a terracotta tote
                                  E  puffs, blush hoodie and headphones
                                  F  teal beanie, denim overalls, a scarf and a book
                                  Rich  top hat, monocle, moustache, tails, gold bow tie and cane
  CatCafe_NPC_Customer_<V>_Sit    the same customer sitting: the pivot is the floor under the middle of a cafe chair
                                  (CatCafe_Furniture_Chair's own pivot), front -Z toward the table, the seat of the
                                  trousers on the cushion (1.58 up), knees under the table's edge and forearms on
                                  its top (a cafe chair stands 2.4 from its table's middle); no cane, cup, tote or
                                  backpack. The kid's feet dangle.

One object each, nothing collides (the client moves them with PivotTo). Adults are 5 studs to the top of the head,
the kid 4.1, so the coin text 5.5 above the pivot clears every hat but the Rich customer's top hat.
"""

import math

from mathutils import Matrix

from common import Builder

SEAT = 1.58                 # the chair cushion's top (furniture.build_chair)
REST = 2.62                 # seated forearms, just over the round table's top (2.6)
FACE_INK = "fur_black"

ADULT = dict(leg=1.45, pelvis=0.35, torso=1.5, tw=1.4, td=0.8, arm=1.3, hw=1.5, hd=1.35, hh=1.45, thigh=1.2)
KID = dict(leg=0.95, pelvis=0.3, torso=1.15, tw=1.22, td=0.72, arm=0.98, hw=1.44, hd=1.3, hh=1.4, thigh=0.9)

LOOKS = {
    "A": dict(body=ADULT, skin="skin_light", hair="choco", style="bob", top="offwhite", cardigan="mint",
              skirt="pastel_butter", legs="fur_ink", shoes="caramel_wood", cup=True, brows=True),
    "B": dict(body=KID, skin="skin_tan", hair="choco", style="cap", cap="mint", top="shirt_red", star="pastel_butter",
              shorts="pants_navy", legs="skin_tan", shoes="offwhite", backpack="pastel_butter"),
    "C": dict(body=ADULT, skin="skin_deep", hair="fur_silver", style="bun", top="offwhite", cardigan="pastel_lilac",
              pants="galaxy_blue", shoes="dark_wood", glasses="brass", cane="dark_wood", brows=True),
    "D": dict(body=ADULT, skin="skin_light", hair="fur_russet", style="curls", beard=True, top="pastel_sky",
              stripes="offwhite", pants="fur_puddle", shoes="choco", tote="terracotta", brows=True),
    "E": dict(body=ADULT, skin="skin_deep", hair="choco", style="puffs", top="blush", hood=True, pants="fur_ink",
              shoes="offwhite", phones="mint"),
    "F": dict(body=ADULT, skin="skin_tan", hair="hair_brown", style="beanie", beanie="sign_teal", top="pastel_butter",
              overalls="fur_puddle", scarf="fur_strawberry", shoes="dark_wood", book="galaxy_blue", brows=True),
    "Rich": dict(body=ADULT, skin="skin_light", hair="hair_brown", style="short", top="fur_black", suit=True,
                 pants="fur_black", shoes="fur_black", moustache=True, monocle=True, top_hat=True, cane="fur_black",
                 knob="rarity_legend", brows=True),
}
EVERYDAY = ("A", "B", "C", "D", "E", "F")


def _ry(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def _rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


class Frame:
    """The body's key heights for one look, standing or sitting."""

    def __init__(self, body, sit):
        self.d = body
        self.sit = sit
        stand_hip = 0.3 + body["leg"] - 0.2                      # the pelvis's bottom when standing
        self.hip = SEAT if sit else stand_hip
        self.lift = self.hip - stand_hip
        self.back = 0.12 if sit else 0.0                          # sitting, the upper body leans to the chair back
        self.waist = self.hip + body["pelvis"]
        self.top = self.waist - 0.05 + body["torso"]              # the shoulders
        self.head0 = self.top + 0.1
        self.head1 = self.head0 + body["hh"]
        self.face = self.back - body["hd"] / 2                    # the face's plane (Blender -Y is the front)


def _legs(b, f, look):
    d = f.d
    legs, shoes = look.get("legs") or look.get("pants") or look.get("overalls"), look["shoes"]
    toe = "offwhite" if shoes != "offwhite" else "fur_grey"
    under = look.get("shorts") or look.get("pants") or look.get("overalls")
    for sx in (1, -1):
        x = sx * 0.32
        if not f.sit:
            b.box_base((x, 0.0, 0.25), (0.56, 0.6, f.hip + 0.1 - 0.25), legs)
            if look.get("shorts"):
                b.box_base((x, 0.0, 0.3 + d["leg"] * 0.55), (0.6, 0.64, d["leg"] * 0.45 - 0.15), under)
            b.box_base((x, -0.12, 0.0), (0.62, 0.9, 0.3), shoes)
            b.box((x, -0.58, 0.18), (0.5, 0.04, 0.12), toe, bevel=False)              # a toe cap
        else:
            thigh = d["thigh"]
            y0, y1 = f.back + 0.3, f.back + 0.3 - thigh                            # back of the seat to the knee
            b.box(((x, (y0 + y1) / 2, f.hip + 0.25)), (0.56, thigh, 0.5), under or legs)
            knee = f.hip + 0.25
            shin_lo = max(0.3, knee - (d["leg"] + 0.1))                            # adults reach the floor
            xs = sx * 0.27                                                         # inside the chair's front legs
            b.box_base((xs, y1 + 0.27, shin_lo), (0.48, 0.46, knee - shin_lo), legs)
            b.box_base((xs, y1 + 0.1, shin_lo - 0.3), (0.5, 0.9, 0.3), shoes)
            b.box((xs, y1 - 0.36, shin_lo - 0.12), (0.42, 0.04, 0.12), toe, bevel=False)


def _lower(b, f, look):
    """Pelvis and skirt or trousers top."""
    d = f.d
    if look.get("skirt"):
        lo = f.hip + (0.02 if f.sit else -0.4)
        b.box_base((0, f.back, lo), (d["tw"] + 0.05, d["td"] + 0.1, f.waist + 0.05 - lo), look["skirt"])
        if not f.sit:
            for sx in (1, -1):                                                     # the flare
                b.wedge((sx * ((d["tw"] + 0.05) / 2 + 0.11), f.back, lo + (f.waist + 0.05 - lo) / 2),
                        (d["td"] + 0.06, 0.22, f.waist + 0.05 - lo - 0.02), look["skirt"], bevel=False,
                        rot=_rz(90 * sx))
        else:
            b.box(((0, f.back - 0.35, f.hip + 0.42)), (d["tw"] + 0.04, 0.9, 0.26), look["skirt"])  # over the lap
    else:
        b.box_base((0, f.back, f.hip), (d["tw"] - 0.1, d["td"] - 0.04, d["pelvis"] + 0.05),
                   look.get("shorts") or look.get("pants") or look.get("overalls"))


def _torso(b, f, look):
    d = f.d
    w, dep, z0, z1 = d["tw"], d["td"], f.waist - 0.05, f.top
    fy = f.back - dep / 2                                                          # the chest's front
    main = look.get("cardigan") or look["top"]
    b.box_base((0, f.back, z0), (w, dep, z1 - z0), main)
    if look.get("cardigan"):
        b.box((0, fy - 0.015, (z0 + z1) / 2 + 0.05), (0.42, 0.04, z1 - z0 - 0.15), look["top"], bevel=False)
        for z in (z0 + 0.35, z0 + 0.7, z0 + 1.05):
            b.box((0.27, fy - 0.025, z), (0.08, 0.03, 0.08), "offwhite" if main != "offwhite" else "fur_grey",
                  bevel=False)
    if look.get("stripes"):
        for k in range(3):
            z = z0 + 0.35 + 0.38 * k
            b.box((0, f.back, z), (w + 0.03, dep + 0.03, 0.12), look["stripes"], bevel=False)
    if look.get("star"):
        b.box((0, fy - 0.015, z0 + 0.65), (0.36, 0.03, 0.36), look["star"], bevel=False, rot=_ry(45))
    if look.get("hood"):
        b.box((0, f.back + dep / 2 + 0.12, z1 - 0.2), (0.95, 0.3, 0.55), look["top"])               # hood down
        b.box((0, fy - 0.015, z0 + 0.35), (0.8, 0.03, 0.4), "fur_strawberry", bevel=False)        # pocket
        for x in (-0.15, 0.15):
            b.box((x, fy - 0.03, z1 - 0.32), (0.05, 0.03, 0.4), "offwhite", bevel=False)          # strings
    if look.get("overalls"):
        b.box((0, fy - 0.015, z0 + 0.45), (0.8, 0.04, 0.8), look["overalls"], bevel=False)       # bib
        b.box((0, fy - 0.035, z0 + 0.55), (0.34, 0.02, 0.24), "fur_ink", bevel=False)           # its pocket
        for sx in (1, -1):
            b.box((sx * 0.3, fy - 0.015, z1 - 0.25), (0.14, 0.04, 0.55), look["overalls"], bevel=False)   # straps
            b.box((sx * 0.3, f.back + dep / 2 + 0.015, z1 - 0.3), (0.14, 0.04, 0.6), look["overalls"],
                  bevel=False)
            b.box((sx * 0.3, fy - 0.04, z0 + 0.82), (0.08, 0.02, 0.08), "brass", bevel=False)
    if look.get("suit"):
        b.box((0, fy - 0.015, (z0 + z1) / 2 + 0.1), (0.45, 0.04, z1 - z0 - 0.2), "offwhite", bevel=False)
        for x in (-0.12, 0.12):
            b.box((x, fy - 0.04, z1 - 0.2), (0.2, 0.03, 0.14), "rarity_legend", bevel=False)     # bow tie
        b.box((0, fy - 0.05, z1 - 0.2), (0.08, 0.02, 0.1), "rarity_legend", bevel=False)
        b.box((-0.48, fy - 0.015, z1 - 0.45), (0.24, 0.03, 0.1), "rarity_legend", bevel=False)   # pocket square
        if not f.sit:
            b.box_base((0, f.back + dep / 2 + 0.03, z0 - 0.75), (w - 0.3, 0.06, 0.8), "fur_black")  # tails
    if look.get("scarf"):
        b.box_base((0, f.back, z1 - 0.1), (0.95, dep - 0.05, 0.28), look["scarf"])
        b.box((0.3, fy - 0.04, z1 - 0.45), (0.28, 0.06, 0.6), look["scarf"], bevel=False, rot=_ry(-8))
    if look.get("backpack") and not f.sit:
        b.box((0, f.back + dep / 2 + 0.22, (z0 + z1) / 2 + 0.05), (w - 0.2, 0.44, z1 - z0 - 0.15), look["backpack"])
        b.box((0, f.back + dep / 2 + 0.45, (z0 + z1) / 2 - 0.05), (w - 0.5, 0.06, 0.4), "fur_strawberry",
              bevel=False)
        for sx in (1, -1):
            b.box((sx * 0.33, fy - 0.015, (z0 + z1) / 2 + 0.1), (0.14, 0.04, z1 - z0 - 0.3), "fur_ink", bevel=False)


def _arms(b, f, look):
    d = f.d
    sleeve = look.get("cardigan") or look["top"]
    cuff = "offwhite" if look.get("suit") else sleeve
    for sx in (1, -1):
        x = sx * (d["tw"] / 2 + 0.2)
        a1 = f.top + 0.05
        if f.sit:                                  # forearms on the table top (2.6), the chair 2.4 from its middle
            b.box_base((x, f.back, REST), (0.42, 0.46, a1 - REST), sleeve)
            fa = f.back - 0.83                                                       # the wrist
            b.box_base((x, (f.back + fa) / 2, REST), (0.4, 0.83, 0.36), sleeve)
            if look.get("stripes"):
                b.box((x, f.back, (a1 + REST + 0.36) / 2), (0.45, 0.49, 0.12), look["stripes"], bevel=False)
            b.box_base((x, fa - 0.16, REST), (0.38, 0.34, 0.32), look["skin"])           # hand
            if look.get("cardigan") or look.get("suit"):
                b.box_base((x, fa + 0.05, REST - 0.01), (0.44, 0.1, 0.38), cuff)
            continue
        a0 = a1 - d["arm"]
        b.box_base((x, f.back, a0), (0.42, 0.46, a1 - a0), sleeve)
        if look.get("stripes"):
            for k in range(2):
                b.box((x, f.back, a0 + 0.3 + 0.38 * k), (0.45, 0.49, 0.12), look["stripes"], bevel=False)
        b.box_base((x, f.back, a0 - 0.32), (0.4, 0.42, 0.34), look["skin"])                      # hand
        if look.get("cardigan") or look.get("suit"):
            b.box_base((x, f.back, a0 - 0.02), (0.45, 0.49, 0.1), cuff)
    if f.sit:
        return
    x = -(d["tw"] / 2 + 0.2)
    hand = f.top + 0.05 - d["arm"] - 0.16
    if look.get("cup"):
        b.cyl_base((x, f.back - 0.42, hand - 0.22), 0.18, 0.46, "offwhite", segments=10)
        b.cyl_base((x, f.back - 0.42, hand - 0.08), 0.195, 0.16, "caramel_wood", segments=10, bevel=False)
        b.cyl_base((x, f.back - 0.42, hand + 0.24), 0.2, 0.06, "choco", segments=10, bevel=False)
    if look.get("book"):
        b.box((x - 0.02, f.back - 0.42, hand + 0.05), (0.16, 0.55, 0.72), look["book"])
        b.box((x - 0.02, f.back - 0.42 + 0.02, hand + 0.05), (0.17, 0.48, 0.64), "offwhite", bevel=False)
    if look.get("tote"):                                      # carried by its handles
        b.box_base((x, f.back, hand - 1.05), (0.26, 0.9, 0.82), look["tote"])
        b.box((x - 0.14, f.back, hand - 0.62), (0.02, 0.3, 0.28), "offwhite", bevel=False)        # a paw print
        for dy in (-0.2, 0.2):
            b.box_base((x, f.back + dy, hand - 0.24), (0.08, 0.08, 0.3), look["tote"], bevel=False)  # handles
    if look.get("cane"):
        cx = d["tw"] / 2 + 0.2
        b.cyl_base((cx, f.back - 0.34, 0), 0.07, hand + 0.05, look["cane"], segments=8)
        b.box((cx, f.back - 0.12, hand + 0.1), (0.14, 0.5, 0.14), look.get("knob", look["cane"]))


def _face(b, f, look):
    d = f.d
    y = f.face
    ez = f.head0 + d["hh"] * 0.47
    for sx in (1, -1):
        b.box((sx * 0.32, y - 0.01, ez), (0.17, 0.02, 0.28), FACE_INK, bevel=False)              # eyes
        b.box((sx * 0.32 - 0.03, y - 0.025, ez + 0.06), (0.06, 0.01, 0.07), "milk", bevel=False)
        b.box((sx * 0.52, y - 0.01, ez - 0.25), (0.24, 0.015, 0.1), "blush", bevel=False)       # cheeks
        if look.get("brows"):
            b.box((sx * 0.33, y - 0.01, ez + 0.27), (0.24, 0.015, 0.06), look["hair"], bevel=False)
    mz = ez - 0.33
    if look.get("moustache"):
        for sx in (1, -1):
            b.box((sx * 0.14, y - 0.03, mz + 0.06), (0.28, 0.05, 0.1), look["hair"], bevel=False, rot=_ry(-12 * sx))
    else:
        b.box((0, y - 0.01, mz), (0.16, 0.015, 0.05), "nose_brick", bevel=False)                 # a smile
        for sx in (1, -1):
            b.box((sx * 0.1, y - 0.01, mz + 0.03), (0.05, 0.015, 0.07), "nose_brick", bevel=False)
    if look.get("beard"):
        b.box((0, y - 0.03, f.head0 + 0.18), (1.1, 0.06, 0.38), look["hair"], bevel=False)
        for sx in (1, -1):
            b.box((sx * 0.62, y + 0.2, f.head0 + 0.45), (0.3, 0.45, 0.6), look["hair"], bevel=False)
    if look.get("glasses"):
        g = look["glasses"]
        for sx in (1, -1):
            cx = sx * 0.32
            for dz in (-0.2, 0.2):
                b.box((cx, y - 0.04, ez + dz), (0.4, 0.02, 0.05), g, bevel=False)
            for dx in (-0.18, 0.18):
                b.box((cx + dx, y - 0.04, ez), (0.05, 0.02, 0.4), g, bevel=False)
        b.box((0, y - 0.04, ez + 0.05), (0.2, 0.02, 0.05), g, bevel=False)
    if look.get("monocle"):
        b.ring((0.32, y - 0.05, ez), 0.24, 0.05, 0.03, "rarity_legend", segments=10, bevel=False,
               rot=(math.radians(90), "X"))


def _hair(b, f, look):
    d = f.d
    hw, hd, top, h0 = d["hw"], d["hd"], f.head1, f.head0
    by, fy, hc = f.back, f.face, look["hair"]
    style = look["style"]
    if style in ("bob", "short", "bun", "curls", "puffs"):
        b.box_base((0, by, top - 0.3), (hw + 0.12, hd + 0.12, 0.42 if style != "short" else 0.36), hc)  # crown
        drop = {"bob": 0.95, "short": 0.45, "bun": 0.6, "curls": 0.6, "puffs": 0.55}[style]
        b.box_base((0, by + hd / 2 - 0.05, top - 0.1 - drop), (hw + 0.12, 0.24, drop), hc)                # back
        for sx in (1, -1):                                                                                 # sides
            b.box_base((sx * (hw / 2 + 0.03), by + 0.12, top - 0.1 - drop * 0.85), (0.12, hd - 0.2, drop * 0.85), hc)
        if style not in ("short", "bun"):
            b.box((0, fy - 0.05, top - 0.22), (hw - 0.1, 0.12, 0.26), hc)                                  # fringe
    if style == "bob":
        b.box((0, by + hd / 2 + 0.02, top - 1.0), (hw + 0.16, 0.28, 0.12), hc)                         # its hem
        for sx in (1, -1):
            b.box((sx * (hw / 2 + 0.05), by + 0.1, top - 1.0), (0.16, hd - 0.1, 0.12), hc)
    if style == "bun":
        b.sphere((0, by + hd / 2 - 0.05, top - 0.05), 0.4, hc, segments=10, rings=6)                    # the bun
    if style == "curls":
        for x, y, z in ((-0.5, -0.2, 0.18), (0.0, -0.3, 0.22), (0.5, -0.2, 0.18), (-0.35, 0.35, 0.2),
                        (0.35, 0.35, 0.2)):
            b.sphere((x, by + y, top + z), 0.3, hc, segments=8, rings=5)
    if style == "puffs":
        for sx in (1, -1):
            b.sphere((sx * 0.62, by + 0.1, top + 0.18), 0.42, hc, segments=10, rings=6)
    if style == "cap":
        b.box_base((0, by, top - 0.25), (hw + 0.1, hd + 0.1, 0.42), look["cap"])
        b.box((0, fy - 0.3, top - 0.18), (hw - 0.1, 0.65, 0.08), look["cap"], bevel=False)               # peak
        b.box_base((0, by + 0.05, top + 0.16), (0.18, 0.18, 0.08), "offwhite", bevel=False)            # button
        b.box_base((0, by + hd / 2 - 0.02, top - 0.7), (hw + 0.06, 0.16, 0.5), hc)                       # hair below
    if style == "beanie":
        b.box_base((0, by + 0.06, h0 + 0.35), (hw + 0.1, hd - 0.06, 0.6), hc)                             # hair below
        b.box_base((0, by, top - 0.38), (hw + 0.14, hd + 0.14, 0.62), look["beanie"])
        b.box_base((0, by, top - 0.42), (hw + 0.2, hd + 0.2, 0.2), look["beanie"])                       # fold
        b.sphere((0, by, top + 0.36), 0.24, "offwhite", segments=8, rings=5)                           # pom-pom
    if look.get("top_hat"):
        b.box_base((0, by, top + 0.1), (1.9, 1.75, 0.1), "fur_black")                                    # brim
        b.box_base((0, by, top + 0.18), (1.25, 1.2, 1.15), "fur_black")
        b.box_base((0, by, top + 0.3), (1.28, 1.23, 0.2), "rarity_legend", bevel=False)               # gold band
    if look.get("phones"):
        b.box_base((0, by, top + 0.1), (hw + 0.36, 0.22, 0.14), "fur_black", bevel=False)              # band
        for sx in (1, -1):
            b.box_base((sx * (hw / 2 + 0.11), by, h0 + 0.55), (0.14, 0.22, top + 0.1 - h0 - 0.55), "fur_black",
                       bevel=False)
            b.box((sx * (hw / 2 + 0.16), by, h0 + 0.6), (0.24, 0.5, 0.5), look["phones"])               # cups


def build_customer(variant, mat, sit=False):
    look = LOOKS[variant]
    f = Frame(look["body"], sit)
    b = Builder()
    _legs(b, f, look)
    _lower(b, f, look)
    _torso(b, f, look)
    _arms(b, f, look)
    b.box_base((0, f.back, f.top - 0.05), (0.5, 0.5, 0.2), look["skin"], bevel=False)                    # neck
    b.box_base((0, f.back, f.head0), (f.d["hw"], f.d["hd"], f.d["hh"]), look["skin"])
    _face(b, f, look)
    _hair(b, f, look)
    name = f"CatCafe_NPC_Customer_{variant}" + ("_Sit" if sit else "")
    return [b.finalize(name, mat)]


ASSETS = {}
for _v in LOOKS:
    ASSETS[f"CatCafe_NPC_Customer_{_v}"] = (lambda mat, v=_v: build_customer(v, mat), 1600)
    ASSETS[f"CatCafe_NPC_Customer_{_v}_Sit"] = (lambda mat, v=_v: build_customer(v, mat, sit=True), 1600)
