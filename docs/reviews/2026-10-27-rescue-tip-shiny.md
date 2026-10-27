# Review: rescue server, rich tip marker, action pills and net shinies (PRs #109 recheck, #113, #114, #115, #116, #117, #119, #120)

Reviewer: luau-reviewer thread, 2026-10-27 about 04:30 to 08:00 UTC. Read only; no game files changed. Each verdict is also a COMMENT review on its PR, posted on the head named here. Follows `2026-10-27-bowl-dealer-alley.md`. Checked against main at 330c1c6, data-model sections 4, 9, 10b, 12 and 15, and the art in `assets/cat-cafe/rbx/`.

## Verdicts

| PR | Thread | Head | Verdict |
|---|---|---|---|
| #109 rescue bar (F27 UI), recheck | ui-designer | c3f0469 | Sound. N75 fixed (e62e5de) |
| #113 action pills for custom prompts | ui-designer | 3827482 | Sound. N76 fixed before the merge (4cb0472) |
| #114 UI reads the bowl, dealer, odds and travel numbers from Config | ui-designer | a77ca15 | Sound. Closes the UI half of N70 |
| #115 rescue minigames on real traps, server side (F27) | engineer | 7f351ab, then 9e6ab86 | Sound. Closes S28 and the server half of N74. N77, N78 (modules.md) and S43 fixed before the merge (79302b3, 3fa5f21) |
| #117 rich tip marker with Collect (F31 UI) | ui-designer | 9c5f221 | Sound. N79 fixed before the merge (c7803cf) |
| #116 bowl, dealer and manhole prompts use the action pill | engineer | 3986502 | Sound. No findings |
| #119 shiny strays from the net (F30) | engineer | 5c40e98 | Sound. No findings; a note for F29 |
| #120 rescue bar on the shared marker, hold retired | ui-designer | 368386a | Sound. Closes the UI half of N74 and the contract half of N78. Nit N80 |

## What was checked

**Rescue server (#115).**
- `RescueBegin` checks, in order:
  - `Guard.id` and a live stuck cat;
  - not carrying, and the area's tier;
  - the player's own running attempt ("Keep going"), then another player's lock;
  - no catch running, and one attempt per player;
  - the 6 s self wait and the 3 s wait for others, both on the server clock;
  - range `GrabRangeStuds + 2`.

  It has a 1 per second limiter, and so does `RescueCancel`.
- `RescuePress` sends no time. The server stamps arrival minus `Circles.latency` (capped at 0.15 s), so lag buys at most the cap. It ignores presses outside `startsAt` to `endsAt`.
- The 0.2 s watch loop ends the attempt on the deadline (`endsAt` plus the cap), when the cat goes, when the player leaves or dies, or at 14 studs. It frees the lock every time. That closes S28.
- Charm, variant and shiny stay in the server's stuck entry (N30). `GrabBegin` refuses during a rescue, and `RescueBegin` refuses during a catch. Both go through `CatService.setRescueCheck`, which avoids a require cycle.
- `addCaughtCat` now takes a method (`"net"`, `"bait"` or `"rescue"`) in place of the rescued flag.
- The new alley traps, placed from their `.model.json` parts against the #102 dressing, overlap nothing:
  - Each trash bin stands 1.7 studs from its building back. The east bin moved to z 22 and is 1.1 studs from the windowed back there.
  - The garbage bags sit flush with the north wall, 1.25 studs from the mural.

**Rich tip marker (#117).**
- `RichTipState.read` turns wrong types, a zero amount and a past expiry into no tip. It rounds the seconds up, so a live tip never reads 0:00. The spec covers each case.
- A tip clears with exactly one toast, whichever of the two attributes the server clears first. A tip already waiting at `bind` shows without a toast. The toast follows only the server clearing the amount, so a refused claim never shows "+$X".
- The Heartbeat loop runs only while the marker shows. The per-frame calls are plain property sets with no tweens.

**Action pills (#113, #116).**
- Only `Style = Custom` prompts without a `CatId` get a pill, so stray and rescue prompts keep the catch card.
- Each pill drops its connections on hide, on a rebuild and on destroy. A pill that goes away mid-hold now lets go of its prompt (N76).
- #116 hangs the three prompts from `PromptPoint` attachments. Their handlers find them with recursive `FindFirstChild`, and `adorneeOf` takes an Attachment. The bowl's client prompt rebuilds with its attachment when the bowl streams back in.
- The prompt ranges stay inside the server checks: 8 studs against the bowl's 12, and 10 against the cart's 12.

**Net shinies (#119).**
- `ShinyChanceNet` is rolled once at spawn and stored on the server's stray. It travels through the carry and check-in into `shinyCollection`.
- The model and prompt `Shiny` attributes are display only, which section 4 allows for a net stray. The client's sparkle reads them in its budgeted nearest list.
- `Catching.shoutOut` covers check-in, rescue and bait in one place. It speaks for Epic and up and for every shiny, using catalog names and `DisplayName` only.

**Rescue bar on the shared marker (#120).**
- The bar, the Demo and the spec require `Shared.RescueMarker`, and the UI copy is deleted.
- The v0.2 hold is removed: `startRescue`, `stopRescue`, `rescueEnded` and the hold state are gone.
- A prompt press while the bar or the circles are up is ignored, which settles the #115 E check. The bar's 3 s no-result timeout clears the rescue state even if the server's result never arrives.

**Config reads (#114).** The bowl ranges, dealer range, travel cooldown, `LureWaitSeconds`, `ShinyChanceBait` and `CharmStarOdds` now come straight from Config. The cards show the numbers the server rolls with.

## Findings

**S43 (should-fix, engineer; #115; fixed by 3fa5f21) A self-referencing symlink was committed.**
- 79302b3 added `games/cat-cafe/tools/cloudcheck/node_modules` as a symlink (mode 120000) to its own absolute path.
- The folder's `.gitignore` said `node_modules/`, and the trailing slash matches only directories.
- On a Windows checkout this becomes a text file or a broken link, and `npm install` in that folder fails.

3fa5f21 removes the link and changes the ignore line to `node_modules`. No mode 120000 entries are left on main.

**N77 (nit, engineer; #115; fixed by 79302b3) The east trash bin sat on a lane spawn point.** At (84.5, 30) the bin was 1.6 studs from plot 6's lane point (82, 31). A stray spawning there could take the one E prompt from the rescue (`Exclusivity` OnePerButton). It now stands at z 22, 9.3 studs from the point.

**N78 (nit, engineer and ui-designer; #115; fixed by 79302b3 and #120) Stale rescue docs.** `docs/engineering/modules.md` and the hold lines of `ui-contract.md` described the 4 s hold, the 6 s lock and `RescueEnd`. Both are rewritten.

**N74 (nit; closed by #115 and #120) One home for the rescue marker maths.** `shared/RescueMarker` is the formula the server judges with. The bar and its spec now require it, and the UI copy is deleted.

**N79 (nit, ui-designer; #117; fixed by c7803cf) One control for the rich tip.** The contract's action pill row listed the rich tip as a custom prompt. `ClaimRichTip()` is a plain event, and the marker's Collect button is the control. The row now names the manhole instead. Gamepad players cannot reach a BillboardGui button, but the tip still pays at expiry. A ButtonX binding while in range would cover them.

**N80 (nit, ui-designer and engineer; #120) Leftovers from the hold.**
- **ui-designer:** `ui-contract.md:226` still places the marker at `Components/RescueMarker`.
- **engineer:** `Config.RescueHoldSeconds` is no longer read anywhere. Drop it, along with its `Config.spec` lines and the "first copy" line in `shared/RescueMarker.luau`.

## For the next builds

**F31 server (rich tip, S29).**
- `ClaimRichTip()`:
  - a 1 per second limiter;
  - the caller owns the plot, and the record's owner and serial match;
  - `os.time() < expiresAt`;
  - range from the server's `RichTipAnchor` with 2 studs of allowance;
  - zero the record and clear both attributes before crediting.
- Run the expiry credit about once a second (or `task.delay` to `expiresAt`), not on the 60 s roll. Otherwise the marker closes up to a minute before the toast.
- Save-on-leave credits an open tip, and releasing a plot clears everything.
- Add a BasePart named `RichTipAnchor` to each plot, and add `RichTipRangeStuds` and `RichTipStaySeconds` to Config.

**F29 (bump).** A bumped or dropped carry that becomes a stray again keeps its def, charm and variant. `spawnStray` must not roll them again.

## Notes, no action needed

- The rescue prompt stays enabled during the bar. Since #120 the client ignores its press while the bar is up, and the server would only answer "Keep going, the bar is up" anyway.
- A shiny Common from the net is announced to the server (section 15). At 2% of catches that will not flood the feed.

## Studio checks for the laptop bench

- #115:
  - Press E near the trap while the bar is up. Nothing should happen beyond the bar's own press.
  - Run a full rescue in each alley trap. The cat should sit visibly in the bin and between the bags.
- #116:
  - Check that the dealer's pill, 4 studs up, clears the NPC's head.
  - On a phone emulator, tap the bowl, cart and manhole pills once each.
- #119: run `PurrPotDebug:Invoke("spawnStray", "tabby", "alley", true)` and catch the cat. Check that the sparkle shows while it roams, the shiny catch header appears, the carried cat sparkles and the toast names it. On check-in, one shout-out should go to the server and the book's Shiny count should rise.
- #117 waits on the F31 server. Once it lands, check the marker on a phone at the cafe and from the alley.

## Build checklist status

**Closed in this batch:** S28, S43, N70 (UI half), N74, N75, N76, N77, N78 and N79.

**Open:**
- From this batch: N80.
- From the last batch: N72 and N73.
- Earlier: N62, N63, N66, N67, N51, N53, N55, N56, N13 (designer) and S11 (Derek).

S36 waits on the bump build.

**Still to build from v0.3:**
- S25, S26, S32 and N29 (bump, with the F29 note above);
- S29 (rich tip server, checklist above);
- S30 and N35 (rename).
