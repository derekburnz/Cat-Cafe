--!strict
-- GrandOpening.luau against first-hour.md section 1 (#1893): the eight milestones and their prizes, each read from
-- the profile, the strip's start at tutorialStep 5, a save already at Tier 3 finished at once, and #1897's save mark.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Economy = require(Shared.Economy)
	local ChatTags = require(Shared.ChatTags)
	local GrandOpening = require(Shared.GrandOpening)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 1_800_000_000

	local function fresh(): any
		local profile: any = ProfileSchema.template(NOW)
		profile.tutorialStep = 5
		profile.upgradeLevels.tables = 0
		return profile
	end

	-- `count` cats of distinct ids from `area` (or any area when nil) added to the collection
	local function collect(profile: any, count: number, area: string?)
		local added = 0
		for _, def in Catalog.cats do
			if added >= count then
				break
			end
			if profile.collection[def.id] == nil and (area == nil or def.area == area) then
				profile.collection[def.id] = NOW
				added += 1
			end
		end
	end

	describe("the milestones (1a)", function()
		it("are the eight of the table, with their prizes", function()
			expect(GrandOpening.COUNT).to.equal(8)
			local fish, spins = 0, 0
			for _, step in GrandOpening.STEPS do
				fish += step.prize.fish or 0
				spins += step.prize.spins or 0
			end
			expect(fish).to.equal(80) -- "80 golden fish, 2 spins, 1 potion and 1 crate"
			expect(spins).to.equal(2)
			expect((GrandOpening.STEPS[5].prize.potions :: any)[Potions.SWIFT]).to.equal(1)
			expect((GrandOpening.STEPS[8].prize.crates :: any).highest).to.equal(1)
			expect(ChatTags.TAGS[GrandOpening.TAG]).to.be.ok()
			expect(table.find(ChatTags.ORDER, GrandOpening.TAG)).to.be.ok()
		end)

		it("reads each one from the profile", function()
			local profile = fresh()
			for n = 1, 8 do
				expect(GrandOpening.met(profile, n)).to.equal(false)
			end
			profile.upgradeLevels.tables = 1
			expect(GrandOpening.met(profile, 1)).to.equal(true)
			profile.stats.baitsLetGo = 1 -- a bait cat let go is still a bait result
			expect(GrandOpening.met(profile, 2)).to.equal(true)
			collect(profile, 5)
			expect(GrandOpening.met(profile, 3)).to.equal(true)
			profile.tier = 2
			expect(GrandOpening.met(profile, 4)).to.equal(true)
			expect(GrandOpening.met(profile, 5)).to.equal(false)
			collect(profile, 1, "park")
			expect(GrandOpening.met(profile, 5)).to.equal(true)
			collect(profile, 11 - Economy.distinctCats(profile)) -- 11 different cats, the starter's id among them
			expect(Economy.distinctCats(profile)).to.equal(11)
			expect(GrandOpening.met(profile, 7)).to.equal(false)
			collect(profile, 1) -- 12, Tier 3's need
			expect(GrandOpening.met(profile, 7)).to.equal(true)
			profile.tier = 3
			expect(GrandOpening.met(profile, 8)).to.equal(true)
		end)

		it("a full cafe is every open role slot with a cat on it, at Tier 2 or above", function()
			local profile = fresh()
			-- fill the first `open` slots with copies of the starter (it is on barista_1)
			local function fill(open: number, check: boolean)
				local filled = 0
				for index, spot in Catalog.allSpots do
					if index > open then
						break
					end
					local cat: any = table.clone(profile.cats[next(profile.cats)])
					cat.uid = "c" .. index
					cat.spotId = spot.id
					profile.cats[cat.uid] = cat
					filled += 1
					if check and filled < open then
						expect(GrandOpening.met(profile, 6)).to.equal(false)
					end
				end
			end
			fill(Catalog.openSlotCount(1, 0), false)
			expect(GrandOpening.met(profile, 6)).to.equal(false) -- a full Tier 1 cafe does not count
			profile.tier = 2
			local open = Catalog.openSlotCount(2, 0)
			expect(open > Catalog.openSlotCount(1, 0)).to.equal(true)
			expect(GrandOpening.met(profile, 6)).to.equal(false)
			fill(open, true)
			expect(GrandOpening.met(profile, 6)).to.equal(true)
			profile.tier = 3 -- Tier 3 opens more slots, so the cafe is no longer full
			expect(GrandOpening.met(profile, 6)).to.equal(open == Catalog.openSlotCount(3, 0))
		end)
	end)

	describe("paying and the strip (1b, 1c)", function()
		it(
			"is quiet before tutorialStep 5, then pays what was met, lowest first, once each",
			function()
				local profile = fresh()
				profile.tutorialStep = 4
				profile.upgradeLevels.tables = 1
				profile.tier = 2
				expect(#GrandOpening.due(profile)).to.equal(0)
				profile.tutorialStep = 5
				expect(GrandOpening.due(profile) :: any).to.deepEqual({ 1, 4 }) -- out of order: both pay
				GrandOpening.mark(profile.grandOpening, 1)
				GrandOpening.mark(profile.grandOpening, 4)
				expect(#GrandOpening.due(profile)).to.equal(0)
				expect(GrandOpening.current(profile.grandOpening)).to.equal(2) -- the lowest not done
				expect(GrandOpening.doneCount(profile.grandOpening)).to.equal(2)
			end
		)

		it("the last one finishes it: nothing more shows or pays", function()
			local profile = fresh()
			profile.tier = 3
			GrandOpening.mark(profile.grandOpening, 8)
			expect(profile.grandOpening.finished).to.equal(true)
			expect(GrandOpening.active(profile)).to.equal(false)
			profile.upgradeLevels.tables = 1
			expect(#GrandOpening.due(profile)).to.equal(0)
			expect(GrandOpening.current(profile.grandOpening)).never.to.be.ok()
		end)

		it("sends a copy", function()
			local state: any = { done = { [2] = true } }
			local view: any = GrandOpening.view(state)
			view.done[3] = true
			expect(state.done[3]).never.to.be.ok()
		end)
	end)

	describe("the save (version 41, 1c and section 2)", function()
		it("a new account starts with nothing done and no guaranteed bait used", function()
			local profile = ProfileSchema.template(NOW)
			expect(next(profile.grandOpening.done)).never.to.be.ok()
			expect(profile.grandOpening.finished).never.to.be.ok()
			expect(profile.firstWow).to.equal(false)
		end)

		it(
			"a save from before at Tier 3 or above is finished with nothing back-paid; below it starts fresh",
			function()
				for tier, finished in { [1] = false, [2] = false, [3] = true, [5] = true } do
					local raw: any = ProfileSchema.template(NOW)
					raw.version = 40
					raw.tier = tier
					raw.grandOpening = { done = { [1] = true } } -- not from this version: ignored
					local profile = ProfileSchema.migrate(raw, NOW)
					expect(profile.grandOpening.finished == true).to.equal(finished)
					expect(next(profile.grandOpening.done)).never.to.be.ok()
				end
			end
		)

		it("keeps a version 41 state, known steps only", function()
			local raw: any = ProfileSchema.template(NOW)
			raw.grandOpening = {
				done = { [1] = true, [3] = true, [9] = true, x = true, [4] = 1 },
				finished = "yes",
			}
			local profile = ProfileSchema.migrate(raw, NOW)
			expect(profile.grandOpening.done :: any).to.deepEqual({ [1] = true, [3] = true })
			expect(profile.grandOpening.finished).never.to.be.ok()
			raw.grandOpening = { done = {}, finished = true }
			expect(ProfileSchema.migrate(raw, NOW).grandOpening.finished).to.equal(true)
		end)

		it(
			"firstWow: kept when true; a save from before that set two baits has had its second",
			function()
				local raw: any = ProfileSchema.template(NOW)
				raw.firstWow = true
				expect(ProfileSchema.migrate(raw, NOW).firstWow).to.equal(true)
				raw.firstWow = nil
				expect(ProfileSchema.migrate(raw, NOW).firstWow).to.equal(false)
				raw.version = 40
				raw.stats.luresUsed = 1
				expect(ProfileSchema.migrate(raw, NOW).firstWow).to.equal(false)
				raw.stats.luresUsed = 2
				expect(ProfileSchema.migrate(raw, NOW).firstWow).to.equal(true)
			end
		)

		it("a bait's wow mark survives a save and load; anything but true drops it", function()
			local raw: any = ProfileSchema.template(NOW)
			raw.bait = {
				lureId = "kibble",
				placedAt = NOW,
				readyAt = NOW + 60,
				catId = "tabby",
				variant = "base",
				charm = 50,
				wow = true,
			}
			expect((ProfileSchema.migrate(raw, NOW).bait :: any).wow).to.equal(true)
			raw.bait.wow = "yes"
			expect((ProfileSchema.migrate(raw, NOW).bait :: any).wow).never.to.be.ok()
		end)
	end)
end
