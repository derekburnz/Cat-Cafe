--!strict
-- Effects/AreaWater and Effects/BulbChase (#4070, #4071): the new areas' water pieces are found by name and the
-- fairground's bulbs chase in order. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local AreaWater = require(Effects:WaitForChild("AreaWater")) :: any
	local BulbChase = require(Effects:WaitForChild("BulbChase")) :: any

	local UP = Vector3.new(0, 1, 0) -- standing as built
	local ON_SIDE = Vector3.new(1, 0, 0) -- a disc: its X axis points up

	describe("Effects area water", function()
		it("finds each water piece by its name, whatever its number", function()
			local function piece(name: string): string?
				local kind = AreaWater.kindOf(name)
				return if kind ~= nil then kind.piece else nil
			end
			expect(piece("CatCafe_WaterPark_Set_159_LazyRiver_Water")).to.equal("LazyRiver")
			expect(piece("CatCafe_WaterPark_Set_7_WavePool_Water")).to.equal("WavePool")
			expect(piece("CatCafe_WaterPark_Set_163_SplashPad_Water")).to.equal("SplashPad")
			expect(piece("CatCafe_WaterPark_Set_199_SmallSlideTower_Water")).to.equal("SlideTower")
			expect(piece("CatCafe_WaterPark_Set_201_KidsPool_Water")).to.equal("KidsPool")
			expect(piece("CatCafe_Castle_Set_044_Moat_Water")).to.equal("Moat")
			expect(piece("CatCafe_Camp_Castle_012_Well_Water")).to.equal("Well")
			-- not water, not ours, or a piece with no kind
			expect(piece("CatCafe_WaterPark_Set_162_WavePool_Pane")).to.equal(nil)
			expect(piece("CatCafe_Ruins_Set_089_Fountain_Water")).to.equal(nil)
			expect(piece("CatCafe_WaterPark_Set_001_Puddle_Water")).to.equal(nil)
			expect(piece("_Water")).to.equal(nil)
		end)

		it("gives every kind emitters that exist and a ring only with its size", function()
			for _, kind in Presets.areaWater.kinds do
				local any = false
				for _, name in { kind.glint, kind.flow, kind.spray, kind.mist } do
					expect(Presets.emitters[name]).to.be.ok()
					any = true
				end
				expect(any).to.equal(true)
				expect(kind.parts >= 1).to.equal(true)
				expect((kind.ringEvery == nil) == (kind.ring == nil)).to.equal(true)
				if kind.ringEvery ~= nil then
					expect(kind.ringEvery >= 1).to.equal(true) -- never a flash faster than once a second
				end
			end
		end)

		it("lays a thin sheet over a slab and a smaller one inside a disc", function()
			expect(AreaWater.upAxis(UP)).to.equal(2)
			expect(AreaWater.upAxis(ON_SIDE)).to.equal(1)
			expect(AreaWater.upAxis(Vector3.new(0, 0.1, -1))).to.equal(3)
			local slab = AreaWater.sheet(UP, Vector3.new(27.9, 0.75, 21.9), false, 0.05)
			expect(slab).to.equal(Vector3.new(27.9, 0.05, 21.9))
			local disc = AreaWater.sheet(ON_SIDE, Vector3.new(0.34, 12.6, 12.6), true, 0.05)
			expect(disc.X).to.equal(0.05)
			expect(disc.Y).to.be.near(12.6 * Presets.areaWater.inner, 1e-4)
			expect(disc.Z).to.be.near(12.6 * Presets.areaWater.inner, 1e-4)
		end)

		it("takes flat parts as water and leaves jets and tipped pieces", function()
			expect(AreaWater.isFlat(UP, Vector3.new(7.4758, 0.412, 8))).to.equal(true)
			expect(AreaWater.isFlat(ON_SIDE, Vector3.new(0.5, 3.9, 3.9))).to.equal(true)
			-- a jet's column stands 2 studs tall and 0.32 across
			expect(AreaWater.isFlat(ON_SIDE, Vector3.new(2, 0.32, 0.32))).to.equal(false)
			expect(AreaWater.isFlat(UP, Vector3.new(0.68, 0.68, 0.68))).to.equal(false)
			expect(AreaWater.halfHeight(ON_SIDE, Vector3.new(0.34, 12.6, 12.6))).to.be.near(
				0.17,
				1e-4
			)
		end)

		it("sends the river the same way round at every part", function()
			local centre = Vector3.new(0, 0, 100)
			-- east of the middle the water goes -Z (counterclockwise from above), west of it +Z
			expect(AreaWater.withFlow(Vector3.new(40, 0, 100), centre, Vector3.new(0, 0, -1))).to.equal(
				true
			)
			expect(AreaWater.withFlow(Vector3.new(40, 0, 100), centre, Vector3.new(0, 0, 1))).to.equal(
				false
			)
			expect(AreaWater.withFlow(Vector3.new(-40, 0, 100), centre, Vector3.new(0, 0, 1))).to.equal(
				true
			)
		end)
	end)

	describe("Effects bulb chase", function()
		it("takes the fairground's rows and no other bulbs", function()
			expect(BulbChase.isRow("CatCafe_WaterPark_Set_012_Booth_Bulbs")).to.equal(true)
			expect(BulbChase.isRow("CatCafe_WaterPark_Set_090_WallHedge_Bulbs")).to.equal(true)
			expect(BulbChase.isRow("CatCafe_Camp_WaterPark_003_TicketFront_Bulbs")).to.equal(true)
			expect(BulbChase.isRow("CatCafe_Square_RallyBoard_Bulbs")).to.equal(false)
			expect(BulbChase.isRow("CatCafe_WaterPark_Backdrop_Bulbs")).to.equal(false)
			expect(BulbChase.isRow("Bulbs")).to.equal(false)
		end)

		it("orders a row along its line and a frame round its middle", function()
			local row = BulbChase.order({
				Vector3.new(6, 3, 0.1),
				Vector3.new(0, 3, 0),
				Vector3.new(4, 3.1, 0),
				Vector3.new(2, 3, 0.1),
			})
			expect(row).to.deepEqual({ 2, 4, 3, 1 })
			-- four corners of a frame in the X Y plane, given out of order
			local frame = BulbChase.order({
				Vector3.new(2, 2, 0),
				Vector3.new(-2, -2, 0),
				Vector3.new(2, -2, 0),
				Vector3.new(-2, 2, 0),
			})
			expect(frame).to.deepEqual({ 2, 3, 1, 4 })
			expect(#BulbChase.order({})).to.equal(0)
			expect(BulbChase.order({ Vector3.new(1, 1, 1) })).to.deepEqual({ 1 })
		end)

		it("steps the lit bulbs along, each lit under once a second", function()
			local c = Presets.bulbChase
			expect(BulbChase.covers(14)).to.equal(math.floor(14 / c.gap))
			expect(BulbChase.covers(2)).to.equal(0)
			local count = 15
			local seen: { [number]: boolean } = {}
			for k = 1, BulbChase.covers(count) do
				local at = BulbChase.lit(k, 0, count)
				expect(seen[at]).never.to.be.ok()
				seen[at] = true
				-- one step on, it is on the next bulb, round the end
				expect(BulbChase.lit(k, 1, count)).to.equal(at % count + 1)
			end
			-- a bulb lights once every gap / hz seconds
			expect(c.gap / c.hz >= 1).to.equal(true)
			expect(c.mostLite <= c.most).to.equal(true)
		end)
	end)
end
