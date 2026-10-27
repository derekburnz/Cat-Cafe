--!strict
-- Labels over the role slots of your own cafe, like the locked pads and empty "+" slots of Roblox tycoons, at most
-- one per role (Components/SlotLabelState decides which):
--   a green pill with a plus over a free slot, "Barista" over "Tap to add a cat", which opens the cat room;
--   else a dark pill with a gold lock over the role's next locked slot, "Barista" over "Opens at Tier 3".
-- The pills are sized in studs, so they shrink with distance and walls hide them, and they hang above the cats'
-- rate tags with a pointer down to the slot. Other cafes show no slot labels: the server's plain LockLabel text
-- overlapped the HUD and showed from inside other cafes (QA 2026-10-26), so it is hidden on this client for every
-- plot and stays as the fallback.
--
--   setCatalog(catalog)  the role slots (catalog.spots)
--   render(state)        tier and cats from the player state
--
-- Roblox terms: plots are the server's models tagged "Plot"; a slot is the part Plot/Spots/<spotId>. A
-- BillboardGui sized in UDim2 scale is that many studs across, and it passes taps to its buttons only when Active.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local SlotLabelState = require(script.Parent.Parent.Components.SlotLabelState)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	openCatRoom: () -> (),
}

export type SlotLabels = {
	setCatalog: (self: SlotLabels, catalog: Types.Catalog) -> (),
	render: (self: SlotLabels, state: Types.PlayerState) -> (),
	destroy: (self: SlotLabels) -> (),
}

local TAG = "Plot"
local SERVER_LABEL = "LockLabel"
local SIZE = UDim2.fromScale(4.4, 1.75) -- studs: the pill and the pointer under it
local PILL_HEIGHT = 0.72 -- of SIZE
local OFFSET = 5.2 -- studs above the slot point to the label's centre, clear of a working cat's rate tag
local MAX_DISTANCE = 36
local PLUS = "+"

type Pill = {
	gui: BillboardGui,
	button: TextButton,
	pointer: Frame,
	border: UIStroke,
	badge: TextLabel,
	title: TextLabel,
	sub: TextLabel,
	kind: SlotLabelState.Kind?,
}

local SlotLabels = {}
SlotLabels.__index = SlotLabels

function SlotLabels.new(parent: Instance, callbacks: Callbacks): SlotLabels
	local self = setmetatable({}, SlotLabels) :: any
	self._parent = parent
	self._callbacks = callbacks
	self._spots = {} :: { Types.SpotDef }
	self._tier = 1
	self._cats = nil :: { [string]: Types.CatInstance }?
	self._own = nil :: Instance?
	self._pills = {} :: { [string]: Pill }
	self._plots = {} :: { [Instance]: { RBXScriptConnection } }
	self._hidden = setmetatable({} :: { [TextLabel]: boolean }, { __mode = "k" }) -- weak: labels can go
	self._connections = {} :: { RBXScriptConnection }

	for _, plot in CollectionService:GetTagged(TAG) do
		self:_attach(plot)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(plot: Instance)
			self:_attach(plot)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(plot: Instance)
			self:_detach(plot)
		end)
	)
	self:_findOwn()
	return self :: SlotLabels
end

local function isMine(plot: Instance): boolean
	local userId = plot:GetAttribute("OwnerUserId")
	return Players.LocalPlayer ~= nil
		and type(userId) == "number"
		and userId == Players.LocalPlayer.UserId
end

-- The server's label text, hidden on this client only. Its children can replicate after the billboard.
function SlotLabels._hideServerText(self: any, instance: Instance)
	local parent = instance.Parent
	if
		instance:IsA("TextLabel")
		and parent ~= nil
		and parent.Name == SERVER_LABEL
		and parent:IsA("BillboardGui")
	then
		local text = instance :: TextLabel
		text.Visible = false
		self._hidden[text] = true
	end
end

function SlotLabels._attach(self: any, plot: Instance)
	if self._plots[plot] then
		return
	end
	local connections: { RBXScriptConnection } = {}
	self._plots[plot] = connections
	for _, descendant in plot:GetDescendants() do
		self:_hideServerText(descendant)
	end
	table.insert(
		connections,
		plot.DescendantAdded:Connect(function(descendant: Instance)
			self:_hideServerText(descendant)
			-- a slot of your own cafe streamed in
			local parent = descendant.Parent
			if
				plot == self._own
				and parent ~= nil
				and parent.Name == "Spots"
				and descendant:IsA("BasePart")
			then
				self:_refresh()
			end
		end)
	)
	table.insert(
		connections,
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			self:_findOwn()
		end)
	)
	if isMine(plot) then
		self:_findOwn()
	end
end

function SlotLabels._detach(self: any, plot: Instance)
	local connections = self._plots[plot]
	if not connections then
		return
	end
	self._plots[plot] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	if plot == self._own then
		self:_findOwn()
	end
end

function SlotLabels._findOwn(self: any)
	local own: Instance? = nil
	for plot in self._plots do
		if isMine(plot) then
			own = plot
			break
		end
	end
	self._own = own
	self:_refresh()
end

function SlotLabels._makePill(self: any, spotId: string): Pill
	local gui: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeSlot_" .. spotId,
		Active = false,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		ResetOnSpawn = false,
		Size = SIZE,
		StudsOffsetWorldSpace = Vector3.new(0, OFFSET, 0),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self._parent,
	})
	local button: TextButton = Create("TextButton", {
		Name = "Pill",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, PILL_HEIGHT),
		Text = "",
		ZIndex = 2,
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local border = Outline.border(button, 2, Theme.colors.outline)
	Outline.shade(button)
	-- a diamond behind the pill's bottom edge: its lower half is the pointer down to the slot
	local pointer: Frame = Create("Frame", {
		Name = "Pointer",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, PILL_HEIGHT),
		Size = UDim2.fromScale(0.34, 0.34),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Rotation = 45,
		ZIndex = 1,
		Parent = gui,
	})
	Outline.border(pointer, 2, Theme.colors.outline)
	-- the round badge on the left: a lock on gold, or a plus on white
	local badge: TextLabel = Create("TextLabel", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.04, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.goodDark,
		Text = Theme.icons.lock,
		ZIndex = 3,
		Parent = button,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0.16, 0),
			PaddingBottom = UDim.new(0.16, 0),
			PaddingLeft = UDim.new(0.16, 0),
			PaddingRight = UDim.new(0.16, 0),
		}),
	})
	Outline.border(badge, 2, Theme.colors.outline)
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.3, 0.1),
		Size = UDim2.fromScale(0.64, 0.48),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 3,
		Parent = button,
	})
	Outline.text(title, 1.5)
	local sub: TextLabel = Create("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.3, 0.58),
		Size = UDim2.fromScale(0.64, 0.3),
		FontFace = Theme.fonts.body,
		TextScaled = true,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 3,
		Parent = button,
	})
	button.Activated:Connect(function()
		if gui.Active then
			Tween.popIn(button, 0.9)
			self._callbacks.openCatRoom()
		end
	end)
	local pill: Pill = {
		gui = gui,
		button = button,
		pointer = pointer,
		border = border,
		badge = badge,
		title = title,
		sub = sub,
		kind = nil,
	}
	self._pills[spotId] = pill
	return pill
end

local function paint(pill: Pill, label: SlotLabelState.Label)
	local open = label.kind == "open"
	local fill = if open then Theme.colors.good else Theme.colors.cocoaDeep
	pill.button.BackgroundColor3 = fill
	pill.pointer.BackgroundColor3 = fill
	pill.border.Color = if open then Theme.colors.goodDark else Theme.colors.outline
	pill.badge.BackgroundColor3 = if open then Theme.colors.white else Theme.colors.gold
	pill.badge.Text = if open then PLUS else Theme.icons.lock
	pill.title.Text = label.title
	pill.sub.Text = label.sub
	pill.sub.TextColor3 = if open then Theme.colors.paper else Theme.hud.subtext
	pill.gui.Active = label.tappable
end

function SlotLabels._refresh(self: any)
	local own: Instance? = self._own
	local wanted: { [string]: SlotLabelState.Label } = {}
	if own then
		wanted = SlotLabelState.labels(self._spots, self._tier, self._cats)
	end
	local folder = if own then (own :: Instance):FindFirstChild("Spots") else nil
	for spotId, label in wanted do
		local found = if folder then folder:FindFirstChild(spotId) else nil
		if found and found:IsA("BasePart") then
			local pill: Pill = self._pills[spotId] or self:_makePill(spotId)
			pill.gui.Adornee = found :: BasePart
			paint(pill, label)
			if pill.kind ~= label.kind or not pill.gui.Enabled then
				pill.gui.Enabled = true
				Tween.popIn(pill.button, 0.6)
			end
			pill.kind = label.kind
		end
	end
	for spotId, pill in self._pills do
		local found = if folder then folder:FindFirstChild(spotId) else nil
		if wanted[spotId] == nil or found == nil then
			pill.gui.Enabled = false
			pill.gui.Active = false
			pill.kind = nil
		end
	end
end

function SlotLabels.setCatalog(self: any, catalog: Types.Catalog)
	self._spots = catalog.spots or {}
	self:_refresh()
end

function SlotLabels.render(self: any, state: Types.PlayerState)
	self._tier = state.tier
	self._cats = state.cats
	self:_refresh()
end

function SlotLabels.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, connections in self._plots do
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	table.clear(self._plots)
	for text in self._hidden do
		if text.Parent then
			text.Visible = true
		end
	end
	table.clear(self._hidden)
	for _, pill in self._pills do
		pill.gui:Destroy()
	end
	table.clear(self._pills)
	self._own = nil
end

return SlotLabels
