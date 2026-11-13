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
			expect(x.big <= 5).to.equal(true)
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
