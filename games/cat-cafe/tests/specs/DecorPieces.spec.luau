--!strict
-- UI/Components/DecorPieces.luau: crate pieces, style slots, decor spots and the Decor Index pages (F53).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local DecorPieces = require(Components:WaitForChild("DecorPieces")) :: any

	local function piece(id: string, pool: string, rarity: string, kind: string)
		return { id = id, name = id, bonus = 0.02, crate = pool, rarity = rarity, kind = kind }
	end

	local DECOR = {
		{ id = "plant", name = "Plant", category = "Plants", bonus = 0.05 }, -- coin decor
		piece("jukebox", "alley", "Legendary", "furniture"),
		piece("brick", "alley", "Common", "wallpaper"),
		piece("sky", "alley", "Mythical", "wallpaper"),
		piece("stools", "alley", "Common", "furniture"),
		piece("lights", "alley", "Rare", "decoration"),
		piece("oak", "classic", "Common", "floor"),
	}
	local CATALOG = {
		decor = DECOR,
		crates = {
			{ id = "alley_crate", area = "alley", golden = false, pieces = {} },
			{ id = "alley_golden_crate", area = "alley", golden = true, pieces = {} },
			{ id = "park_crate", area = "park", golden = false, pieces = {} },
		},
	}

	describe("DecorPieces.info and isStyle", function()
		it("reads a piece's pool, rarity and kind, and nothing from coin decor", function()
			local info = DecorPieces.info(DECOR[2])
			expect(info.pool).to.equal("alley")
			expect(info.rarity).to.equal("Legendary")
			expect(info.kind).to.equal("furniture")
			expect(DecorPieces.info(DECOR[1]).kind).to.equal(nil)
			expect(DecorPieces.isPiece(DECOR[1])).to.equal(false)
			expect(DecorPieces.isPiece(DECOR[2])).to.equal(true)
			expect(DecorPieces.info({ id = "odd", kind = "rug" }).kind).to.equal(nil)
		end)

		it("calls wallpaper, floor and paint style kinds", function()
			expect(DecorPieces.isStyle("wallpaper")).to.equal(true)
			expect(DecorPieces.isStyle("paint")).to.equal(true)
			expect(DecorPieces.isStyle("furniture")).to.equal(false)
			expect(DecorPieces.isStyle(nil)).to.equal(false)
			expect(DecorPieces.kindName("floor")).to.equal("Floor")
			expect(DecorPieces.kindName(nil)).to.equal("Cosmetic")
		end)
	end)

	describe("DecorPieces.spots and spotsUsed", function()
		it("counts the tier's spots plus the Extra Decor Spot levels", function()
			expect(DecorPieces.spots(1, nil)).to.equal(2)
			expect(DecorPieces.spots(5, nil)).to.equal(6)
			expect(DecorPieces.spots(9, nil)).to.equal(6)
			expect(DecorPieces.spots(3, { extra_decor_spot = 2 })).to.equal(6)
		end)

		it("counts placed furniture and decorations, not styles or coin decor", function()
			local placed =
				{ jukebox = true, lights = true, brick = true, plant = true, stools = false }
			expect(DecorPieces.spotsUsed(DECOR, placed)).to.equal(2)
			expect(DecorPieces.spotsUsed(DECOR, placed, { lights = "lights_gold" })).to.equal(1)
		end)

		it("finds the style piece in use", function()
			local inUse = DecorPieces.inUse(DECOR, { sky = true }, "wallpaper")
			expect(inUse and inUse.id).to.equal("sky")
			expect(DecorPieces.inUse(DECOR, { sky = true }, "floor")).to.equal(nil)
		end)
	end)

	describe("DecorPieces.all", function()
		it("joins Catalog.decor and Catalog.crateDecor, each piece once", function()
			local catalog = { decor = { DECOR[1], DECOR[2] }, crateDecor = { DECOR[2], DECOR[3] } }
			local all = DecorPieces.all(catalog)
			expect(#all).to.equal(3)
			expect(all[3].id).to.equal("brick")
			expect(#DecorPieces.all({ decor = DECOR })).to.equal(#DECOR)
		end)
	end)

	describe("DecorPieces pages", function()
		it("maps pools and Decor Index area ids", function()
			expect(DecorPieces.areaOf("alley")).to.equal("decor_alley")
			expect(DecorPieces.poolOf("decor_classic")).to.equal("classic")
			expect(DecorPieces.poolOf("alley")).to.equal(nil)
			expect(DecorPieces.poolOf("decor_")).to.equal(nil)
		end)

		it("lists the plain crates' pools, then pools only the pieces name", function()
			local pools = DecorPieces.pools(CATALOG)
			expect(#pools).to.equal(3)
			expect(pools[1]).to.equal("alley")
			expect(pools[2]).to.equal("park")
			expect(pools[3]).to.equal("classic")
		end)

		it("orders a page rarest last and counts what the player owns", function()
			local pieces = DecorPieces.poolPieces(CATALOG, "alley")
			expect(#pieces).to.equal(5)
			expect(pieces[1].id).to.equal("brick")
			expect(pieces[2].id).to.equal("stools")
			expect(pieces[5].id).to.equal("sky")
			local owned, total = DecorPieces.pageCounts(
				CATALOG,
				{ decorOwned = { brick = true, sky = true, oak = true } },
				"alley"
			)
			expect(owned).to.equal(2)
			expect(total).to.equal(5)
		end)

		it("uses the crate's own piece list when it has one", function()
			local catalog = {
				decor = DECOR,
				crates = {
					{
						id = "alley_crate",
						area = "alley",
						golden = false,
						pieces = { "sky", "brick" },
					},
				},
			}
			local pieces = DecorPieces.poolPieces(catalog, "alley")
			expect(#pieces).to.equal(2)
			expect(pieces[1].id).to.equal("brick")
		end)
	end)
end
