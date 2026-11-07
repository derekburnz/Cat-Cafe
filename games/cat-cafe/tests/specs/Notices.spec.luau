--!strict
-- UI/Notices.luau: the menu tiles' red dots.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Notices = require(Client:WaitForChild("UI"):WaitForChild("Notices")) :: any

	local function catalog(): any
		return {
			cats = {},
			upgrades = {},
			decor = {
				{ id = "plant", cost = 500, category = "plants" },
				-- F97: coin decor made a Classic Crate find, cost 0
				{ id = "lamp", cost = 0, category = "lights", source = "crate", crate = "classic" },
			},
		}
	end

	local function state(extra: { [string]: any }?): any
		local base: { [string]: any } =
			{ money = 1000, tier = 1, upgradeLevels = {}, decorOwned = {}, decorPlaced = {} }
		for key, value in extra or {} do
			base[key] = value
		end
		return base
	end

	-- #2345: the Upgrades tile's "!" and the window's Buy button share Components/UpgradeReady
	describe("Notices Upgrades keys", function()
		local function shop(): any
			local c = catalog()
			c.upgrades = {
				{ id = "tables", maxLevel = 3, costs = { 100, 400, 900 } },
				{ id = "net", maxLevel = 2, costs = { 200, 5000 }, requiresTierAtLevel = { [2] = 3 } },
				{ id = "statue", maxLevel = 1, costs = { 50 }, requiresTier = 2 },
				-- starts at level 1, whose price is 0: never a free "!" (ProfileSchema clamps to startLevel)
				{ id = "espresso", maxLevel = 2, costs = { 0, 999999 }, startLevel = 1 },
			}
			return c
		end

		it("lights for an affordable next level, not a too dear one", function()
			local keys = Notices.candidates(shop(), state({ money = 150 })).Upgrades
			expect(table.concat(keys, ",")).to.equal("tables:1")
			expect(#Notices.candidates(shop(), state({ money = 10 })).Upgrades).to.equal(0)
		end)

		it("skips tier-locked and maxed levels", function()
			local levels = { tables = 3, net = 1 }
			local keys = Notices.candidates(shop(), state({ money = 99999, upgradeLevels = levels })).Upgrades
			expect(#keys).to.equal(0) -- tables maxed, net level 2 needs tier 3, statue needs tier 2
			keys = Notices.candidates(shop(), state({ money = 99999, tier = 3, upgradeLevels = levels })).Upgrades
			expect(table.concat(keys, ",")).to.equal("net:2,statue:1")
		end)
	end)

	describe("Notices Decor keys", function()
		it("never lights for crate-find decor the player does not own", function()
			local keys = Notices.candidates(catalog(), state()).Decor
			expect(table.concat(keys, ",")).to.equal("plant")
		end)

		it("lights once for crate-find decor the player finds", function()
			local keys =
				Notices.candidates(catalog(), state({ decorOwned = { lamp = true } })).Decor
			expect(table.concat(keys, ",")).to.equal("plant,piece:lamp")
		end)
	end)
end
