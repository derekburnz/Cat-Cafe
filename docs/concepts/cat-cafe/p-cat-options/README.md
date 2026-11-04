# P store picture: cat options (#1032)

Derek, 2026-11-03 03:01: "Maybe use a better designed cat for P." These renders offer three cats for picture P (the cafe picture, `docs/growth/store-art/2026-11-02-set3/CatCafe_Thumb_P_CafeNamed.png`). Each one uses the game's own models without changes.

Each option is the cat's standing work body (`CatCafe_Cat_<Name>_Work`) in the barista pose (`poses.CAT_POSES["work_barista"]`) with its takeaway cup, standing at the front left of the cafe with the room out of focus behind it. The right half stays clear for the CATCH A CAT CAFE logo and the "Catch strays. Run your cafe." line, which the store compose step adds.

| File | What |
|---|---|
| `P_cat_option_Blossom.png` | **B, the pick so far** (Tools-Agent, under Derek's blanket OK). Blossom (Legendary): rose and white patches, big blue eyes, the flower and petals and fairy wings, plus the mint barista apron. The face reads clearly at phone size, and the pink stands out on the warm cafe. |
| `P_cat_option_BellhopCat.png` | A. The free Bellhop Cat every new player gets: ginger tabby with a white blaze, chest and socks, red cap and gold bell. It ties the store page to the first cat a player meets. |
| `P_cat_option_ForestCat.png` | C. The Forest Cat (Rare): russet with a cream ruff and ear tufts, its plaid cap, plus the barista apron. Store icon option D uses the same cat. |
| `P_cat_options_sheet.png` | Today's P next to A, B and C. |
| `P_cat_options_lineup.png` | Scale check: the three options beside today's P cat (Ginger in the barista cap and apron) and two everyday sitting cats (Tabby, Tuxedo), all at game scale. The Forest Cat is a size-1.2 cat. |

Rendered in Cycles with the bpy 5.2.3 module, 1920 x 1080 at 32 samples, denoised. To rebuild them from the repo root:

```bash
.venv-bpy/bin/python docs/concepts/cat-cafe/p-cat-options/p_cat_options.py assets/cat-cafe/blender OUT --samples 32
python3 docs/concepts/cat-cafe/p-cat-options/compose_sheet.py OUT OUT docs/growth/store-art/2026-11-02-set3/CatCafe_Thumb_P_CafeNamed.png
```

Toolkit QA (`toolkit_qa.py`: blender-asset-qa roblox profile, blender-game-optimization roblox budget) on the models shown found 0 visible overlaps and 0 floating parts:

| Model | Tris | Draw calls |
|---|---|---|
| BellhopCat_Work | 2,288 | 17 |
| Blossom_Work | 1,796 | 15 |
| ForestCat_Work | 2,176 | 16 |
| Ginger_Work | 1,320 | 14 |
| Apron | 136 | 1 |
| BaristaCap | 258 | 1 |

All are within the Roblox budget.

Next, once Derek picks a cat: put it into the full P render (Tools-Agent's `render_store5.py home5 hcat=<Cat>`, then `compose5.py thumb_home5`) as `CatCafe_Thumb_P_CafeNamed_v3.png`, then upload it with store-media `home`.
