--!strict
-- The Quests window (F73, quests.md sections 1 and 7; Derek 2026-10-27 21:59, approved 22:14). Opened from the Quests
-- pill on the left menu (key J) or the HUD's quest line. Three tabs, each kept brief (Derek 2026-10-28 01:09):
--   Daily         "3 of 5 done" and "New quests in 5 h", a strip with what finishing all five pays (✓ once paid),
--                 then a row per quest: its text, a bar with "3/5" ("$320/$600" for a coins quest), what it pays as
--                 little pictures (Components/PrizeChips) and Claim once done, ✓ once claimed, or Swap (the day's
--                 one free reroll) while it is unfinished and the swap unused.
--   Weekly        the same for the week's three.
--   Achievements  "12 of 44 claimed", then a card each: name, goal, bar, prize and Claim once met. Ready ones come
--                 first, then the closest to done; claimed ones go last, faded.
-- A tab with something to claim carries a red count. Claim and Swap read "..." until a sync shows the change or
-- PENDING_SECONDS pass; a refusal is the server's toast. QuestResult plays giftClaim. Rules: Components/QuestLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local QuestLogic = require(script.Parent.Parent.Components.QuestLogic)
local ShortNumber = require(script.Parent.Parent.Components.ShortNumber)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Tab = "Daily" | "Weekly" | "Achievements"

export type Callbacks = {
	claimQuest: (kind: string, slot: number) -> (),
	rerollQuest: (kind: string, slot: number) -> (),
	claimAchievement: (achievementId: string) -> (),
	close: () -> (),
}

export type Quests = {
	frame: Frame,
	setCatalog: (self: Quests, catalog: Types.Catalog) -> (),
	render: (self: Quests, state: Types.PlayerState) -> (),
	setNight: (self: Quests, night: boolean) -> (),
	showTab: (self: Quests, tab: Tab) -> (),
	result: (self: Quests, paid: { string }) -> (),
	onOpen: (self: Quests) -> (),
	onClose: (self: Quests) -> (),
	destroy: (self: Quests) -> (),
}

type QuestRow = {
	frame: Frame,
	title: TextLabel,
	fill: Frame,
	count: TextLabel,
	chips: PrizeChips.PrizeChips,
	claim: Button.Button,
	swap: Button.Button,
	check: TextLabel,
	claimed: boolean,
}

type Page = {
	kind: string, -- "daily" or "weekly"
	scroll: ScrollingFrame,
	done: TextLabel,
	resets: TextLabel,
	setCaption: TextLabel,
	setChips: PrizeChips.PrizeChips,
	setStatus: TextLabel,
	rows: { QuestRow },
}

type Card = {
	frame: Frame,
	name: TextLabel,
	goal: TextLabel,
	fill: Frame,
	count: TextLabel,
	chips: PrizeChips.PrizeChips,
	claim: Button.Button,
	check: TextLabel,
	size: string,
}

type Pending = { at: number, id: string, claimed: boolean }

local TABS: { Tab } = { "Daily", "Weekly", "Achievements" }
local MAX_SIZE = Vector2.new(660, 560)
local TAB_HEIGHT = Theme.sizes.touchMin
local TAB_WIDTH = 150
local HEAD = 26
local STRIP = 54
local ROW = 80
local BAR = 14
local CHIP = 30
local ACTION_W = 112
local CARD = Vector2.new(0, 142) -- two cards a row; the width follows the window
local CARD_CHIP = 26
local GAP = Theme.sizes.gap
local PENDING_SECONDS = 2 -- ClaimQuest and ClaimAchievement take 2 a second, RerollQuest 1
local TICK_SECONDS = 1 -- the reset times, while the window is open
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6

local Quests = {}
Quests.__index = Quests

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

local function card(name: string, size: UDim2, parent: Instance, order: number?): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = size,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
	})
end

-- A rounded bar and its fill.
local function bar(parent: Instance, position: UDim2, size: UDim2): Frame
	local track: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.good,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function check(parent: Instance, position: UDim2, anchor: Vector2): TextLabel
	return text({
		Name = "Check",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(ACTION_W, 32),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.goodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "✓ Claimed",
		Visible = false,
		Parent = parent,
	})
end

local function scroll(name: string, parent: Instance, top: number): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 10),
		}),
	})
end

-- The red count on a tab: how many things there are ready to claim.
local function countDot(parent: Instance): (Frame, TextLabel)
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		Visible = false,
		ZIndex = 6,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local label = text({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 7,
		Parent = dot,
	})
	return dot, label
end

local function destroyCard(entry: Card)
	entry.claim:destroy()
	entry.chips:destroy()
	entry.frame:Destroy()
end

function Quests.new(callbacks: Callbacks): Quests
	local self = setmetatable({}, Quests) :: any
	self._callbacks = callbacks
	self._alive = true
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._night = false
	self._open = false
	self._tab = "Daily" :: Tab
	self._pending = {} :: { [string]: Pending } -- "daily:2", "weekly:1" or an achievement id
	self._cards = {} :: { [string]: Card }
	self._cardsBuilt = false
	self._tick = nil :: RBXScriptConnection?

	local panel = Panel.new({
		name = "Quests",
		title = "Quests",
		subtitle = "Fresh quests every day and week",
		color = Theme.colors.goldDark,
		icon = Theme.icons.quests,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._tabs = {} :: { [string]: { button: Button.Button, dot: Frame, count: TextLabel } }
	for index, tab in TABS do
		local button = Button.new({
			name = tab .. "Tab",
			text = tab,
			style = if tab == "Daily" then "gold" else "ghost",
			size = UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
			textSize = Theme.sizes.textBody,
			layoutOrder = index,
			parent = tabs,
			sound = "uiTab",
			onClick = function()
				self:showTab(tab)
			end,
		})
		local dot, count = countDot(button.instance)
		self._tabs[tab] = { button = button, dot = dot, count = count }
	end

	local top = TAB_HEIGHT + GAP
	self._pages = {
		Daily = self:_buildPage("daily", 5, content, top),
		Weekly = self:_buildPage("weekly", 3, content, top),
	} :: { [string]: Page }

	-- Achievements: the count, then a grid of cards
	local achievements: Frame = Create("Frame", {
		Name = "Achievements",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		Visible = false,
		Parent = content,
	})
	self._achievements = achievements
	self._claimedCount = text({
		Name = "Claimed",
		Size = UDim2.new(1, 0, 0, HEAD),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = achievements,
	})
	local grid = scroll("Grid", achievements, HEAD + 4)
	grid.Visible = true
	Create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -GAP / 2, 0, CARD.Y),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	self._grid = grid

	self:showTab("Daily")
	return self :: Quests
end

-- One tab of quests: the done count and reset time, the set prize strip, and `slots` rows.
function Quests._buildPage(
	self: any,
	kind: string,
	slots: number,
	parent: Instance,
	top: number
): Page
	local page = scroll(if kind == "daily" then "Daily" else "Weekly", parent, top)
	Create("UIListLayout", {
		Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	local head: Frame = Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEAD),
		LayoutOrder = 1,
		Parent = page,
	})
	local done = text({
		Name = "Done",
		Size = UDim2.new(0.5, 0, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = head,
	})
	local resets = text({
		Name = "Resets",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})

	-- what finishing all of them pays
	local strip = card("Set", UDim2.new(1, 0, 0, STRIP), page, 2)
	strip.BackgroundColor3 = Theme.colors.gold:Lerp(Theme.colors.paper, 0.7)
	local setCaption = text({
		Name = "Caption",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(120, 24),
		FontFace = Theme.fonts.display,
		Text = if kind == "daily" then "All 5 done:" else "All 3 done:",
		Parent = strip,
	})
	local chipArea: Frame = Create("Frame", {
		Name = "Prize",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(136, 0),
		Size = UDim2.new(1, -(136 + ACTION_W + 8), 1, 0),
		Parent = strip,
	})
	local setChips = PrizeChips.new({
		parent = chipArea,
		tile = CHIP,
		textSize = Theme.sizes.textSmall,
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.fromScale(0, 0.5),
		fitTo = chipArea,
		fitPad = 4,
	})
	local setStatus = text({
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(ACTION_W, 24),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.goodDark,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = strip,
	})

	local rows: { QuestRow } = {}
	for slot = 1, slots do
		local row: QuestRow = self:_buildRow(kind, slot, page)
		table.insert(rows, row)
	end
	return {
		kind = kind,
		scroll = page,
		done = done,
		resets = resets,
		setCaption = setCaption,
		setChips = setChips,
		setStatus = setStatus,
		rows = rows,
	}
end

function Quests._buildRow(self: any, kind: string, slot: number, parent: Instance): QuestRow
	local frame = card("Quest" .. slot, UDim2.new(1, 0, 0, ROW), parent, 10 + slot)
	local left = 14
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(left, 10),
		Size = UDim2.new(1, -(left + ACTION_W + 16), 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = frame,
	})
	-- the bar and count on the left half, what it pays on the right half of the second line
	local fill = bar(frame, UDim2.fromOffset(left, 48), UDim2.new(0.42, -left, 0, BAR))
	local count = text({
		Name = "Count",
		Position = UDim2.new(0.42, 6, 0, 44),
		Size = UDim2.fromOffset(96, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Parent = frame,
	})
	local chipArea: Frame = Create("Frame", {
		Name = "Prize",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.42, 104, 0, 38),
		Size = UDim2.new(0.58, -(104 + ACTION_W + 16), 0, CHIP + 4),
		Parent = frame,
	})
	local chips = PrizeChips.new({
		parent = chipArea,
		tile = CHIP,
		textSize = Theme.sizes.textSmall,
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.fromScale(0, 0.5),
		fitTo = chipArea,
		fitPad = 2,
	})
	local actionPosition = UDim2.new(1, -10, 0.5, 0)
	local claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.fromOffset(ACTION_W, Theme.sizes.touchMin),
		anchorPoint = Vector2.new(1, 0.5),
		position = actionPosition,
		parent = frame,
		onClick = function()
			self:_press(kind, slot, "claim")
		end,
	})
	local swap = Button.new({
		name = "Swap",
		text = "Swap",
		icon = "🔄",
		style = "ghost",
		size = UDim2.fromOffset(ACTION_W, Theme.sizes.touchMin),
		anchorPoint = Vector2.new(1, 0.5),
		position = actionPosition,
		parent = frame,
		onClick = function()
			self:_press(kind, slot, "swap")
		end,
	})
	return {
		frame = frame,
		title = title,
		fill = fill,
		count = count,
		chips = chips,
		claim = claim,
		swap = swap,
		check = check(frame, actionPosition, Vector2.new(1, 0.5)),
		claimed = false,
	}
end

function Quests._buildCard(self: any, def: Types.AchievementDef): Card
	local frame = card(def.id, UDim2.fromScale(1, 1), self._grid)
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Parent = frame,
	})
	local goal = text({
		Name = "Goal",
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Parent = frame,
	})
	local fill = bar(frame, UDim2.fromOffset(12, 58), UDim2.new(1, -110, 0, BAR - 2))
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 53),
		Size = UDim2.fromOffset(86, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	local chipArea: Frame = Create("Frame", {
		Name = "Prize",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 82),
		Size = UDim2.new(1, -(24 + ACTION_W - 16), 0, CARD_CHIP + 22),
		Parent = frame,
	})
	local chips = PrizeChips.new({
		parent = chipArea,
		tile = CARD_CHIP,
		textSize = Theme.sizes.textTiny,
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.fromScale(0, 0.5),
		fitTo = chipArea,
		fitPad = 2,
	})
	local actionPosition = UDim2.new(1, -10, 1, -10)
	local claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.fromOffset(ACTION_W - 16, Theme.sizes.touchMin - 4),
		anchorPoint = Vector2.new(1, 1),
		position = actionPosition,
		parent = frame,
		onClick = function()
			self:_pressAchievement(def.id)
		end,
	})
	local done = check(frame, UDim2.new(1, -4, 1, -14), Vector2.new(1, 1))
	return {
		frame = frame,
		name = name,
		goal = goal,
		fill = fill,
		count = count,
		chips = chips,
		claim = claim,
		check = done,
		size = def.size,
	}
end

function Quests.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	for _, page in self._pages do
		page.setChips:setCatalog(catalog)
		for _, row in page.rows do
			row.chips:setCatalog(catalog)
		end
	end
	if self._cardsBuilt then
		self:_syncCards()
	end
	if self._state then
		self:render(self._state)
	end
end

-- One card per achievement, kept while the catalog has it. Built the first time the window opens, so a player who
-- never opens it never pays for 44 cards.
function Quests._syncCards(self: any)
	self._cardsBuilt = true
	local catalog: Types.Catalog? = self._catalog
	if catalog == nil then
		return
	end
	local wanted: { [string]: boolean } = {}
	local defs: { Types.AchievementDef } = catalog.achievements or {}
	for _, def in defs do
		wanted[def.id] = true
		local existing: Card? = self._cards[def.id]
		local entry: Card = existing or self:_buildCard(def)
		self._cards[def.id] = entry
		entry.size = def.size
		entry.name.Text = def.name
		entry.goal.Text = def.text or ""
		entry.chips:setCatalog(catalog)
	end
	for id, entry in self._cards do
		if not wanted[id] then
			destroyCard(entry)
			self._cards[id] = nil
		end
	end
end

function Quests.setNight(self: any, night: boolean)
	if self._night ~= night then
		self._night = night
		if self._state then
			self:render(self._state)
		end
	end
end

function Quests._look(self: any): PrizeChips.Look
	local state: Types.PlayerState? = self._state
	if state == nil then
		return {}
	end
	return {
		dayRate = TipJarLogic.dayRate(state.incomePerSecond, self._night, NIGHT_SHARE),
		tier = state.tier,
	}
end

-- Whether a press on `key` still waits for the server: until a sync shows `id` swapped or claimed, or the wait ends.
function Quests._waiting(self: any, key: string, id: string, claimed: boolean): boolean
	local pending: Pending? = self._pending[key]
	if pending == nil then
		return false
	end
	if
		pending.id ~= id
		or pending.claimed ~= claimed
		or os.clock() - pending.at >= PENDING_SECONDS
	then
		self._pending[key] = nil
		return false
	end
	return true
end

function Quests.render(self: any, state: Types.PlayerState)
	self._state = state
	local catalog: Types.Catalog? = self._catalog
	local quests = state.quests
	local look = self:_look()
	for tab, page in self._pages do
		local kind = page.kind
		local list: { Types.QuestView } = {}
		local rerollUsed, setClaimed = true, false
		if quests then
			list = if kind == "daily" then quests.daily else quests.weekly
			rerollUsed = if kind == "daily" then quests.dailyRerollUsed else quests.weeklyRerollUsed
			setClaimed = if kind == "daily" then quests.dailySetClaimed else quests.weeklySetClaimed
		end
		page.done.Text = ("%d of %d done"):format(QuestLogic.doneCount(list), #list)
		page.setChips:set(QuestLogic.setPrize(catalog, kind), look)
		page.setStatus.Text = if setClaimed then "✓ Paid" else ""
		local ready = 0
		for slot, row in page.rows do
			local quest = list[slot]
			row.frame.Visible = quest ~= nil
			if quest then
				if not quest.claimed and QuestLogic.done(quest) then
					ready += 1
				end
				self:_renderRow(row, kind, slot, quest, rerollUsed, look)
			end
		end
		self:_setTabCount(tab, ready)
	end
	self:_renderAchievements(state, look)
	self:_tickResets()
end

function Quests._renderRow(
	self: any,
	row: QuestRow,
	kind: string,
	slot: number,
	quest: Types.QuestView,
	rerollUsed: boolean,
	look: PrizeChips.Look
)
	local needs = math.max(1, quest.needs)
	local progress = math.clamp(quest.progress, 0, needs)
	local done = QuestLogic.done(quest)
	row.title.Text = quest.text
	row.fill.Size = UDim2.fromScale(progress / needs, 1)
	row.fill.BackgroundColor3 = if done then Theme.colors.gold else Theme.colors.good
	row.count.Text = if QuestLogic.isCoins(self._catalog, quest.id)
		then Format.money(progress) .. "/" .. Format.money(needs)
		else ShortNumber.commas(progress) .. "/" .. ShortNumber.commas(needs)
	row.chips:set(QuestLogic.prize(self._catalog, kind, slot), look)

	local key = kind .. ":" .. slot
	local waiting = self:_waiting(key, quest.id, quest.claimed)
	row.claim.instance.Visible = done and not quest.claimed
	row.claim:setText(if waiting then "..." else "Claim")
	row.claim:setEnabled(not waiting)
	row.swap.instance.Visible = not done and not quest.claimed and not rerollUsed
	row.swap:setText(if waiting then "..." else "Swap")
	row.swap:setEnabled(not waiting)
	row.check.Visible = quest.claimed
	if quest.claimed and not row.claimed and self._open then
		Tween.popIn(row.check, 0.6)
	end
	row.claimed = quest.claimed
	row.frame.BackgroundColor3 = if quest.claimed then Theme.modal.panel else Theme.modal.card
end

function Quests._renderAchievements(self: any, state: Types.PlayerState, look: PrizeChips.Look)
	local catalog: Types.Catalog? = self._catalog
	local prizes = if catalog then catalog.achievementPrizes else nil
	local rows = QuestLogic.achievementRows(catalog, state.achievements)
	local ready = 0
	for order, row in rows do
		local entry: Card? = self._cards[row.def.id]
		if entry == nil then
			continue
		end
		local needs = math.max(1, row.def.needs)
		entry.frame.LayoutOrder = order
		entry.fill.Size = UDim2.fromScale(row.progress / needs, 1)
		entry.fill.BackgroundColor3 = if row.ready or row.claimed
			then Theme.colors.gold
			else Theme.colors.good
		entry.count.Text = ShortNumber.commas(row.progress) .. "/" .. ShortNumber.commas(needs)
		entry.chips:set(if prizes then prizes[entry.size] else nil, look)
		local waiting = self:_waiting(row.def.id, row.def.id, row.claimed)
		entry.claim.instance.Visible = row.ready
		entry.claim:setText(if waiting then "..." else "Claim")
		entry.claim:setEnabled(not waiting)
		entry.check.Visible = row.claimed
		entry.frame.BackgroundColor3 = if row.claimed
			then Theme.modal.panel
			elseif row.ready then Theme.colors.gold:Lerp(Theme.colors.paper, 0.75)
			else Theme.modal.card
		if row.ready then
			ready += 1
		end
	end
	self._claimedCount.Text = ("%d of %d claimed"):format(
		QuestLogic.claimedCount(catalog, state.achievements),
		#rows
	)
	self:_setTabCount("Achievements", ready)
end

function Quests._setTabCount(self: any, tab: Tab, count: number)
	local entry = self._tabs[tab]
	if count > 0 and not entry.dot.Visible then
		Tween.popIn(entry.dot, 0.5)
	end
	entry.dot.Visible = count > 0
	entry.count.Text = tostring(count)
end

-- The reset lines, once a second while the window is open.
function Quests._tickResets(self: any)
	local quests = if self._state then (self._state :: Types.PlayerState).quests else nil
	local now = Workspace:GetServerTimeNow()
	for _, page in self._pages do
		local at = if quests
			then (if page.kind == "daily" then quests.dailyResetsAt else quests.weeklyResetsAt)
			else nil
		page.resets.Text = if at then QuestLogic.resetText(at - now) else ""
	end
end

function Quests.showTab(self: any, tab: Tab)
	self._tab = tab
	for _, name in TABS do
		self._tabs[name].button:setStyle(if name == tab then "gold" else "ghost")
	end
	self._pages.Daily.scroll.Visible = tab == "Daily"
	self._pages.Weekly.scroll.Visible = tab == "Weekly"
	self._achievements.Visible = tab == "Achievements"
end

function Quests._press(self: any, kind: string, slot: number, action: string)
	local state: Types.PlayerState? = self._state
	local quests = if state then state.quests else nil
	local list = if quests then (if kind == "daily" then quests.daily else quests.weekly) else nil
	local quest = if list then list[slot] else nil
	if quest == nil then
		return
	end
	local key = kind .. ":" .. slot
	if self:_waiting(key, quest.id, quest.claimed) then
		return
	end
	self._pending[key] = { at = os.clock(), id = quest.id, claimed = quest.claimed }
	if action == "claim" then
		self._callbacks.claimQuest(kind, slot)
	else
		self._callbacks.rerollQuest(kind, slot)
	end
	self:_refreshAfter()
end

function Quests._pressAchievement(self: any, id: string)
	local state: Types.PlayerState? = self._state
	local views = if state then state.achievements else nil
	local view = if views then views[id] else nil
	local claimed = view ~= nil and view.claimed
	if self:_waiting(id, id, claimed) then
		return
	end
	self._pending[id] = { at = os.clock(), id = id, claimed = claimed }
	self._callbacks.claimAchievement(id)
	self:_refreshAfter()
end

-- Shows "..." now and lights the button again if no sync came within PENDING_SECONDS.
function Quests._refreshAfter(self: any)
	if self._state then
		self:render(self._state)
	end
	task.delay(PENDING_SECONDS, function()
		if self._alive and self._state then
			self:render(self._state)
		end
	end)
end

-- QuestResult(paid): the server's toast already says what it paid; the window gives it a sound.
function Quests.result(_self: any, paid: { string })
	if #paid > 0 then
		Sound.play("giftClaim")
	end
end

-- Opens on a tab with something to claim when the one last viewed has none.
function Quests.onOpen(self: any)
	self._open = true
	if not self._cardsBuilt then
		self:_syncCards()
	end
	local current = self._tabs[self._tab]
	if not current.dot.Visible then
		for _, tab in TABS do
			if self._tabs[tab].dot.Visible then
				self:showTab(tab)
				break
			end
		end
	end
	if self._state then
		self:render(self._state)
	end
	if self._tick == nil then
		local elapsed = 0
		self._tick = RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed >= TICK_SECONDS then
				elapsed = 0
				self:_tickResets()
			end
		end)
	end
end

function Quests.onClose(self: any)
	self._open = false
	local tick: RBXScriptConnection? = self._tick
	if tick then
		tick:Disconnect()
		self._tick = nil
	end
end

function Quests.destroy(self: any)
	self._alive = false
	self:onClose()
	for _, entry in self._cards do
		destroyCard(entry)
	end
	table.clear(self._cards)
	for _, page in self._pages do
		page.setChips:destroy()
		for _, row in page.rows do
			row.claim:destroy()
			row.swap:destroy()
			row.chips:destroy()
		end
	end
	for _, entry in self._tabs do
		entry.button:destroy()
	end
	self._panel:destroy()
end

return Quests
