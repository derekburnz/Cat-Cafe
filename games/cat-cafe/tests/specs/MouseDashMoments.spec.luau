--!strict
-- The Mouse Dash sound moments (#3296): UIController fires them by name and the Audio module binds its handlers by
-- the same names, so every one must exist in Moments. They were missing at the 2026-11-12 launch and the game was
-- silent. Written by the sound-designer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Moments = require(Client:WaitForChild("Moments")) :: any

	describe("Mouse Dash moments", function()
		it("has a signal for every sound the game fires", function()
			local names = {
				"MouseDashStart",
				"MouseDashPop",
				"MouseDashCatch",
				"MouseDashMiss",
				"MouseDashHeart",
				"MouseDashFaster",
				"MouseDashMilestone",
				"MouseDashEnd",
				-- the first arcade game's, fired the same way
				"ArcadeStart",
				"ArcadeMilestone",
				"ArcadeEnd",
			}
			for _, name in names do
				local signal = Moments[name]
				expect(signal ~= nil).to.equal(true)
				expect(type(signal.Connect)).to.equal("function")
				expect(type(signal.Fire)).to.equal("function")
			end
		end)

		it("passes a fired moment's arguments to a listener", function()
			local got: { any } = {}
			local connection = Moments.MouseDashCatch:Connect(
				function(points: number, kind: string, streak: number)
					got = { points, kind, streak }
				end
			)
			Moments.MouseDashCatch:Fire(7, "golden", 3)
			connection:Disconnect()
			expect(got[1]).to.equal(7)
			expect(got[2]).to.equal("golden")
			expect(got[3]).to.equal(3)
		end)
	end)
end
