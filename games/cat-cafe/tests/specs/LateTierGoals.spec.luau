--!strict
-- The goal card, the rank up card and the next goals for the tiers behind a live switch (Tier 8 the Snowy Mountain,
-- Tier 9 the Water Park, Tier 10 the Medieval Castle; shared/LateTiers). Derek 2026-11-14: "make sure with the 3 areas
-- the new your goals are setup". With the switches on, each new tier is the goal by itself, with its own needs and
-- the area it opens; with them off, a Tier 7 cafe is shown as the top one, as the server's rank up check says.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local LateTiers = require(Shared.LateTiers)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ReturnGoals = require(Shared.ReturnGoals)
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local UI = Client:WaitForChild("UI")
	local GoalLines = require(UI:WaitForChild("Components"):WaitForChild("GoalLines")) :: any

	local NOW = 1_800_000_000
	local function profile(tier: number): any
		local p: any = ProfileSchema.template(NOW - 3600)
		p.tier = tier
		p.coins = 0
		return p
	end

	local function with(open: boolean, run: () -> ())
		LateTiers.setOpen(open)
		local ok, message = pcall(run)
		LateTiers.setOpen(nil)
		if not ok then
			error(message)
		end
	end

	local FoodOdds = require(UI:WaitForChild("Components"):WaitForChild("FoodOdds")) :: any

	describe("the goals of the tiers behind a switch", function()
		it("has a tier behind a switch", function()
			expect(Catalog.maxTier >= LateTiers.FIRST).to.equal(true)
		end)

		it(
			"makes each new tier the goal once the switches are on, with its needs and its area",
			function()
				with(true, function()
					for tier = LateTiers.FIRST - 1, Catalog.maxTier - 1 do
						local def = Catalog.getTier(tier + 1) :: any
						local area = Catalog.areasById[def.area] :: any
						-- what RankUp.progress builds the goal card and the rank up card from
						expect(GoalLines.nextTier(Catalog.tiers, tier)).to.equal(def)
						expect(def.cost > 0 and def.distinctCats > 0).to.equal(true)
						expect(area).never.to.equal(nil)
						expect(GoalLines.opens(def.name, false)).to.equal(
							"Opens " .. def.name .. " and the " .. area.name .. " 🏆"
						)
						local goals = ReturnGoals.pick(profile(tier), NOW)
						expect(goals[1].kind).to.equal("cats")
						expect(goals[1].need).to.equal(def.distinctCats)
						expect(goals[1].tier).to.equal(tier + 1)
						expect(goals[1].area).to.equal(def.area)
					end
				end)
			end
		)

		it("shows the last open tier as the top one while the switches are off", function()
			with(false, function()
				local tier = LateTiers.FIRST - 1
				expect(GoalLines.nextTier(Catalog.tiers, tier)).to.equal(nil)
				for _, goal in ReturnGoals.pick(profile(tier), NOW) do
					expect(goal.kind).to.equal("away")
				end
			end)
		end)

		it("names the next area on the bowl's odds sheet only once its switch is on", function()
			local catalog: any =
				{ cats = Catalog.cats, lures = Catalog.lures, areas = Catalog.areas }
			local kibble = Catalog.luresById.kibble
			local tier = LateTiers.FIRST - 1
			local area = Catalog.areasById[(Catalog.getTier(tier + 1) :: any).area] :: any
			local line = ("Rank up to Tier %d to add the %s cats"):format(tier + 1, area.name)
			with(false, function()
				expect(
					string.find(FoodOdds.split(catalog, kibble, tier), "Rank up to Tier", 1, true)
				).to.equal(nil)
			end)
			with(true, function()
				expect(string.find(FoodOdds.split(catalog, kibble, tier), line, 1, true)).never.to.equal(
					nil
				)
			end)
		end)

		it("leaves the tiers before the switches alone", function()
			with(false, function()
				local def = GoalLines.nextTier(Catalog.tiers, LateTiers.FIRST - 2)
				expect(def.tier).to.equal(LateTiers.FIRST - 1)
				expect(GoalLines.nextTier(Catalog.tiers, Catalog.maxTier)).to.equal(nil)
				expect(GoalLines.nextTier(nil, 1)).to.equal(nil)
			end)
		end)
	end)
end
