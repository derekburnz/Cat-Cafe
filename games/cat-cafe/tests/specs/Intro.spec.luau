--!strict
-- shared/Intro.luau: the intro cutscene's shots (F72, intro-cutscene.md section 2), their timing and captions, the
-- camera moves between their places, the catch, carry and job of shots 1 to 4 (section 2a), and the plot numbers the
-- client works them out from.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Intro = require(Shared.Intro)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Layout = require(ServerScriptService.Server.World.Layout)

	local function near(a: Vector3, b: Vector3): boolean
		return (a - b).Magnitude < 1e-6
	end

	local function flat(a: Vector3, b: Vector3): number
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	local EAST = Intro.plot(2) -- side +1
	local WEST = Intro.plot(1) -- side -1

	describe("the shots (section 2)", function()
		it("are ten shots of 25.5 s, each starting where the one before ends", function()
			local shots = Intro.shots(EAST, true)
			expect(#shots).to.equal(Intro.SHOTS)
			expect(Intro.SHOTS).to.equal(10)
			local at = 0
			for i, shot in shots do
				expect(shot.index).to.equal(i)
				expect(shot.starts).to.be.near(at, 1e-9)
				local cuts = 0
				for _, cut in shot.cuts do
					cuts += cut.seconds
				end
				expect(cuts).to.be.near(shot.seconds, 1e-9)
				at += shot.seconds
			end
			expect(Intro.length(shots)).to.be.near(25.5, 1e-9)
			local starts = {}
			for _, shot in shots do
				table.insert(starts, shot.starts)
			end
			expect(starts :: any).to.deepEqual({ 0, 3.5, 6, 8, 10.8, 13.5, 15.3, 17.8, 20.5, 23.5 })
		end)

		it("stages you in shots 1 to 4 only, with the catch, the run and the job each in its own shot", function()
			local shots = Intro.shots(EAST, true)
			local function which(flag: string): { number }
				local found = {}
				for i, shot in shots do
					if (shot :: any)[flag] then
						table.insert(found, i)
					end
				end
				return found
			end
			expect(which("you") :: any).to.deepEqual({ 1, 2, 3, 4 })
			expect(which("demo") :: any).to.deepEqual({ 1, 2 })
			expect(which("catch") :: any).to.deepEqual({ 2 })
			expect(which("run") :: any).to.deepEqual({ 3 })
			expect(which("job") :: any).to.deepEqual({ 4 })
			expect(which("spinWheel") :: any).to.deepEqual({ 8 })
			expect(which("night") :: any).to.deepEqual({ 9 })
			expect(which("follow") :: any).to.deepEqual({ 10 })
			expect(shots[3].caption).to.equal("Carry it home to your cafe!")
			expect(shots[4].caption).to.equal("Give it a job. Working cats earn tips!")
		end)

		it("keeps every caption to one phone line", function()
			for _, codesCat in { true, false } do
				for _, shot in Intro.shots(WEST, codesCat) do
					expect(#shot.caption > 0 and #shot.caption <= Intro.MAX_CAPTION).to.equal(true)
				end
			end
		end)

		it("names the Codes Cat in shot 8 only once one stands in the world", function()
			expect(Intro.shots(EAST, true)[8].caption).to.equal(Intro.CODES_CAPTION)
			expect(Intro.shots(EAST, false)[8].caption).to.equal(Intro.SPIN_CAPTION)
		end)

		it("cuts shot 6 four times, 0.45 s each, with the area title cards", function()
			local cuts = Intro.shots(EAST, true)[6].cuts
			local titles, areas = {}, {}
			for _, cut in cuts do
				expect(cut.seconds).to.be.near(0.45, 1e-9)
				table.insert(titles, cut.title)
				table.insert(areas, cut.area)
				-- each pushes 6% of the way toward its look point
				expect(near(cut.to.position, cut.from.position:Lerp(cut.from.look, Intro.CUT_PUSH))).to.equal(true)
			end
			expect(titles :: any).to.deepEqual({ "THE PARK", "THE NEIGHBOURHOOD", "THE WOODS", "THE SEWER" })
			expect(areas :: any).to.deepEqual({ "park", "neighbourhood", "woods", "sewer" })
		end)

		it("mirrors the plot shots for the west row and leaves the map shots alone", function()
			local east, west = Intro.shots(EAST, true), Intro.shots(WEST, true)
			expect(EAST.side).to.equal(1)
			expect(WEST.side).to.equal(-1)
			local stray = Intro.strayPoint(EAST)
			expect(near(east[1].cuts[1].to.look, Vector3.new(stray.X, 1, stray.Z))).to.equal(true)
			expect(east[1].cuts[1].from.position.X).to.be.near(EAST.x - 30, 1e-9)
			expect(west[1].cuts[1].from.position.X).to.be.near(WEST.x + 30, 1e-9)
			for _, index in { 3, 4 } do
				local e, w = east[index].cuts[1].from.position, west[index].cuts[1].from.position
				expect(e.X - EAST.x).to.be.near(-(w.X - WEST.x), 1e-9)
				expect(e.Y).to.be.near(w.Y, 1e-9)
			end
			expect(near(east[5].cuts[1].from.position, west[5].cuts[1].from.position)).to.equal(true)
		end)

		it("looks at the catch, midway between you and the stray, through shot 2", function()
			local cut = Intro.shots(EAST, true)[2].cuts[1]
			local you, stray = Intro.catchSpot(EAST), Intro.strayPoint(EAST)
			local catch = Vector3.new((you.X + stray.X) / 2, stray.Y + 1.5, (you.Z + stray.Z) / 2)
			expect(near(cut.from.look, catch)).to.equal(true)
			expect(near(cut.to.look, catch)).to.equal(true)
		end)

		it("films the run from the back alley behind you and the job from inside the cafe, under its ceiling", function()
			local W = Config.World
			for _, plot in { EAST, WEST } do
				local shots = Intro.shots(plot, true)
				for _, key in { shots[3].cuts[1].from, shots[3].cuts[1].to } do
					local x = math.abs(key.position.X)
					expect(x > W.AlleyInnerX and x < W.AlleyOuterX).to.equal(true)
					-- holding on the back door
					expect(near(key.look, Intro.plotPoint(plot, Intro.cafe.backDoor.x, 3.5, Intro.cafe.backDoor.z))).to.equal(true)
				end
				for _, key in { shots[4].cuts[1].from, shots[4].cuts[1].to } do
					expect(math.abs(key.position.X - plot.x) < W.PlotDepth / 2).to.equal(true)
					expect(math.abs(key.position.Z - plot.z) < W.PlotWidth / 2).to.equal(true)
					expect(key.position.Y < Intro.FLOOR_Y + W.WallHeight).to.equal(true)
				end
			end
		end)
	end)

	describe("the catch, the carry and the job (section 2a)", function()
		it("stands you 3.5 studs from the stray on the alley floor, on the line to your yard gate", function()
			for index = 1, Config.World.PlotCount do
				local plot = Intro.plot(index)
				local stray, you = Intro.strayPoint(plot), Intro.catchSpot(plot)
				local gate = Intro.plotPoint(plot, Intro.cafe.yardGate.x, 0, Intro.cafe.yardGate.z)
				expect(flat(you, stray)).to.be.near(Intro.CATCH_GAP, 1e-6)
				expect(flat(stray, you) + flat(you, gate)).to.be.near(flat(stray, gate), 1e-6)
				expect(you.Y).to.equal(stray.Y)
				local x = math.abs(you.X)
				expect(x > Config.World.AlleyInnerX and x < Config.World.AlleyOuterX).to.equal(true)
			end
		end)

		-- about 1.4 s from an east row cafe, whose tutorial stray waits 15 studs along the alley from its yard gate; a
		-- west row cafe's waits almost straight out of the gate, so its run is about 1 s
		it("runs you home through the yard gate and in at the back door, out of sight well before the shot ends", function()
			for _, plot in { EAST, WEST } do
				local path = Intro.runPath(plot)
				local cafe = Intro.cafe
				expect(#path).to.equal(4)
				expect(near(path[1], Intro.catchSpot(plot))).to.equal(true)
				expect(near(path[2], Intro.plotPoint(plot, cafe.yardGate.x, 0, cafe.yardGate.z))).to.equal(true)
				expect(near(path[3], Intro.plotPoint(plot, cafe.backDoor.x, 0, cafe.backDoor.z))).to.equal(true)
				expect(near(path[4], Intro.plotPoint(plot, cafe.introSpot.x, 0, cafe.introSpot.z))).to.equal(true)
				local seconds = Intro.TURN_SECONDS + Intro.pathSeconds(path, Intro.RUN_SPEED)
				expect(seconds > 0.9 and seconds < 1.45).to.equal(true)
				expect(seconds < Intro.shots(plot, true)[3].seconds).to.equal(true)
			end
			expect(Intro.RUN_SPEED).to.equal(Config.CatchRushWalkSpeed)
		end)

		it("steps you in from the back door to the intro spot at the start of shot 4", function()
			local steps = Intro.stepIn(EAST)
			expect(#steps).to.equal(2)
			expect(near(steps[1], Intro.runPath(EAST)[3])).to.equal(true)
			expect(near(steps[2], Intro.runPath(EAST)[4])).to.equal(true)
			expect(Intro.STEP_IN_SECONDS).to.equal(Intro.JOB_CARD_AT)
		end)

		it("walks a path: the start, along a leg, the corner and held at the end", function()
			local points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 5) }
			local at, facing = Intro.along(points, 0)
			expect(near(at, points[1])).to.equal(true)
			expect(near(facing, Vector3.new(1, 0, 0))).to.equal(true)
			at = Intro.along(points, 4)
			expect(near(at, Vector3.new(4, 0, 0))).to.equal(true)
			at, facing = Intro.along(points, 12)
			expect(near(at, Vector3.new(10, 0, 2))).to.equal(true)
			expect(near(facing, Vector3.new(0, 0, 1))).to.equal(true)
			at, facing = Intro.along(points, 100)
			expect(near(at, points[3])).to.equal(true)
			expect(near(facing, Vector3.new(0, 0, 1))).to.equal(true)
			expect(Intro.pathSeconds(points, 5)).to.be.near(3, 1e-9)
		end)

		it("times the hop, Skip and the job inside their shots", function()
			local shots = Intro.shots(EAST, true)
			expect(Intro.HOP_FROM).to.be.near(Intro.DEMO_PERFECT + 0.2, 1e-9)
			expect(Intro.HOP_FROM + Intro.HOP_SECONDS <= shots[2].seconds).to.equal(true)
			-- Skip can be pressed just after PERFECT, as the cat hops (5.0 s in all)
			expect(shots[2].starts + Intro.HOP_FROM).to.be.near(Intro.SKIP_AFTER, 1e-9)
			expect(Intro.JOB_CARD_AT < Intro.JOB_SEATED_AT).to.equal(true)
			expect(Intro.JOB_SEATED_AT < Intro.JOB_RATE_AT).to.equal(true)
			expect(Intro.JOB_RATE_AT < shots[4].seconds).to.equal(true)
		end)

		it("catches a Tuxedo, an Alleyway Common whose own role is the waiter job it gets", function()
			local def = Catalog.getCat(Intro.DEMO_CAT) :: any
			expect(def).to.be.ok()
			expect(def.rarity).to.equal("Common")
			expect(def.area).to.equal("alley")
			expect(def.favoriteRole).to.equal(Intro.JOB_ROLE)
			local spot = Catalog.getSpot(Intro.JOB_SPOT) :: any
			expect(spot.spotType).to.equal(Intro.JOB_ROLE)
			expect(spot.tier).to.equal(1)
			expect(Intro.demoName()).to.equal(def.name)
		end)

		it("tags the seated waiter with what a new cafe's Common waiter earns at Tier 1", function()
			local def = Catalog.getCat(Intro.DEMO_CAT) :: any
			local profile = ProfileSchema.template(0)
			local want = def.incomePerSecond
				* Config.FavoriteMultiplier
				* Economy.cafeMultiplier(profile)
				* Economy.tierMultiplier(profile)
			expect(Intro.demoRate() > 0).to.equal(true)
			expect(Intro.demoRate()).to.be.near(want, 1e-9)
		end)
	end)

	describe("the plot and the stray point match the server's Layout", function()
		it("puts every plot where Layout.plotPlacement does", function()
			for index = 1, Config.World.PlotCount do
				expect(Intro.plot(index) :: any).to.deepEqual(Layout.plotPlacement(index) :: any)
			end
		end)

		it("puts the demo cat on the tutorial stray's spawn point, alley point 2p - 1", function()
			for index = 1, Config.World.PlotCount do
				local point = (Layout.alley.spawnPoints :: any)[2 * index - 1]
				local at = Intro.strayPoint(Intro.plot(index))
				expect(near(at, Vector3.new(point.x, point.y, point.z))).to.equal(true)
			end
		end)

		it("lands a newcomer inside the cafe, in front of the back door, facing it", function()
			local spot = Layout.plot.introSpot
			expect(spot.x).to.equal(Layout.plot.backDoor.x)
			expect(math.abs(spot.x) < Config.World.PlotWidth / 2).to.equal(true)
			expect(spot.z > 0 and spot.z < Config.World.PlotDepth / 2).to.equal(true)
		end)

		it("uses Layout.plot's back door, yard gate, intro spot and waiter spot", function()
			local cafe, plot = Intro.cafe, Layout.plot
			expect(cafe.backDoor.x).to.equal(plot.backDoor.x)
			expect(cafe.backDoor.z).to.equal(Config.World.PlotDepth / 2)
			expect(cafe.yardGate.x).to.equal((plot.yardGate.x1 + plot.yardGate.x2) / 2)
			expect(cafe.yardGate.z).to.equal(plot.yard.z2)
			expect(cafe.introSpot.x).to.equal(plot.introSpot.x)
			expect(cafe.introSpot.z).to.equal(plot.introSpot.z)
			local waiter = plot.spots[Intro.JOB_SPOT]
			expect(cafe.waiterSpot.x).to.equal(waiter.x)
			expect(cafe.waiterSpot.z).to.equal(waiter.z)
		end)

		it("turns plot-local places into the world as WorldBuilder turns the plot", function()
			for index = 1, Config.World.PlotCount do
				local plot = Intro.plot(index)
				-- plot -Z faces the street, and the yard's back fence is the back alley's inner edge
				local front = Intro.plotPoint(plot, 0, 0, -Config.World.PlotDepth / 2)
				local gate = Intro.plotPoint(plot, Intro.cafe.yardGate.x, 0, Intro.cafe.yardGate.z)
				expect(math.abs(front.X) < math.abs(plot.x)).to.equal(true)
				expect(math.abs(gate.X)).to.be.near(Config.World.AlleyInnerX, 1e-9)
				expect(front.Y).to.equal(Intro.FLOOR_Y)
				-- plot +X runs along -Z on the east side, +Z on the west side
				local right = Intro.plotPoint(plot, 1, 0, 0)
				expect(right.Z - plot.z).to.be.near(-plot.side, 1e-9)
			end
		end)
	end)

	describe("shotAt (the shot Skip reports)", function()
		it("is the shot showing, 0 once the last has ended", function()
			local shots = Intro.shots(EAST, true)
			expect(Intro.shotAt(shots, 0)).to.equal(1)
			expect(Intro.shotAt(shots, 3.49)).to.equal(1)
			expect(Intro.shotAt(shots, 3.5)).to.equal(2)
			expect(Intro.shotAt(shots, 7)).to.equal(3)
			expect(Intro.shotAt(shots, 9)).to.equal(4)
			expect(Intro.shotAt(shots, 14)).to.equal(6)
			expect(Intro.shotAt(shots, 25.49)).to.equal(10)
			expect(Intro.shotAt(shots, 25.5)).to.equal(0)
			expect(Intro.shotAt(shots, 100)).to.equal(0)
		end)
	end)

	describe("keepCuts (an area that has not streamed in)", function()
		it("drops it and shares its time between the others", function()
			local shot = Intro.shots(EAST, true)[6]
			local kept = Intro.keepCuts(shot, function(cut)
				return cut.area ~= "woods"
			end)
			expect(#kept).to.equal(3)
			for _, cut in kept do
				expect(cut.area ~= "woods").to.equal(true)
				expect(cut.seconds).to.be.near(0.6, 1e-9)
			end
			expect(shot.cuts[3].seconds).to.be.near(0.45, 1e-9) -- the shot itself is left alone
		end)

		it("plays all four when none has streamed in", function()
			local shot = Intro.shots(EAST, true)[6]
			expect(#Intro.keepCuts(shot, function()
				return false
			end)).to.equal(4)
		end)
	end)

	describe("the camera moves", function()
		it("eases from 0 to 1 the TweenService Quad ways", function()
			for _, kind in { "InOut", "Out", "Linear" } do
				expect(Intro.ease(kind :: any, 0)).to.equal(0)
				expect(Intro.ease(kind :: any, 1)).to.equal(1)
				expect(Intro.ease(kind :: any, -1)).to.equal(0)
				expect(Intro.ease(kind :: any, 2)).to.equal(1)
			end
			expect(Intro.ease("InOut", 0.5)).to.be.near(0.5, 1e-9)
			expect(Intro.ease("InOut", 0.25)).to.be.near(0.125, 1e-9)
			expect(Intro.ease("Out", 0.5)).to.be.near(0.75, 1e-9)
		end)

		it("starts and ends on the cut's places and passes shot 1's via point halfway", function()
			local cut = Intro.shots(EAST, true)[1].cuts[1]
			local via = cut.via :: Intro.Key
			expect(near(Intro.at(cut, "InOut", 0).position, cut.from.position)).to.equal(true)
			expect(near(Intro.at(cut, "InOut", 1).position, cut.to.position)).to.equal(true)
			expect(near(Intro.at(cut, "InOut", 0.5).position, via.position)).to.equal(true)
			expect(near(Intro.at(cut, "InOut", 0.5).look, via.look)).to.equal(true)
		end)

		it("ends shot 10 behind and above the character, looking at its head", function()
			local key = Intro.follow(Vector3.new(10, 3, 20), Vector3.new(0, 0, 1))
			expect(near(key.position, Vector3.new(10, 3 + Intro.FOLLOW_UP, 20 - Intro.FOLLOW_BACK))).to.equal(true)
			expect(near(key.look, Vector3.new(10, 3 + Intro.HEAD_UP, 20))).to.equal(true)
			-- a character looking straight up or down still gets a place behind it
			local up = Intro.follow(Vector3.new(0, 0, 0), Vector3.new(0, 1, 0))
			expect(up.position.Y).to.equal(Intro.FOLLOW_UP)
		end)
	end)

	describe("the intro_cutscene event", function()
		it("carries version 2 since the shots moved", function()
			expect(Intro.VERSION).to.equal(2)
		end)

		it("every shot Skip can report passes the server's IntroDone guard, 0 to Intro.SHOTS (QA)", function()
			-- IntroService takes Guard.int(shot, 0, Intro.SHOTS): a whole number, 0 for finished
			for index = 1, Config.World.PlotCount do
				for _, codesCat in { true, false } do
					local shots = Intro.shots(Intro.plot(index), codesCat)
					local length = Intro.length(shots)
					local step = 0
					while step <= 3000 do
						local elapsed = step / 100
						local shot = Intro.shotAt(shots, elapsed)
						if shot ~= math.floor(shot) or shot < 0 or shot > Intro.SHOTS then
							error(string.format("plot %d at %.2f s reports shot %s", index, elapsed, tostring(shot)))
						end
						expect(shot == 0).to.equal(elapsed >= length)
						step += 1
					end
					-- the first play's Skip comes after SKIP_AFTER, in shot 2 or later, never in the catch's start
					expect(Intro.shotAt(shots, Intro.SKIP_AFTER) >= 2).to.equal(true)
				end
			end
		end)
	end)
end
