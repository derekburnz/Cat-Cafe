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
	musicDayA = {
		ids = { "rbxassetid://92150429408895" },
		group = "Music",
		volume = 0.3,
		looped = true,
	}, -- "Open for Business"
	musicDayB = {
		ids = { "rbxassetid://73896733157878" },
		group = "Music",
		volume = 0.3,
		looped = true,
	}, -- "Second Cup"
	musicNightA = {
		ids = { "rbxassetid://131746689332910" },
		group = "Music",
		volume = 0.3,
		looped = true,
	}, -- "After Hours"
	musicNightB = { ids = {}, group = "Music", volume = 0.3, looped = true }, -- "Night Owls"
	stingDusk = {
		ids = { "rbxassetid://72211264391144" },
		group = "Music",
		volume = 0.6,
		duck = true,
	}, -- "Night Shift"
	stingDawn = {
		ids = { "rbxassetid://78519815757270" },
		group = "Music",
		volume = 0.6,
		duck = true,
	}, -- "Fresh Pot"
	jingleCatFound = {
		ids = { "rbxassetid://102912195564834" },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		preload = true,
	},
	jingleRare = { ids = {}, group = "Music", volume = 0.6, minGap = 1 },
	jingleEpic = { ids = {}, group = "Music", volume = 0.65, minGap = 1 },
	jingleLegendary = { ids = {}, group = "Music", volume = 0.7, minGap = 1, duck = true },
	jingleMythical = { ids = {}, group = "Music", volume = 0.7, minGap = 1, duck = true },
	jingleRankUp = {
		ids = { "rbxassetid://77815750894397" },
		group = "Music",
		volume = 0.7,
		minGap = 1,
		duck = true,
	},
	jingleDailyCard = {
		ids = { "rbxassetid://99160708780154" },
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
		ids = { "rbxassetid://126544733880801" },
		group = "Sfx",
		volume = 0.5,
		minGap = 0.1,
		voices = 1,
	}, -- F45: hold E; one voice (Audio's fade relies on it)
	catchStart = { ids = { "rbxassetid://92586398019542" }, group = "Sfx", volume = 0.6 },
	circleAppear = {
		ids = { "rbxassetid://135049952895026" },
		group = "Sfx",
		volume = 0.5,
		voices = 2,
	}, -- played one scale step per circle
	circleClose = { ids = {}, group = "Sfx", volume = 0.3, voices = 2 },
	netSwing = {
		ids = { "rbxassetid://89396147858929" },
		group = "Sfx",
		volume = 0.8,
		pitch = { 0.96, 1.04 },
		minGap = 0.1,
		voices = 2,
		preload = true,
	},
	circlePerfect = {
		ids = { "rbxassetid://80668948664944" },
		group = "Sfx",
		volume = 0.8,
		voices = 2,
		preload = true,
	}, -- one scale step per circle
	circleGood = {
		ids = { "rbxassetid://104110576862212" },
		group = "Sfx",
		volume = 0.7,
		voices = 2,
		preload = true,
	}, -- one scale step per circle
	circleMiss = {
		ids = { "rbxassetid://82265210012821" },
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		voices = 2,
		preload = true,
	},
	catchSparkle = {
		ids = { "rbxassetid://96610512551224" },
		group = "Sfx",
		volume = 0.8,
		preload = true,
	},
	catchMiss = {
		ids = { "rbxassetid://72335633309097" },
		group = "Sfx",
		volume = 0.7,
		preload = true,
	},
	catHiss = {
		ids = { "rbxassetid://133059376390215" },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		range = 40,
	}, -- v0.4: a Miss ends the catch
	pawLost = { ids = { "rbxassetid://120814540941175" }, group = "Sfx", volume = 0.6 }, -- v0.4; retired by F40 (no paws), kept for its upload record
	purrfectChime = {
		ids = { "rbxassetid://115362387345274" },
		group = "Sfx",
		volume = 0.8,
		minGap = 1,
		preload = true,
	},
	strayFlee = {
		ids = { "rbxassetid://115429958262894" },
		group = "Sfx",
		volume = 0.8,
		pitch = { 0.95, 1.05 },
		range = 40,
	},
	straySprint = {
		ids = { "rbxassetid://77220581372843" },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.08 },
		range = 50,
	}, -- v0.5 F40

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

	-- Carry, shoves and check-in (5.3; v0.5 Shove keeps the Bump names in code) ------------------------------
	carryPurr = {
		ids = { "rbxassetid://104398552389386" },
		group = "Sfx",
		volume = 0.25,
		looped = true,
	},
	shove = {
		ids = { "rbxassetid://135377461302918" },
		group = "Sfx",
		volume = 0.7,
		pitch = { 0.95, 1.05 },
		minGap = 0.2,
		range = 40,
	},
	bumpLoose = { -- the StrayFlee file: a startled mrrp and paws scurrying off
		ids = { "rbxassetid://115429958262894" },
		group = "Sfx",
		volume = 0.8,
		pitch = { 1.0, 1.1 },
		range = 40,
	},
	bumpHeld = { ids = { "rbxassetid://83302918660784" }, group = "Sfx", volume = 0.7, range = 40 },
	tackleLunge = {
		ids = { "rbxassetid://119010397581874" },
		group = "Sfx",
		volume = 0.6,
		pitch = { 0.95, 1.05 },
		range = 40,
	}, -- F74: the dive's whoosh on the press; a hit adds the shove sound, a miss tackleMiss
	tackleMiss = {
		ids = { "rbxassetid://85126153307905" },
		group = "Sfx",
		volume = 0.7,
		range = 40,
	}, -- F74: belly flop, skid, "bonk bonk"
	checkInBell = {
		ids = { "rbxassetid://75991488445164" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.5,
		range = 40,
		preload = true,
	},
	catDrop = {
		ids = { "rbxassetid://104205348504396" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.5,
		range = 40,
	}, -- F45: Drop or G
	catPickUp = {
		ids = { "rbxassetid://117560666331463" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.3,
		range = 40,
	}, -- F56: a carry starts (pick up)
	getaway = {
		ids = { "rbxassetid://128887999985652" },
		group = "Sfx",
		volume = 0.7,
		minGap = 1,
		range = 40,
	}, -- F55: a catch pushes the crowd back
	catPlaced = {
		ids = { "rbxassetid://101433267853089" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.15,
	}, -- a cat starts a role (Staff tab)
	catRest = {
		ids = { "rbxassetid://116178484251299" },
		group = "Sfx",
		volume = 0.55,
		minGap = 0.3,
	}, -- a cat leaves its role; Unequip All plays one
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
	purr = {
		ids = { "rbxassetid://110254245469370" },
		group = "Sfx",
		volume = 0.2,
		looped = true,
		range = 8,
	},
	rareNear = {
		ids = {},
		group = "Sfx",
		volume = 0.35,
		minGap = 3,
		range = 40,
	}, -- once as you come near a gold or Legendary and up stray (was the shimmerRare loop, retired 2026-10-28)
	goldReveal = {
		ids = { "rbxassetid://124772067869145" },
		group = "Sfx",
		volume = 0.8,
		minGap = 1,
		duck = true,
	}, -- F42: was shinyReveal

	-- Zones and travel (5.9) --------------------------------------------------------------------------------
	zoneSafe = { ids = { "rbxassetid://106879168380819" }, group = "Sfx", volume = 0.45 }, -- back on the safe street
	zoneArea = { ids = { "rbxassetid://103566569518372" }, group = "Sfx", volume = 0.45 }, -- into a catching area, shoves on
	travelPoof = {
		ids = { "rbxassetid://99298919905979" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.5,
	}, -- fast travel and My Cafe

	-- Rewards (5.10) ----------------------------------------------------------------------------------------
	giftClaim = {
		ids = { "rbxassetid://80009297129343" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.2,
	}, -- F47 Tip Jar
	indexReward = {
		ids = { "rbxassetid://103563370361429" },
		group = "Sfx",
		volume = 0.75,
		minGap = 0.5,
		duck = true,
	}, -- F48 Index rewards

	-- Coins, tiers and the night economy (5.6) --------------------------------------------------------------
	coinPop = {
		ids = { "rbxassetid://80305681313349" },
		group = "Sfx",
		volume = 0.4,
		pitch = { 0.94, 1.06 },
		minGap = 0.08,
		voices = 4,
		range = 40,
		preload = true,
	},
	purchase = {
		ids = { "rbxassetid://135044364239461" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.2,
		preload = true,
	},
	offlineClaim = { ids = {}, group = "Sfx", volume = 0.7 },
	placeFurniture = { ids = {}, group = "Sfx", volume = 0.6, range = 30 },
	gateOpen = { ids = { "rbxassetid://89970899972584" }, group = "Sfx", volume = 0.7, range = 60 }, -- v0.4: the barrier dissolves
	shuttersUp = {
		ids = { "rbxassetid://137368825957454" },
		group = "Sfx",
		volume = 0.7,
		range = 60,
	}, -- a For Rent plot becomes a cafe
	richArrive = { ids = { "rbxassetid://132811455211745" }, group = "Sfx", volume = 0.7 },
	richTip = { ids = { "rbxassetid://89094982389204" }, group = "Sfx", volume = 0.8 },
	tipPile = {
		ids = { "rbxassetid://131031584416450" },
		group = "Sfx",
		volume = 0.6,
		minGap = 0.3,
	}, -- F61: the tip piles are collected
	dealerArrive = { ids = {}, group = "Sfx", volume = 0.7, range = 60 },
	dealerLeave = { ids = {}, group = "Sfx", volume = 0.6, range = 60 },

	-- Clock (5.7) -------------------------------------------------------------------------------------------
	signFlip = { ids = { "rbxassetid://108862500995197" }, group = "Sfx", volume = 0.5, range = 30 },
	lampOn = {
		ids = {},
		group = "Sfx",
		volume = 0.3,
		pitch = { 0.95, 1.05 },
		voices = 4,
		range = 20,
	},

	duskBell = { ids = { "rbxassetid://94140238394787" }, group = "Sfx", volume = 0.5 }, -- F66: DuskWarningSeconds before night

	-- Visitors, codes and potions (5.11) -------------------------------------------------------------------
	visitorCollector = {
		ids = { "rbxassetid://89641081512860" },
		group = "Sfx",
		volume = 0.6,
		minGap = 2,
	}, -- F63: the Cat Collector comes by
	visitorMystery = {
		ids = { "rbxassetid://76865491597271" },
		group = "Sfx",
		volume = 0.6,
		minGap = 2,
	}, -- F64: the Mystery Visitor's gift appears
	giftOpen = {
		ids = { "rbxassetid://116810371894969" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.5,
	}, -- F64: the gift is opened
	potionDrink = {
		ids = { "rbxassetid://135212660589235" },
		group = "Sfx",
		volume = 0.7,
		minGap = 0.3,
	}, -- F64: the UI plays it on UsePotion
	catLevelUp = {
		ids = { "rbxassetid://122201546356974" },
		group = "Sfx",
		volume = 0.4,
		minGap = 1.5,
	}, -- F75: one of your cats levels up

	-- UI (5.8) ----------------------------------------------------------------------------------------------
	uiClick = {
		ids = { "rbxassetid://100998799358810" },
		group = "Ui",
		volume = 0.6,
		pitch = { 0.97, 1.03 },
		minGap = 0.05,
		voices = 2,
		preload = true,
	},
	uiError = {
		ids = { "rbxassetid://80135751380842" },
		group = "Ui",
		volume = 0.6,
		minGap = 0.3,
		preload = true,
	},
	uiOpen = { ids = { "rbxassetid://114730761775875" }, group = "Ui", volume = 0.5, minGap = 0.1 },
	uiClose = { ids = { "rbxassetid://129207225359334" }, group = "Ui", volume = 0.5, minGap = 0.1 },
	uiDealerOpen = { ids = { "rbxassetid://109906464637138" }, group = "Ui", volume = 0.6 },
	uiRankReady = {
		ids = { "rbxassetid://98501439978038" },
		group = "Ui",
		volume = 0.6,
		minGap = 1,
	},
	uiToast = { ids = { "rbxassetid://97064648437698" }, group = "Ui", volume = 0.5, minGap = 0.2 },
	uiHint = { ids = { "rbxassetid://110637750950745" }, group = "Ui", volume = 0.5, minGap = 0.5 },
	uiTab = { ids = { "rbxassetid://122895842124214" }, group = "Ui", volume = 0.4, minGap = 0.05 },
	uiToggle = {
		ids = { "rbxassetid://75685910002998" },
		group = "Ui",
		volume = 0.5,
		minGap = 0.05,
	},
	uiRename = { ids = { "rbxassetid://109980626119711" }, group = "Ui", volume = 0.5 },
	uiSlider = {
		ids = { "rbxassetid://110732370632116" },
		group = "Ui",
		volume = 0.5,
		minGap = 0.03,
	}, -- a volume slider's 5 % step
	uiGiftReady = {
		ids = { "rbxassetid://109161742998311" },
		group = "Ui",
		volume = 0.6,
		minGap = 1,
	}, -- a Tip Jar gift is ready
	uiBadge = { ids = { "rbxassetid://132178490173046" }, group = "Ui", volume = 0.4, minGap = 0.5 }, -- a red dot turns on
	-- The Spin Wheel window (F49): it starts, a slice passes the pointer (can fire every frame early on), it lands
	uiSpinStart = {
		ids = { "rbxassetid://89767919141598" },
		group = "Ui",
		volume = 0.6,
		minGap = 0.5,
	},
	uiSpinTick = {
		ids = { "rbxassetid://109150468833128" },
		group = "Ui",
		volume = 0.45,
		pitch = { 0.97, 1.03 },
		minGap = 0.04,
		voices = 2,
	},
	uiSpinWin = {
		ids = { "rbxassetid://137789027351769" },
		group = "Ui",
		volume = 0.7,
		minGap = 1,
		duck = true,
	},
	uiCodeRedeem = {
		ids = { "rbxassetid://128875832136345" },
		group = "Ui",
		volume = 0.7,
		minGap = 1,
	}, -- F65: a code worked (a wrong one is uiError)
	uiDailyStamp = {
		ids = { "rbxassetid://89023008668503" },
		group = "Ui",
		volume = 0.7,
		minGap = 1,
	}, -- F70: a Daily Treat stamp claimed, days 1 to 6 (the UI plays it)
	uiTrade = { ids = { "rbxassetid://96571316013787" }, group = "Ui", volume = 0.7, minGap = 1 }, -- F63: a trade with the Cat Collector
	announce = { ids = { "rbxassetid://140320161816899" }, group = "Ui", volume = 0.6, minGap = 1 },
	announceMythical = {
		ids = { "rbxassetid://93649795285321" },
		group = "Ui",
		volume = 0.7,
		minGap = 1,
		duck = true,
	}, -- F58: a Mythical shout-out
}

return Cues
