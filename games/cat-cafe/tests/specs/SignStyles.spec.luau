--!strict
-- SignStyles.luau (#1625): which sign styles a player owns (saved, or through the King Cat Pack), which one the sign
-- shows, and saves made whole.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local SignStyles = require(Shared.SignStyles)

	local function owns(set: { [number]: boolean }): (number) -> boolean
		return function(id: number): boolean
			return set[id] == true
		end
	end

	describe("owned and shown", function()
		it("owns a saved style, and the Royal Crest only with the King Cat Pack", function()
			expect(SignStyles.owned({}, owns({})) :: any).to.deepEqual({})
			expect(SignStyles.owned({ bakery_stripes = true }, owns({})) :: any).to.deepEqual({
				"bakery_stripes",
			})
			local king = owns({ [Config.KingPackPassId] = true })
			expect(SignStyles.owned({ bakery_stripes = true }, king) :: any).to.deepEqual({
				"bakery_stripes",
				"royal_crest",
			})
			-- a saved royal_crest means nothing without the pass
			expect(SignStyles.owned({ royal_crest = true }, owns({})) :: any).to.deepEqual({})
		end)

		it("shows the pick only while it is owned", function()
			expect(SignStyles.shown({ bakery_stripes = true }, "bakery_stripes", owns({}))).to.equal(
				"bakery_stripes"
			)
			expect(SignStyles.shown({}, "bakery_stripes", owns({}))).to.equal(nil)
			expect(SignStyles.shown({ bakery_stripes = true }, nil, owns({}))).to.equal(nil)
			expect(SignStyles.shown({}, "royal_crest", owns({ [Config.KingPackPassId] = true }))).to.equal(
				"royal_crest"
			)
		end)

		it("names a model for every style", function()
			for _, style in SignStyles.LIST do
				expect(style.model:match("^CatCafe_Plot_Sign")).to.be.ok()
			end
		end)
	end)

	describe("SetSignStyle's check (pickFor)", function()
		it("refuses a style the player doesn't own", function()
			expect(SignStyles.pickFor("bakery_stripes", {}, owns({}))).to.equal(false)
			expect(SignStyles.pickFor("royal_crest", { royal_crest = true }, owns({}))).to.equal(
				false
			)
		end)

		it("refuses an unknown id or a non-string", function()
			expect(SignStyles.pickFor("nope", { nope = true }, owns({}))).to.equal(false)
			expect(SignStyles.pickFor(5, {}, owns({}))).to.equal(false)
			expect(SignStyles.pickFor({}, {}, owns({}))).to.equal(false)
		end)

		it('takes an owned style, and nil, "" or "default" as the plain sign', function()
			local ok, pick =
				SignStyles.pickFor("bakery_stripes", { bakery_stripes = true }, owns({}))
			expect(ok).to.equal(true)
			expect(pick).to.equal("bakery_stripes")
			ok, pick =
				SignStyles.pickFor("royal_crest", {}, owns({ [Config.KingPackPassId] = true }))
			expect(ok).to.equal(true)
			expect(pick).to.equal("royal_crest")
			ok, pick = SignStyles.pickFor(nil, {}, owns({}))
			expect(ok).to.equal(true)
			expect(pick).to.equal(nil)
			for _, plain in { "", "default" } do
				ok, pick = SignStyles.pickFor(plain, {}, owns({}))
				expect(ok).to.equal(true)
				expect(pick).to.equal(nil)
			end
		end)
	end)

	describe("saves", function()
		it("keeps only known saved styles and a known pick", function()
			expect(SignStyles.sanitize({
				bakery_stripes = true,
				royal_crest = true,
				nope = true,
				x = 1,
			}) :: any).to.deepEqual({ bakery_stripes = true })
			expect(SignStyles.sanitize(nil) :: any).to.deepEqual({})
			expect(SignStyles.sanitizePick("royal_crest")).to.equal("royal_crest")
			expect(SignStyles.sanitizePick("nope")).to.equal(nil)
			expect(SignStyles.sanitizePick(5)).to.equal(nil)
		end)
	end)
end
