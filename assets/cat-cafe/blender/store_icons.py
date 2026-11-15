"""Store pictures for the game passes and developer products (#1623, docs/growth/store-skus.md section 1), rendered
by icons.py as CatCafe_Icon_Pass_<Name> and CatCafe_Icon_Product_<Name> (transparent, outlined, 512 px). Roblox
crops pass and product icons to a circle, so icons.py fits each one to that circle (STORE_FIT): the art is as big as
it can be with every point inside the crop. One picture serves the Creator Hub icon and the in-game Store card.

Passes
  Money2x, Money3x, Money4x  the gold coin stack (icon_art.coins) with a cream tag reading x2, x3 or x4
  LongNap         a ginger cat curled up asleep on a night-blue cushion, a gold alarm clock, big Zs (#1738)
  VIP             a gold plate reading VIP with a cream crest and a gold paw on top
  Accessories     a cream cat in a bow tie and a straw boater drawn big, a spare beret and a pink ribbon bow beside her
  Uniforms        a ginger barista cat in the apron and cap
  CafeStyle       the Garden Cafe front (themes.py's palette): sage and warm white striped awning, a brass cat
                  sign, a terracotta trough of flowers under a cake in the window
  GrandTheme      the grand cafe front: gold columns, a berry pediment with the cat sign, a big gold crown on top,
                  a gold awning over cakes in the windows
  ExtraSlot       a tuxedo cat in an apron on a cafe stool with a big mint +1 tag (one more cat at work)
  RoyalCat        Duchess Marzipan (the Royal Cat) in a big pearl-and-gold tiara, gold stars
  KingCat         King Croissant on his own, drawn big like the Royal Cat, a big Mythical pink star and a gold one
                  (#2180)
  KingPack        King Croissant on his red velvet cushion throne (shopcats.py)
  GoldenPond      a little stone pond with lily pads and a golden fish leaping out
  SecondBaitBowl  two food bowls heaped with kibble, a +1 tag on the second
  SignStylePack   three small sign plates fanned out like cards, one per style in the pack (#1860): Flower Box (white
                  board, mint frame, a box of flowers under it), Starry Night (navy, gold frame, gold stars and a moon)
                  in front, Paw Chalkboard (green slate, wooden frame, chalk paws)
  GardenDecorPack a little flower bed on a grass mound (#1860): pink, yellow, white and lilac flowers, a tall
                  sunflower and leaves in dark soil, with a tiny white picket fence across the front
  Jukebox         a little retro jukebox (#1867): a berry body with gold trim, its record in the arched top under
                  gold, pink and mint light bands, a song strip of buttons, a speaker, and music notes round it
Products
  StarterBundle   the pink gift box with Sprinkles, a Big Money and a Swift Potion, and a striped little sign
  PotionXS        2 Big Money Potions
  PotionS         5 big bottles in a low wicker basket (3 Big Money, a Swift, a Steady Paw)
  PotionM         a low wooden crate of 10 big bottles
  PotionL         a wide crate of 18 bottles and 2 bonus ones on top, with a pink bow on it
  CafePass        a season badge: a gold rosette with a berry centre, a paw and a star, two ribbon tails
  SteadyPawPack   a low wooden crate of 10 Steady Paw jars with a round mint tag and a white paw on its front (#1867)
  StarterPopup    (CatCafe_Icon_StarterPopup) the Starter Bundle pop-up card's picture: Sprinkles in its Epic look,
                  the three potions and the 2x money coins, on a soft warm glow
  ThankYouBadge   a gold heart badge (the supporter's gold heart) with a cream paw, pink ribbon tails, twinkles (#1867)

Built in Blender axes (x right, -y toward the camera, z up); nothing here is a game model.
"""

import math

from mathutils import Matrix, Vector

import accessories
import cats
import hud_icons
import icon_art
import poses
import potion_icons
import shopcats
from common import GLYPHS, Builder
from icon_compose import place

X = (math.radians(90), "X")
INK = "fur_charcoal"
# block digits and signs for the tags (common.GLYPHS has the letters)
SIGNS = {
    "1": ("010", "110", "010", "010", "111"), "2": ("111", "001", "111", "100", "111"),
    "3": ("111", "001", "111", "001", "111"), "4": ("101", "101", "111", "001", "001"),
    "+": ("000", "010", "111", "010", "000"),
}


def _text(b, s, cx, y, zb, px, depth, sw):
    """Block letters standing in the XZ plane, centred on x = cx, bottom at zb, their front face at y."""
    gl = {**GLYPHS, **SIGNS}
    widths = [len(gl[ch][0]) for ch in s]
    cur = cx - (sum(widths) + len(s) - 1) * px / 2
    for ch, w in zip(s, widths):
        for row, bits in enumerate(gl[ch]):
            for col, bit in enumerate(bits):
                if bit == "1":
                    c = (cur + (col + 0.5) * px, y + depth / 2, zb + (4 - row + 0.5) * px)
                    b.box(c, (px * 1.02, depth, px * 1.02), sw, bevel=False)
        cur += (w + 1) * px


def _tag(b, s, cx, cz, r, ink="royal_berry", disc="cream", y=-0.6):
    """A round tag facing the camera at (cx, y, cz), r across its radius, with `s` on it."""
    b.cyl((cx, y + 0.06, cz), r + 0.07, 0.1, "gold_mid", segments=24, rot=X)
    b.cyl((cx, y, cz), r, 0.1, disc, segments=24, rot=X)
    px = min(r * 1.25 / 5, r * 1.5 / ((sum(len({**GLYPHS, **SIGNS}[c][0]) for c in s) + len(s) - 1)))
    _text(b, s, cx, y - 0.08, cz - 2.5 * px, px, 0.06, ink)


def _star(b, x, y, z, s, sw="rarity_legend"):
    b.star((x, y, z), s, s * 0.45, 0.06, sw, rot=X)


def _twinkle(b, x, y, z, s, sw="offwhite"):
    """A four-pointed twinkle facing the camera."""
    pts = []
    for k in range(9):
        a = math.radians(90 + 45 * k)
        r = s / 2 if k % 2 == 0 else s * 0.12
        pts.append((r * math.cos(a), r * math.sin(a)))
    b.fan((x, y, z), (0, 0), pts, 0.05, sw, rot=X)


def _paw(b, x, y, z, s, sw):
    """A paw print facing the camera."""
    b.cyl((x, y, z - 0.05 * s), 0.26 * s, 0.05, sw, segments=14, rot=X)
    for (dx, dz) in ((-0.27, 0.2), (-0.1, 0.34), (0.1, 0.34), (0.27, 0.2)):
        b.cyl((x + dx * s, y, z + dz * s), 0.09 * s, 0.05, sw, segments=10, rot=X)


def _fin(b, name, mat):
    return [b.finalize("CatCafe_IconArt_Store_" + name, mat)]


# --- cats ---------------------------------------------------------------------------------------------------------

ACCESSORY_BUILDS = {"BowTie": accessories.build_bow_tie, "Boater": accessories.build_boater,
                    "Apron": accessories.build_apron, "BaristaCap": accessories.build_barista_cap,
                    "Vest": accessories.build_vest, "Sash": accessories.build_sash,
                    "Glasses": accessories.build_glasses, "TailBow": accessories.build_tail_bow}


def _cat(name, mat, body="sit", dress=(), pose=None, grow=1.0):
    """A roster cat, optionally in role pieces (accessories.slots) and a poses.CAT_POSES pose. `grow` draws the worn
    pieces bigger than life, each about its own slot point, so they read at Store tile size."""
    spec = cats.ROSTER[name]
    objs = cats.build_cat(name, mat, body=body)
    built = {f"CatCafe_Accessory_{n}": ACCESSORY_BUILDS[n](mat) for n in dress}
    pz = poses.CAT_POSES[pose] if pose else None
    worn = poses.accessory_copies(built, objs, spec, body, list(dress), pose=pz) if dress else []
    if pz:
        posed = poses.cat_pose_copies(objs, pz, spec, body)
        poses.cleanup(objs)
        objs = posed
    for src in built.values():
        poses.cleanup(src)
    for ob in worn:
        ob.matrix_world = ob.matrix_world @ Matrix.Scale(grow, 4)
    return objs + worn


def _crop(objs, z_cut):
    """#2578: cut the group off below the world height z_cut (a bust cropped at the chest, a stool at its seat). Each
    mesh gets its own copy first; a piece wholly below the cut is removed. The cut is left open: the camera looks down
    on the picture, so it never sees inside."""
    import bmesh
    import bpy
    bpy.context.view_layer.update()
    keep = []
    for ob in objs:
        if ob.type != "MESH":
            keep.append(ob)
            continue
        if max((ob.matrix_world @ Vector(c)).z for c in ob.bound_box) <= z_cut:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        if min((ob.matrix_world @ Vector(c)).z for c in ob.bound_box) >= z_cut:
            keep.append(ob)
            continue
        ob.data = ob.data.copy()
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        M = ob.matrix_world
        co = M.inverted() @ Vector((0.0, 0.0, z_cut))
        no = (M.to_3x3().transposed() @ Vector((0.0, 0.0, 1.0))).normalized()
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no,
                               clear_inner=True)
        bm.to_mesh(ob.data)
        bm.free()
        if len(ob.data.vertices):
            keep.append(ob)
        else:
            bpy.data.objects.remove(ob, do_unlink=True)
    return keep


def _dressed(name, mat, pieces, look=None, grow=1.0, body="sit"):
    """A roster cat wearing `pieces`, recoloured to a uniform style's (main, trim) the way the game does it."""
    objs = _cat(name, mat, body=body, dress=pieces, grow=grow)
    if look:
        from pass_reward_icons import recolour
        for ob in objs:
            if ob.name.startswith("_v_CatCafe_Accessory_"):
                recolour(ob, *look)
    return objs


def _top(objs):
    """(x, y, z) of the middle of the group's top, in world space."""
    import bpy
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for ob in objs for c in ob.bound_box]
    return (sum(p.x for p in pts) / len(pts), sum(p.y for p in pts) / len(pts), max(p.z for p in pts))


# --- passes -------------------------------------------------------------------------------------------------------

def money(mark):
    def build(mat):
        coins = place(icon_art.coins(mat), at=(-0.25, 0.3, 0.0))
        b = Builder()
        _tag(b, "X" + mark, 0.95, 0.35, 0.62, y=-1.0)
        return coins + _fin(b, "Money" + mark, mat)
    return build


def long_nap(mat):
    """#1738 (Derek2 11-06: "make a better image for long nap pass thats more obvious"): a ginger cat curled up asleep
    on a night-blue cushion, a big gold alarm clock behind it and a tall stack of white Zs rising off it, so the card
    reads as "sleep longer" at tile size."""
    b = Builder()
    b.sphere((0, 0, 0.3), 1.0, "pants_navy", segments=24, rings=12, scale=(1.3, 0.95, 0.3))   # the cushion
    b.cyl((0, 0, 0.3), 1.31, 0.08, "gold_mid", segments=28, scale=(1.0, 0.73, 1.0))          # its gold piping
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.ico((sx * 1.2, sy * 0.84, 0.3), 0.13, "gold_mid")                                # corner tufts
    # the alarm clock, standing behind the cat at the right
    cx, cy, cz, R = 0.95, 0.75, 1.55, 0.7
    b.cyl((cx, cy, cz), R, 0.4, "gold_mid", segments=28, rot=X)                                 # its case
    b.cyl((cx, cy - 0.21, cz), R - 0.12, 0.04, "cream", segments=28, rot=X)                    # the face
    for k in range(12):                                                                       # the hour marks
        a = math.radians(90 - 30 * k)
        L = 0.13 if k % 3 == 0 else 0.07
        r = R - 0.2 - L / 2
        b.box((cx + r * math.cos(a), cy - 0.24, cz + r * math.sin(a)), (0.05, 0.03, L), "fur_black", bevel=False,
              rot=(math.radians(30 * k), "Y"))
    b.box((cx, cy - 0.27, cz + 0.17), (0.07, 0.03, 0.36), "fur_black", bevel=False)            # hour hand: 12
    b.box((cx + 0.16, cy - 0.29, cz - 0.08), (0.05, 0.03, 0.42), "royal_berry", bevel=False,
          rot=(math.radians(-60), "Y"))                                                       # minute hand: past 4
    b.cyl((cx, cy - 0.31, cz), 0.06, 0.04, "gold_dark", segments=10, rot=X)                   # the pin
    for sx in (-1, 1):                                                                        # the bells and legs
        a = math.radians(90 + sx * 40)
        bx, bz = cx + (R + 0.05) * math.cos(a), cz + (R + 0.05) * math.sin(a)
        b.sphere((bx, cy, bz), 0.28, "gold_light", segments=14, rings=7, scale=(1, 1, 0.8))
        b.box((cx + sx * 0.45, cy, cz - R - 0.08), (0.1, 0.12, 0.28), "gold_dark", bevel=False,
              rot=(math.radians(sx * 25), "Y"))
    b.box((cx, cy, cz + R + 0.12), (0.12, 0.12, 0.2), "gold_dark", bevel=False)                # the hammer
    # the Zs, getting bigger as they rise to the left
    _text(b, "Z", -0.2, -0.45, 1.75, 0.09, 0.08, "offwhite")
    _text(b, "Z", -0.7, -0.45, 2.15, 0.12, 0.08, "offwhite")
    _text(b, "Z", -1.3, -0.45, 2.65, 0.16, 0.08, "offwhite")
    cat = place(_cat("Ginger", mat, body="walk", pose="sleep"), at=(-0.1, -0.15, 0.45), yaw=-90, scale=1.1)
    return _fin(b, "LongNap", mat) + cat


def _moon(b, c, R, W, depth, sw, n=14):
    """A smooth crescent standing up and facing the camera, its horns toward -x."""
    a0, a1 = math.radians(-140), math.radians(140)
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        w = W * math.sin(math.pi * t) + 0.02
        outer.append((R * math.cos(a), R * math.sin(a)))
        inner.append(((R - w) * math.cos(a), (R - w) * math.sin(a)))
    for i in range(n):
        b.fan(c, outer[i], [inner[i], inner[i + 1], outer[i + 1]], depth, sw, rot=X)


def vip(mat):
    b = Builder()
    b.box((0, 0, 0.75), (2.9, 0.24, 1.5), "gold_mid")                                          # the plate
    b.box((0, -0.1, 0.75), (2.6, 0.08, 1.22), "gold_light", bevel=False)
    _text(b, "VIP", 0.0, -0.2, 0.75 - 2.5 * 0.2, 0.2, 0.08, "royal_berry")
    for sx in (-1, 1):                                                                        # screws
        b.cyl((sx * 1.2, -0.15, 0.75), 0.06, 0.05, "gold_dark", segments=8, rot=X)
    b.cyl((0, 0, 1.55), 0.5, 0.2, "cream", segments=24, rot=X)                                 # the crest
    b.cyl((0, 0.02, 1.55), 0.56, 0.18, "gold_mid", segments=24, rot=X)
    _paw(b, 0, -0.13, 1.55, 1.05, "gold_mid")
    for (x, z, s) in ((-1.45, 1.75, 0.2), (1.5, 1.85, 0.16)):
        _star(b, x, -0.1, z, s)
    return _fin(b, "VIP", mat)


def accessories_pass(mat):
    """#2578: what the pass gives, the Round Glasses and the Tail Bow (Looks.ACCESSORIES), both worn by one Mythical
    cat drawn big, its tail and bow curled up beside it, with twinkles. (It showed a boater, a bow tie and a loose
    beret, none of which the pass gives.)"""
    b = Builder()
    _twinkle(b, -0.62, -0.5, 1.95, 0.24)
    _twinkle(b, 0.75, -0.5, 1.75, 0.18)
    cat = place(_cat("Wisp", mat, dress=("Glasses", "TailBow"), grow=1.15), yaw=-30)
    return cat + _fin(b, "Accessories", mat)


# Looks.UNIFORMS of the Uniform Styles pass as (main, trim) swatches (pass_reward_icons.UNIFORMS)
PASS_UNIFORMS = {"Striped": ("cream", "caramel_wood"), "Midnight": ("pants_navy", "fur_golden"), "Mint": ("mint", "cream")}


def uniforms(mat):
    """#2578: the three styles the pass sells, one per job, on three cats shoulder to shoulder, cropped at the chest so
    the faces and outfits fill the circle: in front a Midnight barista (apron and cap), behind on the left a Mint
    waiter (bow tie and vest), behind on the right a Striped greeter (sash and boater)."""
    out = []
    for name, role, style, at, s in (("Golem", "waiter", "Mint", (-0.78, 0.5, 0.72), 0.9),
                                     ("Eclipse", "greeter", "Striped", (0.78, 0.5, 0.72), 0.9),
                                     ("Blossom", "barista", "Midnight", (0.0, -0.45, -0.15), 1.3)):
        cat = _dressed(name, mat, accessories.ROLE_OUTFITS[role], PASS_UNIFORMS[style], grow=1.25)
        out += place(cat, at=at, scale=s, yaw=-10 if at[0] >= 0 else 10)
    b = Builder()
    _twinkle(b, -0.95, -0.6, 2.2, 0.22)
    return _crop(out + _fin(b, "Uniforms", mat), 0.3)


def _awning(b, x0, x1, z, depth, colours, n):
    """A striped awning sloping out from the wall over x0..x1 at height z, with a scalloped edge."""
    w = (x1 - x0) / n
    for i in range(n):
        x = x0 + w * (i + 0.5)
        sw = colours[i % 2]
        b.box((x, -depth / 2, z), (w, depth, 0.1), sw, rot=(math.radians(18), "X"))
        b.fan((x, -depth - 0.01, z - depth * math.sin(math.radians(18)) - 0.03), (0, 0),
              [(w / 2 * math.cos(a), w / 2 * math.sin(a)) for a in (math.radians(-15 * k) for k in range(13))],
              0.05, sw, rot=X)


def cafe_style(mat):
    b = Builder()
    W, H = 2.6, 2.2
    b.box((0, 0.2, H / 2), (W, 0.4, H), "cream")                                               # the wall
    b.box((0, 0.2, H + 0.08), (W + 0.12, 0.5, 0.16), "fur_moss")                              # cornice
    b.box((0.55, -0.02, 0.85), (1.1, 0.06, 0.9), "pastel_sky")                                 # window
    b.box((0.55, -0.04, 0.85), (1.18, 0.04, 0.08), "offwhite", bevel=False)
    b.cyl((0.55, -0.12, 0.52), 0.26, 0.06, "offwhite", segments=14)                           # a cake on a stand
    b.cyl((0.55, -0.12, 0.66), 0.2, 0.22, "fur_bubblegum", segments=14)
    b.ico((0.55, -0.12, 0.83), 0.06, "shirt_red")
    b.box((-0.7, -0.02, 0.62), (0.62, 0.06, 1.24), "caramel_wood")                             # door
    b.cyl((-0.48, -0.08, 0.62), 0.05, 0.04, "gold_mid", segments=8, rot=X)
    b.box((-0.7, -0.06, 0.95), (0.36, 0.03, 0.34), "pastel_sky", bevel=False)
    b.box((0, -0.05, 0.03), (W + 0.1, 0.12, 0.06), "fur_fern")                                # step trim
    b.box((0.55, -0.2, 0.2), (1.25, 0.34, 0.3), "terracotta")                                  # a flower trough
    for k in range(7):
        b.ico((0.0 + 0.183 * k, -0.22, 0.42 + 0.03 * (k % 2)), 0.1, ("blush", "offwhite", "pastel_butter")[k % 3])
        b.ico((0.09 + 0.183 * k, -0.12, 0.38), 0.09, "leaf_green")
    _awning(b, -W / 2 - 0.05, W / 2 + 0.05, 1.55, 0.7, ("fur_fern", "offwhite"), 6)
    b.cyl((0, 0.02, 2.55), 0.5, 0.12, "brass", segments=24, rot=X)                             # the round sign
    b.cyl((0, -0.05, 2.55), 0.42, 0.06, "cream", segments=24, rot=X)
    hud = place(hud_icons.cat_face(mat), at=(0, -0.12, 2.27), scale=0.32)                     # a cat face on it
    return _fin(b, "CafeStyle", mat) + hud


def grand_theme(mat):
    b = Builder()
    W, H = 3.2, 2.3
    b.box((0, 0.2, H / 2), (W, 0.4, H), "cream")                                               # the wall
    b.box((0, -0.05, 0.06), (W + 0.3, 0.6, 0.12), "gold_mid")                                  # plinth and steps
    b.box((0, -0.2, 0.15), (1.4, 0.5, 0.06), "cream")
    for x in (-1.4, 1.4):                                                                      # gold columns
        b.cyl_base((x, -0.15, 0.12), 0.15, H - 0.25, "gold_light", segments=12)
        b.box((x, -0.15, 0.17), (0.38, 0.38, 0.1), "gold_mid")
        b.box((x, -0.15, H - 0.08), (0.4, 0.4, 0.12), "gold_mid")
    b.box((0, -0.05, H + 0.05), (W + 0.3, 0.6, 0.18), "gold_mid")                              # entablature
    b.prism((0, 0.0, H + 0.14), [(-W / 2 - 0.1, 0), (W / 2 + 0.1, 0), (0, 1.0)], 0.5, "gold_mid", rot=X)  # pediment
    b.prism((0, -0.02, H + 0.22), [(-W / 2 + 0.1, 0), (W / 2 - 0.1, 0), (0, 0.8)], 0.5, "royal_berry", rot=X)
    b.cyl((0, -0.28, H + 0.48), 0.3, 0.06, "gold_mid", segments=20, rot=X)                     # the cat sign in it
    b.cyl((0, -0.32, H + 0.48), 0.25, 0.04, "cream", segments=20, rot=X)
    crown = H + 1.12                                                                           # a big crown on top
    b.box((0, -0.05, crown), (0.9, 0.22, 0.22), "rarity_legend")
    for dx, hh in ((-0.35, 0.34), (0.0, 0.46), (0.35, 0.34)):
        b.pyramid((dx, -0.05, crown + 0.11), 0.24, hh, "rarity_legend")
        b.ico((dx, -0.05, crown + 0.13 + hh), 0.07, "offwhite")
    b.ico((0, -0.18, crown), 0.07, "shirt_red")
    b.box((0, 0.0, 0.85), (0.9, 0.06, 1.45), "royal_berry")                                    # double doors
    b.box((0, -0.04, 0.85), (0.04, 0.04, 1.4), "gold_mid", bevel=False)
    for sx in (-1, 1):
        b.cyl((sx * 0.1, -0.06, 0.8), 0.04, 0.04, "gold_mid", segments=8, rot=X)
        b.box((sx * 0.85, -0.02, 1.0), (0.55, 0.06, 0.9), "pastel_sky")                        # windows
        b.box((sx * 0.85, -0.04, 1.0), (0.6, 0.04, 0.06), "gold_mid", bevel=False)
        b.cyl((sx * 0.85, -0.12, 0.62), 0.2, 0.05, "offwhite", segments=14)                    # a cake in each
        b.cyl((sx * 0.85, -0.12, 0.74), 0.15, 0.18, "fur_bubblegum", segments=14)
        b.ico((sx * 0.85, -0.12, 0.88), 0.05, "shirt_red")
    _awning(b, -1.2, 1.2, 1.75, 0.6, ("rarity_legend", "cream"), 8)
    for (x, z, s) in ((-1.8, 3.2, 0.2), (1.8, 3.0, 0.16)):
        _star(b, x, -0.2, z, s)
    hud = place(hud_icons.cat_face(mat), at=(0, -0.36, H + 0.31), scale=0.19)
    return _fin(b, "GrandTheme", mat) + hud


def cafe_style_pass(mat):
    """#2578: the Garden Cafe theme up close, three-quarter view of the awning and window only: big sage and white
    stripes, a cat face in the window and a trough of flowers across the bottom."""
    b = Builder()
    W, H = 2.2, 2.0
    b.box((0, 0.2, H / 2), (W, 0.4, H), "cream")                                               # the wall
    b.box((0, -0.02, 0.95), (1.7, 0.06, 1.05), "pastel_sky")                                   # the window
    for (x, z, sx, sz) in ((0, 0.4, 1.86, 0.1), (0, 1.5, 1.86, 0.1), (-0.88, 0.95, 0.1, 1.2), (0.88, 0.95, 0.1, 1.2),
                           (0, 0.95, 0.06, 1.05)):
        b.box((x, -0.06, z), (sx, 0.08, sz), "offwhite", bevel=False)
    face = place(hud_icons.cat_face(mat), at=(-0.42, -0.1, 0.55), scale=0.42)                 # a cat at the window
    b.cyl((0.45, -0.12, 0.5), 0.26, 0.06, "offwhite", segments=14)                            # a cake on a stand
    b.cyl((0.45, -0.12, 0.65), 0.21, 0.24, "fur_bubblegum", segments=14)
    b.ico((0.45, -0.12, 0.84), 0.07, "shirt_red")
    b.box((0, -0.28, 0.2), (2.0, 0.44, 0.4), "terracotta")                                     # the flower trough
    for k in range(9):
        x = -0.88 + 0.22 * k
        b.ico((x + 0.08, -0.25, 0.46), 0.12, "leaf_green")
        b.ico((x, -0.38, 0.5 + 0.04 * (k % 2)), 0.14, ("blush", "offwhite", "pastel_butter")[k % 3])
    _awning(b, -W / 2 - 0.15, W / 2 + 0.15, 1.82, 0.95, ("fur_fern", "offwhite"), 4)           # four big stripes
    b.box((0, 0.2, H + 0.08), (W + 0.12, 0.5, 0.16), "fur_moss")                              # cornice
    _twinkle(b, 1.05, -0.6, 2.3, 0.22)
    return _fin(b, "CafeStyle", mat) + face


def grand_theme_pass(mat):
    """#2578: the Grand Cafe theme up close, so it reads as our grandest look: two gold columns and the berry
    pediment with its cat sign fill the circle, a big gold crown breaks the top, gold sparkles round it."""
    b = Builder()
    H = 1.7
    b.box((0, 0.25, H / 2), (3.0, 0.4, H), "cream")                                            # the wall
    b.box((0, 0.0, 0.72), (0.95, 0.06, 1.24), "royal_berry")                                   # the double doors
    b.box((0, -0.04, 0.72), (0.04, 0.04, 1.2), "gold_mid", bevel=False)
    for sx in (-1, 1):
        b.cyl((sx * 0.1, -0.06, 0.7), 0.045, 0.04, "gold_mid", segments=8, rot=X)
        b.box((sx * 0.25, -0.05, 1.05), (0.3, 0.03, 0.38), "pastel_sky", bevel=False)            # door lights
        b.box((sx * 0.95, -0.02, 0.95), (0.5, 0.06, 0.8), "pastel_sky")                         # windows
        b.box((sx * 0.95, -0.04, 0.95), (0.56, 0.04, 0.06), "gold_mid", bevel=False)
    b.box((0, -0.1, 0.06), (3.1, 0.6, 0.12), "gold_mid")                                       # the step
    for x in (-1.32, 1.32):                                                                    # gold columns
        b.cyl_base((x, -0.2, 0.12), 0.19, H - 0.24, "gold_light", segments=14)
        for z in (0.55, 1.1):
            b.ring((x, -0.2, z), 0.2, 0.03, 0.05, "gold_mid", segments=14)
        b.box((x, -0.2, 0.2), (0.46, 0.46, 0.14), "gold_mid")
        b.box((x, -0.2, H - 0.06), (0.5, 0.5, 0.14), "gold_mid")
    b.box((0, -0.12, H + 0.08), (3.2, 0.66, 0.2), "gold_mid")                                 # the entablature
    b.prism((0, -0.05, H + 0.18), [(-1.65, 0), (1.65, 0), (0, 1.0)], 0.5, "gold_mid", rot=X)   # the pediment
    b.prism((0, -0.08, H + 0.27), [(-1.38, 0), (1.38, 0), (0, 0.78)], 0.5, "royal_berry", rot=X)
    b.cyl((0, -0.34, H + 0.55), 0.3, 0.06, "gold_mid", segments=20, rot=X)                     # the cat sign in it
    b.cyl((0, -0.38, H + 0.55), 0.25, 0.04, "cream", segments=20, rot=X)
    crown = H + 1.38                                                                           # the big crown
    b.box((0, -0.1, crown), (1.2, 0.3, 0.3), "rarity_legend")
    for dx, hh in ((-0.45, 0.42), (0.0, 0.6), (0.45, 0.42)):
        b.pyramid((dx, -0.1, crown + 0.15), 0.32, hh, "rarity_legend")
        b.ico((dx, -0.1, crown + 0.18 + hh), 0.09, "offwhite")
    for dx, sw in ((-0.3, "fish_blue"), (0.0, "shirt_red"), (0.3, "leaf_green")):
        b.ico((dx, -0.27, crown), 0.08, sw)
    for (x, z, s) in ((-1.25, 3.0, 0.22), (1.25, 2.85, 0.18)):
        _star(b, x, -0.3, z, s)
    _twinkle(b, 1.7, -0.5, 2.3, 0.2)
    hud = place(hud_icons.cat_face(mat), at=(0, -0.42, H + 0.39), scale=0.19)
    return _fin(b, "GrandTheme", mat) + hud


def extra_slot(mat):
    """#2578: the stool cropped at its seat so the cat on it is drawn big, with the big mint +1 tag."""
    b = Builder()
    b.cyl((0, 0, 1.15), 0.62, 0.22, "blush", segments=24)                                      # seat cushion
    b.cyl((0, 0, 1.0), 0.6, 0.1, "caramel_wood", segments=24)
    for k in range(4):                                                                         # the legs' tops
        a = math.radians(45 + 90 * k)
        b.cyl((0.42 * math.cos(a), 0.42 * math.sin(a), 0.8), 0.06, 0.4, "caramel_wood", segments=8)
    _tag(b, "+1", 1.0, 2.75, 0.55, ink="leaf_dark", disc="mint", y=-0.8)
    cat = place(_cat("MapleMuffin", mat, dress=("Apron",)), at=(-0.05, 0.05, 1.26), scale=1.25, yaw=-8)
    return _crop(_fin(b, "ExtraSlot", mat) + cat, 0.8)


def royal_cat(mat):
    cat = place(_cat("DuchessMarzipan", mat), yaw=-8)
    x, _, z = _top(cat)
    b = Builder()
    t = (x, -0.25, z - 0.12)                                                                   # the tiara, oversized
    b.box((t[0], t[1], t[2]), (0.62, 0.14, 0.12), "gold_mid")
    for dx, hh in ((-0.24, 0.2), (0.0, 0.34), (0.24, 0.2)):
        b.pyramid((t[0] + dx, t[1], t[2] + 0.06), 0.16, hh, "rarity_legend")
        b.ico((t[0] + dx, t[1], t[2] + 0.08 + hh), 0.06, "offwhite")
    b.ico((t[0], t[1] - 0.09, t[2] + 0.02), 0.07, "fur_bubblegum")
    for dx in (-0.18, 0.18):
        b.ico((t[0] + dx, t[1] - 0.08, t[2]), 0.035, "offwhite")
    _star(b, 0.85, -0.3, 1.75, 0.22)
    _star(b, -0.8, -0.3, 1.35, 0.16)
    return cat + _fin(b, "RoyalCat", mat)


def king_pack(mat):
    """#2578: King Croissant big on his velvet cushion, cropped at the cushion's top, with the Royal Crest sign plate
    (the pack's sign style) behind his shoulder."""
    b = Builder()
    _twinkle(b, -0.9, -0.6, 2.25, 0.22)
    sign = place(crown_sign(mat), at=(-0.85, 0.9, shopcats.SEAT_Y + 1.25), scale=0.36, yaw=10)
    cushion = place(shopcats.build_king_cushion(mat), scale=1.0)
    cat = place(_cat("KingCroissant", mat), at=(0.15, -0.1, shopcats.SEAT_Y), scale=1.3, yaw=-8)
    return _crop(cushion + cat + sign + _fin(b, "KingPack", mat), shopcats.SEAT_Y - 0.12)


def king_cat(mat):
    """#2180: the King Cat pass, King Croissant on his own and drawn big like the Royal Cat (the King Cat Pack shows him
    on his throne), with a big Mythical pink star, a gold one and twinkles."""
    cat = place(_cat("KingCroissant", mat), yaw=-8)
    b = Builder()
    _star(b, 1.0, -0.3, 1.95, 0.3, sw="rarity_mythic")
    _star(b, -0.9, -0.3, 1.45, 0.18)
    _twinkle(b, -0.65, -0.4, 2.15, 0.26)
    _twinkle(b, 1.35, -0.4, 1.25, 0.2)
    return cat + _fin(b, "KingCat", mat)


def golden_pond(mat):
    b = Builder()
    b.cyl((0, 0, 0.1), 1.25, 0.12, "pastel_sky", segments=28, scale=(1, 0.75, 1))              # the water
    for k in range(18):                                                                        # stones round it
        a = 2 * math.pi * k / 18
        b.ico((1.32 * math.cos(a), 1.0 * math.sin(a), 0.14), 0.2 + 0.04 * (k % 3), ("concrete", "concrete_dark")[k % 2],
              scale=(1.0, 1.0, 0.7))
    for (x, y, r) in ((-0.55, 0.2, 0.28), (0.5, 0.35, 0.22)):                                  # lily pads
        b.cyl((x, y, 0.18), r, 0.03, "leaf_green", segments=14)
    b.ico((-0.5, 0.18, 0.24), 0.08, "blush")                                                   # a flower
    for (x, z, s) in ((-0.35, 0.45, 0.07), (0.2, 0.5, 0.06), (-0.15, 0.7, 0.05)):            # splash drops
        b.ico((x, -0.3, z), s, "pastel_sky")
    fish = place(icon_art.golden_fish(mat), at=(0.1, -0.2, 1.2), scale=0.62, roll=-30)          # leaping, nose up
    _twinkle(b, -1.0, -0.4, 1.9, 0.4)
    return _fin(b, "GoldenPond", mat) + fish


def second_bait_bowl(mat):
    """#2578: two heaped bowls side by side, seen from higher so the kibble shows, closer and bigger, with a cat
    peeking over the second one and the +1 tag."""
    face = place(hud_icons.cat_face(mat), at=(0.85, 0.2, 0.6), scale=0.6)
    back = place(hud_icons.bait(mat), at=(-0.75, 0.35, 0.0), scale=1.9)
    front = place(hud_icons.bait(mat), at=(0.75, -0.6, 0.0), scale=1.9)
    b = Builder()
    _tag(b, "+1", 1.5, 1.45, 0.5, ink="leaf_dark", disc="mint", y=-0.9)
    _twinkle(b, -1.1, -0.4, 1.3, 0.28)
    return face + back + front + _fin(b, "SecondBaitBowl", mat)


# --- products -----------------------------------------------------------------------------------------------------

def _flask(name, mat, at, scale, yaw=0.0):
    return place(potion_icons.flask(name, mat), at=at, scale=scale, yaw=yaw)


def starter_bundle(mat):
    box = place(hud_icons.gift(mat), at=(0.1, 0.5, 0.0), scale=0.9)
    cat = place(_cat("Sprinkles", mat), at=(-0.95, -0.35, 0.0), scale=0.85, yaw=10)
    pots = _flask("BigTip", mat, (0.85, -0.55, 0.0), 0.36) + _flask("Swift", mat, (1.3, -0.25, 0.0), 0.36)
    b = Builder()
    b.cyl_base((-1.45, 0.55, 0.0), 0.04, 1.0, "caramel_wood", segments=6)                      # a little sign
    for i in range(4):
        b.box((-1.45 - 0.27 + 0.18 * i, 0.5, 1.15), (0.18, 0.06, 0.5), ("fur_bubblegum", "cream")[i % 2], bevel=False)
    b.box((-1.45, 0.47, 1.15), (0.6, 0.02, 0.06), "fur_strawberry", bevel=False)
    return box + cat + pots + _fin(b, "StarterBundle", mat)


def starter_popup(mat):
    """The Starter Bundle pop-up card's picture (Derek 2026-11-14, Design-Agent's brief): Sprinkles in its Epic look,
    three-quarter front and a little left of the middle, with the bundle's three potions (Big Money, Swift, Steady
    Paw) and the 2x money coins in front at the bottom right. icons.py puts a soft warm glow behind it."""
    cat = place(_cat("Sprinkles", mat, body="walk"), at=(-0.5, 0.3, 0.0), scale=1.45, yaw=48)
    pots = (_flask("BigTip", mat, (0.75, -1.0, 0.0), 0.4, yaw=-6) + _flask("Swift", mat, (1.3, -0.85, 0.0), 0.4)
            + _flask("Steady", mat, (1.85, -0.7, 0.0), 0.4, yaw=8))
    coins = place(icon_art.coins(mat), at=(2.0, 0.5, 0.0), scale=0.55)
    b = Builder()
    _tag(b, "X2", 2.1, 1.75, 0.42, y=0.3)
    return cat + pots + coins + _fin(b, "StarterPopup", mat)


def potion_xs(mat):
    return _flask("BigTip", mat, (-0.5, 0.3, 0.0), 0.9, yaw=8) + _flask("BigTip", mat, (0.55, -0.3, 0.0), 0.9, yaw=-8)


def _basket(b, w, d, h, sw="caramel_wood", band="dark_wood"):
    """A wicker basket w x d x h: a floor, woven walls (alternating bands) and a handle over the top."""
    b.box((0, 0, 0.05), (w, d, 0.1), sw)
    for k in range(4):
        z = 0.1 + (h - 0.1) * (k + 0.5) / 4
        b.box((0, 0, z), (w, d, (h - 0.1) / 4 * 0.92), (sw, band)[k % 2], bevel=False)


def potion_s(mat):
    b = Builder()
    _basket(b, 2.7, 1.4, 0.42)
    for k in range(13):                                                                        # handle, over the top
        a = math.radians(15 * k)
        b.box((1.3 * math.cos(a), 0.0, 0.42 + 1.1 * math.sin(a)), (0.36, 0.1, 0.1), "caramel_wood",
              rot=(-(a + math.pi / 2), "Y"))
    out = _fin(b, "PotionS", mat)
    for (n, x, y, z) in (("BigTip", -0.8, 0.25, 0.2), ("BigTip", 0.0, 0.3, 0.25), ("BigTip", 0.8, 0.25, 0.2),
                         ("Swift", -0.42, -0.3, 0.12), ("Steady", 0.45, -0.3, 0.12)):
        out += _flask(n, mat, (x, y, z), 0.56)
    return out


def _crate(b, w, d, h):
    """An open wooden crate: slatted sides, dark corner posts."""
    b.box((0, 0, 0.06), (w, d, 0.12), "caramel_wood")
    for k in range(3):
        z = 0.12 + (h - 0.12) * (k + 0.5) / 3
        hh = (h - 0.12) / 3 * 0.8
        b.box((0, -d / 2, z), (w, 0.08, hh), "caramel_wood", bevel=False)
        b.box((0, d / 2, z), (w, 0.08, hh), "caramel_wood", bevel=False)
        b.box((-w / 2, 0, z), (0.08, d, hh), "caramel_wood", bevel=False)
        b.box((w / 2, 0, z), (0.08, d, hh), "caramel_wood", bevel=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * w / 2, sy * d / 2, h / 2), (0.14, 0.14, h), "dark_wood", bevel=False)


def potion_m(mat):
    b = Builder()
    _crate(b, 3.0, 1.5, 0.45)
    out = _fin(b, "PotionM", mat)
    rows = (("BigTip", "BigTip", "Swift", "Swift", "Steady"), ("BigTip", "BigTip", "BigTip", "Swift", "Steady"))
    for r, row in enumerate(rows):
        for i, n in enumerate(row):
            out += _flask(n, mat, (-1.16 + 0.58 * i, 0.32 - 0.64 * r, 0.12 + 0.22 * (1 - r)), 0.46)
    return out


def potion_l(mat):
    b = Builder()
    _crate(b, 3.5, 1.9, 0.5)
    b.box((0, -0.97, 0.28), (3.52, 0.04, 0.2), "fur_bubblegum", bevel=False)                   # the ribbon round it
    for sx in (-1, 1):                                                                         # the bow on its front
        b.ico((sx * 0.3, -1.05, 0.42), 0.26, "fur_bubblegum", scale=(1.3, 0.5, 0.8))
        b.box((sx * 0.22, -1.03, 0.12), (0.12, 0.04, 0.3), "fur_bubblegum", rot=(math.radians(sx * 20), "Y"))
    b.ico((0, -1.08, 0.4), 0.13, "blush")
    out = _fin(b, "PotionL", mat)
    names = ("BigTip", "Swift", "Steady")
    for r in range(3):
        for i in range(6):
            n = names[(i + r) % 3]
            out += _flask(n, mat, (-1.4 + 0.56 * i, 0.6 - 0.55 * r, 0.12 + 0.2 * (2 - r)), 0.42)
    out += _flask("BigTip", mat, (-0.45, 0.05, 1.25), 0.42, yaw=-20)                             # the two bonus ones
    out += _flask("Steady", mat, (0.5, 0.05, 1.25), 0.42, yaw=15)
    return out


def cafe_pass(mat):
    b = Builder()
    for sx in (-1, 1):                                                                         # ribbon tails
        b.box((sx * 0.35, 0.1, -0.55), (0.42, 0.06, 1.3), "royal_berry", rot=(math.radians(sx * -14), "Y"))
        b.prism((sx * 0.5, 0.06, -1.2), [(-0.22, 0.0), (0.22, 0.0), (0.0, 0.22)], 0.07, "cream", rot=X)
    n = 16                                                                                     # the scalloped rosette
    for k in range(n):
        a = 2 * math.pi * k / n
        b.cyl((1.0 * math.cos(a), 0.04, 0.5 + 1.0 * math.sin(a)), 0.26, 0.12, "gold_mid", segments=12, rot=X)
    b.cyl((0, 0.0, 0.5), 1.0, 0.16, "gold_mid", segments=32, rot=X)
    b.cyl((0, -0.06, 0.5), 0.82, 0.1, "royal_berry", segments=32, rot=X)
    b.cyl((0, -0.1, 0.5), 0.62, 0.06, "cream", segments=32, rot=X)
    _paw(b, 0, -0.14, 0.42, 1.25, "royal_berry")
    _star(b, 0, -0.14, 0.95, 0.16)
    _twinkle(b, 1.1, -0.3, 1.55, 0.4)
    return _fin(b, "CafePass", mat)


def crown_sign(mat):
    """#1823: the Royal Crest sign style (signstyles.py) cut down to an icon: a short berry board reading CAFE in a gold
    frame with jewel corners, under the crest's medallion with the crown on its croissant, drawn big."""
    from common import RB, text_width
    from signstyles import _crest
    b = RB()
    x1, y1, f, z = 2.0, 1.5, 0.32, 0.0
    b.span((-x1, 0, z), (x1, y1, z + 0.1), "royal_berry")                                       # the board
    for (xa, xb, ya, yb) in ((-x1 - f, x1 + f, -f, 0), (-x1 - f, x1 + f, y1, y1 + f), (-x1 - f, -x1, 0, y1),
                             (x1, x1 + f, 0, y1)):
        b.span((xa, ya, z - 0.14), (xb, yb, z + 0.1), "gold_mid")                              # the raised frame
    for sx in (-1, 1):
        for sy, y in ((-1, -f / 2), (1, y1 + f / 2)):
            b.cyl((sx * (x1 + f / 2), y, z - 0.18), 0.12, 0.08, "bowl_red" if sy > 0 else "shirt_blue", axis="Z",
                  segments=10)
    px = 0.14
    b.text("CAFE", (text_width("CAFE", px) / 2, y1 / 2 - 2.5 * px, z - 0.02), px, 0.04, "cream", right=(-1, 0, 0))
    cy = y1 + f + 0.95
    b.cyl((0.0, cy, z - 0.02), 1.0, 0.24, "gold_mid", axis="Z", segments=20)                 # the medallion,
    b.cyl((0.0, cy, z - 0.16), 0.85, 0.06, "royal_berry", axis="Z", segments=20)             # berry in a gold ring
    _crest(b, 0.0, cy - 0.05, z - 0.19, 1.6)
    return [b.finalize("CatCafe_IconArt_Store_CrownSign", mat)]


def _plate(b, c, ang, w, h, board, frame, f=0.12):
    """A small sign plate facing the camera, centred on c and turned `ang` degrees in the picture plane (positive
    leans it right); returns a function giving world points from the plate's own (x, depth, z) and its rotation."""
    R = Matrix.Rotation(math.radians(ang), 3, "Y")
    C = Vector(c)

    def at(x, y, z):
        return tuple(C + R @ Vector((x, y, z)))

    b.box(at(0, 0, 0), (w, 0.12, h), board, bevel=False, rot=R)
    for (x, z, sx, sz) in ((0, h / 2 + f / 2, w + 2 * f, f), (0, -h / 2 - f / 2, w + 2 * f, f),
                           (-w / 2 - f / 2, 0, f, h), (w / 2 + f / 2, 0, f, h)):
        b.box(at(x, -0.04, z), (sx, 0.2, sz), frame, bevel=False, rot=R)
    return at, R


def sign_style_pack(mat):
    """#2578: the pack's three sign styles (#1860), Starry Night big in front (navy, gold frame, gold stars and a
    moon), Flower Box and Paw Chalkboard peeking out behind it on either side, each about twice the old size."""
    b = Builder()
    up = Matrix.Rotation(math.radians(90), 3, "X")                                            # flat shapes face -y
    W, H = 1.8, 1.15
    # Flower Box, behind on the left
    at, R = _plate(b, (-0.95, 0.35, 1.75), -16, W, H, "offwhite", "mint", f=0.15)
    b.box(at(0, -0.22, -H / 2 - 0.3), (W * 0.85, 0.34, 0.3), "caramel_wood", bevel=False, rot=R)
    for k, sw in enumerate(("apron_pink", "rarity_legend", "pastel_sky", "offwhite", "blush")):
        x = -W * 0.36 + k * W * 0.18
        b.ico(at(x + 0.07, -0.3, -H / 2 - 0.12), 0.15, "leaf_green")
        b.ico(at(x, -0.42, -H / 2 - 0.06), 0.17, sw)
    # Paw Chalkboard, behind on the right
    at, R = _plate(b, (0.95, 0.3, 1.75), 16, W, H, "dumpster_green", "caramel_wood", f=0.15)
    for (x, z, s) in ((0.1, 0.18, 0.5), (0.5, -0.12, 0.42)):
        b.cyl(at(x, -0.08, z - 0.05 * s), 0.26 * s, 0.04, "offwhite", segments=12, rot=R @ up)
        for (dx, dz) in ((-0.27, 0.2), (-0.1, 0.34), (0.1, 0.34), (0.27, 0.2)):
            b.cyl(at(x + dx * s, -0.08, z + dz * s), 0.09 * s, 0.04, "offwhite", segments=8, rot=R @ up)
    # Starry Night, big in front
    W, H = 2.5, 1.5
    at, R = _plate(b, (0, -0.35, 0.8), 0, W, H, "night_sky", "gold_mid", f=0.18)
    for (x, z, s) in ((-0.85, 0.3, 0.26), (-0.32, -0.3, 0.17), (0.2, 0.38, 0.2), (0.62, -0.22, 0.15),
                      (0.98, 0.32, 0.17), (-0.95, -0.42, 0.13)):
        b.star(at(x, -0.09, z), s, s * 0.45, 0.05, "sparkle" if s < 0.16 else "rarity_legend", rot=R @ up)
    _moon(b, at(0.0, -0.1, -0.02), 0.42, 0.2, 0.16, "gold_mid")
    return _fin(b, "SignStylePack", mat)


def garden_decor_pack(mat):
    b = Builder()
    b.cyl((0, 0, 0.1), 1.45, 0.2, "leaf_green", segments=28, scale=(1, 0.72, 1))               # the grass mound
    b.cyl((0, 0.05, 0.24), 1.15, 0.12, "choco", segments=24, scale=(1, 0.6, 1))                # the bed's soil
    flowers = ((-0.85, 0.2, 0.55, "apron_pink"), (-0.5, -0.15, 0.62, "rarity_legend"),
               (-0.15, 0.25, 0.7, "pastel_lilac"),
               (0.2, -0.1, 0.58, "offwhite"), (0.55, 0.2, 0.66, "apron_pink"), (0.85, -0.05, 0.52, "rarity_legend"),
               (-0.65, 0.4, 0.75, "offwhite"), (0.35, 0.42, 0.8, "pastel_lilac"))
    for k, (x, y, h, sw) in enumerate(flowers):
        b.cyl((x, y, 0.3 + h / 2), 0.035, h, "leaf_dark", segments=5, bevel=False)            # a stem
        b.ico((x + 0.1, y, 0.3 + h * 0.45), 0.12, ("leaf_green", "leaf_dark")[k % 2], scale=(1.4, 0.8, 0.5))
        for j in range(5):                                                                     # five round petals
            a = math.radians(72 * j + 90)
            b.cyl((x + 0.12 * math.cos(a), y - 0.02, 0.3 + h + 0.12 * math.sin(a)), 0.1, 0.04, sw, segments=8,
                  bevel=False, rot=X)
        b.cyl((x, y - 0.05, 0.3 + h), 0.07, 0.04, "fur_orange" if sw == "rarity_legend" else "rarity_legend",
              segments=8, bevel=False, rot=X)
    sx, sy, sh = -0.1, 0.5, 1.45                                                               # a tall sunflower
    b.cyl((sx, sy, 0.3 + sh / 2), 0.05, sh, "leaf_dark", segments=6, bevel=False)
    for s in (-1, 1):
        b.ico((sx + s * 0.22, sy, 0.3 + sh * (0.45 if s < 0 else 0.62)), 0.18, "leaf_green", scale=(1.5, 0.8, 0.5))
    for j in range(12):
        a = math.radians(30 * j)
        b.box((sx + 0.36 * math.cos(a), sy - 0.02, 0.3 + sh + 0.36 * math.sin(a)), (0.3, 0.04, 0.13), "rarity_legend",
              bevel=False, rot=Matrix.Rotation(-a, 3, "Y"))
    b.cyl((sx, sy - 0.06, 0.3 + sh), 0.22, 0.08, "choco", segments=14, bevel=False, rot=X)
    for k in range(9):                                                                         # the picket fence
        x = -1.2 + k * 0.3
        b.box((x, -0.82, 0.42), (0.14, 0.06, 0.5), "offwhite")
        b.fan((x, -0.82, 0.67), (0, 0.11), [(-0.07, 0.0), (0.07, 0.0)], 0.06, "offwhite", rot=X)
    for z in (0.32, 0.55):                                                                     # its rails
        b.box((0, -0.79, z), (2.55, 0.05, 0.07), "offwhite", bevel=False)
    return _fin(b, "GardenDecorPack", mat)



def _note(b, x, z, s, sw, flag=True, tilt=0.0):
    """A music note facing the camera: an oval head, a stem and (flag) a little flag."""
    b.cyl((x, -0.3, z), 0.2 * s, 0.07, sw, segments=16, rot=X, scale=(1.3, 1.0, 1.0))
    b.box((x + 0.22 * s, -0.3, z + 0.48 * s), (0.07 * s, 0.07, 0.95 * s), sw, bevel=False)
    if flag:
        b.box((x + 0.36 * s, -0.3, z + 0.8 * s), (0.28 * s, 0.07, 0.1 * s), sw, bevel=False,
              rot=(math.radians(-35 + tilt), "Y"))


def jukebox(mat):
    """#1867: the Jukebox Pass, a little retro jukebox with its record in the arched top, music notes round it."""
    b = Builder()
    w, d = 1.9, 0.9
    b.box((0, 0, 0.09), (w + 0.2, d + 0.1, 0.18), "dark_wood")                                 # the plinth
    b.box((0, 0, 0.88), (w, d, 1.4), "royal_berry")                                            # the body
    b.cyl((0, 0, 1.58), w / 2, d, "royal_berry", segments=32, rot=X)                           # the arched top
    for k, (r, sw) in enumerate(((0.9, "gold_mid"), (0.8, "apron_pink"), (0.7, "mint"), (0.6, "gold_light"))):
        b.cyl((0, -d / 2 - 0.02 - 0.02 * k, 1.58), r, 0.04, sw, segments=32, rot=X)            # the light bands
    b.cyl((0, -0.56, 1.58), 0.5, 0.04, "night_sky", segments=32, rot=X)                        # the window
    b.cyl((0, -0.6, 1.62), 0.36, 0.04, "fur_charcoal", segments=28, rot=X)                     # the record
    b.cyl((0, -0.63, 1.62), 0.12, 0.03, "gold_light", segments=16, rot=X)
    b.box((0, -0.55, 0.86), (w - 0.1, 0.2, 1.42), "royal_berry", bevel=False)  # the front, over the bands
    b.box((0, -0.66, 1.38), (1.5, 0.04, 0.3), "cream", bevel=False)                            # the song strip
    for i in range(4):
        b.cyl((-0.54 + 0.36 * i, -0.7, 1.38), 0.09, 0.05, ("apron_pink", "mint", "gold_mid", "pastel_sky")[i],
              segments=12, rot=X)
    b.box((0, -0.66, 0.72), (1.5, 0.04, 0.95), "gold_mid", bevel=False)                       # the speaker
    for i in range(5):
        b.box((-0.6 + 0.3 * i, -0.69, 0.72), (0.12, 0.04, 0.8), "dark_wood", bevel=False)
    for sx in (-1, 1):                                                                         # gold side trim
        b.box((sx * (w / 2 + 0.02), -0.3, 0.88), (0.1, 0.4, 1.42), "gold_mid", bevel=False)
    _note(b, -1.55, 1.85, 0.75, "gold_mid")
    _note(b, 1.35, 2.05, 0.6, "apron_pink", tilt=10)
    _note(b, 1.6, 0.95, 0.5, "mint")
    _twinkle(b, -1.35, -0.4, 0.75, 0.35)
    return _fin(b, "Jukebox", mat)


def steady_paw_pack(mat):
    """#1867: the Steady Paw Pack, a crate of 10 Steady Paw jars with a mint paw tag on its front."""
    b = Builder()
    _crate(b, 3.0, 1.5, 0.45)
    out = _fin(b, "SteadyPawPack", mat)
    for r in range(2):
        for i in range(5):
            out += _flask("Steady", mat, (-1.16 + 0.58 * i, 0.34 - 0.66 * r, 0.24 + 0.24 * (1 - r)), 0.42)
    t = Builder()
    t.cyl((0, -0.86, 0.42), 0.5, 0.1, "gold_mid", segments=28, rot=X)                           # the tag
    t.cyl((0, -0.92, 0.42), 0.43, 0.08, "mint", segments=28, rot=X)
    _paw(t, 0, -0.98, 0.4, 0.95, "offwhite")
    return out + _fin(t, "SteadyPawPackTag", mat)


def _heart(r, n=36):
    """Heart outline points (x, y) around (0, 0), counter-clockwise, about r across its half width."""
    pts = []
    for k in range(n):
        a = -2 * math.pi * k / n
        x = 16 * math.sin(a) ** 3
        y = 13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a)
        pts.append((x * r / 16, (y + 2.0) * r / 16))
    return pts


def thank_you_badge(mat):
    """#1867: the Thank You Badge, a gold heart badge (the supporter's heart) with a cream paw, pink ribbon tails."""
    b = Builder()
    for sx in (-1, 1):                                                                         # ribbon tails
        b.box((sx * 0.4, 0.12, -0.5), (0.42, 0.06, 1.2), "apron_pink", rot=(math.radians(sx * -16), "Y"))
        b.prism((sx * 0.57, 0.08, -1.08), [(-0.22, 0.0), (0.22, 0.0), (0.0, 0.22)], 0.07, "cream", rot=X)
    b.prism((0, 0.02, 0.55), _heart(1.35), 0.2, "gold_dark", rot=X)
    b.prism((0, -0.06, 0.55), _heart(1.2), 0.12, "gold_mid", rot=X)
    b.prism((0, -0.12, 0.58), _heart(0.9), 0.06, "gold_light", rot=X)
    _paw(b, 0, -0.17, 0.5, 1.15, "cream")
    _twinkle(b, 1.35, -0.3, 1.55, 0.45)
    _twinkle(b, -1.3, -0.3, 1.35, 0.3)
    return _fin(b, "ThankYouBadge", mat)

PASSES = {"Money2x": money("2"), "Money3x": money("3"), "Money4x": money("4"), "LongNap": long_nap, "VIP": vip,
          "Accessories": accessories_pass, "Uniforms": uniforms, "CafeStyle": cafe_style_pass,
          "GrandTheme": grand_theme_pass,
          "ExtraSlot": extra_slot, "RoyalCat": royal_cat, "KingCat": king_cat, "KingPack": king_pack,
          "GoldenPond": golden_pond,
          "SecondBaitBowl": second_bait_bowl, "SignStylePack": sign_style_pack, "GardenDecorPack": garden_decor_pack,
          "Jukebox": jukebox}
PRODUCTS = {"StarterBundle": starter_bundle, "PotionXS": potion_xs, "PotionS": potion_s, "PotionM": potion_m,
            "PotionL": potion_l, "CafePass": cafe_pass, "SteadyPawPack": steady_paw_pack,
            "ThankYouBadge": thank_you_badge}
# #2578: one look for the whole pass set on the Roblox page, where each icon sits in a circle: icons.py also writes
# CatCafe_Icon_Pass_<Name>_Bg.png, the picture on a soft radial disc with a glow behind it in its family's colour
# (centre, edge), for the Creator Hub pass icon. The transparent picture stays the in-game Store card's.
BG_FAMILIES = {
    "berry": ((236, 150, 186), (142, 42, 74)),          # cats and royalty
    "mint": ((214, 242, 222), (96, 160, 128)),          # cafe looks: uniforms, accessories, styles, signs, decor
    "gold": ((255, 236, 160), (214, 146, 30)),          # money and boosts
    "sky": ((206, 232, 252), (70, 140, 204)),           # cafe items: the slot, the bowl, the pond, the nap
}
BG_OF = {"RoyalCat": "berry", "KingCat": "berry", "KingPack": "berry",
         "Uniforms": "mint", "Accessories": "mint", "CafeStyle": "mint", "GrandTheme": "mint", "SignStylePack": "mint",
         "GardenDecorPack": "mint", "Jukebox": "mint",
         "Money2x": "gold", "Money3x": "gold", "Money4x": "gold", "VIP": "gold",
         "ExtraSlot": "sky", "SecondBaitBowl": "sky", "GoldenPond": "sky", "LongNap": "sky"}
# name -> (yaw, pitch) for icons.py
VIEWS = {"Money2x": (-16.0, 30.0), "Money3x": (-16.0, 30.0), "Money4x": (-16.0, 30.0), "LongNap": (-20.0, 26.0),
         "VIP": (-10.0, 8.0), "Accessories": (-24.0, 8.0), "Uniforms": (-14.0, 8.0), "CafeStyle": (-26.0, 12.0),
         "GrandTheme": (-16.0, 8.0), "ExtraSlot": (-20.0, 14.0), "RoyalCat": (-24.0, 8.0), "KingCat": (-24.0, 8.0),
         "KingPack": (-24.0, 12.0),
         "GoldenPond": (-14.0, 30.0), "SecondBaitBowl": (-18.0, 34.0), "StarterBundle": (-20.0, 16.0),
         "SignStylePack": (-8.0, 6.0), "GardenDecorPack": (-18.0, 24.0),
         "PotionXS": (-12.0, 8.0), "PotionS": (-14.0, 22.0), "PotionM": (-16.0, 26.0), "PotionL": (-16.0, 24.0),
         "CafePass": (0.0, 0.0), "Jukebox": (-18.0, 8.0), "SteadyPawPack": (-16.0, 26.0),
         "ThankYouBadge": (0.0, 0.0)}
