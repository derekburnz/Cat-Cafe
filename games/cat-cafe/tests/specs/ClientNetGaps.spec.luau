--!strict
-- client/Net.luau: which presses are dropped inside their gap (SPACED) and which wait their turn (QUEUED).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Net = require(Client:WaitForChild("Net")) :: any

	describe("client Net gaps", function()
		it("never drops a Day Cart Buy all on the device: it waits its turn (#3646)", function()
			expect(Net.SPACED.BuyCornerShopAll).to.equal(nil)
			local gap = Net.QUEUED.BuyCornerShopAll
			expect(type(gap)).to.equal("number")
			-- the server takes 3 every 2 s: no faster than that, and a second section's press goes out within a second
			expect(gap >= 2 / 3).to.equal(true)
			expect(gap <= 1).to.equal(true)
		end)

		it("lists no remote both ways", function()
			for name in Net.SPACED do
				expect(Net.QUEUED[name]).to.equal(nil)
			end
		end)
	end)
end
