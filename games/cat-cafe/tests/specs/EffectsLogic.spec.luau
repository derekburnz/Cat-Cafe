--!strict
-- Pure parts of the client Effects module (src/client/Effects/Logic.luau and Presets.luau, effects list): device
-- tier, catch grades, budget picks, plot changes, gate openings and the motion curves. Written by the vfx-animator
-- (PR #77); the "edges (QA)" block is QA's boundary checks.
return function()
	local Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects.Logic", function()
		it("gives touch-only devices the low budget", function()
			expect(Logic.tier(true, false)).to.equal("low")
			expect(Logic.tier(true, true)).to.equal("high")
			expect(Logic.tier(false, true)).to.equal("high")
		end)

		it("reads catch grades and both CatchResult shapes", function()
			expect(Logic.isPurrfect({ "perfect", "perfect", "perfect" })).to.equal(true)
			expect(Logic.isPurrfect({ "perfect", "good" })).to.equal(false)
			expect(Logic.isPurrfect({ "perfect", "miss" })).to.equal(false)
			expect(Logic.isPurrfect({ 1, 1, 1 })).to.equal(true)
			expect(Logic.isPurrfect({ 1, 0.5 })).to.equal(false)
			expect(Logic.isPurrfect({})).to.equal(false)
			-- v0.4 (grades, success, pawsLeft, charmGain) and v0.3 (scores, chance, success, stayed)
			expect(Logic.catchSucceeded(true, 2)).to.equal(true)
			expect(Logic.catchSucceeded(false, nil)).to.equal(false)
			expect(Logic.catchSucceeded(0.8, true)).to.equal(true)
			expect(Logic.catchSucceeded(0.8, false)).to.equal(false)
		end)

		it("picks the nearest within range, nearest first", function()
			local picked = Logic.nearest({
				{ key = "far", distance = 90 },
				{ key = "b", distance = 20 },
				{ key = "a", distance = 5 },
				{ key = "c", distance = 30 },
			}, 60, 2)
			expect(#picked).to.equal(2)
			expect(picked[1]).to.equal("a")
			expect(picked[2]).to.equal("b")
		end)

		it("tells a claim, a release and a rank up apart", function()
			expect(Logic.plotChange(0, 0, 42, 0, 10)).to.equal("claim")
			expect(Logic.plotChange(42, 3, 0, 0, 10)).to.equal("release")
			expect(Logic.plotChange(42, 2, 42, 3, 10)).to.equal("rankUp")
			-- the new owner's saved tier arriving after the claim is not a rank up
			expect(Logic.plotChange(42, 0, 42, 3, 0.1)).to.equal(nil)
			expect(Logic.plotChange(42, 1, 42, 3, 0.5)).to.equal(nil)
			expect(Logic.plotChange(42, 3, 42, 3, 10)).to.equal(nil)
		end)

		it("opens only the gates crossed by a rank up", function()
			local opened = Logic.newlyOpen({ Park = 2, Woods = 3, Sewer = 5 }, 2, 3)
			expect(#opened).to.equal(1)
			expect(opened[1]).to.equal("Woods")
			expect(#Logic.newlyOpen({ Park = 2 }, 3, 4)).to.equal(0)
		end)

		it("gives every style finite, small offsets", function()
			for _, style in { "nap", "stuck", "stray", "barista", "waiter", "greeter", "entertainer", "sit" } do
				for t = 0, 12, 0.37 do
					local o = Logic.idle(style, t)
					for key, value in o do
						expect(value == value).to.equal(true) -- not NaN
						expect(math.abs(value) <= 2).to.equal(true)
						if key == "bodyY" then
							expect(value >= 0 and value < 0.2).to.equal(true)
						end
					end
				end
			end
		end)

		it("hops highest halfway through a hiss and lands", function()
			local mid = Logic.blank()
			Logic.hiss(mid, 0.5)
			expect(mid.bodyY).to.be.near(Presets.motion.hiss.hop, 1e-6)
			local done = Logic.blank()
			Logic.hiss(done, 1)
			expect(done.bodyY).to.equal(0)
			expect(Logic.landing(0)).to.equal(1)
			expect(Logic.landing(1)).to.equal(0)
			expect(Logic.landing(0.5)).to.be.near(0.5, 1e-6)
		end)

		it("throws confetti up and lets it drift back near launch height", function()
			local c = Presets.confetti
			local v = Vector3.new(8, c.upSpeed[2], 0)
			local peak = -math.huge
			for t = 0, c.seconds, 0.05 do
				peak = math.max(peak, Logic.confettiOffset(v, t, 0).Y)
			end
			expect(peak > 3).to.equal(true)
			local landed = Logic.confettiOffset(v, c.seconds, 0)
			expect(math.abs(landed.Y) < 3).to.equal(true)
			expect(math.abs(landed.X) < 5).to.equal(true)
		end)

		it("keeps butterflies inside their loop", function()
			local b = Presets.butterfly
			for t = 0, 30, 0.5 do
				local offset, flap = Logic.butterfly(t, 1.3)
				expect(math.abs(offset.X) <= b.roam.X + 1e-6).to.equal(true)
				expect(math.abs(offset.Z) <= b.roam.Z + 1e-6).to.equal(true)
				expect(math.abs(offset.Y - b.height) <= b.roam.Y + 1e-6).to.equal(true)
				expect(math.abs(flap) <= math.rad(b.flapDegrees) + 1e-6).to.equal(true)
			end
		end)
	end)

	describe("Effects.Logic edges (QA)", function()
		it("gives a device with neither touch nor keyboard the high budget", function()
			expect(Logic.tier(false, false)).to.equal("high")
		end)

		it("reads a CatchResult with no success flag as a failed catch", function()
			expect(Logic.catchSucceeded(0.8, nil)).to.equal(false)
			expect(Logic.catchSucceeded(nil, nil)).to.equal(false)
		end)

		it("keeps a candidate at exactly the radius and copes with a short or zero limit", function()
			local candidates = {
				{ key = "edge", distance = 60 },
				{ key = "out", distance = 60.01 },
				{ key = "near", distance = 1 },
			}
			local picked = Logic.nearest(candidates, 60, 5)
			expect(#picked).to.equal(2)
			expect(picked[1]).to.equal("near")
			expect(picked[2]).to.equal("edge")
			expect(#Logic.nearest(candidates, 60, 0)).to.equal(0)
			expect(#Logic.nearest({}, 60, 3)).to.equal(0)
		end)

		it("calls a plot passing straight to a new owner a claim", function()
			expect(Logic.plotChange(42, 3, 7, 1, 10)).to.equal("claim")
			expect(Logic.plotChange(42, 3, 7, 3, 10)).to.equal("claim")
		end)

		it("waits exactly the claim grace before a tier rise counts as a rank up", function()
			local grace = Presets.rankUp.claimGrace
			expect(Logic.plotChange(42, 1, 42, 2, grace)).to.equal("rankUp")
			expect(Logic.plotChange(42, 1, 42, 2, grace - 0.01)).to.equal(nil)
			-- skipping a tier is still one rank up; a drop or an unowned plot is not
			expect(Logic.plotChange(42, 1, 42, 3, grace)).to.equal("rankUp")
			expect(Logic.plotChange(42, 3, 42, 2, grace)).to.equal(nil)
			expect(Logic.plotChange(0, 1, 0, 2, grace)).to.equal(nil)
			-- an owned plot still showing tier 0 is waiting on its saved tier, however late it arrives
			expect(Logic.plotChange(42, 0, 42, 2, grace + 10)).to.equal(nil)
		end)

		it("opens every gate a skipped tier crosses and none already open", function()
			local opened = Logic.newlyOpen({ Park = 2, Woods = 3, Sewer = 5 }, 1, 3)
			table.sort(opened)
			expect(#opened).to.equal(2)
			expect(opened[1]).to.equal("Park")
			expect(opened[2]).to.equal("Woods")
			expect(#Logic.newlyOpen({ Park = 2 }, 2, 3)).to.equal(0)
			expect(#Logic.newlyOpen({ Park = 2 }, 3, 3)).to.equal(0)
		end)

		it("pulses to 1 in the middle of its window and rests at 0 outside it", function()
			expect(Logic.pulse(0, 6, 1)).to.equal(0)
			expect(Logic.pulse(0.5, 6, 1)).to.be.near(1, 1e-6)
			expect(Logic.pulse(6.5, 6, 1)).to.be.near(1, 1e-6)
			expect(Logic.pulse(1, 6, 1)).to.equal(0)
			expect(Logic.pulse(3, 6, 1)).to.equal(0)
			for t = 0, 12, 0.13 do
				local v = Logic.pulse(t, 6, 1)
				expect(v >= 0 and v <= 1).to.equal(true)
			end
		end)

		it("leaves the pose alone outside the hiss and clamps the landing", function()
			local before = Logic.blank()
			Logic.hiss(before, -0.1)
			local untouched = Logic.blank()
			for key, value in untouched do
				expect(before[key]).to.equal(value)
			end
			local early = Logic.blank()
			Logic.hiss(early, 0.25)
			expect(early.bodyY > 0 and early.bodyY < Presets.motion.hiss.hop).to.equal(true)
			expect(Logic.landing(-1)).to.equal(1)
			expect(Logic.landing(2)).to.equal(0)
		end)
	end)

	describe("Effects.Presets", function()
		it("keeps phone bursts at 12 or fewer and steady emitters at 4", function()
			local low = Presets.budget.low
			expect(low.maxBurst <= 12).to.equal(true)
			expect(low.steadyEmitters <= 4).to.equal(true)
			for _, count in Presets.catchSparkle do
				expect(math.min(math.floor(count * low.burstScale + 0.5), low.maxBurst) <= 12).to.equal(true)
			end
			expect(Presets.catchSparkle.Mythical <= 30).to.equal(true)
		end)

		it("has a preset for every burst it names", function()
			for name in Presets.bursts do
				if name ~= "purrfect" then
					expect(Presets.emitters[name] ~= nil).to.equal(true)
				end
			end
			expect(Presets.emitters.catchSparkle ~= nil).to.equal(true)
		end)
	end)
end
