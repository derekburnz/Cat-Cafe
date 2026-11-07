--!strict
-- shared/Cooldown.luau (#2324): every server cooldown refusal is "Cooling down Ns", the seconds left rounded up. (The client countdown is UI/Components/Cooldown, tested in Cooldown.spec.)
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Cooldown = require(Shared.Cooldown)

	describe("Cooldown.text", function()
		it("reads the seconds left, rounded up and never 0", function()
			expect(Cooldown.text(4.2)).to.equal("Cooling down 5s")
			expect(Cooldown.text(1)).to.equal("Cooling down 1s")
			expect(Cooldown.text(0.01)).to.equal("Cooling down 1s")
			expect(Cooldown.text(0)).to.equal("Cooling down 1s")
			expect(Cooldown.text(-3)).to.equal("Cooling down 1s")
			expect(Cooldown.text(0 / 0)).to.equal("Cooling down 1s")
		end)

		it("is recognised by isText and nothing else is", function()
			expect(Cooldown.isText(Cooldown.text(12))).to.equal(true)
			for _, other in { "Catch your breath first", "Cooling down", "Give it a moment", "" } do
				expect(Cooldown.isText(other)).to.equal(false)
			end
			expect(Cooldown.isText(nil)).to.equal(false)
		end)
	end)
end
