--!strict
-- The Mystic Pool's roll (#3314, trait-station.md section 1a): the liquid's colour steps follow shared/Traits, stop on
-- the rolled rarity and never go past it, and take about the spec's times. Written by the vfx-animator.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits")) :: any

	describe("Effects Mystic Pool", function()
		it("steps through the same rarities as shared/Traits, in the same order", function()
			expect(#Logic.POOL_RARITIES).to.equal(#Traits.RARITIES)
			for i, r in Traits.RARITIES do
				expect(Logic.POOL_RARITIES[i]).to.equal(r.id)
			end
		end)

		it("goes grey first and stops on the rolled rarity", function()
			expect(table.concat(Logic.poolSteps("common"), ",")).to.equal("common")
			expect(table.concat(Logic.poolSteps("uncommon"), ",")).to.equal("common,uncommon")
			expect(table.concat(Logic.poolSteps("rare"), ",")).to.equal("common,uncommon,rare")
			expect(table.concat(Logic.poolSteps("epic"), ",")).to.equal("common,uncommon,rare,epic")
			expect(table.concat(Logic.poolSteps("legendary"), ",")).to.equal(
				"common,uncommon,rare,epic,legendary"
			)
			expect(#Logic.poolSteps("mythic")).to.equal(6)
			expect(table.concat(Logic.poolSteps("nonsense"), ",")).to.equal("common")
		end)

		it("matches Traits.poolSteps' colours for every trait rarity", function()
			for _, r in Traits.RARITIES do
				local trait = Traits.ofRarity(r.id)[1]
				local theirs = Traits.poolSteps({ id = trait.id })
				local ours = Logic.poolSteps(r.id)
				expect(#ours).to.equal(#theirs)
				for i, id in ours do
					local hex
					for _, s in Traits.RARITIES do
						if s.id == id then
							hex = s.color
						end
					end
					expect(hex).to.equal(theirs[i])
				end
			end
		end)

		it("takes about the spec's times in the pool", function()
			local want: { [string]: number } = {
				common = 1.2,
				uncommon = 1.8,
				rare = 2.4,
				epic = 3.0,
				legendary = 3.6,
				mythic = 4.6,
			}
			for id, seconds in want do
				expect(math.abs(Logic.poolSeconds(id) - seconds) < 0.05).to.equal(true)
			end
		end)

		it("only ever steps up and never shows a colour past the roll", function()
			for _, r in Traits.RARITIES do
				local n = #Logic.poolSteps(r.id)
				local last, t = 0, 0
				while t <= Logic.poolSeconds(r.id) + 0.5 do
					local i, k, done = Logic.poolAt(r.id, t)
					expect(i >= last).to.equal(true)
					expect(i <= n).to.equal(true)
					expect(k >= 0 and k <= 1).to.equal(true)
					if done then
						expect(i).to.equal(n)
						expect(k).to.equal(1)
					end
					last = i
					t += 0.05
				end
				expect(last).to.equal(n)
			end
		end)

		it("keeps its bursts inside the phone budget and has its emitters", function()
			local p = Presets.mysticPool
			local most = Presets.budget.high.maxBurst
			for _, count in { p.sparkles, p.bubbles, p.splash, p.stars, p.revealSparkles } do
				expect(count <= most).to.equal(true)
			end
			for _, name in { "poolBubble", "splashDrops", "catchSparkle" } do
				expect(Presets.emitters[name]).to.be.ok()
			end
			expect(Presets.emitters.poolBubble.rate).to.equal(0)
		end)
	end)
end
