# Catch and rescue rework: the net swing, circles by rarity, clearer results (F93)

Status: decided by Derek in the Google Doc's Set 5 answers (read 2026-11-01), specced by the game-designer thread. His asks of 2026-10-28:

- 14:19: "for the net have your character carry it around then click for it to smack it down and if it hits the cat starts the capturing if you miss near a cat it runs away a little"
- 14:20: "lets start the amounts of bubbles higher commom at 3, rare 4, epic 5 etc… and make each rarity faster", "make the rescue minigames more polished and harder", and "make sure net is put away on capture when holding cat and comes back out when no longer holding"

His Set 5 answers:

- Q1: "No hold E swing only is good"
- Q2: "Sounds good whatever you think is best"
- Q3: "Re-work what the net upgrades do maybe make it so the bands of the circles are bigger with each upgrade but the timing or amount of circles doesn't change, also currently you can get a miss, then an excellent and the old circles all flash good I think maybe add a bar or text at the top while catching showing how well you did like EXCELLENT pops up with an animation and some vfx at the end of the catch and the old circles should disappear after each one has been hit or missed and at the end of a catch"
- Q4: "If they are perfect it should always catch, just give less time for the going left and right so people don't just sit there for perfect timing as for the rest do whatever you recommend."

This replaces the stray's hold E prompt and the net levels' timing in data-model sections 2 and 10. Rescues (10b) keep their hold prompt.

## 1. The net swing

- **Carrying the net.** Every character holds a net in the right hand at all times, as a welded accessory (not a Roblox Tool, so no backpack bar appears). Its look follows the net level: Basic, Sturdy, Pro and Master each get their own model. While the player carries a cat the net is put away (hidden) and it comes back the moment the carry ends, however it ends.
- **Swinging.** Left click on a computer, R2 on a gamepad and a Net button on touch screens, placed just above and left of the jump button. A click on the HUD never swings. The swing is a 0.35 s overhead smack: the net rises for 0.1 s, lands at 0.15 s and recovers. One swing per NetSwingCooldown (0.8 s).
- **What the server judges.** The client sends `SwingNet()` with no arguments. NetSmackDelay (0.15 s) after it arrives, when the net lands, the server takes the character's root position and facing and looks for strays within NetReachStuds (7) plus NetSlackStuds (1.5) whose direction is within NetArcDegrees (60) either side of the facing. Strays that are sprinting, catching their breath or locked by another player are skipped. The nearest one left is the hit.
- **A hit** starts the catch exactly as `GrabBegin` does today: the same checks, then `CatchSchedule`. A hit on a Dropped stray picks it up at once, with no circles.
- **A miss near cats.** If the swing hits nothing and free strays stand within NetMissHopStuds (12), each of them hops away NetMissHopShare (0.25) of its rarity's `fleeStuds`: 6 studs for a Common up to 16 for a Mythical. A player who has not caught a cat yet (`tutorialStep` below 2) never makes a cat hop, so the first catch stays easy (easy-start.md section 2b).
- **In reach.** The client puts a soft glow on the stray its swing would hit right now, so a player sees when to swing. The stray's Catch prompt goes.
- **Not allowed** while carrying (the net is away), mid-catch, mid-rescue, at night in an area, inside your own safe zone or during a cannon flight.

## 2. Circles by rarity, bands by net

The number and speed of circles now come only from the stray's rarity. The net only widens the bands, so a better net makes every cat easier without changing its rhythm.

| rarity | circles | shrinkSeconds | catchWindow |
|---|---|---|---|
| Common | 3 | 1.20 | 1.1 |
| Rare | 4 | 1.00 | 0.95 |
| Epic | 5 | 0.82 | 0.82 |
| Legendary | 6 | 0.68 | 0.70 |
| Mythical | 7 | 0.56 | 0.60 |

| net | perfect | good |
|---|---|---|
| Basic Net | 0.045 | 0.11 |
| Sturdy Net | 0.055 | 0.13 |
| Pro Net | 0.065 | 0.155 |
| Master Net | 0.08 | 0.18 |

The bands are the net's `perfect` and `good` times the rarity's `catchWindow`, as since v0.13.15. Net jitter goes: every circle's shrink time wobbles by CircleJitter (0.10) whatever the net. CircleGapMin (0.40) still clears the widest Good (0.198 on a Master Net Common). The tutorial stray keeps its one slow circle (easy-start.md).

Catch chances per try, for a player whose presses land within about 50 ms, and 70 ms for a young player on a phone. These are the target Derek saw in Set 5 Q3 (a Mythical on a Basic Net about 1 try in 4, about 4 in 5 on a Master Net, a Common about 19 in 20); the catchWindow column above is fitted to them (fixed 2026-11-02 after Gameplay-Engineer found the first column, 1.0 to 0.8, gave a Basic Net Mythical 57%):

| net | Common | Rare | Epic | Legendary | Mythical |
|---|---|---|---|---|---|
| Basic, 50 ms | 95% | 86% | 69% | 46% | 23% |
| Sturdy, 50 ms | 99% | 95% | 84% | 65% | 41% |
| Pro, 50 ms | 100% | 99% | 94% | 83% | 63% |
| Master, 50 ms | 100% | 100% | 98% | 93% | 80% |
| Basic, 70 ms | 77% | 56% | 33% | 15% | 5% |
| Master, 70 ms | 99% | 94% | 83% | 64% | 40% |

Tries stay unlimited and a miss costs only the chase, so a hard cat costs time, never the cat.

## 3. Clear results while catching

- **Each circle clears when it is judged.** The moment a press is judged, that circle pops away with its grade word on the spot (PERFECT in gold, GOOD in mint, MISS in grey) and is gone. Nothing stays on screen from earlier circles.
- **A miss ends it cleanly.** On the first Miss every circle still showing goes at once and nothing after it can flash a grade. Derek saw a Miss followed by an EXCELLENT with the old circles flashing Good; that must not be possible. The client draws only what `CatchResult` and the server's per-press grades say.
- **A progress strip at the top.** While catching, a short strip at the top of the screen shows one pip per circle. Each pip fills with its grade's colour as it lands, so the player sees how the catch is going.
- **The result word at the end.** When the last circle is judged, one word slams in over the strip with a pop and a burst in its colour:
  - every circle Perfect: PURRFECT! (gold, the biggest burst, as the Purrfect burst today)
  - at least half Perfect: EXCELLENT! (gold)
  - every circle Good or better: GREAT! (mint)
  - a Miss: "So close!" (soft grey, no burst), and the cat sprints as now
- Then the strip and the word fade by 1.2 s and the screen is clear.

## 4. Rescues: faster, harder, fair

- **Perfect always works.** Rescues stay fully skill based: a press in the zone is always a hit, with no random roll.
- **No waiting for the perfect moment.** Each target zone stays for RescueZonePasses (2) sweeps of the marker across the bar. If it is not hit by then it counts as a miss (one paw) and the zone moves. A player can no longer watch the marker go back and forth for as long as they like.
- **Harder by rarity.** The marker speeds up RescueSpeedUpPerHit (8%) after every hit, and every rarity needs one more hit: `rescueHits` 3, 4, 5, 6, 7. With presses within about 50 ms a bar rescue works 100 / 100 / 86 / 43 / 12% of the time by rarity (it was 100 / 100 / 97 / 73 / 37%); a failed rescue still never loses the cat, and a Team Rescue helper (F92) makes the rare ones fair.
- **Polish.**
  - The marker is a little paw.
  - The trap shakes on every hit, a little more each time.
  - Hit pips above the bar fill as hits land.
  - A ring around the bar runs down the attempt's 15 s deadline.
  - A burst in the cat's rarity colour plays when it comes free.

## 5. Contracts

- Remotes: `SwingNet()` new, client to server, at most 1 per NetSwingCooldown with a flood guard of 3 per second; it replaces the stray Catch prompt's `GrabBegin`, which stays as the server's internal start. `NetSwung(userId, hit)` to nearby clients for the swing and its whoosh. `PickUpCat` is folded into the swing's hit on a Dropped stray.
- Attributes: `NetHidden` (bool) on the character while carrying, so every client hides the net.
- Config: NetSwingCooldown 0.8, NetSmackDelay 0.15, NetReachStuds 7, NetSlackStuds 1.5, NetArcDegrees 60, NetMissHopStuds 12, NetMissHopShare 0.25, CircleJitter 0.10, RescueZonePasses 2, RescueSpeedUpPerHit 0.08; the rarity table in section 2 and `rescueHits` 3 to 7; the nets' `jitter` column goes.
- Analytics: the `catch_attempt` funnel gains a first step `swing_hit`; a new custom event `net_swing` (value 1, fields result: hit, miss_near or miss_empty; net level; device) shows how often swings miss.
- The exploit check (data-model section 10) is unchanged: the server still owns the schedule and stamps every press.
- Who builds: Gameplay-Engineer (the swing judging, the hop, the rescue changes, the remotes), Animation-Engineer (the held net pose, the smack, putting the net away and taking it out), Model-Agent (four net models), UI-Engineer (the Net button, the in-reach glow, circles clearing, the progress strip, the result words and the rescue polish), VFX-Agent (the result bursts, the rescue shake and free burst, the swing whoosh trail), Sound-Agent (the whoosh, the smack, each grade, each result word), QA-Planner (section 6).

## 6. QA checks

1. Every character holds its net; it vanishes the moment a cat is in their arms and comes back when the carry ends by check-in, drop, shove or night.
2. A click on the HUD never swings; a click in the world swings once per 0.8 s.
3. A swing with a free stray 7 studs ahead starts its catch; one 9 studs away or behind the player does not.
4. A miss next to three strays makes each hop away a quarter of its sprint; a brand new player's miss makes nothing hop.
5. A Common shows three circles and a Mythical seven, on every net; a Master Net shows wider bands than a Basic Net but the same timing.
6. Each circle disappears with its grade the moment it is judged. After a Miss nothing else shows a grade, and the result reads "So close!".
7. All Perfect reads PURRFECT!, half or more Perfect EXCELLENT! and the rest GREAT!, each with its burst, and the screen is clear 1.2 s later.
8. A rescue zone not hit within two sweeps costs a paw and moves. The marker gets faster with each hit. A Mythical needs seven hits.
9. The paw marker, trap shake, hit pips, deadline ring and free burst all show.
10. A dropped cat is picked up by swinging at it.
