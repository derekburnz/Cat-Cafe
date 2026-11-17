--!strict
-- Old characters and Players who left are destroyed (shared/LeaveCleanup), so a long-lived server does not keep them.

return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local LeaveCleanup = require(Shared:WaitForChild("LeaveCleanup"))

	describe("LeaveCleanup", function()
		it("is a live switch that starts on", function()
			expect(table.find(LiveFlags.KEYS, LeaveCleanup.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[LeaveCleanup.FLAG]).to.equal(nil)
			expect(LiveFlags.defaults()[LeaveCleanup.FLAG]).to.equal(true)
		end)

		it("only takes a character that has left and is not the player's own any more", function()
			local folder = game:GetService("ReplicatedStorage")
			expect(LeaveCleanup.characterGone(nil, false)).to.equal(true)
			expect(LeaveCleanup.characterGone(nil, true)).to.equal(false)
			expect(LeaveCleanup.characterGone(folder, false)).to.equal(false)
			expect(LeaveCleanup.PLAYER_SECONDS >= 10).to.equal(true)
			expect(LeaveCleanup.CHARACTER_SECONDS > 0).to.equal(true)
		end)
	end)
end
