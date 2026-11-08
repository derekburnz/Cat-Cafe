--!strict
-- shared/WalkUp.luau (#2398): walking up to a station opens its window once, walking away closes it, nothing opens
-- over a catch or another window, and the edge never flickers.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local WalkUp = require(Shared.WalkUp)

	local function at(key: string, distance: number?, window: string?): any
		return { key = key, window = window or key, distance = distance, radius = 6 }
	end

	describe("inside", function()
		it("comes in at the radius and leaves only LEAVE_EXTRA past it", function()
			expect(WalkUp.inside(false, 6, 6)).to.equal(true)
			expect(WalkUp.inside(false, 6.1, 6)).to.equal(false)
			expect(WalkUp.inside(true, 6 + WalkUp.LEAVE_EXTRA, 6)).to.equal(true)
			expect(WalkUp.inside(true, 6 + WalkUp.LEAVE_EXTRA + 0.1, 6)).to.equal(false)
			expect(WalkUp.inside(true, nil, 6)).to.equal(false)
			expect(WalkUp.inside(false, 0 / 0, 6)).to.equal(false)
		end)
	end)

	describe("step", function()
		it("opens on walking up, once, and closes on walking away", function()
			local state = WalkUp.new()
			local open, close = WalkUp.step(state, { at("spin", 20, "Spin") }, false, nil)
			expect(open).to.equal(nil)
			expect(close).to.equal(false)
			open, close = WalkUp.step(state, { at("spin", 5, "Spin") }, false, nil)
			expect(open).to.equal("spin")
			-- standing there opens nothing more
			open = WalkUp.step(state, { at("spin", 4, "Spin") }, false, "Spin")
			expect(open).to.equal(nil)
			open, close = WalkUp.step(state, { at("spin", 12, "Spin") }, false, "Spin")
			expect(open).to.equal(nil)
			expect(close).to.equal(true)
		end)

		it("opens nothing for a player who spawns or lands already there", function()
			local state = WalkUp.new()
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(nil)
			-- out and back in opens it
			WalkUp.step(state, { at("cannon", 20, "Cannon") }, false, nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal("cannon")
		end)

		it("never opens over a catch or another window, and waits for the next walk up", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("market", 30, "Market") }, false, nil)
			local open = WalkUp.step(state, { at("market", 3, "Market") }, true, nil)
			expect(open).to.equal(nil)
			-- the catch ended while standing there: nothing pops up
			open = WalkUp.step(state, { at("market", 3, "Market") }, false, nil)
			expect(open).to.equal(nil)
			local other = WalkUp.new()
			WalkUp.step(other, { at("market", 30, "Market") }, false, nil)
			open = WalkUp.step(other, { at("market", 3, "Market") }, false, "Store")
			expect(open).to.equal(nil)
		end)

		it("leaves a window closed by hand shut, and never closes a window the player opened", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("cannon", 30, "Cannon") }, false, nil)
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal("cannon")
			-- closed by hand, still standing there: it stays shut
			expect((WalkUp.step(state, { at("cannon", 3, "Cannon") }, false, nil))).to.equal(nil)
			-- the player opened the Store by hand, then walked off: the Store stays open
			local _, close = WalkUp.step(state, { at("cannon", 30, "Cannon") }, false, "Store")
			expect(close).to.equal(false)
		end)

		it("opens the nearest of two stations stepped into together", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("spin", 30, "Spin"), at("market", 30, "Market") }, false, nil)
			local open = WalkUp.step(state, { at("spin", 5, "Spin"), at("market", 3, "Market") }, false, nil)
			expect(open).to.equal("market")
		end)

		it("counts a station that left (the night market at sunrise) as walked away from", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("dealer", 30, "Dealer") }, false, nil)
			expect((WalkUp.step(state, { at("dealer", 2, "Dealer") }, false, nil))).to.equal("dealer")
			local open, close = WalkUp.step(state, {}, false, "Dealer")
			expect(open).to.equal(nil)
			expect(close).to.equal(true)
			expect(next(state.inside)).to.equal(nil)
		end)

		it("goes straight from one station's window to the next one's", function()
			local state = WalkUp.new()
			WalkUp.step(state, { at("spin", 30, "Spin"), at("market", 40, "Market") }, false, nil)
			WalkUp.step(state, { at("spin", 3, "Spin"), at("market", 40, "Market") }, false, nil)
			local open, close =
				WalkUp.step(state, { at("spin", 40, "Spin"), at("market", 3, "Market") }, false, "Spin")
			expect(open).to.equal("market")
			expect(close).to.equal(true)
		end)
	end)
end
