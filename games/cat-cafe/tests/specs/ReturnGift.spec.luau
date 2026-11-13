--!strict
-- shared/ReturnGift (#3772, come-back-tomorrow.md section 2a): a golden crate once per account on its first join on a
-- later UTC day, only for accounts first seen from Config.ReturnGiftFromDay, marked in codesRedeemed.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local ReturnGift = require(Shared.ReturnGift)
	local UpdateGift = require(Shared.UpdateGift)
	local Catalog = require(Shared.Catalog)

	local DAY = 86400
	local FIRST = Config.ReturnGiftFromDay
	local NOON = FIRST * DAY + 12 * 3600 -- midday UTC on the ship day

	local function newAccount(day: number): any
		local profile: any = ProfileSchema.template(day * DAY + 3600)
		profile.telemetry.firstDay = day
		return profile
	end

	it("starts off behind its own switch", function()
		expect(LiveFlags.OFF_BY_DEFAULT[ReturnGift.FLAG]).to.equal(true)
		expect(table.find(LiveFlags.KEYS, ReturnGift.FLAG) ~= nil).to.equal(true)
		expect(LiveFlags.defaults()[ReturnGift.FLAG]).to.equal(false)
	end)

	it("waits on the first day and pays on any later day, once", function()
		local profile = newAccount(FIRST)
		expect(ReturnGift.waiting(profile, NOON)).to.equal(true)
		expect(ReturnGift.due(profile, NOON)).to.equal(false)
		expect(ReturnGift.due(profile, NOON + DAY)).to.equal(true)
		expect(ReturnGift.waiting(profile, NOON + DAY)).to.equal(false)
		-- it never expires: a week later still pays
		expect(ReturnGift.due(profile, NOON + 7 * DAY)).to.equal(true)
		expect(ReturnGift.daysSince(profile, NOON + 7 * DAY)).to.equal(7)
		profile.codesRedeemed[ReturnGift.KEY] = NOON + DAY
		expect(ReturnGift.due(profile, NOON + 2 * DAY)).to.equal(false)
		expect(ReturnGift.waiting(profile, NOON)).to.equal(false)
	end)

	it("skips accounts from before the ship day and ones with no first day", function()
		local old = newAccount(FIRST - 1)
		expect(ReturnGift.due(old, NOON + DAY)).to.equal(false)
		expect(ReturnGift.waiting(old, (FIRST - 1) * DAY + 100)).to.equal(false)
		local unknown = newAccount(0)
		expect(ReturnGift.due(unknown, NOON)).to.equal(false)
	end)

	it("pays a golden crate of the best open area", function()
		local prize: any = ReturnGift.prize()
		expect(prize.crates.highest_golden).to.equal(1)
		expect(prize.coins).to.equal(nil)
		expect(prize.fish).to.equal(nil)
	end)

	it("is marked under a key no code and no update gift can have", function()
		expect(UpdateGift.isKey(ReturnGift.KEY)).to.equal(true) -- so the used codes list leaves it out
		expect(string.find(ReturnGift.KEY, "%d")).to.equal(nil)
		expect(UpdateGift.key("2026-11-14") ~= ReturnGift.KEY).to.equal(true)
		for _, code in Catalog.codes do
			expect(string.lower((code :: any).id) ~= ReturnGift.KEY).to.equal(true)
		end
	end)
end
