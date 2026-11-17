--!strict
-- #5026: far areas' night fences stream with the areaOnly switch on (shared/AreaOnly).

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
	end)
end
