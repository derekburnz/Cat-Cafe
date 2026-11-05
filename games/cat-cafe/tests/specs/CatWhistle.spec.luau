--!strict
-- UI/Components/CatWhistle.luau: the whistle picks the nearest stray in reach (corner-shop-v2.md section 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatWhistle = require(Components:WaitForChild("CatWhistle")) :: any

	describe("CatWhistle.pick", function()
		it("takes the nearest candidate within reach, or none", function()
			local near = { name = "near" }
			local far = { name = "far" }
			local list = {
				{ model = far, position = Vector3.new(300, 0, 0) },
				{ model = near, position = Vector3.new(0, 0, 40) },
			}
			expect(CatWhistle.pick(Vector3.zero, list, 600)).to.equal(near)
			expect(CatWhistle.pick(Vector3.zero, list, 10)).to.equal(nil)
			expect(CatWhistle.pick(Vector3.zero, {}, 600)).to.equal(nil)
		end)
		it("reaches a stray 900 studs off, far past the rarity gems' 80 (#1458)", function()
			local stray = { name = "stray" }
			local list = { { model = stray, position = Vector3.new(900, 0, 0) } }
			expect(CatWhistle.REACH >= 1000).to.equal(true)
			expect(CatWhistle.pick(Vector3.zero, list, CatWhistle.REACH)).to.equal(stray)
		end)
	end)
end
