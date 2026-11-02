--!strict
-- The Lucky Cat statue's beckoning paw (F88, luck-and-rare-moments.md section 1a: "Its paw waves a little faster at
-- each level"). Gameplay-Engineer's #743 puts a Model named "LuckyCat" directly under each plot's model, with a
-- number attribute Level (0 to 5), and makes it again whenever the level changes. Levels 1 to 5 carry Model-Agent's
-- `_Paw` piece (#742), pivoted at the shoulder: this client tips it forward and back about the pivot's X
-- (Logic.pawWave, Presets.luckyPaw), one beckon every 2.4 s at level 1 down to 1.2 s at level 5, on statues within
-- budget.ambientRadius. Each statue starts at its own point in the beckon so a street of cafes does not wave in step.
-- The server never moves the statue's parts, so the turn is drawn over the paw's rest frames (bound when it is
-- found), and a statue out of range or with Reduce Motion is put back at rest. Listening only.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)

local LuckyPaw = {}

local SCAN_SECONDS = 0.5 -- how often statues are checked against the radius and for a move

type Statue = {
	model: Model,
	paw: Model,
	level: number,
	parts: { BasePart }, -- the paw's parts
	rest: { CFrame }, -- each paw part where the statue left it
	frames: { CFrame },
	pivot: CFrame, -- the paw's shoulder pivot at rest
	anchor: BasePart?, -- a part of the statue outside the paw, to notice the statue being moved
	anchorAt: CFrame,
	phase: number,
	waving: boolean,
}

local statues: { [Model]: Statue } = {}
-- Every LuckyCat this client has seen, bound or not: with streaming its paw can arrive after the model, and its parts
-- can stream out and come back as new instances, so the scan binds these again until they hold (review S110).
local seen: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local rng = Random.new()
local started = false
local scanAt = 0
local elapsed = 0

local function pawOf(model: Model): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-4) == "_Paw" then
			return child :: Model
		end
	end
	return nil
end

local function levelOf(model: Model): number
	local level = model:GetAttribute("Level")
	return if type(level) == "number" then level else 0
end

local function rest(statue: Statue)
	if statue.waving then
		statue.waving = false
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for i, part in statue.parts do
			if part.Parent ~= nil then -- one that streamed out comes back as a new part at rest
				table.insert(parts, part)
				table.insert(frames, statue.rest[i])
			end
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- The paw or the statue streamed out and back since it was bound (its parts are new instances), or the paw's parts
-- were still arriving when it was bound.
local function stale(statue: Statue): boolean
	local anchor = statue.anchor
	if
		(anchor ~= nil and not anchor:IsDescendantOf(statue.model))
		or not statue.parts[1]:IsDescendantOf(statue.model)
		or not statue.paw:IsDescendantOf(statue.model)
	then
		return true
	end
	local count = 0
	for _, descendant in statue.paw:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count ~= #statue.parts
end

-- Finds the paw of a statue and the frames it rests at; nil for the plinth (no paw).
local function bind(model: Model): Statue?
	local paw = pawOf(model)
	if paw == nil then
		return nil
	end
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _, descendant in paw:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant :: BasePart)
			table.insert(frames, (descendant :: BasePart).CFrame)
		end
	end
	if #parts == 0 then
		return nil
	end
	local anchor: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant:IsDescendantOf(paw) then
			anchor = descendant :: BasePart
			break
		end
	end
	return {
		model = model,
		paw = paw,
		level = levelOf(model),
		parts = parts,
		rest = frames,
		frames = table.clone(frames),
		pivot = paw:GetPivot(),
		anchor = anchor,
		anchorAt = if anchor ~= nil then anchor.CFrame else CFrame.identity,
		phase = rng:NextNumber(0, 10),
		waving = false,
	}
end

local function forget(model: Model)
	local statue = statues[model]
	if statue ~= nil then
		rest(statue)
		statues[model] = nil
	end
end

local function consider(child: Instance)
	if child.Name ~= "LuckyCat" or not child:IsA("Model") then
		return
	end
	local model = child :: Model
	seen[model] = true
	forget(model)
	local statue = bind(model)
	if statue ~= nil then
		statues[model] = statue
	end
end

local function watchPlot(plot: Instance)
	for _, child in plot:GetChildren() do
		consider(child)
	end
	plot.ChildAdded:Connect(function(child: Instance)
		task.defer(consider, child) -- after its attributes and paw are in
	end)
	plot.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Model") then
			statues[child :: Model] = nil
			seen[child :: Model] = nil
		end
	end)
end

-- Drops statues that are gone, binds again one the server moved or relevelled or that streamed back in, tries again
-- for one whose paw had not arrived, and notes which are in range.
local function scan()
	local focus = Context.focus()
	local radius = Context.budget.ambientRadius
	local still = Context.reducedMotion()
	local again: { Model } = {}
	for model, statue in statues do
		if model.Parent == nil then
			statues[model] = nil
			continue
		end
		local anchor = statue.anchor
		local moved = anchor ~= nil and anchor.CFrame ~= statue.anchorAt
		if moved or levelOf(model) ~= statue.level or stale(statue) then
			table.insert(again, model)
			continue
		end
		local near = not still
			and focus ~= nil
			and (statue.pivot.Position - focus).Magnitude <= radius
		if near then
			statue.waving = true
		else
			rest(statue)
		end
	end
	for model in seen do
		if model.Parent == nil then
			seen[model] = nil
		elseif statues[model] == nil and pawOf(model) ~= nil then
			table.insert(again, model) -- its paw arrived since
		end
	end
	for _, model in again do
		consider(model) -- puts the old paw back at rest first
	end
end

local function step(dt: number)
	local now = os.clock()
	if now >= scanAt then
		scanAt = now + SCAN_SECONDS
		scan()
	end
	elapsed += dt
	if elapsed < 1 / Context.budget.animHz then
		return
	end
	elapsed = 0
	for _, statue in statues do
		if not statue.waving or statue.parts[1].Parent == nil then
			continue -- streamed out: the scan binds it again when it is back
		end
		local turn = statue.pivot
			* CFrame.Angles(Logic.pawWave(now + statue.phase, statue.level), 0, 0)
			* statue.pivot:Inverse()
		local frames = statue.frames
		for i, frame in statue.rest do
			frames[i] = turn * frame
		end
		Workspace:BulkMoveTo(statue.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function LuckyPaw.start()
	if started then
		return
	end
	started = true
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
	RunService.PreRender:Connect(step)
end

return LuckyPaw
