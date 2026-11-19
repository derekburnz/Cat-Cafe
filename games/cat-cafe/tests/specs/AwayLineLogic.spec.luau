--!strict
-- client/UI/Components/AwayLineLogic.luau (#5505 part 2): the Rewards list's away row.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local AwayLineLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("AwayLineLogic")
	) :: any

	local function view(over: { [string]: any }): any
		local base: { [string]: any } = {
			on = true,
			played = 300,
			rate = 10,
			longNap = false,
			coins = 0,
			nextTier = nil,
			nextCost = nil,
		}
		for key, value in over do
			base[key] = value
		end
		return base
	end

	describe("AwayLineLogic", function()
		it("is a full away stretch at the rate, longer with Long Nap", function()
			expect(AwayLineLogic.amount(10, false)).to.equal(
				math.floor(10 * Config.OfflineRate * Config.OfflineCapSeconds)
			)
			expect(AwayLineLogic.amount(10, true)).to.equal(
				math.floor(10 * Config.OfflineRatePass * Config.OfflineCapPassSeconds)
			)
			expect(AwayLineLogic.amount(0, false)).to.equal(0)
		end)

		it("shows only from minute 4, with the switch on and a rate", function()
			expect((AwayLineLogic.line(view({ played = 239 })))).to.equal(nil)
			expect((AwayLineLogic.line(view({ on = false })))).to.equal(nil)
			expect((AwayLineLogic.line(view({ rate = 0 })))).to.equal(nil)
			local line, gold = AwayLineLogic.line(view({}))
			expect(string.find(line :: string, "^Away: about %$") ~= nil).to.equal(true)
			expect(gold).to.equal(false)
		end)

		it(
			"says it pays for the next tier only when the coins and the away money cover it",
			function()
				local amount = AwayLineLogic.amount(10, false)
				local line, gold =
					AwayLineLogic.line(view({ coins = 100, nextTier = 3, nextCost = 100 + amount }))
				expect(gold).to.equal(true)
				expect(string.find(line :: string, "Covers Tier 3's coins!", 1, true) ~= nil).to.equal(
					true
				)
				local _, short =
					AwayLineLogic.line(view({ coins = 100, nextTier = 3, nextCost = 101 + amount }))
				expect(short).to.equal(false)
				local _, already =
					AwayLineLogic.line(view({ coins = 500, nextTier = 3, nextCost = 400 }))
				expect(already).to.equal(false) -- can rank up now: nothing to wait for
			end
		)
	end)
end
