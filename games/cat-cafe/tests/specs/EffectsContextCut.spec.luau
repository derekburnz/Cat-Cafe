--!strict
-- The context tips' camera cut (#976, easy-start.md section 3): where the camera looks from and how far over it is
-- through the cut. Taking the camera, the bars and the skip need a real client, so they are checked in Studio.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local p = Presets.contextCut

	describe("Effects context cut", function()
		it("looks from the camera's side, raised, at a distance that fits the place", function()
			local eye = Logic.cutEye(Vector3.new(0, 0, 0), 20, Vector3.new(100, 50, 0), p)
			local distance = 20 * p.fit
			expect(eye.X).to.be.near(distance, 1e-6)
			expect(eye.Z).to.be.near(0, 1e-6)
			expect(eye.Y).to.be.near(distance * p.rise, 1e-6)
		end)

		it("keeps small and huge places between near and far", function()
			local small = Logic.cutEye(Vector3.new(0, 0, 0), 1, Vector3.new(0, 0, 10), p)
			expect(small.Z).to.be.near(p.near, 1e-6)
			local huge = Logic.cutEye(Vector3.new(0, 0, 0), 1000, Vector3.new(0, 0, 10), p)
			expect(huge.Z).to.be.near(p.far, 1e-6)
		end)

		it("looks from the south when the camera is straight above", function()
			local eye = Logic.cutEye(Vector3.new(5, 0, 5), 20, Vector3.new(5, 80, 5), p)
			expect(eye.X).to.be.near(5, 1e-6)
			expect(eye.Z > 5).to.equal(true)
		end)

		it("swings out, holds and swings back inside the cut", function()
			expect(Logic.cutWeight(0, 3, p)).to.equal(0)
			expect(Logic.cutWeight(p.swingIn / 2, 3, p)).to.be.near(0.5, 1e-9)
			expect(Logic.cutWeight(1.5, 3, p)).to.equal(1)
			expect(Logic.cutWeight(3 - p.swingOut / 2, 3, p)).to.be.near(0.5, 1e-9)
			expect(Logic.cutWeight(3, 3, p)).to.equal(0)
			expect(Logic.cutWeight(-1, 3, p)).to.equal(0)
		end)

		it("jumps rather than swings with Reduce Motion", function()
			expect(Logic.cutWeight(0.05, 3, p, true)).to.equal(1)
			expect(Logic.cutWeight(2.95, 3, p, true)).to.equal(1)
			expect(Logic.cutWeight(3, 3, p, true)).to.equal(0)
		end)

		it("skips only after a second, inside a cut of three", function()
			expect(p.skipAfter).to.equal(1)
			expect(p.swingIn + p.swingOut < 3).to.equal(true)
		end)
	end)
end
