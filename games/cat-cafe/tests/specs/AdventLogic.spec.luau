--!strict
-- UI/Components/AdventLogic.luau: the advent calendar card's doors, words and dates (#5502).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local AdventLogic = require(Components:WaitForChild("AdventLogic")) :: any

	local function view(opened: number, due: number, ready: boolean, reason: string?): any
		return { live = true, opened = opened, due = due, ready = ready, reason = reason or "ok" }
	end

	local function states(cells: { any }): string
		local list: { string } = {}
		for _, cell in cells do
			local state: string = cell.state
			table.insert(list, state:sub(1, 1))
		end
		return table.concat(list)
	end

	describe("AdventLogic.shows", function()
		it("hides the card, the row and the prompt until the server says live", function()
			expect(AdventLogic.shows(nil)).to.equal(false)
			local off: any = { live = false, opened = 0, due = 0, ready = false, reason = "off" }
			local early: any =
				{ live = false, opened = 0, due = 0, ready = false, reason = "not_yet" }
			expect(AdventLogic.shows(off)).to.equal(false)
			expect(AdventLogic.shows(early)).to.equal(false)
			expect(AdventLogic.shows(view(0, 1, true))).to.equal(true)
		end)
	end)

	describe("AdventLogic.cells", function()
		it("is 24 locked doors with no view", function()
			local cells = AdventLogic.cells(nil)
			expect(#cells).to.equal(24)
			expect(states(cells)).to.equal(string.rep("l", 24))
		end)

		it("marks opened, the one ready door, waiting and locked", function()
			-- Dec 5, three opened, a tap opens door 4
			expect(states(AdventLogic.cells(view(3, 5, true)))).to.equal(
				"ooorw" .. string.rep("l", 19)
			)
			-- the same day with today's opens used: nothing is ready
			expect(states(AdventLogic.cells(view(4, 5, false, "tomorrow")))).to.equal(
				"oooow" .. string.rep("l", 19)
			)
			-- all done
			expect(states(AdventLogic.cells(view(24, 24, false, "done")))).to.equal(
				string.rep("o", 24)
			)
		end)

		it("carries the four calendar cats on doors 6, 12, 18 and 24", function()
			local cells = AdventLogic.cells(nil)
			local cats: { number } = {}
			for _, cell in cells do
				if cell.cat ~= nil then
					table.insert(cats, cell.n)
				end
			end
			expect(table.concat(cats, ",")).to.equal("6,12,18,24")
		end)

		it("dates door 1 Dec 1 and door 24 Dec 24", function()
			local cells = AdventLogic.cells(nil)
			expect(cells[1].date).to.equal("Dec 1")
			expect(cells[2].date).to.equal("Dec 2")
			expect(cells[24].date).to.equal("Dec 24")
		end)
	end)

	describe("AdventLogic.prizeText", function()
		it("says each prize in a few words", function()
			expect(AdventLogic.prizeText({ fish = 150 })).to.equal("150 golden fish")
			expect(AdventLogic.prizeText({ snowflakes = 100, spins = 3 })).to.equal(
				"3 spins + 100 Snowflakes"
			)
			expect(AdventLogic.prizeText({ spins = 1 })).to.equal("1 spin")
			expect(AdventLogic.prizeText({ coinSeconds = 7200 })).to.equal("2 h of cafe pay")
			expect(AdventLogic.prizeText({ coinSeconds = 1800 })).to.equal("30 min of cafe pay")
			expect(AdventLogic.prizeText({ crates = { highest_golden = 3 } })).to.equal(
				"3 golden crates"
			)
			expect(AdventLogic.prizeText({ potions = { swift_potion = 2, lucky_potion = 2 } })).to.equal(
				"2 Lucky potions + 2 Swift potions"
			)
			expect(AdventLogic.prizeText({ traitTokens = 5 })).to.equal("5 trait tokens")
		end)

		it("leads with the cat's name", function()
			expect(AdventLogic.prizeText(nil, "Nutcracker")).to.equal("Nutcracker")
			expect(AdventLogic.prizeText({ fish = 1000 }, "Silent Night")).to.equal(
				"Silent Night + 1000 golden fish"
			)
		end)

		it("joins with a comma on a short screen", function()
			expect(AdventLogic.prizeText({ snowflakes = 100, spins = 3 }, nil, true)).to.equal(
				"3 spins, 100 Snowflakes"
			)
			expect(AdventLogic.prizeText({ fish = 1000 }, "Silent Night", true)).to.equal(
				"Silent Night, 1000 golden fish"
			)
		end)

		it("never shows an empty door", function()
			expect(AdventLogic.prizeText(nil)).to.equal("A gift")
			expect(AdventLogic.prizeText({})).to.equal("A gift")
		end)

		it("has words for every door in the list", function()
			for _, cell in AdventLogic.cells(nil) do
				local words = AdventLogic.prizeText(cell.prize, if cell.cat then "Cat" else nil)
				expect(words ~= "A gift").to.equal(true)
			end
		end)
	end)

	describe("AdventLogic.headline and rowLine", function()
		it("names the door that is ready", function()
			expect(AdventLogic.headline(view(3, 5, true))).to.equal("Door 4 is ready!")
			expect(AdventLogic.rowLine(view(3, 5, true))).to.equal("Advent door 4")
		end)

		it("says tomorrow when today's doors are opened", function()
			expect(AdventLogic.headline(view(5, 5, false, "tomorrow"))).to.equal(
				"Next door tomorrow"
			)
			expect(AdventLogic.headline(view(4, 9, false, "tomorrow"))).to.equal(
				"More doors tomorrow"
			)
			expect(AdventLogic.rowLine(view(5, 5, false, "tomorrow"))).to.equal(
				"Advent calendar 5/24"
			)
		end)

		it("ends on all 24", function()
			expect(AdventLogic.headline(view(24, 24, false, "done"))).to.equal(
				"All 24 doors opened. Merry Christmas!"
			)
		end)

		it("is safe with no view", function()
			expect(AdventLogic.headline(nil)).to.equal("The calendar opens on Dec 1")
			expect(AdventLogic.rowLine(nil)).to.equal("Advent calendar 0/24")
		end)
	end)
end
