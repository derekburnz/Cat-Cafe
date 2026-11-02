# Store pictures, set 3 (2026-11-02)

Four 1920 x 1080 thumbnails built on Research-Agent's thumbnail study of 33 trending Roblox games (`/mnt/project-files/Research-Agent/thumbnail-study-2026-11-02.md` in the project files). What the study found and what these follow:

- One big hero, 50 to 60% of the image height, caught mid-action with an open-mouthed reaction. Derek chose a cat for the reacting hero (2026-11-02), since his rule keeps Roblox characters out of the renders.
- One big hook in the top third: a real rarity, real odds or a real income figure, in gold or rainbow gradient with a thick dark outline.
- "CAT CAFE" only on the first image; at most 2 or 3 more words.
- Warm cats on cool, flat backgrounds; a different rare cat on each image.

Made from the game's own models (the Blender generator in `assets/cat-cafe/blender`, rendered in Cycles; the leap and flight poses and the open mouth are render-only, not game models), with text and effects drawn on top. `set3-phone-size.png` shows them at 200 px wide, the size Roblox shows on phones, above set 2.

| File | What it shows | What it claims, and where that is true |
|---|---|---|
| `CatCafe_Thumb_J_MythicalCatch.png` | The Balloon Cat (Mythical, Park) mid-leap with the Master net swooping down on it, "MYTHICAL!", "!!" and the CAT CAFE title | Balloon is Mythical in Catalog; the Master net is the F93 L4 net |
| `CatCafe_Thumb_K_RainbowOdds.png` | A Rainbow Tabby pouncing toward the camera on purple, "1 IN 200" in the coat's hues and "RAINBOW CAT" | Config.RainbowChanceNet and RainbowChanceBait = 0.005, the base odds before rainbow luck |
| `CatCafe_Thumb_L_TopEarner.png` | Eclipse (Mythical, Sewer) at work with the waiter's tray, coin piles flying, "+$6,075/s" and "ONE MYTHICAL CAT" | Catalog: Mythical 75/s x Sewer area 81 = 6,075/s, the Index figure, written the way the game writes a rate (+$ and /s) |
| `CatCafe_Thumb_M_CannonFlight.png` | Blossom (Legendary) flying out of the Town Square's Cat Cannon with a dotted trail and a smoke puff, "BLAST OFF!" and "CAT CANNON" | F84 cannon flights. In the game the player rides the cannon; here the cat stands in for the player, as on the other images |

Titles sit in the top two thirds, since Roblox draws the player count over the bottom of a thumbnail in some views. Each file is under 3 MB.

Upload with the `store-media` workflow: action `home` with the paths for the homepage test (then `home-test` with the ids `list` prints), or `thumbnails` for the page gallery once the key has legacy-universe:manage.
