--!strict
-- UI/Components/LootCardLogic.luau and RummageBin.items (#3464): the Rummage Bin's loot card lists exactly what the
-- server paid, one row per item, and a golden crate win wears the gold frame.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local RummageBin = require(Shared.RummageBin)
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LootCardLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LootCardLogic")
	) :: any

	local function winOf(id: string): any
		for _, rows in { Config.BinFirstPrizes :: { any }, Config.BinTable :: { any } } do
			for _, row in rows do
				if row.id == id then
					return { id = id, first = false, items = RummageBin.items(row) }
				end
			end
		end
		error("no row " .. id)
	end

	describe("RummageBin.items", function()
		it("lists everything the row pays, with the amounts the prize holds", function()
			for _, rows in { Config.BinFirstPrizes :: { any }, Config.BinTable :: { any } } do
				for _, row in rows do
					local prize = RummageBin.prize(row)
					local seen: { [string]: number } = { lure = 0, crate = 0, potion = 0, fish = 0 }
					for _, item in RummageBin.items(row) do
						seen[item.kind] += item.count
					end
					local function total(held: { [string]: number }?): number
						local sum = 0
						for _, count in held or {} do
							sum += count
						end
						return sum
					end
					expect(seen.lure).to.equal(total(prize.lures))
					expect(seen.crate).to.equal(total(prize.crates))
					expect(seen.potion).to.equal(total(prize.potions))
					expect(seen.fish).to.equal(prize.fish or 0)
				end
			end
		end)
	end)

	describe("LootCardLogic.rows", function()
		it("gives one row per item with its name and amount", function()
			local rows = LootCardLogic.rows(winOf("first_tuna"))
			expect(#rows).to.equal(2)
			expect(rows[1].name).to.equal("Tuna")
			expect(rows[1].amount).to.equal("x2")
			expect(rows[2].name).to.equal("Golden fish")
			expect(rows[2].amount).to.equal("+10")
			rows = LootCardLogic.rows(winOf("first_crate"))
			expect(#rows).to.equal(2)
			expect(rows[1].name).to.equal("Alley Crate")
			expect(rows[1].amount).to.equal("x1")
			expect(rows[2].name).to.equal("Lucky Potion")
			rows = LootCardLogic.rows(winOf("fish"))
			expect(#rows).to.equal(1)
			expect(rows[1].amount).to.equal("+8")
		end)

		it("has a row for every prize the bin can pay", function()
			for _, rows in { Config.BinFirstPrizes :: { any }, Config.BinTable :: { any } } do
				for _, row in rows do
					local win = { id = row.id, first = false, items = RummageBin.items(row) }
					expect(#LootCardLogic.rows(win)).to.equal(#win.items)
				end
			end
		end)

		it("draws nothing from a damaged message", function()
			expect(#LootCardLogic.rows(nil)).to.equal(0)
			expect(#LootCardLogic.rows({ id = "tuna" })).to.equal(0)
			expect(#LootCardLogic.rows({ items = "tuna" })).to.equal(0)
			local rows = LootCardLogic.rows({
				items = {
					"tuna",
					{ kind = "coins", count = 5 },
					{ kind = "lure", id = "no_such_food", count = 1 },
					{ kind = "lure", id = "tuna", count = 0 },
					{ kind = "lure", id = "tuna", count = 0 / 0 },
					{ kind = "fish", count = 3.7 },
				},
			})
			expect(#rows).to.equal(1)
			expect(rows[1].amount).to.equal("+3")
			-- never more rows than the card holds
			local many = {}
			for _ = 1, 9 do
				table.insert(many, { kind = "fish", count = 1 })
			end
			expect(#LootCardLogic.rows({ items = many })).to.equal(LootCardLogic.MAX_ROWS)
		end)

		it("says only what was found: no claim, no timer", function()
			expect(LootCardLogic.TITLE).to.equal("You found:")
			expect(LootCardLogic.SECONDS).to.equal(4)
		end)
	end)

	describe("LootCardLogic.gold", function()
		it("is the golden crate win alone", function()
			expect(LootCardLogic.gold(winOf("golden"))).to.equal(true)
			for _, id in
				{ "tuna", "fish", "salmon", "potion", "crate", "first_tuna", "first_crate" }
			do
				expect(LootCardLogic.gold(winOf(id))).to.equal(false)
			end
			expect(LootCardLogic.gold(nil)).to.equal(false)
		end)
	end)
end
