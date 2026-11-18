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

		it("picks the flight's destination, then where they stand, then what they held", function()
			expect(AreaWhole.pick("park", "alley", "alley")).to.equal("park")
			expect(AreaWhole.pick(nil, "alley", "park")).to.equal("alley")
			expect(AreaWhole.pick(nil, nil, "park")).to.equal("park")
			expect(AreaWhole.pick(nil, nil, nil)).to.equal(nil)
		end)
	end)
end
