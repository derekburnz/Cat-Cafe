--!strict
-- shared/BackdropNear.luau (#4857): an area's backdrop ring stays in the client's Workspace only near it.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local BackdropNear =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BackdropNear"))

	describe("BackdropNear", function()
		local box = { x = -1400, z = -1400, ax = 1, az = 0, halfX = 200, halfZ = 200 }
		local margin = BackdropNear.MARGIN

		it("counts a point inside the box and within the margin, on the ground plane", function()
			expect(BackdropNear.near(box, Vector3.new(-1400, 0, -1400), margin)).to.equal(true)
			expect(BackdropNear.near(box, Vector3.new(-1400 + 200 + margin - 1, 0, -1400), margin)).to.equal(
				true
			)
			expect(BackdropNear.near(box, Vector3.new(-1400 + 200 + margin + 1, 0, -1400), margin)).to.equal(
				false
			)
			-- a camera high over the area still counts
			expect(BackdropNear.near(box, Vector3.new(-1400, 900, -1400), margin)).to.equal(true)
		end)

		it("leaves a far area's ring out at the Town spawn", function()
			expect(
				BackdropNear.keep(
					box,
					{ Vector3.new(0, 5, 0), Vector3.new(10, 20, 30) },
					false,
					false
				)
			).to.equal(false)
		end)

		it("keeps a ring while any point is near, or while flying there", function()
			local near = Vector3.new(-1400 + 200 + margin - 10, 5, -1400)
			expect(BackdropNear.keep(box, { Vector3.new(0, 5, 0), near }, false, false)).to.equal(
				true
			)
			expect(BackdropNear.keep(box, { Vector3.new(0, 5, 0) }, false, true)).to.equal(true)
		end)

		it("turns with the ring", function()
			-- a ring 1000 long on X turned a quarter: long on Z instead
			local long = { x = 0, z = 0, ax = 0, az = 1, halfX = 500, halfZ = 50 }
			expect(BackdropNear.near(long, Vector3.new(0, 0, 900), 0)).to.equal(false)
			expect(BackdropNear.near(long, Vector3.new(0, 0, 450), 0)).to.equal(true)
			expect(BackdropNear.near(long, Vector3.new(450, 0, 0), 0)).to.equal(false)
		end)

		it("holds a shown ring a little further before it goes", function()
			local edge = Vector3.new(-1400 + 200 + margin + BackdropNear.HOLD / 2, 5, -1400)
			expect(BackdropNear.keep(box, { edge }, false, false)).to.equal(false)
			expect(BackdropNear.keep(box, { edge }, true, false)).to.equal(true)
		end)
	end)
end
