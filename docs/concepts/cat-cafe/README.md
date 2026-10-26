# Cat Cafe concept images

All images here are rendered from the generated Blender assets in `assets/cat-cafe/blender/` (Cozy Cream style, decided 2026-10-25). Re-run `build_all.py --render --scenes` to refresh them. The `ui/` folder belongs to the UI thread.

| file | caption |
|---|---|
| `vignette_cafe.png` | Cafe interior at cafe level 3: counter with the level 2 espresso machine, Tabby on the counter spot, Tuxedo on the window seat, Void on the wall shelf, Siamese on the cat tree, Calico on the cushion, two tables, fish tank, neon sign, three customers. Lamps are warm point lights. |
| `vignette_alley.png` | The alley behind the cafe at dusk: dumpster with Smoke on the lid, trash cans, crates and boxes beside the spawn points, premium bowl with a tuna lure and Void approaching it, one street lamp doing the lighting. |
| `sheet_cats.png` | The 12 slice cats from one rig: Tabby, Tuxedo, Ginger, Smoke, Snow, Calico, Siamese, Tortie, Bengal, Sphynx, Ragdoll, Void. Collar color is rarity. |
| `sheet_cafe.png` | Customers, counter, espresso machine levels 1 to 3, the five cat spots, table and chair, decor. |
| `sheet_outdoors.png` | Alley and park sets. |
| `sheet_items.png` | Food bowls, kibble, tuna, salmon, gloves. |
| `previews/<Name>.png` | One three-quarter view per asset, same name as the FBX in `assets/cat-cafe/exports/`. |
| `views/<Name>.png` | Five-view inspection sheet per asset (front, left, back, top, three-quarter), no floor; Workbench shading on a PC, Cycles CPU in a cloud container (see `assets/cat-cafe/blender/README.md`). Written by `build_all.py --render`; pairs with `assets/cat-cafe/exports/gates.md`. |
| `CatCafe_Palette.png` | The 64-swatch texture every mesh uses (style guide section 2). |

Glass and water parts render opaque or are hidden in these previews; in Studio they get Transparency per `manifest.json`. Neon tubes and bulbs are flat color here and get the Neon material plus a light in Studio.
