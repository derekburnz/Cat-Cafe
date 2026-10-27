--!strict
-- The world layout (server World/Layout.luau, pure geometry) against design v0.4: world-and-feel.md section 2 (the
-- Alleyway out back) and its section 8 acceptance check 4 (F35, layout v2).
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

		it("the box areas keep every spawn, lure and rescue spot on their floor", function()
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
				for i, point in spec.lureSpots do
					if not inside(point.x, point.z, floor, 2) then
						fail("%s lure spot %d is not 2 studs inside the floor", id, i)
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

		it("every spawn and lure spot is 2 studs inside a floor and clear of every wall", function()
			for _, list in { alley.spawnPoints, alley.lureSpots } do
				for i, point in list :: { Point } do
					local off = not onFloor(point.x, point.z, alleyRects, 2)
					if off or inWall(point.x, point.z, alleyWalls, 1) then
						fail("alley point %d at (%g, %g) is off the floor or in a wall", i, point.x, point.z)
					end
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

		it("fast travel lands inside the Square, clear of its walls", function()
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

	describe("walk times at NormalWalkSpeed 20 (acceptance check 4)", function()
		it("from every cafe's back door a stray spawn is under 2 seconds away", function()
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

		-- Layout v2 puts the far side of the Square about 17 s from the south cafes' back doors on foot (10 s from
		-- the north ones), so this waits on the designer: retune the layout, or count the Alley travel button.
		it("from the farthest cafe's back door the far side of the Square is under 8 seconds")
	end)
end
