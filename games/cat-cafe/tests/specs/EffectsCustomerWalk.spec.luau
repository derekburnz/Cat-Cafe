--!strict
-- Customers walking with a step instead of a hop (#1143, Effects/CustomerWalk): which part of a customer is a leg or
-- an arm, and the step's swing, drop and roll. The walk on a real model needs Studio. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.customerWalk

	describe("Effects customer walk", function()
		it("finds the legs, shoes, hands and arms of a customer by where they are", function()
			-- parts of CatCafe_NPC_Customer_A: x, bottom, top over the feet
			expect(Logic.customerPiece(-0.32, 0, 0.3)).to.equal("legL") -- a shoe
			expect(Logic.customerPiece(0.32, 0.25, 1.65)).to.equal("legR") -- a leg
			expect(Logic.customerPiece(-0.89, 1.78, 2.12)).to.equal("armL") -- a hand
			expect(Logic.customerPiece(0.9, 2.1, 3.4)).to.equal("armR") -- an arm
			expect(Logic.customerPiece(0, 1.85, 3.35)).to.equal(nil) -- the torso
			expect(Logic.customerPiece(0, 1.15, 1.95)).to.equal(nil) -- the hips
			expect(Logic.customerPiece(0.83, 1.16, 1.94)).to.equal(nil) -- a skirt panel at the side
		end)

		it("stands still at no weight and steps legs and arms opposite as it walks", function()
			local leg, arm, drop, roll = Logic.customerStep(1.2, 0)
			expect(leg).to.equal(0)
			expect(arm).to.equal(0)
			expect(drop).to.equal(0)
			expect(roll).to.equal(0)
			leg, arm = Logic.customerStep(math.pi / 2, 1)
			expect(leg).to.be.near(math.rad(c.legSwing), 1e-9)
			expect(arm).to.be.near(-math.rad(c.armSwing), 1e-9)
		end)

		it("keeps the feet on the floor: the body drops as much as a swung leg rises", function()
			for _, phase in { 0, 0.4, math.pi / 2, 2, math.pi, 4.5 } do
				local leg, _, drop = Logic.customerStep(phase, 1)
				expect(drop <= 0).to.equal(true)
				-- the foot's height over the floor
				local foot = drop + c.hip - c.hip * math.cos(leg)
				expect(foot).to.be.near(0, 1e-9)
				expect(-drop < 0.15).to.equal(true) -- a small bob, not a hop
			end
		end)

		it("takes a step about every half stride at the customers' walking speed", function()
			local speed = 7 -- Config.CustomerWalkSpeed
			local stepsPerSecond = speed / c.stride * 2
			expect(stepsPerSecond > 3 and stepsPerSecond < 7).to.equal(true)
		end)

		it("settles on the same feet frame after frame, never sinking (#1331 review)", function()
			-- the models' pivot follows the head (their PrimaryPart), so it carries the body's drop each frame
			local ground, facing = Vector3.new(4, 2, -3), Vector3.new(1, 0, 2).Unit
			local feet, look, drop = ground, facing, 0
			for i = 1, 120 do
				-- where the last frame left the body's origin
				local pivot = feet + Vector3.new(0, drop, 0)
				feet, look = Logic.customerFeet(pivot, look, drop) -- what settle reads back
				local _, _, nextDrop = Logic.customerStep(i * 0.37, 1 - i / 120)
				drop = nextDrop
			end
			expect((feet - ground).Magnitude < 1e-9).to.equal(true)
			expect((look - facing).Magnitude < 1e-9).to.equal(true)
		end)

		it("stands the look flat whatever the pivot's tilt", function()
			local _, look = Logic.customerFeet(Vector3.zero, Vector3.new(0.3, -0.2, 0.9), 0)
			expect(look.Y).to.equal(0)
			expect(math.abs(look.Magnitude - 1) < 1e-9).to.equal(true)
			local _, straight = Logic.customerFeet(Vector3.zero, Vector3.yAxis, 0)
			expect(straight.Z).to.equal(-1)
		end)

		it("moves less with Reduce Motion", function()
			local leg, _, _, roll = Logic.customerStep(math.pi / 2, 1, true)
			local full, _, _, fullRoll = Logic.customerStep(math.pi / 2, 1)
			expect(leg).to.be.near(full * c.reduced, 1e-9)
			expect(roll).to.be.near(fullRoll * c.reduced, 1e-9)
		end)
	end)
end
