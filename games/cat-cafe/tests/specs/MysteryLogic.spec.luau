--!strict
-- UI/Components/MysteryLogic.luau: Juniper's Mystery Market window rows (#2565, #2574).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local MysteryLogic = require(Components:WaitForChild("MysteryLogic")) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config")) :: any

	-- the launch week (the Backpack on sale), 2 h 30 m in
	local NOW = Config.MysteryEpoch + 9000

	local function state(fields: { [string]: any }?): any
		local out: { [string]: any } = {
			mystery = {},
			mysterySeen = false,
			mysteryOpen = true,
			goldenFish = 500,
			tier = 2,
		}
		for key, value in fields or {} do
			out[key] = value
		end
		return out
	end

	describe("MysteryLogic.view", function()
		it("puts this week's item on sale at the top and the rest at full price", function()
			local view = MysteryLogic.view(state(), NOW)
			expect(view.featured.id).to.equal("backpack")
			expect(view.featured.price).to.equal(300)
			expect(view.featured.full).to.equal(400)
			expect(view.featured.sale).to.equal(true)
			expect(view.featured.button).to.equal("300")
			expect(view.featured.enabled).to.equal(true)
			expect(#view.others).to.equal(1)
			expect(view.others[1].id).to.equal("long_net")
			expect(view.others[1].price).to.equal(320)
			expect(view.others[1].sale).to.equal(false)
			-- #3535: the Backpack's sale ends at Friday's update, 22:00 UTC, two hours before the week does
			expect(view.ends).to.equal("Sale ends in 6d 19h")
			expect(view.nextLine).to.equal("Next sale: 6d 19h")
		end)

		it("says owned, the tier, the fish or soon on the button and under it", function()
			local owned = MysteryLogic.view(state({ mystery = { backpack = true } }), NOW).featured
			expect(owned.button).to.equal("Owned")
			expect(owned.note).to.equal("You have this!")
			expect(owned.enabled).to.equal(false)
			local low = MysteryLogic.view(state({ tier = 1 }), NOW).others[1]
			expect(low.button).to.equal("Tier 2")
			expect(low.note).to.equal("Opens at Tier 2")
			expect(low.enabled).to.equal(false)
			local poor = MysteryLogic.view(state({ goldenFish = 299 }), NOW).featured
			expect(poor.button).to.equal("300")
			expect(poor.note).to.equal("Not enough golden fish")
			expect(poor.enabled).to.equal(false)
			local shut = MysteryLogic.view(state({ mysteryOpen = false }), NOW).featured
			expect(shut.button).to.equal("Soon")
			expect(shut.enabled).to.equal(false)
		end)

		it(
			"moves the sale on to the Speed Shoes with Friday's update, switch on (#3535)",
			function()
				local view = MysteryLogic.view(
					state(),
					NOW + Config.MysteryRotateSeconds,
					{ speedShoes = true }
				)
				expect(view.featured.id).to.equal("speed_shoes")
				expect(view.featured.price).to.equal(375)
				expect(view.featured.full).to.equal(500)
				expect(#view.others).to.equal(2)
				expect(view.others[1].id).to.equal("backpack")
				expect(view.others[1].price).to.equal(400)
				expect(view.others[2].id).to.equal("long_net")
			end
		)

		it("leaves the Speed Shoes off the shelf while their switch is off (#3535)", function()
			local view = MysteryLogic.view(state(), NOW + Config.MysteryRotateSeconds)
			expect(view.featured).to.equal(nil)
			expect(view.ends).to.equal(nil)
			expect(#view.others).to.equal(2)
			expect(view.others[1].id).to.equal("backpack")
			expect(view.others[1].price).to.equal(400)
			local now = MysteryLogic.view(state(), NOW)
			expect(now.featured.id).to.equal("backpack")
			expect(#now.others).to.equal(1)
		end)

		it("survives an empty state", function()
			local view = MysteryLogic.view(nil, NOW)
			expect(view.fish).to.equal(0)
			expect(view.featured.enabled).to.equal(false)
		end)
	end)

	describe("MysteryLogic.left", function()
		it("reads days and hours, hours and minutes, or minutes", function()
			expect(MysteryLogic.left(4 * 86400 + 6 * 3600 + 5)).to.equal("4d 06h")
			expect(MysteryLogic.left(6 * 3600 + 12 * 60)).to.equal("6h 12m")
			expect(MysteryLogic.left(30)).to.equal("1m")
		end)
	end)

	describe("MysteryLogic.bang", function()
		it("shows only until the first visit", function()
			expect(MysteryLogic.bang(state())).to.equal(MysteryLogic.BANG_TEXT)
			expect(MysteryLogic.bang(state({ mysterySeen = true }))).to.equal(nil)
			expect(MysteryLogic.bang(nil)).to.equal(nil)
		end)
	end)
end
