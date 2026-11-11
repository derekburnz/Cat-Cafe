--!strict
-- The station build-in (#2687 part 3): when each part of a camp station drops in and how it falls. StationBuild.luau
-- moves the real station, so how it looks is checked in Studio. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.stationBuild

	describe("Effects station build-in", function()
		it("is off, so a camp station is simply there on a first visit (#3191)", function()
			expect(c.on).to.equal(false)
		end)

		it("starts the bottom piece at once and the top one spread seconds later", function()
			expect(Logic.buildPiece(1, 10, 0, c.spread, c.piece)).to.equal(0)
			expect(Logic.buildPiece(10, 10, c.spread - 0.01, c.spread, c.piece)).to.equal(nil)
			expect(Logic.buildPiece(10, 10, c.spread, c.spread, c.piece)).to.equal(0)
			expect(Logic.buildPiece(10, 10, c.spread + c.piece / 2, c.spread, c.piece)).to.be.near(
				0.5,
				1e-9
			)
			expect(Logic.buildPiece(10, 10, c.spread + c.piece * 2, c.spread, c.piece)).to.equal(1)
		end)

		it("lands a lone piece after one piece's time", function()
			expect(Logic.buildPiece(1, 1, c.piece, c.spread, c.piece)).to.equal(1)
			expect(Logic.buildSeconds(1, c.spread, c.piece)).to.equal(c.piece)
		end)

		it("ends when the last piece lands, inside the reveal's 3 s beat", function()
			local seconds = Logic.buildSeconds(40, c.spread, c.piece)
			expect(seconds).to.be.near(c.spread + c.piece, 1e-9)
			expect(seconds <= 3).to.equal(true)
			expect(Logic.buildPiece(40, 40, seconds, c.spread, c.piece)).to.be.near(1, 1e-9)
		end)

		it("falls the whole way at the start, none at the end, faster as it goes", function()
			expect(Logic.buildFall(0)).to.equal(1)
			expect(Logic.buildFall(1)).to.equal(0)
			expect(Logic.buildFall(-1)).to.equal(1)
			expect(Logic.buildFall(2)).to.equal(0)
			local early = Logic.buildFall(0) - Logic.buildFall(0.25)
			local late = Logic.buildFall(0.75) - Logic.buildFall(1)
			expect(late > early).to.equal(true)
		end)

		it("fades in within the drop and starts above its place", function()
			expect(c.fade > 0 and c.fade <= 1).to.equal(true)
			expect(c.lift[1] > 0 and c.lift[2] >= c.lift[1]).to.equal(true)
			expect(c.calmFade > 0 and c.calmFade <= 3).to.equal(true)
			expect(c.wait > 0).to.equal(true)
		end)
	end)
end
