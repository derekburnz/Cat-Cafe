--!strict
-- The Relic Museum's card (#2651 part 4, late-stations.md section 2; #2908), opened by its prompt at the Ruins camp
-- (UI.lateStations.open("museum")). One room at a time, turned with the arrows ("Desert Hall 4/10", a tick once
-- finished): its ten exhibits in two rows of five, each the Index's picture of its cat, a black silhouette until
-- given, then the cat in the coat it was given in (a gold or rainbow frame for those). Under each name: "Given" or
-- "You have 3", and a green "!" when a copy can be given now. Tapping one with a copy to give turns the card to
-- its copies, weakest first (the server's own order), each with Give; a gold or rainbow copy asks first ("This is a
-- gold cat. Give it anyway?"). Tapping one without says why in the note line ("You need a second copy to give one").
-- The footer has the count, "23/70 exhibits · +10% tips forever", and what a room is worth. A Give rests the buttons
-- until the next LateStationsState or a refusal (refused). The server checks every rule again and toasts a finished
-- room ("Desert Hall complete! +5% tips forever"). Nothing is sold for Robux. Words and rules in
-- Components/LateStationsLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local LateStationsLogic = require(script.Parent.Parent.Components.LateStationsLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local StoreBurst = require(script.Parent.Parent.Parent.Effects.StoreBurst) :: any
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
local SharedTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local PAL = Theme.dark

export type Callbacks = {
	donate: (uid: string) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the museum: the card closes
}

export type RelicMuseum = {
	frame: Frame,
	setView: (self: RelicMuseum, museum: SharedTypes.MuseumView?, spa: SharedTypes.SpaView?) -> (),
	render: (self: RelicMuseum, state: Types.PlayerState) -> (),
	opened: (self: RelicMuseum) -> (),
	closed: (self: RelicMuseum) -> (),
	refused: (self: RelicMuseum) -> (),
	-- LateStationResult ok: the gold burst round the exhibit just filled (#2926; "room" when it finished the room)
	given: (self: RelicMuseum, catId: string, room: string?) -> (),
	destroy: (self: RelicMuseum) -> (),
}

type Tile = {
	frame: TextButton,
	stroke: UIStroke,
	portrait: CatPortrait.CatPortrait,
	loaded: string?,
	name: TextLabel,
	line: TextLabel,
	dot: Frame,
	connection: RBXScriptConnection,
}

local MAX_SIZE = Vector2.new(600, 430)
local COLUMNS = 5
local TILE_H = 112
local PICTURE = 60
local PENDING_SECONDS = 5
local ROW_H = 52
local GAP = Theme.sizes.gap

local RelicMuseum = {}
RelicMuseum.__index = RelicMuseum

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

function RelicMuseum.new(callbacks: Callbacks): RelicMuseum
	local self = setmetatable({}, RelicMuseum) :: any
	self._callbacks = callbacks
	self._museum = nil :: SharedTypes.MuseumView?
	self._spa = nil :: SharedTypes.SpaView?
	self._cats = {} :: { [string]: SharedTypes.CatView }
	self._found = {} :: { [string]: number } -- the Index's found cats (PlayerState.collection)
	self._room = 1
	self._pending = false
	self._pendingToken = 0
	self._open = false
	self._tick = 0
	self._giving = nil :: string? -- the catId whose copies the card lists
	self._asking = nil :: string? -- the uid a gold or rainbow warning asks about
	self._note = nil :: string?
	self._rows = {} :: { { frame: Frame, button: Button.Button } }
	local buttonH = Scale.tapHeight(40, Theme.sizes.buttonDepth)
	self._buttonH = buttonH
	local extra = buttonH - 40

	local panel = Panel.new({
		dark = true,
		name = "RelicMuseum",
		title = "Relic Museum",
		subtitle = "Give a spare copy to fill its exhibit",
		color = Theme.colors.mintDark,
		icon = LateStationsLogic.ICONS.museum,
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y + extra),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", {
		MaxSize = Vector2.new(MAX_SIZE.X, MAX_SIZE.Y + extra),
		Parent = panel.frame,
	})
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the room's title between its arrows
	self._prev = Button.new({
		name = "Prev",
		text = "‹",
		style = "ghost",
		size = UDim2.fromOffset(56, buttonH),
		textSize = Theme.sizes.textLarge,
		parent = content,
		onClick = function()
			self:_turn(-1)
		end,
	})
	self._next = Button.new({
		name = "Next",
		text = "›",
		style = "ghost",
		size = UDim2.fromOffset(56, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textLarge,
		parent = content,
		onClick = function()
			self:_turn(1)
		end,
	})
	self._title = text({
		Name = "Room",
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -128, 0, buttonH),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = content,
	})

	local grid: Frame = Create("Frame", {
		Name = "Exhibits",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, buttonH + GAP),
		Size = UDim2.new(1, 0, 0, TILE_H * 2 + GAP),
		Parent = content,
	}, {
		Create("UIGridLayout", {
			CellPadding = UDim2.fromOffset(GAP, GAP),
			CellSize = UDim2.new(1 / COLUMNS, -GAP * (COLUMNS - 1) / COLUMNS, 0, TILE_H),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._tiles = {} :: { Tile }
	for index = 1, 2 * COLUMNS do
		local frame: TextButton = Create("TextButton", {
			Name = "Exhibit" .. index,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = grid,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local stroke: UIStroke = Create("UIStroke", {
			Color = PAL.cardStroke,
			Thickness = Theme.sizes.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
		local portrait = CatPortrait.new({
			parent = frame,
			size = UDim2.fromOffset(PICTURE, PICTURE),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 6),
			still = true,
		})
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(4, PICTURE + 10),
			Size = UDim2.new(1, -8, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			Parent = frame,
		})
		local line = text({
			Name = "Line",
			Position = UDim2.fromOffset(4, PICTURE + 28),
			Size = UDim2.new(1, -8, 0, 16),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		local dot: Frame = Create("Frame", {
			Name = "Dot",
			BackgroundColor3 = Theme.colors.good,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(20, 20),
			Visible = false,
			ZIndex = 3,
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local mark = text({
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			Text = "!",
			ZIndex = 4,
			Parent = dot,
		})
		Outline.text(mark, 1.5)
		local connection = frame.Activated:Connect(function()
			self:_tilePress(index)
		end)
		table.insert(self._tiles, {
			frame = frame,
			stroke = stroke,
			portrait = portrait,
			loaded = nil,
			name = name,
			line = line,
			dot = dot,
			connection = connection,
		})
	end
	local footY = buttonH + GAP + TILE_H * 2 + GAP * 2
	self._noteLabel = text({
		Name = "Note",
		Position = UDim2.fromOffset(0, footY),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Parent = content,
	})
	self._count = text({
		Name = "Count",
		Position = UDim2.fromOffset(0, footY + 20),
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		Parent = content,
	})
	text({
		Name = "RoomBonus",
		Position = UDim2.fromOffset(0, footY + 42),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.gold,
		Text = LateStationsLogic.roomBonusText(),
		Parent = content,
	})

	-- the copies to give
	local give = sheet("Give", content)
	self._give = give
	self._giveTitle = text({
		Name = "Title",
		Size = UDim2.new(1, -110, 0, 32),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = give,
	})
	text({
		Name = "Hint",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -110, 0, 16),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "It stays found in your Index. Your other copy stays with you.",
		ZIndex = 6,
		Parent = give,
	})
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(96, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = give,
		zIndex = 6,
		onClick = function()
			self:_showGive(nil)
		end,
	})
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, buttonH + 10),
		Size = UDim2.new(1, 0, 1, -(buttonH + 10)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 6,
		Parent = give,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	})

	-- a gold or rainbow copy asks first
	local confirm = sheet("Confirm", content, 8)
	self._confirm = confirm
	self._ask = text({
		Name = "Ask",
		Position = UDim2.fromScale(0, 0.22),
		Size = UDim2.new(1, 0, 0, 56),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 9,
		Parent = confirm,
	})
	self._giveIt = Button.new({
		name = "GiveIt",
		text = "Give it",
		style = "danger",
		size = UDim2.fromOffset(150, buttonH + 4),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(0.5, -6, 0.22, 76),
		textSize = Theme.sizes.textBody,
		parent = confirm,
		zIndex = 9,
		onClick = function()
			local uid = self._asking
			self:_showConfirm(nil)
			if uid ~= nil then
				self:_donate(uid)
			end
		end,
	})
	self._keep = Button.new({
		name = "Keep",
		text = "Keep it",
		style = "primary",
		size = UDim2.fromOffset(150, buttonH + 4),
		position = UDim2.new(0.5, 6, 0.22, 76),
		textSize = Theme.sizes.textBody,
		parent = confirm,
		zIndex = 9,
		onClick = function()
			self:_showConfirm(nil)
		end,
	})
	return self :: RelicMuseum
end

function RelicMuseum._rooms(self: any): { LateStationsLogic.RoomRow }
	return LateStationsLogic.rooms(self._museum, self._cats, self._spa)
end

function RelicMuseum._turn(self: any, by: number)
	local count = #self:_rooms()
	if count == 0 then
		return
	end
	self._room = ((self._room - 1 + by) % count) + 1
	self._note = nil
	self:_paint()
end

function RelicMuseum._exhibit(self: any, index: number): LateStationsLogic.Exhibit?
	local room = self:_rooms()[self._room]
	return if room ~= nil then room.exhibits[index] else nil
end

function RelicMuseum._tilePress(self: any, index: number)
	local exhibit = self:_exhibit(index)
	if exhibit == nil or self._pending then
		return
	end
	if exhibit.coat == nil and #exhibit.give > 0 then
		self:_showGive(exhibit.catId)
	else
		self._note = string.format("%s: %s", exhibit.name, LateStationsLogic.whyNot(exhibit))
		self:_paint()
	end
end

function RelicMuseum._donate(self: any, uid: string)
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
	self:_showGive(nil)
	self:_paint()
	self._callbacks.donate(uid)
end

function RelicMuseum._showConfirm(self: any, uid: string?)
	self._asking = uid
	self._confirm.Visible = uid ~= nil
	local cat: SharedTypes.CatView? = if uid ~= nil then self._cats[uid] else nil
	if cat ~= nil then
		self._ask.Text = LateStationsLogic.giveWarning(cat.variant) or ""
	end
end

function RelicMuseum._clearRows(self: any)
	for _, entry in self._rows do
		entry.button:destroy()
		entry.frame:Destroy()
	end
	table.clear(self._rows)
end

-- The copies of `catId` to give, weakest first, or back to the room (nil).
function RelicMuseum._showGive(self: any, catId: string?)
	self._giving = catId
	self._give.Visible = catId ~= nil
	self:_clearRows()
	if catId == nil then
		return
	end
	local def = Catalog.getCat(catId)
	local name = if def ~= nil then def.name else catId
	self._giveTitle.Text = "Give a " .. name
	local copies = LateStationsLogic.donatable(
		self._cats,
		catId,
		if self._museum ~= nil then self._museum.filled else nil,
		self._spa
	)
	for order, cat in copies do
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
		Create("Frame", {
			Name = "Rarity",
			BackgroundColor3 = Theme.rarityColor(if def ~= nil then def.rarity else nil),
			BorderSizePixel = 0,
			Size = UDim2.new(0, 6, 1, 0),
			ZIndex = 7,
			Parent = frame,
		})
		local shiny = cat.variant == "gold" or cat.variant == "rainbow"
		text({
			Name = "Name",
			Position = UDim2.fromOffset(16, 6),
			Size = UDim2.new(1, -130, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if shiny then PAL.gold else PAL.text,
			Text = CatVariant.name(name, cat.variant),
			ZIndex = 7,
			Parent = frame,
		})
		text({
			Name = "Level",
			Position = UDim2.fromOffset(16, 28),
			Size = UDim2.new(1, -130, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				"Lv %d · %s%s",
				cat.level,
				string.rep("★", cat.stars or 1),
				if cat.spotId ~= nil then " · Working" else ""
			),
			ZIndex = 7,
			Parent = frame,
		})
		local uid = cat.uid
		local button = Button.new({
			name = "Give",
			text = "Give",
			style = "primary",
			size = UDim2.fromOffset(100, self._buttonH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -6, 0.5, 0),
			textSize = Theme.sizes.textSmall + 1,
			parent = frame,
			zIndex = 7,
			onClick = function()
				if LateStationsLogic.giveWarning(cat.variant) ~= nil then
					self:_showConfirm(uid)
				else
					self:_donate(uid)
				end
			end,
		})
		table.insert(self._rows, { frame = frame, button = button })
	end
	if #copies == 0 then
		self:_showGive(nil)
	end
end

function RelicMuseum._paint(self: any)
	local rooms: { LateStationsLogic.RoomRow } = self:_rooms()
	local room = rooms[self._room]
	if room == nil then
		return
	end
	self._title.Text = string.format(
		"%s Hall %d/%d%s",
		room.name,
		room.filled,
		#room.exhibits,
		if room.done then " ✓" else ""
	)
	self._title.TextColor3 = if room.done then PAL.gold else PAL.text
	for index, tile: Tile in self._tiles do
		local exhibit = room.exhibits[index]
		tile.frame.Visible = exhibit ~= nil
		if exhibit == nil then
			continue
		end
		local key = exhibit.catId .. ":" .. (exhibit.coat or "-")
		if tile.loaded ~= key then
			tile.loaded = key
			tile.portrait:set(Catalog.getCat(exhibit.catId), exhibit.coat == "gold")
			tile.portrait:setSilhouette(exhibit.coat == nil)
		end
		-- a cat found at least once is named, as in the Index; its picture stays a silhouette until given
		local found = exhibit.coat ~= nil or exhibit.have > 0 or self._found[exhibit.catId] ~= nil
		tile.name.Text = if found then exhibit.name else "???"
		tile.line.Text = exhibit.line
		local canGive = exhibit.coat == nil and #exhibit.give > 0
		tile.line.TextColor3 = if exhibit.coat ~= nil
			then PAL.gold
			elseif canGive then PAL.good
			else PAL.subtext
		tile.dot.Visible = canGive
		tile.stroke.Color = if exhibit.coat == "gold"
			then Theme.colors.gold
			elseif exhibit.coat == "rainbow" then Theme.colors.rainbowChip
			elseif exhibit.coat ~= nil then Theme.rarityColor(exhibit.rarity)
			else PAL.cardStroke
		tile.stroke.Thickness = if exhibit.coat == "gold" or exhibit.coat == "rainbow"
			then Theme.sizes.outline
			else Theme.sizes.stroke
	end
	local museum = self._museum
	local count = if museum ~= nil then museum.count else 0
	local total = if museum ~= nil then museum.total else 0
	self._count.Text = string.format(
		"%d/%d exhibits · %s",
		count,
		total,
		LateStationsLogic.bonusText(if museum ~= nil then museum.bonus else 0)
	)
	self._noteLabel.Text = if self._pending
		then "Giving..."
		else (self._note or if room.canFill > 0
			then "Tap an exhibit with a ! to give a copy"
			else "Spare copies of a cat fill its exhibit")
	self._prev:setEnabled(not self._pending)
	self._next:setEnabled(not self._pending)
end

-- Opens on the first room with something to give, else the first room not finished.
function RelicMuseum._pickRoom(self: any)
	local rooms = self:_rooms()
	for index, room in rooms do
		if room.canFill > 0 then
			self._room = index
			return
		end
	end
	for index, room in rooms do
		if not room.done then
			self._room = index
			return
		end
	end
	self._room = 1
end

function RelicMuseum.setView(self: any, museum: SharedTypes.MuseumView?, spa: SharedTypes.SpaView?)
	self._museum = museum
	self._spa = spa
	self._pending = false
	self._pendingToken += 1
	if self._giving ~= nil then
		self:_showGive(self._giving) -- the list again, without a copy just given
	end
	self:_paint()
end

function RelicMuseum.render(self: any, state: Types.PlayerState)
	self._cats = (state.cats or {}) :: any
	self._found = (state.collection or {}) :: any
	if self._open then
		self:_paint()
	end
end

function RelicMuseum.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self._note = nil
	self:_showGive(nil)
	self:_showConfirm(nil)
	self:_pickRoom()
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
			end
		end
	end)
end

function RelicMuseum.closed(self: any)
	self._open = false
	self._tick += 1
	self:_showGive(nil)
	self:_showConfirm(nil)
end

function RelicMuseum.refused(self: any)
	self._pending = false
	self._pendingToken += 1
	self:_paint()
end

function RelicMuseum.given(self: any, catId: string, room: string?)
	if not self._open then
		return
	end
	for index, row in self:_rooms() do
		for slot, exhibit in row.exhibits do
			if exhibit.catId == catId then
				self._room = index
				self._note = nil
				self:_paint()
				local tile: Tile? = self._tiles[slot]
				if tile ~= nil then
					pcall(StoreBurst.play, tile.frame, if room ~= nil then "room" else "exhibit")
				end
				return
			end
		end
	end
end

function RelicMuseum.destroy(self: any)
	self._open = false
	self._tick += 1
	self:_clearRows()
	for _, tile: Tile in self._tiles do
		tile.connection:Disconnect()
		tile.portrait:destroy()
	end
	self._prev:destroy()
	self._next:destroy()
	self._back:destroy()
	self._giveIt:destroy()
	self._keep:destroy()
	self._panel:destroy()
end

return RelicMuseum
