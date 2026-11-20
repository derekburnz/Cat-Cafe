--!strict
-- #5296 Components/CompanionLogic.order: the picker's cards best first (Money, then Luck, level, newest, uid).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
	local CompanionLogic = require(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.Components.CompanionLogic
	) :: any

	local function catOf(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end

	describe("CompanionLogic.order", function()
		it(
			"puts the biggest boost first, then level, then the newest, and skips unknown kinds",
			function()
				local byId = {}
				for _, def in Catalog.cats do
					byId[def.id] = def
				end
				local common, rare = catOf("Common"), catOf("Rare")
				local cats = {
					a = { uid = "a", catId = common, variant = "rainbow", level = 9, caughtAt = 9 },
					b = { uid = "b", catId = rare, variant = "base", level = 1, caughtAt = 1 },
					c = { uid = "c", catId = rare, variant = "gold", level = 1, caughtAt = 1 },
					d = { uid = "d", catId = rare, variant = "gold", level = 3, caughtAt = 1 },
					x = { uid = "x", catId = "nope", variant = "base", level = 1, caughtAt = 1 },
				}
				local order = {}
				for _, cat in CompanionLogic.order(cats, byId) do
					table.insert(order, cat.uid)
				end
				expect(table.concat(order, ",")).to.equal("d,c,b,a")
				expect(#CompanionLogic.order(nil, byId)).to.equal(0)
			end
		)
	end)

	describe("CompanionLogic.better and fresh (#5457)", function()
		local byId = {}
		for _, def in Catalog.cats do
			byId[def.id] = def
		end
		local common, rare = catOf("Common"), catOf("Rare")
		local cats: { [string]: any } = {
			a = { uid = "a", catId = common, variant = "base", level = 1 },
			b = { uid = "b", catId = rare, variant = "base", level = 1 },
			c = { uid = "c", catId = rare, variant = "gold", level = 1 },
		}

		it("lists only the cats that beat the companion", function()
			expect(table.concat(CompanionLogic.better(cats, byId, "a"), ",")).to.equal("b,c")
			expect(table.concat(CompanionLogic.better(cats, byId, "b"), ",")).to.equal("c")
			expect(#CompanionLogic.better(cats, byId, "c")).to.equal(0)
			expect(#CompanionLogic.better(nil, byId, "a")).to.equal(0)
		end)

		it("is fresh until every better cat is seen, and again for a new one", function()
			local seen = {}
			local better = CompanionLogic.better(cats, byId, "a")
			expect(CompanionLogic.fresh(better, seen)).to.equal(true)
			for _, uid in better do
				seen[uid] = true
			end
			expect(CompanionLogic.fresh(better, seen)).to.equal(false)
			cats.d = { uid = "d", catId = rare, variant = "rainbow", level = 1 }
			expect(CompanionLogic.fresh(CompanionLogic.better(cats, byId, "a"), seen)).to.equal(
				true
			)
			cats.d = nil
		end)
	end)
end
