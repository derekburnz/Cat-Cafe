# Review: bait bowl, night dealer, alley dressing and rescue bar (PRs #101, #105, #106, #102, #103, #108, #109, #110)

Reviewer: luau-reviewer thread, 2026-10-27 about 03:45 to 04:30 UTC. Read only; no game files changed. Each verdict is also a COMMENT review on its PR, posted on the head named here. Follows `2026-10-27-polish-batch.md`. Checked against main at e39c07f, data-model sections 8, 8b and 10b, and the art in `assets/cat-cafe/rbx/`.

## Verdicts

| PR | Thread | Head | Verdict |
|---|---|---|---|
| #101 bait bowl UI (BaitBowl, BaitCard, FoodOdds, HUD chip) | ui-designer | 3418488 | Sound. N69 (closed by #105), N70, and the F28 server checklist |
| #105 night dealer UI (seed shop list, ItemIcon) | ui-designer | 4285446 | Sound. N69 closed. S42 (UI half fixed before the merge) |
| #106 cat room cards with each cat's model | ui-designer | 6c140dd | Sound. N71 fixed before the merge (45ff920) |
| #102 alley kit in the world, turned gates, Sewer manhole | engineer | 7b6bcfc | Sound. Closes N68 |
| #103 cafe sign keeps tier and tips at night | engineer | 486b1d4 | Sound. Closes the server half of S41 |
| #108 bait bowl server and client wiring (F28) | engineer | 8bfe9fd | Sound. Closes N30 and the engineer half of N70. Nits N72, N73 |
| #110 night dealer server (F32) | engineer | 6bc171e | Sound. Closes S27 and the server half of S42. Half of N32 still open |
| #109 rescue minigame bar (F27 UI) | ui-designer | 1a6c813 | Sound. Nits N74, N75 |

#103 later took in main (17049d6) with no change to its own file, so the verdict stands.

## What was checked

**Bait bowl (#101, #108).**
- `UseLure(lureId)` checks `Guard.id`, a known food, `lure_bowl` at least 1, an empty bowl, stock and 12 studs from the player's own `BaitBowl`. It takes the food and rolls rarity, cat, charm and shiny into `profile.bait` in one step, so a rejoin cannot reroll.
- `ResolveBait(choice)` checks the enum, readiness by `os.time()` and 20 studs. It empties the bowl before granting. Both remotes have 1 per second limiters.
- ProfileSync names the cat only once `now >= readyAt` (N30), and `checkArrivals` sends that sync within a second, including after a rejoin. That replaces the `BaitReady` remote.
- `pickBaitCat` uses the same pool as `FoodOdds.split` (every area with `tier <= tier`). Every area has all five rarities, so the per-cat odds on the card are exact.
- `Config.CharmStarOdds` (7.84, 23.53, 35.67, 24.31, 8.65) is pinned to `CatStats.rollCharm` plus `stars` by a spec.
- `sanitizeBait` drops a saved bait whose food or cat has left the catalog.

**Night dealer (#105, #110).**
- `BuyDealerFood(slot, lureId)` checks `Guard.int(1..3)` and `Guard.id`, that the cart is out and it is night, and 12 studs from the cart. It then recomputes this window's stock and refuses when the slot holds another food by now, which closes S42. It also checks the bought mark and the dealer source, then runs `settle` and `trySpend`. Every refusal answers with `DealerStock`.
- The stock is seeded from UserId, `floor(os.time() / 600)` and tier, so a server hop cannot reroll it (S27). The seed arithmetic stays under 2^53, and negative Studio UserIds work.
- The cart and dealer art hold only parts, no scripts. The cart parks mid-street at (0, 0), away from `PlayerSpawn` (z 70).

**Alley dressing (#102).** I placed every piece at its Layout position and turn from its `.model.json`:
- The pieces: 12 building backs, crate stacks, string lights, laundry, the mural, the Square pieces, loose props, the three kit arches, the turned Woods and Sewer gates and the manhole.
- No two visible parts overlap by more than 0.35 studs.
- The arches leave 27.4 studs (street) and 25.4 (back alleys) clear at walking height.
- The crate steps (0.6, 2.6, 5.2, 7.8) reach the first fire escape landing (about 9.4). Nothing leads over the 10 stud outer wall, because the building backs in front of it are 18 to 26 tall.
- Every spawn point lies inside the new `roam` rects. The nearest prop is 2.3 studs from a spawn point.
- The gate turn (`center.z < gateZ`) turns Park, Woods and Sewer and leaves the Neighbourhood alone (N68).

**Rescue bar (#109).**
- The marker is the data model's triangle wave, and its spec covers phase, waiting before `startsAt` and staying within bounds.
- The bar sinks E, Space, A and R2 at High priority, so Space does not jump. It unbinds them on every way out.
- Device guesses are replaced by the server's `RescueResult`.

## Findings

**N72 (nit, engineer; #108) Leftover v0.2 lure data.** These are now unused:
- `AreaSpec.lureSpots` and its lists in Layout (alley, park and three empty ones);
- the Layout.spec checks on them;
- `Catalog.lureSpotsPerArea`.

Drop them the next time Layout changes.

**N73 (nit, qa-playtester; #108) Add abuse cases for the bowl.** The abuse client has no `UseLure` or `ResolveBait` cases, and it still filters strays on `ReservedFor`, which is gone (harmless). Cases to add:
- wrong types and an unknown food;
- no bowl upgrade, a full bowl and no stock;
- 13 or more studs from the player's own bowl, and someone else's bowl;
- `ResolveBait` before `readyAt`;
- two "tame" presses in one frame, which must give one cat;
- a flood of each remote.

**N32 (nit, engineer; #110; half open) The backwards window step.**
- **Done:** `Dealer.refresh` clears the bought marks only on a forward step.
- **Still open:** on a server whose clock is behind at the boundary, `stockFor` shows window W's foods under the marks for W + 1. A slot bought in W but not yet in W + 1 then shows as buyable again.

A server hop takes longer than normal clock skew, so this is hard to hit. The guard is one line in `stockFor` and in the buy check: when `window < profile.dealer.window`, treat every slot as bought. Add a spec case.

**N74 (nit, engineer with ui-designer; #109) One home for the rescue marker maths.** `Components/RescueMarker` is under `StarterPlayerScripts`, where a server Script cannot require it. When the F27 server is built, put it in `src/shared` and have the UI and its spec require it from there. The server then judges presses with the same formula the bar draws.

**N75 (nit, ui-designer; #109) A "circle" challenge with no `circle` leaves the HUD in catching mode.** `UI.rescue.show` hides the prompt card and calls `hud:setCatching(true)` before it checks `challenge.circle`, then returns with nothing on screen. Check `circle` first, or call `endRescue(false)` on that return.

The open nits from the #101 review still apply where they are not closed above. N70's UI half: the BaitCard and FoodOdds fallback copies of the Config numbers can go now that the keys exist.

## Notes, no action needed

- A tame fires `CatCaught`, so it rings the check-in bell. That works as a "joined your cafe" cue. The sound list row should say so.
- A rank up within a dealer window rerolls the three foods (the tier is in the seed) but keeps the slot bought marks. That leans safe and cannot be farmed.
- The rescue circle's result shows the device's guess of the grade on a success. If that grade ever counts for something, put it in `RescueResult`.
- When F31 lands, the server sign line and `CafeSigns` should both show the night rate (rate times `NightIncomeMultiplier`).

## Studio checks for the laptop bench

- #102: every part of `CatCafe_Sewer_Manhole` is `CanCollide = false`, including the lamp. Walk through it and see whether that looks broken. If it does, the asset-artist makes the lamp post collide.
- #108: the bowl at twice its size reaches plot z -19.96, where the garden's front edging (plot z -19.8 to -19.6, about 0.5 high) can cut its front rim by up to 0.36 studs. If that shows, move `Layout.plot.baitBowl` to z -18.6.
- #110: join at night and decide whether the `DealerArrive` cue should play on join.
- #106: the cat room with a large collection on a phone emulator. The lazy build (N71) should keep it flat.

## Build checklist status

**Closed in this batch:** S27, S41, S42, N30, N64 (52dcb26), N65 (e2e42b4), N68, N69, N71, and the engineer half of N70.

**Open:**
- New in this batch: N32 (backwards half), N72 to N75, and N70 (UI half).
- From the last batch: N62, N63, N66, N67.
- Older: N51, N53, N55, N56, N13 (designer) and S11 (Derek).

S36 waits on the bump build.

**Still to build from v0.3:**
- S25, S26, S32 and N29 (bump);
- S28 (rescue server);
- S29 (rich tip);
- S30 and N35 (rename). Names on the cat room cards show once RenameCat stores the TextService-filtered name.
