--!strict
-- UI/Components/SpawnQueue.luau: spawn pop-ups one at a time (#4227).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local SpawnQueue = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("SpawnQueue")
	) :: any
	local Catching = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catching")
	)

	describe("SpawnQueue", function()
		it("knows the spawn lines and their area", function()
			local wave = Catching.waveShoutOut("Mythical", nil, "Park") :: string
			local lucky = Catching.waveShoutOut("Mythical", "gold", "Woods", true) :: string
			local secret = Catching.waveShoutOut("Secret", nil, "Sewer") :: string
			expect(SpawnQueue.isSpawn(wave)).to.equal(true)
			expect(SpawnQueue.isSpawn(secret)).to.equal(true)
			expect(SpawnQueue.isSpawn("Your cafe is now a Bistro!")).to.equal(false)
			expect(SpawnQueue.area(wave)).to.equal("Park")
			expect(SpawnQueue.area(lucky)).to.equal("Woods")
			expect(SpawnQueue.area(secret)).to.equal("Sewer")
		end)

		it("hands them back one at a time, oldest first", function()
			local queue = SpawnQueue.new()
			SpawnQueue.push(queue, "A Mythical cat appeared in the Park!", "Mythical", 0)
			SpawnQueue.push(queue, "A Mythical cat appeared in the Woods!", "Mythical", 1)
			expect(SpawnQueue.waiting(queue, 1)).to.equal(2)
			local text, rarity = SpawnQueue.take(queue, 2)
			expect(text).to.equal("A Mythical cat appeared in the Park!")
			expect(rarity).to.equal("Mythical")
			expect(SpawnQueue.waiting(queue, 2)).to.equal(1)
		end)

		it("merges the same rarity in the same area", function()
			local queue = SpawnQueue.new()
			SpawnQueue.push(queue, "A Mythical cat appeared in the Park!", "Mythical", 0)
			SpawnQueue.push(queue, "A gold Mythical cat appeared in the Park!", "Mythical", 1)
			SpawnQueue.push(queue, "A Secret cat is somewhere in the Park!", "Secret", 1)
			SpawnQueue.push(queue, "A Secret cat is somewhere in the Park!", "Secret", 2)
			expect(SpawnQueue.waiting(queue, 2)).to.equal(2)
			expect((SpawnQueue.take(queue, 3))).to.equal("2 Mythical cats are out in the Park!")
			expect((SpawnQueue.take(queue, 3))).to.equal("2 Secret cats are somewhere in the Park!")
			SpawnQueue.push(queue, "A Rainbow Tabby is out in the Woods!", "Common", 4)
			SpawnQueue.push(queue, "A Rainbow Siamese is out in the Woods!", "Common", 4)
			SpawnQueue.push(queue, "A Common cat appeared in the Woods!", "Common", 4)
			expect((SpawnQueue.take(queue, 5))).to.equal("2 Rainbow cats are out in the Woods!")
			expect((SpawnQueue.take(queue, 5))).to.equal("A Common cat appeared in the Woods!")
		end)

		it("drops lines older than MAX_AGE and keeps at most CAP", function()
			local queue = SpawnQueue.new()
			SpawnQueue.push(queue, "A Mythical cat appeared in the Park!", "Mythical", 0)
			expect((SpawnQueue.take(queue, SpawnQueue.MAX_AGE + 1))).to.equal(nil)
			for index = 1, SpawnQueue.CAP + 2 do
				SpawnQueue.push(
					queue,
					("A Mythical cat appeared in the Area%d!"):format(index),
					"Mythical",
					100
				)
			end
			expect(SpawnQueue.waiting(queue, 100)).to.equal(SpawnQueue.CAP)
			expect((SpawnQueue.take(queue, 100))).to.equal("A Mythical cat appeared in the Area3!")
		end)
	end)
end
