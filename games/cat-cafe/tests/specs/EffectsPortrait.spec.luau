--!strict
-- A cat alive in a card's picture (Derek 2026-11-03 01:10: the Bellhop Cat card's side to side turn read "kind of
-- laggy and slow"): Logic.portrait keeps the body still and moves the cat as it moves in the world, and the Bellhop Cat
-- rings its bell and tips its cap now and then. Portrait.play needs a real model in a ViewportFrame, so it is checked
-- in Studio. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local p = Presets.portrait
	local b = Presets.bellhop
	local STEP = 1 / 30

	describe("Effects portrait", function()
		it("holds the body still while the head looks about and the cat breathes", function()
			local yaws, bellies = {}, {}
			for t = 0, 12, STEP do
				local o = Logic.portrait("tabby", t, "walk")
				expect(o.bodyY).to.equal(0)
				expect(o.bodyRoll).to.equal(0)
				table.insert(yaws, o.headYaw)
				table.insert(bellies, o.belly)
			end
			table.sort(yaws)
			table.sort(bellies)
			expect(yaws[#yaws] - yaws[1] > math.rad(5)).to.equal(true)
			expect(bellies[#bellies] - bellies[1] > 0).to.equal(true)
		end)

		it(
			"rings the Bellhop Cat's bell every few seconds and tips its cap after each ring",
			function()
				local half = b.ring.seconds / (4 * b.ring.swings) -- a quarter of the first swing, the bell out at its widest
				expect(Logic.portrait(b.catId, p.ringFrom / 2, "walk").bell).to.equal(0)
				local ring = Logic.portrait(b.catId, p.ringFrom + half, "walk").bell
				expect(math.abs(ring) > 0.01).to.equal(true)
				expect(Logic.portrait(b.catId, p.ringFrom + p.every + half, "walk").bell).to.be.near(
					ring,
					1e-6
				)
				expect(Logic.portrait(b.catId, p.ringFrom + b.ring.seconds + 0.01, "walk").bell).to.equal(
					0
				)
				-- the cap tip after the ring moves something the plain idle at that moment does not
				local at = p.ringFrom + b.tipAfter + b.tip.seconds / 2
				local tip = Logic.portrait(b.catId, at, "walk") :: any
				local plain = Logic.portrait("tabby", at, "walk") :: any
				local tipped = false
				for key, value in tip do
					if type(value) == "number" and math.abs(value - plain[key]) > 1e-6 then
						tipped = true
					end
				end
				expect(tipped).to.equal(true)
				-- other cats never ring
				expect(Logic.portrait("tabby", p.ringFrom + half, "walk").bell).to.equal(0)
			end
		)
	end)
end
