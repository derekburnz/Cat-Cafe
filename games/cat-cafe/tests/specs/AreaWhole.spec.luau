return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local AreaWhole =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AreaWhole")) :: any

	describe("AreaWhole", function()
		it(
			"keeps an area's chunks per player with the switch on and streams them as built with it off",
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
				expect((AreaWhole.pick(nil, 10, nil, nil))).to.equal(nil)
			end
		)

		it("lets the held area go a while after they leave it for the street or a cafe", function()
			-- Sync 2026-11-18: the first build kept the Alleyway whole all session
			expect((AreaWhole.pick(nil, 10, nil, "park", 5))).to.equal("park")
			expect((AreaWhole.pick(nil, 5 + AreaWhole.RELEASE_AFTER, nil, "park", 5))).to.equal(nil)
			expect((AreaWhole.pick(nil, 10, nil, "park", nil))).to.equal(nil)
		end)

		it("sends a few chunks at a time, always at least one", function()
			expect(AreaWhole.take({ 100, 100, 100, 100, 100 }, 400)).to.equal(4)
			expect(AreaWhole.take({ 700, 100 }, 400)).to.equal(1)
			expect(AreaWhole.take({ 100, 350 }, 400)).to.equal(1)
			expect(AreaWhole.take({}, 400)).to.equal(0)
			-- the rest of a step's budget, for the chunks coming off: only what fits
			expect(AreaWhole.take({ 100, 100 }, 150, false)).to.equal(1)
			expect(AreaWhole.take({ 300 }, 150, false)).to.equal(0)
			expect(AreaWhole.take({ 300 }, 400, false)).to.equal(1)
		end)

		it("cuts the ground into cells", function()
			expect(AreaWhole.cell(Vector3.new(10, 50, 10), 128)).to.equal("0,0")
			expect(AreaWhole.cell(Vector3.new(-10, 0, 130), 128)).to.equal("-1,1")
			expect(AreaWhole.cell(Vector3.new(127, 0, 0), 128)).to.equal(
				AreaWhole.cell(Vector3.new(1, 0, 5), 128)
			)
		end)
	end)
end
