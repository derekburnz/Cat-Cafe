--!strict
-- The front lawn (F91, front-lawn.md): the catalog of section 2, the six spots of section 1b, buying and placing
-- (section 5's BuyLawn, SetLawnSpot and SetLawnStyle rules), the tier gifts and save version 28. QA checks 2 and 4
-- (the tier half; the coins half is LawnService's trySpend) of section 6 are here; 1, 3, 5 and 6 are Studio rows.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Lawn = require(Shared.Lawn)
	local ProfileSchema = require(Shared.ProfileSchema)

	local T = 1000

	local function profileAt(tier: number): any
		local profile = ProfileSchema.template(T)
		profile.tier = tier
		return profile
	end

	local function count(map: { [string]: any }): number
		local n = 0
		for _ in map do
			n += 1
		end
		return n
	end

	describe("the catalog (section 2)", function()
		it("sells the sixteen pieces at the section 2 sizes, tiers and prices", function()
			local expected = {
				{ "tulip_bed", "small", 1, 500 },
				{ "sandwich_board", "small", 1, 500 },
				{ "potted_cat_topiary", "small", 1, 1000 },
				{ "mailbox", "small", 1, 1000 },
				{ "lamp_post", "small", 2, 3000 },
				{ "bird_bath", "small", 2, 3000 },
				{ "garden_gnome_cat", "small", 2, 5000 },
				{ "bicycle_with_basket", "big", 2, 8000 },
				{ "garden_bench", "big", 2, 8000 },
				{ "umbrella_table", "big", 3, 25000 },
				{ "little_fountain", "big", 3, 40000 },
				{ "fairy_light_arch", "big", 4, 150000 },
				{ "flower_cart", "big", 4, 200000 },
				{ "balloon_bunch", "small", 4, 100000 },
				{ "cat_tree_sign", "big", 5, 1000000 },
				{ "golden_paw_statue", "big", 5, 3000000 },
			}
			expect(#Catalog.lawn).to.equal(#expected)
			for i, row in expected do
				local def = Catalog.lawn[i]
				expect(def.id).to.equal(row[1])
				expect(def.spot).to.equal(row[2])
				expect(def.tier).to.equal(row[3])
				expect(def.price).to.equal(row[4])
				expect(Catalog.getLawn(def.id)).to.equal(def)
			end
		end)

		it("sells four paths and four fences, Grey Slabs free", function()
			local expected = {
				{ "grey_slabs", "path", 1, 0 },
				{ "red_brick", "path", 1, 2000 },
				{ "stepping_stones", "path", 2, 10000 },
				{ "paw_print_path", "path", 3, 50000 },
				{ "white_picket", "fence", 1, 2000 },
				{ "low_hedge", "fence", 2, 10000 },
				{ "iron_railing", "fence", 3, 50000 },
				{ "flower_box_fence", "fence", 4, 200000 },
			}
			expect(#Catalog.lawnStyles).to.equal(#expected)
			for i, row in expected do
				local def = Catalog.lawnStyles[i]
				expect(def.id).to.equal(row[1])
				expect(def.kind).to.equal(row[2])
				expect(def.tier).to.equal(row[3])
				expect(def.price).to.equal(row[4])
				expect(Catalog.getLawnStyle(def.id)).to.equal(def)
			end
		end)

		it("names each model as Model-Agent's art does (style guide section 13)", function()
			for _, def in Catalog.lawn do
				expect(def.model).to.equal(
					"CatCafe_Lawn_" .. def.name:gsub(" ", ""):gsub("with", "With")
				)
			end
			for _, def in Catalog.lawnStyles do
				local kind = if def.kind == "path" then "Path_" else "Fence_"
				expect(def.model).to.equal("CatCafe_Lawn_" .. kind .. def.name:gsub(" ", ""))
			end
		end)

		it("keeps piece, style and decor ids apart, so lawnOwned holds both", function()
			for _, def in Catalog.lawn do
				expect(Catalog.getLawnStyle(def.id)).never.to.be.ok()
				expect(Catalog.getDecor(def.id)).never.to.be.ok()
			end
		end)
	end)

	describe("the spots (section 1b)", function()
		it(
			"opens two small spots by the path at Tier 1, two big at Tier 2, two small by the wall at Tier 3",
			function()
				local byTier: { [number]: { string } } = {}
				for _, spot in Lawn.SPOTS do
					byTier[spot.tier] = byTier[spot.tier] or {}
					table.insert(byTier[spot.tier], spot.size)
					expect(Lawn.getSpot(spot.id)).to.equal(spot)
					expect(spot.y).to.equal(-0.05) -- on the grass top
				end
				expect(#Lawn.SPOTS).to.equal(6)
				expect(byTier[1] :: any).to.deepEqual({ "small", "small" })
				expect(byTier[2] :: any).to.deepEqual({ "big", "big" })
				expect(byTier[3] :: any).to.deepEqual({ "small", "small" })
			end
		)

		it("stands at Model-Agent's numbers, a pair mirrored across the path", function()
			local at: { [string]: { number } } = {}
			for _, spot in Lawn.SPOTS do
				at[spot.id] = { spot.x, spot.z }
			end
			expect(at.small1 :: any).to.deepEqual({ -5, -18.3 })
			expect(at.small2 :: any).to.deepEqual({ 5, -18.3 })
			expect(at.big1 :: any).to.deepEqual({ -14, -17.8 })
			expect(at.big2 :: any).to.deepEqual({ 14, -17.8 })
			expect(at.small3 :: any).to.deepEqual({ -8.5, -17.3 })
			expect(at.small4 :: any).to.deepEqual({ 8.5, -17.3 })
		end)

		it("names each spot's plot attribute", function()
			expect(Lawn.spotAttribute("big1")).to.equal("Lawn_big1")
			expect(Lawn.PATH_ATTRIBUTE).to.equal("LawnPath")
			expect(Lawn.FENCE_ATTRIBUTE).to.equal("LawnFence")
		end)
	end)

	describe("buying (section 5, QA check 4)", function()
		it("refuses a piece above the cafe's tier and sells it once the tier is reached", function()
			expect(Lawn.buyBlocker(profileAt(1), "lamp_post")).to.equal(
				"The Lamp Post opens at Tier 2."
			)
			expect(Lawn.buyBlocker(profileAt(1), "paw_print_path")).to.equal(
				"The Paw Print Path opens at Tier 3."
			)
			expect(Lawn.buyBlocker(profileAt(2), "lamp_post")).never.to.be.ok()
			expect(Lawn.buyBlocker(profileAt(1), "tulip_bed")).never.to.be.ok()
			expect(Lawn.buyBlocker(profileAt(5), "golden_paw_statue")).never.to.be.ok()
		end)

		it("refuses what is owned already, Grey Slabs included, and anything unknown", function()
			local profile = profileAt(1)
			profile.lawnOwned.tulip_bed = true
			expect(Lawn.buyBlocker(profile, "tulip_bed")).to.equal(
				"You already have the Tulip Bed."
			)
			expect(Lawn.buyBlocker(profile, "grey_slabs")).to.equal(
				"You already have the Grey Slabs."
			)
			expect(Lawn.buyBlocker(profile, "fish_tank")).to.equal("That is not in the lawn shop.")
			expect(Lawn.owns(profile, "grey_slabs")).to.equal(true)
			expect(Lawn.owns(profile, "red_brick")).to.equal(false)
		end)
	end)

	describe("placing (section 5, QA check 2)", function()
		it("puts an owned piece on an open spot of its size", function()
			local profile = profileAt(1)
			profile.lawnOwned.tulip_bed = true
			expect(Lawn.placeBlocker(profile, "small1", "tulip_bed")).never.to.be.ok()
			Lawn.place(profile, "small1", "tulip_bed")
			expect(profile.lawn.small1).to.equal("tulip_bed")
			expect(Lawn.spotOf(profile, "tulip_bed")).to.equal("small1")
		end)

		it("will not put a big piece in a small spot or a small piece in a big one", function()
			local profile = profileAt(2)
			profile.lawnOwned.garden_bench = true
			profile.lawnOwned.tulip_bed = true
			expect(Lawn.placeBlocker(profile, "small1", "garden_bench")).to.equal(
				"The Garden Bench needs a big spot."
			)
			expect(Lawn.placeBlocker(profile, "big1", "tulip_bed")).to.equal(
				"The Tulip Bed needs a small spot."
			)
		end)

		it("moves a piece placed again, leaving the first spot empty", function()
			local profile = profileAt(3)
			profile.lawnOwned.mailbox = true
			Lawn.place(profile, "small1", "mailbox")
			Lawn.place(profile, "small4", "mailbox")
			expect(profile.lawn.small1).never.to.be.ok()
			expect(profile.lawn.small4).to.equal("mailbox")
		end)

		it("swaps out the piece on a full spot and keeps it owned", function()
			local profile = profileAt(1)
			profile.lawnOwned.mailbox = true
			profile.lawnOwned.tulip_bed = true
			Lawn.place(profile, "small1", "mailbox")
			expect(Lawn.placeBlocker(profile, "small1", "tulip_bed")).never.to.be.ok()
			Lawn.place(profile, "small1", "tulip_bed")
			expect(profile.lawn.small1).to.equal("tulip_bed")
			expect(Lawn.spotOf(profile, "mailbox")).never.to.be.ok()
			expect(profile.lawnOwned.mailbox).to.equal(true)
		end)

		it("clears a spot and keeps the piece", function()
			local profile = profileAt(1)
			profile.lawnOwned.mailbox = true
			Lawn.place(profile, "small2", "mailbox")
			expect(Lawn.placeBlocker(profile, "small2", nil)).never.to.be.ok()
			Lawn.place(profile, "small2", nil)
			expect(next(profile.lawn)).never.to.be.ok()
			expect(profile.lawnOwned.mailbox).to.equal(true)
		end)

		it("refuses a spot above the cafe's tier, a piece not owned and unknown ids", function()
			local profile = profileAt(1)
			profile.lawnOwned.tulip_bed = true
			expect(Lawn.placeBlocker(profile, "small3", "tulip_bed")).to.equal(
				"That spot opens at Tier 3."
			)
			expect(Lawn.placeBlocker(profile, "big1", nil)).to.equal("That spot opens at Tier 2.")
			expect(Lawn.placeBlocker(profile, "small1", "mailbox")).to.equal(
				"Buy the Mailbox first."
			)
			expect(Lawn.placeBlocker(profile, "small9", "tulip_bed")).to.equal(
				"That is not a lawn spot."
			)
			expect(Lawn.placeBlocker(profile, "small1", "red_brick")).to.equal(
				"That is not a lawn piece."
			)
		end)

		it("finds the first empty open spot of a size", function()
			local profile = profileAt(1)
			expect(Lawn.firstFreeSpot(profile, "small")).to.equal("small1")
			expect(Lawn.firstFreeSpot(profile, "big")).never.to.be.ok()
			profile.lawnOwned.mailbox = true
			Lawn.place(profile, "small1", "mailbox")
			expect(Lawn.firstFreeSpot(profile, "small")).to.equal("small2")
			profile.tier = 3
			profile.lawnOwned.tulip_bed = true
			Lawn.place(profile, "small2", "tulip_bed")
			expect(Lawn.firstFreeSpot(profile, "small")).to.equal("small3")
			expect(Lawn.firstFreeSpot(profile, "big")).to.equal("big1")
		end)
	end)

	describe("path and fence styles (section 5, QA check 3's rule half)", function()
		it("starts every cafe on Grey Slabs with no fence", function()
			local profile = profileAt(1)
			expect(profile.lawnStyles :: any).to.deepEqual({ path = "grey_slabs" })
		end)

		it("puts an owned style in use and refuses one not owned or of the other kind", function()
			local profile = profileAt(1)
			expect(Lawn.styleBlocker(profile, "fence", "white_picket")).to.equal(
				"Buy the White Picket first."
			)
			profile.lawnOwned.white_picket = true
			expect(Lawn.styleBlocker(profile, "fence", "white_picket")).never.to.be.ok()
			expect(Lawn.styleBlocker(profile, "path", "white_picket")).to.equal(
				"That is not a path."
			)
			expect(Lawn.styleBlocker(profile, "fence", "grey_slabs")).to.equal(
				"That is not a fence."
			)
			Lawn.setStyle(profile, "fence", "white_picket")
			expect(profile.lawnStyles.fence).to.equal("white_picket")
		end)

		it("takes the fence down and lays Grey Slabs again with no id", function()
			local profile = profileAt(1)
			profile.lawnOwned.red_brick = true
			profile.lawnOwned.white_picket = true
			Lawn.setStyle(profile, "path", "red_brick")
			Lawn.setStyle(profile, "fence", "white_picket")
			expect(Lawn.styleBlocker(profile, "path", nil)).never.to.be.ok()
			Lawn.setStyle(profile, "path", nil)
			Lawn.setStyle(profile, "fence", nil)
			expect(profile.lawnStyles :: any).to.deepEqual({ path = "grey_slabs" })
		end)
	end)

	describe("the tier gifts (section 1b)", function()
		it("gives nothing at Tier 1", function()
			local profile = profileAt(1)
			expect(#Lawn.grantTierGifts(profile)).to.equal(0)
			expect(next(profile.lawnOwned)).never.to.be.ok()
		end)

		it("gives a Garden Bench at Tier 2, placed in the first big spot", function()
			local profile = profileAt(2)
			expect(Lawn.grantTierGifts(profile) :: any).to.deepEqual({ "garden_bench" })
			expect(profile.lawnOwned.garden_bench).to.equal(true)
			expect(profile.lawn.big1).to.equal("garden_bench")
		end)

		it("gives both to a cafe already at Tier 3, once", function()
			local profile = profileAt(3)
			expect(Lawn.grantTierGifts(profile) :: any).to.deepEqual({
				"garden_bench",
				"umbrella_table",
			})
			expect(profile.lawn.big1).to.equal("garden_bench")
			expect(profile.lawn.big2).to.equal("umbrella_table")
			expect(#Lawn.grantTierGifts(profile)).to.equal(0)
		end)

		it(
			"keeps a gift owned but off the lawn when both big spots are full, and never puts a moved one back",
			function()
				local profile = profileAt(3)
				profile.lawnOwned.flower_cart = true
				profile.lawnOwned.little_fountain = true
				Lawn.place(profile, "big1", "flower_cart")
				Lawn.place(profile, "big2", "little_fountain")
				Lawn.grantTierGifts(profile)
				expect(profile.lawnOwned.garden_bench).to.equal(true)
				expect(profile.lawnOwned.umbrella_table).to.equal(true)
				expect(Lawn.spotOf(profile, "garden_bench")).never.to.be.ok()
				Lawn.place(profile, "big1", nil)
				Lawn.grantTierGifts(profile)
				expect(profile.lawn.big1).never.to.be.ok()
			end
		)
	end)

	describe("save version 28", function()
		it("gives a new save an empty lawn", function()
			local profile = ProfileSchema.template(T)
			expect(next(profile.lawnOwned)).never.to.be.ok()
			expect(next(profile.lawn)).never.to.be.ok()
			expect(profile.lawnStyles.path).to.equal("grey_slabs")
			expect(profile.lawnStyles.fence).never.to.be.ok()
		end)

		it("starts a version 27 save with an empty lawn, Grey Slabs and no fence", function()
			local raw = ProfileSchema.template(T) :: any
			raw.version = 27
			raw.tier = 3
			raw.lawnOwned = nil
			raw.lawn = nil
			raw.lawnStyles = nil
			local profile = ProfileSchema.migrate(raw, T)
			expect(profile.version).to.equal(28)
			expect(next(profile.lawnOwned)).never.to.be.ok()
			expect(next(profile.lawn)).never.to.be.ok()
			expect(profile.lawnStyles :: any).to.deepEqual({ path = "grey_slabs" })
		end)

		it("keeps a valid lawn through a save and load", function()
			local raw = ProfileSchema.template(T) :: any
			raw.tier = 4
			raw.lawnOwned =
				{ tulip_bed = true, flower_cart = true, red_brick = true, iron_railing = true }
			raw.lawn = { small1 = "tulip_bed", big2 = "flower_cart" }
			raw.lawnStyles = { path = "red_brick", fence = "iron_railing" }
			local profile = ProfileSchema.migrate(raw, T)
			expect(count(profile.lawnOwned)).to.equal(4)
			expect(profile.lawn :: any).to.deepEqual({ small1 = "tulip_bed", big2 = "flower_cart" })
			expect(profile.lawnStyles :: any).to.deepEqual({
				path = "red_brick",
				fence = "iron_railing",
			})
		end)

		it(
			"drops unknown ids, pieces not owned, the wrong size, closed spots and a second spot",
			function()
				local raw = ProfileSchema.template(T) :: any
				raw.tier = 2
				raw.lawnOwned = {
					tulip_bed = true,
					garden_bench = true,
					mailbox = true,
					rocket = true,
					rug = true,
				}
				raw.lawn = {
					small1 = "tulip_bed",
					small2 = "tulip_bed", -- a second spot
					big1 = "mailbox", -- the wrong size
					big2 = "flower_cart", -- not owned
					small3 = "mailbox", -- opens at Tier 3
					nowhere = "garden_bench",
				}
				raw.lawnStyles = { path = "paw_print_path", fence = "grey_slabs" }
				local profile = ProfileSchema.migrate(raw, T)
				expect(profile.lawnOwned :: any).to.deepEqual({
					tulip_bed = true,
					garden_bench = true,
					mailbox = true,
				})
				expect(profile.lawn :: any).to.deepEqual({ small1 = "tulip_bed" })
				expect(profile.lawnStyles :: any).to.deepEqual({ path = "grey_slabs" })
			end
		)

		it("survives a damaged lawn", function()
			local raw = ProfileSchema.template(T) :: any
			raw.lawnOwned = "yes"
			raw.lawn = 7
			raw.lawnStyles = { path = 3, fence = true }
			local profile = ProfileSchema.migrate(raw, T)
			expect(next(profile.lawnOwned)).never.to.be.ok()
			expect(next(profile.lawn)).never.to.be.ok()
			expect(profile.lawnStyles :: any).to.deepEqual({ path = "grey_slabs" })
		end)
	end)
end
