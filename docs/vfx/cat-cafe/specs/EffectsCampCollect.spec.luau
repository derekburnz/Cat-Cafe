--!strict
-- The camp extras' collect bursts (F100, camp-extras.md section 2): a small burst and a ring at each extra when you
-- collect it, timed to Animation-Engineer's rod and lid. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

	local IDS = { "picnic", "pond", "lostFound", "yardSale" }

	describe("Effects CampCollect", function()
		it("has a burst for every camp extra, inside the phone's burst budget", function()
			local extras = Presets.campCollect.extras
			for _, id in IDS do
				local def = extras[id]
				expect(def ~= nil).to.equal(true)
				expect(#def.bursts >= 1).to.equal(true)
				for _, burst in def.bursts do
					local emitter = Presets.emitters[burst.emitter]
					expect(emitter ~= nil).to.equal(true)
					expect(emitter.rate).to.equal(0) -- bursts only
					expect(burst.count > 0 and burst.count <= Presets.budget.low.maxBurst).to.equal(
						true
					)
				end
				expect(def.ring > 0 and def.ring <= 4).to.equal(true) -- about the extra's size, never past it
				expect(def.above >= 0 and def.above <= 1).to.equal(true)
			end
		end)

		it("gives each extra its own ring colour", function()
			local extras = Presets.campCollect.extras
			for i, a in IDS do
				for j, b in IDS do
					if i < j then
						expect(extras[a].colour ~= extras[b].colour).to.equal(true)
					end
				end
			end
		end)

		it("waits for the rod's tug and the lid's lift, and no longer", function()
			local extras = Presets.campCollect.extras
			local rod = Presets.campExtras.rod.keys
			local lid = Presets.campExtras.lid.pop
			-- the pond splashes as the rod tugs at the bite, before it lifts the fish out
			expect(extras.pond.delay).to.equal(rod[2][1])
			expect(extras.pond.delay < rod[3][1]).to.equal(true)
			-- the Lost and Found's puff comes as the lid is up, before it shuts
			expect(extras.lostFound.delay).to.equal(lid[2][1])
			expect(extras.lostFound.delay < Logic.keyedSeconds(lid)).to.equal(true)
			expect(extras.picnic.delay).to.equal(0)
			expect(extras.yardSale.delay).to.equal(0)
		end)

		it("plays wherever you can collect from", function()
			local c = Presets.campCollect
			expect(c.within >= Config.CampExtraRangeStuds * 2).to.equal(true)
			expect(c.reach >= Config.CampExtraRangeStuds).to.equal(true)
			expect(c.ringSeconds > 0 and c.ringSeconds <= 1).to.equal(true)
		end)
	end)
end
