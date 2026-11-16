--!strict
-- #4470: the spawn shout-outs show with no sound (Audio/Logic.isSpawnLine), every line UI/Components/SpawnQueue
-- writes or merges, while catch shout-outs keep their sting. Written by Motion-FX-Agent.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(Client:WaitForChild("Audio"):WaitForChild("Logic")) :: any
	local SpawnQueue = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("SpawnQueue")
	) :: any

	describe("Audio spawn shout-outs are silent", function()
		it("knows every spawn line, single and merged", function()
			for _, text in
				{
					"A Mythical cat appeared in the Park!",
					"A Secret cat is somewhere in the Woods!",
					"A Mythical cat is out in the Castle on a Lucky Day!",
					"2 Mythical cats are out in the Park!",
					"3 Secret cats are somewhere in the Woods!",
				}
			do
				expect(Logic.isSpawnLine(text)).to.equal(true)
			end
		end)

		it("agrees with the spawn queue on single lines", function()
			for _, text in
				{ "A Mythical cat appeared in the Park!", "Sam secured a Mythical Jazz Cat!" }
			do
				expect(Logic.isSpawnLine(text)).to.equal(SpawnQueue.isSpawn(text))
			end
		end)

		it("leaves catch shout-outs and odd values alone", function()
			expect(Logic.isSpawnLine("Sam secured a Mythical Jazz Cat!")).to.equal(false)
			expect(Logic.isSpawnLine("Sam found the Mythical Midnight Sky!")).to.equal(false)
			expect(Logic.isSpawnLine(nil)).to.equal(false)
			expect(Logic.isSpawnLine(5)).to.equal(false)
		end)
	end)
end
