# Cat Cafe sound list

Draft v0.5, 2026-10-27 (v0.1 and v0.2 on 2026-10-26, v0.3 for design v0.4, v0.4 for design v0.5, v0.5 for the features built on 2026-10-27). Owner: sound-designer. Built from gdd.md v0.5, data-model.md v0.5 (sections 2, 8 to 13, 15 and 17), features.md v0.5 (sections 2b and 2c), world-and-feel.md and style guide section 1. Status: 60 files synthesized and gated. The first 44: 37 effects and jingles (every UI sound in 5.8, the whole net catch with the hiss, the v0.5 sprint away and the Purrfect chime, the shove and its held-tight squeeze, coins, purchase, the door bell, the stray flee, both purrs, the gate, the shutters and sign, the shout-out chime, the cat found and rank up jingles; `assets/cat-cafe/audio/synth/synth.py`), 6 ambience beds (cafe, Alleyway and Park, day and night; the night cafe rebuilt as the closed cafe for v0.5) and the cafe door loop (`synth/ambience.py`). The code that plays them is in `games/cat-cafe/src/client/Audio/`; the engineer wired start, settings, carrying and zones (PR #66) and the moments (`src/client/Moments.luau`, PR #91). Those 44 are on Roblox, uploaded by Derek with `assets/cat-cafe/audio/upload.py` (31 on 2026-10-26, 13 more on 2026-10-27); the ids are in `Cues.luau` and the sources log. The 16 for the 2026-10-27 features (below) wait for his next upload run and stay silent until then. Waiting for Derek's ear; music is still a plan. Every row is a cue: one named sound the game plays, with the moment that fires it. How to source, prepare, upload and wire them is in `.claude/skills/audio-pipeline/SKILL.md`.

Priorities follow the slice: **P0** is needed for the Phase 2 exit test to feel like a game (20 cues), **P1** before the friends alpha, **P2** polish.

What v0.3 changed here: the hold-and-release ring became 1 to 5 closing circles with a grade per press, the rescue hold became a timing bar (a tree shake in the Park), bait moved to your own bowl with a 10 minute wait and Tame or Let go, other players can bump a carried cat loose, shiny cats exist, tiers replace cafe levels and nights last 5 minutes with the cafe still open, a food dealer and rich customers by day.

What v0.4 changed here (world-and-feel.md): the first Miss ends a catch, so a Miss now hisses and the cat jumps back, and the paw you lose pops; an all-Perfect Purrfect catch chimes. The flee roll is gone. Cafes should feel busy from the street, so each cafe front door plays chatter and cups 3D, and cats working near you purr. Empty plots are For Rent shops whose shutters roll up when a player joins; gates dissolve their barrier; server shout-outs chime higher for rarer cats.

What v0.5 changed here (Gavin's round 2, features.md 2c): a Miss still hisses, then the cat sprints 12 to 32 studs away and anyone can chase it and try again, so the paw pop is retired and a paw patter runs off with the cat. Bump becomes Shove: any player can shove another inside a catching area, so every shove gets a playful whoosh and boop, and a shoved carrier still drops the cat (or holds on) with its own sound. The cafe closes at night: the night bed inside is cats asleep, not customers, and the door chatter stops at nightfall and on For Rent shops.

What the 2026-10-27 features changed here (features.md F42 and F45 to F48, Derek's UI round): holding E to catch fills with a rising whirr that pops on the trigger, and each circle pips as it appears; Drop sets the cat down with a mrrp and soft paws; walking between the safe street and a catching area plays a calm or a playful chime with the Safe zone chip; fast travel and My Cafe poof; a cat starting or leaving a role (Staff tab, Unequip All) hops in or sighs off; Tip Jar gifts and Index rewards get a ready chime, a claim and a red dot blip; the volume sliders tick; gold replaces shiny (a gold reveal and a twinkle on gold strays); a resting cafe cat purrs (sitting, or lying in a loaf); and the Spin Wheel window (F49) winds up, ticks past each slice and lands on a fanfare.

## 1. How Cat Cafe should sound

A quiet afternoon cafe, then a small friendly adventure after dark. By day: soft acoustic music, cups and murmur, the occasional meow from a station. At night: the music turns curious and tiptoes, the alley hums and drips, a street lamp buzzes, strays chirp from behind the bins and a mysterious cart jingles on the street, while the cafe keeps a few night owls. Every effect is soft and rounded, like the blocky toy shapes: pops, tinks, chimes and patters, never buzzers, crashes or anything that startles a young player. A missed circle says "aww, try again", not "wrong". The cats are the stars in sound too: short, cute, readable meows.

## 2. The mix

Four channels (Roblox calls them SoundGroups): every sound belongs to one, and the two settings toggles the profile already has (`settings.music`, `settings.sfx`) mute whole channels. Two volume sliders (`settings.musicVolume`, `settings.sfxVolume`, 0 to 1, Derek 2026-10-27) scale them: the channel volume is its start volume times the slider squared, so half way sounds about half as loud. A toggle that is off wins, and a slider at 0 counts as off, so nothing loads.

| Channel | Holds | Start volume | Muted by | Scaled by |
|---|---|---|---|---|
| Music | day and night beds, stingers, jingles | 0.5 | music toggle | music slider |
| Ambience | room tone and outdoor beds, world loops (fountain, lamp hum, dealer cart) | 0.6 | sfx toggle | sound slider |
| Sfx | gameplay sounds, cats, coins | 0.8 | sfx toggle | sound slider |
| Ui | buttons, panels, toasts | 0.7 | sfx toggle | sound slider |

Stingers, the rank up jingle, the gold reveal, the Index reward, the wheel win and the Legendary and Mythical fanfares duck the music to 40 % while they play. During a catch the music ducks to 60 % and the ambience to 50 % so the circles are easy to hear. When it gets busy, the order of importance is: circle grades and the catch result, UI feedback, coins, cat voices, ambience, music.

## 3. Music

The clock is 5 minutes of day and 5 of night (data-model section 9). Music follows the phase on every client at once, because the phase is server-wide. Each phase has two beds that play one after the other, so a 5 minute phase hears each about once and a 15 minute session never hears one loop four times in a row.

| Cue | Moment | Length | Feel | Instruments | Tempo, key | P |
|---|---|---|---|---|---|---|
| `musicDayA` "Open for Business" | DayStart, first half | 150 s loop | warm, busy, content | felt piano or Rhodes melody, nylon guitar, upright bass, brushed snare, glockenspiel on phrase ends | about 90 BPM, major | P0 |
| `musicDayB` "Second Cup" | after `musicDayA` | 150 s loop | lazy afternoon, bossa feel | nylon guitar lead, clarinet or flute, soft shaker | about 84 BPM, major | P1 |
| `musicNightA` "After Hours" | NightStart, first half | 150 s loop | curious, sneaky-cute, never scary | pizzicato strings, muted vibraphone or celesta, walking bass, finger snaps, clarinet | about 96 BPM, minor or dorian but bright | P0 |
| `musicNightB` "Night Owls" | after `musicNightA` | 150 s loop | late and cozy, a little dreamy | soft Rhodes, brushed kit, muted trumpet or alto flute, music box sparkles | about 80 BPM, major seventh chords | P1 |
| `stingDusk` "Night Shift" | NightStart | 3 s | the lamps come on, the sign turns to the moon | descending vibraphone run, a soft lamp click | | P1 |
| `stingDawn` "Fresh Pot" | DayStart | 3 s | morning, the sun sign | rising glockenspiel, one shop bell | | P1 |
| `jingleCatFound` | CatFound | 2 s | "new friend!" | rising four-note glockenspiel, harp sweep | | P0 |
| `jingleRare` / `jingleEpic` / `jingleLegendary` / `jingleMythical` | CatchSuccess, RescueDone or BaitTame by rarity | 1 / 1.5 / 3 / 4 s | rising excitement; Legendary is a small warm fanfare, Mythical adds a choir-like pad (no words) | chimes, then harp, then soft horns, then the pad | | P1 |
| `jingleRankUp` | RankUp | 3 s | proud, the cafe grows; tier 5 gets a longer ending | piano and glockenspiel flourish, soft horns | | P0 |

Phase change: the current bed fades out over about 2 s, the stinger plays, the next phase's A bed fades in. No vocals or lyrics anywhere.

Source plan: Roblox's licensed music in the Creator Store first, free in experiences. I bring three candidates per slot for Derek to listen to (searches such as "lofi jazz cafe", "acoustic cozy", "bossa nova", "pizzicato sneaky", "jazz brushes", "night lounge"), chosen by length, loop points and instruments against the table. Licensed tracks can only be used inside Roblox, so trailers, devlog clips and store videos will need our own or separately licensed music later.

## 4. Ambience

2D beds by zone and phase, crossfaded over about 1.5 s when the player walks between zones, plus 3D loops placed on props. The three later areas are friendly too: the Sewer drips and echoes, it does not growl.

| Cue | Where, when | Feel | P |
|---|---|---|---|
| `ambCafeDay` | inside any cafe, day | soft murmur, cup clinks, a far espresso hiss, very low | P1 |
| `ambCafeNight` | inside, night (v0.5: the cafe is closed) | no customers: a wall clock, the fridge, cats purring in their sleep with a dreaming chirp now and then, one muffled car outside; played lower than the day bed | P1 |
| `ambAlleyDay` | Alleyway, day | distant traffic, pigeons, a little wind | P1 |
| `ambAlleyNight` | Alleyway, night | low city hum, light wind, water drips, crickets | P0 |
| `ambParkDay` | Park, day | birds, leaves, the fountain from afar | P1 |
| `ambParkNight` | Park, night | crickets, soft wind, an owl far away | P1 |
| `ambNeighbourhood`, `ambWoods`, `ambSewer` | the later areas, day and night variants | garden birds and a lawnmower far off; leaves and a stream; gentle drips and a hollow echo | P2 |
| `loopCafeDoor` | 3D on every cafe front door (tag `CafeDoor`), 30 studs, only while the cafe is open: an owned plot, by day (v0.5) | chatter, cup clinks and a far espresso hiss spilling out, so a street of cafes sounds busy before you walk in; quiet on For Rent shops and at night | P1 |
| `loopFountain` | 3D on the park fountain (tag `Fountain`), 30 stud range | gentle splash | P2 |
| `loopStreetLamp` | 3D on each street lamp, night only, 15 studs | faint electric hum | P2 |
| `loopDealerCart` | 3D on the dealer cart while it is out, 25 studs | a slow music box and a lantern creak: mysterious but friendly | P1 |
| `loopFishTank` | 3D on the fish tank decor (tag `FishTank`), 10 studs | bubbles | P2 |
| `loopEspresso` | 3D on the espresso machine, every 20 to 40 s | short steam hiss | P2 |

## 5. Sound effects by mechanic

2D plays flat for you only; 3D plays from a place in the world and fades with distance. Every press plays on the client the instant it happens, never after a round trip to the server.

### 5.1 Net: closing circles (data-model section 10)

1 to 5 circles by rarity (Common 1 up to Mythical 5), each shrinking for 0.65 to 1.4 s onto its ring, Perfect and Good windows from the net level, then one roll on the average score.

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `holdFill` | holding E on a stray's or stuck cat's prompt (F45, HoldDuration 0.5; a manhole's 0.3), from ProximityPromptService, no moment | 2D | 0.5 s plus the pop | a soft whirr rising an octave with the fill, landing on a small pop and tink as the hold triggers; stretched to the prompt's hold so the pop meets the trigger; fades out in 0.06 s if the key is let go; silent while the cat is still running | P1 |
| `catchStart` | CatchStart | 2D | 0.4 s | the net lifts with a soft whoosh-up, ready | P1 |
| `circleAppear` | CircleAppear (each circle "pops up"; the engineer fires it at each circle's start) | 2D | 0.1 s | soft pip as each circle appears; later circles pip a little higher | P1 |
| `circleClose` | CircleAppear, lasting the shrink | 2D, quiet | 0.65 to 1.4 s | gentle rising sweep stretched to the shrink time, so you can hit the ring by ear | P2 |
| `netSwing` | NetSwing (every press) | 3D on you | 0.25 s | soft whoosh of the net | P0 |
| `circlePerfect` | CircleGrade Perfect | 2D | 0.3 s | bright bell; each Perfect in a row is one step up a five-note scale, so a run of Perfects plays a little tune | P0 |
| `circleGood` | CircleGrade Good | 2D | 0.25 s | softer wooden chime at the same pitch step | P0 |
| `circleMiss` | CircleGrade Miss (a bad press, or a circle that closed unpressed) | 2D | 0.2 s | muted "thup", never harsh | P0 |
| `catchSparkle` | CatchSuccess | 2D | 0.6 s | net "fwump" plus a sparkle; the rarity jingle layers on top (section 3) | P0 |
| `catchMiss` | CatchFail (v0.4: the first Miss ends the catch) | 2D | 0.4 s | gentle "whiff" and a soft down-boop | P0 |
| `catHiss` | the stray's `HissAt` attribute changes (set by the server on a Miss, so everyone nearby hears it; once per cat per second) | 3D at the stray | 0.6 s | a short, soft cartoon hiss, more "pfft" than angry | P0 |
| `straySprint` | the stray's `FleeingUntil` attribute is set (v0.5, F40: the server sets it on a Miss; once per cat per second) | 3D on the stray, so it runs off with the cat | 1 s | a scrabble of claws, then soft paws galloping away, fainter each stride | P0 |
| `pawLost` | nothing since v0.5: F40 removed the paw row and the PawLost moment (PR #130); the file stays uploaded | 2D | 0.3 s | small pop and a falling two-note boop | - |
| `purrfectChime` | Purrfect (every circle Perfect) | 2D | 1 s | gold sparkle run into a bright bell, under the Purrfect burst | P0 |
| `strayFlee` | StrayFlee, a stray that leaves (none in v0.5 yet); the same file plays `bumpLoose` | 3D on the stray | 0.5 s | startled "mrrp!" and quick paw patter | P2 |

The scale for the Perfect run is the major pentatonic, PlaybackSpeed 1, 1.125, 1.25, 1.5 and 1.667 for circles 1 to 5, so one sample covers all five. The grade sounds follow the same client estimate the UI shows when you press. The server's grades in `CatchResult` are the ones that count; if one differs, the UI corrects the circle and no extra sound plays.

### 5.2 Rescue minigames (data-model section 10b)

Traps: Alleyway trash bin and garbage bag, Park tree and trashcan. The bar kind needs 2 to 6 hits by rarity with 3 paws for misses; the tree shakes, the cat drops and one catch circle must be Good or better.

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `rescueStart` | RescueStart | 2D | 0.4 s | a curious "mew?" from inside the trap and a small ready chime | P1 |
| `rescueHitBin` / `rescueHitBag` / `rescueHitTree` / `rescueHitCan` | RescueHit by trap type | 3D on the trap | 0.3 s | metal lid rattle; plastic bag rustle; leaves shaking (the branch shake); park can clang, soft | P1 |
| `rescueHitTone` | RescueHit | 2D | 0.15 s | rising pip per hit, so you hear how close you are | P1 |
| `rescueMiss` | RescueMiss | 2D | 0.25 s | soft boing and a small paw-print tick as a paw is used | P1 |
| `rescueDrop` | RescueDrop (tree cat falls) | 3D on the tree | 0.5 s | leaf whoosh and a surprised "mew!"; the catch circle sounds follow | P1 |
| `rescueFail` | RescueFail, RescueCancel | 2D | 0.4 s | small "aww" down-tone; the cat is still stuck, nothing is lost | P1 |
| `rescueDone` | RescueDone | 2D | 1 s | warm chime and a grateful purr-meow | P1 |

### 5.3 Carry, shoves and check-in (data-model section 10c; v0.5 Shove keeps the Bump names in code)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `carryPurr` | CarryStart until CheckIn or BumpLoose | 2D, quiet | 3 s loop | contented purr in your arms | P1 |
| `shove` | Shove, every shove that lands (v0.5, F41) | 3D at the shoved player | 0.4 s | a quick whoosh into a soft, bouncy "boop": a playful push, never a hit | P1 |
| `bumpLoose` | BumpLoose, after Shove when the carrier's cat drops | 3D at the carrier | 0.55 s | the StrayFlee file: a startled "mrrp!" and paws scampering off; the toast plays its own bonk | P1 |
| `bumpHeld` | BumpHeld ("It held on tight!") | 3D at the carrier | 0.6 s | a rubbery double squeeze and a light mint shimmer, with the effects' squeeze wobble and ring | P1 |
| `checkInBell` | CheckIn | 3D on your door | 1 s | shop-door bell | P0 |
| `catDrop` | CatDrop (F45: the Drop button or G while carrying) | 3D at your feet | 0.6 s | a small "mrrp", two soft paws landing and a little shake | P1 |
| `catPlaced` | CatPlaced (a cat starts a role: Staff tab, Equip Best) | 2D, one per sync | 0.6 s | soft hop thump, a happy "mrrp" and three sparkles | P1 |
| `catRest` | UnplaceCat (a cat leaves its role; Unequip All plays it once) | 2D | 0.65 s | a sleepy sigh, a small falling "mew" and a soft flop | P1 |
| `catSold` | CatSold | 2D | 0.6 s | coin clink and a small goodbye meow | P2 |

### 5.4 Bait bowl (data-model section 8)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `foodKibble` / `foodTuna` / `foodSalmon` | BaitPlaced (by food) | 3D on your bowl | 0.4 to 0.6 s | kibble rattle into the bowl; can pop and squish; wet plop | P1 |
| `foodDealer` | BaitPlaced with a dealer food | 3D on your bowl | 0.6 s | the plop plus a faint twinkle (Moonlit Sardines up to Star Treat) | P2 |
| `baitArrive` | BaitArrive (your bait cat is at the bowl) | 3D on the bowl, plus a 2D chime | 1 s | crunching stops, a curious "mrrp?" and a small chime | P1 |
| `baitTame` | BaitTame | 2D | 1 s | happy purr and a warm two-note chime; the rarity jingle layers on top | P1 |
| `baitLetGo` | BaitLetGo | 2D | 0.6 s | friendly "mew" and soft paw steps walking away | P1 |

### 5.5 Cats in the world

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `meow` (5 variants) | idle strays and working cats, every 8 to 20 s each, at most two at once | 3D, 40 studs | 0.3 to 0.8 s | short, cute, varied; pitch shifts a little per play | P1 |
| `purr` | a working cat (tag `WorkingCat`), only the 3 nearest within 14 studs, never a cat the player hid (`HiddenLocal`, Show other cats off); and by day the nearest resting cafe cat within 14 studs, sitting (`Pose` "sit", PR #266) or lying in a loaf (`Effects.isLoafing`, VFX PR #222; one only, so it is always a cat Effects animates, reviewer N131, N150) | 3D, 8 studs | 3 s loop | very quiet purr, so a busy cafe sounds cosy up close | P1 |
| `shimmerRare` | a gold stray, or Epic and up (the `Stray` world loop: `Gold` or `Rarity` on the model, the 3 nearest within 40 studs; replaces RareStrayNearby) | 3D on the stray | 2 s loop | faint gold twinkles over a whisper of air, so you can find it in the dark | P1 |
| `goldReveal` | a gold cat comes into your arms (a `HeldCat` under your character with `Gold`, or `Gold` turning on), and GoldReveal for a bait cat (F42; was shinyReveal) | 2D | 1.8 s | a shimmer climbing into a rich gold bell chord, sparkles settling round it; ducks the music | P1 |

### 5.6 Coins, tiers and the night economy

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `coinPop` | CoinPop (customer coin float) | 3D on the table | 0.15 s | soft coin tink, small pitch changes, at most one every 0.08 s | P0 |
| `purchase` | Purchase (shop, decor, food, dealer) | 2D | 0.5 s | soft register "ka-ching" (the UI's `buy` hook) | P0 |
| `offlineClaim` | OfflineClaim | 2D | 1 s | a short shower of coins | P1 |
| `placeFurniture` | Purchase of a table or decor | 3D on the new piece | 0.5 s | wooden thunk and a sparkle | P2 |
| `gateOpen` | AreaUnlock (the next area's gate after a rank up) | 3D on the gate | 1.5 s | v0.4: the see-through barrier dissolves, a soft shimmer and a rising sparkle | P1 |
| `shuttersUp` | PlotOpened (a For Rent plot becomes a player's cafe) | 3D on the shop front | 1.5 s | shutters rattling up, with `signFlip` as the sign turns to OPEN | P1 |
| `richArrive` | RichArrive (a rich customer at your cafe) | 3D on your tip pile, plus a 2D chime | 1 s | posh little two-note "ding-ding" and a coin pile settling | P1 |
| `richTip` | RichTipClaim (claimed or auto-collected) | 2D | 1.2 s | big coin cascade | P1 |
| `dealerArrive` | DealerArrive | 3D on the cart | 1.5 s | cart wheels rolling in and a lantern bell | P1 |
| `dealerLeave` | DealerLeave | 3D on the cart | 1.5 s | wheels rolling away | P2 |
| `announce` | Announce, the server shout-out (Epic and up, every gold cat, rank ups to Tier 3 and up) | 2D | 1 s | two-note chime under the banner, one note higher per rarity step | P1 |

### 5.7 Clock

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `signFlip` | NightStart, DayStart, PlotOpened | 3D on your door sign | 0.4 s | wooden sign turning between sun and moon, or to OPEN | P1 |
| `lampOn` | NightStart | 3D on each street lamp | 0.5 s | click and hum start | P2 |

### 5.8 UI

| Cue | When | Length | What it sounds like | P |
|---|---|---|---|---|
| `uiClick` | any button press (the UI's `click` hook) | 0.05 s | soft pop | P0 |
| `uiError` | Toast of kind warn, can't afford, not allowed, "You got shoved!" (the UI's `error` hook) | 0.2 s | gentle low "bonk", never a buzzer | P0 |
| `uiOpen` / `uiClose` | panel or modal opens or closes | 0.15 s | soft paper swish up and down | P1 |
| `uiDealerOpen` | the dealer screen opens | 0.4 s | music-box run, a little mysterious | P2 |
| `uiRankReady` | the rank up card shows every requirement met | 0.5 s | bright rising chime, once per tier | P1 |
| `uiToast` | Toast of kind info or good | 0.2 s | small pop; good adds a chime | P1 |
| `uiHint` | a new tutorial prompt | 0.3 s | soft ding | P1 |
| `uiTab` | tab or filter chip | 0.05 s | tick | P2 |
| `uiToggle` | a Settings ON/OFF switch | 0.1 s | click | P2 |
| `uiSlider` | each 5 % step of a volume slider while dragged | 0.04 s | tiny soft tick; it plays through the sound channel, so it previews the new volume | P2 |
| `uiGiftReady` | a Tip Jar gift becomes ready (the ready count goes up, never on the first state) | 0.6 s | glass jar ting and a small two-note chime | P1 |
| `uiBadge` | a red dot turns on (not the ones the first state lights) | 0.1 s | tiny bubble blip | P2 |
| `uiRename` | a cat's new name is saved | 0.3 s | pencil scribble and a ding | P2 |

The UI's `catFound` hook plays `jingleCatFound`.

### 5.9 Zones and travel

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `zoneArea` | Audio.setZone from the safe street (nil or "Cafe") into a catching area, with the Safe zone chip | 2D | 0.5 s | an alert little pluck up a fifth with a paw tap: playful, shoves are on, never a warning | P1 |
| `zoneSafe` | Audio.setZone from a catching area back to the street (the chip's "Safe zone"; the UI's toast is quiet) | 2D | 0.75 s | two felt notes falling to a soft chord, a calm settle | P1 |
| `travelPoof` | Travel (fast travel, My Cafe, a manhole, once the server says the trip worked) | 2D | 0.95 s | a whoosh up, a soft poof where you land and a few sparkles | P1 |

Zone chimes play one per 4 s, so walking along an area's open edge plays one, and none for 2 s after a trip.

### 5.10 Rewards and the spin wheel

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `giftClaim` | TipJarClaim (F47, a gift newly claimed in TipJarState) | 2D | 1 s | a ribbon tug and paper pop, coins tumbling into the jar, a two-note chime | P1 |
| `indexReward` | IndexReward (F48, a milestone newly claimed) | 2D | 1.5 s | a page turns, a stamp lands, a bright run rises to a sparkle; ducks the music | P1 |
| `uiSpinStart` | the Spin Wheel window (F49) starts turning (the UI's playSound) | 2D | 0.6 s | a wooden ratchet winding up into a whoosh | P1 |
| `uiSpinTick` | each slice passing the pointer (the UI; it can fire every frame early in the 4 s spin, so a 0.04 s gap and 2 voices) | 2D | 0.05 s | a wooden peg click, so the ticks slow down with the wheel | P1 |
| `uiSpinWin` | the wheel lands on a prize (the UI) | 2D | 1.4 s | a quick run up into a bright chord with coins on top; ducks the music | P1 |

The spinner hears the window's own cues; Audio binds no wheel moment, so nothing doubles. Other players near the world wheel (VFX PR #226, which turns on `LastSpinAt`) hear nothing yet; a bystander tick could follow that attribute later.

P0 set (20): `musicDayA`, `musicNightA`, `jingleCatFound`, `jingleRankUp`, `ambAlleyNight`, `netSwing`, `circlePerfect`, `circleGood`, `circleMiss`, `catchSparkle`, `catchMiss`, `catHiss`, `straySprint`, `purrfectChime`, `checkInBell`, `coinPop`, `purchase`, `uiClick` and `uiError`. The three circle grades come first: the net is the riskiest feel (features.md build order), and sound is half of a timing game's feel. The upload order in `upload.py` follows this list, so a small monthly allowance covers the whole catch first.

## 6. Moments and hooks

The engineer adds `src/client/Moments.luau`, one signal per moment fired from the controllers; Audio and the vfx-animator's Effects only listen, so a Perfect sounds and sparkles on the same frame. The names are shared with `docs/vfx/cat-cafe/effects-list.md`. v0.3 removed NetWindup, NetRingGood, NetRingPerfect, RescueHold, BaitExpire and LevelUp. v0.4 removes StrayFlee and adds PawLost, Purrfect and PlotOpened. v0.5 retires PawLost (F40) and adds Shove (F41); the sprint after a miss follows the stray's `FleeingUntil` attribute like the hiss, so it needs no moment. The 2026-10-27 features add CatDrop, Travel, UnplaceCat, TipJarClaim, IndexReward and the wheel's WheelSpin, WheelTick and WheelWin for Effects (engineer PR #224 and the Index and wheel PRs), fire CircleAppear and CatPlaced for the first time, rename ShinyReveal to GoldReveal and drop RareStrayNearby (the Stray world loop does it). The hold fill needs no moment either: Audio follows ProximityPromptService's hold events.

| Moment | Args | Fired when | Source (data-model v0.3) |
|---|---|---|---|
| CatchStart | strayId, count | the schedule arrives | `CatchSchedule` |
| CircleAppear | index, shrinkSeconds | a circle starts closing | client timer from `circles[i].startsAt`, cancelled by `CatchResult` (PR #224) |
| NetSwing | index | the player presses | UIController, as `CatchPress` is sent |
| CircleGrade | index, grade (Perfect, Good, Miss) | the press is judged by the client's estimate, or a circle closes unpressed | client, same rule the UI draws |
| CatchSuccess, CatchFail | strayId, rarity | every circle Good or better; the first Miss (the hiss follows `HissAt` on the stray instead) | `CatchResult` v0.4 |
| PawLost | pawsLeft | v0.4 only: a failed catch costs a paw; F40 removes it | `CatchResult` `pawsLeft` |
| Purrfect | charmGain | every circle Perfect | `CatchResult` `charmGain` with all grades Perfect |
| RescueStart | rescueSpotId, kind, trapType | the challenge arrives | `RescueChallenge`; `TrapType` attribute |
| RescueHit, RescueMiss | hits, needed, pawsLeft, trapType | a press is judged | `RescueResult` (UI may predict like the circles) |
| RescueDrop | rescueSpotId | the tree cat falls before its circle | `shake_catch` after the last bar hit |
| RescueDone, RescueFail, RescueCancel | rescueSpotId, rarity | freed; out of paws or tree catch missed; the player cancels | `RescueResult` done; `RescueCancel` sent |
| CarryStart | catId, rarity | any successful catch or rescue | `CatchResult` or `RescueResult` success |
| CatDrop | position (your feet) | F45: the Drop button or G while carrying, on the press | UIController `dropCat` (PR #224) |
| Shove | role (shover, target, bystander), position (the target) | v0.5: a shove lands, on every nearby player's device (3D, so bystanders hear it from where it happened) | `ShoveResult` (engineer PR #139) |
| BumpLoose, BumpHeld | role (shover, target, bystander), position | after Shove, when the target was carrying: the cat drops, or it held on | the same `ShoveResult`; a stray with `Dropped` appears too |
| CheckIn; CatFound | none; catId, isNew | the carried cat goes into the cafe; it is checked in (the jingle plays only when `isNew` is not false) | ProfileSync `carrying` clears; `CatCaught` |
| BaitPlaced | lureId | food goes in the bowl | `UseLure` accepted (`BaitReadyAt` set on the plot) |
| BaitArrive | catView | the bait cat is ready and you are in the server | `BaitReady` |
| BaitTame, BaitLetGo | rarity, gold | the player chooses | `ResolveBait` accepted |
| GoldReveal | method | a bait cat turns out gold (a gold cat in your arms needs no moment: Audio watches the `HeldCat`) | `BaitReady` with gold |
| CatPlaced, CatSold | uid, role | the intent is accepted; CatPlaced also when a cat moves to another role | ProfileSync diff (CatPlaced in PR #224) |
| UnplaceCat | uid | a cat leaves its role, one per cat on Unequip All (Audio plays one sound) | ProfileSync diff (PR #224) |
| Travel | destination ("home", an area id) | a trip worked: fast travel, My Cafe, a manhole | `TravelResult` ok (PR #224) |
| TipJarClaim | step | F47: a gift newly claimed | `TipJarState` diff (PR #224) |
| IndexReward | areaId, milestoneId | F48: a milestone newly claimed | `indexRewards` diff (PR #211) |
| WheelSpin, WheelTick, WheelWin | none; index; prizeKind ("coins" or "lure") | the Spin Wheel: it starts, a slice passes the pointer, it stops on a prize; Audio binds none (the window plays `uiSpinStart`, `uiSpinTick` and `uiSpinWin` itself) | the Spin window wiring (engineer, later) |
| CoinPop | position | a customer drops coins | CustomerController coin float text |
| Purchase, RankUp | id, tier | a new upgrade, decor or food in ProfileSync; `tier` rises | ProfileSync diff |
| AreaUnlock | areaId, position (the gate) | a gate's barrier dissolves for you | ProfileSync diff and the gate part |
| PlotOpened | position (the shop front) | a For Rent plot becomes a player's cafe, for everyone in the server | plot owner attribute changes from none |
| RichArrive, RichTipClaim | amount | `RichTipAmount` is set on your plot; it clears | plot attributes |
| DealerArrive, DealerLeave | | the cart's `Open` attribute changes | `DealerCart` tag |
| NightStart, DayStart | nightIndex | `ReplicatedStorage.Clock` attribute `Phase` changes | attribute, as WorldController reads it |
| OfflineClaim | amount | `ClaimOffline` pressed | intent |
| Announce | text, rarity (optional) | a server shout-out arrives | `Announce` remote; rarity as a second argument lets the chime rise |

World loops need no moment: the world builder tags the part or model and Audio plays its loop while it exists: `CafeDoor` (each cafe's front door, only while its plot has an owner and it is day), `Fountain`, `FishTank`, `WorkingCat` (a cat at its station, awake or napping; only the 3 nearest within 14 studs purr) and `Stray` (a gold or Epic and up stray twinkles; the 3 nearest within 40 studs). By day the nearest resting cafe cat within 14 studs purrs too (the Napping children of each Plot's `Cats`: a sitting one all day, a lying one while `Effects.isLoafing`). Strays need no moment either: the hiss and the sprint follow their `HissAt` and `FleeingUntil` attributes.

For the UI: today `Theme.sounds` holds four optional asset ids. Proposal to the ui-designer: replace the ids with one injected `playSound(cueId)` function, so asset ids live only in `src/client/Audio/Cues.luau` and the UI keeps no ids of its own.

## 7. Sources plan

| Group | First choice | Fallback |
|---|---|---|
| Music beds, stingers, jingles | Creator Store licensed music (three candidates per slot) | commission or compose later; needed anyway for videos |
| Circle bell and chime, UI, ticks, coin tinks | synthesized by us (sfxr-style tool or a short script), fully original | Kenney UI Audio and Interface Sounds packs (CC0) |
| Meows, purrs | recorded from a real cat (see question 1) | Creator Store cat sounds |
| Whooshes, bells, rustles, lid rattles, bag rustle, gate, wheels, splashes | Creator Store sound effects | Freesound CC0 |
| Ambience beds | Creator Store ambience | Freesound CC0 field recordings |

Upload estimate for the slice: about 40 own files (mostly synthesized UI and circle sounds and recorded cats), inside even the 100 per 30 days of an unverified account. Creator Store sounds need no upload.

## 8. Listening list for Derek (once the P0 cues are in)

In Studio, Play in the dev copy:
1. Spawn: the day music starts after a moment, at a level you could talk over. Click three buttons: the click is soft, not sharp.
2. Buy something: register sound once. Try to buy what you cannot afford: a gentle bonk.
3. Walk into the Alleyway: the alley sounds take over.
4. Catch a Common: one circle, the net whoosh on your press and a bell or chime for the grade, then the sparkle. Miss on purpose: a soft thup and the retry.
5. With the Debug tools, catch a Rare or Epic: two or three circles; Perfects climb in pitch. Fail one: it chirps and patters off.
6. Walk home: the door bell, then the new-cat jingle with the music dipping under it.
7. Wait for night: the music fades, the dusk stinger plays, the night track starts, the alley gets its night bed. The dealer cart rolls in and you hear its music box on the street.
8. Rescue a stuck cat from a bin: rattles on hits, a boing for a lost paw, the purr-meow when it is free.
9. Turn the music toggle off and on, then the sfx toggle: everything in that channel stops and comes back.
10. Once on a phone speaker: the circle grades, coins and clicks are still clear.
11. The 2026-10-27 batch, once uploaded: hold E on a stray (a rising whirr that pops as the circles come; let go early and it fades), each circle pips as it appears, press G while carrying (a mrrp and soft paws), walk into the Alleyway and back (a playful pluck in, a calm chord out), press My Cafe (a poof), put a cat to work in the Staff tab and press Unequip All (a happy hop, one sleepy sigh), claim a Tip Jar gift, drag a volume slider (ticks at the new volume) and force a gold stray with the Debug tools (it twinkles nearby and plays the gold reveal when caught).

## 9. Open questions for Derek and Gavin

1. Does anyone have a cat we can record? Real meows and purrs from our own cats are original, free and the best way to make the cats feel alive. A phone in a quiet room is enough.
2. Which account uploads audio: Derek's, or a Roblox Group that will own the game? Uploaded audio is private to its owner, so this decides the permissions work.
3. Is Derek's Roblox account ID-verified? It raises the audio upload quota from 100 to 2,000 per 30 days; not urgent for the slice.
4. Music: OK to use Creator Store licensed tracks for the slice (free, Roblox-only), and decide on original music later for trailers?
5. Answered by design v0.5: a shove must never feel like an attack (effects list section 5), so the shove is a whoosh into a soft boop.
6. Should you hear other players' circle grades and catches nearby, or only your own plus the announcement chime? The slice plan is your own only.

Proposed for docs/decisions.md: the v0.3 moment names in section 6, shared with the vfx-animator.
