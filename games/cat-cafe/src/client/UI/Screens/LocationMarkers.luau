--!strict
-- The My Cafe marker (UI plan 2026-10-27, the world icons of Pet Simulator 99 and Grow a Garden): a gold round icon
-- with "My Cafe" and the distance over the player's own Plot, seen from anywhere on the map. It fades out between
-- Wayfinding.FAR and Wayfinding.NEAR studs, so the cafe in front of the player is never covered, and draws smaller
-- the further away it is (Wayfinding.scale). It hides while carrying, when the carry marker leads to the door.
-- The areas, the night dealer's cart and the Town Square had markers too until Derek 2026-10-28: "toggle off the ui
-- bubbles for all places except your cafe people can just rely on signs in game" (the gate signs and the signpost).
-- The point comes from the plot's pivot, so the marker shows before the parts stream in.
--
-- Roblox terms: a BillboardGui draws 2D UI at a 3D point, facing the camera; AlwaysOnTop shows it through walls.
-- This one is adorned to an Attachment in Terrain at the marker's point.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Wayfinding = require(script.Parent.Parent.Components.Wayfinding)

export type LocationMarkers = {
	setCarrying: (self: LocationMarkers, carrying: boolean) -> (),
	setVisible: (self: LocationMarkers, visible: boolean) -> (),
	setEnabled: (self: LocationMarkers, enabled: boolean) -> (),
	destroy: (self: LocationMarkers) -> (),
}

local ICON = 46
local WIDTH = 160
local HEIGHT = ICON + 40
local FADE_STEP = 0.1 -- seconds between distance checks
local POINT_STEP = 1 -- seconds between looking the plot up again (a plot is claimed)
local STUDS_PER_METRE = 3.57 -- as the carry marker (Components/WorldMarker)
local HOME_LIFT = 18

local LocationMarkers = {}
LocationMarkers.__index = LocationMarkers

function LocationMarkers.new(parent: Instance): LocationMarkers
	local self = setmetatable({}, LocationMarkers) :: any
	self._carrying = false
	self._visible = true
	self._enabled = true -- the My Cafe icon switch in Settings
	self._point = nil :: Vector3?
	self._size = 1 -- the scale last applied
	self._shown = -1 -- the alpha last applied, so a still frame costs nothing

	local attachment: Attachment = Create("Attachment", {
		Name = "CatCafeMarker_home",
		Parent = Workspace.Terrain,
	})
	self._attachment = attachment
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeMarker_home",
		Adornee = attachment,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		MaxDistance = math.huge,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	self._billboard = billboard
	-- everything sits in one full-size frame that a UIScale shrinks, while the billboard's own size follows it
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Parent = billboard,
	})
	self._scale = Create("UIScale", { Parent = root })
	local disc: Frame = Create("Frame", {
		Name = "Icon",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._disc = disc
	self._discStroke = Outline.border(disc, 3, Theme.colors.white)
	local glyph: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 24,
		TextColor3 = Theme.colors.white,
		Text = Theme.icons.home,
		Parent = disc,
	})
	IconArt.set(glyph, Theme.icons.home, 0.84)
	self._glyph = glyph
	local name: TextLabel = Create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, ICON + 2),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = 17,
		TextColor3 = Theme.colors.white,
		Text = "My Cafe",
		Parent = root,
	})
	self._name = name
	self._nameStroke = Outline.text(name, 2)
	local sub: TextLabel = Create("TextLabel", {
		Name = "Distance",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, ICON + 22),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.fonts.display,
		TextSize = 13,
		TextColor3 = Theme.hud.subtext,
		Text = "",
		Parent = root,
	})
	self._sub = sub
	self._subStroke = Outline.text(sub, 1.5)

	local fadeClock, pointClock = 0, POINT_STEP
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		fadeClock += dt
		pointClock += dt
		if pointClock >= POINT_STEP then
			pointClock = 0
			self:_findPoint()
		end
		if fadeClock >= FADE_STEP then
			fadeClock = 0
			self:_fade()
		end
	end)
	return self :: LocationMarkers
end

function LocationMarkers.setCarrying(self: any, carrying: boolean)
	self._carrying = carrying
end

function LocationMarkers.setVisible(self: any, visible: boolean)
	self._visible = visible
	self:_fade()
end

-- The player's My Cafe icon setting; off hides the marker until it is turned back on.
function LocationMarkers.setEnabled(self: any, enabled: boolean)
	self._enabled = enabled
	self:_fade()
end

local function ownPlot(): Model?
	local player = Players.LocalPlayer
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot :: Model
		end
	end
	return nil
end

function LocationMarkers._findPoint(self: any)
	local plot = ownPlot()
	local point = if plot then plot:GetPivot().Position + Vector3.new(0, HOME_LIFT, 0) else nil
	self._point = point
	if point then
		self._attachment.WorldPosition = point
	end
end

-- Shrinks the marker and its billboard together, in steps so a slow walk does not resize it every check.
function LocationMarkers._applySize(self: any, size: number)
	local stepped = math.floor(size * 20 + 0.5) / 20
	if self._size == stepped then
		return
	end
	self._size = stepped
	self._scale.Scale = stepped
	self._billboard.Size = UDim2.fromOffset(WIDTH * stepped, HEIGHT * stepped)
end

function LocationMarkers._applyAlpha(self: any, alpha: number)
	if self._shown == alpha then
		return
	end
	self._shown = alpha
	self._billboard.Enabled = alpha > 0
	local fade = 1 - alpha
	self._disc.BackgroundTransparency = fade
	self._discStroke.Transparency = fade
	IconArt.setTransparency(self._glyph, fade)
	self._name.TextTransparency = fade
	self._nameStroke.Transparency = fade
	self._sub.TextTransparency = fade
	self._subStroke.Transparency = fade
end

function LocationMarkers._fade(self: any)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local from: Vector3? = if root and root:IsA("BasePart") then root.Position else nil
	local point: Vector3? = self._point
	if not point or not from or not self._visible or not self._enabled or self._carrying then
		self:_applyAlpha(0)
		return
	end
	local distance = (point - from).Magnitude
	local alpha = Wayfinding.alpha(distance)
	if alpha > 0 then
		self._sub.Text = ("%d m"):format(math.floor(distance / STUDS_PER_METRE + 0.5))
		self:_applySize(Wayfinding.scale(distance))
	end
	self:_applyAlpha(alpha)
end

function LocationMarkers.destroy(self: any)
	self._loop:Disconnect()
	self._billboard:Destroy()
	self._attachment:Destroy()
end

return LocationMarkers
