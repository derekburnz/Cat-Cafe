--!strict
-- Spin Wheel window (F49, data-model section 11c, areas-and-stations B3), like Pet Simulator 99's wheel: the
-- "Spin" prompt on the plaza's wheel station opens it. On the left the wheel: six round prize tiles on a cream disc,
-- split by spokes, with the paw pointer at the top and rim lights that blink while it turns. On the right every
-- slice's prize and chance, "Spins: n", the countdown to the next free spin and a big Spin button.
--
-- Spin fires events.spinWheel. The server picks the slice and pays at once, then UI.spin.result(slice, amount)
-- turns the wheel for SpinCooldownSeconds and stops it in the middle of that slice with a burst. It slows at a
-- steady rate, so it is still moving briskly when it crosses into the prize's slice and never crawls past a bigger
-- prize or stops on an edge (reviewer N127). Slice 0 means refused, and the line under the button says why. The
-- button stays off until the wheel has landed. Walking out of range closes the window (N132); a prize that lands
-- while it is closed comes up as a toast. Spins are free only: nothing here mentions Robux (monetization-policy,
-- N126). The sums live in Components/SpinLogic.
--
-- The wheel turns by moving the tiles round the hub and turning each spoke about its own middle, so the prizes stay
-- upright and readable while it spins.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CrateLogic = require(script.Parent.Parent.Components.CrateLogic)
local Create = require(script.Parent.Parent.Components.Create)
local FishCoin = require(script.Parent.Parent.Components.FishCoin)
local Format = require(script.Parent.Parent.Components.Format)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Sound = require(script.Parent.Parent.Components.Sound)
local SpinLogic = require(script.Parent.Parent.Components.SpinLogic)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	spin: () -> (),
	status: (freeDue: boolean) -> (), -- every second, for the Plaza marker's red dot
	toast: (text: string) -> (), -- a prize that lands while the window is closed
	close: () -> (),
}

export type SpinWheel = {
	frame: Frame,
	setCatalog: (self: SpinWheel, catalog: Types.Catalog) -> (),
	setNight: (self: SpinWheel, night: boolean) -> (),
	render: (self: SpinWheel, state: Types.PlayerState) -> (),
	result: (self: SpinWheel, slice: number, amount: number) -> (),
	destroy: (self: SpinWheel) -> (),
}

type Tile = {
	holder: Frame,
	stroke: UIStroke,
	icon: ItemIcon.ItemIcon,
	row: Types.SpinRow,
	crate: string?, -- the crate a crate slice shows now ("highest" resolved for the player's tier)
}

type Turn = {
	from: number,
	to: number,
	start: number,
	duration: number,
	index: number,
	amount: number,
}

local WHEEL_SHARE = 0.47 -- of the window's width
local FACE = 0.9 -- the turning face inside the caramel rim
local TILE = 0.29 -- tile size, of the face
local RADIUS = 0.34 -- tile middles from the hub, of the face
local SPOKE = 3
local RIM_LIGHTS = 12
local ROW_HEIGHT = 28
local TURNS = 5
local SPIN_SECONDS: number = Config.SpinCooldownSeconds or 4 -- the server's cooldown is the animation's length
local CALM_SECONDS = 1.5 -- with Reduced Motion on: a shorter spin, two turns
local CALM_TURNS = 2
local PENDING_SECONDS = 5 -- a pressed Spin waits this long for SpinResult before it can be pressed again
local RANGE: number = Config.SpinStationRange or 14
local CLOSE_SLACK = 2 -- studs past the server's range before the window closes
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6
local COIN_GLYPH = "💰"
local TAG = "SpinWheel"

-- The Cozy Cream pastels, one per slice in wheel order
local SLICE_COLORS = {
	Color3.fromHex("FFE3A3"),
	Color3.fromHex("BFE8DC"),
	Color3.fromHex("FFD1B0"),
	Color3.fromHex("C9DEFF"),
	Color3.fromHex("F7C6D9"),
	Color3.fromHex("E2D0F7"),
}

local SpinWheel = {}
SpinWheel.__index = SpinWheel

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

local function circle(props: { [string]: any }): Frame
	local frame: Frame = Create("Frame", props)
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
	return frame
end

-- Studs from the player's character to the nearest wheel station, or nil when either is missing.
local function stationDistance(): number?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local from = (root :: BasePart).Position
	local best: number? = nil
	for _, station in CollectionService:GetTagged(TAG) do
		if station:IsA("Model") or station:IsA("BasePart") then
			local distance = ((station :: PVInstance):GetPivot().Position - from).Magnitude
			if best == nil or distance < best then
				best = distance
			end
		end
	end
	return best
end

function SpinWheel.new(callbacks: Callbacks): SpinWheel
	local self = setmetatable({}, SpinWheel) :: any
	self._callbacks = callbacks
	self._rows = {} :: { Types.SpinRow }
	self._lureById = {} :: { [string]: Types.LureDef }
	self._crates = {} :: { [string]: CrateLogic.Crate }
	self._areas = {} :: { CrateLogic.Area }
	self._tier = 1
	self._spin = nil :: Types.SpinState?
	self._income = 0
	self._night = false
	self._tiles = {} :: { Tile }
	self._spokes = {} :: { Frame }
	self._chances = {} :: { { prize: TextLabel, chance: TextLabel } }
	self._angle = 0
	self._slot = 1
	self._turn = nil :: Turn?
	self._landed = nil :: number?
	self._pressedAt = nil :: number? -- os.clock() of a Spin press still waiting for SpinResult
	self._readyAt = 0 -- os.clock() when the server's cooldown has passed (a calm spin lands before it)

	local panel = Panel.new({
		name = "SpinWheel",
		title = "Spin Wheel",
		subtitle = "A free spin every day · every prize shows its chance",
		color = Theme.colors.berry,
		icon = Theme.icons.spin,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(700, 470), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- the wheel: a caramel rim with lights, the turning face, the hub and the pointer
	local holder: Frame = Create("Frame", {
		Name = "Wheel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(WHEEL_SHARE, 1),
		Parent = panel.content,
	})
	local rim = circle({
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.new(1, -12, 1, -24),
		BackgroundColor3 = Theme.colors.caramel,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = rim })
	Outline.border(rim, Theme.sizes.outline, Theme.colors.outline)
	self._lights = {} :: { Frame }
	for index = 1, RIM_LIGHTS do
		local theta = math.rad((index - 0.5) * 360 / RIM_LIGHTS)
		table.insert(
			self._lights,
			circle({
				Name = "Light" .. index,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(
					0.5 + 0.475 * math.sin(theta),
					0.5 - 0.475 * math.cos(theta)
				),
				Size = UDim2.fromScale(0.045, 0.045),
				BackgroundColor3 = Theme.colors.gold,
				BorderSizePixel = 0,
				Parent = rim,
			})
		)
	end
	local face = circle({
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(FACE, FACE),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Parent = rim,
	})
	Outline.border(face, Theme.sizes.stroke, Theme.colors.caramelDark)
	self._face = face
	local hub = circle({
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.17, 0.17),
		BackgroundColor3 = Theme.colors.caramel,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = face,
	})
	Outline.border(hub, Theme.sizes.stroke, Theme.colors.outline)
	text({
		Name = "Paw",
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🐾",
		ZIndex = 3,
		Parent = hub,
	})
	local pointer = text({
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromOffset(44, 44),
		FontFace = Theme.fonts.display,
		TextSize = 40,
		TextColor3 = Theme.colors.red,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = "▼",
		ZIndex = 5,
		Parent = rim,
	})
	Outline.text(pointer, Theme.sizes.textOutline)

	-- the side: chances, spins, the free spin countdown, the button and the result line
	local side: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Side",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(WHEEL_SHARE, Theme.sizes.gap, 0, 0),
		Size = UDim2.new(1 - WHEEL_SHARE, -Theme.sizes.gap, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
	})
	text({
		Name = "ChancesTitle",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Text = "Prizes and chances",
		Parent = side,
	})
	self._chanceList = Create("Frame", {
		Name = "Chances",
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = side,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	self._spinsLabel = text({
		Name = "Spins",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = side,
	})
	self._freeLabel = text({
		Name = "Free",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Parent = side,
	})
	self._button = Button.new({
		name = "Spin",
		text = "Spin!",
		icon = Theme.icons.spin,
		style = "gold",
		size = UDim2.new(1, 0, 0, 56),
		textSize = Theme.sizes.textLarge + 2,
		layoutOrder = 5,
		parent = side,
		onClick = function()
			self:_press()
		end,
	})
	self._message = text({
		Name = "Message",
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = side,
	})

	-- every frame while turning; four times a second the range check; once a second the counts and the dot
	local rangeClock, clock = 0, 1
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		if self._turn then
			self:_step()
		end
		rangeClock += dt
		if rangeClock >= 0.25 then
			rangeClock = 0
			self:_checkRange()
		end
		clock += dt
		if clock >= 1 then
			clock = 0
			self:_refresh()
		end
	end)

	return self :: SpinWheel
end

function SpinWheel.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._lureById)
	for _, lure in catalog.lures do
		self._lureById[lure.id] = lure
	end
	self._crates = CrateLogic.byId(catalog.crates)
	self._areas = (catalog.areas or {}) :: any
	self._rows = catalog.spinWheel or {}
	self:_build()
end

function SpinWheel.setNight(self: any, night: boolean)
	self._night = night
	self:_refresh()
end

function SpinWheel.render(self: any, state: Types.PlayerState)
	self._spin = state.spin
	self._income = state.incomePerSecond
	if state.tier ~= self._tier then
		self._tier = state.tier
		for _, tile: Tile in self._tiles do
			self:_paintCrate(tile)
		end
	end
	self:_refresh()
end

-- The crate id a crate slice pays this player now (F54: "highest" is the crate of their highest open area).
function SpinWheel._crateOf(self: any, row: Types.SpinRow): string
	return CrateLogic.resolve(
		row.crate or CrateLogic.HIGHEST,
		self._crates,
		self._areas,
		self._tier
	)
end

-- A crate slice's picture, again whenever a new area changes which crate it pays.
function SpinWheel._paintCrate(self: any, tile: Tile)
	if tile.row.kind ~= "crate" then
		return
	end
	local id = self:_crateOf(tile.row)
	if id == tile.crate then
		return
	end
	tile.crate = id
	local crate: CrateLogic.Crate? = self._crates[id]
	tile.icon:set(
		if crate then crate.asset else nil,
		Theme.icons.crate,
		if CrateLogic.isGolden(id, crate) then "Legendary" else "Rare"
	)
end

-- SpinResult from the server: turn to `slice` and show what `amount` paid, or say why a 0 was refused.
function SpinWheel.result(self: any, slice: number, amount: number)
	self._pressedAt = nil
	local now = Workspace:GetServerTimeNow()
	local index = SpinLogic.indexOf(self._rows, slice)
	if slice <= 0 or index == nil then
		if slice > 0 then
			self:_say("You won a prize!", Theme.colors.goodDark) -- a slice this catalog does not know
		else
			self:_say(SpinLogic.refusal(self._spin, now), Theme.colors.warnDark)
			Sound.play("uiError")
		end
		self:_refresh()
		return
	end
	self:_light(nil)
	self:_say("", Theme.modal.text)
	local calm = GuiService.ReducedMotionEnabled
	self._turn = {
		from = self._angle,
		to = SpinLogic.landing(self._angle, index, #self._rows, if calm then CALM_TURNS else TURNS),
		start = os.clock(),
		duration = if calm then CALM_SECONDS else SPIN_SECONDS,
		index = index,
		amount = amount,
	}
	self._readyAt = os.clock() + SPIN_SECONDS
	Sound.play("uiSpinStart")
	self:_refresh()
end

function SpinWheel._build(self: any)
	for _, tile in self._tiles do
		tile.icon:destroy()
		tile.holder:Destroy()
	end
	table.clear(self._tiles)
	for _, spoke in self._spokes do
		spoke:Destroy()
	end
	table.clear(self._spokes)
	for _, row in self._chances do
		(row.prize.Parent :: Instance):Destroy()
	end
	table.clear(self._chances)
	self._landed = nil

	for index, row: Types.SpinRow in self._rows do
		table.insert(
			self._spokes,
			Create("Frame", {
				Name = "Spoke" .. index,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, SPOKE, 0.5, 0),
				BackgroundColor3 = Theme.colors.line,
				BorderSizePixel = 0,
				ZIndex = 1,
				Parent = self._face,
			})
		)
		local color = SLICE_COLORS[(index - 1) % #SLICE_COLORS + 1]
		local holder = circle({
			Name = "Slice" .. row.slice,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(TILE, TILE),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = self._face,
		})
		local stroke = Outline.border(holder, Theme.sizes.stroke, Theme.modal.cardStroke)
		local lure: Types.LureDef? = if row.lureId then self._lureById[row.lureId] else nil
		local icon = ItemIcon.new({
			parent = holder,
			size = UDim2.fromScale(0.6, 0.6),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0.06),
		})
		local tile: Tile = { holder = holder, stroke = stroke, icon = icon, row = row, crate = nil }
		if row.kind == "fish" then
			icon:set(nil, "", "Legendary")
			FishCoin.fill(icon.frame, 0.66, 2)
		elseif row.kind == "crate" then
			self:_paintCrate(tile)
		elseif lure then
			icon:set(lure.asset, Theme.foodIcons[lure.id] or Theme.icons.food, lure.attracts)
		else
			icon:set(nil, COIN_GLYPH, "Legendary")
		end
		local chance = text({
			Name = "Chance",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.98),
			Size = UDim2.fromScale(1, 0.32),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = SpinLogic.chance(self._rows, row),
			ZIndex = 2,
			Parent = holder,
		})
		Create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8, Parent = chance })
		Outline.text(chance, 1.5)
		if row.kind ~= "coins" and (row.count or 1) > 1 then
			local count = text({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1.02, -0.02),
				Size = UDim2.fromScale(0.42, 0.3),
				FontFace = Theme.fonts.display,
				TextScaled = true,
				TextColor3 = Theme.colors.white,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "x" .. (row.count or 1),
				ZIndex = 3,
				Parent = holder,
			})
			Create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8, Parent = count })
			Outline.text(count, 1.5)
		end
		table.insert(self._tiles, tile)

		-- the side list: a swatch in the slice's colour, the prize and its chance
		local line: Frame = Create("Frame", {
			Name = "Slice" .. row.slice,
			LayoutOrder = index,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Parent = self._chanceList,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
			Create("UIStroke", { Color = Theme.modal.cardStroke, Thickness = 1 }),
		})
		local swatch = circle({
			Name = "Swatch",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = line,
		})
		if row.kind == "fish" then
			FishCoin.new({
				parent = swatch,
				size = ROW_HEIGHT - 14,
				position = UDim2.fromScale(0.5, 0.56),
				anchorPoint = Vector2.new(0.5, 0.5),
			})
		else
			text({
				Name = "Glyph",
				Size = UDim2.fromScale(1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = if row.kind == "crate"
					then Theme.icons.crate
					elseif lure then Theme.foodIcons[lure.id] or Theme.icons.food
					else COIN_GLYPH,
				Parent = swatch,
			})
		end
		local prize = text({
			Name = "Prize",
			Position = UDim2.fromOffset(ROW_HEIGHT + 4, 0),
			Size = UDim2.new(1, -(ROW_HEIGHT + 4 + 58), 1, 0),
			FontFace = Theme.fonts.bodyBold,
			Parent = line,
		})
		local chanceText = text({
			Name = "Chance",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0, 54, 1, 0),
			FontFace = Theme.fonts.display,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = SpinLogic.chance(self._rows, row),
			Parent = line,
		})
		table.insert(self._chances, { prize = prize, chance = chanceText })
	end
	self:_setAngle(self._angle)
	self:_refresh()
end

-- Puts the wheel at `angle` degrees clockwise: each tile round the hub, each spoke between two tiles.
function SpinWheel._setAngle(self: any, angle: number)
	self._angle = angle
	local count = #self._tiles
	if count == 0 then
		return
	end
	local size = 360 / count
	for index, tile: Tile in self._tiles do
		local theta = math.rad((index - 1) * size + angle)
		tile.holder.Position =
			UDim2.fromScale(0.5 + RADIUS * math.sin(theta), 0.5 - RADIUS * math.cos(theta))
	end
	for index, spoke: Frame in self._spokes do
		local edge = (index - 0.5) * size + angle
		local theta = math.rad(edge)
		spoke.Position = UDim2.fromScale(0.5 + 0.25 * math.sin(theta), 0.5 - 0.25 * math.cos(theta))
		spoke.Rotation = edge
	end
end

-- One frame of a spin: ease toward the landing angle, tick and blink as each slice passes the pointer.
function SpinWheel._step(self: any)
	local turn: Turn = self._turn
	local t = math.clamp((os.clock() - turn.start) / turn.duration, 0, 1)
	-- Quad Out slows at a steady rate: no long crawl over the last slice edge (N127)
	local eased = TweenService:GetValue(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self:_setAngle(turn.from + (turn.to - turn.from) * eased)
	local slot = SpinLogic.slotAt(self._angle, #self._tiles)
	if slot ~= self._slot then
		self._slot = slot
		Sound.play("uiSpinTick")
		self:_blink(slot)
	end
	if t >= 1 then
		self._turn = nil
		self:_land(turn)
	end
end

function SpinWheel._blink(self: any, phase: number?)
	for index, light: Frame in self._lights do
		local on = phase == nil or (index + phase) % 2 == 0
		light.BackgroundColor3 = if on then Theme.colors.gold else Theme.colors.paper
	end
end

-- The wheel has stopped in the middle of the paid slice: pop it, burst, say the prize.
function SpinWheel._land(self: any, turn: Turn)
	self:_setAngle(turn.to % 360)
	self._slot = SpinLogic.slotAt(self._angle, #self._tiles)
	self:_blink(nil)
	self:_light(turn.index)
	local row: Types.SpinRow? = self._rows[turn.index]
	local won = if row
		then "You won " .. self:_prize(row, turn.amount) .. "!"
		else "You won a prize!"
	self:_say(won, Theme.colors.goodDark)
	local tile: Tile? = self._tiles[turn.index]
	if tile and self.frame.Visible then
		Tween.popIn(tile.holder, 1.35)
		local burst = circle({
			Name = "Burst",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = tile.holder.Position,
			Size = tile.holder.Size,
			BackgroundColor3 = Theme.colors.gold,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = self._face,
		})
		Tween.to(burst, Tween.RISE, {
			Size = UDim2.fromScale(TILE * 2.2, TILE * 2.2),
			BackgroundTransparency = 1,
		}).Completed
			:Once(function()
				burst:Destroy()
			end)
	end
	Sound.play("uiSpinWin")
	if not self.frame.Visible then
		self._callbacks.toast("Spin Wheel: " .. won)
	end
	self:_refresh()
end

-- Rings the landed tile in gold until the next spin; nil clears it.
function SpinWheel._light(self: any, index: number?)
	self._landed = index
	for each, tile: Tile in self._tiles do
		local lit = each == index
		tile.stroke.Color = if lit then Theme.colors.gold else Theme.modal.cardStroke
		tile.stroke.Thickness = if lit then 4 else Theme.sizes.stroke
	end
end

function SpinWheel._say(self: any, message: string, color: Color3)
	self._message.Text = message
	self._message.TextColor3 = color
end

-- "3 Tuna", "$1,200", "4 golden fish", "1 Woods Crate"; `amount` is what SpinResult paid, else the estimate at the
-- current day rate.
function SpinWheel._prize(self: any, row: Types.SpinRow, amount: number?): string
	if row.kind == "coins" then
		local dayRate = TipJarLogic.dayRate(self._income, self._night, NIGHT_SHARE)
		local coins = if amount and amount > 0 then amount else SpinLogic.coins(row, dayRate)
		return Format.money(coins)
	end
	local count = if amount and amount > 0 then amount else row.count or 1
	if row.kind == "fish" then
		return ("%s golden fish"):format(Format.short(count))
	elseif row.kind == "crate" then
		local id = self:_crateOf(row)
		return ("%d %s"):format(count, CrateLogic.name(id, self._crates[id]))
	end
	local lure: Types.LureDef? = if row.lureId then self._lureById[row.lureId] else nil
	return ("%d %s"):format(count, if lure then lure.name else (row.lureId or "food"))
end

function SpinWheel._press(self: any)
	if self._turn or self._pressedAt or os.clock() < self._readyAt then
		return
	end
	self._pressedAt = os.clock()
	self:_say("", Theme.modal.text)
	self._callbacks.spin()
	self:_refresh()
end

-- N132: walking away from the wheel closes the window, so a press out of range cannot happen.
function SpinWheel._checkRange(self: any)
	if not self.frame.Visible then
		return
	end
	local distance = stationDistance()
	if distance and distance > RANGE + CLOSE_SLACK then
		self._callbacks.close()
	end
end

function SpinWheel._refresh(self: any)
	local now = Workspace:GetServerTimeNow()
	local spin: Types.SpinState? = self._spin
	self._callbacks.status(spin ~= nil and #self._rows > 0 and SpinLogic.freeDue(spin, now))
	if self._pressedAt and os.clock() - self._pressedAt >= PENDING_SECONDS then
		self._pressedAt = nil
		self:_say("The wheel did not answer. Try again!", Theme.colors.warnDark)
	end
	if not self.frame.Visible then
		return
	end
	for index, row in self._rows do
		local line = self._chances[index]
		if line then
			line.prize.Text = self:_prize(row, nil)
		end
	end

	local spins = SpinLogic.spins(spin, now)
	local banked = if spin then math.max(0, math.floor(spin.banked)) else 0
	self._spinsLabel.Text = ("Spins: %d"):format(spins)
	local freeLine = if SpinLogic.freeDue(spin, now)
		then "Free spin ready!"
		else "Next free spin in " .. SpinLogic.wait(SpinLogic.nextFreeIn(spin, now))
	if banked > 0 then
		freeLine ..= ("  ·  %d saved"):format(banked)
	end
	self._freeLabel.Text = freeLine
	self._freeLabel.TextColor3 = if SpinLogic.freeDue(spin, now)
		then Theme.colors.goodDark
		else Theme.modal.subtext

	local turning = self._turn ~= nil or os.clock() < self._readyAt
	local waiting = self._pressedAt ~= nil
	self._button:setEnabled(not turning and not waiting and spins > 0 and #self._rows > 0)
	self._button:setText(
		if turning
			then "Spinning..."
			elseif waiting then "..."
			elseif spins > 0 then "Spin!"
			else "No spins"
	)
end

function SpinWheel.destroy(self: any)
	self._tick:Disconnect()
	for _, tile in self._tiles do
		tile.icon:destroy()
	end
	table.clear(self._tiles)
	self._button:destroy()
	self._panel:destroy()
end

return SpinWheel
