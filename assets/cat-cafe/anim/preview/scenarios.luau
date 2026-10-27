--!nocheck
-- What dump.luau plays: which cat model, which styles (Logic.Style) for how long, and how fast the server walks
-- it (studs a second, straight ahead). `camera` is the view render.py takes: "side", "front" or "three".
return {
	-- A resting cat asleep on the walking body (A), curled up: the breath and nothing else.
	sleep = {
		model = "CatCafe_Cat_Ginger",
		camera = "three",
		segments = { { style = "nap", seconds = 6.4 } },
	},
	-- The same nap from the side, where the rise of the back reads best.
	sleepSide = {
		model = "CatCafe_Cat_Ginger",
		camera = "side",
		segments = { { style = "nap", seconds = 6.4 } },
	},
	-- A working cat dozing on the sitting body (B) at night.
	doze = {
		model = "CatCafe_Cat_Ginger_Sit",
		camera = "three",
		attributes = { Pose = "sit" },
		segments = { { style = "doze", seconds = 7.2 } },
	},
	-- A stray walking, then trotting faster, then standing.
	walk = {
		model = "CatCafe_Cat_Ginger",
		camera = "side",
		segments = {
			{ style = "stray", seconds = 0.6 },
			{ style = "stray", seconds = 3, speed = 4 },
			{ style = "stray", seconds = 1.2 },
		},
	},
}
