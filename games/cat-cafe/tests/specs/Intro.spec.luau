--!strict
-- shared/Intro.luau: the intro cutscene's shots (F72, intro-cutscene.md section 2, v3 for the hometown and the Cat
-- Cannon, F84), their timing and captions, the camera moves between their places, the flight, the catch, the carry
-- into the Alleyway's camp and the job (section 2a), and the plot and camp numbers the client works them out from.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Intro = require(Shared.Intro)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Layout = require(ServerScriptService.Server.World.Layout)

	local function near(a: Vector3, b: Vector3, within: number?): boolean
		return (a - b).Magnitude < (within or 1e-6)
	end

	local function flat(a: Vector3, b: Vector3): number
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	local function inside(rect: any, at: Vector3): boolean
		return at.X >= rect.x1 and at.X <= rect.x2 and at.Z >= rect.z1 and at.Z <= rect.z2
	end

	local EAST = Intro.plot(2) -- side +1
	local WEST = Intro.plot(1) -- side -1
	local CAMP = Intro.camp("alley") :: Intro.Camp

	describe("the shots (section 2)", function()
		it("are ten shots of 24.3 s, each starting where the one before ends", function()
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
			expect(Intro.length(shots)).to.be.near(24.3, 1e-9)
			local starts = {}
			for _, shot in shots do
				table.insert(starts, math.floor(shot.starts * 10 + 0.5) / 10)
			end
			expect(starts :: any).to.deepEqual({ 0, 2.5, 5, 7.5, 9.5, 12.3, 14.1, 16.6, 19.3, 22.3 })
		end)

		it(
			"stages you in shots 1 to 4, the flight in 1 and 2, the catch, the carry and the job each in its own",
			function()
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
				expect(which("cannon") :: any).to.deepEqual({ 1, 2 })
				expect(which("launch") :: any).to.deepEqual({ 1 })
				expect(which("flight") :: any).to.deepEqual({ 2 })
				expect(which("catch") :: any).to.deepEqual({ 3 })
				expect(which("run") :: any).to.deepEqual({ 4 })
				expect(which("job") :: any).to.deepEqual({ 5 })
				expect(which("camp") :: any).to.deepEqual({ 3, 4, 7 })
				expect(which("spinWheel") :: any).to.deepEqual({ 8 })
				expect(which("night") :: any).to.deepEqual({ 9 })
				expect(which("follow") :: any).to.deepEqual({ 10 })
				expect(shots[1].caption).to.equal("Fly the Cat Cannon to catch stray cats!")
				expect(shots[4].caption).to.equal("Carry it into the camp to keep it!")
				expect(shots[10].caption).to.equal("Your first cat is waiting in the Alleyway!")
			end
		)

		it("keeps every caption to one phone line", function()
			for _, codesCat in { true, false } do
				for _, streamed in { true, false } do
					for _, shot in Intro.shots(WEST, codesCat, streamed) do
						expect(#shot.caption > 0 and #shot.caption <= Intro.MAX_CAPTION).to.equal(
							true
						)
					end
				end
			end
		end)

		it("names the Codes Cat in shot 8 only once one stands in the world", function()
			expect(Intro.shots(EAST, true)[8].caption).to.equal(Intro.CODES_CAPTION)
			expect(Intro.shots(EAST, false)[8].caption).to.equal(Intro.SPIN_CAPTION)
		end)

		it(
			"leaves out shots 3, 4 and 7 when the Alleyway's camp has not streamed in, about 7 s shorter",
			function()
				local shots = Intro.shots(EAST, true, false)
				local indexes = {}
				local at = 0
				for _, shot in shots do
					table.insert(indexes, shot.index)
					expect(shot.starts).to.be.near(at, 1e-9)
					at += shot.seconds
				end
				expect(indexes :: any).to.deepEqual({ 1, 2, 5, 6, 8, 9, 10 })
				expect(Intro.length(shots)).to.be.near(24.3 - 7, 1e-9)
				-- shot 2 holds the clouds to its end instead of cutting to the camp
				local cuts = shots[2].cuts
				expect(near(cuts[#cuts].from.position, cuts[1].to.position)).to.equal(true)
				expect(near(cuts[#cuts].to.position, cuts[1].to.position)).to.equal(true)
			end
		)

		it(
			"cranes from your cafe front to the cannon in shot 1 and mirrors it for the west row",
			function()
				local east, west = Intro.shots(EAST, true), Intro.shots(WEST, true)
				expect(EAST.side).to.equal(1)
				expect(WEST.side).to.equal(-1)
				expect(east[1].cuts[1].from.position.X).to.be.near(EAST.x - 30, 1e-9)
				expect(west[1].cuts[1].from.position.X).to.be.near(WEST.x + 30, 1e-9)
				for _, shots in { east, west } do
					local cut = shots[1].cuts[1]
					expect(near(cut.to.position, Vector3.new(10, 8, -18))).to.equal(true)
					expect(near(cut.to.look, Vector3.new(0, 6, 0))).to.equal(true)
					expect((cut.via :: Intro.Key).position.Y).to.equal(30)
					-- shot 2 starts where shot 1 ends
					expect(near(shots[2].cuts[1].from.position, cut.to.position)).to.equal(true)
				end
				-- everything after shot 1 is the same for every plot but the job inside your own cafe
				for i = 2, Intro.SHOTS do
					if i ~= 5 then
						expect(near(east[i].cuts[1].from.position, west[i].cuts[1].from.position)).to.equal(
							true
						)
					end
				end
			end
		)

		it(
			"cuts shot 6 four times, 0.45 s each, high over each camp looking into its area",
			function()
				local cuts = Intro.shots(EAST, true)[6].cuts
				local titles, areas = {}, {}
				for _, cut in cuts do
					expect(cut.seconds).to.be.near(0.45, 1e-9)
					table.insert(titles, cut.title)
					table.insert(areas, cut.area)
					-- each pushes 6% of the way toward its look point
					expect(
						near(cut.to.position, cut.from.position:Lerp(cut.from.look, Intro.CUT_PUSH))
					).to.equal(true)
					local camp = Layout.camps[cut.area :: string]
					expect(Layout.campAt(cut.from.position.X, cut.from.position.Z)).to.equal(
						cut.area
					)
					expect(cut.from.position.Y - camp.origin.y).to.be.near(24, 1e-6)
					expect(Layout.campAt(cut.from.look.X, cut.from.look.Z)).to.equal(nil)
					-- the look point is just past the gate, inside the area
					local mine = Intro.camp(cut.area :: string) :: Intro.Camp
					expect((cut.from.look - mine.origin):Dot(mine.u)).to.be.near(10, 1e-6)
				end
				expect(titles :: any).to.deepEqual({
					"THE PARK",
					"THE NEIGHBOURHOOD",
					"THE WOODS",
					"THE SEWER",
				})
				expect(areas :: any).to.deepEqual({ "park", "neighbourhood", "woods", "sewer" })
			end
		)

		it(
			"cuts shot 2 under the clouds to behind the Alleyway's pad, looking out through the way out",
			function()
				local cuts = Intro.shots(EAST, true)[2].cuts
				expect(#cuts).to.equal(3)
				expect(cuts[1].seconds).to.be.near(Intro.PUFF_AT, 1e-9)
				expect(cuts[1].seconds + cuts[2].seconds).to.be.near(Intro.CUT_AT, 1e-9)
				for _, key in { cuts[3].from, cuts[3].to } do
					expect(Layout.campAt(key.position.X, key.position.Z)).to.equal("alley")
					-- behind the pad, toward the camp cannon, looking past it into the area
					expect((key.position - CAMP.pad):Dot(CAMP.u) < 0).to.equal(true)
					expect((key.look - key.position):Dot(CAMP.u) > 0).to.equal(true)
				end
			end
		)

		it(
			"films the catch from the side away from the camp, square to you and the stray",
			function()
				local cut = Intro.shots(EAST, true)[3].cuts[1]
				local you, stray = Intro.catchSpot(), Intro.strayPoint()
				local catch = (you + stray) / 2 + Vector3.new(0, 1.5, 0)
				expect(near(cut.from.look, catch)).to.equal(true)
				expect(near(cut.to.look, catch)).to.equal(true)
				expect(flat(cut.from.position, catch)).to.be.near(9, 1e-6)
				expect(flat(cut.to.position, catch)).to.be.near(6.5, 1e-6)
				local line = (stray - you).Unit
				expect(math.abs((cut.from.position - catch):Dot(line)) < 1e-6).to.equal(true)
				expect((cut.from.position - catch):Dot(CAMP.u) > 0).to.equal(true)
			end
		)

		it(
			"films the run from inside the camp, behind the basket, and the board from its front",
			function()
				local shots = Intro.shots(EAST, true)
				for _, key in { shots[4].cuts[1].from, shots[4].cuts[1].to } do
					expect(Layout.campAt(key.position.X, key.position.Z)).to.equal("alley")
					expect((key.position - CAMP.basket):Dot(CAMP.wayOut - CAMP.basket) < 0).to.equal(
						true
					)
				end
				expect(flat(shots[4].cuts[1].to.position, shots[4].cuts[1].from.position)).to.be.near(
					2,
					1e-6
				)
				for _, key in { shots[7].cuts[1].from, shots[7].cuts[1].to } do
					expect(Layout.campAt(key.position.X, key.position.Z)).to.equal("alley")
					expect((key.position - CAMP.board):Dot(CAMP.boardFacing) > 0).to.equal(true)
					expect(near(key.look, CAMP.board + Vector3.new(0, 4, 0))).to.equal(true)
				end
			end
		)

		it(
			"films the job from inside the cafe, under its ceiling, off the customers' walk",
			function()
				for _, plot in { EAST, WEST } do
					local cut = Intro.shots(plot, true)[5].cuts[1]
					for _, key in { cut.from, cut.to } do
						expect(key.position.Y - Intro.FLOOR_Y < 9).to.equal(true)
						expect(
							flat(key.position, Vector3.new(plot.x, 0, plot.z))
								< Config.World.PlotDepth / 2
						).to.equal(true)
					end
				end
			end
		)
	end)

	describe("the Alleyway camp, the catch and the carry (section 2a)", function()
		it(
			"works out every camp where Layout.camps has it: origin, pad, basket and Index Board",
			function()
				for id, camp in Layout.camps do
					local mine = Intro.camp(id) :: Intro.Camp
					expect(mine).to.be.ok()
					expect(mine.turn).to.equal(camp.turn)
					expect(
						near(mine.origin, Vector3.new(camp.origin.x, camp.origin.y, camp.origin.z))
					).to.equal(true)
					expect(near(mine.pad, Vector3.new(camp.pad.x, camp.pad.y, camp.pad.z))).to.equal(
						true
					)
					expect(
						near(mine.basket, Vector3.new(camp.basket.x, camp.basket.y, camp.basket.z))
					).to.equal(true)
					local board = Layout.indexBoards[id]
					local bx, bz = Layout.campPoint(camp, board.x, board.z)
					expect(flat(mine.board, Vector3.new(bx, 0, bz)) < 1e-6).to.equal(true)
					local pad = Layout.landingPads[id].centre
					expect(near(mine.pad, Vector3.new(pad.x, pad.y, pad.z))).to.equal(true)
					-- u runs from the camp into the area: a step along it from the gate leaves the camp
					local out = mine.origin + mine.u * 2
					expect(Layout.campAt(out.X, out.Z)).to.equal(nil)
					local back = mine.origin - mine.u * 2
					expect(Layout.campAt(back.X, back.Z)).to.equal(id)
				end
				expect(Intro.camp("town")).to.equal(nil)
			end
		)

		it("uses the east lane's way out, on the camp line in the lane's middle", function()
			local W = Config.World
			local lx, lz = Layout.campLocal(Layout.camps.alley, CAMP.wayOut.X, CAMP.wayOut.Z)
			expect(lz).to.be.near(0, 1e-6)
			expect(CAMP.wayOut.X - W.AlleyCenterX).to.be.near(
				(W.AlleyInnerX + W.AlleyOuterX) / 2 - W.AlleyLaneShift,
				1e-6
			)
			expect(math.abs(lx) < Layout.camps.alley.halfAcross).to.equal(true)
			-- on the town side: east of the set's middle, toward the town
			expect(CAMP.wayOut.X > W.AlleyCenterX).to.equal(true)
			local step = CAMP.wayOut + CAMP.u
			local inLane = false
			for _, rect in Layout.alley.rects :: any do
				inLane = inLane or inside(rect, step)
			end
			expect(inLane).to.equal(true)
		end)

		it(
			"puts the demo cat on the first tutorial stray point and you 3.5 studs from it toward the way out",
			function()
				local first: any = nil
				for _, point in Layout.alley.spawnPoints :: any do
					if point.zone == "near" then
						first = point
						break
					end
				end
				local stray, you = Intro.strayPoint(), Intro.catchSpot()
				expect(flat(stray, Vector3.new(first.x, 0, first.z)) < 1e-6).to.equal(true)
				expect((you - stray).Magnitude).to.be.near(Intro.CATCH_GAP, 1e-6)
				-- on the line from the stray to the way out, outside the camp
				local toGate = (CAMP.wayOut - stray).Unit
				expect((you - stray).Unit:Dot(toGate)).to.be.near(1, 1e-6)
				expect(Layout.campAt(you.X, you.Z)).to.equal(nil)
				expect(Layout.campAt(stray.X, stray.Z)).to.equal(nil)
			end
		)

		it(
			"runs you through the way out to 4 studs inside the camp, checking in at about 0.57 s",
			function()
				local path = Intro.runPath()
				expect(near(path[1], Intro.catchSpot())).to.equal(true)
				expect(near(path[2], CAMP.wayOut)).to.equal(true)
				local stop = path[#path]
				expect(Layout.campAt(stop.X, stop.Z)).to.equal("alley")
				local _, lz = Layout.campLocal(Layout.camps.alley, stop.X, stop.Z)
				expect(lz).to.be.near(-Intro.STOP_IN, 1e-6)
				expect(Intro.checkInAt()).to.be.near(0.57, 0.02)
				expect(Intro.stopAt()).to.be.near(0.75, 0.02)
				local shots = Intro.shots(EAST, true)
				expect(Intro.stopAt() + Intro.WATCH_SECONDS < shots[4].seconds).to.equal(true)
				expect(Intro.RUN_SPEED).to.equal(Config.CatchRushWalkSpeed)
			end
		)

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

		it("aims the town cannon at the Alleyway as the server does", function()
			expect(Intro.cannonAim()).to.be.near(Layout.cannonAim("alley"), 1e-9)
			expect(Intro.cannonAim()).to.be.near(-135, 1e-6)
		end)

		it("flies the ball up out of the muzzle into the sky and drops you onto the pad", function()
			local muzzle = Vector3.new(0, 9, 0)
			local aim = Vector3.new(-1, 0, -1).Unit
			expect(near(Intro.arcPoint(muzzle, aim, 0), muzzle)).to.equal(true)
			local top = Intro.arcPoint(muzzle, aim, Intro.PUFF_AT)
			expect(top.Y).to.be.near(Intro.ARC_UP, 1e-6)
			expect(flat(top, muzzle)).to.be.near(Intro.ARC_OUT, 1e-6)
			expect(Vector3.new(top.X - muzzle.X, 0, top.Z - muzzle.Z).Unit:Dot(aim)).to.be.near(
				1,
				1e-6
			)
			-- the beats of Effects/Cannon's staged flight (Presets.cannon.introStage)
			expect(Intro.PUFF_AT).to.equal(0.55)
			expect(Intro.CUT_AT).to.equal(0.7)
			expect(Intro.LAND_AT).to.equal(1.55)
			expect(Intro.dropHeight(Intro.CUT_AT)).to.equal(nil)
			expect(Intro.dropHeight(Intro.DROP_FROM)).to.be.near(Intro.DROP_HEIGHT, 1e-9)
			expect(Intro.dropHeight(Intro.LAND_AT)).to.be.near(0, 1e-9)
			expect((Intro.dropHeight(1.7) :: number) < 0).to.equal(true)
			expect(Intro.dropHeight(Intro.STAND_AT)).to.be.near(0, 1e-9)
			expect(Intro.STAND_AT < Intro.shots(EAST, true)[2].seconds).to.equal(true)
		end)

		it("times the climb, the fuse, the hop, Skip and the job inside their shots", function()
			local shots = Intro.shots(EAST, true)
			expect(Intro.CLIMB_AT + Intro.CLIMB_SECONDS).to.be.near(Intro.AIM_FROM, 1e-9)
			expect(Intro.FUSE_AT + Intro.BOOM_LEAD).to.be.near(shots[1].seconds, 1e-9)
			expect(Intro.WIGGLE_TO < shots[1].seconds).to.equal(true)
			expect(Intro.HOP_FROM).to.be.near(Intro.DEMO_PERFECT + 0.2, 1e-9)
			expect(Intro.HOP_FROM + Intro.HOP_SECONDS <= shots[3].seconds).to.equal(true)
			-- Skip can be pressed from the start of shot 3 (5.0 s in all)
			expect(shots[3].starts).to.be.near(Intro.SKIP_AFTER, 1e-9)
			expect(Intro.JOB_SEATED_AT < Intro.JOB_CARD_AT).to.equal(true)
			expect(Intro.JOB_CARD_AT < Intro.JOB_DRESS_AT).to.equal(true)
			expect(Intro.JOB_DRESS_AT < Intro.JOB_RATE_AT).to.equal(true)
			expect(Intro.JOB_RATE_AT < shots[5].seconds).to.equal(true)
		end)

		it(
			"catches a Tuxedo, an Alleyway Common whose own role is the waiter job it gets",
			function()
				local def = Catalog.getCat(Intro.DEMO_CAT) :: any
				expect(def).to.be.ok()
				expect(def.rarity).to.equal("Common")
				expect(def.area).to.equal("alley")
				expect(def.favoriteRole).to.equal(Intro.JOB_ROLE)
				local spot = Catalog.getSpot(Intro.JOB_SPOT) :: any
				expect(spot.spotType).to.equal(Intro.JOB_ROLE)
				expect(spot.tier).to.equal(1)
				expect(Intro.demoName()).to.equal(def.name)
			end
		)

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

	describe("the plot matches the server's Layout", function()
		it("puts every plot where Layout.plotPlacement does", function()
			for index = 1, Config.World.PlotCount do
				expect(Intro.plot(index) :: any).to.deepEqual(Layout.plotPlacement(index) :: any)
			end
		end)

		it("uses Layout.plot's waiter spot", function()
			local waiter = Layout.plot.spots[Intro.JOB_SPOT]
			expect(Intro.cafe.waiterSpot.x).to.equal(waiter.x)
			expect(Intro.cafe.waiterSpot.z).to.equal(waiter.z)
		end)

		it("turns plot-local places into the world as WorldBuilder turns the plot", function()
			for index = 1, Config.World.PlotCount do
				local plot = Intro.plot(index)
				-- plot -Z faces the street
				local front = Intro.plotPoint(plot, 0, 0, -Config.World.PlotDepth / 2)
				expect(math.abs(front.X) < math.abs(plot.x)).to.equal(true)
				expect(front.Y).to.equal(Intro.FLOOR_Y)
				-- plot +X runs along -Z on the east side, +Z on the west side
				local right = Intro.plotPoint(plot, 1, 0, 0)
				expect(right.Z - plot.z).to.be.near(-plot.side, 1e-9)
			end
		end)

		it(
			"lands a respawn outside the wild areas inside the cafe, in front of the back door",
			function()
				local spot = Layout.plot.respawnSpot
				expect(spot.x).to.equal(Layout.plot.backDoor.x)
				expect(math.abs(spot.x) < Config.World.PlotWidth / 2).to.equal(true)
				expect(spot.z > 0 and spot.z < Config.World.PlotDepth / 2).to.equal(true)
			end
		)
	end)

	describe("shotAt (the shot Skip reports)", function()
		it("is the position of the shot showing, 0 once the last has ended", function()
			local shots = Intro.shots(EAST, true)
			expect(Intro.shotAt(shots, 0)).to.equal(1)
			expect(Intro.shotAt(shots, 2.49)).to.equal(1)
			expect(Intro.shotAt(shots, 2.5)).to.equal(2)
			expect(Intro.shotAt(shots, 5)).to.equal(3)
			expect(Intro.shotAt(shots, 8)).to.equal(4)
			expect(Intro.shotAt(shots, 10)).to.equal(5)
			expect(Intro.shotAt(shots, 13)).to.equal(6)
			expect(Intro.shotAt(shots, 24.29)).to.equal(10)
			expect(Intro.shotAt(shots, 24.31)).to.equal(0)
			expect(Intro.shotAt(shots, 100)).to.equal(0)
		end)
	end)

	describe("keepCuts (a camp that has not streamed in)", function()
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

		it("holds on the cannon with the four title cards when none has streamed in", function()
			local shot = Intro.shots(EAST, true)[6]
			local kept = Intro.keepCuts(shot, function()
				return false
			end)
			expect(#kept).to.equal(4)
			for i, cut in kept do
				expect(cut.title).to.equal(shot.cuts[i].title)
				expect(near(cut.from.position, Vector3.new(10, 8, -18))).to.equal(true)
				expect(near(cut.to.look, Vector3.new(0, 6, 0))).to.equal(true)
			end
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
			expect(near(key.position, Vector3.new(10, 3 + Intro.FOLLOW_UP, 20 - Intro.FOLLOW_BACK))).to.equal(
				true
			)
			expect(near(key.look, Vector3.new(10, 3 + Intro.HEAD_UP, 20))).to.equal(true)
			-- a character looking straight up or down still gets a place behind it
			local up = Intro.follow(Vector3.new(0, 0, 0), Vector3.new(0, 1, 0))
			expect(up.position.Y).to.equal(Intro.FOLLOW_UP)
		end)
	end)

	describe("the intro_cutscene event", function()
		it("carries version 3 since the shots moved for the hometown and the cannon", function()
			expect(Intro.VERSION).to.equal(3)
		end)

		it(
			"every shot Skip can report passes the server's IntroDone guard, 0 to Intro.SHOTS (QA)",
			function()
				-- IntroService takes Guard.int(shot, 0, Intro.SHOTS): a whole number, 0 for finished
				for index = 1, Config.World.PlotCount do
					for _, streamed in { true, false } do
						local shots = Intro.shots(Intro.plot(index), true, streamed)
						local length = Intro.length(shots)
						local step = 0
						while step <= 3000 do
							local elapsed = step / 100
							local position = Intro.shotAt(shots, elapsed)
							local shot = if position == 0 then 0 else shots[position].index
							if shot ~= math.floor(shot) or shot < 0 or shot > Intro.SHOTS then
								error(
									string.format(
										"plot %d at %.2f s reports shot %s",
										index,
										elapsed,
										tostring(shot)
									)
								)
							end
							expect(position == 0).to.equal(elapsed >= length)
							step += 1
						end
						-- the first play's Skip comes after SKIP_AFTER, past the flight
						expect(shots[Intro.shotAt(shots, Intro.SKIP_AFTER)].index >= 3).to.equal(
							true
						)
					end
				end
			end
		)
	end)
end
