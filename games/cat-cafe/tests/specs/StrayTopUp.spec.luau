--!strict
-- shared/StrayTopUp.luau (#1159): the daytime floor of live strays per area, by the players who have it open and
-- capped, the 60 to 120 s top-up timer and the far-point preference.
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
	end)
end
