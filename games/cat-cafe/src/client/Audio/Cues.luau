--!strict
-- Every sound Purr Pot can play, by cue id (docs/audio/cat-cafe/sound-list.md). The only place asset ids live.
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
}

local Cues: { [string]: Cue } = {
	-- Music (sound list section 3) -------------------------------------------------------------------------
	musicDayA = { ids = {}, group = "Music", volume = 0.5, looped = true }, -- "Open for Business"
	musicDayB = { ids = {}, group = "Music", volume = 0.5, looped = true }, -- "Second Cup"
	musicNightA = { ids = {}, group = "Music", volume = 0.5, looped = true }, -- "After Hours"
	musicNightB = { ids = {}, group = "Music", volume = 0.5, looped = true }, -- "Night Owls"
	stingDusk = { ids = {}, group = "Music", volume = 0.6, duck = true }, -- "Night Shift"
	stingDawn = { ids = {}, group = "Music", volume = 0.6, duck = true }, -- "Fresh Pot"
	jingleCatFound = { ids = {}, group = "Music", volume = 0.7, minGap = 1, preload = true },
	jingleRare = { ids = {}, group = "Music", volume = 0.6, minGap = 1 },
	jingleEpic = { ids = {}, group = "Music", volume = 0.65, minGap = 1 },
	jingleLegendary = { ids = {}, group = "Music", volume = 0.7, minGap = 1, duck = true },
	jingleMythical = { ids = {}, group = "Music", volume = 0.7, minGap = 1, duck = true },
	jingleRankUp = { ids = {}, group = "Music", volume = 0.7, minGap = 1, duck = true },

	-- Ambience beds by zone and phase, and 3D world loops (section 4) ---------------------------------------
	ambCafeDay = { ids = {}, group = "Ambience", volume = 0.4, looped = true },
	ambCafeNight = { ids = {}, group = "Ambience", volume = 0.4, looped = true },
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
	loopEspresso = { ids = {}, group = "Ambience", volume = 0.4, range = 15 },

	-- Net: closing circles (5.1) ----------------------------------------------------------------------------
	catchStart = { ids = {}, group = "Sfx", volume = 0.6 },
	circleAppear = { ids = {}, group = "Sfx", volume = 0.5, voices = 2 }, -- played one scale step per circle
	circleClose = { ids = {}, group = "Sfx", volume = 0.3, voices = 2 },
	netSwing = {
		ids = {},
		group = "Sfx",
		volume = 0.8,
		pitch = { 0.96, 1.04 },
		minGap = 0.1,
		voices = 2,
		preload = true,
	},
	circlePerfect = { ids = {}, group = "Sfx", volume = 0.8, voices = 2, preload = true }, -- one scale step per circle
	circleGood = { ids = {}, group = "Sfx", volume = 0.7, voices = 2, preload = true }, -- one scale step per circle
	circleMiss = {
		ids = {},
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		voices = 2,
		preload = true,
	},
	catchSparkle = { ids = {}, group = "Sfx", volume = 0.8, preload = true },
	catchMiss = { ids = {}, group = "Sfx", volume = 0.7, preload = true },
	strayFlee = { ids = {}, group = "Sfx", volume = 0.8, pitch = { 0.95, 1.05 }, range = 40 },

	-- Rescue minigames (5.2) --------------------------------------------------------------------------------
	rescueStart = { ids = {}, group = "Sfx", volume = 0.6 },
	rescueHitBin = {
		ids = {},
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	},
	rescueHitBag = {
		ids = {},
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	},
	rescueHitTree = {
		ids = {},
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	},
	rescueHitCan = {
		ids = {},
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		voices = 2,
		range = 30,
	},
	rescueHitTone = { ids = {}, group = "Sfx", volume = 0.5, voices = 2 }, -- one scale step per hit
	rescueMiss = { ids = {}, group = "Sfx", volume = 0.6 },
	rescueDrop = { ids = {}, group = "Sfx", volume = 0.8, range = 30 },
	rescueFail = { ids = {}, group = "Sfx", volume = 0.6 },
	rescueDone = { ids = {}, group = "Sfx", volume = 0.8 },

	-- Carry, bumps and check-in (5.3) -----------------------------------------------------------------------
	carryPurr = { ids = {}, group = "Sfx", volume = 0.25, looped = true },
	bumpLoose = { ids = {}, group = "Sfx", volume = 0.8, range = 40 },
	bumpHeld = { ids = {}, group = "Sfx", volume = 0.7, range = 40 },
	checkInBell = {
		ids = {},
		group = "Sfx",
		volume = 0.7,
		minGap = 0.5,
		range = 40,
		preload = true,
	},
	catPlaced = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	catSold = { ids = {}, group = "Sfx", volume = 0.6 },

	-- Bait bowl (5.4) ---------------------------------------------------------------------------------------
	foodKibble = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	foodTuna = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	foodSalmon = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	foodDealer = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	baitArrive = { ids = {}, group = "Sfx", volume = 0.7 },
	baitTame = { ids = {}, group = "Sfx", volume = 0.7 },
	baitLetGo = { ids = {}, group = "Sfx", volume = 0.6 },

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
	purr = { ids = {}, group = "Sfx", volume = 0.2, looped = true, range = 8 },
	shimmerRare = { ids = {}, group = "Sfx", volume = 0.4, looped = true, range = 40 },
	shinyReveal = { ids = {}, group = "Sfx", volume = 0.8, duck = true },

	-- Coins, tiers and the night economy (5.6) --------------------------------------------------------------
	coinPop = {
		ids = {},
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.94, 1.06 },
		minGap = 0.08,
		voices = 4,
		range = 40,
		preload = true,
	},
	purchase = { ids = {}, group = "Sfx", volume = 0.7, minGap = 0.2, preload = true },
	offlineClaim = { ids = {}, group = "Sfx", volume = 0.7 },
	placeFurniture = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	gateOpen = { ids = {}, group = "Sfx", volume = 0.7, range = 60 },
	richArrive = { ids = {}, group = "Sfx", volume = 0.7 },
	richTip = { ids = {}, group = "Sfx", volume = 0.8 },
	dealerArrive = { ids = {}, group = "Sfx", volume = 0.7, range = 60 },
	dealerLeave = { ids = {}, group = "Sfx", volume = 0.6, range = 60 },

	-- Clock (5.7) -------------------------------------------------------------------------------------------
	signFlip = { ids = {}, group = "Sfx", volume = 0.5, range = 30 },
	lampOn = {
		ids = {},
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.95, 1.05 },
		voices = 4,
		range = 20,
	},

	-- UI (5.8) ----------------------------------------------------------------------------------------------
	uiClick = {
		ids = {},
		group = "Ui",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		minGap = 0.05,
		voices = 2,
		preload = true,
	},
	uiError = { ids = {}, group = "Ui", volume = 0.6, minGap = 0.3, preload = true },
	uiOpen = { ids = {}, group = "Ui", volume = 0.5, minGap = 0.1 },
	uiClose = { ids = {}, group = "Ui", volume = 0.5, minGap = 0.1 },
	uiDealerOpen = { ids = {}, group = "Ui", volume = 0.6 },
	uiRankReady = { ids = {}, group = "Ui", volume = 0.6, minGap = 1 },
	uiToast = { ids = {}, group = "Ui", volume = 0.5, minGap = 0.2 },
	uiHint = { ids = {}, group = "Ui", volume = 0.5, minGap = 0.5 },
	uiTab = { ids = {}, group = "Ui", volume = 0.4, minGap = 0.05 },
	uiToggle = { ids = {}, group = "Ui", volume = 0.5, minGap = 0.05 },
	uiRename = { ids = {}, group = "Ui", volume = 0.5 },
	announce = { ids = {}, group = "Ui", volume = 0.6, minGap = 1 },
}

return Cues
