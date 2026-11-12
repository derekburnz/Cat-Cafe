--!strict
-- UI/Components/LateStationsLogic.luau: the Oasis Spa and Relic Museum cards' rows, the Cat Cannon picker's strips
-- and the stations' "!" (#2651 part 4, late-stations.md sections 1 and 2).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LateStationsLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LateStationsLogic")
	) :: any
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
	local LateStations =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LateStations")) :: any

	local NOW = 1_800_000_000
	local HOUR = Config.SpaSeconds

	local function cat(uid: string, catId: string, level: number, fields: { [string]: any }?): any
		local out: { [string]: any } = {
			uid = uid,
			catId = catId,
			variant = "base",
			caughtAt = 0,
			locked = false,
			level = level,
			xp = 0,
			xpToNext = 100,
			charm = 50,
			stars = 3,
			rating = level,
		}
		for key, value in fields or {} do
			out[key] = value
		end
		return out
	end

	-- the first room's first two exhibits
	local room = LateStations.rooms[1]
	local first, second = room.cats[1], room.cats[2]

	local function spaOf(slots: number, soaking: { any }): any
		return {
			open = true,
			slots = slots,
			nextPrice = Config.SpaSlotPrices[slots + 1],
			soaking = soaking,
			ready = 0,
		}
	end

	describe("LateStationsLogic.spaRows", function()
		it("words a soaking cat before, during and after its levels", function()
			local cats = { a = cat("a", first, 10) }
			local at = NOW - 30 * 60
			local spa = spaOf(1, {
				{
					slot = 1,
					uid = "a",
					catId = first,
					doneAt = at + HOUR,
					fullAt = at + HOUR * Config.SpaMaxHours,
				},
			})
			local soon = LateStationsLogic.spaRows(spa, cats, NOW)[1]
			expect(soon.kind).to.equal("cat")
			expect(soon.ready).to.equal(false)
			expect(soon.line).to.equal("First level in 30m")
			local later = LateStationsLogic.spaRows(spa, cats, at + 3 * HOUR + 600)[1]
			expect(later.levels).to.equal(3)
			expect(later.ready).to.equal(true)
			expect(later.line).to.equal("+3 levels · next in 50m")
			local full = LateStationsLogic.spaRows(spa, cats, at + 30 * HOUR)[1]
			expect(full.levels).to.equal(Config.SpaMaxHours)
			expect(full.full).to.equal(true)
			expect(full.line).to.equal(string.format("+%d levels · full", Config.SpaMaxHours))
		end)

		it("stops at the top level (#2904)", function()
			local cats = { a = cat("a", first, Config.CatMaxLevel - 2) }
			local at = NOW - 5 * HOUR
			local spa = spaOf(1, { { slot = 1, uid = "a", catId = first, doneAt = at + HOUR } })
			local row = LateStationsLogic.spaRows(spa, cats, NOW)[1]
			expect(row.levels).to.equal(2)
			expect(row.full).to.equal(true)
		end)

		it("shows an empty slot, the next to buy and the one after", function()
			local rows = LateStationsLogic.spaRows(spaOf(1, {}), {}, NOW)
			expect(#rows).to.equal(#Config.SpaSlotPrices)
			expect(rows[1].kind).to.equal("empty")
			expect(rows[2].kind).to.equal("buy")
			expect(rows[2].price).to.equal(Config.SpaSlotPrices[2])
			expect(rows[3].kind).to.equal("shut")
			expect(rows[3].line).to.equal("Open slot 2 first")
		end)
	end)

	describe("LateStationsLogic.spaReady and collectText", function()
		it("sums the levels waiting over the finished slots", function()
			local cats = { a = cat("a", first, 10), b = cat("b", second, 20) }
			local spa = spaOf(2, {
				{ slot = 1, uid = "a", catId = first, doneAt = NOW - 2 * HOUR }, -- 3 hours in: 3 levels
				{ slot = 2, uid = "b", catId = second, doneAt = NOW + 60 }, -- not yet
			})
			local levels, count = LateStationsLogic.spaReady(spa, cats, NOW)
			expect(levels).to.equal(3)
			expect(count).to.equal(1)
			expect(LateStationsLogic.collectText(3)).to.equal("Collect +3 levels")
			expect(LateStationsLogic.collectText(1)).to.equal("Collect +1 level")
			expect(LateStationsLogic.collectText(0)).to.equal("Collect")
		end)
	end)

	describe("LateStationsLogic.spaCandidates", function()
		it("lists cats below the top level and not soaking, highest level first", function()
			local cats = {
				a = cat("a", first, 10),
				b = cat("b", first, 30),
				c = cat("c", second, Config.CatMaxLevel),
				d = cat("d", second, 40),
			}
			local spa = spaOf(1, { { slot = 1, uid = "d", catId = second, doneAt = NOW + HOUR } })
			local list = LateStationsLogic.spaCandidates(cats, spa)
			expect(#list).to.equal(2)
			expect(list[1].uid).to.equal("b")
			expect(list[2].uid).to.equal("a")
		end)

		it("sorts by rarity by default and by level when asked (#3463)", function()
			local Catalog =
				require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
			local function ofRarity(rarity: string): string
				for _, def in Catalog.cats do
					if def.rarity == rarity then
						return def.id
					end
				end
				error("no " .. rarity .. " cat in the catalog")
			end
			local common, legendary = ofRarity("Common"), ofRarity("Legendary")
			local cats = {
				c40 = cat("c40", common, 40, { name = "Zed" }),
				l5 = cat("l5", legendary, 5, { name = "Bea" }),
				l5gold = cat("l5gold", legendary, 5, { variant = "gold", name = "Cy" }),
				l2rainbow = cat("l2rainbow", legendary, 2, { variant = "rainbow", name = "Di" }),
				l9 = cat("l9", legendary, 9, { name = "Abe" }),
				l9b = cat("l9b", legendary, 9, { name = "aaron" }),
			}
			local function order(sort: string?): string
				local uids = {}
				for _, entry in LateStationsLogic.spaCandidates(cats, nil, sort) do
					table.insert(uids, entry.uid)
				end
				return table.concat(uids, " ")
			end
			-- rarity: Legendary before Common; in one rarity rainbow, gold, plain, then level, then name (any case)
			expect(order(nil)).to.equal("l2rainbow l5gold l9b l9 l5 c40")
			expect(order("Rarity")).to.equal(order(nil))
			expect(order("nonsense")).to.equal(order(nil))
			-- level: highest first, then rarity, then name; the coat does not count
			expect(order("Level")).to.equal("c40 l9b l9 l5 l5gold l2rainbow")
			expect(order("level")).to.equal(order("Level"))
			-- the same cats always come out in the same order
			expect(order("Level")).to.equal(order("Level"))
		end)

		it("reads any stored sort as Rarity unless it says Level (#3463)", function()
			expect(LateStationsLogic.SPA_SORTS[1]).to.equal("Rarity")
			expect(LateStationsLogic.spaSort("Level")).to.equal("Level")
			expect(LateStationsLogic.spaSort("level")).to.equal("Level")
			expect(LateStationsLogic.spaSort("Rarity")).to.equal("Rarity")
			expect(LateStationsLogic.spaSort("")).to.equal("Rarity")
			expect(LateStationsLogic.spaSort(nil)).to.equal("Rarity")
			expect(LateStationsLogic.spaSort(7)).to.equal("Rarity")
		end)

		it("lists every cat, however many (#3136)", function()
			local cats = {}
			for index = 1, 400 do
				cats["u" .. index] = cat("u" .. index, first, 1 + index % 20)
			end
			expect(#LateStationsLogic.spaCandidates(cats, nil)).to.equal(400)
		end)

		it("finds a cat by its own name or its breed, any case (#3136)", function()
			local named = cat("a", first, 5, { name = "Mochi" })
			local breed = LateStationsLogic.catName(first)
			expect(LateStationsLogic.spaMatch(named, "", "All")).to.equal(true)
			expect(LateStationsLogic.spaMatch(named, "  moc ", "All")).to.equal(true)
			expect(LateStationsLogic.spaMatch(named, string.upper(breed), "All")).to.equal(true)
			expect(LateStationsLogic.spaMatch(named, "zzzz", "All")).to.equal(false)
			expect(LateStationsLogic.spaMatch(named, "%a", "All")).to.equal(false) -- typed as plain words
		end)

		it("keeps resting or working cats (#3136)", function()
			local resting = cat("a", first, 5)
			local working = cat("b", first, 5, { spotId = "spot1" })
			expect(LateStationsLogic.spaMatch(resting, "", "Resting")).to.equal(true)
			expect(LateStationsLogic.spaMatch(resting, "", "Working")).to.equal(false)
			expect(LateStationsLogic.spaMatch(working, "", "Working")).to.equal(true)
			expect(LateStationsLogic.spaMatch(working, "", "Resting")).to.equal(false)
		end)

		it(
			"titles a row with the cat's own name and keeps its breed on the second line (#3136)",
			function()
				local named = cat("a", first, 5, { name = "Mochi", variant = "gold" })
				local breed = LateStationsLogic.catName(first)
				expect(LateStationsLogic.spaTitle(named)).to.equal("Mochi")
				expect(
					string.find(LateStationsLogic.spaSubtitle(named), "Gold " .. breed, 1, true)
						~= nil
				).to.equal(true)
				expect(LateStationsLogic.spaTitle(cat("b", first, 5))).to.equal(breed)
			end
		)

		it("changes the list's key only when a row would change (#3136)", function()
			local list = { cat("a", first, 5), cat("b", first, 6) }
			local key = LateStationsLogic.spaKey(list)
			expect(LateStationsLogic.spaKey({ cat("a", first, 5), cat("b", first, 6) })).to.equal(
				key
			)
			expect(LateStationsLogic.spaKey({ cat("a", first, 5), cat("b", first, 7) }) ~= key).to.equal(
				true
			)
			expect(LateStationsLogic.spaKey({ cat("a", first, 5) }) ~= key).to.equal(true)
		end)

		it("asks before taking a cat out", function()
			expect(LateStationsLogic.takeOutText("Mochi")).to.equal(
				"Take Mochi out now? It won't level up."
			)
		end)
	end)

	describe("LateStationsLogic.donatable", function()
		it(
			"offers the only copy but never a locked one, one at the spa or the last cat of all (#3123)",
			function()
				local cats = {
					a = cat("a", first, 12, { charm = 70 }),
					b = cat("b", first, 12, { charm = 40 }),
					c = cat("c", first, 5, { locked = true }),
					d = cat("d", first, 3),
					e = cat("e", second, 1),
				}
				local spa =
					spaOf(1, { { slot = 1, uid = "d", catId = first, doneAt = NOW + HOUR } })
				local list = LateStationsLogic.donatable(cats, first, {}, spa)
				expect(#list).to.equal(2)
				expect(list[1].uid).to.equal("b") -- same level, lower charm first
				expect(list[2].uid).to.equal("a")
				expect(#LateStationsLogic.donatable(cats, second, {}, nil)).to.equal(1) -- #3123: the only copy may go
				expect(#LateStationsLogic.donatable({ e = cats.e }, second, {}, nil)).to.equal(0) -- the last cat of all
				expect(#LateStationsLogic.donatable(cats, first, { [first] = "base" }, nil)).to.equal(
					0
				) -- filled
			end
		)

		it(
			"puts plain idle copies first, then working ones, gold and rainbow last (#3125)",
			function()
				local cats = {
					low = cat("low", first, 1, { variant = "gold" }),
					busy = cat("busy", first, 2, { spotId = "spot_1" }),
					mid = cat("mid", first, 9),
					top = cat("top", first, 30),
				}
				local list = LateStationsLogic.donatable(cats, first, {}, nil)
				expect(list[1].uid).to.equal("mid")
				expect(list[2].uid).to.equal("top")
				expect(list[3].uid).to.equal("busy")
				expect(list[4].uid).to.equal("low")
			end
		)

		it("asks before the only copy goes (#3123), and lists an Auto fill (#3130)", function()
			expect(LateStationsLogic.giveAsk("Tabby", "base", 1)).to.equal(
				"This is your only Tabby. It leaves your cafe. Give it anyway?"
			)
			expect(LateStationsLogic.giveAsk("Tabby", "gold", 2)).to.equal(
				"This is a gold cat. Give it anyway?"
			)
			expect(LateStationsLogic.giveAsk("Tabby", "base", 2)).to.equal(nil)
			local cats = { a = cat("a", first, 1), b = cat("b", first, 2), c = cat("c", second, 3) }
			local row = LateStationsLogic.rooms(nil, cats, nil)[1]
			local picks = LateStationsLogic.fillPlan(row, 3)
			expect(#picks).to.equal(2)
			expect(picks[1].cat.uid).to.equal("a")
			expect(picks[1].only).to.equal(false)
			expect(picks[2].only).to.equal(true)
			expect(#LateStationsLogic.fillPlan(row, 2)).to.equal(1) -- the last cat of all stays
			expect(LateStationsLogic.fillAsk(row.name, picks)).to.equal(
				string.format(
					"Give 2 cats to %s Hall? %s and %s. 1 is your only copy.",
					row.name,
					row.exhibits[1].name,
					row.exhibits[2].name
				)
			)
		end)

		it("warns before a gold or rainbow copy goes", function()
			expect(LateStationsLogic.giveWarning("gold")).to.equal(
				"This is a gold cat. Give it anyway?"
			)
			expect(LateStationsLogic.giveWarning("rainbow")).to.equal(
				"This is a rainbow cat. Give it anyway?"
			)
			expect(LateStationsLogic.giveWarning("base")).to.equal(nil)
		end)
	end)

	describe("LateStationsLogic.rooms", function()
		it("gives each room its exhibits, what is filled and what can be filled", function()
			local cats = { a = cat("a", first, 1), b = cat("b", first, 2), c = cat("c", second, 3) }
			local museum = {
				open = true,
				filled = { [room.cats[3]] = "gold" },
				count = 1,
				total = 70,
				canFill = 1,
				rooms = {},
				bonus = 0,
			}
			local rooms = LateStationsLogic.rooms(museum, cats, nil)
			expect(#rooms).to.equal(#LateStations.rooms)
			local row = rooms[1]
			expect(row.area).to.equal(room.area)
			expect(row.filled).to.equal(1)
			expect(row.canFill).to.equal(2) -- #3123: the only copy of the second cat too
			expect(row.done).to.equal(false)
			expect(row.exhibits[1].line).to.equal("You have 2")
			expect(#row.exhibits[1].give).to.equal(2) -- either copy can go; the other stays
			expect(row.exhibits[2].line).to.equal("You have 1")
			expect(#row.exhibits[2].give).to.equal(1)
			local solo = LateStationsLogic.rooms(museum, { c = cats.c }, nil)[1]
			expect(LateStationsLogic.whyNot(solo.exhibits[2])).to.equal(
				"Keep at least one cat in your cafe"
			)
			expect(row.exhibits[3].coat).to.equal("gold")
			expect(row.exhibits[3].line).to.equal("Given")
		end)

		it("words the tips bonus", function()
			expect(LateStationsLogic.bonusText(0.1)).to.equal("+10% tips forever")
			expect(LateStationsLogic.bonusText(nil)).to.equal("+0% tips forever")
		end)
	end)

	describe("LateStationsLogic.pickerLine and bangShows", function()
		local function state(live: boolean, ready: number, canFill: number): any
			return {
				live = live,
				spa = {
					open = true,
					slots = 1,
					soaking = {
						{ slot = 1, uid = "a", catId = first, levels = 2, doneAt = NOW - HOUR },
					},
					ready = ready,
				},
				museum = {
					open = true,
					filled = {},
					count = 23,
					total = 70,
					canFill = canFill,
					rooms = {},
					bonus = 0,
				},
			}
		end

		it("gives the Desert and Ruins strips from the shared lines", function()
			local spa = LateStationsLogic.pickerLine(state(true, 1, 4), "desert")
			expect(spa.name).to.equal("Oasis Spa")
			expect(spa.state).to.equal("+2 levels ready")
			expect(spa.ready).to.equal(true)
			local museum = LateStationsLogic.pickerLine(state(true, 1, 4), "ruins")
			expect(museum.name).to.equal("Relic Museum")
			expect(museum.state).to.equal("23/70 · 4 can be filled")
			expect(museum.ready).to.equal(true)
			expect(LateStationsLogic.pickerLine(state(true, 1, 4), "park")).to.equal(nil)
		end)

		it("shows nothing until the stations are live, and no dot with nothing to do", function()
			expect(LateStationsLogic.pickerLine(state(false, 1, 4), "desert")).to.equal(nil)
			expect(LateStationsLogic.bangShows(state(false, 1, 4), "spa")).to.equal(false)
			expect(LateStationsLogic.bangShows(state(true, 0, 0), "spa")).to.equal(false)
			expect(LateStationsLogic.bangShows(state(true, 0, 0), "museum")).to.equal(false)
			expect(LateStationsLogic.bangShows(state(true, 0, 2), "museum")).to.equal(true)
		end)
	end)
end
