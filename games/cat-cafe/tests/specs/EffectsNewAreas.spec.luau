--!strict
-- #4070 the Water Park and #4071 the Medieval Castle: each area's air, its strays' puff, its cannon tint and a catch
-- that grows with the cat's rarity (Derek 2026-11-13: "make the rarer ones more special"). Written by the
-- vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Water Park and Castle", function()
		for _, area in { "waterpark", "castle" } do
			it(
				"gives the " .. area .. " its air, a stray puff and a cannon tint, in budget",
				function()
					local spec = Presets.areaFx.areas[area]
					expect(spec).to.be.ok()
					local air = Presets.emitters[spec.air]
					expect(air).to.be.ok()
					expect(air.rate <= 14).to.equal(true) -- no thicker than the snow
					expect(air.size[1] <= 0.25).to.equal(true) -- motes, never a fog
					expect(Presets.emitters[spec.puffPreset]).to.be.ok()
					expect(Presets.cannon.tints[area]).to.be.ok()
				end
			)

			it("makes a catch in the " .. area .. " bigger as the cat gets rarer", function()
				local spec = Presets.catchFlavour.areas[area]
				expect(Presets.emitters[spec.preset]).to.be.ok()
				local function size(rarity: string): number
					local plan = Logic.catchFlavour(area, "some_cat", rarity)
					return plan.puff + plan.flakes + plan.ringScale * 10 + plan.gusts * 10
				end
				expect(size("Common")).to.equal(size("Rare"))
				expect(size("Epic") > size("Rare")).to.equal(true)
				expect(size("Legendary") > size("Epic")).to.equal(true)
				expect(size("Mythical") > size("Legendary")).to.equal(true)
				expect(size("Secret")).to.equal(size("Mythical"))
				-- a short column, quick but never a flicker
				expect(spec.gusts <= 4 and spec.gustEvery >= 0.12).to.equal(true)
			end)
		end

		it("gives the Water Park's rarer cats more, each in gold on a gold cat", function()
			local places = { Body = true, Head = true, Prop = true, Prop2 = true }
			local function weight(spec: any): number
				local n = 1 + #(spec.extras or {})
				if spec.orbit ~= nil then
					n += 1
				end
				if spec.arrive ~= nil then
					n += 1
				end
				if spec.eyes == true then
					n += 1
				end
				return n
			end
			local sig = Presets.signature
			for _, catId in { "clown", "water_gun", "coaster", "water" } do
				local spec = sig[catId]
				expect(spec).to.be.ok()
				expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
				expect(places[spec.on]).to.equal(true)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
				for _, extra in spec.extras or {} do
					expect(Presets.emitters[extra.emitter].rate <= 2).to.equal(true)
					expect(places[extra.on]).to.equal(true)
				end
			end
			-- Epic < Legendary < Mythical, and the two Epics match
			expect(weight(sig.clown)).to.equal(weight(sig.water_gun))
			expect(weight(sig.clown) < weight(sig.coaster)).to.equal(true)
			expect(weight(sig.coaster) < weight(sig.water)).to.equal(true)
			-- the commons and rares have none: their props do the talking
			for _, catId in
				{ "popcorn", "pinwheel", "splash", "taffy", "candy_apple", "cotton_candy" }
			do
				expect(sig[catId] == nil).to.equal(true)
			end
			-- the Water Cat: a slow swirl, a splash in budget, a taller fountain on its catch
			local water = sig.water
			expect(water.orbit.seconds >= 2).to.equal(true)
			expect(Presets.emitters[water.orbit.emitter].rate <= 2).to.equal(true)
			expect(water.arrive.burst <= Presets.budget.low.maxBurst).to.equal(true)
			expect(Presets.emitters[water.arrive.preset]).to.be.ok()
			local spec = Presets.catchFlavour.areas.waterpark
			expect(Logic.catchFlavour("waterpark", "water", "Mythical").gusts).to.equal(
				spec.gusts + spec.cats.water
			)
			-- the whoosh and the wet trail only while the cat moves
			expect(sig.coaster.extras[2].moving).to.equal(true)
			expect(sig.water.extras[2].moving).to.equal(true)
		end)

		it("gives the Castle's rarer cats more, each in gold on a gold cat", function()
			local places = { Body = true, Head = true, Prop = true, Prop2 = true }
			local function weight(spec: any): number
				local n = 1 + #(spec.extras or {})
				if spec.orbit ~= nil then
					n += 1
				end
				if spec.arrive ~= nil then
					n += 1
				end
				if spec.eyes == true then
					n += 1
				end
				return n
			end
			local sig = Presets.signature
			for _, catId in { "knight", "mage", "queen", "dragon_knight" } do
				local spec = sig[catId]
				expect(spec).to.be.ok()
				expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
				expect(places[spec.on]).to.equal(true)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
				for _, extra in spec.extras or {} do
					expect(Presets.emitters[extra.emitter].rate <= 2).to.equal(true)
					expect(places[extra.on]).to.equal(true)
				end
			end
			expect(weight(sig.knight)).to.equal(weight(sig.mage))
			expect(weight(sig.knight) < weight(sig.queen)).to.equal(true)
			expect(weight(sig.queen) < weight(sig.dragon_knight)).to.equal(true)
			for _, catId in { "elf", "squire", "dwarf", "crumpet", "jester", "rogue" } do
				expect(sig[catId] == nil).to.equal(true)
			end
			local dragon = sig.dragon_knight
			expect(dragon.orbit.seconds >= 2).to.equal(true)
			expect(Presets.emitters[dragon.orbit.emitter].rate <= 2).to.equal(true)
			expect(dragon.arrive.burst <= Presets.budget.low.maxBurst).to.equal(true)
			expect(Presets.emitters[dragon.arrive.preset]).to.be.ok()
			expect(dragon.extras[2].moving).to.equal(true)
			local spec = Presets.catchFlavour.areas.castle
			expect(Logic.catchFlavour("castle", "dragon_knight", "Mythical").gusts).to.equal(
				spec.gusts + spec.cats.dragon_knight
			)
			-- the same weight as the Water Park's Mythical, and no less than the Snowy one's
			expect(weight(dragon)).to.equal(weight(sig.water))
			expect(weight(dragon) >= weight(sig.blizzard)).to.equal(true)
		end)

		it("reads each new area's box from the Config by its own name", function()
			local boxes = {
				{
					id = "waterpark",
					centre = { x = 0, z = 0 },
					size = { width = 100, depth = 100 },
				},
				{
					id = "castle",
					centre = { x = 500, z = 0 },
					size = { width = 100, depth = 100 },
				},
			}
			expect(Logic.areaAt(10, 10, boxes, 0)).to.equal("waterpark")
			expect(Logic.areaAt(520, -20, boxes, 0)).to.equal("castle")
			expect(Logic.areaAt(250, 0, boxes, 0)).to.equal(nil)
		end)
	end)
end
