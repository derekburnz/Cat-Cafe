# Purr Pot monetization plan

Owner: growth-analyst. v0.3, 2026-10-26: re-checked against design v0.3 (bait bowl with Tame or Let go, night food dealer, shinies, charm, tiers, roles, carry bumps, no cat room cap). v0.1 was written 2026-10-25 on design v0.2. Follows the monetization-policy skill and the project rules on young audiences. Numbers cite sources in comps.md; re-verify Roblox rates before any payout math is quoted externally.

## 1. Principles

1. Convenience and cosmetics only. Nothing that affects gameplay is Robux-exclusive. Role slots, tiers, areas, the net and the bait bowl stay coin-only because they are the economy's sinks and the core skill.
2. Nothing paid in the slice (gdd). Passes arrive at soft launch. A coins developer product is modelled in section 7 and recommended against for soft launch.
3. No Robux path to a random cat (gdd). The only indirect path would be coins sold for Robux, then coins for food (shop or dealer), then a random cat at the bowl. Section 7 models that case.
4. No pressure tactics. No countdown timers on purchases, no "miss out forever", no streak resets, no spending leaderboards, no grayed-out decline buttons, no inverse bundle pricing. These are the patterns named by the Penn State SOUPS 2025 study and the May 2026 FTC complaint (comps.md section 5).
5. One currency players earn (coins, shown as $). No second, Robux-only currency.
6. No trading (decisions.md). Bumps are not trading, but they are the first way a player can lose a cat to another player, so nothing paid may touch them (section 5).
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

Four passes, R$646 total, plus one optional multiplier the designer holds until there is data. No developer products. Compare: Roll a Fisherman launched with six passes totalling R$1,014 (checked 2026-10-09); Care For Cats runs nine from R$79 to R$749.

| SKU (catalog id) | Name in shop | Price | What it does | Why it is fair |
|---|---|---|---|---|
| pass_long_nap | Long Nap | R$99 | Offline earnings cap from 1 hour to 2 hours, still at 25% of the day rate | Convenience. Free players keep the full base cap. The offline_claim event shows how often the cap is reached. |
| pass_vip | VIP Decor Set | R$249 | A VIP decor set with no tip bonus, a VIP chat tag and a golden tip jar on the counter | Pure cosmetics. Market median for VIP passes is R$249. If the set must carry a bonus, cap it at what one coin decor item gives. |
| pass_cat_fits | Cat Accessories | R$149 | Bandanas, bows, tiny hats and collars for any owned cat | Cosmetics on the thing players love most; uses the rig's accessory slots. Kitten Game and Care For Cats both sell cat looks. |
| pass_uniforms | Uniform Styles | R$149 | Alternate colors and patterns for the four role uniforms (apron, bow tie, sash, party hat) | New in v0.3, replaces Second Cat Room. Cosmetic on the most visible v0.3 feature. Asset-artist to confirm uniforms and accessories can be worn together. |
| pass_2x_tips (optional, deferred) | 2x Tips | R$199 | Doubles tips from working cats | The standard tycoon pass (median R$180 for 2x passes). Hold until two weeks of soft-launch data show wallets are not already climbing. |

Dropped in v0.3: Second Cat Room. The v0.3 cat room has no cap, so the pass would sell nothing. Do not add a cap just to sell storage.

Not in the set, and why:
- Role slots or tiers for Robux: slots and rank ups are the main coin sinks (gdd).
- Net levels or any catch, rescue or shiny chance for Robux: pay-to-win on the core skill, and a shiny chance boost is a probability modifier.
- Skipping or shortening the 10-minute bait wait, or a second bait bowl: the gdd rules out Robux to speed up bait, and a second bowl doubles the rate of random cats.
- Anything that changes the dealer: see section 7.3.
- A coins developer product: section 7.

Private servers: free. Friends playing together is goal three of the project, and a free private server is the cheapest way to let a parent host a kid's friends.

Description line on every pass: "Everything in Purr Pot can be earned by playing. Passes add looks and convenience."

## 4. Later options

| Option | When | Rules |
|---|---|---|
| Seasonal cosmetic sets (Autumn Leaves decor, Winter Scarves for cats, holiday uniforms) | After soft launch, one per season | Rotate in and out, but always return next year and say so. No "last chance" copy. R$99 each. |
| Direct-sale cosmetic cat look | When the catalog has its 50 cats | A specific named look (pattern or color) at a fixed price, never random. Its pay must equal an earnable cat of the same rarity so it is a look, not power. Never a shiny for Robux: shinies are the rescue reward and a collection goal. |
| Coins developer product | Phase 5, if shop_checkout shows a high `affordable=no` rate and wallets are flat | Section 7.3 in full. Linear pricing (same coins per Robux at every size; a bigger pack may add a stated bonus, never a worse rate). No "best value" badge. Consider a per-day purchase cap per player. |
| Subscription "Purr Pot Club" | Phase 5, if a monthly cosmetic set is sustainable | Robux price from R$49 or local currency from $2.99. Monthly cosmetic set plus a small daily treat. Benefits must be distinct from passes, identical on every platform, honored for the full term. Creator gets 70% of Robux subscriptions monthly; local-currency ones pay 70% month one and 100% after. Local currency needs ID or phone verification and is unavailable in some countries. |
| Regional pricing | On by default for passes; leave it on | Roblox adjusts by region, never above the default and never below 30% of it. Developer product prices must be read with MarketplaceService at runtime and GetUsersPriceLevelsAsync used; no hard-coded prices. |
| Price optimization | Not for us | Needs about 60,000 transactions in 30 days. |

## 5. Do not build (and the complaint or rule each one maps to)

| Item | Why not |
|---|---|
| Paid eggs, crates, spins, Robux-bought food | Paid random item rules; gacha scrutiny with a child audience; the gdd's "no Robux path to a random cat" |
| Luck boosts for Robux (better food odds, shiny chance, Catnip for Robux) | Probability modifier items fall under the same rules; "pay for better odds" is the casino complaint in Andy Hall's analysis |
| Bump protection, immunity, a stronger or longer-range bump, or faster carry speed for Robux | Bumps are the first player-versus-player contact. Selling defence against other children, or power over them, is the worst-reviewed pattern in the comps (Steal a Brainrot shields and traps). Bumps stay free and symmetric. |
| Robux-only power (role slots, tiers, net levels, areas) | Steal a Brainrot's pay-to-win reviews; hollows out the coin economy |
| A paid dealer reroll or extra dealer slot | A paid reroll of a random stock is a paid random item (section 7.3) |
| Robux to skip the bait timer | Ruled out by the gdd; also turns waiting into a pressure surface |
| Admin commands or "server owner" powers for sale | Steal a Brainrot criticism; griefing vector |
| Trading of any paid item | Scam vector (Adopt Me); IsPaidItemTradingAllowed gating |
| Limited-quantity items, countdown purchase timers, streak resets | FTC complaint scarcity marketing; Kinzoo parent complaints |
| Top spender or donation leaderboards, donation passes | SOUPS 2025 social pressure; Koala Cafe's R$10,000 "donation" pass is the anti-pattern |
| Rewards for watching media feeds | Banned for Kids and Select audiences since 2026-08-25 |
| A second, Robux-bought currency | Layered currency obscures cost (FTC complaint) |
| Licensed characters as passes | IP takedown risk (Cat game's Sanrio passes; Steal a Brainrot's character dispute) |

## 6. Shop and dealer UI rules (for ui-designer)

- Price in Robux on the card before the Roblox purchase prompt, with the free alternative in one line under every non-cosmetic pass ("Or keep earning: the base cap is one hour").
- Decline and buy buttons the same size and contrast. No grayed-out "No thanks".
- No timers anywhere in the shop. Seasonal sets show "Back every autumn".
- The dealer screen shows tonight's stock, prices and each food's odds before buying. No countdown on the dealer screen itself and no "only tonight" copy; the HUD clock chip already says when night ends. Use "He's back every night" instead.
- Cosmetics tab first, convenience second. Owned passes show "Owned" and hide the price.
- Every food card (shop and dealer) opens its odds with a control labelled "Odds" or "Details", never a bare (i) icon, and shows the per-cat line the designer added.
- PolicyService:GetPolicyInfoForPlayerAsync is called once per player on join and cached by the server; the shop reads the cached flags when it builds the panel.
- Never show another player's spending or inventory as a purchase prompt.
- Fire the robux_purchase funnel (analytics-plan.md 4.4) from the server on prompt and completion.

## 7. Food, the dealer and a coins product: the paid random item model

### 7.1 Where things stand in v0.3

Every food, shop or dealer, yields a random cat at the bowl: rarity from the food's odds, the cat uniformly among that rarity's cats in the player's unlocked areas, a 2% shiny roll and a random charm. All of it is rolled when the food goes in. Today coins are only earned, so food is exempt (the policy's own example: a key found in gameplay that opens a chest needs no odds). If coins are ever sold for Robux, every food becomes a paid random item for every player who could buy coins.

Checked against v0.3 on 2026-10-26:
- All seven food tables and all five dealer slot weight rows sum to exactly 100%.
- The per-cat line is on every card, and the card says when a tier up changes the split. Satisfies "every possible outcome".
- Delivery is guaranteed: the cat always arrives at the player's own bowl, Tame always works, and Let go is the player's choice. Baited cats are never carried, so a bump can never take a cat that came from food. This closes the v0.1 concern about lured strays fleeing.
- BuyLure and BuyDealerFood have no PolicyService gate, which is correct (section 7.3 point 9).

### 7.2 Option A (recommended for soft launch): no coins product

Food stays exempt. Everything below is already in the design or cheap to add now, so switching to option B later is a configuration change, not a redesign.

### 7.3 Option B: a coins product ships. Everything below is then mandatory

Disclosure, every player:
1. Food odds as percentages summing to 100%, opened from a control labelled "Odds" or "Details". Done in the design.
2. Every outcome listed. A food's outcome is a cat, a variant and a charm, so the odds panel needs three lines, all independent of each other:
   - Cat: the rarity table plus the per-cat line. Done in the design.
   - Shiny: "Each cat has a 2% chance to be shiny (earns 1.5x)." On every shop and dealer food card since data-model v0.3.1.
   - Charm: the star distribution, because charm changes what the cat earns (0.8x to 1.2x). From data-model section 4b (average of two uniform rolls, bands of 20), the exact shares are 1 star 7.84%, 2 stars 23.53%, 3 stars 35.67%, 4 stars 24.31%, 5 stars 8.65%. Shown to one decimal they sum to 100.0 if 5 stars is written as 8.7%; otherwise add the "rounded, may not total 100%" note. On every food card since data-model v0.3.1.
3. Any modifier that changes the roll shows its numeric effect before purchase and the live odds while active. Catnip already does both (common-features 14), and it shifts only wave spawn rolls in the areas, never bait or dealer rolls (data-model v0.3.1), so food card odds never change while it runs. A tier up changes the per-cat split, which the card already states.
4. Delivery guaranteed. Done (section 7.1). Keep it a rule: food-born cats never enter carry, so bumps never touch them.
5. Duplicates are still an outcome with benefit (they sell for 25 to 12,000).

The dealer:
6. The nightly stock roll is free and shown before purchase, so the roll itself is not a paid random item, and buying a visible slot is a direct sale. Each dealer food is then a paid random item exactly like a shop food, with its card odds. Done in the design.
7. Never sell a reroll of the stock or an extra slot, for Robux or for coins once coins are sold. That would be paying for a random stock.
8. The later "upgrade that improves the dealer" (data-model 8b) would change the stock odds. If it ever exists alongside a coins product, show the slot weights for the current and the upgraded level before purchase. Showing the current tier's weights on the dealer screen's Details panel now costs one table and also explains to players why the stock improves with tier.

Restricted players (ArePaidRandomItemsRestricted true):
9. Gate the coins product, not the food. The server never prompts it for a restricted player and the shop hides it. Their coins are then all earned, which is the policy's "unpaid, earnable path", and BuyLure, BuyDealerFood and UseLure stay open. In the design (data-model 15).
10. If a receipt for a restricted player arrives anyway, grant the coins (never take Robux without delivering) and log `error_recovered` with system `policy`; do not build a two-pool wallet.
11. Trading is off, so IsPaidItemTradingAllowed changes nothing. Keep the cached value for the day a gifting feature appears.

Pricing and safety:
12. Linear pricing across pack sizes, a stated bonus on the largest at most, and no "best value" badge. Consider a cap of three packs per player per day, shown as "That's enough for today, come back tomorrow" rather than a hidden refusal. Note the top dealer food costs 40,000 coins; price packs so no single pack buys a Star Treat outright.
13. Coins packs show the coin amount and the Robux price on one card; no intermediate token.

Paperwork and audit:
14. Answer yes to paid random items on the content maturity questionnaire and describe the PolicyService handling; the Minimal label is still reachable.
15. Test both flags with the Studio Player Emulator before publishing.
16. `bait_rolled` (analytics-plan.md 6.1) records food, rolled rarity and source, so card odds can be audited against results; target within 2 points.

Cost of option B on top of the current design: S. The shiny and charm card lines are in the design since v0.3.1; the dealer weights table in point 8 is the last cheap item worth adding in the slice.

## 8. Creator Rewards fit

- Sessions over 10 minutes: one day plus one night is 10 minutes on the v0.3 clock, and the bait timer is also 10 minutes, so a natural session crosses the threshold.
- First three experiences of the day: the overnight offline earnings and a bait cat waiting at the bowl are the daily reasons to open Purr Pot first. The Daily Treat card does not reset, so there is no fear-based streak.
- Audience expansion credits arrive through the details page link and name search, so the final title must be a searchable, distinctive name (comps.md section 9) and friends share the details-page link, not a server link.
- Derek needs an ID-verified account and a DevEx account before soft launch for the audience expansion share to count. Both are free.

## 9. Soft launch checklist

- [ ] Four passes created with the catalog ids above, descriptions carry the "everything can be earned" line, regional pricing left on.
- [ ] Private servers set to free.
- [ ] Content maturity questionnaire answered: Minimal target; paid random items "no" under option A, "yes" with the handling described under option B.
- [ ] PolicyService call and cache in place; no gate on food.
- [ ] Food cards show the rarity table, the per-cat line, the shiny line and the charm stars (in the design since v0.3.1); the dealer Details panel shows the tier's slot weights.
- [ ] robux_purchase funnel verified in View Events.
- [ ] docs/decisions.md entry recorded.

Proposed for docs/decisions.md: 2026-10-26, soft launch passes are Long Nap, VIP Decor Set, Cat Accessories and Uniform Styles (Second Cat Room dropped because the v0.3 cat room has no cap; 2x Tips still deferred), with no coins product; nothing paid ever touches bumps, the bait timer or the dealer stock; food cards add a shiny line and the charm star odds now so a later coins product needs no redesign.
