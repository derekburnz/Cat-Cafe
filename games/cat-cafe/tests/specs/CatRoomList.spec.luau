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
end
