--!strict
-- #3362: every OpenCrate with a real crate id gets an answer. The Market window waits for a CrateResult, and before
-- this a call dropped by Net's rate limit, a call before the save had loaded or an open that errored got none, so
-- the button gave up with "That didn't go through. Try again!" and nothing said why.
-- Net.on and FishMarketService.onOpenCrate need Players and remotes (Studio-only), so this models them for one
-- player with the real RateLimiter on a fake clock. Keep it in step with Net.on and onOpenCrate.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local Guard = require(ServerScriptService.Server.Util.Guard)
	local RateLimiter = require(ServerScriptService.Server.Util.RateLimiter)

	type Answer = { decorId: string, toast: string? }

	-- `opts.loaded` false: DataService.get is nil. `opts.fails` true: open() errors.
	type Opts = { loaded: boolean?, fails: boolean? }
	local function server(banked: number, opts: Opts?)
		local o: Opts = opts or {}
		local clock = 0
		local function now(): number
			return clock
		end
		local self = {
			banked = banked,
			answers = {} :: { Answer },
			inFlight = nil :: number?,
			lastAt = nil :: number?,
			loaded = o.loaded ~= false,
			fails = o.fails == true,
		}
		-- Net's limits for OpenCrate: the per-remote bucket and the drop-answer bucket
		local limiter = RateLimiter.new(3, 1, now)
		local dropAnswers = RateLimiter.new(2, 1, now)

		local function answer(decorId: string, toast: string?)
			table.insert(self.answers, { decorId = decorId, toast = toast })
		end

		local function onOpenCrate(raw: unknown)
			local crateId = Guard.id(raw)
			if crateId == nil then
				return
			end
			if not self.loaded then
				answer("", "Your save is still loading. Try again in a moment")
				return
			end
			local started = self.inFlight
			local gate =
				Crates.openRefusal(started ~= nil and clock - started < 5, self.lastAt, clock)
			if gate == "busy" then
				answer("", "One crate at a time")
				return
			elseif gate == "spam" then
				answer("")
				return
			end
			if self.banked < 1 then
				answer("", "No crates left")
				return
			end
			self.lastAt = clock
			self.inFlight = clock
			if self.fails then
				self.inFlight = nil -- the xpcall's failure branch
				answer("", "That crate didn't open. Try again!")
				return
			end
			self.banked -= 1
			answer("piece")
			self.inFlight = nil
		end

		function self.press(at: number, raw: unknown?)
			clock = at
			local arg: unknown = if raw == nil then "alley_crate" else raw
			if not limiter:allow("u") then
				-- Net.on: dropped, then the onDrop answer under its own limit
				if dropAnswers:allow("u") and Guard.id(arg) ~= nil then
					answer("")
				end
				return
			end
			onOpenCrate(arg)
		end
		return self
	end

	describe("OpenCrate always answers (#3362)", function()
		it("a normal open answers with its piece", function()
			local s = server(1)
			s.press(1)
			expect(#s.answers).to.equal(1)
			expect(s.answers[1].decorId).to.equal("piece")
		end)

		it("a call dropped by the rate limit still gets an empty answer", function()
			local s = server(10)
			-- four calls in one frame: three pass the limiter (one opens, two are spam), the fourth is dropped
			for _ = 1, 4 do
				s.press(1)
			end
			expect(#s.answers).to.equal(4)
			local pieces = 0
			for _, a in s.answers do
				if a.decorId ~= "" then
					pieces += 1
				end
			end
			expect(pieces).to.equal(1)
		end)

		it("a flood gets at most 2 drop answers a second, not one per call", function()
			local s = server(1000)
			for _ = 1, 50 do
				s.press(1)
			end
			-- 3 through the limiter, then at most 2 answers for the 47 dropped
			expect(#s.answers <= 5).to.equal(true)
		end)

		it("before the save has loaded: an answer with a reason", function()
			local s = server(3, { loaded = false })
			s.press(1)
			expect(#s.answers).to.equal(1)
			expect(s.answers[1].decorId).to.equal("")
			expect(s.answers[1].toast ~= nil).to.equal(true)
		end)

		it("an open that errors answers and does not leave the next press busy", function()
			local s = server(3, { fails = true })
			s.press(1)
			expect(#s.answers).to.equal(1)
			expect(s.answers[1].decorId).to.equal("")
			s.fails = false
			s.press(1 + Config.CrateOpenCooldownSeconds + 0.01)
			expect(s.answers[2].decorId).to.equal("piece")
		end)

		it("a call that is not a crate id gets nothing (no answer to a script's junk)", function()
			local s = server(3)
			s.press(1, 42)
			s.press(2, { "alley_crate" })
			expect(#s.answers).to.equal(0)
		end)
	end)
end
