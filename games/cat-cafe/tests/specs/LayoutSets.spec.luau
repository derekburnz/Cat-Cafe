--!strict
-- The world layout, second half (split from Layout.spec so the strict type check can finish both): the cafe
-- interior, the Town Square set, cat beds, cats making orders, camp extras, rescue spot pools, hidden nooks and
-- area set barriers. Same helpers as Layout.spec.
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
				expect(#plot.beds).to.equal(14) -- #2651: four more for Tier 7 and its extra slots; #4070: Tier 9's two
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
					-- 28 studs: twice the reach the spots were fitted with (14). #3448 took the reach to 18 with the
					-- bigger rings; the rings themselves are kept apart by WalkUp.apart
					expect(apart(x, z, bx, bz) > 28).to.equal(true)
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
			"stands the Rummage Bin in the Alleyway camp beside the way out, 12 studs from every other prompt (#3050, #3458)",
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
				-- in plain view of the landing pad: level with it and within 28 studs (#3458: 15 before the bin moved
				-- out of the entrance), but past its landing spots
				local pad = Layout.landingPads.alley.centre
				local toPad = far(x, z, pad.x, pad.z)
				expect(toPad <= 28).to.equal(true)
				expect(toPad > W.LandingPadRadius + 3).to.equal(true)
				-- #3458: outside the width of the camp's way out, so it is off every walk from the pad to the arch,
				-- on the side away from the basket and the Index Board
				local lx = Layout.campLocal(camp, x, z)
				expect(lx > camp.openingHalfWidth + 4).to.equal(true)
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
				expect(nook.asset).to.equal("CatCafe_Nook_" .. Catalog.areaArt(id)) -- #4070: WaterPark
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

		it("names the piece a dropped barrier stood in for, so its body can collide", function()
			expect(Layout.barrierPiece("CatCafe_Ruins_Set_087_GlyphHalls_Barrier")).to.equal(
				"CatCafe_Ruins_Set_087_GlyphHalls"
			)
			expect(Layout.barrierPiece("CatCafe_Ruins_Set_068_Walls_Barrier")).never.to.be.ok()
			expect(Layout.barrierPiece("CatCafe_Ruins_Set_087_GlyphHalls")).never.to.be.ok()
		end)

		it(
			"makes solid bodies collide and leaves glow, glass, water and flat trim walk-over",
			function()
				expect(Layout.bodyCollides(0, "SmoothPlastic", 8)).to.equal(true)
				expect(Layout.bodyCollides(0, "SmoothPlastic", 0.4)).to.equal(false)
				expect(Layout.bodyCollides(0, "Neon", 8)).to.equal(false)
				expect(Layout.bodyCollides(0, "Glass", 8)).to.equal(false)
				expect(Layout.bodyCollides(0.6, "SmoothPlastic", 8)).to.equal(false)
			end
		)

		it("leaves everything that is not a barrier, the climb ramps too", function()
			expect(Layout.keepsBarrier("CatCafe_Woods_SetF85_162_Treehouse_Climb")).to.equal(true)
			expect(Layout.keepsBarrier("CatCafe_Ruins_Set")).to.equal(true)
			expect(Layout.keepsBarrier("BarrierPost")).to.equal(true)
		end)
	end)
end
