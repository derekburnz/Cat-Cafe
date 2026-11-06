# Cafe Pass: seasons and the paid track (#1626)

Status: specced by the game-designer thread (Design-Agent, friend's project), 2026-11-05. It builds on Monetization-Agent's `shop-and-pass-plan-2026-11-01.md` §3 and on pass XP in [quests.md](quests.md) §8. Builders: Gameplay-Engineer (season clock, track and receipt), UI-Engineer (the Pass screen and Store card, #1486), Model-Agent (the season cat and the cosmetics). Monetization-Agent checks the reward list below against `monetization-policy` before it goes on sale. This replaces golden-fish.md §6's "we never sell a paid track"; Derek asked for the pass on 2026-11-01.

## 1. Season

- **6 weeks, 30 levels, 800 pass XP a level** (24,000 for the full pass). XP comes from quests only (quests.md §8). Achievements pay none. Free and paid players earn it the same way, and levels can never be bought.
- **Season 1 starts on the day the game goes public**, and the paid tier is half price that first week (R$149, then R$299). Season start and end come from `Config.SeasonStarts` (a list of UTC dates). The server compares `os.time()` with them, and a season with no next date yet stays open until one is added.
- **The Pass screen shows the end as a plain date** ("Season 1 ends 3 January"). There is no ticking countdown, no "last chance" text and no red badge as the end nears.

## 2. Free track (everyone, every second level)

Free rewards can be random, because nobody pays for them.

| level | free reward |
|---|---|
| 2 | 1 spin |
| 4 | 15 golden fish |
| 6 | 1 Lucky Potion |
| 8 | 10 minutes of income |
| 10 | 1 Classic Crate |
| 12 | 1 spin |
| 14 | 25 golden fish |
| 16 | 1 Money Potion and 1 Swift Potion |
| 18 | 20 minutes of income |
| 20 | 1 Classic Crate |
| 22 | 2 spins |
| 24 | 40 golden fish |
| 26 | 1 Lucky Potion and 1 Steady Paw Potion |
| 28 | 30 minutes of income |
| 30 | 1 Classic Crate and 50 golden fish |

"Minutes of income" means the day rate as the HUD shows it, with no potions, paid through `Payout` like quest coins (the half-pay rule in economy-ladder.md doesn't apply, because these are already small). Spins follow the banked spin cap, and a spin over the cap becomes 10 golden fish as usual.

## 3. Paid track (every level, fixed rewards only)

**Never on this track:** crates, spins, golden fish, coins or minutes of income, Lucky Potions, or anything that changes luck, gold or rainbow chance, the pity cat or the day rolls. Every row is a named, fixed thing, and the screen shows exactly what each level gives.

| level | paid reward | level | paid reward |
|---|---|---|---|
| 1 | Season 1 chat tag "[Maple]" | 16 | Accessory: Acorn Hair Clip (Head) |
| 2 | 1 Big Money Potion | 17 | 1 Steady Paw Potion |
| 3 | Uniform colour: Pumpkin (every job) | 18 | Decor: Hay Bale Seat |
| 4 | 1 Swift Potion | 19 | 1 Big Money Potion |
| 5 | Accessory: Leaf Beret (Head) | 20 | Uniform colour: Cranberry |
| 6 | 1 Steady Paw Potion | 21 | 1 Swift Potion and 1 Steady Paw Potion |
| 7 | Decor: Pumpkin Lantern | 22 | Accessory: Round Reading Glasses (Face) |
| 8 | 1 Big Money Potion | 23 | 1 Big Money Potion |
| 9 | Uniform colour: Acorn Brown | 24 | Decor: Apple Crate Shelf |
| 10 | Accessory: Mushroom Cap (Head) | 25 | 2 Big Money Potions |
| 11 | 1 Swift Potion | 26 | Accessory: Tiny Lantern (Back) |
| 12 | Decor: Fallen Leaf Rug | 27 | 1 Steady Paw Potion and 1 Swift Potion |
| 13 | 1 Big Money Potion | 28 | Decor: Maple Tree Planter |
| 14 | Uniform colour: Forest Green | 29 | Name plate frame: Golden Leaf (cafe sign) |
| 15 | Decor: Cosy Knit Cushion | 30 | **Season cat: Maple Muffin** |

- **Potions** are the same potions the game already has (data-model.md §12b: Big Money, Swift and Steady Paw). They go into `potions` and follow PotionMaxMinutes. Steady Paw only widens the catch circles; it never changes which cat or rarity appears.
- **Accessories** follow data-model.md's prop rules: Head, Face or Back, never a neck piece. Any cat can wear one as a look. The +15% comes only from the Cat Accessories pass (economy-ladder.md §6a), so a player without that pass gets the look and no money.
- **Uniform colours** recolour every job's uniform. The +15% comes only from the Uniform Styles pass.
- **Decor** pieces are looks only. They add no `cafeMultiplier` and don't count toward the Decor Index, like exclusive cats, so paying never moves the Index. They can be placed, and they can't be traded.
- **The chat tag** shows beside the name in chat for as long as the player has it chosen. A player can pick which tag they show (VIP, a season tag or none) on the Pass screen.

### 3a. More rewards in season 1 (#1883, Derek2 2026-11-06: no season 2 for now, make season 1 more enticing)

- **Free track pays every level.** These are the odd levels added by Monetization-Agent's list on #1883: 1 fish 10, 3 coinSeconds 300, 5 tip_potion 1, 7 spins 1, 9 fish 15, 11 coinSeconds 600, 13 swift_potion 1, 15 highest-zone crate 1, 17 fish 20, 19 coinSeconds 900, 21 swift_potion 1, 23 spins 1, 25 highest-zone crate 1, 27 fish 30, 29 coinSeconds 1500. The two crates are `crates = { highest = 1 }` rather than the Classic crate, which would be a dud by then. In total it adds about 2 spins, 2 crates, 75 fish and 55 minutes of income over 6 weeks.
- **Paid track +1 potion** at levels 2, 4, 6, 8, 11, 13, 17, 19, and 3 Big Money at 25. Allowed potions only.
- **Levels 31 to 34**, so the pass is 34 levels and 27,200 XP, still 800 a level. A player who does every quest reaches 34 in about 3.8 weeks. The paid rewards are looks only, untradeable and outside the Decor Index:

  | level | paid | free |
  |---|---|---|
  | 31 | Accessory: Autumn Leaf Crown (Head) | 20 fish |
  | 32 | Decor: Maple Leaf Lamp (lamp-like, lit at night) | 1 spin |
  | 33 | Decor: Harvest Cider Cart | coinSeconds 1200 |
  | 34 | Sign style: Maple Board (walnut, carved leaves, amber name text) | 1 highest-zone crate |

  Models: `CatCafe_Accessory_LeafCrown`, `Cafe_Decor_MapleLeafLamp`, `Cafe_Decor_CiderCart`, and the Maple Board sign style (Model-Agent). Levels 31 to 34 ship only when their art exists. Until then the pass stays at 30 levels.
- Claims are kept by level, so nothing is paid twice and new levels just show as unclaimed. CafePass.spec still checks that the paid track has no crates, spins, fish, coins or luck.

## 4. The season cat: Maple Muffin

- A ginger tabby with cream paws who wears a small knitted beret with a maple leaf pin (Head prop). A few falling leaves drift around it at work (vfx-animator, mild). It's our own design, built from scratch.
- It's an exclusive cat (`exclusive = true`) at the **Legendary rate**. Like the other shop-only cats (economy-ladder.md §6), it earns like a Legendary from the player's newest area, doesn't count toward "different cats", the Index or Index milestones, and can't be traded.
- Model request for Model-Agent: `Cat_MapleMuffin_Base` with the beret as `CatCafe_Accessory_LeafBeret`, sharing the cat rig.

## 5. Buying, claiming and season end

- **Paid tier product** 3728336202 goes into `Config.ProductIds.CafePassPaid`. It's a developer product bought once per season. On the receipt the server sets `pass.paidSeason = currentSeason` in the same save write that records the receipt id, so a repeated receipt grants nothing. A receipt that arrives when `paidSeason` already equals the season returns PurchaseGranted and adds nothing.
- **Buying mid-season** unlocks every paid reward already reached at once, and the claim screen shows them all.
- **Claiming:** each reached reward has a Claim button, plus one "Claim all". The server checks the level, the track and that it's unclaimed, then pays through `Payout`. Claimed levels are kept in `pass.claimedFree` and `pass.claimedPaid` (level lists).
- **Season end:** rewards that were reached but not claimed are granted automatically on the player's next join after the end (free ones always, paid ones if `paidSeason` matched). Everything earned stays forever: cosmetics, the tag and Maple Muffin. Pass XP and levels reset to 0 for the new season.
- **Nothing is gone forever** (Derek, 2026-11-01 22:42). Season 1's items come back in a later rerun season or in the shop, and the Pass screen says "These come back in a later season" under the track.
- **Can't buy a level.** There's no Robux XP and no skip.

## 6. Contracts

- Config: `SeasonStarts`, `PassLevels` 30, `PassXpPerLevel` 800, `ProductIds.CafePassPaid` 3728336202, and `CafePassPrice` (display only; the price is set on Roblox).
- Catalog: `Catalog.passSeasons[1]` with `free` and `paid` level tables (reward shapes as in `Payout`), the accessories, uniform colours, decor and frame ids, and the Maple Muffin CatDef.
- Save (claim `DataService.luau`): `pass = { season, xp, paidSeason, claimedFree = {}, claimedPaid = {}, tag }`. Pass XP from quests.md §8 goes into `pass.xp`, and a new season resets `xp`, `claimedFree` and `claimedPaid`.
- Remotes: `PassClaim(track, level)` and `PassClaimAll()` are rate-limited and checked on the server. `PassSetTag(tagId)` only accepts a tag the player owns.
- QA:
  1. A player at level 7 who buys the paid tier gets paid levels 1 to 7 to claim.
  2. A second receipt in the same season grants nothing.
  3. A client firing `PassClaim` for an unreached level or a paid level without the tier is refused.
  4. After the season end, unclaimed reached rewards arrive on the next join and XP is 0.
  5. No paid row pays a crate, spin, fish, coins or a Lucky Potion, and a test walks the paid table to check it.
  6. Maple Muffin isn't counted by the Index.
