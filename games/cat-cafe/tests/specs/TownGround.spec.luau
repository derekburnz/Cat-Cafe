--!strict
-- shared/TownGround.luau (#5357): the townGround switch keeps the Town paving and paw paths whole.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
	local TownGround = require(ReplicatedStorage.Shared.TownGround)

	describe("TownGround", function()
		it("is behind an off by default switch", function()
			expect(table.find(LiveFlags.KEYS, TownGround.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[TownGround.FLAG]).to.equal(true)
		end)

		it("keeps the tag WorldBuilder writes", function()
			expect(TownGround.TAG).to.equal("TownGround")
		end)

		it("is Persistent on and Default off", function()
			expect(TownGround.mode(true)).to.equal(Enum.ModelStreamingMode.Persistent)
			expect(TownGround.mode(false)).to.equal(Enum.ModelStreamingMode.Default)
		end)
	end)
end
