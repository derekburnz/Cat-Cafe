--!strict
-- The carry (Derek 2026-10-28: "hold it in your arms crossed arms and it should be either awake loafing or sitting in
-- your arms"): when a character's arms fold, how they ease, and how the cat on them moves. Avatar.carryArms,
-- Avatar.cradle and the HeldCat on the arms need a real character, so they are checked in Studio. Written by the
-- Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.carryPose
	local h = Presets.motion.held

	describe("Effects carry", function()
		it("folds the arms while a living character carries a cat", function()
			expect(Avatar.carrying("tabby", true)).to.equal(true)
			expect(Avatar.carrying("tabby", false)).to.equal(false)
			expect(Avatar.carrying(nil, true)).to.equal(false)
			expect(Avatar.carrying("", true)).to.equal(false)
			expect(Avatar.carrying(7, true)).to.equal(false)
		end)

		it("folds them over blendIn and lets go over blendOut, never past 0 or 1", function()
			local w = Avatar.holdWeight(0, true, c.blendIn / 2, c)
			expect(w).to.be.near(0.5, 1e-9)
			expect(Avatar.holdWeight(w, true, c.blendIn, c)).to.equal(1)
			expect(Avatar.holdWeight(1, false, c.blendOut / 2, c)).to.be.near(0.5, 1e-9)
			expect(Avatar.holdWeight(0.1, false, c.blendOut, c)).to.equal(0)
		end)

		it("keeps the net hold's easing when no blend is given", function()
			expect(Avatar.holdWeight(0, true, Presets.netHold.blendIn / 2)).to.be.near(0.5, 1e-9)
		end)

		it("crosses the forearms in front, the right over the left", function()
			local a = c.arms
			for _, side in { "L", "R" } do
				expect(a["sh" .. side] > 0 and a["sh" .. side] < 90).to.equal(true)
				expect(a["tw" .. side] > 0).to.equal(true)
				expect(a["sp" .. side] < 0).to.equal(true)
			end
			expect(a.elR > a.elL).to.equal(true)
			expect(c.forward < 0).to.equal(true) -- out in front of the chest
		end)

		it("loafs on the walking body, awake, breathing and looking about", function()
			local looked = 0
			local open = false
			for t = 0, h.lookSeconds, 0.05 do
				local o = Logic.idle("held", t, "walk")
				expect(o.loaf).to.equal(1)
				expect(o.bodyY).to.equal(0)
				expect(math.abs(o.headYaw) <= math.rad(h.look) + 1e-9).to.equal(true)
				looked = math.max(looked, math.abs(o.headYaw))
				if o.blink < 0.5 then
					open = true
				end
			end
			expect(looked > math.rad(h.look) * 0.9).to.equal(true)
			expect(open).to.equal(true)
		end)

		it("sits up on the sitting body and folds its legs on an older Part cat", function()
			local sit = Logic.idle("held", 1, "sit")
			expect(sit.loaf).to.equal(0)
			expect(sit.sink).to.equal(0)
			local parts = Logic.idle("held", 1, "parts")
			expect(parts.loaf).to.equal(0)
			expect(parts.sink).to.equal(1)
			expect(parts.pawFL).to.be.near(math.rad(90), 1e-9)
		end)
	end)
end
