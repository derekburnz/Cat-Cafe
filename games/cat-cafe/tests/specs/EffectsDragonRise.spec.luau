--!strict
-- #4062 Dragon Keep: the stage-up cutscene's plan (about 7 s, 12 s for stage 5, 2 s with Reduce Motion), its one
-- flash, the curl into the ember ball and out of it, the roar, stage 5's lap of the castle, what each stage adds, the
-- sounds, and the card deal's numbers. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Audio = Client:WaitForChild("Audio")
	local AudioLogic = require(Audio:WaitForChild("Logic")) :: any
	local Cues = require(Audio:WaitForChild("Cues")) :: any

	local d = Presets.dragonRise

	describe("Effects Dragon Keep stage up", function()
		it("plans five stages, the last with a lap, and a short calm one", function()
			expect(Logic.dragonPlan(0, false)).to.equal(nil)
			expect(Logic.dragonPlan(6, false)).to.equal(nil)
			expect(Logic.dragonPlan(2.5, false)).to.equal(nil)
			for stage = 1, 5 do
				local plan = Logic.dragonPlan(stage, false)
				expect(plan.total).to.equal(if stage == 5 then 12 else 7)
				expect(plan.skipAfter).to.equal(1)
				-- in order, with room for each
				expect(plan.swing <= plan.curlAt).to.equal(true)
				expect(plan.curlAt + d.curlSeconds < plan.crackAt).to.equal(true)
				expect(plan.crackAt < plan.unfurlEnd).to.equal(true)
				expect(plan.unfurlEnd <= plan.roarAt).to.equal(true)
				expect(plan.roarAt + d.roarSeconds <= plan.backAt).to.equal(true)
				expect(plan.backAt < plan.total).to.equal(true)
				-- no shot is shorter than about 0.8 s
				expect(plan.swing >= 0.8).to.equal(true)
				expect(plan.crackAt - plan.swing >= 0.8).to.equal(true)
				expect(plan.total - plan.backAt >= 0.8 - 1e-6).to.equal(true)
				if stage == 5 then
					expect(plan.lapAt >= plan.unfurlEnd).to.equal(true)
					expect(plan.landAt > plan.lapAt and plan.landAt < plan.roarAt).to.equal(true)
				else
					expect(plan.lapAt).to.equal(nil)
				end
				local calm = Logic.dragonPlan(stage, true)
				expect(calm.total).to.equal(2)
				expect(calm.lapAt).to.equal(nil)
				expect(calm.roarAt < calm.backAt).to.equal(true)
			end
		end)

		it("flashes once, at the crack, and never under Reduce Motion", function()
			for stage = 1, 5 do
				local plan = Logic.dragonPlan(stage, false)
				local rises = 0
				local last = 0
				local most = 0
				for step = 0, plan.total * 100 do
					local white = Logic.dragonFlash(plan, step / 100)
					if white > 0 and last == 0 then
						rises += 1
					end
					most = math.max(most, white)
					last = white
				end
				expect(rises).to.equal(1)
				expect(most <= d.crack.flash and most > 0.5).to.equal(true)
				expect(Logic.dragonFlash(plan, plan.crackAt - 0.01)).to.equal(0)
				expect(Logic.dragonFlash(plan, plan.crackAt + d.crack.flashSeconds)).to.equal(0)
			end
			-- the calm one fades softly: never a jump of more than a little in one frame
			local calm = Logic.dragonPlan(3, true)
			local before = 0
			for step = 0, calm.total * 60 do
				local white = Logic.dragonFlash(calm, step / 60)
				expect(math.abs(white - before) < 0.12).to.equal(true)
				before = white
			end
			expect(Logic.dragonFlash(calm, calm.total)).to.equal(0)
		end)

		it("curls him into the ember ball, cracks it and unfurls the new look", function()
			local plan = Logic.dragonPlan(2, false)
			expect(Logic.dragonCurl(plan, 0)).to.equal(0)
			expect(Logic.dragonCurl(plan, plan.crackAt - 0.01) > 0.99).to.equal(true)
			-- the new look starts curled inside the ball and ends standing
			expect(Logic.dragonCurl(plan, plan.crackAt) > 0.99).to.equal(true)
			expect(Logic.dragonCurl(plan, plan.unfurlEnd) < 1e-6).to.equal(true)
			local grown, hot = Logic.dragonBall(plan, plan.crackAt - 0.01)
			expect(grown > 0.99 and hot > 0.99).to.equal(true)
			-- it is fully grown before it is fully hot, and gone from the crack on
			local early, cool = Logic.dragonBall(plan, plan.curlAt + d.ballFrom + 0.1)
			expect(early > 0 and cool == 0).to.equal(true)
			local gone, cold = Logic.dragonBall(plan, plan.crackAt)
			expect(gone == 0 and cold == 0).to.equal(true)
			-- hot enough to hide the swap under it
			expect(d.ball.solid < 0.1).to.equal(true)
			-- Reduce Motion: no curl and no ball
			local calm = Logic.dragonPlan(2, true)
			for step = 0, 20 do
				expect(Logic.dragonCurl(calm, step / 10)).to.equal(0)
				expect((Logic.dragonBall(calm, step / 10))).to.equal(0)
			end
		end)

		it("poses the curl, the roar and the wings", function()
			local stand = Logic.dragonPose(0, 0, 0, 0, 0)
			for _, turn in stand do
				if turn.Magnitude > 1e-6 then
					-- standing with folded wings: only the wings are turned (folded back)
					expect(turn.X == 0 and turn.Z == 0).to.equal(true)
				end
			end
			local curled, drop = Logic.dragonPose(1, 0, 0, 0, 0)
			expect(curled.Neck.X < 0 and curled.Head.X < 0).to.equal(true) -- chin tucked
			expect(curled.Tail1.Y > 0 and curled.Tail3.Y > curled.Tail1.Y).to.equal(true) -- tail wrapped
			expect(curled.LegFL.X > 0 and curled.LegBL.X < 0).to.equal(true) -- legs tucked under
			expect(drop > 0).to.equal(true)
			local roaring = Logic.dragonPose(0, 1, 1, 0, 0)
			expect(roaring.Jaw.X < -0.3).to.equal(true) -- jaw open
			expect(roaring.Head.X > 0 and roaring.Neck.X > 0).to.equal(true) -- head up
			-- wings: open ones are level and mirror each other, a beat lifts both
			expect(math.abs(roaring.WingL.Y) < 1e-6).to.equal(true)
			expect(roaring.WingL.Z).to.equal(-roaring.WingR.Z)
			local up = Logic.dragonPose(0, 0, 1, 0.5, 0)
			expect(up.WingL.Z > roaring.WingL.Z).to.equal(true)
			-- the roar eases in and out inside its time
			local plan = Logic.dragonPlan(4, false)
			expect(Logic.dragonRoar(plan, plan.roarAt)).to.equal(0)
			expect(Logic.dragonRoar(plan, plan.roarAt + 0.4)).to.equal(1)
			expect(Logic.dragonRoar(plan, plan.roarAt + d.roarSeconds)).to.equal(0)
		end)

		it("flies stage 5 one lap from the yard to the tower, never below the ground", function()
			local plan = Logic.dragonPlan(5, false)
			local cr = d.crowned
			local tower = cr.tower
			expect(Logic.dragonLap(plan, plan.lapAt, cr.lapRadius, cr.lapHeight, tower).Magnitude).to.equal(
				0
			)
			local land = Logic.dragonLap(plan, plan.landAt, cr.lapRadius, cr.lapHeight, tower)
			expect((land - tower).Magnitude < 1e-6).to.equal(true)
			local after = Logic.dragonLap(plan, plan.landAt + 1, cr.lapRadius, cr.lapHeight, tower)
			expect((after - tower).Magnitude < 1e-6).to.equal(true)
			local turned = 0
			local lastAngle: number? = nil
			local last = Vector3.new(0, 0, 0)
			local steps = 200
			for step = 0, steps do
				local t = plan.lapAt + (plan.landAt - plan.lapAt) * step / steps
				local at = Logic.dragonLap(plan, t, cr.lapRadius, cr.lapHeight, tower)
				expect(at.Y >= 0).to.equal(true)
				expect(Vector3.new(at.X, 0, at.Z).Magnitude <= cr.lapRadius + 1e-6).to.equal(true)
				-- smooth: no jump between two samples
				expect((at - last).Magnitude < 3).to.equal(true)
				last = at
				if step > 20 and step < 150 then
					local angle = math.atan2(at.X, at.Z)
					if lastAngle ~= nil then
						local delta = (angle - lastAngle + math.pi) % (2 * math.pi) - math.pi
						turned += delta
					end
					lastAngle = angle
				end
			end
			-- most of a lap is flown round the castle (the rest is the rise and the landing)
			expect(turned > math.pi).to.equal(true)
			-- the wings beat as a motion, well under three times a second
			expect(cr.flapHz < 3).to.equal(true)
			-- a model with no lap stays in the yard
			local plain = Logic.dragonPlan(3, false)
			expect(Logic.dragonLap(plain, 5, cr.lapRadius, cr.lapHeight, tower).Magnitude).to.equal(
				0
			)
		end)

		it("throws the shards up and out, the same every time", function()
			local up = 0
			for i = 1, 12 do
				local way = Logic.dragonShard(i, 12)
				expect(math.abs(way.Magnitude - 1) < 1e-6).to.equal(true)
				expect((way - Logic.dragonShard(i, 12)).Magnitude).to.equal(0)
				if way.Y > 0 then
					up += 1
				end
			end
			expect(up >= 9).to.equal(true)
		end)

		it("adds more every stage", function()
			expect(#d.stages).to.equal(5)
			local function weight(st: any): number
				return st.sparks
					+ (st.smokeRings or 0) * 10
					+ (st.emberRing or 0)
					+ (st.column or 0)
					+ (st.coins or 0)
					+ (st.confetti or 0)
			end
			for stage = 2, 5 do
				expect(weight(d.stages[stage]) > weight(d.stages[stage - 1])).to.equal(true)
				expect(d.stages[stage].height > d.stages[stage - 1].height).to.equal(true)
			end
			expect(d.stages[1].smokeRings).to.equal(nil)
			expect(d.stages[2].emberRing).to.equal(nil)
			expect(d.stages[3].coins).to.equal(nil)
			expect(d.stages[4].confetti).to.equal(nil)
			expect(d.stages[5].confetti ~= nil).to.equal(true)
			for _, colour in { "pastel", "ruby", "sapphire", "emerald", "amethyst" } do
				expect(d.scales[colour] ~= nil).to.equal(true)
			end
		end)

		it("sounds each beat and each card from cues that exist", function()
			for _, beat in { "swing", "curl", "crack", "lap", "land", "roar" } do
				local cue = AudioLogic.dragonRiseCue(beat)
				expect(cue ~= nil and Cues[cue] ~= nil).to.equal(true)
			end
			expect(AudioLogic.dragonRiseCue("hush")).to.equal(nil)
			expect(AudioLogic.dragonRiseCue(nil)).to.equal(nil)
			expect(Cues[AudioLogic.cardFlipCue("flip", "common")] ~= nil).to.equal(true)
			expect(AudioLogic.cardFlipCue("rare", "legendary")).to.equal("jingleLegendary")
			expect(AudioLogic.cardFlipCue("rare", "Mythic")).to.equal("jingleMythical")
			expect(Cues.jingleLegendary ~= nil and Cues.jingleMythical ~= nil).to.equal(true)
			expect(AudioLogic.cardFlipCue("other", "rare")).to.equal(nil)
		end)

		it("flips the cards one at a time, about 0.4 s apart, each edge in its rarity", function()
			local c = d.cards
			expect(c.gap >= 0.35 and c.gap <= 0.5).to.equal(true)
			-- a card has turned before the next one starts
			expect(c.shut + c.open <= c.gap).to.equal(true)
			expect(c.edgePulse > c.edge).to.equal(true)
			for _, rarity in { "common", "rare", "epic", "legendary", "mythic" } do
				expect(c.edges[rarity] ~= nil).to.equal(true)
			end
			expect(#c.rainbow >= 4).to.equal(true)
			-- the Mythic rainbow turns slowly: one turn takes well over a second
			expect(360 / c.rainbowTurn > 3).to.equal(true)
		end)
	end)
end
