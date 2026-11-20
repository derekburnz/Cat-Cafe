--!strict
-- shared/StrayMeets (onboarding_v9, switch strayMeets): the Alleyway's waiting stray stands by the landing.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local StrayMeets = require(Shared.StrayMeets)

	describe("StrayMeets.point", function()
		it(
			"brings a far stray to MEET_STUDS from the pad, on its own side and at its own height",
			function()
				local pad = Vector3.new(10, 4, 0)
				local home = Vector3.new(10, 1, 25)
				local meet = StrayMeets.point(pad, home)
				expect(math.abs(meet.X - 10) < 1e-6).to.equal(true)
				expect(math.abs(meet.Z - StrayMeets.MEET_STUDS) < 1e-6).to.equal(true)
				expect(meet.Y).to.equal(1)
			end
		)
		it("leaves a stray that is already that near where it is", function()
			local pad = Vector3.new(0, 0, 0)
			local home = Vector3.new(3, 0, 4)
			expect(StrayMeets.point(pad, home)).to.equal(home)
		end)
	end)

	describe("StrayMeets.due", function()
		it("is only for the first catch by hand", function()
			expect(StrayMeets.due(0)).to.equal(true)
			expect(StrayMeets.due(1)).to.equal(false)
		end)
	end)
end
