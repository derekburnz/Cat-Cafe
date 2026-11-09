--!strict
-- UI/Components/HudUnlocks.luau: the small HUD of the first loop and its unlocks (F87, easy-start.md section 2f).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local HudUnlocks = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("HudUnlocks")
	) :: any

	local function view(
		step: number?,
		cats: number?,
		tier: number?,
		potions: number?,
		fish: number?
	)
		return {
			step = step,
			cats = cats or 0,
			tier = tier or 1,
			potions = potions or 0,
			fish = fish or 0,
		}
	end

	local function count(shown: { [string]: boolean }): number
		local n = 0
		for _, key in HudUnlocks.KEYS do
			if shown[key] then
				n += 1
			end
		end
		return n
	end

	describe("HudUnlocks.shown", function()
		it("starts a new player with nothing but the always-on pieces", function()
			expect(count(HudUnlocks.shown(view(0)))).to.equal(0)
			expect(count(HudUnlocks.shown(view(1)))).to.equal(0)
		end)

		it("opens the Collection, Upgrades and Decor at the first check-in, the rest at step 5", function()
			expect(HudUnlocks.shown(view(1, 1)).decor).to.equal(false)
			local two = HudUnlocks.shown(view(2, 1))
			expect(two.cats).to.equal(true)
			expect(two.upgrades).to.equal(true)
			expect(two.decor).to.equal(true)
			expect(two.quests).to.equal(false)
			local four = HudUnlocks.shown(view(4, 1))
			expect(four.daily).to.equal(false)
			expect(four.clock).to.equal(false)
			local done = HudUnlocks.shown(view(5, 1))
			for _, key in
				{ "quests", "daily", "gifts", "feedback", "invite", "equipBest", "clock", "goal" }
			do
				expect(done[key]).to.equal(true)
			end
		end)

		it(
			"opens the Index at the third cat, Tier 2 pieces at Tier 2 or the first item",
			function()
				expect(HudUnlocks.shown(view(5, 2)).index).to.equal(false)
				expect(HudUnlocks.shown(view(3, 3)).index).to.equal(true)
				expect(HudUnlocks.shown(view(3, 3)).decor).to.equal(true)
				expect(HudUnlocks.shown(view(5, 1)).potions).to.equal(false)
				expect(HudUnlocks.shown(view(5, 1, 1, 1)).potions).to.equal(true)
				expect(HudUnlocks.shown(view(5, 1, 1, 0, 3)).fish).to.equal(true)
				expect(HudUnlocks.shown(view(5, 1, 2)).areas).to.equal(true)
				expect(HudUnlocks.shown(view(5, 1, 1)).areas).to.equal(false)
			end
		)

		it("shows everything with no step", function()
			expect(count(HudUnlocks.shown(view(nil)))).to.equal(#HudUnlocks.KEYS)
		end)
	end)

	describe("HudUnlocks.update", function()
		it("pops nothing on the first sync", function()
			local shown, opened = HudUnlocks.update(nil, view(5, 1))
			expect(shown.quests).to.equal(true)
			expect(#opened).to.equal(0)
		end)

		it("pops each piece once as it opens, and keeps what showed", function()
			local shown, opened = HudUnlocks.update(nil, view(1))
			shown, opened = HudUnlocks.update(shown, view(3, 1))
			expect(table.find(opened, "cats") ~= nil).to.equal(true)
			expect(table.find(opened, "upgrades") ~= nil).to.equal(true)
			expect(table.find(opened, "decor") ~= nil).to.equal(true)
			expect(#opened).to.equal(3)
			shown, opened = HudUnlocks.update(shown, view(3, 1))
			expect(#opened).to.equal(0)
			shown, opened = HudUnlocks.update(shown, view(5, 3))
			expect(table.find(opened, "index") ~= nil).to.equal(true)
			expect(table.find(opened, "quests") ~= nil).to.equal(true)
			-- selling down to one cat keeps the Index
			shown = HudUnlocks.update(shown, view(5, 1))
			expect(shown.index).to.equal(true)
		end)
	end)

	describe("HudUnlocks.view", function()
		it("counts the cats, the bag and the fish", function()
			local v = HudUnlocks.view({
				tutorialStep = 4,
				cats = { a = {}, b = {} },
				tier = 2,
				potions = { tip_potion = 2, swift_potion = 1 },
				goldenFish = 7,
			})
			expect(v.step).to.equal(4)
			expect(v.cats).to.equal(2)
			expect(v.tier).to.equal(2)
			expect(v.potions).to.equal(3)
			expect(v.fish).to.equal(7)
			expect(HudUnlocks.view({}).cats).to.equal(0)
		end)
	end)
end
