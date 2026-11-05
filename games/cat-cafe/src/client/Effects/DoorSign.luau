--!strict
-- The decor door sign shows OPEN by day and CLOSED at night (#1172; Derek 2026-11-04: "the OPEN sign stays on
-- during the night"). Model-Agent's CatCafe_Decor_DoorSign holds two whole boards, one meant to show at a time
-- (build_all.py: "Show Open by day and Closed at night (Clock.Phase)"): the parts named `CatCafe_Decor_DoorSign_Open`
-- and the child Model `CatCafe_Decor_DoorSign_Closed`. Every placed copy in the world, in your cafe and in others',
-- hides the board that does not belong to the phase on this client (LocalTransparencyModifier, so nothing the
-- server owns changes). The cafe is closed exactly at night (F44, the same phase WorldBuilder.setClosedSign follows).
--
-- Source: ReplicatedStorage.Clock's `Phase` and every Model named `CatCafe_Decor_DoorSign_Closed` under Workspace
-- (its parent is the sign). Listening only. Names in Presets.doorSign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Presets = require(script.Parent.Presets)

local DoorSign = {}

local signs: { [Model]: boolean } = {} -- each sign by its Closed board's parent
local night = false
local started = false

local function show(part: Instance, visible: boolean)
	if part:IsA("BasePart") then
		(part :: BasePart).LocalTransparencyModifier = if visible then 0 else 1
	end
end

-- OPEN parts are the sign's own parts outside the Closed board; the Closed board is its child Model.
local function apply(sign: Model)
	local d = Presets.doorSign
	local closed = sign:FindFirstChild(d.closed)
	for _, descendant in sign:GetDescendants() do
		if descendant:IsA("BasePart") then
			local onClosed = closed ~= nil and descendant:IsDescendantOf(closed)
			if onClosed then
				show(descendant, night)
			elseif descendant.Name == d.open then
				show(descendant, not night)
			end
		end
	end
end

local function applyAll()
	for sign in signs do
		if sign.Parent == nil then
			signs[sign] = nil
		else
			apply(sign)
		end
	end
end

local function consider(instance: Instance)
	if instance:IsA("Model") and instance.Name == Presets.doorSign.closed then
		local sign = instance.Parent
		if sign ~= nil and sign:IsA("Model") and signs[sign :: Model] == nil then
			signs[sign :: Model] = true
			apply(sign :: Model)
		end
	elseif instance:IsA("BasePart") then
		-- a board part streaming in after its sign: the OPEN parts sit on the sign, the CLOSED ones on its board
		local d = Presets.doorSign
		local parent = instance.Parent
		if instance.Name == d.open and parent ~= nil and signs[parent :: any] then
			show(instance, not night)
		elseif instance.Name == d.closed and parent ~= nil and parent.Name == d.closed then
			local sign = parent.Parent
			if sign ~= nil and signs[sign :: any] then
				show(instance, night)
			end
		end
	end
end

function DoorSign.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local clock = ReplicatedStorage:WaitForChild("Clock")
		night = clock:GetAttribute("Phase") == "night"
		for _, descendant in Workspace:GetDescendants() do
			consider(descendant)
		end
		Workspace.DescendantAdded:Connect(consider)
		clock:GetAttributeChangedSignal("Phase"):Connect(function()
			local now = clock:GetAttribute("Phase") == "night"
			if now ~= night then
				night = now
				applyAll()
			end
		end)
	end)
end

return DoorSign
