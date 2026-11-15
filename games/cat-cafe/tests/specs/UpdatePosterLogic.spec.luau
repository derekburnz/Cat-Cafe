--!strict
-- UI/Components/UpdatePosterLogic.luau: the Town Square update poster's words (#4362).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("UpdatePosterLogic")
	) :: any
	local Config = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
	) :: any

	local list = {
		{ id = "111", startsAt = 1000 },
		{ id = "333", startsAt = 5000, name = "LATER" },
		{ id = "222", startsAt = 3000, name = "3 NEW WORLDS", poster = "rbxassetid://1" },
		{ id = "abc", startsAt = 2000, name = "BAD ID" },
	}

	describe("UpdatePosterLogic.next", function()
		it("picks the listed Event that starts first of those still ahead", function()
			expect(Logic.next(list, 0).id).to.equal("111")
			expect(Logic.next(list, 1000).id).to.equal("222")
			expect(Logic.next(list, 2999).id).to.equal("222")
			expect(Logic.next(list, 3000).id).to.equal("333")
		end)

		it("has nothing once every Event has started, or with no list", function()
			expect(Logic.next(list, 5000)).to.equal(nil)
			expect(Logic.next(nil, 0)).to.equal(nil)
			expect(Logic.next({}, 0)).to.equal(nil)
		end)
	end)

	describe("UpdatePosterLogic.countdown", function()
		it("reads days, then hours and minutes, then minutes", function()
			expect(Logic.countdown(3 * 86400 + 5, 0)).to.equal("Starts in 3 days")
			expect(Logic.countdown(18 * 3600 + 22 * 60 + 9, 0)).to.equal("Starts in 18 h 22 min")
			expect(Logic.countdown(12 * 60 + 59, 0)).to.equal("Starts in 12 min")
			expect(Logic.countdown(59, 0)).to.equal("Starts in under a minute")
			expect(Logic.countdown(100, 500)).to.equal("Starts in under a minute")
		end)
	end)

	describe("UpdatePosterLogic.view", function()
		it("carries the name, picture and countdown of the next Event", function()
			local view = Logic.view(list, 2400)
			expect(view.id).to.equal("222")
			expect(view.name).to.equal("3 NEW WORLDS")
			expect(view.poster).to.equal("rbxassetid://1")
			expect(view.countdown).to.equal("Starts in 10 min")
		end)

		it("falls back to NEW UPDATE and no picture", function()
			local view = Logic.view(list, 0)
			expect(view.name).to.equal(Logic.NEW_UPDATE)
			expect(view.poster).to.equal(nil)
			expect(Logic.view(list, 9999)).to.equal(nil)
		end)

		it("reads the game's own list: every picture is an asset id and every name is short", function()
			for _, entry in Config.UpdateEvents do
				if entry.poster ~= nil then
					expect(string.match(entry.poster, "^rbxassetid://%d+$") ~= nil).to.equal(true)
				end
				if entry.name ~= nil then
					expect(#entry.name <= 24).to.equal(true)
				end
			end
			-- 3 New Worlds is on the poster until Sunday 2026-11-15 20:00 UTC
			local view = Logic.view(Config.UpdateEvents, 1794772800 - 3600)
			expect(view.name).to.equal("3 NEW WORLDS")
			expect(view.countdown).to.equal("Starts in 1 h 0 min")
		end)
	end)
end
