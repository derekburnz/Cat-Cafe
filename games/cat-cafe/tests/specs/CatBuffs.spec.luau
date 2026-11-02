--!strict
-- UI/Components/CatBuffs.luau: the buff chips that replace charm stars on the Cats screen (F97 section 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatBuffs = require(Components:WaitForChild("CatBuffs")) :: any

	local function texts(chips: { any }): { string }
		local out = {}
		for _, chip in chips do
			table.insert(out, chip.text)
		end
		return out
	end

	describe("CatBuffs.chips", function()
		it(
			"gives a gold level 12 Barista in its favourite role three chips (F97 section 10 check 6)",
			function()
				local chips =
					CatBuffs.chips({ role = "Barista", favourite = true, gold = true, level = 12 })
				expect(#chips).to.equal(3)
				expect(chips[1].kind).to.equal("favourite")
				expect(chips[1].text).to.equal("+50% as Barista")
				expect(chips[2].text).to.equal("Gold +50%")
				expect(chips[3].text).to.equal("Lv 12 +22%")
			end
		)

		it("says Likes away from its favourite role and leaves out gold and level 1", function()
			local chips =
				CatBuffs.chips({ role = "Waiter", favourite = false, gold = false, level = 1 })
			expect(#chips).to.equal(1)
			expect(chips[1].kind).to.equal("likes")
			expect(chips[1].text).to.equal("Likes: Waiter")
		end)

		it("shows nothing for a plain level 1 cat without a favourite role", function()
			expect(#CatBuffs.chips({ favourite = false, gold = false, level = 1 })).to.equal(0)
			expect(#CatBuffs.chips({ role = "", favourite = true, gold = false })).to.equal(0)
		end)

		it("follows the level curve to level 50", function()
			local chips = CatBuffs.chips({ favourite = false, gold = false, level = 50 })
			expect(texts(chips)[1]).to.equal("Lv 50 +98%")
		end)
	end)

	describe("CatBuffs.charmText", function()
		it("shows charm as a plain percentage either side of 50", function()
			expect(CatBuffs.charmText(80)).to.equal("Charm +12%")
			expect(CatBuffs.charmText(40)).to.equal("Charm -4%")
			expect(CatBuffs.charmText(50)).to.equal("Charm +0%")
			expect(CatBuffs.charmText(0)).to.equal("Charm -20%")
			expect(CatBuffs.charmText(100)).to.equal("Charm +20%")
		end)
	end)
end
