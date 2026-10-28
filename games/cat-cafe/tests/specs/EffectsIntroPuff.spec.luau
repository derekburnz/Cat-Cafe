--!strict
-- The intro's cat puff (F72, intro-cutscene.md section 2): small, within the burst budget and drawn from emitters that
-- exist. Written by the vfx-animator; QA moved it into tests/specs and added an edge.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects intro cat puff", function()
		it("puffs from emitters that exist, as bursts", function()
			for _, name in { "smokePuff", "gateSparkle" } do
				expect(Presets.emitters[name] ~= nil).to.equal(true)
				expect(Presets.emitters[name].rate).to.equal(0)
			end
		end)

		it("stays small: each burst under the default puff and the skill's 30", function()
			local p = Presets.introPuff
			for _, count in { p.from, p.seat, p.sparkle } do
				expect(count >= 1 and count < 30).to.equal(true)
			end
			expect(p.from <= Presets.bursts.smokePuff).to.equal(true)
			expect(p.seat <= Presets.bursts.smokePuff).to.equal(true)
		end)

		it("hooks a moment the intro really fires, so the swap is not left a plain cut (QA, #471)", function()
			local Moments = require(Client:WaitForChild("Moments")) :: any
			expect(Moments.IntroCatSeated).to.be.ok()
			expect(type(Moments.IntroCatSeated.Connect)).to.equal("function")
		end)
	end)
end
