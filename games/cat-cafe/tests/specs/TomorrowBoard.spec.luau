--!strict
-- shared/TomorrowBoard.luau: the Daily Treat Board on the cafe wall (#5449, tomorrowBoard).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local TomorrowBoard = require(Shared:WaitForChild("TomorrowBoard")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any

	local DAY = 20409 -- a UTC day number
	local NOW = DAY * 86400 + 3600

	local function view(stamp: number, due: boolean): any
		return {
			stamp = stamp,
			lastDay = if due then DAY - 1 else DAY,
			due = due,
			nextDay = if stamp >= 7 then 1 else stamp + 1,
		}
	end

	describe("TomorrowBoard switch", function()
		it("is off by default and listed", function()
			expect(TomorrowBoard.FLAG).to.equal("tomorrowBoard")
			expect(LiveFlags.OFF_BY_DEFAULT.tomorrowBoard).to.equal(true)
			expect(table.find(LiveFlags.KEYS, "tomorrowBoard") ~= nil).to.equal(true)
			expect(LiveFlags.shown("tomorrowBoard", nil)).to.equal(false)
		end)
	end)

	describe("TomorrowBoard.shows", function()
		it("stays away with the switch off", function()
			expect(TomorrowBoard.shows(false, 0, NOW, 9999)).to.equal(false)
		end)

		it("waits out the first session's quiet start on the first day only", function()
			expect(TomorrowBoard.shows(true, DAY, NOW, 60)).to.equal(false)
			expect(TomorrowBoard.shows(true, DAY, NOW, TomorrowBoard.MIN_PLAYED)).to.equal(true)
			expect(TomorrowBoard.shows(true, DAY - 1, NOW, 0)).to.equal(true)
			expect(TomorrowBoard.shows(true, nil, NOW, 0)).to.equal(true)
		end)
	end)

	describe("TomorrowBoard stamps and glow", function()
		it("stamps each claimed day", function()
			expect(TomorrowBoard.stamps(nil)).to.equal(0)
			expect(TomorrowBoard.stamps(view(3, false))).to.equal(3)
			expect(TomorrowBoard.stamps(view(9, false))).to.equal(7)
		end)

		it("lights day 2 only while day 2 is tomorrow", function()
			expect(TomorrowBoard.glows(view(1, false))).to.equal(true)
			expect(TomorrowBoard.glows(view(1, true))).to.equal(false) -- day 2 is claimable now
			expect(TomorrowBoard.glows(view(2, false))).to.equal(false)
			expect(TomorrowBoard.glows(nil)).to.equal(false)
		end)
	end)

	describe("TomorrowBoard words", function()
		it("names tomorrow's fish and the welcome back crate with bigTreats on", function()
			Catalog.setBigTreats(true)
			local title = TomorrowBoard.title(view(1, false), true)
			Catalog.setBigTreats(false)
			expect(title).to.equal("Tomorrow: 500 Golden Fish and a golden crate!")
		end)

		it("says Today while a stamp is due, with no crate", function()
			Catalog.setBigTreats(true)
			local title = TomorrowBoard.title(view(1, true), true)
			Catalog.setBigTreats(false)
			expect(title).to.equal("Today: 500 Golden Fish and 5 free spins!")
		end)

		it("reads the plain rows with bigTreats off", function()
			expect(TomorrowBoard.title(view(1, false), false)).to.equal(
				"Tomorrow: 10 Golden Fish and a free spin!"
			)
			expect(string.find(TomorrowBoard.line(view(1, false)), "Day 2", 1, true) ~= nil).to.equal(
				true
			)
		end)
	end)
end
