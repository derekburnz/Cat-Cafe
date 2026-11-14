--!strict
-- Effects/AdminFlash's pure half (#4325, AdminFlashLogic with Presets.adminFlash): which reward an event shouts and
-- why to stay, the 3, 2, 1 before the start, the splash and the strip after it, the last minute under the flashing
-- limit, the earned sum that never falls, and that every kind has a look and a drift.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local AdminEventLogic = require(Effects:WaitForChild("AdminEventLogic")) :: any
	local Flash = require(Effects:WaitForChild("AdminFlashLogic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local p = Presets.adminFlash

	local NOW = 1800000000

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	local function view(effects: { [string]: any }, running: boolean?, seconds: number?): any
		local values: { [string]: any } = {
			AdminEventId = "owner-admin-7",
			AdminEventTitle = "Money Storm",
			AdminEventStartsAt = NOW,
			AdminEventEndsAt = NOW + (seconds or 600),
			AdminEventEffects = "json",
			AdminEventRunning = running ~= false,
		}
		return AdminEventLogic.read(function(name: string): any
			return values[name]
		end, function(_json: string): any
			return effects
		end)
	end

	describe("Effects admin flash", function()
		it("shouts the reward in a few big characters", function()
			expect(Flash.headline(view({ moneyStorm = 4 }))).to.equal("x4 MONEY")
			expect(Flash.headline(view({ moneyStorm = 2 }))).to.equal("x2 MONEY")
			expect(Flash.headline(view({ bowlSpeed = 4 }))).to.equal("x4 BOWL SPEED")
			expect(Flash.headline(view({ catStorm = 10 }))).to.equal("x10 MYTHICAL LUCK")
			expect(Flash.headline(view({ goldBoost = 1.5 }))).to.equal("x1.5 GOLD LUCK")
			expect(Flash.headline(view({ secretHunt = 3 }))).to.equal("3 SECRET CATS")
			expect(Flash.headline(view({ traitParty = true }))).to.equal("FREE TRAIT ROLLS")
			expect(Flash.headline(view({}))).to.equal("MONEY STORM") -- nothing it knows: the title
		end)

		it("picks the first effect in its own order when an event has several", function()
			local both = view({ goldBoost = 10, moneyStorm = 2 })
			expect(Flash.headline(both)).to.equal("x2 MONEY")
			expect(Flash.lookOf(both)).to.equal("gold")
			expect(Flash.rainOf(both)).to.equal("moneyStorm")
		end)

		it("says why to stay and for how long", function()
			expect(Flash.stay(view({ moneyStorm = 4 }))).to.equal("Stay and cash in!")
			expect(Flash.stay(view({}))).to.equal(Flash.DEFAULT_STAY)
			expect(Flash.lasting(view({}, true, 600))).to.equal("for 10 minutes")
			expect(Flash.lasting(view({}, true, 60))).to.equal("for 1 minute")
			expect(Flash.lasting(view({}, true, 90))).to.equal("for 90 seconds")
			expect(Flash.lasting(view({}, true, 180))).to.equal("for 3 minutes")
		end)

		it("has a look, a drift and an emitter for every kind", function()
			for _, row in Flash.KINDS do
				expect(p.looks[row.look]).to.be.ok()
				local preset = Presets.adminAir.kinds[row.rain]
				expect(preset).to.be.ok()
				expect(Presets.emitters[preset]).to.be.ok()
			end
			expect(p.looks[Flash.DEFAULT_LOOK]).to.be.ok()
			expect(Flash.lookOf(nil)).never.to.be.ok()
			expect(Flash.rainOf(nil)).never.to.be.ok()
			expect(Flash.rainOf(view({}))).never.to.be.ok()
			expect(Flash.lookOf(view({}))).to.equal(Flash.DEFAULT_LOOK)
		end)

		it("counts 3, 2, 1 only in the last seconds before the start", function()
			local soon = view({ moneyStorm = 4 }, false)
			expect(Flash.step(soon, NOW - 60, nil, p).phase).to.equal("none")
			expect(Flash.step(soon, NOW - p.countFrom - 0.1, nil, p).phase).to.equal("none")
			local three = Flash.step(soon, NOW - 2.5, nil, p)
			expect(three.phase).to.equal("count")
			expect(three.count).to.equal(3)
			expect(Flash.step(soon, NOW - 1.5, nil, p).count).to.equal(2)
			expect(Flash.step(soon, NOW - 0.2, nil, p).count).to.equal(1)
			expect(Flash.step(soon, NOW + 0.5, nil, p).phase).to.equal("none") -- the server has not started it yet
			expect(Flash.step(nil, NOW, nil, p).phase).to.equal("none")
		end)

		it("splashes at the start, then shows the strip", function()
			local on = view({ moneyStorm = 4 })
			local first = Flash.step(on, NOW + 0.1, NOW, p)
			expect(first.phase).to.equal("splash")
			expect(first.strip).to.equal(false)
			local later = Flash.step(on, NOW + p.stripAfter + 0.1, NOW, p)
			expect(later.phase).to.equal("run")
			expect(later.strip).to.equal(true)
			expect(later.last).to.equal(false)
			expect(near(later.left, 600 - p.stripAfter - 0.1)).to.equal(true)
			expect(p.splashSeconds <= p.stripAfter).to.equal(true)
			expect(Flash.step(on, NOW + 600, NOW, p).phase).to.equal("none")
		end)

		it("gives a late joiner the splash from when they first see it", function()
			local on = view({ moneyStorm = 4 })
			local joined = NOW + 200
			expect(Flash.step(on, joined + 1, joined, p).phase).to.equal("splash")
			expect(Flash.step(on, joined + 1, joined, p).strip).to.equal(false)
			expect(Flash.step(on, joined + p.stripAfter + 1, joined, p).strip).to.equal(true)
		end)

		it("leaves the middle of the screen alone while a window is open", function()
			local soon = view({ moneyStorm = 4 }, false)
			expect(Flash.step(soon, NOW - 2.5, nil, p, true).phase).to.equal("none")
			local on = view({ moneyStorm = 4 })
			local first = Flash.step(on, NOW + 0.1, NOW, p, true)
			expect(first.phase).to.equal("run")
			expect(first.strip).to.equal(true) -- the strip carries the start
			expect(Flash.step(on, NOW + 0.1, NOW, p, false).phase).to.equal("splash")
			expect(p.displayOrder < 20).to.equal(true) -- and what does draw sits under every window
			expect(p.stripOrder < 20).to.equal(true)
		end)

		it("says LUCK for a boosted chance, never more cats", function()
			for _, row in Flash.KINDS do
				expect(string.find(row.head, "%s CATS", 1, true) == nil or row.name == "secretHunt").to.equal(
					true
				)
			end
		end)

		it("marks the last minute, but not on a short event", function()
			local on = view({ moneyStorm = 4 })
			expect(Flash.step(on, NOW + 600 - p.lastSeconds - 1, NOW, p).last).to.equal(false)
			expect(Flash.step(on, NOW + 600 - p.lastSeconds + 1, NOW, p).last).to.equal(true)
			local short = view({ moneyStorm = 4 }, true, p.lastMinEvent - 60)
			expect(Flash.step(short, NOW + p.lastMinEvent - 70, NOW, p).last).to.equal(false)
		end)

		it("swells slower than 3 times a second and only a little", function()
			expect(p.pulseHz < 3).to.equal(true)
			expect(p.pulse <= 0.15).to.equal(true)
			expect(near(Flash.pulse(0, p.pulseHz, p.pulse), 1)).to.equal(true)
			expect(near(Flash.pulse(0.5 / p.pulseHz, p.pulseHz, p.pulse), 1 + p.pulse)).to.equal(
				true
			)
		end)

		it("adds up what came in and never takes spending away", function()
			local total = Flash.earned(0, 1000, 1500)
			expect(total).to.equal(500)
			total = Flash.earned(total, 1500, 300) -- bought something
			expect(total).to.equal(500)
			total = Flash.earned(total, 300, 340)
			expect(total).to.equal(540)
			expect(Flash.earned(total, nil, 9000)).to.equal(540) -- the first reading only sets the base
		end)

		it("writes money with commas", function()
			expect(Flash.money(0, "$")).to.equal("+$0")
			expect(Flash.money(999, "$")).to.equal("+$999")
			expect(Flash.money(12340.7, "$")).to.equal("+$12,340")
			expect(Flash.money(1234567, "$")).to.equal("+$1,234,567")
		end)
	end)
end
