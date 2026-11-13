--!strict
-- shared/NetPing.luau (#3661): one ping reading a session, in milliseconds and a band.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local NetPing = require(Shared.NetPing)

	describe("NetPing", function()
		it("turns Roblox's seconds into whole milliseconds, capped", function()
			expect(NetPing.ms(0.0456)).to.equal(46)
			expect(NetPing.ms(0)).to.equal(0)
			expect(NetPing.ms(-1)).to.equal(0)
			expect(NetPing.ms(99)).to.equal(NetPing.MAX_MS)
			expect(NetPing.ms(nil)).to.equal(NetPing.MAX_MS)
			expect(NetPing.ms(0 / 0)).to.equal(NetPing.MAX_MS)
		end)

		it("names the band a reading falls in", function()
			expect(NetPing.band(0)).to.equal("under_80")
			expect(NetPing.band(79)).to.equal("under_80")
			expect(NetPing.band(80)).to.equal("80_150")
			expect(NetPing.band(149)).to.equal("80_150")
			expect(NetPing.band(150)).to.equal("150_300")
			expect(NetPing.band(300)).to.equal("300_up")
			expect(NetPing.band(NetPing.MAX_MS)).to.equal("300_up")
		end)
	end)
end
