--!strict
-- #5572 the Picnic Party's timelines and words (Effects/PicnicLogic). Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local L = require(Effects:WaitForChild("PicnicLogic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local p = Presets.picnicParty

	describe("Effects Picnic Party", function()
		it("picks the look from the switch, the timer and ready", function()
			expect(L.phase(false, true, 200, 100)).to.equal("off")
			expect(L.phase(true, true, nil, 100)).to.equal("ready")
			expect(L.phase(true, false, nil, 100)).to.equal("waiting")
			expect(L.phase(true, false, 200, 100)).to.equal("party")
			expect(L.phase(true, true, 50, 100)).to.equal("ready") -- a past end is over
		end)

		it("says the words Design set", function()
			expect(L.sign("ready", nil, 0)).to.equal("PICNIC READY")
			expect(L.sign("waiting", 720, 0)).to.equal("Next picnic 12 m")
			expect(L.sign("waiting", 30, 0)).to.equal("Next picnic 30 s")
			expect(L.sign("waiting", 3900, 0)).to.equal("Next picnic 1 h 5 m")
			expect(L.sign("waiting", nil, 0)).to.equal("Next picnic")
			expect(L.sign("waiting", 0, 5)).never.to.be.ok()
			expect(L.sign("party", nil, 0)).never.to.be.ok()
			expect(L.wait(719.2)).to.equal("12 m")
		end)

		it("wobbles now and then, still between, under 3 swings a second", function()
			local w = p.wobble
			expect(L.wobble(w.seconds + 0.1, w.every, w.seconds, w.degrees, w.wiggles)).to.equal(0)
			expect(math.abs(L.wobble(w.seconds / 8, w.every, w.seconds, w.degrees, w.wiggles)) > 0).to.equal(
				true
			)
			expect(
				math.abs(
					L.wobble(w.every + w.seconds / 8, w.every, w.seconds, w.degrees, w.wiggles)
				) > 0
			).to.equal(true)
			expect(w.wiggles / w.seconds <= 3.5).to.equal(true)
			expect(w.degrees <= 8).to.equal(true)
		end)

		it(
			"pops in about 1.5 s: lid first, then the blanket, then the treats one by one",
			function()
				expect(L.popLength()).to.be.near(1.5, 0.11)
				local lid, roll, treats = L.pop(0, false)
				expect(lid).to.equal(0)
				expect(roll).to.equal(0)
				expect(treats[1]).never.to.be.ok()
				lid, roll = L.pop(p.pop.lidSeconds, false)
				expect(lid).to.equal(1)
				expect(roll > 0 and roll < 1).to.equal(true)
				local _, _, mid = L.pop(p.pop.treatAt + 0.01, false)
				expect(mid[1] ~= nil and mid[2] == nil).to.equal(true)
				local _, doneRoll, done = L.pop(L.popLength(), false)
				expect(doneRoll).to.equal(1)
				for i = 1, #p.treats do
					expect(done[i]).to.equal(1)
				end
			end
		)

		it("lays it all out at once with Reduce Motion", function()
			local lid, roll, treats = L.pop(0, true)
			expect(lid).to.equal(1)
			expect(roll).to.equal(1)
			expect(treats[3]).to.equal(1)
		end)

		it("packs away: things fade, the blanket rolls up, the lid shuts last", function()
			local gone, out, lid = L.pack(0)
			expect(gone).to.equal(0)
			expect(out).to.equal(1)
			expect(lid).to.equal(1)
			gone, out, lid = L.pack(p.pack.seconds)
			expect(gone).to.equal(1)
			expect(out).to.equal(0)
			expect(lid).to.equal(0)
		end)

		it("bounces a treat and lands it flat", function()
			expect(L.arc(0, 2)).to.equal(0)
			expect(L.arc(0.4, 2)).to.be.near(2, 1e-6)
			expect(L.arc(1, 2)).to.be.near(0, 1e-6)
			expect(L.arc(0.9, 2) > 0).to.equal(true)
		end)
	end)
end
