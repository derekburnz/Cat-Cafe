--!strict
-- The Index's reward strip (F48, data-model section 11b): a row of milestone cards above the open area's cats,
-- like the index rewards in Pet Simulator 99. Each card shows what it needs ("3 cats", "All 10 gold"), the prize
-- and either a bar toward it, a green Claim button or "✓ Claimed". The sums live in Components/IndexRewards;
-- the strip hides itself when the catalog has no prizes for the area.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	claim: (areaId: string, milestoneId: string) -> (),
}

export type IndexStrip = {
	frame: Frame,
	setCatalog: (self: IndexStrip, catalog: Types.Catalog) -> (),
	render: (self: IndexStrip, state: Types.PlayerState, areaId: string?) -> (),
	destroy: (self: IndexStrip) -> (),
}

local HEIGHT = 68
local ICON = 52
local TEXT_LEFT = ICON + 16
local PENDING_SECONDS = 3 -- a pressed Claim waits this long for ProfileSync before it can be pressed again
local COIN_GLYPH = "💰"

local IndexStrip = {}
IndexStrip.__index = IndexStrip

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
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

function IndexStrip.new(parent: Instance, callbacks: Callbacks): IndexStrip
	local self = setmetatable({}, IndexStrip) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._lureById = {} :: { [string]: Types.LureDef }
	self._decorById = {} :: { [string]: Types.DecorDef }
	self._cards = {} :: { [string]: any }
	self._pending = {} :: { [string]: number } -- "area:milestone" -> os.clock() of the press
	self._state = nil :: Types.PlayerState?
	self._area = nil :: string?

	self.frame = Create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		LayoutOrder = 0,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	return self :: IndexStrip
end

function IndexStrip.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	table.clear(self._lureById)
	for _, lure in catalog.lures do
		self._lureById[lure.id] = lure
	end
	table.clear(self._decorById)
	for _, decor in catalog.decor do
		self._decorById[decor.id] = decor
	end
	for _, card in self._cards do
		card.claim:destroy()
		card.icon:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	local milestones: { Types.IndexMilestone } = catalog.indexMilestones or {}
	for order, milestone in milestones do
		self:_buildCard(milestone, order)
	end
end

function IndexStrip._buildCard(self: any, milestone: Types.IndexMilestone, order: number)
	local frame: Frame = Create("Frame", {
		Name = milestone.id,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = self.frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = Theme.modal.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
	})
	local icon = ItemIcon.new({
		parent = frame,
		size = UDim2.fromOffset(ICON, ICON),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 8, 0.5, 0),
	})
	local need = text({
		Name = "Need",
		Position = UDim2.fromOffset(TEXT_LEFT, 5),
		Size = UDim2.new(1, -(TEXT_LEFT + 8), 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		Parent = frame,
	})
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 5),
		Size = UDim2.fromOffset(56, 16),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	local prize = text({
		Name = "Prize",
		Position = UDim2.fromOffset(TEXT_LEFT, 21),
		Size = UDim2.new(1, -(TEXT_LEFT + 8), 0, 18),
		FontFace = Theme.fonts.display,
		Parent = frame,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(TEXT_LEFT, 46),
		Size = UDim2.new(1, -(TEXT_LEFT + 8), 0, 10),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = if milestone.gold then Theme.colors.gold else Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local done = text({
		Name = "Done",
		Position = UDim2.fromOffset(TEXT_LEFT, 40),
		Size = UDim2.new(1, -(TEXT_LEFT + 8), 0, 22),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.goodDark,
		Text = "✓ Claimed",
		Visible = false,
		Parent = frame,
	})
	local id = milestone.id
	local claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.new(1, -(TEXT_LEFT + 8), 0, 26),
		position = UDim2.fromOffset(TEXT_LEFT, 38),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			local area: string? = self._area
			if area == nil then
				return
			end
			self._pending[area .. ":" .. id] = os.clock()
			self._callbacks.claim(area, id)
			self:_refresh()
			-- if no ProfileSync answers, let the button be pressed again
			task.delay(PENDING_SECONDS, function()
				if self._cards[id] then
					self:_refresh()
				end
			end)
		end,
	})
	claim.instance.Visible = false
	self._cards[id] = {
		frame = frame,
		stroke = stroke,
		icon = icon,
		need = need,
		count = count,
		prize = prize,
		track = track,
		fill = fill,
		done = done,
		claim = claim,
		gold = milestone.gold == true,
		shown = nil :: string?, -- the area whose prize the icon and text show
	}
end

-- "$300", "2 Tuna", "Salmon + Alley Mural Print"; the icon is the decor, else the food, else coins.
function IndexStrip._showPrize(self: any, card: any, prize: Types.IndexPrize, gold: boolean)
	local parts: { string } = {}
	local coins: number? = prize.coins
	if coins and coins > 0 then
		table.insert(parts, Format.money(coins))
	end
	local firstLure: Types.LureDef? = nil
	for _, entry in IndexRewards.lureList(prize) do
		local lure: Types.LureDef? = self._lureById[entry.id]
		firstLure = firstLure or lure
		local name = if lure then lure.name else entry.id
		table.insert(parts, if entry.count > 1 then ("%d %s"):format(entry.count, name) else name)
	end
	local decorId: string? = prize.decorId
	local decor: Types.DecorDef? = if decorId then self._decorById[decorId] else nil
	if decorId then
		table.insert(parts, if decor then decor.name else "Index decor")
	end
	card.prize.Text = table.concat(parts, " + ")
	if decorId then
		card.icon:set(
			if decor then decor.asset else nil,
			Theme.icons.decor,
			if gold then "Legendary" else "Epic"
		)
	elseif firstLure then
		card.icon:set(
			firstLure.asset,
			Theme.foodIcons[firstLure.id] or Theme.icons.food,
			firstLure.attracts
		)
	else
		card.icon:set(nil, COIN_GLYPH, "Legendary")
	end
end

function IndexStrip.render(self: any, state: Types.PlayerState, areaId: string?)
	self._state = state
	self._area = areaId
	self:_refresh()
end

function IndexStrip._refresh(self: any)
	local catalog: Types.Catalog? = self._catalog
	local state: Types.PlayerState? = self._state
	local area: string? = self._area
	if catalog == nil or state == nil or area == nil then
		self.frame.Visible = false
		return
	end
	local views = IndexRewards.views(catalog, state, area)
	local total = IndexRewards.counts(catalog, state, area).total
	self.frame.Visible = #views > 0
	for _, card in self._cards do
		card.frame.Visible = false
	end
	local gap = Theme.sizes.gap
	local width =
		UDim2.new(1 / math.max(1, #views), -gap * (#views - 1) / math.max(1, #views), 1, 0)
	for _, view in views do
		local card = self._cards[view.milestone.id]
		if not card then
			continue
		end
		card.frame.Visible = true
		card.frame.Size = width
		if card.shown ~= area then
			card.shown = area
			self:_showPrize(card, view.prize, card.gold)
		end
		local need = view.milestone.need
		card.need.Text = IndexRewards.needLabel(view.milestone, total)
		card.count.Text = ("%d / %d"):format(view.have, need)
		local pressedAt: number? = self._pending[area .. ":" .. view.milestone.id]
		local pending = pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
		local ready = view.state == "ready"
		local claimed = view.state == "claimed"
		card.claim.instance.Visible = ready
		card.claim:setEnabled(not pending)
		card.claim:setText(if pending then "..." else "Claim")
		card.track.Visible = view.state == "locked"
		card.fill.Size = UDim2.fromScale(if need > 0 then view.have / need else 0, 1)
		card.done.Visible = claimed
		card.count.Visible = not claimed
		card.stroke.Color = if ready
			then Theme.colors.good
			elseif card.gold then Theme.colors.gold
			else Theme.modal.cardStroke
		card.stroke.Thickness = Theme.sizes.stroke + (if ready then 1 else 0)
		card.frame.BackgroundTransparency = if claimed then 0.35 else 0
	end
end

function IndexStrip.destroy(self: any)
	for _, card in self._cards do
		card.claim:destroy()
		card.icon:destroy()
	end
	table.clear(self._cards)
	self.frame:Destroy()
end

return IndexStrip
