--!strict
-- Speech bubbles on the town's key cats (#1079, docs/design/cat-cafe/cat-bubbles.md): walking near the Spin Wheel's
-- cat, the Fish Market, the Codes Cat, the Bellhop Cat (until claimed), the night dealer (while his cart is in
-- town), the Cat Collector (while he visits your cafe) or the Corner Shop shows that cat's one line over it, and it
-- fades when the player walks away. Only the nearest shows, and a cat stays quiet for a minute after its bubble
-- fades (Components/CatBubblesLogic). No tap, no prompt, no window, no remote: it is only text.
--
-- The stations are the server's models found by CollectionService tag (Components/CatBubbleLines); the Collector is
-- CustomerController's local model. A bubble floats over the station's prompt point (above its action pill), else
-- 1.5 studs over the model's top. It hides while `hooks.blocked()` says so (a window, a catch, a carry, the intro).
--
-- Roblox terms: a BillboardGui draws 2D UI at a 3D point and always faces the camera. Sized with UDim2 scale it is
-- measured in studs, so it shrinks with distance; with AlwaysOnTop off, walls in front hide it; MaxDistance hides it
-- past that many studs. Two billboards take turns, so one can fade out while the next fades in.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CatBubbleLines = require(script.Parent.Parent.Components.CatBubbleLines)
local CatBubblesLogic = require(script.Parent.Parent.Components.CatBubblesLogic)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Hooks = {
	blocked: () -> boolean, -- true while no bubble may show
	claimed: () -> boolean?, -- ProfileSync's starterCatClaimed, nil before the first sync
}

export type CatBubbles = {
	destroy: (self: CatBubbles) -> (),
}

type Entry = {
	instance: Instance,
	line: CatBubbleLines.Line,
	point: Vector3?, -- where the tail's tip sits, nil while the station is not in the world
	here: boolean, -- the dealer's cart is open, or the Collector is on this player's plot
	refreshAt: number,
	distance: number,
}

type Slot = {
	attachment: Attachment,
	billboard: BillboardGui,
	scale: UIScale,
	box: Frame,
	boxStroke: UIStroke,
	tail: Frame,
	tailStroke: UIStroke,
	label: TextLabel,
	token: number,
	width: number,
	height: number,
	shownScale: number,
}

local TAIL_SHARE = 0.2 -- of the billboard's height, under the box, where the tail points at the cat
local PILL_CLEAR = 1.4 -- studs between a prompt point and the bubble's tip, so the action pill shows under it
local TOP_CLEAR = 1.5 -- studs over the model's top when the station has no prompt point
local REFRESH_SECONDS = 2 -- how often a station's point and its `here` are looked up again
local FADE_IN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POP = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_FROM = 0.85

local CatBubbles = {}
CatBubbles.__index = CatBubbles

local function newSlot(parent: Instance, index: number): Slot
	local attachment: Attachment = Create("Attachment", {
		Name = "CatCafeCatBubble" .. index,
		Parent = Workspace.Terrain,
	})
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeCatBubble" .. index,
		Adornee = attachment,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = CatBubblesLogic.HIDE_STUDS + 4,
		ResetOnSpawn = false,
		Size = UDim2.fromScale(1, 1),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = parent,
	})
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
	})
	local scale: UIScale = Create("UIScale", { Parent = root })
	local box: Frame = Create("Frame", {
		Name = "Box",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1 - TAIL_SHARE),
		ZIndex = 2,
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
	local boxStroke = Outline.border(box, 2, Theme.colors.cocoa)
	-- a square turned 45 degrees behind the box's bottom edge: its lower half is the tail
	local tail: Frame = Create("Frame", {
		Name = "Tail",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1 - TAIL_SHARE),
		Size = UDim2.fromScale(0.26, 0.26),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Rotation = 45,
		ZIndex = 1,
		Parent = root,
	})
	local tailStroke = Outline.border(tail, 2, Theme.colors.cocoa)
	local label: TextLabel = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, CatBubblesLogic.TEXT_STUDS / CatBubblesLogic.HEIGHT_STUDS),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.cocoa,
		TextScaled = true,
		TextWrapped = false,
		Text = "",
		ZIndex = 3,
		Parent = box,
	}, { Create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 64 }) })
	return {
		attachment = attachment,
		billboard = billboard,
		scale = scale,
		box = box,
		boxStroke = boxStroke,
		tail = tail,
		tailStroke = tailStroke,
		label = label,
		token = 0,
		width = 1,
		height = 1,
		shownScale = -1,
	}
end

local function fade(slot: Slot, info: TweenInfo, transparency: number): Tween
	TweenService:Create(slot.box, info, { BackgroundTransparency = transparency }):Play()
	TweenService:Create(slot.boxStroke, info, { Transparency = transparency }):Play()
	TweenService:Create(slot.tail, info, { BackgroundTransparency = transparency }):Play()
	TweenService:Create(slot.tailStroke, info, { Transparency = transparency }):Play()
	local last = TweenService:Create(slot.label, info, { TextTransparency = transparency })
	last:Play()
	return last
end

-- Shrinks the bubble up close (CatBubblesLogic.closeScale), keeping the tail's tip on the point.
local function applyScale(slot: Slot, scale: number)
	if scale == slot.shownScale then
		return
	end
	slot.shownScale = scale
	local total = slot.height / (1 - TAIL_SHARE) * scale
	slot.billboard.Size = UDim2.fromScale(slot.width * scale, total)
	slot.billboard.StudsOffsetWorldSpace = Vector3.new(0, total / 2, 0)
end

local function show(slot: Slot, entry: Entry)
	slot.token += 1
	local text = entry.line.text
	slot.label.Text = text
	slot.width, slot.height = CatBubblesLogic.size(text)
	slot.shownScale = -1
	applyScale(slot, CatBubblesLogic.closeScale(entry.distance))
	slot.attachment.WorldPosition = entry.point or slot.attachment.WorldPosition
	slot.box.BackgroundTransparency = 1
	slot.boxStroke.Transparency = 1
	slot.tail.BackgroundTransparency = 1
	slot.tailStroke.Transparency = 1
	slot.label.TextTransparency = 1
	slot.billboard.Enabled = true
	fade(slot, FADE_IN, 0)
	-- Reduce Motion keeps the plain fade and drops the pop
	if GuiService.ReducedMotionEnabled then
		slot.scale.Scale = 1
	else
		slot.scale.Scale = POP_FROM
		TweenService:Create(slot.scale, POP, { Scale = 1 }):Play()
	end
end

local function hide(slot: Slot)
	slot.token += 1
	local token = slot.token
	fade(slot, FADE_OUT, 1).Completed:Once(function()
		if slot.token == token then
			slot.billboard.Enabled = false
		end
	end)
end

-- The tail's tip for a station: over its prompt point and pill, else over the model's top. Nil out of the world.
local function pointOf(entry: Entry): Vector3?
	local instance = entry.instance
	if not instance:IsDescendantOf(Workspace) then
		return nil
	end
	local anchorName = entry.line.anchor
	if anchorName ~= nil then
		local anchor = instance:FindFirstChild(anchorName, true)
		if anchor ~= nil and anchor:IsA("Attachment") then
			return anchor.WorldPosition + Vector3.new(0, (entry.line.lift or 0) + PILL_CLEAR, 0)
		end
	end
	if instance:IsA("Model") then
		local box, extents = instance:GetBoundingBox()
		return box.Position + Vector3.new(0, extents.Y / 2 + TOP_CLEAR, 0)
	elseif instance:IsA("BasePart") then
		return instance.Position + Vector3.new(0, instance.Size.Y / 2 + TOP_CLEAR, 0)
	end
	return nil
end

local function hereOf(entry: Entry): boolean
	local when = entry.line.when
	if when == "dealerHere" then
		return entry.instance:GetAttribute("Open") ~= false
	elseif when == "collectorVisiting" then
		local plot = entry.instance.Parent
		local player = Players.LocalPlayer
		return plot ~= nil and player ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
	end
	return true
end

function CatBubbles.new(parent: Instance, hooks: Hooks): CatBubbles
	local self = setmetatable({}, CatBubbles) :: any
	local connections: { RBXScriptConnection } = {}
	local entries: { Entry } = {}
	local byInstance: { [Instance]: Entry } = {}
	local slots = { newSlot(parent, 1), newSlot(parent, 2) }
	local memory = CatBubblesLogic.newMemory()
	local keys: { any } = {}
	local distances: { number } = {}
	local activeSlot = 1
	local activeStation: Instance? = nil
	local waited = 0
	self._connections = connections
	self._slots = slots

	local function add(instance: Instance, line: CatBubbleLines.Line)
		if byInstance[instance] ~= nil then
			return
		end
		local entry: Entry = {
			instance = instance,
			line = line,
			point = nil,
			here = false,
			refreshAt = 0,
			distance = math.huge,
		}
		byInstance[instance] = entry
		table.insert(entries, entry)
	end

	local function remove(instance: Instance)
		local entry = byInstance[instance]
		if entry == nil then
			return
		end
		byInstance[instance] = nil
		local index = table.find(entries, entry)
		if index ~= nil then
			table.remove(entries, index)
		end
	end

	for _, line in CatBubbleLines.LINES do
		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal(line.tag):Connect(function(instance: Instance)
				add(instance, line)
			end)
		)
		table.insert(
			connections,
			CollectionService:GetInstanceRemovedSignal(line.tag):Connect(remove)
		)
		for _, instance in CollectionService:GetTagged(line.tag) do
			add(instance, line)
		end
	end

	local function step()
		local now = os.clock()
		local player = Players.LocalPlayer
		local character = if player ~= nil then player.Character else nil
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		local blocked = root == nil or not root:IsA("BasePart") or hooks.blocked()
		local count = 0
		if root ~= nil and root:IsA("BasePart") then
			local from = root.Position
			local claimed = hooks.claimed()
			for _, entry in entries do
				if now >= entry.refreshAt then
					entry.refreshAt = now + REFRESH_SECONDS
					entry.point = pointOf(entry)
					entry.here = hereOf(entry)
				end
				local point = entry.point
				if
					point ~= nil and CatBubblesLogic.allowed(entry.line.when, claimed, entry.here)
				then
					local dx = point.X - from.X
					local dz = point.Z - from.Z
					entry.distance = math.sqrt(dx * dx + dz * dz)
					count += 1
					keys[count] = entry.instance
					distances[count] = entry.distance
				end
			end
		end
		local shown, stopped = CatBubblesLogic.step(memory, keys, distances, count, now, blocked)
		if stopped ~= nil and stopped == activeStation then
			hide(slots[activeSlot])
			activeStation = nil
		end
		if shown == nil then
			return
		end
		local entry = byInstance[shown]
		if entry == nil then
			return
		end
		if shown == activeStation then
			applyScale(slots[activeSlot], CatBubblesLogic.closeScale(entry.distance))
			return
		end
		activeSlot = 3 - activeSlot -- the other billboard, so the old one can finish fading
		activeStation = shown
		show(slots[activeSlot], entry)
	end

	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			waited += dt
			if waited < CatBubblesLogic.STEP_SECONDS then
				return
			end
			waited = 0
			step()
		end)
	)

	return self :: CatBubbles
end

function CatBubbles.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, slot in self._slots do
		slot.billboard:Destroy()
		slot.attachment:Destroy()
	end
	table.clear(self._slots)
end

return CatBubbles
