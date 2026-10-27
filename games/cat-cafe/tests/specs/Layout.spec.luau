--!strict
-- The world layout (server World/Layout.luau, pure geometry) against design v0.4: world-and-feel.md section 2 (the
-- Alleyway out back) and its section 8 acceptance check 4 (F35, layout v2; check 4 as reworded in docs PR #83).
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
	end)

	describe("the Alleyway out back (world-and-feel section 2, F35)", function()
		it("24 spawn points: two behind every cafe and eight in the Square", function()
			local zones: { [string]: number } = {}
			for _, point in alley.spawnPoints do
				expect(point.zone).to.be.ok()
				local zone = point.zone :: string
				zones[zone] = (zones[zone] or 0) + 1
			end
			expect(#alley.spawnPoints).to.equal(24)
			expect(zones.lane).to.equal(2 * W.PlotCount)
			expect(zones.square).to.equal(8)
		end)

		it("lane points lie in a back alley, Square points in the Square", function()
			for i, point in alley.spawnPoints do
				local inLane = math.abs(point.x) >= W.AlleyInnerX
					and math.abs(point.x) <= W.AlleyOuterX
					and point.z < W.SquareSouthZ
				local inSquare = point.z > W.SquareSouthZ and point.z < W.SquareNorthZ
				if point.zone == "lane" and not inLane then
					fail("lane point %d at (%g, %g) is not in a back alley", i, point.x, point.z)
				elseif point.zone == "square" and not inSquare then
					fail("square point %d at (%g, %g) is not in the Square", i, point.x, point.z)
				end
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
		-- fire escapes, crates up to 5 studs deep) and the Square's north wall. WorldBuilder.clampToArea keeps
		-- every wander and jump-back 2 studs inside a roam rect.
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

		it("keeps the strays 5 studs off both outer walls and off the Square's north wall (QA)", function()
			for r, rect in alley.roam :: { Rect } do
				local x1, x2 = math.min(rect.x1, rect.x2), math.max(rect.x1, rect.x2)
				local z2 = math.max(rect.z1, rect.z2)
				if x1 < -W.AlleyOuterX + 5 or x2 > W.AlleyOuterX - 5 or z2 > W.SquareNorthZ - 3 then
					fail("roam rect %d (%g to %g, up to z %g) reaches into the dressing", r, x1, x2, z2)
				end
			end
		end)

		it("rescue spots stand on the Alleyway floor, one in each back alley and one in the Square", function()
			local west, east, square = 0, 0, 0
			for _, spot in alley.rescueSpots do
				expect(onFloor(spot.x, spot.z, alleyRects, 0)).to.equal(true)
				if spot.z >= W.SquareSouthZ then
					square += 1
				elseif spot.x < 0 then
					west += 1
				else
					east += 1
				end
			end
			expect(west).to.equal(1)
			expect(east).to.equal(1)
			expect(square).to.equal(1)
		end)

		it("the Square's manhole sits on its floor, clear of the walls, the arrival and the rescue spots (QA, #102)", function()
			local manhole = Layout.manhole
			expect(manhole).to.be.ok()
			-- world-and-feel.md section 2: the Sewer down a manhole in the middle of the Square
			local sewer = nil
			for _, area in Catalog.areas do
				if area.id == manhole.area then
					sewer = area
				end
			end
			expect(sewer).to.be.ok()
			expect(manhole.z > W.SquareSouthZ and manhole.z < W.SquareNorthZ).to.equal(true)
			expect(onFloor(manhole.x, manhole.z, alley.roam :: { Rect }, 2)).to.equal(true)
			expect(inWall(manhole.x, manhole.z, alleyWalls, 1)).to.equal(false)
			-- Its prompt reaches 8 studs (WorldBuilder): keep it off the arrival point and out of every rescue's
			-- range (12 studs in F27), so one press never offers both.
			local rescueRange = (Config :: any).RescueRangeStuds or 12
			local arrival = alley.arrival :: Point
			expect(math.sqrt((manhole.x - arrival.x) ^ 2 + (manhole.z - arrival.z) ^ 2) > 8).to.equal(true)
			for i, spot in alley.rescueSpots do
				local apart = math.sqrt((manhole.x - spot.x) ^ 2 + (manhole.z - spot.z) ^ 2)
				if apart <= 8 + rescueRange then
					fail("rescue spot %d is %.1f studs from the manhole", i, apart)
				end
			end
		end)

		it("the Alley travel button lands inside the Square, clear of its walls (check 4)", function()
			local arrival = alley.arrival :: Point
			expect(arrival).to.be.ok()
			expect(arrival.z > W.SquareSouthZ and arrival.z < W.SquareNorthZ).to.equal(true)
			expect(onFloor(arrival.x, arrival.z, alleyRects, 2)).to.equal(true)
			expect(inWall(arrival.x, arrival.z, alleyWalls, 1)).to.equal(false)
		end)

		it("is at least 8 times the old 60 x 44 stud box (size target)", function()
			local total = 0
			for _, rect in alleyRects do
				total += math.abs(rect.x2 - rect.x1) * math.abs(rect.z2 - rect.z1)
			end
			expect(total >= 8 * 60 * 44).to.equal(true)
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
	end)

	-- Shortest walks over the Alleyway floor on a 1 stud grid, moving along x or z only, so every distance is at least
	-- the real walk. A cell is walkable when the floor reaches 1 stud past its centre every way (across the seams
	-- where one floor meets the next) and it is 1 stud clear of every wall.
	local GRID_X0 = -W.AlleyOuterX
	local GRID_Z0 = W.AlleySouthZ
	local GRID_NX = math.ceil(2 * W.AlleyOuterX)
	local GRID_NZ = math.ceil(W.SquareNorthZ - W.AlleySouthZ)

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

	local squarePoints: { Point } = {}
	for _, point in alley.spawnPoints do
		if point.zone == "square" then
			table.insert(squarePoints, point)
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

		it("every spawn point can be walked to from every yard gate", function()
			for index = 1, W.PlotCount do
				local _, outX, outZ = yardWalk(index)
				local dist = walkFrom(outX, outZ)
				for n, point in alley.spawnPoints do
					if studsTo(dist, point.x, point.z) == nil then
						fail("plot %d: spawn point %d at (%g, %g) cannot be reached", index, n, point.x, point.z)
					end
				end
			end
		end)

		it("carrying a cat from any Square spawn to any cafe's back door takes under 25 seconds", function()
			-- The check names the farthest cafe's nearer door; the back door is never farther than that, so this bounds
			-- it from above. Travel is greyed while carrying, so this is the one walk that cannot be skipped.
			local worst, worstPlot, worstPoint = 0, 0, 0
			for index = 1, W.PlotCount do
				local yard, outX, outZ = yardWalk(index)
				local dist = walkFrom(outX, outZ)
				for n, point in squarePoints do
					local walked = studsTo(dist, point.x, point.z)
					if walked == nil then
						fail("plot %d cannot reach Square point %d", index, n)
					end
					local seconds = (yard + (walked :: number)) / Config.CarryWalkSpeed
					if seconds > worst then
						worst, worstPlot, worstPoint = seconds, index, n
					end
				end
			end
			expect(#squarePoints).to.equal(8)
			if worst >= 25 then
				fail("plot %d to Square point %d is %.1f s at carry speed", worstPlot, worstPoint, worst)
			end
			-- Layout v2 measures about 21 s here (designer, docs PR #83); a much shorter walk means the grid broke.
			expect(worst > 10).to.equal(true)
		end)
	end)
end
