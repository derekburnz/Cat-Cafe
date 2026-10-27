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
	stuck = { every = 2.6, shake = 9, seconds = 0.5 },
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
	-- A stretch (Derek 2026-10-27): as a cat wakes up, and every `every` to `everyMax` seconds while a stray stands
	-- still. On all fours it rises out of its pose over `rise` of the stretch, bows (front legs `reach` degrees
	-- ahead, body `bow` degrees nose down and `drop` studs lower, head up by `yawn`, tail up by `tail`, ears back by
	-- `ears`, eyes shut, the head kept nearly level), then rocks `rock` degrees forward and stretches each back leg `rear` degrees out behind.
	-- Sat up it leans back by `lean` and lifts both front paws `reachUp` degrees with the yawn.
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
		lean = 8,
		reachUp = 85,
		wakeDelay = 0.4, -- seconds after waking before it stretches
		wakeSpread = 1.5, -- and up to this much more, per cat, so a room waking at dawn does not stretch in unison
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
}

-- Model-Agent's piece poses for the new bodies (manifest `cat_poses`, PR #259), copied here because the
-- manifest does not ship with the game: for each hinged piece, the turn about its own joint as
-- piece:PivotTo(piece:GetPivot() * CFrame.Angles(x, y, z)) in degrees (`angles_roblox_deg`), and how far the whole
-- cat drops (`lift_roblox` Y, studs at Scale 1). `body` is the body each is for, "walk" (A) or "sit" (B). Copy new
-- numbers here when the manifest changes.
export type CatPose = { body: string, lift: number, turns: { [string]: { number } } }
Presets.catPoses = {
	sleep = {
		body = "walk",
		lift = 0.31,
		turns = {
			LegF1 = { -90, 0, 0 },
			LegF2 = { -90, 0, 0 },
			LegB1 = { 90, 0, 0 },
			LegB2 = { 90, 0, 0 },
			Head = { -26.8, 25.4, 12.2 },
			Tail = { 71.7, 49.6, -66.5 },
		},
	},
	loaf = {
		body = "walk",
		lift = 0.31,
		turns = {
			LegF1 = { -90, 0, 0 },
			LegF2 = { -90, 0, 0 },
			LegB1 = { 90, 0, 0 },
			LegB2 = { 90, 0, 0 },
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

-- A shove (F41): a puff where it lands, dizzy stars over the shoved player's head and, for them, a bigger
-- camera bump than a missed catch. The knockback itself is the engineer's, on the target's own client.
Presets.shove = {
	puff = 10, -- hissPuff particles where it lands
	starSeconds = 1.2,
	stars = 3,
	starRadius = 0.9,
	starHz = 1.4,
	shake = 0.3,
	shakeStuds = 0.4,
}

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

Presets.rankUp = { within = 120, claimGrace = 2 }

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
}

return Presets
