--!strict
-- The Balloon Cat's bob (design v0.13, F78: "it bobs as if it might float off"): the whole cat lifts off its paws
-- and settles back, every few bobs pulled higher. Written by the Animation-Engineer (QA said new specs may go
-- straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local f = Presets.motion.float

	local function lift(t: number, share: number?): number
		local o = Logic.blank()
		Logic.float(o, t, share or 1)
		return o.bodyY
	end

	describe("Effects Balloon Cat float", function()
		it("floats only the cats listed, Balloon Cat among them", function()
			expect(f.cats.balloon).to.equal(true)
			expect(f.cats.tabby).to.equal(nil)
		end)

		it("lifts off its paws, hangs at the top and settles back to rest on them", function()
			expect(lift(0)).to.be.near(0, 1e-9)
			expect(lift(f.rise * f.seconds)).to.be.near(f.studs, 1e-9)
			expect(lift(0.25 * f.rise * f.seconds) > 0).to.equal(true)
			local resting = (f.rise + f.fall + 0.5 * (1 - f.rise - f.fall)) * f.seconds
			expect(lift(resting)).to.be.near(0, 1e-9) -- back on its paws before the next bob
			for t = 0, 3 * f.seconds, 0.05 do
				expect(lift(t) >= 0 and lift(t) <= f.studs + 1e-9).to.equal(true)
			end
		end)

		it("is pulled higher every few bobs", function()
			local top = (f.tugEvery - 1 + f.rise) * f.seconds
			expect(lift(top)).to.be.near(f.tugStuds, 1e-9)
			expect(f.tugStuds > f.studs).to.equal(true)
			expect(lift(top + f.tugEvery * f.seconds)).to.be.near(f.tugStuds, 1e-9)
		end)

		it("floats less asleep or loafing and not at all stuck in a trap", function()
			expect(Logic.floatShare("stray")).to.equal(1)
			expect(Logic.floatShare("barista")).to.equal(1)
			expect(Logic.floatShare("nap")).to.equal(f.resting)
			expect(Logic.floatShare("loaf")).to.equal(f.resting)
			expect(Logic.floatShare("doze")).to.equal(f.resting)
			expect(Logic.floatShare("stuck")).to.equal(0)
			local top = f.rise * f.seconds
			expect(lift(top, f.resting)).to.be.near(f.studs * f.resting, 1e-9)
			local o = Logic.idle("stray", top)
			local before = o.bodyY
			Logic.float(o, top, 0)
			expect(o.bodyY).to.equal(before)
		end)

		it("hangs its legs and lifts its tail, but a lying cat keeps its legs folded", function()
			local top = f.rise * f.seconds
			local standing = Logic.idle("stray", top)
			local paw, tail = standing.pawFL, standing.tailPitch
			Logic.float(standing, top, 1)
			expect(standing.pawFL > paw).to.equal(true)
			expect(standing.tailPitch > tail).to.equal(true)
			local napping = Logic.idle("nap", top)
			local folded = napping.pawFL
			Logic.float(napping, top, f.resting)
			expect(napping.pawFL).to.equal(folded)
			expect(napping.bodyY > 0).to.equal(true)
		end)
	end)
end
