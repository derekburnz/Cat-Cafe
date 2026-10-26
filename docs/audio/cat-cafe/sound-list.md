# Purr Pot sound list

Draft v0.1, 2026-10-26. Owner: sound-designer. Built from gdd.md v0.2, features.md, the timings in `src/shared/Config.luau` and style guide section 1. Status: a plan, nothing sourced or uploaded yet. Every row is a cue: one named sound the game plays, with the moment that fires it. How to source, prepare, upload and wire them is in `.claude/skills/audio-pipeline/SKILL.md`.

Priorities follow the slice: **P0** is needed for the Phase 2 exit test to feel like a game (14 cues), **P1** before the friends alpha, **P2** polish.

## 1. How Purr Pot should sound

A quiet afternoon cafe, then a small friendly adventure after dark. By day: soft acoustic music, cups and murmur, the occasional meow from a shelf. At night: the music turns curious and tiptoes, the alley hums and drips, a street lamp buzzes and strays chirp from behind the bins. Every effect is soft and rounded, like the blocky toy shapes: pops, tinks, chimes and patters, never buzzers, crashes or anything that startles a young player. A missed catch says "aww, try again", not "wrong". The cats are the stars in sound too: short, cute, readable meows.

## 2. The mix

Four channels (Roblox calls them SoundGroups): every sound belongs to one, and the two settings toggles the profile already has (`settings.music`, `settings.sfx`) mute whole channels.

| Channel | Holds | Start volume | Muted by |
|---|---|---|---|
| Music | day and night beds, stingers, jingles | 0.5 | music toggle |
| Ambience | room tone and outdoor beds, world loops (fountain, lamp hum) | 0.6 | sfx toggle |
| Sfx | gameplay sounds, cats, coins | 0.8 | sfx toggle |
| Ui | buttons, panels, toasts | 0.7 | sfx toggle |

Stingers and the Legendary fanfare duck the music to 40 % while they play. When it gets busy, the order of importance is: catch result, UI feedback, coins, cat voices, ambience, music.

## 3. Music

The clock is 3 minutes of day and 2 of night (gdd.md, The clock). Music follows the phase on every client at once, because the phase is server-wide.

| Cue | Moment | Length | Feel | Instruments | Tempo, key | P |
|---|---|---|---|---|---|---|
| `musicDayA` "Open for Business" | DayStart (odd days) | 120 s loop | warm, busy, content | felt piano or Rhodes melody, nylon guitar, upright bass, brushed snare, glockenspiel on phrase ends | about 90 BPM, major | P0 |
| `musicDayB` "Second Cup" | DayStart (even days) | 120 s loop | lazy afternoon, bossa feel | nylon guitar lead, clarinet or flute, soft shaker | about 84 BPM, major | P1 |
| `musicNight` "After Hours" | NightStart | 90 s loop | curious, sneaky-cute, never scary | pizzicato strings, muted vibraphone or celesta, walking bass, finger snaps, clarinet | about 96 BPM, minor or dorian but bright | P0 |
| `stingDusk` "Closing Time" | NightStart | 3 s | the sign flips to Closed | descending vibraphone run, small door-sign clack | | P1 |
| `stingDawn` "Fresh Pot" | DayStart | 3 s | the cafe opens | rising glockenspiel, one shop bell | | P1 |
| `jingleCatFound` | CatFound | 2 s | "new friend!" | rising four-note glockenspiel, harp sweep | | P0 |
| `jingleRare` / `jingleEpic` / `jingleLegendary` | CatchSuccess by rarity | 1 / 1.5 / 3 s | rising excitement; Legendary is a small warm fanfare | chimes, then harp, then soft horns | | P1 |
| `jingleLevelUp` | LevelUp | 2 s | proud, bigger cafe | piano and glockenspiel flourish | | P1 |

Phase change: the current bed fades out over about 2 s, the stinger plays, the next bed fades in. Two day tracks alternate so a 15 minute session (three days) never hears one loop five times. No vocals or lyrics anywhere.

Source plan: Roblox's licensed music in the Creator Store first, free in experiences. I bring three candidates per slot for Derek to listen to (searches such as "lofi jazz cafe", "acoustic cozy", "bossa nova", "pizzicato sneaky", "jazz brushes"), chosen by length, loop points and instruments against the table. Licensed tracks can only be used inside Roblox, so trailers, devlog clips and store videos will need our own or separately licensed music later.

## 4. Ambience

2D beds by zone and phase, crossfaded over about 1.5 s when the player walks between zones, plus 3D loops placed on props.

| Cue | Where, when | Feel | P |
|---|---|---|---|
| `ambCafeDay` | inside any cafe, day | soft murmur, cup clinks, a far espresso hiss, very low | P1 |
| `ambCafeNight` | inside, night | quiet room tone, fridge hum, a wall clock | P2 |
| `ambAlleyDay` | alley, day | distant traffic, pigeons, a little wind | P1 |
| `ambAlleyNight` | alley, night | low city hum, light wind, water drips, crickets | P0 |
| `ambParkDay` | park, day | birds, leaves, the fountain from afar | P2 |
| `ambParkNight` | park, night | crickets, soft wind | P2 |
| `loopFountain` | 3D on the park fountain, 30 stud range | gentle splash | P2 |
| `loopStreetLamp` | 3D on each street lamp, night only, 15 studs | faint electric hum | P2 |
| `loopFishTank` | 3D on the fish tank decor, 10 studs | bubbles | P2 |
| `loopEspresso` | 3D on the espresso machine, day, every 20 to 40 s | short steam hiss | P2 |

## 5. Sound effects by mechanic

2D plays flat for you only; 3D plays from a place in the world and fades with distance. Timings below come from `Config.luau` so the sounds line up with what the server decides.

### 5.1 Net catch (hold 1.5 s, good band the last 0.8 s, perfect the last 0.3 s)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `netWindup` | NetWindup | 2D | 1.5 s, stops on release | a rising soft stretch or whoosh that tracks the ring | P0 |
| `netRingGood` | NetRingGood | 2D | 0.05 s | soft wooden tick: you are in the band | P1 |
| `netRingPerfect` | NetRingPerfect | 2D | 0.08 s | brighter tick a fourth higher: release now | P1 |
| `netSwing` | NetSwing | 3D on you | 0.3 s | soft whoosh of the net | P0 |
| `catchSparkle` | CatchSuccess | 2D | 0.6 s | net "fwump" plus a sparkle; rarity jingle layers on top (section 3) | P0 |
| `catchMiss` | CatchFail | 2D | 0.4 s | gentle "whiff" and a soft down-boop; not a buzzer | P0 |
| `strayFlee` | StrayFlee | 3D on the stray | 0.5 s | startled "mrrp!" and quick paw patter | P0 |

The two ticks also help players who struggle to read the ring. They are hints only, like the ring itself: the server scores the timing.

### 5.2 Bait

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `bowlPlace` | BaitPlaced | 3D on the bowl | 0.3 s | ceramic clink on concrete | P1 |
| `foodKibble` / `foodTuna` / `foodSalmon` | BaitPlaced (by lure) | 3D on the bowl | 0.4 to 0.6 s | kibble rattle; can pop and squish; wet plop | P1 |
| `baitArrive` | BaitArrive | 3D on the stray, plus a 2D chime for you | 1 s | calm curious "mrrp?" and a small chime: your stray is here | P1 |
| `baitEat` | stray waiting at the bowl | 3D | 2 s loop | quiet crunching | P2 |
| `baitExpire` | BaitExpire | 2D | 0.6 s | soft two-note fall and a coin clink for the refund | P2 |

### 5.3 Rescue (hold 4 s, cannot fail)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `rescueTree` / `rescueBox` / `rescuePipe` | RescueHold (by prop) | 3D on the spot | 4 s loop | leaf rustle; cardboard shuffling; hollow metal scrabble with a little echo | P1 |
| `rescueRise` | RescueHold | 2D | 4 s | gentle rising tone in step with the hold bar | P1 |
| `rescueCancel` | RescueCancel | 2D | 0.3 s | stops the loops, small soft down-tone | P2 |
| `rescueDone` | RescueDone | 2D | 1 s | warm chime and a grateful purr-meow | P1 |

### 5.4 Carry, check-in and placing

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `carryPurr` | CarryStart until CheckIn | 2D, quiet | 3 s loop | contented purr in your arms | P1 |
| `checkInBell` | CheckIn | 3D on your door | 1 s | shop-door bell | P0 |
| `catPlaced` | CatPlaced | 3D on the spot | 0.4 s | soft cushion thump and a happy "mrrp" | P1 |
| `catSold` | CatSold | 2D | 0.6 s | coin clink and a small goodbye meow | P2 |

### 5.5 Cats in the world

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `meow` (5 variants) | idle strays and placed cats, every 8 to 20 s each, at most two at once | 3D, 40 studs | 0.3 to 0.8 s | short, cute, varied; pitch shifts a little per play | P1 |
| `purr` | cat on its favorite spot, you standing close | 3D, 8 studs | 3 s loop | very quiet purr | P2 |
| `shimmerRare` | RareStrayNearby (an Epic or Legendary stray within about 40 studs) | 3D on the stray | 2 s loop | faint twinkle, so you can find a rare in the dark | P1 |

### 5.6 Coins and progress

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `coinPop` | CoinPop (customer coin float) | 3D on the table | 0.15 s | soft coin tink, small pitch changes, at most one every 0.08 s | P0 |
| `purchase` | Purchase | 2D | 0.5 s | soft register "ka-ching" (UI's `buy` hook) | P0 |
| `offlineClaim` | OfflineClaim | 2D | 1 s | a short shower of coins | P1 |
| `placeFurniture` | Purchase of a table or decor | 3D on the new piece | 0.5 s | wooden thunk and a sparkle | P2 |
| `gateOpen` | AreaUnlock | 3D on the park gate, plus `jingleLevelUp` | 1.5 s | iron gate creak, friendly | P2 |
| `announce` | Announce (anyone catches an Epic or Legendary) | 2D | 1 s | two-note chime under the banner | P1 |

### 5.7 Clock

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `signFlip` | NightStart, DayStart | 3D on your door sign | 0.4 s | wooden sign clack | P1 |
| `lampOn` | NightStart | 3D on each street lamp | 0.5 s | click and hum start | P2 |

### 5.8 UI

| Cue | When | Length | What it sounds like | P |
|---|---|---|---|---|
| `uiClick` | any button press (UI's `click` hook) | 0.05 s | soft pop | P0 |
| `uiError` | Toast of kind warn, can't afford, not allowed (UI's `error` hook) | 0.2 s | gentle low "bonk", never a buzzer | P0 |
| `uiOpen` / `uiClose` | panel or modal opens or closes | 0.15 s | soft paper swish up and down | P1 |
| `uiToast` | Toast of kind info or good | 0.2 s | small pop; good adds a chime | P1 |
| `uiHint` | a new tutorial prompt | 0.3 s | soft ding | P1 |
| `uiTab` | tab or filter chip | 0.05 s | tick | P2 |
| `uiToggle` | settings toggle | 0.1 s | click | P2 |

The UI's `catFound` hook plays `jingleCatFound`.

P0 set (14): `musicDayA`, `musicNight`, `jingleCatFound`, `ambAlleyNight`, `netWindup`, `netSwing`, `catchSparkle`, `catchMiss`, `strayFlee`, `checkInBell`, `coinPop`, `purchase`, `uiClick` and `uiError`. The music beds and the UI pair are the first to source.

## 6. Hooks the code needs

Proposed with the animation and VFX thread: the engineer adds `src/client/Moments.luau`, one signal per moment fired from the controllers, and both Audio and Effects only listen. The names are shared so a catch sounds and sparkles on the same frame. Where each moment comes from in today's code:

| Moment | Fired when | Source today |
|---|---|---|
| NetWindup | the grab hold starts | UIController hold start, before `GrabBegin` |
| NetRingGood, NetRingPerfect | the hold passes `GrabHoldSeconds - RingGoodWindow` and `- RingPerfectWindow` | client timer, the same one that draws the ring |
| NetSwing | the hold is released | UIController, when `GrabEnd` is sent |
| CatchSuccess | `GrabResult` ok for a stray id | remote; rarity from the stray's `Rarity` attribute |
| CatchFail | `GrabResult` not ok with retry | remote |
| StrayFlee | `GrabResult` not ok without retry ("It got away") | remote; position from the stray model before it leaves |
| BaitPlaced | `UseLure` accepted | ProfileSync lure count drops; lure id for the food sound |
| BaitArrive | a stray appears with `ReservedFor` equal to your UserId | stray model attributes |
| BaitExpire | that stray is removed without a catch | stray model removed |
| RescueHold, RescueCancel | rescue hold starts, or ends early | UIController, around `RescueBegin` |
| RescueDone | `GrabResult` ok for a rescue spot id | remote; prop type from the rescue spot |
| CarryStart | any successful catch or rescue | `GrabResult` ok |
| CheckIn, CatFound | `CatCaught` arrives (CatFound when `isNew`) | remote, fired at check-in |
| CatPlaced, CatSold | the matching intent is accepted | ProfileSync diff |
| CoinPop | a customer drops coins | CustomerController coin float text |
| Purchase, LevelUp, AreaUnlock | a new upgrade, decor or lure in ProfileSync; `cafe_level` rises; `park_access` bought | ProfileSync diff; WorldController already tracks the gate |
| NightStart, DayStart | `ReplicatedStorage.Clock` attribute `Phase` changes | attribute, as WorldController reads it |
| RareStrayNearby | an Epic or Legendary stray within about 40 studs | client distance check on stray models |
| OfflineClaim, Announce | `ClaimOffline` pressed; `Announce` arrives | intent; remote |

For the UI: today `Theme.sounds` holds four optional asset ids. Proposal to the ui-designer: replace the ids with one injected `playSound(cueId)` function, so asset ids live only in `src/client/Audio/Cues.luau` and the UI keeps no ids of its own.

## 7. Sources plan

| Group | First choice | Fallback |
|---|---|---|
| Music beds, stingers, jingles | Creator Store licensed music (three candidates per slot) | commission or compose later; needed anyway for videos |
| UI, ticks, coin tinks | synthesized by us (sfxr-style tool), fully original | Kenney UI Audio and Interface Sounds packs (CC0) |
| Meows, purrs | recorded from a real cat (see question 1) | Creator Store cat sounds |
| Whooshes, bell, rustle, cardboard, metal, gate, splashes | Creator Store sound effects | Freesound CC0 |
| Ambience beds | Creator Store ambience | Freesound CC0 field recordings |

Upload estimate for the slice: under 40 own files (mostly synthesized UI and recorded cats), well inside even the 100 per 30 days of an unverified account. Creator Store sounds need no upload.

## 8. Listening list for Derek (once the P0 cues are in)

In Studio, Play in the dev copy:
1. Spawn: the day music starts after a moment, at a level you could talk over. Click three buttons: the click is soft, not sharp.
2. Buy Table 1: register sound once. Try to buy something you cannot afford: a gentle bonk.
3. Walk out the back door: the alley sounds take over.
4. Hold on a stray: the wind-up rises with the ring, the swing whooshes, then either the catch sparkle or the soft miss. Let a Rare get away: it chirps and patters off.
5. Walk home: the door bell, then the new-cat jingle with the music dipping under it.
6. Wait for night: the music fades, the dusk stinger plays, the night track starts, the alley gets its night bed.
7. Turn the music toggle off and on, then the sfx toggle: everything in that channel stops and comes back.
8. Once on a phone speaker: the catch, coins and clicks are still clear.

## 9. Open questions for Derek and Gavin

1. Does anyone have a cat we can record? Real meows and purrs from our own cats are original, free and the best way to make the cats feel alive. A phone in a quiet room is enough.
2. Which account uploads audio: Derek's, or a Roblox Group that will own the game? Uploaded audio is private to its owner, so this decides the permissions work.
3. Is Derek's Roblox account ID-verified? It raises the audio upload quota from 100 to 2,000 per 30 days; not urgent for the slice.
4. Music: OK to use Creator Store licensed tracks for the slice (free, Roblox-only), and decide on original music later for trailers?
5. Gavin: should the night feel like an adventure (music stays on, curious) or quieter (music drops away outside, only the alley sounds)? I drafted the first.
6. Should you hear other players' net swings and catches nearby in the slice, or is the server-wide announcement chime enough? The slice plan is the chime only.

Proposed for docs/decisions.md: music follows the server clock phase (day beds alternate, one night bed, stingers between), Creator Store licensed music for the slice and never in off-platform videos.
