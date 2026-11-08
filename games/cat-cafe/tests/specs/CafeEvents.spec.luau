--!strict
-- shared/CafeEvents.luau against live-events.md (#2486): the schedule's record, its hard rules (a broken record is
-- dropped whole), its caps (a value past one is clamped, with a note), which event runs, the shower times and kinds,
-- the EventEffects shape the HUD reads and the one-server test presets.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CafeEvents = require(Shared.CafeEvents)
	local Config = require(Shared.Config)

	local NOW = 1800000000
	local HOUR = 3600
	local NONE = newproxy() -- an override that leaves the field out

	local function raw(overrides: { [string]: any }?): { [string]: any }
		local out: { [string]: any } = {
			id = "party-1121",
			title = "Cafe Party",
			startsAt = NOW + HOUR,
			endsAt = NOW + 3 * HOUR,
			big = true,
			effects = {
				days = { "lucky", "golden", "rainbow" },
				money = 2,
				luck = 0.5,
				showers = { count = 8, gapSeconds = 900, firstAfter = 600 },
				reward = { cosmeticId = "Decor_PartyBunting" },
			},
		}
		for key, value in overrides or {} do
			out[key] = if value == NONE then nil else value
		end
		return out
	end

	local function effects(overrides: { [string]: any }): { [string]: any }
		local out: { [string]: any } = { days = {}, money = 1, luck = 0 }
		for key, value in overrides do
			out[key] = value
		end
		return out
	end

	describe("the record", function()
		it("reads the spec's example with every effect", function()
			local list, notes = CafeEvents.parse({ raw() }, NOW)
			expect(#list).to.equal(1)
			expect(#notes).to.equal(0)
			local event = list[1]
			expect(event.id).to.equal("party-1121")
			expect(event.title).to.equal("Cafe Party")
			expect(event.startsAt).to.equal(NOW + HOUR)
			expect(event.endsAt).to.equal(NOW + 3 * HOUR)
			expect(event.big).to.equal(true)
			expect(event.test).to.equal(false)
			expect(event.effects.days.lucky).to.equal(true)
			expect(event.effects.days.golden).to.equal(true)
			expect(event.effects.days.rainbow).to.equal(true)
			expect(event.effects.money).to.equal(2)
			expect(event.effects.luck).to.equal(0.5)
			local showers = assert(event.effects.showers)
			expect(showers.count).to.equal(8)
			expect(showers.gapSeconds).to.equal(900)
			expect(showers.firstAfter).to.equal(600)
			expect(event.effects.reward).to.equal("Decor_PartyBunting")
		end)

		it("gives an effect left out its no-boost value", function()
			local list = CafeEvents.parse({ raw({ big = NONE, effects = {} }) }, NOW)
			local event = list[1]
			expect(event.big).to.equal(false)
			expect(event.effects.days.lucky).to.equal(false)
			expect(event.effects.money).to.equal(1)
			expect(event.effects.luck).to.equal(0)
			expect(event.effects.showers).to.equal(nil)
			expect(event.effects.reward).to.equal(nil)
		end)

		it("reads nothing, with no note, when the key is empty", function()
			local list, notes = CafeEvents.parse(nil, NOW)
			expect(#list).to.equal(0)
			expect(#notes).to.equal(0)
			list, notes = CafeEvents.parse("party", NOW)
			expect(#list).to.equal(0)
			expect(#notes).to.equal(1)
		end)
	end)

	describe("hard rules drop the record whole", function()
		local broken: { [string]: { [string]: any } } = {
			["not a table"] = { record = "party" } :: any,
			["an empty id"] = { id = "" },
			["an id with capitals"] = { id = "Party" },
			["an id with a space"] = { id = "cafe party" },
			["an id past ID_MAX"] = { id = string.rep("a", 33) },
			["no title"] = { title = "" },
			["a title past TITLE_MAX"] = { title = string.rep("x", 25) },
			["no start"] = { startsAt = "soon" },
			["no end"] = { endsAt = NONE },
			["shorter than EventMinSeconds"] = { endsAt = NOW + HOUR + 299 },
			["longer than EventMaxSeconds"] = { endsAt = NOW + HOUR + 7201 },
			["already over"] = { startsAt = NOW - 2 * HOUR, endsAt = NOW },
			["a bad big"] = { big = "yes" },
			["no effects"] = { effects = "all" },
			["an unknown day kind"] = { effects = effects({ days = { "lucky", "sunny" } }) },
			["money not a number"] = { effects = effects({ money = "2" }) },
			["luck NaN"] = { effects = effects({ luck = 0 / 0 }) },
			["showers without a gap"] = { effects = effects({ showers = { count = 3, firstAfter = 0 } }) },
			["a negative first shower"] = {
				effects = effects({ showers = { count = 3, gapSeconds = 900, firstAfter = -1 } }),
			},
			["a reward with no cosmetic"] = { effects = effects({ reward = {} }) },
		}
		for name, overrides in broken do
			it("on " .. name, function()
				local item: any = if overrides.record ~= nil then overrides.record else raw(overrides)
				local list, notes = CafeEvents.parse({ item }, NOW)
				expect(#list).to.equal(0)
				expect(#notes).to.equal(1)
				expect(string.find(notes[1], "record 1 ignored", 1, true)).to.equal(1)
			end)
		end

		it("keeps the first of an id that comes twice", function()
			local list, notes = CafeEvents.parse(
				{ raw(), raw({ startsAt = NOW + 10 * HOUR, endsAt = NOW + 11 * HOUR }) },
				NOW
			)
			expect(#list).to.equal(1)
			expect(list[1].startsAt).to.equal(NOW + HOUR)
			expect(#notes).to.equal(1)
		end)

		it("drops an event that overlaps one starting earlier, and keeps one that starts at its end", function()
			local list, notes = CafeEvents.parse({
				raw({ id = "late", startsAt = NOW + 2 * HOUR, endsAt = NOW + 4 * HOUR }),
				raw({ id = "early" }),
				raw({ id = "after", startsAt = NOW + 3 * HOUR, endsAt = NOW + 4 * HOUR }),
			}, NOW)
			expect(#list).to.equal(2)
			expect(list[1].id).to.equal("early")
			expect(list[2].id).to.equal("after")
			expect(#notes).to.equal(1)
			expect(string.find(notes[1], "late", 1, true)).to.equal(1)
		end)

		it("reads at most EventScheduleMax records", function()
			local items = {}
			for i = 1, Config.EventScheduleMax + 2 do
				table.insert(
					items,
					raw({ id = "e" .. i, startsAt = NOW + i * 3 * HOUR, endsAt = NOW + i * 3 * HOUR + HOUR })
				)
			end
			local list, notes = CafeEvents.parse(items, NOW)
			expect(#list).to.equal(Config.EventScheduleMax)
			expect(#notes).to.equal(2)
		end)

		it("keeps an event already under way", function()
			local list = CafeEvents.parse({ raw({ startsAt = NOW - HOUR, endsAt = NOW + HOUR }) }, NOW)
			expect(#list).to.equal(1)
		end)
	end)

	describe("caps clamp, with a note", function()
		it("money to 1..EventMoneyMax and luck to 0..EventLuckMax", function()
			local list, notes = CafeEvents.parse({ raw({ effects = effects({ money = 5, luck = 3 }) }) }, NOW)
			expect(list[1].effects.money).to.equal(Config.EventMoneyMax)
			expect(list[1].effects.luck).to.equal(Config.EventLuckMax)
			expect(#notes).to.equal(2)
			list = CafeEvents.parse({ raw({ effects = effects({ money = 0.5, luck = -1 }) }) }, NOW)
			expect(list[1].effects.money).to.equal(1)
			expect(list[1].effects.luck).to.equal(0)
		end)

		it("showers to EventShowerMax, at least EventShowerGapMinSeconds apart; none for a count of 0", function()
			local list, notes = CafeEvents.parse({
				raw({ effects = effects({ showers = { count = 40, gapSeconds = 10, firstAfter = 0 } }) }),
			}, NOW)
			local showers = assert(list[1].effects.showers)
			expect(showers.count).to.equal(Config.EventShowerMax)
			expect(showers.gapSeconds).to.equal(Config.EventShowerGapMinSeconds)
			expect(#notes).to.equal(2)
			list = CafeEvents.parse({
				raw({ effects = effects({ showers = { count = 0, gapSeconds = 900, firstAfter = 0 } }) }),
			}, NOW)
			expect(list[1].effects.showers).to.equal(nil)
		end)
	end)

	describe("which event runs", function()
		local list = CafeEvents.parse({
			raw({ id = "a" }),
			raw({ id = "b", startsAt = NOW + 5 * HOUR, endsAt = NOW + 6 * HOUR }),
		}, NOW)

		it("runs from startsAt up to, not at, endsAt", function()
			expect(CafeEvents.current(list, NOW)).to.equal(nil)
			expect((CafeEvents.current(list, NOW + HOUR) :: any).id).to.equal("a")
			expect((CafeEvents.current(list, NOW + 3 * HOUR - 1) :: any).id).to.equal("a")
			expect(CafeEvents.current(list, NOW + 3 * HOUR)).to.equal(nil)
			expect((CafeEvents.current(list, NOW + 5 * HOUR) :: any).id).to.equal("b")
		end)

		it("names the next one to start", function()
			expect((CafeEvents.upcoming(list, NOW) :: any).id).to.equal("a")
			expect((CafeEvents.upcoming(list, NOW + HOUR) :: any).id).to.equal("b")
			expect(CafeEvents.upcoming(list, NOW + 5 * HOUR)).to.equal(nil)
		end)
	end)

	describe("showers", function()
		it("come firstAfter into the window, then every gapSeconds, none at or after the end", function()
			local event = CafeEvents.parse({ raw() }, NOW)[1]
			local times = CafeEvents.showerTimes(event)
			-- 2 hours: 600 s in, then every 900 s, so 8 fit (the 8th at 600 + 7 * 900 = 6900 s)
			expect(#times).to.equal(8)
			expect(times[1]).to.equal(event.startsAt + 600)
			expect(times[8]).to.equal(event.startsAt + 6900)
			local short = CafeEvents.parse({ raw({ endsAt = NOW + HOUR + 1500 }) }, NOW)[1]
			expect(#CafeEvents.showerTimes(short)).to.equal(1)
			local none = CafeEvents.parse({ raw({ effects = effects({}) }) }, NOW)[1]
			expect(#CafeEvents.showerTimes(none)).to.equal(0)
		end)

		it("alternate a rainbow Legendary and a Mythical, the first rainbow", function()
			expect(CafeEvents.showerKind(1)).to.equal("rainbow_legendary")
			expect(CafeEvents.showerKind(2)).to.equal("mythical")
			expect(CafeEvents.showerKind(7)).to.equal("rainbow_legendary")
			expect(CafeEvents.showerKind(8)).to.equal("mythical")
		end)
	end)

	describe("shower cats (2c)", function()
		local Catalog = require(Shared.Catalog)

		it("claim under event:<id>:<n>, a test event's under its own server", function()
			local event = CafeEvents.parse({ raw() }, NOW)[1]
			expect(CafeEvents.showerKey(event, 3, "job-1")).to.equal("event:party-1121:3")
			local test = assert(CafeEvents.test("showers", NOW, 10))
			expect(CafeEvents.showerKey(test, 1, "job-1")).to.equal("test:job-1:test-showers:1")
		end)

		it("pick a rainbow Legendary for odd ones and a Mythical for even ones, the same every time", function()
			local event = CafeEvents.parse({ raw() }, NOW)[1]
			for n = 1, 8 do
				local pick = CafeEvents.showerPick(event, n)
				local again = CafeEvents.showerPick(event, n)
				expect(again.catId).to.equal(pick.catId)
				expect(again.areaId).to.equal(pick.areaId)
				local def = assert(Catalog.getCat(pick.catId))
				expect(def.rarity).to.equal(pick.kind)
				expect(def.area).to.equal(pick.areaId)
				if n % 2 == 1 then
					expect(pick.kind).to.equal("Legendary")
					expect(pick.coat).to.equal("rainbow")
				else
					expect(pick.kind).to.equal("Mythical")
					expect(pick.coat).to.equal(nil)
				end
			end
		end)

		it("land on every area about equally (EventShowerAreaWeights, 20 each)", function()
			local counts: { [string]: number } = {}
			for i = 1, 500 do
				local event = CafeEvents.parse({ raw({ id = "e" .. i }) }, NOW)[1]
				local area = CafeEvents.showerPick(event, 1).areaId
				counts[area] = (counts[area] or 0) + 1
			end
			for _, area in Catalog.areas do
				expect((counts[area.id] or 0) >= 60).to.equal(true) -- 100 expected of 500
			end
			expect(CafeEvents.showerAreaFor(0)).to.equal(Catalog.areas[1].id)
			expect(CafeEvents.showerAreaFor(0.999)).to.equal(Catalog.areas[#Catalog.areas].id)
		end)

		it("announce as the spec words it", function()
			local pick = { n = 2, kind = "Mythical", coat = nil, areaId = "woods", catId = "x" }
			expect(CafeEvents.showerText(pick :: any)).to.equal("Event cat! A Mythical appeared in the Woods!")
			expect(CafeEvents.showerText(pick :: any, 4)).to.equal(
				"Event cat! A Mythical appeared in the Woods! (opens at Tier 4)"
			)
			local rainbow = { n = 1, kind = "Legendary", coat = "rainbow", areaId = "woods", catId = "x" }
			expect(CafeEvents.showerText(rainbow :: any)).to.equal("Event cat! A Rainbow Legendary appeared in the Woods!")
			expect(CafeEvents.showerCaughtText("Sam")).to.equal("Event cat caught by Sam!")
		end)
	end)

	describe("the EventEffects attribute", function()
		it("lists the days in Lucky, Golden, Rainbow order, with showers and reward only when set", function()
			local event = CafeEvents.parse({ raw() }, NOW)[1]
			local data = CafeEvents.effectsData(event)
			expect(table.concat(data.days, ",")).to.equal("lucky,golden,rainbow")
			expect(data.money).to.equal(2)
			expect(data.luck).to.equal(0.5)
			expect(data.showers.count).to.equal(8)
			expect(data.reward.cosmeticId).to.equal("Decor_PartyBunting")
			local plain = CafeEvents.effectsData(CafeEvents.parse({ raw({ effects = effects({}) }) }, NOW)[1])
			expect(#plain.days).to.equal(0)
			expect(plain.showers).to.equal(nil)
			expect(plain.reward).to.equal(nil)
		end)

		it("names its attributes as the HUD reads them", function()
			expect(CafeEvents.ATTRIBUTES.id).to.equal("EventId")
			expect(CafeEvents.ATTRIBUTES.title).to.equal("EventTitle")
			expect(CafeEvents.ATTRIBUTES.startsAt).to.equal("EventStartsAt")
			expect(CafeEvents.ATTRIBUTES.endsAt).to.equal("EventEndsAt")
			expect(CafeEvents.ATTRIBUTES.effects).to.equal("EventEffects")
			expect(CafeEvents.ATTRIBUTES.running).to.equal("EventRunning")
		end)
	end)

	describe("test presets (one server)", function()
		it("gives full every effect at its cap, from now, and showers a minute apart", function()
			local event = assert(CafeEvents.test("full", NOW, 10))
			expect(event.test).to.equal(true)
			expect(event.startsAt).to.equal(NOW)
			expect(event.endsAt).to.equal(NOW + 600)
			expect(event.effects.days.rainbow).to.equal(true)
			expect(event.effects.money).to.equal(Config.EventMoneyMax)
			expect(event.effects.luck).to.equal(0.5)
			local times = CafeEvents.showerTimes(event)
			expect(#times).to.equal(CafeEvents.TEST_SHOWERS_MAX)
			expect(times[1]).to.equal(NOW + CafeEvents.TEST_SHOWER_FIRST)
			expect(times[2] - times[1]).to.equal(CafeEvents.TEST_SHOWER_GAP)
		end)

		it("gives each other preset its one effect", function()
			local days = assert(CafeEvents.test("days", NOW, 10))
			expect(days.effects.days.lucky).to.equal(true)
			expect(days.effects.money).to.equal(1)
			expect(days.effects.showers).to.equal(nil)
			local money = assert(CafeEvents.test("money", NOW, 10))
			expect(money.effects.money).to.equal(Config.EventMoneyMax)
			expect(money.effects.days.lucky).to.equal(false)
			local luck = assert(CafeEvents.test("luck", NOW, 10))
			expect(luck.effects.luck).to.equal(0.5)
			expect(luck.effects.money).to.equal(1)
			local showers = assert(CafeEvents.test("showers", NOW, 10))
			expect(showers.effects.showers ~= nil).to.equal(true)
			expect(showers.effects.luck).to.equal(0)
		end)

		it("keeps the length inside TEST_MINUTES_MIN..MAX and knows no other preset", function()
			expect((CafeEvents.test("money", NOW, 1) :: any).endsAt).to.equal(NOW + CafeEvents.TEST_MINUTES_MIN * 60)
			expect((CafeEvents.test("money", NOW, 999) :: any).endsAt).to.equal(
				NOW + CafeEvents.TEST_MINUTES_MAX * 60
			)
			expect(CafeEvents.test("party", NOW, 10)).to.equal(nil)
		end)
	end)
end
