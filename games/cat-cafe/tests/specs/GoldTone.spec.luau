--!strict
-- #4133: gold cats from their base model, behind the goldTone switch.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GoldTone =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GoldTone")) :: any
	local LiveFlags =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags")) :: any

	describe("GoldTone", function()
		afterEach(function()
			GoldTone.setOpen(nil)
		end)

		it("ships behind an off switch", function()
			expect(LiveFlags.OFF_BY_DEFAULT[GoldTone.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, GoldTone.FLAG) ~= nil).to.equal(true)
		end)

		it("has three golds, light to deep", function()
			expect(GoldTone.toneColor(1) ~= nil).to.equal(true)
			expect(GoldTone.toneColor(3) ~= nil).to.equal(true)
			expect(GoldTone.toneColor(0)).to.equal(nil)
			expect(GoldTone.toneColor(4)).to.equal(nil)
			expect(GoldTone.toneColor("2")).to.equal(nil)
			local light, deep = GoldTone.toneColor(1), GoldTone.toneColor(3)
			expect(light.R + light.G + light.B > deep.R + deep.G + deep.B).to.equal(true)
		end)

		it("looks up the _Gold model while off and the toned base while on", function()
			GoldTone.setOpen(false)
			local names, tone = GoldTone.names("Cat_Gold", "Cat")
			expect(names[1]).to.equal("Cat_Gold")
			expect(names[2]).to.equal("Cat")
			expect(tone).to.equal(false)
			GoldTone.setOpen(true)
			names, tone = GoldTone.names("Cat_Gold", "Cat")
			expect(#names).to.equal(1)
			expect(names[1]).to.equal("Cat")
			expect(tone).to.equal(true)
		end)
	end)
end
