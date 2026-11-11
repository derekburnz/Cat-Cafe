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
	local FeedbackStand = require(Shared.FeedbackStand)
	local Layout = require(ServerScriptService.Server.World.Layout)
	local WalkUp = require(Shared.WalkUp)

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
				park = "CatCafe_Park_SetF85", -- F85 (#799)
				neighbourhood = "CatCafe_Neighbourhood_SetF85", -- F85 (#810)
				woods = "CatCafe_Woods_SetF85", -- F85 (#847)
				sewer = "CatCafe_Sewer_SetF85", -- F85 (#860)
			}
			for id, name in sets do
				local spec = Layout.areas[id]
				expect(spec.set).to.equal(name)
				local turn = Layout.gateTurn(spec)
				-- on the ground or a low perch (a porch, a rock, the catwalk), never a roof; the Woods' tree house
				-- cushion and the Great Oak's top nook, up their ladders, are the high spots, and the Sewer's junk
				-- throne seat up on its dais
				local top = spec.floorY
					+ (if id == "woods" then 18.5 elseif id == "sewer" then 4.5 else 4)
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
					then { 20, -20, 0, 0, 87.21 }
					elseif id == "sewer" then { 0, 0, -90, 90 }
					elseif id == "neighbourhood" then { 0, 90, 0, 0 }
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
				-- the Park's plaza at local (-4, -145) is near its gate side, the Neighbourhood's porch at local
				-- (5.05, -166.9) near its own, the Woods' berry bush at local (-30, -223.8) near its own, the Sewer's
				-- brick bridge at local (-26, -205) near its own
				local index = if id == "woods" then 4 else 1
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
		-- top is "rare" (Catching.RARE_ZONE), in the far half too. The Sewer's zones go by region (#491, #860): its
		-- near spots are all in the gate half, and deep starts on the channel's catwalk, right on the middle line.
		it(
			"the v3.2 sets' spots are near their gates or deep in their far halves, with traps deep",
			function()
				local rows = {
					{
						id = "park", -- F85 (#799): four of its five traps deep
						near = 20,
						deep = 28,
						rare = 0,
						deepTraps = 4,
						byRegion = false,
					},
					{
						id = "woods", -- F85 (#847): four of its five traps deep
						near = 28,
						deep = 43,
						rare = 1,
						deepTraps = 4,
						byRegion = false,
					},
					{
						id = "sewer", -- F85 (#860): three of its four traps deep
						near = 25,
						deep = 35,
						rare = 0,
						deepTraps = 3,
						byRegion = true,
					},
					{
						id = "neighbourhood", -- F85 (#810): three of its four traps deep
						near = 32, -- #905's islands: four side path spots for the near porch
						deep = 45,
						rare = 0,
						deepTraps = 3,
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
				-- the Park's traps are the world's trees and bins, the first (F85) a prop with no turn in the set, which
				-- is turned 180 itself
				for _, spot in Layout.park.rescueSpots do
					expect(spot.prop).to.be.ok()
				end
				expect(Layout.park.rescueSpots[1].rotY).to.equal(180)
			end
		)

		-- F85 (hometown-cannon.md 6b; QA edge): whatever a long set's spots, it keeps what makes the carry home long.
		-- The table's size is width x length with the 30 stud camp, and the v3.2 counts are the floors 6b keeps
		-- (F81 rows: Park 16 + 24 spots, Neighbourhood 28 + 44, Woods 26 + 38 + the oak's rare, Sewer 20 + 32). In camp
		-- space z is how far in from the gate line, the camp's edge, so "none within 100 studs of the camp" is z > 100.
		-- An area joins when its set is a SetF85 one; one in the table that is not yet is skipped.
		it(
			"F85's long sets are 6b's size, with their traps deep and none near the camp (QA)",
			function()
				local rows: { [string]: { width: number, length: number, spots: number, traps: number } } =
					{
						park = { width = 120, length = 340, spots = 40, traps = 5 },
						neighbourhood = { width = 180, length = 460, spots = 72, traps = 4 },
						woods = { width = 160, length = 520, spots = 65, traps = 5 },
						sewer = { width = 120, length = 600, spots = 52, traps = 4 },
					}
				local long = 0
				for id, spec in Layout.areas do
					local set = spec.set
					if set == nil or string.sub(set, -7) ~= "_SetF85" then
						continue
					end
					local row = rows[id]
					if row == nil then
						fail("%s has a long set (%s) with no row here", id, set)
					end
					long += 1
					local camp = Layout.camps[id]
					expect(camp).to.be.ok()
					-- the set's floor from its four corners, across and along the way in
					local x1, x2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local x, z = Layout.campLocal(
								camp,
								spec.center.x + sx * spec.halfWidth,
								spec.center.z + sz * spec.halfDepth
							)
							x1, x2 = math.min(x1, x), (math.max(x2, x))
							z1, z2 = math.min(z1, z), (math.max(z2, z))
						end
					end
					expect(x2 - x1).to.be.near(row.width, 0.5)
					expect(z1).to.be.near(0, 0.5)
					expect(z2 + W.CampDepth).to.be.near(row.length, 0.5)
					local along = z2
					-- spawn points: at least v3.2's, about 60% deep (or rare), spread to the far end
					local deep, farthest = 0, 0
					for _, point in spec.spawnPoints do
						local _, z = Layout.campLocal(camp, point.x, point.z)
						farthest = math.max(farthest, z)
						if point.zone ~= "near" then
							deep += 1
						end
					end
					local spots = #spec.spawnPoints
					if spots < row.spots then
						fail("%s has %d spawn points, fewer than v3.2's %d", id, spots, row.spots)
					end
					if deep / spots < 0.55 or deep / spots > 0.67 then
						fail("%s has %d of %d spawn points deep, not about 60%%", id, deep, spots)
					end
					if farthest < 0.9 * along then
						fail(
							"%s's farthest spawn point is %.0f of %.0f studs in",
							id,
							farthest,
							along
						)
					end
					-- traps: v3.2's count, three quarters in the far half, none within 100 studs of the camp
					expect(#spec.rescueSpots).to.equal(row.traps)
					local far = 0
					for i, spot in spec.rescueSpots do
						local _, z = Layout.campLocal(camp, spot.x, spot.z)
						if z <= 100 then
							fail("%s trap %d (%s) is %.1f studs from the camp", id, i, spot.trap, z)
						end
						if z > along / 2 then
							far += 1
						end
					end
					if far < 0.75 * row.traps then
						fail("%s has %d of %d traps in its far half", id, far, row.traps)
					end
				end
				-- the Park, the Neighbourhood and the Woods since #816, #817 and #858
				expect(long >= 3).to.equal(true)
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
	local AO, AS, AN = W.AlleyOuterX, W.AlleySouthZ, W.AlleyNorthZ

	describe("the Alleyway in the wild (world-and-feel section 2, F35; v4, F84)", function()
		it(
			"34 spawn points: 16 on the lanes, 4 nooks at the far end, 6 in the middle and 8 near points by the camp (#3170)",
			function()
				local zones: { [string]: number } = {}
				for _, point in alley.spawnPoints do
					expect(point.zone).to.be.ok()
					local zone = point.zone :: string
					zones[zone] = (zones[zone] or 0) + 1
				end
				expect(#alley.spawnPoints).to.equal(34)
				expect(zones.lane).to.equal(2 * W.PlotCount)
				expect(zones.nook).to.equal(4)
				expect(zones.mid).to.equal(6)
				expect(zones.near).to.equal(W.PlotCount)
			end
		)

		it(
			"every point lies on the one floor, the nooks at the far end 10 studs from every lane point",
			function()
				local sides: { [string]: number } = {}
				for i, point in alley.spawnPoints do
					if not onFloor(point.x, point.z, alleyRects, 0) then
						fail(
							"%s point %d at (%g, %g) is off the floor",
							tostring(point.zone),
							i,
							point.x,
							point.z
						)
					end
					if point.zone ~= "nook" then
						continue
					end
					-- 6 to 6.5 from the south end wall, so 2 or more inside the roam rect's 4 stud margin
					local x, z = toLane(point.x, point.z)
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
				expect(sides.w).to.equal(2)
				expect(sides.e).to.equal(2)
			end
		)

		it(
			"the middle stretch has its own points, clear of the lanes' points and every rescue spot (#3170)",
			function()
				for i, point in alley.spawnPoints do
					if point.zone ~= "mid" then
						continue
					end
					local _, z = toLane(point.x, point.z)
					if z < -50 or z > 15 then
						fail("mid point %d at lane z %g is not in the middle stretch", i, z)
					end
					for j, other in alley.spawnPoints do
						local apart = math.sqrt((point.x - other.x) ^ 2 + (point.z - other.z) ^ 2)
						if j ~= i and apart < 8 then
							fail("mid point %d is %.1f studs from point %d", i, apart, j)
						end
					end
					for _, spot in alley.rescuePool or alley.rescueSpots do
						local apart = math.sqrt((point.x - spot.x) ^ 2 + (point.z - spot.z) ^ 2)
						if apart < 9 then
							fail("mid point %d is %.1f studs from a rescue spot", i, apart)
						end
					end
				end
			end
		)

		it(
			"plot p owns near point p, just past the camp's way in, 5 then 15 either side of the middle (F85)",
			function()
				local near: { Point } = {}
				for _, point in alley.spawnPoints do
					if point.zone == "near" then
						table.insert(near, point)
					end
				end
				expect(#near).to.equal(8)
				for p, point in near do
					local across = math.abs(point.x - W.AlleyCenterX)
					expect(across).to.be.near(if p <= 4 then 5 else 15, 1e-9)
					expect(across < W.AlleyWayHalfWidth).to.equal(true) -- in front of the way in
					local into = W.AlleyCenterZ + AN - point.z
					expect(into == 10 or into == 16).to.equal(true)
				end
				-- g + 10u + 5r first: facing into the Alleyway (-Z) the right hand is +X
				expect(near[1].x - W.AlleyCenterX).to.be.near(5, 1e-9)
				expect(W.AlleyCenterZ + AN - near[1].z).to.be.near(10, 1e-9)
				-- and 4 or more from every lane point
				for p, point in near do
					for j, lane in alley.spawnPoints do
						local apart = math.sqrt((point.x - lane.x) ^ 2 + (point.z - lane.z) ^ 2)
						if lane.zone == "lane" and apart < 4 then
							fail("near point %d is %.1f studs from lane point %d", p, apart, j)
						end
					end
				end
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
			"walls along both outer sides and the far end, open in the middle and into the camp (F85)",
			function()
				local half = W.AlleyOuterX - W.AlleyLaneShift
				for _, side in { -1, 1 } do
					for z = AS + 1, AN - 1, 1 do
						local wx, wz = fromLane(side * (AO + 0.5), z)
						if not inWall(wx, wz, alleyWalls, 0) then
							fail("no outer wall at lane (%g, %g)", side * (AO + 0.5), z)
						end
					end
				end
				for x = -half + 1, half - 1, 2 do
					local wx = W.AlleyCenterX + x
					if not inWall(wx, W.AlleyCenterZ + AS - 0.5, alleyWalls, 0) then
						fail("no end wall at %g across", x)
					end
					-- one lane: no wall anywhere across it, and none on the camp line
					for z = AS + 1, AN + 0.5, 2 do
						if inWall(wx, W.AlleyCenterZ + z, alleyWalls, 0) then
							fail("a wall at (%g, %g) across the Alleyway", x, z)
						end
					end
				end
			end
		)

		it(
			"lays the camp across the north end, its Index Board beside the one way in (F85)",
			function()
				local camp = Layout.camps.alley
				expect(camp.turn).to.equal(180)
				expect(camp.openingHalfWidth).to.equal(W.AlleyWayHalfWidth)
				expect(camp.rect.x1).to.be.near(W.AlleyCenterX - (AO - W.AlleyLaneShift), 1e-9)
				expect(camp.rect.x2).to.be.near(W.AlleyCenterX + (AO - W.AlleyLaneShift), 1e-9)
				expect(camp.rect.z1).to.be.near(W.AlleyCenterZ + AN, 1e-9)
				expect(camp.rect.z2).to.be.near(W.AlleyCenterZ + AN + W.CampDepth, 1e-9)
				local board = Layout.indexBoards.alley
				local bx, bz = Layout.campPoint(camp, board.x, board.z)
				expect(inside(bx, bz, camp.rect, 0)).to.equal(true)
				expect(math.abs(bx - W.AlleyCenterX) > W.AlleyWayHalfWidth).to.equal(true)
				-- one arch over the way in, as wide as it
				local arches = alley.arches :: { Layout.Arch }
				expect(#arches).to.equal(1)
				expect(arches[1].x).to.equal(W.AlleyCenterX)
				expect(arches[1].span).to.equal(2 * W.AlleyWayHalfWidth)
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

	describe("the cat beds (F79; #2047, a bed for each extra slot)", function()
		it("stands the tier's beds, one more per extra slot, none on the empty plot", function()
			expect(Layout.bedsOpen(0, 2)).to.equal(0)
			expect(Layout.bedsOpen(1, 0)).to.equal(0)
			expect(Layout.bedsOpen(2, 2)).to.equal(2)
			expect(Layout.bedsOpen(3, 0)).to.equal(2)
			expect(Layout.bedsOpen(3, 2)).to.equal(4)
			expect(Layout.bedsOpen(4, 1)).to.equal(5)
			expect(Layout.bedsOpen(4, 2)).to.equal(6)
			expect(Layout.bedsOpen(5, 0)).to.equal(6)
			expect(Layout.bedsOpen(5, 1)).to.equal(7)
			expect(Layout.bedsOpen(5, 2)).to.equal(8) -- the 12 cats of Tier 5 with both pass-only waiters
			expect(Layout.bedsOpen(5, 3)).to.equal(9)
			-- #2651: Tier 6's 12 and Tier 7's 14, two more each with the pass
			expect(Layout.bedsOpen(6, 0)).to.equal(8)
			expect(Layout.bedsOpen(6, 2)).to.equal(10)
			expect(Layout.bedsOpen(7, 0)).to.equal(10)
			expect(Layout.bedsOpen(7, 2)).to.equal(12)
			expect(Layout.bedsOpen(7, 3)).to.equal(#Layout.plot.beds)
		end)

		it("keeps the beds in tier order, so the first ones are the tier's", function()
			for index = 2, #Layout.plot.beds do
				expect(Layout.plot.beds[index].tier >= Layout.plot.beds[index - 1].tier).to.equal(
					true
				)
			end
		end)
	end)

	describe("the bait bowl on the back step (v0.5 F44, data-model section 8)", function()
		local plot = Layout.plot
		local halfD = W.PlotDepth / 2

		it(
			"the bowl and its cat sit in the yard just outside the back wall, facing the Alleyway",
			function()
				for _, point in { plot.baitBowl, plot.baitCat, plot.baitBowl2, plot.baitCat2 } do
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
			for _, point in { plot.baitBowl, plot.baitCat, plot.baitBowl2, plot.baitCat2 } do
				expect(point.x > pathX2 + 1 or point.x < pathX1 - 1).to.equal(true)
			end
		end)

		-- #1161: the Second Bait Bowl and its cat follow the same two rules
		local bowlPairs = {
			{ bowl = plot.baitBowl, cat = plot.baitCat },
			{ bowl = plot.baitBowl2, cat = plot.baitCat2 },
		}

		it("the cat stands beside the bowl with its head over it", function()
			for _, pair in bowlPairs do
				local dx = pair.cat.x - pair.bowl.x
				local dz = pair.cat.z - pair.bowl.z
				expect(math.sqrt(dx * dx + dz * dz)).to.be.near(1.6, 0.01)
			end
		end)

		it("the cat is turned to face the bowl (QA)", function()
			-- WorldBuilder turns a point by CFrame.Angles(0, rad(rotY), 0), whose LookVector is (-sin, 0, -cos).
			for _, pair in bowlPairs do
				local yaw = math.rad(pair.cat.rotY or 0)
				local dx = pair.bowl.x - pair.cat.x
				local dz = pair.bowl.z - pair.cat.z
				local length = math.sqrt(dx * dx + dz * dz)
				expect((-math.sin(yaw) * dx - math.cos(yaw) * dz) / length > 0.95).to.equal(true)
			end
		end)

		it(
			"puts the second bowl past the first cat, 2 studs clear, so the pairs never touch (#1161)",
			function()
				expect(plot.baitBowl2.z).to.equal(plot.baitBowl.z)
				expect(plot.baitBowl2.x - plot.baitCat.x >= 2).to.equal(true)
			end
		)

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

	describe("the front lawn (F91, front-lawn.md section 1b)", function()
		local plot = Layout.plot
		-- a footprint's half extents: small pieces keep to 2 x 2, big ones to 4 wide by 3.1 deep under the windows
		local function half(size: string): (number, number)
			return if size == "big" then 2 else 1, if size == "big" then 1.55 else 1
		end
		local path = plot.lawnPath
		local line = plot.fenceLine

		it("keeps every spot in the garden, inside the fence and off the path", function()
			expect(#plot.lawnSpots).to.equal(6)
			for _, spot in plot.lawnSpots do
				local hx, hz = half(spot.size)
				local garden = plot.frontGarden
				expect(spot.x - hx >= garden.x1 and spot.x + hx <= garden.x2).to.equal(true)
				expect(spot.z - hz > line.z and spot.z + hz <= garden.z2).to.equal(true)
				-- the path style is 7 wide (x -3.5 to 3.5); the fence's gap is x -3.9 to 3.9
				expect(math.abs(spot.x) - hx >= line.gapHalfWidth).to.equal(true)
				expect(math.abs(spot.x) + hx <= line.halfWidth).to.equal(true)
			end
		end)

		it("keeps the spots apart and clear of the Lucky Cat's plinth", function()
			local cat = plot.luckyCat
			for i, a in plot.lawnSpots do
				local ax, az = half(a.size)
				local clearX = math.abs(a.x - cat.x) >= ax + 0.9
				local clearZ = math.abs(a.z - cat.z) >= az + 0.9
				expect(clearX or clearZ).to.equal(true)
				for j, b in plot.lawnSpots do
					if j > i then
						local bx, bz = half(b.size)
						local apart = math.abs(a.x - b.x) >= ax + bx
							or math.abs(a.z - b.z) >= az + bz
						expect(apart).to.equal(true)
					end
				end
			end
		end)

		it(
			"lays the path over the shell's own and runs the fence along the sidewalk edge",
			function()
				expect(path.x).to.equal(0)
				expect(path.y).to.equal(0)
				expect(path.z).to.be.near((plot.frontPath.z1 + plot.frontPath.z2) / 2, 1e-9)
				expect(line.z).to.be.near(-22.85, 1e-9)
				expect(line.z > plot.frontGarden.z1 and line.z < plot.frontGarden.z1 + 0.5).to.equal(
					true
				)
			end
		)
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

	-- The camp's way out (F85: one, in the middle), a stud and a half inside the north end, in world space.
	local function waysOut(): { { x: number, z: number } }
		return { { x = W.AlleyCenterX, z = W.AlleyCenterZ + W.AlleyNorthZ - 1.5 } }
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
					local across = math.abs(point.x - W.AlleyCenterX)
					local walk = math.max(0, across - W.AlleyWayHalfWidth) + (line - point.z)
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
			"reaches every spawn point from the camp's way out, the whole lane open since the block went (v4, F85)",
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
			expect(#nookPoints).to.equal(4) -- #3170: was 8
			if worst >= 25 then
				fail("nook point %d is %.1f s from the camp at carry speed", worstPoint, worst)
			end
			-- the Alleyway is 251 studs long; a much shorter walk means the grid broke
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
					-- every way out is the middle of the gate line, the Alleyway's one way in too since F85 (N338)
					local wayOut = 0
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

		it("puts the net away on the square only (Derek 2026-11-03)", function()
			local floor = square.floor
			expect(Layout.inTownSquare(0, 0)).to.equal(true)
			expect(Layout.inTownSquare(floor.x1, floor.z2)).to.equal(true)
			expect(Layout.inTownSquare(floor.x2 + 0.5, 0)).to.equal(false)
			expect(Layout.inTownSquare(0, floor.z1 - 0.5)).to.equal(false)
			for index = 1, W.PlotCount do
				local placement = Layout.plotPlacement(index)
				expect(Layout.inTownSquare(placement.x, placement.z)).to.equal(false)
			end
			for _, spec in Layout.areas do
				expect(Layout.inTownSquare(spec.center.x, spec.center.z)).to.equal(false)
			end
		end)

		it("puts plots 1 to 4 by the square and 5 to 8 one row out, west then east", function()
			-- the bigger cafes (44 x 34, #917)
			local want = { { -41, -100 }, { 41, -100 }, { -41, 100 }, { 41, 100 } } -- #3070: 85 before the 120 x 140 square
			for n = 1, 4 do
				want[n + 4] = { want[n][1], want[n][2] + (if want[n][2] < 0 then -52 else 52) }
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
			"fits the Codes Cat, Juniper's cart and the Day Cart in the south-west corner, facing the cannon (#2565)",
			function()
				local corner: { [string]: Point } = {
					codesCat = Layout.codesCat,
					mysteryCart = Layout.mysteryCart,
					dayCart = Layout.dayCart,
				}
				for name, point in corner do
					if not (point.x < 0 and point.z < 0) then
						fail("%s at (%g, %g) left the south-west quarter", name, point.x, point.z)
					end
					expect(inside(point.x, point.z, square.floor, 4)).to.equal(true)
					local yaw = math.rad(point.rotY or 0)
					local lookX, lookZ = -math.sin(yaw), -math.cos(yaw)
					local length = math.sqrt(point.x * point.x + point.z * point.z)
					expect((lookX * -point.x + lookZ * -point.z) / length > 0.999).to.equal(true)
				end
				-- Model-Agent's check used the real footprints; centres at least 12 studs apart keep the wagon
				-- (12 x 7) off its neighbours
				local function apart(a: Point, b: Point): number
					return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
				end
				expect(apart(Layout.mysteryCart, Layout.codesCat) > 12).to.equal(true)
				expect(apart(Layout.mysteryCart, Layout.dayCart) > 12).to.equal(true)
				expect(apart(Layout.codesCat, Layout.dayCart) > 12).to.equal(true)
			end
		)

		it(
			"keeps every station off the square's props and the other stations (QA 2026-11-09, #2565)",
			function()
				-- QA found the Mystery cart's stopgap spot 2 studs from the Rally board, which no station check
				-- covered: centres stay 8 studs from another station and 6.5 from any prop
				local all: { [string]: Point } = {
					spinWheel = Layout.spinWheel,
					fishMarket = Layout.fishMarket,
					codesCat = Layout.codesCat,
					dealerCart = Layout.dealerCart,
					bellhopStand = Layout.bellhopStand,
					mysteryCart = Layout.mysteryCart,
					leaderboards = Layout.leaderboards,
					cornerShop = Layout.cornerShop,
					dayCart = Layout.dayCart,
					thanksBoard = Layout.thanksBoard,
				}
				local props: { any } = { Layout.townSquare.pitySign, Layout.playerSpawn }
				for _, prop in Layout.townSquare.rallyBoards do
					table.insert(props, prop)
				end
				for _, prop in Layout.townSquare.props do
					if prop.asset ~= "CatCafe_Square_Paving" then
						table.insert(props, prop)
					end
				end
				for name, point in all do
					for other, there in all do
						local gap = math.sqrt((point.x - there.x) ^ 2 + (point.z - there.z) ^ 2)
						if other ~= name and gap < 8 then
							fail("%s stands %.1f studs from %s", name, gap, other)
						end
					end
					for _, prop in props do
						local gap = math.sqrt((point.x - prop.x) ^ 2 + (point.z - prop.z) ^ 2)
						if gap < 6.5 then
							fail(
								"%s stands %.1f studs from %s at (%g, %g)",
								name,
								gap,
								prop.asset or "the spawn",
								prop.x,
								prop.z
							)
						end
					end
				end
			end
		)

		it(
			"keeps the Codes circle clear of the cross and of the Spin Wheel's prompt (QA check 2)",
			function()
				local codes = Layout.codesCat
				local yaw = math.rad(codes.rotY or 0)
				local ahead = 2 + Config.CodesCircleRadius -- #3112: the circle's centre, 8 out at radius 6
				local cx, cz = codes.x - ahead * math.sin(yaw), codes.z - ahead * math.cos(yaw)
				for _, lane in lanes do
					expect(inside(cx, cz, lane, -Config.CodesCircleRadius)).to.equal(false)
				end
				local wheel = Layout.spinWheel
				local gap = math.sqrt((cx - wheel.x) ^ 2 + (cz - wheel.z) ^ 2)
				expect(gap > Config.SpinStationRange + Config.CodesCircleRadius).to.equal(true)
			end
		)

		it("is 120 by 140: #3001's width, and 15 deeper either side (#3070)", function()
			expect(W.TownSquareHalfWidth).to.equal(60)
			expect(W.TownSquareHalfDepth).to.equal(70)
			expect(square.floor.x2 - square.floor.x1).to.equal(120)
			expect(square.floor.z2 - square.floor.z1).to.equal(140)
			-- the width grows inside the town edge: the gardens keep a strip either side
			expect(W.TownEdgeX - W.TownSquareHalfWidth >= 9).to.equal(true)
			-- the streets and the town ground follow the deeper square, so the outer cafe row keeps its margin
			expect(W.StreetNorthZ).to.equal(178)
			expect(W.StreetSouthZ).to.equal(-178)
			expect(W.TownGroundDepth).to.equal(408)
		end)

		it("brings the Thank You board and the Rally board out into the open (#3070)", function()
			-- seen from the spawn, the line to the Thanks board's middle passes the night cart's middle by half the
			-- cart's length (12) or more; it passed 3.8 away on #3001's square, the board behind the cart
			local spawn = Layout.playerSpawn
			local board, cart = Layout.thanksBoard, Layout.dealerCart
			local dx, dz = board.x - spawn.x, board.z - spawn.z
			local long = math.sqrt(dx * dx + dz * dz)
			local off = math.abs((cart.x - spawn.x) * dz - (cart.z - spawn.z) * dx) / long
			expect(off >= 6).to.equal(true)
			-- the spawn's line to the Rally board's middle passes the cannon's 7 wide turret by 1.5 or more (the plinth
			-- is low); it passed 4.6 from the middle on #3001's square
			local rally = square.rallyBoards[1]
			local t = (0 - spawn.z) / (rally.z - spawn.z) -- where the spawn's line to the board crosses z = 0
			local crossX = spawn.x + t * (rally.x - spawn.x)
			expect(math.abs(crossX) >= 3.5 + 1.5).to.equal(true)
		end)

		it(
			"keeps a spot each for the feedback stand and the arcade cabinet (#3070), the stand right of the Thanks board (#3189)",
			function()
				local stand, arcade = Layout.feedbackStand, Layout.arcadeCabinet
				-- #3189: facing the Thanks board from the cannon's side, the stand is on its right, south of the lane,
				-- and well away from the Golden Fish Market
				local board = Layout.thanksBoard
				local long = math.sqrt(board.x ^ 2 + board.z ^ 2)
				local rightX, rightZ = -board.z / long, board.x / long
				expect((stand.x - board.x) * rightX + (stand.z - board.z) * rightZ > 6).to.equal(
					true
				)
				expect(stand.z < 0).to.equal(true)
				local fish = Layout.fishMarket
				expect(math.sqrt((stand.x - fish.x) ^ 2 + (stand.z - fish.z) ^ 2) > 40).to.equal(
					true
				)
				for _, spot in { stand, arcade } do
					expect(inside(spot.x, spot.z, square.floor, 4)).to.equal(true)
					for _, lane in lanes do
						expect(inside(spot.x, spot.z, lane, -4)).to.equal(false)
					end
					-- 12 or more from every other station's spot, so two prompts never show at once
					for _, other in
						{
							Layout.spinWheel,
							Layout.fishMarket,
							Layout.codesCat,
							Layout.dealerCart,
							Layout.bellhopStand,
							Layout.mysteryCart,
							Layout.leaderboards,
							Layout.dayCart,
							Layout.thanksBoard,
						}
					do
						local gap = math.sqrt((spot.x - other.x) ^ 2 + (spot.z - other.z) ^ 2)
						expect(gap >= 12).to.equal(true)
					end
					-- and it faces the cannon
					local yaw = math.rad(spot.rotY or 0)
					local toCannon = -spot.x * -math.sin(yaw) + -spot.z * -math.cos(yaw)
					expect(toCannon > 0).to.equal(true)
				end
			end
		)

		it(
			"keeps the feedback stand's floor ring off the lanes, where nobody walks through it (#3066)",
			function()
				-- the ring touches the stand's front (the model is 3.8 deep), WalkUp.FRONT_RADIUS across each way
				local stand = Layout.feedbackStand
				local yaw = math.rad(stand.rotY or 0)
				local out = WalkUp.frontOffset(1.9, WalkUp.FRONT_RADIUS, FeedbackStand.RANGE)
				local x, z = stand.x - math.sin(yaw) * out, stand.z - math.cos(yaw) * out
				local reach = WalkUp.FRONT_RADIUS + 2 -- two studs of floor between the ring and a lane
				expect(inside(x, z, square.floor, WalkUp.FRONT_RADIUS)).to.equal(true)
				for _, lane in lanes do
					expect(inside(x, z, lane, -reach)).to.equal(false)
				end
				-- and clear of every other station's spot, so its window is the only one that opens there
				for _, other in
					{
						Layout.spinWheel,
						Layout.fishMarket,
						Layout.codesCat,
						Layout.dealerCart,
						Layout.mysteryCart,
						Layout.leaderboards,
						Layout.dayCart,
						Layout.arcadeCabinet,
					}
				do
					local gap = math.sqrt((x - other.x) ^ 2 + (z - other.z) ^ 2)
					expect(gap >= 12).to.equal(true)
				end
			end
		)

		it(
			"stands the Codes Cat back from the middle, between the Mystery Market and the Bellhop Cat (#3000)",
			function()
				local codes, cart, stand = Layout.codesCat, Layout.mysteryCart, Layout.bellhopStand
				-- back: at least 8 studs farther from the cannon than #2707's (-29, -16)
				local out = math.sqrt(codes.x ^ 2 + codes.z ^ 2)
				expect(out >= math.sqrt(29 ^ 2 + 16 ^ 2) + 8).to.equal(true)
				-- between: south of the Bellhop stand, north of the Mystery Market, on their side of the square
				expect(codes.z < stand.z and codes.z > cart.z).to.equal(true)
				expect(codes.x < -W.TownSquareLaneHalfWidth).to.equal(true)
				expect(inside(codes.x, codes.z, square.floor, 4.5)).to.equal(true)
				-- its circle (its edge 2 studs in front) keeps off the Mystery Market's ring: the box closes a stud
				-- past the circle, and the ring is WalkUp.FRONT_RADIUS round a point touching the cart's 3.5 front
				local yaw = math.rad(codes.rotY or 0)
				local ahead = 2 + Config.CodesCircleRadius
				local cx, cz = codes.x - ahead * math.sin(yaw), codes.z - ahead * math.cos(yaw)
				local cartYaw = math.rad(cart.rotY or 0)
				local ring = WalkUp.frontOffset(3.5, WalkUp.FRONT_RADIUS, Config.MysteryMarketRange)
				local rx, rz = cart.x - ring * math.sin(cartYaw), cart.z - ring * math.cos(cartYaw)
				local gap = math.sqrt((cx - rx) ^ 2 + (cz - rz) ^ 2)
				expect(gap >= Config.CodesCircleRadius + 1 + WalkUp.FRONT_RADIUS + 2).to.equal(true)
				-- and off both carts' bodies and the lane
				for _, lane in lanes do
					expect(inside(cx, cz, lane, -Config.CodesCircleRadius)).to.equal(false)
				end
				expect(
					math.sqrt((cx - cart.x) ^ 2 + (cz - cart.z) ^ 2) > Config.CodesCircleRadius + 6
				).to.equal(true)
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
				local ahead = 2 + Config.CodesCircleRadius -- #3112: the circle's centre, 8 out at radius 6
				local cx, cz =
					codes.x - ahead * math.sin(codesYaw), codes.z - ahead * math.cos(codesYaw)
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

		it(
			"stands the leaderboards at the lane's east end, facing the cannon, clear of the edge and the stations (F98)",
			function()
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
			end
		)

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

		-- F85 as one lane (Model-Agent #875, area-sets.md "The Alleyway as one lane"): four rows of low blockers right
		-- across, each one model at the middle, the way through never on the same side twice running (the middle, the
		-- west side, the east side, the middle), and the string lights wall to wall in the other gaps between
		-- buildings. Outside its way through each row (its own half depth, the Van's with its doors open) stays clear
		-- of the spawn points by a cat's half body and of the traps by 2.
		it(
			"crosses the one lane with four blocker rows, the way through moving about, lights between (F85)",
			function()
				type Row = { z: number, name: string }
				-- across from the middle: z, the way through from and to, the half depth
				local want: { [string]: { number } } = {
					RowCamp = { 88.025, -13, 13, 1.5 },
					RowVan = { 18.25, -45, -20.6, 5.7 },
					RowSkip = { -53.675, 21.6, 45, 2.7 },
					RowFar = { -88.025, -16.1, 13, 2.7 },
				}
				local prefix = "CatCafe_Alley_Blocker_"
				local rows: { Row } = {}
				local lights: { number } = {}
				for _, prop in alley.props :: { Layout.Prop } do
					if prop.asset == "CatCafe_Alley_StringLightsWide" then
						expect(prop.x).to.equal(W.AlleyCenterX)
						table.insert(lights, prop.z - W.AlleyCenterZ)
					end
					expect(prop.asset).never.to.equal("CatCafe_Alley_StringLightsLong")
					if prop.asset:sub(1, #prefix) ~= prefix then
						continue
					end
					local name = prop.asset:sub(#prefix + 1)
					local row = want[name]
					if row == nil then
						fail("%s is not one of the one-lane rows", prop.asset)
					end
					expect(prop.x).to.equal(W.AlleyCenterX)
					expect(prop.z - W.AlleyCenterZ).to.be.near(row[1], 1e-9)
					expect(prop.rotY or 0).to.equal(0)
					table.insert(rows, { z = row[1], name = name })
				end
				expect(#rows).to.equal(4)
				table.sort(rows, function(a: Row, b: Row): boolean
					return a.z > b.z
				end)
				local function way(name: string): number
					local middle = (want[name][2] + want[name][3]) / 2
					return if math.abs(middle) < 10 then 0 else math.sign(middle)
				end
				for i = 2, #rows do
					if way(rows[i].name) == way(rows[i - 1].name) then
						fail("%s and %s leave the same way through", rows[i - 1].name, rows[i].name)
					end
				end
				for _, row in rows do
					local w = want[row.name]
					local function clear(x: number, z: number, margin: number): boolean
						local ax, az = x - W.AlleyCenterX, z - W.AlleyCenterZ
						return math.abs(az - w[1]) > w[4] + margin
							or (ax > w[2] + margin and ax < w[3] - margin)
					end
					for i, point in alley.spawnPoints do
						if not clear(point.x, point.z, 0.8) then
							fail(
								"spawn point %d at (%g, %g) is in %s",
								i,
								point.x,
								point.z,
								row.name
							)
						end
					end
					for i, spot in alley.rescueSpots do
						if not clear(spot.x, spot.z, 2) then
							fail("rescue spot %d at (%g, %g) is by %s", i, spot.x, spot.z, row.name)
						end
					end
				end
				-- the lights hang in the two gaps between buildings that have no row
				expect(#lights).to.equal(2)
				for _, z in lights do
					for _, row in rows do
						expect(math.abs(z - row.z) > 10).to.equal(true)
					end
				end
			end
		)

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
				expect(ends).to.equal(3) -- across the south end (F85); the north end opens into the camp
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
					desert = { 1, -1 }, -- #2651: the free diagonals (tier6-7-areas.md section 2)
					ruins = { 1, 1 },
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
					woods = { W.WoodsCenterX + W.WoodsDepth / 2, 0, -90 }, -- F85: its depth along X
					sewer = { W.SewerCenterX - W.SewerDepth / 2, 0, 90 }, -- F85: its depth along X too
					desert = { W.DesertCenterX, W.DesertCenterZ + W.DesertDepth / 2, 180 }, -- #2651: its north end
					ruins = { W.RuinsCenterX, W.RuinsCenterZ - W.RuinsDepth / 2, 0 }, -- #2651: its south end
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

		it("turns the town cannon toward each area's landing pad (#2651)", function()
			local aims: { number } = {}
			for id, camp in Layout.camps do
				local aim = math.rad(Layout.cannonAim(id))
				local pad = camp.pad
				local out = math.sqrt(pad.x ^ 2 + pad.z ^ 2)
				-- the barrel rests along +Z; turned by aim it points along (sin, cos)
				local dot = (math.sin(aim) * pad.x + math.cos(aim) * pad.z) / out
				expect(dot).to.be.near(1, 1e-9)
				table.insert(aims, Layout.cannonAim(id))
			end
			expect(#aims).to.equal(7)
			-- every destination at least 35 degrees from every other, so the barrel visibly turns (section 2 says about 38;
			-- the Ruins pad sits 37.8 from the Sewer)
			for i, a in aims do
				for j, b in aims do
					local apart = math.abs((a - b + 180) % 360 - 180)
					if i ~= j and apart < 35 then
						fail("two cannon aims only %.1f degrees apart", apart)
					end
				end
			end
			expect(Layout.cannonAim("park")).to.be.near(180, 1e-9)
			expect(Layout.cannonAim("neighbourhood")).to.be.near(0, 1e-9)
			expect(Layout.cannonAim("woods")).to.be.near(-90, 1e-9)
			expect(Layout.cannonAim("sewer")).to.be.near(90, 1e-9)
			expect(Layout.cannonAim("town")).to.equal(0)
		end)

		it(
			"catches a fall into the Ruins' mist and nothing above it or in another area (#2651)",
			function()
				local ruins = Layout.areas.ruins
				local c = ruins.center
				expect(ruins.catchBelow).to.equal(20)
				-- on the plateau, a jump, and just above the band: not caught
				expect(Layout.fallCaught(ruins, c.x, ruins.floorY, c.z)).to.equal(false)
				expect(Layout.fallCaught(ruins, c.x, ruins.floorY + 8, c.z)).to.equal(false)
				expect(Layout.fallCaught(ruins, c.x, ruins.floorY - 19.9, c.z)).to.equal(false)
				-- off a long side's cliff, in the band and far below it
				local side = c.x + ruins.halfWidth + 10
				expect(Layout.fallCaught(ruins, side, ruins.floorY - 21, c.z)).to.equal(true)
				expect(Layout.fallCaught(ruins, side, ruins.floorY - 200, c.z)).to.equal(true)
				-- past the margin is someone else's problem (Roblox's own fall floor)
				local far = c.x + ruins.halfWidth + (ruins.catchMargin :: number) + 1
				expect(Layout.fallCaught(ruins, far, ruins.floorY - 30, c.z)).to.equal(false)
				-- no other area has a catch
				for id, spec in Layout.areas do
					if id ~= "ruins" then
						expect(spec.catchBelow).to.equal(nil)
						expect(
							Layout.fallCaught(spec, spec.center.x, spec.floorY - 100, spec.center.z)
						).to.equal(false)
					end
				end
			end
		)

		it(
			"lays out the Desert and the Ruins on the east diagonals from their sets' spots (#2651)",
			function()
				local want: { [string]: { aim: number, near: number, deep: number, gateNorth: boolean } } =
					{
						desert = { aim = 128.3, near = 50, deep = 56, gateNorth = true },
						ruins = { aim = 52.2, near = 55, deep = 45, gateNorth = false },
					}
				for id, w in want do
					local spec = Layout.areas[id]
					expect(spec).to.be.ok()
					expect(Layout.camps[id]).to.be.ok()
					expect(#spec.spawnPoints).to.equal((Catalog.getArea(id) :: any).spawnPoints)
					expect(#(spec.rescuePool :: { any })).to.equal(15)
					expect(spec.center.x > 0).to.equal(true)
					-- long along world Z, the camp on the town end
					expect(spec.halfDepth > spec.halfWidth).to.equal(true)
					expect((spec.gateZ :: number) > spec.center.z).to.equal(w.gateNorth)
					expect(math.abs(spec.gateZ :: number) < math.abs(spec.center.z)).to.equal(true)
					expect(Layout.cannonAim(id)).to.be.near(w.aim, 1)
					-- the pad is about 1790 to 1800 out, a little short of the Alleyway's 1900 (section 2, check 2)
					local pad = Layout.camps[id].pad
					local out = math.sqrt(pad.x ^ 2 + pad.z ^ 2)
					expect(out > 1700 and out < 1900).to.equal(true)
					local counts: { [string]: number } = {}
					for _, point in spec.spawnPoints do
						counts[point.zone :: string] = (counts[point.zone :: string] or 0) + 1
						expect(math.abs(point.x - spec.center.x) < spec.halfWidth).to.equal(true)
						expect(math.abs(point.z - spec.center.z) < spec.halfDepth).to.equal(true)
					end
					expect(counts.near).to.equal(w.near)
					expect(counts.deep).to.equal(w.deep)
					expect(#spec.rescueSpots).to.equal(5)
					for _, trap in spec.rescueSpots do
						expect(math.abs(trap.x - spec.center.x) < spec.halfWidth).to.equal(true)
						expect(math.abs(trap.z - spec.center.z) < spec.halfDepth).to.equal(true)
					end
					-- clear of every other area by more than 500 studs
					for other, there in Layout.areas do
						if other == id then
							continue
						end
						local dx = math.max(
							0,
							math.abs(spec.center.x - there.center.x)
								- spec.halfWidth
								- there.halfWidth
						)
						local dz = math.max(
							0,
							math.abs(spec.center.z - there.center.z)
								- spec.halfDepth
								- there.halfDepth
						)
						if math.sqrt(dx * dx + dz * dz) < 500 then
							fail("the %s is too close to the %s", id, other)
						end
					end
				end
			end
		)

		it(
			"stands one Rally board left of the street's path at its north end, facing the spawn, off the cross and the stations (F101, #2224, #2367)",
			function()
				local boards = square.rallyBoards
				expect(#boards).to.equal(1)
				for _, board in boards do
					expect(board.asset).to.equal("CatCafe_Square_RallyBoard")
					expect(board.z > 0).to.equal(true)
					expect(board.x < 0).to.equal(true) -- the left side, off the Fish Market's (#2367)
					-- its face is about 11 by 1.5 (Model-Agent #759); every corner of that, turned, stays off the cross
					local yaw = math.rad(board.rotY or 0)
					local cos, sin = math.cos(yaw), math.sin(yaw)
					for _, corner in
						{ { -5.5, -0.75 }, { 5.5, -0.75 }, { -5.5, 0.75 }, { 5.5, 0.75 } }
					do
						local x = board.x + corner[1] * cos + corner[2] * sin
						local z = board.z - corner[1] * sin + corner[2] * cos
						expect(inside(x, z, square.floor, 4)).to.equal(true)
						for _, lane in lanes do
							expect(inside(x, z, lane, -0.5)).to.equal(false)
						end
						expect(math.sqrt(x ^ 2 + z ^ 2) > square.fountainRadius + 3).to.equal(true)
					end
					-- front -Z turned toward the spawn on the street's line
					local spawn = Layout.playerSpawn
					local toX, toZ = spawn.x - board.x, spawn.z - board.z
					local length = math.sqrt(toX ^ 2 + toZ ^ 2)
					expect((-sin * toX - cos * toZ) / length > 0.95).to.equal(true)
					for name, point in
						{
							spinWheel = Layout.spinWheel,
							fishMarket = Layout.fishMarket,
							codesCat = Layout.codesCat,
							dealerCart = Layout.dealerCart,
							bellhopStand = Layout.bellhopStand,
							leaderboards = Layout.leaderboards,
						} :: { [string]: Point }
					do
						if math.sqrt((point.x - board.x) ^ 2 + (point.z - board.z) ^ 2) < 13 then
							fail("a Rally board stands on the %s", name)
						end
					end
				end
			end
		)

		it(
			"keeps the Rally boards out of the line from the spawn and the cannon to the Fish Market (#2224)",
			function()
				-- seen from each spot, a board (12.2 wide) and the market (about 12 wide) take up an arc each; they must
				-- not overlap, so nothing hides the market from where players stand
				local market = Layout.fishMarket
				for _, eye in { Layout.playerSpawn, { x = 0, y = 0, z = 0 } :: Point } do
					local function arc(x: number, z: number, half: number): (number, number)
						local dx, dz = x - eye.x, z - eye.z
						return math.atan2(dx, dz), math.atan(half / math.sqrt(dx * dx + dz * dz))
					end
					local m, mHalf = arc(market.x, market.z, 6.4)
					for _, board in square.rallyBoards do
						local a, aHalf = arc(board.x, board.z, 6.1)
						if math.abs(a - m) <= aHalf + mHalf then
							fail(
								"the Rally board at (%g, %g) hides the Fish Market from (%g, %g)",
								board.x,
								board.z,
								eye.x,
								eye.z
							)
						end
					end
				end
			end
		)

		it(
			"stands the pity sign across from the Day Cart facing the spawn, off the lanes (#1753)",
			function()
				local sign = square.pitySign
				expect(sign.asset).to.equal("CatCafe_Square_PitySign")
				-- about 8.2 wide and 1.2 deep (the manifest); every corner of that, turned, stays on the square off the lanes
				local yaw = math.rad(sign.rotY or 0)
				local cos, sin = math.cos(yaw), math.sin(yaw)
				for _, corner in { { -4.1, -0.6 }, { 4.1, -0.6 }, { -4.1, 0.6 }, { 4.1, 0.6 } } do
					local x = sign.x + corner[1] * cos + corner[2] * sin
					local z = sign.z - corner[1] * sin + corner[2] * cos
					expect(inside(x, z, square.floor, 2)).to.equal(true)
					for _, lane in lanes do
						expect(inside(x, z, lane, -0.5)).to.equal(false)
					end
				end
				local spawn = Layout.playerSpawn
				local toX, toZ = spawn.x - sign.x, spawn.z - sign.z
				local length = math.sqrt(toX ^ 2 + toZ ^ 2)
				expect((-sin * toX - cos * toZ) / length > 0.99).to.equal(true)
				for name, point in
					{
						dayCart = Layout.dayCart,
						codesCat = Layout.codesCat,
						dealerCart = Layout.dealerCart,
					} :: { [string]: Point }
				do
					if math.sqrt((point.x - sign.x) ^ 2 + (point.z - sign.z) ^ 2) < 9 then
						fail("the pity sign stands on the %s", name)
					end
				end
			end
		)

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
				for _, role in { "waiter_1", "waiter_2", "waiter_3", "waiter_4", "waiter_5" } do
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

		it(
			"keeps the pass-only waiters (#1624) off the back door walk, the tables and the order queue",
			function()
				local ax, az = plot.backDoor.x, halfD
				local dx, dz = plot.door.x - ax, plot.door.z - az
				local length = math.sqrt(dx * dx + dz * dz)
				for _, id in { "waiter_4", "waiter_5" } do
					local spot = plot.spots[id]
					expect(spot).to.be.ok()
					-- a big seated cat reaches 0.78 from its point; a stud of room past that
					local off = math.abs((spot.x - ax) * dz - (spot.z - az) * dx) / length
					if off < 0.78 + 1 then
						fail("%s stands %.2f studs off the back door walk", id, off)
					end
					for i, other in plot.tables do
						if
							math.abs(spot.x - other.x) < REACH + 0.78
							and math.abs(spot.z - other.z) < DEPTH + 0.78
						then
							fail("%s stands on table %d", id, i)
						end
					end
					expect(math.abs(spot.x - plot.orderPoint.x) >= 3).to.equal(true)
					expect(math.abs(spot.x) < W.PlotWidth / 2 - 1 and math.abs(spot.z) < halfD - 1).to.equal(
						true
					)
				end
			end
		)

		it("puts the rich tip's coin pile on table 1, where the rich customer sits", function()
			expect(plot.richTip.x).to.equal(plot.tables[1].x)
			expect(plot.richTip.z).to.equal(plot.tables[1].z)
			expect(plot.richTip.y > 0).to.equal(true)
		end)
	end)

	describe("the greeters stand clear of the open front door (#1145)", function()
		local plot = Layout.plot
		local door = plot.door
		local jamb = W.DoorWidth / 2

		it("puts the two slots on opposite sides of the walkway, mirrored", function()
			local left, right = plot.spots.greeter_1, plot.spots.greeter_2
			expect(left.x < door.x and right.x > door.x).to.equal(true)
			expect(left.x - door.x).to.be.near(door.x - right.x, 1e-9)
			expect(left.z).to.equal(right.z)
		end)

		it("keeps them past the jambs, so the open leaves never reach them", function()
			for _, id in { "greeter_1", "greeter_2" } do
				local spot = plot.spots[id]
				-- a seated cat fills 0.75 either way; the leaf stands on its jamb
				expect(math.abs(spot.x - door.x) - 0.75 >= jamb + 0.5).to.equal(true)
			end
		end)

		it(
			"stands them a few studs inside the wall, off the decor beside the door (7 in since #1417)",
			function()
				for _, id in { "greeter_1", "greeter_2" } do
					local spot = plot.spots[id]
					local inside = spot.z - door.z
					expect(inside >= 3 and inside <= 8).to.equal(true)
					-- and short of the first row's lane, where customers walk out to the outer chairs (a big cat
					-- reaches 0.76 behind its point; 2 studs of walking room)
					expect(spot.z + 0.76 <= plot.tables[1].lane - 2).to.equal(true)
				end
			end
		)

		it("turns each to face the middle of the doorway", function()
			for _, id in { "greeter_1", "greeter_2" } do
				local spot = plot.spots[id]
				local turn = math.rad(spot.rotY or 0)
				-- a cat's front is -Z, turned about Y by rotY
				local frontX, frontZ = -math.sin(turn), -math.cos(turn)
				local toX, toZ = door.x - spot.x, door.z - spot.z
				local length = math.sqrt(toX * toX + toZ * toZ)
				expect(frontX * toX / length + frontZ * toZ / length).to.be.near(1, 1e-6)
			end
		end)

		it("follows the door's own point, not the plot centre", function()
			expect(plot.spots.greeter_1.z).to.equal(door.z + 7)
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
			"lines the square's edge with twelve benches, each turned square to face in (Derek 10-28, #726, #2565, #2707, #3070)",
			function()
				local benches = piecesOf("CatCafe_Square_Bench")
				expect(#benches).to.equal(12) -- #3070: one more each side under the middle span
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
						"CatCafe_Square_BuntingSide",
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
				-- #2707: the north and south sides keep the long Bunting; the east and west sides take two BuntingSide
				-- each between three lamps
				expect(#piecesOf("CatCafe_Square_Bunting")).to.equal(8) -- #3001: two a quarter on the longer sides
				expect(#piecesOf("CatCafe_Square_BuntingSide")).to.equal(12) -- #3070: three spans a quarter
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
			-- #2707: a halfway lamp on each east and west side; #3001: one on each north and south half too; #3070: a
			-- third span on each east and west quarter
			expect(#piecesOf("CatCafe_Square_Lamp")).to.equal(24)
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
			"adds two beds a tier from Tier 3 and two for the extra slots (#2047), so every working slot sleeps",
			function()
				expect(#plot.beds).to.equal(12) -- #2651: four more for Tier 7 and its extra slots
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

		it(
			"stands a nap bed on each nap spot inside the walls, facing into the room, clear of everything but its cat",
			function()
				expect(#plot.napSpots).to.equal(4)
				for n, spot in plot.napSpots do
					local bed = { x = spot.x, z = spot.z }
					local function check(what: string, x: number, z: number)
						if apart(bed, x, z) < CLEAR then
							fail("nap spot %d is %.2f studs from %s", n, apart(bed, x, z), what)
						end
					end
					expect(spot.y).to.equal(0)
					expect(math.abs(spot.x) <= halfW - 1.5 and math.abs(spot.z) <= halfD - 1.5).to.equal(
						true
					)
					local angle = math.rad(spot.rotY or 0)
					if -math.sin(angle) * -spot.x + -math.cos(angle) * -spot.z <= 0 then
						fail("nap spot %d faces the wall", n)
					end
					for k, decor in plot.decorSpots do
						check("decor spot " .. k, decor.x, decor.z)
					end
					for k, tableSpot in plot.tables do
						check("table " .. k, tableSpot.x, tableSpot.z)
					end
					for id, station in plot.spots do
						check(id, station.x, station.z)
					end
					for id, tree in plot.spotFurniture do
						check(id .. "'s cat tree", tree.x, tree.z)
					end
					for k, other in plot.napSpots do
						if k ~= n then
							check("nap spot " .. k, other.x, other.z)
						end
					end
					for _, f79 in plot.beds do
						check(f79.id, f79.x, f79.z)
					end
				end
			end
		)

		it(
			"stands the right side's nap beds on the wall line with the F79 beds, square to the wall (#1809)",
			function()
				-- Derek2 11-06: one of the two beds by the display case stood out toward the middle of the cafe
				local wall = plot.beds[4].x -- bed_4 and bed_6 sit on the right wall's line
				expect(plot.beds[6].x).to.equal(wall)
				for _, n in { 2, 3 } do
					local spot = plot.napSpots[n]
					expect(spot.x).to.equal(wall)
					expect(spot.rotY).to.equal(90)
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
		local counter = {
			plot.counter.x - 4.2,
			plot.counter.z - 1.33,
			plot.counter.x + 4.2,
			plot.counter.z + 1.3,
		}
		local oven = box(plot.oven.x, plot.oven.z, 3.2, 2.9)
		local till = { 0.7, plot.counter.z - 0.15, 1.7, plot.counter.z + 0.7 }
		local espresso = {
			plot.espresso.x - 1.23,
			plot.espresso.z - 1.15,
			plot.espresso.x + 1.23,
			plot.espresso.z + 0.5,
		}
		local function cat(spot: any): { number }
			return { spot.x - 0.75, spot.z - 0.78, spot.x + 0.75, spot.z + 0.76 }
		end

		it(
			"stands the oven on the floor against the back wall, clear of the counter and the back door",
			function()
				expect(plot.oven.y).to.equal(0)
				expect(oven[4] <= halfD - 0.25 and oven[4] >= halfD - 0.5).to.equal(true)
				expect(overlaps(oven, counter)).to.equal(false)
				local door = plot.backDoor
				expect(oven[1] > door.x + door.width / 2 or oven[3] < door.x - door.width / 2).to.equal(
					true
				)
				expect(oven[3] <= halfW - 1).to.equal(true)
			end
		)

		it(
			"keeps the oven and its open door clear of every cat spot, decor spot, nap spot and bed",
			function()
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
					local piece = if turned
						then box(spot.x, spot.z, 2.5, 4.2)
						else box(spot.x, spot.z, 4.2, 2.5)
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
			end
		)

		it(
			"puts the pass on the counter top, a plate clear of the till, the espresso machine and the tip jar",
			function()
				local plate = box(plot.pass.x, plot.pass.z, 1.1, 1.1)
				expect(plot.pass.y).to.equal(3)
				expect(plate[1] >= counter[1] and plate[3] <= counter[3]).to.equal(true)
				expect(plate[2] >= counter[2] - 0.05 and plate[4] <= counter[4]).to.equal(true)
				expect(overlaps(plate, till)).to.equal(false)
				expect(overlaps(plate, espresso)).to.equal(false)
				expect(overlaps(plate, box(0.2, plot.counter.z - 0.6, 0.4, 0.4))).to.equal(false) -- the tip jar
			end
		)

		it(
			"has the Waiter pick up in front of the counter, clear of the queue and the Cat Collector",
			function()
				expect(plot.pickup.y).to.equal(0)
				local body = cat(plot.pickup)
				expect(body[4] <= counter[2]).to.equal(true)
				expect(math.abs(plot.pickup.x) < 6.3 - 1).to.equal(true) -- in the aisle, off the tables
				expect(overlaps(body, box(plot.collectorSpot.x, plot.collectorSpot.z, 1.56, 1.99))).to.equal(
					false
				)
				-- behind the queue's line at the right edge of its spread, so a customer ordering there brushes it at most
				expect(plot.pickup.z - plot.orderPoint.z >= 0.8 and plot.pickup.x >= 2.5).to.equal(
					true
				)
			end
		)

		it("drops the swept coin bag on the till", function()
			local x, z = plot.tillStack.x, plot.tillStack.z
			expect(x > till[1] and x < till[3] and z > till[2] and z < till[4]).to.equal(true)
			expect(plot.tillStack.y > 3).to.equal(true)
		end)
	end)

	-- F100 (camp-extras.md section 3; Model-Agent #750): one extra in each camp from the Park on.
	describe("the camp extras (F100)", function()
		local function apart(ax: number, az: number, bx: number, bz: number): number
			return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
		end

		it("has a spot for each Catalog extra's area and none for the Alleyway", function()
			local count = 0
			for areaId in Layout.campExtras do
				count += 1
				local found = false
				for _, def in Catalog.campExtras do
					found = found or def.area == areaId
				end
				expect(found).to.equal(true)
			end
			expect(count).to.equal(#Catalog.campExtras)
			expect(Layout.campExtras.alley).never.to.be.ok()
			expect(Layout.campExtraAt("alley")).to.equal(nil)
		end)

		it(
			"stands each inside its camp beside the way out, clear of the board, the pad, the cannon and the basket",
			function()
				for _, def in Catalog.campExtras do
					local camp = Layout.camps[def.area]
					local x, y, z, turn = Layout.campExtraAt(def.area)
					assert(x ~= nil and y ~= nil and z ~= nil and turn ~= nil, def.id)
					-- in the camp, which is the safe zone, its 3 by 2.2 footprint 2 in from every edge
					if not inside(x, z, camp.rect, 2) then
						fail("%s at (%g, %g) is not inside its camp", def.id, x, z)
					end
					expect(Layout.campAt(x, z)).to.equal(def.area)
					expect(y).to.equal(Layout.areas[def.area].floorY)
					expect(turn).to.equal(camp.turn)
					-- beside the way out (not in front of it) and on the other side from the Index Board
					local lx, lz = Layout.campLocal(camp, x, z)
					expect(lx > camp.openingHalfWidth + 2).to.equal(true)
					expect(lz < -2 and lz > -12).to.equal(true)
					local board = Layout.indexBoards[def.area]
					expect(board.x < 0).to.equal(true)
					local bx, bz = Layout.campPoint(camp, board.x, board.z)
					expect(apart(x, z, bx, bz) > 2 * Config.CampExtraRangeStuds).to.equal(true)
					-- clear of the landing pad's spots, the cannon and its front, and the carrier basket
					local pad = Layout.landingPads[def.area].centre
					expect(apart(x, z, pad.x, pad.z) > W.LandingPadRadius + 3).to.equal(true)
					for _, point in
						{ Layout.cannons[def.area], Layout.cannonFronts[def.area], camp.basket }
					do
						expect(apart(x, z, point.x, point.z) > 6).to.equal(true)
					end
				end
			end
		)

		it(
			"stands the Rummage Bin in the Alleyway camp by the pad, 12 studs from every other prompt (#3050)",
			function()
				local RummageBin = require(game:GetService("ReplicatedStorage").Shared.RummageBin)
				local function far(ax: number, az: number, bx: number, bz: number): number
					return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
				end
				expect(Layout.rummageBin.area).to.equal(RummageBin.AREA)
				local camp = Layout.camps.alley
				local spec = Layout.areas.alley
				local x, y, z, turn = Layout.rummageBinAt()
				assert(x ~= nil and y ~= nil and z ~= nil and turn ~= nil, "no bin spot")
				expect(y).to.equal(spec.floorY)
				-- in the camp (the safe zone), its 3.3 stud pallet 2 in from every edge and behind the gate line
				if not inside(x, z, camp.rect, 2) then
					fail("the bin at (%g, %g) is not inside the Alleyway camp", x, z)
				end
				expect(Layout.campAt(x, z)).to.equal("alley")
				-- in plain view of the landing pad: within 15 studs, but past its landing spots
				local pad = Layout.landingPads.alley.centre
				local toPad = far(x, z, pad.x, pad.z)
				expect(toPad <= 15).to.equal(true)
				expect(toPad > W.LandingPadRadius + 3).to.equal(true)
				-- off the walk from the pad out through the arch
				local lx = Layout.campLocal(camp, x, z)
				expect(math.abs(lx) > 6).to.equal(true)
				-- its front (-Z) faces the pad: the pad lies within 15 degrees of where the bin looks
				local look = Vector3.new(-math.sin(math.rad(turn)), 0, -math.cos(math.rad(turn)))
				local toward = Vector3.new(pad.x - x, 0, pad.z - z).Unit
				expect(look:Dot(toward) > math.cos(math.rad(15))).to.equal(true)
				-- no other prompt within 12 studs, so prompts never stack on a phone: the cannon and its walk-up
				-- front, the carrier basket, the Index Board, every stray spawn and every trap spot of the Alleyway
				local board = Layout.indexBoards.alley
				local bx, bz = Layout.campPoint(camp, board.x, board.z)
				local others: { { x: number, z: number } } = {
					Layout.cannons.alley,
					Layout.cannonFronts.alley,
					camp.basket,
					{ x = bx, z = bz },
				}
				for _, point in spec.spawnPoints do
					table.insert(others, point)
				end
				for _, point in spec.rescueSpots do
					table.insert(others, point)
				end
				for _, point in spec.rescuePool or {} do
					table.insert(others, point)
				end
				expect(#others > 20).to.equal(true)
				-- the prompt hangs on the bin's front, up to 2.2 studs from its pivot
				for _, point in others do
					if far(x, z, point.x, point.z) < 12 + 2.2 then
						fail(
							"a prompt at (%g, %g) is %.1f studs from the bin",
							point.x,
							point.z,
							far(x, z, point.x, point.z)
						)
					end
				end
			end
		)

		it(
			"stands the Oasis Spa and the Relic Museum in their camps, clear of the board, pad and cannon (#2651)",
			function()
				local LateStations =
					require(game:GetService("ReplicatedStorage").Shared.LateStations)
				for _, def in LateStations.stations do
					local camp = Layout.camps[def.area]
					local x, y, z, turn = Layout.lateStationAt(def.area)
					assert(x ~= nil and y ~= nil and z ~= nil and turn ~= nil, def.id)
					if not inside(x, z, camp.rect, 2) then
						fail("%s at (%g, %g) is not inside its camp", def.id, x, z)
					end
					expect(Layout.campAt(x, z)).to.equal(def.area)
					expect(y).to.equal(Layout.areas[def.area].floorY)
					expect(turn).to.equal(camp.turn)
					-- #2789's art: the spa 22.8 by 12.2 (its model from -5.0 to +7.2 in its own Z, +Z toward the gate line),
					-- the museum 12.8 by 8.3 (centred). Its whole footprint stays inside the camp, off the way out (2 clear
					-- of the opening) and behind the gate line
					local size = if def.id == LateStations.SPA
						then Vector2.new(22.8, 12.2)
						else Vector2.new(12.8, 8.3)
					local front, back = size.Y / 2, size.Y / 2
					if def.id == LateStations.SPA then
						front, back = 5.0, 7.2
					end
					local lx, lz = Layout.campLocal(camp, x, z)
					expect(lx - size.X / 2 > camp.openingHalfWidth + 1).to.equal(true)
					expect(lx + size.X / 2 < camp.halfAcross - 2).to.equal(true)
					expect(lz + back < -0.5).to.equal(true)
					expect(lz - front > -W.CampDepth + 2).to.equal(true)
					local board = Layout.indexBoards[def.area]
					local bx, bz = Layout.campPoint(camp, board.x, board.z)
					expect(apart(x, z, bx, bz) > 2 * Config.CampExtraRangeStuds).to.equal(true)
					-- clear of the pad, the cannon and its front, and the basket by the footprint's half diagonal
					local reach = size.Magnitude / 2
					local pad = Layout.landingPads[def.area].centre
					expect(apart(x, z, pad.x, pad.z) > W.LandingPadRadius + reach).to.equal(true)
					for _, point in
						{ Layout.cannons[def.area], Layout.cannonFronts[def.area], camp.basket }
					do
						expect(apart(x, z, point.x, point.z) > reach).to.equal(true)
					end
				end
				expect(Layout.lateStationAt("sewer")).to.equal(nil)
			end
		)

		it(
			"stands the Garden Nursery in the Park camp, turned 90 on the camp, clear of the extra and the pad (#1200)",
			function()
				local x, y, z, turn = Layout.lawnStallAt()
				assert(x ~= nil and y ~= nil and z ~= nil and turn ~= nil, "no Garden Nursery spot")
				local camp = Layout.camps.park
				expect(Layout.campAt(x, z)).to.equal("park")
				expect(y).to.equal(Layout.areas.park.floorY)
				-- front (-Z) faces set -X: the camp's turn + 90
				expect(turn).to.equal(camp.turn + 90)
				local ex, _, ez = Layout.campExtraAt("park")
				assert(ex ~= nil and ez ~= nil, "no park extra")
				expect(apart(x, z, ex, ez) > 6).to.equal(true)
				local pad = Layout.landingPads.park.centre
				expect(apart(x, z, pad.x, pad.z) > W.LandingPadRadius + 3).to.equal(true)
			end
		)
	end)

	-- #2240 (Derek 11-07: "change rescue spots not always the same"): each area's pool of trap spots, which RescuePick
	-- draws the day's traps from. The pool holds today's spots first, enough of each trap type for today's mix, and
	-- keeps the rules today's spots keep, so any day's pick keeps them too.
	describe("rescue spot pools (#2240)", function()
		it("every area's pool starts with today's spots and has room for today's mix", function()
			for id, spec in Layout.areas do
				local pool = spec.rescuePool
				if pool == nil then
					fail("%s has no rescue pool", id)
					continue
				end
				for i, spot in spec.rescueSpots do
					local same = pool[i]
					expect(same.trap).to.equal(spot.trap)
					expect(same.prop).to.equal(spot.prop)
					expect(same.x).to.be.near(spot.x, 1e-9)
					expect(same.z).to.be.near(spot.z, 1e-9)
					expect(same.rotY).to.be.near(spot.rotY, 1e-9)
				end
				local need: { [string]: number } = {}
				for _, spot in spec.rescueSpots do
					need[spot.trap] = (need[spot.trap] or 0) + 1
				end
				local have: { [string]: number } = {}
				for _, spot in pool do
					have[spot.trap] = (have[spot.trap] or 0) + 1
					if need[spot.trap] == nil then
						fail("%s's pool has a %s spot, a trap it has none of today", id, spot.trap)
					end
				end
				for trap, count in need do
					expect((have[trap] or 0) >= count).to.equal(true)
				end
				expect(#pool >= 2 * #spec.rescueSpots).to.equal(true)
			end
		end)

		it(
			"keeps every pool spot 25 studs from every other, on the floor and clear of the spawn points",
			function()
				for id, spec in Layout.areas do
					local pool = spec.rescuePool or {}
					local floor: Rect = {
						x1 = spec.center.x - spec.halfWidth,
						z1 = spec.center.z - spec.halfDepth,
						x2 = spec.center.x + spec.halfWidth,
						z2 = spec.center.z + spec.halfDepth,
					}
					local clear = if id == "alley" then 9 else 4
					for i, spot in pool do
						local onIt = if id == "alley"
							then onFloor(spot.x, spot.z, alleyRects, 0)
							else inside(spot.x, spot.z, floor, 0)
						if not onIt then
							fail("%s pool spot %d is off the floor", id, i)
						end
						for j = i + 1, #pool do
							local other = pool[j]
							local apart = math.sqrt((spot.x - other.x) ^ 2 + (spot.z - other.z) ^ 2)
							if apart < 25 then
								fail("%s pool spots %d and %d are %.1f apart", id, i, j, apart)
							end
						end
						for k, point in spec.spawnPoints do
							local gap = math.sqrt((spot.x - point.x) ^ 2 + (spot.z - point.z) ^ 2)
							if gap < clear then
								fail("%s pool spot %d is %.1f from spawn point %d", id, i, gap, k)
							end
						end
						local pose = if spot.prop ~= nil
							then Layout.stuckPoses[spot.prop]
							else Layout.setStuckPoses[spot.trap]
						if pose == nil then
							fail("%s pool spot %d (%s) has no stuck pose", id, i, spot.trap)
						end
					end
				end
			end
		)

		it(
			"keeps a long area's pool 100 studs from its camp, three quarters of it in the far half",
			function()
				for id, spec in Layout.areas do
					local set = spec.set
					if set == nil or string.sub(set, -7) ~= "_SetF85" then
						continue
					end
					local camp = Layout.camps[id]
					local along = 0
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local _, z = Layout.campLocal(
								camp,
								spec.center.x + sx * spec.halfWidth,
								spec.center.z + sz * spec.halfDepth
							)
							along = math.max(along, z)
						end
					end
					local pool = spec.rescuePool or {}
					-- #2794: a starting area keeps one starter trap by the camp (RescueService fills the nearest spot)
					local def = Catalog.getArea(id)
					local starters = if def ~= nil and def.starterRescue == true then 1 else 0
					local far = 0
					for i, spot in pool do
						local _, z = Layout.campLocal(camp, spot.x, spot.z)
						if z <= 100 and starters > 0 then
							starters -= 1
						elseif z <= 100 then
							fail(
								"%s pool spot %d (%s) is %.1f studs from the camp",
								id,
								i,
								spot.trap,
								z
							)
						end
						if z > along / 2 then
							far += 1
						end
					end
					if far < 0.75 * #pool then
						fail("%s has %d of %d pool spots in its far half", id, far, #pool)
					end
				end
			end
		)
	end)

	-- #2687 part 2: each wild area's hidden nook (CatCafe_Nook_<Area>) and its own rescue spot, filled every day on
	-- top of the pool's pick (RescueService). The nook stands on the floor, its walls and the lane out of its gate clear
	-- of the cat spots, its trap a pool spot's distance from every pool spot and well clear of every cat spot.
	describe("hidden nooks (#2687)", function()
		it("puts a nook in every wild area, clear of the cat spots and the pool", function()
			for id, spec in Layout.areas do
				local nook = spec.nook
				if id == "alley" then
					expect(nook).never.to.be.ok()
					continue
				end
				if nook == nil then
					fail("%s has no nook", id)
					continue
				end
				local area = string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2)
				expect(nook.asset).to.equal("CatCafe_Nook_" .. area)
				local trap = nook.trap
				local pose = if trap.prop ~= nil
					then Layout.stuckPoses[trap.prop]
					else Layout.setStuckPoses[trap.trap]
				if pose == nil then
					fail("%s nook trap (%s) has no stuck pose", id, trap.trap)
				end
				-- the nook's footprint, its stones and a lane out of its gate: x -4.4 to 4.4, z -13 to 3.9 in its space
				local a = math.rad(nook.rotY)
				local c, s = math.cos(a), math.sin(a)
				local function toNook(x: number, z: number): (number, number)
					local dx, dz = x - nook.x, z - nook.z
					return dx * c - dz * s, dx * s + dz * c
				end
				for corner = 1, 4 do
					local lx = if corner <= 2 then -4.4 else 4.4
					local lz = if corner % 2 == 1 then -13 else 3.9
					local wx, wz = nook.x + lx * c + lz * s, nook.z - lx * s + lz * c
					if
						math.abs(wx - spec.center.x) > spec.halfWidth - 2
						or math.abs(wz - spec.center.z) > spec.halfDepth - 2
					then
						fail("%s nook reaches off the floor", id)
					end
				end
				for k, point in spec.spawnPoints do
					local gap = math.sqrt((trap.x - point.x) ^ 2 + (trap.z - point.z) ^ 2)
					if gap < 9 then
						fail("%s nook trap is %.1f from spawn point %d", id, gap, k)
					end
					local lx, lz = toNook(point.x, point.z)
					local ox = math.max(math.abs(lx) - 4.4, 0)
					local oz = math.max(-13 - lz, lz - 3.9, 0)
					if math.sqrt(ox * ox + oz * oz) < 2 then
						fail(
							"%s nook is %.1f from spawn point %d",
							id,
							math.sqrt(ox * ox + oz * oz),
							k
						)
					end
				end
				for i, spot in spec.rescuePool or {} do
					local gap = math.sqrt((trap.x - spot.x) ^ 2 + (trap.z - spot.z) ^ 2)
					if gap < 25 then
						fail("%s nook trap is %.1f from pool spot %d", id, gap, i)
					end
				end
			end
		end)

		it("stands each trap on its nook's RescueSpot", function()
			for id, spec in Layout.areas do
				local nook = spec.nook
				if nook == nil then
					continue
				end
				-- the trap is on the nook's middle line, 1 or less from the nook's pivot (nooks.py TRAPS)
				local a = math.rad(nook.rotY)
				local dx, dz = nook.trap.x - nook.x, nook.trap.z - nook.z
				local across = dx * math.cos(a) - dz * math.sin(a)
				expect(across).to.be.near(0, 1e-6)
				expect(math.sqrt(dx * dx + dz * dz) <= 1).to.equal(true)
				expect(nook.trap.y or 0).to.be.near(nook.y, 1e-9)
				if id == "sewer" then
					expect(nook.y).to.equal(spec.setLift)
				end
			end
		end)
	end)

	describe("area set barriers (#3348)", function()
		it("keeps the edge ring and drops every invisible barrier inside an area", function()
			expect(Layout.keepsBarrier("CatCafe_Ruins_Set_068_Walls_Barrier")).to.equal(true)
			expect(Layout.keepsBarrier("CatCafe_Sewer_SetF85_034_Walls_Barrier")).to.equal(true)
			for _, name in
				{
					"CatCafe_Ruins_Set_087_GlyphHalls_Barrier",
					"CatCafe_Sewer_SetF85_037_Pool_Barrier",
					"CatCafe_Woods_SetF85_085_Stream_Barrier",
					"CatCafe_Neighbourhood_SetF85_335_Blocks_Barrier",
					"CatCafe_Park_SetF85_124_Glasshouse_Barrier",
				}
			do
				expect(Layout.keepsBarrier(name)).to.equal(false)
			end
		end)

		it("leaves everything that is not a barrier, the climb ramps too", function()
			expect(Layout.keepsBarrier("CatCafe_Woods_SetF85_162_Treehouse_Climb")).to.equal(true)
			expect(Layout.keepsBarrier("CatCafe_Ruins_Set")).to.equal(true)
			expect(Layout.keepsBarrier("BarrierPost")).to.equal(true)
		end)
	end)
end
