--!strict
-- Gate signs (F39 P0, copied from Pet Simulator 99 and Bee Swarm Simulator): a sign over every area gate with a
-- lock, the area's name, the tier it needs and the player's own progress toward that tier, one bar per
-- requirement ("3 / 5" different cats, "$900 / $1.5K" coins). Once the gate is open the sign shrinks to a green
-- name plate. Gates are the server's World.Gates models tagged "AreaGate" with `Area` and `RequiresTier`
-- attributes (WorldBuilder); the signs are local BillboardGuis in PlayerGui, so each player sees their own
-- progress. View only: the gate's collision is WorldController's and the server checks the tier anyway.
--
-- Roblox terms: a BillboardGui is 2D UI drawn at a point in the 3D world and always facing the camera. Its
-- Size here is in studs (UDim2 scale), so the sign shrinks with distance like a real sign. CollectionService
-- tags let the client find every gate the server built, including ones that stream in later.

local CollectionService = game:GetService("CollectionService")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local RankUp = require(script.Parent.RankUp)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type GateSigns = {
	setCatalog: (self: GateSigns, catalog: Types.Catalog) -> (),
	render: (self: GateSigns, state: Types.PlayerState) -> (),
	destroy: (self: GateSigns) -> (),
}

local TAG = "AreaGate"
local ROWS = 3
-- Past the 30 stud rule for cat labels: there are only five gates and each is the way to the next goal.
local MAX_DISTANCE = 50
local GAP = 1.2 -- studs between the top of the gate and the bottom of the sign
local LOCKED_SIZE = Vector2.new(11, 6.2) -- studs
local OPEN_SIZE = Vector2.new(8, 2)

type Row = { frame: Frame, fill: Frame, label: TextLabel, status: TextLabel }
type Sign = {
	gate: Instance,
	billboard: BillboardGui,
	card: Frame,
	border: UIStroke,
	header: TextLabel,
	needs: TextLabel,
	hint: TextLabel,
	rows: { Row },
	anchored: boolean, -- the sign has a part to hang from
	open: boolean?,
	connections: { RBXScriptConnection },
}

local GateSigns = {}
GateSigns.__index = GateSigns

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local label: TextLabel = Create("TextLabel", merged)
	Outline.text(label, 2)
	return label
end

-- The part the sign hangs from: the barrier if the gate has one, else any part of the model.
local function anchorPart(gate: Instance): BasePart?
	local bars = gate:FindFirstChild("Bars")
	if bars and bars:IsA("BasePart") then
		return bars :: BasePart
	end
	if gate:IsA("Model") and (gate :: Model).PrimaryPart then
		return (gate :: Model).PrimaryPart
	end
	local found = gate:FindFirstChildWhichIsA("BasePart", true)
	return if found then found :: BasePart else nil
end

local function findArea(catalog: Types.Catalog?, areaId: string?): Types.AreaDef?
	if not catalog or not areaId then
		return nil
	end
	local areas: { Types.AreaDef } = catalog.areas or {}
	for _, area in areas do
		if area.id == areaId then
			return area
		end
	end
	return nil
end

local function findTier(catalog: Types.Catalog?, tier: number): Types.TierDef?
	if not catalog then
		return nil
	end
	local tiers: { Types.TierDef } = catalog.tiers or {}
	for _, def in tiers do
		if def.tier == tier then
			return def
		end
	end
	return nil
end

-- Hangs the sign just above the top of the gate model, whatever its size.
local function place(sign: Sign)
	local part = anchorPart(sign.gate)
	sign.billboard.Adornee = part :: any
	sign.anchored = part ~= nil
	if not part then
		sign.billboard.Enabled = false
		return
	end
	assert(part, "anchor part missing")
	local top = part.Position.Y + part.Size.Y / 2
	if sign.gate:IsA("Model") then
		local boxCFrame, boxSize = (sign.gate :: Model):GetBoundingBox()
		top = math.max(top, boxCFrame.Position.Y + boxSize.Y / 2)
	end
	local height = (if sign.open then OPEN_SIZE else LOCKED_SIZE).Y
	sign.billboard.StudsOffsetWorldSpace =
		Vector3.new(0, top - part.Position.Y + GAP + height / 2, 0)
end

local function buildRow(parent: Frame, index: number): Row
	local frame: Frame = Create("Frame", {
		Name = "Row" .. index,
		BackgroundColor3 = Theme.colors.ink,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.fromScale(1, 0.3),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
	Outline.border(frame, 2)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.35, 0) }) })
	Outline.shade(fill, 0.22)
	local label = text({
		Name = "Label",
		Position = UDim2.fromScale(0.04, 0.1),
		Size = UDim2.fromScale(0.62, 0.8),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = frame,
	})
	local status = text({
		Name = "Status",
		Position = UDim2.fromScale(0.66, 0.1),
		Size = UDim2.fromScale(0.3, 0.8),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = frame,
	})
	return { frame = frame, fill = fill, label = label, status = status }
end

function GateSigns.new(parent: Instance): GateSigns
	local self = setmetatable({}, GateSigns) :: any
	self._parent = parent
	self._signs = {} :: { [Instance]: Sign }
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._connections = {} :: { RBXScriptConnection }

	for _, gate in CollectionService:GetTagged(TAG) do
		self:_attach(gate)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(gate: Instance)
			self:_attach(gate)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(gate: Instance)
			self:_detach(gate)
		end)
	)
	return self :: GateSigns
end

function GateSigns._attach(self: any, gate: Instance)
	if self._signs[gate] then
		return
	end
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "GateSign_" .. tostring(gate:GetAttribute("Area") or gate.Name),
		Size = UDim2.fromScale(LOCKED_SIZE.X, LOCKED_SIZE.Y),
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Enabled = false,
	})
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.hud.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = billboard,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.14, 0) }) })
	local border = Outline.border(card, 3)
	Outline.shade(card, 0.2)
	local header = text({
		Name = "Header",
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.28),
		Parent = card,
	})
	local needs = text({
		Name = "Needs",
		Position = UDim2.fromScale(0.05, 0.34),
		Size = UDim2.fromScale(0.9, 0.16),
		TextColor3 = Theme.colors.gold,
		Parent = card,
	})
	local hint = text({
		Name = "Hint",
		Position = UDim2.fromScale(0.05, 0.6),
		Size = UDim2.fromScale(0.9, 0.18),
		TextColor3 = Theme.hud.subtext,
		Visible = false,
		Parent = card,
	})
	local list: Frame = Create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.54),
		Size = UDim2.fromScale(0.88, 0.42),
		Parent = card,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local rows: { Row } = {}
	for index = 1, ROWS do
		rows[index] = buildRow(list, index)
	end

	local sign: Sign = {
		gate = gate,
		billboard = billboard,
		card = card,
		border = border,
		header = header,
		needs = needs,
		hint = hint,
		rows = rows,
		anchored = false,
		open = nil,
		connections = {},
	}
	self._signs[gate] = sign

	-- The server's placeholder text label on the gate is replaced by this sign. Removing it here only
	-- changes this player's copy.
	local function dropPlaceholder(descendant: Instance)
		if descendant:IsA("BillboardGui") then
			descendant:Destroy()
		end
	end
	for _, descendant in gate:GetDescendants() do
		dropPlaceholder(descendant)
	end
	table.insert(
		sign.connections,
		gate.DescendantAdded:Connect(function(descendant: Instance)
			dropPlaceholder(descendant)
			if descendant:IsA("BasePart") then
				-- a part streamed in late: re-hang the sign on the barrier
				place(sign)
			end
		end)
	)
	table.insert(
		sign.connections,
		gate:GetAttributeChangedSignal("RequiresTier"):Connect(function()
			self:_renderSign(sign)
		end)
	)

	billboard.Parent = self._parent
	place(sign)
	self:_renderSign(sign)
end

function GateSigns._detach(self: any, gate: Instance)
	local sign: Sign? = self._signs[gate]
	if not sign then
		return
	end
	assert(sign, "sign missing")
	for _, connection in sign.connections do
		connection:Disconnect()
	end
	sign.billboard:Destroy()
	self._signs[gate] = nil
end

function GateSigns._renderSign(self: any, sign: Sign)
	local state: Types.PlayerState? = self._state
	local catalog: Types.Catalog? = self._catalog
	if not state or not catalog then
		sign.billboard.Enabled = false
		return
	end
	assert(state and catalog, "state and catalog set")
	local areaId = sign.gate:GetAttribute("Area")
	local area = findArea(catalog, if type(areaId) == "string" then areaId else nil)
	local requiresAttr = sign.gate:GetAttribute("RequiresTier")
	local requires: number = if type(requiresAttr) == "number"
		then requiresAttr
		elseif area then area.tier
		else 1
	local name = if area then area.name else tostring(areaId or sign.gate.Name)
	local icon: string = (Theme.icons :: any)[area and area.id or ""] or Theme.icons.travel
	local tier = state.tier or 1
	local open = tier >= requires

	sign.billboard.Enabled = sign.anchored
	local wasOpen = sign.open
	sign.open = open
	if wasOpen ~= open then
		local size = if open then OPEN_SIZE else LOCKED_SIZE
		sign.billboard.Size = UDim2.fromScale(size.X, size.Y)
		sign.card.BackgroundColor3 = if open then Theme.colors.good else Theme.hud.panel
		sign.border.Color = if open then Theme.colors.goodDark else Theme.colors.outline
		sign.header.Position = if open
			then UDim2.fromScale(0.06, 0.12)
			else UDim2.fromScale(0.05, 0.05)
		sign.header.Size = if open then UDim2.fromScale(0.88, 0.76) else UDim2.fromScale(0.9, 0.28)
		sign.needs.Visible = not open
		place(sign)
	end

	if open then
		sign.header.Text = icon .. " " .. name
		sign.hint.Visible = false
		for _, row in sign.rows do
			row.frame.Visible = false
		end
		return
	end

	sign.header.Text = Theme.icons.lock .. " " .. name
	local needed = findTier(catalog, requires)
	sign.needs.Text = if needed
		then ("Needs %s (Tier %d)"):format(needed.name, requires)
		else ("Needs Tier %d"):format(requires)

	if requires > tier + 1 then
		-- a later gate: point at the next rank up rather than show bars that cannot move yet
		local nextTier = findTier(catalog, tier + 1)
		sign.hint.Text = if nextTier
			then ("Rank up to %s first"):format(nextTier.name)
			else ("Reach Tier %d first"):format(requires - 1)
		sign.hint.Visible = true
		for _, row in sign.rows do
			row.frame.Visible = false
		end
		return
	end

	local progress = self._progress or RankUp.progress(catalog, state)
	self._progress = progress
	sign.hint.Visible = false
	if progress.ready then
		sign.needs.Text = "Ready to rank up!"
	end
	for index, row in sign.rows do
		local item = progress.requirements[index]
		row.frame.Visible = item ~= nil
		if item then
			row.label.Text = item.label
			row.status.Text = if item.met then "✓" else item.status
			row.fill.Size = UDim2.fromScale(math.clamp(item.fraction, 0, 1), 1)
			row.fill.BackgroundColor3 = if item.met then Theme.colors.gold else Theme.colors.mint
		end
	end
end

function GateSigns.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self._progress = nil
	for _, sign in self._signs do
		self:_renderSign(sign)
	end
end

function GateSigns.render(self: any, state: Types.PlayerState)
	self._state = state
	-- one progress per render, shared by every sign
	self._progress = nil
	for _, sign in self._signs do
		self:_renderSign(sign)
	end
end

function GateSigns.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for gate in self._signs do
		self:_detach(gate)
	end
end

return GateSigns
