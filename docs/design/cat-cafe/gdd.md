# Cat Cafe Game Design Doc (working title Purr Pot)

Draft v0.3.1, 2026-10-26 (v0.1 on 2026-10-25, v0.2 after Gavin's Cat Cafe tab, v0.3 after Gavin's answers to our twenty questions, v0.3.1 with the reviewer's bump, dealer, rescue and save fixes). Owner: game-designer thread. Status: ready for the engineer, asset and UI threads to build. Derek, 2026-10-26: "lets start with those mechanics and see where it goes from there". Every number is a first guess to tune in playtests. Full tables are in [data-model.md](data-model.md), the build order and thread handoffs in [features.md](features.md), genre-standard features for later phases in [common-features.md](common-features.md), Gavin's answers word for word in [feedback/gavin-2026-10-26.md](feedback/gavin-2026-10-26.md), the next questions for him in [questions-for-gavin.md](questions-for-gavin.md), and decisions in [docs/decisions.md](../../decisions.md).

Reference games: Steal an Egg (timed spawns in shared stages, place-and-earn pets, chasing players who carry eggs) and Roll a Fisherman, also called Spin for a Fisherman (roll for staff, collect what they produce, expand the dock). We borrow the structure, never the names, art or characters. Gavin suggested "Cat Cafe" as the name; whether that is final is a round 2 question, and the repo slug stays `cat-cafe` either way.

## Pitch

A cozy cat cafe tycoon where the cats do the work and you do the collecting. Strays roam five areas around your street: the Alleyway, the Park, the Neighbourhood, the Woods and the Sewer. You catch them with a net and a quick timing game, rescue the ones stuck in bins and trees, or leave food in your bait bowl and see who turns up. Carry each one home, give it a job (Barista, Waiter, Greeter or Entertainer) and watch it stand up in its uniform and start earning. Tips buy tables, decor and a better net, and ranking your cafe up through five tiers opens the next area. Fifty cats to find, ten per area, each with a shiny version.

## Core loop

- By day (5 minutes): cats serve and tips flow at the full rate, rich customers drop big tips, you assign cats to roles, buy upgrades, set bait and hunt any stray left over from last night.
- By night (5 minutes): a fresh wave of ten strays appears in every area you have unlocked, cats stuck in traps wait to be rescued, the mysterious food dealer opens his cart and the cafe keeps earning at 60%. Net or rescue a cat, carry it home without getting bumped, check it in.
- Every session (10 to 15 minutes): one or two nights, two to four cats, a role filled, an upgrade or two, a bait cat waiting when you come back.
- Over weeks: rank up from Tier 1 to Tier 5, open all five areas, fill the book of 50 and the shiny book.

The player is the manager. There is no manager avatar or NPC in the cafe (Gavin, Q11): the hands-on jobs are catching, rescuing, assigning, upgrading and ranking up, and the cats do the rest.

Q17 (anything missing from the main loop) is still open with Gavin; the loop above is what we build until he says otherwise.

## The street and the cafe

Each player owns one cafe plot on a shared server of 8 players, along one street. The five catching areas open off the street and are shared, so everyone sees the same strays and first to catch wins. An area you have not unlocked shows a gate; you can look in but not catch there.

A cafe has role slots instead of the v0.2 spots: Barista at the counter, Waiter by the tables, Greeter at the door, Entertainer on the cat tree. Tier 1 opens two slots (Barista and Waiter) and Tier 5 opens ten. Cats without a role rest in the cat room on all fours and earn nothing. Every cat can do every role, and each cat has one favorite role where it earns 1.5 times as much (Gavin, Q12, with role boosts for specific cats later). Equip Best fills the slots with the best cats in one tap.

Customers come and go as the visual proof the cafe works: a full house by day, a few night owls at night. They do not change the math except for the rich customer below.

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

Fifty cats, ten per area: four Common, two Rare, two Epic, one Legendary and one Mythical (Gavin, Q5 and Q14). Every area can spawn every rarity, and later areas tilt the odds upward. Each cat is unique to its area in v0.3 (a round 2 question). The slice builds the Alleyway and Park cats (20); the other thirty have provisional names in the catalog and arrive with their areas.

| Rarity | Base tips per second | Net circles | Notes |
|---|---|---|---|
| Common | 1 | 1 | Never runs away |
| Rare | 3 | 2 | Runs on a failed catch |
| Epic | 8 | 3 | Runs on a failed catch |
| Legendary | 25 | 4 | Runs on a failed catch |
| Mythical | 75 | 5 | New top rarity, replaces the old Secret tier |

Per-cat stats stay as built: charm (rolled at catch, 0.8x to 1.2x), level from time spent working (up to 1.45x) and the star rating.

Shiny (Gavin, Q16): every cat has a shiny version that earns 1.5 times as much and sparkles. A shiny turns up 2% of the time from the net and bait and 10% from a rescue. Shiny strays sparkle on sight, so the race for them is visible; a rescued cat's shininess is a surprise when it comes out. The book has a shiny page. There is no merging of duplicates, and Golden and Galaxy variants are dropped. Duplicates still sell for coins.

Names (Q16): players can name their cats. Names go through Roblox's text filter before anyone else can see them.

Look (Q15): strays walk on all fours and look like strays. A cat with a role stands upright in that role's uniform: Barista apron, Waiter bow tie, Greeter sash, Entertainer party hat. The cat room shows them on all fours. All fifty come from one rig with pattern, color and accessory variants.

## The clock

The server runs a 10 minute loop: 5 minutes of day, 5 minutes of night (Gavin, Q1). At every night start each unlocked area spawns a fresh wave of ten strays and the uncaught ones from last night vanish; leftovers stay catchable by day until then (Q2). A new server starts two minutes before its first night so a new player meets one early. Bait ignores the clock.

## Catching

Three ways, from Gavin's list, plus the carry home.

Net (Q6): walk up to a stray and start a catch. Closing circles pop up one after another: one for a Common, up to five for a Mythical. The rarer the cat the faster they close. Press as each circle meets its ring. Each press is Perfect, Good or Miss, and the catch chance is the average: all Perfect is 100%, all Good is 50%, all Miss is 0%. Your net decides how wide the Perfect and Good windows are and how steady the circle speed is. With the basic net a Mythical's five quick, uneven circles are close to impossible to perfect; a Master net makes them fair. Commons stay put after a failed catch so you can try again; anything rarer runs. The server sets the circle timings and judges every press on its own clock, so a modified client cannot claim a perfect it did not get.

Rescue (Q8): at night some cats are stuck in traps that fit their area. In the Alleyway they are in trash bins and garbage bags, in the Park up trees and in trash cans; the other three areas get their own traps when they are built. A rescue is a short minigame: stop a sliding marker in the target zone a few times, or for a tree, shake the branch and catch the cat with one closing circle. The rarer the cat, the more hits, the narrower the zone and the faster the marker. A failed rescue never loses the cat: it stays stuck and you or anyone else can try again a few seconds later. A rescued cat has a 10% shiny chance, five times the net's.

Bait (Q7): buy a bait bowl for your cafe once, then put food in it at any time of day. Ten minutes later a cat is sitting at the bowl eating, even if you logged off in between. You see exactly which cat it is and choose Tame (it joins your cafe, no catch needed) or Let go. The food is used either way. Better food gives better odds, and the odds are on the shop card before you buy, so lure food already meets the paid random items rules if coins are ever sold for Robux.

Night food dealer (Q10): a mysterious dealer parks his cart on the street every night and leaves at dawn. He sells rare foods with better odds than the shop, including the only foods with a real Mythical chance. Each player sees three stock slots that restock every 10 minutes of real time, the same on every server, each bought once per restock. The higher your tier the better his rolls. The stock is shown before you buy, so nothing about the cart is a paid random item.

Carry and bump (Q9): a caught or rescued cat rides in your arms at 80% walk speed until you check in at your cafe door. You can carry one cat at a time. On the way home other players can bump you, and half the time it knocks the cat loose: the cat scurries a few steps, you get the first 8 seconds to net it back, and after that anyone except the bumper can try. A knocked-loose cat never runs away for good; it stays until someone catches it or the next night. This replaces the v0.2 "no stealing" rule, with protections so it stays playful for an everyone audience: no bumps in the first three seconds after a catch or near the carrier's own cafe, a cooldown per bumper and per target, the bumper can never catch the cat they knocked loose, and a cat that was knocked loose once cannot be bumped again on its next trip. Baited cats are tamed at home and are never carried.

## Income and customers

Income is the sum of each working cat's rating, times 1.5 on its favorite role, times the cafe multiplier from tables, espresso and decor, times the tier multiplier. Tips keep flowing at night at 60% of the day rate (Q10), so day is when the cafe is busiest.

Rich customers (Q10): now and then by day a rich customer visits and leaves a big tip worth 45 seconds of your income. Tap the tip pile to collect it, or it drops into the till when they leave, so nobody loses out by being busy in the alley.

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

1. Spawn inside your cafe. Tabby is already behind the counter in an apron. A toast shows the rate.
2. An arrow points to the Alleyway. A Common stray is waiting there even by day. Start a catch, hit the one circle, carry it back, check in.
3. Give it the Waiter job. It stands up in a bow tie and the rate rises. Prompt to buy Table 1.
4. Prompt to buy the bait bowl and put Kibble in it: "a cat will come by in 10 minutes".
5. The first night arrives at minute two with ten strays and a stuck cat in a bin. Rescue it.
6. Minute 10 target: three or four different cats, two roles filled, two tables, a bait cat on the way, the Tier 2 card showing what is left. That is one full loop and the Phase 2 exit test.

## Social

Shared spawns and the race for rares and shinies. Bumping a carrier on the way home. A server-wide announcement when anyone catches an Epic, Legendary, Mythical or any shiny. Walk into any cafe to see its cats at work under their names. Leaderboards for tips per second and cats found. No trading and no player text beyond Roblox chat and filtered cat names at launch.

## Monetization

Nothing in the slice. At soft launch, per the growth thread's monetization.md: cosmetic and convenience passes, free private servers and no cash product. No Robux path to a random cat. If a coins product ever ships, lure food (shop and dealer) becomes a paid random item: its odds are already on every card, a baited cat is always delivered to the player who set the bait, per-cat odds are equal within a rarity and stated, and the cash product is hidden from players whose policy restricts paid random items. The dealer's stock roll is free and shown before purchase, so it is not a paid random item. No Robux to speed up bait or skip the 10 minute wait.

## Genre-standard features

The features players expect from Steal an Egg and Roll a Fisherman style games are mapped onto the cafe in [common-features.md](common-features.md) with a phase each. v0.3 pulls three of them into the slice: shiny variants (in place of Golden and Galaxy), tiers (in place of Renovate) and carry bumps (in place of the opt-in raid fallback). The Nap Pod (merging) is dropped.

## Vertical slice scope

In: one street with 8 plots, the Alleyway and the Park with their 20 cats, Neighbourhood, Woods and Sewer as gated grayboxes, the 5 and 5 minute clock with waves of ten, tiers 1 to 5, four roles with favorite-role pay and upright uniforms, Equip Best, the closing-circle net with three upgrades, rescue minigames with Alleyway and Park traps, the bait bowl at your cafe with Tame or Let go, carry with bumps, shinies, naming cats, night income at 60%, rich customers, the night food dealer, the collection and shiny books, selling duplicates, offline earnings, data saving, tutorial beats, analytics events.

Out: trading, the 30 cats of the last three areas (provisional names only), role boosts for specific cats, free decor placement, patio and second floor content, game passes, a coins product, friends list features.

| System | Size | Riskiest part |
|---|---|---|
| Catalog v3, profile v3 migration | M | Migrating v2 saves without loss |
| Tiers and rank up | M | Requirement checks and balance |
| Roles, uniforms, Equip Best over 10 slots | M | Upright pose swap when assigned |
| Net circles (server schedule, press judging) | M | Feel on touch and latency fairness |
| Rescue minigames | M | Two minigame kinds and their props |
| Bait bowl with an offline timer | S | Rolling the cat at placement so rejoining cannot reroll |
| Carry bumps | M | Griefing; must be easy to switch off |
| Shiny | S | None |
| Night income, rich customers | S | Settling income across a phase change |
| Night food dealer | M | Stock that cannot be rerolled by rejoining |
| Naming cats | S | Text filter failures |
| Areas 3 to 5 grayboxes and gates | S | Server checks for locked areas |

## Risks

- Net timing exploit. Gavin wants all-Perfect to be 100%, so a script that presses perfectly catches anything. The server judges presses on its own clock against a schedule it sets, which stops forged results but not a perfect auto-presser. Supply is the real limit (ten strays per area per night, shared). The server flags accounts whose Perfect rate stays above 95% over 50 or more circles. Reviewer signed off on 2026-10-26.
- Bump griefing. Bumps are the first player-versus-player contact in the game and the audience is everyone. Protections are in the catching section, there is a server switch to turn bumps off and the friends alpha decides whether they stay.
- Ten minute bait. Long enough to feel like a timer game. The tutorial says up front that the cat will be there when you come back, and the timer runs offline.
- Scope. Fifty cats, five areas, two rescue minigames and a dealer is a lot for one builder. The slice builds two areas of content and grayboxes the rest, and everything else is one feature per branch.
- Catch feel. Circles have to feel good on touch. Prototype them first after the data change.
- Economy. Tier costs, night income and dealer prices are guesses; QA's loop script measures minute-10 and Tier 2 timing.
- Data loss. Session locking is built; the v3 migration needs a test against real v2 saves.

## Open questions

Round 2 for Gavin is in [questions-for-gavin.md](questions-for-gavin.md): the main loop, how bumps should feel, where bait goes, spending versus holding coins to rank up, the role list, shiny numbers, night pay, area-unique cats, the dealer's stock, the name and the circle scoring.

Settled 2026-10-25: Cozy Cream art style (Derek: cozy game vibes). No trading. Settled 2026-10-26 by Gavin's answers and Derek's go-ahead: everything in v0.3 above, including carry bumps in place of the no-stealing rule.
