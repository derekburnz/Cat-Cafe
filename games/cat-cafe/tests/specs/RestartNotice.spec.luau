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
		it("counts down in minutes, then seconds, then now, and says the cafe is saved", function()
			expect(RestartNotice.text(300)).to.equal(
				"Servers restart for an update in 5 minutes. Your cafe is saved."
			)
			expect(RestartNotice.text(180)).to.equal(
				"Servers restart for an update in 3 minutes. Your cafe is saved."
			)
			expect(RestartNotice.text(60)).to.equal(
				"Servers restart for an update in 1 minute. Your cafe is saved."
			)
			expect(RestartNotice.text(150)).to.equal(
				"Servers restart for an update in 3 minutes. Your cafe is saved."
			)
			expect(RestartNotice.text(30)).to.equal(
				"Servers restart for an update in 30 seconds. Your cafe is saved."
			)
			expect(RestartNotice.text(0.4)).to.equal(
				"Servers restart for an update in 1 second. Your cafe is saved."
			)
			expect(RestartNotice.text(0)).to.equal(
				"Servers restart for an update now. Your cafe is saved. Join again in a moment."
			)
		end)
	end)
end
