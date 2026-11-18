--!strict
-- The door sign shows OPEN by day and CLOSED at night (#1172; Derek 2026-11-04: "the OPEN sign stays on during the
-- night"), and flips between them at nightfall and sunrise (#1140, door-sign.md section 3). Model-Agent's
-- CatCafe_Decor_DoorSign is the one Open/Closed sign on each cafe's door: the parts named
-- `CatCafe_Decor_DoorSign_Open` (the OPEN face) and the child Model `CatCafe_Decor_DoorSign_Closed` (the CLOSED face).
--
-- - A two-sided sign (#1346: it has a `CatCafe_Decor_DoorSign_Hanger` child, the pivot is at its hook and its board
--   is centred under it) turns half a turn about its pivot when the phase changes: OPEN faces the street by day, as
--   placed, and CLOSED at night. The turn eases over `flip` seconds and settles with one small back-and-forth swing.
--   With Reduce Motion, past `within` studs, or on joining mid-phase, it just shows the right side. Each part keeps
--   its offset from the sign's placed pivot, so a part that streams in late turns with the rest.
-- - A sign without a hanger (the earlier two-board one) hides the board that doesn't belong to the phase.
--
-- All on this client only (CFrame and LocalTransparencyModifier on anchored, unwelded parts the server places once
-- and never moves). The cafe is closed exactly at night (F44). The CLOSED face's `_Moon_Bulb` glows with the street's
-- night parts (WorldController).
--
-- Source: ReplicatedStorage.Clock's `Phase` and every Model named `CatCafe_Decor_DoorSign_Closed` under Workspace
-- (its parent is the sign). Listening only. Names and numbers in Presets.doorSign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local DoorSign = {}

type Turn = {
	base: CFrame, -- the sign's pivot as the server placed it (OPEN to the street)
	parts: { [BasePart]: CFrame }, -- each part's offset from `base`
	angle: number, -- the half turn shown now: 0 OPEN, math.pi CLOSED
	from: number,
	to: number,
	startedAt: number?, -- a flip under way
}

local boards: { [Model]: boolean } = {} -- two-board signs, by sign
local turns: { [Model]: Turn } = {} -- two-sided signs, by sign

-- #5003 (Sync's Park flight read: DoorSign was 3 to 4.4 ms of each 4,000-instance streaming burst): the answer for
-- each parent, kept until a sign is taken, so the parts of one model walk up once between them. Weak keys, so a
-- parent that streams out is let go.
local signOfParent: { [Instance]: Model | false } = setmetatable({}, { __mode = "k" }) :: any

local function signTaken()
	table.clear(signOfParent)
end

local night = false
local started = false
local stepping: RBXScriptConnection? = nil

local function show(part: Instance, visible: boolean)
	if part:IsA("BasePart") then
		(part :: BasePart).LocalTransparencyModifier = if visible then 0 else 1
	end
end

-- Two-board signs: OPEN parts are the sign's own parts outside the Closed board; the Closed board is its child Model.
local function hideOther(sign: Model)
	local d = Presets.doorSign
	local closed = sign:FindFirstChild(d.closed)
	for _, descendant in sign:GetDescendants() do
		if descendant:IsA("BasePart") then
			if closed ~= nil and descendant:IsDescendantOf(closed) then
				show(descendant, night)
			elseif descendant.Name == d.open then
				show(descendant, not night)
			end
		end
	end
end

local function target(): number
	return if night then math.pi else 0
end

-- #5164 (Sync's phase change read: DoorSign.place was 30 to 61 ms of the change frame, every sign's parts set one by
-- one): with the `nightSlice` switch on, each sign's parts move in one Workspace:BulkMoveTo. The lists are reused
-- and emptied after each move.
local BULK_FLAG = "nightSlice"
local bulkParts: { BasePart } = {}
local bulkFrames: { CFrame } = {}

local function place(turn: Turn, angle: number)
	local at = turn.base * CFrame.Angles(0, angle, 0)
	local bulk = ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. BULK_FLAG) == true
	local count = 0
	for part, offset in turn.parts do
		if part.Parent == nil then
			turn.parts[part] = nil
		elseif bulk then
			count += 1
			bulkParts[count] = part
			bulkFrames[count] = at * offset
		else
			part.CFrame = at * offset
		end
	end
	if count > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(bulkParts)
		table.clear(bulkFrames)
	end
end

local function step()
	local d = Presets.doorSign
	local now = os.clock()
	local busy = false
	for sign, turn in turns do
		local startedAt = turn.startedAt
		if sign.Parent == nil then
			turns[sign] = nil
		elseif startedAt ~= nil then
			local swingBy = math.rad(d.swing)
			local share, swing = Logic.signFlip(now - startedAt, d.flip, d.settle, swingBy)
			local direction = if turn.to >= turn.from then 1 else -1
			turn.angle = turn.from + (turn.to - turn.from) * share + direction * swing
			if now - startedAt >= d.flip + d.settle then
				turn.angle, turn.startedAt = turn.to, nil
			else
				busy = true
			end
			place(turn, turn.angle)
		end
	end
	local connection = stepping
	if not busy and connection ~= nil then
		connection:Disconnect()
		stepping = nil
	end
end

local function flipAll()
	local d = Presets.doorSign
	local to = target()
	for sign, turn in turns do
		if sign.Parent == nil then
			turns[sign] = nil
		elseif turn.angle ~= to or turn.startedAt ~= nil then
			local near = Context.distance(turn.base.Position) <= d.within
			if Context.reducedMotion() or not near then
				turn.angle, turn.startedAt = to, nil
				place(turn, to)
			else
				turn.from, turn.to, turn.startedAt = turn.angle, to, os.clock()
			end
		end
	end
	for sign in boards do
		if sign.Parent == nil then
			boards[sign] = nil
		else
			hideOther(sign)
		end
	end
	if stepping == nil then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

-- A two-sided sign seen for the first time: as placed it shows OPEN, so it takes the phase's side at once.
local function addTurn(sign: Model)
	local base = sign:GetPivot()
	local parts: { [BasePart]: CFrame } = {}
	for _, descendant in sign:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			parts[part] = base:ToObjectSpace(part.CFrame)
		end
	end
	local turn: Turn = { base = base, parts = parts, angle = 0, from = 0, to = 0, startedAt = nil }
	turns[sign] = turn
	signTaken()
	turn.angle, turn.to = target(), target()
	place(turn, turn.angle)
end

-- The sign a part streaming in belongs to: its nearest ancestor already taken as a two-sided or two-board sign.
-- #4987 (Sync's load read: this was 236 ms of the Effects start on a PC): it was an IsA and a FindFirstChild on every
-- ancestor of every part in the map; it is now a table look-up per ancestor, and nothing at all with no sign known.
local function signOf(instance: Instance): Model?
	if next(turns) == nil and next(boards) == nil then
		return nil
	end
	local parent = instance.Parent
	if parent == nil then
		return nil
	end
	local known = signOfParent[parent]
	if known == false then
		return nil
	elseif known ~= nil then
		return known :: Model
	end
	local found: Model? = nil
	local at: Instance? = parent
	while at ~= nil and at ~= (Workspace :: Instance) do
		local model = at :: Model
		if turns[model] ~= nil or boards[model] ~= nil then
			found = model
			break
		end
		at = at.Parent
	end
	signOfParent[parent] = if found ~= nil then found else false
	return found
end

local function consider(instance: Instance)
	local d = Presets.doorSign
	if instance:IsA("Model") and instance.Name == d.closed then
		local sign = instance.Parent
		if sign ~= nil and sign:IsA("Model") then
			local model = sign :: Model
			if turns[model] == nil and boards[model] == nil then
				if model:FindFirstChild(d.hanger) ~= nil then
					addTurn(model)
				else
					boards[model] = true
					signTaken()
					hideOther(model)
				end
			end
		end
	elseif instance:IsA("Model") and instance.Name == d.hanger then
		-- the hanger streaming in after the sign was taken for a two-board one
		local sign = instance.Parent
		if sign ~= nil and sign:IsA("Model") and boards[sign :: Model] then
			local model = sign :: Model
			boards[model] = nil
			for _, descendant in model:GetDescendants() do
				show(descendant, true)
			end
			addTurn(model)
		end
	elseif instance:IsA("BasePart") then
		local sign = signOf(instance)
		if sign == nil then
			return
		end
		local turn = turns[sign]
		if turn ~= nil then
			-- a part streaming in after its sign, as placed: it turns with the rest (one already taken is turned)
			local part = instance :: BasePart
			local known: CFrame? = turn.parts[part]
			if known ~= nil then
				return
			end
			turn.parts[part] = turn.base:ToObjectSpace(part.CFrame)
			part.CFrame = turn.base * CFrame.Angles(0, turn.angle, 0) * turn.parts[part]
		elseif boards[sign] then
			local closed = sign:FindFirstChild(d.closed)
			if closed ~= nil and instance:IsDescendantOf(closed) then
				show(instance, night)
			elseif instance.Name == d.open then
				show(instance, not night)
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
		-- #4987: the first look needs only the signs' models: addTurn and hideOther take the parts already there
		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("Model") then
				consider(descendant)
			end
		end
		Context.onWorkspaceAdded(consider)
		clock:GetAttributeChangedSignal("Phase"):Connect(function()
			local now = clock:GetAttribute("Phase") == "night"
			if now ~= night then
				night = now
				flipAll()
			end
		end)
	end)
end

return DoorSign
