--!strict
-- UI/Components/RichTipState.luau: what the rich tip marker shows from the plot attributes (data-model section 12).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local RichTipState = require(Components:WaitForChild("RichTipState")) :: any

	describe("RichTipState.read", function()
		it("shows the amount, whole seconds left and the share of the stay left", function()
			local view = RichTipState.read(1200, 1090, 1000, 90)
			expect(view).to.be.ok()
			expect(view.amount).to.equal(1200)
			expect(view.left).to.equal(90)
			expect(view.fraction).to.equal(1)
		end)

		it("rounds seconds up so a tip still there never reads 0:00", function()
			local view = RichTipState.read(50, 1000.4, 1000, 90)
			expect(view.left).to.equal(1)
		end)

		it("halves the bar halfway through the stay", function()
			local view = RichTipState.read(50, 1045, 1000, 90)
			expect(view.fraction).to.equal(0.5)
		end)

		it("shows nothing without a positive amount", function()
			expect(RichTipState.read(nil, 1090, 1000, 90)).never.to.be.ok()
			expect(RichTipState.read(0, 1090, 1000, 90)).never.to.be.ok()
			expect(RichTipState.read("1200", 1090, 1000, 90)).never.to.be.ok()
		end)

		it("shows nothing once the expiry has passed or when it is missing", function()
			expect(RichTipState.read(1200, 1000, 1000, 90)).never.to.be.ok()
			expect(RichTipState.read(1200, 990, 1000, 90)).never.to.be.ok()
			expect(RichTipState.read(1200, nil, 1000, 90)).never.to.be.ok()
		end)

		it("keeps the bar full when a longer stay than expected comes in", function()
			local view = RichTipState.read(50, 1200, 1000, 90)
			expect(view.fraction).to.equal(1)
		end)
	end)

	describe("RichTipState.clock", function()
		it("formats minutes and seconds", function()
			expect(RichTipState.clock(90)).to.equal("1:30")
			expect(RichTipState.clock(5)).to.equal("0:05")
			expect(RichTipState.clock(0)).to.equal("0:00")
		end)
	end)
end
