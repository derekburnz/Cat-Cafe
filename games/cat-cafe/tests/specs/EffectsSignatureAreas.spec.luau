--!strict
-- The area-themed cats' signature effects (F78, data-model 3d v0.13): Jazz Cat's music notes off its saxophone,
-- Balloon Cat's shining balloons and Gnome Cat's lucky sparkles, each with gold colours of its own, and the spare
-- cats they replace keep theirs for players who own one. Written by the vfx-animator for QA to move into tests/specs
-- next to EffectsSignature.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local AREA_CATS = { "neon", "balloon", "gnome" }
	local SPARE_CATS = { "midnight", "aurora", "marshmallow" }
	local PLACES = { Body = true, Head = true, Prop = true, Prop2 = true }

	describe("Effects area-themed signature cats", function()
		it("gives Jazz, Balloon and Gnome Cat a gentle effect, in gold on a gold cat", function()
			for _, catId in AREA_CATS do
				local spec = Presets.signature[catId]
				expect(spec ~= nil).to.equal(true)
				expect(Presets.emitters[spec.emitter] ~= nil).to.equal(true)
				expect(Presets.emitters[spec.emitter].rate <= 2).to.equal(true)
				expect(PLACES[spec.on]).to.equal(true)
				expect(#spec.colors > 0 and #spec.gold > 0).to.equal(true)
				expect(Logic.signatureColors(catId, false)).to.equal(spec.colors)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
			end
			-- the saxophone is Jazz Cat's second prop (the fedora is its first); the three balloons are one prop
			expect(Presets.signature.neon.on).to.equal("Prop2")
			expect(Presets.signature.neon.notes).to.equal(true)
			expect(Presets.signature.balloon.on).to.equal("Prop")
			expect(Presets.signature.balloon.props).to.equal(3)
			expect(Presets.signature.gnome.notes == nil).to.equal(true)
		end)

		it("keeps the spare cats' effects for owned copies", function()
			for _, catId in SPARE_CATS do
				local spec = Presets.signature[catId]
				expect(spec ~= nil).to.equal(true)
				expect(Logic.signatureColors(catId, true)).to.equal(spec.gold)
			end
		end)

		it("floats the music notes up and fades them in and out", function()
			local n = Presets.notes
			expect(n.every > 0 and n.most >= 1 and n.most <= 3).to.equal(true)
			expect(n.fadeIn + n.fade <= n.seconds).to.equal(true)
			expect(n.size > 0 and n.size <= 1).to.equal(true)
			local startAt, startShown = Logic.note(0, 0)
			expect(startAt.Y).to.equal(0)
			expect(startShown).to.equal(0)
			local midAt, midShown = Logic.note(n.seconds / 2, 0)
			expect(midShown).to.equal(1)
			expect(midAt.Y > 0 and midAt.Y < n.rise).to.equal(true)
			local endAt, endShown = Logic.note(n.seconds, 0)
			expect(math.abs(endAt.Y - n.rise) < 1e-6).to.equal(true)
			expect(endShown).to.equal(0)
			-- it never sways further than `sway` from the line it rises on
			for step = 0, 20 do
				local at = Logic.note(n.seconds * step / 20, step)
				expect(math.abs(at.X) <= n.sway + 1e-6).to.equal(true)
			end
		end)
	end)
end
