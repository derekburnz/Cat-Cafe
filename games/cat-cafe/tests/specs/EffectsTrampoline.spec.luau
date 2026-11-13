--!strict
-- Effects/Trampoline (#3690): the Neighborhood's trampoline bounces this player's character.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Trampoline = require(Effects:WaitForChild("Trampoline")) :: any

	local function landing(over: { [string]: any }): { [string]: any }
		local base: { [string]: any } = {
			feetY = 1.8,
			matTop = 1.755,
			away = 1,
			radius = 2.6,
			sinceLast = 5,
			carrying = false,
			held = false,
		}
		for key, value in over do
			base[key] = value
		end
		return base
	end

	describe("Effects trampoline", function()
		it("knows the trampoline models and their mat", function()
			expect(Trampoline.named("CatCafe_Neighbourhood_SetF85_257_Trampoline")).to.equal(true)
			expect(Trampoline.named("CatCafe_Neighbourhood_SetF85_258_Slide")).to.equal(false)
			expect(Trampoline.named("Trampoline")).to.equal(false)
			expect(Trampoline.isMat(Vector3.new(0.15, 5.2, 5.2))).to.equal(true)
			expect(Trampoline.isMat(Vector3.new(0.25, 1.6, 0.25))).to.equal(false) -- a leg
		end)

		it("bounces a landing from above, over the mat", function()
			expect(Trampoline.bounces(landing({}))).to.equal(true)
			expect(Trampoline.bounces(landing({ feetY = 4 }))).to.equal(true)
		end)

		it("does not bounce a walk into its side, or a touch from under it", function()
			expect(Trampoline.bounces(landing({ feetY = 0 }))).to.equal(false)
			expect(Trampoline.bounces(landing({ away = 4 }))).to.equal(false)
		end)

		it("does not bounce a carrier, a held character, or twice in one landing", function()
			expect(Trampoline.bounces(landing({ carrying = true }))).to.equal(false)
			expect(Trampoline.bounces(landing({ held = true }))).to.equal(false)
			expect(Trampoline.bounces(landing({ sinceLast = Presets.trampoline.gap / 2 }))).to.equal(
				false
			)
		end)

		it("throws a little higher than a jump off the mat, and never far", function()
			local t = Presets.trampoline
			expect(t.height > 7.2).to.equal(true)
			expect(t.height <= 12).to.equal(true)
			local speed = Trampoline.speed(t.height, 196.2)
			expect(math.abs(speed * speed / (2 * 196.2) - t.height) < 0.001).to.equal(true)
			expect(Trampoline.speed(0, 196.2)).to.equal(0)
			expect(Trampoline.speed(9, 0)).to.equal(0)
		end)

		it("dips gently and comes back", function()
			local t = Presets.trampoline
			expect(t.dip <= 0.5).to.equal(true)
			expect(t.down + t.up <= 0.6).to.equal(true)
		end)
	end)
end
