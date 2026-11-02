--!strict
-- The Daily Treat window (F70, data-model section 11e), kept brief (Derek 2026-10-28 01:09). One line on top says
-- what is next ("Day 3 is ready!", "Next treat in 5 h 12 min"), then the card: seven days, each with its prize as
-- little pictures (Components/PrizeChips: coins from the day rate, foods, golden fish, crates, spins, a potion). A
-- stamped day fades and reads "✓ Stamped", the day due now wears a green border and Claim, and the next one reads
-- "Tomorrow". Day 7 is the wide gold "Best day". The subtitle carries the no-pressure rule: a missed day loses
-- nothing, so there is no streak to lose. Opened from the HUD's Daily tile, and by itself once when a player joins
-- with a stamp due (UI init). Claim reads "..." until a sync stamps the day or PENDING_SECONDS pass; the server takes
-- one a second and answers a refusal with ProfileSync. A new stamp plays uiDailyStamp, or jingleDailyCard on day 7.
-- Rules: Components/DailyTreatLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DailyTreatLogic = require(script.Parent.Parent.Components.DailyTreatLogic)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	claim: () -> (),
	-- the card arrived (shown) and whether a stamp is due, each time either changes: for the HUD's Daily tile
	status: (shown: boolean, due: boolean) -> (),
	close: () -> (),
}

export type DailyTreat = {
	frame: Frame,
	setCatalog: (self: DailyTreat, catalog: Types.Catalog) -> (),
	render: (self: DailyTreat, state: Types.PlayerState) -> (),
	setNight: (self: DailyTreat, night: boolean) -> (),
	destroy: (self: DailyTreat) -> (),
}

type Card = {
	frame: Frame,
	stroke: UIStroke,
	chips: PrizeChips.PrizeChips,
	status: TextLabel,
	claim: Button.Button,
	best: boolean,
}

local CARD = Vector2.new(150, 140)
local GAP = Theme.sizes.gap + 4
local ICON = 44
local STRIP_HEIGHT = 40
local BEST_FILL = Theme.colors.gold:Lerp(Theme.colors.paper, 0.72)
local PENDING_SECONDS = 2
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6

local DailyTreat = {}
DailyTreat.__index = DailyTreat

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function DailyTreat.new(callbacks: Callbacks): DailyTreat
	local self = setmetatable({}, DailyTreat) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._view = nil :: Types.DailyTreatView?
	self._income = 0
	self._night = false
	self._spin = nil :: Types.SpinState?
	self._cards = {} :: { [number]: Card }
	self._pendingAt = nil :: number? -- os.clock() of the last Claim press
	self._shown = false -- what status last said
	self._due = false

	local panel = Panel.new({
		name = "DailyTreat",
		title = "Daily Treat",
		subtitle = "A stamp for each day you play · missing a day loses nothing",
		color = Theme.colors.berry,
		icon = Theme.icons.daily,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(700, 470), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	local strip: Frame = Create("Frame", {
		Name = "Strip",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, STRIP_HEIGHT),
		Parent = panel.content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = Theme.sizes.stroke }),
	})
	self._line = text({
		Name = "Next",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = strip,
	})

	self._grid = Create("ScrollingFrame", {
		Name = "Card",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, STRIP_HEIGHT + Theme.sizes.gap + 2),
		Size = UDim2.new(1, 0, 1, -(STRIP_HEIGHT + Theme.sizes.gap + 2)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		-- days 1 to 4 on the first line, then 5, 6 and the wide day 7; each cell carries the gap under it
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, GAP),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 6),
		}),
	})
	self:_build()

	-- once a second: the HUD tile's dot at UTC midnight, and the countdown while the window is open
	local clock = 0
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < 1 then
			return
		end
		clock = 0
		self:_refresh()
	end)

	return self :: DailyTreat
end

-- The seven cards, built once; the catalog's prizes fill them on each refresh.
function DailyTreat._build(self: any)
	for day = 1, DailyTreatLogic.DAYS do
		local best = day == DailyTreatLogic.DAYS
		local cell: Frame = Create("Frame", {
			Name = "Day" .. day,
			BackgroundTransparency = 1,
			Size = if best
				then UDim2.fromOffset(CARD.X * 2 + GAP, CARD.Y + GAP)
				else UDim2.fromOffset(CARD.X, CARD.Y + GAP),
			LayoutOrder = day,
			Parent = self._grid,
		})
		local frame: Frame = Create("Frame", {
			Name = "Card",
			BackgroundColor3 = if best then BEST_FILL else Theme.modal.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, CARD.Y),
			Parent = cell,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		})
		local stroke: UIStroke = Create("UIStroke", {
			Color = Theme.modal.cardStroke,
			Thickness = Theme.sizes.stroke,
			Parent = frame,
		})
		text({
			Name = "Day",
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = if best then Theme.colors.goldDark else Theme.modal.text,
			Text = if best then ("Day %d  ·  Best day"):format(day) else ("Day %d"):format(day),
			Parent = frame,
		})
		local chips = PrizeChips.new({
			parent = frame,
			tile = ICON,
			textSize = Theme.sizes.textBody,
			name = "Prize",
			position = UDim2.new(0.5, 0, 0, 28),
			anchorPoint = Vector2.new(0.5, 0),
			fitTo = frame,
			fitPad = 12,
		})
		local status = text({
			Name = "Status",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 26),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.line,
			FontFace = Theme.fonts.display,
			TextColor3 = Theme.modal.subtext,
			Visible = false,
			Parent = frame,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = status })
		local claim = Button.new({
			name = "Claim",
			text = "Claim",
			style = "primary",
			size = UDim2.new(1, -16, 0, 34),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -6),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_claim()
			end,
		})
		claim.instance.Visible = false
		self._cards[day] = {
			frame = frame,
			stroke = stroke,
			chips = chips,
			status = status,
			claim = claim,
			best = best,
		}
	end
end

function DailyTreat._claim(self: any)
	local pendingAt: number? = self._pendingAt
	if pendingAt ~= nil and os.clock() - pendingAt < PENDING_SECONDS then
		return
	end
	self._pendingAt = os.clock()
	self._callbacks.claim()
	self:_refresh()
	-- Claim comes back as soon as the wait is over, not on the next once-a-second tick
	task.delay(PENDING_SECONDS, function()
		if self._cards[1] then
			self:_refresh()
		end
	end)
end

function DailyTreat.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	for _, card: Card in self._cards do
		card.chips:setCatalog(catalog)
	end
	self:_refresh()
end

function DailyTreat.setNight(self: any, night: boolean)
	self._night = night
	self:_refresh()
end

function DailyTreat.render(self: any, state: Types.PlayerState)
	local view = DailyTreatLogic.view(state.dailyTreat)
	local stamped = DailyTreatLogic.claimedDay(self._view, view)
	self._view = view
	self._income = state.incomePerSecond
	self._spin = state.spin
	if stamped then
		self._pendingAt = nil
		Sound.play(DailyTreatLogic.stampSound(stamped))
	end
	self:_refresh()
	local card: Card? = if stamped then self._cards[stamped] else nil
	if card and self.frame.Visible then
		Tween.popIn(card.status, 0.5)
	end
end

function DailyTreat._refresh(self: any)
	local now = Workspace:GetServerTimeNow()
	local view: Types.DailyTreatView? = self._view
	local due = DailyTreatLogic.due(view, now)
	local shown = view ~= nil
	if shown ~= self._shown or due ~= self._due then
		self._shown, self._due = shown, due
		self._callbacks.status(shown, due)
	end
	if not self.frame.Visible then
		return
	end
	local catalog: Types.Catalog? = self._catalog
	local spin: Types.SpinState? = self._spin
	local look: PrizeChips.Look = {
		dayRate = TipJarLogic.dayRate(self._income, self._night, NIGHT_SHARE),
		spinsBanked = if spin then spin.banked else nil,
	}
	local pendingAt: number? = self._pendingAt
	local pending = pendingAt ~= nil and os.clock() - pendingAt < PENDING_SECONDS
	local readyDay: number? = nil
	for _, cell in DailyTreatLogic.cells(view, if catalog then catalog.dailyTreat else nil, now) do
		local card: Card? = self._cards[cell.day]
		if card == nil then
			continue
		end
		card.chips:set(cell.prize, look) -- coins follow the day rate; a full spin bank reads "Full"
		local ready = cell.state == "ready"
		local stamped = cell.state == "stamped"
		if ready then
			readyDay = cell.day
		end
		card.claim.instance.Visible = ready
		card.claim:setEnabled(not pending)
		card.claim:setText(if pending then "..." else "Claim")
		card.status.Visible = stamped or cell.state == "next"
		card.status.Text = if stamped then "✓ Stamped" else "Tomorrow"
		card.status.TextColor3 = if stamped then Theme.colors.goodDark else Theme.modal.subtext
		card.stroke.Color = if ready
			then Theme.colors.good
			elseif card.best then Theme.colors.goldDark
			else Theme.modal.cardStroke
		card.stroke.Thickness = Theme.sizes.stroke + (if ready or card.best then 1 else 0)
		card.frame.BackgroundTransparency = if stamped then 0.35 else 0
	end

	local wait = DailyTreatLogic.waitText(DailyTreatLogic.untilTomorrow(now))
	if view == nil then
		self._line.Text = ""
	elseif readyDay ~= nil then
		self._line.Text = ("Day %d is ready!"):format(readyDay)
	elseif view.stamp >= DailyTreatLogic.DAYS then
		self._line.Text = "Card full! A fresh card starts in " .. wait
	else
		self._line.Text = "Next treat in " .. wait
	end
	self._line.TextColor3 = if readyDay ~= nil then Theme.colors.goodDark else Theme.modal.text
end

function DailyTreat.destroy(self: any)
	self._tick:Disconnect()
	for _, card: Card in self._cards do
		card.claim:destroy()
		card.chips:destroy()
	end
	table.clear(self._cards)
	self._panel:destroy()
end

return DailyTreat
