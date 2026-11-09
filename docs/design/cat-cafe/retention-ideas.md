# Playtime and the 2 to 5 minute drop: ranked ideas

Status: brainstorm by Design-Agent (friend's project), 2026-11-09, for Derek2: "start brainstorming ideas to help with playtime average and getting past 2-5min drop off in players". Nothing here is decided. Derek picks, then each pick gets its own issue. Research-Agent's deep dive on what keeps CCU and playtime high in comparable games will be folded into section 4 when it lands.

## 1. What the numbers say (Research-Agent, stats-2026-11-09-1505)

- **first_hour_v2 (33 new players):** at 30 s 29, 60 s 25, **2 min 21, 5 min 11**, 10 min 6, 20 min 2, 30 min 1. Half of the players left between 2 and 5 minutes. That's the cliff.
- **onboarding_v6 (35):** catch 18, customer 18, second cat 16, table 15, **tip 12, bait 12**, rescue 10, **bait resolved 7**, five cats 7, Tier 2 6. Players leave in the stretch after the first catch, where the game turns from "I do things" into "I wait for things" (customers, the first tip, the bait timer).
- **Tablets:** 10 players, 3 caught a cat, and none got past the first rescue. Phones: 19 players, 10 catch, 5 reach Tier 2.
- **Sessions:** the average session is 16.6 min and D1 is about 31%. The players who get past 10 minutes stay a long time, so the job is getting them there.
- **Small sample:** 33 players is too few to judge any change by. Read every measure below over at least 100 new players.

Shipping today in #2776/#2777, and assumed in place below:
- The first catch can't fail.
- A Catch prompt from farther away.
- The first bait in 45 s, with a "cat is coming" tip.
- An instant first tip.
- A tablet hint.
- Telemetry for each step.

The rules this list keeps (Derek):
- Cats handle customers and tips, with no arrows for those.
- New players already have night immunity.
- No dark patterns: nothing is lost by leaving, and no "limited" pressure.
- Nothing here is sold.

## 2. The ranked list

Effort: S is under a day for one builder, M is one or two days and a couple of builders, L is bigger.

| # | Idea | Targets | Effort |
|---|---|---|---|
| 1 | Gift ladder visible from minute 0 | 2–5 min cliff, session length | M |
| 2 | Wow cat on the first bait | bait → bait resolved, 5 min | S |
| 3 | Keep catching: a stray trio after the first catch | 2–5 min "waiting" stretch | S–M |
| 4 | Tablet pass | tablet 0/10 past rescue | M |
| 5 | Cozy Cafe rewards (the player's AFK idea) | session length, 10 min+ | M |
| 6 | Grand Opening strip from the first catch | 2–5 min "what now?" | S |
| 7 | An upgrade every 60–90 s early | 2–10 min | S |
| 8 | Day 2 teaser on the gift ladder | D1 return | S |
| 9 | Server-life moments ("someone caught a Mythical!") | 5–20 min, CCU | S–M |

### 1. Gift ladder visible from minute 0 ("Cafe gifts")
- **What:** a small strip on the HUD from the first second: "🎁 Next gift 0:45". Gifts land at 1, 2, 4, 6, 9, 12, 16, 20 and 30 minutes of play that game day. Early steps pay coins (one or two minutes of income) and a bait food. The 4-minute step pays a spin, the 9-minute step a potion, the 20-minute step 10 golden fish, and the 30-minute step a crate.
  - Progress is kept across rejoins that day, so leaving loses nothing.
  - Gifts pay at once, with no claim button and no "limited" wording.
  - The like and favourite cards (10 and 30 minutes) fold into the matching steps.
- **Why:** timed playtime rewards are the most common retention tool in the big simulators, and the reason is simple: a countdown that is always close gives a reason to stay "just one more minute". The 4 and 6 minute gifts sit right on our cliff.
- **Watch:** it must not crowd the tutorial. It shows as one line under the goal card and goes quiet during the catch minigame.
- **Measure:** the 5 min share of first_hour_v2 (now 11/33 = 33%, target 50%), the 10 min share, and the ladder step reached at session end.
- **Builders:** Gameplay (a PlaytimeGifts extension, a day-keyed save field), UI (the strip and toast).

### 2. Wow cat on the first bait
- **What:** move the first-hour.md §2 guaranteed Rare-or-better roll from the second bait result to the first. With the first bait now at 45 s, the first big "wow" comes at about minute 2 or 3, right before the cliff. The bowl card says "Your first bait cat will be Rare or better!" while it waits.
- **Why:** the bait wait is the first "waiting" moment, and 5 of 12 players leave inside it. A promised Rare turns the wait into anticipation, and the payoff arrives before minute 5.
- **Measure:** bait → bait resolved (now 12 → 7), the 5 min share, and first_wow_cat timing.
- **Builders:** Gameplay (move one trigger and one line of card text).

### 3. Keep catching: a stray trio after the first catch
- **What:** after the first catch, the next two strays spawn close to the cafe within 20 s with a short "More cats are wandering nearby!" line. Catching is the part players came for (the Mythical ads lead). Between catch 1 and the first tip they currently have little to do with their hands.
- **Why:** the drop sits where the game turns from active to waiting. A couple more easy catches fill the wait while the cats serve customers and the first tip lands on its own. It also fills the "second cat" and "five cats" steps sooner.
- **Measure:** the time from the first catch to the third, the 2 → 5 min share, and five cats (now 7 of 35).
- **Builders:** Gameplay (stray spawn rule for new players only), UI (one toast).

### 4. Tablet pass
- **What:** a focused pass on tablet layouts and the rescue on a tablet. 10 of the 34 players were on tablets and none got past the first rescue, so something there is likely broken rather than just hard.
  - Laptop-Tester or QA plays the first 5 minutes in the tablet emulator: iPad and a 10" Android in both orientations.
  - Check the rescue bar's touch target, any HUD overlap with the rescue prompt, and the Catch button size.
- **Measure:** the tablet onboarding funnel, specifically the share past the rescue (now 0/10).
- **Builders:** QA first, then UI or Gameplay for each bug found.

### 5. Cozy Cafe rewards (the player's AFK suggestion)
- **What:** "While you're in your cafe, your cats bring you extra rewards."
  - After 60 s inside your own cafe, a cat curls up on the counter with a "Cozy" bubble.
  - Every 3 minutes you stay, it leaves a small gift bag: about a minute of income, sometimes a bait food, and rarely 1–3 golden fish.
  - Up to 8 bags a game day.
  - A bag is collected by walking over it or tapping it, so it needs a touch every few minutes but not active play.
  - The HUD line reads "Cozy gift in 2:10".
- **How it fits the loop:** the game is already two halves: catching out in the world (active) and the cafe earning on its own (idle). Right now the idle half only pays coins, so a player who wants to sit back has no reason to stay in-game rather than take the offline earnings. Cozy rewards make "sitting in your cafe" a real way to play. That raises session length, which Roblox's discovery reads, and it suits players on breaks or on a second screen.
- **How to keep it from replacing active play:**
  - Keep it small. The 8 bags a day add up to less than 10 minutes of active catching earns, and it never gives cats (cats come only from catching and bait).
  - It doesn't stack with offline earnings.
  - It stops after 8 bags. Roblox's 20 minute idle kick also limits pure AFK, and we don't fight that kick.
  - Its best prize, the golden fish, is rarer than from one catch.
  - It's placed after the tutorial, from the first visit back to the cafe after the first catch, so new players still learn to catch first.
- **Measure:** session length for players with at least one Cozy bag against those without, the share of play time spent in the cafe, and whether catches a session drop (they shouldn't).
- **Builders:** Gameplay (the timer and bag drops in the plot zone), Model (the bag and the curled-up cat pose), UI (the HUD line), Sound (a soft purr on the drop).

### 6. Grand Opening strip from the first catch
- **What:** show the Grand Opening 0/8 strip (first-hour.md §1) as soon as the first cat is caught, instead of at the tutorial's end. A goal is then always on screen during the 2–5 minute stretch.
- **Measure:** the 5 min share, and grand_opening step 1 timing.
- **Builders:** UI (one condition).

### 7. An upgrade every 60–90 s early
- **What:** tune the first three purchases (a table, a second table, the first cat level-up) so each is affordable about a minute after the last, with the "buy" button pulsing when affordable. Make the first one cost exactly what the instant first tip pays.
- **Why:** frequent small "the number goes up" beats keep idle tycoons sticky in the first minutes, before the bigger goals take over.
- **Measure:** the time between the first three purchases, and table → tip in onboarding_v6.
- **Builders:** Gameplay (Config prices).

### 8. Day 2 teaser on the gift ladder
- **What:** the last step on the gift ladder shows "Tomorrow: Day 2 of your Daily Treat 🐟 + crate", using the existing seven-stamp Daily Treat card. A reason to come back is shown before the player leaves.
- **Measure:** D1 (now about 31%) for players who saw the teaser against those who didn't.
- **Builders:** UI.

### 9. Server-life moments
- **What:** a server-wide banner when anyone in the server catches a Mythical or a rainbow cat, plus a "cats spotted near the fountain" event every 10 minutes that pulls players to the Town Square together for a minute.
- **Why:** shared moments make a server feel alive. That's part of what keeps CCU up in the big games, and it advertises rare catches to players who haven't had one yet.
- **Measure:** session length in servers of 2+ players against servers with 1, and the share of players who join a fountain event.
- **Builders:** Gameplay, UI, VFX. Rarer catches already have their F89 effects.

## 3. Recommended first wave
1, 2, 3 and 6 together, because each targets the 2–5 minute stretch directly and 2 and 6 are tiny. Then read first_hour_v2 over the next 100 new players before adding 5 and 7. Do 4 (tablets) in parallel, because it's a bug hunt more than a design change.

## 4. Research deep dive
To be filled in from Research-Agent's findings on what keeps CCU and playtime high in comparable Roblox games. Any finding that changes the ranking moves the list above, and this section notes why.
