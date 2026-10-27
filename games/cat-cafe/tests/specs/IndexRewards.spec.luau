--!strict
-- UI/Components/IndexRewards.luau: the Index's per-area milestones (F48, data-model section 11b).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local IndexRewards = require(Components:WaitForChild("IndexRewards")) :: any

	local CATALOG = {
		cats = {
			{ id = "tabby", area = "alley" },
			{ id = "tuxedo", area = "alley" },
			{ id = "calico" }, -- no area: an Alleyway cat
			{ id = "siamese", area = "alley" },
			{ id = "corgi_cat", area = "park" },
		},
		indexMilestones = {
			{ id = "cats3", need = 3 },
			{ id = "cats6", need = 6 },
			{ id = "all4", need = 4 },
			{ id = "gold4", need = 4, gold = true },
		},
		indexPrizes = {
			alley = {
				cats3 = { coins = 300 },
				all4 = { lures = { salmon = 1 }, decorId = "index_alley" },
				gold4 = { decorId = "index_alley_gold" },
			},
			park = { cats3 = { coins = 1000 } },
		},
	}

	describe("IndexRewards.counts", function()
		it("counts the area's cats found and gold, with no area meaning the Alleyway", function()
			local state = {
				collection = { tabby = 1, calico = 2, corgi_cat = 3 },
				goldCollection = { tabby = 1 },
			}
			local counts = IndexRewards.counts(CATALOG, state, "alley")
			expect(counts.total).to.equal(4)
			expect(counts.found).to.equal(2)
			expect(counts.gold).to.equal(1)
			expect(IndexRewards.counts(CATALOG, state, "park").found).to.equal(1)
		end)
	end)

	describe("IndexRewards.views", function()
		it("skips milestones without a prize and keeps catalog order", function()
			local views = IndexRewards.views(CATALOG, {}, "alley")
			expect(#views).to.equal(3)
			expect(views[1].milestone.id).to.equal("cats3")
			expect(views[2].milestone.id).to.equal("all4")
			expect(views[3].milestone.id).to.equal("gold4")
		end)

		it("marks reached milestones ready, claimed ones claimed, and caps the count", function()
			local state = {
				collection = { tabby = 1, tuxedo = 1, calico = 1, siamese = 1 },
				goldCollection = { tabby = 1 },
				indexRewards = { alley = { cats3 = true } },
			}
			local views = IndexRewards.views(CATALOG, state, "alley")
			expect(views[1].state).to.equal("claimed")
			expect(views[2].state).to.equal("ready")
			expect(views[2].have).to.equal(4)
			expect(views[3].state).to.equal("locked")
			expect(views[3].have).to.equal(1)
		end)

		it("has no cards without milestones or prizes for the area", function()
			expect(#IndexRewards.views({ cats = CATALOG.cats }, {}, "alley")).to.equal(0)
			expect(#IndexRewards.views(CATALOG, {}, "woods")).to.equal(0)
		end)
	end)

	describe("IndexRewards.claimable", function()
		it("counts ready milestones per area and in all", function()
			local state = { collection = { tabby = 1, tuxedo = 1, calico = 1 } }
			local perArea, total = IndexRewards.claimable(CATALOG, state)
			expect(perArea.alley).to.equal(1)
			expect(perArea.park).to.equal(nil)
			expect(total).to.equal(1)
			local _, none = IndexRewards.claimable(CATALOG, { collection = {} })
			expect(none).to.equal(0)
		end)
	end)

	describe("IndexRewards Decor Index pages (F53)", function()
		local catalog = {
			cats = CATALOG.cats,
			decor = {
				{ id = "brick", crate = "alley", rarity = "Common", kind = "wallpaper" },
				{ id = "stools", crate = "alley", rarity = "Common", kind = "furniture" },
				{ id = "sky", crate = "alley", rarity = "Mythical", kind = "wallpaper" },
			},
			crates = { { id = "alley_crate", area = "alley", golden = false, pieces = {} } },
			indexMilestones = { { id = "decor5", needs = 2 }, { id = "decor10", needs = 3 } },
			indexPrizes = { decor_alley = { decor5 = { fish = 25 }, decor10 = { bonus = 0.05 } } },
		}

		it("counts a page's owned pieces and readies its rewards", function()
			local state = { decorOwned = { brick = true, sky = true }, indexRewards = {} }
			local counts = IndexRewards.counts(catalog, state, "decor_alley")
			expect(counts.total).to.equal(3)
			expect(counts.found).to.equal(2)
			local views = IndexRewards.views(catalog, state, "decor_alley")
			expect(views[1].state).to.equal("ready")
			expect(views[2].state).to.equal("locked")
			local perArea, total = IndexRewards.claimable(catalog, state)
			expect(perArea.decor_alley).to.equal(1)
			expect(total).to.equal(1)
		end)

		it("names a page's need in pieces", function()
			expect(IndexRewards.needLabel({ id = "decor5", needs = 5 }, 10, "decor_alley")).to.equal(
				"5 pieces"
			)
			expect(IndexRewards.needLabel({ id = "decor10", needs = 10 }, 10, "decor_alley")).to.equal(
				"All 10"
			)
		end)
	end)

	describe("IndexRewards labels", function()
		it("names the need, saying All once it is the whole page", function()
			expect(IndexRewards.needLabel({ id = "cats3", need = 3 }, 10)).to.equal("3 cats")
			expect(IndexRewards.needLabel({ id = "cats10", need = 10 }, 10)).to.equal("All 10")
			expect(IndexRewards.needLabel({ id = "gold10", need = 10, gold = true }, 10)).to.equal(
				"All 10 gold"
			)
			expect(IndexRewards.needLabel({ id = "gold10", need = 10, gold = true }, 12)).to.equal(
				"10 gold"
			)
		end)

		it("finds the milestone behind an Index decor piece and names it", function()
			local areaId, milestone = IndexRewards.decorSource(CATALOG, "index_alley_gold")
			expect(areaId).to.equal("alley")
			expect(milestone.id).to.equal("gold4")
			expect(IndexRewards.decorSource(CATALOG, "plants")).to.equal(nil)
			expect(IndexRewards.unlockLabel(milestone, "Alleyway", 4)).to.equal(
				"All 4 Alleyway cats as gold"
			)
			expect(IndexRewards.unlockLabel({ id = "cats10", need = 10 }, "Park", 10)).to.equal(
				"All 10 Park cats"
			)
			expect(IndexRewards.isIndexDecor({ id = "index_alley", source = "index" })).to.equal(
				true
			)
			expect(IndexRewards.isIndexDecor({ id = "plants" })).to.equal(false)
		end)

		it("finds normal pieces whose gold piece is owned and placed", function()
			local catalog = {
				cats = {},
				decor = {
					{ id = "index_alley" },
					{ id = "index_alley_gold", replaces = "index_alley" },
					{ id = "index_park_gold", replaces = "index_park" },
				},
			}
			local replaced = IndexRewards.replacedBy(catalog, {
				decorOwned = { index_alley = true, index_alley_gold = true, index_park_gold = true },
				decorPlaced = {
					index_alley = true,
					index_alley_gold = true,
					index_park_gold = false,
				},
			})
			expect(replaced.index_alley).to.equal("index_alley_gold")
			expect(replaced.index_park).to.equal(nil)
		end)

		it("lists a prize's foods in id order", function()
			local list = IndexRewards.lureList({ lures = { tuna = 2, salmon = 1 } })
			expect(#list).to.equal(2)
			expect(list[1].id).to.equal("salmon")
			expect(list[2].count).to.equal(2)
			expect(#IndexRewards.lureList({ coins = 5 })).to.equal(0)
		end)
	end)

	describe("IndexRewards next reward (Derek 2026-10-27)", function()
		local function kinds(parts: { any }): string
			local out: { string } = {}
			for _, part in parts do
				table.insert(
					out,
					part.kind .. (if part.id then ":" .. part.id else "") .. "=" .. part.amount
				)
			end
			return table.concat(out, ",")
		end

		it("points at the first reward to claim, else the first still to reach", function()
			local none = { collection = {}, goldCollection = {}, indexRewards = {} }
			local views = IndexRewards.views(CATALOG, none, "alley")
			local nextView = IndexRewards.nextView(views)
			expect(nextView.milestone.id).to.equal("cats3")
			expect(nextView.state).to.equal("locked")
			expect(IndexRewards.toGo(nextView)).to.equal(3)

			local three = {
				collection = { tabby = 1, tuxedo = 1, calico = 1 },
				goldCollection = {},
				indexRewards = {},
			}
			local ready = IndexRewards.nextView(IndexRewards.views(CATALOG, three, "alley"))
			expect(ready.milestone.id).to.equal("cats3")
			expect(ready.state).to.equal("ready")
			expect(IndexRewards.toGo(ready)).to.equal(0)

			three.indexRewards = { alley = { cats3 = true } }
			local after = IndexRewards.nextView(IndexRewards.views(CATALOG, three, "alley"))
			expect(after.milestone.id).to.equal("all4")
			expect(IndexRewards.toGo(after)).to.equal(1)
		end)

		it("has no next reward once every milestone is claimed", function()
			local done = {
				collection = { tabby = 1, tuxedo = 1, calico = 1, siamese = 1 },
				goldCollection = { tabby = 1, tuxedo = 1, calico = 1, siamese = 1 },
				indexRewards = { alley = { cats3 = true, all4 = true, gold4 = true } },
			}
			expect(IndexRewards.nextView(IndexRewards.views(CATALOG, done, "alley"))).to.equal(nil)
			expect(IndexRewards.nextView({})).to.equal(nil)
		end)

		it("lists what a prize pays as parts with amounts, in a steady order", function()
			expect(kinds(IndexRewards.prizeParts({ coins = 300 }))).to.equal("coins=300")
			expect(
				kinds(
					IndexRewards.prizeParts({
						lures = { tuna = 2, salmon = 1 },
						decorId = "index_alley",
					})
				)
			).to.equal("lure:salmon=1,lure:tuna=2,decor:index_alley=1")
			expect(kinds(IndexRewards.prizeParts({}))).to.equal("")
		end)

		it("shows spins and crates, the rewards Derek wants instead of decor outright", function()
			local prize = { coins = 1000, spins = 2, crates = { decor_park = 1, decor_alley = 3 } }
			expect(kinds(IndexRewards.prizeParts(prize))).to.equal(
				"coins=1000,spins=2,crate:decor_alley=3,crate:decor_park=1"
			)
		end)

		it("shows a prize kind it does not know yet, and skips empty amounts", function()
			local prize = { goldenFish = 5, coins = 0, lures = { tuna = 0 }, spins = 0, note = "x" }
			expect(kinds(IndexRewards.prizeParts(prize))).to.equal("other:goldenFish=5")
		end)
	end)

	-- golden-fish.md sections 5, 5b and 8: two tracks per area, rows { id, track, needs }, the "all" page and the
	-- new prize fields. The UI reads both shapes so it works before and after the engineer's catalog change.
	describe("IndexRewards F54 shapes (design v0.7)", function()
		local function kinds(parts: { any }): string
			local out: { string } = {}
			for _, part in parts do
				table.insert(
					out,
					part.kind .. (if part.id then ":" .. part.id else "") .. "=" .. part.amount
				)
			end
			return table.concat(out, ",")
		end

		local F54 = {
			cats = CATALOG.cats,
			indexMilestones = {
				{ id = "cats3", track = "normal", needs = 3 },
				{ id = "gold1", track = "gold", needs = 1 },
				{ id = "gold2", track = "gold", needs = 2 },
				{ id = "total5", track = "normal", needs = 5 },
			},
			indexPrizes = {
				alley = {
					cats3 = { coins = 300, coinSeconds = 600, fish = 5, spins = 1 },
					gold1 = { fish = 10, spins = 1, crates = { alley_crate = 1 }, bonus = 0.01 },
					gold2 = { fish = 15, spins = 2 },
				},
				all = { total5 = { fish = 10, spins = 1, bonus = 0.02 } },
			},
		}

		it("reads needs and the gold track as well as need and gold", function()
			expect(IndexRewards.need({ id = "a", needs = 6 })).to.equal(6)
			expect(IndexRewards.need({ id = "a", need = 4 })).to.equal(4)
			expect(IndexRewards.isGold({ id = "a", track = "gold", needs = 1 })).to.equal(true)
			expect(IndexRewards.isGold({ id = "a", need = 10, gold = true })).to.equal(true)
			expect(IndexRewards.isGold({ id = "a", track = "normal", needs = 3 })).to.equal(false)
			expect(IndexRewards.needLabel({ id = "gold1", track = "gold", needs = 1 }, 4)).to.equal(
				"1 gold"
			)
			expect(IndexRewards.needLabel({ id = "c", needs = 1 }, 4)).to.equal("1 cat")
		end)

		it("counts each track from its own collection and points NEXT per track", function()
			local state = {
				collection = { tabby = 1, tuxedo = 1 },
				goldCollection = { tabby = 1 },
				indexRewards = {},
			}
			local views = IndexRewards.views(F54, state, "alley")
			local ids: { string } = {}
			for _, view in views do
				table.insert(ids, view.milestone.id .. "=" .. view.state)
			end
			expect(table.concat(ids, ",")).to.equal("cats3=locked,gold1=ready,gold2=locked")
			-- the board's next reward: the one ready to claim
			expect(IndexRewards.nextView(views).milestone.id).to.equal("gold1")
			-- the strip's NEXT stickers, one per track
			local normal = IndexRewards.nextView(views, "normal")
			expect(normal.milestone.id).to.equal("cats3")
			expect(IndexRewards.toGo(normal)).to.equal(1)
			expect(IndexRewards.nextView(views, "gold").milestone.id).to.equal("gold1")
			state.indexRewards = { alley = { gold1 = true } }
			local gold = IndexRewards.nextView(IndexRewards.views(F54, state, "alley"), "gold")
			expect(gold.milestone.id).to.equal("gold2")
			expect(IndexRewards.toGo(gold)).to.equal(1)
		end)

		it("counts every area's cats on the All Cats page", function()
			local state = {
				collection = { tabby = 1, calico = 1, corgi_cat = 1 },
				goldCollection = {},
				indexRewards = {},
			}
			local counts = IndexRewards.counts(F54, state, IndexRewards.ALL_AREA)
			expect(counts.total).to.equal(5)
			expect(counts.found).to.equal(3)
			local views = IndexRewards.views(F54, state, "all")
			expect(#views).to.equal(1)
			expect(views[1].milestone.id).to.equal("total5")
			expect(IndexRewards.toGo(views[1])).to.equal(2)
		end)

		it(
			"prices coins that grow with the cafe like the Tip Jar, never under the least",
			function()
				local prize = { coins = 300, coinSeconds = 600 }
				expect(IndexRewards.coins(prize, 2)).to.equal(1200)
				expect(IndexRewards.coins(prize, 0.1)).to.equal(300)
				expect(IndexRewards.coins(prize, nil)).to.equal(300)
				expect(IndexRewards.coins({ coins = 500 }, 100)).to.equal(500)
				expect(IndexRewards.coins({ coinSeconds = 60 }, 2.5)).to.equal(150)
			end
		)

		it("shows coins, fish, food, spins, crates, the tag and the bonus in that order", function()
			local prize = {
				bonus = 0.05,
				tag = "Cat Master",
				crates = { alley_golden_crate = 2, alley_crate = 1 },
				spins = 2,
				lures = { salmon = 2 },
				fish = 25,
				coins = 1000,
				coinSeconds = 600,
			}
			expect(kinds(IndexRewards.prizeParts(prize, 10))).to.equal(
				"coins=6000,fish=25,lure:salmon=2,spins=2,crate:alley_crate=1,crate:alley_golden_crate=2,"
					.. "tag:Cat Master=1,bonus=0.05"
			)
			expect(kinds(IndexRewards.prizeParts({ fish = 10, bonus = 0, tag = "" }))).to.equal(
				"fish=10"
			)
		end)
	end)

	describe("IndexRewards edges (QA)", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Catalog = require(ReplicatedStorage.Shared.Catalog) :: any
		local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
		local SharedRewards = require(ReplicatedStorage.Shared.IndexRewards)

		-- The card the server's answer stands for: no blocker is a Claim button, "Already claimed"
		-- a tick, and "Find n more" a bar with n to go.
		local function serverCard(
			profile: any,
			areaId: string,
			milestoneId: string
		): (string, number?)
			local blocker = SharedRewards.blocker(profile, areaId, milestoneId)
			if blocker == nil then
				return "ready", nil
			elseif blocker == "Already claimed" then
				return "claimed", nil
			end
			return "locked", tonumber(string.match(blocker, "^Find (%d+) more"))
		end

		-- Every card on every page against the server; returns how many the server would pay now.
		local function agree(profile: any): number
			local ready = 0
			for areaId in pairs(Catalog.indexPrizes) do
				local views = IndexRewards.views(Catalog, profile, areaId)
				expect(#views).to.equal(#Catalog.indexMilestones)
				for _, view in ipairs(views) do
					local card = areaId .. "." .. view.milestone.id .. " "
					local state, left = serverCard(profile, areaId, view.milestone.id)
					expect(card .. view.state).to.equal(card .. state)
					if state == "locked" then
						expect(IndexRewards.toGo(view)).to.equal(left)
					elseif state == "ready" then
						ready += 1
					end
				end
			end
			local _, badges = IndexRewards.claimable(Catalog, profile)
			expect(badges).to.equal(ready)
			return ready
		end

		-- The Claim button and the red badges promise a payout, so they light exactly where
		-- ClaimIndexReward pays.
		it("shows Claim where the server pays, as every page fills and is claimed", function()
			local profile: any = ProfileSchema.template(1000)
			table.clear(profile.collection)
			expect(agree(profile)).to.equal(0)
			for _, def in ipairs(Catalog.cats) do
				profile.collection[def.id] = 1000
				agree(profile)
			end
			for _, def in ipairs(Catalog.cats) do
				profile.goldCollection[def.id] = 1000
				agree(profile)
			end
			-- Every page full: every milestone is reachable; a claim ticks its own card, no other.
			local open = 0
			for _ in pairs(Catalog.indexPrizes) do
				open += #Catalog.indexMilestones
			end
			expect(agree(profile)).to.equal(open)
			for areaId in pairs(Catalog.indexPrizes) do
				for _, milestone in ipairs(Catalog.indexMilestones) do
					profile.indexRewards[areaId] = profile.indexRewards[areaId] or {}
					profile.indexRewards[areaId][milestone.id] = true
					open -= 1
					expect(agree(profile)).to.equal(open)
				end
			end
		end)
	end)
end
