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
