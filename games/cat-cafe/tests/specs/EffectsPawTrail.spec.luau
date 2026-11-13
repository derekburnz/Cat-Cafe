--!strict
-- Effects/PawTrail (#3554): the guide trail's dots drawn as paw prints, left and right in turn, toes to the target.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local PawTrail = require(Effects:WaitForChild("PawTrail")) :: any

	describe("Effects paw trail", function()
		it("steps right and left in turn", function()
			expect(PawTrail.side(1)).to.equal(1)
			expect(PawTrail.side(2)).to.equal(-1)
			expect(PawTrail.side(3)).to.equal(1)
		end)

		it("faces the next dot and sits to the side of the line", function()
			local at, forward = PawTrail.place(1, Vector3.new(0, 1, 0), Vector3.new(0, 5, -10), 0.5)
			-- flat: a higher next dot never tips the print
			expect(math.abs(forward.Y) < 0.001).to.equal(true)
			expect(forward.Z < -0.99).to.equal(true)
			expect(math.abs(at.X - 0.5) < 0.001).to.equal(true)
			expect(math.abs(at.Y - 1) < 0.001).to.equal(true)
			local left = PawTrail.place(2, Vector3.new(0, 1, 0), Vector3.new(0, 1, -10), 0.5)
			expect(math.abs(left.X + 0.5) < 0.001).to.equal(true)
		end)

		it("stays put when there is no way to face", function()
			local at, forward = PawTrail.place(1, Vector3.new(3, 1, 4), Vector3.new(3, 9, 4), 0.5)
			expect((at - Vector3.new(3, 1, 4)).Magnitude < 0.001).to.equal(true)
			expect(forward).to.equal(nil)
		end)

		it("keeps the prints inside their part and apart from each other", function()
			local p = Presets.pawTrail
			expect(p.attribute).to.equal("Paws")
			-- GuideTrail's dots are 3.5 studs apart
			expect(p.size < 3.5).to.equal(true)
			expect(p.offset * 2 < p.size).to.equal(true)
			expect(#p.toes).to.equal(4)
			for _, toe in p.toes do
				expect(toe[1] - toe[3] / 2 >= 0).to.equal(true)
				expect(toe[1] + toe[3] / 2 <= 1).to.equal(true)
				expect(toe[2] - toe[4] / 2 >= 0).to.equal(true)
			end
		end)
	end)
end
