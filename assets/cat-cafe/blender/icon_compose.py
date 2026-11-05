"""Lays out several existing pictures' models in one icon (icons.py): each builder's objects are moved, turned about
the up axis and scaled as one group, in Blender axes (x right, -y toward the camera, z up). The potion flasks'
invisible framing boxes are dropped, so the camera frames what shows. Nothing here is a game model."""

import math

import bpy
from mathutils import Matrix


def place(objs, at=(0.0, 0.0, 0.0), scale=1.0, yaw=0.0, tilt=0.0):
    """Move a builder's objects as one group: scale, tip `tilt` degrees about x, turn `yaw` degrees about z, then
    move by `at`. Returns the objects that stay (the potion frames are removed)."""
    bpy.context.view_layer.update()                         # a builder may have just set .location
    keep = []
    for ob in objs:
        if ob.name.startswith("CatCafe_IconArt_PotionFlask_Frame"):
            bpy.data.objects.remove(ob, do_unlink=True)
        else:
            keep.append(ob)
    m = (Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
         @ Matrix.Rotation(math.radians(tilt), 4, "X") @ Matrix.Scale(scale, 4))
    for ob in keep:
        if ob.parent is None or ob.parent not in keep:      # a child follows its parent
            ob.matrix_world = m @ ob.matrix_world
    bpy.context.view_layer.update()
    return keep
