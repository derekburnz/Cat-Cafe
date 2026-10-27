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
	nosePink = Color3.fromRGB(224, 122, 140), -- 19 nose_pink
	leaf = Color3.fromRGB(95, 184, 90), -- 47 leaf_green
	fishBlue = Color3.fromRGB(110, 193, 255), -- 42 fish_blue
	neonPink = Color3.fromRGB(255, 107, 129), -- 53 neon_pink
	sparkle = Color3.fromRGB(255, 244, 176), -- 54 sparkle
	aurora = Color3.fromRGB(142, 124, 240), -- 58 aurora_violet
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
	shinySparkle = "", -- CatCafe_VFX_ShinySparkle.png (asset thread, PR #46) once uploaded
}

export type Budget = {
	animatedCats: number, -- cats whose head, tail and paws move at once
	animRadius: number, -- studs from the player within which a cat can move
	animHz: number, -- pose updates per second
	steadyEmitters: number, -- steam, chimney smoke and fireflies on at once
	shinyEmitters: number,
	butterflies: number,
	ambientRadius: number, -- studs; steam, butterflies and fireflies beyond it are off
	chimneyRadius: number, -- smoke reads from far away, so it gets a longer range
	burstScale: number, -- multiplies every burst count
	maxBurst: number, -- no single burst is bigger than this
	confetti: number, -- pieces in one confetti burst
	napLabels: number, -- napping cats that show floating z's
}

-- "low" is a phone or a tablet (touch with no keyboard): 150 live particles, bursts of 12, 4 steady emitters
-- (skill section 7). "high" is a PC or console.
Presets.budget = {
	low = {
		animatedCats = 8,
		animRadius = 60,
		animHz = 30,
		steadyEmitters = 4,
		shinyEmitters = 3,
		butterflies = 6,
		ambientRadius = 80,
		chimneyRadius = 140,
		burstScale = 0.5,
		maxBurst = 12,
		confetti = 14,
		napLabels = 4,
	},
	high = {
		animatedCats = 16,
		animRadius = 80,
		animHz = 60,
		steadyEmitters = 10,
		shinyEmitters = 8,
		butterflies = 14,
		ambientRadius = 110,
		chimneyRadius = 200,
		burstScale = 1,
		maxBurst = 30,
		confetti = 28,
		napLabels = 10,
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
		texture = Presets.textures.sparkle,
		colors = { Presets.palette.sparkle, Presets.palette.offwhite },
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
} :: { [string]: EmitterPreset }

-- Burst sizes before burstScale. A catch sparkle grows with rarity and stays under 30 (skill section 6).
Presets.bursts = {
	hissPuff = 10,
	smokePuff = 12,
	dust = 6,
	gateSparkle = 24,
	purrfect = 28,
}
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

-- Cat motion. Angles in degrees, distances in studs, times in seconds.
Presets.motion = {
	breathe = { studs = 0.03, seconds = 2.6 },
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
	stuck = { every = 2.6, shake = 9, seconds = 0.5 },
	nap = { headDroop = 10, breathe = 0.05, seconds = 3.2 },
}

Presets.shake = { seconds = 0.18, studs = 0.22 }

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
	roam = Vector3.new(2.4, 0.6, 1.8), -- half size of the box it loops around its flowers in
	height = 1.6,
	perSource = 2,
}

Presets.nap = { maxDistance = 45, riseSeconds = 2.4 }

Presets.gate = { seconds = 1.4, playWithin = 70 }

Presets.shutter = { seconds = 0.9, signSeconds = 0.6 }

Presets.rankUp = { within = 120, claimGrace = 2 }

return Presets
