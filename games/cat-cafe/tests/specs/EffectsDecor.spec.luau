--!strict
-- Crate openings, golden fish and the Mythical cafe styles (F53, golden-fish.md section 4): every Mythical crate
-- piece has its own effect on the slot its kind paints, the effects stay inside the steady emitter budget with none
-- moving in Low performance, a crate piece of any rarity has a catch pop to show, and the golden fish sparkle grows
-- with the gain and never plays for spending. Written by the vfx-animator for QA to move into tests/specs next to
-- EffectsLogic.spec.luau.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	-- Where each kind of piece shows: the plot style attribute it sets, or a placed model.
	local ON = {
		wallpaper = "Wallpaper",
		floor = "Floor",
		paint = "Paint",
		furniture = "model",
		decoration = "model",
	}

	describe("Effects crate openings, golden fish and Mythical decor", function()
		it("gives every Mythical crate piece an effect where its kind shows", function()
			local mythicals = 0
			for _, def in Catalog.crateDecor do
				if def.rarity == "Mythical" then
					mythicals += 1
					local spec = Presets.decor[def.id]
					expect(spec ~= nil).to.equal(true)
					expect(spec.on).to.equal(ON[def.kind])
					if spec.emitter ~= nil then
						expect(Presets.emitters[spec.emitter] ~= nil).to.equal(true)
						expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
					end
				end
			end
			expect(mythicals).to.equal(6)
		end)

		it("keeps the Mythical decor inside the steady emitter budget", function()
			for _, budget in Presets.budget do
				expect(budget.decorEffects <= budget.steadyEmitters).to.equal(true)
			end
			local low, high, saver =
				Presets.budget.low, Presets.budget.high, Presets.budget.lowPerformance
			expect(saver.decorEffects).to.equal(0) -- Low performance shows the still look only
			expect(low.decorEffects <= high.decorEffects).to.equal(true)
		end)

		it("has a pop for a crate piece of every rarity", function()
			for _, def in Catalog.crateDecor do
				local rarity = def.rarity or "Common"
				expect(Presets.rarity[rarity] ~= nil).to.equal(true)
				expect(Presets.catchSparkle[rarity] ~= nil).to.equal(true)
				expect(Presets.catchPop.ring[rarity] ~= nil).to.equal(true)
			end
		end)

		it("sparkles for golden fish gained and never for spending", function()
			expect(Logic.fishGain(nil, 12)).to.equal(0) -- the first count
			expect(Logic.fishGain(12, 12)).to.equal(0)
			expect(Logic.fishGain(70, 10)).to.equal(0) -- a crate bought
			expect(Logic.fishGain(10, 15)).to.equal(5)
			expect(Logic.fishGain(10, nil)).to.equal(0)
			local sparkles, ring = Logic.fishPickup(0)
			expect(sparkles).to.equal(0)
			expect(ring).to.equal(0)
			local lastSparkles, lastRing = 0, 0
			for _, step in Presets.fishPickup.steps do
				local s, r = Logic.fishPickup(step.from)
				expect(s > lastSparkles and r > lastRing).to.equal(true)
				expect(s <= 30).to.equal(true) -- a burst stays under 30 (animation-vfx section 6)
				lastSparkles, lastRing = s, r
			end
			local most = Logic.fishPickup(10000)
			expect(most).to.equal(lastSparkles)
		end)

		it("measures a turned box along the plot's axes", function()
			-- a quarter turn about Y, as a CFrame's axes (the cloud runner has no CFrame)
			local turned = {
				RightVector = Vector3.new(0, 0, -1),
				UpVector = Vector3.new(0, 1, 0),
				LookVector = Vector3.new(-1, 0, 0),
			} :: any
			local half = Logic.halfExtents(turned, Vector3.new(4, 1, 2))
			expect(math.abs(half.X - 1) < 1e-6).to.equal(true)
			expect(math.abs(half.Y - 0.5) < 1e-6).to.equal(true)
			expect(math.abs(half.Z - 2) < 1e-6).to.equal(true)
		end)
	end)
end
