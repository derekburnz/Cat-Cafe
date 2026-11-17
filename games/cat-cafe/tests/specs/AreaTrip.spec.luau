--!strict
-- UI/Components/AreaTrip.luau: an area's title card shows once a trip and never over a catch (#5050).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local AreaTrip = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("AreaTrip")
	) :: any
	local GAP = AreaTrip.GAP

	describe("AreaTrip", function()
		it("shows the first area once, and not again for a step out and back in", function()
			local trip = AreaTrip.new()
			expect(AreaTrip.due(trip, "alley", false, 0)).to.equal(true)
			AreaTrip.zone(trip, "alley", 0)
			AreaTrip.shown(trip, "alley", true, 0)
			-- Sync's run: 10 s out of the Alley box at the camp's edge and back in is the same trip
			AreaTrip.zone(trip, nil, 100)
			AreaTrip.zone(trip, "alley", 110)
			expect(AreaTrip.due(trip, "alley", false, 110)).to.equal(false)
		end)

		it("shows a landing's title once whether the trip or the zone reports it first", function()
			local trip = AreaTrip.new()
			-- the trip's result first: not inside yet
			expect(AreaTrip.due(trip, "alley", false, 0)).to.equal(true)
			AreaTrip.shown(trip, "alley", false, 0)
			AreaTrip.zone(trip, "alley", 1)
			expect(AreaTrip.due(trip, "alley", false, 1)).to.equal(false)
		end)

		it("shows it again after a real trip away, by walking or by flying back", function()
			local trip = AreaTrip.new()
			AreaTrip.zone(trip, "alley", 0)
			AreaTrip.shown(trip, "alley", true, 0)
			AreaTrip.zone(trip, nil, 10)
			AreaTrip.zone(trip, "alley", 10 + GAP)
			expect(AreaTrip.due(trip, "alley", false, 10 + GAP)).to.equal(true)
			AreaTrip.shown(trip, "alley", true, 10 + GAP)
			expect(AreaTrip.due(trip, "alley", false, 11 + GAP)).to.equal(false)
			-- a cannon trip back reports before the zone does
			AreaTrip.zone(trip, nil, 100)
			expect(AreaTrip.due(trip, "alley", false, 100 + GAP)).to.equal(true)
		end)

		it("always shows a different area, and never over a catch", function()
			local trip = AreaTrip.new()
			AreaTrip.zone(trip, "alley", 0)
			AreaTrip.shown(trip, "alley", true, 0)
			AreaTrip.zone(trip, "park", 5)
			expect(AreaTrip.due(trip, "park", false, 5)).to.equal(true)
			expect(AreaTrip.due(trip, "park", true, 5)).to.equal(false)
		end)
	end)
end
