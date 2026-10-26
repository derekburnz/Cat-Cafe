# Purr Pot monetization plan

Owner: growth-analyst. Written 2026-10-25, aligned the same day with gdd.md (Monetization section), data-model.md section 8 (lure catalog and odds) and the designer's note that lure food must be modelled as a paid random item rather than designed around. Follows the monetization-policy skill and the project rules on young audiences. Numbers cite sources in comps.md; re-verify Roblox rates before any payout math is quoted externally.

## 1. Principles

1. Convenience and cosmetics only. Nothing that affects gameplay is Robux-exclusive. Spots, areas, gloves and cafe levels stay coin-only because they are the economy's sinks; selling them for Robux would hollow out the loop.
2. Nothing paid in the slice (gdd). Passes arrive at soft launch. A cash developer product is modelled in section 7 and recommended against for soft launch (section 3).
3. No Robux path to a random cat (gdd). The one indirect path is cash for Robux, then coins for lure food, then a random-rarity stray. Section 7 is the full compliance model for that case.
4. No pressure tactics. No countdown timers on purchases, no "miss out forever", no streak resets, no spending leaderboards, no grayed-out decline buttons, no inverse bundle pricing. These are the patterns named by the Penn State SOUPS 2025 study and the May 2026 FTC complaint (comps.md section 5).
5. One currency players earn (coins, shown as $). No second, Robux-only currency.
6. No trading (decisions.md), so IsPaidItemTradingAllowed is a cached check with nothing behind it.
7. Prices at common market points: R$49, R$99, R$149, R$199, R$249. Statroblox (data to 2026-10-24): median pass R$180, most common R$99, Simulation genre typical R$150, 7 passes per game.

## 2. Money reality (verify before quoting)

| Fact | Value | Source |
|---|---|---|
| Creator share on passes and developer products | 70% (30% marketplace fee) | Studio Insights, checked 2026-09-16 |
| DevEx rate | $0.0038 per earned Robux; 30,000 earned Robux minimum ($114) | Roblox DevEx help page via Studio Insights |
| Gross sales to reach the first payout | about R$42,860 (30,000 divided by 0.70) | derived |
| Pass sales to get there | about 290 at R$149, or 215 at R$199, or 172 at R$249 | derived |
| Creator Rewards, daily engagement | 5 Robux per active spender who plays at least 10 minutes in a day, and only if Purr Pot is one of the first three experiences they launch that day. Active spender means at least $9.99 of qualifying Roblox purchases in the past 60 days. | DevForum Creator Rewards launch, 2025-07-24; Studio Insights |
| Creator Rewards, audience expansion | 35% of the first $100 of Robux purchases by new or 60-day-lapsed users for two months after they arrive via the game's details page link or a name search and play 10 minutes or more. Requires an ID-verified account in good standing and a DevEx account. | same |
| Payer conversion | 1.4% of DAU paid in Q1 2026 (Roblox, via Fortune 2026-05-20); 3.8% of tracked players over a year in the GameAnalytics sample | comps.md section 2 |
| Median revenue per paying user per game | $0.70 | GameAnalytics 2026 |

What this means: at Care For Cats scale (a few thousand peak concurrent, tens of millions of visits in a year) a hobby game can reach DevEx payouts. At friends-alpha scale it earns nothing, which is fine; revenue is a bonus signal per the plan. Design for retention first, then let Creator Rewards and a small honest shop do their work.

## 3. Soft launch set

The designer's three candidates, one cosmetic addition, one optional multiplier for the designer to accept or reject, no developer product. Five passes, R$745 total (R$944 with the optional pass). Compare: Roll a Fisherman launched with six passes totalling R$1,014 (checked 2026-10-09); Care For Cats runs nine from R$79 to R$749.

| SKU (catalog id) | Name in shop | Price | What it does | Why it is fair |
|---|---|---|---|---|
| pass_long_nap | Long Nap | R$99 | Offline earnings cap from 1 hour to 2 hours, still at 25% of the logout rate (gdd economy) | Convenience. Free players keep the full base cap. Rolls into the offline_claim analytics so we can see if the cap matters. |
| pass_cat_room_2 | Second Cat Room | R$149 | A second cat room page: more unplaced cats stored | Storage, not income. Cats in the room earn nothing, so this is a collector's convenience. Market median for slot and storage passes is R$149. |
| pass_vip | VIP Decor Set | R$249 | VIP decor set (fixed-position decor pieces with a 0% tip bonus), a VIP chat tag and a golden tip jar on the counter | Pure cosmetics. Market median for VIP passes is R$249. If the designer wants the set to carry a tip bonus, cap it at what one coin decor item gives. |
| pass_cat_fits | Cat Accessories | R$149 | Bandanas, bows, tiny hats and collars equippable on any owned cat | Cosmetics on the thing players love most. Kitten Game and Care For Cats both sell cat looks. Reuses the one-rig accessory slot already in the cat plan. |
| pass_2x_tips (optional, designer's call) | 2x Tips | R$199 | Doubles tips from placed cats | The standard tycoon pass (median R$180 for 2x passes). It compresses time without gating anything, but it does bend the tuned economy. Recommend holding it until the economy has two weeks of soft-launch data, then adding it only if wallets are not already climbing. |

Not in the set, and why:
- Extra spots or cafe levels for Robux: spots are the main coin sink (gdd). Selling them would remove the reason to earn.
- Gloves or catch chance for Robux: pay-to-win on the core skill mechanic.
- Cash developer product: see section 7. Recommended for Phase 5 at the earliest, and only with the full compliance list in place.

Private servers: free. Friends playing together is goal three of the project, and a free private server is the cheapest way to let a parent host a kid's friends.

Description line on every pass: "Everything in Purr Pot can be earned by playing. Passes add looks and convenience."

## 4. Later options

| Option | When | Rules |
|---|---|---|
| Seasonal cosmetic sets (Autumn Leaves decor, Winter Scarves for cats) | After soft launch, one per season | Rotate in and out, but always return next year and say so. No "last chance" copy. R$99 each. |
| Direct-sale variant cat | After Golden and Rainbow variants exist | A specific named variant at a fixed price (R$199 to R$299), never random. This is Roll a Fisherman's compliant pattern: 14 fishermen sold directly beside the spins. Its tip rate must equal an earnable cat of the same rarity so it is a look, not power. |
| Cash developer product | Phase 5, if shop_checkout shows a high `affordable=no` rate and wallets are flat | Section 7 in full. Linear pricing (same coins per Robux at every size; a bigger pack may add a stated bonus, never a worse rate). No "best value" badge. Consider a per-day purchase cap per player. |
| Subscription "Purr Pot Club" | Phase 5, if a monthly cosmetic set is sustainable | Robux price from R$49 or local currency from $2.99. Monthly cosmetic set plus a small daily treat. Benefits must be distinct from passes, identical on every platform, honored for the full term. Creator gets 70% of Robux subscriptions monthly; local-currency ones pay 70% month one and 100% after. Local currency needs ID or phone verification and is unavailable in some countries. |
| Regional pricing | On by default for passes; leave it on | Roblox adjusts by region, never above the default and never below 30% of it. Developer product prices must be read with MarketplaceService at runtime and GetUsersPriceLevelsAsync used; no hard-coded prices. |
| Price optimization | Not for us | Needs about 60,000 transactions in 30 days. |

## 5. Do not build (and the complaint or rule each one maps to)

| Item | Why not |
|---|---|
| Paid eggs, crates, spins, Robux-bought food | Paid random item rules (odds UI, live luck odds, PolicyService alternatives); gacha scrutiny with a child audience; and the gdd's "no Robux path to a random cat" |
| Luck boosts for Robux (better food odds, better grab odds) | Probability modifier items fall under the same rules; "pay for better odds" is the casino complaint in Andy Hall's analysis |
| Robux-only power (spots, gloves, cafe levels, areas) | Steal a Brainrot's pay-to-win reviews; hollows out the coin economy |
| Admin commands or "server owner" powers for sale | Steal a Brainrot criticism; griefing vector |
| Steal protection, locks or shields for Robux | There is no stealing to protect against; monetizing defence against other children is the worst-reviewed pattern |
| Trading of any paid item | Scam vector (Adopt Me); IsPaidItemTradingAllowed gating |
| Limited-quantity items, countdown purchase timers, streak resets | FTC complaint scarcity marketing; Kinzoo parent complaints |
| Top spender or donation leaderboards, donation passes | SOUPS 2025 social pressure; Koala Cafe's R$10,000 "donation" pass is the anti-pattern |
| Rewards for watching media feeds | Banned for Kids and Select audiences since 2026-08-25 |
| A second, Robux-bought currency | Layered currency obscures cost (FTC complaint); needless for a five-pass shop |
| Licensed characters as passes | IP takedown risk (Cat game's Sanrio passes; Steal a Brainrot's character dispute) |

## 6. Shop UI rules (for ui-designer)

- Price in Robux on the card before the Roblox purchase prompt, with the free alternative in one line under every non-cosmetic pass ("Or keep earning: the base cap is one hour").
- Decline and buy buttons the same size and contrast. No grayed-out "No thanks".
- No timers anywhere in the shop. Seasonal sets show "Back every autumn".
- Cosmetics tab first, convenience second. Owned passes show "Owned" and hide the price.
- Food cards show the odds table before purchase from day one (data-model section 8), opened by a control labelled "Odds" or "Details", never a bare (i) icon. See section 7 for what the table must contain once cash is sold.
- PolicyService:GetPolicyInfoForPlayerAsync is called once per player on join and cached by the server; the shop reads the cached flags when it builds the panel.
- Never show another player's spending or inventory as a purchase prompt.
- Fire the robux_purchase funnel (analytics-plan.md 4.3) from the server on prompt and completion.

## 7. The lure food case, modelled

The chain: Robux buys a cash pack, cash is coins, coins buy Kibble, Tuna or Salmon, food spawns a stray whose rarity is rolled from the food's odds table (data-model section 8), the player then has to catch it. Under the 2026-05-26 clarification, "a random item bought with in-game currency bought with Robux" is a paid random item, so the moment a cash product exists every food item is one, for every player who could have bought cash. Without a cash product, food bought with earned coins is exempt (the policy's own example: a key found in gameplay opening a chest needs no odds).

### 7.1 Option A (recommended for soft launch): no cash product

- Food stays exempt. The odds UI and the cached PolicyService flags ship anyway, so switching to option B later is a configuration change plus the list below, not a redesign.
- The BuyLure gate in data-model section 15 is a no-op that logs the flag; it must not block anyone.

### 7.2 Option B: cash product ships. Everything below is then mandatory

Disclosure (every player):
1. The odds control on each food is labelled "Odds" or "Details". Odds are percentages summing to exactly 100%. The current table (Kibble 70 / 26 / 3.5 / 0.5, Tuna 45 / 42 / 11 / 2, Salmon 15 / 50 / 28 / 7) already sums correctly.
2. Every possible outcome must be listed, and the outcome is a specific cat, not a rarity. Either list each cat with its odds (Kibble: Tabby 14%, Tuxedo 14%, Ginger 14%, Smoke 14%, Snow 14%, then the four Rares at 6.5% each, and so on), or state "equal odds within each rarity" beside the rarity table with the per-cat figure shown. If the park and the alley use different cat pools for lures, the table is per area and says so.
3. Any modifier that changes the roll (a future luck decor, a Golden variant chance, a night-only cat) must show its numeric effect before purchase and the displayed odds must update while it is active. The design has none today; keep it that way or budget for the UI.
4. The purchased outcome must actually be delivered. Two gdd rules break this: Rare and above flee on a missed grab, and the lured stray is reserved only 30 seconds. A paid outcome that can be lost to a missed ring or to another player is an outcome with no benefit. Fix for option B: a lured stray does not flee from the player who lured it and stays reserved to them until caught or until its two-minute despawn, and on despawn the food is refunded. Alternatively the lured stray goes straight to the cat room. Pick one in the design before any cash product ships.
5. Duplicates are still an outcome with benefit (they sell for 25 to 3,000), so a duplicate result is fine.

Restricted players (ArePaidRandomItemsRestricted true):
6. Gate the cash product, not the lure. The server never prompts the cash product for a restricted player and the shop hides it. Their coins are then all earned, which is the policy's treatment "offer an unpaid, earnable path to the item", and BuyLure stays open to them. Blocking BuyLure instead would remove a core mechanic for whole regions.
7. If a receipt for a restricted player ever arrives anyway (exploit or a flag that changed mid-session), grant the coins (never take Robux without delivering) and log `error_recovered` with system `policy`; do not build a two-pool wallet.
8. Trading is off, so IsPaidItemTradingAllowed changes nothing. Keep the cached value for the day a gifting feature appears.

Pricing and safety:
9. Linear pricing across pack sizes, a stated bonus on the largest at most, and no "best value" badge. Consider a cap of three packs per player per day, surfaced as "That's enough for today, come back tomorrow" rather than a hidden refusal.
10. Cash packs show the coin amount and the Robux price on one card; no intermediate token.

Compliance paperwork:
11. Answer yes to paid random items on the content maturity questionnaire and describe the PolicyService handling; the Minimal label is still reachable.
12. Test both flags with the Studio Player Emulator before publishing.

Analytics:
13. `lure_used` (analytics-plan.md section 6) records food id and rolled rarity so shown odds can be audited against results; the Phase 5 target is results within 2 points of the table.
14. The cash pack logs an IAP economy source with the pack SKU; food logs a Shop sink; the robux_purchase funnel carries `restricted`.

Cost estimate for option B on top of option A: S for the product gating and refund rule, S for the per-cat odds table, M if the lured-stray reservation and flee rules change (touches Catching and UI). The designer owns the choice in point 4.

## 8. Creator Rewards fit

- Sessions over 10 minutes: the gdd's session loop (catch two to four cats, buy one or two upgrades) is 10 to 15 minutes, and the offline claim gives a reason to return without a streak.
- First three experiences of the day: the overnight earnings waiting at the door are the daily hook. Do not add login-streak penalties.
- Audience expansion credits arrive through the details page link and name search, so the final title must be the searchable name and friends share the details-page link, not a server link.
- Derek needs an ID-verified account and a DevEx account before soft launch for the audience expansion share to count. Both are free.

## 9. Soft launch checklist

- [ ] Passes created with the catalog ids above, descriptions carry the "everything can be earned" line, regional pricing left on.
- [ ] Private servers set to free.
- [ ] Content maturity questionnaire answered: Minimal target; paid random items "no" under option A, "yes" with the handling described under option B.
- [ ] PolicyService call and cache in place; BuyLure gate is a no-op under option A.
- [ ] Food odds control labelled "Odds" or "Details" and shows the table (option A: rarity table is enough; option B: per-cat).
- [ ] robux_purchase funnel and IAP economy events verified in View Events.
- [ ] docs/decisions.md entry recorded.

Proposed for docs/decisions.md: 2026-10-25, Purr Pot soft-launches with four cosmetic and convenience passes (Long Nap, Second Cat Room, VIP Decor Set, Cat Accessories; 2x Tips optional and deferred), free private servers and no cash product, keeping lure food exempt from the paid random item rules; a cash product is a Phase 5 decision that triggers the section 7 option B list, in particular guaranteed delivery of lured strays and gating the cash product rather than BuyLure for restricted players.
