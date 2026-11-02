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
