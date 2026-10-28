--!strict
-- The world layout (server World/Layout.luau, pure geometry) against design v0.4: world-and-feel.md section 2 (the
-- Alleyway out back) and its section 8 acceptance check 4 (F35, layout v2; check 4 as reworded in docs PR #83), and
-- town-layout-v3.md (F76) with section 7 (v3.1, F77: the Alley Square gone, the Woods and Sewer off the alleys).
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

	-- The middle of a cafe's back door, where its back wall meets the yard.
	local function backDoor(index: number): (number, number)
		return plotToWorld(index, Layout.plot.backDoor.x, W.PlotDepth / 2)
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

		it("spawn points are at least 4 studs apart in every area, so strays never stack", function()
			for id, spec in Layout.areas do
				for i, a in spec.spawnPoints do
					for j = i + 1, #spec.spawnPoints do
						local b = spec.spawnPoints[j]
						local apart = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
						if apart < 4 then
							fail("%s spawn points %d and %d are %.1f studs apart", id, i, j, apart)
						end
					end
				end
			end
		end)

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
							fail("%s spawn point %d is %.1f studs from rescue spot %d", id, i, apart, j)
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
				expect(built).to.equal(
					if id == "park" then 0 elseif id == "woods" then 5 else 4
				)
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
				local toGate = math.sqrt((point.x - (gx :: number)) ^ 2 + (point.z - (gz :: number)) ^ 2)
				local toCenter = math.sqrt((point.x - spec.center.x) ^ 2 + (point.z - spec.center.z) ^ 2)
				if toGate >= toCenter then
					fail("%s spawn point %d is %.1f from the gate and %.1f from the centre", id, index, toGate, toCenter)
				end
			end
		end)

		-- F81 (town-layout-v3.md section 8d): a v3.2 set tags each cat spot near (the gate half) or deep (the far
		-- half, where Epic and rarer strays wait), and some of its traps are in the far half. The Woods' Great Oak
		-- top is "rare" (Catching.RARE_ZONE), in the far half too. The Sewer's zones go by region (#491): its near
		-- spots are all in the gate half, but past the cross wall's arch is deep, the west hall's far chamber in the
		-- gate half among it.
		it("the v3.2 sets' spots are near their gates or deep in their far halves, with traps deep", function()
			local rows = {
				{ id = "park", near = 16, deep = 24, rare = 0, deepTraps = 3, byRegion = false },
				{ id = "woods", near = 26, deep = 38, rare = 1, deepTraps = 3, byRegion = false },
				{ id = "sewer", near = 20, deep = 32, rare = 0, deepTraps = 2, byRegion = true },
				{ id = "neighbourhood", near = 28, deep = 44, rare = 0, deepTraps = 2, byRegion = false },
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
						fail("%s spawn point %d (%s) is %.1f studs in from the gate", row.id, i, zone, inFrom)
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
		end)

		-- Derek 2026-10-28 01:34 and 01:35 (Model-Agent #452): a cat can get stuck up the tree house's branch, and the
		-- Great Oak's top nook is where the rarer cats wait.
		it("the Woods' tree house branch is a tree trap up off the deck, and the oak top a rare spot", function()
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
		end)
	end)

	describe("the Alleyway out back (world-and-feel section 2, F35)", function()
		it("24 spawn points: two behind every cafe and two at each end of the back alleys (v3.1)", function()
			local zones: { [string]: number } = {}
			for _, point in alley.spawnPoints do
				expect(point.zone).to.be.ok()
				local zone = point.zone :: string
				zones[zone] = (zones[zone] or 0) + 1
			end
			expect(#alley.spawnPoints).to.equal(24)
			expect(zones.lane).to.equal(2 * W.PlotCount)
			expect(zones.nook).to.equal(8)
		end)

		it("every point lies in a back alley, and the nooks at its ends, 10 studs from every lane point", function()
			local ends: { [string]: number } = {}
			for i, point in alley.spawnPoints do
				local inAlley = math.abs(point.x) >= W.AlleyInnerX
					and math.abs(point.x) <= W.AlleyOuterX
					and point.z > W.AlleySouthZ
					and point.z < W.AlleyNorthZ
				if not inAlley then
					fail("%s point %d at (%g, %g) is not in a back alley", tostring(point.zone), i, point.x, point.z)
				end
				if point.zone ~= "nook" then
					continue
				end
				-- 6.5 from a south end wall and 8.5 from a north one (section 7e, reviewer S84), so 2 or more inside
				-- the roam rects' 4 and 6 stud margins
				local fromEnd = W.AlleyNorthZ - math.abs(point.z)
				if fromEnd < 6 or fromEnd > 9 then
					fail("nook point %d at (%g, %g) is %.1f from its end wall", i, point.x, point.z, fromEnd)
				end
				local key = (if point.x < 0 then "w" else "e") .. (if point.z < 0 then "s" else "n")
				ends[key] = (ends[key] or 0) + 1
				for j, lane in alley.spawnPoints do
					local apart = math.sqrt((point.x - lane.x) ^ 2 + (point.z - lane.z) ^ 2)
					if lane.zone == "lane" and apart < 10 then
						fail("nook point %d is %.1f studs from lane point %d", i, apart, j)
					end
				end
			end
			for _, key in { "ws", "wn", "es", "en" } do
				expect(ends[key]).to.equal(2)
			end
		end)

		it("plot p owns alley points 2p - 1 and 2p, behind its own yard", function()
			-- The tutorial stray waits at a beginner's own yard gate.
			for index = 1, W.PlotCount do
				local placement = Layout.plotPlacement(index)
				for _, n in { 2 * index - 1, 2 * index } do
					local point = alley.spawnPoints[n]
					expect(point.zone).to.equal("lane")
					expect(math.sign(point.x)).to.equal(placement.side)
					local along = math.abs(point.z - placement.z)
					expect(along <= (W.PlotWidth + W.PlotRowGap) / 2).to.equal(true)
				end
			end
		end)

		it("every spawn point is 2 studs inside a floor and clear of every wall", function()
			for i, point in alley.spawnPoints do
				local off = not onFloor(point.x, point.z, alleyRects, 2)
				if off or inWall(point.x, point.z, alleyWalls, 1) then
					fail("alley point %d at (%g, %g) is off the floor or in a wall", i, point.x, point.z)
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
				return math.min(math.max(a1, a2), math.max(b1, b2)) - math.max(math.min(a1, a2), math.min(b1, b2))
			end
			for r, rect in roam do
				for _, corner in { { rect.x1, rect.z1 }, { rect.x1, rect.z2 }, { rect.x2, rect.z1 }, { rect.x2, rect.z2 } } do
					if not onFloor(corner[1], corner[2], alleyRects, 0) then
						fail("roam rect %d corner (%g, %g) is off the floor", r, corner[1], corner[2])
					end
				end
				for w, wall in alleyWalls do
					if overlap(rect.x1, rect.x2, wall.x1, wall.x2) > 0 and overlap(rect.z1, rect.z2, wall.z1, wall.z2) > 0 then
						fail("roam rect %d overlaps wall %d", r, w)
					end
				end
			end
		end)

		it("every spawn point is 2 studs inside a roam rect, so no stray starts in the dressing (QA)", function()
			local roam = alley.roam :: { Rect }
			for i, point in alley.spawnPoints do
				if not onFloor(point.x, point.z, roam, 2) then
					fail("alley point %d at (%g, %g) is not 2 studs inside a roam rect", i, point.x, point.z)
				end
			end
		end)

		it("keeps the strays 5 studs off both outer walls and 4 off the end walls (QA, v3.1)", function()
			for r, rect in alley.roam :: { Rect } do
				local x1, x2 = math.min(rect.x1, rect.x2), math.max(rect.x1, rect.x2)
				local z1, z2 = math.min(rect.z1, rect.z2), math.max(rect.z1, rect.z2)
				local outer = x1 < -W.AlleyOuterX + 5 or x2 > W.AlleyOuterX - 5
				if outer or z1 < W.AlleySouthZ + 4 or z2 > W.AlleyNorthZ - 4 then
					fail("roam rect %d (%g to %g, z %g to %g) reaches into the dressing", r, x1, x2, z1, z2)
				end
				-- so no stray wanders out through the Woods or Sewer gate's opening either
				expect(x1 > -W.AlleyOuterX and x2 < W.AlleyOuterX).to.equal(true)
			end
		end)

		it("rescue spots stand on the Alleyway floor, two in the west back alley and one in the east (v3.1)", function()
			local west, east = 0, 0
			for _, spot in alley.rescueSpots do
				expect(onFloor(spot.x, spot.z, alleyRects, 0)).to.equal(true)
				if spot.x < 0 then
					west += 1
				else
					east += 1
				end
			end
			expect(west).to.equal(2)
			expect(east).to.equal(1)
		end)

		it("closes both back alleys at their ends and opens each outer wall only for its area's gate (v3.1)", function()
			for _, side in { -1, 1 } do
				-- along the outer wall's line: wall everywhere but the 24 stud gate opening at z -12 to 12
				local x = side * (W.AlleyOuterX + 0.5)
				for z = W.AlleySouthZ + 1, W.AlleyNorthZ - 1, 1 do
					local open = math.abs(z) < W.SideGateHalfWidth
					if inWall(x, z, alleyWalls, 0) == open then
						fail("outer wall at (%g, %g) is %s", x, z, if open then "closed" else "open")
					end
				end
				-- the end walls across the whole width of each back alley, with the Park's and the Neighbourhood's near
				-- walls (1 thick on their edges, opening as wide as the street) where those areas are wider
				local ends: { Rect } = table.clone(alleyWalls)
				for _, spec in { Layout.park, Layout.neighbourhood } do
					local nearZ = spec.center.z + (if spec.center.z < 0 then 1 else -1) * spec.halfDepth
					local opening = spec.openingHalfWidth or W.StreetHalfWidth
					local x1, x2 = spec.center.x - spec.halfWidth, spec.center.x + spec.halfWidth
					table.insert(ends, { x1 = x1, z1 = nearZ - 0.5, x2 = -opening, z2 = nearZ + 0.5 })
					table.insert(ends, { x1 = opening, z1 = nearZ - 0.5, x2 = x2, z2 = nearZ + 0.5 })
				end
				for ax = W.AlleyInnerX, W.AlleyOuterX, 2 do
					for _, z in { W.AlleySouthZ - 0.5, W.AlleyNorthZ + 0.5 } do
						if not inWall(side * ax, z, ends, 0) then
							fail("no end wall at (%g, %g)", side * ax, z)
						end
					end
				end
			end
		end)

		it("the Alley travel button lands just inside the side arch on the player's side (v3.1, check 6)", function()
			local west, east = alley.arrival :: Point, alley.arrivalEast :: Point
			expect(west).to.be.ok()
			expect(east).to.be.ok()
			for _, arrival in { west, east } do
				expect(onFloor(arrival.x, arrival.z, alleyRects, 2)).to.equal(true)
				expect(inWall(arrival.x, arrival.z, alleyWalls, 1)).to.equal(false)
				expect(math.abs(arrival.z) <= W.TownSquareArchWidth).to.equal(true)
			end
			expect(west.x < 0 and east.x > 0).to.equal(true)
		end)

		-- v3.1 gave up the Alley Square for the bigger Woods and Sewer next door (town-layout-v3.md section 7b), so
		-- the two back alleys alone are the Alleyway now: 8 times before, about 5.7 times since.
		it("is at least 5 times the old 60 x 44 stud box (size target)", function()
			local total = 0
			for _, rect in alleyRects do
				total += math.abs(rect.x2 - rect.x1) * math.abs(rect.z2 - rect.z1)
			end
			expect(total >= 5 * 60 * 44).to.equal(true)
		end)

		it("every yard gate opens onto its back alley", function()
			for index = 1, W.PlotCount do
				local gateX = plotToWorld(index, Layout.plot.yardGate.x1, Layout.plot.yard.z2)
				expect(math.abs(math.abs(gateX) - W.AlleyInnerX) <= 1).to.equal(true)
			end
		end)
	end)

	describe("the bait bowl on the back step (v0.5 F44, data-model section 8)", function()
		local plot = Layout.plot
		local halfD = W.PlotDepth / 2

		it("the bowl and its cat sit in the yard just outside the back wall, facing the Alleyway", function()
			for _, point in { plot.baitBowl, plot.baitCat } do
				expect(inside(point.x, point.z, plot.yard, 0.5)).to.equal(true)
				expect(point.z - (halfD + 1) <= 3).to.equal(true) -- on the step, not out in the yard
				expect(point.y).to.equal(0)
			end
		end)

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

		it("fills from the back door, and Tame reaches the door to gate walk (QA)", function()
			local bowl, door, gate, yard = plot.baitBowl, plot.backDoor, plot.yardGate, plot.yard
			local function from(x: number, z: number): number
				return math.sqrt((x - bowl.x) ^ 2 + (z - bowl.z) ^ 2)
			end
			-- UseLure measures from the character's root, so 2 studs of slack for standing a step away.
			expect(from(door.x, halfD + 1) <= Config.BaitBowlRangeStuds - 2).to.equal(true)
			-- Tame and Let go reach from every corner of the straight walk from the back door to the gate.
			local x1 = math.min(door.x - door.width / 2, gate.x1)
			local x2 = math.max(door.x + door.width / 2, gate.x2)
			for _, x in { x1, x2 } do
				for _, z in { halfD + 1, yard.z2 } do
					expect(from(x, z) <= Config.BaitResolveRangeStuds - 2).to.equal(true)
				end
			end
		end)
	end)

	-- Shortest walks over the Alleyway floor on a 1 stud grid, moving along x or z only, so every distance is at least
	-- the real walk. A cell is walkable when the floor reaches 1 stud past its centre every way (across the seams
	-- where one floor meets the next) and it is 1 stud clear of every wall.
	local GRID_X0 = -W.AlleyOuterX
	local GRID_Z0 = W.AlleySouthZ
	local GRID_NX = math.ceil(2 * W.AlleyOuterX)
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
	-- preallocated arrays keep the eight walks light on memory.
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

	-- A cafe's back door to its yard gate (the yard is open inside its fence), and the gate's alley-side point.
	local function yardWalk(index: number): (number, number, number)
		local doorX, doorZ = backDoor(index)
		local gate = Layout.plot.yardGate
		local gateX, gateZ = plotToWorld(index, (gate.x1 + gate.x2) / 2, Layout.plot.yard.z2)
		local side = Layout.plotPlacement(index).side
		local outX = side * (W.AlleyInnerX + 1.5)
		return math.abs(gateX - doorX) + math.abs(gateZ - doorZ) + math.abs(outX - gateX), outX, gateZ
	end

	local nookPoints: { Point } = {}
	for _, point in alley.spawnPoints do
		if point.zone == "nook" then
			table.insert(nookPoints, point)
		end
	end

	describe("walk times (acceptance check 4, docs PR #83)", function()
		it("from every cafe's back door a stray spawn is under 2 seconds away at NormalWalkSpeed", function()
			-- Out of the back door, through the yard and its gate, to the nearest lane point: at most the walk along
			-- x plus the walk along z.
			for index = 1, W.PlotCount do
				local doorX, doorZ = backDoor(index)
				local nearest = math.huge
				for _, point in alley.spawnPoints do
					local walk = math.abs(point.x - doorX) + math.abs(point.z - doorZ)
					nearest = math.min(nearest, walk)
				end
				local seconds = nearest / Config.NormalWalkSpeed
				if seconds >= 2 then
					fail("plot %d: the nearest spawn is %.1f s from the back door", index, seconds)
				end
			end
		end)

		it("every spawn point in a back alley can be walked to from every yard gate onto it", function()
			-- v3.1: the two back alleys meet only through the Town Square, which is not catching ground
			for index = 1, W.PlotCount do
				local _, outX, outZ = yardWalk(index)
				local dist = walkFrom(outX, outZ)
				for n, point in alley.spawnPoints do
					if math.sign(point.x) ~= math.sign(outX) then
						continue
					end
					if studsTo(dist, point.x, point.z) == nil then
						fail("plot %d: spawn point %d at (%g, %g) cannot be reached", index, n, point.x, point.z)
					end
				end
			end
		end)

		it("carrying a cat from any nook to any cafe's nearer door takes under 25 seconds (v3.1)", function()
			-- The check names the farthest cafe's nearer door. From a nook in the cafe's own back alley that is the
			-- back door, through the yard; from any nook it can be the front door, out of the back alley by the
			-- side arch or a side passage and along the street. The legs off the Alleyway are the walk along x and
			-- z, an upper bound. Travel is greyed while carrying, so this is the one walk that cannot be skipped.
			local exits: { { x: number, z: number, dist: { number } } } = {}
			for _, side in { -1, 1 } do
				local x = side * (W.AlleyInnerX + 1.5)
				for _, z in { 0, table.unpack(Layout.sidePassages()) } do
					table.insert(exits, { x = x, z = z, dist = walkFrom(x, z) })
				end
			end
			local worst, worstPlot, worstPoint = 0, 0, 0
			for index = 1, W.PlotCount do
				local yard, outX, outZ = yardWalk(index)
				local dist = walkFrom(outX, outZ)
				local doorX, doorZ = plotToWorld(index, Layout.plot.door.x, Layout.plot.door.z)
				for n, point in nookPoints do
					local nearer = math.huge
					local walked = studsTo(dist, point.x, point.z)
					if walked ~= nil then
						nearer = yard + walked
					end
					for _, exit in exits do
						local out = studsTo(exit.dist, point.x, point.z)
						if out ~= nil then
							nearer = math.min(nearer, out + math.abs(doorX - exit.x) + math.abs(doorZ - exit.z))
						end
					end
					if nearer == math.huge then
						fail("plot %d cannot reach nook point %d", index, n)
					end
					local seconds = nearer / Config.CarryWalkSpeed
					if seconds > worst then
						worst, worstPlot, worstPoint = seconds, index, n
					end
				end
			end
			expect(#nookPoints).to.equal(8)
			if worst >= 25 then
				fail("plot %d to nook point %d is %.1f s at carry speed", worstPlot, worstPoint, worst)
			end
			-- Layout v3 measured about 23 s from the Alley Square; a much shorter walk means the grid broke.
			expect(worst > 10).to.equal(true)
		end)
	end)

	-- QA (engineer PR #171): the red stripes and SAFE ZONE paint must match the rule they show. A shove lands only
	-- when both players are in the same catching area (Shove.refusal over WorldBuilder.areaAt, which tests these
	-- floor rects). The mark positions restate WorldBuilder.buildSafeZoneMarks.
	describe("safe zone marks match the catching areas (QA)", function()
		local parkEdge = W.ParkCenterZ + W.ParkDepth / 2 - 0.8 -- the Park stripe, on the Park floor
		local neighbourhoodEdge = W.NeighbourhoodCenterZ - W.NeighbourhoodDepth / 2 + 0.8 -- and the Neighbourhood's

		-- WorldBuilder.areaAt at floor height: the Alleyway's floor rects, one floor for a box area.
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

		local function expectArea(x: number, z: number, want: string?, what: string)
			local got = areaAt(x, z)
			if got ~= want then
				local wanted = tostring(want)
				fail("%s at (%.1f, %.1f): %s, wants %s", what, x, z, tostring(got), wanted)
			end
		end

		it("stripes lie in their area, and a stud toward the cafes is in none", function()
			for _, side in { -1, 1 } do
				local x = side * (W.AlleyInnerX + 0.3)
				for z = W.AlleySouthZ, W.AlleyNorthZ, 2 do
					expectArea(x, z, "alley", "back alley stripe")
					expectArea(x - side, z, nil, "a stud off the back alley stripe")
				end
			end
			for x = -W.StreetHalfWidth, W.StreetHalfWidth, 2 do
				expectArea(x, parkEdge, "park", "Park stripe")
				expectArea(x, parkEdge + 1, nil, "a stud off the Park stripe")
				expectArea(x, neighbourhoodEdge, "neighbourhood", "Neighbourhood stripe")
				expectArea(x, neighbourhoodEdge - 1, nil, "a stud off the Neighbourhood stripe")
			end
		end)

		it("every SAFE ZONE sits in no area, in a side passage or on the street", function()
			for _, side in { -1, 1 } do
				expectArea(side * (W.AlleyInnerX - 3.5), 0, nil, "Town Square side arch SAFE ZONE")
				for _, z in Layout.sidePassages() do
					expectArea(side * (W.AlleyInnerX - 2.5), z, nil, "side passage SAFE ZONE")
					-- in the gap between two neighbouring yards, not on one
					for index = 1, W.PlotCount do
						local placement = Layout.plotPlacement(index)
						local onYard = math.abs(placement.z - z) < W.PlotWidth / 2
						if placement.side == side and onYard then
							fail("side passage SAFE ZONE at z %.1f is on plot %d", z, index)
						end
					end
				end
			end
			expectArea(0, W.ParkGateZ + 4, nil, "street SAFE ZONE before the Park gate")
			expectArea(0, W.NeighbourhoodGateZ - 4, nil, "street SAFE ZONE before the Neighbourhood gate")
		end)

		it("the street stripes span the whole way in", function()
			for _, spec in { Layout.park, Layout.neighbourhood } do
				local opening = spec.openingHalfWidth or W.StreetHalfWidth
				expect(W.StreetHalfWidth >= opening).to.equal(true)
			end
		end)
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

		it("keeps every plot, yard included, off the square and inside the street's length", function()
			for index = 1, W.PlotCount do
				local z = Layout.plotPlacement(index).z
				expect(math.abs(z) - W.PlotWidth / 2 >= W.TownSquareHalfDepth + W.PlotRowGap).to.equal(true)
				expect(math.abs(z) + W.PlotWidth / 2 <= W.StreetNorthZ).to.equal(true)
			end
		end)

		it("finds a side passage between every pair of neighbouring cafes and beside the gardens", function()
			local passages = Layout.sidePassages()
			expect(#passages).to.equal(4)
			for _, z in passages do
				for index = 1, W.PlotCount do
					local placement = Layout.plotPlacement(index)
					expect(math.abs(placement.z - z) >= W.PlotWidth / 2 + W.PlotRowGap / 2).to.equal(true)
				end
				expect(math.abs(z) > W.TownSquareHalfDepth).to.equal(true)
			end
		end)

		local stations: { [string]: Point } = {
			spinWheel = Layout.spinWheel,
			fishMarket = Layout.fishMarket,
			codesCat = Layout.codesCat,
			dealerCart = Layout.dealerCart,
		}

		it("stands each station in its own quarter, off the open cross, facing the fountain", function()
			local quarters: { [string]: string } = {}
			for name, point in stations do
				expect(inside(point.x, point.z, square.floor, 4)).to.equal(true)
				for _, lane in lanes do
					if inside(point.x, point.z, lane, -5) then
						fail("%s at (%g, %g) stands within 5 studs of the open cross", name, point.x, point.z)
					end
				end
				local quarter = (if point.x < 0 then "w" else "e") .. (if point.z < 0 then "s" else "n")
				expect(quarters[quarter]).to.equal(nil)
				quarters[quarter] = name
				-- WorldBuilder turns a point by CFrame.Angles(0, rad(rotY), 0), whose LookVector is (-sin, 0, -cos).
				local yaw = math.rad(point.rotY or 0)
				local lookX, lookZ = -math.sin(yaw), -math.cos(yaw)
				local length = math.sqrt(point.x * point.x + point.z * point.z)
				local dot = (lookX * -point.x + lookZ * -point.z) / length
				expect(dot > 0.999).to.equal(true)
			end
		end)

		it("keeps the Codes circle clear of the cross and of the Spin Wheel's prompt (QA check 2)", function()
			local codes = Layout.codesCat
			local yaw = math.rad(codes.rotY or 0)
			local cx, cz = codes.x - 6 * math.sin(yaw), codes.z - 6 * math.cos(yaw)
			for _, lane in lanes do
				expect(inside(cx, cz, lane, -Config.CodesCircleRadius)).to.equal(false)
			end
			local wheel = Layout.spinWheel
			local gap = math.sqrt((cx - wheel.x) ^ 2 + (cz - wheel.z) ^ 2)
			expect(gap > Config.SpinStationRange + Config.CodesCircleRadius).to.equal(true)
		end)

		it("spawns players on the street's line in the square, looking north at the fountain", function()
			local spawn = Layout.playerSpawn
			expect(math.abs(spawn.x) <= W.TownSquareLaneHalfWidth).to.equal(true)
			expect(inside(spawn.x, spawn.z, square.floor, 0)).to.equal(true)
			expect(spawn.z < -Layout.townSquare.fountainRadius).to.equal(true)
			expect(math.abs(math.sin(math.rad(spawn.rotY or 0)))).to.be.near(0, 1e-9)
			expect(-math.cos(math.rad(spawn.rotY or 0))).to.equal(1)
		end)

		it("opens a side arch from each garden into its back alley, on the alley's inner edge", function()
			expect(#square.arches).to.equal(2)
			for _, arch in square.arches do
				expect(math.abs(math.abs(arch.x) - W.AlleyInnerX) <= 1).to.equal(true)
				expect(arch.z).to.equal(0)
				expect(arch.span).to.equal(W.TownSquareArchWidth)
				-- the lane through the square lines up with the arch
				expect(W.TownSquareCrossHalfWidth * 2 >= arch.span).to.equal(true)
			end
		end)

		it("keeps every Alleyway rescue spot 9 studs from every spawn point (reviewer N77)", function()
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
		end)

		it("keeps the back alleys' loose props 6 studs from every lane spawn point", function()
			for _, prop in alley.props :: { Layout.Prop } do
				local name = prop.asset
				local loose = name:find("Dumpster", 1, true) ~= nil
					or name:find("GarbageBags", 1, true) ~= nil
					or name:find("TrashCan", 1, true) ~= nil
					or name:find("_Crate", 1, true) ~= nil and name:find("CrateStack", 1, true) == nil
				if not loose then
					continue
				end
				for _, point in alley.spawnPoints do
					local gap = math.sqrt((prop.x - point.x) ^ 2 + (prop.z - point.z) ^ 2)
					if gap < 6 then
						fail("%s at (%g, %g) is %.1f from the spawn point at (%g, %g)", name, prop.x, prop.z, gap, point.x, point.z)
					end
				end
			end
		end)

		-- Model-Agent #535: eight full buildings in place of the repeated backs and the staff doors.
		it("lines each back alley's outer wall with six different buildings, a crate stack by each Warehouse", function()
			local prefix = "CatCafe_Alley_Building_"
			for _, side in { -1, 1 } do
				local seen: { [string]: boolean } = {}
				local count, warehouses, stacks = 0, 0, 0
				for _, prop in alley.props :: { Layout.Prop } do
					if prop.x * side <= 0 then
						continue
					end
					local onOuterWall = math.abs(prop.x) > W.AlleyOuterX
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
				expect(count).to.equal(6)
				expect(warehouses).to.equal(1)
				expect(stacks).to.equal(warehouses)
			end
		end)

		it("keeps every building's back inside the walls behind it, off the next area's floor", function()
			local prefix = "CatCafe_Alley_Building_"
			local woodsEdge = -(W.WoodsCenterX + W.WoodsWidth / 2) -- the Woods' near edge, |x|
			local sewerEdge = W.SewerCenterX - W.SewerWidth / 2
			local parkEdge = -(W.ParkCenterZ + W.ParkDepth / 2) -- the Park's near edge, |z|
			local hoodEdge = W.NeighbourhoodCenterZ - W.NeighbourhoodDepth / 2
			local ends = 0
			for _, prop in alley.props :: { Layout.Prop } do
				if prop.asset:sub(1, #prefix) ~= prefix then
					continue
				end
				if math.abs(prop.x) > W.AlleyOuterX then
					-- the back plane: past the alley's outer wall face, inside the side area's wall (1 thick, centred)
					local edge = if prop.x < 0 then woodsEdge else sewerEdge
					expect(math.abs(prop.x) <= edge + 0.5).to.equal(true)
				else
					ends += 1
					local edge = if prop.z < 0 then parkEdge else hoodEdge
					expect(math.abs(prop.z) >= math.abs(W.AlleyNorthZ)).to.equal(true)
					expect(math.abs(prop.z) <= edge + 0.5).to.equal(true)
				end
			end
			expect(ends).to.equal(3) -- both south ends and the east north end; the west north end keeps the mural
		end)
	end)

	-- Town layout v3.1 (F77, town-layout-v3.md section 7): every area one straight walk from the fountain.
	describe("the compass (layout v3.1, F77)", function()
		local square = Layout.townSquare
		local lanes = square.lanes :: { Rect }

		it("stands every gate in the middle of its opening, turned to face the town", function()
			local want = {
				park = { 0, W.ParkGateZ, 180 },
				neighbourhood = { 0, W.NeighbourhoodGateZ, 0 },
				woods = { W.WoodsGateX, 0, -90 },
				sewer = { W.SewerGateX, 0, 90 },
			} :: { [string]: { number } }
			for id, spec in Layout.areas do
				local x, z = Layout.gatePosition(spec)
				local gate = want[id]
				if gate == nil then
					expect(x).to.equal(nil)
					expect(Layout.gateTurn(spec)).to.equal(0)
					continue
				end
				expect(x).to.equal(gate[1])
				expect(z).to.equal(gate[2])
				expect(Layout.gateTurn(spec)).to.equal(gate[3])
				-- the gate's front, CFrame.Angles(0, rad(turn), 0)'s LookVector (-sin, 0, -cos), points at the fountain
				local yaw = math.rad(gate[3])
				local length = math.sqrt(gate[1] ^ 2 + gate[2] ^ 2)
				local dot = (-math.sin(yaw) * -gate[1] - math.cos(yaw) * -gate[2]) / length
				expect(dot).to.be.near(1, 1e-9)
			end
		end)

		it("puts every gate under 6.5 s on foot from the fountain, straight down an arm of the cross (QA check 3)", function()
			for id, spec in Layout.areas do
				local x, z = Layout.gatePosition(spec)
				if x == nil or z == nil then
					continue
				end
				expect(x == 0 or z == 0).to.equal(true)
				local seconds = (math.abs(x) + math.abs(z)) / Config.NormalWalkSpeed
				if seconds >= 6.5 then
					fail("the %s gate is %.1f s from the fountain", id, seconds)
				end
			end
		end)

		it("opens the Woods and the Sewer through the back alleys' outer walls, across from the side arches", function()
			for _, spec in { Layout.woods, Layout.sewer } do
				local gateX = spec.gateX :: number
				local side = math.sign(gateX)
				expect(spec.gateZ).to.equal(nil)
				expect(spec.openingHalfWidth).to.equal(W.SideGateHalfWidth)
				-- the gate stands in the alley's outer wall, and the area's near wall is right behind it
				expect(math.abs(gateX) >= W.AlleyOuterX and math.abs(gateX) <= W.AlleyOuterX + 1).to.equal(true)
				local nearEdge = math.abs(spec.center.x) - spec.halfWidth
				expect(nearEdge > W.AlleyOuterX + 1 and nearEdge <= W.AlleyOuterX + 2.5).to.equal(true)
				expect(side * spec.center.x > 0).to.equal(true)
				local arch = nil
				for _, a in square.arches do
					if math.sign(a.x) == side then
						arch = a
					end
				end
				expect(arch).to.be.ok()
				expect((arch :: Layout.Arch).z).to.equal(spec.center.z)
			end
		end)

		it("stands the signpost by the fountain's ring, south-west and off the cross", function()
			local post = square.signpost :: Point
			expect(post.x < 0 and post.z < 0).to.equal(true)
			local fromFountain = math.sqrt(post.x ^ 2 + post.z ^ 2)
			expect(fromFountain > square.fountainRadius + 3 and fromFountain < 15).to.equal(true)
			for _, lane in lanes do
				expect(inside(post.x, post.z, lane, -0.5)).to.equal(false)
			end
		end)

		it("lays a paw path from the fountain to every gate and on into its area", function()
			local reach: { [string]: { number } } = {}
			for _, paw in Layout.pawPrints() do
				local along = math.max(math.abs(paw.x), math.abs(paw.z)) -- down the arm of the cross
				local seen = reach[paw.area] or { math.huge, 0 }
				reach[paw.area] = { math.min(seen[1], along), math.max(seen[2], along) }
				-- its front (-Z) turned away from the fountain, toward the gate
				local yaw = math.rad(paw.rotY)
				local out = math.sqrt(paw.x ^ 2 + paw.z ^ 2)
				expect((-math.sin(yaw) * paw.x - math.cos(yaw) * paw.z) / out > 0.99).to.equal(true)
			end
			for id, spec in Layout.areas do
				local x, z = Layout.gatePosition(spec)
				if x == nil or z == nil then
					expect(reach[id]).to.equal(nil)
					continue
				end
				local seen = reach[id]
				expect(seen).to.be.ok()
				expect(seen[1] <= square.fountainRadius + 3).to.equal(true)
				expect(seen[2] >= math.abs(x) + math.abs(z) + 5).to.equal(true)
			end
		end)

		it("keeps every paw print off the safe zone paint and out of the walls", function()
			-- the marks a print would cover, as WorldBuilder.buildSafeZoneMarks lays them, and its 0.8 stud reach
			local marks: { Rect } = {}
			for _, side in { -1, 1 } do
				local words = side * (W.AlleyInnerX - 3.5)
				local stripe = side * (W.AlleyInnerX + 0.3)
				table.insert(marks, { x1 = words - 0.9, z1 = -4.5, x2 = words + 0.9, z2 = 4.5 })
				table.insert(marks, { x1 = stripe - 0.25, z1 = W.AlleySouthZ, x2 = stripe + 0.25, z2 = W.AlleyNorthZ })
			end
			for _, spec in { Layout.park, Layout.neighbourhood } do
				local toward = if spec.center.z < 0 then 1 else -1
				local words = (spec.gateZ :: number) + toward * 4
				local edge = spec.center.z + toward * (spec.halfDepth - 0.8)
				table.insert(marks, { x1 = -6, z1 = words - 1.2, x2 = 6, z2 = words + 1.2 })
				local half = W.StreetHalfWidth
				table.insert(marks, { x1 = -half, z1 = edge - 0.25, x2 = half, z2 = edge + 0.25 })
			end
			local areaWalls: { Rect } = {}
			for _, spec in { Layout.woods, Layout.sewer } do
				local near = spec.center.x - math.sign(spec.center.x) * spec.halfWidth
				table.insert(areaWalls, { x1 = near - 0.5, z1 = -spec.halfDepth, x2 = near + 0.5, z2 = spec.halfDepth })
			end
			for n, paw in Layout.pawPrints() do
				for _, mark in marks do
					if inside(paw.x, paw.z, mark, -0.9) then
						fail("%s paw print %d at (%g, %g) covers a safe zone mark", paw.area, n, paw.x, paw.z)
					end
				end
				if inWall(paw.x, paw.z, alleyWalls, 0.9) or inWall(paw.x, paw.z, areaWalls, 0.9) then
					fail("%s paw print %d at (%g, %g) is in a wall", paw.area, n, paw.x, paw.z)
				end
			end
		end)
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
			expect(plot.tables[1].z < plot.tables[3].z and plot.tables[3].z < plot.tables[5].z).to.equal(true)
		end)

		it("leaves the aisle clear: no table or chair reaches inside x -6.3 to 6.3", function()
			expect(plot.seatOffsets[2].x + 1.3 <= REACH + 1e-9).to.equal(true)
			for i, spot in plot.tables do
				if math.abs(spot.x) - REACH < AISLE - 1e-9 then
					fail("table %d at x %.2f reaches into the aisle", i, spot.x)
				end
			end
			expect(math.abs(plot.door.x) < AISLE and math.abs(plot.counter.x) < AISLE).to.equal(true)
			expect(math.abs(plot.orderPoint.x) < AISLE).to.equal(true)
		end)

		it("walks customers down the aisle clear of the waiters and along lanes clear of every table", function()
			for _, role in { "waiter_1", "waiter_2", "waiter_3" } do
				expect(math.abs(plot.spots[role].x) - plot.aisleX >= 2).to.equal(true)
			end
			expect(plot.aisleX > 0 and plot.aisleX + 1 <= AISLE).to.equal(true)
			for i, spot in plot.tables do
				expect(math.abs(spot.lane) < halfD - 1).to.equal(true)
				for j, other in plot.tables do
					if math.abs(spot.lane - other.z) < DEPTH + 0.5 then
						fail("table %d's lane z %.2f runs through table %d at z %.2f", i, spot.lane, j, other.z)
					end
				end
			end
		end)

		it("keeps the straight walk from the back door to the front door a stud clear of every table (N237)", function()
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
		end)

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

		it("names every piece CatCafe_Square_ and keeps the paving and fountain at the origin", function()
			for _, prop in square.props :: { any } do
				expect(string.sub(prop.asset, 1, 15)).to.equal("CatCafe_Square_")
			end
			for _, asset in { "CatCafe_Square_Paving", "CatCafe_Square_Fountain" } do
				local pieces = piecesOf(asset)
				expect(#pieces).to.equal(1)
				expect(pieces[1].x).to.equal(0)
				expect(pieces[1].z).to.equal(0)
			end
		end)

		it("rings the fountain with seven benches at one radius, each turned to face it", function()
			local benches = piecesOf("CatCafe_Square_Bench")
			expect(#benches).to.equal(7)
			local radius = math.sqrt(benches[1].x ^ 2 + benches[1].z ^ 2)
			expect(radius > square.fountainRadius + 8).to.equal(true)
			for i, bench in benches do
				expect(math.sqrt(bench.x ^ 2 + bench.z ^ 2)).to.be.near(radius, 0.05)
				-- WorldBuilder turns a prop by CFrame.Angles(0, rad(rotY), 0); its front (-Z) then points at the fountain
				local toward = math.deg(math.atan2(bench.x, bench.z))
				local off = ((bench.rotY or 0) - toward) % 360
				if math.min(off, 360 - off) > 0.5 then
					fail("bench %d at (%.2f, %.2f) is turned %.1f degrees off the fountain", i, bench.x, bench.z, off)
				end
				-- the signpost stands in the eighth bench's place, so no bench crowds it
				local dx, dz = bench.x - square.signpost.x, bench.z - square.signpost.z
				expect(math.sqrt(dx * dx + dz * dz) >= 4).to.equal(true)
			end
		end)

		it("keeps benches, lamps and gardens off the open cross and the spawn", function()
			local spawn = Layout.playerSpawn
			for _, asset in { "CatCafe_Square_Bench", "CatCafe_Square_Lamp", "CatCafe_Square_Garden" } do
				for i, piece in piecesOf(asset) do
					if onCross(piece.x, piece.z, 1) then
						fail("%s %d at (%.2f, %.2f) stands on the open cross", asset, i, piece.x, piece.z)
					end
					local dx, dz = piece.x - spawn.x, piece.z - spawn.z
					expect(math.sqrt(dx * dx + dz * dz) >= 6).to.equal(true)
				end
			end
			expect(#piecesOf("CatCafe_Square_Lamp")).to.equal(4)
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

		it("adds two beds a tier from Tier 3, so the trees' four places and the beds sleep every working slot", function()
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
		end)

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

		it("keeps every bed clear of the nap spots, decor spots, tables, stations, cat trees and the other beds", function()
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
		end)
	end)
end
