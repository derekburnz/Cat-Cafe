--!strict
-- Effects/FlightClock: a shorter first cannon flight (CannonFlightScale) plays every beat in step.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FlightClock = require(Client:WaitForChild("Effects"):WaitForChild("FlightClock")) :: any

	describe("FlightClock", function()
		it("reads the scale, 1 when missing or bad, clamped", function()
			expect(FlightClock.scaleFrom(nil)).to.equal(1)
			expect(FlightClock.scaleFrom("fast")).to.equal(1)
			expect(FlightClock.scaleFrom(0 / 0)).to.equal(1)
			expect(FlightClock.scaleFrom(2 / 3)).to.equal(2 / 3)
			expect(FlightClock.scaleFrom(0)).to.equal(FlightClock.MIN)
			expect(FlightClock.scaleFrom(9)).to.equal(FlightClock.MAX)
		end)
		it("maps a 2.5 s first flight onto the usual 3.75 s beats", function()
			expect(math.abs(FlightClock.toBeats(2.5, 2 / 3) - 3.75) < 1e-9).to.equal(true)
			expect(math.abs(FlightClock.realAt(2.2, 2 / 3) - 2.2 * 2 / 3) < 1e-9).to.equal(true)
			expect(FlightClock.toBeats(1.5, 1)).to.equal(1.5)
		end)
		it("scales the cloud cutscene and leaves the usual one alone", function()
			local plan = {
				coverFrom = 1,
				coverTo = 2,
				partFrom = 3,
				partTo = 4,
				tintFrom = 1.5,
				tintTo = 2.5,
			}
			expect(FlightClock.clouds(plan, 1)).to.equal(plan)
			local short = FlightClock.clouds(plan, 0.5)
			expect(short.partTo).to.equal(2)
			expect(short.tintFrom).to.equal(0.75)
		end)
	end)
end
