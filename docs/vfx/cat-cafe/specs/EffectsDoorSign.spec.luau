--!strict
-- The door sign (#1172, #1140): the names DoorSign.luau looks for match Model-Agent's sign, and the flip at nightfall
-- and sunrise turns half a turn, then settles with one small swing (door-sign.md section 3).
-- Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Effects door sign", function()
		it("finds Model-Agent's sign by its names", function()
			-- CatCafe_Decor_DoorSign: the OPEN face's parts, the CLOSED face's and the hanger's child Models
			local d = Presets.doorSign
			expect(d.open).to.equal("CatCafe_Decor_DoorSign_Open")
			expect(d.closed).to.equal("CatCafe_Decor_DoorSign_Closed")
			expect(d.hanger).to.equal("CatCafe_Decor_DoorSign_Hanger")
			expect(d.open ~= d.closed and d.hanger ~= d.closed).to.equal(true)
		end)

		it("flips over 0.6 s and settles with an 8 degree swing in 0.4 s", function()
			local d = Presets.doorSign
			expect(d.flip).to.equal(0.6)
			expect(d.settle).to.equal(0.4)
			expect(d.swing).to.equal(8)
		end)

		it("turns all the way, then swings back to rest", function()
			local swing = math.rad(8)
			local share, extra = Logic.signFlip(0, 0.6, 0.4, swing)
			expect(share).to.equal(0)
			expect(extra).to.equal(0)
			share = Logic.signFlip(0.3, 0.6, 0.4, swing)
			expect(close(share, 0.5)).to.equal(true) -- halfway through, eased
			share, extra = Logic.signFlip(0.7, 0.6, 0.4, swing)
			expect(share).to.equal(1)
			expect(extra > 0 and extra < swing).to.equal(true) -- swinging on past the half turn
			share, extra = Logic.signFlip(0.9, 0.6, 0.4, swing)
			expect(extra < 0 and extra > -swing).to.equal(true) -- and back
			share, extra = Logic.signFlip(1.05, 0.6, 0.4, swing)
			expect(share).to.equal(1)
			expect(extra).to.equal(0) -- at rest
		end)
	end)
end
