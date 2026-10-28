"""Build every Cat Cafe asset: mesh, FBX + GLB export, preview PNGs, manifest.

Run with the bpy module:      python build_all.py [--render] [--scenes] [--only Tabby,Counter]
Run inside Blender headless:  blender -b -P build_all.py -- [--render] [--scenes]
Run inside the Blender GUI:   Scripting tab, open this file, Run Script (add --no-reset
                               to keep your current scene; objects appear at the origin).

Outputs (relative to the repo root, override with --out and --docs):
  assets/cat-cafe/exports/<Name>.fbx and .glb, CatCafe_Palette.png, CatCafe_VFX_ShinySparkle.png, manifest.json, gates.md
  assets/cat-cafe/rbx/<Name>.model.json (the same model as Roblox Parts, Rojo synced into ReplicatedStorage.Assets)
  docs/concepts/cat-cafe/previews/<Name>.png, views/<Name>.png (five-view sheet), contact sheets, vignettes

Every asset runs through gates.check (budget, transforms, material, UVs, naming as FAIL; pivot
and centering as WARN). The build exits 1 on any FAIL; read exports/gates.md for the reasons.
"""

import argparse
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import accessories  # noqa: E402
import alley  # noqa: E402
import alleyway  # noqa: E402
import areakit  # noqa: E402
import areas  # noqa: E402
import boards  # noqa: E402
import cats  # noqa: E402
import coins  # noqa: E402
import common  # noqa: E402
import crate_decor  # noqa: E402
import decor  # noqa: E402
import furniture  # noqa: E402
import gold  # noqa: E402
import gates  # noqa: E402
import items  # noqa: E402
import neighbourhood  # noqa: E402
import night  # noqa: E402
import doors  # noqa: E402
import market  # noqa: E402
import npc  # noqa: E402
import palette  # noqa: E402
import park  # noqa: E402
import parkset  # noqa: E402
import woodsset  # noqa: E402
import sewerset  # noqa: E402
import neighbourhoodset  # noqa: E402
import plot  # noqa: E402
import poses  # noqa: E402
import props  # noqa: E402
import rbx_export  # noqa: E402
import sewer  # noqa: E402
import spinwheel  # noqa: E402
import square  # noqa: E402
import stations  # noqa: E402
import street  # noqa: E402
import vfx  # noqa: E402
import woods  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MODULES = [cats, gold, npc, furniture, decor, alley, park, items, accessories, street, areas, plot, alleyway, boards,
           night, stations, coins, market, crate_decor, neighbourhood, woods, sewer, spinwheel, square, parkset,
           woodsset, sewerset, neighbourhoodset, doors]

PIVOT_NOTES = {
    "CatCafe_Square_Paving": "The square's centre on its floor top (0, 0.1, 0): the grout slab runs 0.4 below the "
                             "pivot, the stones 0.02 above it. Square space is world space; place with no turn.",
    "CatCafe_Square_Signpost": "Post's foot at (-9, 0.1, -7.5) with no turn: each _Arm<Area> board is aimed in world "
                               "space at its gate, long along its own X, with an Area attribute.",
    "CatCafe_Square_Bunting": "On the ground under the middle of the span; its ends sit inside two lamps 22 apart.",
    "CatCafe_Furniture_WallShelf": "wall: back-bottom center",
    "CatCafe_Decor_WindowPlants": "wall: back-bottom center",
    "CatCafe_Decor_NeonSign": "wall: back-bottom center",
    "CatCafe_Decor_MenuBoard": "wall: back-bottom center",
    "CatCafe_Decor_MuralPrint": "wall: back-bottom center",
    "CatCafe_Decor_MuralPrint_Gold": "wall: back-bottom center",
    "CatCafe_Decor_HangingLamp": "ceiling hook (geometry hangs below the pivot)",
    "CatCafe_Decor_DoorSign": "hook (geometry hangs below the pivot)",
    "CatCafe_Decor_StringLights": "left end of the strand seen from the front; it runs to the right (Roblox -X) and sags below the pivot",
    "CatCafe_Alley_ShopWindow": "wall: back-bottom center",
    "CatCafe_Item_Net_L1": "grip end of the pole; the pole runs forward (Roblox -Z)",
    "CatCafe_Item_Net_L2": "grip end of the pole; the pole runs forward (Roblox -Z)",
    "CatCafe_Item_Net_L3": "grip end of the pole; the pole runs forward (Roblox -Z)",
    "CatCafe_Accessory_Glasses": "attachment point (see attach)",
    "CatCafe_Accessory_BowTie": "attachment point (see attach)",
    "CatCafe_Accessory_Apron": "attachment point (see attach)",
    "CatCafe_Accessory_Hat": "attachment point (see attach)",
    "CatCafe_Accessory_Sash": "attachment point (see attach_upright)",
    "CatCafe_Accessory_PartyHat": "attachment point (see attach_upright)",
    "CatCafe_Neighbourhood_Set": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Woods_Set": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Sewer_Set": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Park_Set": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Woods_SetV32": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Sewer_SetV32": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Neighbourhood_SetV32": "area centre on the floor, gate side -Z: turn it so -Z faces the gate (areakit)",
    "CatCafe_Park_RescueTree": "base center; the Branch pivots at its root on the trunk (part_pivots_roblox)",
    **{f"CatCafe_Plot_Cafe_{c}": "Plot.cframe: floor top centre of the cafe, front -Z to the street" for c in plot.COLOURS},
    "CatCafe_Plot_Interior": "Plot.cframe: floor top centre of the cafe",
    "CatCafe_Plot_ForRent": "Plot.cframe: floor top centre of the cafe",
    **{f"CatCafe_Plot_Tier{n}": "Plot.cframe: floor top centre of the cafe" for n in range(1, 6)},
    "CatCafe_Plot_ClosedSign": "Plot.cframe: floor top centre of the cafe",
    **{n: "wall: back plane at the bottom centre; -Z faces into the alley" for n in
       ("CatCafe_Alley_WallWindows", "CatCafe_Alley_WallDoor", "CatCafe_Alley_FireEscape", "CatCafe_Alley_Mural")},
    "CatCafe_Alley_ArchStreet": "base centre of the 36 stud opening; -Z faces the street",
    "CatCafe_Alley_Arch": "base centre of the 26 stud opening; -Z faces the back alley",
    **{f"CatCafe_{a}_Gate": "base centre of the opening; -Z faces the side players come from" for a in
       ("Park", "Neighbourhood", "Woods", "Sewer")},
    **{n: f"the pivot of {h}: place it there with no offset" for n, h in night.HOSTS.items()},
    "CatCafe_Alley_NightFenceSegment": "base centre of the 8 stud piece; -Z faces the cafe side",
    "CatCafe_Plot_BackDoorClosed": "Plot.cframe: floor top centre of the cafe",
    "CatCafe_Plot_BackDoor": "Plot.cframe: floor top centre of the cafe; the _Leaf pivot is the hinge",
    "CatCafe_Street_CodesCat": "base centre; the desk front (-Z) faces the players",
    "CatCafe_Street_FishMarket": "base centre; the counter front (-Z) faces the players",
    "CatCafe_Prop_FishCoin": "base centre: the coin stands on its rim, the cat face toward -Z; spin it about Y",
}
STUDIO_NOTES = {
    "CatCafe_Decor_NeonSign": "Tube: Material Neon, add PointLight (neon_pink). Board stays SmoothPlastic.",
    "CatCafe_Decor_FishTank": "Glass: Transparency 0.5. Water: Transparency 0.3, Material Glass.",
    "CatCafe_Decor_HangingLamp": "Bulb: Material Neon + PointLight 255,214,170 range 14.",
    "CatCafe_Alley_StreetLamp": "Bulb: Material Neon + SpotLight pointing down, warm.",
    "CatCafe_Park_Fountain": "Water: Transparency 0.3. Optional ParticleEmitter at the top ball.",
    **{f"CatCafe_{a}_Gate": "Area gate. Bars (ForceField, directly under the gate) fills the opening up to 12 studs: "
                            "keep it solid and Transparency 0.35 below the tier, CanCollide false and fade it once open. "
                            "Requirement SurfaceGui on the -Z face of the part named SignBoard (10 x 2.5). "
                            "Turn the Park, Woods and Sewer gates 180 degrees so -Z faces the street or back alley."
       for a in ("Park", "Neighbourhood", "Woods", "Sewer")},
    "CatCafe_Alley_ArchStreet": "Over the street's north end at (0, 123.5). Posts collide; ALLEY SQUARE reads from the "
                                "street, CAFE STREET from the square.",
    "CatCafe_Alley_Arch": "Over each back alley's north end at (+-78, 123.5). Posts collide; ALLEY SQUARE reads from the "
                          "back alley, BACK ALLEY from the square.",
    **{n: "Against the inner face of an alley wall, -Z into the alley; 30 wide, taller than the wall. _Pane parts glow "
          "at night." for n in ("CatCafe_Alley_WallWindows", "CatCafe_Alley_WallDoor", "CatCafe_Alley_Mural")},
    "CatCafe_Alley_FireEscape": "As the other wall pieces. Landings and the ladder rungs collide: landing_1 (top 9.35) "
                                "is reachable from CatCafe_Alley_CrateStack (top 7.7) placed just past its open left end "
                                "(local x -8) with the tall column toward it, or up the ladder at x 5.5; stairs lead to "
                                "landing_2 (17.35). See ledges_roblox.",
    "CatCafe_Alley_CrateStack": "Solid crates in steps of 2.6 (tops 0.5, 2.5, 5.1, 7.7 from -X to +X).",
    "CatCafe_Alley_LaundryLine": "Poles collide, the line and clothes (_Decor) do not. Lines at 9.5 to 10.5 studs.",
    "CatCafe_Alley_StringLightsLong": "Poles 28 apart, so it spans a 30 stud back alley; _Bulbs glow at night.",
    "CatCafe_Sewer_Manhole": "Slide or hide the child Model _Cover to open it; the requirement SurfaceGui goes on the "
                             "-Z face of the part named SignBoard on the post.",
    "CatCafe_Furniture_Counter": "CollisionFidelity Hull. Sit pad on the left end is the counter spot.",
    "CatCafe_Furniture_CatTree": "CollisionFidelity Hull. F79 bedtime: Attachments Sleep_Top (the top cushion, the "
                                 "entertainer's sit point) and Sleep_Shelf (the lower shelf) take a sleeping cat's "
                                 "pivot, facing their LookVector; Foot is the floor spot it hops up from.",
    "CatCafe_Furniture_CatBed": "F79 bedtime: Tier 3 to 5 dressing, standing on the floor at the plot's bed spots. "
                                "Attachment Sleep (the cushion) takes a sleeping cat's pivot, facing the bed's front "
                                "dip (-Z); Foot is the floor 1.5 in front. 2.6 across.",
    "CatCafe_Alley_Dumpster": "CollisionFidelity Hull.",
    "CatCafe_Alley_TrashBin": "Rescue trap trash_bin. Put the stuck cat at stuck_pose. The Lid turns about its "
                              "part_pivots_roblox point (the hinge) to rattle on a hit. CollisionFidelity Box on the Bin.",
    "CatCafe_Alley_GarbageBags": "Rescue trap garbage_bag. Put the stuck cat at stuck_pose; the front bag hides its body. "
                                 "CollisionFidelity Hull.",
    "CatCafe_Park_RescueTree": "Rescue trap tree (shake_catch). To wobble, rotate the Branch about its part_pivots_roblox point "
                               "(set Branch.PivotOffset there if the import centres it). Put the cat at stuck_pose, then "
                               "weld its Body to the Branch so it moves with it. CollisionFidelity Hull on the Trunk.",
    "CatCafe_Park_TrashCan": "Rescue trap trashcan. Put the stuck cat at stuck_pose. The Lid turns about its "
                             "part_pivots_roblox point (the back of the rim). CollisionFidelity Hull on the Can.",
    "CatCafe_Alley_ShopWindow": "Pane: day = Color glass, Material Glass, Transparency 0.5; night = Material Neon, Color lamp_warm, Transparency 0.3, plus a PointLight (Brightness 0.8, Range 10).",
    "CatCafe_Decor_DoorSign": "Show Open by day and Closed at night (Clock.Phase). Hang on the door at eye height.",
    "CatCafe_Decor_StringLights": "Bulbs: Neon lamp_warm at night with one soft PointLight per strand (Brightness 0.8, Range 10); SmoothPlastic by day.",
    "CatCafe_Item_Net_L1": "Tool Handle = _Handle. Bag: Transparency 0.35. Grip at the pivot.",
    "CatCafe_Item_Net_L2": "Tool Handle = _Handle. Bag: Transparency 0.35. Grip at the pivot.",
    "CatCafe_Item_Net_L3": "Tool Handle = _Handle. Bag: Transparency 0.35. Grip at the pivot.",
    **{f"CatCafe_Plot_Cafe_{c}": "Replaces the code-built walls, door header, windows and sign. Walls and glass collide. "
                                 "The child Model <name>_Roof (roof, ridge, chimney) fades for the owner inside. Put the "
                                 "owner sign's SurfaceGui on the -Z face of the part named SignBoard (16 x 3.2 studs). "
                                 "Doors: front 7 wide at x 0, back 6 wide at x -8, both 7.5 high. Front garden z -20..-15. "
                                 "F53: the walls' pastel outer layer is the child Model <name>_Paint (every part tagged "
                                 "Paint) and their cream inner layer <name>_Wallpaper (tagged Wallpaper)."
       for c in plot.COLOURS},
    "CatCafe_Plot_Interior": "Every plot. Big parts collide. HangingLamp bulbs are Neon all day; StringLights Bulbs glow at night.",
    "CatCafe_Plot_ForRent": "Only while OwnerUserId is 0: half-down shutters, FOR RENT sign, dust sheets over the counter, "
                            "boxes and a broom, a sleeping Tabby on the door mat (decor, not catchable).",
    **{f"CatCafe_Plot_Tier{n}": "Cumulative: place every tier up to the cafe's tier." for n in range(1, 6)},
    **{n: f"F66: only while the areas are closed (Clock AreasOpen false), at the pivot of {h}. The fence collides "
          "(8 studs to the rail tops, above a jump) and stands just behind the gate's Bars, so the Bars and the "
          "requirement sign stay as they are; the child Model _Moon_Bulb (moon, stars, CLOSED and OPENS AT SUNRISE) "
          "glows at night and does not collide. Tag NightFence." for n, h in night.HOSTS.items()},
    "CatCafe_Alley_NightFenceSegment": "F66: only while the areas are closed. Tile it end to end every 8 studs along the "
                                       "back alleys' inner edges (the SAFE ZONE stripes) and across the side passages, -Z "
                                       "toward the cafes; each piece has a post at both ends. Collides, 8 studs to the rail "
                                       "tops; _Moon_Bulb glows. Tag NightFence.",
    "CatCafe_Plot_BackDoorClosed": "F66: owned cafes while the areas are closed, at the Plot pivot. A door shut in the "
                                   "6 x 7.5 back door (x -11..-5), so it collides; the CLOSED UNTIL SUNRISE sign faces "
                                   "the back alley (+Z) and its child Model _Sign_Bulb glows. Tag NightFence.",
    "CatCafe_Plot_BackDoor": "Every cafe, at the Plot pivot: a wooden door hung in the back doorway with a cat flap. "
                             "Turn the child Model _Leaf about its pivot's Y to swing it (-90 degrees is wide open, out "
                             "into the yard); _Flap rides the leaf and turns about its own X as a cat goes through. "
                             "_Sign (CLOSED UNTIL SUNRISE) is for the night, its _Sign_Bulb glows. The leaf's CatFlap "
                             "Attachment is where an F80 flap goes (hide _Flap then). Nothing collides: keep the code "
                             "panel as the collider.",
    "CatCafe_Street_CodesCat": "F65: the Codes Cat in the street plaza, tag CodesCat. Walking into the part named "
                               "CodesCircle (a flat Neon disc 8 studs across, centre 6 studs in front of the pivot, "
                               "CanCollide off, CanTouch on, inside the child Model _CodesCircle) opens the code box; "
                               "_Glow (its rim and ticket) is Neon all day. The Attachment PromptAnchor (desk front, 3 "
                               "studs up) stays for a prompt if one is wanted. The kiosk collides; the cat is decor "
                               "with the usual hinged pieces (child Models <name>_Cat_Head with its eyes and ears, "
                               "_Cat_Tail, _Cat_LegF1, _Cat_LegF2) and its cap (_Cat_Prop) rides inside the Head Model. "
                               "_Bulb (the sign lamp) glows at night.",
    "CatCafe_Plot_ClosedSign": "F44: owned cafes at night only (Clock.Phase), at the Plot pivot. Hangs in the front door "
                               "above head height; nothing collides. The child Model _Moon_Bulb glows at night.",
    **{f"CatCafe_Cat_{n}_Sit": f"Body B, sitting up: clone this instead of CatCafe_Cat_{n} for a cat resting in the "
                                "cafe or working at a station. Put the role's outfit pieces on its Outfit_<Piece> "
                                "Attachments. Parts with their own joint (Head with the eyes and ears, Tail, LegF1, "
                                "LegF2) are Models pivoted at the joint, for poses (manifest cat_poses)."
       for n in cats.ROSTER},
    **{f"CatCafe_Cat_{n}_Gold{sfx}": f"F42: clone this instead of CatCafe_Cat_{n}{sfx} when the cat is gold. Same "
                                      "parts, joints, attachments and poses; only the coat colours differ (style guide 2)."
       for n in cats.ROSTER for sfx in cats.SUFFIX.values()},
    "CatCafe_Street_FishMarket": "F53: the Golden Fish Market in the street plaza (x -8.5, z 64, rotY -90); WorldBuilder "
                                 "tags it FishMarket and hangs the Shop prompt on the Attachment PromptAnchor (counter "
                                 "front, 3 up). The shopkeeper cat's sou'wester rides its Head Model; the sign Bulb is "
                                 "lit at night.",
    "CatCafe_Prop_FishCoin": "F52: the golden fish coin, a world pickup or prize; gold parts are Metal. Its HUD picture "
                             "is exports/icons/CatCafe_Icon_GoldenFish.png (icons.py).",
}


for _n in crate_decor.ASSETS:                   # F53 crate pieces: the server clones them onto decor spots
    _index = _n.endswith(("MailboxPlanter", "MushroomLamp", "PipeFountain"))
    STUDIO_NOTES[_n] = ("F53 crate piece: " + ("its zone's Epic, on the Index anchor or a decor spot" if _index
                        else "on a decor spot, 1.4 studs off the wall") + "; pivot base centre, front -Z, no "
                        "collision (CatCafe_Decor_). _Glow parts are Neon all day, _Water is Glass 0.3, _Glass "
                        "Glass 0.45. The server sets DecorId, so a Mythical's effect finds it.")

for _n, _spec in cats.ROSTER.items():           # glowing eyes (Void, Aurora): Neon eye parts in Studio
    if _spec.get("glow_eyes"):
        for _v in (f"CatCafe_Cat_{_n}{g}{sfx}" for g in ("", "_Gold") for sfx in cats.SUFFIX.values()):
            STUDIO_NOTES[_v] = (STUDIO_NOTES.get(_v, "") + " Glowing eyes: set the parts of the Eye1 and Eye2 Models "
                                "to Neon.").strip()
    if props.slot(_n):                          # themed cats (data-model 3): the prop is part of the model
        _rides = "the Body" if props.slot(_n) == "Back" else "the Head (its Model is inside the Head Model)"
        for _v in (f"CatCafe_Cat_{_n}{g}{sfx}" for g in ("", "_Gold") for sfx in cats.SUFFIX.values()):
            STUDIO_NOTES[_v] = (STUDIO_NOTES.get(_v, "") + f" Prop: the {props.slot(_n)} prop is the child Model "
                                f"<name>_Prop (and <name>_Prop_Glass, Glass) and rides {_rides}; PropSlot = "
                                f"{props.slot(_n)}, so CatPose.dress leaves that slot's role piece off.").strip()


def cat_rbx_extras(name):
    """A cat's Part model carries its Scale and, on a sitting model (where working cats wear their outfits), one
    Attachment per role outfit piece (Outfit_<Piece>) at that piece's slot, times the scale, in the Body or Head part,
    so the game needs no manifest at runtime. A themed cat also carries PropSlot (Head, Face or Back) and its prop's
    parts carry Follows (Head or Body); a Head or Face prop's Model rides inside the Head Model."""
    cat, _gold, body = cats.parse(name)
    spec = cats.ROSTER[cat]
    s = spec.get("scale", 1.0)
    attachments = []
    if body == "sit":
        joints = cats.joints(spec, body)
        pieces = {p for outfit in accessories.ROLE_OUTFITS.values() for p in outfit}
        for n, (part, off, r) in accessories.slots(spec, body).items():
            if n in pieces:
                turn = Euler([math.radians(a) for a in r], "XYZ").to_matrix().to_4x4()
                attachments.append(("_" + part, "Outfit_" + n,
                                    Matrix.Translation(Vector(joints[part]) + Vector(off) * s) @ turn))
    extras = {"attachments": attachments, "attributes": {"Scale": {"Float64": float(s)}}}
    slot = props.slot(cat)
    if slot:                                # a themed cat's prop: its slot, and which piece its parts follow
        rides = "Body" if slot == "Back" else "Head"
        extras["attributes"]["PropSlot"] = slot
        extras["part_attributes"] = {"_Prop": {"Follows": rides}, "_Prop_Glass": {"Follows": rides}}
        if rides == "Head":
            extras["nest"] = {"_Prop": "_Head", "_Prop_Glass": "_Head"}
    return extras


def _slot_entry(part, off, r, s=1.0):
    off = [v * s for v in off]
    return {"part": part, "offset": [round(v, 3) for v in off], "offset_roblox": common.to_roblox(off),
            "angles_roblox_deg": common.euler_to_roblox(r)}


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else (argv[1:] if not bpy.app.binary_path or argv[0].endswith(".py") else [])
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=os.path.join(ROOT, "assets", "cat-cafe", "exports"))
    p.add_argument("--docs", default=os.path.join(ROOT, "docs", "concepts", "cat-cafe"))
    p.add_argument("--render", action="store_true", help="render a preview PNG and a five-view sheet per asset")
    p.add_argument("--no-views", action="store_true", help="with --render: skip the five-view sheets")
    p.add_argument("--views-engine", choices=common.VIEW_ENGINES, default="auto",
                   help="sheet renderer; auto = Workbench where it can run, else Cycles CPU")
    p.add_argument("--scenes", action="store_true", help="render the cafe and alley vignettes")
    p.add_argument("--no-export", action="store_true")
    p.add_argument("--rbx", default=os.path.join(ROOT, "assets", "cat-cafe", "rbx"),
                   help="where the Part-built .model.json files go (Rojo syncs them into ReplicatedStorage.Assets)")
    p.add_argument("--no-rbx", action="store_true", help="skip the Part-built Roblox models")
    p.add_argument("--no-reset", action="store_true", help="keep the current scene (GUI use)")
    p.add_argument("--only", default="", help="comma list of name fragments to build")
    p.add_argument("--samples", type=int, default=32)
    return p.parse_args(argv)


def all_assets():
    out = {}
    for m in MODULES:
        for name, (fn, budget) in m.ASSETS.items():
            out[name] = (fn, budget, m.__name__)
    return out


def main():
    args = parse_args()
    t0 = time.time()
    if not args.no_reset:
        common.reset_scene()
    os.makedirs(args.out, exist_ok=True)
    png = os.path.join(args.out, palette.TEXTURE_NAME + ".png")
    palette.write_palette_png(png)
    mat = common.palette_material(png)
    sparkle_png = vfx.write_sparkle_png(os.path.join(args.out, vfx.SPARKLE + ".png"))

    wanted = [s.strip() for s in args.only.split(",") if s.strip()]
    manifest, failed, built = [], [], {}
    if args.render and not args.no_views:
        print("view sheets:", common.resolve_views_engine(args.views_engine))
    for name, (fn, budget, module) in all_assets().items():
        if wanted and not any(w.lower() in name.lower() for w in wanted):
            continue
        objs = fn(mat)
        built[name] = objs
        extra = cat_rbx_extras(name) if name.startswith("CatCafe_Cat_") else {}
        if name in boards.AREA_OF:                # the UI finds an Index Board by its tag and Area
            extra = {"attributes": {"Area": boards.AREA_OF[name]}}
        if name == "CatCafe_Street_CodesCat":     # the prompt's spot, and the cap rides the cat's Head
            extra = {"attachments": [stations.prompt_attachment()], "nest": {"_Prop": "_Head"}}
        if name == "CatCafe_Street_SpinWheel":    # the Spin prompt's spot; the host's hat rides its Head, its outfit its Body
            extra = {"attachments": [spinwheel.prompt_attachment()], "nest": {"_Prop": "_Head", "_Outfit": "_Body"}}
        if name == "CatCafe_Street_FishMarket":   # the Shop prompt's spot, and the hat rides the cat's Head
            extra = {"attachments": [market.prompt_attachment()], "nest": {"_Prop": "_Head"}}
        if name == "CatCafe_Furniture_CatTree":   # F79 sleep spots: pedestals, hops and the foot (furniture.TREE_SPOTS)
            extra = {"attachments": furniture.spot_attachments(name, furniture.TREE_SPOTS)}
        if name == "CatCafe_Furniture_CatBed":
            extra = {"attachments": furniture.spot_attachments(name, furniture.BED_SPOTS)}
        if name == "CatCafe_Decor_CatTreeTower":
            extra = {"attachments": furniture.spot_attachments(name, crate_decor.TOWER_SPOTS)}
        if name == doors.NAME:                    # the leaf's CatFlap spot; glass, flap and sign ride the leaf
            extra = {"attachments": [doors.cat_flap_attachment()], "nest": doors.NEST}
        if name == "CatCafe_Square_Signpost":     # each arm's Area, for the UI to draw its name and lock on
            extra = {"part_attributes": square.ARM_ATTRIBUTES}
        rbx_path, rbx_parts = (None, 0) if args.no_rbx else rbx_export.write_model(objs, name, args.rbx, **extra)
        tris = common.tri_count(objs)
        lo, hi = common.bounds(objs)
        size = [round(v, 2) for v in (hi - lo)]
        entry = {
            "name": name, "category": name.split("_")[1], "module": module,
            "objects": [o.name for o in objs], "triangles": tris, "budget": budget,
            "size_studs": {"x": size[0], "y": size[1], "z": size[2]},     # Blender axes, z is height
            "size_roblox": [size[0], size[2], size[1]],                    # width, height, depth
            "bounds_min": [round(v, 2) for v in lo], "bounds_max": [round(v, 2) for v in hi],
            "pivot": PIVOT_NOTES.get(name, "base center (floor contact)"),
            "front": "-Z in Roblox, the LookVector (Blender -Y)",
        }
        moved = {o.name: list(o.location) for o in objs if o.location.length > 1e-6}
        if moved and not name.startswith("CatCafe_Cat_"):   # parts with their own pivot (gate leaves, tree branch); cats use joints
            entry["part_pivots"] = {k: [round(v, 2) for v in p] for k, p in moved.items()}
            entry["part_pivots_roblox"] = {k: common.to_roblox(p) for k, p in moved.items()}
        if name.startswith("CatCafe_Square_"):    # Layout.townSquare.props: world x, floor top y, z, turn about Y
            entry["placements_roblox"] = [[x, 0.1, z, r] for (n, x, z, r) in square.PLACEMENTS if n == name]
        if name in areakit.POINTS:                # spots inside an area set (cat spawns, traps), area-space Roblox x, z
            entry["points_roblox"] = areakit.POINTS[name]
        if name in furniture.SIT_POINTS:
            entry["sit_point"] = list(furniture.SIT_POINTS[name])
            entry["sit_point_roblox"] = common.to_roblox(furniture.SIT_POINTS[name])
        if name.startswith("CatCafe_Cat_"):
            cat, is_gold, body = cats.parse(name)
            spec = cats.ROSTER[cat]
            entry["rarity"] = spec["rarity"]
            entry["body"] = body                        # walk (A, on all fours) or sit (B, sitting up)
            entry["gold"] = is_gold
            look = gold.gold_spec(cat) if is_gold else spec
            entry["pattern"] = look["pattern"]          # colors by field, as swatch and hex, for any future cat model
            entry["coat"] = {k: {"swatch": sw, "hex": palette.SWATCHES[palette.idx(sw)][1]}
                             for k, sw in cats.coat(look).items()}
            s_ = spec.get("scale", 1.0)
            entry["scale"] = s_                     # scale accessories by this too
            joints = cats.joints(spec, body)        # every hinged piece's pivot (Head, Tail, legs, eyes, ears)
            entry["joints"] = {k: [round(v, 3) for v in j] for k, j in joints.items() if k != "Body"}
            entry["joints_roblox"] = {k: common.to_roblox(j) for k, j in joints.items() if k != "Body"}
            entry["attachments"] = {k: _slot_entry(p, o, r, s_) for k, (p, o, r) in accessories.slots(spec, body).items()}
            if props.slot(cat):
                entry["prop"] = {"slot": props.slot(cat), "objects": [o.name for o in objs if "_Prop" in o.name],
                                 "follows": "Body" if props.slot(cat) == "Back" else "Head"}
            lifts = {k: cats.pose_lift(spec, v) for k, v in poses.CAT_POSES.items() if v["body"] == body and "lift" in v}
            if lifts:                               # already times the cat's scale
                entry["pose_lifts_roblox"] = {k: common.to_roblox([c * cats.scale_of(spec, body) for c in v])
                                              for k, v in lifts.items()}
        if name.startswith("CatCafe_Accessory_"):
            n = name.split("_")[-1]
            if n in accessories.SIT_SLOTS:
                entry["slot"] = dict(_slot_entry(*accessories.SIT_SLOTS[n]), body="sit")
            elif n in accessories.slots(cats.ROSTER["Tabby"], "walk"):
                entry["slot"] = dict(_slot_entry(*accessories.slots(cats.ROSTER["Tabby"], "walk")[n]), body="walk")
        if name == "CatCafe_Street_FishMarket":
            entry["prompt_anchor_roblox"] = list(market.PROMPT_ROBLOX)
        if name == "CatCafe_Street_DealerCart":
            entry["display_slots"] = [list(p) for p in street.DISPLAY_SLOTS]
            entry["display_slots_roblox"] = [common.to_roblox(p) for p in street.DISPLAY_SLOTS]
        if name.startswith("CatCafe_Item_") and name.split("_")[-1] in items.FOODS:
            entry["food_in_bowl_roblox"] = [0, items.FOOD_IN_BOWL, 0]
        if name in alleyway.LEDGES:
            entry["ledges_roblox"] = {k: list(v) for k, v in alleyway.LEDGES[name].items()}
        if name.endswith("_Gate") and name in areas.ASSETS:
            entry["sign_board_roblox"] = areas.SIGN_INFO
        if name.startswith("CatCafe_Plot_Cafe_"):
            entry["chimney_top_roblox"] = list(plot.CHIMNEY_TOP)
            entry["sign_board_roblox"] = plot.SIGN_INFO
        if name in boards.AREA_OF:
            host, (px, py, pz, turn) = boards.PLACEMENT[boards.AREA_OF[name]]
            entry["area"] = boards.AREA_OF[name]
            entry["screen"] = {"part": "Screen", "face": "Front (-Z)", "size": [boards.W, boards.H]}
            entry["placement"] = {"relative_to": host, "offset_roblox": [px, py, pz], "turn_y_deg": turn,
                                  "use": "host:GetPivot() * CFrame.new(offset) * CFrame.Angles(0, math.rad(turn), 0)"}
        if name in night.HOSTS:
            entry["placement"] = {"relative_to": night.HOSTS[name], "offset_roblox": [0, 0, 0], "turn_y_deg": 0,
                                  "use": "host:GetPivot()"}
        if name == "CatCafe_Street_CodesCat":
            entry["prompt_anchor_roblox"] = list(stations.PROMPT_ROBLOX)
            entry["codes_circle"] = {"part": "CodesCircle", "centre_roblox": [0, 0.05, stations.CIRCLE_Z],
                                     "radius": stations.CIRCLE_R}
        if name in poses.STUCK_POSES:
            entry["stuck_pose"] = poses.manifest_pose(poses.STUCK_POSES[name])
        if name in STUDIO_NOTES:
            entry["studio"] = STUDIO_NOTES[name]
        if rbx_path:
            entry["rbx_model"] = os.path.relpath(rbx_path, ROOT)
            entry["rbx_parts"] = rbx_parts
        if not args.no_export and not name.endswith(("_Gold", "_Gold_Sit")):    # gold cats are Part models only
            entry["files"] = [os.path.relpath(p, ROOT) for p in common.export_asset(objs, name, args.out)]
        entry["gates"] = gates.check(objs, name, budget, tris, lo, hi, PIVOT_NOTES.get(name), mat)
        if args.render:
            path = os.path.join(args.docs, "previews", name + ".png")
            visible = [o for o in objs if not o.name.endswith(("_Glass", "_Fireflies", "_Climb", "_Barrier"))] or objs   # glass is opaque in Cycles here; firefly volumes are air
            shifted = [o for o in objs if o.name.endswith("_Closed")]            # show both sign faces side by side
            for o in shifted:
                o.location.x += 3.2
            common.render_preview(visible, path, samples=args.samples,
                                 warm=not name.startswith("CatCafe_Alley_"), floor=True)
            for o in shifted:
                o.location.x -= 3.2
            entry["preview"] = os.path.relpath(path, ROOT)
            vpath = os.path.join(args.docs, "views", name + ".png")
            if not args.no_views:
                common.render_views(visible, vpath, engine=args.views_engine)
            if os.path.exists(vpath):                 # --no-views keeps pointing at the earlier views
                entry["views"] = os.path.relpath(vpath, ROOT)
        else:                                     # keep pointing at earlier renders
            for key, sub_dir in (("preview", "previews"), ("views", "views")):
                path = os.path.join(args.docs, sub_dir, name + ".png")
                if os.path.exists(path):
                    entry[key] = os.path.relpath(path, ROOT)
        g = entry["gates"]
        flag = "ok" if g["pass"] else "FAIL " + ",".join(g["failed"])
        if g["warnings"]:
            flag += "  warn " + ",".join(g["warnings"])
        if not g["pass"]:
            failed.append(name)
        print(f"{name:44s} tris {tris:5d} / {budget:5d} parts {rbx_parts:4d} {flag}  size {size}")
        manifest.append(entry)

    mpath = os.path.join(args.out, "manifest.json")
    if wanted and os.path.exists(mpath):          # partial build: merge into the existing manifest
        with open(mpath) as f:
            old = {e["name"]: e for e in json.load(f).get("assets", [])}
        old.update({e["name"]: e for e in manifest})
        order = list(all_assets().keys())
        manifest = sorted(old.values(), key=lambda e: order.index(e["name"]) if e["name"] in order else 999)
    with open(mpath, "w") as f:
        json.dump({"generated": time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime()), "units": "studs",
                   "palette": os.path.relpath(png, ROOT),
                   "pose_convention": poses.__doc__.strip().splitlines()[-5:],
                   "poses": {k: poses.manifest_pose(v) for k, v in poses.POSES.items()},
                   "cat_poses": {k: poses.manifest_cat_pose(v) for k, v in poses.CAT_POSES.items()},
                   "role_outfits": accessories.ROLE_OUTFITS,
                   "sit_slots": {k: _slot_entry(*v) for k, v in accessories.SIT_SLOTS.items()},
                   "textures": {vfx.SPARKLE: vfx.manifest_entry(sparkle_png, ROOT)},
                   "assets": manifest}, f, indent=2)
    gates.write_report(os.path.join(args.out, "gates.md"), manifest, ROOT)

    if args.render:
        poses.render_pose_previews(built, mat, args.docs, samples=args.samples)
        vfx.render_sparkle_preview(built, sparkle_png, os.path.join(args.docs, "previews", vfx.SPARKLE + ".png"),
                                   samples=args.samples)
        import contact_sheet
        contact_sheet.build_sheets(args.docs, manifest)
    if args.scenes:
        import scenes
        scenes.render_all(built, mat, args.docs, samples=max(args.samples, 48))

    print(f"built {len(manifest)} assets in {time.time() - t0:.0f}s; gates report: {os.path.join(args.out, 'gates.md')}")
    if failed:
        print("GATES FAILED:", ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
