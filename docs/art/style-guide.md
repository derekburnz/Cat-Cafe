# Cat Cafe art style guide

Game: Cat Cafe (placeholder name). Direction: **Cozy Cream** (default from the Three Game Sketches page, 2026-10-25; Pastel Pop and Alley Night remain as alternates if Derek or Gavin pick them). Every asset, Studio placeholder and UI color should come from this file. Change the file first, then the assets.

## 1. Mood in one paragraph

A quiet afternoon in a small cafe. Cream walls, caramel wood, mint accents and warm lamp light. The room is calm and low-contrast so the cats are the color in it. Shapes are soft blocks: chunky, rounded, toy-like, never thin or spiky. The alley out back is the same world after hours: cool grey-blue concrete and brick with one warm street lamp, so catching trips feel like a small adventure and the cafe feels like coming home.

## 2. Palette

All colors live in one shared texture, `CatCafe_Palette.png` (256 x 512, 8 swatches across and 16 rows of 32 px swatches; rows 13 to 15 are empty for now). Every mesh in the game UV-maps each face to the center of one swatch, so one material and one texture cover every prop and every cat. Variants (a Tabby versus a Grey cat) are the same mesh with different swatch indices, not different textures.

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

Row 12, the twelve plain Commons of the Neighbourhood, Woods and Sewer (data-model 3c, 2026-10-27).

| idx | name | hex | use |
|---|---|---|---|
| 96 | fur_puddle | #7A96B4 | Puddle (its own blue, because the `puddle` swatch exports as see-through Glass) |
| 97 | fur_pepper | #6B6C73 | Pepper |
| 98 | fur_ink | #363C4C | Socks |
| 99 | fur_moss | #8D9B6E | Moss |
| 100 | fur_acorn | #A0683A | Acorn |
| 101 | fur_bramble | #6E5140 | Bramble |
| 102 | fur_fern | #A4C08F | Fern |
| 103 | fur_ash | #3A373C | Soot |

Row 13, the Town Square's paving and the compass (town layout v3.1, 2026-10-28). The `paw_` swatches are the paw
paths' colours in WorldBuilder, so the compass points and the paws match.

| idx | name | hex | use |
|---|---|---|---|
| 104 | paving_light | #F2E8D5 | the square's cross (the walk), the garden paths |
| 105 | paving_sand | #E2CFAE | the quarters' tiles, light |
| 106 | paving_tan | #D4BC96 | the quarters' tiles, dark |
| 107 | paving_grout | #A7957C | joints, and the square's base slab |
| 108 | paw_park | #68C45C | the Park's compass point (south) |
| 109 | paw_neighbourhood | #F09640 | the Neighbourhood's compass point (north) |
| 110 | paw_woods | #267040 | the Woods' compass point (west) |
| 111 | paw_sewer | #566E96 | the Sewer's compass point (east) |

Row 14, the coats of the ten area-themed cats of F78 (data-model 3, v0.13, 2026-10-28). Eight cells of row 14 and
row 15 stay free.

| idx | name | hex | use |
|---|---|---|---|
| 112 | fur_dusty | #96918C | Binbag (Garbage Bag Cat) |
| 113 | fur_marmalade | #E18C3C | Taxi (Taxi Cat) |
| 114 | fur_indigo | #2D236E | Neon (Jazz Cat) |
| 115 | fur_dune | #D7B987 | Birdwatch (Birdwatcher Cat) |
| 116 | fur_bubblegum | #F7A8C8 | Balloon (Balloon Cat) |
| 117 | fur_toffee | #8C5F3C | Builder (Construction Cat) |
| 118 | fur_pewter | #A5A5AA | Gnome (Gnome Cat) |
| 119 | fur_gunmetal | #69737D | Plumber (Plumber Cat) |

**Cat coats (2026-10-27).** Derek asked for a clearly different color scheme on every cat, because the cat meshes may be replaced. So the colors are data, not mesh: `cats.ROSTER` gives each cat its fur, second and third (markings), ruff, muzzle, eyes (eyes2 for an odd-eyed cat's right eye), nose, tail tip, socks (all four paws) and pattern, and `manifest.json` repeats them per cat under `coat` (swatch and hex) and `pattern`, ready to apply to any future model. No two cats share a main coat color. Picture: `docs/concepts/cat-cafe/sheet_cats.png`.

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
| Biscuit | treat_tan | choco socks and tail tip, white muzzle | green | brick |
| Pepper | fur_pepper | salt and pepper flecks (fur_white and fur_black), fur_silver muzzle | amber | dark |
| Socks | fur_ink | fur_white socks, tail tip and muzzle | chartreuse | pink |
| Butter | pastel_butter | white muzzle, a little rounder | blue | pink |
| Moss | fur_moss | cream muzzle, ear tufts | amber | brick |
| Acorn | fur_acorn | fur_brown tail tip, fur_oat muzzle | green | brick |
| Bramble | fur_bramble | fur_seal stripes, fur_hazel muzzle | chartreuse | dark |
| Fern | fur_fern | leaf_dark stripes, white muzzle | amber | pink |
| Rusty | fur_rust_red | fur_smoke_light patches, cream muzzle | green | brick |
| Soot | fur_ash | fur_soot muzzle and tail tip | copper | dark |
| Pipes | fur_smoke_light | fur_charcoal stripes, white muzzle | green | dark |
| Puddle | fur_puddle | fur_mist muzzle and tail tip | amber | dark |
| Binbag | fur_dusty | fur_soot stripes, white muzzle | green | dark |
| Taxi | fur_marmalade | fur_orange_dark stripes, cream muzzle, a white and black checkered band on each flank | green | brick |
| Neon | fur_indigo | neon_pink and sign_teal stripes, taking turns | sign_teal, glowing | pink |
| Birdwatch | fur_dune | fur_hazel stripes, cream muzzle | copper | brick |
| Duckling | fur_white | fur_silver and fur_mist patches | blue | pink |
| Balloon | fur_bubblegum | mint and pastel_butter patches | pastel_sky, glowing | pink |
| Builder | fur_toffee | fur_seal stripes, white muzzle and socks | amber | brick |
| Gardener | fur_cream | fur_grey and fur_smoke_light patches, white muzzle | green | pink |
| Gnome | fur_pewter | fur_white patches and muzzle, long coat, thick tail, a little rounder | green | pink |
| Plumber | fur_gunmetal | fur_white bib, belly, socks and muzzle, fur_gunmetal tail tip | copper | dark |

**Gold cats (v0.5 F42, called shiny until 2026-10-27).** Derek picked gold and asked for gold-modeled cats, called gold. Every cat has `CatCafe_Cat_<Name>_Gold`: the same shapes with the coat in three golds and eyes, nose, inner ears and star specks unchanged. The cat's coat colors (fur, second, third, ruff, and a tail tip or socks when the coat names them) are ranked lightest first by CIE L*: the lightest takes gold_light, the next gold_mid, the next gold_dark, and any coat darker than L* 35 (black, chocolate) takes gold_dark too, so stripes, points and patches still show; the muzzle turns gold_light. The golds are metal: `palette.METAL_SWATCHES` makes them Material Metal on the Part models and metallic in the palette material (a mask texture, `CatCafe_Palette_Metal.png`, into Metallic, Roughness 0.3 there). Gold cats are Part models only; their meshes are the base cats'. Picture: `docs/concepts/cat-cafe/sheet_gold.png`.

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
| Customer NPC | 2.25 x 1.55 x 5.0 | our own chunky townsfolk, not Roblox avatars: hip at 1.55, torso 1.5, a big head 1.45 with a face; the kid is 4.1 tall. The seated twins (`_Sit`) sit on the chair cushion at 1.58 |
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
| Cat (every piece, either body) | 1,500 total; 1,800 with a second prop | plain coats land at 650 to 950 on A and B; themed cats with their prop at 800 to 1,380, with two props at 976 to 1,760 (`props.TWO_PROP_BUDGET`, gold twins the same) |
| Accessory | 200 to 300 | glasses, hat, and the role outfit pieces: apron, barista cap, bow tie, vest, sash, boater, party hat, cape |
| Held net (F93) | 600, 750, 900, 1,100 | Basic, Sturdy, Pro, Master (`CatCafe_Item_Net_L1` to `L4`); they land at 496 to 968 triangles and 28 to 42 Parts |
| Potion bottles (F64, F73) | 700, Big Tip 750 | `potions.py`: they land at 468 to 688 |
| Cafe Crates (F53) | 1,500 | `crates.py`, body and `_Lid` together, golden twin the same: they land at 384 (Neighbourhood) to 1,146 (Park) |
| Mystery Visitor and gift (F64) | visitor 2,600, gift 700 | `mystery.py`: the visitor (cat, hood and capelet) lands at 1,636, the gift at 362 |
| Cat Collector (F63) | 2,600 | `collector.py`: cat, bowler, coat and magnifying glass land at 1,856 |
| Customer NPC | 1,600 | each of the standing and seated twins; the night dealer 1,800 |
| Hero furniture (Counter) | 3,000 | the night dealer's cart 6,000 (with its jars, fish, lights and sack, and the dealer's cat on its cushion) |
| Furniture | 800 | role stations: GreeterPodium 800, StageCatTree 1,400; the F79 CatBed 800 |
| Decor | 500 | |
| Crate decor | 1,500 to 2,400 | the F53 crate furniture and decorations (`crate_decor.py`): 1,500 for the Commons, 1,800 Rare and Epic, 2,400 Legendary and Mythical; they land at 324 to 1,640 (section 14) |
| Rally Crate decor (F101) | 1,800 to 2,400 | `rallycrate.py`, the same budgets: Bleacher Bench 620, Trophy Shelf 1,768, Cheer Bunting 672, Victory Podium 1,720 |
| Alley props | 800 | Dumpster 1,200; rescue traps (TrashBin, GarbageBags) 600 |
| Park props | 800 | Fountain 1,200; rescue traps (RescueTree, TrashCan) 900 |
| Area gates | 6,000 | Park, Neighbourhood, Woods, Sewer: arches with a barrier (section 13) |
| Area sets (v3.2) | 80,000 Park, 120,000 Woods, Sewer and Neighbourhood | a whole area as one Model of Parts; the part count is the real cost (Park 2,758, Woods 5,466, Sewer 4,789, Neighbourhood 5,478) |
| Index Boards | 1,500 | one per area, at its entry inside the gate (section 14) |
| Night pieces | 6,000 per gate fence | the short night (section 14): Alley_NightFenceSegment 2,000, Plot_BackDoorClosed 2,500 |
| Street stations | 6,000 | the Codes Cat desk and the Golden Fish Market stall, each with its cat (section 14); the stall 7,000 with its Fresh Catch board (F94) |
| Currency props | 1,200 | the golden fish coin (`CatCafe_Prop_FishCoin`); its UI picture is rendered from it (section 14) |
| Alleyway set pieces | 5,000 to 6,000 | arches, building backs and the town buildings (Warehouse 6,000); crate stack 3,000, laundry line 2,500, long string lights 1,500, manhole 2,500 |
| Cafe plot set pieces | 12,000 shell, 8,000 interior, 4,000 For Rent, 3,000 per tier, 4,000 back door | built from blocks for the Part export (section 14); the FBX is the reference |
| Door sets and cat flaps (F80) | 4,000 per door half, 1,600 per flap | `doorsets.py`: front double doors land at 1,196 to 3,292, back doors 2,254 to 3,278, flaps 256 to 1,336 |
| Hometown cannon (F84) | 8,000 square, 6,000 per camp, 1,500 landing pad | `cannon.py`: the Town Square cannon (plinth, turret, moon cover and statue) lands at 7,004, each camp cannon 5,104, the pad 1,444 |
| Hometown backdrop | 60,000 | `backdrop.py`: 21,638 triangles in 961 Parts, nearly all of it trees; the hills are one ellipsoid Part each |
| Wild area backdrop | 60,000 | `wildbackdrop.py`: 16,698 (Park, 676 Parts) to 25,512 (Woods, 969 Parts) triangles; the Alleyway's city is the most Parts, 1,166 |
| Lucky Cat statue | 4,000 | `luckycat.py`: 646 to 726 triangles, 51 to 59 Parts a level |
| Welcome arch (F84) | 8,000 | `welcomearch.py`: 6,654 triangles in 548 Parts, a third of them the board's letters |
| Camps (F84) | 20,000 | `camps.py`: ground, walls, pad, carrier basket and theme props land at 6,596 (Sewer) to 12,306 (Alleyway) |
| Front lawn (F91) | 800 small, 1,500 big, 2,500 Tier 4 and 5 big; paths 1,000, fences 2,400 | `lawn.py`: small pieces land at 392 to 796, big at 620 to 2,472, paths at 204 to 804, fences at 744 to 1,968 (each fence is both halves, 30 studs). A fully dressed lawn (six pieces, a path and a fence) is 6,600 to 10,300 triangles and 500 to 1,000 Parts, well over the 1,500 the spec guessed; the eight-lawn phone check in front-lawn.md section 6 decides |
| Camp extras (F100) | 3,000 | `campextras.py`: the Fish Pond 1,036, the Picnic Basket 1,052, the Yard Sale 1,722 and the Lost and Found 1,848 |
| Leaderboard row (F98) | 8,000 | `leaderboards.py`: 5,250 triangles in 358 Parts for the three boards, the plinth and the planters |
| Rescue Rally board (F101) | 8,000 | `rally.py`: 4,004 triangles in 281 Parts; the Rally bunting 272 and 240 |
| Items | 300 | dealer foods: Sardines 400, Caviar 600; TipPile prop 600 |
| Menu items and order props (F90) | 500 an item, 1,500 the oven | `menu.py`: the twelve items with their plate 250 (Cake slice) to 484 (Tea); GoldPlate 148 of 200, Tray 240 of 400, CoinBag 420, Oven 716 |

The build script prints the triangle count for every export and fails the build if a budget is exceeded.

## 6. Naming

`CatCafe_<Category>_<Name>[_<Variant>]`, PascalCase, no spaces, ASCII only. The same name is used for the Blender object, the exported file, the MeshPart or Model in Studio and the asset id in code. Categories: `Cat`, `NPC`, `Furniture`, `Decor`, `Alley`, `Park`, `Item`, `Accessory`. Upgrade levels are `_L1`, `_L2`, `_L3`.

Examples: `CatCafe_Cat_Tabby`, `CatCafe_Cat_Tabby_Head`, `CatCafe_Furniture_Counter`, `CatCafe_Furniture_EspressoMachine_L2`, `CatCafe_NPC_Customer_B`, `CatCafe_Item_FoodBowl_Premium`.

The full list with sizes, triangle counts and Studio notes is generated into `assets/cat-cafe/exports/manifest.json`. The roster of cats and the asset order come from `docs/design/cat-cafe/data-model.md` section 3 and `features.md` section 5; this guide does not duplicate them.

Parts that need a Studio material or a script are separate objects inside one asset, suffixed by job: `_Tube`, `_Bulb`, `_Bulbs` and `_Pane` (Neon at night, section 9), `_Glass` and `_Water` (Transparency), `_Open` and `_Closed` (door sign faces, one visible at a time), `_Handle`, `_Hoop`, `_Bag` and `_Bag_Glass` (the held net's pole, rim, strands and see-through netting), `_Lid` and `_Branch` (rescue trap parts that move: the TrashBin and TrashCan lids, the RescueTree branch, with `_Bin`, `_Can` and `_Trunk` as the fixed rest), and the cat's hinged pieces (below). Other suffixes in a multi-object asset (`_Board`, `_Frame`, `_Post`, `_Wire` and the like) are plain SmoothPlastic parts. Everything else is one object, one MeshPart.

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

Lighting.Technology Future, Bloom low, ColorCorrection Saturation +0.05, Contrast +0.05. The light follows the server clock through the whole day and night, not just a flip at dusk (Derek, 2026-10-27 22:37: "the brightness should reflect time not just when its night everything is too bright"). `shared/DayLight.luau` holds the looks below (PR #376); each phase runs through its keyframes and ends on the look the next one starts with, and WorldController applies them to Lighting and its Atmosphere. Day keyframes at 0, 0.12, 0.45, 0.75, 0.93 and 1 of the day: sunrise, morning, midday, golden, dusk, sunset. The night falls to the night look in its first fifth, holds it, and warms back to sunrise from 85%.

| setting | sunrise | morning | midday | golden | dusk | sunset | night |
|---|---|---|---|---|---|---|---|
| ClockTime | 6.4 | 8.6 | 12.5 | 16.2 | 17.7 | 18.3 | 0.5 |
| Brightness | 0.9 | 1.3 | 1.5 | 1.35 | 0.95 | 0.75 | 0.6 |
| OutdoorAmbient | 150,125,120 | 142,134,128 | 138,132,126 | 148,132,116 | 125,105,115 | 90,85,110 | 45,55,85 |
| Ambient | 95,85,85 | 98,94,90 | 100,96,92 | 100,96,92 | 85,78,85 | 60,58,78 | 30,35,55 |
| ExposureCompensation | -0.1 | -0.2 | -0.2 | -0.2 | -0.1 | 0 | 0 |
| ColorShift_Top | 255,190,150 | 255,225,195 | 255,245,232 | 255,210,160 | 255,170,140 | 200,165,190 | 150,170,220 |
| Atmosphere Density | 0.3 | 0.3 | 0.3 | 0.3 | 0.3 | 0.3 | 0.4 |
| Atmosphere Color | 255,195,160 | 235,218,205 | 210,224,238 | 255,212,160 | 245,160,135 | 190,140,150 | 110,120,160 |
| Atmosphere Haze, Glare | 2.6, 0.6 | 2.2, 0.3 | 2, 0 | 2.3, 0.5 | 2.5, 0.4 | 2, 0.2 | 0, 0 |

The brightest the day gets is midday at Brightness 1.5 and exposure -0.2; the old day look (Brightness 2, OutdoorAmbient 170,160,150, exposure 0) was too bright. Exposure +0.25 at night washed the lit cafe out to white (PR #239), so the night stays at 0. Change the numbers in `DayLight.luau` and here together.

Parts that switch at night (all exported as their own object, suffix `_Bulb`, `_Bulbs`, `_Pane` or `_Tube`): StreetLamp Bulb, ShopWindow Pane, StringLights Bulbs, HangingLamp Bulb, NeonSign Tube. Day: SmoothPlastic in their palette color (the window pane is Glass, Transparency 0.5). Night: Material Neon, Color lamp_warm (neon_pink for the sign); bulbs and tubes are solid, window panes keep Transparency 0.3 so you can see into the cafe. The child light is enabled: street lamp SpotLight 255,200,150 Brightness 3 Range 30 Angle 100; window, string light and sign tube PointLight 255,214,170 Brightness 0.8 Range 10; hanging lamp PointLight Brightness 1.2 Range 14 (on by day too, indoors). Stronger window and string lights (the old 1.5 and 16) wash the cafe interior out to white, so keep new lights at or under these values (PR #239, playtest #184). The cafe door sign shows `DoorSign_Open` by day and `DoorSign_Closed` at night. From v0.5 (F44) cafes close at night and customers leave: owned cafes hang `CatCafe_Plot_ClosedSign` in the front door, a night_sky board with CLOSED on both faces, two stars and a crescent moon (`_Moon_Bulb`, so it glows lamp_warm). The `vignette_alley_night.png` concept image is the target look.

Sky: `CatCafe_Sky`, a Sky instance in Assets (built by `blender/sky.py`) that the client clones into Lighting in place of the Roblox default (Derek, 2026-10-27). Pale blue overhead (#88BDE6), light blue at 32 degrees up (#AACFEA), a warm cream horizon (#EFDDC1) and a sandy haze below it. It stays off pure white so the sky never out-glows the lit cafes. No clouds, sun or moon are painted in: Roblox draws the sun, moon and stars over it, and the lighting presets above set the time of day. Every face comes from one gradient by height in the sky, so the faces meet with no seams and the four sides share one image. To change it, edit `STOPS` in `sky.py`, run it, upload each changed image once with the upload-image workflow and put the new ids in `IDS`; the model is only written when every id matches its image. Preview: `previews/CatCafe_Sky.png`.

## 10. Export and import checklist

Blender export (the build script does this): FBX, Selected Objects, Object Types Mesh only, Apply Unit, Apply Scalings "FBX Units Scale", Forward Z, Up Y (Roblox's documented settings; Forward -Z would turn every model to face +Z), Mesh Smoothing Face, no Leaf Bones, no animation. A `.glb` sits next to each `.fbx` for tools that prefer glTF; it keeps glTF's own axes, so import the `.fbx` into Studio.

Studio import (3D Importer): Scale Unit Studs, Rig Type none, Insert using Scene Position off, Anchored on. After import check: 1) it stands on the floor with the pivot at the base, 2) the front faces the camera when you use View Selected from the front, 3) scale next to a 5-stud R15 dummy matches the table above, 4) texture shows the right colors (if the whole mesh is grey, set TextureID to the uploaded palette), 5) CollisionFidelity Box for simple props, Hull for the counter, cat tree and dumpster, 6) RenderFidelity Automatic, DoubleSided off.

Toolkit QA (since 2026-10-27): run `assets/cat-cafe/blender/toolkit_qa.py` after a build. It uses the EL4CTEO blender-skills (`blender-asset-qa` with the `roblox` profile, `blender-game-optimization` with the `roblox` budget) and lists visible overlaps and floating parts with the code line to change. Rules it enforces: two faces of different colours never share a plane (move one 0.01 studs: proud, recessed or past the other's edge), and no part hangs more than 0.05 studs off the piece it belongs to unless it is meant to (sparkles, litter on the ground, add-ons that touch the cafe shell).

Overlap check in the Part models (since 2026-11-01, Derek 2026-10-30 "models flicker"): `rbx_zfight.py` looks for faces of two Parts that lie in one plane and overlap, which Roblox draws as a flicker even when the Blender mesh is clean (Parts are sized and placed apart from the mesh). The exporter runs `rbx_zfight.unfight` on every model it writes: the smaller face moves 0.03 studs clear of the bigger one (forward when it stood level or in front, back when it was set in), up to 3 times that when a neighbour is in the way, in up to six passes. Run `python3 rbx_zfight.py [--only names] [--out report.md] [--where]` from `assets/cat-cafe/blender` to check; every model should report 0. Render previews with `JITTER=0` when you want to see flicker spots, because the preview otherwise grows each part a hair to hide them.

## 11. Previews and reviews

After every visual task save 2 to 4 PNGs to `docs/concepts/cat-cafe/` with a one-line caption in `docs/concepts/cat-cafe/README.md`. The build script renders a three-quarter view of every asset and a contact sheet for the whole set.

## 12. Poses

The slice has no skeleton. Every pose turns the cat's hinged pieces (section 6) about their joints, so it works for every cat. `manifest.json` carries two kinds, with every value in Blender and Roblox axes:

- `cat_poses` turn single pieces of body A or B, after an optional `lift` of the whole cat: `lick` (B: the left front paw up at the mouth, head tipped down to it; Derek, 2026-10-27: the paw-up sit is licking a paw), `loaf` (A: belly on the floor, all four legs folded under), `sleep` (the loaf with the head down and turned and the tail curled round) and `eat` (A standing, head down to a bowl). In Roblox turn each piece's Model with `piece:PivotTo(piece:GetPivot() * CFrame.Angles(...))` using `angles_roblox_deg`, Head first, then move the whole model by `lift_roblox` times the cat's `scale`. Preview: `previews/Pose_Cats.png` (walk, sit, lick, loaf, sleep, eat).
- `poses` move the whole walking cat as a Body CFrame plus a turn of the Head and the Tail: `carried` (relative to the HumanoidRootPart centre, 3 studs above the floor on a default R15 character; `previews/Pose_Carried.png`) and `upright`, which is now only the base of the bin traps. Each v0.3 rescue trap has a `stuck_pose` (Alleyway `TrashBin` and `GarbageBags`, Park `RescueTree` and `TrashCan`): in the bin and the can the cat stands inside with its head and front paws over the rim; in the bags it is buried with its head and front paws out the front; on the tree it lies draped across the branch between the trunk and the leaf tuft, facing the tree's front and looking down at the player (the engineer's #200 pose), its Body welded to the `_Branch` so it rides the shake. `body_cframe_roblox` is the Body CFrame as 12 numbers for `CFrame.new(table.unpack(t))`; `head_offset_roblox` moves the Head joint in the Body's own frame. Previews: `previews/CatCafe_Alley_TrashBin.png` and the other three, collected in `sheet_poses.png`.

Cats wear no collar, strays and cafe cats alike (Derek, 2026-10-27). Working cats (v0.3 roles, data-model section 5) sit at their stations on body B in their role's two-piece outfit, which is what marks a cat as staff: Apron and BaristaCap for the barista, BowTie and Vest for the waiter, Sash and Boater for the greeter, PartyHat and Cape for the entertainer (`role_outfits` in the manifest, `previews/Pose_Uniforms.png`). The pieces share the cafe palette: mint and cream for the barista, dark_wood with a white shirt and gold buttons for the waiter, shirt_red and straw (treat_tan) for the greeter, sign_teal and neon_pink with gold stars for the entertainer. Put each piece on the sitting model's `Outfit_<Piece>` Attachment and scale it by the model's `Scale` attribute; multiply every pose position by it too. Idle bob, blinks, ear twitches and tail wag are tweens on the piece Models (the vfx-animator's Effects code). Gavin's reference images (in the shared project folder under cat-cafe/docs/concepts/cat-cafe/reference/, not committed because they are not ours) show cube-headed collectible cats with big glossy eyes.

Themed cats (data-model section 3c) each wear one signature prop, built in `props.py` and named `CatCafe_Cat_<Name>[_Gold][_Sit]_Prop`, on both bodies and the gold twins. The prop has a slot: `Head` (hats, horns, antlers, headphones), `Face` (glasses, masks, the eye patch, the bubble pipe) or `Back` (cape, wings, guitar, skateboard, backpack, the firefly jar). Head and Face props pivot at the neck and the Part model nests them in the Head Model, so a head turn carries them; Back props sit in the root Model and ride the Body. Every prop Part carries a `Follows` attribute (`Head` or `Body`) and the cat's root Model a `PropSlot` attribute. When a themed cat works, `CatPose.dress` leaves off the role piece in the prop's slot (a Head prop replaces the BaristaCap, Boater or PartyHat, a Back prop the Entertainer's Cape) and keeps the other piece; Face props keep the whole outfit. Clear parts (lenses, the helmet, bubbles, the jar) are `_Prop_Glass`, Glass at 0.45. Props follow the toolkit rule for details: sunk 0.005 to 0.01 into the surface they sit on and at least 0.01 proud of it, never coplanar with a face of another swatch. Review sheets: `docs/concepts/cat-cafe/themed_cats_<area>.png`. **Second props (F78, v0.13).** A themed cat can wear a second prop in another slot, the object `_Prop2` (`props.PROPS2`): the Jazz Cat's saxophone, the Gardener Cat's watering can and the Plumber Cat's wrench on the back, the Gnome Cat's beard on the face. The root Model's `PropSlot2` attribute names that slot and its parts carry `Follows` like the first prop's; a Face second prop nests in the Head Model. `CatPose.dress` (F71) leaves off the role pieces in both slots, and an Entertainer with a Head and a Back prop wears the PartyHat in place of its head prop and drops the Cape. On body B a back prop keeps its inner face 0.07 behind the chest's back (`props.B_CLEAR`), clear of the waiter's vest, the barista's apron bow and the greeter's sash; straps come over the top of the chest under the chin (`_sling`). The F78 cats: Binbag (a black bin bag over the back, Back), Taxi (a roof light, Head), Neon (fedora, Head; saxophone, Back), Birdwatch (prism binoculars, Face), Duckling (a duckling, Head), Balloon (three glowing balloons, the three biggest parts, Back), Builder (hard hat with a pencil, Head), Gardener (sun hat, Head; watering can, Back), Gnome (gnome hat, Head; beard, Face) and Plumber (work cap, Head; wrench, Back). Review sheets: the Model-Agent library's `f78-themed-cats-1.png` and `-2.png`. **Second props for the earlier themed cats (Set 4 Q2, 2026-11-02).** Seventeen more cats got a second prop, all in the slot their first prop leaves free: Munchkin (Skater, a teal cap on backwards with a gold star, Head), Fold (Painter, a paintbrush across the mouth, Face), Chonk (Chef, a curly moustache, Face), Postie (Mail, a letter held by its corner in the mouth, Face), Marshmallow (Super, a red domino mask, Face), Comet (Ice Cream, round pink sunglasses with sprinkles, Face), Pinecone (Scout, a ranger hat, Head), ForestCat (Lumberjack, three logs tied with rope, Back), Toadstool (Mushroom, a mossy patch of toadstools, Back), Firefly (a headband with two antennae tipped with glowing balls, Head), OldOak (Antler, a cloak of leaves, Back), Lantern (Miner, a pickaxe, Back), Bubbles (a rubber duck in bath foam, Head), Gears (Steampunk, a top hat with a brass gear, Head), Glimmer (Diver, an air tank with a hose, Back), Bottlecap (King, a violet cape with an ermine collar, Back) and Eclipse (Dragon, two curved horns, Head). Second props have no glass parts. Review sheets: the Model-Agent library's `second-props/` folder.

## 13. Cafe plots and the street

The street is a row of cottage shopfronts, never grey boxes (world-and-feel.md sections 3 and 5). Each plot's
shell (`CatCafe_Plot_Cafe_<Colour>`) is a pastel cottage: mint, blush, pastel_butter or pastel_lilac walls by plot
number, offwhite trim and corner pilasters, a terracotta plinth and gable roof with brick tile lines and a chimney,
two arched windows with striped awnings in the accent colour (blush, mint, sign_teal, pastel_butter), an arched
door with a sunburst fanlight, a sign board with cat ears on the front gable, and a front garden with a path,
flower beds, a picket fence, a bench and a lamp post. Inside (`CatCafe_Plot_Interior`) follows the concept sketch:
caramel plank wainscot with a dark chair rail, cream walls, mint curtains, tie beams with mint pendant lamps over
the tables, a chalk menu board, plant and mug shelves, framed pixel portraits of our cats and coloured string
lights. Empty plots add `CatCafe_Plot_ForRent` (half-down shutters, a FOR RENT blade sign, a dust sheet over the counter,
the tables put away with their chairs turned up on top and one under a sheet, boxes and a broom; no cat) and running cafes add the tier sets `CatCafe_Plot_Tier1` to `Tier5` cumulatively: chalkboard;
flower boxes and a bistro set; neon OPEN, string lights and a second bistro set; a fish tank in the window and the
back patio pergola; gold trim, the cup-with-ears rooftop sign and a red carpet. Previews:
`previews/CatCafe_Plot_*.png`, the Part versions in `rbx/`.

Cafe styles (F53, golden-fish.md): the shell's walls are two child Models the server recolours. `<shell>_Paint` is
the pastel outer layer (facade, side and back walls, gables, the spandrels round the arches), every Part tagged
`Paint`; `<shell>_Wallpaper` is the cream inner layer, tagged `Wallpaper`. Plinth, roof, door and garden stay in
the shell's own parts, so a paint never reaches them. The floor is code-built and tagged by the server. Since F89
(Gold Leaf, VFX-Agent's glint) the chunky trims are a third child Model, `<shell>_Trim`, every Part tagged
`PaintTrim`: window jambs, heads, sills, arch rings and keystones, the front and back door frames and the door's
arch (in the cafe's accent colour), the corner pilasters, the eave cornices, the attic vent ring, the awnings' head
rails and the sign's frame (F89 2c: Gold Leaf gilds "every trim"). The roof's barge boards and eave fascias are
`<shell>_Roof_Trim` inside `<shell>_Roof`, tagged the same. Anything under 0.19 studs thick (glazing bars, shutter
slats, the fanlight's rays, the vent's bars) stays in the shell's own parts, because the glint recolours one Part at
a time and slivers read as flicker. The shell's base, corner pilasters, downpipes and the walls' paint layer run
0.3 below the plot floor (the plot stands 0.2 above the grass and the walls stand outside its edge), the side walls
reach up into the roof slab, and the arched glass runs 0.05 past the arch into the wall so no daylight shows between
glass and wall (QA world scan 2026-11-01, M2, M3, M5). Inside, the curtains lie on the wallpaper from the window's
edge, never on a pole in front of a gap (QA recheck after #630, M1, M2).

The Alleyway behind the cafes is a city back street at cosy scale: building backs 30 wide and 16 to 24 tall in
brick with concrete quoins, cornices and window frames, a few lit windows with curtains (`_Pane`), shutters and
flower boxes in the street's pastels, AC units, drainpipes and pipes. Variants: `CatCafe_Alley_WallWindows`,
`WallDoor` (green staff door, teal canopy, lamp), `FireEscape` (two walkable landings, a ladder and stairs) and
`Mural` (sunset bands, CAT CAFE and pixel faces of Tabby, Tuxedo, Siamese, Void and Calico). Arches over the mouths
of the Alley Square (`CatCafe_Alley_ArchStreet`, `CatCafe_Alley_Arch`) are brick posts with lanterns, a teal name
board and an iron arc of bulbs with a gold cat medallion; since F84 the two `CatCafe_Alley_Arch` stand over the
Alleyway's two ways out of its camp and read THE ALLEYWAY on both faces. Props: a crate stack in climbable steps, a laundry line,
long string lights and the Sewer manhole with barricades. Area gates are arches over the full opening with a
ForceField barrier and a hanging sign board, themed: the Park in brick with ivy, planters and a green iron frame;
the Woods in timber posts and a log beam with moss, mushrooms and small spruces; the Sewer in concrete with hazard
stripes, a big pipe and slime; the Neighbourhood in brick with a white pergola, hedges and a mailbox.

The town buildings (`CatCafe_Alley_Building_<Name>`, `townbuildings.py`) replace the repeated backs and the staff door with whole little buildings, each its own colour, height and roof so no two neighbours match: Bakery, Townhouses, Warehouse, Grocer, Apartments, ClockHouse, MusicShop and NarrowHouses. Shops say what they are with a hanging picture sign (bread, apple, music note), never words. Each is 30.6 wide like the backs, with a 3 deep body standing over the 1 thick outer wall: the pivot is the back plane at the bottom centre, set 2.25 behind the wall's inner face so the facade is 1 out into the lane and the body's back meets the Woods' and the Sewer's own walls (only the back sills and eaves reach 0.25 into them); lane-side doors, sills, canopies and lamps keep within 3.5 of the facade. The backs have plain windows for the areas behind. The Warehouse carries the walkable fire escape at the FireEscape's place (`ledges_roblox`), so the crate stack beside it still climbs to landing 1.

The Town Square keeps its middle and its quarters for features; its dressing lives on the edge (Derek 2026-10-28: "move triangle flags and lamp posts/benches to perimiter of town square to make more space in the middle for other features"). Twelve `CatCafe_Square_Lamp`s stand on the middle of the brick border, 22.5 apart along each side (at the corners, beside both sign arches and at both sides of the lane's ends), their lantern arms across the side so no lantern hangs in a bunting's line. `CatCafe_Square_Bunting` (22) runs lamp to lamp round all four sides and `CatCafe_Square_BuntingShort` (16.5, 12 flags) over each end of the lane; the street's two ends have the sign arches instead. A `CatCafe_Square_Bench` faces the square under the middle of each long span, 1.6 inside the lamp line. The manifest's `placements_roblox` rows are the layout (`square.PLACEMENTS`).

The hometown backdrop (`CatCafe_Town_Backdrop`, `backdrop.py`; Derek 2026-10-28: "nicer background of the actual game outside of the map" and "the sides of the map are blended in with terrain more smoothly and not just a patch of grass ground stretching out") is everything past the town's hedges, placed once at the town's origin with no turn. Its ground carries on from the town's own plate in the plate's grass colour and Grass material (exporter `LOOKS`), and the near hills are that same grass, so there is no seam. Hills are ellipsoids sunk 1.6 times their height into the ground, so each rises gently instead of standing on it like a dome; the near ring hides the plate's edge and stays low on the street's line so the view down the street opens onto the far ring, which is paler (150, 186, 128) so the horizon reads in layers. Between the hedges and the hills: meadows with tree clumps, bushes and wildflower tufts; a row of cottages past the north arch with the windmill on the line behind; a walled garden with a bandstand past the south arch; a barn with a silo and hay bales to the east; a pond to the west. Nothing of it stands inside the hedges. Every Part of an asset whose name holds `_Backdrop` has no collision, shadow or raycast (`rbx_export.BACKDROP`), and the cottage and windmill windows are `_Bulbs`, lit at night.

The wild areas' backdrops (`CatCafe_<Area>_Backdrop`, `wildbackdrop.py`; hometown-cannon.md section 6a: "a backdrop ring outside its walls (hills, trees, house roofs or brick vaults by theme)") follow the same rules round each area and its camp, in set space, so each is placed where its camp set goes. Their ground starts at the edge of WorldBuilder's plate (80 past the walls and the camp) and the near pieces stand at least 3 studs clear of the walls and the camp set. Each area has its own theme so a player knows where they landed: the Alleyway in city blocks hard by its walls, taller ones behind and towers in soft hazy colours further off, on asphalt; the Park in parkland and grassy hills, opened round a lake past its far wall; the Neighbourhood in house rows facing it across a road with a pavement, fences and street lamps; the Woods in a fir and oak forest under a ring of grey mountains, the tallest snow-capped; the Sewer in brick works sheds with arched windows on a concrete yard, chimneys, a water tower, gas holders and a big pipe along each side. City and works buildings show rows of windows by a lit glass face behind floor bands and piers, which costs a dozen Parts a building instead of one per window. Sizes come from `Config.World`'s v4 numbers (AREAS in the module), so F85's long rectangles are a rebuild with their new numbers.

The Lucky Cat (F88, `luckycat.py`) stands by every cafe's door, left of it in plot space (-5.1, -16.1), where the left potted shrub was: a 1.5 square stone plinth, a red cushion and a beckoning cat sitting up, in the game's blocky cat shape with happy closed eyes, blush, whiskers, a red collar with a bell, a gold coin held to its chest and its left paw raised by its ear. Each level is its own model: 0 is the empty plinth with a teal LUCKY CAT board so players see there is something to buy, then clay (terracotta), bronze and silver (Metal through `rbx_export.SWATCH_MATERIALS`, a per-asset swatch to material table), gold (Metal like every gold swatch) and jade (Marble, so it has jade's veins); from gold up the plinth gets a gold cap and the cushion gold tassels. The raised paw is a child Model `_Paw` whose pivot is the shoulder (with an Attachment `PawHinge` on the body there), so the wave turns it about one axis without touching the head.

The welcome arch (`CatCafe_Town_WelcomeArch`, `welcomearch.py`; hometown-cannon.md section 2: "a 'Cat Cafe Town' welcome arch over the street end") stands over both ends of the street, one model turned to face the square each time (Layout.townEnds). It is the town's grandest gateway and a landmark from the spawn: two brick towers on the grass beside the sidewalks with cream bands, teal domes with gold finials, lit arched windows and a gold paw on a teal medallion front and back; a cream arch edged in terracotta across the 36 stud opening with bulbs along its top; a teal board hung under it on two chains, CAT CAFE TOWN between two paws toward the square and WELCOME TO CAT CAFE TOWN on the outer face; and a big blocky ginger cat peeking over the top with its paws hooked over the front edge and its tail along the arch behind it. A garden bed across the street's end (brick kerb, a clipped box hedge, tulips, flower clumps and four topiary balls in terracotta pots round a little paw sign) ends the street in a garden instead of at the town's end hedge, which stands just behind it. The arch's bulbs, the board's bulbs and the tower windows are `_Bulbs` and the lanterns `_Lamp_Bulb`, so it lights up at night. If the game's final name changes, the two board lines are the only text to rebuild. `CatCafe_Town_` joins the exporter's collide and outdoor families, so the towers, kerb and pots are solid (the town backdrop stays walk-through under its `_Backdrop` rule).

The hometown cannon (F84, `cannon.py`) stands in the middle of the Town Square: a cream barrel with gold bands and
teal paws on a teal carriage with gold-rimmed wheels, a ladder up the back to the hatch, a fuse on the left shoulder,
on a round cream plinth with two steps to the south, a coping paw print in each area's colour pointing its way and
the golden waving cat statue on the south-east. `_Turret` turns about Y at its pivot to aim (the turns are in the
manifest's `turret`); `_MoonCover`, a night-sky cap with a gold crescent and stars, closes the mouth at night. The
landing pad is a flat cream disc with a paw print in the trim colour and a ring of dashes. Each side area has a camp
outside its gate (`CatCafe_Camp_<Area>`, `camps.py`): 30 deep and as wide as the area, its ground and path in the
area's swatches, low themed walls on the back and sides under a tall invisible barrier, the landing pad, a three-quarter cannon at the back trimmed in the area's colour (`CatCafe_Camp_Cannon_<Area>`)
and a wicker carrier basket beside the pad (`CampBasket` tag, `Drop` attachment). The red SAFE ZONE line and words
are the game's own paint on every camp (WorldBuilder), so the sets carry none. The Alleyway's camp lies across both
lanes' north ends: a brick building end (`_BlockEnd`, two shuttered windows with flower boxes) on the block between
them, where the Index Board stands, string lights over both ways out, a dumpster, bin bags, trash cans, crates and
boxes, benches, lamps and flowerbeds. Theme props: the Park's benches,
lamps, trees and flowerbeds; the Neighbourhood's mailbox, bins, lamp posts, picket fences and hedges; the Woods' tent,
campfire, log benches, lanterns and pines; the Sewer's manhole, big pipe, wall lanterns, barrels, cones and tyres.

The front lawn (F91, `lawn.py`, front-lawn.md) is what a player places in the front garden. Pieces are
`CatCafe_Lawn_<Piece>` (the catalog name without spaces), pivot the base centre on the grass top, front -Z to the
street: small ones keep to 2 x 2 (Tulip Bed, Sandwich Board, Potted Cat Topiary, Mailbox, Lamp Post, Bird Bath,
Garden Gnome Cat, Balloon Bunch), big ones to 4 x 4 (Bicycle with Basket, Garden Bench, Umbrella Table, Little
Fountain, Fairy Light Arch, Flower Cart, Cat Tree Sign, Golden Paw Statue). Paths are `CatCafe_Lawn_Path_<Style>`
(Grey Slabs, Red Brick, Stepping Stones, Paw Print Path), 7 x 5 over the shell's own path (plot x -3.5..3.5, z
-20..-15), pivot its centre at the plot's floor level; each keeps ground under the door mat. Fences are
`CatCafe_Lawn_Fence_<Style>` (White Picket, Low Hedge, Iron Railing, Flower Box Fence), both halves from the path's
gap (x 3.9) to the plot's edge (x 19) each side, pivot the gap's centre on the fence line (plot z -19.85). Lawn parts
collide like other outdoor sets. The moving and lit bits: the Mailbox's `_Flag` (pivot on its hinge, lying back
along the side; -90 about the pivot's X raises it), the Bird Bath's robin `_Bird_Bob`, the Balloon Bunch's
`_Balloons_Swing` with the LED `_Balloons_Glow`, the Fairy Light Arch's and Flower Cart's `_Lantern_Swing` with
`_Lantern_Glow`, the Cat Tree Sign's `_Star_Spin` and `_Toy_Swing`, the Golden Paw Statue's `_Paw_Spin`; night
lights are `_Bulbs` (Lamp Post, Fairy Light Arch, Cat Tree Sign, Golden Paw Statue). `_Water` (Bird Bath, Little
Fountain) and `_Flowers` (Flower Cart, Flower Box Fence) as elsewhere. The Sandwich Board's chalk face is `_Chalk`
and the Cat Tree Sign's name board `_NameBoard`, with the painted CAT CAFE in `_NameText` for the UI to hide when it
writes the cafe's name. The Garden Bench has a `NapSpot` attachment on its cushion and the Umbrella Table `Seat1`
and `Seat2` on the floor under its chairs (a customer faces the table). The cafe shell's own garden is two child
Models the lawn code hides: `_Path` (the path and its joints) when a path style is laid, and `_Garden` (beds, picket
fence, bench, lamp post, the round bush and the flower clumps on lawn spots, with the beds' `_Flowers` and the
`_LampPost_Bulb` nested inside) once the lawn is live. The door mat, the potted shrub right of the door, three flower
clumps on leafy tufts and the `_Fireflies` stay on the shell, standing on the grass and clear of every lawn spot, so
a new front is never bare. Lawn spots (`Layout.cafe.lawnSpots`, plot space): small by the path (±5.0, -18.3), small
by the wall (±8.5, -17.3), big (±14.0, -17.8); a big spot under a window has 3.2 studs of depth in front of the
Tier 2 window boxes, so big pieces keep their ground footprint within 3.1 deep (the Little Fountain is scaled to
fit). The bistro sets of Tier 2 and Tier 3 stand in the garden too, so each is its
own child Model, `CatCafe_Plot_Tier2_Bistro` and `CatCafe_Plot_Tier3_Bistro`.

Each camp from the Park on has one extra (F100, camp-extras.md, `campextras.py`), the size of an Index Board, beside the way out across from the board (`campextras.SPOTS`, area space): the Park's Picnic Basket (a red checked blanket, a wicker basket with a Money Potion peeking out, a teal thermos, sandwiches, an apple and fish crackers), the Neighbourhood's Yard Sale (a folding table with a striped cloth on a rug, two cardboard boxes with crates inside and "40" price tags with a gold fish, a lamp, books, a teapot, a cash tin, and a hand-painted YARD SALE board hanging from a little frame), the Woods' Fish Pond (a ring of stones, lily pads, reeds and cattails, a cat-sized jetty with a bucket of golden fish and a rod in its holder) and the Sewer's Lost and Found (a battered crate stencilled LOST AND / FOUND with a sock, an umbrella's hook and a teddy's ear poking out under its lid, a list pinned to its side, a boot and a puddle, under a standpipe that drips onto the lid). Each moving touch is its own child Model for Animation-Engineer: `_Sign_Swing` pivots on the bar it hangs from (turn about Z), `_Rod` on the rod's butt (turn about X to cast; its line and bobber ride it), `_Fish` at the fish's middle, `_Lid` on the back hinge (a rattle is a small turn about X). VFX points are Attachments on the main model: `Steam` (the thermos's mouth), `FishJump` (on the water above the fish) and `Drip` (under the pipe's mouth). Every extra has a `PromptAnchor` 1.5 up in front of it. The pond's water is `_Water` (see-through, walk-through) and its lily pads stand on stems so nothing floats.

The Town Square's leaderboards (F98, leaderboards.md section 2, `leaderboards.py`) are one model, `CatCafe_Town_LeaderboardRow`: three standing chalkboards on a low brick plinth with a cream cap, a terracotta planter with a clipped bush and a lamp post at each end. Read from the front they are Index, Playtime and Money, each its own child Model (`CatCafe_Town_LeaderboardRow_Index`, `_Playtime`, `_Money`, tagged Leaderboard): a caramel frame round a chalk green face on two dark posts with feet and gold finials, a chalk tray with chalk and a duster, a header plank in the board's colour (teal, galaxy blue, park green) with its name in cream letters, and a round crest on top in a gold ring with a dark green laurel, painted with the board's icon (an open red book, a red alarm clock at ten past ten, a gold paw coin with two sparkles). A ginger cat sleeps on the Playtime header beside the clock. Each board's 5 x 6.4 face is its `Screen` part (Front -Z) for the UI's SurfaceGui, so nothing stands in front of it. The row stands at the east end of the square's lane (Layout point (40, 0.1, 0), turned 90 to face the Cat Cannon), mirroring the Bellhop stand at the west end, and streams in whole (Atomic).

The Rescue Rally weekend (F101, rescue-rally.md section 4, `rally.py`) dresses the Town Square in the Rally colours: red (`shirt_red`), blue (`shirt_blue`), navy (`pants_navy`), gold (`rarity_legend`) and off-white. `CatCafe_Square_RallyBoard` is a sporty scoreboard on two blue posts striped in off-white, each on a concrete footing with a gold ball on top and a pennant flag (red right, blue left): a navy frame with 32 marquee bulbs (`_Bulbs`, lit at night) round a dark 10 x 4 face, a black and white finish-line apron under it, a red header reading RESCUE RALLY front and back between two gold stars, and on its white top band a gold trophy with a paw on a wooden plinth between a red and a blue pom-pom. The face is its `Screen` part (Front -Z) for the UI's SurfaceGui to draw the bar, its three steps, the lap and the time left, so nothing stands in front of it; an off-white paw marks the back. It stands in the north-east quarter at (15, 0.1, 12) turned 30 to face the player spawn, off the lane, the street and the cannon's firing lines. `CatCafe_Square_RallyBunting` and `CatCafe_Square_RallyBuntingShort` are the edge bunting in red, off-white, blue and gold with the same spans and pennant Models, so during the Rally they swap in at the edge bunting's placements.

Where a model meets the code-built walls (gates and arches, 2026-10-27, Derek: "a lot of the gate models for zones
are clipping in eachother and can see it when walking"): a wall that ends at an opening must end inside a post, never
flush with its face, or the two faces flicker. Posts reach 0.12 into the opening and past the wall's back face, and
nothing beside a post sits on the wall's line. Check a placed piece in its scene, not alone: the toolkit only sees
one model, so a gate that passes on its own can still cut through the walls around it.

## 14. Part-built models in Roblox

`build_all.py` also writes `assets/cat-cafe/rbx/<Name>.model.json` for every asset. Rojo syncs that folder into
`ReplicatedStorage.Assets`, so the game uses these instead of the code placeholders with no Studio import. Each
Builder block becomes a Part (cylinders, wedges, balls; cones as stacked bands; flat stars and arches as wedge
pairs), coloured from the palette, SmoothPlastic, no bevels. Glass is SmoothPlastic at 0.6 transparency with no shadow
(Roblox's Glass material bends the view through it, so a cafe room looked broken through its windows: Derek
2026-10-30); water is Glass at 0.3.
Hanging lamp bulbs are Neon; other `_Bulb`, `_Bulbs`, `_Pane` and `_Tube` parts keep their day look until
WorldController lights them at night. Every extra object (Head, Tail, Lid, Branch, Roof, SignBoard, bulbs) is a
child Model whose pivot is that object's origin, so hinges and joints match `part_pivots_roblox`. Big parts of
furniture, alley, park, plot and street assets collide; cats, people, items and decor do not. In the outdoor
areas (Alley, Park, Street, Square, Neighbourhood, Woods, Sewer) thin parts collide too, down to 0.12 thick when
at least 0.9 long, so planks, decks, rungs and rails hold players up. Round parts (ellipsoids) get a block collider
75% of their size so it does not stick out past the curve. An object ending `_Climb` exports as an invisible
TrussPart (sizes in 2-stud steps, top flush with the deck it reaches) behind a ladder's rungs so players climb it.
A ladder is 2.6 between its rails (2.4 clear), its opening at the top at least that wide, and nothing over the
climber's side of it (Derek 2026-10-28: the Great Oak was "just a little too tight to walk around inside and up
ladders").
An object ending `_Barrier` exports as invisible parts that always collide, 30 high on every blocker and outer wall
of a v3.2 area set, so nobody jumps a hedge or a wall (a default jump clears 7.2), and along the water a set's way in
crosses only on its bridges (8c). A barrier always stands on something a player can see (Derek 2026-10-28: "in park
there is a invisible barrier around the edge of the pond", 10-29: "lots of invisible barriers in sewer"): a wall, a
hedge, the bars of a tunnel mouth, or a railing on the water's edge, the Sewer's kerbs a steel guard rail 3.2 high
(yellow top rail, like its catwalks) and the Woods stream's rock edges a log rail 3.0 high, each with its barrier a
0.5 thick wall on the rail's line, so a player walks up to the rail. Water that no way in crosses gets no barrier: the
Park's duck pond is shallow and players and cats wade in it. `_Flowers` never collide.

Names the game code reads, so keep them when an asset is rebuilt: `_Roof` (faded for the owner), a part named
`SignBoard` (owner sign SurfaceGui), `Bars` (a gate barrier, ForceField), `Top` (round table, customers face it),
`_Steam` (espresso cups), `_Chimney` (chimney opening), `_Flowers` (beds and flower boxes, butterflies),
`_Fireflies` (invisible volume over the beds), `_Shutter` and `_Sign` inside ForRent (rolled up and flipped on a
claim), `_Zzz` (sleeping cat). Index Boards (`CatCafe_<Area>_IndexBoard`, `boards.py`): the part named `Screen` (8 x 5, its
Front face carries the player's Index page), the `IndexBoard` tag, an `Area` attribute and ModelStreamingMode
Atomic on the root Model; `placement` in the manifest gives the spot in its gate's frame. Night pieces (`night.py`): every
`CatCafe_<Area>_NightFence`, `CatCafe_Alley_NightFenceSegment` and `CatCafe_Plot_BackDoorClosed` carries the `NightFence`
tag, the moon, stars and sign letters are `_Moon_Bulb` or `_Sign_Bulb` (Neon at night; on the gate fences the
CLOSED board's rim and the moon badge's rim glow too, the letters are a 5 x 7 face with thin strokes and the moon
is a thin crescent, so the sign reads up close), and `placement` names the gate or
arch whose pivot each gate fence takes. The Codes Cat (`CatCafe_Street_CodesCat`, `stations.py`): the `CodesCat` tag,
the part `CodesCircle` (the walk-in circle that opens the code box) and an Attachment named `PromptAnchor` on the desk
front; the cap is nested under `_Head`. The Golden Fish Market (`CatCafe_Street_FishMarket`, `market.py`): an
Attachment named `PromptAnchor` on the counter front, 3 studs up (WorldBuilder hangs the Shop prompt there and adds the
`FishMarket` tag), the coin on the counter front as `_Coin`, the sign lamp as `_Bulb`, the sou'wester nested under
`_Head`. The Fresh Catch board (F94) stands on its own legs in front of the barrel, facing the street, its chalk face the object `_FreshCatch`: one Part whose Front (-Z) face, 1.7 by 1.45 studs, takes the UI's stock list (and "Back at sunrise" at night) under a cream header reading FRESH CATCH. The golden fish coin (`CatCafe_Prop_FishCoin`, `coins.py`) is gold swatches, so Metal. Since F97 the currency has
one picture everywhere, `exports/icons/CatCafe_Icon_GoldenFish.png`: a plump shiny gold fish side on with a happy
closed eye, a pink cheek and a white glint (`icon_art.py`, front view, transparent, a 10 px dark gold outline at 512,
readable down to 24 px); the cat-face coin picture (`rbxassetid://77287948377172`) retires with it. The crate furniture and decorations
(`CatCafe_Decor_<Piece>`, `crate_decor.py`) stand on a decor spot 1.4 studs off a wall, so each keeps to about 4
wide and 2.5 deep around a base-centre pivot, front -Z, and never collides; tall pieces are fine (the Cat Tree Tower
is 10.6). Lamps and neon are `_Glow`, fountain water `_Water`, a window to look through `_Glass`, and the Blossom
Tree's flowers are the child Model `_Canopy` that the petal effect falls from. `_Glow` parts are Neon day and night,
and WorldController leaves them alone. The F80 door sets (`CatCafe_Door_<Name>_Front` and `_Back`, `doorsets.py`) and
cat flaps (`CatCafe_CatFlap_<Name>`) never collide; the code reads `_LeafL`, `_LeafR` and `_Leaf` (each pivoted on its
hinge), the back leaf's `CatFlap` Attachment, `_Sign` and `_Sign_Bulb` (night), `_Flap` (pivoted on the flap's top
hinge) and the Bell flap's `_Bell`. Back leaves keep the flap patch flat on both faces, so any flap fits any back door,
the cafe's own included, and no flap reaches below the leaf's foot. The Cafe Crates (`CatCafe_Prop_Crate_<Pool>` and
`_Gold`, `crates.py`) never collide; the pivot is the base centre with the front -Z, and the lid is the child Model
`_Lid`, pivoted on its back hinge, so the reveal turns it about the pivot's X (positive lifts the front, 105 is wide
open). Golden twins keep the paw, ribbons and accents in colour and are Metal elsewhere. Their shop pictures are
`exports/icons/CatCafe_Icon_Crate_<Pool>[_Gold].png`; the four nets have theirs too (`icons.py`). The Rescue Rally's crate (F101, rescue-rally.md
section 2) is `CatCafe_Prop_Crate_Rally`: a navy kit crate with off-white corners and rails, a red team stripe edged in
white, a gold star and the gold paw on the front, a chequered finish-line band across the lid and a gold carry handle;
it has no golden twin, since it only comes from the Rally. Its twelve pieces keep to the Rally colours (red
`shirt_red`, blue `shirt_blue`, navy `pants_navy`, gold `rarity_legend`, off-white) at the Classic Crate's mix:
wallpapers Pennant Wall (red felt) and Team Banner (navy felt), floors Running Track (red rubber) and Gym Floor (maple
boards), paints Team Stripes (blue) and Trophy Gold (foil gold), whose samples `style_icons.py` makes from the catalog
rows (its PENDING list stands in until Catalog.luau has them); in `rallycrate.py` the Bleacher Bench (two tiers of red
and blue seats on aluminium frames, a megaphone and a gold foam finger), the Trophy Shelf (a wooden case with a navy
back and a red fascia of gold stars: a gold cup with a paw, a silver cup, a framed team photo of two cats, a star
trophy, a ball, folded shirts and a board of gold, silver and bronze medals), the Cheer Bunting (two striped poles and
six pennants, each flag its own `_FlagNN_Pennant` Model for the bunting flutter) and the Victory Podium (1-2-3 steps
with gold, silver and bronze tops, `_Glow` marquee bulbs and a gold cup on top that turns, the child Model
`_Trophy_Spin` pivoted at the middle of its foot); in `doorsets.py` the Medal Door (navy leaves with an off-white
border, red and white team stripes, a gold-framed window, a gold medal with a paw on a blue, white and red ribbon and
a gold push bar) and the Finish Line Flap (a chequered flap in a red frame under a navy hood with a gold band). The F97 pictures
(`icon_art.py`, picture-only models) are the seven foods, each named for its game id (`CatCafe_Icon_Kibble`, `_Tuna`,
`_Sardines`, `_Salmon`, `_Caviar`, `_MoonMilk`, `_StarTreat`) and drawn to read at 48 px on its rarity tile: a kibble
bag with a cat face, a peeled tuna tin, an open night-blue sardine tin with a moon on its lid, a salmon fillet on a
leaf, a tin of black pearls with a gold lid, a bottle of moon milk, a golden star biscuit; the three Golden Fish Market
perks (a gold espresso with a paw in the foam, the big bowl with a "-2:00" tag, a dotted decor spot with a plus and a
tiny plant); and the prize pictures `CatCafe_Icon_Coins` (three gold coins with a $) and `CatCafe_Icon_Spin` (the
Spin Wheel's own wheel). Each net's `_Handle` carries an Attachment named `Grip`, mid wrap with no turn, for the hand in the net
hold (the pole runs along -Z). The nets (F93, catch-rework.md section 1) get better with each level: L1 Basic, a
plain wooden net; L2 Sturdy, a mint pole with steel bands and a steel hoop; L3 Pro, a blue pole and hoop with brass
trims and sky blue netting; L4 Master, a dark wood pole with gold bands, a gold pommel and a pink gem, a gold hoop
with cat ears, lilac netting. The rim (`_Hoop`) is ten bars, alternately 0.016 taller so no two tops share a plane; the
netting is a see-through cone (`_Bag_Glass`, Transparency 0.6) with four strands down it and a ring of eight round its
middle (`_Bag`). The rim's far edge is the point farthest from the Grip, where VFX-Agent's NetTrail starts its whoosh. The potion bottles (`CatCafe_Prop_Potion_<Name>`, `potions.py`) never collide; the
pivot is the base centre with the front -Z, the name is the potion id without `_potion` in PascalCase, the liquid is
the potion's colour in the UI's `Theme.potionColors` and the picture is `exports/icons/CatCafe_Icon_Potion_<Name>.png`. The crate wallpapers, floors and paints are only a colour and a material on the cafe, so each has a picture model, `CatCafe_Style_<Name>` (`style_icons.py`, the catalog name without spaces or marks): a piece of wall with a skirting board, a cornice and a framed picture, a square of floor with a cat bowl, or an open paint tin with a brush. The parts named `_Swatch` take the style's colour and material straight from `Catalog.luau` at build time, so a sample always matches the cafe; nothing in game places them. The HUD's Decor button picture is `exports/icons/CatCafe_Icon_Decor.png`, a cat-eared armchair beside a potted plant. The Mystery Visitor (`CatCafe_NPC_MysteryVisitor`, `mystery.py`) is a sitting cat at scale 1.3 with the usual hinged pieces, its hood the child Model `_Prop` inside `Head` and its capelet `_Cloak`; the pivot is the floor under a chair seat's centre, facing the table (-Z), so the cat sits at 1.57 clear of the chair's back. Its gift (`CatCafe_Item_MysteryGift`) has its pivot at the base centre with the "?" tag to the front (-Z). Neither collides; the client tags them `MysteryVisitor` and `MysteryGift`. The Cat Collector (`CatCafe_NPC_Collector`, `collector.py`) is a sitting cat at scale 1.45 with the usual hinged pieces, its bowler the child Model `_Prop` inside `Head`, its coat `_Coat` and its magnifying glass the child Model `_Lens` inside `LegF2`, which is raised to the right eye; the pivot is the floor under him on the plot's `CollectorSpot`, facing into the room (-Z), and he sits 2.7 tall to the hat in a 2 x 2 footprint. He does not collide; the client tags him `CatCollector`. The night dealer's cart (`CatCafe_Street_DealerCart`) carries the dealer's own cat on a violet cushion at the back of its counter: a blue-black cat with star specks and gold eyes in a little violet hood with a gold edge, folded tip and tassel like the dealer's, made of the usual hinged sitting-cat pieces named `Cat_Body`, `Cat_Head` and so on, its hood the child Model `Cat_Prop` inside `Cat_Head`; it comes and goes with the cart. The cafe customers (`CatCafe_NPC_Customer_<V>`, `customers.py`) are our own townsfolk, each with a face (dot eyes with a highlight, blush, a small smile), hair and an outfit: twelve everyday looks A to L (a bob and cardigan with a takeaway cup; a kid in a cap with a backpack; an elder with a silver bun, glasses and a cane; ginger curls and a short beard along the jaw, clear of the mouth and cheeks, with a striped sweater and a tote; puffs, a hoodie and headphones; a beanie, overalls, a scarf and a book; a kid with pigtails and an ice cream cone; long blonde hair under a straw sun hat with a bunch of flowers; short hair, glasses and a cardigan with a laptop; a ginger ponytail, a yellow raincoat, red wellies and a furled umbrella; an elder in a flat cap with a moustache and a newspaper; long black hair, a butter top, a navy skirt and a tote) and the Rich customer (top hat, monocle, moustache, tails, gold bow tie and cane). Standing ones pivot at the feet; each has a seated twin `_Sit` pivoted on the floor under a cafe chair's middle (the chair's own pivot), facing the table, sitting on the cushion with the forearms on the table top and nothing in the hands or on the back; seated long hair ends above the chair back's posts. None collides. Tags for the audio loops: `FishTank` (decor tank and the Tier 4 tank's water) and
`Fountain`; the engineer tags `CafeDoor` and `WorkingCat` at placement.
The F90 menu (cats-make-orders.md, `menu.py`) is twelve dishes, `CatCafe_Menu_<Id>` for Coffee, Milk, CakeSlice, PawCookie (tier 1), Tea, FishBiscuit (tier 2), KittyCupcake, HotCocoa (tier 3), PancakeStack, Sundae (tier 4), StrawberryRoll and RainbowCake (tier 5), each on its own plate: an off-white plate with a mint rim, 1.1 across with its top at 0.12, the child Model `<name>_Plate`. The food sits inside the plate and under 1.1 tall, so any dish fits a table setting, the counter or the tray, and the later ones look richer: a blush mug of coffee with a heart in the foam, milk with a striped straw, a cake slice with a cherry, a paw-print cookie, tea in a cup on a sky saucer with its tag, two fish biscuits, a pink cupcake with cat ears and a face, a mint mug of cocoa with a marshmallow cat, a pancake stack with syrup and butter, a three-scoop sundae with wafer ears, a strawberry roll with a cream spiral and a seven-layer rainbow slice. The pivot is the plate's base centre with the front -Z; none collides. `CatCafe_Menu_GoldPlate` is the rich customer's plate, gold with a light gold foot, the same size and pivot as `_Plate`, so the game hides `_Plate` and pivots the gold one in its place. `CatCafe_Menu_Tray` is the waiter's head tray, a silver disc 1.4 across on a metal foot with a lip, pivoted at its underside centre for a cat's `Carry` Attachment, with an `Item` Attachment at 0.15 where a dish's pivot goes. `CatCafe_Menu_CoinBag` is the money bag for the tip sweep: a round sack with a red cord, a gold paw on the front and one coin peeking out, pivoted at its base centre; it rides on the tray's `Item` like a dish, since a round bag on its own cannot rest on the ear tips. `CatCafe_Cafe_Oven` stands behind the counter: a mint oven with cat ears, an off-white top and skirting, a timer dial and four knobs, a metal flue and a door (the child Model `_Door`, pivoted on its bottom hinge so it opens about X) with a warm window, rack bars, a handle and a mint paw; its `DoorGlow` Attachment sits at the window for the baking glow. It collides like the other cafe furniture, and its pivot is the base centre with the front -Z. Every cat model, walking and sitting, carries the Attachment `Carry` in its Head part, over the middle of the head at the ear tips (a Maine Coon's tufts, a Fold's folded ears included, `cats.carry_at`), so the tray rests flat on the ears and turns with the head. Walking staff wear the role pieces that fit the level body A (`accessories.WALK_PIECES`): the three hats on the head top as on B, the bow tie under the chin from the Head, and the cape turned to lie along the back from just behind the head; the walking models carry those `Outfit_<Piece>` slots. The apron, waistcoat and sash wrap B's upright chest, so a walking cat goes without them until they have walking meshes.
`rbx_preview.py` renders the Part versions the way Roblox draws them; check them before a PR. A MeshPart import
saved as `<Name>.rbxm` replaces the JSON of the same name (delete the JSON).

## 15. Rules

- Original work only. No characters, logos or art from reference games (Steal an Egg, Spin for a Fisherman, Cookie Run, AFK Arena).
- Young audience. No blood, weapons or scary cats. Even the Void cat is cute.
- Prefer our own assets or Roblox-made ones. Inspect any Creator Store asset for scripts before inserting it.
- Decisions about style changes go in `docs/decisions.md` with the date.
