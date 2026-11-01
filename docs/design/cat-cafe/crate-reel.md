# The crate reel (F103)

Status: decided by Derek, specced by the game-designer thread, 2026-11-01. Derek, 2026-10-28: a sideways sliding spin when a crate opens that lands on the prize. VFX-Agent's proposal (relayed 2026-11-01 23:11) sets the fairness rules. This replaces the two second card reveal in golden-fish.md section 4 and ui-contract.md's Golden Fish Market reveal for every crate: the zone crates, the Classic Crate, the golden crates and the Rally Crate.

## 1. The rules that keep it fair

The old rule was "the won rarity shows from the first frame". A reel has to show other pieces going by, so the rule becomes:

- **The server has already decided and paid** before the reel starts, as now. The reel only shows the result. Leaving mid-reel keeps the piece.
- **Same length every time.** Every reel runs the same distance at the same speeds, so a good result never takes longer or slows differently.
- **It lands in the middle of the won piece.** Never on an edge, never creeping over a tile line.
- **Nothing rarer than the prize near the end.** In the last second of the reel, and in the tiles still in view when it stops, no piece is rarer than the one won. Rarer pieces can only go by in the fast part, as a blur.
- **The strip is honest.** The other tiles are drawn from the crate's real odds, so a player mostly sees Commons and Rares go by, as in the odds sheet.
- **A tap skips** straight to the landing. **Reduce Motion** keeps today's short fade with no reel.

Crates are never sold for Robux, but these rules hold anyway (monetization-policy section 2, young audience).

## 2. The reel

- A strip of CrateReelTiles (40) square tiles slides right to left under a fixed marker in the middle of the window, a gold notch above and below. Seven tiles are in view. Each tile is the piece's icon on its rarity colour with the rarity's border.
- **The won piece is tile 34** (CrateReelLandingTile). The reel starts with tile 1 under the marker and travels 33 tiles.
- **Timing, the same every time:**

| part | time | what happens |
|---|---|---|
| speed up | 0 to 0.3 s | eases in to 15 tiles a second (CrateReelTopSpeed) |
| full speed | 0.3 to about 2.08 s | 26.75 tiles at 15 a second, blurred |
| slow down | the last 0.8 s (CrateReelStopSeconds) | an ease-out cubic over the last 4 tiles, stopping dead centre on tile 34 |
| stop | about 2.9 s | the marker pulses in the won rarity's colour for 0.25 s |
| prize card | about 3.15 s | today's prize card pops in ("New! Find it in Decor." or the fish back line, Use it and Later) |

- **The protected tiles.** Tiles 26 to 37 cover the last second (tiles 27 to 34 pass the marker then) and the tiles in view at the stop. The client draws them again until none is rarer than the won piece. For a Common prize that means every tile from 26 on is a Common.
- **Golden crates** hold only Epic or better, so their strips use the golden odds and the same rules.
- The client builds the strip from `CrateResult` with its own `Random`; it is display only and sends nothing back.

## 3. Sound and the counter crate

- **Sound** (Sound-Agent): a soft tick each time a tile line crosses the marker (at most one every 0.07 s, so it reads as a whirr at full speed and slows into distinct ticks), a wooden thunk at the stop, then the rarity sting from Epic up as now.
- **The crate on the Market counter** (VFX-Agent, `Market.luau`): its lid rattles while the reel runs and pops open at the stop (about 2.9 s) with confetti in the won rarity's colour.
- **Legendary and Mythical** (luck-and-rare-moments.md section 2b, moved to the landing): at the stop the landing tile glows in the rarity colour, the counter crate glows and shakes for 0.6 s, the lid blows open and the big pull card plays in place of the prize card. Before the stop nothing hints at the rarity.

## 4. Contracts

- Config (shared, so UI and VFX time to the same numbers): `CrateReelTiles` 40, `CrateReelLandingTile` 34, `CrateReelProtectFrom` 26, `CrateReelProtectTo` 37, `CrateReelTopSpeed` 15, `CrateReelRampSeconds` 0.3, `CrateReelStopSeconds` 0.8, `CrateReelHoldSeconds` 0.25. The total (about 2.9 s to the stop) comes from these.
- No server or remote change: `CrateResult` already carries the piece and rarity.
- A pure helper for the strip and the position at time t, with a spec: the stop is tile 34's centre, the total time never changes, and tiles 26 to 37 are never rarer than the prize over 10,000 builds.
- Who builds: UI-Engineer (the reel in the Market window, updating ui-contract.md), VFX-Agent (the counter crate's rattle and pop and the rare glow at the stop), Sound-Agent (ticks and thunk), QA-Planner (the checks below).

## 5. QA checks

1. Fifty opens of each crate all stop dead centre on the won piece at the same time after Open, measured from `CrateResult`.
2. Over 10,000 strip builds in the cloud check, no tile from 26 to 37 is rarer than the prize, and the tiles before 26 match the crate's odds.
3. A tap during the reel jumps to the landing and the prize card.
4. Closing the window or leaving mid-reel keeps the piece (the Decor screen has it on rejoin).
5. A Mythical shows no glow, shake or colour hint until the stop, then the shake, the lid and the big pull.
6. With Reduce Motion on, there is no reel, only the short fade.
