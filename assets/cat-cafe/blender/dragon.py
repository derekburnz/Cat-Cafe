"""Cinder, the Dragon Keep's dragon (#4062, Design-Agent's ticket-booth-and-dragon-keep.md sections 2.4 and 2.10;
Derek OK'd the Keep 2026-11-13 23:53 UTC). One model per stage, drawn on the owner's client by Motion-FX's Effects
code. They go in their own folder, ReplicatedStorage.Assets.Dragon (rbx/Dragon/); none has a script or collides.

  CatCafe_Dragon_Hatchling   stage 1: small and round, pastel scales, big eyes, an egg shell cap on his head
  CatCafe_Dragon_Whelp       stage 2: stubby wings and two little horns
  CatCafe_Dragon_Drake       stage 3: twice the size, real wings, a brighter chest
  CatCafe_Dragon_Elder       stage 4: a long neck, a crown of five horns, wings half spread
  CatCafe_Dragon_Crowned     stage 5: huge, a small gold crown and gems set in his scales

All five share one set of joints, so one animation set plays on every stage. A joint is a child Model whose pivot is
the hinge (the way a cat's Head and Tail are), named <Asset>_<Joint>:

  <Asset>                      the root: the belly and chest plates and the back spikes (the Body). Pivot at his feet on
    _Body_Scale                the floor, front -Z. Move the root and everything follows.
    _Chest_Glow                the ember in his chest (Neon)
    _Neck                      pivot at the base of the neck
      _Head                    pivot where the head meets the neck: eyes, horns (the shell cap or the crown)
        _Jaw                   pivot at the jaw hinge; open it by turning about X
        _Crown_Glow            Crowned only: the glint on the crown (Neon)
    _Tail1 > _Tail2 > _Tail3   each pivots at its own start
    _WingL, _WingR             pivot at the shoulder (not on the Hatchling); flap about Z
    _LegFL, _LegFR, _LegBL, _LegBR   pivot at the hip

Every joint's scales are its own child Model, <Joint>_Scale, and nothing else is in it: to give him another scale
colour (Ruby, Sapphire, Emerald, Amethyst from stage 3) set Color on every part whose name ends with "_Scale".
"""

import math

from common import RB
from plot import rot_x, rot_y, rot_z

RBX_DIR = "Dragon"                          # build_all writes these into rbx/Dragon/ (a Folder in Assets)
N = "CatCafe_Dragon_"
BELLY, HORN, CLAW, WHITE, PUPIL = "fur_custard", "fur_vanilla", "fur_cream", "milk", "fur_black"

# u: size (the body is 1.5u long); neck: its length in u; head: head size against the body; wings: 0 none, else the
# span of one wing in u; horns: how many; eye: eye size (the young ones' are bigger)
STAGES = {
    "Hatchling": dict(u=0.9, scale="fur_peach", membrane="fur_rose", neck=0.25, head=1.25, wings=0.0, horns=0,
                      eye=1.35, glow="lamp_warm", spikes=2, shell=True),
    "Whelp": dict(u=1.3, scale="nose_brick", membrane="fur_apricot", neck=0.4, head=1.1, wings=1.0, horns=2,
                  eye=1.15, glow="fur_orange", spikes=3),
    "Drake": dict(u=1.8, scale="shirt_red", membrane="fur_apricot", neck=0.6, head=0.95, wings=1.5, horns=2,
                  eye=1.0, glow="fur_orange", spikes=4, big_glow=True),
    "Elder": dict(u=2.2, scale="shirt_red", membrane="fur_apricot", neck=1.0, head=0.9, wings=1.6, horns=5,
                  eye=0.9, glow="fur_orange", spikes=5, big_glow=True, frills=True),
    "Crowned": dict(u=2.6, scale="shirt_red", membrane="fur_apricot", neck=1.05, head=0.9, wings=1.8, horns=5,
                    eye=0.9, glow="fur_orange", spikes=6, big_glow=True, frills=True, crown=True, gems=True),
}


class J:
    """One joint's object: an RB whose points are given in the dragon's own space and stored about its pivot."""

    def __init__(self, pivot=(0.0, 0.0, 0.0)):
        self.rb, self.o = RB(), pivot

    def _c(self, c):
        return tuple(a - b for a, b in zip(c, self.o))

    def box(self, c, s, sw, rot=None):
        self.rb.box(self._c(c), s, sw, rot=rot)

    def wedge(self, c, s, sw, rot=None):
        self.rb.wedge(self._c(c), s, sw, rot=rot)

    def done(self, name, mat):
        return self.rb.finalize(name, mat, location=self.o)


def _dragon(stage):
    S = STAGES[stage]
    u, sc = S["u"], S["scale"]
    name = N + stage

    def build(mat):
        out = []
        leg_h = 0.42 * u
        by = leg_h + 0.36 * u                                        # the body's centre height
        bw, bh, bl = 0.95 * u, 0.72 * u, 1.5 * u

        def pair(joint, pivot):
            a, b = J(pivot), J(pivot)
            out.append((a, name + "_" + joint))
            out.append((b, name + "_" + joint + "_Scale"))
            return a, b

        # ---- the body: the root holds the belly, chest plate and spikes; the scales are _Body_Scale
        root, body = J(), J()
        out.append((root, name))
        out.append((body, name + "_Body_Scale"))
        body.box((0, by, 0), (bw, bh, bl), sc)
        body.box((0, by + 0.05 * u, -0.05 * u), (bw + 0.12 * u, bh * 0.6, bl * 0.62), sc)      # rounder flanks
        body.box((0, by + bh * 0.5, 0.05 * u), (bw * 0.6, 0.12 * u, bl * 0.8), sc)             # the back's ridge
        root.box((0, by - bh / 2 - 0.02 * u, -0.02 * u), (bw * 0.72, 0.1 * u, bl * 0.9), BELLY)
        root.box((0, by - 0.08 * u, -bl / 2 - 0.03 * u), (bw * 0.7, bh * 0.7, 0.08 * u), BELLY)  # chest plate
        n = S["spikes"]
        for k in range(n):                                           # spikes down the back
            z = -bl * 0.3 + bl * 0.7 * k / max(1, n - 1)
            h = (0.2 - 0.02 * abs(k - n / 2)) * u
            root.box((0, by + bh / 2 + 0.1 * u + h / 2, z), (0.1 * u, h, 0.16 * u), HORN, rot=rot_x(-18))
        for sx in (-1, 1):                                           # shoulder and hip plates, a shade of belly
            for z in ((-bl * 0.3, bl * 0.3) if u >= 1.8 else ()):
                root.box((sx * (bw / 2 + 0.065 * u), by + 0.02 * u, z), (0.04 * u, 0.3 * u, 0.36 * u), BELLY,
                         rot=rot_x(45))
        if S.get("gems"):                                            # a gold chest piece
            root.box((0, by + bh * 0.22, -bl / 2 - 0.075 * u), (bw * 0.8, 0.12 * u, 0.05 * u), "gold_mid")
            root.box((0, by - bh * 0.38, -bl / 2 - 0.075 * u), (bw * 0.5, 0.1 * u, 0.05 * u), "gold_mid")
        if S.get("gems"):                                            # gems set in the scales (not scale parts)
            for k, (sx, y, z, sw) in enumerate(((1, 0.1, -0.35, "fish_blue"), (-1, 0.1, -0.35, "fish_blue"),
                                                (1, 0.12, 0.1, "eye_green"), (-1, 0.12, 0.1, "eye_green"),
                                                (1, 0.08, 0.5, "rarity_epic"), (-1, 0.08, 0.5, "rarity_epic"))):
                root.box((sx * (bw / 2 + 0.07 * u), by + y * u, z * u), (0.06 * u, 0.2 * u, 0.2 * u), sw,
                         rot=rot_x(45))
        glow = J((0, by - 0.08 * u, -bl / 2 - 0.08 * u))
        g = (0.42 if S.get("big_glow") else 0.26) * u
        glow.box((0, by - 0.08 * u, -bl / 2 - 0.085 * u), (g, g * 0.8, 0.05 * u), S["glow"], rot=rot_z(45))
        out.append((glow, name + "_Chest_Glow"))

        # ---- the neck, head and jaw
        nl = S["neck"] * u
        nb = (0.0, by + bh * 0.3, -bl / 2 + 0.12 * u)                # neck base
        lean = math.radians(35)
        nt = (0.0, nb[1] + nl * math.cos(lean), nb[2] - nl * math.sin(lean))   # neck top
        neck, neck_s = pair("Neck", nb)
        nw = 0.5 * u
        mid = tuple((a + b) / 2 for a, b in zip(nb, nt))
        neck_s.box(mid, (nw, nl + 0.3 * u, nw), sc, rot=rot_x(-35))
        neck.box((mid[0], mid[1] - 0.12 * u, mid[2] - nw * 0.42), (nw * 0.62, nl + 0.1 * u, 0.08 * u), BELLY,
                 rot=rot_x(-35))
        hs = S["head"] * u
        hw_, hh, hl = 0.72 * hs, 0.6 * hs, 0.7 * hs
        hc = (0.0, nt[1] + hh * 0.35, nt[2] - hl * 0.25)             # head centre
        head, head_s = pair("Head", nt)
        head_s.box(hc, (hw_, hh, hl), sc)
        sl = 0.5 * hs                                                # snout
        sn = (0.0, hc[1] - hh * 0.12, hc[2] - hl / 2 - sl / 2 + 0.04 * hs)
        head_s.box(sn, (hw_ * 0.7, hh * 0.42, sl), sc)
        for sx in (-1, 1):
            e = 0.2 * hs * S["eye"]
            ex = sx * (hw_ / 2 - e * 0.35)
            ez = hc[2] - hl / 2 - 0.012 * hs
            head.box((ex, hc[1] + hh * 0.12, ez), (e, e * 1.15, 0.03 * hs), WHITE)
            head.box((ex - sx * e * 0.1, hc[1] + hh * 0.1, ez - 0.012 * hs), (e * 0.55, e * 0.75, 0.03 * hs), PUPIL)
            head.box((sx * hw_ * 0.18, sn[1] + hh * 0.22, sn[2] - sl * 0.3), (0.06 * hs, 0.04 * hs, 0.06 * hs), PUPIL)
            head.box((sx * (hw_ / 2 + 0.02 * hs), hc[1] - hh * 0.05, hc[2] - hl * 0.2), (0.04 * hs, 0.1 * hs, 0.14 * hs),
                     "blush")                                        # cheeks: he stays friendly at every size
        horns = S["horns"]
        spots = {0: (), 2: ((-1, 0.0), (1, 0.0)), 5: ((-1, 0.0), (1, 0.0), (-0.55, 0.12), (0.55, 0.12), (0, 0.2))}[horns]
        for hx, extra in spots:
            hh2 = (0.3 + extra) * hs
            head.box((hx * hw_ * 0.36, hc[1] + hh / 2 + hh2 * 0.4, hc[2] + hl * 0.3 + 0.03 * hs * abs(hx)),
                     (0.11 * hs, hh2, 0.11 * hs), HORN, rot=rot_x(28) @ rot_z(-hx * 12))
        if S.get("frills"):                                          # the old dragon's cheek frills and chin spike
            for sx in (-1, 1):
                for k in range(3):
                    head.box((sx * (hw_ / 2 + 0.05 * hs), hc[1] + (0.14 - 0.14 * k) * hs, hc[2] + hl * 0.34),
                             (0.05 * hs, 0.1 * hs, (0.34 - 0.06 * k) * hs), S["membrane"], rot=rot_y(-sx * 28))
        if S.get("shell"):                                           # the egg shell cap
            top = hc[1] + hh / 2
            head.box((0, top + 0.06 * hs, hc[2]), (hw_ * 0.86, 0.12 * hs, hl * 0.86), "pearl")
            head.box((0, top + 0.16 * hs, hc[2]), (hw_ * 0.6, 0.1 * hs, hl * 0.6), "pearl")
            for k, (x, z) in enumerate(((-0.3, -0.3), (0.3, -0.3), (-0.3, 0.3), (0.3, 0.3), (0, -0.38), (0, 0.38))):
                head.box((x * hw_, top - 0.02 * hs, hc[2] + z * hl), (0.14 * hs, 0.12 * hs, 0.14 * hs), "pearl",
                         rot=rot_y(45))
        if S.get("crown"):
            top = hc[1] + hh / 2
            cz = hc[2] - hl * 0.12
            head.box((0, top + 0.07 * hs, cz), (0.5 * hs, 0.14 * hs, 0.5 * hs), "gold_mid")
            for k in range(8):
                a = math.radians(45 * k)
                tall = 0.26 if k % 2 == 0 else 0.16
                head.box((0.21 * hs * math.cos(a), top + 0.14 * hs + tall * hs / 2, cz + 0.21 * hs * math.sin(a)),
                         (0.1 * hs, tall * hs, 0.1 * hs), "gold_light")
            for k in range(4):
                a = math.radians(90 * k)
                head.box((0.255 * hs * math.cos(a), top + 0.07 * hs, cz + 0.255 * hs * math.sin(a)),
                         (0.09 * hs, 0.09 * hs, 0.09 * hs), "rarity_mythic", rot=rot_y(-90 * k) @ rot_x(45))
            gl = J((0, top + 0.52 * hs, cz))
            gl.box((0, top + 0.52 * hs, cz), (0.14 * hs, 0.14 * hs, 0.14 * hs), "sparkle", rot=rot_x(45) @ rot_z(45))
            out.append((gl, name + "_Crown_Glow"))
        jp = (0.0, sn[1] - hh * 0.2, hc[2] - hl / 2 + 0.06 * hs)     # jaw hinge
        jaw, jaw_s = pair("Jaw", jp)
        jaw_s.box((0, jp[1] - 0.06 * hs, jp[2] - sl * 0.45), (hw_ * 0.62, 0.11 * hs, sl * 0.95), sc)
        jaw.box((0, jp[1] + 0.005 * hs, jp[2] - sl * 0.45), (hw_ * 0.4, 0.03 * hs, sl * 0.7), "nose_pink")   # tongue
        if S.get("frills"):
            jaw.box((0, jp[1] - 0.17 * hs, jp[2] - sl * 0.3), (0.1 * hs, 0.16 * hs, 0.1 * hs), HORN, rot=rot_x(-20))
        for sx in (-1, 1):                                           # two little teeth
            jaw.box((sx * hw_ * 0.24, jp[1] + 0.035 * hs, jp[2] - sl * 0.82), (0.06 * hs, 0.08 * hs, 0.06 * hs), WHITE)

        # ---- the tail, three joints tapering back
        z0 = bl / 2 - 0.05 * u
        ty = by + 0.02 * u
        for k, (ln, th) in enumerate(((0.6, 0.42), (0.55, 0.3), (0.5, 0.18)), start=1):
            ln, th = ln * u, th * u
            t, t_s = pair("Tail%d" % k, (0.0, ty, z0))
            t_s.box((0, ty, z0 + ln / 2), (th, th, ln + 0.06 * u), sc)
            t.box((0, ty + th / 2 + 0.05 * u, z0 + ln / 2), (0.08 * u, 0.12 * u, 0.14 * u), HORN, rot=rot_x(-18))
            if S.get("gems") and k < 3:                              # a gold ring round each tail joint
                t.box((0, ty, z0 + 0.1 * u), (th + 0.07 * u, th + 0.07 * u, 0.1 * u), "gold_mid")
            if k == 3:                                               # the tail's tip
                t.box((0, ty, z0 + ln + 0.1 * u), (0.3 * u, 0.08 * u, 0.3 * u), HORN, rot=rot_y(45))
            z0 += ln
            ty -= 0.06 * u

        # ---- the legs
        for nm, sx, z in (("LegFL", 1, -bl * 0.3), ("LegFR", -1, -bl * 0.3), ("LegBL", 1, bl * 0.3),
                          ("LegBR", -1, bl * 0.3)):
            x = sx * (bw / 2 - 0.1 * u)
            leg, leg_s = pair(nm, (x, leg_h + 0.06 * u, z))
            lw = (0.34 if "B" in nm else 0.3) * u
            leg_s.box((x, leg_h / 2 + 0.05 * u, z), (lw, leg_h + 0.1 * u, lw * 1.1), sc)
            leg_s.box((x, 0.06 * u, z - 0.08 * u), (lw * 1.05, 0.12 * u, lw * 1.5), sc)       # the foot
            for dx in (-0.1, 0.1):
                leg.box((x + dx * u, 0.04 * u, z - 0.08 * u - lw * 0.78), (0.07 * u, 0.08 * u, 0.08 * u), CLAW)

        # ---- the wings (not on the Hatchling): an arm of scales and a three-panel membrane, half spread
        if S["wings"]:
            span = S["wings"] * u
            for nm, sx in (("WingL", 1), ("WingR", -1)):
                sh = (sx * bw * 0.32, by + bh / 2 + 0.02 * u, -bl * 0.18)
                w, w_s = pair(nm, sh)
                R = rot_z(sx * 22)                                    # the arm rises outward
                ax = math.cos(math.radians(22)) * span
                ay = math.sin(math.radians(22)) * span
                w_s.box((sh[0] + sx * ax / 2, sh[1] + ay / 2, sh[2]), (span, 0.12 * u, 0.14 * u), sc, rot=R)
                for k, (f, ln) in enumerate(((0.17, 0.5), (0.5, 0.78), (0.83, 0.6))):
                    px, py = sh[0] + sx * ax * f, sh[1] + ay * f
                    w.box((px, py - 0.02 * u, sh[2] + ln * span / 2), (span * 0.34, 0.04 * u, ln * span),
                          S["membrane"], rot=R)
                    if S["wings"] >= 1.5:                             # a finger of scales down each panel's edge
                        w_s.box((px + sx * span * 0.165, py + 0.01 * u, sh[2] + ln * span / 2),
                                (0.06 * u, 0.07 * u, ln * span), sc, rot=R)
                w.box((sh[0] + sx * ax, sh[1] + ay + 0.04 * u, sh[2]), (0.09 * u, 0.2 * u, 0.09 * u), HORN, rot=R)
        return [j.done(nm, mat) for j, nm in out]

    build.name = name
    return build


JOINTS = ("Neck", "Head", "Jaw", "Tail1", "Tail2", "Tail3", "WingL", "WingR", "LegFL", "LegFR", "LegBL", "LegBR")
# rbx_export nesting (the longest suffix wins): the chain, and each joint's scales inside the joint
NEST = {"_Head": "_Neck", "_Jaw": "_Head", "_Crown_Glow": "_Head", "_Tail2": "_Tail1", "_Tail3": "_Tail2",
        **{"_%s_Scale" % j: "_" + j for j in JOINTS}}
ASSETS = {N + s: (_dragon(s), 4000) for s in STAGES}
