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
			-- the second Epic matches the first
			local leopard = Presets.signature.snow_leopard
			expect(weight(leopard)).to.equal(weight(ice))
			expect(Presets.emitters[leopard.emitter] ~= nil and PLACES[leopard.on]).to.equal(true)
			-- the commons have none: their props do the talking
			for _, catId in { "flurry", "mitten", "hot_chocolate", "spruce" } do
				expect(Presets.signature[catId] == nil).to.equal(true)
			end
			-- the Rares: one faint emitter, only while they move, and only in a slot no rarer cat needs
			for _, catId in { "snow_boots", "ski" } do
				local rare = Presets.signature[catId]
				expect(weight(rare)).to.equal(1)
				expect(rare.moving).to.equal(true)
				expect(rare.minor).to.equal(true)
				expect(rare.eyes).to.equal(nil)
				local kick = Presets.emitters[rare.emitter]
				expect(kick.rate < Presets.emitters.sigFrostTrail.rate).to.equal(true)
				expect(kick.transparency[1] > Presets.emitters.sigFrostTrail.transparency[1]).to.equal(
					true
				)
			end
			expect(blizzard.arrive.burst <= Presets.budget.low.maxBurst).to.equal(true)
			expect(Presets.emitters[blizzard.arrive.preset] ~= nil).to.equal(true)
			-- the frost trail only while it walks
			expect(blizzard.extras[1].moving).to.equal(true)
		end)

		it("adds more snow to a catch the rarer the cat, and nothing outside the area", function()
			expect(Logic.catchFlavour("alley", "tabby", "Mythical")).to.equal(nil)
			expect(Logic.catchFlavour(nil, nil, nil)).to.equal(nil)
			local spec = Presets.catchFlavour.areas.snowy
			expect(Presets.emitters[spec.preset] ~= nil).to.equal(true)
			local order = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
			local last = -1
			for _, rarity in order do
				local plan = Logic.catchFlavour("snowy", "flurry", rarity)
				local total = plan.puff + plan.flakes + plan.ringScale + plan.gusts
				expect(total >= last).to.equal(true)
				last = total
				expect(plan.puff <= Presets.budget.low.maxBurst).to.equal(true)
				expect(plan.flakes <= Presets.budget.low.maxBurst).to.equal(true)
			end
			local common = Logic.catchFlavour("snowy", "flurry", "Common")
			expect(common.flakes == 0 and common.ringScale == 0 and common.gusts == 0).to.equal(
				true
			)
			local epic = Logic.catchFlavour("snowy", "ice", "Epic")
			expect(epic.flakes > 0 and epic.ringScale == 0).to.equal(true)
			local legendary = Logic.catchFlavour("snowy", "white_tiger", "Legendary")
			expect(legendary.ringScale > 1 and legendary.gusts == 0).to.equal(true)
			local mythical = Logic.catchFlavour("snowy", "blizzard", "Mythical")
			expect(mythical.gusts).to.equal(spec.gusts + spec.cats.blizzard)
			-- the gusts climb slowly: one at a time, well apart
			expect(spec.gustEvery >= 0.15).to.equal(true)
			-- an unknown rarity is treated as a Common
			expect(Logic.catchFlavour("snowy", nil, "Odd").flakes).to.equal(0)
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

		it("wriggles a cat stuck in each of the Snowy Mountain's traps", function()
			for _, trap in { "snowdrift", "snow_log", "snowman", "sled" } do
				expect(Logic.stuckStyle(trap)).to.equal("stuckButt")
			end
		end)

		it("shows the northern lights through the day's last stretch and the night", function()
			local evening = Presets.areaFx.auroraEvening
			expect(evening >= 30 and evening <= 120).to.equal(true)
			expect(Logic.auroraOn("night", nil, evening)).to.equal(true)
			expect(Logic.auroraOn("night", 40, evening)).to.equal(true)
			expect(Logic.auroraOn("day", evening, evening)).to.equal(true)
			expect(Logic.auroraOn("day", 5, evening)).to.equal(true)
			expect(Logic.auroraOn("day", evening + 1, evening)).to.equal(false)
			expect(Logic.auroraOn("day", nil, evening)).to.equal(false)
			expect(Logic.auroraOn(nil, nil, evening)).to.equal(false)
		end)

		it(
			"hangs the northern lights across the way the camera looks, in its upper view",
			function()
				local a = Presets.areaFx.areas.snowy.aurora :: any
				expect(a.window >= 200 and a.window <= 400).to.equal(true)
				expect(a.deep < a.window).to.equal(true) -- so the ribbons run across, not front to back
				expect(a.glide >= 2).to.equal(true) -- a slow glide, never a jump
				expect(a.recentre >= 60).to.equal(true) -- a small turn of the camera does not move them
				-- the spot is `ahead` out along the flat look, whatever the look's length or tilt
				local x, z, dirX, dirZ = Logic.auroraSpot(10, -20, 3, 0, a.ahead)
				expect(x).to.equal(10 + a.ahead)
				expect(z).to.equal(-20)
				expect(dirX).to.equal(1)
				expect(dirZ).to.equal(0)
				x, z, dirX, dirZ = Logic.auroraSpot(0, 0, -0.6, 0.8, 100)
				expect(x).to.be.near(-60, 1e-6)
				expect(z).to.be.near(80, 1e-6)
				expect(dirX * dirX + dirZ * dirZ).to.be.near(1, 1e-6)
				-- looking straight down: no flat look, the caller keeps its last one
				x, z, dirX, dirZ = Logic.auroraSpot(5, 6, 0.01, -0.02, a.ahead)
				expect(x).to.equal(5)
				expect(z).to.equal(6)
				expect(dirX).to.equal(0)
				expect(dirZ).to.equal(0)
				-- laid out about the part's own middle: side to side, each 6 to 16 degrees up from your feet
				local ribbons = Logic.auroraRibbons(
					a.ribbons[1],
					{ x = 0, z = 0 },
					{ width = a.window, depth = a.deep },
					0,
					a.spread,
					a.rise,
					a.curve,
					a.seconds,
					a.curveMost
				)
				for _, r in ribbons do
					local run = r.to - r.from
					expect(math.abs(run.Z) < 1e-6).to.equal(true)
					expect(math.abs(run.X) >= 200).to.equal(true)
					expect(math.abs(r.from.X + r.to.X) < 1e-6).to.equal(true)
					expect(math.abs(r.from.Z) <= a.deep / 2).to.equal(true)
					for _, out in { a.ahead - r.from.Z, a.ahead + r.from.Z } do
						local up = math.deg(math.atan2(a.height + r.from.Y, out))
						expect(up >= 6 and up <= 16).to.equal(true)
					end
				end
			end
		)

		it("hangs the northern lights over the area at night, slow and inside it", function()
			local a = Presets.areaFx.areas.snowy.aurora :: any
			expect(#a.ribbons).to.equal(3) -- one count per budget tier, fewer as the tier drops
			expect(a.ribbons[1] >= a.ribbons[2] and a.ribbons[2] >= a.ribbons[3]).to.equal(true)
			expect(a.ribbons[1] <= 3).to.equal(true) -- two Beams a ribbon: six at most
			-- soft, never a solid band: the smoke picture thins it further (#4085: 0.72 could not be seen at all)
			-- #4216: seen at dusk, when 0.55 to 0.62 vanished against the sky, so stronger than the night values were
			expect(a.shown >= 0.35 and a.shown < 1).to.equal(true)
			expect(a.brightness >= 1 and a.brightness <= 3).to.equal(true)
			-- thinner bands over wider ones, never more than three, and even all three together stay see-through
			expect(#a.nest >= 2 and #a.nest <= 3).to.equal(true)
			expect(a.nest[1]).to.equal(1)
			for n = 2, #a.nest do
				expect(a.nest[n] < a.nest[n - 1]).to.equal(true)
			end
			expect(a.nestLow >= 1 and a.nestLow <= #a.nest).to.equal(true)
			local through = 1
			for n = 1, #a.nest do
				expect(a.nestShown[n] >= 0.35 and a.nestShown[n] < 1).to.equal(true)
				expect(a.nestBright[n] >= 1 and a.nestBright[n] <= 2).to.equal(true)
				through *= a.nestShown[n]
			end
			expect(through >= 0.05).to.equal(true)
			for _, seconds in a.seconds do
				expect(seconds >= 8).to.equal(true) -- a slow sway
			end
			local centre = { x = 100, z = -400 }
			-- a wide area and a long one (the Snowy Mountain is 150 across and 560 deep): the ribbons run the long way
			for _, size in { { width = 300, depth = 200 }, { width = 150, depth = 560 } } do
				local alongZ = size.depth > size.width
				local long = if alongZ then size.depth else size.width
				local short = if alongZ then size.width else size.depth
				local ribbons = Logic.auroraRibbons(
					a.ribbons[1],
					centre,
					size,
					a.height,
					a.spread,
					a.rise,
					a.curve,
					a.seconds,
					a.curveMost
				)
				expect(#ribbons).to.equal(a.ribbons[1])
				for i, r in ribbons do
					local run = r.to - r.from
					-- level, along the long side, inside the box end to end
					expect(run.Y).to.equal(0)
					expect(math.abs(run.Magnitude - long * 0.8) < 1e-6).to.equal(true)
					expect(math.abs(if alongZ then run.X else run.Z) < 1e-6).to.equal(true)
					-- it bends square to its length, never more than curveMost
					expect(math.abs(r.across:Dot(run)) < 1e-6).to.equal(true)
					expect(math.abs(r.bend) <= a.curveMost).to.equal(true)
					-- spread over the short side, each a little higher, low enough for the default camera (#4216)
					local off = if alongZ then r.from.X - centre.x else r.from.Z - centre.z
					expect(math.abs(off) < short * a.spread / 2).to.equal(true)
					expect(r.from.Y).to.equal(a.height + (i - 1) * a.rise)
					-- neighbours bend to opposite sides
					expect(r.bend * (if i % 2 == 1 then 1 else -1) > 0).to.equal(true)
					expect(r.seconds >= 8).to.equal(true)
				end
			end
			expect(#Logic.auroraRibbons(0, centre, { width = 1, depth = 1 }, 1, 1, 1, 1, { 1 })).to.equal(
				0
			)
		end)
	end)
end
