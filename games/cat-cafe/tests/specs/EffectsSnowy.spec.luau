--!strict
-- #4069 Snowy Mountain (Tier 8): the area's air and foot puffs, and its rarer cats' signature effects, which grow
-- with rarity (Derek 2026-11-13: "make the rarer ones more special"): the Epic Ice Cat a glint, the Legendary White
-- Tiger Cat breath, a glint and glowing eyes, the Mythical Blizzard Cat flakes, a circling swirl, a frost trail and
-- a gust where it lands. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local PLACES = { Body = true, Head = true, Prop = true, Prop2 = true }

	-- how much a signature shows: its emitters, its swirl and its gust
	local function weight(spec: any): number
		local n = 1
		if spec.extras ~= nil then
			n += #spec.extras
		end
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

	describe("Effects Snowy Mountain", function()
		it("has snow in the air, a puff, foot puffs and the cannon tint, in budget", function()
			local spec = Presets.areaFx.areas.snowy
			expect(spec).to.be.ok()
			local air = Presets.emitters[spec.air]
			expect(air).to.be.ok()
			-- the flakes fall, and fade before they could pile up at your feet
			expect(air.acceleration.Y < 0).to.equal(true)
			expect(air.transparency[2]).to.equal(1)
			expect(air.rate <= 16).to.equal(true)
			expect(Presets.emitters[spec.puffPreset]).to.be.ok()
			expect(spec.puff <= Presets.budget.low.maxBurst).to.equal(true)
			expect(Presets.emitters[spec.footPreset]).to.be.ok()
			expect(spec.footPuff >= 1 and spec.footPuff <= 4).to.equal(true)
			expect(spec.footStuds >= 2).to.equal(true)
			expect(spec.lift > Presets.areaFx.lift).to.equal(true)
			expect(Presets.cannon.tints.snowy ~= nil).to.equal(true)
		end)

		it("gives the rarer cats more, each in gold on a gold cat", function()
			local ice = Presets.signature.ice
			local tiger = Presets.signature.white_tiger
			local blizzard = Presets.signature.blizzard
			local three: { [string]: any } = { ice = ice, white_tiger = tiger, blizzard = blizzard }
			for catId, spec in three do
				expect(spec ~= nil).to.equal(true)
				expect(Presets.emitters[spec.emitter] ~= nil).to.equal(true)
				expect(PLACES[spec.on]).to.equal(true)
				expect(#spec.colors > 0 and #spec.gold > 0).to.equal(true)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
				for _, extra in spec.extras or {} do
					expect(Presets.emitters[extra.emitter] ~= nil).to.equal(true)
					expect(Presets.emitters[extra.emitter].rate <= 2).to.equal(true)
					expect(PLACES[extra.on]).to.equal(true)
				end
			end
			-- Epic < Legendary < Mythical
			expect(weight(ice) < weight(tiger)).to.equal(true)
			expect(weight(tiger) < weight(blizzard)).to.equal(true)
			-- the commons and rares have none: their props do the talking
			for _, catId in { "flurry", "mitten", "hot_chocolate", "spruce", "snow_boots", "ski" } do
				expect(Presets.signature[catId] == nil).to.equal(true)
			end
			expect(blizzard.arrive.burst <= Presets.budget.low.maxBurst).to.equal(true)
			expect(Presets.emitters[blizzard.arrive.preset] ~= nil).to.equal(true)
			-- the frost trail only while it walks
			expect(blizzard.extras[1].moving).to.equal(true)
		end)

		it("circles the Blizzard Cat's swirl evenly at its radius, slowly", function()
			local o = Presets.signature.blizzard.orbit
			expect(Presets.emitters[o.emitter] ~= nil).to.equal(true)
			expect(Presets.emitters[o.emitter].rate <= 2).to.equal(true)
			expect(o.countLow <= o.count and o.countLow >= 1).to.equal(true)
			expect(o.seconds >= 2).to.equal(true) -- a slow turn, never a flicker
			local radius = 2
			for step = 0, 12 do
				local t = step * 0.37
				local sum = Vector3.new(0, 0, 0)
				for i = 1, o.count do
					local at = Logic.orbitOffset(i, o.count, t, radius, o.tilt, o.seconds)
					expect(math.abs(at.Magnitude - radius) < 1e-6).to.equal(true)
					sum += at
				end
				-- spread evenly: the motes balance round the middle
				expect(sum.Magnitude < 1e-6).to.equal(true)
			end
			-- once round every `seconds`
			local a = Logic.orbitOffset(1, o.count, 0, radius, o.tilt, o.seconds)
			local b = Logic.orbitOffset(1, o.count, o.seconds, radius, o.tilt, o.seconds)
			expect((a - b).Magnitude < 1e-6).to.equal(true)
		end)
	end)
end
