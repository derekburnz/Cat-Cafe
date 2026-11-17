--!strict
-- UI/Components/Spread.luau: queued label builds run a frame at a time within a budget, in order, at least one a frame.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Spread = require(Components:WaitForChild("Spread")) :: any

	-- a clock that moves `step` seconds each time it is read
	local function ticking(step: number): () -> number
		local now = 0
		return function(): number
			now += step
			return now
		end
	end

	describe("Spread", function()
		it("runs jobs in order until the budget is spent, at least one a frame", function()
			local ran: { number } = {}
			local jobs = {}
			for i = 1, 5 do
				table.insert(jobs, function()
					table.insert(ran, i)
				end)
			end
			-- each read moves 0.4 ms: the budget of 1 ms is spent after the third job
			expect(Spread.drain(jobs, ticking(0.0004), 0.001)).to.equal(3)
			expect(#jobs).to.equal(2)
			expect(ran[1]).to.equal(1)
			expect(ran[3]).to.equal(3)
			-- a job slower than the whole budget still runs alone
			expect(Spread.drain(jobs, ticking(0.01), 0.001)).to.equal(1)
			expect(#jobs).to.equal(1)
			expect(Spread.drain(jobs, ticking(0), 0.001)).to.equal(1)
			expect(#jobs).to.equal(0)
			expect(Spread.drain(jobs, ticking(0), 0.001)).to.equal(0)
		end)

		it("keeps going after a job that fails", function()
			local done = false
			local jobs = {
				function()
					error("boom")
				end,
				function()
					done = true
				end,
			}
			expect(Spread.drain(jobs, ticking(0), 0.001)).to.equal(2)
			expect(done).to.equal(true)
		end)
	end)
end
