--!strict
-- UI/Components/CannonLogic.luau: the Cat Cannon picker's cards and buttons, its notice, the name card and the hints (F84).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CannonLogic = require(Components:WaitForChild("CannonLogic")) :: any
	local Catalog =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))

	local function ids(list: { any }): string
		local out = {}
		for _, destination in list do
			table.insert(out, destination.id)
		end
		return table.concat(out, ",")
	end

	describe("CannonLogic.destinations", function()
		it("lists only the areas the tier has opened, the Alleyway from Tier 1", function()
			expect(ids(CannonLogic.destinations(Catalog.areas, 1, "town"))).to.equal("alley")
			expect(ids(CannonLogic.destinations(Catalog.areas, 2, "town"))).to.equal("alley,park")
			expect(ids(CannonLogic.destinations(Catalog.areas, 5, "town"))).to.equal(
				"alley,park,neighbourhood,woods,sewer"
			)
		end)

		it("puts Town Square first from a camp and leaves out the camp's own area", function()
			expect(ids(CannonLogic.destinations(Catalog.areas, 3, "park"))).to.equal("town,alley,neighbourhood")
			expect(ids(CannonLogic.destinations(Catalog.areas, 1, "alley"))).to.equal("town")
			local town = CannonLogic.destinations(Catalog.areas, 1, "alley")[1]
			expect(town.name).to.equal("Town Square")
		end)

		it("sorts by tier and keeps the catalog order within a tier", function()
			local areas = {
				{ id = "b", name = "B", tier = 3 },
				{ id = "a", name = "A", tier = 2 },
				{ id = "c", name = "C", tier = 2 },
			}
			expect(ids(CannonLogic.destinations(areas, 5, "town"))).to.equal("a,c,b")
		end)
	end)

	describe("CannonLogic.moreToOpen", function()
		it("is true until the last area is open", function()
			expect(CannonLogic.moreToOpen(Catalog.areas, 1)).to.equal(true)
			expect(CannonLogic.moreToOpen(Catalog.areas, 4)).to.equal(true)
			expect(CannonLogic.moreToOpen(Catalog.areas, 5)).to.equal(false)
		end)
	end)

	describe("CannonLogic.button", function()
		it("shuts every card while carrying", function()
			expect(CannonLogic.button("park", false, false, true)).to.equal("carrying")
			expect(CannonLogic.button("town", true, false, true)).to.equal("carrying")
		end)

		it("shuts the areas at dusk and at night but never Town Square", function()
			expect(CannonLogic.button("park", false, false, false)).to.equal("launch")
			expect(CannonLogic.button("park", false, true, false)).to.equal("dusk")
			expect(CannonLogic.button("park", true, false, false)).to.equal("night")
			expect(CannonLogic.button("town", true, false, false)).to.equal("launch")
			expect(CannonLogic.button("town", false, true, false)).to.equal("launch")
		end)
	end)

	describe("CannonLogic.notice", function()
		it("says why Launch is off", function()
			expect(CannonLogic.notice(false, false, true, nil)).to.equal("Bring your cat to the camp first")
			expect(CannonLogic.notice(false, true, false, 12)).to.equal(
				"Night is coming. Launch opens again at sunrise."
			)
			expect(CannonLogic.notice(false, false, false, nil)).to.equal(nil)
		end)

		it("counts down to sunrise at night", function()
			expect(CannonLogic.notice(true, false, false, 160)).to.equal("Closed until sunrise · 2m 40s")
			expect(CannonLogic.notice(true, false, false, 159.2)).to.equal("Closed until sunrise · 2m 40s")
			expect(CannonLogic.notice(true, false, false, 45)).to.equal("Closed until sunrise · 45s")
			expect(CannonLogic.notice(true, false, false, -2)).to.equal("Closed until sunrise · 0s")
			expect(CannonLogic.notice(true, false, false, nil)).to.equal("Closed until sunrise")
		end)
	end)

	describe("CannonLogic name card", function()
		it("names the destination", function()
			expect(CannonLogic.cardTitle("woods", "Woods")).to.equal("To the Woods!")
			expect(CannonLogic.cardTitle("town", "Town Square")).to.equal("To Town Square!")
			expect(CannonLogic.cardSub("woods", "Woods")).to.equal("Landing at the Woods camp")
			expect(CannonLogic.cardSub("town", "Town Square")).to.equal("Landing in Town Square")
		end)

		it("pops in under the clouds and is gone before they part", function()
			expect(CannonLogic.cardPhase(0)).to.equal("waiting")
			expect(CannonLogic.cardPhase(1.59)).to.equal("waiting")
			expect(CannonLogic.cardPhase(1.6)).to.equal("in")
			expect(CannonLogic.cardPhase(2.1)).to.equal("wobble")
			expect(CannonLogic.cardPhase(2.45)).to.equal("out")
			expect(CannonLogic.cardPhase(2.6)).to.equal("gone")
		end)
	end)

	describe("CannonLogic.hint", function()
		local function view(changes: { [string]: any }): any
			local out: { [string]: any } = {
				on = true,
				wild = false,
				intro = false,
				launched = false,
				tier = 1,
				tutorialStep = 0,
				told = true,
				opened = nil,
				first = "Alleyway",
			}
			for key, value in changes do
				out[key] = value
			end
			return out
		end

		it("sends a Tier 1 player to the Alleyway until the first flight", function()
			expect(CannonLogic.hint(view({}))).to.equal("Hop in the cannon to fly to the Alleyway!")
			expect(CannonLogic.hint(view({ launched = true }))).to.equal(nil)
			expect(CannonLogic.hint(view({ tier = 3 }))).to.equal(nil)
		end)

		it("shows only in town, outside the intro, with the cannon live", function()
			expect(CannonLogic.hint(view({ wild = true }))).to.equal(nil)
			expect(CannonLogic.hint(view({ intro = true }))).to.equal(nil)
			expect(CannonLogic.hint(view({ on = false }))).to.equal(nil)
		end)

		it("names the area the rank up to Tier 2 opened", function()
			expect(CannonLogic.hint(view({ tier = 2, launched = true, opened = "Park", told = false }))).to.equal(
				"The Park is open! Hop in the cannon to fly there."
			)
		end)

		it("lets the onboarding line come first after the first catch", function()
			expect(CannonLogic.hint(view({ tutorialStep = 4 }))).to.equal(nil)
			expect(CannonLogic.hint(view({ tutorialStep = 4, told = false }))).to.equal(
				"Hop in the cannon to fly to the Alleyway!"
			)
			expect(CannonLogic.hint(view({ tutorialStep = 1 }))).to.equal("Hop in the cannon to fly to the Alleyway!")
		end)
	end)
end
