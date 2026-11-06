--!strict
-- UI/Components/PityLogic.luau: the Town Square pity sign's words (#1572, luck-and-rare-moments.md 1h).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local PityLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("PityLogic")
	) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Pity = require(Shared.Pity)

	local function state(extra: { [string]: any }?): any
		local s: { [string]: any } = { kind = "", area = "", state = "", winner = "" }
		for key, value in extra or {} do
			s[key] = value
		end
		return s
	end

	describe("PityLogic.view", function()
		it("counts down to the next Legendary and the next Mythical on the shared clock", function()
			local t = 100000
			local view = PityLogic.view(t, nil)
			local legendaryAt = Pity.nextAt(t, "Legendary")
			local mythicalAt = Pity.nextAt(t, "Mythical")
			expect(view.legendary).to.equal(
				"Legendary cat in " .. Pity.countdownText(legendaryAt - t)
			)
			expect(view.mythical).to.equal("Mythical cat in " .. Pity.countdownText(mythicalAt - t))
			expect(view.status).to.equal(nil)
		end)

		it("names the area while a pity cat is out, in its kind's colour", function()
			local woods = Catalog.getArea("woods")
			local view =
				PityLogic.view(100000, state({ kind = "Mythical", area = "woods", state = "out" }))
			expect(view.status).to.equal(("Now in the %s!"):format(woods and woods.name or "woods"))
			expect(view.statusKind).to.equal("Mythical")
		end)

		it("names the winner after the catch, and nothing when none is out", function()
			local caught = PityLogic.view(
				100000,
				state({ kind = "Legendary", area = "park", state = "caught", winner = "Sam" })
			)
			expect(caught.status).to.equal("Caught by Sam")
			expect(caught.statusKind).to.equal("Legendary")
			expect(PityLogic.view(100000, state()).status).to.equal(nil)
			expect(PityLogic.view(100000, state({ state = "caught" })).status).to.equal(nil)
		end)
	end)
end
