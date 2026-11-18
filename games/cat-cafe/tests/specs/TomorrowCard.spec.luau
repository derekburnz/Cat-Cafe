--!strict
-- UI/Components/TomorrowCard.luau: the come back tomorrow card on a new account's first day (#3951).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local TomorrowCard = require(Components:WaitForChild("TomorrowCard")) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any
	local ReturnHook = require(Shared:WaitForChild("ReturnHook")) :: any

	local DAY = 20409 -- a UTC day number
	local NOW = DAY * 86400 + 3600

	local function moment(over: { [string]: any }?): any
		local m = {
			on = true,
			shown = false,
			kind = "gift",
			firstDay = DAY,
			now = NOW,
			played = 320,
			held = false,
			busy = false,
		}
		for key, value in over or {} do
			m[key] = value
		end
		return m
	end

	describe("TomorrowCard switch", function()
		it("is off by default and listed", function()
			expect(TomorrowCard.FLAG).to.equal("tomorrowCard")
			expect(LiveFlags.OFF_BY_DEFAULT.tomorrowCard).to.equal(true)
			expect(table.find(LiveFlags.KEYS, "tomorrowCard") ~= nil).to.equal(true)
			expect(LiveFlags.shown("tomorrowCard", nil)).to.equal(false)
		end)

		it("reports the same outcomes the server allows", function()
			expect(TomorrowCard.OUTCOMES).to.equal(ReturnHook.CARD_OUTCOMES)
			expect(table.find(TomorrowCard.OUTCOMES, "shown") ~= nil).to.equal(true)
		end)
	end)

	describe("TomorrowCard.due", function()
		it("shows on the first day once the hold ends", function()
			expect(TomorrowCard.due(moment())).to.equal(true)
		end)

		it("waits for the switch, the hold, a calm screen and the settle", function()
			expect(TomorrowCard.due(moment({ on = false }))).to.equal(false)
			expect(TomorrowCard.due(moment({ held = true }))).to.equal(false)
			expect(TomorrowCard.due(moment({ busy = true }))).to.equal(false)
			expect(TomorrowCard.due(moment({ played = TomorrowCard.SETTLE_SECONDS - 1 }))).to.equal(
				false
			)
			expect(TomorrowCard.due(moment({ played = TomorrowCard.SETTLE_SECONDS }))).to.equal(
				true
			)
		end)

		it("shows once a session", function()
			expect(TomorrowCard.due(moment({ shown = true }))).to.equal(false)
		end)

		it("names only the welcome back gift", function()
			expect(TomorrowCard.due(moment({ kind = "treat" }))).to.equal(false)
			local none = moment()
			none.kind = nil -- a nil in the override table is skipped, so clear it after building
			expect(TomorrowCard.due(none)).to.equal(false)
		end)

		it("is only for the account's first UTC day", function()
			expect(TomorrowCard.due(moment({ firstDay = DAY - 1 }))).to.equal(false)
			expect(TomorrowCard.due(moment({ firstDay = 0 }))).to.equal(false)
			expect(TomorrowCard.due(moment({ firstDay = "x" }))).to.equal(false)
			expect(TomorrowCard.due(moment({ now = (DAY + 1) * 86400 }))).to.equal(false)
			expect(TomorrowCard.due(moment({ now = (DAY + 1) * 86400 - 1 }))).to.equal(true)
		end)
	end)

	describe("TomorrowCard words", function()
		it("names the reason in the title, as a phone hides the line", function()
			expect(string.find(TomorrowCard.TITLE, "tomorrow", 1, true) ~= nil).to.equal(true)
			expect(string.find(string.lower(TomorrowCard.TITLE), "golden crate", 1, true) ~= nil).to.equal(true)
			expect(string.find(TomorrowCard.LINE, "Come back tomorrow", 1, true) ~= nil).to.equal(true)
			expect(
				string.find(string.lower(TomorrowCard.TITLE .. TomorrowCard.LINE), "free", 1, true)
			).to.equal(nil)
		end)

		it("never uses the banned wooden crate picture", function()
			expect(TomorrowCard.PICTURE).never.to.equal("rbxassetid://81784091360384")
		end)
	end)
end
