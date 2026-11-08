# Ad thumbnails, week-one test (2026-11-08, #2422)

These are the 10 pictures for the first Ads Manager campaign in `docs/growth/ad-campaign-plan-2026-11-08.md`. Derek2 asked for them on 2026-11-08: "Continue with working on the 10 ads". Each one is 1920 x 1080 (16:9, the Ads Manager thumbnail shape) and under 2 MB. They all go into one Plays campaign, and the day 2 and day 3 rules in the plan cut them down to the best 2 or 3. Each picture gives a different reason to play. Nothing paid is shown, and every claim in them was checked against the code on 2026-11-08.

| File | Hook | Made from | Claim, and where it is true |
|---|---|---|---|
| `Ad_01_CatsAtWork.png` | Cats serving customers. Derek2 asked for this one: "cats carrying to customers or making food". | Set 2 G, with CATCH A added above the old CAT CAFE title, plus two labels with arrows ("Barista cat makes it", "Waiter cat brings the cake!"), because the tray read as food on the cat's head (Derek2, 2026-11-08) | F90: the Barista and Waiter cats serve orders |
| `Ad_02_BellhopCafe.png` | Cute cat and the brand | Set 3 P v3, unchanged | The Bellhop Cat is the free starter cat (F96) |
| `Ad_03_MythicalCatch.png` | Catch moment | Set 3 N v2, unchanged | The Balloon Cat is Mythical in Catalog, and the player swings the net |
| `Ad_04_TopEarner.png` | Income | Set 3 L v2, unchanged | Mythical 75/s x Sewer 81 = 6,075/s (Catalog `AREA_INCOME`) |
| `Ad_05_DecorateCafe.png` | Decorating your cafe (Derek2 2026-11-08: "show cute decor and customizing cafe") | New: 8 decor pieces from the preview renders (jukebox, duck fountain, blossom tree, bathtub sofa, cat tree tower, ice cream counter, mushroom lamp, porch swing) | All are decor pieces in Catalog (crate decor, earned in play) |
| `Ad_06_EarnOffline.png` | Earn while offline (Derek2, 2026-11-08: "can also use earn offline for ads") | New: night sky with the Sleepy Cat (Ragdoll) in its nightcap | `Config.OfflineRate = 0.5` for up to 8 hours, free for everyone (the pass raises it, but the picture doesn't mention the pass) |
| `Ad_07_RescueCats.png` | Rescuing stuck cats. This is a placeholder until the rainbow Mythical render ("1 IN 5,000+") arrives, then that picture replaces it (Derek2, 2026-11-08). | New: the Park rescue tree with its stuck cat | RescueService; `Config.GoldChanceRescue = 0.12`, so some rescued cats turn out gold |
| `Ad_08_RainbowCats.png` | Rainbow cats | Set 2 F, with CATCH A added and the pill changed from x3 to **x2** | `Config.RainbowMultiplier = 2` (Derek2, 2026-11-07) |
| `Ad_09_FiftyCats.png` | Collection | New: 12 cat cards from the preview renders, with rarity borders in the game's rarity colours | 50 catchable cats in Catalog; each card's rarity matches Catalog |
| `Ad_10_GoldenCats.png` | Gold cats | New: Blossom next to its gold twin | Any stray can roll gold (`GoldChanceNet` / `GoldChanceBait`), and a gold cat earns `GoldMultiplier = 1.5` |

Left out:

- Set 3 K ("1 IN 200"): a rainbow cat is now 1 in 67 (`RainbowChanceNet = 0.015`), so 200 overstates how rare it is. A rainbow Mythical really is about 1 in 5,500 per stray (1.2% Mythical in every area's odds x 1.5% rainbow). "1 IN 5,000+" would be a true and stronger hook, but it needs a new render of a rainbow Mythical.
- The cannon (set 2 H, set 3 M and O v2) and the Lucky Cat (set 2 I): Derek2 swapped them out on 2026-11-08.
- J and N v1: they repeat the catch hook.

The plan also listed "friends" and "cozy night" scenes. They need new Blender renders, which this session could not make, so they are a follow-up.

`ads-overview.png` shows all ten together, and `ads-phone-size.png` shows them at 200 px wide (phone size). The new pictures and the logo edits were made with `compose_new_ads.py` and `adtext.py`, using Pillow and the Fredoka font (Google Fonts, OFL; the game UI's font).

Nothing here is uploaded. Derek2 adds the pictures to the campaign in Ads Manager.
