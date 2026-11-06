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

## 7. Catch v3: moods, trust, twists and the finish (#1884)

Derek2, 2026-11-06: "re-work the cat catching mechanic/minigame to be more fun but still clean it's one of the core gameplay loops". He picked every recommendation (20:24, "go with all recommended"). The research and the reasons are in the project library, `Design-Agent/catch-v3-proposal-2026-11-06.md`. Sections 1 (the swing) and 2 (bands by net) stay. Section 3's progress strip and result words are replaced by 7b and 7d. Rescues (section 4) don't change.

### 7a. Cat moods on the approach
- A stray rolls a mood when it spawns and keeps it until it's caught or leaves. It's stored as the `Mood` attribute on the stray model, and the client shows a small icon above its head within 20 studs.

  | rarity | Sleepy (zZ) | Curious (?) | Skittish (!) |
  |---|---|---|---|
  | Common, Rare | 55 | 45 | 0 |
  | Epic | 30 | 35 | 35 |
  | Legendary, Mythical | 20 | 30 | 50 |

- **Sleepy:** curled up, never wanders, and only wakes when a swing lands on it.
- **Curious:** the first time a player comes within 12 studs, it walks 4 studs toward them. A swing that lands within 2 s of that walk starting begins with +1 trust (`CuriousTrustBonus`).
- **Skittish:** it faces one way, and its icon shows a small view arc. A player who comes within 10 studs *inside its 90° front arc* makes it hop 6 studs away, at most once every 8 s (`SkittishHopStuds` 6, `SkittishCooldown` 8). Coming from behind or the side is fine. It's sneaking with no extra button.
- The tutorial stray is always Sleepy. A player before `tutorialStep` 2 never meets a Skittish cat, because their strays reroll Skittish to Sleepy.

### 7b. The trust bar (replaces "one Miss ends it")
- Trust starts at 2 (3 with the Curious bonus) and has to reach the rarity's `trustNeed`: Common 8, Rare 10, Epic 12, Legendary 14, Mythical 16. An all-Perfect run takes the same number of rings as today: 3, 4, 5, 6 or 7.
- Each ring: **Perfect +2, Good +1, Miss -2.** If trust drops **below 0**, the cat bolts. That's today's sprint and miss streak, unchanged.
- Rings keep coming on a steady beat, one every `shrinkSeconds + CircleGapMin`, until trust is full or the cat bolts. A run also ends as a bolt after `2 x` the all-Perfect ring count (6 for a Common, 14 for a Mythical), so it can never drag on.
- The rings sit on the cat in the world, around its head, not in the middle of the screen. The cat reacts to each grade: ears perk on a hit, a wriggle and a soft hiss on a Miss.
- A soft purr rises in pitch with trust (Sound).
- **Re-fit:** Gameplay-Engineer runs the section 2 simulation (50 ms and 70 ms presses) and tunes only the `catchWindow` column, so each cell of the section 2 catch-chance table lands within 5 points of today. If that can't be done, Design re-tunes `trustNeed`. A Basic Net Mythical stays about 1 try in 4.

### 7c. Rarity twists
- **Double ring (Epic and above):** each ring after the first has a 25% chance (`DoubleRingChance`) to be a double, with two outlines shrinking 0.18 s apart. Each half is graded as its own press.
- **Paw ring (Legendary and above):** each ring after the second has a 1 in 6 chance (`PawRingChance`) to be red with a paw print, never twice in a row. *Don't tap it.* Leaving it gives +1 trust. Tapping it is graded as a Miss (-2), and the cat swats at the net.
- Mythicals can get both. Commons and Rares keep plain rings.
- The server picks every ring kind into `CatchSchedule`, so the client only draws them.

### 7d. The finish
- When trust fills, the net wraps the cat and wobbles twice in 0.6 s, then pops with confetti and one banner:
  - **PURRFECT!** if every tapped ring was Perfect and no paw ring was tapped. Gold, the biggest burst.
  - **GREAT!** if at most one ring wasn't Perfect. Mint.
  - **NICE!** otherwise. Cream.
  - A bolt shows "So close!" as now.
- **Purrfect bonus:** the caught cat joins with `CatXpBase` (120) XP, which is level 2 at once. A "Purrfect x3" streak counter shows under the coins after the second Purrfect in a row. It resets on any other result and lasts for the session only, so there's no save change.
- The carry home after the finish is unchanged.

### 7e. Contracts
- `CatchSchedule` gains `rings = { { at, kind = "single" | "double" | "paw" } }`, `trustStart` and `trustNeed`. `CatchResult` gains `trust`, `finish = "purrfect" | "great" | "nice" | "bolt"` and `streak`. No new remotes, and the server still stamps and grades every press.
- Config: `TrustPerfect` 2, `TrustGood` 1, `TrustMiss` -2, `TrustStart` 2, `CuriousTrustBonus` 1, `DoubleRingChance` 0.25, `PawRingChance` 1/6, `SkittishHopStuds` 6, `SkittishCooldown` 8, `MoodIconStuds` 20. On `Catalog.rarities`: `trustNeed` and the mood weights.
- Analytics: `catch_attempt` gains `finish` and `mood`.
- **Who builds:**
  - Gameplay-Engineer: the moods, trust, ring kinds, the re-fit, Pace.spec and the XP bonus.
  - UI-Engineer: the trust bar over the cat, mood icons, the banner and the streak counter.
  - Animation-Engineer: the ear perk, wriggle, swat, net wrap and wobble, and the mood idles.
  - VFX-Agent: the ring pops, a 60 ms hit-stop on Perfect (client only), confetti and the Purrfect burst, with lighter versions for Reduce Motion and Low performance.
  - Sound-Agent: the rising purr, grade ticks, hiss, swat, wobble and pop, and the Purrfect jingle.
- Two PRs from Gameplay: trust and the finish first, then moods and twists.

### 7f. QA checks
1. A brand-new player's first three catches all succeed, and none of their strays is Skittish.
2. A Common caught with three Perfects takes 3 rings, about 4 s from the swing to PURRFECT.
3. One Miss early on a Rare doesn't end the catch, but two Misses in a row from the start do.
4. A Skittish cat hops when approached from the front within 10 studs, not from behind.
5. Tapping a paw ring costs trust and plays the swat. Leaving it adds trust.
6. A Purrfect cat joins at level 2. The streak counter shows from the second Purrfect in a row.
7. The section 2 chance table holds within 5 points (spec simulation). A playtest on phone and desktop shows no new console errors.
