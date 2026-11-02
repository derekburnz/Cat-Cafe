--!strict
-- Everyday moments (Derek 2026-10-27: catching, upgrades, tiers, a good spin): how a catch pops by rarity, how a
-- spin prize is celebrated by its chance, and that the bigger effects stay inside the phone budget. Written by the
-- vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

	local function onPhone(count: number): number
		local low = Presets.budget.low
		return math.clamp(math.floor(count * low.burstScale + 0.5), 1, low.maxBurst)
	end

	describe("Effects everyday moments", function()
		it(
			"pops a rarer catch bigger: a wider ring, confetti from Epic and a beam from Legendary",
			function()
				local lastRing, lastConfetti = 0, 0
				for _, rarity in ORDER do
					local ring, confetti, beam = Logic.catchPop(rarity)
					expect(ring > lastRing).to.equal(true)
					expect(confetti >= lastConfetti).to.equal(true)
					expect(confetti > 0).to.equal(rarity ~= "Common" and rarity ~= "Rare")
					expect(beam).to.equal(rarity == "Legendary" or rarity == "Mythical")
					lastRing, lastConfetti = ring, confetti
				end
				local ring, confetti, beam = Logic.catchPop("Sparkly")
				local commonRing = Logic.catchPop("Common")
				expect(ring == commonRing and confetti == 0 and beam == false).to.equal(true)
			end
		)

		it("celebrates a spin by the prize's chance and never an unknown slice", function()
			-- the wheel as Catalog.spinWheel has it on 2026-10-27: 30, 22, 18, 15, 10 and 5 in 100
			local weights = { 30, 22, 18, 15, 10, 5 }
			local expected = { "small", "small", "small", "good", "good", "jackpot" }
			for slice, tier in expected do
				expect(Logic.prizeTier(weights, slice)).to.equal(tier)
			end
			expect(Logic.prizeTier(weights, nil)).to.equal("small")
			expect(Logic.prizeTier(weights, 7)).to.equal("small")
			expect(Logic.prizeTier({}, 1)).to.equal("small")
			expect(Presets.wheel.jackpot < Presets.wheel.good).to.equal(true)
			expect(Presets.wheel.jackpotFlashes > Presets.wheel.flashes).to.equal(true)
		end)

		it("keeps the new bursts and confetti inside the phone budget", function()
			local low = Presets.budget.low
			for _, count in
				{
					Presets.purchase.sparkle,
					Presets.purchase.dust,
					Presets.purchase.swirl[1],
					Presets.purchase.swirl[2],
					Presets.rankUp.fountain,
					Presets.bursts.shower,
				}
			do
				expect(onPhone(count) <= 12).to.equal(true)
			end
			expect(Presets.emitters.shower ~= nil).to.equal(true)
			-- your own rank up throws both sides' confetti at once; a Mythical catch or a jackpot one burst
			local rankUp = 2 * math.ceil(low.confetti * Presets.rankUp.sideConfetti)
			expect(rankUp <= Presets.confetti.maxLive).to.equal(true)
			for _, share in
				{
					Presets.catchPop.confetti.Mythical,
					Presets.wheel.jackpotConfetti,
					Presets.purchase.confetti,
				}
			do
				expect(share > 0 and share <= 1).to.equal(true)
			end
		end)
	end)
end
