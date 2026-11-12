# AFK in your cafe

Asked by Derek on 2026-11-12 13:06 UTC: "no afk kicking inside cafe/right outside it (the area when you teleport) and have a little gentle text saying something like 2x rewards while afk in cafe and cats earn offline ... so we can have people afk the game more (publish this when its ready no restart)". Owner: game-designer. Build: #3573, behind the switch `afkCafe`. Built in #3587 (server and pay) and #3578 (chip); the party wording of the once a visit line is in #3598.

## 1. In one paragraph

A player who stands still in their own cafe, or on its doorstep, for 2 minutes earns double pay from their cats until they move again. A small chip says so. Nothing else changes, and offline pay is as before.

## 2. The AFK zone

The player's own cafe (inside its walls) and its doorstep, the spot where a teleport home lands, about 12 studs around it. The server decides. Another player's cafe does not count.

## 3. What counts as AFK

In the zone with no input (move, jump, camera, tap, key, button, chat) for `Config.AfkCafeSeconds` (120). The client reports idle time; the server checks the zone and that the character has not moved. Not AFK while moving, carrying a cat, in a catch, a rescue, a trade or a mini game. Any input ends it at once.

## 4. The 2x

- It doubles the pay the player's own cats earn in the cafe (the per second cafe income).
- It works the same as an event money boost: it multiplies the whole cafe settle, including the extra paid seconds a timed tip potion adds (build answer on #3573, 2026-11-12).
- It does not touch the till's collected tips and rich tips, serving, golden fish, the Fish Pond, crates, quests, the Rescue Rally, Cafe Pass progress, playtime gifts, Trait Tokens or luck.
- While a player rests, each cat's own per-second label stays at base pay; only the cafe total doubles, as with an event boost.
- A rest carries on through nightfall and sunrise. Only the player's own input or leaving the zone ends it.
- It sits in the party's money boost slot and never goes above `EventMoneyMax` (2). During a 2x party it adds nothing. Money passes and money potions multiply as always.
- Offline pay is unchanged: half for up to 8 hours, full for up to 16 with Long Nap. The AFK 2x never applies offline.
- Playing must still pay more than resting. Growth-Agent checks after a week; if resting wins at any tier the 2x comes down.
- Server side. The server needs the zone, no movement and no actions before it pays double.

## 5. The kick

Roblox itself disconnects a player after 20 minutes with no input, and a game cannot switch that off. The only way round it is to rejoin the player automatically, which sidesteps a Roblox rule. Derek said no to that on 2026-11-12 13:10 UTC, then reversed it at 14:36 UTC: "add auto rejoin" and "make sure they auto rejoin at their cafe back in the auto rejoin 2x money area".

**Auto rejoin (#3602, PRs #3603 and #3607, switch `autoRejoin`, off by default).**
- Only a player who is resting in their own cafe or on its doorstep is sent back into the game, shortly before Roblox's idle disconnect (`Config.AutoRejoinSeconds`). Nobody who is playing is moved.
- They land at their own cafe inside the rest zone and the rest and its 2x carry on without the 2 minute wait.
- The rejoin is quiet: no Welcome back card, no top 10 join line, the rest line is not said again, and every ask (invite, Interested prompt, tips) waits for the player's first input.
- Pay is never doubled up: the seconds of the hop are paid once at the offline rate. Boosts, potions and timers run by the clock and carry on. Gifts counted by account play time or once per account do not restart.
- The Tip Jar's twelve session gifts restart on a rejoin, as on any leave. It cannot be farmed, since a claim needs input and input ends the rest. Carrying them over is a follow-up if players ask.
- Not in Studio and not in private servers. It has to be proven once in the live game, since teleports do not run in Studio.
- Roblox has no written rule on this that we found (checked 2026-11-12). Each rejoin counts as a new visit and a new session, so visits rise and average session length falls for resting players; Growth-Agent reads the numbers with that in mind once the switch is on.
- The words still never say or suggest that a player will not be kicked.

## 6. The words

1. Chip by the money while the 2x is on: "Cozy cafe: 2x cat pay 💤". Gone the moment the player moves. During a 2x party it reads "Cozy cafe 💤".
2. Once a visit, the first time into the cafe, not in the first session's tutorial, fading in about 6 seconds: "Rest here any time. Cats earn 2x while you're AFK in your cafe, and they keep earning while you're offline." During a 2x party the number is dropped, as on the chip: "Rest here any time. Your cats keep earning while you're AFK in your cafe and while you're offline."
3. Back from AFK: "Welcome back! Your cats earned [amount] while you rested 💤".

Gentle. No timer, no arrows, nothing that says to stay or that anything is lost by leaving, nothing sold beside it. Look: a small cream chip with the dark outline in the HUD's quiet zone and a slow "z" drift (Motion-FX-Agent).

## 6a. The banner, reworked (#3701)

Status 2026-11-12: spec, not built yet. Derek, 22:07 UTC: "the message that pops up about stay in cafe for 2x money only pops up once not everytime your in cafe and also gets cut off make it more obvious redo the banner and shorter clear message". When this is built it replaces lines 1 and 2 of section 6; line 3 (the welcome back toast) stays. Layout draft in the Library: `Design-Agent/for-derek-2026-11-12/cafe-rest-banner.png`.

One banner, three states, same spot (top centre, under the HUD's top row)

A cream pill with the dark outline, a round "2x" badge on the left, one big line and one small line.

| State | When | Big line | Small line |
|---|---|---|---|
| 1. Welcome | each time the player enters their own cafe or its doorstep | Stand still for 2x money | Your cats earn double while you rest |
| 2. Counting | while the player has not moved, until the rest starts | 2x money in 1:20 | Almost resting |
| 3. Resting | while the 2x is on | 2x money ON | Resting in your cafe |

- **State 1** shows on every entry, for 5 seconds, then fades. Not more than once every 60 seconds, so walking in and out of the door does not flash it. It is no longer once a session.
- **State 2** appears after 10 seconds without moving and counts down to the start of the rest (`Config.AfkCafeSeconds`). Any move ends it. The time is the client's own count; the server still decides when the rest really starts.
- **State 3** is green and stays while the rest lasts. It replaces the small rest chip of #3578 (one thing on screen, not two). Gone the moment the player moves.
- **During a 2x party** (or any time the party slot is already at 2): state 1 reads "Rest here, cats keep earning" with small line "Even while you are away", state 2 is skipped and state 3 reads "Resting in your cafe" with no number. The banner never promises a 2x the player will not get.
- The "Welcome back! Your cats earned [amount] while you rested" toast stays as it is.

### Never cut off

- The big line is at most 26 characters in English. The pill is as wide as its text, up to the screen width less the safe area; past that the text wraps to a second line and then shrinks to the UI gate's smallest size. It is never clipped.
- UI gate scenes: 667 x 375 phone, 705 x 338 phone, tablet, desktop, each with the three states.

### Kept gentle

- No arrows, no pulsing, no sound on state 1. Nothing that tells the player to stay or that anything is lost by leaving. Nothing sold beside it.
- Not shown in the first session's tutorial, and never over an open window or a minigame.
- It never says or suggests the player will not be kicked.

## 7. Numbers and checks

- Telemetry: `afk_start`, `afk_end` (seconds), `afk_pay` (coins).
- Standing still in the cafe or on the doorstep for 2 minutes gives the chip and exactly double cat pay, ended by any input.
- Never above 2x in a party. Nothing changes with `afkCafe` off or outside the zone.
- The three lines fit a 705 x 338 phone and stay off the goal card.
