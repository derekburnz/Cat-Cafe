--!strict
-- UI/Components/IndexHints.luau: the Index's find hints, the reveal's area count and the goal card nudge (#1919,
-- first-hour.md section 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local IndexHints = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("IndexHints")
	) :: any

	local catalog = {
		areas = {
			{ id = "alley", name = "Alley", tier = 1 },
			{ id = "park", name = "Park", tier = 2 },
			{ id = "woods", name = "Woods", tier = 4 },
		},
		cats = {
			{ id = "a1", name = "A1", rarity = "Common", area = "alley" },
			{ id = "a2", name = "A2", rarity = "Rare", area = "alley" },
			{ id = "p1", name = "P1", rarity = "Common", area = "park" },
			{ id = "p2", name = "P2", rarity = "Common", area = "park" },
			{ id = "p3", name = "P3", rarity = "Epic", area = "park" },
			{ id = "w1", name = "W1", rarity = "Legendary", area = "woods" },
			{ id = "x1", name = "X1", rarity = "Rare", area = "exclusive", exclusive = true },
		},
	}

	local function state(tier: number, found: { string }, step7Next: boolean?)
		local collection = {}
		for _, id in found do
			collection[id] = 1
		end
		local done = {}
		if step7Next then
			for n = 1, 6 do
				done[n] = true
			end
		end
		return {
			tier = tier,
			catsOwned = {},
			collection = collection,
			tutorialStep = 5,
			grandOpening = { done = done },
		}
	end

	describe("IndexHints.hint", function()
		it("says catch or bait for an open area, and the tier for a locked one", function()
			expect(IndexHints.hint(catalog, state(2, {}), catalog.cats[3])).to.equal(
				"Not found yet. Catch one in the Park, or it may come to your bait."
			)
			expect(IndexHints.hint(catalog, state(2, {}), catalog.cats[6])).to.equal(
				"Not found yet. The Woods opens at Tier 4. Shy: walk up slowly."
			)
		end)

		it("adds the shy line from Epic up and keeps exclusive cats as they are", function()
			expect(IndexHints.hint(catalog, state(2, {}), catalog.cats[5])).to.equal(
				"Not found yet. Catch one in the Park, or it may come to your bait. Shy: walk up slowly."
			)
			expect(IndexHints.hint(catalog, state(2, {}), catalog.cats[2])).to.equal(
				"Not found yet. Catch one in the Alley, or it may come to your bait."
			)
			expect(IndexHints.hint(catalog, state(2, {}), catalog.cats[7])).to.equal(nil)
		end)
	end)

	describe("IndexHints.nudge", function()
		it("shows only while the twelve cats step is next", function()
			expect(IndexHints.nudge(catalog, state(2, { "a1" }))).to.equal(nil)
			local nudge = IndexHints.nudge(catalog, state(2, { "a1", "x1" }, true))
			expect(nudge.text).to.equal("Find 11 more cats")
		end)

		it("points at the newest open area with the most missing cats", function()
			expect(IndexHints.nudge(catalog, state(2, { "a1" }, true)).area).to.equal("park")
			-- a tie (one missing each) goes to the newer area; the locked Woods never counts
			expect(IndexHints.nudge(catalog, state(2, { "a1", "p1", "p2" }, true)).area).to.equal(
				"park"
			)
			expect(IndexHints.nudge(catalog, state(2, { "p1", "p2", "p3" }, true)).area).to.equal(
				"alley"
			)
		end)

		it("says one cat for the last one and hides once twelve are found", function()
			local twelve = {}
			for n = 1, 11 do
				table.insert(twelve, "c" .. n)
			end
			expect(IndexHints.nudge(catalog, state(2, twelve, true)).text).to.equal(
				"Find 1 more cat"
			)
			table.insert(twelve, "c12")
			expect(IndexHints.nudge(catalog, state(2, twelve, true))).to.equal(nil)
		end)
	end)
end
