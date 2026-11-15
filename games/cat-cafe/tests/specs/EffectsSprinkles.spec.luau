--!strict
-- Sprinkles, the Starter Bundle's baker (Derek 2026-11-14: as good as an Epic from the best area, effects included):
-- its signature effect sits on the Epic rung of the new areas' ladder, on the lit parts of its model (#4190).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any

	-- what a spec costs: its emitters' rates, with an orbit and an arrival counted on top
	local function weight(spec: any): number
		local total = Presets.emitters[spec.emitter].rate
		for _, extra in spec.extras or {} do
			total += Presets.emitters[extra.emitter].rate
		end
		return total
			+ (if spec.orbit ~= nil then 10 else 0)
			+ (if spec.arrive ~= nil then 10 else 0)
	end

	describe("Effects Sprinkles' signature effect", function()
		it("is an Epic's: sprinkles off the candle and a twinkle on the cherry, gently", function()
			local spec = Presets.signature.sprinkles
			expect(spec ~= nil).to.equal(true)
			expect(Catalog.catsById.sprinkles.rarity).to.equal("Epic")
			expect(spec.minor == nil).to.equal(true)
			expect(spec.on).to.equal("Candle_Glow")
			expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
			expect(#spec.extras).to.equal(1)
			expect(spec.extras[1].on).to.equal("Cherry_Glow")
			expect(Presets.emitters[spec.extras[1].emitter].rate <= 1).to.equal(true)
			-- nothing a Legendary or a Mythical has on top
			expect(spec.orbit == nil and spec.arrive == nil and spec.eyes == nil).to.equal(true)
		end)

		it("shows the puff's own colours, and gold on a gold copy", function()
			local spec = Presets.signature.sprinkles
			expect(spec.colors).to.deepEqual(Presets.shopCats.sprinkles.colours)
			expect(Logic.signatureColors("sprinkles", false)).to.equal(spec.colors)
			expect(Logic.signatureColors("sprinkles", true)).to.equal(spec.gold)
			expect(#spec.gold > 0).to.equal(true)
		end)

		it("is at least as much as the best area's Epics and less than its Legendary", function()
			local mine = weight(Presets.signature.sprinkles)
			expect(mine >= weight(Presets.signature.knight)).to.equal(true)
			expect(mine >= weight(Presets.signature.mage)).to.equal(true)
			expect(mine < weight(Presets.signature.queen)).to.equal(true)
		end)
	end)
end
