--!strict
-- #4307: shared/Parallel runs the join's yielding calls side by side. The cloud test shim's task.wait never yields,
-- so a "web call" here parks in coroutine.yield until the spec answers it with task.spawn, as Roblox would.

return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Parallel = require(Shared:WaitForChild("Parallel"))

	-- Calls that wait until answered: `call(n)` parks and later gives n * 10 (or errors for n == 0).
	local function slowCalls()
		local pending: { thread } = {}
		local most = 0
		local function call(n: number): number
			table.insert(pending, coroutine.running())
			most = math.max(most, #pending)
			coroutine.yield()
			if n == 0 then
				error("boom")
			end
			return n * 10
		end
		local function answerOne()
			local thread = table.remove(pending, 1)
			if thread ~= nil then
				task.spawn(thread)
			end
		end
		local function answerAll()
			while #pending > 0 do
				answerOne()
			end
		end
		return {
			pending = pending,
			call = call,
			answerOne = answerOne,
			answerAll = answerAll,
			most = function(): number
				return most
			end,
		}
	end

	describe("Parallel.map", function()
		it("starts every call before any answers and gives the answers in order", function()
			local calls = slowCalls()
			local out: { number? }? = nil
			task.spawn(function()
				out = Parallel.map({ 3, 1, 2 }, 8, calls.call)
			end)
			expect(#calls.pending).to.equal(3)
			expect(out).to.equal(nil)
			calls.answerAll()
			local got = out :: any
			expect(got[1]).to.equal(30)
			expect(got[2]).to.equal(10)
			expect(got[3]).to.equal(20)
		end)

		it("waits for the last call", function()
			local calls = slowCalls()
			local out: { number? }? = nil
			task.spawn(function()
				out = Parallel.map({ 1, 2 }, 8, calls.call)
			end)
			calls.answerOne()
			expect(out).to.equal(nil)
			calls.answerOne()
			expect(out ~= nil).to.equal(true)
		end)

		it("returns at once when no call yields", function()
			local out = Parallel.map({ 1, 2 }, 8, function(n: number): number
				return n + 1
			end)
			expect(out[1]).to.equal(2)
			expect(out[2]).to.equal(3)
		end)

		it("never runs more than the limit at once", function()
			local calls = slowCalls()
			local items = {}
			for i = 1, 10 do
				items[i] = i
			end
			local out: { number? }? = nil
			task.spawn(function()
				out = Parallel.map(items, 3, calls.call)
			end)
			expect(#calls.pending).to.equal(3)
			calls.answerAll()
			expect(calls.most()).to.equal(3)
			local got = out :: any
			for i = 1, 10 do
				expect(got[i]).to.equal(i * 10)
			end
		end)

		it("gives nil for a call that errors and still answers the rest", function()
			local calls = slowCalls()
			local out: { number? }? = nil
			task.spawn(function()
				out = Parallel.map({ 1, 0, 3 }, 2, calls.call)
			end)
			calls.answerAll()
			local got = out :: any
			expect(got[1]).to.equal(10)
			expect(got[2]).to.equal(nil)
			expect(got[3]).to.equal(30)
		end)

		it("gives an empty list for no items", function()
			expect(#Parallel.map({}, 4, function(n: number): number
				return n
			end)).to.equal(0)
		end)
	end)

	describe("Parallel.start", function()
		it("runs alongside the caller and waits for a call still running", function()
			local calls = slowCalls()
			local wait = Parallel.start(function(): number
				return calls.call(7)
			end)
			expect(#calls.pending).to.equal(1) -- started, and the caller carried on
			local got: number? = nil
			task.spawn(function()
				got = wait()
			end)
			expect(got).to.equal(nil)
			calls.answerAll()
			expect(got).to.equal(70)
			expect(wait()).to.equal(70)
		end)

		it("answers at once for a call that already finished", function()
			local wait = Parallel.start(function(): string
				return "done"
			end)
			expect(wait()).to.equal("done")
		end)

		it("gives nil for a call that errors", function()
			local calls = slowCalls()
			local wait = Parallel.start(function(): number
				return calls.call(0)
			end)
			local got: number? = -1
			task.spawn(function()
				got = wait()
			end)
			calls.answerAll()
			expect(got).to.equal(nil)
		end)
	end)
end
