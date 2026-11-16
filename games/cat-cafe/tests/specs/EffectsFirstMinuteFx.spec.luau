--!strict
-- Effects/FirstMinuteFx cheers the account's first net catch and sparkles its first bait card.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FirstMinuteFx =
		require(Client:WaitForChild("Effects"):WaitForChild("FirstMinuteFx")) :: any

	describe("FirstMinuteFx", function()
		it("cheers the account's first net catch, once", function()
			expect(FirstMinuteFx.cheers(0, false)).to.equal(true)
			expect(FirstMinuteFx.cheers(1, false)).to.equal(true)
			expect(FirstMinuteFx.cheers(2, false)).to.equal(true) -- bowl first: the bowl cat, then this catch
			expect(FirstMinuteFx.cheers(1, true)).to.equal(false)
		end)
		it("stays quiet on older saves or before the save is known", function()
			expect(FirstMinuteFx.cheers(3, false)).to.equal(false)
			expect(FirstMinuteFx.cheers(400, false)).to.equal(false)
			expect(FirstMinuteFx.cheers(nil, false)).to.equal(false)
		end)
		it("sparkles only the account's first bait card, once", function()
			expect(FirstMinuteFx.firstCard(0, 1, 0, false)).to.equal(true)
			expect(FirstMinuteFx.firstCard(0, 1, nil, false)).to.equal(true)
			expect(FirstMinuteFx.firstCard(0, 1, 0, true)).to.equal(false)
			expect(FirstMinuteFx.firstCard(0, 2, 0, false)).to.equal(false)
			expect(FirstMinuteFx.firstCard(0, 1, 1, false)).to.equal(false)
			expect(FirstMinuteFx.firstCard(0, nil, 0, false)).to.equal(false)
			expect(FirstMinuteFx.firstCard(5, 0, 0, false)).to.equal(false) -- a veteran's first bowl use
			expect(FirstMinuteFx.firstCard(nil, 1, 0, false)).to.equal(false)
		end)
	end)
end
