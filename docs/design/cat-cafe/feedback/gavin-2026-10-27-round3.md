# Gavin's answers, round 3, questions 1 to 6 (2026-10-27)

The first six round 3 questions were answered on the bullets under them in the Cat Cafe tab of the Game Ideas Google Doc. Derek relayed it on 2026-10-27 at 19:20 UTC: "first 6 questions answered take that feedback save it and delete the questions and rest of questions left will be round 4". The questions below are the ones in the doc; each answer is copied word for word from its bullet. Q4 was answered by Derek earlier the same day. Questions 7 to 22 move to round 4 in [questions-for-gavin.md](../questions-for-gavin.md). Round 2 is in [gavin-2026-10-27.md](gavin-2026-10-27.md) and round 1 in [gavin-2026-10-26.md](gavin-2026-10-26.md). What changed in the design because of these answers is in [data-model.md](../data-model.md) (v0.8 notes), [features.md](../features.md) section 2f and docs/decisions.md.

## Questions and answers

### Shove

**Q1. Shoving mid-catch.** Can you shove someone while they are in the middle of a catch or a rescue? Our plan: no, they are safe until it ends, so nobody gets shoved into a miss.

> No, maybe make it so players are knocked away from the person who caught it or give them a temporary speed boost when captured so whoever catches has a good chance of getting home.

**Q2. Shoving a carrier.** Does a shove knock a carried cat loose? Our plan: yes. The carrier gets the first 8 seconds to net it back, and the shover can never catch that cat.

> if you manage to shove a player the cat drops they get knocked a bit back then anyone can hold e to pickup no timer needed and then the original catcher can get push them back to get it.

### Catching

**Q3. The chase.** After a miss the cat sprints off, about 12 studs (two player heights) for a Common up to 32 studs (six player heights) for a Mythical, faster than you can walk, then stops for a second and a half so you can try again. Is that "for a bit", or should rarer cats run farther or hide?

> double those amounts for both. Think of some failure repercussions for the player that failed the catching workout fking over the players that have not tried catching the pet yet. Possibly announce if a mythical has spawned in an area on the day reset and wipe all cats during night to refresh which can be found.

### Cats

**Q4. Shiny colours.** Every cat gets its own shiny coat. Which style: A Frost (silver blue), B Gold, C Lavender or a completely different colour for each cat? Our plan: A, Frost. (Picture: the Tabby as normal, then A, B and C, left to right.)

> Answered by Derek (2026-10-27): B, Gold. "change shiny to gold and make it gold modeled"

### Dealer

**Q5. Shared stock.** Everyone sees the same three foods. Can each player buy each food once per restock (our plan), or is there a limited amount that everyone races for?

> stock is per player and same items are rolled globally across all servers might role 0 of an item or a couple rarer the item the less odds and more expensive, resets every 5 min. So if one 5 min reset has 1 rare cat food and 0 common cat food or something then all servers have that per player.

### Cafe

**Q6. Night.** At night the cafe shows Closed, customers go home and your working cats nap at their stations while still earning 60%. Good?

> lets do earn the same but no customers some sort of night event or bonus speeding up of the cat food that's set outside cafe as bait or night market shop. During day customers that leave tips (base it on money per min for scaling) can leave a good chunk of your revenue and rarer customers like cat collector might offer items for a certain one  of your cats that are not equipped or locked in return for rare items like cosmetic crates (the rarer the cat the better the item and gold rarities even better have some sort of value calculated based on rarity and gold version calculation that can roll better rewards he might offer the better it is) or rich visitors that give bonus cash a good chunk of it, and mysterious visitors that might give potions or other things

## How we read them

- Q1: the catch and rescue lock stays. On a successful catch or rescue, other players next to the catcher are pushed back and the catcher gets a short speed boost. The answer says "or"; we do both because they are small and work together.
- Q2: a shove always drops a carried cat (no half chance) at the carrier's feet, the carrier is pushed back, and anyone, the shover included, picks it up with the same hold E, without circles or an owner window. The cooldowns already in place let the original catcher shove back once.
- Q3: "double those amounts for both" is read as double the run for every rarity (Common and Mythical both, 24 up to 64 studs); the rest stays 1.5 s. The repercussions land only on the player who missed: a wait on that cat that grows with each miss and a short slow. "On the day reset" is read as the wave refresh: strays are already wiped and respawned at each night start, and a Mythical in a new wave is now announced to the server.
- Q5: every window rolls a count of each of the four dealer foods (rarer foods roll fewer and more often none), the same on every server; each player can buy up to that count. The window drops from 10 to 5 minutes.
- Q6: night pays 100% with no customers, and food set in the bait bowl at night is ready in half the time (the night dealer is already our night market). By day, customers leave tip piles worth a share of your rate and rich visitors pay more. Two new visitors come too: the Cat Collector offers a reward for one of your resting, unlocked cats, and the Mystery Visitor leaves a potion or another small gift. Cats get a lock so the Collector and selling never touch a favourite.
