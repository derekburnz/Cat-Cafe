---
name: animation-vfx
description: How Purr Pot cats, customers, props and moments move and sparkle: picking procedural motion, a Motor6D rig with the Animation Editor or a Blender skinned rig, AnimationController and Animator playback, publishing animations and who must own them, client-side tweens, ParticleEmitters, Beams, Highlights and night glow in the Cozy Cream style, and the low-end and mobile budgets. Use for any animation, tween, particle, glow or "make it feel good" task.
---

# Animation and VFX for Purr Pot

Everything here is cosmetic. It runs on each player's device, never decides gameplay, and must look the same on a cheap phone as on a PC, only with fewer particles. Read with `asset-pipeline` (pivots, naming, palette) and `docs/art/style-guide.md` (colors, lighting table, poses). Third-party references: `roblox-characters-animation` (Animator, tracks, priorities, tweens), `roblox-dev-skill/references/performance-optimization.md` (MicroProfiler, shadows), `roblox-mobile-playtest` (phone pass), `blender-to-roblox/references/export-rules.md` (rig export rules).

## 1. Roblox concepts in one line each

- **Rig**: a model whose parts are joined by joints the engine can bend. Two kinds: parts joined by **Motor6D** joints, or one mesh with **Bones** inside it (a skinned mesh, made in Blender).
- **Motor6D**: a joint between `Part0` (the parent part, for a cat the Body) and `Part1` (the child, the Head). The child sits at `Part0.CFrame * C0 * Transform * C1:Inverse()`. Animations write `Transform`; it is not replicated, so writing it from a LocalScript moves the part only on that player's screen.
- **Animation**: an instance holding `AnimationId = "rbxassetid://<number>"`, the id of an animation asset published to Roblox.
- **Animator**: the object that plays animations on a rig. It lives under a `Humanoid` (player characters) or under an **AnimationController** (anything else, like our cats). `animator:LoadAnimation(animation)` returns an **AnimationTrack** you `Play`, `Stop`, `AdjustSpeed` and `AdjustWeight`. `Humanoid:LoadAnimation` and `AnimationController:LoadAnimation` are deprecated.
- **KeyframeSequence**: the editable source of an animation, saved by the Animation Editor into ServerStorage. Only the published asset plays in a live game.
- **TweenService**: moves a property from A to B over time with an easing curve. Good for UI, doors, signs and bowls. One tween per property at a time.
- **ParticleEmitter**: sprays small textured cards (particles) from a part or an **Attachment** (an invisible point inside a part). `Rate` for a steady stream, `emitter:Emit(n)` for a one-off burst.
- **Beam**: a textured strip drawn between two Attachments (light shafts, a glowing lead from bowl to cat).
- **Trail**: a fading ribbon left behind by two moving Attachments (the swoosh of a net swing). Keep `Lifetime` under 0.3 s.
- **Highlight**: an outline and fill drawn around a model, visible through walls if you want it to be.
- **PointLight / SpotLight**: real lights; with `Lighting.Technology = Future` they light the room. `Shadows` on a light is the expensive part.
- **Bloom**: a post effect that makes Neon parts and bright particles glow. Our setting is low (style guide section 9).

## 2. Which tool for which job

| Job | Tool | Where it runs | Owner |
|---|---|---|---|
| Buttons, popups, coin counter, catch circles, rescue bar | TweenService on GuiObjects (`UI/Components/Tween.luau`) | client | ui-designer |
| Props: park gate leaves, door sign flip, bowl drop, espresso steam, decor pop-in | TweenService on anchored parts, or a `CFrameValue` driving `model:PivotTo` | client | vfx-animator |
| Cat idle, look at customer, tail wag, ear twitch, carried wriggle in the slice | Step 1: procedural `Motor6D.Transform` on the cat's Body, Head and Tail joints | client | vfx-animator (rig set-up by engineer) |
| Authored cat clips: stretch, pounce, curl up, happy hop, the stuck wiggle per rescue trap, the role idles once they need hand-keyed timing | Step 2: the same Motor6D rig keyed in the Animation Editor, published, played by an Animator | client | vfx-animator |
| Working cats standing upright in their role uniform at a station | Step 1 rig with the manifest's upright pose as the Body and Head joints' rest offset; uniforms welded to Body or Head | client | vfx-animator (rig set-up by engineer) |
| Bendy cats: spine, walking legs, ears, waving front paws | Step 3: Blender armature and skinned mesh, generated in Python | client | vfx-animator with asset-artist |
| Strays walking and fleeing | Server moves the pivot (`shared/Mover.luau`); the client adds joint motion on top | server pivot, client joints | engineer, vfx-animator |
| Customers | Walk bob in `Mover`; a Motor6D rig needs separate arm and leg objects from the asset-artist | client (customers are client-only) | vfx-animator |
| Bursts, sparkles, glows, light shafts, outlines | ParticleEmitter, Beam, Highlight, Neon plus lights | client | vfx-animator |
| Day and night lighting presets and night parts | `Controllers/WorldController.luau` from style guide section 9 | client | engineer today; extras on top are vfx-animator |

Rule of thumb: start on the cheapest row that looks good. Procedural motion costs nothing to upload and can be tuned in code review; a published animation is a separate asset with ownership rules (section 4).

## 3. The rig ladder for cats

The cat ships as three MeshParts, `<Name>_Body`, `<Name>_Head`, `<Name>_Tail`, with the Head pivot at the neck and the Tail pivot at the tail root. `assets/cat-cafe/exports/manifest.json` gives both joints per cat as `joints_roblox` (model space, studs from the floor pivot). Every pose in `poses` (upright, carried) and every `stuck_pose` is Body CFrame plus Head and Tail angles, so it maps straight onto the joints. A working cat (design v0.3 roles) is the same rig with `poses.upright` and its `head_offset_roblox` as the rest offset of the Body and Head joints, so standing up at a station and dropping to all fours are a 0.4 s tween of two offsets, and the role uniforms (welded to Body or Head at `upright_attachments`) follow every motion.

### Step 1: Motor6D rig built in code, procedural motion (the slice)

The engineer turns a cloned cat into a rig when it spawns (one shared function, used for strays, stuck cats, placed cats and the held cat). The rig is `Root -> Body -> Head, Tail`: `Root` is an invisible, anchored, non-colliding 1 x 1 x 1 Part at the floor pivot and becomes the `PrimaryPart` (the asset-pipeline rule). The root part has no joint of its own, so it cannot be animated; giving the Body a joint to Root is what lets a clip or the code bob, lean or hop the whole cat.

Animation clips find parts by name, so the rig also renames the imported `CatCafe_Cat_<Name>_Body`, `_Head` and `_Tail` MeshParts to plain `Body`, `Head` and `Tail` (the placeholders already use these names) and keeps the asset name in an attribute. That is what lets one clip play on all twelve breeds.

```lua
-- jointWorld for Body is the model pivot; for Head and Tail it is the manifest's joints_roblox, in model space.
local function joint(part0: BasePart, part1: BasePart, jointWorld: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = part1.Name -- "Body", "Head", "Tail" after the rename
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(jointWorld)
	motor.C1 = part1.CFrame:ToObjectSpace(jointWorld)
	motor.Parent = part0
	part1.Anchored = false -- only Root stays anchored, so Root is the assembly root
	part1.CanCollide = false
	part1.Massless = true
	return motor
end
-- joint(root, body, pivot); joint(body, head, pivot * CFrame.new(headJoint)); joint(body, tail, pivot * CFrame.new(tailJoint))
```

Then add an `AnimationController` with a child `Animator` to the model so step 2 needs no rebuild. Server code that treats the Body as the PrimaryPart (the held cat's welds, the name tag) moves to Root, and the held cat code must not weld parts that already have a Motor6D, or the head freezes.

The client drives motion with one `RunService.PreSimulation` connection for all cats (not one per cat), writing `motor.Transform = offset` from a sine or a small state machine (idle, look, wag, sleep). Because `Transform` is not replicated, the server moving a stray's pivot never fights the client's head bob. The Animator writes `Transform` for every joint a playing track uses each frame, before `PreSimulation`; once step 2 clips exist, leave a joint alone while a track drives it, or layer a small offset with `motor.Transform *= offset` only while that track is playing.

### Step 2: Animation Editor clips on the same rig

1. In Studio, open the Animation Editor (Avatar tab; search "Animation Editor" in Studio's command search if the ribbon moved) and select a rigged cat in Workspace. Root must be the assembly root: it is the only anchored part, which is enough. `PrimaryPart` does not decide this.
2. Key the clip on the Body, Head and Tail tracks. Name events with markers (`Pounce`, `Land`) so code can sync a sparkle or a sound via `track:GetMarkerReachedSignal("Land")`.
3. Save (keeps the KeyframeSequence in ServerStorage), then right-click the KeyframeSequence > Save to File as `assets/cat-cafe/anim/keyframes/<Clip>.rbxm` so the source is in Git.
4. Publish: Animation Editor `...` menu > Publish to Roblox. Pick the **Creator** that owns the experience (Derek's account now, the Roblox Group once it exists). Copy the asset id into `src/client/Effects/AnimationIds.luau` with the creator next to it.
5. Before publishing, `KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)` gives a temporary id for trying a clip in a Studio playtest. Treat it as Studio only.

Playback on the client:

```lua
local track = animator:LoadAnimation(animation) -- once per Animator per clip, then reuse
track.Priority = Enum.AnimationPriority.Idle    -- Core < Idle < Movement < Action < Action2..4
track.Looped = true
track:Play(0.2)                                  -- 0.2 s fade in
```

Play cat clips on the client: each player animates their own copy, nothing goes over the network, and two players seeing a tail wag at slightly different moments does not matter. Only the local player's own character replicates client-played animations to others.

### Step 3: Blender skinned rig (after the slice)

Generate the armature and weights in Python next to the asset-artist's meshes so it rebuilds like everything else: `assets/cat-cafe/anim/rig.py` imports the cat from `assets/cat-cafe/blender/cats.py` (read only), adds bones, weights and clips, and exports FBX to `assets/cat-cafe/anim/exports/`. Rules from `blender-to-roblox`: bones frozen (scale 1, rotation 0), root bone at the origin, at most 4 influences per vertex, nothing weighted to the root, one animation per FBX, no leaf bones. Our budget: at most 20 bones per cat, the triangle budget unchanged (1,500). Import with the 3D Importer (Rig on), then each clip through Animation Editor `...` > Import > From FBX Animation, and publish as in step 2. Ask the lead to copy `blender-character-rigging` and `blender-animation` from EL4CTEO/blender-skills (see `.claude/skills/THIRD_PARTY.md`) before starting.

## 4. Animation ownership (why clips silently fail live)

- An animation plays in a live server only if its owner can use it in that experience. Publish every clip under the same creator that owns the experience. In Studio it may still play for its owner, so a clip that works in Studio and not live is almost always this.
- Moving the game to a Roblox Group later: either re-publish each clip under the Group or grant the experience on each animation's Permissions page in the Creator Hub (Enter Universe IDs). Grants cannot be revoked. Check the current rules in the Creator Docs (`roblox_docs` MCP) before the move; they have changed before.
- Keep every id in `src/client/Effects/AnimationIds.luau` with its creator, so the Group move is one list to work through, and so the reviewer can see no id came from someone else's account.
- Never use animation ids found in other games or the Creator Store; they are someone else's asset and break live. Original motion only (CLAUDE.md rule 8). The one exception is Roblox's own default character animations (the ids inside the default `Animate` script of a player character in a Studio playtest): Roblox owns them and they play in any experience, which is enough for an R15 NPC such as the night dealer. Copy the ids from that script, not from memory.
- Particle and beam textures are image assets with the same rule: publish them under the experience's creator, and prefer Roblox's built-in textures (`rbxasset://textures/particles/sparkles_main.dds` is the emitter default) until a custom texture earns its upload.

## 5. Tweens for UI and props

- Tween on the client only. A server tween replicates every frame and stutters on phones; the server sets the final state (an attribute or a property) and every client tweens towards it.
- Anchored parts only. For a Model, tween a `CFrameValue` and call `model:PivotTo(value.Value)` in its `Changed` handler, or tween the one part the rest is welded to.
- Easing: `Back, Out` for pops (0.2 to 0.3 s), `Quad, Out` for rises and slides (0.3 to 0.9 s), `Sine, InOut` for loops and the 4 s lighting change. `Enum.EasingStyle.Spring` and `Bezier` error in `TweenInfo.new`; do not use them.
- Cancel before restarting: keep the Tween in a table keyed by instance and call `:Cancel()` when a new one starts, or two tweens fight over the same property.
- UI motion stays in `UI/Components/Tween.luau` (ui-designer). World motion goes through `src/client/Effects/`. If an effect needs UI (a coin flying into the HUD counter), ask the ui-designer for a hook; do not reach into the UI tree.

## 6. VFX in the Cozy Cream style

The room is calm and low-contrast so the cats are the color. Effects follow the same rule: small, soft, short and warm.

- **Shapes**: soft dots, four-point sparkles, paw prints, hearts, little coins, a puff of fur. Never shards, lightning, fire, smoke plumes or anything that reads as danger. No red "damage" tints.
- **Colors**: palette only (style guide section 2), as `ColorSequence` stops: `sparkle` #FFF4B0, `lamp_warm` #FFD9A8, `offwhite` #FFF9F2, `mint` #8FD3C1, `blush` #E8A0A0, coins in `rarity_legend` #FFC94D, rarity in `rarity_common` #8E97B2, `rarity_rare` #5FA8FF, `rarity_epic` #C07CFF, `rarity_legend` #FFC94D, and Mythical in the designer's proposed #FF5E7E once the asset-artist adds it to palette row 7. Add a new color to row 7 of the palette (with the asset-artist) before using it.
- **Timing**: feedback bursts last 0.3 to 0.8 s. Transparency fades 0.2 to 1 over the lifetime; size shrinks or holds, never balloons.
- **Rarity ladder**: Common is a small puff; Rare adds blue sparkles; Epic adds a purple ring; Legendary adds gold sparkles and a short Highlight outline, plus the server announcement; Mythical adds a coral ring, more sparkles and a longer outline. A shiny cat adds the `ShinySparkle` preset on top of its rarity. The ladder is the reward for rarity, so the Common burst stays plain.
- **Day and night**: by day `LightEmission = 0` (normal blending reads on cream walls); at night 0.5 to 1 so sparkles glow in the dark alley. Glow comes from Neon parts and lights under low Bloom; do not raise Bloom to make an effect read.
- **Night glow**: the night parts (`_Bulb`, `_Bulbs`, `_Pane`, `_Tube`) already turn Neon with a light (WorldController). On top: one soft halo per bulb (a single locked particle, `LightEmission = 1`, Size 2 to 3, Transparency 0.6), a faint Beam cone under the street lamp (Transparency 0.85 or more), and 2 or 3 slow fireflies near park plants. Window panes at night can throw one Beam shaft onto the alley floor.
- **Young audience and accessibility**: no more than three flashes per second, no full-screen white flash, no camera shake. When `GuiService.ReducedMotionEnabled` is true (the player's Reduce Motion setting; check it reads from a LocalScript with `roblox_docs`), skip screen-space bursts, scale pops and idle loops other than breathing.

## 7. Budgets for low-end phones

Roblox caps a single emitter at 400 particles per second, 100 on mobile; particles live at most 20 s; only 31 Highlights render on a client at once and a disabled Highlight still takes a slot. Our budgets sit far below those caps because a phone in the night alley also draws 8 cafes, 6 strays, lures and other players.

| Item | Phone (low tier) | PC (high tier) |
|---|---|---|
| Live particles on screen, all effects | 150 | 400 |
| One burst (`Emit`) | 12 | 24 |
| Steady emitters within 60 studs | 4, Rate 8 or less | 8, Rate 16 or less |
| Particle lifetime | 1.5 s (halos and fireflies 4 s) | same |
| Particle size | 1.5 studs or less (halos 3) | same |
| Textures | built-in, or 128 px; flipbooks 256 px (2x2 or 4x4) | same |
| Beams visible | 4, Segments 1 when straight | 8 |
| Trails active | 2, Lifetime 0.3 s or less | 4 |
| Highlights from our code | 2 at once, destroyed after use (never left disabled) | 4 |
| Lights we add | `Shadows = false` on every one; ranges from style guide section 9 | same |
| World tweens running | 30 | 60 |
| Procedural cat motion | one PreSimulation loop, cats within 60 studs, half rate past 30 studs, 0.5 ms per frame | 1 ms |
| Animation tracks | 3 loaded per cat (idle, action, carried), stopped past 80 studs | same |

Tier: low if the device is touch-only (`UserInputService.TouchEnabled` and not `KeyboardEnabled`) or the saved graphics quality is low (`UserSettings():GetService("UserGameSettings").SavedQualityLevel`, which reads `Automatic` when the player never changed it). Low tier halves bursts and drops ambient emitters (steam, fireflies, halos beyond 40 studs). Pick the tier once on join; do not resample every frame.

Measure, do not guess: Studio playtest with the device emulator on a phone profile, MicroProfiler (Ctrl+F6) for the frame cost of the Effects loop, and Studio Settings > Rendering > Editor Quality Level at both the lowest and highest setting. Record the numbers in the handoff.

## 8. Code shape (`games/cat-cafe/src/client/Effects/`)

- `--!strict`, luau-conventions, one module per concern: `init.luau` (public API), `Presets.luau` (every burst and loop as data: colors, sizes, counts per tier), `CatMotion.luau` (procedural joints and track playback), `PropMotion.luau` (gate, sign, bowl), `NightGlow.luau`, `AnimationIds.luau`.
- Effects only listen. They subscribe to the moment signals in `src/client/Moments.luau` (engineer-owned, one Signal per moment, shared with the sound designer's Audio module) and to replicated world state: CollectionService tags (`Stray`, `StuckCat`, `Plot`), attributes (`LockedBy`, `Rescue`, `Phase`) and models appearing (`HeldCat` under a character). They never fire remotes, never change gameplay attributes, never move a part the server also moves.
- Moment names: the shared list in `docs/audio/cat-cafe/sound-list.md` section 6, agreed with the sound designer. Do not keep a second copy here; when a mechanic changes, update that list together with the sound designer.
- Pool and clean up: one emitter per preset parked under `workspace.Terrain` attachments and moved to the effect point, `Emit(n)`, back to the pool. Anything created per effect is destroyed when it ends. No per-frame table allocation in the motion loop.
- An effect another player must see (a friend's Legendary catch) is driven by replicated state every client already has, so it needs no new remote. If one is truly needed, ask the engineer for an `UnreliableRemoteEvent` and let the reviewer check it.

## 9. Studio MCP use

Allowed: `execute_luau` to drop a test emitter or a rigged cat into the dev place and tune numbers live, `start_stop_play` and `screen_capture` for evidence, `get_console_output` for errors. Then copy the tuned numbers into `Presets.luau`; nothing tuned in Studio survives unless it is in a file. Never edit a Rojo-managed script in Studio.

## 10. Handoff note

Effects or clips added (name, moment, where it plays), files changed, animation ids with their creator, budget numbers measured on the phone profile (particles on screen, MicroProfiler ms), screenshots or a short capture per effect in `docs/vfx/cat-cafe/`, and what the engineer must hook (a moment to fire, a rig change, an attribute). Hand code to luau-reviewer and the result to qa-playtester; never sign off your own work.
