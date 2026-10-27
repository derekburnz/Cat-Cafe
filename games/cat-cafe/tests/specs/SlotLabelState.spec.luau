--!strict
-- UI/Components/SlotLabelState.luau: the labels over your own cafe's role slots (data-model section 5).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local SlotLabelState = require(Components:WaitForChild("SlotLabelState")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	local function count(labels: { [string]: any }, kind: string): number
		local n = 0
		for _, label in labels do
			if label.kind == kind then
				n += 1
			end
		end
		return n
	end

	describe("SlotLabelState.labels, locked slots", function()
		it("labels the next locked slot of each role, four at Tier 1", function()
			local labels = SlotLabelState.labels(Catalog.spots, 1, nil)
			expect(count(labels, "locked")).to.equal(4)
			expect(count(labels, "open")).to.equal(0)
			expect(labels.waiter_2.sub).to.equal("Opens at Tier 2")
			expect(labels.greeter_1.title).to.equal("Greeter")
			expect(labels.barista_2.sub).to.equal("Opens at Tier 3")
			expect(labels.entertainer_1.tappable).to.equal(false)
			expect(labels.waiter_3).never.to.be.ok()
		end)

		it("moves on to the next slot of a role after a rank up", function()
			local labels = SlotLabelState.labels(Catalog.spots, 3, nil)
			expect(labels.barista_2).never.to.be.ok()
			expect(labels.barista_3.sub).to.equal("Opens at Tier 5")
			expect(labels.waiter_3.sub).to.equal("Opens at Tier 4")
		end)

		it("labels nothing at the top tier with every slot working", function()
			expect(next(SlotLabelState.labels(Catalog.spots, 5, nil))).never.to.be.ok()
		end)
	end)

	describe("SlotLabelState.labels, free slots", function()
		it("labels a free slot of a role in place of its locked one", function()
			local cats = { b = { uid = "b", catId = "tabby" } }
			local labels = SlotLabelState.labels(Catalog.spots, 1, cats)
			expect(labels.waiter_1.kind).to.equal("open")
			expect(labels.waiter_1.title).to.equal("Waiter")
			expect(labels.waiter_1.sub).to.equal("Tap to add a cat")
			expect(labels.waiter_1.tappable).to.equal(true)
			expect(labels.waiter_2).never.to.be.ok()
			expect(labels.greeter_1.kind).to.equal("locked")
		end)

		it("skips a slot a cat works and counts the free ones", function()
			local cats = {
				a = { uid = "a", catId = "tabby", spotId = "barista_1" },
				b = { uid = "b", catId = "tabby" },
			}
			local labels = SlotLabelState.labels(Catalog.spots, 3, cats)
			expect(labels.barista_1).never.to.be.ok()
			expect(labels.barista_2.sub).to.equal("Tap to add a cat")
			expect(labels.waiter_1.sub).to.equal("2 free · tap to add cats")
			expect(labels.waiter_2).never.to.be.ok()
		end)

		it("asks for a catch when every cat has a role", function()
			local cats = { a = { uid = "a", catId = "tabby", spotId = "barista_1" } }
			local labels = SlotLabelState.labels(Catalog.spots, 1, cats)
			expect(labels.waiter_1.sub).to.equal("Catch a cat for it")
			expect(labels.waiter_1.tappable).to.equal(false)
		end)

		it("labels no free slot while the cats are unknown", function()
			local labels = SlotLabelState.labels(Catalog.spots, 3, nil)
			expect(count(labels, "open")).to.equal(0)
		end)
	end)
end
