--!strict
-- #5026: far areas' night fences and camp cannons stream with the areaOnly switch on (shared/AreaOnly).

return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local AreaOnly = require(Shared:WaitForChild("AreaOnly"))

	describe("AreaOnly", function()
		it("is a live switch that starts off", function()
			expect(table.find(LiveFlags.KEYS, AreaOnly.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[AreaOnly.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[AreaOnly.FLAG]).to.equal(false)
		end)

		it("streams the fences with it on and keeps them as built with it off", function()
			expect(AreaOnly.fenceMode(true)).to.equal(Enum.ModelStreamingMode.Atomic)
			expect(AreaOnly.fenceMode(false)).to.equal(Enum.ModelStreamingMode.Persistent)
			expect(AreaOnly.STEP > 0).to.equal(true)
		end)

		it("keeps a cafe for its owner alone with it on, and for everyone with it off", function()
			expect(AreaOnly.cafeMode(true)).to.equal(Enum.ModelStreamingMode.PersistentPerPlayer)
			expect(AreaOnly.cafeMode(false)).to.equal(Enum.ModelStreamingMode.Persistent)
		end)

		it("streams every camp cannon and never the Town Square's", function()
			expect(AreaOnly.cannonStreams("alley")).to.equal(true)
			expect(AreaOnly.cannonStreams("castle")).to.equal(true)
			expect(AreaOnly.cannonStreams("town")).to.equal(false)
			expect(AreaOnly.cannonStreams(nil)).to.equal(false)
		end)
	end)
end
