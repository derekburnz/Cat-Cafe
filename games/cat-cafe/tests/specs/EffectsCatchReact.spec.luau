--!strict
-- Catch v3 on the cat (catch-rework.md section 7, #1892): the reaction to each judged ring, the net wrap's two
-- wobbles and the mood stances. All pure; the cat answering a real catch is a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local r = Presets.catchReact

	local function at(kind: string, alpha: number): any
		local o = Logic.blank()
		o.tailYaw = 0.3
		Logic.catchReact(o, kind, alpha)
		return o
	end

	describe("Effects catch v3 reactions", function()
		it("picks the reaction from the grade and the ring's kind", function()
			expect(Logic.catchReactFor("perfect", "single")).to.equal("perk")
			expect(Logic.catchReactFor("good", nil)).to.equal("perk")
			expect(Logic.catchReactFor("left", "paw")).to.equal("perk")
			expect(Logic.catchReactFor("miss", "single")).to.equal("wriggle")
			expect(Logic.catchReactFor("miss", nil)).to.equal("wriggle")
			expect(Logic.catchReactFor("miss", "paw")).to.equal("swat")
			expect(Logic.catchReactFor("bogus", "paw")).to.equal(nil)
			expect(Logic.catchReactFor(nil, nil)).to.equal(nil)
		end)

		it("perks the ears forward on a hit and swats with the right front paw", function()
			local perk = at("perk", 0.5)
			expect(perk.earL).to.be.near(-math.rad(r.perk.ears), 1e-9)
			expect(perk.headPitch > 0).to.equal(true)
			local swat = at("swat", r.swat.up)
			expect(swat.pawFR).to.be.near(math.rad(r.swat.paw), 1e-9)
			expect(swat.pawFL).to.equal(0)
		end)

		it("wriggles side to side on a Miss", function()
			local left, right = false, false
			for i = 1, 99 do
				local roll = at("wriggle", i / 100).bodyRoll
				left = left or roll < -0.01
				right = right or roll > 0.01
			end
			expect(left and right).to.equal(true)
		end)

		it("leaves the cat as it was before and after every reaction", function()
			for _, kind in { "perk", "wriggle", "swat", "wrap" } do
				for _, alpha in { -0.1, 1, 1.5 } do
					local o = at(kind, alpha)
					expect(o.bodyRoll).to.equal(0)
					expect(o.pawFR).to.equal(0)
					expect(o.earL).to.equal(0)
					expect(o.tailYaw).to.equal(0.3)
					expect(o.sink).to.equal(0)
				end
				local o = at(kind, 0.999)
				expect(math.abs(o.bodyRoll) < 0.05).to.equal(true)
			end
		end)

		it("closes the net onto the cat and wobbles it twice in the wrap's seconds", function()
			expect(r.wrap.seconds).to.equal(0.6)
			local open = Logic.netWrap(0)
			expect(open).to.be.near(r.wrap.open, 1e-9)
			local snug = Logic.netWrap(r.wrap.settle)
			expect(snug).to.be.near(r.wrap.snug, 1e-9)
			local sign, flips = 0, 0
			for i = 1, 99 do
				local _, rock = Logic.netWrap(i / 100)
				local now = if rock > 1e-6 then 1 elseif rock < -1e-6 then -1 else 0
				if now ~= 0 and sign ~= 0 and now ~= sign then
					flips += 1
				end
				if now ~= 0 then
					sign = now
				end
			end
			expect(flips).to.equal(r.wrap.wobbles * 2 - 1)
		end)

		it("curls a Sleepy stray up until a catch of it starts", function()
			expect(Logic.moodStyle("Sleepy", false)).to.equal("nap")
			expect(Logic.moodStyle("Sleepy", true)).to.equal(nil)
			expect(Logic.moodStyle("Curious", false)).to.equal(nil)
			expect(Logic.moodStyle(nil, false)).to.equal(nil)
		end)

		it("crouches a Skittish stray and tips a Curious one's head", function()
			local skittish = Logic.blank()
			Logic.moodLayer(skittish, "Skittish", 0, 1)
			expect(skittish.sink).to.be.near(r.mood.skittish.crouch, 1e-9)
			expect(skittish.earL > 0).to.equal(true)
			local curious = Logic.blank()
			Logic.moodLayer(curious, "Curious", r.mood.curious.seconds / 4, 1)
			expect(curious.headRoll).to.be.near(math.rad(r.mood.curious.tilt), 1e-6)
			expect(curious.earL < 0).to.equal(true)
			local none = Logic.blank()
			Logic.moodLayer(none, "Skittish", 0, 0)
			expect(none.sink).to.equal(0)
		end)
	end)
end
