--!strict
-- The Cat room tab of Collection as an inventory (UI plan 2026-10-27, from the Pet Simulator inventory Derek sent:
-- "slots for each role of the cafe and locked if its locked still").
--   Crew strip  a square per role slot in the order they open (Components/StaffSlots): the working cat's own model
--               on its rarity colour, a green "+" for a free slot, a grey lock with the tier that opens it. Tap a
--               cat's square to pick that cat; tap a "+" to put the picked cat to work there.
--   Toolbar     search (name, breed or rarity), All / Working / Resting with counts, Unequip All and Equip Best.
--   Grid        a card per cat in Components/CatRoomList order: model, name, level and rate, the role icon while it
--               works, a sparkle when shiny. Models load as cards scroll near view (reviewer N71).
--   Detail      the picked cat: name with the rename pencil, rarity, level and stars, rate and where it works, its
--               favourite role, then Assign (Move while working), Rest and Sell (Rare and up ask first, with the
--               price). Assign rings every free "+" in gold and marks the cat's favourite role "★ 1.5x".
-- CatCollection owns the tab; this view only reads state and calls back.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatRoomList = require(script.Parent.Parent.Components.CatRoomList)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local RenameDialog = require(script.Parent.RenameDialog)
local Sound = require(script.Parent.Parent.Components.Sound)
local StaffSlots = require(script.Parent.Parent.Components.StaffSlots)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	placeCat: (uid: string, spotId: string) -> (),
	unplaceCat: (uid: string) -> (),
	sellCat: (uid: string) -> (),
	renameCat: (uid: string, name: string) -> (),
	equipBest: () -> (),
	unequipAll: () -> (),
}

export type CatRoom = {
	frame: Frame,
	setCatalog: (self: CatRoom, catalog: Types.Catalog) -> (),
	render: (self: CatRoom, state: Types.PlayerState) -> (),
	reset: (self: CatRoom) -> (),
	destroy: (self: CatRoom) -> (),
}

local GAP = Theme.sizes.gap
local SQUARE = Theme.sizes.touchMin
local CREW_LABEL = 16
local CREW_H = CREW_LABEL + 4 + SQUARE + 8
local TOOL_H = Theme.sizes.touchMin
local SEARCH_W = 180
local CHIP_W = 96
local ACTION_W = 124
local DETAIL_W = 236
local DETAIL_ART = 64
local CARD = Vector2.new(104, 134)
local CARD_ART = 76
local RENAME_W = 34
-- cards this far above or below the visible part of the grid already get their cat model (reviewer N71)
local PORTRAIT_MARGIN = 240
local NOTICE_SECONDS = 3

-- Sell asks for confirmation from this rarity up (data-model: Rare and above), showing the price.
local CONFIRM_SELL_FROM = 2
local RARITY_SELL_VALUE: { [string]: number } =
	{ Common = 25, Rare = 150, Epic = 600, Legendary = 3000, Mythical = 12000 }

local FILTERS: { CatRoomList.Filter } = { "All", "Working", "Resting" }

local CatRoom = {}
CatRoom.__index = CatRoom

local function rarityRank(rarity: string): number
	return table.find(Theme.rarityOrder, rarity) or 0
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function card(props: { [string]: any }): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame: Frame = Create("Frame", merged, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	Outline.border(frame, Theme.sizes.stroke, Theme.modal.cardStroke)
	return frame
end

local function badge(parent: Instance, label: string, color: Color3, textColor: Color3): TextLabel
	return Create("TextLabel", {
		Name = "Badge",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = textColor,
		Text = label,
		ZIndex = 3,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
	})
end

-- "Barista 1" for barista_1
local function slotName(spot: Types.SpotDef?, spotId: string): string
	if spot then
		return Format.roleName(spot.spotType) .. " " .. (spot.id:match("%d+$") or "")
	end
	return spotId
end

function CatRoom.new(parent: Frame, callbacks: Callbacks): CatRoom
	local self = setmetatable({}, CatRoom) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._catById = {} :: { [string]: Types.CatDef }
	self._spotById = {} :: { [string]: Types.SpotDef }
	self._cards = {} :: { [string]: any }
	self._roles = {} :: { any } -- crew strip groups, one per role in catalog order
	self._filter = "All" :: CatRoomList.Filter
	self._query = ""
	self._selected = nil :: string? -- the picked cat's uid
	self._placing = false -- Assign pressed: the next "+" tap puts the picked cat there
	self._confirmSell = false
	self._notice = nil :: string?
	self._noticeToken = 0
	self._state = nil :: Types.PlayerState?
	self._buttons = {} :: { any }
	self._connections = {} :: { RBXScriptConnection }
	self.frame = parent

	-- crew strip: the role slots, scrolling sideways if a later catalog adds more
	local crew = card({
		Name = "Crew",
		Size = UDim2.new(1, 0, 0, CREW_H),
		Parent = parent,
	})
	self._crew = Create("ScrollingFrame", {
		Name = "Roles",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = crew,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 4),
		}),
	})

	-- toolbar: search, filters, then Unequip All and Equip Best on the right
	local toolTop = CREW_H + GAP
	local toolbar: Frame = Create("Frame", {
		Name = "Toolbar",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, toolTop),
		Size = UDim2.new(1, 0, 0, TOOL_H),
		Parent = parent,
	})
	local search: TextBox = Create("TextBox", {
		Name = "Search",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(SEARCH_W, TOOL_H),
		ClearTextOnFocus = false,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.modal.text,
		PlaceholderColor3 = Theme.modal.subtext,
		PlaceholderText = "🔍 Search cats",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = toolbar,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.border(search, Theme.sizes.stroke, Theme.modal.cardStroke)
	self._search = search
	table.insert(
		self._connections,
		search:GetPropertyChangedSignal("Text"):Connect(function()
			self._query = search.Text
			self:_refresh()
		end)
	)

	self._chips = {} :: { [string]: any }
	for index, filter in FILTERS do
		self._chips[filter] = Button.new({
			name = filter,
			text = filter,
			style = if filter == "All" then "gold" else "ghost",
			size = UDim2.fromOffset(CHIP_W, TOOL_H),
			position = UDim2.fromOffset(SEARCH_W + GAP + (index - 1) * (CHIP_W + GAP), 0),
			textSize = Theme.sizes.textSmall,
			parent = toolbar,
			sound = "uiTab",
			onClick = function()
				self._filter = filter
				self:_refresh()
			end,
		})
	end

	-- Equip best: the server fills the open slots with the highest-rated cats (cat stats thread)
	self._equipBest = Button.new({
		name = "EquipBest",
		text = Theme.icons.equipBest .. " Equip Best",
		style = "gold",
		size = UDim2.fromOffset(ACTION_W, TOOL_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = toolbar,
		onClick = function()
			self._callbacks.equipBest()
		end,
	})
	-- Unequip all: every working cat rests (the engineer's UnequipAll remote, one sync)
	self._unequipAll = Button.new({
		name = "UnequipAll",
		text = "Unequip All",
		style = "ghost",
		size = UDim2.fromOffset(ACTION_W, TOOL_H),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -(ACTION_W + GAP), 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = toolbar,
		onClick = function()
			self._placing = false
			self._callbacks.unequipAll()
		end,
	})

	-- body: the grid on the left, the picked cat on the right
	local bodyTop = toolTop + TOOL_H + GAP
	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, bodyTop),
		Size = UDim2.new(1, -(DETAIL_W + GAP), 1, -bodyTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 3),
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 10),
		}),
	})
	local grid: ScrollingFrame = self._grid
	table.insert(
		self._connections,
		grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			self:_loadPortraits()
		end)
	)
	self._empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, bodyTop + 40),
		Size = UDim2.new(1, -(DETAIL_W + GAP), 0, 48),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.modal.subtext,
		Visible = false,
		Parent = parent,
	})

	self:_buildDetail(parent, bodyTop)

	self._rename = RenameDialog.new(parent, function(uid: string, name: string)
		self._callbacks.renameCat(uid, name)
	end)

	return self :: CatRoom
end

function CatRoom._buildDetail(self: any, parent: Frame, top: number)
	local detail = card({
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, top),
		Size = UDim2.new(0, DETAIL_W, 1, -top),
		Parent = parent,
	})
	self._detail = detail
	self._detailEmpty = text({
		Name = "Hint",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.modal.subtext,
		Parent = detail,
	})

	local body: Frame = Create("Frame", {
		Name = "Cat",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = detail,
	})
	self._detailBody = body
	self._detailGlow = Create("Frame", {
		Name = "Glow",
		BackgroundColor3 = Theme.colors.line,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(DETAIL_ART - 8, DETAIL_ART - 8),
		Parent = body,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._detailArt = CatPortrait.new({
		parent = body,
		size = UDim2.fromOffset(DETAIL_ART, DETAIL_ART),
		position = UDim2.fromOffset(8, 8),
		still = true,
		zIndex = 2,
	})
	self._detailArtFor = nil :: string?
	self._detailShiny = badge(body, "✨", Theme.colors.gold, Theme.colors.goldText)
	self._detailShiny.Position = UDim2.fromOffset(4, 4)
	self._detailShiny.Visible = false

	local textLeft = DETAIL_ART + 14
	self._detailName = text({
		Name = "Name",
		Position = UDim2.fromOffset(textLeft, 8),
		Size = UDim2.new(1, -(textLeft + RENAME_W + 10), 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = body,
	})
	self._detailBreed = text({
		Name = "Breed",
		Position = UDim2.fromOffset(textLeft, 32),
		Size = UDim2.new(1, -(textLeft + 8), 0, 18),
		TextSize = Theme.sizes.textSmall,
		Parent = body,
	})
	self._detailStats = text({
		Name = "Stats",
		Position = UDim2.fromOffset(textLeft, 50),
		Size = UDim2.new(1, -(textLeft + 8), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.caramelDark,
		Parent = body,
	})
	table.insert(
		self._buttons,
		Button.new({
			name = "Rename",
			text = "✏️",
			style = "ghost",
			size = UDim2.fromOffset(RENAME_W, 28),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -8, 0, 6),
			textSize = Theme.sizes.textSmall,
			parent = body,
			onClick = function()
				self:_openRename()
			end,
		})
	)
	self._detailRate = text({
		Name = "Rate",
		Position = UDim2.fromOffset(10, DETAIL_ART + 14),
		Size = UDim2.new(1, -20, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = Theme.colors.goodDark,
		Parent = body,
	})
	self._detailInfo = text({
		Name = "Info",
		Position = UDim2.fromOffset(10, DETAIL_ART + 34),
		Size = UDim2.new(1, -20, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Parent = body,
	})
	-- the breed's line from the catalog, where the window is tall enough for it
	local actionsH = Theme.sizes.touchMin
	self._detailDesc = text({
		Name = "Description",
		Position = UDim2.fromOffset(10, DETAIL_ART + 56),
		Size = UDim2.new(1, -20, 1, -(DETAIL_ART + 56 + actionsH + 18)),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.modal.subtext,
		Parent = body,
	})

	local actions: Frame = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -10),
		Size = UDim2.new(1, -16, 0, actionsH),
		Parent = body,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._assign = Button.new({
		name = "Assign",
		text = "Assign",
		style = "primary",
		size = UDim2.new(1 / 3, -4, 1, 0),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 1,
		parent = actions,
		onClick = function()
			self:_pressAssign()
		end,
	})
	self._rest = Button.new({
		name = "Rest",
		text = "Rest",
		style = "ghost",
		size = UDim2.new(1 / 3, -4, 1, 0),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 2,
		parent = actions,
		onClick = function()
			self:_pressRest()
		end,
	})
	self._sell = Button.new({
		name = "Sell",
		text = "Sell",
		style = "danger",
		size = UDim2.new(1 / 3, -4, 1, 0),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 3,
		parent = actions,
		onClick = function()
			self:_pressSell()
		end,
	})
end

function CatRoom.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	table.clear(self._catById)
	for _, def in catalog.cats do
		self._catById[def.id] = def
	end
	table.clear(self._spotById)
	local spots: { Types.SpotDef } = catalog.spots or {}
	for _, spot in spots do
		self._spotById[spot.id] = spot
	end
	-- every card keeps its def, so rebuild them against the new catalog
	for uid in self._cards do
		self:_dropCard(uid)
	end
	self:_buildCrew()
	self:_refresh()
end

-- One group per role: its name over a square per slot. Squares are built once per catalog; render paints them.
function CatRoom._buildCrew(self: any)
	for _, role in self._roles do
		for _, square in role.squares do
			square.portrait:destroy()
		end
		role.frame:Destroy()
	end
	table.clear(self._roles)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog")
	for index, row in StaffSlots.rows(catalog.spots or {}, 1, nil) do
		local group: Frame = Create("Frame", {
			Name = row.role,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, CREW_LABEL + 4 + SQUARE),
			LayoutOrder = index,
			Parent = self._crew,
		})
		local label = text({
			Name = "Role",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, CREW_LABEL),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextTruncate = Enum.TextTruncate.None,
			Text = (Theme.roleIcons[row.role] or "") .. " " .. row.name,
			Parent = group,
		})
		local squaresFrame: Frame = Create("Frame", {
			Name = "Slots",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, CREW_LABEL + 4),
			Size = UDim2.fromOffset(#row.slots * (SQUARE + 6) - 6, SQUARE),
			Parent = group,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local squares = {}
		for slotIndex, slot in row.slots do
			local button: TextButton = Create("TextButton", {
				Name = slot.spotId,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.colors.disabled,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(SQUARE, SQUARE),
				LayoutOrder = slotIndex,
				Parent = squaresFrame,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
			local border = Outline.border(button, Theme.sizes.stroke)
			local portrait = CatPortrait.new({
				parent = button,
				size = UDim2.fromOffset(SQUARE - 4, SQUARE - 4),
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
				still = true,
			})
			portrait.frame.Visible = false
			local glyph = text({
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textBody,
				TextColor3 = Theme.colors.white,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.None,
				ZIndex = 2,
				Parent = button,
			})
			Outline.text(glyph, 1.5)
			local tierTag = text({
				Name = "Tier",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, 0),
				Size = UDim2.fromOffset(SQUARE, 14),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textTiny,
				TextColor3 = Theme.colors.white,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.None,
				ZIndex = 3,
				Parent = button,
			})
			Outline.text(tierTag, 1)
			local square = {
				spotId = slot.spotId,
				tier = slot.tier,
				button = button,
				border = border,
				portrait = portrait,
				glyph = glyph,
				tierTag = tierTag,
				kind = "locked",
				uid = nil :: string?,
				shownUid = nil :: string?,
			}
			table.insert(
				self._connections,
				button.Activated:Connect(function()
					self:_pressSquare(square)
				end)
			)
			table.insert(squares, square)
		end
		table.insert(
			self._roles,
			{ role = row.role, name = row.name, frame = group, label = label, squares = squares }
		)
	end
end

function CatRoom._makeCard(self: any, instance: Types.CatInstance)
	local def: Types.CatDef? = self._catById[instance.catId]
	local rarity = if def then def.rarity else "Common"
	local shiny = CatVariant.isGold(instance.variant)
	local button: TextButton = Create("TextButton", {
		Name = instance.uid,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Parent = self._grid,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		-- the rarity colour washes up from the bottom, like the inventory cards in Pet Simulator 99
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(
				Theme.modal.card,
				Theme.modal.card:Lerp(Theme.rarityColor(rarity), 0.45)
			),
		}),
	})
	-- a shiny cat's card has a thicker gold edge; the picked card a thick sky edge (set in render)
	local stroke: UIStroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if shiny then Theme.colors.gold else Theme.rarityColor(rarity),
		Thickness = Theme.sizes.stroke + (if shiny then 1 else 0),
		Parent = button,
	})
	local portrait = CatPortrait.new({
		parent = button,
		size = UDim2.fromOffset(CARD_ART, CARD_ART),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 6),
		still = true,
		zIndex = 2,
	})
	local role = badge(button, "", Theme.colors.mint, Theme.colors.ink)
	role.Position = UDim2.fromOffset(4, 4)
	role.Visible = false
	if shiny then
		local sparkle = badge(button, "✨", Theme.colors.gold, Theme.colors.goldText)
		sparkle.AnchorPoint = Vector2.new(1, 0)
		sparkle.Position = UDim2.new(1, -4, 0, 4)
	end
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(4, CARD_ART + 10),
		Size = UDim2.new(1, -8, 0, 18),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = button,
	})
	local rate = text({
		Name = "Rate",
		Position = UDim2.fromOffset(4, CARD_ART + 30),
		Size = UDim2.new(1, -8, 0, 16),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.goodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = button,
	})
	local entry = {
		button = button,
		stroke = stroke,
		portrait = portrait,
		loaded = false, -- the model is cloned by _loadPortraits once the card is near the visible window
		role = role,
		name = name,
		rate = rate,
		def = def,
		shiny = shiny,
		rarity = rarity,
	}
	entry.connection = button.Activated:Connect(function()
		Sound.play("uiClick")
		self:_select(instance.uid)
	end)
	return entry
end

function CatRoom._dropCard(self: any, uid: string)
	local entry = self._cards[uid]
	if entry then
		entry.connection:Disconnect()
		entry.portrait:destroy()
		entry.button:Destroy()
		self._cards[uid] = nil
	end
end

-- The cat's coins per second where it works now (1.5x on its favourite role), or what it earns working.
function CatRoom._rateOf(self: any, instance: Types.CatInstance): (number, boolean)
	local def: Types.CatDef? = self._catById[instance.catId]
	local rate = instance.rating or (if def then def.incomePerSecond else 0)
	local spotId = instance.spotId
	local spot: Types.SpotDef? = if spotId then self._spotById[spotId] else nil
	local favorite = def ~= nil and spot ~= nil and def.favoriteRole == spot.spotType
	return rate * (if favorite then 1.5 else 1), favorite
end

function CatRoom._select(self: any, uid: string?)
	if self._selected ~= uid then
		self._placing = false
		self._confirmSell = false
		self._notice = nil
	end
	self._selected = uid
	self:_refresh()
end

function CatRoom._say(self: any, notice: string)
	self._notice = notice
	self._noticeToken += 1
	local token = self._noticeToken
	task.delay(NOTICE_SECONDS, function()
		if self._noticeToken == token and self._notice == notice then
			self._notice = nil
			self:_refresh()
		end
	end)
	self:_refresh()
end

function CatRoom._pressSquare(self: any, square: any)
	if square.kind == "working" and square.uid then
		Sound.play("uiClick")
		self:_select(square.uid)
	elseif square.kind == "open" then
		local uid = self._selected
		if uid then
			Sound.play("uiClick")
			self._placing = false
			self._callbacks.placeCat(uid, square.spotId)
		else
			Sound.play("uiError")
			self:_say("Pick a cat below, then tap a green +.")
		end
	else
		Sound.play("uiError")
		self:_say(("That slot opens at %s."):format(Format.tier(square.tier)))
	end
end

function CatRoom._pressAssign(self: any)
	self._confirmSell = false
	if self._placing then
		self._placing = false
		self:_refresh()
		return
	end
	local free = 0
	for _, role in self._roles do
		for _, square in role.squares do
			if square.kind == "open" then
				free += 1
			end
		end
	end
	if free == 0 then
		self:_say("Every open slot is taken. Rest a cat or rank up for more.")
		return
	end
	self._placing = true
	self:_refresh()
end

function CatRoom._pressRest(self: any)
	local uid = self._selected
	if not uid then
		return
	end
	if self._confirmSell then
		self._confirmSell = false
		self:_refresh()
		return
	end
	self._placing = false
	self._callbacks.unplaceCat(uid)
end

function CatRoom._pressSell(self: any)
	local uid = self._selected
	local state: Types.PlayerState? = self._state
	local cats = if state then state.cats else nil
	local instance = if cats and uid then cats[uid] else nil
	if not (uid and instance) then
		return
	end
	local def: Types.CatDef? = self._catById[instance.catId]
	local needsConfirm = def ~= nil and rarityRank(def.rarity) >= CONFIRM_SELL_FROM
	if needsConfirm and not self._confirmSell then
		self._placing = false
		self._confirmSell = true
		self:_refresh()
		return
	end
	self._confirmSell = false
	self._callbacks.sellCat(uid)
end

function CatRoom._openRename(self: any)
	local uid = self._selected
	local state: Types.PlayerState? = self._state
	local cats = if state then state.cats else nil
	local instance = if cats and uid then cats[uid] else nil
	if not (uid and instance) then
		return
	end
	self._placing = false
	self._confirmSell = false
	local def: Types.CatDef? = self._catById[instance.catId]
	self._rename:open(uid, instance.name, if def then def.name else instance.catId)
end

-- Cancels a half-done pick, sell or rename (the tab was switched or the window closed).
function CatRoom.reset(self: any)
	self._placing = false
	self._confirmSell = false
	self._notice = nil
	self._rename:close()
end

function CatRoom._refresh(self: any)
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function CatRoom.render(self: any, state: Types.PlayerState)
	self._state = state
	local cats: { [string]: Types.CatInstance } = state.cats or {}
	local selected: string? = self._selected
	if selected and cats[selected] == nil then
		-- sold, or gone with a reset: let go of it
		selected = nil
		self._selected = nil
		self._placing = false
		self._confirmSell = false
	end
	if self._rename:editing() and cats[self._rename:editing()] == nil then
		self._rename:close()
	end

	-- toolbar
	local counts = CatRoomList.counts(cats)
	local countOf: { [string]: number } =
		{ All = counts.all, Working = counts.working, Resting = counts.resting }
	for _, filter in FILTERS do
		local chip = self._chips[filter]
		chip:setText(("%s %d"):format(filter, countOf[filter] or 0))
		chip:setStyle(if filter == self._filter then "gold" else "ghost")
	end
	self._equipBest:setEnabled(counts.all > 0)
	self._unequipAll:setEnabled(counts.working > 0)

	-- grid
	local shown = CatRoomList.list(cats, self._catById, rarityRank, self._filter, self._query)
	local order: { [string]: number } = {}
	for index, instance in shown do
		order[instance.uid] = index
	end
	for uid in self._cards do
		if cats[uid] == nil then
			self:_dropCard(uid)
		end
	end
	for uid, instance in cats do
		local entry = self._cards[uid]
		local index = order[uid]
		if index == nil then
			if entry then
				entry.button.Visible = false
			end
			continue
		end
		if not entry then
			entry = self:_makeCard(instance)
			self._cards[uid] = entry
		end
		entry.button.Visible = true
		entry.button.LayoutOrder = index
		local def: Types.CatDef? = entry.def
		local custom = instance.name
		entry.name.Text = if custom and custom ~= ""
			then custom
			elseif def then def.name
			else instance.catId
		local rate = self:_rateOf(instance)
		local level = instance.level
		entry.rate.Text = (if level then Format.level(level) .. "  " else "") .. Format.rate(rate)
		local spotId = instance.spotId
		local spot: Types.SpotDef? = if spotId then self._spotById[spotId] else nil
		entry.role.Visible = spot ~= nil
		if spot then
			entry.role.Text = Theme.roleIcons[spot.spotType] or "✓"
		end
		local picked = uid == selected
		entry.stroke.Color = if picked
			then Theme.colors.sky
			elseif entry.shiny then Theme.colors.gold
			else Theme.rarityColor(entry.rarity)
		entry.stroke.Thickness = if picked
			then 4
			else Theme.sizes.stroke + (if entry.shiny then 1 else 0)
	end
	self._empty.Visible = #shown == 0
	self._empty.Text = if counts.all == 0
		then "No cats yet. Catch one in the Alleyway and walk it home!"
		elseif self._query ~= "" then ('No cats match "%s".'):format(self._query)
		else ("No %s cats right now."):format(string.lower(self._filter))

	self:_renderCrew(state, cats)
	self:_renderDetail(cats)

	-- after the grid layout has placed new cards
	task.defer(function()
		if self.frame.Parent ~= nil then
			self:_loadPortraits()
		end
	end)
end

function CatRoom._renderCrew(
	self: any,
	state: Types.PlayerState,
	cats: { [string]: Types.CatInstance }
)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog")
	local selected: string? = self._selected
	local placingDef: Types.CatDef? = nil
	if self._placing and selected then
		local instance = cats[selected]
		placingDef = if instance then self._catById[instance.catId] else nil
	end
	local rows = StaffSlots.rows(catalog.spots or {}, state.tier, cats)
	for index, row in rows do
		local role = self._roles[index]
		if not (role and role.role == row.role) then
			continue
		end
		local loves = placingDef ~= nil and placingDef.favoriteRole == row.role
		role.label.Text = (Theme.roleIcons[row.role] or "")
			.. " "
			.. row.name
			.. (if loves then "  ★ 1.5x" else "")
		role.label.TextColor3 = if loves then Theme.colors.caramelDark else Theme.modal.text
		for slotIndex, slot in row.slots do
			local square = role.squares[slotIndex]
			if not square then
				continue
			end
			square.kind = slot.kind
			square.uid = slot.catUid
			local instance = if slot.catUid then cats[slot.catUid] else nil
			local color = Theme.colors.disabled
			local glyph = Theme.icons.lock
			if slot.kind == "working" and instance then
				local def: Types.CatDef? = self._catById[instance.catId]
				color = Theme.rarityColor(if def then def.rarity else nil)
				glyph = ""
				if square.shownUid ~= instance.uid then
					square.shownUid = instance.uid
					square.portrait:set(def, CatVariant.isGold(instance.variant))
				end
			elseif slot.kind == "open" then
				color = Theme.colors.good
				glyph = "+"
			end
			if slot.kind ~= "working" and square.shownUid ~= nil then
				square.shownUid = nil
				square.portrait:set(nil)
			end
			square.portrait.frame.Visible = slot.kind == "working"
			square.button.BackgroundColor3 = color
			square.glyph.Text = glyph
			square.glyph.TextSize = if slot.kind == "open"
				then Theme.sizes.textLarge
				else Theme.sizes.textBody
			square.tierTag.Text = if slot.kind == "locked" then "T" .. slot.tier else ""
			-- Assign rings the free slots in gold; the picked cat's own slot gets the sky ring of its card
			local ringed = self._placing and slot.kind == "open"
			local mine = selected ~= nil and slot.catUid == selected
			square.border.Color = if ringed
				then Theme.colors.gold
				elseif mine then Theme.colors.sky
				else Theme.colors.outline
			square.border.Thickness = if ringed or mine then 4 else Theme.sizes.stroke
		end
	end
end

function CatRoom._renderDetail(self: any, cats: { [string]: Types.CatInstance })
	local uid: string? = self._selected
	local instance = if uid then cats[uid] else nil
	self._detailBody.Visible = instance ~= nil
	self._detailEmpty.Visible = instance == nil
	if not instance then
		self._detailEmpty.Text = self._notice
			or (
				if next(cats) == nil
					then "Cats you catch rest here. Put them to work in your crew above to earn."
					else "Tap a cat to see it here, then tap a green + above to put it to work."
			)
		return
	end
	assert(instance, "instance")
	local def: Types.CatDef? = self._catById[instance.catId]
	local breed = if def then def.name else instance.catId
	local rarity = if def then def.rarity else "Common"
	local shiny = CatVariant.isGold(instance.variant)

	if self._detailArtFor ~= instance.uid then
		self._detailArtFor = instance.uid
		self._detailArt:set(def, shiny)
	end
	self._detailGlow.BackgroundColor3 = Theme.rarityColor(rarity)
	self._detailShiny.Visible = shiny

	local custom = instance.name
	self._detailName.Text = if custom and custom ~= "" then custom else breed
	self._detailBreed.Text = ("%s%s %s"):format(if shiny then "Gold " else "", rarity, breed)
	self._detailBreed.TextColor3 = Theme.rarityColor(rarity):Lerp(Theme.colors.ink, 0.25)
	local statBits = {}
	if instance.level then
		table.insert(statBits, Format.level(instance.level))
	end
	if instance.stars then
		table.insert(statBits, Format.stars(instance.stars))
	end
	self._detailStats.Text = table.concat(statBits, "  ")

	local rate, favorite = self:_rateOf(instance)
	local spotId = instance.spotId
	if spotId then
		self._detailRate.Text = ("%s  ·  %s"):format(
			Format.rate(rate),
			slotName(self._spotById[spotId], spotId)
		)
	else
		self._detailRate.Text = Format.rate(rate) .. " when working  ·  Resting"
	end
	local loves = if def and def.favoriteRole then Format.roleName(def.favoriteRole) else nil
	if self._notice then
		self._detailInfo.Text = self._notice
		self._detailInfo.TextColor3 = Theme.colors.warnDark
	elseif self._placing then
		self._detailInfo.Text = "Tap a gold-ringed + above."
		self._detailInfo.TextColor3 = Theme.colors.caramelDark
	else
		self._detailInfo.Text = if loves
			then ("Loves %s%s"):format(
				loves,
				if favorite then "  ·  1.5x now" else "  ·  1.5x there"
			)
			else ""
		self._detailInfo.TextColor3 = if favorite
			then Theme.colors.caramelDark
			else Theme.modal.subtext
	end
	self._detailDesc.Text = if def then def.description or "" else ""

	-- actions: Assign (Move), Rest, Sell; a sell to confirm becomes Cancel and a wide "Sell $150"
	if self._confirmSell then
		local value = RARITY_SELL_VALUE[rarity] or 0
		self._assign.instance.Visible = false
		self._rest:setText("Cancel")
		self._rest:setEnabled(true)
		self._rest.instance.Size = UDim2.new(1 / 3, -3, 1, 0)
		self._sell:setText(if value > 0 then "Sell " .. Format.money(value) else "Confirm")
		self._sell:setStyle("gold")
		self._sell.instance.Size = UDim2.new(2 / 3, -3, 1, 0)
	else
		self._assign.instance.Visible = true
		self._assign:setText(if self._placing then "Cancel" elseif spotId then "Move" else "Assign")
		self._assign:setStyle(if self._placing then "ghost" else "primary")
		self._assign:setEnabled(self._catalog ~= nil)
		self._rest:setText("Rest")
		self._rest:setEnabled(spotId ~= nil)
		self._rest.instance.Size = UDim2.new(1 / 3, -4, 1, 0)
		self._sell:setText("Sell")
		self._sell:setStyle("danger")
		self._sell.instance.Size = UDim2.new(1 / 3, -4, 1, 0)
	end
end

-- N71: a card clones its cat model only once it scrolls near the visible part of the grid, so a big collection
-- pays for the cards on screen. A card whose model is not in Assets yet tries again on the next pass.
function CatRoom._loadPortraits(self: any)
	local grid: ScrollingFrame = self._grid
	if not grid:IsDescendantOf(game) or not self.frame.Visible then
		return
	end
	local top = grid.AbsolutePosition.Y - PORTRAIT_MARGIN
	local bottom = grid.AbsolutePosition.Y + grid.AbsoluteSize.Y + PORTRAIT_MARGIN
	for _, entry in self._cards do
		if entry.loaded or not entry.button.Visible then
			continue
		end
		local y = entry.button.AbsolutePosition.Y
		if y + entry.button.AbsoluteSize.Y >= top and y <= bottom then
			entry.portrait:set(entry.def, entry.shiny) -- a shiny cat in its own coat (F42)
			entry.loaded = entry.portrait:hasModel()
		end
	end
end

function CatRoom.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for uid in self._cards do
		self:_dropCard(uid)
	end
	for _, role in self._roles do
		for _, square in role.squares do
			square.portrait:destroy()
		end
	end
	for _, chip in self._chips do
		chip:destroy()
	end
	for _, button in self._buttons do
		button:destroy()
	end
	self._equipBest:destroy()
	self._unequipAll:destroy()
	self._assign:destroy()
	self._rest:destroy()
	self._sell:destroy()
	self._detailArt:destroy()
	self._rename:destroy()
	self._noticeToken += 1
end

return CatRoom
