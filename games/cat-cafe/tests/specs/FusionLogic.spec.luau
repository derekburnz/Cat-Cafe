--!strict
-- UI/Components/FusionLogic.luau: what the Fusion Observatory window shows (#4104).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FusionLogic")
	) :: any

	local function cat(catId: string, level: number, extra: { [string]: any }?)
		local out =
			{ catId = catId, variant = "base", level = level, xp = 0, charm = 50 } :: { [string]: any }
		for key, value in extra or {} do
			out[key] = value
		end
		return out
	end

	-- six plain Tabbies (one working), four Tuxedos, five gold Gingers and two rainbow Smokes
	local function sample(): { [string]: any }
		return {
			t1 = cat("tabby", 3),
			t2 = cat("tabby", 12, { trait = { id = "bigTipper_epic" }, name = "Mochi" }),
			t3 = cat("tabby", 1),
			t4 = cat("tabby", 7, { trait = { id = "nightOwl_common" } }),
			t5 = cat("tabby", 2),
			t6 = cat("tabby", 30, { spotId = "barista_1" }),
			x1 = cat("tuxedo", 1),
			x2 = cat("tuxedo", 1),
			x3 = cat("tuxedo", 1),
			x4 = cat("tuxedo", 1, { locked = true }),
			g1 = cat("ginger", 5, { variant = "gold" }),
			g2 = cat("ginger", 5, { variant = "gold" }),
			g3 = cat("ginger", 5, { variant = "gold" }),
			g4 = cat("ginger", 5, { variant = "gold" }),
			g5 = cat("ginger", 5, { variant = "gold" }),
			r1 = cat("smoke", 9, { variant = "rainbow" }),
			r2 = cat("smoke", 9, { variant = "rainbow" }),
		}
	end

	describe("FusionLogic.groups", function()
		it("lists five free copies as ready, rainbow results first", function()
			local ready, almost = Logic.groups(sample(), nil)
			expect(#ready).to.equal(2)
			expect(ready[1].key).to.equal("ginger:gold")
			expect(ready[1].next).to.equal("rainbow")
			expect(ready[2].key).to.equal("tabby:base")
			expect(#ready[2].free).to.equal(5) -- the working one stays out
			expect(ready[2].total).to.equal(6)
			-- three free Tuxedos (one locked) are "almost"; rainbow Smokes can't fuse
			expect(#almost).to.equal(1)
			expect(almost[1].key).to.equal("tuxedo:base")
			expect(Logic.almostText(almost[1])).to.equal("Tuxedo ×3 · 2 more")
		end)
		it("leaves out busy cats", function()
			local ready = Logic.groups(sample(), { g1 = true })
			expect(#ready).to.equal(1)
			expect(ready[1].key).to.equal("tabby:base")
		end)
		it("says why a copy can't go in", function()
			expect(Logic.blocker(cat("tabby", 1, { locked = true }), "a", nil)).to.equal("Locked")
			expect(Logic.blocker(cat("tabby", 1, { spotId = "x" }), "a", nil)).to.equal("Working")
			expect(Logic.blocker(cat("tabby", 1), "a", { a = true })).to.equal("Busy")
			expect(Logic.blocker(cat("tabby", 1), "a", nil)).to.equal(nil)
		end)
	end)

	describe("FusionLogic.defaultPick and result", function()
		it("keeps the best level copy and spends the weakest", function()
			local cats = sample()
			cats.t7 = cat("tabby", 4)
			local ready = Logic.groups(cats, nil)
			local tabby = ready[2]
			local pick = Logic.defaultPick(tabby)
			expect(#pick).to.equal(5)
			expect(pick[1]).to.equal("t2") -- Lv 12
			expect(table.find(pick, "t4")).to.equal(nil) -- Lv 7 is the one left over
			local result = Logic.result(tabby, pick)
			expect(result.level).to.equal(12)
			expect(result.name).to.equal("Mochi")
			expect(#result.traits).to.equal(1)
			expect(result.traits[1].id).to.equal("bigTipper_epic")
		end)
		it("lists every trait in the pick, rarest first", function()
			local ready = Logic.groups(sample(), nil)
			local result = Logic.result(ready[2], { "t1", "t2", "t3", "t4", "t5" })
			expect(#result.traits).to.equal(2)
			expect(result.traits[1].id).to.equal("bigTipper_epic")
			expect(result.traits[2].id).to.equal("nightOwl_common")
		end)
		it("asks twice and names the coat", function()
			local ready = Logic.groups(sample(), nil)
			expect(Logic.fuseText(ready[2], false)).to.equal("Fuse 5 → 1 Gold")
			expect(Logic.fuseText(ready[1], true)).to.equal(
				"Tap again: 5 Ginger become 1 Rainbow Ginger"
			)
			expect(Logic.countText(ready[1])).to.equal("Gold Ginger ×5")
		end)
	end)

	describe("FusionLogic.dome and clock", function()
		it("reads free, running and ready", function()
			expect(Logic.dome(nil, 0).state).to.equal("free")
			local running = {
				running = { catId = "tabby", coat = "gold", doneAt = 1402, level = 12 },
				goldSeconds = 600,
			}
			local dome = Logic.dome(running, 1000)
			expect(dome.state).to.equal("running")
			expect(dome.title).to.equal("Gold Tabby · 6:42")
			expect(math.abs(dome.share - 0.33) < 1e-9).to.equal(true)
			local done = Logic.dome(running, 1500)
			expect(done.state).to.equal("ready")
			expect(done.title).to.equal("Gold Tabby is ready")
			expect(done.line).to.equal("Lv 12 · tap Collect")
		end)
		it("uses the cat's own name", function()
			local view = {
				running = {
					catId = "tabby",
					coat = "rainbow",
					doneAt = 10,
					level = 3,
					name = "Mochi",
				},
				ready = true,
			}
			expect(Logic.dome(view, 0).title).to.equal("Rainbow Mochi is ready")
		end)
		it("formats the timer and the duration", function()
			expect(Logic.clock(402)).to.equal("6:42")
			expect(Logic.clock(3725)).to.equal("1:02:05")
			expect(Logic.clock(-3)).to.equal("0:00")
			expect(Logic.duration(600)).to.equal("10 min")
			expect(Logic.duration(3600)).to.equal("1 h")
			expect(Logic.duration(2700)).to.equal("45 min")
			expect(Logic.duration(5400)).to.equal("1 h 30 min")
		end)
		it("falls back to the spec's times", function()
			expect(Logic.seconds(nil, "gold")).to.equal(600)
			expect(Logic.seconds({ rainbowSeconds = 2700 }, "rainbow")).to.equal(2700)
		end)
	end)

	describe("FusionLogic.pickerLine and coatTrack", function()
		it("says what waits at the dome", function()
			local view = { running = { catId = "tabby", coat = "gold", doneAt = 400, level = 1 } }
			local line, bang = Logic.pickerLine(view, 2, 0)
			expect(line).to.equal("Observatory: Gold Tabby 7 min")
			expect(bang).to.equal(false)
			line, bang = Logic.pickerLine({ running = view.running, ready = true }, 0, 0)
			expect(line).to.equal("Observatory: Gold Tabby ready !")
			expect(bang).to.equal(true)
			expect((Logic.pickerLine(nil, 3, 0))).to.equal("Observatory: 3 can fuse !")
			expect((Logic.pickerLine(nil, 0, 0))).to.equal("Observatory: free")
		end)
		it("lights the coats found and counts the copies", function()
			local cats = sample()
			local ready = Logic.groups(cats, nil)
			local list = Logic.coatTrack(
				cats,
				{ base = { tabby = 1 }, gold = { ginger = 1 }, rainbow = {} },
				ready
			)
			local byId = {}
			for _, track in list do
				byId[track.catId] = track
			end
			expect(byId.tabby.found.base).to.equal(true)
			expect(byId.tabby.found.gold).to.equal(false)
			expect(byId.tabby.owned.base).to.equal(6)
			expect(byId.tabby.canFuse).to.equal(true)
			expect(byId.ginger.found.gold).to.equal(true)
			expect(byId.ginger.owned.gold).to.equal(5)
			expect(byId.smoke.canFuse).to.equal(false)
		end)
	end)
end
