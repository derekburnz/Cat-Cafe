--!strict
-- UI/Components/StaffSlots.luau: the Staff tab rows of Upgrades, one per role with its slots in opening order.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local StaffSlots = require(Components:WaitForChild("StaffSlots")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	local function byRole(rows: { any }): { [string]: any }
		local map = {}
		for _, row in rows do
			map[row.role] = row
		end
		return map
	end

	describe("StaffSlots.initial", function()
		it("takes the first whole letter, upper-cased", function()
			expect(StaffSlots.initial("mochi")).to.equal("M")
			expect(StaffSlots.initial("Émile")).to.equal("É")
			expect(StaffSlots.initial("ねこ")).to.equal("ね")
			expect(StaffSlots.initial("")).to.equal("?")
		end)
	end)

	describe("StaffSlots.rows", function()
		it("lists the four roles in catalog order with every slot", function()
			local rows = StaffSlots.rows(Catalog.spots, 1, {})
			expect(#rows).to.equal(4)
			expect(rows[1].name).to.equal("Barista")
			local total = 0
			for _, row in rows do
				total += #row.slots
			end
			expect(total).to.equal(#Catalog.spots)
		end)

		it("opens slots by tier and says when the next one opens", function()
			local roles = byRole(StaffSlots.rows(Catalog.spots, 1, {}))
			expect(roles.barista.open).to.equal(1)
			expect(roles.barista.locked).to.equal(2)
			expect(roles.barista.nextTier).to.equal(3)
			expect(roles.barista.summary).to.equal("1 free · next at Tier 3")
			expect(roles.greeter.open).to.equal(0)
			expect(roles.greeter.summary).to.equal("Opens at Tier 2")
			expect(roles.barista.slots[1].kind).to.equal("open")
			expect(roles.barista.slots[3].kind).to.equal("locked")
			expect(roles.barista.slots[3].tier).to.equal(5)
		end)

		it("marks the slots cats work as working, with the cat's uid", function()
			local cats = {
				a = { catId = "tabby", spotId = "barista_1" },
				b = { catId = "tuxedo", spotId = "waiter_1" },
				c = { catId = "calico" },
			}
			local roles = byRole(StaffSlots.rows(Catalog.spots, 1, cats))
			expect(roles.barista.working).to.equal(1)
			expect(roles.barista.slots[1].kind).to.equal("working")
			expect(roles.barista.slots[1].catUid).to.equal("a")
			expect(roles.barista.summary).to.equal("1 working · next at Tier 3")
		end)

		it("says All N working once every slot of a role is open and filled", function()
			local cats = {
				a = { catId = "tabby", spotId = "greeter_1" },
				b = { catId = "tuxedo", spotId = "greeter_2" },
			}
			local roles = byRole(StaffSlots.rows(Catalog.spots, 5, cats))
			expect(roles.greeter.summary).to.equal("All 2 working")
			expect(roles.greeter.nextTier).never.to.be.ok()
		end)

		it("counts opened slots as open when the cats are not known", function()
			local roles = byRole(StaffSlots.rows(Catalog.spots, 2, nil))
			expect(roles.waiter.open).to.equal(2)
			expect(roles.waiter.working).to.equal(0)
		end)
	end)

	-- QA (UI PR #173): the rows against Catalog.spots at every tier, empty and full.
	describe("QA edges", function()
		-- One row at `tier` with no cats: slots in tier order, locked above the tier, counts and summary agree.
		local function checkRow(row: any, tier: number, seen: { [string]: boolean })
			local soonest: number? = nil
			for index, slot in row.slots do
				expect(seen[slot.spotId]).never.to.be.ok()
				seen[slot.spotId] = true
				if index > 1 then
					expect(slot.tier >= row.slots[index - 1].tier).to.equal(true)
				end
				local locked = slot.tier > tier
				expect(slot.kind).to.equal(if locked then "locked" else "open")
				if locked and (soonest == nil or slot.tier < soonest) then
					soonest = slot.tier
				end
			end
			expect(row.working + row.open + row.locked).to.equal(#row.slots)
			expect(row.nextTier).to.equal(soonest)
			expect(row.summary ~= "").to.equal(true)
			if row.open == 0 and soonest ~= nil then
				expect(row.summary).to.equal(("Opens at Tier %d"):format(soonest))
			end
		end

		it("every tier: each spot once, in tier order, counts and summaries agree", function()
			for tier = 1, Catalog.maxTier do
				local seen: { [string]: boolean } = {}
				for _, row in StaffSlots.rows(Catalog.spots, tier, {}) do
					checkRow(row, tier, seen)
				end
				for _, spot in Catalog.spots do
					expect(seen[spot.id]).to.equal(true)
				end
			end
		end)

		it("a cat on every spot at the top tier: All N working, nothing next", function()
			local cats = {}
			for _, spot in Catalog.spots do
				cats["cat_" .. spot.id] = { catId = "tabby", spotId = spot.id }
			end
			for _, row in StaffSlots.rows(Catalog.spots, Catalog.maxTier, cats) do
				expect(row.summary).to.equal(("All %d working"):format(#row.slots))
				for _, slot in row.slots do
					expect(slot.catUid).to.equal("cat_" .. slot.spotId)
				end
			end
		end)

		-- #1624: Catalog.allSpots as Gameplay's #1652 builds it, the tier slots then two pass-only waiter slots
		local function allSpots(): { any }
			local list = table.clone(Catalog.spots)
			table.insert(list, { id = "waiter_4", spotType = "waiter", tier = 6, passOnly = true })
			table.insert(list, { id = "waiter_5", spotType = "waiter", tier = 6, passOnly = true })
			return list
		end

		it("hides the pass-only slots until extra slots open them (#1624)", function()
			local waiter = byRole(StaffSlots.rows(allSpots(), Catalog.maxTier, {}))
			local hidden = 0
			for _, slot in waiter.waiter.slots do
				if slot.hidden then
					hidden += 1
					expect(slot.kind).to.equal("locked")
				end
			end
			expect(hidden).to.equal(2)
			-- never "opens at Tier 6": the hidden slots stay out of the summary
			expect(waiter.waiter.summary:find("Tier 6")).to.equal(nil)
			expect(waiter.waiter.locked).to.equal(0)
			-- two extra slots at the top tier open both pass-only slots
			local extra = byRole(StaffSlots.rows(allSpots(), Catalog.maxTier, {}, 2)).waiter
			for _, slot in extra.slots do
				expect(slot.hidden).to.equal(nil)
				expect(slot.kind).to.equal("open")
			end
		end)

		it(
			"opens the next tier's slot early with an extra slot, as Catalog.slotIsOpen does (#1624)",
			function()
				local function openCount(rows: { any }): number
					local count = 0
					for _, row in rows do
						count += row.open + row.working
					end
					return count
				end
				local base = openCount(StaffSlots.rows(allSpots(), 1, {}))
				local plusOne = StaffSlots.rows(allSpots(), 1, {}, 1)
				expect(openCount(plusOne)).to.equal(base + 1)
				-- the slot opened early is the first spot past tier 1 in opening order
				local early: any = nil
				for _, spot in Catalog.spots do
					if spot.tier > 1 then
						early = spot
						break
					end
				end
				local found = false
				for _, row in plusOne do
					for _, slot in row.slots do
						if slot.spotId == early.id then
							found = true
							expect(slot.kind).to.equal("open")
						end
					end
				end
				expect(found).to.equal(true)
				-- without extra it matches the old tier rule
				expect(openCount(StaffSlots.rows(Catalog.spots, 2, {}))).to.equal(
					openCount(StaffSlots.rows(allSpots(), 2, {}, 0))
				)
			end
		)

		it("initial keeps a whole emoji or digit and upper-cases ASCII only", function()
			expect(StaffSlots.initial("\u{1F431}Mochi")).to.equal("\u{1F431}")
			expect(StaffSlots.initial("\u{1F44D}\u{1F3FD}")).to.equal("\u{1F44D}")
			expect(StaffSlots.initial("7up")).to.equal("7")
			expect(StaffSlots.initial("\u{E9}lan")).to.equal("\u{E9}")
			expect(StaffSlots.initial("z")).to.equal("Z")
		end)
	end)
end
