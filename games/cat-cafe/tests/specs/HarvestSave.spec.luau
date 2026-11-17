--!strict
-- shared/HarvestSave: Harvest Hollow's save and the server's rules (#4251, harvest-hollow-spec sections 3 to 5).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local HarvestSave = require(Shared:WaitForChild("HarvestSave")) :: any
	local HarvestHollow = require(Shared:WaitForChild("HarvestHollow")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local ProfileSchema = require(Shared:WaitForChild("ProfileSchema")) :: any

	local open = HarvestHollow.OPENS_AT + 60

	describe("HarvestSave", function()
		it("cleans a save: known items only, whole pumpkins in range", function()
			local save = HarvestSave.sanitize({
				pumpkins = 12.7,
				bought = { acorn_hat = true, made_up = true, pie_counter = "yes" },
				visitDay = -3,
				helped = 1,
			})
			expect(save.pumpkins).to.equal(12)
			expect(save.bought.acorn_hat).to.equal(true)
			expect(save.bought.made_up).to.equal(nil)
			expect(save.bought.pie_counter).to.equal(nil)
			expect(save.visitDay).to.equal(0)
			expect(save.helped).to.equal(false)
			expect(HarvestSave.sanitize(nil).pumpkins).to.equal(0)
			expect(HarvestSave.sanitize({ pumpkins = 1e12 }).pumpkins).to.equal(
				HarvestSave.MAX_PUMPKINS
			)
		end)

		it("keeps the area shut outside its dates, below Tier 2 or with the switch off", function()
			expect(HarvestSave.areaBlocker(open, 2, true)).to.equal(nil)
			expect(HarvestSave.areaBlocker(HarvestHollow.OPENS_AT - 1, 2, true)).to.equal(
				"Harvest Hollow is closed"
			)
			expect(HarvestSave.areaBlocker(HarvestHollow.CLOSES_AT, 5, true)).to.equal(
				"Harvest Hollow is closed"
			)
			expect(HarvestSave.areaBlocker(open, 1, true)).to.equal(
				"Harvest Hollow opens at Tier 2"
			)
			expect(HarvestSave.areaBlocker(open, 5, false)).to.equal("Harvest Hollow is closed")
		end)

		it("sells each Stall item once, for its price in pumpkins", function()
			local save = HarvestSave.fresh()
			save.pumpkins = 135
			expect(HarvestSave.buyBlocker(save, "nope", open, 2, true)).to.equal(
				"That isn't on the Stall"
			)
			expect(HarvestSave.buyBlocker(save, "sunflower_hat", open, 2, true)).to.equal(
				"You need 15 more pumpkins"
			)
			expect(HarvestSave.buyBlocker(save, "acorn_hat", open, 2, true)).to.equal(nil)
			expect(HarvestSave.buy(save, "acorn_hat")).to.equal(true)
			expect(save.pumpkins).to.equal(15)
			expect(save.bought.acorn_hat).to.equal(true)
			expect(HarvestSave.buyBlocker(save, "acorn_hat", open, 2, true)).to.equal(
				"You already have it"
			)
			expect(HarvestSave.buy(save, "acorn_hat")).to.equal(false)
			expect(save.pumpkins).to.equal(15)
			save.pumpkins = 100
			expect(HarvestSave.buyBlocker(save, "pumpkin_hat", HarvestHollow.CLOSES_AT, 2, true)).to.equal(
				"Harvest Hollow is closed"
			)
		end)

		it("gives the arch's +40 once a UTC day", function()
			local save = HarvestSave.fresh()
			expect(HarvestSave.visit(save, open)).to.equal(40)
			expect(HarvestSave.visit(save, open + 60)).to.equal(0)
			local nextDay = (math.floor(open / 86400) + 1) * 86400
			expect(HarvestSave.visit(save, nextDay)).to.equal(40)
			expect(save.pumpkins).to.equal(80)
		end)

		it("pays a harvest cat by rarity and regrows faster in a busy patch", function()
			expect(HarvestSave.catchPumpkins("Common")).to.equal(1)
			expect(HarvestSave.catchPumpkins("Rare")).to.equal(2)
			expect(HarvestSave.catchPumpkins("Epic")).to.equal(3)
			expect(HarvestSave.catchPumpkins("Legendary")).to.equal(5)
			expect(HarvestSave.catchPumpkins("Mythical")).to.equal(10)
			expect(HarvestSave.regrowSeconds(1)).to.equal(300)
			expect(HarvestSave.regrowSeconds(5)).to.equal(300)
			expect(HarvestSave.regrowSeconds(6)).to.equal(150)
		end)

		it("caps pumpkins and hands the client a copy", function()
			local save = HarvestSave.fresh()
			save.pumpkins = HarvestSave.MAX_PUMPKINS - 1
			expect(HarvestSave.give(save, 5)).to.equal(1)
			save.bought.acorn_hat = true
			local view = HarvestSave.forClient(save)
			view.bought.feather_cap = true
			expect(save.bought.feather_cap).to.equal(nil)
		end)

		it("bakes the Feast Pie in eighths of a live goal", function()
			expect(HarvestSave.pieGoal(false)).to.equal(25000)
			expect(HarvestSave.pieGoal(true)).to.equal(15000)
			expect(HarvestSave.pieSlices(0, 25000)).to.equal(0)
			expect(HarvestSave.pieSlices(3124, 25000)).to.equal(0)
			expect(HarvestSave.pieSlices(3125, 25000)).to.equal(1)
			expect(HarvestSave.pieSlices(24999, 25000)).to.equal(7)
			expect(HarvestSave.pieSlices(99999, 25000)).to.equal(8)
			expect(HarvestSave.pieSlices(10, 0)).to.equal(0)
			expect(LiveFlags.defaults()[HarvestSave.PIE_LOW_FLAG]).to.equal(false)
		end)

		it("pins one of six fixed notes, one a player, the last twelve", function()
			expect(HarvestSave.validNote(1)).to.equal(true)
			expect(HarvestSave.validNote(6)).to.equal(true)
			expect(HarvestSave.validNote(0)).to.equal(false)
			expect(HarvestSave.validNote(7)).to.equal(false)
			expect(HarvestSave.validNote(2.5)).to.equal(false)
			expect(HarvestSave.validNote("1")).to.equal(false)
			local list = {}
			for userId = 1, 13 do
				list = HarvestSave.pinNote(list, userId, 1)
			end
			expect(#list).to.equal(12)
			expect(list[1].userId).to.equal(2)
			list = HarvestSave.pinNote(list, 5, 3)
			expect(#list).to.equal(12)
			expect(list[12].userId).to.equal(5)
			expect(list[12].note).to.equal(3)
			local fives = 0
			for _, row in list do
				if row.userId == 5 then
					fives += 1
				end
			end
			expect(fives).to.equal(1)
		end)

		it("is in every new save and the switch is on by default", function()
			local profile = ProfileSchema.migrate({}, open)
			expect(profile.harvest.pumpkins).to.equal(0)
			expect(LiveFlags.defaults()[HarvestSave.FLAG]).to.equal(true)
		end)

		it("spawns harvest cats on odds that sum to 100, with room for the cap (part 5)", function()
			local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog) :: any
			local total = 0
			for rarity, odds in HarvestSave.ODDS do
				expect(Catalog.rarities[rarity]).to.be.ok()
				expect(odds > 0).to.equal(true)
				total += odds
				local any = false
				for _, def in Catalog.harvestCats do
					any = any or def.rarity == rarity
				end
				expect(any).to.equal(true) -- every rarity it rolls has a harvest cat
			end
			expect(math.abs(total - 100) < 1e-9).to.equal(true)
			expect(HarvestSave.STRAY_CAP >= 1 and HarvestSave.STRAY_CAP <= 15).to.equal(true)
			expect(Catalog.harvestCats[1].area).to.equal(HarvestSave.AREA)
		end)

		it(
			"owes the full pie's reward once, to a helper, only when the pie is full (part 6)",
			function()
				local save = HarvestSave.fresh()
				expect(save.pieReward).to.equal(false)
				expect(HarvestSave.pieRewardDue(save, HarvestSave.PIE_SLICES)).to.equal(false) -- not a helper
				save.helped = true
				expect(HarvestSave.pieRewardDue(save, HarvestSave.PIE_SLICES - 1)).to.equal(false)
				expect(HarvestSave.pieRewardDue(save, HarvestSave.PIE_SLICES)).to.equal(true)
				save.pieReward = true
				expect(HarvestSave.pieRewardDue(save, HarvestSave.PIE_SLICES)).to.equal(false)
				-- kept through a save round trip; anything but true is false
				expect(HarvestSave.sanitize({ pieReward = true }).pieReward).to.equal(true)
				expect(HarvestSave.sanitize({ pieReward = "yes" }).pieReward).to.equal(false)
				expect(HarvestSave.forClient(save).pieReward).to.equal(true)
			end
		)

		it(
			"puts Stall decor and the Feast Pie in decorOwned and the hats in the Looks items (part 7)",
			function()
				local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog) :: any
				local Looks = require(game:GetService("ReplicatedStorage").Shared.Looks) :: any
				local HarvestHollow =
					require(game:GetService("ReplicatedStorage").Shared.HarvestHollow) :: any
				-- every Stall item and the Feast Pie has its decor piece or hat
				for _, item in HarvestHollow.STALL do
					if item.kind == "decor" then
						local def = Catalog.getDecor(HarvestSave.decorId(item.id))
						expect(def).to.be.ok()
						expect(def.source).to.equal("harvest")
						expect(def.asset).to.equal(item.model)
					else
						expect(Looks.accessory(HarvestSave.lookId(item.id))).to.be.ok()
					end
				end
				expect(Catalog.getDecor(HarvestSave.decorId(HarvestSave.FEAST_PIE))).to.be.ok()
				local save = HarvestSave.fresh()
				save.bought.hay_bale_sofa = true
				save.bought.acorn_hat = true
				local decor: { [string]: boolean } = {}
				expect(HarvestSave.grantOwned(save, decor)).to.equal(1)
				expect(decor.decor_hay_bale_sofa).to.equal(true)
				expect(HarvestSave.grantOwned(save, decor)).to.equal(0) -- already whole
				save.pieReward = true
				expect(HarvestSave.grantOwned(save, decor)).to.equal(1)
				expect(decor.decor_feast_pie).to.equal(true)
				local passItems: { [string]: boolean } = { acc_leaf_beret = true }
				local items = HarvestSave.lookItems(save, passItems)
				expect(items.acc_acorn_hat).to.equal(true)
				expect(items.acc_leaf_beret).to.equal(true)
				expect(passItems.acc_acorn_hat).to.equal(nil) -- a copy
				expect(table.find(
					Looks.owned("accessory", function()
						return false
					end, items),
					"acc_acorn_hat"
				)).to.be.ok()
			end
		)
	end)
end
