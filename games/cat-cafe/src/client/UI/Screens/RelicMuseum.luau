--!strict
-- The Relic Museum's card (#2651 part 4, late-stations.md section 2; #2908), opened by its prompt at the Ruins camp
-- (UI.lateStations.open("museum")). One room at a time, turned with the arrows ("Desert Hall 4/10", a tick once
-- finished): its ten exhibits in two rows of five, each the Index's picture of its cat, a black silhouette until
-- given, then the cat in the coat it was given in (a gold or rainbow frame for those). Under each name: "Given" or
-- "You have 3", and a green "!" when a copy can be given now. #3123: the ten tiles are placed by hand at fifths of
-- the width (a UIGridLayout wrapped at 4 a row), in a scroller that fills the room between the arrows and the
-- footer, so a short screen scrolls instead of the footer covering a row. Tapping one with a copy to give turns the
-- card to its copies, the one to give first first and marked "Best to give" (#3125, the server's own order), each
-- with Give; the last copy asks first ("This is your only Tabby. It leaves your cafe. Give it anyway?", #3123), as
-- does a gold or rainbow copy. Tapping one without says why in the note line. The footer has the count,
-- "23/70 exhibits · +10% tips forever", and what a room is worth. A Give rests the buttons until the next
-- LateStationsState or a refusal (refused); #3124: Gives go at least SEND_GAP apart (the server takes one a second
-- and drops the rest unanswered), and one with no answer frees the card after PENDING_SECONDS with a note. #3130:
-- Auto fill beside the arrows gives the hall's every fillable exhibit its pick in one call (fill(area)), after a
-- question that lists them (LateStationsLogic.fillPlan and fillAsk). The server checks every rule again and toasts a finished
-- room ("Desert Hall complete! +5% tips forever"). Nothing is sold for Robux. Words and rules in
-- Components/LateStationsLogic.
-- #3961 (Model-Agent's batch 3 mock, station-menus-batch3-3558.png): the arrows became a row of hall tabs
-- ("Alleyway 2/10", gold for the hall shown, a tick once finished; it scrolls sideways when the halls don't fit),
-- with a chunky Auto fill at its end. Each exhibit is a picture card: a green tick and "On show" once given, a green
-- "Give a copy" chip while a copy can be given (the card's Copies attribute says how many), else "Not found yet" or
-- "You have 0". The footer is a dark pill with the count and, beside it, the note or what a finished hall gives.
-- Looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local Create = require(script.Parent.Parent.Components.Create)
local LateStationsLogic = require(script.Parent.Parent.Components.LateStationsLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local StoreBurst = require(script.Parent.Parent.Parent.Effects.StoreBurst) :: any
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
local SharedTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))

local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	donate: (uid: string) -> (),
	fill: ((area: string) -> ())?, -- #3130: Auto fill on the hall shown
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
	chip: Frame,
	check: Frame,
	connection: RBXScriptConnection,
}

type HallTab = { area: string, button: Button.Button }

local MAX_SIZE = Vector2.new(600, 386) -- #3961: two full rows of TILE_H and the one line footer, no gap under them
local COLUMNS = 5
local TILE_H = 112
local PICTURE = 60
local PENDING_SECONDS = 2.5
local SEND_GAP = 1.1 -- #3124: the server's MuseumDonate limit is one a second
local FILL_GAP = 2.1 -- #3130: MuseumFill's is one per 2 s
local FOOT_H = 22 -- #3961: one line (the note, else what a finished hall gives); the count sits under the hall's name
local NAME_H = 16
local LINE_H = 14
local FILL_W = 104
local ROW_H = 52
local CHIP_H = 16 -- #3961: the green "Give a copy" chip
local TAB_MIN_W, TAB_MAX_W = 96, 190 -- a hall tab sized to its words
local GAP = Theme.sizes.gap

local RelicMuseum = {}
RelicMuseum.__index = RelicMuseum

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = CARD.text,
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
-- #3961: a cat's name as big as its tile allows (Garbage Bag Cat was cut to "arbage Bag Ca" on a phone): the bold
-- font runs a little over half its size a letter
local function nameSize(name: string, width: number): number
	local fit = math.floor(width / (math.max(1, utf8.len(name) or #name) * 0.56))
	return math.clamp(fit, Theme.sizes.textTiny, Theme.sizes.textSmall)
end

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
		subtitle = "Give a copy of a cat to fill its exhibit",
		color = Theme.colors.mintDark,
		icon = LateStationsLogic.ICONS.museum,
		size = UDim2.fromScale(1, 1), -- #3123: as tall as the screen allows, up to MAX_SIZE; the exhibits scroll on a short one
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

	-- #3961 (mock): a row of hall tabs, one per hall, scrolling sideways when they don't all fit, and Auto fill at
	-- its end. The tabs are made in _paint, once the halls are known.
	self._halls = Create("ScrollingFrame", {
		Name = "Halls",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -(FILL_W + GAP), 0, buttonH + 8),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		-- room for the tabs' outlines inside the row's clip
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	self._tabs = {} :: { HallTab }
	self._fillButton = Button.new({
		name = "AutoFill",
		text = "Auto fill",
		style = "primary",
		size = UDim2.fromOffset(FILL_W, buttonH),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 4),
		textSize = Theme.sizes.textSmall + 1,
		parent = content,
		onClick = function()
			self:_askFill()
		end,
	})

	-- #3123: two rows of five placed by hand (a UIGridLayout's five cells and four gaps could round past the width
	-- and wrap at four). #3961 (Derek: cells cut off on a phone): the two rows share the room between the tabs and
	-- the footer, each half of it (up to TILE_H), and the pictures shrink to fit, so nothing scrolls or is cut
	local grid: Frame = Create("Frame", {
		Name = "Exhibits",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, buttonH + 8 + GAP),
		Size = UDim2.new(1, 0, 1, -(buttonH + 8 + GAP * 2 + FOOT_H)),
		Parent = content,
	}, {
		Create("UISizeConstraint", { MaxSize = Vector2.new(math.huge, TILE_H * 2 + GAP + 6) }),
		-- room for the tiles' outlines inside the scroller's clip
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 3),
			PaddingTop = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 3),
		}),
	})
	self._tiles = {} :: { Tile }
	for index = 1, 2 * COLUMNS do
		local frame: TextButton = Create("TextButton", {
			Name = "Exhibit" .. index,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / COLUMNS, -GAP * (COLUMNS - 1) / COLUMNS, 0.5, -GAP / 2),
			Position = UDim2.new(
				((index - 1) % COLUMNS) / COLUMNS,
				((index - 1) % COLUMNS) * GAP / COLUMNS,
				(math.ceil(index / COLUMNS) - 1) * 0.5,
				(math.ceil(index / COLUMNS) - 1) * GAP / 2
			),
			Parent = grid,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local stroke: UIStroke = Create("UIStroke", {
			Color = CARD.cardStroke,
			Thickness = Theme.sizes.stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
		-- the picture takes what the two lines under it leave, square and at most PICTURE
		local portrait = CatPortrait.new({
			parent = frame,
			size = UDim2.new(1, -8, 1, -(NAME_H + LINE_H + 10)),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 4),
			still = true,
		})
		Create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = portrait.frame })
		Create(
			"UISizeConstraint",
			{ MaxSize = Vector2.new(PICTURE, PICTURE), Parent = portrait.frame }
		)
		local name = text({
			Name = "Name",
			Position = UDim2.new(0, 3, 1, -(NAME_H + LINE_H + 4)),
			Size = UDim2.new(1, -6, 0, NAME_H),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			Parent = frame,
		})
		local line = text({
			Name = "Line",
			Position = UDim2.new(0, 3, 1, -(LINE_H + 4)),
			Size = UDim2.new(1, -6, 0, LINE_H),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = CARD.subtext,
			Parent = frame,
		})
		-- #3961 (mock): a green "Give a copy" chip in the line's place while a copy can be given
		local chip: Frame = Create("Frame", {
			Name = "GiveChip",
			BackgroundColor3 = Theme.colors.good,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -(CHIP_H + 2)),
			Size = UDim2.new(1, -10, 0, CHIP_H),
			Visible = false,
			ZIndex = 3,
			Parent = frame,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", {
				Color = Theme.colors.ink,
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		local chipText = text({
			Name = "Text",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Give a copy",
			ZIndex = 4,
			Parent = chip,
		})
		Create(
			"UITextSizeConstraint",
			{ MaxTextSize = Theme.sizes.textTiny, MinTextSize = 9, Parent = chipText }
		)
		chipText.TextScaled = true
		Outline.text(chipText, 1)
		-- a green tick in the corner once the exhibit is on show
		local check: Frame = Create("Frame", {
			Name = "Check",
			BackgroundColor3 = Theme.colors.good,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -11, 0, 11),
			Size = UDim2.fromOffset(20, 20),
			Visible = false,
			ZIndex = 3,
			Parent = frame,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", {
				Color = Color3.new(1, 1, 1),
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		local tick = text({
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "✓",
			ZIndex = 4,
			Parent = check,
		})
		Outline.text(tick, 1)
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
			chip = chip,
			check = check,
			connection = connection,
		})
	end
	-- the footer keeps its own strip at the bottom (#3123: it sat over a third row). #3961 (mock): the museum's count
	-- in a dark pill at the left, the note or what a finished hall gives beside it
	local countPill: Frame = Create("Frame", {
		Name = "CountPill",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -FOOT_H),
		Size = UDim2.new(0.42, 0, 0, FOOT_H),
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", {
			Color = PAL.caramel,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	self._count = text({
		Name = "Count",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.text,
		TextScaled = true,
		Parent = countPill,
	})
	Create(
		"UITextSizeConstraint",
		{ MaxTextSize = Theme.sizes.textSmall, MinTextSize = 10, Parent = self._count }
	)
	self._noteLabel = text({
		Name = "Note",
		Position = UDim2.new(0.42, GAP, 1, -FOOT_H),
		Size = UDim2.new(0.58, -GAP, 0, FOOT_H),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
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
		TextColor3 = PAL.text,
		Parent = give,
	})
	text({
		Name = "Hint",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -110, 0, 16),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "It stays found in your Index.",
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
		Create("UIPadding", {
			PaddingRight = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 3), -- #3125: the Best to give row's outline
			PaddingTop = UDim.new(0, 3),
		}),
	})

	-- the last copy, or a gold or rainbow one, asks first
	local confirm = sheet("Confirm", content, 8)
	self._confirm = confirm
	self._ask = text({
		Name = "Ask",
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.new(1, 0, 0, 100),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 9,
		TextColor3 = PAL.text,
		Parent = confirm,
	})
	self._giveIt = Button.new({
		name = "GiveIt",
		text = "Give it",
		style = "danger",
		size = UDim2.fromOffset(150, buttonH + 4),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(0.5, -6, 0.12, 112),
		textSize = Theme.sizes.textBody,
		parent = confirm,
		zIndex = 9,
		onClick = function()
			local uid = self._asking
			local fill = self._fillArea
			self:_showConfirm(nil)
			if fill ~= nil then
				self:_fill(fill)
			elseif uid ~= nil then
				self:_donate(uid)
			end
		end,
	})
	self._keep = Button.new({
		name = "Keep",
		text = "Keep it",
		style = "primary",
		size = UDim2.fromOffset(150, buttonH + 4),
		position = UDim2.new(0.5, 6, 0.12, 112),
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

-- Shows hall `index` (a tab press).
function RelicMuseum._select(self: any, index: number)
	if self._pending or index == self._room then
		return
	end
	self._room = index
	self._note = nil
	self:_paint()
end

-- #3961: one tab per hall, made again only when the halls change; "Alleyway 2/10", a tick once finished.
function RelicMuseum._paintTabs(self: any, rooms: { LateStationsLogic.RoomRow })
	local same = #rooms == #self._tabs
	if same then
		for index, room in rooms do
			if self._tabs[index].area ~= room.area then
				same = false
			end
		end
	end
	if not same then
		for _, tab: HallTab in self._tabs do
			tab.button:destroy()
		end
		table.clear(self._tabs)
		for index, room in rooms do
			local button = Button.new({
				name = "Hall_" .. room.area,
				text = room.name,
				style = "ghost",
				size = UDim2.fromOffset(TAB_MIN_W, self._buttonH),
				textSize = Theme.sizes.textSmall,
				layoutOrder = index,
				parent = self._halls,
				onClick = function()
					self:_select(index)
				end,
			})
			table.insert(self._tabs, { area = room.area, button = button })
		end
	end
	for index, room in rooms do
		local tab: HallTab = self._tabs[index]
		local words = string.format(
			"%s %d/%d%s",
			room.name,
			room.filled,
			#room.exhibits,
			if room.done then " ✓" else ""
		)
		tab.button:setText(words)
		tab.button:setStyle(if index == self._room then "gold" else "ghost")
		tab.button:setEnabled(not self._pending)
		local width = math.clamp(24 + (utf8.len(words) or #words) * 8, TAB_MIN_W, TAB_MAX_W)
		tab.button.instance.Size = UDim2.fromOffset(width, self._buttonH)
	end
end

-- Scrolls the tab row so the hall shown is in view.
function RelicMuseum._showTab(self: any)
	local tab: HallTab? = self._tabs[self._room]
	if tab == nil then
		return
	end
	local halls: ScrollingFrame = self._halls
	local left = tab.button.instance.AbsolutePosition.X
		- halls.AbsolutePosition.X
		+ halls.CanvasPosition.X
	local right = left + tab.button.instance.AbsoluteSize.X
	local view = halls.AbsoluteSize.X
	local x = halls.CanvasPosition.X
	if left < x then
		x = left - 2
	elseif right > x + view then
		x = right - view + 2
	end
	halls.CanvasPosition = Vector2.new(math.max(0, x), 0)
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
	-- #2952 (Sound-Agent): the tiles are plain TextButtons, so they click like a Button press, or sound the error
	-- when the exhibit can't be given now
	if exhibit.coat == nil and #exhibit.give > 0 then
		Sound.play("uiClick")
		self:_showGive(exhibit.catId)
	else
		Sound.play("uiError")
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
	-- #3124: wait out the server's one a second, so this Give isn't dropped unanswered
	local wait = math.max(0, (self._lastSent or -math.huge) + SEND_GAP - os.clock())
	task.delay(wait + PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending then
			self._pending = false
			self._note = "That didn't go through. Try again."
			self:_paint()
		end
	end)
	self:_showGive(nil)
	self:_paint()
	self._lastSent = os.clock() + wait
	if wait > 0 then
		task.delay(wait, function()
			if self._pendingToken == token and self._pending then
				self._callbacks.donate(uid)
			end
		end)
	else
		self._callbacks.donate(uid)
	end
end

function RelicMuseum._showConfirm(self: any, uid: string?, ask: string?, fillArea: string?)
	self._asking = uid
	self._fillArea = fillArea
	self._confirm.Visible = uid ~= nil or fillArea ~= nil
	self._ask.Text = ask or ""
	self._ask.TextSize = if #(ask or "") > 70 then Theme.sizes.textBody else Theme.sizes.textLarge
end

-- #3130: Auto fill's picks for the hall shown.
function RelicMuseum._fillPicks(self: any): { LateStationsLogic.FillPick }
	local room = self:_rooms()[self._room]
	if room == nil then
		return {}
	end
	local total = 0
	for _ in self._cats do
		total += 1
	end
	return LateStationsLogic.fillPlan(room, total)
end

function RelicMuseum._askFill(self: any)
	local room = self:_rooms()[self._room]
	if room == nil or self._pending then
		return
	end
	local picks = self:_fillPicks()
	if #picks == 0 then
		Sound.play("uiError")
		self._note = "Nothing to fill in this hall right now"
		self:_paint()
		return
	end
	Sound.play("uiClick")
	self:_showConfirm(nil, LateStationsLogic.fillAsk(room.name, picks), room.area)
end

-- Sends Auto fill for `area`, after the same send gap and wait as a Give (#3124).
function RelicMuseum._fill(self: any, area: string)
	local fill = (self._callbacks :: Callbacks).fill
	if fill == nil or self._pending then
		return
	end
	self._pending = true
	self._pendingToken += 1
	local token = self._pendingToken
	local wait = math.max(
		0,
		(self._lastSent or -math.huge) + SEND_GAP - os.clock(),
		(self._lastFill or -math.huge) + FILL_GAP - os.clock()
	)
	task.delay(wait + PENDING_SECONDS, function()
		if self._pendingToken == token and self._pending then
			self._pending = false
			self._note = "That didn't go through. Try again."
			self:_paint()
		end
	end)
	self:_paint()
	self._lastSent = os.clock() + wait
	self._lastFill = self._lastSent
	task.delay(wait, function()
		if self._pendingToken == token and self._pending then
			fill(area)
		end
	end)
end

-- How many copies of `catId` the player has.
function RelicMuseum._copies(self: any, catId: string): number
	local count = 0
	for _, cat: SharedTypes.CatView in self._cats do
		if cat.catId == catId then
			count += 1
		end
	end
	return count
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
		local best = order == 1 and #copies > 1 -- #3125: the one to give first
		local frame: Frame = Create("Frame", {
			Name = cat.uid,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, math.max(ROW_H, self._buttonH + 8)),
			ZIndex = 6,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		})
		if best then
			Create("UIStroke", {
				Color = Theme.colors.good,
				Thickness = Theme.sizes.stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = frame,
			})
		end
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
			TextColor3 = if shiny then CARD.gold else CARD.text,
			Text = CatVariant.name(name, cat.variant),
			ZIndex = 7,
			Parent = frame,
		})
		text({
			Name = "Level",
			Position = UDim2.fromOffset(16, 28),
			Size = UDim2.new(1, -130, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = CARD.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				"Lv %d · %s%s%s",
				cat.level,
				string.rep("★", cat.stars or 1),
				if cat.spotId ~= nil then " · Working" else "",
				if best then " · Best to give" else ""
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
				local ask = LateStationsLogic.giveAsk(name, cat.variant, self:_copies(cat.catId))
				if ask ~= nil then
					self:_showConfirm(uid, ask)
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
	self:_paintTabs(rooms)
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
		tile.name.TextSize = nameSize(tile.name.Text, tile.name.AbsoluteSize.X)
		-- #3961 (mock): "On show" with a tick once given, the Give a copy chip while one can be, else why not
		local canGive = exhibit.coat == nil and #exhibit.give > 0
		tile.line.Text = if exhibit.coat ~= nil
			then "On show"
			elseif found then exhibit.line
			else "Not found yet"
		tile.line.TextColor3 = if exhibit.coat ~= nil then CARD.good else CARD.subtext
		tile.line.Visible = not canGive
		tile.chip.Visible = canGive
		tile.check.Visible = exhibit.coat ~= nil
		tile.frame:SetAttribute("Copies", exhibit.have)
		tile.stroke.Color = if exhibit.coat == "gold"
			then Theme.colors.gold
			elseif exhibit.coat == "rainbow" then Theme.colors.rainbowChip
			elseif exhibit.coat ~= nil then Theme.rarityColor(exhibit.rarity)
			else CARD.cardStroke
		tile.stroke.Thickness = if exhibit.coat == "gold" or exhibit.coat == "rainbow"
			then Theme.sizes.outline
			else Theme.sizes.stroke
	end
	local museum = self._museum
	local count = if museum ~= nil then museum.count else 0
	local total = if museum ~= nil then museum.total else 0
	local bonus = if museum ~= nil then museum.bonus or 0 else 0 -- "+10% tips" (bonusText without "forever")
	self._count.Text = string.format(
		"%d of %d exhibits · +%d%% tips",
		count,
		total,
		math.floor(bonus * 100 + 0.5)
	)
	-- #3961: one footer line: the note, else the hint while a copy can be given, else what a finished hall gives
	local note = if self._pending
		then "Giving..."
		else (self._note or if room.canFill > 0
			then "Tap Give a copy to fill an exhibit"
			else nil)
	self._noteLabel.Text = note or LateStationsLogic.roomBonusText()
	self._noteLabel.TextColor3 = if note ~= nil then PAL.subtext else PAL.gold
	self._fillButton.instance.Visible = (self._callbacks :: Callbacks).fill ~= nil
	self._fillButton:setEnabled(not self._pending and room.canFill > 0)
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
	self:_showTab()
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
				self:_showTab()
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
	for _, tab: HallTab in self._tabs do
		tab.button:destroy()
	end
	self._fillButton:destroy()
	self._back:destroy()
	self._giveIt:destroy()
	self._keep:destroy()
	self._panel:destroy()
end

return RelicMuseum
