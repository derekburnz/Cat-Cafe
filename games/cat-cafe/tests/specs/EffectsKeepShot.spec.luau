--!strict
-- Effects/KeepShot (#4612): the Dragon Keep cutscene's camera looks down from above and over the walls at every
-- stage, and never stands lower than it was asked to.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local KeepShot = require(Effects:WaitForChild("KeepShot")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local c = Presets.dragonRise.camera

	local walls = { halfX = 7.5, halfZ = 7.5, top = 7.5 }

	-- the height of the line from look to eye where it crosses the front wall (z = -halfZ)
	local function overWall(eye: Vector3, look: Vector3): number
		local share = (-walls.halfZ - look.Z) / (eye.Z - look.Z)
		return look.Y + (eye.Y - look.Y) * share
	end

	describe("Effects keep shot", function()
		it("clears the walls and looks down at every stage", function()
			for _, stage in Presets.dragonRise.stages do
				local h = stage.height
				local distance = math.max(c.minDistance, c.distance * h + 4)
				local low = Vector3.new(c.side * distance, c.up * h + 1.5, -distance)
				local look = Vector3.new(0, h * c.lookUp, 0)
				local eye = KeepShot.lift(low, look, walls, c.wallGap, c.pitch)
				expect(overWall(eye, look) >= walls.top + c.wallGap - 1e-6).to.equal(true)
				local flat = math.sqrt((eye.X - look.X) ^ 2 + (eye.Z - look.Z) ^ 2)
				expect(math.atan2(eye.Y - look.Y, flat) >= c.pitch - 1e-6).to.equal(true)
				expect(eye.X).to.equal(low.X)
				expect(eye.Z).to.equal(low.Z)
			end
		end)

		it("never lowers a shot already high enough", function()
			local eye = Vector3.new(0, 80, -12)
			expect(KeepShot.lift(eye, Vector3.new(0, 2, 0), walls, 2, 0.6).Y).to.equal(80)
		end)

		it("leaves the walls alone when the dragon is out of the yard", function()
			local eye = KeepShot.lift(Vector3.new(0, 3, -40), Vector3.new(0, 20, -30), walls, 2, 0)
			expect(eye.Y).to.equal(3)
		end)

		it("measures the walls from the box's middle when it is off the yard centre", function()
			-- the box 4 studs toward the gate: its front wall at z = -11.5, not -7.5
			local off = { halfX = 7.5, halfZ = 7.5, top = 7.5, x = 0, z = -4 }
			local look = Vector3.new(0, 2, 0)
			local eye = KeepShot.lift(Vector3.new(0, 3, -20), look, off, 2, 0)
			local share = (-11.5 - look.Z) / (eye.Z - look.Z)
			expect(look.Y + (eye.Y - look.Y) * share >= 9.5 - 1e-6).to.equal(true)
			expect(KeepShot.walls(Vector3.new(1, 3.5, -4), Vector3.new(15, 7, 14), 12).z).to.equal(
				-4
			)
		end)

		it("reads the walls from the Keep's box, top capped", function()
			local read = KeepShot.walls(Vector3.new(0, 3.5, 0), Vector3.new(15, 7, 14), 12)
			expect(read.halfX).to.equal(7.5)
			expect(read.halfZ).to.equal(7)
			expect(math.abs(read.top - 7) < 1e-6).to.equal(true)
			expect(KeepShot.walls(Vector3.new(0, 25, 0), Vector3.new(15, 60, 14), 12).top).to.equal(
				12
			)
		end)
	end)
end
