return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local AreaWhole =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AreaWhole")) :: any

	describe("AreaWhole", function()
		it(
			"keeps an area per player with the switch on and streams it as built with it off",
			function()
				expect(AreaWhole.mode(true)).to.equal(Enum.ModelStreamingMode.PersistentPerPlayer)
				expect(AreaWhole.mode(false)).to.equal(Enum.ModelStreamingMode.Default)
			end
		)

		it(
			"holds a flight's destination until they stand in it, then where they stand, then what they held",
			function()
				local flight = { area = "park", untilAt = 100 }
				-- a camp launch: still standing in the area it left, or over another on the way
				local area, stands = AreaWhole.pick(flight, 10, "alley", "alley")
				expect(area).to.equal("park")
				expect(stands).to.equal(true)
				area, stands = AreaWhole.pick(flight, 10, "castle", "park")
				expect(area).to.equal("park")
				expect(stands).to.equal(true)
				-- landed
				area, stands = AreaWhole.pick(flight, 10, "park", "park")
				expect(area).to.equal("park")
				expect(stands).to.equal(false)
				-- a flight cut short runs out
				area, stands = AreaWhole.pick(flight, 100, "alley", "park")
				expect(area).to.equal("alley")
				expect(stands).to.equal(false)
				expect((AreaWhole.pick(nil, 10, "alley", "park"))).to.equal("alley")
				expect((AreaWhole.pick(nil, 10, nil, "park"))).to.equal("park")
				expect((AreaWhole.pick(nil, 10, nil, nil))).to.equal(nil)
			end
		)
	end)
end
