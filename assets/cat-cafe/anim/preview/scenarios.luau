--!nocheck
-- What dump.luau plays: which cat model, which styles (Logic.Style) for how long, and how fast the server walks
-- it (studs a second, straight ahead). `camera` is the view render.py takes: "side", "front" or "three". `role`
-- dresses a seated cat in that role's outfit, as at a station. The Tabby is the orange cat of Model-Agent's sheets.
return {
	-- A resting cat asleep on the walking body (A), curled up: the breath and nothing else.
	sleep = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		segments = { { style = "nap", seconds = 6.4 } },
	},
	-- The same nap from the side, where the rise of the back reads best.
	sleepSide = {
		model = "CatCafe_Cat_Tabby",
		camera = "side",
		segments = { { style = "nap", seconds = 6.4 } },
	},
	-- A working cat dozing on the sitting body (B) at night.
	doze = {
		model = "CatCafe_Cat_Tabby_Sit",
		role = "waiter",
		camera = "three",
		attributes = { Pose = "sit" },
		segments = { { style = "doze", seconds = 7.2 } },
	},
	-- A resting cafe cat by day: asleep, it sits up into its loaf for a while and curls back up. It is still resting,
	-- so no stretch (review S71); lying back down is the slower settle.
	loaf = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		segments = {
			{ style = "nap", seconds = 1.5 },
			{ style = "loaf", seconds = 4.5 },
			{ style = "nap", seconds = 3.5 },
		},
	},
	-- A stray standing still having a stretch.
	stretch = {
		model = "CatCafe_Cat_Tabby",
		camera = "side",
		segments = { { style = "stray", seconds = 4, stretch = true } },
	},
	-- A stray napping in a pause of its wander gets up when the server sets StretchAt, stretches onto all fours and,
	-- once the server stops waiting, walks off.
	strayNap = {
		model = "CatCafe_Cat_Tabby",
		camera = "side",
		segments = {
			{ style = "nap", seconds = 2.5 },
			{ style = "stray", seconds = 3.6, stretch = true },
			{ style = "stray", seconds = 3, speed = 3 },
		},
	},
	-- A stray wandering at StrayWanderSpeed (3, a walk), then trotting, then standing.
	walk = {
		model = "CatCafe_Cat_Tabby",
		camera = "side",
		segments = {
			{ style = "stray", seconds = 0.6 },
			{ style = "stray", seconds = 3, speed = 3 },
			{ style = "stray", seconds = 2, speed = 6 },
			{ style = "stray", seconds = 1 },
		},
	},
	-- The same walk from the front three quarters.
	walkThree = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		segments = {
			{ style = "stray", seconds = 0.4 },
			{ style = "stray", seconds = 3, speed = 3 },
		},
	},
	-- Balloon Cat (F78) bobbing as if it might float off, on the Tabby until Model-Agent's Balloon Cat is built (the
	-- motion only looks at CatId). A stray stands through four bobs, the fourth pulled higher, then wanders off.
	balloonStray = {
		model = "CatCafe_Cat_Tabby",
		camera = "side",
		attributes = { CatId = "balloon" },
		segments = {
			{ style = "stray", seconds = 8.8 },
			{ style = "stray", seconds = 2.6, speed = 3 },
		},
	},
	-- Asleep it floats half as high; `phase` starts it two bobs in, so the higher one comes round sooner.
	balloonNap = {
		model = "CatCafe_Cat_Tabby",
		camera = "side",
		phase = 4.4,
		attributes = { CatId = "balloon" },
		segments = { { style = "nap", seconds = 4.4 } },
	},
	-- At work on the sitting body (B) in the entertainer's outfit, its favourite role.
	balloonWork = {
		model = "CatCafe_Cat_Tabby_Sit",
		role = "entertainer",
		camera = "side",
		phase = 4.4,
		attributes = { Pose = "sit", CatId = "balloon" },
		segments = { { style = "entertainer", seconds = 4.4 } },
	},
	-- Stuck in a rescue trap (Derek 2026-10-28: the back end sticking out for most traps, upside down where it fits).
	-- A `trap` scenario puts the cat on the trap's own prop, a `trapSet` one on a trap built into an area set (spot
	-- and piece turn as Layout's setTrap has them). `stuckAt` is the pose tried (12 numbers in the prop's pivot space,
	-- or in the set trap spot's, as WorldBuilder applies them); without it a prop takes its Layout.stuckPoses entry.
	-- `box` frames the trap's opening.
	stuckBin = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trap = "CatCafe_Alley_TrashBin",
		stuckAt = { 0, 2.55, -0.57, -1, 0, 0, 0, 0, 1, 0, 1, 0 },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	-- Dived nose first into the top front of the big bag, 60 degrees down: back end up, back legs off the ground,
	-- tail over the top (Derek 14:17: the old shallow pose stood against the bag and looked off).
	stuckBags = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trap = "CatCafe_Alley_GarbageBags",
		stuckAt = { -0.45, 0.75, -0.8, -1, 0, 0, 0, 0.5, 0.866, 0, 0.866, -0.5 },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	stuckCan = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trap = "CatCafe_Park_TrashCan",
		stuckAt = { 0, 2.05, -0.65, -1, 0, 0, 0, 0, 1, 0, 1, 0 },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	stuckTree = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trap = "CatCafe_Park_RescueTree",
		stuckAt = { -2.2, 4.1, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
		segments = { { style = "stuckFlip", seconds = 4.4 } },
	},
	-- The Neighbourhood's garden shed: head first through the jammed door on the piece's -Z.
	stuckShed = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trapSet = {
			set = "CatCafe_Neighbourhood_SetV32",
			spot = { 126.4, 0, -89.3, 0 },
			radius = 6,
		},
		stuckAt = { 0, 0, 0.75, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
		box = { { -2, 0, -2 }, { 2, 3, 2 } },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	-- On its back across the bungalow's front gutter, 7.05 up by the downpipe: legs in the air and its head hanging
	-- out over the gutter's front edge (the piece's -Z), towards the street.
	stuckGutter = {
		model = "CatCafe_Cat_Tabby",
		camera = "low",
		trapSet = {
			set = "CatCafe_Neighbourhood_SetV32",
			spot = { -53.4, 7.05, -60.5, 180 },
			radius = 8,
		},
		stuckAt = { 0, 1.25, 0.1, -1, 0, 0, 0, -1, 0, 0, 0, 1 },
		box = { { -2.5, 6, -1.5 }, { 2.5, 9, 1.5 } },
		segments = { { style = "stuckFlip", seconds = 4.4 } },
	},
	-- The Woods' hollow log: head first into its open end on the piece's +X.
	stuckLog = {
		model = "CatCafe_Cat_Tabby",
		camera = "right",
		trapSet = { set = "CatCafe_Woods_SetV32", spot = { 78, 0, -40, 20 }, radius = 6 },
		stuckAt = { 3.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 },
		box = { { 1.5, 0, -2 }, { 5.5, 3, 2 } },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	-- Dived nose first into the bramble bush's top front, 70 degrees down so its head is just under the leaves, the
	-- back end, kicking back legs and tail out on top (Derek 14:17: lying on its back on top of the bush looked off).
	-- The Woods' other bramble (-86, 0, 30) is the same bush the same way round.
	stuckBramble = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trapSet = { set = "CatCafe_Woods_SetV32", spot = { -84, 0, -50, 0 }, radius = 4 },
		stuckAt = { 0, 2.56, -1.17, -1, 0, 0, 0, 0.342, 0.9397, 0, 0.9397, -0.342 },
		box = { { -2.5, 0.5, -2.5 }, { 2.5, 4.2, 2 } },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	-- Hanging upside down under the tree house's branch, which points along the piece's -X.
	stuckBranch = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trapSet = {
			set = "CatCafe_Woods_SetV32",
			spot = { -88.85, 15.45, 68.06, -106.26 },
			radius = 5,
		},
		stuckAt = { 0.5, -0.55, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
		box = { { -2, 12.8, -1.5 }, { 3, 15.6, 1.5 } },
		segments = { { style = "stuckFlip", seconds = 4.4 } },
	},
	-- Nose down through a Sewer grate, back end up.
	stuckGrate = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trapSet = { set = "CatCafe_Sewer_SetV32", spot = { -38, 0.4, -78, 0 }, radius = 4 },
		stuckAt = { 0, 0.45, -0.57, -1, 0, 0, 0, 0, 1, 0, 1, 0 },
		box = { { -2, 0, -2 }, { 2, 2.2, 2 } },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	-- Head first into a drain pipe's mouth, which faces the piece's -Z.
	stuckPipe = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		trapSet = { set = "CatCafe_Sewer_SetV32", spot = { 81.7, 0.4, -77, 90 }, radius = 4 },
		stuckAt = { 0, 0.55, 0.5, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
		box = { { -1.6, 0.4, -1.5 }, { 1.6, 2.8, 2 } },
		segments = { { style = "stuckButt", seconds = 4.4 } },
	},
	-- The carry (Derek 2026-10-28): held on the stand-in player's folded arms, awake. Loafing across the arms on the
	-- walking body (what the server's HeldCat is), standing a moment and then carried at CarryWalkSpeed (16).
	carryLoaf = {
		model = "CatCafe_Cat_Tabby",
		camera = "three",
		carrier = { shirt = "red" },
		segments = {
			{ style = "held", seconds = 3.4 },
			{ style = "held", seconds = 2.6, speed = 16 },
		},
	},
	-- Sitting up on the arms, facing out, on the sitting body.
	carrySit = {
		model = "CatCafe_Cat_Tabby_Sit",
		camera = "three",
		attributes = { Pose = "sit" },
		carrier = { shirt = "blue", skin = "tan" },
		segments = {
			{ style = "held", seconds = 3.4 },
			{ style = "held", seconds = 2.6, speed = 16 },
		},
	},
}
