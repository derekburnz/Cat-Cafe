--!strict
-- UI/Components/Wayfinding.luau: when location markers show, and which zones are safe.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Wayfinding = require(Components:WaitForChild("Wayfinding")) :: any

	describe("Wayfinding.alpha", function()
		it("hides a marker up close and shows it fully from FAR out", function()
			expect(Wayfinding.alpha(0)).to.equal(0)
			expect(Wayfinding.alpha(Wayfinding.NEAR)).to.equal(0)
			expect(Wayfinding.alpha(Wayfinding.FAR)).to.equal(1)
			expect(Wayfinding.alpha(500)).to.equal(1)
		end)

		it("fades in between NEAR and FAR", function()
			local middle = (Wayfinding.NEAR + Wayfinding.FAR) / 2
			expect(Wayfinding.alpha(middle)).to.be.near(0.5, 1e-9)
		end)

		it("treats NaN as hidden", function()
			expect(Wayfinding.alpha(0 / 0)).to.equal(0)
		end)
	end)

	describe("Wayfinding zones", function()
		it("counts the street and the cafes as safe", function()
			expect(Wayfinding.isSafe(nil)).to.equal(true)
			expect(Wayfinding.isSafe("Cafe")).to.equal(true)
			expect(Wayfinding.isSafe("Alley")).to.equal(false)
		end)

		it("names the area of a catching zone", function()
			expect(Wayfinding.areaOf("Alley")).to.equal("alley")
			expect(Wayfinding.areaOf("Neighbourhood")).to.equal("neighbourhood")
			expect(Wayfinding.areaOf("Cafe")).never.to.be.ok()
			expect(Wayfinding.areaOf(nil)).never.to.be.ok()
		end)
	end)
end
