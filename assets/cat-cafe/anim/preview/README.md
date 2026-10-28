# Cat motion preview (no Studio needed)

Plays the game's own cat motion code on the real Part cats and renders it to a short clip, so a change to `games/cat-cafe/src/client/Effects/` (Logic, Presets, Pose) can be seen and checked before anyone opens Studio. The cloud threads have no Studio; this is how they show Derek an animation.

How it works:

1. `rojo build preview.project.json` packs every model in `assets/cat-cafe/rbx/` into one `.rbxm`.
2. `dump.luau` runs in [Lune](https://lune-org.github.io) (a standalone Luau runtime with Roblox's CFrame, Vector3 and Instance types). It loads `Logic.luau`, `Presets.luau` and `Pose.luau` unchanged, binds a cat with `Pose.bind`, and for each frame does what `Cats.luau`'s step does (the style's idle, the settle from the last style, the gait, the Balloon Cat's float, the stretch), then `Pose.draw`. It writes every part's CFrame and Size, and the z's from `Logic.napZ`, to JSON. The few engine calls Lune lacks (`GetPivot`, `GetScale`, `Workspace:BulkMoveTo`, `os.clock`) are filled in at the top of the file.
3. `render.py` draws each part from its Roblox shape in headless Blender (the `bpy` pip module, Cycles on the CPU), with the z's where the BillboardGui would put them, and writes PNG frames, an MP4, a GIF and a strip of six frames.

What it does not cover: `Cats.luau` itself (which cats move, budgets, the hiss and the gold sparkle), lighting and the camera as the game has them, and Motor6D rigs. Treat a clip as a check of the motion, and Studio as the final word.

## Run it

```sh
# once: rojo 7.7.1 (rokit.toml), lune 0.10.4 (github.com/lune-org/lune/releases), python 3.13 with `pip install bpy pillow`, ffmpeg
cd assets/cat-cafe/anim/preview
./preview.sh sleep /tmp/catclips          # one scenario
./preview.sh "sleep doze walk" /tmp/catclips --samples 16
# a before and after against another copy of the Effects folder (say main's, exported with git show):
lune run dump.luau /tmp/catclips/cats.rbxm sleepSide /tmp/catclips/before.json /tmp/main-effects/
```

Scenarios (which cat, which styles for how long, how fast it walks, which view, and for a seated cat the role whose outfit it wears) are in `scenarios.luau`. Show Derek the cats he knows: they use the Tabby, the orange cat of Model-Agent's pose sheets, and the default view is the sheets' camera (front left, the face towards the camera); a working cat wears its outfit the way the server's `CatPose.dress` puts it on. Clips are scratch output: keep them out of Git and post them in the thread instead.

## Stuck cats

The `stuck*` scenarios put a cat in a rescue trap with its wriggle. A `trap` scenario stands the trap prop (the Alleyway's bin and bags, the Park's can and tree) with its pivot at the origin and pivots the cat by the prop's `Layout.stuckPoses` entry, read from `Layout.luau` itself. A `trapSet` scenario draws the parts of an area set (the Neighbourhood's shed and gutter, the Woods' log, bramble and tree house branch, the Sewer's grate and drain pipe) within `radius` studs of a trap spot, seen from the ground under the spot turned by the piece, exactly as Layout's `setTrap` gives it, so the cat sits where WorldBuilder would put it with that pose. `stuckAt` tries a pose before it goes to the Gameplay-Engineer (12 numbers, as in `Layout.stuckPoses`), `box` frames the trap's opening, and the `right` and `low` views see a trap that opens to +X or sits up on a roof. A part with a sphere mesh draws as an ellipsoid of its size times the mesh's Scale, as the game draws a bush or a bin bag.

## Player poses (the Tackle)

`avatar.luau` does the same for the Tackle's character poses (`Avatar.luau` and `Presets.tacklePose`, unchanged) on a stand-in blocky R15 in the palette's shirt and skin swatches, built from plain tables with the members `Avatar.bind` reads. The engineer's lunge and knockback are copied as straight moves at the design's speeds. Scenarios: `miss`, `hit` (into a player facing the tackler) and `behind` (into one facing away). The JSON carries a fixed `box` and the checker floor, so the camera watches the whole run from one place. The carry has its cat in it, so it runs in `dump.luau`: `carryLoaf` and `carrySit` put the cat on the stand-in's folded arms (`Avatar.carryArms`, `Avatar.cradle`) as Carry.luau does, standing and then walking at carry speed. `net` is three players holding the level 1, 2 and 3 nets (`Avatar.holdNet`, `Presets.netHold`), standing and then walking with the camera following; it reads the nets from the assets rbxm, passed after the Effects folder (an empty Effects argument keeps the default). The stand-in itself is in `standin.luau`.

```sh
lune run avatar.luau hit /tmp/catclips/hit.json
lune run avatar.luau net /tmp/catclips/net.json "" /tmp/catclips/all.rbxm
python render.py /tmp/catclips/hit.json /tmp/catclips --samples 10
```
