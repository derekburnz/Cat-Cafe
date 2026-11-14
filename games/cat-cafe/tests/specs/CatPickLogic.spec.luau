--!strict
-- UI/Components/CatPickLogic (#3700): the order, filters and words of a "pick a cat" list.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("CatPickLogic")) :: any
	local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any

	-- one cat kind of each rarity, from the real catalog
	local kind: { [string]: string } = {}
	for _, def in Catalog.cats do
		if kind[def.rarity] == nil then
			kind[def.rarity] = def.id
		end
	end

	local function cat(uid: string, rarity: string, over: { [string]: any }?): any
		local made: { [string]: any } = {
			uid = uid,
			catId = kind[rarity],
			variant = "normal",
			level = 1,
			rating = 1,
			name = uid,
		}
		for key, value in over or {} do
			made[key] = value
		end
		return made
	end

	local function uids(list: { any }): string
		local out = {}
		for _, entry in list do
			table.insert(out, entry.uid)
		end
		return table.concat(out, ",")
	end

	local cats = {
		a = cat("a", "Common", { level = 50, rating = 900 }),
		b = cat("b", "Legendary", { level = 3, rating = 40 }),
		c = cat("c", "Rare", { level = 20, rating = 5000, spotId = "s1" }),
		d = cat("d", "Legendary", { level = 3, rating = 40, variant = "gold" }),
		e = cat("e", "Rare", { level = 9, rating = 10, trait = { id = "x" } }),
	}

	describe("Cat pick list", function()
		it("sorts by rarity first", function()
			expect(Logic.SORTS[1]).to.equal("Rarity")
			-- Legendary (gold before plain), then Rare by level, then Common
			expect(uids(Logic.sorted(cats, "Rarity"))).to.equal("d,b,c,e,a")
		end)

		it("sorts by money by default (#3874)", function()
			expect(Logic.DEFAULT_SORT).to.equal("Money")
			expect(uids(Logic.sorted(cats))).to.equal("c,a,b,d,e")
			expect(uids(Logic.sorted(cats, "nonsense"))).to.equal("c,a,b,d,e")
		end)

		it("sorts by level, money and name", function()
			expect(uids(Logic.sorted(cats, "Level"))).to.equal("a,c,e,b,d")
			expect(uids(Logic.sorted(cats, "Money"))).to.equal("c,a,b,d,e")
			expect(uids(Logic.sorted(cats, "Name"))).to.equal("a,b,c,d,e")
		end)

		it(
			"has Money, Level and Rarity in the Filter pop-up, and a Name sort falls back to Money (#3874)",
			function()
				expect(table.concat(Logic.MENU_SORTS, ",")).to.equal("Money,Level,Rarity")
				expect(table.concat(Logic.MENU_FILTERS, ",")).to.equal(
					"All,Working,Resting,No trait,Has trait"
				)
				expect(Logic.menuSort("Rarity")).to.equal("Rarity")
				expect(Logic.menuSort("Level")).to.equal("Level")
				expect(Logic.menuSort("Name")).to.equal("Money")
				expect(Logic.menuSort(nil)).to.equal("Money")
			end
		)

		it("turns each order round", function()
			expect(uids(Logic.sorted(cats, "Rarity", true))).to.equal("a,e,c,b,d")
			expect(uids(Logic.sorted(cats, "Level", true))).to.equal("b,d,e,c,a")
			expect(uids(Logic.sorted(cats, "Name", true))).to.equal("e,d,c,b,a")
		end)

		it("leaves out what is not a cat and takes no cats at all", function()
			expect(#Logic.sorted(nil)).to.equal(0)
			expect(#Logic.sorted({ x = 5, y = { catId = "none" } } :: any)).to.equal(0)
		end)

		it("filters by job, by trait and by the words typed", function()
			expect(Logic.match(cats.c, "", "Working")).to.equal(true)
			expect(Logic.match(cats.c, "", "Resting")).to.equal(false)
			expect(Logic.match(cats.a, "", "Resting")).to.equal(true)
			expect(Logic.match(cats.e, "", "Has trait")).to.equal(true)
			expect(Logic.match(cats.e, "", "No trait")).to.equal(false)
			expect(Logic.match(cats.a, "", "No trait")).to.equal(true)
			expect(Logic.match(cats.a, "", "Has trait")).to.equal(false)
			expect(Logic.match(cats.a, "  A ", "All")).to.equal(true)
			expect(Logic.match(cats.a, "zzz", "All")).to.equal(false)
			expect(Logic.match(cats.d, "gold", "All")).to.equal(true)
		end)

		it("puts Show chips on top of each other, one group at a time (#3940)", function()
			local function shown(...: string): { [string]: boolean }
				local out = {}
				for _, name in { ... } do
					out[name] = true
				end
				return out
			end
			-- c works with no trait, a rests with no trait, e has a trait
			expect(Logic.matchShown(cats.c, "", shown("Working", "No trait"))).to.equal(true)
			expect(Logic.matchShown(cats.a, "", shown("Working", "No trait"))).to.equal(false)
			expect(Logic.matchShown(cats.e, "", shown("No trait"))).to.equal(false)
			expect(Logic.matchShown(cats.a, "", shown("Working", "Resting"))).to.equal(true)
			expect(Logic.matchShown(cats.c, "", shown("Working", "Resting"))).to.equal(true)
			expect(Logic.matchShown(cats.e, "", shown("No trait", "Has trait"))).to.equal(true)
			expect(Logic.matchShown(cats.a, "", {})).to.equal(true)
			expect(Logic.matchShown(cats.a, "zzz", {})).to.equal(false)
			expect(Logic.matchShown(cats.a, "", nil)).to.equal(true)
		end)

		it("toggles a chip, clears on All and packs the chips for the save (#3940)", function()
			local on = Logic.toggleShown({}, "Working")
			expect(Logic.packShown(on)).to.equal("Working")
			on = Logic.toggleShown(on, "No trait")
			expect(Logic.packShown(on)).to.equal("Working,No trait")
			expect(Logic.anyShown(on)).to.equal(true)
			on = Logic.toggleShown(on, "Working")
			expect(Logic.packShown(on)).to.equal("No trait")
			expect(Logic.anyShown(Logic.toggleShown(on, "All"))).to.equal(false)
			expect(Logic.packShown(Logic.toggleShown(on, "Nonsense"))).to.equal("")
			expect(Logic.packShown(Logic.unpackShown("Has trait,Resting"))).to.equal(
				"Resting,Has trait"
			)
			expect(Logic.anyShown(Logic.unpackShown("Bad,Words"))).to.equal(false)
			expect(Logic.anyShown(Logic.unpackShown(7))).to.equal(false)
		end)

		it("words a row and the count", function()
			expect(Logic.rarity(cats.b)).to.equal("Legendary")
			expect(Logic.rarity({ uid = "q", catId = "none" })).to.equal("Common")
			expect(Logic.coatTag(cats.d)).to.equal("GOLD")
			expect(Logic.coatTag(cats.a)).to.equal(nil)
			expect(Logic.title(cats.a)).to.equal("a")
			local line = Logic.line(cats.c, "+$5K/s")
			expect(string.find(line, "+$5K/s", 1, true) ~= nil).to.equal(true)
			expect(string.find(line, "Lv 20", 1, true) ~= nil).to.equal(true)
			expect(string.find(line, "Working", 1, true) ~= nil).to.equal(true)
			expect(string.find(Logic.line(cats.a), "Resting", 1, true) ~= nil).to.equal(true)
			expect(Logic.count(42)).to.equal("42 cats")
			expect(Logic.count(1)).to.equal("1 cat")
			expect(Logic.count(0)).to.equal("0 cats match")
		end)
	end)
end
