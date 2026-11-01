# One extra thing at each camp (F100)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek's Set 4 Q4 answer (2026-10-29): "I like the idea and its def a good thing it might get annoying to cannon to each location to checkout whatever the benefits are so rethink a way of unlocking and using those new features without making the cannon teleporting between locations tedious, if the cannon between is fast then it wouldn't be terrible and can show the little feature of each area in the menu and clean it up if needed if not plan out some other possible options on how to have unlocks with every or every couple new tiers." His release rule of 2026-11-01 22:59 puts it before release.

## 1. The rules that keep it from being a chore

- **One new thing per tier.** Each area from the Park on gets one extra at its camp, opening with the area, so every rank up from Tier 2 to Tier 5 opens a new one. The Alleyway has none, so a new player's first area stays simple.
- **The cannon menu says what is waiting.** Every card in the cannon picker (hometown-cannon.md section 3) gets one line under "7/10 cats" with the extra's icon and state, and a "!" only when something is ready to claim (Derek's rule for "!"). So nobody flies anywhere to check.
- **Nothing is lost by waiting.** Each extra keeps filling while the player is away or offline, up to a cap that is at least six hours, so twice a day is enough to get everything. The flight is 3 seconds and you go to these areas to catch anyway.
- **No food and nothing for Robux.** The prizes are golden fish, potions and crates (Derek's Set 4 Q5 note: too much food already). Nothing here is sold, sped up or refilled for Robux.
- **It sits in the camp,** inside the safe zone, beside the Index Board, so collecting never means walking into the wild part.

## 2. The four extras

| area (tier) | extra | what it gives | fills | holds |
|---|---|---|---|---|
| Park (2) | **Picnic Basket**: a wicker basket on a checked blanket | a 15 minute Money Potion | one every 6 hours | 2 |
| Neighbourhood (3) | **Yard Sale**: a folding table with a hand-written sign and two boxes on it | two crates for golden fish, one buy each a day: the Classic Crate and one zone crate of an area you have open (a new zone each day), each 40 golden fish (the Market's price is 60) | new stock each day at 00:00 UTC | today's stock |
| Woods (4) | **Fish Pond**: a small pond with lily pads and a cat-sized jetty | golden fish, landed with a little rod animation | 2 golden fish every 30 minutes | 24 (6 hours) |
| Sewer (5) | **Lost and Found**: a battered box with a "Lost and Found" stencil under a dripping pipe | one free prize a day from the table below, odds on the box | one a day at 00:00 UTC | 3 |

Lost and Found table (shown on its card): 10 golden fish 40%, a Lucky Potion 30%, a Gold Rush Potion 20%, a Classic Crate 9%, a Golden Classic Crate 1%. It is free and never sold, so the monetization policy's paid-random rule does not apply, but the odds show anyway.

What it adds: a daily player at Tier 4 or 5 gets about 50 more golden fish a day from the Pond and a potion or crate from the Lost and Found. That is a little more than the quests give (about 35 a day), which is the point: late game players get a reason to visit every area each day.

## 3. How it works in game

- **Walk up** within 8 studs and a prompt shows the extra's name and state: "Fish Pond: 14 fish, collect" or "Picnic Basket: next in 2 h 10 m". Collecting is one press. The prize flies to the HUD with F94's prize toast, at most two pictures.
- **The Yard Sale** opens a small card with the two crates, their prices and "Bought" once taken. It uses the Market's crate opening (golden-fish.md section 4).
- **The picker line** reads, for example: "Picnic Basket: 1 ready !", "Yard Sale: new crates", "Fish Pond: 14 fish !", "Lost and Found: 2 to claim !". A Yard Sale never shows a "!", since buying is not claiming. An area at night still shows its line, so players plan their morning.
- **Looks.** Each extra is a small model in the area's theme at a `campExtra` point in its camp, about the size of the Index Board, with one moving touch: steam off a thermos on the picnic blanket, the yard sale sign swinging, a fish jumping in the pond now and then, the box's lid rattling when a prize waits. The moving touch stops on Reduce Motion.

## 4. Contracts

- Save: `campExtras = { picnic: { at: number, held: number }, yardSale: { day: number, bought: { [string]: boolean } }, pond: { at: number }, lostFound: { day: number, held: number } }`. All timestamps are server time; the server works out what has filled since `at` on each collect and on profile load.
- Config: `PicnicEverySeconds` 21600, `PicnicHold` 2, `PicnicPotion` money 15 minutes, `YardSaleCratePrice` 40, `PondFishPerStep` 2, `PondStepSeconds` 1800, `PondHold` 24, `LostFoundHold` 3, `LostFoundTable` as section 2, `CampExtraRangeStuds` 8.
- Remotes: `CollectCampExtra(extraId)` (picnic, pond, lostFound) and `BuyYardSale(crateId)`, both checked on the server: the player's tier opens the area, the player stands within range of that camp's extra, the extra has something held (or the crate is in today's stock and not bought) and they have the fish. Rate limit one call a second. `CampExtrasState` (server to client) with each extra's held count and next fill time, sent on join, after a collect and on a rank up.
- Models: `CatCafe_Camp_Park_PicnicBasket`, `CatCafe_Camp_Neighbourhood_YardSale`, `CatCafe_Camp_Woods_FishPond`, `CatCafe_Camp_Sewer_LostFound` (Model-Agent), each with a `PromptAnchor` attachment.
- Analytics: `camp_extra` with the extra, what was taken and the player's tier.
- Who builds: Gameplay-Engineer (server, saves, prompts), UI-Engineer (picker line, Yard Sale card, icons), Model-Agent (four models), Animation-Engineer (the rod cast and the moving touches), Sound-Agent (a splash, a basket creak, a box rattle).

## 5. QA checks

1. A Tier 2 player's picker shows "Picnic Basket" on the Park card and nothing on the Alleyway card; a Tier 4 player sees lines on the Park, Neighbourhood and Woods cards.
2. A player who leaves for 7 hours finds the Fish Pond at 24 and the Picnic Basket at 1, and the picker shows both with a "!".
3. Collecting the pond from outside the camp, or firing `CollectCampExtra` from a Tier 3 account for the pond, is refused.
4. The Yard Sale's two crates match across two servers on the same day, each can be bought once a day and costs 40 fish.
5. Over 10,000 cloud rolls the Lost and Found table matches its odds within one percentage point.
6. A Yard Sale card never shows a "!" in the picker.
7. With Reduce Motion on, the fish stop jumping and the sign stops swinging.
