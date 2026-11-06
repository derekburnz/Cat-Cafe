# Analytics events and funnel read-out (2026-11-06, #1888)
Owner: growth-analyst (Monetization-Agent). Source: PR #1894 (Gameplay-Engineer). Owner test mode players and Studio are left out of every event.

## Events
| Event | Fields | Read it for |
|---|---|---|
| session_start | join source (ad, organic or "unknown"), new or returning, tier | Split every funnel by ad vs organic. |
| onboarding_v4 | v3's 37 steps, then first_store_open, first_pass_xp, first_pass_claim, first_camp_collect, first_equip_best, pass_level_5, tier_4, first_robux_purchase | Where new players drop; D1/D7 by step reached. |
| store funnel "store" | steps opened, tab_viewed, buy_pressed, completed; store_cancelled; sku | Store conversion; prompt shown but not completed = store_cancelled. |
| robux_purchase | value = Robux, sku (pass_&lt;name&gt; or product_&lt;id&gt;), day since first join, first or repeat | Revenue by item and by day; time to first purchase. |
| cafe_pass_level | every 5 levels | Whether the extra free rewards lift engagement. |
| cafe_pass_bought | day of the season | When in the season players buy. |
| jukebox_pick | track | Whether free music gets used. |
| pity_cat | outcome "spawned" | Pity cat reach. |
| lucky_day | the day's kinds | Lucky/Golden/Rainbow day joins. |

## Read-outs to build once data flows
1. Store funnel by ad vs organic: opened > tab_viewed > buy_pressed > completed, per sku.
2. Day 1 and day 7 retention for players who bought anything by day 1 vs those who did not.
3. Time from join to first_robux_purchase; first vs repeat purchase mix.
4. Cafe Pass: share reaching level 5, 15, 30; share buying the paid track and on which season day.
5. King Cat bundle vs King Cat alone (pass_king_*): buys per 100 store opens.

## Guardrails (monetization-policy)
- No user text and no ids beyond what Roblox analytics already carries.
- No hidden price tests without Derek2's OK.
- A missing join source is logged as "unknown", never guessed.
