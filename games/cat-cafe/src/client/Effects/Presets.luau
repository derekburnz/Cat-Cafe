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
	napLabels: number, -- napping cats that show floating z's
	rushLines: number, -- speed lines on a player in a Catch Rush (F55)
	signatureCats: number, -- Legendary and Mythical themed cats showing their signature effect at once
	decorEffects: number, -- Mythical cafe styles and decor moving at once; each takes one of steadyEmitters
	potionGlows: number, -- players showing a running potion's glow at once (F64), your own first
}

-- "low" is a phone or a tablet (touch with no keyboard): 150 live particles, bursts of 12, 4 steady emitters
-- (skill section 7). "high" is a PC or console. "lowPerformance" is the Low performance setting on any device:
-- under the phone budget everywhere, with half the steady particles.
Presets.budget = {
	low = {
		animatedCats = 8,
		animRadius = 60,
		animHz = 30,
		steadyEmitters = 4,
		rateScale = 1,
		goldEmitters = 3,
		butterflies = 6,
		ambientRadius = 80,
		chimneyRadius = 140,
		burstScale = 0.5,
		maxBurst = 12,
		confetti = 14,
		napLabels = 4,
		rushLines = 2,
		signatureCats = 3,
		decorEffects = 2,
		potionGlows = 3,
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
		napLabels = 10,
		rushLines = 3,
		signatureCats = 6,
		decorEffects = 4,
		potionGlows = 6,
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
		napLabels = 2,
		rushLines = 1,
		signatureCats = 1,
		decorEffects = 0,
		potionGlows = 0,
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
	-- Ambient
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
	-- A faint twinkle over the owner's own Mystery Visitor gift while it waits (Mystery.luau).
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
	ring = { Common = 4, Rare = 5, Epic = 7, Legendary = 9, Mythical = 11 } :: { [string]: number },
	ringSeconds = 0.5,
	confetti = { Epic = 0.4, Legendary = 0.6, Mythical = 0.9 } :: { [string]: number },
	beams = { Legendary = true, Mythical = true } :: { [string]: boolean },
	beam = { width = 1.4, height = 16, seconds = 1.3 },
	echo = { after = 0.16, scale = 1.4, seconds = 0.7 }, -- the Mythical's second ring
	shower = { bursts = 3, after = 0.3, every = 0.25, height = 9 },
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
	barista = { tapEvery = 1.6, headDip = 12, paw = 35 },
	waiter = { sway = 5, swaySeconds = 1.8, step = 0.05 },
	greeter = { waveEvery = 3.2, wave = 70, tilt = 10 },
	entertainer = { swatEvery = 1.4, swat = 55, yarnStuds = 1.2 },
	-- Stuck in a rescue trap (Derek 2026-10-28: a different animation "for whatever cat is stuck in it", "like tail
	-- sticking out or butt", "make the butt sticking out for a lot of the rescue's", "flip the cats upside for some
	-- rescue missions where fit"). Each TrapType wriggles one of two ways (`kinds`), in bursts once every `every`
	-- seconds over `seconds` at `hz`, still moving `twitch` as much in between. `butt`: head first into a bin, can,
	-- bag pile, shed, log, pipe or grate with only its back end out: the hips wiggle `wiggle` degrees, the back legs
	-- paddle `kick` and the raised tail (`tailUp`) lashes `tail`. `flip`: upside down, hanging under a branch or a
	-- gutter or on its back in a bramble bush: all four legs pedal `legs` degrees in the air, the body rocks `rock`,
	-- the tail swings `tail`, the head looks about `look` and the ears go back `ears`. Where the cat sits and which
	-- way up is the server's stuck pose for the trap. A trap not in `kinds` keeps the plain shake (`every`, `shake`,
	-- `seconds`).
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
			tree = "flip",
			gutter = "flip",
			bramble_bush = "flip",
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
	},
	-- A sitting cat (the _Sit body, PR #259) washing a paw now and then (Derek 2026-10-27: the paw-up sit is a
	-- lick), the way a walking cat loafs: `hold` seconds of every `every`, by day. In bursts of `strokes` seconds a
	-- `pause` apart, the head bobs and the raised paw rubs at `hz` licks a second, eyes half shut.
	lick = {
		every = 60,
		hold = 9,
		strokes = 1.6,
		pause = 1.1,
		hz = 2.4,
		bob = 6,
		paw = 10,
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
}

-- Model-Agent's piece poses for the new bodies (manifest `cat_poses`, PR #259), copied here because the
-- manifest does not ship with the game: for each hinged piece, the turn about its own joint as
-- piece:PivotTo(piece:GetPivot() * CFrame.Angles(x, y, z)) in degrees (`angles_roblox_deg`), and how far the whole
-- cat drops (`lift_roblox` Y, studs at Scale 1). `body` is the body each is for, "walk" (A) or "sit" (B). Copy new
-- numbers here when the manifest changes. In the sleep and the loaf the folded legs also turn out to the sides (the
-- last angle, front 30 degrees, back 26), so the paws peek out a little (Derek 2026-10-27; in the manifest since #296).
export type CatPose = { body: string, lift: number, turns: { [string]: { number } } }
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

-- The net hold (Derek 2026-10-28: "have your character holding a net while walking around until catching a cat"),
-- drawn by Tackle.luau, the net itself by NetHold.luau: in a catching area, with no cat in the arms, the right hand
-- holds the player's net (CatCafe_Item_Net_L1 to L3 by its `Grip` attachment) upright and leaning ahead, the other
-- arm free to swing. The right shoulder is raised `sh` degrees forward, turned `tw` and out `sp`, the elbow bent
-- `el`, so the forearm points ahead; on R6, which has no elbow, the whole arm rises `sh6`. The pole leaves the fist
-- along the hand's back-to-front axis tipped `tilt` (R6: `tilt6`) degrees towards the fingers, so it leans
-- `sh + el + tilt` degrees up from straight ahead. The grip sits at the hand's own RightGripAttachment where it has
-- one, else `grip` studs from the hand's centre (`grip6` on R6). Within budget.animRadius; the arm eases in over
-- `blendIn` and out over `blendOut` seconds, and the net shows while the arm is past halfway (`showAt`).
Presets.netHold = {
	sh = 20,
	tw = 0,
	sp = 6,
	el = 80,
	sh6 = 70,
	tilt = -45,
	tilt6 = -15,
	grip = Vector3.new(0, -0.1, 0),
	grip6 = Vector3.new(0, -0.9, 0),
	blendIn = 0.25,
	blendOut = 0.2,
	showAt = 0.5,
}

-- The carry (Derek 2026-10-28: "hold it in your arms crossed arms", the cat "awake loafing or sitting in your
-- arms"), drawn by Tackle.luau on the carrier and by Carry.luau on the HeldCat. `arms` is the upper body's pose in
-- Avatar.Pose degrees (the legs stay the character's own): arms folded across the chest, the left forearm under the
-- right, head tipped down to the cat. R6 has no elbows, so `arms6` reaches both arms forward and in to meet under the
-- cat. The cat's floor sits `gap` studs over the higher forearm (below it: it sinks into the arms a little) and
-- `forward` studs further out, clear of the chest. Lying across the arms it turns `loafTurn` degrees (its face at the
-- character's left) and sitting up `sitTurn` (facing out); either way it moves `loafSide` or `sitSide` studs to the
-- right (negative: left), so its head is beside the character's, not in front of the face, and the game's camera
-- behind the player sees it over the shoulder. The arms ease in over `blendIn` and out over `blendOut` seconds.
Presets.carryPose = {
	arms = {
		shL = 60,
		twL = 45,
		spL = -45,
		elL = 45,
		shR = 60,
		twR = 45,
		spR = -45,
		elR = 58,
		neck = -12,
		waist = -4,
	} :: { [string]: number },
	arms6 = { sh = 80, sp = -30, neck = -12 } :: { [string]: number },
	gap = -0.15,
	forward = -0.8,
	loafTurn = 90,
	loafSide = -0.45,
	sitTurn = 15,
	sitSide = -0.55,
	blendIn = 0.2,
	blendOut = 0.2,
}

-- After a catch and after a miss (design v0.8, data-model section 10c). The getaway (F55): a net catch or rescue
-- pushes every other player within CatchBurstRadiusStuds (10) of the catcher away, so a ring as wide as that
-- spreads from the catcher's feet, and while their `RushUntil` runs (CatchRushSeconds, 5) speed lines stream off
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

Presets.gate = { seconds = 1.4, playWithin = 70 }

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
}

-- The Spin Wheel station (F49): the world wheel turns for everyone nearby whenever anyone spins and stops on the
-- won slice (LastSlice). It stops inside the server's 4 s SpinCooldownSeconds, so a player's next spin starts from
-- rest.
Presets.wheel = {
	seconds = 3.4, -- turning, easing to a stop
	turns = 3, -- whole turns before it settles
	stillTurns = 1, -- with Reduce Motion
	slices = 6, -- Catalog.spinWheel's six slices
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
	jackpot = 0.06,
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
	-- "Body" or "Head", or "Prop" / "Prop2" for the cat's first or second prop (parts named ..._Prop, ..._Prop2);
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
}

local palette = Presets.palette
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
	radius = 4,
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
	maxDistance = 160,
	hideWithin = 10,
	showAfter = 1, -- a hidden mark comes back only this far past hideWithin
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
}
-- The opened crate on the counter (crates.py's models, about 2.5 by 2 by 2 studs at full size): scaled down to sit on
-- the stall's ice, the lid swung up `lidDegrees` (crates.py: 105 is wide open with no clipping) over `lidSeconds`,
-- held for `hold` seconds from the open and faded over `fade`.
Presets.marketCrate = { scale = 0.6, lidDegrees = 105, lidSeconds = 0.3, hold = 1.8, fade = 0.4 }

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
export type DecorSpec = { look: string, on: string, emitter: string?, colors: { Color3 }? }
Presets.decor = {
	alley_midnight_sky = { look = "stars", on = "Wallpaper" },
	park_blossom_tree = { look = "petals", on = "model", emitter = "decorPetals" },
	neighbourhood_rainbow_shimmer = { look = "rainbow", on = "Paint" },
	woods_aurora_sky = { look = "aurora", on = "Wallpaper" },
	sewer_glimmer_canal = {
		look = "canal",
		on = "Floor",
		emitter = "decorGlint",
		colors = { palette.milk, palette.pastelSky },
	},
	classic_gold_leaf = {
		look = "goldLeaf",
		on = "Paint",
		emitter = "decorGlint",
		colors = { palette.offwhite, palette.goldLight },
	},
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
	-- fading to `faded` and back every `twinkle` seconds, diamonds from `diamondFrom` pixels.
	stars = {
		back = 16,
		side = 10,
		size = { 3, 7 },
		shown = { 0.05, 0.35 },
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
	-- degrees and drifting `drift` across over their `seconds`, with `stars` still stars a wall behind them.
	aurora = {
		bands = 3,
		height = 0.42,
		shown = 0.45,
		sway = 5,
		drift = 0.05,
		shimmer = 0.12,
		seconds = { 7, 9, 11 },
		stars = 6,
	},
	-- Glimmer Canal: light bands `width` wide sliding across the floor under the glass, each crossing in `seconds`.
	canal = { bands = 4, width = 0.16, shown = 0.78, tilt = 30, seconds = { 9, 15 } },
	-- Rainbow Shimmer: a rainbow tint over the cafe front that scrolls once across in `seconds`, lit like paint.
	rainbow = {
		shown = 0.78,
		seconds = 18,
		light = 0.6,
		colors = {
			palette.shirtRed,
			palette.golden,
			palette.leaf,
			palette.fishBlue,
			palette.aurora,
			palette.nosePink,
		},
	},
	-- Gold Leaf: a sheen `width` wide sweeping over the front, crossing it in a share of every `seconds`.
	sheen = { width = 0.08, shown = 0.45, tilt = 20, seconds = 7 },
	petalPad = 0.8, -- share of the tree's width the petals fall from
}

-- A stray's rarity gem (Derek 2026-10-28 01:25: "have some sort indicator of what rarity the cat is before going
-- up to it and looking at the name"): a small gem in the rarity colour (Presets.rarity) bobs `above` studs over each
-- stray whose rarity `shows`, `size` studs tall plus `pixels` so a far one still reads. It is a square turned 45
-- degrees, `gem` of the gui across, lit from the top (`light` of the way to white, `dark` to black at the bottom)
-- with a white edge; a Mythical one glints now and then. It hides within hideWithin studs, where the Catch card
-- shows the name, comes back past hideWithin + showAfter, and shows to maxDistance for the `most` nearest.
Presets.rarityMark = {
	shows = { Rare = true, Epic = true, Legendary = true, Mythical = true } :: { [string]: boolean },
	glints = { Mythical = true } :: { [string]: boolean },
	above = 0.9,
	size = 0.8,
	pixels = 16,
	gem = 0.62,
	corner = 0.18,
	light = 0.45,
	dark = 0.2,
	outline = Presets.palette.milk,
	outlinePixels = 2,
	bob = 0.15,
	bobSeconds = 0.9, -- one way
	glintSize = 0.34,
	glintSeconds = 0.3, -- one way
	glintEvery = 2.2,
	hideWithin = 10,
	showAfter = 1,
	maxDistance = 80,
	most = 12,
	checkEvery = 0.25,
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
} :: { [string]: PotionSpec }
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

return Presets
