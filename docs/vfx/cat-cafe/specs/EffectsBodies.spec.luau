--!strict
-- The new cat bodies (PR #259: walking A, sitting B, every hinged piece its own Model): naps and loafs are
-- Model-Agent's piece poses, a sitting cat washes a paw now and then, and every cat blinks and flicks its ears.
-- Written by the vfx-animator for QA to move into tests/specs next to EffectsMotion.spec.luau. Pose itself needs
-- real instances and CFrames, so the turns about each piece's pivot are Studio rows (effects-list "New bodies").
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local m = Presets.motion
	local AWAKE = { "stuck", "stray", "barista", "waiter", "greeter", "entertainer", "sit" }

	describe("Effects new bodies", function()
		it("naps in the sleep pose on the walking body, eyes shut, without folding its own legs", function()
			for t = 0, 12, 0.37 do
				local o = Logic.idle("nap", t, "walk")
				expect(o.sleep).to.equal(1)
				expect(o.loaf == 0 and o.lick == 0).to.equal(true)
				expect(o.sink).to.equal(0) -- the pose's own lift lays it down
				expect(o.pawFL == 0 and o.pawFR == 0 and o.pawBL == 0 and o.pawBR == 0).to.equal(true)
				expect(o.headPitch == 0 and o.headYaw == 0).to.equal(true) -- the pose turns the head
				expect(o.blink).to.equal(1)
			end
		end)

		it("loafs in the loaf pose on the walking body, eyes half shut, looking aside now and then", function()
			local l = m.loaf
			for t = 0, 30, 0.1 do
				local o = Logic.idle("loaf", t, "walk")
				expect(o.loaf).to.equal(1)
				expect(o.sleep).to.equal(0)
				expect(o.sink).to.equal(0)
				expect(math.abs(o.headYaw) <= math.rad(l.look) + 1e-9).to.equal(true)
				expect(o.blink >= m.blink.sleepy - 1e-9 and o.blink <= 1).to.equal(true)
			end
		end)

		it("settles from the nap into the loaf without leaving the floor", function()
			for k = 0, 1, 0.1 do
				local o = Logic.mix(Logic.idle("nap", 5, "walk"), Logic.idle("loaf", 5, "walk"), k)
				-- both poses lie at the same lift, so blended they always add up to lying down
				expect(o.sleep + o.loaf).to.be.near(1, 1e-9)
				expect(o.sink).to.equal(0)
			end
			expect(Presets.catPoses.sleep.lift).to.equal(Presets.catPoses.loaf.lift)
		end)

		it("washes a paw on the sitting body in bursts, the paw and head moving only a little", function()
			local k = m.lick
			local moved = false
			for t = 0, 12, 0.05 do
				local o = Logic.idle("lick", t, "sit")
				expect(o.lick).to.equal(1)
				expect(o.sleep == 0 and o.loaf == 0 and o.sink == 0).to.equal(true)
				expect(math.abs(o.pawFL) <= math.rad(k.paw) + 1e-9).to.equal(true)
				expect(o.headPitch <= 1e-9 and o.headPitch >= -math.rad(k.bob) - 1e-9).to.equal(true)
				expect(o.blink).to.equal(k.eyes)
				if math.abs(o.pawFL) > math.rad(k.paw) * 0.5 then
					moved = true
				end
				-- between bursts the paw rests at the mouth
				if t % (k.strokes + k.pause) >= k.strokes then
					expect(o.pawFL).to.equal(0)
				end
			end
			expect(moved).to.equal(true)
		end)

		it("dozes seated with its eyes shut and never takes a lying pose", function()
			for t = 0, 12, 0.37 do
				local o = Logic.idle("doze", t, "sit")
				expect(o.sleep == 0 and o.loaf == 0 and o.lick == 0).to.equal(true)
				expect(o.sink).to.equal(0)
				expect(o.blink).to.equal(1)
			end
		end)

		it("ties each piece pose to its body", function()
			expect(Presets.catPoses.sleep.body).to.equal("walk")
			expect(Presets.catPoses.loaf.body).to.equal("walk")
			expect(Presets.catPoses.lick.body).to.equal("sit")
			expect(Presets.catPoses.lick.lift).to.equal(0)
			for _, pose in Presets.catPoses do
				for _, angles in pose.turns do
					expect(#angles).to.equal(3)
				end
			end
		end)

		it("blinks now and then and keeps its eyes open most of the time", function()
			for _, style in AWAKE do
				local shut, samples = 0, 0
				for t = 0, 60, 0.02 do
					local o = Logic.idle(style, t, "walk")
					expect(o.blink >= 0 and o.blink <= 1).to.equal(true)
					samples += 1
					if o.blink > 0.5 then
						shut += 1
					end
				end
				expect(shut > 0).to.equal(true)
				expect(shut / samples < 0.1).to.equal(true)
			end
		end)

		it("flicks each ear now and then, by no more than the twitch", function()
			local twitch = math.rad(m.ears.twitch)
			local left, right = false, false
			for t = 0, 60, 0.02 do
				local o = Logic.idle("stray", t, "walk")
				expect(o.earL >= 0 and o.earL <= twitch + 1e-9).to.equal(true)
				expect(o.earR >= 0 and o.earR <= twitch + 1e-9).to.equal(true)
				left = left or o.earL > twitch * 0.5
				right = right or o.earR > twitch * 0.5
			end
			expect(left and right).to.equal(true)
		end)

		it("keeps the older Part cats folding their own legs", function()
			local o = Logic.idle("nap", 1)
			expect(o.sink).to.equal(1)
			expect(o.sleep).to.equal(0)
			expect(Logic.idle("loaf", 1, "parts").sink).to.equal(1)
		end)

		it("gives every style finite, small offsets on both bodies", function()
			for _, body in { "walk", "sit" } do
				for _, style in { "nap", "loaf", "lick", "doze", table.unpack(AWAKE) } do
					for t = 0, 12, 0.37 do
						local o = Logic.idle(style, t, body)
						for key, value in o do
							expect(value == value).to.equal(true) -- not NaN
							expect(math.abs(value) <= 2).to.equal(true)
							if key == "bodyY" then
								expect(value >= 0 and value < 0.2).to.equal(true)
							end
						end
					end
				end
			end
		end)

		it("washes for hold seconds of every cycle, each cat at its own time", function()
			local k = m.lick
			local phase = Logic.phaseOf("cat_uid_1")
			local on = 0
			for t = 0, k.every * 4 - 1 do
				if Logic.licking(1000 + t, phase) then
					on += 1
				end
			end
			expect(on).to.equal(k.hold * 4)
			expect(k.hold < k.every / 2).to.equal(true)
		end)
	end)
end
