# Purr Pot (working title): Cat Cafe Game Design Doc

Draft v0.2, 2026-10-26 (v0.1 on 2026-10-25, revised after Gavin's Cat Cafe tab in the Game Ideas doc). Owner: game-designer thread. Status: ready for the engineer, asset and UI threads to build the vertical slice from. Every number here is a first guess to tune in playtests. The full tables live in [data-model.md](data-model.md), the build order and thread handoffs in [features.md](features.md), the genre-standard features for later phases in [common-features.md](common-features.md), and decisions in [docs/decisions.md](../../decisions.md).

Sources: Gavin's Game Ideas doc (Cat Cafe tab updated 2026-10-26: night spawns, net, bait and rescue, day serving, the manager fantasy), the Three Game Sketches page (25 Oct 2026) and plan section 8. Open questions for Gavin are in [questions-for-gavin.md](questions-for-gavin.md). Reference games: Steal an Egg (timed spawns in shared stages, place-and-earn pets, size and mutation value, chasing players who carry eggs) and Roll a Fisherman, also called Spin for a Fisherman (roll for staff, collect what they produce, sell it, expand the dock). We borrow the structure, never the names, art or characters.

## Pitch

A cozy cat cafe tycoon where the cats do the work and you do the collecting. Strays appear in the alley behind the cafes and in the park. You catch them with a timed grab or lure them with food, carry them home and sit them where they like to be. Every placed cat earns tips each second. Tips buy tables, decor and better tools, and better tools get you rarer cats. Fill the collection book: 12 cats in the slice, 40 at launch.

## Core loop

- By day (3 minutes): watch the cafe serve, place cats, buy upgrades, set bait, catch any leftover stray.
- By night (2 minutes): a fresh wave of strays appears in the alley and the park; net one, rescue a stuck one or collect a baited one, carry it home, drop it on a free spot, watch the rate tick up.
- Every session (10 to 15 minutes): two or three nights, two to four cats, one or two upgrades, a new spot or area, leave with offline earnings running.
- Every week: finish a rarity set in the collection book, reach cafe level 5 and the patio, hunt the night-only secret cat, visit friends' cafes to compare.

You are the manager: the hands-on jobs are catching, placing and upgrading. Serving customers is the cats' job and runs on its own.

## The cafe

Each player owns one cafe plot on a shared server of 8 players. Plots sit along one street. The alley runs behind all of them and the park is at the end of the street, so catching areas are shared and everyone sees the same strays.

A cafe has spots: fixed places where one cat can sit. Spot types in the slice are Counter, Window, Cushion, Shelf, Cat Tree and Patio. Cafe level 1 opens two spots and level 5 opens seven. Cats you own but have not placed rest in the cat room and earn nothing, so spots are the main thing you buy.

Decor and furniture appear in fixed positions when bought. Free placement is out of scope for the slice.

## Cats

Each cat type has a rarity, a base tip rate, a favorite spot type and a catch difficulty. A cat in its favorite spot earns 50% more. Gavin's model concept images (docs/concepts/cat-cafe/reference/) show cube-headed collectible cats and an upright cat in a suit; whether working cats stand up in uniforms is question 15 for him, and the one-rig plan holds until he answers.

| Rarity | Base tips per second | Slice roster | Catch chance before bonuses |
|---|---|---|---|
| Common | 1 | Tabby, Tuxedo, Ginger, Smoke, Snow | 90% |
| Rare | 3 | Calico, Siamese, Tortie, Bengal | 65% |
| Epic | 8 | Sphynx, Ragdoll | 45% |
| Legendary | 25 | Void (black cat with glowing eyes, the hero asset) | 25% |

After the slice: Secret cats that only appear at night or in rain (Midnight, Puddle), Golden and Rainbow variants with tip multipliers, seasonal cats, and merging three duplicates into a variant. In the slice, duplicates are sold for cash.

All 40 launch cats come from one blocky cat rig with pattern, color and accessory variants, so each new cat costs a texture and a name, not a model.

## The clock

The server runs a 5 minute loop: 3 minutes of day, 2 minutes of night. By day the cafe is open, customers sit and tips flow. At night the sign flips to Closed, the street lamps come on, and a fresh wave of strays appears in every catching area (Gavin's rule, like Steal an Egg). Strays nobody caught vanish when the next night starts, so leftovers can still be caught by day. A new server starts two minutes before its first night so a new player meets one inside the first ten minutes. Tips keep flowing at night in the current plan (question 10 for Gavin).

## Catching

Three ways, from Gavin's list.

Net: walk up to a stray, hold to wind up, and release the swing while the ring is in the band. The server decides success from the cat's base chance, your net level, the bait bonus and the swing timing; the timing adds at most 15%, so a cheating client gains little. A failed swing on a Common lets you try again after two seconds. Rare and above run on a failed swing, which is the tension. When one player starts a swing the stray is locked to them for three seconds, so two people cannot net the same cat.

Bait: buy a bait bowl once, then spend consumable food (Kibble, Tuna, Salmon) at a bait spot. After 45 seconds a stray appears at the bowl with odds shifted toward higher rarities by the food tier. It is calm (+20% catch chance), never runs from you, and stays reserved for you until you catch it or it despawns after 90 seconds, in which case the food is refunded. Food odds are shown as percentages before you buy, from day one, so a later Robux cash pack cannot break the paid random items rules: a bought random outcome has to be delivered, and this rule delivers it. Bait works by day or night.

Rescue: at night some cats turn up stuck, in a tree, a box or a drainpipe, at rescue spots. Walk up and hold for four seconds. There is no swing and no chance to fail, but it takes longer and someone else may get there first. Rescue odds lean Rare, and a rescued cat earns 10% more tips because it is grateful. This is the kind catch, and the one a younger player can always complete.

Waves: at night start each area spawns six strays at once from its own odds table, with better odds in the park than the alley. First to catch wins.

Carry: a caught cat rides in your arms at 80% walk speed until you check in at your cafe door, which puts it in your cat room. This is the moment friends see your Legendary. No stealing during carry at launch.

Areas in the slice: Alley (free) and Park (unlocks at cafe level 3 for 1,000). After the slice: Woods, Rooftops and Harbor, each with a cat found only there.

## Customers

Customers are the visual proof that the cafe is working. They come by day only. Each table seats two. Customers walk in, sit for 20 to 40 seconds, drop coin effects at a pace that matches your income and leave. In the slice they do not change the math: income is cats times the cafe multiplier. A demand model where customers cap income is a Phase 3 experiment if the economy feels flat.

## Upgrades

| Group | What it does | Slice content |
|---|---|---|
| Cafe level | Opens spots and gates other upgrades | Levels 1 to 5 |
| Tables | +10% tips each and two more customers | Up to 6 |
| Espresso machine | +15% tips per level | Levels 1 to 3 (5 at launch) |
| Decor | Small tip bonuses, visible changes | Plants, rug, neon sign, fish tank |
| Tools | Net +10% catch chance per level, bait bowl, food | Net 1 to 3, bowl, 3 foods |
| Areas | Access to better spawns | Park |

Cafe multiplier = 1 + 0.10 per table + 0.15 per espresso level above 1 + decor bonuses. Everything is additive inside the multiplier so income cannot run away.

## Economy

Start with 50 cash and a Tabby on the counter earning 1.5 per second. The first purchase, Table 1 at 100, lands inside two minutes. Cafe level 2 at 250 opens the third spot at about minute three. Cafe level 5 at 8,000 takes roughly 45 to 60 minutes of play with a mixed collection earning 8 to 12 per second. Offline earnings run at 25% of your rate for up to one hour and are claimed with a popup on return. Duplicate cats sell for 25, 150, 600 and 3,000 by rarity.

## The first ten minutes

1. Spawn inside your cafe. Tabby is already on the counter. A toast shows the rate.
2. An arrow points to the back door. The alley has a Common stray waiting at a guaranteed spawn even by day. Hold to wind up the net, learn the ring, catch, carry back, check in. The first night arrives by minute two and brings a full wave.
3. Prompt to place it on the window spot. The rate rises. Prompt to buy Table 1.
4. Free play. Second catch, cafe level 2, a third cat placed, decor or gloves bought.
5. Minute 10 target: 3 cats placed, 2 tables, cafe level 2 or 3. That is one full loop and the Phase 2 exit test.

## Social

Shared spawns and the race for rares. A server-wide announcement when anyone catches an Epic or Legendary. Walk into any cafe on the street to see its cats. Leaderboards for tips per second and cats found. No stealing, no trading and no player text beyond Roblox chat at launch.

## Monetization

Nothing in the slice. At soft launch, per the growth thread's monetization.md: four cosmetic and convenience passes (Long Nap raises the offline cap to two hours, Second Cat Room, VIP Decor Set, Cat Accessories), free private servers and no cash product. A 2x Tips pass is deferred until two weeks of soft launch data. No Robux path to a random cat. A coins product is a Phase 5 decision: if it ships, lure food becomes a paid random item, so the food odds are already on screen, lured strays are already guaranteed to the player who lured them, per-cat odds are equal within a rarity (stated in the shop), and the cash product itself is hidden from players whose policy restricts paid random items, so their coins are all earned and luring stays open to them.

## Genre-standard features

The features players expect from Steal an Egg and Roll a Fisherman style games (night cycle, server events, variants, index rewards, playtime and daily rewards, codes, rebirth, merging, luck buffs, daily quests, a rotating shop, passes) are mapped onto the cafe in [common-features.md](common-features.md) with a phase each. None of them change the slice loop; the alpha gets Closing Time, Cat Parade, variants, set rewards, Sneakers, Tip Jar, the friend bonus and Shoulder Cat, and the launch gets Renovate, Nap Pod, Daily Treat, codes, Catnip, Customer Requests and the Adoption Van.

## Vertical slice scope

In: one street with 8 plots, Alley and Park, the day and night clock with night waves, 12 cats, 6 spot types, cafe levels 1 to 5, the upgrade list above, net, bait and rescue, carry and check-in, cosmetic customers, collection book, selling duplicates, offline earnings, data saving, tutorial beats, analytics events.

Out: stealing, trading, naming cats, free decor placement, variants and merging, secret and seasonal cats, Woods and beyond, prestige, game passes, the customer demand model, friends list features.

| System | Size | Riskiest part |
|---|---|---|
| Street, plots, areas (graybox) | S | Spawn point placement |
| Spots and cat placement | M | Replicating placed cats cheaply |
| Income, upgrades, cafe multiplier | M | Balance, not code |
| Day and night clock, lighting, night waves | S | A new player idle by day: the tutorial stray and bait cover it |
| Net (grab) | M | Two players on one cat, hold input on touch |
| Bait and food | S | Griefing bait |
| Rescue | S | Rescue spots need props |
| Carry and check-in | S | Can be cut without breaking the loop |
| Cosmetic customers | S | Pathfinding cost across 8 cafes |
| Collection book, cat room, shop UI | M | Mobile layout |
| Data saving with session lock | M | Data loss, the costliest failure |
| Offline earnings | S | Clock trust |
| Tutorial and first-time flow | S | Skipping it on repeat joins |
| Analytics events | S | None |

Total is a 4 to 6 week slice for one builder with agents, which matches the plan.

## Risks

- Night-only waves. If days feel empty in the alpha, add a small daytime trickle of Commons. Bait already works by day.
- Fun without stealing. The sketch dropped stealing to avoid griefing. If the friends alpha feels flat, the escape hatch is an opt-in raid mode during carry, not base stealing.
- Catch feel. The timing ring has to feel good on touch and the server decision has to arrive fast. Prototype this first.
- Content cost. Forty cats is cheap only if the one-rig rule holds. The asset thread must prove it with the first three cats.
- Data loss. Session locking and retries before any public test.
- Economy flatness. A single multiplier and flat rates per rarity are easy to tune but can feel samey. Variants and per-cat tuning are the fix, after the slice.
- Policy. Keep the Robux-to-random path closed until the monetization-policy skill exists.

## Open questions

1. Name. Purr Pot is a placeholder.
2. Server size: 8 plots keeps spawn competition friendly. Go to 12 if the street feels empty.
3. Target age band, which decides whether a missed grab scares a cat away for everyone or just ends your attempt.

Settled 2026-10-25: Cozy Cream is the art style (Derek: cozy game vibes). No stealing and no trading for now, revisit after the friends alpha.

Waiting on Gavin (2026-10-26): the twenty questions in [questions-for-gavin.md](questions-for-gavin.md), above all night length, whether tips pause at night, what the manager does by day, what rescue means to him, upright working cats, and whether rebirth is in the first version.
