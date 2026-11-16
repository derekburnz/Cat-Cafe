--!strict
-- AutoRankUp.luau (#4924): the Rank Up window opens by itself once a tier, on a calm screen.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local AutoRankUp =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("AutoRankUp"))
	local LiveFlags = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LiveFlags")
	)

	local function due(over: { [string]: any }): boolean
		local o: any = { on = true, tier = 1, ready = true, opened = false, calmFor = 2 }
		for k, v in over do
			o[k] = v
		end
		return AutoRankUp.due(o)
	end

	describe("AutoRankUp.due", function()
		it("opens a ready rank up on a calm screen", function()
			expect(due({})).to.equal(true)
			expect(due({ tier = 4 })).to.equal(true)
		end)

		it("waits for the screen to be calm long enough", function()
			expect(due({ calmFor = 0 })).to.equal(false)
			expect(due({ calmFor = AutoRankUp.CALM_SECONDS - 0.1 })).to.equal(false)
			expect(due({ calmFor = AutoRankUp.CALM_SECONDS })).to.equal(true)
		end)

		it(
			"never for a rank up that is not ready, already opened, or with the switch off",
			function()
				expect(due({ ready = false })).to.equal(false)
				expect(due({ opened = true })).to.equal(false)
				expect(due({ on = false })).to.equal(false)
			end
		)

		it("is a live switch that is on unless switched off", function()
			expect(table.find(LiveFlags.KEYS, AutoRankUp.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[AutoRankUp.FLAG]).to.equal(nil)
			expect(LiveFlags.shown(AutoRankUp.FLAG, nil)).to.equal(true)
		end)
	end)
end
