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
}
