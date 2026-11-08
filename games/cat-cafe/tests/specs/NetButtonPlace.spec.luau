--!strict
-- UI/Components/NetButtonPlace.luau: the touch Net button sits just above and left of Roblox's jump button (F93,
-- catch-rework.md section 1).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local NetButtonPlace = require(Components:WaitForChild("NetButtonPlace")) :: any

	local function overlaps(aAt: Vector2, aSize: number, bAt: Vector2, bSize: number): boolean
		return aAt.X < bAt.X + bSize
			and bAt.X < aAt.X + aSize
			and aAt.Y < bAt.Y + bSize
			and bAt.Y < aAt.Y + aSize
	end

	describe("NetButtonPlace", function()
		it(
			"sits up and left of the small jump button on a phone, clear of it and on screen",
			function()
				local viewport = Vector2.new(844, 390)
				local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
				expect(jumpAt).to.equal(Vector2.new(749, 300))
				expect(jumpSize).to.equal(70)
				local at, size = NetButtonPlace.place(viewport)
				expect(size >= 44).to.equal(true) -- a finger's width (Theme.sizes.touchMin)
				expect(at.X < jumpAt.X).to.equal(true)
				expect(at.Y + size <= jumpAt.Y).to.equal(true)
				expect(overlaps(at, size, jumpAt, jumpSize)).to.equal(false)
				expect(at.X >= 0 and at.Y >= 0).to.equal(true)
			end
		)

		it("follows the bigger jump button on a tablet", function()
			local viewport = Vector2.new(1024, 768)
			local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
			expect(jumpSize).to.equal(120)
			local at, size = NetButtonPlace.place(viewport)
			expect(size).to.equal(96)
			expect(at.Y + size <= jumpAt.Y).to.equal(true)
			expect(at.X < jumpAt.X).to.equal(true)
			expect(overlaps(at, size, jumpAt, jumpSize)).to.equal(false)
		end)

		it("puts the touch Tackle button left of the Net button, level with it (#2510)", function()
			for _, viewport in
				{ Vector2.new(844, 390), Vector2.new(667, 375), Vector2.new(1180, 820) }
			do
				local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
				local netAt, netSize = NetButtonPlace.place(viewport)
				local at, size = NetButtonPlace.tackle(viewport)
				expect(size).to.equal(netSize)
				expect(size >= 44).to.equal(true)
				expect(at.Y).to.equal(netAt.Y)
				expect(at.X + size + NetButtonPlace.GAP).to.equal(netAt.X)
				expect(overlaps(at, size, netAt, netSize)).to.equal(false)
				expect(overlaps(at, size, jumpAt, jumpSize)).to.equal(false)
				expect(at.X >= 0 and at.Y >= 0).to.equal(true)
			end
		end)
	end)
end
