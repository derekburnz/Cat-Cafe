# Cat Cafe Game Design Doc

Draft v0.10, 2026-10-27 (v0.10 after the round 4 answers in [feedback/answers-2026-10-27-round4.md](feedback/answers-2026-10-27-round4.md) and Derek's Codes Cat stand; v0.9 makes night a 90 second reset with the areas closed, from Derek; v0.8 after Gavin's round 3 answers 1 to 6 in [feedback/gavin-2026-10-27-round3.md](feedback/gavin-2026-10-27-round3.md) and Derek's Codes Cat; v0.7 the golden fish, crates and Index rewards in [golden-fish.md](golden-fish.md), okayed by Derek; v0.5 after Gavin's round 2 answers in [feedback/gavin-2026-10-27.md](feedback/gavin-2026-10-27.md); v0.1 on 2026-10-25, v0.2 after Gavin's Cat Cafe tab, v0.3 after Gavin's answers to our twenty questions, v0.3.1 with the reviewer's bump, dealer, rescue and save fixes, v0.4 after Derek played the rough draft: misses cost the catch, the Alleyway behind the cafes, lively cafes, For Rent plots and borrowed UI patterns, detailed in [world-and-feel.md](world-and-feel.md)). Owner: game-designer thread. Status: ready for the engineer, asset and UI threads to build. Derek, 2026-10-26: "lets start with those mechanics and see where it goes from there". Every number is a first guess to tune in playtests. Full tables are in [data-model.md](data-model.md), the build order and thread handoffs in [features.md](features.md), genre-standard features for later phases in [common-features.md](common-features.md), Gavin's answers word for word in [feedback/](feedback/) (round 1 2026-10-26, round 2 2026-10-27), the next questions for him in [questions-for-gavin.md](questions-for-gavin.md), and decisions in [docs/decisions.md](../../decisions.md).

Reference games: Steal an Egg (timed spawns in shared stages, place-and-earn pets, chasing players who carry eggs) and Roll a Fisherman, also called Spin for a Fisherman (roll for staff, collect what they produce, expand the dock). We borrow the structure, never the names, art or characters. Gavin keeps "Cat Cafe" as the placeholder name for now (round 2); the working title stays Cat Cafe and the repo slug `cat-cafe`.

## Pitch

A cozy cat cafe tycoon where the cats do the work and you do the collecting. Strays roam five areas around your street: the Alleyway, the Park, the Neighbourhood, the Woods and the Sewer. You catch them with a net and a quick timing game, rescue the ones stuck in bins and trees, or leave food in your bait bowl and see who turns up. Carry each one home, give it a job (Barista, Waiter, Greeter or Entertainer) and watch it sit down at its station in its uniform and start earning. Tips buy tables, decor and a better net, and ranking your cafe up through five tiers opens the next area. Fifty cats to find, ten per area, each with a gold version.

## Core loop

- By day (5 minutes): cats serve and customers leave tip piles on the tables for you to collect, rich visitors drop big tips, the Cat Collector and the Mystery Visitor sometimes call, you assign cats to roles, buy upgrades, set bait and hunt the fresh wave of strays that came at sunrise. A cat you let go with Drop walks back to where you caught it, and anyone can pick it up on the way (round 4).
- By night (90 seconds since v0.9): the catching areas close and send everyone home, the mysterious food dealer opens his cart in the plaza, bait set now is ready in half the time and the cafe closes but keeps earning the full rate while the cats nap. At sunrise a fresh wave of ten strays fills every area and cats wait in traps to be rescued. By day, net or rescue a cat, carry it home without getting shoved and check it in.
- Every session (10 to 15 minutes): one or two nights, two to four cats, a role filled, an upgrade or two, a bait cat waiting when you come back.
- Over weeks: rank up from Tier 1 to Tier 5, open all five areas, fill the Index of 50 and the gold Index.

The player is the manager. There is no manager avatar or NPC in the cafe (Gavin, Q11): the hands-on jobs are catching, rescuing, assigning, upgrading and ranking up, and the cats do the rest.

Q17 (anything missing from the main loop) is still open with Gavin; the loop above is what we build until he says otherwise.

## The street and the cafe

Each player owns one cafe plot on a shared server of 8 players, along one street. v0.4: every cafe's back door opens onto the Alleyway, two back alleys behind the rows that meet in a big Alley Square, so the first area is seconds away. The other four areas open off the street and the Square through gates, and travel buttons at the top of the screen take you to any unlocked area unless you are carrying a cat. Areas are shared, so everyone sees the same strays and first to catch wins. An area you have not unlocked shows a gate with what you still need; you can look in but not catch there.

Cafes look like the concept sketch and feel busy: a proper roof, big windows you can see the cats through, an awning, a name sign with your avatar and your tips per second, and customers queueing and leaving hearts. Up to four of your jobless cats nap around the room. Each tier adds pieces you can see from the street. Empty plots are closed shops with shutters and a For Rent sign, never grey boxes.

A cafe has role slots instead of the v0.2 spots: Barista at the counter, Waiter by the tables, Greeter at the door, Entertainer on the cat tree. Tier 1 opens two slots (Barista and Waiter) and Tier 5 opens ten. Cats without a role rest in the cat room on all fours and earn nothing. Every cat can do every role, and each cat has one favorite role where it earns 1.5 times as much (Gavin, Q12, with role boosts for specific cats later). Equip Best fills the slots with the best cats in one tap.

Customers come and go as the visual proof the cafe works: a full house by day. At night the cafe is closed (Gavin, round 2): no customers, the sign says Closed and the working cats nap at their stations, earning the same as by day since round 3. By day customers change the math through their tip piles and the visitors below.

## Tiers (replaces cafe level and Renovate)

Gavin, Q18: instead of a rebirth, a tier you rank up to by meeting a prerequisite. Nothing resets. Each rank up spends coins and needs a number of different cats caught, and from Tier 3 a cat of a given rarity. Each tier opens more role slots, a bigger cafe, a higher income multiplier, more decor and shop levels and the next area.

| Tier | Name | Rank up needs | Opens |
|---|---|---|---|
| 1 | Corner Cafe | start | Alleyway, Barista and Waiter, 2 tables |
| 2 | Cozy Cafe | 1,500 coins, 5 different cats | Park, 4 slots, x1.25 income, 4 tables, plants and rug |
| 3 | Busy Cafe | 8,000 coins, 12 different cats, any Epic | Neighbourhood, 6 slots, x1.5, 6 tables, neon sign |
| 4 | Famous Cafe | 30,000 coins, 20 different cats, any Legendary | Woods, 8 slots, x1.75, fish tank, patio |
| 5 | Grand Cafe | 120,000 coins, 30 different cats, two different Legendaries | Sewer, 10 slots, x2.0 |

Whether ranking up spends the coins or only needs you to hold them is a round 2 question; we build "spend" because the cafe needs a coin sink.

## Cats

Fifty cats, ten per area: four Common, two Rare, two Epic, one Legendary and one Mythical (Gavin, Q5 and Q14). Every area can spawn every rarity, and later areas tilt the odds upward. Each cat lives only in its own area, and several of the same cat can be out at once there (Gavin confirmed in round 2). The slice builds the Alleyway and Park cats (20); the other thirty have provisional names in the catalog and arrive with their areas.

| Rarity | Base tips per second | Net circles | Notes |
|---|---|---|---|
| Common | 1 | 1 | Never runs away |
| Rare | 3 | 2 | Runs on a failed catch |
| Epic | 8 | 3 | Runs on a failed catch |
| Legendary | 25 | 4 | Runs on a failed catch |
| Mythical | 75 | 5 | New top rarity, replaces the old Secret tier |

Per-cat stats stay as built: charm (rolled at catch, 0.8x to 1.2x), level from time spent working (up to 1.45x) and the star rating.

Gold cats (Gavin, Q16 and round 2; called shiny until Derek renamed them on 2026-10-27): every cat has a gold version that earns 1.5 times as much and sparkles (Derek picked gold on 2026-10-27). A gold cat turns up 5% of the time from the net and bait and 10% from a rescue. Gold strays sparkle on sight, so the race for them is visible; whether a rescued cat is gold is a surprise when it comes out. The Index has a gold page. There is no merging of duplicates, and Golden and Galaxy variants are dropped. Duplicates still sell for coins.

Names (Q16): players can name their cats. Names go through Roblox's text filter before anyone else can see them.

Look (Q15, updated by Derek's body picks on 2026-10-27): strays walk on all fours (body A) and look like strays. A cat with a role sits at its station on the seated body (B) in that role's two-piece outfit: Barista apron and cap, Waiter bow tie and vest, Greeter sash and straw hat, Entertainer party hat and cape. It used to stand upright, but that pose looked bad. The cat room shows them relaxing without the outfit. All fifty share the two bodies with pattern, color and prop variants.

## The clock

The server runs a 10 minute loop: 5 minutes of day, 5 minutes of night (Gavin, Q1). Since v0.9 (Derek: night is "mostly just to reset cat spawns") night lasts 90 seconds: at dusk the catching areas close, everyone in them is sent home with any cat they carry checked in, and at sunrise a fresh wave fills every area, so you hunt by day and spend the short night at the cafe and the plaza. The rest of this paragraph is the v0.3 loop. At every night start each unlocked area spawns a fresh wave of ten strays and the uncaught ones from last night vanish; leftovers stay catchable by day until then (Q2). A new server starts two minutes before its first night so a new player meets one early. Bait ignores the clock.

## Catching

Three ways, from Gavin's list, plus the carry home.

Net (Q6): walk up to a stray and start a catch. Closing circles pop up one after another: one for a Common, up to five for a Mythical. The rarer the cat the faster they close. Press as each circle meets its ring. Each press is Perfect, Good or Miss. v0.4 (Derek: missing has to matter) and v0.5 (Gavin, round 2): the first Miss ends the catch and the cat sprints away, farther the rarer it is, so you have to chase it down before you can try again. Tries are unlimited for every cat, and anyone can have the next go once it stops. Since round 3 (Gavin, Q3) it runs twice as far, and only the player who missed pays for it: they wait a little longer after each miss in a row and are slowed for two seconds, while everyone else can try at once. Every circle Good or Perfect is a sure catch, and each Perfect makes the cat a little more charming, double for an all-Perfect Purrfect. Your net decides how wide the Perfect and Good windows are and how steady the circle speed is. With the basic net a Mythical's five quick, uneven circles mean several tries and chases; a Master net makes them fair. The server sets the circle timings and judges every press on its own clock, so a modified client cannot claim a perfect it did not get.

Rescue (Q8): at night some cats are stuck in traps that fit their area. In the Alleyway they are in trash bins and garbage bags, in the Park up trees and in trash cans; the other three areas get their own traps when they are built. A rescue is a short minigame: stop a sliding marker in the target zone a few times, or for a tree, shake the branch and catch the cat with one closing circle. The rarer the cat, the more hits, the narrower the zone and the faster the marker. A failed rescue never loses the cat: it stays stuck and you or anyone else can try again a few seconds later. A rescued cat has a 10% gold chance, five times the net's.

Bait (Q7): buy a bait bowl for your cafe once. It sits outside on your back step facing the Alleyway (Gavin, round 2). Put food in it at any time of day. Ten minutes later a cat is sitting at the bowl eating, even if you logged off in between. You see exactly which cat it is and choose Tame (it joins your cafe, no catch needed) or Let go. The food is used either way. Better food gives better odds, and the odds are on the shop card before you buy, so lure food already meets the paid random items rules if coins are ever sold for Robux.

Night food dealer (Q10): a mysterious dealer parks his cart on the street every night and leaves at dawn. He sells rare foods with better odds than the shop, including the only foods with a real Mythical chance. Since round 3 every restock, every 5 minutes of real time, rolls how many of each of his four foods he has, from none to a few, with the rarer foods rolling fewer and more often none. The amounts are the same on every server, and each player can buy up to that many, whatever anyone else buys (Gavin, round 3 Q5). The stock is shown before you buy, so nothing about the cart is a paid random item.

Carry and shove (Q9, round 2 Q3): a caught or rescued cat rides in your arms at 80% walk speed until you check in at your cafe door. You can carry one cat at a time. Inside the catching areas players can shove each other, carrying or not; the street and the cafes are safe. Since round 3 (Gavin, Q1 and Q2) a catch pushes nearby players back and gives the catcher five seconds of extra speed to get a head start, and a shove that lands on a carrier always drops the cat at their feet. Anyone can then pick it up with the same half-second hold of E, no circles and no timer, and the old carrier can shove back to take it home. A dropped cat never leaves its area and stays for at least two minutes, even if a new night starts. This replaces the v0.2 "no stealing" rule, with protections so it stays playful for an everyone audience: no knock-loose in the first three seconds of a carry or near the carrier's own cafe, no shoving someone in the middle of a catch or rescue, and a cooldown per shover and per target, which ends a tug of war after one shove back. Baited cats are tamed at home and are never carried.

## Income and customers

Income is the sum of each working cat's rating, times 1.5 on its favorite role, times the cafe multiplier from tables, espresso and decor, times the tier multiplier. Tips keep flowing at night at the full day rate (round 3 Q6, was 60%), and day adds the tip piles, rich visitors and visitors, so day is still when the cafe is busiest.

Rich customers (Q10): now and then by day a rich customer visits and leaves a big tip worth 2 minutes of your income (round 3, was 45 seconds). Tap the tip pile to collect it, or it drops into the till when they leave, so nobody loses out by being busy in the alley.

Offline earnings stay: 25% of your day rate for up to one hour, claimed with a popup on return.

## Upgrades

| Group | What it does | Content |
|---|---|---|
| Tier | Slots, areas, income multiplier, unlocks | Tiers 1 to 5 by rank up |
| Tables | +10% tips each and two more customers | Up to 6, capped by tier |
| Espresso machine | +15% tips per level | Levels 1 to 5, capped by tier |
| Decor | Small tip bonuses, visible changes | Plants, rug, neon sign, fish tank |
| Net | Wider Perfect and Good windows, steadier circles | Basic plus 3 upgrades, capped by tier |
| Bait bowl | Enables bait at your cafe | One bowl |
| Food | Bait consumables | Kibble, Tuna, Salmon in the shop; four rare foods from the dealer |

## Economy

Start with 50 coins and a Tabby as Barista earning 1.5 per second. Table 1 at 100 lands inside two minutes. Tier 2 at 1,500 coins and five different Alleyway cats lands around minute 10 to 15, which opens the Park. Tier 5 is a long goal of several hours. Duplicate cats sell for 25, 150, 600, 3,000 and 12,000 by rarity.

## The first ten minutes

1. Watch the intro, about 26 seconds with Skip after 5 (F72, [intro-cutscene.md](intro-cutscene.md)), then start inside your cafe by the back door. Tabby is already behind the counter in an apron. A toast shows the rate.
2. An arrow points to your back door. A Common stray is waiting right behind your cafe even by day. Start a catch, hit the one circle, carry it back, check in.
3. Give it the Waiter job. It sits at its station in a bow tie and vest and the rate rises. Prompt to buy Table 1.
4. Prompt to buy the bait bowl and put Kibble in it: "a cat will come by in 10 minutes".
5. The server opens at sunrise with ten strays in every area and a stuck cat in a bin (v0.9; the first night used to bring them at minute two). Rescue it.
6. Minute 10 target: three or four different cats, two roles filled, two tables, a bait cat on the way, the Tier 2 card showing what is left. That is one full loop and the Phase 2 exit test.

## Social

Shared spawns and the race for rares and gold cats. Shoving in the catching areas and knocking a carrier's cat loose. A server-wide announcement when anyone catches an Epic, Legendary, Mythical or any gold cat. Walk into any cafe to see its cats at work under their names. Leaderboards for tips per second and cats found. No trading and no player text beyond Roblox chat and filtered cat names at launch.

## Monetization

Nothing in the slice. At soft launch, per the growth thread's monetization.md: cosmetic and convenience passes, free private servers and no cash product. No Robux path to a random cat. If any Robux product that grants coins ever ships, lure food (shop and dealer) becomes a paid random item: its odds are already on every card, a baited cat is always delivered to the player who set the bait, per-cat odds are equal within a rarity and stated, and the cash product is hidden from players whose policy restricts paid random items. The dealer's stock roll is free and shown before purchase, so it is not a paid random item. No Robux to speed up bait or skip the 10 minute wait.

v0.10 (round 4 Q14: "We will make a monetization agent that will do research and decide what to add and what sells well"; Q15: "Not just looks everything should be possible to obtain in game like cosmetics/cats/items but p2w should also be fine to be not just cosmetic"): a future monetization agent decides what to sell. Robux items no longer have to be looks only and may help a player, but everything sold must also be obtainable by playing, nothing may wall off the core loop and anything random still follows the paid random items rules (monetization-policy). This supersedes the round 4 Q15 plan that decor packs would be looks only.

## Genre-standard features

The features players expect from Steal an Egg and Roll a Fisherman style games are mapped onto the cafe in [common-features.md](common-features.md) with a phase each. v0.3 pulls three of them into the slice: gold variants (in place of Golden and Galaxy), tiers (in place of Renovate) and carry bumps (in place of the opt-in raid fallback). The Nap Pod (merging) is dropped.

## Vertical slice scope

In: one street with 8 plots, the Alleyway and the Park with their 20 cats, Neighbourhood, Woods and Sewer as gated grayboxes, the 5 and 5 minute clock with waves of ten, tiers 1 to 5, four roles with favorite-role pay and seated workers in role outfits, Equip Best, the closing-circle net with three upgrades, rescue minigames with Alleyway and Park traps, the bait bowl at your cafe with Tame or Let go, carry with shoves, gold cats, naming cats, night income at 60%, rich customers, the night food dealer, the collection and gold Index pages, selling duplicates, offline earnings, data saving, tutorial beats, analytics events.

Out: trading, the 30 cats of the last three areas (provisional names only), role boosts for specific cats, free decor placement, patio and second floor content, game passes, a coins product, friends list features.

| System | Size | Riskiest part |
|---|---|---|
| Catalog v3, profile v3 migration | M | Migrating v2 saves without loss |
| Tiers and rank up | M | Requirement checks and balance |
| Roles, uniforms, Equip Best over 10 slots | M | Swap to the seated body with the outfit when assigned |
| Net circles (server schedule, press judging) | M | Feel on touch and latency fairness |
| Rescue minigames | M | Two minigame kinds and their props |
| Bait bowl with an offline timer | S | Rolling the cat at placement so rejoining cannot reroll |
| Carry and shove | M | Griefing; must be easy to switch off |
| Gold | S | None |
| Night income, rich customers | S | Settling income across a phase change |
| Night food dealer | M | Stock that cannot be rerolled by rejoining |
| Naming cats | S | Text filter failures |
| Areas 3 to 5 grayboxes and gates | S | Server checks for locked areas |

## Risks

- Net timing exploit. Gavin wants all-Perfect to be 100%, and v0.4 makes any run without a Miss a sure catch, so a script that presses on time catches anything. The server judges presses on its own clock against a schedule it sets, which stops forged results but not a perfect auto-presser. Supply is the real limit (ten strays per area per night, shared). The server flags accounts whose Perfect rate stays above 95% over 50 or more circles; a flagged account gets no Perfect charm bonus until it drops to 85%, and nothing else is taken away. Reviewer signed off on the v0.3 net on 2026-10-26; v0.4 goes back to the reviewer.
- Shove griefing. Shoves are the first player-versus-player contact in the game and the audience is everyone, and v0.5 lets anyone in a catching area be shoved, not only carriers. Protections are in the catching section, there is a server switch to turn shoves off and the friends alpha decides whether they stay.
- Ten minute bait. Long enough to feel like a timer game. The tutorial says up front that the cat will be there when you come back, and the timer runs offline.
- Scope. Fifty cats, five areas, two rescue minigames and a dealer is a lot for one builder. The slice builds two areas of content and grayboxes the rest, and everything else is one feature per branch.
- Catch feel. Circles have to feel good on touch, and a Miss sends the cat running, so an unfair Basic Net window on a phone would feel bad. Widen `good` before anything else if QA finds it mean.
- Performance. Lively cafes times eight on a phone. Culling distances and the roaming cat cap are in world-and-feel.md section 4.
- Economy. Tier costs, night income and dealer prices are guesses; QA's loop script measures minute-10 and Tier 2 timing.
- Data loss. Session locking is built; the v3 migration needs a test against real v2 saves.

## Open questions

Rounds 2, 3 and 4 are answered (feedback/gavin-2026-10-27.md, feedback/gavin-2026-10-27-round3.md and feedback/answers-2026-10-27-round4.md). The next questions, for Derek or Gavin, are Set 4 in [questions-for-gavin.md](questions-for-gavin.md): shoved cats walking home, second props and swaps for the later areas, one thing to do per area, the Daily Treat and Tip Jar prizes, the Index bonus kinds, the group code, potions for fish and when the monetization agent starts.

Settled 2026-10-25: Cozy Cream art style (Derek: cozy game vibes). No trading. Settled 2026-10-26 by Gavin's answers and Derek's go-ahead: everything in v0.3 above, including carry bumps in place of the no-stealing rule. Settled 2026-10-27 by Gavin's round 2: unlimited tries with a chase after a miss, Shove in place of Bump, the bowl outside, a special coat for every cat at 5% (now gold cats), spending coins to rank up, the cafe closed at night at 60%, one shared dealer stock, area-unique cats, "Cat Cafe" as the placeholder name. Settled 2026-10-27 evening by Gavin's round 3 answers 1 to 6: no shoving mid-catch with a getaway after a catch, a shove always drops the cat for anyone to pick up, a chase twice as long that costs only the player who missed, Mythical wave announcements, dealer amounts per food every 5 minutes, full pay at night with faster night bait, day tip piles, bigger rich visitors, the Cat Collector and the Mystery Visitor; and by Derek: golden fish, Cafe Crates and the Index rewards (v0.7), and the Codes Cat. Settled by the round 4 answers: the half second hold, one miss ends a catch, 1 to 5 circles by rarity, the safe zone at the stripes, a dropped cat walks home and can be picked up on the way, one or two props per themed cat, every working cat shows its job, gold Legendary and Mythical effects turn gold, no cats from spins, food rarity badges and a Spin odds button, bigger Daily Treat and Tip Jar prizes, a bonus kind per Index track, the `launch` and `group` codes, the 18 later area cats, and Robux items that may help a player as long as everything can be earned; and by Derek: the Codes Cat on a stand with a walk-in circle.
