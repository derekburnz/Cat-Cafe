--!strict
-- UI/Components/PerkCardLogic.luau: the station perk card's words (#2687 part 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PerkCardLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PerkCardLogic")
	) :: any
	local StationPerks = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("StationPerks")
	) :: any
	local LateTiers = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LateTiers")
	) :: any

	describe("PerkCardLogic.ICON", function()
		it("has a picture for every station perk", function()
			for _, perk in StationPerks.LIST do
				expect(PerkCardLogic.ICON[perk.id]).to.be.ok()
			end
		end)
	end)

	describe("PerkCardLogic.unlocked", function()
		it("names the station, the perk and its line", function()
			local view = PerkCardLogic.unlocked(StationPerks.get("haggler"))
			expect(view.station).to.equal("Yard Sale")
			expect(view.perk).to.equal("New perk: Haggler")
			expect(view.text).to.equal(StationPerks.get("haggler").text)
			expect(view.icon).to.equal(PerkCardLogic.ICON.haggler)
		end)

		it(
			"names the Mystic Pool for the Park's perk while the pool stands on the basket's spot (#3585)",
			function()
				local perk = StationPerks.get("fresh_bait")
				expect(PerkCardLogic.unlocked(perk).station).to.equal("Picnic Basket")
				expect(PerkCardLogic.unlocked(perk, false).station).to.equal("Picnic Basket")
				local view = PerkCardLogic.unlocked(perk, true)
				expect(view.station).to.equal("Mystic Pool")
				expect(view.icon).to.equal(PerkCardLogic.POOL_ICON)
				expect(view.perk).to.equal("New perk: Fresh Bait")
				expect(view.text).to.equal(perk.text)
				-- every other station keeps its own name
				expect(PerkCardLogic.unlocked(StationPerks.get("haggler"), true).station).to.equal(
					"Yard Sale"
				)
			end
		)
	end)

	describe("PerkCardLogic.list", function()
		it("shows only the first perk, locked, at Tier 1", function()
			local rows = PerkCardLogic.list(1)
			expect(#rows).to.equal(1)
			expect(rows[1].owned).to.equal(false)
			expect(rows[1].text).to.equal("Opens at Tier 2")
			expect(rows[1].title).to.equal("Picnic Basket perk")
		end)

		it("names the pool in Your perks and in the rank up teaser too", function()
			expect(PerkCardLogic.list(2)[1].title).to.equal("Fresh Bait · Picnic Basket")
			local rows = PerkCardLogic.list(2, true)
			expect(rows[1].title).to.equal("Fresh Bait · Mystic Pool")
			expect(rows[1].icon).to.equal(PerkCardLogic.POOL_ICON)
			expect(rows[2].title).to.equal("Yard Sale perk")
			expect(PerkCardLogic.list(1, true)[1].title).to.equal("Mystic Pool perk")
			local function has(text: string?, part: string): boolean
				return text ~= nil and string.find(text, part, 1, true) ~= nil
			end
			expect(has(PerkCardLogic.teaser(1, true), "Mystic Pool")).to.equal(true)
			expect(has(PerkCardLogic.teaser(1), "Picnic Basket")).to.equal(true)
			expect(has(PerkCardLogic.teaser(2, true), "Yard Sale")).to.equal(true)
		end)

		it("lists each owned perk then the next one locked", function()
			local rows = PerkCardLogic.list(4)
			expect(#rows).to.equal(4)
			for index = 1, 3 do
				expect(rows[index].owned).to.equal(true)
			end
			expect(rows[1].id).to.equal("fresh_bait")
			expect(rows[2].title).to.equal("Haggler · Yard Sale")
			expect(rows[4].owned).to.equal(false)
			expect(rows[4].icon).to.equal(PerkCardLogic.LOCK)
			expect(rows[4].text).to.equal("Opens at Tier 5")
		end)

		it("has no locked row once every perk is owned", function()
			local rows = PerkCardLogic.list(8) -- #3997: Tier 8's Cocoa Stand
			expect(#rows).to.equal(#StationPerks.LIST)
			for _, row in rows do
				expect(row.owned).to.equal(true)
			end
		end)
	end)

	describe("PerkCardLogic.teaser", function()
		it("names the next tier's station and perk", function()
			local line = PerkCardLogic.teaser(2)
			expect(line:find("Yard Sale", 1, true)).to.be.ok()
			expect(line:find("Haggler", 1, true)).to.be.ok()
		end)

		it("is nil at the top tier", function()
			expect(PerkCardLogic.teaser(8)).to.equal(nil)
		end)

		it("keeps Tier 8's Cocoa Stand back until the tier8 switch is on (#3997)", function()
			LateTiers.setOpen(false)
			expect(PerkCardLogic.teaser(7)).to.equal(nil)
			expect(#PerkCardLogic.list(7)).to.equal(#StationPerks.LIST - 1)
			LateTiers.setOpen(true)
			expect(PerkCardLogic.teaser(7):find("Cocoa Stand", 1, true)).to.be.ok()
			expect(#PerkCardLogic.list(7)).to.equal(#StationPerks.LIST)
			LateTiers.setOpen(nil)
		end)
	end)
end
