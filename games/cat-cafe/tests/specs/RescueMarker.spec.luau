--!strict
-- UI/Components/RescueMarker.luau: the rescue bar's marker and zone (data-model section 10b).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local RescueMarker = require(Components:WaitForChild("RescueMarker")) :: any

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end

	describe("RescueMarker.position", function()
		it("slides out to the right end and back at speed bar lengths per second", function()
			expect(near(RescueMarker.position(10, 0, 1, 10), 0)).to.equal(true)
			expect(near(RescueMarker.position(10, 0, 1, 10.25), 0.25)).to.equal(true)
			expect(near(RescueMarker.position(10, 0, 1, 11), 1)).to.equal(true)
			expect(near(RescueMarker.position(10, 0, 1, 11.5), 0.5)).to.equal(true)
			expect(near(RescueMarker.position(10, 0, 1, 12), 0)).to.equal(true)
			expect(near(RescueMarker.position(10, 0, 0.8, 11), 0.8)).to.equal(true)
		end)

		it("starts at its phase and waits there before startsAt", function()
			expect(near(RescueMarker.position(10, 1.5, 1, 9), 0.5)).to.equal(true)
			expect(near(RescueMarker.position(10, 1.5, 1, 10.25), 0.25)).to.equal(true)
			expect(near(RescueMarker.position(10, 0.4, 1.6, 10), 0.4)).to.equal(true)
		end)

		it("stays between 0 and 1 over a long attempt", function()
			for step = 0, 300 do
				local position = RescueMarker.position(0, 0.7, 1.4, step * 0.05)
				expect(position >= 0 and position <= 1).to.equal(true)
			end
		end)
	end)

	describe("RescueMarker.inZone", function()
		it("counts the inside of the zone and the tolerance either side", function()
			expect(RescueMarker.inZone(0.5, 0.5, 0.3)).to.equal(true)
			expect(RescueMarker.inZone(0.649, 0.5, 0.3)).to.equal(true)
			expect(RescueMarker.inZone(0.66, 0.5, 0.3)).to.equal(false)
			expect(RescueMarker.inZone(0.67, 0.5, 0.3, 0.03)).to.equal(true)
			expect(RescueMarker.inZone(0.31, 0.5, 0.3, 0.03)).to.equal(false)
		end)
	end)
end
