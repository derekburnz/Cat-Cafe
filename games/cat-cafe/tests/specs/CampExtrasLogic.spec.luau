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
			view.held = 1
			expect(CampExtrasLogic.yardFooter(view, NOW)).to.equal("A free crate is waiting") -- #1154
			view.held = 0
			expect(CampExtrasLogic.yardFooter(view, NOW)).to.equal("New crate soon")
			expect(CampExtrasLogic.yardFooter(shut(), NOW)).to.equal("Opens at Tier 3")
		end)
	end)

	describe("CampExtrasLogic.yardOddsLines", function()
		it("lists the crate's rarities Common first with Market percents (#1051)", function()
			local lines = CampExtrasLogic.yardOddsLines({
				Mythical = 0.5,
				Common = 60,
				Rare = 27,
				Epic = 10,
				Legendary = 2.5,
			})
			expect(#lines).to.equal(5)
			expect(lines[1].rarity).to.equal("Common")
			expect(lines[1].text).to.equal("60%")
			expect(lines[4].text).to.equal("2.5%")
			expect(lines[5].rarity).to.equal("Mythical")
			expect(lines[5].text).to.equal("0.5%")
		end)

		it("leaves out a rarity the crate never gives, and copes with no odds", function()
			local lines = CampExtrasLogic.yardOddsLines({ Common = 0, Epic = 80, Legendary = 20 })
			expect(#lines).to.equal(2)
			expect(lines[1].rarity).to.equal("Epic")
			expect(#CampExtrasLogic.yardOddsLines(nil)).to.equal(0)
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
	describe(
		"CampExtrasLogic.binLine and withBin (the Rummage Bin on the Cat Cannon card)",
		function()
			it(
				"shows Ready with the dot while the bin is full, Empty for now while it waits, never a countdown",
				function()
					local full = CampExtrasLogic.binLine("alley", NOW - 1, NOW, true)
					expect(full.name).to.equal("Rummage Bin")
					expect(full.state).to.equal("Ready")
					expect(full.ready).to.equal(true)
					expect(CampExtrasLogic.binLine("alley", nil, NOW, true).ready).to.equal(true)
					local empty = CampExtrasLogic.binLine("alley", NOW + 600, NOW, true)
					expect(empty.state).to.equal("Empty for now")
					expect(empty.ready).to.equal(false)
					expect(string.find(empty.state, "%d")).to.equal(nil)
				end
			)

			it("is only on the bin's own area, and gone while the bin is switched off", function()
				expect(CampExtrasLogic.binLine("park", NOW - 1, NOW, true)).to.equal(nil)
				expect(CampExtrasLogic.binLine("town", NOW - 1, NOW, true)).to.equal(nil)
				expect(CampExtrasLogic.binLine("alley", NOW - 1, NOW, false)).to.equal(nil)
			end)

			it("has no button: the bin is played at the bin", function()
				expect(
					CampExtrasLogic.remoteAction(
						CampExtrasLogic.binLine("alley", NOW - 1, NOW, true)
					)
				).to.equal(nil)
			end)

			it(
				"gives the card's one line to the station unless only the bin has something waiting",
				function()
					local bin = CampExtrasLogic.binLine("alley", NOW - 1, NOW, true)
					local waiting = CampExtrasLogic.binLine("alley", NOW + 60, NOW, true)
					local station = {
						extraId = "picnic",
						icon = "x",
						name = "Picnic Basket",
						state = "Next in 2 h",
						ready = false,
					}
					local stationReady = {
						extraId = "picnic",
						icon = "x",
						name = "Picnic Basket",
						state = "1 ready",
						ready = true,
					}
					expect(CampExtrasLogic.withBin(nil, bin)).to.equal(bin)
					expect(CampExtrasLogic.withBin(nil, nil)).to.equal(nil)
					expect(CampExtrasLogic.withBin(station, nil)).to.equal(station)
					expect(CampExtrasLogic.withBin(station, bin)).to.equal(bin)
					expect(CampExtrasLogic.withBin(stationReady, bin)).to.equal(stationReady)
					expect(CampExtrasLogic.withBin(station, waiting)).to.equal(station)
				end
			)
		end
	)
end
