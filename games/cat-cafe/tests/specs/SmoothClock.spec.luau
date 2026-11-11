--!strict
-- #3359: Components/SmoothClock, the Arcade board's steady server time. A clock sync correction eases in instead of
-- making the closing circle hop, time never runs backwards, and a far-off reading is taken at once.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local SmoothClock =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("SmoothClock"))

	local function fake()
		local state = { here = 100, offset = 5000 }
		local clock = SmoothClock.new(function(): number
			return state.here + state.offset
		end, function(): number
			return state.here
		end)
		return state, clock
	end

	describe("SmoothClock (#3359)", function()
		it("reads server time when the sync is steady", function()
			local state, clock = fake()
			expect(clock:now()).to.be.near(5100, 1e-9)
			state.here += 1 / 60
			expect(clock:now()).to.be.near(5100 + 1 / 60, 1e-9)
		end)

		it("eases a small correction in over frames instead of jumping", function()
			local state, clock = fake()
			clock:now()
			state.offset += 0.05 -- the sync moves server time 50 ms ahead
			state.here += 1 / 60
			local t = clock:now()
			local truth = state.here + state.offset
			expect(truth - t > 0.04).to.equal(true) -- most of the jump is still to come
			for _ = 1, 120 do
				state.here += 1 / 60
				t = clock:now()
			end
			expect(t).to.be.near(state.here + state.offset, 1e-3) -- caught up within two seconds
		end)

		it("never goes backwards when the sync moves server time back", function()
			local state, clock = fake()
			local last = clock:now()
			state.offset -= 0.2
			for _ = 1, 60 do
				state.here += 1 / 60
				local t = clock:now()
				expect(t >= last).to.equal(true)
				last = t
			end
		end)

		it("takes a far-off reading at once", function()
			local state, clock = fake()
			clock:now()
			state.offset += 2
			state.here += 1 / 60
			expect(clock:now()).to.be.near(state.here + state.offset, 1e-9)
		end)
	end)
end
