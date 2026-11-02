--!strict
-- Working cats on the work body (S, Model-Agent #826; Derek 2026-11-02 12:02: "S: chibi holding the prop"), the
-- Animation-Engineer's part: the idles on top of the role's arm pose, which the server puts on the model
-- (Logic.workIdle, through Logic.idle with body "work"), and the walker getting up from standing for a cafe walk
-- (Logic.crouch with `standing`). These are pure; Pose finding the work body, the held thing riding its arm and
-- the arms waving about the shoulder need real instances, so they are Studio rows (effects-list "Working cats on S").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local w = Presets.motion.work
	local ROLES = { "barista", "waiter", "greeter", "entertainer" }
	local FRAME = 1 / 60
	local LIMIT = math.rad(15) + 1e-9 -- Model-Agent's contract: idle swings of the arms and held things under about 15
	local FIELDS = {
		"bodyY",
		"bodyPitch",
		"bodyRoll",
		"headPitch",
		"headYaw",
		"headRoll",
		"tailPitch",
		"tailYaw",
		"pawFL",
		"pawFR",
		"pawBL",
		"pawBR",
		"waveL",
		"waveR",
		"held",
	}

	describe("Effects working cats on the work body (S)", function()
		it("keeps every arm, wave and held turn under 15 degrees and never moves the back legs", function()
			for _, role in ROLES do
				for t = 0, 20, 0.013 do
					local o = Logic.idle(role, t, "work")
					for _, field in { "pawFL", "pawFR", "waveL", "waveR", "held" } do
						expect(math.abs(o[field]) <= LIMIT).to.equal(true)
					end
					expect(o.pawBL).to.equal(0)
					expect(o.pawBR).to.equal(0)
					expect(o.sink).to.equal(0)
					expect(o.sleep + o.loaf + o.lick).to.equal(0)
					expect(math.abs(o.bodyRoll) <= math.rad(math.max(w.sway, w.entertainer.sway)) + 1e-9).to.equal(
						true
					)
				end
			end
		end)

		it("moves with no jumps at 60 frames a second", function()
			for _, role in ROLES do
				local last = Logic.idle(role, 0, "work")
				for t = FRAME, 12, FRAME do
					local o = Logic.idle(role, t, "work")
					for _, field in FIELDS do
						expect(math.abs(o[field] - last[field]) < math.rad(4)).to.equal(true)
					end
					last = o
				end
			end
		end)

		it("has the Barista offer its cup now and then, the cup arm lifting and the cup tipping, the other arm still", function()
			local b = w.barista
			local mid = Logic.idle("barista", b.seconds / 2, "work")
			expect(mid.pawFR).to.be.near(math.rad(b.lift), 1e-9)
			expect(mid.held).to.be.near(math.rad(b.held), 1e-9)
			expect(mid.headPitch).to.be.near(-math.rad(b.look), 1e-9)
			expect(mid.pawFL).to.equal(0)
			local between = Logic.idle("barista", b.seconds + 0.1, "work")
			expect(between.pawFR).to.equal(0)
			expect(between.held).to.equal(0)
			expect(b.seconds < b.every).to.equal(true)
		end)

		it("keeps the Waiter's tray arm still while its head watches the room", function()
			local turned = 0
			for t = 0, w.waiter.lookSeconds, 0.05 do
				local o = Logic.idle("waiter", t, "work")
				expect(o.pawFL == 0 and o.pawFR == 0 and o.held == 0).to.equal(true)
				expect(o.waveL == 0 and o.waveR == 0).to.equal(true)
				turned = math.max(turned, math.abs(o.headYaw))
			end
			expect(turned).to.be.near(math.rad(w.waiter.look), 1e-3)
		end)

		it("has the Greeter wave its raised left paw side to side in bursts, the right arm still", function()
			local g = w.greeter
			local most, swings, last = 0, 0, 0
			for t = 0, g.seconds, 0.002 do
				local o = Logic.idle("greeter", t, "work")
				expect(o.waveR).to.equal(0)
				expect(o.pawFL == 0 and o.pawFR == 0).to.equal(true)
				most = math.max(most, math.abs(o.waveL))
				if last ~= 0 and o.waveL ~= 0 and (last > 0) ~= (o.waveL > 0) then
					swings += 1
				end
				if o.waveL ~= 0 then
					last = o.waveL
				end
			end
			expect(most > math.rad(g.wave) * 0.6).to.equal(true)
			expect(swings >= 2 * g.hz * g.seconds - 2).to.equal(true) -- side to side, not one slow lean
			-- between bursts the paw only drifts
			for t = g.seconds + 0.05, g.every - 0.05, 0.05 do
				local o = Logic.idle("greeter", t, "work")
				expect(math.abs(o.waveL) <= math.rad(g.rest) + 1e-9).to.equal(true)
			end
			expect(g.seconds < g.every).to.equal(true)
		end)

		it("has the Entertainer nod on the beat with the mic tipping along, swaying and waving to it", function()
			local e = w.entertainer
			local down = Logic.idle("entertainer", e.beat / 2, "work")
			expect(down.headPitch).to.be.near(-math.rad(e.nod), 1e-9)
			expect(down.held).to.be.near(math.rad(e.mic), 1e-9)
			local up = Logic.idle("entertainer", e.beat, "work")
			expect(up.headPitch).to.be.near(0, 1e-9)
			expect(up.held).to.be.near(0, 1e-9)
			local sway = Logic.idle("entertainer", e.beat / 2, "work")
			expect(sway.bodyRoll).to.be.near(math.rad(e.sway), 1e-9)
			expect(sway.waveL).to.be.near(math.rad(e.wave), 1e-9)
			expect(sway.waveR).to.equal(0)
		end)

		it("leaves the other bodies' role idles as they were, with no waves or held tips", function()
			for _, role in ROLES do
				for _, body in { "sit", "walk", "parts" } do
					for t = 0, 6, 0.21 do
						local o = Logic.idle(role, t, body)
						expect(o.waveL == 0 and o.waveR == 0 and o.held == 0).to.equal(true)
					end
				end
				-- a style with no work idle (resting, dozing) goes on as before on the work body
				expect(Logic.workIdle(Logic.blank(), "doze", 1)).to.equal(false)
			end
			expect(Logic.workIdle(Logic.blank(), "barista", 1)).to.equal(true)
		end)

		it("dozes on its feet at night without sinking, and never stretches", function()
			for t = 0, 10, 0.1 do
				local o = Logic.idle("doze", t, "work")
				expect(o.sink).to.equal(0)
				expect(o.blink).to.equal(1)
				expect(o.pawBL == 0 and o.pawBR == 0).to.equal(true)
			end
			local o = Logic.blank()
			Logic.stretch(o, 0.5, "work")
			for _, field in FIELDS do
				expect(o[field]).to.equal(0)
			end
		end)
	end)

	describe("Effects getting up from standing for a cafe walk (S)", function()
		it("rears the walker up onto its back legs further than a sit and lifts it rather than dropping it", function()
			local s, sit = Presets.cafeWalk.stand, Presets.cafeWalk.sit
			local up = Logic.blank()
			Logic.crouch(up, 1, true)
			expect(up.bodyPitch).to.be.near(math.rad(s.pitch), 1e-9)
			expect(up.bodyY).to.be.near(-s.drop, 1e-9)
			expect(up.bodyY > 0).to.equal(true)
			expect(up.pawBL).to.be.near(math.rad(s.tuck), 1e-9)
			expect(up.pawFL + up.bodyPitch).to.be.near(0, 1e-9) -- front legs hang straight down
			expect(s.pitch > sit.pitch).to.equal(true)
			-- without `standing` it is the sit, as before
			local down = Logic.blank()
			Logic.crouch(down, 1)
			expect(down.bodyPitch).to.be.near(math.rad(sit.pitch), 1e-9)
			expect(down.bodyY).to.be.near(-sit.drop, 1e-9)
			local none = Logic.blank()
			Logic.crouch(none, 0, true)
			for _, field in FIELDS do
				expect(none[field]).to.equal(0)
			end
		end)
	end)
end
