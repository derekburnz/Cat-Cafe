--!strict
-- KingPack.luau (#1822): the King Cat Pack's contents, its worth line, the Grand look and Royal Crest through the
-- pack, the looks-only Royal Velvet Booth, and the one-time gift of the booth and Potion Pack M's potions.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local Economy = require(Shared.Economy)
	local KingPack = require(Shared.KingPack)
	local Looks = require(Shared.Looks)
	local Products = require(Shared.Products)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ShopCats = require(Shared.ShopCats)
	local SignStyles = require(Shared.SignStyles)
	local Trade = require(Shared.Trade)

	local function owns(set: { [number]: boolean }): (number) -> boolean
		return function(id: number): boolean
			return set[id] == true
		end
	end
	local pack = owns({ [Config.KingPackPassId] = true })

	describe("contents", function()
		it("lists the cat, sign, Grand look, booth and potion set, each a real thing", function()
			local kinds = {}
			for _, item in KingPack.contents() do
				table.insert(kinds, item.kind)
			end
			expect(kinds :: any).to.deepEqual({ "cat", "sign", "theme", "decor", "potions" })
			expect(Catalog.getCat(KingPack.CAT)).to.be.ok()
			expect(SignStyles.get(KingPack.SIGN)).to.be.ok()
			expect(Looks.theme(KingPack.THEME)).to.be.ok()
			expect(Catalog.getDecor(KingPack.DECOR)).to.be.ok()
			expect(Catalog.getProduct(KingPack.POTION_PRODUCT)).to.be.ok()
			expect(KingPack.contents()[3].name).to.equal("Grand look")
		end)

		it("gives the pack's cat, sign and Grand look through the pass", function()
			local profile = ProfileSchema.template(1000)
			expect(ShopCats.toGive(profile, pack) :: any).to.deepEqual({ KingPack.CAT })
			expect(table.find(SignStyles.owned({}, pack), KingPack.SIGN)).to.be.ok()
			expect(Looks.owned("theme", pack, {}) :: any).to.deepEqual({ "grand" })
			expect(Looks.owned("theme", owns({}), {}) :: any).to.deepEqual({})
			expect(Looks.owned("theme", owns({ [Config.GrandThemePassId] = true }), {}) :: any).to.deepEqual({
				"grand",
			})
			local ok, id = Looks.pickFor("theme", "grand", pack, {})
			expect(ok).to.equal(true)
			expect(id).to.equal("grand")
		end)

		it(
			"keeps the Grand look a look only: the Grand Cafe money stays on its own pass",
			function()
				-- PassService sets Economy's `grand` (money, rich visitors, job slot) from GrandThemePassId alone
				local grand = Looks.theme("grand") :: any
				expect(grand.passKey).to.equal("GrandThemePassId")
				expect(grand.alsoKey).to.equal(KingPack.PASS_KEY)
			end
		)
	end)

	describe("the Royal Velvet Booth", function()
		it("is Epic pass decor, +8% money in use, that comes with the pack", function()
			local profile = ProfileSchema.template(1000)
			local def = Catalog.getDecor(KingPack.DECOR) :: any
			expect(def.source).to.equal("pass")
			expect(def.pack).to.equal("Cat King Pack")
			expect(def.rarity).to.equal("Epic") -- #2006
			expect(def.bonus).to.equal(Config.CratePieceBonus.Epic)
			expect(def.asset).to.equal("CatCafe_Decor_VelvetBooth")
			expect(Crates.takesSpot(def)).to.equal(true)
			expect(table.find(Catalog.passDecor, def)).to.be.ok()
			expect(Economy.decorBlocker(profile, KingPack.DECOR)).to.equal(
				"Comes with the Cat King Pack, not for sale"
			)
			expect(Trade.piece(KingPack.DECOR)).never.to.be.ok()
		end)
	end)

	describe("the gift", function()
		it("gives the booth and Potion Pack M's potions once, only to a pack owner", function()
			local profile = ProfileSchema.template(1000)
			expect(KingPack.gift(profile, false)).to.equal(nil)
			expect(profile.decorOwned[KingPack.DECOR]).to.equal(nil)
			local potions = KingPack.gift(profile, true)
			expect(potions :: any).to.deepEqual({
				big_tip_potion = 5,
				swift_potion = 3,
				steady_potion = 2,
			})
			expect(profile.decorOwned[KingPack.DECOR]).to.equal(true)
			expect(profile.onceBought[KingPack.MARK]).to.equal(true)
			expect(KingPack.due(profile, true)).to.equal(false)
			expect(KingPack.gift(profile, true)).to.equal(nil)
		end)

		it("keeps the gift mark through a save", function()
			local kept = Products.sanitizeOnce({
				[KingPack.MARK] = true,
				junk = true,
				starter_bundle = true,
			})
			expect(kept :: any).to.deepEqual({ [KingPack.MARK] = true, starter_bundle = true })
		end)

		it("does not change the Catalog potion set it copies", function()
			local potions = KingPack.potions()
			potions.big_tip_potion = 99
			expect(
				(Catalog.getProduct(KingPack.POTION_PRODUCT) :: any).prize.potions.big_tip_potion
			).to.equal(5)
		end)
	end)
end
