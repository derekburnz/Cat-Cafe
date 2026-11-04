--!strict
-- The camp extras (F100, camp-extras.md): what each fills and holds, how it waits while shut or full, the Yard Sale's
-- stock and buys, the Lost and Found's table, the prompt and cannon picker lines, and save version 25. QA checks 1, 2,
-- 3 (the tier half; the range half is CampExtraService's), 4, 5 and 6 of section 5 are here; 7 is a Studio row.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CampExtras = require(Shared.CampExtras)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)

	local DAY = 86400
	local T = 20000 * DAY + 3600 -- 01:00 UTC on day 20000
	local HOUR = 3600

	local function half(): number
		return 0.5
	end

	-- A fresh save settled at T for `tier`, everything waiting taken, so each clock starts at T.
	local function emptied(tier: number): any
		local save = CampExtras.fresh(T)
		for _, id in CampExtras.COLLECT do
			CampExtras.take(save, id, tier, T, half)
		end
		return save
	end

	local function at(save: any, tier: number, now: number): any
		CampExtras.settle(save, tier, now)
		return CampExtras.view(save, tier, now)
	end

	describe("which tier opens each (section 1)", function()
		it("opens one extra per rank up from Tier 2, none in the Alleyway", function()
			expect(CampExtras.tierOf("picnic")).to.equal(2)
			expect(CampExtras.tierOf("yardSale")).to.equal(3)
			expect(CampExtras.tierOf("pond")).to.equal(4)
			expect(CampExtras.tierOf("lostFound")).to.equal(5)
			for _, def in Catalog.campExtras do
				expect(def.area).never.to.equal("alley")
				expect(CampExtras.isOpen(def.id, 1)).to.equal(false)
			end
		end)

		it("holds nothing while shut and has one fill waiting the moment its area opens", function()
			local save = CampExtras.fresh(T)
			local shut = at(save, 1, T + 10 * DAY)
			for _, id in { "picnic", "yardSale", "pond", "lostFound" } do
				expect(shut[id].open).to.equal(false)
				expect(shut[id].held).to.equal(0)
			end
			local now = T + 10 * DAY + 60
			local open = at(save, 5, now)
			expect(open.picnic.held).to.equal(1)
			expect(open.pond.held).to.equal(Config.PondFishPerStep)
			expect(open.lostFound.held).to.equal(1)
			expect(open.yardSale.held).to.equal(1)
		end)

		it("refuses the pond to a Tier 3 account and the Yard Sale to Tier 2 (check 3)", function()
			local save = CampExtras.fresh(T)
			CampExtras.settle(save, 3, T)
			expect(CampExtras.collectBlocker(save, "pond", 3, T)).to.equal("The Fish Pond opens at Tier 4")
			local prize = CampExtras.take(save, "pond", 3, T, half)
			expect(prize).to.equal(nil)
			expect(CampExtras.buyBlocker(save, "alley_crate", 2, T)).to.equal("The Yard Sale opens at Tier 3")
			expect(CampExtras.collectBlocker(save, "yardSale", 5, T)).to.equal("There is nothing to collect there")
		end)
	end)

	describe("filling (section 2)", function()
		it("bags one Money Potion every 6 hours up to 2, the clock waiting while it is full", function()
			local save = emptied(2)
			expect(at(save, 2, T + 6 * HOUR - 1).picnic.held).to.equal(0)
			expect(at(save, 2, T + 6 * HOUR).picnic.held).to.equal(1)
			local full = at(save, 2, T + 13 * HOUR)
			expect(full.picnic.held).to.equal(2)
			expect(full.picnic.nextAt).to.equal(nil)
			expect(at(save, 2, T + 20 * HOUR).picnic.held).to.equal(2)
			local prize, count = CampExtras.take(save, "picnic", 2, T + 20 * HOUR, half)
			expect(count).to.equal(2)
			expect(prize :: any).to.deepEqual({ potions = { [Config.PicnicPotion] = 2 } })
			expect(Config.PicnicPotion).to.equal("tip_potion")
			-- the next one counts from the moment it was emptied
			expect(CampExtras.view(save, 2, T + 20 * HOUR).picnic.nextAt).to.equal(T + 26 * HOUR)
		end)

		it("lands 2 golden fish every 30 minutes up to 24, keeping a part step when collected", function()
			local save = emptied(4)
			local view = at(save, 4, T + 45 * 60)
			expect(view.pond.held).to.equal(2)
			expect(view.pond.nextAt).to.equal(T + HOUR)
			local prize = CampExtras.take(save, "pond", 4, T + 45 * 60, half)
			expect(prize :: any).to.deepEqual({ fish = 2 })
			-- the second step still ends at the hour
			expect(at(save, 4, T + HOUR).pond.held).to.equal(2)
			expect(at(save, 4, T + 30 * HOUR).pond.held).to.equal(Config.PondHold)
		end)

		it("keeps one Lost and Found prize a UTC day from midnight, up to 3", function()
			local save = emptied(5)
			expect(at(save, 5, T + 22 * HOUR).lostFound.held).to.equal(0)
			local nextDay = at(save, 5, T + 23 * HOUR)
			expect(nextDay.lostFound.held).to.equal(1)
			expect(nextDay.lostFound.nextAt).to.equal((20000 + 2) * DAY)
			expect(at(save, 5, T + 10 * DAY).lostFound.held).to.equal(Config.LostFoundHold)
			local prize, count = CampExtras.take(save, "lostFound", 5, T + 10 * DAY, half)
			expect(count).to.equal(3)
			expect(prize :: any).to.deepEqual({ potions = { lucky_potion = 3 } }) -- a roll of 0.5 is the Lucky Potion
		end)

		it("finds the pond at 24 and the picnic at 1 after 7 hours away, both with a ! (check 2)", function()
			local save = emptied(5)
			local now = T + 7 * HOUR
			local view = at(save, 5, now)
			expect(view.pond.held).to.equal(24)
			expect(view.picnic.held).to.equal(1)
			local woods, woodsReady = CampExtras.pickerLine(view, "woods", now)
			local park, parkReady = CampExtras.pickerLine(view, "park", now)
			expect(woods).to.equal("Fish Pond: 24 fish !")
			expect(park).to.equal("Picnic Basket: 1 ready !")
			expect(woodsReady and parkReady).to.equal(true)
		end)

		it("says why there is nothing yet and when the next comes", function()
			local save = emptied(2)
			local now = T + 6 * HOUR - 130 * 60
			CampExtras.settle(save, 2, now)
			expect(CampExtras.collectBlocker(save, "picnic", 2, now)).to.equal("Nothing yet. Next in 2 h 10 m")
			expect(CampExtras.take(save, "picnic", 2, now, half)).to.equal(nil)
		end)
	end)

	describe("the Yard Sale (sections 2 and 4)", function()
		it("gives one open zone's crate, the same for everyone on a day, a new zone each day (crate-prices.md 5)", function()
			local zones = { "alley_crate", "park_crate", "neighbourhood_crate" }
			local seen: { [string]: boolean } = {}
			for day = 20000, 20002 do
				local stock = CampExtras.yardStock(3, day)
				expect(stock :: any).to.deepEqual({ zones[day % 3 + 1] })
				expect(CampExtras.yardStock(3, day) :: any).to.deepEqual(stock)
				seen[stock[1]] = true
			end
			for _, crateId in zones do
				expect(seen[crateId]).to.equal(true)
			end
			expect(#CampExtras.yardStock(2, 20000)).to.equal(0)
			-- Tier 5 picks from every area
			for day = 20000, 20004 do
				local zone = CampExtras.yardStock(5, day)[1]
				expect(Catalog.getCrate(zone)).to.be.ok()
				expect((Catalog.getCrate(zone) :: any).golden).to.equal(false)
			end
		end)

		it("gives today's crate free once a day, and a new one the next day (crate-prices.md 5)", function()
			local save = emptied(3)
			local today = CampExtras.day(T)
			local zone = CampExtras.yardStock(3, today)[1]
			expect(CampExtras.buyBlocker(save, zone, 3, T)).to.equal(nil) -- free: no fish needed
			expect(CampExtras.buyBlocker(save, "classic_crate", 3, T)).to.equal(
				"That crate is not at the Yard Sale today"
			)
			expect(CampExtras.buyBlocker(save, "classic_golden_crate", 3, T)).to.equal(
				"That crate is not at the Yard Sale today"
			)
			local before = CampExtras.view(save, 3, T)
			expect(before.yardSale.held).to.equal(1)
			expect((before.yardSale.stock :: any)[1].price).to.equal(0)
			expect((CampExtras.nextYardCrate(before.yardSale) :: any).crateId).to.equal(zone)
			save.yardSale.bought[zone] = true
			expect(CampExtras.buyBlocker(save, zone, 3, T)).to.equal(CampExtras.TAKEN)
			local view = CampExtras.view(save, 3, T)
			expect(view.yardSale.held).to.equal(0)
			expect(CampExtras.nextYardCrate(view.yardSale)).to.equal(nil)
			local tomorrow = at(save, 3, T + DAY)
			expect(tomorrow.yardSale.held).to.equal(1)
			local nextCrate = CampExtras.yardStock(3, today + 1)[1]
			expect(CampExtras.buyBlocker(save, nextCrate, 3, T + DAY)).to.equal(nil)
		end)

		it("shows a ! on the Yard Sale's picker line while the free crate waits (#1051)", function()
			local save = emptied(3)
			local view = at(save, 3, T)
			local line, ready = CampExtras.pickerLine(view, "neighbourhood", T)
			expect(line).to.equal("Yard Sale: free crate !")
			expect(ready).to.equal(true)
			for _, crate in view.yardSale.stock do
				save.yardSale.bought[crate.crateId] = true
			end
			local soldOut, readyAfter = CampExtras.pickerLine(CampExtras.view(save, 3, T), "neighbourhood", T)
			expect(soldOut).to.equal("Yard Sale: new crate in 23 h")
			expect(readyAfter).to.equal(false)
		end)
	end)

	describe("the Lost and Found's table (section 2)", function()
		it("adds up to 1 and pays golden fish, potions and crates the game knows", function()
			local total = 0
			for _, row in Config.LostFoundTable do
				total += row.chance
				if row.potion ~= nil then
					expect(Catalog.getPotion(row.potion)).to.be.ok()
				end
				if row.crate ~= nil then
					expect(Catalog.getCrate(row.crate)).to.be.ok()
				end
			end
			expect(total).to.be.near(1, 1e-9)
		end)

		local function share(rolls: number, roll: (number) -> number): { [string]: number }
			local counts: { [string]: number } = {}
			for i = 1, rolls do
				local prize = CampExtras.lostFoundPrize(roll(i))
				local key = if prize.fish == 10
					then "fish"
					else next(prize.potions or {}) or next(prize.crates or {})
				counts[key :: string] = (counts[key :: string] or 0) + 1
			end
			for key, count in counts do
				counts[key] = count / rolls
			end
			return counts
		end

		local want: { [string]: number } = {
			fish = 0.40,
			lucky_potion = 0.30,
			gold_rush_potion = 0.20,
			classic_crate = 0.09,
			classic_golden_crate = 0.01,
		}

		it("lands exactly on its odds over evenly spread rolls", function()
			local got = share(10000, function(i: number): number
				return (i - 0.5) / 10000
			end)
			for key, chance in want do
				expect(got[key]).to.be.near(chance, 1e-9)
			end
		end)

		it("matches its odds within one point over 10,000 random rolls (check 5)", function()
			-- one fixed seed: a point is about 2.5 standard deviations for the 20% row over 10,000 rolls, so a fixed
			-- draw keeps the check from failing by chance on some runs
			local rng = Random.new(123456789)
			local got = share(10000, function(): number
				return rng:NextNumber()
			end)
			for key, chance in want do
				expect(math.abs((got[key] or 0) - chance) <= 0.01).to.equal(true)
			end
		end)
	end)

	describe("lines (section 3)", function()
		it("shows each extra's line on its area's card in the picker, and none for a shut one (check 1)", function()
			local tier2 = at(emptied(2), 2, T + 6 * HOUR)
			expect(CampExtras.pickerLine(tier2, "alley", T + 6 * HOUR)).to.equal(nil)
			expect(CampExtras.pickerLine(tier2, "park", T + 6 * HOUR)).to.equal("Picnic Basket: 1 ready !")
			expect(CampExtras.pickerLine(tier2, "neighbourhood", T + 6 * HOUR)).to.equal(nil)
			local now = T + 15 * 60
			local tier4 = at(emptied(4), 4, now)
			for _, areaId in { "park", "neighbourhood", "woods" } do
				expect(CampExtras.pickerLine(tier4, areaId, now)).to.be.ok()
			end
			expect(CampExtras.pickerLine(tier4, "sewer", now)).to.equal(nil)
			expect(CampExtras.pickerLine(tier4, "park", now)).to.equal("Picnic Basket: next in 5 h 45 m")
			expect(CampExtras.pickerLine(tier4, "woods", now)).to.equal("Fish Pond: next in 15 m")
		end)

		it("words each prompt with what a press does or when the next fill comes", function()
			local save = emptied(5)
			local now = T + 7 * HOUR
			local view = at(save, 5, now)
			local name, action = CampExtras.promptText("pond", view.pond, now)
			expect(name).to.equal("Fish Pond")
			expect(action).to.equal("Collect 24 fish")
			expect(select(2, CampExtras.promptText("picnic", view.picnic, now))).to.equal("Collect 1 Money Potion")
			expect(select(2, CampExtras.promptText("lostFound", view.lostFound, now))).to.equal("Next in 16 h")
			expect(select(2, CampExtras.promptText("yardSale", view.yardSale, now))).to.equal("Take a free crate")
			local shut = CampExtras.view(CampExtras.fresh(T), 1, T)
			expect(select(2, CampExtras.promptText("pond", shut.pond, T))).to.equal("Opens at Tier 4")
		end)
	end)

	describe("save version 25 (section 4)", function()
		it("makes a damaged save whole: no future times, holds capped, only known crates", function()
			local raw = {
				picnic = { at = T + 999, held = 9 },
				pond = { at = "soon" },
				lostFound = { day = 99999999, held = -2 },
				yardSale = { day = 5, bought = { classic_crate = true, not_a_crate = true, park_crate = "yes" } },
			}
			local save = CampExtras.sanitize(raw, T)
			expect(save.picnic.at).to.equal(T)
			expect(save.picnic.held).to.equal(Config.PicnicHold)
			expect(save.pond.at).to.equal(T - Config.PondStepSeconds)
			expect(save.lostFound.day).to.equal(CampExtras.day(T))
			expect(save.lostFound.held).to.equal(0)
			expect(save.yardSale :: any).to.deepEqual({ day = 5, bought = { classic_crate = true } })
			expect(CampExtras.sanitize(save, T) :: any).to.deepEqual(save)
		end)

		it("gives a version 24 save one fill waiting at each open extra and keeps a version 25 one", function()
			local raw: any = ProfileSchema.template(T)
			raw.version = 24
			raw.campExtras = nil
			local profile = ProfileSchema.migrate(raw, T)
			expect(profile.version).to.equal(ProfileSchema.VERSION)
			expect(profile.campExtras :: any).to.deepEqual(CampExtras.fresh(T))
			profile.campExtras.picnic = { at = T - HOUR, held = 1 }
			profile.campExtras.yardSale.bought.classic_crate = true
			local again = ProfileSchema.migrate(profile, T)
			expect(again.campExtras.picnic :: any).to.deepEqual({ at = T - HOUR, held = 1 })
			expect(again.campExtras.yardSale.bought.classic_crate).to.equal(true)
			expect(ProfileSchema.migrate(again, T) :: any).to.deepEqual(again)
		end)
	end)
end
