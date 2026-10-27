--!strict
-- UI/Components/ShoveTarget.luau: who the Shove button aims at (data-model section 10c, reviewer S46).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local ShoveTarget = require(Components:WaitForChild("ShoveTarget")) :: any

	local A, B, C = 101, 202, 303

	describe("ShoveTarget.pick", function()
		it("aims at the nearest player within range", function()
			local candidates = {
				{ userId = A, distance = 4.5 },
				{ userId = B, distance = 2 },
				{ userId = C, distance = 7 },
			}
			expect(ShoveTarget.pick(candidates, 6, {}, {}, 0)).to.equal(2)
		end)

		it("aims at no one when everyone is out of range", function()
			local candidates = { { userId = A, distance = 6.5 }, { userId = B, distance = 9 } }
			expect(ShoveTarget.pick(candidates, 6, {}, {}, 0)).never.to.be.ok()
			expect(ShoveTarget.pick({}, 6, {}, {}, 0)).never.to.be.ok()
		end)

		it("passes over a player holding a catch or rescue lock", function()
			local candidates = { { userId = A, distance = 1.5 }, { userId = B, distance = 5 } }
			expect(ShoveTarget.pick(candidates, 6, { [A] = true }, {}, 0)).to.equal(2)
			expect(ShoveTarget.pick(candidates, 6, { [A] = true, [B] = true }, {}, 0)).never.to.be.ok()
		end)

		it("passes over a recently shoved player until the wait ends", function()
			local candidates = { { userId = A, distance = 1.5 }, { userId = B, distance = 5 } }
			local skipUntil = { [A] = 20 }
			expect(ShoveTarget.pick(candidates, 6, {}, skipUntil, 10)).to.equal(2)
			expect(ShoveTarget.pick(candidates, 6, {}, skipUntil, 20)).to.equal(1)
		end)

		it("keeps the first of two players at the same distance", function()
			local candidates = { { userId = A, distance = 3 }, { userId = B, distance = 3 } }
			expect(ShoveTarget.pick(candidates, 6, {}, {}, 0)).to.equal(1)
		end)
	end)
end
