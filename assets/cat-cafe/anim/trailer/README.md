# Store page video: the scene in the real game

Derek asked on 2026-11-03 for a gameplay video for the store page: a player catches a cat, runs it home dodging two or three players who dive at them, and the cat ends up working in their cafe. Roblox only accepts real in-game footage for store videos (Creator Hub, Thumbnails > Videos), so this is not a render. These scripts stage the scene inside the actual game in a Studio playtest, with the game's own systems doing every part of it, and Studio's view is recorded while a take plays.

The storyboard and shot list are in the project library, `Animation-Engineer/trailer/storyboard.md`. Sound-Agent's music and sound effects are in `Sound-Agent/trailer/`.

## What is here

| File | Where it goes in the place | What it does |
|---|---|---|
| `trailer.project.json` | the whole place | The game's normal Rojo tree (`games/cat-cafe/src`, `assets/cat-cafe/rbx`) plus the three files below. The published game is built from `default.project.json`, which never has them. |
| `TrailerConfig.luau` | `ReplicatedStorage.TrailerConfig` | Every number of the scene: the cat, the cafe, the cast's catalog outfits, where everyone stands, the dodges, each shot's timing and framing. |
| `TrailerDirector.server.luau` | `ServerScriptService.TrailerDirector` | Stages the scene through the game's services: the save becomes a Tier 3 cafe with four cats round the starter Tabby (so the star's check-in takes the Entertainer's spot by the game's own rule) and every tip and ask already seen, day time, the player as the default Roblox avatar (R6, Pal Hair, Blue and Black Motorcycle Shirt, Dark Green Jeans), Rocker Cat as a real stray 205 studs down the Alleyway, and the three shovers built from their outfits. It answers the take's cues: `home` sends the player to their cafe, `reset` stages everything again. |
| `TrailerCamera.client.luau` | `StarterPlayerScripts.TrailerCamera` | Runs a take: the player walks down the lane, swings the real net (the same two calls as the Net button), presses each catch circle at its exact time so the catch lands, carries the cat home at the getaway speed, and the camp checks it in. The shovers are local copies of the server's characters, moved by their root and drawn by the game's Effects (net in hand, the Tackle's dive, belly slide and get up). It moves the camera shot by shot and hides every screen but the toasts, the Roblox menus and the mouse pointer. |

Studio only: both scripts do nothing outside Studio. The director also refuses to stage while the server's saves reach the real DataStore, so a take never touches anyone's real save. Open the Rojo-built file, not the published place.

## Running a take

```sh
cd assets/cat-cafe/anim/trailer
rojo build trailer.project.json -o CatCafeTrailer.rbxl
```

1. Open `CatCafeTrailer.rbxl` in Studio (File > Open from File). It is a local copy, so it does not block publishing.
2. Press Play (Play Solo). The Output shows `[Trailer] staged take 1` and then `[Trailer] camera ready`.
3. Start recording the game view, then let the take start by itself 6 seconds after staging, or click in the game view and press **T**.
4. Each shot's start is printed as it cuts (`[Trailer]   4.00  approach`), timed from the take's start, and the whole list is printed again at the end.
5. **R** stops a take and stages the scene again (a new stray, the player back at the start); the next take starts 6 seconds later.

A take is about 30 seconds: establish 4 s, the walk to the cat, the swing and the catch circles (cut out in the edit), caught 1.4 s, the run home with three dodges (about 9 s), the check-in and 2.4 s on the camp, then the cafe push in for 6.5 s and 3 s held for the logo.

Recording: the ideal is 1920x1080 at 60 fps. Studio's game view can be set to 1920x1080 with the Device emulator (Test > Device), then captured with OBS (Window capture) or ffmpeg (`ffmpeg -f gdigrab -framerate 60 -i title="..."`). The game's own sound comes through Studio; Sound-Agent's mix is laid in at the edit.

## Tuning

Change `TrailerConfig.luau`, rebuild (or sync with `rojo serve trailer.project.json`) and press Play again. The things most likely to need a nudge in Studio:

- `camera.*`: each shot's framing. Tracking shots are offsets in the runner's own space (x right, y up from its middle, z behind), and a dodge shot's x flips when the runner cuts left.
- `dodge.*`: when each shover starts its run (`chargeLead`), when it dives (`diveLead`), and how far the runner cuts (`cutStuds`). The lunge, the belly slide's pose and the get up are the game's own Tackle numbers.
- `starDepth`, `heroDepth`, the shovers' `depth` and `side`: where things happen along the Alleyway (depth in studs from the name arch, across to the right of a player running home).

## Checks

The game's gate covers `games/cat-cafe/src` only. For these files, from this folder:

```sh
rojo sourcemap trailer.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=../../../../games/cat-cafe/globalTypes.None.d.luau --ignore "**/Vendor/**" TrailerConfig.luau TrailerDirector.server.luau TrailerCamera.client.luau
stylua --config-path ../../../../games/cat-cafe/stylua.toml --check .
```

Keep `sourcemap.json` and any built `.rbxl` out of Git.
