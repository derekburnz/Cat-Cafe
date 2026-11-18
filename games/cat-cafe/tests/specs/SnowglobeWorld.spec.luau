--!strict
-- server World/SnowglobeWorld: where Snowglobe Village stands, where a trip in lands and where the globe stands in the
-- Town Square (snowglobe-village-spec section 3).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local SnowglobeWorld = require(ServerScriptService.Server.World.SnowglobeWorld) :: any
	local HarvestWorld = require(ServerScriptService.Server.World.HarvestWorld) :: any
	local Layout = require(ServerScriptService.Server.World.Layout) :: any

	local function flat(at: Vector3): number
		local offset = at - SnowglobeWorld.CENTER
		return math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	end

	describe("SnowglobeWorld", function()
		it("stands far from every other area and from Harvest Hollow", function()
			for id, spec in Layout.areas do
				local reach = math.max(spec.halfWidth or 0, spec.halfDepth or 0) + 130
				local apart = Vector3.new(
					(spec.center.x :: number) - SnowglobeWorld.CENTER.X,
					0,
					(spec.center.z :: number) - SnowglobeWorld.CENTER.Z
				)
				if apart.Magnitude <= reach then
					error(
						string.format(
							"Snowglobe Village is %.0f studs from %s",
							apart.Magnitude,
							tostring(id)
						)
					)
				end
			end
			expect((HarvestWorld.CENTER - SnowglobeWorld.CENTER).Magnitude > 400).to.equal(true)
		end)

		it(
			"has the set's 12 snowflakes and 14 stray spots, all inside the barrier ring and over the Floor",
			function()
				expect(SnowglobeWorld.flakeCount).to.equal(12)
				expect(#SnowglobeWorld.flakes).to.equal(12)
				expect(#SnowglobeWorld.spawns).to.equal(14)
				local size = SnowglobeWorld.FLOOR_SIZE
				expect(size.X >= 128 and size.Z >= 128 and size.Y > 0).to.equal(true)
				local all = table.clone(SnowglobeWorld.spawns)
				for _, at in SnowglobeWorld.flakes do
					table.insert(all, at)
				end
				table.insert(all, SnowglobeWorld.nook)
				for _, at in all do
					expect(SnowglobeWorld.inArea(at)).to.equal(true)
					expect(flat(at) < SnowglobeWorld.BARRIER_RADIUS - 2).to.equal(true)
				end
			end
		)

		it("keeps every roam box inside the barrier's inner face", function()
			for _, box in SnowglobeWorld.roamBoxes do
				for _, corner in
					{
						{ box.x1, box.z1 },
						{ box.x1, box.z2 },
						{ box.x2, box.z1 },
						{ box.x2, box.z2 },
					}
				do
					local r = math.sqrt(corner[1] * corner[1] + corner[2] * corner[2])
					expect(r < SnowglobeWorld.BARRIER_RADIUS - 3).to.equal(true)
				end
			end
		end)

		it("lands a trip on the player spawn inside the ring, facing into the village", function()
			local landing = SnowglobeWorld.landingPoint()
			expect(SnowglobeWorld.inArea(landing)).to.equal(true)
			expect(landing.Y > SnowglobeWorld.CENTER.Y).to.equal(true)
			expect(SnowglobeWorld.front(math.pi).Z > 0.99).to.equal(true) -- landing()'s turn
			for _, spot in SnowglobeWorld.spawns do
				expect((spot - landing).Magnitude > 8).to.equal(true) -- no stray spot under the landing
			end
			expect(SnowglobeWorld.inArea(Vector3.new(0, 0, 0))).to.equal(false)
		end)

		it("turns the Gift Stall to face the lamp lane", function()
			local look = SnowglobeWorld.front(SnowglobeWorld.stallYaw)
			expect(look.X > 0.99).to.equal(true)
		end)

		it("puts the globe on Harvest's vaulted arch spot, facing the cannon", function()
			expect(SnowglobeWorld.PORTAL_AT).to.equal(HarvestWorld.ARCH_AT)
			local at = SnowglobeWorld.PORTAL_AT
			local toCannon = (Vector3.new(0, at.Y, 0) - at).Unit
			expect(SnowglobeWorld.front(SnowglobeWorld.portalYaw()):Dot(toCannon) > 0.99).to.equal(
				true
			)
		end)
	end)
end
