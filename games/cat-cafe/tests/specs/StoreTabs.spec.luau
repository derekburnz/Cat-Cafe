--!strict
-- StoreTabs.luau (#1842): the Store tabs' versions, the saved storeSeen made whole, and which tabs show "New".
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ProfileSchema = require(Shared.ProfileSchema)
	local StoreTabs = require(Shared.StoreTabs)

	describe("StoreTabs", function()
		it("knows the Store's tab ids and gives each a version from 1", function()
			for _, id in { "featured", "passes", "cats", "potions", "cafePass", "codes" } do
				expect(StoreTabs.isTab(id)).to.equal(true)
				expect(StoreTabs.VERSIONS[id] >= 1).to.equal(true)
			end
			expect(StoreTabs.isTab("shop")).to.equal(false)
			expect(StoreTabs.isTab(3)).to.equal(false)
			expect(StoreTabs.isTab(nil)).to.equal(false)
		end)

		it("shows every tab as new on a fresh save, and clears a tab once it is opened", function()
			local seen = ProfileSchema.template(1000).storeSeen
			expect(next(seen)).to.equal(nil)
			expect(StoreTabs.unseen(seen).cats).to.equal(true)
			expect(StoreTabs.markSeen(seen, "cats")).to.equal(true)
			expect(seen.cats).to.equal(StoreTabs.VERSIONS.cats)
			expect(StoreTabs.unseen(seen).cats).to.equal(nil)
			expect(StoreTabs.unseen(seen).passes).to.equal(true)
			-- opening it again changes nothing, and an unknown tab is refused
			expect(StoreTabs.markSeen(seen, "cats")).to.equal(false)
			expect(StoreTabs.markSeen(seen, "nope")).to.equal(false)
			expect(StoreTabs.markSeen(seen, {})).to.equal(false)
			expect(seen.nope).to.equal(nil)
		end)

		it("keeps only known tabs with whole versions up to the current one", function()
			local kept = StoreTabs.sanitize({
				cats = StoreTabs.VERSIONS.cats,
				passes = 999,
				potions = 0,
				codes = 0 / 0,
				featured = "1",
				junk = 1,
				[5] = 1,
			})
			expect(kept :: any).to.deepEqual({
				cats = StoreTabs.VERSIONS.cats,
				passes = StoreTabs.VERSIONS.passes,
			})
			expect(next(StoreTabs.sanitize("x"))).to.equal(nil)
		end)

		it("is kept through a save", function()
			local raw = ProfileSchema.template(1000) :: any
			raw.storeSeen = { cats = 1, junk = 4 }
			local profile = ProfileSchema.migrate(raw, 1000) :: any
			expect(profile.storeSeen :: any).to.deepEqual({ cats = 1 })
		end)
	end)
end
