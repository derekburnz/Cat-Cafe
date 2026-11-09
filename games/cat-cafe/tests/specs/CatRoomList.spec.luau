--!strict
-- UI/Components/CatRoomList.luau: which cats the cat room's inventory grid shows, and in what order.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatRoomList = require(Components:WaitForChild("CatRoomList")) :: any

	local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
	local function rank(rarity: string): number
		return table.find(RARITIES, rarity) or 0
	end
	local defs = {
		tabby = { id = "tabby", name = "Tabby", rarity = "Common", incomePerSecond = 2 },
		tuxedo = { id = "tuxedo", name = "Tuxedo", rarity = "Rare", incomePerSecond = 5 },
		void = { id = "void", name = "Void", rarity = "Epic", incomePerSecond = 12 },
	}
	local cats = {
		a = { uid = "a", catId = "tabby" },
		b = { uid = "b", catId = "tuxedo", name = "Mochi" },
		c = { uid = "c", catId = "void" },
		d = { uid = "d", catId = "tabby", spotId = "barista_1" },
		e = { uid = "e", catId = "tabby", rating = 3 },
	}
	local function uids(list: { any }): string
		local out = {}
		for _, instance in list do
			table.insert(out, instance.uid)
		end
		return table.concat(out, ",")
	end

	describe("CatRoomList.counts", function()
		it("counts working and resting cats", function()
			local counts = CatRoomList.counts(cats)
			expect(counts.all).to.equal(5)
			expect(counts.working).to.equal(1)
			expect(counts.resting).to.equal(4)
		end)
	end)

	describe("CatRoomList.list", function()
		it("puts working cats first, then rarer, then the higher rating, then the uid", function()
			expect(uids(CatRoomList.list(cats, defs, rank, "All", ""))).to.equal("d,c,b,e,a")
		end)

		it("filters working and resting cats", function()
			expect(uids(CatRoomList.list(cats, defs, rank, "Working", ""))).to.equal("d")
			expect(uids(CatRoomList.list(cats, defs, rank, "Resting", ""))).to.equal("c,b,e,a")
		end)

		it("searches the player's name, the breed and the rarity, ignoring case and spaces", function()
			expect(uids(CatRoomList.list(cats, defs, rank, "All", "moc"))).to.equal("b")
			expect(uids(CatRoomList.list(cats, defs, rank, "All", "  TUX "))).to.equal("b")
			expect(uids(CatRoomList.list(cats, defs, rank, "All", "epic"))).to.equal("c")
			expect(uids(CatRoomList.list(cats, defs, rank, "Resting", "tabby"))).to.equal("e,a")
		end)

		it("treats pattern characters in the query as plain text", function()
			expect(#CatRoomList.list(cats, defs, rank, "All", "%a")).to.equal(0)
			expect(#CatRoomList.list(cats, defs, rank, "All", "(")).to.equal(0)
		end)

		it("keeps a cat whose breed is missing from the catalog", function()
			local list = CatRoomList.list({ z = { uid = "z", catId = "ghost" } }, defs, rank, "All", "")
			expect(#list).to.equal(1)
			expect(CatRoomList.matches(list[1], nil, "gho")).to.equal(true)
		end)
	end)

	-- QA: a big seeded cat room over the real catalog, so the grid never loses, doubles or reshuffles a cat.
	describe("edges (QA)", function()
		local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Catalog)
		local catDefs: { [string]: any } = {}
		for _, def in Catalog.cats do
			catDefs[def.id] = def
		end
		local function realRank(rarity: string): number
			return Catalog.rarityRank[rarity] or 0
		end
		local NAMES = { "Mochi", "Biscuit", "Tabby Jr" }

		-- n cats from a seed, added to the table first to last or last to first
		local function room(seed: number, n: number, backwards: boolean): { [string]: any }
			local rng = Random.new(seed)
			local made = {}
			for i = 1, n do
				local def = Catalog.cats[rng:NextInteger(1, #Catalog.cats)]
				local spot = Catalog.spots[rng:NextInteger(1, #Catalog.spots)]
				made[i] = {
					uid = string.format("%012x", rng:NextInteger(0, 2 ^ 31)),
					catId = def.id,
					spotId = if rng:NextNumber() < 0.3 then spot.id else nil,
					rating = if rng:NextNumber() < 0.8 then rng:NextInteger(1, 4) else nil,
					name = if rng:NextNumber() < 0.3
						then NAMES[rng:NextInteger(1, #NAMES)]
						else nil,
				}
			end
			local out = {}
			for i = 1, n do
				local instance = made[if backwards then n + 1 - i else i]
				out[instance.uid] = instance
			end
			return out
		end

		local function show(cats: { [string]: any }, filter: string, query: string): { any }
			return CatRoomList.list(cats, catDefs, realRank, filter, query)
		end

		-- the sort key the grid promises: working, rarity, rating, then breed and uid
		local function before(a: any, b: any): boolean
			local keyA = {
				if a.spotId ~= nil then 1 else 0,
				realRank(catDefs[a.catId].rarity),
				a.rating or catDefs[a.catId].incomePerSecond,
			}
			local keyB = {
				if b.spotId ~= nil then 1 else 0,
				realRank(catDefs[b.catId].rarity),
				b.rating or catDefs[b.catId].incomePerSecond,
			}
			for k = 1, 3 do
				if keyA[k] ~= keyB[k] then
					return keyA[k] > keyB[k]
				end
			end
			return a.catId < b.catId or (a.catId == b.catId and a.uid < b.uid)
		end

		it("200 cats: Working and Resting split All, and the order is a strict one", function()
			local cats200 = room(42, 200, false)
			local all = show(cats200, "All", "")
			local counts = CatRoomList.counts(cats200)
			expect(#all).to.equal(counts.all)
			expect(#show(cats200, "Working", "")).to.equal(counts.working)
			expect(#show(cats200, "Resting", "")).to.equal(counts.resting)
			expect(counts.working + counts.resting).to.equal(counts.all)
			local seen: { [string]: boolean } = {}
			for i, instance in all do
				expect(seen[instance.uid]).never.to.be.ok()
				seen[instance.uid] = true
				if i > 1 and not before(all[i - 1], instance) then
					error(
						string.format("%s before %s is out of order", all[i - 1].uid, instance.uid)
					)
				end
			end
		end)

		it("the same cats added in another order list the same way", function()
			local forwards = show(room(7, 120, false), "All", "")
			local backwards = show(room(7, 120, true), "All", "")
			expect(uids(backwards)).to.equal(uids(forwards))
		end)

		it("a search keeps the grid order and only drops cats", function()
			local cats120 = room(9, 120, false)
			local all = show(cats120, "All", "")
			for _, query in { "tabby", "COMMON", "moch", "jr", " legendary " } do
				local want = {}
				for _, instance in all do
					if CatRoomList.matches(instance, catDefs[instance.catId], query) then
						table.insert(want, instance)
					end
				end
				expect(uids(show(cats120, "All", query))).to.equal(uids(want))
			end
		end)

		it("finds every catalog cat by its breed and its rarity", function()
			for _, def in Catalog.cats do
				local instance = { uid = "x", catId = def.id }
				expect(CatRoomList.matches(instance, def, def.name)).to.equal(true)
				expect(CatRoomList.matches(instance, def, string.upper(def.name))).to.equal(true)
				expect(CatRoomList.matches(instance, def, def.rarity)).to.equal(true)
			end
		end)
	end)
end
