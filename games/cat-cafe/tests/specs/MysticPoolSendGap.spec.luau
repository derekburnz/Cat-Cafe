--!strict
-- #4477: fast re-rolls never trip the server's 1 a second limit on RollTrait and ChooseTrait
-- (MysticPoolLogic.sendIn), so the card is not left waiting on "..." for an answer that never comes.
-- Written by Motion-FX-Agent.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local MysticPoolLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MysticPoolLogic")
	) :: any

	describe("Mystic Pool presses spaced for the server's limit", function()
		it("sends a first press at once", function()
			expect(MysticPoolLogic.sendIn(nil, 100)).to.equal(0)
			expect(MysticPoolLogic.sendIn(0 / 0, 100)).to.equal(0)
		end)

		it("holds a press that comes too soon for the rest of the gap", function()
			local gap = MysticPoolLogic.SEND_GAP
			expect(gap > 1).to.equal(true) -- over the server's 1 a second
			expect(MysticPoolLogic.sendIn(100, 100.4)).to.be.near(gap - 0.4, 1e-9)
			expect(MysticPoolLogic.sendIn(100, 100 + gap)).to.be.near(0, 1e-9)
			expect(MysticPoolLogic.sendIn(100, 105)).to.equal(0)
		end)

		it("counts from a press still held, and never holds more than 3 gaps", function()
			local gap = MysticPoolLogic.SEND_GAP
			expect(MysticPoolLogic.sendIn(100.5, 100)).to.be.near(gap + 0.5, 1e-9)
			expect(MysticPoolLogic.sendIn(1000, 100)).to.equal(3 * gap)
		end)

		it("keeps 30 presses as fast as the buttons allow at least a gap apart", function()
			-- the buttons rest from a press until its answer (0.2 s after it goes), then the player taps again at once
			local last: number? = nil
			local now = 0
			local sent: { number } = {}
			for _ = 1, 30 do
				local hold = MysticPoolLogic.sendIn(last, now)
				last = now + hold
				table.insert(sent, now + hold)
				now = now + hold + 0.2 + 0.05
			end
			for i = 2, #sent do
				expect(sent[i] - sent[i - 1] >= MysticPoolLogic.SEND_GAP - 1e-9).to.equal(true)
				expect(sent[i] - sent[i - 1] <= MysticPoolLogic.SEND_GAP + 1e-9).to.equal(true)
			end
		end)
	end)
end
