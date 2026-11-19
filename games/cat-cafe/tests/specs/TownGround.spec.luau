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

		it("puts the local paw path behind its own off by default switch (#5471)", function()
			expect(table.find(LiveFlags.KEYS, TownGround.LOCAL_FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[TownGround.LOCAL_FLAG]).to.equal(true)
		end)

		it("round-trips the print list and skips broken pieces (#5471)", function()
			local prints = {
				{ x = 0.7, y = 0.135, z = -40.25, rotY = 180, r = 214, g = 84, b = 72 },
				{ x = -0.7, y = 0.115, z = 12, rotY = 0, r = 104, g = 196, b = 92 },
			}
			local back = TownGround.decode(TownGround.encode(prints) .. ";bad,1;")
			expect(#back).to.equal(2)
			expect(math.abs(back[1].z + 40.25) < 1e-6).to.equal(true)
			expect(back[1].rotY).to.equal(180)
			expect(back[2].g).to.equal(196)
			expect(#TownGround.decode(nil)).to.equal(0)
			expect(#TownGround.decode("")).to.equal(0)
		end)
	end)
end
