--!strict
-- UI/Components/IndexBook.luau: the Index's Cats and Gold tabs as one scroll of areas (Derek's Set 4 answer).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local IndexBook = require(Components:WaitForChild("IndexBook")) :: any

	local CATALOG = {
		areas = {
			{ id = "park", name = "Park", tier = 2 },
			{ id = "alley", name = "Alleyway", tier = 1 },
		},
		cats = {
			{ id = "boss", area = "alley", rarity = "Legendary" },
			{ id = "tabby", area = "alley", rarity = "Common" },
			{ id = "tux", rarity = "Rare" }, -- no area: an Alleyway cat
			{ id = "ginger", area = "alley", rarity = "Common" },
			{ id = "corgi", area = "park", rarity = "Epic" },
			{ id = "calico", area = "spare", rarity = "Rare" },
			{ id = "persian", area = "spare", rarity = "Epic" },
		},
	}

	local function state(changes: { [string]: any }): any
		local out: { [string]: any } = {
			tier = 1,
			catsOwned = {},
			collection = {},
			goldCollection = {},
		}
		for key, value in changes do
			out[key] = value
		end
		return out
	end

	local function ids(list: { any }): string
		local out = {}
		for _, each in list do
			table.insert(out, each.id)
		end
		return table.concat(out, ",")
	end

	describe("IndexBook.sections", function()
		it("lists the areas in tier order with their cats rarest last", function()
			local sections = IndexBook.sections(CATALOG, state({}), "normal")
			expect(ids(sections)).to.equal("alley,park")
			expect(ids(sections[1].cats)).to.equal("tabby,ginger,tux,boss")
			expect(sections[1].total).to.equal(4)
		end)

		it("counts met or owned cats on the Cats tab and gold ones on the Gold tab", function()
			local s = state({
				collection = { tabby = 1 },
				catsOwned = { boss = { count = 1 } },
				goldCollection = { tabby = 1, corgi = 1 },
			})
			local normal = IndexBook.sections(CATALOG, s, "normal")
			expect(normal[1].have).to.equal(2)
			local gold = IndexBook.sections(CATALOG, s, "gold")
			expect(gold[1].have).to.equal(1)
			expect(gold[2].have).to.equal(1)
		end)

		it("leaves the spare cats out on both tabs, found or not", function()
			local s = state({ collection = { calico = 1 }, goldCollection = { calico = 1 } })
			expect(ids(IndexBook.sections(CATALOG, s, "normal"))).to.equal("alley,park")
			expect(ids(IndexBook.sections(CATALOG, s, "gold"))).to.equal("alley,park")
		end)

		it("locks an area above the player's tier until something in it is found", function()
			local sections = IndexBook.sections(CATALOG, state({}), "normal")
			expect(sections[2].locked).to.equal(true)
			local found =
				IndexBook.sections(CATALOG, state({ collection = { corgi = 1 } }), "normal")
			expect(found[2].locked).to.equal(false)
			expect(IndexBook.sections(CATALOG, state({ tier = 2 }), "normal")[2].locked).to.equal(
				false
			)
		end)
	end)

	describe("IndexBook's Exclusive page", function()
		local WITH = table.clone(CATALOG)
		WITH.cats = table.clone(CATALOG.cats)
		table.insert(
			WITH.cats,
			1,
			{ id = "bellhop", area = "exclusive", rarity = "Rare", exclusive = true }
		)

		it("puts the exclusive cats on their own page after every area", function()
			local sections = IndexBook.sections(WITH, state({}), "normal")
			expect(ids(sections)).to.equal("alley,park,exclusive")
			local page = sections[3]
			expect(page.exclusive).to.equal(true)
			expect(page.name).to.equal("Exclusive")
			expect(page.locked).to.equal(false)
			expect(ids(page.cats)).to.equal("bellhop")
			expect(sections[1].exclusive).to.equal(false)
			expect(sections[1].total).to.equal(4)
		end)

		it("leaves it off the Gold tab, as an exclusive cat is never gold", function()
			local s = state({ goldCollection = { bellhop = 1 } })
			expect(ids(IndexBook.sections(WITH, s, "gold"))).to.equal("alley,park")
		end)

		it("counts it without Complete! and never opens on it", function()
			local s = state({
				catsOwned = { bellhop = { count = 1 } },
				collection = { tabby = 1, ginger = 1, tux = 1, boss = 1, corgi = 1 },
				tier = 2,
			})
			local sections = IndexBook.sections(WITH, s, "normal")
			expect(IndexBook.count(sections[3])).to.equal("1 / 1")
			expect(IndexBook.first(sections)).to.equal("alley")
			expect(IndexBook.first(IndexBook.sections(WITH, state({ tier = 2 }), "normal"))).to.equal(
				"alley"
			)
		end)
	end)

	describe("IndexBook.count and first", function()
		it("says the count, Complete! or the tier", function()
			local s = state({ collection = { corgi = 1, calico = 1 } })
			local sections = IndexBook.sections(CATALOG, s, "normal")
			expect(IndexBook.count(sections[1])).to.equal("0 / 4")
			expect(IndexBook.count(sections[2])).to.equal("Complete!")
			expect(IndexBook.count(IndexBook.sections(CATALOG, state({}), "normal")[2])).to.equal(
				"Tier 2"
			)
		end)

		it("opens on the first open area with cats still to find", function()
			local done = { tabby = 1, ginger = 1, tux = 1, boss = 1 }
			expect(IndexBook.first(IndexBook.sections(CATALOG, state({}), "normal"))).to.equal(
				"alley"
			)
			expect(
				IndexBook.first(
					IndexBook.sections(CATALOG, state({ collection = done, tier = 2 }), "normal")
				)
			).to.equal("park")
			expect(
				IndexBook.first(IndexBook.sections(CATALOG, state({ collection = done }), "normal"))
			).to.equal("alley")
		end)
	end)

	describe("IndexBook.reward", function()
		local function view(
			id: string,
			track: string?,
			viewState: string,
			have: number,
			need: number
		): any
			return {
				milestone = { id = id, track = track, needs = need },
				prize = {},
				state = viewState,
				have = have,
			}
		end

		it("counts the rewards waiting on the tab's track only", function()
			local views = {
				view("cats3", "normal", "ready", 3, 3),
				view("cats6", "normal", "locked", 4, 6),
				view("gold1", "gold", "ready", 1, 1),
				view("gold2", "gold", "ready", 2, 2),
			}
			local normal = IndexBook.reward(views, "normal")
			expect(normal.state).to.equal("ready")
			expect(normal.ready).to.equal(1)
			expect(IndexBook.reward(views, "gold").ready).to.equal(2)
		end)

		it("says what the next one needs, then done, or none without rewards", function()
			local next = IndexBook.reward({
				view("cats3", "normal", "claimed", 3, 3),
				view("cats6", "normal", "locked", 4, 6),
			}, "normal")
			expect(next.state).to.equal("next")
			expect(next.need).to.equal(6)
			expect(next.toGo).to.equal(2)
			expect(IndexBook.reward({ view("cats3", "normal", "claimed", 3, 3) }, "normal").state).to.equal(
				"done"
			)
			expect(IndexBook.reward({}, "gold").state).to.equal("none")
		end)
	end)

	describe("IndexBook's Rainbow tab (F99)", function()
		local WITH = table.clone(CATALOG)
		WITH.cats = table.clone(CATALOG.cats)
		table.insert(
			WITH.cats,
			1,
			{ id = "bellhop", area = "exclusive", rarity = "Rare", exclusive = true }
		)

		it("counts rainbow cats in each area, with no Exclusive or spare page", function()
			local s = state({
				collection = { tabby = 1, ginger = 1, corgi = 1 },
				goldCollection = { tabby = 1, ginger = 1 },
				rainbowCollection = { ginger = 1, calico = 1 },
			})
			local sections = IndexBook.sections(WITH, s, "rainbow")
			expect(ids(sections)).to.equal("alley,park")
			expect(sections[1].have).to.equal(1)
			expect(sections[1].total).to.equal(4)
			expect(sections[2].have).to.equal(0)
			local found = IndexBook.found(s, "rainbow")
			expect(found.ginger).to.equal(true)
			expect(found.tabby).to.equal(nil)
			expect(IndexBook.count(sections[1])).to.equal("1 / 4")
		end)

		it("reads no rainbow cats from a save without the collection", function()
			expect(next(IndexBook.found(state({}), "rainbow"))).to.equal(nil)
		end)

		it("counts the Rainbow track's rewards on its own tab", function()
			local views = {
				{
					milestone = { id = "rainbow1", track = "rainbow", needs = 1 },
					prize = {},
					state = "ready",
					have = 1,
				},
				{
					milestone = { id = "rainbow3", track = "rainbow", needs = 3 },
					prize = {},
					state = "locked",
					have = 1,
					need = 3,
				},
			}
			expect(IndexBook.reward(views, "rainbow").ready).to.equal(1)
			expect(IndexBook.reward(views, "normal").state).to.equal("none")
		end)
	end)
end
