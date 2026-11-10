--!strict
-- The first bait's cutscene (#2946): its eating dips, the camera spot round the bowl and the
-- timing against Design-Agent's spec. FirstBaitCut.luau moves the server's real bait cat and the camera, so how it
-- looks is checked in Studio. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.firstBaitCut

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects first bait cutscene", function()
		it("dips its head `bites` times while it eats and is still outside the eat", function()
			expect(Logic.baitEat(0, c.eat, c.bites, c.dip, c.pitch)).to.equal(0)
			expect(Logic.baitEat(c.eat, c.eat, c.bites, c.dip, c.pitch)).to.equal(0)
			local dips = 0
			local wasDown = false
			for i = 1, 199 do
				local dip, pitch = Logic.baitEat(c.eat * i / 200, c.eat, c.bites, c.dip, c.pitch)
				expect(dip <= c.dip + 1e-9 and dip >= 0).to.equal(true)
				expect(pitch <= c.pitch + 1e-9 and pitch >= 0).to.equal(true)
				local down = dip > c.dip * 0.9
				if down and not wasDown then
					dips += 1
				end
				wasDown = down
			end
			expect(dips).to.equal(c.bites)
		end)

		it(
			"puts the camera back and up from the bowl, swung round it by the given degrees",
			function()
				local look = Vector3.new(10, 2, -4)
				local toward = Vector3.new(0, 0, -1)
				local eye = Logic.cutAround(look, toward, c.back, c.up, 0)
				expect(near(eye.X, 10)).to.equal(true)
				expect(near(eye.Y, 2 + c.up)).to.equal(true)
				expect(near(eye.Z, -4 - c.back)).to.equal(true)
				for _, degrees in c.swings do
					local swung = Logic.cutAround(look, toward, c.back, c.up, degrees)
					local flat = Vector3.new(swung.X - look.X, 0, swung.Z - look.Z)
					expect(near(flat.Magnitude, c.back)).to.equal(true) -- always `back` studs out
				end
				local left = Logic.cutAround(look, toward, c.back, c.up, 90)
				local right = Logic.cutAround(look, toward, c.back, c.up, -90)
				expect(near(left.X + right.X, 2 * look.X)).to.equal(true) -- mirror images
			end
		)

		it("fits Design-Agent's timing and always gives the camera back", function()
			expect(near(c.swingIn + c.walk + c.eat + c.swingOut, 3.6)).to.equal(true)
			-- the longest run: the cat comes at the last moment, then walks, eats and swings back, inside the cap
			expect(c.waitCat + c.walkMax + c.eat + c.swingOut <= c.cap).to.equal(true)
			expect(c.skipAfter >= 0.3).to.equal(true) -- the bait press itself can't skip it
		end)
	end)
end
