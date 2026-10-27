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
end
