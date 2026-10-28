--!strict
-- The opened crate on the Market counter (F53): which model each crate shows and how its lid swings. Written by the
-- vfx-animator; QA moved it into tests/specs and added the edges.
return function()
	local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects crate on the counter", function()
		it("names each crate's model and its golden twin", function()
			expect(Logic.crateModelName("alley", false)).to.equal("CatCafe_Prop_Crate_Alley")
			expect(Logic.crateModelName("neighbourhood", false)).to.equal(
				"CatCafe_Prop_Crate_Neighbourhood"
			)
			expect(Logic.crateModelName("classic", true)).to.equal(
				"CatCafe_Prop_Crate_Classic_Gold"
			)
			expect(Logic.crateModelName("sewer", nil)).to.equal("CatCafe_Prop_Crate_Sewer")
			expect(Logic.crateModelName("", false) == nil).to.equal(true)
			expect(Logic.crateModelName(nil, true) == nil).to.equal(true)
		end)

		it("swings the lid open quickly and never past wide open", function()
			local c = Presets.marketCrate
			expect(Logic.lidAngle(0, c.lidSeconds, c.lidDegrees)).to.equal(0)
			expect(
				Logic.lidAngle(c.lidSeconds * 0.5, c.lidSeconds, c.lidDegrees) > c.lidDegrees * 0.5
			).to.equal(true)
			expect(Logic.lidAngle(c.lidSeconds, c.lidSeconds, c.lidDegrees)).to.equal(c.lidDegrees)
			expect(Logic.lidAngle(c.lidSeconds * 4, c.lidSeconds, c.lidDegrees)).to.equal(
				c.lidDegrees
			)
			expect(Logic.lidAngle(0, 0, c.lidDegrees)).to.equal(c.lidDegrees)
			expect(c.lidDegrees <= 105).to.equal(true) -- crates.py: wide open with no clipping
			expect(c.hold > c.lidSeconds).to.equal(true)
		end)
	end)

	describe("Effects crate on the counter edges (QA)", function()
		-- the twelve crate models in assets/cat-cafe/rbx (Model-Agent's crates.py, asset PR #524)
		local MODELS = {}
		for _, pool in { "Alley", "Park", "Neighbourhood", "Woods", "Sewer", "Classic" } do
			MODELS["CatCafe_Prop_Crate_" .. pool] = true
			MODELS["CatCafe_Prop_Crate_" .. pool .. "_Gold"] = true
		end

		it("names one of the twelve crate models for every crate in the Catalog, and each model once", function()
			local used: { [string]: string } = {}
			local count = 0
			for _, def in Catalog.crates do
				local name = Logic.crateModelName(def.area, def.golden)
				expect(name ~= nil and MODELS[name] == true).to.equal(true)
				expect(string.sub(name, -5) == "_Gold").to.equal(def.golden == true)
				expect(used[name] == nil).to.equal(true)
				used[name] = def.id
				count += 1
			end
			expect(count).to.equal(12)
		end)

		it("matches the effects list and only ever opens the lid further", function()
			local c = Presets.marketCrate
			expect(c.scale).to.equal(0.6)
			expect(c.lidDegrees).to.equal(105)
			expect(c.lidSeconds).to.equal(0.3)
			expect(c.hold).to.equal(1.8)
			expect(c.fade).to.equal(0.4)
			local last = Logic.lidAngle(-1, c.lidSeconds, c.lidDegrees)
			expect(last).to.equal(0)
			for step = 1, 60 do
				local angle = Logic.lidAngle(step * c.lidSeconds / 30, c.lidSeconds, c.lidDegrees)
				expect(angle >= last and angle <= c.lidDegrees).to.equal(true)
				last = angle
			end
			expect(last).to.equal(c.lidDegrees)
		end)
	end)
end
