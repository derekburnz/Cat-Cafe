--!strict
-- UI/Components/EventRsvp.luau: the update Event's ask (#2766).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local EventRsvp = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("EventRsvp")
	) :: any
	local Config = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
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

		it(
			"moves on to the next Event 10 minutes after one starts, and asks nothing after the last",
			function()
				-- Derek 2026-11-14: the next update's ask waits QUIET_AFTER_SECONDS after an update went out
				expect(EventRsvp.next(list, 1000)).to.equal(nil)
				expect(EventRsvp.next(list, 1000 + EventRsvp.QUIET_AFTER_SECONDS - 1)).to.equal(nil)
				local id, at = EventRsvp.next(list, 1000 + EventRsvp.QUIET_AFTER_SECONDS)
				expect(id).to.equal("222")
				expect(at).to.equal(2000)
				expect(EventRsvp.next(list, 2000 + EventRsvp.QUIET_AFTER_SECONDS)).to.equal(nil)
			end
		)

		it("gives an Event's own ask words when its entry has them (#4026)", function()
			local worded = {
				{ id = "333", startsAt = 3000, title = "Packs!" },
				{ id = "444", startsAt = 4000 },
			}
			local _, _, words = EventRsvp.next(worded, 0)
			expect(words).to.equal("Packs!")
			local id, _, none = EventRsvp.next(worded, 3000 + EventRsvp.QUIET_AFTER_SECONDS)
			expect(id).to.equal("444")
			expect(none).to.equal(nil)
		end)

		it(
			"lists the Cat Outfit Packs Event for Saturday 22:00 UTC with its own words (#4026)",
			function()
				local id, at, words = EventRsvp.next(Config.UpdateEvents, 1794650000)
				expect(id).to.equal("4733999329807827538")
				expect(at).to.equal(1794693600)
				expect(type(words)).to.equal("string")
			end
		)

		it(
			"asks about Sunday's 3 New Worlds 10 minutes after tonight's update, then the Secrets, then Wednesday",
			function()
				expect(EventRsvp.next(Config.UpdateEvents, 1794693600 + 300)).to.equal(nil)
				local sunday = EventRsvp.next(Config.UpdateEvents, 1794693600 + 600)
				expect(sunday).to.equal("8139939288161845916")
				expect((EventRsvp.next(Config.UpdateEvents, 1794772800 + 600))).to.equal(
					"8700676156604678758"
				)
				expect((EventRsvp.next(Config.UpdateEvents, 1794799800 + 300))).to.equal(nil)
				expect((EventRsvp.next(Config.UpdateEvents, 1794799800 + 600))).to.equal(
					"6810389993696133776"
				)
			end
		)

		it("asks nothing for an empty or broken list", function()
			expect(EventRsvp.next({}, 0)).to.equal(nil)
			expect(EventRsvp.next(nil, 0)).to.equal(nil)
			expect(EventRsvp.next({ "x", { id = "abc", startsAt = 5 }, { id = "1" } }, 0)).to.equal(
				nil
			)
		end)

		it("has Config's Events as ids with starts", function()
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
