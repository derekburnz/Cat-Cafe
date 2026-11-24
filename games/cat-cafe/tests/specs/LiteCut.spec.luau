--!strict
-- shared/LiteCut.luau (#5686): the parkLite switch holds the Park backdrop's cut pieces out of the world.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
	local LiteCut = require(ReplicatedStorage.Shared.LiteCut)

	describe("LiteCut", function()
		it("is behind an off by default switch", function()
			expect(LiteCut.FLAG).to.equal("parkLite")
			expect(table.find(LiveFlags.KEYS, LiteCut.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[LiteCut.FLAG]).to.equal(true)
		end)

		it("keeps the tag rbx_export writes on the ring's _LiteCut model", function()
			expect(LiteCut.TAG).to.equal("LiteCut")
		end)

		it("holds a piece in the world when on and puts a held one back when off", function()
			expect(LiteCut.action(true, false)).to.equal("hold")
			expect(LiteCut.action(false, true)).to.equal("restore")
		end)

		it("leaves a piece alone when it is already where the switch wants it", function()
			expect(LiteCut.action(true, true)).to.equal("none")
			expect(LiteCut.action(false, false)).to.equal("none")
		end)
	end)
end
