--!strict
-- #4369: every Secret cat has a signature effect of its own, one rung above a Mythical's, in gold on a gold cat and
-- inside the phone budget (Presets.signature).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any

	local SECRETS = {
		"nebula",
		"glitch",
		"cafe_ghost",
		"lucky_clover",
		"moonstag",
		"ooze",
		"djinn",
		"phoenix",
		"abyss",
		"excalipurr",
	}

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

	describe("Effects Secret cats' signature effects", function()
		it("gives each of the ten an effect of its own, in gold on a gold cat", function()
			local seen: { [string]: boolean } = {}
			for _, catId in SECRETS do
				local spec = Presets.signature[catId]
				expect(spec).to.be.ok()
				expect(spec.minor == nil).to.equal(true)
				expect(#spec.colors > 0 and #spec.gold > 0).to.equal(true)
				expect(Logic.signatureColors(catId, false)).to.equal(spec.colors)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
				-- no two Secrets share the same effect on the same part in the same first colour
				local key = spec.emitter .. "|" .. spec.on .. "|" .. tostring(spec.colors[1])
				expect(seen[key] == nil).to.equal(true)
				seen[key] = true
			end
		end)

		it("covers every Secret the Catalog has", function()
			local missing = {}
			for catId, def in Catalog.catsById do
				-- #5502: the advent calendar cats get their own glow from Motion-FX (advent-calendar-spec section 8)
				if
					def.rarity == "Secret"
					and def.source ~= "advent"
					and Presets.signature[catId] == nil
				then
					table.insert(missing, catId)
				end
			end
			table.sort(missing)
			expect(table.concat(missing, " ")).to.equal("")
		end)

		it("puts a Secret one rung above the Mythicals", function()
			local most = 0
			for catId, spec in Presets.signature do
				local def = Catalog.catsById[catId]
				if def ~= nil and def.rarity ~= "Secret" then
					most = math.max(most, weight(spec))
				end
			end
			for _, catId in SECRETS do
				expect(weight(Presets.signature[catId]) > most).to.equal(true)
			end
		end)

		it("stays gentle and inside the phone budget", function()
			for _, catId in SECRETS do
				local spec = Presets.signature[catId]
				expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
				local walking = 0
				for _, extra in spec.extras do
					expect(Presets.emitters[extra.emitter].rate <= 2).to.equal(true)
					if extra.moving == true then
						walking += 1
					end
				end
				expect(walking).to.equal(1)
				expect(Presets.emitters[spec.orbit.emitter].rate <= 2).to.equal(true)
				expect(spec.orbit.seconds >= 2).to.equal(true)
				expect(spec.orbit.countLow <= 3 and spec.orbit.countLow < spec.orbit.count).to.equal(
					true
				)
				expect(spec.arrive.burst <= Presets.budget.low.maxBurst).to.equal(true)
				expect(Presets.emitters[spec.arrive.preset]).to.be.ok()
			end
		end)
	end)
end
