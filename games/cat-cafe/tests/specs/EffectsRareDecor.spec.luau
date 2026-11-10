--!strict
-- The Mythical surfaces read above an Epic (#2734): Midnight Sky, Aurora Sky, the canal floors and Gold Leaf were
-- lifted, and every flash or sweep stays slower than 3 a second for a young audience. Written by the
-- Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects rare decor surfaces", function()
		it("shows the Mythical surfaces clearly but never fully opaque", function()
			local fx = Presets.decorFx
			expect(fx.stars.back >= 20 and fx.stars.side >= 12).to.equal(true)
			expect(fx.stars.shown[2] <= 0.3).to.equal(true)
			for _, shown in { fx.aurora.shown, fx.canal.shown, fx.sheen.shown } do
				expect(shown >= 0.2 and shown <= 0.7).to.equal(true)
			end
		end)

		it("keeps every twinkle, sweep and slide slower than 3 a second", function()
			local fx = Presets.decorFx
			local least = 1 / 3
			expect(fx.stars.twinkle[1] >= least).to.equal(true)
			expect(fx.sheen.seconds >= least).to.equal(true)
			for _, seconds in fx.canal.seconds do
				expect(seconds >= least).to.equal(true)
			end
			for _, seconds in fx.aurora.seconds do
				expect(seconds >= least).to.equal(true)
			end
		end)
	end)
end
