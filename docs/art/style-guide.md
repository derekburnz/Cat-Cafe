# Cat Cafe art style guide

Game: Cat Cafe (placeholder name). Direction: **Cozy Cream** (default from the Three Game Sketches page, 2026-10-25; Pastel Pop and Alley Night remain as alternates if Derek or Gavin pick them). Every asset, Studio placeholder and UI color should come from this file. Change the file first, then the assets.

## 1. Mood in one paragraph

A quiet afternoon in a small cafe. Cream walls, caramel wood, mint accents and warm lamp light. The room is calm and low-contrast so the cats are the color in it. Shapes are soft blocks: chunky, rounded, toy-like, never thin or spiky. The alley out back is the same world after hours: cool grey-blue concrete and brick with one warm street lamp, so catching trips feel like a small adventure and the cafe feels like coming home.

## 2. Palette

All colors live in one shared texture, `CatCafe_Palette.png` (256 x 512, 8 swatches across and 16 rows of 32 px swatches; rows 10 to 15 are empty for now). Every mesh in the game UV-maps each face to the center of one swatch, so one material and one texture cover every prop and every cat. Variants (a Tabby versus a Grey cat) are the same mesh with different swatch indices, not different textures.

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
| 10 | fur_black | #2B2B35 | Tuxedo, Void, Tortie base, Calico patches, Maine Coon stripes |
| 11 | fur_white | #F7F1E6 | Tuxedo chest, Snow, Calico and Ragdoll base, muzzles |
| 12 | fur_grey | #8E96A3 | spare grey (no cat uses it since 2026-10-27) |
| 13 | fur_cream | #EFD9B4 | Siamese body, cream muzzles |
| 14 | fur_brown | #7A4F2E | Brownie's coat |
| 15 | fur_golden | #F2C14E | Golden (Legendary) |

### Row 2: cat details and rarity

| idx | name | hex | use |
|---|---|---|---|
| 16 | eye_green | #6FCF97 | Common eyes |
| 17 | eye_amber | #F2B134 | Tabby, Tortie eyes; Void glow eyes |
| 18 | eye_blue | #5FA8FF | Siamese, Snow eyes |
| 19 | nose_pink | #E07A8C | noses, inner ears, paw pads |
| 20 | rarity_common | #8E97B2 | Common rarity color (UI frames and badges) |
| 21 | rarity_rare | #5FA8FF | Rare rarity color |
| 22 | rarity_epic | #C07CFF | Epic rarity color |
| 23 | rarity_legend | #FFC94D | Legendary rarity color; gold trim (sash edges, vest buttons, cape stars and clasps) |

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

Row 7, v0.3 to v0.5 additions. The texture grew from 8 to 16 rows on 2026-10-27 for per-cat coats (rows 8 and 9 below). New swatches only go at the end, so every index keeps its place; growing the texture again moves every UV and means re-exporting every asset.

| idx | name | hex | use |
|---|---|---|---|
| 56 | rarity_mythic | #FF5E7E | Mythical rarity color (data-model section 2 color) |
| 57 | fur_blue | #9AA9C2 | Blue's silver-blue coat |
| 58 | aurora_violet | #8E7CF0 | Aurora's middle band between galaxy_blue and mint |
| 59 | pastel_butter | #F6DFA0 | Butter cafe facade (plot shells come in mint, blush, pastel_butter, pastel_lilac) |
| 60 | pastel_lilac | #C9B8E8 | Lilac cafe facade |
| 61 | gold_light | #FBE49A | Gold cat, lightest coat color of a cat (metal) |
| 62 | gold_mid | #F2C14E | Gold cat, second coat color (metal) |
| 63 | gold_dark | #C98F2A | Gold cat, third coat color and any near-black coat (metal) |

Row 8, coats (2026-10-27), so that no two cats share a main coat color.

| idx | name | hex | use |
|---|---|---|---|
| 64 | fur_ginger | #D9662E | Ginger's red-ginger coat, Tortie's patches |
| 65 | fur_charcoal | #4A4F58 | Smoke's coat |
| 66 | fur_silver | #CDD2DA | Maine Coon's silver tabby base |
| 67 | fur_latte | #C79F7A | Cream's latte coat |
| 68 | fur_sand | #DDB46A | Bengal's sand base |
| 69 | fur_rose | #F2BFCB | Blossom's rose coat |
| 70 | fur_peach | #EDBBA1 | Sphynx's skin |
| 71 | fur_lavender | #B9A3DE | Persian's lavender long coat |

Row 9, eyes, noses and markings for the coats.

| idx | name | hex | use |
|---|---|---|---|
| 72 | eye_copper | #E0782F | Tortie and Persian eyes |
| 73 | eye_chartreuse | #B9D84A | Smoke and Cream eyes |
| 74 | eye_violet | #9C7CF2 | Sphynx eyes |
| 75 | nose_dark | #4A4450 | noses of the dark, grey and pointed cats |
| 76 | nose_brick | #C4675B | noses of the ginger, brown and tabby-patterned cats |
| 77 | fur_seal | #3E2A22 | Siamese points, Bengal spots |
| 78 | fur_apricot | #F2B88A | Tortie's second patch color |
| 79 | fur_smoke_light | #8A8F99 | Smoke's muzzle |

Rows 10 and 11, the Neighbourhood, Woods and Sewer themed cats (data-model 3c) and their props (2026-10-27).

| idx | name | hex | use |
|---|---|---|---|
| 80 | fur_slate | #6E7E98 | Postie (Mail Cat) |
| 81 | fur_oat | #E6CFA8 | Fold (Painter Cat); Bottlecap's muzzle |
| 82 | fur_vanilla | #FBF0D2 | Comet (Ice Cream Cat); Fold's muzzle |
| 83 | fur_strawberry | #F28FAA | Comet's stripes and the scoop on its hat |
| 84 | fur_hazel | #A27A55 | Pinecone (Scout Cat); Old Oak's muzzle |
| 85 | fur_russet | #8E4A2C | Forest Cat (Lumberjack Cat) |
| 86 | fur_rust_red | #C4512F | Toadstool's patches |
| 87 | fur_soot | #625D59 | Lantern (Miner Cat) |
| 88 | fur_mist | #C3D0DE | Bubbles (Bubble Cat) |
| 89 | fur_copper | #B5602F | Gears (Steampunk Cat) |
| 90 | fur_teal_grey | #7A9C9E | Glimmer (Diver Cat) |
| 91 | fur_caramel | #CF8F52 | Bottlecap (King Cat); not a gold tone, so it never reads as a gold cat |
| 92 | bronze | #80562E | Bottlecap's patches and crown band, the steampunk goggles' rims |
| 93 | fur_emerald | #2E9E6B | Eclipse (Dragon Cat), front of its emerald to teal gradient |
| 94 | pastel_sky | #A8D8F0 | Comet's and Wisp's glowing eyes, Wisp's mane, fairy wings |
| 95 | brass | #B8913A | steampunk goggles (plain colour, not metal, unlike the gold swatches) |

**Cat coats (2026-10-27).** Derek asked for a clearly different color scheme on every cat, because the cat meshes may be replaced. So the colors are data, not mesh: `cats.ROSTER` gives each cat its fur, second and third (markings), ruff, muzzle, eyes (eyes2 for an odd-eyed cat's right eye), nose and pattern, and `manifest.json` repeats them per cat under `coat` (swatch and hex) and `pattern`, ready to apply to any future model. No two cats share a main coat color. Picture: `docs/concepts/cat-cafe/sheet_cats.png`.

| cat | coat | markings | eyes | nose |
|---|---|---|---|---|
| Tabby | fur_orange | fur_orange_dark stripes, white muzzle | amber | pink |
| Tuxedo | fur_black | fur_white bib, belly and socks | green | pink |
| Ginger | fur_ginger | cream muzzle | green | brick |
| Smoke | fur_charcoal | fur_smoke_light muzzle | chartreuse | dark |
| Snow | fur_white | none | odd: blue and amber | pink |
| Cream | fur_latte | cream muzzle | chartreuse | pink |
| Brownie | fur_brown | choco stripes, cream muzzle | amber | brick |
| Blue | fur_blue | none | green | dark |
| Calico | fur_white | fur_orange and fur_black patches | green | pink |
| Siamese | fur_cream | fur_seal points | blue | dark |
| Tortie | fur_black | fur_ginger and fur_apricot patches | copper | brick |
| Bengal | fur_sand | fur_seal spots, cream muzzle | green | brick |
| Sphynx | fur_peach | none | violet | pink |
| Ragdoll | fur_white | fur_blue points | blue | pink |
| Maine Coon | fur_silver | fur_black stripes, white ruff | amber | brick |
| Persian | fur_lavender | pastel_lilac fringe | copper | pink |
| Void | fur_black | sparkle specks | amber, glowing | dark |
| Blossom | fur_rose | fur_white and nose_pink patches, petals | blue | pink |
| Midnight | night_sky | sparkle stars and moon | sparkle, glowing | dark |
| Aurora | galaxy_blue | aurora_violet and mint gradient | mint, glowing | pink |
| Munchkin | fur_grey | fur_white patches and muzzle, short legs | copper | dark |
| Fold | fur_oat | fur_vanilla muzzle, folded ears, paint-dipped toes (pink, teal, yellow, blue) | green | pink |
| Chonk | fur_apricot | fur_white bib, belly and socks; scale 1.25 | green | pink |
| Postie | fur_slate | fur_blue muzzle | copper | dark |
| Marshmallow | milk | fur_white fringe, ruff and cheek fluff (long coat) | blue | pink |
| Comet | fur_vanilla | fur_strawberry stripes, sprinkles | pastel_sky, glowing | pink |
| Pinecone | fur_hazel | fur_brown stripes, cream muzzle | green | brick |
| Forest Cat | fur_russet | fur_seal stripes, cream ruff, ear tufts; scale 1.2 | amber | brick |
| Toadstool | cream | fur_rust_red patches | amber | pink |
| Firefly | choco | fur_brown muzzle, sparkle tail tip | amber | brick |
| Old Oak | dark_wood | leaf_green leaves, fur_hazel muzzle | amber | brick |
| Wisp | fur_white | pastel rainbow mane, sparkle specks | pastel_sky, glowing | pink |
| Lantern | fur_soot | fur_grey muzzle | amber | dark |
| Bubbles | fur_mist | white muzzle | blue | pink |
| Gears | fur_copper | rust stripes, cream muzzle | green | brick |
| Glimmer | fur_teal_grey | white muzzle and chest | copper | pink |
| Bottlecap | fur_caramel | bronze patches, fur_oat muzzle | green | brick |
| Eclipse | fur_emerald | sign_teal and dumpster_green gradient | amber, glowing | dark |

**Gold cats (v0.5 F42, called shiny until 2026-10-27).** Derek picked gold and asked for gold-modeled cats, called gold. Every cat has `CatCafe_Cat_<Name>_Gold`: the same shapes with the coat in three golds and eyes, nose, inner ears and star specks unchanged. The cat's coat colors (fur, second, third, ruff) are ranked lightest first by CIE L*: the lightest takes gold_light, the next gold_mid, the next gold_dark, and any coat darker than L* 35 (black, chocolate) takes gold_dark too, so stripes, points and patches still show; the muzzle turns gold_light. The golds are metal: `palette.METAL_SWATCHES` makes them Material Metal on the Part models and metallic in the palette material (a mask texture, `CatCafe_Palette_Metal.png`, into Metallic, Roughness 0.3 there). Gold cats are Part models only; their meshes are the base cats'. Picture: `docs/concepts/cat-cafe/sheet_gold.png`.

**Gold Book decor (F48).** Each area's Book reward piece has a gold version for the `gold10` milestone, `CatCafe_Decor_<Piece>_Gold` (`MuralPrint`, `ParkBench`), on the same shapes with the metal golds: the Alley mural print gets a gold_mid frame, a gold_light inner lip and a gold_light name plate (the picture stays in colour); the Park bench gets gold_light slats, gold_dark iron and gold_mid finials (the mint cushion stays). Like gold cats they are Part models only. Previews: `previews/CatCafe_Decor_MuralPrint_Gold.png`, `previews/CatCafe_Decor_ParkBench_Gold.png`.

## 3. Shape language

- Soft blocks. Every hard edge gets a 0.06 stud chamfer (a one-segment bevel; two segments only on the hero counter top). Nothing is razor-thin: minimum thickness 0.1 stud, minimum feature size 0.15 stud. Legs and posts are at least 0.15 stud across.
- Chunky proportions. Heads are big, legs are short, props are about 10 percent wider and squatter than real life.
- Flat shading, flat colors. No gradients, no normal maps, no baked lighting, no photo textures. Shading comes from the scene lights.
- Cylinders use 12 segments (16 for anything over 1.5 studs across). Spheres use 10 segments and 6 rings, or an icosphere with 1 subdivision.
- No floating geometry smaller than a nose. Details that would be under 0.15 stud (whiskers, stitching, screws) are left out.
- Cat faces: big glossy eyes, a pink nose, blush cheeks and the W mouth on every cat (Derek, 2026-10-27, option 2 of the mouth drafts): a short line down from the nose into two little u curves, standing 0.02 proud of the muzzle. It is `fur_black` on light fur or a light muzzle and `fur_grey` on dark fur (CIE L* under 35, `palette.lstar`). The blep and the open smile come later as expression swaps.

## 4. Scale and placement

1 Blender unit = 1 Roblox stud. Blender scene units: Metric, Unit Scale 0.01, Length Centimeters. Export FBX with Apply Scalings "FBX Units Scale" and import into Studio with Scale Unit "Studs" (the default). An R15 avatar is about 5 studs tall, so a counter comes to the avatar's hip and a cat comes to its shin.

| asset | size (w x d x h studs) | notes |
|---|---|---|
| Cat, walking (body A) | 1.0 x 2.0 x 1.85 | nose to tail tip 2.0, head top at 1.63, ear tips at 1.85. Ragdoll and Maine Coon are 1.2 times this |
| Cat, sitting (body B) | 1.05 x 1.2 x 1.85 | drawn at 0.95 so a sitting cat is no taller than a walking one; head top at 1.63 |
| Customer NPC | 2.0 x 1.0 x 5.0 | Roblox blocky proportions: legs 2, torso 2, head 1 |
| Counter | 8.0 x 2.6 x 3.0 | hero asset. Espresso machine sits on top at the left end, the pastry case at the right end; the barista cat's pad (sit point) is between them, behind the tip jar |
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
| Alley mural print (Book decor) | 3.6 x 0.2 x 1.8 | pivot at the wall, back-bottom center (hung like the neon sign); the Alley mural at 0.11 scale in a caramel_wood frame |
| Park bench (Book decor) | 3.0 x 1.3 x 2.4 | seat at 1.1; a little indoor copy of the Park bench with curled armrests and a mint paw-print cushion |
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
| Cat (every piece, either body) | 1,500 total | plain coats land at 650 to 950 on A and B; themed cats with their prop at 800 to 1,380 |
| Accessory | 200 to 300 | glasses, hat, and the role outfit pieces: apron, barista cap, bow tie, vest, sash, boater, party hat, cape |
| Held tool (net) | 500 to 650 | per level |
| Customer NPC | 1,000 | |
| Hero furniture (Counter) | 3,000 | the night dealer's cart 3,500 |
| Furniture | 800 | role stations: GreeterPodium 800, StageCatTree 1,400 |
| Decor | 500 | |
| Alley props | 800 | Dumpster 1,200; rescue traps (TrashBin, GarbageBags) 600 |
| Park props | 800 | Fountain 1,200; rescue traps (RescueTree, TrashCan) 900 |
| Area gates | 6,000 | Park, Neighbourhood, Woods, Sewer: arches with a barrier (section 13) |
| Alleyway set pieces | 5,000 to 6,000 | arches and building backs; crate stack 3,000, laundry line 2,500, long string lights 1,500, manhole 2,500 |
| Cafe plot set pieces | 12,000 shell, 8,000 interior, 4,000 For Rent, 3,000 per tier | built from blocks for the Part export (section 14); the FBX is the reference |
| Items | 300 | dealer foods: Sardines 400, Caviar 600; TipPile prop 600 |

The build script prints the triangle count for every export and fails the build if a budget is exceeded.

## 6. Naming

`CatCafe_<Category>_<Name>[_<Variant>]`, PascalCase, no spaces, ASCII only. The same name is used for the Blender object, the exported file, the MeshPart or Model in Studio and the asset id in code. Categories: `Cat`, `NPC`, `Furniture`, `Decor`, `Alley`, `Park`, `Item`, `Accessory`. Upgrade levels are `_L1`, `_L2`, `_L3`.

Examples: `CatCafe_Cat_Tabby`, `CatCafe_Cat_Tabby_Head`, `CatCafe_Furniture_Counter`, `CatCafe_Furniture_EspressoMachine_L2`, `CatCafe_NPC_Customer_B`, `CatCafe_Item_FoodBowl_Premium`.

The full list with sizes, triangle counts and Studio notes is generated into `assets/cat-cafe/exports/manifest.json`. The roster of cats and the asset order come from `docs/design/cat-cafe/data-model.md` section 3 and `features.md` section 5; this guide does not duplicate them.

Parts that need a Studio material or a script are separate objects inside one asset, suffixed by job: `_Tube`, `_Bulb`, `_Bulbs` and `_Pane` (Neon at night, section 9), `_Glass` and `_Water` (Transparency), `_Open` and `_Closed` (door sign faces, one visible at a time), `_Handle` and `_Bag` (the net Tool's grip and net), `_Lid` and `_Branch` (rescue trap parts that move: the TrashBin and TrashCan lids, the RescueTree branch, with `_Bin`, `_Can` and `_Trunk` as the fixed rest), and the cat's hinged pieces (below). Other suffixes in a multi-object asset (`_Board`, `_Frame`, `_Post`, `_Wire` and the like) are plain SmoothPlastic parts. Everything else is one object, one MeshPart.

A cat is two models (Derek, 2026-10-27: "A for walking around B while they are sitting"): `CatCafe_Cat_<Name>` is body A on all fours (strays, carried and stuck cats, cats walking about) and `CatCafe_Cat_<Name>_Sit` is body B sitting up (cats resting in the cafe, working cats at their stations). Their gold twins are `_Gold` and `_Gold_Sit` (Part models only). Each is a set of hinged pieces, each its own object pivoted at its joint: `_Body` (the PrimaryPart; B's back paws included), `_Head` (neck), `_Eye1` and `_Eye2` (eye centre, for blinks), `_EarL` and `_EarR` (ear base, for twitches), `_Tail` (root) and the legs `_LegF1` and `_LegF2`, plus `_LegB1` and `_LegB2` on A (shoulder or hip; F front, B back, 1 the cat's left). A themed cat adds `_Prop` (its signature prop) and, when the prop has clear parts, `_Prop_Glass` (section 12). The Part models nest the eyes and ears inside the Head Model, so turning the Head carries them. Code poses a cat by turning those Models with CFrames, no skeleton (section 12). Rigged, animated cats are a later phase.

## 7. Pivots and orientation

- Pivot (object origin) at the base center: the point that touches the floor, centered on the footprint. In Studio the Model's PrimaryPart or the MeshPart pivot sits on the floor, so `CFrame = floor + Vector3.new(0, 0, 0)` places it.
- Wall-mounted assets (shelf, menu board, window box) pivot at the back center where they touch the wall. Ceiling-mounted (hanging lamp) pivot at the hook.
- Cat pieces pivot at their joints: Head at the neck, Tail at the root, legs at the shoulder or hip, eyes at their centre, ears at their base (`joints_roblox` per cat in the manifest, already scaled), so rotating them in Studio looks right.
- Moving parts of a prop (trap lids, the rescue tree branch) pivot at their hinge or root. `manifest.json` gives that point per part as `part_pivots_roblox`, relative to the asset pivot. If the Studio import puts a MeshPart's pivot at its bounding box centre, set its `PivotOffset` so the pivot lands on that point, then rotate with `PivotTo`.
- Held tools (the net) pivot at the grip end with the pole running forward (-Z in Roblox), so the Tool's Handle needs no Grip offset beyond rotation.
- Accessories pivot at their slot. The role outfit pieces are built for body B, whose chest and head are the same on every cat, and every sitting model carries one `Outfit_<Piece>` Attachment per piece (the hats in the Head part, the rest in the Body part). Glasses and Hat ride the walking Head. `manifest.json` lists each cat's slots under `attachments` (already scaled) and the shared sitting slots under `sit_slots`.
- Front faces -Y in Blender. The FBX export uses Roblox's documented axes (Forward Z, Up Y), which turn Blender (x, y, z) into Roblox (-x, z, y), so the front lands on -Z, the LookVector, and `CFrame.lookAt` works without a correction. Every position and angle in `manifest.json` has a `_roblox` twin already converted; use those in code. Angles named `*_angles_roblox_deg` are for `CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))`.
- Apply all transforms before export: location 0, rotation 0, scale 1 on every object except the deliberate offsets of Head and Tail.

## 8. Materials and textures

- One material, `CatCafe_Palette`, Base Color from `CatCafe_Palette.png`, Roughness 0.65, no normal map. Metallic comes from the mask `CatCafe_Palette_Metal.png`, white only on the gold swatches (gold cats), where Roughness drops to 0.3. Every mesh uses it.
- UVs: every face mapped to the center of its swatch (all loops of the face share the UV). No unwrapping needed and no seams.
- In Studio, set the texture on the MeshPart (`TextureID`) or use a SurfaceAppearance with ColorMap. Material `SmoothPlastic`, or `Plastic` for a touch of grain. Emissive bits (lamp bulbs, Void eyes) are separate Neon Parts or a small PointLight added in Studio, not part of the mesh.
- Studio placeholders: Parts in the same sizes using Color3 from the palette and SmoothPlastic, named identically, so swapping a Part for a MeshPart is a one-line change.
- Rarity glow: Studio-side Highlight or ParticleEmitter in the rarity color. Legendary cats also get a few `sparkle` swatch studs in the mesh.
- Particle sprites are the one exception to "one palette texture": `CatCafe_VFX_ShinySparkle.png` (128 px, white on transparent, built by `vfx.py`) is a ParticleEmitter Texture that the emitter's `Color` tints, `sparkle` for gold cats. Its shape is a fat four-point star with small diagonal glints and a soft halo, drawn thick so it still reads at Size 0.4 to 0.6 on a phone at 30 studs. The manifest's `textures` section has the file and suggested emitter values; the vfx-animator's `ShinySparkle` preset owns the emitter. Upload the PNG in Studio and use its id; until then `rbxasset://textures/particles/sparkles_main.dds` stands in. Preview: `previews/CatCafe_VFX_ShinySparkle.png`.

## 9. Lighting (Studio)

Lighting.Technology Future, Bloom low, ColorCorrection Saturation +0.05, Contrast +0.05. The server clock (3 minutes day, 2 minutes night, `Clock.Phase`) drives two presets; tween between them over 4 seconds.

| setting | day | night |
|---|---|---|
| ClockTime | 14.5 | 0.5 |
| Brightness | 2 | 0.6 |
| OutdoorAmbient | 170,160,150 | 45,55,85 |
| Ambient | 120,115,110 | 30,35,55 |
| ExposureCompensation | 0 | 0 (0.25 washed the lit cafe out to white; changed in PR #239) |
| ColorShift_Top | 255,245,230 | 150,170,220 |
| Atmosphere Density | 0.3 | 0.4, Color 110,120,160 |

Parts that switch at night (all exported as their own object, suffix `_Bulb`, `_Bulbs`, `_Pane` or `_Tube`): StreetLamp Bulb, ShopWindow Pane, StringLights Bulbs, HangingLamp Bulb, NeonSign Tube. Day: SmoothPlastic in their palette color (the window pane is Glass, Transparency 0.5). Night: Material Neon, Color lamp_warm (neon_pink for the sign); bulbs and tubes are solid, window panes keep Transparency 0.3 so you can see into the cafe. The child light is enabled: street lamp SpotLight 255,200,150 Brightness 3 Range 30 Angle 100; window, string light and sign tube PointLight 255,214,170 Brightness 0.8 Range 10; hanging lamp PointLight Brightness 1.2 Range 14 (on by day too, indoors). Stronger window and string lights (the old 1.5 and 16) wash the cafe interior out to white, so keep new lights at or under these values (PR #239, playtest #184). The cafe door sign shows `DoorSign_Open` by day and `DoorSign_Closed` at night. From v0.5 (F44) cafes close at night and customers leave: owned cafes hang `CatCafe_Plot_ClosedSign` in the front door, a night_sky board with CLOSED on both faces, two stars and a crescent moon (`_Moon_Bulb`, so it glows lamp_warm). The `vignette_alley_night.png` concept image is the target look.

## 10. Export and import checklist

Blender export (the build script does this): FBX, Selected Objects, Object Types Mesh only, Apply Unit, Apply Scalings "FBX Units Scale", Forward Z, Up Y (Roblox's documented settings; Forward -Z would turn every model to face +Z), Mesh Smoothing Face, no Leaf Bones, no animation. A `.glb` sits next to each `.fbx` for tools that prefer glTF; it keeps glTF's own axes, so import the `.fbx` into Studio.

Studio import (3D Importer): Scale Unit Studs, Rig Type none, Insert using Scene Position off, Anchored on. After import check: 1) it stands on the floor with the pivot at the base, 2) the front faces the camera when you use View Selected from the front, 3) scale next to a 5-stud R15 dummy matches the table above, 4) texture shows the right colors (if the whole mesh is grey, set TextureID to the uploaded palette), 5) CollisionFidelity Box for simple props, Hull for the counter, cat tree and dumpster, 6) RenderFidelity Automatic, DoubleSided off.

Toolkit QA (since 2026-10-27): run `assets/cat-cafe/blender/toolkit_qa.py` after a build. It uses the EL4CTEO blender-skills (`blender-asset-qa` with the `roblox` profile, `blender-game-optimization` with the `roblox` budget) and lists visible overlaps and floating parts with the code line to change. Rules it enforces: two faces of different colours never share a plane (move one 0.01 studs: proud, recessed or past the other's edge), and no part hangs more than 0.05 studs off the piece it belongs to unless it is meant to (sparkles, litter on the ground, add-ons that touch the cafe shell).

## 11. Previews and reviews

After every visual task save 2 to 4 PNGs to `docs/concepts/cat-cafe/` with a one-line caption in `docs/concepts/cat-cafe/README.md`. The build script renders a three-quarter view of every asset and a contact sheet for the whole set.

## 12. Poses

The slice has no skeleton. Every pose turns the cat's hinged pieces (section 6) about their joints, so it works for every cat. `manifest.json` carries two kinds, with every value in Blender and Roblox axes:

- `cat_poses` turn single pieces of body A or B, after an optional `lift` of the whole cat: `lick` (B: the left front paw up at the mouth, head tipped down to it; Derek, 2026-10-27: the paw-up sit is licking a paw), `loaf` (A: belly on the floor, all four legs folded under), `sleep` (the loaf with the head down and turned and the tail curled round) and `eat` (A standing, head down to a bowl). In Roblox turn each piece's Model with `piece:PivotTo(piece:GetPivot() * CFrame.Angles(...))` using `angles_roblox_deg`, Head first, then move the whole model by `lift_roblox` times the cat's `scale`. Preview: `previews/Pose_Cats.png` (walk, sit, lick, loaf, sleep, eat). The For Rent plot's sleeping Tabby is the `sleep` pose.
- `poses` move the whole walking cat as a Body CFrame plus a turn of the Head and the Tail: `carried` (relative to the HumanoidRootPart centre, 3 studs above the floor on a default R15 character; `previews/Pose_Carried.png`) and `upright`, which is now only the base of the bin traps. Each v0.3 rescue trap has a `stuck_pose` (Alleyway `TrashBin` and `GarbageBags`, Park `RescueTree` and `TrashCan`): in the bin and the can the cat stands inside with its head and front paws over the rim; in the bags it is buried with its head and front paws out the front; on the tree it lies draped across the branch between the trunk and the leaf tuft, facing the tree's front and looking down at the player (the engineer's #200 pose), its Body welded to the `_Branch` so it rides the shake. `body_cframe_roblox` is the Body CFrame as 12 numbers for `CFrame.new(table.unpack(t))`; `head_offset_roblox` moves the Head joint in the Body's own frame. Previews: `previews/CatCafe_Alley_TrashBin.png` and the other three, collected in `sheet_poses.png`.

Cats wear no collar, strays and cafe cats alike (Derek, 2026-10-27). Working cats (v0.3 roles, data-model section 5) sit at their stations on body B in their role's two-piece outfit, which is what marks a cat as staff: Apron and BaristaCap for the barista, BowTie and Vest for the waiter, Sash and Boater for the greeter, PartyHat and Cape for the entertainer (`role_outfits` in the manifest, `previews/Pose_Uniforms.png`). The pieces share the cafe palette: mint and cream for the barista, dark_wood with a white shirt and gold buttons for the waiter, shirt_red and straw (treat_tan) for the greeter, sign_teal and neon_pink with gold stars for the entertainer. Put each piece on the sitting model's `Outfit_<Piece>` Attachment and scale it by the model's `Scale` attribute; multiply every pose position by it too. Idle bob, blinks, ear twitches and tail wag are tweens on the piece Models (the vfx-animator's Effects code). Gavin's reference images (in the shared project folder under cat-cafe/docs/concepts/cat-cafe/reference/, not committed because they are not ours) show cube-headed collectible cats with big glossy eyes.

Themed cats (data-model section 3c) each wear one signature prop, built in `props.py` and named `CatCafe_Cat_<Name>[_Gold][_Sit]_Prop`, on both bodies and the gold twins. The prop has a slot: `Head` (hats, horns, antlers, headphones), `Face` (glasses, masks, the eye patch, the bubble pipe) or `Back` (cape, wings, guitar, skateboard, backpack, the firefly jar). Head and Face props pivot at the neck and the Part model nests them in the Head Model, so a head turn carries them; Back props sit in the root Model and ride the Body. Every prop Part carries a `Follows` attribute (`Head` or `Body`) and the cat's root Model a `PropSlot` attribute. When a themed cat works, `CatPose.dress` leaves off the role piece in the prop's slot (a Head prop replaces the BaristaCap, Boater or PartyHat, a Back prop the Entertainer's Cape) and keeps the other piece; Face props keep the whole outfit. Clear parts (lenses, the helmet, bubbles, the jar) are `_Prop_Glass`, Glass at 0.45. Props follow the toolkit rule for details: sunk 0.005 to 0.01 into the surface they sit on and at least 0.01 proud of it, never coplanar with a face of another swatch. Review sheets: `docs/concepts/cat-cafe/themed_cats_<area>.png`.

## 13. Cafe plots and the street

The street is a row of cottage shopfronts, never grey boxes (world-and-feel.md sections 3 and 5). Each plot's
shell (`CatCafe_Plot_Cafe_<Colour>`) is a pastel cottage: mint, blush, pastel_butter or pastel_lilac walls by plot
number, offwhite trim and corner pilasters, a terracotta plinth and gable roof with brick tile lines and a chimney,
two arched windows with striped awnings in the accent colour (blush, mint, sign_teal, pastel_butter), an arched
door with a sunburst fanlight, a sign board with cat ears on the front gable, and a front garden with a path,
flower beds, a picket fence, a bench and a lamp post. Inside (`CatCafe_Plot_Interior`) follows the concept sketch:
caramel plank wainscot with a dark chair rail, cream walls, mint curtains, tie beams with mint pendant lamps over
the tables, a chalk menu board, plant and mug shelves, framed pixel portraits of our cats and coloured string
lights. Empty plots add `CatCafe_Plot_ForRent` (half-down shutters, a FOR RENT blade sign, dust sheets, boxes, a
sleeping Tabby) and running cafes add the tier sets `CatCafe_Plot_Tier1` to `Tier5` cumulatively: chalkboard;
flower boxes and a bistro set; neon OPEN, string lights and a second bistro set; a fish tank in the window and the
back patio pergola; gold trim, the cup-with-ears rooftop sign and a red carpet. Previews:
`previews/CatCafe_Plot_*.png`, the Part versions in `rbx/`.

The Alleyway behind the cafes is a city back street at cosy scale: building backs 30 wide and 16 to 24 tall in
brick with concrete quoins, cornices and window frames, a few lit windows with curtains (`_Pane`), shutters and
flower boxes in the street's pastels, AC units, drainpipes and pipes. Variants: `CatCafe_Alley_WallWindows`,
`WallDoor` (green staff door, teal canopy, lamp), `FireEscape` (two walkable landings, a ladder and stairs) and
`Mural` (sunset bands, CAT CAFE and pixel faces of Tabby, Tuxedo, Siamese, Void and Calico). Arches over the mouths
of the Alley Square (`CatCafe_Alley_ArchStreet`, `CatCafe_Alley_Arch`) are brick posts with lanterns, a teal name
board and an iron arc of bulbs with a gold cat medallion. Props: a crate stack in climbable steps, a laundry line,
long string lights and the Sewer manhole with barricades. Area gates are arches over the full opening with a
ForceField barrier and a hanging sign board, themed: the Park in brick with ivy, planters and a green iron frame;
the Woods in logs with moss, mushrooms and small spruces; the Sewer in concrete with hazard stripes, a big pipe
and slime; the Neighbourhood in brick with a white pergola, hedges and a mailbox.

## 14. Part-built models in Roblox

`build_all.py` also writes `assets/cat-cafe/rbx/<Name>.model.json` for every asset. Rojo syncs that folder into
`ReplicatedStorage.Assets`, so the game uses these instead of the code placeholders with no Studio import. Each
Builder block becomes a Part (cylinders, wedges, balls; cones as stacked bands; flat stars and arches as wedge
pairs), coloured from the palette, SmoothPlastic, no bevels. Glass is Glass at 0.45 transparency, water at 0.3.
Hanging lamp bulbs are Neon; other `_Bulb`, `_Bulbs`, `_Pane` and `_Tube` parts keep their day look until
WorldController lights them at night. Every extra object (Head, Tail, Lid, Branch, Roof, SignBoard, bulbs) is a
child Model whose pivot is that object's origin, so hinges and joints match `part_pivots_roblox`. Big parts of
furniture, alley, park, plot and street assets collide; cats, people, items and decor do not.

Names the game code reads, so keep them when an asset is rebuilt: `_Roof` (faded for the owner), a part named
`SignBoard` (owner sign SurfaceGui), `Bars` (a gate barrier, ForceField), `Top` (round table, customers face it),
`_Steam` (espresso cups), `_Chimney` (chimney opening), `_Flowers` (beds and flower boxes, butterflies),
`_Fireflies` (invisible volume over the beds), `_Shutter` and `_Sign` inside ForRent (rolled up and flipped on a
claim), `_Zzz` (sleeping cat). Tags for the audio loops: `FishTank` (decor tank and the Tier 4 tank's water) and
`Fountain`; the engineer tags `CafeDoor` and `WorkingCat` at placement.
`rbx_preview.py` renders the Part versions the way Roblox draws them; check them before a PR. A MeshPart import
saved as `<Name>.rbxm` replaces the JSON of the same name (delete the JSON).

## 15. Rules

- Original work only. No characters, logos or art from reference games (Steal an Egg, Spin for a Fisherman, Cookie Run, AFK Arena).
- Young audience. No blood, weapons or scary cats. Even the Void cat is cute.
- Prefer our own assets or Roblox-made ones. Inspect any Creator Store asset for scripts before inserting it.
- Decisions about style changes go in `docs/decisions.md` with the date.
