--!strict
-- #4062 the Dragon Keep's stage-up cutscene, played live (Effects/DragonStageCut): which DragonStage values play and
-- the queue of stages reached at once. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local DragonStageCut =
		require(Client:WaitForChild("Effects"):WaitForChild("DragonStageCut")) :: any

	describe("Effects Dragon stage cutscene", function()
		it("plays only whole stages 1 to 5", function()
			for stage = 1, 5 do
				expect(DragonStageCut.valid(stage)).to.equal(true)
			end
			expect(DragonStageCut.valid(0)).to.equal(false)
			expect(DragonStageCut.valid(6)).to.equal(false)
			expect(DragonStageCut.valid(2.5)).to.equal(false)
			expect(DragonStageCut.valid("3")).to.equal(false)
			expect(DragonStageCut.valid(nil)).to.equal(false)
		end)

		it("queues several stages in order, once each, never more than five", function()
			local list = {}
			DragonStageCut.add(list, 3)
			DragonStageCut.add(list, 2)
			DragonStageCut.add(list, 3)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal(2)
			expect(list[2]).to.equal(3)
			for stage = 1, 5 do
				DragonStageCut.add(list, stage)
			end
			expect(#list).to.equal(5)
			expect(list[5]).to.equal(5)
		end)
	end)
end
