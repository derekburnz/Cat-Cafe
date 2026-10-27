--!strict
-- shared/Codes.luau and Catalog.codes (F65, data-model section 11d): what a typed code becomes, why a code cannot
-- pay, the wrong-code lock, the circle's open and close edges, and the launch rows.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Codes = require(Shared.Codes)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 1_800_000_000

	local function fresh(): any
		return ProfileSchema.template(1000)
	end

	describe("normalize (codes are not case sensitive)", function()
		it("trims spaces and lowercases, so PlayTest, playtest and PLAYTEST are one code", function()
			expect(Codes.normalize("PlayTest")).to.equal("playtest")
			expect(Codes.normalize("playtest")).to.equal("playtest")
			expect(Codes.normalize("  PLAYTEST \t")).to.equal("playtest")
			expect(Codes.normalize("likes1000")).to.equal("likes1000")
		end)

		it("refuses anything that is not 1 to CodeMaxLength letters and digits", function()
			local cases: { any } = {
				"",
				"   ",
				"play test",
				"group!",
				"play-test",
				"café",
				string.rep("a", Config.CodeMaxLength + 1),
				string.rep(" ", 30) .. string.rep("a", 11), -- 41 bytes before trimming
				42,
				nil,
				{ "playtest" },
			}
			for _, raw in cases do
				expect(Codes.normalize(raw)).never.to.be.ok()
			end
			expect(Codes.normalize(string.rep("a", Config.CodeMaxLength))).to.equal(
				string.rep("a", Config.CodeMaxLength)
			)
		end)
	end)

	describe("refusal", function()
		it("pays a known active code once per player", function()
			local profile = fresh()
			expect(Codes.refusal(profile, "playtest", NOW)).never.to.be.ok()
			profile.codesRedeemed.playtest = NOW
			expect(Codes.refusal(profile, "playtest", NOW)).to.equal(Codes.USED)
		end)

		it("answers an unknown code, an inactive one and one past its endsAt", function()
			local profile = fresh()
			expect(Codes.refusal(profile, "nope", NOW)).to.equal(Codes.UNKNOWN)
			expect(Codes.refusal(profile, "launch", NOW)).to.equal(Codes.EXPIRED)
			local ended: Types.CodeDef = { id = "x", active = true, endsAt = NOW, prize = {} }
			expect(Codes.expired(ended, NOW - 1)).to.equal(false)
			expect(Codes.expired(ended, NOW)).to.equal(true)
		end)

		it("a group code has expired while Config.GroupId is 0 and needs membership after", function()
			local profile = fresh()
			expect(Config.GroupId).to.equal(0)
			expect(Codes.refusal(profile, "group", NOW, true)).to.equal(Codes.EXPIRED)
			local open: Types.CodeDef = { id = "g", active = true, requiresGroup = true, prize = {} }
			expect(Codes.expired(open, NOW)).to.equal(true) -- GroupId 0
		end)
	end)

	describe("the wrong-code lock", function()
		it("locks on the CodeWrongLimit-th wrong code inside the window, for CodeLockSeconds", function()
			local guard = Codes.newGuard()
			for i = 1, Config.CodeWrongLimit - 1 do
				expect(Codes.noteWrong(guard, 100 + i)).to.equal(false)
				expect(Codes.locked(guard, 100 + i)).to.equal(false)
			end
			expect(Codes.noteWrong(guard, 110)).to.equal(true)
			expect(Codes.locked(guard, 110 + Config.CodeLockSeconds - 1)).to.equal(true)
			expect(Codes.locked(guard, 110 + Config.CodeLockSeconds)).to.equal(false)
			-- the count starts again after a lock
			expect(Codes.noteWrong(guard, 200)).to.equal(false)
		end)

		it("forgets wrong codes older than the window", function()
			local guard = Codes.newGuard()
			for i = 1, Config.CodeWrongLimit - 1 do
				Codes.noteWrong(guard, i)
			end
			expect(Codes.noteWrong(guard, 1 + Config.CodeWrongWindowSeconds)).to.equal(false)
			expect(#guard.wrong).to.equal(Config.CodeWrongLimit - 1)
		end)
	end)

	describe("the circle (v0.10)", function()
		it("opens at CodesCircleRadius and closes only past CodesCircleRadius + 1", function()
			local r = Config.CodesCircleRadius
			expect(Codes.circleOpen(false, r)).to.equal(true)
			expect(Codes.circleOpen(false, r + 0.5)).to.equal(false)
			expect(Codes.circleOpen(true, r + 0.5)).to.equal(true)
			expect(Codes.circleOpen(true, r + 1)).to.equal(true)
			expect(Codes.circleOpen(true, r + 1.01)).to.equal(false)
		end)
	end)

	describe("Catalog.codes (section 11d)", function()
		it("keys every row by its own lowercase id, letters and digits", function()
			for key, def in Catalog.codes do
				expect(def.id).to.equal(key)
				expect(Codes.normalize(key)).to.equal(key)
			end
		end)

		it("playtest pays the friends-alpha starter pack", function()
			local def = Catalog.codes.playtest
			expect(def.active).to.equal(true)
			expect(def.prize :: any).to.deepEqual({
				coins = 5000,
				fish = 300,
				spins = 10,
				crates = { classic_crate = 3, alley_crate = 1, classic_golden_crate = 1 },
				lures = { tuna = 3, salmon = 2, caviar = 1 },
			})
		end)

		it("launch and group wait to be switched on, and group needs the group", function()
			expect(Catalog.codes.launch.active).to.equal(false)
			expect(Catalog.codes.launch.prize :: any).to.deepEqual({
				coins = 1000,
				coinSeconds = 600,
				fish = 25,
				spins = 2,
				lures = { tuna = 3 },
			})
			expect(Catalog.codes.group.active).to.equal(false)
			expect(Catalog.codes.group.requiresGroup).to.equal(true)
			expect(Catalog.codes.group.prize.coinSeconds).to.equal(1800)
			expect(Catalog.codes.group.prize.coins).to.equal(2500)
		end)

		it("every prize names real crates and foods", function()
			for _, def in Catalog.codes do
				for crateId in def.prize.crates or {} do
					expect(Catalog.getCrate(crateId)).to.be.ok()
				end
				for lureId in def.prize.lures or {} do
					expect(Catalog.getLure(lureId)).to.be.ok()
				end
			end
		end)
	end)

	describe("save (version 9)", function()
		it("keeps code ids that could be codes, with a whole time, and drops the rest", function()
			local raw: any = ProfileSchema.template(1000)
			raw.version = 8
			raw.codesRedeemed = {
				playtest = 1234.9,
				oldcode = 50,
				["bad id"] = 10,
				launch = "soon",
				huge = math.huge,
			}
			local profile = ProfileSchema.migrate(raw, 2000)
			expect(profile.version).to.equal(ProfileSchema.VERSION)
			expect(profile.codesRedeemed :: any).to.deepEqual({ playtest = 1234, oldcode = 50, huge = 0 })
		end)
	end)

	describe("Codes edges (QA)", function()
		local Client = game:GetService("StarterPlayer")
			:WaitForChild("StarterPlayerScripts")
			:WaitForChild("Client")
		local CodeEntry = require(
			Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CodeEntry")
		) :: any

		-- Park and Miller's generator: exact in doubles, so a run is the same everywhere
		local seed = 65
		local function uniform(): number
			seed = seed * 48271 % 2147483647
			return seed / 2147483647
		end
		local function pick<T>(list: { T }): T
			return list[1 + math.floor(uniform() * #list)]
		end

		-- Bytes a player can type or paste: letters both ways, digits, spaces and tabs, punctuation, the
		-- underscore %w leaves out, a NUL, and the UTF-8 of an accent, a fullwidth letter and an emoji.
		local PIECES = {
			"a",
			"Z",
			"q",
			"7",
			"0",
			" ",
			"\t",
			"\n",
			"!",
			"-",
			"_",
			".",
			"\0",
			"é",
			"Ａ",
			"🐱",
			"playtest",
			"PLAY",
			"launch",
		}
		local function typed(): string
			local parts: { string } = {}
			for _ = 1, math.floor(uniform() * 14) do
				table.insert(parts, pick(PIECES))
			end
			return table.concat(parts)
		end

		-- What the server must make of a raw text, worked out here: nil unless it is at most MAX_BYTES and,
		-- trimmed of whitespace, 1 to CodeMaxLength ASCII letters and digits; then those, lowercased.
		local function want(raw: string): string?
			if #raw > Codes.MAX_BYTES then
				return nil
			end
			local first, last = 1, #raw
			while first <= last and string.find(string.sub(raw, first, first), "^%s$") do
				first += 1
			end
			while last >= first and string.find(string.sub(raw, last, last), "^%s$") do
				last -= 1
			end
			local text = string.sub(raw, first, last)
			if #text < 1 or #text > Config.CodeMaxLength then
				return nil
			end
			for i = 1, #text do
				local byte = string.byte(text, i)
				local digit = byte >= 48 and byte <= 57
				local upper = byte >= 65 and byte <= 90
				local lower = byte >= 97 and byte <= 122
				if not (digit or upper or lower) then
					return nil
				end
			end
			return string.lower(text)
		end

		-- The box only sends what CodeEntry.clean keeps, so a code typed with junk around it must still reach
		-- the server as that code, and nothing the box lights Redeem for may count against the wrong-code lock
		-- as malformed.
		it("reads 3,000 seeded texts the same way in the box and on the server", function()
			-- MAX_BYTES counts before trimming: 40 bytes still reads, 41 does not
			local padded = string.rep(" ", Codes.MAX_BYTES - Config.CodeMaxLength)
				.. string.rep("a", Config.CodeMaxLength)
			expect(Codes.normalize(padded)).to.equal(string.rep("a", Config.CodeMaxLength))
			expect(Codes.normalize(" " .. padded)).to.equal(nil)
			for n = 1, 3000 do
				local raw = typed()
				local at = string.format("%d %q: ", n, raw)
				local direct = Codes.normalize(raw)
				expect(at .. tostring(direct)).to.equal(at .. tostring(want(raw)))
				local sent = CodeEntry.clean(raw)
				expect(#sent <= Config.CodeMaxLength).to.equal(true)
				if CodeEntry.canRedeem(raw) then
					expect(at .. tostring(Codes.normalize(sent))).to.equal(at .. string.lower(sent))
				else
					expect(sent).to.equal("")
				end
			end
		end)

		it("takes every code typed with any case, spaces and punctuation in the box", function()
			for id in pairs(Catalog.codes) do
				for _, raw in
					{
						id,
						string.upper(id),
						"  " .. id .. "  ",
						string.sub(id, 1, 1) .. " " .. string.sub(id, 2) .. "!",
						"\t" .. string.upper(string.sub(id, 1, 2)) .. string.sub(id, 3) .. "\n",
					}
				do
					local sent = CodeEntry.clean(raw)
					expect(string.format("%q %s", raw, tostring(Codes.normalize(sent)))).to.equal(
						string.format("%q %s", raw, id)
					)
				end
			end
		end)

		-- The guard against reference rules: a wrong code at t counts the wrong codes in (t - window, t] with it,
		-- and the CodeWrongLimit-th locks [t, t + CodeLockSeconds) and starts the count again; while locked a
		-- try is answered locked and counts nothing (CodeService checks the lock first).
		it("locks exactly as the rules say over 300 seeded try sequences", function()
			for run = 1, 300 do
				local guard = Codes.newGuard()
				local wrong: { number } = {}
				local lockedUntil = 0
				local t = 0
				for step = 1, 40 do
					t += pick({ 0, 0.5, 2, 2, 2, 7.5, 12, 30, 59.999, 60, 60.001 })
					local at = string.format("run %d step %d t=%s: ", run, step, tostring(t))
					local lockedNow = t < lockedUntil
					expect(at .. tostring(Codes.locked(guard, t))).to.equal(
						at .. tostring(lockedNow)
					)
					if lockedNow then
						continue
					end
					local kept: { number } = {}
					for _, before in wrong do
						if t - before < Config.CodeWrongWindowSeconds then
							table.insert(kept, before)
						end
					end
					table.insert(kept, t)
					local locks = #kept >= Config.CodeWrongLimit
					if locks then
						wrong = {}
						lockedUntil = t + Config.CodeLockSeconds
					else
						wrong = kept
					end
					expect(at .. tostring(Codes.noteWrong(guard, t))).to.equal(
						at .. tostring(locks)
					)
					if locks then
						-- the count starts again, which matters if CodeLockSeconds is ever made shorter than the window
						expect(at .. #guard.wrong).to.equal(at .. "0")
					end
				end
			end
		end)

		-- RedeemCode allows 1 try per 2 s. Guessing at that pace, no 60 s stretch may see more than
		-- CodeWrongLimit guesses reach the code table, and an hour lets through about 5 every 68 s.
		it(
			"lets at most CodeWrongLimit guesses through in any minute at the remote's limit",
			function()
				local guard = Codes.newGuard()
				local looked: { number } = {}
				for t = 0, 3600, 2 do
					if not Codes.locked(guard, t) then
						table.insert(looked, t)
						Codes.noteWrong(guard, t)
					end
				end
				for i, start in looked do
					local inside = 0
					for j = i, #looked do
						if looked[j] - start < Config.CodeWrongWindowSeconds then
							inside += 1
						end
					end
					expect(inside <= Config.CodeWrongLimit).to.equal(true)
				end
				expect(#looked <= 270).to.equal(true)
			end
		)

		-- The box must never open where RedeemCode would say "Walk up to the Codes Cat": the circle sits 6 studs in
		-- front of the station's pivot (Layout and the asset), and the box stays open to CodesCircleRadius + 1.
		it("keeps the open box inside CodesCatRange of the station", function()
			expect(6 + Config.CodesCircleRadius + 1 <= Config.CodesCatRange).to.equal(true)
		end)

		it(
			"never flickers on the circle's edge: a 2,000 step walk opens only inside and closes only past + 1",
			function()
				local open = false
				local distance = Config.CodesCircleRadius + 3
				for _ = 1, 2000 do
					distance = math.clamp(
						distance + (uniform() - 0.5) * 0.8,
						0,
						Config.CodesCircleRadius + 4
					)
					local now = Codes.circleOpen(open, distance)
					local at = string.format("%s at %.3f: ", open and "open" or "shut", distance)
					if open then
						expect(at .. tostring(now)).to.equal(
							at .. tostring(distance <= Config.CodesCircleRadius + 1)
						)
					else
						expect(at .. tostring(now)).to.equal(
							at .. tostring(distance <= Config.CodesCircleRadius)
						)
					end
					open = now
				end
			end
		)

		it("refuses in the order the box words it: unknown, used, expired, group", function()
			local profile = fresh()
			profile.codesRedeemed.launch = NOW - 10
			expect(Codes.refusal(profile, "nope", NOW, true)).to.equal(Codes.UNKNOWN)
			-- used wins over expired: an old code that has since been switched off still says it was used
			expect(Codes.refusal(profile, "launch", NOW, true)).to.equal(Codes.USED)
			expect(Codes.refusal(fresh(), "launch", NOW, true)).to.equal(Codes.EXPIRED)
			expect(Codes.refusal(fresh(), "group", NOW, true)).to.equal(Codes.EXPIRED)
			expect(Codes.refusal(fresh(), "playtest", NOW, false)).never.to.be.ok()
			for id, def in pairs(Catalog.codes) do
				expect(Codes.normalize(id)).to.equal(id)
				expect(def.id).to.equal(id)
			end
		end)
	end)
end
