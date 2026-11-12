--!strict
-- The Rummage Bin (#3050): its save, the wait after each win, the two fixed first prizes, the prize table and its
-- chances, the bar (2 hits and 3 paws, easier for the first rummages), the prompt's odds note and the bar's closing
-- words. The range, the busy checks and the remotes are BinService's (Studio rows in the PR's test plan).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Rescue = require(Shared.Rescue)
	local RummageBin = require(Shared.RummageBin)

	local T = 1_800_000_000

	local function half(): number
		return 0.5
	end

	describe("its own store (no save field, #3050 shipped with no restart)", function()
		it("a player with nothing stored has a full bin and no wins", function()
			local save = RummageBin.fresh()
			expect(save.nextAt).to.equal(0)
			expect(save.uses).to.equal(0)
			expect(RummageBin.ready(save, T)).to.equal(true)
			expect(RummageBin.early(save)).to.equal(true)
			local stored = RummageBin.sanitize(nil, T)
			expect(stored.nextAt).to.equal(0)
			expect(stored.uses).to.equal(0)
		end)

		it("keeps a stored wait and wins", function()
			local save = RummageBin.sanitize({ nextAt = T + 400, uses = 7 }, T)
			expect(save.nextAt).to.equal(T + 400)
			expect(save.uses).to.equal(7)
			expect(RummageBin.ready(save, T)).to.equal(false)
			expect(RummageBin.ready(save, T + 400)).to.equal(true)
		end)

		it("is not in the player's save", function()
			expect((ProfileSchema.template(T) :: any).bin).to.equal(nil)
			expect(ProfileSchema.VERSION).to.equal(48) -- #3196 traits moved the save on; the bin still adds no field
		end)

		it(
			"makes a damaged value whole: no wait longer than one cooldown, no negative or broken numbers",
			function()
				local far = RummageBin.sanitize({ nextAt = T + 10 * 86400, uses = 2 }, T)
				expect(far.nextAt).to.equal(T + Config.BinCooldownSeconds)
				expect(far.uses).to.equal(2)
				for _, raw in
					{
						nil,
						5,
						"bin",
						{},
						{ nextAt = "soon", uses = -3 },
						{ nextAt = 0 / 0, uses = 0 / 0 },
					} :: { any }
				do
					local save = RummageBin.sanitize(raw, T)
					expect(save.nextAt).to.equal(0)
					expect(save.uses).to.equal(0)
				end
				expect(RummageBin.sanitize({ nextAt = 12.9, uses = 3.7 }, T).nextAt).to.equal(12)
				expect(RummageBin.sanitize({ nextAt = 12.9, uses = 3.7 }, T).uses).to.equal(3)
			end
		)
	end)

	describe("the wait after a win", function()
		it("is 3 minutes after the first two wins and 15 minutes after every later one", function()
			expect(Config.BinFirstUses).to.equal(3)
			local save = RummageBin.fresh()
			RummageBin.win(save, T, 0.5)
			expect(save.uses).to.equal(1)
			expect(save.nextAt).to.equal(T + 180)
			RummageBin.win(save, T + 180, 0.5)
			expect(save.nextAt).to.equal(T + 360)
			RummageBin.win(save, T + 360, 0.5)
			expect(save.uses).to.equal(3)
			expect(save.nextAt).to.equal(T + 360 + 900)
			RummageBin.win(save, T + 2000, 0.5)
			expect(save.nextAt).to.equal(T + 2900)
		end)

		it("is not ready a second before the wait ends and nothing banks while away", function()
			local save = RummageBin.fresh()
			RummageBin.win(save, T, 0.5)
			expect(RummageBin.ready(save, T + 179)).to.equal(false)
			expect(RummageBin.ready(save, T + 180)).to.equal(true)
			-- a week away: still one rummage, and the next wait starts at that win
			RummageBin.win(save, T + 7 * 86400, 0.5)
			expect(RummageBin.ready(save, T + 7 * 86400 + 1)).to.equal(false)
		end)

		it("the easy bar is for the first three rummages", function()
			local save = RummageBin.fresh()
			for _ = 1, 3 do
				expect(RummageBin.early(save)).to.equal(true)
				RummageBin.win(save, T, 0.5)
			end
			expect(RummageBin.early(save)).to.equal(false)
		end)
	end)

	describe("prizes", function()
		it(
			"the first three wins are the fixed starting boost, whatever the roll (#3460)",
			function()
				for _, roll in { 0, 0.3, 0.7, 0.999 } do
					local save = RummageBin.fresh()
					local first = RummageBin.win(save, T, roll)
					expect(first.id).to.equal("first_tuna")
					local one = RummageBin.prize(first)
					expect((one.lures :: any).tuna).to.equal(2)
					expect(one.fish).to.equal(10)
					local second = RummageBin.win(save, T, roll)
					expect(second.id).to.equal("first_crate")
					local two = RummageBin.prize(second)
					expect((two.crates :: any).alley_crate).to.equal(1)
					expect((two.potions :: any).lucky_potion).to.equal(1)
					expect(two.fish).never.to.be.ok()
					local third = RummageBin.win(save, T, roll)
					expect(third.id).to.equal("first_salmon")
					local three = RummageBin.prize(third)
					expect((three.lures :: any).salmon).to.equal(1)
					expect(three.fish).to.equal(10)
					-- the fourth is a roll, and there is no second starting boost
					expect(RummageBin.fixedFor(save.uses)).to.equal(nil)
					expect(RummageBin.win(save, T, 0.999).id).to.equal("golden")
				end
				expect(#Config.BinFirstPrizes).to.equal(Config.BinFirstUses)
			end
		)

		it("the table's chances add to 1 and every row names something real", function()
			local total = 0
			local ids: { [string]: boolean } = {}
			local function real(row: RummageBin.Row): number
				local kinds = 0
				if row.lure ~= nil then
					kinds += 1
					expect(Catalog.getLure(row.lure)).to.be.ok()
				end
				if row.crate ~= nil then
					kinds += 1
					expect(Catalog.getCrate(row.crate)).to.be.ok()
				end
				if row.potion ~= nil then
					kinds += 1
					expect(Catalog.getPotion(row.potion)).to.be.ok()
				end
				if row.fish ~= nil then
					kinds += 1
					expect(row.fish > 0).to.equal(true)
				end
				if row.count ~= nil then
					expect(row.count >= 1 and row.count % 1 == 0).to.equal(true)
				end
				return kinds
			end
			for _, row in Config.BinTable :: { RummageBin.Row } do
				local chance = row.chance :: number
				total += chance
				expect(chance > 0).to.equal(true)
				expect(ids[row.id]).never.to.be.ok()
				ids[row.id] = true
				expect(real(row)).to.equal(1)
			end
			expect(math.abs(total - 1) < 1e-9).to.equal(true)
			-- #3460: the fixed first prizes are their own rows, with ids of their own and no chance
			for _, row in Config.BinFirstPrizes :: { RummageBin.Row } do
				expect(ids[row.id]).never.to.be.ok()
				ids[row.id] = true
				expect(row.chance).to.equal(nil)
				expect(real(row) >= 1).to.equal(true)
			end
		end)

		it("pays the new amounts: 2 Tuna, 8 golden fish, one of each other row (#3460)", function()
			local function prizeOf(id: string): any
				for _, row in Config.BinTable :: { RummageBin.Row } do
					if row.id == id then
						return RummageBin.prize(row)
					end
				end
				error("no row " .. id)
			end
			expect(prizeOf("tuna").lures.tuna).to.equal(2)
			expect(prizeOf("fish").fish).to.equal(8)
			expect(prizeOf("salmon").lures.salmon).to.equal(1)
			expect(prizeOf("potion").potions.lucky_potion).to.equal(1)
			expect(prizeOf("crate").crates.alley_crate).to.equal(1)
			expect(prizeOf("golden").crates.alley_golden_crate).to.equal(1)
		end)

		it(
			"pays no coins, no spins and nothing sold for Robux (monetization sign-off 11-10)",
			function()
				local rows: { RummageBin.Row } = {}
				for _, row in Config.BinTable :: { RummageBin.Row } do
					table.insert(rows, row)
				end
				for _, row in Config.BinFirstPrizes :: { RummageBin.Row } do
					table.insert(rows, row)
				end
				for _, row in rows do
					local prize = RummageBin.prize(row)
					expect(prize.coins).never.to.be.ok()
					expect(prize.coinSeconds).never.to.be.ok()
					expect(prize.spins).never.to.be.ok()
					-- the sold potions are Big Money, Swift and Steady
					expect(row.potion == nil or row.potion == "lucky_potion").to.equal(true)
				end
			end
		)

		it("a later win is the row its roll lands in", function()
			local function at(roll: number): string
				return RummageBin.rowFor(5, roll).id
			end
			expect(at(0)).to.equal("tuna")
			expect(at(0.339)).to.equal("tuna")
			expect(at(0.345)).to.equal("fish")
			expect(at(0.589)).to.equal("fish")
			expect(at(0.595)).to.equal("salmon")
			expect(at(0.745)).to.equal("potion")
			expect(at(0.865)).to.equal("crate")
			expect(at(0.985)).to.equal("golden")
			expect(at(0.9999)).to.equal("golden")
			expect(RummageBin.prize(RummageBin.rowFor(5, 0.5)).fish).to.equal(8)
		end)
	end)

	describe("the bar", function()
		it(
			"is a plain bar of 5 hits and 3 paws at the bin's own width and speed (#3458)",
			function()
				local challenge = RummageBin.challenge(false, 100, half)
				expect(challenge.kind).to.equal("bar")
				expect(challenge.hitsNeeded).to.equal(5)
				expect(Config.BinHits).to.equal(5)
				expect(#(challenge.zones :: { number })).to.equal(5)
				expect(challenge.paws).to.equal(3)
				expect(challenge.zoneWidth).to.be.near(Config.BinZoneWidth, 1e-9)
				expect(challenge.speed).to.be.near(Config.BinBarSpeed, 1e-9)
				-- #3458: 0.22 and 0.80 (0.42 and 0.64 before), whatever the rescue bars are set to
				expect(Config.BinZoneWidth).to.equal(0.22)
				expect(Config.BinBarSpeed).to.equal(0.80)
				-- the marker never waits inside the first zone
				for seed = 1, 40 do
					local rng = Random.new(seed)
					local made = RummageBin.challenge(seed % 2 == 0, 100, function()
						return rng:NextNumber()
					end)
					local zones = made.zones :: { number }
					local phase = made.phase :: number
					local waiting = if phase <= 1 then phase else 2 - phase
					local width = made.zoneWidth :: number
					expect(math.abs(waiting - zones[1]) > width / 2).to.equal(true)
				end
			end
		)

		it("is wider and slower for an early rummage", function()
			local plain = RummageBin.challenge(false, 100, half)
			local early = RummageBin.challenge(true, 100, half)
			local ease = Config.BinFirstEase
			expect(
				math.abs((early.zoneWidth :: number) - (plain.zoneWidth :: number) * ease.zone)
					< 1e-9
			).to.equal(true)
			expect(math.abs((early.speed :: number) - (plain.speed :: number) * ease.speed) < 1e-9).to.equal(
				true
			)
			expect((early.zoneWidth :: number) <= 1).to.equal(true)
			expect(early.hitsNeeded).to.equal(5) -- #3458: the easy first rummages need the 5 hits too
			expect(early.zoneWidth).to.be.near(0.352, 1e-9)
			expect(early.speed).to.be.near(0.48, 1e-9)
		end)

		it("five hits in the zone win and three misses end it with nothing", function()
			local challenge = RummageBin.challenge(true, 100, half)
			local attempt = RummageBin.attempt(challenge)
			for hit = 1, 5 do
				expect(attempt.stage).to.equal("bar")
				local centre = Rescue.currentZone(attempt) :: number
				local at = Rescue.lastTimeAt(attempt, centre, attempt.lastPressAt + 3)
				expect(Rescue.pressBar(attempt, at, false)).to.equal("hit")
				expect(attempt.hits).to.equal(hit)
			end
			expect(attempt.stage).to.equal("done")
			expect(attempt.success).to.equal(true)

			local lost = RummageBin.attempt(RummageBin.challenge(false, 100, half))
			for _ = 1, 3 do
				local centre = Rescue.currentZone(lost) :: number
				local far = if centre > 0.5 then 0 else 1
				local at = Rescue.lastTimeAt(lost, far, lost.lastPressAt + 5)
				expect(Rescue.pressBar(lost, at, false)).to.equal("miss")
			end
			expect(lost.stage).to.equal("done")
			expect(lost.success).to.equal(false)
		end)
	end)

	describe("words", function()
		it("the prompt's note lists every chance over two lines, with no timer", function()
			local note = RummageBin.oddsLine()
			local lines = string.split(note, "\n")
			expect(#lines).to.equal(2)
			expect(lines[1]).to.equal("2 Tuna 34%  ·  8 golden fish 25%  ·  Salmon 15%")
			expect(lines[2]).to.equal(
				"Lucky Potion 12%  ·  Alley Crate 12%  ·  Golden Alley Crate 2%"
			)
			expect(string.find(RummageBin.EMPTY, "%d")).never.to.be.ok() -- no countdown (Monetization-Agent)
		end)

		it("the note names the next fixed prize, then the chances (#3460)", function()
			expect(RummageBin.note(0)).to.equal("Next: 2 Tuna and 10 golden fish")
			expect(RummageBin.note(1)).to.equal("Next: Alley Crate and Lucky Potion")
			expect(RummageBin.note(2)).to.equal("Next: Salmon and 10 golden fish")
			expect(RummageBin.note(3)).to.equal(RummageBin.oddsLine())
			expect(RummageBin.note(40)).to.equal(RummageBin.oddsLine())
			for uses = 0, 3 do
				expect(string.find(RummageBin.note(uses), "min")).never.to.be.ok() -- no timer
			end
		end)

		it("the bar closes on the prize's name", function()
			local title, detail = RummageBin.winWords("first_tuna", true)
			expect(title).to.equal("2 Tuna and more!")
			expect(detail).to.equal("Rare food! Put it in your bowl 🐾")
			title, detail = RummageBin.winWords("first_crate", false)
			expect(title).to.equal("Alley Crate and more!")
			expect(detail).to.equal("Open it at the Golden Fish Market")
			title, detail = RummageBin.winWords("first_salmon", false)
			expect(title).to.equal("Salmon and more!")
			expect(detail).to.equal("Food for your bowl")
			title, detail = RummageBin.winWords("tuna", false)
			expect(title).to.equal("2 Tuna!")
			expect(detail).to.equal("Food for your bowl")
			title, detail = RummageBin.winWords("fish", false)
			expect(title).to.equal("8 golden fish!")
			expect(detail).to.equal("")
			title, detail = RummageBin.winWords("golden", false)
			expect(title).to.equal("Golden Alley Crate!")
			expect(detail).to.equal("Open it at the Golden Fish Market")
			title = RummageBin.winWords("potion", false)
			expect(title).to.equal("Lucky Potion!")
			title = RummageBin.winWords("nonsense", false)
			expect(title).to.equal("Found something!")
		end)
	end)

	describe("the alleyBin switch", function()
		it("is a live flag that is on unless switched off", function()
			expect(table.find(LiveFlags.KEYS, RummageBin.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.defaults().alleyBin).to.equal(true)
			expect(LiveFlags.parse({}).alleyBin).to.equal(true)
			expect(LiveFlags.parse({ alleyBin = false }).alleyBin).to.equal(false)
		end)
	end)
	describe("the prize rolled before the bar (#3608, the binRoll switch)", function()
		local rows = RummageBin.rollRows()

		it(
			"has seven rows whose chances add to 1, most common on top, each with its own tier",
			function()
				expect(#rows).to.equal(7)
				local total, last = 0, 1
				for _, row in rows do
					local chance = row.chance or 0
					expect(chance > 0).to.equal(true)
					expect(chance <= last).to.equal(true)
					last = chance
					total += chance
					expect(row.tier == 1 or row.tier == 2 or row.tier == 3).to.equal(true)
				end
				expect(math.abs(total - 1) < 1e-9).to.equal(true)
			end
		)

		it(
			"gives each row the tier the design names, never one worked out from its chance",
			function()
				local want = {
					tuna = 1,
					fish = 1,
					salmon = 1,
					crate = 2,
					potion = 2,
					golden = 3,
					bigmoney = 3,
				}
				for _, row in rows do
					expect(RummageBin.tier(row)).to.equal(want[row.id])
				end
				expect(RummageBin.tier((Config.BinFirstPrizes :: any)[1])).to.equal(2)
			end
		)

		it("pays what the table says", function()
			local salmon = RummageBin.prize(RummageBin.rollRow("salmon") :: any)
			expect((salmon.lures :: any).salmon).to.equal(2)
			expect(salmon.fish).to.equal(8)
			local tuna = RummageBin.prize(RummageBin.rollRow("tuna") :: any)
			expect((tuna.lures :: any).tuna).to.equal(2)
			expect(tuna.fish).to.equal(3)
			expect(RummageBin.prize(RummageBin.rollRow("fish") :: any).fish).to.equal(10)
			expect(Catalog.getPotion("big_tip_potion")).to.be.ok()
			expect(Catalog.getCrate("alley_golden_crate")).to.be.ok()
			expect(RummageBin.rowName(RummageBin.rollRow("salmon") :: any)).to.equal(
				"2 Salmon and 8 golden fish"
			)
		end)

		it("matches the table over 1,000 rolls", function()
			local random = Random.new(3608)
			local counts: { [string]: number } = {}
			for _ = 1, 1000 do
				local save = RummageBin.fresh()
				save.uses = Config.BinFirstUses
				local row, mode = RummageBin.choose(save, random:NextNumber())
				expect(mode).to.equal(RummageBin.MODE_ROLL)
				expect(save.prize).to.equal(row.id)
				counts[row.id] = (counts[row.id] or 0) + 1
			end
			for _, row in rows do
				local share = (counts[row.id] or 0) / 1000
				expect(math.abs(share - (row.chance or 0)) < 0.05).to.equal(true)
			end
		end)

		it("gives the first three wins their fixed prizes with no roll", function()
			local save = RummageBin.fresh()
			for index = 1, Config.BinFirstUses do
				local row, mode = RummageBin.choose(save, 0.999)
				expect(mode).to.equal(RummageBin.MODE_FIXED)
				expect(row.id).to.equal((Config.BinFirstPrizes :: any)[index].id)
				expect(RummageBin.rollIndex(row.id)).to.equal(nil)
				local won = RummageBin.winStored(save, T)
				expect(won).to.equal(row)
				expect(save.prize).to.equal(nil)
				expect(save.uses).to.equal(index)
			end
			local _, mode = RummageBin.choose(save, 0)
			expect(mode).to.equal(RummageBin.MODE_ROLL)
		end)

		it("never rerolls a prize that waits: a miss, a retry and a rejoin keep it", function()
			local save = RummageBin.fresh()
			save.uses = 9
			local first = RummageBin.choose(save, 0.99) -- the rarest row
			expect(first.id).to.equal("bigmoney")
			for _, roll in { 0, 0.3, 0.6, 0.99 } do
				local again, mode = RummageBin.choose(save, roll)
				expect(again.id).to.equal("bigmoney")
				expect(mode).to.equal(RummageBin.MODE_WAITING)
			end
			-- through the store and back, as a rejoin reads it
			local read = RummageBin.sanitize({ nextAt = 0, uses = 9, prize = save.prize }, T)
			expect(read.prize).to.equal("bigmoney")
			expect(RummageBin.choose(read, 0).id).to.equal("bigmoney")
			-- the win pays it, starts the wait and clears it
			local won = RummageBin.winStored(read, T)
			expect((won :: any).id).to.equal("bigmoney")
			expect(read.prize).to.equal(nil)
			expect(read.nextAt).to.equal(T + Config.BinCooldownSeconds)
			expect(RummageBin.winStored(read, T)).to.equal(nil)
		end)

		it("drops a stored prize whose row is gone or broken", function()
			for _, raw in { "nothing", 7, {}, true } :: { any } do
				expect(RummageBin.sanitize({ nextAt = 0, uses = 4, prize = raw }, T).prize).to.equal(
					nil
				)
			end
		end)

		it("is behind its own switch, off by default", function()
			expect(LiveFlags.parse({}).binRoll).to.equal(false)
			expect(LiveFlags.parse({ binRoll = true }).binRoll).to.equal(true)
		end)

		it("words a rolled win from the rolled table", function()
			local title = RummageBin.winWords("salmon", false, true)
			expect(title).to.equal("2 Salmon and more!")
			expect((RummageBin.winWords("bigmoney", false, true))).to.be.ok()
		end)
	end)
end
