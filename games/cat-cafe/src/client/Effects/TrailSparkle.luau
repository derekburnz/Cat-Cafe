--!strict
-- A brighter guide trail (#3022, the second cat: only 51 of 139 players reached the trail). UI's GuideTrail lays
-- flat gold dots on the ground from the player to the tutorial's target, the waiting stray among them. Here, every
-- `every`th dot (by the device budget) also sends up a few soft sparkles in its own colour, so the path reads from
-- farther off and between buildings. GuideTrail itself is untouched: this only adds emitters to its dots while its
-- folder is in the Workspace. Reduce Motion keeps the sparkles (they drift, they don't flash); Low performance
-- drops them. On this client only; listening only. Numbers in Presets.trailSparkle.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local TrailSparkle = {}

local started = false
-- each watched trail folder and its ChildAdded hook; a folder taken out of the Workspace is dropped, and its next
-- show (Workspace.ChildAdded) watches it again
local folders: { [Instance]: RBXScriptConnection } = {}

-- Whether the dot at `index` (from 1, nearest the player first) carries sparkles.
function TrailSparkle.carries(index: number, every: number, lowPerformance: boolean): boolean
	if lowPerformance or every < 1 then
		return false
	end
	return (index - 1) % every == 0
end

local function refresh(folder: Instance)
	local p = Presets.trailSparkle
	local every = if Context.device == "low" then p.everyLow else p.every
	local index = 0
	for _, child in folder:GetChildren() do
		if not child:IsA("BasePart") or child.Name ~= p.dot then
			continue
		end
		index += 1
		local dot = child :: BasePart
		local existing = dot:FindFirstChild(p.emitter)
		local emitter: ParticleEmitter? = if existing ~= nil
				and existing:IsA("ParticleEmitter")
			then existing :: ParticleEmitter
			else nil
		if TrailSparkle.carries(index, every, Context.lowPerformance) then
			if emitter == nil then
				emitter = Particles.attach(p.emitter, dot)
			end
			local made = emitter
			if made ~= nil then
				made.Color = ColorSequence.new(dot.Color, Presets.palette.offwhite)
				Particles.switchOn(made, p.emitter)
			end
		elseif emitter ~= nil then
			emitter.Enabled = false
		end
	end
end

local function watch(folder: Instance)
	local known: RBXScriptConnection? = folders[folder]
	if known ~= nil then
		return
	end
	local pending = false
	folders[folder] = folder.ChildAdded:Connect(function()
		if not pending then
			pending = true
			task.defer(function()
				pending = false
				refresh(folder)
			end)
		end
	end)
	refresh(folder)
end

local function consider(child: Instance)
	if child:IsA("Folder") and child.Name == Presets.trailSparkle.folder then
		watch(child)
	end
end

function TrailSparkle.start()
	if started then
		return
	end
	started = true
	for _, child in Workspace:GetChildren() do
		consider(child)
	end
	Workspace.ChildAdded:Connect(consider)
	task.spawn(function()
		-- a changed Low performance setting reaches the dots within a few seconds
		while true do
			task.wait(Presets.trailSparkle.recheck)
			for folder, hook in folders do
				if folder.Parent ~= nil then
					refresh(folder)
				else
					hook:Disconnect()
					folders[folder] = nil
				end
			end
		end
	end)
end

return TrailSparkle
