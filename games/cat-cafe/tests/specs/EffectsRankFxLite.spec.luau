--!strict
-- #5651: the Rank Up effects' off switch is a real, off-by-default LiveFlags key. Written by the vfx-animator.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any

	describe("Effects Rank Up lite", function()
		it("reads rankFxLite, which starts off", function()
			local key = Presets.rankUp.liteFlag
			expect(key).to.equal("rankFxLite")
			expect(table.find(LiveFlags.KEYS, key) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[key]).to.equal(true)
			expect(LiveFlags.shown(key, nil)).to.equal(false)
			expect(LiveFlags.shown(key, true)).to.equal(true)
		end)
	end)
end
