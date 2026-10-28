--!strict
-- The cat hover card (F75, data-model section 4b v0.12; Derek 2026-10-27: "when you hover over your cat in cafe it
-- should display what they are and their lvl / xp bar"). A small card over one cat in any cafe:
--   your own cat     a picture of its head beside its name (with the catalog name under it when named), the rarity
--                    badge and a Gold tag, the role with its icon and a heart in its favourite role (or Resting),
--                    "Level 12" and the XP bar with "340 / 1,440 XP", "MAX" at the top level
--   another's cat    a smaller card from the model's attributes: head, name, rarity, Gold, role and level, no bar
-- No charm stars (Derek 2026-10-27: "do a pic of the cats head instead and no stars needed").
-- Mouse: the card shows over the cat under the pointer. Touch: a tap opens it, a second tap on the same cat or a tap
-- elsewhere closes it, and it closes by itself after 4 s. Gamepad: the nearest own cat within 8 studs.
-- Hidden while a window is open or the UI is hidden (the intro). Own cats read ProfileSync's `cats`, so the card
-- costs no network traffic; the server keeps `Level` on every cat model under Plot/Cats for the others.
--
-- Roblox terms: a BillboardGui draws 2D UI at a 3D point (its Adornee) facing the camera; AlwaysOnTop draws it over
-- walls. A raycast with an Include filter can only hit the instances listed, here every cafe's Cats folder.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CatCardLogic = require(script.Parent.Parent.Components.CatCardLogic)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	blocked: () -> boolean, -- a window is open or the UI is hidden
}

export type CatCard = {
	billboard: BillboardGui,
	setCatalog: (self: CatCard, catalog: Types.Catalog) -> (),
	render: (self: CatCard, state: Types.PlayerState) -> (),
	destroy: (self: CatCard) -> (),
}

type Mode = "mouse" | "touch" | "gamepad"

local WIDTH = 252 -- design pixels; Scale maps them to the device
local PAD = 10
local GAP = 4
local HEAD = 60 -- the head picture's disc, left of the name
local TEXT_X = PAD + HEAD + 8
local NAME_H = 24
local SUB_H = 16
local TAGS_H = 22
local ROLE_H = 22
local LOVES_H = 18
local LEVEL_H = 20
local BAR_H = 10
local PILL_H = 20
local TICK = 0.1 -- seconds between pointer checks
local RAY_STUDS = 150
-- studs between the model's top and the card: over the rate tag when it shows (WorldTags: 1.8 tall, 0.3 up)
local OVER_TAG = 2.4
local OVER_CAT = 0.5
local PLOT_TAG = "Plot"
local CATS = "Cats"
local WORKING = "WorkingCat"
local HEART = "♥"
local RESTING_ICON = "💤"
local BAR_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CatCard = {}
CatCard.__index = CatCard

local function modeOf(inputType: Enum.UserInputType): Mode
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	end
	if inputType.Name:sub(1, 7) == "Gamepad" then
		return "gamepad"
	end
	return "mouse"
end

-- The part the card hangs from and how far above its centre the model's top is (as WorldTags does).
local function anchorOf(model: Model): (BasePart?, number)
	local part: BasePart? = model.PrimaryPart
	if not part then
		local found = model:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if not part then
		return nil, 0
	end
	assert(part, "anchor part")
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = math.max(part.Position.Y + part.Size.Y / 2, boxCFrame.Position.Y + boxSize.Y / 2)
	return part, top - part.Position.Y
end

local function label(props: { [string]: any }, children: { Instance }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged, children)
end

local function pill(parent: Instance, name: string, order: number): TextLabel
	return label({
		Name = name,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, PILL_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny + 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

function CatCard.new(parent: Instance, callbacks: Callbacks): CatCard
	local self = setmetatable({}, CatCard) :: any
	self._callbacks = callbacks
	self._cats = {} :: { [string]: Types.CatInstance }
	self._defs = {} :: { [string]: Types.CatDef }
	self._spots = {} :: { [string]: Types.SpotDef }
	self._model = nil :: Model?
	self._shownUid = nil :: string? -- the cat the bar last showed, so a refresh tweens and a new cat jumps
	self._touchUntil = 0
	self._elapsed = 0
	self._mode = modeOf(UserInputService:GetLastInputType())
	self._connections = {} :: { RBXScriptConnection }
	self._watch = {} :: { RBXScriptConnection } -- the shown model's attributes
	self._height = 0

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	self._params = params

	-- The billboard is twice the card's height with the card in its top half, so the card's bottom edge sits on
	-- the point over the cat at any distance.
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeCatCard",
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = math.huge,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	self.billboard = billboard
	local holder: Frame = Create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WIDTH, 100),
		Parent = billboard,
	})
	self._holder = holder
	self._uiScale = Create("UIScale", { Parent = holder })
	local card: Frame = Create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Parent = holder,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(card, Theme.sizes.outline)
	self._card = card

	local disc: Frame = Create("Frame", {
		Name = "Head",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(HEAD, HEAD),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(disc, 1.5, Theme.modal.cardStroke)
	self._headDisc = disc
	self._portrait = CatPortrait.new({ parent = disc, size = UDim2.fromScale(1, 1), head = true })
	self._headKey = nil :: string? -- the cat and coat the picture shows, so a refresh does not rebuild it

	self._name = label({
		Name = "CatName",
		Size = UDim2.new(1, -TEXT_X - PAD, 0, NAME_H),
		FontFace = Theme.fonts.display,
		TextSize = 20,
		Parent = card,
	})
	self._sub = label({
		Name = "CatalogName",
		Size = UDim2.new(1, -TEXT_X - PAD, 0, SUB_H),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.modal.subtext,
		Parent = card,
	})
	local tags: Frame = Create("Frame", {
		Name = "Tags",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -TEXT_X - PAD, 0, TAGS_H),
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
	})
	self._tags = tags
	self._rarity = pill(tags, "Rarity", 1)
	self._gold = pill(tags, "Gold", 2)
	self._gold.BackgroundColor3 = Theme.colors.gold
	self._gold.TextColor3 = Theme.colors.goldText
	self._gold.Text = "Gold"

	local roleIcon: Frame = Create("Frame", {
		Name = "RoleIcon",
		BackgroundColor3 = Theme.colors.gold:Lerp(Theme.colors.paper, 0.55),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(ROLE_H, ROLE_H),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(roleIcon, 1.5, Theme.modal.cardStroke)
	self._roleIcon = roleIcon
	self._roleGlyph = label({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = roleIcon,
	})
	self._role = label({
		Name = "Role",
		Size = UDim2.new(1, -2 * PAD - ROLE_H - 6, 0, ROLE_H),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody - 1,
		RichText = true,
		Parent = card,
	})

	self._loves = label({
		Name = "Loves",
		Size = UDim2.new(1, -2 * PAD, 0, LOVES_H),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.caramelDark,
		RichText = true,
		Visible = false,
		Parent = card,
	})

	self._level = label({
		Name = "Level",
		Size = UDim2.new(0.45, -PAD, 0, LEVEL_H),
		FontFace = Theme.fonts.display,
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.None,
		Parent = card,
	})
	self._xp = label({
		Name = "Xp",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.55, -PAD, 0, LEVEL_H),
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
	local track: Frame = Create("Frame", {
		Name = "XpBar",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, -2 * PAD, 0, BAR_H),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 1.5, Theme.modal.cardStroke)
	self._track = track
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.good,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	table.insert(
		self._connections,
		UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
			local mode = modeOf(inputType)
			if mode ~= self._mode then
				self._mode = mode
				self:_hide()
			end
		end)
	)
	table.insert(
		self._connections,
		UserInputService.TouchTap:Connect(function(positions: { any }, processed: boolean)
			self:_tap(positions[1], processed)
		end)
	)
	table.insert(
		self._connections,
		RunService.Heartbeat:Connect(function(dt: number)
			self._elapsed += dt
			if self._elapsed >= TICK then
				self._elapsed = 0
				self:_check()
			end
		end)
	)
	local rescale = Scale.changed:Connect(function()
		self:_size()
	end)
	table.insert(self._connections, rescale :: any)
	return self :: CatCard
end

function CatCard.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._defs)
	for _, def in catalog.cats do
		self._defs[def.id] = def
	end
	table.clear(self._spots)
	local spots: { Types.SpotDef } = catalog.spots or {}
	for _, spot in spots do
		self._spots[spot.id] = spot
	end
end

function CatCard.render(self: any, state: Types.PlayerState)
	self._cats = state.cats or {}
	if self._model then
		self:_fill()
	end
end

-- Finding the cat ----------------------------------------------------------------------------------------------

-- The cat model the ray hits first, in any cafe.
function CatCard._catAt(self: any, ray: Ray): Model?
	local folders: { Instance } = {}
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		local cats = plot:FindFirstChild(CATS)
		if cats then
			table.insert(folders, cats)
		end
	end
	if #folders == 0 then
		return nil
	end
	self._params.FilterDescendantsInstances = folders
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * RAY_STUDS, self._params)
	local node: Instance? = if hit then hit.Instance else nil
	while node and not (node:IsA("Model") and node:GetAttribute("Uid") ~= nil) do
		node = node.Parent
	end
	return if node then node :: Model else nil
end

-- The nearest of the player's own cats within GAMEPAD_STUDS of their character.
function CatCard._nearestOwn(_self: any): Model?
	local player = Players.LocalPlayer
	local character = player.Character
	local root = if character
		then character:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	if not root then
		return nil
	end
	local points: { [Model]: Vector3 } = {}
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		local cats = plot:GetAttribute("OwnerUserId") == player.UserId and plot:FindFirstChild(CATS)
		if cats then
			for _, cat in cats:GetChildren() do
				if cat:IsA("Model") then
					points[cat :: Model] = (cat :: Model):GetPivot().Position
				end
			end
		end
	end
	return CatCardLogic.nearest(root.Position, points, CatCardLogic.GAMEPAD_STUDS)
end

function CatCard._check(self: any)
	if self._callbacks.blocked() then
		self:_hide()
		return
	end
	local shown: Model? = self._model
	if shown and not shown:IsDescendantOf(Workspace) then
		self:_hide()
		shown = nil
	end
	local mode: Mode = self._mode
	if mode == "touch" then
		if shown and os.clock() > self._touchUntil then
			self:_hide()
		end
		return
	end
	local found: Model? = nil
	if mode == "gamepad" then
		found = self:_nearestOwn()
	else
		local camera = Workspace.CurrentCamera
		if camera then
			local at = UserInputService:GetMouseLocation()
			found = self:_catAt(camera:ViewportPointToRay(at.X, at.Y))
		end
	end
	if found then
		self:_show(found)
	else
		self:_hide()
	end
end

-- A tap opens the card on a cat; a second tap on that cat or a tap anywhere else closes it.
function CatCard._tap(self: any, position: Vector2?, processed: boolean)
	local camera = Workspace.CurrentCamera
	if processed or position == nil or camera == nil or self._callbacks.blocked() then
		return
	end
	local found = self:_catAt(camera:ScreenPointToRay(position.X, position.Y))
	if found == nil or found == self._model then
		self:_hide()
		return
	end
	self._touchUntil = os.clock() + CatCardLogic.TOUCH_SECONDS
	self:_show(found)
end

-- Showing --------------------------------------------------------------------------------------------------------

function CatCard._show(self: any, model: Model)
	if self._model == model then
		return
	end
	self:_unwatch()
	local part, height = anchorOf(model)
	if not part then
		self:_hide()
		return
	end
	self._model = model
	self._height = height
	self.billboard.Adornee = part
	local function refresh()
		self:_fill()
	end
	for _, attribute in { "Level", "Role", "Napping", "Rate", "DisplayName", "Gold" } do
		table.insert(self._watch, model:GetAttributeChangedSignal(attribute):Connect(refresh))
	end
	self:_fill()
	self.billboard.Enabled = true
	Tween.popIn(self._card, 0.85)
end

function CatCard._hide(self: any)
	if self._model == nil then
		return
	end
	self:_unwatch()
	self._model = nil
	self._shownUid = nil
	self.billboard.Enabled = false
	self.billboard.Adornee = nil
	self._portrait:set(nil) -- drops the clone and stops its sway while nothing shows
	self._headKey = nil
end

function CatCard._unwatch(self: any)
	for _, connection in self._watch do
		connection:Disconnect()
	end
	table.clear(self._watch)
end

-- Rows from the top; returns the card's height. Rows that do not show take no room. The head and the name block sit
-- side by side, each centred on the taller of the two.
function CatCard._layout(
	self: any,
	sub: boolean,
	own: boolean,
	level: boolean,
	loves: boolean
): number
	local textHeight = NAME_H + (if sub then SUB_H else 0) + GAP + TAGS_H
	local block = math.max(HEAD, textHeight)
	self._headDisc.Position = UDim2.fromOffset(PAD, PAD + math.floor((block - HEAD) / 2))
	local y = PAD - 2 + math.floor((block - textHeight) / 2)
	self._name.Position = UDim2.fromOffset(TEXT_X, y)
	y += NAME_H
	self._sub.Visible = sub
	if sub then
		self._sub.Position = UDim2.fromOffset(TEXT_X, y - 2)
		y += SUB_H
	end
	y += GAP
	self._tags.Position = UDim2.fromOffset(TEXT_X, y)
	y = PAD + block + GAP + 2
	self._roleIcon.Position = UDim2.fromOffset(PAD, y)
	self._role.Position = UDim2.fromOffset(PAD + ROLE_H + 6, y)
	y += ROLE_H
	self._loves.Visible = loves
	if loves then
		self._loves.Position = UDim2.fromOffset(PAD, y + 2)
		y += LOVES_H + 2
	end
	self._level.Visible = level
	self._xp.Visible = level and own
	self._track.Visible = level and own
	if level then
		y += GAP + 2
		self._level.Position = UDim2.fromOffset(PAD, y)
		self._xp.Position = UDim2.new(1, -PAD, 0, y)
		y += LEVEL_H
		if own then
			y += GAP
			self._track.Position = UDim2.fromOffset(PAD, y)
			y += BAR_H
		end
	end
	return y + PAD
end

function CatCard._size(self: any)
	local height: number = self._cardHeight or 100
	local scale = Scale.get()
	self._uiScale.Scale = scale
	self._holder.Size = UDim2.fromOffset(WIDTH, height)
	self.billboard.Size = UDim2.fromOffset(WIDTH * scale, 2 * height * scale)
end

function CatCard._fill(self: any)
	local model: Model? = self._model
	if model == nil then
		return
	end
	local uid = model:GetAttribute("Uid")
	local catId = model:GetAttribute("CatId")
	local own = model:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
	local instance: Types.CatInstance? = if own and type(uid) == "string"
		then self._cats[uid]
		else nil
	local def: Types.CatDef? = if type(catId) == "string" then self._defs[catId] else nil
	local catalogName = if def then def.name elseif type(catId) == "string" then catId else "Cat"

	-- names: ProfileSync's for an own cat, else the server's filtered DisplayName
	local custom: string? = nil
	if instance then
		custom = instance.name
	else
		local shown = model:GetAttribute("DisplayName")
		custom = if type(shown) == "string" then shown else nil
	end
	local title, under = CatCardLogic.names(custom, catalogName)
	self._name.Text = title
	self._sub.Text = under or ""

	local rarityAttribute = model:GetAttribute("Rarity")
	local rarity = if def
		then def.rarity
		elseif type(rarityAttribute) == "string" then rarityAttribute
		else "Common"
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	local gold = if instance
		then CatVariant.isGold(instance.variant)
		else model:GetAttribute("Gold") == true
	self._gold.Visible = gold

	-- the head: the gold coat's own model for a gold cat, rebuilt only when the cat or its coat changes
	self._headDisc.BackgroundColor3 = Theme.rarityColor(rarity):Lerp(Theme.colors.paper, 0.7)
	local headKey = ("%s/%s"):format(if def then def.id else "", if gold then "gold" else "base")
	if headKey ~= self._headKey then
		self._headKey = headKey
		self._portrait:set(def, gold)
	end

	-- the role: an own cat's slot from ProfileSync, else the model's Role (working cats only)
	local role: string? = nil
	if instance then
		local spotId = instance.spotId
		local spot: Types.SpotDef? = if spotId then self._spots[spotId] else nil
		role = if spot then spot.spotType else nil
	else
		local attribute = model:GetAttribute("Role")
		role = if type(attribute) == "string" then attribute else nil
	end
	local loves: string? = if def then def.favoriteRole else nil
	local roleText, favourite = CatCardLogic.role(role, loves)
	self._roleGlyph.Text = if role then Theme.roleIcons[role] or "✓" else RESTING_ICON
	self._role.TextColor3 = if role then Theme.modal.text else Theme.modal.subtext
	self._role.Text = if favourite
		then ('%s  <font color="#%s">%s</font>'):format(
			roleText,
			Theme.colors.berryDark:ToHex(),
			HEART
		)
		else roleText
	-- resting or in another role: a line under it with where the cat would rather be (Derek 2026-10-28: the
	-- favourite role in bold with its icon)
	local lovesShows = loves ~= nil and not favourite
	self._loves.Text = if loves then Format.lovesRole(loves) else ""

	-- the level: ProfileSync's for an own cat, else the model's Level
	local level: number? = nil
	if instance then
		level = instance.level
	else
		local attribute = model:GetAttribute("Level")
		level = if type(attribute) == "number" then attribute else nil
	end
	local hasLevel = level ~= nil
	if level then
		self._level.Text = CatCardLogic.levelText(level)
	end
	local withBar = instance ~= nil and hasLevel
	if instance and level then
		local text, share = CatCardLogic.xp(level, instance.xp or 0, instance.xpToNext)
		local max = text == "MAX"
		self._xp.Text = text
		self._xp.FontFace = if max then Theme.fonts.display else Theme.fonts.body
		self._xp.TextColor3 = if max then Theme.colors.goldDark else Theme.modal.subtext
		self._fill.BackgroundColor3 = if max then Theme.colors.gold else Theme.colors.good
		local size = UDim2.fromScale(share, 1)
		-- the same cat's bar slides up as XP comes in; a new cat, or a level up's reset, jumps
		if self._shownUid == uid and share >= self._fill.Size.X.Scale then
			Tween.to(self._fill, BAR_TWEEN, { Size = size })
		else
			self._fill.Size = size
		end
		self._shownUid = uid
	end

	self._cardHeight = self:_layout(under ~= nil, withBar, hasLevel, lovesShows)
	self:_size()
	local tagShows = CollectionService:HasTag(model, WORKING)
		and model:GetAttribute("Napping") ~= true
		and (tonumber(model:GetAttribute("Rate")) or 0) > 0
	self.billboard.StudsOffsetWorldSpace =
		Vector3.new(0, self._height + (if tagShows then OVER_TAG else OVER_CAT), 0)
end

function CatCard.destroy(self: any)
	self:_unwatch()
	self._portrait:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self.billboard:Destroy()
end

return CatCard
