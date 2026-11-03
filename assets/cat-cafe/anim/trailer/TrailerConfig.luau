--!strict
-- The store page video's scene, in numbers (Animation-Engineer, 2026-11-03). Storyboard and shot list:
-- /mnt/project-files/Animation-Engineer/trailer/storyboard.md. TrailerDirector.server.luau stages the scene with the
-- game's own services and TrailerCamera.client.luau runs each take: the player's run, the shovers and the cameras.
-- Change a number here and press Play again; nothing here reaches the published game.
--
-- Places along the Alleyway are given as `depth` (studs into the Alleyway from the line of its name arch, the camp
-- lying at negative depth) and `across` (studs to the right of a player running home toward the camp, 0 the middle
-- of the 90 stud lane; keep it within 30 so nobody runs into the buildings' props).

local TrailerConfig = {}

export type Look = {
	hair: { number }, -- catalog hair accessory ids
	shirt: number,
	pants: number,
	face: number, -- 0 keeps the default smile
	skin: Color3,
	net: number, -- NetLevel 1 to 4, the net model in the hand (Basic, Sturdy, Pro, Master)
}

export type Shover = {
	look: Look,
	-- -1 comes in from the runner's left, 1 from the right, 0 head-on from in front
	side: number,
	depth: number, -- where on the run home the dive lands
	-- which way the runner cuts (-1 left, 1 right); nil is away from the shover, and right for a head-on one
	cut: number?,
}

-- Framing for a tracking shot, in the runner's own space: x to its right, y up from its middle (the root, 3 studs
-- off the floor), z behind it (-z ahead), the way CFrame offsets read. `from` is the camera, `at` what it looks at.
export type Framing = { from: Vector3, at: Vector3, fov: number }

-- The cat, and the cafe it ends up working in -------------------------------------------------------------------

TrailerConfig.star = "tortie" -- Rocker Cat (Rare, Alleyway, Entertainer by favourite role)
TrailerConfig.starSpot = "entertainer_1" -- where it works in the last shot (Catalog.spots)
TrailerConfig.tier = 3 -- Tier 3 opens entertainer_1
-- Given first, so they fill barista_2, waiter_1, waiter_2 and greeter_1 round the starter Tabby (barista_1) and the
-- star's check-in takes the next free spot, entertainer_1, by the game's own rule (CafeService.addCaughtCat).
TrailerConfig.cafeCats = { "tuxedo", "binbag", "ginger", "maine_coon" }
TrailerConfig.upgrades =
	{ tables = 4, espresso = 3, net = 2, lucky_cat = 2 } :: { [string]: number }
TrailerConfig.decor = { "plants", "rug", "neon_sign" } -- owned and put out (Catalog decor ids)
TrailerConfig.coins = 25000

-- The cast (the player's net is the one its save's net upgrade gives) ---------------------------------------------

local NEAR_WHITE = Color3.fromRGB(242, 243, 243)

-- Derek's rule for player shots (2026-11-02 16:51): the actual default Roblox avatar, R6, as it is.
TrailerConfig.hero = {
	hair = { 63690008 }, -- Pal Hair
	shirt = 144076358, -- Blue and Black Motorcycle Shirt
	pants = 144076760, -- Dark Green Jeans
	face = 616380929, -- Winning Smile (Laughing Fun is 226217449)
	skin = NEAR_WHITE,
	net = 2,
} :: Look

-- Three other players in Roblox's own free catalog items. One dive each on the run home, far end first.
TrailerConfig.shovers = {
	{
		look = {
			hair = { 376548738 }, -- Brown Charmer Hair
			shirt = 382537702, -- Teal Shirt
			pants = 382537569, -- Black Jeans
			face = 226217449, -- Laughing Fun
			skin = Color3.fromRGB(204, 142, 105),
			net = 3,
		},
		side = -1,
		depth = 160,
	},
	{
		look = {
			hair = { 451220849 }, -- Lavender Updo
			shirt = 382538295, -- Guitar Tee with Black Jacket
			pants = 398633812, -- Black Jeans with White Shoes
			face = 0,
			skin = Color3.fromRGB(255, 220, 190),
			net = 1,
		},
		side = 1,
		depth = 108,
	},
	{
		look = {
			hair = { 451221329 }, -- True Blue Hair
			shirt = 398635081, -- Blue Plaid Shirt
			pants = 382538503, -- Black Jeans with Sneakers
			face = 0,
			skin = Color3.fromRGB(124, 92, 70),
			net = 4,
		},
		side = 0,
		depth = 58,
		cut = 1,
	},
} :: { Shover }

-- The stage ----------------------------------------------------------------------------------------------------

TrailerConfig.starDepth = 205 -- where Rocker Cat waits, near the far end (the nooks are at about 245)
TrailerConfig.starAcross = -3
TrailerConfig.heroDepth = 140 -- where the player stands at the start, facing down the lane toward the cat
TrailerConfig.heroAcross = 2
TrailerConfig.swingStuds = 4 -- how close the player walks before the swing (the net reaches 8.5)

-- The dodges, in studs and seconds. The lunge itself is the Tackle's own (Config.TackleLungeStuds in
-- Config.TackleLungeSeconds, 12 studs in 0.35 s), and so are its timers for the belly slide and the get up.
TrailerConfig.dodge = {
	cutStuds = 9, -- how far across the runner cuts, landing 3 studs past the dive
	settleStuds = 4, -- where it runs on after the cut
	sideStart = 16, -- a side shover waits this far across from the runner's line, 6 studs nearer home
	headOnStart = 26, -- a head-on shover waits this far up the lane, 1.5 studs off the line away from the cut
	chargeLead = 22, -- a side shover starts running when the runner is this far short of the dive
	headOnChargeLead = 30,
	diveLead = 6, -- it dives when the runner is this far short of where the dive lands
	slideSeconds = 0.5, -- the belly slide on from the lunge, slowing to a stop
	chargeSpeed = { 8, 22 }, -- the slowest and fastest a shover runs to get into place
}

-- Seconds
TrailerConfig.timing = {
	autoStart = 6, -- a take starts this long after the scene is staged (or press T in the game view)
	establish = 4,
	settle = 0.25, -- the player turns to the cat and holds this long before the swing
	caught = 1.4, -- the player shows the cat in its arms before running home
	homeHold = 2.4, -- held on the camp after the check-in
	travelWait = 1.5, -- after the cafe is ready, before its shot
	cafe = 6.5, -- the push in on Rocker Cat at work
	endHold = 3, -- held for the logo
}

-- The cameras --------------------------------------------------------------------------------------------------

TrailerConfig.camera = {
	smooth = 10, -- how quickly a tracking camera catches up (higher is stiffer)
	-- shot 1: a high wide shot down the lane that sinks and pushes in toward the cat
	establishFrom = { depth = -10, across = 0, up = 40, lookDepth = 120 },
	establishTo = { depth = 70, across = 6, up = 16, lookDepth = 205 },
	establishFov = 60,
	approach = { from = Vector3.new(4, 0, 10), at = Vector3.new(0, 0, -12), fov = 65 } :: Framing,
	-- shot 3: from the net hand's side, level with the player's middle, between the player and the cat
	swingSide = 12,
	swingUp = 0.5,
	swingFov = 55,
	caught = { from = Vector3.new(1.5, -0.5, -8), at = Vector3.new(0, 0.6, 0), fov = 55 } :: Framing,
	-- shot 5a: in front, backing away; 5b: high to the side the runner cuts to; 5c: low in front. Each x is for a
	-- dodge whose runner cuts right, and flips for one that cuts left.
	run1 = { from = Vector3.new(-2, 1.5, -15), at = Vector3.new(0, 0, 0), fov = 65 } :: Framing,
	run2 = { from = Vector3.new(14, 13, -6), at = Vector3.new(0, -1, -3), fov = 60 } :: Framing,
	run3 = { from = Vector3.new(-4, -1.8, -13), at = Vector3.new(0, 0.3, 0), fov = 65 } :: Framing,
	-- shot 6: still, from behind in the lane, the arch framing the camp
	homeFrom = { depth = 42, across = 4, up = 7 },
	homeAt = { depth = -6, across = 0, up = 6 },
	homeFov = 60,
	homeCut = 26, -- the runner this close to the arch's line cuts to shot 6
	-- shot 7: from in front of Rocker Cat at work, pushing in (studs from the cat: x to its right, y up, z ahead)
	cafeFrom = Vector3.new(2, 4.5, 13),
	cafeTo = Vector3.new(1, 2.6, 6.5),
	cafeAt = 1.3, -- looks this high on the cat
	cafeFov = 55,
}

-- Screens left showing (every other ScreenGui of the game is hidden for the takes): the toasts, so the check-in's
-- "New cat!" line shows.
TrailerConfig.keepGuis = { CatCafeToasts = true } :: { [string]: boolean }
-- The game's markers in the world hidden too: the "run home" and tutorial markers over their targets (BillboardGuis in
-- the PlayerGui) and the tutorial's guide trail of dots on the ground (a folder of parts in the Workspace; QA-Planner
-- saw it on a fresh save, which the director moves past the tutorial anyway).
TrailerConfig.hideMarkers = { "CatCafeCarryMarker", "CatCafeTutorialMarker" }
TrailerConfig.hideWorld = { "CatCafeTutorialTrail" }

return TrailerConfig
