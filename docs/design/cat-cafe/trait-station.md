# Trait station: one trait per cat (#3196)

Status: **approved** (Derek2, 2026-11-11 14:23 UTC: "Yes for everything ... also give 5 free rerolls off start"). Build behind the `traits` flag. The plan on #3196 is the source; this file is the short spec the build follows, with the numbers the comments asked for.

Derek2, 2026-11-10: "re-work the picnic into a station ... to add traits 1 per cat that do things like increase food bowl luck, extra money, slight speed bonus etc make it cost gold fish or trait re-roll tokens and add those to the game into certain rewards like spins etc... (also make the circle infront open the menu)". Then at 23:59 UTC: "make re-rolls the same cost as first trait".

## 1. The station
- The Park's Picnic Basket becomes the **Cat Trainer**. It stays in the same spot with the same unlock (the Park's camp extra, Tier 2). Model and sign: model lane.
- The walk-in circle opens the menu (WalkUp ring, #3112). It also opens from the Cannon menu with no range check, like every other station (camp-extras.md §3).
- **Menu:**
  - Pick a cat from a searchable list with faces, the same picker as the Spa (#3136).
  - See its trait, then Roll (or Re-roll).
  - After a re-roll, the old trait and the new one show side by side, with **Keep old** and **Take new**.
  - The odds line is always on the card.
- While a player still has starter rolls, the Roll button reads **Free roll (5 left)** and uses those first.
- The Picnic Basket's Money Potion every 6 h goes away. In its place is **1 free Trait Token every 12 h, holding 2**, with the same "Next in ..." line.

## 2. Traits
Each cat holds one trait at a time.

| Trait | Effect | I | II | III | Counts |
|---|---|---|---|---|---|
| Big Tipper | this cat's income | +5% | +10% | +15% | the cat itself |
| Night Owl | this cat's income at night | +10% | +20% | +30% | the cat itself |
| Fast Learner | this cat's XP gain | +10% | +20% | +30% | the cat itself |
| Lucky Bowl | bait bowl luck | +2% | +4% | +6% | best 3 working cats, at most +18%, always inside `LuckMax` |
| Quick Paws | walk and carry speed | +0.3 | +0.6 | +1.0 studs/s | best 1 working cat, at most +1.0 |
| Rich Friend | rich visitor rate | +2% | +4% | +6% | best 2 working cats, at most +12% |

- "Working" means the cat is in a staff slot in the cafe. Cafe-wide traits from resting, Spa or carried cats don't count.
- No trait touches catch difficulty, rescue bars or wild rarity odds.

## 3. Rolls and costs
- **5 free starter rolls** (Derek2, 2026-11-11). Every player gets them once, the first time the Cat Trainer unlocks for them. Players who already own the Park's camp extra get them when the flag turns on. They are their own counter (`traitFreeRolls`), used before tokens and fish, can go on any cat, and never come back.
- A roll picks one of the six traits evenly, then its strength: **I 70%, II 25%, III 5%**.
- The first trait and every re-roll cost the same: **10 golden fish or 1 Trait Token**.
- A Strength III of the trait you want takes about 120 rolls (6 traits × 1 in 20), or about 20 for any III. With keep-or-swap, a cat never gets worse. That makes this a long, optional golden fish sink.
- Trait Tokens are **never sold** in any Robux product, pack or pass. They can't be traded or gifted. Golden fish are earned only too, so this is not a paid random item. The odds are shown anyway.

## 4. Where Trait Tokens drop
| Source | Amount |
|---|---|
| Starter gift | 5 free rolls, once (see §3) |
| Cat Trainer | 1 every 12 h, holds 2 |
| Spin Wheel slice 3 | 1 token, weight **9** (4.5%; was "3 golden fish" at weight 30, 15%) |
| Spin Wheel slice 1 | weight **91** (was 70), so the wheel total stays 200 |
| Daily Treat day 7 | 1 |
| Weekly quest set | 1 |
| Lost and Found table | 1 slot, rarest band |
| Update codes | per code, set when the code is made |

**Why weight 9:** slice 3 paid 0.45 fish per spin on average (15% × 3). A token is worth about 10 fish, so 4.5% × 10 is the same 0.45 fish of value per spin. The 21 freed weight goes to the smallest coin slice, so the wheel's jackpot odds don't move.

## 5. Stacking check (Monetization's ask for Rich Friend)
- Rich rate today is `1 + 0.25 (Cafe Style) + 1.0 (Grand Cafe)`, at most 2.25 (`Economy.richRate`).
- Rich Friend adds at most 0.12 more, so the cap becomes 2.37.
- A rich tip pays 120 s of the day rate about every 480 s of open day, so each 1.0 of rate is about +25% income.
  - **Free player:** rate 1 to 1.12 is about +3% income.
  - **Cafe Style alone:** its 0.25 is about +6%, so Rich Friend stays at about half the paid perk.
  - **Every pass:** 2.25 to 2.37 is about +3% income on top of roughly 24x. That's well inside the 11-05 stacking re-check's margin (economy-ladder.md §6a).
- Quick Paws +1.0 is a quarter of the Swift Potion's +4. Lucky Bowl stays under `LuckMax`. So no paid perk is undercut.

## 6. Save and publish
- A trait is a new field on each saved cat, `trait = { id, strength }`, plus a `traitTokens` count, a `traitFreeRolls` count (starts at 5) and the station's token timer on the profile.
- Older servers would drop these when they save, so this needs a save version step and **one publish with a server restart**. That restart needs Derek's yes at the time.
- Everything else (the menu, the circle, the token drops, the spin slice) is built first behind a LiveFlag `traits`, switched off.

## 7. Telemetry
- `trait_roll` with `{ trait, strength, paidWith = "fish" | "token", reroll, kept = "old" | "new" }`.
- `trait_token` with `{ source }`.

## 8. QA checks
1. A cat with a trait keeps it through a rejoin and a trade (the trait travels with the cat).
2. Lucky Bowl from 4 working cats counts only the best 3, and never pushes bowl luck past `LuckMax`.
3. Quick Paws from 3 working cats gives only the best one's bonus, including while carrying a cat.
4. A re-roll that rolls worse can be declined, and the cat keeps the old trait.
5. Rolling with 9 golden fish and no token is refused server-side.
6. The token timer holds at 2 and shows "Next in ...".
7. A new player's first 5 rolls cost nothing and show "Free roll (n left)"; the 6th asks for a token or 10 fish. A rejoin mid-way keeps the count.
8. Spin slice 3 pays 1 token at about 4.5% over 2,000 spins.
