--!strict
-- A cat stuck in a rescue trap wriggles the way its trap holds it (Derek 2026-10-28: a different animation "for
-- whatever cat is stuck in it", "like tail sticking out or butt"). Written by the Animation-Engineer (QA said new
-- specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local s = Presets.motion.stuck

	-- the middle of a burst, and a moment between bursts
	local function during(kind: string): number
		return s[kind].seconds / 2
	end
	local function between(kind: string): number
		return (s[kind].seconds + s[kind].every) / 2
	end

	describe("Effects stuck cats", function()
		it("picks a wriggle for every trap type in the areas, the back end out for most", function()
			for _, trap in
				{
					"trash_bin",
					"trashcan",
					"garbage_bag",
					"shed",
					"hollow_log",
					"drain_pipe",
					"grate",
				}
			do
				expect(Logic.stuckStyle(trap)).to.equal("stuckButt")
			end
			for _, trap in { "tree", "gutter", "bramble_bush" } do
				expect(Logic.stuckStyle(trap)).to.equal("stuckFlip")
			end
		end)

		it("keeps the plain shake for a trap it does not know", function()
			expect(Logic.stuckStyle("volcano")).to.equal("stuck")
			expect(Logic.stuckStyle(nil)).to.equal("stuck")
			expect(Logic.stuckStyle(3)).to.equal("stuck")
		end)

		it("never floats a stuck cat", function()
			for _, style in { "stuck", "stuckButt", "stuckFlip" } do
				expect(Logic.isStuck(style)).to.equal(true)
				expect(Logic.floatShare(style)).to.equal(0)
			end
			expect(Logic.isStuck("stray")).to.equal(false)
		end)

		it(
			"head first in a bin: the back legs paddle in turn and the tail is up, the front paws still",
			function()
				local moved = false
				for t = 0, s.butt.seconds, 0.02 do
					local o = Logic.idle("stuckButt", t, "walk")
					expect(o.pawBL).to.be.near(-o.pawBR, 1e-9)
					expect(o.pawFL).to.equal(0)
					expect(o.tailPitch).to.be.near(math.rad(s.butt.tailUp), 1e-9)
					if math.abs(o.pawBL) > math.rad(s.butt.kick) * 0.5 then
						moved = true
					end
				end
				expect(moved).to.equal(true)
			end
		)

		it(
			"upside down: all four legs pedal, front and back out of step, and the ears go back",
			function()
				local most: { number } = { 0, 0, 0, 0 }
				local legs = { "pawFL", "pawFR", "pawBL", "pawBR" }
				for t = 0, s.flip.seconds, 0.02 do
					local o = Logic.idle("stuckFlip", t, "walk")
					expect(o.pawFL).to.be.near(-o.pawFR, 1e-9)
					expect(o.pawBL).to.be.near(-o.pawBR, 1e-9)
					for i, leg in legs do
						most[i] = math.max(most[i], math.abs(o[leg]))
					end
				end
				for _, angle in most do
					expect(angle > math.rad(s.flip.legs) * 0.5).to.equal(true)
				end
				local o = Logic.idle("stuckFlip", during("flip"), "walk")
				expect(o.earL >= math.rad(s.flip.ears) * 0.9).to.equal(true)
			end
		)

		it("calms between bursts but never goes still", function()
			for _, pair in { { "stuckButt", "butt", "pawBL" }, { "stuckFlip", "flip", "pawFL" } } do
				local style, kind, field = pair[1], pair[2], pair[3]
				local function swing(from: number): number
					local most = 0
					for t = from, from + 1 / s[kind].hz, 0.01 do
						most = math.max(most, math.abs(Logic.idle(style, t, "walk")[field]))
					end
					return most
				end
				local calm, wild = swing(between(kind)), swing(during(kind) - 0.5 / s[kind].hz)
				expect(calm > 0).to.equal(true)
				expect(calm < wild).to.equal(true)
			end
		end)
	end)
end
