--!strict
-- The Oasis Spa's card (#2651 part 4, late-stations.md section 1; #2904), opened by its prompt at the Desert camp
-- (UI.lateStations.open("spa")). Three slots side by side:
--   a cat soaking: its picture, name, "Lv 37 → 40" and "+3 levels · next in 12m" (or "First level in 42m", or
--     "+24 levels · full"), with Take out while it has no level yet, which asks first ("Take Mochi out now? It won't
--     level up.");
--   an empty slot: Add a cat, which turns the card to a list of the cats that can go in (below the top level, not
--     soaking, best first), each with Relax. #3136 (Derek2: "make it so you can search your cats and it shows a
--     little face so you can tell which make sure it doesn't cause lag"): the list has a search box and All /
--     Resting / Working, and each row shows the cat's face. To stay light with hundreds of cats its rows are built
--     once when it opens (a few a frame past the first screenful) and again only when the cats that can go in
--     change; typing only hides and shows rows; a face loads when its row is near the visible part, FACES_PER_PASS
--     at a time, and is let go when its row is far off again; and closing the list frees them all;
--   the next slot to open: its golden fish price (100, then 250), greyed while the player has too few; a slot after
--     it reads "Open slot 2 first".
-- Under them Collect takes every slot with a level waiting ("Collect +7 levels"), and a line says how many golden
-- fish the player has. A press rests every button until the next LateStationsState or a refusal (refused), or
-- PENDING_SECONDS. The server checks everything again and toasts each level up ("Mochi relaxed: Lv 37 → 38!").
-- Nothing is sold for Robux. Words and rules in Components/LateStationsLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local LateStationsLogic = require(script.Parent.Parent.Components.LateStationsLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ShortNumber = require(script.Parent.Parent.Components.ShortNumber)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
local SharedTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local PAL = Theme.dark

export type Callbacks = {
	put: (slot: number, uid: string) -> (),
	takeOut: (slot: number) -> (),
	collect: () -> (),
	buy: (slot: number) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the spa: the card closes
}

export type OasisSpa = {
	frame: Frame,
	setView: (self: OasisSpa, spa: SharedTypes.SpaView?) -> (),
	render: (self: OasisSpa, state: Types.PlayerState) -> (),
	opened: (self: OasisSpa) -> (),
	closed: (self: OasisSpa) -> (),
	refused: (self: OasisSpa) -> (),
	destroy: (self: OasisSpa) -> (),
}

type Tile = {
	frame: Frame,
	portrait: CatPortrait.CatPortrait,
	loaded: string?, -- the catId and coat the portrait holds
	glyph: TextLabel,
	name: TextLabel,
	level: TextLabel,
	line: TextLabel,
	action: Button.Button,
	label: string?,
	style: string?,
	enabled: boolean?,
}

local MAX_SIZE = Vector2.new(540, 372)
local TILE_GAP = 10
local PICTURE = 64
local PENDING_SECONDS = 5
local ROW_H = 52
local FACE = 44
local TOOL_H = 34
local CHIP_W = 78
local FIRST_ROWS = 12 -- built at once when the list opens: more than a screenful
local ROWS_PER_FRAME = 20 -- then this many a frame
local FACES_PER_PASS = 15
local FACE_MARGIN = 240 -- a face loads once its row is this near the visible part of the list (as the Cats window)
-- a face is let go again once its row is this far from the visible part (about three screens of the list), so
-- scrolling through hundreds of cats never holds hundreds of cat models (QA-Planner on #3142: 315 faces stayed)
local FACE_KEEP = 720
local SEARCH_WAIT = 0.15 -- typing settles this long before the rows are filtered

type Row = {
	frame: Frame,
	disc: Frame,
	button: Button.Button,
	cat: SharedTypes.CatView,
	portrait: CatPortrait.CatPortrait?,
	loaded: boolean,
}
local GAP = Theme.sizes.gap

local OasisSpa = {}
OasisSpa.__index = OasisSpa

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- A page over the card's content (a list, a question): a little past its edges, so the tiles' outlines don't show.
-- `z` lifts a question over a list.
local function sheet(name: string, parent: Instance, z: number?): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 8),
		Visible = false,
		ZIndex = z or 5,
		Parent = parent,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
end

function OasisSpa.new(callbacks: Callbacks): OasisSpa
	local self = setmetatable({}, OasisSpa) :: any
	self._callbacks = callbacks
	self._spa = nil :: SharedTypes.SpaView?
	self._cats = {} :: { [string]: SharedTypes.CatView }
	self._fish = 0
	self._pending = false
	self._pendingToken = 0
	self._open = false
	self._tick = 0
	self._pickSlot = nil :: number? -- the slot the cat list fills
	self._confirmSlot = nil :: number? -- the slot Take out asks about
	self._rows = {} :: { Row }
	self._rowsKey = nil :: string? -- LateStationsLogic.spaKey of the rows built
	self._buildToken = 0
	self._query = ""
	self._filter = "All"
	self._searchToken = 0
	self._facesQueued = false
	local buttonH = Scale.tapHeight(40, Theme.sizes.buttonDepth)
	self._buttonH = buttonH
	local tileH = PICTURE + 84 + buttonH
	local extra = buttonH - 40

	local panel = Panel.new({
		dark = true,
		name = "OasisSpa",
		title = "Oasis Spa",
		subtitle = "A level for every hour of rest",
		color = Theme.colors.sky,
		icon = LateStationsLogic.ICONS.spa,
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y + extra * 2),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", {
		MaxSize = Vector2.new(MAX_SIZE.X, MAX_SIZE.Y + extra * 2),
		Parent = panel.frame,
	})
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local row: Frame = Create("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tileH),
		Parent = content,
	})
	self._tiles = {} :: { Tile }
	for slot = 1, 3 do
		local frame: Frame = Create("Frame", {
			Name = "Slot" .. slot,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			Position = UDim2.new((slot - 1) / 3, (slot - 1) * TILE_GAP / 3, 0, 0),
			Size = UDim2.new(1 / 3, -TILE_GAP * 2 / 3, 1, 0),
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local portrait = CatPortrait.new({
			parent = frame,
			size = UDim2.fromOffset(PICTURE, PICTURE),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 8),
			still = true,
		})
		local glyph = text({
			Name = "Glyph",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(PICTURE, PICTURE),
			FontFace = Theme.fonts.display,
			TextSize = 40,
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(6, PICTURE + 14),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			Parent = frame,
		})
		local level = text({
			Name = "Level",
			Position = UDim2.fromOffset(6, PICTURE + 36),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			Parent = frame,
		})
		local line = text({
			Name = "Line",
			Position = UDim2.fromOffset(6, PICTURE + 54),
			Size = UDim2.new(1, -12, 0, 18),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		local action = Button.new({
			name = "Action",
			text = "",
			icon = Theme.icons.goldenFish,
			style = "primary",
			size = UDim2.new(1, -16, 0, buttonH),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			textSize = Theme.sizes.textSmall + 1,
			parent = frame,
			onClick = function()
				self:_tilePress(slot)
			end,
		})
		table.insert(self._tiles, {
			frame = frame,
			portrait = portrait,
			loaded = nil,
			glyph = glyph,
			name = name,
			level = level,
			line = line,
			action = action,
			label = nil,
			style = nil,
			enabled = nil,
		})
	end

	self._collect = Button.new({
		name = "Collect",
		text = "Collect",
		style = "primary",
		size = UDim2.fromOffset(240, buttonH + 4),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, tileH + GAP + 2),
		textSize = Theme.sizes.textBody + 1,
		parent = content,
		onClick = function()
			self:_send(function()
				self._callbacks.collect()
			end)
		end,
	})
	self._have = text({
		Name = "Have",
		Position = UDim2.fromOffset(0, tileH + GAP + buttonH + 14),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		Parent = content,
	})
	text({
		Name = "Note",
		Position = UDim2.fromOffset(0, tileH + GAP + buttonH + 34),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		Text = "A cat soaks up a level an hour, up to 24, while you play or are away",
		Parent = content,
	})

	-- the cat list behind Add a cat
	local picker = sheet("Picker", content)
	self._picker = picker
	text({
		Name = "Title",
		Size = UDim2.new(1, -110, 0, 32),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Pick a cat to relax",
		ZIndex = 6,
		Parent = picker,
	})
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(96, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = picker,
		zIndex = 6,
		onClick = function()
			self:_showPicker(nil)
		end,
	})
	-- #3136: search and All / Resting / Working over the list
	local toolTop = buttonH + 6
	local chipsW = #LateStationsLogic.SPA_FILTERS * (CHIP_W + 6)
	local search: TextBox = Create("TextBox", {
		Name = "Search",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, toolTop),
		Size = UDim2.new(1, -(chipsW + 2), 0, TOOL_H),
		ClearTextOnFocus = false,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = PAL.text,
		PlaceholderColor3 = PAL.subtext,
		PlaceholderText = "🔍 Search cats",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 6,
		Parent = picker,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.border(search, Theme.sizes.stroke, PAL.cardStroke)
	self._search = search
	self._searchChanged = search:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = search.Text
		self._searchToken += 1
		local token = self._searchToken
		task.delay(SEARCH_WAIT, function()
			if self._searchToken == token then
				self:_applyFilter()
			end
		end)
	end)
	self._chips = {} :: { [string]: Button.Button }
	for index, filter in LateStationsLogic.SPA_FILTERS do
		self._chips[filter] = Button.new({
			name = filter,
			text = filter,
			style = if filter == "All" then "gold" else "ghost",
			size = UDim2.fromOffset(CHIP_W, TOOL_H),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(
				1,
				-(#LateStationsLogic.SPA_FILTERS - index) * (CHIP_W + 6),
				0,
				toolTop
			),
			textSize = Theme.sizes.textSmall,
			parent = picker,
			zIndex = 6,
			sound = "uiTab",
			onClick = function()
				self:_setFilter(filter)
			end,
		})
	end
	local listTop = toolTop + TOOL_H + 8
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
		Parent = picker,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})
	self._scrolled = (self._list :: ScrollingFrame)
		:GetPropertyChangedSignal("CanvasPosition")
		:Connect(function()
			self:_queueFaces()
		end)
	self._empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, listTop + 20),
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		TextColor3 = PAL.subtext,
		Text = "Every cat you have is at the top level or already relaxing",
		Visible = false,
		ZIndex = 6,
		Parent = picker,
	})

	-- Take out's question
	local confirm = sheet("Confirm", content, 8)
	self._confirm = confirm
	self._ask = text({
		Name = "Ask",
		Position = UDim2.fromScale(0, 0.18),
		Size = UDim2.new(1, 0, 0, 56),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 9,
		Parent = confirm,
	})
	self._takeOut = Button.new({
		name = "TakeOut",
		text = "Take out",
		style = "danger",
		size = UDim2.fromOffset(150, buttonH + 4),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(0.5, -6, 0.18, 76),
		textSize = Theme.sizes.textBody,
		parent = confirm,
		zIndex = 9,
		onClick = function()
			local slot = self._confirmSlot
			self:_showConfirm(nil)
			if slot ~= nil then
				self:_send(function()
					self._callbacks.takeOut(slot)
				end)
			end
		end,
	})
	self._keep = Button.new({
		name = "Keep",
		text = "Keep relaxing",
		style = "primary",
		size = UDim2.fromOffset(150, buttonH + 4),
		position = UDim2.new(0.5, 6, 0.18, 76),
		textSize = Theme.sizes.textBody,
		parent = confirm,
		zIndex = 9,
		onClick = function()
			self:_showConfirm(nil)
		end,
	})
	return self :: OasisSpa
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Every press goes out once: the buttons rest until the server answers (or PENDING_SECONDS).
function OasisSpa._send(self: any, fire: () -> ())
	if self._pending then
		return
	end
	self._pending = true
	self._pendingToken += 1
	local token = self._pendingToken
	task.delay(PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending then
			self._pending = false
			self:_paint()
		end
	end)
	self:_paint()
	fire()
end

function OasisSpa._tilePress(self: any, slot: number)
	local rows = LateStationsLogic.spaRows(self._spa, self._cats, now())
	local row = rows[slot]
	if row == nil or self._pending then
		return
	end
	if row.kind == "empty" then
		self:_showPicker(slot)
	elseif row.kind == "cat" and not row.ready then
		self:_showConfirm(slot)
	elseif row.kind == "buy" and row.price ~= nil and self._fish >= row.price then
		self:_send(function()
			self._callbacks.buy(slot)
		end)
	end
end

function OasisSpa._catName(self: any, uid: string?, catId: string?): string
	local cat: SharedTypes.CatView? = if uid ~= nil then self._cats[uid] else nil
	local id = catId or (if cat ~= nil then cat.catId else nil)
	return CatVariant.name(LateStationsLogic.catName(id), if cat ~= nil then cat.variant else nil)
end

function OasisSpa._showConfirm(self: any, slot: number?)
	self._confirmSlot = slot
	self._confirm.Visible = slot ~= nil
	if slot ~= nil then
		local row = LateStationsLogic.spaRows(self._spa, self._cats, now())[slot]
		self._ask.Text =
			LateStationsLogic.takeOutText(self:_catName(row and row.uid, row and row.catId))
	end
end

function OasisSpa._clearRows(self: any)
	self._buildToken += 1 -- a build still going a few rows a frame stops
	for _, entry: Row in self._rows do
		if entry.portrait then
			entry.portrait:destroy() -- its ViewportFrame and cat model
		end
		entry.button:destroy()
		entry.frame:Destroy()
	end
	table.clear(self._rows)
	self._rowsKey = nil
end

-- The cat list for `slot`, or back to the slots (nil), which frees every row and face.
function OasisSpa._showPicker(self: any, slot: number?)
	self._pickSlot = slot
	self._picker.Visible = slot ~= nil
	if slot == nil then
		self:_clearRows()
		return
	end
	self._search.Text = ""
	self._query = ""
	self._searchToken += 1
	self:_setFilter("All", true)
	self:_buildRows()
end

function OasisSpa._setFilter(self: any, filter: string, quiet: boolean?)
	self._filter = filter
	for name, chip: Button.Button in self._chips do
		chip:setStyle(if name == filter then "gold" else "ghost")
	end
	if not quiet then
		self:_applyFilter()
	end
end

function OasisSpa._row(self: any, order: number, cat: SharedTypes.CatView): Row
	local def = Catalog.getCat(cat.catId)
	local rarity = Theme.rarityColor(if def ~= nil then def.rarity else nil)
	local frame: Frame = Create("Frame", {
		Name = cat.uid,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, math.max(ROW_H, self._buttonH + 8)),
		ZIndex = 6,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
	})
	-- the face's frame in the rarity's colour; the face itself comes when the row is near (_loadFaces)
	local disc: Frame = Create("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(FACE, FACE),
		ZIndex = 7,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = rarity, Thickness = 3 }),
	})
	local left = 8 + FACE + 10
	text({
		Name = "Name",
		Position = UDim2.fromOffset(left, 6),
		Size = UDim2.new(1, -(left + 114), 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = LateStationsLogic.spaTitle(cat),
		ZIndex = 7,
		Parent = frame,
	})
	text({
		Name = "Level",
		Position = UDim2.fromOffset(left, 28),
		Size = UDim2.new(1, -(left + 114), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = LateStationsLogic.spaSubtitle(cat),
		ZIndex = 7,
		Parent = frame,
	})
	local uid = cat.uid
	local button = Button.new({
		name = "Relax",
		text = "Relax",
		style = "primary",
		size = UDim2.fromOffset(100, self._buttonH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, 0),
		textSize = Theme.sizes.textSmall + 1,
		parent = frame,
		zIndex = 7,
		onClick = function()
			local into = self._pickSlot
			self:_showPicker(nil)
			if into ~= nil then
				self:_send(function()
					self._callbacks.put(into, uid)
				end)
			end
		end,
	})
	return { frame = frame, disc = disc, button = button, cat = cat, portrait = nil, loaded = false }
end

-- Builds the list's rows from the cats the player has now: the first FIRST_ROWS at once, the rest ROWS_PER_FRAME a
-- frame, so opening the list never stalls on a big collection.
function OasisSpa._buildRows(self: any)
	self:_clearRows()
	local token = self._buildToken
	local cats = LateStationsLogic.spaCandidates(self._cats, self._spa)
	self._rowsKey = LateStationsLogic.spaKey(cats)
	self._candidates = #cats
	local function build(from: number, to: number)
		for order = from, to do
			local row = self:_row(order, cats[order])
			row.frame.Visible = LateStationsLogic.spaMatch(row.cat, self._query, self._filter)
			table.insert(self._rows, row)
		end
	end
	build(1, math.min(#cats, FIRST_ROWS))
	self:_applyFilter()
	if #cats > FIRST_ROWS then
		task.spawn(function()
			local at = FIRST_ROWS
			while at < #cats do
				task.wait()
				if self._buildToken ~= token then
					return
				end
				build(at + 1, math.min(#cats, at + ROWS_PER_FRAME))
				at += ROWS_PER_FRAME
			end
			self:_applyFilter()
		end)
	end
end

-- The search and the chips only show and hide the rows that are there; none is made or destroyed.
function OasisSpa._applyFilter(self: any)
	local shown = 0
	for _, row: Row in self._rows do
		local visible = LateStationsLogic.spaMatch(row.cat, self._query, self._filter)
		if row.frame.Visible ~= visible then
			row.frame.Visible = visible
		end
		if visible then
			shown += 1
		end
	end
	local none = (self._candidates or 0) == 0
	self._empty.Text = if none
		then "Every cat you have is at the top level or already relaxing"
		else "No cat matches. Try another name."
	self._empty.Visible = none or (shown == 0 and #self._rows >= (self._candidates or 0))
	self:_queueFaces()
end

-- One look for faces on the next frame, however many times it is asked this frame (the rows have their places then).
function OasisSpa._queueFaces(self: any)
	if self._facesQueued then
		return
	end
	self._facesQueued = true
	task.delay(0, function()
		self._facesQueued = false
		self:_loadFaces()
	end)
end

-- A row gets its face (the cat's head, still, as the Cats window's) once it is within FACE_MARGIN of the visible
-- part of the list, at most FACES_PER_PASS a look, and loses it again past FACE_KEEP, so only the faces near the
-- visible rows are ever held.
function OasisSpa._loadFaces(self: any)
	local list: ScrollingFrame = self._list
	if self._pickSlot == nil or not list:IsDescendantOf(game) then
		return
	end
	local top = list.AbsolutePosition.Y - FACE_MARGIN
	local bottom = list.AbsolutePosition.Y + list.AbsoluteSize.Y + FACE_MARGIN
	local made = 0
	for _, row: Row in self._rows do
		local y = row.frame.AbsolutePosition.Y
		local height = row.frame.AbsoluteSize.Y
		if row.loaded then
			-- hidden by the search, or scrolled far off: its face goes, and comes back when the row is near again
			local far = y + height < top - (FACE_KEEP - FACE_MARGIN)
				or y > bottom + (FACE_KEEP - FACE_MARGIN)
			if not row.frame.Visible or far then
				if row.portrait then
					row.portrait:destroy()
					row.portrait = nil
				end
				row.loaded = false
			end
			continue
		end
		if not row.frame.Visible then
			continue
		end
		if y + height < top or y > bottom then
			continue
		end
		if made >= FACES_PER_PASS then
			self:_queueFaces() -- the rest on the next frame
			return
		end
		made += 1
		local portrait = CatPortrait.new({
			parent = row.disc,
			size = UDim2.fromScale(1, 1),
			still = true,
			head = true,
			zIndex = 8,
		})
		portrait:set(Catalog.getCat(row.cat.catId), CatVariant.isGold(row.cat.variant))
		row.portrait = portrait
		row.loaded = true
	end
end

-- While the list is open, a change in the cats that can go in (a level, a rename, one sent to the spa) rebuilds it;
-- anything else leaves its rows alone.
function OasisSpa._syncRows(self: any)
	if self._pickSlot == nil then
		return
	end
	local key = LateStationsLogic.spaKey(LateStationsLogic.spaCandidates(self._cats, self._spa))
	if key ~= self._rowsKey then
		self:_buildRows()
	end
end

function OasisSpa._paint(self: any)
	local rows = LateStationsLogic.spaRows(self._spa, self._cats, now())
	for slot, tile: Tile in self._tiles do
		local row = rows[slot]
		if row == nil then
			continue
		end
		local isCat = row.kind == "cat"
		local cat: SharedTypes.CatView? = if row.uid ~= nil then self._cats[row.uid] else nil
		tile.portrait.frame.Visible = isCat
		tile.glyph.Visible = not isCat
		if isCat then
			local key = (row.catId or "?") .. ":" .. (if cat ~= nil then cat.variant else "base")
			if tile.loaded ~= key then
				tile.loaded = key
				tile.portrait:set(
					if row.catId ~= nil then Catalog.getCat(row.catId) else nil,
					cat ~= nil and CatVariant.isGold(cat.variant)
				)
			end
			tile.name.Text = self:_catName(row.uid, row.catId)
			local level = row.level
			tile.level.Text = if level == nil
				then ""
				elseif row.levels > 0 then string.format(
					"Lv %d → %d",
					level,
					level + row.levels
				)
				else string.format("Lv %d", level)
			tile.level.TextColor3 = if row.ready then PAL.good else PAL.text
		else
			tile.glyph.Text = if row.kind == "empty" then "+" else Theme.icons.lock
			tile.name.Text = string.format("Slot %d", slot)
			tile.level.Text = if row.kind == "empty" then "Empty" else ""
			tile.level.TextColor3 = PAL.text
		end
		tile.line.Text = if row.kind == "empty" then "Room for one more cat" else row.line
		tile.line.TextColor3 = if row.ready then PAL.good else PAL.subtext
		local label, style, enabled, show = "", "primary", false, true
		if row.kind == "cat" then
			label, style, enabled, show = "Take out", "ghost", not self._pending, not row.ready
		elseif row.kind == "empty" then
			label, style, enabled = "Add a cat", "primary", not self._pending
		else
			local price = row.price or 0
			label, style = tostring(price), "gold"
			enabled = row.kind == "buy" and self._fish >= price and not self._pending
		end
		tile.action.instance.Visible = show
		if tile.label ~= label then
			tile.label = label
			tile.action:setText(label)
		end
		if tile.style ~= style then
			tile.style = style
			tile.action:setStyle(style :: any)
		end
		if tile.enabled ~= enabled then
			tile.enabled = enabled
			tile.action:setEnabled(enabled)
		end
		local fish: TextLabel? = tile.action.icon
		if fish then
			fish.Visible = row.kind == "buy" or row.kind == "shut"
		end
	end
	local levels = LateStationsLogic.spaReady(self._spa, self._cats, now())
	self._collect:setText(if self._pending then "..." else LateStationsLogic.collectText(levels))
	self._collect:setEnabled(levels > 0 and not self._pending)
	self._have.Text = ("You have %s golden fish"):format(ShortNumber.format(self._fish))
end

function OasisSpa.setView(self: any, spa: SharedTypes.SpaView?)
	self._spa = spa
	self._pending = false
	self._pendingToken += 1
	self:_paint()
	self:_syncRows()
end

function OasisSpa.render(self: any, state: Types.PlayerState)
	self._fish = state.goldenFish or 0
	self._cats = (state.cats or {}) :: any
	self:_paint()
	self:_syncRows()
end

-- While open the lines move on once a second, and walking away closes the card.
function OasisSpa.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_showPicker(nil)
	self:_showConfirm(nil)
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				local far = (self._callbacks :: Callbacks).far
				if far ~= nil and far() then
					self._callbacks.close()
					return
				end
				self:_paint()
			end
		end
	end)
end

function OasisSpa.closed(self: any)
	self._open = false
	self._tick += 1
	self:_showPicker(nil)
	self:_showConfirm(nil)
end

-- A refusal: the buttons wake and Collect wobbles (the server's toast says why).
function OasisSpa.refused(self: any)
	self._pending = false
	self._pendingToken += 1
	self:_paint()
	local button: Frame = self._collect.instance
	button.Rotation = -8
	Tween.to(
		button,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Rotation = 0 }
	)
end

function OasisSpa.destroy(self: any)
	self._open = false
	self._tick += 1
	self:_clearRows()
	self._searchChanged:Disconnect()
	self._scrolled:Disconnect()
	for _, chip: Button.Button in self._chips do
		chip:destroy()
	end
	for _, tile: Tile in self._tiles do
		tile.portrait:destroy()
		tile.action:destroy()
	end
	self._collect:destroy()
	self._back:destroy()
	self._takeOut:destroy()
	self._keep:destroy()
	self._panel:destroy()
end

return OasisSpa
