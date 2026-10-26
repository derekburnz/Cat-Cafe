# Cat Cafe concept images

All images here are rendered from the generated Blender assets in `assets/cat-cafe/blender/` (Cozy Cream style, decided 2026-10-25). Re-run `build_all.py --render --scenes` to refresh them. The `ui/` folder belongs to the UI thread.

| file | caption |
|---|---|
| `vignette_cafe.png` | Cafe interior at cafe level 3: counter with the level 2 espresso machine, Tabby on the counter spot, Tuxedo on the window seat, Void on the wall shelf, Siamese on the cat tree, Calico on the cushion, two tables, fish tank, neon sign, three customers. Lamps are warm point lights. |
| `vignette_alley.png` | The alley behind the cafe at dusk: dumpster with Smoke on the lid, trash cans, crates and boxes beside the spawn points, premium bowl with a tuna lure and Void approaching it, one street lamp doing the lighting. |
| `vignette_alley_night.png` | The same alley at night: street lamp, glowing shop window, string lights and the Closed sign switched to Neon, the three rescue props each with a stuck Ginger. Target look for the night lighting preset in the style guide. |
| `sheet_poses.png` | Tabby wearing the accessory set (glasses, hat, bow tie, apron), the upright pose test with the same parts, the four role uniforms on upright cats (apron, bow tie, sash, party hat), the carried pose against an R15-sized stand-in, and the three rescue props with their stuck pose. |
| `sheet_cats.png` | The 20 slice cats from one rig. Alleyway: Tabby, Tuxedo, Ginger, Smoke, Calico, Tortie, Sphynx, Maine Coon, Void, Midnight. Park: Snow, Cream, Brownie, Blue, Siamese, Bengal, Ragdoll, Persian, Blossom, Aurora. Collar color is rarity; Midnight and Aurora are the Mythical heroes. |
| `sheet_cafe.png` | Customers, counter, espresso machine levels 1 to 3, the five cat spots, table and chair, decor. |
| `sheet_outdoors.png` | Alley and park sets, including the rescue props and the shop window. |
| `sheet_items.png` | Food bowls, kibble, tuna, salmon, the net at levels 1 to 3, and the accessories. |
| `previews/<Name>.png` | One three-quarter view per asset, same name as the FBX in `assets/cat-cafe/exports/`. |
| `views/<Name>.png` | Five-view inspection sheet per asset (front, left, back, top, three-quarter), no floor; Workbench shading on a PC, Cycles CPU in a cloud container (see `assets/cat-cafe/blender/README.md`). Written by `build_all.py --render`; pairs with `assets/cat-cafe/exports/gates.md`. |
| `CatCafe_Palette.png` | The 64-swatch texture every mesh uses (style guide section 2). |

Glass and water parts render opaque or are hidden in these previews; in Studio they get Transparency per `manifest.json`. Neon tubes and bulbs are flat color here and get the Neon material plus a light in Studio.
