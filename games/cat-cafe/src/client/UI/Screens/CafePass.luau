--!strict
-- The Cafe Pass window (#1646, cafe-pass.md sections 1 to 5). The header names the season and its end as a plain date
-- ("Season 1: Maple · ends 3 January"), never a countdown, no "last chance" words and no red badge as the end nears
-- (section 1). On top: the player's level, the XP bar to the next level and Claim all. Then the track, one column per
-- level that scrolls sideways: the free reward on top (every second level) and the paid one under it (every level).
-- Each reward shows exactly what it gives: its prize as little pictures (Components/PrizeChips) or its named item with
-- its name. A reached, unclaimed reward wears a green border and Claim; a claimed one reads "✓ Claimed"; one not
-- reached yet is faded; a paid one before the paid track is bought shows a lock. Under the track: where pass XP comes
-- from and "These come back in a later season." (section 5). The cards take the track's height, so on a phone both
-- rows show without scrolling up and down. Claim reads "..." until the next CafePassState or PENDING_SECONDS pass.
-- The paid track's purchase, the Store card and the tag picker come with #1626. Rules: Components/PassLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Panel = require(script.Parent.Parent.Components.Panel)
local PassLogic = require(script.Parent.Parent.Components.PassLogic)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Types = require(script.Parent.Parent.Types)
local ViewScale = require(script.Parent.Parent.Scale)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local SharedPass = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafePass")) :: any

-- the dark window palette (#1028 pilot)
local PAL = Theme.dark

export type Callbacks = {
	claim: (track: string, level: number) -> (),
	claimAll: () -> (),
	close: () -> (),
}

export type CafePass = {
	frame: Frame,
	setCatalog: (self: CafePass, catalog: Types.Catalog) -> (),
	setView: (self: CafePass, view: Types.CafePassView?) -> (),
	render: (self: CafePass, state: Types.PlayerState) -> (),
	setNight: (self: CafePass, night: boolean) -> (),
	onOpen: (self: CafePass) -> (),
	destroy: (self: CafePass) -> (),
}

type Slot = {
	frame: Frame,
	stroke: UIStroke,
	chips: PrizeChips.PrizeChips?,
	icon: ItemIcon.ItemIcon?,
	name: TextLabel?,
	status: TextLabel,
	claim: Button.Button,
}

type Column = {
	frame: Frame,
	level: TextLabel,
	free: Slot?,
	paid: Slot,
}

-- a column's reward cards, the free one first when the level has one
local function slotsOf(column: Column): { Slot }
	local free = column.free
	return if free then { free, column.paid } else { column.paid }
end

local TOP_H = 46
local FOOT_H = 22
local GAP = Theme.sizes.gap
local SIDE_W = 56 -- the "Free" and "Paid" words left of the track
local COL_W = 128
local COL_GAP = 8
local TRACK_PAD = 8 -- under the cards, for the scroll bar
local LEVEL_H = 22
local SLOT_MAX = 134 -- a card's height when the track has room
local SLOT_MIN = 92 -- and its least, on a short phone
local CLAIM_H = 36 -- the least a tap needs (the UI gate)
local TILE = 36
local ITEM_MAX = 46
local ITEM_MIN = 24
local NAME_H = 30 -- two lines of the item's name
local PENDING_SECONDS = 2
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6
local MAPLE = Theme.colors.warn
local CLAIM_W = 150

local CafePassScreen = {}
CafePassScreen.__index = CafePassScreen

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

function CafePassScreen.new(callbacks: Callbacks): CafePass
	local self = setmetatable({}, CafePassScreen) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._view = nil :: Types.CafePassView?
	self._season = -1 -- the season the columns were built for
	self._columns = {} :: { Column }
	self._income = 0
	self._night = false
	self._spin = nil :: Types.SpinState?
	self._pendingAt = nil :: number?
	self._slotH = SLOT_MAX

	local panel = Panel.new({
		name = "CafePass",
		title = "Cafe Pass",
		subtitle = "Earn pass XP from quests",
		color = MAPLE,
		dark = true,
		icon = "🍁",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(880, 500), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the level, the XP bar and Claim all
	local top: Frame = Create("Frame", {
		Name = "Top",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TOP_H),
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._levelText = text({
		Name = "Level",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(96, TOP_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = PAL.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})
	local bar: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = PAL.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 112, 0.5, 0),
		Size = UDim2.new(1, -(112 + CLAIM_W + 24), 0, 24),
		ClipsDescendants = true,
		Parent = top,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._xpFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = MAPLE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._xpText = text({
		Name = "Xp",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		ZIndex = 2,
		Parent = bar,
	})
	Create("UIStroke", { Color = Theme.colors.outline, Thickness = 1.5, Parent = self._xpText })
	self._claimAll = Button.new({
		name = "ClaimAll",
		text = "Claim all",
		style = "primary",
		size = UDim2.fromOffset(CLAIM_W, CLAIM_H + 2),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, -1),
		textSize = Theme.sizes.textBody + 1,
		parent = top,
		onClick = function()
			self:_press(nil, nil)
		end,
	})

	-- the track: the row words on the left, the levels scrolling sideways
	local trackY = TOP_H + GAP
	local side: Frame = Create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, trackY),
		Size = UDim2.new(0, SIDE_W, 1, -(trackY + FOOT_H)),
		Parent = content,
	})
	self._side = side
	self._freeWord = text({
		Name = "Free",
		Size = UDim2.fromOffset(SIDE_W - 6, SLOT_MAX),
		FontFace = Theme.fonts.display,
		Text = "Free",
		Parent = side,
	})
	self._paidWord = text({
		Name = "Paid",
		Size = UDim2.fromOffset(SIDE_W - 6, SLOT_MAX),
		FontFace = Theme.fonts.display,
		TextColor3 = PAL.gold,
		Text = "Paid",
		Parent = side,
	})
	self._track = Create("ScrollingFrame", {
		Name = "Track",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(SIDE_W, trackY),
		Size = UDim2.new(1, -SIDE_W, 1, -(trackY + FOOT_H)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = content,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, COL_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	})
	self._foot = text({
		Name = "Later",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, 0),
		Size = UDim2.new(1, -8, 0, FOOT_H),
		TextColor3 = PAL.subtext,
		Text = "Pass XP comes from quests  ·  These come back in a later season.",
		Parent = content,
	})
	self._closed = text({
		Name = "Closed",
		Position = UDim2.fromOffset(0, trackY),
		Size = UDim2.new(1, 0, 0, 60),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Text = "The Cafe Pass opens soon.",
		Visible = false,
		Parent = content,
	})
	self._sized = self._track:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end)
	self._scaled = ViewScale.changed:Connect(function()
		self:_layout()
	end)
	self:_layout()
	self:_refresh()
	return self :: CafePass
end

-- The cards' height from the track's height in design units, so both rows show on a phone without scrolling up and
-- down; then every card's insides from that height.
function CafePassScreen._layout(self: any)
	local scale = ViewScale.get()
	local height = self._track.AbsoluteSize.Y / (if scale > 0 then scale else 1)
	local slotH = SLOT_MAX
	if height > 0 then
		slotH =
			math.clamp(math.floor((height - LEVEL_H - COL_GAP - TRACK_PAD) / 2), SLOT_MIN, SLOT_MAX)
	end
	self._slotH = slotH
	self._freeWord.Position = UDim2.fromOffset(0, LEVEL_H)
	self._freeWord.Size = UDim2.fromOffset(SIDE_W - 6, slotH)
	self._paidWord.Position = UDim2.fromOffset(0, LEVEL_H + slotH + COL_GAP)
	self._paidWord.Size = UDim2.fromOffset(SIDE_W - 6, slotH)
	for _, column: Column in self._columns do
		column.frame.Size = UDim2.fromOffset(COL_W, LEVEL_H + slotH * 2 + COL_GAP)
		local free = column.free
		if free then
			self:_place(free, LEVEL_H)
		end
		self:_place(column.paid, LEVEL_H + slotH + COL_GAP)
	end
end

-- One card at `y`, its picture sized to what is left over its name and Claim.
function CafePassScreen._place(self: any, slot: Slot, y: number)
	local slotH: number = self._slotH
	slot.frame.Position = UDim2.fromOffset(0, y)
	slot.frame.Size = UDim2.fromOffset(COL_W, slotH)
	local above = slotH - CLAIM_H - 6 -- the room over the Claim button
	local icon = slot.icon
	local name = slot.name
	if icon and name then
		local size = math.clamp(above - NAME_H - 6, ITEM_MIN, ITEM_MAX)
		icon.frame.Size = UDim2.fromOffset(size, size)
		icon.frame.Position = UDim2.new(0.5, 0, 0, 4)
		name.Position = UDim2.fromOffset(4, 4 + size + 1)
		name.TextSize = if size < ITEM_MAX then Theme.sizes.textTiny + 1 else Theme.sizes.textSmall
	end
	local chips = slot.chips
	if chips then
		chips.frame.Position = UDim2.new(0.5, 0, 0, math.max(6, math.floor((above - TILE) / 2)))
	end
end

-- One reward card: its Claim button and its status pill; _fill draws what it gives.
function CafePassScreen._slot(self: any, parent: Frame, track: string, level: number): Slot
	local frame: Frame = Create("Frame", {
		Name = if track == "free" then "Free" else "Paid",
		BackgroundColor3 = if track == "paid" then PAL.goldCard else PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(COL_W, SLOT_MAX),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = PAL.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
	})
	local status = text({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = PAL.line,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Visible = false,
		Parent = frame,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = status })
	local claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.new(1, -12, 0, CLAIM_H),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -4),
		textSize = Theme.sizes.textBody,
		parent = frame,
		onClick = function()
			self:_press(track, level)
		end,
	})
	claim.instance.Visible = false
	return {
		frame = frame,
		stroke = stroke,
		chips = nil,
		icon = nil,
		name = nil,
		status = status,
		claim = claim,
	}
end

-- What a reward gives, drawn once when the columns are built: a named item's picture and name, else its prize.
function CafePassScreen._fill(self: any, slot: Slot, reward: Types.PassReward)
	local item = reward.item
	if item then
		local icon = ItemIcon.new({
			parent = slot.frame,
			size = UDim2.fromOffset(ITEM_MAX, ITEM_MAX),
			anchorPoint = Vector2.new(0.5, 0),
			name = "Item",
		})
		icon:set(
			nil,
			PassLogic.itemGlyph(item.kind),
			if item.kind == "cat" then "Legendary" else "Epic"
		)
		slot.icon = icon
		slot.name = text({
			Name = "ItemName",
			Size = UDim2.new(1, -8, 0, NAME_H),
			TextSize = Theme.sizes.textSmall,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = PassLogic.itemText(item),
			Parent = slot.frame,
		})
		return
	end
	local chips = PrizeChips.new({
		parent = slot.frame,
		tile = TILE,
		textSize = Theme.sizes.textBody,
		textColor = PAL.text,
		name = "Prize",
		anchorPoint = Vector2.new(0.5, 0),
		fitTo = slot.frame,
		fitPad = 10,
		maxPictures = 2,
	})
	local catalog: Types.Catalog? = self._catalog
	if catalog then
		chips:setCatalog(catalog)
	end
	slot.chips = chips
end

-- The thirty columns for the season's tracks, built again only when the season changes.
function CafePassScreen._build(self: any, view: Types.CafePassView?)
	local season = if view then view.season else 0
	if season == self._season then
		return
	end
	self._season = season
	self:_clearColumns()
	local def: Types.PassSeasonDef? = if season > 0 then SharedPass.seasonDef(season) else nil
	if view == nil or def == nil then
		return
	end
	for level = 1, view.levels do
		local frame: Frame = Create("Frame", {
			Name = "Level" .. level,
			BackgroundTransparency = 1,
			LayoutOrder = level,
			Parent = self._track,
		})
		local label = text({
			Name = "Number",
			Size = UDim2.fromOffset(COL_W, LEVEL_H - 2),
			FontFace = Theme.fonts.display,
			Text = ("Level %d"):format(level),
			Parent = frame,
		})
		local free: Slot? = nil
		local freeReward = def.free[level]
		if freeReward then
			local slot = self:_slot(frame, "free", level)
			self:_fill(slot, freeReward)
			free = slot
		end
		local paid = self:_slot(frame, "paid", level)
		local paidReward = def.paid[level]
		if paidReward then
			self:_fill(paid, paidReward)
		end
		table.insert(self._columns, { frame = frame, level = label, free = free, paid = paid })
	end
	self:_layout()
end

function CafePassScreen._clearColumns(self: any)
	for _, column: Column in self._columns do
		for _, slot in slotsOf(column) do
			if slot.chips then
				slot.chips:destroy()
			end
			if slot.icon then
				slot.icon:destroy()
			end
			slot.claim:destroy()
		end
		column.frame:Destroy()
	end
	table.clear(self._columns)
end

-- Claim on one reward (track and level), or Claim all (nil, nil).
function CafePassScreen._press(self: any, track: string?, level: number?)
	local pendingAt: number? = self._pendingAt
	if pendingAt ~= nil and os.clock() - pendingAt < PENDING_SECONDS then
		return
	end
	self._pendingAt = os.clock()
	if track ~= nil and level ~= nil then
		self._callbacks.claim(track, level)
	else
		self._callbacks.claimAll()
	end
	self:_refresh()
	task.delay(PENDING_SECONDS, function()
		if self._panel then
			self:_refresh()
		end
	end)
end

function CafePassScreen.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	for _, column: Column in self._columns do
		for _, slot in slotsOf(column) do
			if slot.chips then
				slot.chips:setCatalog(catalog)
			end
		end
	end
	self:_refresh()
end

-- From CafePassState: at join, after each claim and at a season roll.
function CafePassScreen.setView(self: any, view: Types.CafePassView?)
	self._view = view
	self._pendingAt = nil
	self:_build(view)
	self:_refresh()
end

function CafePassScreen.render(self: any, state: Types.PlayerState)
	self._income = state.incomePerSecond
	self._spin = state.spin
	self:_refresh()
end

function CafePassScreen.setNight(self: any, night: boolean)
	self._night = night
	self:_refresh()
end

-- Scrolls the track to the first ready reward, else the next level to reach.
function CafePassScreen.onOpen(self: any)
	self:_layout()
	self:_refresh()
	local view: Types.CafePassView? = self._view
	if view == nil then
		return
	end
	local def: Types.PassSeasonDef? = SharedPass.seasonDef(view.season)
	local index = PassLogic.focus(PassLogic.columns(view, def), view.level)
	local x = math.max(0, (index - 2) * (COL_W + COL_GAP))
	self._track.CanvasPosition = Vector2.new(x, 0)
end

local function paintSlot(slot: Slot, cell: PassLogic.Cell?, pending: boolean)
	local state = if cell then cell.state else "ahead"
	local ready = cell ~= nil and state == "ready"
	slot.claim.instance.Visible = ready
	slot.claim:setEnabled(not pending)
	slot.claim:setText(if pending then "..." else "Claim")
	slot.status.Visible = cell ~= nil and (state == "claimed" or state == "locked")
	slot.status.Text = if state == "claimed" then "✓ Claimed" else "🔒 Paid track"
	slot.status.TextColor3 = if state == "claimed" then PAL.good else PAL.gold
	slot.stroke.Color = if ready then Theme.colors.good else PAL.cardStroke
	slot.stroke.Thickness = Theme.sizes.stroke + (if ready then 1 else 0)
	slot.frame.BackgroundTransparency = if cell == nil
		then 0.7
		elseif state == "ahead" or state == "claimed" then 0.35
		else 0
end

function CafePassScreen._refresh(self: any)
	local view: Types.CafePassView? = self._view
	local open = PassLogic.shows(view)
	PrizeChips.passOpen = open
	self._closed.Visible = not open
	self._track.Visible = open
	self._side.Visible = open
	self._foot.Visible = open
	if view == nil or not open then
		self._levelText.Text = "Level 0"
		self._xpFill.Size = UDim2.fromScale(0, 1)
		self._xpText.Text = ""
		self._claimAll.instance.Visible = false
		return
	end
	local def: Types.PassSeasonDef? = SharedPass.seasonDef(view.season)
	self._panel:setTitle("Cafe Pass", PassLogic.subtitle(view, if def then def.name else nil))
	local progress = PassLogic.progress(view)
	self._levelText.Text = ("Level %d"):format(progress.level)
	self._xpFill.Size = UDim2.fromScale(progress.fraction, 1)
	self._xpText.Text = progress.text
	if not self.frame.Visible then
		return
	end
	local cells = PassLogic.columns(view, def)
	local pendingAt: number? = self._pendingAt
	local pending = pendingAt ~= nil and os.clock() - pendingAt < PENDING_SECONDS
	local ready = PassLogic.readyCount(cells)
	self._claimAll.instance.Visible = ready > 0
	self._claimAll:setEnabled(not pending)
	self._claimAll:setText(if pending then "..." else ("Claim all (%d)"):format(ready))
	local spin: Types.SpinState? = self._spin
	local look: PrizeChips.Look = {
		dayRate = TipJarLogic.dayRate(self._income, self._night, NIGHT_SHARE),
		spinsBanked = if spin then spin.banked else nil,
	}
	for index, column: Column in self._columns do
		local cell = cells[index]
		if cell == nil then
			continue
		end
		column.level.TextColor3 = if cell.reached then PAL.gold else PAL.subtext
		local free = column.free
		if free then
			paintSlot(free, cell.free, pending)
			if free.chips and cell.free then
				free.chips:set(cell.free.reward.prize :: any, look) -- the shared prize shape
			end
		end
		paintSlot(column.paid, cell.paid, pending)
		if column.paid.chips and cell.paid then
			column.paid.chips:set(cell.paid.reward.prize :: any, look)
		end
	end
end

function CafePassScreen.destroy(self: any)
	self._sized:Disconnect()
	self._scaled:Disconnect()
	self:_clearColumns()
	self._claimAll:destroy()
	self._panel:destroy()
	self._panel = nil
end

return CafePassScreen
