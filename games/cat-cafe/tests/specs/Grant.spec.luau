--!strict
-- shared/Grant.luau (#2127): a paid prize in steps. A step that throws loses only itself, and a first step that throws
-- before changing the save undoes the grant so the receipt is delivered again. Also Products.forget.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Grant = require(Shared.Grant)
	local Products = require(Shared.Products)

	local function steps(log: { string }, throwing: { [string]: boolean }): { Grant.Step }
		local out: { Grant.Step } = {}
		for _, name in { "mark", "potions", "toast" } do
			table.insert(out, {
				name = name,
				run = function()
					if throwing[name] then
						error("boom in " .. name)
					end
					table.insert(log, name)
				end,
			})
		end
		return out
	end

	describe("run", function()
		it("runs every step in order when nothing throws", function()
			local log: { string } = {}
			local result = Grant.run({
				name = "cats",
				run = function()
					table.insert(log, "cats")
				end,
			}, function()
				return true
			end, steps(log, {}))
			expect(result.undone).to.equal(false)
			expect(#result.failed).to.equal(0)
			expect(table.concat(log, ",")).to.equal("cats,mark,potions,toast")
		end)

		it("undoes the grant when the first step throws before changing anything", function()
			local log: { string } = {}
			local result = Grant.run({
				name = "cats",
				run = function()
					error("no such cat")
				end,
			}, function()
				return false
			end, steps(log, {}))
			expect(result.undone).to.equal(true)
			expect(result.failed[1]).to.equal("cats")
			expect(#log).to.equal(0) -- nothing else was paid
		end)

		it("keeps paying when the first step throws after it changed the save", function()
			local log: { string } = {}
			local result = Grant.run({
				name = "cats",
				run = function()
					table.insert(log, "cats")
					error("the cat joined but the plot refresh failed")
				end,
			}, function()
				return true
			end, steps(log, {}))
			expect(result.undone).to.equal(false)
			expect(result.failed[1]).to.equal("cats")
			expect(table.concat(log, ",")).to.equal("cats,mark,potions,toast")
		end)

		it("doesn't undo when it can't tell whether the save changed", function()
			local log: { string } = {}
			local result = Grant.run({
				name = "cats",
				run = function()
					error("boom")
				end,
			}, function(): boolean
				error("can't count")
			end, steps(log, {}))
			expect(result.undone).to.equal(false)
			expect(table.concat(log, ",")).to.equal("mark,potions,toast")
		end)

		it("loses only the step that throws later on", function()
			local log: { string } = {}
			local result = Grant.run({
				name = "cats",
				run = function() end,
			}, function()
				return false
			end, steps(log, { potions = true }))
			expect(result.undone).to.equal(false)
			expect(#result.failed).to.equal(1)
			expect(result.failed[1]).to.equal("potions")
			expect(string.find(result.errors[1], "boom in potions", 1, true) ~= nil).to.equal(true)
			expect(table.concat(log, ",")).to.equal("mark,toast")
		end)
	end)

	it("masks long digit runs in a logged error", function()
		local text = Grant.errorText("profile p_123456789 failed")
		expect(string.find(text, "123456789", 1, true)).to.equal(nil)
		expect(#Grant.errorText(string.rep("x", 500))).to.equal(120)
	end)

	describe("Products.forget", function()
		it("takes an id out again and leaves the others", function()
			local receipts: { string } = {}
			Products.record(receipts, "a")
			Products.record(receipts, "b")
			Products.forget(receipts, "a")
			expect(Products.granted(receipts, "a")).to.equal(false)
			expect(Products.granted(receipts, "b")).to.equal(true)
			Products.forget(receipts, "missing")
			expect(#receipts).to.equal(1)
		end)
	end)
end
