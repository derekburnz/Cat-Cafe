--!strict
-- PassDecor.luau and the Garden Decor Pack's catalog rows (#1168 row 3): six pass decor pieces, owned while the
-- player owns the pass, never for sale or trade. #2006: every pass piece has a rarity (Common to Epic) and the crate
-- pieces' money bonus for it.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local Economy = require(Shared.Economy)
	local PassDecor = require(Shared.PassDecor)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Trade = require(Shared.Trade)

	local function garden(): { any }
		local out = {}
		for _, def in Catalog.passDecor do
			if def.passKey == "GardenDecorPackPassId" then
				table.insert(out, def)
			end
		end
		return out
	end

	describe("the Garden Decor Pack", function()
		it(
			"holds six pass pieces, three Rare and three Epic, that can't be bought or traded",
			function()
				local profile = ProfileSchema.template(1000)
				local pieces = garden()
				expect(#pieces).to.equal(6)
				for _, def in pieces do
					expect(def.source).to.equal("pass")
					expect(def.pack).to.equal("Garden Decor Pack")
					expect(def.rarity == "Rare" or def.rarity == "Epic").to.equal(true)
					expect(def.bonus).to.equal(Config.CratePieceBonus[def.rarity :: string])
					expect(def.asset:match("^CatCafe_Decor_")).to.be.ok()
					expect(Crates.takesSpot(def)).to.equal(true)
					expect(Economy.decorBlocker(profile, def.id)).to.equal(
						"Comes with the Garden Decor Pack, not for sale"
					)
					expect(Trade.piece(def.id)).never.to.be.ok()
				end
			end
		)

		it(
			"gives nothing while the pass id is 0 or not owned, and each piece once when owned",
			function()
				local profile = ProfileSchema.template(1000)
				expect(#PassDecor.toGrant(profile, function(id: number): boolean
					return id == 0
				end)).to.equal(0)
				expect(#PassDecor.toGrant(profile, function(): boolean
					return false
				end)).to.equal(0)
				local packId = (Config :: any).GardenDecorPackPassId
				if packId ~= 0 then
					local owns = function(id: number): boolean
						return id == packId
					end
					local ids = PassDecor.toGrant(profile, owns)
					expect(#ids).to.equal(6)
					for _, id in ids do
						profile.decorOwned[id] = true
					end
					expect(#PassDecor.toGrant(profile, owns)).to.equal(0)
				end
			end
		)

		it(
			"gives every pass piece a rarity up to Epic (the outfit packs Legendary), its bonus and no crate or Index place (#2006)",
			function()
				local inPool: { [string]: boolean } = {}
				for _, crate in Catalog.crates do
					for _, id in crate.pieces do
						inPool[id] = true
					end
				end
				local count =
					{ Common = 0, Rare = 0, Epic = 0, Legendary = 0 } :: { [string]: number }
				for _, def in Catalog.passDecor do
					local rarity = def.rarity :: string
					expect(count[rarity]).to.be.ok()
					-- #2486: a Cafe Event's piece stands with them but is no pass piece
					if def.source == "pass" then
						count[rarity] += 1
					end
					-- #4026: the outfit packs' pieces are Legendary at +25%
					expect(def.bonus).to.equal(
						if def.passKey ~= nil
								and string.match(def.id, "^decor_pack_") ~= nil
							then 0.25
							else Config.CratePieceBonus[rarity]
					)
					expect(def.bonus > 0).to.equal(true)
					expect(def.effect).to.equal(
						string.format("+%d%% money while in use", math.floor(def.bonus * 100 + 0.5))
					)
					expect(def.crate).to.equal(nil)
					expect(inPool[def.id]).to.equal(nil)
					expect(Trade.piece(def.id)).never.to.be.ok()
				end
				expect(count.Common).to.equal(3)
				expect(count.Rare).to.equal(6)
				expect(count.Epic).to.equal(6)
				expect(count.Legendary).to.equal(4) -- #4026: one per outfit pack
				expect((Catalog.getDecor("decor_royal_velvet_booth") :: any).rarity).to.equal(
					"Epic"
				)
			end
		)

		it("leaves the Cafe Pass and King Cat Pack pieces to their own grants", function()
			for _, def in Catalog.passDecor do
				if def.passKey == nil then
					expect(PassDecor.passId(def)).to.equal(0)
				end
			end
			expect((Catalog.getDecor("decor_royal_velvet_booth") :: any).passKey).to.equal(nil)
		end)
	end)
end
