--!strict
-- shared/IdeaCredits.luau against idea-credits.md (#1083): a stored credit made safe to show, the Thank You board's
-- rows newest first with display names only (a hidden player or a failed lookup shows "a player", never a username
-- or id), at most MAX_ROWS, and whether a player has a credit. QA checks 4 to 6. Also save version 30's hideCredit.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local IdeaCredits = require(Shared.IdeaCredits)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function credit(userId: number, idea: string, addedAt: number): IdeaCredits.Credit
		return { userId = userId, idea = idea, version = 190, addedAt = addedAt }
	end

	describe("sanitize", function()
		it("keeps a good credit and drops anything that is not one", function()
			expect(IdeaCredits.sanitize({ userId = 7, idea = "Cats nap on benches", version = 190, addedAt = 5 }) :: any).to.deepEqual(
				{ userId = 7, idea = "Cats nap on benches", version = 190, addedAt = 5 }
			)
			expect(IdeaCredits.sanitize(nil)).to.equal(nil)
			expect(IdeaCredits.sanitize("x")).to.equal(nil)
			expect(IdeaCredits.sanitize({ userId = 0, idea = "a", version = 1, addedAt = 1 })).to.equal(nil)
			expect(IdeaCredits.sanitize({ userId = 7, idea = 5, version = 1, addedAt = 1 })).to.equal(nil)
			expect(IdeaCredits.sanitize({ userId = 7, idea = "   ", version = 1, addedAt = 1 })).to.equal(nil)
			expect(IdeaCredits.sanitize({ userId = 7, idea = "a", version = 0 / 0, addedAt = 1 })).to.equal(nil)
			expect(IdeaCredits.sanitize({ userId = 7, idea = "\255bad", version = 1, addedAt = 1 })).to.equal(nil)
		end)

		it("keeps a creditId of c and digits only (#1216)", function()
			local function idOf(raw: unknown): string?
				local credit = IdeaCredits.sanitize({ userId = 7, idea = "Idea", version = 1, addedAt = 1, creditId = raw })
				return (credit :: any).creditId
			end
			expect(idOf("c3")).to.equal("c3")
			expect(idOf("c120")).to.equal("c120")
			expect(idOf("3")).to.equal(nil)
			expect(idOf("c")).to.equal(nil)
			expect(idOf("cx1")).to.equal(nil)
			expect(idOf("c1 ")).to.equal(nil)
			expect(idOf(5)).to.equal(nil)
			expect(idOf("c" .. string.rep("1", 20))).to.equal(nil)
		end)

		it("trims, drops control characters and cuts a long idea at a whole character", function()
			local trimmed = IdeaCredits.sanitize({ userId = 7, idea = "  two\nlines  ", version = 1, addedAt = 1 })
			expect((trimmed :: any).idea).to.equal("two lines")
			local long = string.rep("é", 40) -- 80 bytes
			local cut = IdeaCredits.sanitize({ userId = 7, idea = long, version = 1, addedAt = 1 }) :: any
			expect(#cut.idea <= IdeaCredits.IDEA_BYTES).to.equal(true)
			expect(utf8.len(cut.idea)).to.equal(24)
		end)
	end)

	describe("rows (QA checks 4 to 6)", function()
		it("lists the newest first with the display name, and 'a player' when hidden or not looked up", function()
			local rows = IdeaCredits.rows(
				{ credit(1, "Old idea", 10), credit(2, "New idea", 30), credit(3, "Middle idea", 20) },
				{ [1] = "MochiPie", [2] = "Biscuit" },
				{ [2] = true }
			)
			expect(rows :: any).to.deepEqual({
				{ idea = "New idea", version = 190, name = IdeaCredits.ANON }, -- hidden
				{ idea = "Middle idea", version = 190, name = IdeaCredits.ANON }, -- lookup failed
				{ idea = "Old idea", version = 190, name = "MochiPie" },
			})
			expect(IdeaCredits.ANON).to.equal("a player")
		end)

		it("carries each credit's creditId onto its row, hidden or not (#1216)", function()
			local linked = credit(1, "Linked idea", 2)
			linked.creditId = "c4"
			local rows = IdeaCredits.rows({ linked, credit(2, "Other", 1) }, { [1] = "MochiPie" }, { [1] = true })
			expect(rows[1].creditId).to.equal("c4")
			expect(rows[1].name).to.equal(IdeaCredits.ANON)
			expect(rows[2].creditId).to.equal(nil)
		end)

		it("never puts a user id in a row", function()
			local rows = IdeaCredits.rows({ credit(123456789, "Idea", 1) }, {}, {})
			expect(string.find(rows[1].name, "123456789", 1, true)).to.equal(nil)
		end)

		it("shows at most MAX_ROWS", function()
			local many: { IdeaCredits.Credit } = {}
			for i = 1, IdeaCredits.MAX_ROWS + 10 do
				table.insert(many, credit(i, "Idea " .. i, i))
			end
			local rows = IdeaCredits.rows(many, {}, {})
			expect(#rows).to.equal(IdeaCredits.MAX_ROWS)
			expect(rows[1].idea).to.equal("Idea " .. (IdeaCredits.MAX_ROWS + 10))
		end)

		it("knows who has a credit", function()
			local list = { credit(1, "a", 1), credit(2, "b", 2) }
			expect(IdeaCredits.has(list, 2)).to.equal(true)
			expect(IdeaCredits.has(list, 3)).to.equal(false)
		end)
	end)

	describe("save version 30", function()
		it("keeps hideCredit only as true", function()
			expect(ProfileSchema.VERSION >= 30).to.equal(true)
			expect(ProfileSchema.template(1000).hideCredit).to.equal(nil)
			local raw: any = ProfileSchema.template(1000)
			raw.version = 29
			raw.hideCredit = true
			expect(ProfileSchema.migrate(raw, 1000).hideCredit).to.equal(true)
			raw.hideCredit = "yes"
			expect(ProfileSchema.migrate(raw, 1000).hideCredit).to.equal(nil)
			raw.hideCredit = nil
			expect(ProfileSchema.migrate(raw, 1000).hideCredit).to.equal(nil)
		end)
	end)
end
