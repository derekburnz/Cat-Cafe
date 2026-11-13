--!strict
-- shared/NewKind (#3529): the "NEW" tag over kinds not owned, the catch card's line and the five cats pointer.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local GrandOpening = require(Shared.GrandOpening)
	local LiveFlags = require(Shared.LiveFlags)
	local NewKind = require(Shared.NewKind)

	local function alley(rarity: string): any
		for _, def in Catalog.cats do
			if def.area == "alley" and def.rarity == rarity and def.exclusive ~= true then
				return def
			end
		end
		error("no alley " .. rarity)
	end

	describe("the switch", function()
		it("is a live switch that starts off", function()
			expect(NewKind.FLAG).to.equal("newKindTag")
			expect(table.find(LiveFlags.KEYS, NewKind.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[NewKind.FLAG]).to.equal(true)
			expect(LiveFlags.defaults()[NewKind.FLAG]).to.equal(false)
			expect(LiveFlags.shown(NewKind.FLAG, nil)).to.equal(false)
			expect(LiveFlags.shown(NewKind.FLAG, true)).to.equal(true)
		end)
	end)

	describe("isNew", function()
		it("is a kind the collection does not hold", function()
			local tabby = alley("Common")
			expect(NewKind.isNew({}, tabby.id, tabby.rarity)).to.equal(true)
			expect(NewKind.isNew({ [tabby.id] = 1 }, tabby.id, tabby.rarity)).to.equal(false)
			expect(NewKind.isNew({ other = 1 }, tabby.id, tabby.rarity)).to.equal(true)
		end)

		it("is never a Secret, a hidden kind, an unknown id or a missing collection", function()
			local tabby = alley("Common")
			expect(NewKind.isNew({}, tabby.id, "Secret")).to.equal(false)
			expect(NewKind.isNew({}, nil, "Common")).to.equal(false)
			expect(NewKind.isNew({}, "", "Common")).to.equal(false)
			expect(NewKind.isNew({}, 12, "Common")).to.equal(false)
			expect(NewKind.isNew({}, "no_such_cat", "Common")).to.equal(false)
			expect(NewKind.isNew(nil, tabby.id, tabby.rarity)).to.equal(false)
			for _, def in Catalog.cats do
				if def.rarity == "Secret" then
					expect(NewKind.isNew({}, def.id, "Mythical")).to.equal(false)
				end
			end
		end)
	end)

	describe("shows", function()
		it(
			"is up between 6 and 60 studs, not on a bar and not while a net holds the cat",
			function()
				expect(NewKind.shows(true, false, 0, 30)).to.equal(true)
				expect(NewKind.shows(true, false, nil, 30)).to.equal(true)
				expect(NewKind.shows(true, false, 0, NewKind.NEAR)).to.equal(true)
				expect(NewKind.shows(true, false, 0, NewKind.NEAR - 0.1)).to.equal(false)
				expect(NewKind.shows(true, false, 0, NewKind.RANGE)).to.equal(true)
				expect(NewKind.shows(true, false, 0, NewKind.RANGE + 0.1)).to.equal(false)
				expect(NewKind.shows(true, true, 0, 30)).to.equal(false)
				expect(NewKind.shows(true, false, 77, 30)).to.equal(false)
				expect(NewKind.shows(false, false, 0, 30)).to.equal(false)
				expect(NewKind.NEAR).to.equal(6)
				expect(NewKind.RANGE).to.equal(60)
			end
		)
	end)

	describe("the catch card's line", function()
		it("counts the kind being caught toward Tier 2 below Tier 2", function()
			local name = (Catalog.getTier(2) :: any).name
			expect(NewKind.line(1, 1)).to.equal("New kind! 2/5 for " .. name)
			expect(NewKind.line(2, 1)).to.equal("New kind! 3/5 for " .. name)
			expect(NewKind.line(4, 1)).to.equal("New kind! 5/5 for " .. name)
			expect(NewKind.line(9, 1)).to.equal("New kind! 5/5 for " .. name)
			expect(NewKind.line(0, 1)).to.equal("New kind! 1/5 for " .. name)
		end)

		it("is short at Tier 2 and above", function()
			expect(NewKind.line(3, 2)).to.equal("New kind!")
			expect(NewKind.line(30, 5)).to.equal("New kind!")
		end)

		it("needs what Tier 2 needs", function()
			expect((Catalog.getTier(2) :: any).distinctCats).to.equal(NewKind.KINDS)
		end)
	end)

	describe("the goal", function()
		it("reads the count on the card", function()
			expect(NewKind.title(3)).to.equal("Catch new kinds of cat 🐾 3/5")
			expect(NewKind.title(0)).to.equal("Catch new kinds of cat 🐾 0/5")
			expect(NewKind.title(8)).to.equal("Catch new kinds of cat 🐾 5/5")
			expect(NewKind.title(3, true)).to.equal("New kinds of cat 🐾 3/5") -- the phone's narrower card
		end)

		it(
			"is on only with the switch, as the Grand Opening's next milestone, under five kinds",
			function()
				expect(NewKind.goal(true, "five_cats", 3)).to.equal(true)
				expect(NewKind.goal(false, "five_cats", 3)).to.equal(false)
				expect(NewKind.goal(true, "first_bait_cat", 3)).to.equal(false)
				expect(NewKind.goal(true, nil, 3)).to.equal(false)
				expect(NewKind.goal(true, "five_cats", 5)).to.equal(false)
			end
		)

		it("names a real Grand Opening milestone", function()
			local found = false
			for _, step in GrandOpening.STEPS do
				found = found or step.id == NewKind.MILESTONE
			end
			expect(found).to.equal(true)
		end)
	end)

	describe("the trail", function()
		it("shows after 20 idle seconds and goes 120 seconds after it showed", function()
			expect(NewKind.trail(true, false, 19.9, nil)).to.equal(false)
			expect(NewKind.trail(true, false, 20, nil)).to.equal(true)
			expect(NewKind.trail(true, false, 0, 5)).to.equal(true) -- a catch ended: it is still up
			expect(NewKind.trail(true, false, 500, 119.9)).to.equal(true)
			expect(NewKind.trail(true, false, 500, 120)).to.equal(false)
		end)

		it("never shows without the goal or while busy", function()
			expect(NewKind.trail(false, false, 100, nil)).to.equal(false)
			expect(NewKind.trail(true, true, 100, nil)).to.equal(false)
			expect(NewKind.trail(true, true, 100, 10)).to.equal(false)
		end)

		it("leads to a stray, the cannon, the next area or nothing", function()
			expect(NewKind.where("alley", true, true, false)).to.equal("stray")
			expect(NewKind.where("alley", true, true, true)).to.equal("stray")
			expect(NewKind.where("alley", true, false, true)).to.equal("next")
			expect(NewKind.where("alley", true, false, false)).to.equal("none")
			expect(NewKind.where(nil, true, false, false)).to.equal("cannon")
			expect(NewKind.where(nil, false, false, true)).to.equal("none")
			expect(NewKind.where("alley", false, true, true)).to.equal("none")
		end)

		it("counts as followed within 25 studs on the ground", function()
			expect(NewKind.followed(Vector3.new(0, 0, 0), Vector3.new(25, 40, 0))).to.equal(true)
			expect(NewKind.followed(Vector3.new(0, 0, 0), Vector3.new(25.1, 0, 0))).to.equal(false)
		end)

		it("names its two step_time events and what the client reports for them", function()
			expect(NewKind.SHOWN).to.equal("new_kind_trail_shown")
			expect(NewKind.FOLLOWED).to.equal("new_kind_trail_followed")
			expect(NewKind.REPORTS.shown).to.equal(NewKind.SHOWN)
			expect(NewKind.REPORTS.followed).to.equal(NewKind.FOLLOWED)
			expect(NewKind.REPORTS.other).to.equal(nil)
		end)
	end)

	describe("the Alleyway (#3529 section 4)", function()
		it("has at least five kinds a new player can catch without Epic luck", function()
			local easy = #Catching.candidates("Common", "alley")
				+ #Catching.candidates("Rare", "alley")
			expect(easy >= NewKind.KINDS).to.equal(true)
		end)

		it("holds five or more kinds in at least nine sunrise waves of ten", function()
			local area = Catalog.getArea("alley") :: any
			local random = Random.new(3529)
			local trials, enough = 2000, 0
			for _ = 1, trials do
				local seen: { [string]: boolean } = {}
				local kinds = 0
				for _ = 1, area.waveSize do
					local rarity = Catching.pickRarity(area.odds, random:NextNumber())
					local def = Catching.pickCat(rarity, "alley", random:NextNumber())
					if not seen[def.id] then
						seen[def.id] = true
						kinds += 1
					end
				end
				if kinds >= NewKind.KINDS then
					enough += 1
				end
			end
			expect(enough / trials >= 0.9).to.equal(true)
		end)
	end)

	describe("wording", function()
		it("has no hurry words, arrows or timers", function()
			for _, text in
				{
					NewKind.TEXT,
					NewKind.LINE,
					NewKind.CANNON_LINE,
					NewKind.NEXT_AREA,
					NewKind.title(3),
					NewKind.title(3, true),
					NewKind.line(2, 1),
				}
			do
				local lower = string.lower(text)
				for _, word in { "hurry", "quick", "fast", "now", "left", "→", "➡" } do
					expect(string.find(lower, word, 1, true)).to.equal(nil)
				end
			end
		end)
	end)
end
