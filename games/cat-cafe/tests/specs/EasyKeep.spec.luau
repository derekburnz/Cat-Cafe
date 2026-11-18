--!strict
-- #5311 shared/EasyKeep and DragonKeep.setEasy: the easyKeep switch's Warmth goals, and a save that already reaches a
-- lowered stage. Each case puts the plain goals back.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local DragonKeep = require(Shared:WaitForChild("DragonKeep")) :: any
	local EasyKeep = require(Shared:WaitForChild("EasyKeep")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any

	local function goals(): { number }
		local out = {}
		for _, stage in DragonKeep.STAGES do
			table.insert(out, stage.warmth)
		end
		return out
	end

	describe("EasyKeep", function()
		afterEach(function()
			DragonKeep.setEasy(false)
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[EasyKeep.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, EasyKeep.FLAG)).to.be.ok()
		end)

		it(
			"asks 50, 100, 250, 500 and 1,000 with Rekindle 500 when on, and the old goals when off",
			function()
				DragonKeep.setEasy(true)
				expect(table.concat(goals(), ",")).to.equal("50,100,250,500,1000")
				expect(DragonKeep.REKINDLE).to.equal(500)
				DragonKeep.setEasy(false)
				expect(table.concat(goals(), ",")).to.equal("50,300,1000,1400,2400")
				expect(DragonKeep.REKINDLE).to.equal(1500)
			end
		)

		it("moves a save at 600 Warmth on Whelp to Elder with two stage hands", function()
			DragonKeep.setEasy(true)
			local save = DragonKeep.sanitize({ warmth = 600, stage = 2, slots = { "", "" } })
			expect(save.stage).to.equal(4)
			expect(#save.slots).to.equal(4)
			expect(#save.queue).to.equal(2)
			expect(save.queue[1]).to.equal("stage")
			expect(save.queue[2]).to.equal("stage")
		end)

		it("grows a loaded save when the switch goes on, once", function()
			local save = DragonKeep.sanitize({ warmth = 600, stage = 2, slots = { "", "" } })
			expect(save.stage).to.equal(2)
			DragonKeep.setEasy(true)
			expect(DragonKeep.regrow(save)).to.equal(true)
			expect(save.stage).to.equal(4)
			expect(DragonKeep.regrow(save)).to.equal(false)
		end)

		it("keeps Rekindle under the cap and takes nothing away when off again", function()
			DragonKeep.setEasy(true)
			local save = DragonKeep.sanitize({ warmth = 1000 + 500 * 5, stage = 0 })
			expect(save.stage).to.equal(5)
			local rekindles = 0
			for _, kind in save.queue do
				if kind == "rekindle" then
					rekindles += 1
				end
			end
			expect(rekindles).to.equal(DragonKeep.HAND_CAP)
			DragonKeep.setEasy(false)
			local again = DragonKeep.sanitize(save)
			expect(again.stage).to.equal(5)
			expect(again.warmth).to.equal(3500)
		end)
	end)
end
