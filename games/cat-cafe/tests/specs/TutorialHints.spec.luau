--!strict
-- UI/Components/TutorialHints.luau: the tutorial strip's device-aware line per step (F87, easy-start.md section 2e).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TutorialHints = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TutorialHints")
	) :: any

	local DEVICES = { "keyboard", "touch", "gamepad" }
	local VIEWS = {
		{ step = 0 },
		{ step = 1 },
		{ step = 2, resting = true },
		{ step = 2, resting = false },
		{ step = 3 },
		{ step = 3, cats = 1 },
		{ step = 3, cats = 1, night = true }, -- #3238
		{ step = 4, bowl = false },
		{ step = 4, bowl = true, baited = false },
		{ step = 4, bowl = true, baited = true },
		{ step = 4, bowl = true, baited = true, arrived = true },
	}

	local function line(view: { [string]: any }, device: string): string?
		local copy = table.clone(view)
		copy.device = device
		return TutorialHints.line(copy)
	end

	describe("TutorialHints.line", function()
		it("has a short line for every step on every device", function()
			for _, view in VIEWS do
				for _, device in DEVICES do
					local text = line(view, device)
					expect(type(text)).to.equal("string")
					expect(#(text :: string) > 10).to.equal(true)
					expect(#(text :: string) <= 50).to.equal(true)
				end
			end
		end)

		it("names a letter key on a keyboard only", function()
			for _, view in VIEWS do
				for _, device in { "touch", "gamepad" } do
					local text = line(view, device) :: string
					expect(text:find("%(%u%)") == nil).to.equal(true)
				end
			end
			expect(line({ step = 3 }, "keyboard")).to.equal(
				"Buy a table in Upgrades (U): more tips per cat"
			)
			expect(line({ step = 3 }, "touch")).to.equal(
				"Tap Upgrades and buy a table: more tips per cat"
			)
		end)

		it(
			"says the strays return at sunrise on step 3 at night, on every device (#3238)",
			function()
				local night = { step = 3, cats = 1, night = true }
				expect(line(night, "keyboard")).to.equal(
					"Strays return at sunrise, or buy a table (U)"
				)
				expect(line(night, "touch")).to.equal("Strays return at sunrise, or tap Upgrades")
				expect(line(night, "gamepad")).to.equal(
					"Strays return at sunrise, or open Upgrades"
				)
				-- by day, or once two cats are caught, the words are as before
				expect(line({ step = 3, cats = 1, night = false }, "touch")).to.equal(
					"Catch another cat, or tap Upgrades for a table"
				)
				expect(line({ step = 3, cats = 2, night = true }, "touch")).to.equal(
					"Tap Upgrades and buy a table: more tips per cat"
				)
				-- the step still asks for the second cat (the trail and ring read ask)
				expect(TutorialHints.ask(night)).to.equal("second")
			end
		)

		it("says how to swing the net on each device", function()
			expect((line({ step = 0 }, "keyboard") :: string):find("Click", 1, true) ~= nil).to.equal(
				true
			)
			expect((line({ step = 0 }, "touch") :: string):find("Tap NET", 1, true) ~= nil).to.equal(
				true
			)
			expect((line({ step = 1 }, "gamepad") :: string):find("R2", 1, true) ~= nil).to.equal(
				true
			)
		end)

		it("follows step 2's and step 4's choices", function()
			expect(line({ step = 2, resting = true }, "keyboard")).to.equal(
				"Open Cats (C) and give your new cat a job"
			)
			expect((line({ step = 2 }, "keyboard") :: string):find("Upgrades", 1, true) ~= nil).to.equal(
				true
			)
			expect(line({ step = 4 }, "touch")).to.equal("Tap Upgrades and buy the Bait bowl")
			expect(line({ step = 4, bowl = true }, "keyboard")).to.equal(
				"Put Kibble in your bowl on the back step (F)"
			)
			expect(line({ step = 4, bowl = true, baited = true }, "gamepad")).to.equal(
				"A cat is on its way to your bowl"
			)
		end)

		it(
			"asks for another cat or the table at step 3 while only one cat is caught (#2912)",
			function()
				expect(line({ step = 3, cats = 1 }, "keyboard")).to.equal(
					"Catch another cat, or buy a table in Upgrades (U)"
				)
				expect(line({ step = 3, cats = 1 }, "touch")).to.equal(
					"Catch another cat, or tap Upgrades for a table"
				)
				expect(line({ step = 3, cats = 2 }, "keyboard")).to.equal(
					"Buy a table in Upgrades (U): more tips per cat"
				)
			end
		)

		it("has nothing once the first loop is done", function()
			expect(line({ step = 5 }, "keyboard")).to.equal(nil)
			expect(line({ step = 9 }, "touch")).to.equal(nil)
		end)
	end)

	describe("TutorialHints.resting", function()
		local spots = {
			{ id = "barista_1", tier = 1 },
			{ id = "waiter_1", tier = 1 },
			{ id = "chef_1", tier = 2 },
		}

		it("needs a resting cat and a free slot its tier opens", function()
			expect(TutorialHints.resting({ a = { spotId = "barista_1" }, b = {} }, spots, 1)).to.equal(
				true
			)
			expect(TutorialHints.resting({ a = { spotId = "barista_1" } }, spots, 1)).to.equal(
				false
			)
			expect(
				TutorialHints.resting(
					{ a = { spotId = "barista_1" }, b = { spotId = "waiter_1" }, c = {} },
					spots,
					1
				)
			).to.equal(false)
			expect(
				TutorialHints.resting(
					{ a = { spotId = "barista_1" }, b = { spotId = "waiter_1" }, c = {} },
					spots,
					2
				)
			).to.equal(true)
		end)

		it("is false with nothing to read", function()
			expect(TutorialHints.resting(nil, spots, 1)).to.equal(false)
			expect(TutorialHints.resting({ a = {} }, nil, 1)).to.equal(false)
		end)
	end)

	describe("TutorialHints.upgrade (#1796)", function()
		it("asks for a table at step 3 and the Bait bowl at step 4 until it is owned", function()
			expect(TutorialHints.upgrade(3, {})).to.equal("tables")
			expect(TutorialHints.upgrade(4, {})).to.equal("lure_bowl")
			expect(TutorialHints.upgrade(4, { lure_bowl = 1 })).to.equal(nil)
			expect(TutorialHints.upgrade(2, {})).to.equal(nil)
			expect(TutorialHints.upgrade(5, nil)).to.equal(nil)
			expect(TutorialHints.upgrade(nil, nil)).to.equal(nil)
		end)
	end)

	describe("TutorialHints.ask and view (#2697)", function()
		local spots = { { id = "barista", tier = 1 }, { id = "waiter", tier = 2 } }
		local function state(changes: { [string]: any }): any
			local out: { [string]: any } = {
				tutorialStep = 2,
				tier = 1,
				cats = { a = {} },
				upgradeLevels = {},
				bait = nil,
			}
			for key, value in changes do
				out[key] = value
			end
			return out
		end

		it("asks for a job while a new cat rests and a role is free", function()
			expect(TutorialHints.ask(TutorialHints.view(state({}), spots))).to.equal("job")
			local busy = state({ cats = { a = { spotId = "barista" } } })
			expect(TutorialHints.ask(TutorialHints.view(busy, spots))).to.equal("more")
		end)

		it("counts the cats caught for step 3 (#2912), not the cats in the cafe (#3022)", function()
			-- a new cafe after its first catch: the starter Tabby and the caught cat, one cat caught
			local one = state({
				tutorialStep = 3,
				cats = { starter = {}, a = {} },
				stats = { catsCaught = 1 },
			})
			expect(TutorialHints.ask(TutorialHints.view(one, spots))).to.equal("second")
			local two = state({
				tutorialStep = 3,
				cats = { starter = {}, a = {}, b = {} },
				stats = { catsCaught = 2 },
			})
			expect(TutorialHints.ask(TutorialHints.view(two, spots))).to.equal("table")
			-- a state with no stats (an older server) asks for the table alone
			expect(TutorialHints.ask(TutorialHints.view(state({ tutorialStep = 3 }), spots))).to.equal(
				"table"
			)
		end)

		it("asks for the bowl, then food in it, then waits", function()
			expect(TutorialHints.ask(TutorialHints.view(state({ tutorialStep = 4 }), spots))).to.equal(
				"bowl"
			)
			local owned = state({ tutorialStep = 4, upgradeLevels = { lure_bowl = 1 } })
			expect(TutorialHints.ask(TutorialHints.view(owned, spots))).to.equal("food")
			owned.bait = { readyAt = 10 }
			expect(TutorialHints.ask(TutorialHints.view(owned, spots))).to.equal("waiting")
			-- #3158: step 4 lasts until the first bowl cat is tamed or let go, so it says the cat is there
			owned.bait = { readyAt = 10, cat = { catId = "tabby" } }
			local view = TutorialHints.view(owned, spots)
			expect(TutorialHints.ask(view)).to.equal("arrived")
			expect(TutorialHints.line(view)).to.equal("Your bowl cat is here! Tame it")
		end)

		it("does not count a tamed bowl cat as a cat caught for step 3 (#3160)", function()
			local tamed = state({
				tutorialStep = 3,
				cats = { starter = {}, a = {}, b = {} },
				stats = { catsCaught = 2, baitsTamed = 1 },
			})
			expect(TutorialHints.ask(TutorialHints.view(tamed, spots))).to.equal("second")
		end)

		it(
			"offers the step's upgrade for one press only while the coins cover it (#2912)",
			function()
				local upgrades = {
					{ id = "tables", startLevel = 0, costs = { 150, 600 } },
					{ id = "lure_bowl", startLevel = 0, costs = { 600, 6000 } },
				}
				local offer = TutorialHints.offer(3, { tables = 0 }, 850, upgrades)
				expect(offer.id).to.equal("tables")
				expect(offer.cost).to.equal(150)
				expect(offer.text).to.equal("Buy a table")
				expect(TutorialHints.offer(3, { tables = 0 }, 149, upgrades)).to.equal(nil)
				local bowl = TutorialHints.offer(4, { tables = 1, lure_bowl = 0 }, 600, upgrades)
				expect(bowl.id).to.equal("lure_bowl")
				expect(bowl.cost).to.equal(600)
				-- the bowl owned, a step with no upgrade, an unknown balance or no catalog: no button
				expect(TutorialHints.offer(4, { lure_bowl = 1 }, 99999, upgrades)).to.equal(nil)
				for _, step in { 1, 2, 5 } do
					expect(TutorialHints.offer(step, {}, 99999, upgrades)).to.equal(nil)
				end
				expect(TutorialHints.offer(3, {}, nil, upgrades)).to.equal(nil)
				expect(TutorialHints.offer(3, {}, 850, nil)).to.equal(nil)
				-- a level past the price list (a save from a bigger list) is no offer
				expect(TutorialHints.offer(3, { tables = 2 }, 99999, upgrades)).to.equal(nil)
			end
		)

		it("asks for nothing once the walk-through is done, or with no step saved", function()
			expect(TutorialHints.ask(TutorialHints.view(state({ tutorialStep = 5 }), spots))).to.equal(
				nil
			)
			expect(TutorialHints.ask(TutorialHints.view(state({ tutorialStep = false }), spots))).to.equal(
				nil
			)
		end)
	end)
end
