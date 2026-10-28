--!strict
-- shared/BackDoor.luau (Model-Agent #509; Derek 2026-10-28 01:28: players walk through the door, cats use the flap):
-- when the leaf stands open and how the leaf and the cat flap move.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BackDoor = require(Shared.BackDoor)

	local FRAME = 1 / 60

	describe("wantsOpen", function()
		it("opens by day on an owned cafe for a player within OPEN_RANGE", function()
			expect(BackDoor.OPEN_DEGREES).to.equal(-90)
			expect(BackDoor.wantsOpen(true, true, 0)).to.equal(true)
			expect(BackDoor.wantsOpen(true, true, BackDoor.OPEN_RANGE)).to.equal(true)
			expect(BackDoor.wantsOpen(true, true, BackDoor.OPEN_RANGE + 0.1)).to.equal(false)
			expect(BackDoor.wantsOpen(true, true, nil)).to.equal(false)
		end)

		it("stays shut at night and on an empty plot", function()
			expect(BackDoor.wantsOpen(false, true, 0)).to.equal(false)
			expect(BackDoor.wantsOpen(true, false, 0)).to.equal(false)
		end)
	end)

	describe("frontTurn", function()
		it("turns a door set's left front leaf -90 and its right one +90, into the cafe", function()
			expect(BackDoor.FRONT_OPEN_DEGREES).to.equal(90)
			expect(BackDoor.frontTurn("CatCafe_Door_FireEscape_Front_LeafL")).to.equal(-1)
			expect(BackDoor.frontTurn("CatCafe_Door_FireEscape_Front_LeafR")).to.equal(1)
		end)

		it("leaves the rest of the model still", function()
			expect(BackDoor.frontTurn("CatCafe_Door_FireEscape_Front")).to.equal(nil)
			expect(BackDoor.frontTurn("CatCafe_Door_FireEscape_Front_LeafL_Glass")).to.equal(nil)
			expect(BackDoor.frontTurn("CatCafe_Door_FireEscape_Back_Leaf")).to.equal(nil)
		end)
	end)

	describe("stepLeaf", function()
		it("eases open within a second and lands on the angle, then shuts the same way", function()
			local angle = 0
			local frames = 0
			while angle ~= BackDoor.OPEN_DEGREES do
				local nextAngle = BackDoor.stepLeaf(angle, BackDoor.OPEN_DEGREES, FRAME)
				expect(nextAngle <= angle).to.equal(true) -- always on toward open, never past it
				expect(nextAngle >= BackDoor.OPEN_DEGREES).to.equal(true)
				angle = nextAngle
				frames += 1
				expect(frames < 60).to.equal(true)
			end
			while angle ~= 0 do
				angle = BackDoor.stepLeaf(angle, 0, FRAME)
				frames += 1
				expect(frames < 120).to.equal(true)
			end
		end)

		it("never overshoots on a long frame and stays put with no time", function()
			expect(BackDoor.stepLeaf(-30, -90, 5)).to.equal(-90)
			expect(BackDoor.stepLeaf(-30, -90, 0)).to.equal(-30)
			expect(BackDoor.stepLeaf(-30, -90, -1)).to.equal(-30)
		end)
	end)

	describe("the cat flap", function()
		it("is pushed in by a cat in the yard and out by a cat inside", function()
			expect(BackDoor.pushFrom(1.5)).to.equal(1)
			expect(BackDoor.pushFrom(0)).to.equal(1)
			expect(BackDoor.pushFrom(-0.5)).to.equal(-1)
		end)

		it("swings toward FLAP_PUSH while a cat is at it, then rocks back to rest", function()
			local angle, speed = 0, 0
			for _ = 1, 30 do
				angle, speed = BackDoor.stepFlap(angle, speed, 1, FRAME)
			end
			expect(angle).to.be.near(BackDoor.FLAP_PUSH, 1)
			local crossed = false
			local frames = 0
			while angle ~= 0 or speed ~= 0 do
				angle, speed = BackDoor.stepFlap(angle, speed, nil, FRAME)
				expect(math.abs(angle) <= BackDoor.FLAP_MAX).to.equal(true)
				crossed = crossed or angle < 0
				frames += 1
				expect(frames < 600).to.equal(true) -- settles within ten seconds
			end
			expect(crossed).to.equal(true) -- a swing back past rest, like a real flap
			angle, speed = 0, 0
			for _ = 1, 30 do
				angle, speed = BackDoor.stepFlap(angle, speed, -1, FRAME)
			end
			expect(angle).to.be.near(-BackDoor.FLAP_PUSH, 1)
		end)

		it("stays steady on a long frame and still with no time", function()
			local angle, speed = BackDoor.FLAP_PUSH, 0
			for _ = 1, 200 do
				angle, speed = BackDoor.stepFlap(angle, speed, nil, 1)
				expect(math.abs(angle) <= BackDoor.FLAP_MAX).to.equal(true)
			end
			expect(angle).to.equal(0)
			expect(speed).to.equal(0)
			local a, s = BackDoor.stepFlap(12, 3, nil, 0)
			expect(a).to.equal(12)
			expect(s).to.equal(3)
		end)
	end)
end
