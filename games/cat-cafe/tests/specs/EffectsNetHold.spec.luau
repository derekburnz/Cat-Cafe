--!strict
-- The net hold (Derek 2026-10-28: "have your character holding a net while walking around until catching a cat"):
-- when a character holds its net, which net it shows and how the arm eases in and out. Avatar.holdNet, Avatar.netHand
-- and the net in the hand need a real character, so they are checked in Studio. Written by the Animation-Engineer
-- (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local h = Presets.netHold

	describe("Effects net hold", function()
		it("holds the net in a catching area, alive and with empty arms", function()
			expect(Avatar.holdsNet("Alley", nil, true)).to.equal(true)
			expect(Avatar.holdsNet("Sewer", nil, true)).to.equal(true)
		end)

		it(
			"puts it away on the street, in a cafe, while carrying a cat and when knocked out",
			function()
				expect(Avatar.holdsNet(nil, nil, true)).to.equal(false)
				expect(Avatar.holdsNet("Cafe", nil, true)).to.equal(false)
				expect(Avatar.holdsNet("Park", "cat_tabby", true)).to.equal(false)
				expect(Avatar.holdsNet("Park", nil, false)).to.equal(false)
			end
		)

		it("shows the Basic and Sturdy nets as the first model, then one model a level", function()
			expect(Avatar.netModel(0)).to.equal(1)
			expect(Avatar.netModel(1)).to.equal(1)
			expect(Avatar.netModel(2)).to.equal(2)
			expect(Avatar.netModel(3)).to.equal(3)
		end)

		it("shows the Basic net for a missing or odd NetLevel", function()
			expect(Avatar.netModel(nil)).to.equal(1)
			expect(Avatar.netModel("3")).to.equal(1)
			expect(Avatar.netModel(0 / 0)).to.equal(1)
			expect(Avatar.netModel(-2)).to.equal(1)
			expect(Avatar.netModel(9)).to.equal(3)
			expect(Avatar.netModel(2.7)).to.equal(2)
		end)

		it("raises the arm over blendIn and lowers it over blendOut, never past 0 or 1", function()
			local w = Avatar.holdWeight(0, true, h.blendIn / 2)
			expect(w).to.be.near(0.5, 1e-9)
			expect(Avatar.holdWeight(w, true, h.blendIn)).to.equal(1)
			expect(Avatar.holdWeight(1, false, h.blendOut / 2)).to.be.near(0.5, 1e-9)
			expect(Avatar.holdWeight(0.1, false, h.blendOut)).to.equal(0)
		end)

		it("leans the pole ahead and up, never flat or back over the head", function()
			local lean = h.sh + h.el + h.tilt -- degrees up from straight ahead (R15)
			local lean6 = h.sh6 + h.tilt6 -- the same on R6
			for _, angle in { lean, lean6 } do
				expect(angle > 30 and angle < 80).to.equal(true)
			end
			expect(h.showAt > 0 and h.showAt < 1).to.equal(true)
		end)
	end)
end
