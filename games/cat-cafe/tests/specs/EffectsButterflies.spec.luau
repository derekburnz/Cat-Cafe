--!strict
-- Butterflies by day (Derek 2026-10-27 22:43): they wander the whole flower bed instead of one loop at the middle of
-- it, fly smoothly from spot to spot, and come and go, out for less than half the time so fewer show at once.
-- Written by the vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects butterflies", function()
		it("flies from spot to spot, still at both ends and never past them", function()
			local from, to = Vector3.new(-6, 0, 1), Vector3.new(8, 0, -2)
			local start, finish = Logic.butterflyLeg(from, to, 0), Logic.butterflyLeg(from, to, 1)
			expect((start - from).Magnitude < 1e-6 and (finish - to).Magnitude < 1e-6).to.equal(
				true
			)
			expect((Logic.butterflyLeg(from, to, -1) - from).Magnitude < 1e-6).to.equal(true)
			expect((Logic.butterflyLeg(from, to, 2) - to).Magnitude < 1e-6).to.equal(true)
			local last = -1
			for k = 0, 1, 0.05 do
				local along = (Logic.butterflyLeg(from, to, k) - from).Magnitude
				expect(along >= last - 1e-9).to.equal(true)
				last = along
			end
			-- eased: it covers less of the way in the first tenth than in the middle tenth
			local early = (Logic.butterflyLeg(from, to, 0.1) - from).Magnitude
			local middle = (Logic.butterflyLeg(from, to, 0.55) - Logic.butterflyLeg(from, to, 0.45)).Magnitude
			expect(early < middle).to.equal(true)
		end)

		it("fades in and out of each spell and shows nothing between them", function()
			expect(Logic.spell(-1, 10, 1)).to.equal(0)
			expect(Logic.spell(0, 10, 1)).to.equal(0)
			expect(Logic.spell(10, 10, 1)).to.equal(0)
			expect(Logic.spell(12, 10, 1)).to.equal(0)
			expect(Logic.spell(0.5, 10, 1)).to.be.near(0.5, 1e-9)
			expect(Logic.spell(5, 10, 1)).to.equal(1)
			expect(Logic.spell(9.75, 10, 1)).to.be.near(0.25, 1e-9)
			-- a spell shorter than two fades still peaks in the middle
			expect(Logic.spell(0.5, 1, 1)).to.equal(1)
			for age = 0, 10, 0.25 do
				local shown = Logic.spell(age, 10, 1)
				expect(shown >= 0 and shown <= 1).to.equal(true)
			end
		end)

		it("is out less than half the time, with whole fades in every spell", function()
			local b = Presets.butterfly
			for _, range in { b.out, b.away, b.firstAway } do
				expect(range[1] >= 0 and range[1] <= range[2]).to.equal(true)
			end
			expect(b.out[1] >= 2 * b.fade).to.equal(true)
			local out = (b.out[1] + b.out[2]) / 2
			local away = (b.away[1] + b.away[2]) / 2
			expect(out / (out + away) < 0.5).to.equal(true)
			expect(b.rise > 0 and b.fade > 0).to.equal(true)
		end)

		it("wanders a bed wider than its little loop, at a butterfly's pace", function()
			local b = Presets.butterfly
			expect(b.least.X > b.roam.X and b.least.Z > b.roam.Z).to.equal(true)
			expect(b.pad >= 0).to.equal(true)
			expect(b.speed > 0 and b.speed <= 6).to.equal(true)
			expect(b.legShortest > 0 and b.legShortest <= b.legLongest).to.equal(true)
			expect(b.hover.chance >= 0 and b.hover.chance < 1).to.equal(true)
			expect(b.hover.shortest > 0 and b.hover.shortest <= b.hover.longest).to.equal(true)
			expect(b.perSource >= 1).to.equal(true)
		end)
	end)
end
