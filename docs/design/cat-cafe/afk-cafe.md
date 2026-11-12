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

Roblox itself disconnects a player after 20 minutes with no input, and a game cannot switch that off. The only way round it is to rejoin the player automatically, which sidesteps a Roblox rule. Derek said no to that on 2026-11-12 13:10 UTC. So the kick stays, we add none of our own, and the words never say or suggest a player will not be kicked.

## 6. The words

1. Chip by the money while the 2x is on: "Cozy cafe: 2x cat pay 💤". Gone the moment the player moves. During a 2x party it reads "Cozy cafe 💤".
2. Once a visit, the first time into the cafe, not in the first session's tutorial, fading in about 6 seconds: "Rest here any time. Cats earn 2x while you're AFK in your cafe, and they keep earning while you're offline." During a 2x party the number is dropped, as on the chip: "Rest here any time. Your cats keep earning while you're AFK in your cafe and while you're offline."
3. Back from AFK: "Welcome back! Your cats earned [amount] while you rested 💤".

Gentle. No timer, no arrows, nothing that says to stay or that anything is lost by leaving, nothing sold beside it. Look: a small cream chip with the dark outline in the HUD's quiet zone and a slow "z" drift (Motion-FX-Agent).

## 7. Numbers and checks

- Telemetry: `afk_start`, `afk_end` (seconds), `afk_pay` (coins).
- Standing still in the cafe or on the doorstep for 2 minutes gives the chip and exactly double cat pay, ended by any input.
- Never above 2x in a party. Nothing changes with `afkCafe` off or outside the zone.
- The three lines fit a 705 x 338 phone and stay off the goal card.
