--!strict
-- The Index window (the Cats screen is its own window since 2026-10-27, Screens/MyCats). Three tabs:
--   Cats and Gold (Derek's Set 4 answer, 2026-11-01: "sorted into a normal and gold tab and a cleaner ui for
--         navigating it looks so cluttered right now should be able to just swap between normal/gold and scroll
--         through area's very simply showing rarity and what hasn't been found with a black filling and a darker
--         background"): one scroll down a dark page, an area at a time in tier order (Components/IndexBook). Each
--         area has a header line (its name in its colour, "7 / 10" or "Complete!", a slim bar and a Rewards button)
--         over its cats as tiles in their rarity colour, rarest last, with the cat's name under it. A cat not found
--         yet is a black silhouette on a darkened tile with its rarity in place of the name, and no other writing
--         (Derek 2026-10-28: "just show found by the picture being filled its black if not found simple no need for
--         writing"). The Gold tab shows each cat's gold coat and counts the gold track. Tap a tile for its details
--         on a card over the page.
--         The Rewards button opens the area's reward strip (Screens/IndexStrip, F48) under the header, on the tab's
--         track; it turns green as Claim! with a red count while a reward waits. The Cats tab starts with an All
--         cats line (the All Cats track, F54). The spare cats (F78) have no page (Derek 2026-10-28).
--   Decor: the Decor Index (F53, Screens/DecorIndex): a page per crate with its twelve pieces and two rewards.
--   Beside the tabs, the forever bonuses the claimed rewards add up to (F54 v0.10): tips, gold luck with the gold
--   chance it gives, and faster bait, each in its track's colour (Components/IndexRewards.totals).
-- The Index opens on the first open area with cats still to find; an Index Board's prompt opens it on that area.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local DecorIndex = require(script.Parent.DecorIndex)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local Format = require(script.Parent.Parent.Components.Format)
local IndexBook = require(script.Parent.Parent.Components.IndexBook)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local IndexStrip = require(script.Parent.IndexStrip)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	claimIndexReward: (areaId: string, milestoneId: string) -> (),
	close: () -> (),
}

-- "Index" is the Cats tab (the name init and the Index Boards already use)
export type Tab = "Index" | "Gold" | "Decor"

export type CatCollection = {
	frame: Frame,
	setCatalog: (self: CatCollection, catalog: Types.Catalog) -> (),
	render: (self: CatCollection, state: Types.PlayerState) -> (),
	showTab: (self: CatCollection, tab: Tab) -> (),
	showArea: (self: CatCollection, areaId: string) -> (),
	setNight: (self: CatCollection, night: boolean) -> (),
	destroy: (self: CatCollection) -> (),
}

local TILE = Vector2.new(104, 128)
local PORTRAIT = 84
local TAB_W = 112
local TAB_HEIGHT = 40
local HEADER_HEIGHT = 52
local REWARDS = Vector2.new(124, 40) -- an area's Rewards button
local NAME_W = 220
local BAR_H = 10
local PERK_HEIGHT = 26 -- a forever bonus pill beside the tabs
local DETAIL = Vector2.new(470, 216)
local DETAIL_ART = 176
local ALL_AREA = IndexRewards.ALL_AREA
local PORTRAITS_PER_FRAME = 10 -- a tab's 50-odd models are cloned over a few frames

local CatCollection = {}
CatCollection.__index = CatCollection

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

local function pill(
	parent: Instance,
	label: string,
	color: Color3,
	textColor: Color3,
	position: UDim2,
	anchor: Vector2?
)
	return Create("TextLabel", {
		Name = "Pill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		Position = position,
		AnchorPoint = anchor or Vector2.new(),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = textColor,
		Text = label,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

-- A red count badge on a tab's or button's top right corner, hidden until something is waiting (F48).
local function badge(parent: Instance, size: number): (Frame, TextLabel)
	local dot: Frame = Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(size, size),
		Visible = false,
		ZIndex = 6,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local mark = text({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 7,
		Parent = dot,
	})
	return dot, mark
end

-- The product of every UIScale from `gui` up, so a header's on-screen offset can be turned back into canvas pixels.
local function scaleOf(gui: Instance): number
	local scale = 1
	local node: Instance? = gui
	while node do
		local found = node:FindFirstChildOfClass("UIScale")
		if found then
			scale *= (found :: UIScale).Scale
		end
		node = node.Parent
	end
	return math.max(scale, 0.01)
end

local function trackOf(tab: Tab): IndexRewards.Track
	if tab == "Gold" then
		return "gold"
	end
	return "normal"
end

function CatCollection.new(callbacks: Callbacks): CatCollection
	local self = setmetatable({}, CatCollection) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._catById = {} :: { [string]: Types.CatDef }
	self._cells = {} :: { [string]: any }
	self._sections = {} :: { [string]: any } -- area id (or "all") -> its header, strip and grid
	self._loadToken = 0 -- the latest portrait queue's, so an older one stops
	self._tab = "Index" :: Tab
	self._selected = nil :: string? -- the cat on the detail card
	self._detailId = nil :: string? -- the cat whose model the detail card holds
	self._detailGold = false
	self._scrollTo = nil :: string? -- an area to bring to the top on the next render
	self._opened = false -- the first render picks the area to open on
	self._night = false
	self._dirty = true
	self._lastState = nil :: Types.PlayerState?

	local panel = Panel.new({
		name = "Collection",
		color = Theme.colors.good,
		icon = Theme.icons.collection,
		title = "Index",
		subtitle = "0 / 0 found",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(820, 580), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- tabs: Cats, Gold, Decor
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function tabButton(name: string, label: string, icon: string, order: number, tab: Tab)
		local button = Button.new({
			name = name,
			text = label,
			icon = icon,
			style = "ghost",
			size = UDim2.fromOffset(TAB_W, TAB_HEIGHT),
			textSize = Theme.sizes.textBody,
			layoutOrder = order,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self:showTab(tab)
			end,
		})
		local dot, count = badge(button.instance, 24)
		return button, dot, count
	end
	self._indexTab, self._indexBadge, self._indexBadgeCount =
		tabButton("IndexTab", "Cats", Theme.icons.cats, 1, "Index")
	self._goldTab, self._goldBadge, self._goldBadgeCount =
		tabButton("GoldTab", "Gold", "⭐", 2, "Gold")
	self._decorTab, self._decorBadge, self._decorBadgeCount =
		tabButton("DecorTab", "Decor", Theme.icons.decor, 3, "Decor")
	self._decorTab.instance.Visible = false

	-- the forever bonuses, right of the tabs; shrinks to fit the room the tabs leave on a narrow screen
	local perks: Frame = Create("Frame", {
		Name = "Forever",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, TAB_HEIGHT),
		Visible = false,
		Parent = panel.content,
	})
	local perksLayout: UIListLayout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = perks,
	})
	local perksScale: UIScale = Create("UIScale", { Parent = perks })
	self._perksCaption = text({
		Name = "Caption",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, PERK_HEIGHT),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.index.subtext,
		TextTruncate = Enum.TextTruncate.None,
		Text = "Forever",
		Parent = perks,
	})
	self._perks = perks
	self._perkPills = {} :: { [string]: TextLabel }
	for order, perk in IndexRewards.PERKS do
		local label: TextLabel =
			pill(perks, "", PrizeChips.perkColor(perk), Theme.colors.white, UDim2.new())
		label.Name = perk
		label.LayoutOrder = order
		label.Size = UDim2.fromOffset(0, PERK_HEIGHT)
		label.TextSize = Theme.sizes.textSmall
		label.Visible = false
		Outline.border(label, 2)
		Outline.text(label, 1.5)
		self._perkPills[perk] = label
	end
	local tabsLayout = tabs:FindFirstChildOfClass("UIListLayout")
	local function fitPerks()
		-- AbsoluteContentSize already includes the UIScale, so divide it back out for the row's own width
		local natural = perksLayout.AbsoluteContentSize.X / math.max(perksScale.Scale, 0.01)
		local used = if tabsLayout then tabsLayout.AbsoluteContentSize.X else 0
		local room = panel.content.AbsoluteSize.X - used - Theme.sizes.gap
		perksScale.Scale = if room > 0 and natural > room then room / natural else 1
	end
	perksLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitPerks)
	panel.content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPerks)
	if tabsLayout then
		tabsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitPerks)
	end

	-- Cats and Gold: one scroll of areas
	local indexTop = TAB_HEIGHT + Theme.sizes.gap
	self._book = Create("ScrollingFrame", {
		Name = "Book",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, indexTop),
		Size = UDim2.new(1, 0, 1, -indexTop),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap * 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
	})

	-- Decor Index: a page per crate (Screens/DecorIndex)
	self._decor = Create("Frame", {
		Name = "Decor",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, indexTop),
		Size = UDim2.new(1, 0, 1, -indexTop),
		Visible = false,
		Parent = panel.content,
	})
	self._decorIndex = DecorIndex.new(self._decor, { claim = callbacks.claimIndexReward })

	self:_buildDetail(panel.content)
	self:_paintTabs()
	return self :: CatCollection
end

-- The card a tapped tile opens over the page: the cat big, its name, rarity, where it lives, what it earns and its
-- story once found. The dim cover behind it or the X closes it.
function CatCollection._buildDetail(self: any, parent: Instance)
	local cover: TextButton = Create("TextButton", {
		Name = "DetailCover",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Visible = false,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._cover = cover
	cover.Activated:Connect(function()
		self:_closeDetail()
	end)
	local card: Frame = Create("Frame", {
		Name = "Card",
		Active = true, -- taps on the card stay on it
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(DETAIL.X, DETAIL.Y),
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		ZIndex = 41,
		Parent = cover,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._detailStroke = Outline.border(card, Theme.sizes.outline + 1)
	self._detailDisc = Create("Frame", {
		Name = "Disc",
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, (DETAIL.Y - DETAIL_ART) / 2),
		Size = UDim2.fromOffset(DETAIL_ART, DETAIL_ART),
		ZIndex = 42,
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._detailArt = CatPortrait.new({
		parent = card,
		size = UDim2.fromOffset(DETAIL_ART, DETAIL_ART),
		position = UDim2.fromOffset(16, (DETAIL.Y - DETAIL_ART) / 2),
		zIndex = 43,
	})
	local left = DETAIL_ART + 32
	self._detailName = text({
		Name = "Name",
		Position = UDim2.fromOffset(left, 16),
		Size = UDim2.new(1, -(left + 56), 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		ZIndex = 42,
		Parent = card,
	})
	self._detailPill = pill(
		card,
		"",
		Theme.colors.line,
		Theme.colors.ink,
		UDim2.fromOffset(left, 50),
		Vector2.new(0, 0)
	)
	self._detailPill.ZIndex = 42
	self._detailMeta = text({
		Name = "Meta",
		Position = UDim2.fromOffset(left, 78),
		Size = UDim2.new(1, -(left + 16), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		RichText = true, -- the favourite role in bold
		ZIndex = 42,
		Parent = card,
	})
	self._detailDesc = text({
		Name = "Description",
		Position = UDim2.fromOffset(left, 100),
		Size = UDim2.new(1, -(left + 16), 0, DETAIL.Y - 116),
		TextSize = Theme.sizes.textSmall,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 42,
		Parent = card,
	})
	self._detailClose = Button.new({
		name = "Close",
		text = "X",
		style = "close",
		size = UDim2.fromOffset(Theme.sizes.touchMin, Theme.sizes.touchMin),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 8),
		textSize = Theme.sizes.textLarge,
		sound = "uiClose",
		zIndex = 44,
		parent = card,
		onClick = function()
			self:_closeDetail()
		end,
	})
	-- closing the window puts the card away, so the page is what opens next time
	self.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not self.frame.Visible then
			self:_closeDetail()
		end
	end)
end

function CatCollection._closeDetail(self: any)
	self._selected = nil
	self._cover.Visible = false
end

-- The tabs' looks and the page behind them: dark for Cats and Gold, the light window body for Decor.
function CatCollection._paintTabs(self: any)
	local tab: Tab = self._tab
	self._indexTab:setStyle(if tab == "Index" then "gold" else "ghost")
	self._goldTab:setStyle(if tab == "Gold" then "gold" else "ghost")
	self._decorTab:setStyle(if tab == "Decor" then "gold" else "ghost")
	local dark = tab ~= "Decor"
	self._panel.body.BackgroundColor3 = if dark then Theme.index.body else Theme.modal.panel
	self._perksCaption.TextColor3 = if dark then Theme.index.subtext else Theme.modal.subtext
	self._book.Visible = dark
	self._decor.Visible = not dark
end

function CatCollection.showTab(self: any, tab: Tab)
	if self._tab ~= tab then
		self:_closeDetail()
		self._book.CanvasPosition = Vector2.zero
		self._opened = false -- the Cats and Gold tabs each open on their first area still to find
	end
	self._tab = tab
	self:_paintTabs()
	if self._lastState then
		self._dirty = true
		self:render(self._lastState)
	end
end

-- The Cats tab with the area's cats at the top (an Index Board's prompt, F50).
function CatCollection.showArea(self: any, areaId: string)
	if self._tab ~= "Index" then
		self:_closeDetail()
	end
	self._tab = "Index"
	self._scrollTo = areaId
	self._opened = true -- so the first render does not pick another area over it
	self:_paintTabs()
	if self._lastState then
		self._dirty = true
		self:render(self._lastState)
	end
end

-- The reward strips price prizes that grow with the cafe from the day rate (the synced income drops after dark).
function CatCollection.setNight(self: any, night: boolean)
	self._night = night
	for _, section in self._sections do
		local strip = section.strip
		if strip then
			strip:setNight(night)
		end
	end
end

-- An area's header line: its name, count, bar and Rewards button, then a slot for its reward strip and its tiles.
function CatCollection._buildSection(
	self: any,
	id: string,
	name: string,
	order: number,
	grid: boolean
)
	local frame: Frame = Create("Frame", {
		Name = id,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = order,
		Parent = self._book,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		LayoutOrder = 1,
		Parent = frame,
	})
	local title = text({
		Name = "Area",
		Size = UDim2.fromOffset(NAME_W, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		TextColor3 = Theme.areaColors[id] or Theme.colors.caramel,
		Text = name,
		Parent = header,
	})
	Outline.text(title, 2.5)
	local count = text({
		Name = "Count",
		Position = UDim2.fromOffset(NAME_W + 8, 2),
		Size = UDim2.new(1, -(NAME_W + 8 + REWARDS.X + 12), 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.index.text,
		Parent = header,
	})
	Outline.text(count, 1.5)
	local hint = text({
		Name = "Hint",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(REWARDS.X + 12), 0, 6),
		Size = UDim2.fromOffset(220, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.index.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.index.track,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, -(REWARDS.X + 12), 0, BAR_H),
		Parent = header,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 2)
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.areaColors[id] or Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.shade(fill, 0.2)
	local section = {
		id = id,
		frame = frame,
		header = header,
		title = title,
		count = count,
		hint = hint,
		track = track,
		fill = fill,
		expanded = false,
		strip = nil :: any,
		slot = nil :: Frame?,
		grid = nil :: Frame?,
		rewards = nil :: any,
		dot = nil :: Frame?,
		dotCount = nil :: TextLabel?,
	}
	section.rewards = Button.new({
		name = "Rewards",
		text = "Rewards",
		style = "ghost",
		size = UDim2.fromOffset(REWARDS.X, REWARDS.Y),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, 0, 0.5, 0),
		textSize = Theme.sizes.textSmall + 1,
		parent = header,
		sound = "uiTab",
		onClick = function()
			self:_toggleRewards(section)
		end,
	})
	section.dot, section.dotCount = badge(section.rewards.instance, 20)
	section.slot = Create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Visible = false,
		Parent = frame,
	})
	if grid then
		section.grid = Create("Frame", {
			Name = "Cats",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 3,
			Parent = frame,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
				CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end
	self._sections[id] = section
	return section
end

-- Opens or shuts an area's reward strip; the strip is built the first time it opens.
function CatCollection._toggleRewards(self: any, section: any)
	section.expanded = not section.expanded
	if section.expanded and section.strip == nil then
		local strip = IndexStrip.new(section.slot, { claim = self._callbacks.claimIndexReward })
		local catalog: Types.Catalog? = self._catalog
		if catalog then
			strip:setCatalog(catalog)
		end
		strip:setNight(self._night)
		section.strip = strip
	end
	section.slot.Visible = section.expanded
	local state: Types.PlayerState? = self._lastState
	if state then
		self:render(state)
	end
end

function CatCollection._clear(self: any)
	self._loadToken += 1 -- the queued portraits are about to go
	for _, cell in self._cells do
		cell.connection:Disconnect()
		cell.portrait:destroy()
		cell.frame:Destroy()
	end
	table.clear(self._cells)
	for _, section in self._sections do
		if section.strip then
			section.strip:destroy()
		end
		section.rewards:destroy()
		section.frame:Destroy()
	end
	table.clear(self._sections)
	table.clear(self._catById)
end

function CatCollection._buildIndex(self: any)
	self:_clear()
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")

	-- every area the catalog or its cats name, in tier order; the All cats line first
	self:_buildSection(ALL_AREA, Format.areaName(ALL_AREA), 0, false)
	local empty: any = { tier = 0, catsOwned = {}, collection = {}, goldCollection = {} }
	local order = 0
	for _, area in IndexBook.sections(catalog, empty, "normal") do
		order += 1
		self:_buildSection(area.id, area.name, order, true)
	end

	for index, def in catalog.cats do
		self._catById[def.id] = def
		local areaId: string = def.area or IndexBook.FALLBACK_AREA
		local section = self._sections[areaId]
		if not section or not section.grid then
			continue
		end
		local rarity = def.rarity
		local tile: TextButton = Create("TextButton", {
			Name = def.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.rarityColor(rarity),
			BorderSizePixel = 0,
			LayoutOrder = (table.find(IndexBook.RARITIES, rarity) or 1) * 1000 + index,
			Parent = section.grid,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local border = Outline.border(tile, Theme.sizes.outline)
		Outline.shade(tile, 0.3)
		local portrait = CatPortrait.new({
			parent = tile,
			size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 4),
			still = true,
			zIndex = 2,
		})
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(4, PORTRAIT + 10),
			Size = UDim2.new(1, -8, 0, 22),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "???",
			ZIndex = 3,
			Parent = tile,
		})
		Create("UITextSizeConstraint", {
			MaxTextSize = Theme.sizes.textSmall + 1,
			MinTextSize = 9,
			Parent = name,
		})
		Outline.text(name, 2)
		local connection = tile.Activated:Connect(function()
			Sound.play("uiTab")
			self._selected = def.id
			self:_showDetail()
		end)
		self._cells[def.id] = {
			frame = tile,
			border = border,
			portrait = portrait,
			loaded = nil :: boolean?, -- the coat the portrait holds: false the base, true the gold, nil none yet
			name = name,
			def = def,
			connection = connection,
		}
	end
end

function CatCollection.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildIndex()
	self._decorIndex:setCatalog(catalog)
	-- the Decor tab shows once the catalog has crates to fill its pages
	self._decorTab.instance.Visible = #DecorPieces.pools(catalog) > 0
	self._dirty = true
end

-- One header line from a section's counts and the tab's rewards.
function CatCollection._paintHeader(
	self: any,
	section: any,
	have: number,
	total: number,
	countText: string,
	reward: IndexBook.Reward,
	locked: boolean,
	areaId: string,
	state: Types.PlayerState
)
	local gold = self._tab == "Gold"
	local fraction = if total > 0 then have / total else 0
	section.count.Text = countText
	section.count.TextColor3 = if total > 0 and have >= total
		then Theme.colors.gold
		elseif locked then Theme.index.subtext
		else Theme.index.text
	section.fill.Size = UDim2.fromScale(fraction, 1)
	section.fill.BackgroundColor3 = if gold or have >= total
		then Theme.colors.gold
		else Theme.areaColors[areaId] or Theme.colors.mint
	local rewards = section.rewards
	rewards.instance.Visible = reward.state ~= "none"
	if reward.state == "ready" then
		rewards:setText(if section.expanded then "Hide" else "Claim!")
		rewards:setStyle("primary")
		section.hint.Text = "Reward ready"
	elseif reward.state == "next" then
		rewards:setText(if section.expanded then "Hide" else "Rewards")
		rewards:setStyle("ghost")
		local word = if gold then "gold" else "cats"
		section.hint.Text = ("Next reward at %d %s · %d to go"):format(
			reward.need or 0,
			word,
			reward.toGo or 0
		)
	else
		rewards:setText(if section.expanded then "Hide" else "Rewards")
		rewards:setStyle("ghost")
		section.hint.Text = if reward.state == "done" then "Every reward claimed" else ""
	end
	section.hint.TextColor3 = if reward.state == "ready"
		then Theme.colors.mint
		else Theme.index.subtext
	local dot: Frame = section.dot
	dot.Visible = reward.ready > 1
	section.dotCount.Text = tostring(reward.ready)
	section.slot.Visible = section.expanded and reward.state ~= "none"
	if section.expanded and section.strip then
		section.strip:setTrack(trackOf(self._tab))
		section.strip:render(state, areaId)
	end
end

-- The Cats or Gold tab: each area's header and tiles. A tile's model is cloned the first time its tab shows it
-- (a few per frame, _loadPortraits), and again on later renders until Assets has it.
function CatCollection._renderBook(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog")
	local tab: Tab = self._tab
	local gold = tab == "Gold"
	local kind: IndexBook.Tab = if gold then "gold" else "normal"
	local track: IndexRewards.Track = trackOf(tab)
	local sections = IndexBook.sections(catalog, state, kind)
	local found = IndexBook.found(state, kind)

	local shown: { [string]: boolean } = {}
	for _, area in sections do
		local section = self._sections[area.id]
		if not section then
			continue
		end
		shown[area.id] = true
		local views = IndexRewards.views(catalog, state, area.id)
		self:_paintHeader(
			section,
			area.have,
			area.total,
			IndexBook.count(area),
			IndexBook.reward(views, track),
			area.locked,
			area.id,
			state
		)
		section.title.Text = area.name
	end
	-- the All cats line: the All Cats track, on the Cats tab only
	local all = self._sections[ALL_AREA]
	if all and not gold then
		local counts = IndexRewards.counts(catalog, state, ALL_AREA)
		local views = IndexRewards.views(catalog, state, ALL_AREA)
		local have, total = counts.found, counts.total
		self:_paintHeader(
			all,
			have,
			total,
			if total > 0 and have >= total then "Complete!" else ("%d / %d"):format(have, total),
			IndexBook.reward(views, "normal"),
			false,
			ALL_AREA,
			state
		)
		shown[ALL_AREA] = true
	end
	for id, section in self._sections do
		section.frame.Visible = shown[id] == true
	end

	local toLoad = {}
	for catId, cell in self._cells do
		local def: Types.CatDef = cell.def
		if cell.loaded ~= gold then
			table.insert(toLoad, cell)
		end
		local isFound = found[catId] == true
		local color = Theme.rarityColor(def.rarity)
		cell.frame.BackgroundColor3 = if isFound
			then color
			else color:Lerp(Color3.new(0, 0, 0), Theme.index.dim)
		cell.portrait:setSilhouette(not isFound)
		cell.name.Text = if isFound then def.name else def.rarity
		cell.border.Color = if gold and isFound then Theme.colors.gold else Theme.colors.outline
		cell.border.Thickness = Theme.sizes.outline + (if gold and isFound then 1 else 0)
	end
	self:_loadPortraits(toLoad, gold)

	-- the first render picks the area to open on; an Index Board's prompt asked for one
	if not self._opened then
		self._opened = true
		self._scrollTo = IndexBook.first(sections)
	end
	local target: string? = self._scrollTo
	if target then
		self._scrollTo = nil
		self:_scrollToSection(target)
	end
end

-- Brings an area's header to the top of the scroll once the layout has placed it (the first area stays at 0, so
-- the All cats line shows above it).
function CatCollection._scrollToSection(self: any, areaId: string)
	local section = self._sections[areaId]
	if not section then
		return
	end
	local first = true
	for _, each in self._sections do
		if
			each.frame.Visible
			and each.frame.LayoutOrder < section.frame.LayoutOrder
			and each.id ~= ALL_AREA
		then
			first = false
			break
		end
	end
	if first then
		self._book.CanvasPosition = Vector2.zero
		return
	end
	-- two frames: the window's pop in and the grids' automatic sizes settle first
	task.spawn(function()
		task.wait()
		task.wait()
		local book: ScrollingFrame = self._book
		if not section.frame.Parent or not section.frame.Visible then
			return
		end
		local scale = scaleOf(book)
		local offset = (section.frame.AbsolutePosition.Y - book.AbsolutePosition.Y) / scale
		local most = math.max(0, (book.AbsoluteCanvasSize.Y - book.AbsoluteWindowSize.Y) / scale)
		book.CanvasPosition = Vector2.new(0, math.clamp(book.CanvasPosition.Y + offset, 0, most))
	end)
end

-- Clones the page's missing cat models (gold coats on the Gold tab) in grid order, PORTRAITS_PER_FRAME now and as
-- many each frame after, so a tab does not clone 50 models in one frame. A newer render or tab takes over.
function CatCollection._loadPortraits(self: any, cells: { any }, gold: boolean)
	table.sort(cells, function(a: any, b: any): boolean
		local pa, pb = a.frame.Parent, b.frame.Parent
		if pa ~= pb and pa and pb then
			return (pa.Parent :: any).LayoutOrder < (pb.Parent :: any).LayoutOrder
		end
		return a.frame.LayoutOrder < b.frame.LayoutOrder
	end)
	self._loadToken += 1
	local token = self._loadToken
	local function load(first: number)
		for index = first, math.min(first + PORTRAITS_PER_FRAME - 1, #cells) do
			local cell = cells[index]
			if cell.loaded ~= gold and cell.frame.Visible then
				cell.portrait:set(cell.def, gold)
				cell.loaded = if cell.portrait:hasModel() then gold else nil
			end
		end
	end
	load(1)
	if #cells <= PORTRAITS_PER_FRAME then
		return
	end
	task.spawn(function()
		for first = PORTRAITS_PER_FRAME + 1, #cells, PORTRAITS_PER_FRAME do
			task.wait()
			if self._loadToken ~= token then
				return
			end
			load(first)
		end
	end)
end

-- The detail card for the selected cat, on the tab it was tapped on.
function CatCollection._showDetail(self: any)
	local catId: string? = self._selected
	local def: Types.CatDef? = if catId then self._catById[catId] else nil
	local state: Types.PlayerState? = self._lastState
	if not def or not state then
		return
	end
	assert(def and state, "detail")
	local gold = self._tab == "Gold"
	local found = IndexBook.found(state, if gold then "gold" else "normal")[def.id] == true
	if self._detailId ~= def.id or self._detailGold ~= gold then
		self._detailId = def.id
		self._detailGold = gold
		self._detailArt:set(def, gold)
	end
	self._detailArt:setSilhouette(not found)
	local color = Theme.rarityColor(def.rarity)
	self._detailStroke.Color = color
	self._detailDisc.BackgroundColor3 = color
	local name = if found then def.name else "Not found yet"
	self._detailName.Text = if gold and found then "Gold " .. name else name
	self._detailPill.Text = def.rarity
	self._detailPill.BackgroundColor3 = color
	self._detailPill.TextColor3 = Theme.rarityTextColor(def.rarity)
	local meta = {}
	table.insert(meta, Format.rate(def.incomePerSecond))
	if def.favoriteRole then
		table.insert(meta, Format.lovesRole(def.favoriteRole, Theme.modal.text))
	end
	table.insert(meta, "lives in the " .. Format.areaName(def.area or IndexBook.FALLBACK_AREA))
	self._detailMeta.Text = table.concat(meta, "  ·  ")
	self._detailDesc.Text = if found then (def.description or "") else ""
	if not self._cover.Visible then
		self._cover.Visible = true
		Tween.popIn(self._cover:FindFirstChild("Card") :: GuiObject, 0.9)
	end
end

function CatCollection.render(self: any, state: Types.PlayerState)
	self._lastState = state
	if not self.frame.Visible then
		self._dirty = true
		return
	end
	self._dirty = false
	local catalog: Types.Catalog? = self._catalog
	local gold = self._tab == "Gold"
	-- the title's "12 / 50" leaves the spare cats out (F78); the Gold tab counts gold cats
	local foundCount, total = 0, 0
	if catalog then
		if gold then
			for _, section in IndexBook.sections(catalog, state, "gold") do
				foundCount += section.have
				total += section.total
			end
		else
			foundCount, total = IndexRewards.book(catalog, state)
		end
	end
	self._panel:setTitle(
		"Index",
		("%d / %d %s  ·  %s"):format(
			foundCount,
			total,
			if gold then "gold" else "found",
			Format.percent(if total > 0 then foundCount / total else 0)
		)
	)

	-- each tab's badge counts the rewards waiting on its pages, whichever tab is open
	local waiting, goldWaiting, decorWaiting = 0, 0, 0
	if catalog then
		local ready = IndexRewards.claimable(catalog, state)
		for areaId, count in ready do
			if DecorPieces.poolOf(areaId) then
				decorWaiting += count
			elseif count > 0 then
				local views = IndexRewards.views(catalog, state, areaId)
				waiting += IndexBook.reward(views, "normal").ready
				goldWaiting += IndexBook.reward(views, "gold").ready
			end
		end
	end
	local function setBadge(dot: Frame, label: TextLabel, count: number)
		if count > 0 and not dot.Visible then
			Tween.popIn(dot, 0.5)
		end
		dot.Visible = count > 0
		label.Text = tostring(count)
	end
	setBadge(self._indexBadge, self._indexBadgeCount, waiting)
	setBadge(self._goldBadge, self._goldBadgeCount, goldWaiting)
	setBadge(self._decorBadge, self._decorBadgeCount, decorWaiting)
	self:_renderPerks(state)

	if self._tab == "Decor" then
		self._decorIndex:render(state)
	else
		self:_renderBook(state)
		if self._selected and self._cover.Visible then
			self:_showDetail()
		end
	end
end

-- The forever bonuses beside the tabs, on every tab, once the player has any.
function CatCollection._renderPerks(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	local any = false
	if catalog then
		local totals = IndexRewards.totals(catalog, state)
		for _, perk in IndexRewards.PERKS do
			local label = IndexRewards.perkLabel(perk, (totals :: any)[perk] or 0)
			local pillLabel: TextLabel = self._perkPills[perk]
			pillLabel.Visible = label ~= nil
			pillLabel.Text = label or ""
			any = any or label ~= nil
		end
	end
	self._perks.Visible = any
end

function CatCollection.destroy(self: any)
	self:_clear()
	self._detailArt:destroy()
	self._detailClose:destroy()
	self._decorIndex:destroy()
	self._indexTab:destroy()
	self._goldTab:destroy()
	self._decorTab:destroy()
	self._panel:destroy()
end

return CatCollection
