--!strict
-- The intro cutscene's shots (F72, docs/design/cat-cafe/intro-cutscene.md section 2): when each starts, its caption,
-- and where the camera flies, worked out from the player's own plot. Studs, y up. Shots 1 to 3 follow the plot
-- (`x`, `z` and `side`, -1 for the west row and +1 for the east row, the street toward -side); the rest follow the
-- Config.World points they look at (town layout v3, F76: intro-cutscene.md section 2b), so a layout change moves
-- them too. The positions are starting points to tune in Studio. Pure apart from Vector3.

local Config = require(script.Parent.Config)

local Intro = {}

Intro.SHOTS = 9
Intro.SKIP_AFTER = 5.0 -- seconds into the first play before Skip can be pressed (its bar fills until then; Derek 00:57); a replay allows it at once
Intro.MAX_CAPTION = 46 -- characters, so a caption fits one line on a phone ("about 45"; shot 8's is 46)
Intro.CUT_PUSH = 0.06 -- shot 5: each area cut pushes this share of the way toward its look point

-- Shot 2's demo catch, in seconds into the shot: the ring closes to PERFECT, then the demo cat fades.
Intro.DEMO_PERFECT = 1.3
Intro.DEMO_FADE = 1.9
Intro.DEMO_HIDE_RADIUS = 4 -- real strays this close to the demo cat are hidden for shots 1 and 2

-- Shot 8, in seconds into the shot: dusk, a short night and sunrise on this screen only.
Intro.NIGHT_FROM = 0.35
Intro.NIGHT_TO = 0.95
Intro.SUNRISE_FROM = 1.8
Intro.SUNRISE_TO = 2.3
Intro.STRAYS_OUT_FROM = 0.45 -- the back alleys' strays fade out
Intro.STRAYS_OUT_TO = 0.85
Intro.SUNRISE_STRAYS_AT = 2.1 -- fresh local strays pop in from here
Intro.SUNRISE_STRAYS = 10
Intro.SUNRISE_STRAY_GAP = 0.04 -- seconds between pops
Intro.STRAY_AREA = "alley" -- shot 8's strays that fade out and pop back in are this area's (v3.1: the back alleys)

-- Shot 9 lands this far behind and above the character, looking at its head.
Intro.FOLLOW_BACK = 12
Intro.FOLLOW_UP = 6
Intro.HEAD_UP = 1.5

Intro.CODES_CAPTION = "Free spin every day. Codes at the Codes Cat!"
Intro.SPIN_CAPTION = "Spin the wheel for a free prize every day!" -- shot 7 before a Codes Cat stands in the world

export type Ease = "InOut" | "Out" | "Linear"
export type Plot = { x: number, z: number, side: number }
-- One camera place: where it is and what it looks at.
export type Key = { position: Vector3, look: Vector3 }
-- One continuous move. `via` bends it through a third place halfway; `area` names the area a shot 5 cut shows,
-- which is skipped when that area has not streamed in.
export type Cut = { from: Key, to: Key, via: Key?, seconds: number, title: string?, area: string? }
export type Shot = {
	index: number,
	starts: number,
	seconds: number,
	caption: string,
	ease: Ease,
	cuts: { Cut },
	follow: boolean?, -- shot 9: the last cut ends behind the character (Intro.follow), not at `to`
	spinWheel: boolean?, -- shot 7: the world wheel turns two spins on this screen
	night: boolean?, -- shot 8: night falls and the sun rises on this screen
	demo: boolean?, -- shot 2: the demo catch at the tutorial stray point
	roof: boolean?, -- shot 3: the own cafe's roof fades as it does for an owner inside
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function key(position: Vector3, look: Vector3): Key
	return { position = position, look = look }
end

-- A shot 5 cut: from `position` toward `look`, pushing CUT_PUSH of the way.
local function push(position: Vector3, look: Vector3, title: string, area: string): Cut
	local to = position + (look - position) * Intro.CUT_PUSH
	return {
		from = key(position, look),
		to = key(to, look),
		seconds = 0.45,
		title = title,
		area = area,
	}
end

-- Where plot `index` (1-based) stands: the same numbers as the server's Layout.plotPlacement (a test checks they
-- match), so the client needs neither the server module nor the plot to have streamed in.
function Intro.plot(index: number): Plot
	local W = Config.World
	local i = index - 1
	local side = if i % 2 == 0 then -1 else 1
	local pair = math.floor(i / 2)
	local north = if pair % 2 == 0 then -1 else 1
	local ring = math.floor(pair / 2)
	local z = north
		* (
			W.TownSquareHalfDepth
			+ W.PlotRowGap
			+ W.PlotWidth / 2
			+ ring * (W.PlotWidth + W.PlotRowGap)
		)
	local x = side * (W.StreetHalfWidth + 2 + W.FrontGardenDepth + 1 + W.PlotDepth / 2)
	return { x = x, z = z, side = side }
end

-- The tutorial stray point behind a plot, on the alley floor: the lane spawn point 2p - 1 (Layout's alley points).
function Intro.strayPoint(plot: Plot): Vector3
	return v((Config.World.AlleyInnerX + 7) * plot.side, 0.1, plot.z - 7)
end

-- The nine shots for this plot. `codesCat` is false until a Codes Cat station stands in the Workspace (F65).
function Intro.shots(plot: Plot, codesCat: boolean): { Shot }
	local W = Config.World
	local px, pz, s = plot.x, plot.z, plot.side
	local lane = W.AlleyInnerX -- the back alley's inner edge
	local stray = v((lane + 7) * s, 1, pz - 7)
	-- the west Alleyway Index Board, 8 inside the Town Square's west side arch (intro-cutscene.md 2c, v3.1)
	local board = v(-(lane + 8), 4, -9)
	local town = v(0, 0, -20) -- shot 8 looks up the whole town from the south, both back alleys in frame
	local parkGate = W.ParkGateZ
	-- the Town Square sits at the origin: the fountain, and the west quarters' Spin Wheel and Codes Cat
	local fountain = v(0, 2, 0)
	local stations = v(-28, 4, 0)
	local shots: { Shot } = {
		{
			index = 1,
			starts = 0,
			seconds = 3.5,
			caption = "Catch stray cats behind your cafe!",
			ease = "InOut",
			demo = true,
			cuts = {
				{
					-- one crane from the street over the roof into the alley
					from = key(v(px - 30 * s, 9, pz - 6), v(px - 14.3 * s, 7, pz)),
					via = key(v(px, 38, pz - 10), v(px + 20 * s, 0, pz - 7)),
					to = key(v((lane + 1) * s, 7, pz - 17), stray),
					seconds = 3.5,
				},
			},
		},
		{
			index = 2,
			starts = 3.5,
			seconds = 2.5,
			caption = "Tap as each circle closes!",
			ease = "Linear",
			demo = true,
			cuts = {
				{
					from = key(v((lane + 2) * s, 4.5, pz - 15), stray),
					to = key(v((lane + 4) * s, 3.2, pz - 12), stray),
					seconds = 2.5,
				},
			},
		},
		{
			index = 3,
			starts = 6,
			seconds = 3,
			caption = "Bring cats home. Give them jobs. Earn tips!",
			ease = "InOut",
			roof = true,
			cuts = {
				{
					from = key(v(px - 6 * s, 22, pz - 18), v(px + 6 * s, 1, pz - 4)),
					to = key(v(px - 8 * s, 18, pz - 8), v(px + 8 * s, 2, pz)),
					seconds = 3,
				},
			},
		},
		{
			index = 4,
			starts = 9,
			seconds = 2.7,
			caption = "Rank up your cafe to open new areas",
			ease = "InOut",
			cuts = {
				{
					from = key(v(0, 45, parkGate + 111), v(0, 0, parkGate + 61)),
					to = key(v(0, 12, parkGate + 19), v(0, 4, parkGate - 1)),
					seconds = 2.7,
				},
			},
		},
		{
			index = 5,
			starts = 11.7,
			seconds = 1.8,
			caption = "Every area has its own cats",
			ease = "Linear",
			cuts = {
				push(v(0, 40, parkGate + 6), v(0, 0, W.ParkCenterZ - 2), "THE PARK", "park"),
				push(
					v(W.NeighbourhoodCenterX, 60, W.NeighbourhoodGateZ + 8.5),
					v(W.NeighbourhoodCenterX, 0, W.NeighbourhoodCenterZ + 5.5),
					"THE NEIGHBOURHOOD",
					"neighbourhood"
				),
				-- v3.1: the Woods and the Sewer lie west and east, seen from just outside their side gates
				push(
					v(W.WoodsGateX + 5, 45, W.WoodsCenterZ),
					v(W.WoodsCenterX + 5, 0, W.WoodsCenterZ),
					"THE WOODS",
					"woods"
				),
				push(
					v(W.SewerGateX - 5, 40, W.SewerCenterZ),
					v(W.SewerCenterX - 4, 0, W.SewerCenterZ),
					"THE SEWER",
					"sewer"
				),
			},
		},
		{
			index = 6,
			starts = 13.5,
			seconds = 2.5,
			caption = "Find all 50 cats for Index rewards",
			ease = "Out",
			cuts = {
				{
					-- from the square's east to west lane, through the west side arch at the board, clear of its south pillar
					from = key(v(-(lane - 3), 5, -1), board),
					to = key(v(-(lane + 1.5), 4.5, -6.5), board),
					seconds = 2.5,
				},
			},
		},
		{
			index = 7,
			starts = 16,
			seconds = 2.7,
			caption = if codesCat then Intro.CODES_CAPTION else Intro.SPIN_CAPTION,
			ease = "InOut",
			spinWheel = true,
			cuts = {
				{
					-- a hard cut, then down into the Town Square from its south side until the Spin Wheel and the
					-- Codes Cat are both in frame
					from = key(v(0, 24, -(W.TownSquareHalfDepth + 4)), fountain),
					to = key(v(-8, 10, 0), stations),
					seconds = 2.7,
				},
			},
		},
		{
			index = 8,
			starts = 18.7,
			seconds = 3,
			caption = "Night closes the areas. Fresh cats at sunrise!",
			ease = "Linear",
			night = true,
			cuts = {
				{
					from = key(v(0, 80, -150), town),
					to = key(v(0, 76, -144), town),
					seconds = 3,
				},
			},
		},
		{
			index = 9,
			starts = 21.7,
			seconds = 2,
			caption = "Go catch your first cat!",
			ease = "InOut",
			follow = true,
			cuts = {
				{
					-- `to` becomes the follow point at play time (Intro.follow); the swoop to a north row cafe, up to
					-- about 250 studs, bends through a point over the square
					from = key(v(0, 76, -144), town),
					via = if pz > 0 then key(v(0, 45, 0), v(0, 2, 0)) else nil,
					to = key(v(0, 76, -144), town),
					seconds = 2,
				},
			},
		},
	}
	return shots
end

-- The whole intro's length: where the last shot ends.
function Intro.length(shots: { Shot }): number
	local last = shots[#shots]
	return last.starts + last.seconds
end

-- The shot showing `elapsed` seconds in, or 0 once the last one has ended.
function Intro.shotAt(shots: { Shot }, elapsed: number): number
	for i = #shots, 1, -1 do
		if elapsed >= shots[i].starts then
			return if elapsed < shots[i].starts + shots[i].seconds then i else 0
		end
	end
	return 1
end

-- Shot 5's cuts that `streamed` says are there, sharing the shot's whole time between them, so a skipped area
-- gives its time to the others. With none streamed in, all four play anyway.
function Intro.keepCuts(shot: Shot, streamed: (Cut) -> boolean): { Cut }
	local kept: { Cut } = {}
	for _, cut in shot.cuts do
		if streamed(cut) then
			table.insert(kept, cut)
		end
	end
	if #kept == 0 then
		kept = table.clone(shot.cuts)
	end
	local out: { Cut } = {}
	for _, cut in kept do
		local copy = table.clone(cut)
		copy.seconds = shot.seconds / #kept
		table.insert(out, copy)
	end
	return out
end

-- The eased share of a move `t` (0 to 1) of the way through, the curves TweenService calls Quad.
function Intro.ease(kind: Ease, t: number): number
	t = math.clamp(t, 0, 1)
	if kind == "InOut" then
		return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
	elseif kind == "Out" then
		return 1 - (1 - t) ^ 2
	end
	return t
end

-- A point `u` (0 to 1, already eased) of the way from a to c. With b it is the curve that leaves a, passes
-- through b at u = 0.5 and ends at c, so a via point bends the move without a corner.
local function along(a: Vector3, b: Vector3?, c: Vector3, u: number): Vector3
	if b == nil then
		return a:Lerp(c, u)
	end
	local control = b * 2 - (a + c) / 2
	return a * ((1 - u) * (1 - u)) + control * (2 * u * (1 - u)) + c * (u * u)
end

-- Where the camera is and looks `t` (0 to 1) of the way through a cut, with the shot's ease.
function Intro.at(cut: Cut, ease: Ease, t: number): Key
	local u = Intro.ease(ease, t)
	local via = cut.via
	return {
		position = along(
			cut.from.position,
			if via ~= nil then via.position else nil,
			cut.to.position,
			u
		),
		look = along(cut.from.look, if via ~= nil then via.look else nil, cut.to.look, u),
	}
end

-- Shot 9's end: FOLLOW_BACK behind and FOLLOW_UP above a character standing at `root`, looking at its head.
function Intro.follow(rootPosition: Vector3, facing: Vector3): Key
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local back = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	return {
		position = rootPosition - back * Intro.FOLLOW_BACK + Vector3.new(0, Intro.FOLLOW_UP, 0),
		look = rootPosition + Vector3.new(0, Intro.HEAD_UP, 0),
	}
end

return Intro
