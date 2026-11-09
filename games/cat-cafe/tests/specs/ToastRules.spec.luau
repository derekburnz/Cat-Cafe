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
end
