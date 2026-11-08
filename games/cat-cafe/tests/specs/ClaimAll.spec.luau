--!strict
-- shared/ClaimAll.luau: what one Claim all pays in the Quests window, the Index and the Tip Jar (Derek 2026-10-28 and
-- 10-29, ui-contract.md `claimAll`), and the one toast's lines.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local ClaimAll = require(Shared.ClaimAll)
	local Config = require(Shared.Config)
	local IndexRewards = require(Shared.IndexRewards)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Quests = require(Shared.Quests)

	local function fresh(): any
		return ProfileSchema.template(1000)
	end

	describe("the kinds", function()
		it("takes the windows' kinds, \"quests\" for all three Quests tabs, and says when nothing is ready", function()
			expect(ClaimAll.KINDS :: any).to.deepEqual({
				"daily",
				"weekly",
				"achievements",
				"quests",
				"index",
				"tipjar",
			})
			expect(ClaimAll.NOTHING).to.equal("Nothing to claim yet")
			expect((Config :: any).QuestClaimAll).to.equal(true)
			expect((Config :: any).IndexClaimAll).to.equal(true)
			expect((Config :: any).TipJarClaimAll).to.equal(true)
		end)
	end)

	describe("quests and achievements", function()
		it(
			"lists the finished, unclaimed quests of one set by slot, as a single Claim would pay them",
			function()
				local p = fresh()
				p.quests.daily = Quests.rollSet(p, "daily", 0, {}, function()
					return 0
				end)
				p.quests.daily[1] = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
				p.quests.daily[3] = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
				for slot in p.quests.daily do
					p.quests.daily[slot].claimed = slot ~= 1 and slot ~= 3
				end
				expect(ClaimAll.quests(p, "daily") :: any).to.deepEqual({})
				p.stats.catsCaught += 5
				expect(ClaimAll.quests(p, "daily") :: any).to.deepEqual({ 1, 3 })
				p.quests.daily[1].claimed = true
				expect(ClaimAll.quests(p, "daily") :: any).to.deepEqual({ 3 })
				for _, slot in ClaimAll.quests(p, "weekly") do
					expect(Quests.claimBlocker(p, "weekly", slot)).to.equal(nil)
				end
			end
		)

		it("gathers every ready daily, weekly and achievement for the one Claim all (#1073)", function()
			local p = fresh()
			p.quests.daily = Quests.rollSet(p, "daily", 0, {}, function()
				return 0
			end)
			p.quests.daily[1] = Quests.entry(p, Catalog.getQuest("d_catch5") :: any, 0)
			for slot in p.quests.daily do
				p.quests.daily[slot].claimed = slot ~= 1
			end
			p.stats.rescues = 1e9
			p.stats.catsCaught += 5
			local ready = ClaimAll.questReady(p)
			expect(ready.daily :: any).to.deepEqual(ClaimAll.quests(p, "daily"))
			expect(ready.weekly :: any).to.deepEqual(ClaimAll.quests(p, "weekly"))
			expect(ready.achievements :: any).to.deepEqual(ClaimAll.achievements(p))
			expect(#ready.daily >= 1).to.equal(true)
			expect(#ready.achievements >= 2).to.equal(true)
			expect(ready.count).to.equal(#ready.daily + #ready.weekly + #ready.achievements)
			-- claimed everywhere: nothing left, so the button hides
			for _, slot in ready.daily do
				p.quests.daily[slot].claimed = true
			end
			for _, slot in ready.weekly do
				p.quests.weekly[slot].claimed = true
			end
			for _, id in ready.achievements do
				p.achievements[id] = true
			end
			expect(ClaimAll.questReady(p).count).to.equal(0)
		end)

		it("lists the met, unclaimed achievements in Catalog order", function()
			local p = fresh()
			local before = ClaimAll.achievements(p)
			for _, id in before do
				expect(Quests.achievementBlocker(p, id)).to.equal(nil)
			end
			local rescues: { string } = {}
			for _, def in Catalog.achievements do
				if def.measure == "rescues" then
					table.insert(rescues, def.id)
				end
			end
			expect(#rescues >= 2).to.equal(true)
			p.stats.rescues = 1e9
			local ready = ClaimAll.achievements(p)
			local at: { [string]: number } = {}
			for i, id in ready do
				at[id] = i
			end
			for i, id in rescues do
				expect(at[id]).to.be.ok()
				if i > 1 then
					expect(at[id] > at[rescues[i - 1]]).to.equal(true)
				end
			end
			p.achievements[rescues[1]] = true
			expect(table.find(ClaimAll.achievements(p), rescues[1])).to.equal(nil)
			expect(#ClaimAll.achievements(p)).to.equal(#ready - 1)
		end)
	end)

	describe("the Index", function()
		it(
			"goes through every page once: the areas by tier, All Cats, Rainbow, then the Decor pages",
			function()
				local pages = ClaimAll.indexPages()
				for i, area in Catalog.areas do
					expect(pages[i]).to.equal(area.id)
				end
				expect(pages[#Catalog.areas + 1]).to.equal(IndexRewards.ALL)
				expect(pages[#Catalog.areas + 2]).to.equal(IndexRewards.RAINBOW)
				local count = 0
				for _ in Catalog.indexPrizes do
					count += 1
				end
				expect(#pages).to.equal(count)
				for i = #Catalog.areas + 3, #pages do
					expect(string.sub(pages[i], 1, #IndexRewards.DECOR_PREFIX)).to.equal(
						IndexRewards.DECOR_PREFIX
					)
					if i > #Catalog.areas + 3 then
						expect(pages[i] > pages[i - 1]).to.equal(true)
					end
				end
			end
		)

		it("lists every reward ready on every page and drops one once claimed", function()
			local p = fresh()
			expect(#ClaimAll.index(p)).to.equal(0)
			local alley = 0
			for _, def in Catalog.cats do
				if def.area == "alley" and def.exclusive ~= true and alley < 6 then
					p.collection[def.id] = 1000
					alley += 1
				end
			end
			expect(alley).to.equal(6)
			local ready = ClaimAll.index(p)
			local names: { string } = {}
			for _, item in ready do
				expect(IndexRewards.blocker(p, item.areaId, item.milestoneId)).to.equal(nil)
				table.insert(names, item.areaId .. "/" .. item.milestoneId)
			end
			expect(names :: any).to.deepEqual({ "alley/cats3", "alley/cats6", "all/total5" })
			p.indexRewards.alley = { cats3 = true }
			expect(#ClaimAll.index(p)).to.equal(2)
		end)
	end)

	describe("the Tip Jar", function()
		it("lists the steps ready and unclaimed this session, in order", function()
			local start = 5000
			local claimed = table.create(#Catalog.tipJar, false)
			expect(ClaimAll.tipJar(claimed, start, start) :: any).to.deepEqual({})
			local tenMinutes = start + 10 * 60
			local want: { number } = {}
			for step, def in Catalog.tipJar do
				if def.minutes <= 10 then
					table.insert(want, step)
				end
			end
			expect(#want >= 2).to.equal(true)
			expect(ClaimAll.tipJar(claimed, start, tenMinutes) :: any).to.deepEqual(want)
			claimed[want[1]] = true
			table.remove(want, 1)
			expect(ClaimAll.tipJar(claimed, start, tenMinutes) :: any).to.deepEqual(want)
		end)
	end)

	describe("the toast", function()
		it(
			"adds up money, golden fish, spins, forever bonuses and counted things in the order they came",
			function()
				local lines = ClaimAll.merge({
					"+$300",
					"+5 golden fish",
					"1 Alley Crate",
					"+2% money forever",
					"+$500",
					"1 spin",
					"+10 golden fish",
					"2 Alley Crate",
					"+3% gold luck forever",
					"+5% money forever",
					"1 spin",
					"1 Money Potion",
				})
				expect(lines :: any).to.deepEqual({
					"+$800",
					"+15 golden fish",
					"3 Alley Crate",
					"+7% money forever",
					"2 spins",
					"+3% gold luck forever",
					"1 Money Potion",
				})
			end
		)

		it("keeps a capped spin line and a tag as they are, and an empty list empty", function()
			expect(ClaimAll.merge({}) :: any).to.deepEqual({})
			expect(ClaimAll.merge({ "2 spins" }) :: any).to.deepEqual({ "2 spins" })
			expect(
				ClaimAll.merge({ "1 of 2 spins (Spins full)", "the Rainbow Finder tag", "+$1" }) :: any
			).to.deepEqual({
				"1 of 2 spins (Spins full)",
				"the Rainbow Finder tag",
				"+$1",
			})
		end)
	end)
end
