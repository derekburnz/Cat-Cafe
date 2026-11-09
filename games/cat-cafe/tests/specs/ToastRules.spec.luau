--!strict
-- UI/Components/ToastRules.luau: which toasts and shout-outs still show (#2399).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ToastRules = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ToastRules")
	) :: any

	describe("ToastRules.announce", function()
		it("drops Epic and lower shout-outs and keeps Legendary and better", function()
			expect(ToastRules.announce("Epic", 100, nil, false)).to.equal(false)
			expect(ToastRules.announce("Rare", 100, nil, true)).to.equal(false)
			expect(ToastRules.announce("Legendary", 100, nil, false)).to.equal(true)
			expect(ToastRules.announce("Mythical", 100, nil, true)).to.equal(true)
		end)

		it("keeps one with no rarity or an unknown kind (a rank up, a pity cat)", function()
			expect(ToastRules.announce(nil, 100, 99, true)).to.equal(true)
			expect(ToastRules.announce("legendaryPity", 100, 99, true)).to.equal(true)
		end)

		it("shows one Legendary every ANNOUNCE_GAP seconds on touch, Mythical always", function()
			local gap = ToastRules.ANNOUNCE_GAP
			expect(ToastRules.announce("Legendary", 100, 100 - gap + 1, true)).to.equal(false)
			expect(ToastRules.announce("Legendary", 100, 100 - gap, true)).to.equal(true)
			expect(ToastRules.announce("Legendary", 100, 99, false)).to.equal(true)
			expect(ToastRules.announce("Mythical", 100, 99, true)).to.equal(true)
		end)
	end)

	describe("ToastRules.isRepeat", function()
		it("drops the same words within REPEAT_SECONDS, never a warning", function()
			local seconds = ToastRules.REPEAT_SECONDS
			expect(ToastRules.isRepeat("good", 100, 100 - seconds + 1)).to.equal(true)
			expect(ToastRules.isRepeat("info", 100, 100 - seconds)).to.equal(false)
			expect(ToastRules.isRepeat("good", 100, nil)).to.equal(false)
			expect(ToastRules.isRepeat("warn", 100, 99)).to.equal(false)
		end)
	end)

	describe("ToastRules.maxVisible", function()
		it("keeps two on a phone and three on a PC", function()
			expect(ToastRules.maxVisible(true)).to.equal(2)
			expect(ToastRules.maxVisible(false)).to.equal(3)
		end)
	end)

	describe("ToastRules.quiet (#2600)", function()
		it("drops the purchase confirmations and keeps refusals and other toasts", function()
			expect(ToastRules.quiet("Bought Tuna (40)", "good")).to.equal(true)
			expect(ToastRules.quiet("Bought a Money Potion. It's in your potion bag.", "good")).to.equal(true)
			expect(ToastRules.quiet("Bought 5 foods for 12.4M coins", nil)).to.equal(true)
			expect(ToastRules.quiet("Bought Tuna (40)", "warn")).to.equal(false)
			expect(ToastRules.quiet("Not enough coins", "warn")).to.equal(false)
			expect(ToastRules.quiet("New piece: Lamp! Find it in Decor.", "good")).to.equal(false)
		end)
	end)

	describe("ToastRules.quiet cuts (#2729)", function()
		it("drops the nudges and the lines the screen already shows", function()
			for _, line in {
				"New quest: Catch 5 cats",
				"A cheap Rare Crate at the Fish Market!",
				"Luck Potions at the Fish Market!",
				"Something good at the Fish Market!",
				"🌙 Night bait! Food in your bowl now brings a cat in half the time.",
				"Bait food is at the Corner Shop now",
				"🧺 Pirate Cat is on its way to your cafe!",
				"You dropped Mochi.",
				"Mochi ran back to the Park.",
				"You got tackled!",
			} do
				expect(ToastRules.quiet(line, "info")).to.equal(true)
			end
		end)

		it("keeps what the player must act on, the rewards and every warning", function()
			for _, line in {
				"You dropped Mochi. It's walking home.",
				"It held on tight!",
				"It dropped! Pick it up quick!",
				"Town Index reward: $5,000, 2 Golden fish",
				"Try again! Tap as the circle closes.",
				"Walk closer to collect the tip",
				"Welcome back! +$1.2K while you were away",
			} do
				expect(ToastRules.quiet(line, "good")).to.equal(false)
			end
			expect(ToastRules.quiet("New quest: Catch 5 cats", "warn")).to.equal(false)
		end)
	end)

	describe("ToastRules.oneLine (#2729)", function()
		it("keeps good and info toasts to one row, and lets warnings wrap", function()
			expect(ToastRules.oneLine("good")).to.equal(true)
			expect(ToastRules.oneLine("info")).to.equal(true)
			expect(ToastRules.oneLine(nil)).to.equal(true)
			expect(ToastRules.oneLine("warn")).to.equal(false)
		end)
	end)
end
