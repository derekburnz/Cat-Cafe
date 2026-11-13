--!strict
-- UI/Components/EventRsvp.luau: the update Event's ask (#2766).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local EventRsvp = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("EventRsvp")
	) :: any

	describe("EventRsvp.due", function()
		it("is due before the Event starts", function()
			expect(EventRsvp.due("8839991594911400494", 1000, 999)).to.equal(true)
		end)

		it("is not due once it has started", function()
			expect(EventRsvp.due("8839991594911400494", 1000, 1000)).to.equal(false)
			expect(EventRsvp.due("8839991594911400494", 1000, 5000)).to.equal(false)
		end)

		it("is not due without an id or a start, or with an id that is not a number", function()
			expect(EventRsvp.due(nil, 1000, 0)).to.equal(false)
			expect(EventRsvp.due("8839991594911400494", nil, 0)).to.equal(false)
			expect(EventRsvp.due("", 1000, 0)).to.equal(false)
			expect(EventRsvp.due("abc", 1000, 0)).to.equal(false)
			expect(EventRsvp.due(8839991594911400494, 1000, 0)).to.equal(false)
		end)
	end)

	describe("EventRsvp.next", function()
		local list = { { id = "222", startsAt = 2000 }, { id = "111", startsAt = 1000 } }

		it("asks about the first listed Event that has not started", function()
			local id, at = EventRsvp.next(list, 500)
			expect(id).to.equal("111")
			expect(at).to.equal(1000)
		end)

		it("moves on to the next Event once one starts, and asks nothing after the last", function()
			local id, at = EventRsvp.next(list, 1000)
			expect(id).to.equal("222")
			expect(at).to.equal(2000)
			expect(EventRsvp.next(list, 2000)).to.equal(nil)
		end)

		it("asks nothing for an empty or broken list", function()
			expect(EventRsvp.next({}, 0)).to.equal(nil)
			expect(EventRsvp.next(nil, 0)).to.equal(nil)
			expect(EventRsvp.next({ "x", { id = "abc", startsAt = 5 }, { id = "1" } }, 0)).to.equal(
				nil
			)
		end)

		it("has Config's Events as ids with starts", function()
			local Config = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
			) :: any
			for _, entry in Config.UpdateEvents do
				expect(EventRsvp.due(entry.id, entry.startsAt, 0)).to.equal(true)
			end
		end)
	end)

	describe("EventRsvp.window (#3450)", function()
		it("opens 3 minutes into the session and shuts after 10", function()
			expect(EventRsvp.window(0)).to.equal(false)
			expect(EventRsvp.window(179)).to.equal(false)
			expect(EventRsvp.window(180)).to.equal(true)
			expect(EventRsvp.window(600)).to.equal(true)
			expect(EventRsvp.window(601)).to.equal(false)
		end)
	end)

	describe("EventRsvp.title", function()
		it("says today within twelve hours and soon after that", function()
			expect(EventRsvp.title(3600, 0):find("today", 1, true)).to.be.ok()
			expect(EventRsvp.title(EventRsvp.SOON_SECONDS + 10, 0):find("soon", 1, true)).to.be.ok()
		end)
	end)
end
