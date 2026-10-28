--!strict
-- The Spin Wheel turns about its axle (Derek 2026-10-28 01:03: "right now it flips it over and over"): the axle is
-- the disc's thinnest axis pointing to the back of the station, whatever the Wheel's pivot says, and "up" across
-- the face stays square to it, so the pointer knocks sideways in the wheel's plane. Written by the vfx-animator for
-- QA to move into tests/specs next to EffectsWheel.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	local function near(a: Vector3, b: Vector3): boolean
		return (a - b).Magnitude < 1e-6
	end

	describe("Effects Spin Wheel axle", function()
		it("finds the axle from the placeholder's disc, not from its pivot", function()
			-- the placeholder Disc: 0.5 x 8 x 8, turned 90 degrees about Y, so its thin X axis points along -Z
			local right, up, look =
				Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)
			local size = Vector3.new(0.5, 8, 8)
			local back = Vector3.new(0, 0, 1) -- the station's front faces -Z
			expect(near(Logic.thinAxis(right, up, look, size, back), Vector3.new(0, 0, 1))).to.equal(
				true
			)
			-- the same station turned to face +X: the axle follows it round
			local turned = Logic.thinAxis(
				Vector3.new(1, 0, 0),
				up,
				Vector3.new(0, 0, -1),
				size,
				Vector3.new(-1, 0, 0)
			)
			expect(near(turned, Vector3.new(-1, 0, 0))).to.equal(true)
			-- a disc modelled unturned and thin along Z: its look vector (-Z) is turned round to the back
			local unturned = Logic.thinAxis(
				Vector3.new(1, 0, 0),
				up,
				Vector3.new(0, 0, -1),
				Vector3.new(8, 8, 0.3),
				back
			)
			expect(near(unturned, Vector3.new(0, 0, 1))).to.equal(true)
			-- and one lying flat, thin along Y
			expect(
				near(
					Logic.thinAxis(right, up, look, Vector3.new(8, 0.3, 8), back),
					Vector3.new(0, 1, 0)
				)
			).to.equal(true)
		end)

		it("keeps up across the face square to the axle", function()
			local back = Vector3.new(0, 0, 1)
			expect(near(Logic.wheelUp(Vector3.new(0, 0, 1), back), Vector3.new(0, 1, 0))).to.equal(
				true
			)
			local tilted = Vector3.new(0, 0.6, 0.8)
			local up = Logic.wheelUp(tilted, back)
			expect(math.abs(up:Dot(tilted)) < 1e-6).to.equal(true)
			expect(math.abs(up.Magnitude - 1) < 1e-6).to.equal(true)
			expect(up.Y > 0).to.equal(true)
			-- a wheel lying flat takes the station's back as up
			expect(near(Logic.wheelUp(Vector3.new(0, 1, 0), back), back)).to.equal(true)
		end)
	end)
end
