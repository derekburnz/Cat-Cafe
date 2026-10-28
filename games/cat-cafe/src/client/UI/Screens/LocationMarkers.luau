--!strict
-- Location markers (UI plan 2026-10-27, the world icons of Pet Simulator 99 and Grow a Garden): a round icon with the
-- place's name and distance over My Cafe, every area and the night dealer's cart, seen from anywhere on the map.
-- Each fades out between Wayfinding.FAR and Wayfinding.NEAR studs, so the place in front of the player is never
-- covered (Derek: "symbols to locations also that disappear when close enough so its not clutter"), and draws smaller
-- the further away it is (Wayfinding.scale; Derek 2026-10-28: "further away the bubbles should be smaller").
--   My Cafe       over the player's own Plot, gold; hidden while carrying, when the carry marker leads to the door
--   Areas         over the area's gate (tag AreaGate with `Area`), else the middle of its biggest World.Zones box; a
--                 locked area's marker is hidden until the tier opens it, except right by its gate, where it shows a
--                 lock and its tier (Wayfinding.lockedAlpha; Derek 2026-10-28: "hide the tiered map and distance ui
--                 bubbles until unlocked unless standing really close"); the area the player stands in
--                 (UI.setZone) hides its own.
--                 The Alleyway has no gate and two back alleys the same size since v3.1 (F77), so its marker sits in
--                 the one on the player's side, just inside the Town Square's side arch (west with no cafe)
--   Night dealer  over the cart (tag DealerCart) while it is open
--   Town Square   over the Spin Wheel station (tag SpinWheel, F49; the plaza became the Town Square in F76), with a
--                 red dot while a free spin waits
-- Points come from model pivots and the persistent Zones boxes, so markers show before the parts stream in.
--
-- Roblox terms: a BillboardGui draws 2D UI at a 3D point, facing the camera; AlwaysOnTop shows it through walls.
-- Each one here is adorned to an Attachment in Terrain at the marker's point.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)
local Wayfinding = require(script.Parent.Parent.Components.Wayfinding)

export type LocationMarkers = {
	setCatalog: (self: LocationMarkers, catalog: Types.Catalog) -> (),
	render: (self: LocationMarkers, state: Types.PlayerState, carrying: boolean) -> (),
	setZone: (self: LocationMarkers, zone: string?) -> (),
	setVisible: (self: LocationMarkers, visible: boolean) -> (),
	setEnabled: (self: LocationMarkers, enabled: boolean) -> (),
	setPlazaDot: (self: LocationMarkers, on: boolean) -> (),
	destroy: (self: LocationMarkers) -> (),
}

local ICON = 46
local WIDTH = 160
local HEIGHT = ICON + 40
local FADE_STEP = 0.1 -- seconds between distance checks
local POINT_STEP = 1 -- seconds between looking the places up again (a cart arrives, a plot is claimed)
local STUDS_PER_METRE = 3.57 -- as the carry marker (Components/WorldMarker)
local HOME_LIFT = 18
local GATE_LIFT = 16
local CART_LIFT = 10
local PLAZA_LIFT = 16 -- the wheel is about 12 studs tall
local DOT = 18
local ZONE_LIFT = 12

type Marker = {
	key: string,
	billboard: BillboardGui,
	scale: UIScale, -- shrinks the whole marker with distance
	size: number, -- the scale last applied
	attachment: Attachment,
	disc: Frame,
	discStroke: UIStroke,
	glyph: TextLabel,
	name: TextLabel,
	nameStroke: UIStroke,
	sub: TextLabel,
	subStroke: UIStroke,
	dot: Frame?, -- the Plaza's red dot
	dotStroke: UIStroke?,
	color: Color3,
	point: Vector3?,
	locked: boolean,
	lockText: string,
	hidden: boolean,
	shown: number, -- the alpha last applied, so a still frame costs nothing
}

local LocationMarkers = {}
LocationMarkers.__index = LocationMarkers

local function pascal(id: string): string
	return id:sub(1, 1):upper() .. id:sub(2)
end

local function newMarker(
	parent: Instance,
	key: string,
	icon: string,
	label: string,
	color: Color3
): Marker
	local attachment: Attachment = Create("Attachment", {
		Name = "CatCafeMarker_" .. key,
		Parent = Workspace.Terrain,
	})
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeMarker_" .. key,
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
		BackgroundColor3 = color,
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
		Text = icon,
		Parent = disc,
	})
	IconArt.set(glyph, icon, 0.84) -- My Cafe and the Spin Wheel get the drawn icon
	local name: TextLabel = Create("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, ICON + 2),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = 17,
		TextColor3 = Theme.colors.white,
		Text = label,
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
		key = key,
		billboard = billboard,
		scale = scale,
		size = 1,
		attachment = attachment,
		disc = disc,
		discStroke = discStroke,
		glyph = glyph,
		name = name,
		nameStroke = nameStroke,
		sub = sub,
		subStroke = subStroke,
		dot = nil,
		dotStroke = nil,
		color = color,
		point = nil,
		locked = false,
		lockText = "",
		hidden = false,
		shown = -1,
	}
end

-- Shrinks the marker and its billboard together, in steps so a slow walk does not resize it every check.
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
	local dot, dotStroke = marker.dot, marker.dotStroke
	if dot and dotStroke then
		dot.BackgroundTransparency = fade
		dotStroke.Transparency = fade
	end
end

function LocationMarkers.new(parent: Instance): LocationMarkers
	local self = setmetatable({}, LocationMarkers) :: any
	self._parent = parent
	self._markers = {} :: { [string]: Marker }
	self._areas = {} :: { Types.AreaDef }
	self._tier = 1
	self._carrying = false
	self._zoneArea = nil :: string?
	self._visible = true
	self._enabled = true -- the Place icons switch in Settings
	self._home = newMarker(parent, "home", Theme.icons.home, "My Cafe", Theme.colors.gold)
	self._markers.home = self._home
	self._dealer = newMarker(parent, "dealer", "🛒", "Night dealer", Theme.colors.berry)
	self._markers.dealer = self._dealer
	self._plaza = newMarker(parent, "plaza", Theme.icons.spin, "Town Square", Theme.colors.warn)
	self._markers.plaza = self._plaza
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(DOT, DOT),
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = self._plaza.disc,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._plaza.dot = dot
	self._plaza.dotStroke = Outline.border(dot, 2, Theme.colors.white)

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

function LocationMarkers.setCatalog(self: any, catalog: Types.Catalog)
	for key, marker in self._markers do
		if key:sub(1, 5) == "area:" then
			marker.billboard:Destroy()
			marker.attachment:Destroy()
			self._markers[key] = nil
		end
	end
	local areas: { Types.AreaDef } = catalog.areas or {}
	self._areas = areas
	for _, area in areas do
		local key = "area:" .. area.id
		self._markers[key] = newMarker(
			self._parent,
			key,
			(Theme.icons :: any)[area.id] or Theme.icons.travel,
			area.name,
			Theme.areaColors[area.id] or Theme.colors.caramel
		)
	end
	self:_refreshLocks()
	self:_findPoints()
end

function LocationMarkers._refreshLocks(self: any)
	for _, area in self._areas do
		local marker: Marker? = self._markers["area:" .. area.id]
		if marker then
			marker.locked = self._tier < area.tier
			marker.lockText = if marker.locked
				then ("%s %s  ·  "):format(Theme.icons.lock, Format.tier(area.tier))
				else ""
			marker.disc.BackgroundColor3 = if marker.locked
				then Theme.colors.disabledDark
				else marker.color
		end
	end
end

function LocationMarkers.render(self: any, state: Types.PlayerState, carrying: boolean)
	if state.tier ~= self._tier then
		self._tier = state.tier
		self:_refreshLocks()
	end
	self._carrying = carrying
end

function LocationMarkers.setVisible(self: any, visible: boolean)
	self._visible = visible
	self:_fade()
end

-- The player's Place icons setting; off hides every marker until it is turned back on.
function LocationMarkers.setEnabled(self: any, enabled: boolean)
	self._enabled = enabled
	self:_fade()
end

-- A free spin is waiting (F49): the Plaza marker shows a red dot.
function LocationMarkers.setPlazaDot(self: any, on: boolean)
	local dot: Frame? = self._plaza.dot
	if dot then
		dot.Visible = on
	end
end

-- The World.Zones name the player stands in; the area there hides its own marker.
function LocationMarkers.setZone(self: any, zone: string?)
	self._zoneArea = Wayfinding.areaOf(zone)
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

-- The middle of the biggest World.Zones box with this name, a little above its floor; of boxes the same size, the
-- one on `side` of town (-1 west, 1 east, Wayfinding.pickBox).
local function zonePoint(name: string, side: number?): Vector3?
	local world = Workspace:FindFirstChild("World")
	local zones = if world then world:FindFirstChild("Zones") else nil
	if not zones then
		return nil
	end
	local found: { BasePart } = {}
	local sizes: { { area: number, x: number } } = {}
	for _, box in zones:GetChildren() do
		if box:IsA("BasePart") and box.Name == name then
			local part = box :: BasePart
			table.insert(found, part)
			table.insert(sizes, { area = part.Size.X * part.Size.Z, x = part.Position.X })
		end
	end
	local index = Wayfinding.pickBox(sizes, side)
	if not index then
		return nil
	end
	local box: BasePart = found[index]
	return box.Position + Vector3.new(0, -box.Size.Y / 2 + ZONE_LIFT, 0)
end

function LocationMarkers._findPoints(self: any)
	local plot = ownPlot()
	self._home.point = if plot then plot:GetPivot().Position + Vector3.new(0, HOME_LIFT, 0) else nil
	local side: number? = if plot then math.sign(plot:GetPivot().Position.X) else nil

	local gates: { [string]: Model } = {}
	for _, gate in CollectionService:GetTagged("AreaGate") do
		local areaId = gate:GetAttribute("Area")
		if gate:IsA("Model") and typeof(areaId) == "string" then
			gates[areaId] = gate :: Model
		end
	end
	for _, area in self._areas do
		local marker: Marker? = self._markers["area:" .. area.id]
		if marker then
			local gate = gates[area.id]
			marker.point = if gate
				then gate:GetPivot().Position + Vector3.new(0, GATE_LIFT, 0)
				else zonePoint(pascal(area.id), side)
		end
	end

	local cart: Instance? = CollectionService:GetTagged("DealerCart")[1]
	self._dealer.point = if cart
			and cart:IsA("Model")
			and cart:GetAttribute("Open") ~= false
		then cart:GetPivot().Position + Vector3.new(0, CART_LIFT, 0)
		else nil

	local wheel: Instance? = CollectionService:GetTagged("SpinWheel")[1]
	self._plaza.point = if wheel and (wheel:IsA("Model") or wheel:IsA("BasePart"))
		then (wheel :: PVInstance):GetPivot().Position + Vector3.new(0, PLAZA_LIFT, 0)
		else nil

	for _, marker in self._markers do
		local point = marker.point
		if point then
			marker.attachment.WorldPosition = point
		end
	end
end

function LocationMarkers._fade(self: any)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local from: Vector3? = if root and root:IsA("BasePart") then root.Position else nil
	for key, marker in self._markers do
		local point = marker.point
		local hidden = point == nil
			or from == nil
			or not self._visible
			or not self._enabled
			or (key == "home" and self._carrying)
			or (self._zoneArea ~= nil and key == "area:" .. self._zoneArea)
		if hidden or not point or not from then
			applyAlpha(marker, 0)
			continue
		end
		local distance = (point - from).Magnitude
		local alpha = if marker.locked
			then Wayfinding.lockedAlpha(distance)
			else Wayfinding.alpha(distance)
		if alpha > 0 then
			marker.sub.Text = marker.lockText
				.. ("%d m"):format(math.floor(distance / STUDS_PER_METRE + 0.5))
			applySize(marker, Wayfinding.scale(distance))
		end
		applyAlpha(marker, alpha)
	end
end

function LocationMarkers.destroy(self: any)
	self._loop:Disconnect()
	for _, marker in self._markers do
		marker.billboard:Destroy()
		marker.attachment:Destroy()
	end
	table.clear(self._markers)
end

return LocationMarkers
