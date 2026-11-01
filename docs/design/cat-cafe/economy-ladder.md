# The money ladder, tier pace and coming back (F95)

Status: decided by Derek in the Google Doc's Set 5 answers (read 2026-11-01) and his 2026-11-01 22:32 answer to Monetization-Agent, specced by the game-designer thread. His answers:

- Q5 (tier pace, "Tier 2 about 15 minutes, Tier 3 about 50 minutes, Tier 4 about 2.5 hours and Tier 5 about 7 hours of play"): "Sounds good."
- Q6 (offline cap to 8 hours): "Raise the cap to 8h works, possible paying options to increase later." Then at 22:32: "I think do 50% offline and pass makes it 100% and up to 16h".
- Q7 (older rare cats): "I think mythical from T1 should be about as good as legendary from T2 or epic from T3 etc…"
- 2026-10-28 14:22: Tier 5 at 5 to 10 hours of play, and it is fine to need log off and return rewards.
- 2026-10-28 17:01: "slow down progression especially money making from everything by ALOT like 15 minutes of playing and basically done tier 3". Section 3 puts Tier 3 at 50 minutes.
- Three smaller notes from 2026-10-28 to 10-30, in section 6b.

It changes data-model sections 4b, 5b, 6, 7, 8, 9, 11, 12b and 17, the prize tables' coin seconds, the Lucky Cat prices in luck-and-rare-moments.md and the lawn prices in front-lawn.md. It changes the live keep up rule (F86, in v56) by config, without reverting it. Where they differ, this wins.

## 1. The area ladder

Each area now pays three times the one before it, so one step up in area is worth one step up in rarity, as Derek asked.

`incomeMultiplier` per area: Alleyway 1, Park 3, Neighbourhood 9, Woods 27, Sewer 81 (was 1, 1.5, 2.25, 3.5 and 5). Rarity rates stay 1, 3, 8, 25 and 75. Base rates at charm 50 and level 1:

| area | Common | Rare | Epic | Legendary | Mythical |
|---|---|---|---|---|---|
| Alleyway | 1 | 3 | 8 | 25 | 75 |
| Park | 3 | 9 | 24 | 75 | 225 |
| Neighbourhood | 9 | 27 | 72 | 225 | 675 |
| Woods | 27 | 81 | 216 | 675 | 2,025 |
| Sewer | 81 | 243 | 648 | 2,025 | 6,075 |

Read the diagonal: an Alleyway Mythical (75) earns as much as a Park Legendary (75), a Neighbourhood Epic (72), a Woods Rare (81) and a Sewer Common (81). Spare cats keep the area they came from (`incomeArea`), and Catalog sets each CatDef's `incomePerSecond` to rarity rate times area multiplier, as now.

## 2. Keep up becomes the ladder

Keep up (F86) let an older Legendary or Mythical earn as if it came from the area one step behind the player's newest. On the ladder that would make an older Mythical always as good as the newest area's Legendary (75 x 27 = 2,025 at Tier 5, a Sewer Legendary), which breaks Derek's "epic from T3" step. So:

- `KeepUpRarities` becomes empty. Every area cat earns with its own area's multiplier and the "Keeps up" tag stops showing.
- The code stays: `CatStats.areaMultiplier(def, tier)`, `KeepUpStepsBehind` and every caller passing the owner's tier. The shop-only cats use it (section 6), and keep up can come back by config.
- What older cats are worth at Tier 5: an Alleyway Mythical earns like a Sewer Common, a Park Mythical like a Sewer Rare (225 against 243), a Neighbourhood Mythical like a Sewer Epic (675 against 648) and a Woods Mythical like a Sewer Legendary (2,025). The best older cats stay in the cafe for a tier or two after the player moves on. The newest area's rare cats are the big step up.
- Nothing saved changes.

## 3. Tier costs and pace

| tier | was | now |
|---|---|---|
| 2 | 8,000 | 8,000 |
| 3 | 80,000 | 350,000 |
| 4 | 700,000 | 27,000,000 |
| 5 | 5,000,000 | 800,000,000 |

Time to each tier, in minutes or hours of play (the day it comes in brackets). Medians of the pace model, 40 to 200 seeded runs:

| player | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|---|---|---|---|---|
| plays in one go, nothing offline | 15 min | 51 min | 3 h 24 | 10 h |
| an hour a day, free offline | 12 min | 52 min (day 1) | 2 h (day 2) | 4 h 42 (day 5) |
| half an hour a day, free offline | 12 min | 30 min (day 1) | 1 h 30 (day 3) | 3 h (day 6) |
| an hour a day with Long Nap | 12 min | 52 min (day 1) | 1 h 7 (day 2) | 3 h (day 3) |
| 4x Money, in one go | 9 min | 27 min | 1 h 28 | about 4 h 45 |
| owns every paid bonus (about 24x and an extra slot), in one go | 9 min | 28 min | 56 min | 2 h 8 |

Why not exactly Q5's 15 minutes, 50 minutes, 2.5 hours and 7 hours: Derek okayed those for play time, then made offline far bigger (section 5). A night away now pays 4 hours of income, so at the Q5 costs a player who comes back daily reached Tier 5 on day 3 with 3 hours of play. That is too soon to run out of tiers. These costs put one-go play at about 10 hours and daily play at about 5 hours, the two ends of Derek's 5 to 10 hour range, with Q5's 7 hours between them. Set 6 asks Derek to confirm.

- Tier 2 and Tier 3 match Q5, since no night has passed yet.
- The v0.8 rule holds: if QA finds a tier too quick, its cost goes up rather than the rewards going down.
- The model: the v0.13.16 one (4 catches a day, bait kept going, five bowl levels, Tip Jar coins at half, section 6b), with the prices in section 4 and offline paid at the end of each day's session. It leaves out the Lucky Cat, the lawn, crate decor, potions and the F94 prize tables, so real players run a little faster.

## 4. Shop prices from Tier 3 on

A cafe now earns about 4 times today's figure at Tier 3, about 8 times at Tier 4 and about 16 times at Tier 5. Every coin price that needs Tier 3 or later goes up by that much, so each tier's shop still takes a while to fill:

| item | level | needs | was | now |
|---|---|---|---|---|
| Tables | 5 | Tier 3 | 50,000 | 200,000 |
| Tables | 6 | Tier 3 | 150,000 | 600,000 |
| Espresso machine | 4 | Tier 3 | 100,000 | 400,000 |
| Espresso machine | 5 | Tier 4 | 800,000 | 6,000,000 |
| Net | 3 (Master Net) | Tier 3 | 200,000 | 800,000 |
| Bait bowl | 3 (Fancy Bowl) | Tier 3 | 60,000 | 240,000 |
| Bait bowl | 4 (Deluxe Bowl) | Tier 4 | 500,000 | 4,000,000 |
| Bait bowl | 5 (Royal Bowl) | Tier 5 | 3,000,000 | 50,000,000 |
| Neon cat sign | | Tier 3 | 60,000 | 240,000 |
| Fish tank | | Tier 4 | 500,000 | 4,000,000 |
| Lucky Cat (F88) | 3, 4, 5 | Tier 3, 4, 5 | 150,000, 1,000,000, 5,000,000 | 600,000, 8,000,000, 80,000,000 |

- Front lawn (F91): Tier 3 pieces and styles cost 4 times their front-lawn.md price, Tier 4 ones 8 times and Tier 5 ones 16 times. For example the Umbrella Table is 100,000, the Fairy Light Arch 1,200,000 and the Golden Paw Statue 50,000,000.
- Food prices stay. Late on the dealer's foods are cheap for a big cafe, and the dealer's amounts (F94: one stock a night) are what keep them rare.
- Rich tips, tip piles and every coin prize already scale with the day rate, so they follow the ladder by themselves.

## 5. Coming back: offline earnings

- **Free:** OfflineRate 0.5 and OfflineCapSeconds 28,800. A player away for a night comes back to 4 hours of income.
- **Long Nap pass** (Monetization-Agent's plan, R$199): OfflineRatePass 1.0 and OfflineCapPassSeconds 57,600. The full rate for up to 16 hours.
- `offlineGain = dayRateAtLogout x rate x min(now - lastSeen, cap)`, with the pass's rate and cap when the player owns Long Nap on the join that pays it (checked on the server at join and cached for the session).
- `dayRateAtLogout` still leaves out potions, because potion timers pause while away. It includes the money pass multiplier (section 6), since a pass is permanent.
- The welcome back card: "Your cats earned 1.2M while you were away (7 h 40 m)" with a Collect button and a line saying "Half pay while away, up to 8 hours" (or "Full pay, up to 16 hours" with Long Nap). Monetization-Agent's plan decides where Long Nap is offered. It never takes the place of Collect and never shows to a player who owns it.
- Bait in the bowl keeps counting while away, as now.

## 6. Hooks for Monetization-Agent's shop

- **Money passes.** `incomePerSecond` gains `x passMultiplier`: 1, or 2, 3 or 4 for the 2x, 3x and 4x Money passes (the highest owned counts). It applies after the potions, so 4x with a Big Money Potion is 6x. Tip piles, rich visitors and coin prizes use the day rate, so they scale too ("all cafe income").
- **The other paid bonuses** in Monetization-Agent's plan (Cafe Style and Grand Cafe add into `cafeMultiplier`; Cat Accessories and Uniform Styles multiply a dressed or working cat's rating by 1.15) go in where its plan says. This spec only adds the hooks they need.
- **Shop-only cats** (the starter, Royal, Grand and season cats): CatDef `exclusive = true`. Their `areaIncomeMultiplier` is the owner's newest area's multiplier, worked out from the tier each time, so they earn like a newest-area cat of their rarity. At Tier 1 the Grand cat (Mythical rate) earns 75 a second, at Tier 5 6,075, the same as a Sewer Mythical. They do not count toward "different cats", the Index or Index milestones, so ranking up still needs catching.
- **The extra role slot** (Grand Cafe): `slotBonus` from a pass adds that many role slots to every tier's `slots` (Config ExtraSlotPassIds, 0 until made), with a slot spot in each cafe expansion's layout.
- **Paid players' pace.** A 4x Money player who plays in one go reaches Tier 5 in about 4 h 45. A player who owns every paid bonus (about 24 times a free player's income, with the extra slot) reaches it in about 2 h 8 in one go, or 1 h 35 of play at an hour a day with Long Nap. That is above Monetization-Agent's one hour floor, because catching the 30 different cats Tier 5 needs takes that long whatever the income. If QA finds it under an hour, the cat requirements go up, not the bonuses down.

## 6b. Three smaller rules from Derek's 2026-10-28 to 10-30 notes

- **Coin prizes pay half.** Derek, 2026-10-30 00:27: "maybe also tune down the money rewards based on income a bit as it progresses the cafe very fast and makes thing like the rich customer less rewarding and finding better cats feel less rewarding". Every prize paid in seconds of day rate (`coinSeconds` in the Tip Jar, the wheel, the Daily Treat, quests, achievements, Index milestones and codes) pays half its seconds. The minimum coin amounts stay, so early prizes still feel the same. Rich visitors (120 s) and tip piles stay as they are, so next to the smaller prizes they count for more.
- **The Big Bowl takes 2 minutes off.** Derek, 2026-10-28 17:39: "big bowl upgrade lowers bait bowl to 8 minutes from 10 but should just lower it by 2 min perma since other upgrades lower it to lower times". BigBowlWaitMultiplier (0.8) becomes BigBowlWaitCutSeconds (120), taken off the bowl level's day wait before night halves it and before `baitSpeed`: 10:00 to 8:00 on a Bait Bowl, 8:00 to 6:00 on a Royal Bowl (was 6:24). Its card reads "2 minutes off every bait wait, forever".
- **Potions stack to 24 hours.** Derek, 2026-10-28 17:36: "don't add a full time for potions keep it stacking up to 24h and have it pause on exit". PotionMaxMinutes goes from 60 to 1440. The v0.13.8 refusal stays only at that cap, so the bag's "Full" is now rare. Timers still pause while the player is away (v0.10.2).

## 7. Contracts

- Catalog: AreaDef `incomeMultiplier` 1, 3, 9, 27, 81 and each CatDef's `incomePerSecond`; TierDef costs (section 3); UpgradeDef and DecorDef costs, the `lucky_cat` costs and `Catalog.lawn` prices (section 4); CatDef `exclusive?`.
- Config: KeepUpRarities `{}` (was Legendary and Mythical); OfflineRate 0.5 (was 0.25); OfflineCapSeconds 28800 (was 3600); OfflineRatePass 1.0, OfflineCapPassSeconds 57600, LongNapPassId, MoneyPassIds (2x, 3x, 4x) and ExtraSlotPassIds new, the ids 0 until Tools-Agent makes the passes, which turns their effects off; BigBowlWaitCutSeconds 120 in place of BigBowlWaitMultiplier; PotionMaxMinutes 1440 (was 60).
- Catalog prizes: every `coinSeconds` halved (section 6b), every minimum unchanged.
- Economy: `passMultiplier` in `incomePerSecond`; the offline rate and cap from the pass; `CatStats.areaMultiplier` gives exclusive cats the newest area's multiplier.
- UI: the welcome back card's text; the "Keeps up" tag reads KeepUpRarities and goes quiet by itself; Index potential lines follow the new rates.
- Save: none.
- Analytics: custom event `offline_return` (value minutes away, fields tier, minutes paid, Long Nap yes or no).
- Who builds: Gameplay-Engineer (numbers, keep up config, offline, pass hooks, exclusive cats), UI-Engineer (the welcome back card), QA-Planner (Pace.spec and section 8).

## 8. QA checks

1. At charm 50 and level 1 an Alleyway Mythical earns 75, a Park Legendary 75, a Neighbourhood Epic 72, a Woods Rare 81 and a Sewer Common 81.
2. At Tier 5 an Alleyway Legendary earns 25 and shows no "Keeps up" tag.
3. Rank ups cost 8,000, 350,000, 27M and 800M. Pace.spec: one-go play reaches Tier 2 in 10 to 20 minutes and Tier 5 in 8 to 12 hours; an hour a day with offline reaches Tier 5 on day 4 to 6.
4. Away 10 hours, a free player gets 8 hours at half their day rate. With Long Nap, 10 hours at the full rate; away 20 hours, 16.
5. A running potion does not raise offline pay. A 2x Money pass doubles the income, the tip piles and offline pay.
6. An exclusive cat at Tier 3 earns like a Neighbourhood cat of its rarity and does not count for Tier 4's 20 different cats.
7. With 4x Money and nothing offline, Tier 5 takes over 2 hours of play; if not, the Tier 5 cost goes up.
8. The Tip Jar's 60 minute gift pays 300 s of day rate (at least 1,000); a rich visitor still pays 120 s.
9. A Royal Bowl with the Big Bowl waits 6:00 by day and 3:00 by night.
10. Drinking a sixth hour of Money Potions works; a potion that would take one kind past 24 hours is refused.
