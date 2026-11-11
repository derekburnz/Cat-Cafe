# Trait station (the Mystic Pool): one trait per cat (#3196)

Status: **approved** (Derek2, 2026-11-11 14:23 UTC: "Yes for everything ... also give 5 free rerolls off start"). Build behind the `traits` flag. The plan on #3196 is the source; this file is the short spec the build follows, with the numbers the comments asked for.

Derek2, 2026-11-10: "re-work the picnic into a station ... to add traits 1 per cat that do things like increase food bowl luck, extra money, slight speed bonus etc make it cost gold fish or trait re-roll tokens and add those to the game into certain rewards like spins etc... (also make the circle infront open the menu)". Then at 23:59 UTC: "make re-rolls the same cost as first trait".

## 1. The station: the Mystic Pool
Derek2, 2026-11-11 14:34 UTC: "Re-work the station to be like a mystical wizard cat giving traits to your cats ... dropping them in a pool of liquid and it changes color based on how good the rarity is", then "make the legendary / mythic traits give combinations of multiple things".

- The Park's Picnic Basket becomes the **Mystic Pool**. It stays in the same spot with the same unlock (the Park's camp extra, Tier 2).
- **Who runs it:** an old wizard cat, **Sage Sorrel**. Sorrel wears a starry robe and a pointed hat and holds a staff, and stands beside a round stone pool of glowing liquid. Model and sign: model lane. Animation: animation lane.
- The walk-in circle opens the menu (WalkUp ring, #3112). It also opens from the Cannon menu with no range check, like every other station (camp-extras.md §3).
- **Menu:**
  - Pick a cat from a searchable list with faces, the same picker as the Spa (#3136).
  - See its trait, then Roll (or Re-roll).
  - After a re-roll, the old trait and the new one show side by side, with **Keep old** and **Take new**.
  - The odds line is always on the card.
- While a player still has starter rolls, the Roll button reads **Free roll (5 left)** and uses those first.
- The Picnic Basket's Money Potion every 6 h goes away. In its place is **1 free Trait Token every 12 h, holding 2**, with the same "Next in ..." line.

### 1a. The roll animation
The server decides the result first. The animation only shows it.
1. Sorrel raises the staff. The chosen cat floats up in a sparkle and drops into the pool with a splash.
2. The liquid starts **grey**. It then steps up through the colours, one step about every 0.6 s, with a bubble burst on each step, and **stops on the rolled rarity's colour**:

| Rarity | Pool colour steps | Total time |
|---|---|---|
| Common | grey | about 1.2 s |
| Uncommon | grey, green | about 1.8 s |
| Rare | grey, green, blue | about 2.4 s |
| Legendary | grey, green, blue, gold | about 3.0 s |
| Mythic | grey, green, blue, gold, then a fast flash to **mythic purple** with a rainbow shimmer and a star burst | about 4.0 s |

3. The cat pops back out on a splash. The trait card rises with the trait's name, its rarity colour and what it does.
- Colours: Common grey `#9AA0A6`, Uncommon green `#4CAF50`, Rare blue `#3F8FE0`, Legendary gold `#F4C430`, Mythic purple `#B04FE0` with a rainbow shimmer.
- **No near-miss teasing:** the pool never goes past the real colour and comes back, and never pauses on a step to fake a "nearly". This is for a young audience.
- After the first roll, a tap skips straight to the card.
- **Mythic:** a server-wide line, "<name>'s cat got a Mythic trait!", once per Mythic. It uses the same channel as the existing rare-catch announcements and shows display names only.

## 2. Traits
Each cat holds one trait at a time. A roll picks the **rarity** first, then a trait from that rarity's list.

### 2a. Common, Uncommon and Rare: one effect
At these rarities the roll picks one of six traits evenly. Each trait is stronger at each rarity.

| Trait | Effect | Common | Uncommon | Rare | Counts |
|---|---|---|---|---|---|
| Big Tipper | this cat's income | +5% | +8% | +12% | the cat itself |
| Night Owl | this cat's income at night | +10% | +15% | +22% | the cat itself |
| Fast Learner | this cat's XP gain | +10% | +15% | +22% | the cat itself |
| Lucky Bowl | bait bowl luck | +2% | +3% | +4% | best 3 working cats |
| Quick Paws | walk and carry speed | +0.3 | +0.5 | +0.7 studs/s | best 1 working cat |
| Rich Friend | rich visitor rate | +2% | +3% | +4% | best 2 working cats |

### 2b. Legendary: two effects
The roll picks one of four traits evenly.

| Trait | Effects |
|---|---|
| Golden Whiskers | this cat's income +18%, rich visitor rate +6% |
| Moonlit Hunter | this cat's night income +30%, bait bowl luck +6% |
| Prodigy | this cat's XP +30%, this cat's income +10% |
| Lightning Tail | walk and carry speed +1.0, this cat's XP +20% |

### 2c. Mythic: three effects, very strong
The roll picks one of three traits evenly.

| Trait | Effects |
|---|---|
| Cosmic Fortune | this cat's income +40%, bait bowl luck +12%, rich visitor rate +12% |
| Eternal Night | this cat's night income +60%, this cat's XP +75%, walk and carry speed +1.5 |
| Star Sage | this cat's XP +100%, this cat's income +25%, bait bowl luck +10% |

### 2d. How the effects add up
Each effect inside a combo counts like the single trait with the same effect. For example, Moonlit Hunter's bowl luck is one of the "best 3 working cats" for Lucky Bowl.
- **Bait bowl luck:** only the best 3 working cats count, at most +36%. It always stays inside `LuckMax`.
- **Speed:** only the best 1 working cat counts, at most +1.5 studs/s.
- **Rich visitor rate:** only the best 2 working cats count, at most +24%. That stays below Cafe Style's 0.25, so no trait beats a paid perk (§5).
- **Per-cat effects** (income, night income, XP) apply only to that cat.
- "Working" means the cat is in a staff slot in the cafe. Traits on resting, Spa or carried cats don't count.
- No trait touches catch difficulty, rescue bars or wild rarity odds.

## 3. Rolls and costs
- **5 free starter rolls** (Derek2, 2026-11-11). Every player gets them once, the first time the Mystic Pool unlocks for them. Players who already own the Park's camp extra get them when the flag turns on. They are used before tokens and fish, can go on any cat, and never come back.
- **Save shape (Review-Agent, 2026-11-11):** store `traitFreeRollsUsed` (0 to 5, counts up), not a count left, and never write a default of 5 for a missing field. Free rolls left = 5 minus used. The field only ships with the save version step and its restart publish (§6), so no older server can drop it and hand the 5 out again.
- **Rarity odds per roll:**

| Rarity | Chance |
|---|---|
| Common | 55% |
| Uncommon | 28% |
| Rare | 12% |
| Legendary | 4% |
| Mythic | 1% |

- The first trait and every re-roll cost the same: **10 golden fish or 1 Trait Token**.
- **How long it takes:**
  - any Legendary: about 25 rolls;
  - any Mythic: about 100 rolls (about 1,000 golden fish);
  - one exact Mythic: about 300 rolls.
- With keep-or-swap, a cat never gets worse. That makes this a long, optional golden fish sink.
- The 5 free rolls give about a 5% chance at a Mythic and about 23% at Legendary or better.
- Trait Tokens are **never sold** in any Robux product, pack or pass. They can't be traded or gifted. Golden fish are earned only too, so this is not a paid random item. The odds are shown anyway.

## 4. Where Trait Tokens drop
| Source | Amount |
|---|---|
| Starter gift | 5 free rolls, once (see §3) |
| Mystic Pool | 1 every 12 h, holds 2 |
| Spin Wheel slice 3 | 1 token, weight **9** (4.5%; was "3 golden fish" at weight 30, 15%) |
| Spin Wheel slice 1 | weight **91** (was 70), so the wheel total stays 200 |
| Daily Treat day 7 | 1 |
| Weekly quest set | 1 |
| Lost and Found table | 1 slot, rarest band |
| Update codes | per code, set when the code is made |

**Why weight 9:** slice 3 paid 0.45 fish per spin on average (15% × 3). A token is worth about 10 fish, so 4.5% × 10 is the same 0.45 fish of value per spin. The 21 freed weight goes to the smallest coin slice, so the wheel's jackpot odds don't move.

## 5. Stacking check (Monetization's ask for Rich Friend)
- Rich rate today is `1 + 0.25 (Cafe Style) + 1.0 (Grand Cafe)`, at most 2.25 (`Economy.richRate`).
- Traits add at most 0.24 more (best 2 cats, Mythic Cosmic Fortune at +12% each), so the cap becomes 2.49.
- A rich tip pays 120 s of the day rate about every 480 s of open day, so each 1.0 of rate is about +25% income.
  - **Free player:** rate 1 to 1.24 is about +6% income.
  - **Cafe Style alone:** its 0.25 is about +6%. Two Mythic cats nearly match it but never pass it, and the common case (Rare, +4% each) is about a third of it.
  - **Every pass:** 2.25 to 2.49 is about +6% income on top of roughly 24x. That's inside the 11-05 stacking re-check's margin (economy-ladder.md §6a), but Monetization should re-check it with the Mythic numbers.
- Speed tops out at +1.5, under half of the Swift Potion's +4. Bowl luck stays under `LuckMax`. Per-cat income tops out at +40% on one cat. So no paid perk is undercut.

## 6. Save and publish
- A trait is a new field on each saved cat, `trait = { id }` (each trait id carries its rarity and effects in Config), plus a `traitTokens` count, a `traitFreeRollsUsed` count (starts at 0) and the station's token timer on the profile.
- Older servers would drop these when they save, so this needs a save version step and **one publish with a server restart**. That restart needs Derek's yes at the time.
- Everything else (the menu, the pool animation, the circle, the token drops, the spin slice) is built first behind a LiveFlag `traits`, switched off.

## 7. Telemetry
- `trait_roll` with `{ trait, rarity, paidWith = "fish" | "token", reroll, kept = "old" | "new" }`.
- `trait_token` with `{ source }`.

## 8. QA checks
1. A cat with a trait keeps it through a rejoin and a trade (the trait travels with the cat).
2. Bowl luck from 4 working cats (mixed single and combo traits) counts only the best 3, and never pushes bowl luck past `LuckMax`.
3. Speed from 3 working cats (Quick Paws, Lightning Tail, Eternal Night) gives only the best one's bonus, including while carrying a cat.
4. A re-roll that rolls worse can be declined, and the cat keeps the old trait.
5. Rolling with 9 golden fish and no token is refused server-side.
6. The token timer holds at 2 and shows "Next in ...".
7. A new player's first 5 rolls cost nothing and show "Free roll (n left)"; the 6th asks for a token or 10 fish. A rejoin mid-way keeps the count.
8. Spin slice 3 pays 1 token at about 4.5% over 2,000 spins.
9. Over 10,000 server rolls, rarities land near 55 / 28 / 12 / 4 / 1%.
10. The pool's colour steps match the server's rarity every time and never go past it. Tap to skip works after the first roll.
11. A Mythic sends one server-wide line with the display name only.
