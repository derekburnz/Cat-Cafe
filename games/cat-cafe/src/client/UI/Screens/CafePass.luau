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
-- Before the paid track is bought, a gold "Paid track R$299" button sits in the top strip with Roblox's price read at
-- runtime (setBuy); it hides once bought, while the price loads and while the product is off sale, and says nothing
-- else (no timer, no "last chance"). The tag picker comes later. Rules: Components/PassLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PassLogic = require(script.Parent.Parent.Components.PassLogic)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Types = require(script.Parent.Parent.Types)
local ViewScale = require(script.Parent.Parent.Scale)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local SharedPass = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CafePass")) :: any

-- the dark window palette (#1028 pilot)
local PAL = MenuFamily.pal
local CARD = MenuFamily.card -- #3558: what sits on a picture card (cream in the family look)

export type Callbacks = {
	claim: (track: string, level: number) -> (),
	buy: () -> (), -- the paid track's purchase prompt
	claimAll: () -> (),
	setTag: (pick: string) -> (), -- #1626: the chat tag button's next pick, a ChatTags id or "off"
	close: () -> (),
}

export type CafePass = {
	frame: Frame,
	setCatalog: (self: CafePass, catalog: Types.Catalog) -> (),
	setView: (self: CafePass, view: Types.CafePassView?) -> (),
	-- the buy button's words with the price ("Paid track  R$299"), or nil to hide it
	setBuy: (self: CafePass, text: string?) -> (),
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
	group: Frame?, -- #2087: a named item's picture over its name, centred in the room over Claim
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
local ITEM_MAX = 56 -- #2087: the items' own pictures, bigger
local ITEM_MIN = 28
local NAME_H = 30 -- two lines of the item's name
local NAME_ONE = 15 -- one line, on a short card
local PENDING_SECONDS = 2
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6
local MAPLE = Theme.colors.warn
local CLAIM_W = 150
local BUY_W = 180
local TAG_W = 160 -- #1626: the chat tag button
local BAR_X = 112

local CafePassScreen = {}
CafePassScreen.__index = CafePassScreen

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

function CafePassScreen.new(callbacks: Callbacks): CafePass
	local self = setmetatable({}, CafePassScreen) :: any
	-- #3961 (batch 4 panel 8): the level as a chip, FREE and PAID chips beside the rows and capital words
	local family = MenuFamily.on()
	self._family = family
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
		image = ShopIcons.hud("Pass"), -- #2588: the HUD Pass tile's medal, not the 🍁 emoji
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
		BackgroundColor3 = CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TOP_H),
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = CARD.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._levelText = text({
		Name = "Level",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(96, TOP_H),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 4,
		TextColor3 = CARD.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})
	if family then
		local level: TextLabel = self._levelText
		level.AnchorPoint = Vector2.new(0, 0.5)
		level.Position = UDim2.new(0, 8, 0.5, 0)
		level.Size = UDim2.fromOffset(BAR_X - 16, 32)
		level.BackgroundTransparency = 0
		level.BackgroundColor3 = MAPLE
		level.TextColor3 = Theme.colors.white
		level.TextSize = Theme.sizes.textBody + 1
		level.TextXAlignment = Enum.TextXAlignment.Center
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = level })
		Outline.text(level)
	end
	local bar: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = CARD.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, BAR_X, 0.5, 0),
		Size = UDim2.new(1, -(BAR_X + CLAIM_W + 24), 0, 24),
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
	if not MenuFamily.on() then
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 1.5, Parent = self._xpText })
	end
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
	self._bar = bar
	self._buy = Button.new({
		name = "Buy",
		text = "Paid track",
		style = "store",
		size = UDim2.fromOffset(BUY_W, CLAIM_H + 2),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, -1),
		textSize = Theme.sizes.textBody + 1,
		parent = top,
		onClick = function()
			self._callbacks.buy()
		end,
	})
	self._buy.instance.Visible = false
	-- #1626: the chat tag the player's name shows; a tap moves to their next tag, then off
	self._tag = Button.new({
		name = "ChatTag",
		text = "Chat tag",
		style = "slate",
		size = UDim2.fromOffset(TAG_W, CLAIM_H + 2),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, -1),
		textSize = Theme.sizes.textBody,
		parent = top,
		onClick = function()
			local button = PassLogic.tagButton(self._view)
			if button then
				self._callbacks.setTag(button.nextPick)
			end
		end,
	})
	self._tag.label.RichText = true
	self._tag.instance.Visible = false

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
		TextColor3 = PAL.text,
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
	if family then
		-- the words sit on a chip each (green for the free row, gold for the paid one)
		for _, pair in
			{
				{ self._freeWord, Theme.colors.goodDark, Theme.colors.white },
				{ self._paidWord, Theme.colors.gold, Theme.colors.goldText },
			}
		do
			local word: TextLabel, fill: Color3, ink: Color3 = pair[1], pair[2], pair[3]
			-- the chip carries the word; the row's own label keeps its place and size for the layout
			local chip: Frame = Create("Frame", {
				Name = "Chip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = fill,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -2, 0, 24),
				Parent = word,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			Outline.border(chip, 2)
			text({
				Name = "Word",
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textSmall,
				TextColor3 = ink,
				Text = string.upper(word.Text),
				Parent = chip,
			})
			word.TextTransparency = 1
		end
	end
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
		-- #2294: the first column's cards kept off the left edge, so their outlines aren't cut off (the level row
		-- above and TRACK_PAD below leave the rest of the room)
		Create(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, Outline.ROOM), PaddingRight = UDim.new(0, 6) }
		),
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
		TextColor3 = PAL.text,
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
	local group = slot.group
	if icon and name and group then
		-- #2087 (Derek2: "centre them lower they are too high"): the picture and its name centred together over Claim;
		-- a short card gives the name one line so the picture stays big
		local short = above < ITEM_MIN + NAME_H + 14
		local nameH = if short then NAME_ONE else NAME_H
		local size = math.clamp(above - nameH - 8, ITEM_MIN, ITEM_MAX)
		icon.frame.Size = UDim2.fromOffset(size, size)
		group.Position = UDim2.new(0.5, 0, 0, math.floor(above / 2) + 2)
		name.TextSize = if short or size < ITEM_MAX
			then Theme.sizes.textTiny + 1
			else Theme.sizes.textSmall
		name.TextWrapped = not short
		name.TextTruncate = if short then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None
		if short then
			name.AutomaticSize = Enum.AutomaticSize.None
			name.Size = UDim2.new(1, 0, 0, nameH)
		else
			name.AutomaticSize = Enum.AutomaticSize.Y
			name.Size = UDim2.new(1, 0, 0, 0)
		end
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
		BackgroundColor3 = if track == "paid" then CARD.goldCard else CARD.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(COL_W, SLOT_MAX),
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = CARD.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
	})
	local status = text({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = CARD.line,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.subtext,
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
		group = nil,
		status = status,
		claim = claim,
	}
end

-- What a reward gives, drawn once when the columns are built: a named item's picture and name, else its prize.
function CafePassScreen._fill(self: any, slot: Slot, reward: Types.PassReward)
	local item = reward.item
	if item then
		-- #2087: the item's own picture (its 3D model, a uniform's or a chat tag's colour), over its name, the two
		-- centred together in the room over Claim (_place)
		local group: Frame = Create("Frame", {
			Name = "ItemGroup",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = slot.frame,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local icon = ItemIcon.new({
			parent = group,
			size = UDim2.fromOffset(ITEM_MAX, ITEM_MAX),
			name = "Item",
		})
		icon.frame.LayoutOrder = 1
		local art = PassLogic.itemArt(item)
		icon:set(
			art.asset,
			art.glyph,
			if item.kind == "cat" then "Legendary" else "Epic",
			art.image, -- #2592: the uniform and tag pictures
			art.tint
		)
		slot.icon = icon
		slot.group = group
		slot.name = text({
			Name = "ItemName",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = Theme.sizes.textSmall,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Text = PassLogic.itemText(item),
			LayoutOrder = 2,
			Parent = group,
		})
		Create("UISizeConstraint", { MaxSize = Vector2.new(math.huge, NAME_H), Parent = slot.name })
		return
	end
	local chips = PrizeChips.new({
		parent = slot.frame,
		tile = TILE,
		textSize = Theme.sizes.textBody,
		textColor = CARD.text,
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
			TextColor3 = PAL.text, -- on the window's body, over the column
			Text = (if self._family then "LEVEL %d" else "Level %d"):format(level),
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

-- The buy button and Claim all from the right of the top strip, and the XP bar in the room left.
function CafePassScreen._placeTop(self: any)
	local right = 6
	if self._buy.instance.Visible then
		right += BUY_W + 8
	end
	self._claimAll.instance.Position = UDim2.new(1, -right, 0.5, -1)
	if self._claimAll.instance.Visible then
		right += CLAIM_W + 8
	end
	self._tag.instance.Position = UDim2.new(1, -right, 0.5, -1)
	if self._tag.instance.Visible then
		right += TAG_W + 8
	end
	self._bar.Size = UDim2.new(1, -(BAR_X + right + 6), 0, 24)
end

function CafePassScreen.setBuy(self: any, text: string?)
	self._buy.instance.Visible = text ~= nil
	if text then
		self._buy:setText(text)
	end
	self:_placeTop()
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
	self._prizeRate = state.prizeRate -- #2539
	self._spin = state.spin
	self._tier = state.tier
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
	slot.claim:setText(if pending then "..." elseif MenuFamily.on() then "CLAIM" else "Claim")
	slot.status.Visible = cell ~= nil and (state == "claimed" or state == "locked")
	slot.status.Text = if state == "claimed" then "✓ Claimed" else "🔒 Paid track"
	slot.status.TextColor3 = if state == "claimed" then CARD.good else CARD.gold
	slot.stroke.Color = if ready then Theme.colors.good else CARD.cardStroke
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
	-- Derek2 11-11: titles are picked in the Bag's Titles tab now, so the pass's Chat tag button stays hidden
	self._tag.instance.Visible = false
	if view == nil or not open then
		self._levelText.Text = "Level 0"
		self._xpFill.Size = UDim2.fromScale(0, 1)
		self._xpText.Text = ""
		self._claimAll.instance.Visible = false
		self:_placeTop()
		return
	end
	local def: Types.PassSeasonDef? = SharedPass.seasonDef(view.season)
	self._panel:setTitle("Cafe Pass", PassLogic.subtitle(view, if def then def.name else nil))
	local progress = PassLogic.progress(view)
	self._levelText.Text = (if self._family then "LEVEL %d" else "Level %d"):format(progress.level)
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
	self._claimAll:setText(
		if pending
			then "..."
			else (if self._family then "CLAIM ALL (%d)" else "Claim all (%d)"):format(ready)
	)
	self:_placeTop()
	local spin: Types.SpinState? = self._spin
	local look: PrizeChips.Look = {
		dayRate = TipJarLogic.prizeRate(self._prizeRate, self._income, self._night, NIGHT_SHARE),
		spinsBanked = if spin then spin.banked else nil,
		-- #1883: levels 15 and 25 give the "highest" crate, the crate of the highest area this tier opens (as the
		-- server's Prizes.crateFor), so the card shows that crate's picture and name
		tier = self._tier,
	}
	for index, column: Column in self._columns do
		local cell = cells[index]
		if cell == nil then
			continue
		end
		column.level.TextColor3 = if cell.reached then CARD.gold else CARD.subtext
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
	self._buy:destroy()
	self._panel:destroy()
	self._panel = nil
end

return CafePassScreen
