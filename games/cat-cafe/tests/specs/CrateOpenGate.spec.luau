--!strict
-- #1146: Crates.openRefusal, the OpenCrate rule FishMarketService and the Market window's Open buttons share. An open
-- is refused while another is in flight ("busy") or within CrateOpenCooldownSeconds of the last start ("spam"), so a
-- Quick open and the next crate, and Buy 5's crates one by one, go through, while a script firing fast does not.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)

	local LIMIT = Config.CrateOpenCooldownSeconds
	local SLACK = 0.2 -- the Market window's GATE_SLACK

	-- A model of the server's side of OpenCrate (FishMarketService.onOpenCrate needs Players and remotes, so it is
	-- Studio-only) for one player: the gate, then an open that sets the in-flight flag and clears it once its
	-- CrateResult is sent. Keep it in step with onOpenCrate. `banked` crates; returns what each call got.
	local function server(banked: number)
		local self = { banked = banked, inFlight = false, lastAt = nil :: number?, opened = 0 }
		function self.press(now: number): string
			local gate = Crates.openRefusal(self.inFlight, self.lastAt, now)
			if gate ~= nil then
				return gate
			end
			if self.banked <= 0 then
				return "none left"
			end
			self.lastAt = now
			self.inFlight = true
			self.banked -= 1
			self.opened += 1
			-- CrateResult sent
			self.inFlight = false
			return "opened"
		end
		return self
	end

	describe("Crates.openRefusal (#1146)", function()
		it("is a short spam limit, not the old 2 s cooldown", function()
			expect(LIMIT > 0 and LIMIT <= 0.5).to.equal(true)
		end)

		it("refuses while an open is in flight, whatever the time", function()
			expect(Crates.openRefusal(true, nil, 100)).to.equal("busy")
			expect(Crates.openRefusal(true, 0, 100)).to.equal("busy")
		end)

		it("refuses within the spam limit of the last start and allows after it", function()
			expect(Crates.openRefusal(false, nil, 100)).to.equal(nil)
			expect(Crates.openRefusal(false, 100, 100)).to.equal("spam")
			expect(Crates.openRefusal(false, 100, 100 + LIMIT / 2)).to.equal("spam")
			expect(Crates.openRefusal(false, 100, 100 + LIMIT + 1e-6)).to.equal(nil)
		end)

		it("the client's slack waits a little longer than the server", function()
			expect(Crates.openRefusal(false, 100, 100 + LIMIT + 1e-6, SLACK)).to.equal("spam")
			expect(Crates.openRefusal(false, 100, 100 + LIMIT + SLACK + 1e-6, SLACK)).to.equal(nil)
		end)

		it("a Quick open, then the next crate at once (well inside the old 2 s): opens", function()
			local s = server(2)
			expect(s.press(10)).to.equal("opened")
			-- the reveal skipped; the window waits out the limit plus its slack, then fires
			expect(s.press(10 + LIMIT + SLACK)).to.equal("opened")
			expect(s.opened).to.equal(2)
		end)

		it("Buy 5: five banked crates open one after another, none refused", function()
			local s = server(Config.CrateBundleCount)
			local now = 50
			for _ = 1, Config.CrateBundleCount do
				expect(s.press(now)).to.equal("opened")
				-- the client's next Open frees up after the limit and slack; jitter can make it arrive 0.15 s early
				now += LIMIT + SLACK - 0.15
			end
			expect(s.opened).to.equal(Config.CrateBundleCount)
			expect(s.press(now)).to.equal("none left")
		end)

		it(
			"a script firing every 0.1 s gets one open per spam window, and two in one frame get one",
			function()
				local s = server(100)
				expect(s.press(0)).to.equal("opened")
				expect(s.press(0)).to.equal("spam")
				local t = 0
				for _ = 1, 20 do
					t += 0.1
					s.press(t)
				end
				-- 2.0 s of presses: at most one per LIMIT
				expect(s.opened <= math.floor(2 / LIMIT) + 1).to.equal(true)
				expect(s.opened < 21).to.equal(true)
			end
		)

		it(
			"an open still in flight refuses the next one with busy (two windows, a slow server)",
			function()
				local s = server(3)
				s.inFlight = true
				expect(s.press(100)).to.equal("busy")
				s.inFlight = false
				expect(s.press(100)).to.equal("opened")
			end
		)
	end)
end
