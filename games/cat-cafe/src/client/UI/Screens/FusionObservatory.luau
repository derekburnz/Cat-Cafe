--!strict
-- #4104 The Fusion Observatory window (Snowy Mountain late station; Design-Agent/notes/fusion-observatory.md section 2).
-- Five copies of one cat in one coat make one in the next coat: 5 normal give 1 gold, 5 gold give 1 rainbow. The cocoa
-- station look with an ice blue edge and two pill tabs:
-- - Fuse: the dome card (free, a live timer while a fusion runs, or "Gold Mochi is ready" with Collect), then every
--   cat and coat with five free copies, best result first, each with Fuse, and up to three dimmed "1 more" rows.
-- - Coats: every cat's three coats as dots, lit when found, with the copies owned; a cat that can fuse now has a "!".
-- Fuse opens the confirm card over the window: the free copies with the default five ticked (the best level and the
-- four weakest), what comes out (level, name, the trait to keep), the time, and a two tap Fuse, because the five leave
-- when it starts.
--   FusionObservatory.new(callbacks)   built hidden; the UI registers its frame as the "FusionObservatory" modal
--   :setView(view, cats, busy, collection) :opened() :closed() :destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local FitText = require(script.Parent.Parent.Components.FitText)
local FusionLogic = require(script.Parent.Parent.Components.FusionLogic)
local GridFit = require(script.Parent.Parent.Components.GridFit)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog")) :: any

local PAL = MenuFamily.pal
local CARD = MenuFamily.card

export type Callbacks = {
	start: (uids: { string }, keepTraitUid: string?) -> (),
	collect: () -> (),
	close: () -> (),
}

export type FusionObservatory = {
	frame: Frame,
	setView: (
		self: FusionObservatory,
		view: any,
		cats: { [string]: any }?,
		busy: { [string]: boolean }?,
		collection: { [string]: { [string]: any }? }?
	) -> (),
	showTab: (self: FusionObservatory, tab: string) -> (),
	opened: (self: FusionObservatory) -> (),
	closed: (self: FusionObservatory) -> (),
	destroy: (self: FusionObservatory) -> (),
}

local MAX_SIZE = Vector2.new(820, 560)
local GAP = Theme.sizes.gap
local TAB_H = 36 -- a tap target (ui-review: 36 px or more)
local DOME_H = 88
local ROW_H = 68
local PICK_CELL = 88
local PICK_H = 104
local COAT_CELL = 112
local COAT_H = 104
local ARM_SECONDS = 4 -- the confirm's "Tap again" waits this long
local ICE = FusionLogic.ICE
local COAT_COLOURS: { [string]: Color3 } = {
	base = Color3.fromHex("C9B8A6"),
	gold = Color3.fromHex("F4C430"),
	rainbow = Color3.fromHex("C07CFF"),
}
local TABS = {
	{ id = "fuse", name = "Fuse" },
	{ id = "coats", name = "Coats" },
}

local FusionObservatory = {}
FusionObservatory.__index = FusionObservatory

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

local function card(props: { [string]: any }, edge: Color3?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("Frame", merged, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = edge or CARD.cardStroke, Thickness = 2 }),
	})
end

local function scroller(name: string, parent: Instance): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
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

-- the coat's colour on a tile edge: a gradient for rainbow
local function paintEdge(stroke: UIStroke, coat: string?)
	stroke.Color = if coat then COAT_COLOURS[coat] or CARD.cardStroke else CARD.cardStroke
	local gradient = stroke:FindFirstChildOfClass("UIGradient")
	if coat == "rainbow" then
		if gradient == nil then
			Create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("FF5E7E")),
					ColorSequenceKeypoint.new(0.35, Color3.fromHex("F4C430")),
					ColorSequenceKeypoint.new(0.65, Color3.fromHex("4DB8E8")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("C07CFF")),
				}),
				Parent = stroke,
			})
		end
		stroke.Color = Color3.new(1, 1, 1)
	elseif gradient then
		gradient:Destroy()
	end
end

-- Makes a tile and everything in it see-through but keeps its place, so the row doesn't jump; the returned function
-- puts every value back. For the swirl, which flies copies of the tiles (Motion-FX, #4105).
local function hideTiles(tiles: { GuiObject }): () -> ()
	local saved: { { item: any, prop: string, value: any } } = {}
	local function save(item: any, prop: string, value: any)
		table.insert(saved, { item = item, prop = prop, value = item[prop] })
		item[prop] = value
	end
	for _, tile in tiles do
		for _, item in { tile :: Instance, table.unpack(tile:GetDescendants()) } do
			if item:IsA("GuiObject") then
				save(item, "BackgroundTransparency", 1)
				if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
					save(item, "TextTransparency", 1)
				elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
					save(item, "ImageTransparency", 1)
				elseif item:IsA("ViewportFrame") then
					save(item, "ImageTransparency", 1)
				end
			elseif item:IsA("UIStroke") then
				save(item, "Enabled", false)
			end
		end
	end
	return function()
		for _, entry in saved do
			entry.item[entry.prop] = entry.value
		end
		table.clear(saved)
	end
end

-- Motion-FX's Effects/FusionFx (#4105) when it is there: swirl(tiles, centre, coat, onDone?) and burst(target, coat)
local function fusionFx(): any
	local client: Instance = script.Parent.Parent.Parent :: Instance
	local effects = client:FindFirstChild("Effects")
	local module = if effects then effects:FindFirstChild("FusionFx") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, fx = pcall(require, module)
	return if ok and type(fx) == "table" then fx else nil
end

local function coatTag(coat: string): string
	if coat == "gold" then
		return "✨ Gold"
	elseif coat == "rainbow" then
		return "🌈 Rainbow"
	end
	return "Normal"
end

function FusionObservatory.new(callbacks: Callbacks): FusionObservatory
	local self = setmetatable({}, FusionObservatory) :: any
	self._callbacks = callbacks
	self._view = nil :: any
	self._cats = nil :: { [string]: any }?
	self._busy = nil :: { [string]: boolean }?
	self._collection = {} :: { [string]: { [string]: any }? }
	self._tab = "fuse"
	self._open = false
	self._tick = 0
	self._ready = {} :: { FusionLogic.Group }
	self._almost = {} :: { FusionLogic.Group }
	self._group = nil :: string? -- the confirm card's group key
	self._picked = {} :: { [string]: boolean }
	self._keep = nil :: string? -- the trait to keep: the copy's uid
	self._armed = false
	self._armToken = 0
	self._buyH = Scale.tapHeight(40, Theme.sizes.buttonDepth)

	local panel = Panel.new({
		dark = true,
		name = "FusionObservatory",
		title = "Fusion Observatory",
		subtitle = "5 of a cat make 1 in the next coat",
		color = Color3.fromHex("2F6E9E"),
		icon = "🔭",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_H),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	self._tabButtons = {} :: { [string]: any }
	for order, tab in TABS do
		self._tabButtons[tab.id] = Button.new({
			name = "Tab_" .. tab.id,
			text = tab.name,
			style = if tab.id == self._tab then "sky" else "ghost",
			size = UDim2.fromOffset(if tab.id == "coats" then 128 else 104, TAB_H),
			textSize = Theme.sizes.textSmall,
			layoutOrder = order,
			parent = tabs,
			onClick = function()
				self:showTab(tab.id)
			end,
		})
	end
	local pages: Frame = Create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TAB_H + GAP),
		Size = UDim2.new(1, 0, 1, -(TAB_H + GAP)),
		Parent = content,
	})
	self:_buildFuse(pages)
	self:_buildCoats(pages)
	self:_buildConfirm(content)
	self:showTab("fuse")
	return self :: FusionObservatory
end

----------------------------------------------------------------------------------------------------
-- Fuse
----------------------------------------------------------------------------------------------------

function FusionObservatory._buildFuse(self: any, pages: Frame)
	local page: Frame = Create("Frame", {
		Name = "FusePage",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = pages,
	})
	self._fusePage = page

	-- the dome card
	local dome = card({
		Name = "Dome",
		Size = UDim2.new(1, 0, 0, DOME_H),
		Parent = page,
	}, ICE)
	self._dome = dome
	self._domePortrait = CatPortrait.new({
		parent = dome,
		size = UDim2.fromOffset(DOME_H - 16, DOME_H - 16),
		position = UDim2.fromOffset(8, 8),
		still = true,
		head = true,
	})
	self._domeIcon = text({
		Name = "Icon",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(DOME_H - 16, DOME_H - 16),
		TextScaled = true,
		Text = "🔭",
		Parent = dome,
	})
	local left = DOME_H + 4
	self._domeTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(left, 10),
		Size = UDim2.new(1, -(left + 150), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dome,
	})
	FitText.shrink(self._domeTitle)
	self._domeLine = text({
		Name = "Line",
		Position = UDim2.fromOffset(left, 36),
		Size = UDim2.new(1, -(left + 150), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dome,
	})
	FitText.shrink(self._domeLine)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = CARD.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(left, 62),
		Size = UDim2.new(1, -(left + 150), 0, 10),
		Parent = dome,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._domeTrack = track
	self._domeFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = ICE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._collect = Button.new({
		name = "Collect",
		text = "Collect",
		style = "primary",
		size = UDim2.fromOffset(132, self._buyH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -10, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = dome,
		onClick = function()
			local coat = if self._view and self._view.running then self._view.running.coat else nil
			self._callbacks.collect()
			local fx = fusionFx()
			if fx and type(fx.burst) == "function" and coat then
				pcall(fx.burst, self._domePortrait.frame, coat)
			end
		end,
	})

	local list = scroller("Ready", page)
	list.Position = UDim2.fromOffset(0, DOME_H + GAP)
	list.Size = UDim2.new(1, 0, 1, -(DOME_H + GAP))
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	self._readyList = list
	self._rows = {} :: { any }
	self._empty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		Text = "Catch 5 of one cat in one coat to fuse them",
		Visible = false,
		LayoutOrder = 999,
		Parent = list,
	})
end

function FusionObservatory._row(self: any, index: number): any
	local made = self._rows[index]
	if made then
		return made
	end
	local row = card({
		Name = "Row" .. index,
		Size = UDim2.new(1, -4, 0, ROW_H),
		LayoutOrder = index,
		Parent = self._readyList,
	})
	local stroke = row:FindFirstChildOfClass("UIStroke") :: UIStroke
	local from = CatPortrait.new({
		parent = row,
		size = UDim2.fromOffset(ROW_H - 12, ROW_H - 12),
		position = UDim2.fromOffset(6, 6),
		still = true,
		head = true,
	})
	local count = text({
		Name = "Count",
		Position = UDim2.fromOffset(ROW_H + 2, 8),
		Size = UDim2.new(1, -(ROW_H + 2 + ROW_H + 160), 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	FitText.shrink(count)
	local line = text({
		Name = "Line",
		Position = UDim2.fromOffset(ROW_H + 2, 34),
		Size = UDim2.new(1, -(ROW_H + 2 + ROW_H + 160), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	FitText.shrink(line)
	local arrow = text({
		Name = "Arrow",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(150 + ROW_H - 4), 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = CARD.subtext,
		Text = "→",
		Parent = row,
	})
	local to = CatPortrait.new({
		parent = row,
		size = UDim2.fromOffset(ROW_H - 12, ROW_H - 12),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -150, 0.5, 0),
		still = true,
		head = true,
	})
	local button = Button.new({
		name = "Fuse",
		text = "Fuse",
		style = "sky",
		size = UDim2.fromOffset(130, self._buyH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = row,
		onClick = function()
			local key = made.key
			if key ~= nil then
				self:_openConfirm(key)
			end
		end,
	})
	made = {
		row = row,
		stroke = stroke,
		from = from,
		to = to,
		count = count,
		line = line,
		arrow = arrow,
		button = button,
		key = nil :: string?,
		shown = "",
	}
	self._rows[index] = made
	return made
end

function FusionObservatory._paintFuse(self: any)
	local view = self._view
	local now = workspace:GetServerTimeNow()
	local dome = FusionLogic.dome(view, now)
	-- a fusion that finishes while the Coats tab is up brings the Fuse tab back, so Collect is seen (Review-QA)
	if dome.state == "ready" and self._domeState == "running" and self._tab == "coats" then
		self:showTab("fuse")
	end
	self._domeState = dome.state
	self._domeTitle.Text = dome.title
	self._domeLine.Text = dome.line
	self._domeFill.Size = UDim2.fromScale(dome.share, 1)
	self._domeFill.BackgroundColor3 = if dome.coat then COAT_COLOURS[dome.coat] or ICE else ICE
	self._domeTrack.Visible = dome.state == "running"
	self._collect.instance.Visible = dome.state == "ready"
	local def = if dome.catId then Catalog.getCat(dome.catId) else nil
	self._domeIcon.Visible = def == nil
	self._domePortrait.frame.Visible = def ~= nil
	local domeKey = (dome.catId or "") .. ":" .. (dome.coat or "")
	if def ~= nil and self._domeShown ~= domeKey then
		self._domeShown = domeKey
		self._domePortrait:set(def, dome.coat == "gold" or dome.coat == "rainbow")
	end
	paintEdge(self._dome:FindFirstChildOfClass("UIStroke") :: UIStroke, dome.coat)

	local busyDome = dome.state ~= "free"
	local rows: { { group: FusionLogic.Group, ready: boolean } } = {}
	for _, group in self._ready do
		table.insert(rows, { group = group, ready = true })
	end
	for _, group in self._almost do
		table.insert(rows, { group = group, ready = false })
	end
	for index = 1, math.max(#rows, #self._rows) do
		local entry = rows[index]
		if entry == nil then
			local spare = self._rows[index]
			if spare then
				spare.row.Visible = false
				spare.key = nil
			end
			continue
		end
		local group = entry.group
		local made = self:_row(index)
		made.row.Visible = true
		made.key = if entry.ready then group.key else nil
		if made.shown ~= group.key then
			made.shown = group.key
			local catDef = Catalog.getCat(group.catId)
			made.from:set(catDef, group.coat == "gold")
			made.to:set(catDef, true)
		end
		made.count.Text = if entry.ready
			then FusionLogic.countText(group)
			else FusionLogic.almostText(group)
		made.line.Text = if entry.ready
			then ("Makes 1 %s %s"):format(FusionLogic.COAT_NAMES[group.next], group.name)
			else "Catch more to fuse"
		made.row.BackgroundTransparency = if entry.ready then 0 else 0.35
		made.arrow.Visible = entry.ready
		made.to.frame.Visible = entry.ready
		made.button.instance.Visible = entry.ready
		made.button:setText(if busyDome then "Dome busy" else "Fuse")
		made.button:setEnabled(not busyDome)
		paintEdge(made.stroke, if entry.ready then group.next else nil)
	end
	self._empty.Visible = #rows == 0
end

----------------------------------------------------------------------------------------------------
-- Coats
----------------------------------------------------------------------------------------------------

function FusionObservatory._buildCoats(self: any, pages: Frame)
	local page = scroller("CoatsPage", pages)
	page.Visible = false
	self._coatsPage = page
	local layout: UIGridLayout = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	GridFit.fit(page, layout, COAT_CELL, 6, function()
		return COAT_H
	end)
	self._coatCells = {} :: { [string]: any }
end

-- built the first time the tab opens, so a player who never looks pays nothing for the portraits
function FusionObservatory._coatCell(self: any, catId: string, order: number): any
	local made = self._coatCells[catId]
	if made then
		return made
	end
	local cell = card({
		Name = "Coat_" .. catId,
		LayoutOrder = order,
		Parent = self._coatsPage,
	})
	local portrait = CatPortrait.new({
		parent = cell,
		size = UDim2.fromOffset(46, 46),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 4),
		still = true,
		head = true,
	})
	portrait:set(Catalog.getCat(catId), false)
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(4, 52),
		Size = UDim2.new(1, -8, 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny + 1,
		Parent = cell,
	})
	FitText.shrink(name)
	local dots: Frame = Create("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 72),
		Size = UDim2.new(1, -8, 0, 26),
		Parent = cell,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local coats = {} :: { [string]: any }
	for order2, coat in { "base", "gold", "rainbow" } do
		local holder: Frame = Create("Frame", {
			Name = coat,
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / 3, -3, 1, 0),
			LayoutOrder = order2,
			Parent = dots,
		})
		local dot: Frame = Create("Frame", {
			Name = "Dot",
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Parent = holder,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local owned = text({
			Name = "Owned",
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -14, 1, 0),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = CARD.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = holder,
		})
		FitText.shrink(owned)
		coats[coat] = { dot = dot, owned = owned }
	end
	local bang = text({
		Name = "Bang",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.red or Color3.fromHex("E0463C"),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "!",
		Visible = false,
		ZIndex = 3,
		Parent = cell,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bang })
	made = { cell = cell, portrait = portrait, name = name, coats = coats, bang = bang }
	self._coatCells[catId] = made
	return made
end

function FusionObservatory._paintCoats(self: any)
	local tracks = FusionLogic.coatTrack(self._cats, self._collection, self._ready)
	local seen: { [string]: boolean } = {}
	for order, track in tracks do
		seen[track.catId] = true
		local made = self:_coatCell(track.catId, order)
		made.cell.Visible = true
		made.cell.LayoutOrder = order
		made.name.Text = track.name
		for coat, piece in made.coats do
			local found = track.found[coat] == true
			piece.dot.BackgroundColor3 = if found then COAT_COLOURS[coat] else CARD.line
			local count = track.owned[coat] or 0
			piece.owned.Text = if count > 0 then "×" .. tostring(count) else "-"
		end
		made.bang.Visible = track.canFuse
	end
	for catId, made in self._coatCells do
		if not seen[catId] then
			made.cell.Visible = false
		end
	end
end

----------------------------------------------------------------------------------------------------
-- The confirm card
----------------------------------------------------------------------------------------------------

function FusionObservatory._buildConfirm(self: any, content: Frame)
	local shade: TextButton = Create("TextButton", {
		Name = "Confirm",
		AutoButtonColor = false,
		BackgroundColor3 = PAL.panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Visible = false,
		ZIndex = 20,
		Parent = content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._confirm = shade
	self._confirmTitle = text({
		Name = "Title",
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = ICE,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = shade,
	})
	Outline.text(self._confirmTitle, 1)
	FitText.shrink(self._confirmTitle)
	self._pickedLine = text({
		Name = "Picked",
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 26),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = shade,
	})
	FitText.shrink(self._pickedLine)

	-- the foot: the result, the trait chips, the time, Back and Fuse
	local footH = self._buyH + 6 + 20 + 4 + 36 + 4 + 22
	local list = scroller("Copies", shade)
	list.ZIndex = 21
	list.Position = UDim2.fromOffset(0, 48)
	list.Size = UDim2.new(1, 0, 1, -(48 + footH + 6))
	self._copyList = list
	local layout: UIGridLayout = Create("UIGridLayout", {
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	GridFit.fit(list, layout, PICK_CELL, 6, function()
		return PICK_H
	end)
	self._copyCells = {} :: { any }

	local foot: Frame = Create("Frame", {
		Name = "Foot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, footH),
		ZIndex = 21,
		Parent = shade,
	})
	self._resultLine = text({
		Name = "Result",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 0),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = foot,
	})
	FitText.shrink(self._resultLine)
	local chips: Frame = Create("Frame", {
		Name = "Traits",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 0, 36),
		ZIndex = 22,
		Parent = foot,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	self._chips = chips
	self._chipButtons = {} :: { any }
	self._timeLine = text({
		Name = "Time",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 66),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = foot,
	})
	FitText.shrink(self._timeLine)
	local buttons: Frame = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, self._buyH),
		ZIndex = 22,
		Parent = foot,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.new(0.28, 0, 1, 0),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		zIndex = 23,
		parent = buttons,
		onClick = function()
			self:_closeConfirm()
		end,
	})
	self._fuseButton = Button.new({
		name = "FuseGo",
		text = "Fuse",
		style = "sky",
		size = UDim2.new(0.62, 0, 1, 0),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		zIndex = 23,
		parent = buttons,
		onClick = function()
			self:_fuse()
		end,
	})
end

function FusionObservatory._copyCell(self: any, index: number): any
	local made = self._copyCells[index]
	if made then
		return made
	end
	local cell: TextButton = Create("TextButton", {
		Name = "Copy" .. index,
		AutoButtonColor = false,
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Text = "",
		ZIndex = 22,
		Parent = self._copyList,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = CARD.cardStroke,
		Thickness = 2,
		Parent = cell,
	})
	local portrait = CatPortrait.new({
		parent = cell,
		size = UDim2.fromOffset(48, 48),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 4),
		zIndex = 23,
		still = true,
		head = true,
	})
	local level = text({
		Name = "Level",
		Position = UDim2.fromOffset(4, 54),
		Size = UDim2.new(1, -8, 0, 18),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		ZIndex = 23,
		Parent = cell,
	})
	local tag = text({
		Name = "Tag",
		Position = UDim2.fromOffset(4, 74),
		Size = UDim2.new(1, -8, 0, 24),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		TextWrapped = true,
		ZIndex = 23,
		Parent = cell,
	})
	FitText.shrink(tag)
	local check = text({
		Name = "Check",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.goodDark,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "✓",
		Visible = false,
		ZIndex = 24,
		Parent = cell,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = check })
	made = {
		cell = cell,
		stroke = stroke,
		portrait = portrait,
		level = level,
		tag = tag,
		check = check,
		uid = nil :: string?,
		shown = "",
	}
	cell.Activated:Connect(function()
		local uid = made.uid
		if uid == nil then
			return
		end
		if self._picked[uid] then
			self._picked[uid] = nil
		else
			local count = 0
			for _ in self._picked do
				count += 1
			end
			if count >= FusionLogic.COPIES then
				return -- five already: untick one first
			end
			self._picked[uid] = true
		end
		self._armed = false
		self:_paintConfirm()
	end)
	self._copyCells[index] = made
	return made
end

function FusionObservatory._groupByKey(self: any, key: string?): FusionLogic.Group?
	if key == nil then
		return nil
	end
	for _, group in self._ready do
		if group.key == key then
			return group
		end
	end
	return nil
end

function FusionObservatory._openConfirm(self: any, key: string)
	local group = self:_groupByKey(key)
	if group == nil then
		return
	end
	self._group = key
	self._picked = {}
	for _, uid in FusionLogic.defaultPick(group) do
		self._picked[uid] = true
	end
	self._keep = nil
	self._armed = false
	self._confirm.Visible = true
	self:_paintConfirm()
end

function FusionObservatory._closeConfirm(self: any)
	self._group = nil
	self._picked = {}
	self._keep = nil
	self._armed = false
	self._confirm.Visible = false
end

function FusionObservatory._pickedList(self: any, group: FusionLogic.Group): { string }
	local out: { string } = {}
	for _, copy in group.free do
		if self._picked[copy.uid] then
			table.insert(out, copy.uid)
		end
	end
	return out
end

function FusionObservatory._paintConfirm(self: any)
	local group = self:_groupByKey(self._group)
	if group == nil then
		-- the copies changed (traded, locked, fused): the card closes
		self:_closeConfirm()
		return
	end
	local nextName = FusionLogic.COAT_NAMES[group.next]
	local fromName = if group.coat == "base"
		then group.name
		else FusionLogic.COAT_NAMES[group.coat] .. " " .. group.name
	self._confirmTitle.Text = "Fuse "
		.. tostring(FusionLogic.COPIES)
		.. " "
		.. fromName
		.. " into 1 "
		.. tostring(nextName)
		.. " "
		.. group.name
	-- picks that are gone drop out
	local still: { [string]: boolean } = {}
	for _, copy in group.free do
		if self._picked[copy.uid] then
			still[copy.uid] = true
		end
	end
	self._picked = still
	local picked = self:_pickedList(group)
	self._pickedLine.Text = ("%d of %d picked · tap a cat to swap it"):format(
		#picked,
		FusionLogic.COPIES
	)
	-- strongest first in the strip, so the kept copy leads
	local copies = table.clone(group.free)
	table.sort(copies, function(a: FusionLogic.Copy, b: FusionLogic.Copy): boolean
		if a.level ~= b.level then
			return a.level > b.level
		end
		return a.uid < b.uid
	end)
	local def = Catalog.getCat(group.catId)
	for index = 1, math.max(#copies, #self._copyCells) do
		local copy = copies[index]
		if copy == nil then
			local spare = self._copyCells[index]
			if spare then
				spare.cell.Visible = false
				spare.uid = nil
			end
			continue
		end
		local made = self:_copyCell(index)
		made.cell.Visible = true
		made.uid = copy.uid
		if made.shown ~= group.key then
			made.shown = group.key
			made.portrait:set(def, group.coat == "gold")
		end
		made.level.Text = "Lv " .. tostring(copy.level)
		local traitName = nil
		if copy.trait then
			local result = FusionLogic.result(group, { copy.uid })
			traitName = if result.traits[1] then result.traits[1].name else nil
		end
		made.tag.Text = traitName or (if copy.name then copy.name else "")
		local on = self._picked[copy.uid] == true
		made.check.Visible = on
		made.stroke.Color = if on then ICE else CARD.cardStroke
		made.stroke.Thickness = if on then 3 else 2
	end

	local result = FusionLogic.result(group, picked)
	local nameNote = if result.name then " · keeps " .. result.name .. "'s name" else ""
	self._resultLine.Text = "→ 1 "
		.. tostring(nextName)
		.. " "
		.. group.name
		.. " · Lv "
		.. tostring(result.level)
		.. nameNote
	-- the trait chips: the rarest is the default
	local keep = self._keep
	local valid = false
	for _, choice in result.traits do
		if choice.uid == keep then
			valid = true
		end
	end
	if not valid then
		keep = if result.traits[1] then result.traits[1].uid else nil
		self._keep = keep
	end
	self._chips.Visible = #result.traits > 0
	for index = 1, math.max(#result.traits, #self._chipButtons) do
		local choice = result.traits[index]
		local chip = self._chipButtons[index]
		if choice == nil then
			if chip then
				chip.instance.Visible = false
			end
			continue
		end
		if chip == nil then
			chip = Button.new({
				name = "Trait" .. index,
				text = "",
				style = "ghost",
				size = UDim2.fromOffset(170, 36),
				textSize = Theme.sizes.textSmall,
				layoutOrder = index,
				zIndex = 23,
				parent = self._chips,
				onClick = function()
					local current = FusionLogic.result(
						assert(self:_groupByKey(self._group)),
						self:_pickedList(assert(self:_groupByKey(self._group)))
					)
					local pick = current.traits[index]
					if pick then
						self._keep = pick.uid
						self._armed = false
						self:_paintConfirm()
					end
				end,
			})
			self._chipButtons[index] = chip
		end
		chip.instance.Visible = true
		chip:setText("Keep: " .. choice.name .. " (" .. choice.rarity .. ")")
		chip:setStyle(if choice.uid == keep then "sky" else "ghost")
	end
	self._timeLine.Text = "Ready in "
		.. FusionLogic.duration(FusionLogic.seconds(self._view, group.next))
		.. " · the five leave when it starts"
	local ready = #picked == FusionLogic.COPIES
	self._fuseButton:setText(
		if ready
			then FusionLogic.fuseText(group, self._armed)
			else ("Pick %d more"):format(FusionLogic.COPIES - #picked)
	)
	self._fuseButton:setEnabled(ready)
end

function FusionObservatory._fuse(self: any)
	local group = self:_groupByKey(self._group)
	if group == nil then
		return
	end
	local picked = self:_pickedList(group)
	if #picked ~= FusionLogic.COPIES then
		return
	end
	if not self._armed then
		self._armed = true
		self._armToken += 1
		local token = self._armToken
		self:_paintConfirm()
		task.delay(ARM_SECONDS, function()
			if self._armToken == token and self._armed then
				self._armed = false
				if self._confirm.Visible then
					self:_paintConfirm()
				end
			end
		end)
		return
	end
	local result = FusionLogic.result(group, picked)
	local keep = if #result.traits > 0 then self._keep else nil
	self._callbacks.start(picked, keep)
	-- the five fly into the dome, and the card closes as they meet (at once without the effect or with Reduce Motion)
	local fx = fusionFx()
	local tiles: { GuiObject } = {}
	for _, made in self._copyCells do
		if made.uid ~= nil and self._picked[made.uid] and made.cell.Visible then
			table.insert(tiles, made.cell)
		end
	end
	local closed = false
	local restore: (() -> ())? = nil
	local function close()
		if not closed then
			closed = true
			self:_closeConfirm()
			if restore then
				restore() -- the card is shut by now, so the tiles are ready for the next fusion
			end
		end
	end
	if fx and type(fx.swirl) == "function" and #tiles > 0 then
		self._fuseButton:setEnabled(false)
		local ok = pcall(fx.swirl, tiles, self._dome, group.next, close)
		if ok then
			if not closed then
				restore = hideTiles(tiles) -- the swirl has its copies; the five originals go see-through in the same frame
			end
			task.delay(3, close) -- never left open if the effect stops early
			return
		end
	end
	close()
end

----------------------------------------------------------------------------------------------------

function FusionObservatory.showTab(self: any, tab: string)
	self._tab = tab
	self._fusePage.Visible = tab == "fuse"
	self._coatsPage.Visible = tab == "coats"
	for id, button in self._tabButtons do
		button:setStyle(if id == tab then "sky" else "ghost")
	end
	self:_paint()
end

function FusionObservatory.setView(
	self: any,
	view: any,
	cats: { [string]: any }?,
	busy: { [string]: boolean }?,
	collection: { [string]: { [string]: any }? }?
)
	self._view = view
	self._cats = cats
	self._busy = busy
	self._collection = collection or {}
	self._ready, self._almost = FusionLogic.groups(cats, busy)
	self:_paint()
end

function FusionObservatory._paint(self: any)
	self:_paintFuse()
	if self._tab == "coats" then
		self:_paintCoats()
	end
	if self._confirm.Visible then
		self:_paintConfirm()
	end
end

-- the dome's timer ticks once a second while the window is open
function FusionObservatory._startTick(self: any)
	self._tick += 1
	local token = self._tick
	task.spawn(function()
		while self._open and self._tick == token do
			task.wait(1)
			if self._open and self._tick == token then
				self:_paintFuse()
			end
		end
	end)
end

function FusionObservatory.opened(self: any)
	self._open = true
	self:_closeConfirm()
	self:showTab("fuse")
	self:_startTick()
end

function FusionObservatory.closed(self: any)
	self._open = false
	self._tick += 1
	self:_closeConfirm()
end

function FusionObservatory.destroy(self: any)
	self._open = false
	self._tick += 1
	self._domePortrait:destroy()
	for _, made in self._rows do
		made.from:destroy()
		made.to:destroy()
	end
	for _, made in self._copyCells do
		made.portrait:destroy()
	end
	for _, made in self._coatCells do
		made.portrait:destroy()
	end
	self._panel:destroy()
end

return FusionObservatory
