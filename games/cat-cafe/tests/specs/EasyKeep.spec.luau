--!strict
-- #5311 EasyKeep: the Dragon Keep's easier stage Warmths behind easyKeep.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local DragonKeep = require(Shared.DragonKeep)
	local EasyKeep = require(Shared.EasyKeep)

	local function warmths(): { number }
		local out = {}
		for _, stage in DragonKeep.STAGES do
			table.insert(out, stage.warmth)
		end
		return out
	end

	describe("EasyKeep", function()
		afterEach(function()
			EasyKeep.apply(false)
		end)

		it("is off unless the switch is true, and off keeps the plain numbers", function()
			expect(EasyKeep.on()).to.equal(false)
			EasyKeep.apply(false)
			local now = warmths()
			for index, warmth in EasyKeep.PLAIN do
				expect(now[index]).to.equal(warmth)
			end
			expect(DragonKeep.REKINDLE).to.equal(EasyKeep.PLAIN_REKINDLE)
		end)

		it("on: stages 50, 100, 250, 500, 1000 and Rekindle 500", function()
			EasyKeep.apply(true)
			local now = warmths()
			expect(#now).to.equal(5)
			for index, warmth in { 50, 100, 250, 500, 1000 } do
				expect(now[index]).to.equal(warmth)
			end
			expect(DragonKeep.REKINDLE).to.equal(500)
		end)

		it(
			"on: a save at 600 Warmth on Whelp loads as Elder with two stage hands queued",
			function()
				EasyKeep.apply(true)
				local save = DragonKeep.sanitize({ warmth = 600, stage = 2, slots = { "", "" } })
				expect(save.stage).to.equal(4)
				local stages = 0
				for _, kind in save.queue do
					if kind == "stage" then
						stages += 1
					end
				end
				expect(stages).to.equal(2)
				expect(#save.slots).to.equal(4)
			end
		)

		it("off again keeps a stage already reached", function()
			EasyKeep.apply(true)
			local save = DragonKeep.sanitize({ warmth = 600, stage = 2, slots = { "", "" } })
			EasyKeep.apply(false)
			local again = DragonKeep.sanitize(save)
			expect(again.stage).to.equal(4)
		end)
	end)
end
