--!strict
-- #5665 part 2: Snowglobe Village's rules (snowglobe-village-spec sections 1 and 3), on Harvest Hollow's numbers.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Advent = require(Shared:WaitForChild("Advent")) :: any
	local HarvestSave = require(Shared:WaitForChild("HarvestSave")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema")) :: any
	local SnowglobeSave = require(Shared:WaitForChild("SnowglobeSave")) :: any

	local OPEN = Advent.FIRST_OPEN + 3600

	describe("Snowglobe Village rules", function()
		it(
			"opens Dec 1 20:00 UTC to the end of Jan 3, from Tier 2, only with christmasEvent on",
			function()
				expect(SnowglobeSave.FLAG).to.equal("christmasEvent")
				expect(LiveFlags.defaults().christmasEvent).to.equal(false)
				expect(SnowglobeSave.areaBlocker(OPEN, 2, true)).to.equal(nil)
				expect(SnowglobeSave.areaBlocker(OPEN, 2, false)).to.equal(
					"Snowglobe Village is closed"
				)
				expect(SnowglobeSave.areaBlocker(Advent.FIRST_OPEN - 1, 5, true)).to.equal(
					"Snowglobe Village opens on Dec 1"
				)
				expect(SnowglobeSave.areaBlocker(Advent.FIRST_OPEN, 2, true)).to.equal(nil)
				expect(SnowglobeSave.areaBlocker(Advent.CLOSES, 5, true)).to.equal(
					"Snowglobe Village is closed until next Christmas"
				)
				expect(SnowglobeSave.areaBlocker(OPEN, 1, true)).to.equal(
					"Snowglobe Village opens at Tier 2"
				)
				expect(SnowglobeSave.open(Advent.CLOSES - 1)).to.equal(true)
				expect(SnowglobeSave.open(Advent.CLOSES)).to.equal(false)
			end
		)

		it("gives the first visit of each UTC day 40 Snowflakes, once", function()
			local save = SnowglobeSave.fresh()
			local flakes, added = SnowglobeSave.visit(save, nil, OPEN)
			expect(added).to.equal(40)
			expect(flakes).to.equal(40)
			flakes, added = SnowglobeSave.visit(save, flakes, OPEN + 60)
			expect(added).to.equal(0)
			expect(flakes).to.equal(40)
			flakes, added = SnowglobeSave.visit(save, flakes, OPEN + 86400)
			expect(added).to.equal(40)
			expect(flakes).to.equal(80)
		end)

		it("pays catches, regrows and spawns on Harvest's numbers", function()
			for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
				expect(SnowglobeSave.catchFlakes(rarity)).to.equal(
					HarvestSave.catchPumpkins(rarity)
				)
			end
			expect(SnowglobeSave.catchFlakes("Mythical")).to.equal(10)
			expect(SnowglobeSave.regrowSeconds(1)).to.equal(300)
			expect(SnowglobeSave.regrowSeconds(6)).to.equal(150)
			expect(SnowglobeSave.ODDS).to.equal(HarvestSave.ODDS)
			expect(SnowglobeSave.STRAY_CAP).to.equal(10)
		end)

		it("caps Snowflakes and never takes any away", function()
			local after, added = SnowglobeSave.give(SnowglobeSave.MAX_FLAKES - 1, 5)
			expect(after).to.equal(SnowglobeSave.MAX_FLAKES)
			expect(added).to.equal(1)
			after, added = SnowglobeSave.give(7, -3)
			expect(after).to.equal(7)
			expect(added).to.equal(0)
		end)

		it("keeps the visit day through a save and drops junk", function()
			expect(SnowglobeSave.sanitize({ visitDay = 20788.6 }).visitDay).to.equal(20788)
			expect(SnowglobeSave.sanitize({ visitDay = "x" }).visitDay).to.equal(nil)
			expect(SnowglobeSave.sanitize({ visitDay = -1 }).visitDay).to.equal(nil)
			expect(SnowglobeSave.sanitize(5).visitDay).to.equal(nil)
			local profile = ProfileSchema.migrate({ snowglobe = { visitDay = 20790 } }, OPEN)
			expect(profile.snowglobe.visitDay).to.equal(20790)
			expect(ProfileSchema.migrate({}, OPEN).snowglobe).to.equal(nil)
		end)
	end)
end
