# Store page: name, genre and description

Owner: growth-analyst. Written 2026-11-04 for Derek's ask, which came through the Coordinator. The text ships through `games/cat-cafe/tools/opencloud/store-page.txt` and the `store-page` workflow (`set`). Derek approves the text before anyone runs `set`.

## 1. What the games around us do

Live data comes from the public Roblox games API (games.roblox.com/v1/games), read on 2026-11-04. Player counts are a snapshot, and the Halloween tags were still up.

| Game | Title pattern | Genre / subgenre | Playing | Visits | First line of the description |
|---|---|---|---:|---:|---|
| Adopt Me! | `[🎃] Adopt Me!` | Roleplay & Avatar Sim / Pet Care | 155,799 | 45.3B | "Adopt and raise 🐶🦄👶, trade and collect legendary pets, build your dream home, and roleplay with friends!" |
| Steal a Brainrot | `[💀] Steal a Brainrot` | Simulation / Tycoon | 82,679 | 74.3B | "🗣️ Welcome to Steal a Brainrot!", then an emoji "How to Play" list |
| Fisch | `Fisch 🎸 [VENUE ENCORE]` | Adventure / (none) | 72,269 | 5.1B | "Dive into Fisch, the ultimate fishing adventure… Cast your line to catch rare and unique fish" |
| Pet Simulator 99 | `🎃 [MINIGAMES] Pet Simulator 99! 👻` | Simulation / Incremental Simulator | 54,493 | 2.7B | "Create an army of the coolest pets! They will help you get RICH!" |
| Grow a Garden | `[🎃] Grow a Garden 🌶️` | Simulation / Tycoon | 14,625 | 36.0B | "Buy seeds… plant them, wait for them to grow, and collect the profits!" |
| Restaurant Tycoon 3 | plain | Simulation / Tycoon | 7,311 | 389M | "🧑‍🍳Welcome to Restaurant Tycoon 3", then HOW TO PLAY with 🍔 bullets and "make money while you're offline" |
| Pet Store Tycoon | plain | Simulation / Tycoon | 4,985 | 22.6M | "Small shop. Big dreams. Lots of adorable pets!", then 4 emoji bullets |
| Kitten Game 🐾 | emoji after the name | Roleplay & Avatar Sim / Animal Sim | 4,328 | 643M | "🐾Become a cat, collect fun accessories, play with friends, and explore!" |
| Catch And Tame! | `[😵‍💫] Catch And Tame!` | Simulation / Tycoon | 2,363 | 469M | "Grab your lasso… Catch them, bring them back to your pen", "💸 EARN MONEY EVEN WHILE YOU'RE OFFLINE! 💸" |
| Own a Cat Cafe! | `Own a Cat Cafe! [❄️ WINTER UPDATE]` | Simulation / Sandbox | 23 | 79K | "🐱 Run your own cozy cat cafe!", then a ❄️ update block |
| Catch a Cat! 🐱 | emoji after the name | Simulation / Tycoon | 30 | 13K | "❤️ Pet cats to catch them / 💰 Put cats on droppers" |
| Pet Cafe Tycoon | `[Free Worker]` tag | Simulation / Tycoon | 34 | 27K | "🧋 Run your own boba café with cats!" |

What gets traction:
- **The first line says the verb and the reward**: adopt and raise, catch and bring back, grow and collect profits. Every big one does this in under 120 characters. Roblox's own description guide says the first ~160 characters matter most because they show in search and on phones before the page expands, and that the hook should hold the title, the genre and the most unique feature.
- **Emoji are used as bullets, one per line, never as decoration in the middle of a sentence.** All the top pet and tycoon pages do this. Roblox says emoji are optional.
- **A short list beats paragraphs.** Most pages use 4 to 6 lines with an emoji each. Long how-to-play control lists are common, but Roblox's guide says to teach controls in the game instead.
- **"Earns while you're offline"** shows up as its own line on Restaurant Tycoon 3, Catch And Tame and Grow a Garden. We have it, so we say it.
- **Update tags go in the title** (`[🎃]`, `[❄️ WINTER UPDATE]`), not as a long block in the description. The description keeps at most one short update line, because Roblox says long update blocks push the main text down.
- **Social lines** on the big pages ask for likes, a group join or the notify bell ("Like the game and join the group", "Be FIRST 🏆… pressing 🔔NOTIFY"). We leave out like and favourite asks, per Derek's rules and the young-audience default. A plain feedback line is enough.
- Roblox says hashtags and tags do nothing for ranking and only use up characters.

Name note: `Catch a Cat! 🐱` (Simulation / Tycoon, created 2026-10-09, 13K visits) is close to our name. The name is final (CLAUDE.md, 2026-11-02), so nothing changes. It does mean "Cafe" and the cafe hook have to carry the difference, and the description leads with "cat cafe" for that reason.

## 2. Genre: Simulation, subgenre Tycoon

- Roblox defines Tycoon as "games simulating the management of a business or base". Our core loop is running the cafe: cats work roles, customers pay, coins buy tiers up to the Grand Cafe, and the cafe earns while players are away. The catching feeds that business.
- Our nearest comps all use it: Catch And Tame, Pet Store Tycoon, Restaurant Tycoon 3, Grow a Garden and Steal a Brainrot. That puts us in the same Tycoon charts the players we want already browse.

Considered and not picked:
- Simulation / Incremental Simulator (Pet Simulator 99): its definition is "simple repetitive actions to increase a counter". Our net is a skill minigame, not a click counter.
- Roleplay & Avatar Sim / Pet Care (Adopt Me): we don't raise one pet. Choosing it would also put us next to roleplay games our loop doesn't match.
- Simulation / Sandbox (Own a Cat Cafe!): we have no free building.

Roblox lets the genre change only once every 3 months and may correct a genre it finds wrong, so it's worth getting right the first time. Our genre is blank today. Derek sets it in Creator Hub under Publish Settings > Game Details (Genre and Subgenre), per the Roblox genres page. The store-page workflow doesn't set it.

## 3. The description (store-page.txt)

About 600 of the 1,000 allowed characters. The hook is 93 characters, so it shows in full in search.

Checks:
- **Every claim is in the game today:**
  - 5 areas: Alleyway, Park, Neighbourhood, Woods, Sewer.
  - 50 area cats in `Catalog.cats`, Common to Mythical, plus spares and the starter.
  - Gold and rainbow coats.
  - Tier names Corner Cafe to Grand Cafe (`Catalog.luau`).
  - Trading at `TradeMinTier = 3`.
  - PalService and RescueService.
  - Offline earnings, daily treat, quests, codes, leaderboards, and the Feedback button.
- **Nothing promised:** no "new cats every week", no "limited", no countdown.
- **No "Roblox" and no "game"/"games" anywhere:** the group is not named in the text, because "Creampuff Games" would trip the filter.
- **No like, favourite or group-join ask, and no paid item mentioned.**

Open choices for Derek:
1. Title stays `Catch a Cat Cafe`. Optional later: a seasonal tag in front (`[❄️] Catch a Cat Cafe`), which every top comp uses during events.
2. If he says yes on #999 (group gate), add one line later: "🐾 Join our community to take home the Bellhop Cat." The group can't be named, for the filter reason above.

## Sources

- Roblox experience descriptions guide: https://create.roblox.com/docs/production/publishing/descriptions
- Roblox experience genres: https://create.roblox.com/docs/production/publishing/experience-genres
- Game data: https://games.roblox.com/v1/games?universeIds=383310974,7709344486,5750914919,3317771874,7436755782,7094518649,10282097014,4689722433,9091133975,10768414012,10770009005,10772835007
