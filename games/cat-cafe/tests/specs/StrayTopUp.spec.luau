--!strict
-- shared/StrayTopUp.luau (#1159): the daytime floor of live strays per area, by the players who have it open and
-- capped, the 40 to 80 s top-up timer and the far-point preference, and (#1621) the strays kept by each gate.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local StrayTopUp = require(Shared.StrayTopUp)

	describe("StrayTopUp", function()
		it(
			"keeps a floor that grows with the players in the area, never past StrayLiveMax",
			function()
				expect(StrayTopUp.floor(1)).to.equal(Config.StrayFloorBase)
				expect(StrayTopUp.floor(0)).to.equal(Config.StrayFloorBase)
				expect(StrayTopUp.floor(4)).to.equal(
					Config.StrayFloorBase + 3 * Config.StrayFloorPerPlayer
				)
				expect(StrayTopUp.floor(8)).to.equal(
					math.min(Config.StrayLiveMax, Config.StrayFloorBase + 7)
				)
				expect(StrayTopUp.floor(50)).to.equal(Config.StrayLiveMax)
				-- #2794: an area's own floor base
				expect(StrayTopUp.floor(1, 16)).to.equal(math.min(Config.StrayLiveMax, 16))
				expect(StrayTopUp.floor(50, 16)).to.equal(Config.StrayLiveMax)
				-- a lone player keeps at least as many as the long areas' sunrise waves gave (Derek: "low even solo")
				for _, area in Catalog.areas do
					if area.id ~= "alley" then
						expect(StrayTopUp.floor(1, area.floorBase) >= area.waveSize).to.equal(true)
					end
				end
			end
		)

		it("waits 60 to 120 s between top-ups", function()
			expect(StrayTopUp.wait(0)).to.equal(Config.StrayTopUpMinSeconds)
			expect(StrayTopUp.wait(0.5)).to.equal(
				(Config.StrayTopUpMinSeconds + Config.StrayTopUpMaxSeconds) / 2
			)
			expect(StrayTopUp.wait(5)).to.equal(Config.StrayTopUpMaxSeconds)
		end)

		it(
			"prefers far points (deep; not the Alleyway's nooks since #3170), else any free one",
			function()
				local zones: { string? } = { "near", "deep", "lane", "nook", nil }
				expect(StrayTopUp.farPool({ 1, 2, 3, 4, 5 }, zones) :: any).to.deepEqual({ 2 })
				expect(StrayTopUp.farPool({ 1, 3, 4 }, zones) :: any).to.deepEqual({ 1, 3, 4 })
				expect(StrayTopUp.farPool({ 1, 3, 5 }, zones) :: any).to.deepEqual({ 1, 3, 5 })
			end
		)

		it("keeps strays by each gate (#1621, no cats at the start of the Sewer)", function()
			expect(Config.StrayEntryFloor).to.equal(4) -- #2557 (was 3)
			expect(Config.StrayEntryStuds).to.equal(120)
			expect(Config.StrayEntryTopUpSeconds).to.equal(15) -- #2557 (was 20)
			expect(StrayTopUp.nearGate(100, 0, 0, 0)).to.equal(true)
			expect(StrayTopUp.nearGate(120, 0, 0, 0)).to.equal(true)
			expect(StrayTopUp.nearGate(90, 90, 0, 0)).to.equal(false)
			expect(StrayTopUp.entryPool({ 1, 2, 3 }, { [2] = true, [3] = false }) :: any).to.deepEqual({
				2,
			})
			expect(StrayTopUp.entryPool({ 1, 3 }, { [2] = true }) :: any).to.deepEqual({ 1, 3 })
			-- short while fewer than the floor stand by the gate, never past the live cap
			expect(StrayTopUp.entryShort(3, 5)).to.equal(true)
			expect(StrayTopUp.entryShort(4, 5)).to.equal(false)
			expect(StrayTopUp.entryShort(0, Config.StrayLiveMax)).to.equal(false)
			-- the last four placed from a wave (rarest first) are the commonest and go by the gate
			expect(StrayTopUp.waveEntry(8, 11)).to.equal(true)
			expect(StrayTopUp.waveEntry(7, 11)).to.equal(false)
			expect(StrayTopUp.waveEntry(11, 11)).to.equal(true)
			-- #2794: an area's own entry floor
			expect(StrayTopUp.entryShort(5, 10, 6)).to.equal(true)
			expect(StrayTopUp.entryShort(6, 10, 6)).to.equal(false)
			expect(StrayTopUp.waveEntry(11, 16, 6)).to.equal(true)
			expect(StrayTopUp.waveEntry(10, 16, 6)).to.equal(false)
		end)

		it("#2794: the Alleyway and the Park start busy, with a rescue by the camp", function()
			for _, area in Catalog.areas do
				local starting = area.id == "alley" or area.id == "park"
				expect(area.starterRescue == true).to.equal(starting)
				if starting then
					expect(area.floorBase).to.equal(16)
					expect((area.floorBase :: number) > area.waveSize).to.equal(true)
					expect(area.entryFloor).to.equal(6)
					expect(area.rescueMinStuck).to.equal(2)
					expect(StrayTopUp.floor(1, area.floorBase) <= Config.StrayLiveMax).to.equal(
						true
					)
				end
			end
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
					if
						StrayTopUp.nearGate(point.x, point.z, gateX, gateZ)
						and point.zone ~= "rare"
					then
						near += 1
					end
				end
				if near < (area.entryFloor or Config.StrayEntryFloor) * 2 then
					error(string.format("%s has %d spawn points by its gate", area.id, near))
				end
			end
		end)

		it(
			"places a sunrise wave over time: each area's rarest at once, the rest in turn from the gate end (#3661)",
			function()
				local a = { "a1", "a2", "a3", "a4", "a5" }
				local b = { "b1", "b2", "b3" }
				local c = { "c1" }
				local now, later = StrayTopUp.waveOrder({ a, b, c }, 2)
				expect(table.concat(now, " ")).to.equal("a1 a2 b1 b2 c1")
				-- one area after another, each from its last (commonest, by the gate) back
				expect(table.concat(later, " ")).to.equal("a5 b3 a4 a3")
				-- nothing is lost or placed twice, whatever the sizes
				for atOnce = 0, 6 do
					local first, rest = StrayTopUp.waveOrder({ a, b, c, {} }, atOnce)
					local seen: { [string]: number } = {}
					for _, list in { first, rest } do
						for _, name in list do
							seen[name] = (seen[name] or 0) + 1
						end
					end
					for _, wave in { a, b, c } do
						for _, name in wave do
							expect(seen[name]).to.equal(1)
						end
					end
					expect(#first + #rest).to.equal(9)
				end
				local all, none = StrayTopUp.waveOrder({ a }, 5)
				expect(#all).to.equal(5)
				expect(#none).to.equal(0)
				-- the gap: the last one lands WaveSpreadSeconds after sunrise, between a frame and a second apart
				expect(StrayTopUp.waveGap(60, 30)).to.equal(0.5)
				expect(StrayTopUp.waveGap(10, 30)).to.equal(1)
				expect(StrayTopUp.waveGap(100000, 30)).to.equal(1 / 30)
				expect(StrayTopUp.waveGap(0, 30)).to.equal(0)
				-- the real waves: every area shows its Epic or rarer at sunrise, and the rest is in well inside the
				-- shortest top-up wait, so the spread never draws a top-up of its own
				expect(Config.WaveAtOnce >= 1).to.equal(true)
				expect(Config.WaveSpreadSeconds <= Config.StrayTopUpMinSeconds).to.equal(true)
				local laterCount = 0
				for _, areaDef in Catalog.areas do
					laterCount += math.max(0, areaDef.waveSize - Config.WaveAtOnce)
				end
				local gap = StrayTopUp.waveGap(laterCount, Config.WaveSpreadSeconds)
				expect(gap >= 0.2).to.equal(true) -- at most five cat models a second
				-- each area's gate strays (its last entryFloor) are placed inside the gate's own top-up wait
				local turns = Config.StrayEntryFloor * #Catalog.areas
				expect(turns * gap < Config.StrayEntryTopUpSeconds).to.equal(true)
			end
		)
	end)
end
