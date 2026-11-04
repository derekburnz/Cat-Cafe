--!strict
-- UI/Components/CampExtrasLogic.luau: the Cat Cannon card's camp extra strip, the Yard Sale card's rows and the
-- prize toast's line (F100, camp-extras.md sections 2 and 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CampExtrasLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CampExtrasLogic")
	) :: any

	local NOW = 1_800_000_000

	local function shut(): any
		return { open = false, held = 0 }
	end

	-- a Tier 3 player's state: the Picnic Basket and the Yard Sale open, the Pond and the Lost and Found shut
	local function tier3(picnicHeld: number, yardBought: boolean): any
		return {
			day = math.floor(NOW / 86400),
			picnic = {
				open = true,
				held = picnicHeld,
				nextAt = if picnicHeld < 2 then NOW + 7800 else nil,
			},
			yardSale = {
				open = true,
				held = if yardBought then 0 else 2,
				nextAt = NOW + 3 * 3600,
				stock = {
					{ crateId = "park_crate", price = 0, bought = yardBought }, -- #1051: one free crate
				},
			},
			pond = shut(),
			lostFound = shut(),
		}
	end

	describe("CampExtrasLogic.icon", function()
		it("gives each extra its glyph and a gift for anything else", function()
			expect(CampExtrasLogic.icon("picnic")).to.equal("🧺")
			expect(CampExtrasLogic.icon("yardSale")).to.equal("🏷️")
			expect(CampExtrasLogic.icon("pond")).to.equal("🎣")
			expect(CampExtrasLogic.icon("lostFound")).to.equal("📦")
			expect(CampExtrasLogic.icon("other")).to.equal("🎁")
		end)
	end)

	describe("CampExtrasLogic.pickerLine", function()
		it(
			"splits the shared line into the name and what waits, with the red dot when it is ready",
			function()
				local line = CampExtrasLogic.pickerLine(tier3(1, false), "park", NOW)
				expect(line.extraId).to.equal("picnic")
				expect(line.icon).to.equal("🧺")
				expect(line.name).to.equal("Picnic Basket")
				expect(line.state).to.equal("1 ready")
				expect(line.ready).to.equal(true)
			end
		)

		it("shows the wait with no dot while nothing is ready", function()
			local line = CampExtrasLogic.pickerLine(tier3(0, false), "park", NOW)
			expect(line.state).to.equal("Next in 2 h 10 m")
			expect(line.ready).to.equal(false)
		end)

		it("words the Yard Sale's free crate, with the red dot while it waits (#1051)", function()
			local fresh = CampExtrasLogic.pickerLine(tier3(0, false), "neighbourhood", NOW)
			expect(fresh.name).to.equal("Yard Sale")
			expect(fresh.state).to.equal("Free crate")
			expect(fresh.ready).to.equal(true)
			local sold = CampExtrasLogic.pickerLine(tier3(0, true), "neighbourhood", NOW)
			expect(sold.state).to.equal("New crate in 3 h")
			expect(sold.ready).to.equal(false)
		end)

		it(
			"shows nothing for an area with no extra, a shut extra or before the first state",
			function()
				expect(CampExtrasLogic.pickerLine(tier3(1, false), "alley", NOW)).to.equal(nil)
				expect(CampExtrasLogic.pickerLine(tier3(1, false), "woods", NOW)).to.equal(nil)
				expect(CampExtrasLogic.pickerLine(nil, "park", NOW)).to.equal(nil)
			end
		)
	end)

	describe("CampExtrasLogic Yard Sale card", function()
		it("lists today's one free crate, which any player can take (#1051)", function()
			local rows = CampExtrasLogic.yardRows(tier3(0, false).yardSale, 0)
			expect(#rows).to.equal(1)
			expect(rows[1].crateId).to.equal("park_crate")
			expect(rows[1].afford).to.equal(true)
			expect(#CampExtrasLogic.yardRows(shut(), 100)).to.equal(0)
			expect(#CampExtrasLogic.yardRows(nil, 100)).to.equal(0)
		end)

		it("words the button: Take, Taken once taken, ... while a take is out (#1051)", function()
			local rows = CampExtrasLogic.yardRows(tier3(0, false).yardSale, 0)
			expect(CampExtrasLogic.yardButton(rows[1], false)).to.equal("Take")
			expect(CampExtrasLogic.yardButton(rows[1], true)).to.equal("...")
			local taken = CampExtrasLogic.yardRows(tier3(0, true).yardSale, 0)
			expect(CampExtrasLogic.yardButton(taken[1], true)).to.equal("Taken")
			expect(
				CampExtrasLogic.yardButton(
					{ crateId = "x", price = 40, bought = false, afford = true },
					false
				)
			).to.equal("40")
		end)

		it("says when the next crates come", function()
			local view = tier3(0, false).yardSale
			view.nextAt = NOW + 3 * 3600 + 600
			expect(CampExtrasLogic.yardFooter(view, NOW)).to.equal("New crate in 3 h 10 m")
			view.nextAt = nil
			expect(CampExtrasLogic.yardFooter(view, NOW)).to.equal("New crate tomorrow")
			expect(CampExtrasLogic.yardFooter(shut(), NOW)).to.equal("Opens at Tier 3")
		end)
	end)

	describe("CampExtrasLogic.prizeTitle", function()
		it("names the extra and what it paid in the server's words", function()
			expect(CampExtrasLogic.prizeTitle("pond", { "+14 golden fish" })).to.equal(
				"Fish Pond: +14 golden fish"
			)
			expect(CampExtrasLogic.prizeTitle("lostFound", { "1 Lucky Potion", "+10 golden fish" })).to.equal(
				"Lost and Found: 1 Lucky Potion, +10 golden fish"
			)
			expect(CampExtrasLogic.prizeTitle("yardSale", { "1 Park Crate" })).to.equal(
				"Yard Sale: 1 Park Crate"
			)
			expect(CampExtrasLogic.prizeTitle("picnic", {})).to.equal("Picnic Basket")
			expect(CampExtrasLogic.prizeTitle("picnic", nil)).to.equal("Picnic Basket")
		end)
	end)
end
