--!strict
-- Upright working cats (F25, engineer PR #159) in the client Effects module: legs found in the body's own axes,
-- and the standing doze at night in place of the curl. Written by the vfx-animator (PR #164); the "edges (QA)"
-- block is QA's. The leg cases use the exported Bengal's numbers, in its body part's axes (body 0.855 x 0.665 x
-- 1.47).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local BODY = Vector3.new(0.855, 0.665, 1.47)
	local LEG = Vector3.new(0.28, 0.5, 0.28)

	describe("Effects upright cats", function()
		it("finds the four legs in the body's own axes", function()
			expect(Logic.legOf(Vector3.new(0.266, -0.5125, -0.5), LEG, BODY)).to.equal("pawFR")
			expect(Logic.legOf(Vector3.new(-0.266, -0.5125, -0.5), LEG, BODY)).to.equal("pawFL")
			expect(Logic.legOf(Vector3.new(0.266, -0.5125, 0.45), LEG, BODY)).to.equal("pawBR")
			expect(Logic.legOf(Vector3.new(-0.266, -0.5125, 0.45), LEG, BODY)).to.equal("pawBL")
		end)

		it("takes no marking, collar bead or flat piece for a leg", function()
			-- a stripe on the flank: tall and thin, but up beside the body
			expect(
				Logic.legOf(Vector3.new(0.4375, 0.1375, 0.2), Vector3.new(0.04, 0.18, 0.18), BODY)
			).to.equal(nil)
			-- the low bead of a collar ring: under the body, but on the middle line
			expect(
				Logic.legOf(Vector3.new(0, -0.3725, -0.785), Vector3.new(0.16, 0.16, 0.12), BODY)
			).to.equal(nil)
			-- a flat piece under the body: wider than it is tall
			expect(Logic.legOf(Vector3.new(0.2, -0.45, 0), Vector3.new(0.3, 0.1, 0.3), BODY)).to.equal(
				nil
			)
		end)

		it("dozes on its feet: head down, no sink, legs straight", function()
			local d = Presets.motion.doze
			for t = 0, 8, 0.1 do
				local o = Logic.idle("doze", t)
				expect(o.sink).to.equal(0)
				expect(o.pawFL == 0 and o.pawFR == 0 and o.pawBL == 0 and o.pawBR == 0).to.equal(
					true
				)
				local droop = -math.deg(o.headPitch)
				expect(droop >= d.headDroop - d.nod - 1e-6 and droop <= d.headDroop + d.nod + 1e-6).to.equal(
					true
				)
				expect(math.abs(o.bodyRoll) <= math.rad(d.sway) + 1e-9).to.equal(true)
				expect(o.bodyY >= 0 and o.bodyY <= d.breathe + 1e-9).to.equal(true)
			end
			-- settling from a role idle into the doze never sinks either
			local mid = Logic.mix(Logic.idle("barista", 3), Logic.idle("doze", 3), 0.5)
			expect(mid.sink).to.equal(0)
		end)
	end)

	-- QA: every role a working cat stands at settles into the doze without sinking, each role keeps its own idle,
	-- and the standing doze is never the curl.
	describe("edges (QA)", function()
		local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Catalog)
		local m = Presets.motion

		local function roles(): { string }
			local seen: { [string]: boolean } = {}
			local list = {}
			for _, spot in Catalog.spots do
				if not seen[spot.spotType] then
					seen[spot.spotType] = true
					table.insert(list, spot.spotType)
				end
			end
			return list
		end

		it("every role idle blends into the doze and back with no sink", function()
			local styles = roles()
			table.insert(styles, "sit")
			for _, style in styles do
				for t = 0, 8, 0.25 do
					local role, doze = Logic.idle(style, t), Logic.idle("doze", t)
					for _, k in { 0, 0.25, 0.5, 0.75, 1 } do
						expect(Logic.mix(role, doze, k).sink).to.equal(0)
						expect(Logic.mix(doze, role, k).sink).to.equal(0)
					end
				end
			end
		end)

		it("every role with an outfit has its own idle, not the plain sit", function()
			for _, role in roles() do
				expect(Catalog.roleOutfits[role]).to.be.ok()
				local differs = false
				for t = 0, 8, 0.1 do
					local o, sit = Logic.idle(role, t), Logic.idle("sit", t)
					for key, value in o :: any do
						if math.abs(value - (sit :: any)[key]) > 1e-6 then
							differs = true
						end
					end
				end
				if not differs then
					error(string.format("the %s idle is the plain sit", role))
				end
			end
		end)

		it("the doze keeps the head straight and the tail hanging, unlike the nap", function()
			local swish = math.rad(m.tailSwish.degrees)
			for t = 0, 8, 0.1 do
				local doze, nap = Logic.idle("doze", t), Logic.idle("nap", t)
				expect(doze.headYaw).to.equal(0)
				expect(math.abs(doze.tailYaw) <= swish * m.doze.tail + 1e-9).to.equal(true)
				expect(nap.sink > 0 and nap.headYaw ~= 0).to.equal(true)
			end
		end)

		it("legs mirror left to right and front to back", function()
			local swap = {
				x = { pawFL = "pawFR", pawFR = "pawFL", pawBL = "pawBR", pawBR = "pawBL" },
				z = { pawFL = "pawBL", pawBL = "pawFL", pawFR = "pawBR", pawBR = "pawFR" },
			}
			for x = 0.1, 0.4, 0.1 do
				for z = 0.1, 0.6, 0.1 do
					for _, y in { -0.5125, -0.45, -0.3 } do
						local leg = Logic.legOf(Vector3.new(x, y, z), LEG, BODY)
						local left = Logic.legOf(Vector3.new(-x, y, z), LEG, BODY)
						local front = Logic.legOf(Vector3.new(x, y, -z), LEG, BODY)
						if leg == nil then
							expect(left).to.equal(nil)
							expect(front).to.equal(nil)
						else
							expect(left).to.equal(swap.x[leg])
							expect(front).to.equal(swap.z[leg])
						end
					end
				end
			end
		end)
	end)
end
