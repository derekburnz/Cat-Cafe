--!strict
-- UI/Components/RecapLogic.luau: the session recap card's lines and when it may show (#1920, first-hour.md 6).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RecapLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RecapLogic")
	) :: any

	local function money(n: number): string
		return "$" .. tostring(n)
	end

	local function input(over: { [string]: any })
		local base = {
			view = { minutes = 41, newCats = 3, earned = 1200 },
			state = { tutorialStep = 9 },
			nextTier = "Cozy Cafe",
			baitReadyAt = {},
			now = 1000,
			offlineRate = 0.5,
			offlineCapSeconds = 28800,
			money = money,
		}
		for key, value in over do
			base[key] = value
		end
		return base
	end

	describe("RecapLogic.lines", function()
		it("leads with today, then what's next, then the offline share and tomorrow", function()
			local lines = RecapLogic.lines(input({}))
			expect(#lines).to.equal(3)
			expect(lines[1]).to.equal("Today: 3 new cats, $1200 earned")
			expect(lines[2]).to.equal("Next: rank up to Cozy Cafe")
			expect(lines[3]).to.equal(
				"Your cafe earns while you're away: 50% for up to 8 h. Tomorrow: new quests"
			)
		end)

		it("shows a line only when it is true", function()
			local lines = RecapLogic.lines(input({
				view = { newCats = 0, earned = 0 },
				nextTier = false,
			}))
			expect(#lines).to.equal(1)
			local one = RecapLogic.lines(input({ view = { newCats = 1 } }))
			expect(one[1]).to.equal("Today: 1 new cat")
		end)

		it("names the Grand Opening's next step while it runs", function()
			local state = { tutorialStep = 9, grandOpening = { done = { [1] = true, [2] = true } } }
			expect(RecapLogic.next(state, "Cozy Cafe")).to.equal(
				"Grand Opening 2/8: Five different cats"
			)
		end)

		it("counts a cooking bait cat in whole minutes, never under one", function()
			local lines = RecapLogic.lines(input({ baitReadyAt = { 900, 1150, 1500 } }))
			expect(lines[3]).to.equal("Your bait cat arrives in 3 min. It waits for you")
			local soon = RecapLogic.lines(input({ baitReadyAt = { 1010 } }))
			expect(soon[3]).to.equal("Your bait cat arrives in 1 min. It waits for you")
		end)

		it("uses the pass's share and tomorrow's Daily Treat day once today's is taken", function()
			local lines = RecapLogic.lines(input({
				offlineRate = 1,
				offlineCapSeconds = 57600,
				state = { tutorialStep = 9, dailyTreat = { due = false, nextDay = 4 } },
			}))
			expect(lines[#lines]).to.equal(
				"Your cafe earns while you're away: 100% for up to 16 h. Tomorrow: Daily Treat day 4 and new quests"
			)
		end)
	end)

	describe("RecapLogic.canShow", function()
		local function gate(over: { [string]: any })
			local base = {
				enabled = true,
				tutorialStep = 9,
				catching = false,
				carrying = false,
				menuOpen = false,
				idleSeconds = 6,
			}
			for key, value in over do
				base[key] = value
			end
			return base
		end

		it("waits for a calm moment after the tutorial", function()
			expect(RecapLogic.canShow(gate({}))).to.equal(true)
			expect(RecapLogic.canShow(gate({ idleSeconds = 2 }))).to.equal(false)
			expect(RecapLogic.canShow(gate({ catching = true }))).to.equal(false)
			expect(RecapLogic.canShow(gate({ carrying = true }))).to.equal(false)
			expect(RecapLogic.canShow(gate({ menuOpen = true }))).to.equal(false)
			expect(RecapLogic.canShow(gate({ tutorialStep = 3 }))).to.equal(false)
		end)

		it("never shows with the Settings toggle off", function()
			expect(RecapLogic.canShow(gate({ enabled = false }))).to.equal(false)
		end)
	end)
end
