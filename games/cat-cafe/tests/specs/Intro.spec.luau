--!strict
-- shared/Intro.luau: the intro cutscene's shots (F72, intro-cutscene.md section 2), their timing and captions, the
-- camera moves between their places, and the plot numbers the client works them out from.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Intro = require(Shared.Intro)
	local Layout = require(ServerScriptService.Server.World.Layout)

	local function near(a: Vector3, b: Vector3): boolean
		return (a - b).Magnitude < 1e-6
	end

	local EAST = Intro.plot(2) -- side +1
	local WEST = Intro.plot(1) -- side -1

	describe("the shots (section 2)", function()
		it("are nine shots of 23.7 s, each starting where the one before ends", function()
			local shots = Intro.shots(EAST, true)
			expect(#shots).to.equal(Intro.SHOTS)
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
			expect(Intro.length(shots)).to.be.near(23.7, 1e-9)
			local starts = {}
			for _, shot in shots do
				table.insert(starts, shot.starts)
			end
			expect(starts :: any).to.deepEqual({ 0, 3.5, 6, 9, 11.7, 13.5, 16, 18.7, 21.7 })
		end)

		it("keeps every caption to one phone line", function()
			for _, codesCat in { true, false } do
				for _, shot in Intro.shots(WEST, codesCat) do
					expect(#shot.caption > 0 and #shot.caption <= Intro.MAX_CAPTION).to.equal(true)
				end
			end
		end)

		it("names the Codes Cat in shot 7 only once one stands in the world", function()
			expect(Intro.shots(EAST, true)[7].caption).to.equal(Intro.CODES_CAPTION)
			expect(Intro.shots(EAST, false)[7].caption).to.equal(Intro.SPIN_CAPTION)
		end)

		it("cuts shot 5 four times, 0.45 s each, with the area title cards", function()
			local cuts = Intro.shots(EAST, true)[5].cuts
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
			expect(near(east[2].cuts[1].from.look, Vector3.new(stray.X, 1, stray.Z))).to.equal(true)
			expect(east[1].cuts[1].from.position.X).to.be.near(EAST.x - 30, 1e-9)
			expect(west[1].cuts[1].from.position.X).to.be.near(WEST.x + 30, 1e-9)
			expect(near(east[4].cuts[1].from.position, west[4].cuts[1].from.position)).to.equal(true)
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
	end)

	describe("shotAt (the shot Skip reports)", function()
		it("is the shot showing, 0 once the last has ended", function()
			local shots = Intro.shots(EAST, true)
			expect(Intro.shotAt(shots, 0)).to.equal(1)
			expect(Intro.shotAt(shots, 3.49)).to.equal(1)
			expect(Intro.shotAt(shots, 3.5)).to.equal(2)
			expect(Intro.shotAt(shots, 12)).to.equal(5)
			expect(Intro.shotAt(shots, 23.69)).to.equal(9)
			expect(Intro.shotAt(shots, 23.7)).to.equal(0)
			expect(Intro.shotAt(shots, 100)).to.equal(0)
		end)
	end)

	describe("keepCuts (an area that has not streamed in)", function()
		it("drops it and shares its time between the others", function()
			local shot = Intro.shots(EAST, true)[5]
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
			local shot = Intro.shots(EAST, true)[5]
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

		it("ends shot 9 behind and above the character, looking at its head", function()
			local key = Intro.follow(Vector3.new(10, 3, 20), Vector3.new(0, 0, 1))
			expect(near(key.position, Vector3.new(10, 3 + Intro.FOLLOW_UP, 20 - Intro.FOLLOW_BACK))).to.equal(true)
			expect(near(key.look, Vector3.new(10, 3 + Intro.HEAD_UP, 20))).to.equal(true)
			-- a character looking straight up or down still gets a place behind it
			local up = Intro.follow(Vector3.new(0, 0, 0), Vector3.new(0, 1, 0))
			expect(up.position.Y).to.equal(Intro.FOLLOW_UP)
		end)
	end)
end
