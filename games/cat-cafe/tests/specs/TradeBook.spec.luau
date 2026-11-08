--!strict
-- server/Util/TradeBook.luau: F102 trade requests and open trades (trading.md sections 2 to 4).
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local TradeBook = require(ServerScriptService.Server.Util.TradeBook)

	local SAM = { userId = 1, name = "Sam" }
	local ALEX = { userId = 2, name = "Alex" }

	local function opened(): (any, any)
		local book = TradeBook.new()
		local trade = TradeBook.open(book, "t1", SAM, ALEX, 100)
		return book, trade
	end

	-- a tile with rateForMe as the uid's length, so the totals are easy to check
	local function tile(ownerId: number, uid: string): any
		return {
			uid = uid,
			catId = "tabby",
			rarity = "Common",
			level = ownerId,
			rateForMe = #uid,
		}
	end

	describe("requests", function()
		it(
			"runs a request, refuses a second answer and makes a decline wait to ask again",
			function()
				local book = TradeBook.new()
				local request = TradeBook.ask(book, "r1", 1, 2, 100)
				expect(request.expiresAt).to.equal(100 + Config.TradeRequestSeconds)
				expect(TradeBook.isAsking(book, 1)).to.equal(true)
				expect(TradeBook.answer(book, "r1", 3, true, 101)).never.to.be.ok() -- not theirs to answer
				expect(TradeBook.answer(book, "r1", 2, false, 101)).to.be.ok()
				expect(TradeBook.isAsking(book, 1)).to.equal(false)
				expect(TradeBook.reaskLeft(book, 1, 2, 101)).to.equal(Config.TradeReaskSeconds)
				expect(TradeBook.reaskLeft(book, 2, 1, 101)).to.equal(0)
				expect(TradeBook.answer(book, "r1", 2, true, 102)).never.to.be.ok() -- answered already
			end
		)

		it("lets an accept through with no wait, and runs a request out", function()
			local book = TradeBook.new()
			TradeBook.ask(book, "r1", 1, 2, 100)
			expect(TradeBook.answer(book, "r1", 2, true, 105)).to.be.ok()
			expect(TradeBook.reaskLeft(book, 1, 2, 105)).to.equal(0)
			TradeBook.ask(book, "r2", 1, 2, 200)
			expect(#TradeBook.expire(book, 200 + Config.TradeRequestSeconds - 1)).to.equal(0)
			local gone = TradeBook.expire(book, 200 + Config.TradeRequestSeconds)
			expect(#gone).to.equal(1)
			expect(gone[1].id).to.equal("r2")
			expect(TradeBook.isAsking(book, 1)).to.equal(false)
			expect(TradeBook.reaskLeft(book, 1, 2, 200 + Config.TradeRequestSeconds)).to.equal(
				Config.TradeReaskSeconds
			)
			-- an answer after it ran out is refused too
			TradeBook.ask(book, "r3", 3, 4, 300)
			expect(TradeBook.answer(book, "r3", 4, true, 300 + Config.TradeRequestSeconds)).never.to.be.ok()
			-- the waits that are over are forgotten
			TradeBook.expire(book, 10000)
			expect(next(book.reaskAt)).never.to.be.ok()
		end)

		it(
			"drops both players' requests out when their trade opens, and everything of a player who leaves",
			function()
				local book = TradeBook.new()
				TradeBook.ask(book, "r1", 1, 3, 100)
				TradeBook.ask(book, "r2", 4, 2, 100)
				TradeBook.open(book, "t1", SAM, ALEX, 101)
				expect(TradeBook.isAsking(book, 1)).to.equal(false)
				expect(book.requests.r1).never.to.be.ok()
				expect(book.requests.r2).to.be.ok() -- asked by someone else: Alex's answer is refused later
				expect(TradeBook.leave(book, 2, 102)).to.be.ok()
				expect(book.requests.r2).never.to.be.ok()
			end
		)
	end)

	describe("offers", function()
		it("puts any change on a new version and starts both sides over", function()
			local _, trade = opened()
			expect(trade.version).to.equal(1)
			expect(TradeBook.add(trade, 1, "a", 3, 101)).to.equal(true)
			expect(trade.version).to.equal(2)
			expect(TradeBook.ready(trade, 1, 2, true, 102)).never.to.be.ok()
			expect(TradeBook.ready(trade, 2, 2, true, 102)).never.to.be.ok()
			expect(trade.phase).to.equal("countdown")
			expect(TradeBook.add(trade, 2, "b", 1, 103)).to.equal(true)
			expect(trade.version).to.equal(3)
			expect(trade.phase).to.equal("offer")
			expect(trade.countdownEndsAt).never.to.be.ok()
			expect(trade.a.ready).to.equal(false)
			expect(trade.b.ready).to.equal(false)
			expect(trade.changed :: any).to.deepEqual({ userId = 2, uid = "b", at = 103 })
			expect(TradeBook.remove(trade, 1, "a", 104)).to.equal(true)
			expect(trade.version).to.equal(4)
			expect(TradeBook.remove(trade, 1, "a", 105)).to.equal(false)
			expect(trade.version).to.equal(4)
		end)

		it("refuses a cat on offer twice, a full side and anyone not in the trade", function()
			local book, trade = opened()
			expect(TradeBook.add(trade, 1, "a", 1, 101)).to.equal(true)
			expect(TradeBook.add(trade, 1, "a", 1, 101)).to.equal(false)
			expect(TradeBook.add(trade, 9, "z", 1, 101)).to.equal(false)
			for i = 2, Config.TradeMaxCats do
				expect(TradeBook.add(trade, 1, "a" .. i, 1, 101)).to.equal(true)
			end
			expect(TradeBook.add(trade, 1, "extra", 1, 101)).to.equal(false)
			expect(TradeBook.isOffered(book, 1, "a")).to.equal(true)
			expect(TradeBook.isOffered(book, 2, "a")).to.equal(false)
			expect(TradeBook.isOffered(book, 3, "a")).to.equal(false)
		end)
	end)

	describe("Ready, the countdown and Confirm", function()
		it("refuses a Ready for an old version or with both offers empty", function()
			local _, trade = opened()
			expect(TradeBook.ready(trade, 1, 1, true, 101)).to.equal(TradeBook.EMPTY)
			TradeBook.add(trade, 2, "b", 1, 101)
			expect(TradeBook.ready(trade, 1, 1, true, 102)).to.equal(TradeBook.STALE)
			expect(TradeBook.ready(trade, 1, 2, true, 102)).never.to.be.ok()
			expect(TradeBook.ready(trade, 3, 2, true, 102)).to.equal(TradeBook.PHASE)
		end)

		it("counts down when both are Ready; taking it back keeps the other's Ready", function()
			local _, trade = opened()
			TradeBook.add(trade, 1, "a", 1, 100)
			TradeBook.ready(trade, 1, 2, true, 101)
			expect(trade.phase).to.equal("offer")
			TradeBook.ready(trade, 2, 2, true, 102)
			expect(trade.phase).to.equal("countdown")
			expect(trade.countdownEndsAt).to.equal(102 + Config.TradeCountdownSeconds)
			expect(TradeBook.ready(trade, 2, 2, false, 103)).never.to.be.ok()
			expect(trade.phase).to.equal("offer")
			expect(trade.a.ready).to.equal(true)
			expect(trade.b.ready).to.equal(false)
			expect(trade.version).to.equal(2) -- Ready never moves the version
		end)

		it(
			"opens the confirm screen when the countdown ends, with the wait only on a warned side",
			function()
				local _, trade = opened()
				TradeBook.add(trade, 1, "mythical", 50, 100)
				TradeBook.add(trade, 2, "common", 1, 100)
				TradeBook.ready(trade, 1, 3, true, 101)
				TradeBook.ready(trade, 2, 3, true, 101)
				local endsAt = 101 + Config.TradeCountdownSeconds
				expect(TradeBook.tick(trade, endsAt - 0.1)).to.equal(false)
				expect(TradeBook.tick(trade, endsAt)).to.equal(true)
				expect(trade.phase).to.equal("confirm")
				-- Sam gives 50 for 1: lopsided, so Sam waits; Alex can confirm at once
				expect(trade.a.confirmAt).to.equal(endsAt + Config.TradeConfirmWaitSeconds)
				expect(trade.b.confirmAt).to.equal(0) -- N336: no wait, so the view sends none
				expect((TradeBook.view(trade, 2, tile) :: any).confirmAt).never.to.be.ok()
				expect((TradeBook.view(trade, 1, tile) :: any).confirmAt).to.equal(
					endsAt + Config.TradeConfirmWaitSeconds
				)
				expect(TradeBook.confirm(trade, 1, 3, endsAt + 1)).to.equal(TradeBook.WAIT)
				expect(TradeBook.confirm(trade, 1, 2, endsAt + 5)).to.equal(TradeBook.STALE)
				expect(TradeBook.confirm(trade, 2, 3, endsAt)).never.to.be.ok()
				expect(TradeBook.bothConfirmed(trade)).to.equal(false)
				local wait = Config.TradeConfirmWaitSeconds - TradeBook.CONFIRM_SLACK / 2 -- inside the slack
				expect(TradeBook.confirm(trade, 1, 3, endsAt + wait)).never.to.be.ok()
				expect(TradeBook.bothConfirmed(trade)).to.equal(true)
			end
		)

		it(
			"gives a gift's giver the wait, and sends both back to the offers when one leaves the confirm screen",
			function()
				local _, trade = opened()
				TradeBook.add(trade, 1, "a", 3, 100)
				TradeBook.ready(trade, 1, 2, true, 100)
				TradeBook.ready(trade, 2, 2, true, 100)
				TradeBook.tick(trade, 100 + Config.TradeCountdownSeconds)
				expect(trade.a.confirmAt).to.equal(
					100 + Config.TradeCountdownSeconds + Config.TradeConfirmWaitSeconds
				)
				expect(TradeBook.confirm(trade, 2, 2, 200)).never.to.be.ok()
				expect(TradeBook.ready(trade, 1, 2, false, 201)).never.to.be.ok()
				expect(trade.phase).to.equal("offer")
				expect(trade.a.ready or trade.b.ready or trade.b.confirmed).to.equal(false)
			end
		)

		it(
			"refuses Confirm before the confirm screen, and every change once the swap begins",
			function()
				local _, trade = opened()
				TradeBook.add(trade, 1, "a", 1, 100)
				expect(TradeBook.confirm(trade, 1, 2, 101)).to.equal(TradeBook.PHASE)
				TradeBook.ready(trade, 1, 2, true, 101)
				TradeBook.ready(trade, 2, 2, true, 101)
				TradeBook.tick(trade, 200)
				TradeBook.confirm(trade, 1, 2, 300)
				TradeBook.confirm(trade, 2, 2, 300)
				TradeBook.commit(trade)
				expect(TradeBook.add(trade, 2, "b", 1, 301)).to.equal(false)
				expect(TradeBook.remove(trade, 1, "a", 301)).to.equal(false)
				expect(TradeBook.ready(trade, 1, 2, false, 301)).to.equal(TradeBook.PHASE)
				expect(trade.version).to.equal(2)
			end
		)
	end)

	describe("closing", function()
		it("starts the cooldown only for a trade that swapped", function()
			local book, trade = opened()
			TradeBook.close(book, trade, 150, false)
			expect(TradeBook.tradeFor(book, 1)).never.to.be.ok()
			expect(TradeBook.sinceLastSwap(book, 1, 151)).to.equal(math.huge)
			local again = TradeBook.open(book, "t2", SAM, ALEX, 160)
			TradeBook.close(book, again, 170, true)
			expect(TradeBook.sinceLastSwap(book, 1, 175)).to.equal(5)
			expect(TradeBook.sinceLastSwap(book, 2, 175)).to.equal(5)
			expect(book.trades.t2).never.to.be.ok()
		end)
	end)

	describe("the view", function()
		it(
			"shows each player their own side as me, the change, the totals and the warnings",
			function()
				local _, trade = opened()
				TradeBook.add(trade, 1, "aaa", 20, 100)
				TradeBook.add(trade, 2, "b", 1, 101)
				local sam = TradeBook.view(trade, 1, tile) :: any
				expect(sam.me.name).to.equal("Sam")
				expect(sam.them.name).to.equal("Alex")
				expect(sam.changed :: any).to.deepEqual({ side = "them", uid = "b", at = 101 })
				expect(sam.giveValue).to.equal(20)
				expect(sam.getValue).to.equal(1)
				expect(sam.lopsided).to.equal(true)
				expect(sam.gift).to.equal(false)
				expect(sam.myRateNow).to.equal(3)
				expect(sam.theirRateForMe).to.equal(1)
				expect(sam.phase).to.equal("offer")
				expect(sam.confirmAt).never.to.be.ok()
				local alex = TradeBook.view(trade, 2, tile) :: any
				expect(alex.changed.side).to.equal("me")
				expect(alex.lopsided).to.equal(false)
				expect(TradeBook.view(trade, 3, tile)).never.to.be.ok()
			end
		)

		it(
			"leaves out a cat the tile maker cannot find and shows a swap as the confirm screen",
			function()
				local _, trade = opened()
				TradeBook.add(trade, 1, "a", 1, 100)
				TradeBook.add(trade, 2, "gone", 1, 100)
				local view = TradeBook.view(trade, 1, function(ownerId: number, uid: string): any
					return if uid == "gone" then nil else tile(ownerId, uid)
				end) :: any
				expect(#view.them.cats).to.equal(0)
				TradeBook.ready(trade, 1, 3, true, 101)
				TradeBook.ready(trade, 2, 3, true, 101)
				TradeBook.tick(trade, 200)
				TradeBook.commit(trade)
				local swapping = TradeBook.view(trade, 2, tile) :: any
				expect(swapping.phase).to.equal("confirm")
				expect(swapping.confirmAt).never.to.be.ok() -- a fair trade: no wait on either side (N336)
			end
		)
	end)

	describe("TradeBook edges (QA)", function()
		-- Seeded play (QA, trading.md section 4): both players and an outsider press anything in any order, with the
		-- version on the table or an old or made-up one, and the rules that stop a swap-at-the-last-moment scam hold
		-- after every call.
		local VALUES = { 0, 1, 3, 8, 20, 50, 150, 500 }
		local STEPS = { 0, 0.1, 0.5, 1, 1.9, 2, 3, 5, 6 }
		local OPS = { "add", "add", "add", "remove", "ready", "ready", "ready", "tick", "tick" }
		for _ = 1, 3 do
			table.insert(OPS, "confirm")
		end

		local function snapshot(trade: any): string
			local parts = { tostring(trade.version), trade.phase, tostring(trade.countdownEndsAt) }
			for _, side in { trade.a, trade.b } do
				table.insert(parts, table.concat(side.cats, ","))
				local flags = { tostring(side.ready), tostring(side.confirmed) }
				table.insert(flags, tostring(side.confirmAt))
				table.insert(parts, table.concat(flags, " "))
			end
			return table.concat(parts, "|")
		end

		-- the press that moves the trade on, so half the presses push toward a swap and the seeds reach many
		local function onward(trade: any): string
			if trade.phase == "countdown" then
				return "tick"
			elseif trade.phase == "confirm" then
				return "confirm"
			end
			return if #trade.a.cats + #trade.b.cats == 0 then "add" else "ready"
		end

		local function total(values: { [string]: number }): number
			local sum = 0
			for _, value in values do
				sum += value
			end
			return sum
		end

		local function keys(values: { [string]: number }): { string }
			local list: { string } = {}
			for uid in values do
				table.insert(list, uid)
			end
			table.sort(list)
			return list
		end

		it("never swaps an offer either side has not Readied and Confirmed as it stands", function()
			local swaps, waits, stale = 0, 0, 0
			for seed = 1, 400 do
				local rng = Random.new(seed)
				local book = TradeBook.new()
				local trade = TradeBook.open(book, "t" .. seed, SAM, ALEX, 0)
				local now, changes = 0, 0
				local values: { [number]: { [string]: number } } = { {}, {} }
				local readyOn: { [number]: number } = {}
				local confirmedOn: { [number]: number } = {}
				local countdownFrom, screenAt = 0, 0
				local frozen: string? = nil
				for _ = 1, 80 do
					now += STEPS[rng:NextInteger(1, #STEPS)]
					local who = if rng:NextInteger(1, 6) == 6 then 3 else rng:NextInteger(1, 2)
					local version = trade.version
					if rng:NextInteger(1, 4) == 1 then
						version = rng:NextInteger(1, trade.version + 2)
					end
					local op = OPS[rng:NextInteger(1, #OPS)]
					if rng:NextInteger(1, 2) == 1 then
						op = onward(trade)
					end
					local uid = "c" .. rng:NextInteger(1, 12)
					local before, phase = snapshot(trade), trade.phase
					local took, why = false, nil
					if op == "add" then
						local value = VALUES[rng:NextInteger(1, #VALUES)]
						took = TradeBook.add(trade, who, uid, value, now)
						if took and who ~= 3 then
							changes += 1
							values[who][uid] = value
						end
					elseif op == "remove" then
						took = TradeBook.remove(trade, who, uid, now)
						if took and who ~= 3 then
							changes += 1
							values[who][uid] = nil
						end
					elseif op == "ready" then
						local ready = rng:NextInteger(1, 4) > 1
						why = TradeBook.ready(trade, who, version, ready, now)
						took = why == nil
						if took and ready then
							-- a Ready only takes on the offer as it stands
							expect(version).to.equal(trade.version)
							readyOn[who] = version
						end
					elseif op == "tick" then
						took = TradeBook.tick(trade, now)
					else
						why = TradeBook.confirm(trade, who, version, now)
						took = why == nil
					end
					if why == TradeBook.WAIT then
						waits += 1
					elseif why == TradeBook.STALE then
						stale += 1
					end
					if who == 3 and op ~= "tick" then
						-- someone outside the trade changes nothing
						expect(took).to.equal(false)
						expect(snapshot(trade)).to.equal(before)
					end
					if frozen ~= nil then
						-- once the swap begins nothing on the trade moves
						expect(took).to.equal(false)
						expect(snapshot(trade)).to.equal(frozen)
						continue
					end
					expect(trade.version).to.equal(1 + changes)
					for index, side in { trade.a, trade.b } do
						expect(table.concat(keys(values[index]), ",")).to.equal(
							table.concat(keys(side.values), ",")
						)
						expect(#side.cats).to.equal(#keys(values[index]))
						expect(#side.cats <= Config.TradeMaxCats).to.equal(true)
						if side.confirmed then
							expect(trade.phase).to.equal("confirm")
						end
					end
					if trade.phase == "countdown" then
						expect(trade.a.ready and trade.b.ready).to.equal(true)
						if phase ~= "countdown" then
							countdownFrom = now
						end
					end
					if trade.phase == "confirm" and phase ~= "confirm" then
						-- only a tick opens the confirm screen, and only after the whole countdown
						expect(phase).to.equal("countdown")
						expect(op).to.equal("tick")
						expect(now >= countdownFrom + Config.TradeCountdownSeconds).to.equal(true)
						screenAt = now
					end
					if op == "confirm" and took then
						expect(version).to.equal(trade.version)
						local give, get = total(values[who]), total(values[3 - who])
						local gift = next(values[3 - who]) == nil
						local lopsided = give > 0 and give >= Config.TradeLopsidedRatio * get
						local warned = gift or lopsided
						local from = screenAt
							+ (if warned then Config.TradeConfirmWaitSeconds else 0)
							- TradeBook.CONFIRM_SLACK
						expect(now >= from - 1e-6).to.equal(true)
						confirmedOn[who] = version
					end
					if TradeBook.bothConfirmed(trade) then
						-- both Readied and Confirmed this very offer, and it has not changed since
						for side = 1, 2 do
							expect(readyOn[side]).to.equal(trade.version)
							expect(confirmedOn[side]).to.equal(trade.version)
						end
						TradeBook.commit(trade)
						frozen = snapshot(trade)
						swaps += 1
					end
				end
			end
			-- the seeds reach every refusal and plenty of swaps, so the checks above ran
			expect(swaps >= 200).to.equal(true)
			expect(waits >= 30).to.equal(true)
			expect(stale >= 500).to.equal(true)
		end)
	end)

	describe("decor (section 1b, #1574)", function()
		it("puts pieces on and off a side, resetting both and counting them in the warnings", function()
			local book, trade = opened()
			expect(TradeBook.ready(trade, 1, 1, true, 100)).to.equal(TradeBook.EMPTY)
			expect(TradeBook.addDecor(trade, 1, "rug", 1, 101)).to.equal(true)
			expect(TradeBook.addDecor(trade, 1, "rug", 1, 101)).to.equal(false) -- on offer already
			expect(trade.version).to.equal(2)
			expect(TradeBook.isPieceOffered(book, 1, "rug")).to.equal(true)
			expect(TradeBook.isPieceOffered(book, 2, "rug")).to.equal(false)
			expect(TradeBook.ready(trade, 2, 2, true, 102)).never.to.be.ok() -- a piece alone is an offer
			expect(TradeBook.addDecor(trade, 2, "fish_tank", 8, 103)).to.equal(true)
			expect(trade.b.ready).to.equal(false) -- any change resets both
			expect(trade.changed :: any).to.deepEqual({ userId = 2, uid = "fish_tank", at = 103 })
			local lopsided, gift = TradeBook.warnings(trade, 2)
			expect(lopsided).to.equal(true) -- gives 8 for 1
			expect(gift).to.equal(false)
			expect(TradeBook.removeDecor(trade, 1, "rug", 104)).to.equal(true)
			expect(TradeBook.removeDecor(trade, 1, "rug", 104)).to.equal(false)
			lopsided, gift = TradeBook.warnings(trade, 2)
			expect(gift).to.equal(true)
			for i = 1, Config.TradeMaxDecor do
				TradeBook.addDecor(trade, 1, "p" .. i, 1, 105)
			end
			expect(TradeBook.addDecor(trade, 1, "one_more", 1, 106)).to.equal(false)
			TradeBook.commit(trade)
			expect(TradeBook.removeDecor(trade, 1, "p1", 107)).to.equal(false)
		end)

		it("shows each side's pieces and the viewer's pieces the other player owns", function()
			local _, trade = opened()
			TradeBook.addDecor(trade, 1, "rug", 1, 101)
			TradeBook.addDecor(trade, 1, "nope", 0, 101)
			local function piece(id: string): any
				return if id == "rug"
					then { id = id, name = "Cozy rug", kind = "decor", rarity = "Common", bonus = 0.05 }
					else nil
			end
			local sam = TradeBook.view(trade, 1, tile, piece, { "neon_sign" }) :: any
			expect(#sam.me.decor).to.equal(1) -- an unknown piece is left out
			expect(sam.me.decor[1].name).to.equal("Cozy rug")
			expect(#sam.them.decor).to.equal(0)
			expect(sam.theyHave).to.deepEqual({ "neon_sign" })
			local alex = TradeBook.view(trade, 2, tile) :: any
			expect(#alex.them.decor).to.equal(0) -- no piece tiles without the maker
			expect(alex.theyHave).to.deepEqual({})
		end)
	end)
end
