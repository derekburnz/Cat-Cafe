# Cat Cafe Vertical Slice: Feature List and Thread Handoffs

Draft v0.1, 2026-10-25. Owner: game-designer thread. Readers: engineer (Build cat cafe rough draft), asset-artist (Create cat cafe 3D models), ui-designer (Design cat cafe UI), QA (Plan cat cafe playtests), reviewer, growth. Design reasoning is in [gdd.md](gdd.md), every number in [data-model.md](data-model.md), the UI API in [ui-contract.md](ui-contract.md).

Priorities: P0 must exist for the ten-minute loop test, P1 should ship in the slice, P2 can slip. Sizes S, M, L. The slice is done when the QA loop script in section 8 passes with no blocker tickets, data saves, and the check gate is green.

## 1. Build order for the engineer

Build in this order so there is something playable after each step and every step can be reviewed on its own branch.

1. Street, plots, areas as grayboxes with spots, anchors, spawn points, bait spots and rescue spots (F01), then the clock (F20).
2. Profile load and save with the version 1 schema, starter cat placed (F10).
3. Income accounting and ProfileSync to the UI (F04). At this point money goes up and the HUD shows it.
4. Night waves in the alley with attributes and prompts (F05).
5. Grab with server lock and chance roll, carry and check-in (F06, F07).
6. Place, unplace, sell from the cat room (F02, F03).
7. Upgrade, decor and cafe level purchases (F08).
8. Lure bowl and food (F09).
9. Rescue (F21), park, offline earnings, tutorial beats, announcements (F11 to F14).
10. Cosmetic customers, analytics, leaderboards (F15 to F17).

## 2. Features

| id | feature | P | size | owner | depends on | done when |
|---|---|---|---|---|---|---|
| F01 | Street with 8 plots, alley and park grayboxes. Plot assigned on join and freed on leave. Plot model has Spots, DecorAnchors, Door, CustomerWaypoints; areas have SpawnPoints and LureSpots | P0 | S | engineer, asset for props | | Join, own a plot, walk from cafe to alley to park and back in under 60 s |
| F02 | Spots and placement. Spots open by cafe level. PlaceCat and UnplaceCat remotes, placed cat model appears on the spot with an idle animation or bob | P0 | M | engineer | F01, F10 | Place and remove a cat, rate changes, survives rejoin |
| F03 | Cat room list in the Collection screen: owned cats with Place, Remove and Sell, silhouettes for unfound cats, 7 / 12 count | P0 | S | ui, engineer binds | F02 | Sell a duplicate and see coins rise |
| F04 | Income accounting (lazy, per data-model section 11), cafe multiplier, ProfileSync partial updates, predicted counter on the client | P0 | M | engineer | F10 | HUD rate equals the formula for any setup QA builds |
| F05 | Night waves: at each night start despawn leftovers and spawn waveSize strays per area with odds, attributes and tagged models, tutorial guaranteed Common | P0 | M | engineer | F01, F20 | Six strays appear in the alley at night start, leftovers vanish at the next night |
| F06 | Net: GrabBegin lock, swing ring via the UI catch API, GrabEnd roll, flee or retry rules, toast on fail | P0 | M | engineer, ui | F05 | Two players cannot catch the same stray; cheat client with permanent perfect gains at most 15% |
| F07 | Carry and check-in: held cat model, 80% walk speed, door zone, CatCaught popup, first-catch reward, collection entry | P1 | S | engineer, asset for held pose | F06 | Catch, walk home, cat appears in the cat room; leaving mid-carry still saves the cat |
| F08 | Shop: BuyUpgrade, BuyDecor, ToggleDecor, cafe level gates, decor anchors show and hide, tables add visible tables and chairs | P0 | M | engineer, ui | F04 | Buy every slice item in order, each visible in the world, each refused when unaffordable |
| F09 | Lure: lure_bowl upgrade, BuyLure, EquipLure, UseLure at lure spots, lured stray reserved to the placer until caught or despawn, never flees from the placer, food refunded on despawn, odds shown before buy | P1 | S | engineer, ui | F05, F08 | Tuna produces a Rare at roughly the table rate over 20 tries; a missed grab on a lured Rare lets the placer retry |
| F10 | Profile save and load with session locking, autosave, BindToClose, migration by version, starter state | P0 | M | engineer | | Rejoin after a crash of the server keeps coins and cats; reviewer signs off data safety |
| F11 | Park area with park_access gate and its own odds | P1 | S | engineer, asset | F05, F08 | Park spawns Tortie, Bengal and Ragdoll; locked gate before purchase |
| F12 | Offline earnings: rateAtLogout, 25% for up to one hour, OfflineEarnings popup and ClaimOffline | P1 | S | engineer, ui | F04, F10 | Leave for 10 minutes, return, popup shows the formula amount |
| F13 | Tutorial beats: arrow to the alley, guaranteed stray, place prompt, buy table prompt, TutorialAdvance steps, skipped on repeat joins | P1 | S | engineer, ui | F06, F08 | New account finishes the loop in under 10 minutes without help |
| F14 | Announcements for Epic and Legendary catches, Toast remote | P2 | S | engineer, ui | F07 | Everyone on the server sees the catch message |
| F15 | Cosmetic customers on the client with seats per table, coin effects via UI.floatText | P2 | S | engineer, asset | F08 | Customers fill seats, no server cost, under 2 ms per frame on a phone |
| F16 | Analytics events per data-model section 16 | P2 | S | engineer | F13 | Events appear in the Creator Hub analytics view |
| F17 | Leaderboards: tips per second and cats found, "Cafe Owner" tag at cafe level 5 | P2 | S | engineer, ui | F04 | Boards update within 60 s |
| F18 | Cat stats and Equip best (data-model section 4b): charm rolled at catch, stars on the prompt and in the cat room, levels from time placed, rating shown per cat, EquipBest remote and button that places the best cats on the open spots | P1 | M | cat stats thread, ui | F02, F03, F04 | Two Tabbies with different charm earn different rates; a cat levels after 60 s placed; Equip best on a cafe with more cats than spots matches a hand-computed best placement |
| F18 | Visiting: walk into any cafe and see its placed cats and decor | P2 | S | engineer | F02, F08 | Other players' cafes replicate placed cats |
| F19 | Fast travel: Home, Alley and Park buttons on the HUD, disabled while carrying | P2 | S | engineer, ui | F01, F07 | Tap Alley from the cafe and arrive at its entrance; button greyed while carrying |
| F20 | Clock: 3 minute day, 2 minute night, Clock attributes, lighting and street lamps, cafe sign, HUD chip with countdown, customers by day only | P0 | S | engineer, ui, asset | F01 | Night arrives two minutes after a server starts and every five minutes after; lighting and sign follow |
| F21 | Rescue: rescue spots roll at night start, stuck cat model, 4 s hold with no fail, RescueBegin and RescueEnd, rescued flag and 1.10x tips | P1 | S | engineer, ui, asset | F05, F07, F20 | Rescue a stuck cat with a 4 s hold; its tips show the bonus |

## 3. Placeholder rules for the rough draft

The engineer builds the whole loop with placeholders so nothing waits on art. Every placeholder uses the final name and attributes so swapping is a file replace, not a code change.

- Cats: a Model named `CatCafe_Cat_<Name>` with a `Body` Part 1 x 1.6 x 2.6 studs (the style guide size) in the cat's base color, a `Head` Part on top, PrimaryPart `Body`, pivot at the base. A BillboardGui with the name and rarity color is fine for the draft.
- Held cat: the same model welded to the character's upper torso. The asset thread later delivers a carried pose.
- Plot: Parts for floor, walls and counter in palette colors cream, caramel_wood and mint. Spots are invisible anchor Parts named `counter_1`, `window_1` and so on with attribute `SpotType`.
- Decor and tables: a colored Part per anchor until the asset arrives.
- Customers: default R15 rigs with shirt colors from palette row 4.
- Areas: flat ground with brick walls for the alley and green for the park. Spawn points are invisible Parts tagged `SpawnPoint` with attribute `Area`.
- Use `generate_procedural_model` in Studio MCP only for one-off set dressing; everything with a name in this doc is a Part placeholder so it can be replaced by name.

## 4. Interface contracts between threads

- Ids and names: data-model section 1. Model names: `CatCafe_<Category>_<Name>` per the style guide. Cat id to model name is `CatCafe_Cat_` plus the id in PascalCase.
- World attributes and tags: data-model section 13. The UI reads `CatId`, `CatName`, `Rarity` from the stray's ProximityPrompt; the engineer sets them when spawning.
- Catalog: data-model sections 3, 6, 7 and 8 map one to one onto `CatDef`, `UpgradeDef`, `DecorDef` and `LureDef` in ui-contract. Designer requests to the UI thread: add `odds` to `LureDef` (must be visible before purchase), add `placeCat`, `unplaceCat` and `sellCat` intents on the Collection screen, add a carry indicator and a check-in prompt, add tutorial arrow and prompt hooks, and a P2 leaderboard panel.
- Starting levels: `cafe_level` 1 and `espresso` 1 so their `costs[1]` is 0 and never offered.
- Config and Catalog modules: data-model sections 6 to 9 and 17 give every field name. Nothing numeric lives in a Service.
- Remotes: data-model section 15 is the list in `src/shared/Remotes.luau`. Reviewer checks each against the validation column.
- Asset delivery: a cat is one Model with `Body`, `Head`, `Tail` MeshParts, PrimaryPart `Body`, pivot at the base, facing -Z (Roblox's LookVector, so CFrame.lookAt needs no flip), sized per the style guide. Furniture pivots per the style guide. Each asset lands in `assets/cat-cafe/rbx/` and shows up under `ReplicatedStorage.Assets` by name; the engineer clones by name.

## 5. Asset list for the asset thread

Order is by when the engineer needs it. Placeholder stand-ins are in section 3.

| priority | asset | name | notes |
|---|---|---|---|
| 1 | Cat base rig, three pattern variants | `CatCafe_Cat_Tabby`, `CatCafe_Cat_Tuxedo`, `CatCafe_Cat_Void` | Proves the one-rig rule: stripes, patches, solid. Void gets glowing eyes (Neon) and sparkle |
| 2 | Remaining slice cats | Ginger, Smoke, Snow, Calico, Siamese, Tortie, Bengal, Sphynx, Ragdoll | Sphynx is the one shape exception (no fur silhouette, bigger ears). Ragdoll is scaled 1.2 |
| 3 | Counter with espresso machine (hero asset) | `CatCafe_Furniture_Counter`, `CatCafe_Furniture_EspressoMachine_L1`, `_L2`, `_L3` | One mesh per visible espresso level: base, chrome trim, double boiler. The engineer swaps the mesh by upgrade level |
| 4 | Spots | `CatCafe_Furniture_Cushion`, `CatCafe_Furniture_WallShelf`, `CatCafe_Furniture_CatTree`, `CatCafe_Furniture_WindowSeat`, `CatCafe_Furniture_PatioBench` | One per spot type, each with a visible sit point |
| 5 | Tables and chairs | `CatCafe_Furniture_TableRound`, `CatCafe_Furniture_Chair` | Six tables use the same pair |
| 6 | Decor | `CatCafe_Decor_WindowPlants`, `CatCafe_Decor_Rug`, `CatCafe_Decor_NeonSign`, `CatCafe_Decor_FishTank` | Neon sign uses Neon material and a point light |
| 7 | Alley set | `CatCafe_Alley_Dumpster`, `CatCafe_Alley_TrashCan`, `CatCafe_Alley_StreetLamp`, `CatCafe_Alley_Crate` | Spawn points sit beside these |
| 8 | Items | `CatCafe_Item_FoodBowl`, `CatCafe_Item_FoodBowl_Premium`, `CatCafe_Item_Net` (3 levels, was Gloves), `CatCafe_Item_Kibble`, `CatCafe_Item_TunaCan`, `CatCafe_Item_Salmon` | Food models match lure ids kibble, tuna, salmon and sit in the bowl while a lure is active |
| 8b | Rescue props | `CatCafe_Alley_StuckTree`, `CatCafe_Alley_StuckBox`, `CatCafe_Alley_Drainpipe` | A stuck cat pose per prop; the alley wall gets a Closed and Open sign |
| 9 | Park set | `CatCafe_Park_Bench`, `CatCafe_Park_Tree`, `CatCafe_Park_Fountain`, `CatCafe_Park_Gate` | Gate stays closed until park_access |
| 10 | Customers | `CatCafe_NPC_Customer_A`, `_B`, `_C` | Adult, kid, elder |
| 11 | Poses and motion | cat idle bob, cat carried pose, cat flee dash | CFrame tweens on Head and Tail per the style guide; no skeleton in the slice |
| 12 | VFX and audio | coin pop, catch sparkle, Legendary glow, purr loop, meow on catch, cafe ambience | Original or Roblox-provided audio only |

## 6. UI screens for the UI thread

ui-contract already covers HUD, Upgrades, Decor, Collection, catch prompt, toasts, cat found, offline earnings. Additions the slice needs:

| screen or element | shows | actions | P |
|---|---|---|---|
| Collection: cat room tab | owned cats grouped by catId with count, placed or resting, spot name | Place (pick a free spot from a list), Remove, Sell with confirm for Rare and above | P0 |
| Collection: book tab | all catalog cats, silhouettes with "?" for unfound, 7 / 12 count, rarity filter chips | tap for description, favorite spot, where it is found | P0 |
| Lure strip | equipped food, count, odds for each food before buying | buy, equip | P1 |
| Clock chip | sun or moon with a countdown to the next phase, Closed or Open on the cafe sign | none | P0 |
| Rescue prompt | 4 s hold bar with no ring, "Rescuing..." | hold | P1 |
| Carry indicator | small panel "Carrying Void. Walk home to check in" with an arrow to the door | none | P1 |
| Tutorial prompts | arrow in the world and one-line prompt per step | dismiss on completion only | P1 |
| Leaderboards | two boards, top 10, own rank | none | P2 |
| Settings | music, sfx toggles | toggle | P2 |

## 7. Reviewer focus

In order: GrabBegin and GrabEnd (lock, distance, cooldown, ring bonus cap), SellCat and PlaceCat ownership checks, every purchase's affordability and gate check, profile session locking and migration, remote rate limits, no client-trusted time.

## 8. QA loop script (Phase 2 exit test)

Fresh account, phone-sized viewport, 10 minute limit.

1. Join. Plot assigned, Tabby on the counter, HUD shows $50 and a positive rate within 5 s.
2. Follow the arrow to the alley. A Common stray is there even by day. Hold to wind up the net, release in the band. Catch succeeds (retry is allowed for Commons). Night arrives by minute two with a full wave.
3. Walk home at carry speed, check in at the door. Cat found popup, collection goes to 2 / 12.
4. Place the new cat on window_1. Rate rises.
5. Buy Table 1 at $100. A table appears, rate rises by 10%.
6. Free play until minute 10. Expected: cafe level 2 bought, three cats placed, at least one more purchase.
7. Leave for 5 minutes, rejoin. Offline popup shows about 25% of the rate times 300 s. Coins and cats match before leaving.
8. Pass criteria: all steps complete under 10 minutes, no console errors, no blocker tickets from the reviewer.

## 9. Post-slice backlog

Scheduled by phase in [common-features.md](common-features.md). Unscheduled: Secret cats at night and in rain, Golden and Galaxy variants, merging three duplicates, Woods, Rooftops and Harbor, naming cats with text filtering, free decor placement, customer demand model, daily special customer, seasonal cats, prestige (Renovate), opt-in carry raids, trading, game passes and a cash product gated by PolicyService, friends list features.
