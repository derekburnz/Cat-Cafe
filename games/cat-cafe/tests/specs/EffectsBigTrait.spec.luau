--!strict
-- #3846: a Legendary or Mythic trait roll's cutscene (Effects/BigTraitCut). The pure parts: which rolls get it, its
-- title, the title's one grow-in and the fanfare's cue. The camera and the effects at the pool are a Studio row.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local AudioLogic = require(Client:WaitForChild("Audio"):WaitForChild("Logic")) :: any
	local Cues = require(Client:WaitForChild("Audio"):WaitForChild("Cues")) :: any

	local b = Presets.bigTrait

	describe("Effects big trait roll", function()
		it("plays for Legendary and Mythic only", function()
			expect(Logic.bigTraitRoll("legendary")).to.equal(true)
			expect(Logic.bigTraitRoll("mythic")).to.equal(true)
			for _, id in { "common", "uncommon", "rare", "epic", "nope" } do
				expect(Logic.bigTraitRoll(id)).to.equal(false)
			end
			expect(Logic.bigTraitRoll(nil)).to.equal(false)
		end)

		it("names the rarity in its title", function()
			expect(Logic.bigTraitTitle("legendary")).to.equal("LEGENDARY TRAIT!")
			expect(Logic.bigTraitTitle("mythic")).to.equal("MYTHIC TRAIT!")
		end)

		it("grows the title in once and then holds still", function()
			expect(Logic.bigTraitPop(0)).to.be.near(b.popFrom, 1e-9)
			expect(Logic.bigTraitPop(b.popSeconds)).to.be.near(b.popOver, 1e-6)
			expect(Logic.bigTraitPop(b.popSeconds * 2)).to.equal(1)
			expect(Logic.bigTraitPop(5)).to.equal(1)
			local last = Logic.bigTraitPop(0)
			for i = 1, 20 do
				local now = Logic.bigTraitPop(b.popSeconds * i / 20)
				expect(now >= last).to.equal(true)
				last = now
			end
		end)

		it("keeps the cutscene short and gives controls back", function()
			expect(b.big <= 3).to.equal(true)
			expect(b.screenSeconds <= 2.5).to.equal(true)
			expect(b.cap >= 12).to.equal(true) -- a Mythic roll (about 6 s) plus the big moment and the swing back
		end)

		it("makes a Mythic bigger than a Legendary and a Secret the biggest (#3908)", function()
			expect(Logic.bigTraitRoll("secret")).to.equal(true)
			expect(Logic.bigTraitTitle("secret")).to.equal("SECRET TRAIT!")
			local l, m, x =
				Logic.bigTraitSize("legendary"),
				Logic.bigTraitSize("mythic"),
				Logic.bigTraitSize("secret")
			for _, key in { "big", "beams", "rings", "stars", "confetti", "rays", "dim" } do
				expect((m :: any)[key] >= (l :: any)[key]).to.equal(true)
				expect((x :: any)[key] > (m :: any)[key]).to.equal(true)
			end
			-- an unknown rarity gets the Legendary's
			expect(Logic.bigTraitSize("rare")).to.equal(l)
			-- still short, and inside the cap with a Mythic roll and the swings
			expect(x.big <= 6).to.equal(true) -- #3942: the Secret scene runs about 8 s with the swings
			expect(x.screenSeconds <= 3).to.equal(true)
			expect(6 + x.big + b.swingIn + b.swingOut < b.cap).to.equal(true)
			-- a small shake only, and the screen never goes fully dark
			expect(x.shake <= 0.15).to.equal(true)
			expect(x.dim < 0.6).to.equal(true)
			-- the rings come one after the other, slower than about 3 a second
			expect(b.ringGap >= 1 / 3).to.equal(true)
		end)

		it("stands the light columns round the pool, one in the middle", function()
			expect(#Logic.bigTraitBeams(0, 5)).to.equal(0)
			local one = Logic.bigTraitBeams(1, 5)
			expect(#one).to.equal(1)
			expect(one[1]).to.equal(Vector3.zero)
			local five = Logic.bigTraitBeams(5, 5)
			expect(#five).to.equal(5)
			for i = 2, 5 do
				expect(math.abs(five[i].Magnitude - 2.5) < 1e-6).to.equal(true)
				expect(five[i].Y).to.equal(0)
			end
		end)

		it(
			"gives Mythic and Secret a whole scene, the Secret the bigger, inside the safety rules (#3942)",
			function()
				local b = Presets.bigTrait
				expect(Logic.bigTraitScene("rare")).to.equal(nil)
				expect(Logic.bigTraitScene(nil)).to.equal(nil)
				-- Derek 2026-11-13: a Legendary gets a small one, smaller than a Mythic's
				local l = Logic.bigTraitScene("legendary")
				expect(l ~= nil).to.equal(true)
				expect(l.orbit < 20 and l.bars < 0.1 and l.lift > 0 and l.constellation == false).to.equal(
					true
				)
				expect(l.liftHeight < Presets.mysticPool.liftHeight).to.equal(true)
				expect(l.orbit / l.orbitSeconds <= 10).to.equal(true)
				local m, x = Logic.bigTraitScene("mythic"), Logic.bigTraitScene("secret")
				expect(m ~= nil and x ~= nil).to.equal(true)
				expect(x.orbit > m.orbit and x.dim > m.dim and x.spiral > m.spiral).to.equal(true)
				expect(m.constellation).to.equal(false)
				-- the cat rises up the pillar a little longer for a Secret
				expect(x.lift > m.lift and m.lift > 0).to.equal(true)
				expect(x.constellation).to.equal(true)
				for _, scene in { m, x } :: { any } do
					-- bars never take more than a quarter of the screen, the world never goes near black
					expect(scene.bars > 0 and scene.bars <= 0.125).to.equal(true)
					expect(scene.dim > 0 and scene.dim <= 0.35).to.equal(true)
					-- a slow turn: no faster than 10 degrees a second
					expect(scene.orbit / scene.orbitSeconds <= 10).to.equal(true)
				end
				-- the scene runs about 6 s for a Mythic and 8 s for a Secret, well under the cap that frees the controls
				local mythicSeconds = b.swingIn + b.sizes.mythic.big + b.swingOut
				local secretSeconds = b.swingIn + b.sizes.secret.big + b.swingOut
				expect(secretSeconds > mythicSeconds).to.equal(true)
				expect(secretSeconds + 4 < b.cap).to.equal(true)
				-- the stars come one after the other, slower than about 10 a second, and the cat is done in the big moment
				expect(b.starGap >= 0.1).to.equal(true)
				expect(#Logic.CAT_CONSTELLATION * b.starGap < b.sizes.secret.big).to.equal(true)
			end
		)

		it(
			"climbs a Legendary's words RARE, EPIC, LEGENDARY slower than three a second (Derek 2026-11-13)",
			function()
				expect(#b.ladder).to.equal(3)
				expect(b.ladder[#b.ladder]).to.equal("legendary")
				expect(b.ladderGap >= 1 / 3).to.equal(true)
				-- the words and the title fit in the Legendary's big moment, before the swing back
				expect(#b.ladder * b.ladderGap + b.popSeconds * 2 < b.sizes.legendary.big).to.equal(
					true
				)
				for _, tier in b.ladder do
					expect(type(b.ladderWords[tier])).to.equal("string")
				end
			end
		)

		it("circles the camera round the pool at the same height and distance (#3942)", function()
			local look = Vector3.new(10, 5, -3)
			local eye = Vector3.new(10, 12, 9)
			local turned = Logic.sceneOrbit(look, eye, 90)
			expect(math.abs(turned.Y - eye.Y) < 1e-6).to.equal(true)
			expect(math.abs((turned - look).Magnitude - (eye - look).Magnitude) < 1e-6).to.equal(
				true
			)
			expect((Logic.sceneOrbit(look, eye, 0) - eye).Magnitude < 1e-6).to.equal(true)
			local first = Logic.sceneSpiral(1, 8, 2, 18)
			local last = Logic.sceneSpiral(8, 8, 2, 18)
			expect(first.Y).to.equal(0)
			expect(math.abs(last.Y - 18) < 1e-6).to.equal(true)
		end)

		it("plays the Legendary or Mythical fanfare on its beat", function()
			expect(AudioLogic.bigTraitCue("fanfare", "secret")).to.equal("jingleMythical")
			expect(AudioLogic.bigTraitCue("fanfare", "legendary")).to.equal("jingleLegendary")
			expect(AudioLogic.bigTraitCue("fanfare", "mythic")).to.equal("jingleMythical")
			expect(AudioLogic.bigTraitCue("other", "mythic")).to.equal(nil)
			expect(Cues.jingleLegendary ~= nil).to.equal(true)
			expect(Cues.jingleMythical ~= nil).to.equal(true)
		end)
	end)
end
