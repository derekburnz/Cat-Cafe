--!strict
-- The Rift Run (Effects/RiftRun, Derek 2026-11-13): a Mythic or Secret trait roll's run through the Rift Realm. The
-- pure parts: which rolls get it, the gates up to the rolled tier and when each is passed, the run's distance, the
-- dodges and meteors, the leap, the rift's opening, the flashes, the Secret's dark and the sounds. The realm, the
-- camera and the cat on the path are a Studio row (Workspace attribute RiftRunTest).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local AudioLogic = require(Client:WaitForChild("Audio"):WaitForChild("Logic")) :: any
	local Cues = require(Client:WaitForChild("Audio"):WaitForChild("Cues")) :: any
	local LiveFlags = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LiveFlags")
	) :: any

	local r = Presets.riftRun

	describe("Effects Rift Run", function()
		it("plays for Mythic and Secret only, behind a switch that starts off", function()
			expect(Logic.riftPlan("mythic") ~= nil).to.equal(true)
			expect(Logic.riftPlan("secret") ~= nil).to.equal(true)
			for _, id in { "common", "uncommon", "rare", "epic", "legendary", "nope" } do
				expect(Logic.riftPlan(id)).to.equal(nil)
			end
			expect(Logic.riftPlan(nil)).to.equal(nil)
			expect(table.find(LiveFlags.KEYS, "riftRun") ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT.riftRun).to.equal(true)
			expect(LiveFlags.defaults().riftRun).to.equal(false)
		end)

		it("passes a gate a tier, Common first, up to the rolled tier and never past it", function()
			local m = Logic.riftPlan("mythic")
			expect(#m.gates).to.equal(6)
			expect(m.gates[1]).to.equal("common")
			expect(m.gates[6]).to.equal("mythic")
			expect(m.darkAt).to.equal(nil)
			local x = Logic.riftPlan("secret")
			expect(#x.gates).to.equal(7)
			expect(x.gates[7]).to.equal("secret")
			expect(x.darkAt ~= nil).to.equal(true)
			for _, plan in { m, x } :: { any } do
				for i = 2, #plan.gates do
					-- in order, along the path, about a second apart (never faster than three a second)
					expect(plan.gateZ[i] > plan.gateZ[i - 1]).to.equal(true)
					expect(plan.gateAt[i] - plan.gateAt[i - 1] >= 0.8).to.equal(true)
				end
				-- every gate stands on the path, and the leap starts past the last one
				expect(plan.gateZ[#plan.gateZ] < r.leapFrom).to.equal(true)
				expect(r.leapFrom <= r.pathLength).to.equal(true)
				expect(plan.leapAt > plan.gateAt[#plan.gateAt]).to.equal(true)
				expect(plan.total > plan.leapAt and plan.total <= plan.leapEnd).to.equal(true)
				-- the whole run hands back well inside the cap
				expect(plan.total + 6 < r.cap).to.equal(true)
			end
			-- the Secret runs longer, through the dark
			expect(x.total > m.total).to.equal(true)
		end)

		it("runs through every gate at its time, never backwards", function()
			for _, rarity in { "mythic", "secret" } do
				local plan = Logic.riftPlan(rarity)
				expect(Logic.riftDistance(plan, 0)).to.equal(0)
				expect(Logic.riftDistance(plan, r.runStart)).to.equal(0)
				for i, at in plan.gateAt do
					expect(math.abs(Logic.riftDistance(plan, at) - plan.gateZ[i]) < 1e-6).to.equal(
						true
					)
				end
				expect(math.abs(Logic.riftDistance(plan, plan.leapAt) - r.leapFrom) < 1e-6).to.equal(
					true
				)
				expect(Logic.riftDistance(plan, plan.leapAt + 5)).to.equal(r.leapFrom)
				local last = 0
				local t = 0
				while t < plan.leapAt do
					local z = Logic.riftDistance(plan, t)
					expect(z >= last - 1e-9).to.equal(true)
					last = z
					t += 0.02
				end
			end
		end)

		it(
			"hops aside from each meteor, which lands in the lane it just left, never on it",
			function()
				local x, y = Logic.riftDodge(0)
				expect(x).to.equal(0)
				expect(y).to.equal(0)
				local plan = Logic.riftPlan("mythic")
				local meteors = Logic.riftMeteors(plan.leapAt)
				expect(#meteors).to.equal(#r.dodges)
				for i, m in meteors do
					expect(m.at < plan.leapAt).to.equal(true)
					-- where the cat is as it lands: a lane away (and the hop under way or done)
					local side = Logic.riftDodge(m.at)
					expect(math.abs(side - m.lane) >= r.laneWidth * 0.5).to.equal(true)
					-- from alternate sides
					if i > 1 then
						expect(m.from).to.equal(-meteors[i - 1].from)
					end
					-- lanes stay on the path
					expect(math.abs(m.lane) < r.pathWidth / 2).to.equal(true)
				end
				for _, lane in r.lanes do
					expect(math.abs(lane * r.laneWidth) + 1 < r.pathWidth / 2).to.equal(true)
				end
				-- a hop goes up and comes back down
				local mid = r.runStart + r.dodges[1] + r.dodgeSeconds / 2
				local _, high = Logic.riftDodge(mid)
				expect(high > 1).to.equal(true)
				local _, down = Logic.riftDodge(r.runStart + r.dodges[1] + r.dodgeSeconds + 0.01)
				expect(down).to.equal(0)
				-- a meteor falls from its start to where it lands
				local a, b = Vector3.new(10, 40, -30), Vector3.new(0, 0, 0)
				expect((Logic.riftFall(a, b, 0) - a).Magnitude < 1e-6).to.equal(true)
				expect((Logic.riftFall(a, b, 1) - b).Magnitude < 1e-6).to.equal(true)
			end
		)

		it("leaps from the path's end into the middle of the rift", function()
			local from, tilt = Logic.riftLeap(2, 0)
			expect(math.abs(from.Z + r.leapFrom) < 1e-6).to.equal(true)
			expect(math.abs(from.Y) < 1e-6).to.equal(true)
			expect(from.X).to.equal(2)
			expect(tilt > 0).to.equal(true)
			local to, level = Logic.riftLeap(2, 1)
			expect(math.abs(to.Z + r.pathLength + r.ringBeyond) < 1e-6).to.equal(true)
			expect(math.abs(to.Y - r.ringLift) < 1e-6).to.equal(true)
			expect(math.abs(to.X) < 1e-6).to.equal(true)
			expect(level).to.equal(0)
		end)

		it("opens the rift from a slit to wide open by the leap", function()
			local plan = Logic.riftPlan("mythic")
			local first = Logic.riftOpen(plan, 0)
			expect(first > 0 and first < 0.1).to.equal(true)
			expect(Logic.riftOpen(plan, plan.leapAt - r.ringTear) <= r.ringOpen + 1e-6).to.equal(
				true
			)
			expect(math.abs(Logic.riftOpen(plan, plan.leapAt) - 1) < 1e-6).to.equal(true)
			local last = 0
			for t = 0, plan.leapAt, 0.05 do
				local k = Logic.riftOpen(plan, t)
				expect(k >= last - 1e-9).to.equal(true)
				last = k
			end
		end)

		it(
			"flashes white only at the cut in and the hand back, pink before the last white",
			function()
				local plan = Logic.riftPlan("mythic")
				local w0 = Logic.riftFlash(plan, 0)
				expect(w0).to.equal(0)
				local w1 = Logic.riftFlash(plan, r.flareIn)
				expect(math.abs(w1 - 1) < 1e-6).to.equal(true)
				-- clear through the whole run
				for t = r.flareIn + r.flareOut + 0.01, plan.leapAt, 0.1 do
					local w = Logic.riftFlash(plan, t)
					expect(w).to.equal(0)
				end
				local _, pink =
					Logic.riftFlash(plan, plan.leapAt + r.leapSeconds * (r.pinkAt + 0.05))
				expect(pink > 0.5).to.equal(true)
				local white, endPink = Logic.riftFlash(plan, plan.total)
				expect(math.abs(white - 1) < 1e-6).to.equal(true)
				expect(endPink).to.equal(0)
				-- the two whites are far apart: no flashing
				expect(plan.leapAt - r.flareIn > 3).to.equal(true)
			end
		)

		it("grows every gate's moment and darkens only a Secret's realm", function()
			expect(Logic.riftGateScale(1)).to.equal(1)
			for i = 2, 7 do
				expect(Logic.riftGateScale(i) > Logic.riftGateScale(i - 1)).to.equal(true)
			end
			local m = Logic.riftPlan("mythic")
			local x = Logic.riftPlan("secret")
			for t = 0, x.total, 0.25 do
				expect(Logic.riftDark(m, t)).to.equal(0)
			end
			expect(Logic.riftDark(x, x.darkAt)).to.equal(0)
			local deep = Logic.riftDark(x, x.darkAt + 0.25 + r.darkIn)
			expect(deep > 0.99).to.equal(true)
			-- the star cat is all drawn well before the white Secret gate, and inside the gate's frame
			expect(0.25 + #Logic.CAT_CONSTELLATION * r.starCatGap < r.darkGap - 1).to.equal(true)
			for _, point in Logic.CAT_CONSTELLATION do
				local y = r.starCatHeight + point.Y * r.starCatScale
				expect(y > 0 and y < r.gateHeight).to.equal(true)
				expect(math.abs(point.X * r.starCatScale) < r.gateWidth / 2).to.equal(true)
			end
			-- the white Secret gate lifts the dark half way
			expect(math.abs(Logic.riftDark(x, x.gateAt[7] + 1) - 0.5) < 1e-6).to.equal(true)
		end)

		it("sounds each beat from cues that exist, a gate a note higher each tier", function()
			expect(AudioLogic.riftRunCue("gate", 1, "common")).to.equal("poolStep")
			local _, one = AudioLogic.riftRunCue("gate", 1, "common")
			local _, five = AudioLogic.riftRunCue("gate", 5, "legendary")
			expect(five > one).to.equal(true)
			expect(AudioLogic.riftRunCue("gate", 6, "mythic")).to.equal("poolMythic")
			expect(AudioLogic.riftRunCue("gate", 7, "secret")).to.equal("jingleSecret")
			for _, beat in { "flare", "land", "meteor", "dark", "tear", "leap" } do
				local cue = AudioLogic.riftRunCue(beat, 0, "mythic")
				expect(type(cue)).to.equal("string")
				expect(Cues[cue] ~= nil).to.equal(true)
			end
			expect(AudioLogic.riftRunCue("cut", 0, "mythic")).to.equal(nil)
			expect(AudioLogic.riftRunCue("nope", 0, "mythic")).to.equal(nil)
		end)

		it("has a word for every tier", function()
			for _, tier in r.tiers do
				expect(type(r.words[tier])).to.equal("string")
			end
		end)
	end)
end
