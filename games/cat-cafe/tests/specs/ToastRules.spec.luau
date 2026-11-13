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
			expect(ToastRules.quiet("Bought a Money Potion. It's in your potion bag.", "good")).to.equal(
				true
			)
			expect(ToastRules.quiet("Bought 5 foods for 12.4M coins", nil)).to.equal(true)
			expect(ToastRules.quiet("Bought Tuna (40)", "warn")).to.equal(false)
			expect(ToastRules.quiet("Not enough coins", "warn")).to.equal(false)
			expect(ToastRules.quiet("New piece: Lamp! Find it in Decor.", "good")).to.equal(false)
		end)
	end)

	describe("ToastRules.quiet cuts (#2729)", function()
		it("drops the nudges and the lines the screen already shows", function()
			for _, line in
				{
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
				}
			do
				expect(ToastRules.quiet(line, "info")).to.equal(true)
			end
		end)

		it("keeps what the player must act on and every warning", function()
			for _, line in
				{
					"You dropped Mochi. It's walking home.",
					"It held on tight!",
					"Try again! Tap as the circle closes.",
					"Walk closer to collect the tip",
				}
			do
				expect(ToastRules.quiet(line, "info")).to.equal(false)
			end
			expect(ToastRules.quiet("New quest: Catch 5 cats", "warn")).to.equal(false)
		end)
	end)

	describe("ToastRules.quiet for green toasts (#3080, #3054)", function()
		it("drops a catch, a claim, a reward, a drop and the rest", function()
			for _, line in
				{
					"New cat! Mochi joins the collection (+$50, 1 golden fish)",
					"The Mochi joined your cafe! It is resting in the cat room.",
					"Caught a cat!",
					"Town Index reward: $5,000, 2 Golden fish",
					"4 Index rewards: +$11.3M, +25 golden fish",
					"Daily Treat day 3: 2 Golden fish",
					"Gift! $1,200",
					"Tip Jar: $300",
					"Quest done: $500",
					"Cozy gift! Tuna x2",
					"Rescue Rally: 3 golden fish",
					"Fish Pond: +14 golden fish",
					"Spin Wheel: Luck Potion",
					"The cat dropped a snack: Tuna in your Bag",
					"Tuna in your Bag",
					"Mochi followed you home at dusk.",
					"Rich tip! +$1.2K",
					"Level up! Level 4",
					"Lamp placed (+2% tips)",
					"Renamed to Mochi",
					"Welcome back! +$1.2K while you were away",
					"Code redeemed!",
					"Saved!",
				}
			do
				expect(ToastRules.quiet(line, "good")).to.equal(true)
			end
		end)

		it(
			"keeps the receipts, a sent report, a finished trade and a crate result with no reveal",
			function()
				for _, line in ToastRules.KEEP do
					expect(type(line)).to.equal("string")
				end
				for _, line in
					{
						"Thank you! 3 Luck Potions",
						"Thank you! The Cafe Pass paid track is yours this season",
						"King Cat Pack: the Royal Velvet Booth, 2 Luck Potions",
						"👕 Your working cats now earn +15%!",
						"Thanks! Your report was sent.",
						"Trade done!",
						"Trade done! 2 new cats",
						"New piece: Lamp! Find it in Decor.",
						"Lamp again: +5 golden fish back",
						"Opened 10 crates: 4 new, +30 golden fish back",
						"Owner test mode: 3 Luck Potions",
						"Your bait cat is here! Head home to your bowl to meet it.",
						"It dropped! Pick it up quick!",
						-- #3106: a new player's first delivery and first cat are back
						"🧺 Mochi is on its way to your cafe!",
						"Your first cat! Mochi is your Waiter now ($2/s)",
						"Welcome back! Your cats earned $113K while you rested 💤", -- #3573
					}
				do
					expect(ToastRules.kept(line)).to.equal(true)
					expect(ToastRules.quiet(line, "good")).to.equal(false)
				end
			end
		)

		it("leaves info toasts and warnings to the older rules", function()
			expect(ToastRules.quiet("Trade cancelled", "info")).to.equal(false)
			expect(ToastRules.quiet("Your cats are already in their best roles.", "info")).to.equal(
				false
			)
			expect(ToastRules.quiet("Not enough coins", "warn")).to.equal(false)
			expect(ToastRules.quiet("Caught a cat!", "warn")).to.equal(false)
			expect(ToastRules.quiet("Hello", nil)).to.equal(false)
		end)
	end)

	describe("ToastRules.oneLine (#2729)", function()
		it("keeps good and info toasts to one row, and lets warnings wrap", function()
			expect(ToastRules.oneLine("good")).to.equal(true)
			expect(ToastRules.oneLine("info")).to.equal(true)
			expect(ToastRules.oneLine(nil)).to.equal(true)
			expect(ToastRules.oneLine("warn")).to.equal(false)
		end)

		it("lets every restart warning wrap, the calm early ones too (#3205)", function()
			local RestartNotice = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("RestartNotice")
			) :: any
			for _, seconds in RestartNotice.SHOWN do
				local text = RestartNotice.text(seconds)
				expect(ToastRules.oneLine(RestartNotice.kind(seconds), text)).to.equal(false)
			end
			expect(RestartNotice.kind(600)).to.equal("info")
			expect(ToastRules.oneLine("info", "Welcome back! Your cats missed you")).to.equal(true)
			-- #3212: an owner command's reply is a sentence, so it wraps too
			expect(
				ToastRules.oneLine(
					"info",
					"Owner test mode: Cafe Party started on all servers for 10 minutes"
				)
			).to.equal(false)
			expect(ToastRules.oneLine("good", "Claimed 3 quests")).to.equal(true)
		end)
	end)
end
