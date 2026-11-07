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
		it(
			"are eight shots of 21 s, each starting where the one before ends (#1542, #1782, #2242, #2357)",
			function()
				local shots = Intro.shots(EAST, true)
				expect(#shots).to.equal(Intro.SHOTS)
				expect(Intro.SHOTS).to.equal(8)
				expect(Intro.VERSION).to.equal(9)
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
				-- 30.5 with the camp cuts, until #1542; 22.5 with the Index Board shot, until #1782; 20 until #2242's
				-- 3 s rich visitor; 23 until #2357 took out the 2 s "first cat is waiting" shot
				expect(Intro.length(shots)).to.be.near(21, 1e-9)
				local starts = {}
				for _, shot in shots do
					table.insert(starts, math.floor(shot.starts * 10 + 0.5) / 10)
				end
				-- #2242: the 3 s rich visitor after the cafe job; #2113: the 3 s night before the 2.7 s spin
				expect(starts :: any).to.deepEqual({ 0, 2.5, 5, 7.5, 9.5, 12.3, 15.3, 18.3 })
			end
		)

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
				expect(which("camp") :: any).to.deepEqual({ 3, 4 })
				expect(which("rich") :: any).to.deepEqual({ 6 }) -- #2242: straight after the cafe job
				expect(which("spinWheel") :: any).to.deepEqual({ 8 }) -- #2113: after the night
				expect(which("night") :: any).to.deepEqual({ 7 })
				expect(which("follow") :: any).to.deepEqual({}) -- #2357: the last shot is gone
				expect(shots[1].caption).to.equal("Fly the Cat Cannon to catch stray cats!")
				expect(shots[4].caption).to.equal("Carry it into the camp to keep it!")
				expect(shots[6].caption).to.equal("Rich visitors leave big tips. Grab them fast!")
				expect(shots[9]).never.to.be.ok() -- #2357
				-- #1542: no shot shows the other camps any more; #1782: nor the Alleyway's Index Board after the cafe
				for _, shot in shots do
					expect(shot.caption ~= "Rank up to fly to new areas!").to.equal(true)
					expect(shot.caption ~= "Find all 50 cats for Index rewards").to.equal(true)
				end
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

		it("shows night and its fresh cats before the free spin and the codes (#2113)", function()
			local shots = Intro.shots(EAST, true)
			expect(shots[7].night).to.equal(true)
			expect(shots[8].spinWheel).to.equal(true)
			expect(Intro.VERSION).to.equal(9)
		end)

		it(
			"leaves out shots 3 and 4 when the Alleyway's camp has not streamed in, 4.5 s shorter: 16.5 s",
			function()
				local shots = Intro.shots(EAST, true, false)
				local indexes = {}
				local at = 0
				for _, shot in shots do
					table.insert(indexes, shot.index)
					expect(shot.starts).to.be.near(at, 1e-9)
					at += shot.seconds
				end
				expect(indexes :: any).to.deepEqual({ 1, 2, 5, 6, 7, 8 })
				expect(Intro.length(shots)).to.be.near(16.5, 1e-9)
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
				-- 16 studs out from the front wall, half the bigger cafe's 34 deep from its middle (#917)
				expect(east[1].cuts[1].from.position.X).to.be.near(EAST.x - 33, 1e-9)
				expect(west[1].cuts[1].from.position.X).to.be.near(WEST.x + 33, 1e-9)
				for _, shots in { east, west } do
					local cut = shots[1].cuts[1]
					expect(near(cut.to.position, Vector3.new(10, 8, -18))).to.equal(true)
					expect(near(cut.to.look, Vector3.new(0, 6, 0))).to.equal(true)
					expect((cut.via :: Intro.Key).position.Y).to.equal(30)
					-- shot 2 starts where shot 1 ends
					expect(near(shots[2].cuts[1].from.position, cut.to.position)).to.equal(true)
				end
				-- everything after shot 1 is the same for every plot but the job and the rich visitor in your own cafe
				for i = 2, Intro.SHOTS do
					if i ~= 5 and i ~= 6 then
						expect(near(east[i].cuts[1].from.position, west[i].cuts[1].from.position)).to.equal(
							true
						)
					end
				end
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

		it("films the run from inside the camp, behind the basket", function()
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
		end)

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

	describe("the rich visitor (#2242)", function()
		it("films your cafe's door and table 1's coin pile from inside, under its ceiling", function()
			for _, plot in { EAST, WEST } do
				local shot = Intro.shots(plot, true)[6]
				local tip, door = Intro.richTipPoint(plot), Intro.doorPoint(plot)
				for _, key in { shot.cuts[1].from, shot.cuts[1].to } do
					expect(key.position.Y - Intro.FLOOR_Y < 9).to.equal(true)
					expect(
						flat(key.position, Vector3.new(plot.x, 0, plot.z)) < Config.World.PlotDepth / 2
					).to.equal(true)
					-- the coin pile and the door both in front of the camera
					local ahead = (key.look - key.position).Unit
					expect((tip - key.position).Unit:Dot(ahead) > 0.5).to.equal(true)
					expect((door - key.position).Unit:Dot(ahead) > 0.3).to.equal(true)
				end
			end
		end)

		it("uses Layout.plot's rich tip anchor and the front door", function()
			local tip = Layout.plot.richTip
			expect(Intro.cafe.richTip.x).to.equal(tip.x)
			expect(Intro.cafe.richTip.y).to.equal(tip.y)
			expect(Intro.cafe.richTip.z).to.equal(tip.z)
			local door = Intro.doorPoint(WEST)
			expect(near(door, Intro.plotPoint(WEST, 0, 0, -Config.World.PlotDepth / 2 + 1.5))).to.equal(true)
		end)

		it("stops your copy RICH_REACH short of the coins, on the door's side, on the floor", function()
			local door = Vector3.new(0, 0.2, 0)
			local tip = Vector3.new(10, 2.9, 0)
			local at = Intro.grabSpot(door, tip)
			expect(near(at, Vector3.new(10 - Intro.RICH_REACH, 0.2, 0))).to.equal(true)
			-- standing on the tip falls back to a fixed side
			expect(Intro.grabSpot(tip, tip).Y).to.equal(tip.Y)
		end)

		it("times the walk in, the sit, the coins and the grab inside the shot", function()
			local shot = Intro.shots(EAST, true)[6]
			local beats = {
				Intro.RICH_WALK_AT,
				Intro.RICH_SIT_AT,
				Intro.RICH_TIP_AT,
				Intro.RICH_GRAB_FROM,
				Intro.RICH_GRAB_AT,
			}
			for i = 2, #beats do
				expect(beats[i - 1] < beats[i]).to.equal(true)
			end
			expect(Intro.RICH_GRAB_AT < shot.seconds).to.equal(true)
			-- 8 words: a 4.2 s reading hold (section 2b)
			expect(shot.hold).to.be.near(4.2, 1e-9)
		end)

		it("pops a rich tip on a new cafe's day rate at Tier 1, at least $50", function()
			expect(Intro.richTip()).to.equal(Economy.richTipAmount(Intro.demoRate()))
			expect(Intro.richTip() >= 50).to.equal(true)
		end)
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

		it("uses the one way in, on the camp line in the middle (F85)", function()
			local W = Config.World
			local lx, lz = Layout.campLocal(Layout.camps.alley, CAMP.wayOut.X, CAMP.wayOut.Z)
			expect(lz).to.be.near(0, 1e-6)
			expect(lx).to.be.near(0, 1e-6)
			expect(CAMP.wayOut.X).to.be.near(W.AlleyCenterX, 1e-6)
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
			expect(Intro.dropHeight(1.7)).to.be.near(0, 1e-9)
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
			expect(Intro.shotAt(shots, 12.29)).to.equal(5)
			expect(Intro.shotAt(shots, 12.31)).to.equal(6) -- the rich visitor, straight after the job (#2242)
			expect(Intro.shotAt(shots, 15.31)).to.equal(7) -- the square
			expect(Intro.shotAt(shots, 20.99)).to.equal(8) -- the last since #2357
			expect(Intro.shotAt(shots, 21.01)).to.equal(0)
			expect(Intro.shotAt(shots, 100)).to.equal(0)
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

	describe("the cloud dips between places (#958)", function()
		-- every camera place change in order: the shot it goes into, the cut, and whether it is a jump
		local function changes(plot: Intro.Plot): { { shot: number, cut: number, jump: boolean } }
			local list = {}
			local last: Intro.Key? = nil
			for _, shot in Intro.shots(plot, true) do
				for index, cut in shot.cuts do
					if last ~= nil and not shot.flight then
						table.insert(list, {
							shot = shot.index,
							cut = index,
							jump = Intro.jump(last :: Intro.Key, cut.from),
						})
					end
					last = cut.to
				end
			end
			return list
		end

		it(
			"dips into your cafe and the town (no camp tour since #1542, no board since #1782)",
			function()
				for _, plotIndex in { 1, 2, 5, 8 } do
					local jumps = {}
					for _, change in changes(Intro.plot(plotIndex)) do
						if change.jump then
							table.insert(jumps, string.format("%d.%d", change.shot, change.cut))
						end
					end
					-- the cafe to the night (7.1) dips only from a plot far enough from the square; the rich visitor
					-- (6.1, #2242) stays in the cafe
					local seen = table.concat(jumps, " ")
					expect(seen == "5.1 8.1" or seen == "5.1 7.1 8.1").to.equal(true)
				end
			end
		)

		it("keeps the Alleyway's catch and run and the end behind you as plain cuts", function()
			for _, change in changes(EAST) do
				if change.shot == 3 or change.shot == 4 or change.shot == 6 or change.shot == 9 then
					expect(change.jump).to.equal(false)
				end
			end
			expect(Intro.JUMP_STUDS).to.equal(60)
			expect(Intro.CUT_LEAD).to.be.near(0.2, 1e-12)
		end)
	end)

	describe("the intro_cutscene event", function()
		it(
			"carries version 9 since #2357 took out the last shot (8 since #2242, 7 since #2182, 6 since #2113, 5 since #1782, 4 since #1542)",
			function()
				expect(Intro.VERSION).to.equal(9)
			end
		)

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
	describe("reading holds and Next (#2182, section 2b)", function()
		local EAST = { x = 40, z = 0, side = 1, index = 1 }
		it("holds each shot for 1.0 s plus 0.4 s a word, at least its section 2 length", function()
			expect(Intro.words("Tap as each circle closes!")).to.equal(5)
			expect(Intro.words("  two   words ")).to.equal(2)
			expect(Intro.hold(2.5, "Tap as each circle closes!")).to.be.near(3.0, 1e-9)
			expect(Intro.hold(5, "Short")).to.equal(5)
			local holds = {}
			for _, shot in Intro.shots(EAST, true, true) do
				expect(shot.hold).to.be.near(Intro.hold(shot.seconds, shot.caption), 1e-9)
				expect(shot.hold >= shot.seconds).to.equal(true)
				table.insert(holds, math.floor(shot.hold * 10 + 0.5) / 10)
			end
			expect(holds :: any).to.deepEqual({ 4.2, 4.2, 3.0, 4.2, 4.2, 4.2, 4.2, 4.6 })
		end)

		it("eases the camera to a stop at the end of its moves and holds it there", function()
			local shot = Intro.shots(EAST, true, true)[1] -- 2.5 s of moves, a 4.2 s hold
			local settle = Intro.SETTLE_SECONDS
			expect(Intro.cameraTime(shot, 1)).to.equal(1)
			expect(Intro.cameraTime(shot, shot.seconds - settle)).to.be.near(
				shot.seconds - settle,
				1e-9
			)
			expect(Intro.cameraTime(shot, shot.seconds + settle)).to.be.near(shot.seconds, 1e-9)
			expect(Intro.cameraTime(shot, shot.hold)).to.be.near(shot.seconds, 1e-9)
			local last = -1
			for t = 0, shot.hold, 0.05 do
				local camera = Intro.cameraTime(shot, t)
				expect(camera >= last - 1e-9).to.equal(true)
				expect(camera <= shot.seconds + 1e-9).to.equal(true)
				last = camera
			end
		end)

		it("keeps a shot with no spare time as it was", function()
			local shot = table.clone(Intro.shots(EAST, true, true)[1])
			shot.hold = shot.seconds
			expect(Intro.cameraTime(shot, 2.4)).to.equal(2.4)
			expect(Intro.launchTime(shot, 2.4)).to.equal(2.4)
		end)

		it("waits in the barrel through shot 1's extra hold, so the BOOM ends the hold", function()
			local shot = Intro.shots(EAST, true, true)[1]
			local inBarrel = Intro.CLIMB_AT + Intro.CLIMB_SECONDS
			expect(Intro.launchTime(shot, Intro.CLIMB_AT)).to.equal(Intro.CLIMB_AT)
			expect(Intro.launchTime(shot, inBarrel + 1)).to.equal(inBarrel)
			expect(Intro.launchTime(shot, Intro.fuseAt(shot))).to.be.near(Intro.FUSE_AT, 1e-9)
			expect(Intro.fuseAt(shot) + Intro.BOOM_LEAD).to.be.near(shot.hold, 1e-9)
			expect(Intro.launchTime(shot, shot.hold)).to.be.near(shot.seconds, 1e-9)
		end)

		it("lets Next in from 1.0 s, before any shot's hold ends", function()
			expect(Intro.NEXT_AFTER).to.equal(1.0)
			for _, shot in Intro.shots(EAST, true, true) do
				expect(Intro.NEXT_AFTER < shot.hold).to.equal(true)
			end
		end)
	end)
end
