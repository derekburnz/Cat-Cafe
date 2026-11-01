--!strict
-- Gold Leaf's real gold trims (F89 2c, luck-and-rare-moments.md: "a slow glint that sweeps across the trims every 5
-- seconds and a soft glow on them at night"): when the glint crosses, how brightly each trim catches it, and the
-- colour check that hands a trim back to its style. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects Gold Leaf trims", function()
		it("sweeps every 5 seconds and rests between crossings", function()
			local t = Presets.decorFx.trims
			expect(t.every).to.equal(5)
			expect(t.seconds < t.every).to.equal(true)
			expect(Logic.trimSweep(t.every + t.seconds + 0.01, t.every, t.seconds, -19, 19, 3)).to.equal(
				nil
			)
			expect(Logic.trimSweep(1, 0, 1, -19, 19, 3)).to.equal(nil)
		end)

		it("crosses from a band's width before the trims to a band's width past them", function()
			local start = Logic.trimSweep(10, 5, 2, -19, 19, 3)
			expect(close(start, -22)).to.equal(true)
			local middle = Logic.trimSweep(11, 5, 2, -19, 19, 3)
			expect(close(middle, 0)).to.equal(true)
			local late = Logic.trimSweep(11.999, 5, 2, -19, 19, 3)
			expect(late > 21.9 and late < 22).to.equal(true)
		end)

		it("lights a short trim fully under the band and not at all a band's width off", function()
			expect(Logic.trimGlint(-0.5, 0.5, 0, 3)).to.equal(1)
			expect(Logic.trimGlint(-0.5, 0.5, 3.5, 3)).to.equal(0)
			expect(Logic.trimGlint(-0.5, 0.5, -3.5, 3)).to.equal(0)
			expect(Logic.trimGlint(-0.5, 0.5, nil, 3)).to.equal(0)
			local near = Logic.trimGlint(-0.5, 0.5, 1, 3)
			local far = Logic.trimGlint(-0.5, 0.5, 2.5, 3)
			expect(near > far and far > 0 and near < 1).to.equal(true)
		end)

		it("lifts a long trim gently instead of flashing it whole", function()
			local cornice = Logic.trimGlint(-19, 19, 0, 3)
			expect(close(cornice, 6 / 38)).to.equal(true)
			expect(Logic.trimGlint(-3, 3, 0, 3)).to.equal(1) -- two band widths still flashes
		end)

		it("tells a style's recolour from its own write read back in 8 bits", function()
			local tolerance = Presets.decorFx.trims.tolerance
			local written = Color3.new(0.5, 0.4, 0.2)
			local readBack = Color3.fromRGB(128, 102, 51)
			expect(Logic.colourMoved(readBack, written, tolerance)).to.equal(false)
			expect(Logic.colourMoved(Color3.fromRGB(240, 230, 210), written, tolerance)).to.equal(
				true
			)
		end)

		it("keeps the night glow soft", function()
			local t = Presets.decorFx.trims
			expect(t.tag).to.equal("PaintTrim")
			expect(t.lights <= 4).to.equal(true)
			expect(t.brightness <= 0.5).to.equal(true)
			expect(t.night <= 0.4).to.equal(true)
			expect(Presets.emitters.decorGlint ~= nil).to.equal(true)
		end)
	end)
end
