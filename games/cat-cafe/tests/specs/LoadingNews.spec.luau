--!strict
-- UI/Components/LoadingNews.luau: the WHAT'S NEW card on the cute loading screen (#4314).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local LoadingNews = require(Components:WaitForChild("LoadingNews")) :: any

	describe("LoadingNews.whenText", function()
		it("names the day and time in Eastern time before, and Out now! after", function()
			expect(LoadingNews.whenText(1794772800, 1794700000)).to.equal("Sunday 3 PM ET")
			expect(LoadingNews.whenText(1794799800, 1794700000)).to.equal("Sunday 10:30 PM ET")
			expect(LoadingNews.whenText(1794704400, 1794700000)).to.equal("Saturday 8 PM ET")
			expect(LoadingNews.whenText(1794772800, 1794772800)).to.equal("Out now!")
			expect(LoadingNews.whenText(nil, 0)).to.equal("Out now!")
			-- past its time with a switch still off: never "Out now!" (Review-QA on #4321)
			expect(LoadingNews.whenText(1794772800, 1794800000, false)).to.equal("Coming soon!")
			expect(LoadingNews.whenText(1794772800, 1794800000, true)).to.equal("Out now!")
			expect(LoadingNews.whenText(1794772800, 1794700000, false)).to.equal("Sunday 3 PM ET")
		end)
		it("is live only with every switch on", function()
			local entry = { flags = { "a", "b" } }
			expect(LoadingNews.live(entry, function(key)
				return key == "a"
			end)).to.equal(false)
			expect(LoadingNews.live(entry, function()
				return true
			end)).to.equal(true)
			expect(LoadingNews.live({}, function()
				return false
			end)).to.equal(true)
			for _, news in LoadingNews.ENTRIES do
				if news.at ~= nil then
					expect(news.flags ~= nil and #news.flags > 0).to.equal(true)
				end
			end
		end)
	end)

	describe("LoadingNews.pick", function()
		it("turns through every entry and starts again", function()
			local count = #LoadingNews.ENTRIES
			local _, first = LoadingNews.pick(0)
			expect(first).to.equal(1)
			local _, second = LoadingNews.pick(LoadingNews.SECONDS + 0.01)
			expect(second).to.equal(2)
			local _, again = LoadingNews.pick(LoadingNews.SECONDS * count + 0.01)
			expect(again).to.equal(1)
			local _, early = LoadingNews.pick(-5)
			expect(early).to.equal(1)
		end)
	end)

	describe("LoadingNews.ENTRIES", function()
		it(
			"gives each a short title, one line and a picture; the Secret one shapes only",
			function()
				for _, entry in LoadingNews.ENTRIES do
					expect(#entry.title <= 16).to.equal(true)
					expect(#entry.line <= 52).to.equal(true)
					expect(
						entry.secret == true
							or (entry.tiles ~= nil and #entry.tiles >= 1 and #entry.tiles <= 3)
					).to.equal(true)
					if entry.secret then
						expect(entry.tiles).to.equal(nil)
					end
				end
			end
		)
	end)

	describe("LoadingNews.tip", function()
		it("names the button for the device in hand", function()
			expect(LoadingNews.tip("touch"):find("tap CATCH", 1, true) ~= nil).to.equal(true)
			expect(LoadingNews.tip("gamepad"):find("hold X", 1, true) ~= nil).to.equal(true)
			expect(LoadingNews.tip("keyboard"):find("hold E", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
