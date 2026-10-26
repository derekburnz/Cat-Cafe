---
name: audio-pipeline
description: How Purr Pot sound effects, music and ambience go from an idea to the game - Roblox audio basics, sourcing and licenses, file prep and the audio gate, naming, uploads and permissions, SoundGroups and client playback, the Cozy Cream day and night music rules, mixing for phones. Use for any sound, music, ambience or volume task.
---

# Audio pipeline (cue -> file -> Roblox asset -> game)

The "what" lives in `docs/audio/cat-cafe/sound-list.md` (every cue, the music brief, the listening list). This skill is the "how". For engine API details read the third-party `roblox-audio` skill; for Creator Store search, license checks and credits read `find-resources`.

## 1. Roblox audio in two minutes
- **Asset id.** Every sound on Roblox is an uploaded asset with a number, played as `rbxassetid://<number>`. Audio files never ship inside the place: the repo keeps the source files and the ids.
- **Sound.** The object that plays one asset. Properties we use: `SoundId`, `Volume` (default 0.5), `PlaybackSpeed` (1 is normal; 1.05 is slightly higher and faster, our cheap way to stop repeats sounding robotic), `Looped`, `TimePosition`.
- **2D or 3D.** A Sound inside a Part or Attachment is positional: it pans left and right and fades with distance between `RollOffMinDistance` and `RollOffMaxDistance` (studs). A Sound in `SoundService` plays flat in both ears; music, UI and ambience beds go there.
- **SoundService** holds the game's audio settings and our SoundGroups.
- **SoundGroup** is a mixer channel. Each Sound points at one through its `SoundGroup` property; the group's `Volume` scales all of them, and effects parented to the group (`EqualizerSoundEffect`, `ReverbSoundEffect`, `CompressorSoundEffect`) process the whole channel. Settings toggles mute groups, never single sounds.
- **Client or server.** A Sound started by a client script is heard only by that player. One started by the server replicates to everyone and ignores each player's settings. Purr Pot plays every sound on the client.
- **Loading.** A Sound downloads before it can play, so the first play of a cold sound can be late. Preload only the few that must be instant (`ContentProvider:PreloadAsync`); preloading everything slows joins.
- **Two audio engines.** Classic `Sound` and the newer Audio API (`AudioPlayer` -> `Wire` -> `AudioDeviceOutput`, with `AudioFader` and effect objects in between). The engine docs tag classic Sound members with the `LegacySound` capability, but the class is not deprecated. Purr Pot uses classic Sound plus SoundGroups for the slice: one object per sound, the most examples, and enough for a cozy game. All of it sits behind `src/client/Audio/`, so a later move to the Audio API (for acoustic simulation or voice effects) changes one folder. Never mix the two engines in one feature.

## 2. Where things live
| What | Path | Owner |
|---|---|---|
| Cue list, music brief, listening list | `docs/audio/cat-cafe/sound-list.md` | sound-designer |
| Upload-ready files | `assets/cat-cafe/audio/{music,ambience,sfx,ui}/CatCafe_<Bus>_<Name>.ogg` | sound-designer |
| Sources and license log | `assets/cat-cafe/audio/README.md` | sound-designer |
| Gate report | `assets/cat-cafe/audio/gates.md` (written by the script, never by hand) | sound-designer |
| Cue table, player, hook contract | `games/cat-cafe/src/client/Audio/{Cues.luau,init.luau,README.md}` | sound-designer, reviewed by luau-reviewer |
| Moments the code fires | `games/cat-cafe/src/client/Moments.luau` (proposed) | luau-engineer |
| CC-BY credits | `CREDITS.md` at the repo root, through find-resources `credit.sh` | sound-designer |

Creator Store audio used as it is has no file in the repo; its log row and the id in `Cues.luau` are enough. DAW projects, raw recordings and stems stay out of Git (Derek's PC or Drive); the log says where.

## 3. Names
- File name, uploaded asset name and Sound instance name are the same: `CatCafe_<Bus>_<Name>[_<Variant>]`, Bus one of `Music`, `Amb`, `Sfx`, `Ui`. Examples: `CatCafe_Music_DayA`, `CatCafe_Amb_AlleyNight`, `CatCafe_Sfx_NetSwing`, `CatCafe_Sfx_Meow_03`, `CatCafe_Ui_Click`.
- Cue ids in code are short camelCase: `netSwing`, `meow`, `uiClick`. A cue can hold variants (`meow` picks one of five files).
- Moments, the game events that fire cues, use the PascalCase names shared with the vfx-animator (sound-list section 6): `CircleGrade`, `CatchSuccess`, `NightStart`. One moment can fire several cues and several effects.

## 4. Sourcing and licenses
In this order:
1. **Roblox Creator Store audio.** Over 100,000 sound effects and music tracks from Roblox's audio partners, free in experiences, no upload needed. Search with Studio MCP `search_asset` (`scope: "creator_store"`, `assetType: "Audio"`, `priceFilter: "free"`, `verifiedCreatorsOnly: true`, `audioMinDuration`/`audioMaxDuration`) or `find-resources/scripts/search.sh --type sound` (or `music`). Licensed music is for use inside Roblox only: never in a trailer, devlog clip or any video off the platform. Take the audio id; never insert a Model only because it contains a sound.
2. **Our own.** Record it (Derek's or friends' cats for meows and purrs, a cup, a bell; a phone in a quiet room is enough) or synthesize it (UI blips, coin chimes, timing ticks with an sfxr-style tool such as jsfxr or ChipTone). Fully original, no license questions.
3. **CC0.** Kenney audio packs, Freesound filtered to CC0. Log the page link anyway.
4. **CC-BY.** Allowed with a credit in `CREDITS.md` and on the in-game credits screen; record the version (3.0 or 4.0).
5. **Paid royalty-free** (a pack, a commissioned track): only with a license that allows commercial use in a game; log where the license or receipt lives.

Never: audio ripped from games, films, anime, TV or songs (Roblox moderates uploads and copyright strikes land on Derek's account); non-commercial (NC) licenses, because the game earns Robux; "free for YouTube" music; sounds lifted from other Roblox games; AI-generated music without a plan whose terms grant commercial rights (log the plan and date); voices imitating a real person; sound-alikes of famous game themes. Never invent an asset id or a license: use only what a search or the asset's page shows.

## 5. File prep and budgets
Roblox upload limits: `.mp3`, `.ogg`, `.wav` or `.flac`, under 20 MB, under 7 minutes, at most 48 kHz, mono or stereo. We deliver `.ogg` (Vorbis, quality 5 or 6) at 44.1 or 48 kHz.

| Kind (folder) | Channels | Length | Loudness | Peak ceiling | Other |
|---|---|---|---|---|---|
| `ui` | mono | 0.02 to 1.5 s | by ear against `uiClick` | -1 dBTP | at most 10 ms of silence before the sound |
| `sfx` | mono (3D needs mono to pan) | 0.05 to 4 s | by ear against `coinPop` | -1 dBTP | at most 20 ms of silence before the sound |
| `ambience` | stereo | 20 to 120 s, seamless loop | about -26 LUFS | -3 dBTP | no fade at either end |
| `music` | stereo | 30 to 240 s, seamless loop | about -18 LUFS | -1 dBTP | loop starts and ends on the beat |

LUFS is perceived loudness over the whole file; dBTP is the loudest instant. Master files close to these so the SoundGroup volumes do the mixing, not per-file fixes. Short sounds are too short for LUFS, so match them by ear against the reference cue. Seamless loop: the end flows into the start with no click, gap or fade.

**The audio gate** measures all of this, because the agent cannot hear:
```sh
python .claude/skills/audio-pipeline/scripts/audio_gate.py            # assets/cat-cafe/audio -> gates.md
```
It needs `ffmpeg` and `ffprobe` on PATH (Windows: `winget install Gyan.FFmpeg`; cloud containers usually have them). FAIL means a Roblox limit, the name, mono or the peak is wrong. WARN means listen: length outside the budget, loudness off target or a loop seam that may click. PASS only means measured clean; Derek or Gavin still listens.

## 6. Upload and permissions
- **Who and where.** Uploads happen on Derek's PC: Creator Dashboard (Creations > Development Items > Audio), Studio's Asset Manager or `blender-to-roblox/scripts/upload-asset.sh FILE --name CatCafe_Sfx_NetSwing --type Audio` with an Open Cloud key in `ROBLOX_API_KEY` (asset write only, never pasted in chat).
- **Owner.** Upload under the same account or Group that owns the experience. Uploaded audio is private: only its owner can use it until it is shared. To share, open the asset's Permissions on the Creator Dashboard, Experiences tab, and add the experience's universe id; grants are permanent. If the game moves to a Roblox Group later (still an open question), grant every asset to the group's experience or re-upload under the group. Ask Derek before a batch.
- **Quota.** 100 audio uploads per 30 days on an unverified account, 2,000 when ID-verified. Batch uploads, and do not burn the quota on drafts: get Derek's pick first.
- **Moderation.** Every upload is reviewed. Upload only files that have a log row with a clean license.
- **After upload.** Put the id in `Cues.luau` and the log row in the same commit.

## 7. Wiring in the game
```
SoundService
  Music     SoundGroup  0.5   muted when settings.music is false
  Ambience  SoundGroup  0.6   muted when settings.sfx is false
  Sfx       SoundGroup  0.8   muted when settings.sfx is false
  Ui        SoundGroup  0.7   muted when settings.sfx is false
```
`src/client/Audio/init.luau` builds the groups at startup from `Cues.luau` and exposes `play(cueId, at)` (2D when `at` is nil, else parented to that Part or Attachment) plus `setMusic(name)` and `setAmbience(name)`. A cue entry:
```luau
netSwing = {
	ids = {}, -- "rbxassetid://..." strings; empty means silent, never an error
	group = "Sfx",
	volume = 0.8,
	pitch = { 0.96, 1.04 }, -- random PlaybackSpeed per play
	minGap = 0.1, -- seconds; drops spam
	voices = 2, -- pooled Sounds; the oldest restarts when all are busy
	preload = true,
},
```
Rules:
- Subscribe to moments; never fire remotes, change state or read the server from audio code.
- Pool Sounds per cue (`voices`); never create one Sound per coin. Destroy 3D Sounds with their part (streaming can remove parts).
- Music: one bed at a time. On a phase change crossfade over about 2 s (`TweenService` on `Volume`). Stingers duck Music to 40 % for their length, then restore. Music starts only after the first ProfileSync, so a player who muted it never hears a note.
- Ambience follows the player's zone (cafe, alley, park) and the phase; crossfade about 1.5 s on a change.
- The server never plays sounds. In the slice you hear your own actions, world loops near you and the strays; other players' catches are a later moment broadcast.
- Settings: apply `settings.music` and `settings.sfx` on the first ProfileSync and on every toggle by setting group volumes to 0 or back.
- Preload only cues marked `preload` (about ten).
- A missing or failed sound must never break gameplay: wrap loads, log once, stay silent.

## 8. Music rules (Cozy Cream)
Warm and acoustic, no vocals or lyrics, 80 to 105 BPM, soft attacks, nothing that startles. Day is the cafe open and busy, night is a small friendly adventure: curious, never scary (young audience). Two day tracks alternate so a 15 minute session does not repeat one loop five times. Loops are seamless and each phase change has a short stinger. The full brief, instruments and tempos are in the sound list.

## 9. Mixing for phones
- Most players listen on phone speakers: little below 150 Hz survives, so put the information a sound carries (catch, coin, error) between 1 and 4 kHz and keep bass decorative.
- When it gets busy, the order of importance is: catch result, UI feedback, coins, cat voices, ambience, music.
- Keep about 16 or fewer Sounds playing at once on a client; pooling and `minGap` handle most of it.
- Check sound memory in Studio's Developer Console (F9, Memory tab) after a full loop; long uncompressed files are the usual cause.

## 10. Listening and testing
- Studio: press Play and walk the listening list at the end of the sound list. An Output line about a sound that failed to load means a wrong id or a missing permission (section 6).
- Before calling a mix done, one pass on a real phone speaker (a published dev copy or Team Test on the phone).
- QA's playtest report gets an audio line: missing sound, too loud or quiet, repeats too often, heard by the wrong player, still playing after a toggle.

## 11. Handoff note
Per cue: cue id, moment, file, asset id, source and license, gate verdict, where to listen (exact Studio steps). Then open questions for Derek and Gavin.
