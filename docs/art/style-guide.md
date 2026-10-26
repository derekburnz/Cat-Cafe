# Cat Cafe art style guide

Game: Cat Cafe (working title "Purr Pot"). Direction: **Cozy Cream** (default from the Three Game Sketches page, 2026-10-25; Pastel Pop and Alley Night remain as alternates if Derek or Gavin pick them). Every asset, Studio placeholder and UI color should come from this file. Change the file first, then the assets.

## 1. Mood in one paragraph

A quiet afternoon in a small cafe. Cream walls, caramel wood, mint accents and warm lamp light. The room is calm and low-contrast so the cats are the color in it. Shapes are soft blocks: chunky, rounded, toy-like, never thin or spiky. The alley out back is the same world after hours: cool grey-blue concrete and brick with one warm street lamp, so catching trips feel like a small adventure and the cafe feels like coming home.

## 2. Palette

All colors live in one shared texture, `CatCafe_Palette.png` (256 x 256, an 8 x 8 grid of 32 px swatches). Every mesh in the game UV-maps each face to the center of one swatch, so one material and one texture cover every prop and every cat. Variants (a Tabby versus a Grey cat) are the same mesh with different swatch indices, not different textures.

Swatch index is `row * 8 + col`, rows counted from the top of the image. Hex values are the source of truth; the texture is generated from them by `assets/cat-cafe/blender/palette.py`.

### Row 0: cafe interior (the Cozy Cream base)

| idx | name | hex | use |
|---|---|---|---|
| 0 | cream | #F6EBDD | walls, counter top, table tops |
| 1 | caramel_wood | #C98A4B | counter body, chairs, shelves, floor planks |
| 2 | dark_wood | #5E4634 | table legs, frames, menu board, outlines |
| 3 | mint | #8FD3C1 | accents: cushions, mugs, awning, espresso machine |
| 4 | blush | #E8A0A0 | cushions, rugs, cake frosting, premium bowl |
| 5 | offwhite | #FFF9F2 | cups, saucers, napkins, counter trim |
| 6 | lamp_warm | #FFD9A8 | lamp shades, lit bulbs (pair with Neon or a PointLight in Studio) |
| 7 | floor_tile | #E9D9C4 | cafe floor, pale tile |

### Row 1: cat fur

| idx | name | hex | cats |
|---|---|---|---|
| 8 | fur_orange | #E9A24B | Tabby base |
| 9 | fur_orange_dark | #B8732B | Tabby stripes |
| 10 | fur_black | #2B2B35 | Tuxedo, Void |
| 11 | fur_white | #F7F1E6 | Tuxedo chest, Snow, Calico base, Siamese body |
| 12 | fur_grey | #8E96A3 | Grey, Smoke base |
| 13 | fur_cream | #EFD9B4 | Cream cat, Siamese body |
| 14 | fur_brown | #7A4F2E | Tortie patches, Siamese points, Calico patches |
| 15 | fur_golden | #F2C14E | Golden (Legendary) |

### Row 2: cat details and rarity

| idx | name | hex | use |
|---|---|---|---|
| 16 | eye_green | #6FCF97 | Common eyes |
| 17 | eye_amber | #F2B134 | Tabby, Tortie eyes; Void glow eyes |
| 18 | eye_blue | #5FA8FF | Siamese, Snow eyes |
| 19 | nose_pink | #E07A8C | noses, inner ears, paw pads |
| 20 | rarity_common | #8E97B2 | Common collars |
| 21 | rarity_rare | #5FA8FF | Rare collars |
| 22 | rarity_epic | #C07CFF | Epic collars |
| 23 | rarity_legend | #FFC94D | Legendary collars, gold trim |

### Row 3: alley

| idx | name | hex | use |
|---|---|---|---|
| 24 | brick | #9C5F4F | alley walls (Studio Parts can use Brick material with this color) |
| 25 | concrete | #8B8F99 | ground, curbs, trash can |
| 26 | concrete_dark | #5B5F6B | shadows, wet patches, dumpster wheels |
| 27 | dumpster_green | #3F6F5E | dumpster body |
| 28 | metal | #A9AFB8 | lids, lamp post, tuna can |
| 29 | rust | #7A4A2A | rust stripes, old crates |
| 30 | cardboard | #C9A273 | boxes, pallets |
| 31 | puddle | #6E8FB3 | puddles, night-sky accents |

### Row 4: customers (NPC)

| idx | name | hex | use |
|---|---|---|---|
| 32 | skin_light | #F3C9A2 | |
| 33 | skin_tan | #C98E6A | |
| 34 | skin_deep | #7A4B32 | |
| 35 | shirt_blue | #3C7DD9 | |
| 36 | shirt_red | #D9483B | |
| 37 | shirt_green | #4E9A3C | |
| 38 | pants_navy | #2F3E5C | |
| 39 | hair_brown | #5A3A22 | hair, also the barista apron strap |

### Row 5: items and food

| idx | name | hex | use |
|---|---|---|---|
| 40 | bowl_red | #D94C3B | basic food bowl |
| 41 | kibble | #B07B4F | kibble, cookie base |
| 42 | fish_blue | #6EC1FF | fish, tuna label |
| 43 | fish_belly | #DDF2FF | fish underside |
| 44 | treat_tan | #E3B77A | treats, croissants |
| 45 | choco | #4A2E1F | cookie dots, coffee |
| 46 | milk | #FFFFFF | milk, foam, glass highlights |
| 47 | leaf_green | #5FB85A | plants |

### Row 6: extra plants and glass

| idx | name | hex | use |
|---|---|---|---|
| 48 | leaf_dark | #3E7F4E | plant shadow leaves |
| 49 | terracotta | #C47A58 | plant pots |
| 50 | glass | #CFE9E3 | display case glass (set Transparency 0.5 in Studio) |
| 51 | sign_teal | #1FA58F | cafe sign, UI accent |
| 52 | night_sky | #1F2A44 | Alley Night alternate, window at night |
| 53 | neon_pink | #FF6B81 | neon sign (Alley Night alternate) |
| 54 | sparkle | #FFF4B0 | Legendary sparkles, star specks |
| 55 | galaxy_blue | #3B4C8C | Galaxy cat base |

Row 7 (56 to 63) is spare. Add new colors there and record them here before using them.

## 3. Shape language

- Soft blocks. Every hard edge gets a 0.06 stud chamfer (a one-segment bevel; two segments only on the hero counter top). Nothing is razor-thin: minimum thickness 0.1 stud, minimum feature size 0.15 stud. Legs and posts are at least 0.15 stud across.
- Chunky proportions. Heads are big, legs are short, props are about 10 percent wider and squatter than real life.
- Flat shading, flat colors. No gradients, no normal maps, no baked lighting, no photo textures. Shading comes from the scene lights.
- Cylinders use 12 segments (16 for anything over 1.5 studs across). Spheres use 10 segments and 6 rings, or an icosphere with 1 subdivision.
- No floating geometry smaller than a nose. Details that would be under 0.15 stud (whiskers, stitching, screws) are left out.

## 4. Scale and placement

1 Blender unit = 1 Roblox stud. Blender scene units: Metric, Unit Scale 0.01, Length Centimeters. Export FBX with Apply Scalings "FBX Units Scale" and import into Studio with Scale Unit "Studs" (the default). An R15 avatar is about 5 studs tall, so a counter comes to the avatar's hip and a cat comes to its shin.

| asset | size (w x d x h studs) | notes |
|---|---|---|
| Cat | 1.0 x 2.6 x 1.8 | nose to tail tip 2.6, head top at 1.5, ear tips at 1.8. Ragdoll is 1.2 times this |
| Customer NPC | 2.0 x 1.0 x 5.0 | Roblox blocky proportions: legs 2, torso 2, head 1 |
| Counter | 8.0 x 2.6 x 3.0 | hero asset. Espresso machine sits on top at the left end |
| Espresso machine | 1.4 x 1.0 x 1.4 (L1, L2), 2.0 x 1.0 x 1.7 (L3) | three upgrade looks: painted, chrome trim, double boiler |
| Table round | 3.5 dia x 2.6 | |
| Table square | 3.0 x 3.0 x 2.6 | |
| Chair | 1.5 x 1.5 x 3.0 | seat at 1.4 |
| Stool | 1.4 dia x 1.6 | |
| Bench | 4.0 x 1.4 x 2.8 | seat at 1.4 |
| Cat tree | 2.0 x 2.0 x 4.5 | top platform sit point at (0.5, -0.4, 4.45) |
| Cushion | 1.8 dia x 0.45 | sit point on top |
| Window seat | 4.0 x 1.4 x 2.3 | wall side +Y, sit point on the cushion |
| Patio bench | 4.0 x 1.4 x 3.0 | |
| Cat bed | 1.8 dia x 0.5 | |
| Hanging lamp | 1.6 dia x 2.6 | pivot at the ceiling hook |
| Wall shelf | 3.0 x 0.6 x 0.6 | pivot at the wall, back center |
| Menu board | 2.0 x 0.15 x 1.5 | pivot at the wall, back center |
| Dumpster | 6.0 x 3.5 x 4.0 | |
| Trash can | 1.6 dia x 2.4 | |
| Street lamp | 1.0 x 1.0 x 10.0 | arm reaches 1.6 forward |
| Food bowl | 0.9 dia x 0.3 | premium bowl adds a gold rim and a fish |
| Doorway (Studio Parts) | 4 wide x 7 tall | not a mesh, for reference |

Snap all footprints to 0.5 stud and all heights to 0.25 stud so Studio snapping works.

## 5. Triangle budgets

Roblox has a per-MeshPart triangle cap (10,000 at last check; verify in the Creator docs before relying on it). Our budgets stay far below so a 20-cat cafe with 10 customers runs on a phone.

| category | budget per asset | notes |
|---|---|---|
| Cat (Body + Head + Tail) | 1,500 total | Body 900, Head 450, Tail 150 |
| Accessory | 200 to 300 | glasses, bow tie, apron, hat |
| Held tool (net) | 500 to 650 | per level |
| Customer NPC | 1,000 | |
| Hero furniture (Counter) | 3,000 | |
| Furniture | 800 | |
| Decor | 500 | |
| Alley props | 800 | Dumpster 1,200 |
| Items | 300 | |

The build script prints the triangle count for every export and fails the build if a budget is exceeded.

## 6. Naming

`CatCafe_<Category>_<Name>[_<Variant>]`, PascalCase, no spaces, ASCII only. The same name is used for the Blender object, the exported file, the MeshPart or Model in Studio and the asset id in code. Categories: `Cat`, `NPC`, `Furniture`, `Decor`, `Alley`, `Park`, `Item`, `Accessory`. Upgrade levels are `_L1`, `_L2`, `_L3`.

Examples: `CatCafe_Cat_Tabby`, `CatCafe_Cat_Tabby_Head`, `CatCafe_Furniture_Counter`, `CatCafe_Furniture_EspressoMachine_L2`, `CatCafe_NPC_Customer_B`, `CatCafe_Item_FoodBowl_Premium`.

The full list with sizes, triangle counts and Studio notes is generated into `assets/cat-cafe/exports/manifest.json`. The roster of cats and the asset order come from `docs/design/cat-cafe/data-model.md` section 3 and `features.md` section 5; this guide does not duplicate them.

Parts that need a Studio material or a script are separate objects inside one asset, suffixed by job: `_Tube`, `_Bulb`, `_Bulbs` and `_Pane` (Neon at night, section 9), `_Glass` and `_Water` (Transparency), `_LeafL` and `_LeafR` (gate leaves that swing), `_Open` and `_Closed` (door sign faces, one visible at a time), `_Handle` and `_Bag` (the net Tool's grip and net), and the cat's `_Body`, `_Head`, `_Tail`. Other suffixes in a multi-object asset (`_Board`, `_Frame`, `_Post`, `_Wire` and the like) are plain SmoothPlastic parts. Everything else is one object, one MeshPart.

A cat exports as one FBX containing three objects: `<Name>_Body` (legs included), `<Name>_Head` and `<Name>_Tail`. Studio imports that as a Model with three MeshParts, so the engineer can tween the head (bob, look at customer) and tail (wag) with CFrames without a skeleton. Rigged, animated cats are a later phase.

## 7. Pivots and orientation

- Pivot (object origin) at the base center: the point that touches the floor, centered on the footprint. In Studio the Model's PrimaryPart or the MeshPart pivot sits on the floor, so `CFrame = floor + Vector3.new(0, 0, 0)` places it.
- Wall-mounted assets (shelf, menu board, window box) pivot at the back center where they touch the wall. Ceiling-mounted (hanging lamp) pivot at the hook.
- Cat Head pivots at the neck joint, Tail at the tail root, so rotating them in Studio looks right.
- Held tools (the net) pivot at the grip end with the pole running forward (-Z in Roblox), so the Tool's Handle needs no Grip offset beyond rotation.
- Accessories pivot at their attachment point. `manifest.json` lists, per cat, where each attachment sits on the Head or Body: Glasses and Hat ride the Head, BowTie and Apron ride the Body, so they survive a pose change (upright, carried, stuck) and any future upright variant without new art.
- Front faces -Y in Blender. The FBX export uses Roblox's documented axes (Forward Z, Up Y), which turn Blender (x, y, z) into Roblox (-x, z, y), so the front lands on -Z, the LookVector, and `CFrame.lookAt` works without a correction. Every position and angle in `manifest.json` has a `_roblox` twin already converted; use those in code. Angles named `*_angles_roblox_deg` are for `CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))`.
- Apply all transforms before export: location 0, rotation 0, scale 1 on every object except the deliberate offsets of Head and Tail.

## 8. Materials and textures

- One material, `CatCafe_Palette`, Base Color from `CatCafe_Palette.png`, Roughness 0.65, no metallic, no normal map. Every mesh uses it.
- UVs: every face mapped to the center of its swatch (all loops of the face share the UV). No unwrapping needed and no seams.
- In Studio, set the texture on the MeshPart (`TextureID`) or use a SurfaceAppearance with ColorMap. Material `SmoothPlastic`, or `Plastic` for a touch of grain. Emissive bits (lamp bulbs, Void eyes) are separate Neon Parts or a small PointLight added in Studio, not part of the mesh.
- Studio placeholders: Parts in the same sizes using Color3 from the palette and SmoothPlastic, named identically, so swapping a Part for a MeshPart is a one-line change.
- Rarity glow: Studio-side Highlight or ParticleEmitter in the rarity color. Legendary cats also get a few `sparkle` swatch studs in the mesh.

## 9. Lighting (Studio)

Lighting.Technology Future, Bloom low, ColorCorrection Saturation +0.05, Contrast +0.05. The server clock (3 minutes day, 2 minutes night, `Clock.Phase`) drives two presets; tween between them over 4 seconds.

| setting | day | night |
|---|---|---|
| ClockTime | 14.5 | 0.5 |
| Brightness | 2 | 0.6 |
| OutdoorAmbient | 170,160,150 | 45,55,85 |
| Ambient | 120,115,110 | 30,35,55 |
| ExposureCompensation | 0 | 0.25 |
| ColorShift_Top | 255,245,230 | 150,170,220 |
| Atmosphere Density | 0.3 | 0.4, Color 110,120,160 |

Parts that switch at night (all exported as their own object, suffix `_Bulb`, `_Bulbs`, `_Pane` or `_Tube`): StreetLamp Bulb, ShopWindow Pane, StringLights Bulbs, HangingLamp Bulb, NeonSign Tube. Day: SmoothPlastic in their palette color (the window pane is Glass, Transparency 0.5). Night: Material Neon, Color lamp_warm (neon_pink for the sign), and the child light enabled: street lamp SpotLight 255,200,150 Brightness 3 Range 30 Angle 100, window and string lights PointLight 255,214,170 Brightness 1.5 Range 16, hanging lamp PointLight Brightness 1.2 Range 14 (on by day too, indoors). The cafe door sign shows `DoorSign_Open` by day and `DoorSign_Closed` at night. Customers leave at night. The `vignette_alley_night.png` concept image is the target look.

## 10. Export and import checklist

Blender export (the build script does this): FBX, Selected Objects, Object Types Mesh only, Apply Unit, Apply Scalings "FBX Units Scale", Forward Z, Up Y (Roblox's documented settings; Forward -Z would turn every model to face +Z), Mesh Smoothing Face, no Leaf Bones, no animation. A `.glb` sits next to each `.fbx` for tools that prefer glTF; it keeps glTF's own axes, so import the `.fbx` into Studio.

Studio import (3D Importer): Scale Unit Studs, Rig Type none, Insert using Scene Position off, Anchored on. After import check: 1) it stands on the floor with the pivot at the base, 2) the front faces the camera when you use View Selected from the front, 3) scale next to a 5-stud R15 dummy matches the table above, 4) texture shows the right colors (if the whole mesh is grey, set TextureID to the uploaded palette), 5) CollisionFidelity Box for simple props, Hull for the counter, cat tree and dumpster, 6) RenderFidelity Automatic, DoubleSided off.

## 11. Previews and reviews

After every visual task save 2 to 4 PNGs to `docs/concepts/cat-cafe/` with a one-line caption in `docs/concepts/cat-cafe/README.md`. The build script renders a three-quarter view of every asset and a contact sheet for the whole set.

## 12. Poses

The slice has no skeleton. A pose is a CFrame for the Body plus a local rotation for the Head and the Tail, so it works for every cat. `manifest.json` carries `poses` (upright, carried) and a `stuck_pose` on each rescue prop (StuckTree, StuckBox, Drainpipe), with every value in both Blender and Roblox axes. Carried is relative to the HumanoidRootPart centre, which sits 3 studs above the floor on a default R15 character (`previews/Pose_Carried.png`). `body_cframe_roblox` is the Body CFrame as 12 numbers for `CFrame.new(table.unpack(t))`. A pose can also move the Head joint by `head_offset_roblox`, given in the Body's own frame: upright moves it 0.32 studs, which seats the head on the collar so the raised front paws and the bow tie stay below the face. Idle bob and tail wag are tweens the engineer writes (features.md priority 11). Gavin's reference images (in the shared project folder under cat-cafe/docs/concepts/cat-cafe/reference/, not committed because they are not ours) show cube-headed collectible cats with big glossy eyes and an upright cat in a suit; we keep one quadruped rig, gave the eyes a larger glossy highlight, and proved the upright pose with the same parts (`previews/Pose_Upright.png`) so question 15 can go either way without a restart.

## 13. Rules

- Original work only. No characters, logos or art from reference games (Steal an Egg, Spin for a Fisherman, Cookie Run, AFK Arena).
- Young audience. No blood, weapons or scary cats. Even the Void cat is cute.
- Prefer our own assets or Roblox-made ones. Inspect any Creator Store asset for scripts before inserting it.
- Decisions about style changes go in `docs/decisions.md` with the date.
