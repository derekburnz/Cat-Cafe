--!strict
-- UI/Components/ShortNumber.luau: the HUD counters' short numbers (golden-fish.md section 1, F52): exact below
-- 100,000, then K to Qi, always cut down so a counter never shows more than the player has.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local ShortNumber = require(Components:WaitForChild("ShortNumber")) :: any

	describe("ShortNumber.format", function()
		it("is exact with commas below 100,000", function()
			expect(ShortNumber.format(0)).to.equal("0")
			expect(ShortNumber.format(7)).to.equal("7")
			expect(ShortNumber.format(8420)).to.equal("8,420")
			expect(ShortNumber.format(99999)).to.equal("99,999")
			expect(ShortNumber.format(99999.9)).to.equal("99,999")
		end)

		it("cuts down instead of rounding up (Derek's 1.99M, not 2M)", function()
			expect(ShortNumber.format(1999999)).to.equal("1.99M")
			expect(ShortNumber.format(999999)).to.equal("999K")
			expect(ShortNumber.format(100999)).to.equal("100K")
			expect(ShortNumber.format(19999999)).to.equal("19.9M")
			expect(ShortNumber.format(999999999)).to.equal("999M")
		end)

		it("keeps three digits and drops trailing zeros", function()
			expect(ShortNumber.format(100000)).to.equal("100K")
			expect(ShortNumber.format(1000000)).to.equal("1M")
			expect(ShortNumber.format(1240000)).to.equal("1.24M")
			expect(ShortNumber.format(1500000)).to.equal("1.5M")
			expect(ShortNumber.format(1050000)).to.equal("1.05M")
			expect(ShortNumber.format(12345678)).to.equal("12.3M")
			expect(ShortNumber.format(123456789)).to.equal("123M")
			expect(ShortNumber.format(2500000000)).to.equal("2.5B")
		end)

		it("goes on through T, Qa and Qi", function()
			expect(ShortNumber.format(4.56e12)).to.equal("4.56T")
			expect(ShortNumber.format(7.89e15)).to.equal("7.89Qa")
			expect(ShortNumber.format(3e18)).to.equal("3Qi")
			expect(ShortNumber.format(4.2e20)).to.equal("420Qi")
			expect(ShortNumber.format(5e21)).to.equal("5,000Qi")
		end)

		it("handles signs and odd input without showing more", function()
			expect(ShortNumber.format(-1999999)).to.equal("-1.99M")
			expect(ShortNumber.format(-250)).to.equal("-250")
			expect(ShortNumber.format(-0.4)).to.equal("0")
			expect(ShortNumber.format(0 / 0)).to.equal("0")
		end)
	end)

	describe("ShortNumber.commas", function()
		it("groups thousands and cuts off fractions", function()
			expect(ShortNumber.commas(1234567)).to.equal("1,234,567")
			expect(ShortNumber.commas(999.9)).to.equal("999")
			expect(ShortNumber.commas(-1234)).to.equal("-1,234")
		end)
	end)
end
