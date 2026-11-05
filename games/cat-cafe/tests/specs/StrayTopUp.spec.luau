--!strict
-- shared/StrayTopUp.luau (#1159): the daytime floor of live strays per area, by the players who have it open and
-- capped, the 40 to 80 s top-up timer and the far-point preference, and (#1621) the strays kept by each gate.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local StrayTopUp = require(Shared.StrayTopUp)

	describe("StrayTopUp", function()
		it("keeps a floor that grows with the players in the area, never past StrayLiveMax", function()
			expect(StrayTopUp.floor(1)).to.equal(Config.StrayFloorBase)
			expect(StrayTopUp.floor(0)).to.equal(Config.StrayFloorBase)
			expect(StrayTopUp.floor(4)).to.equal(Config.StrayFloorBase + 3 * Config.StrayFloorPerPlayer)
			expect(StrayTopUp.floor(8)).to.equal(math.min(Config.StrayLiveMax, Config.StrayFloorBase + 7))
			expect(StrayTopUp.floor(50)).to.equal(Config.StrayLiveMax)
			-- a lone player keeps at least as many as the long areas' sunrise waves gave (Derek: "low even solo")
			for _, area in Catalog.areas do
				if area.id ~= "alley" then
					expect(StrayTopUp.floor(1) >= area.waveSize).to.equal(true)
				end
			end
		end)

		it("waits 60 to 120 s between top-ups", function()
			expect(StrayTopUp.wait(0)).to.equal(Config.StrayTopUpMinSeconds)
			expect(StrayTopUp.wait(0.5)).to.equal((Config.StrayTopUpMinSeconds + Config.StrayTopUpMaxSeconds) / 2)
			expect(StrayTopUp.wait(5)).to.equal(Config.StrayTopUpMaxSeconds)
		end)

		it("prefers far points (deep, nook), else any free one", function()
			local zones: { string? } = { "near", "deep", "lane", "nook", nil }
			expect(StrayTopUp.farPool({ 1, 2, 3, 4, 5 }, zones) :: any).to.deepEqual({ 2, 4 })
			expect(StrayTopUp.farPool({ 1, 3, 5 }, zones) :: any).to.deepEqual({ 1, 3, 5 })
		end)

		it("keeps strays by each gate (#1621, no cats at the start of the Sewer)", function()
			expect(Config.StrayEntryFloor).to.equal(3)
			expect(Config.StrayEntryStuds).to.equal(120)
			expect(Config.StrayEntryTopUpSeconds).to.equal(20)
			expect(StrayTopUp.nearGate(100, 0, 0, 0)).to.equal(true)
			expect(StrayTopUp.nearGate(120, 0, 0, 0)).to.equal(true)
			expect(StrayTopUp.nearGate(90, 90, 0, 0)).to.equal(false)
			expect(StrayTopUp.entryPool({ 1, 2, 3 }, { [2] = true, [3] = false }) :: any).to.deepEqual({ 2 })
			expect(StrayTopUp.entryPool({ 1, 3 }, { [2] = true }) :: any).to.deepEqual({ 1, 3 })
			-- short while fewer than the floor stand by the gate, never past the live cap
			expect(StrayTopUp.entryShort(2, 5)).to.equal(true)
			expect(StrayTopUp.entryShort(3, 5)).to.equal(false)
			expect(StrayTopUp.entryShort(0, Config.StrayLiveMax)).to.equal(false)
			-- the last three placed from a wave (rarest first) are the commonest and go by the gate
			expect(StrayTopUp.waveEntry(6, 8)).to.equal(true)
			expect(StrayTopUp.waveEntry(5, 8)).to.equal(false)
			expect(StrayTopUp.waveEntry(8, 8)).to.equal(true)
		end)

		it("has room by every gate for the floor (#1621)", function()
			local ServerScriptService = game:GetService("ServerScriptService")
			local Layout = require(ServerScriptService.Server.World.Layout) :: any
			for _, area in Catalog.areas do
				local spec = Layout.areas[area.id]
				local gateX, gateZ = Layout.gatePosition(spec)
				if gateX == nil then
					continue -- the Alleyway has no gate
				end
				local near = 0
				for _, point in spec.spawnPoints do
					if StrayTopUp.nearGate(point.x, point.z, gateX, gateZ) and point.zone ~= "rare" then
						near += 1
					end
				end
				if near < Config.StrayEntryFloor * 2 then
					error(string.format("%s has %d spawn points by its gate", area.id, near))
				end
			end
		end)
	end)
end
