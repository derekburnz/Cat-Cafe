"""Shared helpers for the Cat Cafe Blender generators.

Works both as a script inside Blender (blender -b -P build_all.py) and with the
`bpy` pip module (python build_all.py). Units: 1 Blender unit = 1 stud.
"""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import palette

BEVEL = 0.06          # stud, see style guide section 3
BEVEL_SEGMENTS = 1   # one-segment chamfer reads as soft at Roblox scale and keeps tris low
UP = Vector((0, 0, 1))


# ---------------------------------------------------------------- scene -----
def reset_scene():
    """Empty scene with Roblox-friendly units (Unit Scale 0.01, cm)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 0.01
    sc.unit_settings.length_unit = "CENTIMETERS"
    sc.render.engine = "CYCLES"
    return sc


def palette_material(png_path):
    """The one material every mesh uses: palette PNG into Base Color."""
    mat = bpy.data.materials.get(palette.TEXTURE_NAME)
    if mat:
        return mat
    img = bpy.data.images.get(palette.TEXTURE_NAME) or palette.write_palette_png(png_path)
    mat = bpy.data.materials.new(palette.TEXTURE_NAME)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.65
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    tex.location = (-400, 300)
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# -------------------------------------------------------------- builder -----
def _mat(center, size=(1, 1, 1), rot=None):
    """Translation @ rotation @ scale. rot = (angle_rad, 'X'|'Y'|'Z') or a Matrix."""
    m = Matrix.Translation(Vector(center))
    if rot is not None:
        if isinstance(rot, Matrix):
            m = m @ rot.to_4x4()
        else:
            m = m @ Matrix.Rotation(rot[0], 4, rot[1])
    return m @ Matrix.Diagonal((*size, 1.0))


class Builder:
    """Accumulates primitives into one mesh, tagging each face with a swatch.

    Every primitive goes in with a swatch name (palette.py) and a bevel flag.
    finalize() bevels tagged edges, writes UVs to swatch centers, sets flat
    shading and returns a Blender object whose origin is the build origin, so
    build everything relative to the pivot you want (base center, floor).
    """

    def __init__(self):
        self.bm = bmesh.new()
        self.sw = self.bm.faces.layers.int.new("swatch")
        self.bev = self.bm.edges.layers.int.new("bev")

    # -- tagging ------------------------------------------------------------
    def _tag(self, verts, swatch, bevel):
        i = palette.idx(swatch)
        faces, edges = set(), set()
        for v in verts:
            faces.update(v.link_faces)
            edges.update(v.link_edges)
        for f in faces:
            f[self.sw] = i
        for e in edges:
            e[self.bev] = 1 if bevel else 0
        return verts

    # -- primitives ---------------------------------------------------------
    def box(self, center, size, swatch, bevel=True, rot=None):
        """Axis-aligned box. center=(x,y,z) of the box center, size=(w,d,h)."""
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=_mat(center, size, rot))
        return self._tag(r["verts"], swatch, bevel)

    def box_base(self, base_center, size, swatch, bevel=True, rot=None):
        """Box standing on base_center (its bottom face center)."""
        c = (base_center[0], base_center[1], base_center[2] + size[2] / 2)
        return self.box(c, size, swatch, bevel, rot)

    def cyl(self, center, radius, height, swatch, segments=12, bevel=True, rot=None, radius2=None, scale=(1, 1, 1)):
        """Vertical cylinder (or cone when radius2 given) centered at center.
        radius is the bottom radius, radius2 the top. scale squashes it (ellipses)."""
        r2 = radius if radius2 is None else radius2
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                  radius1=radius, radius2=r2, depth=height,
                                  matrix=_mat(center, scale, rot))
        return self._tag(r["verts"], swatch, bevel)

    def cyl_base(self, base_center, radius, height, swatch, segments=12, bevel=True, radius2=None, scale=(1, 1, 1)):
        c = (base_center[0], base_center[1], base_center[2] + height / 2)
        return self.cyl(c, radius, height, swatch, segments, bevel, None, radius2, scale)

    def sphere(self, center, radius, swatch, segments=10, rings=6, scale=(1, 1, 1)):
        r = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=radius,
                                      matrix=_mat(center, scale))
        return self._tag(r["verts"], swatch, False)

    def ico(self, center, radius, swatch, subdivisions=1, scale=(1, 1, 1)):
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius,
                                       matrix=_mat(center, scale))
        return self._tag(r["verts"], swatch, False)

    def pyramid(self, base_center, size, height, swatch, bevel=False, rot=None):
        """Square pyramid standing on base_center. size = base width."""
        c = (base_center[0], base_center[1], base_center[2] + height / 2)
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=4,
                                  radius1=size / math.sqrt(2), radius2=0.0, depth=height,
                                  matrix=_mat(c, (1, 1, 1), rot) @ Matrix.Rotation(math.radians(45), 4, "Z"))
        return self._tag(r["verts"], swatch, bevel)

    def wedge(self, center, size, swatch, bevel=True, rot=None):
        """Triangular prism: right triangle in the Y/Z plane, extruded along X.
        Flat bottom, vertical back (+Y), slope facing -Y. size=(w,d,h)."""
        w, d, h = size
        pts = [(-w / 2, -d / 2, -h / 2), (w / 2, -d / 2, -h / 2), (w / 2, d / 2, -h / 2), (-w / 2, d / 2, -h / 2),
               (w / 2, d / 2, h / 2), (-w / 2, d / 2, h / 2)]
        m = _mat(center, (1, 1, 1), rot)
        vs = [self.bm.verts.new(m @ Vector(p)) for p in pts]
        for idxs in [(0, 1, 2, 3), (3, 2, 4, 5), (0, 3, 5), (1, 4, 2), (0, 5, 4, 1)]:
            self.bm.faces.new([vs[i] for i in idxs])
        self.bm.normal_update()
        bmesh.ops.recalc_face_normals(self.bm, faces=list({f for v in vs for f in v.link_faces}))
        return self._tag(vs, swatch, bevel)

    def ring(self, center, radius, thickness, height, swatch, segments=12, bevel=True, rot=None):
        """Ring (washer) lying flat in XY, `height` thick along Z: outer radius, inner radius-thickness.
        rot=(angle,'X') tips it, e.g. (pi/2,'X') for a collar standing in the XZ plane."""
        base = _mat(center, (1, 1, 1), rot) @ Matrix.Translation((0, 0, -height / 2))
        geom = bmesh.ops.create_circle(self.bm, cap_ends=False, segments=segments, radius=radius, matrix=base)
        outer = geom["verts"]
        inner = bmesh.ops.create_circle(self.bm, cap_ends=False, segments=segments, radius=radius - thickness,
                                        matrix=base)["verts"]
        edges = [e for v in outer + inner for e in v.link_edges]
        edges = list(dict.fromkeys(edges))
        bmesh.ops.bridge_loops(self.bm, edges=edges)
        faces = set(f for v in outer + inner for f in v.link_faces)
        r = bmesh.ops.extrude_face_region(self.bm, geom=list(faces))
        new_verts = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
        up = (base.to_3x3() @ Vector((0, 0, height)))
        bmesh.ops.translate(self.bm, vec=up, verts=new_verts)
        allv = outer + inner + new_verts
        bmesh.ops.recalc_face_normals(self.bm, faces=list(set(f for v in allv for f in v.link_faces)))
        return self._tag(allv, swatch, bevel)

    # -- finish -------------------------------------------------------------
    def finalize(self, name, mat, bevel=BEVEL, location=(0, 0, 0)):
        bm = self.bm
        bev_edges = [e for e in bm.edges if e[self.bev]]
        if bev_edges and bevel > 0:
            bmesh.ops.bevel(bm, geom=bev_edges, offset=bevel, offset_type="OFFSET",
                            segments=BEVEL_SEGMENTS, profile=0.7, affect="EDGES", clamp_overlap=True)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            u, v = palette.uv_center(f[self.sw])
            for l in f.loops:
                l[uv].uv = (u, v)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        ob.location = location
        bpy.context.scene.collection.objects.link(ob)
        return ob


# -------------------------------------------------------------- metrics -----
def tri_count(objs):
    if isinstance(objs, bpy.types.Object):
        objs = [objs]
    return sum(len(p.vertices) - 2 for ob in objs for p in ob.data.polygons)


def bounds(objs):
    """World-space (min, max) over objects' mesh vertices."""
    bpy.context.view_layer.update()   # fresh objects have a stale matrix_world until this
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        mw = ob.matrix_world
        for v in ob.data.vertices:
            w = mw @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


# --------------------------------------------------------------- export -----
def _select_only(objs):
    for ob in bpy.context.scene.objects:
        ob.select_set(ob in objs)
    bpy.context.view_layer.objects.active = objs[0]


def export_asset(objs, name, out_dir, glb=True):
    """Write <out_dir>/<name>.fbx (and .glb). Style guide section 10 settings."""
    os.makedirs(out_dir, exist_ok=True)
    _select_only(objs)
    fbx = os.path.join(out_dir, name + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS", global_scale=1.0,
        axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_mesh_modifiers=True,
        add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True,
        use_custom_props=False, use_triangles=False,
    )
    paths = [fbx]
    if glb:
        g = os.path.join(out_dir, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=g, use_selection=True, export_format="GLB",
                                  export_yup=True, export_apply=True, export_animations=False,
                                  export_skins=False, export_morph=False)
        paths.append(g)
    return paths


# --------------------------------------------------------------- render -----
def _ensure_floor(color_name="floor_tile", size=400):
    if bpy.data.objects.get("_PreviewFloor"):
        return
    me = bpy.data.meshes.new("_PreviewFloor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new("_PreviewFloor")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*palette.rgb_linear(color_name), 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    me.materials.append(mat)
    ob = bpy.data.objects.new("_PreviewFloor", me)
    ob.location = (0, 0, -0.001)
    bpy.context.scene.collection.objects.link(ob)


def _ensure_lights(warm=True):
    if bpy.data.objects.get("_Key"):
        bpy.data.lights["_Key"].color = (1.0, 0.93, 0.85) if warm else (0.85, 0.9, 1.0)
        bg = bpy.context.scene.world.node_tree.nodes.get("Background")
        bg.inputs["Color"].default_value = (0.9, 0.86, 0.8, 1) if warm else (0.3, 0.36, 0.5, 1)
        return
    key = bpy.data.lights.new("_Key", "SUN")
    key.energy = 3.0
    key.angle = math.radians(8)
    key.color = (1.0, 0.93, 0.85) if warm else (0.85, 0.9, 1.0)
    ko = bpy.data.objects.new("_Key", key)
    ko.rotation_euler = (math.radians(50), math.radians(-15), math.radians(35))
    bpy.context.scene.collection.objects.link(ko)
    fill = bpy.data.lights.new("_Fill", "AREA")
    fill.energy = 400
    fill.size = 12
    fo = bpy.data.objects.new("_Fill", fill)
    fo.location = (-8, -6, 8)
    fo.rotation_euler = (math.radians(45), 0, math.radians(-55))
    bpy.context.scene.collection.objects.link(fo)
    w = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.9, 0.86, 0.8, 1) if warm else (0.3, 0.36, 0.5, 1)
    bg.inputs["Strength"].default_value = 0.6


def render_preview(objs, path, res=(640, 480), samples=32, azimuth=35, elevation=22, warm=True, margin=1.15,
                   floor=True):
    """Three-quarter view of objs, auto-framed, Cycles CPU."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    if floor:
        _ensure_floor()
    fl = bpy.data.objects.get("_PreviewFloor")
    if fl:
        fl.hide_render = not floor
    _ensure_lights(warm)
    lo, hi = bounds(objs)
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.5)
    cam = bpy.data.objects.get("_Cam")
    if cam is None:
        cd = bpy.data.cameras.new("_Cam")
        cd.lens = 50
        cam = bpy.data.objects.new("_Cam", cd)
        sc.collection.objects.link(cam)
    sc.camera = cam
    az, el = math.radians(azimuth), math.radians(elevation)
    direction = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    fov = cam.data.angle_y if res[0] >= res[1] else cam.data.angle_x
    dist = radius * margin / math.sin(fov / 2)
    cam.location = center + direction * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    hidden = []
    for ob in sc.objects:
        if ob.type == "MESH" and ob not in objs and not ob.name.startswith("_"):
            if not ob.hide_render:
                ob.hide_render = True
                hidden.append(ob)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for ob in hidden:
        ob.hide_render = False
    return path


def hide_all_meshes():
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH" and not ob.name.startswith("_"):
            ob.hide_render = True


def show(objs):
    for ob in objs:
        ob.hide_render = False
