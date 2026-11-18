--!strict
-- #5284 shared/CompanionScene: when the Cat Companion scene plays, which cat it picks, and its tipsSeen key.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local CompanionScene = require(Shared:WaitForChild("CompanionScene")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local Tips = require(Shared:WaitForChild("Tips")) :: any

	local function catOf(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end

	describe("CompanionScene", function()
		it("plays once, at Tier 2 alone, with both switches on", function()
			expect(CompanionScene.due(2, {}, true, true)).to.equal(true)
			expect(CompanionScene.due(2, nil, true, true)).to.equal(true)
			expect(CompanionScene.due(3, {}, true, true)).to.equal(false)
			expect(CompanionScene.due(1, {}, true, true)).to.equal(false)
			expect(CompanionScene.due(2, {}, false, true)).to.equal(false)
			expect(CompanionScene.due(2, {}, true, false)).to.equal(false)
			expect(CompanionScene.due(2, { [CompanionScene.KEY] = true }, true, true)).to.equal(
				false
			)
			expect(CompanionScene.due("2", {}, true, true)).to.equal(false)
		end)

		it("is off by default and its key is one TipSeen may carry", function()
			expect(LiveFlags.OFF_BY_DEFAULT[CompanionScene.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, CompanionScene.FLAG)).to.be.ok()
			expect(Tips.seenId(CompanionScene.KEY)).to.equal(true)
		end)

		it(
			"picks the rarest cat, then the better coat, then the higher level, then the newest",
			function()
				local common, rare = catOf("Common"), catOf("Rare")
				local cats = {
					a = { uid = "a", catId = common, variant = "rainbow", level = 9, caughtAt = 9 },
					b = { uid = "b", catId = rare, variant = "base", level = 1, caughtAt = 1 },
					c = { uid = "c", catId = rare, variant = "gold", level = 1, caughtAt = 1 },
				}
				expect(CompanionScene.pick(cats)).to.equal("c")
				cats.d = { uid = "d", catId = rare, variant = "gold", level = 2, caughtAt = 1 }
				expect(CompanionScene.pick(cats)).to.equal("d")
				cats.e = { uid = "e", catId = rare, variant = "gold", level = 2, caughtAt = 5 }
				expect(CompanionScene.pick(cats)).to.equal("e")
				cats.f = { uid = "f", catId = rare, variant = "gold", level = 2, caughtAt = 5 }
				expect(CompanionScene.pick(cats)).to.equal("e") -- a full tie goes to the lower uid, every time
			end
		)

		it("picks nothing with no cats and skips unknown kinds", function()
			expect(CompanionScene.pick(nil)).to.equal(nil)
			expect(CompanionScene.pick({})).to.equal(nil)
			expect(CompanionScene.pick({
				x = { uid = "x", catId = "nope", variant = "base", level = 1, caughtAt = 1 },
			})).to.equal(nil)
		end)

		it("says the cat walks with you, then the perk", function()
			expect(CompanionScene.line("Mittens", "+5% money")).to.equal(
				"Mittens walks with you everywhere. +5% money"
			)
			expect(CompanionScene.line("Mittens", nil)).to.equal(
				"Mittens walks with you everywhere."
			)
			expect(CompanionScene.NAME).to.equal("Cat Companion")
		end)
	end)
end
