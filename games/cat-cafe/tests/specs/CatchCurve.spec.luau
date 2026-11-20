--!strict
-- shared/Circles' catchCurve (#5392, Design-Agent's catch-curve spec): one smooth curve by net, area tier and coat.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Circles = require(Shared.Circles)
	local Config = require(Shared.Config)

	local function areaOfTier(tier: number): string?
		for _, area in Catalog.areas do
			if area.tier == tier then
				return area.id
			end
		end
		return nil
	end

	describe("catchCurve", function()
		it("never gets easier in a higher area (W and S only fall)", function()
			local curve = Config.CatchCurve
			for tier = 2, #curve.W do
				expect(curve.W[tier] <= curve.W[tier - 1]).to.equal(true)
				expect(curve.S[tier] <= curve.S[tier - 1]).to.equal(true)
			end
			expect(#curve.S).to.equal(#curve.W)
		end)

		it("widens the bands 15% a net level and narrows them by area tier", function()
			local first, late = areaOfTier(1), areaOfTier(10)
			expect(first ~= nil and late ~= nil).to.equal(true)
			local base = Circles.curveWindows(0, "Mythical", first, nil)
			local net3 = Circles.curveWindows(3, "Mythical", first, nil)
			expect(math.abs(net3.good / base.good - 1.45) < 1e-6).to.equal(true)
			local far = Circles.curveWindows(0, "Mythical", late, nil)
			expect(far.good < base.good).to.equal(true)
			local gold = Circles.curveWindows(0, "Mythical", first, "gold")
			expect(gold.good < base.good).to.equal(true)
		end)

		it("keeps the widest band under the ring gap once capped", function()
			local widest = Circles.capped(
				Circles.scaled(
					Circles.curveWindows(5, "Common", areaOfTier(1), nil),
					Config.EarlyCatchWindowScale * 2
				)
			)
			expect(widest.good <= Config.CatchCurve.maxBand).to.equal(true)
			expect(widest.good < Config.CircleGapMin).to.equal(true)
		end)

		it("speeds rings by tier and coat", function()
			local first, late = areaOfTier(1), areaOfTier(10)
			expect(Circles.curveSpeed("Mythical", first, nil)).to.equal(Config.CatchCurve.S[1])
			expect(
				Circles.curveSpeed("Mythical", late, nil)
					< Circles.curveSpeed("Mythical", first, nil)
			).to.equal(true)
			expect(
				Circles.curveSpeed("Common", first, "rainbow")
					< Circles.curveSpeed("Common", first, "gold")
			).to.equal(true)
			expect(Circles.curveSpeed("Common", nil, nil)).to.equal(1)
		end)

		it(
			"gives a bigger Perfect for a better net, more in low areas, never a one press catch",
			function()
				local first, late = areaOfTier(1), areaOfTier(7)
				expect(Circles.perfectGain(0, first, 0, 20)).to.equal(Config.TrustPerfect)
				expect(Circles.perfectGain(3, first, 0, 20)).to.equal(
					math.floor(Config.TrustPerfect * 1.6 + 0.5)
				)
				expect(Circles.perfectGain(3, late, 0, 20) <= Circles.perfectGain(3, first, 0, 20)).to.equal(
					true
				)
				for start = 0, 8 do
					expect(start + Circles.perfectGain(5, first, start, 10) < 10).to.equal(true)
				end
			end
		)

		it("leaves the old ring speed alone without a speed (switch off)", function()
			local roll = function()
				return 0.5
			end
			local area = areaOfTier(6)
			local plain = Circles.schedule("Common", 0, 0, roll, area)
			local expected = Catalog.rarities.Common.shrinkSeconds
				* Circles.ringSpeed("Common", area)
			expect(math.abs(plain[1].shrinkSeconds - expected) < 1e-6).to.equal(true)
		end)
	end)
end
