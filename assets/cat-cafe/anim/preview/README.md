# Cat motion preview (no Studio needed)

Plays the game's own cat motion code on the real Part cats and renders it to a short clip, so a change to `games/cat-cafe/src/client/Effects/` (Logic, Presets, Pose) can be seen and checked before anyone opens Studio. The cloud threads have no Studio; this is how they show Derek an animation.

How it works:

1. `rojo build preview.project.json` packs every model in `assets/cat-cafe/rbx/` into one `.rbxm`.
2. `dump.luau` runs in [Lune](https://lune-org.github.io) (a standalone Luau runtime with Roblox's CFrame, Vector3 and Instance types). It loads `Logic.luau`, `Presets.luau` and `Pose.luau` unchanged, binds a cat with `Pose.bind`, and for each frame does what `Cats.luau`'s step does (the style's idle, the settle from the last style, the gait), then `Pose.draw`. It writes every part's CFrame and Size, and the z's from `Logic.napZ`, to JSON. The few engine calls Lune lacks (`GetPivot`, `GetScale`, `Workspace:BulkMoveTo`, `os.clock`) are filled in at the top of the file.
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

Scenarios (which cat, which styles for how long, how fast it walks, which view) are in `scenarios.luau`. Clips are scratch output: keep them out of Git and post them in the thread instead.
