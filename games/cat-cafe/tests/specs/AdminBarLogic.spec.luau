--!strict
-- UI/Components/AdminBarLogic.luau: the admin event's banner, timer and Admin Wheel window words (#4195).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("AdminBarLogic")
	) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AdminWheel = require(Shared:WaitForChild("AdminWheel")) :: any
	local CafeEvents = require(Shared:WaitForChild("CafeEvents")) :: any

	local NAMES = CafeEvents.ADMIN_ATTRIBUTES
	local function reader(values: { [string]: any }): (string) -> unknown
		return function(name: string): unknown
			return values[name]
		end
	end
	-- (the test runner has no HttpService: the JSON the server writes, as tables)
	local JSON: { [string]: any } = {
		['{"wheel":true}'] = { wheel = true },
		['{"bowlSpeed":4}'] = { bowlSpeed = 4 },
		['{"hunt":3,"found":1}'] = { hunt = 3, found = 1 },
		['{"hunt":3,"found":9}'] = { hunt = 3, found = 9 },
		['{"money":5,"line":"Rain of coins"}'] = { money = 5, line = "Rain of coins" },
	}
	local function decode(raw: string): unknown
		local known = JSON[raw]
		if known == nil then
			error("bad JSON")
		end
		return known
	end
	local function info(effects: string, running: boolean?): any
		return Logic.info(
			reader({
				[NAMES.id] = "wheel-1",
				[NAMES.title] = "Admin Wheel",
				[NAMES.startsAt] = 1000,
				[NAMES.endsAt] = 1300,
				[NAMES.effects] = effects,
				[NAMES.running] = running == true,
			}),
			NAMES,
			decode
		)
	end

	describe("AdminBarLogic", function()
		it("reads nothing when no admin event is named or its times are bad", function()
			expect(Logic.info(reader({ [NAMES.id] = "" }), NAMES, decode)).to.equal(nil)
			expect(Logic.info(reader({}), NAMES, decode)).to.equal(nil)
			expect(Logic.info(
				reader({
					[NAMES.id] = "x",
					[NAMES.startsAt] = 10,
					[NAMES.endsAt] = 5,
				}),
				NAMES,
				decode
			)).to.equal(nil)
		end)

		it("reads the wheel and the bowl speed from the effects, and survives bad JSON", function()
			local wheel = info('{"wheel":true}')
			expect(wheel.wheel).to.equal(true)
			expect(wheel.bowlSpeed).to.equal(nil)
			local frenzy = info('{"bowlSpeed":4}')
			expect(frenzy.wheel).to.equal(false)
			expect(frenzy.bowlSpeed).to.equal(4)
			expect(info("{not json").wheel).to.equal(false)
		end)

		it("counts down the 2 minute warning, then the time left", function()
			local wheel = info('{"wheel":true}')
			local soon = Logic.view(wheel, 880, nil)
			expect(soon.phase).to.equal("soon")
			expect(soon.big).to.equal("ADMIN EVENT IN 2:00")
			expect(soon.pill).to.equal("Admin Wheel in")
			expect(soon.time).to.equal("2:00")
			expect(soon.spin).to.equal(false)
			expect(Logic.view(wheel, 990.5, nil).time).to.equal("0:10")
			local live =
				Logic.view(wheel, 1048, { eventId = "wheel-1", spun = false, endsAt = 1300 })
			expect(live.phase).to.equal("live")
			expect(live.big).to.equal("ADMIN WHEEL NOW!")
			expect(live.time).to.equal("4:12 left")
			expect(live.spin).to.equal(true)
			expect(live.key).never.to.equal(soon.key) -- the banner comes up again at the start
			expect(Logic.view(wheel, 1300, nil)).to.equal(nil)
		end)

		it("offers Spin only while this account has not spun this event's wheel", function()
			local wheel = info('{"wheel":true}', true)
			expect(
				Logic.view(wheel, 1100, { eventId = "wheel-1", spun = true, endsAt = 1300 }).spin
			).to.equal(false)
			expect(Logic.view(wheel, 1100, { eventId = "other", spun = false, endsAt = 1300 }).spin).to.equal(
				false
			)
			expect(Logic.view(wheel, 1100, nil).spin).to.equal(false)
			local frenzy = info('{"bowlSpeed":4}', true)
			expect(
				Logic.view(frenzy, 1100, { eventId = "wheel-1", spun = false, endsAt = 1300 }).spin
			).to.equal(false)
			expect(Logic.view(frenzy, 900, nil).sub).to.equal("Bait bowls bring cats 4x faster")
		end)

		it("says free, nothing to buy, on the window's line, and what was won", function()
			local open =
				Logic.wheelView({ eventId = "w", spun = false, endsAt = 1300 }, 1048, false, nil)
			expect(open.enabled).to.equal(true)
			expect(open.line:find("Nothing to buy", 1, true)).to.be.ok()
			expect(open.line:find("Robux", 1, true)).to.equal(nil)
			expect(
				Logic.wheelView({ eventId = "w", spun = false, endsAt = 1300 }, 1048, true, nil).enabled
			).to.equal(false)
			expect(
				Logic.wheelView({ eventId = "w", spun = true, endsAt = 1300 }, 1048, false, nil).enabled
			).to.equal(false)
			expect(Logic.wheelView(nil, 1048, false, nil).enabled).to.equal(false)
			local won = Logic.wheelView(
				{ eventId = "w", spun = true, endsAt = 1300 },
				1048,
				false,
				"+200 golden fish"
			)
			expect(won.line).to.equal("You won +200 golden fish!")
		end)

		it(
			"words every part 2 event from its effects, with the server's own line first (#4197)",
			function()
				expect(Logic.line({ golden = 10, rainbow = 5 })).to.equal(
					"Gold coats 10x, rainbow 5x on every catch"
				)
				expect(Logic.line({ golden = 10 })).to.equal("Gold coats 10x on every catch")
				expect(Logic.line({ catStorm = 10 })).to.equal(
					"Strays rain in every area, Mythical 10x"
				)
				expect(Logic.line({ money = 5 })).to.equal("5x cafe money for everyone")
				expect(Logic.line({ traitFree = true })).to.equal(
					"Trait rolls are free, with extra rarity luck"
				)
				expect(Logic.line({ hunt = 3 })).to.equal(
					"Find the 3 hidden Secret cats and keep them"
				)
				expect(Logic.line({ hunt = 1 })).to.equal("Find the hidden Secret cat and keep it")
				expect(Logic.line({ fountain = true })).to.equal(
					"The Town Square fountain sprays golden fish"
				)
				expect(Logic.line({ crates = true })).to.equal("Golden crates drop into every area")
				expect(Logic.line({ speed = true })).to.equal(
					"Speed Shoes for all, cannons fly 2x as far"
				)
				expect(Logic.line({ money = 1 })).to.equal(nil) -- no multiplier, no line
				expect(Logic.line({ money = 5, line = "Rain of coins" })).to.equal("Rain of coins")
				expect(Logic.line({ money = 5, line = string.rep("x", Logic.LINE_MAX + 1) })).to.equal(
					"5x cafe money for everyone"
				)
				expect(Logic.line({})).to.equal(nil)
				for _, data in
					{
						{ wheel = true },
						{ bowlSpeed = 4 },
						{ catStorm = 10 },
						{ golden = 10, rainbow = 5 },
						{ money = 5 },
						{ traitFree = true },
						{ hunt = 3 },
						{ fountain = true },
						{ crates = true },
						{ speed = true },
					}
				do
					expect(#(Logic.line(data) :: string) <= Logic.LINE_MAX).to.equal(true)
				end
			end
		)

		it(
			"puts the server's line on the banner and a Secret Hunt's count on the timer (#4197)",
			function()
				local storm = info('{"money":5,"line":"Rain of coins"}')
				expect(Logic.view(storm, 900, nil).sub).to.equal("Rain of coins")
				local hunt = info('{"hunt":3,"found":1}', true)
				expect(hunt.total).to.equal(3)
				expect(hunt.found).to.equal(1)
				local live = Logic.view(hunt, 1100, nil)
				expect(live.pill).to.equal("Admin Wheel 1/3")
				expect(live.sub).to.equal("Find the 3 hidden Secret cats and keep them")
				expect(Logic.view(hunt, 900, nil).pill).to.equal("Admin Wheel in") -- no count before it starts
				expect(info('{"hunt":3,"found":9}').found).to.equal(3)
				expect(Logic.view(info("{not json"), 900, nil).sub).to.equal("Admin Wheel")
			end
		)

		it("has one slice look for each wheel prize", function()
			expect(#Logic.SLICES).to.equal(#AdminWheel.PRIZES)
			local sum = 0
			for _, prize in AdminWheel.PRIZES do
				sum += prize.weight
			end
			expect(sum).to.equal(100)
		end)
	end)
end
