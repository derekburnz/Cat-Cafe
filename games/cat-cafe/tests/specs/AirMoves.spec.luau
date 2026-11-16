--!strict
-- AirMoves.luau (#4447): the Dragon Keep's Double Jump (a fresh press in the air, once a jump) and Glide (a held
-- jump holds the fall to GLIDE_FALL).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AirMoves = require(Shared.AirMoves)

	describe("AirMoves", function()
		it("jumps once more on a fresh press in the air, once until landing", function()
			local s = AirMoves.new()
			expect(AirMoves.request(s, 0, true)).to.equal(false) -- the ground jump
			AirMoves.leftGround(s, 0)
			expect(AirMoves.request(s, 0.05, true)).to.equal(false) -- still holding the first press
			expect(AirMoves.request(s, 0.5, true)).to.equal(true) -- let go, pressed again
			expect(AirMoves.request(s, 1.0, true)).to.equal(false) -- spent
			AirMoves.landed(s)
			AirMoves.leftGround(s, 2)
			expect(AirMoves.request(s, 2.5, true)).to.equal(true)
		end)

		it("never jumps again without the card or while holding the first jump", function()
			local s = AirMoves.new()
			AirMoves.request(s, 0, true)
			AirMoves.leftGround(s, 0)
			for t = 0.05, 1, 0.05 do
				expect(AirMoves.request(s, t, true)).to.equal(false) -- held the whole way
			end
			local off = AirMoves.new()
			AirMoves.leftGround(off, 0)
			expect(AirMoves.request(off, 0.5, false)).to.equal(false)
		end)

		it("holds the fall to GLIDE_FALL while jump is held in the air", function()
			local s = AirMoves.new()
			AirMoves.leftGround(s, 0)
			AirMoves.request(s, 1, true)
			expect(AirMoves.glideFall(s, 1.05, true, -30)).to.equal(-AirMoves.GLIDE_FALL)
			expect(AirMoves.glideFall(s, 1.05, true, -2)).to.equal(nil) -- falling slowly already
			expect(AirMoves.glideFall(s, 1.05, false, -30)).to.equal(nil) -- no card
			expect(AirMoves.glideFall(s, 1.5, true, -30)).to.equal(nil) -- let go
			AirMoves.landed(s)
			expect(AirMoves.glideFall(s, 1.05, true, -30)).to.equal(nil) -- on the ground
		end)
	end)
end
