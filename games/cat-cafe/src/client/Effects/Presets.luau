--!strict
-- Every number Effects tunes, in one place (animation-vfx skill sections 6 and 7). Tune in Studio through MCP,
-- then copy the numbers here. Pure data: no services, so a spec can require it.

local Presets = {}

export type Tier = "low" | "high"

-- Swatches from the style guide palette (docs/art/style-guide.md section 2). Effects use nothing else.
Presets.palette = {
	cream = Color3.fromRGB(246, 235, 221), -- 0 cream
	mint = Color3.fromRGB(143, 211, 193), -- 3 mint
	blush = Color3.fromRGB(232, 160, 160), -- 4 blush
	offwhite = Color3.fromRGB(255, 249, 242), -- 5 offwhite
	lampWarm = Color3.fromRGB(255, 217, 168), -- 6 lamp_warm
	furGrey = Color3.fromRGB(142, 150, 163), -- 12 fur_grey
	golden = Color3.fromRGB(242, 193, 78), -- 15 fur_golden
	eyeBlue = Color3.fromRGB(95, 168, 255), -- 18 eye_blue
	nosePink = Color3.fromRGB(224, 122, 140), -- 19 nose_pink
	leaf = Color3.fromRGB(95, 184, 90), -- 47 leaf_green
	fishBlue = Color3.fromRGB(110, 193, 255), -- 42 fish_blue
	fishBelly = Color3.fromRGB(221, 242, 255), -- 43 fish_belly
	milk = Color3.fromRGB(255, 255, 255), -- 46 milk
	neonPink = Color3.fromRGB(255, 107, 129), -- 53 neon_pink
	sparkle = Color3.fromRGB(255, 244, 176), -- 54 sparkle
	aurora = Color3.fromRGB(142, 124, 240), -- 58 aurora_violet
	shirtBlue = Color3.fromRGB(60, 125, 217), -- 35 shirt_blue
	shirtRed = Color3.fromRGB(217, 72, 59), -- 36 shirt_red
	signTeal = Color3.fromRGB(31, 165, 143), -- 51 sign_teal
	galaxyBlue = Color3.fromRGB(59, 76, 140), -- 55 galaxy_blue
	goldLight = Color3.fromRGB(251, 228, 154), -- 61 gold_light
	goldDark = Color3.fromRGB(201, 143, 42), -- 63 gold_dark (62 gold_mid is fur_golden, `golden`)
	furRose = Color3.fromRGB(242, 191, 203), -- 69 fur_rose
	pastelSky = Color3.fromRGB(168, 216, 240), -- 94 pastel_sky
}

-- Rarity swatches 20 to 23 and 56, the same hex values as Catalog.rarities.
Presets.rarity = {
	Common = Color3.fromRGB(142, 151, 178),
	Rare = Color3.fromRGB(95, 168, 255),
	Epic = Color3.fromRGB(192, 124, 255),
	Legendary = Color3.fromRGB(255, 201, 77),
	Mythical = Color3.fromRGB(255, 94, 126),
	Secret = Color3.fromRGB(22, 22, 29), -- #3470: near black; anything that must glow uses Presets.rarityGlow
} :: { [string]: Color3 }

-- The colour a rarity's light takes (sparkles, beams, neon rings) when its swatch is too dark to glow: a Secret's
-- starlight. Every other rarity glows in its own swatch (Logic.glowColour).
Presets.rarityGlow = {
	Secret = Color3.fromRGB(226, 214, 255),
} :: { [string]: Color3 }

-- Roblox's own particle textures ship with the engine, so they need no upload and no permission. Our sprites in
-- assets/cat-cafe/vfx/ replace them once Derek uploads them: put the rbxassetid:// here and leave the rest alone.
Presets.textures = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	goldSparkle = "", -- the sparkle sprite CatCafe_VFX_ShinySparkle.png (asset thread, PR #46) once uploaded
}

export type Budget = {
	animatedCats: number, -- cats whose head, tail and paws move at once
	animRadius: number, -- studs from the player within which a cat can move
	animHz: number, -- pose updates per second
	steadyEmitters: number, -- steam, chimney smoke and fireflies on at once
	rateScale: number, -- multiplies every steady emitter's rate
	goldEmitters: number, -- gold cats sparkling at once
	butterflies: number,
	ambientRadius: number, -- studs; steam, butterflies and fireflies beyond it are off
	chimneyRadius: number, -- smoke reads from far away, so it gets a longer range
	burstScale: number, -- multiplies every burst count
	maxBurst: number, -- no single burst is bigger than this
	confetti: number, -- pieces in one confetti burst
	areaPuffs: number, -- Desert and Ruins stray puffs in any one second (#2661)
	napLabels: number, -- napping cats that show floating z's
	rushLines: number, -- speed lines on a player in a Catch Rush (F55)
	signatureCats: number, -- Legendary and Mythical themed cats showing their signature effect at once
	decorEffects: number, -- Mythical cafe styles and decor moving at once; each takes one of steadyEmitters
	lawnEffects: number, -- front lawn pieces showing their effects at once (#1283, Effects/Lawn)
	potionGlows: number, -- players showing a running potion's glow at once (F64), your own first
	cloudPuffs: number, -- puffs in the full-screen clouds of a cannon flight or a cloud hop (F84)
	campfires: number, -- campfires whose flame moves, with embers and a light, at once
	pullConfetti: number, -- confetti pieces on screen in a big pull (F89)
	rainbowCats: number, -- rainbow cats whose bands flow, with a glow and a trail, at once (F99)
	rainbowOutlines: number, -- of those, the nearest with a band-coloured outline (a Highlight each)
	rallyPops: number, -- "+1" pops and paws flying into the Rally bar at once (F101)
	pennants: number, -- bunting pennants fluttering at once (F101); 0 hangs them all still
	decorMotion: number, -- rare decor's moving parts (_Swing, _Spin, _Bob) moving at once (F89 2c)
	rides: number, -- #5065: Water Park rides turning at once (Effects/Rides)
	rideHz: number, -- #5065: their turns a second
	netTrails: number, -- nets drawing a whoosh trail at once (F93)
	luckyShimmers: number, -- jade Lucky Cat statues shimmering at once (F88), a Highlight each
	campDrips: number, -- camp pipes dripping at once (F100), a drop part each
	campFish: number, -- camp pond fish jumping now and then (F100); 0 holds them all still
	rallyBoards: number, -- Rally boards running their marquee at once (F101); 0 leaves them as built
	cafeOrders: number, -- orders in other cafes showing their puff, oven glow and ding at once (F90); your own always
	crownGlints: number, -- crowned players whose crown glints now and then (F98), the nearest first
	shopCatEmitters: number, -- shop cats with a steady emitter on at once (Duchess's petals #1191, Maple's leaves #1668)
	waterfalls: number, -- Ruins waterfalls and fountains whose water runs at once (Effects/RuinsWater)
}

-- When a phone or tablet counts as struggling (#4311, Logic.slowStep; Derek 2026-11-14): under `fps` frames a second
-- on average over a `window` second window, `windows` windows in a row, not counting the first `after` seconds or
-- frames longer than `pause` seconds. #4307 (phones leave at 61 to 180 s): it used to need 60 + 2 x 20 = 100 s, past
-- most of the tutorial, so a struggling phone ran the full budget through its first minutes; now 20 + 2 x 10 = 40 s
-- at the earliest (cutscenes still hold the count, so the intro does not count). #4857 read (Nov 16, first 5 minutes
-- priority): phones average about 49 fps, so "a little laggy" ones (35 to 39) never tripped at 30; now under 40, and
-- from 10 s in, so the lighter budget can be on by 30 s.
Presets.slow = {
	fps = 40, -- 30 before
	window = 10,
	windows = 2,
	after = 10, -- 20 before
	pause = 1,
}

-- "low" is a phone or a tablet (touch with no keyboard): 150 live particles, bursts of 12, 4 steady emitters
-- (skill section 7). "high" is a PC. "console" is an Xbox or PlayStation (#2871): it runs at the "high" tier, but
-- with a budget between the phone's and the PC's, since an Xbox One or PS4 is far slower than a gaming PC and the
-- console pass watches the frame rate in a busy Alleyway. "lowPerformance" is the Low performance setting on any
-- device: under the phone budget everywhere, with half the steady particles. "lite" (#3794, the `fxLite` switch) is
-- a struggling phone or tablet (Presets.slow, #4311), or any device with graphics quality set to 1 to 3: between the
-- phone budget and Low performance, for the
-- phones' frame rate (about 47 fps against 65 on PC): fewer moving cats at 20 Hz, fewer and thinner steady emitters,
-- smaller bursts, fewer Highlights, and no decor motion or bunting flutter.
Presets.budget = {
	low = {
		animatedCats = 8,
		animRadius = 60,
		animHz = 30,
		steadyEmitters = 4,
		rateScale = 0.85, -- #4857 (phones average 49 fps): 1 before
		goldEmitters = 3,
		butterflies = 6,
		ambientRadius = 75, -- #4857: 80 before
		chimneyRadius = 140,
		burstScale = 0.5,
		maxBurst = 12,
		confetti = 14,
		areaPuffs = 4,
		napLabels = 4,
		rushLines = 2,
		signatureCats = 3,
		decorEffects = 2,
		lawnEffects = 3,
		potionGlows = 3,
		cloudPuffs = 10,
		campfires = 2,
		pullConfetti = 20,
		rainbowCats = 6,
		rainbowOutlines = 3,
		rallyPops = 5,
		pennants = 20, -- #4857: 40 before
		decorMotion = 6, -- #4857: 12 before
		rides = 1, -- #5065 (Sync's phone read: 2 rides at 30 Hz were half of Effects' time in the Water Park): 3 before
		rideHz = 15, -- #5065: 30 before
		netTrails = 3,
		luckyShimmers = 2,
		campDrips = 1,
		campFish = 1,
		rallyBoards = 1,
		cafeOrders = 0,
		crownGlints = 2,
		shopCatEmitters = 1,
		waterfalls = 1,
	},
	high = {
		animatedCats = 16,
		animRadius = 80,
		animHz = 60,
		steadyEmitters = 10,
		rateScale = 1,
		goldEmitters = 8,
		butterflies = 14,
		ambientRadius = 110,
		chimneyRadius = 200,
		burstScale = 1,
		maxBurst = 30,
		confetti = 28,
		areaPuffs = 8,
		napLabels = 10,
		rushLines = 3,
		signatureCats = 6,
		decorEffects = 4,
		lawnEffects = 6,
		potionGlows = 6,
		cloudPuffs = 16,
		campfires = 3,
		pullConfetti = 40,
		rainbowCats = 10,
		rainbowOutlines = 6,
		rallyPops = 8,
		pennants = 90,
		decorMotion = 24,
		rides = 3,
		rideHz = 30,
		netTrails = 6,
		luckyShimmers = 4,
		campDrips = 2,
		campFish = 2,
		rallyBoards = 1,
		cafeOrders = 3,
		crownGlints = 5,
		shopCatEmitters = 2,
		waterfalls = 3,
	},
	console = {
		animatedCats = 12,
		animRadius = 70,
		animHz = 30,
		steadyEmitters = 6,
		rateScale = 1,
		goldEmitters = 5,
		butterflies = 10,
		ambientRadius = 95,
		chimneyRadius = 170,
		burstScale = 0.75,
		maxBurst = 20,
		confetti = 20,
		areaPuffs = 6,
		napLabels = 6,
		rushLines = 2,
		signatureCats = 4,
		decorEffects = 3,
		lawnEffects = 4,
		potionGlows = 4,
		cloudPuffs = 12,
		campfires = 2,
		pullConfetti = 28,
		rainbowCats = 8,
		rainbowOutlines = 4,
		rallyPops = 6,
		pennants = 60,
		decorMotion = 16,
		rides = 3,
		rideHz = 30,
		netTrails = 4,
		luckyShimmers = 3,
		campDrips = 1,
		campFish = 1,
		rallyBoards = 1,
		cafeOrders = 2,
		crownGlints = 3,
		shopCatEmitters = 1,
		waterfalls = 2,
	},
	lite = {
		animatedCats = 5,
		animRadius = 50,
		animHz = 20,
		steadyEmitters = 3,
		rateScale = 0.7,
		goldEmitters = 2,
		butterflies = 3,
		ambientRadius = 70,
		chimneyRadius = 120,
		burstScale = 0.4,
		maxBurst = 10,
		confetti = 10,
		areaPuffs = 3,
		napLabels = 3,
		rushLines = 1,
		signatureCats = 2,
		decorEffects = 1,
		lawnEffects = 2,
		potionGlows = 2,
		cloudPuffs = 8,
		campfires = 1,
		pullConfetti = 16,
		rainbowCats = 4,
		rainbowOutlines = 1,
		rallyPops = 4,
		pennants = 0,
		decorMotion = 0,
		rides = 1, -- #5065: the lite budget turns one ride (rides.mostLite before)
		rideHz = 15,
		netTrails = 2,
		luckyShimmers = 1,
		campDrips = 1,
		campFish = 1,
		rallyBoards = 1,
		cafeOrders = 0,
		crownGlints = 1,
		shopCatEmitters = 1,
		waterfalls = 1,
	},
	lowPerformance = {
		animatedCats = 4,
		animRadius = 45,
		animHz = 20,
		steadyEmitters = 2,
		rateScale = 0.5,
		goldEmitters = 1,
		butterflies = 2,
		ambientRadius = 60,
		chimneyRadius = 100,
		burstScale = 0.35,
		maxBurst = 8,
		confetti = 8,
		areaPuffs = 2,
		napLabels = 2,
		rushLines = 1,
		signatureCats = 1,
		decorEffects = 0,
		lawnEffects = 0,
		potionGlows = 0,
		cloudPuffs = 6,
		campfires = 1,
		pullConfetti = 13,
		rainbowCats = 3,
		rainbowOutlines = 0,
		rallyPops = 3,
		pennants = 0,
		decorMotion = 0,
		rides = 0, -- Low performance leaves every ride still
		rideHz = 15,
		netTrails = 1,
		luckyShimmers = 0,
		campDrips = 1,
		campFish = 0,
		rallyBoards = 0,
		cafeOrders = 0,
		crownGlints = 1,
		shopCatEmitters = 0,
		waterfalls = 1,
	},
} :: { [string]: Budget }

export type EmitterPreset = {
	texture: string,
	colors: { Color3 }, -- spread evenly over the particle's life
	size: { number }, -- studs at birth and at death
	transparency: { number }, -- at birth and at death
	lifetime: { number }, -- min and max seconds
	speed: { number }, -- min and max studs per second
	spread: number, -- degrees either side of straight up
	rate: number, -- per second, steady emitters only (bursts use Emit)
	acceleration: Vector3?,
	drag: number?,
	lightEmission: number?, -- 0 by day; glow effects use 0.5 to 1
	rotSpeed: { number }?,
}

Presets.emitters = {
	-- The Dragon Keep's set looks (Effects/KeepSets, Derek 2026-11-15): one soft look per lit card family, from the
	-- body (the crown's from the head). Level 5 doubles the rate and grows the size (Presets.dragonSets).
	dragonSetFlame = {
		texture = Presets.textures.sparkle,
		colors = {
			Color3.fromRGB(255, 130, 50),
			Color3.fromRGB(255, 205, 110),
			Color3.fromRGB(255, 240, 200),
		},
		size = { 0.3, 0.05 },
		transparency = { 0.1, 1 },
		lifetime = { 0.6, 1 },
		speed = { 0.5, 1.2 },
		spread = 40,
		rate = 5,
		acceleration = Vector3.new(0, 2, 0),
		drag = 1,
		lightEmission = 0.6,
	},
	dragonSetClaw = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(235, 240, 250), Color3.fromRGB(170, 185, 210) },
		size = { 0.35, 0 },
		transparency = { 0, 1 },
		lifetime = { 0.25, 0.4 },
		speed = { 0, 0.3 },
		spread = 180,
		rate = 3,
		lightEmission = 0.8,
		rotSpeed = { -90, 90 },
	},
	dragonSetWing = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(225, 240, 255), Color3.fromRGB(190, 215, 245) },
		size = { 0.25, 0.15 },
		transparency = { 0.3, 1 },
		lifetime = { 1.2, 1.8 },
		speed = { 0.3, 0.6 },
		spread = 70,
		rate = 3,
		acceleration = Vector3.new(0, -1, 0),
		drag = 1.5,
		rotSpeed = { -40, 40 },
	},
	dragonSetHoard = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(255, 180, 40) },
		size = { 0.3, 0.15 },
		transparency = { 0, 1 },
		lifetime = { 0.7, 1 },
		speed = { 0.2, 0.5 },
		spread = 60,
		rate = 3,
		acceleration = Vector3.new(0, -3, 0),
		lightEmission = 0.5,
	},
	dragonSetHeart = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 150, 190), Color3.fromRGB(255, 200, 220) },
		size = { 0.3, 0.1 },
		transparency = { 0.1, 1 },
		lifetime = { 1, 1.5 },
		speed = { 0.3, 0.7 },
		spread = 35,
		rate = 3,
		acceleration = Vector3.new(0, 0.8, 0),
		drag = 0.8,
		lightEmission = 0.4,
	},
	dragonSetCrown = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 250, 220) },
		size = { 0.25, 0.05 },
		transparency = { 0, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0.6, 1 },
		spread = 15,
		rate = 4,
		drag = 2,
		lightEmission = 0.8,
	},
	-- Ambient
	-- The Desert's air (#2657, tier6-7-areas.md section 4): sand motes drifting downwind round you, in sand and
	-- sandstone; the Ruins' air (section 5): slow glyph-gold and jade motes floating up, glowing a little at night.
	desertSand = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(232, 205, 150), Color3.fromRGB(204, 150, 96) },
		size = { 0.25, 0.1 },
		transparency = { 0.35, 1 },
		lifetime = { 2.5, 4 },
		speed = { 0.3, 0.8 },
		spread = 60,
		rate = 10,
		acceleration = Vector3.new(3, -0.2, 1),
		drag = 0.3,
	},
	-- Sand blowing off a Desert dune's crest in the wind (#2925): a thin pale plume streaming downwind.
	duneSand = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(240, 220, 172), Color3.fromRGB(232, 205, 150) },
		size = { 0.5, 1.6 },
		transparency = { 0.55, 1 },
		lifetime = { 1.2, 2 },
		speed = { 2, 4 },
		spread = 15,
		rate = 6,
		acceleration = Vector3.new(4, 0.4, 1.3),
		drag = 0.6,
	},
	ruinsMotes = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(232, 190, 80), Color3.fromRGB(80, 160, 120) },
		size = { 0.18, 0 },
		transparency = { 0.2, 1 },
		lifetime = { 3, 5 },
		speed = { 0.2, 0.5 },
		spread = 180,
		rate = 5,
		acceleration = Vector3.new(0, 0.15, 0),
		lightEmission = 0.5,
		rotSpeed = { -30, 30 },
	},
	-- The Oasis Spa's pool (#2925, late-stations.md section 1): wide, slow, soft steam off the water.
	spaSteam = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite },
		size = { 1, 3 },
		transparency = { 0.7, 1 },
		lifetime = { 2.5, 3.5 },
		speed = { 0.6, 1.2 },
		spread = 25,
		rate = 3,
		acceleration = Vector3.new(0.2, 0.3, 0),
		drag = 0.8,
	},
	steam = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite },
		size = { 0.4, 1.6 },
		transparency = { 0.55, 1 },
		lifetime = { 1.2, 1.8 },
		speed = { 1.5, 2.5 },
		spread = 12,
		rate = 4,
		acceleration = Vector3.new(0.3, 0.6, 0),
		drag = 1,
	},
	chimney = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.cream, Presets.palette.furGrey },
		size = { 1.2, 4 },
		transparency = { 0.45, 1 },
		lifetime = { 3, 4 },
		speed = { 2, 3 },
		spread = 10,
		rate = 2.5,
		acceleration = Vector3.new(1.2, 0.4, 0.4),
		drag = 0.6,
	},
	ember = {
		-- A campfire's embers: soft warm dots drifting up and fading, never sparks.
		texture = Presets.textures.smoke,
		colors = {
			Presets.palette.lampWarm,
			Color3.fromRGB(255, 170, 84),
			Color3.fromRGB(232, 112, 64),
		},
		size = { 0.16, 0.04 },
		transparency = { 0, 1 },
		lifetime = { 1.2, 2.2 },
		speed = { 1.5, 3 },
		spread = 22,
		rate = 3,
		acceleration = Vector3.new(0.25, 0.5, 0.15),
		drag = 0.7,
		lightEmission = 1,
	},
	fireflies = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.lampWarm, Presets.palette.sparkle },
		size = { 0.35, 0.2 },
		transparency = { 0.1, 1 },
		lifetime = { 3, 5 },
		speed = { 0.2, 0.6 },
		spread = 180,
		rate = 2.5,
		lightEmission = 1,
		drag = 0.5,
	},
	shiny = {
		-- A gold cat's sparkle (F42; Derek picked gold coats on 2026-10-27): warm white glints off the gold. The key
		-- keeps its old name because QA's EffectsMotion spec checks it.
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Presets.palette.sparkle, Presets.palette.golden },
		size = { 0.45, 0 },
		transparency = { 0, 1 },
		lifetime = { 0.6, 1 },
		speed = { 0.5, 1.2 },
		spread = 180,
		rate = 3,
		lightEmission = 0.6,
		rotSpeed = { -90, 90 },
	},
	-- Bursts
	hissPuff = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite, Presets.palette.furGrey },
		size = { 0.6, 1.4 },
		transparency = { 0.35, 1 },
		lifetime = { 0.35, 0.55 },
		speed = { 5, 8 },
		spread = 70,
		rate = 0,
		drag = 6,
	},
	-- A Secret stray (#3470): a slow dark haze round the cat and a few pale stars drifting up through it.
	secretAura = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(22, 22, 29), Color3.fromRGB(52, 44, 78) },
		size = { 1.6, 2.8 },
		transparency = { 0.55, 1 },
		lifetime = { 1.4, 2 },
		speed = { 0.2, 0.7 },
		spread = 180,
		rate = 3,
		drag = 1,
		lightEmission = 0,
		rotSpeed = { -20, 20 },
	},
	-- The Secret cats' own glow (#3544, Effects/SecretGlow): a soft pale halo in the Secret colour round the cat,
	-- locked to it, drawn behind it and bright against dark and light ground alike. A few big, slow, see-through
	-- puffs: about 4 on screen a cat.
	secretHalo = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(226, 214, 255), Color3.fromRGB(190, 170, 255) },
		size = { 2.2, 3.2 },
		transparency = { 0.72, 1 },
		lifetime = { 1.6, 2.2 },
		speed = { 0, 0.15 },
		spread = 180,
		rate = 2,
		lightEmission = 0.7,
		rotSpeed = { -12, 12 },
	},
	secretStars = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(226, 214, 255), Color3.fromRGB(255, 255, 255) },
		size = { 0.35, 0.1 },
		transparency = { 0.1, 1 },
		lifetime = { 1, 1.6 },
		speed = { 0.6, 1.4 },
		spread = 50,
		rate = 2,
		lightEmission = 0.8,
	},
	smokePuff = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.cream, Presets.palette.offwhite },
		size = { 1.5, 4 },
		transparency = { 0.3, 1 },
		lifetime = { 0.8, 1.2 },
		speed = { 4, 7 },
		spread = 80,
		rate = 0,
		drag = 4,
	},
	dust = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.cream },
		size = { 0.6, 1.8 },
		transparency = { 0.4, 1 },
		lifetime = { 0.6, 0.9 },
		speed = { 1, 3 },
		spread = 60,
		rate = 0,
		drag = 3,
	},
	-- Little puffs kicked up behind a running cat's feet (F40).
	kick = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.cream },
		size = { 0.3, 0.9 },
		transparency = { 0.5, 1 },
		lifetime = { 0.35, 0.55 },
		speed = { 0.5, 1.5 },
		spread = 70,
		rate = 0,
		drag = 3,
	},
	-- A small huff of breath from a cat catching its breath (F40).
	huff = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite },
		size = { 0.2, 0.55 },
		transparency = { 0.35, 1 },
		lifetime = { 0.4, 0.6 },
		speed = { 1, 2 },
		spread = 30,
		rate = 0,
		drag = 2,
	},
	catchSparkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite }, -- tinted by rarity when the burst is made
		size = { 0.8, 0 },
		transparency = { 0, 0.3 },
		lifetime = { 0.5, 0.9 },
		speed = { 6, 10 },
		spread = 180,
		rate = 0,
		acceleration = Vector3.new(0, -6, 0),
		drag = 3,
		lightEmission = 0.5,
		rotSpeed = { -180, 180 },
	},
	-- The Rift Run (Effects/RiftRun): the rift's swirl of light, the warp stars rushing past the camera, a meteor's
	-- fire trail and the sparks where it lands
	riftSwirl = {
		texture = Presets.textures.sparkle,
		colors = {
			Color3.fromRGB(255, 220, 245),
			Color3.fromRGB(255, 120, 200),
			Color3.fromRGB(150, 110, 255),
		},
		size = { 1.2, 0 },
		transparency = { 0.1, 1 },
		lifetime = { 0.8, 1.4 },
		speed = { 3, 7 },
		spread = 180,
		rate = 40,
		drag = 2,
		lightEmission = 1,
		rotSpeed = { -90, 90 },
	},
	-- Snowglobe Village (Effects/SnowglobeFx): the Town Square globe's icy swirl, the Rift's swirl in snow colours
	globeSwirl = {
		texture = Presets.textures.sparkle,
		colors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(190, 225, 255),
			Color3.fromRGB(140, 190, 255),
		},
		size = { 0.9, 0 },
		transparency = { 0.15, 1 },
		lifetime = { 1.2, 2 },
		speed = { 1.5, 3.5 },
		spread = 180,
		rate = 24,
		drag = 1.5,
		lightEmission = 1,
		rotSpeed = { -60, 60 },
	},
	riftStreak = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 190, 255) },
		size = { 0.25, 0.05 },
		transparency = { 0.2, 1 },
		lifetime = { 0.25, 0.4 },
		speed = { 50, 70 },
		spread = 35,
		rate = 0,
		lightEmission = 1,
	},
	riftMeteorFire = {
		texture = Presets.textures.smoke,
		colors = {
			Color3.fromRGB(255, 230, 150),
			Color3.fromRGB(255, 130, 60),
			Color3.fromRGB(110, 50, 60),
		},
		size = { 2.6, 0.4 },
		transparency = { 0.05, 1 },
		lifetime = { 0.35, 0.6 },
		speed = { 0, 1 },
		spread = 180,
		rate = 70,
		lightEmission = 1,
		rotSpeed = { -120, 120 },
	},
	riftSpark = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 140, 60) },
		size = { 0.7, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.4, 0.8 },
		speed = { 10, 18 },
		spread = 70,
		rate = 0,
		acceleration = Vector3.new(0, -30, 0),
		drag = 1,
		lightEmission = 1,
	},
	-- The Ruins' falling water (Effects/RuinsWater): pale streaks sliding down a waterfall's or a fountain's sheet,
	-- emitted through the sheet part itself, so the sheet reads as running water.
	fallStreaks = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 0.35, 0.2 },
		transparency = { 0.35, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 5, 7 },
		spread = 4,
		rate = 14,
		acceleration = Vector3.new(0, -10, 0),
		lightEmission = 0.2,
	},
	-- Soft spray rising where the water lands in the pool (Effects/RuinsWater).
	fallMist = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 1.2, 2.6 },
		transparency = { 0.6, 1 },
		lifetime = { 1.4, 2.2 },
		speed = { 0.6, 1.4 },
		spread = 60,
		rate = 4,
		drag = 0.8,
		lightEmission = 0.1,
	},
	-- The new areas' still water (Effects/AreaWater, #4070 and #4071): small glints that wink on a pool's surface,
	-- foam flecks drifting round the lazy river and the splash pad's jets spraying at their tops.
	poolGlint = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 1.1, 0.15 }, -- big enough to read from a standing camera (Review-QA, #4206: 0.45 was lost)
		transparency = { 0, 1 },
		lifetime = { 1, 1.6 },
		speed = { 0, 0 },
		spread = 0,
		rate = 5,
		lightEmission = 0.8,
	},
	-- the Castle Well's: its water is a few studs across, so smaller and fewer glints than a pool's
	wellGlint = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 0.5, 0.1 },
		transparency = { 0, 1 },
		lifetime = { 1, 1.6 },
		speed = { 0, 0 },
		spread = 0,
		rate = 2,
		lightEmission = 0.8,
	},
	riverFoam = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 0.5, 0.3 },
		transparency = { 0.45, 1 },
		lifetime = { 2.2, 3.2 },
		speed = { 1.6, 2.4 },
		spread = 6,
		rate = 2.5,
		lightEmission = 0.15,
	},
	padSpray = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 0.22, 0.12 },
		transparency = { 0.3, 1 },
		lifetime = { 0.6, 0.9 },
		speed = { 5, 7 },
		spread = 28,
		rate = 9,
		acceleration = Vector3.new(0, -16, 0),
		lightEmission = 0.2,
	},
	-- A Cat Storm (Effects/StormFall, #4197): the puff where a storm stray lands, and the slow sparkles that drift
	-- down round you while the storm runs.
	stormPuff = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.offwhite },
		size = { 0.5, 0.1 },
		transparency = { 0.1, 1 },
		lifetime = { 0.5, 0.9 },
		speed = { 4, 7 },
		spread = 70,
		rate = 0,
		acceleration = Vector3.new(0, -8, 0),
		drag = 1,
		lightEmission = 0.5,
	},
	stormDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.offwhite },
		size = { 0.3, 0.15 },
		transparency = { 0.3, 1 },
		lifetime = { 3, 4 },
		speed = { 4, 6 },
		spread = 8,
		rate = 10,
		lightEmission = 0.4,
		rotSpeed = { -30, 30 },
	},
	-- #4197 admin events' air (Effects/AdminAir): Golden Hour's slow gold motes and Money Storm's quicker coin
	-- glints, falling round you while the event runs.
	goldHourDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.golden, Presets.palette.goldLight },
		size = { 0.55, 0.2 },
		transparency = { 0.1, 0.9 },
		lifetime = { 3.5, 4.5 },
		speed = { 3, 5 },
		spread = 8,
		rate = 10,
		lightEmission = 0.6,
		rotSpeed = { -40, 40 },
	},
	moneyStormDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.golden },
		size = { 0.75, 0.4 },
		transparency = { 0.1, 0.9 },
		lifetime = { 2.2, 3 },
		speed = { 9, 12 },
		spread = 8,
		rate = 14,
		lightEmission = 0.5,
		rotSpeed = { -200, 200 },
	},
	-- #4325: every admin event rains something (AdminFlashLogic.rainOf), each in its look's colours, and thinly:
	-- Derek 2026-11-14 22:54, "the money amount everywhere on screen is too much"
	adminRoseDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.neonPink, Presets.palette.furRose },
		size = { 0.6, 0.25 },
		transparency = { 0.1, 0.9 },
		lifetime = { 2.6, 3.4 },
		speed = { 6, 9 },
		spread = 8,
		rate = 11,
		lightEmission = 0.5,
		rotSpeed = { -120, 120 },
	},
	adminStormDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.fishBlue, Presets.palette.offwhite },
		size = { 0.5, 0.2 },
		transparency = { 0.1, 0.9 },
		lifetime = { 2, 2.8 },
		speed = { 10, 14 },
		spread = 8,
		rate = 11,
		lightEmission = 0.5,
		rotSpeed = { -60, 60 },
	},
	adminRainbowDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.neonPink, Presets.palette.fishBlue },
		size = { 0.6, 0.25 },
		transparency = { 0.1, 0.9 },
		lifetime = { 2.6, 3.4 },
		speed = { 6, 9 },
		spread = 8,
		rate = 11,
		lightEmission = 0.5,
		rotSpeed = { -160, 160 },
	},
	adminVioletDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.aurora, Presets.palette.offwhite },
		size = { 0.55, 0.2 },
		transparency = { 0.1, 0.9 },
		lifetime = { 3, 4 },
		speed = { 4, 6 },
		spread = 8,
		rate = 9,
		lightEmission = 0.6,
		rotSpeed = { -60, 60 },
	},
	adminBlueDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.fishBlue, Presets.palette.goldLight },
		size = { 0.6, 0.25 },
		transparency = { 0.1, 0.9 },
		lifetime = { 2.6, 3.4 },
		speed = { 6, 9 },
		spread = 8,
		rate = 10,
		lightEmission = 0.5,
		rotSpeed = { -120, 120 },
	},
	adminMintDrift = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.mint, Presets.palette.offwhite },
		size = { 0.5, 0.2 },
		transparency = { 0.1, 0.9 },
		lifetime = { 1.8, 2.4 },
		speed = { 12, 16 },
		spread = 8,
		rate = 11,
		lightEmission = 0.5,
		rotSpeed = { -90, 90 },
	},
	-- Soft sparkles rising off the guide trail's dots (Effects/TrailSparkle, #3022), recoloured to each dot.
	trailSparkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.offwhite },
		size = { 0.35, 0.1 },
		transparency = { 0.1, 1 },
		lifetime = { 0.8, 1.2 },
		speed = { 1.5, 2.5 },
		spread = 15,
		rate = 2,
		drag = 0.5,
		lightEmission = 1,
	},
	-- Water kicked up by a step in a puddle or a pond (Effects/Splash): small drops thrown up and falling back.
	splashDrops = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.fishBelly },
		size = { 0.2, 0.08 },
		transparency = { 0.1, 1 },
		lifetime = { 0.3, 0.45 },
		speed = { 5, 8 },
		spread = 30,
		rate = 0,
		acceleration = Vector3.new(0, -35, 0),
		lightEmission = 0.2,
	},
	-- The Mystic Pool's bubbles (#3314): a burst of round bubbles bobbing up off the liquid at each colour step,
	-- tinted that step's colour (Particles.burst's tint), glowing a little.
	poolBubble = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Presets.palette.milk },
		size = { 0.35, 0.15 },
		transparency = { 0.1, 1 },
		lifetime = { 0.5, 0.9 },
		speed = { 3, 6 },
		spread = 35,
		rate = 0,
		acceleration = Vector3.new(0, 4, 0),
		drag = 1.5,
		lightEmission = 0.6,
		rotSpeed = { -90, 90 },
	},
	-- A pipe's drip landing on the Lost and Found's lid (Effects/CampWater, F100): a few tiny drops hopping off it.
	dripSplash = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.fishBelly },
		size = { 0.09, 0.03 },
		transparency = { 0.15, 1 },
		lifetime = { 0.2, 0.3 },
		speed = { 1.5, 3 },
		spread = 55,
		rate = 0,
		acceleration = Vector3.new(0, -30, 0),
		lightEmission = 0.2,
	},
	gateSparkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle, Presets.palette.mint },
		size = { 0.7, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.8, 1.3 },
		speed = { 2, 5 },
		spread = 40,
		rate = 0,
		acceleration = Vector3.new(0, 4, 0),
		lightEmission = 0.5,
		rotSpeed = { -120, 120 },
	},
	-- A slow fall of sparkles from the top of a Mythical's beam or a jackpot wheel.
	shower = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite }, -- tinted when the burst is made
		size = { 0.5, 0 },
		transparency = { 0, 0.6 },
		lifetime = { 1.2, 1.8 },
		speed = { 1, 3 },
		spread = 180,
		rate = 0,
		acceleration = Vector3.new(0, -2.5, 0),
		drag = 1,
		lightEmission = 0.6,
		rotSpeed = { -90, 90 },
	},
	-- A soft violet haze rolling over an area gate as it closes for the night (F66).
	duskHaze = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.aurora, Presets.palette.furGrey },
		size = { 1.4, 3.6 },
		transparency = { 0.55, 1 },
		lifetime = { 1.2, 1.8 },
		speed = { 1, 2.5 },
		spread = 70,
		rate = 0,
		acceleration = Vector3.new(0, 0.6, 0),
		drag = 1.5,
	},
	-- Signature effects (Presets.signature): one steady emitter on a Legendary or Mythical themed cat, at Rate 2 or
	-- less, coloured per cat when it is made. Glints twinkle on the fur or a prop, `sigRise` drifts up (stars,
	-- sprinkles, sparks), `sigFall` flutters down (petals, leaves), `sigHalo` is a soft glow round the cat and
	-- `sigWhoosh` puffs behind a cat on the move. The sparkle sprite stands in for petals and leaves until our own
	-- sprites are uploaded.
	sigGlint = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle },
		size = { 0.25, 0 },
		transparency = { 0, 1 },
		lifetime = { 0.5, 0.9 },
		speed = { 0, 0.3 },
		spread = 180,
		rate = 1.5,
		lightEmission = 0.8,
		rotSpeed = { -60, 60 },
	},
	sigRise = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle },
		size = { 0.24, 0.06 },
		transparency = { 0.1, 1 },
		lifetime = { 1.4, 2.2 },
		speed = { 0.4, 0.9 },
		spread = 30,
		rate = 2,
		acceleration = Vector3.new(0, 0.5, 0),
		drag = 0.4,
		lightEmission = 0.7,
		rotSpeed = { -45, 45 },
	},
	-- #4070 the Water Park's air: fine spray off the slides and pools, small bright drops that lift a little and
	-- fall, catching the light. #4071 the Medieval Castle's air: slow warm motes of dust in torch and banner gold.
	waterparkSpray = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 226, 250) },
		size = { 0.16, 0.08 },
		transparency = { 0.25, 1 },
		lifetime = { 1.4, 2.2 },
		speed = { 0.8, 2 },
		spread = 70,
		rate = 9,
		acceleration = Vector3.new(0.4, -2.2, 0.2),
		drag = 0.4,
		lightEmission = 0.3,
	},
	castleMotes = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(255, 226, 150), Color3.fromRGB(226, 170, 96) },
		size = { 0.14, 0.08 },
		transparency = { 0.4, 1 },
		lifetime = { 3.5, 5 },
		speed = { 0.15, 0.5 },
		spread = 180,
		rate = 7,
		acceleration = Vector3.new(0.2, 0.12, 0.1),
		drag = 0.4,
		lightEmission = 0.25,
	},
	-- #4069 Snowy Mountain. `snowfall` is the area's air: soft flakes drifting down round you, with a little sideways
	-- drift, fading before they pile up. The three sig* ones are its rarer cats' (Presets.signature): `sigFrost` a
	-- puff of frosty breath off the White Tiger Cat's head, `sigSnowflake` the flakes the Blizzard Cat's swirl leaves
	-- behind as it circles, and `sigFrostTrail` the frost it leaves where it walks.
	snowfall = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 240, 255) },
		size = { 0.22, 0.16 },
		transparency = { 0.15, 1 },
		lifetime = { 3, 4.5 },
		speed = { 0.4, 1.2 },
		spread = 180,
		rate = 14,
		acceleration = Vector3.new(0.6, -1.6, 0.3),
		drag = 0.5,
		rotSpeed = { -40, 40 },
	},
	sigFrost = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(236, 246, 255) },
		size = { 0.25, 0.9 },
		transparency = { 0.55, 1 },
		lifetime = { 0.9, 1.4 },
		speed = { 0.5, 1 },
		spread = 25,
		rate = 0.8,
		acceleration = Vector3.new(0, 0.3, 0),
		drag = 1.2,
	},
	sigSnowflake = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 255, 255) },
		size = { 0.3, 0.05 },
		transparency = { 0, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0, 0.15 },
		spread = 180,
		rate = 2,
		lightEmission = 0.6,
		rotSpeed = { -90, 90 },
	},
	sigFrostTrail = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(214, 236, 255), Color3.fromRGB(255, 255, 255) },
		size = { 0.5, 1.1 },
		transparency = { 0.5, 1 },
		lifetime = { 0.9, 1.3 },
		speed = { 0.1, 0.4 },
		spread = 70,
		rate = 2,
		acceleration = Vector3.new(0, -0.6, 0),
		drag = 2,
	},
	-- The Rares of the new areas (`minor` in Presets.signature). `sigSnowKick`: a little snow kicked up behind the
	-- Snow Boots Cat and the Ski Cat (#4069), sugar off the Cotton Candy Cat (#4070) and a wisp of shadow behind the
	-- Rogue Cat (#4071), only while they move; smaller, fainter and shorter lived than the Blizzard Cat's frost
	-- trail. `sigGlintSmall`: a glint about half as often as an Epic's, for the Candy Apple Cat's glaze and the
	-- Jester Cat's bells.
	sigGlintSmall = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle },
		size = { 0.2, 0 },
		transparency = { 0.15, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0, 0.2 },
		spread = 180,
		rate = 0.8,
		lightEmission = 0.8,
		rotSpeed = { -60, 60 },
	},
	sigSnowKick = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(255, 255, 255) },
		size = { 0.3, 0.7 },
		transparency = { 0.65, 1 },
		lifetime = { 0.4, 0.6 },
		speed = { 0.2, 0.6 },
		spread = 50,
		rate = 1.5,
		acceleration = Vector3.new(0, -1.2, 0),
		drag = 2,
	},
	-- #4070 the Water Park's rarer cats (Presets.signature): `sigDrip` drops falling off a water blaster or a cat made
	-- of water, `sigBubble` the bubbles the Water Cat's swirl leaves as it circles, and `sigWetTrail` the splashes
	-- it leaves where it walks.
	sigDrip = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(170, 226, 250) },
		size = { 0.13, 0.05 },
		transparency = { 0.1, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0.2, 0.6 },
		spread = 40,
		rate = 1.6,
		acceleration = Vector3.new(0, -9, 0),
		lightEmission = 0.3,
	},
	sigBubble = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 255, 255) },
		size = { 0.22, 0.3 },
		transparency = { 0.2, 1 },
		lifetime = { 0.6, 0.9 },
		speed = { 0.1, 0.3 },
		spread = 180,
		rate = 2,
		acceleration = Vector3.new(0, 0.8, 0),
		lightEmission = 0.5,
	},
	sigWetTrail = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(150, 220, 250), Color3.fromRGB(255, 255, 255) },
		size = { 0.18, 0.06 },
		transparency = { 0.2, 1 },
		lifetime = { 0.4, 0.6 },
		speed = { 1.5, 3 },
		spread = 60,
		rate = 2,
		acceleration = Vector3.new(0, -14, 0),
		lightEmission = 0.2,
	},
	-- #4071 the Medieval Castle's Dragon Knight (Presets.signature): `sigEmber` the embers its circling sparks leave
	-- behind, and `sigEmberTrail` the warm sparks that scatter low where it walks and die out. Harmless little lights,
	-- no flame.
	sigEmber = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 190, 90) },
		size = { 0.26, 0.04 },
		transparency = { 0, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0.1, 0.3 },
		spread = 180,
		rate = 2,
		acceleration = Vector3.new(0, 0.9, 0),
		lightEmission = 0.8,
		rotSpeed = { -60, 60 },
	},
	sigEmberTrail = {
		texture = Presets.textures.sparkle,
		colors = { Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 220, 140) },
		size = { 0.2, 0.03 },
		transparency = { 0.1, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 0.6, 1.4 },
		spread = 70,
		rate = 2,
		acceleration = Vector3.new(0, -1.5, 0),
		drag = 1.5,
		lightEmission = 0.7,
	},
	sigFall = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.furRose },
		size = { 0.32, 0.22 },
		transparency = { 0, 1 },
		lifetime = { 1.4, 2 },
		speed = { 0.2, 0.6 },
		spread = 90,
		rate = 1,
		acceleration = Vector3.new(0.3, -0.35, 0), -- a slow drift down that fades before it reaches the floor
		drag = 0.8,
		rotSpeed = { -120, 120 },
	},
	sigHalo = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.galaxyBlue },
		size = { 1.2, 1.8 },
		transparency = { 0.75, 1 },
		lifetime = { 1.6, 2.4 },
		speed = { 0, 0.2 },
		spread = 180,
		rate = 1.5,
		drag = 1,
		lightEmission = 1,
	},
	sigWhoosh = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite },
		size = { 0.5, 1.2 },
		transparency = { 0.6, 1 },
		lifetime = { 0.4, 0.6 },
		speed = { 0, 0.2 },
		spread = 20,
		rate = 2,
		drag = 2,
	},
	-- Motes rising off the Codes Cat's walk-in circle (F65), from the whole circle.
	codesMotes = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.mint, Presets.palette.sparkle },
		size = { 0.4, 0 },
		transparency = { 0.1, 1 },
		lifetime = { 1.2, 1.8 },
		speed = { 0.6, 1.2 },
		spread = 8,
		rate = 2,
		lightEmission = 0.8,
	},
	-- Mythical decor (F53): a glint now and then over Glimmer Canal's floor or a Gold Leaf front, tinted by the piece.
	-- Rainbow cat sparkles dropping behind it as it moves (F99), shifting through the hues as they fade in 0.8 s.
	rainbowTrail = {
		texture = Presets.textures.sparkle,
		colors = {
			Color3.fromRGB(255, 72, 88),
			Color3.fromRGB(255, 222, 60),
			Color3.fromRGB(84, 214, 112),
			Color3.fromRGB(72, 182, 255),
			Color3.fromRGB(168, 108, 255),
		},
		size = { 0.3, 0 },
		transparency = { 0, 0.6 },
		lifetime = { 0.6, 0.8 },
		speed = { 0, 0.3 },
		spread = 180,
		rate = 8,
		lightEmission = 0.8,
		rotSpeed = { -120, 120 },
	},
	decorGlint = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Presets.palette.sparkle },
		size = { 0.4, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.4, 0.8 },
		speed = { 0, 0.2 },
		spread = 180,
		rate = 2,
		lightEmission = 0.8,
		rotSpeed = { -90, 90 },
	},
	-- Gold glints floating up off you as golden fish land in your wallet (Fish.luau).
	fishRise = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.sparkle },
		size = { 0.4, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.8, 1.3 },
		speed = { 2, 4 },
		spread = 30,
		rate = 0,
		acceleration = Vector3.new(0, 3, 0),
		drag = 1,
		lightEmission = 0.5,
		rotSpeed = { -120, 120 },
	},
	-- The Blossom Tree's petals fluttering down from its canopy, with a little sideways drift.
	decorPetals = {
		texture = Presets.textures.sparkle, -- a petal sprite once one is uploaded
		colors = { Presets.palette.furRose, Presets.palette.blush, Presets.palette.offwhite },
		size = { 0.35, 0.28 },
		transparency = { 0, 0.5 },
		lifetime = { 3, 4.5 },
		speed = { 0.2, 0.6 },
		spread = 180,
		rate = 2,
		acceleration = Vector3.new(0.2, -0.6, 0),
		drag = 0.8,
		rotSpeed = { -90, 90 },
	},
	-- Potion glows (F64), one per kind, on a drinker while the potion runs (Potions.luau). Tip: gold glints drifting
	-- up off the body (a coin sprite once one is uploaded); Lucky: green and mint glints all round; Swift: blue wisps
	-- left behind at the feet; Steady Paw: soft mint sparkles on the paws, split between the two hands.
	potionTip = {
		texture = Presets.textures.sparkle, -- a coin sprite once one is uploaded
		colors = { Presets.palette.golden, Presets.palette.goldLight },
		size = { 0.45, 0.35 },
		transparency = { 0, 1 },
		lifetime = { 1.3, 1.9 },
		speed = { 0.8, 1.3 },
		spread = 15,
		rate = 2.5,
		acceleration = Vector3.new(0, 0.2, 0),
		drag = 0.6,
		lightEmission = 0.5,
		rotSpeed = { -180, 180 },
	},
	potionLucky = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.leaf, Presets.palette.mint, Presets.palette.sparkle },
		size = { 0.4, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.8, 1.2 },
		speed = { 0.1, 0.4 },
		spread = 180,
		rate = 2,
		drag = 1,
		lightEmission = 0.7,
		rotSpeed = { -90, 90 },
	},
	potionSwift = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.fishBlue, Presets.palette.pastelSky },
		size = { 0.5, 1.1 },
		transparency = { 0.45, 1 },
		lifetime = { 0.4, 0.6 },
		speed = { 0.3, 0.6 },
		spread = 40,
		rate = 4,
		acceleration = Vector3.new(0, 0.5, 0),
		drag = 1,
		lightEmission = 0.4,
	},
	-- The Speed Shoes' trail (#3523, Effects/SpeedShoes): small mint and cream puffs left at the heels of a wearer who
	-- carries a cat on the move. Thinner and shorter than the Swift Potion's blue wisps, so the two read apart.
	-- #4558: Fire Trail's embers, at the heels of a walker with the Dragon Keep card (Effects/FireTrail)
	fireTrail = {
		texture = Presets.textures.sparkle,
		colors = {
			Color3.fromRGB(255, 130, 50),
			Color3.fromRGB(255, 205, 110),
			Color3.fromRGB(255, 240, 200),
		},
		size = { 0.35, 0.05 },
		transparency = { 0.05, 1 },
		lifetime = { 0.45, 0.8 },
		speed = { 0.4, 1.2 },
		spread = 60,
		rate = 12,
		acceleration = Vector3.new(0, 1.8, 0),
		drag = 1.5,
		lightEmission = 0.8,
	},
	shoeTrail = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.mint, Presets.palette.offwhite },
		size = { 0.55, 0.15 },
		transparency = { 0.35, 1 },
		lifetime = { 0.3, 0.45 },
		speed = { 0.2, 0.5 },
		spread = 25,
		rate = 8,
		acceleration = Vector3.new(0, 0.6, 0),
		drag = 1.5,
		lightEmission = 0.3,
	},
	potionSteady = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.mint, Presets.palette.offwhite },
		size = { 0.32, 0.1 },
		transparency = { 0.1, 1 },
		lifetime = { 0.9, 1.4 },
		speed = { 0.1, 0.3 },
		spread = 180,
		rate = 2,
		acceleration = Vector3.new(0, 0.3, 0),
		drag = 1,
		lightEmission = 0.6,
		rotSpeed = { -60, 60 },
	},
	-- The quest potions (F73, quests.md section 4). Big Tip: a brighter, busier stream of gold glints than the Tip
	-- Potion's; Gold Rush: gold glints twinkling all round; Quick Bait: food crumbs falling from the paws.
	potionBigTip = {
		texture = Presets.textures.sparkle, -- a coin sprite once one is uploaded
		colors = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.sparkle },
		size = { 0.55, 0.4 },
		transparency = { 0, 1 },
		lifetime = { 1.3, 1.9 },
		speed = { 1, 1.6 },
		spread = 20,
		rate = 3.5,
		acceleration = Vector3.new(0, 0.2, 0),
		drag = 0.6,
		lightEmission = 0.7,
		rotSpeed = { -180, 180 },
	},
	potionGoldRush = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.golden, Presets.palette.offwhite },
		size = { 0.45, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.8, 1.2 },
		speed = { 0.1, 0.4 },
		spread = 180,
		rate = 2,
		drag = 1,
		lightEmission = 0.8,
		rotSpeed = { -90, 90 },
	},
	potionQuickBait = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.blush, Presets.palette.cream },
		size = { 0.18, 0.12 },
		transparency = { 0, 0.6 },
		lifetime = { 0.8, 1.2 },
		speed = { 0.2, 0.5 },
		spread = 60,
		rate = 2,
		acceleration = Vector3.new(0, -4, 0),
		drag = 0.5,
	},
	-- The Day Cart's Tier 6 potions (#3462): each its smaller kind's glow, a little bigger and busier, with one more
	-- colour so the two can be told apart side by side. Big Lucky: green, mint and gold glints with a few larger
	-- ones; Big Gold Rush: gold glints that drift up as they twinkle; Mega Money: a wide, bright stream of gold.
	potionBigLucky = {
		texture = Presets.textures.sparkle,
		colors = {
			Presets.palette.leaf,
			Presets.palette.mint,
			Presets.palette.golden,
			Presets.palette.sparkle,
		},
		size = { 0.55, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.9, 1.4 },
		speed = { 0.2, 0.6 },
		spread = 180,
		rate = 3.5,
		drag = 1,
		lightEmission = 0.8,
		rotSpeed = { -90, 90 },
	},
	potionBigGoldRush = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.golden, Presets.palette.offwhite },
		size = { 0.6, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 1, 1.5 },
		speed = { 0.2, 0.6 },
		spread = 180,
		rate = 3.5,
		acceleration = Vector3.new(0, 0.6, 0),
		drag = 1,
		lightEmission = 0.9,
		rotSpeed = { -90, 90 },
	},
	potionMegaTip = {
		texture = Presets.textures.sparkle, -- a coin sprite once one is uploaded
		colors = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.sparkle },
		size = { 0.7, 0.45 },
		transparency = { 0, 1 },
		lifetime = { 1.4, 2 },
		speed = { 1.2, 1.9 },
		spread = 30,
		rate = 4,
		acceleration = Vector3.new(0, 0.2, 0),
		drag = 0.6,
		lightEmission = 0.8,
		rotSpeed = { -180, 180 },
	},
	-- A faint twinkle over the owner's own Mystery Visitor gift while it waits (Mystery.luau).
	-- The first wow bowl cat's soft sparkle (#4822, Effects/WowBaitGlow): slow points round the body, tinted by its
	-- rarity; about a dozen alive at once (rate 6 times 2 s), under the phone budget's 15
	wowSparkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite },
		size = { 0.45, 0 },
		transparency = { 0.1, 0.8 },
		lifetime = { 1.5, 2.5 },
		speed = { 0.2, 0.6 },
		spread = 180,
		rate = 6,
		lightEmission = 0.8,
		rotSpeed = { -60, 60 },
	},
	-- The night stars over the Observatory (#4069, Effects/FusionFx): still, pale points that grow in and fade
	-- out, a few at a time over a wide box, so the sky over the telescope twinkles. Under 3 a second.
	observatoryStars = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Color3.fromRGB(200, 220, 255) },
		size = { 0.9, 0 },
		transparency = { 0.15, 0.85 },
		lifetime = { 1.6, 3 },
		speed = { 0, 0 },
		spread = 0,
		rate = 2.5,
		lightEmission = 1,
		rotSpeed = { -20, 20 },
	},
	giftTwinkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle, Presets.palette.offwhite },
		size = { 0.3, 0 },
		transparency = { 0.1, 0.6 },
		lifetime = { 0.5, 0.9 },
		speed = { 0, 0.3 },
		spread = 180,
		rate = 1.5,
		lightEmission = 0.8,
		rotSpeed = { -90, 90 },
	},
	-- The Cat Cannon (F84): sparks off the fuse as it fizzes, and the sparkle trail behind a flying player.
	fuseSpark = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle, Presets.palette.lampWarm, Presets.palette.golden },
		size = { 0.35, 0 },
		transparency = { 0, 0.3 },
		lifetime = { 0.15, 0.3 },
		speed = { 6, 11 },
		spread = 70,
		rate = 0,
		acceleration = Vector3.new(0, -20, 0),
		lightEmission = 1,
	},
	cannonTrail = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle, Presets.palette.mint, Presets.palette.offwhite },
		size = { 0.9, 0 },
		transparency = { 0, 0.5 },
		lifetime = { 0.4, 0.7 },
		speed = { 0.5, 2 },
		spread = 180,
		rate = 40,
		drag = 2,
		lightEmission = 0.7,
		rotSpeed = { -180, 180 },
	},
	-- Cats make the orders (F90, Effects/Orders): steam over the espresso machine while a drink is made, a flour puff
	-- over the oven while a bake is made, a few cool twinkles at the counter for the milk and the sundae, and the
	-- "ding" sparkle over the finished item.
	orderSteam = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite },
		size = { 0.3, 1.2 },
		transparency = { 0.4, 1 },
		lifetime = { 0.7, 1.1 },
		speed = { 2, 3.5 },
		spread = 15,
		rate = 0,
		acceleration = Vector3.new(0.2, 0.8, 0),
		drag = 1.5,
	},
	flourPuff = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.offwhite, Presets.palette.cream },
		size = { 0.25, 0.9 },
		transparency = { 0.3, 1 },
		lifetime = { 0.5, 0.8 },
		speed = { 1.5, 3 },
		spread = 60,
		rate = 0,
		acceleration = Vector3.new(0, 0.4, 0),
		drag = 3,
	},
	counterTwinkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Presets.palette.pastelSky },
		size = { 0.25, 0 },
		transparency = { 0, 1 },
		lifetime = { 0.35, 0.6 },
		speed = { 0.5, 1.5 },
		spread = 180,
		rate = 0,
		lightEmission = 0.4,
	},
	-- Coins off a swept tip pile and into the till (F90 section 2 step 5): gold glints hopping up and falling back.
	coinGlint = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.golden },
		size = { 0.35, 0.12 },
		transparency = { 0, 0.6 },
		lifetime = { 0.4, 0.6 },
		speed = { 3, 5 },
		spread = 35,
		rate = 0,
		acceleration = Vector3.new(0, -18, 0),
		lightEmission = 0.5,
		rotSpeed = { -180, 180 },
	},
	dingSparkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Presets.palette.sparkle }, -- tinted gold on the rich customer's plate
		size = { 0.5, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.4, 0.7 },
		speed = { 3, 6 },
		spread = 180,
		rate = 0,
		drag = 4,
		lightEmission = 0.6,
		rotSpeed = { -180, 180 },
	},
	-- Sprinkles' rainbow sprinkle puff (Effects/ShopCats, #1191): little sprinkles tossed up over the cat that tumble
	-- and fall, tinted one colour per burst.
	sprinkle = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite },
		size = { 0.3, 0.2 },
		transparency = { 0, 0.6 },
		lifetime = { 0.6, 0.9 },
		speed = { 3, 5 },
		spread = 50,
		rate = 0,
		acceleration = Vector3.new(0, -12, 0),
		drag = 1.5,
		lightEmission = 0.4,
		rotSpeed = { -360, 360 },
	},
	-- Duchess Marzipan's lilac petals (Effects/ShopCats, #1191): a few soft petals that drift out round her, turning
	-- slowly as they settle.
	lilacPetal = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(200, 170, 230), Presets.palette.furRose },
		size = { 0.22, 0.16 },
		transparency = { 0.15, 0.9 },
		lifetime = { 2.5, 3.5 },
		speed = { 0.4, 0.9 },
		spread = 120,
		rate = 1.5,
		acceleration = Vector3.new(0.15, -0.35, 0.1),
		drag = 0.6,
		rotSpeed = { -60, 60 },
	},
	-- Maple Muffin's autumn leaves (Effects/ShopCats, #1668): a few amber leaves turning rust as they fall off it
	-- while it works, rocking as they go. Mild on purpose (cafe-pass.md section 4).
	mapleLeaf = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(232, 140, 52), Color3.fromRGB(196, 84, 44) },
		size = { 0.24, 0.18 },
		transparency = { 0.1, 0.9 },
		lifetime = { 2.5, 3.5 },
		speed = { 0.3, 0.7 },
		spread = 140,
		rate = 1.2,
		acceleration = Vector3.new(0.2, -0.6, 0.1),
		drag = 0.7,
		rotSpeed = { -90, 90 },
	},
	-- #4251 Harvest Hollow's air (Effects/HarvestFx): amber, gold and rust leaves falling slowly round you, rocking
	-- as they go. Thin: it sits behind the strays and the pumpkins.
	harvestLeaves = {
		texture = Presets.textures.smoke,
		colors = { Color3.fromRGB(236, 160, 60), Color3.fromRGB(196, 84, 44) },
		size = { 0.3, 0.22 },
		transparency = { 0.1, 0.9 },
		lifetime = { 4, 5.5 },
		speed = { 0.4, 1 },
		spread = 40,
		rate = 8,
		acceleration = Vector3.new(0.5, -1.2, 0.2),
		drag = 0.5,
		rotSpeed = { -90, 90 },
	},
	-- King Croissant's gold motes (Effects/ShopCats, #1191): a slow drift of tiny warm gold lights rising off him.
	goldMote = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.golden },
		size = { 0.14, 0.05 },
		transparency = { 0.2, 1 },
		lifetime = { 2, 3 },
		speed = { 0.2, 0.5 },
		spread = 70,
		rate = 2,
		acceleration = Vector3.new(0, 0.25, 0),
		drag = 0.6,
		lightEmission = 1,
	},
	-- The stray waiting for your second cat (Effects/WaitingCat, #3022): gold sparkles rising off it like a beacon.
	waitBeacon = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.goldLight, Presets.palette.golden },
		size = { 0.45, 0.12 },
		transparency = { 0, 1 },
		lifetime = { 1.6, 2.2 },
		speed = { 3, 5 },
		spread = 10,
		rate = 8,
		drag = 0.4,
		lightEmission = 1,
	},
	-- A glint on a leaderboard crown (Effects/Crown, F98): a few gold stars that flash and fade where they are.
	-- Lawn pieces (Effects/Lawn, #1283). The Little Fountain's spill: small drops tipping off the upper bowl's rim
	-- and falling into the basin.
	fountainDrops = {
		texture = Presets.textures.smoke,
		colors = { Presets.palette.milk, Presets.palette.pastelSky },
		size = { 0.14, 0.06 },
		transparency = { 0.2, 0.9 },
		lifetime = { 0.45, 0.7 },
		speed = { 0.8, 1.6 },
		spread = 100,
		rate = 8,
		acceleration = Vector3.new(0, -14, 0),
		lightEmission = 0.2,
	},
	-- A few slow fireflies round a lawn lamp or the Fairy Light Arch at night: fewer and smaller than the woods'.
	lawnFireflies = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.lampWarm, Presets.palette.sparkle },
		size = { 0.25, 0.12 },
		transparency = { 0.1, 1 },
		lifetime = { 3, 4.5 },
		speed = { 0.15, 0.45 },
		spread = 180,
		rate = 1,
		lightEmission = 1,
		drag = 0.5,
	},
	crownGlint = {
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.offwhite, Presets.palette.goldLight, Presets.palette.golden },
		size = { 0.55, 0 },
		transparency = { 0, 0.3 },
		lifetime = { 0.35, 0.6 },
		speed = { 0, 0.4 },
		spread = 180,
		rate = 0,
		lightEmission = 0.9,
		rotSpeed = { -120, 120 },
	},
} :: { [string]: EmitterPreset }

-- Burst sizes before burstScale. A catch sparkle grows with rarity and stays under 30 (skill section 6).
Presets.bursts = {
	hissPuff = 10,
	smokePuff = 12,
	dust = 6,
	gateSparkle = 24,
	purrfect = 28,
	duskHaze = 4, -- at dusk, at each of the areas.points places along an area gate
	shower = 8, -- each of a Mythical catch's or a jackpot spin's showers
	fuseSpark = 3, -- each fizz of a cannon's fuse
}

-- A gold coat seen for the first time (a gold cat caught or rescued, F42): this many sparkles from the gold
-- cat's emitter and a golden ring.
Presets.reveal = { sparkles = 20 }
Presets.catchSparkle = {
	Common = 8,
	Rare = 12,
	Epic = 16,
	Legendary = 22,
	Mythical = 28,
	Secret = 28, -- the cap; a Secret's step up is its taller beam, third ring and extra showers (catchPop.secret)
} :: { [string]: number }

-- Confetti is small parts, not particles, so it needs no texture: the palette's party colours.
Presets.confettiColors = {
	Presets.palette.mint,
	Presets.palette.blush,
	Presets.palette.lampWarm,
	Presets.palette.aurora,
	Presets.palette.fishBlue,
	Presets.palette.offwhite,
}
Presets.purrfectColors =
	{ Presets.palette.golden, Presets.palette.sparkle, Presets.palette.offwhite }

Presets.confetti = {
	size = Vector3.new(0.35, 0.05, 0.22),
	seconds = 1.8, -- life of one piece; it fades over the last 0.4 s
	upSpeed = { 16, 24 }, -- studs per second at launch
	sideSpeed = { 6, 12 },
	gravity = 12, -- with the drag it falls at about 4 studs a second, so it flutters back to launch height
	drag = 3,
	flutter = 0.8, -- studs of side to side sway while it falls
	maxLive = 80, -- pieces alive at once on any device
}

Presets.ring = {
	diameter = 9, -- studs at the end of the Purrfect and gate ring
	seconds = 0.5,
}

-- A beam of light that shoots up from a spot and fades: a Legendary or Mythical catch, your own rank up. One
-- flash; skipped with Reduce Motion like the ring.
Presets.beam = { grow = 0.25, holdShare = 0.4 } -- of its seconds: rising, then held before it fades

-- Everyday moments (Derek 2026-10-27 20:13: effects "for basic stuff in game like catching or clicking upgrade or
-- unlocking new tiers or landing on a good item on the spin the wheel"). A catch pops in the rarity's colour: a
-- ring under the cat as wide as `ring`, confetti from Epic up (`confetti`, a share of the budget's confetti), a beam
-- from Legendary up and for a Mythical a second, wider ring and three slow sparkle showers from the top of the beam.
Presets.catchPop = {
	ring = { Common = 4, Rare = 5, Epic = 7, Legendary = 9, Mythical = 11, Secret = 13 } :: { [string]: number },
	ringSeconds = 0.5,
	confetti = { Epic = 0.4, Legendary = 0.6, Mythical = 0.9, Secret = 1 } :: { [string]: number },
	beams = { Legendary = true, Mythical = true, Secret = true } :: { [string]: boolean },
	beam = { width = 1.4, height = 16, seconds = 1.3 },
	echo = { after = 0.16, scale = 1.4, seconds = 0.7 }, -- the Mythical's second ring
	shower = { bursts = 3, after = 0.3, every = 0.25, height = 9 },
	-- A Secret (#3470, "the catch effect one step above Mythical"): everything a Mythical gets, with a wider and
	-- taller beam that lasts longer, a third and widest ring `third.after` seconds in, and `bursts` showers.
	secret = {
		beam = { width = 1.9, height = 26, seconds = 1.7 },
		third = { after = 0.34, scale = 1.85, seconds = 0.9 },
		bursts = 5,
	},
}

-- #4069 (Derek 2026-11-13: "make the rarer ones more special"): a catch in an area with a flavour adds the area's
-- own touch on top of the rarity pop, more the rarer the cat. Each step names the rarity it starts at: a `puff` of
-- `preset` in `colour` at the cat for every catch, `flakes` sparkles from `flakesFrom` up, a second ground ring
-- `ringScale` times the rarity's from `ringFrom` up, and from `gustsFrom` up `gusts` puffs climbing `gustHeight`
-- studs, `gustEvery` seconds apart. A cat named in `cats` gets `gusts` more.
export type CatchFlavour = {
	preset: string,
	colour: Color3,
	puff: number,
	flakes: number,
	flakesFrom: string,
	ringScale: number,
	ringFrom: string,
	gusts: number,
	gustsFrom: string,
	gustHeight: number,
	gustEvery: number,
	cats: { [string]: number },
}
Presets.catchFlavour = {
	ranks = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5, Secret = 6 } :: { [string]: number },
	areas = {
		-- the Snowy Mountain: a puff of snow, then flakes, a frost ring, and a column of snow gusts for the rarest
		snowy = {
			preset = "smokePuff",
			colour = Color3.fromRGB(236, 246, 255),
			puff = 4,
			flakes = 10,
			flakesFrom = "Epic",
			ringScale = 1.3,
			ringFrom = "Legendary",
			gusts = 3,
			gustsFrom = "Mythical",
			gustHeight = 8,
			gustEvery = 0.18,
			cats = { blizzard = 2 }, -- the snowstorm itself: a taller column
		},
		-- #4070 the Water Park: a splash, then bright drops, a ripple ring, and a little fountain for the rarest
		waterpark = {
			preset = "splashDrops",
			colour = Color3.fromRGB(150, 220, 250),
			puff = 6,
			flakes = 10,
			flakesFrom = "Epic",
			ringScale = 1.3,
			ringFrom = "Legendary",
			gusts = 3,
			gustsFrom = "Mythical",
			gustHeight = 7,
			gustEvery = 0.15,
			cats = { water = 2 }, -- the water itself: a taller fountain
		},
		-- #4071 the Medieval Castle: gold sparkles, more of them, a gold ring, and a rising fanfare of sparkles
		castle = {
			preset = "catchSparkle",
			colour = Color3.fromRGB(255, 214, 120),
			puff = 6,
			flakes = 12,
			flakesFrom = "Epic",
			ringScale = 1.3,
			ringFrom = "Legendary",
			gusts = 3,
			gustsFrom = "Mythical",
			gustHeight = 8,
			gustEvery = 0.18,
			cats = { dragon_knight = 2 }, -- a taller fanfare for the Dragon Knight
		},
		-- #4251 Harvest Hollow (area id "harvest"): a puff of pumpkin orange, then gold sparkles, a warm ring, and
		-- climbing orange puffs for the rarest
		harvest = {
			preset = "smokePuff",
			colour = Color3.fromRGB(232, 140, 60),
			puff = 6,
			flakes = 10,
			flakesFrom = "Epic",
			ringScale = 1.3,
			ringFrom = "Legendary",
			gusts = 3,
			gustsFrom = "Mythical",
			gustHeight = 7,
			gustEvery = 0.15,
			cats = { harvest_moon = 2 }, -- the moon over the hollow: a taller column
		},
	} :: { [string]: CatchFlavour },
}

-- Something you bought appears at your cafe (a table set, the espresso machine, the bait bowl, decor): a sparkle
-- above it, a mint ring at its foot as wide as it plus `ringPad` (at most `ringMost`), a puff of dust and a few
-- confetti. A purchase with nothing new to show (the net, a food) gives a sparkle swirl at your feet instead. A
-- piece counts when it appeared up to `before` seconds before the purchase showed or up to `after` seconds after.
Presets.purchase = {
	before = 1.5,
	after = 1,
	within = 120, -- studs from the player
	sparkle = 14, -- gateSparkle particles above the piece
	dust = 6,
	ringPad = 3,
	ringMost = 10,
	ringSeconds = 0.55,
	confetti = 0.3, -- of the budget's confetti
	swirlRing = 5,
	swirl = { 12, 8 }, -- gateSparkle particles at the feet, `swirlGap` seconds apart
	swirlGap = 0.3,
}

-- Cat motion. Angles in degrees, distances in studs, times in seconds.
Presets.motion = {
	-- #4601 strayWalkSlow (Model-Agent's server step of a stray walk at 10 Hz): Cats eases each server step in over
	-- this long instead of snapping to it (Pose.read's `ease`); read straight off the switch, off by default.
	-- While the server's walk is set on the model (WalkFrom, WalkTo, WalkSpeed, WalkAt, Model-Agent's #5139) the cat is
	-- drawn exactly where that walk has it now, and only a write's small miss, or the walk starting and ending, is eased
	-- (Sync's Alley runs: an ease that trailed the writes, and then a guess at the speed, both wobbled)
	stepEase = { flag = "strayWalkSlow", seconds = 0.1 },
	breathe = { studs = 0.03, seconds = 2.6 },
	-- The shape of one breath while asleep or resting (Logic.breath): the belly fills over `inhale` of the cycle,
	-- lets out over `exhale`, and rests for the rest. The nap, loaf and doze give the length and the rise.
	breath = { inhale = 0.38, exhale = 0.47 },
	-- How the body swells as it breathes in (Pose): sideways by `side` of the rise, so the belly fills out rather
	-- than the back just getting taller. Pieces ride the swell by how high their joint sits on the body.
	belly = { side = 0.5 },
	tailSwish = { degrees = 18, seconds = 2.2 },
	headLook = { degrees = 14, seconds = 5.5 },
	hiss = {
		seconds = 0.6,
		hop = 1.3, -- peak height of the jump back
		headBack = 22,
		tailUp = 40,
		jumpStuds = 3, -- a server move longer than this during a hiss is drawn as part of the hop
	},
	-- A near miss (F93, catch-rework.md section 1): a free stray within NetMissHopStuds of a swing that hit nothing
	-- springs `hop` studs up over `seconds` as the server sends it off (HopAt), nose up `lean` degrees, tail up `tailUp`
	-- and ears flat back `ears`, without the hiss: startled, then away at a run.
	startle = { seconds = 0.4, hop = 0.8, lean = 10, tailUp = 35, ears = 40 },
	-- #3022: the stray waiting for your second cat calls you over (Effects/StrayCall, Logic.beckon): within `near`
	-- studs, every `every` seconds it does `hops` small hops `hop` studs high in the first `hopShare` of `seconds`,
	-- its head turned to you (at most `look` degrees) and tipped up `lookUp`, ears forward, its tail up `tailUp` and
	-- flicking `flicks` times `flick` degrees either way. Off with Reduce Motion.
	beckon = {
		near = 30,
		every = 3.5,
		check = 0.25,
		seconds = 1.4,
		hops = 2,
		hop = 0.35,
		hopShare = 0.55,
		look = 60,
		lookUp = 14,
		tailUp = 30,
		flick = 28,
		flicks = 3,
	},
	barista = { tapEvery = 1.6, headDip = 12, paw = 35 },
	-- The Barista's working bob while it makes an order (F90, cats-make-orders.md section 2: "two small hops and a head
	-- tilt, on a loop"; Logic.makingBob and makingPose, drawn by Cats.luau while the cat's local Making attribute is
	-- set): each `seconds` loop it hops `hops` times, `height` studs off its seat over `hopSeconds` each with its front
	-- paws lifting `paws` degrees, pauses `tiltGap`, then tilts its head `tilt` degrees over `tiltSeconds`, the other
	-- way the next loop; its tail is up `tail` throughout. It eases in and out over `ease` seconds. With Reduce Motion
	-- only the tilt plays.
	making = {
		seconds = 1.5,
		hops = 2,
		hopSeconds = 0.24,
		height = 0.1,
		paws = 10,
		tiltGap = 0.1,
		tilt = 14,
		tiltSeconds = 0.6,
		tail = 15,
		ease = 0.2,
	},
	-- A waiter watching the room from its station (Derek 2026-10-29 19:45: cats should move around the cafe, "not just
	-- waddle back and fourth while sitting"; it used to rock side to side with a little hop): the head turns `look`
	-- degrees from table to table over `lookSeconds`, and tilts `tilt` now and then, once every `tiltEvery`. Its walks
	-- round the tables are Presets.cafeWalk.
	waiter = { look = 22, lookSeconds = 7, tilt = 8, tiltEvery = 5.5 },
	greeter = { waveEvery = 3.2, wave = 70, tilt = 10 },
	-- Working cats on the work body (S, Model-Agent #826; Derek 2026-11-02 12:02: "S: chibi holding the prop"),
	-- standing at the station on their back legs with the role's arm pose already on the model (the server turns
	-- each arm by cat_poses.work_<role>), so every turn here is small, none past about 15 degrees, and the held thing
	-- stays where Model-Agent's clip sweep checked it (Logic.workIdle). Each shifts its weight from foot to foot, the
	-- body rocking `sway` degrees over `swaySeconds`.
	-- `barista`: holds its cup out to the customer and now and then (`every`) offers it over `seconds`: the arm
	--   lifts `lift` degrees, the cup tips `held` towards them and the cat looks down at it `look`.
	-- `waiter`: the tray held steady at its side (it rides the breath and the sway) while the head turns `look` from
	--   table to table over `lookSeconds` and tilts `tilt` once every `tiltEvery`.
	-- `greeter`: the raised paw waves side to side `wave` degrees `hz` times a second, in bursts of `seconds` once
	--   every `every`, the head tilting `tilt` towards it; between bursts the paw drifts `rest` over `restSeconds`.
	-- `entertainer`: sings into the mic held up under its chin: once a `beat` the head nods `nod` and the mic tips
	--   `mic` with it, the body sways `sway` over two beats and the free paw, down at its side, swings `swing`
	--   forward and back with the sway (Derek 2026-11-02 19:34: the mic at the hip with the other paw waving
	--   "looks a little bit off").
	work = {
		sway = 2.5,
		swaySeconds = 4.8,
		barista = { every = 2.6, seconds = 1, lift = 8, held = 10, look = 10 },
		waiter = { look = 22, lookSeconds = 7, tilt = 8, tiltEvery = 5.5 },
		greeter = {
			every = 3.2,
			seconds = 1.6,
			wave = 14,
			hz = 2,
			tilt = 10,
			rest = 3,
			restSeconds = 3.7,
		},
		entertainer = { beat = 0.5, nod = 6, mic = 6, sway = 4, swing = 10 },
	},
	-- The entertainer bats a pom-pom on a springy wand stuck in its perch (Derek 2026-10-28 17:41: Comet's ball was
	-- "kind of floating" and its foot "randomly" twitched; the old yarn ball slid about in mid air 2 studs past the
	-- cat tree's top, which the paw never reached). The paws take turns once every `every` seconds: the paw comes
	-- up over `windup`, faster and faster, meets the pom-pom from behind raised `reach` degrees, holds it `hold`, and
	-- goes down again over `back`. A paw is one stiff piece, so it never lifts over the pom-pom, which would pass
	-- through it. The pom-pom rests just ahead of that paw's pad, `pom` studs across, on a `wand` thick wand from
	-- `wandBase` (studs ahead of the cat, on the perch). Each bat sends it away `tilt` degrees, `side` of that off to
	-- the far side, and it springs back and wobbles at `hz` a second, dying away `decay` times a second. The head
	-- looks down `look` degrees at it and turns after it by `follow` of its sway; the body leans into each bat `lean`.
	entertainer = {
		every = 1.6,
		windup = 0.22,
		reach = 70,
		hold = 0.06,
		back = 0.38,
		pom = 0.3,
		wand = 0.05,
		wandBase = 0.55,
		tilt = 30,
		side = 0.45,
		hz = 1.8,
		decay = 2.6,
		look = 10,
		follow = 0.8,
		lean = 4,
	},
	-- Stuck in a rescue trap (Derek 2026-10-28: a different animation "for whatever cat is stuck in it", "like tail
	-- sticking out or butt", "make the butt sticking out for a lot of the rescue's", "flip the cats upside for some
	-- rescue missions where fit"). Each TrapType wriggles one of two ways (`kinds`), in bursts once every `every`
	-- seconds over `seconds` at `hz`, still moving `twitch` as much in between. `butt`: head first into a bin, can,
	-- bag pile, shed, log, pipe, grate or bramble bush (Derek 14:17: on its back on the bush looked off), or the
	-- Desert's sand, urn and canopy and the Ruins' rubble and urn (#2651), with only its back end out: the hips
	-- wiggle `wiggle` degrees, the back legs paddle `kick` and the raised tail (`tailUp`) lashes `tail`. `flip`:
	-- upside down, hanging under a branch or on its back across a gutter or on the Ruins' bridge stub: all four legs pedal
	-- `legs` degrees in the air, the body rocks `rock`, the tail swings `tail`, the head looks about `look` and the
	-- ears go back `ears`. Where the cat sits and which way up is the server's stuck pose for the trap. A trap not in
	-- `kinds` keeps the plain shake (`every`, `shake`, `seconds`).
	stuck = {
		every = 2.6,
		shake = 9,
		seconds = 0.5,
		kinds = {
			trash_bin = "butt",
			trashcan = "butt",
			garbage_bag = "butt",
			shed = "butt",
			hollow_log = "butt",
			drain_pipe = "butt",
			grate = "butt",
			bramble_bush = "butt",
			tree = "flip",
			gutter = "flip",
			-- Tier 6 and 7 (#2651)
			sand_dune = "butt",
			clay_urn = "butt",
			collapsed_canopy = "butt",
			rubble_pile = "butt",
			stone_urn = "butt",
			bridge_ledge = "flip",
			-- Tier 8, the Snowy Mountain (#4069): head first into a snowdrift, a snowy log, a snowman or under a sled
			snowdrift = "butt",
			snow_log = "butt",
			snowman = "butt",
			sled = "butt",
			-- Tier 9, the Water Park (#4070) and Tier 10, the Medieval Castle (#4071), by the names of Model-Agent's
			-- spots (trap_ball_pit and so on). Head first with the back end out where the piece has a hollow to dive
			-- into: the ball pit, the prize plush pile and the haystack. In the rest the cat sits the right way up
			-- (carousel, river_ring, balloons, barrel, banner_pole, awning, helmet) and keeps the plain shake.
			ball_pit = "butt",
			plush_pile = "butt",
			haystack = "butt",
		} :: { [string]: string },
		butt = {
			every = 2.2,
			seconds = 1.3,
			hz = 3,
			twitch = 0.2,
			wiggle = 14,
			kick = 40,
			tail = 45,
			tailUp = 30,
		},
		flip = {
			every = 2,
			seconds = 1.2,
			hz = 2.5,
			twitch = 0.3,
			legs = 45,
			rock = 10,
			tail = 40,
			look = 25,
			ears = 30,
		},
	},
	-- A nap curls the cat up: it lies on its belly with its legs folded (front paws out in front), tucks its head
	-- round towards its tail and wraps the tail along its side. sink 1 is right down on its belly. `breathe` is how
	-- far the top of its back rises with each breath (Derek 2026-10-27: the belly lifting and lowering while it
	-- sleeps), one breath every `seconds`.
	nap = { headDroop = 18, headTuck = 35, tailWrap = 70, sink = 1, breathe = 0.09, seconds = 3.2 },
	-- A cat stood upright at its station (F25) dozes on its feet at night instead: chin down on its chest with a
	-- slow nod, a little sway, the tail hanging still. Nothing sinks, so it never dips into the counter.
	doze = { headDroop = 26, nod = 5, sway = 2, tail = 0.15, breathe = 0.06, seconds = 3.6 },
	-- A loaf (Derek 2026-10-27, from draft E): a resting cafe cat sits up from its nap now and then, tucked in and
	-- still. On its belly with every leg folded under and the front paws peeking out, head up and level, the tail laid along its right side, a slow
	-- breath, a slow look aside once in a while and a quick ear flick. `hold` seconds of every `every`, by day.
	loaf = {
		headDroop = 4,
		look = 16,
		lookEvery = 11,
		lookSeconds = 3.5,
		flick = 4,
		flickEvery = 6.5,
		tailWrap = 60,
		breathe = 0.05,
		seconds = 4.2,
		every = 75,
		hold = 24,
		-- #3923 (Derek 2026-11-13: "sometimes the cats randomly sit up when you move around cafe even when resting
		-- should just be asleep"): a resting cafe cat no longer sits up; it naps the whole rest. A cat in a
		-- player's arms still loafs awake. true brings the sit-ups back.
		resting = false,
	},
	-- A sitting cat (the _Sit body, PR #259) washing a paw now and then (Derek 2026-10-27: the paw-up sit is a
	-- lick), the way a walking cat loafs: `hold` seconds of every `every`, by day, eyes half shut. The paw stays up
	-- at the mouth and the head licks it (Derek 2026-10-29: the old paw rub looked like kicking): in bursts of
	-- `strokes` seconds a `pause` apart, `hz` licks a second, each a dip of `bob` degrees taking `down` of the lick
	-- and the rest to come up, turned `turn` degrees into the paw, which lifts `paw` degrees to meet it; a burst eases
	-- in and out over `ease` seconds. Every other pause the cat rubs its cheek along the paw: the paw rises `wipe`
	-- degrees as the head turns `wipeTurn` into it, bowing `wipeBow` and tipping `wipeTilt`.
	lick = {
		every = 60,
		hold = 9,
		strokes = 1.6,
		pause = 1.1,
		hz = 2.2,
		bob = 9,
		down = 0.3,
		turn = 3,
		paw = 4,
		ease = 0.12,
		wipe = 8,
		wipeTurn = 20,
		wipeBow = 8,
		wipeTilt = 14,
		eyes = 0.6,
	},
	-- Blinks squash each eye to `squash` of its height for `seconds`, every `every` seconds or so. A sleeping or
	-- dozing cat keeps its eyes shut; a loafing cat keeps them `sleepy` shut and blinks slowly.
	blink = { every = 4.3, seconds = 0.16, squash = 0.12, sleepy = 0.4, slowSeconds = 0.6 },
	-- An ear flicks back and out by `twitch` degrees for `seconds`, the left every `everyL` seconds and the right
	-- every `everyR` (the new bodies' EarL and EarR); asleep, half as often.
	ears = { twitch = 22, seconds = 0.22, everyL = 5.3, everyR = 7.7 },
	settle = 0.8, -- seconds a cat takes to move from one style to the next
	settleDown = 1.2, -- lying down (into a nap or a loaf) takes longer
	settleUp = 0.9, -- and getting up a little less
	lieGap = 0.02, -- studs a lying cat's belly stays off the floor, at Scale 1 (the manifest's 0.31 on a 0.33 body)
	-- A stretch (Derek 2026-10-27): as a stray gets up from a nap to walk off (the server's `StretchAt`), and every
	-- `every` to `everyMax` seconds while a stray stands still. On all fours it rises out of its pose over `rise` of the stretch, bows (front legs `reach` degrees
	-- ahead, body `bow` degrees nose down and `drop` studs lower, head up by `yawn`, tail up by `tail`, ears back by
	-- `ears`, eyes shut, the head kept nearly level), then rocks `rock` degrees forward and stretches each back leg `rear` degrees out behind.
	stretch = {
		seconds = 3.2,
		rise = 0.12,
		bow = 22,
		drop = 0.17,
		reach = 70,
		yawn = 8,
		headLevel = 0.6, -- of the bow the head turns back up, so it looks ahead rather than at the floor
		tail = 45,
		ears = 20,
		rock = 6,
		rear = 50,
		every = 35,
		everyMax = 80,
	},
	-- Legs swing with the distance the server moves the cat, so the feet keep pace with the ground: a trot at
	-- walking speed, a gallop once it runs (F40's sprint is 26 studs a second). Speeds in studs a second.
	gait = {
		moveFrom = 0.8, -- slower than this the cat stands
		runFrom = 9, -- the gallop starts to blend in here
		runFull = 18, -- and is full from here
		walkStride = 1.3, -- studs travelled per leg cycle
		runStride = 3.2,
		trotFrom = 3.4, -- slower than this it walks one leg at a time (strays wander at 3)
		trotFull = 4, -- and trots from here
		walkSwing = 28, -- degrees each leg swings either way
		runSwing = 50,
		walkBob = 0.04,
		walkRoll = 3, -- degrees the body sways side to side once a cycle at a walk
		walkNod = 4, -- degrees the head nods with each step
		walkTail = 18, -- degrees the tail is held up while it walks or trots
		tailSway = 10, -- degrees the tail sways with the steps
		lookAhead = 0.7, -- how much of its look around a moving cat drops to watch where it is going
		runBob = 0.16,
		runRock = 9, -- degrees the body rocks nose up and down in a gallop
		runHead = 12, -- the head stretches forward and down
		dustEvery = 0.14, -- seconds between dust kicks while it runs
		dust = 3,
	},
	-- Catching its breath after the sprint (FleeingUntil still ahead, standing still): quick shallow breaths,
	-- head low, tail down, a small huff of breath now and then.
	pant = {
		seconds = 0.32,
		studs = 0.035,
		headDown = 14,
		tailDown = 15,
		huffEvery = 0.7,
		huff = 2,
	},
	-- Held in a player's arms (Derek 2026-10-28: "awake loafing or sitting"): a loaf on the walking body, a sit on the
	-- sitting body, eyes open, a breath every `seconds` rising `breathe`, looking `look` degrees either way and `nod`
	-- up and down over `lookSeconds`, the tail swishing `tail` as much as usual.
	held = { seconds = 3.4, breathe = 0.05, look = 30, nod = 8, lookSeconds = 6.5, tail = 0.5 },
	-- Balloon Cat (F78, design v0.13: "it bobs as if it might float off"): a cat in `cats` lifts off its paws and
	-- settles back once every `seconds`, rising over `rise` of it and coming down over `fall`, then resting on its
	-- paws for the rest; every `tugEvery`th bob the balloons pull it up to `tugStuds` instead of `studs`. While it is
	-- up its legs hang `dangle` degrees apart, the tail lifts `tail` and it sways `sway` degrees about every
	-- `swaySeconds`. Asleep or loafing it floats `resting` as high; stuck in a trap or galloping it stays down.
	float = {
		cats = { balloon = true } :: { [string]: boolean },
		studs = 0.14,
		tugStuds = 0.3,
		tugEvery = 4,
		seconds = 2.2,
		rise = 0.5,
		fall = 0.35,
		dangle = 8,
		tail = 15,
		sway = 3,
		swaySeconds = 3.1,
		resting = 0.5,
	},
	-- The new areas' Common cats (#4069, #4070, #4071; Derek 2026-11-13: commons get prop motion only): the hat or
	-- tufts in the head (`_Prop`, Pose's "cap") bounce with each stride while the cat walks, tipping up to the cat's
	-- `degrees` front and back about the prop's own pivot, `lag` radians behind the legs so it reads as loose. One
	-- bounce a leg cycle (about 2 a second at a stray's walk), still while it stands. The Elf Cat's belled hood swings
	-- the most and the Dwarf Cat's beard and iron cap bounce; the Squire wears nothing on its head, so it has none.
	-- Small on purpose: the exported props pivot at the neck like the head, so a bigger tip would lift them off it.
	propBounce = {
		lag = 0.9,
		cats = {
			elf = 5,
			dwarf = 4,
			pinwheel = 4,
			hot_chocolate = 3,
			crumpet = 3,
			flurry = 3,
			mitten = 3,
			spruce = 3,
			popcorn = 3,
			splash = 3,
			taffy = 3,
		} :: { [string]: number },
	},
}

-- Model-Agent's piece poses for the new bodies (manifest `cat_poses`, PR #259), copied here because the
-- manifest does not ship with the game: for each hinged piece, the turn about its own joint as
-- piece:PivotTo(piece:GetPivot() * CFrame.Angles(x, y, z)) in degrees (`angles_roblox_deg`), and how far the whole
-- cat drops (`lift_roblox` Y, studs at Scale 1). `body` is the body each is for, "walk" (A) or "sit" (B). Copy new
-- numbers here when the manifest changes. In the sleep and the loaf the folded legs also turn out to the sides (the
-- last angle, front 30 degrees, back 26), so the paws peek out a little (Derek 2026-10-27; in the manifest since #296).
export type CatPose = { body: string, lift: number, turns: { [string]: { number } } }
-- Cafe cats on the move (CafeWalk.luau; Derek 2026-10-29 19:45: "make the cats move around cafe not just waddle
-- back and fourth while sitting"). In your own cafe by day, a waiter at its station now and then gets up, walks
-- `speed` studs a second onto the nearest lane and along it to a chair within `reach` studs (the chair's Approach
-- point, where customers walk to sit), looks over the table for `pause` seconds and walks back to sit again, once
-- every `every` seconds (a random time between the two), at most `most` at once and only while the camera is within
-- `range` studs. Getting up and sitting down cross-fade the seated body and the walking body over `fade` seconds; it
-- turns at most `turn` degrees a second. Off with Reduce Motion. F90's orders (cats-make-orders.md) send the same
-- walk with a tray, its underside on the walking body's Carry attachment at the ear tips (Model-Agent's #778).
-- F90's animation (section 6, Logic.crouch, trayCarry, sweepPose, sweepScoop and bankNod):
-- - `sit`: getting up, the walking copy rises out of a sit over `rise` seconds (the cross-fade runs over the first
--   `fade` of them); sitting down it sinks into one, the cross-fade over the last `fade`. Down, its hindquarters
--   are `drop` studs lower with the back legs tucked `tuck` degrees, the body `pitch` degrees nose up and the tail
--   `tail` degrees down.
-- - `carry`: with a tray on its head it eases into carrying over `ease` seconds, its chin `chin` degrees up and tail
--   `tail` degrees higher, the head steady (Logic.gait's level); tall hats fade out over the same ease.
-- - `sweep`: at a tip pile (Moments.TipSwept) it stops for `seconds`: rears up by `up` (a share of the sweep) with
--   its body `rear` degrees back and `lift` studs higher, its left paw `reach` degrees out on the table edge, drags
--   its right paw back `drag` degrees `swipes` times, and is back on all fours from `down` to the end, tail up
--   `tail`. The tray with the coin bag waits where the pile was and hops onto its head between `scoop` and `land`,
--   in an arc `arc` studs high.
-- - `bank`: at the till (Moments.TipBanked) it stops for `seconds` and dips its shoulders `lean` and head `nod`
--   degrees toward it as the bag tips off, tail up `tail`.
-- Sweep and bank do not play with Reduce Motion: the bag goes straight onto the head and the walk goes on.
Presets.cafeWalk = {
	speed = 3,
	turn = 300,
	fade = 0.3,
	every = { 16, 32 },
	pause = { 2.5, 4.5 },
	reach = 12,
	most = 2,
	range = 70,
	trayLift = 0.08, -- studs a tray sits above the top of the head, on a body without a Carry attachment
	tallAbove = 0.05, -- studs a head prop may rise above Carry before it steps aside under a tray
	sit = { rise = 0.45, drop = 0.1, tuck = 40, pitch = 12, tail = 20 },
	-- A cat standing at its station on the work body (S, #826) gets up from standing instead: the walker starts
	-- reared up on its back legs, nose up `pitch` degrees and `drop` studs (negative: lifted, so its back end stays
	-- out of the floor), back legs tucked `tuck` and tail down `tail`, and drops onto all fours over sit.rise while
	-- the station model fades out; coming home it rears back up as the station model fades in.
	stand = { drop = -0.12, tuck = 30, pitch = 30, tail = 10 },
	carry = {
		ease = 0.25,
		chin = 6,
		tail = 20,
		-- by what rides on the tray (#1576, Derek 2026-11-05: "extra carrying animations by food type"), kept subtle:
		-- `chin` and `tail` degrees more, the tray tipping `sway` degrees side to side once a stride and lifting
		-- `bob` studs at each step, all at full once the walker goes `swayAt` studs/s (still while it stands).
		-- A drink is carried dead level, a bake rocks a little, the gold plate goes proud and careful.
		swayAt = 6,
		styles = {
			drink = { chin = 2, tail = 0, sway = 0.5, bob = 0 },
			bake = { chin = 0, tail = 0, sway = 2.5, bob = 0.03 },
			gold = { chin = 3, tail = 10, sway = 1, bob = 0.01 },
			plain = { chin = 0, tail = 0, sway = 0, bob = 0 },
		} :: { [string]: { chin: number, tail: number, sway: number, bob: number } },
	},
	sweep = {
		seconds = 1.1,
		up = 0.18,
		down = 0.72,
		rear = 22,
		lift = 0.12,
		reach = 50,
		drag = 40,
		swipes = 2,
		tail = 25,
		scoop = 0.6,
		land = 0.85,
		arc = 0.8,
	},
	bank = { seconds = 0.45, lean = 10, nod = 25, tail = 15 },
}

-- The Bellhop Cat's five animations (F96, starter-cat.md section 1), on Model-Agent's #708 hinges: the cap (`_Prop`
-- in `_Head`) tips about its pivot at the back of its base, front up for plus; the bell (`_Bell`, in the collar
-- `_Prop2`) swings side to side about its pivot's Z where it hangs.
-- - `ring`: the head gives a quick shake over `shakeSeconds` (`shake` degrees of roll) and the bell swings `swings`
--   times either way, `degrees` at first and dying away, over `seconds`. The stand rings once every `every` seconds
--   (a random time between the two) by day; a cafe Bellhop rings in each customer who comes within `greet` studs
--   before ordering, at most once every `gap` seconds, and tips its cap to them `tipAfter` seconds later.
-- - `tip`: the cap lifts `degrees` at the front with a `nod` of the head and settles back, over `seconds`. The stand
--   tips it to you as you walk within `walkUp` studs, at most once every `tipGap` seconds.
-- - `bow`: put in its place (a new station model), it leans `lean` degrees forward with its head `head` degrees
--   down and the cap tipped `cap`, over `seconds`, if it shows within `bowWindow` seconds of appearing.
-- - `sleepCap`: asleep (a nap or doze) the cap turns `turn` degrees and moves `down` and `forward` studs, times the
--   cat's scale, to sit over its eyes, sliding there or back over `seconds`. Since #708's cap fix (Derek saw the old
--   one sink into the face) `down` is negative: the cap lifts as it tips forward, so its back rises and its front rim
--   rests on the tops of the eyes, outside the face.
-- - `hop`: claimed at the stand, it bounces `bounceHeight` studs where it sits for the first `bounce` share of
--   `seconds`, then leaps in an arc `height` studs high to `ahead` studs in front of you, its feet `lift` studs above
--   the middle of your character (in your arms), nose up
--   `lean`, tail up `tailUp` and front paws reaching `reach` degrees. It vanishes in a sparkle there and fades back
--   onto the cart over `fade` seconds, `back` seconds later.
-- `standScale`: the cart's cat is the sitting body (`sitModel`) at this scale (Model-Agent). `standAwake`: the cart's
-- cat never dozes, so its face shows at night too (#1023, Derek: "the bellhop cat is missing face and features").
Presets.bellhop = {
	catId = "bellhop_cat",
	ring = { seconds = 1.4, degrees = 30, swings = 4, shake = 7, shakeSeconds = 0.5 },
	every = { 8, 12 },
	greet = 7,
	gap = 3,
	tipAfter = 1.2,
	tip = { seconds = 1, degrees = 20, nod = 8 },
	walkUp = 12,
	tipGap = 8,
	bow = { seconds = 1.5, lean = 16, head = 18, cap = 8 },
	bowWindow = 3,
	sleepCap = { turn = -40, down = -0.13, forward = 0.39, seconds = 1.2 },
	hop = {
		seconds = 1.1,
		bounce = 0.3,
		bounceHeight = 0.6,
		height = 3,
		ahead = 1.8,
		lift = -0.6,
		lean = 14,
		tailUp = 40,
		reach = 35,
		back = 3,
		fade = 0.4,
	},
	standScale = 1.5,
	standAwake = true,
	sitModel = "CatCafe_Cat_BellhopCat_Sit",
}

-- A cat alive in a card's picture (Portrait.luau; Derek 2026-11-03 01:10 on the Bellhop Cat's card): the Bellhop Cat
-- rings its bell `ringFrom` seconds after the card opens and then every `every` seconds, tipping its cap
-- Presets.bellhop's `tipAfter` after each ring.
Presets.portrait = {
	ringFrom = 1.2,
	every = 7,
}

-- The Lucky Cat statue's beckoning paw (F88, luck-and-rare-moments.md section 1a: "Its paw waves a little faster at
-- each level"): the statue's `_Paw` piece (Model-Agent's #742, pivoted at the shoulder) tips forward and back about
-- its pivot's X, `degrees` each way (clear of the head and ear), one beckon every `seconds[level]` for levels 1 to 5,
-- on statues within budget.ambientRadius. Still with Reduce Motion.
Presets.luckyPaw = {
	degrees = 20,
	seconds = { 2.4, 2.1, 1.8, 1.5, 1.2 },
}

-- The secured cat's happy hop with a full spin (F89, luck-and-rare-moments.md 2a: "the cat does a happy hop with a
-- full spin at the door ... inside the existing catch beam"): on a big pull a copy of the cat on its walking body
-- appears `ahead` studs in front of the player, facing them, crouches until `takeoff`, leaps `height` studs turning
-- `turns` full turns until `land`, squashes `squash` studs on landing until `settle`, sits up proud and fades,
-- `seconds` in all (each share is of that). It fades in over the first `fadeIn` share and out over the last `fadeOut`.
Presets.pullHop = {
	seconds = 1.6,
	ahead = 1.5,
	takeoff = 0.15,
	land = 0.7,
	settle = 0.82,
	height = 2.5,
	turns = 1,
	crouch = 0.25,
	squash = 0.2,
	tailUp = 45,
	reach = 30,
	lean = 10,
	proud = 12,
	fadeIn = 0.06,
	fadeOut = 0.15,
}

-- The camp extras' moving touches (F100, camp-extras.md section 3), drawn by CampExtras.luau. Each turn is about the
-- pivot's X of Model-Agent's child Model (#750): the Fish Pond's `_Rod` at its butt in the holder (below 0 lifts the
-- tip, above 0 dips it toward the water), the Lost and Found's `_Lid` at its back hinge (above 0 lifts the front).
-- Nothing moves with Reduce Motion. VFX-Agent draws the fish jump, the thermos steam and the pipe drips.
Presets.campExtras = {
	rod = {
		-- the fish landed at a pond collect, { seconds, degrees }: a tug at the bite, the tip lifted high to swing the
		-- fish in, a pause, the cast back out past rest so the bobber plops in (the rodCast beat), and a settle
		keys = {
			{ 0, 0 },
			{ 0.12, 6 },
			{ 0.45, -35 },
			{ 0.9, -32 },
			{ 1.15, 8 },
			{ 1.4, -3 },
			{ 1.65, 1 },
			{ 1.85, 0 },
		},
		hangBeyond = 1.2, -- studs out from the butt past which an upright part (the line, the bobber) hangs from the tip
		within = 30, -- studs from the collect's position to the rod it plays on
	},
	lid = {
		every = { 3.5, 6.5 }, -- seconds between rattles while a prize waits, each with the lidRattle beat
		rattle = { seconds = 0.55, degrees = 5, knocks = 4 }, -- quick lifts of the front edge, each smaller
		-- the lid at a Lost and Found collect, { seconds, degrees }: up to let the prize out, a pause, shut with a bounce
		pop = { { 0, 0 }, { 0.18, 28 }, { 0.55, 26 }, { 0.8, 0 }, { 0.9, 4 }, { 1, 0 } },
		within = 30, -- studs from the collect's position to the lid it plays on
	},
	-- the Lost and Found booth's desk bell (#1732, camp-stations.md section 4b): while a prize waits it rings, a
	-- wobble side to side about its base that dies away, every few seconds; it plays with Reduce Motion too
	bell = {
		every = { 3.5, 6.5 }, -- seconds between rings while a prize waits
		ring = { seconds = 0.7, degrees = 9, wobbles = 3 }, -- tips each way `wobbles` times, each smaller
	},
}

-- The store's motion (#1823, StoreMotion.luau): a pressed button dips to `dip` of its size in `down` seconds and
-- springs back in `up`; a bought card pops to `pop` in `grow`, settles in `settle`, flashes white from `flash`
-- transparency over `flashSeconds`, and throws `sparks` gold sparks `reach` pixels out over `sparkSeconds`.
Presets.storeMotion = {
	press = { dip = 0.94, down = 0.06, up = 0.16 },
	bought = {
		pop = 1.08,
		grow = 0.12,
		settle = 0.25,
		flash = 0.45,
		flashSeconds = 0.35,
		sparks = 8,
		reach = 70,
		sparkSize = 8,
		sparkSeconds = 0.5,
		colour = Color3.fromRGB(255, 205, 80),
	},
}

Presets.catPoses = {
	sleep = {
		body = "walk",
		lift = 0.31,
		turns = {
			LegF1 = { -90, 0, -30 },
			LegF2 = { -90, 0, 30 },
			LegB1 = { 90, 0, -26 },
			LegB2 = { 90, 0, 26 },
			Head = { -26.8, 25.4, 12.2 },
			Tail = { 71.7, 49.6, -66.5 },
		},
	},
	loaf = {
		body = "walk",
		lift = 0.31,
		turns = {
			LegF1 = { -90, 0, -30 },
			LegF2 = { -90, 0, 30 },
			LegB1 = { 90, 0, -26 },
			LegB2 = { 90, 0, 26 },
			Tail = { 42.1, 23.2, -19.6 },
		},
	},
	lick = {
		body = "sit",
		lift = 0,
		turns = {
			LegF1 = { 128.8, -11.0, 8.7 },
			Head = { -16.5, 13.4, 3.9 },
		},
	},
} :: { [string]: CatPose }

Presets.shake = { seconds = 0.18, studs = 0.22 }

-- Controller rumble (#4224; Effects/Rumble; phones never vibrate, #5214): a camera bump of `studs` buzzes the gamepad's big motor at `perStud` a
-- stud, between `least` and `most` of full, for the bump's seconds kept between `shortest` and `longest`. `catch` is
-- your own catch's pulse by rarity: light for a Common, firmer and a little longer the rarer the cat.
Presets.rumble = {
	perStud = 1.6,
	least = 0.2,
	most = 0.7,
	shortest = 0.08,
	longest = 0.5,
	catch = {
		Common = { seconds = 0.08, strength = 0.2 },
		Rare = { seconds = 0.1, strength = 0.25 },
		Epic = { seconds = 0.14, strength = 0.35 },
		Legendary = { seconds = 0.2, strength = 0.45 },
		Mythical = { seconds = 0.3, strength = 0.55 },
		Secret = { seconds = 0.4, strength = 0.65 },
	} :: { [string]: { seconds: number, strength: number } },
}

-- A shove (F41), a landed tackle since F74: a puff where it lands, dizzy stars over the shoved player's head and,
-- for them, a bigger camera bump than a missed catch. The knockback itself is the engineer's, on the target's own
-- client.
Presets.shove = {
	puff = 10, -- hissPuff particles where it lands
	stars = 3,
	starRadius = 0.9,
	starHz = 1.4,
	shake = 0.3,
	shakeStuds = 0.4,
}

-- A tackle (F74, data-model 10c v0.11): a streak of dust along the ground behind the tackler while they lunge, and
-- after a miss a skid of dust kicked up as they slide on their belly with a puff where they stop. The seconds come
-- from the shared Config once it has them (TackleLungeSeconds, TackleHitGraceSeconds, TackledDownSeconds); these
-- until then.
Presets.tackle = {
	lungeSeconds = 0.35, -- TackleLungeSeconds
	graceSeconds = 0.25, -- TackleHitGraceSeconds: the streak may run this much longer for lag
	downSeconds = 0.8, -- TackledDownSeconds: a tackled player's stars circle this long
	starsAfter = 0.4, -- and this much longer while they get up, fading out over the last 0.3 s
	lungeSpeed = 28, -- studs a second: a lunge (12 in 0.35 s) beats this, a Catch Rush walk (24) does not
	streakWidth = 1.4, -- studs: the flat ribbon of dust along the ground
	streakSeconds = 0.45, -- how long the ribbon trails behind before it fades
	every = 0.06, -- seconds between looks at how fast the tackler moves, and between kicks
	kick = 2, -- kick particles at the feet each time while lunging fast
	skidSeconds = 0.6, -- the longest a missed tackler's slide is followed
	skidSpeed = 3, -- studs a second: slower than this they have stopped
	skidKick = 3, -- kick particles each time while sliding
	skidDust = 8, -- dust particles where they stop
}

-- The Tackle (design v0.11, F74), drawn on R15 characters by Tackle.luau with Avatar.luau's poses. Seconds as the
-- engineer's timers (Config Tackle* once it has them: the lunge, the hit window's grace, the stand-up after a hit
-- and after a miss, the target's push and how long it stays down), so a pose ends when the player can move again.
-- Each key pose is degrees about the R15 joints (Avatar.Pose; `sh`, `sp`, `el`, `hip` and `kn` set both sides,
-- `shL`... one side) and `air`, studs from the floor to the lowest part (0: resting on the floor). A pose eases in
-- over `blendIn` from whatever the character was playing and back out over `blendOut`. A character that moves
-- faster than `cutSpeed` studs a second after the moving part of its tackle is up again, so its pose eases out.
Presets.tacklePose = {
	lunge = 0.35, -- TackleLungeSeconds
	grace = 0.25, -- TackleHitGraceSeconds: the window runs this much past the lunge before a miss is known
	hitRecover = 0.4, -- TackleHitRecoverSeconds
	missRecover = 1.2, -- TackleMissRecoverSeconds
	push = 0.25, -- the target's knockback: ShoveController's PUSH_SECONDS, keep the two together
	down = 0.8, -- TackledDownSeconds, after the push
	land = 0.15, -- after the lunge the diver comes down on its belly over this long
	lost = 0.5, -- after the window, no hit and no TackleMissAt for this long: it gets up anyway
	blendIn = 0.06,
	blendOut = 0.12,
	cutSpeed = 8,
	cutAfter = 0.15, -- seconds after the moving part before speed counts: the push or lunge dies away
	cutSeconds = 0.15, -- how fast the pose lets go once the player moves
	sideRoll = 20, -- most a tackled player tips towards a push from the side
	slide = { neck = 6, kick = 25, roll = 3, hz = 6 }, -- the belly slide's wobble, fading as it stops
	poses = {
		coil = { lean = 20, waist = 15, neck = 20, sh = -50, sp = 15, el = 25, hip = 70, kn = 85 },
		launch = { lean = 55, neck = 40, sh = 120, sp = 15, el = 20, hip = 5, kn = 25, air = 0.5 },
		fly = {
			lean = 82,
			waist = -5,
			neck = 55,
			sh = 165,
			sp = 22,
			el = 10,
			hip = -8,
			kn = 35,
			air = 0.5,
		},
		belly = {
			lean = 90,
			waist = -6,
			neck = 50,
			sh = 168,
			sp = 28,
			el = 15,
			hip = -4,
			kn = 40,
			air = 0.04,
		},
		allFours = { lean = 60, neck = 40, sh = 60, sp = 5, el = 5, hip = 62, kn = 92 },
		stumble = {
			lean = 28,
			waist = 10,
			neck = 25,
			shL = 85,
			shR = 55,
			sp = 35,
			el = 30,
			hipL = 55,
			knL = 35,
			hipR = -22,
			knR = 30,
		},
		recoil = {
			lean = -22,
			waist = -10,
			neck = -20,
			sh = 70,
			sp = 40,
			el = 30,
			hip = 25,
			kn = 25,
			air = 0.3,
		},
		recoilForward = {
			lean = 28,
			waist = 10,
			neck = 30,
			sh = 100,
			sp = 30,
			el = 20,
			hip = -20,
			kn = 35,
			air = 0.3,
		},
		back = {
			lean = -90,
			waist = 5,
			neck = -15,
			sh = 35,
			sp = 70,
			el = 20,
			hip = 40,
			kn = 50,
			air = 0.04,
		},
		sit = { lean = -10, waist = 12, neck = 5, sh = 25, sp = 30, el = 35, hip = 88, kn = 20 },
		crouch = { lean = 30, waist = 15, neck = 20, sh = 30, sp = 20, el = 30, hip = 95, kn = 115 },
	} :: { [string]: { [string]: number } },
}

-- The net hold (Derek 2026-10-28: "have your character holding a net while walking around until catching a cat";
-- 16:47 "default of holding net should be tilted back over your shoulder unless swinging down"), drawn by
-- Tackle.luau, the net itself by NetHold.luau: at all times (F93), except with a cat in the arms or in a cannon
-- flight, the right hand holds the player's net (CatCafe_Item_Net_L1 to L4 by its `Grip` attachment) at the
-- shoulder with the pole resting back over it, the hoop behind and to the right of the head, out of the camera's
-- way; the other arm is free to swing. `waist` is 0: the hold leaves the body alone. The right shoulder is raised
-- `sh` degrees forward, turned `tw` and out `sp` (in, below 0), the elbow bent `el`, so the forearm points up; on R6,
-- which has no elbow, the whole arm rises `sh6`. The pole leaves the fist along the hand's back-to-front axis tipped
-- `tilt` (R6: `tilt6`) degrees towards the fingers, so it points `sh + el + tilt` degrees up from straight ahead
-- (past 90 is back), turned `roll` degrees about the pole so the hoop opens forward and the bag trails back (Derek
-- 14:17: the nets faced the wrong way). The grip sits at the hand's own RightGripAttachment where it has one, else
-- `grip` studs from the hand's centre (`grip6` on R6). Within budget.animRadius; the arm eases in over `blendIn` and
-- out over `blendOut` seconds, and the net shows while the arm is past halfway (`showAt`).
Presets.netHold = {
	sh = 35,
	tw = -25,
	sp = -15,
	el = 135,
	sh6 = 120,
	waist = 0,
	tilt = -45,
	tilt6 = -15,
	roll = 180,
	grip = Vector3.new(0, -0.1, 0),
	grip6 = Vector3.new(0, -0.9, 0),
	blendIn = 0.25,
	blendOut = 0.2,
	showAt = 0.5,
}

-- The net smack (F93, catch-rework.md section 1): one swing every NetSwingCooldown (0.8 s), 0.62 s long (Derek
-- 2026-11-03 "much better swing", over the old 0.35 s snap). From the shoulder the arm winds the net up over the
-- head by `rise`, slams it down onto the ground ahead by `land` (NetSmackDelay, when the server judges the hit),
-- holds it there `impact` seconds and eases back to the shoulder by `ends`, swinging a little past it and settling
-- (`settle`, an ease out with a back swing; 0 is a plain ease out). A swing that hit nothing
-- bounces the net back up off the ground for `bounce` seconds first (the recoil). Each pose is a NetArm
-- (Avatar.holdNet): `raised` has the pole about 150 degrees up from straight ahead (up and back over the head),
-- `landed` about 23 degrees below it with the body bent into the hit (the hoop at the ground on a stand-in R15),
-- `bounced` partway back up. Played on the swinger's own screen from the press, elsewhere from the server's
-- NetSwung; the swinger's own screen takes a NetSwung for its player within `answerWithin` seconds of the press
-- (NetSwingCooldown) as that swing's answer, not a new swing.
Presets.netSmack = {
	rise = 0.14,
	land = 0.22,
	impact = 0.05,
	ends = 0.62,
	bounce = 0.09,
	settle = 1.1,
	answerWithin = 0.8,
	poses = {
		raised = { sh = 150, tw = 0, sp = 10, el = 35, sh6 = 165, waist = -8 },
		landed = { sh = 32, tw = 0, sp = 4, el = 5, sh6 = 0, waist = 15 },
		-- higher than a hit's eased return at the same moment, so the recoil reads as a miss's alone
		bounced = { sh = 72, tw = 0, sp = 6, el = 26, sh6 = 60, waist = 10 },
	},
}

-- The pal wave (F92, playing-together.md section 5: "a little wave from both characters" when an invited or
-- following player spawns at a pal's front door): the left arm comes up over `raise` seconds, raised `sh` degrees
-- forward and `sp` out to the side with the elbow bent `el` so the forearm stands up by the head, turns `twist`
-- degrees in and out about the upper arm `waves` times (one every `every` seconds) and goes back down over `lower`
-- seconds, 1.9 s in all. The right arm keeps the net. R6, with no elbow, raises the whole arm `sh6` and sways it
-- `sway6` degrees either side of `sp6` out. The pal waves back `palDelay` seconds after the joiner starts.
Presets.palWave = {
	raise = 0.25,
	waves = 3,
	every = 0.45,
	lower = 0.3,
	sh = 125,
	sp = 20,
	el = 60,
	twist = 25,
	sh6 = 160,
	sp6 = 15,
	sway6 = 15,
	palDelay = 0.35,
}

-- The carry (Derek 2026-10-28: "hold it in your arms crossed arms", the cat "awake loafing or sitting in your
-- arms"), drawn by Tackle.luau on the carrier and by Carry.luau on the HeldCat. `arms` is the upper body's pose in
-- Avatar.Pose degrees (the legs stay the character's own): elbows at the sides and the forearms down and in, the hands
-- meeting under the middle of the cat with their tops about 0.4 studs under the UpperTorso's middle, the right a
-- touch higher than the left, head tipped down to the cat. Derek2 2026-11-07: "make the hands in the holding sit
-- lower ... the bottom of cat starts below hands", then "bring cat closer to chest and lower": Catching.HELD puts
-- the cat's floor on the hands with its back against the chest (#1964); the wrists are held straight, so the hands keep still over the character's
-- walk (16:51: "hands shake too much"). R6 has no elbows, so `arms6` reaches both arms forward and in to meet under
-- the cat, angled down and in so their ends pass under its floor rather than up either side of it (Desktop-Tester 2026-11-07; Catching.HELD.r6). The cat's floor sits `gap` studs over the higher forearm (below it: it sinks into the arms a little),
-- `loafSide` or `sitSide` studs to the right of halfway between the forearms (negative: left) and `loafForward` or
-- `forward` studs further out than them. Lying on the arms it turns `loafTurn` degrees: straight across the middle
-- of the arms, head to the character's left (Derek 2026-11-02 12:01: "it should be straight across middle of arms";
-- before, it lay out at the left side facing back over the shoulder, for the camera behind, which he found off
-- centre). `loafForward` keeps its big head clear of the character's face, its back just in front of it, while it
-- looks about. Sitting up it turns `sitTurn` (facing out), `forward` out. The arms ease in over `blendIn` and out over
-- `blendOut` seconds, and the cat on them fades in and out over the same (#1138). A HeldCat Pose
-- cannot move part by part (still streaming in, or on Motor6D joints) stays on its weld and is tried again after
-- `retry` seconds.
Presets.carryPose = {
	arms = {
		shL = 25,
		twL = 25,
		spL = -35,
		elL = 30,
		shR = 25,
		twR = 25,
		spR = -35,
		elR = 35,
		neck = -12,
		waist = -4,
	} :: { [string]: number },
	-- Derek2 2026-11-07 13:12 (R6 row "bad": forearms stacked in front of the belly, hands up through the cat): a
	-- plain cradle like R15's, both arms raised forward 65 degrees and swung 35 in, so they reach out level-ish at
	-- chest height and their ends meet under the cat (FK: ends 0.14 down from the Torso's middle, 1.37 out)
	arms6 = { sh = 65, tw = 0, sp = -35, neck = -12 } :: { [string]: number },
	gap = -0.15,
	forward = -0.6,
	loafForward = -1.15,
	loafTurn = 90,
	loafSide = 0,
	sitTurn = 15,
	sitSide = -0.55,
	blendIn = 0.2,
	blendOut = 0.2,
	retry = 1,
}

-- The Cat Cannon flight (F84, hometown-cannon.md section 3b; Derek 2026-11-03: "much further with less summer
-- salting", "it's cool to see your character fly"), drawn by CannonGlide.luau on every character from its
-- `CannonLaunchAt`, in seconds from it (CannonLaunchSeconds 3.75 in all, #2690). The server holds the character's root
-- anchored at the barrel's seat, upright and facing where the barrel fires, then on the landing pad from
-- CannonTeleportAtSeconds (2.2 since #3292, was 2.6); the body moves away from the root through the Root joint, so nothing replicates.
-- From where it stood the character crouches for `hopCrouch` and hops in a `hopHeight` arc into the barrel by `hop`,
-- curling into the ball on the way. At `boom` the ball leaves along the barrel, tipped `tilt` degrees up, at `speed`
-- studs a second under `gravity`. It makes `flips` forward rolls over the first `flipFor` seconds, slowing as it
-- goes, and opens out of the ball into `soar` (arms ahead, legs back, head first along the way it flies) between
-- `soarFrom` and `soarTo` seconds after the boom. Between `bendFrom` and `bendTo` its way over the ground bends from
-- the barrel's to the flight's `CannonHeading` (Gameplay-Engineer, towards the landing pad), leaning up to `bank`
-- degrees into the turn. At `gone` it waits `hidden` studs up, out of sight, while the clouds cover the move. At
-- `drop` it comes back `height` studs over the pad and `back` studs behind it, feet first in `drop`, and falls along
-- a curve onto the pad, the curve's own speed slowing to `arrive` of it at the end; it swings into the landing over
-- the last `open` seconds and lands at `touch`. The hero landing: down on one knee with a fist on the ground by
-- `kneel` seconds after the touch, held to `hold`, then up standing at `ends`, and the joints go back over
-- `blendOut`. #2690 (Derek2 2026-11-09: "locked too long" after landing): the server lets go at `ends`, a quarter
-- second after the touch (was half a second), so the landing is quicker. A key's numbers are Avatar.Pose degrees, as in tacklePose; `ball` hugs the shins with the chin tucked.
Presets.cannonPose = {
	hopCrouch = 0.1,
	hop = 0.4,
	boom = 0.5,
	gone = 2.0,
	drop = 3.0,
	touch = 3.5,
	ends = 3.75, -- Config.CannonLaunchSeconds: the server lets go here
	hopHeight = 2.5,
	tilt = 50,
	speed = 260, -- was 190 (#1174: "shoot faster and further")
	gravity = 50, -- was 80: a higher, longer climb, about 250 studs out and 240 up by the clouds
	flips = 1,
	flipFor = 0.8,
	soarFrom = 0.35,
	soarTo = 0.75,
	bendFrom = 0.25,
	bendTo = 1.3,
	bank = 30,
	hidden = 4000,
	height = 45,
	back = 30,
	arrive = 0.2,
	open = 0.15,
	lateHold = 0.3, -- #3292: seconds past `drop` the body stays out of sight while the move to the pad is late
	seatNear = 2, -- studs: the root still this close to the barrel's seat means the move has not arrived
	kneel = 0.08,
	hold = 0.12,
	blendOut = 0.15,
	poses = {
		hopCrouch = {
			lean = 15,
			waist = 15,
			neck = 15,
			sh = -45,
			sp = 12,
			el = 30,
			hip = 65,
			kn = 85,
		},
		hopUp = { lean = -5, neck = 20, sh = 160, sp = 20, el = 10, hip = 15, kn = 25 },
		ball = { waist = 50, neck = -35, sh = 55, sp = -10, tw = 35, el = 115, hip = 125, kn = 150 },
		soar = { waist = -8, neck = 50, sh = 172, sp = 8, el = 5, hip = -8, kn = 12, lg = 4 },
		drop = { lean = 6, neck = -10, sh = 120, sp = 70, el = 20, hip = 30, kn = 45, lg = 8 },
		land = { lean = 25, waist = 20, neck = 25, sh = 35, sp = 50, el = 25, hip = 85, kn = 115 },
		kneel = {
			lean = 30,
			waist = 18,
			neck = 30,
			shL = -35,
			spL = 45,
			elL = 25,
			shR = 50,
			spR = 8,
			elR = 5,
			hipL = 100,
			knL = 105,
			hipR = 20,
			knR = 115,
			lgL = 6,
			lgR = 4,
		},
		settle = { lean = 8, waist = 5, neck = 5, sh = 10, sp = 15, el = 15, hip = 25, kn = 35 },
		spread = {
			lean = 78,
			waist = -8,
			neck = 45,
			sh = 100,
			sp = 70,
			el = 25,
			hip = -12,
			kn = 45,
			lg = 25,
		},
	} :: { [string]: { [string]: number } },
}

-- The cloud cutscene's flyer (Derek 2026-10-28 13:56: "make the cloud cutscene a little better"; 2026-11-03: "it's
-- cool to see your character fly"), drawn by CannonGlide.luau in a ViewportFrame in the cloud tunnel on the launching
-- player's screen, from cannonPose's `gone` to its `drop`. It rises `below` studs into view over `rise` seconds as it
-- left the sky, soaring head first tipped `pitch` degrees, and spreads out over `open` into cannonPose's `spread`, a
-- happy skydiver: flat out, arms up and out, legs apart and bent. It glides with its knees fluttering `flutter`
-- degrees at `flutterHz`, bobbing `bob` studs at `bobHz` and banking `bank` degrees at `bankHz`, then over the last
-- `dive` seconds swings its feet down into cannonPose's `drop` and falls out of the bottom of the frame, ready to land
-- on the pad. It heads `heading` degrees off straight into the screen, so its side and face show; the frame's camera
-- sits at `camera` looking at `look` with `fov` degrees, which puts the flyer low in the frame, under UI-Engineer's
-- destination card at the top.
Presets.cannonGlide = {
	rise = 0.18,
	open = 0.2,
	dive = 0.22,
	pitch = 75,
	below = 9,
	flutter = 14,
	flutterHz = 3,
	bob = 0.25,
	bobHz = 1.3,
	bank = 14,
	bankHz = 0.7,
	heading = 20,
	camera = Vector3.new(0, 6, 15),
	look = Vector3.new(0, 1, -1.5),
	fov = 40,
}

-- The launching player's camera through the flight (hometown-cannon.md section 7), moved by CannonGlide.luau; everyone
-- else keeps their own. Over the hop and the fuse it eases from the player's own view to `launch` (studs right, up
-- and back of the seat) looking `ahead` studs up the barrel. From the boom it chases the flyer from `chase` (right,
-- up and back of the way it goes over the ground, so the soaring flyer shows side on), easing there over `catch`
-- seconds (the boom's shake is Cannon.luau's, on top).
-- Under the clouds it waits. `over` seconds before the drop it looks, for one frame, the way the landing pad faces
-- at the player's own pitch, and the game's camera takes over from there (Logic.cannonHandBackAt). So the camera is
-- the player's own all the way down, at the touch and after: #3444 (Derek 2026-11-12: "landing still moves your
-- camera on landing so remove that"). That one frame's pitch stays between `pitchLow` and `pitchHigh` degrees
-- (`pitchRest` when unknown), its distance between `distanceMin` and `distanceMax` studs (`distanceRest` when
-- unknown) and its focus within `focusMax` studs of the player (Logic.cannonLanding; #3548, #3549), so a camera that
-- was straight down or far out when the flight began is never handed back that way.
Presets.cannonCamera = {
	launch = Vector3.new(5, 5, 14),
	ahead = 12,
	chase = Vector3.new(7, 2.5, 12),
	catch = 0.15,
	over = 0.1,
	pitchLow = -50,
	pitchHigh = 10,
	pitchRest = -15,
	distanceMin = 6,
	distanceMax = 60, -- Config.CameraMaxZoomStuds: as far as a player can zoom out
	distanceRest = 14,
	focusMax = 4,
}

-- After a catch and after a miss (design v0.8, data-model section 10c). The getaway (F55): a net catch or rescue
-- pushes every other player within CatchBurstRadiusStuds (10) of the catcher away, so a ring as wide as that
-- spreads from the catcher's feet, and while their `RushUntil` runs (Config.CatchRushSeconds) speed lines stream off
-- them. Startled (F57): the player who missed walks slowly while their `StartledUntil` runs (StartledSeconds, 2), with
-- the dizzy stars of a shove for that long and, for them, a camera bump between a miss's and a shove's.
Presets.chase = {
	ringDiameter = 20, -- studs: twice CatchBurstRadiusStuds, so the ring ends where the push does
	ringSeconds = 0.6,
	dust = 8, -- dust particles at the catcher's feet as the rush starts
	pushedDust = 6, -- kick particles at a pushed player's feet (`PushedAt`, when the engineer sets it)
	lineSeconds = 0.25, -- how long a speed line trails behind
	lineWidth = 0.12, -- studs
	-- Where each line leaves the body, in the HumanoidRootPart's axes (x right, y up, z back), in the order the
	-- budget's rushLines takes them.
	lines = {
		Vector3.new(-1.15, 0.9, 0.4),
		Vector3.new(1.15, 0.2, 0.4),
		Vector3.new(-0.95, -1.2, 0.4),
	},
	longest = 30, -- seconds; a RushUntil or StartledUntil further ahead than this is cut to it
	startledShake = 0.24,
	startledStuds = 0.3,
}

-- The areas closing at dusk and opening at sunrise (F66, data-model section 9): at every area gate this player
-- can use and is near, a violet haze as it closes and a sunrise sparkle and a warm ring as it opens.
Presets.areas = {
	points = 3, -- places along each gate's width the haze and sparkle come from
	sparkle = 6, -- gateSparkle particles at each of those places at sunrise
	ringDiameter = 12,
}

-- Butterflies by day (design v0.4 section 4; Derek 2026-10-27 22:43: round more than the door, and they come and
-- go). The `perSource` butterflies of a flower bed wander all of it and `pad` studs past its edges (at least `least`
-- from its middle each way): a flight to a random spot at about `speed` studs a second, often then a hover over it,
-- with a little loop of `roam` on top all the time. Each is out for a spell of `out` seconds, then away for `away`;
-- it comes down from `rise` studs up as it fades in, and rises as it fades out, over `fade` seconds.
Presets.butterfly = {
	wing = Vector3.new(0.34, 0.03, 0.28),
	colors = {
		Presets.palette.blush,
		Presets.palette.aurora,
		Presets.palette.lampWarm,
		Presets.palette.mint,
	},
	flapHz = 2.2,
	flapDegrees = 55,
	roam = Vector3.new(0.7, 0.35, 0.6), -- half size of the little loop it flutters in on top of its flight
	height = 1.6, -- studs over the flowers
	speed = 2.6,
	legShortest = 1.2, -- seconds of one flight
	legLongest = 5,
	hover = { chance = 0.45, shortest = 0.6, longest = 1.8 },
	pad = 1,
	least = Vector3.new(1.5, 0, 1.2),
	out = { 6, 14 }, -- seconds, shortest and longest
	away = { 8, 20 },
	firstAway = { 0, 10 }, -- the first wait once a bed is near, so they do not all arrive at once
	fade = 1,
	rise = 1.5,
	-- Now and then (`chance` of a flight) it flies over to another bed within `range` studs of its home bed, or
	-- back home, at about `speed` studs a second (`shortest` to `longest` seconds) in an arc `arc` studs high, and
	-- stays out at least `stay` seconds after it lands (Derek 2026-10-28 17:48: the Town Square's butterflies
	-- "going in circles are a little repetitive make them go between each one").
	hop = { chance = 0.35, range = 26, speed = 3.5, shortest = 2, longest = 9, arc = 1.2, stay = 3 },
	perSource = 2,
}

-- The z's over a sleeping cat (Logic.napZ): `labels` z's take turns, one each time the cat breathes out, each
-- rising for `life` breaths before it fades and starts again at the bottom. Places are in the z's box, which sits
-- `offset` studs up and to the right of the head on screen and is `box` studs: x 0 to 1 from the left, y 0 to 1
-- from the top. A z starts at (x, y) at `size` of a full z, rises by `rise` and drifts right by `drift` with a
-- `sway` to and fro, fades in over the first `fadeIn` of its life and out over the last `fadeOut`, tilting by
-- up to `tilt` degrees.
Presets.nap = {
	maxDistance = 45,
	labels = 3,
	life = 2.5,
	box = Vector2.new(1.8, 2.4),
	offset = Vector3.new(0.55, 1.35, 0),
	zSize = Vector2.new(0.42, 0.3), -- of the box, for a full z
	x = 0.22,
	y = 0.86,
	size = 0.45,
	rise = 0.76,
	drift = 0.5,
	sway = 0.07,
	fadeIn = 0.15,
	fadeOut = 0.35,
	tilt = 12,
}

-- `areaPuff` (#4069): pieces of the area's own puff at each of Presets.areas.points places along the foot of a gate
-- whose area has effects of its own (Presets.areaFx.areas), on top of the dissolve.
Presets.gate = { seconds = 1.4, playWithin = 70, areaPuff = 3 }

Presets.shutter = { seconds = 0.9, signSeconds = 0.6 }

-- A rank up: confetti and a smoke puff at any cafe's door in range. Your own cafe also gets a gold beam from roof
-- height, a gold ring across the street, confetti from both sides of the door (`sideStuds` either side, each a share
-- of the budget's confetti) and `fountains` sparkle fountains `fountainEvery` seconds apart.
Presets.rankUp = {
	within = 120,
	claimGrace = 2,
	beam = { width = 2.6, height = 22, seconds = 1.8 },
	ring = 18,
	ringSeconds = 0.8,
	sideStuds = 4,
	sideConfetti = 0.75,
	fountains = 3,
	fountainEvery = 0.3,
	fountain = 12, -- gateSparkle particles in each
	awayRoof = 10, -- #4922: away from the door the beam drops from this far over your feet
}

-- The Spin Wheel station (F49): the world wheel turns for everyone nearby whenever anyone spins and stops on the
-- won slice (LastSlice). It stops inside the server's 4 s SpinCooldownSeconds, so a player's next spin starts from
-- rest.
Presets.wheel = {
	seconds = 3.4, -- turning, easing to a stop
	turns = 3, -- whole turns before it settles
	stillTurns = 1, -- with Reduce Motion
	slices = 6, -- equal slices for a Wheel with no SliceSpans attribute (the old six-slice wheel)
	landWithin = 0.6, -- of a slice's width around its centre the wheel stops in, so never by an edge
	tick = 14, -- degrees the pointer is knocked aside as a slice edge passes it
	tickShare = 0.18, -- of a slice it takes to spring back
	chaseStep = 0.09, -- seconds between steps of the rim lights chasing round
	flashes = 3, -- the rim lights blink together when it stops
	flashSeconds = 0.6,
	sparkles = 10, -- at the pointer when it stops
	within = 120, -- studs; a spin farther away just moves the wheel to where it stopped
	-- How a prize is celebrated, by its chance in Catalog.spinWheel, only once the wheel has stopped on it: a
	-- "good" one (chance at most `good`) adds a mint ring and confetti from the top of the wheel, a "jackpot" (at
	-- most `jackpot`) gold confetti, a gold ring, `showers` sparkle showers and longer blinking.
	good = 0.16,
	jackpot = 0.02, -- the v2 wheel's two 0.5% slices only, not its 6% crate (#1411)
	goodRing = 8,
	jackpotRing = 12,
	ringSeconds = 0.6,
	goodConfetti = 0.5, -- of the budget's confetti
	jackpotConfetti = 1,
	showers = 3,
	showerEvery = 0.3,
	jackpotFlashes = 6,
	jackpotFlashSeconds = 1.2,
}

-- Signature effects (effects list section 1; round 4 Q8, 2026-10-27: "Yes thats a great idea make them special
-- because of rarity"): each Legendary and Mythical themed cat, keyed by CatId, shows one emitter (`emitter`, a
-- Presets.emitters key) on its Body or Head (`on`) in `colors`, and a gold one shows the same effect in `gold`.
-- `eyes`: the cat was modelled with glowing eyes (cats.py glow_eyes), so the iris of each eye turns Neon;
-- `goldEyes` is the eye colour of a gold one where the eyes are the effect (Ninja Cat). `moving`: only while the
-- cat moves. Only the nearest budget.signatureCats within `radius` studs show their emitter; eyes glow on all.
export type Signature = {
	emitter: string,
	-- "Body" or "Head" (or any part name's ending after the last cat name underscore, as "Candle_Glow"), or
	-- "Prop" / "Prop2" for the cat's first or second prop (parts named ..._Prop, ..._Prop2);
	-- a prop's emitter goes on its `props` biggest parts (1 if not set), sharing the rate, and falls back to the body
	-- while the prop has not streamed in
	on: string,
	props: number?,
	colors: { Color3 },
	gold: { Color3 },
	eyes: boolean?,
	goldEyes: Color3?,
	moving: boolean?,
	notes: boolean?, -- music notes float up off the prop as well (Jazz Cat, Presets.notes)
	-- a small touch on a Rare: it only takes a slot of budget.signatureCats that no rarer cat nearby needs
	minor: boolean?,
	-- #4069 (Derek 2026-11-13: "make the rarer ones more special"): more on top for the rarest cats
	extras: { SignatureExtra }?, -- more emitters, each on its own part
	orbit: SignatureOrbit?, -- motes circling the cat, each leaving a trail of `emitter`
	arrive: SignatureArrive?, -- a gust where it appears (a stray landing, a cat set down)
}
export type SignatureExtra = { emitter: string, on: string, moving: boolean? }
-- `count` motes (`countLow` on the low tier) circle the body `radius` of its widest side out and `height` of its
-- height up, tilted `tilt` radians, once every `seconds`. They hold still with Reduce Motion.
export type SignatureOrbit = {
	emitter: string,
	count: number,
	countLow: number,
	radius: number,
	height: number,
	tilt: number,
	seconds: number,
}
export type SignatureArrive = { ring: number, burst: number, preset: string }

local palette = Presets.palette
-- the Secret cats' circling motes: one more than a Mythical's, a little wider and slower
local function secretOrbit(emitter: string): SignatureOrbit
	return {
		emitter = emitter,
		count = 6,
		countLow = 3,
		radius = 0.9,
		height = 0.6,
		tilt = 0.35,
		seconds = 3.5,
	}
end
Presets.signature = {
	void = { -- Ninja Cat: glowing eyes and a twinkle on the black coat
		emitter = "sigGlint",
		on = "Body",
		colors = { palette.sparkle, palette.offwhite },
		gold = { palette.goldLight, palette.golden },
		eyes = true,
		goldEyes = palette.goldLight,
	},
	midnight = { -- Wizard Cat: little stars drifting up off the night sky coat
		emitter = "sigRise",
		on = "Body",
		colors = { palette.sparkle, palette.offwhite },
		gold = { palette.goldLight, palette.golden },
		eyes = true,
	},
	blossom = { -- Fairy Cat: a petal now and then
		emitter = "sigFall",
		on = "Body",
		colors = { palette.furRose, palette.nosePink, palette.offwhite },
		gold = { palette.goldLight, palette.golden },
	},
	aurora = { -- Astro Cat: a glow shifting from galaxy blue through violet to mint
		emitter = "sigHalo",
		on = "Body",
		colors = { palette.galaxyBlue, palette.aurora, palette.mint },
		gold = { palette.goldDark, palette.golden, palette.goldLight },
		eyes = true,
	},
	marshmallow = { -- Super Cat: a whoosh behind the cape as it runs
		emitter = "sigWhoosh",
		on = "Body",
		colors = { palette.offwhite, palette.shirtRed },
		gold = { palette.goldLight, palette.golden },
		moving = true,
	},
	comet = { -- Ice Cream Cat: floating sprinkles off the cone hat
		emitter = "sigRise",
		on = "Head",
		colors = {
			palette.neonPink,
			palette.signTeal,
			Presets.rarity.Legendary,
			palette.shirtBlue,
			palette.mint,
		},
		gold = { palette.goldLight, palette.golden, palette.goldDark, palette.sparkle },
		eyes = true,
	},
	old_oak = { -- Antler Cat: a leaf drifting down off the antlers
		emitter = "sigFall",
		on = "Head",
		colors = { palette.leaf, palette.mint },
		gold = { palette.golden, palette.goldDark },
	},
	wisp = { -- Unicorn Cat: a sparkle trail off the glowing horn
		emitter = "sigGlint",
		on = "Head",
		colors = { palette.pastelSky, palette.sparkle, palette.blush },
		gold = { palette.goldLight, palette.sparkle },
		eyes = true,
	},
	bottlecap = { -- King Cat: glints off the bottle cap crown
		emitter = "sigGlint",
		on = "Head",
		colors = { palette.offwhite, palette.sparkle },
		gold = { palette.golden, palette.goldLight },
	},
	eclipse = { -- Dragon Cat: tiny harmless sparks that fade to smoke
		emitter = "sigRise",
		on = "Head",
		colors = { palette.sparkle, palette.lampWarm, palette.furGrey },
		gold = { palette.sparkle, palette.golden, palette.goldDark },
		eyes = true,
	},
	-- The area-themed cats of design v0.13 (F78, data-model 3d). Wizard, Astro and Super Cat above are spare cats
	-- now; owned ones keep their effects.
	neon = { -- Jazz Cat: music notes floating up off the glowing saxophone, which twinkles in the sign colours
		emitter = "sigGlint",
		on = "Prop2",
		colors = { palette.neonPink, palette.signTeal, palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		eyes = true,
		notes = true,
	},
	balloon = { -- Balloon Cat: its three balloons shine; the floaty bob is the cat motion's (Animation-Engineer)
		emitter = "sigGlint",
		on = "Prop",
		props = 3,
		colors = { palette.offwhite, palette.sparkle, palette.blush },
		gold = { palette.goldLight, palette.sparkle },
	},
	gnome = { -- Gnome Cat: little lucky sparkles, clover green and gold, round the pointy hat
		emitter = "sigGlint",
		on = "Head",
		colors = { palette.leaf, palette.mint, palette.goldLight },
		gold = { palette.golden, palette.goldLight, palette.sparkle },
	},
	-- #4069 Snowy Mountain (Tier 8). The ladder: a Rare kicks up snow as it moves, an Epic gets a glint, the Legendary breath, a glint and glowing
	-- eyes, the Mythical flakes, a circling swirl, a frost trail, glowing eyes and a gust where it lands.
	ice = { -- Ice Cat (Epic): a glint now and then off the ice spikes along its back
		emitter = "sigGlint",
		on = "Prop",
		props = 2,
		colors = { Color3.fromRGB(214, 240, 255), palette.offwhite },
		gold = { palette.goldLight, palette.sparkle },
	},
	snow_leopard = { -- Snow Leopard Cat (Epic): a warm glint off its climber's head lamp
		emitter = "sigGlint",
		on = "Prop2",
		colors = { Color3.fromRGB(255, 240, 200), palette.offwhite },
		gold = { palette.goldLight, palette.sparkle },
	},
	-- the two Rares: no glow, only a little snow kicked up while they move, and never ahead of a rarer cat
	snow_boots = { -- Snow Boots Cat (Rare): snow off its boots as it walks
		emitter = "sigSnowKick",
		on = "Body",
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 240, 255) },
		gold = { palette.goldLight, palette.offwhite },
		moving = true,
		minor = true,
	},
	ski = { -- Ski Cat (Rare): a spray of snow behind its skis
		emitter = "sigSnowKick",
		on = "Body",
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 240, 255) },
		gold = { palette.goldLight, palette.offwhite },
		moving = true,
		minor = true,
	},
	white_tiger = { -- White Tiger Cat (Legendary): frosty breath, ice-blue eyes and a soft glint on the white coat
		emitter = "sigFrost",
		on = "Head",
		colors = { Color3.fromRGB(236, 246, 255), palette.offwhite },
		gold = { palette.goldLight, palette.offwhite },
		eyes = true,
		extras = { { emitter = "sigGlint", on = "Body" } },
	},
	blizzard = { -- Blizzard Cat (Mythical): a living snowstorm
		emitter = "sigFall",
		on = "Body",
		colors = { palette.offwhite, Color3.fromRGB(196, 226, 255), palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		eyes = true,
		extras = { { emitter = "sigFrostTrail", on = "Body", moving = true } },
		orbit = {
			emitter = "sigSnowflake",
			count = 5,
			countLow = 3,
			radius = 0.75,
			height = 0.55,
			tilt = 0.3,
			seconds = 3.2,
		},
		arrive = { ring = 9, burst = 10, preset = "smokePuff" },
	},
	-- #4070 the Water Park (Tier 9). The same ladder: each Epic one effect on its lit prop, the Legendary a glint on
	-- its lit loop, sparks off the goggles and a whoosh while it runs, the Mythical drips, circling bubbles, a wet
	-- trail, glowing eyes and a splash where it lands.
	-- the two Rares: a small touch each, never ahead of a rarer cat
	candy_apple = { -- Candy Apple Cat (Rare): a glint now and then off its caramel glaze
		emitter = "sigGlintSmall",
		on = "Prop",
		colors = { Color3.fromRGB(255, 226, 170), palette.offwhite },
		gold = { palette.goldLight, palette.sparkle },
		minor = true,
	},
	cotton_candy = { -- Cotton Candy Cat (Rare): a little sugar drifts off its floss as it moves
		emitter = "sigSnowKick",
		on = "Prop",
		colors = { Color3.fromRGB(255, 190, 220), Color3.fromRGB(190, 226, 255) },
		gold = { palette.goldLight, palette.offwhite },
		moving = true,
		minor = true,
	},
	clown = { -- Clown Cat (Epic): confetti twinkles off the lit pom of its hat, in the pom colours
		emitter = "sigGlint",
		on = "Prop",
		colors = {
			palette.shirtRed,
			palette.shirtBlue,
			Color3.fromRGB(255, 226, 120),
			palette.neonPink,
		},
		gold = { palette.goldLight, palette.golden, palette.sparkle },
	},
	water_gun = { -- Water Gun Cat (Epic): drops falling off the water blaster on its back
		emitter = "sigDrip",
		on = "Prop",
		colors = { Color3.fromRGB(170, 226, 250), palette.offwhite },
		gold = { palette.goldLight, palette.golden },
	},
	coaster = { -- Coaster Cat (Legendary): the lit loop glints, sparks lift off, and it leaves a whoosh at speed
		emitter = "sigGlint",
		on = "Prop2",
		colors = { Presets.rarity.Legendary, palette.sparkle, palette.shirtRed },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigRise", on = "Body" },
			{ emitter = "sigWhoosh", on = "Body", moving = true },
		},
	},
	water = { -- Water Cat (Mythical): a cat of living water
		emitter = "sigDrip",
		on = "Body",
		colors = { Color3.fromRGB(170, 226, 250), palette.offwhite, palette.mint },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		eyes = true,
		extras = {
			{ emitter = "sigGlint", on = "Prop" },
			{ emitter = "sigWetTrail", on = "Body", moving = true },
		},
		orbit = {
			emitter = "sigBubble",
			count = 5,
			countLow = 3,
			radius = 0.8,
			height = 0.5,
			tilt = -0.25,
			seconds = 3.6,
		},
		arrive = { ring = 9, burst = 10, preset = "splashDrops" },
	},
	-- #4071 the Medieval Castle (Tier 10), the same ladder: each Epic one effect on its lit prop, the Legendary a
	-- glint on her jewels, a slow fall of gold dust and a soft royal glow, the Mythical rising embers, circling
	-- sparks, an ember trail, glowing eyes and a burst of sparks where it lands.
	-- the two Rares: a small touch each, never ahead of a rarer cat
	jester = { -- Jester Cat (Rare): a glint now and then off the gold bells of its hat
		emitter = "sigGlintSmall",
		on = "Prop",
		colors = { palette.goldLight, palette.offwhite },
		gold = { palette.goldLight, palette.sparkle },
		minor = true,
	},
	rogue = { -- Rogue Cat (Rare): a wisp of shadow behind it as it sneaks, gone in half a second
		emitter = "sigSnowKick",
		on = "Body",
		colors = { Color3.fromRGB(70, 64, 86), Color3.fromRGB(110, 100, 130) },
		gold = { palette.goldLight, palette.offwhite },
		moving = true,
		minor = true,
	},
	knight = { -- Knight Cat (Epic): a glint now and then off the gold paw crest on its shield
		emitter = "sigGlint",
		on = "Prop2",
		colors = { palette.goldLight, palette.offwhite },
		gold = { palette.goldLight, palette.sparkle },
	},
	mage = { -- Mage Cat (Epic): little stars drifting up off the lit star of its hat
		emitter = "sigRise",
		on = "Prop",
		colors = { palette.sparkle, palette.aurora, palette.pastelSky },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
	},
	queen = { -- Queen Cat (Legendary): her crown's jewels glint, gold dust falls round her, and she glows a little
		emitter = "sigGlint",
		on = "Prop",
		colors = { Presets.rarity.Legendary, palette.sparkle, palette.blush },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigFall", on = "Body" },
			{ emitter = "sigHalo", on = "Body" },
		},
	},
	dragon_knight = { -- Dragon Knight (Mythical): a knight with a dragon's fire in it
		emitter = "sigRise",
		on = "Prop",
		colors = { Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 96, 64), palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		eyes = true,
		extras = {
			{ emitter = "sigGlint", on = "Prop2" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = {
			emitter = "sigEmber",
			count = 5,
			countLow = 3,
			radius = 0.8,
			height = 0.6,
			tilt = 0.35,
			seconds = 3,
		},
		arrive = { ring = 9, burst = 10, preset = "catchSparkle" },
	},
	-- #4251 Harvest Hollow's rarer cats (Wed Nov 25 to Sun Dec 6), the same ladder in autumn colours, on the lit
	-- parts of their models (`..._Leaves_Glow`, `..._Wheat_Glow`, `..._Glow`; a copy without them shows on its body).
	-- the three Rares: a small touch each, never ahead of a rarer cat
	apple_pie = { -- Apple Pie Cat (Rare): a warm glint now and then off its pie's glaze
		emitter = "sigGlintSmall",
		on = "Prop",
		colors = { Color3.fromRGB(255, 220, 160), palette.offwhite },
		gold = { palette.goldLight, palette.sparkle },
		minor = true,
	},
	cornstalk = { -- Cornstalk Cat (Rare): a few husk flecks fall off its stalk as it moves
		emitter = "sigSnowKick",
		on = "Prop",
		colors = { Color3.fromRGB(246, 214, 110), Color3.fromRGB(196, 178, 96) },
		gold = { palette.goldLight, palette.offwhite },
		moving = true,
		minor = true,
	},
	pumpkin_spice = { -- Pumpkin Spice Cat (Rare): a puff of cinnamon behind it as it walks
		emitter = "sigSnowKick",
		on = "Body",
		colors = { Color3.fromRGB(214, 130, 70), Color3.fromRGB(240, 196, 150) },
		gold = { palette.goldLight, palette.offwhite },
		moving = true,
		minor = true,
	},
	cranberry = { -- Cranberry Cat (Epic): a glint now and then off its berries
		emitter = "sigGlint",
		on = "Prop",
		colors = { Color3.fromRGB(226, 60, 84), palette.sparkle },
		gold = { palette.goldLight, palette.sparkle },
	},
	maple_leaf = { -- Maple Leaf Cat (Legendary): leaves drift down off it, the lit leaves glint, and it glows a little
		emitter = "sigFall",
		on = "Leaves_Glow",
		colors = {
			Color3.fromRGB(236, 160, 60),
			Color3.fromRGB(214, 84, 44),
			Color3.fromRGB(246, 206, 96),
		},
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		eyes = true,
		extras = {
			{ emitter = "sigGlint", on = "Leaves_Glow" },
			{ emitter = "sigHalo", on = "Body" },
		},
	},
	harvest_moon = { -- Harvest Moon Cat (Mythical): moonlit motes rise off its wheat and circle it like fireflies
		emitter = "sigRise",
		on = "Wheat_Glow",
		colors = { Color3.fromRGB(255, 214, 120), Color3.fromRGB(255, 168, 72), palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		eyes = true,
		extras = {
			{ emitter = "sigGlint", on = "Prop" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = {
			emitter = "sigEmber",
			count = 5,
			countLow = 3,
			radius = 0.8,
			height = 0.6,
			tilt = 0.3,
			seconds = 3.4,
		},
		arrive = { ring = 9, burst = 10, preset = "catchSparkle" },
	},
	-- Sprinkles, the Starter Bundle's baker (Derek 2026-11-14: as good as an Epic from the best area, effects
	-- included). The Epic rung of the same ladder on the lit parts of its model (#4190): sprinkles drift up off the
	-- cupcake's candle through the puff's own colours, and the cherry on its toque twinkles a little. `on` names
	-- the lit parts (..._Candle_Glow, ..._Cherry_Glow); a copy without them shows both on its body.
	sprinkles = {
		emitter = "sigRise",
		on = "Candle_Glow",
		colors = {
			palette.neonPink,
			palette.golden,
			palette.mint,
			palette.eyeBlue,
			palette.aurora,
		},
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Cherry_Glow" },
		},
	},
	-- The Secret cats (#4369): the rung above Mythical on the same ladder, on top of the starlight halo every
	-- Secret shares (Effects/SecretGlow). Each has its own steady effect on its lit part (..._Stars_Glow and so on; a
	-- copy without that part shows it on its body), four extras (one only while it walks), six motes circling it
	-- (three on a phone) and a gust where it appears. Every emitter stays at Rate 2 or less.
	nebula = { -- Nebula: stars drift up off its starfield
		emitter = "sigRise",
		on = "Stars_Glow",
		colors = { palette.aurora, palette.pastelSky, palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigGlint", on = "Glow" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	glitch = { -- Glitch: its sprite blinks in three screen colours
		emitter = "sigGlint",
		on = "Sprite_Glow",
		colors = {
			Color3.fromRGB(90, 240, 255),
			Color3.fromRGB(255, 90, 220),
			Color3.fromRGB(140, 255, 120),
		},
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigGlintSmall", on = "Glow" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	cafe_ghost = { -- Cafe Ghost: a pale mist round it, wisps rising off its head
		emitter = "sigHalo",
		on = "Body",
		colors = { palette.offwhite, palette.pastelSky },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigRise", on = "Head" },
			{ emitter = "sigGlintSmall", on = "Tail" },
			{ emitter = "sigWhoosh", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	lucky_clover = { -- Lucky Clover: its rainbow twinkles, green luck drifts up
		emitter = "sigRise",
		on = "Rainbow_Glow",
		colors = { Color3.fromRGB(120, 230, 120), palette.mint, palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigGlint", on = "Glow" },
			{ emitter = "sigFall", on = "Body" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	moonstag = { -- Moonstag: moonlight falls off its antlers
		emitter = "sigFall",
		on = "Grove_Glow",
		colors = { palette.pastelSky, palette.offwhite, palette.aurora },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigGlint", on = "Glow" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	ooze = { -- Ooze: drips off its spill, a glowing trail where it walks
		emitter = "sigDrip",
		on = "Spill_Glow",
		colors = { Color3.fromRGB(150, 255, 110), Color3.fromRGB(90, 220, 140) },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigBubble", on = "Glow" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigWetTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigBubble"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	djinn = { -- Djinn: smoke curls off it, gold dust in the air
		emitter = "sigHalo",
		on = "Smoke_Glow",
		colors = { palette.aurora, palette.eyeBlue, palette.goldLight },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigRise", on = "Glow" },
			{ emitter = "sigGlint", on = "Prop" },
			{ emitter = "sigWhoosh", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	phoenix = { -- Phoenix: warm sparks rise off its wings (little lights, no flame)
		emitter = "sigRise",
		on = "Wings_Glow",
		colors = { Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 96, 64), palette.sparkle },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigGlint", on = "Glow" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	abyss = { -- Abyss: deep sea lights on its sail, bubbles rising
		emitter = "sigBubble",
		on = "Sail_Glow",
		colors = { Color3.fromRGB(80, 220, 255), palette.eyeBlue, palette.mint },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigGlint", on = "Glow" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigWetTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigBubble"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
	excalipurr = { -- Excalipurr: its blade glints, light rises round it
		emitter = "sigGlint",
		on = "Blade_Glow",
		colors = { palette.sparkle, palette.offwhite, palette.pastelSky },
		gold = { palette.goldLight, palette.golden, palette.sparkle },
		extras = {
			{ emitter = "sigGlintSmall", on = "Head" },
			{ emitter = "sigRise", on = "Glow" },
			{ emitter = "sigHalo", on = "Body" },
			{ emitter = "sigEmberTrail", on = "Body", moving = true },
		},
		orbit = secretOrbit("sigEmber"),
		arrive = { ring = 10, burst = 12, preset = "catchSparkle" },
	},
} :: { [string]: Signature }
Presets.signatureFx = {
	radius = 40, -- studs from the player
	movedStuds = 0.5, -- a `moving` effect runs while the cat moved this far since the last choice
}

-- Jazz Cat's music notes (F78): drawn notes (a head, a stem and a flag, every other one a pair joined by a beam) in
-- the cat's colours, one every `every` seconds from `above` studs over its saxophone, rising `rise` studs with a
-- `sway` to and fro over `seconds`, fading in over `fadeIn` and out over the last `fade`; at most `most` per cat.
-- Only on cats that show their signature effect (the nearest signatureCats). They only drift, so Reduce Motion keeps
-- them.
Presets.notes = {
	every = 1,
	seconds = 2.2,
	rise = 1.8,
	sway = 0.3,
	swayHz = 0.7,
	fadeIn = 0.2,
	fade = 0.6,
	above = 0.3,
	size = 0.5, -- studs tall
	most = 3,
	maxDistance = 60,
}

-- The Codes Cat's walk-in circle (F65; Derek 2026-10-27 20:10: "a clear area circle to walk into to open code
-- entering menu"): a soft mint ring round the inside of the circle's rim that breathes between `glow` transparencies
-- every `seconds` (steady with Reduce Motion), brighter (`inside`) while you stand in it, motes rising off it within
-- the budget's ambientRadius (not in Low performance) and a ring with a few sparkles as you step in. In and out use
-- the code box's own edges, CodesCircleRadius (`radius` until Config has it) and `leaveAfter` studs past it, so the
-- glow and the box agree. The glow is a ring, `ring` studs wide `inset` in from the edge with a fainter `halo` band
-- inside it at `haloShare` of its strength, drawn flat (a SurfaceGui, no Neon bloom), so the middle of the circle
-- and the ticket on it stay clear (Derek 2026-10-28 00:47: "too bright and can't see what symbol its showing").
Presets.codes = {
	radius = 6, -- #3112: 4 until the circles grew
	leaveAfter = 1,
	glow = { 0.75, 0.5 },
	inside = 0.25,
	seconds = 1.2, -- one way; a breath is twice this
	ring = 0.25,
	halo = 0.3,
	haloShare = 0.35,
	inset = 0.3, -- clear of the modelled rim; the halo's inner edge stays clear of the ticket's corners (3.1 studs)
	pixelsPerStud = 24,
	lift = 0.06, -- studs above the circle's top
	ringPad = 1,
	ringSeconds = 0.45,
	sparkles = 10,
	padShare = 1.4, -- the motes' square pad is this many radii wide, so its corners stay inside the circle
	checkEvery = 0.1,
}

-- A red "!" over each rescue trap that holds a stuck cat (Derek 2026-10-28 01:01: "rescue mini games like stuck in
-- trash and others should have a red exclamation mark coming out"), so players spot a rescue from across the area.
-- It pops up out of the trap over `popSeconds`, rising `rise` studs to sit `above` + `rise` studs over the cat, then
-- bobs `bob` studs every `bobSeconds` (it just sits there with Reduce Motion). It is `size` studs tall plus `pixels`
-- on screen, so it still reads from afar, in `colour` with an `outline` round it. The nearest `most` within
-- `maxDistance` show, checked every `checkEvery` seconds; none while someone is rescuing that cat (LockedBy) or
-- once you are within `hideWithin` studs, where its Rescue card takes over (GrabRangeStuds is 10).
Presets.stuckMark = {
	colour = Presets.palette.shirtRed,
	outline = Presets.palette.offwhite,
	outlinePixels = 3,
	above = 0.3,
	rise = 0.8,
	popSeconds = 0.35,
	bob = 0.3,
	bobSeconds = 0.6, -- one way
	size = 1.4,
	pixels = 18,
	maxDistance = 100, -- in view only (Derek 12:13); was 160 when it drew over everything
	hideWithin = 10,
	showAfter = 1, -- a hidden mark comes back only this far past hideWithin
	lostAfter = 0.5, -- seconds out of view before it hides
	gem = 1.4, -- studs: the cat's rarity gem and its halo over the "!" (#2231), as wide as the "!" mark
	gemGap = 0.15,
	seeThrough = 3, -- see-through parts a sight line passes before it gives up
	most = 6,
	checkEvery = 0.25,
}

-- Opening a Cafe Crate at the Golden Fish Market (F53): a puff of ice off the stall's counter and the won piece's
-- rarity popping `above` studs over it, as a catch of that rarity does (catchPop). On the modelled stall (market.py)
-- the pop comes from `counterY` up and `counterZ` toward the front from its pivot, over the ice.
Presets.market = {
	within = 30, -- studs from the player to the stall (FishMarketRange is 14)
	above = 0.6,
	puff = 6, -- dust particles, tinted like ice
	counterY = 3.1,
	counterZ = -0.65,
	floorDepth = 12, -- how far under the counter a Mythical crate's shockwave looks for the ground
}
-- The opened crate on the counter (crates.py's models, about 2.5 by 2 by 2 studs at full size): scaled down to sit on
-- the stall's ice, the lid swung up `lidDegrees` (crates.py: 105 is wide open with no clipping) over `lidSeconds`,
-- held for `hold` seconds from the open and faded over `fade`.
-- While the Market window's crate reel runs (F103, crate-reel.md), the lid knocks on its hinge as hard as the reel is
-- fast (Logic.crateReelPace): up to `reelRattle` degrees and `reelHop` studs, `reelHz` knocks a second, the same for
-- every prize. The lid opens at the stop: the time Config's CrateReel* numbers give (Logic.crateReelStop), or the
-- UI's CrateReelLanded moment (a tap skips), in which case the stop plus `reelSafety` seconds is only the fallback.
Presets.marketCrate = {
	scale = 0.6,
	lidDegrees = 105,
	lidSeconds = 0.3,
	hold = 1.8,
	fade = 0.4,
	reelRattle = 3,
	reelHop = 0.04,
	reelHz = 9,
	reelSafety = 1.5,
}

-- Rainbow coats (F99, rainbow-coat.md section 2): a rainbow cat's own parts in `hues`, each part's colour drifting
-- round them with its phase set by how far back from the nose it sits, so bands flow nose to tail, one lap every
-- `period` seconds and `spread` laps along the cat; a part keeps `least` to all of its band's brightness by how light
-- its own colour was against the body's, so stripes still show, and a mark lighter than the body is up to `lift`
-- paler. Only the `pieces` named here change (not the eyes, props or outfits),
-- and in them a part shorter than `keepShare` of its piece's biggest part (the nose, the mouth, the blush) keeps its
-- colour. The nearest budget.rainbowCats within `within` studs (no more than Config.RainbowAnimateMax) flow at `hz`
-- updates a second, glow (`glow`) and drop `trail` sparkles while they move faster than `moving` studs a second; the
-- nearest budget.rainbowOutlines of those also get an outline in the band colour. The rest show still bands. When a
-- rainbow stray spawns (`RainbowSpawned`), a bundle of six thin beams, one per hue, rises from it (`beam`) for
-- anyone within `beam.within`. Reduce Motion stills the bands and drops the trail and beam; glow and outline stay.
Presets.rainbow = {
	hues = {
		Color3.fromRGB(255, 72, 88), -- red
		Color3.fromRGB(255, 150, 48), -- orange
		Color3.fromRGB(255, 222, 60), -- yellow
		Color3.fromRGB(84, 214, 112), -- green
		Color3.fromRGB(72, 182, 255), -- sky blue
		Color3.fromRGB(168, 108, 255), -- violet
	},
	period = 3,
	spread = 1,
	least = 0.7,
	lift = 0.5, -- the most a mark lighter than the body is lifted toward white
	keepShare = 0.2,
	pieces = { "Body", "Head", "EarL", "EarR", "Tail", "LegF1", "LegF2", "LegB1", "LegB2" },
	within = 120,
	hz = 20,
	hzLow = 12, -- on a phone or in Low performance: a 3 s lap still reads as flowing at 12 steps a second
	pick = 0.25, -- seconds between choosing which cats flow
	recount = 8, -- every this many picks (2 s) a cat's parts are counted again, for parts that streamed in late
	glow = { color = Color3.new(1, 1, 1), range = 6, brightness = 0.6 },
	outline = 0.25, -- outline transparency
	moving = 0.6,
	beam = { width = 0.5, height = 50, seconds = 3, ring = 0.55, within = 400 },
}

-- The Rescue Rally (F101, rescue-rally.md section 4) on this player's screen, over the UI's banner bar (`RallyBar`):
-- each point anyone scores pops a "+N" in `text` up from just under the bar into the end of its fill, and this
-- player's own points fly a paw with the "+N" up from the bottom middle of the screen. Each flies `seconds`, popping
-- in over `popIn` and shrinking to `land` as it arrives, with a small sparkle there; no more than the budget's
-- rallyPops at once, the rest skipped. Each step of the bar (`steps`) runs `stepSparkles` sparkles along the filled
-- bar, twice as many in gold for the full bar. Reduce Motion drops the pops and halves the step sparkles.
Presets.rally = {
	displayOrder = 11, -- over the HUD (10), under the area title (12) and the modals (20)
	steps = { 0.25, 0.5, 1 }, -- only if Catalog.rallySteps is missing; Effects/Rally reads the server's milestones
	seconds = 0.65,
	popIn = 0.14,
	land = 0.55,
	below = { 34, 64 }, -- pixels under the bar the "+N" pops at
	spreadX = 46, -- pixels either side of the fill end
	lift = { 0.12, 0.28 }, -- how far a flight bends, a share of its length, to either side
	textSize = 26,
	ownSize = 44, -- the paw's size in pixels
	text = Color3.fromRGB(255, 249, 242),
	stroke = Color3.fromRGB(217, 102, 40),
	paw = Color3.fromRGB(255, 166, 77),
	sparkle = Color3.fromRGB(255, 244, 176),
	arrive = 5, -- sparkles where a pop lands
	stepSparkles = 14,
	stepSeconds = 0.8,
	full = Color3.fromRGB(242, 193, 78),
}

-- A Cat Storm's strays fall out of the sky (Effects/StormFall, #4197). A stray the server marked `StormCat` that
-- appears within `within` studs: a `streak` of light drops from `height` studs up over `seconds`, then a ring `ring`
-- studs wide and `puffCount` of `puff` where it lands. At most budget.areaPuffs falls a second. While the storm
-- runs the `drift` emitter rains slow sparkles from a `driftBox` kept `driftHeight` over you, moved every
-- `driftEvery` seconds. `markWait`: how long a new stray is watched for the server's mark.
Presets.stormFall = {
	within = 140,
	height = 60,
	seconds = 0.55,
	streak = Vector3.new(0.6, 7, 0.6),
	colour = Presets.palette.goldLight,
	ring = 5,
	ringSeconds = 0.7,
	puff = "stormPuff",
	puffCount = 10,
	drift = "stormDrift",
	driftBox = Vector3.new(70, 1, 70),
	driftHeight = 22,
	driftEvery = 0.5,
	markWait = 2,
	freshFor = 8, -- seconds after its SpawnedAt that a storm stray streaming in still counts as just dropped (#4796)
}

-- #4197 (Effects/AdminAir): the drift an admin event hangs round you while it runs, by its effect's name. Since #4325
-- every event has one (AdminFlashLogic.rainOf), all of them thin. One emitter on an unseen `box` held `height`
-- studs over the camera's focus, looked at every `every` seconds. None with Reduce Motion or in Low performance.
Presets.adminAir = {
	kinds = {
		goldBoost = "goldHourDrift",
		moneyStorm = "moneyStormDrift",
		crateDrop = "goldHourDrift",
		wheel = "goldHourDrift",
		bowlSpeed = "adminRoseDrift",
		catStorm = "adminStormDrift",
		rainbowBoost = "adminRainbowDrift",
		secretHunt = "adminVioletDrift",
		traitParty = "adminVioletDrift",
		fishFountain = "adminBlueDrift",
		speedRush = "adminMintDrift",
	} :: { [string]: string },
	box = Vector3.new(70, 1, 70),
	height = 22,
	every = 0.5,
}

-- #4197 (Effects/AdminDrops): the stand-ins that fly in what an admin event drops, for drops within `within` studs.
-- Fish Fountain: a `blob` arcs from the plinth to its fish in `seconds`, `rise` studs high at the middle, then
-- `splashCount` glints. Crate Drop: a `box` under a `canopy` on `cord` studs of line comes down from `height` over
-- the `seconds` before the server's LandsAt, leaning up to `swayDegrees` each way every `swaySeconds`, then a ring
-- and a puff.
Presets.adminDrops = {
	within = 160,
	fish = {
		seconds = 0.8,
		rise = 9,
		blob = Vector3.new(1.1, 1.1, 1.1),
		colour = Presets.palette.golden,
		splash = "coinGlint",
		splashCount = 6,
		fresh = 2, -- seconds after the server's DroppedAt that a fish still arcs in; later it streamed in and just shows
		remember = 120, -- seconds a fish's spot is remembered, so one streaming back in does not arc again
	},
	-- the pickup pop (Derek2 11-16): a bead `bead` studs wide hops `hop` studs and shrinks away over `seconds`, with
	-- `glints` glints and a `ring` stud ring; only within `within` studs, and only when a character was within
	-- `reach` studs of the fish as it went (a touch, not a fish running out)
	pickup = {
		-- a fish's life on the server (AdminDropService FISH_LIFE, from its DroppedAt): one going within `margin` of it
		-- ran out, so it gets no pop
		life = 20,
		margin = 1,
		reach = 7,
		within = 120,
		bead = 0.7,
		hop = 2,
		seconds = 0.35,
		glint = "coinGlint",
		glints = 5,
		ring = 3,
		colour = Presets.palette.golden,
	},
	crate = {
		seconds = 3,
		height = 45,
		box = Vector3.new(3, 3, 3),
		colour = Presets.palette.golden,
		canopy = Vector3.new(8, 3.2, 8),
		canopyColour = Presets.palette.neonPink,
		cord = 5,
		cordColour = Presets.palette.offwhite,
		swayDegrees = 6,
		swaySeconds = 1.6,
		ring = 7,
		ringSeconds = 0.5,
		puff = "stormPuff",
		puffCount = 10,
	},
	-- #4888 the crate grab pop (Effects/AdminDrops.popCrate): a copy of `art` on the spot, its lid turning `lidDegrees`
	-- over `open` seconds, held `hold`, then shrunk away over `shrink`; `count` sparkles `lift` studs up and a `ring`
	-- stud ring. Only within `within` studs, and only when a character was within `reach` studs as it went.
	cratePop = {
		art = "CatCafe_Prop_Crate_Drop",
		life = 90, -- a crate's life after it lands (AdminDropService CRATE_LIFE, from LandsAt); later it ran out
		reach = 9,
		within = 140,
		lidDegrees = 110,
		open = 0.25,
		hold = 0.25,
		shrink = 0.3,
		burst = "catchSparkle",
		count = 14,
		lift = 2.5,
		ring = 6,
		ringSeconds = 0.4,
		colour = Presets.palette.golden,
	},
}

-- #4251 (Effects/HarvestFx): Harvest Hollow. Leaves (`air`) fall from a `box` held `height` studs over the camera's
-- focus while you are within `airWithin` studs of the Thankful Board (`boardTag`), looked at every `every` seconds,
-- at `calmRate` of the rate with Reduce Motion. A patch pumpkin (`pumpkinTag`) whose `readyAttribute` goes false
-- within `within` studs pops `pickCount` pieces `lift` studs up and a `pickRing` stud ring; one that comes back
-- sprouts `regrowCount` green sparkles. Every `glintEvery` seconds the nearest `glintMost` ready pumpkins within
-- `glintWithin` studs give `glintCount` gold glints. `inside` the area is within `airWithin` too (the song, the pie).
-- Snowglobe Village's world effects (Effects/SnowglobeFx, Christmas Event Dec 1). Tag names are placeholders until
-- Model-Agent's village and Gameplay-Engineer's event row land; change them here only.
-- Christmas Event (Effects/SnowglobeFlakes): the Snowflake patch. Ready flakes bob `height` studs over `period`
-- seconds (each `phaseStep` seconds behind the one before) and turn once every `spin` seconds within `bobWithin`
-- studs; a pick within `within` studs bursts `pickCount` icy sparkles `lift` studs up and a `pickRing` stud ring, a
-- regrow `regrowCount`; a rise in your Snowflakes pops "+N Snowflakes" over your head for `popSeconds`.
Presets.snowglobeFlakes = {
	flag = "christmasEvent",
	tag = "SnowglobeFlake",
	touchName = "Touch",
	readyAttribute = "Ready",
	bobWithin = 90,
	height = 0.35,
	period = 2.4,
	phaseStep = 0.37,
	spin = 6,
	within = 120,
	lift = 1.2,
	sparkle = "catchSparkle",
	pickCount = 10,
	pickRing = 5,
	colour = Color3.fromRGB(143, 211, 255), -- icy blue, the Gift Stall's
	regrowCount = 5,
	regrowColour = Color3.fromRGB(255, 255, 255),
	popColour = Color3.fromRGB(143, 211, 255),
	popSeconds = 1.4,
}

Presets.snowglobeFx = {
	centreTag = "SnowglobeCentre",
	portalTag = "SnowglobePortal",
	every = 0.5,
	airWithin = 140,
	snow = "snowfall",
	box = Vector3.new(60, 1, 60),
	height = 18,
	calmRate = 0.2,
	swirl = "globeSwirl",
	portalWithin = 120,
	portalLift = 6,
	-- part 2 (#5326's names): the spin, the star and the night lights
	parts = {
		prefix = "CatCafe_Snowglobe_",
		spin = "CatCafe_Snowglobe_Portal_Spin",
		star = "CatCafe_Snowglobe_Set_006_TreeStar_Glow",
		lights = {
			"CatCafe_Snowglobe_Set_003_TreeLights_Glow",
			"CatCafe_Snowglobe_Stall_Glow",
			"CatCafe_Snowglobe_Portal_Portal_Glow",
			"CatCafe_Snowglobe_Portal_Glow",
		},
	},
	spinSeconds = 18, -- when Portal_Spin has no Seconds attribute
	starSeconds = 10,
	spinWithin = 160,
	lightEvery = 4, -- of `every`: the lights are picked again every 2 s
	lightWithin = 90,
	lightGap = 9,
	lightsMost = 10,
	lightsLow = 5,
	lightBrightness = 0.7,
	lightRange = 10,
}

Presets.harvestFx = {
	pumpkinTag = "HarvestPumpkin",
	boardTag = "HarvestBoard",
	readyAttribute = "Ready",
	airWithin = 130,
	air = "harvestLeaves",
	box = Vector3.new(60, 1, 60),
	height = 18,
	every = 0.5,
	calmRate = 0.2,
	within = 120,
	lift = 1.2,
	pick = "catchSparkle",
	pickCount = 10,
	pickColour = Color3.fromRGB(240, 140, 40), -- pumpkin orange
	pickRing = 5,
	regrow = "catchSparkle",
	regrowCount = 5,
	regrowColour = Presets.palette.leaf,
	-- a regrow spot (#4251 spec section 3): a soil mound with a green shoot where a picked pumpkin stood, and a thin
	-- ring `sproutRing` studs across its half that fills toward RegrowAt; at most `sproutMost` spots, plain parts
	regrowAttribute = "RegrowAt",
	sproutMost = 12,
	sproutRing = 1.6,
	sproutRingColour = Color3.fromRGB(255, 240, 210),
	sproutRingTransparency = 0.6,
	sproutFillTransparency = 0.35,
	sproutMound = Vector3.new(1.6, 0.5, 1.6),
	sproutSoil = Color3.fromRGB(110, 78, 52),
	sproutShoot = Vector3.new(0.25, 0.9, 0.25),
	glint = "coinGlint",
	glintCount = 2,
	glintEvery = 5,
	glintWithin = 60,
	glintMost = 3,
	-- the Feast Pie: a slice baked while you are in the area pops `pieCount` gold pieces `pieLift` studs over the
	-- board and a `pieRing` stud ring; the last of `pieFull` slices adds confetti and a gold beam
	pieAttribute = "HarvestPieSlices",
	pieFull = 8,
	pieLift = 6,
	pieBurst = "catchSparkle",
	pieCount = 12,
	pieRing = 8,
	pieConfetti = 0.6,
	pieBeamWidth = 1.2,
	pieBeamHeight = 14,
	pieBeamSeconds = 1.2,
	-- a note pinned on the Thankful Board while you are in the area: `pinCount` leaves `pinLift` studs over the board,
	-- and `pinSparkles` gold sparkles when the pin is yours
	notesAttribute = "HarvestNotes",
	pinLift = 4,
	pinCount = 6,
	pinSparkles = 5,
	-- walking in: `arriveSpots` puffs of `arriveCount` leaves in a circle `arriveRadius` studs round you, `arriveLift`
	-- studs up, `arriveStep` seconds apart (each spot puffs once), with `arriveSparkles` gold
	-- sparkles; not again within `arriveGap` seconds
	arriveSpots = 6,
	arriveCount = 4,
	arriveRadius = 5,
	arriveLift = 3,
	arriveStep = 0.12,
	arriveSparkles = 8,
	arriveGap = 90,
}

-- #4325 (Effects/AdminFlash): an admin event takes the screen and the world. The 3, 2, 1 begins `countFrom` seconds
-- before the start; the name splash holds `splashSeconds`; the strip comes in `stripAfter` seconds in (as the
-- splash leaves) at `stripY` of the screen's height, and in the event's last `lastSeconds` (events of
-- `lastMinEvent` seconds or longer) turns red and stays steady (#4603: no swell). The end card holds `overSeconds`. Sizes are pixels on a `designHeight` tall screen, scaled to the
-- screen's shorter side between `scaleMin` and `scaleMax`. `looks`: the world's tint while each kind runs, eased
-- over `tintSeconds`, and the band's and strip's colours.
Presets.adminFlash = {
	displayOrder = 13, -- the countdown, splash and end card: over the HUD and the area title (12), under the windows (20)
	stripOrder = 11, -- the strip: just over the HUD (10), under every window (20)
	countFrom = 3,
	splashSeconds = 3.2,
	stripAfter = 3.4, -- as the splash leaves (the start card is skipped while the splash shows)
	lastSeconds = 60,
	lastMinEvent = 180,
	overSeconds = 2.5,
	readEvery = 0.25,
	tintSeconds = 2,
	designHeight = 720,
	scaleMin = 0.5,
	scaleMax = 1.4,
	readMin = 0.8, -- #5040: the strip and end card never draw smaller than this (AdminFlashLogic.readScale)
	thinUnder = 14, -- #5040: words under this many px get the thin outline
	thinOutline = 1.5,
	dim = 0.55,
	band = 0.5,
	bandClear = 0.2,
	wide = 0.92,
	titleSize = 66,
	headSize = 46,
	lineSize = 26,
	countSize = 190,
	countPop = 0.35,
	splashPop = 0.4,
	popSeconds = 0.25,
	stripY = 0.17,
	stripLift = 140, -- #4616: on touch the strip's bottom edge sits this far over the screen's bottom (above My Cafe)
	stripWidth = 220,
	stripHeight = 56,
	stripBig = 25,
	stripSmall = 15,
	earnEase = 0.12,
	overWidth = 460,
	overHeight = 130,
	overTitle = 34,
	overLine = 24,
	sparkles = 18,
	sparkle = { size = 16, seconds = 0.7, reach = 140, stagger = 0.15 },
	ringSeconds = 0.6,
	symbol = "$",
	gold = Color3.fromRGB(255, 216, 74),
	outline = Color3.fromRGB(20, 12, 8),
	card = Color3.fromRGB(90, 59, 41),
	earnColour = Color3.fromRGB(125, 255, 138),
	lastTop = Color3.fromRGB(255, 143, 107),
	lastBottom = Color3.fromRGB(226, 72, 58),
	looks = {
		gold = {
			tint = Color3.fromRGB(255, 232, 170),
			saturation = 0.15,
			brightness = 0.04,
			top = Color3.fromRGB(255, 216, 74),
			bottom = Color3.fromRGB(243, 154, 28),
			text = Color3.fromRGB(255, 216, 74),
		},
		rose = {
			tint = Color3.fromRGB(255, 214, 224),
			saturation = 0.12,
			brightness = 0.03,
			top = Color3.fromRGB(255, 150, 175),
			bottom = Color3.fromRGB(217, 97, 127),
			text = Color3.fromRGB(255, 170, 190),
		},
		storm = {
			tint = Color3.fromRGB(196, 214, 255),
			saturation = 0.05,
			brightness = -0.03,
			top = Color3.fromRGB(110, 193, 255),
			bottom = Color3.fromRGB(60, 125, 217),
			text = Color3.fromRGB(150, 210, 255),
		},
		rainbow = {
			tint = Color3.fromRGB(246, 220, 255),
			saturation = 0.3,
			brightness = 0.04,
			top = Color3.fromRGB(255, 130, 190),
			bottom = Color3.fromRGB(110, 150, 255),
			text = Color3.fromRGB(255, 190, 240),
		},
		violet = {
			tint = Color3.fromRGB(222, 208, 255),
			saturation = 0.1,
			brightness = -0.02,
			top = Color3.fromRGB(172, 150, 250),
			bottom = Color3.fromRGB(110, 90, 200),
			text = Color3.fromRGB(200, 185, 255),
		},
		blue = {
			tint = Color3.fromRGB(205, 232, 255),
			saturation = 0.1,
			brightness = 0.02,
			top = Color3.fromRGB(120, 205, 255),
			bottom = Color3.fromRGB(60, 140, 225),
			text = Color3.fromRGB(160, 220, 255),
		},
		mint = {
			tint = Color3.fromRGB(210, 255, 236),
			saturation = 0.12,
			brightness = 0.03,
			top = Color3.fromRGB(150, 230, 205),
			bottom = Color3.fromRGB(70, 175, 150),
			text = Color3.fromRGB(170, 245, 220),
		},
	} :: {
		[string]: {
			tint: Color3,
			saturation: number,
			brightness: number,
			top: Color3,
			bottom: Color3,
			text: Color3,
		},
	},
}

-- The Rally board's marquee (F101, Model-Agent's #759: `CatCafe_Square_RallyBoard` with its 32 bulbs in the
-- `_Bulbs` Model round the face). While a Rally runs, every `gap`th bulb glows and the lit ones run round the frame
-- clockwise at `hz` steps a second, `burstHz` for `burstSeconds` after each point anyone scores; each step of the bar
-- flashes every bulb `flashes` times at `flashHz` (`fullFlashes` in `full` gold for the full bar), under 3 flashes a
-- second. A lit bulb is a Neon cover `grow` times its size in `on`; an unlit one at night is a cover in `off` so the
-- chase reads against the night glow, and by day shows the bulb as built. The nearest budget.rallyBoards within
-- `within` studs, chosen every `pick` seconds; none with Reduce Motion or in Low performance.
Presets.rallyBoard = {
	within = 120,
	gap = 3,
	hz = 5,
	burstHz = 8,
	burstSeconds = 1.2,
	flashes = 2,
	fullFlashes = 3,
	flashHz = 2.5,
	grow = 1.15,
	on = Color3.fromRGB(255, 236, 190),
	full = Color3.fromRGB(242, 193, 78),
	off = Color3.fromRGB(120, 92, 60),
	pick = 1,
}

-- Bunting pennants (F101: the Town Square's Rally bunting, the Rally Crate's cheer bunting): every Model or part whose
-- name ends `_Pennant` inside a Model whose name has `Bunting` in it swings about its top edge, out of its hanging
-- plane, leaning `lean` degrees downwind and fluttering `swing` degrees on two waves (`hz1`, `hz2`) that run across
-- the square with the wind every `wavelength` studs. The nearest budget.pennants within ambientRadius move at the
-- budget's update rate; the rest, and all of them with Reduce Motion, hang as modelled.
Presets.bunting = {
	lean = 7,
	swing = 13,
	hz1 = 0.9,
	hz2 = 1.6,
	wavelength = 18,
	pick = 1, -- seconds between choosing which pennants move
}

-- The Grand Opening ribbon set (#1922, first-hour.md 1d; Effects/GrandOpening, Model-Agent's #1928). At roadmap step
-- `lastStep` your `ribbon` snaps: each half swings `degrees` about its rosette over `swing` seconds (easing out with a
-- small bounce), then drops `drop` studs as it fades over `fade`; `confetti` of the budget's confetti and `sparkles`
-- gold sparkles burst from the knot. The `bunting`'s balloon clusters within `within` studs (at most `most`) bob
-- `wobble` degrees at `hz` a second about their ties, found every `pick` seconds; still in Low performance and with
-- Reduce Motion.
Presets.grandOpening = {
	lastStep = 8,
	ribbon = "CatCafe_Plot_GrandOpeningRibbon",
	bunting = "CatCafe_Plot_GrandOpeningBunting",
	degrees = 60,
	swing = 0.45,
	drop = 1.5,
	fade = 0.7,
	confetti = 0.6,
	sparkles = 10,
	within = 120,
	most = 4,
	wobble = 4,
	hz = 0.45,
	pick = 1,
}
-- The cafe palette, as the bunting's flags
Presets.grandOpeningColors = {
	Presets.palette.blush,
	Presets.palette.mint,
	Presets.palette.goldLight,
	Presets.palette.aurora,
	Presets.palette.pastelSky,
	Presets.palette.shirtRed, -- a scrap of the ribbon
}

-- Trade done (F102, trading.md section 3 step 6): the UI's "You get" pictures (tag `TradeGot`) fly off the confirm
-- screen into the HUD's Cats pill, the cat room, one after another `stagger` seconds apart, in an arc that bends up
-- by `lift` of the way, shrinking to `land` of the pill's height over `seconds`; each lands with `arrive` sparkles and
-- a ring round the pill. With Reduce Motion nothing flies: the pill gets half the sparkles and no ring.
-- The store's thank-you burst (#1823; Effects/StoreBurst, called by UI-Engineer's store with the bought card once the
-- server confirms the buy). Per `kinds`: `sparkles` diamonds of `size` pixels fly out from round the card's edge up to
-- `reach` of its shorter side (between `reachMin` and `reachMax` pixels) over `seconds`, the n-th waiting up to
-- `stagger`; then `rings` rings grow from `ringFrom` to `ringTo` times its longer side over `ringSeconds`, `ringGap`
-- apart. `displayOrder` sits just over the store window (a modal, 20) and under the toasts (30).
Presets.storeBurst = {
	displayOrder = 22,
	size = 12,
	seconds = 0.5,
	stagger = 0.12,
	reach = 0.6,
	reachMin = 24,
	reachMax = 90,
	ringFrom = 0.6,
	ringTo = 1.4,
	ringSeconds = 0.5,
	ringGap = 0.25,
	kinds = {
		pass = { colour = Presets.palette.golden, sparkles = 12, rings = 1 },
		pack = { colour = Color3.fromRGB(255, 244, 176), sparkles = 12, rings = 1 },
		bundle = { colour = Presets.palette.golden, sparkles = 20, rings = 2 },
		-- the Relic Museum card (#2925): an exhibit tile filled, and the tile that finished a room
		exhibit = { colour = Presets.palette.golden, sparkles = 10, rings = 1 },
		room = { colour = Presets.palette.golden, sparkles = 20, rings = 2 },
	},
}

-- The Cat Fusion Observatory (#4104, fusion-observatory.md section 3; Effects/FusionFx). `gold` is the gold coat's
-- colour and the rainbow one drifts round Presets.rainbow.hues once every `huePeriod` seconds.
-- `swirl` (the window, on start): up to `most` tiles leave `stagger` seconds apart and take `seconds` each to spiral
-- `turns` turns in to the centre, shrinking to `land` of their size; as they meet, `sparkles` diamonds of
-- `sparkleSize` pixels fly `reach` of the centre's size out over `sparkleSeconds` and one ring grows from `ringFrom`
-- to `ringTo` of it over `ringSeconds`.
-- `burst` (the window, on collect): per coat `sparkles` diamonds round the picture over `seconds` (the rainbow's
-- hues `hueGap` apart) and `rings` rings of `ringSeconds`, `ringGap` apart: thin outlines, and never more than one a
-- second.
-- `dome` (the world): the model's name ends `suffix`, its slit parts end `glow`; `paws` lights of `pawSize` studs
-- circle at `pawRadius` of its half width and `pawHeight` of its height, a lap every `lap` seconds (`lapReady` once
-- the cat waits), and a ready slit breathes down by `breathDip` every `breathSeconds`. `collect` sparkles, a ring
-- `collectRing` of its width and, for a rainbow, `collectConfetti` of the confetti budget when you collect.
-- Drawn every `rate` seconds; looked for every `lookSeconds`.
export type FusionBurst = {
	sparkles: number,
	seconds: number,
	hueGap: number,
	rings: number,
	ringSeconds: number,
}
Presets.fusion = {
	displayOrder = 22, -- just over the window (a modal, 20), under the toasts (30)
	gold = Presets.palette.golden,
	huePeriod = 6,
	acrossMin = 110, -- pixels: rings are sized as if the picture were at least this wide, so a small one still reads
	acrossMax = 180, -- and never wider than this, so the meeting ring stays round the dome's picture (#4563)
	wide = 1.6, -- a centre wider than this many times its height is a card: the tiles land on its left square
	swirl = {
		most = 5,
		stagger = 0.09,
		seconds = 1.1,
		turns = 0.75,
		land = 0.2,
		sparkles = 10,
		sparkleSize = 12,
		sparkleSeconds = 0.5,
		sparkleStagger = 0.1,
		reach = 0.9,
		ringFrom = 0.4,
		ringTo = 2.2,
		ringSeconds = 0.8,
	},
	burst = {
		size = 15,
		stagger = 0.12,
		reach = 0.6,
		reachMin = 24,
		reachMax = 90,
		ringFrom = 0.6,
		ringTo = 2.2,
		ringGap = 1,
		kinds = {
			gold = { sparkles = 16, seconds = 0.6, hueGap = 0, rings = 2, ringSeconds = 0.9 },
			rainbow = { sparkles = 24, seconds = 0.7, hueGap = 0.12, rings = 3, ringSeconds = 0.95 },
		} :: { [string]: FusionBurst },
	},
	dome = {
		suffix = "_FusionObservatory",
		glow = "_Glow",
		paws = 5,
		pawSize = 0.45,
		anchor = "GlowAnchor", -- Model-Agent's attachment on the dome's axis, at the ring's height (PR #4114)
		anchorRadius = 5.75, -- studs: 1.15 of the tower's 5, clear of the telescope (4.1) and over the sign post
		pawRadius = 1.15, -- without the anchor: of the model's half width
		pawHeight = 0.7, -- and of its height
		lap = 12,
		lapReady = 6,
		breathDip = 0.5,
		breathSeconds = 2.4,
		collect = 12,
		collectRing = 1.2,
		collectConfetti = 0.5,
		rate = 1 / 60, -- every frame near the dome: at 20 a second the paw lights stepped round in jerks (#4563)
		lookSeconds = 3,
	},
	-- #4069: the night stars over the Observatory (emitter `observatoryStars`), a flat box `across` studs wide,
	-- `lift` studs over the dome's top
	stars = {
		emitter = "observatoryStars",
		across = 40,
		lift = 10,
		within = 110,
		check = 1,
	},
}

-- The first wow bowl cat (#4822, Effects/WowBaitGlow): the rarities that get the look, the bowl folders looked in,
-- the outline, the sparkle (`whiten` toward white of the rarity colour), the tag (pixels, studs over the head, popped
-- `pop` times as big over `popSeconds` on a claim), the claim burst, and how often to look (`check`), how long a
-- claim may be from the cat going (`claimWindow`) and how long to wait for the cat after FirstWow (`giveUp`).
Presets.wowBait = {
	rarities = { Rare = true, Epic = true, Legendary = true, Mythical = true } :: { [string]: boolean },
	folders = { "Bait", "Bait2" },
	outline = 0,
	sparkle = "wowSparkle",
	whiten = 0.35,
	tag = {
		width = 96,
		height = 30,
		lift = 1.6,
		maxDistance = 90,
		stroke = 2,
		pop = 1.5,
		popSeconds = 0.35,
	},
	burst = "catchSparkle",
	burstCount = 18,
	check = 0.25,
	claimWindow = 1.5,
	giveUp = 60,
}

-- The arcade cabinet's idle glow (#3062; Effects/ArcadeGlow): its `screen` part drifts through `colours`, one every
-- `step` seconds, and `emitter` sparkles rise `lift` studs over its top, within `within` studs.
-- The Mystic Pool's quiet pointer (#3821, Effects/PoolBeacon): a PointLight `lift` studs over the liquid, `range`
-- studs, `brightness` at its fullest, breathing down by `breathDip` over `breathSeconds` (far under 3 Hz), and
-- `rate` slow `emitter` sparkles a second in the liquid's colour lightened by `whiten`. Full within `full` studs,
-- fading to nothing at `within`. `colour` stands in when the liquid is not found. Updated every `tick` seconds.
Presets.poolBeacon = {
	lift = 1.2,
	range = 12,
	brightness = 1.4,
	breathSeconds = 4,
	breathDip = 0.35,
	emitter = "waitBeacon",
	rate = 2,
	whiten = 0.35,
	full = 30,
	within = 60,
	colour = Color3.fromRGB(150, 120, 230),
	tick = 0.2,
}

Presets.arcadeGlow = {
	screen = "Screen",
	step = 2.5,
	within = 120,
	lift = 0.3,
	emitter = "waitBeacon",
	colours = {
		Presets.palette.pastelSky,
		Presets.palette.blush,
		Presets.palette.mint,
		Presets.palette.goldLight,
	},
}

-- The Cat Arcade's attract screen (Derek 2026-11-18; Effects/ArcadeScreen): a SurfaceGui on the cabinet's `part`
-- at `pixelsPerStud`, a mouse up every `beat` seconds, the paw bopping every `bopEvery`-th, a golden mouse every
-- `goldEvery`-th. `sheet` and `backdrop` are Mouse Dash's uploaded pictures (UI/Components/MouseDashLogic).
Presets.arcadeScreen = {
	part = "Screen",
	pixelsPerStud = 100,
	brightness = 1.4,
	maxDistance = 160,
	within = 90,
	beat = 0.9,
	up = 0.18,
	down = 0.12,
	wait = 0.15,
	bop = 0.12,
	dust = 0.35,
	bopEvery = 3,
	goldEvery = 7,
	holes = 3,
	holeSize = 0.28,
	holeY = 0.62,
	sheet = "rbxassetid://106053188764774",
	backdrop = "rbxassetid://116753136904678",
	cell = 256,
	cells = {
		Mouse = { 0, 0 },
		MouseHit = { 256, 0 },
		GoldMouse = { 512, 0 },
		GoldMouseHit = { 768, 0 },
		Hole = { 512, 256 },
		Dust = { 0, 512 },
		Paw = { 256, 512 },
		PawBop = { 512, 512 },
	} :: { [string]: { number } },
	night = Color3.fromRGB(31, 42, 68), -- the screen part's own night blue
	floorTint = Color3.fromRGB(200, 190, 210),
	text = "PRESS PLAY",
	gold = Presets.palette.golden,
	ink = Color3.fromRGB(74, 46, 30),
}

-- A Golden find (#3222; Effects/GoldenFind): the toast line starting `prefix` (LawnService.giveDrop's) plays a gold
-- `beamWidth` by `beamHeight` stud beam off the player for `beamSeconds`, `sparkles` catchSparkle and `confetti` pieces
-- `lift` studs over their middle, and `rings` gold rings `ringGap` seconds apart, `ring` studs wider each, at their
-- feet (`feet` studs under it). At most one every `gap` seconds.
Presets.goldenFind = {
	prefix = "Golden find! ",
	gap = 3,
	lift = 1,
	feet = 2.8,
	sparkles = 18,
	confetti = 30,
	colours = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.offwhite },
	beamWidth = 2.5,
	beamHeight = 18,
	beamSeconds = 1.6,
	rings = 2,
	ring = 7,
	ringGap = 0.3,
	ringSeconds = 0.9,
}

-- #3360 (rich customers' money bags, Effects/MoneyBag): the gold ring and sparkles when a bag drops on table 1 and
-- the pop when it is collected. Studs and seconds; one beat per bag, so nothing repeats faster than a bag can drop.
Presets.moneyBag = {
	within = 120, -- studs from this player; further cafes are skipped
	lift = 0.6, -- the sparkles start this far over the table top
	dropSparkles = 8,
	dropRing = 3,
	collectSparkles = 16,
	collectRing = 5,
	ringSeconds = 0.7,
	confetti = 14, -- in your own cafe only
	colours = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.offwhite },
}

-- #3062 (Cat Arcade): the pops round a 10-point milestone and the golden fish a run costs, and the sparkles, rings
-- and words Mouse Dash draws with them (Effects/ArcadeFx). Circle Streak's ring grades went with it (#4722). Pixels
-- and seconds.
Presets.arcade = {
	displayOrder = 23, -- over the arcade window (a modal, 20), under toasts (30)
	sparkSize = 10,
	sparkSeconds = 0.4,
	sparkStagger = 0.08,
	reach = 46,
	ringFrom = 0.5, -- of the target's longer side
	ringTo = 1.5,
	ringSeconds = 0.35,
	wordRise = 34,
	wordSeconds = 0.6,
	milestone = {
		colour = Presets.palette.golden,
		sparkles = 12, -- the phone's burst cap
		rings = 2,
		ringGap = 0.15,
		wordSize = 34,
	},
	fish = { glyph = "🐟", colour = Presets.palette.golden, sparkles = 6, wordSize = 30 },
	-- #3338: the shine that sweeps across the Play button while a game can start
	shine = { every = 2.6, seconds = 0.7, width = 0.18, transparency = 0.55 },
}

-- Mouse Dash's pops (#3296, MouseDashFx), drawn with the arcade's sparkles, rings and words (Presets.arcade)
Presets.mouseDash = {
	bigEvery = 5, -- every 5th catch of a streak gets the bigger golden pop
	pop = {
		colour = Presets.palette.offwhite,
		golden = { colour = Presets.palette.golden, sparkles = 4 },
		kitten = { colour = Presets.palette.blush },
	},
	-- the window floats its own "+1" and "+3" over the hole, so the catch pops are sparkles and a ring only
	catch = { colour = Presets.palette.mint, sparkles = 4, rings = 1 },
	catchBig = {
		colour = Presets.palette.golden,
		sparkles = 8,
		rings = 1,
	},
	catchGolden = {
		colour = Presets.palette.golden,
		sparkles = 12,
		rings = 1,
	},
	-- the dust as a mouse ducks back in: round blobs off the hole's rim; `drop` is how far under the hole's middle
	-- they start, in hole heights
	puff = {
		count = 6,
		colour = Presets.palette.lampWarm,
		size = 16,
		reach = 34,
		seconds = 0.45,
		transparency = 0.25,
		drop = 0.15,
	},
	wrong = {
		kitten = { word = "mrow?", colour = Presets.palette.blush, wordSize = 24 },
		empty = { colour = Presets.palette.sparkle, stars = 3, puffs = 3 },
	},
	heart = {
		colour = Presets.palette.nosePink,
		sparkles = 6,
		lost = Presets.palette.furGrey,
		puffs = 3,
	},
	-- the window's banner says "Faster!", so this is the ring and sparkles round the score only
	faster = {
		colour = Presets.palette.eyeBlue,
		sparkles = 6,
		rings = 1,
	},
	-- MouseDashFx.prize: the next prize banner as a run passes a prize; the banner pops its own scale
	prize = { colour = Presets.palette.golden, sparkles = 6, rings = 1 },
	best = {
		colour = Presets.palette.golden,
		confetti = { Presets.palette.golden, Presets.palette.mint, Presets.palette.nosePink },
		sparkles = 12, -- the phone's burst cap, shared out over the confetti colours
		rings = 2,
		ringGap = 0.15,
		wordSize = 34, -- for the words the window hands over ("You win!")
	},
	-- MouseDashFx.bounce: how far each kind swells (over 1) or dips (under 1) before it settles
	bounce = { seconds = 0.22, peaks = { pop = 1.15, squash = 0.8, pulse = 1.25 } },
}

Presets.tradeFly = {
	displayOrder = 21, -- over the trade window (a modal, 20), under the bait card (35) and toasts (30)
	seconds = 0.75,
	stagger = 0.09,
	lift = 0.22,
	land = 0.8,
	popIn = 0.12,
	arrive = 6,
	ring = 1.6, -- the ring grows to this many times the pill's height
	ringSeconds = 0.45,
	sparkle = Color3.fromRGB(255, 244, 176),
	ringColor = Color3.fromRGB(255, 249, 242),
}

-- Moving parts of rare decor (F89 2c, luck-and-rare-moments.md: a Legendary piece has "a moving part and a light"):
-- Model-Agent marks each with a child Model named ending `_Swing` (swings side to side about its pivot's Z axis, the
-- pivot at the hook: lanterns, a porch swing, wind chimes), `_Spin` (turns about its pivot's Y axis: a record, a little
-- fan) or `_Bob` (rides up and down along its pivot's Y: a duck on the water), lights inside riding along. Its own
-- `Angle` (degrees), `Seconds` (one cycle) and `Rise` (studs) attributes override the defaults here, held inside the
-- ranges. The nearest budget.decorMotion within ambientRadius move at the budget's update rate, each started at a
-- random point of its cycle; Reduce Motion and Low performance hold them all still as modelled.
Presets.decorMotion = {
	angle = { default = 10, least = 0, most = 45 },
	seconds = { default = 2, least = 0.3, most = 120 }, -- up to 120 for a slow lookout turn (#4069 telescope, Seconds 90)
	rise = { default = 0.08, least = 0, most = 1 },
	pick = 1, -- seconds between choosing which parts move
}

-- #4070 the Water Park's rides (Effects/Rides): each turning piece of the area set is a Model named ending with a key
-- of `kinds`, and turns once every `seconds` about the middle of its own box: `axis` "up" straight up (the carousel,
-- the teacups), "thin" along the box's thin side (the Ferris wheel, about its hub). All slow: the fastest rim, the
-- carousel's, moves about 3.5 studs a second. The nearest budget.rides within `radius` studs turn (#5065: one on a
-- phone), chosen every `pick` seconds, stepped budget.rideHz times a second but never above `hz`;
-- a step never covers more than `longest` seconds. Reduce Motion and Low performance hold them all still.
export type Ride = { axis: "up" | "thin", seconds: number }
Presets.rides = {
	kinds = {
		CarouselTurn = { axis = "up", seconds = 24 },
		TeacupsTurn = { axis = "up", seconds = 16 },
		FerrisTurn = { axis = "thin", seconds = 60 },
	} :: { [string]: Ride },
	radius = 260, -- how many turn and how often: the budget's `rides` and `rideHz` (#5065)
	hz = 30, -- never faster than this
	longest = 0.25,
	pick = 1,
}

-- The net swing (F93, catch-rework.md sections 1 and 5): a whoosh trail off the net's hoop over the downswing, from
-- `from` to `to` seconds into the smack (it lands at netSmack.land), each piece fading over `lifetime`. The trail's
-- edges are the hoop and a point `inner` of the way out from the grip, so it sweeps a fan like a swung racket. Only
-- characters within `within` studs, the nearest budget.netTrails at once; none with Reduce Motion.
Presets.netTrail = {
	from = 0.06,
	to = 0.17,
	lifetime = 0.14,
	inner = 0.55,
	transparency = 0.3, -- at the hoop's end of each piece; it fades to clear
	lightEmission = 0.4,
	within = 60,
	colors = { Presets.palette.offwhite, Presets.palette.pastelSky },
}

-- The Christmas cats' beats (snowglobe-village-spec section 4, Effects/ChristmasCats): which cats, the glow parts'
-- name endings, and whether it wears a bell. Jingle's bell swings `degrees` either way, `swings` times over `seconds`,
-- every `every` seconds (the first `firstMin` or more after it appears). A glow part shows `dayDim` of the way to
-- clear by day; at night it twinkles between 0 and `nightDim` once every `twinkleSeconds`. Reduce Motion: no bell,
-- steady glow.
Presets.christmasCats = {
	cats = {
		jingle = { bell = true, glows = {} },
		star_topper = { bell = false, glows = { "_Star_Glow", "_Bulbs_Glow" } },
		sugar_plum = { bell = false, glows = { "_Gem_Glow", "_Wings_Glow" } },
	} :: { [string]: { bell: boolean, glows: { string } } },
	jingle = { seconds = 0.9, degrees = 22, swings = 3, every = { 7, 12 }, firstMin = 2 },
	dayDim = 0.45,
	nightDim = 0.25,
	twinkleSeconds = 1.6,
}

-- The catch's result word (F93 section 3): as UI-Engineer's word slams in, sparkles burst off it in its colour and
-- rings grow round it, the biggest for PURRFECT!; "So close!" gets none. The word is the first of `targets` found in
-- CatCafeCatchCircles that shows within `wait` seconds of CatchResult. Sparkles are `size` pixels and fly up to
-- `reach` pixels over `seconds`; rings grow from `ringFrom` to `ringTo` of the word's width over `ringSeconds`, the
-- second `ringGap` seconds later. Never more sparkles than the budget's maxBurst; Reduce Motion halves them and drops
-- the rings.
Presets.catchWord = {
	displayOrder = 26, -- just over the catch screen (CatCafeCatchCircles, 25), under toasts (30)
	targets = { "FinishBanner", "ResultWord", "Outcome" }, -- FinishBanner: v3 (#1884)
	wait = 0.5,
	size = 12,
	seconds = 0.6,
	reach = 80,
	stagger = 0.12,
	ringFrom = 0.5,
	ringTo = 1.4,
	ringSeconds = 0.5,
	ringGap = 0.15,
	words = {
		purrfect = { sparkles = 18, rings = 2, colour = Presets.palette.golden },
		excellent = { sparkles = 11, rings = 1, colour = Presets.palette.golden },
		great = { sparkles = 7, rings = 1, colour = Presets.palette.mint },
		nice = { sparkles = 5, rings = 1, colour = Presets.palette.cream }, -- v3 (#1884 7d)
	} :: { [string]: { sparkles: number, rings: number, colour: Color3 } },
	-- #5300 Perfect catch (switch perfectCatch): when PURRFECT! turns to `text`, a sky blue burst (the "+50%" colour,
	-- shared/PerfectCatch.COLOR #8FD3FF) with one more ring than PURRFECT!'s. Watched for `watch` seconds.
	perfectPlus = {
		flag = "perfectCatch",
		text = "+50%",
		watch = 2.5,
		sparkles = 16,
		rings = 3,
		colour = Color3.fromRGB(143, 211, 255),
	},
}

-- Catch v3 (#1884, catch-rework.md 7b to 7d; Effects/Catch). Each ring the server judges (CatchJudged) pops at the
-- cat's head in its grade's colour: `sparkles` sparkles and a ring `ring` studs across over `ringSeconds`, a Miss a
-- grey puff instead of sparkles. A Perfect holds the camera and your character's animations for `hitStop` seconds
-- first (client only; the rings never pause, so timing stays fair). Reduce Motion: sparkles only, no ring and no
-- hit-stop. Low performance: the budget's burst scale.
Presets.catchJudge = {
	hitStop = 0.06,
	ringSeconds = 0.3,
	grades = {
		perfect = { colour = Presets.palette.golden, sparkles = 6, ring = 1.8, puff = 0 },
		good = { colour = Presets.palette.mint, sparkles = 3, ring = 1.4, puff = 0 },
		miss = { colour = Presets.palette.furGrey, sparkles = 0, ring = 1.2, puff = 2 },
		left = { colour = Presets.palette.mint, sparkles = 2, ring = 1.2, puff = 0 }, -- a paw ring rightly left alone
	} :: { [string]: { colour: Color3, sparkles: number, ring: number, puff: number } },
}

-- The v3 finish (7d): the pop waits `wrap` seconds for the net to wrap the cat and wobble twice (Animation-Engineer),
-- then the catch pops (a Purrfect as `Catch` always has, gold) with confetti, `confetti` of the budget's in the
-- finish's `colours`. The banner's screen burst is `catchWord.words`.
Presets.catchFinish = {
	wrap = 0.6,
	confetti = { purrfect = 0.6, great = 0.35, nice = 0.25 } :: { [string]: number },
	colours = {
		great = { Presets.palette.mint, Presets.palette.sparkle, Presets.palette.offwhite },
		nice = { Presets.palette.cream, Presets.palette.offwhite, Presets.palette.sparkle },
	} :: { [string]: { Color3 } },
}

-- Rescues (F93 section 4): the trap (the `<rescueSpotId>_Trap` model by its anchor) shakes on every hit of your
-- rescue, tipping side to side about its base and hopping, a little more each hit (Logic.trapShake); Reduce Motion
-- keeps it still. When the cat comes free it pops in its rarity colour (Catch.pop) `above` studs over its spot.
Presets.trapShake = { least = 1.5, most = 5, seconds = 0.35, hz = 12, hop = 0.08 }
Presets.rescueFree = { above = 1.2, depth = 20 } -- `depth`: how far under the spot the ring looks for the ground

-- Team Rescue (F92, playing-together.md section 3: "Both players see a small "Team Rescue!" pop when the cat comes
-- free"): on the rescuer's and the helper's screens, `text` pops up `above` studs over the trap's spot, `width` by
-- `height` studs, growing in over `popIn` s with a small overshoot, then rises `rise` studs and fades over the last
-- half of `seconds`, seen within `maxDistance` studs. `sparkles` catch sparkles in each of `colours` burst there, a
-- ring of each grows `ring` studs across over `ringSeconds`, `ringGap` s apart, and a share `confetti` of the budget's
-- confetti falls in them. Reduce Motion keeps the word where it popped, skips the rings and halves the confetti.
Presets.teamRescue = {
	text = "Team Rescue!",
	above = 2.4,
	width = 5,
	height = 1.2,
	popIn = 0.18,
	seconds = 1.8,
	rise = 1.2,
	maxDistance = 80,
	textColour = palette.golden,
	stroke = Color3.fromRGB(94, 70, 52), -- palette 2 dark wood, the UI's outline
	colours = { palette.mint, palette.golden },
	sparkles = 10,
	ring = 4,
	ringSeconds = 0.6,
	ringGap = 0.15,
	confetti = 0.4,
}

-- Cats make the orders (F90, cats-make-orders.md section 2 step 2 and section 4; Model-Agent's oven in #775). While a
-- Barista makes an order a puff plays at its station every `every` seconds: `count` steam puffs off one of the
-- espresso machine's `_Steam` parts (else `rise` over its top) for a drink, `count` flour puffs `above` studs over the
-- oven's top and `forward` studs toward its front for a bake, `count` cool twinkles `above` the counter spot for the
-- milk and the sundae. A bake also lights the oven's door window: a warm Neon cover `pad` studs proud of the window
-- part by the `DoorGlow` attachment (`window` studs across when there is none), with a light inside, coming up over
-- `rise` s, flickering by `flicker` at `hz` and fading over `fade` s once the oven has nothing left to bake; brighter
-- by `night` after dark. When the item appears, `sparkles` ding sparkles burst `above` studs over it and a ring
-- `ring` studs across opens round its plate over `ringSeconds`, both gold with `goldSparkles` on the rich customer's
-- gold-rimmed plate; a bake's oven door (its `_Door` child Model, pivoted on the bottom hinge) swings out by `door`
-- (keys of { seconds, degrees }, negative opens it toward the front) with `waft` steam puffs out of it. Orders within
-- `within` studs play: your own cafe's always, other cafes' while fewer than the budget's `cafeOrders` play. A make
-- with no OrderReady stops on its own `grace` s after its seconds. Reduce Motion keeps the door shut and the glow
-- steady; Low performance leaves out the light. Serving and tips (section 2 steps 3 and 5): `served` as the dish goes
-- on the table (by the same rule, a spot within `plotReach` of your own plot counting as your cafe), `sweep` as a tip
-- pile goes into the coin bag and `bank` as the bag lands in the till, both your own cafe within `within`.
Presets.orders = {
	within = 150,
	grace = 1.5,
	steam = { every = 0.35, count = 3, rise = 0.3 },
	flour = { every = 0.55, count = 4, above = 0.35, forward = 0.4 },
	counter = { every = 0.5, count = 3, above = 0.6 },
	glow = {
		rise = 0.6,
		fade = 0.4,
		colour = Color3.fromRGB(255, 170, 84),
		transparency = 0.3, -- the cover's, fully lit
		pad = 0.035,
		thick = 0.02,
		margin = 0.02, -- studs past the window part's edges
		window = Vector2.new(1.5, 0.74),
		reach = 0.5, -- studs from DoorGlow the window part can be
		light = Color3.fromRGB(255, 176, 102),
		range = 7,
		brightness = 1.2,
		night = 1.5,
		flicker = 0.12,
		hz = 3.1,
	},
	-- 30 at most: the plot's Barista stands 2.65 studs in front of the oven (#781), and the 1.75 stud door would reach
	-- it past that
	door = { { 0, 0 }, { 0.12, -30 }, { 0.55, -30 }, { 0.85, 0 } },
	waft = 6,
	-- the dish set on the table: `sparkles` ding sparkles `above` it and a ring `ring` studs across round the plate
	served = {
		sparkles = 6,
		above = 0.3,
		ring = 1.3,
		ringSeconds = 0.4,
		colour = Presets.palette.blush,
	},
	-- a tip sweep: `coins` coin glints hop up off the table and `dust` puffs; the bag landing in the till: `coins`
	-- glints and `sparkles` gold ding sparkles `above` it with a gold ring `ring` studs across
	sweep = { coins = 6, dust = 2, above = 0.3 },
	bank = {
		coins = 8,
		sparkles = 10,
		above = 0.4,
		ring = 1.8,
		ringSeconds = 0.45,
		colour = Presets.palette.golden,
	},
	plotReach = 40, -- studs from a plot's pivot that count as in that cafe
	ding = {
		sparkles = 10,
		goldSparkles = 14,
		above = 0.25,
		ring = 1.6,
		ringSeconds = 0.45,
		colour = Presets.palette.sparkle,
		gold = Presets.palette.golden,
	},
}

-- Clouds in the sky (Sky.luau; Derek 2026-10-28 17:05: "add clouds in sky"): Roblox's cloud layer at `cover` (0 to
-- 1, how much of the sky it hides) and `density` (how thick each cloud looks), tinted `color`, drifting on `wind`
-- studs a second when the place has no wind of its own. Off in Low performance.
-- #4291 (Derek 2026-11-14: "the sky still needs to be changed off the boring cloudy view"): the sky box now has its
-- own painted clouds (assets/cat-cafe/vfx/sky_painted.py), so this layer is a few drifting clouds (0.5 before, which
-- hid half the blue behind flat white).
Presets.sky = {
	cover = 0.22,
	density = 0.5,
	color = Color3.fromRGB(255, 252, 247),
	wind = Vector3.new(3, 0, 1.5),
}

-- A Lucky Day (F88, luck-and-rare-moments.md 1c: "The sky takes a warm gold tint for the day"): while the Clock's
-- LuckyDay is on by day, the world takes a warm gold `tint` with a touch more `saturation` and `brightness` (a
-- ColorCorrectionEffect of this client's own, over the place's, so the sky's day and night curve is untouched) and
-- the clouds turn `clouds` gold, easing in and out over `seconds`. Joining during one shows it at once.
Presets.luckyDay = {
	tint = Color3.fromRGB(255, 240, 206),
	saturation = 0.06,
	brightness = 0.02,
	clouds = Color3.fromRGB(255, 232, 178),
	seconds = 4,
}

-- The Lucky Cat statue by each cafe's door (F88, 1a; Model-Agent's CatCafe_Plot_LuckyCat_0 to _5). When a plot's
-- statue goes up a level while this client has it, sparkles in the new look's colour and some sparkle yellow burst
-- `centre` studs over its base (the cushion is at 1.2, the head top about 3.2), a ring grows on the plinth and, from
-- `confettiFrom` (gold and jade), confetti. Within `within` studs. The jade statue (`shimmerFrom`) shimmers: a faint
-- Highlight over it drifts through the rainbow coat hues once every `period` seconds (`fill` transparent) and a
-- `twinkle` of sparkles rises off it every `twinkleEvery` seconds; the nearest budget.luckyShimmers within
-- `shimmerWithin` studs, chosen every `pick` seconds. Reduce Motion holds the shimmer at one hue with no twinkles.
Presets.luckyCat = {
	centre = 2.2,
	sparkles = 14,
	ring = 5,
	ringSeconds = 0.6,
	confettiFrom = 4,
	within = 120,
	colours = {
		Color3.fromRGB(196, 122, 88), -- 1 clay (terracotta)
		Color3.fromRGB(128, 86, 46), -- 2 bronze
		Color3.fromRGB(205, 210, 218), -- 3 silver (fur_silver)
		Color3.fromRGB(242, 193, 78), -- 4 gold (fur_golden)
		Color3.fromRGB(46, 158, 107), -- 5 jade (fur_emerald)
	},
	shimmerFrom = 5,
	shimmerWithin = 90,
	period = 6,
	fill = 0.82,
	twinkle = 2,
	twinkleEvery = 1.4,
	pick = 1,
}

-- The camp extras' water (F100, camp-extras.md section 3; Model-Agent's #750). `drip`: under the Sewer standpipe's
-- `Drip` attachment a drop swells for `swell` seconds to `size` studs across, falls under `gravity` (gentle, so the
-- fall reads) onto what is below it within `reach` studs (the Lost and Found's lid, or `fallback` studs down) and
-- lands with `splash` dripSplash drops and a ripple from `rippleFrom` to `ripple` studs across; the next forms
-- `gap` seconds later. `fish`: the Woods pond's `_Fish` jumps every `every` seconds (the first `first` seconds after
-- it comes near): from its rest under the water it arcs `peak` studs over the `FishJump` attachment's height and
-- `length` studs on along its head (`headX`: Model-Agent's fish faces -X, its tail fin at +X) in `seconds`, with
-- `exitDrops` and an `exitRipple` as it leaves the water (the fishJump beat, Sound-Agent's campSplash) and
-- `entryDrops` and an `entryRipple` as it dives back in, then swims home under the water in `back` seconds, turning
-- over the first and last `turn` of it. Only the nearest budget.campDrips and budget.campFish within `within` studs,
-- chosen every `pick` seconds. Reduce Motion holds the fish at rest; the drips go on, like steam.
Presets.campWater = {
	drip = {
		gap = { 0.6, 1.4 },
		swell = 0.45,
		size = 0.14,
		gravity = 22,
		reach = 3,
		fallback = 1,
		colour = Color3.fromRGB(196, 226, 240),
		transparency = 0.25,
		splash = 3,
		rippleFrom = 0.08,
		ripple = 0.45,
	},
	fish = {
		every = { 6, 12 },
		first = { 2, 6 },
		seconds = 0.8,
		length = 1,
		peak = 1,
		headX = -1,
		back = 2.2,
		turn = 0.25,
		exitDrops = 5,
		exitRipple = 0.8,
		entryDrops = 8,
		entryRipple = 0.9,
	},
	within = 70,
	pick = 1,
}

-- One camp extra's collect burst (Presets.campCollect): `count` particles of `emitter`, tinted when `tint` is given.
export type CampBurst = { emitter: string, count: number, tint: Color3? }
export type CampCollect = {
	delay: number, -- seconds after the press, so it meets Animation-Engineer's turn
	above: number, -- studs over the spot the bursts pop at
	bursts: { CampBurst },
	colour: Color3, -- the ring's
	ring: number, -- studs across
}

-- The camp extras' collect bursts (F100, camp-extras.md section 2: "Collecting is one press. The prize flies to the
-- HUD with F94's prize toast"; Effects/CampCollect). When you collect one, a small burst in its own colours pops
-- `above` studs over it and a ring `ring` studs across opens on its ground over `ringSeconds`, `delay` seconds after
-- the press so it meets Animation-Engineer's turn (Presets.campExtras: the pond's rod tugs at the bite at 0.12 s and
-- the Lost and Found's lid is up at 0.18 s). The spot is the top of the extra's model, the pond's `FishJump` water
-- (its ring on the water) and the Lost and Found's `_Lid`. Picnic Basket: warm sparkles and a few gold coin glints
-- for the Money Potion, a mint ring on the blanket. Fish Pond: drops off the water and gold glints rising, a fish-blue
-- ripple. Lost and Found: a grey puff of dust out of the battered box and bright sparkles, a sparkle ring. Yard
-- Sale (a crate bought for golden fish): sparkles over the boxes in gold and a blush ring. Your own collects only
-- (the server answers only you), within `within` studs; the model is looked for within `reach` studs of the prompt.
-- The golden fish landing in your wallet sparkle round you as ever (Fish.luau).
Presets.campCollect = {
	within = 40,
	reach = 12,
	ringSeconds = 0.5,
	extras = {
		picnic = {
			delay = 0,
			above = 0.3,
			bursts = {
				{ emitter = "dingSparkle", count = 8 },
				{ emitter = "coinGlint", count = 5 },
			},
			colour = Presets.palette.mint,
			ring = 3,
		},
		pond = {
			delay = 0.12,
			above = 0.1,
			bursts = { { emitter = "splashDrops", count = 8 }, { emitter = "fishRise", count = 6 } },
			colour = Presets.palette.fishBlue,
			ring = 2.4,
		},
		lostFound = {
			delay = 0.18,
			above = 0.2,
			bursts = {
				{ emitter = "dust", count = 3, tint = Presets.palette.furGrey },
				{ emitter = "dingSparkle", count = 10 },
			},
			colour = Presets.palette.sparkle,
			ring = 2.6,
		},
		yardSale = {
			delay = 0,
			above = 0.3,
			bursts = { { emitter = "dingSparkle", count = 8, tint = Presets.palette.golden } },
			colour = Presets.palette.blush,
			ring = 3,
		},
	} :: { [string]: CampCollect },
	-- #3615: a golden crate won on the Yard Sale's lucky pick adds this on top of the yardSale burst: more gold
	-- sparkles, gold confetti, a wider gold ring and a short light column (no column with Reduce Motion). `within`
	-- seconds is how close the pick's landing must come before the stall's collect.
	yardSaleGold = {
		within = 1,
		sparkles = 16,
		confetti = 14,
		ring = 5.5,
		column = { width = 1.4, height = 9, seconds = 1.2 },
	},
}

-- A big pull (F89, luck-and-rare-moments.md 2a and 2b; Derek 2026-10-30: "when securing something good leg/mythic
-- decor or cats possibly consider a bigger VFX"): when this player secures a Legendary, a Mythical or a gold Epic cat,
-- or opens a Legendary or Mythical crate piece, confetti in the rarity colour (gold mixed in for a gold cat) bursts
-- in from both edges of the screen over UI-Engineer's big pull card, with a small camera shake, and a Mythical adds a
-- second wave of sparkles round the middle at `sparkles.at`. Everyone within `within` studs sees the catch pop of
-- that rarity where the cat was secured, and a Mythical's ground shockwave `shockwave.diameter` studs across. The
-- budget's pullConfetti is the count (phones half, Low performance a third); Reduce Motion halves it and drops the
-- shake and the shockwave. On the screen the pieces fly in pixels from the screen's height.
Presets.bigPull = {
	seconds = 2.4, -- the card's longest stay
	displayOrder = 47, -- over the big pull card (44), popups (40) and the cannon name card (46), under the intro (50)
	fade = 0.5, -- seconds the pieces fade over at the end
	height = { 0.45, 0.85 }, -- share of the screen's height the pieces leave the edges at
	speed = { 1.1, 1.7 }, -- screen heights a second
	angle = { 30, 68 }, -- degrees above level, in toward the middle
	gravity = 1.5, -- screen heights a second, every second
	drag = 1.1, -- share of their speed lost a second
	size = { 0.014, 0.026 }, -- of the screen's height
	spin = 540, -- degrees a second either way at most
	flutter = { 2, 4.5 }, -- flips a second
	round = 0.3, -- share of the pieces that are dots, not slips
	stagger = 0.25, -- seconds the pieces leave over
	sparkles = { at = 0.6, count = 14, seconds = 0.8, radius = { 0.16, 0.42 }, size = 0.035 },
	gold = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.goldDark },
	shake = 0.3, -- seconds
	shakeStuds = 0.3,
	within = 120, -- studs: onlookers see the world pop
	shockwave = { diameter = 20, seconds = 0.7, puffs = 12, puffAt = 0.3 },
	-- A Legendary or Mythical crate piece: the crate glows in the rarity colour from the moment it appears and shakes
	-- for `crateShake` seconds before the lid blows open in `blowSeconds`.
	crateShake = 0.6,
	blowSeconds = 0.12,
	rattle = 6, -- degrees at the end of the shake
	rattleHop = 0.12, -- studs
	rattleHz = 11,
	glowFill = 0.6, -- the Highlight's fill transparency
	glowLight = { range = 8, brightness = 2 },
	crateSparkles = 5, -- catchSparkle particles rising off the crate every `sparkleEvery` seconds while it shakes
	sparkleEvery = 0.15,
}

-- Golden fish landing in your wallet (golden-fish.md section 4: "the catch sparkle in gold"): catch sparkles in gold
-- `chest` studs above the root part, `rise` of as many gold glints floating up (fishRise) and a gold ring at your
-- feet, both by the biggest step the gain reaches.
Presets.fishPickup = {
	chest = 0.5,
	rise = 0.5,
	ringSeconds = 0.45,
	steps = {
		{ from = 1, sparkles = 8, ring = 3 },
		{ from = 10, sparkles = 14, ring = 4.5 },
		{ from = 40, sparkles = 22, ring = 6 },
	},
}

-- A cat levelling up (F75, data-model 4b v0.12): a small mint sparkle over one of your own cafe cats, `above` studs
-- over its head, and a few glints floating up. Small, since cats level often early on.
Presets.levelUp = {
	sparkles = 6, -- catchSparkle particles
	glints = 3, -- fishRise particles, tinted
	above = 0.4,
	colour = Presets.palette.mint,
}

-- Decor you just put out (Derek 2026-10-28): a green outline and faint fill (a Highlight, drawn over whatever stands
-- in front) come in over `fadeIn` seconds, hold, then fade over `fade`. `fill` is the fill's transparency at its
-- strongest. The piece's model is waited for up to `wait` seconds after the sync; past `maxDistance` studs nothing
-- shows, and at most `most` flash at once (Roblox draws 31 Highlights at most).
Presets.equipFlash = {
	colour = Presets.palette.leaf,
	fill = 0.7,
	fadeIn = 0.15,
	hold = 0.6,
	fade = 0.75,
	wait = 3,
	maxDistance = 150,
	most = 4,
}

-- Mythical cafe styles and decor (F53, golden-fish.md section 4: each "gets one steady emitter or a texture scroll.
-- It runs only near the player, counts against the steady-emitter budget and shows a still look in Low performance
-- mode"), by decor id. `on` is a plot style attribute (the style shows on the plot's parts with that tag) or
-- "model", a placed piece carrying DecorId. `emitter` and `colors` are its glints or petals.
-- `spare` (#2734): a Legendary piece, which only moves in a slot no Mythical piece within reach wants.
export type DecorSpec = {
	look: string,
	on: string,
	emitter: string?,
	colors: { Color3 }?,
	spare: boolean?,
}
-- #2734 (Derek2 2026-11-09): the Legendary crate furniture and decorations twinkle with a few gold glints over the
-- piece, so they read above an Epic; they take a moving slot only when the Mythicals leave one free.
local LEGENDARY_GLINT = { Color3.fromRGB(255, 236, 170), palette.goldLight, palette.offwhite }
local function legendary(): DecorSpec
	return {
		look = "sparkle",
		on = "model",
		emitter = "decorGlint",
		colors = LEGENDARY_GLINT,
		spare = true,
	}
end
Presets.decor = {
	alley_retro_jukebox = legendary(),
	park_duck_fountain = legendary(),
	neighbourhood_ice_cream_counter = legendary(),
	woods_hollow_log_booth = legendary(),
	sewer_bathtub_sofa = legendary(),
	desert_caravan_bench = legendary(),
	ruins_stone_throne = legendary(),
	snow_stone_fireplace = legendary(), -- #3997
	funfair_mini_carousel = legendary(), -- #4070
	castle_round_table = legendary(), -- #4184
	classic_cat_tree_tower = legendary(),
	rally_victory_podium = legendary(),
	alley_midnight_sky = { look = "stars", on = "Wallpaper" },
	park_blossom_tree = { look = "petals", on = "model", emitter = "decorPetals" },
	-- #2734 (Derek2 2026-11-09: "certain high rarity decor like the rainbow shimmer paint are underwhelming"): the tint
	-- alone read as a faint lilac front, so it also sparkles in the rainbow's colours and a white glint sweeps it.
	neighbourhood_rainbow_shimmer = {
		look = "rainbow",
		on = "Paint",
		emitter = "decorGlint",
		colors = {
			Color3.fromRGB(255, 150, 160),
			Color3.fromRGB(255, 225, 120),
			Color3.fromRGB(150, 235, 160),
			Color3.fromRGB(140, 200, 255),
			Color3.fromRGB(210, 160, 255),
		},
	},
	woods_aurora_sky = { look = "aurora", on = "Wallpaper" },
	sewer_glimmer_canal = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { palette.milk, palette.pastelSky },
	},
	-- The Desert and Ruins crates' Mythical floors (Tier 6 and 7, #2651): Glimmer Canal's light under the glass with
	-- glints in their own colours, heat shimmer on Mirage Glass and gold lines over Jade Inlay.
	desert_mirage_glass = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { Color3.fromRGB(255, 244, 214), Color3.fromRGB(232, 205, 150) },
	},
	ruins_jade_inlay = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { Color3.fromRGB(232, 190, 80), Color3.fromRGB(80, 160, 120) },
	},
	-- #3997: the Snowy Crate's Mythical floor, the same light under clear ice with the northern lights' glints
	snow_aurora_ice = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { Color3.fromRGB(120, 230, 200), Color3.fromRGB(170, 140, 255) },
	},
	-- #4070: the Water Park Crate's Mythical floor, the same moving light with pool blue and foam white glints
	funfair_wave_pool = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { Color3.fromRGB(120, 205, 240), Color3.fromRGB(240, 250, 255) },
	},
	-- #4184: the Castle Crate's Mythical floor, the same moving light with ember orange and gold glints (a first
	-- pick by Model-Agent for Motion-FX to tune)
	castle_dragon_scales = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { Color3.fromRGB(255, 140, 60), Color3.fromRGB(255, 214, 120) },
	},
	classic_gold_leaf = {
		look = "goldLeaf",
		on = "Paint",
		emitter = "decorGlint",
		colors = { palette.offwhite, palette.goldLight },
	},
	-- The Rally Crate's Mythical paint (F101, Model-Agent's #766: gold 255, 201, 77 Foil on the Paint parts, its
	-- `_Trim` trims with #660), with Gold Leaf's look: the glints over the front and, once trims are in, their sweep.
	rally_trophy_gold = {
		look = "goldLeaf",
		on = "Paint",
		emitter = "decorGlint",
		colors = { palette.offwhite, palette.goldLight },
	},
	-- The Grand Cafe theme (#1624, the plot's `Theme` "grand"): Gold Leaf's sweep and night glow on its gold trims.
	theme_grand = { look = "grandTrims", on = "Theme" },
} :: { [string]: DecorSpec }

-- How the Mythical styles look. Walls: Midnight Sky's stars and moon and Aurora Sky's lights are pictures on a
-- see-through sheet laid `lift` studs inside the back and side walls (the wallpaper layer is `layer` thick, from
-- plot.py), from `wallFrom` above the floor to `wallTo` under the eave, at `pixels` per stud. The floor and the
-- front take `floorPixels`. Times are seconds; positions and sizes in UI scale unless they say pixels.
Presets.decorFx = {
	checkEvery = 1,
	retry = { first = 2, most = 30 }, -- a piece whose walls, floor or front are missing waits, doubling, between tries
	layer = 0.2,
	lift = 0.03,
	wallFrom = 1,
	wallTo = 0.4,
	pixels = 12,
	floorPixels = 6,
	-- Midnight Sky: stars on the back and side walls (`size` pixels, `shown` transparency), `twinkleShare` of them
	-- fading to `faded` and back every `twinkle` seconds, diamonds from `diamondFrom` pixels. #2734 (Mythical should
	-- read well above an Epic on a phone): was 16 and 10 stars of 3 to 7 pixels at 0.05 to 0.35.
	stars = {
		back = 22,
		side = 14,
		size = { 4, 8 },
		shown = { 0, 0.25 },
		twinkleShare = 0.5,
		twinkle = { 1.2, 2.6 },
		faded = 0.85,
		diamondFrom = 6,
	},
	-- A full moon `size` pixels wide, `height` down the back wall, drifting from `from` to `to` and back. Its soft
	-- glow is rings of warm light, each { times as wide, transparency }, fainter as they widen.
	moon = {
		size = 52,
		glow = { { 1.5, 0.84 }, { 2.1, 0.9 }, { 2.8, 0.95 } },
		crater = 0.75,
		height = 0.3,
		from = 0.2,
		to = 0.8,
		seconds = 45,
	},
	-- Aurora Sky: soft curtains of light `height` tall, violet at the top to teal at the foot, swaying `sway`
	-- degrees and drifting `drift` across over their `seconds`, with `stars` still stars a wall behind them. #2734:
	-- was 0.45 shown, 5 degrees, 0.12 shimmer and 6 stars, a faint wash on a phone.
	aurora = {
		bands = 3,
		height = 0.42,
		shown = 0.32,
		sway = 7,
		drift = 0.05,
		shimmer = 0.18,
		seconds = { 7, 9, 11 },
		stars = 10,
	},
	-- Glimmer Canal: light bands `width` wide sliding across the floor under the glass, each crossing in `seconds`.
	-- Mirage Glass and Jade Inlay share it. #2734: was 4 bands at 0.78 crossing in 9 to 15 s, hard to see from the
	-- street.
	canal = { bands = 5, width = 0.16, shown = 0.66, tilt = 30, seconds = { 7, 12 } },
	-- Rainbow Shimmer: a rainbow tint over the cafe front that scrolls once across in `seconds`, lit `light` like
	-- paint, with a white `glint` (Gold Leaf's sheen in white) crossing it (#2734: was 0.78 shown, 18 s, 0.6 lit and
	-- no glint, too faint to read as Mythical).
	-- #3221: the cafe's front doorway (plot.py DOOR: 7 wide at x 0, square to 7.5, then a round arch), left out of
	-- the front tints; `rows` bands step up the arch
	doorway = { half = 3.5, spring = 7.5, rows = 5 },
	rainbow = {
		shown = 0.5,
		seconds = 10,
		light = 0.35,
		glint = { width = 0.1, shown = 0.35, seconds = 6 },
		colors = {
			palette.shirtRed,
			palette.golden,
			palette.leaf,
			palette.fishBlue,
			palette.aurora,
			palette.nosePink,
		},
	},
	-- Gold Leaf: a sheen `width` wide sweeping over the front, crossing it in a share of every `seconds`. Trophy Gold
	-- shares it. #2734: was 0.45 shown every 7 s.
	sheen = { width = 0.08, shown = 0.35, tilt = 20, seconds = 5 },
	-- Gold Leaf on real gold trims (F89 2c, luck-and-rare-moments.md: "a slow glint that sweeps across the trims
	-- every 5 seconds and a soft glow on them at night"). The trims are Model-Agent's `_Trim` parts tagged `tag`. A
	-- glint `width` studs wide crosses the front in `seconds` at the start of every `every`, lifting each trim up to
	-- `shine` of the way to `glint`, with `sparkles` glints along the eave every `sparkleEvery` as it passes. At night
	-- every trim lifts `night` of the way to `glow`, and `lights` soft lights stand `out` studs in front of the front
	-- and `below` studs under the eave, `range` and `brightness` each. The trims are read again every `checkEvery`
	-- seconds as they stream in; `tolerance` is how far a trim's colour may read back from what was written.
	trims = {
		tag = "PaintTrim",
		every = 5,
		seconds = 1.6,
		width = 3,
		shine = 0.75,
		glint = palette.offwhite,
		sparkles = 1,
		sparkleEvery = 0.12,
		night = 0.3,
		glow = palette.goldLight,
		lights = 3,
		out = 1.5,
		below = 0.8,
		range = 9,
		brightness = 0.35,
		checkEvery = 2,
		tolerance = 2 / 255,
	},
	petalPad = 0.8, -- share of the tree's width the petals fall from
}

-- A stray's rarity gem (Derek 2026-10-28 01:25: "have some sort indicator of what rarity the cat is before going
-- up to it and looking at the name"): a small gem in the rarity colour (Presets.rarity) bobs `above` studs over each
-- stray whose rarity `shows`, `size` studs tall plus `pixels` so a far one still reads. It is a square turned 45
-- degrees, `gem` of the gui across, lit from the top (`light` of the way to white, `dark` to black at the bottom)
-- with a white edge; a Mythical one glints now and then. It stays up close while the cat is free (hideWithin is 0,
-- so the gem and the Catch card's name sit together), hides only while someone is catching the cat, and shows to
-- maxDistance for the `most` nearest. A hidden gem comes back past hideWithin + showAfter (both 0, so at once).
Presets.rarityMark = {
	shows = {
		Common = true,
		Rare = true,
		Epic = true,
		Legendary = true,
		Mythical = true,
		Secret = true,
	} :: { [string]: boolean },
	glints = { Legendary = true, Mythical = true, Secret = true } :: { [string]: boolean },
	above = 0.9,
	-- #2231 (Derek2 2026-11-07: "make the gems that show raritys glow and be more obvious"): the billboard is twice
	-- the old one, the gem a bit under half of it (about 1.5 times the old gem) and a halo in the rarity colour fills
	-- the rest; the rim is the rarity colour lightened `rim` towards white, so it reads like neon at night
	size = 1.6,
	pixels = 30,
	gem = 0.46,
	corner = 0.18,
	light = 0.45,
	dark = 0.2,
	rim = 0.6,
	outlinePixels = 2.5,
	-- the halo: three soft rings, the outer the faintest, each `transparency` at full strength; how strong it is per
	-- rarity (Common faint, Mythical full)
	haloRings = {
		{ scale = 1, transparency = 0.8 },
		{ scale = 0.78, transparency = 0.66 },
		{ scale = 0.6, transparency = 0.5 },
	} :: { { scale: number, transparency: number } },
	halo = {
		Common = 0.3,
		Rare = 0.5,
		Epic = 0.7,
		Legendary = 0.85,
		Mythical = 1,
		Secret = 1,
	} :: { [string]: number },
	haloRest = 0.92, -- of the billboard, while still
	-- Epic and up breathe their halo out to `grow` times its rest size over `seconds` (one way), faster and further the
	-- rarer; held still with Reduce Motion or Low performance
	pulse = {
		Epic = { seconds = 1.4, grow = 1.08 },
		Legendary = { seconds = 1.1, grow = 1.14 },
		Mythical = { seconds = 0.8, grow = 1.2 },
		Secret = { seconds = 0.7, grow = 1.26 },
	} :: { [string]: { seconds: number, grow: number } },
	bob = 0.15,
	bobSeconds = 0.9, -- one way
	glintSize = 0.3,
	glintSeconds = 0.3, -- one way
	glintEvery = { Legendary = 2.6, Mythical = 1.6, Secret = 1.2 } :: { [string]: number }, -- seconds between glints
	hideWithin = 0,
	showAfter = 0,
	maxDistance = 80,
	most = 12,
	checkEvery = 0.25,
	-- #5201 (Derek 2026-11-18: "make gems viewable if in view not distance"): a gem shows on every stray on screen out
	-- to `reach` studs (about as far as strays stream in), not only the `maxDistance` nearest; Rare and up take the
	-- slots first, then the nearest. At most `most` at once, `lowMost` on a phone or in Low performance. `margin`
	-- (share of the screen) lets one just off the edge keep its gem as the camera turns.
	inView = {
		reach = 300,
		most = 24,
		lowMost = 16,
		margin = 0.08,
	},
	-- Derek 2026-11-18 ("make the cats diamonds smaller from further away as they block the cats"; switch `flag`, off
	-- by default): the billboard's fixed `pixels` part tapers from full at `near` studs to `least` at `far` (the Park
	-- finder's to `finderLeast`), so past `far` a gem is 1.6 studs plus a few pixels and shrinks with the cat
	shrink = {
		flag = "gemsShrink",
		near = 20,
		far = 80, -- Sync 2026-11-18: 110 left gems at 60 to 100 studs covering 38 to 51% of the cat
		least = 4,
		finderLeast = 14,
	},
	-- #5034 Park phone leak (phones 37% never catch a cat in the Park, mostly from not finding one): with the switch
	-- `flag` on and no `area` cat in the player's Index yet, the gems of that area's strays (their `Area`) show out to
	-- `maxDistance` studs, `pixels` wide at the least, and draw over hedges and walls (AlwaysOnTop) past `onTopBeyond`
	-- studs, so a stray across the Park reads on a phone. Everywhere else, and once a Park cat is caught, as before.
	finder = {
		flag = "parkFinder",
		area = "park",
		maxDistance = 160,
		pixels = 40,
		onTopBeyond = 30,
	},
	-- #2258 (Derek2 2026-11-07: "show new tag if it's a cat you don't own yet for people index hunting"): a NEW pill
	-- over the gem of a cat not in your Index yet, in leaf green (no rarity uses it), `width` by `height` of the
	-- gem's square, its foot `overlap` down over the gem's top corner (it pokes a little over the billboard's top)
	newTag = {
		text = "NEW",
		width = 0.72,
		height = 0.26,
		overlap = 0.05,
		fill = Presets.palette.leaf,
		textColour = Presets.palette.milk,
		textOutline = Color3.fromRGB(36, 92, 40),
		rim = Presets.palette.offwhite,
		rimPixels = 2,
	},
}

-- Walking through water (Derek 2026-10-28 01:33, Effects/Splash): feet count as in the water from `above` studs
-- over its top down to `depth` under it, on a plate whose up is at least `flat` upright. A splash comes on stepping
-- in, then every `stride` studs walked (a player's step, a cat's), at least `minSpeed` studs a second, alternating
-- feet `side` studs out: `drops` droplets (splashDrops) and a ripple from `rippleFrom` to `ripple` studs across over
-- rippleSeconds. Checked every checkEvery seconds for the `most` nearest walkers within maxDistance studs (you first).
Presets.splash = {
	above = 0.4,
	depth = 3,
	flat = 0.7,
	minSpeed = 2,
	stride = { player = 2.6, cat = 1.1 } :: { [string]: number },
	side = { player = 0.4, cat = 0.15 } :: { [string]: number },
	drops = { player = 5, cat = 3 } :: { [string]: number },
	ripple = { player = 1.8, cat = 1 } :: { [string]: number },
	rippleFrom = 0.4,
	rippleSeconds = 0.5,
	rippleTransparency = 0.35,
	rippleColour = Presets.palette.milk,
	checkEvery = 0.1,
	maxDistance = 60,
	most = { high = 6, low = 3, saver = 1 },
}

-- Potions (F64, data-model 12b, and the quest potions of F73): each kind's glow while it runs, shown on the newest id in the drinker's
-- `ActivePotions` (data-model 13). `on` is where its emitter sits: "Body" the root part, "Feet" an attachment under it,
-- "Hands" the two hands (the rate split between them). The drink pop, on your own `buffs` growing in ProfileSync, is
-- `sparkles` catch sparkles in the potion's colour at the chest and a `ring` stud ring at the feet.
export type PotionSpec = { emitter: string, on: string, colour: Color3 }
Presets.potions = {
	tip_potion = { emitter = "potionTip", on = "Body", colour = palette.golden },
	lucky_potion = { emitter = "potionLucky", on = "Body", colour = palette.leaf },
	swift_potion = { emitter = "potionSwift", on = "Feet", colour = palette.fishBlue },
	steady_potion = { emitter = "potionSteady", on = "Hands", colour = palette.mint },
	-- the quest potions (F73, quests.md section 4)
	big_tip_potion = { emitter = "potionBigTip", on = "Body", colour = palette.golden },
	gold_rush_potion = { emitter = "potionGoldRush", on = "Body", colour = palette.goldLight },
	quick_bait_potion = { emitter = "potionQuickBait", on = "Hands", colour = palette.blush },
	-- #3462: the Day Cart's Tier 6 potions, each a bigger, busier glow of its smaller kind
	big_lucky_potion = { emitter = "potionBigLucky", on = "Body", colour = palette.leaf },
	big_gold_rush_potion = {
		emitter = "potionBigGoldRush",
		on = "Body",
		colour = palette.goldLight,
	},
	mega_tip_potion = { emitter = "potionMegaTip", on = "Body", colour = palette.golden },
	-- #4195: the Admin Wheel's hour of 3x money glows as Mega Money until Motion-FX gives it its own
	admin_money_potion = { emitter = "potionMegaTip", on = "Body", colour = palette.golden },
	-- #5572: Picnic Time glows as Mega Money until Motion-FX gives it its own
	picnic_time = { emitter = "potionMegaTip", on = "Body", colour = palette.golden },
} :: { [string]: PotionSpec }
-- The Speed Shoes' trail (Effects/SpeedShoes): shown on wearers within `radius` studs, checked every `pickEvery`
-- seconds; `moving` is how much of full walking input counts as on the move; the puffs start `lift` studs over the
-- ground and `behind` studs back from the middle of the body. `model` is the worn shoes' name in the character.
Presets.speedShoes = {
	radius = 50,
	pickEvery = 0.25,
	moving = 0.2,
	lift = 0.25,
	behind = 0.6,
	model = "CatCafe_Item_SpeedShoes",
}

-- #4558 Fire Trail (Dragon Keep card, look only; Effects/FireTrail): embers at the heels while a player whose
-- `FireTrail` attribute is true (DragonKeepService) walks on the ground faster than `moving` of full speed; the nearest
-- budget.potionGlows within `radius`, yours first, re-picked every `pickEvery` seconds. None in Low performance.
Presets.fireTrail = {
	radius = 60,
	pickEvery = 0.25,
	moving = 0.2,
	lift = 0.2,
	behind = 0.5,
}

-- The Dragon Keep's set looks (Effects/KeepSets): `families` maps each card family to its emitter, `onHead` the
-- ones worn on the head. Level 5 runs `bigRate` times the rate at `bigSize` times the size. The nearest
-- budget.potionGlows players within `radius` studs show theirs, checked every `pickEvery` seconds.
Presets.dragonSets = {
	radius = 60,
	pickEvery = 0.5,
	bigRate = 2,
	bigSize = 1.4,
	families = {
		flame = "dragonSetFlame",
		claw = "dragonSetClaw",
		wing = "dragonSetWing",
		hoard = "dragonSetHoard",
		heart = "dragonSetHeart",
		crown = "dragonSetCrown",
	} :: { [string]: string },
	onHead = { crown = true } :: { [string]: boolean },
}

Presets.potionFx =
	{ radius = 50, pickEvery = 0.5, sparkles = 10, chest = 0.5, ring = 3, ringSeconds = 0.45 }

-- The intro's shot 4 (F72): the demo cat leaves your arms in a cream puff of `from` smoke and appears in its seat in
-- one of `seat` with `sparkle` sparkles.
Presets.introPuff = { from = 5, seat = 6, sparkle = 8 }

-- The Mystery Visitor (F64): a purple puff of `puff` smoke where the visitor arrives and leaves, `sparkle` sparkles
-- where the gift appears and, when the owner opens it (MysteryGiftResult), confetti (`confetti` of the budget's) in
-- the ribbon colours with `pop` sparkles and a `ring` in the colour of what was inside, from the gift's top.
Presets.mystery = {
	puff = 6,
	puffColour = palette.aurora,
	sparkle = 6,
	pop = 8,
	ring = 3,
	ringSeconds = 0.45,
	confetti = 0.4,
	ribbon = { palette.neonPink, palette.aurora, palette.sparkle, palette.offwhite },
	-- one small camera shake as it opens, `shake` s of `shakeStuds`; the pop, confetti, ring and shake grow by the
	-- wrap's `tierScale` (#2614: Super pops twice as big)
	shake = 0.25,
	shakeStuds = 0.15,
	tierScale = { Common = 1, Rare = 1.3, Super = 2 } :: { [string]: number },
	-- the red "!" over every waiting gift (#1638): `studs` wide plus `pixels`, so it still reads from across the
	-- street, `lift` studs over the gift, seen within `within` studs, bobbing `bob` studs every `seconds`
	bang = {
		studs = 1.2,
		pixels = 18,
		lift = 1.2,
		within = 150, -- as the rich tip's marker and the camp stations' "!" (#2272)
		bob = 0.5,
		seconds = 1.6,
		colour = Color3.fromRGB(240, 82, 79), -- the HUD's and the camp stations' red "!"
	},
	-- what was inside: a potion in its own colour, the rest by kind
	kinds = {
		lure = palette.blush,
		fish = palette.golden,
		spin = palette.lampWarm,
		potion = palette.mint,
	} :: {
		[string]: Color3,
	},
}

-- The Cat Cannon flight (F84, hometown-cannon.md section 3b; CannonLaunchSeconds 3.75 is `endAt`). Seconds from the
-- server's `CannonLaunchAt`: the fuse fizzes until `boomAt`, then a smoke ring, confetti and a shake at the muzzle
-- and a sparkle trail on the flying body until `puffAt`, where a cloud puff swallows it in the sky. The trail comes
-- back as it drops onto the landing pad from `dropAt`, and a dust poof goes off at `landAt`, when its feet touch
-- down (Animation-Engineer's Presets.cannonPose). Onlookers within `within` studs see it; the launching player also
-- gets the full-screen clouds (Presets.clouds.cannon) with their own character gliding through them. `tints` is
-- each destination's colour in the clouds: the paw path colours of town-layout-v3, neon pink for the Alleyway and a
-- warm cream for the Town Square and Home.
Presets.cannon = {
	boomAt = 0.5,
	puffAt = 2.0,
	dropAt = 3.0,
	landAt = 3.5,
	endAt = 3.75, -- #2690: was 4.0
	stale = 0.5, -- seconds past endAt a flight still plays (joined or streamed in late: none)
	fuseSeconds = 0.5, -- the fizz runs over this long before the boom
	fuseEvery = 0.08, -- seconds between fizzes
	ring = 8, -- smoke puffs round the muzzle
	ringRadius = 1.4, -- studs
	ringPuffs = 2, -- smokePuff particles at each of them
	confetti = 0.6, -- of the budget's confetti
	shake = 0.35, -- seconds
	shakeStuds = 0.5, -- for the launching player
	shakeNear = 0.2, -- for anyone within shakeWithin studs of the muzzle
	shakeWithin = 24,
	skyPuff = 14, -- smokePuff particles where the player vanishes
	landRing = 6, -- dust bursts round the landing spot
	landRadius = 1.6,
	landDust = 4,
	within = 150,
	skyWithin = 450, -- the sky puff only: the flyer vanishes ~250 studs out, 240 up (#1174)
	most = 4, -- flights showing their trail at once, your own first
	findCannon = 20, -- studs round the player at launch to look for the cannon they sit in
	-- The intro's cannon shot (intro-cutscene.md shot 2, PR #576): the flight squeezed, in seconds from the
	-- shot's BOOM, for Cannon.playStaged. The sky puff at 0.55, the clouds cover by the cut to the camp at 0.7, the
	-- copy glides 0.7 to 1.1, the clouds part 1.1 to 1.4 and the dust poof goes off at 1.55.
	introStage = {
		boomAt = 0,
		puffAt = 0.55,
		dropAt = 1.4,
		landAt = 1.55,
		endAt = 1.8,
		clouds = {
			coverFrom = 0.55,
			coverTo = 0.66, -- full a couple of frames before the cut to the camp at 0.7
			partFrom = 1.1,
			partTo = 1.4,
			tintFrom = 0.75,
			tintTo = 1.05,
		},
		glideFrom = 0.7,
		glideTo = 1.1,
	},
	tints = {
		town = Presets.palette.lampWarm,
		home = Presets.palette.lampWarm,
		alley = Presets.palette.neonPink, -- a fifth cannon area since hometown-cannon.md PR 566: the jazz club signs
		park = Presets.palette.leaf,
		neighbourhood = Color3.fromRGB(240, 150, 70),
		woods = Color3.fromRGB(46, 122, 74),
		sewer = Color3.fromRGB(96, 116, 158),
		desert = Color3.fromRGB(232, 205, 150), -- Tier 6 (#2657): sand
		ruins = Color3.fromRGB(80, 160, 120), -- Tier 7 (#2657): jade
		snowy = Color3.fromRGB(214, 236, 255), -- Tier 8 (#4069): ice blue
		waterpark = Color3.fromRGB(120, 205, 240), -- #4070: pool blue
		castle = Color3.fromRGB(255, 214, 120), -- #4071: banner gold
	} :: { [string]: Color3 },
}

-- The full-screen clouds of a cannon flight and of a cloud hop (Home and the night sweep from a wild area;
-- CloudHopSeconds 1.6, the move at 0.6; Derek 13:56: "make the cloud cutscene a little better"). Each plan is
-- seconds from its start: the clouds rush in over coverFrom..coverTo, cover the screen fully until partFrom (the
-- server moves the player meanwhile), and draw aside like curtains by partTo. Over tintFrom..tintTo the
-- destination's colour comes up from below as if the land shows through: `tint` says how far toward it the cloud
-- tops, their undersides and the sky's top and bottom go. A cloud is `lobes` circles ({x, y, size} as shares of its
-- box), white on top and shaded only in its lower part, and flies out from the middle in `rush` seconds, puffing up
-- as the clouds rush in; the wind streaks take `windShare` of that. A sun glow of `glow` rings ({size of the
-- screen's shorter side, most opacity}) shines ahead, and the tunnel banks by `bank`. With Reduce Motion it all
-- holds still and fades instead. `displayOrder` sits over the popups (40) and under the intro (50);
-- UI-Engineer's destination name card goes above it.
Presets.clouds = {
	displayOrder = 45,
	riderZ = 7, -- Animation-Engineer's gliding character, between the clouds behind (4, 6) and in front (8, 10)
	white = Presets.palette.offwhite,
	shade = Color3.fromRGB(214, 226, 240), -- the underside of each cloud
	sky = Presets.palette.pastelSky,
	sun = Presets.palette.sparkle,
	tint = { top = 0.1, under = 0.45, skyTop = 0.15, skyBottom = 0.55 },
	shadeFrom = 0.55, -- of a lobe's height: white above, shading down to `shade` below
	rush = 0.9,
	cloudSize = { 0.45, 0.85 }, -- of the screen's shorter side, at the edge
	lobes = {
		{ 0, 0.05, 0.6 },
		{ -0.28, 0.12, 0.44 },
		{ 0.28, 0.14, 0.42 },
		{ -0.1, -0.16, 0.42 },
		{ 0.14, -0.1, 0.36 },
	},
	glow = { { 1.0, 0.12 }, { 0.8, 0.16 }, { 0.6, 0.22 }, { 0.42, 0.3 }, { 0.26, 0.4 } },
	bank = { share = 0.04, hz = 0.35 }, -- the middle drifts this share of the shorter side round a slow loop
	windShare = 0.45,
	windLength = 0.22, -- of the shorter side, at the edge
	windAlpha = 0.6,
	cannon = {
		coverFrom = 2.0,
		coverTo = 2.2,
		partFrom = 3.0,
		partTo = 3.4,
		tintFrom = 2.6,
		tintTo = 3.0,
	},
	-- #5370 (Derek 2026-11-18: "no need to see floating islands in the distance when shooting in cannon anymore as it
	-- only shows them half rendered"): with cannonCloudsEarly on, the clouds cover just after the ball leaves the barrel
	-- (the boom is at 0.5), so the chase up the sky never shows the far areas, and the destination loads behind them
	cannonEarly = {
		coverFrom = 0.75,
		coverTo = 1.0,
		partFrom = 3.0,
		partTo = 3.4,
		tintFrom = 2.6,
		tintTo = 3.0,
	},
	earlyFlag = "cannonCloudsEarly",
	hop = {
		coverFrom = 0,
		coverTo = 0.5,
		partFrom = 1.1,
		partTo = 1.6,
		tintFrom = 0.6,
		tintTo = 1.0,
	},
	hopPuff = 12, -- smokePuff particles where onlookers see a player hop away and arrive
	moved = 30, -- studs a root jumps in one step during a hop: it has arrived
}

-- The intro's cloud dip over a jump between far-apart places (IntroCut.luau, #958; Derek 2026-11-03 00:50: "make the
-- locations cuts smoother"): the cannon's clouds (Presets.clouds) on a short plan, in seconds from when the hook came
-- in, `cut` seconds before the jump. They cover the screen fully a few frames before the jump and part over the next
-- third of a second, in plain white (no tint).
Presets.introCut = {
	cut = 0.2, -- Gameplay-Engineer's Intro.CUT_LEAD
	-- a shot this long or longer gets the whole dip; a shorter one (the camp tour's 0.45 s cuts) a shorter one in
	-- proportion (Logic.introDip). The dip takes coverFrom to partTo = 0.55 s of the shots around it, half of 1.1 s.
	full = 1.1,
	plan = {
		coverFrom = 0,
		coverTo = 0.16,
		partFrom = 0.24,
		partTo = 0.55,
		tintFrom = 99,
		tintTo = 99,
	},
	tint = Presets.palette.offwhite,
}

-- The campfires (the Woods' campsite and the Great Oak clearing; Derek 2026-10-30: "The fire from the camp fire
-- isnt moving"). Model-Agent's flame (the `_Campfire_Glow` model: three tongues of three stacked Neon discs) moves on
-- this client: each tongue stretches and squashes, leans and bends a little more at the tip, and flickers brighter,
-- out of step with the others. Warm embers drift up off it with a small pop of them now and then, and a warm light
-- flickers with the flame, brighter at night. With Reduce Motion the flame moves `still` as much. The nearest
-- `campfires` (budget) within ambientRadius run; the rest stand as modelled.
-- `kinds`: what burns, by the end of the flame Model's name, each with the reach of its light in studs, how bright
-- it is against `brightness`, the embers in a pop and how far over the flame's base they leave from. A torch (#4071)
-- is a smaller flame up on a post.
export type FlameKind = { range: number, bright: number, pop: number, emberHeight: number }
Presets.campfire = {
	kinds = {
		_Campfire_Glow = { range = 14, bright = 1, pop = 5, emberHeight = 1.2 },
		_Torch_Glow = { range = 10, bright = 0.8, pop = 2, emberHeight = 0.9 },
	} :: { [string]: FlameKind },
	stretch = 0.2, -- of the modelled height, either way
	lean = 9, -- degrees at the tip
	hz = { 1.7, 2.9, 4.3 }, -- the three waves each tongue's motion is made of
	still = 0.4,
	gap = 0.05, -- studs across the ground between the discs of one tongue
	brighten = 0.2, -- how far the flicker lifts each disc's colour toward `hot`
	hot = Presets.palette.lampWarm,
	light = Color3.fromRGB(255, 176, 102),
	brightness = 1.1,
	flicker = 0.35, -- of the brightness, either way
	night = 1.6, -- times the brightness at night
	popEvery = { 2.5, 5 }, -- seconds between pops
}

-- A cat checked in at a camp (F84 section 4): it hops out of its carrier's arms in an arc `hopHeight` studs high
-- into the carrier basket over `hopSeconds`, then puffs away with a few sparkles.
Presets.campCheckIn = {
	hopSeconds = 0.45,
	hopHeight = 2.5,
	shrink = 0.6, -- of its size by the end of the hop, as it goes into the basket
	puff = 10,
	sparkle = 8,
	findBasket = 40, -- studs round the carrier
	within = 120,
}

-- The leaderboard crown (F98, leaderboards.md section 3: a crown over anyone in an all time top 10; the UI's
-- Screens/Crowns draws it `lift` studs over the head, in the camera's up, as a BillboardGui seen within `within`
-- studs). Effects/Crown: every `every` seconds a crown glints with `glint` crownGlint stars within `spread` studs of
-- it, on the nearest budget.crownGlints crowned players, chosen every `pick` seconds. When a player near you earns the
-- crown (their `Crown` goes from false to true at a refresh while you watch; the first value seen sets no burst),
-- `earned.sparkles` gold sparkles and `earned.stars` glints burst at the crown, a share `earned.confetti` of the
-- budget's confetti falls in gold, and a gold ring `earned.ring` studs across opens at their feet. Still with Reduce
-- Motion (the confetti halves there as everywhere).
Presets.crown = {
	lift = 3.2, -- Screens/Crowns LIFT
	within = 80, -- Screens/Crowns MAX_DISTANCE
	every = { 2.5, 5 },
	glint = 3,
	spread = 0.4,
	pick = 0.5,
	earned = {
		sparkles = 12,
		stars = 6,
		confetti = 0.3,
		ring = 4,
		ringSeconds = 0.55,
		colour = Presets.palette.golden,
	},
}

-- The shop-only cats (#1191, Design-Agent's brief 2026-11-04; Effects/ShopCats). Sprinkles (`catId`): when a tip is
-- swept off a paid table in a cafe where it works (Moments.TipSwept, your own cafe), a puff of `each` sprinkle
-- particles in each of `colours` (one small burst in all, scaled by the budget) pops `lift` studs over its Head's
-- BubbleAnchor (else `overPivot` studs over its pivot, or `overPile` over the pile when it swept itself), at most once
-- every `gap` seconds and within `within` studs. With Reduce Motion: a short glow in `glow.colour` instead.
Presets.shopCats = {
	sprinkles = {
		catId = "sprinkles",
		gap = 20,
		within = 120,
		lift = 0.3,
		overPivot = 2.5,
		overPile = 2.5,
		each = 2,
		colours = {
			Presets.palette.neonPink,
			Presets.palette.golden,
			Presets.palette.mint,
			Presets.palette.eyeBlue,
			Presets.palette.aurora,
		},
		glow = { seconds = 1.2, range = 8, brightness = 1.5, colour = Presets.palette.furRose },
	},
	-- Duchess Marzipan (`catId`): the `lilacPetal` emitter on her Head's BubbleAnchor, on the nearest
	-- budget.shopCatEmitters within `within` studs, chosen every `pick` seconds. In Low performance or with Reduce
	-- Motion, `still` instead: petals `size` studs long at `spots` ({ x, z, turn }) on the floor round her feet,
	-- smoke-sprite decals in `colour`. As she starts a shift, `shift.sparkles` lilac sparkles over her ears (else
	-- `overPivot` studs over her pivot) and a `shift.ring` ring at her feet.
	duchess = {
		catId = "duchess_marzipan",
		within = 40,
		pick = 0.5,
		overPivot = 2.5,
		colour = Color3.fromRGB(200, 170, 230), -- lilac, her cape
		still = {
			size = 0.5,
			colour = Color3.fromRGB(200, 170, 230),
			transparency = 0.25,
			spots = { { 0.9, 0.3, 0.4 }, { -0.7, 0.6, 1.9 }, { 0.2, -0.9, 3.1 } } :: { { number } },
		},
		shift = { sparkles = 8, ring = 3, ringSeconds = 0.5 },
	},
	-- Maple Muffin (`catId`), the Season 1 cat (#1668): the `mapleLeaf` emitter on its Head's BubbleAnchor while it
	-- works (a Role without Bedtime), sharing Duchess's budget.shopCatEmitters and her `pick` beat, within `within`
	-- studs. In Low performance or with Reduce Motion, `still` leaves on the floor round its feet instead.
	maple = {
		catId = "maple_muffin",
		within = 40,
		still = {
			size = 0.5,
			colour = Color3.fromRGB(222, 120, 48), -- amber, its fur
			transparency = 0.2,
			spots = { { -0.8, 0.4, 0.7 }, { 0.6, -0.7, 2.2 }, { 0.3, 0.9, 4.0 } } :: { { number } },
		},
	},
	-- King Croissant (`catId`), on the nearest `most` within `within` studs, stepped every `step` seconds: a soft
	-- gold `glow` (a PointLight on his chest's Glow attachment, kept with Reduce Motion and Low performance), the
	-- `goldMote` emitter there (none with Reduce Motion, in Low performance or with no budget.shopCatEmitters), and
	-- a sparkle Texture in `trim.colour` tiled every `trim.tile` studs on `trim.faces` of his cape trim's band,
	-- scrolling `trim.speed` studs a second (still with Reduce Motion). When his table pays (the same moment as
	-- Sprinkles), `pop.sparkles` gold sparkles, `pop.stars` gold stars and a `pop.ring` ring off his CrownTop (else
	-- `overPivot` studs over him), at most once every `pop.gap` seconds; not with Reduce Motion.
	king = {
		catId = "king_croissant",
		within = 60,
		most = 2,
		step = 0.1,
		overPivot = 3.2,
		glow = { colour = Presets.palette.goldLight, range = 8, brightness = 0.8 },
		trim = {
			colour = Presets.palette.golden,
			transparency = 0.35,
			tile = 1.2,
			speed = 0.4,
			faces = { Enum.NormalId.Back, Enum.NormalId.Front } :: { Enum.NormalId },
		},
		pop = { gap = 20, sparkles = 10, stars = 5, ring = 4, ringSeconds = 0.55 },
	},
	-- The Royal Crest sign style (King Cat Pack, #1191): on every bar (part) of a Model named `model`, on the
	-- nearest `most` within `within` studs, a soft gold sparkle Texture on `faces` slides once across the frame over
	-- `sweep` seconds every `every` seconds (each sign on its own beat), fading in and out and at its brightest at
	-- `transparency`. None with Reduce Motion: the frame stays as modelled.
	royalCrest = {
		model = "CatCafe_Plot_SignRoyalCrest_Frame",
		within = 100,
		most = 3,
		every = 8,
		sweep = 1.2,
		transparency = 0.35,
		colour = Presets.palette.goldLight,
		faces = { Enum.NormalId.Front, Enum.NormalId.Back } :: { Enum.NormalId },
	},
}

-- Customers walking (Derek 2026-11-04, #1143: "walking looks like mini hopping"; Effects/CustomerWalk.luau). The
-- customer models are loose parts on a pivot at the feet, so the legs are the parts below `legTop` within
-- `legHalfWidth` of the middle and the arms the ones from `armBottom` to `armTop` at least `armFrom` out (a side that
-- also has a part lower down there, a bag, keeps its arm still). Each leg swings `legSwing` degrees either way about
-- the hip and each arm `armSwing` the other way about the shoulder, one cycle per `stride` studs walked (two steps:
-- Config.CustomerWalkSpeed 7 makes 2.5 a second), the body rolls `roll` degrees side to side once a cycle and drops
-- as a leg leaves the upright so the feet stay on the floor (the bob). It eases in over `easeIn` seconds and back to
-- standing over `settle` once it stops; `reduced` scales the swing, roll and bob with Reduce Motion.
Presets.customerWalk = {
	legTop = 1.7,
	legHalfWidth = 0.6,
	armFrom = 0.75,
	armBottom = 1.7,
	armTop = 3.6,
	hip = 1.65,
	shoulder = 3.3,
	stride = 2.8,
	legSwing = 22,
	armSwing = 16,
	roll = 2,
	easeIn = 0.2,
	settle = 0.2,
	reduced = 0.5,
	idleAfter = 0.08, -- seconds with no walk step before it starts to settle
}

-- The camp stations' ready glows (camp-stations.md sections 2 to 4; Effects/CampGlow): while one of your stations
-- holds something (Picnic potions #1133, a free Yard Sale crate #1154, Fish Pond fish #1232), one PointLight in its
-- `colour`, `brightness` over `range` studs (inside the night glow budget: the street's night lights are 0.5 over
-- 8), fading in and out over `fade` seconds, on the station's `anchor` attachment, else `under` of the way up its
-- bounding box (under the parasol, the awning, the hut's roof), once it holds `atLeast` (the pond: half its 36,
-- Config.PondHold, so it reads as worth a trip). Checked every `pick` seconds for streaming.
Presets.campGlow = {
	anchor = "GlowAnchor",
	brightness = 0.6,
	range = 7,
	fade = 0.6,
	pick = 1,
	extras = {
		picnic = { under = 0.45, colour = Presets.palette.lampWarm, atLeast = 1 },
		yardSale = { under = 0.5, colour = Presets.palette.lampWarm, atLeast = 1 },
		pond = { under = 0.4, colour = Presets.palette.golden, atLeast = 18 },
	},
	-- The Lost and Found booth's sign bulb (#1732, camp-stations.md section 4b): while a find waits, the `part`
	-- bulb(s) under the `extra` station go Neon in `colour` for `on` seconds, then back for `off` seconds. Under 1
	-- blink a second, so it stays on with Reduce Motion and Low performance (a material swap, no light).
	blink = {
		extra = "lostFound",
		part = "CatCafe_Camp_Sewer_LostFoundBooth_Blink_Bulb",
		colour = Presets.palette.lampWarm,
		on = 0.6,
		off = 0.6,
	},
}

-- The door sign (#1172, #1140; Effects/DoorSign). Model-Agent's CatCafe_Decor_DoorSign: its OPEN face's parts are
-- named `open`, its CLOSED face is the child Model `closed`, and a sign with a `hanger` child Model (#1346: the hook,
-- twine and two-sided board, pivot at the hook) turns half a turn about its pivot at nightfall and sunrise over `flip`
-- seconds, then settles with one `swing` degree back-and-forth over `settle`; nearer than `within` studs, else (and
-- with Reduce Motion, or on joining) it snaps. A sign without a hanger (the two-board one) hides the other board.
Presets.doorSign = {
	open = "CatCafe_Decor_DoorSign_Open",
	closed = "CatCafe_Decor_DoorSign_Closed",
	hanger = "CatCafe_Decor_DoorSign_Hanger",
	flip = 0.6,
	settle = 0.4,
	swing = 8,
	within = 200,
}

-- The context tips' camera cut (#976, easy-start.md section 3; ContextCut.luau, Logic.cutEye and Logic.cutWeight):
-- the camera swings out to the place over `swingIn` seconds, holds, and swings back over the last `swingOut`. It
-- looks from `extent * fit` studs away (at least `near`, at most `far`), raised by `rise` of that, at a point `lookUp`
-- of the place's height above its middle. Any press after `skipAfter` s skips: it swings back over `skipOut`. Black
-- bars of `bars` of the screen's height slide in with the caption (outlined white text, `captionSize` px, on the
-- lower bar), on a ScreenGui at `displayOrder` (over the HUD, under the tip card's 11 and the cloud tunnel's 45).
Presets.contextCut = {
	swingIn = 0.7,
	swingOut = 0.6,
	fit = 1.4,
	near = 16,
	far = 70,
	rise = 0.45,
	lookUp = 0.15,
	skipAfter = 0, -- #3168: was 1, then 0.2
	skipOut = 0.35,
	bars = 0.11,
	captionSize = 26,
	displayOrder = 10,
}

-- The first bait's cutscene (Effects/FirstBaitCut, #2946, Design-Agent's spec on the issue): the camera eases over
-- `swingIn` s to `back` studs past the bowl from the yard and `up` studs up (`backTall`/`upTall` on a portrait
-- screen), looking `lookUp` studs over the bowl, tried at each of `swings` degrees round the bowl until a ray reaches
-- it clear. The bait cat walks in `walkDistance` studs from the yard (`walkSide` to the side; SlotWalk's copy, about
-- `walk` s, never waited on past `walkMax`), eats over `eat` s with `bites` head dips (`dip` studs down, `pitch`
-- degrees) and a heart puff of `happy` sparkles `happyUp` studs over it halfway, and the camera eases back over
-- `swingOut`. It waits up to `waitCat` s for the server's cat.
-- A press from `skipAfter` s skips it (back over `skipOut`); the "Tap to skip" label (`skipSize` px, `skipFade`
-- transparency) sits in the bottom right on a ScreenGui at `displayOrder`. Everything is given back at `cap` s
-- whatever happened. Off when the bowl is more than `maxDistance` studs from the player.
Presets.firstBaitCut = {
	-- #4920 cut 2 (Design-Agent, first 5 minutes): about 2.5 s from the food to the camera back, with the cat out
	-- at food + 0.3 s: swing in 0.4, walk about 0.8 (5.4 studs at SlotWalk's 7), eat 0.6, swing out 0.4
	swingIn = 0.4,
	swingOut = 0.4,
	back = 10,
	up = 6,
	backTall = 13,
	upTall = 7,
	lookUp = 1.5,
	swings = { 0, 45, -45, 90, -90 },
	walk = 0.8,
	walkMax = 1.0,
	walkDistance = 5,
	walkSide = 2,
	eat = 0.6,
	bites = 2,
	dip = 0.1,
	pitch = 30,
	happy = 10,
	happyUp = 2,
	-- #5074: the server puts the cat out at catOutAt (placedAt + 1 on whole os.time seconds, checked by a 1 s loop),
	-- so it lands 1 to 2 s after the food, plus streaming on a phone. 2.0 left too little and the cut ended "none"
	-- with no cat. A cat on time plays the same 2.2 s cut; only a late one gets the extra second.
	waitCat = 3.0,
	skipAfter = 0.3,
	skipOut = 0.25,
	skipSize = 18,
	skipFade = 0.4,
	displayOrder = 10,
	cap = 5.5, -- #5074: waitCat + walkMax + eat + swingOut (5.0) and a little room
	maxDistance = 120,
	-- #5548 follow-up (Design 2026-11-20): a freeStart save's first food goes in at the Alleyway check-in, away from the
	-- bowl, so with baitCutQuick the scene is owed and plays once the save first comes within `lateNear` studs of its
	-- own bowl with the cat there (outside the walk-up ring's 8, so it comes before the cat's card)
	lateNear = 25,
	lateCheck = 0.25, -- seconds between looks while it is owed
	lateMargin = 5, -- studs past lateNear the bait cards already wait, so none slips in between two looks
	tvSafe = 0.05, -- #2871: the TV's title-safe margin, as a fraction of the screen
	-- #5548 (Derek 2026-11-20: "do the make bait scene quicker and no skip allowed"), switch baitCutQuick: about
	-- 1.5 s with the cat on time (swing in 0.3, walk 0.5 = 3.5 studs at SlotWalk's 7, one bite and the heart puff in
	-- 0.4, swing out 0.3), no skip, so the cap is the only way out: waitCat 1.2 and cap 3.0. Under the same switch
	-- the server puts the first bait cat out at placedAt, as the food lands (#5549), not placedAt + 1 as above
	quick = {
		swingIn = 0.3,
		swingOut = 0.3,
		walk = 0.5,
		walkMax = 0.6,
		walkDistance = 3.5,
		eat = 0.4,
		bites = 1,
		waitCat = 1.2,
		cap = 3.0,
	},
}

-- The front lawn pieces' effects (Effects/Lawn, #1283, front-lawn.md section 5), by LawnId. Each spot is `offset`
-- studs from the bounding box centre of the piece's child named ending `at`, else from the piece's pivot (in its
-- space). `emitter` is a steady Presets.emitters entry (`night`: only after dark); `light` a soft PointLight (`night`:
-- only after dark); `pulse` fires every `every` seconds: a `burst` of `count` in `colour` and/or a `ring` that many
-- studs across; `twinkle` (night only) glints `count` sparkles on a random part of the `at` child every `every`
-- seconds. Only the nearest budget.lawnEffects pieces within `within` studs show any of it, checked every `step`
-- seconds. Reduce Motion drops the emitters and rings and keeps the lights and glints; Low performance shows none.
export type LawnSpec = {
	emitter: { name: string, at: string?, offset: Vector3, night: boolean? }?,
	light: {
		at: string?,
		offset: Vector3,
		colour: Color3,
		range: number,
		brightness: number,
		night: boolean?,
	}?,
	pulse: {
		at: string?,
		offset: Vector3,
		every: number,
		burst: string?,
		count: number?,
		colour: Color3,
		ring: number?,
	}?,
	twinkle: { at: string, every: number, count: number, colour: Color3 }?,
}

Presets.lawn = {
	within = 40,
	step = 0.25,
	pieces = {
		lamp_post = {
			emitter = { name = "lawnFireflies", at = "_Bulbs", offset = Vector3.zero, night = true },
		},
		bird_bath = {
			pulse = {
				offset = Vector3.new(0, 1.72, 0),
				every = 3.5,
				colour = Presets.palette.milk,
				ring = 1.2,
			},
		},
		garden_gnome_cat = {
			light = {
				offset = Vector3.new(0, 0.45, -0.38),
				colour = Presets.palette.lampWarm,
				range = 5,
				brightness = 1,
				night = true,
			},
		},
		little_fountain = {
			emitter = { name = "fountainDrops", offset = Vector3.new(0, 2.05, 0) },
			pulse = {
				offset = Vector3.new(0, 0.66, 0),
				every = 2.5,
				colour = Presets.palette.milk,
				ring = 2.8,
			},
			light = {
				offset = Vector3.new(0, 0.9, 0),
				colour = Presets.palette.pastelSky,
				range = 8,
				brightness = 0.8,
				night = true,
			},
		},
		balloon_bunch = {
			pulse = {
				at = "_Balloons_Swing",
				offset = Vector3.zero,
				every = 5,
				burst = "decorGlint",
				count = 3,
				colour = Presets.palette.sparkle,
			},
		},
		fairy_light_arch = {
			emitter = { name = "lawnFireflies", at = "_Bulbs", offset = Vector3.zero, night = true },
			twinkle = { at = "_Bulbs", every = 0.5, count = 2, colour = Presets.palette.lampWarm },
		},
		flower_cart = {
			emitter = { name = "decorPetals", at = "_Flowers", offset = Vector3.new(0, 0.5, 0) },
		},
		cat_tree_sign = {
			pulse = {
				at = "_Star_Spin",
				offset = Vector3.zero,
				every = 4,
				burst = "crownGlint",
				count = 4,
				colour = Presets.palette.golden,
			},
			twinkle = { at = "_Bulbs", every = 0.8, count = 2, colour = Presets.palette.lampWarm },
		},
		golden_paw_statue = {
			emitter = { name = "goldMote", at = "_Paw_Spin", offset = Vector3.zero },
			pulse = {
				at = "_Paw_Spin",
				offset = Vector3.zero,
				every = 6,
				burst = "crownGlint",
				count = 5,
				colour = Presets.palette.golden,
			},
		},
		-- #3222 rare Golden drops: each spins (the `_Spin` contract) and glints like the Golden Paw Statue
		golden_cat_fountain = {
			emitter = { name = "goldMote", at = "_Cat_Spin", offset = Vector3.new(0, 1, 0) },
			pulse = {
				at = "_Cat_Spin",
				offset = Vector3.new(0, 1.2, 0),
				every = 5,
				burst = "crownGlint",
				count = 5,
				colour = Presets.palette.golden,
			},
			twinkle = { at = "_Bulbs", every = 0.8, count = 2, colour = Presets.palette.lampWarm },
		},
		golden_cat_throne = {
			emitter = { name = "goldMote", at = "_Crown_Spin", offset = Vector3.zero },
			pulse = {
				at = "_Crown_Spin",
				offset = Vector3.zero,
				every = 4,
				burst = "crownGlint",
				count = 5,
				colour = Presets.palette.golden,
			},
			twinkle = { at = "_Bulbs", every = 0.6, count = 2, colour = Presets.palette.lampWarm },
		},
		golden_yarn_kitten = {
			emitter = { name = "goldMote", at = "_Yarn_Spin", offset = Vector3.zero },
			pulse = {
				at = "_Yarn_Spin",
				offset = Vector3.zero,
				every = 6,
				burst = "crownGlint",
				count = 5,
				colour = Presets.palette.golden,
			},
			twinkle = { at = "_Bulbs", every = 0.5, count = 3, colour = Presets.palette.lampWarm },
		},
	} :: { [string]: LawnSpec },
}

-- The cafe themes' touches (Effects/Themes, #1624). The Grand Cafe's chandelier (`asset`): a PointLight in `colour`
-- `below` studs under its flames' centre, `brightness` and `range`, flickering by up to `flicker` of its brightness
-- every `flickerEvery` seconds, and `glints` sparkles on a flame of the `radius`-stud ring about every `glintEvery`
-- seconds. The nearest `most` within `within` studs, checked every `step` seconds.
Presets.themes = {
	step = 0.05,
	chandelier = {
		asset = "CatCafe_Plot_ThemeGrandChandelier",
		within = 60,
		most = 2,
		colour = Color3.fromRGB(255, 196, 120),
		below = 0.2,
		range = 14,
		brightness = 0.9,
		flicker = 0.18,
		flickerEvery = { 0.07, 0.16 },
		glintEvery = 2.5,
		glints = 2,
		radius = 1,
	},
}

-- The pity cat (Effects/Pity, #1572 luck-and-rare-moments.md 1h). As one appears: `beams` beams (Particles.beam)
-- `width` wide and `height` tall in `colours`, `spread` studs round it, for `seconds`, and `sparkles` ding sparkles
-- `lift` studs over it; only within `within` studs. When it is caught in another server or goes: a `puff` of smoke,
-- gold sparkles and a ring. A removal up to `lateSeconds` before the announcement still puffs where the cat stood;
-- positions are tracked every `track` seconds.
-- The outfit passes' thank-you (#2147, store-pass-looks.md 7.3, Effects/PassThanks): one short bow-pink sparkle of
-- `sparkles` (twice, in `colours`) and a small `ring` over each of your working cats within `within` studs (the
-- nearest `most`), `gap` seconds apart, at the Head's BubbleAnchor or `over` studs over the pivot.
Presets.passThanks = {
	within = 120,
	most = 16,
	gap = 0.08,
	over = 3,
	sparkles = 6,
	colours = { Presets.palette.neonPink, Presets.palette.furRose },
	ring = 2.4,
	ringSeconds = 0.4,
	ringBelow = 0.4,
}

Presets.pity = {
	within = 300,
	seconds = 3,
	lift = 2,
	track = 0.5,
	lateSeconds = 3,
	legendary = {
		beams = 1,
		width = 1.6,
		height = 40,
		spread = 0,
		sparkles = 14,
		colours = { Presets.palette.golden },
	},
	mythical = {
		beams = 3,
		width = 1.2,
		height = 48,
		spread = 0.9,
		sparkles = 20,
		colours = { Presets.palette.golden, Presets.palette.aurora, Presets.palette.goldLight },
	},
	puff = {
		smoke = 10,
		sparkles = 12,
		colour = Presets.palette.golden,
		ring = 4,
		ringSeconds = 0.5,
	},
	-- The lasting mark under a pity stray while it is out (#2099, luck-and-rare-moments.md 1j): a soft ring on the
	-- floor `ring` times the cat's width across (at least `minDiameter`), its stroke `stroke` studs wide, breathing
	-- from `breath[1]` to `breath[2]` of its size over `breathSeconds` and back; still with Reduce Motion or Low
	-- performance. One small sparkle puff of `sparkles` every `sparkleEvery` s, `sparkleLift` up (none with either).
	-- Drawn within `within` studs.
	mark = {
		within = 150,
		ring = 1.6,
		minDiameter = 3.5,
		stroke = 0.3,
		halo = 0.5,
		transparency = 0.15,
		haloTransparency = 0.7,
		pixelsPerStud = 32,
		lift = 0.06,
		breath = { 0.9, 1 },
		breathSeconds = 2,
		sparkleEvery = 1.5,
		sparkles = 1,
		sparkleLift = 1.2,
		legendary = Presets.palette.golden,
		mythical = Presets.palette.aurora,
	},
}

-- Catch v3 (catch-rework.md section 7, #1892; Logic.catchReact, Logic.netWrap, Logic.moodLayer, Effects/CatchReact):
-- how the cat answers each judged ring, in degrees and seconds. perk on a hit, wriggle on a Miss, swat on a tapped
-- paw ring (the paw flicks up by `up` of the way through and is back down by the end, staying up until `hold`). wrap:
-- the net closes from `open` to `snug` times the cat's size over `settle` of the `seconds` and rocks `roll` degrees
-- `wobbles` times, the cat hunkering `sink` into it; `seconds` matches VFX-Agent's Presets.catchFinish.wrap, so the
-- finish pop lands as the wobble ends. mood: the Curious head tilt and the Skittish crouch on a stray's idle,
-- easing in over `ease` seconds. None of it with Reduce Motion, except the net, which closes without rocking.
Presets.catchReact = {
	perk = { seconds = 0.45, ears = 18, nose = 8, lean = 6, tailUp = 20 },
	wriggle = { seconds = 0.7, wriggles = 3, roll = 12, head = 10, tail = 30, ears = 30 },
	swat = { seconds = 0.45, up = 0.25, hold = 0.45, paw = 70, rear = 8, lean = 6, ears = 45 },
	wrap = {
		seconds = 0.6,
		settle = 0.25,
		wobbles = 2,
		roll = 10,
		sink = 0.35,
		ears = 35,
		open = 1.5,
		snug = 1.08,
		color = Color3.fromRGB(245, 236, 214),
		transparency = 0.35,
	},
	mood = {
		ease = 0.4,
		curious = { tilt = 14, seconds = 2.4, tailUp = 25, ears = 10 },
		skittish = { crouch = 0.35, headDown = 10, tailDown = 15, ears = 25 },
	},
}

-- The net pinning a caught stray (#2005 section 1, NetPin.luau), the catcher's net upside down over the cat while it
-- has NetDown. `ring`: the hoop's radius over the cat's half diagonal across the floor; `cover`: the bag's depth over
-- the cat's height; `maxScale` caps it for a big cat. Drop: from `height` studs up over `seconds`, falling. Lift: up
-- `height` studs over `seconds`, fading out from `fadeFrom` of the way.
Presets.netPin = {
	ring = 1.1,
	cover = 1.05,
	maxScale = 4,
	drop = { height = 1.6, seconds = 0.18 },
	lift = { height = 2.2, seconds = 0.35, fadeFrom = 0.3 },
}

-- The bedtime walk drawn on each client (#2050, BedWalk.luau): when the trip ends the copy fades out over `fade`
-- seconds as the server's model, landed on the bed or back at its station, fades in.
-- A cafe cat walking to its new spot when it changes spot (#2050, Effects/SlotWalk): only for a model whose Uid left
-- the same plot's Cats at most `window` seconds before and that lands at least `minStuds` away and no more than
-- `maxRise` up or down (not onto the counter or a cat tree); it trots at `speed`
-- (faster when the way is long, so it arrives within `maxSeconds`), turns `turn` degrees a second, and the copy
-- cross-fades with the new model over `fade` seconds once it is there.
Presets.slotWalk = {
	window = 1.5,
	minStuds = 2,
	maxRise = 2, -- a nap bed's cushion, not the counter top (3) or a cat tree (4.5)
	speed = 7,
	maxSeconds = 4,
	turn = 540,
	fade = 0.25,
	-- #2050 (Desktop-Tester 2026-11-07: walkers drawn at the world origin and far below the floor): a found way is
	-- only taken when every waypoint lies within `detour` studs of the straight line and `waypointRise` of the floor;
	-- the copy walks straight once `planWait` seconds pass without one, and is let go (the cat just shows at its new
	-- spot) if it is ever drawn further than `detour` from that line
	detour = 24,
	waypointRise = 8,
	planWait = 0.4,
}

Presets.bedWalk = { fade = 0.25 }

-- #5172 the cat follower (Effects/Follower): how fast the drawn speed and climb follow the floor (a second's share
-- a frame times dt), the most speed the legs show, the climb (studs a second) that reads as a full hop, the hop's
-- nose-up pitch and legs out (degrees), and the puff where it pops in (smokePuff particles, studs over its feet).
Presets.follower = {
	speedEase = 10,
	speedMax = 30,
	hopClimb = 12,
	hopPitch = 12,
	hopReach = 35,
	hopTrail = 30,
	puff = 6,
	puffHeight = 0.8,
}

-- The Desert and the Ruins (Tier 6 and 7, #2657; tier6-7-areas.md sections 4 and 5). While you are inside an area's
-- box (Config.World's Desert* and Ruins* centre and size, #2655, plus `pad` studs) its `air` emitter fills a `box` of air round you
-- (`Presets.emitters`, the budget's rateScale; a fifth of the rate with Reduce Motion, none in Low performance).
-- A stray of the area puffs `puff` `puffPreset` particles in `colour` where it appears and where it leaves the ground,
-- within the budget's animRadius, at most the budget's areaPuffs in any one second (#2661). In the Ruins, falling `mistDepth` studs below the plateau puffs `mist` violet-grey
-- mist round you once, before the server's catch moves you to the camp pad.
-- #4069: ribbons of northern light over an area while it is night and you are in it. Each ribbon is two soft bands
-- (`foot` colour under `top` colour) `width` studs tall, hung `height` studs over the ground along the area's longer
-- side and spread over its shorter one, each bending `curve` of its length (at most `curveMost` studs) to one side and slowly over to the other in its
-- `seconds` and back. Each band wears the soft smoke picture stretched once along it, so it fades out toward its
-- edges and ends and never shows a hard stripe. They fade in and out over `fade` seconds. With Reduce Motion they hang still; none in Low
-- performance. `ribbons` is per budget tier (high, medium, low).
export type AuroraSpec = {
	ribbons: { number },
	-- #4687: each ribbon is a curtain of upright rays side by side along it, each one Beam from its foot up
	columns: { number }, -- rays a ribbon by tier (high, medium, low)
	tall: number, -- studs a ray reaches up from the foot
	tallVary: number, -- of `tall`, how much the rays' tops rise and dip along the curtain, a slow wave
	footVary: number, -- studs the rays' feet rise and dip, ray to ray, so the foot is no straight edge
	wide: number, -- each ray's width as a share of the gap between rays: over 1 they overlap into one curtain
	sway: number, -- studs a ray's middle bows side to side as it sways
	bright: number, -- Beam.Brightness
	foot: Color3, -- the curtain's colour at its foot, then `middle`, then `top`
	middle: Color3,
	top: Color3,
	height: number,
	window: number, -- studs across your look the ribbons' box is wide: they run over 0.8 of it, side to side
	deep: number, -- studs front to back the ribbons are spread over, centred `ahead` of you
	ahead: number, -- studs out the way the camera looks, laid flat
	recentre: number, -- the window moves once you are this far from where it was centred for
	glide: number, -- seconds it takes to move
	spread: number, -- of the area's shorter side the ribbons are spread over (over 1: the outer ones hang past its walls)
	rise: number, -- studs each ribbon hangs above the one in front
	curve: number,
	curveMost: number,
	seconds: { number },
	shown: number, -- a ray's transparency just over its foot when fully shown; it fades to nothing going up
	fade: number,
}
export type AreaFxSpec = {
	air: string,
	colour: Color3,
	puffPreset: string,
	puff: number,
	mist: number?,
	mistColour: Color3?,
	mistDepth: number?,
	lift: number?, -- the air box's centre over your feet, where the area's own differs (snow falls from higher)
	-- #4069: a little puff of `footPreset` in `footColour` at your feet for every `footStuds` you walk on the ground
	footPuff: number?,
	footPreset: string?,
	footColour: Color3?,
	footStuds: number?,
	aurora: AuroraSpec?, -- northern lights over the area at night
}
Presets.areaFx = {
	pad = 40, -- the camp lies outside the floor box, and the server's mist catch reaches 40 studs past it
	box = Vector3.new(36, 10, 36),
	lift = 3, -- the box's centre over your feet
	checkSeconds = 0.5,
	calmRate = 0.2,
	-- Sand off the Desert's dune crests (#2925): while you are in the Desert, the nearest `most[tier]` crests (parts
	-- named ..DuneRidge or ..WallDune in the Desert's area model) within `within` studs blow a `duneSand` plume off
	-- their top, re-picked every `pickSeconds`, the part list re-read every `scanSeconds`. None with Reduce Motion or
	-- in Low performance.
	dunes = {
		names = { "DuneRidge", "WallDune" },
		within = 70,
		most = { low = 2, high = 3 } :: { [string]: number },
		pickSeconds = 2,
		scanSeconds = 10,
		emitter = "duneSand",
	},
	-- the northern lights also hang through this many last seconds of the day: night closes the areas
	auroraEvening = 60,
	areas = {
		desert = {
			air = "desertSand",
			colour = Color3.fromRGB(232, 205, 150),
			puffPreset = "smokePuff",
			puff = 6,
		},
		ruins = {
			air = "ruinsMotes",
			colour = Color3.fromRGB(80, 160, 120),
			puffPreset = "catchSparkle",
			puff = 6,
			mist = 10,
			mistColour = Color3.fromRGB(196, 186, 210),
			mistDepth = 12,
		},
		-- #4069 Snowy Mountain (Tier 8): snow drifting down round you, a white puff where its strays come and go and
		-- small snow puffs under your feet as you walk. The area's box is Config.World's Snowy* once the area is in.
		snowy = {
			air = "snowfall",
			colour = Color3.fromRGB(240, 248, 255),
			puffPreset = "smokePuff",
			puff = 6,
			lift = 6,
			footPuff = 3,
			footPreset = "dust",
			footColour = Color3.fromRGB(246, 250, 255),
			footStuds = 3,
			aurora = {
				ribbons = { 2, 2, 1 },
				-- #4216 Studio look: hung over the whole 560 stud area at 90 studs they sat far off behind the
				-- mountain and the top of the screen. So a window of them keeps ahead of you, lower. Second look: at
				-- 62 studs they were still above what the default camera shows (it looks a little down, and the top
				-- HUD bar covers the rest), so they hang low and further out: 10 to 20 degrees up from where you stand.
				-- Third look: run along the area they were end on to you, thin slivers with faded tips. So they hang
				-- across the way you look, side to side, at about 90, 150 and 210 studs ahead.
				-- Fourth look: the camera at the landing looks along the area's short side, so nothing hung by the
				-- area's sides is sure to be in view. They hang from the camera's own look now, 15 to 30 studs over
				-- your feet: 6 to 14 degrees up, the upper third of the screen.
				height = 20,
				window = 300,
				deep = 80,
				ahead = 150,
				recentre = 90,
				glide = 6,
				spread = 1,
				rise = 6,
				curve = 0.12,
				curveMost = 30,
				seconds = { 21, 27 },
				-- #4687 (Derek 2026-11-16: "redone to look way more like a gentle aurora right now its so bad"): the
				-- old ribbons were thick solid stripes, mint under violet, which read as coloured clouds. First redo
				-- (stacked flat bands) was still stripes in Sync's Studio look: a Beam only fades along its length,
				-- never across its width, so every band had hard top and bottom edges. So the curtain now stands up:
				-- upright rays side by side along each ribbon, each one Beam from its foot to its top, its colour and
				-- see-through running along that length, a soft green foot fading up through teal into a faint violet
				-- top. The rays are wider than the gap between them, so they merge into one curtain with faint streaks
				-- like a real aurora's. Each ray bows a few studs side to side on its own slow clock, so the curtain
				-- ripples, and the tops rise and dip in a slow wave along it. Still no picture (#4085).
				shown = 0.5,
				columns = { 14, 10, 7 },
				tall = 30,
				tallVary = 0.35,
				footVary = 3,
				wide = 1.7,
				sway = 3,
				bright = 1.2,
				foot = Color3.fromRGB(128, 242, 180),
				middle = Color3.fromRGB(110, 214, 214),
				top = Presets.palette.aurora,
				fade = 4,
			},
		},
		-- #4070 the Water Park: fine spray in the air and a splash where its strays come and go. #4071 the Medieval
		-- Castle: warm motes of dust and a gold sparkle for its strays. Their boxes are Config.World's WaterPark* and
		-- Castle* once the areas are in.
		waterpark = {
			air = "waterparkSpray",
			colour = Color3.fromRGB(150, 220, 250),
			puffPreset = "splashDrops",
			puff = 6,
			lift = 4,
		},
		castle = {
			air = "castleMotes",
			colour = Color3.fromRGB(255, 214, 120),
			puffPreset = "catchSparkle",
			puff = 6,
		},
		-- #4251 Harvest Hollow (area id "harvest"): a pumpkin-orange puff where its strays come and go. The falling
		-- leaves are Effects/HarvestFx's (by the Thankful Board), so Config.World has no Harvest box and `air` here
		-- never starts. Your steps there (no box, so Logic.walkArea goes by the distance to the Thankful Board) kick up a few
		-- dry leaves in amber and play the leaf crunch.
		harvest = {
			air = "harvestLeaves",
			colour = Color3.fromRGB(232, 140, 60),
			puffPreset = "smokePuff",
			puff = 6,
			footPuff = 2,
			footPreset = "dust",
			footColour = Color3.fromRGB(214, 128, 52),
			footStuds = 3,
		},
	} :: { [string]: AreaFxSpec },
}

-- #2687's station build-in (StationBuild.luau): the first time you come into an area whose station you own, its camp
-- station builds in. Every part drops in from above, turning, and snaps into place, bottom to top, fading in as it
-- falls. With Reduce Motion the whole station only fades in.
Presets.stationBuild = {
	-- #3191 (Derek2 2026-11-10: "when landing here the first time the picnic table and stuff load in block at a time
	-- falling from sky", and the Yard Sale the same): off, so every camp station and its growth is simply there on a
	-- first visit; the reveal's burst, sparkle, fanfare and Unlocked card still play
	on = false,
	wait = 4, -- seconds to wait for the station to stream in after the reveal
	spread = 1.8, -- seconds from the first piece starting to the last
	piece = 0.45, -- seconds each piece takes to drop into place
	lift = { 4, 7 }, -- studs above its place a piece starts
	drift = 1.5, -- studs to either side it may start
	tilt = 30, -- degrees it may start turned, about a random axis
	fade = 0.4, -- of its drop, how much it takes to fade in
	calmFade = 0.6, -- seconds the whole station takes to fade in with Reduce Motion
	clunkGap = 0.12, -- seconds at least between stationClunk beats as pieces land (Sound-Agent's clunk set)
}

-- #2687's station reveal burst (StationReveal.luau): the first time you come into an area whose station you own, a
-- gold beam rises off the station, sparkles and confetti burst over it and rings spread at its foot. Studs and
-- seconds.
Presets.stationReveal = {
	wait = 4, -- seconds to wait for the station to stream in after the reveal
	lift = 1, -- studs over the station's top the sparkles and confetti burst
	sparkles = 24,
	confetti = 40,
	colours = { Presets.palette.golden, Presets.palette.goldLight, Presets.palette.offwhite },
	beamWidth = 3,
	beamHeight = 22,
	beamSeconds = 1.8,
	rings = 2,
	ringPad = 2, -- studs the first ring spreads past the station's widest side
	ringGap = 0.3,
	ringSeconds = 1,
}

-- #5112 Effects/StationUnlockCut (Design-Agent's station-unlock-cutscene.md): the cut to a big station a rank up
-- unlocks. Times in seconds from the start: a `fade` to black and back, the station appears at `appearAt` (scales up
-- from `fromScale` over `grow`, drawn at `scaleHz`), the label at `labelAt` (in over `labelIn`), the fade back at
-- `endAt`. The camera stands `far` then `near` times the station's size out (clamped to `nearest`..`farthest` studs),
-- `rise` of that up, `yaw` degrees off the model's front (`faceSign` -1 if a model faces its back), looking `lookUp`
-- of its height up. `smallScreen` px tall or less shrinks the label by `smallScale`.
Presets.stationCut = {
	stations = {
		-- #5112 15:40 UTC: the Town Square's StationTiers stations, a short pan (no stream)
		[3] = {
			tag = "ArcadeCabinet",
			name = "The Cat Arcade",
			line = "Play Mouse Dash for daily prizes",
			locked = true, -- StationTiers: hidden below its tier, shown in full after the cut
		},
		[4] = {
			tag = "MysticPool",
			name = "The Mystic Pool",
			line = "Give each cat a trait that helps it",
			locked = true,
		},
		[8] = {
			tag = "FusionObservatory",
			name = "Fusion Observatory",
			line = "Fuse 5 of one cat into a better coat",
		},
		[9] = {
			tag = "TicketBooth",
			name = "Ticket Booth",
			line = "Catches give tickets for prizes",
		},
		[10] = {
			tag = "DragonKeep",
			name = "Dragon Keep",
			line = "Grow Cinder the dragon for bonus cards",
		},
	} :: { [number]: { tag: string, name: string, line: string, locked: boolean? } },
	fade = 0.2,
	appearAt = 0.4,
	grow = 0.6,
	fromScale = 0.85,
	scaleHz = 20,
	labelAt = 1.2,
	labelIn = 0.25,
	endAt = 4.0,
	skipAfter = 0.3,
	skip = true, -- a tap, click, key or gamepad button can skip it
	cap = 1, -- seconds past the cut's length it always ends by, whatever happens
	-- #5550 cutsQuick (Design, from the 60 to 67% who skip it): about 2 s with no skip, over by 0.5 s after its end.
	-- Only the tiers in `plays` get a scene; the rest get the "Unlocked" toast and no camera move (Derek 2026-11-20
	-- 13:19 UTC: no Cat Arcade scene, the Mystic Pool is the one that matters)
	quick = {
		plays = { [4] = true, [8] = true, [9] = true, [10] = true } :: { [number]: boolean },
		appearAt = 0.3,
		grow = 0.45,
		labelAt = 0.65,
		labelIn = 0.2,
		endAt = 2.0,
		skip = false,
		cap = 0.5,
	},
	far = 1.9,
	near = 1.45,
	nearest = 18,
	farthest = 70,
	rise = 0.35,
	yaw = 35,
	-- Sync's run: the camp stations' area gates stood in the way, so these turns from the front are tried in order and
	-- the first with the camera's whole distance clear wins
	views = { 35, -35, 0, 70, -70, 110, -110, 180 },
	clearance = 2, -- studs the camera keeps short of what is in the way when no view is clear
	closest = 8, -- never nearer than this
	faceSign = 1,
	lookUp = 0.1,
	displayOrder = 11, -- over ContextCut's 10
	titleSize = 64,
	nameSize = 34,
	lineSize = 22,
	titleY = 0.2,
	nameY = 0.31,
	lineY = 0.38,
	smallScreen = 420,
	smallScale = 0.7,
	-- StationReveal's burst, made bigger
	burst = {
		lift = 1,
		sparkles = 40,
		confetti = 60,
		beamWidth = 4.5,
		beamHeight = 32,
		beamSeconds = 2.2,
		rings = 2,
		ringPad = 3,
		ringGap = 0.3,
		ringSeconds = 1.2,
	},
}

-- #5284 Cat Companion unlock scene (Effects/CompanionUnlockCut), about 8 s: fade in, the camera `far` studs in front
-- of the player rising `rise` a stud, pushing in to `near`; the cat trots in from `walkFrom` studs to the player's right
-- (and `walkIn` toward the camera) to `beside` studs beside them, from `walkAt` over `walkSeconds`; hearts `heartsUp`
-- over it as it stops; the label from `labelAt`; the fade out at `endAt`. Skippable after `skipAfter`.
Presets.companionCut = {
	fade = 0.25,
	walkAt = 0.6,
	walkSeconds = 2.8,
	labelAt = 3.7,
	labelIn = 0.3,
	endAt = 7.4,
	skipAfter = 0.4,
	skip = true, -- a tap, click, key or gamepad button can skip it
	cap = 1, -- seconds past the scene's length it always ends by, whatever happens
	-- #5550 cutsQuick (Design, from the 79% who skip it): about 3 s with no skip and a shorter line, the cat trotting
	-- in from nearer; over by 0.5 s after its end
	quick = {
		fade = 0.2,
		walkAt = 0.3,
		walkSeconds = 1.3,
		walkFrom = 6,
		labelAt = 1.5,
		labelIn = 0.2,
		endAt = 3.0,
		skip = false,
		cap = 0.5,
		line = "%s follows you now!",
		lineNoName = "Your cat follows you now!",
	},
	far = 12,
	near = 9,
	rise = 0.22,
	lookUp = 1.6, -- studs over the feet the camera looks at, between the player and the cat
	clearance = 1.5,
	closest = 5,
	beside = 3,
	walkFrom = 11,
	walkIn = 2,
	heartsUp = 0.6,
	title = "CAT COMPANION UNLOCKED!",
	line = "%s will follow you. Pick Money or Luck in Cats.",
	lineNoName = "Your cat will follow you. Pick Money or Luck in Cats.",
	displayOrder = 11, -- over ContextCut's 10, as the station cut
	titleSize = 56,
	nameSize = 34,
	lineSize = 22,
	titleY = 0.2,
	nameY = 0.31,
	lineY = 0.38,
	smallScreen = 420,
	smallScale = 0.7,
}

-- #2687's townsfolk cats (Townsfolk.luau), Model-Agent's CatCafe_NPC_Townsfolk_* sitting round a grown camp: an idle
-- of head turns, ear flicks and a swaying tail, and a greet (head turned to you, a paw lifted and waved) as you come
-- near. Off with Reduce Motion.
Presets.townsfolk = {
	lookYaw = 18, -- degrees the head wanders either way
	lookPitch = 5, -- degrees it nods
	tailYaw = 16, -- degrees the tail sways either way
	tailHz = 0.45,
	flick = { every = { 3, 7 }, seconds = 0.3, degrees = 28 }, -- an ear twitch now and then
	greetRadius = 14, -- studs: coming this near starts a greet
	greetAgain = 25, -- seconds before the same cat greets you again
	turn = 4, -- how fast the head eases to where it looks (1 / seconds)
	followLimit = 60, -- degrees the head turns to follow you while you are near
	wave = { up = 0.3, wave = 1.2, waves = 3, lift = 75, side = 22 },
}

-- The Tier 6 and 7 stations (#2925, late-stations.md sections 1 and 2; Effects/LateStationFx). The Oasis Spa's
-- `spaSteam` rises off its `Steam` attachment (else over its `_Water` part) within the budget's ambientRadius, still
-- with Reduce Motion and off in Low performance. A cat put in splashes a `splashRing` stud ring and `splash` droplets
-- on the pool; a collect sends `levelUp` gold sparkles up off it for each cat relaxed, at most `levelUpMost` bursts.
-- A Relic Museum donation pops `donate` gold sparkles at the `SparkleAnchor` (the golden idol case); one that
-- finishes a room adds confetti (`roomConfetti` of the budget's), a `roomRing` stud gold ring and a gold beam
-- `beamWidth` wide and `beamHeight` tall for `beamSeconds`. Bursts play within the budget's animRadius.
-- Crumbs off the bowl while the first bait cat eats (#2946; Effects/BaitCrumbs): `count` `preset` crumbs `lift` studs
-- over the bowl every `gap` seconds for the eating's length, at most `most` seconds.
Presets.baitCrumbs = {
	preset = "potionQuickBait",
	count = 3,
	lift = 0.4,
	gap = 0.35,
	most = 4,
}

-- Bowl Frenzy at your bait bowl (#4195; Effects/BowlFrenzyFx): every `every` seconds while the frenzy runs, `count`
-- gold `preset` sparkles pop `lift` studs over the food in each of your bowls whose cat is still on the way, and every
-- `ringEvery`th pop a `ring` stud gold ring spreads from it; within `within` studs, checked every `check` seconds.
-- Low performance: every `lowEvery` seconds, `lowCount` sparkles, no ring. `folders` are CafeService's bowl folders.
Presets.bowlFrenzy = {
	folders = { "Bait", "Bait2" },
	preset = "catchSparkle",
	count = 5,
	lowCount = 2,
	lift = 0.6,
	every = 1.2,
	lowEvery = 3,
	ringEvery = 3,
	ring = 5,
	within = 80,
	check = 0.3,
}

-- The stray waiting for your second cat (#3022; Effects/WaitingCat): `emitter` sparkles rise off it and a `ring` stud
-- gold ring pulses out at its feet every `ringEvery` seconds, from `delay` seconds after it shows for `seconds`, then
-- every `calmEvery` seconds until it is caught (#3238: it used to stop at `seconds`), within `within` studs, checked
-- every `check` seconds. `marker` is the gold paw over it, drawn through walls within `marker.within` studs (#3238:
-- only 51 of 139 players reached the second cat's trail). `attribute`, `delay` and `seconds` are shared/SecondCat's
-- when it is in.
-- #4384 (one ask at a time after the first check-in): while the player's tutorialStep is `holdStep` (the bowl step)
-- the beacon, the call and its sound wait, so the Bait bowl is the only ask (always, since #4654 retired its switch).
-- Only once the player owns the Bait bowl (upgrade `holdUpgrade`): one who cannot buy it yet keeps the beacon to the
-- free second cat. And for `holdMost` seconds at most, so nobody is left with no next step.
Presets.waitingCat = {
	attribute = "WaitsFor",
	holdStep = 4,
	holdUpgrade = "lure_bowl",
	holdMost = 180,
	delay = 2,
	seconds = 120,
	within = 400,
	check = 0.25,
	emitter = "waitBeacon",
	ring = 10,
	ringSeconds = 1.1,
	ringEvery = 1.6,
	calmEvery = 4,
	marker = {
		within = 700, -- studs: from the cafe's front door to the far end of the alley
		lift = 2.5, -- studs over the cat's head
		studs = 3.2, -- the badge's size in the world, so it shrinks with distance
		pixels = 26, -- and this many pixels more, so it never vanishes when far
		bob = 0.6, -- studs up and down
		seconds = 1.4, -- one bob
		glyph = "🐾",
	},
}

-- Effects/FirstMinuteFx: the first bowl cat card's sparkle and the first net catch's cheer.
Presets.firstMinute = {
	card = {
		wait = 0.35, -- the card pops in first
		displayOrder = 36, -- over the bait card (35), under the cat found reveal (40)
		sparks = 10,
		sparkle = { size = 14, seconds = 0.6, reach = 46, stagger = 0.15 },
		rings = 2,
		ringEvery = 0.25,
		ringGrow = 2.2,
		ringSeconds = 0.6,
		colour = Color3.fromRGB(255, 214, 92),
	},
	cheer = {
		confetti = 0.75, -- of the budget's confetti, from each side
		side = 3,
		up = 3,
		sparkle = 12,
	},
}

-- #5285 E2 Effects/FirstCatchWow: the account's first net catch, under 1.5 s (switch firstCatchWow). Times in seconds
-- from the catch landing; `push` is the share of the way the camera moves toward the cat.
Presets.firstCatchWow = {
	slowSeconds = 0.25,
	slowSpeed = 0.3, -- your animations at 30% speed for the slow motion
	push = 0.15,
	pushIn = 0.25,
	popAt = 0.25,
	ringScale = 2, -- times the rarity's catch ring (Presets.catchPop.ring)
	ringSeconds = 0.6,
	confetti = 1, -- of the budget's confetti; half on a phone or the low tier
	colours = {
		Presets.palette.golden,
		Presets.palette.sparkle,
		Presets.palette.offwhite,
		Presets.palette.blush,
	},
	coins = 30, -- about three times a normal pay out's coins
	coinSeconds = 0.7,
	coinStagger = 0.012,
	coinSpread = 90, -- pixels the coins fly out from the cat before they turn to the counter
	coinLift = 40,
	coinMin = 22,
	bannerAt = 0.3,
	bannerIn = 0.15,
	bannerOut = 0.25,
	bannerEnd = 1.3,
	bannerTop = 40, -- pixels from the top when the catch strip is not there
	popFrom = 0.6,
	text = "FIRST CATCH!",
	textShare = 0.065, -- of the screen's height
	textMin = 26,
	textMax = 52,
	gold = Presets.palette.golden,
	ink = Color3.fromRGB(74, 46, 30), -- the menus' cocoa brown, for the outline
	panel = Color3.fromRGB(74, 46, 30),
	panelTransparency = 0.2,
	backAt = 1.3,
	backSeconds = 0.18,
	displayOrder = 26, -- over the catch screen (25), under toasts (30)
}

-- #4920 Effects/RankUpPulse: the RANK UP button's glows when a tier's rank up is first ready, and the strip's tick.
Presets.rankUpPulse = {
	displayOrder = 29, -- over the HUD and windows, under toasts (30)
	wait = 0.35, -- the Rank Up window slides in first
	look = 0.5, -- seconds between looks for a RANK UP button once a tier's rank up is ready
	lookFor = 120, -- and for how long (the window waits for a calm screen; a later flip looks again)
	pulses = 3,
	every = 0.55,
	seconds = 0.7,
	grow = 26, -- pixels the glow swells past the button
	corner = 14,
	thickness = 4,
	fill = 0.35, -- the glow's own fill at its start (0 none)
	colour = Color3.fromRGB(255, 214, 92),
	sparkle = { size = 12, seconds = 0.5, reach = 34, stagger = 0.1 },
	tick = {
		sparks = 6,
		sparkle = { size = 9, seconds = 0.45, reach = 26, stagger = 0.06 },
		ringFrom = 8,
		ringTo = 44,
		ringSeconds = 0.4,
	},
}

-- Effects/CannonCue (Design-Agent 2026-11-17, the phone drop between the bowl cat's tame and Tier 2's rank up): one
-- gold glow (rankUpPulse's look) on the HUD's Cannon button every `every` seconds while Tier 2 is short of cats and
-- the player is in the hometown, until the button is pressed. Behind `flag`, off.
Presets.cannonCue = {
	flag = "cannonCue",
	every = 4,
	calmEvery = 8, -- with Reduce Motion
}

-- The first catch's held ring (#2920; Effects/HoldPulse): gold rings swell off it every `gap` seconds (under 3 Hz)
-- from `from` to `to` times its size while it waits for the press, for at most `most` seconds.
Presets.holdPulse = {
	displayOrder = 26, -- just over the catch screen (25), under toasts (30)
	gap = 0.9,
	from = 1,
	to = 1.7,
	seconds = 0.7,
	most = 60, -- Config.FirstRingHoldSeconds
}

Presets.lateStations = {
	steamPreset = "spaSteam",
	water = "_Water",
	splash = 6,
	splashRing = 6,
	splashColour = Color3.fromRGB(64, 168, 160), -- the oasis teal (tier6-7-areas.md section 4)
	levelUp = 8,
	levelUpMost = 3,
	levelUpGap = 0.3,
	donate = 10,
	roomConfetti = 0.6,
	roomRing = 8,
	beamWidth = 1.2,
	beamHeight = 14,
	beamSeconds = 1.2,
}

-- The Ticket Booth's buy moment (#4061; Effects/BoothFx): paper tickets in the booth's own red, cream and gold off
-- the `anchor` attachment of the `tag`-tagged model (else `under` of its height above its middle), `tickets` of the
-- device's confetti budget, `sparkles` gold sparkles and one gold ring `ring` studs wide at its feet.
Presets.boothFx = {
	tag = "TicketBooth",
	anchor = "BangAnchor",
	under = 0.2,
	tickets = 0.5,
	sparkles = 8,
	ring = 7,
	colours = { Presets.palette.shirtRed, Presets.palette.cream, Presets.palette.golden },
}

-- The advent calendar board (#5502, Effects/AdventFx): opened doors swing `openAngle` out to the front over
-- `swingSeconds` with `overshoot`; the ready door breathes gold every `breathe` seconds (fill from `fillLow` to
-- `fillHigh`, `fillCat` on a cat door); an open bursts `sparkles` (`catSparkles`), `snow` flakes and `confetti` of the
-- budget; a cat door adds a ring, a column of light and a nook light for `catSeconds`. `catDoors` match shared/Advent.
Presets.adventFx = {
	flag = "adventCalendar",
	board = "CatCafe_Square_AdventBoard",
	doors = 24,
	catDoors = { 6, 12, 18, 24 },
	openAngle = math.rad(105),
	swingSeconds = 0.55,
	overshoot = 0.17,
	breathe = 1.6,
	fillLow = 0.15,
	fillHigh = 0.4,
	fillCat = 0.6,
	sparkles = 10,
	catSparkles = 24,
	snow = 8,
	confetti = 0.4,
	colours = { Presets.palette.shirtRed, Presets.palette.cream, Presets.palette.golden },
	gold = Presets.palette.golden,
	ring = 4,
	ringDrop = 1.5,
	beamWidth = 1.2,
	beamHeight = 10,
	catSeconds = 3,
	lightBrightness = 3,
	lightRange = 8,
	lookSeconds = 2,
}

-- The new start's camp pay moment (#5533 v2, Effects/CampCoinFly): at the first `checkIns` camp check-ins of a session,
-- `coins` coins arc from the camp to the money counter (FirstCatchWow's flight numbers), the counter bounces to
-- `bounce` times over `bounceSeconds`, and a "+12/s" line pops in at `pop` times under it, settles by `settle` and
-- fades over its last `fade` of `rateSeconds`. `waitSync` lets the check-in's own sync bring the new rate first.
Presets.campCoinFly = {
	checkIns = 3,
	waitSync = 0.25,
	coins = 14,
	coinSeconds = 0.7,
	coinStagger = 0.02,
	coinSpread = 70,
	coinLift = 40,
	coinMin = 22,
	gold = Presets.palette.golden,
	ink = Color3.fromRGB(92, 64, 51),
	bounce = 1.18,
	bounceSeconds = 0.3,
	pop = 1.6,
	settle = 0.25,
	fade = 0.5,
	rateSeconds = 2,
	lineGap = 4,
	lineWidth = 120,
	lineHeight = 28,
	gui = "EffectsCampCoinFly",
	displayOrder = 26,
}

-- The new start's world glows (#5533 v2, Effects/WorldGlow), Cozy Cream gold: a stall glow lasts `stallSeconds`,
-- breathing every `breathe` seconds down to `low`; the steady glows (the cannon, the door while carrying) dip by
-- `steadyDip` every `steadyPeriod` seconds. A Highlight fills to `fill` and outlines to `outline`; the door's panel
-- shows at `panel` with a light. The cannon's sign is `signWidth` by `signHeight` studs, `signLift` over the cannon.
Presets.worldGlow = {
	stallFlag = "stallGlow",
	cannonFlag = "cannonGlow",
	carryFlag = "freeStart",
	cannonAttribute = "CannonGlowArea",
	firstCamp = "alley",
	campReach = 200, -- studs: the camp cannon lights with the Town Square's while the player is this near it -- the camp the new start lands at, when the character is not there yet
	ringBright = 2, -- added to a walk-up ring's SurfaceGui Brightness at full glow
	ringFill = 0.45, -- a walk-up ring's disc at full glow (its own is 0.82)
	stallSeconds = 6,
	breathe = 1.5,
	low = 0.35,
	steadyDip = 0.25,
	steadyPeriod = 2.4,
	fill = 0.45,
	outline = 0.9,
	panel = 0.45,
	panelDepth = 0.15,
	lightRange = 10,
	lightBrightness = 1.5,
	gold = Presets.palette.golden,
	cream = Presets.palette.cream,
	ink = Color3.fromRGB(92, 64, 51),
	signWidth = 7,
	signHeight = 2,
	signLift = 2.5,
	signDistance = 140,
	lookSeconds = 0.25,
	areaNames = {
		alley = "Alleyway",
		park = "Park",
		neighbourhood = "Neighbourhood",
		woods = "Woods",
		sewer = "Sewer",
		desert = "Desert",
		ruins = "Ruins",
	} :: { [string]: string },
}

-- The Relic Museum's room names (#3129; Effects/MuseumPlaques, Logic.plaqueGlow): a finished room's plaque letters
-- turn Neon `gold` (the room-complete burst's gold) and breathe to `bright` and back every `every` seconds, well
-- under 3 Hz. `suffix` plus the area id ends the name of each plaque's Model in the museum; `rate` is the seconds
-- between colour steps and `lookSeconds` between looks for a museum that streamed back in.
Presets.museumPlaques = {
	suffix = "_Plaque_",
	gold = Presets.palette.golden,
	bright = Color3.fromRGB(255, 226, 130),
	every = 2.6,
	rate = 1 / 12,
	lookSeconds = 2,
}

-- The Oasis Spa's soaking cats and the Relic Museum's new exhibits (#2897; Effects/StationMotion, Logic.soakBob,
-- Logic.dropBounce). Degrees for the turns; the hop and the bob are studs on a cat at the pool's 0.6 scale.
Presets.stationMotion = {
	rate = 1 / 30, -- seconds between moves of the pool's cats
	bob = 0.07, -- studs up and down as the cat floats
	bobHz = 0.4,
	sway = 3, -- degrees of side-to-side roll
	swayHz = 0.18,
	yaw = 6, -- degrees the cat slowly looks left and right
	yawHz = 0.09,
	readyEvery = 3.5, -- a finished soaker's happy wiggle: every 3.5 s (well under 3 Hz)
	readyLength = 0.7,
	readyHop = 0.2,
	readyWiggle = 9, -- degrees of the wiggle's quick turns
	readySparkle = 4, -- a few gold sparkles over its head, every readySparkleEvery
	readySparkleEvery = 7,
	rippleEvery = 5, -- a ring spreading on the water from each cat
	ripple = 2.4, -- the ring's width, studs
	rippleSeconds = 1.6,
	dropHeight = 1.6, -- a new exhibit drops this far onto its plinth
	dropSeconds = 0.55,
	dropFall = 0.62, -- of dropSeconds spent falling; the rest is one small bounce
	dropBounce = 0.16, -- the bounce's height, as a share of dropHeight
	dropRing = 3, -- a gold ring on the plinth as it lands
	dropSparkle = 5,
}

-- The Ruins' waterfall by the cat colossus and the running fountain (#3257, Effects/RuinsWater): a Model whose name
-- ends in one of `suffixes` holds the water parts. A part at least `sheetHeight` studs tall and at most `sheetThin`
-- thin across is a falling sheet: streaks run down through it and mist rises at its foot (feet closer than `merge`
-- studs share one mist); a ring `ring` studs wide spreads there every `rippleEvery` seconds. Only the nearest
-- budget.waterfalls within `within` studs run, chosen every `pick` seconds. Reduce Motion keeps the streaks and mist
-- without the rings; Low performance keeps the streaks only.
Presets.ruinsWater = {
	suffixes = { "_Waterfall_Water", "_Fountain_Water" },
	sheetHeight = 3,
	sheetThin = 0.5,
	merge = 2,
	within = 160,
	pick = 1,
	streaks = "fallStreaks",
	mist = "fallMist",
	mistLift = 0.3,
	ring = 3.5,
	ringSeconds = 1.2,
	rippleEvery = 1.4,
	colour = Presets.palette.milk,
}

-- The new areas' still water (Effects/AreaWater; #4070 the Water Park, #4071 the Castle's moat and well). A water
-- piece is a Model whose name holds one of `sets` and ends `_Water` (Model-Agent's names are
-- `<Set>_<nnn>_<Piece>_Water`, so the piece is found in the name, never by its number). Each kind, the first whose
-- `piece` the name holds: `glint` an emitter on a thin sheet just over each flat part (the nearest `parts` of them),
-- `flow` the same but drifting round the ring the parts make, `spray` an emitter at the top of each ball (a jet's
-- cap), `mist` soft spray over each part, and a ring spreading on the surface every `ringEvery` seconds, `ring`
-- studs wide. The nearest budget.waterfalls + `extra` pieces within `within` studs run, chosen every `pick`
-- seconds. Reduce Motion drops the rings; Low performance leaves the water as built.
export type AreaWaterKind = {
	piece: string,
	glint: string?,
	flow: string?,
	spray: string?,
	mist: string?,
	parts: number,
	ringEvery: number?,
	ring: number?,
}
Presets.areaWater = {
	sets = {
		"CatCafe_WaterPark_",
		"CatCafe_Castle_",
		"CatCafe_Camp_WaterPark",
		"CatCafe_Camp_Castle",
		"CatCafe_Harvest_", -- #4251: Harvest Hollow's creek
	},
	suffix = "_Water",
	within = 110,
	pick = 1,
	extra = 3,
	lift = 0.06, -- studs over the surface the sheet sits
	inner = 0.7, -- of a disc's width the sheet covers (a square inside the circle)
	window = 36, -- studs: a part wider than this (the moat) gets a sheet this wide that follows you along it
	ringSeconds = 1.3,
	ringInner = 0.3, -- of the part's shorter side: how far from its middle a ring may start
	colour = Presets.palette.milk,
	kinds = {
		{ piece = "LazyRiver", flow = "riverFoam", parts = 8 },
		{ piece = "SplashPad", spray = "padSpray", parts = 8, ringEvery = 1.6, ring = 2.4 },
		{ piece = "SlideTower", mist = "fallMist", parts = 2, ringEvery = 1.4, ring = 3.2 },
		{ piece = "WavePool", glint = "poolGlint", parts = 1, ringEvery = 1.1, ring = 4.5 },
		{ piece = "KidsPool", glint = "poolGlint", parts = 1, ringEvery = 2.2, ring = 2.6 },
		{ piece = "Moat", glint = "poolGlint", parts = 2, ringEvery = 2.2, ring = 3 },
		{ piece = "Well", glint = "wellGlint", parts = 1, ringEvery = 3.5, ring = 1.2 },
		-- #4251: Harvest Hollow's creek is a run of small plates, so the well's small glints on the nearest few
		{ piece = "Creek", glint = "wellGlint", parts = 4, ringEvery = 3, ring = 1.4 },
	} :: { AreaWaterKind },
}

-- The fairground's bulbs chase at night (Effects/BulbChase, #4070 "ride lamps chase slowly"). A `_Bulbs` Model whose
-- name holds one of `pieces` runs a chase, by day and by night: every `gap`th bulb wears a brighter Neon cover `grow`
-- times its size, and the lit ones step along the row (or round the frame) `hz` times a second, so any one bulb
-- lights once every gap / hz seconds, well under one flash a second. The nearest `most` rows within `within`
-- studs (`mostLite` on the lite budget), chosen every `pick` seconds; `hzDay` steps a second by day; none with Reduce Motion or in Low
-- performance. `round` is how wide the bulbs must spread across their second axis, of their first, to be taken as a
-- frame and ordered round it and not along it.
Presets.bulbChase = {
	pieces = { "Booth_Bulbs", "WallBoards_Bulbs", "WallHedge_Bulbs", "TicketFront_Bulbs" },
	within = 90,
	pick = 1.5,
	most = 5,
	mostLite = 2,
	gap = 3,
	hz = 2,
	hzDay = 1, -- by day, when the bulbs are not glowing themselves
	grow = 1.3,
	round = 0.3,
	on = Color3.fromRGB(255, 240, 205),
}

-- The guide trail's sparkles (#3022, Effects/TrailSparkle): every `every`th of GuideTrail's `dot` parts in the
-- Workspace folder `folder` (`everyLow` on a phone) carries the `emitter`; the choice is looked at again every
-- `recheck` seconds.
Presets.trailSparkle = {
	folder = "CatCafeTutorialTrail",
	dot = "Dot",
	emitter = "trailSparkle",
	every = 2,
	everyLow = 4,
	recheck = 3,
}

-- The Rummage Bin's prize roll and its reward effects (#3608; Effects/BinRoll). The roll goes `laps` times down
-- the list and on to the prize, a tick every `first` seconds until the last lap's worth of ticks slow evenly toward
-- `last` (the final gap is 6/7 of the way there; 2.0 to 2.5 s for the seven rows of the design, whose
-- BinRollSeconds is 2.5). While it rolls the bin rattles: it tips `rattle` degrees side to side `rattleHz` times a second about its base (still with Reduce
-- Motion). A row with no tier of its own gets one from its chance: at most `good` the middle show, at most `best`
-- the big one. `landed` is what the bin does as the roll stops, `tiers` what it does on the win, one entry per
-- tier: `sparkles` in a burst, a ground ring `ring` studs wide (0 for none), `confetti` as a share of the budget's
-- confetti, a light column `beam` studs high for `beamSeconds` (0 for none) and a `shake` of the screen in studs
-- (the big win only; off with Screen shake or Reduce Motion). The landing's column is short and thin so it is
-- gone before the bar's first hit and never covers the bar (design section 4).
Presets.binRoll = {
	laps = 2,
	first = 0.067,
	last = 0.45,
	slow = 4, -- #3903: the last ticks that slow down, all inside the final run to the prize (no near miss)
	rattle = 4,
	rattleHz = 7,
	good = 0.15,
	best = 0.05,
	lift = 3, -- studs over the bin's base where a burst comes out
	emitter = "catchSparkle",
	landed = {
		{ sparkles = 0, ring = 0, confetti = 0, beam = 0, beamSeconds = 0, shake = 0 },
		{ sparkles = 6, ring = 5, confetti = 0, beam = 0, beamSeconds = 0, shake = 0 },
		{ sparkles = 10, ring = 6, confetti = 0, beam = 14, beamSeconds = 0.9, shake = 0 },
	},
	tiers = {
		{ sparkles = 6, ring = 0, confetti = 0, beam = 0, beamSeconds = 0, shake = 0 },
		{ sparkles = 12, ring = 7, confetti = 0.4, beam = 0, beamSeconds = 0, shake = 0 },
		{ sparkles = 20, ring = 10, confetti = 1, beam = 40, beamSeconds = 3, shake = 0.12 },
	},
	-- common, good (the board's soft blue edge) and best (gold)
	colours = { Presets.palette.offwhite, Color3.fromRGB(143, 208, 255), Presets.palette.golden },
	reveal = 0.45, -- seconds a fixed prize's reveal takes (no roll)
	-- the prize's hop from the bin to the player
	hop = { seconds = 0.55, height = 3, size = 0.7, sparkles = 4 },
	-- #3885 (Derek 2026-11-13: "show a quick animation of the item popping out of the bin into your hands"): with the
	-- prize's picture the hop is the picture itself. It pops `rise` studs up out of the bin growing from `from` to its
	-- full `size` (studs wide) over the first `popShare` of `seconds`, then arcs `height` studs over to the hands and
	-- ends at `catch` of its size, with `sparkles` at the pop and again at the catch.
	prize = {
		seconds = 1.1,
		popShare = 0.4,
		rise = 2.5,
		height = 2,
		size = 2.2,
		from = 0.3,
		catch = 0.6,
		sparkles = 6,
		-- Review-QA's Studio look: the catch's few sparkles did not read, so the hands get a bigger burst and a ring
		catchSparkles = 16,
		catchRing = 4, -- studs wide
	},
	-- The lid on a win (#3612): still for a common prize, a hop for a good one, flies up turning and fades for the
	-- best. The lid is the model's closed look (its child Model named with `lidSuffix`); a model without one (the
	-- Yard Sale stall) just skips this.
	lidSuffix = "_Empty",
	lid = {
		{ height = 0, seconds = 0, turns = 0, fly = false },
		{ height = 1.6, seconds = 0.45, turns = 0, fly = false },
		{ height = 9, seconds = 1.1, turns = 1.5, fly = true },
	},
}

-- Petting a cat in your cafe (#3651; Effects/PetCat). The left arm goes down to the cat over `raise` seconds,
-- reached `sh` degrees forward and `sp` out with the elbow bent `el`, strokes `strokes` times (one every `every`
-- seconds, the hand moving `swing` degrees either way) and comes back over `lower`: 1.25 s in all. R6 reaches the
-- whole arm `sh6`. As the hand arrives the cat perks up (the catch's "perk") and `hearts` hearts (the ♥ glyph on
-- billboards, no texture; scaled by the budget's burstScale) float up `heartRise` studs from `up` studs over it (its
-- BubbleAnchor when it has one) in `colour` over `heartSeconds`, fanning `heartFan` studs apart, with a short purr
-- and a heart chime (Audio/Logic.petCatCue). When the heart moves from another cat, one grey heart fades off the
-- old cat and a pink heart `move.size` studs tall arcs `move.height` studs high to the new one in `move.seconds`.
-- Played for cafes within `range` studs.
Presets.petCat = {
	raise = 0.2,
	strokes = 2,
	every = 0.4,
	lower = 0.25,
	sh = 50,
	sp = 8,
	el = 20,
	swing = 10,
	sh6 = 60,
	up = 2.2,
	hearts = 5,
	heartSize = 0.9, -- studs
	heartSeconds = 1.1,
	heartRise = 2.4, -- studs a heart floats up
	heartFan = 1.6, -- studs between the outermost hearts at the top
	colour = Presets.palette.nosePink,
	lost = Presets.palette.furGrey,
	edge = Color3.fromRGB(94, 70, 52), -- palette 2, the UI's outline colour
	move = { seconds = 0.6, height = 3, size = 0.9 },
	range = 120,
}

-- #4913 Pal Day (Effects/PalDayFx): when today's gift is paid, this player waves with a heart puff (PetCat's hearts)
-- `overHead` studs over the head (`up` over the root without one), and each pal within `range` studs waves back
-- `palDelay` seconds later; at most `most` pals are kept from PalsChanged.
Presets.palDay = {
	overHead = 0.8,
	up = 3,
	range = 120,
	palDelay = 0.45,
	most = 12,
	colour = Presets.palette.nosePink,
	-- #4913 (Design-Agent, Wed Nov 18): while today's gift can still be earned (the server's `due` attribute on this
	-- player and the palDay switch on), a small still pink heart over the nearest `most` pals within `range` studs, so
	-- a player sees who to play beside. One BillboardGui each, `size` studs plus `pixels`, `up` studs over the head;
	-- checked every `every` seconds. Gone once the gift is paid, the switch is off or the pal walks away.
	heart = {
		due = "PalDayDue",
		most = 4,
		range = 120,
		every = 0.5,
		size = 1.1,
		pixels = 16,
		up = 2.2,
		glyph = "\u{2665}",
	},
}

-- #5465 the guide arrow (Effects/GuideArrow, switch guideArrow): a ">" of two `length` x `width` neon arms, each
-- `spread` radians off the line, its tip `ahead` studs before the player's feet toward the target and `lift` over the
-- ground, sliding up to `reach` studs further and back every `period` seconds. `target` and `colour` are the
-- attributes UI's GuideTrail writes on its folder.
Presets.guideArrow = {
	name = "CatCafeGuideArrow",
	target = "GuideTarget",
	colour = "GuideColour",
	ahead = 4.5,
	lift = 0.15,
	length = 1.6,
	width = 0.4,
	thick = 0.12,
	spread = math.rad(38),
	transparency = 0.1,
	reach = 0.8,
	period = 1.2,
}

-- Paw prints for a guide trail (#3554; Effects/PawTrail): while the trail's folder carries `attribute` = true, each
-- dot is drawn as a paw print `size` studs across on a `pixels` square canvas, `offset` studs left and right of the
-- line in turn. `toes` are x, y, width and height of each toe as shares of the canvas (the pad sits under them).
-- `turn` turns the drawing on its part, should the toes come out facing the wrong way in Studio.
Presets.pawTrail = {
	attribute = "Paws", -- UI's mark; since #4940 every tutorial trail is paws, so it gates nothing
	home = "CatCafePawTrail",
	size = 2.1, -- #4940: bigger for phones (1.7 before)
	pixels = 64,
	offset = 0.45,
	brightness = 2, -- the SurfaceGui ignores light (LightInfluence 0), so this is how it glows at night (1.6 before)
	faintest = 0.4, -- the comet's tail fades a print no further than this (GuideTrail's tail is 0.75)
	rim = { colour = Color3.fromRGB(92, 58, 34), pixels = 2, transparency = 0.45 }, -- cocoa, for pale floors
	turn = 0,
	pool = 48, -- Design 2026-11-17: prints built ahead from the first trail (GuideTrail's MAX_DOTS), kept for reuse
	buildsPerFrame = 4, -- at most this many new prints in one frame, for a dot or ahead
	toes = {
		{ 0.2, 0.36, 0.2, 0.26 },
		{ 0.39, 0.2, 0.2, 0.28 },
		{ 0.61, 0.2, 0.2, 0.28 },
		{ 0.8, 0.36, 0.2, 0.26 },
	},
}

-- The Mystic Pool's roll (#3314, trait-station.md section 1a; Effects/MysticPool): Sage Sorrel raises his staff, the
-- rolled cat floats up over the pool in a sparkle and drops in with a splash, the liquid steps grey, green, blue, gold
-- every `step` seconds with a bubble burst on each, stopping on the rolled rarity (a Mythic flashes on to its pink-red with a
-- rainbow shimmer and a star burst), then the cat pops back out and the trait card rises (the caller's onReveal).
-- Never a near miss: the steps only go up and stop on the real rarity. A tap skips to the card at any point. The
-- colours are shared/Traits.RARITIES' (the card's), so the pool and the card always match.
Presets.mysticPool = {
	liquidSuffix = "_Liquid_Glow", -- Model-Agent's mysticpool.py: the liquid's Model
	armSuffix = "_Sage_LegF2", -- the staff arm's Model; the staff rides it
	step = 0.6, -- seconds per colour step
	blend = 0.25, -- seconds a step's colour takes to blend in
	flash = 0.12, -- the Mythic's fast flash from gold to its own colour
	hold = 0.6, -- seconds on the last colour before the cat pops out
	mythicHold = 1.6, -- a Mythic's flash and shimmer, so its pool time is about 4 s
	shimmerHz = 0.9, -- rainbow cycles per second over a Mythic's liquid
	shimmerMix = 0.55, -- how much rainbow over the Mythic's colour (0 to 1)
	raise = 0.4, -- seconds Sorrel takes to raise his staff
	raiseDegrees = 75, -- forward, about his shoulder
	lower = 0.6, -- seconds to lower it again after the card
	rise = 0.7, -- seconds the cat floats up
	riseHeight = 4.5, -- studs over the liquid it floats to
	hang = 0.15, -- seconds it hangs there
	drop = 0.3, -- seconds it falls into the liquid
	sink = 1.2, -- studs under the surface it sinks to (out of sight)
	popUp = 0.45, -- seconds it pops back out
	popHeight = 3, -- studs over the liquid it pops to
	showCat = 1.6, -- seconds it floats there over the card before fading
	-- #3942: in a Mythic or Secret roll's whole scene the cat then rises up the pillar to `liftHeight` studs, turning
	-- `liftTurns` times as it goes, over the scene's `lift` seconds (Presets.bigTrait.scenes), and floats there
	liftHeight = 9,
	liftTurns = 2,
	-- the Rift Run's hand back (Effects/RiftRun, MysticPool.roll's landing): the cat falls `landHeight` studs into
	-- the pool over `landDrop` seconds and stays under `landHold` before it pops out
	landHeight = 26,
	landDrop = 0.55,
	landHold = 0.35,
	fadeBack = 1.5, -- seconds the liquid takes to go back to its rest colour
	startFront = 1.2, -- studs in front of the pool's middle the cat starts, on the liquid's surface
	sparkles = 14, -- the float's sparkle burst
	bubbles = 10, -- each step's bubble burst
	splash = 14, -- the drop's and the pop's splash
	stars = 30, -- a Mythic's star burst
	confetti = 40, -- a Mythic's confetti
	revealSparkles = 18, -- the pop's sparkles, in the rarity's colour
	-- the Mythic's confetti: its own colour first (shared/Traits.RARITIES' mythic, the Mythical cat rarity's
	-- pink-red since #3712; was purple), then a rainbow
	mythicColours = {
		Color3.fromHex("FF5E7E"),
		Color3.fromHex("FFF4E6"),
		Color3.fromHex("F4C430"),
		Color3.fromHex("4CAF50"),
		Color3.fromHex("3F8FE0"),
	},
}

-- #3430 (the Mystic Pool's first walk-up cutscene, Effects/MysticIntroCut). Seconds and studs. The camera swings to
-- `back` studs out along the pool's front and `up` up (`backTall`, `upTall` on a portrait screen), looking `lookUp`
-- over the liquid, trying each of `swings` degrees round it for a clear line. Then the five colours at `step` seconds
-- each (3 s), the silhouette's `rise` (2 s) and the swing back: about 7 s in all, inside the spec's 6 to 8.
Presets.mysticIntro = {
	swingIn = 1,
	swingOut = 0.8,
	steps = 6, -- the six rarity colours, Epic among them since 2026-11-12 (shared/Traits.RARITIES)
	step = 0.6, -- per colour, as the roll's own steps
	blend = 0.25,
	rise = 2, -- the silhouette and the card line
	riseSeconds = 1.2, -- of those, how long it takes to come up
	riseHeight = 2.5, -- studs over the liquid
	riseTurn = 60, -- degrees it turns through as it comes up
	raise = 0.4, -- Sorrel's staff going up
	waveHz = 0.8, -- then his wave, slow
	waveLow = 0.7, -- the wave's low point, as a share of fully raised
	back = 13,
	up = 2.5, -- a low view, so the moon arch stands over the pool
	backTall = 17,
	upTall = 4,
	lookUp = 2.5,
	swings = { 0, 25, -25, 50, -50 },
	maxDistance = 40,
	bubbles = 8,
	sparkles = 14,
	cat = "CatCafe_Cat_Tabby_Sit", -- the silhouette's shape
	shade = Color3.fromRGB(58, 44, 110), -- a deep violet, never black
	words = "The Mystic Pool gives your cat a special trait",
	lineSize = 24,
	lineHeight = 44,
	lineWidth = 560,
	lineUp = 84, -- pixels over the bottom edge, clear of the skip label
	lineCard = Presets.palette.offwhite,
	lineText = Color3.fromRGB(74, 52, 38),
	still = 2, -- Reduce Motion: the card line alone
	skipAfter = 0.2, -- a press sooner is the walk-up's own
	skipOut = 0.25,
	skipSize = 18,
	skipFade = 0.4,
	displayOrder = 10,
	cap = 9, -- controls always come back by now
	tvSafe = 0.05,
}

-- #3846 (Effects/BigTraitCut, Derek 2026-11-13: "a quick cutscene animation for legendary+ trait rerolls with some
-- vfx/sound before the menu pops up"): a Legendary or Mythic roll at the pool. Seconds, studs and pixels. The camera
-- spot is Presets.mysticIntro's (back, up, swings). Nothing blinks: the rays turn slowly and the title grows in once.
Presets.bigTrait = {
	rarities = { legendary = true, mythic = true, secret = true }, -- shared/Traits.RARITIES ids that get the cutscene
	titles = { legendary = "LEGENDARY TRAIT!", mythic = "MYTHIC TRAIT!", secret = "SECRET TRAIT!" },
	-- #3908 (Derek 2026-11-13: "make secret and mythic trait rolls have crazy animations and vfx"): each rarity's
	-- size of big moment. `big` and `screenSeconds` are seconds; `beams` light columns `beamHeight` studs high, in a
	-- circle `beamSpread` studs wide; `rings` ground rings `ringGap` seconds apart; `stars` and `confetti` before
	-- the device budget's cap; `rays` on the screen; `shake` studs (off with Screen shake or Reduce Motion); `dim`
	-- how dark the screen goes behind the title (0 none). The other numbers below are the Legendary's and shared.
	sizes = {
		-- Derek 2026-11-13 ("make legendary a smaller one less underwhelming"): two gold rings, more stars and
		-- confetti, and longer, for the RARE, EPIC, LEGENDARY words before the title (`ladder`), each with a ring
		legendary = {
			big = 3.6,
			screenSeconds = 2.6,
			beams = 1,
			beamHeight = 26,
			rings = 2,
			stars = 32,
			confetti = 56,
			rays = 10,
			shake = 0,
			dim = 0,
		},
		mythic = {
			big = 4.0,
			screenSeconds = 2.4,
			beams = 3,
			beamHeight = 30,
			rings = 2,
			stars = 36,
			confetti = 60,
			rays = 14,
			shake = 0.06,
			dim = 0.2,
		},
		secret = {
			big = 5.4,
			screenSeconds = 3,
			beams = 5,
			beamHeight = 40,
			rings = 3,
			stars = 48,
			confetti = 80,
			rays = 18,
			shake = 0.1,
			dim = 0.45,
		},
	},
	beamSpread = 5,
	ringGap = 0.35,
	-- the Secret rarity's look until shared/Traits gives it a colour: the Secret cats' starlight on a dark sky
	secretColour = Color3.fromRGB(226, 214, 255),
	secretColours = {
		Color3.fromRGB(226, 214, 255),
		Color3.fromRGB(120, 92, 200),
		Color3.fromRGB(255, 255, 255),
	},
	swingIn = 0.9, -- the camera over to the pool as the roll starts
	swingOut = 0.7, -- and back once the big moment is over
	skipOut = 0.25, -- back after a skip
	big = 2.2, -- the big moment, from the cat popping out to the swing back
	beamWidth = 2.4,
	beamHeight = 22,
	ringDiameter = 12,
	ringSeconds = 1.1,
	stars = 24,
	confetti = 40,
	screenSeconds = 1.8, -- away from the pool: the rays and the title alone
	still = 1.4, -- Reduce Motion: the title alone, still
	popSeconds = 0.35, -- the title's grow in
	popFrom = 0.55,
	popOver = 1.08,
	rays = 10,
	raySpin = 0.06, -- turns a second
	rayFade = 0.6, -- the rays' least transparency
	titleSize = 64,
	titleMin = 28,
	titleInk = Color3.fromRGB(74, 52, 38),
	displayOrder = 22, -- over the card's edge shade (21) and its "Tap to skip"
	cap = 16, -- controls always come back by now
	tvSafe = 0.05,
	-- #3942 (Derek 2026-11-13: "should give them a whole scene animation"): a Mythic or Secret roll at the pool is a
	-- whole scene, not just the card's moment. With the camera held: letterbox bars `bars` of the screen's height
	-- each, the world dimmed by `dim` (ColorCorrection brightness) and greyed by `saturation` toward `tint`, all
	-- following the camera's swing in and out, and the camera turning `orbit` degrees round the pool over
	-- `orbitSeconds`. At the big moment `spiral` sparkle pops climb the pillar over `spiralSeconds`; a Secret also
	-- draws a cat of `constellation` stars in the sky, `skyHeight` studs over the pool and `skyScale` studs a unit,
	-- one star every `starGap` seconds. Audio ducks the music for the scene. Reduce Motion: none of it.
	scenes = {
		-- Derek 2026-11-13: a small scene for a Legendary too: thin bars, a warm tint, a short turn round the pool, a
		-- spiral up the pillar and the cat hopping up spinning to `liftHeight` studs
		legendary = {
			bars = 0.07,
			dim = 0.05,
			saturation = -0.05,
			tint = Color3.fromRGB(255, 240, 208),
			orbit = 16,
			orbitSeconds = 5,
			spiral = 6,
			spiralSeconds = 1,
			lift = 1,
			liftHeight = 5.5,
			constellation = false,
		},
		mythic = {
			bars = 0.1,
			dim = 0.15,
			saturation = -0.25,
			tint = Color3.fromRGB(255, 226, 240),
			orbit = 30,
			orbitSeconds = 6,
			spiral = 8,
			spiralSeconds = 1.6,
			lift = 1.6,
			constellation = false,
		},
		secret = {
			bars = 0.12,
			dim = 0.3,
			saturation = -0.4,
			tint = Color3.fromRGB(206, 200, 255),
			orbit = 45,
			orbitSeconds = 7.5,
			spiral = 12,
			spiralSeconds = 2,
			lift = 2.2,
			constellation = true,
		},
	},
	skyHeight = 30,
	skyScale = 4,
	starGap = 0.12,
	starSparkles = 4,
	spiralRadius = 2.2,
	spiralHeight = 18,
	-- #3942: another player's Mythic or Secret roll seen from nearby (BigTraitCut.watchPool): within `seenRadius`
	-- studs, `seenDelay` seconds after the server's mark (about when the roller's pillar goes up), and only while
	-- the mark is under `seenFresh` seconds old
	-- Derek 2026-11-13: a Legendary's word ladder before its title, one word every `ladderGap` seconds (well under
	-- three a second), each in its tier's colour
	ladder = { "rare", "epic", "legendary" },
	ladderGap = 0.42,
	ladderWords = { rare = "RARE", epic = "EPIC", legendary = "LEGENDARY" },
	ladderSize = 40,
	seenRadius = 160,
	seenDelay = 4,
	seenFresh = 10,
}

-- The Rift Run (Derek 2026-11-13: "like a whole cutscene with the cat you have ... A rift opens and your cat jumps
-- through it running away while dodging meteors ... flash Common/Flash uncommon/flash rare ... with increasing
-- vfx/animation for each tier"; storyboard OK'd 20:09 UTC): a Mythic or Secret trait roll cuts to the Rift Realm, a
-- floating stone path in a violet sky, built on this client far off the map at `origin`. The rolled cat lands on the
-- path, runs it toward the rift while meteors fall beside it (it hops aside; nothing ever hits it), passes one gate a
-- tier, Common up to the rolled one, each with a bigger burst, word and sound than the last, and leaps through the
-- rift as it tears open. A pink then white flash takes it back to the pool (Effects/BigTraitCut's big moment and the
-- card). Seconds on the cutscene's own clock from its start; studs from the path's start, along -Z.
-- Model-Agent's kit (ReplicatedStorage.Assets.RiftRun, CatCafe_RiftRun_*) is used when it is there; otherwise the
-- same pieces are drawn here in the same sizes. Nothing flashes faster than about once a second; Reduce Motion skips
-- it all (the pool's own calm reveal plays). Switch `riftRun` (shared/LiveFlags).
Presets.riftRun = {
	origin = Vector3.new(6000, 1600, 6000), -- the path's start, on its walking top
	tiers = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }, -- a gate each, in order
	words = {
		common = "COMMON",
		uncommon = "UNCOMMON",
		rare = "RARE",
		epic = "EPIC",
		legendary = "LEGENDARY",
		mythic = "MYTHIC",
		secret = "SECRET",
	},
	pathLength = 120,
	pathWidth = 10,
	tileLength = 5,
	gateFirst = 20, -- the first gate this far along, the rest `gateGap` apart
	gateGap = 15,
	gateWidth = 12, -- inside
	gateHeight = 14,
	ringBeyond = 12, -- the rift's ring this far past the path's end, upright
	ringDiameter = 30,
	ringLift = 15, -- its middle this high over the path's top
	-- the open: white over the pool, then the cut to the realm and the white fading off it
	flareIn = 0.45,
	flareOut = 0.55,
	dropAt = 0.6, -- the cat falls onto the path's start
	dropSeconds = 0.35,
	dropHeight = 7,
	runStart = 1.5,
	firstGateAt = 3,
	gateGaps = { 1.15, 1.05, 1, 0.95, 0.9 }, -- seconds from each gate to the next, Common to Mythic: faster and faster
	darkGap = 2.4, -- a Secret: from the Mythic gate to the white Secret gate, through the dark
	darkIn = 0.7, -- the realm going black after the Mythic gate
	leapFrom = 117, -- the leap starts here
	endSpeed = 18, -- studs a second from the last gate to the leap
	leapSeconds = 1.45, -- off the path's end up into the rift, slowed right down
	leapArc = 5, -- studs over the straight line at the leap's top
	pinkAt = 0.55, -- of the leap: the pink flash starts
	whiteAt = 0.92, -- and is all white
	backOut = 0.6, -- back at the pool, the white fading off
	-- dodging: the cat hops aside to a new lane `dodges` seconds after it starts running, and a meteor lands in the
	-- lane it left `meteorLead` seconds later, just beside it
	laneWidth = 2.8,
	dodges = { 0.9, 2, 3.05, 4, 4.9, 5.75 },
	lanes = { -1, 1, 0, -1, 1, 0 },
	dodgeSeconds = 0.32,
	dodgeHop = 1.4,
	meteorLead = 0.3,
	meteorFall = 0.85,
	meteorFrom = Vector3.new(12, 46, -34), -- where it falls from, from where it lands (X mirrored every other one)
	meteorAhead = 2.5, -- lands this far ahead of the cat
	meteorSize = 3.6,
	meteorStay = 1.4, -- the rock sinks and fades after landing
	meteorSparks = 18,
	meteorShake = 0.05,
	-- the camera: low behind the cat, the field of view opening as it speeds up
	camera = {
		back = 6,
		up = 4,
		ahead = 9,
		lookUp = 1.4,
		fov = 70,
		fovEnd = 82,
		fovKick = 2.5, -- more each gate, easing off over kickSeconds
		kickSeconds = 0.45,
		follow = 9, -- how fast it catches up with the cat
		introEye = Vector3.new(-13, 8, 15), -- the first wide shot, from the path's start
		introLook = Vector3.new(0, 4, -45),
		leapEye = Vector3.new(5, 3, 10), -- from the leap's start, as the cat flies up
	},
	-- each gate as the cat passes: its arch flares, a shockwave ring, sparkles and the tier's word, all growing
	gateSparkles = 10,
	gateSparklesGrow = 6,
	shockFrom = 4,
	shockTo = 13,
	shockGrow = 2.5,
	shockSeconds = 0.55,
	gateFlare = 0.35, -- the arch white, back to its colour
	wordSize = 44,
	wordGrow = 5,
	wordSeconds = 0.85,
	wordInk = Color3.fromRGB(40, 22, 60),
	confettiFrom = 5, -- gates from this tier up throw confetti
	beamsFrom = 6, -- and from this one two light columns
	-- the realm's look
	sky = {
		-- Neon glows brighter than its colour (Review-QA on #4029 read the first sky as pale pink), so these are dark
		Color3.fromRGB(8, 4, 22), -- top
		Color3.fromRGB(18, 8, 42),
		Color3.fromRGB(36, 12, 66),
		Color3.fromRGB(70, 22, 92),
		Color3.fromRGB(128, 48, 108), -- the horizon's glow
		Color3.fromRGB(44, 14, 64),
		Color3.fromRGB(12, 6, 26), -- under
	},
	skyHalf = 120, -- the sky's walls this far to either side
	skyAhead = 230, -- and ahead
	skyBehind = 50,
	skyUp = 130,
	skyDown = 90,
	stars = { high = 110, low = 45 },
	starColour = Color3.fromRGB(255, 244, 255),
	nebula = {
		{ at = Vector3.new(-30, 40, -200), size = 70, colour = Color3.fromRGB(255, 90, 170) },
		{ at = Vector3.new(40, 25, -190), size = 55, colour = Color3.fromRGB(120, 90, 255) },
		{ at = Vector3.new(0, 70, -205), size = 80, colour = Color3.fromRGB(80, 160, 255) },
	},
	nebulaSeen = 0.82, -- transparency
	stone = { Color3.fromRGB(88, 78, 120), Color3.fromRGB(76, 68, 106) },
	edge = Color3.fromRGB(176, 120, 255),
	rock = Color3.fromRGB(46, 36, 66),
	crystal = { Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 120, 210) },
	islands = {
		{ at = Vector3.new(-26, -6, -30), size = 16 },
		{ at = Vector3.new(30, 4, -62), size = 24 },
		{ at = Vector3.new(-34, 10, -96), size = 10 },
		{ at = Vector3.new(26, -10, -118), size = 16 },
	},
	islandBob = 0.8, -- studs, slowly
	ringColour = Color3.fromRGB(255, 110, 190),
	ringCore = Color3.fromRGB(255, 214, 240),
	ringSegments = 28,
	ringOpen = 0.18, -- how open the rift is as the run starts (a slit), opening fully as the leap nears
	ringTear = 1.2, -- seconds before the leap it tears the rest of the way open
	grade = {
		tint = Color3.fromRGB(236, 222, 255),
		brightness = -0.02,
		contrast = 0.12,
		saturation = 0.1,
	},
	dark = { brightness = -0.32, saturation = -0.6, tint = Color3.fromRGB(200, 196, 255) },
	secretColour = Color3.fromRGB(240, 236, 255),
	flashPink = Color3.fromRGB(255, 120, 200),
	displayOrder = 40, -- over every window, the bars and the title
	cap = 30, -- everything is back by now, whatever happens
	streaks = 18, -- speed streaks a second round the camera at the end speed
}

-- #3419 (the update party's banner, Effects/EventBanner): a cream and gold card at the top middle of the screen for
-- the party's start, the gift on its way and the gift paid. Pixels and seconds. The words are the caller's (#3420);
-- `titleLength` and `lineLength` are the most characters drawn. Everything plays once per banner.
Presets.eventBanner = {
	displayOrder = 29,
	queue = 3, -- banners that may wait behind the one showing
	hold = 5, -- seconds at rest when the caller gives none; a tap on the card sends it away sooner
	holdMin = 3,
	holdMax = 5, -- Derek, 2026-11-12: gone by itself in 3 to 5 seconds
	titleLength = 24,
	lineLength = 36,
	maxLines = 3,
	-- the card
	widthScale = 0.9,
	maxWidth = 440,
	top = 10, -- under the Roblox top bar
	pad = 10,
	corner = 16,
	titleHeight = 36,
	titleSize = 30,
	lineHeight = 24,
	lineSize = 20,
	badgeSize = 56,
	card = Presets.palette.offwhite,
	outline = Color3.fromRGB(74, 52, 38), -- the UI's dark brown outline
	stripTop = Presets.palette.goldLight,
	stripBottom = Presets.palette.golden,
	titleText = Presets.palette.milk,
	lineText = Color3.fromRGB(74, 52, 38),
	badge = Presets.palette.neonPink,
	badgeText = Presets.palette.milk,
	-- #4195 the admin event cards: a rose strip, a gold badge of at most `badgeLength` characters, and the start
	-- card as wide as the screen allows
	badgeLength = 3,
	adminTop = Color3.fromRGB(255, 150, 170),
	adminBottom = Presets.palette.neonPink,
	adminBadge = Presets.palette.golden,
	adminWidthScale = 0.98,
	adminMaxWidth = 900,
	fishImage = "rbxassetid://101061912700342", -- CatCafe_Icon_GoldenFish (the UI's Theme.textures.fishCoin)
	-- the motion
	dropSeconds = 0.45,
	leaveSeconds = 0.3,
	fadeSeconds = 0.25, -- Reduce Motion: fade in and out in place
	shineSeconds = 0.7, -- one sweep as the card lands
	shineWidth = 0.3,
	shineTransparency = 0.45,
	-- the confetti as it lands (12 is the phone's burst cap)
	confetti = 12,
	confettiSoon = 6,
	confettiColours = { Presets.palette.golden, Presets.palette.neonPink, Presets.palette.mint },
	confettiSize = 12,
	confettiSeconds = 0.7,
	confettiReach = 46,
	confettiStagger = 0.25,
	-- the gift's golden fish hopping out from under the card
	fish = 8,
	fishSize = 34,
	fishSeconds = 1.1,
	fishStagger = 0.07,
	fishUp = 40,
	fishFall = 150,
	fishSpread = 180,
	-- the "secrets" banner (#3523): a night strip, a "?" badge and the Secret cats as black shapes under the words
	nightTop = Color3.fromRGB(64, 50, 132),
	nightBottom = Color3.fromRGB(30, 22, 72),
	secretBadge = Presets.palette.aurora,
	spawnBadge = Color3.fromRGB(226, 214, 255), -- the "secretSpawn" banner's disc: the Secret starlight (#3545)
	secretColours = { Presets.palette.aurora, Presets.palette.milk },
	shapeMost = 3, -- cats in the row
	shapeRow = 74, -- the row's height under the last line
	shapeSize = 68,
	shapeGap = 18,
	shapeColour = Color3.fromRGB(8, 8, 10), -- the Index's black for a cat not found yet (CatPortrait)
	shapeFov = 30,
	shapeTurn = 20, -- degrees from face on, so both ears show and a little of the body behind the head
	-- bits left off a shape because they read wrong in plain black: Glitch's trail of loose pixels off one ear
	-- joins up into a horn (Derek, 2026-11-12: "the horn looks a little off"). Only the parts of these pieces no
	-- longer than `shapeLoose` studs go (the pixels are 0.12 to 0.22); the torn bars at the head's sides (0.71) stay.
	shapeLeaveOff = { "CatCafe_Cat_Glitch_Prop", "CatCafe_Cat_Glitch_Glow" },
	shapeLoose = 0.3,
	shapeFill = 0.92, -- how much of its square a shape may fill
	shapeSeen = 0.95, -- a part at least this see-through is a hitbox and stays out of the shape
	markSize = 24, -- the "?" on each shape
	markColour = Color3.fromRGB(206, 196, 255),
}

-- A Secret stray in the world (#3470 section 5: "a soft dark aura and a thin beam of light to the sky that can be
-- seen from the camp"). The aura is the secretAura haze on the cat's body, with the secretStars unless Low
-- performance is on. The beam stands `height` studs tall over the cat and is `perStud` studs wide for each stud
-- between you and it, between `widthMin` and `widthMax`, so it stays a thin line on screen from any distance; it is
-- see-through by `far` from a distance and fades to `near` inside `nearWithin` studs so it never covers the catch.
-- It holds still: no pulse, so nothing flashes. The `most` nearest Secret strays show; there is rarely even one.
Presets.secretStray = {
	most = 2, -- cats wearing the haze at once
	-- The beam also shows for a Secret stray too far to be streamed in, from the server's beacons: the Folder
	-- `beacons` in ReplicatedStorage (Catching.SECRET_BEACONS) holds a Vector3Value per live Secret stray, named by
	-- its StrayId, with the cat's position every 2 seconds. The `beams` nearest show, and a beam with no cat model
	-- here glides to each new position at `glide` of the way a second, snapping past `snap` studs (a new spot).
	beacons = "SecretBeacons",
	beams = 3,
	glide = 3,
	snap = 60,
	checkEvery = 0.5,
	beam = {
		height = 260,
		lift = 1.2, -- studs over the cat's pivot where the beam starts
		perStud = 0.007,
		widthMin = 0.45,
		widthMax = 4,
		far = 0.3,
		near = 0.8,
		nearWithin = 30,
		fadeOver = 30, -- studs past nearWithin over which it reaches `far`
		topFade = 0.45, -- share of the height over which the top fades to nothing
	},
}

-- The Secret cats' own glow (#3544, Effects/SecretGlow). The nearest `most` Secret cats within `within` studs glow
-- (`mostLow` on Low performance, halo only), checked every `checkEvery` seconds. It is whole inside `full` studs and
-- fades to nothing at `within`; the stars show while more than `starsFrom` of it is left. The light is `colour`,
-- reaches `range` studs and breathes between `low` and 1 of `brightness` once every `breathe` seconds (slow: far
-- under any flash); Reduce Motion holds it at `rest`. `behind` is the halo's ZOffset, so it draws behind the cat.
Presets.secretGlow = {
	most = 4,
	mostLow = 2,
	within = 90,
	full = 45,
	starsFrom = 0.5,
	checkEvery = 0.5,
	colour = Color3.fromRGB(226, 214, 255),
	range = 9,
	brightness = 1.1,
	low = 0.55,
	rest = 0.8,
	breathe = 4,
	behind = -1.5,
}

-- #3464 (a loot card's pop-in, Effects/LootCardFx): the card scales in from `from` over `popSeconds` with one soft
-- overshoot, its first row lands at `firstRow` seconds and each next one `gap` later; `bounceSeconds` is the icon
-- bounce's length (Presets.mouseDash.bounce.seconds), counted so the pop-in's end covers the last bounce.
Presets.lootCard = {
	from = 0.8,
	popSeconds = 0.22,
	firstRow = 0.12,
	gap = 0.15,
	bounceSeconds = 0.22,
}

-- The stuck cat that calls for help (#2912, Design-Agent 2026-11-12): while this player's save waits for its first
-- rescue (ProfileSync `stuckGoal`), the cat in the Alleyway's starter trap (its `Starter` attribute) wears a warm,
-- `pillar` of light that can be seen from the camp (the Secret beam's maths, shorter and warm; it holds still),
-- a `bubble` over it that rocks gently like a waving paw, its trap gives a small `wiggle` now and then, and the cat
-- meows (`meow`, Audio's strayCall) as you come near, a few times at most. All of it goes when the rescue bar opens
-- or someone else is on that cat. Nothing counts down and nothing says hurry. No arrow (Derek's no-arrows rule).
-- Reduce Motion keeps the bubble and the trap still.
Presets.stuckCall = {
	checkEvery = 0.5,
	-- Review-QA's Studio look (2026-11-12): at 0.4 studs, pale and 35% see-through it could not be made out by day
	-- from the camp. It is now golden, at least `widthMin` 2 studs wide, nearly solid from afar (`far`), only half
	-- additive (`emission`, so it holds its colour against a bright sky) and wears a soft `halo` `wide` times its
	-- width that is `add` more see-through.
	pillar = {
		colour = Presets.palette.golden,
		emission = 0.5,
		height = 90,
		lift = 1,
		perStud = 0.03,
		widthMin = 2,
		widthMax = 4,
		far = 0.12,
		near = 0.85,
		nearWithin = 18,
		fadeOver = 25,
		topFade = 0.5,
		halo = { wide = 2.6, add = 0.6 },
	},
	-- Review-QA's second look: from the camp pad the Alleyway's street arch hides the pillar, so the trap also
	-- wears a warm `glow` on the ground, `radius` studs across, that breathes slowly between `bright` and `dim`
	-- see-through over `seconds` each way (well under once a second; held at `bright` with Reduce Motion), and a
	-- soft warm light of `range` studs.
	glow = {
		colour = Color3.fromRGB(255, 150, 48), -- warm orange, apart from the guide trail's yellow dots
		radius = 4,
		thick = 0.05,
		bright = 0.35,
		dim = 0.65,
		seconds = 1.6,
		range = 14,
		brightness = 2,
	},
	bubble = {
		text = "Help! 🐾",
		above = 4.4, -- studs over the cat's top, clear of the "!" and its gem
		width = 4.6,
		height = 1.5,
		within = 70,
		hideWithin = 10, -- the Rescue card shows from here
		rock = 6, -- degrees each way
		rockSeconds = 0.9, -- one way
	},
	wiggle = { every = 5, within = 80, hits = 1, needed = 3 }, -- a trapShake as small as a rescue's first hit
	meow = { near = 60, gap = 45, most = 4 },
}

-- The Neighborhood's trampoline (#3690; Effects/Trampoline). A model whose name ends in `suffix` is one; its mat is
-- the part at most `matThin` studs thin and at least `matWide` wide. A landing from above (the feet no more than
-- `under` studs below the mat's top, within the mat's radius plus `edge`) throws the character `height` studs up,
-- at most once every `gap` seconds; the landing is looked for `ray` studs under the feet. A jump off the mat reaches 7.2 studs, so `height` adds under 2 studs of reach.
-- The mat dips `dip` studs over `down` seconds and springs back over `up`.
Presets.trampoline = {
	suffix = "_Trampoline",
	matThin = 0.3,
	matWide = 4,
	height = 9,
	gap = 0.25,
	under = 0.6,
	edge = 0.5,
	ray = 1.5,
	dip = 0.3,
	down = 0.08,
	up = 0.35,
}

-- #4062 Dragon Keep: the stage-up cutscene (Effects/DragonRise) and the card deal's flips (Effects/CardFlip). Spec:
-- Design-Agent/notes/ticket-booth-and-dragon-keep.md 2.5 and 2.6. Times are seconds from the start; sizes studs.
-- Every stage plays the same shots, with more on top each stage (like the Rift Run's gates): 1 sparks, 2 smoke rings,
-- 3 an ember ring and a light column, 4 gold coins in the column, 5 a lap of the castle and flame confetti.
Presets.dragonRise = {
	-- the shots (stages 1 to 4, about 7 s): the camera swings to the Keep, holds low through the curl into an ember
	-- ball and its crack, then one slow push in on the new look and the roar; no cut faster than about 0.8 s
	swing = 1.2, -- the camera's swing from the player's view to the Keep
	curlAt = 1.2, -- he starts curling up
	curlSeconds = 0.9,
	ballFrom = 0.35, -- after curlAt, the ember ball starts growing round him
	heatSeconds = 1.0, -- before the crack, the ball heats from orange to white-gold
	crackAt = 3.0,
	unfurlSeconds = 1.3, -- after the crack, the new look unfurls
	roarAfter = 0.25, -- after the unfurl, the roar
	roarSeconds = 1.1,
	backSeconds = 0.8, -- the camera's swing back to the player at the end
	total = 7,
	skipAfter = 1, -- a tap skips after this
	-- stage 5 (12 s): after the unfurl he flies one lap of the castle and lands on the tower, crown glinting
	crowned = {
		total = 12,
		lapAfter = 0.2, -- after the unfurl
		lapSeconds = 4.6,
		roarAfter = 0.35, -- after landing on the tower
		lapRadius = 26,
		lapHeight = 16,
		tower = Vector3.new(-14, 18, 10), -- the tower top, from the yard centre (the Keep's frame), when none is given
		flapHz = 1.4, -- wing beats a second while flying (a motion, never a flash)
		flap = 0.75,
	},
	-- Reduce Motion: a 2 s soft fade with the new look and the roar
	reduced = { total = 2, fadeSeconds = 0.5, roarAt = 1.0, outAt = 1.5 },
	cap = 3, -- seconds past a plan's total by which everything is given back, whatever happens

	-- the stages: the stand-in's height (its own models' framing too), the title, and what each adds
	stages = {
		{ name = "Hatchling", height = 3.2, sparks = 16 },
		{ name = "Whelp", height = 4.6, sparks = 22, smokeRings = 2 },
		{ name = "Drake", height = 7.5, sparks = 30, smokeRings = 3, emberRing = 18, column = 34 },
		{
			name = "Elder",
			height = 10,
			sparks = 36,
			smokeRings = 3,
			emberRing = 24,
			column = 44,
			coins = 16,
		},
		{
			name = "Crowned",
			height = 13,
			sparks = 44,
			smokeRings = 4,
			emberRing = 30,
			column = 56,
			coins = 22,
			confetti = 70,
		},
	},
	camera = {
		-- from the yard centre in the Keep's frame (its -Z looks out the gate, where the camera stands): the eye
		-- `distance` heights out and `up` heights up, looking at `lookUp` heights over the yard
		distance = 2.4,
		minDistance = 9,
		up = 0.55,
		lookUp = 0.45,
		side = 0.35, -- a little off to one side, so he reads in three quarters
		drift = 0.12, -- the slow drift sideways while he curls (of a height)
		push = 0.78, -- the push in on the new look: the distance by this much
		fov = 60,
		lapFov = 66,
		lapEye = Vector3.new(0, 8, -30), -- the camera for the lap, from the yard centre in the Keep's frame
		-- the camera never sits inside the map: it stays `clearGap` studs in front of the first solid thing between
		-- what it looks at and where it wants to be, at least `clearLeast` of the way out, easing back out at
		-- `clearEase` a frame once the way is clear
		clearGap = 1.5,
		clearLeast = 0.25,
		clearEase = 0.12,
		-- #4612 (Derek: "make it show from above"): the yard shots look down on him by at least `pitch` and over the
		-- Keep's walls by `wallGap` studs (Effects/KeepShot). The walls come from the Keep model's box (top at most
		-- `wallsMost`); without one, `wallsHalf` and `wallsTop` (the Keep export: 15 x 15 studs, 7.5 high)
		pitch = math.rad(38),
		wallGap = 2,
		wallsHalf = 7.5,
		wallsTop = 7.5,
		wallsMost = 16,
		-- #5423 (Derek 2026-11-19: "still a little bit too much with the wall in camera make it more from above"): the
		-- yard shots swing up to `above` over him, `aboveRange` of the low shot's distance away (Effects/KeepShot.above)
		above = math.rad(64),
		aboveRange = 0.9,
		-- #5480: the flights to and from the Keep rise over the straight line by `hopLift` of their length (at most
		-- `hopMost` studs) and keep `groundGap` studs over the hills under them, so they never skim the ground
		hopLift = 0.35,
		hopMost = 60,
		groundGap = 6,
	},
	-- the ember ball
	ball = {
		size = 1.2, -- of the bigger look's height
		transparency = 0.35,
		solid = 0.04, -- at its hottest (the swap under it is hidden)
		cool = Color3.fromRGB(255, 128, 52),
		hot = Color3.fromRGB(255, 238, 186),
		light = 4,
		embers = 18, -- the ember emitter's rate on it
		rumble = 0.035, -- the shake while it heats (studs)
	},
	crack = {
		flash = 0.8, -- the one white flash: up to this much, then off over flashSeconds
		flashSeconds = 0.55,
		shards = 10, -- plus shardsGrow a stage
		shardsGrow = 2,
		shardSpeed = 14,
		shardSeconds = 0.9,
		ring = 10, -- plus ringGrow a stage
		ringGrow = 3,
		shake = 0.12,
	},
	roar = {
		jaw = 0.65, -- the jaw open (radians)
		lift = 0.55, -- head up
		hop = 0.12, -- a happy hop (of a height)
		shake = 0.08, -- plus shakeGrow a stage
		shakeGrow = 0.03,
		smokeRingPuffs = 10,
		smokeRingSeconds = 1.4,
		coinSeconds = 1.6,
	},
	-- the scale colours (the stage 3 pick, and before it his pastel)
	scales = {
		pastel = Color3.fromRGB(255, 196, 170),
		ruby = Color3.fromRGB(214, 62, 78),
		sapphire = Color3.fromRGB(62, 112, 214),
		emerald = Color3.fromRGB(52, 170, 110),
		amethyst = Color3.fromRGB(150, 92, 208),
	},
	belly = Color3.fromRGB(255, 232, 196),
	horn = Color3.fromRGB(250, 236, 210),
	chest = Color3.fromRGB(255, 170, 70),
	gold = Color3.fromRGB(255, 200, 70),
	egg = Color3.fromRGB(255, 240, 220),
	eggSpots = Color3.fromRGB(255, 196, 170),
	flame = {
		Color3.fromRGB(255, 120, 50),
		Color3.fromRGB(255, 190, 70),
		Color3.fromRGB(255, 230, 140),
		Color3.fromRGB(240, 80, 90),
	},
	wordInk = Color3.fromRGB(80, 36, 20),
	wordColour = Color3.fromRGB(255, 214, 120),
	wordSize = 72,
	wordSeconds = 2.2,
	displayOrder = 40,

	-- the card deal (CardFlip): one card at a time, on the Legendary word ladder's beat
	cards = {
		gap = 0.42,
		shut = 0.13, -- the back narrows to nothing
		open = 0.2, -- the front widens out, overshooting a little
		pop = 1.07,
		edge = 3, -- the rarity edge's thickness, pulsing once to edgePulse
		edgePulse = 7,
		edgeSeconds = 0.45,
		rainbowTurn = 70, -- degrees a second the Mythic edge's rainbow turns (a slow turn, never a flash)
		rays = 12, -- the Legendary and Mythic burst behind the card
		raySeconds = 1.1,
		sweepSeconds = 0.5, -- the Legendary glint across the face
		edges = {
			common = Color3.fromRGB(170, 170, 178),
			rare = Color3.fromRGB(70, 140, 235),
			epic = Color3.fromRGB(160, 90, 220),
			legendary = Color3.fromRGB(255, 196, 60),
			mythic = Color3.fromRGB(255, 110, 200),
		},
		rainbow = {
			Color3.fromRGB(255, 96, 96),
			Color3.fromRGB(255, 196, 70),
			Color3.fromRGB(110, 220, 120),
			Color3.fromRGB(80, 170, 255),
			Color3.fromRGB(190, 110, 255),
		},
	},
}

-- "Trading unlocked!" (#4280, Effects/TradeUnlock; Derek 2026-11-14: "an unlock with a lock falling off of it
-- animation on hitting Tier 3"). On the screen's upper middle, taking no taps: the Trade icon pops in over `popIn`
-- with a closed padlock on it; from `wiggleAt` the lock wiggles `wiggles` times through `wiggle` degrees over
-- `wiggleSeconds` (2.4 a second, under the 3 a second limit); at `openAt` it springs open with a hop of `hop` of its
-- size, `sparkles` gold diamonds and a ring; from `fallAt` it falls off (`gravity` and `drift` in icon sizes a second,
-- `spin` degrees a second) and fades over `fallSeconds`. The words show from `openAt`. At `flyAt` the icon flies over
-- `fly` seconds to the HUD's Trade tile, shrinking to `land` of its size, and the tile gets `landSparkles` and a
-- ring; with no tile on screen it fades there instead. `size` is the icon's share of the screen's shorter side,
-- between `sizeMin` and `sizeMax` pixels, and it sits `high` of the way down the screen.
-- Reduce Motion: no pop, wiggle, fall or flight; the closed lock gives way to the open one at `stillOpen`, the
-- words hold and everything fades from `stillEnd` over `fade`.
Presets.tradeUnlock = {
	displayOrder = 22, -- over a window (20), under the toasts (30)
	size = 0.2,
	sizeMin = 72,
	sizeMax = 132,
	high = 0.3,
	lock = 0.62, -- the padlock's size against the icon's
	popIn = 0.3,
	wiggleAt = 0.4,
	wiggleSeconds = 1.25,
	wiggles = 3,
	wiggle = 14,
	openAt = 1.75,
	hop = 0.18,
	fallAt = 2.1,
	fallSeconds = 0.7,
	gravity = 9,
	drift = 0.7,
	spin = 220,
	flyAt = 4.1,
	fly = 0.55,
	land = 0.4,
	lift = 0.12,
	fade = 0.3,
	stillOpen = 0.8,
	stillEnd = 3.6,
	-- #5550 cutsQuick (Derek 2026-11-20 13:21 UTC: "make the trade unlocked faster"): about 2.0 s, same look,
	-- sparkles and sounds; one wiggle (2.5 a second, under the 3 a second limit). Off keeps the timing above.
	quick = {
		popIn = 0.2,
		wiggleAt = 0.25,
		wiggleSeconds = 0.4,
		wiggles = 1,
		openAt = 0.7,
		fallAt = 0.9,
		fallSeconds = 0.5,
		flyAt = 1.5,
		fly = 0.4,
		stillOpen = 0.4,
		stillEnd = 1.6,
	},
	sparkles = 14,
	landSparkles = 10,
	sparkle = { size = 12, seconds = 0.55, reach = 90, stagger = 0.1 },
	ringSeconds = 0.5,
	title = "Trading unlocked!",
	line = "Swap cats with other players",
	titleSize = 30,
	lineSize = 18,
	gold = Presets.palette.golden,
	tradeImage = "rbxassetid://83738164568639", -- Icon_Clean_Trade (the UI's ShopIcons)
	lockImage = "rbxassetid://126676730576646", -- Icon_Clean_Lock
	openImage = "rbxassetid://129908896970192", -- Icon_Clean_Unlock
}

-- #5572 the Picnic Party (Effects/PicnicParty, switch picnicParty; Derek 2026-11-20 15:09 UTC: "rework the picnic
-- basket into being something cool and clean ... it has to be something that hooks"). Ready: the basket wobbles
-- `wobble.degrees` for `wobble.seconds` every `wobble.every` seconds, a soft gold Highlight and PointLight, and a sign
-- `sign.width` x `sign.height` pixels (fixed on screen, so it reads from the Park landing on an 844 x 390 phone, Design
-- 15:15 UTC) `sign.lift` studs over the station's top, seen to `sign.maxDistance` studs. Not ready: the sign's
-- `waiting` look with "Next picnic 12 m". The pop (on the ring claim, about `pop.seconds`): the `_Lid` swings open
-- `lidOpen` degrees, the blanket rolls out `blanket.gap` studs beside the basket over `rollSeconds`, `treats` bounce
-- from the basket onto it, `confetti` pieces. Where the blanket and the picnic cats' seats lie is shared/PicnicSeats.
-- Pack away over `pack.seconds`. Reduce Motion: no wobble or bounce, the basket opens and the blanket lies out still.
-- Words are Design's (`words`).
Presets.picnicParty = {
	flag = "picnicParty",
	extraId = "picnic",
	wobble = { every = 2.5, seconds = 0.7, degrees = 8, wiggles = 2, lidShare = 2.5 }, -- the lid lifts up to 20 degrees
	lidSuffix = "_Lid", -- Model-Agent's #5580: the lid is the station's child model <station name>_Lid
	glow = {
		fill = Presets.palette.golden,
		fillTransparency = 0.8,
		outlineTransparency = 0.35,
		light = 1.4, -- PointLight brightness
		range = 12,
		pulse = 2.4, -- seconds a slow breath of the light takes
	},
	sign = {
		width = 210,
		height = 58,
		waitWidth = 170,
		waitHeight = 40,
		lift = 4.5, -- over the player's head from the Park landing
		maxDistance = 220, -- drawn on top of walls, so only from the Park itself
		swell = 0.15, -- the ready sign grows this share at the top of each wobble
		bob = 0.25, -- studs up and down
		bobSeconds = 2.2,
		gold = Presets.palette.golden,
		cream = Presets.palette.cream,
		ink = Color3.fromRGB(60, 36, 20),
		faded = 0.25, -- the waiting sign's see-through share
	},
	pop = {
		seconds = 1.5,
		lidOpen = 105, -- degrees about its back edge
		lidSeconds = 0.25,
		rollAt = 0.15,
		rollSeconds = 0.5,
		treatAt = 0.55,
		treatGap = 0.15,
		treatSeconds = 0.45,
		treatHeight = 2.5, -- studs over the straight line the arc rises
		confettiAt = 0.3,
		confetti = 40,
		sparkles = 12,
	},
	pack = { seconds = 0.9, lidSeconds = 0.25 },
	blanket = {
		size = Vector3.new(6, 0.08, 6),
		gap = 1, -- studs between the basket's side and the blanket's near edge
		squares = 6, -- checks along each side of the stand-in blanket
		red = Color3.fromRGB(214, 96, 92),
		white = Presets.palette.cream,
		model = "CatCafe_Prop_PicnicBlanket", -- Model-Agent's #5580, under ReplicatedStorage.Assets
		rolled = "CatCafe_Prop_PicnicBlanket_Rolled",
		rollRadius = 0.32,
	},
	treats = {
		{
			model = "CatCafe_Prop_PicnicSandwich",
			colour = Color3.fromRGB(236, 196, 120),
			at = Vector2.new(-0.2, -0.3),
		},
		{
			model = "CatCafe_Prop_PicnicCupcake",
			colour = Color3.fromRGB(244, 160, 186),
			at = Vector2.new(0.05, -0.32),
		},
		{
			model = "CatCafe_Prop_PicnicLemonade",
			colour = Color3.fromRGB(250, 226, 110),
			at = Vector2.new(0.3, -0.28),
		},
	},
	treatSize = Vector3.new(0.6, 0.35, 0.6), -- the stand-ins
	words = {
		ready = "PICNIC READY",
		waiting = "Next picnic %s",
	},
}

return Presets
