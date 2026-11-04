--!strict
-- The Index window (the Cats screen is its own window since 2026-10-27, Screens/MyCats). Its tabs:
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
--   Rainbow (F99, rainbow-coat.md sections 2 to 4): the same scroll counting rainbow cats, after Gold. A found
--         rainbow cat's tile has a slowly turning rainbow border and its name in rainbow letters (Components/Rainbow);
--         the rest stay silhouettes. It starts with a Rainbow cats line, the one Rainbow track for the whole Index
--         (rainbow1 to rainbow25), whose prizes add rainbow luck. The tab shows once the catalog has the track.
--   Decor: the Decor Index (F53, Screens/DecorIndex): a page per crate with its twelve pieces and two rewards.
--   In the title bar, the forever bonuses the claimed rewards add up to (F54 v0.10): tips, gold luck with the gold
--   chance it gives, rainbow luck with the rainbow chance (F99, on the bands) and faster bait, each in its track's
--   colour (Components/IndexRewards.totals). They sat beside the tabs until the Rainbow tab filled that row. Right of the tabs,
--   "Claim all (5)" while any reward waits on any page (from one since Derek 2026-11-03 never saw it) (Derek 2026-10-28: "more claim all buttons needed so
--   many reward pop ups"): one ClaimAll("index"), one toast; shown once shared Config.IndexClaimAll is true.
-- The Index opens on the first open area with cats still to find; an Index Board's prompt opens it on that area.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local Rainbow = require(script.Parent.Parent.Components.Rainbow)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	claimIndexReward: (areaId: string, milestoneId: string) -> (),
	claimAll: (() -> ())?, -- every waiting reward on every page, cats and Decor
	close: () -> (),
}

-- "Index" is the Cats tab (the name init and the Index Boards already use). The Top tab (F98 leaderboards) went on
-- 2026-11-03 (Derek: "no need to put "top" inside index"); the town's boards still show them.
export type Tab = "Index" | "Gold" | "Rainbow" | "Decor"

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
local CLAIM_ALL_W = 150
local CLAIM_ALL_HOLD = 3 -- seconds Claim all reads "Claiming" unless the sync clears the rewards first
local TAB_HEIGHT = 40
local HEADER_HEIGHT = 52
local REWARDS = Vector2.new(124, 40) -- an area's Rewards button
local NAME_W = 220
local HINT_W = 260 -- "Next reward at 10 rainbow · 5 to go"
local BAR_H = 10
local PERK_HEIGHT = 26 -- a forever bonus pill in the title bar
local PERKS_RIGHT = 64 -- the title bar's room for the X, right of the pills
local DETAIL = Vector2.new(470, 216)
local DETAIL_ART = 176
local ALL_AREA = IndexRewards.ALL_AREA
local RAINBOW_AREA = IndexRewards.RAINBOW_AREA -- the Rainbow cats line (F99)
local RAINBOW_NAME = "Rainbow cats"
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
	elseif tab == "Rainbow" then
		return "rainbow"
	end
	return "normal"
end

-- The IndexBook tab a window tab lists.
local function kindOf(tab: Tab): IndexBook.Tab
	if tab == "Gold" then
		return "gold"
	elseif tab == "Rainbow" then
		return "rainbow"
	end
	return "normal"
end

-- A tile's rainbow border and rainbow letters on its name (F99), made the first time the tile shows a found rainbow
-- cat and switched off on the other tabs, so the bands' loop turns only what shows.
local function paintBands(cell: any, on: boolean)
	if on and cell.bands == nil then
		cell.bands = { Rainbow.stroke(cell.border), Rainbow.text(cell.name) }
	end
	local bands: { UIGradient }? = cell.bands
	if bands then
		for _, gradient in bands do
			gradient.Enabled = on
		end
	end
	if on then
		cell.border.Color = Theme.colors.white -- the bands tint it
	end
	cell.name.TextColor3 = Theme.colors.white
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
	self._detailBands = nil :: UIGradient? -- the rainbow edge, made the first time a rainbow cat shows (F99)
	-- an area's Rewards button: a 36 px face on a mouse, a finger's on a phone
	self._rewardsH = Scale.tapHeight(REWARDS.Y + 1, Theme.sizes.buttonDepth)
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

	-- tabs: Cats, Gold, Rainbow, Decor, then Claim all; tall enough for a finger on a phone and a 36 px face on
	-- a mouse
	local tabH = Scale.tapHeight(TAB_HEIGHT + 1, Theme.sizes.buttonDepth)
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tabH),
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
			size = UDim2.fromOffset(TAB_W, tabH),
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
	self._rainbowTab, self._rainbowBadge, self._rainbowBadgeCount =
		tabButton("RainbowTab", "Rainbow", "🌈", 3, "Rainbow")
	self._rainbowTab.instance.Visible = false -- until the catalog has the Rainbow track
	self._decorTab, self._decorBadge, self._decorBadgeCount =
		tabButton("DecorTab", "Decor", Theme.icons.decor, 5, "Decor")
	self._decorTab.instance.Visible = false
	self._claimAllAt = -math.huge -- os.clock() of the last Claim all press
	self._claimAll = Button.new({
		name = "ClaimAll",
		text = "Claim all",
		style = "primary",
		size = UDim2.fromOffset(CLAIM_ALL_W, tabH),
		textSize = Theme.sizes.textBody,
		layoutOrder = 6,
		parent = tabs,
		onClick = function()
			self:_pressClaimAll()
		end,
	})
	self._claimAll.instance.Visible = false

	-- the forever bonuses, in the title bar right of the title and left of the X (F99: five tabs and Claim all fill
	-- the tab row); shrinks to fit the room the title leaves on a narrow screen
	local header = panel.body:FindFirstChild("Header") :: Frame
	local perks: Frame = Create("Frame", {
		Name = "Forever",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -PERKS_RIGHT, 0.5, -1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, PERK_HEIGHT + 4),
		Visible = false,
		ZIndex = 3,
		Parent = header,
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
		TextColor3 = Theme.modal.headerText,
		TextTruncate = Enum.TextTruncate.None,
		Text = "Forever",
		Parent = perks,
	})
	Outline.text(self._perksCaption, 1.5)
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
		PrizeChips.paintPerk(label, perk) -- rainbow luck on the turning bands
		self._perkPills[perk] = label
	end
	local titleLabel = header:FindFirstChild("Title") :: TextLabel
	local subtitleLabel = header:FindFirstChild("Subtitle") :: TextLabel
	local function fitPerks()
		-- AbsoluteContentSize already includes the UIScale, so divide it back out for the row's own width; the room
		-- is the bar's width past the title's or the count's words, whichever is longer, and the X's corner
		local natural = perksLayout.AbsoluteContentSize.X / math.max(perksScale.Scale, 0.01)
		local words = math.max(titleLabel.TextBounds.X, subtitleLabel.TextBounds.X)
		local left = titleLabel.AbsolutePosition.X - header.AbsolutePosition.X + words
		local room = header.AbsoluteSize.X
			- left
			- PERKS_RIGHT * scaleOf(header)
			- Theme.sizes.gap * 2
		perksScale.Scale = if room > 0 and natural > room then room / natural else 1
	end
	perksLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitPerks)
	header:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPerks)
	subtitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(fitPerks)

	-- Cats, Gold and Rainbow: one scroll of areas
	local indexTop = tabH + Theme.sizes.gap
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
	-- a finger wide and tall on a phone, as the window's own X
	local closeTall = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	local closeWide = math.max(Theme.sizes.touchMin, closeTall - Theme.sizes.buttonDepth)
	self._detailClose = Button.new({
		name = "Close",
		text = "X",
		style = "close",
		size = UDim2.fromOffset(closeWide, closeTall),
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

-- The tabs' looks; the page behind them is dark on every tab (#1028).
function CatCollection._paintTabs(self: any)
	local tab: Tab = self._tab
	self._indexTab:setStyle(if tab == "Index" then "gold" else "ghost")
	self._goldTab:setStyle(if tab == "Gold" then "gold" else "ghost")
	self._rainbowTab:setStyle(if tab == "Rainbow" then "gold" else "ghost")
	self._decorTab:setStyle(if tab == "Decor" then "gold" else "ghost")
	-- every tab on the dark page since #1028 (the Decor Index draws from Theme.dark too)
	self._panel.body.BackgroundColor3 = Theme.index.body
	self._book.Visible = tab == "Index" or tab == "Gold" or tab == "Rainbow"
	self._decor.Visible = tab == "Decor"
end

function CatCollection.showTab(self: any, tab: Tab)
	if self._tab ~= tab then
		self:_closeDetail()
		self._book.CanvasPosition = Vector2.zero
		self._opened = false -- the Cats, Gold and Rainbow tabs each open on their first area still to find
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
		-- tall enough for the Rewards button's finger height on a phone
		Size = UDim2.new(1, 0, 0, math.max(HEADER_HEIGHT, self._rewardsH + 4)),
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
		Size = UDim2.fromOffset(HINT_W, 20),
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
		size = UDim2.fromOffset(REWARDS.X, self._rewardsH),
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

	-- every area the catalog or its cats name, in tier order; the All cats line first (the Rainbow cats line takes
	-- its place on the Rainbow tab)
	self:_buildSection(ALL_AREA, Format.areaName(ALL_AREA), 0, false)
	local rainbowLine = self:_buildSection(RAINBOW_AREA, RAINBOW_NAME, 0, false)
	Rainbow.text(rainbowLine.title)
	Rainbow.fill(rainbowLine.fill)
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
			bands = nil :: { UIGradient }?, -- the rainbow border and name, made the first time it shows as rainbow
		}
	end
end

function CatCollection.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildIndex()
	self._decorIndex:setCatalog(catalog)
	-- the Decor tab shows once the catalog has crates to fill its pages, the Rainbow tab once it has the track
	self._decorTab.instance.Visible = #DecorPieces.pools(catalog) > 0
	local prizes = catalog.indexPrizes
	self._rainbowTab.instance.Visible = prizes ~= nil and prizes[RAINBOW_AREA] ~= nil
	if self._tab == "Rainbow" and not self._rainbowTab.instance.Visible then
		self._tab = "Index"
		self:_paintTabs()
	end
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
	local rainbow = self._tab == "Rainbow"
	local fraction = if total > 0 then have / total else 0
	section.count.Text = countText
	section.count.TextColor3 = if total > 0 and have >= total
		then Theme.colors.gold
		elseif locked then Theme.index.subtext
		else Theme.index.text
	section.fill.Size = UDim2.fromScale(fraction, 1)
	section.fill.BackgroundColor3 = if areaId == RAINBOW_AREA
		then Theme.colors.white -- under its rainbow bands
		elseif gold or have >= total then Theme.colors.gold
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
		local word = if gold then "gold" elseif rainbow then "rainbow" else "cats"
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

-- The Cats, Gold or Rainbow tab: each area's header and tiles. A tile's model is cloned the first time its tab shows
-- it (a few per frame, _loadPortraits), and again on later renders until Assets has it. Rainbow tiles keep the base
-- coat, as every rainbow portrait does; their border and name carry the bands.
function CatCollection._renderBook(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog")
	local tab: Tab = self._tab
	local gold = tab == "Gold"
	local rainbow = tab == "Rainbow"
	local kind: IndexBook.Tab = kindOf(tab)
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
		if area.exclusive then
			section.hint.Text = IndexBook.EXCLUSIVE_NOTE -- F96: it counts toward nothing and has no rewards
		end
	end
	-- the line over the areas: the All Cats track on the Cats tab, the Rainbow track on the Rainbow tab, none on Gold
	local lineId: string? = if tab == "Index" then ALL_AREA elseif rainbow then RAINBOW_AREA else nil
	local line = if lineId then self._sections[lineId] else nil
	if line and lineId then
		local counts = IndexRewards.counts(catalog, state, lineId)
		local views = IndexRewards.views(catalog, state, lineId)
		local have, total = if rainbow then counts.rainbow else counts.found, counts.total
		self:_paintHeader(
			line,
			have,
			total,
			if total > 0 and have >= total then "Complete!" else ("%d / %d"):format(have, total),
			IndexBook.reward(views, track),
			false,
			lineId,
			state
		)
		shown[lineId] = true
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
		-- an uncaught cat keeps its dark silhouette but says its name, so players know what to look for (#1077)
		cell.name.Text = def.name
		cell.name.TextTransparency = if isFound then 0 else 0.25
		local bright = (gold or rainbow) and isFound
		cell.border.Color = if gold and isFound then Theme.colors.gold else Theme.colors.outline
		cell.border.Thickness = Theme.sizes.outline + (if bright then 1 else 0)
		paintBands(cell, rainbow and isFound)
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
-- the All cats or Rainbow cats line shows above it).
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
			and each.id ~= RAINBOW_AREA
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
	local found = IndexBook.found(state, kindOf(self._tab))[def.id] == true
	local rainbow = self._tab == "Rainbow" and found
	if self._detailId ~= def.id or self._detailGold ~= gold then
		self._detailId = def.id
		self._detailGold = gold
		self._detailArt:set(def, gold)
	end
	self._detailArt:setSilhouette(not found)
	local color = Theme.rarityColor(def.rarity)
	if rainbow and self._detailBands == nil then
		self._detailBands = Rainbow.stroke(self._detailStroke) -- F99: the rainbow card's turning edge
	end
	local bands: UIGradient? = self._detailBands
	if bands then
		bands.Enabled = rainbow
	end
	self._detailStroke.Color = if rainbow then Theme.colors.white else color
	self._detailDisc.BackgroundColor3 = color
	-- the name shows whether or not the cat is found (#1077); "Not found yet" moves to the line under it
	local name = def.name
	self._detailName.Text = if gold and found
		then "Gold " .. name
		elseif rainbow then "Rainbow " .. name
		else name
	self._detailPill.Text = def.rarity
	self._detailPill.BackgroundColor3 = color
	self._detailPill.TextColor3 = Theme.rarityTextColor(def.rarity)
	local meta = {}
	if not found then
		table.insert(meta, "Not found yet")
	end
	table.insert(meta, Format.rate(def.incomePerSecond))
	if def.favoriteRole then
		table.insert(meta, Format.lovesRole(def.favoriteRole, Theme.modal.text))
	end
	if def.exclusive == true then
		-- F95 and F96: never caught, so it lives nowhere
		table.insert(
			meta,
			if def.source == "free" then "free at its stand in town" else "from the shop"
		)
	else
		table.insert(meta, "lives in the " .. Format.areaName(def.area or IndexBook.FALLBACK_AREA))
	end
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
	local kind: IndexBook.Tab = kindOf(self._tab)
	-- the title's "12 / 50" leaves the spare cats out (F78); the Gold and Rainbow tabs count their coats
	local foundCount, total = 0, 0
	if catalog then
		if kind ~= "normal" then
			for _, section in IndexBook.sections(catalog, state, kind) do
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
			if kind == "normal" then "found" else kind,
			Format.percent(if total > 0 then foundCount / total else 0)
		)
	)

	-- each tab's badge counts the rewards waiting on its pages, whichever tab is open
	local waiting, goldWaiting, rainbowWaiting, decorWaiting = 0, 0, 0, 0
	local waitingAll = 0
	if catalog then
		local ready, all = IndexRewards.claimable(catalog, state)
		waitingAll = all
		for areaId, count in ready do
			if DecorPieces.poolOf(areaId) then
				decorWaiting += count
			elseif count > 0 then
				local views = IndexRewards.views(catalog, state, areaId)
				waiting += IndexBook.reward(views, "normal").ready
				goldWaiting += IndexBook.reward(views, "gold").ready
				rainbowWaiting += IndexBook.reward(views, "rainbow").ready
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
	setBadge(self._rainbowBadge, self._rainbowBadgeCount, rainbowWaiting)
	setBadge(self._decorBadge, self._decorBadgeCount, decorWaiting)
	self._waitingAll = waitingAll
	self:_syncClaimAll()
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

-- Claim all shows while any reward waits and the server has ClaimAll; a press reads "Claiming" until the sync.
function CatCollection._syncClaimAll(self: any)
	local count: number = self._waitingAll or 0
	local can = (Config :: any).IndexClaimAll == true and self._callbacks.claimAll ~= nil
	local pending = os.clock() - self._claimAllAt < CLAIM_ALL_HOLD
	self._claimAll.instance.Visible = can and count >= 1
	self._claimAll:setEnabled(not pending)
	self._claimAll:setText(if pending then "Claiming" else ("Claim all (%d)"):format(count))
end

function CatCollection._pressClaimAll(self: any)
	local callbacks: Callbacks = self._callbacks
	local claimAll = callbacks.claimAll
	if claimAll == nil or os.clock() - self._claimAllAt < CLAIM_ALL_HOLD then
		return
	end
	self._claimAllAt = os.clock()
	claimAll()
	self:_syncClaimAll()
	task.delay(CLAIM_ALL_HOLD, function()
		if self._claimAll.instance.Parent ~= nil then
			self:_syncClaimAll()
		end
	end)
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
	self._claimAll:destroy()
	self._detailArt:destroy()
	self._detailClose:destroy()
	self._decorIndex:destroy()
	self._indexTab:destroy()
	self._goldTab:destroy()
	self._rainbowTab:destroy()
	self._decorTab:destroy()
	self._panel:destroy()
end

return CatCollection
