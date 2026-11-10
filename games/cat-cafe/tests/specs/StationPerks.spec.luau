--!strict
-- StationPerks.luau and StationReveal.luau (#2687): each area's camp station brings one lasting perk from its tier, and
-- its reveal plays once per account.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Rescue = require(Shared.Rescue)
	local StationPerks = require(Shared.StationPerks)
	local StationReveal = require(Shared.StationReveal)
	local Tips = require(Shared.Tips)

	describe("StationPerks", function()
		it(
			"has one perk for each tier 2 to 7, in tier order, each named with its station",
			function()
				expect(#StationPerks.LIST).to.equal(6)
				for i, perk in StationPerks.LIST do
					expect(perk.tier).to.equal(i + 1)
					expect(StationPerks.get(perk.id)).to.equal(perk)
					expect(StationPerks.at(perk.tier)).to.equal(perk)
					expect(#perk.name > 0 and #perk.text > 0 and #perk.station > 0).to.equal(true)
				end
				expect(StationPerks.at(1)).to.equal(nil)
				expect(StationPerks.get("nope")).to.equal(nil)
			end
		)

		it("owns a perk from its tier on, never before", function()
			expect(StationPerks.has(1, "fresh_bait")).to.equal(false)
			expect(StationPerks.has(2, "fresh_bait")).to.equal(true)
			expect(StationPerks.has(6, "curator")).to.equal(false)
			expect(StationPerks.has(7, "curator")).to.equal(true)
			expect(StationPerks.has(nil, "fresh_bait")).to.equal(false)
			expect(#StationPerks.owned(1)).to.equal(0)
			expect(#StationPerks.owned(4)).to.equal(3)
			expect(#StationPerks.owned(7)).to.equal(6)
			expect((StationPerks.nextAfter(4) :: any).id).to.equal("homing_bell")
			expect(StationPerks.nextAfter(7)).to.equal(nil)
		end)

		it("gives each perk's number only from its tier", function()
			expect(StationPerks.baitSpeed(1)).to.equal(0)
			expect(StationPerks.baitSpeed(2)).to.equal(0.10)
			expect(StationPerks.sellValue(100, 2)).to.equal(100)
			expect(StationPerks.sellValue(100, 3)).to.equal(110)
			expect(StationPerks.sellValue(25, 3)).to.equal(28) -- 27.5 rounds to a whole coin
			expect(StationPerks.firstCatchFish(3)).to.equal(0)
			expect(StationPerks.firstCatchFish(4)).to.equal(1)
			expect(StationPerks.homingSpeed(4)).to.equal(1)
			expect(StationPerks.homingSpeed(5)).to.equal(2)
			expect(StationPerks.rescueZoneScale(5)).to.equal(1)
			expect(StationPerks.rescueZoneScale(6)).to.equal(1.10)
			expect(StationPerks.tipMultiplier(6)).to.equal(1)
			expect(StationPerks.tipMultiplier(7)).to.equal(1.05)
		end)

		it(
			"Warm Paws widens a rescue's zones, and the client reads the width from the challenge",
			function()
				local function roll(): number
					return 0.5
				end
				local plain = Rescue.newChallenge("Rare", "trash_bin", 100, roll)
				local wide = Rescue.newChallenge(
					"Rare",
					"trash_bin",
					100,
					roll,
					StationPerks.rescueZoneScale(6)
				)
				expect(plain.zoneWidth).to.equal(Config.RescueZoneWidth.Rare)
				expect(
					math.abs((wide.zoneWidth :: number) - Config.RescueZoneWidth.Rare * 1.10) < 1e-9
				).to.equal(true)
			end
		)
	end)

	describe("StationReveal", function()
		it("has a key for each area whose tier brings a perk, and none for the Alley", function()
			for _, def in Catalog.tiers do
				local area = (def :: any).area
				if type(area) == "string" then
					expect(StationReveal.isKey(StationReveal.key(area))).to.equal(def.tier >= 2)
				end
			end
			expect(StationReveal.isKey("reveal_moon")).to.equal(false)
			expect(StationReveal.isKey("park")).to.equal(false)
		end)

		it("is due once the area's tier is owned, until it is seen", function()
			local park = (Catalog.getTier(2) :: any).area
			expect((StationReveal.due(2, {}, park) :: any).id).to.equal("fresh_bait")
			expect(StationReveal.due(1, {}, park)).to.equal(nil)
			expect(StationReveal.due(2, { [StationReveal.key(park)] = true }, park)).to.equal(nil)
			expect(StationReveal.due(7, nil, park) ~= nil).to.equal(true)
			expect(StationReveal.due(7, {}, nil)).to.equal(nil)
			expect(StationReveal.due(7, {}, "alley")).to.equal(nil)
		end)

		it("rides tipsSeen: Tips takes the keys and a saved one survives a load", function()
			local key = StationReveal.key((Catalog.getTier(3) :: any).area)
			expect(Tips.seenId(key)).to.equal(true)
			expect(Tips.seenId("reveal_moon")).to.equal(false)
			local seen = Tips.sanitizeSeen({ [key] = true, reveal_moon = true }, false)
			expect(seen[key]).to.equal(true)
			expect(seen.reveal_moon).to.equal(nil)
		end)
	end)
end
