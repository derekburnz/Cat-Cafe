# The Rescue Rally weekend (F101)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek, 2026-10-30 00:38: "the game needs some sort of other type of content on the side like a limited event don't make it halloween as that's going to be passed start brainstorming other ways to use your cat team maybe battling event for rewards or something or some sort of group content with your friends to get rewards together not sure yet". His release rule of 2026-11-01 22:59 puts it before release. Cat team battles are the bigger idea and wait on Set 6 Q10.

The Rally is the group content: for two days, everyone in a server fills one bar together and everyone who helped gets the prizes. It uses only things already built (catching, rescues, Team Rescue from F92), so it is cheap to make, and every weekend it gives players a reason to come back and play at the same time, which is what Roblox's co-play ranking counts.

## 1. When

- **Every weekend,** from Saturday 00:00 to Monday 00:00 UTC. It falls inside the ads week whatever day the game launches.
- **Friday:** a "Rescue Rally tomorrow!" line on the What's New board and a countdown chip on the HUD clock for the last 12 hours. Players who turned on experience notifications (13 and up) get one notification when it starts; this waits on the Open Cloud notifications permission and was not in #809. Notifications never gate anything.
- `Config.RallyForce` turns it on at any time for testing.

## 2. The bar

- One bar per server. Points come from what players already do:

| action | points |
|---|---|
| a cat checked in at a camp (caught or carried) | 1 |
| a bait cat tamed | 1 |
| a stuck cat rescued | 3 |
| a Team Rescue (F92) | 3 to the rescuer and 3 to each helper |

So two friends doing Team Rescues together fill it twice as fast as one player alone, and a rescue at night is worth three catches.
- **As built (#809):** a rescued cat scores the rescuer its 3 when it is checked in, in place of the check-in's 1, so a rescue never scores 4. A Team Rescue helper scores their 3 when the cat is freed, since their part ends there.
- **The goal** is RallyPointsPerPlayer (30) times the number of players in the server, never fewer than 3 players' worth (90). It is fixed when the lap starts, so a player leaving does not move it. With 8 players a lap takes about an hour.
- **Steps** at 25%, 50% and 100%. At 100% the bar empties and the next lap starts ("Rally 2", "Rally 3").

## 3. Prizes

Every player in the server when a step is reached gets its prize, as long as they scored at least RallyMinPoints (3) in the current lap. So someone who hops in at 99% gets nothing for that step, and an idle player gets nothing.

| step | prize |
|---|---|
| 25% | 5 golden fish |
| 50% | 10 golden fish and a Money Potion (`tip_potion`, 10 minutes, into the bag) |
| 100% | a Rally Crate and 15 golden fish |

- A player can earn prizes from at most RallyMaxLaps (4) laps a weekend (a lap counts toward the 4 the first time it pays that player, so its later steps still pay them), so it is a nice weekend goal and not an all-night grind. After that they still help the server's bar and see "You've done your laps this weekend" on the banner.
- **The Rally Crate** holds twelve pieces made for it (two of each kind, plus a door set and a cat flap, like every crate): pennant wallpaper, a running-track floor, team-stripe paint, a trophy shelf, cheer bunting, a medal door and so on, at the Classic Crate's rarity odds. It only comes from the Rally and comes back every weekend, so nothing is truly limited (the shop rule recorded 2026-11-01). It has its own page in the Decor Index with the same prizes as the other pages: `decor5` (5 pieces) pays 25 golden fish and `decor10` (all 12) adds +5% money forever, so a full Decor Index is +70% (as built in #804, kept 2026-11-02: the crate only comes from weekends, so the page is as hard to fill as any other).
- Nothing about the Rally is sold for Robux, and nothing skips or speeds the bar.

## 4. What players see

- **The banner** in the HUD's reserved event spot (top centre, under the travel row): "Rescue Rally" with the bar, three step icons, the lap number and the time left in the weekend. Each point anyone scores pops a small "+1" into the bar; your own points pop a paw from your side. At each step a short cheer plays and the prize toast follows (F94, at most two pictures).
- **The Town Square** gets bunting in the Rally colours and a big Rally board by the cannon showing the bar, so players in town see it too.
- **The cannon picker** shows "Rally: rescues x3" on every card at night, when the stuck cats are out.
- **Reduce Motion:** the "+1" pops and the bunting's flutter stop; the bar still fills.

## 5. Contracts

- Save: `rally = { weekend: number, laps: number }` (the weekend number and the laps this player has been paid this weekend). The bar itself is the server's and starts again if the server restarts.
- Config: `RallyStartWeekday` 6 (Saturday, UTC), `RallyHours` 48, `RallyPointsPerPlayer` 30, `RallyMinPlayers` 3, `RallyMinPoints` 3, `RallyMaxLaps` 4, `RallyPoints` (check-in 1, tame 1, rescue 3, team rescue 3), `RallyForce` false.
- Remotes: `RallyState` (server to client) with `{ active, endsAt, lap, goal, points, myPoints, lapsPaid }`, sent on join, at each step and at most twice a second while points come in; `RallyPoint(userId, amount)` to all clients for the pops. The server scores points from its own events; no client remote adds points.
- Assets: the Rally banner art and step icons (UI-Engineer), the Rally board and bunting (Model-Agent), twelve Rally Crate pieces with a before and after sheet (Model-Agent), cheer and step sounds (Sound-Agent), the bar pops and bunting flutter (VFX-Agent).
- Analytics: `rally_step` with the step, lap and players in the server; `rally_points` per player at weekend end.

## 6. QA checks

1. With RallyForce on, the banner shows in every server and the goal is 30 times the players (90 with one or two players).
2. A Team Rescue gives 3 points to each player in it; a camp check-in gives 1.
3. A player who joins at 95% and scores 1 point does not get the 100% prize; one who scored 3 does.
4. After four paid laps, a fifth lap pays that player nothing and the banner says so.
5. The Rally Crate opens with the Classic Crate's odds and its pieces show on their own Decor Index page.
6. At Monday 00:00 UTC the banner goes in every server and the save's `rally.laps` resets the next weekend.
7. Firing any remote cannot add Rally points.
