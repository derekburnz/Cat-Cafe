--!strict
-- UI/Components/CrateReelLogic.luau: the crate reel's timing, position and strip (F103, crate-reel.md section 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CrateReelLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CrateReelLogic")
	) :: any

	local CONFIG = {
		CrateReelTiles = 40,
		CrateReelLandingTile = 34,
		CrateReelProtectFrom = 26,
		CrateReelProtectTo = 37,
		CrateReelTopSpeed = 15,
		CrateReelRampSeconds = 0.3,
		CrateReelStopSeconds = 0.8,
		CrateReelHoldSeconds = 0.25,
	}
	local RANK: { [string]: number } =
		{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }
	local PIECES = {
		{ id = "m", rarity = "Mythical", percent = 0.5 },
		{ id = "l", rarity = "Legendary", percent = 2 },
		{ id = "e", rarity = "Epic", percent = 7.5 },
		{ id = "r1", rarity = "Rare", percent = 12.5 },
		{ id = "r2", rarity = "Rare", percent = 12.5 },
		{ id = "c1", rarity = "Common", percent = 32.5 },
		{ id = "c2", rarity = "Common", percent = 32.5 },
	}

	describe("CrateReelLogic.timing", function()
		it("stops at the same time every time, about 2.9 s, as the counter crate's lid", function()
			local timing = CrateReelLogic.timing(CONFIG)
			expect(timing.stop).to.be.near(2.8833, 0.001)
			expect(timing.slowFrom).to.be.near(2.0833, 0.001)
			expect(timing.slowTiles).to.be.near(4, 1e-9)
			expect(timing.hold).to.equal(0.25)
		end)

		it("waits for Config's numbers", function()
			expect(CrateReelLogic.timing({})).to.equal(nil)
			expect(CrateReelLogic.timing({ CrateReelTiles = 40 })).to.equal(nil)
		end)
	end)

	describe("CrateReelLogic.position", function()
		it("starts on tile 1 and stops dead centre on the landing tile", function()
			local timing = CrateReelLogic.timing(CONFIG)
			expect(CrateReelLogic.position(0, timing)).to.equal(1)
			expect(CrateReelLogic.position(timing.stop, timing)).to.equal(34)
			expect(CrateReelLogic.position(timing.stop + 5, timing)).to.equal(34)
			expect(CrateReelLogic.position(timing.stop - 1e-4, timing)).to.be.near(34, 1e-3)
		end)

		it("never runs backwards and joins up at each part", function()
			local timing = CrateReelLogic.timing(CONFIG)
			local last = 1
			for step = 1, 600 do
				local at = CrateReelLogic.position(step * timing.stop / 600, timing)
				expect(at >= last - 1e-9).to.equal(true)
				expect(at - last < 0.1).to.equal(true) -- no jump bigger than a 1/200 s step at 15 tiles a second
				last = at
			end
			expect(CrateReelLogic.position(timing.ramp, timing)).to.be.near(1 + 2.25, 1e-6)
			expect(CrateReelLogic.position(timing.slowFrom, timing)).to.be.near(30, 1e-6)
		end)

		it("counts the tile lines that pass the marker", function()
			expect(CrateReelLogic.crossed(1, 1.4)).to.equal(0)
			expect(CrateReelLogic.crossed(1, 1.6)).to.equal(1)
			expect(CrateReelLogic.crossed(1, 34)).to.equal(33)
			expect(CrateReelLogic.crossed(5, 4)).to.equal(0)
		end)
	end)

	describe("CrateReelLogic.strip", function()
		it(
			"puts the prize on tile 34 and nothing rarer on tiles 26 to 37, over 10,000 builds",
			function()
				local timing = CrateReelLogic.timing(CONFIG)
				local rng = Random.new(7)
				local wins = {
					{ id = "c1", rarity = "Common" },
					{ id = "r2", rarity = "Rare" },
					{ id = "e", rarity = "Epic" },
					{ id = "m", rarity = "Mythical" },
				}
				local bad = 0
				for build = 1, 10000 do
					local won = wins[(build - 1) % #wins + 1]
					local tiles = CrateReelLogic.strip(PIECES, won, rng, timing)
					expect(#tiles).to.equal(40)
					if tiles[34].id ~= won.id then
						bad += 1
					end
					for index = 26, 37 do
						if RANK[tiles[index].rarity] > RANK[won.rarity] then
							bad += 1
						end
					end
				end
				expect(bad).to.equal(0)
			end
		)

		it("draws the open tiles from the crate's own chances", function()
			local timing = CrateReelLogic.timing(CONFIG)
			local rng = Random.new(11)
			local counts: { [string]: number } = {}
			local total = 0
			for _ = 1, 2000 do
				local tiles =
					CrateReelLogic.strip(PIECES, { id = "m", rarity = "Mythical" }, rng, timing)
				for index = 1, 25 do
					local rarity = tiles[index].rarity
					counts[rarity] = (counts[rarity] or 0) + 1
					total += 1
				end
			end
			expect(counts.Common / total).to.be.near(0.65, 0.02)
			expect(counts.Rare / total).to.be.near(0.25, 0.02)
			expect(counts.Epic / total).to.be.near(0.075, 0.01)
		end)

		it("fills with the prize when the crate lists no pieces", function()
			local timing = CrateReelLogic.timing(CONFIG)
			local tiles = CrateReelLogic.strip(
				{},
				{ id = "x", rarity = "Epic" },
				Random.new(1),
				timing
			)
			expect(tiles[1].id).to.equal("x")
			expect(tiles[40].id).to.equal("x")
		end)
	end)
end
