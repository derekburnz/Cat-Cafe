--!strict
-- Catch v3 mood icons (catch-rework.md 7a): a small round icon over each stray's head for its Mood attribute, shown
-- within Config.MoodIconStuds (20): zZ Sleepy, ? Curious, ! Skittish. A Skittish cat's icon also shows its 90 degree
-- view arc, turned each frame to the way the cat faces on screen, so a player can see where to sneak in from behind.
-- The icon hides while the cat is being caught (LockedBy set: the trust bar takes that spot) or running off
-- (FleeingUntil ahead), and comes back after. Gameplay sets Mood when the stray spawns; without it nothing shows.
-- Components/MoodLogic says what each mood looks like.
--   MoodIcons.new()      watches the Stray tag
--   icons:destroy()
--
-- Roblox terms: a BillboardGui parented under a part draws over it and always faces the camera; an offset Size stays
-- the same on screen at any distance, and MaxDistance hides it past that many studs.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local MoodLogic = require(script.Parent.Parent.Components.MoodLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type MoodIcons = {
	destroy: (self: MoodIcons) -> (),
}

type Entry = {
	model: Instance,
	part: BasePart,
	billboard: BillboardGui,
	icon: Frame,
	glyph: TextLabel,
	arc: Frame,
	angle: number?,
}

local TAG = "Stray"
local SIZE = 56 -- px, square: the icon and room for the arc around it
local ICON = 26 -- px, the round icon
local ARC_FROM = 15 -- px from the centre, just outside the icon
local ARC_LENGTH = 9 -- px, each edge of the view arc
local ARC_HALF = 45 -- degrees each side of the facing: the 90 degree front arc
local LIFT = 0.8 -- studs over the top of the cat

local MoodIcons = {}
MoodIcons.__index = MoodIcons

local function anchorOf(model: Instance): (BasePart?, number)
	local part: BasePart? = nil
	if model:IsA("Model") then
		part = (model :: Model).PrimaryPart
		if part ~= nil and not part:IsDescendantOf(model) then
			part = nil -- streamed out: the model's old part
		end
	end
	if not part then
		local found = model:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if not part then
		return nil, 0
	end
	assert(part, "anchor part")
	local top = part.Position.Y + part.Size.Y / 2
	if model:IsA("Model") then
		local boxCFrame, boxSize = (model :: Model):GetBoundingBox()
		top = math.max(top, boxCFrame.Position.Y + boxSize.Y / 2)
	end
	return part, top - part.Position.Y
end

-- One edge (or the tip dots) of the arc: a thin bar from ARC_FROM out, pointing `degrees` from the arc's facing
local function edge(parent: Instance, name: string, degrees: number, color: Color3)
	local rad = math.rad(degrees)
	local mid = ARC_FROM + ARC_LENGTH / 2
	Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(rad) * mid, 0.5, math.sin(rad) * mid),
		Size = UDim2.fromOffset(ARC_LENGTH, 3),
		Rotation = degrees,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
end

local function tip(parent: Instance, name: string, degrees: number, color: Color3)
	local rad = math.rad(degrees)
	local at = ARC_FROM + ARC_LENGTH
	Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(rad) * at, 0.5, math.sin(rad) * at),
		Size = UDim2.fromOffset(3, 3),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
end

function MoodIcons.new(): MoodIcons
	local self = setmetatable({}, MoodIcons) :: any
	self._entries = {} :: { [Instance]: Entry }
	self._watched = {} :: { [Instance]: { RBXScriptConnection } }
	self._connections = {} :: { RBXScriptConnection }
	self._turn = nil :: RBXScriptConnection?
	for _, stray in CollectionService:GetTagged(TAG) do
		self:_watch(stray)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(stray: Instance)
			self:_watch(stray)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(stray: Instance)
			self:_unwatch(stray)
		end)
	)
	return self :: MoodIcons
end

-- Mood can arrive after the tag (or change), so each stray is watched and its icon made, swapped or dropped to match
function MoodIcons._watch(self: any, stray: Instance)
	if self._watched[stray] then
		return
	end
	local refresh = function()
		if self._watched[stray] ~= nil then -- a deferred refresh after the stray went does nothing
			self:_refresh(stray)
		end
	end
	self._watched[stray] = {
		-- with streaming the model can come before its parts, and a cat streamed out and back in gets new parts, so
		-- the icon is made when a part arrives and made again when its part goes (as PityTags, #2099)
		stray.DescendantAdded:Connect(function(child: Instance)
			if self._entries[stray] == nil and child:IsA("BasePart") then
				task.defer(refresh)
			end
		end),
		stray.DescendantRemoving:Connect(function(child: Instance)
			local entry = self._entries[stray]
			if entry ~= nil and child == entry.part then
				self:_drop(stray)
				task.defer(refresh)
			end
		end),
		stray:GetAttributeChangedSignal("Mood"):Connect(refresh),
		stray:GetAttributeChangedSignal("LockedBy"):Connect(refresh),
		stray:GetAttributeChangedSignal("FleeingUntil"):Connect(refresh),
		stray.AncestryChanged:Connect(function()
			if not stray:IsDescendantOf(Workspace) then
				self:_unwatch(stray)
			end
		end),
	}
	self:_refresh(stray)
end

function MoodIcons._unwatch(self: any, stray: Instance)
	local watched = self._watched[stray]
	if watched then
		for _, connection in watched do
			connection:Disconnect()
		end
		self._watched[stray] = nil
	end
	self:_drop(stray)
end

local function busy(stray: Instance): boolean
	local locked = stray:GetAttribute("LockedBy")
	if type(locked) == "number" and locked ~= 0 then
		return true
	end
	local fleeing = stray:GetAttribute("FleeingUntil")
	return type(fleeing) == "number" and fleeing > Workspace:GetServerTimeNow()
end

function MoodIcons._refresh(self: any, stray: Instance)
	local look = MoodLogic.look(stray:GetAttribute("Mood"))
	if not look then
		self:_drop(stray)
		return
	end
	local entry: Entry? = self._entries[stray]
	if not entry then
		entry = self:_make(stray)
		if not entry then
			return
		end
	end
	assert(entry, "entry")
	local color = Color3.fromHex(look.color)
	entry.glyph.Text = look.glyph
	entry.glyph.TextColor3 = color
	entry.arc.Visible = look.arc -- only Skittish has one, drawn in its red
	local shown = not busy(stray)
	if shown and not entry.billboard.Enabled then
		Tween.popIn(entry.icon, 0.25)
	end
	entry.billboard.Enabled = shown
	-- FleeingUntil passes without an attribute change: look again just after it
	local fleeing = stray:GetAttribute("FleeingUntil")
	local wait = if type(fleeing) == "number" then fleeing - Workspace:GetServerTimeNow() else 0
	if not shown and wait > 0 and wait < 60 then
		task.delay(wait + 0.1, function()
			if self._entries[stray] then
				self:_refresh(stray)
			end
		end)
	end
	self:_startTurn()
end

function MoodIcons._make(self: any, stray: Instance): Entry?
	local part, height = anchorOf(stray)
	if not part then
		return nil
	end
	assert(part, "part")
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeMoodIcon",
		Size = UDim2.fromOffset(SIZE, SIZE),
		StudsOffsetWorldSpace = Vector3.new(0, height + LIFT, 0),
		MaxDistance = MoodLogic.range(),
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = part,
	})
	local icon: Frame = Create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 2 }),
	})
	local glyph: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 18,
		Text = "",
		Parent = icon,
	})
	Outline.text(glyph, 1)
	local arc: Frame = Create("Frame", {
		Name = "Arc",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = billboard,
	})
	local ink = Theme.colors.red
	edge(arc, "Left", -ARC_HALF, ink)
	edge(arc, "Right", ARC_HALF, ink)
	tip(arc, "TipLeft", -ARC_HALF / 2, ink)
	tip(arc, "Tip", 0, ink)
	tip(arc, "TipRight", ARC_HALF / 2, ink)
	local entry: Entry = {
		model = stray,
		part = part,
		billboard = billboard,
		icon = icon,
		glyph = glyph,
		arc = arc,
		angle = nil,
	}
	self._entries[stray] = entry
	return entry
end

function MoodIcons._drop(self: any, stray: Instance)
	local entry: Entry? = self._entries[stray]
	if entry then
		entry.billboard:Destroy()
		self._entries[stray] = nil
	end
end

-- One RenderStepped turns every Skittish arc in range to the cat's facing on screen; it stops itself when none is left
function MoodIcons._startTurn(self: any)
	if self._turn then
		return
	end
	self._turn = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local any = false
		for _, entry: Entry in self._entries do
			if entry.arc.Visible then
				any = true
				if camera and entry.billboard.Enabled then
					local at = entry.part.Position
					if (camera.CFrame.Position - at).Magnitude <= entry.billboard.MaxDistance then
						local here, onHere = camera:WorldToViewportPoint(at)
						local ahead, onAhead =
							camera:WorldToViewportPoint(at + entry.part.CFrame.LookVector * 2)
						if onHere or onAhead then
							entry.angle =
								MoodLogic.arcAngle(ahead.X - here.X, ahead.Y - here.Y, entry.angle)
						end
						entry.arc.Rotation = entry.angle or 90
					end
				end
			end
		end
		if not any and self._turn then
			self._turn:Disconnect()
			self._turn = nil
		end
	end)
end

function MoodIcons.destroy(self: any)
	if self._turn then
		self._turn:Disconnect()
		self._turn = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for stray in self._watched do
		self:_unwatch(stray)
	end
	for stray in self._entries do
		self:_drop(stray)
	end
end

return MoodIcons
