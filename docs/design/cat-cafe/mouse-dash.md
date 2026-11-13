# Mouse Dash (#3296): the Cat Arcade's new game, replacing Circle Streak

Draft v2, 2026-11-11, Design-Agent; as built in 4a and 4b (updated 2026-11-13). This replaces [new-activities.md](new-activities.md) section 4 (the paused v1: six holes, one miss ends the run, milestones to 50).

Derek, 2026-11-11 23:30 UTC: "build mouse dash if making it high enough quality it honestly should replace the current game". Earlier (Derek2, 2026-11-11): "arcade game 1 free attempt daily". The game is a player's idea and keeps its credit line on the card.

Builders: Gameplay-Engineer (server, shared module, window), Model-Agent (the picture sheet), Motion-FX-Agent (effects and sound). Review-QA-Agent reviews and plans the playtest.

## 1. What it is
A whack-a-mouse game in the arcade window. Mice pop out of nine holes and you bop them with a cat paw before they duck back in. It gets faster as you score, you have three hearts, and 100 points wins. A run lasts from about 15 seconds for a new player to about 90 seconds for a full win.

Why this version can carry the arcade where v1 could not:
- **Three hearts, not one miss.** A new player gets a real go instead of a three second run. Circle Streak ends on the first miss.
- **Four things to read, not one:** grey mice, golden mice, napping kittens you must leave alone and two mice at once.
- **Its own look and feel:** a paw that bops, mice that squash, a cheese cellar backdrop. Circle Streak is the catch circles again.
- **The same 0 to 100 scale, prizes and title as Circle Streak,** so it takes over with nothing lost (section 8).

## 2. A run
- **Board:** nine holes in a 3 x 3 grid inside the arcade window. Every hole's tap area is at least 64 px on the smallest phone and the areas never overlap.
- **Mice:** the server pops one up in a hole for a short window. Tap it in time for **+1**. The next one comes a short gap after the catch or after the window ends, so quick taps make a quicker run. The same hole never comes twice in a row.
- **Hearts:** you start with **3**, shown as paw pads. A mouse that gets away costs one. At 0 the run ends. Every **10 catches in a row** gives one heart back, up to 3.
- **Golden mouse** (from 10 points, about 1 in 12): up for three quarters of the normal window, worth **+3**. Missing it costs no heart, so it is only ever good news.
- **Napping kitten** (from 20 points, about 1 in 8): a sleeping kitten with "Zzz" pops up instead of a mouse. Leave it alone and it ducks back with no cost. Tapping it costs a heart. Never two kittens in a row.
- **Two at once** (from 30 points, 1 in 5): two holes pop together, each with its own window. From 40 points one of the two can be a kitten.
- **A tap on an empty hole** costs no heart. The paw is dizzy for 0.4 s and taps in that time do nothing. This is what stops button mashing, and the server enforces it.
- **Win:** 100 points ends the run as a win (a golden mouse from 98 shows 100).
- **No Robux anywhere:** no extra heart, continue, skip or speed-up is sold. Nothing is random that costs anything. No near-miss teasing: an escaped mouse just ducks away.

### 2a. Getting harder
Every 5 points, up to 100:

| | Start | Each step | Floor |
|---|---|---|---|
| Mouse window | 1.10 s | x0.93 | 0.40 s (reached at 70 points) |
| Gap before the next mouse | 0.50 s | x0.95 | 0.25 s |

That is a 0.76 s window at 25 points and 0.53 s at 50. The floor is 0.40 s (v1 said 0.35) because a phone's tap plus the trip to the server needs it.

### 2b. The first run on an account
The first three mice of a player's first ever run are slow (2.0 s windows), with a pointing hand on each, and cannot cost a heart. The first kitten a player ever sees gets a one line hint: "Let sleeping kittens nap!". No other tutorial.

## 3. Cost, prizes and records
- **Cost:** the first run each UTC day is free. Later runs cost 1 golden fish (`GoldenFish.spend`). The button reads "Play (free)" or "Play (1 golden fish)". Mouse Dash keeps its own free run day (section 8).
- **Milestones are the arcade's, shared with Circle Streak.** The ten milestones at 10 to 100 points (`Config.ArcadeMilestones`) pay once per UTC day each, whichever game reaches them first. A day still pays at most 58 golden fish and one each of the item prizes, so a second game adds no golden fish to the economy. The card shows the same list with today's ticks.
- **Titles:** 100 points gives **Arcade Legend**, the same title and the same saved flag as Circle Streak. 50 points in Mouse Dash gives **Mouser** (once, kept): a chat title in `ChatTags` with a `TitlesLogic.HOW` line "Mouse Dash 50 points".
- **Records:** best points, then fastest time: score = points x 1000 + (999 - seconds, held between 0 and 999). Its own all-time board, top 10 across servers plus this server's best, as Circle Streak has now. Owner accounts stay off it (#3321). Written only on a new best and at most once per 60 s. No bot check for now (Derek2: "not worried about bots yet").

## 4. Server authority
- The server draws the run in blocks (as `Arcade.block` does): for each pop its hole, its kind (mouse, golden, kitten), its window and the gap after it. The timeline moves on from a judged catch or from the window's end.
- The client sends only `MouseDashStart()`, `MouseDashTap(run, index, hole)` and `MouseDashQuit(run)`. It never sends a score, a time or a kind.
- Each tap is judged on the server's clock, with the same allowance for ping as a catch press (half the round trip, at most `CatchLatencyCapSeconds`). The server checks the types, that the run is the caller's and live, that `index` is the pop now up, that `hole` matches and that the paw is not dizzy. A tap for a pop that is gone is ignored, not punished twice.
- Rate limit: taps at most 12 a second, start and quit 1 a second.
- The same start checks as Circle Streak: the switch on, the save read, no game running, not in a catch, rescue or flight, no trade freeze on fish.

### 4a. As built (Gameplay-Engineer, PR #3401, agreed 2026-11-11)
- The server draws **one wave at a time**, when it starts, not blocks, so a client never knows a hole early. `index` in `MouseDashTap` is the wave.
- Each mouse of a pair gets **1.35 times the window**, so one thumb can reach both at the 0.40 s floor.
- A wave with a mouse and a kitten ends when the mouse is caught or gone, and the kitten ducks back with it. A kitten alone stays its whole window.
- The streak for the heart back breaks on an escape or a tapped kitten. An empty-hole tap does not break it.
- A golden mouse is up for max(0.75 x the wave's window, the 0.40 s floor): the floor applies after the golden scale, so it is never shorter than a phone can manage. A golden mouse that gets away does not break the streak; only a grey mouse escaping or a tapped kitten does.
- Ping allowance: the full round trip, at most `CatchLatencyCapSeconds` (0.15 s), because the pop also has to travel to the client. (Section 4 said half.)
- A first run's three safe mice break nothing when missed: no heart and no streak.

### 4b. Changed on launch night (Derek on the live game, 2026-11-12; PRs #3714, #3723)
- **Every miss costs a heart** ("make them always cost lives"). A tap on an empty hole now costs a heart and the paw is still dizzy for 0.4 s (`MouseDashDizzySeconds`); a tap while dizzy does nothing. This replaces section 2's "costs no heart". An escaped mouse and a tapped kitten cost one as before.
- **A run clock** ("make a timer for how long left in the minigame"): a run has `MouseDashRunSeconds` 180 from its first mouse, counted down on screen. A perfect win takes up to about 110 s, so the clock only ends a slow run. A run that ends on the clock ends as `time`, pays its milestones like any other end and plays the end sound.
- **The card** follows the arcade mock (#3553): a lit sign, the free play pill, the records, the next prize with its picture, a big green Play button, and Prizes and Leaderboard buttons that each open their own list.
- **While playing** a banner shows only the next prize from the current score. The banners sit in the window's header, never over the holes (#3766).

## 5. Look, feel and controls
The bar is "would you play this again right away". These are part of the build, not polish for later.
- **Backdrop:** a cosy cheese cellar in the arcade's neon colours, low contrast so the mice are the brightest thing on screen.
- **The paw:** your cat's paw bops the hole you tap. A catch squashes the mouse and pops a "+1" (a gold "+3" for a golden mouse).
- **Read at a glance:** hearts as three paw pads top left, the score big at the top centre, best at the top right. A "Faster!" banner on each speed step. Nothing else on screen during a run.
- **End card:** points, best (with "New best!"), today's milestones and one big "Play again" button with its cost. Only the window's X closes it.
- **Controls:** tap or click a hole. Keyboard: Q W E, A S D, Z X C for the nine holes. Gamepad: the left stick points at a hole (resting is the centre hole) and A bops it.
- **Keep the holes clear (Derek, 2026-11-11 23:44 UTC, on the art preview: "the top left symbol is a little too close to the possible spawn and distracting"):** nothing that draws the eye sits near a hole. Backdrop shapes (cheese wheels, wedges, rings) stay at least half a hole's width away from every hole and from anything that can pop out of one, and stay low contrast. The hearts, score and best sit in their own strip beside the board, never over it. As built (#3405): the strip is on the left of a wide board and on top of a tall one, and always at least 24 px clear of the holes.
- **Everything is centred (Derek, 23:45 UTC: "some of the kittens/things look off centred also so make sure thats fixed for the game"):** every mouse, kitten and dust puff is centred on its hole, left to right, and each picture's pivot is the middle of its base so pictures of different widths line up. "Zzz", "+1", "+3" and stars are drawn as separate pieces so they never push a picture off centre.
- **Reduce Motion:** no screen shake and no squash, the pops still show.
- Checked on phone, tablet, desktop and console.

### 5a. Pictures (Model-Agent)
One sheet, Cozy Cream style, thick outlines, readable at 64 px: grey mouse (peeking, up, squashed), golden mouse (the same three), napping kitten with "Zzz", a hole (empty and with a dust puff), the cat paw (ready and bopping), a heart paw pad (full and empty) and the cheese cellar backdrop. Uploading the sheet needs Derek's OK on a picture first. Until then the build uses UI-drawn stand-ins, so nothing waits on it.

**As drawn (Model-Agent, PR #3400, 2026-11-11):** the sheet matches this list with these differences. "Peeking" has no picture of its own: it is the up picture slid a third of the way out between the Hole and HoleFront pictures. The dust puff is a separate Dust picture laid over the hole. The hearts are paw-print hearts. Extra pictures: a woken kitten (for a tapped kitten), a cheese wedge for the score and a game picture for the arcade tab. The cellar floor is the arcade's purple with cheese shapes.

### 5b. Effects and sound (Motion-FX-Agent)
| Moment | Effect | Sound |
|---|---|---|
| Mouse pops up | quick rise with a small bounce | soft pop |
| Catch | paw bop, squash, "+1" | squeak that climbs a little with the streak |
| Golden mouse up | sparkle trail | bright chime |
| Golden catch | gold burst, "+3" | richer squeak and chime |
| Mouse gets away | dust puff, one heart pad empties | small down-slide, never a harsh buzz |
| Kitten up | "Zzz" drifts up | soft purr |
| Kitten tapped | kitten blinks awake, one heart pad empties | gentle "mrow?" |
| Empty hole tapped | paw wobbles with stars for 0.4 s | soft thud |
| Heart back (10 in a row) | the pad refills with a pulse | warm two note rise |
| Speed step | "Faster!" banner | quick rising tick |
| Milestone | the arcade's milestone ring | the arcade's milestone sound |
| End of run | "Nice try!" card | the arcade's end sound |
| New best or win | confetti | short fanfare |

No flashing above 3 Hz.

## 6. Numbers (new Config values)
| Name | Value |
|---|---|
| MouseDashHearts | 3 |
| MouseDashStepEvery | 5 |
| MouseDashWindowStart, WindowStep, WindowFloor | 1.10, 0.93, 0.40 |
| MouseDashGapStart, GapStep, GapFloor | 0.50, 0.95, 0.25 |
| MouseDashGoldenFrom, GoldenChance, GoldenPoints, GoldenWindowScale | 10, 1/12, 3, 0.75 |
| MouseDashKittenFrom, KittenChance | 20, 0.125 |
| MouseDashPairFrom, PairChance, PairKittenFrom | 30, 0.20, 40 |
| MouseDashHeartBackEvery | 10 catches in a row |
| MouseDashDizzySeconds | 0.40 |
| MouseDashFirstRunMice, FirstRunWindow | 3, 2.0 |
| MouseDashMouserAt | 50 |

Shared with Circle Streak: `ArcadeMaxPoints` 100, `ArcadeCostFish` 1, `ArcadeMilestones`.

**Judge by (first week):** the median run is 10 to 15 points, and about 1 run in 100 reaches 80. Three hearts make this kinder than Circle Streak, so watch the share of daily players paid the 50 milestone: if it is more than 1.5 times Circle Streak's, make the game faster (window start 1.00, floor 0.36). Never cut the prizes.

## 7. Saves, switches and restarts
- **No restart is needed and the profile save does not change.**
- Mouse Dash's own record lives in a new DataStore, `CatCafe_MouseDash`: `{ best, bestSeconds, runs, freeDay, mouser, seenKitten, firstRunDone }`. Older servers never read or write it, so they cannot drop anything.
- The day's paid milestones and the Arcade Legend flag stay where they are, in the arcade's existing save (`day`, `paid`, `legend` in `CatCafe_Arcade`). Older servers already keep those fields, so a milestone can never pay twice while old and new servers run side by side. That matters now, with no restarts.
- Its board is a new OrderedDataStore, `CatCafe_LB_MouseDash1`.
- Switches (LiveFlags are on or off only): `mouseDash` starts off (`OFF_BY_DEFAULT`) and turns the game on at the swap. `circleStreak` starts on and goes off at the swap (section 8). There is no `mouseDashMain`.
- **One thing for the engineer to check:** an older server does not know the Mouser chat title. If picking it on a new server and then joining an old one would wipe the player's chosen title, hold the Mouser title back until the next restart Derek approves. Everything else ships without it.

## 8. The swap: Mouse Dash replaces Circle Streak, which is vaulted
Derek, 2026-11-11 23:51 UTC, on the art preview: "Swap this in for the current arcade game and vault the other one", then "make sure the rewards/leaderboard stuff still works". This replaces the first plan here (both games side by side for a few days, then a measured switch).

**What happens**
1. Mouse Dash is built behind `mouseDash`, off, and passes review and the QA playtest.
2. **The swap is one step:** `mouseDash` goes on and a new switch `circleStreak` goes off. From then the cabinet, the menu row and the arcade window open Mouse Dash, and Circle Streak cannot be started. There is no side by side period and no second tab.
3. **Vaulted means kept, not deleted.** Circle Streak's code, pictures, effects, saves and board all stay. Turning `circleStreak` back on brings it back as it was, so the swap can be undone in one step.

**Rewards, leaderboard and titles through the swap (these must keep working)**
- **Daily prizes:** the ten milestones at 10 to 100 points are the same list, on the same daily tick, in the same save. A player who was paid the 10 and 20 milestones in Circle Streak today and then plays Mouse Dash after the swap is paid from 30 on and never twice. The card shows the same list with today's ticks.
- **Arcade Legend:** everyone who has the title keeps it, in chat and in the Bag. Mouse Dash awards it at 100 points from the swap on. It is the same saved flag.
- **Leaderboard:** the arcade's leaderboard button, the server's best line and the "new best" moments all work in Mouse Dash from the first run, on its own board (`CatCafe_LB_MouseDash1`). The board starts empty because the two games' scores cannot be compared.
- **Circle Streak's records are not erased:** its board is frozen and shown as a "Circle Streak Hall of Fame" page in the leaderboard panel (its top 10 and your own best).
- **Anything else that reads the arcade board** (crowns, rank titles, the What's New line, `arcade_board_top`) reads Mouse Dash's board after the swap. The engineer lists what does and checks each one.
- **Free daily run:** one a day, Mouse Dash's.
- **Golden fish cost:** unchanged, 1 a run after the free one.

**While there are no restarts:** servers that started before the build do not have Mouse Dash and keep offering Circle Streak until they close on their own. That is safe: both games pay from the same daily list, so nothing pays twice, and the title is the same flag. A player may get one free run in each game on such a day.

**Numbers:** arcade_v1 keeps its name and six steps, so the history runs on and Growth can compare Mouse Dash with Circle Streak's days before the swap. Step 4 becomes "first hit in a game". `arcade_run`, `arcade_quit` and `arcade_blocked` carry the game ("circle" or "mouse"). New: `mouse_dash_run` with points, hearts lost, seconds and free or paid. If after 3 days fewer players start a run or play again than did with Circle Streak, Design-Agent tunes the speed first (section 6) and tells Derek.

What's New and the cabinet sign say "New game: Mouse Dash".

## 9. Test plan for the build
- **The swap keeps rewards and the leaderboard working:** on one account reach 10 in Circle Streak, do the swap, then reach 10 and 20 in Mouse Dash: 10 pays nothing more and 20 pays once. An account with Arcade Legend still has the title after the swap. A Mouse Dash best shows on the leaderboard button and the server's best line, and the Hall of Fame page shows Circle Streak's top 10 and your best.
- After the swap Circle Streak cannot be started from the cabinet, the menu row or its remotes. Turning `circleStreak` back on brings it back with its records.
- Three escapes end the run. Ten catches in a row refill one heart and never go above 3.
- A missed golden mouse costs no heart. A tapped kitten costs one. A left kitten costs none.
- Taps while dizzy do nothing. Mashing all nine holes scores worse than playing.
- A forged tap (wrong run, wrong index, wrong hole, late, 50 a second) never scores.
- Score 100 gives Arcade Legend once. Score 50 gives Mouser once.
- With `mouseDash` off there is no tab and the remotes refuse.
- Old server and new server side by side: nothing pays twice and nothing errors.
- Phone, tablet, desktop (mouse and keys) and gamepad all play. Reduce Motion works.
- A screenshot with all nine holes filled (mice, golden mice and kittens) shows every one centred on its hole and no backdrop shape within half a hole's width of a hole.
