--!strict
-- ShopCats.luau and the pass cats' catalog rows (#1447, store-skus.md): Duchess Marzipan on the Royal Cat pass and
-- King Croissant on the King Cat Pack are exclusive shop cats that always earn like a Legendary and a Mythical of the
-- owner's newest area, and a player who owns a pass is given its cat when it is not home.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ShopCats = require(Shared.ShopCats)

	local ROWS = {
		{ catId = "duchess_marzipan", rarity = "Legendary", passId = Config.RoyalCatPassId },
		{ catId = "king_croissant", rarity = "Mythical", passId = Config.KingPackPassId },
		-- #1822: the King Cat alone, the same cat on a pass of its own (0 until made)
		{ catId = "king_croissant", rarity = "Mythical", passId = (Config :: any).KingCatPassId },
	}

	-- The native cat of `rarity` in the area that opens at `tier`, the newest one at that tier.
	local function newestNative(rarity: string, tier: number): any
		local areaId: string? = nil
		for _, area in Catalog.areas do
			if area.tier == tier then
				areaId = area.id
			end
		end
		for _, def in Catalog.cats do
			if def.area == areaId and def.rarity == rarity then
				return def
			end
		end
		return nil
	end

	describe("the catalog rows", function()
		it("are shop-only exclusive cats of their rarity, on their own pass", function()
			for index, row in ROWS do
				local def = Catalog.getCat(row.catId) :: any
				expect(def).to.be.ok()
				expect(def.rarity).to.equal(row.rarity)
				expect(def.exclusive).to.equal(true)
				expect(def.source).to.equal("shop")
				expect(def.area).to.equal("exclusive")
				expect(ShopCats.LIST[index].catId).to.equal(row.catId)
				expect(ShopCats.passId(ShopCats.LIST[index])).to.equal(row.passId)
			end
			expect(#ShopCats.LIST).to.equal(#ROWS)
		end)

		it(
			"earn like their rarity from the newest area at every tier, rising as each area opens",
			function()
				local last = 0
				for tier = 1, #Catalog.tiers do
					for _, row in ROWS do
						local def = Catalog.getCat(row.catId) :: any
						local native = newestNative(row.rarity, tier)
						expect(native).to.be.ok()
						local shop =
							CatStats.newInstance("s", row.catId, 100, CatStats.DEFAULT_CHARM)
						local wild =
							CatStats.newInstance("w", native.id, 100, CatStats.DEFAULT_CHARM)
						expect(CatStats.rating(shop, tier)).to.be.near(
							CatStats.rating(wild, tier),
							1e-9
						)
						expect(def.incomePerSecond * CatStats.areaMultiplier(def, tier)).to.be.near(
							native.incomePerSecond,
							1e-9
						)
					end
					local king =
						CatStats.rating(CatStats.newInstance("k", "king_croissant", 100, 50), tier)
					expect(king > last).to.equal(true)
					last = king
				end
			end
		)

		it("count toward no different cats", function()
			local profile = ProfileSchema.template(1000)
			local before = Economy.distinctCats(profile)
			profile.collection.duchess_marzipan = 1000
			profile.collection.king_croissant = 1000
			expect(Economy.distinctCats(profile)).to.equal(before)
		end)
	end)

	describe("who is given a cat", function()
		local function owns(set: { [number]: boolean }): (number) -> boolean
			return function(id: number): boolean
				return set[id] == true
			end
		end

		it("lists both made passes for PassService to look up", function()
			local ids = ShopCats.passIds()
			-- #1822: the King Cat alone joins the list once its pass is made
			expect(#ids).to.equal(if (Config :: any).KingCatPassId == 0 then 2 else 3)
			expect(ids[1]).to.equal(Config.RoyalCatPassId)
			expect(ids[2]).to.equal(Config.KingPackPassId)
		end)

		it("gives each owned pass's cat once, and again only if it is gone", function()
			local profile = ProfileSchema.template(1000)
			expect(#ShopCats.toGive(profile, owns({}))).to.equal(0)
			local both = owns({ [Config.RoyalCatPassId] = true, [Config.KingPackPassId] = true })
			expect(ShopCats.toGive(profile, both) :: any).to.deepEqual({
				"duchess_marzipan",
				"king_croissant",
			})
			expect(ShopCats.toGive(profile, owns({ [Config.KingPackPassId] = true })) :: any).to.deepEqual({
				"king_croissant",
			})
			profile.cats.d = CatStats.newInstance("d", "duchess_marzipan", 1000, 50)
			expect(ShopCats.has(profile, "duchess_marzipan")).to.equal(true)
			expect(ShopCats.toGive(profile, both) :: any).to.deepEqual({ "king_croissant" })
			profile.cats.k = CatStats.newInstance("k", "king_croissant", 1000, 50)
			expect(#ShopCats.toGive(profile, both)).to.equal(0)
			profile.cats.d = nil
			expect(ShopCats.toGive(profile, both) :: any).to.deepEqual({ "duchess_marzipan" })
		end)

		it("gives the King Cat once when both the pack and the King Cat alone are owned", function()
			local profile = ProfileSchema.template(1000)
			local all = function(id: number): boolean
				return id ~= 0 and id ~= Config.RoyalCatPassId
			end
			expect(ShopCats.toGive(profile, all) :: any).to.deepEqual({ "king_croissant" })
		end)

		it("never gives a cat for a pass id of 0", function()
			local profile = ProfileSchema.template(1000)
			expect(#ShopCats.toGive(profile, function(id: number): boolean
				return id == 0
			end)).to.equal(0)
		end)
	end)
end
