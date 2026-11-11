"""Cat Arcade pictures for Mouse Dash (#3296, Design-Agent's mouse-dash-spec-3296.md section 5a): the pieces the
Arcade screen draws its second game with, rendered by icons.py as CatCafe_Icon_Arcade_<Name> (transparent, thick dark
outline, 512 px, readable at 64 px). pack_arcade_sheet.py packs them into one sheet for a single upload.

  Mouse, MouseHit          the grey mouse up out of its hole, and squashed flat under the paw with stars knocked out
  GoldMouse, GoldMouseHit  the golden mouse (+3), the same two, twinkling
  Kitten, KittenAwake      the napping kitten (do not tap): eyes shut and Zzz, then wide awake after a tap
  Hole                     one mouse hole in the cellar floor: a wooden rim round the dark hole, cheese crumbs
  HoleFront                only the front half of that rim, framed exactly as Hole. The screen stacks Hole, then the
                           animal sliding up inside a clipping frame, then HoleFront over it, so it rises out of the
                           hole. Peeking is the same picture slid a third of the way up
  Dust                     the puff a mouse leaves when it gets away
  Paw, PawBop              the player's cat paw: ready (beans showing) and landing (flatter, with impact dashes)
  Heart, HeartEmpty        a life: a paw print with a heart for its big pad, pink and spent
  Cheese                   a cheese wedge, for the score and the milestone row
  MouseDash                the game's own picture (its tab, the menu row, What's new): the mouse halfway out of a hole
  Backdrop                 the cheese cellar floor from straight above in the arcade's night purples, low contrast,
                           no outline: the board the nine holes sit on

The animals and the hole share one view (VIEW) so they stack, and the six animal pictures share one hidden frame, so
they are the same scale and centred left to right (the Zzz, stars and sparkles sit inside that frame). The Paw and
PawBop pictures are centred on the paw's pad. Centre a cell on the hole and the piece lands dead centre. Draw an
animal cell at about 0.95 of the hole picture's width.

Each builder lays its object out in Blender axes (x right, -y toward the camera, z up) and returns its objects; nothing
here is a game model. An object tagged ob["fit_only"] only frames the camera and is hidden in the render.
"""

import math

from common import Builder

VIEW = (0.0, 24.0)                       # yaw, pitch: straight on, looking a little down into the hole
FACE = (math.radians(90), "X")           # turns a disc to face the camera (-Y)
FUR, EAR, INK_SW = "fur_pewter", "fur_rose", "fur_black"
RIM, RIM_LO, DARK, DARK_BACK = "caramel_wood", "dark_wood", "fur_black", "fur_ash"
R_IN, R_OUT, R_SKIRT, RIM_H = 1.0, 1.45, 1.75, 0.34       # the hole's mouth, its wooden rim, the rim's skirt


def _fin(b, name, mat, fit_only=False):
    ob = b.finalize("CatCafe_IconArt_Arcade_" + name, mat)
    if fit_only:
        ob["fit_only"] = True
    return ob


def _ring(b, r0, r1, z0, z1, swatch, a0=0.0, a1=360.0, n=20):
    """A flat-topped ring from radius r0 to r1 between the angles a0 and a1 (degrees, 0 = +x, 270 = toward the
    camera), built from n wedge blocks a full turn."""
    steps = max(1, round(n * (a1 - a0) / 360.0))
    for i in range(steps):
        t0 = math.radians(a0 + (a1 - a0) * i / steps)
        t1 = math.radians(a0 + (a1 - a0) * (i + 1) / steps)
        pts = [(r1 * math.cos(t0), r1 * math.sin(t0)), (r1 * math.cos(t1), r1 * math.sin(t1)),
               (r0 * math.cos(t1), r0 * math.sin(t1)), (r0 * math.cos(t0), r0 * math.sin(t0))]
        cx, cy = sum(p[0] for p in pts) / 4, sum(p[1] for p in pts) / 4
        b.prism((cx, cy, (z0 + z1) / 2), [(x - cx, y - cy) for x, y in pts], z1 - z0, swatch)


def _hole_back(b):
    """Everything but the front lip: the back of the rim and the dark hole."""
    _ring(b, R_OUT, R_SKIRT, 0.0, 0.16, RIM_LO, 0.0, 180.0)
    _ring(b, R_IN, R_OUT, 0.0, RIM_H, RIM, 0.0, 180.0)
    b.cyl((0, 0, 0.05), R_IN, 0.08, DARK_BACK, segments=24, bevel=False)         # the far wall catches a little light
    b.cyl((0, -0.14, 0.08), R_IN - 0.12, 0.08, DARK, segments=24, bevel=False)   # the dark of the hole


def _hole_front(b):
    """The front lip: the near half of the rim and its skirt, with a few cheese crumbs."""
    _ring(b, R_OUT, R_SKIRT, 0.0, 0.16, RIM_LO, 180.0, 360.0)
    _ring(b, R_IN, R_OUT, 0.0, RIM_H, RIM, 180.0, 360.0)
    for x, y, s in ((-1.25, -1.5, 0.2), (-0.9, -1.74, 0.13), (1.3, -1.45, 0.16)):
        b.box((x, y, s / 2), (s * 1.3, s, s), "fur_golden", bevel=False)


def hole(mat):
    b = Builder()
    _hole_back(b)
    _hole_front(b)
    return [_fin(b, "Hole", mat)]


def hole_front(mat):
    front, back = Builder(), Builder()
    _hole_front(front)
    _hole_back(back)
    return [_fin(front, "HoleFront", mat), _fin(back, "HoleFrontFrame", mat, fit_only=True)]


def _frame(name, mat, centre, size):
    """A hidden slab that frames the camera: every picture sharing a frame has the same scale and the same middle,
    so the screen can centre a cell on a hole and the animal (or the paw's pad) lands dead centre."""
    b = Builder()
    b.box(centre, size, "offwhite", bevel=False)
    return _fin(b, name + "Frame", mat, fit_only=True)


def _animal_frame(name, mat):
    return _frame(name, mat, (0, 0, 1.85), (4.3, 0.02, 4.1))


def _ear(b, x, z, r, fur, inner):
    b.cyl((x, 0.15, z), r, 0.2, fur, segments=16, bevel=False, rot=FACE)
    b.cyl((x - 0.02 * (1 if x > 0 else -1), 0.03, z - 0.03), r * 0.62, 0.06, inner, segments=14, bevel=False, rot=FACE)


def _mouse_body(b, coat, z=0.0, shoulders=True):
    fur, _inner, pale = coat
    if shoulders:
        b.box((0, 0.05, z + 0.3), (1.35, 1.0, 1.0), fur)                           # shoulders
        b.box((0, -0.47, z + 0.38), (0.8, 0.08, 0.7), pale)                        # a pale tummy
    b.box((0, 0, z + 1.45), (1.9, 1.35, 1.45), fur)                                # head
    b.box((0, -0.68, z + 1.12), (1.0, 0.16, 0.62), pale)                           # muzzle
    b.box((0, -0.8, z + 1.34), (0.32, 0.12, 0.22), "nose_pink")                    # nose
    for sx in (-1, 1):
        b.box((sx * 0.72, -0.69, z + 1.2), (0.26, 0.04, 0.16), "blush")            # cheeks
        for k, dz in enumerate((1.22, 1.06)):                                      # whiskers
            b.box((sx * 0.95, -0.72, z + dz), (0.62, 0.03, 0.045), "choco",
                  rot=(math.radians(sx * (10 - 20 * k)), "Y"))


def _mouse_face(b, coat, z=0.0):
    fur, inner, _pale = coat
    for sx in (-1, 1):
        _ear(b, sx * 0.98, 2.3 + z, 0.62, fur, inner)
        b.box((sx * 0.46, -0.69, 1.68 + z), (0.3, 0.06, 0.42), INK_SW)             # eyes
        b.box((sx * 0.4, -0.725, 1.79 + z), (0.11, 0.04, 0.12), "offwhite")        # shine
    b.box((0, -0.79, z + 0.9), (0.3, 0.06, 0.24), "offwhite")                      # buck teeth
    b.box((0, -0.825, z + 0.9), (0.03, 0.02, 0.24), "fur_pewter")


def _star(b, c, r, swatch="fur_golden"):
    pts = []
    for i in range(10):
        a = math.radians(90 + 36 * i)
        k = r if i % 2 == 0 else r * 0.45
        pts.append((k * math.cos(a), k * math.sin(a)))
    b.prism(c, pts, 0.1, swatch, rot=FACE)


def _mouse(name, coat, sparkle=False):
    def build(mat):
        b = Builder()
        _mouse_body(b, coat)
        _mouse_face(b, coat)
        if sparkle:                                                                # the golden mouse twinkles
            _star(b, (-1.55, -0.3, 2.95), 0.26, "sparkle")
            _star(b, (1.6, -0.3, 1.55), 0.2, "sparkle")
        return [_fin(b, name, mat), _animal_frame(name, mat)]
    return build


def _mouse_hit(name, coat):
    """The mouse the moment the paw lands: squashed flat and wide, eyes squeezed shut, stars knocked out of it."""
    def build(mat):
        b, stars = Builder(), Builder()
        fur, inner, _pale = coat
        _mouse_body(b, coat)
        for sx in (-1, 1):
            _ear(b, sx * 1.12, 2.05, 0.6, fur, inner)                              # ears knocked down and out
            for k in (-1, 1):                                                      # eyes squeezed shut: > and <
                b.box((sx * 0.46, -0.69, 1.68 + k * 0.1), (0.36, 0.06, 0.09), INK_SW,
                      rot=(math.radians(sx * k * 28), "Y"))
        b.box((0, -0.79, 0.9), (0.34, 0.06, 0.3), "nose_brick")                    # an open mouth
        b.box((0, -0.815, 0.99), (0.3, 0.04, 0.1), "offwhite")
        body = _fin(b, name, mat)
        body.scale = (1.2, 1.0, 0.66)
        _star(stars, (-1.75, -0.3, 2.05), 0.34)
        _star(stars, (0.1, -0.3, 2.45), 0.42)
        _star(stars, (1.8, -0.3, 2.0), 0.3, "sparkle")
        return [body, _fin(stars, name + "Stars", mat), _animal_frame(name, mat)]
    return build


GREY = ("fur_pewter", "fur_rose", "fur_white")
GOLD = ("fur_golden", "pastel_butter", "fur_vanilla")


def _zed(b, x, z, s, swatch="pastel_sky"):
    """One Z, s wide and tall, facing the camera."""
    t = s * 0.22
    b.box((x, -0.3, z + s / 2 - t / 2), (s, 0.08, t), swatch, bevel=False)
    b.box((x, -0.3, z - s / 2 + t / 2), (s, 0.08, t), swatch, bevel=False)
    b.box((x, -0.3, z), (s * 1.05, 0.07, t), swatch, bevel=False, rot=(math.radians(-42), "Y"))


def _kitten_head(b):
    b.box((0, 0.05, 0.3), (1.3, 1.0, 1.0), "fur_orange")                           # shoulders
    b.box((0, -0.47, 0.4), (0.78, 0.08, 0.7), "fur_cream")                         # bib
    b.box((0, 0, 1.4), (1.95, 1.35, 1.4), "fur_orange")                            # head
    b.box((0, -0.68, 1.06), (0.95, 0.16, 0.5), "fur_cream")                        # muzzle
    for sx in (-1, 1):
        b.pyramid((sx * 0.62, 0, 2.1), 0.68, 0.62, "fur_orange")                   # ears
        b.pyramid((sx * 0.62, -0.14, 2.12), 0.36, 0.4, "nose_pink")
        b.box((sx * 0.74, -0.69, 1.22), (0.28, 0.04, 0.16), "blush")               # cheeks
        b.box((sx * 0.9, -0.69, 1.86), (0.3, 0.05, 0.08), "fur_orange_dark")       # forehead stripes
        for dz in (1.14, 1.0):
            b.box((sx * 0.96, -0.72, dz), (0.56, 0.03, 0.045), "choco")
        b.box((sx * 0.12, -0.78, 0.96), (0.2, 0.04, 0.06), INK_SW, rot=(math.radians(-sx * 30), "Y"))   # w mouth
    b.box((0, -0.69, 1.97), (0.12, 0.05, 0.26), "fur_orange_dark")
    b.box((0, -0.8, 1.22), (0.26, 0.1, 0.16), "nose_pink")


def kitten(mat):
    """The napping kitten: do not tap. Eyes shut in two little curves, Zzz drifting up."""
    b = Builder()
    _kitten_head(b)
    for sx in (-1, 1):
        for k in (-1, 1):                                                          # closed eyes, a shallow curve each
            b.box((sx * 0.48 + k * 0.12, -0.69, 1.56), (0.28, 0.06, 0.08), INK_SW,
                  rot=(math.radians(k * 24), "Y"))
    _zed(b, 0.95, 2.78, 0.3)                                                        # rising over one ear
    _zed(b, 1.32, 3.17, 0.4)
    _zed(b, 1.72, 3.6, 0.5)
    return [_fin(b, "Kitten", mat), _animal_frame("Kitten", mat)]


def kitten_awake(mat):
    """The kitten woken by a tap: wide eyes, a small round mouth."""
    b = Builder()
    _kitten_head(b)
    for sx in (-1, 1):
        b.box((sx * 0.48, -0.69, 1.62), (0.4, 0.06, 0.46), INK_SW)
        b.box((sx * 0.4, -0.725, 1.74), (0.15, 0.04, 0.16), "offwhite")
        b.box((sx * 0.56, -0.725, 1.5), (0.08, 0.04, 0.08), "offwhite")
    b.box((0, -0.8, 0.9), (0.18, 0.05, 0.16), "nose_brick")                        # "mrow?"
    b.box((1.5, -0.3, 2.55), (0.16, 0.08, 0.5), "pastel_sky", bevel=False)         # a little "!"
    b.box((1.5, -0.3, 2.12), (0.16, 0.08, 0.16), "pastel_sky", bevel=False)
    return [_fin(b, "KittenAwake", mat), _animal_frame("KittenAwake", mat)]


def dust(mat):
    """The puff a mouse leaves when it gets away."""
    b = Builder()
    for x, z, r, sw in ((-0.9, 0.5, 0.62, "fur_vanilla"), (0.0, 0.75, 0.8, "offwhite"), (0.95, 0.5, 0.6, "fur_vanilla"),
                        (-0.4, 1.35, 0.5, "offwhite"), (0.55, 1.3, 0.44, "fur_vanilla")):
        b.ico((x, 0, z), r, sw, subdivisions=2)
    for x, z in ((-1.75, 1.2), (1.7, 1.25), (0.1, 2.15)):
        b.ico((x, 0, z), 0.16, "fur_vanilla", subdivisions=1)
    return [_fin(b, "Dust", mat), _frame("Dust", mat, (0, 0, 1.2), (4.3, 0.02, 2.6))]


def _paw(name, tilt, bop=False):
    """The player's cat paw: a cream arm coming in from the lower right, pink toe beans toward the camera."""
    def build(mat):
        b, extra = Builder(), Builder()
        b.box((0, 0, 1.5), (0.95, 0.8, 2.2), "fur_vanilla")                        # arm
        b.box((0, -0.02, 3.0), (1.5, 0.95, 1.3), "fur_vanilla")                    # paw
        for dx in (-0.5, 0.0, 0.5):                                                # toes
            b.box((dx, -0.02, 3.72), (0.44, 0.9, 0.3), "fur_vanilla")
            b.cyl((dx, -0.49, 3.5 + (0.08 if dx == 0 else 0)), 0.17, 0.06, "nose_pink", segments=12, bevel=False, rot=FACE)
        b.cyl((0, -0.5, 2.95), 0.36, 0.06, "nose_pink", segments=14, bevel=False, rot=FACE, scale=(1.2, 1.0, 1.0))
        arm = _fin(b, name, mat)
        arm.rotation_euler = (0, math.radians(tilt), 0)
        k = 0.94 if bop else 1.0                                                   # the pad's middle, after the turn
        px, pz = 2.95 * k * math.sin(math.radians(tilt)), 2.95 * k * math.cos(math.radians(tilt))
        frame = _frame(name, mat, (px, 0, pz), (5.6, 0.02, 5.6))                   # the pad is the picture's middle
        if bop:
            arm.scale = (1.08, 1.0, 0.94)
            for a, r in ((200, 0.5), (232, 0.62), (262, 0.5)):                     # impact dashes under the paw
                t = math.radians(a)
                extra.box((px + 1.75 * math.cos(t) * 0.8 - 0.35, -0.3, pz + 1.75 * math.sin(t) * 0.8 + 0.25),
                          (r, 0.08, 0.14), "fur_golden", bevel=False, rot=(-t, "Y"))
            return [arm, _fin(extra, name + "Lines", mat), frame]
        return [arm, frame]
    return build


def _heart(name, pad, toe):
    """A life: a paw print whose big pad is a heart."""
    def build(mat):
        b = Builder()
        pts = []
        for i in range(28):
            t = -2 * math.pi * i / 28
            pts.append((16 * math.sin(t) ** 3 * 0.07,
                        (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * 0.07))
        b.prism((0, 0, 0.9), pts, 0.3, pad, rot=FACE)
        for dx, dz, r in ((-0.95, 2.15, 0.36), (0.0, 2.45, 0.4), (0.95, 2.15, 0.36)):
            b.cyl((dx, 0, dz), r, 0.3, toe, segments=16, bevel=False, rot=FACE)
        return [_fin(b, name, mat)]
    return build


def cheese(mat):
    b = Builder()
    pts = [(-1.1, -0.75), (1.2, -0.75), (-1.1, 0.95)]
    cx, cy = sum(p[0] for p in pts) / 3, sum(p[1] for p in pts) / 3
    b.prism((cx, cy, 0.5), [(x - cx, y - cy) for x, y in pts], 1.0, "fur_golden")
    b.prism((cx, cy, 1.03), [((x - cx) * 0.94, (y - cy) * 0.94) for x, y in pts], 0.06, "pastel_butter")   # the top
    for x, z, r in ((-0.6, 0.6, 0.2), (0.1, 0.36, 0.14), (0.55, 0.68, 0.11), (-0.15, 0.8, 0.09)):         # holes
        b.cyl((x, -0.74, z), r, 0.06, "eye_amber", segments=12, bevel=False, rot=FACE)
    b.cyl((-0.55, -0.05, 1.07), 0.17, 0.03, "eye_amber", segments=12, bevel=False)
    b.cyl((-0.85, 0.42, 1.07), 0.1, 0.03, "eye_amber", segments=12, bevel=False)
    return [_fin(b, "Cheese", mat)]


def mouse_dash(mat):
    b = Builder()
    _hole_back(b)
    z = -0.55                                                                      # the mouse halfway out
    _mouse_body(b, GREY, z, shoulders=False)
    _mouse_face(b, GREY, z)
    _hole_front(b)
    for sx in (-1, 1):                                                             # paws on the rim
        b.box((sx * 0.62, -1.12, RIM_H + 0.09), (0.36, 0.5, 0.2), "fur_rose")
    return [_fin(b, "MouseDash", mat)]


def backdrop(mat):
    """The cheese cellar floor seen from straight above, in the arcade's night purples at low contrast so the holes
    and animals stand out: floorboards, a stone edge, and a few small cheese pieces against the edge between the rows of holes."""
    b = Builder()
    S = 10.0
    b.box((0, 0, -0.1), (S, S, 0.2), "night_sky", bevel=False)                     # the gaps between the boards
    n = 8
    for i in range(n):                                                             # floorboards, staggered ends
        y = -S / 2 + (i + 0.5) * S / n
        cut = (-1.8, 2.6, -3.0, 0.8, 3.4, -0.6, 1.9, -2.4)[i]
        for x0, x1 in ((-S / 2, cut), (cut, S / 2)):
            b.box(((x0 + x1) / 2, y, 0.02), (x1 - x0 - 0.07, S / n - 0.07, 0.04), "fur_indigo", bevel=False)
    for sx in (-1, 1):                                                             # the stone edge
        b.box((sx * (S / 2 - 0.2), 0, 0.06), (0.4, S, 0.12), "galaxy_blue", bevel=False)
        b.box((0, sx * (S / 2 - 0.2), 0.06), (S - 0.8, 0.4, 0.12), "galaxy_blue", bevel=False)

    def wheel(x, y, r, cutout):
        b.cyl((x, y, 0.2), r, 0.3, "velvet_lilac", segments=20, bevel=False)
        b.cyl((x, y, 0.36), r * 0.82, 0.04, "aurora_violet", segments=20, bevel=False)
        for dx, dy, k in ((0.3, 0.2, 0.14), (-0.35, 0.1, 0.1), (0.05, -0.4, 0.12)):
            b.cyl((x + dx * r, y + dy * r, 0.39), k * r, 0.03, "velvet_lilac", segments=10, bevel=False)
        if cutout:                                                                 # a slice taken out
            b.prism((x, y, 0.3), [(0, 0.02), (r * 1.05, -r * 0.25), (r * 1.05, r * 0.45)], 0.5, "fur_indigo")

    def wedge(x, y, turn, k=1.0):
        b.prism((x, y, 0.2), [(-0.5 * k, -0.45 * k), (0.75 * k, -0.45 * k), (-0.5 * k, 0.6 * k)], 0.3, "velvet_lilac",
                rot=(math.radians(turn), "Z"))
        b.prism((x, y, 0.37), [(-0.42 * k, -0.38 * k), (0.55 * k, -0.38 * k), (-0.42 * k, 0.44 * k)], 0.04,
                "aurora_violet", rot=(math.radians(turn), "Z"))

    # Derek, 2026-11-11: nothing near a hole. The nine holes sit on thirds, so the few small pieces hug the edge on
    # the lines between the rows and columns, where no mouse can pop up.
    T = S / 6
    wheel(-4.15, T, 0.42, True)
    wheel(4.15, -T, 0.42, False)
    wedge(-T, 4.2, 200, 0.55)
    wedge(T, -4.2, 30, 0.55)
    for x, y in ((-4.3, -T), (4.3, T), (T, 4.3), (-T, -4.3)):                      # crumbs
        b.box((x, y, 0.1), (0.16, 0.14, 0.1), "velvet_lilac", bevel=False)
    return [_fin(b, "Backdrop", mat)]


BUILDERS = {
    "Mouse": _mouse("Mouse", GREY), "MouseHit": _mouse_hit("MouseHit", GREY),
    "GoldMouse": _mouse("GoldMouse", GOLD, sparkle=True), "GoldMouseHit": _mouse_hit("GoldMouseHit", GOLD),
    "Kitten": kitten, "KittenAwake": kitten_awake,
    "Hole": hole, "HoleFront": hole_front, "Dust": dust,
    "Paw": _paw("Paw", -24), "PawBop": _paw("PawBop", -62, bop=True),
    "Heart": _heart("Heart", "neon_pink", "nose_pink"), "HeartEmpty": _heart("HeartEmpty", "fur_bramble", "fur_bramble"),
    "Cheese": cheese, "MouseDash": mouse_dash, "Backdrop": backdrop,
}
VIEWS = {n: VIEW for n in BUILDERS}
VIEWS.update({"Cheese": (-28.0, 22.0), "MouseDash": (-8.0, 24.0), "Paw": (0.0, 8.0), "PawBop": (0.0, 8.0),
              "Heart": (0.0, 0.0), "HeartEmpty": (0.0, 0.0), "Dust": (0.0, 8.0), "Backdrop": (0.0, 90.0)})
WIDTH = 16                               # outline at 512 px: thick, so a piece still reads at 64 px
PADS = {"Backdrop": -0.01}               # the floor fills its square edge to edge
WIDTHS = {"Backdrop": 0}                 # and has no outline
