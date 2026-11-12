--!strict
-- Every sound Cat Cafe can play, by cue id (docs/audio/cat-cafe/sound-list.md). The only place asset ids live.
-- A cue with no ids yet is silent and never an error, so code can play every cue from day one.
-- Pure: no Roblox services, so tests can require it.
--
-- ids      "rbxassetid://..." strings; more than one picks a random variant per play
-- group    SoundGroup channel: Music, Ambience, Sfx or Ui (sound list section 2)
-- volume   the Sound's own Volume, before the channel's
-- pitch    { min, max } random PlaybackSpeed per play
-- minGap   seconds; a play sooner than this after the last one is dropped
-- voices   pooled Sounds; when all are busy the oldest restarts
-- preload  loaded at startup (about ten cues; everything else loads on first play)
-- looped   plays until stopped (Audio.loop, music and ambience beds)
-- range    studs at which a 3D play fades out (RollOffMaxDistance)
-- duck     ducks the music bed to 40 % while it plays
-- sheet    a sound sheet's cue (sheetWorld, sheetMoments): the file is the sheet's, and this cue plays only its
--          `region`, { start, stop } in seconds of that file (sound list section 5.13). Its own ids stay empty.
-- seconds  a song's length (music cues): with `sections`, where a play may start and how long it lasts
-- sections the equal parts a song is made of (its 8 bar phrases); a play starts at one of them

export type Group = "Music" | "Ambience" | "Sfx" | "Ui"

export type Cue = {
	ids: { string },
	group: Group,
	volume: number,
	pitch: { number }?,
	minGap: number?,
	voices: number?,
	preload: boolean?,
	looped: boolean?,
	range: number?,
	duck: boolean?,
	sheet: string?,
	region: { number }?,
	seconds: number?,
	sections: number?,
}

local Cues: { [string]: Cue } = {
	-- Music (sound list section 3) -------------------------------------------------------------------------
	-- Songs play half their length from one of their four 8 bar sections, then rest (Audio refreshMusic).
	musicDayA = {
		ids = { "rbxassetid://83352686708210" },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 87.273, -- 32 bars at 88 BPM
		sections = 4,
	}, -- "Open for Business"
	musicDayB = {
		ids = { "rbxassetid://105502030061552" },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 91.429, -- 32 bars at 84 BPM
		sections = 4,
	}, -- "Second Cup"
	musicNightA = {
		ids = { "rbxassetid://104937902594770" },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 80, -- 32 bars of 3/4 at 72 BPM
		sections = 4,
	}, -- "After Hours"
	-- #980 (Derek OK'd them 2026-11-03): three more songs in one upload, the Music sheet. Each plays its own region of
	-- it; silent (not in the rotation) until sheetMusic has an id. Rendered by synth/music.py, which prints the regions.
	sheetMusic = {
		ids = { "rbxassetid://101914371530807" },
		group = "Music",
		volume = 0.3,
	}, -- stereo, 244.5 s: Paw Prints, Market Morning, Night Owls with 0.5 s of silence between
	musicDayC = {
		ids = {},
		sheet = "sheetMusic",
		region = { 0.000, 73.846 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 73.846, -- 32 bars at 104 BPM
		sections = 4,
	}, -- "Paw Prints"
	musicDayD = {
		ids = {},
		sheet = "sheetMusic",
		region = { 74.346, 142.918 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 68.571, -- 32 bars at 112 BPM
		sections = 4,
	}, -- "Market Morning"
	musicNightB = {
		ids = {},
		sheet = "sheetMusic",
		region = { 143.418, 244.470 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 101.053, -- 32 bars at 76 BPM
		sections = 4,
	}, -- "Night Owls"
	-- #1168 row 2 (2026-11-06): the Jukebox Pass's four cafe songs, in one upload like the Music sheet. A pass owner's
	-- pick plays in place of the day and night rotation (Audio.setJukebox); silent until sheetMusicJukebox has an id.
	-- Rendered by synth/music.py, which prints the regions. Each name matches its shared/Jukebox track `cue`.
	sheetMusicJukebox = {
		ids = { "rbxassetid://119723228198008" },
		group = "Music",
		volume = 0.3,
	}, -- stereo, 189.5 s: Rainy Window, Catnap Waltz, Bakery Bounce, Starlight Purr with 0.5 s of silence between
	musicJukeboxRainyWindow = {
		ids = {},
		sheet = "sheetMusicJukebox",
		region = { 0.000, 60.000 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 60.000, -- 16 bars at 64 BPM
	}, -- "Rainy Window"
	musicJukeboxCatnapWaltz = {
		ids = {},
		sheet = "sheetMusicJukebox",
		region = { 60.500, 94.786 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 34.286, -- 16 bars of 3/4 at 84 BPM
	}, -- "Catnap Waltz"
	musicJukeboxBakeryBounce = {
		ids = {},
		sheet = "sheetMusicJukebox",
		region = { 95.286, 130.841 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 35.556, -- 16 bars at 108 BPM
	}, -- "Bakery Bounce"
	musicJukeboxStarlightPurr = {
		ids = {},
		sheet = "sheetMusicJukebox",
		region = { 131.341, 189.523 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 58.182, -- 16 bars at 66 BPM
	}, -- "Starlight Purr"
	-- #2651 (Tier 6 and 7): each late area has its own song, played in place of the cafe music while you are in it
	-- (Audio.setZone, Logic.areaSongFor). Both share one upload, the MusicAreas sheet; uploaded by upload-audio run
	-- 42576766940 (group). Rendered by synth/music.py, which prints the regions.
	sheetMusicAreas = {
		ids = { "rbxassetid://133058435990072" },
		group = "Music",
		volume = 0.3,
	}, -- stereo, 179.2 s: Sunstone Caravan, Glyph Halls with 0.5 s of silence between
	musicAreaDesert = {
		ids = {},
		sheet = "sheetMusicAreas",
		region = { 0.000, 87.273 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 87.273, -- 32 bars at 88 BPM
		sections = 4,
	}, -- "Sunstone Caravan" (the Desert, Tier 6)
	musicAreaRuins = {
		ids = {},
		sheet = "sheetMusicAreas",
		region = { 87.773, 179.201 },
		group = "Music",
		volume = 0.3,
		looped = true,
		seconds = 91.429, -- 32 bars at 84 BPM
		sections = 4,
	}, -- "Glyph Halls" (the Ruins, Tier 7)
	-- 2026-11-05 (#1541, Derek): the tutorial plays its own calm song instead of the day and night songs, from the intro
	-- cutscene and through the first tutorial steps, until it is skipped or done. Uploaded by upload-audio run
	-- 42068848366.
	musicTutorial = {
		ids = { "rbxassetid://112232482675173" },
		group = "Music",
		volume = 0.18, -- Derek 2026-11-06 (#1793): a little loud under the tutorial text, so lower than the day songs (0.3)
		looped = true,
		seconds = 40, -- 16 bars at 96 BPM
	}, -- "Step by Step"
	stingDusk = {
		ids = { "rbxassetid://110881711300369" },
		group = "Music",
		volume = 0.6,
		duck = true,
	}, -- "Night Shift"
	stingDawn = {
		ids = { "rbxassetid://105006150455225" },
		group = "Music",
		volume = 0.6,
		duck = true,
	}, -- "Fresh Pot"
	jingleCatFound = {
		ids = { "rbxassetid://118123593035931" },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		preload = true,
	},
	jingleRare = { ids = {}, group = "Music", volume = 0.6, minGap = 1 },
	-- F89: one sting per rarity from Epic up, at the catch and on your own big pull; the crate reel's stop plays
	-- them too (the UI). Rainbow (F99) has its own on the big pull. All five live in sheetMoments.
	jingleEpic = {
		ids = {},
		sheet = "sheetMoments",
		region = { 0.000, 1.500 },
		group = "Music",
		volume = 0.65,
		minGap = 1,
	},
	jingleLegendary = {
		ids = {},
		sheet = "sheetMoments",
		region = { 2.000, 5.000 },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		duck = true,
	},
	jingleMythical = {
		ids = {},
		sheet = "sheetMoments",
		region = { 5.500, 9.500 },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		duck = true,
	},
	-- #3470: a Secret catch. No file of its own yet: the Mythical fanfare three semitones lower, so it lands
	-- deeper and a little slower (about 4.8 s).
	jingleSecret = {
		ids = {},
		sheet = "sheetMoments",
		region = { 5.500, 9.500 },
		group = "Music",
		volume = 0.75,
		pitch = { 0.84, 0.84 },
		minGap = 1,
		duck = true,
		range = 8,
	},
	jingleRainbow = {
		ids = {},
		sheet = "sheetMoments",
		region = { 10.000, 14.200 },
		group = "Music",
		volume = 0.75,
		minGap = 1,
		duck = true,
	},
	jingleLuckyDay = {
		ids = {},
		sheet = "sheetMoments",
		region = { 14.700, 17.300 },
		group = "Music",
		volume = 0.6,
		minGap = 5,
		duck = true,
	}, -- F88: a Lucky Day starts, after the sunrise sting
	jingleRankUp = {
		ids = { "rbxassetid://85819178163551" },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		duck = true,
	},
	jingleDailyCard = {
		ids = { "rbxassetid://138202971136133" },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		duck = true,
	}, -- F70: day 7 fills the Daily Treat card; the UI plays it instead of uiDailyStamp, its own stamp included

	-- Ambience beds by zone and phase, and 3D world loops (section 4) ---------------------------------------
	-- Derek 2026-10-27: no ambience beds or cafe door loop, the quiet music plays instead; their files were
	-- removed, so these stay silent unless a bed comes back.
	ambCafeDay = { ids = {}, group = "Ambience", volume = 0.4, looped = true },
	ambCafeNight = { ids = {}, group = "Ambience", volume = 0.3, looped = true }, -- v0.5: the closed cafe, cats asleep
	ambAlleyDay = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	ambAlleyNight = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	ambParkDay = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	ambParkNight = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	ambNeighbourhood = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	ambWoods = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	ambSewer = { ids = {}, group = "Ambience", volume = 0.5, looped = true },
	loopFountain = { ids = {}, group = "Ambience", volume = 0.5, looped = true, range = 30 },
	loopStreetLamp = { ids = {}, group = "Ambience", volume = 0.3, looped = true, range = 15 },
	loopDealerCart = { ids = {}, group = "Ambience", volume = 0.6, looped = true, range = 25 },
	loopFishTank = { ids = {}, group = "Ambience", volume = 0.4, looped = true, range = 10 },
	loopCafeDoor = { ids = {}, group = "Ambience", volume = 0.7, looped = true, range = 30 }, -- tag CafeDoor
	loopEspresso = { ids = {}, group = "Ambience", volume = 0.4, range = 15 },

	-- Net: closing circles (5.1) ----------------------------------------------------------------------------
	holdFill = {
		ids = { "rbxassetid://102979949179030" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.1,
		voices = 1,
	}, -- F45: hold E; one voice (Audio's fade relies on it)
	catchStart = { ids = { "rbxassetid://96760734642727" }, group = "Sfx", volume = 0.6 },
	circleAppear = {
		ids = { "rbxassetid://103026194958680" },
		group = "Sfx",
		volume = 0.5,
		voices = 2,
	}, -- played one scale step per circle
	circleClose = { ids = {}, group = "Sfx", volume = 0.3, voices = 2 },
	netSwing = {
		ids = { "rbxassetid://70879520668287" },
		group = "Sfx",
		volume = 0.8,
		pitch = { 0.96, 1.04 },
		minGap = 0.1,
		voices = 2,
		preload = true,
	},
	circlePerfect = {
		ids = { "rbxassetid://126376086540474" },
		group = "Sfx",
		volume = 0.8,
		voices = 2,
		preload = true,
	}, -- one scale step per circle
	circleGood = {
		ids = { "rbxassetid://93601709619890" },
		group = "Sfx",
		volume = 0.7,
		voices = 2,
		preload = true,
	}, -- one scale step per circle
	circleMiss = {
		ids = { "rbxassetid://109577366461065" },
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		voices = 2,
		preload = true,
	},
	catchSparkle = {
		ids = { "rbxassetid://91641836065515" },
		group = "Sfx",
		volume = 0.8,
		preload = true,
	},
	catchMiss = {
		ids = { "rbxassetid://119698339547500" },
		group = "Sfx",
		volume = 0.7,
		preload = true,
	},
	catHiss = {
		ids = { "rbxassetid://112692442470029" },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		range = 40,
	}, -- v0.4: a Miss ends the catch
	pawLost = { ids = { "rbxassetid://115646034851877" }, group = "Sfx", volume = 0.6 }, -- v0.4; retired by F40 (no paws), kept for its upload record
	purrfectChime = {
		ids = { "rbxassetid://101827371438540" },
		group = "Sfx",
		volume = 0.8,
		minGap = 1,
		preload = true,
	},
	strayFlee = {
		ids = { "rbxassetid://114582331349747" },
		group = "Sfx",
		volume = 0.8,
		pitch = { 0.95, 1.05 },
		range = 40,
	},
	straySprint = {
		ids = { "rbxassetid://90925740178919" },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.08 },
		range = 50,
	}, -- v0.5 F40

	-- Rescue minigames (5.2) and F92 Team Rescue: all in the Rescue sheet (2026-11-02; silent until then) -----------
	sheetRescue = {
		ids = { "rbxassetid://112281216042656" },
		group = "Sfx",
		volume = 1,
		preload = true,
	}, -- mono: the trap hits and the drop play in 3D on the trap, the rest flat
	rescueStart = {
		ids = {},
		sheet = "sheetRescue",
		region = { 0.000, 0.500 },
		group = "Sfx",
		volume = 0.6,
	}, -- a muffled "mew?" from inside the trap and a small ready chime
	rescueHitBin = {
		ids = {},
		sheet = "sheetRescue",
		region = { 1.000, 1.320 },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	}, -- the bin's tinny lid lifting and rattling down
	rescueHitBag = {
		ids = {},
		sheet = "sheetRescue",
		region = { 1.820, 2.120 },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	}, -- a plastic rustle and crinkle
	rescueHitTree = {
		ids = {},
		sheet = "sheetRescue",
		region = { 2.620, 3.020 },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	}, -- the branch shake: leaves in quick waves over a soft creak
	rescueHitCan = {
		ids = {},
		sheet = "sheetRescue",
		region = { 3.520, 3.870 },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	}, -- a soft, round clang on the park can
	rescueHitTone = {
		ids = {},
		sheet = "sheetRescue",
		region = { 4.370, 4.520 },
		group = "Sfx",
		volume = 0.5,
		voices = 2,
	}, -- a C5 pip, one scale step per hit (C5 to D6 over 7 hits)
	rescueMiss = {
		ids = {},
		sheet = "sheetRescue",
		region = { 5.020, 5.280 },
		group = "Sfx",
		volume = 0.6,
	}, -- a soft dropping boop and a paw-print tick
	rescueDrop = {
		ids = {},
		sheet = "sheetRescue",
		region = { 5.780, 6.200 },
		group = "Sfx",
		volume = 0.8,
		range = 30,
	}, -- a leafy whoosh down and a surprised "mew!"
	rescueFail = {
		ids = {},
		sheet = "sheetRescue",
		region = { 6.700, 7.200 },
		group = "Sfx",
		volume = 0.6,
	}, -- a gentle "aww": two felt notes leaning down
	rescueDone = {
		ids = {},
		sheet = "sheetRescue",
		region = { 7.700, 8.800 },
		group = "Sfx",
		volume = 0.8,
	}, -- a warm vibes chime up the C chord and a grateful purr-meow
	teamRescue = {
		ids = {},
		sheet = "sheetRescue",
		region = { 9.300, 10.100 },
		group = "Sfx",
		volume = 0.6,
		minGap = 1,
	}, -- F92: a high-five clap and two bright notes (G6, C7) over rescueDone, on both friends' screens

	-- Carry, shoves and check-in (5.3; v0.5 Shove keeps the Bump names in code) ------------------------------
	carryPurr = {
		ids = { "rbxassetid://122312250965460" },
		group = "Sfx",
		volume = 0.33,
		looped = true,
	}, -- Derek 2026-10-28: purring a little louder (both purrs about 2.5 dB up)
	shove = {
		ids = { "rbxassetid://108455272441129" },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		minGap = 0.2,
		range = 40,
	},
	bumpLoose = { -- the StrayFlee file: a startled mrrp and paws scurrying off
		ids = { "rbxassetid://114582331349747" },
		group = "Sfx",
		volume = 0.8,
		pitch = { 1.0, 1.1 },
		range = 40,
	},
	bumpHeld = { ids = { "rbxassetid://74229186579543" }, group = "Sfx", volume = 0.7, range = 40 },
	tackleLunge = {
		ids = { "rbxassetid://131297265053036" },
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.95, 1.05 },
		range = 40,
	}, -- F74: the dive's whoosh on the press; a hit adds the shove sound, a miss tackleMiss
	tackleMiss = {
		ids = { "rbxassetid://90894734407033" },
		group = "Sfx",
		volume = 0.7,
		range = 40,
	}, -- F74: belly flop, skid, "bonk bonk"
	checkInBell = {
		ids = { "rbxassetid://124730012199621" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.5,
		range = 40,
		preload = true,
	},
	catDrop = {
		ids = { "rbxassetid://82672663045710" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.5,
		range = 40,
	}, -- F45: Drop or G
	catPickUp = {
		ids = { "rbxassetid://109834386589176" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.3,
		range = 40,
	}, -- F56: a carry starts (pick up)
	getaway = {
		ids = { "rbxassetid://138475700063366" },
		group = "Sfx",
		volume = 0.7,
		minGap = 1,
		range = 40,
	}, -- F55: a catch pushes the crowd back
	shiftChime = {
		ids = { "rbxassetid://93382811999608" },
		group = "Sfx",
		volume = 0.3,
		minGap = 2,
		range = 40,
	}, -- #1191: a shop-only cat starts its shift, a soft three-note celesta lift (under VFX's sparkle, #1259)
	stationReady = {
		ids = { "rbxassetid://122405628888661" },
		group = "Sfx",
		volume = 0.3,
		minGap = 3,
	}, -- #1133/#1154/#1232: a camp station has something to collect, a soft two-note glockenspiel (2D, no id until uploaded)
	catPlaced = {
		ids = { "rbxassetid://112209746211990" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.15,
	}, -- a cat starts a role (Staff tab)
	catRest = {
		ids = { "rbxassetid://100485229755444" },
		group = "Sfx",
		volume = 0.55,
		minGap = 0.3,
	}, -- a cat leaves its role; Unequip All plays one
	catSold = { ids = { "rbxassetid://74026102899667" }, group = "Sfx", volume = 0.6 }, -- #2952, run 42830310860 (group)
	strayCall = {
		ids = { "rbxassetid://115966888994390" },
		group = "Sfx",
		volume = 0.55,
		minGap = 2,
		range = 60,
	}, -- #3022, run 42858357100 (group)
	arcadeStart = {
		ids = { "rbxassetid://106809535338101" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.3,
	}, -- #3062: a golden fish into the cabinet
	arcadeMilestone = {
		ids = { "rbxassetid://123235784633608" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.3,
	}, -- #3062: every 10 circles of a streak
	arcadeEnd = {
		ids = { "rbxassetid://102143051757899" },
		group = "Sfx",
		volume = 0.45,
		minGap = 0.5,
	}, -- #3062: a run ends, "nice try"

	-- Bait bowl (5.4) ---------------------------------------------------------------------------------------
	-- 2026-11-02: reused files until the upload quota allows the bowl its own (Derek: "continue with sounds needed to
	-- be added"). Every food plays foodDealer until its own cue has a file. 2026-11-03 (#981), Derek: "the cat cafe
	-- bait and claim re-use ding is way too loud": the reused bowl and claim sounds play at half their volume.
	-- #983: each food's own sound in the Bait sheet (synth.py SHEETS); until sheetBait has an id they fall back to
	-- foodDealer (Logic.foodCue). Soft on purpose: the bowl fills often.
	sheetBait = {
		ids = { "rbxassetid://100201013800031" },
		group = "Sfx",
		volume = 1,
	}, -- mono, 8.85 s: the seven foods and the claim
	foodKibble = {
		ids = {},
		sheet = "sheetBait",
		region = { 0.000, 0.550 },
		group = "Sfx",
		volume = 0.35,
		minGap = 0.3,
		range = 30,
	}, -- dry pellets rattling into a ceramic bowl
	foodTuna = {
		ids = {},
		sheet = "sheetBait",
		region = { 1.050, 1.600 },
		group = "Sfx",
		volume = 0.35,
		minGap = 0.3,
		range = 30,
	}, -- a can's ring-pull pops, a soft plop
	foodSalmon = {
		ids = {},
		sheet = "sheetBait",
		region = { 2.100, 2.600 },
		group = "Sfx",
		volume = 0.35,
		minGap = 0.3,
		range = 30,
	}, -- a juicier slap of fish settling in the bowl
	foodSardines = {
		ids = {},
		sheet = "sheetBait",
		region = { 3.100, 3.700 },
		group = "Sfx",
		volume = 0.35,
		minGap = 0.3,
		range = 30,
	}, -- a tin lid peeled back, two small plops
	foodCaviar = {
		ids = {},
		sheet = "sheetBait",
		region = { 4.200, 4.800 },
		group = "Sfx",
		volume = 0.22,
		minGap = 0.3,
		range = 30,
	}, -- tiny glassy pearls and one crystal tink
	foodMoonMilk = {
		ids = {},
		sheet = "sheetBait",
		region = { 5.300, 6.000 },
		group = "Sfx",
		volume = 0.3,
		minGap = 0.3,
		range = 30,
	}, -- a creamy pour and a silvery shimmer
	foodStarTreat = {
		ids = {},
		sheet = "sheetBait",
		region = { 6.500, 7.250 },
		group = "Sfx",
		volume = 0.25,
		minGap = 0.3,
		range = 30,
	}, -- a crisp crunch and a three-note star twinkle
	foodDealer = {
		ids = {},
		sheet = "sheetCafe",
		region = { 3.400, 3.680 },
		group = "Sfx",
		volume = 0.22,
		minGap = 0.3,
		range = 30,
	}, -- the trayClink part: a soft tap and two china clinks as the food goes in the bowl
	baitArrive = {
		ids = { "rbxassetid://112209746211990" },
		group = "Sfx",
		volume = 0.3,
		minGap = 1,
	}, -- the catPlaced file: a hop, a happy mrrp and sparkles
	baitTame = { ids = {}, group = "Sfx", volume = 0.7 }, -- unused: a tame sounds with its check-in (bell, jingle, sting)
	baitLetGo = {
		ids = { "rbxassetid://82672663045710" },
		group = "Sfx",
		volume = 0.3,
		minGap = 1,
	}, -- the catDrop file: a mrrp, soft paws and a shake

	-- Cats in the world (5.5) -------------------------------------------------------------------------------
	meow = {
		ids = {},
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.92, 1.08 },
		minGap = 0.4,
		voices = 2,
		range = 40,
	},
	purr = {
		ids = { "rbxassetid://98395715075799" },
		group = "Sfx",
		volume = 0.27,
		looped = true,
		range = 8,
	},
	rareNear = {
		ids = { "rbxassetid://134220486232962" },
		group = "Sfx",
		volume = 0.35,
		minGap = 3,
		range = 40,
	}, -- once as you come near a Mythical stray (was the shimmerRare loop, retired 2026-10-28)
	secretNear = {
		ids = { "rbxassetid://134220486232962" },
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.74, 0.76 },
		minGap = 3,
		range = 50,
	}, -- #3470: the same, for a Secret stray: rareNear's twinkle a fourth lower, heard from a little further
	goldReveal = {
		ids = { "rbxassetid://134771896552643" },
		group = "Sfx",
		volume = 0.8,
		minGap = 1,
		duck = true,
	}, -- F42: was shinyReveal

	-- Zones and travel (5.9) --------------------------------------------------------------------------------
	zoneSafe = { ids = { "rbxassetid://102307932367391" }, group = "Sfx", volume = 0.45 }, -- back on the safe street; silent since 2026-11-02 (UI PR #669), kept for its upload record
	zoneArea = { ids = { "rbxassetid://122475758992868" }, group = "Sfx", volume = 0.45 }, -- into a catching area; silent since 2026-11-02 (UI PR #669), kept for its upload record
	travelPoof = {
		ids = { "rbxassetid://136895580073047" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.5,
	}, -- fast travel and My Cafe
	waterStep = {
		ids = { "rbxassetid://71465595506771" },
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.9, 1.12 },
		minGap = 0.1,
		range = 30,
		voices = 3,
	}, -- a player's step through water (Effects.Splash), quiet; cats' steps stay silent

	-- The Cat Cannon (F84, hometown-cannon.md 3b; Derek's yes 2026-10-28): the 3 s flight in three parts, so each
	-- plays where it happens: the launch at the barrel, the clouds for the one flying, the whistle and landing at the pad
	cannonLaunch = {
		ids = { "rbxassetid://102075028148467" },
		group = "Sfx",
		volume = 0.8,
		minGap = 0.3,
		range = 80,
		voices = 2,
	},
	cannonClouds = {
		ids = { "rbxassetid://108064008516131" },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
	},
	cannonLand = {
		ids = { "rbxassetid://103029343434588" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.3,
		range = 60,
		voices = 2,
	},
	cloudHop = {
		ids = { "rbxassetid://76704372473776" },
		group = "Sfx",
		volume = 0.55,
		minGap = 1,
	}, -- Home from a wild area, the night sweep
	campCheckIn = {
		ids = { "rbxassetid://79340353325458" },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
	}, -- a cat banked at a camp (CampCheckIn), not the door bell

	-- Rewards (5.10) ----------------------------------------------------------------------------------------
	-- Derek 2026-10-28: the dings on claiming were a little loud, so every claim sound (these two, offlineClaim,
	-- richTip, uiCodeRedeem and uiDailyStamp) is about 4 dB down, still well above the music.
	giftClaim = {
		ids = { "rbxassetid://74934447836735" },
		group = "Sfx",
		volume = 0.45,
		minGap = 0.2,
	}, -- F47 Tip Jar
	indexReward = {
		ids = { "rbxassetid://127241224294798" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.5,
		duck = true,
	}, -- F48 Index rewards
	stationReveal = {
		ids = { "rbxassetid://119242621398873" }, -- CatCafe_Sfx_StationReveal (group upload run 43101011410)
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
		duck = true,
	}, -- #2687: a new station builds in the first time you reach its area

	-- Coins, tiers and the night economy (5.6) --------------------------------------------------------------
	coinPop = {
		ids = { "rbxassetid://84089684524419" },
		group = "Sfx",
		volume = 0.2,
		pitch = { 0.94, 1.06 },
		minGap = 4,
		voices = 1,
		range = 40,
		preload = true,
	}, -- Derek 2026-11-03 (#981): "ding's are too loud and too often I think its the money pop up dings": half as loud, one every 4 s at most (each seated customer floats one every 3 s)
	purchase = {
		ids = { "rbxassetid://116389589868688" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.2,
		preload = true,
	},
	offlineClaim = {
		ids = {},
		sheet = "sheetBait",
		region = { 7.750, 8.850 },
		group = "Sfx",
		volume = 0.3,
		minGap = 1,
	}, -- #983 (2026-11-04): its own jingle, coins out of a cloth pouch and a soft two-note "welcome back" (the UI plays it on Claim)
	placeFurniture = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	gateOpen = { ids = { "rbxassetid://129683906883492" }, group = "Sfx", volume = 0.7, range = 60 }, -- v0.4: the barrier dissolves
	shuttersUp = {
		ids = { "rbxassetid://88936101264758" },
		group = "Sfx",
		volume = 0.7,
		range = 60,
	}, -- a For Rent plot becomes a cafe
	richArrive = { ids = { "rbxassetid://72229334389341" }, group = "Sfx", volume = 0.7 },
	richTip = { ids = { "rbxassetid://134978111441854" }, group = "Sfx", volume = 0.5 },
	tipPile = {
		ids = { "rbxassetid://131455934857825" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.3,
	}, -- F61: the tip piles were collected; silent since F97 (#714) pays them as they appear; F90 plays its file as tipSweep
	-- Quiet on purpose for now: the cart parks with the dusk stinger and leaves with the dawn one, which mark it.
	dealerArrive = { ids = {}, group = "Sfx", volume = 0.7, range = 60 },
	dealerLeave = { ids = {}, group = "Sfx", volume = 0.6, range = 60 },

	-- Clock (5.7) -------------------------------------------------------------------------------------------
	signFlip = { ids = { "rbxassetid://97178553934391" }, group = "Sfx", volume = 0.5, range = 30 },
	lampOn = {
		ids = {},
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.95, 1.05 },
		voices = 4,
		range = 20,
	},

	-- Visitors, codes and potions (5.11) -------------------------------------------------------------------
	visitorCollector = {
		ids = { "rbxassetid://79131004801316" },
		group = "Sfx",
		volume = 0.6,
		minGap = 2,
	}, -- F63: the Cat Collector comes by
	visitorMystery = {
		ids = { "rbxassetid://109251583263849" },
		group = "Sfx",
		volume = 0.6,
		minGap = 2,
	}, -- F64: the Mystery Visitor's gift appears
	giftOpen = {
		ids = { "rbxassetid://114143832834959" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.5,
	}, -- F64: the gift is opened
	potionDrink = {
		ids = { "rbxassetid://89037651167310" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.3,
	}, -- F64: the UI plays it on UsePotion
	catLevelUp = {
		ids = { "rbxassetid://75904013038713" },
		group = "Sfx",
		volume = 0.4,
		minGap = 1.5,
	}, -- F75: one of your cats levels up; silent since 2026-11-02 with its toast (UI PR #669), kept for its upload record

	-- UI (5.8) ----------------------------------------------------------------------------------------------
	uiClick = {
		ids = { "rbxassetid://123281023369868" },
		group = "Ui",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		minGap = 0.05,
		voices = 2,
		preload = true,
	},
	-- Derek 2026-11-03 (#981): "The noise of hittin a button you can't click is also a little loud and change it to
	-- something less annoying". The uiTab tick played lower, a dull "tuk", in place of the Error file's two falling
	-- notes (rbxassetid://100658806415053). The comment after the brace keeps upload.py from writing that id back.
	uiError = { -- the uiTab file, lower and softer
		ids = { "rbxassetid://132990737294484" },
		group = "Ui",
		volume = 0.45,
		pitch = { 0.78, 0.82 },
		minGap = 0.3,
		preload = true,
	},
	uiOpen = { ids = { "rbxassetid://137136098721051" }, group = "Ui", volume = 0.5, minGap = 0.1 },
	uiClose = { ids = { "rbxassetid://136390381178341" }, group = "Ui", volume = 0.5, minGap = 0.1 },
	uiDealerOpen = { ids = { "rbxassetid://76779738636330" }, group = "Ui", volume = 0.6 },
	uiRankReady = {
		ids = { "rbxassetid://125474672370745" },
		group = "Ui",
		volume = 0.6,
		minGap = 1,
	},
	-- #1541: a tutorial step done; the Rank Ready chime's file, so it needs no upload of its own.
	tutorialStepDone = {
		ids = { "rbxassetid://125474672370745" },
		group = "Ui",
		volume = 0.45,
		minGap = 1,
	},
	uiToast = { ids = { "rbxassetid://101668755145423" }, group = "Ui", volume = 0.5, minGap = 0.2 },
	uiHint = { ids = { "rbxassetid://84709734267357" }, group = "Ui", volume = 0.5, minGap = 0.5 },
	uiTab = { ids = { "rbxassetid://132990737294484" }, group = "Ui", volume = 0.4, minGap = 0.05 },
	uiFocus = {
		ids = { "rbxassetid://132990737294484" },
		group = "Ui",
		volume = 0.22,
		minGap = 0.06,
	}, -- #2871: the gamepad selection moves between buttons (the uiTab file, quieter)
	uiToggle = {
		ids = { "rbxassetid://87744600545017" },
		group = "Ui",
		volume = 0.5,
		minGap = 0.05,
	},
	uiRename = { ids = { "rbxassetid://126356996133307" }, group = "Ui", volume = 0.5 },
	uiSlider = {
		ids = { "rbxassetid://87070259611294" },
		group = "Ui",
		volume = 0.5,
		minGap = 0.03,
	}, -- a volume slider's 5 % step
	uiGiftReady = {
		ids = { "rbxassetid://107614584511698" },
		group = "Ui",
		volume = 0.6,
		minGap = 1,
	}, -- a Tip Jar gift is ready
	uiBadge = { ids = { "rbxassetid://127086916799354" }, group = "Ui", volume = 0.4, minGap = 0.5 }, -- a red dot turns on
	-- The Spin Wheel window (F49): it starts, a slice passes the pointer (can fire every frame early on), it lands
	uiSpinStart = {
		ids = { "rbxassetid://101675886953192" },
		group = "Ui",
		volume = 0.6,
		minGap = 0.5,
	},
	uiSpinTick = {
		ids = { "rbxassetid://133333553770736" },
		group = "Ui",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.04,
		voices = 2,
	},
	uiSpinWin = {
		ids = { "rbxassetid://79008493792613" },
		group = "Ui",
		volume = 0.7,
		minGap = 1,
		duck = true,
	},
	uiSpinBusy = {
		ids = { "rbxassetid://133956483226854" },
		group = "Ui",
		volume = 0.55,
		minGap = 0.3,
	}, -- the wheel can't spin yet: its own wooden "tok-tok", not uiError (Derek 2026-10-28: sounded like a disconnect)
	uiCodeRedeem = {
		ids = { "rbxassetid://139056960178897" },
		group = "Ui",
		volume = 0.45,
		minGap = 1,
	}, -- F65: a code worked (a wrong one is uiError)
	uiDailyStamp = {
		ids = { "rbxassetid://123343224842944" },
		group = "Ui",
		volume = 0.45,
		minGap = 1,
	}, -- F70: a Daily Treat stamp claimed, days 1 to 6 (the UI plays it)
	uiTrade = { ids = { "rbxassetid://87866050266126" }, group = "Ui", volume = 0.7, minGap = 1 }, -- F63: a trade with the Cat Collector
	announce = { ids = { "rbxassetid://132783050282387" }, group = "Ui", volume = 0.6, minGap = 1 },
	announceMythical = {
		ids = { "rbxassetid://95418238847080" },
		group = "Ui",
		volume = 0.7,
		minGap = 1,
		duck = true,
	}, -- F58: a Mythical shout-out

	-- Sound sheets (5.13) -----------------------------------------------------------------------------------
	-- The release batch shares two uploads (Roblox's 100 a month for an account without ID verification). A
	-- sheet's row holds the file and is never played itself; its parts are the cues that name it. Preloaded, so
	-- the first part to play is not late.
	sheetWorld = {
		ids = { "rbxassetid://73129093144324" },
		group = "Sfx",
		volume = 1,
		preload = true,
	}, -- mono, plays in 3D
	sheetMoments = {
		ids = { "rbxassetid://79195889382293" },
		group = "Music",
		volume = 1,
		preload = true,
	}, -- stereo, plays flat
	bellhopBell = {
		ids = {},
		sheet = "sheetWorld",
		region = { 0.000, 1.000 },
		group = "Sfx",
		volume = 0.35,
		minGap = 0.5,
		range = 30,
		voices = 2,
	}, -- F96: the Bellhop Cat rings its collar bell (Effects' Beats "bellRing", on the stand or as a greeter)
	rainbowNear = {
		ids = {},
		sheet = "sheetWorld",
		region = { 1.500, 3.100 },
		group = "Sfx",
		volume = 0.4,
		minGap = 3,
		range = 50,
	}, -- F99: once as you come near a rainbow stray (in place of rareNear for it)
	campSplash = {
		ids = {},
		sheet = "sheetWorld",
		region = { 3.600, 4.500 },
		group = "Sfx",
		volume = 0.55,
		minGap = 0.5,
		range = 40,
		voices = 2,
	}, -- F100: the Fish Pond, collected or a fish jumping
	campBasket = {
		ids = {},
		sheet = "sheetWorld",
		region = { 5.000, 5.950 },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.5,
		range = 30,
	}, -- F100: the Picnic Basket opened
	campRattle = {
		ids = {},
		sheet = "sheetWorld",
		region = { 6.450, 7.150 },
		group = "Sfx",
		volume = 0.4,
		minGap = 0.5,
		range = 30,
	}, -- F100: the Lost and Found box, collected or its lid rattling while a prize waits
	rallyCheer = {
		ids = {},
		sheet = "sheetMoments",
		region = { 17.800, 19.300 },
		group = "Ui",
		volume = 0.55,
		minGap = 1,
	}, -- F101: a Rescue Rally step reached (the UI's banner plays it)
	uiReelTick = {
		ids = {},
		sheet = "sheetMoments",
		region = { 19.800, 19.840 },
		group = "Ui",
		volume = 0.35,
		pitch = { 0.97, 1.03 },
		minGap = 0.06,
		voices = 2,
	}, -- F103: a tile line crosses the crate reel's marker; minGap 0.06 lets all 15 a second through as a whirr
	uiReelStop = {
		ids = {},
		sheet = "sheetMoments",
		region = { 20.340, 20.740 },
		group = "Ui",
		volume = 0.6,
		minGap = 0.3,
	}, -- F103: the reel stops on the prize; the rarity sting follows from Epic up
	uiTradeTick = {
		ids = {},
		sheet = "sheetMoments",
		region = { 21.240, 21.420 },
		group = "Ui",
		volume = 0.45,
		minGap = 0.5,
	}, -- F102: each second of the trade countdown
	uiTradeDone = {
		ids = {},
		sheet = "sheetMoments",
		region = { 21.920, 23.220 },
		group = "Ui",
		volume = 0.6,
		minGap = 1,
	}, -- F102: "Trade done!" between players (uiTrade stays the Cat Collector's)

	-- F89 rare decor (5.14): each Legendary and Mythical piece's small sound, once as you walk up to it
	sheetDecor = {
		ids = { "rbxassetid://108434963257406" },
		group = "Sfx",
		volume = 1,
		preload = true,
	}, -- mono, plays in 3D
	decorBlossomTree = {
		ids = {},
		sheet = "sheetDecor",
		region = { 0.000, 2.400 },
		group = "Sfx",
		volume = 0.45,
		minGap = 1,
		range = 30,
	}, -- the wind chime between its paper lanterns (Mythical)
	decorBathtubSofa = {
		ids = {},
		sheet = "sheetDecor",
		region = { 2.900, 4.200 },
		group = "Sfx",
		volume = 0.45,
		minGap = 1,
		range = 30,
	}, -- bath bubbles and the rubber duck's squeak
	decorHollowLog = {
		ids = {},
		sheet = "sheetDecor",
		region = { 4.700, 6.500 },
		group = "Sfx",
		volume = 0.6,
		minGap = 1,
		range = 30,
	}, -- the lantern's flame crackling and crickets
	decorIceCream = {
		ids = {},
		sheet = "sheetDecor",
		region = { 7.000, 8.500 },
		group = "Sfx",
		volume = 0.4,
		minGap = 1,
		range = 30,
	}, -- a scoop, a plop and a little music box tune
	decorDuckFountain = {
		ids = {},
		sheet = "sheetDecor",
		region = { 9.000, 10.600 },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
		range = 30,
	}, -- water burbling and one small squeak
	decorJukebox = {
		ids = {},
		sheet = "sheetDecor",
		region = { 11.100, 13.100 },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
		range = 30,
	}, -- a coin, the record dropping, the needle and a short organ riff
	decorCatTree = {
		ids = {},
		sheet = "sheetDecor",
		region = { 13.600, 14.900 },
		group = "Sfx",
		volume = 0.55,
		minGap = 1,
		range = 30,
	}, -- claws on the sisal post, the toy's bell and a paw landing

	-- F93 net swing (5.15): the whoosh is netSwing; the smack lands NetSmackDelay later, a miss bounces, a near miss
	-- makes a stray hop, and GREAT and EXCELLENT get their word (PURRFECT keeps purrfectChime, "So close!" catchMiss)
	sheetCatch = {
		ids = { "rbxassetid://110336837728633" },
		group = "Sfx",
		volume = 1,
		preload = true,
	}, -- mono, plays in 3D
	netSmack = {
		ids = {},
		sheet = "sheetCatch",
		region = { 0.000, 0.350 },
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.95, 1.05 },
		minGap = 0.05,
		voices = 3,
		range = 40,
	}, -- the net slapping down: mesh, a padded thump and the hoop's tok
	netBounce = {
		ids = {},
		sheet = "sheetCatch",
		region = { 0.850, 1.350 },
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.3,
		range = 30,
	}, -- your swing hit nothing: a rubbery boing and one more tap
	strayHop = {
		ids = {},
		sheet = "sheetCatch",
		region = { 1.850, 2.350 },
		group = "Sfx",
		volume = 0.75,
		pitch = { 0.94, 1.06 },
		minGap = 0.2,
		voices = 2,
		range = 40,
	}, -- a startled stray's fur puff, take-off scrabble and two paws landing (no voice)
	wordGreat = {
		ids = {},
		sheet = "sheetCatch",
		region = { 2.850, 3.450 },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
	}, -- GREAT!: the word's pop and two marimba notes
	wordExcellent = {
		ids = {},
		sheet = "sheetCatch",
		region = { 3.950, 4.850 },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
	}, -- EXCELLENT!: the pop and a four note vibes fanfare

	-- Catch v3 (#1884, catch-rework.md 7): the swat, the net's wobble and pop, and the NICE! word. The rising purr is
	-- the `purr` cue sped up with trust (Audio.setCatchTrust); ticks, hiss, GREAT, EXCELLENT and PURRFECT are the cues above.
	sheetCatch3 = {
		ids = { "rbxassetid://119641670692404" },
		group = "Sfx",
		volume = 1,
		preload = true,
	}, -- mono, plays in 3D; silent until uploaded
	pawSwat = {
		ids = {},
		sheet = "sheetCatch3",
		region = { 0.000, 0.400 },
		group = "Sfx",
		volume = 0.55,
		pitch = { 0.96, 1.04 },
		minGap = 0.2,
		range = 40,
	}, -- a paw ring was tapped: the cat bats at the net
	netWobble = {
		ids = {},
		sheet = "sheetCatch3",
		region = { 0.900, 1.600 },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
		range = 40,
	}, -- trust is full: the net wraps the cat and wobbles twice
	netPop = {
		ids = {},
		sheet = "sheetCatch3",
		region = { 2.100, 2.700 },
		group = "Sfx",
		volume = 0.55,
		minGap = 1,
		range = 40,
	}, -- the net pops open with confetti
	wordNice = {
		ids = {},
		sheet = "sheetCatch3",
		region = { 3.200, 3.700 },
		group = "Sfx",
		volume = 0.45,
		minGap = 1,
	}, -- NICE!: the pop and one marimba note

	-- The Mystic Pool's roll (#3389; Effects/MysticPool.onBeat, Logic.poolCue): the Pool sheet, mono. The drop, the
	-- steps and the Mythic play in 3D at the pool; the reveal is flat, under the trait card. Rendered by synth/synth.py.
	sheetPool = {
		ids = { "rbxassetid://86210298933711" },
		group = "Sfx",
		volume = 1,
	}, -- mono, 6.05 s; uploaded by upload-audio run 43113223077 (group)
	poolDrop = {
		ids = {},
		sheet = "sheetPool",
		region = { 0.000, 0.900 },
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		range = 60,
	}, -- the cat drops into the pool
	poolStep = {
		ids = {},
		sheet = "sheetPool",
		region = { 1.400, 1.850 },
		group = "Sfx",
		volume = 0.55,
		voices = 3,
		range = 60,
	}, -- one per colour step, a scale note higher each time
	poolReveal = {
		ids = {},
		sheet = "sheetPool",
		region = { 2.350, 3.650 },
		group = "Sfx",
		volume = 0.55,
		minGap = 0.5,
	}, -- the cat comes back with its trait
	poolMythic = {
		ids = {},
		sheet = "sheetPool",
		region = { 4.150, 6.050 },
		group = "Sfx",
		volume = 0.65,
		minGap = 1,
		range = 80,
		duck = true,
	}, -- the purple flash of a Mythic trait
	-- #3296 Mouse Dash, the second Cat Arcade game: eleven sounds on one sheet (synth/synth.py, parts in
	-- sheet-parts/sfx), all flat on the player's own screen. Milestones and the start reuse the arcade's own cues.
	sheetMouse = {
		ids = { "rbxassetid://74952684733332" },
		group = "Sfx",
		volume = 1,
	}, -- mono, 11.74 s; uploaded by upload-audio run 43121873618 (group)
	mousePop = {
		ids = {},
		sheet = "sheetMouse",
		region = { 0.000, 0.220 },
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.96, 1.04 },
		voices = 2,
	}, -- a mouse pops out of its hole
	mouseCatch = {
		ids = {},
		sheet = "sheetMouse",
		region = { 0.720, 1.120 },
		group = "Sfx",
		volume = 0.5,
		voices = 3,
	}, -- a mouse caught; a scale note higher per catch inside each 5 of a streak
	mouseGoldUp = {
		ids = {},
		sheet = "sheetMouse",
		region = { 1.620, 2.220 },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.2,
	}, -- the golden mouse pops up
	mouseGoldCatch = {
		ids = {},
		sheet = "sheetMouse",
		region = { 2.720, 3.570 },
		group = "Sfx",
		volume = 0.55,
		minGap = 0.2,
	}, -- the golden mouse caught, +3
	mouseDuck = {
		ids = {},
		sheet = "sheetMouse",
		region = { 4.070, 4.570 },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.2,
	}, -- a mouse ducks back in untapped
	mousePurr = {
		ids = {},
		sheet = "sheetMouse",
		region = { 5.070, 5.670 },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.3,
	}, -- the napping kitten is up; a quiet file, so a higher volume
	mouseMrow = {
		ids = {},
		sheet = "sheetMouse",
		region = { 6.170, 6.570 },
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.97, 1.05 },
		minGap = 0.3,
	}, -- the napping kitten tapped awake
	mouseThud = {
		ids = {},
		sheet = "sheetMouse",
		region = { 7.070, 7.420 },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.15,
	}, -- a tap on an empty hole
	mouseHeart = {
		ids = {},
		sheet = "sheetMouse",
		region = { 7.920, 8.720 },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.5,
	}, -- a heart won back after 10 catches in a row
	mouseFaster = {
		ids = {},
		sheet = "sheetMouse",
		region = { 9.220, 9.640 },
		group = "Sfx",
		volume = 0.45,
		minGap = 0.3,
	}, -- the speed step
	mouseBest = {
		ids = {},
		sheet = "sheetMouse",
		region = { 10.140, 11.740 },
		group = "Sfx",
		volume = 0.55,
		minGap = 1,
	}, -- a run ends on a new best, or is won
	-- The late stations (#2651 part 4, late-stations.md; #2927) and the first catch's held ring (#2920): the Late sheet,
	-- mono. A finished Museum room plays indexReward, the Index milestone fanfare. Rendered by synth/synth.py.
	sheetLate = {
		ids = { "rbxassetid://104681497739384" },
		group = "Sfx",
		volume = 1,
	}, -- mono, 6.3 s; uploaded by upload-audio run 42745669425 (group)
	spaSplash = {
		ids = {},
		sheet = "sheetLate",
		region = { 0.000, 1.000 },
		group = "Sfx",
		volume = 0.5,
		pitch = { 0.96, 1.04 },
		minGap = 0.5,
	}, -- a cat goes into the Oasis Spa's pool (your own SpaPut)
	spaChime = {
		ids = {},
		sheet = "sheetLate",
		region = { 1.500, 3.000 },
		group = "Sfx",
		volume = 0.5,
		minGap = 1,
	}, -- spa cats collected, each a level up (your own SpaCollect)
	museumBell = {
		ids = {},
		sheet = "sheetLate",
		region = { 3.500, 5.300 },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.5,
	}, -- a cat fills its Relic Museum exhibit (your own MuseumDonate)
	circleHold = {
		ids = {},
		sheet = "sheetLate",
		region = { 5.800, 6.300 },
		group = "Sfx",
		volume = 0.45,
		minGap = 1,
	}, -- the first catch's ring stops on the target: "now!" (moment CircleHold, from the Catch screen)

	-- F90 cats make the orders (5.16): the Cafe sheet, all 3D; they repeat with every order, so each is short and soft
	sheetCafe = {
		ids = { "rbxassetid://94516523486015" },
		group = "Sfx",
		volume = 1,
		preload = true,
	}, -- mono, plays in 3D
	orderPour = {
		ids = {},
		sheet = "sheetCafe",
		region = { 0.000, 1.500 },
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.96, 1.04 },
		minGap = 0.3,
		voices = 2,
		range = 30,
	}, -- the espresso pump's hum, a stream filling the cup and a puff of steam
	orderDing = {
		ids = {},
		sheet = "sheetCafe",
		region = { 2.000, 2.900 },
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.98, 1.02 },
		minGap = 2,
		voices = 2,
		range = 35,
	}, -- "ding!": one strike of a small counter bell, a note up for a drink and two for the counter; your own cafe only, one every 2 s at most (#981)
	trayClink = {
		ids = {},
		sheet = "sheetCafe",
		region = { 3.400, 3.680 },
		group = "Sfx",
		volume = 0.45,
		pitch = { 0.94, 1.06 },
		minGap = 0.15,
		voices = 2,
		range = 30,
	}, -- the dish set down: a wooden tap and two china clinks
	tipBank = {
		ids = {},
		sheet = "sheetCafe",
		region = { 4.180, 4.580 },
		group = "Sfx",
		volume = 0.4,
		minGap = 0.3,
		range = 30,
	}, -- the coin bag dropped in the till: a cloth thump and a muffled jingle
	tipSweep = { -- the tipPile file: coins scooped off a table into the Waiter's bag (your own cafe)
		ids = { "rbxassetid://131455934857825" },
		group = "Sfx",
		volume = 0.35,
		pitch = { 0.95, 1.05 },
		minGap = 0.3,
		range = 30,
	},
}

return Cues
