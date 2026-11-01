--!strict
-- The Cat Cannon flight, the cloud hop and the camp check-in (F84, hometown-cannon.md sections 3b, 4 and 5): the
-- clouds always hide the server's move, the beats play once and in order, and every destination has a colour.
-- Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects cannon clouds", function()
		it("cover the screen fully while the server moves the player", function()
			local cannon, hop = Presets.clouds.cannon, Presets.clouds.hop
			expect(Logic.cloudCover(1.9, cannon)).to.equal(1) -- CannonTeleportAtSeconds
			expect(Logic.cloudCover(0.6, hop)).to.equal(1) -- CloudHopMoveAtSeconds
			expect(cannon.coverTo < 1.9 and cannon.partFrom > 1.9).to.equal(true)
			expect(hop.coverTo < 0.6 and hop.partFrom > 0.6).to.equal(true)
			expect(cannon.partTo <= Presets.cannon.endAt).to.equal(true)
			expect(hop.partTo <= 1.6).to.equal(true) -- CloudHopSeconds
		end)

		it("rush in, hold and part", function()
			local plan = Presets.clouds.cannon
			expect(Logic.cloudCover(1.0, plan)).to.equal(0)
			local coming = Logic.cloudCover(1.5, plan)
			expect(coming > 0 and coming < 1).to.equal(true)
			local going = Logic.cloudCover(2.6, plan)
			expect(going > 0 and going < 1).to.equal(true)
			expect(Logic.cloudCover(2.7, plan) < going).to.equal(true)
			expect(Logic.cloudCover(plan.partTo, plan)).to.equal(0)
			expect(Logic.cloudCover(5, plan)).to.equal(0)
		end)

		it("turn toward the destination's colour after the move", function()
			local plan = Presets.clouds.cannon
			expect(Logic.cloudTint(plan.tintFrom - 0.1, plan)).to.equal(0)
			expect(close(Logic.cloudTint((plan.tintFrom + plan.tintTo) / 2, plan), 0.5)).to.equal(
				true
			)
			expect(Logic.cloudTint(plan.tintTo + 1, plan)).to.equal(1)
			expect(plan.tintFrom >= 1.9).to.equal(true) -- never the colour of a place you have not reached
			local flat =
				{ coverFrom = 0, coverTo = 1, partFrom = 2, partTo = 3, tintFrom = 1, tintTo = 1 }
			expect(Logic.cloudTint(0.5, flat)).to.equal(0)
			expect(Logic.cloudTint(1, flat)).to.equal(1)
		end)

		it("bank only a little", function()
			local bank = Presets.clouds.bank
			for _, t in { 0, 0.4, 1.1, 2.3 } do
				local drift = Logic.cloudBank(t, bank)
				expect(math.abs(drift.X) <= bank.share + 1e-9).to.equal(true)
				expect(math.abs(drift.Y) <= bank.share + 1e-9).to.equal(true)
			end
			expect(bank.share > 0 and bank.share <= 0.08).to.equal(true)
		end)

		it("sit over the popups and under the intro", function()
			expect(Presets.clouds.displayOrder > 40 and Presets.clouds.displayOrder < 50).to.equal(
				true
			)
		end)
	end)

	describe("Effects cannon beats", function()
		it("plays each beat once and in order, even from a late step", function()
			local beats = { boom = 0.5, puff = 1.4, land = 3.0 }
			local fired = {}
			expect(#Logic.beatsDue(0.2, beats, fired)).to.equal(0)
			local late = Logic.beatsDue(1.6, beats, fired)
			expect(#late).to.equal(2)
			expect(late[1]).to.equal("boom")
			expect(late[2]).to.equal("puff")
			expect(#Logic.beatsDue(1.7, beats, fired)).to.equal(0)
			local last = Logic.beatsDue(3.2, beats, fired)
			expect(#last).to.equal(1)
			expect(last[1]).to.equal("land")
		end)

		it("trails sparkles out of the barrel and on the drop to the pad", function()
			local c = Presets.cannon
			expect(Logic.cannonTrail(0.2, c)).to.equal(false) -- the fuse
			expect(Logic.cannonTrail(c.boomAt, c)).to.equal(true)
			expect(Logic.cannonTrail(1.0, c)).to.equal(true)
			expect(Logic.cannonTrail(c.puffAt, c)).to.equal(false) -- in the clouds
			expect(Logic.cannonTrail(2.0, c)).to.equal(false)
			expect(Logic.cannonTrail(c.dropAt + 0.1, c)).to.equal(true) -- the drop to the pad
			expect(Logic.cannonTrail(c.landAt, c)).to.equal(false)
		end)

		it("matches the spec's timeline", function()
			local c = Presets.cannon
			expect(c.boomAt).to.equal(0.5)
			expect(c.puffAt).to.equal(1.4)
			expect(c.dropAt).to.equal(2.4)
			expect(c.landAt).to.equal(2.62) -- feet down (Animation-Engineer's Presets.cannonPose)
			expect(c.endAt).to.equal(3.0) -- CannonLaunchSeconds
			expect(Presets.clouds.cannon.coverFrom).to.equal(c.puffAt)
			expect(Presets.clouds.cannon.partFrom).to.equal(c.dropAt)
		end)

		it("squeezes into the intro's cannon shot", function()
			local s = Presets.cannon.introStage
			local plan = s.clouds
			expect(s.boomAt).to.equal(0) -- the shot's BOOM (intro-cutscene.md shot 2)
			expect(s.puffAt).to.equal(0.55)
			expect(s.landAt).to.equal(1.55)
			expect(plan.coverFrom).to.equal(s.puffAt)
			expect(plan.coverTo < 0.7).to.equal(true) -- covered before the cut to the camp
			expect(Logic.cloudCover(0.7, plan)).to.equal(1)
			expect(Logic.cloudCover(s.glideFrom, plan)).to.equal(1)
			expect(Logic.cloudCover(s.glideTo, plan)).to.equal(1)
			expect(plan.partTo <= s.landAt and s.landAt <= s.endAt).to.equal(true)
			expect(plan.tintFrom >= 0.7).to.equal(true) -- after the cut
			expect(Logic.cannonTrail(0.2, s)).to.equal(true)
			expect(Logic.cannonTrail(1.0, s)).to.equal(false) -- in the clouds
			expect(Logic.cannonTrail(s.dropAt + 0.05, s)).to.equal(true)
			local fuse = Presets.cannon.fuseSeconds
			expect(fuse > 0 and fuse <= Presets.cannon.boomAt).to.equal(true)
		end)

		it("has a colour for every destination", function()
			for _, id in { "town", "home", "alley", "park", "neighbourhood", "woods", "sewer" } do
				expect(Presets.cannon.tints[id] ~= nil).to.equal(true)
			end
		end)

		it("stays in budget", function()
			local b = Presets.budget
			expect(b.low.cloudPuffs <= b.high.cloudPuffs).to.equal(true)
			expect(b.lowPerformance.cloudPuffs <= b.low.cloudPuffs).to.equal(true)
			expect(b.lowPerformance.cloudPuffs >= 1).to.equal(true)
			expect(Presets.emitters.fuseSpark ~= nil and Presets.emitters.cannonTrail ~= nil).to.equal(
				true
			)
			expect(Presets.bursts.fuseSpark <= 6).to.equal(true)
			expect(Presets.cannon.most >= 1 and Presets.cannon.most <= 6).to.equal(true)
		end)
	end)

	describe("Effects camp check-in", function()
		it("hops the cat in an arc into the basket", function()
			local from, to = Vector3.new(0, 4, 0), Vector3.new(4, 2, 0)
			local start = Logic.hopPoint(from, to, 2.5, 0)
			local finish = Logic.hopPoint(from, to, 2.5, 1)
			local middle = Logic.hopPoint(from, to, 2.5, 0.5)
			expect(close(start.X, 0) and close(start.Y, 4)).to.equal(true)
			expect(close(finish.X, 4) and close(finish.Y, 2)).to.equal(true)
			expect(close(middle.X, 2) and close(middle.Y, 3 + 2.5)).to.equal(true)
			expect(close(Logic.hopPoint(from, to, 2.5, 2).X, 4)).to.equal(true) -- past the end stays in the basket
		end)
	end)
end
