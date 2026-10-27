# Cat Cafe concept images

All images here are rendered from the generated Blender assets in `assets/cat-cafe/blender/` (Cozy Cream style, decided 2026-10-25). Re-run `build_all.py --render --scenes` to refresh them. The `ui/` folder belongs to the UI thread.

| file | caption |
|---|---|
| `vignette_cafe.png` | Cafe interior at cafe level 3: counter with the level 2 espresso machine, Tabby on the counter spot, Tuxedo on the window seat, Void on the wall shelf, Siamese on the cat tree, Calico on the cushion, two tables, fish tank, neon sign, three customers. Lamps are warm point lights. |
| `vignette_alley.png` | The alley behind the cafe at dusk: dumpster with Smoke on the lid, trash cans, crates and boxes beside the spawn points, the wheelie bin and garbage bag rescue traps (empty by day), premium bowl with a tuna lure and Void approaching it, one street lamp doing the lighting. |
| `vignette_alley_night.png` | The same alley at night: street lamp, glowing shop window, string lights and the Closed sign switched to Neon, the two Alleyway rescue traps (wheelie bin and garbage bags) each with a stuck Ginger. Target look for the night lighting preset in the style guide. |
| `sheet_poses.png` | Tabby wearing the accessory set (glasses, hat, bow tie, apron), the upright pose test with the same parts, the four role outfits on upright cats (apron and barista cap, bow tie and vest, sash and boater, party hat and cape), the carried pose against an R15-sized stand-in, the four v0.3 rescue traps with their stuck cat (Alleyway trash bin and garbage bags, Park rescue tree and trash can), and a gold Tabby with the ShinySparkle sprite at the suggested sizes. |
| `sheet_cats.png` | The 20 slice cats from one rig, each with its own coat, eyes and nose (style guide section 2, Cat coats), in roster order: Tabby, Tuxedo, Ginger, Smoke, Snow, Calico, Siamese, Tortie, Bengal, Sphynx, Ragdoll, Void, Maine Coon, Midnight, Cream, Brownie, Blue, Persian, Blossom, Aurora. No collars: a working cat wears its role outfit instead (`sheet_poses.png`). Midnight and Aurora are the Mythical heroes. |
| `sheet_gold.png` | Each cat beside its gold version (F42, called shiny until 2026-10-27), four pairs to a row in roster order. The golds are metal in Studio. |
| `sheet_cafe.png` | Customers (with the rich customer and the night dealer), counter, espresso machine levels 1 to 3, the cat spots and role stations (greeter podium, stage cat tree), table and chair, decor. |
| `sheet_outdoors.png` | Alley and park sets: the rescue traps, the shop window, the dealer cart, the Alleyway kit (arches, building backs with windows, a staff door, a fire escape and the cat mural, crate stack, laundry line, long string lights, sewer manhole) and the four area gates with their see-through barriers. |
| `sheet_items.png` | Food bowls, kibble, tuna, salmon, the dealer foods (sardines, caviar, moon milk, star treat), the net at levels 1 to 3 (bag hung from the hoop), the tip pile and the accessories. |
| `sheet_plot.png` | Cafe plot pieces (world-and-feel.md sections 3 to 5): the shell in Mint, Blush, Butter and Lilac, the interior dressing, the For Rent dressing for empty plots, the tier sets 1 to 5 seen from the street and the night Closed sign (F44). |
| `previews/<Name>.png` | One three-quarter view per asset, same name as the FBX in `assets/cat-cafe/exports/`. |
| `views/<Name>.png` | Five-view inspection sheet per asset (front, left, back, top, three-quarter), no floor; Workbench shading on a PC, Cycles CPU in a cloud container (see `assets/cat-cafe/blender/README.md`). Written by `build_all.py --render`; pairs with `assets/cat-cafe/exports/gates.md`. |
| `rbx/<Name>.png` | The Part-built model from `assets/cat-cafe/rbx/` drawn with Roblox's own shapes by `rbx_preview.py`, which is what Studio shows without any mesh upload. |
| `rbx/alley_row.png` | A back alley as Parts, shortened to fit the frame: the staff door, fire escape (with the crate stack to climb it) and cat mural building backs on the left, a Mint cafe on the right with its back to the alley, long string lights, a laundry line, a dumpster, a trash bin, puddles and the arch into the Alley Square at the far end. |
| `rbx/cafe_closed.png` | A Mint cafe at night as Parts with `CatCafe_Plot_ClosedSign` hung in its front door (F44): CLOSED, two stars and a crescent moon that glows at night. |
| `rbx/street_row.png` | Three plots side by side as Parts, left to right: a Butter cafe at tier 5, a Blush plot For Rent and a Mint cafe at tier 3. |
| `CatCafe_Palette.png` | The 64-swatch texture every mesh uses (style guide section 2). |

Glass and water parts render opaque or are hidden in these previews; in Studio they get Transparency per `manifest.json`. Neon tubes and bulbs are flat color here and get the Neon material plus a light in Studio.
