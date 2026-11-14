--!strict
-- Admin events (#4195): the second lane in the events schedule (shared/CafeEvents `admin = true` records), Bowl
-- Frenzy's bait wait (Bait.eventWait), the adminEvents switch and the owner's /admin command (shared/OwnerTest).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bait = require(Shared.Bait)
	local CafeEvents = require(Shared.CafeEvents)
	local Config = require(Shared.Config)
	local LiveFlags = require(Shared.LiveFlags)
	local OwnerTest = require(Shared.OwnerTest)

	local NOW = 1800000000
	local ADMIN = CafeEvents.ADMIN

	local function party(startsAt: number, endsAt: number): { [string]: any }
		return {
			id = "party-1115",
			title = "Update Party",
			startsAt = startsAt,
			endsAt = endsAt,
			effects = { money = 2 },
		}
	end

	local function frenzy(overrides: { [string]: any }?): { [string]: any }
		local out: { [string]: any } = {
			id = "frenzy-1115",
			title = "Bowl Frenzy",
			admin = true,
			startsAt = NOW + 480,
			endsAt = NOW + 480 + 900,
			effects = { bowlSpeed = 4 },
		}
		for key, value in overrides or {} do
			out[key] = value
		end
		return out
	end

	describe("the admin lane of the schedule", function()
		it("runs an admin record inside a normal event, each in its own list", function()
			local events, notes, admins =
				CafeEvents.parse({ party(NOW, NOW + 1800), frenzy() }, NOW)
			expect(#notes).to.equal(0)
			expect(#events).to.equal(1)
			expect(events[1].id).to.equal("party-1115")
			expect(#admins).to.equal(1)
			local admin = admins[1]
			expect(admin.id).to.equal("frenzy-1115")
			expect(admin.title).to.equal("Bowl Frenzy")
			expect(admin.effects.bowlSpeed).to.equal(4)
			expect(admin.test).to.equal(false)
			-- the party keeps its own effects and is not disturbed
			expect(events[1].effects.money).to.equal(2)
			expect(CafeEvents.current(events, NOW + 600)).to.equal(events[1])
		end)

		it("leaves a schedule with no admin record exactly as it was", function()
			local events, notes, admins = CafeEvents.parse({ party(NOW, NOW + 1800) }, NOW)
			expect(#events).to.equal(1)
			expect(#notes).to.equal(0)
			expect(#admins).to.equal(0)
			local _, _, none = CafeEvents.parse(nil, NOW)
			expect(#none).to.equal(0)
			local _, _, bad = CafeEvents.parse("no", NOW)
			expect(#bad).to.equal(0)
		end)

		it("gives an admin record no money, Luck or days, whatever it says", function()
			local events, _, admins = CafeEvents.parse({
				frenzy({
					effects = { bowlSpeed = 4, money = 2, luck = 0.5, days = { "golden" } },
				}),
			}, NOW)
			expect(#events).to.equal(0)
			expect(#admins).to.equal(1)
			expect((admins[1].effects :: any).money).to.equal(nil)
			expect((admins[1].effects :: any).luck).to.equal(nil)
			expect(CafeEvents.adminEffectsData(admins[1])).to.deepEqual({ bowlSpeed = 4 })
		end)

		it("drops a broken admin record whole, with a note", function()
			local broken: { { [string]: any } } = {
				frenzy({ id = "Bad Id" }),
				frenzy({ title = "" }),
				frenzy({ endsAt = NOW + 480 + ADMIN.minSeconds - 1 }),
				frenzy({ endsAt = NOW + 480 + ADMIN.maxSeconds + 1 }),
				frenzy({ effects = "fast" }),
				frenzy({ effects = {} }),
				frenzy({ effects = { bowlSpeed = 1 } }),
				frenzy({ effects = { bowlSpeed = "4" } }),
				frenzy({ effects = { bowlSpeed = 0 / 0 } }),
				frenzy({ effects = { bowlSpeed = math.huge } }),
				frenzy({ startsAt = "soon" }),
			}
			for _, item in broken do
				local events, notes, admins = CafeEvents.parse({ item }, NOW)
				expect(#events).to.equal(0)
				expect(#admins).to.equal(0)
				expect(#notes).to.equal(1)
			end
			-- one that is over is how every schedule ends up: no note
			local _, notes, admins =
				CafeEvents.parse({ frenzy({ startsAt = NOW - 900, endsAt = NOW }) }, NOW)
			expect(#admins).to.equal(0)
			expect(#notes).to.equal(0)
		end)

		it("clamps bowlSpeed to its cap, with a note", function()
			local _, notes, admins =
				CafeEvents.parse({ frenzy({ effects = { bowlSpeed = 50 } }) }, NOW)
			expect(admins[1].effects.bowlSpeed).to.equal(ADMIN.bowlSpeedMax)
			expect(#notes).to.equal(1)
			_, notes, admins = CafeEvents.parse({ frenzy({ effects = { bowlSpeed = -3 } }) }, NOW)
			expect(#admins).to.equal(0) -- clamped to 1, which does nothing
			expect(#notes).to.equal(2)
		end)

		it("never runs two admin events at once, or the same id twice", function()
			local second = frenzy({ id = "frenzy-b", startsAt = NOW + 900, endsAt = NOW + 1500 })
			local _, notes, admins = CafeEvents.parse({ second, frenzy() }, NOW)
			expect(#admins).to.equal(1)
			expect(admins[1].id).to.equal("frenzy-1115") -- the earlier start stays
			expect(#notes).to.equal(1)
			local after = frenzy({ id = "frenzy-c", startsAt = NOW + 1380, endsAt = NOW + 1680 })
			_, notes, admins = CafeEvents.parse({ frenzy(), after }, NOW)
			expect(#admins).to.equal(2) -- back to back is fine
			expect(#notes).to.equal(0)
			_, notes, admins = CafeEvents.parse({ frenzy(), frenzy() }, NOW)
			expect(#admins).to.equal(1)
			expect(#notes).to.equal(1)
			-- an id shared with a normal event is the same id twice too
			_, notes, admins =
				CafeEvents.parse({ party(NOW, NOW + 1800), frenzy({ id = "party-1115" }) }, NOW)
			expect(#admins).to.equal(0)
			expect(#notes).to.equal(1)
		end)

		it("says which one runs, and shows the next from its warning on", function()
			local _, _, admins = CafeEvents.parse({ frenzy() }, NOW)
			local startsAt, endsAt = NOW + 480, NOW + 480 + 900
			expect(CafeEvents.adminCurrent(admins, NOW)).to.equal(nil)
			expect(CafeEvents.adminShown(admins, startsAt - ADMIN.warnSeconds - 1)).to.equal(nil)
			expect(CafeEvents.adminShown(admins, startsAt - ADMIN.warnSeconds)).to.equal(admins[1])
			expect(CafeEvents.adminCurrent(admins, startsAt - 1)).to.equal(nil)
			expect(CafeEvents.adminCurrent(admins, startsAt)).to.equal(admins[1])
			expect(CafeEvents.adminShown(admins, startsAt)).to.equal(admins[1])
			expect(CafeEvents.adminCurrent(admins, endsAt - 1)).to.equal(admins[1])
			expect(CafeEvents.adminCurrent(admins, endsAt)).to.equal(nil)
			expect(CafeEvents.adminShown(admins, endsAt)).to.equal(nil)
		end)
	end)

	describe("the owner's /admin", function()
		it("reads the kind, the minutes and now", function()
			expect(OwnerTest.isAdminCommand("/admin")).to.equal(true)
			expect(OwnerTest.isAdminCommand("/ADMIN bowl 15")).to.equal(true)
			expect(OwnerTest.isAdminCommand("/administrator")).to.equal(false)
			expect(OwnerTest.isAdminCommand("say /admin bowl")).to.equal(false)
			expect(OwnerTest.isAdminCommand(12)).to.equal(false)
			expect(OwnerTest.isCommand("/admin bowl")).to.equal(true)
			expect(OwnerTest.isEventCommand("/admin bowl")).to.equal(false)
			expect(OwnerTest.adminAsk("/admin bowl 15")).to.deepEqual({
				stop = false,
				kind = "bowl",
				minutes = 15,
				now = false,
			})
			expect(OwnerTest.adminAsk("/Admin Bowl")).to.deepEqual({
				stop = false,
				kind = "bowl",
				now = false,
			})
			expect(OwnerTest.adminAsk("/admin bowl now")).to.deepEqual({
				stop = false,
				kind = "bowl",
				now = true,
			})
			expect(OwnerTest.adminAsk("/admin bowl 5 NOW")).to.deepEqual({
				stop = false,
				kind = "bowl",
				minutes = 5,
				now = true,
			})
			expect(OwnerTest.adminAsk("/admin stop")).to.deepEqual({
				stop = true,
				kind = "stop",
				now = false,
			})
			expect(OwnerTest.adminAsk("/admin").kind).to.equal("")
			-- a kind called "now" is not a skipped warning, and bad minutes fall back to the kind's own
			expect(OwnerTest.adminAsk("/admin now").now).to.equal(false)
			for _, bad in { "0", "-5", "nan", "inf" } do
				expect(OwnerTest.adminAsk("/admin bowl " .. bad).minutes).to.equal(nil)
			end
		end)

		it("writes a record that passes the schedule's own rules, after the warning", function()
			local record = CafeEvents.adminRecord("bowl", NOW + 0.7, nil) :: { [string]: any }
			expect(record.admin).to.equal(true)
			expect(record.title).to.equal("Bowl Frenzy")
			expect(record.startsAt).to.equal(NOW + ADMIN.warnSeconds)
			expect(record.endsAt - record.startsAt).to.equal(15 * 60)
			expect(record.effects.bowlSpeed).to.equal(4)
			expect(string.sub(record.id, 1, #CafeEvents.OWNER_ADMIN_PREFIX)).to.equal(
				CafeEvents.OWNER_ADMIN_PREFIX
			)
			local events, notes, admins = CafeEvents.parse({ record }, NOW)
			expect(#events).to.equal(0)
			expect(#notes).to.equal(0)
			expect(#admins).to.equal(1)
			-- the kind's effects are a copy, so a record can never change the kind
			record.effects.bowlSpeed = 99
			expect(CafeEvents.ADMIN_KINDS.bowl.effects.bowlSpeed).to.equal(4)
		end)

		it("starts at once with now, and keeps the length inside the lane's limits", function()
			local record = CafeEvents.adminRecord("bowl", NOW, 5, true) :: { [string]: any }
			expect(record.startsAt).to.equal(NOW)
			expect(record.endsAt).to.equal(NOW + 300)
			local long = CafeEvents.adminRecord("bowl", NOW, 100000) :: { [string]: any }
			expect(long.endsAt - long.startsAt).to.equal(ADMIN.maxSeconds)
			local short = CafeEvents.adminRecord("bowl", NOW, 0.2) :: { [string]: any }
			expect(short.endsAt - short.startsAt).to.equal(ADMIN.minSeconds)
			expect(CafeEvents.adminRecord("party", NOW, 5)).to.equal(nil)
			expect(CafeEvents.adminRecord("", NOW, 5)).to.equal(nil)
		end)

		it("goes in beside a running Cafe Party, never beside another admin event", function()
			local record = CafeEvents.adminRecord("bowl", NOW, nil) :: { [string]: any }
			local running = party(NOW - 600, NOW + 1200)
			local list, why = CafeEvents.ownerAdd({ running }, record, NOW)
			expect(why).to.equal(nil)
			expect(#(list :: { any })).to.equal(2)
			local again = CafeEvents.adminRecord("bowl", NOW + 30, nil) :: { [string]: any }
			local refused, whyNot = CafeEvents.ownerAdd(list, again, NOW + 30)
			expect(refused).to.equal(nil)
			expect(type(whyNot)).to.equal("string")
			-- a Cafe Party still goes in while an admin event runs
			local partyRecord = CafeEvents.ownerRecord("money", NOW, 10) :: { [string]: any }
			local both, whyParty = CafeEvents.ownerAdd({ record }, partyRecord, NOW)
			expect(whyParty).to.equal(nil)
			expect(#(both :: { any })).to.equal(2)
		end)

		it("stops only its own lane", function()
			local admin = CafeEvents.adminRecord("bowl", NOW, nil) :: { [string]: any }
			local own = CafeEvents.ownerRecord("money", NOW, 10) :: { [string]: any }
			local scheduled =
				frenzy({ id = "frenzy-b", startsAt = NOW + 3000, endsAt = NOW + 3600 })
			local stored = { admin, own, scheduled }
			local list, count = CafeEvents.ownerRemove(stored, NOW, true)
			expect(count).to.equal(1)
			expect(list).to.deepEqual({ own, scheduled })
			list, count = CafeEvents.ownerRemove(stored, NOW, false)
			expect(count).to.equal(1)
			expect(list).to.deepEqual({ admin, scheduled })
			list, count = CafeEvents.ownerRemove(stored, NOW)
			expect(count).to.equal(1)
			expect(list).to.deepEqual({ admin, scheduled })
		end)

		it("runs a test in one server after a short warning", function()
			local event = CafeEvents.adminTest("bowl", NOW, 2) :: CafeEvents.AdminEvent
			expect(event.test).to.equal(true)
			expect(event.startsAt).to.equal(NOW + ADMIN.testWarnSeconds)
			expect(event.endsAt - event.startsAt).to.equal(120)
			expect(event.effects.bowlSpeed).to.equal(4)
			expect(CafeEvents.adminShown({ event }, NOW)).to.equal(event)
			expect(CafeEvents.adminCurrent({ event }, NOW)).to.equal(nil)
			local atOnce = CafeEvents.adminTest("bowl", NOW, 2, true) :: CafeEvents.AdminEvent
			expect(CafeEvents.adminCurrent({ atOnce }, NOW)).to.equal(atOnce)
			expect(CafeEvents.adminTest("party", NOW, 2)).to.equal(nil)
		end)
	end)

	describe("Bowl Frenzy's bait wait", function()
		it("divides the wait, in whole seconds", function()
			expect(Bait.eventWait(600, 4)).to.equal(150)
			expect(Bait.eventWait(372, 4)).to.equal(93)
			expect(Bait.eventWait(150, 4)).to.equal(37)
			expect(Bait.eventWait(600, 1.5)).to.equal(400)
		end)

		it("changes nothing without an event, or for a speed that is not one", function()
			for _, speed in { 1, 0, -4, 0.5, 0 / 0 } do
				expect(Bait.eventWait(600, speed)).to.equal(600)
			end
		end)

		it("never goes under the shortest wait there is, and never lengthens one", function()
			local least = Config.FirstBaitWaitSeconds
			expect(Bait.eventWait(least * 2, 4)).to.equal(least)
			expect(Bait.eventWait(least, 4)).to.equal(least)
			expect(Bait.eventWait(least - 2, 4)).to.equal(least - 2)
			for wait = 1, 700, 7 do
				local out = Bait.eventWait(wait, ADMIN.bowlSpeedMax)
				expect(out <= wait).to.equal(true)
				expect(out >= math.min(wait, least)).to.equal(true)
			end
			-- the account's first bait keeps its own short wait
			expect(Bait.firstWait(Bait.eventWait(600, 4), 0)).to.equal(least)
		end)
	end)

	describe("the Admin Wheel's admin effect", function()
		local function wheel(overrides: { [string]: any }?): { [string]: any }
			local out =
				frenzy({ id = "wheel-1115", title = "Admin Wheel", effects = { wheel = true } })
			for key, value in overrides or {} do
				out[key] = value
			end
			return out
		end

		it("is an admin kind the owner's /admin starts with no parser change", function()
			local kind = CafeEvents.ADMIN_KINDS.wheel
			expect(kind.title).to.equal("Admin Wheel")
			expect(kind.effects).to.deepEqual({ wheel = true })
			local ask = OwnerTest.adminAsk("/admin wheel now")
			expect(ask.kind).to.equal("wheel")
			local record = CafeEvents.adminRecord("wheel", NOW, nil, true) :: { [string]: any }
			expect(record.effects).to.deepEqual({ wheel = true })
			expect(record.endsAt - record.startsAt).to.equal(kind.minutes * 60)
			local events, notes, admins = CafeEvents.parse({ record }, NOW)
			expect(#events).to.equal(0)
			expect(#notes).to.equal(0)
			expect(admins[1].effects.wheel).to.equal(true)
			expect(admins[1].effects.bowlSpeed).to.equal(1)
			expect(CafeEvents.adminCurrent(admins, NOW)).to.equal(admins[1])
		end)

		it("is read from a schedule record, alone or with Bowl Frenzy's speed", function()
			local _, notes, admins = CafeEvents.parse({ wheel() }, NOW)
			expect(#notes).to.equal(0)
			expect(admins[1].effects).to.deepEqual({ bowlSpeed = 1, catStorm = 1, wheel = true })
			expect(CafeEvents.adminEffectsData(admins[1])).to.deepEqual({ wheel = true })
			_, notes, admins =
				CafeEvents.parse({ wheel({ effects = { wheel = true, bowlSpeed = 4 } }) }, NOW)
			expect(#notes).to.equal(0)
			expect(CafeEvents.adminEffectsData(admins[1])).to.deepEqual({
				bowlSpeed = 4,
				wheel = true,
			})
			-- Bowl Frenzy has no wheel
			_, _, admins = CafeEvents.parse({ frenzy() }, NOW)
			expect(admins[1].effects.wheel).to.equal(false)
		end)

		it("drops a record whose wheel is no boolean, or is off with nothing else", function()
			for _, effects in { { wheel = "yes" }, { wheel = 1 }, { wheel = false } } do
				local _, notes, admins = CafeEvents.parse({ wheel({ effects = effects }) }, NOW)
				expect(#admins).to.equal(0)
				expect(#notes).to.equal(1)
			end
		end)

		it("runs as a test in one server", function()
			local event = CafeEvents.adminTest("wheel", NOW, nil, true) :: CafeEvents.AdminEvent
			expect(event.test).to.equal(true)
			expect(event.effects).to.deepEqual({ bowlSpeed = 1, catStorm = 1, wheel = true })
			local bowl = CafeEvents.adminTest("bowl", NOW, 2, true) :: CafeEvents.AdminEvent
			expect(bowl.effects.wheel).to.equal(false)
		end)
	end)

	describe("Cat Storm's record", function()
		it("carries catStorm, clamped to its cap, and drops a bad one", function()
			local storm =
				frenzy({ id = "storm-1115", title = "Cat Storm", effects = { catStorm = 10 } })
			local events, notes, admins = CafeEvents.parse({ storm }, NOW)
			expect(#events).to.equal(0)
			expect(#notes).to.equal(0)
			expect(admins[1].effects.catStorm).to.equal(10)
			expect(admins[1].effects.bowlSpeed).to.equal(1)
			expect(CafeEvents.adminEffectsData(admins[1])).to.deepEqual({ catStorm = 10 })
			events, notes, admins =
				CafeEvents.parse({ frenzy({ effects = { catStorm = 500 } }) }, NOW)
			expect(admins[1].effects.catStorm).to.equal(ADMIN.catStormMax)
			expect(#notes).to.equal(1)
			for _, bad in { "10", 0 / 0, math.huge, {} } do
				events, notes, admins =
					CafeEvents.parse({ frenzy({ effects = { catStorm = bad } }) }, NOW)
				expect(#admins).to.equal(0)
				expect(#notes).to.equal(1)
			end
			-- a frenzy has no storm in it
			events, notes, admins = CafeEvents.parse({ frenzy() }, NOW)
			expect(admins[1].effects.catStorm).to.equal(1)
			expect(CafeEvents.adminEffectsData(admins[1])).to.deepEqual({ bowlSpeed = 4 })
		end)

		it("is the owner's /admin storm: ten minutes, ten times", function()
			local record = CafeEvents.adminRecord("storm", NOW, nil) :: { [string]: any }
			expect(record.title).to.equal("Cat Storm")
			expect(record.endsAt - record.startsAt).to.equal(600)
			expect(record.effects).to.deepEqual({ catStorm = 10 })
			local _, notes, admins = CafeEvents.parse({ record }, NOW)
			expect(#notes).to.equal(0)
			expect(admins[1].effects.catStorm).to.equal(10)
			local test = CafeEvents.adminTest("storm", NOW, 2) :: CafeEvents.AdminEvent
			expect(test.effects.catStorm).to.equal(10)
			expect(test.effects.bowlSpeed).to.equal(1)
			expect(OwnerTest.adminAsk("/admin storm 10 now")).to.deepEqual({
				stop = false,
				kind = "storm",
				minutes = 10,
				now = true,
			})
		end)
	end)

	describe("the adminEvents switch", function()
		it("is off until the store holds an explicit true", function()
			expect(ADMIN.flag).to.equal("adminEvents")
			expect(table.find(LiveFlags.KEYS, ADMIN.flag) ~= nil).to.equal(true)
			expect(LiveFlags.defaults()[ADMIN.flag]).to.equal(false)
			expect(LiveFlags.parse({})[ADMIN.flag]).to.equal(false)
			expect(LiveFlags.parse({ adminEvents = "yes" })[ADMIN.flag]).to.equal(false)
			expect(LiveFlags.parse({ adminEvents = true })[ADMIN.flag]).to.equal(true)
		end)
	end)
end
