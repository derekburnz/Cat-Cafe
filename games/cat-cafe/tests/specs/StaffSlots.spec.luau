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
end
