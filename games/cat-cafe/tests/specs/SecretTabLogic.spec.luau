--!strict
-- UI/Components/SecretTabLogic.luau (#4221): the Index's Secret tab, one card per area.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local SecretTabLogic = require(Components:WaitForChild("SecretTabLogic")) :: any

	local CATALOG = {
		areas = {
			{ id = "park", name = "Park", tier = 2 },
			{ id = "alley", name = "Alleyway", tier = 1 },
			{ id = "snowy", name = "Snowy Mountain", tier = 8 },
		},
		cats = {
			{ id = "tabby", area = "alley", rarity = "Common", name = "Tabby" },
			{
				id = "ghost",
				area = "secret",
				secretArea = "alley",
				rarity = "Secret",
				name = "Cafe Ghost",
			},
			{
				id = "nebula",
				area = "secret",
				secretArea = "snowy",
				rarity = "Secret",
				name = "Nebula",
			},
			{ id = "stray", area = "secret", rarity = "Secret", name = "Old Secret" }, -- no home: on no card
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

	local function states(cards: { any }): string
		local out = {}
		for _, card in cards do
			table.insert(out, card.area .. ":" .. card.state)
		end
		return table.concat(out, ",")
	end

	describe("cards", function()
		it("lists every area in tier order with its Secret's state", function()
			local cards = SecretTabLogic.cards(CATALOG, state({}))
			expect(states(cards)).to.equal("alley:hidden,park:soon,snowy:locked")
			expect(SecretTabLogic.counter(cards)).to.equal("0 / 3 found")
			expect(SecretTabLogic.line(cards)).to.equal(SecretTabLogic.NONE_YET)
		end)

		it(
			"shows a found Secret even in an area the tier has not opened, with its coats",
			function()
				local cards = SecretTabLogic.cards(
					CATALOG,
					state({
						collection = { nebula = 1, ghost = 1 },
						goldCollection = { nebula = 1 },
						rainbowCollection = { ghost = 2 },
					})
				)
				expect(states(cards)).to.equal("alley:found,park:soon,snowy:found")
				expect(cards[1].rainbow).to.equal(true)
				expect(cards[1].gold).to.equal(false)
				expect(cards[3].gold).to.equal(true)
				expect(SecretTabLogic.counter(cards)).to.equal("2 / 3 found")
				expect(SecretTabLogic.line(cards)).to.equal(SecretTabLogic.LINE)
			end
		)

		it("opens an area's card once the tier reaches it", function()
			local cards =
				SecretTabLogic.cards(CATALOG, state({ tier = 8, catsOwned = { ghost = true } }))
			expect(states(cards)).to.equal("alley:found,park:soon,snowy:hidden")
		end)
	end)

	describe("words", function()
		it("names, hints and the all found line", function()
			local cards = SecretTabLogic.cards(CATALOG, state({}))
			expect(SecretTabLogic.name(cards[1])).to.equal("???")
			expect(SecretTabLogic.hint(cards[1])).to.equal(SecretTabLogic.HINTS.alley)
			expect(SecretTabLogic.name(cards[2])).to.equal("Coming soon")
			expect(SecretTabLogic.hint(cards[2])).to.equal("")
			expect(SecretTabLogic.name(cards[3])).to.equal("Tier 8")
			expect(SecretTabLogic.hint(cards[3])).to.equal("Reach Tier 8 to search here")
			local all = {
				{ area = "alley", state = "found", def = { name = "Cafe Ghost" } },
			}
			expect(SecretTabLogic.line(all)).to.equal(SecretTabLogic.ALL_FOUND)
			expect(SecretTabLogic.name(all[1])).to.equal("Cafe Ghost")
		end)

		it("keeps every line short enough for a phone card", function()
			for _, hint in SecretTabLogic.HINTS do
				expect(#hint <= 48).to.equal(true)
			end
			expect(#SecretTabLogic.NONE_YET <= 70).to.equal(true)
		end)
	end)
end
