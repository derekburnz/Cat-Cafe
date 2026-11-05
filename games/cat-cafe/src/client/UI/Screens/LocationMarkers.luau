--!strict
-- The My Cafe and Night Market markers (UI plan 2026-10-27, the world icons of Pet Simulator 99 and Grow a Garden):
-- a gold round icon with "My Cafe" and the distance over the player's own Plot, seen from anywhere on the map. Each
-- marker fades out between Wayfinding.FAR and Wayfinding.NEAR studs, so the place in front of the player is never
-- covered, and draws smaller the further away it is (Wayfinding.scale). They hide while carrying, when the carry
-- marker leads to the door.
-- The areas, the night dealer's cart and the Town Square had markers too until Derek 2026-10-28: "toggle off the ui
-- bubbles for all places except your cafe people can just rely on signs in game" (the gate signs).
-- #1418 (Derek 11-05: "add a ui bubble similar to this cafe one but for night market that appears during night when
-- hes there and disappears when gone") brings one back: a berry moon icon with "Night Market" and the distance over
-- the dealer's cart, only while a `DealerCart` model is out with Open set (the server parks it at nightfall and
-- removes it at dawn, DealerService). The Settings switch (Map icons) turns both off.
-- #1620 (Derek2 11-05: "only show the my cafe bubble when in that area"): the My Cafe marker shows only while the
-- player is in the cafe area, the street and the cafes (Wayfinding.homeShows), and hides in the catching areas.
-- The points come from model pivots, so a marker shows before the parts stream in.
--
-- Roblox terms: a BillboardGui draws 2D UI at a 3D point, facing the camera; AlwaysOnTop shows it through walls.
-- Each one is adorned to an Attachment in Terrain at the marker's point.

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
	setZone: (self: LocationMarkers, zone: string?) -> (),
	destroy: (self: LocationMarkers) -> (),
}

local ICON = 46
local WIDTH = 160
local HEIGHT = ICON + 40
local FADE_STEP = 0.1 -- seconds between distance checks
local POINT_STEP = 1 -- seconds between looking the points up again (a plot is claimed, the cart comes or goes)
local STUDS_PER_METRE = 3.57 -- as the carry marker (Components/WorldMarker)
local HOME_LIFT = 18
local CART_LIFT = 12 -- over the dealer's head and his Shop pill (4 studs up)

local LocationMarkers = {}
LocationMarkers.__index = LocationMarkers

type Spec = {
	key: string,
	name: string,
	glyph: string,
	colour: Color3,
	find: () -> Vector3?,
	inZone: ((zone: string?) -> boolean)?, -- where the player must stand for it to show; nil is anywhere
}

-- One icon with its name and distance: the billboard and the parts that fade.
type Marker = {
	spec: Spec,
	point: Vector3?,
	size: number, -- the scale last applied
	shown: number, -- the alpha last applied, so a still frame costs nothing
	attachment: Attachment,
	billboard: BillboardGui,
	scale: UIScale,
	disc: Frame,
	discStroke: UIStroke,
	glyph: TextLabel,
	name: TextLabel,
	nameStroke: UIStroke,
	sub: TextLabel,
	subStroke: UIStroke,
}

local function ownPlot(): Model?
	local player = Players.LocalPlayer
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot :: Model
		end
	end
	return nil
end

local function homePoint(): Vector3?
	local plot = ownPlot()
	return if plot then plot:GetPivot().Position + Vector3.new(0, HOME_LIFT, 0) else nil
end

-- The dealer's cart while it is out and open (the same check as the Night Market banner in UI/init).
local function cartPoint(): Vector3?
	for _, cart in CollectionService:GetTagged("DealerCart") do
		if
			cart:IsA("Model")
			and cart:IsDescendantOf(Workspace)
			and cart:GetAttribute("Open") ~= false
		then
			return (cart :: Model):GetPivot().Position + Vector3.new(0, CART_LIFT, 0)
		end
	end
	return nil
end

LocationMarkers.SPECS = {
	{
		key = "home",
		name = "My Cafe",
		glyph = Theme.icons.home,
		colour = Theme.colors.gold,
		find = homePoint,
		inZone = Wayfinding.homeShows,
	},
	{
		key = "nightMarket",
		name = "Night Market",
		glyph = Theme.icons.moon,
		colour = Theme.colors.berry,
		find = cartPoint,
	},
} :: { Spec }

local function build(parent: Instance, spec: Spec): Marker
	local attachment: Attachment = Create("Attachment", {
		Name = "CatCafeMarker_" .. spec.key,
		Parent = Workspace.Terrain,
	})
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeMarker_" .. spec.key,
		Adornee = attachment,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		MaxDistance = math.huge,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	-- everything sits in one full-size frame that a UIScale shrinks, while the billboard's own size follows it
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Parent = billboard,
	})
	local scale: UIScale = Create("UIScale", { Parent = root })
	local disc: Frame = Create("Frame", {
		Name = "Icon",
		BackgroundColor3 = spec.colour,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local discStroke = Outline.border(disc, 3, Theme.colors.white)
	local glyph: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 24,
		TextColor3 = Theme.colors.white,
		Text = spec.glyph,
		Parent = disc,
	})
	IconArt.set(glyph, spec.glyph, 0.84)
	local name: TextLabel = Create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, ICON + 2),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = 17,
		TextColor3 = Theme.colors.white,
		Text = spec.name,
		Parent = root,
	})
	local nameStroke = Outline.text(name, 2)
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
	local subStroke = Outline.text(sub, 1.5)
	return {
		spec = spec,
		point = nil,
		size = 1,
		shown = -1,
		attachment = attachment,
		billboard = billboard,
		scale = scale,
		disc = disc,
		discStroke = discStroke,
		glyph = glyph,
		name = name,
		nameStroke = nameStroke,
		sub = sub,
		subStroke = subStroke,
	}
end

function LocationMarkers.new(parent: Instance): LocationMarkers
	local self = setmetatable({}, LocationMarkers) :: any
	self._carrying = false
	self._visible = true
	self._enabled = true -- the Map icons switch in Settings
	self._zone = nil :: string? -- the World.Zones name the player stands in (UI.setZone)
	local markers: { Marker } = {}
	for _, spec in LocationMarkers.SPECS do
		table.insert(markers, build(parent, spec))
	end
	self._markers = markers

	local fadeClock, pointClock = 0, POINT_STEP
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		fadeClock += dt
		pointClock += dt
		if pointClock >= POINT_STEP then
			pointClock = 0
			self:_findPoints()
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

-- The player's Map icons setting; off hides the markers until it is turned back on.
function LocationMarkers.setEnabled(self: any, enabled: boolean)
	self._enabled = enabled
	self:_fade()
end

-- The World.Zones name the player stands in: the My Cafe marker hides in the catching areas.
function LocationMarkers.setZone(self: any, zone: string?)
	self._zone = zone
	self:_fade()
end

-- Each marker looks its point up again; nil (no plot yet, no cart tonight) hides it.
function LocationMarkers._findPoints(self: any)
	for _, marker: Marker in self._markers do
		local point = marker.spec.find()
		marker.point = point
		if point then
			marker.attachment.WorldPosition = point
		end
	end
end

-- Shrinks a marker and its billboard together, in steps so a slow walk does not resize it every check.
local function applySize(marker: Marker, size: number)
	local stepped = math.floor(size * 20 + 0.5) / 20
	if marker.size == stepped then
		return
	end
	marker.size = stepped
	marker.scale.Scale = stepped
	marker.billboard.Size = UDim2.fromOffset(WIDTH * stepped, HEIGHT * stepped)
end

local function applyAlpha(marker: Marker, alpha: number)
	if marker.shown == alpha then
		return
	end
	marker.shown = alpha
	marker.billboard.Enabled = alpha > 0
	local fade = 1 - alpha
	marker.disc.BackgroundTransparency = fade
	marker.discStroke.Transparency = fade
	IconArt.setTransparency(marker.glyph, fade)
	marker.name.TextTransparency = fade
	marker.nameStroke.Transparency = fade
	marker.sub.TextTransparency = fade
	marker.subStroke.Transparency = fade
end

function LocationMarkers._fade(self: any)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local from: Vector3? = if root and root:IsA("BasePart") then root.Position else nil
	local hidden = not self._visible or not self._enabled or self._carrying
	for _, marker: Marker in self._markers do
		local point: Vector3? = marker.point
		local inZone = marker.spec.inZone
		local away = inZone ~= nil and not inZone(self._zone)
		if hidden or away or point == nil or from == nil then
			applyAlpha(marker, 0)
		else
			local distance = ((point :: Vector3) - (from :: Vector3)).Magnitude
			local alpha = Wayfinding.alpha(distance)
			if alpha > 0 then
				marker.sub.Text = ("%d m"):format(math.floor(distance / STUDS_PER_METRE + 0.5))
				applySize(marker, Wayfinding.scale(distance))
			end
			applyAlpha(marker, alpha)
		end
	end
end

function LocationMarkers.destroy(self: any)
	self._loop:Disconnect()
	for _, marker: Marker in self._markers do
		marker.billboard:Destroy()
		marker.attachment:Destroy()
	end
	table.clear(self._markers)
end

return LocationMarkers
