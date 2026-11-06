--!strict
-- Looks.luau (#1624, store-pass-looks.md): which cafe themes and uniform styles a player owns (through a pass, or a
-- Cafe Pass season colour kept in pass.items), which one shows, SetLook's check, and saves made whole.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Looks = require(Shared.Looks)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function owns(set: { [number]: boolean }): (number) -> boolean
		return function(id: number): boolean
			return set[id] == true
		end
	end

	local none = owns({})
	local garden = owns({ [Config.CafeStylePassId] = true })
	local both = owns({ [Config.CafeStylePassId] = true, [Config.GrandThemePassId] = true })
	local uniforms = owns({ [Config.UniformStylesPassId] = true })

	describe("owned and shown", function()
		it("owns a theme only with its pass", function()
			expect(Looks.owned("theme", none, {}) :: any).to.deepEqual({})
			expect(Looks.owned("theme", garden, {}) :: any).to.deepEqual({ "garden" })
			expect(Looks.owned("theme", both, {}) :: any).to.deepEqual({ "garden", "grand" })
		end)

		it(
			"owns the three pass uniforms with Uniform Styles and a season colour through pass.items",
			function()
				expect(Looks.owned("uniform", none, {}) :: any).to.deepEqual({})
				expect(Looks.owned("uniform", uniforms, {}) :: any).to.deepEqual({
					"striped",
					"midnight",
					"mint",
				})
				expect(Looks.owned("uniform", none, { uniform_pumpkin = true }) :: any).to.deepEqual({
					"uniform_pumpkin",
				})
				-- a saved pass uniform id in items means nothing without the pass
				expect(Looks.owned("uniform", none, { striped = true }) :: any).to.deepEqual({})
			end
		)

		it("shows the pick only while it is owned", function()
			expect(Looks.shown("theme", "grand", both, {})).to.equal("grand")
			expect(Looks.shown("theme", "grand", garden, {})).to.equal(nil)
			expect(Looks.shown("theme", nil, both, {})).to.equal(nil)
			expect(Looks.shown("theme", "striped", uniforms, {})).to.equal(nil) -- a uniform id is not a theme
			expect(Looks.shown("uniform", "midnight", uniforms, {})).to.equal("midnight")
			expect(Looks.shown("uniform", "uniform_cranberry", none, { uniform_cranberry = true })).to.equal(
				"uniform_cranberry"
			)
		end)

		it("names the theme models and gives every uniform two colours", function()
			for _, theme in Looks.THEMES do
				expect(theme.front:match("^CatCafe_Plot_Theme")).to.be.ok()
				expect(theme.sign:match("^CatCafe_Plot_Sign")).to.be.ok()
				expect(Looks.passIdOf(theme.passKey) > 0).to.equal(true)
			end
			for _, uniform in Looks.UNIFORMS do
				expect(#uniform.main).to.equal(3)
				expect(#uniform.trim).to.equal(3)
			end
		end)
	end)

	describe("SetLook's check (pickFor)", function()
		it("refuses a look the player doesn't own", function()
			expect(Looks.pickFor("theme", "garden", none, {})).to.equal(false)
			expect(Looks.pickFor("theme", "grand", garden, {})).to.equal(false)
			expect(Looks.pickFor("uniform", "mint", none, {})).to.equal(false)
			expect(Looks.pickFor("uniform", "uniform_acorn_brown", uniforms, {})).to.equal(false)
		end)

		it("refuses an unknown kind or id, a look of the other kind, or a non-string", function()
			expect(Looks.pickFor("hat", "garden", both, {})).to.equal(false)
			expect(Looks.pickFor(nil, "garden", both, {})).to.equal(false)
			expect(Looks.pickFor("theme", "nope", both, {})).to.equal(false)
			expect(Looks.pickFor("theme", "striped", uniforms, {})).to.equal(false)
			expect(Looks.pickFor("uniform", 5, uniforms, {})).to.equal(false)
			expect(Looks.pickFor("uniform", {}, uniforms, {})).to.equal(false)
		end)

		it("takes an owned look, and the default for nil, empty or default", function()
			local ok, pick = Looks.pickFor("theme", "grand", both, {})
			expect(ok).to.equal(true)
			expect(pick).to.equal("grand")
			ok, pick = Looks.pickFor(
				"uniform",
				"uniform_forest_green",
				none,
				{ uniform_forest_green = true }
			)
			expect(ok).to.equal(true)
			expect(pick).to.equal("uniform_forest_green")
			for _, raw in { "", "default" } do
				ok, pick = Looks.pickFor("theme", raw, none, {})
				expect(ok).to.equal(true)
				expect(pick).to.equal(nil)
			end
			ok, pick = Looks.pickFor("uniform", nil, none, {})
			expect(ok).to.equal(true)
			expect(pick).to.equal(nil)
		end)
	end)

	describe("saves", function()
		it("keeps known picks and drops the rest", function()
			expect(Looks.sanitize(nil) :: any).to.deepEqual({})
			expect(Looks.sanitize("x") :: any).to.deepEqual({})
			expect(Looks.sanitize({ theme = "grand", uniform = "mint" }) :: any).to.deepEqual({
				theme = "grand",
				uniform = "mint",
			})
			expect(Looks.sanitize({ theme = "mint", uniform = 4 }) :: any).to.deepEqual({})
		end)

		it("migrates an older save to no picks and keeps a saved pick", function()
			local old = ProfileSchema.migrate({ version = 37 }, 0)
			expect(old.looks :: any).to.deepEqual({})
			local kept = ProfileSchema.migrate(
				{ version = 38, looks = { theme = "garden", uniform = "x" } },
				0
			)
			expect(kept.looks :: any).to.deepEqual({ theme = "garden" })
		end)
	end)
end
