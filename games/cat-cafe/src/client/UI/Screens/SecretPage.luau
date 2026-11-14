--!strict
-- #4221: the Index's Secret tab (Screens/CatCollection, while the `secretAreas` switch is on), drawn from
-- Components/SecretTabLogic: a header line and the found count over one card per area, in tier order. A found card is
-- dark and starry with the cat's own look, its name and a gold or rainbow dot for the coats owned; a hidden one is the
-- cat's black shape, "???" and the area's hint; a locked one is dimmed with "Tier N"; an area whose Secret is not in
-- the game yet says "Coming soon". A tap on a found card opens the Index's detail card (onSelect).
--   SecretPage.new(parent, position, size, onSelect)
--   page:render(cards)
--   page.frame, page:destroy()

local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Rainbow = require(script.Parent.Parent.Components.Rainbow)
local SecretTabLogic = require(script.Parent.Parent.Components.SecretTabLogic)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type SecretPage = {
	frame: ScrollingFrame,
	render: (self: SecretPage, cards: { SecretTabLogic.Card }) -> (),
	destroy: (self: SecretPage) -> (),
}

local CARD = Vector2.new(132, 184)
local PORTRAIT = 92
local HEADER_H = 46
local HINT_SIZE = 13 -- 9 px on a small phone once the window scales down
local STAR = Color3.fromHex("E2D6FF") -- the Secret starlight (Theme.rarities.Secret.color)
local NIGHT = Color3.fromHex("16161D")
local NIGHT_TOP = Color3.fromHex("3A2F6B")
local HIDDEN = Color3.fromHex("3F332E") -- Theme.dark.card: the Index's not-found tile
local LOCKED = Color3.fromHex("2E2522")
local GOLD_DOT = Color3.fromHex("F4C430")

local SecretPage = {}
SecretPage.__index = SecretPage

local function words(props: { [string]: any }): TextLabel
	local label: TextLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "",
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function SecretPage.new(
	parent: Instance,
	position: UDim2,
	size: UDim2,
	onSelect: (def: Types.CatDef) -> ()
): SecretPage
	local self = setmetatable({}, SecretPage) :: any
	self._onSelect = onSelect
	self._cards = {} :: { [string]: any } -- area id -> its card's parts
	self._order = {} :: { string }
	local frame: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Secret",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Outline.listPadding(10, 8),
	})
	self.frame = frame

	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER_H),
		LayoutOrder = 1,
		Parent = frame,
	})
	self._line = words({
		Name = "Line",
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.index.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -150, 0, 24),
		Parent = header,
	})
	words({
		Name = "Note",
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.index.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -150, 0, 20),
		Text = SecretTabLogic.NOTE,
		Parent = header,
	})
	self._count = words({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 30),
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = STAR,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		Parent = header,
	})
	Outline.text(self._count, 2)

	self._grid = Create("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = 2,
		Parent = frame,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap + 2, Theme.sizes.gap + 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	return self :: SecretPage
end

function SecretPage._card(self: any, area: string, order: number): any
	local found = self._cards[area]
	if found ~= nil then
		found.button.LayoutOrder = order
		return found
	end
	local button: TextButton = Create("TextButton", {
		Name = area,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = HIDDEN,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = self._grid,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local border = Outline.border(button, Theme.sizes.outline)
	local gradient: UIGradient = Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(NIGHT_TOP, NIGHT),
		Enabled = false,
		Parent = button,
	})
	local areaName = words({
		Name = "Area",
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.index.subtext,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, 18),
		ZIndex = 3,
		Parent = button,
	})
	local portrait = CatPortrait.new({
		parent = button,
		size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 22),
		still = true,
		zIndex = 2,
	})
	local mark = words({
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
		TextSize = 54,
		TextColor3 = Theme.index.subtext,
		Text = "?",
		Visible = false,
		ZIndex = 3,
		Parent = button,
	})
	local name = words({
		Name = "Name",
		Position = UDim2.fromOffset(4, PORTRAIT + 24),
		Size = UDim2.new(1, -8, 0, 20),
		TextScaled = true,
		TextWrapped = false,
		ZIndex = 3,
		Parent = button,
	})
	Create("UITextSizeConstraint", {
		MaxTextSize = Theme.sizes.textBody,
		MinTextSize = 9,
		Parent = name,
	})
	Outline.text(name, 2)
	-- up to three lines of small words: Growth-Agent's hints are 48 characters at most
	local hint = words({
		Name = "Hint",
		FontFace = Theme.fonts.body,
		Position = UDim2.fromOffset(4, PORTRAIT + 44),
		Size = UDim2.new(1, -8, 0, CARD.Y - PORTRAIT - 48),
		TextSize = HINT_SIZE,
		TextColor3 = Theme.index.subtext,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = button,
	})
	local dots: Frame = Create("Frame", {
		Name = "Coats",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 24),
		Size = UDim2.fromOffset(16, 40),
		ZIndex = 4,
		Parent = button,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function dot(dotName: string, color: Color3, layoutOrder: number): Frame
		local made: Frame = Create("Frame", {
			Name = dotName,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(16, 16),
			LayoutOrder = layoutOrder,
			Visible = false,
			ZIndex = 4,
			Parent = dots,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(made, 2)
		return made
	end
	local goldDot = dot("Gold", GOLD_DOT, 1)
	local rainbowDot = dot("Rainbow", Theme.colors.white, 2)
	Rainbow.fill(rainbowDot)
	local made = {
		button = button,
		border = border,
		gradient = gradient,
		areaName = areaName,
		portrait = portrait,
		mark = mark,
		name = name,
		hint = hint,
		gold = goldDot,
		rainbow = rainbowDot,
		def = nil :: Types.CatDef?,
		shownId = nil :: string?,
		connection = nil :: RBXScriptConnection?,
	}
	made.connection = button.Activated:Connect(function()
		local def: Types.CatDef? = made.def
		if def ~= nil and made.button:GetAttribute("Found") == true then
			Sound.play("uiTab")
			self._onSelect(def)
		end
	end)
	self._cards[area] = made
	return made
end

function SecretPage.render(self: any, cards: { SecretTabLogic.Card })
	self._line.Text = SecretTabLogic.line(cards)
	self._count.Text = SecretTabLogic.counter(cards)
	local seen: { [string]: boolean } = {}
	for order, card in cards do
		seen[card.area] = true
		local parts = self:_card(card.area, order)
		local isFound = card.state == "found"
		local def = card.def
		parts.def = def
		parts.button:SetAttribute("Found", isFound)
		parts.areaName.Text = card.areaName
		parts.areaName.TextColor3 = if isFound then STAR else Theme.index.subtext
		parts.name.Text = SecretTabLogic.name(card)
		parts.name.TextColor3 = if isFound
			then Theme.colors.white
			elseif card.state == "hidden" then Theme.index.text
			else Theme.index.subtext
		parts.hint.Text = SecretTabLogic.hint(card)
		parts.gradient.Enabled = isFound
		parts.button.BackgroundColor3 = if isFound
			then Theme.colors.white -- under the night gradient
			elseif card.state == "hidden" then HIDDEN
			else LOCKED
		parts.border.Color = if isFound then STAR else Theme.colors.outline
		parts.border.Thickness = Theme.sizes.outline + (if isFound then 1 else 0)
		parts.gold.Visible = card.gold
		parts.rainbow.Visible = card.rainbow
		-- the cat's shape on every card that has one: its look once found, black until then
		local showCat = def ~= nil and card.state ~= "soon"
		parts.portrait.frame.Visible = showCat
		parts.mark.Visible = not showCat
		if showCat and def ~= nil and parts.shownId ~= def.id then
			parts.portrait:set(def, false)
			parts.shownId = if parts.portrait:hasModel() then def.id else nil
		end
		if showCat then
			parts.portrait:setSilhouette(not isFound)
			-- a locked area's shape shows faint (Review-QA in Studio: the portrait's frame is a Frame with no
			-- ImageTransparency, so set it on its ViewportFrame)
			local view = parts.portrait.frame:FindFirstChild("View")
			if view ~= nil and view:IsA("ViewportFrame") then
				view.ImageTransparency = if card.state == "locked" then 0.5 else 0
			end
		end
	end
	for area, parts in self._cards do
		parts.button.Visible = seen[area] == true
	end
end

function SecretPage.destroy(self: any)
	for _, parts in self._cards do
		if parts.connection ~= nil then
			parts.connection:Disconnect()
		end
		parts.portrait:destroy()
	end
	self.frame:Destroy()
end

return SecretPage
