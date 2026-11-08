--!strict
-- UI/Components/DailyTreatLogic.luau: the Daily Treat card's stamps, the HUD tile's due dot and the window's words
-- (F70, data-model section 11e).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local DailyTreatLogic = require(Components:WaitForChild("DailyTreatLogic")) :: any

	local DAY = 86400
	local TODAY = 20000 -- a UTC day number
	local NOON = TODAY * DAY + DAY / 2

	local function states(cells: { any }): string
		local list: { string } = {}
		for _, cell in cells do
			local state: string = cell.state
			table.insert(list, state:sub(1, 1))
		end
		return table.concat(list)
	end

	local days: any = {
		{ day = 1, prize = { coins = 300, coinSeconds = 300 } },
		{ day = 2, prize = { lures = { salmon = 2 }, fish = 15, spins = 1 } },
		{ day = 7, prize = { fish = 50, spins = 3 } },
	}

	describe("DailyTreatLogic.view", function()
		it("makes ProfileSync's card safe", function()
			expect(DailyTreatLogic.view(nil)).to.equal(nil)
			local view = DailyTreatLogic.view({ stamp = 9.5, lastDay = -3, due = 1 })
			expect(view.stamp).to.equal(7)
			expect(view.lastDay).to.equal(0)
			expect(view.due).to.equal(false)
			expect(view.nextDay).to.equal(1)
			expect(DailyTreatLogic.view({ stamp = 2, lastDay = TODAY, due = true }).nextDay).to.equal(3)
		end)
	end)

	describe("DailyTreatLogic.due", function()
		it("follows the server, and a UTC day turning since the last claim", function()
			expect(DailyTreatLogic.due(nil, NOON)).to.equal(false)
			local claimedToday = DailyTreatLogic.view({ stamp = 2, lastDay = TODAY, due = false })
			expect(DailyTreatLogic.due(claimedToday, NOON)).to.equal(false)
			expect(DailyTreatLogic.due(claimedToday, (TODAY + 1) * DAY)).to.equal(true)
			local fresh = DailyTreatLogic.view({ stamp = 0, lastDay = 0, due = true })
			expect(DailyTreatLogic.due(fresh, NOON)).to.equal(true)
		end)
	end)

	describe("DailyTreatLogic.cells", function()
		it("stamps the days paid, readies the one due and waits on the rest", function()
			local due = DailyTreatLogic.view({ stamp = 2, lastDay = TODAY - 3, due = true })
			local cells = DailyTreatLogic.cells(due, days, NOON)
			expect(#cells).to.equal(7)
			expect(states(cells)).to.equal("ssrllll")
			expect(cells[1].prize.coins).to.equal(300)
			expect(cells[7].prize.fish).to.equal(50)
			expect(cells[3].prize).to.equal(nil)
			local waiting = DailyTreatLogic.view({ stamp = 3, lastDay = TODAY, due = false })
			expect(states(DailyTreatLogic.cells(waiting, days, NOON))).to.equal("sssnlll")
		end)

		it("shows a full card until the next stamp is due, then a fresh one", function()
			local full = DailyTreatLogic.view({ stamp = 7, lastDay = TODAY, due = false })
			expect(states(DailyTreatLogic.cells(full, days, NOON))).to.equal("sssssss")
			expect(states(DailyTreatLogic.cells(full, days, (TODAY + 1) * DAY + 5))).to.equal("rllllll")
			local fresh = DailyTreatLogic.view({ stamp = 0, lastDay = 0, due = true })
			expect(states(DailyTreatLogic.cells(fresh, nil, NOON))).to.equal("rllllll")
		end)
	end)

	describe("DailyTreatLogic words and sounds", function()
		it("counts to the next UTC midnight in hours and minutes", function()
			expect(DailyTreatLogic.untilTomorrow(NOON)).to.equal(DAY / 2)
			expect(DailyTreatLogic.untilTomorrow(TODAY * DAY)).to.equal(DAY)
			expect(DailyTreatLogic.waitText(5 * 3600 + 12 * 60)).to.equal("5 h 12 min")
			expect(DailyTreatLogic.waitText(41 * 60 + 1)).to.equal("42 min")
			expect(DailyTreatLogic.waitText(-5)).to.equal("1 min")
		end)

		it("hears a new stamp only when a sync moves the last claim on", function()
			local before = DailyTreatLogic.view({ stamp = 2, lastDay = TODAY - 1, due = true })
			local after = DailyTreatLogic.view({ stamp = 3, lastDay = TODAY, due = false })
			expect(DailyTreatLogic.claimedDay(before, after)).to.equal(3)
			expect(DailyTreatLogic.claimedDay(nil, after)).to.equal(nil)
			expect(DailyTreatLogic.claimedDay(after, after)).to.equal(nil)
			expect(DailyTreatLogic.stampSound(3)).to.equal("uiDailyStamp")
			expect(DailyTreatLogic.stampSound(7)).to.equal("jingleDailyCard")
		end)

		it("opens by itself only with a stamp due and the tutorial done", function()
			local due = DailyTreatLogic.view({ stamp = 1, lastDay = TODAY - 1, due = true })
			expect(DailyTreatLogic.autoOpen(due, NOON, 5)).to.equal(true)
			expect(DailyTreatLogic.autoOpen(due, NOON, nil)).to.equal(true)
			expect(DailyTreatLogic.autoOpen(due, NOON, 2)).to.equal(false)
			local done = DailyTreatLogic.view({ stamp = 1, lastDay = TODAY, due = false })
			expect(DailyTreatLogic.autoOpen(done, NOON, 5)).to.equal(false)
		end)
	end)
end
