--!strict
-- UI/Components/ShareCatchLogic.luau (#4911): the big catch card's "Share this catch!" button shows only for a
-- Mythical or Secret cat, with the switch on and sharing allowed, after the walk-through and five minutes of play,
-- once a session.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ShareCatchLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ShareCatchLogic")
	) :: any

	local function ask(changes: { [string]: any }?): any
		local base: { [string]: any } = {
			on = true,
			allowed = true,
			rarity = "Mythical",
			tutorialDone = true,
			played = ShareCatchLogic.PLAY_SECONDS,
			offered = false,
		}
		for key, value in changes or {} do
			base[key] = value
		end
		return base
	end

	describe("ShareCatchLogic.offer", function()
		it("offers a Mythical or Secret catch once everything allows it", function()
			expect(ShareCatchLogic.offer(ask())).to.equal(true)
			expect(ShareCatchLogic.offer(ask({ rarity = "Secret" }))).to.equal(true)
		end)

		it("never offers a Legendary or lower", function()
			for _, rarity in { "Legendary", "Epic", "Rare", "Common", "" } do
				expect(ShareCatchLogic.offer(ask({ rarity = rarity }))).to.equal(false)
			end
		end)

		it("stays hidden with the switch off or sharing not allowed (or not known yet)", function()
			expect(ShareCatchLogic.offer(ask({ on = false }))).to.equal(false)
			expect(ShareCatchLogic.offer(ask({ allowed = false }))).to.equal(false)
			local unknown = ask()
			unknown.allowed = nil
			expect(ShareCatchLogic.offer(unknown)).to.equal(false)
		end)

		it(
			"waits for the walk-through and five minutes of play, then shows once a session",
			function()
				expect(ShareCatchLogic.offer(ask({ tutorialDone = false }))).to.equal(false)
				expect(ShareCatchLogic.offer(ask({ played = ShareCatchLogic.PLAY_SECONDS - 1 }))).to.equal(
					false
				)
				expect(ShareCatchLogic.offer(ask({ offered = true }))).to.equal(false)
			end
		)

		it("joins through the shared picture carry the share launch data", function()
			expect(ShareCatchLogic.LAUNCH_DATA).to.equal("share_catch")
			expect(ShareCatchLogic.CLOSE_AT > 2.4).to.equal(true)
		end)
	end)
end
