--!strict
-- Effects/TradeUnlock's timeline (#4280, Logic.tradeUnlock with Presets.tradeUnlock): the lock wiggles under the
-- flashing limit, opens before it falls, the words come with the opening, the icon flies last, and Reduce Motion
-- moves nothing.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local p = Presets.tradeUnlock

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects trade unlock", function()
		it("keeps its beats in order", function()
			expect(p.popIn <= p.wiggleAt).to.equal(true)
			expect(p.wiggleAt + p.wiggleSeconds <= p.openAt).to.equal(true)
			expect(p.openAt < p.fallAt).to.equal(true)
			expect(p.fallAt + p.fallSeconds < p.flyAt).to.equal(true)
		end)

		it("wiggles slower than 3 times a second", function()
			expect(p.wiggles / p.wiggleSeconds < 3).to.equal(true)
		end)

		it("pops in from nothing with the lock closed and no words", function()
			local first = Logic.tradeUnlock(0, p, false)
			expect(near(first.scale, 0)).to.equal(true)
			expect(first.open).to.equal(false)
			expect(near(first.words, 0)).to.equal(true)
			local settled = Logic.tradeUnlock(p.popIn, p, false)
			expect(near(settled.scale, 1)).to.equal(true)
		end)

		it("wiggles the closed lock and stands it upright before it opens", function()
			local quarter = p.wiggleAt + p.wiggleSeconds / (4 * p.wiggles)
			local mid = Logic.tradeUnlock(quarter, p, false)
			expect(math.abs(mid.tilt - p.wiggle) < 0.01).to.equal(true)
			expect(mid.open).to.equal(false)
			local after = Logic.tradeUnlock(p.wiggleAt + p.wiggleSeconds, p, false)
			expect(near(after.tilt, 0)).to.equal(true)
		end)

		it("opens, hops and shows the words before the lock falls", function()
			local opening = Logic.tradeUnlock((p.openAt + p.fallAt) / 2, p, false)
			expect(opening.open).to.equal(true)
			expect(opening.hop > 0).to.equal(true)
			expect(near(opening.fallY, 0)).to.equal(true)
			expect(near(opening.lockShown, 1)).to.equal(true)
			expect(opening.words > 0).to.equal(true)
		end)

		it("drops the lock away and fades it out", function()
			local falling = Logic.tradeUnlock(p.fallAt + p.fallSeconds / 2, p, false)
			expect(falling.fallY > 0).to.equal(true)
			expect(falling.fallSpin > 0).to.equal(true)
			expect(falling.lockShown < 1 and falling.lockShown > 0).to.equal(true)
			local gone = Logic.tradeUnlock(p.fallAt + p.fallSeconds, p, false)
			expect(near(gone.lockShown, 0)).to.equal(true)
			expect(near(gone.words, 1)).to.equal(true)
			expect(near(gone.fly, 0)).to.equal(true)
		end)

		it("flies the icon to the tile last and then ends", function()
			local before = Logic.tradeUnlock(p.flyAt, p, false)
			expect(near(before.fly, 0)).to.equal(true)
			expect(before.done).to.equal(false)
			local half = Logic.tradeUnlock(p.flyAt + p.fly / 2, p, false)
			expect(half.fly > 0 and half.fly < 1).to.equal(true)
			local last = Logic.tradeUnlock(p.flyAt + p.fly, p, false)
			expect(near(last.fly, 1)).to.equal(true)
			expect(near(last.words, 0)).to.equal(true)
			expect(last.done).to.equal(true)
		end)

		it("moves nothing with Reduce Motion", function()
			for _, t in { 0.1, p.stillOpen + 0.5, p.stillEnd - 0.1 } do
				local frame = Logic.tradeUnlock(t, p, true)
				expect(near(frame.scale, 1)).to.equal(true)
				expect(near(frame.tilt, 0)).to.equal(true)
				expect(near(frame.hop, 0)).to.equal(true)
				expect(near(frame.fallY, 0)).to.equal(true)
				expect(near(frame.fly, 0)).to.equal(true)
			end
			expect(Logic.tradeUnlock(p.stillOpen - 0.1, p, true).open).to.equal(false)
			local open = Logic.tradeUnlock(p.stillOpen + p.fade, p, true)
			expect(open.open).to.equal(true)
			expect(near(open.words, 1)).to.equal(true)
			expect(near(open.shown, 1)).to.equal(true)
			local ended = Logic.tradeUnlock(p.stillEnd + p.fade, p, true)
			expect(near(ended.shown, 0)).to.equal(true)
			expect(ended.done).to.equal(true)
		end)
	end)
end
