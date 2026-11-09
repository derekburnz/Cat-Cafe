# Playtime and the 2 to 5 minute drop: ranked ideas

Status: **Derek2 picked on 2026-11-09 16:24 (section 5); Gameplay-Engineer builds.** Brainstorm by Design-Agent (friend's project), 2026-11-09, for Derek2: "start brainstorming ideas to help with playtime average and getting past 2-5min drop off in players". Nothing here is decided. Derek picks, then each pick gets its own issue. Research-Agent's deep dive on what keeps CCU and playtime high in comparable games will be folded into section 4 when it lands.

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
| 1 | Gift ladder visible from minute 0 | 2–5 min cliff, play days | M |
| 2 | First visitors early: rich tip, Mystery gift, then the Collector (Derek2) | 2–10 min, "the game has a lot to it" | S–M |
| 3 | Wow cat on the first bait | bait → bait resolved, 5 min | S |
| 4 | Keep catching: a stray trio after the first catch | 2–5 min "waiting" stretch | S–M |
| 5 | Grand Opening strip from the first catch | 2–5 min "what now?" | S |
| 6 | Tablet pass | tablet 0/10 past rescue | M |
| 7 | Open loop at every exit, "welcome back" on return | session 2, 7-day return | S–M |
| 8 | Server-wide timed moment every 15–30 min | 5–30 min, co-play | M |
| 9 | Invite prompt after the first good moment | co-play days | S |
| 10 | Cozy Cafe rewards (the player's AFK idea) | session length up to 60 min | M |
| 11 | An upgrade every 60–90 s early | 2–10 min | S |
| 12 | Weekly update at a fixed day and time, with an update gift | play days, D7 | process |

Changed after Research-Agent's deep dive (section 4): the old #8 Day 2 teaser folds into #6. The old #9 server-life moments become #7 with a fixed timer. #8 and #11 are new. Cozy Cafe and early upgrades move down, because AFK past 60 minutes adds no ranking and front-loaded rewards trade D7 for D1.

### 1. Gift ladder visible from minute 0 ("Cafe gifts")
- **What:** a small strip on the HUD from the first second: "🎁 Next gift 0:45". Gifts land at 1, 2, 4, 6, 9, 12, 16, 20 and 30 minutes of play that game day. Early steps pay coins (one or two minutes of income) and a bait food. The 4-minute step pays a spin, the 9-minute step a potion, the 20-minute step 10 golden fish, and the 30-minute step a crate.
  - Progress is kept across rejoins that day, so leaving loses nothing.
  - Gifts pay at once, with no claim button and no "limited" wording.
  - The like and favourite cards (10 and 30 minutes) fold into the matching steps.
- **Why:** timed playtime rewards are the most common retention tool in the big simulators, and the reason is simple: a countdown that is always close gives a reason to stay "just one more minute". The 4 and 6 minute gifts sit right on our cliff.
- **Pacing guard (deep dive):** the gifts stay small and stop at 30 minutes. The strip always shows the next two or three steps, since players want a reward most when they're 60 to 80% of the way there. Because it's per game day, it doubles as a daily return loop.
- **Watch:** it must not crowd the tutorial. It shows as one line under the goal card and goes quiet during the catch minigame.
- **Measure:** the 5 min share of first_hour_v2 (now 11/33 = 33%, target 50%), the 10 min share, and the ladder step reached at session end.
- **Builders:** Gameplay (a PlaytimeGifts extension, a day-keyed save field), UI (the strip and toast).

### 2. First visitors early: rich tip, then Mystery gift, then the Collector (Derek2)
Derek2, 2026-11-09: "maybe an early rich tip and a mystery gift then cat collector a little but after each-other you can claim at cafe and make it obvious when he visits might help see it eary on and realize game has a lot to it".

- **Today** (Config), a new player meets these by chance:
  - The rich customer comes every 4–12 min of open day and leaves after 90 s.
  - The Mystery Visitor comes every 12.5–29 min.
  - The Collector comes every 3.3–6.7 min, and only once a cat is resting and unlocked.

  So many players leave before seeing any of them, and the ones who stay may miss them while out catching.
- **What:** a fixed first-visit schedule, once per account, in minutes of play after the tutorial's first tip:
  1. **The rich customer at about 3 min.** It pays the normal rich tip (120 s of the day rate, at least $50). That's right in the cliff.
  2. **The Mystery Visitor at about 6 min.** Its first gift is at least Rare, the same as idea 3's honest "first is special".
  3. **The Collector at about 9 min,** once a resting unlocked cat exists. If none exists, he waits until one does. His first offer uses the top of his roll (CollectorRollMax), so the first deal feels good.

  After the third visit, the normal timers take over. Each one needs the player at the cafe to claim (the existing 12-stud range), as now.
- **Make it obvious:**
  - On arrival, a big toast with the visitor's portrait: "A rich customer is at your cafe! 💰", "A mysterious visitor left a gift! 🎁" or "The Cat Collector wants to trade! 🐱".
  - A soft chime, and a glow or sparkle on the visitor.
  - When the player is away from the cafe, the toast has a "Go to my cafe" button, using the home travel that already exists.
  - There's no arrow, keeping Derek's rule.
- **First visits wait for the player.** The first rich tip and the first Collector stay until claimed, up to 5 min instead of 90 s and 180 s, so a player out catching doesn't miss the one that teaches the feature. After that, "if you miss it you miss it" applies as before.
- **Why:** each visit shows a new system (big tips, potions and gifts, selling cats for prizes) inside the first 10 minutes. That's Derek's "realize the game has a lot to it". The spacing gives a new surprise about every 3 minutes, across the exact stretch where players leave.
- **Measure:** the 5 and 10 min shares, claim rate and time-to-claim for each first visit, and whether players who claimed the first rich tip reach 10 min more often.
- **Builders:**
  - Gameplay: VisitTimer first-visit override, a save flag `firstVisits` with three booleans, and the longer first stay.
  - UI: the arrival toasts and the Go button.
  - Sound: the chimes.
  - VFX: the glow, reusing the rare-moment sparkle.
- **Coordinates with** idea 1 (keep the gift ladder's 2, 4 and 6 minute toasts from landing in the same second; offset by 20 s) and idea 3 (the wow cat around minute 2–3).

### 3. Wow cat on the first bait
- **What:** move the first-hour.md §2 guaranteed Rare-or-better roll from the second bait result to the first. With the first bait now at 45 s, the first big "wow" comes at about minute 2 or 3, right before the cliff. The bowl card says "Your first bait cat will be Rare or better!" while it waits.
- **Why:** the bait wait is the first "waiting" moment, and 5 of 12 players leave inside it. A promised Rare turns the wait into anticipation, and the payoff arrives before minute 5.
- **Measure:** bait → bait resolved (now 12 → 7), the 5 min share, and first_wow_cat timing.
- **Builders:** Gameplay (move one trigger and one line of card text).

### 4. Keep catching: a stray trio after the first catch
- **What:** after the first catch, the next two strays spawn close to the cafe within 20 s with a short "More cats are wandering nearby!" line. Catching is the part players came for (the Mythical ads lead). Between catch 1 and the first tip they currently have little to do with their hands.
- **Why:** the drop sits where the game turns from active to waiting. A couple more easy catches fill the wait while the cats serve customers and the first tip lands on its own. It also fills the "second cat" and "five cats" steps sooner.
- **Measure:** the time from the first catch to the third, the 2 → 5 min share, and five cats (now 7 of 35).
- **Builders:** Gameplay (stray spawn rule for new players only), UI (one toast).

### 5. Grand Opening strip from the first catch
- **What:** show the Grand Opening 0/8 strip (first-hour.md §1) as soon as the first cat is caught, instead of at the tutorial's end. A goal is then always on screen during the 2–5 minute stretch.
- **Measure:** the 5 min share, and grand_opening step 1 timing.
- **Builders:** UI (one condition).

### 6. Tablet pass
- **What:** a focused pass on tablet layouts and the rescue on a tablet. 10 of the 34 players were on tablets and none got past the first rescue, so something there is likely broken rather than just hard.
  - Laptop-Tester or QA plays the first 5 minutes in the tablet emulator: iPad and a 10" Android in both orientations.
  - Check the rescue bar's touch target, any HUD overlap with the rescue prompt, and the Catch button size.
- **Measure:** the tablet onboarding funnel, specifically the share past the rescue (now 0/10).
- **Builders:** QA first, then UI or Gameplay for each bug found.

### 7. Open loop at every exit, "welcome back" on return (was the Day 2 teaser)
- **What:** the session recap (after 10 minutes, and on the leave card where Roblox shows it) lists the next two or three goals with progress bars, for example "Park: 3 of 5 cats", "Your cafe earns about $X by tomorrow", "Daily Treat Day 2: 🐟 + crate" and "Rally Saturday 18:00 UTC". On return, the offline earnings card says what came in and points at the nearest of those goals with "Welcome back!".
- **Why:** the deep dive rates an open loop at the end of a session above a daily reward. Players come back to finish what is nearly done, and we already have the recap and the offline card.
- **Measure:** 7-day qualified play sessions and D1 for players who saw the recap with goals against those who didn't.
- **Builders:** UI (copy and progress bars), Gameplay (the goal list read from the profile).

### 8. Server-wide timed moment every 15–30 min
- **What:** a free event for everyone in the server on a fixed timer, with a HUD countdown ("Cat Parade in 4:12"). For example, a parade of strays through the Town Square, easy to catch, with a slightly better chance of gold. It's free for all, needs no sign-up and loses nothing if missed. The Mythical or rainbow catch banner from the old idea rides along.
- **Why:** a known event time is an open loop inside the session, and it pulls players together, which helps co-play. It fits Derek's ads, which lead with rare cats.
- **Measure:** the 20 and 30 min shares, the share of players in the server who join a parade, and session length in 2+ player servers.
- **Builders:** Gameplay (timer and spawns), UI (countdown), VFX and Sound (parade entrance).

### 9. Invite prompt after the first good moment
- **What:** after the first Rare-or-better cat (idea 3), a one-time card: "Show a friend? Invite them to your cafe", which opens Roblox's own invite prompt. It's skippable, appears once, and gives no reward for inviting (no pressure on kids). Invited friends join the player's public server.
- **Why:** co-play days are a ranking signal, and players invite at a high point, not at the start.
- **Measure:** invite prompt opens and accepts, and co-play days in Creator Analytics.
- **Builders:** UI (card).
- **Private servers stay as they are** (Derek, 2026-11-09: free with VIP, 50 Robux otherwise), so players stay in public servers where Derek can join and watch. No idea here leans on private servers or changes their price.

### 10. Cozy Cafe rewards (the player's AFK suggestion)
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
- **Research note:** playtime counts for ranking only up to 60 minutes a player a day, so AFK beyond that adds CCU but no discovery. 8 bags at 3 minutes stays well inside the hour. Build it after the 5-minute number moves.
- **Measure:** session length for players with at least one Cozy bag against those without, the share of play time spent in the cafe, and whether catches a session drop (they shouldn't).
- **Builders:** Gameplay (the timer and bag drops in the plot zone), Model (the bag and the curled-up cat pose), UI (the HUD line), Sound (a soft purr on the drop).

### 11. An upgrade every 60–90 s early
- **What:** tune the first three purchases (a table, a second table, the first cat level-up) so each is affordable about a minute after the last, with the "buy" button pulsing when affordable. Make the first one cost exactly what the instant first tip pays.
- **Why:** frequent small "the number goes up" beats keep idle tycoons sticky in the first minutes, before the bigger goals take over.
- **Measure:** the time between the first three purchases, and table → tip in onboarding_v6.
- **Builders:** Gameplay (Config prices).

### 12. Weekly update at a fixed day and time, with an update gift
- **What:** ship content on one fixed weekday and hour (for example Saturday 17:00 UTC), and give a small "update gift" to everyone who plays that day. Grow a Garden's Saturday drop is the model.
- **Why:** a known time is the strongest return loop for play days and D7, and it gives the ads and the Event page something to point at.
- **Measure:** play days per user (7 day) and D7.
- **Builders:** lead or Gameplay-Engineer (publish timing), Gameplay (the gift through Daily Treat's payout).

## 3. Recommended first wave
1 to 5 together, because each targets the 2–5 minute stretch directly, and 2, 3 and 5 are small. Do 6 (tablets) in parallel, because it's a bug hunt more than a design change. Then 7 (open loop), which is mostly copy. Read first_hour_v2 and sessions 2 to 5 over the next 100 new players before 8 to 11. 12 is a schedule choice for Derek.

## 4. Research deep dive (Research-Agent, ccu-playtime-deep-dive-2026-11-09.md)
- **CCU is not a ranking signal.** What counts:
  - Playtime per player, capped at 60 minutes a day.
  - Deep play-through and bounce rate. Bounce is our 2–5 minute drop.
  - Play days per user.
  - 7-day qualified play sessions (session 2).
  - Intentional co-play days, which have counted private servers since December 2025.
- **We already have nearly every standard system.** The gap is the first 5 minutes and the missing open loop when a session ends. This confirms ideas 1–5 at the top.
- **Its ranked list:** fix the 2–5 drop, then:
  - An open loop at exit and a welcome back (idea 7).
  - A weekly fixed-time update (idea 12).
  - A server-wide timed moment (idea 8).
  - Co-play invites (idea 9). Its private-server half is dropped by Derek's decision above.
  - Small full servers (8), which is already our server size.
  - A gameplay video on Home.
  - A pacing guard (added to idea 1).
  - Measuring sessions 2 to 5.
- **Not to do:** chase CCU with AFK farms past 60 minutes, front-load early rewards (it buys D1 and loses D7), or add systems before the 5 minute number moves. That's why Cozy Cafe (idea 10) and early upgrades (idea 11) moved down.
- **Data still to come** once #2776 is live:
  - The last step and time on that step for 2–5 minute leavers (`step_time`, `quit_state`).
  - A clean device split at 2 and 5 minutes.
  - Whether leavers had touched the bait bowl.

## 5. Derek2's picks (2026-11-09 16:24) and the build specs

Derek2's answers, item by item, use the numbering in section 2.

**The rule for every item (Derek2: "don't make this or any other updates take a lot of precious phone screen space"):**
- No new bar, strip or panel that stays on screen.
- Any new HUD element takes one slot in the existing icon row, the same size as the icons already there.
- Pop-ups are one toast at a time at the top centre. Each lasts at most 3 s and is at most 2 lines on a phone.
- Cards (invite, Unlocked) open only on a tap or at a calm moment (GiftIdleSeconds), never during a catch, rescue or flight.
- UI-Engineer checks each one on a 360 × 640 phone and a tablet before merge.

| # | Idea | Derek2 | What gets built |
|---|---|---|---|
| 1 | Gift ladder | yes, improve the existing gift milestones, little screen space | 5a |
| 2 | First visitors early | yes, needed | section 2 idea 2 as written, with toasts per the rule above |
| 3 | Wow cat on the first bait | yes, and a faster first bait | first-hour.md §2's guarantee moves to the first bait result; the first bait wait stays at #2776's 45 s |
| 4 | Stray trio | not needed; instead many starting cats and spawns in the Alleyway and Park, with rescues near the start | 5b |
| 5 | Grand Opening strip from the first catch | yes | shows from the first catch, collapsed to its one-line "Grand Opening 1/8" chip under the goal card (already its size) |
| 6 | Tablet pass | test on mobile and tablets | QA-Planner and Laptop-Tester: the first 10 minutes on a phone and a tablet, both orientations; bugs become issues |
| 7 | Open loop at exit | the game has most of these | dropped |
| 8 | Server-wide timed moment | not needed; strays are already up; halve the pity timers for now and add a funnel | 5c |
| 9 | Invite prompt | a reward for inviting, shown between 5 and 15 minutes | 5d |
| 10 | Cozy Cafe rewards | yes | section 2 idea 10 as written; its "Cozy gift in 2:10" line becomes the gift icon's tooltip (5a) |
| 11, 12 | Early upgrades, weekly update | not answered | on hold |

### 5a. Gift milestones, improved (idea 1)
- **Steps.** Keep the existing like and favourite gifts (PlaytimeGifts, 10 and 30 minutes) and add small steps before them on the same track: 2, 4 and 6 minutes, then 10 (like), 15, 20 and 30 (favourite).
  - **The added steps pay:**
    - 2 min: 1 minute of income.
    - 4 min: a bait food.
    - 6 min: 1 spin.
    - 15 min: 5 golden fish.
    - 20 min: a Swift Potion.
  - **Counted per account.** Played time on the account counts, as PlaytimeGifts does now, so it's once per account and leaving loses nothing.
- **On screen.** One gift icon in the HUD icon row with a small countdown under it ("1:45"). Tapping it shows the next two steps in a small popover. When a step pays, a toast reads "Gift! +1 spin". After the 30-minute step the icon goes away.
- **Contracts.** `PlaytimeGifts.KINDS` grows to the seven steps; the like and fav cards stay on their steps. Config `PlaytimeGiftSteps` holds the minutes and prizes. Save: the existing paid marks grow to cover the new kinds, with no version bump if the marks map is keyed by kind (Gameplay to confirm). Analytics: `playtime_gift` with the step.

### 5b. Busier starting areas (instead of idea 4)
- **More strays where players start.**
  - Alleyway `waveSize` 11 → 16, and Park 12 → 16.
  - A per-area floor override, `floorBase`: Alleyway 16, Park 16. Other areas keep `StrayFloorBase` 12, and `StrayLiveMax` 21 still caps every area.
  - The Alleyway and Park keep at least 6 strays within `StrayEntryStuds` of their camp (a per-area `entryFloor` 6, others stay at 4). New players then see cats as soon as they land.
- **Rescues near the start.**
  - Each of the two areas marks one rescue spot within about 40 studs of its camp as `starter`. Gameplay picks it from the existing pool, or asks Model-Agent for one more spot.
  - At night start, those two areas get at least 2 stuck cats (a per-area `rescueMinStuck` 2), and the first fills the starter spot when it's free.
  - The tutorial's rescue step uses the starter spot.
- **Odds unchanged.** More strays means more Commons in absolute terms but the same rare odds per stray, so Pace's tier times barely move. Gameplay re-runs Pace.spec to check Tier 2 stays in #2683's 12–16 min band.
- **Measure:** onboarding_v6 catch → second cat → five cats, and rescue → bait resolved.

### 5c. Pity timers halved, for now (instead of idea 8)
- `PityLegendarySeconds` 1800 → 900 and `PityMythicalSeconds` 7200 → 3600. Both are marked "temporary, Derek2 2026-11-09, review 2026-11-16" in Config, and a decisions.md entry records when they go back.
- **A funnel** `pity_v1`: steps `pity_spawned` (rarity, area), `pity_seen` (a player within 60 studs), `pity_catch_started` and `pity_caught`, with the catcher's minutes played (bands). Counts only, never who.
- **Measure:** time from spawn to catch, and the share caught by players in their first 30 minutes.

### 5d. Invite with a reward, between 5 and 15 minutes (idea 9)
- **When.** Once per account, at the first good moment between 5 and 15 minutes of play: the first Rare-or-better cat, the first Collector deal, or the Grand Opening's step 4. If none happens by 15 minutes, it shows at 15 at the next calm moment. It never shows before minute 5.
- **What.** A small card: "Invite a friend: you both get 🐟 20 when they start playing!" with Invite (Roblox's own invite prompt, SocialService) and Not now. There's a Friends button in the menu for later invites, inside the existing menu, not a new HUD slot.
- **Reward** (Roblox's Friend Invite Reward System guidance, checked by Research-Agent 2026-11-09):
  - **Detection.** `Player:GetJoinData().ReferredByPlayerId` covers every kind of Roblox invite, links included. There's no "Roblox friends only" rule, since a brand-new player from a shared link can't be a friend yet.
  - **The joiner must be new** (a fresh save, judged on the server), must not be the inviter, and each joiner pays once, ever.
  - **When it pays.** The joiner gets 20 golden fish on their first catch. The inviter gets 20 golden fish once the joiner has played 5 minutes or caught their first cat, whichever comes first. This stops join-and-leave farming.
  - **Cap.** Up to 5 rewarded joiners per inviter per game day.
  - **No pay for sending.** Sending an invite alone pays nothing.
  - **The prompt** only opens after `SocialService:CanSendGameInviteAsync` passes. There are no reminders or extra pop-ups beyond the one card (young-audience rules).
  - **Currency.** Fish are earned only, never sold, so this stays outside `monetization-policy`.
  - **Optional.** A Creator Hub reward banner describing the reward exactly is a store page change, so it needs Derek's OK first.
- **Contracts.** Save: `invites = { rewarded: { [joinerUserId]: true } (last 50), today: { day, count }, cardShown: boolean }` on the inviter, and `referredBy = { userId, paid: boolean }` on the joiner, a version bump. The server reads `ReferredByPlayerId` at join, waits for the qualifying play, then pays the inviter if they are in the server, or saves it to the inviter's pending (a small DataStore key, as the trade vault does), and pays both. Analytics: `invite_card` (shown, invite, not now) and `invite_join`.
