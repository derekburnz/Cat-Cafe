--!strict
-- Tip Jar screen (F47, data-model section 11b): the twelve free playtime gifts of this session, like the Free
-- Gifts grid in Pet Simulator 99. A strip on top says how long you have played and when the next gift opens;
-- each card shows when it opens, the prize (coins from your day rate, or a food) and a green Claim button once
-- it is ready. Opened from the Gifts tile in the HUD's top-right icon row. The sums live in
-- Components/TipJarLogic; the jar resets when the player leaves, which the subtitle says. A gift that also banks
-- a Spin Wheel spin (F49, steps 11 and 12) wears a "+1 spin" badge, or "Spins full" while the bank is at
-- SpinBankCap, since the server then drops the spin and pays the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	claim: (step: number) -> (),
	status: (summary: TipJarLogic.Summary?) -> (), -- every second, for the HUD's Gifts tile; nil before any jar
	close: () -> (),
}

export type TipJar = {
	frame: Frame,
	setCatalog: (self: TipJar, catalog: Types.Catalog) -> (),
	setJar: (self: TipJar, jar: TipJarLogic.Jar?) -> (),
	setNight: (self: TipJar, night: boolean) -> (),
	render: (self: TipJar, state: Types.PlayerState) -> (),
	destroy: (self: TipJar) -> (),
}

local CARD = Vector2.new(150, 132)
local ICON = 52
local STRIP_HEIGHT = 52
local PENDING_SECONDS = 3 -- a pressed Claim waits this long for TipJarState before it can be pressed again
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6
local COIN_GLYPH = "💰"
local SPIN_BANK_CAP: number = Config.SpinBankCap or 20

local TipJar = {}
TipJar.__index = TipJar

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

function TipJar.new(callbacks: Callbacks): TipJar
	local self = setmetatable({}, TipJar) :: any
	self._callbacks = callbacks
	self._rows = {} :: { TipJarLogic.Row }
	self._lureById = {} :: { [string]: Types.LureDef }
	self._jar = nil :: TipJarLogic.Jar?
	self._income = 0
	self._night = false
	self._spin = nil :: Types.SpinState?
	self._cards = {} :: { [number]: any }
	self._pending = {} :: { [number]: number } -- step -> os.clock() of the press

	local panel = Panel.new({
		name = "TipJar",
		title = "Tip Jar",
		subtitle = "Free gifts for playing · they reset when you leave",
		color = Theme.colors.warn,
		icon = Theme.icons.gifts,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 580), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- the strip: time played, the next gift, and a bar filling toward it
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
	self._played = text({
		Name = "Played",
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -28, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = strip,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 10),
		Parent = strip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.warn,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local grid: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Grid",
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
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(Theme.sizes.gap + 4, Theme.sizes.gap + 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 6),
		}),
	})
	self._grid = grid

	-- once a second: the HUD tile's countdown, and the cards while the screen is open
	local clock = 0
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < 1 then
			return
		end
		clock = 0
		self:_refresh()
	end)

	return self :: TipJar
end

function TipJar.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._lureById)
	for _, lure in catalog.lures do
		self._lureById[lure.id] = lure
	end
	self._rows = catalog.tipJar or {}
	self:_build()
end

function TipJar.setJar(self: any, jar: TipJarLogic.Jar?)
	self._jar = jar
	table.clear(self._pending)
	self:_refresh()
end

function TipJar.setNight(self: any, night: boolean)
	self._night = night
	self:_refresh()
end

function TipJar.render(self: any, state: Types.PlayerState)
	self._income = state.incomePerSecond
	self._spin = state.spin
	self:_refresh()
end

function TipJar._build(self: any)
	for _, card in self._cards do
		card.claim:destroy()
		card.icon:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	for _, row: TipJarLogic.Row in self._rows do
		local frame: Frame = Create("Frame", {
			Name = "Gift" .. row.step,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			LayoutOrder = row.step,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		})
		local stroke: UIStroke = Create("UIStroke", {
			Color = Theme.modal.cardStroke,
			Thickness = Theme.sizes.stroke,
			Parent = frame,
		})
		local when = text({
			Name = "When",
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Text = ("%d min"):format(row.minutes),
			-- a spin badge takes the right of the top line, so the minutes move left
			TextXAlignment = if (row.spins or 0) > 0
				then Enum.TextXAlignment.Left
				else Enum.TextXAlignment.Center,
			Parent = frame,
		})
		local lure: Types.LureDef? = if row.lureId then self._lureById[row.lureId] else nil
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(ICON, ICON),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 22),
		})
		if lure then
			icon:set(lure.asset, Theme.foodIcons[lure.id] or Theme.icons.food, lure.attracts)
		else
			icon:set(nil, COIN_GLYPH, "Legendary")
		end
		local prize = text({
			Name = "Prize",
			Position = UDim2.fromOffset(6, 22 + ICON + 2),
			Size = UDim2.new(1, -12, 0, 20),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Parent = frame,
		})
		Outline.text(prize, 1)
		local waiting = text({
			Name = "Wait",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 26),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.line,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.modal.subtext,
			Parent = frame,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = waiting })
		local spinBadge: TextLabel? = nil
		if (row.spins or 0) > 0 then
			local badge = text({
				Name = "Spin",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(70, 18),
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.colors.berry,
				FontFace = Theme.fonts.display,
				TextSize = Theme.sizes.textTiny,
				TextColor3 = Theme.colors.white,
				ZIndex = 2,
				Parent = frame,
			})
			Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
			spinBadge = badge
		end
		local step = row.step
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
				self._pending[step] = os.clock()
				self._callbacks.claim(step)
				self:_refresh()
			end,
		})
		self._cards[step] = {
			frame = frame,
			stroke = stroke,
			when = when,
			icon = icon,
			lure = lure,
			prize = prize,
			waiting = waiting,
			claim = claim,
			spinBadge = spinBadge,
		}
	end
	self:_refresh()
end

function TipJar._refresh(self: any)
	local now = Workspace:GetServerTimeNow()
	local jar: TipJarLogic.Jar? = self._jar
	local views = TipJarLogic.views(self._rows, jar, now)
	local summary = TipJarLogic.summary(views)
	self._callbacks.status(if jar and #self._rows > 0 then summary else nil)
	if not self.frame.Visible then
		return
	end
	local dayRate = TipJarLogic.dayRate(self._income, self._night, NIGHT_SHARE)
	for _, view in views do
		local row = view.row
		local card = self._cards[row.step]
		if not card then
			continue
		end
		if row.kind == "coins" then
			card.prize.Text = Format.money(TipJarLogic.coins(row, dayRate))
		else
			local lure: Types.LureDef? = card.lure
			card.prize.Text = ("%d %s"):format(
				row.count or 1,
				if lure then lure.name else (row.lureId or "food")
			)
		end
		local pressedAt: number? = self._pending[row.step]
		local pending = pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
		local claimed = view.state == "claimed"
		local ready = view.state == "ready"
		card.claim.instance.Visible = ready
		card.claim:setEnabled(not pending)
		card.claim:setText(if pending then "..." else "Claim")
		card.waiting.Visible = not ready
		card.waiting.Text = if claimed then "✓ Claimed" else TipJarLogic.clock(view.remaining)
		card.waiting.TextColor3 = if claimed then Theme.colors.goodDark else Theme.modal.subtext
		card.stroke.Color = if ready then Theme.colors.good else Theme.modal.cardStroke
		card.stroke.Thickness = Theme.sizes.stroke + (if ready then 1 else 0)
		card.frame.BackgroundTransparency = if claimed then 0.35 else 0
		local badge: TextLabel? = card.spinBadge
		if badge then
			local spin: Types.SpinState? = self._spin
			local full = spin ~= nil and spin.banked >= SPIN_BANK_CAP
			badge.Visible = not claimed
			badge.Text = if full
				then "Spins full"
				else ("%s +%d spin%s"):format(
					Theme.icons.spin,
					row.spins or 1,
					if (row.spins or 1) == 1 then "" else "s"
				)
			badge.BackgroundColor3 = if full then Theme.colors.disabledDark else Theme.colors.berry
		end
	end

	-- the strip: minutes played and the next gift
	local elapsed = if jar then math.max(0, now - jar.sessionStartedAt) else 0
	local played = "Played " .. TipJarLogic.clock(elapsed)
	local nextIn: number? = summary.nextIn
	if summary.left == 0 then
		self._played.Text = played .. "  ·  every gift claimed, see you next time!"
		self._fill.Size = UDim2.fromScale(1, 1)
	elseif summary.ready > 0 then
		self._played.Text = played
			.. ("  ·  %d gift%s ready!"):format(
				summary.ready,
				if summary.ready == 1 then "" else "s"
			)
		self._fill.Size = UDim2.fromScale(1, 1)
	elseif nextIn ~= nil then
		self._played.Text = played .. "  ·  next gift in " .. TipJarLogic.clock(nextIn)
		-- the bar fills from the last gift's minute to the next one's
		local previous, upcoming = 0, 0
		for _, view in views do
			local at = view.row.minutes * 60
			if view.state == "waiting" then
				upcoming = at
				break
			end
			previous = at
		end
		local span = math.max(1, upcoming - previous)
		self._fill.Size = UDim2.fromScale(math.clamp((elapsed - previous) / span, 0, 1), 1)
	else
		self._played.Text = played
		self._fill.Size = UDim2.fromScale(0, 1)
	end
end

function TipJar.destroy(self: any)
	self._tick:Disconnect()
	for _, card in self._cards do
		card.claim:destroy()
		card.icon:destroy()
	end
	table.clear(self._cards)
	self._panel:destroy()
end

return TipJar
