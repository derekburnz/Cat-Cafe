# Analytics events and funnel read-out (2026-11-06, #1888)
Owner: growth-analyst (Monetization-Agent). Source: PR #1894 (Gameplay-Engineer). Owner test mode players and Studio are left out of every event.

## Events
| Event | Fields | Read it for |
|---|---|---|
| session_start | join source (ad, organic or "unknown"), new or returning, tier | Split every funnel by ad vs organic. |
| onboarding_v4 | v3's 37 steps, then first_store_open, first_pass_xp, first_pass_claim, first_camp_collect, first_equip_best, pass_level_5, tier_4, first_robux_purchase | Where new players drop; D1/D7 by step reached. |
| store funnel "store_v1" (since v482, 2026-11-10 03:35 UTC; was "store") | steps opened, tab_viewed (not the tab the Store opens on), buy_pressed, prompt_closed (bought or cancelled), completed; store_cancelled; sku | Store conversion (#2914). buy_pressed to prompt_closed shows refused prompts; prompt_closed to completed shows cancels. Steps come from StoreFunnel.luau. |
| robux_purchase | value = Robux, sku (`pass_<name>` or `product_<id>`), day since first join, first or repeat | Revenue by item and by day; time to first purchase. |
| grant_failed | value 1; product id, the grant step that threw, and "retry" (nothing paid, the id is dropped so Roblox redelivers) or "kept" (part paid) | A paid prize that did not fully land (#2127, #2158). Should stay at 0; any "kept" row is a player owed something. |
| cafe_pass_level | every 5 levels | Whether the extra free rewards lift engagement. |
| cafe_pass_bought | day of the season | When in the season players buy. |
| jukebox_pick | track | Whether free music gets used. |
| pity_cat | outcome "spawned" | Pity cat reach. |
| lucky_day | the day's kinds | Lucky/Golden/Rainbow day joins. |

## Read-outs to build once data flows
1. Store funnel (store_v1) by ad vs organic: opened > tab_viewed > buy_pressed > prompt_closed > completed, per sku.
2. Day 1 and day 7 retention for players who bought anything by day 1 vs those who did not.
3. Time from join to first_robux_purchase; first vs repeat purchase mix.
4. Cafe Pass: share reaching level 5, 15, 30; share buying the paid track and on which season day.
5. King Cat bundle vs King Cat alone (pass_king_*): buys per 100 store opens.
6. grant_failed: check daily in the first launch week. Any "kept" row: find the product and step, fix the code, and make the player whole by hand. Many "retry" rows on one step mean that step is broken.

## Guardrails (monetization-policy)
- No user text and no ids beyond what Roblox analytics already carries.
- No hidden price tests without Derek2's OK.
- A missing join source is logged as "unknown", never guessed.
