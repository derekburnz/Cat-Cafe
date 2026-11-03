--!strict
-- Tip Jar screen (F47, data-model section 11b): the twelve free playtime gifts of this session, like the Free
-- Gifts grid in Pet Simulator 99. A strip on top says how long you have played and when the next gift opens;
-- each card shows when it opens, the prize as pictures with amounts (Components/PrizeChips: coins from your day
-- rate, foods, golden fish, crates, spins, potions) and a green Claim button once it is ready. Opened from the Gifts
-- tile in the HUD's top-right icon row. The sums live in Components/TipJarLogic; the jar resets when the player
-- leaves, which the subtitle says. A one-prize gift that also banks a Spin Wheel spin (F49, step 11) wears a
-- "+1 spin" badge, or "Spins full" while the bank is at SpinBankCap, since the server then drops the spin and pays
-- the rest. F68 (round 4 Q10): the 60 and 120 minute gifts pay several things, so their cards are wider and gold,
-- "Big gift" and "Best gift", with every prize as a picture (spins too, reading "Full" when the bank is full).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	claim: (step: number) -> (),
	-- Claim all (Derek 2026-10-28: "more claim all buttons needed so many reward pop ups"): every ready gift in one
	-- ClaimAll("tipjar"), one toast; shown once shared Config.TipJarClaimAll says the server has it
	claimAll: (() -> ())?,
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
local GAP = Theme.sizes.gap + 4
local ICON = 52
local BIG_ICON = 46 -- the pictures on a big gift's card
local BIG_FILL = PAL.goldCard
local STRIP_HEIGHT = 52
-- A pressed Claim reads "Claiming" until TipJarState answers, or this long, then it can be pressed again. The
-- server takes one ClaimTipJar a second and drops the rest unanswered, so after any claim every Claim waits
-- CLAIM_GAP before it lights again (Derek 2026-10-27: a quick second claim sat on "..." until the old 3 s ran out).
local PENDING_SECONDS = 1.5
local CLAIM_GAP = 1.1
local CLAIM_ALL_W = 140
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6
local SPIN_BANK_CAP: number = Config.SpinBankCap or 20

local TipJar = {}
TipJar.__index = TipJar

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

function TipJar.new(callbacks: Callbacks): TipJar
	local self = setmetatable({}, TipJar) :: any
	self._callbacks = callbacks
	self._rows = {} :: { TipJarLogic.Row }
	self._catalog = nil :: Types.Catalog?
	self._jar = nil :: TipJarLogic.Jar?
	self._income = 0
	self._night = false
	self._spin = nil :: Types.SpinState?
	self._cards = {} :: { [number]: any }
	self._pending = {} :: { [number]: number } -- step -> os.clock() of the press
	self._lastClaim = -math.huge -- os.clock() of the latest press on any Claim

	local panel = Panel.new({
		dark = true, -- #1028
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

	-- the strip: time played, the next gift, and a bar filling toward it; on a phone tall enough for Claim all's tap
	local claimH = Scale.tapHeight(STRIP_HEIGHT - 11, Theme.sizes.buttonDepth)
	local stripH = math.max(STRIP_HEIGHT, claimH + 12)
	local strip: Frame = Create("Frame", {
		Name = "Strip",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, stripH),
		Parent = panel.content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
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
		BackgroundColor3 = PAL.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 10),
		Parent = strip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._track = track
	self._claimAll = Button.new({
		name = "ClaimAll",
		text = "Claim all",
		style = "primary",
		size = UDim2.fromOffset(CLAIM_ALL_W, claimH),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = strip,
		onClick = function()
			self:_pressAll()
		end,
	})
	self._claimAll.instance.Visible = false
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
		Position = UDim2.fromOffset(0, stripH + Theme.sizes.gap + 2),
		Size = UDim2.new(1, 0, 1, -(stripH + Theme.sizes.gap + 2)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		-- a wrapping row of cards: the bigger gifts are wider (F68), so not a grid; each card's cell carries the gap
		-- under it
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
	self._catalog = catalog
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
		card.chips:destroy()
		card.cell:Destroy()
	end
	table.clear(self._cards)
	local catalog: Types.Catalog? = self._catalog
	for _, row: TipJarLogic.Row in self._rows do
		local prize = TipJarLogic.prize(row)
		local size = TipJarLogic.size(prize)
		local big = size ~= "small"
		local spins = prize.spins or 0
		-- a small card shows its spins as the badge; bigger gifts show them as a picture among the rest
		local shown: TipJarLogic.Prize = prize
		if not big and spins > 0 then
			local copy = table.clone(prize)
			copy.spins = nil
			shown = copy
		end
		local cell: Frame = Create("Frame", {
			Name = "Gift" .. row.step,
			BackgroundTransparency = 1,
			Size = if size == "full"
				then UDim2.new(1, 0, 0, CARD.Y + GAP)
				elseif big then UDim2.fromOffset(CARD.X * 2 + GAP, CARD.Y + GAP)
				else UDim2.fromOffset(CARD.X, CARD.Y + GAP),
			LayoutOrder = row.step,
			Parent = self._grid,
		})
		local frame: Frame = Create("Frame", {
			Name = "Card",
			BackgroundColor3 = if big then BIG_FILL else PAL.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, CARD.Y),
			Parent = cell,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		})
		local stroke: UIStroke = Create("UIStroke", {
			Color = PAL.cardStroke,
			Thickness = Theme.sizes.stroke,
			Parent = frame,
		})
		local minutes = ("%d min"):format(row.minutes)
		local when = text({
			Name = "When",
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = if big then Theme.fonts.display else Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = if big then PAL.gold else PAL.subtext,
			Text = if size == "full"
				then minutes .. "  ·  Best gift"
				elseif big then minutes .. "  ·  Big gift"
				else minutes,
			-- a spin badge takes the right of the top line, so the minutes move left
			TextXAlignment = if not big and spins > 0
				then Enum.TextXAlignment.Left
				else Enum.TextXAlignment.Center,
			Parent = frame,
		})
		local chips = PrizeChips.new({
			textColor = PAL.text, -- light words on the dark window (#1028)
			parent = frame,
			tile = if big then BIG_ICON else ICON,
			textSize = Theme.sizes.textBody,
			name = "Prize",
			position = UDim2.new(0.5, 0, 0, 24),
			anchorPoint = Vector2.new(0.5, 0),
			fitTo = frame,
			fitPad = 12,
		})
		if catalog then
			chips:setCatalog(catalog)
		end
		local waiting = text({
			Name = "Wait",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 26),
			BackgroundTransparency = 0,
			BackgroundColor3 = PAL.line,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = waiting })
		local spinBadge: TextLabel? = nil
		if not big and spins > 0 then
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
				local now = os.clock()
				if now - self._lastClaim < CLAIM_GAP then
					return
				end
				self._lastClaim = now
				self._pending[step] = now
				self._callbacks.claim(step)
				self:_refresh()
				-- the buttons come back as soon as the waits are over, not on the next once-a-second tick
				task.delay(math.max(PENDING_SECONDS, CLAIM_GAP), function()
					if self._cards[step] then
						self:_refresh()
					end
				end)
			end,
		})
		self._cards[step] = {
			cell = cell,
			frame = frame,
			stroke = stroke,
			when = when,
			chips = chips,
			shown = shown,
			spins = spins,
			big = big,
			waiting = waiting,
			claim = claim,
			spinBadge = spinBadge,
		}
	end
	self:_refresh()
end

-- Claim all: every ready gift reads "Claiming" until TipJarState answers, then one ClaimAll.
function TipJar._pressAll(self: any)
	local callbacks: Callbacks = self._callbacks
	local claimAll = callbacks.claimAll
	if claimAll == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local marked = 0
	for _, view in TipJarLogic.views(self._rows, self._jar, now) do
		if view.state == "ready" then
			self._pending[view.row.step] = os.clock()
			marked += 1
		end
	end
	if marked == 0 then
		return
	end
	self._lastClaim = os.clock()
	claimAll()
	self:_refresh()
	task.delay(math.max(PENDING_SECONDS, CLAIM_GAP), function()
		if not self._destroyed then
			self:_refresh()
		end
	end)
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
	local spin: Types.SpinState? = self._spin
	local banked = if spin then spin.banked else nil
	local look: PrizeChips.Look = { dayRate = dayRate, spinsBanked = banked }
	for _, view in views do
		local row = view.row
		local card = self._cards[row.step]
		if not card then
			continue
		end
		card.chips:set(card.shown, look) -- coins follow the day rate; a full spin bank reads "Full"
		local pressedAt: number? = self._pending[row.step]
		local pending = pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
		local resting = os.clock() - self._lastClaim < CLAIM_GAP
		local claimed = view.state == "claimed"
		local ready = view.state == "ready"
		card.claim.instance.Visible = ready
		card.claim:setEnabled(not pending and not resting)
		card.claim:setText(if pending then "Claiming" else "Claim")
		card.waiting.Visible = not ready
		card.waiting.Text = if claimed then "✓ Claimed" else TipJarLogic.clock(view.remaining)
		card.waiting.TextColor3 = if claimed then PAL.good else PAL.subtext
		card.stroke.Color = if ready
			then Theme.colors.good
			elseif card.big then Theme.colors.goldDark
			else PAL.cardStroke
		card.stroke.Thickness = Theme.sizes.stroke + (if ready or card.big then 1 else 0)
		card.frame.BackgroundTransparency = if claimed then 0.35 else 0
		local badge: TextLabel? = card.spinBadge
		if badge then
			local full = banked ~= nil and banked >= SPIN_BANK_CAP
			local spins: number = card.spins
			local plural = if spins == 1 then "" else "s"
			badge.Visible = not claimed
			badge.Text = if full
				then "Spins full"
				else ("%s +%d spin%s"):format(Theme.icons.spin, spins, plural)
			badge.BackgroundColor3 = if full then Theme.colors.disabledDark else Theme.colors.berry
		end
	end

	-- Claim all, at the strip's right end while two or more gifts wait; the played line and bar make room
	local canAll = (Config :: any).TipJarClaimAll == true and self._callbacks.claimAll ~= nil
	local showAll = canAll and summary.ready >= 2
	local allPending = false
	for _, view in views do
		local pressedAt: number? = self._pending[view.row.step]
		if
			view.state == "ready"
			and pressedAt ~= nil
			and os.clock() - pressedAt < PENDING_SECONDS
		then
			allPending = true
		end
	end
	self._claimAll.instance.Visible = showAll
	self._claimAll:setEnabled(not allPending)
	self._claimAll:setText(
		if allPending then "Claiming" else ("Claim all (%d)"):format(summary.ready)
	)
	local room = if showAll then CLAIM_ALL_W + 12 else 0
	self._played.Size = UDim2.new(1, -28 - room, 0, 24)
	self._track.Size = UDim2.new(1, -28 - room, 0, 10)

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
	self._destroyed = true
	self._tick:Disconnect()
	self._claimAll:destroy()
	for _, card in self._cards do
		card.claim:destroy()
		card.chips:destroy()
	end
	table.clear(self._cards)
	self._panel:destroy()
end

return TipJar
