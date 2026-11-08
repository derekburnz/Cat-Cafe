--!strict
-- shared/PayBatch.luau (#2413): the cafe's money pop-ups at most once every GAP seconds, carrying everything paid
-- since the last one, written short (16400 -> "+$16K").
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local PayBatch = require(Shared.PayBatch)

	describe("PayBatch", function()
		it("floats the first payment at once", function()
			local batch = PayBatch.new()
			local now, wait = PayBatch.add(batch, 120, 10)
			expect(now).to.equal(120)
			expect(wait).to.equal(nil)
		end)

		it("holds the payments inside the gap and floats their sum once", function()
			local batch = PayBatch.new()
			PayBatch.add(batch, 100, 10)
			local now, wait = PayBatch.add(batch, 40, 12)
			expect(now).to.equal(nil)
			expect(wait).to.equal(PayBatch.GAP - 2)
			-- the next one inside the same wait asks for no second flush
			local again, waitAgain = PayBatch.add(batch, 60, 13)
			expect(again).to.equal(nil)
			expect(waitAgain).to.equal(nil)
			expect(PayBatch.flush(batch, 10 + PayBatch.GAP)).to.equal(100)
			expect(PayBatch.flush(batch, 10 + PayBatch.GAP)).to.equal(nil)
		end)

		it("floats again at once after a quiet gap", function()
			local batch = PayBatch.new()
			PayBatch.add(batch, 5, 0)
			expect((PayBatch.add(batch, 7, PayBatch.GAP + 1))).to.equal(7)
		end)

		it("adds nothing for a zero, a negative or a NaN", function()
			local batch = PayBatch.new()
			expect((PayBatch.add(batch, 0, 1))).to.equal(nil)
			expect((PayBatch.add(batch, -5, 1))).to.equal(nil)
			expect((PayBatch.add(batch, 0 / 0, 1))).to.equal(nil)
			expect(batch.amount).to.equal(0)
		end)

		it("writes the amount short, as the HUD does", function()
			expect(PayBatch.text(16400)).to.equal("+$16K")
			expect(PayBatch.text(2500000)).to.equal("+$2.5M")
			expect(PayBatch.text(840)).to.equal("+$840")
		end)
	end)
end
