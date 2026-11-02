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
		-- prices: section 2's, times 4 at Tier 3, 8 at Tier 4 and 16 at Tier 5 (economy-ladder.md section 4, which wins)
		it("sells the sixteen pieces at their sizes, tiers and ladder prices", function()
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
				{ "umbrella_table", "big", 3, 100000 },
				{ "little_fountain", "big", 3, 160000 },
				{ "fairy_light_arch", "big", 4, 1200000 },
				{ "flower_cart", "big", 4, 1600000 },
				{ "balloon_bunch", "small", 4, 800000 },
				{ "cat_tree_sign", "big", 5, 16000000 },
				{ "golden_paw_statue", "big", 5, 50000000 },
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
				{ "paw_print_path", "path", 3, 200000 },
				{ "white_picket", "fence", 1, 2000 },
				{ "low_hedge", "fence", 2, 10000 },
				{ "iron_railing", "fence", 3, 200000 },
				{ "flower_box_fence", "fence", 4, 1600000 },
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

	-- QA edges (front-lawn.md sections 5 and 6): what a forged or repeated call can do to a lawn. The remotes reach a
	-- piece or a spot only through Guard.id, and every move LawnService allows goes through the blockers here, so a
	-- lawn built by any run of allowed moves must be one a reload (ProfileSchema.migrate's Lawn.sanitize) keeps as it
	-- is: nothing a player paid for vanishes on rejoin, and a piece never stands on two spots.
	describe("Lawn edges (QA)", function()
		local ServerScriptService = game:GetService("ServerScriptService")
		local Guard = require(ServerScriptService.Server.Util.Guard)
		local Types = require(Shared.Types)

		local pieceIds: { string } = {}
		for _, piece in Catalog.lawn do
			table.insert(pieceIds, piece.id)
		end
		local styleIds: { string } = {}
		for _, style in Catalog.lawnStyles do
			table.insert(styleIds, style.id)
		end
		local spotIds: { string } = {}
		for _, spot in Lawn.SPOTS do
			table.insert(spotIds, spot.id)
		end

		local function fail(pattern: string, ...: any)
			error(string.format(pattern, ...), 2)
		end

		local function snapshot(profile: any): string
			local parts: { string } = {}
			for _, id in pieceIds do
				table.insert(parts, if profile.lawnOwned[id] then id else "-")
			end
			for _, id in styleIds do
				table.insert(parts, if profile.lawnOwned[id] then id else "-")
			end
			for _, id in spotIds do
				table.insert(parts, tostring(profile.lawn[id]))
			end
			table.insert(parts, tostring(profile.lawnStyles.path))
			table.insert(parts, tostring(profile.lawnStyles.fence))
			return table.concat(parts, " ")
		end

		-- Fails unless the lawn is valid at the profile's tier and a reload keeps it as it is.
		local function checkLawn(profile: any, label: string)
			local tier = profile.tier
			local seen: { [string]: string } = {}
			for spotId, pieceId in profile.lawn do
				local spot = Lawn.getSpot(spotId)
				local piece = Catalog.getLawn(pieceId)
				if spot == nil or piece == nil then
					fail("%s: %s holds %s", label, tostring(spotId), tostring(pieceId))
					return
				end
				if seen[pieceId] ~= nil then
					fail("%s: %s stands on %s and %s", label, pieceId, seen[pieceId], spotId)
				end
				seen[pieceId] = spotId
				if not Lawn.owns(profile, pieceId) then
					fail("%s: %s on %s is not owned", label, pieceId, spotId)
				end
				if piece.spot ~= spot.size then
					fail("%s: %s (%s) on %s (%s)", label, pieceId, piece.spot, spotId, spot.size)
				end
				if spot.tier > tier then
					fail("%s: %s holds %s at Tier %d", label, spotId, pieceId, tier)
				end
			end
			local path = Catalog.getLawnStyle(profile.lawnStyles.path)
			if path == nil or path.kind ~= "path" or not Lawn.owns(profile, path.id) then
				fail("%s: the path is %s", label, tostring(profile.lawnStyles.path))
			end
			local fenceId = profile.lawnStyles.fence
			if fenceId ~= nil then
				local fence = Catalog.getLawnStyle(fenceId)
				if fence == nil or fence.kind ~= "fence" or not Lawn.owns(profile, fenceId) then
					fail("%s: the fence is %s", label, tostring(fenceId))
				end
			end
			local owned, placed, styles =
				Lawn.sanitize(profile.lawnOwned, profile.lawn, profile.lawnStyles, tier)
			local reloaded = { lawnOwned = owned, lawn = placed, lawnStyles = styles }
			if snapshot(reloaded) ~= snapshot(profile) then
				fail("%s: a reload changes %s to %s", label, snapshot(profile), snapshot(reloaded))
			end
		end

		it(
			"lets every lawn piece, style and spot id through Guard.id, so a client can name it",
			function()
				for _, list in { pieceIds, styleIds, spotIds } do
					for _, id in list do
						if Guard.id(id) ~= id then
							fail("Guard.id drops %q, so no remote can reach it", id)
						end
					end
				end
			end
		)

		it("sells each piece and style from its own tier up and never twice", function()
			for tier = 1, Catalog.maxTier do
				for _, list in { pieceIds, styleIds } do
					for _, id in list do
						local row: any = Catalog.getLawn(id) or Catalog.getLawnStyle(id)
						local profile = profileAt(tier)
						local blocker = Lawn.buyBlocker(profile, id)
						local free = row.price == 0
						if (blocker == nil) ~= (row.tier <= tier and not free) then
							fail("%s at Tier %d: %s", id, tier, tostring(blocker))
						end
						if blocker == nil then
							profile.lawnOwned[id] = true
							if Lawn.buyBlocker(profile, id) == nil then
								fail("%s sells twice at Tier %d", id, tier)
							end
						end
					end
				end
			end
		end)

		-- A seeded run of LawnService's moves, the tier rising as rank ups do (with their gifts) and a save and load
		-- now and then: every move a blocker refuses changes nothing, and after each move the lawn is valid and a
		-- reload keeps it.
		it(
			"keeps any run of allowed moves valid through a reload, refused moves changing nothing",
			function()
				local random = Random.new(91)
				local moves = 0
				for run = 1, 40 do
					local profile = profileAt(1)
					for step = 1, 150 do
						local label = string.format("run %d step %d", run, step)
						local before = snapshot(profile)
						local roll = random:NextInteger(1, 20)
						if roll == 1 and profile.tier < Catalog.maxTier then
							profile.tier += 1
							Lawn.grantTierGifts(profile)
						elseif roll <= 7 then
							-- BuyLawn(id, spotId?) as LawnService does it
							local all = if random:NextNumber() < 0.7 then pieceIds else styleIds
							local id = all[random:NextInteger(1, #all)]
							local spotId: string? = if random:NextNumber() < 0.5
								then spotIds[random:NextInteger(1, #spotIds)]
								else nil
							if Lawn.buyBlocker(profile, id) ~= nil then
								if snapshot(profile) ~= before then
									fail("%s: a refused buy of %s changed the lawn", label, id)
								end
							else
								profile.lawnOwned[id] = true
								local piece, style = Catalog.getLawn(id), Catalog.getLawnStyle(id)
								if style ~= nil then
									Lawn.setStyle(profile, style.kind, id)
								elseif piece ~= nil then
									local target: string? = Lawn.firstFreeSpot(profile, piece.spot)
									if
										spotId ~= nil
										and Lawn.placeBlocker(profile, spotId, id) == nil
									then
										target = spotId
									end
									if target ~= nil then
										Lawn.place(profile, target, id)
									end
								end
								moves += 1
							end
						elseif roll <= 15 then
							-- SetLawnSpot(spotId, pieceId?)
							local spotId = spotIds[random:NextInteger(1, #spotIds)]
							local pieceId: string? = if random:NextNumber() < 0.85
								then pieceIds[random:NextInteger(1, #pieceIds)]
								else nil
							if Lawn.placeBlocker(profile, spotId, pieceId) ~= nil then
								if snapshot(profile) ~= before then
									fail("%s: a refused move changed the lawn", label)
								end
							else
								Lawn.place(profile, spotId, pieceId)
								moves += 1
							end
						elseif roll <= 19 then
							-- SetLawnStyle(kind, id or "")
							local kind: Types.LawnStyleKind = if random:NextNumber() < 0.5
								then "path"
								else "fence"
							local id: string? = if random:NextNumber() < 0.8
								then styleIds[random:NextInteger(1, #styleIds)]
								else nil
							if Lawn.styleBlocker(profile, kind, id) ~= nil then
								if snapshot(profile) ~= before then
									fail("%s: a refused style changed the lawn", label)
								end
							else
								Lawn.setStyle(profile, kind, id)
								moves += 1
							end
						else
							-- a save and load
							local raw = ProfileSchema.template(T) :: any
							raw.tier = profile.tier
							raw.lawnOwned = table.clone(profile.lawnOwned)
							raw.lawn = table.clone(profile.lawn)
							raw.lawnStyles = table.clone(profile.lawnStyles)
							local loaded = ProfileSchema.migrate(raw, T)
							if snapshot(loaded) ~= snapshot(profile) then
								fail(
									"%s: a save and load changed %s to %s",
									label,
									before,
									snapshot(loaded)
								)
							end
							Lawn.grantTierGifts(loaded) -- as CafeService's load does
							if snapshot(loaded) ~= before then
								fail(
									"%s: the load's gifts changed %s to %s",
									label,
									before,
									snapshot(loaded)
								)
							end
						end
						checkLawn(profile, label)
					end
				end
				-- enough allowed moves that the run means something
				expect(moves > 1500).to.equal(true)
			end
		)

		-- A damaged or hand-edited save (DataStore junk, an older or newer server's fields) never errors, and what it
		-- loads to is a valid lawn that the next load keeps as it is.
		it("loads any junk to a valid lawn the next load keeps", function()
			local random = Random.new(902)
			local names: { any } = {
				"tulip_bed",
				"garden_bench",
				"golden_paw_statue",
				"red_brick",
				"white_picket",
				"grey_slabs",
				"small1",
				"big2",
				"path",
				"fence",
				"TULIP_BED",
				"rug",
				"",
				string.rep("a", 300),
			}
			local function junk(depth: number): any
				local roll = random:NextInteger(1, 10)
				if roll == 1 then
					return nil
				elseif roll == 2 then
					return random:NextNumber() < 0.5
				elseif roll == 3 then
					return ({ 0, -1, 0 / 0, math.huge, 1e308, 2.5 })[random:NextInteger(1, 6)]
				elseif roll <= 7 or depth >= 2 then
					return names[random:NextInteger(1, #names)]
				end
				local map: { [any]: any } = {}
				for _ = 1, random:NextInteger(0, 6) do
					local key = if random:NextNumber() < 0.8
						then names[random:NextInteger(1, #names)]
						else random:NextInteger(1, 3)
					if key ~= nil then
						map[key] = junk(depth + 1)
					end
				end
				return map
			end
			-- a save that is nearly right: real ids, but pieces not owned, the wrong size, on closed spots or twice
			local all = table.clone(pieceIds)
			table.move(styleIds, 1, #styleIds, #all + 1, all)
			local function nearlyRight(): (any, any, any)
				local owned: { [any]: any } = {}
				for _, id in all do
					local roll = random:NextNumber()
					owned[id] = if roll < 0.5 then true elseif roll < 0.6 then junk(1) else nil
				end
				local placed: { [any]: any } = {}
				for _, spotId in spotIds do
					if random:NextNumber() < 0.8 then
						placed[spotId] = pieceIds[random:NextInteger(1, #pieceIds)]
					end
				end
				local styles = {
					path = all[random:NextInteger(1, #all)],
					fence = if random:NextNumber() < 0.8
						then all[random:NextInteger(1, #all)]
						else nil,
				}
				return owned, placed, styles
			end
			for round = 1, 3000 do
				local label = string.format("round %d", round)
				local tier = random:NextInteger(1, Catalog.maxTier)
				local rawOwned, rawLawn, rawStyles = junk(0), junk(0), junk(0)
				if round % 2 == 0 then
					rawOwned, rawLawn, rawStyles = nearlyRight()
				end
				local owned, placed, styles = Lawn.sanitize(rawOwned, rawLawn, rawStyles, tier)
				-- only a saved `true` owns anything: junk never hands out a piece for free
				for id in owned do
					if type(rawOwned) ~= "table" or rawOwned[id] ~= true then
						fail(
							"%s: %s owned from a saved %s",
							label,
							id,
							tostring(if type(rawOwned) == "table" then rawOwned[id] else rawOwned)
						)
					end
				end
				local profile =
					{ tier = tier, lawnOwned = owned, lawn = placed, lawnStyles = styles }
				checkLawn(profile, label)
			end
		end)
	end)
end
