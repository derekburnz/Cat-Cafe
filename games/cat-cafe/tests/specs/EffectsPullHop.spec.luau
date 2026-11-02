--!strict
-- The secured cat's happy hop with a full spin (F89, luck-and-rare-moments.md 2a: "the cat does a happy hop with a
-- full spin at the door ... inside the existing catch beam"). Logic.pullHop (height and turn) and Logic.pullHopPose
-- are pure; the copy of the cat hopping in front of the player on SecuredRare (PullHop.luau) is a Studio row
-- (effects-list "Big pull hop").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local h = Presets.pullHop
	local FULL = 2 * math.pi * h.turns

	local function pose(alpha: number): any
		local o = Logic.blank()
		o.earL = 0.2
		Logic.pullHopPose(o, alpha)
		return o
	end

	describe("Effects big pull hop", function()
		it("stays on the floor until it springs, and lands back on it", function()
			for _, alpha in { 0, h.takeoff / 2, h.takeoff, h.land, h.settle, 0.99 } do
				local lift = Logic.pullHop(alpha)
				expect(lift).to.equal(0)
			end
			local middle = Logic.pullHop((h.takeoff + h.land) / 2)
			expect(middle).to.be.near(h.height, 1e-9)
		end)

		it("turns one full turn in the air and ends facing where it began", function()
			local _, before = Logic.pullHop(h.takeoff)
			local _, after = Logic.pullHop(h.land)
			expect(before).to.equal(0)
			expect(after).to.be.near(FULL, 1e-9)
			local _, last = Logic.pullHop(0.99)
			expect(last).to.be.near(FULL, 1e-9)
			local previous = -1
			for alpha = h.takeoff, h.land, 0.01 do
				local _, turn = Logic.pullHop(alpha)
				expect(turn >= previous).to.equal(true) -- always the same way round
				previous = turn
			end
		end)

		it("crouches, tucks in the air, squashes on landing and sits up proud", function()
			expect(pose(h.takeoff / 2).bodyY).to.be.near(-h.crouch, 1e-9)
			local air = pose((h.takeoff + h.land) / 2)
			expect(air.tailPitch).to.be.near(math.rad(h.tailUp), 1e-9)
			expect(air.pawFL > 0 and air.pawBL < 0).to.equal(true)
			expect(air.earL).to.be.near(0, 1e-9)
			expect(pose((h.land + h.settle) / 2).bodyY).to.be.near(-h.squash, 1e-9)
			local proud = pose(0.9)
			expect(proud.headPitch).to.be.near(math.rad(h.proud), 1e-9)
			for _, alpha in { -0.1, 1, 1.2 } do
				local o = pose(alpha)
				expect(o.bodyY).to.equal(0)
				expect(o.earL).to.equal(0.2)
			end
		end)

		it("moves with no jumps at 60 frames a second", function()
			local step = 1 / (60 * h.seconds)
			local lastLift, lastTurn = Logic.pullHop(0)
			local last = pose(0)
			for alpha = step, 1 - step, step do
				local lift, turn = Logic.pullHop(alpha)
				local o = pose(alpha)
				expect(math.abs(lift - lastLift) < 0.25).to.equal(true)
				expect(math.abs(turn - lastTurn) < math.rad(20)).to.equal(true)
				expect(math.abs(o.bodyY - last.bodyY) < 0.15).to.equal(true)
				expect(math.abs(o.tailPitch - last.tailPitch) < math.rad(12)).to.equal(true)
				expect(math.abs(o.pawFL - last.pawFL) < math.rad(12)).to.equal(true)
				expect(math.abs(o.bodyPitch - last.bodyPitch) < math.rad(6)).to.equal(true)
				lastLift, lastTurn, last = lift, turn, o
			end
		end)

		it("plays for the big pulls only, and fits inside the pull's card time", function()
			expect(Logic.bigPull("Legendary", false)).to.equal(true)
			expect(Logic.bigPull("Epic", true)).to.equal(true)
			expect(Logic.bigPull("Epic", false)).to.equal(false)
			expect(h.seconds <= Presets.bigPull.seconds).to.equal(true)
			expect(h.takeoff < h.land and h.land < h.settle and h.settle < 1).to.equal(true)
		end)
	end)
end
