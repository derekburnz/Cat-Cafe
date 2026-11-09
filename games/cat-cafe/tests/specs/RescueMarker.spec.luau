--!strict
-- shared/RescueMarker.luau: the rescue bar's marker and zone (data-model section 10b), which the bar draws and
-- the server judges presses with (reviewer N74).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local RescueMarker = require(Shared:WaitForChild("RescueMarker")) :: any

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
	describe("RescueMarker.hitAt (#2318)", function()
		-- from server time 10 at the left end, two bar lengths a second: at 0.4 at 10.2 and 0.6 at 10.3
		it("counts a press up to SEEN_LAG after the marker left the zone", function()
			expect(RescueMarker.SEEN_LAG).to.equal(0.05)
			expect(RescueMarker.hitAt(10, 0, 2, 10.25, 0.5, 0.2, 0)).to.equal(true) -- inside
			expect(RescueMarker.hitAt(10, 0, 2, 10.32, 0.5, 0.2, 0)).to.equal(true) -- left 20 ms ago
			expect(RescueMarker.hitAt(10, 0, 2, 10.36, 0.5, 0.2, 0)).to.equal(false) -- left 60 ms ago
			expect(RescueMarker.hitAt(10, 0, 2, 10.18, 0.5, 0.2, 0)).to.equal(false) -- not there yet
		end)

		it("never looks back past the last judged press", function()
			expect(RescueMarker.hitAt(10, 0, 2, 10.32, 0.5, 0.2, 0, 10.31)).to.equal(false)
			expect(RescueMarker.hitAt(10, 0, 2, 10.32, 0.5, 0.2, 0, 10.29)).to.equal(true)
		end)

		it("catches a zone at the end the marker turned at in between", function()
			-- from 0.85 to the right end and back to 0.85 in the lag: both ends miss a zone at 0.9 to 1
			expect(RescueMarker.inZone(RescueMarker.position(10, 0.85, 6, 10.05), 0.95, 0.1)).to.equal(false)
			expect(RescueMarker.hitAt(10, 0.85, 6, 10.05, 0.95, 0.1, 0)).to.equal(true)
			expect(RescueMarker.hitAt(10, 0.85, 6, 10.05, 0.5, 0.1, 0)).to.equal(false)
		end)
	end)
end
