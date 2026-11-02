# Store pictures, set 2 (2026-11-02)

Four 1920 x 1080 thumbnails for the game's page, one per feature added since the first set (2026-10-28): rainbow coats (F99), cats serving orders (F90), the Cat Cannon (F84) and the Lucky Cat statue (F88). Made from the game's own models (the Blender generator in `assets/cat-cafe/blender`, rendered in Cycles), with titles, glows and effects drawn on top. No Roblox characters appear in them.

| File | What it shows | What it claims |
|---|---|---|
| `CatCafe_Thumb_F_RainbowCats.png` | A Rainbow Tabby on a crate in the coat's six hues with its glow and band-coloured outline, a Gold Tabby and a Ginger beside it, "RAINBOW CATS!" and "EARN x3 MONEY" | Config.RainbowMultiplier = 3 |
| `CatCafe_Thumb_G_CatsServe.png` | The Barista in its apron and cap at the espresso machine, a waiter cat trotting a Rainbow Cake on its tray to a seated customer, "Your cats take the orders!" | F90 Barista and Waiter tray |
| `CatCafe_Thumb_H_CatCannon.png` | The Town Square's Cat Cannon from below, a puff at the mouth, the brass cat statue and two cats on the deck, "BLAST OFF!" and "Fly the Cat Cannon!" | F84 cannon flights (the player rides hidden in the barrel, so none is drawn) |
| `CatCafe_Thumb_I_LuckyCat.png` | The gold Lucky Cat statue waving, the Nerd Cat and the Pirate Cat beside it with coins, "LUCKY CAT!" and "More rare cats" | F88 luck on bait and crates |

Titles sit in the top two thirds, since Roblox draws the player count over the bottom of a thumbnail in some views. Each file is under 3 MB.

Upload with the `store-media` workflow: action `thumbnails`, args the paths, and `branch` if they are not on main yet.
