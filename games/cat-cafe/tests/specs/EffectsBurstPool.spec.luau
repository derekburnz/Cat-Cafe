--!strict
-- #3743 (client memory over a long session): the pooled burst emitters stay bounded. One per preset, and tinted
-- ones in a recently-used list of Logic.BURST_TINTS_MAX, so a tint that changes every burst (the Lucky Cat's
-- rainbow twinkle) no longer adds an emitter for the rest of the session.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	describe("Effects burst pool", function()
		it("touchKey keeps the newest at the end and returns the oldest past the cap", function()
			local order: { string } = {}
			expect(Logic.touchKey(order, "a", 2)).to.equal(nil)
			expect(Logic.touchKey(order, "b", 2)).to.equal(nil)
			-- a used again moves to the newest end, so b is now the oldest
			expect(Logic.touchKey(order, "a", 2)).to.equal(nil)
			expect(order[1]).to.equal("b")
			expect(order[2]).to.equal("a")
			expect(Logic.touchKey(order, "c", 2)).to.equal("b")
			expect(#order).to.equal(2)
		end)

		it("never holds more than the cap, whatever comes in", function()
			local order: { string } = {}
			local dropped = 0
			for i = 1, 1000 do
				if
					Logic.touchKey(order, "k" .. tostring(i % 300), Logic.BURST_TINTS_MAX) ~= nil
				then
					dropped += 1
				end
			end
			expect(#order <= Logic.BURST_TINTS_MAX).to.equal(true)
			-- 300 keys in turn through 48 places: every touch is a new key, so each is either kept or dropped
			expect(dropped + #order).to.equal(1000)
		end)

		it("a cap well above the tints any one moment uses", function()
			expect(Logic.BURST_TINTS_MAX >= 32).to.equal(true)
			expect(Logic.BURST_TINTS_MAX <= 64).to.equal(true)
		end)
	end)
end
