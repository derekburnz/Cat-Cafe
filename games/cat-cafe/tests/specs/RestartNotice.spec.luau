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
			"counts down calmly in minutes, then seconds, then now, and says the cafe is saved",
			function()
				expect(RestartNotice.text(600)).to.equal(
					"A quick update is coming in 10 minutes. Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(120)).to.equal(
					"A quick update is coming in 2 minutes. Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(60)).to.equal(
					"A quick update is coming in 1 minute. Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(150)).to.equal(
					"A quick update is coming in 3 minutes. Keep playing, your cafe is saved."
				)
				expect(RestartNotice.text(30)).to.equal(
					"Quick update in 30 seconds. Your cafe is saved."
				)
				expect(RestartNotice.text(0.4)).to.equal(
					"Quick update in 1 second. Your cafe is saved."
				)
				expect(RestartNotice.text(0)).to.equal(
					"Updating now. Your cafe is saved. Join again in a moment."
				)
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
