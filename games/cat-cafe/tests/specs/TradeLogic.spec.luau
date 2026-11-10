--!strict
-- UI/Components/TradeLogic.luau: what the trade window, the request card and the players list say and which buttons
-- can be pressed (F102, trading.md sections 2 and 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local TradeLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("TradeLogic")
	) :: any

	local NOW = 5000

	local function side(name: string, extra: { [string]: any }?): any
		local data: { [string]: any } = {
			userId = if name == "You" then 1 else 2,
			name = name,
			ready = false,
			confirmed = false,
			cats = {
				{
					uid = name .. "_1",
					catId = "tabby",
					rarity = "Common",
					level = 1,
					rateForMe = 10,
				},
			},
		}
		for key, value in extra or {} do
			data[key] = value
		end
		return data
	end

	local function trade(extra: { [string]: any }?): any
		local state: { [string]: any } = {
			tradeId = "t1",
			version = 1,
			phase = "offer",
			me = side("You"),
			them = side("Sam"),
			giveValue = 100,
			getValue = 100,
			lopsided = false,
			gift = false,
			myRateNow = 184,
			theirRateForMe = 1490,
		}
		for key, value in extra or {} do
			state[key] = value
		end
		return state
	end

	describe("TradeLogic.minTier and shown", function()
		it("reads the live attribute, else Config's minimum", function()
			expect(TradeLogic.minTier(5)).to.equal(5)
			expect(TradeLogic.minTier(nil)).to.equal(TradeLogic.minTier("x"))
			expect(TradeLogic.minTier(nil) >= 1).to.equal(true)
		end)

		it("shows the HUD tile from the minimum tier, never before the tier is known", function()
			expect(TradeLogic.shown(3, 3)).to.equal(true)
			expect(TradeLogic.shown(4, 3)).to.equal(true)
			expect(TradeLogic.shown(2, 3)).to.equal(false)
			expect(TradeLogic.shown(nil, 1)).to.equal(false)
		end)

		it("says which tier opens the greyed tile (#2462)", function()
			expect(TradeLogic.lockedText(3)).to.equal("Unlocks at Tier 3")
			expect(TradeLogic.lockedText(5)).to.equal("Unlocks at Tier 5")
		end)
	end)

	describe("TradeLogic.compact and rate", function()
		it("cuts numbers down to fit a card and never rounds up", function()
			expect(TradeLogic.compact(950)).to.equal("950")
			expect(TradeLogic.compact(1000)).to.equal("1K")
			expect(TradeLogic.compact(1299)).to.equal("1.2K")
			expect(TradeLogic.compact(12999)).to.equal("12K")
			expect(TradeLogic.compact(1500000)).to.equal("1.5M")
			expect(TradeLogic.compact(-5)).to.equal("0")
			expect(TradeLogic.compact(9.7)).to.equal("9")
		end)

		it("puts a plus on what their cats would earn for you", function()
			expect(TradeLogic.rate(24, false)).to.equal("$24/s")
			expect(TradeLogic.rate(1200, true)).to.equal("+$1.2K/s")
		end)
	end)

	describe("TradeLogic.totals", function()
		it("says what your cats earn now and what theirs would earn in your cafe", function()
			local give, get = TradeLogic.totals(trade())
			expect(give).to.equal("Your cats: $184/s now")
			expect(string.find(get, "Their cats: +$", 1, true)).to.equal(1)
			expect(string.find(get, "/s in your cafe", 1, true) ~= nil).to.equal(true)
		end)

		it("reads zero when the server leaves a rate out", function()
			local state = trade()
			state.myRateNow = nil
			state.theirRateForMe = nil
			local give, get = TradeLogic.totals(state)
			expect(give).to.equal("Your cats: $0/s now")
			expect(get).to.equal("Their cats: +$0/s in your cafe")
		end)
	end)

	describe("TradeLogic.headline and countdown", function()
		it("asks for cats first, then for Ready from whoever has not pressed it", function()
			expect(TradeLogic.headline(trade(), NOW)).to.equal("Add cats, then press Ready")
			expect(TradeLogic.headline(trade({ me = side("You", { ready = true }) }), NOW)).to.equal(
				"Waiting for Sam to press Ready"
			)
			expect(TradeLogic.headline(trade({ them = side("Sam", { ready = true }) }), NOW)).to.equal(
				"Sam is ready. Press Ready when you are"
			)
		end)

		it("counts down whole seconds and never shows zero", function()
			local state = trade({ phase = "countdown", countdownEndsAt = NOW + 2.4 })
			expect(TradeLogic.countdown(state, NOW)).to.equal(3)
			expect(TradeLogic.headline(state, NOW)).to.equal("Both ready! Trading in 3...")
			expect(TradeLogic.countdown(state, NOW + 5)).to.equal(1)
			expect(TradeLogic.countdown(trade(), NOW)).to.equal(nil)
		end)

		it("walks the confirm screen from check to waiting", function()
			expect(TradeLogic.headline(trade({ phase = "confirm" }), NOW)).to.equal(
				"Check the trade, then confirm"
			)
			local theirs = trade({ phase = "confirm", them = side("Sam", { confirmed = true }) })
			expect(TradeLogic.headline(theirs, NOW)).to.equal(
				"Sam confirmed. Check it, then confirm"
			)
			local mine = trade({ phase = "confirm", me = side("You", { confirmed = true }) })
			expect(TradeLogic.headline(mine, NOW)).to.equal("Waiting for Sam to confirm")
		end)
	end)

	describe("TradeLogic.readyButton", function()
		it("is Ready, greyed while both offers are empty", function()
			local button = TradeLogic.readyButton(trade())
			expect(button.text).to.equal("Ready")
			expect(button.enabled).to.equal(true)
			expect(button.ready).to.equal(true)
			local empty = TradeLogic.readyButton(
				trade({ me = side("You", { cats = {} }), them = side("Sam", { cats = {} }) })
			)
			expect(empty.enabled).to.equal(false)
		end)

		it("turns into Not ready once pressed or while the countdown runs", function()
			local pressed = TradeLogic.readyButton(trade({ me = side("You", { ready = true }) }))
			expect(pressed.text).to.equal("Not ready")
			expect(pressed.ready).to.equal(false)
			local counting =
				TradeLogic.readyButton(trade({ phase = "countdown", countdownEndsAt = NOW + 3 }))
			expect(counting.text).to.equal("Not ready")
			expect(counting.style).to.equal("ghost")
		end)
	end)

	describe("TradeLogic.warning and confirmButton", function()
		it("warns on a gift before a lopsided trade, and says nothing on a fair one", function()
			expect(TradeLogic.warning(trade({ gift = true, lopsided = true }))).to.equal(
				"You get nothing back"
			)
			expect(TradeLogic.warning(trade({ lopsided = true }))).to.equal(
				"You're giving much more than you get. Are you sure?"
			)
			expect(TradeLogic.warning(trade())).to.equal(nil)
		end)

		it("holds Confirm for the first seconds of a warning", function()
			local state = trade({ phase = "confirm", lopsided = true })
			local early = TradeLogic.confirmButton(state, 0.2)
			expect(early.text).to.equal("Confirm (2)")
			expect(early.enabled).to.equal(false)
			expect(early.style).to.equal("danger")
			local later = TradeLogic.confirmButton(state, TradeLogic.CONFIRM_WAIT)
			expect(later.text).to.equal("Confirm")
			expect(later.enabled).to.equal(true)
			expect(later.style).to.equal("danger")
		end)

		it("follows the server's confirmAt over the screen's own clock (#850)", function()
			local state = trade({ phase = "confirm", gift = true })
			state.confirmAt = 1000
			local early = TradeLogic.confirmButton(state, 5, 998.5)
			expect(early.text).to.equal("Confirm (2)")
			expect(early.enabled).to.equal(false)
			expect(early.style).to.equal("danger")
			local open = TradeLogic.confirmButton(state, 0, 1000)
			expect(open.text).to.equal("Confirm")
			expect(open.enabled).to.equal(true)
			-- an odd confirmAt far ahead still waits at most CONFIRM_WAIT; NaN falls back to the screen's clock
			state.confirmAt = 1e9
			expect(TradeLogic.confirmButton(state, 0, 1000).text).to.equal(
				string.format("Confirm (%d)", TradeLogic.CONFIRM_WAIT)
			)
			state.confirmAt = 0 / 0
			expect(TradeLogic.confirmButton(state, TradeLogic.CONFIRM_WAIT, 1000).enabled).to.equal(
				true
			)
		end)

		it("lets a fair trade confirm at once, then waits on the other player", function()
			local fair = TradeLogic.confirmButton(trade({ phase = "confirm" }), 0)
			expect(fair.enabled).to.equal(true)
			expect(fair.style).to.equal("primary")
			local mine = TradeLogic.confirmButton(
				trade({ phase = "confirm", me = side("You", { confirmed = true }) }),
				5
			)
			expect(mine.text).to.equal("Waiting for Sam")
			expect(mine.enabled).to.equal(false)
		end)
	end)

	describe("TradeLogic.changed", function()
		it("flashes a change for CHANGED_SECONDS, then lets it go", function()
			local state = trade({ changed = { side = "them", uid = "Sam_1", at = NOW } })
			local change = TradeLogic.changed(state, NOW + 0.5)
			expect(change.side).to.equal("them")
			expect(change.uid).to.equal("Sam_1")
			expect(TradeLogic.changed(state, NOW + TradeLogic.CHANGED_SECONDS)).to.equal(nil)
			expect(TradeLogic.changed(trade(), NOW)).to.equal(nil)
		end)

		it("puts up with a server clock a little ahead, not far ahead", function()
			local state = trade({ changed = { side = "me", uid = "You_1", at = NOW + 0.5 } })
			expect(TradeLogic.changed(state, NOW) ~= nil).to.equal(true)
			local far = trade({ changed = { side = "me", uid = "You_1", at = NOW + 5 } })
			expect(TradeLogic.changed(far, NOW)).to.equal(nil)
		end)
	end)

	describe("TradeLogic.myCats", function()
		local defs: { [string]: any } = {
			tabby = { name = "Tabby", rarity = "Common" },
			moon = { name = "Moon Cat", rarity = "Epic" },
			star = { name = "Star Cat", rarity = "Legendary" },
			bell = { name = "Bellhop Cat", rarity = "Rare", exclusive = true },
		}
		local function defOf(catId: string): any
			return defs[catId]
		end

		it("lists the rarest first, gold and rainbow coats ahead, then level", function()
			local picks = TradeLogic.myCats({
				a = { uid = "a", catId = "tabby", level = 9 },
				b = { uid = "b", catId = "moon", level = 1 },
				c = { uid = "c", catId = "moon", level = 1, variant = "gold" },
				d = { uid = "d", catId = "moon", level = 1, variant = "rainbow" },
				e = { uid = "e", catId = "star", level = 2 },
				f = { uid = "f", catId = "moon", level = 4 },
			}, defOf, {})
			local order = {}
			for _, pick in picks do
				table.insert(order, pick.uid)
			end
			expect(table.concat(order, ",")).to.equal("e,d,c,f,b,a")
		end)

		it("sends locked and exclusive cats to the end, each with its reason", function()
			local picks = TradeLogic.myCats({
				a = { uid = "a", catId = "star", locked = true },
				b = { uid = "b", catId = "bell" },
				c = { uid = "c", catId = "tabby" },
				d = { uid = "d", catId = "moon" },
				x = { uid = "x", catId = "unknown" },
			}, defOf, { d = true })
			expect(#picks).to.equal(4)
			expect(picks[1].uid).to.equal("d")
			expect(picks[1].status).to.equal("offered")
			expect(picks[2].uid).to.equal("c")
			expect(picks[3].status).to.equal("locked")
			expect(picks[4].status).to.equal("exclusive")
			expect(TradeLogic.pickHint(picks[3], false)).to.equal("Unlock it on its card to trade")
			expect(TradeLogic.pickHint(picks[4], false)).to.equal("This cat can't be traded")
			expect(TradeLogic.pickHint(picks[2], false)).to.equal(nil)
			expect(TradeLogic.pickHint(picks[2], true)).to.equal(
				string.format("Up to %d cats a trade", TradeLogic.MAX_CATS)
			)
			expect(TradeLogic.pickHint(picks[1], true)).to.equal(nil)
		end)

		it("uses a cat's own name and reads a missing list as empty", function()
			local picks = TradeLogic.myCats(
				{ a = { uid = "a", catId = "tabby", name = "Biscuit" } },
				defOf,
				{}
			)
			expect(picks[1].name).to.equal("Biscuit")
			expect(picks[1].level).to.equal(1)
			expect(#TradeLogic.myCats(nil, defOf, {})).to.equal(0)
		end)
	end)

	describe("TradeLogic.playerButton", function()
		it("says Asked, Busy or the tier needed, else Trade", function()
			expect(TradeLogic.playerButton({ tier = 5, asked = true, trading = true }, 3).text).to.equal(
				"Asked"
			)
			expect(TradeLogic.playerButton({ tier = 5, asked = false, trading = true }, 3).text).to.equal(
				"Busy"
			)
			local low = TradeLogic.playerButton({ tier = 2, asked = false }, 3)
			expect(low.text).to.equal("Tier 3 needed")
			expect(low.enabled).to.equal(false)
			local ok = TradeLogic.playerButton({ tier = 3, asked = false }, 3)
			expect(ok.text).to.equal("Trade")
			expect(ok.enabled).to.equal(true)
			expect(TradeLogic.playerButton({ asked = false }, 3).enabled).to.equal(true)
		end)
	end)

	describe("TradeLogic.requestsMode", function()
		it("shows the saved choice, else Everyone", function()
			expect(TradeLogic.requestsMode("friends", nil, 0)).to.equal("friends")
			expect(TradeLogic.requestsMode("off", nil, 0)).to.equal("off")
			expect(TradeLogic.requestsMode(nil, nil, 0)).to.equal("everyone")
			expect(TradeLogic.requestsMode("nonsense", nil, 0)).to.equal("everyone")
			expect(TradeLogic.requestsMode(true, nil, 0)).to.equal("everyone")
		end)

		it("holds a fresh press until the server agrees or the hold runs out", function()
			local tap = { value = "off", at = 10 }
			expect(TradeLogic.requestsMode("everyone", tap, 11)).to.equal("off")
			expect(TradeLogic.requestsMode("everyone", tap, 10 + TradeLogic.HOLD_SECONDS)).to.equal(
				"everyone"
			)
			expect(TradeLogic.requestsMode("off", tap, 11)).to.equal("off")
			expect(TradeLogic.requestsMode(nil, tap, 999)).to.equal("off")
		end)

		it("labels the three choices", function()
			local labels: { string } = {}
			for _, mode in TradeLogic.REQUEST_MODES do
				local label: string = TradeLogic.modeLabel(mode)
				table.insert(labels, label)
			end
			expect(table.concat(labels, ",")).to.equal("Everyone,Friends only,Off")
		end)
	end)

	describe("TradeLogic.ago", function()
		it("reads minutes, hours, yesterday, days, then weeks", function()
			expect(TradeLogic.ago(NOW - 20, NOW)).to.equal("Just now")
			expect(TradeLogic.ago(NOW + 30, NOW)).to.equal("Just now")
			expect(TradeLogic.ago(NOW - 12 * 60, NOW)).to.equal("12m ago")
			expect(TradeLogic.ago(NOW - 3 * 3600 - 59, NOW)).to.equal("3h ago")
			expect(TradeLogic.ago(NOW - 30 * 3600, NOW)).to.equal("Yesterday")
			expect(TradeLogic.ago(NOW - 4 * 86400, NOW)).to.equal("4 days ago")
			expect(TradeLogic.ago(NOW - 21 * 86400, NOW)).to.equal("3 weeks ago")
		end)
	end)

	describe("TradeLogic.logRows", function()
		local BIG = 10000000

		it("lists the newest first with who and when", function()
			local rows = TradeLogic.logRows({
				{
					id = "a",
					at = BIG - 7200,
					partnerName = "Sam",
					gave = { { catId = "tabby", rarity = "Common", level = 2 } },
					got = {},
				},
				{
					id = "b",
					at = BIG - 60,
					partnerName = "Mia",
					gave = {},
					got = { { catId = "moon", rarity = "Epic", variant = "gold", level = 5 } },
				},
			}, BIG)
			expect(#rows).to.equal(2)
			expect(rows[1].id).to.equal("b")
			expect(rows[1].partner).to.equal("With Mia")
			expect(rows[1].when).to.equal("1m ago")
			expect(#rows[1].gave).to.equal(0)
			expect(rows[1].got[1].variant).to.equal("gold")
			expect(rows[2].partner).to.equal("With Sam")
			expect(rows[2].when).to.equal("2h ago")
			expect(rows[2].gave[1].level).to.equal(2)
		end)

		it("keeps the last 20 and drops broken entries and cats", function()
			local log: { any } = {}
			for index = 1, 25 do
				table.insert(
					log,
					{
						id = "t" .. index,
						at = BIG - index,
						partnerName = "Sam",
						gave = {},
						got = {},
					}
				)
			end
			table.insert(log, { at = BIG, partnerName = "No id" })
			table.insert(log, { id = "no_time", partnerName = "No time" })
			table.insert(log, "junk")
			table.insert(log, {
				id = "odd",
				at = BIG - 100,
				partnerName = "",
				gave = { { rarity = "Rare" }, { catId = "tabby" }, "junk" },
				got = "junk",
			})
			local rows = TradeLogic.logRows(log, BIG)
			expect(#rows).to.equal(TradeLogic.LOG_MAX)
			expect(rows[1].id).to.equal("t1")
			local odd = TradeLogic.logRows({ log[#log] }, BIG)[1]
			expect(odd.partner).to.equal("With a player")
			expect(#odd.gave).to.equal(1)
			expect(odd.gave[1].rarity).to.equal("Common")
			expect(odd.gave[1].level).to.equal(1)
			expect(#odd.got).to.equal(0)
			expect(#TradeLogic.logRows(nil, BIG)).to.equal(0)
		end)
	end)

	describe("TradeLogic.logRows decor (#1574)", function()
		it("carries each side's pieces, and none for entries from before decor trading", function()
			local rows = TradeLogic.logRows({
				{
					id = "d",
					at = 100,
					partnerName = "Sam",
					gave = {},
					got = {},
					gaveDecor = { { id = "bench", kind = "decor", rarity = "Rare" }, "junk", { kind = "lawn" } },
					gotDecor = { { id = "tulip_bed", kind = "lawn" } },
				},
				{ id = "old", at = 50, partnerName = "Mia", gave = {}, got = {} },
			}, 200)
			expect(#rows[1].gaveDecor).to.equal(1)
			expect(rows[1].gaveDecor[1].id).to.equal("bench")
			expect(rows[1].gaveDecor[1].rarity).to.equal("Rare")
			expect(rows[1].gotDecor[1].kind).to.equal("lawn")
			expect(rows[1].gotDecor[1].rarity).to.equal("Common")
			expect(#rows[2].gaveDecor).to.equal(0)
			expect(#rows[2].gotDecor).to.equal(0)
		end)
	end)

	describe("TradeLogic.logRows crates and fish (#2745)", function()
		it("carries each side's crates and golden fish, and none for older entries", function()
			local rows = TradeLogic.logRows({
				{
					id = "c",
					at = 100,
					partnerName = "Sam",
					gave = {},
					got = {},
					gaveCrates = { { id = "alley_crate", count = 3 }, { id = "junk", count = 0 }, "junk", { count = 2 } },
					gotFish = 50,
					gaveFish = 0 / 0,
				},
				{ id = "old", at = 50, partnerName = "Mia", gave = {}, got = {} },
			}, 200)
			expect(#rows[1].gaveCrates).to.equal(1)
			expect(rows[1].gaveCrates[1].id).to.equal("alley_crate")
			expect(rows[1].gaveCrates[1].count).to.equal(3)
			expect(#rows[1].gotCrates).to.equal(0)
			expect(rows[1].gotFish).to.equal(50)
			expect(rows[1].gaveFish).to.equal(0)
			expect(#rows[2].gaveCrates).to.equal(0)
			expect(rows[2].gotFish).to.equal(0)
		end)
	end)

	describe("TradeLogic.askTitle and doneLine", function()
		it("words the request card and the done toast", function()
			expect(TradeLogic.askTitle("Sam")).to.equal("Sam wants to trade")
			expect(TradeLogic.doneLine({ {} })).to.equal("Trade done! 1 new cat")
			expect(TradeLogic.doneLine({ {}, {} })).to.equal("Trade done! 2 new cats")
			expect(TradeLogic.doneLine({})).to.equal("Trade done!")
			expect(TradeLogic.doneLine(nil)).to.equal("Trade done!")
			expect(TradeLogic.doneLine({}, { {}, {} })).to.equal("Trade done! 2 new decor")
			expect(TradeLogic.doneLine({ {} }, { {} })).to.equal("Trade done! 1 new cat and 1 new decor")
			expect(TradeLogic.doneLine({}, nil, { { id = "a", count = 2 }, { id = "b", count = 1 } })).to.equal(
				"Trade done! 3 new crates"
			)
			expect(TradeLogic.doneLine({ {}, {} }, { {} }, { { id = "a", count = 1 } })).to.equal(
				"Trade done! 2 new cats, 1 new decor and 1 new crate"
			)
		end)
	end)
	describe("decor pieces (#1574)", function()
		local INFO: { [string]: any } = {
			rug = { kind = "decor", name = "Rug", rarity = "Rare", bonus = 0.05 },
			lamp = { kind = "decor", name = "Lamp", rarity = "Legendary", bonus = 0.12 },
			gnome = { kind = "lawn", name = "Gnome", rarity = "Uncommon", bonus = 0.02 },
			fountain = { kind = "lawn", name = "Fountain", rarity = "Golden", bonus = 0.2 },
			bench = { kind = "decor", name = "Bench", rarity = "Common", bonus = 0 },
		}
		local function pieceOf(id: string): any
			return INFO[id]
		end

		it("lists owned tradeable pieces, rarest first, each with why it cannot go", function()
			local picks = TradeLogic.myPieces(
				{
					rug = true,
					lamp = true,
					gnome = true,
					fountain = true,
					bench = true,
					shop_sign = true,
				},
				{ fountain = true },
				pieceOf,
				{ gnome = true },
				{ "bench" }
			)
			local order, status = {}, {}
			for _, pick in picks do
				table.insert(order, pick.id)
				status[pick.id] = pick.status
			end
			-- shop_sign can't be traded (pieceOf says nil), so it is left out
			expect(table.concat(order, ",")).to.equal("fountain,rug,gnome,lamp,bench")
			expect(status.fountain).to.equal("ok") -- Golden, unlocked
			expect(status.gnome).to.equal("offered")
			expect(status.lamp).to.equal("locked") -- Legendary, not unlocked
			expect(status.bench).to.equal("theyHave")
			expect(picks[1].kind).to.equal("lawn")
			expect(picks[1].bonus).to.equal(0.2)
		end)

		it("lists nothing without owned pieces", function()
			expect(#TradeLogic.myPieces(nil, nil, pieceOf, {}, nil)).to.equal(0)
			expect(#TradeLogic.myPieces({ rug = false }, nil, pieceOf, {}, nil)).to.equal(0)
		end)

		it("says why a piece can't go", function()
			local function pick(status: string): any
				return {
					id = "x",
					name = "X",
					kind = "decor",
					rarity = "Rare",
					bonus = 0,
					status = status,
				}
			end
			expect(TradeLogic.pieceHint(pick("locked"), false)).to.equal(
				"Unlock it on its card to trade"
			)
			expect(TradeLogic.pieceHint(pick("theyHave"), false)).to.equal("They already have this")
			expect(TradeLogic.pieceHint(pick("ok"), true)).to.equal(
				string.format("Up to %d decor each", TradeLogic.MAX_DECOR)
			)
			expect(TradeLogic.pieceHint(pick("ok"), false)).to.equal(nil)
			expect(TradeLogic.pieceHint(pick("offered"), true)).to.equal(nil)
		end)

		it("shows a piece's tip bonus as a whole percent", function()
			expect(TradeLogic.bonusText(0.05)).to.equal("+5%")
			expect(TradeLogic.bonusText(0.125)).to.equal("+13%")
			expect(TradeLogic.bonusText(0.001)).to.equal("+1%")
			expect(TradeLogic.bonusText(0)).to.equal(nil)
			expect(TradeLogic.bonusText(nil)).to.equal(nil)
			expect(TradeLogic.pieceRarity("Rare", 0.05)).to.equal("Rare · +5%")
			expect(TradeLogic.pieceRarity("Common", 0)).to.equal("Common")
		end)

		it("counts pieces toward Ready", function()
			local piece =
				{ id = "rug", name = "Rug", kind = "decor", rarity = "Rare", bonus = 0.05 }
			local onlyDecor = trade({
				me = side("You", { cats = {}, decor = { piece } }),
				them = side("Sam", { cats = {} }),
			})
			expect(TradeLogic.offerCount(onlyDecor.me)).to.equal(1)
			expect(TradeLogic.readyButton(onlyDecor).enabled).to.equal(true)
		end)
	end)
	describe("crates (#2745)", function()
		local DEFS: { [string]: any } = {
			alley_crate = { name = "Alley Crate", order = 2 },
			classic_crate = { name = "Classic Crate", order = 1 },
			desert_crate = { name = "Desert Crate", order = 6 },
			classic_golden_crate = { name = "Golden Classic Crate", golden = true, order = 7 },
		}
		local function defOf(id: string): any
			return DEFS[id]
		end
		local function sideWith(crates: { any }): any
			return { cats = {}, decor = {}, crates = crates }
		end

		it("lists banked crates in catalog order, never a golden one, blocked ones last", function()
			local picks = TradeLogic.myCrates(
				{ alley_crate = 3, classic_crate = 1, desert_crate = 2, classic_golden_crate = 4, gone = 5, none = 0 },
				defOf,
				{ classic_crate = 1, alley_crate = 1 },
				{ desert_crate = "They haven't reached the Desert yet" }
			)
			local order = {}
			for _, pick in picks do
				table.insert(order, pick.id)
			end
			expect(table.concat(order, ",")).to.equal("classic_crate,alley_crate,desert_crate")
			expect(picks[1].status).to.equal("offered") -- its only one is on offer
			expect(picks[2].status).to.equal("ok")
			expect(picks[2].banked).to.equal(3)
			expect(picks[2].offered).to.equal(1)
			expect(picks[3].status).to.equal("blocked")
			expect(picks[3].reason).to.equal("They haven't reached the Desert yet")
		end)

		it("says why a tap adds none", function()
			local function pick(fields: { [string]: any }): any
				local base = { id = "alley_crate", name = "Alley Crate", banked = 3, offered = 0, status = "ok" }
				for key, value in fields do
					base[key] = value
				end
				return base
			end
			expect(TradeLogic.crateHint(pick({}), sideWith({}))).to.equal(nil)
			expect(TradeLogic.crateHint(pick({ status = "blocked", reason = "Not yet" }), sideWith({}))).to.equal(
				"Not yet"
			)
			expect(TradeLogic.crateHint(pick({ offered = 3, status = "offered" }), sideWith({}))).to.equal(
				"You don't have that many"
			)
			local six = {}
			for index = 1, TradeLogic.MAX_CRATE_KINDS do
				table.insert(six, { id = "c" .. index, count = 1 })
			end
			expect(TradeLogic.crateHint(pick({}), sideWith(six))).to.equal(
				string.format("Up to %d kinds of crate each", TradeLogic.MAX_CRATE_KINDS)
			)
			local full = { { id = "classic_crate", count = TradeLogic.MAX_CRATES } }
			expect(TradeLogic.crateHint(pick({}), sideWith(full))).to.equal(
				string.format("Up to %d crates each", TradeLogic.MAX_CRATES)
			)
		end)

		it("lets the picker go up to what is banked, within the caps", function()
			local pick = { id = "alley_crate", name = "Alley Crate", banked = 30, offered = 2, status = "ok" }
			local side = sideWith({ { id = "alley_crate", count = 2 }, { id = "classic_crate", count = 5 } })
			-- 20 in all, 5 of them another kind
			expect(TradeLogic.crateMax(pick :: any, side)).to.equal(TradeLogic.MAX_CRATES - 5)
			local few = { id = "alley_crate", name = "Alley Crate", banked = 4, offered = 0, status = "ok" }
			expect(TradeLogic.crateMax(few :: any, sideWith({}))).to.equal(4)
		end)

		it("sends the difference from what is on offer", function()
			local action, count = TradeLogic.crateChange(2, 5)
			expect(action).to.equal("add")
			expect(count).to.equal(3)
			action, count = TradeLogic.crateChange(5, 1)
			expect(action).to.equal("remove")
			expect(count).to.equal(4)
			action = TradeLogic.crateChange(3, 3)
			expect(action).to.equal(nil)
			expect(TradeLogic.countText(3)).to.equal("x3")
		end)

		it("counts crates toward Ready", function()
			local onlyCrates = {
				phase = "offer",
				me = { ready = false, cats = {}, decor = {}, crates = { { id = "alley_crate", count = 1 } } },
				them = { ready = false, cats = {}, decor = {} },
			}
			expect(TradeLogic.readyButton(onlyCrates).enabled).to.equal(true)
		end)
	end)
	describe("golden fish (#2745 section 1d)", function()
		it("reads the amount on a side and counts it toward Ready", function()
			expect(TradeLogic.fishOf({ fish = 50 })).to.equal(50)
			expect(TradeLogic.fishOf({ fish = 2.7 })).to.equal(2)
			expect(TradeLogic.fishOf({ fish = -3 })).to.equal(0)
			expect(TradeLogic.fishOf({ fish = 0 / 0 })).to.equal(0)
			expect(TradeLogic.fishOf({ fish = math.huge })).to.equal(0)
			expect(TradeLogic.fishOf({})).to.equal(0)
			expect(TradeLogic.offerCount({ cats = {}, fish = 10 })).to.equal(1)
			expect(TradeLogic.offerCount({ cats = {}, fish = 0 })).to.equal(0)
			local onlyFish = { me = { cats = {}, fish = 10, ready = false }, them = { cats = {} }, phase = "offer" }
			expect(TradeLogic.readyButton(onlyFish).enabled).to.equal(true)
		end)

		it("caps the picker at the wallet, the per-trade cap and their room today", function()
			local cap = TradeLogic.MAX_FISH
			expect(TradeLogic.fishMax(1000, nil)).to.equal(cap)
			expect(TradeLogic.fishMax(30, nil)).to.equal(30)
			expect(TradeLogic.fishMax(1000, 120)).to.equal(math.min(120, cap))
			expect(TradeLogic.fishMax(1000, 0)).to.equal(0)
			expect(TradeLogic.fishMax(nil, 100)).to.equal(0)
			expect(TradeLogic.fishMax(-5, 100)).to.equal(0)
		end)

		it("says why the picker can't open, and the room line", function()
			expect(TradeLogic.fishHint(0, 100, 0)).to.equal("You have no golden fish")
			expect(TradeLogic.fishHint(nil, 100, 0)).to.equal("You have no golden fish")
			expect(TradeLogic.fishHint(50, 0, 0)).to.equal("They can't get more golden fish today")
			expect(TradeLogic.fishHint(50, 0, 20)).to.equal(nil) -- some on offer: open, to take them back
			expect(TradeLogic.fishHint(50, 100, 0)).to.equal(nil)
			expect(TradeLogic.fishRoomLine(150)).to.equal("They can get 150 more today")
			expect(TradeLogic.fishRoomLine(0)).to.equal("They can't get more today")
			expect(TradeLogic.fishRoomLine(nil)).to.equal(string.format("Up to %d a trade", TradeLogic.MAX_FISH))
		end)

		it("sets the quick amounts within the top", function()
			expect(TradeLogic.fishQuick(10, 120)).to.equal(10)
			expect(TradeLogic.fishQuick(50, 30)).to.equal(30)
			expect(TradeLogic.fishQuick("max", 120)).to.equal(120)
		end)

		it("joins the fish to the done line", function()
			expect(TradeLogic.doneLine({}, nil, nil, 50)).to.equal("Trade done! 50 golden fish")
			expect(TradeLogic.doneLine({ {} }, nil, nil, 20)).to.equal("Trade done! 1 new cat and 20 golden fish")
			expect(TradeLogic.doneLine({}, nil, nil, 0)).to.equal("Trade done!")
		end)
	end)
end
