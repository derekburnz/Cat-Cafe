# Purr Pot animation and VFX list

Draft v0.1, 2026-10-26. Owner: vfx-animator. Readers: luau-engineer (hooks and the cat rig), ui-designer (screen versus world), sound-designer (same moment names), asset-artist (parts and swatches), luau-reviewer, qa-playtester. How each tool works, the style rules and the phone budgets are in `.claude/skills/animation-vfx/SKILL.md`; this file is the what and the when.

Nothing here changes gameplay. Every entry runs on the client, reads state the client already has and fits the low tier budget. Priorities: **P1** makes the ten-minute slice loop read (features.md priorities 11 and 12), **P2** ships in the slice if time allows, **P3** after the slice. Tools: **proc** is procedural joint motion (`Motor6D.Transform`), **tween** is TweenService, **clip** is a published Animation Editor clip, **fx** is ParticleEmitter, Beam, Trail or Highlight. Particle counts are high tier; the low tier halves them and drops anything marked "high only".

Moment names match the sound list (agreed with the sound thread) and become Signals in `src/client/Moments.luau`; where each one fires in today's code is in `docs/audio/cat-cafe/sound-list.md` section 6. Effects that other players must see also read replicated state (tags, attributes, the `HeldCat` model), listed in the hook column.

## 0. Foundation (build first)

| id | what | owner | P | notes |
|---|---|---|---|---|
| A0.1 | Cat rig on clone: invisible anchored `Root` at the floor pivot as PrimaryPart, Motor6D Root to Body, Body to Head, Body to Tail at `joints_roblox`, parts renamed `Body`, `Head`, `Tail`, AnimationController with Animator | engineer (recipe in skill section 3) | P1 | One function for strays, stuck cats, placed cats, the held cat and placeholders. The held cat's weld loop skips parts that already have a Motor6D, and its `HoldWeld` goes from HumanoidRootPart to Root |
| A0.2 | `src/client/Moments.luau`: one Signal per moment, fired from UIController, WorldController and CustomerController | engineer | P1 | Proposed in decisions.md with the sound thread |
| A0.3 | `src/client/Effects/` skeleton: `init.luau` (`Effects.start(moments)`), `Presets.luau`, `CatMotion.luau`, `PropMotion.luau`, `NightGlow.luau`, `AnimationIds.luau`, the low or high tier picked once on join, emitter pool under `workspace.Terrain` | vfx-animator | P1 | Started from `Main.client.luau` after the controllers |
| A0.4 | Stray exit attribute: before removing a stray or stuck cat the server sets `Exit` to `caught`, `fled`, `expired` or `wave`, disables its prompt and destroys it 0.5 s later | engineer | P1 | Lets every client play the right exit (sparkle, dash, puff) on a model that still exists. Today `despawn` destroys at once (CatService.luau:167) |
| A0.5 | Net on the character: the owned `CatCafe_Item_Net_L<level>` attached to the right hand by a Motor6D named `NetGrip` while the player is in the alley or park and not carrying | engineer, asset-artist for the grip offset | P1 | The net models exist with `_Handle` and `_Bag`; nothing holds them yet |

## 1. Cats everywhere (placed, stray, stuck, held)

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| idle (placed) | Breathing bob of the Body (0.03 stud, about 4 s cycle), slow tail sway, head turns towards the nearest customer every 3 to 6 s (yaw capped at 35 degrees), cats on a Cushion or Cat bed sleep with the head down | proc | one shared loop, cats within 60 studs | `Plot/Cats` children | P1 |
| favorite spot | A happy tail curl every 10 to 15 s for a cat sitting on its favorite spot type, so the 1.5x bonus is visible without UI | proc | none | spot `SpotType` vs catalog `favoriteSpot` | P2 |
| walk (stray) | Head nods in step with Mover's walk bob (it bobs at 9 rad/s), tail up while walking, tail down when it stops | proc | none | the stray's pivot moving | P1 |
| CatPlaced | The cat lands on its spot with a small hop (Body joint up 0.4 stud and back, 0.25 s) and 4 offwhite dust dots | proc, fx | 4 particles | Moments, or a new child under `Plot/Cats` | P1 |
| sleepy at night | Placed cats yawn once when NightStart fires (head tilt back, 0.6 s) | proc | none | Clock `Phase` | P3 |

## 2. Net swing

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| net at rest | Net held low, sways a little with walking | proc on `NetGrip` | none | A0.5 | P2 |
| NetWindup | Net lifts back over 0.3 s and trembles more as the ring tightens; the stray flattens and crouches (Body joint down 0.1 stud, head low) | proc | none | `UI.events.grabBegan` | P1 |
| NetRingGood, NetRingPerfect | A small mint glint on the net rim on entering the good band, a gold glint on perfect: the world echo of the ring for players who watch the cat, not the HUD | fx | 3 and 6 particles | fired by UIController from `Config.RingGoodWindow` and `RingPerfectWindow` after grabBegan | P2 |
| NetSwing | 0.25 s forward arc (Quad Out) with a soft white Trail on the net rim | proc, fx (Trail 0.2 s) | 1 Trail | `grabEnded`, or the full hold running out | P1 |
| arm swing | The player's arm swings with the net and other players see it | clip on the player's own Animator, keying the `NetGrip` joint too, so it replicates | 1 track | NetSwing | P2. This is the first published clip, so it also proves the ownership flow in skill section 4 |

## 3. Catch outcomes

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CatchSuccess | Stray hops towards the player (0.25 s), then a burst by rarity: Common 8 offwhite dots; Rare adds 6 blue sparkles; Epic adds a purple ring (one particle that grows from 0.5 to 3 studs and fades); Legendary adds 10 gold sparkles and a 0.8 s gold Highlight on the held cat | proc, fx | 24 particles at most (Legendary), 1 Highlight | local: `GrabResult` ok; everyone else: `Exit = caught` | P1 |
| CatchFail, retry | Startle hop (Body joint 0.4 stud, 0.2 s), head jerks back, 4 fur puffs in the cat's base color, the net bounces back | proc, fx | 4 particles | `GrabResult` with retry | P1 |
| StrayFlee | The stray dashes 3 studs away from the player over 0.4 s, then a small soft puff and it is gone | tween on the pivot (the server no longer moves it once `Exit` is set), fx | 6 particles | `Exit = fled` | P1 |
| RareStrayNearby | Epic and Legendary strays shimmer: 2 sparkles a second in the rarity color | fx | 2 emitters within 40 studs, Rate 2 | `Stray` tag plus `Rarity` | P2 |
| Legendary outline | A soft gold outline on a Legendary stray within 40 studs, hidden behind walls (`DepthMode = Occluded`) | fx (Highlight) | 2 at once | `Stray` tag plus `Rarity` | P2. See open question 2 |
| Announce | The catcher's held Epic or Legendary keeps one soft halo in its rarity color for the whole carry, so people on the street can spot it | fx | 1 particle per held cat | `HeldCat` model with an Epic or Legendary `CatId` | P2 |

The "Cat found" popup with its sparkles is the ui-designer's and stays as it is.

## 4. Bait

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| BaitPlaced | The bowl drops in from 1 stud with a Back Out bounce (0.3 s) and 4 crumbs in the food's swatch (kibble, fish_blue, blush for salmon) | tween, fx | 4 particles | the bowl model appearing in the strays folder; needs `LureSpotId` and `PlacedBy` attributes on it | P1 |
| waiting | A soft scent wisp rises from the bowl, from 1 to 3 particles a second over the 45 s wait, tinted by food | fx | 1 emitter per active bowl | the bowl's `PlacedAt` attribute (new) | P2 |
| BaitArrive | A soft pop where the bowl was and the cat sits there; the placer alone sees a slow mint heart over it while it is reserved for them | fx | 6 particles, then Rate 0.5 | the lured stray's `ReservedFor` equal to the local UserId | P1 |
| walk-in | The cat walks in from 3 studs away and eats from the bowl instead of replacing it | proc | none | engineer: keep the bowl until the cat is caught or leaves and spawn the stray 3 studs out (CatService.luau:934 removes it today) | P2 |
| BaitExpire | The cat yawns, walks off 2 studs and puffs away | proc, fx | 6 particles | `Exit = expired` | P2 |

## 5. Rescue hold

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| stuck idle | The cat holds its `stuck_pose` and looks around every 2 to 4 s with a tail flick; one faint sparkle in its rarity color every 2 s so it can be found at night | proc, fx | 1 emitter per stuck cat, Rate 0.5 | `StuckCat` tag | P1 |
| RescueHold | The prop answers the hold: the tree shakes a little and drops 2 leaves a second, the box flaps wobble, the drainpipe rattles; the cat wriggles faster as the bar fills | tween on the prop (anchored and never moved by the server), proc, fx | 2 particles a second | `UI.events.rescueBegan`; progress is time since the hold began over `Config.RescueHoldSeconds` | P1 |
| RescueCancel | Prop and cat settle back over 0.3 s | tween, proc | none | `rescueEnded` with completed false | P2 |
| RescueDone | A burst of 8 blush hearts (plus a shower of 6 leaves for the tree) and the cat is in the player's arms; one "grateful" heart pops over the held cat | fx | 14 particles | local: `rescueEnded` completed; everyone: `Exit = caught` on the stuck cat | P1 |

## 6. Carry and check-in

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CarryStart | The held cat settles into the carried pose with a small dip (Body joint 0.1 stud, 0.2 s) | proc | none | a `HeldCat` model added under any character | P1 |
| carried idle | Slow tail sway, head looks ahead, breathing; every player sees it because every client animates every held cat within 60 studs | proc | shared loop | `HeldCat` | P1 |
| grateful | A rescued cat sends up one heart every 4 s while carried | fx | Rate 0.25, high only | `HeldCat` with a rescued flag (attribute needed) | P2 |
| CheckIn | A heart and sparkle burst at the cafe door; the carrier also sees the cat hop towards the door | fx, proc | 10 particles | local: CheckIn; everyone: `HeldCat` removed near a plot `Door` | P1 for the burst, P2 for the hop |

## 7. Coins and purchases

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| CoinPop | 3 small gold coins pop 1 stud up from the table and fade (0.6 s), next to the existing `UI.floatText` "+$8" | fx | about 4 particles a second for a full cafe | CustomerController.luau:135; low tier keeps the float text only | P1 |
| Purchase | The new table, chair set or decor drops in from 0.5 studs with a Back Out bounce and 10 sparkles | tween on a `CFrameValue` driving `PivotTo`, fx | 10 particles | a decor or table model appearing under its anchor | P1 |
| espresso upgrade | A steam burst on the new machine, then a slow steam wisp on L2 and L3 | fx | 6 particles, then Rate 1, high only | the espresso model swap | P2 |
| LevelUp | Palette confetti at the cafe door (16 particles) and a soft ring on each spot the new level opens | fx | 16 plus 1 per new spot | `upgradeLevels.cafe_level` rising in ProfileSync | P1 |
| AreaUnlock | The park gate leaves swing open (`_LeafL` and `_LeafR`, 0.8 s Back Out) and a sparkle arch | tween, fx | 12 particles | WorldController's park gate open; today it only goes see-through | P1 |

## 8. Day and night

The 4 s lighting change and the night parts turning Neon with their lights already exist (WorldController.luau, style guide section 9). These add to it.

| moment | what you see | tool | budget | hook | P |
|---|---|---|---|---|---|
| lamp halos | One soft warm halo per lit bulb (street lamps, string lights, shop windows), fading in with the 4 s lighting change | fx (1 locked particle, LightEmission 1, Size 2.5, Transparency 0.6) | bulbs within 80 studs, about 12 particles | NightStart, night parts by suffix | P1 |
| door sign | The door sign flips: rotate 90 degrees, swap `DoorSign_Open` and `_Closed`, rotate back (0.4 s) | tween | none | Clock `Phase` | P1 |
| wave arrival | Each new stray appears with a soft puff, staggered 0.1 s apart so six puffs never land on one frame | fx | 6 particles each, 36 total over 0.6 s | NightStart plus new `Stray` tags | P1 |
| street lamp cone | A faint light cone under each street lamp | fx (Beam, Transparency 0.88, Segments 1) | 1 per lamp within 80 studs | NightStart | P2 |
| window shafts | One warm light shaft from each lit shop window onto the alley floor | fx (Beam) | 1 per window within 60 studs | NightStart | P2 |
| fireflies | Three slow fireflies near park plants and the patio | fx | 2 emitters at most, Rate 1, Lifetime 4 s, high only | NightStart | P2 |
| DayStart | Halos and beams fade out with the lighting; placed cats stretch once (head and tail up, 0.8 s) | fx, proc | none | DayStart | P2 |

## 9. Worst case on a phone (low tier)

Night start in the alley, 6 strays arriving, the player catching a Legendary, other players' customers out of range:

| source | particles alive |
|---|---|
| wave arrival puffs (halved) | 18 for 0.6 s |
| lamp halos | 12 |
| Legendary catch burst (halved) | 12 for 0.8 s |
| stuck cat sparkles (2) | 2 |
| bait wisp, calm heart | 3 |
| total | about 47, against the 150 budget |

Highlights in that scene: one from the catch, at most two Legendary outlines. Trails: one. The procedural loop covers about 6 strays, 2 stuck cats and 1 held cat within 60 studs. The cafe on the same phone adds its own placed cats (up to 7) and coin pops (about 2 alive). The numbers get measured in Studio once A0.1 to A0.3 exist.

## 10. Requests to other roles

- **luau-engineer**: A0.1 cat rig, A0.2 Moments, A0.4 `Exit` attribute, A0.5 net on the hand. Attributes on the lure bowl (`LureSpotId`, `PlacedBy`, `PlacedAt`) and a rescued flag on the held cat. P2: keep the bowl and walk the lured cat in. Noticed while planning, not an Effects matter: strays walk by the server calling `PivotTo` every Heartbeat (Mover.luau), which sends every stray's position every frame; worth a look if the night alley lags on phones.
- **ui-designer**: none required. Optional: an `UI.events.ringBand(band)` signal when the ring enters good or perfect, if you would rather fire NetRingGood and NetRingPerfect than have the controller time them.
- **asset-artist**: the `NetGrip` offset for each net level (where the hand holds the `_Handle`), and a sit pose or separate leg objects for customers when they get a sitting animation (P3).
- **sound-designer**: same moment names; markers in published clips (`Land`, `Pounce`) can fire sound cues too.

## 11. Build order

1. A0.1 to A0.3 (rig, Moments, Effects skeleton), then cat idle, stray walk and carried idle. Every later item reuses this.
2. Catch success by rarity, catch fail, flee (A0.4).
3. Rescue: stuck idle, hold, done.
4. Bait: placed, arrive, calm heart.
5. Coins, purchase, level up, park gate.
6. Night: halos, door sign flip, wave arrival puffs.
7. Net on the hand (A0.5), windup and swing; then the first published clip (the R15 arm swing) to prove the ownership flow before anything depends on clips.
8. P2 items in the order the playtest asks for them.

## 12. Open questions

1. Gavin's question 15 (upright working cats in uniforms): an upright cat bends at the hips, which the three-part rig cannot do. If the answer is yes, the Blender skinned rig (skill section 3, step 3) moves into the slice and needs the asset-artist's split meshes.
2. Legendary outline: drawing it through walls (`DepthMode = AlwaysOnTop`) would work as a radar in a first-catch-wins race. The draft keeps it `Occluded`; the game-designer decides if any rarity should show through walls.
3. Reduce Motion: the draft drops idle loops except breathing when the player has Reduce Motion on. Derek, say if you would rather keep the tail wag.
