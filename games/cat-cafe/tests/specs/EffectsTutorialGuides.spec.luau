--!strict
-- #5647 to #5650, #5660: the arrow line, the net hint, the big cannon flash and the Rank Up dim. Written by the
-- vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local GuideArrow = require(Effects:WaitForChild("GuideArrow")) :: any
	local NetHint = require(Effects:WaitForChild("NetHint")) :: any
	local WorldGlow = require(Effects:WaitForChild("WorldGlow")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local ArrowLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TutorialArrowLogic")
	) :: any

	describe("Tutorial guides", function()
		it("lays the arrow line toward the target and stops short of it", function()
			local p = Presets.guideArrow
			local spots = GuideArrow.lineSpots(100, p.ahead, p.spacing, p.count, p.short, p.arrive)
			expect(#spots).to.equal(p.count)
			expect(spots[1]).to.equal(p.ahead)
			expect(spots[2] - spots[1]).to.equal(p.spacing)
			local near = GuideArrow.lineSpots(12, p.ahead, p.spacing, p.count, p.short, p.arrive)
			for _, along in near do
				expect(along <= 12 - p.short).to.equal(true)
			end
			expect(#GuideArrow.lineSpots(p.arrive, p.ahead, p.spacing, p.count, p.short, p.arrive)).to.equal(
				0
			)
		end)

		it(
			"fades the line between its base and base plus fade, still with Reduce Motion",
			function()
				local p = Presets.guideArrow
				for t = 0, 3, 0.1 do
					local a =
						GuideArrow.lineFade(3, 8, t, p.lineBase, p.lineFade, p.linePeriod, false)
					expect(a >= p.lineBase - 1e-6 and a <= p.lineBase + p.lineFade + 1e-6).to.equal(
						true
					)
				end
				expect(GuideArrow.lineFade(3, 8, 1.7, p.lineBase, p.lineFade, p.linePeriod, true)).to.equal(
					p.lineBase
				)
			end
		)

		it("shows the net hint only early, with a cat in reach and the switch on", function()
			local u = Presets.netHint.untilCaught
			expect(NetHint.shows(true, true, 0, u)).to.equal(true)
			expect(NetHint.shows(true, true, u, u)).to.equal(false)
			expect(NetHint.shows(true, true, nil, u)).to.equal(false)
			expect(NetHint.shows(true, false, 0, u)).to.equal(false)
			expect(NetHint.shows(false, true, 0, u)).to.equal(false)
		end)

		it("picks the hint for the device", function()
			expect(NetHint.device(true, false, false, false)).to.equal("touch")
			expect(NetHint.device(false, false, true, false)).to.equal("gamepad")
			expect(NetHint.device(false, true, false, true)).to.equal("mouse")
			expect(NetHint.device(true, true, false, true)).to.equal("mouse")
			expect(NetHint.pressed(0.1, 0.8, 0.3, false)).to.equal(1)
			expect(NetHint.pressed(0.5, 0.8, 0.3, false)).to.equal(0)
			expect(NetHint.pressed(0.5, 0.8, 0.3, true)).to.equal(1)
		end)

		it("flashes the lit cannon harder, full with Reduce Motion", function()
			local p = Presets.worldGlow
			expect(WorldGlow.flashStrength(0, p.flashLow, p.flashPeriod, false)).to.equal(1)
			local low = WorldGlow.flashStrength(p.flashPeriod / 2, p.flashLow, p.flashPeriod, false)
			expect(math.abs(low - p.flashLow) < 1e-6).to.equal(true)
			expect(WorldGlow.flashStrength(0.3, p.flashLow, p.flashPeriod, true)).to.equal(1)
		end)

		it("dims a Rank Up step darker and leaves the rest", function()
			expect(ArrowLogic.rankShade(0.5, false)).to.equal(0.5)
			expect(ArrowLogic.rankShade(0.5, true) < 0.5).to.equal(true)
			expect(ArrowLogic.rankShade(1, true)).to.equal(1)
		end)
	end)
end
