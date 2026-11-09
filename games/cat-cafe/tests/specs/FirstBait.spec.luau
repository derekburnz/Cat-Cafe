--!strict
-- UI/Components/FirstBait.luau: the account's short first bait and its "A cat is coming!" cue (#1895).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FirstBait =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FirstBait")) :: any

	describe("FirstBait", function()
		it("caps the empty bowl's wait only before the first bait", function()
			local first = FirstBait.wait()
			expect(FirstBait.firstWait(true, 600)).to.equal(first)
			expect(FirstBait.firstWait(true, 30)).to.equal(30) -- #2774: below the 45 s first wait
			expect(FirstBait.firstWait(false, 600)).to.equal(600)
			expect(FirstBait.firstWait(nil, 600)).to.equal(600)
		end)

		it("calls a short day bait the first one and a normal or night bait not", function()
			local first = FirstBait.wait()
			expect(FirstBait.coming({ placedAt = 1000, readyAt = 1000 + first })).to.equal(true)
			expect(FirstBait.coming({ placedAt = 1000, readyAt = 1600 })).to.equal(false)
			expect(FirstBait.coming({ placedAt = 1000, readyAt = 1000 + first, night = true })).to.equal(false)
			expect(FirstBait.coming({ readyAt = 1100 })).to.equal(false)
			expect(FirstBait.coming(nil)).to.equal(false)
		end)

		it("counts down while it waits and goes when it is ready", function()
			local first = FirstBait.wait()
			local bait = { placedAt = 1000, readyAt = 1000 + first }
			expect(FirstBait.chip(bait, 1000 + first - 102)).to.equal("A cat is coming! 1m 42s")
			expect(FirstBait.chip(bait, 1000 + first)).to.equal(nil)
			expect(FirstBait.chip({ placedAt = 1000, readyAt = 1600 }, 1100)).to.equal(nil)
		end)
	end)
end
