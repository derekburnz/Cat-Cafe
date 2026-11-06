--!strict
-- shared/Pity against luck-and-rare-moments.md 1h (#1572): the global slots, the night rule, the seeded pick and the
-- banner texts.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local Pity = require(Shared.Pity)

	local every = Config.PityLegendarySeconds

	describe("slots", function()
		it("runs a slot every PityLegendarySeconds, every 4th a Mythical one", function()
			expect(every).to.equal(1800)
			expect(Config.PityMythicalEvery).to.equal(4)
			expect(Pity.slot(0)).to.equal(0)
			expect(Pity.slot(every - 1)).to.equal(0)
			expect(Pity.slot(every)).to.equal(1)
			expect(Pity.slot(-50)).to.equal(0)
			expect(Pity.kindOf(1)).to.equal("Legendary")
			expect(Pity.kindOf(3)).to.equal("Legendary")
			expect(Pity.kindOf(4)).to.equal("Mythical")
			expect(Pity.kindOf(8)).to.equal("Mythical")
		end)

		it("moves a slot due at night to the next sunrise (QA 4)", function()
			local movedOne = false
			for slot = 1, 400 do
				local due = Pity.dueAt(slot)
				local phase, left = Clock.phaseAt(due)
				if phase == "night" then
					movedOne = true
					expect(Pity.spawnAt(slot)).to.equal(due + left)
					expect((Clock.phaseAt(Pity.spawnAt(slot)))).to.equal("day")
				else
					expect(Pity.spawnAt(slot)).to.equal(due)
				end
			end
			expect(movedOne).to.equal(true)
		end)

		it(
			"counts down to the next Legendary within 30 min and the next Mythical within 2 h",
			function()
				for t = 0, 20000, 137 do
					local at, slot = Pity.nextAt(t, "Legendary")
					expect(at > t).to.equal(true)
					expect(Pity.kindOf(slot)).to.equal("Legendary")
					expect(at - t <= 2 * every + Config.NightLengthSeconds).to.equal(true)
					local mAt, mSlot = Pity.nextAt(t, "Mythical")
					expect(mAt > t).to.equal(true)
					expect(Pity.kindOf(mSlot)).to.equal("Mythical")
					expect(mAt - t <= 4 * every + Config.NightLengthSeconds).to.equal(true)
					local anyAt = Pity.nextAt(t)
					expect(anyAt).to.equal(math.min(at, mAt))
				end
			end
		)

		it("keeps a slot's cat out from its spawn until night", function()
			local slot = 5
			local at = Pity.spawnAt(slot)
			expect(Pity.live(at)).to.equal(slot)
			expect(Pity.live(at - 1)).never.to.equal(slot)
			local _, left = Clock.phaseAt(at)
			expect(Pity.live(at + left - 1)).to.equal(slot)
			expect(Pity.live(at + left + 1)).to.equal(nil) -- night
			expect(Pity.live(at + left + Config.NightLengthSeconds + 5)).to.equal(nil) -- the next day
			expect(Pity.live(10)).to.equal(nil) -- before the first slot
		end)
	end)

	describe("pick", function()
		it(
			"is the same for a slot every time, with a cat of the slot's rarity from its area",
			function()
				for slot = 1, 200 do
					local a, b = Pity.pick(slot), Pity.pick(slot)
					expect(a.areaId).to.equal(b.areaId)
					expect(a.catId).to.equal(b.catId)
					expect(a.kind).to.equal(Pity.kindOf(slot))
					local def = Catalog.getCat(a.catId)
					expect(def).to.be.ok()
					if def ~= nil then
						expect(def.rarity).to.equal(a.kind)
						expect(def.area).to.equal(a.areaId)
					end
				end
			end
		)

		it("lands on the areas within 1 point of the weights over 10,000 slots (QA 3)", function()
			local total = 0
			for _, weight in Config.PityAreaWeights do
				total += weight
			end
			local counts: { [string]: number } = {}
			local n = 10000
			for slot = 1, n do
				local area = Pity.pick(slot).areaId
				counts[area] = (counts[area] or 0) + 1
			end
			for areaId, weight in Config.PityAreaWeights do
				expect(Catalog.getArea(areaId)).to.be.ok()
				local share = 100 * (counts[areaId] or 0) / n
				expect(math.abs(share - 100 * weight / total) <= 1).to.equal(true)
			end
		end)

		it("maps a roll onto the weights in area order", function()
			expect(Pity.areaFor(0)).to.equal("alley")
			expect(Pity.areaFor(0.099)).to.equal("alley")
			expect(Pity.areaFor(0.1)).to.equal("park")
			expect(Pity.areaFor(0.999)).to.equal("sewer")
		end)
	end)

	describe("texts", function()
		it("names the area, with the tier for a player who has not opened it", function()
			expect(Pity.spawnText("Legendary", "woods")).to.equal(
				"A Legendary pity cat appeared in the Woods!"
			)
			expect(Pity.spawnText("Mythical", "woods", 4)).to.equal(
				"A Mythical pity cat appeared in the Woods! (opens at Tier 4)"
			)
			expect(Pity.caughtText("Sam")).to.equal("Sam caught the pity cat!")
			expect(Pity.claimKey(12)).to.equal("pity:12")
		end)

		it("writes the sign's countdowns", function()
			expect(Pity.countdownText(750)).to.equal("12:30")
			expect(Pity.countdownText(6130)).to.equal("1:42:10")
			expect(Pity.countdownText(0.2)).to.equal("0:01")
			expect(Pity.countdownText(-3)).to.equal("0:00")
		end)
	end)
end
