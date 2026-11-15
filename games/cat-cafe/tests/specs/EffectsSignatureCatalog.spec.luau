--!strict
-- Every signature effect (Presets.signature) belongs to a cat in the Catalog, so a renamed or mistyped cat id cannot
-- leave an effect that no cat ever shows. The `minor` ones (a small touch that only takes a spare slot) are the
-- Rares; the full ones belong to rarer cats. Harvest Hollow's three wait in PENDING until #4251 puts its
-- cats in the Catalog: a pending id that has arrived fails here, so the list empties with that change.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Presets = require(Client:WaitForChild("Effects"):WaitForChild("Presets")) :: any
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any

	-- #4251: Harvest Hollow's three wait here until its cats are in the Catalog (the Castle's six arrived, #4184)
	local PENDING: { [string]: boolean } =
		{ cranberry = true, maple_leaf = true, harvest_moon = true }

	describe("Effects signature cats and the Catalog", function()
		it("names only cats the Catalog has", function()
			local missing = {}
			for catId in Presets.signature do
				if Catalog.catsById[catId] == nil and not PENDING[catId] then
					table.insert(missing, catId)
				end
			end
			table.sort(missing)
			expect(table.concat(missing, " ")).to.equal("")
		end)

		it("drops a cat from the waiting list once the Catalog has it", function()
			local arrived = {}
			for catId in PENDING do
				expect(Presets.signature[catId] ~= nil).to.equal(true)
				if Catalog.catsById[catId] ~= nil then
					table.insert(arrived, catId)
				end
			end
			table.sort(arrived)
			expect(table.concat(arrived, " ")).to.equal("")
		end)

		it("keeps the small touch for Rares and the full effect for rarer cats", function()
			local wrong = {}
			for catId, spec in Presets.signature do
				local def = Catalog.catsById[catId]
				if def ~= nil and (spec.minor == true) ~= (def.rarity == "Rare") then
					table.insert(wrong, catId .. ":" .. tostring(def.rarity))
				end
			end
			table.sort(wrong)
			expect(table.concat(wrong, " ")).to.equal("")
		end)
	end)
end
