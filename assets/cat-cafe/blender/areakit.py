"""Shared bits for the area kits (areas-and-stations.md Part A; Derek approved the draft sheets on 2026-10-27):
small builders the Neighbourhood, Woods and Sewer pieces share, and `compose`, which lays a kit out as one set
model in the area's own space so WorldBuilder places a whole area with one prop.

Area space is Roblox: origin at the area's centre on its floor, +Z toward the far wall, -Z toward the gate (the
Woods and Sewer gates are turned 180 degrees, so their sets are too). Pieces are built with common.Builder (Blender
axes, front -Y, which is Roblox -Z) and placed with `put(x, z, rot_y)` in Roblox numbers: rot_y is
CFrame.Angles(0, math.rad(rot_y), 0), so 90 turns a piece's front from -Z to -X.
"""

import math

import bpy
from mathutils import Matrix

import common

PI = math.pi
POINTS = {}         # set name -> {label: [(x, y, z), ...]} in area space; build_all writes it into the manifest
SUFFIXES = ("_Pane", "_Bulb", "_Bulbs", "_Glass", "_Water", "_Glow", "_Flowers", "_Decor", "_Lights", "_Tube", "_Climb")


def rx(d):
    return (math.radians(d), "X")


def ry(d):
    return (math.radians(d), "Y")


def rz(d):
    return (math.radians(d), "Z")


def gable(b, cx, cy, z0, w, d, h, wall, roof, over=0.6, thick=0.4):
    """Front-gable roof on a box w wide (x) and d deep (y) whose walls end at z0: a gable triangle in the wall
    colour, two roof slabs meeting at a ridge that runs front to back, and a ridge cap."""
    b.fan((cx, cy, z0), (0, h), [(-w / 2, 0), (w / 2, 0)], d, wall, rot=rx(90))
    a = math.atan2(h, w / 2)
    L = math.hypot(w / 2, h) + over
    for s in (-1, 1):
        out = (s * math.cos(a), -math.sin(a))
        nrm = (s * math.sin(a), math.cos(a))
        c = (cx + s * w / 4 + out[0] * over / 2 + nrm[0] * thick / 2, cy,
             z0 + h / 2 + out[1] * over / 2 + nrm[1] * thick / 2)
        b.box(c, (L, d + 2 * over, thick), roof, rot=ry(s * math.degrees(a)))
    b.box((cx, cy, z0 + h + 0.15), (0.5, d + 2 * over, 0.35), roof, bevel=False)


def window(b, panes, x, y, z, w, h, frame="offwhite", sill=True, cross=True):
    """A window on a wall facing -Y at depth y: frame, a pane on `panes` (a _Pane object, lit at night), a cross
    bar and a sill."""
    b.box((x, y - 0.06, z), (w + 0.4, 0.2, h + 0.4), frame, bevel=False)
    panes.box((x, y - 0.18, z), (w, 0.06, h), "glass", bevel=False)
    if cross:
        b.box((x, y - 0.24, z), (0.14, 0.05, h), frame, bevel=False)
        b.box((x, y - 0.245, z), (w, 0.04, 0.14), frame, bevel=False)
    if sill:
        b.box((x, y - 0.3, z - h / 2 - 0.25), (w + 0.7, 0.5, 0.2), frame, bevel=False)


def flowers(b, x, y, z, n=5, r=0.7, cols=("blush", "pastel_butter", "neon_pink", "pastel_lilac", "offwhite"), seed=0):
    for i in range(n):
        a = 2 * PI * (i + 0.3 * seed) / n + seed
        px, py = x + r * math.cos(a) * (0.5 + 0.5 * ((i * 7 + seed) % 3) / 2), y + r * math.sin(a) * 0.8
        b.box_base((px, py, z), (0.08, 0.08, 0.45), "leaf_dark", bevel=False)
        b.ico((px, py, z + 0.5), 0.2 + 0.01 * (i % 3), cols[(i + seed) % len(cols)], subdivisions=1)


def tree_round(b, x, y, z=0.0, h=7.0, r=2.6, leaf="leaf_green", trunk="fur_brown"):
    b.cyl_base((x, y, z), 0.45, h * 0.6, trunk, segments=8, radius2=0.35)
    b.ico((x, y, z + h * 0.72), r, leaf, subdivisions=1)
    b.ico((x + r * 0.6, y - r * 0.2, z + h * 0.62), r * 0.6, leaf, subdivisions=1)
    b.ico((x - r * 0.55, y + r * 0.3, z + h * 0.66), r * 0.62, leaf, subdivisions=1)


def ring_blocks(b, cx, cy, z0, r_out, thick, h, swatch, n=40):
    """A flat ring as n blocks (what Builder.ring exports as), with every other block 0.006 taller, so the
    overlapping corners of neighbours never share a top face (coplanar overlaps flicker and render black)."""
    rr = r_out - thick / 2
    chord = 2 * r_out * math.sin(PI / n) * 1.04
    for k in range(n):
        a = 2 * PI * (k + 0.5) / n
        b.box_base((cx + rr * math.cos(a), cy + rr * math.sin(a), z0), (thick, chord, h + 0.006 * (k % 2)), swatch,
                   bevel=False, rot=(a, "Z"))


def turned(x, z, rot_y, lx, lz):
    """Area position of (lx, lz) in the space of a piece standing at (x, z) turned rot_y (all Roblox)."""
    a = math.radians(rot_y)
    return x + lx * math.cos(a) + lz * math.sin(a), z - lx * math.sin(a) + lz * math.cos(a)


class Set:
    """Collects placed pieces for one area set. `put` builds nothing itself: pass the objects a piece builder
    returned, and it moves them into area space and bakes the move into their meshes."""

    def __init__(self, name):
        self.name = name
        self.objs = []
        self.count = 0
        self.points = {}                     # label -> list of (x, z) the set reports (spawn spots, traps)

    def put(self, objs, x, z, rot_y=0.0, y=0.0):
        bpy.context.view_layer.update()
        M = Matrix.Translation((-x, z, y)) @ Matrix.Rotation(math.radians(rot_y), 4, "Z")
        for ob in objs:
            ob.matrix_world = M @ ob.matrix_world
            common.bake_transform(ob)
            base = ob.name.split(".")[0]
            suffix = next((s for s in SUFFIXES if base.endswith(s)), "")
            piece = base[:len(base) - len(suffix)].split("_", 2)[-1]
            ob.name = f"{self.name}_{self.count:03d}_{piece}{suffix}"
            self.objs.append(ob)
        self.count += 1
        return objs

    def mark(self, label, x, z, y=0.0):
        """A spot the set reports (where a stray can sit): area-space x, z and the height it sits at above the
        set's base, so a cat on a porch or a trampoline is not buried in it."""
        self.points.setdefault(label, []).append((round(x, 2), round(y, 2), round(z, 2)))

    def finish(self, ground, mat):
        """The set's own object (named after the set: flat ground pieces) first, then every placed piece."""
        main = ground.finalize(self.name, mat)
        POINTS[self.name] = self.points
        return [main] + self.objs
