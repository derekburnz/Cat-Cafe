--!strict
-- UI/Components/CampExtrasLogic.bangShows: when the camp stations' red "!" (ReadyBang) shows
-- (camp-stations.md section 1; #1133, #1154, #1232).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CampExtrasLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CampExtrasLogic")
	) :: any

	local function state(picnic: number, yard: number, pond: number, pondOpen: boolean): any
		return {
			day = 20000,
			picnic = { open = true, held = picnic },
			yardSale = { open = true, held = yard },
			pond = { open = pondOpen, held = pond },
			lostFound = { open = false, held = 0 },
		}
	end

	describe("CampExtrasLogic.bangShows", function()
		it("shows over a station that holds something to claim", function()
			local s = state(1, 1, 14, true)
			expect(CampExtrasLogic.bangShows(s, "picnic")).to.equal(true)
			expect(CampExtrasLogic.bangShows(s, "yardSale")).to.equal(true)
			expect(CampExtrasLogic.bangShows(s, "pond")).to.equal(true)
		end)

		it("hides once claimed or while it refills", function()
			local s = state(0, 0, 0, true)
			expect(CampExtrasLogic.bangShows(s, "picnic")).to.equal(false)
			expect(CampExtrasLogic.bangShows(s, "yardSale")).to.equal(false)
			expect(CampExtrasLogic.bangShows(s, "pond")).to.equal(false)
		end)

		it("hides over a station the player hasn't opened, even holding something", function()
			expect(CampExtrasLogic.bangShows(state(0, 0, 6, false), "pond")).to.equal(false)
		end)

		it("shows nothing before the first state or for a broken one", function()
			expect(CampExtrasLogic.bangShows(nil, "picnic")).to.equal(false)
			expect(CampExtrasLogic.bangShows("x", "picnic")).to.equal(false)
			local text = { picnic = { open = true, held = "2" } }
			expect(CampExtrasLogic.bangShows(text, "picnic")).to.equal(false)
			expect(CampExtrasLogic.bangShows({}, "picnic")).to.equal(false)
		end)

		it("covers the three stations, not the Lost and Found", function()
			expect(#CampExtrasLogic.BANG_EXTRAS).to.equal(3)
			expect(table.find(CampExtrasLogic.BANG_EXTRAS, "lostFound")).to.equal(nil)
			expect(CampExtrasLogic.BANG_RANGE).to.equal(150)
		end)
	end)

	describe("CampExtrasLogic.remoteCollect (#1463)", function()
		it(
			"offers Collect on the pond strip only to a Golden Pond owner with fish waiting",
			function()
				local pond = {
					extraId = "pond",
					icon = "",
					name = "Fish Pond",
					state = "14 fish",
					ready = true,
				}
				expect(CampExtrasLogic.remoteCollect(pond, true)).to.equal(true)
				expect(CampExtrasLogic.remoteCollect(pond, false)).to.equal(false)
				local empty = table.clone(pond)
				empty.ready = false
				expect(CampExtrasLogic.remoteCollect(empty, true)).to.equal(false)
				local picnic = table.clone(pond)
				picnic.extraId = "picnic"
				expect(CampExtrasLogic.remoteCollect(picnic, true)).to.equal(false)
				expect(CampExtrasLogic.remoteCollect(nil, true)).to.equal(false)
				expect(CampExtrasLogic.GOLD_POND_ATTRIBUTE).to.equal("GoldenPondPass")
			end
		)
	end)
end
