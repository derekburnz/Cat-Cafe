# Cat Cafe sound list

Draft v0.20, 2026-11-03 (v0.1 and v0.2 on 2026-10-26, v0.3 for design v0.4, v0.4 for design v0.5, v0.5 for the features built on 2026-10-27, v0.6 for design v0.8 and v0.9, features.md 2f, v0.7 for the quiet music and design v0.11 and v0.12, v0.8 for the Daily Treat, F70, v0.9 for the rare stray twinkle and the water step, v0.10 for quieter claim sounds, v0.11 for the Cat Cannon, F84, v0.12 for Derek's louder purring and the wheel's own "not yet", v0.13 for the release batch in two sound sheets, v0.14 for the rare decor sounds, v0.15 for the F93 net swing, v0.16 for quieting the cat level up and zone chimes with their toasts, v0.17 for the rescue sounds and the F92 Team Rescue chime, v0.18 for the F90 cafe orders, v0.19 for hooking the crate reel, trade and Rally cues, which nothing played, and for reusing uploaded sounds for the bait bowl and the offline claim until the upload quota allows their own, v0.20 for music that changes between songs instead of looping (#978) and a quieter cafe (#981)). Owner: sound-designer. Built from gdd.md v0.5, data-model.md v0.5 (sections 2, 8 to 13, 15 and 17), features.md v0.5 (sections 2b and 2c), world-and-feel.md and style guide section 1. Status: 76 files synthesized and gated. The first 44: 37 effects and jingles (every UI sound in 5.8, the whole net catch with the hiss, the v0.5 sprint away and the Purrfect chime, the shove and its held-tight squeeze, coins, purchase, the door bell, the stray flee, both purrs, the gate, the shutters and sign, the shout-out chime, the cat found and rank up jingles; `assets/cat-cafe/audio/synth/synth.py`), 6 ambience beds (cafe, Alleyway and Park, day and night; the night cafe rebuilt as the closed cafe for v0.5) and the cafe door loop (`synth/ambience.py`). The code that plays them is in `games/cat-cafe/src/client/Audio/`; the engineer wired start, settings, carrying and zones (PR #66) and the moments (`src/client/Moments.luau`, PR #91). Derek uploaded all 76 with `assets/cat-cafe/audio/upload.py` (31 on 2026-10-26, 13 more on 2026-10-27, then the 17 for the 2026-10-27 features and the 15 for design v0.8 and v0.9 that evening); the ids are in `Cues.luau` and the sources log. Later that night Derek replaced the ambience with quiet music: the cafe's day bed had a synthesized murmuring crowd that sounded eerie, so all seven beds and the cafe door loop were removed, three original tracks were composed (`synth/music.py`, section 3) and the purr was rebuilt. Design v0.11 and v0.12 add three more: the tackle's whoosh and miss skid and a cat level up chime. Those eight files went up from GitHub Actions (the upload-audio workflow) the same night, so 75 files have ids. On 2026-10-28 the Daily Treat (F70) added a stamp and a day 7 card fanfare, section 5.10, both uploaded from Actions the same night (77 files with ids). Every row is a cue: one named sound the game plays, with the moment that fires it. How to source, prepare, upload and wire them is in `.claude/skills/audio-pipeline/SKILL.md`.

Priorities follow the slice: **P0** is needed for the Phase 2 exit test to feel like a game (20 cues), **P1** before the friends alpha, **P2** polish.

What v0.3 changed here: the hold-and-release ring became 1 to 5 closing circles with a grade per press, the rescue hold became a timing bar (a tree shake in the Park), bait moved to your own bowl with a 10 minute wait and Tame or Let go, other players can bump a carried cat loose, shiny cats exist, tiers replace cafe levels and nights last 5 minutes with the cafe still open, a food dealer and rich customers by day.

What v0.4 changed here (world-and-feel.md): the first Miss ends a catch, so a Miss now hisses and the cat jumps back, and the paw you lose pops; an all-Perfect Purrfect catch chimes. The flee roll is gone. Cafes should feel busy from the street, so each cafe front door played chatter and cups 3D (removed with the ambience on 2026-10-27), and cats working near you purr. Empty plots are For Rent shops whose shutters roll up when a player joins; gates dissolve their barrier; server shout-outs chime higher for rarer cats.

What v0.5 changed here (Gavin's round 2, features.md 2c): a Miss still hisses, then the cat sprints 12 to 32 studs away and anyone can chase it and try again, so the paw pop is retired and a paw patter runs off with the cat. Bump becomes Shove: any player can shove another inside a catching area, so every shove gets a playful whoosh and boop, and a shoved carrier still drops the cat (or holds on) with its own sound. The cafe closes at night: the night bed inside is cats asleep, not customers, and the door loop stops at nightfall and on For Rent shops.

What the 2026-10-27 features changed here (features.md F42 and F45 to F48, Derek's UI round): holding E to catch fills with a rising whirr that pops on the trigger, and each circle pips as it appears; Drop sets the cat down with a mrrp and soft paws; walking between the safe street and a catching area plays a calm or a playful chime with the Safe zone chip; fast travel and My Cafe poof; a cat starting or leaving a role (Staff tab, Unequip All) hops in or sighs off; Tip Jar gifts and Index rewards get a ready chime, a claim and a red dot blip; the volume sliders tick; gold replaces shiny (a gold reveal and a twinkle on gold strays); a resting cafe cat purrs (sitting, or lying in a loaf); and the Spin Wheel window (F49) winds up, ticks past each slice and lands on a fanfare.

What design v0.8 and v0.9 changed here (features.md 2f, F55 to F66): the short night gets a town bell 15 s before dusk, a dusk stinger whose vibraphone run ends on the area gates latching shut, and a sunrise stinger as the areas open with fresh cats (the two stingers were silent until now, and they play on the phase change, so they need no new moment); a Mythical shout-out gets its own sting over a wordless choir; a carry starting pops with a pleased mrrp (the dropped cat being picked up); a catch's getaway puffs outward and patters off; collecting tip piles clinks; rich visitors finally get their ding-dong and coin cascade; the Codes Cat has a redeem jingle (a wrong code is the usual gentle bonk); the Cat Collector arrives with a curious clarinet motif and a trade jingle; the Mystery Visitor's gift appears with a cloak swish and a dreamy celesta run, opens with paper and sparkles, and a potion pops, glugs and shimmers. Audio drives all but the UI's four from attributes the design already defines (`Clock`, the plot, the characters).

What design v0.11 and v0.12 changed here (features.md F74 and F75): the Shove becomes a Tackle, a 12 stud dive that can miss, so the press whooshes for everyone nearby, a hit keeps the shove's boop, and a miss lands in a belly flop that skids to a stop with a silly wooden "bonk bonk". Both follow the tackler's `TackleAt` and `TackleMissAt`, like the effects. Cats level up over time, so the owner hears a short, soft celesta chime with the level up toast.

What the release batch changed here (2026-11-01, Derek: everything queued ships before release): one sting per rarity from Epic up for the catch and your own big pull (F89), a Lucky Day chime (F88), the rainbow coat's shimmer and sting (F99), the camp extras' splash, basket creak and box rattle (F100), the Rescue Rally's cheer (F101), the trade countdown and its done chime (F102), the crate reel's ticks and stop (F103) and the Bellhop Cat's bell (F96). They are fifteen sounds in two sound sheets (section 5.13), so the batch costs two uploads.

## 1. How Cat Cafe should sound

A quiet afternoon cafe, then a small friendly adventure after dark. By day: soft acoustic music, cups and spoons, the occasional meow from a station. At night: the music turns curious and tiptoes, the alley hums and drips, a street lamp buzzes, strays chirp from behind the bins and a mysterious cart jingles on the street, while the cafe keeps a few night owls. Every effect is soft and rounded, like the blocky toy shapes: pops, tinks, chimes and patters, never buzzers, crashes or anything that startles a young player. A missed circle says "aww, try again", not "wrong". The cats are the stars in sound too: short, cute, readable meows.

## 2. The mix

Four channels (Roblox calls them SoundGroups): every sound belongs to one, and the two settings toggles the profile already has (`settings.music`, `settings.sfx`) mute whole channels. Two volume sliders (`settings.musicVolume`, `settings.sfxVolume`, 0 to 1, Derek 2026-10-27) scale them: the channel volume is its start volume times the slider squared, so half way sounds about half as loud. A toggle that is off wins, and a slider at 0 counts as off, so nothing loads.

| Channel | Holds | Start volume | Muted by | Scaled by |
|---|---|---|---|---|
| Music | day and night beds, stingers, jingles | 0.5 | music toggle | music slider |
| Ambience | room tone and outdoor beds, world loops (fountain, lamp hum, dealer cart) | 0.6 | sfx toggle | sound slider |
| Sfx | gameplay sounds, cats, coins | 0.8 | sfx toggle | sound slider |
| Ui | buttons, panels, toasts | 0.7 | sfx toggle | sound slider |

Stingers, the rank up jingle, the gold reveal, the Index reward, the wheel win and the Legendary and Mythical fanfares duck the music to 40 % while they play. During a catch the music ducks to 60 % and the ambience to 50 % so the circles are easy to hear. When it gets busy, the order of importance is: circle grades and the catch result, UI feedback, coins, cat voices, ambience, music.

Claim sounds sit a step lower than the other rewards: Derek found the ding on claiming a little loud (2026-10-28), so `giftClaim` (quests, achievements and the Tip Jar), `indexReward`, `richTip`, `uiDailyStamp`, `uiCodeRedeem` and `offlineClaim` play about 4 dB quieter than before (cue volume 0.45 to 0.5). The server's toast still pops with each claim, so the two together stay clear.

## 3. Music

The clock is 5 minutes of day and 90 s of night (data-model section 9, v0.9). Music follows the phase on every client at once, because the phase is server-wide. Derek asked on 2026-10-27 for a couple of cozy songs that rotate, quietly, instead of the ambience. On 2026-11-03 he found them "a little too repetitive and too long", so no song loops any more. A phase plays one of its songs for half its length (two of its four 8 bar sections, from one picked at random, wrapping round the seamless loop), fades it out, rests 15 to 30 s and plays another. It never plays the same song twice in a row while the phase has another. The day picks from every `musicDay*` cue with a file and the night from every `musicNight*` cue, so a new song joins the rotation by getting its id. Music plays at 0.3 in the Music channel (0.5), well under the effects, and the Music switch and slider in Settings still control it.

| Cue | Moment | Length | Feel | Instruments | Tempo, key | P |
|---|---|---|---|---|---|---|
| `musicDayA` "Open for Business" | the day rotation | 87 s, 32 bars, 4 sections | warm, busy, content | electric piano, upright bass, brushes and a soft kick; the vibraphone tune, then a nylon guitar picking the chords, then the tune on a music box; a glockenspiel closes each phrase | 88 BPM swung, F major | P0 |
| `musicDayB` "Second Cup" | the day rotation | 91 s, 32 bars, 4 sections | lazy afternoon, bossa feel | nylon guitar (bass and strummed chords), a flute tune, the vibraphone answering an octave up, shaker and rim clicks | 84 BPM straight, G major | P1 |
| `musicNightA` "After Hours" | the night rotation | 80 s, 32 bars, 4 sections | a cozy lullaby while the cats sleep (2026-10-27: cozy, no longer sneaky) | harp rocking on the chords, soft strings, a music box tune, the vibraphone an octave down | 72 BPM waltz, C major | P0 |
| `musicDayC` "Paw Prints" | the day rotation | 74 s, 32 bars, 4 sections; region 0 to 73.846 of `sheetMusic` | bright and bouncy | pizzicato, a marimba tune, flute, glockenspiel; no kick (Derek 2026-11-03: the beat was too loud) | 104 BPM, D major | P1 |
| `musicDayD` "Market Morning" | the day rotation | 69 s, 32 bars, 4 sections; region 74.346 to 142.918 of `sheetMusic` | a sunny market | ukulele strums, upright bass, soft claps, flute and marimba; no kick | 112 BPM, A major | P1 |
| `musicNightB` "Night Owls" | the night rotation | 101 s, 32 bars, 4 sections; region 143.418 to 244.470 of `sheetMusic` | late and cozy, a little dreamy | electric piano, brushes, music box and vibes, light swing; no kick | 76 BPM, F major | P1 |
| `stingDusk` "Night Shift" | NightStart (F66: the areas close) | 3.2 s | the lamps come on, the sign turns to the moon, the gates latch for the night | descending vibraphone run into a cozy chord, a soft lamp click, a wooden latch (synthesized, until a composed one) | | P1 |
| `stingDawn` "Fresh Pot" | DayStart (F66: the sunrise wave, the areas open) | 3.2 s | morning, the sun sign, fresh cats | rising glockenspiel, one shop bell, a warm swell (synthesized, until a composed one) | | P1 |
| `jingleCatFound` | CatFound | 2 s | "new friend!" | rising four-note glockenspiel, harp sweep | | P0 |
| `jingleRare` / `jingleEpic` / `jingleLegendary` / `jingleMythical` | CatchSuccess or RescueDone by rarity, and your own big pull (SecuredRare, F89, which is how a tame gets its sting); the crate reel's stop. jingleRare stays silent: F89 asks for stings from Epic up | 1 / 1.5 / 3 / 4 s | rising excitement; Legendary is a small warm fanfare, Mythical adds a choir-like pad (no words) | chimes, then harp, then soft horns, then the pad | | P1 |
| `jingleRankUp` | RankUp | 3 s | proud, the cafe grows; tier 5 gets a longer ending | piano and glockenspiel flourish, soft horns | | P0 |

The three songs above (#980, Derek approved them by ear on 2026-11-03) share one upload, `sheets/CatCafe_Sheet_Music.ogg` (stereo, 244.5 s, 4.4 MB; Roblox allows 20 MB and 7 minutes a file). Each cue plays its region of the sheet and a play's start counts from the region's start (Audio `crossfade`). Uploaded 2026-11-04 (`sheetMusic` = 90426389837188), so they are in the rotation.

Phase change: the current song fades out over about 2 s, the stinger plays, and one of the next phase's songs starts from its top. Joining mid-phase starts a song at once. No vocals or lyrics anywhere.

Source: our own. The three tracks are composed and synthesized in `assets/cat-cafe/audio/synth/music.py` (electric piano, plucked strings, flute, vibraphone, music box and brushes all made from code, fixed seeds), so they are original and can also go in trailers and devlog clips, which Creator Store licensed music cannot. Every song is 32 bars whose notes and echoes wrap around the end, so it loops with no seam.

## 4. Ambience

Retired 2026-10-27 (Derek: "the ambient noises are not needed and should be replaced with some cozy background music"). The beds and the cafe door loop below were removed from the game and the repo; their rows stay as a record and the generator `synth/ambience.py` stays in case one comes back. The 3D prop loops (fountain, fish tank, lamp, cart) have no files.

2D beds by zone and phase, crossfaded over about 1.5 s when the player walks between zones, plus 3D loops placed on props. The three later areas are friendly too: the Sewer drips and echoes, it does not growl.

| Cue | Where, when | Feel | P |
|---|---|---|---|
| `ambCafeDay` | inside any cafe, day | no voices (2026-10-27: the synthesized murmur sounded eerie in game): cup clinks, spoons, saucers, a coffee pour, the steamer and grinder, birds faint through the windows, a warm room presence; very low (0.3) | P1 |
| `ambCafeNight` | inside, night (v0.5: the cafe is closed) | no customers: a wall clock, the fridge, cats purring in their sleep with a dreaming chirp now and then, one muffled car outside; played lower than the day bed | P1 |
| `ambAlleyDay` | Alleyway, day | distant traffic, pigeons, a little wind | P1 |
| `ambAlleyNight` | Alleyway, night | low city hum, light wind, water drips, crickets | P0 |
| `ambParkDay` | Park, day | birds, leaves, the fountain from afar | P1 |
| `ambParkNight` | Park, night | crickets, soft wind, an owl far away | P1 |
| `ambNeighbourhood`, `ambWoods`, `ambSewer` | the later areas, day and night variants | garden birds and a lawnmower far off; leaves and a stream; gentle drips and a hollow echo | P2 |
| `loopCafeDoor` | 3D on every cafe front door (tag `CafeDoor`), 24 studs, only while the cafe is open: an owned plot, by day (v0.5) | no voices (2026-10-27): the cafe's cups and espresso machine muffled through the doorway, sparrows on the awning and a soft wind chime by the door now and then, so a street of cafes sounds lived in; well under the music (0.35); quiet on For Rent shops and at night | P1 |
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

Traps: Alleyway trash bin and garbage bag, Park tree and trashcan. The bar kind needs 3 to 7 hits by rarity since F93 (catch-rework.md) with 3 paws for misses; the tree shakes, the cat drops and one catch circle must be Good or better.

These rows were written on 2026-10-26 but never made, so until v0.17 a rescue was silent apart from the rarity sting. On 2026-11-02 they were made together with F92's Team Rescue chime (playing-together.md section 3) and share the fifth sound sheet, `sheets/CatCafe_Sheet_Rescue.ogg` (mono, one upload). The tones sit in C major: the pip starts on C5 and climbs the pentatonic (C5 to D6 over a Mythical's seven hits), the done chime rolls up the C chord and the Team Rescue notes ring above it.

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `rescueStart` | RescueStart | 2D | 0.4 s | a curious "mew?" from inside the trap and a small ready chime | P1 |
| `rescueHitBin` / `rescueHitBag` / `rescueHitTree` / `rescueHitCan` | RescueHit by trap type | 3D on the trap | 0.3 s | metal lid rattle; plastic bag rustle; leaves shaking (the branch shake); park can clang, soft | P1 |
| `rescueHitTone` | RescueHit | 2D | 0.15 s | rising pip per hit, so you hear how close you are | P1 |
| `rescueMiss` | RescueMiss | 2D | 0.25 s | soft boing and a small paw-print tick as a paw is used | P1 |
| `rescueDrop` | RescueDrop (tree cat falls) | 3D on the tree | 0.5 s | leaf whoosh and a surprised "mew!"; the catch circle sounds follow | P1 |
| `rescueFail` | RescueFail, RescueCancel | 2D | 0.4 s | small "aww" down-tone; the cat is still stuck, nothing is lost | P1 |
| `rescueDone` | RescueDone | 2D | 1 s | warm chime and a grateful purr-meow | P1 |
| `teamRescue` | TeamRescue (F92: a helped rescue freed its cat), on the rescuer's and the helper's screens, just after their RescueDone | 2D | 0.8 s | a light high-five clap and two bright glockenspiel notes, one for each friend (G6 then C7), ringing above the done chime | P1 |

A helper's bar fires the same RescueStart, RescueHit, RescueDone and RescueFail on the helper's screen, so both friends hear every hit (each client's `RescueResult` counts hits from either player). A helper's miss costs no paw, so `rescueMiss` never plays for a helper's press.

### 5.3 Carry, shoves and check-in (data-model section 10c; v0.5 Shove keeps the Bump names in code)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `carryPurr` | CarryStart until CheckIn or BumpLoose | 2D, quiet | 2.6 s loop | contented purr in your arms: about 24 tiny clicks a second through a cat's nose and mouth, a longer breath out and a softer, quicker breath in, a little airy (rebuilt 2026-10-27: the first one read as a low rumble) | P1 |
| `shove` | Shove, every shove that lands (v0.5, F41), and since v0.11 every tackle that lands | 3D at the shoved player | 0.4 s | a quick whoosh into a soft, bouncy "boop": a playful push, never a hit | P1 |
| `tackleLunge` | a character's `TackleAt` is set (F74: a tackle is pressed and accepted), under 0.6 s old | 3D on the tackler | 0.5 s | a rush of air that swells through the 0.35 s dive and drops as it lands, a cloth flutter and a soft rising "fwip": a cartoon dive | P0 |
| `tackleMiss` | a character's `TackleMissAt` is set (F74: the lunge hit nobody), under 0.6 s old | 3D on the tackler | 1 s | a soft belly flop, a skid that slows to a stop and a wooden "bonk bonk" going down: silly, never painful | P0 |
| `bumpLoose` | BumpLoose, after Shove when the carrier's cat drops | 3D at the carrier | 0.55 s | the StrayFlee file: a startled "mrrp!" and paws scampering off; the toast plays its own bonk | P1 |
| `bumpHeld` | BumpHeld ("It held on tight!") | 3D at the carrier | 0.6 s | a rubbery double squeeze and a light mint shimmer, with the effects' squeeze wobble and ring | P1 |
| `checkInBell` | CheckIn | 3D on your door | 1 s | shop-door bell | P0 |
| `catDrop` | CatDrop (F45: the Drop button or G while carrying) | 3D at your feet | 0.6 s | a small "mrrp", two soft paws landing and a little shake | P1 |
| `catPickUp` | a character's `CarryStartedAt` is set (F56: a dropped cat picked up; any carry starting, but your own stays quiet for 2 s after your catch or rescue) | 3D on the carrier | 0.4 s | a soft pop as the cat hops into your arms and a pleased little "mrrp" | P1 |
| `getaway` | a character's `RushUntil` moves ahead (F55: a catch pushes everyone within 10 studs back and the catcher rushes) | 3D on the catcher | 0.85 s | a puff of air bursting outward, then quick light paws rushing off | P1 |
| `catPlaced` | CatPlaced (a cat starts a role: Staff tab, Equip Best) | 2D, one per sync | 0.6 s | soft hop thump, a happy "mrrp" and three sparkles | P1 |
| `shiftChime` | a shop-only cat (Duchess Marzipan; King Croissant and Sprinkles once their models ship) goes from off duty to working, seen by Audio from its `Role` and `Bedtime` attributes; not when its model is built or streams in already working (#1191) | 3D at the cat, 40 studs | 1.0 s | a soft three-note celesta lift (G, B, D) and a faint bell shimmer, at 0.3, at most every 2 s; plays under VFX's lilac sparkle (#1259) | P2 |
| `catRest` | UnplaceCat (a cat leaves its role; Unequip All plays it once) | 2D | 0.65 s | a sleepy sigh, a small falling "mew" and a soft flop | P1 |
| `catLevelUp` | CatLevelUp (F75: one of your cats reaches a new level; the owner only). Silent since 2026-11-02 with its toast (Derek 2026-10-28: "a little spammy", UI PR #669) | 2D, quiet, 1.5 s apart at most | 0.9 s | three quick celesta notes up and a small twinkle, beside the toast and the sparkle | P1 |
| `catSold` | CatSold | 2D | 0.6 s | coin clink and a small goodbye meow | P2 |

### 5.4 Bait bowl (data-model section 8)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `foodKibble` / `foodTuna` / `foodSalmon` / `foodSardines` / `foodCaviar` / `foodMoonMilk` / `foodStarTreat` | food goes in the bowl (by food; `Logic.foodCue` maps `star_treat` to `foodStarTreat`) | 3D at you (food goes in from the F menu anywhere) | 0.5 to 0.75 s | #983, made 2026-11-03, regions of `sheetBait`: kibble rattling into a ceramic bowl; a tuna can's ring-pull and a plop; a juicier salmon slap; a sardine tin peeled and two plops; caviar pearls and a crystal tink; a Moon Milk pour and a silvery shimmer; a Star Treat crunch and a three-note twinkle. Soft (0.22 to 0.35). Uploaded 2026-11-04 (`sheetBait` = 91146885655744); `foodDealer` stays the fallback for a food with no cue | P1 |
| `foodDealer` | food goes in the bowl, any food without its own file | 3D at you | 0.28 s | 2026-11-02: the `trayClink` part of the Cafe sheet, a soft tap and two china clinks, at half volume (0.22) since 2026-11-03 (#981). Planned: the plop plus a faint twinkle | P2 |
| `baitArrive` | your bait cat arrives at the bowl | 2D (the card pops wherever you are) | 0.6 s | 2026-11-02: the `catPlaced` file, a hop, a happy "mrrp" and three sparkles, at half volume (0.3) since 2026-11-03 (#981). A gold cat plays `goldReveal` and a rainbow one the `rainbowNear` shimmer instead | P1 |
| `baitTame` | none: a tame sounds with its check-in (the door bell, the new cat jingle and the sting from Epic up) | 2D | 1 s | kept for a file of its own later | P2 |
| `baitLetGo` | Let go | 2D | 0.6 s | 2026-11-02: the `catDrop` file, a small "mrrp", soft paws and a shake as it hops off, at half volume (0.3) since 2026-11-03 (#981) | P1 |

None of these needs a moment: Audio follows the `bait` in each ProfileSync (`Logic.baitChange`). Food going in, the cat arriving and a Let go each sound once; a tame adds its cat in the same sync, so it stays with its check-in. The first sync after joining only sets where the bowl stands, so a rejoin with a cat already waiting is quiet.

### 5.5 Cats in the world

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `meow` (5 variants) | idle strays and working cats, every 8 to 20 s each, at most two at once | 3D, 40 studs | 0.3 to 0.8 s | short, cute, varied; pitch shifts a little per play | P1 |
| `purr` | a working cat (tag `WorkingCat`), only the nearest one within 14 studs (the 3 nearest until Derek found the cafe too busy on 2026-11-03, #981), never a cat the player hid (`HiddenLocal`, Show other cats off); and by day the nearest resting cafe cat within 14 studs, sitting (`Pose` "sit", PR #266) or lying in a loaf (`Effects.isLoafing`, VFX PR #222; one only, so it is always a cat Effects animates, reviewer N131, N150) | 3D, 8 studs | 2.5 s loop | quiet purr, so a busy cafe sounds cozy up close; the same real purr as `carryPurr` at 25 clicks a second (rebuilt 2026-10-27; both purrs about 2.5 dB louder since Derek asked on 2026-10-28) | P1 |
| `rareNear` | you come within 30 studs of a Mythical stray (`Rarity` on a `Stray`); once per cat until you have been 45 studs away, 3 s apart at most (2026-10-28: replaced the `shimmerRare` loop, which played all the time around gold and Epic and up strays and annoyed Derek; only Mythical makes a sound now) | 3D on the stray | 1.3 s | four soft gold twinkles over a breath of air, quiet | P1 |
| `goldReveal` | a gold cat comes into your arms (a `HeldCat` under your character with `Gold`, or `Gold` turning on), and a gold bait cat arriving at the bowl (F42; was shinyReveal) | 2D | 1.8 s | a shimmer climbing into a rich gold bell chord, sparkles settling round it; ducks the music | P1 |

### 5.6 Coins, tiers and the night economy

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `coinPop` | CoinPop (customer coin float, your own cafe: each seated customer floats one every 3 s) | 3D on the table | 0.15 s | soft coin tink, small pitch changes; since 2026-11-03 at volume 0.2 and at most one every 4 s, one voice (Derek: "ding's are too loud and too often I think its the money pop up dings", #981) | P0 |
| `purchase` | Purchase (shop, decor, food, dealer) | 2D | 0.5 s | soft register "ka-ching" (the UI's `buy` hook) | P0 |
| `offlineClaim` | Claim on the welcome back card (the UI plays it) | 2D | 1.1 s | #983, since 2026-11-04: its own jingle, coins sliding out of a cloth pouch and a soft two-note "welcome back", region 7.750 to 8.850 of `sheetBait`, at 0.3. Until then it reused the `richTip` file (quieted to 0.22 for #981) | P1 |
| `placeFurniture` | Purchase of a table or decor | 3D on the new piece | 0.5 s | wooden thunk and a sparkle | P2 |
| `gateOpen` | AreaUnlock (the next area's gate after a rank up) | 3D on the gate | 1.5 s | v0.4: the see-through barrier dissolves, a soft shimmer and a rising sparkle | P1 |
| `shuttersUp` | PlotOpened (a For Rent plot becomes a player's cafe) | 3D on the shop front | 1.5 s | shutters rattling up, with `signFlip` as the sign turns to OPEN | P1 |
| `richArrive` | RichArrive (a rich customer at your cafe; F61 makes them richer and more common) | 2D | 1.1 s | posh little two-note "ding-dong" and a coin pile settling | P1 |
| `richTip` | RichTipClaim (claimed or auto-collected) | 2D | 1.3 s | big coin cascade and a bright chime | P1 |
| `tipPile` | your plot's `TipPiles` went down (F61: `CollectTips`, walking near a pile or Collect on the till). Silent since F97 (#714): a pile pays the moment it appears, which plays `coinPop`, and the count only drops when old piles are swept | 2D | 0.5 s | a short clink of coins scooped off the tables, once per collect however many piles | P1 |
| `dealerArrive` | DealerArrive | 3D on the cart | 1.5 s | cart wheels rolling in and a lantern bell. Quiet on purpose for now: the cart parks with the dusk stinger, which marks it | P2 |
| `dealerLeave` | DealerLeave | 3D on the cart | 1.5 s | wheels rolling away. Quiet with the dawn stinger the same way | P2 |
| `announce` | Announce, the server shout-out (Epic and up, every gold cat, rank ups to Tier 3 and up) | 2D | 1 s | two-note chime under the banner, one note higher per rarity step | P1 |
| `announceMythical` | Announce with rarity Mythical (F58: a Mythical in the sunrise wave, or a Mythical catch); the two-note chime if the file is missing | 2D | 2.4 s | the shout-out's two notes grow into a shimmering gold chord over a wordless choir; ducks the music | P1 |

### 5.7 Clock

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `signFlip` | NightStart, DayStart, PlotOpened | 3D on your door sign | 0.4 s | wooden sign turning between sun and moon, or to OPEN | P1 |
| `lampOn` | NightStart | 3D on each street lamp | 0.5 s | click and hum start | P2 |
| ~~`duskBell`~~ | Removed 2026-11-05 (Derek: no dings before night; the "Night falls" banner is the only warning). The file stays uploaded but is unused | | | | |

### 5.8 UI

| Cue | When | Length | What it sounds like | P |
|---|---|---|---|---|
| `uiClick` | any button press (the UI's `click` hook) | 0.05 s | soft pop | P0 |
| `uiError` | a press on a greyed button, Toast of kind warn, can't afford, not allowed, "You got shoved!", a wrong or used code (F65) (the UI's `error` hook) | 0.05 s | a dull low "tuk": since 2026-11-03 the `uiTab` file played at 0.8 speed and volume 0.45 (Derek: "The noise of hittin a button you can't click is also a little loud and change it to something less annoying", #981); before that its own file, two falling notes | P0 |
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
| `uiCodeRedeem` | `CodeResult` ok (F65, the Codes Cat's box; the UI plays it) | 1.25 s | a key turns in a little lock, a bright run and a sprinkle of coins | P1 |
| `uiTrade` | the Cat Collector trade goes through (F63, `AnswerCollector(true)` accepted; the UI plays it) | 1.2 s | two little runs pass each other, then a bright "deal!" chord and a coin | P2 |

The UI's `catFound` hook plays `jingleCatFound`.

### 5.9 Zones and travel

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `zoneArea` | Audio.setZone from the safe street (nil or "Cafe") into a catching area, with the Safe zone chip. Silent since 2026-11-02: its toast and the zone chip are gone (Derek 2026-10-28, UI PR #669) | 2D | 0.5 s | an alert little pluck up a fifth with a paw tap: playful, shoves are on, never a warning | P1 |
| `zoneSafe` | Audio.setZone from a catching area back to the street (the chip's "Safe zone"; the UI's toast is quiet). Silent since 2026-11-02: its toast and the zone chip are gone (Derek 2026-10-28, UI PR #669) | 2D | 0.75 s | two felt notes falling to a soft chord, a calm settle | P1 |
| `travelPoof` | Travel (fast travel, My Cafe, a manhole, and from F84 the Cannon button, which moves you at once to a cannon nearby even in a wild area; once the server says the trip worked) | 2D | 0.95 s | a whoosh up, a soft poof where you land and a few sparkles | P1 |
| `waterStep` | each splash under a player's step in a puddle, pond, pool or fountain (2026-10-28, Derek's splashes: the vfx-animator's `Effects.Splash.stepped` with kind "player", about one per 2.6 studs, already budgeted to the nearest walkers); a cat's steps (kind "cat", one per 1.1 studs) stay silent so strays never patter | 3D at the splash, 30 studs | 0.32 s | a soft slosh with a little drip on top, a little higher or lower each step, quiet | P2 |

Zone chimes play one per 4 s, so walking along an area's open edge plays one, and none for 2 s after a trip.

### 5.10 Rewards and the spin wheel

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `giftClaim` | TipJarClaim (F47, a gift newly claimed in TipJarState) | 2D | 1 s | a ribbon tug and paper pop, coins tumbling into the jar, a two-note chime | P1 |
| `indexReward` | IndexReward (F48, a milestone newly claimed) | 2D | 1.5 s | a page turns, a stamp lands, a bright run rises to a sparkle; ducks the music | P1 |
| `uiSpinStart` | the Spin Wheel window (F49) starts turning (the UI's playSound) | 2D | 0.6 s | a wooden ratchet winding up into a whoosh | P1 |
| `uiSpinTick` | each slice passing the pointer (the UI; it can fire every frame early in the 4 s spin, so a 0.04 s gap and 2 voices) | 2D | 0.05 s | a wooden peg click, so the ticks slow down with the wheel | P1 |
| `uiSpinWin` | the wheel lands on a prize (the UI) | 2D | 1.4 s | a quick run up into a bright chord with coins on top; ducks the music | P1 |
| `uiSpinBusy` | the wheel can't spin yet: a refused spin, such as a press while it is still turning, no spin left or too far away (the UI, in place of `uiError`; Derek 2026-10-28: the error's two falling notes sounded like a device disconnecting) | 2D | 0.26 s | the wheel's brake peg knocks twice on the pointer, a soft dry wooden "tok-tok" on one pitch, and a short rattle | P1 |
| `uiDailyStamp` | a Daily Treat stamp is claimed, days 1 to 6 (F70, data-model 11e; the UI plays it when `ClaimDailyTreat` is accepted) | 2D | 1.5 s | a soft rubber stamp lands on the card, then a warm vibraphone run over a piano chord and a small sparkle; a little bigger than `uiCodeRedeem` | P2 |
| `jingleDailyCard` | day 7 fills the card (F70; the UI plays it instead of `uiDailyStamp`) | 2D, Music channel | 3.2 s | the last stamp lands, a music box plays a short happy phrase over a slow swell of soft chords and it settles on a sparkle: a gentle fanfare; ducks the music | P2 |

The spinner hears the window's own cues; Audio binds no wheel moment, so nothing doubles. Other players near the world wheel (VFX PR #226, which turns on `LastSpinAt`) hear nothing yet; a bystander tick could follow that attribute later.

### 5.11 Visitors and potions (v0.8, section 12b)

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `visitorCollector` | your plot's `CollectorUntil` goes from 0 to a time (F63: the Cat Collector comes by) | 2D | 1.5 s | a polite, curious clarinet motif and the glint of a magnifying glass | P2 |
| `visitorMystery` | your plot's `MysteryGiftAt` goes from 0 to a time (F64: the Mystery Visitor left a gift) | 2D | 1.7 s | the swish of a cloak and a dreamy whole-tone celesta run, curious, never spooky | P2 |
| `giftOpen` | `MysteryGiftResult` (F64: you opened the gift; the UI plays it with the result card, not on `MysteryGiftAt` clearing, which also happens at the keep timeout) | 2D | 1.2 s | the ribbon slips, the paper tears, a pop and a sparkle | P2 |
| `potionDrink` | `UsePotion` accepted (F64; the UI plays it when the bag's count drops) | 2D | 1.25 s | a cork pops, three bubbly gulps and a shimmer rising as it starts working | P2 |

### 5.12 The Cat Cannon and the camps (F84, hometown-cannon.md; Derek's yes 2026-10-28)

The 3 s flight (section 3b) is three cues, so each plays where it happens: the launch at the barrel for everyone in the square, the clouds only for the one flying, and the whistle and landing at the pad for everyone at the camp. Your own flight plays flat, since your camera flies with you. All friendly and cartoon: the boom is a deep soft thump with a cork "pomf", never a bang.

| Cue | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `cannonLaunch` | a character's `CannonLaunchAt` is set (flight 0 to 1.4 s) | 3D at the character (anchored in the barrel), 80 studs; flat for the one flying | 1.5 s | a hollow "dunk" into the barrel, ratchet clicks as it turns, the fuse fizzing, then at 0.5 s a big friendly boom, paper confetti and a whoosh rising away | P1 |
| `cannonClouds` | `Config.CannonCloudsAt` (2.0 s since the longer flight, #954) after your own `CannonLaunchAt`; 1.4 s without the key | 2D, the one flying only | 1.0 s | soft wind gusting past and a quiet airy chord swelling as the clouds light up in the area's colour | P1 |
| `cannonLand` | 0.6 s before the feet touch the pad, `Config.CannonTouchdownAt` (3.5 s of the 4.0 s flight with the hero landing, #955; `Logic.cannonBeats`), so the thump lands on the feet; without the key 0.6 s before the flight ends; only while `CannonLaunchAt` is still set | 3D at the character (now on the landing pad), 60 studs; flat for the one flying | 1.05 s | a cartoon slide whistle falling, then at 0.6 s a soft landing thump with a dust puff and a little bounce | P1 |
| `cloudHop` | your own `CloudHopAt` (Home from a wild area, and the night sweep; the Alley button went with the Alleyway, PR #566), and a Travel while you are in a wild area or your hop has just started, except the Cannon button's (`Logic.travelCue`) | 2D | 1.6 s | clouds whoosh in, a muffled breath of wind while you move, then a soft whoosh out with a sparkle | P1 |
| `campCheckIn` | `CampCheckIn` for your own userId: a carried cat banked at a camp (the door bell stays the cafe's and never rings in a wild area) | 2D | 1.4 s | the cat hops into a wicker carrier, the lid latches, a soft puff and a warm three-note vibraphone chime | P1 |

### 5.13 The release batch and sound sheets (F88, F89, F96, F99 to F103; 2026-11-01)

Roblox lets an account without ID verification upload 100 sounds in 30 days, and this batch came with 6 left (the first ones roll off on 2026-11-25; with ID verification the limit is 2,000). So its fifteen sounds share two files, **sound sheets**: `sheets/CatCafe_Sheet_World.ogg` (mono, for 3D) and `sheets/CatCafe_Sheet_Moments.ogg` (stereo, flat), each the parts in order with half a second of silence between. A part's cue names its sheet and its `region` (start and stop in seconds), and Audio plays only that stretch (`Sound.PlaybackRegion`, with a timed stop just after it as a backstop). Each part is also written and gated on its own under `sheet-parts/`. `synth.py` builds the parts and sheets and prints the regions for `Cues.luau`; a changed part means one new upload of its sheet.

| Cue | Sheet | Moment | 2D/3D | Length | What it sounds like | P |
|---|---|---|---|---|---|---|
| `jingleEpic` | Moments | as `jingleRare` above, Epic (and a gold Epic's big pull) | 2D | 1.5 s | a quick harp sweep up into two bright glockenspiel notes and a small sparkle | P1 |
| `jingleLegendary` | Moments | Legendary | 2D, ducks | 3 s | a small warm fanfare: soft horns play a pickup into a held chord, a harp sweeps under it, gold bells on top | P1 |
| `jingleMythical` | Moments | Mythical | 2D, ducks | 4 s | a shimmer rises into a bigger horn fanfare with a magic raised fourth in the bells, a warm pad, and a second wave of sparkles falling at the end (no voices) | P1 |
| `jingleRainbow` | Moments | your own big pull of a rainbow cat (SecuredRare's `variant`, F99), whatever its rarity | 2D, ducks | 4.2 s | a glissando climbs two octaves, lands on a big chord whose bells are doubled a hair apart so they shimmer, and a sparkle falls down the scale | P1 |
| `jingleLuckyDay` | Moments | the Clock's `LuckyDay` turns true (F88), 3.4 s later so it follows the sunrise sting | 2D, ducks | 2.6 s | a sprinkle of coins climbs into a warm vibraphone run, a small bright bell rings twice like the Lucky Cat's waving paw, a gold chord settles | P1 |
| `rainbowNear` | World | a rainbow stray (its `Variant` "rainbow") within 30 studs, once until you have been 45 studs away, as `rareNear` (which it replaces for that cat) | 3D on the cat, 50 studs | 1.6 s | six bright twinkles climb, one per colour of the coat, over a breath of shimmering air | P1 |
| `bellhopBell` | World | Beats `bellRing`: the Bellhop Cat's ring animation, on its stand in the plaza or as a greeter (F96), from its bell Model `<cat>_Bell` (PR #708; the stand's is `CatCafe_Street_BellhopStand_Cat_Bell`) | 3D, 30 studs | 1.0 s | ting-a-ling: a small brass collar bell swung once and twice more, with a soft jingle; quiet, since it rings every few seconds | P1 |
| `campSplash` | World | CampExtraCollect `pond`, and Beats `fishJump` and `rodCast` (F100) | 3D, 40 studs | 0.9 s | a bright plip, a friendly splash and a few droplets pattering back | P1 |
| `campBasket` | World | CampExtraCollect `picnic`, Beats `basketOpen` | 3D, 30 studs | 0.95 s | the wicker lid creaks open and drops back with a soft pat, two warm notes | P1 |
| `campRattle` | World | CampExtraCollect `lostFound`, Beats `lidRattle` (a prize waits) | 3D, 30 studs | 0.7 s | a cardboard thud and small knocks of odds and ends rattling inside | P1 |
| `rallyCheer` | Moments | the Rescue Rally bar reaches a step (F101): Audio follows the `RallyState` remote and cheers once per step crossed on the same lap, never on the first state after joining | 2D | 1.5 s | a party horn toots twice, a burst of clapping, a confetti popper and a bright three-note rise (no voices) | P1 |
| `uiReelTick` | Moments | a tile line crosses the crate reel's marker (F103, the reel's CrateReelTick moment; the cue keeps them at least 0.06 s apart) | 2D | 0.04 s | a soft dry tick: a whirr at 15 a second, separate ticks as the reel slows | P1 |
| `uiReelStop` | Moments | the reel stops on the prize or is skipped (F103, CrateReelLanded); the rarity sting follows from Epic up once the moment passes the piece's rarity | 2D | 0.4 s | a wooden thunk as the strip settles into its slot, a small latch click | P1 |
| `uiTradeTick` | Moments | each second of the trade countdown (F102): Audio follows the `TradeState` remote's countdownEndsAt, and any new state, TradeDone or TradeEnded stops the rest | 2D | 0.18 s | a soft woodblock tock, calm so five in a row never nag | P1 |
| `uiTradeDone` | Moments | "Trade done!" between players (F102, the `TradeDone` remote; `uiTrade` stays the Cat Collector's) | 2D | 1.3 s | a paw shake (two soft pats), a light whoosh as the cats fly to the cat room, a celesta arpeggio and a warm chord | P1 |

A tame's BaitTame and its SecuredRare land together, so a sting within 4 s of another plays only if it is bigger (a rainbow's over the rarity's), and stops the first.

### 5.14 Rare decor (F89, luck-and-rare-moments.md 2c; 2026-11-02)

Each Legendary and Mythical furniture or decoration model has "a small sound when used". Used here means visited: a placed piece in any cafe (its model in the plot's `Decor` folder, by `DecorId`) plays its sound once as you walk within 12 studs and again only after you have been 24 studs away, like the rare stray twinkle, so it is never a loop. It plays at the piece's moving part once Model-Agent's rework names one (Logic.decorSound), else at the model. All seven are in a third sound sheet, `sheets/CatCafe_Sheet_Decor.ogg` (mono, 3D, 30 studs).

| Cue | Piece | Length | What it sounds like | P |
|---|---|---|---|---|
| `decorBlossomTree` | Blossom Tree (Mythical, Park), at `CatCafe_Decor_BlossomTree_Chime_Swing` | 2.4 s | a breeze sets the wind chime between the paper lanterns ringing, soft pentatonic tubes | P1 |
| `decorBathtubSofa` | Bathtub Sofa (Sewer), at `CatCafe_Decor_BathtubSofa_Duck_Bob` | 1.3 s | bath bubbles bloop up and the rubber duck squeaks twice | P1 |
| `decorHollowLog` | Hollow Log Booth (Woods), at `CatCafe_Decor_HollowLogBooth_Lantern_Swing` | 1.8 s | the lantern's little flame crackles and two crickets chirp | P1 |
| `decorIceCream` | Ice Cream Counter (Neighbourhood), at `CatCafe_Decor_IceCreamCounter_Sign_Spin` | 1.5 s | a scoop scrapes the tub, a soft plop, a four-note music box tune | P1 |
| `decorDuckFountain` | Duck Fountain (Park), at `CatCafe_Decor_DuckFountain_Ducklings_Spin` | 1.6 s | water burbling from the duck's beak, a few plips, one small squeak | P1 |
| `decorJukebox` | Retro Jukebox (Alleyway), at `CatCafe_Decor_RetroJukebox_Record_Spin` | 2.0 s | a coin drops in, the record clunks down, the needle crackles, a short bouncy organ riff | P1 |
| `decorCatTree` | Cat Tree Tower (Classic Crate), at `CatCafe_Decor_CatTreeTower_Toy1_Swing` (the toy on a string, cat height) | 1.3 s | claws rake the sisal post, the dangling toy's bell jingles, a paw lands on top | P1 |


### 5.15 The net swing (F93, catch-rework.md; 2026-11-02)

Derek's net swing replaces hold E: every character carries the net, a click smacks it down and the server judges where it lands 0.15 s later (NetSmackDelay). Section 5 of catch-rework.md gives the sound-designer the whoosh, the smack, each grade and each result word. The whoosh is `netSwing` and the grades are the circle sounds, all unchanged; the five new cues share a fourth sound sheet, `sheets/CatCafe_Sheet_Catch.ogg` (mono, one upload).

| Cue | Moment | Where | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `netSwing` then `netSmack` | NetSmackPress (your press), or NetSwung from another player (when their smack starts); the smack follows NetSmackDelay later | 3D on the swinger, 40 studs | 0.35 s | the mesh slaps down with a soft rustle, a padded thump on the ground and the hoop's light tok; cartoon soft, never a hit | P0 |
| `netBounce` | NetSwung with hit false, your own swing only | 3D on you | 0.5 s | the net springs back with a rubbery boing and taps down once more, a friendly miss | P1 |
| `strayHop` | a stray's `HopAt` (a near miss makes free strays within 12 studs hop away) | 3D on the cat, 40 studs | 0.5 s | a fur puff, the take-off scrabble and two soft paws landing; no voice | P1 |
| `wordGreat` | GREAT! (every circle Good or better), from `CatchResult` grades | 2D | 0.6 s | the word's pop and two warm marimba notes up a fifth, under the catch sparkle in its key | P1 |
| `wordExcellent` | EXCELLENT! (at least half Perfect), from `CatchResult` grades | 2D | 0.9 s | the pop and a quick four note vibes fanfare up the A major chord, a step below PURRFECT | P1 |

PURRFECT! keeps `purrfectChime` and "So close!" keeps `catchMiss`. A rescue zone that runs out (RescueZonePasses) sends a RescueResult with a paw lost, so it plays `rescueMiss` like a missed press with no change here.

### 5.16 Cats make the orders (F90, cats-make-orders.md; 2026-11-02)

A Barista cat makes each order at its station, the Waiter carries it on a head tray to the table, and in your own cafe Waiters and Greeters sweep the tip piles into a coin bag and drop it in the till. The spec asks the sound-designer for a pour, an oven ding, a tray clink and a coin sweep. They repeat with every order, so each is short, soft and 3D with a short range. The pour, ding, clink and the bag drop share the sixth sound sheet, `sheets/CatCafe_Sheet_Cafe.ogg` (mono, one upload); the sweep reuses `tipPile`'s file (coins scooped off a table), silent since F97, so it needs no upload.

| Cue | Moment | Where | Length | What it sounds like | P |
|---|---|---|---|---|---|
| `orderPour` | nothing since 2026-11-03 (#981); was OrderMaking with station "espresso" (the oven and counter work quietly under their puffs) | 3D on the Espresso model, 30 studs | 1.5 s | the pump's low hum, a thin stream filling a cup with its note rising and a few small bubbles, a little puff of steam | P2 |
| `orderDing` | OrderReady, every station, your own cafe only and at most one every 2 s (#981) | 3D on the station, 35 studs | 0.9 s | one strike of a small counter bell; the oven's is the lowest, a drink's a note up and the counter's two (`Logic.orderDingStep`) | P2 |
| `trayClink` | nothing since 2026-11-03 (Derek: "Plate noises and eating noises too loud honestly not even needed", #981); was OrderServed | 3D at the table, 30 studs | 0.3 s | a soft wooden tap and two small china clinks as the plate settles | P2 |
| `tipSweep` | nothing since 2026-11-03 (#981); was TipSwept, your own cafe | 3D at the table, 30 studs | 0.5 s | `tipPile`'s file: coins scooped off the table into the bag | P2 |
| `tipBank` | TipBanked, your own cafe | 3D at the till, 30 studs | 0.4 s | a cloth thump and a muffled jingle as the coin bag drops in the till | P2 |

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
| TeamRescue | rescueSpotId, rescuerUserId, helperUserId, position | F92: a helped rescue freed its cat, on both players' clients | the `TeamRescue` remote (engineer PR #763) |
| OrderMaking, OrderReady | plot, station ("espresso", "oven", "counter"), at (the Espresso or Oven model, or the Barista), seconds or the dish | F90: a Barista starts an order; it is ready (the "ding!"), in every cafe this client shows the making in | Controllers/CafeOrders (engineer PR #781) |
| OrderServed | customer, itemId, position | F90: the dish is set on the customer's table, as the heart pops | Controllers/CafeOrders |
| TipSwept, TipBanked | cat, position | F90, your own cafe: a Waiter or Greeter sweeps a tip pile into its bag; drops the bag in the till | Controllers/CafeOrders |
| CarryStart | catId, rarity | any successful catch or rescue | `CatchResult` or `RescueResult` success |
| CatDrop | position (your feet) | F45: the Drop button or G while carrying, on the press | UIController `dropCat` (PR #224) |
| Shove | role (shover, target, bystander), position (the target) | v0.5: a shove lands, on every nearby player's device (3D, so bystanders hear it from where it happened) | `ShoveResult` (engineer PR #139) |
| BumpLoose, BumpHeld | role (shover, target, bystander), position | after Shove, when the target was carrying: the cat drops, or it held on | the same `ShoveResult`; a stray with `Dropped` appears too |
| CheckIn; CatFound | none; catId, isNew | the carried cat goes into the cafe; it is checked in (the jingle plays only when `isNew` is not false) | ProfileSync `carrying` clears; `CatCaught` |
| BaitPlaced, BaitArrive, BaitTame, BaitLetGo, GoldReveal | | not needed since 2026-11-02: Audio follows ProfileSync's `bait` (section 5.4), and a gold cat in your arms plays from its `HeldCat` | |
| CatPlaced, CatSold | uid, role | the intent is accepted; CatPlaced also when a cat moves to another role | ProfileSync diff (CatPlaced in PR #224) |
| UnplaceCat | uid | a cat leaves its role, one per cat on Unequip All (Audio plays one sound) | ProfileSync diff (PR #224) |
| CatLevelUp | uid, level | v0.12 (F75): one of your cats reaches a new level | the `CatLevelUp` remote (server to the owner) |
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
| OfflineClaim | | not needed: the welcome back card's Claim plays `offlineClaim` through the UI's `playSound` | |
| Announce | text, rarity (optional) | a server shout-out arrives | `Announce` remote; rarity as a second argument lets the chime rise |
| CampCheckIn | userId, campId | F84: a carried cat is banked at a camp, on every client, just before the carrier's CheckIn | the `CampCheckIn` client event (hometown-cannon.md section 7) |

World loops need no moment: the world builder tags the part or model and Audio plays its loop while it exists: `CafeDoor` (each cafe's front door; its loop was removed with the ambience on 2026-10-27), `Fountain`, `FishTank`, `WorkingCat` (a cat at its station, awake or napping; only the nearest within 14 studs purrs, 3 until #981) and, until 2026-10-28, `Stray` (now a one-shot `rareNear` as you come near a Mythical stray). By day the nearest resting cafe cat within 14 studs purrs too (the Napping children of each Plot's `Cats`: a sitting one all day, a lying one while `Effects.isLoafing`). Strays need no moment either: the hiss and the sprint follow their `HissAt` and `FleeingUntil` attributes.

The tackle (v0.11, F74) needs no new moment: Audio follows each character's `TackleAt` and `TackleMissAt` (data-model section 13), and a hit still fires Shove. On a ShoveResult `miss` the controller should fire no Shove, or the boop would play on a miss too.

Design v0.8 and v0.9 need no new moment either. Audio follows the attributes data-model section 13 already defines: the `Clock` for the dusk bell (and the two stingers it always played), every character's `RushUntil` (getaway) and `CarryStartedAt` (pick up), and your own plot's `TipPiles`, `CollectorUntil` and `MysteryGiftAt` (tip piles, the two visitors), so they work for players nearby too and on a rejoin. The UI plays `uiCodeRedeem` and `uiError` from `CodeResult`, `giftOpen` from `MysteryGiftResult` (an unopened gift also clears at MysteryGiftKeepSeconds, so the attribute going to 0 is not an opening), `uiTrade` when a trade goes through and `potionDrink` when a potion is drunk.

The Cat Cannon (F84) adds one moment, CampCheckIn, and otherwise follows attributes: every character's `CannonLaunchAt` (hometown-cannon.md section 7) times the launch, the clouds and the landing, checking the attribute is still the same launch before each, and your own `CloudHopAt` plays the cloud hop (the night sweep has no Travel). A Travel plays the cloud hop instead of the poof while you are in a wild area (`Logic.inWild`: farther than half of `Config.World.WildAreaDistance` from the town's centre) or your hop has just started, except for the Cannon button (`cannon`), which always poofs (`Logic.travelCue`), and the door bell stays quiet in a wild area and just after a camp check-in.

The release batch (section 5.13) adds one moment and one client signal. **CampExtraCollect** `(extraId, position)`: the Gameplay-Engineer fires it on the collecting client when the server confirms a CollectCampExtra (picnic, pond or lostFound). **Beats** (`src/client/Audio/Beats.luau`, `Beats.hit:Fire(beat, at)`): Effects fires it on the frame an animation's sound lands, `bellRing` for the Bellhop Cat, `fishJump`, `rodCast`, `basketOpen` and `lidRattle` for the camp extras, with the part, attachment or point it comes from. Audio follows the rest itself: the `SecuredRare` remote for your own big pull's sting (hooked when it appears, like Effects' Pull), the Clock's `LuckyDay` attribute and each stray's `Variant`. Since 2026-11-02 Audio also plays `uiReelTick` and `uiReelStop` from the crate reel's CrateReelTick and CrateReelLanded (then `jingleEpic`, `jingleLegendary` or `jingleMythical` by the piece's rarity, which UI PR #892 passes), the trade countdown's `uiTradeTick` and `uiTradeDone` from the `TradeState` and `TradeDone` remotes and `rallyCheer` from `RallyState`; the UI plays none of them. Audio hooks ProfileSync, TradeState and RallyState only after the first ProfileSync, when every controller listens: a remote fired before anything listens keeps its events for the first listener alone.

The net swing (section 5.15) uses the Gameplay-Engineer's two new moments from `Controllers/NetSwingController.luau` (PR #667): **NetSmackPress** `()` on your own screen at the press, before the server hears of it, and **NetSwung** `(userId, hit)` on every client within 150 studs when the server has judged a swing. Audio plays your own whoosh and smack from NetSmackPress, another player's from NetSwung, and your own miss bounce from NetSwung. A stray's `HopAt` attribute plays its hop, and the result words come from the grades in the `CatchResult` remote itself (`Logic.catchWord`), so they need no moment.

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
11. The 2026-10-27 batch: hold E on a stray (a rising whirr that pops as the circles come; let go early and it fades), each circle pips as it appears, press G while carrying (a mrrp and soft paws), walk into the Alleyway and back (a playful pluck in, a calm chord out), press My Cafe (a poof), put a cat to work in the Staff tab and press Unequip All (a happy hop, one sleepy sigh), claim a Tip Jar gift, drag a volume slider (ticks at the new volume) and force a gold stray with the Debug tools (it twinkles nearby and plays the gold reveal when caught).

## 9. Open questions for Derek and Gavin

1. Does anyone have a cat we can record? Real meows and purrs from our own cats are original, free and the best way to make the cats feel alive. A phone in a quiet room is enough.
2. Which account uploads audio: Derek's, or a Roblox Group that will own the game? Uploaded audio is private to its owner, so this decides the permissions work.
3. Is Derek's Roblox account ID-verified? It raises the audio upload quota from 100 to 2,000 per 30 days; not urgent for the slice.
4. Music: OK to use Creator Store licensed tracks for the slice (free, Roblox-only), and decide on original music later for trailers?
5. Answered by design v0.5: a shove must never feel like an attack (effects list section 5), so the shove is a whoosh into a soft boop.
6. Should you hear other players' circle grades and catches nearby, or only your own plus the announcement chime? The slice plan is your own only.

Proposed for docs/decisions.md: the v0.3 moment names in section 6, shared with the vfx-animator.
