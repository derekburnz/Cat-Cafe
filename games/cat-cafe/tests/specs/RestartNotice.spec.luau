--!strict
-- shared/RestartNotice.luau: the restart countdown's warning (Derek 2026-10-29, decisions.md 2026-11-01), which every
-- server reads from MessagingService and toasts its players.
return function()
	local RestartNotice =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").RestartNotice)

	-- a stand-in for HttpService:JSONDecode that knows the countdown's shape and errors on anything else
	local function decode(text: string): unknown
		local seconds = string.match(text, '^{"kind":"restart","seconds":(%-?[%d%.]+)}$')
		if seconds == nil then
			error("Can't parse JSON")
		end
		return { kind = "restart", seconds = tonumber(seconds) }
	end

	describe("reading a message", function()
		it("listens on the countdown script's topic", function()
			expect(RestartNotice.TOPIC).to.equal("CatCafeAnnounce")
			expect(RestartNotice.MAX_SECONDS).to.equal(600)
		end)

		it("reads the countdown's JSON text at 300, 180, 60 and 0 seconds", function()
			for _, seconds in { 300, 180, 60, 0 } do
				local text = string.format('{"kind":"restart","seconds":%d}', seconds)
				expect(RestartNotice.parse(text, decode)).to.equal(seconds)
			end
			expect(RestartNotice.parse({ kind = "restart", seconds = 120 }, decode)).to.equal(120)
		end)

		it(
			"ignores anything else: other kinds, bad seconds, bad JSON, long text, other types",
			function()
				expect(RestartNotice.parse("hello", decode)).to.equal(nil)
				expect(RestartNotice.parse('{"kind":"restart","seconds":-1}', decode)).to.equal(nil)
				expect(RestartNotice.parse('{"kind":"restart","seconds":601}', decode)).to.equal(
					nil
				)
				expect(RestartNotice.parse('{"kind":"restart","seconds":1.5}', decode)).to.equal(
					nil
				)
				expect(RestartNotice.parse(string.rep("x", 201), decode)).to.equal(nil)
				expect(RestartNotice.parse({ kind = "shout", seconds = 60 }, decode)).to.equal(nil)
				expect(RestartNotice.parse({ kind = "restart", seconds = "60" }, decode)).to.equal(
					nil
				)
				expect(RestartNotice.parse({ kind = "restart", seconds = 0 / 0 }, decode)).to.equal(
					nil
				)
				expect(RestartNotice.parse({ kind = "restart" }, decode)).to.equal(nil)
				expect(RestartNotice.parse(nil, decode)).to.equal(nil)
				expect(RestartNotice.parse(60, decode)).to.equal(nil)
			end
		)
	end)

	describe("what players read", function()
		it(
			"counts down calmly in minutes, then seconds, then now, says the cafe is saved and promises the event",
			function()
				expect(RestartNotice.text(600)).to.equal(
					"A quick update is coming in 10 minutes, then a 30-minute event! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(120)).to.equal(
					"A quick update is coming in 2 minutes, then a 30-minute event! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(60)).to.equal(
					"A quick update is coming in 1 minute, then a 30-minute event! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(150)).to.equal(
					"A quick update is coming in 3 minutes, then a 30-minute event! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(30)).to.equal(
					"Quick update in 30 seconds, then a 30-minute event! Your cafe is saved."
				)
				expect(RestartNotice.text(0.4)).to.equal(
					"Quick update in 1 second, then a 30-minute event! Your cafe is saved."
				)
				expect(RestartNotice.text(0)).to.equal(
					"Updating now. Join again for a 30-minute event! Your cafe is saved."
				)
			end
		)

		it(
			"promises the 1 hour party and the gift around the 2026-11-12 launch only (#3420)",
			function()
				local at = RestartNotice.LAUNCH_AT
				expect(os.date("!%Y-%m-%d %H:%M", at)).to.equal("2026-11-12 22:00")
				expect(RestartNotice.text(600, at - 600)).to.equal(
					"A quick update is coming in 10 minutes, then a 1-hour party and a gift! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(30, at - 30)).to.equal(
					"Quick update in 30 seconds, then a 1-hour party and a gift! Your cafe is saved."
				)
				expect(RestartNotice.text(0, at)).to.equal(
					"Updating now. Join again for a 1-hour party and a gift! Your cafe is saved."
				)
				-- a late launch restart still says it; the day before and the day after do not
				expect(RestartNotice.text(0, at + 1800)).to.equal(
					"Updating now. Join again for a 1-hour party and a gift! Your cafe is saved."
				)
				-- #3535: the Friday update, a day later, says it too
				local friday = RestartNotice.LAUNCHES[2]
				expect(os.date("!%Y-%m-%d %H:%M", friday)).to.equal("2026-11-13 22:00")
				expect(RestartNotice.text(30, friday - 30)).to.equal(
					"Quick update in 30 seconds, then a 1-hour party and a gift! Your cafe is saved."
				)
				for _, now in
					{ at - 3601, at + 1801, at - 86400, friday + 1801, friday + 2 * 86400 }
				do
					expect(RestartNotice.text(600, now)).to.equal(RestartNotice.text(600))
					expect(RestartNotice.text(0, now)).to.equal(RestartNotice.text(0))
				end
			end
		)

		it(
			"names the admin events around the 2026-11-14, 2026-11-15 and 2026-11-21 updates (#4195)",
			function()
				local saturday, sunday, secrets =
					RestartNotice.ADMIN_LAUNCHES[1],
					RestartNotice.ADMIN_LAUNCHES[2],
					RestartNotice.ADMIN_LAUNCHES[3]
				expect(os.date("!%Y-%m-%d %H:%M", saturday)).to.equal("2026-11-14 22:00")
				expect(os.date("!%Y-%m-%d %H:%M", sunday)).to.equal("2026-11-15 20:00")
				expect(os.date("!%Y-%m-%d %H:%M", secrets)).to.equal("2026-11-16 03:30")
				expect(RestartNotice.text(600, saturday - 600)).to.equal(
					"A quick update is coming in 10 minutes, then ADMIN EVENTS: 2x money, Golden Hour and cat showers! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(0, saturday)).to.equal(
					"Updating now. Join again for ADMIN EVENTS: 2x money, Golden Hour and cat showers! Your cafe is saved."
				)
				-- Sunday's three areas and the Secrets update lead with their own headline
				expect(RestartNotice.text(600, sunday - 600)).to.equal(
					"A quick update is coming in 10 minutes, then 3 NEW WORLDS and ADMIN EVENTS! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(30, sunday - 30)).to.equal(
					"Quick update in 30 seconds, then 3 NEW WORLDS and ADMIN EVENTS! Your cafe is saved."
				)
				expect(RestartNotice.text(0, sunday)).to.equal(
					"Updating now. Join again for 3 NEW WORLDS and ADMIN EVENTS! Your cafe is saved."
				)
				expect(RestartNotice.text(600, secrets - 600)).to.equal(
					"A quick update is coming in 10 minutes, then 10 SECRET CATS and ADMIN EVENTS! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(0, secrets)).to.equal(
					"Updating now. Join again for 10 SECRET CATS and ADMIN EVENTS! Your cafe is saved."
				)
				local devices = RestartNotice.ADMIN_LAUNCHES[4]
				expect(os.date("!%Y-%m-%d %H:%M", devices)).to.equal("2026-11-18 20:00")
				expect(RestartNotice.text(600, devices - 600)).to.equal(
					"A quick update is coming in 10 minutes, then better controls and ADMIN EVENTS! Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(0, devices)).to.equal(
					"Updating now. Join again for better controls and ADMIN EVENTS! Your cafe is saved."
				)
				for _, now in
					{
						saturday - 3601,
						saturday + 1801,
						sunday + 1801,
						secrets - 3601,
						secrets + 1801,
					}
				do
					expect(RestartNotice.text(600, now)).to.equal(RestartNotice.text(600))
				end
			end
		)

		it("never says the word restart, which read as a warning to leave (#2720)", function()
			for _, seconds in { 600, 300, 120, 60, 30, 10, 0 } do
				expect(string.find(string.lower(RestartNotice.text(seconds)), "restart", 1, true)).to.equal(
					nil
				)
			end
		end)
	end)

	describe("how often and how loud (#2720)", function()
		it("shows only 10 minutes, 2 minutes, 1 minute, 30 seconds and now", function()
			for _, seconds in { 600, 120, 60, 30, 0 } do
				expect(RestartNotice.shows(seconds)).to.equal(true)
			end
			for _, seconds in { 300, 180, 10, 1, 599 } do
				expect(RestartNotice.shows(seconds)).to.equal(false)
			end
		end)

		it("the script's marks today show three notices; the lead's new marks show four", function()
			local function count(marks: { number }): number
				local n = 0
				for _, seconds in marks do
					if RestartNotice.shows(seconds) then
						n += 1
					end
				end
				return n
			end
			expect(count({ 600, 300, 180, 60, 10, 0 })).to.equal(3)
			expect(count({ 600, 120, 30, 0 })).to.equal(4)
		end)

		it("is calm info until the last minute, then a warning", function()
			expect(RestartNotice.kind(600)).to.equal("info")
			expect(RestartNotice.kind(120)).to.equal("info")
			expect(RestartNotice.kind(61)).to.equal("info")
			expect(RestartNotice.kind(60)).to.equal("warn")
			expect(RestartNotice.kind(30)).to.equal("warn")
			expect(RestartNotice.kind(0)).to.equal("warn")
		end)
	end)
end
