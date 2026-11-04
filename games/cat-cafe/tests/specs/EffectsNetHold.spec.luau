--!strict
-- The net hold (Derek 2026-10-28: "have your character holding a net while walking around until catching a cat",
-- back over the shoulder; F93, catch-rework.md section 1: at all times, put away while a cat is in the arms) and the
-- net smack: when a
-- character holds its net, which net it shows, how the arm eases in and out and how the 0.62 s smack moves it.
-- Avatar.holdNet, Avatar.netHand and the net in the hand need a real character, so they are checked in Studio.
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Avatar = require(Effects:WaitForChild("Avatar")) :: any
	local Config = require(Shared:WaitForChild("Config")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local h = Presets.netHold
	local k = Presets.netSmack

	-- Degrees up from straight ahead the pole points with this arm (R15, then R6, which has no waist).
	local function pole(arm: any): number
		return arm.sh + arm.el + h.tilt - arm.waist
	end
	local function pole6(arm: any): number
		return arm.sh6 + h.tilt6
	end
	local function same(a: any, b: any, within: number?)
		for _, key in { "sh", "tw", "sp", "el", "sh6", "waist" } do
			expect(a[key]).to.be.near(b[key], within or 1e-6)
		end
	end

	describe("Effects net hold", function()
		it("holds the net everywhere, alive and with empty arms", function()
			expect(Avatar.holdsNet(nil, nil, true, nil)).to.equal(true)
			expect(Avatar.holdsNet(nil, false, true, false)).to.equal(true)
		end)

		it(
			"puts it away while carrying a cat, when the server hides it, in a cannon flight and when knocked out",
			function()
				expect(Avatar.holdsNet("cat_tabby", nil, true, nil)).to.equal(false)
				expect(Avatar.holdsNet(nil, true, true, nil)).to.equal(false)
				expect(Avatar.holdsNet(nil, nil, true, true)).to.equal(false)
				expect(Avatar.holdsNet(nil, nil, false, nil)).to.equal(false)
			end
		)

		it("shows one model a level: Basic, Sturdy, Pro and Master", function()
			expect(Avatar.netModel(0)).to.equal(1)
			expect(Avatar.netModel(1)).to.equal(2)
			expect(Avatar.netModel(2)).to.equal(3)
			expect(Avatar.netModel(3)).to.equal(4)
		end)

		it("shows the Basic net for a missing or odd NetLevel", function()
			expect(Avatar.netModel(nil)).to.equal(1)
			expect(Avatar.netModel("3")).to.equal(1)
			expect(Avatar.netModel(0 / 0)).to.equal(1)
			expect(Avatar.netModel(-2)).to.equal(1)
			expect(Avatar.netModel(9)).to.equal(4)
			expect(Avatar.netModel(2.7)).to.equal(3)
		end)

		it("raises the arm over blendIn and lowers it over blendOut, never past 0 or 1", function()
			local w = Avatar.holdWeight(0, true, h.blendIn / 2)
			expect(w).to.be.near(0.5, 1e-9)
			expect(Avatar.holdWeight(w, true, h.blendIn)).to.equal(1)
			expect(Avatar.holdWeight(1, false, h.blendOut / 2)).to.be.near(0.5, 1e-9)
			expect(Avatar.holdWeight(0.1, false, h.blendOut)).to.equal(0)
		end)

		it("rests the pole back over the shoulder (Derek 10-28 16:47), not flat behind", function()
			expect(pole(h) > 100 and pole(h) < 150).to.equal(true)
			expect(pole6(h) > 90 and pole6(h) < 150).to.equal(true)
			expect(h.showAt > 0 and h.showAt < 1).to.equal(true)
		end)
	end)

	describe("Effects net smack", function()
		-- a smack that hit (`missedAt` false) or heard it missed `missedAt` seconds in
		local function smack(seconds: number, missedAt: number | boolean): any
			return Avatar.smack(seconds, if missedAt == false then nil else missedAt)
		end
		it("lasts 0.62 s and lands at NetSmackDelay (0.22 s), inside the swing cooldown", function()
			expect(k.ends).to.be.near(0.62, 1e-9)
			expect(k.land).to.be.near(Config.NetSmackDelay, 1e-9) -- the drift guard (#1021)
			expect(k.rise > 0 and k.rise < k.land).to.equal(true)
			expect(k.land + k.bounce < k.ends).to.equal(true)
			expect(k.land + k.impact < k.ends).to.equal(true)
			expect(k.ends < 0.8).to.equal(true) -- Config.NetSwingCooldown: done before the next swing can start
		end)

		it("holds the net on the ground for the impact beat after a hit", function()
			same(smack(k.land + k.impact * 0.5, false), k.poses.landed)
			same(smack(k.land + k.impact - 1e-6, false), k.poses.landed, 0.01)
		end)

		it("swings a little past the hold on the way back, then settles on it", function()
			local h6 = pole6(h)
			local past = false
			for i = 1, 40 do
				local at = k.land + k.impact + (k.ends - k.land - k.impact) * i / 41
				if pole6(smack(at, false)) > h6 + 0.5 then
					past = true
				end
			end
			expect(past).to.equal(true)
		end)

		it("is nothing before the swing and from its end on", function()
			expect(Avatar.smack(-0.01)).to.equal(nil)
			expect(Avatar.smack(k.ends)).to.equal(nil)
			expect(Avatar.smack(k.ends, k.land)).to.equal(nil)
			expect(Avatar.smack(k.ends + 1, 0.3)).to.equal(nil)
		end)

		it(
			"starts from the hold, is up by rise and down by land, on a hit and a miss alike",
			function()
				same(Avatar.smack(0), h)
				for _, missedAt in { false, 0, k.land } do
					same(smack(k.rise, missedAt), k.poses.raised)
					same(smack(k.land - 1e-6, missedAt), k.poses.landed, 0.01)
					same(smack(k.land, missedAt), k.poses.landed)
				end
			end
		)

		it(
			"raises the net up and back over the head, then slams it below straight ahead",
			function()
				expect(pole(k.poses.raised) > 120).to.equal(true)
				expect(pole6(k.poses.raised) > 120).to.equal(true)
				expect(pole(k.poses.landed) < 0).to.equal(true)
				expect(pole6(k.poses.landed) < 0).to.equal(true)
				expect(k.poses.landed.waist > 0).to.equal(true) -- bent into the hit
			end
		)

		it("goes back to the hold by the end, a miss known by the landing too", function()
			same(smack(k.ends - 1e-6, false), h, 0.01)
			same(smack(k.ends - 1e-6, k.land), h, 0.01)
			same(smack(k.ends - 1e-6, 0), h, 0.01)
		end)

		it("bounces the net back up off the ground after a miss, and only after a miss", function()
			local at = k.land + k.bounce
			same(smack(at, k.land), k.poses.bounced)
			expect(pole(smack(at, k.land)) > pole(smack(at, false))).to.equal(true)
		end)

		it(
			"bends a swing whose miss is heard late where it is, and only makes it longer",
			function()
				local late = 0.25 -- the swinger's own screen: the landing plus a round trip
				same(smack(late - 0.01, late), smack(late - 0.01, false))
				same(smack(late + k.bounce, late), k.poses.bounced)
				expect(smack(k.ends, late)).never.to.equal(nil)
				local done = late + k.ends - k.land
				same(smack(done - 1e-6, late), h, 0.01)
				expect(smack(done, late)).to.equal(nil)
			end
		)

		it("ignores a miss heard after the swing ended", function()
			same(smack(0.3, k.ends + 0.1), smack(0.3, false))
			expect(smack(k.ends, k.ends + 0.1)).to.equal(nil)
		end)

		it("joins its parts with no jump: the arm is where the last part left it", function()
			for _, missedAt in { false, k.land, 0.25 } do
				for _, at in
					{ k.rise, k.land, k.land + k.impact, k.land + k.bounce, 0.25, 0.25 + k.bounce }
				do
					local before, after = smack(at - 1e-4, missedAt), smack(at, missedAt)
					expect(math.abs(pole(before) - pole(after)) < 1).to.equal(true)
					expect(math.abs(pole6(before) - pole6(after)) < 1).to.equal(true)
				end
			end
		end)
	end)
end
