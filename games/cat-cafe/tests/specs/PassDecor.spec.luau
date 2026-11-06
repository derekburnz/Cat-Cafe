--!strict
-- PassDecor.luau and the Garden Decor Pack's catalog rows (#1168 row 3): six looks-only pass decor pieces, owned
-- while the player owns the pass, never for sale or trade.
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
		it("holds six looks-only pass pieces that can't be bought or traded", function()
			local profile = ProfileSchema.template(1000)
			local pieces = garden()
			expect(#pieces).to.equal(6)
			for _, def in pieces do
				expect(def.source).to.equal("pass")
				expect(def.pack).to.equal("Garden Decor Pack")
				expect(def.bonus).to.equal(0)
				expect(def.asset:match("^CatCafe_Decor_")).to.be.ok()
				expect(Crates.takesSpot(def)).to.equal(true)
				expect(Economy.decorBlocker(profile, def.id)).to.equal(
					"Comes with the Garden Decor Pack, not for sale"
				)
				expect(Trade.piece(def.id)).never.to.be.ok()
			end
		end)

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
