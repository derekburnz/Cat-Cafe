--!strict
-- shared/Bedtime.luau (F79, data-model section 12c; Model-Agent #511's sleep points): the sleep spots' fill order,
-- who sleeps where, the way up a cat tree and the decor Cat Tree Tower, and the arc of one hop.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bedtime = require(Shared.Bedtime)
	local Config = require(Shared.Config)

	-- The sleep and hop points' heights over the floor in the art (#511), and the Foot the climb starts from.
	local TREE = { Foot = 0, Sleep_Shelf = 2.35, Sleep_Top = 4.47 }
	local TOWER = {
		Foot = 0,
		Hop_1 = 1.55,
		Hop_2 = 3.2,
		Hop_3 = 3.4,
		Sleep_2 = 5.2,
		Hop_4 = 6.2,
		Hop_5 = 7.9,
		Sleep_1 = 9.9,
	}

	local function joined(list: { string }): string
		return table.concat(list, " ")
	end

	local function rises(heights: { [string]: number }, chain: { string }): { number }
		local out = { 0 }
		for _, name in chain do
			table.insert(out, heights[name])
		end
		return out
	end

	describe("the fill order", function()
		it("fills the tree tops, then their shelves, then decor cat trees, then the beds", function()
			local ids = {
				"bed_2",
				"decor_3_2",
				"tree_2_shelf",
				"bed_10",
				"tree_1_top",
				"decor_3_1",
				"decor_1_2",
				"tree_1_shelf",
				"bed_1",
				"tree_2_top",
			}
			expect(joined(Bedtime.order(ids))).to.equal(
				"tree_1_top tree_2_top tree_1_shelf tree_2_shelf decor_1_2 decor_3_1 decor_3_2 bed_1 bed_2 bed_10"
			)
			expect(ids[1]).to.equal("bed_2") -- a new table: the list handed in is left as it was
		end)

		it("puts anything it does not know last, by name", function()
			expect(joined(Bedtime.order({ "zz", "bed_1", "aa", "tree_1_top" }))).to.equal(
				"tree_1_top bed_1 aa zz"
			)
			expect(Bedtime.before("tree_1_top", "tree_1_top")).to.equal(false)
		end)

		it("names the two cat trees by their entertainer stations, left first", function()
			expect(joined(Bedtime.TREES)).to.equal("entertainer_1 entertainer_2")
		end)
	end)

	describe("who sleeps where", function()
		local SPOTS = { "tree_1_top", "tree_2_top", "tree_1_shelf", "bed_1" }

		it("gives the best cat the first spot and so on down", function()
			local plan = Bedtime.assign({ "a", "b", "c" }, SPOTS, {})
			expect(plan.a).to.equal("tree_1_top")
			expect(plan.b).to.equal("tree_2_top")
			expect(plan.c).to.equal("tree_1_shelf")
		end)

		it("lets a cat keep its spot and the rest fill round it", function()
			local plan = Bedtime.assign({ "a", "b", "c" }, SPOTS, { c = "tree_1_top" })
			expect(plan.c).to.equal("tree_1_top")
			expect(plan.a).to.equal("tree_2_top")
			expect(plan.b).to.equal("tree_1_shelf")
		end)

		it("moves a cat whose spot has gone, and gives a spot two hold to the better cat", function()
			local plan = Bedtime.assign({ "a", "b" }, SPOTS, { a = "decor_2_1", b = "bed_1" })
			expect(plan.b).to.equal("bed_1")
			expect(plan.a).to.equal("tree_1_top")
			plan = Bedtime.assign({ "a", "b" }, SPOTS, { a = "bed_1", b = "bed_1" })
			expect(plan.a).to.equal("bed_1")
			expect(plan.b).to.equal("tree_1_top")
		end)

		it("leaves the cats past the last spot out, at their stations", function()
			local plan = Bedtime.assign({ "a", "b", "c", "d", "e", "f" }, SPOTS, {})
			local count = 0
			local used: { [string]: boolean } = {}
			for _, spot in plan do
				count += 1
				expect(used[spot]).to.equal(nil)
				used[spot] = true
			end
			expect(count).to.equal(#SPOTS)
			expect(plan.e).to.equal(nil)
			expect(plan.f).to.equal(nil)
			expect(next(Bedtime.assign({ "a" }, {}, { a = "bed_1" }))).to.equal(nil)
		end)
	end)

	describe("the way up", function()
		it("climbs a cat tree by its shelf to the top, and to the shelf in one hop", function()
			expect(joined(Bedtime.hopChain(TREE, "Sleep_Top"))).to.equal("Sleep_Shelf Sleep_Top")
			expect(joined(Bedtime.hopChain(TREE, "Sleep_Shelf"))).to.equal("Sleep_Shelf")
		end)

		it("climbs the Cat Tree Tower through every lower hop and sleep point", function()
			expect(joined(Bedtime.hopChain(TOWER, "Sleep_1"))).to.equal(
				"Hop_1 Hop_2 Hop_3 Sleep_2 Hop_4 Hop_5 Sleep_1"
			)
			expect(joined(Bedtime.hopChain(TOWER, "Sleep_2"))).to.equal("Hop_1 Hop_2 Hop_3 Sleep_2")
		end)

		it("hops into a bed from its foot", function()
			expect(joined(Bedtime.hopChain({ Foot = 0, Sleep = 0.36 }, "Sleep"))).to.equal("Sleep")
		end)

		it("has no way up to a point the piece does not have", function()
			expect(#Bedtime.hopChain(TREE, "Sleep_1")).to.equal(0)
			expect(#Bedtime.hopChain({}, "Sleep")).to.equal(0)
		end)

		it("never climbs more than HopMaxRise in one hop on the art's points", function()
			for _, case in
				{
					{ TREE, "Sleep_Top" },
					{ TREE, "Sleep_Shelf" },
					{ TOWER, "Sleep_1" },
					{ TOWER, "Sleep_2" },
				}
			do
				local heights = case[1] :: { [string]: number }
				local rise = Bedtime.highestRise(
					rises(heights, Bedtime.hopChain(heights, case[2] :: string))
				)
				expect(rise > 0 and rise <= Config.HopMaxRise).to.equal(true)
			end
		end)

		it("reads the highest single climb, going down counting as none", function()
			expect(Bedtime.highestRise({ 0, 1.5, 1.2, 4 })).to.be.near(2.8, 1e-9)
			expect(Bedtime.highestRise({ 3, 1 })).to.equal(0)
			expect(Bedtime.highestRise({ 0 })).to.equal(0)
		end)
	end)

	describe("one hop", function()
		local FROM = Vector3.new(0, 0, 0)
		local TO = Vector3.new(2, 2, 0)

		it("leaves from the start, lands on the end and peaks HOP_HEIGHT over the line halfway", function()
			local start = Bedtime.arc(FROM, TO, 0)
			local land = Bedtime.arc(FROM, TO, 1)
			local mid = Bedtime.arc(FROM, TO, 0.5)
			expect(start.X).to.equal(0)
			expect(start.Y).to.equal(0)
			expect(land.X).to.equal(2)
			expect(land.Y).to.equal(2)
			expect(mid.X).to.be.near(1, 1e-9)
			expect(mid.Y).to.be.near(1 + Bedtime.HOP_HEIGHT, 1e-9)
		end)

		it("stays at the ends outside 0 to 1", function()
			expect(Bedtime.arc(FROM, TO, -1).Y).to.equal(0)
			expect(Bedtime.arc(FROM, TO, 3).Y).to.equal(2)
		end)
	end)

	describe("the timings (Config)", function()
		it("hops quickly, staggers the cats and gives up on a stuck walk", function()
			expect(Config.HopSeconds > 0 and Config.HopSeconds < 1).to.equal(true)
			expect(Config.BedtimeStaggerSeconds > 0).to.equal(true)
			expect(Config.BedtimeTimeoutSeconds > Config.BedtimeStretchSeconds).to.equal(true)
			expect(Config.CafeCatWalkSpeed > 0).to.equal(true)
		end)
	end)
end
