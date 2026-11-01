# Easy start: play in seconds, learn as you go (F87)

Status: proposed by the game-designer thread, 2026-11-01. From Derek's asks of 2026-10-30 23:28 ("make the game especially the start as low friction as possible so we don't lose early players ... while still making it able to have depth and hold player retention") and his research notes of 2026-10-31 ("add a feedback either cat area or button so people can submit. ADD Tons of test checks to see where/what step people are getting stuck and quitting ... don't overload them with a long tutorial add context tutorials ... if they find food for like food bowl or something then you can give them a QUICK cut scene on how to use food bowl"). Part of the ship-and-learn plan in the decision memo (`Design-Agent/rework-or-ship-2026-11-01.md` in the project files).

Written for today's town (the Alleyway behind the cafes, travel buttons), which is what ships if Derek picks ship and learn. If the cannon (F84) is built first, the same rules apply with "fly to the Alleyway" in place of "go out the back door".

## 1. Goals

1. A new player is moving toward a cat within 10 seconds of the world loading and has caught one within 60.
2. One next step on screen at a time, always with a trail to it. Nothing else asks for attention until the first loop is done.
3. Every other system is taught at the moment it first matters, in one line or a cut of 4 seconds at most.
4. The first loop cannot be failed. Depth (harder catches, tackles, rare odds) arrives after the first cat is home.
5. We can see the step where each player quit, on the dashboard, from the first day of the ads.

## 2. The first session

### 2a. Straight into play

- **The intro stops playing by itself.** `Config.IntroAutoPlay` (false). A new player spawns at their back door, facing the alley, with the first hint and its trail already showing. The Tutorial tile (top right, "?") glows twice and plays the intro for anyone who taps it, as now. Flipping the constant back to true restores today's behaviour. This is a Set 5 question for Derek, since he asked for the intro; the recommendation is off, because 25 seconds of cutscene before the first input is the longest wait in the game.
- **The tutorial stray is in view.** The beginner's Common (data-model section 9) waits at its point behind the player's own cafe, as now. Its "!" marker shows from the spawn.

### 2b. A first catch that cannot fail

While `tutorialStep` is below 2, for the beginner's own tutorial stray only:

- One circle, shrinking over TutorialShrinkSeconds (1.6), with Good and Perfect windows doubled.
- A Miss does not make the cat sprint off. The circle comes back after TutorialRetrySeconds (1.0) with "Try again! Tap as the circle closes." There is no limit on tries.
- Other players cannot start a catch on it: it is locked to the beginner (`LockedBy` the beginner's user id) from spawn.

### 2c. Safe first carry

Until the player's first check-in, nobody can tackle or shove them (`ShoveService` refusal reason `newcomer`). The shield also covers a beginner standing in an area without a cat. It ends at the first check-in, which also starts the tackle context tip (section 3).

### 2d. The first cat takes a job by itself

At the first check-in, if a Tier 1 role slot is free, the server places the cat in it (the Waiter slot when Tabby holds Barista), the way `PlaceCat` would. A celebration card shows "Your first cat! [name] is your Waiter now" with the new rate, and the cat appears at its spot in its outfit. `tutorialStep` goes from 2 to 3 and `first_role` logs. Giving a cat a job by hand is taught at the second cat (tip `second_cat`).

### 2e. The steps that are left

| tutorialStep | Hint (one line, device-aware) | Trail to |
|---|---|---|
| 0 to 1 | Catch the cat behind your cafe! [hold key] | the tutorial stray |
| 2 | Carry it home through your back door | the back door |
| 3 | Buy a table: more tips from every cat [Upgrades key] | the Upgrades button |
| 4 | Buy the Bait bowl [Upgrades key], then put Kibble in it | the button, then the bowl |
| 5 | (done: the Daily Treat, the spin and Quests appear) | |

Device-aware means the hint names the input the player last used: "hold E" on a keyboard, "tap and hold" on touch, the button glyph on a gamepad (the `PromptKey` component). On touch the hint never names a letter key.

### 2f. A small HUD until the first loop is done

Until `tutorialStep` reaches 5, the HUD shows only coins and rate, the hint with its trail, the Home and Alley travel buttons, Upgrades from step 3 and the Collection from the first check-in. The other buttons appear one at a time when their unlock happens, each with a small "New!" pop and its context tip if it has one.

| Button or station | Appears when |
|---|---|
| Collection | first check-in |
| Upgrades | step 3 |
| Quests, Codes, Daily Treat, Spin Wheel | step 5 (the treat and the spin already wait for it) |
| Index, Decor | the third cat checked in |
| Area travel buttons beyond the Alley | Tier 2 |
| Dealer, Collector, Fish Market, crates, potions | Tier 2, or the first golden fish or potion if that comes first |

Stations a player cannot use yet stay in the world, with a small lock and "Opens at Tier 2" in place of their prompt. Nothing about them is hidden from the street.

### 2g. Never stuck

- If the current step has not moved for StuckNudgeSeconds (40), the hint pulses and the trail is drawn again from where the character stands.
- After StuckHelpSeconds (90) on the same step, a small card asks "Need a hand?" with two buttons: Show me (plays the step's context cut, or the intro for steps 0 to 2) and Got it. It shows once per step per account.
- Each nudge logs `stuck_nudge` (section 5) so we see which step stalls.

## 3. Context tips

A context tip is one line on a card, or a camera cut of 4 seconds at most with one caption, shown the first time a player meets something. Each shows once per account and is saved in `tipsSeen`. Rules:

- Never during a catch, a rescue, a carry or a tackle, never in the 15 s dusk warning's last 5 seconds, and at most one every TipGapSeconds (60). A tip that cannot show yet waits in a queue of three; older ones drop.
- A camera cut freezes controls for its length and can be skipped by any press after 1 second. A card needs no press and goes after 5 seconds or on a tap.
- The Settings window has "Show tips again", which clears `tipsSeen`.

| id | Trigger (first time) | Shows | Kind |
|---|---|---|---|
| `bowl` | the player owns food and a bowl and the bowl is empty (Derek's example) | the camera swings to the bowl on the back step: "Put food in your bowl. A cat comes to eat it!" | cut, 3 s |
| `second_cat` | a second cat is checked in | "Open your Collection [key] to give it a job" | card |
| `stuck_cat` | a stuck cat's "!" is within 30 studs | "A cat is stuck! Hold [key], then tap to free it" | card |
| `tackle` | the first check-in ends the newcomer shield | "Careful: other players can tackle you while you carry a cat" | card |
| `dropped` | the player is knocked loose for the first time | "You dropped it! Grab it again before someone else does" | card |
| `night` | the first dusk warning | "Night closes the areas. Your cats keep earning!" | card |
| `rank_up` | rank up's needs are met for the first time | the camera swings to the Rank Up button or board: "Rank up to open the Park!" | cut, 3 s |
| `golden_fish` | the first golden fish | the camera swings to the Fish Market: "Spend golden fish on crates here" | cut, 3 s |
| `potion` | the first potion | "Drink it from the potion bar for a short boost" | card |
| `dealer` | Tier 2 opens the dealer | the camera swings to the dealer: "The dealer sells cats for coins" | cut, 3 s |
| `luck` | the first luck source, if F88 ships | "Luck makes rare cats more likely. Tap the chip to see why" | card |
| `offline` | the first return after 10 minutes or more away | the existing offline card, with "Your cats earned while you were away!" on top | card |

## 4. Feedback button

- **Where.** A Feedback row at the top of Settings, and a small speech-bubble button on the HUD's top right row from step 5. It opens the existing report window with a new first page.
- **First page.** "How is Cat Cafe so far?" with three big faces: Love it, It's OK, Not for me. A tap sends `SendFeedback(face, chip)` at once, so one tap is enough. Then optional chips (pick one): Too hard, Confusing, Boring, Laggy, Want more cats, Something else. Then an optional "Tell us more" box, which sends through today's `ReportBug(text, "idea")`, filtered and limited exactly as bug reports are.
- **One ask.** Once per account, after FeedbackAskMinutes (12) of play in a session and only between activities, the same three faces slide in at the bottom for 10 seconds with "How is it so far?". Ignoring it is fine and it never comes back. No reward is given for answering, so the answers stay honest and nobody is pushed.
- **No free text in analytics.** The face and chip go to analytics as short fixed values; any text goes only to the report store.
- **Public repo.** The repo is public, so the bug-reports workflow's job log can be read by anyone. Before the ads it must print only counts, kinds, faces and chips, never report text or user ids; the text is read locally with the Open Cloud script or with `Debug.bugReports` in Studio (Tools-Agent).

## 5. Funnel and events

The onboarding funnel (analytics-plan section 3) gets finer steps at the start, so the dashboard shows exactly where new players stop. The game has not launched, so renumbering now mixes no data; the funnel's name gets a `v2` so the alpha's numbers stay apart. Logging order stays honest with the held-back rule in analytics-plan section 3.2.

| Step | stepName | Logged when |
|---|---|---|
| 1 | joined | the profile loads |
| 2 | first_move | the character has moved 8 studs from its spawn |
| 3 | saw_alley | the character enters the Alleyway (today's step) |
| 4 | near_stray | within 12 studs of the tutorial stray |
| 5 | catch_started | the first `GrabBegin` is accepted |
| 6 | first_catch | the first success |
| 7 | first_checkin | the first check-in |
| 8 | first_role | the first cat in a role (now at the first check-in) |
| 9 | second_cat | a second cat checked in |
| 10 | first_table | tables to level 1 |
| 11 | bowl_bought | the bait bowl bought |
| 12 | first_bait | the first food in the bowl |
| 13 | first_bait_resolved | the first bait result |
| 14 | five_cats | five different cats owned |
| 15 | rank_up_ready | Tier 2's needs met |
| 16 | tier_2 | rank up to Tier 2 |
| 17 | first_park_catch | the first catch in the Park |
| 18 | returned_next_day | a join on a later UTC day than the last session ended |
| 19 | first_offline_claim | the first offline claim |
| 20 | tier_3 | rank up to Tier 3 |

New custom events (analytics-plan section 6.4; three fields at most, short fixed values only):

| eventName | value | customFields | Logged when |
|---|---|---|---|
| left_early | seconds played | tutorialStep, device, minutes bucket (0 to 1, 1 to 3, 3 to 10, 10+) | PlayerRemoving while `tutorialStep` is below 5 |
| stuck_nudge | 1 | tutorialStep, kind (pulse, help_shown, show_me) | a nudge or the help card in 2g |
| tip_shown | 1 | tip id, skipped (yes, no) | a context tip shows |
| feedback | 1 | face (love, ok, no), chip (or none), tier | `SendFeedback` |
| intro_choice | 1 | from (tile, help) | the intro is played from the tile or the help card |

`left_early` and the funnel together answer Derek's "where/what step people are getting stuck and quitting": the funnel shows how many reach each step, `left_early` shows which step they were on when they left and how long they stayed.

## 6. Contracts

- **Profile** (next save version): `tipsSeen` (map tip id to true, empty by default), `feedbackAsked` (boolean, false), `stuckHelpShown` (map tutorialStep to true). The funnel state in `telemetry` gets `funnel = 2` so a profile from the alpha starts the new funnel at the step it has reached.
- **Remotes:** `TipSeen(id)`, client to server, 1 per second, `id` from the tip table, sets `tipsSeen[id]` (the server decides triggers it can see itself, such as `night` and `rank_up`, and tells the client with `ShowTip(id)`); `SendFeedback(face, chip?)`, 1 per 10 s and 5 per session, both values checked against fixed lists; `ClearTips()`, 1 per 10 s.
- **Server:** the tutorial stray's catch rules (2b) in CatService; the newcomer shield in ShoveService; the automatic first job (2d) in CafeService, through the same code path as `PlaceCat`; the funnel steps and events (5) in Telemetry.
- **Client and UI:** the small HUD and button unlocks (2f), the device-aware hint, the nudges and help card (2g), the tip queue, cards and camera cuts (3), the feedback page and the one ask (4).
- **Constants:** IntroAutoPlay false, TutorialShrinkSeconds 1.6, TutorialWindowScale 2, TutorialRetrySeconds 1.0, StuckNudgeSeconds 40, StuckHelpSeconds 90, TipGapSeconds 60, TipCutMaxSeconds 4, FeedbackAskMinutes 12.

## 7. Who builds what

- Gameplay-Engineer: 2b, 2c, 2d, the server tips, the remotes, the profile fields and section 5.
- UI-Engineer: 2a's tile glow, 2e, 2f, 2g, the tip cards, the feedback page and the one ask.
- Animation-Engineer or VFX-Agent: the three-second camera cuts (a shared `ContextCut.play(target, caption)` the tips call).
- Tools-Agent: the bug-reports workflow change in section 4 and checking the events in Creator Hub's View Events after the first publish.
- QA-Planner: section 8.

## 8. QA checks

1. A fresh account spawns at its back door with the hint and trail showing and no intro; the "?" tile glows twice and plays the intro.
2. The first catch: a Miss brings the circle back after 1 s with "Try again!" and the cat stays; another player cannot start a catch on it.
3. Carrying the first cat, a second player cannot shove or tackle the beginner; after the first check-in they can.
4. The first check-in puts the cat in the free Waiter slot with the card, and step 3's hint shows.
5. Until step 5 the HUD shows only the pieces in 2f, and each new button pops in with "New!" when it unlocks.
6. On a phone the hints say "tap and hold", never a letter key; on a gamepad they show the button glyph.
7. Standing still for 40 s pulses the hint; at 90 s the help card shows once for that step.
8. Each context tip shows once, never during a catch or carry, never two within 60 s; "Show tips again" in Settings brings them back.
9. The face buttons send with one tap; the slide-in ask comes once after 12 minutes and only between activities. It never comes back.
10. In the published dev place, Creator Hub's View Events shows the v2 funnel steps in order and `left_early` with the step when a fresh account leaves after the first catch.
11. The bug-reports job log shows no report text and no user ids.
