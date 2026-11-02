--!strict
-- The world layout (server World/Layout.luau, pure geometry) against design v0.4: world-and-feel.md section 2 (the
-- Alleyway out back) and its section 8 acceptance check 4 (F35, layout v2; check 4 as reworded in docs PR #83), and
-- town-layout-v3.md (F76) with section 7 (v3.1, F77: the Alley Square gone, the Woods and Sewer off the alleys).
-- v4 (F84, hometown-cannon.md): the hometown alone in the middle, every catching area far out with its camp.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Layout = require(ServerScriptService.Server.World.Layout)

	type Point = Layout.Point
	type Rect = Layout.Rect

	local W = Config.World

	local function fail(pattern: string, ...: any)
		error(string.format(pattern, ...), 2)
	end

	local function inside(x: number, z: number, rect: Rect, margin: number): boolean
		return x >= math.min(rect.x1, rect.x2) + margin
			and x <= math.max(rect.x1, rect.x2) - margin
			and z >= math.min(rect.z1, rect.z2) + margin
			and z <= math.max(rect.z1, rect.z2) - margin
	end

	local function onFloor(x: number, z: number, rects: { Rect }, margin: number): boolean
		for _, rect in rects do
			if inside(x, z, rect, margin) then
				return true
			end
		end
		return false
	end

	local function inWall(x: number, z: number, walls: { Rect }, margin: number): boolean
		for _, wall in walls do
			if inside(x, z, wall, -margin) then
				return true
			end
		end
		return false
	end

	-- A plot-local point in world space. WorldBuilder turns each plot with CFrame.lookAt toward the street (x = 0),
	-- so plot -Z points at the street and plot +X runs along -Z on the east side (+1), +Z on the west side (-1).
	local function plotToWorld(index: number, localX: number, localZ: number): (number, number)
		local placement = Layout.plotPlacement(index)
		return placement.x + placement.side * localZ, placement.z - placement.side * localX
	end

	local alley = Layout.alley
	local alleyRects = alley.rects :: { Rect }
	local alleyWalls = alley.walls :: { Rect }

	describe("areas match Catalog.areas (data-model section 9)", function()
		it("every area has the spawn points and rescue spots Catalog.areas counts", function()
			for _, area in Catalog.areas do
				local spec = Layout.areas[area.id]
				expect(spec).to.be.ok()
				expect(#spec.spawnPoints).to.equal(area.spawnPoints)
				expect(#spec.rescueSpots).to.equal(area.rescueSpots)
			end
		end)

		it(
			"spawn points are at least 4 studs apart in every area, so strays never stack",
			function()
				for id, spec in Layout.areas do
					for i, a in spec.spawnPoints do
						for j = i + 1, #spec.spawnPoints do
							local b = spec.spawnPoints[j]
							local apart = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
							if apart < 4 then
								fail(
									"%s spawn points %d and %d are %.1f studs apart",
									id,
									i,
									j,
									apart
								)
							end
						end
					end
				end
			end
		)

		it("the box areas keep every spawn point and rescue spot on their floor", function()
			for id, spec in Layout.areas do
				if spec.rects ~= nil then
					continue
				end
				local floor: Rect = {
					x1 = spec.center.x - spec.halfWidth,
					z1 = spec.center.z - spec.halfDepth,
					x2 = spec.center.x + spec.halfWidth,
					z2 = spec.center.z + spec.halfDepth,
				}
				for i, point in spec.spawnPoints do
					if not inside(point.x, point.z, floor, 2) then
						fail("%s spawn point %d is not 2 studs inside the floor", id, i)
					end
				end
				for i, spot in spec.rescueSpots do
					if not inside(spot.x, spot.z, floor, 0) then
						fail("%s rescue spot %d is off the floor", id, i)
					end
				end
			end
		end)

		-- Model-Agent #401: the area sets bring their cat spots and their traps, turned with the set so its gate side
		-- faces the town; the Park's v3.2 set (#460) its cat spots, its traps being the world's trees and bins; the
		-- Woods', the Sewer's and the Neighbourhood's v3.2 sets (#470, #491, #505) their spots and traps, the hollow
		-- logs, drain pipes, sheds and gutters turned in the set as well.
		it("the area sets' cat spots stand on the set's ground, clear of its traps", function()
			local sets: { [string]: string } = {
				park = "CatCafe_Park_Set",
				neighbourhood = "CatCafe_Neighbourhood_SetV32",
				woods = "CatCafe_Woods_SetV32",
				sewer = "CatCafe_Sewer_SetV32",
			}
			for id, name in sets do
				local spec = Layout.areas[id]
				expect(spec.set).to.equal(name)
				local turn = Layout.gateTurn(spec)
				-- on the ground or a low perch (a porch, a rock, the catwalk), never a roof; the Woods' tree house
				-- cushion and the Great Oak's top nook, up their ladders, are the high spots
				local top = spec.floorY + (if id == "woods" then 18.5 else 4)
				for i, point in spec.spawnPoints do
					if point.y < spec.floorY or point.y > top then
						fail("%s spawn point %d stands at y %g", id, i, point.y)
					end
					expect(point.rotY).to.equal(turn)
					for j, spot in spec.rescueSpots do
						local apart = math.sqrt((point.x - spot.x) ^ 2 + (point.z - spot.z) ^ 2)
						if apart < 4 then
							fail(
								"%s spawn point %d is %.1f studs from rescue spot %d",
								id,
								i,
								apart,
								j
							)
						end
					end
				end
				local pieceTurns: { number } = if id == "woods"
					then { 20, -20, 0, 0, -106.26 }
					elseif id == "sewer" then { 0, 0, 90, -90 }
					elseif id == "neighbourhood" then { 0, -90, 180, 34 }
					else {}
				local built = 0
				for _, spot in spec.rescueSpots do
					if spot.prop == nil then
						built += 1
						expect(spot.rotY).to.equal(turn + (pieceTurns[built] or 0))
					end
				end
				expect(built).to.equal(if id == "park" then 0 elseif id == "woods" then 5 else 4)
			end
		end)

		it("a set spot turns with the set: its -Z side toward the gate", function()
			for _, id in { "park", "neighbourhood", "woods", "sewer" } do
				local spec = Layout.areas[id]
				local gx, gz = Layout.gatePosition(spec)
				expect(gx).to.be.ok()
				-- the Park's plaza at local (-3.5, -49.5) is near its gate side, the Neighbourhood's porch at local
				-- (-110.2, -98.9) near its own, the Woods' berry bush at local (-30, -99.8) near its own, the Sewer's
				-- canal bridge at local (44, -61) near its own
				local index = if id == "woods" then 8 else 1
				local point = spec.spawnPoints[index]
				local toGate =
					math.sqrt((point.x - (gx :: number)) ^ 2 + (point.z - (gz :: number)) ^ 2)
				local toCenter =
					math.sqrt((point.x - spec.center.x) ^ 2 + (point.z - spec.center.z) ^ 2)
				if toGate >= toCenter then
					fail(
						"%s spawn point %d is %.1f from the gate and %.1f from the centre",
						id,
						index,
						toGate,
						toCenter
					)
				end
			end
		end)

		-- F81 (town-layout-v3.md section 8d): a v3.2 set tags each cat spot near (the gate half) or deep (the far
		-- half, where Epic and rarer strays wait), and some of its traps are in the far half. The Woods' Great Oak
		-- top is "rare" (Catching.RARE_ZONE), in the far half too. The Sewer's zones go by region (#491): its near
		-- spots are all in the gate half, but past the cross wall's arch is deep, the west hall's far chamber in the
		-- gate half among it.
		it(
			"the v3.2 sets' spots are near their gates or deep in their far halves, with traps deep",
			function()
				local rows = {
					{
						id = "park",
						near = 16,
						deep = 24,
						rare = 0,
						deepTraps = 3,
						byRegion = false,
					},
					{
						id = "woods",
						near = 26,
						deep = 38,
						rare = 1,
						deepTraps = 3,
						byRegion = false,
					},
					{
						id = "sewer",
						near = 20,
						deep = 32,
						rare = 0,
						deepTraps = 2,
						byRegion = true,
					},
					{
						id = "neighbourhood",
						near = 28,
						deep = 44,
						rare = 0,
						deepTraps = 2,
						byRegion = false,
					},
				}
				for _, row in rows do
					local spec = Layout.areas[row.id]
					local gateX, gateZ = spec.gateX, spec.gateZ
					-- how far in from the gate, along the way in
					local function fromGate(x: number, z: number): number
						if gateX ~= nil then
							return math.abs(x - gateX)
						end
						return math.abs(z - (gateZ :: number))
					end
					local middle = fromGate(spec.center.x, spec.center.z)
					local counts: { [string]: number } = {}
					for i, point in spec.spawnPoints do
						local zone = point.zone :: string
						counts[zone] = (counts[zone] or 0) + 1
						local inFrom = fromGate(point.x, point.z)
						local wrong = if row.byRegion
							then zone == "near" and inFrom > middle
							else (zone ~= "near") ~= (inFrom > middle)
						if wrong then
							fail(
								"%s spawn point %d (%s) is %.1f studs in from the gate",
								row.id,
								i,
								zone,
								inFrom
							)
						end
					end
					expect(counts.near).to.equal(row.near)
					expect(counts.deep).to.equal(row.deep)
					expect(counts.rare or 0).to.equal(row.rare)
					local deep = 0
					for _, spot in spec.rescueSpots do
						if fromGate(spot.x, spot.z) > middle then
							deep += 1
						end
					end
					expect(deep).to.equal(row.deepTraps)
				end
				-- the Park's traps are the world's trees and bins, the first a prop turned 180 in the set, which is
				-- turned 180 itself
				for _, spot in Layout.park.rescueSpots do
					expect(spot.prop).to.be.ok()
				end
				expect(Layout.park.rescueSpots[1].rotY).to.equal(0)
			end
		)

		-- Derek 2026-10-28 01:34 and 01:35 (Model-Agent #452): a cat can get stuck up the tree house's branch, and the
		-- Great Oak's top nook is where the rarer cats wait.
		it(
			"the Woods' tree house branch is a tree trap up off the deck, and the oak top a rare spot",
			function()
				local woods = Layout.woods
				local branch = woods.rescueSpots[5]
				expect(branch.prop).to.equal(nil)
				expect(branch.trap).to.equal("tree")
				expect(branch.y).to.equal(15.45)
				local rares = 0
				for _, point in woods.spawnPoints do
					if point.zone == "rare" then
						rares += 1
						expect(point.y).to.be.near(woods.floorY + 18.3, 1e-9)
					end
				end
				expect(rares).to.equal(1)
			end
		)

		-- Animation-Engineer's stuck placements (2026-10-28): every stuck cat is posed, a prop trap's in the prop's
		-- space and a set trap's by its TrapType in the spot's, so the wriggles read as back end out or upside down.
		it("every trap poses its stuck cat, each pose a turn and nothing more", function()
			local function isTurn(pose: { number }, label: string)
				if #pose ~= 12 then
					fail("%s pose has %d numbers", label, #pose)
				end
				local a, b, c =
					{ pose[4], pose[5], pose[6] },
					{ pose[7], pose[8], pose[9] },
					{ pose[10], pose[11], pose[12] }
				local det = a[1] * (b[2] * c[3] - b[3] * c[2])
					- a[2] * (b[1] * c[3] - b[3] * c[1])
					+ a[3] * (b[1] * c[2] - b[2] * c[1])
				if math.abs(det - 1) > 1e-3 then
					fail("%s pose's rotation has determinant %.4f", label, det)
				end
			end
			for id, spec in Layout.areas do
				for i, spot in spec.rescueSpots do
					local label = string.format("%s trap %d (%s)", id, i, spot.trap)
					local pose = if spot.prop ~= nil
						then Layout.stuckPoses[spot.prop]
						else Layout.setStuckPoses[spot.trap]
					if pose == nil then
						fail("%s has no stuck pose", label)
					end
					isTurn(pose :: { number }, label)
				end
			end
			-- the Park's trees are props, so a set's tree pose is the Woods' tree house branch alone
			expect(Layout.setStuckPoses.tree).to.be.ok()
			expect(Layout.stuckPoses.CatCafe_Park_RescueTree).to.be.ok()
		end)
	end)

	-- v4 (F84, hometown-cannon.md section 6a): the Alleyway's two lanes keep their v3.2 numbers in lane space, and the
	-- set stands in the wild with each lane AlleyLaneShift nearer its middle (Layout.alley). toLane undoes the move.
	local function toLane(x: number, z: number): (number, number)
		local dx = x - W.AlleyCenterX
		return dx + (if dx < 0 then -1 else 1) * W.AlleyLaneShift, z - W.AlleyCenterZ
	end
	local function fromLane(x: number, z: number): (number, number)
		return W.AlleyCenterX + x - math.sign(x) * W.AlleyLaneShift, W.AlleyCenterZ + z
	end
	local AI, AO, AS, AN = W.AlleyInnerX, W.AlleyOuterX, W.AlleySouthZ, W.AlleyNorthZ
	local MID = (AI + AO) / 2

	describe("the Alleyway in the wild (world-and-feel section 2, F35; v4, F84)", function()
		it(
			"32 spawn points: 16 on the lanes, 8 nooks at the far end and 8 near points by the camp (v4)",
			function()
				local zones: { [string]: number } = {}
				for _, point in alley.spawnPoints do
					expect(point.zone).to.be.ok()
					local zone = point.zone :: string
					zones[zone] = (zones[zone] or 0) + 1
				end
				expect(#alley.spawnPoints).to.equal(32)
				expect(zones.lane).to.equal(2 * W.PlotCount)
				expect(zones.nook).to.equal(8)
				expect(zones.near).to.equal(W.PlotCount)
			end
		)

		it(
			"every point lies in a lane or the passage, the nooks at the far end 10 studs from every lane point",
			function()
				local sides: { [string]: number } = {}
				for i, point in alley.spawnPoints do
					local x, z = toLane(point.x, point.z)
					local inLane = math.abs(x) >= AI and math.abs(x) <= AO and z > AS and z < AN
					local inPassage = math.abs(x) < AI and z > AS and z < AS + W.AlleyPassageDepth
					if not inLane and not inPassage then
						fail(
							"%s point %d at (%g, %g) is not in a lane or the passage",
							tostring(point.zone),
							i,
							x,
							z
						)
					end
					if point.zone ~= "nook" then
						continue
					end
					-- 6 to 6.5 from the south end wall, so 2 or more inside the roam rects' 4 stud margin
					local fromEnd = z - AS
					if fromEnd < 5 or fromEnd > 9 then
						fail(
							"nook point %d at (%g, %g) is %.1f from the end wall",
							i,
							x,
							z,
							fromEnd
						)
					end
					local key = if x < 0 then "w" else "e"
					sides[key] = (sides[key] or 0) + 1
					for j, lane in alley.spawnPoints do
						local apart = math.sqrt((point.x - lane.x) ^ 2 + (point.z - lane.z) ^ 2)
						if lane.zone == "lane" and apart < 10 then
							fail("nook point %d is %.1f studs from lane point %d", i, apart, j)
						end
					end
				end
				expect(sides.w).to.equal(4)
				expect(sides.e).to.equal(4)
			end
		)

		it(
			"plot p owns near point p, just past the camp's ways out, the east lane's first (v0.13.18)",
			function()
				local near: { Point } = {}
				for _, point in alley.spawnPoints do
					if point.zone == "near" then
						table.insert(near, point)
					end
				end
				for p, point in near do
					local x, z = toLane(point.x, point.z)
					expect(math.sign(x)).to.equal(if p <= 4 then 1 else -1)
					local into = AN - z
					expect(into == 10 or into == 16).to.equal(true)
					expect(math.abs(math.abs(x) - MID)).to.be.near(5, 1e-9)
				end
				-- g + 10u + 5r first: facing into the lane (-Z) the right hand is +X
				local x1, z1 = toLane(near[1].x, near[1].z)
				expect(x1).to.be.near(MID + 5, 1e-9)
				expect(z1).to.be.near(AN - 10, 1e-9)
			end
		)

		it("every spawn point is 2 studs inside a floor and clear of every wall", function()
			for i, point in alley.spawnPoints do
				local off = not onFloor(point.x, point.z, alleyRects, 2)
				if off or inWall(point.x, point.z, alleyWalls, 1) then
					fail(
						"alley point %d at (%g, %g) is off the floor or in a wall",
						i,
						point.x,
						point.z
					)
				end
			end
		end)

		-- Engineer PR #102: strays keep to alley.roam, off the dressed strip along the outer walls (building backs,
		-- fire escapes, crates up to 5 studs deep) and the end walls. WorldBuilder.clampToArea keeps every wander
		-- and jump-back 2 studs inside a roam rect.
		it("the roam rects lie on the floor, clear of every wall (QA)", function()
			local roam = alley.roam :: { Rect }
			expect(roam).to.be.ok()
			-- How far two rects overlap along one axis; 0 or less when they only touch or miss.
			local function overlap(a1: number, a2: number, b1: number, b2: number): number
				return math.min(math.max(a1, a2), math.max(b1, b2))
					- math.max(math.min(a1, a2), math.min(b1, b2))
			end
			for r, rect in roam do
				for _, corner in
					{
						{ rect.x1, rect.z1 },
						{ rect.x1, rect.z2 },
						{ rect.x2, rect.z1 },
						{ rect.x2, rect.z2 },
					}
				do
					if not onFloor(corner[1], corner[2], alleyRects, 0) then
						fail(
							"roam rect %d corner (%g, %g) is off the floor",
							r,
							corner[1],
							corner[2]
						)
					end
				end
				for w, wall in alleyWalls do
					if
						overlap(rect.x1, rect.x2, wall.x1, wall.x2) > 0
						and overlap(rect.z1, rect.z2, wall.z1, wall.z2) > 0
					then
						fail("roam rect %d overlaps wall %d", r, w)
					end
				end
			end
		end)

		it(
			"every spawn point is 2 studs inside a roam rect, so no stray starts in the dressing (QA)",
			function()
				local roam = alley.roam :: { Rect }
				for i, point in alley.spawnPoints do
					if not onFloor(point.x, point.z, roam, 2) then
						fail(
							"alley point %d at (%g, %g) is not 2 studs inside a roam rect",
							i,
							point.x,
							point.z
						)
					end
				end
			end
		)

		it(
			"keeps the strays 5 studs off the outer walls, 4 off the end wall and out of the camp (QA, v4)",
			function()
				local camp = Layout.camps.alley
				expect(camp).to.be.ok()
				for r, rect in alley.roam :: { Rect } do
					local ax, az = toLane(rect.x1, rect.z1)
					local bx, bz = toLane(rect.x2, rect.z2)
					local x1, x2 = math.min(ax, bx), math.max(ax, bx)
					local z1, z2 = math.min(az, bz), math.max(az, bz)
					local outer = x1 < -AO + 5 or x2 > AO - 5
					if outer or z1 < AS + 4 or z2 > AN - 4 then
						fail(
							"roam rect %d (%g to %g, z %g to %g) reaches into the dressing",
							r,
							x1,
							x2,
							z1,
							z2
						)
					end
					expect(math.max(rect.z1, rect.z2) < camp.rect.z1).to.equal(true)
				end
			end
		)

		it(
			"rescue spots stand on the Alleyway floor, two in the west lane and one in the east (v3.1)",
			function()
				local west, east = 0, 0
				for _, spot in alley.rescueSpots do
					expect(onFloor(spot.x, spot.z, alleyRects, 0)).to.equal(true)
					if spot.x < W.AlleyCenterX then
						west += 1
					else
						east += 1
					end
				end
				expect(west).to.equal(2)
				expect(east).to.equal(1)
			end
		)

		it(
			"walls in both lanes along their outer sides and far end, with the passage open through the block (v4)",
			function()
				for _, side in { -1, 1 } do
					for z = AS + 1, AN - 1, 1 do
						local wx, wz = fromLane(side * (AO + 0.5), z)
						if not inWall(wx, wz, alleyWalls, 0) then
							fail("no outer wall at lane (%g, %g)", side * (AO + 0.5), z)
						end
					end
					for x = AI, AO, 2 do
						local wx, wz = fromLane(side * x, AS - 0.5)
						if not inWall(wx, wz, alleyWalls, 0) then
							fail("no end wall at lane (%g, %g)", side * x, AS - 0.5)
						end
						-- and open into the camp at the north end
						local cx, cz = fromLane(side * x, AN + 0.5)
						if x > AI and x < AO and inWall(cx, cz, alleyWalls, 0) then
							fail("the way out at lane (%g, %g) is walled", side * x, AN + 0.5)
						end
					end
				end
				-- the block between the lanes, and the passage through it at the far end
				for z = AS + 1, AN - 1, 2 do
					local blocked = inWall(W.AlleyCenterX, W.AlleyCenterZ + z, alleyWalls, 0)
					local passage = z < AS + W.AlleyPassageDepth
					if blocked == passage then
						fail(
							"the middle at lane z %g is %s",
							z,
							if passage then "walled" else "open"
						)
					end
				end
			end
		)

		it(
			"lays the camp across both lanes' north ends, its Index Board between the two ways out (v4)",
			function()
				local camp = Layout.camps.alley
				expect(camp.turn).to.equal(180)
				expect(camp.rect.x1).to.be.near(W.AlleyCenterX - (AO - W.AlleyLaneShift), 1e-9)
				expect(camp.rect.x2).to.be.near(W.AlleyCenterX + (AO - W.AlleyLaneShift), 1e-9)
				expect(camp.rect.z1).to.be.near(W.AlleyCenterZ + AN, 1e-9)
				expect(camp.rect.z2).to.be.near(W.AlleyCenterZ + AN + W.CampDepth, 1e-9)
				local board = Layout.indexBoards.alley
				local bx, bz = Layout.campPoint(camp, board.x, board.z)
				expect(inside(bx, bz, camp.rect, 0)).to.equal(true)
				expect(math.abs(bx - W.AlleyCenterX) < AI - W.AlleyLaneShift).to.equal(true)
			end
		)

		-- v3.1 gave up the Alley Square for the bigger Woods and Sewer next door (town-layout-v3.md section 7b), so
		-- the two back alleys alone are the Alleyway now: 8 times before, about 5.7 times since.
		it("is at least 5 times the old 60 x 44 stud box (size target)", function()
			local total = 0
			for _, rect in alleyRects do
				total += math.abs(rect.x2 - rect.x1) * math.abs(rect.z2 - rect.z1)
			end
			expect(total >= 5 * 60 * 44).to.equal(true)
		end)

		it(
			"ends every cafe's yard at the town's back edge, where the back alleys began (v4)",
			function()
				for index = 1, W.PlotCount do
					local backX = plotToWorld(index, 0, Layout.plot.yard.z2)
					expect(math.abs(math.abs(backX) - W.TownEdgeX) <= 1).to.equal(true)
				end
			end
		)
	end)

	describe("the bait bowl on the back step (v0.5 F44, data-model section 8)", function()
		local plot = Layout.plot
		local halfD = W.PlotDepth / 2

		it(
			"the bowl and its cat sit in the yard just outside the back wall, facing the Alleyway",
			function()
				for _, point in { plot.baitBowl, plot.baitCat } do
					expect(inside(point.x, point.z, plot.yard, 0.5)).to.equal(true)
					expect(point.z - (halfD + 1) <= 3).to.equal(true) -- on the step, not out in the yard
					expect(point.y).to.equal(0)
				end
			end
		)

		it("clear of the back door and the straight path from it to the yard gate", function()
			local door = plot.backDoor
			local pathX1 = math.min(door.x - door.width / 2, plot.yardGate.x1)
			local pathX2 = math.max(door.x + door.width / 2, plot.yardGate.x2)
			for _, point in { plot.baitBowl, plot.baitCat } do
				expect(point.x > pathX2 + 1 or point.x < pathX1 - 1).to.equal(true)
			end
		end)

		it("the cat stands beside the bowl with its head over it", function()
			local dx = plot.baitCat.x - plot.baitBowl.x
			local dz = plot.baitCat.z - plot.baitBowl.z
			expect(math.sqrt(dx * dx + dz * dz)).to.be.near(1.6, 0.01)
		end)

		it("the cat is turned to face the bowl (QA)", function()
			-- WorldBuilder turns a point by CFrame.Angles(0, rad(rotY), 0), whose LookVector is (-sin, 0, -cos).
			local yaw = math.rad(plot.baitCat.rotY or 0)
			local dx = plot.baitBowl.x - plot.baitCat.x
			local dz = plot.baitBowl.z - plot.baitCat.z
			local length = math.sqrt(dx * dx + dz * dz)
			expect((-math.sin(yaw) * dx - math.cos(yaw) * dz) / length > 0.95).to.equal(true)
		end)

		it(
			"fills from the back door (QA; Tame and Let go reach everywhere since 2026-10-28)",
			function()
				local bowl, door = plot.baitBowl, plot.backDoor
				local function from(x: number, z: number): number
					return math.sqrt((x - bowl.x) ^ 2 + (z - bowl.z) ^ 2)
				end
				-- UseLure measures from the character's root, so 2 studs of slack for standing a step away.
				expect(from(door.x, halfD + 1) <= Config.BaitBowlRangeStuds - 2).to.equal(true)
			end
		)
	end)

	describe("the Lucky Cat statue by the front door (F88, luck-and-rare-moments.md 1a)", function()
		local plot = Layout.plot

		it("stands in the front garden on the ground, clear of the path to the door", function()
			local spot = plot.luckyCat
			expect(spot.y).to.equal(0)
			-- its plinth is 1.8 across: 0.9 each way stays in the garden and 1 stud off the path
			expect(inside(spot.x, spot.z, plot.frontGarden, 0.9)).to.equal(true)
			expect(inside(spot.x, spot.z, plot.frontPath, -1.9)).to.equal(false)
			expect(math.abs(spot.x - plot.door.x) <= 8).to.equal(true) -- beside the door, seen from the street
		end)
	end)

	-- Shortest walks over the Alleyway floor on a 1 stud grid, moving along x or z only, so every distance is at least
	-- the real walk. A cell is walkable when the floor reaches 1 stud past its centre every way (across the seams
	-- where one floor meets the next) and it is 1 stud clear of every wall. v4: the grid covers the set in the wild.
	local GRID_X0 = W.AlleyCenterX - (W.AlleyOuterX - W.AlleyLaneShift)
	local GRID_Z0 = W.AlleyCenterZ + W.AlleySouthZ
	local GRID_NX = math.ceil(2 * (W.AlleyOuterX - W.AlleyLaneShift))
	local GRID_NZ = math.ceil(W.AlleyNorthZ - W.AlleySouthZ)

	local function cellOf(x: number, z: number): number?
		local i = math.floor(x - GRID_X0)
		local j = math.floor(z - GRID_Z0)
		if i < 0 or i >= GRID_NX or j < 0 or j >= GRID_NZ then
			return nil
		end
		return j * GRID_NX + i
	end

	-- Built on first use inside a test, not while the specs are collected.
	local grid: { boolean }? = nil
	local function walkable(): { boolean }
		local built = grid
		if built ~= nil then
			return built
		end
		local cells: { boolean } = {}
		for j = 0, GRID_NZ - 1 do
			for i = 0, GRID_NX - 1 do
				local x, z = GRID_X0 + i + 0.5, GRID_Z0 + j + 0.5
				local clear = onFloor(x - 1, z - 1, alleyRects, 0)
					and onFloor(x + 1, z - 1, alleyRects, 0)
					and onFloor(x - 1, z + 1, alleyRects, 0)
					and onFloor(x + 1, z + 1, alleyRects, 0)
				cells[j * GRID_NX + i + 1] = clear and not inWall(x, z, alleyWalls, 1)
			end
		end
		grid = cells
		return cells
	end

	-- Studs from the cell at (x, z) to every cell, by cell index + 1, or -1 where it cannot be reached. Flat
	-- preallocated arrays keep the walks light on memory.
	local STEPS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local walks: { [number]: { number } } = {}
	local function walkFrom(x: number, z: number): { number }
		local open = walkable()
		local start = cellOf(x, z)
		assert(start ~= nil and open[start + 1], "the walk starts off the Alleyway floor")
		local cached = walks[start]
		if cached ~= nil then
			return cached
		end
		local count = GRID_NX * GRID_NZ
		local dist = table.create(count, -1)
		local queue = table.create(count, 0)
		dist[start + 1] = 0
		queue[1] = start
		local head, tail = 1, 1
		while head <= tail do
			local cell = queue[head]
			head += 1
			local i, j = cell % GRID_NX, cell // GRID_NX
			local here = dist[cell + 1]
			for _, step in STEPS do
				local ni, nj = i + step[1], j + step[2]
				if ni >= 0 and ni < GRID_NX and nj >= 0 and nj < GRID_NZ then
					local next = nj * GRID_NX + ni
					if open[next + 1] and dist[next + 1] < 0 then
						dist[next + 1] = here + 1
						tail += 1
						queue[tail] = next
					end
				end
			end
		end
		walks[start] = dist
		return dist
	end

	-- The walk's studs to (x, z), or nil when that point is off the grid or cut off.
	local function studsTo(dist: { number }, x: number, z: number): number?
		local cell = cellOf(x, z)
		if cell == nil or dist[cell + 1] < 0 then
			return nil
		end
		return dist[cell + 1]
	end

	-- The camp's two ways out, a stud inside each lane's north end, in world space.
	local function waysOut(): { { x: number, z: number } }
		local list = {}
		for _, side in { -1, 1 } do
			local x, z = fromLane(side * MID, W.AlleyNorthZ - 1.5)
			table.insert(list, { x = x, z = z })
		end
		return list
	end

	local nookPoints: { Point } = {}
	for _, point in alley.spawnPoints do
		if point.zone == "nook" then
			table.insert(nookPoints, point)
		end
	end

	describe("walk times in the Alleyway (acceptance check 4, docs PR #83; v4, F84)", function()
		it(
			"puts every near point under 2 seconds' walk from the camp line at NormalWalkSpeed",
			function()
				local line = W.AlleyCenterZ + W.AlleyNorthZ
				for n, point in alley.spawnPoints do
					if point.zone ~= "near" then
						continue
					end
					local x = toLane(point.x, point.z)
					local walk = math.abs(math.abs(x) - MID) + (line - point.z)
					if walk / Config.NormalWalkSpeed >= 2 then
						fail(
							"near point %d is %.1f s from the camp line",
							n,
							walk / Config.NormalWalkSpeed
						)
					end
				end
			end
		)

		it(
			"reaches every spawn point from each of the camp's ways out, the lanes joined by the passage (v4)",
			function()
				for _, out in waysOut() do
					local dist = walkFrom(out.x, out.z)
					for n, point in alley.spawnPoints do
						if studsTo(dist, point.x, point.z) == nil then
							fail(
								"spawn point %d at (%g, %g) cannot be reached",
								n,
								point.x,
								point.z
							)
						end
					end
				end
			end
		)

		it("carrying a cat from any nook to the camp takes 10 to 25 seconds (v4)", function()
			local outs = waysOut()
			local walksOut = {}
			for _, out in outs do
				table.insert(walksOut, walkFrom(out.x, out.z))
			end
			local worst, worstPoint = 0, 0
			for n, point in nookPoints do
				local nearest = math.huge
				for _, dist in walksOut do
					local walked = studsTo(dist, point.x, point.z)
					if walked ~= nil then
						nearest = math.min(nearest, walked + 1.5) -- and over the camp line
					end
				end
				if nearest == math.huge then
					fail("nook point %d cannot reach the camp", n)
				end
				local seconds = nearest / Config.CarryWalkSpeed
				if seconds > worst then
					worst, worstPoint = seconds, n
				end
			end
			expect(#nookPoints).to.equal(8)
			if worst >= 25 then
				fail("nook point %d is %.1f s from the camp at carry speed", worstPoint, worst)
			end
			-- the lanes are 251 studs long; a much shorter walk means the grid broke
			expect(worst > 10).to.equal(true)
		end)
	end)

	-- QA, v4 (F84, hometown-cannon.md sections 2 and 4): the hometown is a safe zone everywhere, and each camp is one
	-- up to its gate line, with the wild part starting a step past it.
	describe("camps and the safe hometown (v4, F84)", function()
		-- WorldBuilder.areaAt at floor height without the camps: the Alleyway's floor rects, one floor for a box area.
		local function areaAt(x: number, z: number): string?
			for id, spec in Layout.areas do
				local box = {
					x1 = spec.center.x - spec.halfWidth,
					z1 = spec.center.z - spec.halfDepth,
					x2 = spec.center.x + spec.halfWidth,
					z2 = spec.center.z + spec.halfDepth,
				}
				for _, rect in spec.rects or { box } do
					if x >= rect.x1 and x <= rect.x2 and z >= rect.z1 and z <= rect.z2 then
						return id
					end
				end
			end
			return nil
		end

		it("has no catching area or camp anywhere on the hometown's ground", function()
			local halfW, halfD = W.TownGroundWidth / 2, W.TownGroundDepth / 2
			for x = -halfW, halfW, 4 do
				for z = -halfD, halfD, 4 do
					if areaAt(x, z) ~= nil or Layout.campAt(x, z) ~= nil then
						fail(
							"(%g, %g) in town is in %s",
							x,
							z,
							tostring(areaAt(x, z) or Layout.campAt(x, z))
						)
					end
				end
			end
		end)

		it(
			"gives every area a camp, its rect ending at the gate line, where the wild part starts",
			function()
				for _, def in Catalog.areas do
					local camp = Layout.camps[def.id]
					expect(camp).to.be.ok()
					-- the Alleyway's ways out are its lanes' ends, either side of the block in the middle
					local wayOut = if def.id == "alley" then MID - W.AlleyLaneShift else 0
					for _, across in { -camp.halfAcross + 3, wayOut, camp.halfAcross - 3 } do
						local ix, iz = Layout.campPoint(camp, across, -0.2)
						expect(Layout.campAt(ix, iz)).to.equal(def.id)
						local ox, oz = Layout.campPoint(camp, across, 1)
						expect(Layout.campAt(ox, oz)).to.equal(nil)
						if across == wayOut then
							expect(areaAt(ox, oz)).to.equal(def.id) -- one step past the line is the wild part
						end
					end
					local size = math.abs(camp.rect.x2 - camp.rect.x1)
						* math.abs(camp.rect.z2 - camp.rect.z1)
					expect(size).to.be.near(2 * camp.halfAcross * W.CampDepth, 1e-6)
				end
			end
		)

		it("keeps every spawn point and rescue spot out of the camps", function()
			for id, spec in Layout.areas do
				for i, point in spec.spawnPoints do
					if Layout.campAt(point.x, point.z) ~= nil then
						fail("%s spawn point %d is in a camp", id, i)
					end
				end
				for i, spot in spec.rescueSpots do
					if Layout.campAt(spot.x, spot.z) ~= nil then
						fail("%s rescue spot %d is in a camp", id, i)
					end
				end
			end
		end)

		it(
			"moves a cat dropped at a camp's edge out to CampDropOutStuds past the line (section 4)",
			function()
				for _, camp in Layout.camps do
					for _, z in { -0.5, 0, 1.5 } do
						local x0, z0 = Layout.campPoint(camp, 4, z)
						local x, zz = Layout.outOfCamp(x0, z0)
						local lx, lz = Layout.campLocal(camp, x, zz)
						expect(lz).to.be.near(W.CampDropOutStuds, 1e-6)
						expect(lx).to.be.near(4, 1e-6)
						expect(Layout.campAt(x, zz)).to.equal(nil)
					end
					-- further out it stays put
					local fx, fz = Layout.campPoint(camp, 4, W.CampDropMarginStuds + 1)
					local x, z = Layout.outOfCamp(fx, fz)
					expect(x).to.equal(fx)
					expect(z).to.equal(fz)
				end
			end
		)

		it(
			"puts each camp's pad, its 17 spots, its cannon and the cannon's front inside the camp",
			function()
				for id, camp in Layout.camps do
					local pad = Layout.landingPads[id]
					expect(#pad.spots).to.equal(17)
					for n, spot in pad.spots do
						if not inside(spot.x, spot.z, camp.rect, 0) then
							fail("%s landing spot %d is outside its camp", id, n)
						end
						local dx, dz = spot.x - pad.centre.x, spot.z - pad.centre.z
						expect(math.sqrt(dx * dx + dz * dz) <= W.LandingPadRadius).to.equal(true)
					end
					for _, point in { Layout.cannons[id], Layout.cannonFronts[id] } do
						expect(inside(point.x, point.z, camp.rect, 0)).to.equal(true)
					end
					local front, cannon = Layout.cannonFronts[id], Layout.cannons[id]
					local reach = math.sqrt((front.x - cannon.x) ^ 2 + (front.z - cannon.z) ^ 2)
					expect(reach < W.CannonRangeStuds - 2).to.equal(true)
				end
			end
		)
	end)

	-- Town layout v3 (F76, town-layout-v3.md sections 2, 3 and 6).
	describe("the Town Square (layout v3, F76)", function()
		local square = Layout.townSquare
		local lanes = square.lanes :: { Rect }

		it("puts plots 1 to 4 by the square and 5 to 8 one row out, west then east", function()
			local want = { { -38, -58 }, { 38, -58 }, { -38, 58 }, { 38, 58 } }
			for n = 1, 4 do
				want[n + 4] = { want[n][1], want[n][2] + (if want[n][2] < 0 then -44 else 44) }
			end
			for index, xz in want do
				local placement = Layout.plotPlacement(index)
				expect(placement.x).to.equal(xz[1])
				expect(placement.z).to.equal(xz[2])
				expect(placement.side).to.equal(if xz[1] < 0 then -1 else 1)
			end
		end)

		it(
			"keeps every plot, yard included, off the square and inside the street's length",
			function()
				for index = 1, W.PlotCount do
					local z = Layout.plotPlacement(index).z
					expect(math.abs(z) - W.PlotWidth / 2 >= W.TownSquareHalfDepth + W.PlotRowGap).to.equal(
						true
					)
					expect(math.abs(z) + W.PlotWidth / 2 <= W.StreetNorthZ).to.equal(true)
				end
			end
		)

		it(
			"finds a side passage between every pair of neighbouring cafes and beside the gardens",
			function()
				local passages = Layout.sidePassages()
				expect(#passages).to.equal(4)
				for _, z in passages do
					for index = 1, W.PlotCount do
						local placement = Layout.plotPlacement(index)
						expect(math.abs(placement.z - z) >= W.PlotWidth / 2 + W.PlotRowGap / 2).to.equal(
							true
						)
					end
					expect(math.abs(z) > W.TownSquareHalfDepth).to.equal(true)
				end
			end
		)

		local stations: { [string]: Point } = {
			spinWheel = Layout.spinWheel,
			fishMarket = Layout.fishMarket,
			codesCat = Layout.codesCat,
			dealerCart = Layout.dealerCart,
		}

		it(
			"stands each station in its own quarter, off the open cross, facing the fountain",
			function()
				local quarters: { [string]: string } = {}
				for name, point in stations do
					expect(inside(point.x, point.z, square.floor, 4)).to.equal(true)
					for _, lane in lanes do
						if inside(point.x, point.z, lane, -5) then
							fail(
								"%s at (%g, %g) stands within 5 studs of the open cross",
								name,
								point.x,
								point.z
							)
						end
					end
					local quarter = (if point.x < 0 then "w" else "e")
						.. (if point.z < 0 then "s" else "n")
					expect(quarters[quarter]).to.equal(nil)
					quarters[quarter] = name
					-- WorldBuilder turns a point by CFrame.Angles(0, rad(rotY), 0), whose LookVector is (-sin, 0, -cos).
					local yaw = math.rad(point.rotY or 0)
					local lookX, lookZ = -math.sin(yaw), -math.cos(yaw)
					local length = math.sqrt(point.x * point.x + point.z * point.z)
					local dot = (lookX * -point.x + lookZ * -point.z) / length
					expect(dot > 0.999).to.equal(true)
				end
			end
		)

		it(
			"keeps the Codes circle clear of the cross and of the Spin Wheel's prompt (QA check 2)",
			function()
				local codes = Layout.codesCat
				local yaw = math.rad(codes.rotY or 0)
				local cx, cz = codes.x - 6 * math.sin(yaw), codes.z - 6 * math.cos(yaw)
				for _, lane in lanes do
					expect(inside(cx, cz, lane, -Config.CodesCircleRadius)).to.equal(false)
				end
				local wheel = Layout.spinWheel
				local gap = math.sqrt((cx - wheel.x) ^ 2 + (cz - wheel.z) ^ 2)
				expect(gap > Config.SpinStationRange + Config.CodesCircleRadius).to.equal(true)
			end
		)

		it(
			"puts the Bellhop stand at the lane's west end, facing the cannon, its card clear of the Codes circle (F96)",
			function()
				local stand = Layout.bellhopStand
				local DAIS = 4.6 -- half the stand's 9.2 stud dais
				expect(inside(stand.x, stand.z, square.floor, DAIS)).to.equal(true)
				expect(stand.x < 0).to.equal(true)
				expect(stand.z > Layout.codesCat.z and stand.z < Layout.spinWheel.z).to.equal(true)
				-- the street's line stays open past the dais
				expect(math.abs(stand.x) - DAIS > W.TownSquareLaneHalfWidth).to.equal(true)
				local yaw = math.rad(stand.rotY or 0)
				local lookX, lookZ = -math.sin(yaw), -math.cos(yaw)
				local length = math.sqrt(stand.x * stand.x + stand.z * stand.z)
				expect((lookX * -stand.x + lookZ * -stand.z) / length > 0.999).to.equal(true)
				-- walking into the stand's card never also opens the code box
				local codes = Layout.codesCat
				local codesYaw = math.rad(codes.rotY or 0)
				local cx, cz = codes.x - 6 * math.sin(codesYaw), codes.z - 6 * math.cos(codesYaw)
				local gap = math.sqrt((cx - stand.x) ^ 2 + (cz - stand.z) ^ 2)
				expect(gap > Config.StarterCatRangeStuds + 1 + Config.CodesCircleRadius + 1).to.equal(
					true
				)
				for name, point in stations do
					local apart = math.sqrt((point.x - stand.x) ^ 2 + (point.z - stand.z) ^ 2)
					if apart < DAIS + 8 then
						fail("the stand is %.1f studs from the %s", apart, name)
					end
				end
				for _, prop in square.props :: { any } do
					local apart = math.sqrt((prop.x - stand.x) ^ 2 + (prop.z - stand.z) ^ 2)
					if prop.asset ~= "CatCafe_Square_Paving" and apart < DAIS + 1 then
						fail(
							"%s at (%g, %g) stands on the stand's dais",
							prop.asset,
							prop.x,
							prop.z
						)
					end
				end
			end
		)

		it("stands the leaderboards at the lane's east end, facing the cannon, clear of the edge and the stations (F98)", function()
			local row = Layout.leaderboards
			local HALF_LONG, HALF_DEEP = 11.9, 1.35 -- the row turned: 23.8 along z, 2.7 along x
			expect(row.x > 0).to.equal(true)
			expect(row.x + HALF_DEEP < W.TownSquareHalfWidth - 5).to.equal(true) -- in front of the edge lamps
			expect(math.abs(row.z) + HALF_LONG < W.TownSquareHalfDepth).to.equal(true)
			expect(row.x - HALF_DEEP > W.TownSquareLaneHalfWidth).to.equal(true) -- the street's line stays open
			local yaw = math.rad(row.rotY or 0)
			local lookX, lookZ = -math.sin(yaw), -math.cos(yaw)
			local length = math.sqrt(row.x * row.x + row.z * row.z)
			expect((lookX * -row.x + lookZ * -row.z) / length > 0.999).to.equal(true)
			for name, point in stations do
				local dx, dz = math.abs(point.x - row.x), math.abs(point.z - row.z)
				if dx < HALF_DEEP + 4 and dz < HALF_LONG + 4 then
					fail("the leaderboards stand on the %s", name)
				end
			end
		end)

		it(
			"spawns players on the street's line in the square, looking north at the fountain",
			function()
				local spawn = Layout.playerSpawn
				expect(math.abs(spawn.x) <= W.TownSquareLaneHalfWidth).to.equal(true)
				expect(inside(spawn.x, spawn.z, square.floor, 0)).to.equal(true)
				expect(spawn.z < -Layout.townSquare.fountainRadius).to.equal(true)
				expect(math.abs(math.sin(math.rad(spawn.rotY or 0)))).to.be.near(0, 1e-9)
				expect(-math.cos(math.rad(spawn.rotY or 0))).to.equal(1)
			end
		)

		it(
			"runs the gardens out to the town's back edge, where the side arches into the back alleys stood (v4)",
			function()
				expect(square.gardens[1].x1).to.equal(-W.TownEdgeX)
				expect(square.gardens[2].x2).to.equal(W.TownEdgeX)
				expect((square :: any).arches).to.equal(nil)
			end
		)

		it(
			"keeps every Alleyway rescue spot 9 studs from every spawn point (reviewer N77)",
			function()
				for _, spot in alley.rescueSpots do
					for _, point in alley.spawnPoints do
						local gap = math.sqrt((spot.x - point.x) ^ 2 + (spot.z - point.z) ^ 2)
						if gap < 9 then
							fail(
								"%s at (%g, %g) is %.1f from the spawn point at (%g, %g)",
								spot.prop,
								spot.x,
								spot.z,
								gap,
								point.x,
								point.z
							)
						end
					end
				end
			end
		)

		it("keeps the back alleys' loose props 6 studs from every lane spawn point", function()
			for _, prop in alley.props :: { Layout.Prop } do
				local name = prop.asset
				local loose = name:find("Dumpster", 1, true) ~= nil
					or name:find("GarbageBags", 1, true) ~= nil
					or name:find("TrashCan", 1, true) ~= nil
					or name:find("_Crate", 1, true) ~= nil
						and name:find("CrateStack", 1, true) == nil
				if not loose then
					continue
				end
				for _, point in alley.spawnPoints do
					local gap = math.sqrt((prop.x - point.x) ^ 2 + (prop.z - point.z) ^ 2)
					if gap < 6 then
						fail(
							"%s at (%g, %g) is %.1f from the spawn point at (%g, %g)",
							name,
							prop.x,
							prop.z,
							gap,
							point.x,
							point.z
						)
					end
				end
			end
		end)

		-- Model-Agent #535: eight full buildings in place of the repeated backs and the staff doors; v4 a seventh on
		-- each outer wall where the Woods or Sewer gate stood.
		it(
			"lines each lane's outer wall with seven different buildings, a crate stack by each Warehouse",
			function()
				local prefix = "CatCafe_Alley_Building_"
				for _, side in { -1, 1 } do
					local seen: { [string]: boolean } = {}
					local count, warehouses, stacks = 0, 0, 0
					for _, prop in alley.props :: { Layout.Prop } do
						local x = toLane(prop.x, prop.z)
						if x * side <= 0 then
							continue
						end
						local onOuterWall = math.abs(x) > W.AlleyOuterX
						if prop.asset:sub(1, #prefix) == prefix and onOuterWall then
							count += 1
							if seen[prop.asset] then
								fail("%s stands twice on side %d", prop.asset, side)
							end
							seen[prop.asset] = true
							if prop.asset == prefix .. "Warehouse" then
								warehouses += 1
							end
						elseif prop.asset == "CatCafe_Alley_CrateStack" then
							stacks += 1
						end
					end
					expect(count).to.equal(7)
					expect(warehouses).to.equal(1)
					expect(stacks).to.equal(warehouses)
				end
			end
		)

		it(
			"keeps every building's back plane at its wall, on the outer walls and at the far end (v4)",
			function()
				local prefix = "CatCafe_Alley_Building_"
				local ends = 0
				for _, prop in alley.props :: { Layout.Prop } do
					if prop.asset:sub(1, #prefix) ~= prefix then
						continue
					end
					local x, z = toLane(prop.x, prop.z)
					if math.abs(x) > W.AlleyOuterX then
						expect(math.abs(x) <= W.AlleyOuterX + 2.5).to.equal(true)
					else
						ends += 1
						expect(z <= W.AlleySouthZ and z >= W.AlleySouthZ - 1).to.equal(true)
					end
				end
				expect(ends).to.equal(2) -- both south ends; the north ends open into the camp
			end
		)
	end)

	-- v4 (F84, hometown-cannon.md sections 2, 3 and 6a): the hometown in the middle, every catching area far out and
	-- reached by the Cat Cannon on the old fountain's plinth.
	describe("the hometown and the far areas (v4, F84)", function()
		local square = Layout.townSquare
		local lanes = square.lanes :: { Rect }

		-- An area's floor and camp as one box.
		local function bounds(id: string): Rect
			local spec = Layout.areas[id]
			local r = Layout.camps[id].rect
			return {
				x1 = math.min(spec.center.x - spec.halfWidth, r.x1),
				z1 = math.min(spec.center.z - spec.halfDepth, r.z1),
				x2 = math.max(spec.center.x + spec.halfWidth, r.x2),
				z2 = math.max(spec.center.z + spec.halfDepth, r.z2),
			}
		end

		-- The gap between two boxes, 0 when they overlap.
		local function gap(a: Rect, b: Rect): number
			local dx = math.max(0, math.max(a.x1, b.x1) - math.min(a.x2, b.x2))
			local dz = math.max(0, math.max(a.z1, b.z1) - math.min(a.z2, b.z2))
			return math.sqrt(dx * dx + dz * dz)
		end

		it(
			"puts every area WildAreaDistance out the old compass way, far from the town and each other",
			function()
				local ways = {
					alley = { -1, -1 },
					park = { 0, -1 },
					neighbourhood = { 0, 1 },
					woods = { -1, 0 },
					sewer = { 1, 0 },
				} :: { [string]: { number } }
				local town: Rect = {
					x1 = -W.TownGroundWidth / 2,
					z1 = -W.TownGroundDepth / 2,
					x2 = W.TownGroundWidth / 2,
					z2 = W.TownGroundDepth / 2,
				}
				for id, spec in Layout.areas do
					local way = ways[id]
					expect(way).to.be.ok()
					local out = math.sqrt(spec.center.x ^ 2 + spec.center.z ^ 2)
					expect(out >= 0.95 * W.WildAreaDistance).to.equal(true)
					local length = math.sqrt(way[1] ^ 2 + way[2] ^ 2)
					local dot = (spec.center.x * way[1] + spec.center.z * way[2]) / (out * length)
					expect(dot > 0.99).to.equal(true)
					if gap(bounds(id), town) < 1000 then
						fail("the %s is %.0f studs from the town", id, gap(bounds(id), town))
					end
					for other in Layout.areas do
						if other ~= id and gap(bounds(id), bounds(other)) < 500 then
							fail(
								"the %s is %.0f studs from the %s",
								id,
								gap(bounds(id), bounds(other)),
								other
							)
						end
					end
				end
			end
		)

		it(
			"stands every gate across the middle of its camp's way out, its front toward the camp",
			function()
				local want = {
					alley = { W.AlleyCenterX, W.AlleyCenterZ + W.AlleyNorthZ, 180 },
					park = { 0, W.ParkCenterZ + W.ParkDepth / 2, 180 },
					neighbourhood = { 0, W.NeighbourhoodCenterZ - W.NeighbourhoodDepth / 2, 0 },
					woods = { W.WoodsCenterX + W.WoodsWidth / 2, 0, -90 },
					sewer = { W.SewerCenterX - W.SewerWidth / 2, 0, 90 },
				} :: { [string]: { number } }
				for id, spec in Layout.areas do
					local x, z = Layout.gatePosition(spec)
					local gate = want[id]
					expect(x).to.be.near(gate[1], 1e-9)
					expect(z).to.be.near(gate[2], 1e-9)
					expect(Layout.gateTurn(spec)).to.equal(gate[3])
					-- the front, CFrame.Angles(0, rad(turn), 0)'s LookVector (-sin, 0, -cos), points into the camp
					local camp = Layout.camps[id]
					local yaw = math.rad(gate[3])
					local cx, cz = Layout.campPoint(camp, 0, -W.CampDepth / 2)
					local dx, dz = cx - (x :: number), cz - (z :: number)
					local dot = (-math.sin(yaw) * dx - math.cos(yaw) * dz)
						/ math.sqrt(dx * dx + dz * dz)
					expect(dot).to.be.near(1, 1e-9)
				end
			end
		)

		it(
			"stands the Cat Cannon on the old fountain's plinth, its pad at its south foot round the spawn",
			function()
				local cannon = Layout.cannons.town
				expect(cannon.x).to.equal(0)
				expect(cannon.z).to.equal(0)
				local pad = Layout.landingPads.town
				expect(#pad.spots).to.equal(17)
				expect(pad.centre.x).to.equal(0)
				expect(pad.centre.z < -square.fountainRadius - W.LandingPadRadius + 0.5).to.equal(
					true
				)
				for n, spot in pad.spots do
					if not inside(spot.x, spot.z, square.floor, 0) then
						fail("town landing spot %d is off the square", n)
					end
				end
				local spawn = Layout.playerSpawn
				local fromPad =
					math.sqrt((spawn.x - pad.centre.x) ^ 2 + (spawn.z - pad.centre.z) ^ 2)
				expect(fromPad <= W.LandingPadRadius).to.equal(true)
				-- the Cannon button's spot in town: in front of the plinth, the prompt in reach
				local front = Layout.cannonFronts.town
				local reach = math.sqrt(front.x ^ 2 + front.z ^ 2)
				expect(reach > square.fountainRadius and reach < W.CannonRangeStuds - 2).to.equal(
					true
				)
				expect(front.z < 0).to.equal(true)
			end
		)

		it("turns the town cannon toward each area it fires at", function()
			for id, spec in Layout.areas do
				local aim = math.rad(Layout.cannonAim(id))
				local out = math.sqrt(spec.center.x ^ 2 + spec.center.z ^ 2)
				-- the barrel rests along +Z; turned by aim it points along (sin, cos)
				local dot = (math.sin(aim) * spec.center.x + math.cos(aim) * spec.center.z) / out
				expect(dot).to.be.near(1, 1e-9)
			end
			expect(Layout.cannonAim("town")).to.equal(0)
		end)

		it("stands the signpost by the cannon's plinth, south-west and off the cross", function()
			local post = square.signpost :: Point
			expect(post.x < 0 and post.z < 0).to.equal(true)
			local fromCannon = math.sqrt(post.x ^ 2 + post.z ^ 2)
			expect(fromCannon > square.fountainRadius + 3 and fromCannon < 15).to.equal(true)
			for _, lane in lanes do
				expect(inside(post.x, post.z, lane, -0.5)).to.equal(false)
			end
		end)

		it(
			"closes the town at its edges: fences behind the yards and walls across both street ends",
			function()
				local edges = Layout.townEdges
				expect(#edges).to.equal(4)
				for _, side in { -1, 1 } do
					for z = W.StreetSouthZ, W.StreetNorthZ, 4 do
						expect(inWall(side * (W.TownEdgeX + 0.5), z, edges, 0)).to.equal(true)
					end
				end
				for x = -W.StreetHalfWidth, W.StreetHalfWidth, 2 do
					expect(inWall(x, W.StreetSouthZ - 2, edges, 0)).to.equal(true)
					expect(inWall(x, W.StreetNorthZ + 2, edges, 0)).to.equal(true)
				end
				expect(#Layout.townEnds).to.equal(2)
			end
		)

		it(
			"lays a paw path from each street end in to the cannon's plinth, every print facing it",
			function()
				local north, south = math.huge, math.huge
				local farthest = 0
				for _, paw in Layout.pawPrints() do
					expect(paw.area).to.equal("town")
					expect(math.abs(paw.x) <= 1).to.equal(true)
					local along = math.abs(paw.z)
					farthest = math.max(farthest, along)
					if paw.z > 0 then
						north = math.min(north, along)
					else
						south = math.min(south, along)
					end
					-- its front (-Z) turned toward the cannon at the origin
					local yaw = math.rad(paw.rotY)
					local out = math.sqrt(paw.x ^ 2 + paw.z ^ 2)
					expect((-math.sin(yaw) * -paw.x - math.cos(yaw) * -paw.z) / out > 0.99).to.equal(
						true
					)
					if inWall(paw.x, paw.z, Layout.townEdges, 0.9) then
						fail("paw print at (%g, %g) is in the town's edge", paw.x, paw.z)
					end
				end
				expect(north <= square.fountainRadius + 6 and south <= square.fountainRadius + 6).to.equal(
					true
				)
				expect(farthest >= W.StreetNorthZ - 10).to.equal(true)
			end
		)
	end)

	describe("cafe tables off the door to counter walk (QA, engineer PR #433)", function()
		-- Layout.plot.tables: a table and its two chairs reach REACH either side of its x and DEPTH in front and behind
		-- (the Layout comment), so the aisle from the front door to the counter stays clear from -AISLE to AISLE.
		local plot = Layout.plot
		local halfD = W.PlotDepth / 2
		local REACH, DEPTH, AISLE = 3.7, 2.1, 6.3

		local function corners(spot: any): { { number } }
			local x1, x2 = spot.x - REACH, spot.x + REACH
			local z1, z2 = spot.z - DEPTH, spot.z + DEPTH
			return { { x1, z1 }, { x1, z2 }, { x2, z1 }, { x2, z2 } }
		end

		it("keeps six tables, filled two a tier, a mirrored pair on each row", function()
			expect(#plot.tables).to.equal(6)
			for pair = 1, 3 do
				local left, right = plot.tables[2 * pair - 1], plot.tables[2 * pair]
				expect(left.x < 0 and right.x > 0).to.equal(true)
				expect(left.z).to.equal(right.z)
				expect(left.lane).to.equal(right.lane)
			end
			expect(plot.tables[1].z < plot.tables[3].z and plot.tables[3].z < plot.tables[5].z).to.equal(
				true
			)
		end)

		it("leaves the aisle clear: no table or chair reaches inside x -6.3 to 6.3", function()
			expect(plot.seatOffsets[2].x + 1.3 <= REACH + 1e-9).to.equal(true)
			for i, spot in plot.tables do
				if math.abs(spot.x) - REACH < AISLE - 1e-9 then
					fail("table %d at x %.2f reaches into the aisle", i, spot.x)
				end
			end
			expect(math.abs(plot.door.x) < AISLE and math.abs(plot.counter.x) < AISLE).to.equal(
				true
			)
			expect(math.abs(plot.orderPoint.x) < AISLE).to.equal(true)
		end)

		it(
			"walks customers down the aisle clear of the waiters and along lanes clear of every table",
			function()
				for _, role in { "waiter_1", "waiter_2", "waiter_3" } do
					expect(math.abs(plot.spots[role].x) - plot.aisleX >= 2).to.equal(true)
				end
				expect(plot.aisleX > 0 and plot.aisleX + 1 <= AISLE).to.equal(true)
				for i, spot in plot.tables do
					expect(math.abs(spot.lane) < halfD - 1).to.equal(true)
					for j, other in plot.tables do
						if math.abs(spot.lane - other.z) < DEPTH + 0.5 then
							fail(
								"table %d's lane z %.2f runs through table %d at z %.2f",
								i,
								spot.lane,
								j,
								other.z
							)
						end
					end
				end
			end
		)

		it(
			"keeps the straight walk from the back door to the front door a stud clear of every table (N237)",
			function()
				local ax, az = plot.backDoor.x, halfD
				local dx, dz = plot.door.x - ax, plot.door.z - az
				local length = math.sqrt(dx * dx + dz * dz)
				for i, spot in plot.tables do
					local nearest, side = math.huge, 0
					for _, corner in corners(spot) do
						local cross = ((corner[1] - ax) * dz - (corner[2] - az) * dx) / length
						if side ~= 0 and (cross > 0) ~= (side > 0) then
							fail("the walk crosses table %d", i)
						end
						side = cross
						nearest = math.min(nearest, math.abs(cross))
					end
					if nearest < 1 then
						fail("the walk passes table %d only %.2f studs clear", i, nearest)
					end
				end
			end
		)

		it("puts the rich tip's coin pile on table 1, where the rich customer sits", function()
			expect(plot.richTip.x).to.equal(plot.tables[1].x)
			expect(plot.richTip.z).to.equal(plot.tables[1].z)
			expect(plot.richTip.y > 0).to.equal(true)
		end)
	end)

	describe("the Town Square set (QA, engineer PR #444)", function()
		local square = Layout.townSquare
		local TSW, TSD = W.TownSquareHalfWidth, W.TownSquareHalfDepth

		local function piecesOf(asset: string): { any }
			local found = {}
			for _, prop in square.props :: { any } do
				if prop.asset == asset then
					table.insert(found, prop)
				end
			end
			return found
		end

		local function onCross(x: number, z: number, margin: number): boolean
			return math.abs(x) < W.TownSquareLaneHalfWidth + margin
				or (math.abs(z) < W.TownSquareCrossHalfWidth + margin and math.abs(x) <= TSW)
		end

		it(
			"names every piece CatCafe_Square_ and keeps the paving at the origin, the fountain gone for the cannon",
			function()
				for _, prop in square.props :: { any } do
					expect(string.sub(prop.asset, 1, 15)).to.equal("CatCafe_Square_")
				end
				local paving = piecesOf("CatCafe_Square_Paving")
				expect(#paving).to.equal(1)
				expect(paving[1].x).to.equal(0)
				expect(paving[1].z).to.equal(0)
				expect(#piecesOf("CatCafe_Square_Fountain")).to.equal(0) -- v4: the Cat Cannon stands there
			end
		)

		it(
			"lines the square's edge with eight benches, each turned square to face in (Derek 10-28, #726)",
			function()
				local benches = piecesOf("CatCafe_Square_Bench")
				expect(#benches).to.equal(8)
				for i, bench in benches do
					-- WorldBuilder turns a prop by CFrame.Angles(0, rad(rotY), 0); its front (-Z) is (-sin, -cos)
					local turn = math.rad(bench.rotY or 0)
					local lookX, lookZ = -math.sin(turn), -math.cos(turn)
					if lookX * -bench.x + lookZ * -bench.z <= 0 then
						fail(
							"bench %d at (%.2f, %.2f) faces out of the square",
							i,
							bench.x,
							bench.z
						)
					end
					local off = (bench.rotY or 0) % 90
					expect(math.min(off, 90 - off) < 0.5).to.equal(true)
					local dx, dz = bench.x - square.signpost.x, bench.z - square.signpost.z
					expect(math.sqrt(dx * dx + dz * dz) >= 4).to.equal(true)
				end
			end
		)

		it(
			"keeps the benches, lamps and buntings at the edge, the middle and the quarters free (#726)",
			function()
				local EDGE = 3 -- studs in from the square's border
				for _, asset in
					{
						"CatCafe_Square_Bench",
						"CatCafe_Square_Lamp",
						"CatCafe_Square_Bunting",
						"CatCafe_Square_BuntingShort",
					}
				do
					for i, piece in piecesOf(asset) do
						local atEdge = math.abs(piece.x) >= TSW - EDGE
							or math.abs(piece.z) >= TSD - EDGE
						if not atEdge or math.abs(piece.x) > TSW or math.abs(piece.z) > TSD then
							fail(
								"%s %d at (%.2f, %.2f) is not on the square's edge",
								asset,
								i,
								piece.x,
								piece.z
							)
						end
					end
				end
				expect(#piecesOf("CatCafe_Square_Bunting")).to.equal(8)
				expect(#piecesOf("CatCafe_Square_BuntingShort")).to.equal(2)
			end
		)

		it("keeps benches, lamps and gardens off the open cross and the spawn", function()
			local spawn = Layout.playerSpawn
			for _, asset in
				{ "CatCafe_Square_Bench", "CatCafe_Square_Lamp", "CatCafe_Square_Garden" }
			do
				for i, piece in piecesOf(asset) do
					if onCross(piece.x, piece.z, 1) then
						fail(
							"%s %d at (%.2f, %.2f) stands on the open cross",
							asset,
							i,
							piece.x,
							piece.z
						)
					end
					local dx, dz = piece.x - spawn.x, piece.z - spawn.z
					expect(math.sqrt(dx * dx + dz * dz) >= 6).to.equal(true)
				end
			end
			expect(#piecesOf("CatCafe_Square_Lamp")).to.equal(12)
		end)

		it("puts the gardens in the garden strips, clear of the path to the side arches", function()
			local gardens = piecesOf("CatCafe_Square_Garden")
			expect(#gardens).to.equal(4)
			for _, garden in gardens do
				local strip = if garden.x < 0 then square.gardens[1] else square.gardens[2]
				expect(inside(garden.x, garden.z, strip, 0)).to.equal(true)
				expect(math.abs(garden.z) > W.TownSquareCrossHalfWidth + 6).to.equal(true)
			end
		end)

		it("hangs a sign arch over the street at the square's north and south edges", function()
			local arches = piecesOf("CatCafe_Square_SignArch")
			expect(#arches).to.equal(2)
			local north, south = false, false
			for _, arch in arches do
				expect(arch.x).to.equal(0)
				expect(math.abs(arch.z)).to.equal(TSD)
				north = north or arch.z > 0
				south = south or arch.z < 0
			end
			expect(north and south).to.equal(true)
		end)
	end)

	describe("the cat beds (F79, Model-Agent #511)", function()
		local plot = Layout.plot
		local halfW, halfD = W.PlotWidth / 2, W.PlotDepth / 2
		local CLEAR = 2 -- studs from a bed's centre to anything else's

		local function apart(bed: any, x: number, z: number): number
			return math.sqrt((bed.x - x) ^ 2 + (bed.z - z) ^ 2)
		end

		it(
			"adds two beds a tier from Tier 3, so the trees' four places and the beds sleep every working slot",
			function()
				expect(#plot.beds).to.equal(6)
				for n, bed in plot.beds do
					expect(bed.id).to.equal("bed_" .. n)
					expect(bed.tier).to.equal(2 + math.ceil(n / 2))
				end
				for _, tier in Catalog.tiers do
					local places = 4
					for _, bed in plot.beds do
						if tier.tier >= bed.tier then
							places += 1
						end
					end
					if places < tier.slots then
						fail(
							"Tier %d has %d working slots and only %d sleep places",
							tier.tier,
							tier.slots,
							places
						)
					end
				end
			end
		)

		it("stands each bed on the floor inside the walls, facing into the room", function()
			for _, bed in plot.beds do
				expect(bed.y).to.equal(0)
				expect(math.abs(bed.x) <= halfW - 1.5 and math.abs(bed.z) <= halfD - 1.5).to.equal(
					true
				)
				-- the front (-Z turned rotY about Y) points away from the nearest walls, toward the middle
				local angle = math.rad(bed.rotY)
				local frontX, frontZ = -math.sin(angle), -math.cos(angle)
				if frontX * -bed.x + frontZ * -bed.z <= 0 then
					fail("%s faces the wall", bed.id)
				end
			end
		end)

		it(
			"keeps every bed clear of the nap spots, decor spots, tables, stations, cat trees and the other beds",
			function()
				for _, bed in plot.beds do
					local function check(what: string, x: number, z: number)
						if apart(bed, x, z) < CLEAR then
							fail("%s is %.2f studs from %s", bed.id, apart(bed, x, z), what)
						end
					end
					for n, spot in plot.napSpots do
						check("nap spot " .. n, spot.x, spot.z)
					end
					for n, spot in plot.decorSpots do
						check("decor spot " .. n, spot.x, spot.z)
					end
					for n, spot in plot.tables do
						check("table " .. n, spot.x, spot.z)
					end
					for id, spot in plot.spots do
						check(id, spot.x, spot.z)
					end
					for id, spot in plot.spotFurniture do
						check(id .. "'s cat tree", spot.x, spot.z)
					end
					for _, other in plot.beds do
						if other ~= bed then
							check(other.id, other.x, other.z)
						end
					end
				end
			end
		)
	end)

	describe("cats make the orders (F90, cats-make-orders.md section 3)", function()
		local plot = Layout.plot
		local halfW, halfD = W.PlotWidth / 2, W.PlotDepth / 2
		-- footprints as plot-local boxes {x1, z1, x2, z2}: the counter (CatCafe_Furniture_Counter, 8.4 by 2.6 about
		-- its pivot), the oven (Model-Agent #775: 3.2 wide, 2.9 deep, base centre), the till and the level 3 espresso
		-- machine on the counter top, and a seated cat (Scale 1.2) round its spot
		local function box(x: number, z: number, w: number, d: number): { number }
			return { x - w / 2, z - d / 2, x + w / 2, z + d / 2 }
		end
		local function overlaps(a: { number }, b: { number }): boolean
			return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
		end
		local counter = { plot.counter.x - 4.2, plot.counter.z - 1.33, plot.counter.x + 4.2, plot.counter.z + 1.3 }
		local oven = box(plot.oven.x, plot.oven.z, 3.2, 2.9)
		local till = { 0.7, plot.counter.z - 0.15, 1.7, plot.counter.z + 0.7 }
		local espresso = { plot.espresso.x - 1.23, plot.espresso.z - 1.15, plot.espresso.x + 1.23, plot.espresso.z + 0.5 }
		local function cat(spot: any): { number }
			return { spot.x - 0.75, spot.z - 0.78, spot.x + 0.75, spot.z + 0.76 }
		end

		it("stands the oven on the floor against the back wall, clear of the counter and the back door", function()
			expect(plot.oven.y).to.equal(0)
			expect(oven[4] <= halfD - 0.25 and oven[4] >= halfD - 0.5).to.equal(true)
			expect(overlaps(oven, counter)).to.equal(false)
			local door = plot.backDoor
			expect(oven[1] > door.x + door.width / 2 or oven[3] < door.x - door.width / 2).to.equal(true)
			expect(oven[3] <= halfW - 1).to.equal(true)
		end)

		it("keeps the oven and its open door clear of every cat spot, decor spot, nap spot and bed", function()
			-- the door (Model-Agent #775) hinges at the front 1.2 in from the pivot and is 1.75 long, so open flat it
			-- reaches 2.95 in front of the pivot
			local swept = { oven[1], plot.oven.z - 2.95, oven[3], oven[4] }
			for id, spot in plot.spots do
				if overlaps(swept, cat(spot)) then
					fail("the oven or its open door overlaps %s", id)
				end
			end
			for n, spot in plot.decorSpots do
				-- the widest decor piece is 4.2 across and 2.5 deep
				local turned = spot.rotY == 90 or spot.rotY == -90
				local piece = if turned then box(spot.x, spot.z, 2.5, 4.2) else box(spot.x, spot.z, 4.2, 2.5)
				if overlaps(oven, piece) then
					fail("the oven overlaps decor spot %d", n)
				end
			end
			for n, spot in plot.napSpots do
				if overlaps(oven, cat(spot)) then
					fail("the oven overlaps nap spot %d", n)
				end
			end
			for _, bed in plot.beds do
				if overlaps(oven, box(bed.x, bed.z, 2.65, 2.65)) then
					fail("the oven overlaps %s", bed.id)
				end
			end
		end)

		it("puts the pass on the counter top, a plate clear of the till, the espresso machine and the tip jar", function()
			local plate = box(plot.pass.x, plot.pass.z, 1.1, 1.1)
			expect(plot.pass.y).to.equal(3)
			expect(plate[1] >= counter[1] and plate[3] <= counter[3]).to.equal(true)
			expect(plate[2] >= counter[2] - 0.05 and plate[4] <= counter[4]).to.equal(true)
			expect(overlaps(plate, till)).to.equal(false)
			expect(overlaps(plate, espresso)).to.equal(false)
			expect(overlaps(plate, box(0.2, plot.counter.z - 0.6, 0.4, 0.4))).to.equal(false) -- the tip jar
		end)

		it("has the Waiter pick up in front of the counter, clear of the queue and the Cat Collector", function()
			expect(plot.pickup.y).to.equal(0)
			local body = cat(plot.pickup)
			expect(body[4] <= counter[2]).to.equal(true)
			expect(math.abs(plot.pickup.x) < 6.3 - 1).to.equal(true) -- in the aisle, off the tables
			expect(overlaps(body, box(plot.collectorSpot.x, plot.collectorSpot.z, 1.56, 1.99))).to.equal(false)
			-- behind the queue's line at the right edge of its spread, so a customer ordering there brushes it at most
			expect(plot.pickup.z - plot.orderPoint.z >= 0.8 and plot.pickup.x >= 2.5).to.equal(true)
		end)

		it("drops the swept coin bag on the till", function()
			local x, z = plot.tillStack.x, plot.tillStack.z
			expect(x > till[1] and x < till[3] and z > till[2] and z < till[4]).to.equal(true)
			expect(plot.tillStack.y > 3).to.equal(true)
		end)
	end)
end
