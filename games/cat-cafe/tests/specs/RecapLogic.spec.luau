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
				"Your cats keep earning while you're away: 50% pay, up to 8\u{00A0}h. Tomorrow: new quests"
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

		it("knows the offline line for the card's callout (#2235)", function()
			local lines = RecapLogic.lines(input({}))
			local found = 0
			for _, line in lines do
				if RecapLogic.isOffline(line) then
					found += 1
				end
			end
			expect(found).to.equal(1)
			expect(RecapLogic.isOffline("Today: 3 new cats, $12,500 earned")).to.equal(false)
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
				"Your cats keep earning while you're away: 100% pay, up to 16\u{00A0}h. Tomorrow: Daily Treat day 4 and new quests"
			)
		end)
	end)

	describe("RecapLogic Tomorrow line (#2123)", function()
		it("names the one pick under the offline share, and drops the cooking line", function()
			local lines = RecapLogic.lines(input({
				view = { newCats = 3, earned = 1200, tomorrow = { kind = "bait" } },
				baitReadyAt = { 1500 },
			}))
			expect(#lines).to.equal(4)
			expect(lines[3]).to.equal(
				"Your cats keep earning while you're away: 50% pay, up to 8\u{00A0}h"
			)
			expect(lines[4]).to.equal("Your bait cat will be waiting for you")
		end)

		it("words each kind, with the treat's day and its prize from the catalog", function()
			expect(RecapLogic.tomorrow({ kind = "bait" })).to.equal(
				"Your bait cat will be waiting for you"
			)
			expect(RecapLogic.tomorrow({ kind = "treat", day = 2 })).to.equal(
				"Tomorrow: Daily Treat day 2, " .. RecapLogic.treatWords(2)
			)
			expect(RecapLogic.tomorrow({ kind = "treat", day = 99 })).to.equal(
				"Tomorrow: Daily Treat day 99"
			)
			expect(RecapLogic.tomorrow({ kind = "treat" })).to.equal("Tomorrow: your Daily Treat")
			expect(RecapLogic.tomorrow({ kind = "quests" })).to.equal("Tomorrow: new daily quests")
			-- #3772: the welcome back gift
			expect(RecapLogic.tomorrow({ kind = "gift" })).to.equal("Come back tomorrow for a golden crate")
			expect((RecapLogic.hook({ kind = "gift" }) :: any).kind).to.equal("gift")
		end)

		it("names a Daily Treat day's prize after its coins, two things at most", function()
			expect(RecapLogic.treatWords(1)).to.equal("2 Small Snacks")
			expect(RecapLogic.treatWords(2)).to.equal("10 Golden Fish and 1 spin")
			-- day 7 leads with its golden crate, then the Star Treat (the fish drop off)
			local seven = string.split(RecapLogic.treatWords(7) :: string, " and ")
			expect(#seven).to.equal(2)
			expect(string.find(seven[1], "Crate", 1, true) ~= nil).to.equal(true)
			expect(string.find(seven[2], "Fish", 1, true)).to.equal(nil)
			for day = 1, 7 do
				local words = RecapLogic.treatWords(day)
				expect(words ~= nil and #words <= 40).to.equal(true)
			end
			expect(RecapLogic.treatWords(0)).to.equal(nil)
			expect(RecapLogic.treatWords(nil)).to.equal(nil)
		end)

		it("falls back to state.returnHook, and ignores a bad pick", function()
			local lines = RecapLogic.lines(input({
				state = { tutorialStep = 9, returnHook = { kind = "quests" } },
			}))
			expect(lines[#lines]).to.equal("Tomorrow: new daily quests")
			expect(RecapLogic.hook({ kind = "store" })).to.equal(nil)
			expect(RecapLogic.hook("bait")).to.equal(nil)
			local odd = RecapLogic.hook({ kind = "treat", day = -1, prize = string.rep("x", 80) })
			expect(odd.day).to.equal(nil)
			expect(odd.prize).to.equal(nil)
			-- no pick: the line from before #2123
			local before = RecapLogic.lines(input({}))
			expect(before[#before]).to.equal(
				"Your cats keep earning while you're away: 50% pay, up to 8\u{00A0}h. Tomorrow: new quests"
			)
		end)

		it("never names a timer or the store", function()
			for _, hook in
				{
					{ kind = "bait" },
					{ kind = "treat", day = 3, prize = "Gold" },
					{ kind = "quests" },
				}
			do
				local line = string.lower(RecapLogic.tomorrow(hook))
				expect(string.find(line, "%d+ ?min")).to.equal(nil)
				expect(string.find(line, "store", 1, true)).to.equal(nil)
				expect(string.find(line, "lose", 1, true)).to.equal(nil)
			end
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
