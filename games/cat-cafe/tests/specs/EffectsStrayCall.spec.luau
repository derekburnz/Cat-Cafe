--!strict
-- #3022: the stray waiting for your second cat calls you over (Effects/StrayCall): a couple of small hops, its head
-- turned to you and tipped up, tail up and flicking. Logic.beckon is pure; the call on a real stray is a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local b = Presets.motion.beckon

	local function at(alpha: number, yaw: number?): any
		local o = Logic.blank()
		o.tailYaw = 0.3
		o.earL = 0.2
		Logic.beckon(o, alpha, yaw or 0)
		return o
	end

	describe("Effects waiting stray call", function()
		it("does its hops in the first part and stands still by the end", function()
			expect(at(0).bodyY).to.be.near(0, 1e-9)
			local top = at(b.hopShare / b.hops / 2)
			expect(top.bodyY).to.be.near(b.hop, 1e-6)
			expect(at(b.hopShare + 0.01).bodyY).to.equal(0)
			expect(at(0.999).bodyY).to.equal(0)
		end)

		it("turns its head to you, tips it up and lifts its tail, then lets go", function()
			local mid = at(0.5, 40)
			expect(mid.headYaw).to.be.near(math.rad(40), 1e-6)
			expect(mid.headPitch).to.be.near(math.rad(b.lookUp), 1e-6)
			expect(mid.tailPitch).to.be.near(math.rad(b.tailUp), 1e-6)
			expect(mid.earL).to.be.near(0, 1e-6) -- ears forward
			for _, alpha in { -0.1, 1, 1.5 } do
				local o = at(alpha, 40)
				expect(o.headYaw).to.equal(0)
				expect(o.tailYaw).to.equal(0.3)
				expect(o.earL).to.equal(0.2)
			end
		end)

		it("moves with no jumps at 60 frames a second", function()
			local step = 1 / (60 * b.seconds)
			local last = at(0, 50)
			for alpha = step, 1 - step, step do
				local o = at(alpha, 50)
				expect(math.abs(o.bodyY - last.bodyY) < 0.1).to.equal(true)
				expect(math.abs(o.headYaw - last.headYaw) < math.rad(6)).to.equal(true)
				expect(math.abs(o.tailYaw - last.tailYaw) < math.rad(8)).to.equal(true)
				last = o
			end
		end)

		it("calls only from close by and not too often", function()
			expect(b.near > 0 and b.near <= 40).to.equal(true)
			expect(b.every > b.seconds).to.equal(true)
			expect(Logic.lookYaw(-10, 0, b.look)).to.be.near(b.look, 1e-9) -- clamped
		end)
	end)
end
