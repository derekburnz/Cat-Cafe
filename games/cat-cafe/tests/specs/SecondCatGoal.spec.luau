--!strict
-- UI/Components/SecondCatGoal.luau (#3022): the goal card's words while the cafe waits for its second cat.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local SecondCatGoal = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("SecondCatGoal")
	) :: any

	-- a new Tier 1 cafe after its first customer: both jobs taken, so the two rates are equal
	local function full(changes: { [string]: any }?): any
		local state: { [string]: any } = {
			secondCat = { now = 2.5, with = 2.5, cats = 1, bonus = 50 },
		}
		for key, value in changes or {} do
			state[key] = value
		end
		return state
	end

	describe("SecondCatGoal.view", function()
		it("is nothing without the server's secondCat", function()
			expect(SecondCatGoal.view({}, true, "Cozy Cafe")).to.equal(nil)
			expect(SecondCatGoal.view(nil, true, "Cozy Cafe")).to.equal(nil)
			expect(SecondCatGoal.view({ carrying = "tuxedo" }, true, "Cozy Cafe")).to.equal(nil)
		end)

		it(
			"keeps the card while a cat is carried, sending it home (no flip to the tier goal)",
			function()
				for _, narrow in { true, false } do
					for _, open in { true, false } do
						local view: any = SecondCatGoal.view(
							full({ carrying = "tuxedo" }),
							narrow,
							"Cozy Cafe",
							open
						)
						expect(view).to.deepEqual({
							title = "Bring your cat to the camp 🐾",
							lines = {},
							chip = "Bring your cat to the camp 🐾",
						})
					end
				end
			end
		)

		it("is the goal with its count, and no hook line on a narrow card", function()
			local view = SecondCatGoal.view(full(), true, "Cozy Cafe")
			expect(view.title).to.equal("Catch a 2nd cat 🐾 1/2")
			expect(view.chip).to.equal("Catch a 2nd cat 🐾 1/2")
			expect(view.hook).to.equal(nil)
		end)

		it("names the new-cat bonus under it on a wide card, the server's number", function()
			local view = SecondCatGoal.view(full(), false, "Cozy Cafe")
			expect(view.title).to.equal("Catch a 2nd cat 🐾 1/2")
			expect(view.hook).to.equal("New cats pay +$50 💰")
			expect(view.chip).to.equal("Catch a 2nd cat 🐾 1/2")
			local dear = full()
			dear.secondCat.bonus = 300
			expect(SecondCatGoal.view(dear, false, "Cozy Cafe").hook).to.equal(
				"New cats pay +$300 💰"
			)
		end)

		it("previews the bonus and the step toward the next tier", function()
			expect(SecondCatGoal.view(full(), false, "Cozy Cafe").lines).to.deepEqual({
				"New kind of cat: +$50",
				"and 1 step closer to Cozy Cafe",
			})
			expect(SecondCatGoal.view(full(), true, "Cozy Cafe").lines).to.deepEqual({
				"New kind of cat: +$50",
				"1 step closer to Cozy Cafe",
			})
			expect(SecondCatGoal.view(full(), true, nil).lines).to.deepEqual({
				"New kind of cat: +$50",
			})
		end)

		it(
			"says when the strays come back while the areas are shut, on every card (#3238)",
			function()
				for _, narrow in { true, false } do
					local view = SecondCatGoal.view(full(), narrow, "Cozy Cafe", false)
					expect(view.title).to.equal("Catch a 2nd cat 🐾 1/2")
					expect(view.hook).to.equal(
						if narrow
							then "Next cat at sunrise 🌅"
							else "Strays come back at sunrise 🌅"
					)
					expect(view.lines :: any).to.deepEqual({})
				end
				-- open (or not known) reads as before
				expect(SecondCatGoal.view(full(), false, "Cozy Cafe", true).hook).to.equal(
					"New cats pay +$50 💰"
				)
				expect(SecondCatGoal.view(full(), true, "Cozy Cafe", true).hook).to.equal(nil)
			end
		)

		it("never says 2x or a rate while both jobs are taken", function()
			for _, narrow in { true, false } do
				local view = SecondCatGoal.view(full(), narrow, "Cozy Cafe")
				local words: { string } = { view.title, view.hook or "", view.chip }
				for _, line in view.lines do
					table.insert(words, line)
				end
				for _, line in words do
					expect(line:find("2x", 1, true)).to.equal(nil)
					expect(line:find("/s", 1, true)).to.equal(nil)
				end
			end
		end)

		it("says 2x and both rates only when a free job backs them", function()
			local state = full()
			state.secondCat = { now = 1.5, with = 3, cats = 1, bonus = 50 }
			local wide = SecondCatGoal.view(state, false, "Cozy Cafe")
			expect(wide.title).to.equal("Catch a 2nd cat 🐾 1/2")
			expect(wide.hook).to.equal("2 cats earn 2x 💰")
			expect(wide.lines).to.deepEqual({ "Now +$1.5/s", "with 2 cats +$3/s" })
			local narrow = SecondCatGoal.view(state, true, "Cozy Cafe")
			expect(narrow.hook).to.equal(nil)
			expect(narrow.lines).to.deepEqual({ "Now +$1.5/s", "with 2 cats +$3/s" })
			-- more, but not double: no "2x"
			state.secondCat = { now = 1.5, with = 2.5, cats = 1, bonus = 50 }
			local more = SecondCatGoal.view(state, false, "Cozy Cafe")
			expect(more.hook).to.equal("2 cats earn more 💰")
			expect(more.lines).to.deepEqual({ "Now +$1.5/s", "with 2 cats +$2.5/s" })
		end)

		it("keeps the goal alone when the numbers are missing or bad", function()
			local state = full()
			state.secondCat = { cats = 1 }
			local view = SecondCatGoal.view(state, false, "Cozy Cafe")
			expect(view.title).to.equal("Catch a 2nd cat 🐾 1/2")
			expect(view.hook).to.equal(nil)
			expect(#view.lines).to.equal(0)
			state.secondCat = { now = 0 / 0, with = -4, cats = 9, bonus = -1 }
			view = SecondCatGoal.view(state, false, "Cozy Cafe")
			expect(view.title).to.equal("Catch a 2nd cat 🐾 1/2")
			expect(view.hook).to.equal(nil)
		end)

		it("agrees with the server's numbers", function()
			local SecondCat =
				require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SecondCat)
			expect(SecondCatGoal.NEED).to.equal(SecondCat.CATS)
			expect(SecondCatGoal.PREVIEW_SECONDS).to.equal(SecondCat.PREVIEW_SECONDS)
			expect(SecondCatGoal.NUDGE_SECONDS).to.equal(SecondCat.NUDGE_SECONDS)
		end)
	end)
end
