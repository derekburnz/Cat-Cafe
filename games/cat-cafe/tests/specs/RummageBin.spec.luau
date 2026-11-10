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

	describe("save (version 48)", function()
		it("a new save's bin is full at once and has no wins", function()
			local profile = ProfileSchema.template(T)
			expect(profile.bin.nextAt).to.equal(0)
			expect(profile.bin.uses).to.equal(0)
			expect(RummageBin.ready(profile.bin, T)).to.equal(true)
			expect(RummageBin.early(profile.bin)).to.equal(true)
		end)

		it("a save from before the bin gets a full bin", function()
			local raw: any = ProfileSchema.template(T)
			raw.version = 47
			raw.bin = nil
			local profile = ProfileSchema.migrate(raw, T)
			expect(profile.bin.nextAt).to.equal(0)
			expect(profile.bin.uses).to.equal(0)
		end)

		it("keeps a saved wait and wins through a load", function()
			local raw: any = ProfileSchema.template(T)
			raw.bin = { nextAt = T + 400, uses = 7 }
			local profile = ProfileSchema.migrate(raw, T)
			expect(profile.bin.nextAt).to.equal(T + 400)
			expect(profile.bin.uses).to.equal(7)
			expect(RummageBin.ready(profile.bin, T)).to.equal(false)
			expect(RummageBin.ready(profile.bin, T + 400)).to.equal(true)
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
			"the first win is always Tuna and the second always an Alley Crate, whatever the roll",
			function()
				for _, roll in { 0, 0.3, 0.7, 0.999 } do
					local save = RummageBin.fresh()
					local first = RummageBin.win(save, T, roll)
					expect(first.id).to.equal("tuna")
					expect((RummageBin.prize(first).lures :: any).tuna).to.equal(1)
					local second = RummageBin.win(save, T, roll)
					expect(second.id).to.equal("crate")
					expect((RummageBin.prize(second).crates :: any).alley_crate).to.equal(1)
				end
			end
		)

		it("the table's chances add to 1 and every row names something real", function()
			local total = 0
			local ids: { [string]: boolean } = {}
			for _, row in Config.BinTable do
				total += row.chance
				expect(row.chance > 0).to.equal(true)
				expect(ids[row.id]).never.to.be.ok()
				ids[row.id] = true
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
				expect(kinds).to.equal(1)
			end
			expect(math.abs(total - 1) < 1e-9).to.equal(true)
			for _, id in Config.BinFirstPrizes do
				expect(ids[id]).to.equal(true)
			end
		end)

		it(
			"pays no coins, no spins and nothing sold for Robux (monetization sign-off 11-10)",
			function()
				for _, row in Config.BinTable do
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
			expect(at(0.399)).to.equal("tuna")
			expect(at(0.40)).to.equal("fish")
			expect(at(0.649)).to.equal("fish")
			expect(at(0.65)).to.equal("salmon")
			expect(at(0.77)).to.equal("potion")
			expect(at(0.88)).to.equal("crate")
			expect(at(0.98)).to.equal("golden")
			expect(at(0.9999)).to.equal("golden")
			expect(RummageBin.prize(RummageBin.rowFor(5, 0.5)).fish).to.equal(5)
		end)

		it("a third win rolls the table", function()
			local save = RummageBin.fresh()
			RummageBin.win(save, T, 0.99)
			RummageBin.win(save, T, 0.99)
			expect(RummageBin.win(save, T, 0.99).id).to.equal("golden")
		end)
	end)

	describe("the bar", function()
		it("is a plain bar of 2 hits and 3 paws with the Alleyway's ease", function()
			local challenge = RummageBin.challenge(false, 100, half)
			expect(challenge.kind).to.equal("bar")
			expect(challenge.hitsNeeded).to.equal(2)
			expect(challenge.paws).to.equal(3)
			local ease = Config.RescueAreaEase.alley
			expect(
				math.abs(
					(challenge.zoneWidth :: number) - Config.RescueZoneWidth.Common * ease.zone
				) < 1e-9
			).to.equal(true)
			expect(
				math.abs((challenge.speed :: number) - Config.RescueBarSpeed.Common * ease.speed)
					< 1e-9
			).to.equal(true)
		end)

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
			expect(early.hitsNeeded).to.equal(2)
		end)

		it("two hits in the zone win and three misses end it with nothing", function()
			local challenge = RummageBin.challenge(true, 100, half)
			local attempt = RummageBin.attempt(challenge)
			for _ = 1, 2 do
				local centre = Rescue.currentZone(attempt) :: number
				local at = Rescue.lastTimeAt(attempt, centre, attempt.lastPressAt + 5)
				expect(Rescue.pressBar(attempt, at, false)).to.equal("hit")
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
			expect(lines[1]).to.equal("Tuna 40%  ·  5 golden fish 25%  ·  Salmon 12%")
			expect(lines[2]).to.equal(
				"Lucky Potion 11%  ·  Alley Crate 10%  ·  Golden Alley Crate 2%"
			)
			expect(string.find(RummageBin.EMPTY, "%d")).never.to.be.ok() -- no countdown (Monetization-Agent)
		end)

		it("the bar closes on the prize's name", function()
			local title, detail = RummageBin.winWords("tuna", true)
			expect(title).to.equal("Tuna!")
			expect(detail).to.equal("Rare food! Put it in your bowl 🐾")
			title, detail = RummageBin.winWords("tuna", false)
			expect(detail).to.equal("Food for your bowl")
			title, detail = RummageBin.winWords("fish", false)
			expect(title).to.equal("5 golden fish!")
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
end
