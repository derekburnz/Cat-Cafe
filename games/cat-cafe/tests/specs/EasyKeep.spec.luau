--!strict
-- shared/EasyKeep (#5311): the Dragon Keep's Warmth marks with `easyKeep` on and off.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local DragonKeep = require(Shared.DragonKeep) :: any
	local EasyKeep = require(Shared.EasyKeep) :: any

	local function marks(): { number }
		local out = {}
		for index, stage in DragonKeep.STAGES do
			out[index] = stage.warmth
		end
		return out
	end

	describe("easyKeep (#5311)", function()
		it("is off by default and the plain marks stand", function()
			expect(EasyKeep.on()).to.equal(false)
			expect(EasyKeep.apply(false)).to.equal(false)
			expect(table.concat(marks(), ",")).to.equal("50,300,1000,1400,2400")
			expect(DragonKeep.REKINDLE).to.equal(1500)
		end)

		it(
			"asks 50, 100, 250, 500 and 1,000 with Rekindle 500, and puts the plain ones back",
			function()
				expect(EasyKeep.apply(true)).to.equal(true)
				expect(table.concat(marks(), ",")).to.equal("50,100,250,500,1000")
				expect(DragonKeep.REKINDLE).to.equal(500)
				expect(EasyKeep.apply(true)).to.equal(false)
				expect(EasyKeep.apply(false)).to.equal(true)
				expect(table.concat(marks(), ",")).to.equal("50,300,1000,1400,2400")
				expect(DragonKeep.REKINDLE).to.equal(1500)
			end
		)

		it(
			"moves a save at 600 Warmth on Whelp to Elder with two hands queued, and takes nothing back",
			function()
				local save = DragonKeep.fresh()
				save.warmth = 600
				DragonKeep.regrow(save)
				expect(save.stage).to.equal(2) -- plain: 300 reached, 1,000 not
				local queued = #save.queue
				EasyKeep.apply(true)
				DragonKeep.regrow(save)
				expect(save.stage).to.equal(4)
				expect(#save.queue).to.equal(queued + 2)
				expect(#save.slots).to.equal(4)
				EasyKeep.apply(false)
				DragonKeep.regrow(save)
				expect(save.stage).to.equal(4)
				expect(#save.queue).to.equal(queued + 2)
			end
		)

		it("deals a Rekindle every 500 after Crowned, up to the hand cap", function()
			EasyKeep.apply(true)
			local save = DragonKeep.fresh()
			save.warmth = 1000 + 500 * 5
			DragonKeep.regrow(save)
			expect(save.stage).to.equal(5)
			local rekindles = 0
			for _, kind in save.queue do
				if kind == "rekindle" then
					rekindles += 1
				end
			end
			expect(rekindles).to.equal(DragonKeep.HAND_CAP)
			EasyKeep.apply(false)
		end)
	end)
end
