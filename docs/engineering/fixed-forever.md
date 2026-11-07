# Fixed forever: names, keys and ids that must not change after launch (#2120)

Written by Tools-Agent, 2026-11-07, from `main` at 2e08a5d. Renaming or reusing any row below after launch loses player data or breaks purchases. Studio playtests use a `_dev` suffix on the profile and trade stores so they never touch live saves.

## 1. DataStores and keys

| What | Store name | Key pattern | Where | Notes |
|---|---|---|---|---|
| Player saves | `CatCafeProfiles` (`CatCafeProfiles_dev` in Studio) | `p_<userId>` | `Config.ProfileStoreName`, `Config.ProfileKeyPrefix`, `DataService` (ProfileStore) | Save version `ProfileSchema.VERSION = 42`. Only ever raised, with a migration; never lowered. |
| Trade vault | `<store name>` plus `_dev` in Studio | `p_<userId>` | `TradeVault.luau` | Same key shape as saves. |
| Leaderboards | `CatCafe_LB_Index`, `CatCafe_LB_Playtime`, `CatCafe_LB_Money` (ordered); weekly lists add `_W<week>` | `<userId>` | `Leaderboards.STORE_NAMES` | Week number comes from `Quests.week`; changing the week origin shifts the weekly stores. |
| Leaderboard hidden list | `CatCafe_LB` | `CatCafe_LB_Hidden` | `LeaderboardService` | |
| Bug and idea reports | `BugReports_v1` | `r_<YYYYMMDD>_...` live, `s_<YYYYMMDD>_...` Studio | `BugReport.StoreName`, `BugReport.key` | Read by `bug-reports.sh` (global scope). |
| Idea credits | `IdeaCredits_v1` | `credit/<report key>`, plus a hide-prefix key | `IdeaCredits.STORE`, `CREDIT_PREFIX` | Written only by `idea-credits.yml`, never by the game. |
| ProfileStore probe | `____PS` | `____PS` | vendor library | Library internal; leave alone. |

## 2. Experience, place and Open Cloud
| What | Value | Where |
|---|---|---|
| Universe (experience) | 10773193456 | publish.yml, tools/opencloud |
| Start place | 119569792798199 | publish.yml, store-page.sh |
| Creator group (Creampuff Games) | 107520049 | upload-image.yml, upload-audio.yml |
| Owner account | 40908216 | upload workflows (old user-owned assets only) |
| Studio test account | 140223517 | asset grants |
| Pictures and sounds | all re-uploaded under the group on 2026-11-07 (276 images, 97 sounds); old user-owned ids are retired | `docs`: image-id-swap table in `/mnt/project-files/Tools-Agent/` |

## 3. Passes (Config) — ids never reused; a pass cannot be deleted
LongNap 2064345084; Money 2x 2064604577, 3x 2064670602, 4x 2064357148; ExtraSlot 2066816325; VIP 2072030274; CatAccessories 2068634239; UniformStyles 2071522382; CafeStyle 2070044168; GrandTheme 2071158673; RoyalCat 2066438426; KingPack 2071368679; KingCat 2074682301; Jukebox 2075072428 (off sale, songs free); SignStylePack 2075396351; GardenDecorPack 2075342357; GoldenPond 2071704337; SecondBowl 2072132265.

## 4. Developer products (Config.ProductIds)
potion_pack_xs 3728336174; _s 3728336184; _m 3728336191; _l 3728336197; steady_paw_pack 3728717974; thank_you_badge 3728719483; starter_bundle 3728336166; cafe_pass 3728336202. `ProcessReceipt` records each PurchaseId in the save before granting. Never reuse a product for a different item.

## 5. Badges
Five exist (welcome, firstCatch, cozyCafe, grandOpening, purrfect); 15 more are created five a day from 2026-11-08 and then filled into `Config.Badges`. A badge's id is permanent once awarded; a 0 means not made yet and is never awarded.

## 6. Analytics, funnels and messages
Funnel and event names in `Telemetry.luau` (`onboarding_v4`, `catch_attempt`, `bait_cycle`, `pity_cat`, `rally_step`, `session_10m` and the coin source/sink names) feed the dashboards; renaming one splits its history, so rename only with a new name beside the old. `Onboarding.VERSION` names the onboarding funnel. MessagingService topics: the update-restart topic used by publish.yml (`kind`: `restart`, `seconds`).

## 7. Checks done
- Nothing in code looks temporary or placeholder except: `Theme.iconSheet` (unused image, keeps an old user-owned id, harmless) and badges 6-20 at 0 (planned).
- Pass `Jukebox` stays off sale on purpose.
- All store names have the Studio suffix or key prefix that keeps Studio apart from live where it matters (profiles, trades, reports).

## 8. Derek's Creator Hub checklist (not changed by the team without asking him)
1. **Maturity & Compliance questionnaire:** done (Set 13). Re-do it only if the content changes (new random-item paid features, chat, user text).
2. **Private servers:** decide on or off; the game has no private-server code path, so off is the safe default.
3. **Max players:** 8 to match the 8 cafe plots (Configure > Experience > Places > Max players).
4. **Genre, description, icon, thumbnails, store videos:** set by Derek or by the store-page workflow on his word.
5. **Passes and products:** sale state, prices and regional pricing are changed only on his OK; everything is on sale except the Jukebox Pass.
6. **Ad account and ad targeting:** parked until the game is finished (Set 13).
7. **Experience privacy / public switch:** the game is private until Derek decides launch day.
8. **Group roles:** the group account must keep the role that can manage assets, since all pictures and sounds now belong to the group.
9. **API keys:** the repo secrets `ROBLOX_PUBLISH_KEY` (and any group key) have an expiry date; check it before launch week so publishing does not stop.
