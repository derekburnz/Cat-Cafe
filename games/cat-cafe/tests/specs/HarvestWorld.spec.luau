--!strict
-- server World/HarvestWorld: where Harvest Hollow stands and where a trip in lands (#4251, harvest-hollow-spec 1 and 2).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local HarvestWorld = require(ServerScriptService.Server.World.HarvestWorld) :: any
	local Layout = require(ServerScriptService.Server.World.Layout) :: any

	describe("HarvestWorld", function()
		it(
			"stands far from every other area, with the set's 12 pumpkins and 14 stray spots",
			function()
				for id, spec in Layout.areas do
					local reach = math.max(spec.halfWidth or 0, spec.halfDepth or 0) + 120 -- the set is 150 x 120
					local apart = Vector3.new(
						(spec.center.x :: number) - HarvestWorld.CENTER.X,
						0,
						(spec.center.z :: number) - HarvestWorld.CENTER.Z
					)
					if apart.Magnitude <= reach then
						error(
							string.format(
								"Harvest Hollow is %.0f studs from %s",
								apart.Magnitude,
								tostring(id)
							)
						)
					end
				end
				expect(HarvestWorld.pumpkinCount).to.equal(12)
				expect(#HarvestWorld.spawns).to.equal(14)
				for _, spot in HarvestWorld.spawns do
					expect(math.abs(spot.X - HarvestWorld.CENTER.X) <= 75).to.equal(true)
					expect(math.abs(spot.Z - HarvestWorld.CENTER.Z) <= 60).to.equal(true)
				end
			end
		)

		it("lands a trip on the player spawn inside the fence, south of the patch", function()
			local landing = HarvestWorld.landingPoint()
			expect(math.abs(landing.X - HarvestWorld.CENTER.X) <= 75).to.equal(true)
			expect(math.abs(landing.Z - HarvestWorld.CENTER.Z) <= 60).to.equal(true)
			expect(landing.Y > HarvestWorld.CENTER.Y).to.equal(true)
			for _, spot in HarvestWorld.spawns do
				expect((spot - landing).Magnitude > 8).to.equal(true) -- no stray spot under the landing
			end
		end)

		it(
			"puts the arch in the Town Square off the street and the lane, clear of its stations",
			function()
				local at = HarvestWorld.ARCH_AT
				local floor = Layout.townSquare.floor
				expect(at.X > floor.x1 + 12 and at.X < floor.x2 - 12).to.equal(true)
				expect(at.Z > floor.z1 + 12 and at.Z < floor.z2 - 12).to.equal(true)
				for _, lane in Layout.townSquare.lanes do
					local inside = at.X > lane.x1 - 12
						and at.X < lane.x2 + 12
						and at.Z > lane.z1 - 12
						and at.Z < lane.z2 + 12
					expect(inside).to.equal(false)
				end
				for _, name in
					{
						"spinWheel",
						"mysticPool",
						"fishMarket",
						"codesCat",
						"dealerCart",
						"bellhopStand",
						"mysteryCart",
						"leaderboards",
						"cornerShop",
					}
				do
					local station = Layout[name]
					if station ~= nil then
						local apart = Vector3.new(station.x - at.X, 0, station.z - at.Z).Magnitude
						if apart < 16 then
							error(string.format("the arch is %.1f studs from %s", apart, name))
						end
					end
				end
			end
		)
	end)
end
