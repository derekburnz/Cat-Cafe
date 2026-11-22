--!strict
-- Util/EventGate.luau: the analytics send budget in front of every Telemetry Log call (396 "You have sent too many
-- events" errors in 24 h since v498). Over budget an event waits in order instead of being refused; only a full
-- queue drops, and the drop is counted.
return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local EventGate = require(ServerScriptService.Server.Util.EventGate)

	local function drain(gate: EventGate.Gate, from: number, to: number, players: number): { any }
		local out = {}
		local t = from
		while t <= to do
			for _, item in gate:due(t, players) do
				table.insert(out, item)
			end
			t += 1
		end
		return out
	end

	describe("EventGate.rate", function()
		it("allows 80% of 120 + 20 a player each minute", function()
			expect(EventGate.rate(0) * 60).to.be.near(96, 1e-6)
			expect(EventGate.rate(8) * 60).to.be.near(224, 1e-6)
		end)
	end)

	describe("EventGate offer and due", function()
		it("sends a new server's first burst at once, then queues the rest in order", function()
			local gate = EventGate.new(0)
			local burst = math.floor(EventGate.rate(0) * EventGate.BURST_SECONDS)
			local sent = 0
			for i = 1, burst + 5 do
				if gate:offer(i, 0, 0) then
					sent += 1
				end
			end
			expect(sent).to.equal(burst)
			expect(gate:size()).to.equal(5)
			local out = drain(gate, 1, 10, 0)
			expect(#out).to.equal(5)
			for i, item in out do
				expect(item).to.equal(burst + i)
			end
			expect(gate:size()).to.equal(0)
		end)

		it("keeps order: a new event waits behind queued ones even when budget is back", function()
			local gate = EventGate.new(0)
			gate.tokens = 0
			expect(gate:offer("a", 0, 0)).to.equal(false)
			-- budget refilled, but "a" is still waiting, so "b" queues behind it
			expect(gate:offer("b", 5, 0)).to.equal(false)
			local out = gate:due(5, 0)
			expect(out[1]).to.equal("a")
			expect(out[2]).to.equal("b")
		end)

		it("never sends more than the Roblox limit in any minute of a flood", function()
			local players = 8
			local gate = EventGate.new(0)
			local limit = EventGate.BASE_PER_MINUTE + EventGate.PER_PLAYER_PER_MINUTE * players
			local perSecond = {}
			for second = 0, 299 do
				local count = 0
				for _ = 1, 20 do
					if gate:offer(true, second, players) then
						count += 1
					end
				end
				count += #gate:due(second, players)
				perSecond[second] = count
			end
			for start = 0, 240 do
				local total = 0
				for second = start, start + 59 do
					total += perSecond[second]
				end
				expect(total <= limit).to.equal(true)
			end
		end)

		it("drops only when the queue is full, and counts the drops", function()
			local gate = EventGate.new(0)
			gate.tokens = 0
			for i = 1, EventGate.QUEUE_MAX + 7 do
				gate:offer(i, 0, 0)
			end
			expect(gate:size()).to.equal(EventGate.QUEUE_MAX)
			expect(gate:takeDropped()).to.equal(7)
			expect(gate:takeDropped()).to.equal(0)
		end)

		it("does not bank more than BURST_SECONDS of budget after a quiet spell", function()
			local gate = EventGate.new(0)
			gate:due(3600, 0)
			expect(gate.tokens).to.be.near(EventGate.rate(0) * EventGate.BURST_SECONDS, 1e-6)
		end)
	end)
end
