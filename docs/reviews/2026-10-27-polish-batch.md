# Review: the polish batch (PRs #82, #84, #85, #86, #88, #90, #91, #93, #94, #95)

Reviewer: luau-reviewer thread, 2026-10-27 about 03:00 to 03:30 UTC. Read only; no game files changed. Each verdict is also a COMMENT review on its PR, posted on the head named here. Follows `2026-10-27-v0.4-build.md`. Checked against main at 699f5d3, design v0.4 (`world-and-feel.md`) and the art in `assets/cat-cafe/rbx/`.

This batch answers Derek's 2026-10-26 23:03 playtest: cafes that look like the sketch, For Rent plots instead of grey boxes, lively cafes and UI patterns from popular Roblox games.

## Verdicts

| PR | Thread | Head | Verdict |
|---|---|---|---|
| #85 cafe life | engineer | 1dbe6e2 | Sound. N59 and N60 fixed before the merge |
| #86 Square-only rares | engineer | e154dea | Sound |
| #84 greyed-button bonk and announce colour | ui-designer | a44965b | Sound. Closes N57 and N58 |
| #82 collection book with area tabs | ui-designer | 9620639 | Sound. One phone check (below) |
| #88 cafe shells, For Rent, tier dressing, roof cutaway | engineer | 9c5137c | Sound. Nits N61 to N63 |
| #91 UI wiring and Moments | engineer | f7497f1 | Sound. Closes S39. S40 (gate art), nits N64, N65 |
| #93 cat found jingle only for a new cat | sound-designer | 6b76ce3 | Sound |
| #90 cafe name signs, rate tags, order bubbles | ui-designer | 0380353 | Sound. S41 (night sign), nit N66 |
| #94 grade hint on press | ui-designer | 6ea78a1 | Sound |
| #95 tutorial trail | ui-designer | 6fc48f6 | Sound. Nit N67 |

#82 and #84 later took in main 699f5d3, which changed only server and QA files, so the verdicts stand on the new heads (d834a5b and 239ac9b).

## Checked against the art (#88)

| Check | Result |
|---|---|
| Front doorway | x -3.5 to 3.5 in every shell, the same as DoorWidth 7, so `CafeDoor` and the customer path still go through the opening |
| Back doorway | x -11 to -5 and 7.5 high, the same as `Layout.plot.backDoor`, so the code-built BackDoor panel fills it exactly |
| Name sign | `SignBoard` is 16 x 3.2 with identity rotation and its front face at z -15.35, so `Face = Front` is the street side. No tier dressing sits in front of it |
| Roof cutaway | The chimney, ridge and roof are all inside `<name>_Roof`, with no Decals or Textures, so `LocalTransparencyModifier` on the BaseParts hides all of it. At 1 the default camera stops treating the roof as an occluder |
| Inside test | `plotAt` uses the plot's explicit `WorldPivot`, so it does not depend on what has streamed in |
| Floors | No shell or dressing face lies flush with the code-built Floor or FrontGarden, so nothing z-fights |
| Fallback | Placeholders do not list the plot names, so the code-built cafe still appears when the art is missing |
| For Rent shutters | Effects finds `Dressing/ForRent` through `inForRent` and caches it again through `DescendantAdded` after a release |
| Night glow | Dressing that arrives later is picked up through `DescendantAdded`, with one light per model: about 7 lights for a Tier 5 cafe |

## Findings

**S40 (should-fix, asset-artist, then engineer; #91) Three of the four real gates have no `Bars`, and no gate spans its opening.** `setGateOpen` now changes only parts named `Bars`. Of the real gates, only `CatCafe_Park_Gate` has one, and it is 5.6 studs wide. Neighbourhood, Woods and Sewer are posts plus `_LeafL` and `_LeafR` models. With #91 those three gates look the same below and above the tier, and once open their leaves stay shut and you walk through them. The openings are 24 studs (Park, Neighbourhood) and 30 studs (Woods, Sewer), but the gates are 6 to 8 studs wide, so no gate has blocked anyone since the art landed. The server checks the tier on every catch and rescue, so this is not an exploit, but the gates feel broken. Fix: the asset-artist adds a `Bars` part across the full opening, the same shape as the placeholder (width = opening, 5 high, 0.35 transparency). The engineer hides the leaf parts when the gate opens.

**S41 (should-fix, ui-designer and engineer; #90 and #85) The night sign says the cafe is closed while it keeps earning.** At night `CafeSigns` writes "Closed till morning" and the server fallback `PlotService.signText` writes "Closed". The design takes nothing away at night (common-features note 1): income runs at 60% once F31 lands (100% today) and customers keep walking in under the sign. Fix: keep the tier and rate line at night with a moon. Once F31 lands, show the rate times NightIncomeMultiplier, matching the clock chip's "Tips 60%".

**N61 (nit, asset-artist; #88) The Tier 4 aquarium clips the bought Window plants.** The `plants` anchor puts `CatCafe_Decor_WindowPlants` at x 11.5 to 14.5, y 1.2 to 2.4, z -13.9 to -13.3. The Tier 4 tank glass covers x 8.5 to 13.5, y 1 to 3.4, z -13.8 to -12.3. Move the tank about 1.5 studs back (z -12.3 to -10.7). That still clears nap spot 2 and the table at (9, -6).

**N62 (nit, designer; #88) Free tier dressing repeats two shop items.** Tier 3 adds a neon sign and Tier 4 an aquarium, and the decor shop sells a Neon sign and a Fish tank. Either give the tiers different pieces or accept that the bought ones become extras.

**N63 (nit, Studio bench; #88) Phone frame time with eight shells.** A plot is about 990 parts empty and 1,050 at Tier 5, nearly all casting shadows, so the street holds about 8,000 parts, all within the default streaming radius. Look down the street on the phone emulator and check frame time. If it is heavy, the artist turns off CastShadow on trim (20 shingle strips per roof, 36 glass arch wedges, the bulbs) or merges the shingles.

**N64 (nit, engineer; #91) Pass the rarity to the toast.** The `Announce` handler calls `UI.announce(text)`. With #84 on main, call `UI.announce(text, rarity)`, or the N58 fix never gets its argument.

**N65 (nit, engineer; #91, for the bump build) `CheckIn` fires on any carry ending.** Today only check-in ends a carry. Once a bump can drop the carried cat (S25, S26), the bell will ring on a drop. Fire `Moments.CheckIn` from the `CatCaught` handler, and update the sound-list row (#93) to match.

**N66 (nit, ui-designer; #90) The server's SignGui can show under the card after a stream-in.** Children of a replicated part can arrive after the part, so `hang` can miss `SignGui`, and two SurfaceGuis then share the board's front face. Disable a `SignGui` when it arrives, in the same `DescendantAdded` handler, or give the card a `ZOffset` of 1.

**N67 (nit, ui-designer; #95) A failed path draws the trail through walls.** When `ComputeAsync` fails, `route` stays `{ start, finish }`, a straight line through the cafe's back wall. Lay no dots (or keep the last good route) and let the marker point the way.

## Studio checks for the laptop bench

- #82: open a full area page of the collection book on a phone-sized emulator and confirm the ViewportFrames keep frame time flat. If they spike, cap the live viewports per page.
- #88 (N63): frame time looking down the street with all eight shells.
- #88: walk into a cafe and watch the roof fade. Walk out the back door, through the yard and out of the gate.
- #94: on a laggy phone the press sound is the device's guess and can say Perfect when the server later grades the circle Good. Keep the press cue quieter than the result cue.

## Build checklist status

Closed: S39 (#91), N57 and N58 (#84), N59 and N60 (#85). Open: S40 and S41, N61 to N67, and from the last batch N51, N53, N55 and N56. S36 waits on the bump build. Still to build from v0.3: S25, S26, S32 and N29 (bump), S27 and N32 (dealer), S28 (rescue), S29 (rich tip), S30 and N35 (rename), N30 (bait reveal).
