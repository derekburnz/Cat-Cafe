# Update launch, Thursday 2026-11-12 (#3420)

Draft v1, 2026-11-12, Design-Agent. Builder and lead: Gameplay-Engineer. Banner look, motion and sound: Motion-FX-Agent (#3419). Pictures, the Roblox event page, the group post, thumbnails and ads: Model-Agent and Growth-Agent.

Derek, 2026-11-12 00:50 UTC: "setup event for update for tomorrow at 5 pm, make that the release of cat traits wizard/pool station and new arcade game and whatever other big change I am missing ... When you push the update at that restart servers and run a 1 hour event of our boosts and a couple other things like global 2x money booster for an hour and a giveaway of 100 gold fish to everyone 3 minute after restart with an announcement banner telling them."

**When:** Thursday 2026-11-12, 5:00 PM Toronto time, which is 22:00 UTC. The party ends at 6:00 PM Toronto (23:00 UTC).

Almost everything here uses what is already built: Cafe Events ([live-events.md](live-events.md)), the update gift (`shared/UpdateGift`, #2997) and the restart warning. The only new pieces are the banner (#3419), a gift notice and some words.

## 1. What the update contains
The headline three, in this order everywhere they are listed:
1. **The Mystic Pool** ([trait-station.md](trait-station.md)): Sage Sorrel the wizard cat and the pool that gives a cat a trait. Switch `traits` on.
2. **Mouse Dash** ([mouse-dash.md](mouse-dash.md)): the new Cat Arcade game. Switch `mouseDash` on and `circleStreak` off in one step (Circle Streak is vaulted).
3. **Rich customers leave money bags** ([rich-money-bags.md](rich-money-bags.md)): already live since 2026-11-11, but new to most players, so it is named in the update.

Also new since the last update, one line each where a list has room: Swift Paws has 5 speed levels, a free Arcade game every day, the Cat Arcade leaderboard, Rank #1, #2 and #3 chat titles and the Titles tab in the Bag, shorter nights.

**If a headline feature is not ready:** the go or no-go is at 20:00 UTC (two hours before). A feature that has not passed review and QA by then stays switched off, and its name comes out of the banner, the event page and the group post. The launch still happens at 22:00 UTC with what is ready. Nothing is switched on without its pass, launch or not. Gates still open as of this draft: Mouse Dash needs its QA pass (the `circleStreak` switch merged in #3405), and `traits` needs its Pace gate and QA pass.

## 2. The order of steps
All times UTC on 2026-11-12. This is the one restart Derek approved; the rule of no other restarts stands.

| When | Step | Who |
|---|---|---|
| by 19:00 | Schedule the party (section 3) so the in-game countdown shows from T-3h. The Roblox event page and the group post are up before this | Gameplay-Engineer, Growth-Agent |
| 20:00 | Go or no-go on each headline feature (section 1) | Gameplay-Engineer with Review-QA-Agent |
| about 21:45 | The last publish is on main, with `Config.UpdateGift` set (section 4). Record the player count | Gameplay-Engineer |
| 21:50 | Restart warning starts (10 minutes, 2 minutes, 30 seconds, now) | restart workflow |
| 22:00 | Servers restart. The party starts in every server on the shared clock | restart workflow, EventService |
| 22:00 | Right after the restart call: `traits` on, `mouseDash` on, `circleStreak` off. Record the player count 30 to 60 seconds after | Gameplay-Engineer |
| 22:00 to 22:03 | The gift notice shows to everyone in game and to anyone who joins (section 4) | server |
| 22:03 | 100 golden fish to everyone, with the gift banner | server |
| 23:00 | The party ends. It is never extended | EventService |

If the restart runs late, the party still ends at 23:00 and the gift still pays at 22:03 on every server running the new version. Neither is moved after it is announced.

## 3. The 1 hour party (a Cafe Event record)
One record through `events.sh add`, no new code:

| Field | Value |
|---|---|
| id | `update-1112` |
| title | `Update Party` |
| start, length | 2026-11-12 22:00 UTC, 60 minutes |
| big | false (so Saturday's weekly Cafe Party is still allowed) |
| money | 2 |
| luck | 0.5 |
| days | lucky, golden, rainbow |
| showers | count 4, gapSeconds 900, firstAfter 600 (at 10, 25, 40 and 55 minutes: 2 Rainbow Legendaries, 2 Mythicals) |
| reward | none (the gift in section 4 is this party's present) |

- **"Global 2x money booster" is the party's `money = 2`.** It is the same boost, for everyone in every server, and it is the cap (`EventMoneyMax`). There is no second x2 on top of it.
- It counts for cats' work, tips, rich money bags and the tip jar. It does not count for offline income, sales, prizes or golden fish (live-events.md 2b).
- Pace: this adds one extra hour of x2 this week next to Saturday's party. That is a one-time launch extra, inside the Pace case of one 2-hour x2 window, so no costs change.
- All of live-events.md section 6 holds: nothing is sold in the party, no purchase prompts during the hour, the end time always shows, and no text names a pass or a stacked number next to the party.

## 4. The gift: 100 golden fish for everyone
Uses the update gift that is already built (#2997), so there is no new save field.

- `Config.UpdateGift = { id = "2026-11-12", from = 1794520980, fish = 100, spins = 0 }`. `from` is 22:03:00 UTC, three minutes after the restart.
- **Who gets it:** every player in game at 22:03, and every player on their first join after that. Once per account. It needs no button and no claim, and nobody loses it by being a minute late or by not being on at 5 PM. It stays on until Saturday's update gift replaces it (2026-11-14 17:00 UTC, 15 golden fish and 1 spin as planned; set that one again in Saturday's update).
- **Size:** 100 golden fish is about one day of a daily player's golden fish, or two and a half crates at the Market. It is a one-time launch present, not a new rate. Golden fish are never sold, so nothing here touches Robux.
- **The gift notice (new, small):** while `os.time()` is before `from` and within 5 minutes of it, the server shows each player one banner, once: on join, or at server start for players already in. It names the wait in whole minutes.
- **At 22:03:** the gift banner in place of the plain toast, with the existing gift sound.

## 5. Wording
Final words for the banner (#3419: a title of at most 24 characters and up to three short lines, about 6 seconds). Sentence case, no hype words, no "last chance", no prices.

| Moment | Title | Lines |
|---|---|---|
| Party start (22:00, and on join during the party) | `Update Party!` | `x2 cafe earnings until 6:00 PM` / `New: Mystic Pool and Mouse Dash` / `Rare cat showers all hour` |
| Gift notice (22:00 to 22:03) | `A gift is coming!` | `100 golden fish for everyone` / `in 3 minutes` |
| Gift paid (22:03, or first join after) | `A gift for everyone!` | `+100 golden fish` / `Thanks for playing!` |

- The end time in the first line is the player's local time, as the event banner does today (6:00 PM is Toronto's).
- The gift notice says the real minutes left ("in 2 minutes", "in 1 minute"). It never says to stay, and never says anything is lost by leaving.
- If a headline feature is held back (section 1), the "New:" line names only what is on: "New: Mouse Dash" or "New: Mystic Pool". With neither on, the line is "Rich customers leave bags".
- **HUD chip and Town Square board:** as built, from the record: "Update Party in 2:59", then "Update Party · ends in 59:40 · next shower 9:12". Board lines: "x2 cafe earnings", "4 rare cat showers", "Lucky, Golden and Rainbow Day", "+0.5 Luck".
- **Restart warning:** "A quick update is coming in 10 minutes, then a 1-hour party and a gift! Keep playing, your cafe is saved." and at zero "Updating now. Join again for a 1-hour party and a gift! Your cafe is saved." The warning's words come from the server that shows it, so this change must merge today for servers running tomorrow to say it. A server still on older code says "then a 10-minute event!", which undersells and is fine. After the launch the line goes back to the 10-minute event.
- **What's New rows** (at most 28 characters): "Mystic Pool: cat traits" (icon new), "New Arcade game: Mouse Dash" (new), "Rich customers leave bags" (new). A row is added only for a feature that is on.
- **Roblox event page and group post** (same text for both, with Derek's picture):
  - Title: "Mystic Pool and Mouse Dash update"
  - Short line: "New wizard cat, new arcade game, and a party"
  - Description: "The Mystic Pool opens! Sage Sorrel the wizard cat can give your cats special traits. The Cat Arcade has a new game, Mouse Dash: tap the mice, don't wake the kitten. Rich customers now leave money bags at your cafe. Join the Update Party for the first hour: x2 cafe earnings, extra Luck, rare cat showers, and 100 golden fish for everyone as a thank you."
  - The page and post never mention a pass, Robux or a stacked number.

## 6. Analytics
Nothing new to build: `event_join`, `event_money` and `event_shower` with id `update-1112`, the `update_gift` payout, and the restart player counts. Growth-Agent reads them with the arcade funnel after the hour: players at 21:45, at 22:01, the peak during the party and at 23:30.

## 7. Test plan
- Dev store (`EVENTS_STORE=dev`) or `OwnerTest event full 5`: the banner shows the three lines, the chip and board read as in section 5, x2 lands on tips and money bags and not on sales or prizes.
- Studio with `UpdateGift.from` two minutes ahead: the notice shows once with the right minutes, the gift pays 100 once at `from`, a rejoin pays nothing more, a first join after `from` pays once with the gift banner and no notice. With `spins = 0` the words show no spin.
- A player under 13: same banners, no purchase prompt during the hour.
- Phone, tablet, desktop and console: the banner's longest line ("New: Mystic Pool and Mouse Dash") fits.
- On the day: two servers start the party within a second of each other; the chip, board and banner agree on 6:00 PM; the player counts are recorded.
