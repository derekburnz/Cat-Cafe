--!strict
-- CarrySync.luau (#3145): when the screen's carry state must be set again to the server's.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CarrySync = require(Shared.CarrySync)

	local function view(catId: string?, banner: boolean, built: boolean?): CarrySync.View
		return { built = built ~= false, catId = catId, banner = banner }
	end

	describe("CarrySync.stale", function()
		it("is quiet while the screen agrees with the server", function()
			expect(CarrySync.stale(nil, nil, view(nil, false))).to.equal(false)
			expect(CarrySync.stale("bengal", "bengal", view("bengal", true))).to.equal(false)
		end)

		it("asks for a change of cat, a pick up and a put down", function()
			expect(CarrySync.stale("bengal", nil, view(nil, false))).to.equal(true)
			expect(CarrySync.stale(nil, "bengal", view("bengal", true))).to.equal(true)
			expect(CarrySync.stale("tabby", "bengal", view("bengal", true))).to.equal(true)
		end)

		it(
			"takes down a banner left up for a cat the server no longer has (Derek2's screenshot)",
			function()
				-- the last value applied was nil, yet the banner is up and the UI still names the cat
				expect(CarrySync.stale(nil, nil, view("bengal", true))).to.equal(true)
				expect(CarrySync.stale(nil, nil, view(nil, true))).to.equal(true)
				-- the UI's state names a cat with no banner (a sync that stopped part way): G would still send Drop
				expect(CarrySync.stale(nil, nil, view("bengal", false))).to.equal(true)
			end
		)

		it("puts back a banner that never came up, or names the wrong cat", function()
			expect(CarrySync.stale("bengal", "bengal", view("bengal", false))).to.equal(true)
			expect(CarrySync.stale("bengal", "bengal", view("tabby", true))).to.equal(true)
			expect(CarrySync.stale("bengal", "bengal", view(nil, true))).to.equal(true)
		end)

		it("waits for the HUD before comparing the banner", function()
			expect(CarrySync.stale("bengal", "bengal", view("bengal", false, false))).to.equal(
				false
			)
			expect(CarrySync.stale(nil, nil, view(nil, false, false))).to.equal(false)
			-- a new value is still handed over before the HUD exists (UI.setCarrying keeps it in its state)
			expect(CarrySync.stale("bengal", nil, view(nil, false, false))).to.equal(true)
		end)
	end)

	-- UIController in small: `latest` is noted as each sync arrives, `apply` hands a value to the screen.
	describe("a Drop of a Backpack cat: two syncs in one frame", function()
		local function screen()
			local ui = { catId = nil :: string?, banner = false }
			local applied: string? = nil
			local latest: string? = nil
			local function refresh()
				local now: CarrySync.View = { built = true, catId = ui.catId, banner = ui.banner }
				if CarrySync.stale(latest, applied, now) then
					applied = latest
					ui.catId, ui.banner = latest, latest ~= nil
				end
			end
			return ui, function(value: string?)
				latest = value
			end, refresh
		end

		it("ends with no banner when the syncs apply in order", function()
			local ui, arrive, refresh = screen()
			arrive("bengal")
			refresh()
			expect(ui.banner).to.equal(true)
			arrive(nil)
			refresh()
			expect(ui.banner).to.equal(false)
			expect(ui.catId).to.equal(nil)
		end)

		it("ends with no banner when the first sync finishes applying after the second", function()
			local ui, arrive, refresh = screen()
			arrive("bengal") -- the first sync arrives and is held up before it reaches the banner
			arrive(nil) -- the second arrives and applies in full
			refresh()
			refresh() -- the first resumes: it reads the newest value, not its own
			expect(ui.banner).to.equal(false)
			expect(ui.catId).to.equal(nil)
		end)

		it("takes a stuck banner down on the next look, with no new sync", function()
			local ui, arrive, refresh = screen()
			arrive(nil)
			ui.catId, ui.banner = "bengal", true -- left behind, whatever the cause
			refresh()
			expect(ui.banner).to.equal(false)
			expect(ui.catId).to.equal(nil)
		end)
	end)
end
