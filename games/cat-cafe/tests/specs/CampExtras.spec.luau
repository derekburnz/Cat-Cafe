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

	describe("Picnic Treats (#3715, the picnicTreats switch)", function()
		local function treatsAt(save: any, tier: number, now: number): any
			CampExtras.settle(save, tier, now, true)
			return CampExtras.view(save, tier, now, nil, nil, true)
		end

		it("has three treats, each one earned potion the catalog knows", function()
			expect(#CampExtras.TREATS).to.equal(3)
			local potions: { string } = {}
			for _, treat in CampExtras.TREATS do
				expect(Catalog.getPotion(treat.potion) ~= nil).to.equal(true)
				expect(CampExtras.getTreat(treat.id)).to.equal(treat)
				table.insert(potions, treat.potion)
			end
			expect(table.concat(potions, ",")).to.equal("tip_potion,swift_potion,lucky_potion")
			expect(table.concat(CampExtras.treatIds(), ",")).to.equal("sandwich,lemonade,cupcake")
			expect(CampExtras.getTreat("cake")).to.equal(nil)
		end)

		it("fills one pick every 4 hours and holds one", function()
			expect(Config.PicnicTreatSeconds).to.equal(4 * HOUR)
			expect(Config.PicnicTreatHold).to.equal(1)
			local save = emptied(2)
			local view = treatsAt(save, 2, T + 4 * HOUR - 60).picnic
			expect(view.held).to.equal(0)
			expect(view.nextAt).to.equal(T + 4 * HOUR)
			expect(table.concat(view.treats, ",")).to.equal("sandwich,lemonade,cupcake")
			view = treatsAt(save, 2, T + 4 * HOUR).picnic
			expect(view.held).to.equal(1)
			expect(view.nextAt).to.equal(nil)
			-- a day away is still one pick
			expect(treatsAt(save, 2, T + 30 * HOUR).picnic.held).to.equal(1)
		end)

		it("pays the picked treat's potion once and starts the wait from the pick", function()
			local save = emptied(2)
			local now = T + 9 * HOUR
			local prize, why = CampExtras.pickTreat(save, "lemonade", 2, now)
			expect(why).to.equal(nil)
			expect((prize :: any).potions.swift_potion).to.equal(1)
			expect((prize :: any).potions.tip_potion).to.equal(nil)
			local again, blocker = CampExtras.pickTreat(save, "cupcake", 2, now + 60)
			expect(again).to.equal(nil)
			expect(blocker).to.equal("Next picnic in 3 h 59 m")
			expect(treatsAt(save, 2, now + 60).picnic.nextAt).to.equal(now + 4 * HOUR)
			expect(
				(CampExtras.pickTreat(save, "cupcake", 2, now + 4 * HOUR) :: any).potions.lucky_potion
			).to.equal(1)
		end)

		it(
			"refuses an unknown treat and a player below the Park's tier, and takes nothing",
			function()
				local save = emptied(2)
				local prize, why = CampExtras.pickTreat(save, "pizza", 2, T + 9 * HOUR)
				expect(prize).to.equal(nil)
				expect(why).to.equal("There is no treat like that")
				prize, why = CampExtras.pickTreat(save, "sandwich", 1, T + 9 * HOUR)
				expect(prize).to.equal(nil)
				expect(why).to.equal("Picnic Treats open at Tier 2")
				expect(
					(CampExtras.pickTreat(save, "sandwich", 2, T + 9 * HOUR) :: any).potions.tip_potion
				).to.equal(1)
			end
		)

		it("turns a basket holding two potions into one pick ready now", function()
			local save = emptied(2)
			CampExtras.settle(save, 2, T + 20 * HOUR)
			expect(save.picnic.held).to.equal(2)
			local view = treatsAt(save, 2, T + 20 * HOUR).picnic
			expect(view.held).to.equal(1)
			expect(save.picnic.held).to.equal(1)
		end)

		it(
			"never picks by a walk-up, and words the prompt and the cannon line as a pick",
			function()
				local save = emptied(2)
				local ready = treatsAt(save, 2, T + 5 * HOUR)
				expect(CampExtras.autoClaim("picnic", ready.picnic)).to.equal(nil)
				expect((CampExtras.walkUp("picnic", ready.picnic))).to.equal("treats") -- #3938: its pick card
				local name, action = CampExtras.promptText("picnic", ready.picnic, T + 5 * HOUR)
				expect(name).to.equal("Picnic Treats")
				expect(action).to.equal("Pick one treat")
				local line, bang = CampExtras.pickerLine(ready, "park", T + 5 * HOUR)
				expect(line).to.equal("Picnic Treats: pick one !")
				expect(bang).to.equal(true)
				CampExtras.pickTreat(save, "sandwich", 2, T + 5 * HOUR)
				local waiting = treatsAt(save, 2, T + 5 * HOUR + 60)
				local _, wait = CampExtras.promptText("picnic", waiting.picnic, T + 5 * HOUR + 60)
				expect(wait).to.equal("Next picnic in 3 h 59 m")
				line, bang = CampExtras.pickerLine(waiting, "park", T + 5 * HOUR + 60)
				expect(line).to.equal("Picnic Treats: next in 3 h 59 m")
				expect(bang).to.equal(false)
			end
		)

		it("leaves the basket as it was with the switch off", function()
			local save = emptied(2)
			local view = at(save, 2, T + 20 * HOUR).picnic
			expect(view.held).to.equal(2)
			expect(view.treats).to.equal(nil)
			expect(CampExtras.autoClaim("picnic", view)).to.equal("collect")
		end)
	end)

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
			expect(CampExtras.collectBlocker(save, "pond", 3, T)).to.equal(
				"The Fish Pond opens at Tier 4"
			)
			local prize = CampExtras.take(save, "pond", 3, T, half)
			expect(prize).to.equal(nil)
			expect(CampExtras.buyBlocker(save, "alley_crate", 2, T)).to.equal(
				"The Yard Sale opens at Tier 3"
			)
			expect(CampExtras.collectBlocker(save, "yardSale", 5, T)).to.equal(
				"There is nothing to collect there"
			)
		end)
	end)

	describe("filling (section 2)", function()
		it(
			"bags one Money Potion every 6 hours up to 2, the clock waiting while it is full",
			function()
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
				expect(CampExtras.view(save, 2, T + 20 * HOUR).picnic.nextAt).to.equal(
					T + 26 * HOUR
				)
			end
		)

		it(
			"lands 1 golden fish every 15 minutes up to 24, keeping a part step when collected (#2237)",
			function()
				local save = emptied(4)
				local view = at(save, 4, T + 25 * 60)
				expect(view.pond.held).to.equal(1)
				expect(view.pond.nextAt).to.equal(T + 30 * 60)
				local prize = CampExtras.take(save, "pond", 4, T + 25 * 60, half)
				expect(prize :: any).to.deepEqual({ fish = 1 })
				-- the second step still ends at the half hour
				expect(at(save, 4, T + 30 * 60).pond.held).to.equal(1)
				-- camp-stations.md QA 3 (#2237): 4 after an hour away, 24 and no more after 7 hours
				local away = emptied(4)
				expect(at(away, 4, T + HOUR).pond.held).to.equal(4)
				expect(at(away, 4, T + 7 * HOUR).pond.held).to.equal(24)
				expect(Config.PondHold).to.equal(24)
			end
		)

		it(
			"lands and holds twice the fish for a Golden Pond owner, on the same clock (#3093)",
			function()
				expect(CampExtras.POND_PASS_TIMES).to.equal(2)
				expect(CampExtras.pondTimes(true)).to.equal(2)
				expect(CampExtras.pondTimes(false)).to.equal(1)
				local save = emptied(4)
				local function owner(now: number): any
					CampExtras.settle(save, 4, now)
					return CampExtras.view(save, 4, now, 2)
				end
				expect(owner(T + 14 * 60).pond.held).to.equal(0)
				local first = owner(T + 15 * 60)
				expect(first.pond.held).to.equal(2)
				expect(first.pond.nextAt).to.equal(T + 30 * 60) -- the same step as everyone's
				expect(owner(T + HOUR).pond.held).to.equal(8)
				local full = owner(T + 7 * HOUR)
				expect(full.pond.held).to.equal(48)
				expect(full.pond.nextAt).to.equal(nil) -- full: no "next in"
				-- the same save without the pass shows the plain numbers
				expect(at(save, 4, T + 7 * HOUR).pond.held).to.equal(24)
				local prize, count = CampExtras.take(save, "pond", 4, T + 7 * HOUR, half, 2)
				expect(prize :: any).to.deepEqual({ fish = 48 })
				expect(count).to.equal(48)
				-- emptied: the next fill counts from the collect, for an owner as for anyone
				expect(owner(T + 7 * HOUR).pond.held).to.equal(0)
				expect(owner(T + 7 * HOUR + 15 * 60).pond.held).to.equal(2)
			end
		)

		it("says every extra is used from anywhere (#3082)", function()
			expect(CampExtras.FROM_ANYWHERE).to.equal(true)
		end)

		it("keeps one Lost and Found find every 2 hours, up to 3 (#1732, section 4b)", function()
			expect(Config.LostFoundEverySeconds).to.equal(2 * HOUR)
			expect(Config.LostFoundHold).to.equal(3)
			local save = emptied(5)
			expect(at(save, 5, T + 2 * HOUR - 1).lostFound.held).to.equal(0)
			local first = at(save, 5, T + 2 * HOUR)
			expect(first.lostFound.held).to.equal(1)
			expect(first.lostFound.nextAt).to.equal(T + 4 * HOUR)
			-- section 4b QA: after 7 hours away, 3 are held
			expect(at(save, 5, T + 7 * HOUR).lostFound.held).to.equal(3)
			local full = at(save, 5, T + 10 * DAY)
			expect(full.lostFound.held).to.equal(Config.LostFoundHold)
			expect(full.lostFound.nextAt).to.equal(nil)
			local prize, count, lostCats = CampExtras.take(save, "lostFound", 5, T + 10 * DAY, half)
			expect(count).to.equal(3)
			-- a roll of 0.5 is the Lucky Potion and Gold Rush Potion row
			expect(prize :: any).to.deepEqual({
				potions = { lucky_potion = 3, gold_rush_potion = 3 },
			})
			expect(#lostCats).to.equal(0)
			-- a full one's clock waited, so the next find counts from the take
			expect(at(save, 5, T + 10 * DAY).lostFound.nextAt).to.equal(T + 10 * DAY + 2 * HOUR)
		end)

		-- #3361: a roll in the spins row (after fish 0.30 and potions 0.22), counted
		local function counted(value: number): (() -> number, () -> number)
			local calls = 0
			return function(): number
				calls += 1
				return value
			end, function(): number
				return calls
			end
		end

		it("with no room for spins, a claim rolls nothing and every find waits (#3361)", function()
			local most = CampExtras.lostFoundMaxSpins()
			expect(most).to.equal(2)
			for _, value in { 0.1, 0.5, 0.6, 0.999 } do
				local save = emptied(5)
				at(save, 5, T + 7 * HOUR) -- 3 held
				local roll, calls = counted(value)
				local prize, count =
					CampExtras.take(save, "lostFound", 5, T + 7 * HOUR, roll, nil, most - 1)
				expect(prize).to.equal(nil)
				expect(count).to.equal(0)
				expect(calls()).to.equal(0) -- nothing rolled, so nothing rerolled
				expect(save.lostFound.held).to.equal(3)
			end
		end)

		it("stops by the room left, never by what was rolled (#3361)", function()
			-- room for one find of spins: a spins find uses it up and the other two wait
			local save = emptied(5)
			at(save, 5, T + 7 * HOUR)
			local roll, calls = counted(0.6)
			local some, taken = CampExtras.take(save, "lostFound", 5, T + 7 * HOUR, roll, nil, 2)
			expect(taken).to.equal(1)
			expect(calls()).to.equal(1)
			expect((some :: any).spins).to.equal(2)
			expect(save.lostFound.held).to.equal(2)
			-- the same room with finds that are not spins: all three come, the room never shrinks
			local other = emptied(5)
			at(other, 5, T + 7 * HOUR)
			local potions, potionCalls = counted(0.5)
			local _, all = CampExtras.take(other, "lostFound", 5, T + 7 * HOUR, potions, nil, 2)
			expect(all).to.equal(3)
			expect(potionCalls()).to.equal(3)
			expect(other.lostFound.held).to.equal(0)
			-- with plenty of room the rest of the first save comes at once
			local rest, more = CampExtras.take(save, "lostFound", 5, T + 7 * HOUR, roll, nil, 50)
			expect(more).to.equal(2)
			expect((rest :: any).spins).to.equal(4)
			expect(save.lostFound.held).to.equal(0)
		end)

		it("brings a lost Epic cat for each lostCat row a take lands on", function()
			local save = emptied(5)
			at(save, 5, T + 7 * HOUR)
			local prize, count, lostCats = CampExtras.take(
				save,
				"lostFound",
				5,
				T + 7 * HOUR,
				function(): number
					return 0.999 -- the last row, the lost cat
				end
			)
			expect(count).to.equal(3)
			expect(lostCats :: any).to.deepEqual({ "Epic", "Epic", "Epic" })
			expect(prize :: any).to.deepEqual({})
		end)

		it(
			"finds the pond at 24 and the picnic at 1 after 7 hours away, both with a ! (check 2)",
			function()
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
			end
		)

		it("says why there is nothing yet and when the next comes", function()
			local save = emptied(2)
			local now = T + 6 * HOUR - 130 * 60
			CampExtras.settle(save, 2, now)
			expect(CampExtras.collectBlocker(save, "picnic", 2, now)).to.equal(
				"Nothing yet. Next in 2 h 10 m"
			)
			expect(CampExtras.take(save, "picnic", 2, now, half)).to.equal(nil)
		end)
	end)

	describe("the Yard Sale (sections 2 and 4)", function()
		it(
			"gives one open zone's crate, the same in any server, the next zone each take (crate-prices.md 5, #1154)",
			function()
				local zones = { "alley_crate", "park_crate", "neighbourhood_crate" }
				local seen: { [string]: boolean } = {}
				for claims = 0, 2 do
					local stock = CampExtras.yardStock(3, claims)
					expect(stock :: any).to.deepEqual({ zones[claims % 3 + 1] })
					expect(CampExtras.yardStock(3, claims) :: any).to.deepEqual(stock)
					seen[stock[1]] = true
				end
				for _, crateId in zones do
					expect(seen[crateId]).to.equal(true)
				end
				expect(#CampExtras.yardStock(2, 0)).to.equal(0)
				-- Tier 5 picks from every area
				for claims = 0, 4 do
					local zone = CampExtras.yardStock(5, claims)[1]
					expect(Catalog.getCrate(zone)).to.be.ok()
					expect((Catalog.getCrate(zone) :: any).golden).to.equal(false)
				end
			end
		)

		it(
			"gives a free crate every 4 hours from the last take, holding 1 (camp-stations.md QA 2)",
			function()
				local save = emptied(3)
				expect(Config.YardSaleClaimHours).to.equal(4)
				local zone = CampExtras.yardStock(3, save.yardSale.claims)[1]
				expect(CampExtras.buyBlocker(save, zone, 3, T)).to.equal(nil) -- free: no fish needed
				expect(CampExtras.buyBlocker(save, "classic_crate", 3, T)).to.equal(
					"That crate is not at the Yard Sale now"
				)
				expect(CampExtras.buyBlocker(save, "classic_golden_crate", 3, T)).to.equal(
					"That crate is not at the Yard Sale now"
				)
				local before = CampExtras.view(save, 3, T)
				expect(before.yardSale.held).to.equal(1)
				expect(before.yardSale.nextAt).to.equal(nil)
				expect((before.yardSale.stock :: any)[1].price).to.equal(0)
				expect((CampExtras.nextYardCrate(before.yardSale) :: any).crateId).to.equal(zone)
				-- a take, as CampExtraService does it
				save.yardSale.lastClaimAt = T
				save.yardSale.claims += 1
				local nextZone = CampExtras.yardStock(3, save.yardSale.claims)[1]
				expect(nextZone).never.to.equal(zone)
				expect(CampExtras.buyBlocker(save, nextZone, 3, T + 4 * HOUR - 60)).to.equal(
					CampExtras.TAKEN .. ". A new one in 1 m"
				)
				expect(CampExtras.buyBlocker(save, nextZone, 3, T + 1)).to.equal(
					CampExtras.TAKEN .. ". A new one in 4 h"
				)
				local view = CampExtras.view(save, 3, T + HOUR)
				expect(view.yardSale.held).to.equal(0)
				expect(view.yardSale.nextAt).to.equal(T + 4 * HOUR)
				expect(CampExtras.nextYardCrate(view.yardSale)).to.equal(nil)
				-- a rank up can move the crate to another zone: still one take per wait (#1051 review)
				for tier = 4, 5 do
					local other = CampExtras.yardStock(tier, save.yardSale.claims)[1]
					expect(
						string.find(
							CampExtras.buyBlocker(save, other, tier, T + HOUR) or "",
							CampExtras.TAKEN,
							1,
							true
						)
					).to.equal(1)
					expect(CampExtras.view(save, tier, T + HOUR).yardSale.held).to.equal(0)
				end
				-- at 4 h it works, and a long wait still holds just 1
				expect(CampExtras.buyBlocker(save, nextZone, 3, T + 4 * HOUR)).to.equal(nil)
				expect(at(save, 3, T + 40 * HOUR).yardSale.held).to.equal(1)
			end
		)

		it("shows a ! on the Yard Sale's picker line while the free crate waits (#1051)", function()
			local save = emptied(3)
			local view = at(save, 3, T)
			local line, ready = CampExtras.pickerLine(view, "neighbourhood", T)
			expect(line).to.equal("Yard Sale: free crate !")
			expect(ready).to.equal(true)
			-- #3615: with the lucky pick on, the line and the prompt name the pick, not a crate
			local picking = at(save, 3, T)
			picking.yardSale.pick = {}
			expect((CampExtras.pickerLine(picking, "neighbourhood", T))).to.equal(
				"Yard Sale: free lucky pick !"
			)
			expect(select(2, CampExtras.promptText("yardSale", picking.yardSale, T))).to.equal(
				"Free lucky pick"
			)
			save.yardSale.lastClaimAt = T
			save.yardSale.claims += 1
			local soldOut, readyAfter =
				CampExtras.pickerLine(CampExtras.view(save, 3, T), "neighbourhood", T)
			expect(soldOut).to.equal("Yard Sale: new crate in 4 h")
			expect(readyAfter).to.equal(false)
		end)
	end)

	describe("the Lost and Found's table (section 2)", function()
		it(
			"adds up to 1 and pays golden fish, potions, spins, crates and cats the game knows",
			function()
				local total = 0
				for _, row in Config.LostFoundTable do
					total += row.chance
					for potionId in row.potions or {} do
						expect(Catalog.getPotion(potionId)).to.be.ok()
					end
					if row.crate ~= nil then
						expect(Catalog.getCrate(row.crate)).to.be.ok()
					end
					if row.lostCat ~= nil then
						expect(Catalog.rarityRank[row.lostCat]).to.be.ok()
					end
				end
				expect(total).to.be.near(1, 1e-9)
			end
		)

		it("pays the section 4b finds", function()
			local function find(roll: number): (any, string?)
				return CampExtras.lostFoundPrize(roll)
			end
			expect(find(0.15) :: any).to.deepEqual({ fish = 25 }) -- #2237: was 40
			expect(find(0.4) :: any).to.deepEqual({
				potions = { lucky_potion = 1, gold_rush_potion = 1 },
			})
			expect(find(0.6) :: any).to.deepEqual({ spins = 2 })
			expect(find(0.75) :: any).to.deepEqual({ crates = { sewer_crate = 1 } })
			expect(find(0.9) :: any).to.deepEqual({ crates = { classic_golden_crate = 1 } })
			expect(find(0.96) :: any).to.deepEqual({ crates = { sewer_golden_crate = 1 } })
			local prize, lostCat = find(0.99)
			expect(prize :: any).to.deepEqual({})
			expect(lostCat).to.equal("Epic")
			-- a table row's potions are copied, so merging finds never changes Config
			local merged = CampExtras.merge(find(0.4), find(0.4))
			expect(merged.potions :: any).to.deepEqual({ lucky_potion = 2, gold_rush_potion = 2 })
			expect(Config.LostFoundTable[2].potions :: any).to.deepEqual({
				lucky_potion = 1,
				gold_rush_potion = 1,
			})
			expect(CampExtras.merge({ spins = 2 }, { spins = 2 }).spins).to.equal(4)
		end)

		local function share(rolls: number, roll: (number) -> number): { [string]: number }
			local counts: { [string]: number } = {}
			for i = 1, rolls do
				local prize, lostCat = CampExtras.lostFoundPrize(roll(i))
				local key = if lostCat ~= nil
					then "lostCat"
					elseif prize.fish ~= nil then "fish"
					elseif prize.potions ~= nil then "potions"
					elseif prize.spins ~= nil then "spins"
					else next(prize.crates or {})
				counts[key :: string] = (counts[key :: string] or 0) + 1
			end
			for key, count in counts do
				counts[key] = count / rolls
			end
			return counts
		end

		local want: { [string]: number } = {
			fish = 0.30,
			potions = 0.22,
			spins = 0.15,
			sewer_crate = 0.18,
			classic_golden_crate = 0.10,
			sewer_golden_crate = 0.03,
			lostCat = 0.02,
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

	describe("walk-up claims (#2498)", function()
		it(
			"takes what waits at the basket, pond and lost and found, and nothing while empty or shut",
			function()
				local fresh = at(CampExtras.fresh(T), 5, T)
				for _, id in CampExtras.COLLECT do
					local view = (fresh :: any)[id]
					expect(view.held > 0).to.equal(true)
					expect((CampExtras.autoClaim(id, view))).to.equal("collect")
				end
				local empty = CampExtras.view(emptied(5), 5, T)
				for _, id in CampExtras.COLLECT do
					expect((CampExtras.autoClaim(id, (empty :: any)[id]))).to.equal(nil)
				end
				local shut = at(CampExtras.fresh(T), 1, T)
				expect((CampExtras.autoClaim("pond", shut.pond))).to.equal(nil)
			end
		)

		it("takes the Yard Sale's free crate while it waits, and nothing once taken", function()
			local save = CampExtras.fresh(T)
			local view = at(save, 3, T).yardSale
			local how, crateId = CampExtras.autoClaim(CampExtras.YARD_SALE, view)
			expect(how).to.equal("yard")
			expect(crateId).to.equal((CampExtras.nextYardCrate(view) :: any).crateId)
			local taken = table.clone(view)
			taken.held = 0
			expect((CampExtras.autoClaim(CampExtras.YARD_SALE, taken))).to.equal(nil)
			local unknown = { open = true, held = 1 }
			expect((CampExtras.autoClaim("mystery", unknown :: any))).to.equal(nil)
			-- #3615: a lucky pick is pressed on the card, never spent by walking up
			local pick = table.clone(view) :: any
			pick.pick = { { crateId = "classic_crate", chance = 100 } }
			expect((CampExtras.autoClaim(CampExtras.YARD_SALE, pick))).to.equal(nil)
		end)

		it("opens the station's card when nothing waits, or it is shut (#3938)", function()
			local fresh = at(CampExtras.fresh(T), 5, T)
			for _, id in CampExtras.COLLECT do
				expect((CampExtras.walkUp(id, (fresh :: any)[id]))).to.equal("collect")
			end
			local empty = CampExtras.view(emptied(5), 5, T)
			for _, id in CampExtras.COLLECT do
				expect((CampExtras.walkUp(id, (empty :: any)[id]))).to.equal("info")
			end
			local shut = at(CampExtras.fresh(T), 1, T)
			expect((CampExtras.walkUp("pond", shut.pond))).to.equal("info")
			expect((CampExtras.walkUp(CampExtras.YARD_SALE, shut.yardSale))).to.equal("info")
			-- the Yard Sale: its free crate as before, else its own card (a lucky pick is pressed there)
			local yard = at(CampExtras.fresh(T), 3, T).yardSale
			local how, crateId = CampExtras.walkUp(CampExtras.YARD_SALE, yard)
			expect(how).to.equal("yard")
			expect(crateId).to.equal((CampExtras.nextYardCrate(yard) :: any).crateId)
			local taken = table.clone(yard)
			taken.held = 0
			expect((CampExtras.walkUp(CampExtras.YARD_SALE, taken))).to.equal("yardCard")
			local pick = table.clone(yard) :: any
			pick.pick = { { crateId = "classic_crate", chance = 100 } }
			expect((CampExtras.walkUp(CampExtras.YARD_SALE, pick))).to.equal("yardCard")
		end)
	end)

	describe("lines (section 3)", function()
		it(
			"shows each extra's line on its area's card in the picker, and none for a shut one (check 1)",
			function()
				local tier2 = at(emptied(2), 2, T + 6 * HOUR)
				expect(CampExtras.pickerLine(tier2, "alley", T + 6 * HOUR)).to.equal(nil)
				expect(CampExtras.pickerLine(tier2, "park", T + 6 * HOUR)).to.equal(
					"Picnic Basket: 1 ready !"
				)
				expect(CampExtras.pickerLine(tier2, "neighbourhood", T + 6 * HOUR)).to.equal(nil)
				local now = T + 5 * 60 -- inside the pond's first 15 minute step (#2237)
				local tier4 = at(emptied(4), 4, now)
				for _, areaId in { "park", "neighbourhood", "woods" } do
					expect(CampExtras.pickerLine(tier4, areaId, now)).to.be.ok()
				end
				expect(CampExtras.pickerLine(tier4, "sewer", now)).to.equal(nil)
				expect(CampExtras.pickerLine(tier4, "park", now)).to.equal(
					"Picnic Basket: next in 5 h 55 m"
				)
				expect(CampExtras.pickerLine(tier4, "woods", now)).to.equal(
					"Fish Pond: next in 10 m"
				)
			end
		)

		it("words each prompt with what a press does or when the next fill comes", function()
			local save = emptied(5)
			local now = T + 7 * HOUR
			local view = at(save, 5, now)
			local name, action = CampExtras.promptText("pond", view.pond, now)
			expect(name).to.equal("Fish Pond")
			expect(action).to.equal("Collect 24 fish")
			expect(select(2, CampExtras.promptText("picnic", view.picnic, now))).to.equal(
				"Collect 1 Money Potion"
			)
			expect(select(2, CampExtras.promptText("lostFound", view.lostFound, now))).to.equal(
				"Collect 3 finds"
			)
			local soon = at(emptied(5), 5, T + HOUR)
			expect(select(2, CampExtras.promptText("lostFound", soon.lostFound, T + HOUR))).to.equal(
				"Next in 1 h"
			)
			expect(select(2, CampExtras.promptText("yardSale", view.yardSale, now))).to.equal(
				"Take a free crate"
			)
			local shut = at(CampExtras.fresh(T), 1, T)
			expect(select(2, CampExtras.promptText("pond", shut.pond, T))).to.equal(
				"Opens at Tier 4"
			)
		end)
	end)

	describe("save version 25 (section 4)", function()
		it(
			"turns a version 39 Lost and Found into { at, held } at the load, keeping what it held (#1732)",
			function()
				local save =
					CampExtras.sanitize({ lostFound = { day = CampExtras.day(T), held = 2 } }, T)
				expect(save.lostFound :: any).to.deepEqual({ at = T, held = 2 })
				local damaged = CampExtras.sanitize({ lostFound = { at = T + 999, held = 9 } }, T)
				expect(damaged.lostFound :: any).to.deepEqual({
					at = T,
					held = Config.LostFoundHold,
				})
				local kept = CampExtras.sanitize({ lostFound = { at = T - 600, held = 1 } }, T)
				expect(kept.lostFound :: any).to.deepEqual({ at = T - 600, held = 1 })
			end
		)

		it(
			"makes a damaged save whole: no future times, holds capped, only known crates",
			function()
				local raw = {
					picnic = { at = T + 999, held = 9 },
					pond = { at = "soon" },
					lostFound = { day = 99999999, held = -2 },
					yardSale = { lastClaimAt = T + 999, claims = -3 },
				}
				local save = CampExtras.sanitize(raw, T)
				expect(save.picnic.at).to.equal(T)
				expect(save.picnic.held).to.equal(Config.PicnicHold)
				expect(save.pond.at).to.equal(T - Config.PondStepSeconds)
				expect(save.lostFound.at).to.equal(T) -- an old { day, held } starts its clock at the load
				expect(save.lostFound.held).to.equal(0)
				expect(save.yardSale :: any).to.deepEqual({ lastClaimAt = T, claims = 0 })
				expect(CampExtras.sanitize(save, T) :: any).to.deepEqual(save)
			end
		)

		it(
			"gives a version 24 save one fill waiting at each open extra and keeps a version 25 one",
			function()
				local raw: any = ProfileSchema.template(T)
				raw.version = 24
				raw.campExtras = nil
				local profile = ProfileSchema.migrate(raw, T)
				expect(profile.version).to.equal(ProfileSchema.VERSION)
				expect(profile.campExtras :: any).to.deepEqual(CampExtras.fresh(T))
				profile.campExtras.picnic = { at = T - HOUR, held = 1 }
				profile.campExtras.yardSale = { lastClaimAt = T - HOUR, claims = 4 }
				local again = ProfileSchema.migrate(profile, T)
				expect(again.campExtras.picnic :: any).to.deepEqual({ at = T - HOUR, held = 1 })
				expect(again.campExtras.yardSale :: any).to.deepEqual({
					lastClaimAt = T - HOUR,
					claims = 4,
				})
				expect(ProfileSchema.migrate(again, T) :: any).to.deepEqual(again)
			end
		)
	end)

	describe("save version 33 (#1154, camp-stations.md section 3)", function()
		local today = CampExtras.day(T)

		it(
			"makes a version 32 Yard Sale that took today's crate wait 4 h from the start of that UTC day",
			function()
				local raw: any = ProfileSchema.template(T)
				raw.version = 32
				raw.campExtras.yardSale = { day = today, bought = { park_crate = true } }
				local profile = ProfileSchema.migrate(raw, T)
				expect(profile.version).to.equal(ProfileSchema.VERSION) -- 33 then, 34 since the second bowl (#1161)
				expect(profile.campExtras.yardSale :: any).to.deepEqual({
					lastClaimAt = today * DAY,
					claims = today + 1,
				})
				local zone = CampExtras.yardStock(3, profile.campExtras.yardSale.claims)[1]
				-- T is 01:00 UTC: refused until 04:00, then free
				expect(CampExtras.buyBlocker(profile.campExtras, zone, 3, T)).to.equal(
					CampExtras.TAKEN .. ". A new one in 3 h"
				)
				expect(CampExtras.buyBlocker(profile.campExtras, zone, 3, today * DAY + 4 * HOUR)).to.equal(
					nil
				)
			end
		)

		it("lets a version 32 Yard Sale that took no crate today take one at once", function()
			for _, yard in
				{
					{ day = today - 1, bought = { park_crate = true } },
					{ day = today, bought = {} },
				}
			do
				local raw: any = ProfileSchema.template(T)
				raw.version = 32
				raw.campExtras.yardSale = yard
				local profile = ProfileSchema.migrate(raw, T)
				expect(profile.campExtras.yardSale.lastClaimAt).to.equal(0)
				local zone = CampExtras.yardStock(3, profile.campExtras.yardSale.claims)[1]
				expect(CampExtras.buyBlocker(profile.campExtras, zone, 3, T)).to.equal(nil)
			end
		end)
	end)
end
