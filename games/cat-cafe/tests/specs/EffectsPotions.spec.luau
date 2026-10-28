--!strict
-- Potion glows and the Mystery Visitor (F64, data-model 12b and 13): every potion kind has a glow on a body part
-- that exists, the glows stay inside the budget with none in Low performance, the drinker shows their newest potion,
-- the drink pop plays only when one of your own buffs runs longer, and a gift's pop is in the colour of what was
-- inside. Written by the vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	-- The four potions of data-model 12b and the three quest potions of quests.md section 4.
	local KINDS = {
		"tip_potion",
		"lucky_potion",
		"swift_potion",
		"steady_potion",
		"big_tip_potion",
		"gold_rush_potion",
		"quick_bait_potion",
	}
	local PLACES = { Body = true, Feet = true, Hands = true }

	describe("Effects potion glows and the Mystery Visitor", function()
		it("gives every potion a glow on a body place with a modest steady emitter", function()
			local ids = table.clone(KINDS)
			if type(Catalog.potions) == "table" then
				-- Catalog.potions is the bag's ordered rows (F64); a map keyed by id reads too
				for key, row in Catalog.potions do
					table.insert(ids, if type(row) == "table" and type(row.id) == "string" then row.id else key)
				end
			end
			for _, id in ids do
				local spec = Presets.potions[id]
				expect(spec ~= nil).to.equal(true)
				expect(PLACES[spec.on]).to.equal(true)
				local emitter = Presets.emitters[spec.emitter]
				expect(emitter ~= nil).to.equal(true)
				expect(emitter.rate > 0 and emitter.rate <= 4).to.equal(true)
			end
		end)

		it("keeps the glows inside the budget, none in Low performance", function()
			local low, high, saver =
				Presets.budget.low, Presets.budget.high, Presets.budget.lowPerformance
			expect(saver.potionGlows).to.equal(0)
			expect(low.potionGlows >= 1).to.equal(true)
			expect(low.potionGlows <= high.potionGlows).to.equal(true)
			expect(Presets.emitters.giftTwinkle ~= nil).to.equal(true)
		end)

		it("shows the newest running potion and nothing for none or an unknown kind", function()
			expect(Logic.newestPotion("")).to.equal(nil)
			expect(Logic.newestPotion(nil)).to.equal(nil)
			expect(Logic.newestPotion(3)).to.equal(nil)
			expect(Logic.newestPotion("tip_potion")).to.equal("tip_potion")
			expect(Logic.newestPotion("tip_potion,swift_potion")).to.equal("swift_potion")
			expect(Logic.newestPotion(" tip_potion , lucky_potion ")).to.equal("lucky_potion")
			expect(Logic.newestPotion("tip_potion,mystery_potion")).to.equal(nil)
		end)

		it("pops only when one of your own buffs runs longer", function()
			expect(Logic.potionDrunk(nil, { tip_potion = 100 })).to.equal(nil) -- the first sync
			expect(Logic.potionDrunk({}, { tip_potion = 100 })).to.equal("tip_potion")
			expect(Logic.potionDrunk({ tip_potion = 100 }, { tip_potion = 700 })).to.equal(
				"tip_potion"
			)
			expect(Logic.potionDrunk({ tip_potion = 100 }, {})).to.equal(nil) -- ran out
			expect(Logic.potionDrunk({ tip_potion = 100 }, { tip_potion = 100 })).to.equal(nil)
			expect(
				Logic.potionDrunk(
					{ tip_potion = 100, swift_potion = 50 },
					{ tip_potion = 100, swift_potion = 350 }
				)
			).to.equal("swift_potion")
		end)

		it("colours a gift's pop by what was inside", function()
			local palette = Presets.palette
			expect(Logic.giftColour("potion", "lucky_potion")).to.equal(
				Presets.potions.lucky_potion.colour
			)
			expect(Logic.giftColour("potion", "unknown")).to.equal(Presets.mystery.kinds.potion)
			expect(Logic.giftColour("lure", "salmon")).to.equal(Presets.mystery.kinds.lure)
			expect(Logic.giftColour("fish", nil)).to.equal(Presets.mystery.kinds.fish)
			expect(Logic.giftColour("spin", nil)).to.equal(Presets.mystery.kinds.spin)
			expect(Logic.giftColour(nil, nil)).to.equal(palette.neonPink)
		end)
	end)
end
