--!strict
-- UI/Components/MoneyFlash.luau: the money counter flashes for lumps, not for the steady income ticks (#1026).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local MoneyFlash = require(Components:WaitForChild("MoneyFlash")) :: any

	describe("MoneyFlash.shouldFlash", function()
		it("stays still on the first render", function()
			expect(MoneyFlash.shouldFlash(nil, 500, 10)).to.equal(false)
		end)
		it("stays still for a 0.2 s income tick", function()
			expect(MoneyFlash.shouldFlash(1000, 1002, 10)).to.equal(false)
		end)
		it("stays still for a gain of exactly one second of income", function()
			expect(MoneyFlash.shouldFlash(1000, 1010, 10)).to.equal(false)
		end)
		it("stays still when the money goes down or a sync pulls it back", function()
			expect(MoneyFlash.shouldFlash(1000, 990, 10)).to.equal(false)
			expect(MoneyFlash.shouldFlash(1000, 1000, 10)).to.equal(false)
		end)
		it("flashes for a sale bigger than a second of income", function()
			expect(MoneyFlash.shouldFlash(1000, 1250, 10)).to.equal(true)
		end)
		it("flashes for any gain when there is no income", function()
			expect(MoneyFlash.shouldFlash(1000, 1001, 0)).to.equal(true)
			expect(MoneyFlash.shouldFlash(1000, 1001, nil)).to.equal(true)
		end)
	end)
end
