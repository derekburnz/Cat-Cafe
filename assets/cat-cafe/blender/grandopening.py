"""The Grand Opening ribbon set (#1922, first-hour.md section 1d, for the roadmap of #1893): looks only, placed at the
Plot's pivot like the sign styles (Plot.cframe: floor top centre, -Z toward the street), nothing collides, all of it
above head height and clear of the doorway, the awnings and the back step.

  CatCafe_Plot_GrandOpeningRibbon    shown from the end of the tutorial until roadmap step 8: a red ribbon hung across
                                     the front between two brass rosettes on the piers beside the door (x +-8, y 10.3),
                                     sagging under a big red bow in front of the fanlight, with a cream swallowtail
                                     pennant hanging from its right half that reads GRAND OPENING / SOON. The root holds
                                     only the rosettes. The ribbon is two child Models, named as seen from the street:
                                     `_RibbonL` (x > 0: the left half, its bow loop and tail, and the knot) and
                                     `_RibbonR` (x < 0: the right half, its loop and tail, and the pennant), each pivoted
                                     at its own rosette, so at step 8 VFX can snap it: swing each half down about its
                                     pivot (about 60 degrees, about the pivot's Z axis) and fade it out
  CatCafe_Plot_GrandOpeningBunting   shown for 2 hours of play after step 8: four swags of pastel triangle flags along
                                     the eave between five brass hooks (y 12.55), above the awnings, and two balloon clusters tied beside
                                     the door, child Models `_LeftBalloons` and `_RightBalloons`, each pivoted at its
                                     tie so VFX can wobble it (not on low settings)

Built with RB in Roblox axes (x across, y up, -Z the front).
"""

import math

from mathutils import Matrix, Vector

import common
from common import RB, text_width
from plot import DOOR, FRONT, HWI, rot_z

RED, RED_DK = "shirt_red", "bowl_red"
ZR = FRONT - 0.62                       # the ribbon's depth: in front of the door's arch ring (FRONT - 0.35) and keystone
HOOK_X, HOOK_Y, SAG = 8.0, 10.3, 1.0    # the rosettes on the piers between the door and the windows, the ribbon's sag
BOW_Y = HOOK_Y - SAG + 0.05             # the bow's knot, at the ribbon's lowest point (x 0)
PASTELS = ("blush", "mint", "pastel_butter", "pastel_lilac", "pastel_sky", "apron_pink")


def _pivoted(ob, at):
    """Move an object's origin to Roblox point `at` without moving its geometry (a child Model's pivot). The
    primitive log moves with the mesh: rbx_export builds the Parts from it, and without that every Part landed a
    second `at` away (#2218: the balloons and ribbon halves floated out over the street)."""
    p = Vector(RB.p(*at))
    T = Matrix.Translation(-p)
    ob.data.transform(T)
    common.PRIMS[ob.data.name] = [(k, T @ m, sw, ex) for k, m, sw, ex in common.PRIMS.get(ob.data.name, [])]
    ob.location = p
    return ob


def _strip(b, pts, w, d, z, sw):
    """A flat band through the Roblox (x, y) points, `w` tall and `d` deep, one box per span (joints overlap a hair)."""
    for k, ((ax, ay), (bx, by)) in enumerate(zip(pts, pts[1:])):
        L = math.hypot(bx - ax, by - ay)                                   # every other span a hair deeper: no z-fight
        b.box(((ax + bx) / 2, (ay + by) / 2, z), (L + 0.06, w, d + 0.008 * (k % 2)), sw, rot=rot_z(math.degrees(math.atan2(by - ay, bx - ax))))


def _sag(x0, x1, y0, sag, n):
    return [(x0 + (x1 - x0) * k / n, y0 - sag * 4 * (k / n) * (1 - k / n)) for k in range(n + 1)]


def _ribbon_y(x):
    t = (x + HOOK_X) / (2 * HOOK_X)
    return HOOK_Y - SAG * 4 * t * (1 - t)


def _rosette(b, x, y, z):
    """A brass rosette on the wall: a disc with a ring of petals and a hook."""
    b.cyl((x, y, z), 0.26, 0.12, "brass", axis="Z", segments=10)
    b.cyl((x, y, z - 0.09), 0.14, 0.06, "gold_mid", axis="Z", segments=8)


def build_ribbon(mat):
    name = "CatCafe_Plot_GrandOpeningRibbon"
    root, left, right = RB(), RB(), RB()
    zw = FRONT - 0.06                                                                      # the rosettes' backs
    for sx in (-1, 1):
        _rosette(root, sx * HOOK_X, HOOK_Y, zw)
    pts = [(x, y) for x, y in _sag(-HOOK_X, HOOK_X, HOOK_Y, SAG, 12)]                     # the ribbon, hook to hook
    half = len(pts) // 2
    for b, seg in ((left, pts[:half + 1]), (right, pts[half:])):
        _strip(b, seg, 0.42, 0.05, ZR, RED)
        _strip(b, [(x, y + 0.17) for x, y in seg], 0.06, 0.06, ZR - 0.01, "gold_mid")      # a gold edge on top
    for b, sx in ((left, -1), (right, 1)):                                                 # each half's tie at its rosette
        b.span((sx * HOOK_X - 0.06, HOOK_Y - 0.2, ZR - 0.058), (sx * HOOK_X + 0.06, HOOK_Y + 0.2, zw - 0.04), RED_DK)
    # the big bow at x 0: two loops, two tails and a knot (the knot is on the x > 0 half, so it falls with it)
    for b, sx in ((left, -1), (right, 1)):
        for k, (dx, dy, a, L) in enumerate(((0.55, 0.32, 28, 1.1), (0.55, -0.12, -22, 1.0))):
            b.box((sx * dx, BOW_Y + dy, ZR - 0.088 - 0.012 * k), (L, 0.36, 0.14), RED,
                  rot=rot_z(sx * a))                                                       # a loop, top and bottom edge
        b.box((sx * 1.02, BOW_Y + 0.1, ZR - 0.096), (0.14, 0.62, 0.16), RED)                # the loop's outer end
        b.box((sx * 0.45, BOW_Y - 0.75, ZR - 0.045), (0.3, 1.1, 0.06), RED, rot=rot_z(sx * 18))   # a tail
        b.wedge((sx * 0.62, BOW_Y - 1.36, ZR - 0.045), (0.3, 0.2, 0.06), RED_DK, rot=rot_z(sx * 18))
    right.box((0.0, BOW_Y + 0.05, ZR - 0.115), (0.36, 0.42, 0.22), RED_DK)                  # the knot
    # the pennant, on the street's right half (x < 0) over the pier: a cream swallowtail with a red hem, GRAND OPENING over SOON
    px = 0.08
    w1, w2 = text_width("GRAND OPENING", px), text_width("SOON", px)
    pw, ph, pcx = w1 + 0.5, 1.3, -6.2
    top = _ribbon_y(pcx) - 0.3
    zp = ZR + 0.06                                                                         # just behind the ribbon
    for x in (pcx - pw / 2 + 0.6, pcx + pw / 2 - 0.6):                                     # its two ties, up to the ribbon
        left.span((x - 0.04, top - 0.1, zp - 0.02), (x + 0.04, _ribbon_y(x), zp + 0.02), "treat_tan")
    left.span((pcx - pw / 2, top - ph, zp - 0.03), (pcx + pw / 2, top, zp + 0.03), "cream")
    left.span((pcx - pw / 2 - 0.02, top - 0.12, zp - 0.04), (pcx + pw / 2 + 0.02, top + 0.02, zp + 0.04), RED)   # its hem
    for sx in (-1, 1):                                                                     # swallowtail ends
        xe, xo = pcx + sx * pw / 2, pcx + sx * (pw / 2 + 0.5)
        tri = [[(xe, top), (xo, top)], [(xo, top - ph), (xe, top - ph)]]
        for chain in tri:
            left.fan_z(zp - 0.025, (xe, top - ph / 2), chain if sx > 0 else chain[::-1], 0.05, "cream")
    zt = zp - 0.025
    left.text("GRAND OPENING", (pcx + w1 / 2, top - 0.62, zt), px, 0.02, RED_DK, right=(-1, 0, 0))
    left.text("SOON", (pcx + w2 / 2, top - 1.15, zt), px, 0.02, RED_DK, right=(-1, 0, 0))
    return [root.finalize(name, mat),
            _pivoted(left.finalize(name + "_RibbonR", mat), (-HOOK_X, HOOK_Y, ZR)),
            _pivoted(right.finalize(name + "_RibbonL", mat), (HOOK_X, HOOK_Y, ZR))]


def _flags(b, x0, x1, y, sag, z, k0, fh):
    """A swag of triangle flags from x0 to x1 hanging from a twine line."""
    pts = _sag(x0, x1, y, sag, 8)
    _strip(b, pts, 0.05, 0.05, z, "treat_tan")
    n = max(3, int(abs(x1 - x0) / 1.25))
    for k in range(n):
        t = (k + 0.5) / n
        x, yy = x0 + (x1 - x0) * t, y - sag * 4 * t * (1 - t)
        sw = PASTELS[(k0 + k) % len(PASTELS)]
        slope = math.degrees(math.atan(-sag * 4 * (1 - 2 * t) / (x1 - x0)))
        b.box((x, yy, z - 0.006), (0.9, 0.09, 0.09), sw, rot=rot_z(slope))         # the flag's hem, folded over the twine
        b.fan_z(z - 0.05 - 0.006 * (k % 2), (x, yy - fh), [(x - 0.5, yy + 0.02), (x + 0.5, yy + 0.02)], 0.03, sw)


def _balloons(b, x, side):
    """Three balloons on strings from a tie on the wall beside the door, floating up and out."""
    tie = (x, 6.4, FRONT - 0.08)
    b.span((x - 0.12, 6.3, FRONT - 0.16), (x + 0.12, 6.5, FRONT - 0.02), "brass")             # the tie's hook
    for k, (dx, dy, dz, r, sw) in enumerate(((side * 0.35, 3.1, -0.75, 0.62, "blush"),
                                              (side * 1.25, 2.55, -1.0, 0.56, "mint"),
                                              (side * 0.55, 1.95, -0.5, 0.52, "pastel_butter"))):
        c = Vector((x + dx, tie[1] + dy, FRONT + dz))
        s = c - Vector(tie) - Vector((0, r * 1.15, 0))
        mid = Vector(tie) + s / 2
        L = s.length
        R = Vector((0, 1, 0)).rotation_difference(s.normalized()).to_matrix()
        b.box(tuple(mid), (0.03, L, 0.03), "offwhite", rot=R)                                  # its string
        b.ball(tuple(c), r, sw, scale=(1, 1.18, 1))                                            # the balloon
        b.box((c.x, c.y - r * 1.18 - 0.04, c.z), (0.12, 0.1, 0.12), sw)                        # its knot
    return tie


def build_bunting(mat):
    name = "CatCafe_Plot_GrandOpeningBunting"
    b, lb, rb_ = RB(), RB(), RB()
    xs = (-HWI, -9.0, 0.0, 9.0, HWI)              # five hooks under the eave, the outer swags over the awnings (x 9..20)
    y, z = 12.55, FRONT - 0.55
    for x in xs:
        b.span((x - 0.07, y - 0.07, z - 0.03), (x + 0.07, y + 0.07, FRONT - 0.04), "brass")
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        inner = abs(x0 + x1) < 10                                      # the two over the door hang deeper
        _flags(b, x0, x1, y, 0.9 if inner else 0.12, z, 2 * i, 0.95 if inner else 0.78)
    dx = DOOR[1] + 1.3                                                                     # beside the door's frame
    tl = _balloons(lb, -dx, -1)
    tr = _balloons(rb_, dx, 1)
    return [b.finalize(name, mat), _pivoted(lb.finalize(name + "_LeftBalloons", mat), tl),
            _pivoted(rb_.finalize(name + "_RightBalloons", mat), tr)]


ASSETS = {
    "CatCafe_Plot_GrandOpeningRibbon": (build_ribbon, 3000),
    "CatCafe_Plot_GrandOpeningBunting": (build_bunting, 3000),
}
