# Review: PR #11 fix rounds and PR #16 (night look, net placeholders)

Reviewer: luau-reviewer thread, 2026-10-26 about 17:40 UTC. Read only; no game files changed. Follows `2026-10-26-v0.2-rescue-and-followups.md`.

## PR #11 fix rounds (merged at f151a79)

| Finding | Commit | Checked |
|---|---|---|
| S20 rescue lock re-press | ef24029 | `holdAt` times the hold and the 6 s lock. `lockedSince` starts a player's run, and a run past 12 s ends with a 6 s cooldown for that player on that spot. A short scripted `RescueEnd` plus a new `RescueBegin` continues the run, because `lastHolder` survives the unlock. The cooldown clears `lastHolder`. |
| N25 press timed just after each lapse | 347f169 | A press within 12 s of the same player's last press now continues the run, so every forced break leaves the spot free for at least 6 s. |
| S21 carry overwrite | ef24029 | `resolveGrab` refuses before rolling while the player carries a cat, and `startCarry` refuses to replace a carry. Neither path yields between the check and the carry. |
| N20 to N23 | ef24029 | `%g` in the hold message. The `GrabResult` id is matched to the active prompt or its model, and results still pass when no card is active. Lamps are watched under `World` only. The sun runs forward at dawn. |

All PR #11 findings are closed.

## PR #16: night look and net placeholders (ab2c645)

Sound, client-only and cosmetic. CI is green on both jobs.

Checked: the PR adds no remotes and changes no server logic or Config. Every night change is a client-local edit to a replicated `World` part or a light the client makes, and the always-on server PointLights in the placeholders are gone. The Lighting goal is cloned before the +24, so the sun runs forward both ways. The Atmosphere day colour is captured before the client first changes it. Decor that is toggled off is destroyed on the server, so the night look cannot bring back a sign the player removed. `HangingLamp` bulbs are excluded. The full `GetDescendants` sweep runs once per phase change. Wall props add their `y` to the floor height only. Nothing still references `CatCafe_Item_Net`.

**S22 (should-fix, mobile perf)** The `CatCafe_Decor_StringLights` placeholder builds 8 parts named `_Bulbs`, and `lightFor` gives each one its own PointLight (Range 16). The two alley strands therefore add 16 overlapping lights every night. The asset spec (`assets/cat-cafe/blender/build_all.py:78`) says one soft PointLight per strand, and the real model has a single `_Bulbs` part. Fix: build the placeholder bulbs as one part, or have `lightFor` make at most one light per model.

**N26 (nit)** `_Bulbs` and `_Pane` are new night suffixes. Style guide section 6 lists only `_Tube` and `_Bulb` (Neon) and `_Glass` (transparent). The asset thread should add the two new ones, so a future model does not glow, or fail to glow, by accident.

## Test formatting (N19)

The TestKit and AbuseClient formatting landed in PR #12 at 46cc6e0. The spec half is a patch on `main` 6c38f8e in the shared folder (`cat-cafe/docs/reviews/2026-10-26-specs-stylua.patch`), handed to QA. N24 (the `shop` case and good toasts) is closed at 46cc6e0: the case now compares the four state fields the buys would change.

## Open items

| Item | Owner | State |
|---|---|---|
| S22 string light count | engineer | Open on PR #16 |
| N26 night suffixes in the style guide | asset-artist | Nit |
| N19 spec formatting | QA | Patch supplied |
| N13 (review-fixes doc) spam-dropped GrabEnd UX | designer | Open |
| S11 Max Players 8 | Derek, Studio setting | Open |
| Hold-to-end grab check | Derek, Studio | Open |
