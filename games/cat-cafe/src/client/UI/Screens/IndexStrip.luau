--!strict
-- The Index's reward strip (F48, data-model section 11b; F54, golden-fish.md section 5): the open area's milestones
-- above its cats, like the index rewards in Pet Simulator 99. Each card shows what it needs ("3 cats", "4 gold"),
-- the prize as pictures with amounts (Components/PrizeChips: "$300", golden fish "x10", the food "x2", a crate,
-- spins), a band when the milestone adds a forever bonus ("+2% tips forever", "+3% gold luck forever" or "+2% faster
-- bait forever", v0.10), and either a bar toward it, a green Claim button or "✓ Claimed".
-- Only the next reward shows, as one big card with bigger pictures (Derek 2026-10-28: "only show next reward and make
-- it bigger unless they click a expand milestones then show rest"): a reward waiting to be claimed first, else the
-- first one still to earn. Expand milestones opens the full row of small cards under it, which scrolls sideways and
-- opens on the first NEXT card; the button carries a red count of the other rewards waiting. The sums live in
-- Components/IndexRewards; the strip hides itself when the catalog has no prizes for the area.

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
	frame: Frame,
	setCatalog: (self: IndexStrip, catalog: Types.Catalog) -> (),
	setNight: (self: IndexStrip, night: boolean) -> (),
	render: (self: IndexStrip, state: Types.PlayerState, areaId: string?) -> (),
	destroy: (self: IndexStrip) -> (),
}

local CARD = Vector2.new(200, 172) -- a small card: room for three lines of pictures above the bonus band
local STICKER = 10 -- room above the cards for the NEXT sticker
local EDGE = 4 -- room round the cards for their outline inside the scrolling row
local SCROLLBAR = 6
local TILE = 26 -- a prize picture on a small card
local PAD = 10
local BAND = 18 -- the forever bonus band
local BIG_H = 124 -- the next reward's card
local BIG_MAX = 560 -- its widest, so it reads as one card on a wide screen
local BIG_TILE = 40
local BIG_RIGHT = 140 -- its right column: the count, then the bar, Claim or "✓ Claimed"
local EXPAND = Vector2.new(184, 40)
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
	self._total = 0 -- the open page's cats, for "All 10"
	self._expanded = false -- the full row; shut on open, so the next reward is all that shows

	self.frame = Create("Frame", {
		Name = "Rewards",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 0,
		Visible = false,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- the next reward and the Expand milestones button beside it
	local top: Frame = Create("Frame", {
		Name = "Next",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, BIG_H + STICKER + EDGE * 2),
		LayoutOrder = 1,
		Parent = self.frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, STICKER + EDGE),
			PaddingBottom = UDim.new(0, EDGE),
			PaddingLeft = UDim.new(0, EDGE),
		}),
	})
	local featured = self:_buildCard(top, true, 1)
	featured.frame.Size = UDim2.new(1, -(EXPAND.X + Theme.sizes.gap + EDGE), 0, BIG_H)
	Create("UISizeConstraint", { MaxSize = Vector2.new(BIG_MAX, BIG_H), Parent = featured.frame })
	self._featured = featured
	self._expand = Button.new({
		name = "Expand",
		text = "Expand milestones",
		style = "secondary",
		size = UDim2.fromOffset(EXPAND.X, EXPAND.Y),
		textSize = Theme.sizes.textSmall,
		layoutOrder = 2,
		parent = top,
		onClick = function()
			self._expanded = not self._expanded
			self:_refresh()
		end,
	})
	-- a red count of the rewards waiting that the big card is not showing
	local dot: Frame = Create("Frame", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		Visible = false,
		ZIndex = 6,
		Parent = self._expand.instance,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	self._badge = dot
	self._badgeCount = text({
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

	self._row = Create("ScrollingFrame", {
		Name = "All",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, CARD.Y + STICKER + EDGE * 2 + SCROLLBAR),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = SCROLLBAR,
		ScrollBarImageColor3 = Theme.modal.subtext,
		LayoutOrder = 2,
		Visible = false,
		Parent = self.frame,
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
		local card = self:_buildCard(self._row, false, order)
		card.milestoneId = milestone.id
		card.gold = IndexRewards.isGold(milestone)
		card.fill.BackgroundColor3 = if card.gold then Theme.colors.gold else Theme.colors.mint
		card.sticker.BackgroundColor3 = if card.gold then Theme.colors.gold else Theme.colors.good
		card.frame.Name = milestone.id
		self._cards[milestone.id] = card
	end
	self._featured.chips:setCatalog(catalog)
	self._scrolledFor = nil
end

function IndexStrip.setNight(self: any, night: boolean)
	self._night = night
	self:_refresh()
end

-- One milestone card: a small one for the full row, or the big one for the next reward, which shows whichever
-- milestone _refresh gives it (`card.milestoneId`) with bigger pictures on one line and its count, bar and Claim
-- button in a column on the right.
function IndexStrip._buildCard(self: any, parent: Instance, big: boolean, order: number): any
	local frame: Frame = Create("Frame", {
		Name = if big then "Card" else "Milestone",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		LayoutOrder = order,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local stroke: UIStroke = Create("UIStroke", {
		Color = Theme.modal.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
	})
	-- the big card's left side holds the words and pictures, its right column the progress
	local left: Frame = Create("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = if big then UDim2.new(1, -(BIG_RIGHT + PAD), 1, 0) else UDim2.fromScale(1, 1),
		Parent = frame,
	})
	local right: Frame = if big
		then Create("Frame", {
			Name = "Right",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -PAD, 0, 0),
			Size = UDim2.new(0, BIG_RIGHT, 1, 0),
			Parent = frame,
		})
		else left
	-- small cards wrap their pictures in up to three lines above the band, so the band never sits on them; the
	-- big card keeps one line and shrinks it to fit beside its right column
	local chips = PrizeChips.new({
		parent = left,
		tile = if big then BIG_TILE else TILE,
		textSize = if big then Theme.sizes.textBody else Theme.sizes.textSmall,
		wrap = not big,
		showBonus = false,
		size = UDim2.new(1, -PAD * 2, 0, 0),
		position = UDim2.fromOffset(PAD, if big then 36 else 28),
		fitTo = if big then left else nil,
		fitPad = PAD * 2,
	})
	if self._catalog then
		chips:setCatalog(self._catalog)
	end
	local need = text({
		Name = "Need",
		Position = UDim2.fromOffset(PAD, if big then 10 else 8),
		Size = if big then UDim2.new(1, -PAD * 2, 0, 20) else UDim2.new(1, -(PAD + 64), 0, 16),
		FontFace = Theme.fonts.bodyBold,
		TextSize = if big then Theme.sizes.textBody else Theme.sizes.textTiny,
		TextColor3 = if big then Theme.modal.text else Theme.modal.subtext,
		Parent = left,
	})
	local count = text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = if big then UDim2.new(1, 0, 0, 10) else UDim2.new(1, -8, 0, 8),
		Size = if big then UDim2.new(1, 0, 0, 26) else UDim2.fromOffset(56, 16),
		FontFace = Theme.fonts.display,
		TextSize = if big then Theme.sizes.textLarge else Theme.sizes.textTiny,
		TextColor3 = if big then Theme.modal.text else Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = right,
	})
	-- a forever bonus gets a band of its own, so it never wraps under the pictures: across the small card's foot,
	-- or as a pill under the big card's pictures
	local band = text({
		Name = "Bonus",
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		Position = if big then UDim2.new(0, PAD, 1, -(BAND + 14)) else UDim2.new(0, PAD, 1, -56),
		Size = if big then UDim2.fromOffset(0, BAND + 2) else UDim2.new(1, -PAD * 2, 0, BAND),
		AutomaticSize = if big then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		FontFace = Theme.fonts.display,
		TextSize = if big then Theme.sizes.textSmall else Theme.sizes.textTiny,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = not big, -- "+2% faster bait forever" shrinks a little on a small card rather than cut off
		TextTruncate = Enum.TextTruncate.None,
		Visible = false,
		Parent = left,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = band })
	if not big then
		Create("UITextSizeConstraint", { MaxTextSize = Theme.sizes.textTiny, Parent = band })
	end
	local pad = UDim.new(0, if big then 10 else 6)
	Create("UIPadding", { PaddingLeft = pad, PaddingRight = pad, Parent = band })
	Outline.text(band, 1.5)
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = if big then UDim2.new(0, 0, 1, -26) else UDim2.new(0, PAD, 1, -20),
		Size = if big then UDim2.new(1, 0, 0, 12) else UDim2.new(1, -PAD * 2, 0, 10),
		Parent = right,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill: Frame = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local done = text({
		Name = "Done",
		Position = if big then UDim2.new(0, 0, 1, -40) else UDim2.new(0, PAD, 1, -32),
		Size = if big then UDim2.new(1, 0, 0, 28) else UDim2.new(1, -PAD * 2, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = if big then Theme.sizes.textBody else Theme.sizes.textSmall,
		TextColor3 = Theme.colors.goodDark,
		TextXAlignment = if big then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		Text = "✓ Claimed",
		Visible = false,
		Parent = right,
	})
	-- the card to work toward next: a sticker over its top edge, gold on the gold track
	local sticker: TextLabel = Create("TextLabel", {
		Name = "NextSticker",
		BackgroundColor3 = Theme.colors.good,
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
	local card: any = {
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
		gold = false,
		big = big,
		milestoneId = nil :: string?,
	}
	card.claim = Button.new({
		name = "Claim",
		text = "Claim",
		style = "primary",
		size = if big then UDim2.new(1, 0, 0, 36) else UDim2.new(1, -PAD * 2, 0, 28),
		position = if big then UDim2.new(0, 0, 1, -46) else UDim2.new(0, PAD, 1, -34),
		textSize = if big then Theme.sizes.textBody else Theme.sizes.textSmall,
		parent = right,
		onClick = function()
			local area: string? = self._area
			local id: string? = card.milestoneId
			if area == nil or id == nil then
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
	card.claim.instance.Visible = false
	return card
end

function IndexStrip.render(self: any, state: Types.PlayerState, areaId: string?)
	self._state = state
	self._area = areaId
	self:_refresh()
end

-- Fills one card with a milestone's view: what it needs, the prize, its band, and its bar, Claim or "✓ Claimed".
function IndexStrip._fill(
	self: any,
	card: any,
	view: IndexRewards.View,
	look: PrizeChips.Look,
	isNext: boolean
)
	local area: string = self._area
	local total: number = self._total
	card.milestoneId = view.milestone.id
	card.chips:set(view.prize, {
		gold = card.gold,
		dayRate = look.dayRate,
		spinsBanked = look.spinsBanked,
		tier = look.tier,
	})
	local need = IndexRewards.need(view.milestone)
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

function IndexStrip._refresh(self: any)
	local catalog: Types.Catalog? = self._catalog
	local state: Types.PlayerState? = self._state
	local area: string? = self._area
	if catalog == nil or state == nil or area == nil then
		self.frame.Visible = false
		return
	end
	local views = IndexRewards.views(catalog, state, area)
	self._total = IndexRewards.counts(catalog, state, area).total
	local nextNormal = IndexRewards.nextView(views, "normal")
	local nextGold = IndexRewards.nextView(views, "gold")
	local look: PrizeChips.Look = {
		dayRate = TipJarLogic.dayRate(state.incomePerSecond, self._night, NIGHT_SHARE),
		spinsBanked = if state.spin then state.spin.banked else nil,
		tier = state.tier,
	}
	self.frame.Visible = #views > 0
	if #views == 0 then
		return
	end

	-- the big card: a reward waiting first, else the first still to earn, else (all claimed) the last one
	local nextView = IndexRewards.nextView(views)
	local shown = nextView or views[#views]
	local featured = self._featured
	local gold = IndexRewards.isGold(shown.milestone)
	featured.gold = gold
	featured.fill.BackgroundColor3 = if gold then Theme.colors.gold else Theme.colors.mint
	featured.sticker.BackgroundColor3 = if gold then Theme.colors.gold else Theme.colors.good
	self:_fill(featured, shown, look, nextView ~= nil)
	local lead = if shown.state == "ready" then "Reward ready · " else "Next reward · "
	featured.need.Text = if nextView then lead .. featured.need.Text else "Every reward claimed"

	local waiting = 0
	for _, view in views do
		if view.state == "ready" and view ~= shown then
			waiting += 1
		end
	end
	self._badge.Visible = waiting > 0
	self._badgeCount.Text = tostring(waiting)
	local expanded = self._expanded == true and #views > 1
	self._expand.instance.Visible = #views > 1
	self._expand:setText(if expanded then "Hide milestones" else "Expand milestones")
	self._row.Visible = expanded

	for _, card in self._cards do
		card.frame.Visible = false
	end
	for _, view in views do
		local card = self._cards[view.milestone.id]
		if not card then
			continue
		end
		card.frame.Visible = true
		self:_fill(card, view, look, view == nextNormal or view == nextGold)
	end
	self:_scrollToNext(views, area, nextView)
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
	self._row.CanvasPosition = Vector2.new(x, 0)
end

function IndexStrip.destroy(self: any)
	for _, card in self._cards do
		card.claim:destroy()
		card.chips:destroy()
	end
	table.clear(self._cards)
	self._featured.claim:destroy()
	self._featured.chips:destroy()
	self._expand:destroy()
	self.frame:Destroy()
end

return IndexStrip
