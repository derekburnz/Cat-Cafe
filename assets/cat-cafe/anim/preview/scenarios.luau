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
	-- A waiter waking at dawn in its seat at the station: the seated reach and yawn, then back to work.
	wakeSit = {
		model = "CatCafe_Cat_Tabby_Sit",
		role = "waiter",
		camera = "three",
		attributes = { Pose = "sit" },
		segments = { { style = "doze", seconds = 1.5 }, { style = "waiter", seconds = 4.5 } },
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
}
