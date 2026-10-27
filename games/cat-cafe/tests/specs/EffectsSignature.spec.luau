--!strict
-- Signature effects and the Codes Cat's circle (design v0.10, 2026-10-27): every Legendary and Mythical themed cat
-- has an effect with gold colours of its own (round 4 Q8), the effects stay inside the phone budget and the walk-in
-- circle never flickers at its edge (F65). Written by the vfx-animator for QA to move into tests/specs next to
-- EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	-- The Legendary and Mythical themed cats of the Alley, Park, Neighbourhood, Woods and Sewer (data-model 3).
	local SIGNATURE_CATS = {
		"void",
		"midnight",
		"blossom",
		"aurora",
		"marshmallow",
		"comet",
		"old_oak",
		"wisp",
		"bottlecap",
		"eclipse",
	}

	describe("Effects signature cats and the Codes Cat circle", function()
		it("gives every Legendary and Mythical themed cat an effect, in gold on a gold cat", function()
			for _, catId in SIGNATURE_CATS do
				local spec = Presets.signature[catId]
				expect(spec ~= nil).to.equal(true)
				expect(Presets.emitters[spec.emitter] ~= nil).to.equal(true)
				expect(spec.on == "Body" or spec.on == "Head").to.equal(true)
				expect(#spec.colors > 0 and #spec.gold > 0).to.equal(true)
				expect(Logic.signatureColors(catId, false)).to.equal(spec.colors)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
			end
			expect(Logic.signatureColors("tabby", true)).to.equal(nil)
			expect(Logic.signatureColors(nil, false)).to.equal(nil)
			-- Ninja Cat's eyes are its effect, so a gold one's eyes turn gold too
			expect(Presets.signature.void.eyes == true and Presets.signature.void.goldEyes ~= nil).to.equal(true)
		end)

		it("keeps the signature emitters gentle and inside the budget", function()
			for _, spec in Presets.signature do
				expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
			end
			local low, high, saver =
				Presets.budget.low, Presets.budget.high, Presets.budget.lowPerformance
			expect(saver.signatureCats <= low.signatureCats).to.equal(true)
			expect(low.signatureCats <= high.signatureCats).to.equal(true)
			expect(Presets.emitters.codesMotes.rate <= 2).to.equal(true)
		end)

		it("opens the circle at its radius and closes it only past the edge", function()
			local radius, leave = Presets.codes.radius, Presets.codes.leaveAfter
			expect(Logic.insideCircle(false, radius, radius, leave)).to.equal(true)
			expect(Logic.insideCircle(false, radius + 0.5, radius, leave)).to.equal(false)
			expect(Logic.insideCircle(true, radius + 0.5, radius, leave)).to.equal(true)
			expect(Logic.insideCircle(true, radius + leave + 0.01, radius, leave)).to.equal(false)
			expect(Logic.insideCircle(true, 0, radius, leave)).to.equal(true)
			-- the motes' square pad stays inside the circle
			expect(Presets.codes.padShare * math.sqrt(2) / 2 <= 1).to.equal(true)
		end)
	end)
end
