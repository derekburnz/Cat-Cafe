--!strict
-- Self-test for the harness. If this file fails, no other spec result can be trusted.
return function()
	describe("TestKit expectations", function()
		it("equal and never.equal", function()
			expect(1 + 1).to.equal(2)
			expect("cat").never.to.equal("dog")
		end)

		it("ok", function()
			expect(0).to.be.ok()
			expect("").to.be.ok()
			expect(nil).never.to.be.ok()
			expect(false).never.to.be.ok()
		end)

		it("near", function()
			expect(0.1 + 0.2).to.be.near(0.3)
			expect(10).to.be.near(10.4, 0.5)
			expect(10).never.to.be.near(11, 0.5)
		end)

		it("type checks", function()
			expect(5).to.be.a("number")
			expect("x").to.be.a("string")
			expect({}).to.be.a("table")
			expect(print).to.be.a("function")
			expect(5).never.to.be.a("string")
		end)

		it("throw", function()
			expect(function()
				error("kaboom")
			end).to.throw()
			expect(function()
				error("kaboom")
			end).to.throw("kabo")
			expect(function() end).never.to.throw()
		end)

		it("deepEqual and contain (extensions)", function()
			expect({ a = 1, b = { 2, 3 } }).to.deepEqual({ a = 1, b = { 2, 3 } })
			expect({ a = 1 }).never.to.deepEqual({ a = 2 })
			expect({ "tabby", "calico" }).to.contain("calico")
			expect("Purr Pot").to.contain("Purr")
		end)
	end)

	describe("TestKit hooks", function()
		local log = {}

		beforeAll(function()
			table.insert(log, "beforeAll")
		end)
		beforeEach(function()
			table.insert(log, "beforeEach")
		end)
		afterEach(function()
			table.insert(log, "afterEach")
		end)

		it("runs beforeAll then beforeEach before the first test", function()
			expect(log[1]).to.equal("beforeAll")
			expect(log[2]).to.equal("beforeEach")
		end)

		it("runs afterEach between tests", function()
			expect(log[3]).to.equal("afterEach")
			expect(log[4]).to.equal("beforeEach")
		end)

		itSKIP("skipped tests are counted, not run", function()
			error("should never run")
		end)

		it("pending test with no body counts as skipped")
	end)
end
