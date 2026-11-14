--!strict
-- shared/AreaRares.luau: the wild Mythicals and Secrets out per area (#4227).
return function()
	local AreaRares = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AreaRares")
	)
	-- the cloud tests have no HttpService, so a stand-in decoder for the two shapes the cases use
	local function decodeJson(text: string): unknown
		if text == "good" then
			return { park = { m = 2, s = 1 }, woods = { m = 0, s = 0 } }
		elseif text == "odd" then
			return { park = { m = -3, s = "x" } }
		end
		error("not json")
	end

	describe("AreaRares", function()
		it("counts only wild Mythicals and Secrets, by area", function()
			local counts = AreaRares.count({
				{ area = "park", rarity = "Mythical", wild = true },
				{ area = "park", rarity = "Mythical", wild = true },
				{ area = "park", rarity = "Secret", wild = true },
				{ area = "park", rarity = "Mythical", wild = false },
				{ area = "woods", rarity = "Legendary", wild = true },
				{ area = "alley", rarity = "Secret", wild = true },
			})
			expect(counts.park.m).to.equal(2)
			expect(counts.park.s).to.equal(1)
			expect(counts.alley.m).to.equal(0)
			expect(counts.alley.s).to.equal(1)
			expect(counts.woods).to.equal(nil)
		end)

		it("reads back what the server wrote, and nothing from a bad value", function()
			local counts = AreaRares.decode("good", decodeJson)
			expect(counts.park.m).to.equal(2)
			expect(counts.park.s).to.equal(1)
			expect(counts.woods).to.equal(nil)
			expect(next(AreaRares.decode(nil, decodeJson))).to.equal(nil)
			expect(next(AreaRares.decode("not json", decodeJson))).to.equal(nil)
			expect(next(AreaRares.decode("odd", decodeJson))).to.equal(nil)
		end)

		it("totals the open areas only", function()
			local counts = { park = { m = 2, s = 1 }, snowy = { m = 4, s = 1 } }
			local m, s = AreaRares.totals(counts, { park = true, alley = true })
			expect(m).to.equal(2)
			expect(s).to.equal(1)
		end)
	end)
end
