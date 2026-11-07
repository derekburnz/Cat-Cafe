--!strict
-- shared/SessionRecap.luau (#1920, first-hour.md section 6): the recap goes out once a session after
-- Config.RecapAfterSeconds of play with the sessionRecap setting on, and counts only this session.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SessionRecap = require(Shared.SessionRecap)
	local Settings = require(Shared.Settings)

	local NOW = 1_800_000_000

	local function addCats(profile: any, count: number)
		local added = 0
		for _, def in Catalog.cats do
			if added >= count then
				break
			end
			if profile.collection[def.id] == nil then
				profile.collection[def.id] = NOW
				added += 1
			end
		end
	end

	it("comes after 40 minutes, with the setting on by default", function()
		expect(Config.RecapAfterSeconds).to.equal(2400)
		expect(Settings.kinds.sessionRecap).to.equal("switch")
		expect(Settings.defaults().sessionRecap).to.equal(true)
		local profile: any = ProfileSchema.template(NOW)
		local start = SessionRecap.start(profile, NOW)
		expect(SessionRecap.due(start, NOW + 2399, true)).to.equal(false)
		expect(SessionRecap.due(start, NOW + 2400, true)).to.equal(true)
		expect(SessionRecap.due(start, NOW + 2400, false)).to.equal(false) -- switched off in Settings
		start.sent = true
		expect(SessionRecap.due(start, NOW + 9000, true)).to.equal(false) -- once a session
	end)

	it("counts this session's minutes, new Index cats and coins only", function()
		local profile: any = ProfileSchema.template(NOW)
		addCats(profile, 3)
		profile.lifetimeCoins = 5000
		local start = SessionRecap.start(profile, NOW)
		local before = Economy.distinctCats(profile)
		addCats(profile, 4)
		profile.lifetimeCoins = 17250.6
		local view = SessionRecap.view(start, profile, NOW + 2459)
		expect(view.minutes).to.equal(40)
		expect(view.newCats).to.equal(Economy.distinctCats(profile) - before)
		expect(view.newCats).to.equal(4)
		expect(view.earned).to.equal(12250)
	end)

	it("never reports less than nothing", function()
		local profile: any = ProfileSchema.template(NOW)
		profile.lifetimeCoins = 100
		local start = SessionRecap.start(profile, NOW)
		profile.lifetimeCoins = 50 -- a reset save between the join and the check
		local view = SessionRecap.view(start, profile, NOW - 5)
		expect(view.minutes).to.equal(0)
		expect(view.newCats).to.equal(0)
		expect(view.earned).to.equal(0)
	end)
end
