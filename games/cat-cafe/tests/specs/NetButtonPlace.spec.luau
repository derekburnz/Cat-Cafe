--!strict
-- UI/Components/NetButtonPlace.luau: the touch Net button sits just left of Roblox's jump button and the Tackle on
-- the thumb's arc up and left of it (F93, #2721).
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

	local function centre(at: Vector2, size: number): Vector2
		return at + Vector2.new(size, size) / 2
	end

	local VIEWPORTS = {
		Vector2.new(844, 390), -- phone
		Vector2.new(667, 375), -- small phone
		Vector2.new(1024, 768), -- tablet
		Vector2.new(1180, 820), -- big tablet
	}

	describe("NetButtonPlace", function()
		it("keeps the jump button formula for a phone and a tablet", function()
			local jumpAt, jumpSize = NetButtonPlace.jump(Vector2.new(844, 390))
			expect(jumpAt).to.equal(Vector2.new(749, 300))
			expect(jumpSize).to.equal(70)
			local _, bigSize = NetButtonPlace.jump(Vector2.new(1024, 768))
			expect(bigSize).to.equal(120)
		end)

		it("puts Net just left of the jump button, centres level (#2721)", function()
			for _, viewport in VIEWPORTS do
				local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
				local at, size = NetButtonPlace.place(viewport)
				expect(size >= 44).to.equal(true) -- a finger's width (Theme.sizes.touchMin)
				expect(at.X + size + NetButtonPlace.GAP).to.equal(jumpAt.X)
				expect(math.abs(centre(at, size).Y - centre(jumpAt, jumpSize).Y) <= 1).to.equal(
					true
				)
				expect(overlaps(at, size, jumpAt, jumpSize)).to.equal(false)
				expect(at.X >= 0 and at.Y >= 0 and at.Y + size <= viewport.Y).to.equal(true)
			end
		end)

		it(
			"puts Tackle on the thumb's arc up and left of the jump button, clear of both (#2721)",
			function()
				for _, viewport in VIEWPORTS do
					local jumpAt, jumpSize = NetButtonPlace.jump(viewport)
					local netAt, netSize = NetButtonPlace.place(viewport)
					local at, size = NetButtonPlace.tackle(viewport)
					expect(size >= 44).to.equal(true)
					expect(size < netSize).to.equal(true) -- Net is the main action
					local fromJump = centre(at, size) - centre(jumpAt, jumpSize)
					expect(fromJump.X < 0 and fromJump.Y < 0).to.equal(true) -- up and left
					expect(fromJump.Magnitude <= jumpSize * 1.8).to.equal(true) -- in the thumb's reach
					expect(centre(at, size).Y < centre(netAt, netSize).Y).to.equal(true) -- above Net
					expect(overlaps(at, size, netAt, netSize)).to.equal(false)
					expect(overlaps(at, size, jumpAt, jumpSize)).to.equal(false)
					expect(at.X >= 0 and at.Y >= 0).to.equal(true)
				end
			end
		)

		it("follows a live jump button wherever it is (#2721)", function()
			local viewport = Vector2.new(844, 390)
			local jumpAt = Vector2.new(700, 280)
			local at, size = NetButtonPlace.place(viewport, jumpAt, 80)
			expect(at.X + size + NetButtonPlace.GAP).to.equal(700)
			expect(math.abs(centre(at, size).Y - 320) <= 1).to.equal(true)
			local tackleAt, tackleSize = NetButtonPlace.tackle(viewport, jumpAt, 80)
			expect(overlaps(tackleAt, tackleSize, jumpAt, 80)).to.equal(false)
			expect(overlaps(tackleAt, tackleSize, at, size)).to.equal(false)
		end)

		it("stays on screen next to a jump button near the edge (#2721)", function()
			local viewport = Vector2.new(400, 300)
			local at, size = NetButtonPlace.place(viewport, Vector2.new(10, 250), 70)
			expect(at.X >= 0 and at.Y >= 0 and at.Y + size <= viewport.Y).to.equal(true)
			local tackleAt = NetButtonPlace.tackle(viewport, Vector2.new(10, 250), 70)
			expect(tackleAt.X >= 0 and tackleAt.Y >= 0).to.equal(true)
		end)
	end)
end
