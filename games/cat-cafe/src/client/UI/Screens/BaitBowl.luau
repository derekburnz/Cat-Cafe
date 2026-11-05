--!strict
-- Bait bowl screen (F28, data-model section 8): what is in your bowl and every food you can put in it. A food
-- goes in with Use from anywhere, F included (Derek 2026-10-28); the cat it brings is rolled then and arrives after
-- the wait, even while you are offline, and you choose Tame or Let go when it comes. Since #1612 (Derek2 11-05: "no
-- need to show odds of everything everywhere") each food is one compact row: its picture, name, grade and "You have
-- 3", with Use and Details; Details opens the five-rarity odds in their colours, the gold chance (no charm stars
-- since F97) and the per-cat split (the growth thread's rules for random items). #1281 (corner-shop-v2.md section 1b): no Buy here; the
-- shop foods are sold at the Corner Shop, so each row says "You have 3" and Use, or a calm "Get more at the Corner
-- Shop" with none left. F69: each food's picture wears its grade badge, its card a border
-- in the grade's colour, and the grade by its name (the "Attracts" chip went in #1612); the bowl shows the food in it. F54: the gold
-- chance has the Index's gold luck in it, and the wait the Big Bowl perk and the Index's faster bait; F73 adds a
-- running Gold Rush, Lucky or Quick Bait Potion's, as the server rolls food set now. F60: food set
-- at night waits half, so by night the empty bowl's wait is the night one and a night bowl counts down behind a moon.
-- F82: the odds row, the split and the wait are the bowl level's (shared Bait, as the server rolls), and the title
-- names the bowl you have, "Comfy Bowl" up to "Royal Bowl". The foods run in rarity order, rarest first since #1609
-- (Components/FoodOrder).
-- Opened by the bowl's prompt (UI.bait.openPicker), the HUD bowl chip or F.
-- #1161 (the Second Bait Bowl pass, Derek 2026-11-04: "make sure the bowl menu works perfectly with two bowls"): with a
-- second bowl a row of two bowl tabs sits over the status card, each with its own state ("Empty", the countdown or
-- "Cat!"), and the status card, Use and "See the cat" are the chosen bowl's, so nothing is shared by accident. Without
-- the pass ("offer") bowl 2's tab is locked: choosing it shows a calm "Get a second bowl" card with the pass's price
-- from Roblox and every food's odds in that bowl (shared Bait.oddsCard, the same as bowl 1's). The screen never opens
-- on the locked tab, so the offer only shows when the player taps it. One bowl only (nil): no tabs, as before.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local FoodGrade = require(script.Parent.Parent.Components.FoodGrade)
local FoodOdds = require(script.Parent.Parent.Components.FoodOdds)
local FoodOrder = require(script.Parent.Parent.Components.FoodOrder)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

local Bait = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bait"))

export type Callbacks = {
	useLure: (lureId: string, bowl: number) -> (), -- #1161: into bowl 1 or 2
	openUpgrades: () -> (),
	showCat: (bowl: number) -> (), -- reopens that bowl's Tame or Let go card
	buySecond: () -> (), -- #1161: Roblox's purchase window for the Second Bait Bowl pass
	close: () -> (),
}

-- What Roblox said about the Second Bait Bowl pass (as Components/StoreLogic.Price), nil until it answers.
export type PassPrice = { robux: number?, forSale: boolean }

export type BaitBowl = {
	frame: Frame,
	setCatalog: (self: BaitBowl, catalog: Types.Catalog) -> (),
	render: (self: BaitBowl, state: Types.PlayerState) -> (),
	-- `bowl` is 1 or 2 (#1161); nil is 1
	setBait: (self: BaitBowl, bait: Types.BaitView?, catWaiting: boolean, bowl: number?) -> (),
	-- #1161: "on" (the pass: bowl 2 takes food), "offer" (bowl 2 locked, with the pass card) or nil (one bowl)
	setSecond: (self: BaitBowl, kind: string?, price: PassPrice?) -> (),
	select: (self: BaitBowl, bowl: number) -> (), -- shows that bowl's tab
	selected: (self: BaitBowl) -> number,
	openOn: (self: BaitBowl) -> (), -- on open: a bowl with a cat waiting, else an empty one that takes food, else 1
	setNight: (self: BaitBowl, night: boolean) -> (),
	destroy: (self: BaitBowl) -> (),
}

local STATUS_HEIGHT = 92
-- #1612 (Derek2 11-05: "just have it in a smaller line/image have the symbol the name the rarity of the food (remove
-- what it attracts) remove odds and just put that under details"): a compact row, Use and Details side by side
local BUTTON = Vector2.new(112, Theme.sizes.touchMin)
local DETAILS_W = 100
local DETAILS_H = 42 -- a 37 px face, over the 36 px a mouse needs (the UI gate's tap check)
local ICON = 52 -- the food's picture with its grade gem
local TEXT_LEFT = ICON + 24
local TEXT_WIDTH = -(TEXT_LEFT + BUTTON.X + DETAILS_W + 8 + 24)
local TAB_H = 42 -- the bowl tabs (#1161), as tall as Details
local ODDS_LINE = 22
local TITLE = "Bait bowl"
local SUBTITLE = "Put food in and a cat comes to your door"

local BaitBowl = {}
BaitBowl.__index = BaitBowl

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- a rarity's odds colour as hex, for FoodOdds.rich
local function rarityHex(rarity: string): string
	return Theme.rarityLight(rarity):ToHex() -- light odds on the dark cards (#1028)
end

-- Text that goes into a RichText label as it reads (the Details text sits under the coloured odds).
local function plain(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function BaitBowl.new(callbacks: Callbacks): BaitBowl
	local self = setmetatable({}, BaitBowl) :: any
	self._callbacks = callbacks
	self._rows = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._baits = {} :: { [number]: Types.BaitView? } -- #1161: bowl 1's and bowl 2's
	self._waiting = { false, false } -- whether each bowl's Tame or Let go card has a cat
	self._second = nil :: string? -- "on", "offer" or nil
	self._price = nil :: PassPrice?
	self._selected = 1
	self._tabsShown = false
	self._oddsLevel = -1 -- the bowl level the locked bowl's odds card was written for
	self._tier = 0
	self._extras = "" -- the gold and charm line the Details were written with
	self._waitSeconds = FoodOdds.waitSeconds(0, false, 0)
	self._bowlLevel = 0 -- lure_bowl (F82): the odds and wait are this level's
	self._luck = 1 -- F88: the player's Luck, in the odds rows and the split
	self._bigBowl = false
	self._speed = 0 -- the Index's faster bait (F54) plus a running Quick Bait Potion's (F73)
	self._night = false -- the clock's phase (F60: food set at night waits half)
	self._accumulator = 0

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Bait",
		color = Theme.colors.mintDark,
		icon = Theme.upgradeIcons.lure_bowl,
		title = TITLE,
		subtitle = SUBTITLE,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- #1161: the two bowl tabs, shown with a second bowl (_layout)
	local tabH = Scale.tapHeight(TAB_H, Theme.sizes.buttonDepth)
	self._tabH = tabH
	local tabs: Frame = Create("Frame", {
		Name = "Bowls",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, tabH),
		Visible = false,
		Parent = panel.content,
	})
	self._tabs = tabs
	self._tabButtons = {} :: { any }
	for bowl = 1, 2 do
		self._tabButtons[bowl] = Button.new({
			name = "Bowl" .. bowl,
			text = "Bowl " .. bowl,
			style = "ghost",
			size = UDim2.new(0.5, -4, 0, tabH),
			position = UDim2.new((bowl - 1) * 0.5, if bowl == 2 then 4 else 0, 0, 0),
			textSize = Theme.sizes.textSmall,
			parent = tabs,
			onClick = function()
				self:select(bowl)
			end,
		})
	end

	-- Status card: the bowl, what is in it and the countdown
	local status: Frame = Create("Frame", {
		Name = "Status",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, STATUS_HEIGHT),
		Parent = panel.content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._status = status
	self._statusBorder = Outline.border(status, Theme.sizes.outline)
	local bowlTile: TextLabel = text({
		Name = "Bowl",
		BackgroundColor3 = Theme.colors.caramel,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 34,
		Text = Theme.icons.food,
		Parent = status,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bowlTile })
	Outline.border(bowlTile, 2)
	self._bowlTile = bowlTile
	-- F69: the food in the bowl, with its grade badge, in place of the bowl while it waits
	self._bowlFood = ItemIcon.new({
		parent = status,
		size = UDim2.fromOffset(64, 64),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 12, 0.5, -4),
		name = "Food",
	})
	self._bowlFood.frame.Visible = false
	self._bowlLure = nil :: string?
	self._statusTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(90, 12),
		Size = UDim2.new(1, -250, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.colors.white,
		Parent = status,
	})
	Outline.text(self._statusTitle, 2)
	self._statusSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(90, 40),
		Size = UDim2.new(1, -250, 0, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = status,
	})
	-- countdown bar along the bottom of the status card while a cat is on its way
	self._track = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.cocoa,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 90, 1, -10),
		Size = UDim2.new(1, -250, 0, 8),
		Visible = false,
		Parent = status,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = self._track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._action = Button.new({
		name = "Action",
		text = "",
		style = "gold",
		size = UDim2.fromOffset(140, Theme.sizes.touchMin + 4),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = status,
		onClick = function()
			self:_pressAction()
		end,
	})
	self._actionKind = nil :: string?
	self._actionStyle = "gold"
	-- #1573: the food each bowl last held this session, for Refill once it is empty again
	self._lastLure = {} :: { [number]: string? }

	self._list = Create("ScrollingFrame", {
		Name = "Foods",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, STATUS_HEIGHT + Theme.sizes.gap + 4),
		Size = UDim2.new(1, 0, 1, -(STATUS_HEIGHT + Theme.sizes.gap + 4)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }),
	})

	-- #1161: the locked bowl 2's odds, every food's in a bowl of the player's level (shared Bait.oddsCard)
	local oddsCard: Frame = Create("Frame", {
		Name = "SecondOdds",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 0,
		Visible = false,
		Parent = self._list,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.caramel, Thickness = Theme.sizes.stroke }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	text({
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		Text = "Bowl 2's odds",
		LayoutOrder = 0,
		Parent = oddsCard,
	})
	self._oddsNote = text({
		Name = "Note",
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = "",
		LayoutOrder = 1,
		Parent = oddsCard,
	})
	self._oddsCard = oddsCard
	self._oddsLines = {} :: { TextLabel }

	-- the countdown ticks once a second while the screen is open
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		if not self.frame.Visible or (self._baits[1] == nil and self._baits[2] == nil) then
			return
		end
		self._accumulator += dt
		if self._accumulator >= 1 then
			self._accumulator = 0
			self:_renderStatus()
		end
	end)
	self:_layout()
	return self :: BaitBowl
end

-- #1161: the tabs over the status card while there are two bowls, and the card and list below them.
function BaitBowl._layout(self: any)
	local state: Types.PlayerState? = self._state
	local shown = state ~= nil
		and (state.upgradeLevels.lure_bowl or 0) >= 1
		and (self._second ~= nil or self._baits[2] ~= nil)
	self._tabsShown = shown
	self._tabs.Visible = shown
	if not shown then
		self._selected = 1
	end
	local top = if shown then self._tabH + Theme.sizes.gap else 0
	self._status.Position = UDim2.fromOffset(0, top)
	local listTop = top + STATUS_HEIGHT + Theme.sizes.gap + 4
	self._list.Position = UDim2.fromOffset(0, listTop)
	self._list.Size = UDim2.new(1, 0, 1, -listTop)
end

function BaitBowl._buildRows(self: any)
	for _, row in self._rows do
		row.use:destroy()
		row.details:destroy()
		row.icon:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	self._bowlLure = nil -- the bowl's picture follows the new catalog's food
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")
	-- every food in rarity order, the night dealer's among the shop's (F97 section 3); rarest first since #1609
	-- (Derek2 11-05), as the Bag's Bait tab
	local foods: { Types.LureDef } = FoodOrder.defs(catalog.lures, true)
	-- on a phone Use and Details grow to a 44 px face and the card's top with them, as in the dealer's list
	local buttonH = Scale.tapHeight(BUTTON.Y, Theme.sizes.buttonDepth)
	local detailsH = Scale.tapHeight(DETAILS_H, Theme.sizes.buttonDepth)
	local topHeight = math.max(ICON + 16, buttonH + 16, detailsH + 16)
	for index, lure in foods do
		local dealer = lure.source == "dealer"
		local row: Frame = Create("Frame", {
			Name = lure.id,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = index,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			-- F69: the card's border in the food's grade colour, like its badge
			Create("UIStroke", {
				Color = Theme.rarityColor(FoodGrade.of(lure)),
				Thickness = Theme.sizes.stroke + 1,
			}),
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local top: Frame = Create("Frame", {
			Name = "Top",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, topHeight),
			LayoutOrder = 1,
			Parent = row,
		})
		local icon = ItemIcon.new({
			parent = top,
			size = UDim2.fromOffset(ICON, ICON),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 12, 0.5, 0),
			badge = "gem",
		})
		icon:setFood(lure)
		local heading: Frame = Create("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, TEXT_LEFT, 0.5, -24),
			Size = UDim2.new(1, TEXT_WIDTH, 0, 24),
			Parent = top,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		text({
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 2,
			Text = lure.name,
			LayoutOrder = 1,
			Parent = heading,
		})
		-- the food's own grade in its colour, where the "Attracts" chip was (#1612)
		local grade = FoodGrade.of(lure)
		text({
			Name = "Grade",
			Size = UDim2.fromOffset(90, 24), -- "Legendary" at full width, beside a name of any length
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.rarityLight(grade),
			TextTruncate = Enum.TextTruncate.None,
			Text = grade,
			LayoutOrder = 2,
			Parent = heading,
		})
		local count = text({
			Name = "Count",
			Position = UDim2.new(0, TEXT_LEFT, 0.5, 2),
			Size = UDim2.new(1, TEXT_WIDTH, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			Parent = top,
		})
		-- Use on the right and Details beside it (#1612); the odds live under Details
		local use = Button.new({
			name = "Use",
			text = "Use",
			style = "primary",
			size = UDim2.fromOffset(BUTTON.X, buttonH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -12, 0.5, 0),
			textSize = Theme.sizes.textBody,
			parent = top,
			onClick = function()
				self._callbacks.useLure(lure.id, self._selected)
			end,
		})
		local details = Button.new({
			name = "Details",
			text = "Details",
			style = "ghost",
			size = UDim2.fromOffset(DETAILS_W, detailsH),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -(12 + BUTTON.X + 8), 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = top,
			onClick = function()
				self:_toggleDetail(lure.id)
			end,
		})
		local detail = text({
			Name = "Detail",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = PAL.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true, -- the odds in their colours, then the gold line and the split
			Text = "",
			Visible = false,
			LayoutOrder = 2,
			Parent = row,
		})
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 12),
			Parent = detail,
		})
		self._rows[lure.id] = {
			frame = row,
			icon = icon,
			count = count,
			use = use,
			details = details,
			detail = detail,
			odds = FoodOdds.rich(lure.odds, rarityHex), -- the five-rarity odds at the bowl's level, for Details
			split = nil :: string?, -- the per-cat split for the tier and bowl last drawn
			def = lure,
			dealer = dealer,
		}
	end
	self._tier = -1 -- rebuild the odds and split text on the next render
	self._extras = ""
end

function BaitBowl._toggleDetail(self: any, lureId: string)
	local row = self._rows[lureId]
	if not row then
		return
	end
	row.detail.Visible = not row.detail.Visible
	row.details:setText(if row.detail.Visible then "Hide details" else "Details")
end

function BaitBowl.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildRows()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.setBait(self: any, bait: Types.BaitView?, catWaiting: boolean, bowl: number?)
	local index = if bowl == 2 then 2 else 1
	self._baits[index] = bait
	self._waiting[index] = catWaiting
	if bait ~= nil then
		self._lastLure[index] = bait.lureId
	end
	self:_layout()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

-- #1161: the second bowl's kind from ProfileSync, and the pass's price for the locked tab's card.
function BaitBowl.setSecond(self: any, kind: string?, price: PassPrice?)
	self._second = if kind == "on" or kind == "offer" then kind else nil
	self._price = price
	self:_layout()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.select(self: any, bowl: number)
	local index = if bowl == 2 and self._tabsShown then 2 else 1
	if self._selected == index then
		return
	end
	self._selected = index
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.selected(self: any): number
	return self._selected
end

-- Bowl 2 takes food only with the pass; a cat already at it can always be tamed or let go.
function BaitBowl._takesFood(self: any, bowl: number): boolean
	return bowl == 1 or self._second == "on"
end

-- The locked bowl 2: no pass and nothing in it, so its tab shows the pass card.
function BaitBowl._locked(self: any, bowl: number): boolean
	return bowl == 2 and self._second ~= "on" and self._baits[2] == nil
end

-- The tab the screen opens on: a cat waiting first, then an empty bowl that takes food, else bowl 1; never the
-- locked one, so the pass card only shows when the player taps its tab.
function BaitBowl.openOn(self: any)
	local pick = 1
	if self._tabsShown and not self._waiting[1] then
		local secondEmpty = self._baits[2] == nil and self:_takesFood(2)
		if self._waiting[2] or (self._baits[1] ~= nil and secondEmpty) then
			pick = 2
		end
	end
	self._selected = pick
end

-- F60: by night the empty bowl promises the night wait; a bowl already filling keeps its own readyAt.
function BaitBowl.setNight(self: any, night: boolean)
	if self._night == night then
		return
	end
	self._night = night
	self._waitSeconds = FoodOdds.waitSeconds(self._bowlLevel, self._bigBowl, self._speed, night)
	if self.frame.Visible then
		self:_renderStatus()
	end
end

local function ownsBowl(state: Types.PlayerState): boolean
	return (state.upgradeLevels.lure_bowl or 0) >= 1
end

function BaitBowl.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_layout()
	if not self.frame.Visible then
		return -- money ticks re-render every screen; this one catches up when it opens
	end
	local catalog: Types.Catalog? = self._catalog
	-- the odds row and the split are the bowl level's (F82) at the player's Luck (F88), the split the tier's areas too
	local bowlLevel: number = state.upgradeLevels.lure_bowl or 0
	local luck = LuckLogic.current(state, Workspace:GetServerTimeNow())
	local oddsChanged = catalog ~= nil
		and (state.tier ~= self._tier or bowlLevel ~= self._bowlLevel or luck ~= self._luck)
	self._bowlLevel = bowlLevel
	if catalog and oddsChanged then
		self._tier = state.tier
		self._luck = luck
		self._panel:setTitle(if bowlLevel >= 1 then Bait.bowlName(bowlLevel) else TITLE, SUBTITLE)
		for _, row in self._rows do
			row.odds = FoodOdds.rich(FoodOdds.atBowl(row.def.odds, bowlLevel, luck), rarityHex)
			row.split = FoodOdds.split(catalog, row.def, state.tier, bowlLevel, luck)
		end
	end
	local totals = if catalog then IndexRewards.totals(catalog, state) else nil
	local boosts = PotionLogic.boosts(catalog, state, Workspace:GetServerTimeNow())
	local fishPerks: { [string]: number } = state.fishPerks or {}
	self._bigBowl = (fishPerks.big_bowl or 0) >= 1
	self._speed = (if totals then totals.baitSpeed else 0) + boosts.baitSpeed
	self._waitSeconds = FoodOdds.waitSeconds(bowlLevel, self._bigBowl, self._speed, self._night)
	-- Details: the gold chance with the Index's gold luck (F54) and the running potions (F73) in it and the charm
	-- stars, then the split
	local extras =
		FoodOdds.extras(if totals then totals.goldLuck else 0, boosts.goldLuck, boosts.goldScale)
	local rainbow = FoodOdds.rainbow(state.rainbowLuck) -- F99: under the gold line once rainbow rolls exist
	if rainbow then
		extras ..= "\n" .. rainbow
	end
	if oddsChanged or extras ~= self._extras then
		self._extras = extras
		for _, row in self._rows do
			row.detail.Text = row.odds .. "\n" .. plain(extras .. "\n" .. (row.split or ""))
		end
	end
	local owned = ownsBowl(state)
	local selected: number = self._selected
	local empty = self._baits[selected] == nil
	local takes = self:_takesFood(selected)
	local locked = self:_locked(selected)
	self._oddsCard.Visible = locked
	if locked then
		self:_renderOdds(bowlLevel, luck)
	end
	for lureId, row in self._rows do
		row.frame.Visible = not locked -- the locked tab lists bowl 2's odds in place of the foods
		local have = state.lures[lureId] or 0
		-- #1281: where to get more, in calm grey, with none left: the night dealer's cart or the Corner Shop
		if have > 0 then
			row.count.Text = ("You have %d"):format(have)
		elseif row.dealer then
			row.count.Text = "Sold by the night dealer's cart"
		else
			row.count.Text = "Get more at the Corner Shop"
		end
		row.use:setEnabled(owned and takes and empty and have > 0)
	end
	self:_renderStatus()
end

-- #1161: the locked bowl's odds card, one line per food in a bowl of this level (the same as bowl 1's).
function BaitBowl._renderOdds(self: any, bowlLevel: number, luck: number)
	self._oddsNote.Text = if luck > 1
		then ("Same foods and odds as bowl 1. Your %s helps both bowls the same way."):format(
			LuckLogic.text(luck)
		)
		else "Same foods and odds as bowl 1, at your bowl's level."
	if self._oddsLevel == bowlLevel then
		return
	end
	self._oddsLevel = bowlLevel
	for _, line in self._oddsLines do
		line:Destroy()
	end
	table.clear(self._oddsLines)
	local rows: { any } = Bait.oddsCard(bowlLevel)
	for index, row in rows do
		local line = text({
			Name = "Odds_" .. tostring(row.lureId),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, ODDS_LINE),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			RichText = true,
			Text = ("%s: %s"):format(row.name, FoodOdds.rich(row.odds, rarityHex)),
			LayoutOrder = 1 + index,
			Parent = self._oddsCard,
		})
		table.insert(self._oddsLines, line)
	end
end

-- #1161: each tab's state, "Bowl 1 · 4m 10s", "Bowl 2 · Empty" or "Bowl 2 · Cat!", the chosen one in gold.
function BaitBowl._renderTabs(self: any)
	if not self._tabsShown then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for bowl, button in self._tabButtons do
		local bait: Types.BaitView? = self._baits[bowl]
		local label: string
		if self:_locked(bowl) then
			label = Theme.icons.lock .. " Bowl 2"
		elseif bait == nil then
			label = ("Bowl %d · Empty"):format(bowl)
		elseif bait.readyAt - now <= 0 then
			label = ("Bowl %d · Cat!"):format(bowl)
		else
			label = ("Bowl %d · %s"):format(bowl, Format.duration(math.ceil(bait.readyAt - now)))
		end
		button:setText(label)
		button:setStyle(if bowl == self._selected then "gold" else "ghost")
	end
end

-- The status card's states: no bowl yet, empty, a cat on its way, a cat at the bowl, and (#1161) the locked bowl 2.
function BaitBowl._renderStatus(self: any)
	local state: Types.PlayerState? = self._state
	if not state then
		return
	end
	self:_renderTabs()
	local selected: number = self._selected
	local bait: Types.BaitView? = self._baits[selected]
	local title: string
	local sub: string
	local action: string? = nil
	local ready = false
	self._track.Visible = false
	if not ownsBowl(state) then
		title = "No bait bowl yet"
		sub = "Buy the Bait bowl in Upgrades, then put food in it to bring a cat to your door."
		action = "upgrades"
	elseif self:_locked(selected) then
		title = "Get a second bowl"
		sub = "Run two baits at once: a second bowl by your door."
		action = "buy"
	elseif bait == nil then
		title = if self._tabsShown
			then ("Bowl %d is empty"):format(selected)
			else "Your bowl is empty"
		local wait = Format.duration(self._waitSeconds)
		local refill: Types.LureDef? = self:_refillFood(state, selected)
		sub = if not self:_takesFood(selected)
			then "Bowl 2 takes new food with the Second Bait Bowl pass."
			elseif
				self._night
			then ("%s Night bait: half the wait. Use a food now and a cat comes by in %s."):format(
				Theme.icons.moon,
				wait
			)
			elseif
				refill
			then ("Refill puts in another %s, or pick a food and press Use. A cat comes by in %s."):format(
				refill.name,
				wait
			)
			else "Pick a food and press Use. A cat comes by in " .. wait .. ", even if you leave."
		if refill then
			action = "refill"
		end
	else
		local left = bait.readyAt - Workspace:GetServerTimeNow()
		local foodName = bait.lureId
		local food: Types.LureDef? = nil
		for _, row in self._rows do
			if row.def.id == bait.lureId then
				foodName = row.def.name
				food = row.def
			end
		end
		if self._bowlLure ~= bait.lureId then
			self._bowlLure = bait.lureId
			self._bowlFood:setFood(food, bait.lureId)
		end
		if left > 0 then
			title = if self._tabsShown
				then foodName .. " is in bowl " .. tostring(selected)
				else foodName .. " is in the bowl"
			local inTime = Format.duration(math.ceil(left))
			sub = if bait.night
				then ("%s Night bait: half the wait. A cat comes by in %s."):format(
					Theme.icons.moon,
					inTime
				)
				else ("A cat comes by in %s. You can leave; it waits for you."):format(inTime)
			-- the bowl's own wait from placedAt, else today's for its phase
			local total = if bait.placedAt
				then bait.readyAt - bait.placedAt
				else FoodOdds.waitSeconds(
					self._bowlLevel,
					self._bigBowl,
					self._speed,
					bait.night
				)
			self._track.Visible = true
			self._fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(total, 1), 0, 1), 1)
		else
			ready = true
			local waiting = self._waiting[selected] == true
			title = if self._tabsShown
				then ("A cat is at bowl %d!"):format(selected)
				else "A cat is at your bowl!"
			sub = if waiting
				then "Tame it or let it go. The food is used either way."
				else "It is sitting down at your bowl now."
			if waiting then
				action = "cat"
			end
		end
	end
	self._bowlFood.frame.Visible = bait ~= nil and ownsBowl(state)
	self._bowlTile.Visible = not self._bowlFood.frame.Visible
	self._statusTitle.Text = title
	self._statusTitle.TextColor3 = if ready then Theme.colors.gold else Theme.colors.white
	self._statusSub.Text = sub
	self._statusBorder.Color = if ready then Theme.colors.gold else Theme.colors.outline
	self._actionKind = action
	self._action.instance.Visible = action ~= nil
	local style = "gold"
	local enabled = true
	if action == "upgrades" then
		self._action:setText("Upgrades")
	elseif action == "cat" then
		self._action:setText("See the cat")
	elseif action == "refill" then
		self._action:setText("Refill")
		style = "primary"
	elseif action == "buy" then
		-- the price from Roblox, never from here (shop-and-pass-plan section 1): "..." until it answers, Soon off sale
		local price: PassPrice? = self._price
		if price == nil then
			self._action:setText("...")
			style, enabled = "ghost", false
		elseif not price.forSale or price.robux == nil then
			self._action:setText("Soon")
			style, enabled = "ghost", false
		else
			self._action:setText(("R$%d"):format(price.robux :: number))
			style = "store"
		end
	end
	if style ~= self._actionStyle then
		self._actionStyle = style
		self._action:setStyle(style :: any)
	end
	self._action:setEnabled(enabled)
end

function BaitBowl._pressAction(self: any)
	if self._actionKind == "upgrades" then
		self._callbacks.openUpgrades()
	elseif self._actionKind == "cat" then
		self._callbacks.showCat(self._selected)
	elseif self._actionKind == "buy" then
		self._callbacks.buySecond()
	elseif self._actionKind == "refill" then
		local state: Types.PlayerState? = self._state
		local food = if state then self:_refillFood(state, self._selected) else nil
		if food then
			self._callbacks.useLure(food.id, self._selected)
		end
	end
end

-- #1573 Refill: the food this bowl last held, while the bowl is empty, takes food and you still have one.
function BaitBowl._refillFood(self: any, state: Types.PlayerState, bowl: number): Types.LureDef?
	local lureId: string? = self._lastLure[bowl]
	if lureId == nil or self._baits[bowl] ~= nil or not self:_takesFood(bowl) then
		return nil
	end
	if (state.lures[lureId] or 0) <= 0 then
		return nil
	end
	local row = self._rows[lureId]
	return if row then row.def else nil
end

function BaitBowl.destroy(self: any)
	self._tick:Disconnect()
	for _, row in self._rows do
		row.use:destroy()
		row.details:destroy()
		row.icon:destroy()
	end
	self._action:destroy()
	for _, button in self._tabButtons do
		button:destroy()
	end
	self._bowlFood:destroy()
	self._panel:destroy()
end

return BaitBowl
