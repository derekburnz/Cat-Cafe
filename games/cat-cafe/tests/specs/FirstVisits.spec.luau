--!strict
-- FirstVisits.luau (#2792, retention-ideas.md section 2): a new account's first rich customer, Mystery Visitor and Cat
-- Collector come on a fixed schedule in its first minutes of play, once each, and stay longer.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local FirstVisits = require(Shared.FirstVisits)

	describe("FirstVisits (#2792)", function()
		it(
			"comes at about 3, 6 and 9 minutes, inside a 30 minute window, and stays 5 minutes",
			function()
				expect(Config.FirstVisitAt :: any).to.deepEqual({
					rich = 180,
					mystery = 360,
					collector = 540,
				})
				expect(Config.FirstVisitWindowSeconds).to.equal(1800)
				expect(Config.FirstVisitStaySeconds).to.equal(300)
				for _, kind in FirstVisits.KINDS do
					expect((Config.FirstVisitAt :: any)[kind] < Config.FirstVisitWindowSeconds).to.equal(
						true
					)
				end
			end
		)

		it("sanitize keeps only the known kinds set to true", function()
			expect(FirstVisits.sanitize(nil) :: any).to.deepEqual({})
			expect(FirstVisits.sanitize("rich") :: any).to.deepEqual({})
			expect(
				FirstVisits.sanitize({ rich = true, mystery = 1, collector = false, other = true }) :: any
			).to.deepEqual({
				rich = true,
			})
		end)

		it("is due from its time until it is met, inside the window only", function()
			local save = FirstVisits.sanitize(nil)
			expect(FirstVisits.due(save, "rich", 179)).to.equal(false)
			expect(FirstVisits.due(save, "rich", 180)).to.equal(true)
			expect(FirstVisits.due(save, "mystery", 300)).to.equal(false)
			expect(FirstVisits.due(save, "mystery", 360)).to.equal(true)
			expect(FirstVisits.due(save, "collector", 540)).to.equal(true)
			expect(FirstVisits.due(save, "collector", 1801)).to.equal(false)
			expect(FirstVisits.mark(save, "rich")).to.equal(true)
			expect(FirstVisits.mark(save, "rich")).to.equal(false)
			expect(FirstVisits.due(save, "rich", 400)).to.equal(false)
		end)

		it(
			"a visitor that came early by chance counts as met; an older account is never pending",
			function()
				local save = FirstVisits.sanitize(nil)
				expect(FirstVisits.pending(save, "collector", 100)).to.equal(true)
				FirstVisits.mark(save, "collector")
				expect(FirstVisits.pending(save, "collector", 100)).to.equal(false)
				expect(FirstVisits.due(save, "collector", 600)).to.equal(false)
				expect(FirstVisits.pending(FirstVisits.sanitize(nil), "rich", 5000)).to.equal(false)
			end
		)

		it("a first visit stays FirstVisitStaySeconds, never shorter than a normal one", function()
			expect(FirstVisits.stay(true, 90)).to.equal(300)
			expect(FirstVisits.stay(false, 90)).to.equal(90)
			expect(FirstVisits.stay(true, 400)).to.equal(400)
		end)
	end)
end
