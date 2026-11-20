--!strict
-- Effects/WorldGlow (#5533 v2): the stall glow fades in and out inside its 6 s, the cannon sign names the area, and
-- the door glows only while carrying the first cat with the switch on.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local WorldGlow = require(Effects:WaitForChild("WorldGlow")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local p = Presets.worldGlow

	describe("WorldGlow", function()
		it("glows a stall target only inside its seconds, softly", function()
			expect(WorldGlow.stallStrength(0, 6, 1.5, 0.35, false)).to.equal(0)
			expect(WorldGlow.stallStrength(6, 6, 1.5, 0.35, false)).to.equal(0)
			expect(WorldGlow.stallStrength(-1, 6, 1.5, 0.35, false)).to.equal(0)
			for i = 1, 59 do
				local k = WorldGlow.stallStrength(i / 10, 6, 1.5, 0.35, false)
				expect(k >= 0 and k <= 1).to.equal(true)
			end
			-- still with Reduce Motion: full between the fades
			expect(WorldGlow.stallStrength(3, 6, 1.5, 0.35, true)).to.equal(1)
			expect(p.stallSeconds).to.equal(6)
		end)

		it("breathes slower than 3 times a second", function()
			expect(p.breathe >= 1 / 3).to.equal(true)
			expect(p.steadyPeriod >= 1 / 3).to.equal(true)
		end)

		it("names the area on the cannon's sign", function()
			expect(WorldGlow.signText("park")).to.equal("PARK")
			expect(WorldGlow.signText("alley")).to.equal("ALLEYWAY")
			expect(WorldGlow.signText("moon")).to.equal("MOON")
		end)

		it("glows the door only while carrying the first cat", function()
			expect(WorldGlow.carryDoor(true, 1, true)).to.equal(true)
			expect(WorldGlow.carryDoor(true, 0, true)).to.equal(true)
			expect(WorldGlow.carryDoor(true, 2, true)).to.equal(false)
			expect(WorldGlow.carryDoor(false, 1, true)).to.equal(false)
			expect(WorldGlow.carryDoor(true, 1, false)).to.equal(false)
		end)

		it("lights the camp cannon only when the player is near it", function()
			expect(WorldGlow.campNear(50, p.campReach)).to.equal(true)
			expect(WorldGlow.campNear(p.campReach + 1, p.campReach)).to.equal(false)
		end)
	end)
end
