--!strict
-- The Index's reward strip (F48, data-model section 11b; F54, golden-fish.md section 5): a row of milestone cards
-- above the open area's cats, like the index rewards in Pet Simulator 99. Each card shows what it needs ("3 cats",
-- "4 gold"), the prize as little pictures with amounts (Components/PrizeChips: "$300", golden fish "x10", the food
-- "x2", a crate, spins), a band when the milestone adds a forever bonus ("+2% tips forever", "+3% gold luck
-- forever" or "+2% faster bait forever", v0.10), and either a bar
-- toward it, a green Claim button or "✓ Claimed". The next card to work toward on each track (normal and gold)
-- wears a NEXT sticker and says how many cats are left (Derek 2026-10-27: show what the next reward is and how
-- much). With F54's nine milestones an area the row scrolls sideways and opens on the first NEXT card. The sums
-- live in Components/IndexRewards; the strip hides itself when the catalog has no prizes for the area.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local Outline = require(script.Parent.Parent.Components.Outline)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	claim: (areaId: string, milestoneId: string) -> (),
}

export type IndexStrip = {
	frame: ScrollingFrame,
	setCatalog: (self: IndexStrip, catalog: Types.Catalog) -> (),
	setNight: (self: IndexStrip, night: boolean) -> (),
	render: (self: IndexStrip, state: Types.PlayerState, areaId: string?) -> (),
	destroy: (self: IndexStrip) -> (),
}

local CARD = Vector2.new(200, 144)
local STICKER = 10 -- room above the cards for the NEXT sticker
local EDGE = 4 -- room round the cards for their outline inside the scrolling row
local SCROLLBAR = 6
local TILE = 26 -- a prize picture
local PAD = 10
local BAND = 18 -- the forever bonus band
local PENDING_SECONDS = 3 -- a pressed Claim waits this long for ProfileSync before it can be pressed again
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6

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
	self._cards = {} :: { [string]: any }
	self._pending = {} :: { [string]: number } -- "area:milestone" -> os.clock() of the press
	self._state = nil :: Types.PlayerState?
	self._area = nil :: string?
	self._night = false
	self._scrolledFor = nil :: string? -- "area:milestone" the row last scrolled to, so it scrolls once per change

	self.frame = Create("ScrollingFrame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, CARD.Y + STICKER + EDGE * 2 + SCROLLBAR),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = SCROLLBAR,
		ScrollBarImageColor3 = Theme.modal.subtext,
		LayoutOrder = 0,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, STICKER + EDGE),
			PaddingLeft = UDim.new(0, EDGE),
			PaddingRight = UDim.new(0, EDGE),
		}),
	})

	return self :: IndexStrip
end

function IndexStrip.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	for _, card in self._cards do
		card.claim:destroy()
		card.chips:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	local milestones: { Types.IndexMilestone } = catalog.indexMilestones or {}
	for order, milestone in milestones do
		self:_buildCard(milestone, order)
	end
	self._scrolledFor = nil
end

function IndexStrip.setNight(self: any, night: boolean)
	self._night = night
	self:_refresh()
end

function IndexStrip._buildCard(self: any, milestone: Types.IndexMilestone, order: number)
	local gold = IndexRewards.isGold(milestone)
	local frame: Frame = Create("Frame", {
		Name = milestone.id,
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		LayoutOrder = order,
		Parent = self.frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = Theme.modal.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
	})
	local chips = PrizeChips.new({
		parent = frame,
		tile = TILE,
		textSize = Theme.sizes.textSmall,
		wrap = true,
		showBonus = false,
		size = UDim2.new(1, -PAD * 2, 0, 0),
		position = UDim2.fromOffset(PAD, 28),
	})
	if self._catalog then
		chips:setCatalog(self._catalog)
	end
	local need = text({
		Name = "Need",
		Position = UDim2.fromOffset(PAD, 8),
		Size = UDim2.new(1, -(PAD + 64), 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		Parent = frame,
	})
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(56, 16),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
	-- a forever bonus gets a band of its own, so it never wraps under the pictures
	local band = text({
		Name = "Bonus",
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		Position = UDim2.new(0, PAD, 1, -54),
		Size = UDim2.new(1, -PAD * 2, 0, BAND),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true, -- "+2% faster bait forever" shrinks a little rather than cut off
		Visible = false,
		Parent = frame,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = band })
	Create("UITextSizeConstraint", { MaxTextSize = Theme.sizes.textTiny, Parent = band })
	local pad = UDim.new(0, 6)
	Create("UIPadding", { PaddingLeft = pad, PaddingRight = pad, Parent = band })
	Outline.text(band, 1.5)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.new(0, PAD, 1, -20),
		Size = UDim2.new(1, -PAD * 2, 0, 10),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = if gold then Theme.colors.gold else Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local done = text({
		Name = "Done",
		Position = UDim2.new(0, PAD, 1, -32),
		Size = UDim2.new(1, -PAD * 2, 0, 24),
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.goodDark,
		Text = "✓ Claimed",
		Visible = false,
		Parent = frame,
	})
	-- the card to work toward next: a sticker over its top edge, gold on the gold track
	local sticker: TextLabel = Create("TextLabel", {
		Name = "Next",
		BackgroundColor3 = if gold then Theme.colors.gold else Theme.colors.good,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(52, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.white,
		Text = "NEXT",
		Rotation = 4,
		Visible = false,
		ZIndex = 3,
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(sticker, 2)
	Outline.text(sticker, 1.5)
	local id = milestone.id
	local claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = UDim2.new(1, -PAD * 2, 0, 28),
		position = UDim2.new(0, PAD, 1, -34),
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
		chips = chips,
		need = need,
		count = count,
		band = band,
		sticker = sticker,
		track = track,
		fill = fill,
		done = done,
		claim = claim,
		gold = gold,
		order = order,
	}
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
	local nextNormal = IndexRewards.nextView(views, "normal")
	local nextGold = IndexRewards.nextView(views, "gold")
	local look: PrizeChips.Look = {
		dayRate = TipJarLogic.dayRate(state.incomePerSecond, self._night, NIGHT_SHARE),
		spinsBanked = if state.spin then state.spin.banked else nil,
		tier = state.tier,
	}
	self.frame.Visible = #views > 0
	for _, card in self._cards do
		card.frame.Visible = false
	end
	for _, view in views do
		local card = self._cards[view.milestone.id]
		if not card then
			continue
		end
		card.frame.Visible = true
		card.chips:set(view.prize, {
			gold = card.gold,
			dayRate = look.dayRate,
			spinsBanked = look.spinsBanked,
			tier = look.tier,
		})
		local need = IndexRewards.need(view.milestone)
		local isNext = view == nextNormal or view == nextGold
		local toGo = IndexRewards.toGo(view)
		local label = IndexRewards.needLabel(view.milestone, total, area)
		card.need.Text = if isNext and view.state == "locked"
			then ("%s · %d to go"):format(label, toGo)
			else label
		card.sticker.Visible = isNext
		card.count.Text = ("%d / %d"):format(view.have, need)
		local perk, amount = IndexRewards.perk(view.prize)
		card.band.Visible = perk ~= nil
		card.band.Text = if perk then "★ " .. PrizeChips.bonusText(amount, perk) else ""
		card.band.BackgroundColor3 = PrizeChips.perkColor(perk)
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
			elseif isNext or card.gold then Theme.colors.gold
			else Theme.modal.cardStroke
		card.stroke.Thickness = Theme.sizes.stroke + (if ready or isNext then 1 else 0)
		card.frame.BackgroundTransparency = if claimed then 0.35 else 0
	end
	self:_scrollToNext(views, area, IndexRewards.nextView(views))
end

-- Opens the row on the next card once per area and per next card, so a player who scrolls away is left alone.
function IndexStrip._scrollToNext(
	self: any,
	views: { IndexRewards.View },
	area: string,
	nextView: IndexRewards.View?
)
	local key = area .. ":" .. (if nextView then nextView.milestone.id else "")
	if key == self._scrolledFor then
		return
	end
	self._scrolledFor = key
	local before = 0 -- shown cards to the left of the next one
	if nextView then
		for _, view in views do
			if view == nextView then
				break
			end
			if self._cards[view.milestone.id] then
				before += 1
			end
		end
	end
	-- keep one card of the past in view, so the row reads as progress
	local x = math.max(0, before - 1) * (CARD.X + Theme.sizes.gap)
	self.frame.CanvasPosition = Vector2.new(x, 0)
end

function IndexStrip.destroy(self: any)
	for _, card in self._cards do
		card.claim:destroy()
		card.chips:destroy()
	end
	table.clear(self._cards)
	self.frame:Destroy()
end

return IndexStrip
