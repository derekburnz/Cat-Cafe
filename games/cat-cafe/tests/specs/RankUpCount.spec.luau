--!strict
-- #1141: the rank up "different cats" count is one shared function (Economy.rankUpCatCount), read by the server's
-- Economy.rankUpBlocker and by the client's RankUpNeeds, which RankUp.progress (the rank up card, the upgrade shop
-- button, the goal card and the gate signs) builds its rows and "ready" from. Derek's call (2026-11-04): the free
-- Bellhop Cat counts. These check both sides agree.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RankUpNeeds =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RankUpNeeds"))

	local BELLHOP = "bellhop_cat"
	local NEED = (Catalog.getTier(3) :: any).distinctCats :: number -- #4189: 8 (10 before)
	local NOW = 1000

	-- Caught (non exclusive, non spare) cat ids of one rarity, in catalog order.
	local function caughtIdsOf(rarity: string): { string }
		local ids = {}
		for _, def in Catalog.cats do
			if def.rarity == rarity and def.exclusive ~= true then
				table.insert(ids, def.id)
			end
		end
		return ids
	end

	-- A Tier 2 profile with plenty of coins and NEED - 1 different caught cats, one of them Epic (Tier 3 needs NEED and
	-- an Epic), plus the Bellhop Cat when `withBellhop`.
	local function profile(withBellhop: boolean): any
		local p: any = ProfileSchema.template(NOW)
		p.tier = 2
		p.coins = 1e10
		p.collection = {}
		local epic = caughtIdsOf("Epic")[1]
		p.collection[epic] = NOW
		local added = 1
		for _, rarity in { "Common", "Rare" } do
			for _, id in caughtIdsOf(rarity) do
				if added < NEED - 1 then
					p.collection[id] = NOW
					added += 1
				end
			end
		end
		assert(added == NEED - 1, "not enough catalog cats for the test profile")
		if withBellhop then
			p.collection[BELLHOP] = NOW
		end
		return p
	end

	-- What the client renders from: the state the sync sends, with the same collection.
	local function stateOf(p: any): any
		return { money = p.coins, tier = p.tier, collection = p.collection, catsOwned = {} }
	end

	-- The client's view of the next tier for this profile.
	local function client(p: any): any
		return RankUpNeeds.of(Catalog.getTier(p.tier + 1) :: any, stateOf(p))
	end

	describe("RankUpCount (#1141)", function()
		it("the Bellhop Cat is an exclusive free cat and counts toward rank up", function()
			local def = Catalog.getCat(BELLHOP)
			expect(def ~= nil and def.exclusive == true and def.source == "free").to.equal(true)
			expect(Economy.countsForRankUp(BELLHOP)).to.equal(true)
		end)

		it(
			"one short in normal cats plus the Bellhop Cat: the client shows ready and the server ranks up",
			function()
				local p = profile(true)
				expect(NEED).to.equal(8) -- #4189: was 10; #3111: was 11; #2683: was 13; #2230: was 12
				expect(Economy.rankUpCatCount(p.collection)).to.equal(NEED)
				expect(Economy.rankUpBlocker(p)).to.equal(nil)
				local needs = client(p)
				expect(needs.ready).to.equal(true)
				expect(needs.catsHave).to.equal(NEED)
			end
		)

		it("one short without the Bellhop Cat: both say not yet, with the same count", function()
			local p = profile(false)
			expect(Economy.rankUpCatCount(p.collection)).to.equal(NEED - 1)
			expect(Economy.rankUpBlocker(p)).to.equal(
				string.format("Needs %d different cats (you have %d)", NEED, NEED - 1)
			)
			local needs = client(p)
			expect(needs.ready).to.equal(false)
			expect(needs.catsHave).to.equal(NEED - 1)
		end)

		it(
			"duplicates, gold coats and cats away, sold or traded change nothing: only the collection counts",
			function()
				local p = profile(true)
				local before = Economy.rankUpCatCount(p.collection)
				-- owned cats (two of one breed, a gold coat, a cat away) are not what is counted
				p.cats = {}
				p.goldCollection = { [BELLHOP] = NOW }
				expect(Economy.rankUpCatCount(p.collection)).to.equal(before)
				expect(Economy.rankUpBlocker(p)).to.equal(nil)
				expect(client(p).ready).to.equal(true)
			end
		)

		it(
			"an unknown id counts toward the number but never meets a rarity, on both sides",
			function()
				local p = profile(false)
				p.collection.not_a_cat = NOW
				expect(Economy.rankUpCatCount(p.collection)).to.equal(NEED)
				expect(Economy.rankUpCatsAtLeast(p.collection, "Epic")).to.equal(1)
				expect(Economy.rankUpBlocker(p)).to.equal(nil)
				expect(client(p).ready).to.equal(true)
			end
		)

		it("the rarity requirement agrees too: no Epic means not ready on both sides", function()
			local p = profile(true)
			for catId in p.collection do
				local def = Catalog.getCat(catId)
				if def ~= nil and def.rarity == "Epic" then
					p.collection[catId] = nil
					p.collection[caughtIdsOf("Common")[#caughtIdsOf("Common")]] = NOW
				end
			end
			expect(Economy.rankUpCatsAtLeast(p.collection, "Epic")).to.equal(0)
			expect(Economy.rankUpBlocker(p)).to.equal("Needs one cat, Epic or better")
			expect(client(p).ready).to.equal(false)
		end)
	end)

	describe("RankUpNeeds.rarityCaption (#2999, the goal card's short lines on a phone)", function()
		it("reads Mythical+ cat for one and 2 Mythical+ cats for more on touch", function()
			expect(RankUpNeeds.rarityCaption("Mythical", 1, true)).to.equal("Mythical+ cat")
			expect(RankUpNeeds.rarityCaption("Mythical", 2, true)).to.equal("2 Mythical+ cats")
			expect(RankUpNeeds.rarityCaption("Legendary", 3, true)).to.equal("3 Legendary+ cats")
			expect(RankUpNeeds.rarityCaption("Epic", 0, true)).to.equal("Epic+ cat")
		end)

		it("keeps the PC and console wording", function()
			expect(RankUpNeeds.rarityCaption("Mythical", 1, false)).to.equal("Mythical or better")
			expect(RankUpNeeds.rarityCaption("Legendary", 2, false)).to.equal("Legendary or better")
		end)

		it("is never longer on touch than the PC caption, for every tier's need", function()
			for _, tier in Catalog.tiers do
				local rarity = (tier :: any).needsRarity
				if rarity ~= nil then
					local count = (tier :: any).needsRarityCount or 1
					local touch = RankUpNeeds.rarityCaption(rarity, count, true)
					expect(#touch <= #RankUpNeeds.rarityCaption(rarity, count, false)).to.equal(
						true
					)
					expect(#touch <= 18).to.equal(true)
				end
			end
		end)
	end)
end
