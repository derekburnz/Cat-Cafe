--!strict
-- Components/LostFoundLogic (#3955): the Lost and Found card's words and its "what can turn up" rows.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.Config) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LostFoundLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LostFoundLogic")
	) :: any

	local NOW = 1000000

	describe("LostFoundLogic", function()
		it("names the finds waiting and lets Claim go", function()
			local title, line, status, ready = LostFoundLogic.status({ open = true, held = 2 }, NOW)
			expect(title).to.equal("2 finds waiting")
			expect(line).to.equal("Claim to see what turned up")
			expect(status).to.equal("2 WAITING")
			expect(ready).to.equal(true)
			expect(LostFoundLogic.button({ open = true, held = 2 }, NOW, false)).to.equal("Claim 2")
			expect(LostFoundLogic.button({ open = true, held = 1 }, NOW, false)).to.equal("Claim")
			expect(LostFoundLogic.button({ open = true, held = 1 }, NOW, true)).to.equal("...")
		end)

		it("says when the next find comes while nothing waits", function()
			local view = { open = true, held = 0, nextAt = NOW + 4800 }
			local title, line, status, ready = LostFoundLogic.status(view, NOW)
			expect(title).to.equal("Nothing found yet")
			expect(string.sub(line, 1, 14)).to.equal("Next find in 1")
			expect(status).to.equal("SOON")
			expect(ready).to.equal(false)
			expect(LostFoundLogic.button(view, NOW, false)).to.equal(line)
			local _, _, _, shut = LostFoundLogic.status({ open = false, held = 3 }, NOW)
			expect(shut).to.equal(false)
			local _, _, _, none = LostFoundLogic.status(nil, NOW)
			expect(none).to.equal(false)
		end)

		it("lists every row of the table with its chance, the lost cat as a cat", function()
			local rows = LostFoundLogic.rows()
			expect(#rows).to.equal(#Config.LostFoundTable)
			local cats = 0
			for index, row in rows do
				local def = Config.LostFoundTable[index]
				expect(string.sub(row.chance, -1)).to.equal("%")
				if def.lostCat ~= nil then
					cats += 1
					expect(row.lostCat).to.equal(def.lostCat)
				else
					expect(row.lostCat).to.equal(nil)
				end
				if def.fish ~= nil then
					expect(row.prize.fish).to.equal(def.fish)
				end
				if def.crate ~= nil then
					expect(row.prize.crates[def.crate]).to.equal(1)
				end
			end
			expect(cats).to.equal(1)
			expect(rows[1].chance).to.equal("30%")
		end)

		it("names what turned up from the server's lines", function()
			expect(LostFoundLogic.foundText({ "+25 golden fish" })).to.equal("+25 golden fish")
			expect(LostFoundLogic.foundText({ "+2 spins", "1 Sewer Crate" })).to.equal(
				"+2 spins, 1 Sewer Crate"
			)
			expect(LostFoundLogic.foundText(nil)).to.equal("Something turned up!")
		end)
	end)
end
