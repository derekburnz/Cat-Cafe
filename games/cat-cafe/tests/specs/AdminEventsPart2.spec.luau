--!strict
-- Admin events part 2 (#4197): Golden Hour (goldBoost, rainbowBoost), Money Storm (moneyStorm), Trait Party
-- (traitParty), Speed Rush (speedRush) and Secret Hunt (secretHunt) in the admin lane (shared/CafeEvents), and what each one changes: the coat
-- chances (Clock.setAdminCoats), the cafe pay floor (Economy.setAdminMoney, Economy.moneyFor) and the lent shoes
-- (SpeedShoes.carry).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CafeEvents = require(Shared.CafeEvents)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local OwnerTest = require(Shared.OwnerTest)
	local SpeedShoes = require(Shared.SpeedShoes)

	local NOW = 1800000000
	local ADMIN = CafeEvents.ADMIN

	local function record(effects: { [string]: any }): { [string]: any }
		return {
			id = "admin-1115",
			title = "Golden Hour",
			admin = true,
			startsAt = NOW + 60,
			endsAt = NOW + 60 + 900,
			effects = effects,
		}
	end

	local function parseOne(effects: { [string]: any }): (CafeEvents.AdminEvent?, { string })
		local _, notes, admins = CafeEvents.parse({ record(effects) }, NOW)
		return admins[1], notes
	end

	afterEach(function()
		Clock.setAdminCoats(1, 1, 1)
		Economy.setAdminMoney(1, ADMIN.moneyStormMax)
	end)

	describe("the part 2 admin kinds", function()
		it("are the owner's /admin golden, money, traits and speed", function()
			local expected: { [string]: { title: string, data: { [string]: number } } } = {
				golden = { title = "Golden Hour", data = { goldBoost = 10, rainbowBoost = 5 } },
				money = { title = "Money Storm", data = { moneyStorm = 4 } }, -- Derek 22:09 UTC: 4x, 5 minutes
				traits = { title = "Trait Party", data = { traitParty = 1 } },
				speed = { title = "Speed Rush", data = { speedRush = 1 } },
				hunt = { title = "Secret Hunt", data = { secretHunt = 3 } },
				fountain = { title = "Fish Fountain", data = { fishFountain = 1 } },
				crates = { title = "Crate Drop", data = { crateDrop = 1 } },
			}
			for kind, want in expected do
				expect(OwnerTest.adminAsk("/admin " .. kind .. " now").kind).to.equal(kind)
				local made = CafeEvents.adminRecord(kind, NOW, nil, true) :: { [string]: any }
				expect(made.title).to.equal(want.title)
				local _, notes, admins = CafeEvents.parse({ made }, NOW)
				expect(#notes).to.equal(0)
				expect(#admins).to.equal(1)
				expect(CafeEvents.adminEffectsData(admins[1])).to.deepEqual(want.data)
				local test = CafeEvents.adminTest(kind, NOW, 2, true) :: CafeEvents.AdminEvent
				expect(CafeEvents.adminEffectsData(test)).to.deepEqual(want.data)
			end
		end)

		it("runs a Trait Party 3 minutes at most (Derek 2026-11-16)", function()
			expect(CafeEvents.TRAIT_PARTY_MAX_SECONDS).to.equal(180)
			local made = CafeEvents.adminRecord("traits", NOW, nil, true) :: { [string]: any }
			expect(made.endsAt - made.startsAt).to.equal(180)
			local asked = CafeEvents.adminRecord("traits", NOW, 15, true) :: { [string]: any }
			expect(asked.endsAt - asked.startsAt).to.equal(180)
			local test = CafeEvents.adminTest("traits", NOW, 15, true) :: CafeEvents.AdminEvent
			expect(test.endsAt - test.startsAt).to.equal(180)
			-- a 15 minute record written by hand (the events workflow) is cut to 3 minutes as it is read
			local event = parseOne({ traitParty = true })
			assert(event ~= nil)
			expect(event.endsAt - event.startsAt).to.equal(180)
			-- other kinds keep their length
			local storm = CafeEvents.adminRecord("storm", NOW, 15, true) :: { [string]: any }
			expect(storm.endsAt - storm.startsAt).to.equal(900)
		end)

		it("runs a Secret Hunt 3 minutes at most (#4871)", function()
			expect(CafeEvents.SECRET_HUNT_MAX_SECONDS).to.equal(180)
			local made = CafeEvents.adminRecord("hunt", NOW, nil, true) :: { [string]: any }
			expect(made.endsAt - made.startsAt).to.equal(180)
			local asked = CafeEvents.adminRecord("hunt", NOW, 15, true) :: { [string]: any }
			expect(asked.endsAt - asked.startsAt).to.equal(180)
			local event = parseOne({ secretHunt = 3 })
			assert(event ~= nil)
			expect(event.endsAt - event.startsAt).to.equal(180)
			local golden = CafeEvents.adminRecord("golden", NOW, nil, true) :: { [string]: any }
			expect(golden.endsAt - golden.startsAt).to.equal(900)
		end)

		it("clamps each multiplier to its cap and drops a bad one", function()
			local event, notes = parseOne({ goldBoost = 99, rainbowBoost = 99, moneyStorm = 99 })
			assert(event ~= nil)
			expect(event.effects.goldBoost).to.equal(ADMIN.goldBoostMax)
			expect(event.effects.rainbowBoost).to.equal(ADMIN.rainbowBoostMax)
			expect(event.effects.moneyStorm).to.equal(ADMIN.moneyStormMax)
			expect(#notes).to.equal(3)
			for _, bad in { "5", 0 / 0, math.huge, {} } do
				local none = parseOne({ moneyStorm = bad })
				expect(none).to.equal(nil)
			end
			-- a multiplier of 1 or less does nothing, so a record with only that has no admin effect
			expect(parseOne({ moneyStorm = 1 })).to.equal(nil)
			expect(parseOne({ goldBoost = 0.5 })).to.equal(nil)
		end)

		it("reads traitParty and speedRush as true or a number above 0", function()
			for _, on in { true, 1, 3 } do
				local event = parseOne({ traitParty = on, speedRush = on })
				assert(event ~= nil)
				expect(event.effects.traitParty).to.equal(true)
				expect(event.effects.speedRush).to.equal(true)
				expect(CafeEvents.adminEffectsData(event)).to.deepEqual({
					traitParty = 1,
					speedRush = 1,
				})
			end
			for _, off in { false, 0, -1 } do
				expect(parseOne({ traitParty = off })).to.equal(nil)
			end
			expect(parseOne({ speedRush = "yes" })).to.equal(nil)
			expect(parseOne({ speedRush = 0 / 0 })).to.equal(nil)
		end)

		it("leaves Bowl Frenzy, Cat Storm and the wheel as they were", function()
			local event = parseOne({ bowlSpeed = 4, catStorm = 10, wheel = true })
			assert(event ~= nil)
			expect(CafeEvents.adminEffectsData(event)).to.deepEqual({
				bowlSpeed = 4,
				catStorm = 10,
				wheel = true,
			})
			expect(event.effects.goldBoost).to.equal(1)
			expect(event.effects.moneyStorm).to.equal(1)
			expect(event.effects.traitParty).to.equal(false)
			expect(event.effects.speedRush).to.equal(false)
			expect(event.effects.secretHunt).to.equal(0)
			expect(event.effects.fishFountain).to.equal(false)
			expect(event.effects.crateDrop).to.equal(false)
		end)

		it("reads fishFountain and crateDrop as switches", function()
			local event = parseOne({ fishFountain = true, crateDrop = 2 })
			assert(event ~= nil)
			expect(CafeEvents.adminEffectsData(event)).to.deepEqual({
				fishFountain = 1,
				crateDrop = 1,
			})
			expect(parseOne({ fishFountain = false })).to.equal(nil)
			expect(parseOne({ crateDrop = "on" })).to.equal(nil)
		end)

		it("reads secretHunt as whole cats up to its cap", function()
			local event, notes = parseOne({ secretHunt = 9 })
			assert(event ~= nil)
			expect(event.effects.secretHunt).to.equal(ADMIN.secretHuntMax)
			expect(#notes).to.equal(1)
			local three = parseOne({ secretHunt = 3.7 })
			assert(three ~= nil)
			expect(CafeEvents.adminEffectsData(three)).to.deepEqual({ secretHunt = 3 })
			expect(parseOne({ secretHunt = 0 })).to.equal(nil)
			expect(parseOne({ secretHunt = -2 })).to.equal(nil)
			expect(parseOne({ secretHunt = "3" })).to.equal(nil)
			expect(parseOne({ secretHunt = 0 / 0 })).to.equal(nil)
		end)
	end)

	describe("Golden Hour's coat chances", function()
		it("multiplies every gold and rainbow chance, day or night, under the cap", function()
			expect(Clock.goldChance(0.05, nil)).to.equal(0.05)
			Clock.setAdminCoats(10, 5, ADMIN.coatChanceMax)
			expect(Clock.goldChance(0.02, nil)).to.be.near(0.2)
			expect(Clock.rainbowChance(0.015, nil)).to.be.near(0.075)
			-- with a Golden Day on top, still at most the cap
			local golden = { lucky = false, golden = true, rainbow = false }
			expect(Clock.goldChance(0.05, golden)).to.equal(ADMIN.coatChanceMax)
			-- a chance already over the cap is never lowered
			expect(Clock.goldChance(0.6, nil)).to.equal(0.6)
		end)

		it("goes back to the day's own chances when it ends, and ignores bad factors", function()
			Clock.setAdminCoats(10, 5, ADMIN.coatChanceMax)
			Clock.setAdminCoats(1, 1, ADMIN.coatChanceMax)
			expect(Clock.goldChance(0.05, nil)).to.equal(0.05)
			Clock.setAdminCoats(0 / 0, -3, ADMIN.coatChanceMax)
			expect(Clock.goldChance(0.05, nil)).to.equal(0.05)
			expect(Clock.rainbowChance(0.015, nil)).to.equal(0.015)
			local rainbow = { lucky = false, golden = false, rainbow = true }
			expect(Clock.rainbowChance(0.015, rainbow)).to.be.near(
				0.015 * Config.RainbowDayMultiplier
			)
		end)
	end)

	describe("Money Storm's cafe pay", function()
		it(
			"lifts every player's pay to its multiplier, never on top of the event slot or the rest",
			function()
				local profile = {} :: any
				expect(Economy.moneyFor(profile)).to.equal(1)
				Economy.setAdminMoney(5, ADMIN.moneyStormMax)
				expect(Economy.moneyFor(profile)).to.equal(5)
				Economy.setEventMoney(Config.EventMoneyMax)
				expect(Economy.moneyFor(profile)).to.equal(5) -- the larger, not 5 x 2
				Economy.setAdminMoney(1, ADMIN.moneyStormMax)
				expect(Economy.moneyFor(profile)).to.equal(Config.EventMoneyMax)
				Economy.setEventMoney(1)
			end
		)

		it("stays inside its cap and ignores a bad value", function()
			Economy.setAdminMoney(50, ADMIN.moneyStormMax)
			expect(Economy.adminMoney()).to.equal(ADMIN.moneyStormMax)
			Economy.setAdminMoney(0 / 0, ADMIN.moneyStormMax)
			expect(Economy.adminMoney()).to.equal(1)
			Economy.setAdminMoney(0.2, ADMIN.moneyStormMax)
			expect(Economy.adminMoney()).to.equal(1)
		end)
	end)

	describe("Speed Rush's lent shoes", function()
		it("gives the shoes' carry bonus to a player without them, switch or not", function()
			local carry, walk = Config.CarryWalkSpeed, Config.NormalWalkSpeed
			local none = { mystery = {} } :: any
			expect(SpeedShoes.carry(carry, walk, none, true)).to.equal(carry)
			expect(SpeedShoes.carry(carry, walk, none, false, true)).to.equal(
				SpeedShoes.carry(carry, walk, { mystery = { [SpeedShoes.ID] = true } } :: any, true)
			)
			expect(SpeedShoes.carry(carry, walk, nil, false, true) > carry).to.equal(true)
			-- still one short of the player's own walk speed with no cat
			expect(SpeedShoes.carry(carry, walk, nil, false, true) <= walk - 1).to.equal(true)
		end)
	end)
end
