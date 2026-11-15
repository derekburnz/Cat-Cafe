--!strict
-- NightLights.luau (#4311): only the nearest night lights are on.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local NightLights = require(Shared.NightLights)

	describe("NightLights", function()
		it("is a switch that starts on", function()
			expect(table.find(LiveFlags.KEYS, NightLights.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[NightLights.FLAG]).to.equal(nil)
			expect(LiveFlags.defaults()[NightLights.FLAG]).to.equal(true)
		end)

		it("lights the nearest few within range only", function()
			local points = {
				Vector3.new(50, 0, 0),
				Vector3.new(10, 0, 0),
				Vector3.new(500, 0, 0),
				Vector3.new(0, 0, 30),
				Vector3.new(0, 0, 20),
			}
			local on = NightLights.nearest(points, Vector3.zero, 3, 100)
			expect(on[2]).to.equal(true)
			expect(on[5]).to.equal(true)
			expect(on[4]).to.equal(true)
			expect(on[1]).to.equal(nil)
			expect(on[3]).to.equal(nil)
		end)

		it("lights none past range and copes with no lights", function()
			expect(next(NightLights.nearest({ Vector3.new(999, 0, 0) }, Vector3.zero, 16, 160))).to.equal(
				nil
			)
			expect(next(NightLights.nearest({}, Vector3.zero, 16, 160))).to.equal(nil)
		end)

		it("breaks ties by order, the same every time", function()
			local points = { Vector3.new(10, 0, 0), Vector3.new(-10, 0, 0), Vector3.new(0, 10, 0) }
			local on = NightLights.nearest(points, Vector3.zero, 2, 100)
			expect(on[1]).to.equal(true)
			expect(on[2]).to.equal(true)
			expect(on[3]).to.equal(nil)
		end)
	end)
end
