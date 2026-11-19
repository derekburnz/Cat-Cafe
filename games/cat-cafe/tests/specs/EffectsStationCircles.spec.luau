--!strict
-- Effects/StationCircles (#4668): the walk-up rings show only for an explicit Station circles on.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local StationCircles =
		require(Client:WaitForChild("Effects"):WaitForChild("StationCircles")) :: any

	describe("Effects station circles", function()
		it("hides the rings unless the setting is true", function()
			expect(StationCircles.visible(true)).to.equal(true)
			expect(StationCircles.visible(false)).to.equal(false)
			expect(StationCircles.visible(nil)).to.equal(false)
			expect(StationCircles.visible("true")).to.equal(false)
		end)

		it("keeps a ring hidden while its station is locked here (#5463)", function()
			expect(StationCircles.FLAG).to.equal("lockedRingsHidden")
			expect(StationCircles.shownHere(true, nil)).to.equal(true)
			expect(StationCircles.shownHere(true, true)).to.equal(false)
			expect(StationCircles.shownHere(false, nil)).to.equal(false)
			expect(StationCircles.shownHere(true, false)).to.equal(true)
		end)

		it("hides the walk-up rings and the Codes Cat's circle, not their links", function()
			expect(StationCircles.isCircle("WalkUpCircle", "Part")).to.equal(true)
			expect(StationCircles.isCircle("WalkUpCircle", "ObjectValue")).to.equal(false)
			expect(StationCircles.isCircle("CodesCircle", "Model")).to.equal(true)
			expect(StationCircles.isCircle("CodesCircle", "Part")).to.equal(true)
			expect(StationCircles.isCircle("CodesGlow", "Part")).to.equal(true)
			expect(StationCircles.isCircle("CatCafe_Street_CodesCat_Glow", "Model")).to.equal(true)
			expect(StationCircles.isCircle("CatCafe_Street_CodesCat_Ticket_Decor", "Part")).to.equal(
				true
			)
			expect(StationCircles.isCircle("CatCafe_Street_CodesCat_Cat_Body", "Part")).to.equal(
				false
			)
			expect(StationCircles.isCircle("Counter", "Part")).to.equal(false)
		end)
	end)
end
