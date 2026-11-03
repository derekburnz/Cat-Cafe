--!strict
-- The intro's cloud dip over a jump between far-apart places (#958; Derek 2026-11-03 00:50: "make the locations cuts
-- smoother"): the clouds cover the screen fully before the jump, Intro.CUT_LEAD after the hook, and are gone soon after
-- it. IntroCut.luau plays it through Clouds.luau, which needs a screen, so that part is checked in Studio. Written by
-- the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local p = Presets.introCut

	describe("Effects intro cloud dip", function()
		it("covers the screen fully over the jump and parts within about half a second", function()
			expect(Logic.cloudCover(0, p.plan)).to.equal(0)
			expect(p.plan.coverTo < p.cut and p.cut < p.plan.partFrom).to.equal(true)
			expect(Logic.cloudCover(p.cut, p.plan)).to.equal(1)
			expect(Logic.cloudCover(p.plan.coverTo, p.plan)).to.equal(1)
			expect(Logic.cloudCover(p.plan.partTo, p.plan)).to.equal(0)
			expect(p.plan.partTo - p.cut <= 0.4).to.equal(true) -- the next shot shows again quickly
		end)

		it("stays plain white, with no destination tint", function()
			expect(Logic.cloudTint(p.plan.partTo, p.plan)).to.equal(0)
		end)

		it("plays the whole dip between long cuts", function()
			local plan = Logic.introDip(p, nil, nil)
			for _, key in { "coverFrom", "coverTo", "partFrom", "partTo" } do
				expect(plan[key]).to.be.near(p.plan[key], 1e-9)
			end
			plan = Logic.introDip(p, 3, 2.5)
			expect(plan.coverFrom).to.be.near(p.plan.coverFrom, 1e-9)
			expect(plan.partTo).to.be.near(p.plan.partTo, 1e-9)
		end)

		it(
			"shortens its side around a short cut, so the camp tour shows clear over half the time",
			function()
				-- a cut of `seconds` between two dips: the last dip's parting and the next one's cover share it
				for _, seconds in { 0.2, 0.3, 0.45, 0.6, 0.8, 1.1, 1.5, 3 } do
					local into = Logic.introDip(p, nil, seconds) -- the jump into the cut
					local outOf = Logic.introDip(p, seconds, nil) -- the jump out of it
					local clearFrom = into.partTo - p.cut
					local clearTo = seconds - (p.cut - outOf.coverFrom)
					expect(clearTo - clearFrom >= seconds / 2 - 1e-9).to.equal(true)
					-- still fully covered over each jump, and in order
					expect(Logic.cloudCover(p.cut, into)).to.equal(1)
					expect(Logic.cloudCover(p.cut, outOf)).to.equal(1)
					expect(outOf.coverFrom >= 0 and outOf.coverFrom < outOf.coverTo).to.equal(true)
					expect(
						into.coverTo < p.cut
							and p.cut < into.partFrom
							and into.partFrom < into.partTo
					).to.equal(true)
				end
				-- the camp tour's 0.45 s cuts part within 0.15 s, as Gameplay-Engineer asked
				local camp = Logic.introDip(p, 0.45, 0.45)
				expect(camp.partTo - p.cut <= 0.15).to.equal(true)
			end
		)
	end)
end
