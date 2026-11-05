--!strict
-- Spin Wheel window (F49, data-model section 11c, areas-and-stations B3), like Pet Simulator 99's wheel: the
-- "Spin" prompt on the plaza's wheel station opens it. On the left the wheel: a bright wedge per slice (#1500: eight,
-- the two 0.5% jackpots narrow gold ones, as on the world wheel), each with the prize's picture and what it pays
-- ("$1,200", "x3"), split by spokes, with the paw pointer at the top
-- and rim lights that blink while it turns. On the right "Spins: n", the countdown to the next free spin, a big Spin
-- button and an Odds button. Derek 2026-10-28: "odds menu should be hidden until it is clicked and also the wheel
-- pictures should reflect whats possible", so the chances live only behind Odds.
--
-- Spin fires events.spinWheel. The server picks the slice and pays at once, then UI.spin.result(slice, amount)
-- turns the wheel for SpinCooldownSeconds and stops it in the middle of that slice with a burst. It slows at a
-- steady rate, so it is still moving briskly when it crosses into the prize's slice and never crawls past a bigger
-- prize or stops on an edge (reviewer N127). Slice 0 means refused, and the line under the button says why. The
-- button stays off until the wheel has landed, except as a free Skip while it turns (Derek 2026-10-30), and then
-- until the server's cooldown has passed. Walking out of range closes the window (N132); a prize that lands
-- while it is closed comes up as a toast. Spins are free only: nothing here mentions Robux (monetization-policy,
-- N126). The sums live in Components/SpinLogic. F69 (round 4 Q11): the Odds button opens a list of the slices
-- likeliest first, each with its prize picture, a bar and its chance, and the food prizes wear their grade gems.
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
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local SpinLogic = require(script.Parent.Parent.Components.SpinLogic)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	spin: () -> (),
	-- #1078 Use all: spends every saved spin in one go (SpinAll); no button without it
	spinAll: (() -> ())?,
	toast: (text: string) -> (), -- a prize that lands while the window is closed
	close: () -> (),
}

export type SpinWheel = {
	frame: Frame,
	setCatalog: (self: SpinWheel, catalog: Types.Catalog) -> (),
	setNight: (self: SpinWheel, night: boolean) -> (),
	render: (self: SpinWheel, state: Types.PlayerState) -> (),
	result: (self: SpinWheel, slice: number, amount: number) -> (),
	allResult: (
		self: SpinWheel,
		rolls: { { slice: number, amount: number } },
		totals: { SpinLogic.Total }
	) -> (),
	destroy: (self: SpinWheel) -> (),
}

type Tile = {
	holder: Frame,
	stroke: UIStroke,
	icon: ItemIcon.ItemIcon,
	row: Types.SpinRow,
	crate: string?, -- the crate a crate slice shows now ("highest" resolved for the player's tier)
	prize: TextLabel?, -- a row of the Odds list: its prize text, kept current with the day rate
	amount: TextLabel?, -- a wheel tile: what it pays ("$1,200", "x3"), kept current with the day rate
}

type Turn = {
	from: number,
	to: number,
	start: number,
	duration: number,
	index: number,
	amount: number,
	skippable: boolean, -- past SpinLogic.SKIP_AFTER, so the button is a Skip
}

local WHEEL_SHARE = 0.56 -- of the window's width; the side holds only the spins, Spin and Odds
local FACE = 0.88 -- the turning face inside the rim
local TILE = 0.3 -- a prize's picture and amount, of the face, at most: each tile is cut to TILE_FILL of the gap between
-- its wedge's edges at its radius, so tiles never touch (#1280: the $ bag crowded the x3 pill and the Epic gem sat on it)
local TILE_FILL = 0.92
local RADIUS = 0.32 -- prize middles from the hub, of the face
local NARROW_RADIUS = 0.39 -- #1500: a jackpot's narrow wedge holds its prize further out, where it is widest
local NARROW_PILL = 0.36 -- and its amount pill is taller for its smaller tile, so "x100" stays readable
local SPOKE = 5 -- the white divider between two wedges
-- The wedges (the user, 2026-11-04: "make the menu ui of the spin section much more satisfying and clean looking"): a
-- classic prize wheel, each slice a bright wedge. Roblox UI has no pie shape, so a wedge is a fan of thin bars from
-- the hub to the edge, WEDGE_STEP degrees apart. Each bar's long side lies on a ray and the bar reaches into its own
-- wedge (clockwise in the first half, back in the second), so no bar crosses a divider: a bar centred on its ray
-- would spill past it near the hub (Review-Agent, #1109). Its far side could only cross the wedge's other edge inside
-- 2 bar widths of the middle, under the hub.
local WEDGE_STEP = 4
-- The look of the wheel in the Town Square (assets/cat-cafe/blender/spinwheel.py; the user, 11-04: "make it look like
-- the wheel model that you can see in game"): a gold frame with warm bulbs, a gold hub with a pink cap, a pink pointer
local RIM_COLOR = Color3.fromHex("FFC94D") -- rarity_legend
local RIM_LIGHT_COLOR = Color3.fromHex("FFF4B0") -- sparkle, the lit bulbs
local HUB_COLOR = Color3.fromHex("FFC94D")
local LIGHT_OFF_COLOR = Color3.fromHex("D9A23A") -- a bulb between flashes, darker than the frame
local CAP_COLOR = Color3.fromHex("FF6B81") -- neon_pink, the hub's cap and the pointer
local RIM_LIGHTS = 16
local SPIN_HEIGHT = 64
local COUNT_BADGE = 56 -- the spins count's gold badge (#965)
local SIDE_PAD = 12 -- inside the side card on every edge, so no button's outline or lip is clipped (#965)
local ODDS_HEIGHT = 44 -- full width; it was 84 x 36 (Derek 2026-10-28: "a little squished"). Both grow on a phone.
local ODDS_ROW = 64
local ODDS_ICON = 48
local ODDS_CHANCE = 84 -- the chance column's width
local BACK_WIDTH = 96
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

-- The model's slices in wheel order (spinwheel.py SLICES, #1500): butter, mint, lilac, sky, blush, galaxy blue, and the
-- jackpots in gold_mid and gold_light
local SLICE_COLORS = {
	Color3.fromHex("F6DFA0"),
	Color3.fromHex("8FD3C1"),
	Color3.fromHex("C9B8E8"),
	Color3.fromHex("A8D8F0"),
	Color3.fromHex("E8A0A0"),
	Color3.fromHex("3B4C8C"),
}
local JACKPOT_COLORS = { Color3.fromHex("F2C14E"), Color3.fromHex("FBE49A") }

local SpinWheel = {}
SpinWheel.__index = SpinWheel

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
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
	self._oddsTiles = {} :: { Tile }
	self._spokes = {} :: { Frame }
	self._angle = 0
	self._slot = 1
	self._turn = nil :: Turn?
	self._landed = nil :: number?
	self._pressedAt = nil :: number? -- os.clock() of a Spin press still waiting for SpinResult
	self._readyAt = 0 -- os.clock() when the server's cooldown has passed (a calm spin lands before it)

	local panel = Panel.new({
		dark = true, -- #1028
		name = "SpinWheel",
		title = "Spin Wheel",
		subtitle = "A free spin every day · Odds shows every chance",
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
		BackgroundColor3 = RIM_COLOR,
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
				Size = UDim2.fromScale(0.04, 0.04),
				BackgroundColor3 = RIM_LIGHT_COLOR,
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
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Parent = rim,
	})
	Outline.border(face, Theme.sizes.outline, Theme.colors.outline)
	self._face = face
	-- the wedges turn with the wheel: one frame holds them all and takes the wheel's angle (_setAngle)
	self._bars = {} :: { { frame: Frame, base: number, side: number, width: number } }
	self._spans = {} :: { number } -- each slot's degrees (SpinLogic.spans)
	self._centres = {} :: { number } -- each slot's middle, from slot 1's
	self._radii = {} :: { number } -- each tile's distance from the hub, of the face
	self._wedges = Create("Frame", {
		Name = "Wedges",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = face,
	})
	local hub = circle({
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.19, 0.19),
		BackgroundColor3 = HUB_COLOR,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = face,
	})
	Outline.border(hub, Theme.sizes.outline, Theme.colors.outline)
	local cap = circle({
		Name = "Cap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.66),
		BackgroundColor3 = CAP_COLOR,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = hub,
	})
	Outline.border(cap, 2, Theme.colors.outline)
	text({
		Name = "Paw",
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🐾",
		ZIndex = 4,
		Parent = hub,
	})
	local pointer = text({
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromOffset(44, 44),
		FontFace = Theme.fonts.display,
		TextSize = 40,
		TextColor3 = CAP_COLOR,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Text = "▼",
		ZIndex = 5,
		Parent = rim,
	})
	Outline.text(pointer, Theme.sizes.textOutline)

	-- the side (#965, Derek: "the right side of spin menu is very plain", "buttons ... get cut off"): a card with the
	-- spins count in a big gold badge, the free spin line as a chip, Spin, Odds and the result line. Padded on every
	-- edge, as the scroller clips: buttons' outlines and lips once reached past its right and bottom edges.
	local side: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Side",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Position = UDim2.new(WHEEL_SHARE, Theme.sizes.gap, 0, 0),
		Size = UDim2.new(1 - WHEEL_SHARE, -Theme.sizes.gap, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, SIDE_PAD),
			PaddingBottom = UDim.new(0, SIDE_PAD + Theme.sizes.buttonDepth),
			PaddingLeft = UDim.new(0, SIDE_PAD),
			PaddingRight = UDim.new(0, SIDE_PAD + 6),
		}),
	})
	-- the spins count: a gold badge with the number, "Spins" beside it
	local count: Frame = Create("Frame", {
		Name = "Count",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, COUNT_BADGE),
		Parent = side,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local badge = circle({
		Name = "Badge",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(COUNT_BADGE, COUNT_BADGE),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Parent = count,
	})
	Outline.border(badge, Theme.sizes.outline, Theme.colors.outline)
	self._spinsCount = text({
		Name = "Number",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 30,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = badge,
	})
	Outline.text(self._spinsCount, Theme.sizes.textOutline)
	self._spinsLabel = text({
		Name = "Spins",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, COUNT_BADGE),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		TextTruncate = Enum.TextTruncate.None,
		Parent = count,
	})
	Outline.text(self._spinsLabel, 2)
	-- the free spin line as a chip
	local chip: Frame = Create("Frame", {
		Name = "FreeChip",
		LayoutOrder = 2,
		BackgroundColor3 = PAL.line,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		Parent = side,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 26) }),
	})
	self._freeChip = chip
	self._freeLabel = text({
		Name = "Free",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextTruncate = Enum.TextTruncate.None,
		Parent = chip,
	})
	self._button = Button.new({
		name = "Spin",
		text = "Spin!",
		icon = Theme.icons.spin,
		style = "gold",
		size = UDim2.new(1, 0, 0, Scale.tapHeight(SPIN_HEIGHT, Theme.sizes.buttonDepth)),
		textSize = Theme.sizes.textLarge + 2,
		layoutOrder = 3,
		parent = side,
		onClick = function()
			self:_press()
		end,
	})
	-- Use all and Odds share one row, so a phone's card holds them without scrolling (#1078)
	local actionH = Scale.tapHeight(ODDS_HEIGHT, Theme.sizes.buttonDepth)
	local actions: Frame = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, actionH),
		Parent = side,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._oddsButton = Button.new({
		name = "Odds",
		text = "Odds",
		icon = "📊",
		style = "secondary",
		size = UDim2.new(1, 0, 1, 0),
		textSize = Theme.sizes.textBody + 1,
		layoutOrder = 2,
		parent = actions,
		onClick = function()
			self:_showOdds(true)
		end,
	})
	-- #1078 Use all: under Spin, while two or more spins wait (SpinLogic.allText)
	self._allPending = nil :: number? -- os.clock() of a Use all press still waiting for SpinAllResult
	self._allButton = Button.new({
		name = "UseAll",
		text = "Use all",
		icon = Theme.icons.spin,
		style = "purple",
		size = UDim2.new(0.5, -4, 1, 0),
		textSize = Theme.sizes.textBody + 1,
		layoutOrder = 1,
		parent = actions,
		onClick = function()
			self:_pressAll()
		end,
	})
	self._allButton.instance.Visible = false
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

	-- the Odds list (F69), over the whole window until Back
	local backHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	local odds: Frame = Create("Frame", {
		Name = "OddsList",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Visible = false,
		Parent = panel.content,
	})
	self._odds = odds
	text({
		Name = "Title",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -(BACK_WIDTH + 16), 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Text = "Spin odds",
		Parent = odds,
	})
	text({
		Name = "Sub",
		Position = UDim2.fromOffset(4, 28),
		Size = UDim2.new(1, -(BACK_WIDTH + 16), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = "Every slice of the wheel, likeliest first. Together they make 100%.",
		Parent = odds,
	})
	self._oddsBack = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(BACK_WIDTH, backHeight),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -4, 0, 2),
		textSize = Theme.sizes.textBody,
		parent = odds,
		onClick = function()
			self:_showOdds(false)
		end,
	})
	self._oddsList = Create("ScrollingFrame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, backHeight + 10),
		Size = UDim2.new(1, 0, 1, -(backHeight + 10)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = odds,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 6),
		}),
	})
	-- closing the window puts the list away, so the wheel is what opens next time
	self.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not self.frame.Visible then
			self._odds.Visible = false
		end
	end)

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
	self._catalog = catalog
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
		for _, tile: Tile in self._oddsTiles do
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
	-- the clean crate symbol (#966: "too small"); the crate's model only if that picture were missing (#1242)
	tile.icon:set(
		if crate then crate.asset else nil,
		Theme.icons.crate,
		if CrateLogic.isGolden(id, crate) then "Legendary" else "Rare",
		ShopIcons.clean("Crate")
	)
end

-- SpinResult from the server: turn to `slice` and show what `amount` paid, or say why a 0 was refused.
-- Use all (#1078): one SpinAll; the button reads "..." until SpinAllResult or PENDING_SECONDS.
function SpinWheel._pressAll(self: any)
	local spinAll: (() -> ())? = self._callbacks.spinAll
	if spinAll == nil or self._turn ~= nil or self._pressedAt ~= nil then
		return
	end
	if self._allPending and os.clock() - self._allPending < PENDING_SECONDS then
		return
	end
	self._allPending = os.clock()
	self:_say("", PAL.text)
	spinAll()
	self:_refresh()
end

-- SpinAllResult(rolls, totals): the wheel turns to the last roll, then one card sums every prize (no popup per spin).
-- Empty lists mean refused (out of range, cooldown, no spins); the window says why as for one spin.
function SpinWheel.allResult(
	self: any,
	rolls: { { slice: number, amount: number } },
	totals: { SpinLogic.Total }
)
	self._allPending = nil
	if #rolls == 0 then
		self:result(0, 0)
		return
	end
	local last = rolls[#rolls]
	self:result(last.slice, last.amount)
	local count = #rolls
	local prize = SpinLogic.totalsPrize(totals)
	local wait = if GuiService.ReducedMotionEnabled then CALM_SECONDS else SPIN_SECONDS
	task.delay(wait, function()
		self:_showAllCard(count, prize)
	end)
end

-- The one results card over the window: "5 spins used", every prize as pictures with amounts, and Nice!.
function SpinWheel._showAllCard(self: any, count: number, prize: Types.IndexPrize)
	if self._allCard == nil then
		local cover: Frame = Create("Frame", {
			Name = "AllCard",
			Active = true,
			BackgroundColor3 = Theme.modal.backdrop,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
			Visible = false,
			Parent = self._panel.content,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		local card: Frame = Create("Frame", {
			Name = "Card",
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.86, 0, 0, 230),
			ZIndex = 21,
			Parent = cover,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
		Outline.border(card, Theme.sizes.outline, Theme.colors.gold)
		local title = text({
			Name = "Title",
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.new(1, 0, 0, 30),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge + 2,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 22,
			Parent = card,
		})
		Outline.text(title, 2)
		local holder: Frame = Create("Frame", {
			Name = "Prizes",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 50),
			Size = UDim2.new(1, -24, 0, 110),
			ZIndex = 22,
			Parent = card,
		})
		local chips = PrizeChips.new({
			parent = holder,
			tile = 52,
			wrap = true,
			size = UDim2.fromScale(1, 1),
			outlined = true,
		})
		local nice = Button.new({
			name = "Nice",
			text = "Nice!",
			style = "primary",
			size = UDim2.fromOffset(
				160,
				Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
			),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -10),
			zIndex = 22,
			parent = card,
			onClick = function()
				cover.Visible = false
			end,
		})
		self._allCard = { cover = cover, title = title, chips = chips, nice = nice }
	end
	local view = self._allCard
	view.title.Text = ("%d spin%s used"):format(count, if count == 1 then "" else "s")
	local catalog: Types.Catalog? = self._catalog
	if catalog then
		view.chips:setCatalog(catalog)
	end
	view.chips:set(prize, { dayRate = self._income })
	view.cover.Visible = true
	Tween.popIn(view.cover:FindFirstChild("Card") :: GuiObject, 0.9)
end

function SpinWheel.result(self: any, slice: number, amount: number)
	self._pressedAt = nil
	local now = Workspace:GetServerTimeNow()
	local index = SpinLogic.indexOf(self._rows, slice)
	if slice <= 0 or index == nil then
		if slice > 0 then
			self:_say("You won a prize!", PAL.good) -- a slice this catalog does not know
		else
			self:_say(SpinLogic.refusal(self._spin, now), PAL.warn)
			-- the wheel's own soft tok-tok; uiError "sounds too similar to a device disconnecting" (Derek 10-28)
			Sound.play("uiSpinBusy")
		end
		self:_refresh()
		return
	end
	self:_light(nil)
	self:_say("", PAL.text)
	local calm = GuiService.ReducedMotionEnabled
	local start = os.clock()
	self._turn = {
		from = self._angle,
		to = SpinLogic.landing(self._angle, index, self._spans, if calm then CALM_TURNS else TURNS),
		start = start,
		duration = if calm then CALM_SECONDS else SPIN_SECONDS,
		index = index,
		amount = amount,
		skippable = false,
	}
	self._readyAt = start + SPIN_SECONDS -- a full spin lands right on it, so Spin! comes back as it stops
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
	for _, bar in self._wedges:GetChildren() do
		bar:Destroy()
	end
	table.clear(self._bars)
	local spans = SpinLogic.spans(self._rows)
	self._spans = spans
	table.clear(self._centres)
	table.clear(self._radii)
	local plain, golds = 0, 0
	for index, row: Types.SpinRow in self._rows do
		local size = spans[index]
		local centre = SpinLogic.centre(spans, index)
		self._centres[index] = centre
		self._radii[index] = if row.jackpot == true then NARROW_RADIUS else RADIUS
		local color: Color3
		if row.jackpot == true then
			golds += 1
			color = JACKPOT_COLORS[(golds - 1) % #JACKPOT_COLORS + 1]
		else
			plain += 1
			color = SLICE_COLORS[(plain - 1) % #SLICE_COLORS + 1]
		end
		local steps = math.max(2, math.ceil(size / WEDGE_STEP))
		local step = size / steps
		-- a bar's width, of the face: wide enough to reach the next ray at the rim, a little more so neighbours overlap
		local width = 0.5 * math.sin(math.rad(step)) * 1.15
		local from = centre - size / 2
		local function add(base: number, side: number)
			local bar: Frame = Create("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(width, 0.5),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 1,
				Parent = self._wedges,
			})
			table.insert(self._bars, { frame = bar, base = base, side = side, width = width })
		end
		for k = 0, math.ceil(steps / 2) - 1 do
			add(from + k * step, 1) -- from the wedge's first edge, reaching clockwise
		end
		for k = 0, math.ceil(steps / 2) - 1 do
			add(from + size - k * step, -1) -- from its last edge, reaching back
		end
	end
	for _, tile in self._oddsTiles do
		tile.icon:destroy()
		tile.holder:Destroy()
	end
	table.clear(self._oddsTiles)
	self._landed = nil

	for index, row: Types.SpinRow in self._rows do
		table.insert(
			self._spokes,
			Create("Frame", {
				Name = "Spoke" .. index,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0, SPOKE, 0.5, 0),
				BackgroundColor3 = Theme.colors.white,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = self._face,
			})
		)
		-- the prize on its wedge: one fat picture filling the wedge (Derek's 11-04 mockup), the amount in a dark pill over
		-- its foot; a gold ring when won
		local radius = self._radii[index]
		local fit = math.min(TILE, 2 * radius * math.sin(math.rad(spans[index] / 2)) * TILE_FILL)
		local narrow = fit < TILE * 0.75
		local holder = circle({
			Name = "Slice" .. row.slice,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(fit, fit),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = self._face,
		})
		local stroke = Outline.border(holder, 4, Theme.colors.gold)
		stroke.Enabled = false
		local icon = ItemIcon.new({
			parent = holder,
			size = UDim2.fromScale(0.9, 0.9),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, -0.04),
			badge = "gem",
			plain = true,
		})
		local pill: Frame = Create("Frame", {
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1.04),
			Size = UDim2.fromScale(if narrow then 1 else 0.8, if narrow then NARROW_PILL else 0.27),
			BackgroundColor3 = Theme.colors.outline,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = holder,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local amount = text({
			Name = "Amount",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			TextColor3 = Theme.colors.white,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
			Parent = pill,
		})
		Create("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 9, Parent = amount })
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = amount,
		})
		local tile: Tile = {
			holder = holder,
			stroke = stroke,
			icon = icon,
			row = row,
			crate = nil,
			amount = amount,
		}
		self:_paint(tile)
		table.insert(self._tiles, tile)
	end
	for order, row: Types.SpinRow in SpinLogic.byChance(self._rows) do
		self:_oddsRow(row, order)
	end
	self:_setAngle(self._angle)
	self:_refresh()
end

-- A tile's picture: coins, golden fish, the crate it pays now, or the food with its grade gem (F69), each the
-- uploaded picture of F97 section 4.
function SpinWheel._paint(self: any, tile: Tile)
	local row = tile.row
	local icon: ItemIcon.ItemIcon = tile.icon
	if row.kind == "fish" then
		icon:set(nil, "", "Legendary")
		FishCoin.fill(icon.frame, 0.66, 2)
	elseif row.kind == "crate" then
		self:_paintCrate(tile)
	elseif row.kind == "lure" then
		-- the food's clean picture from the one food lookup (ShopIcons.food, #1242), as in the bowl and the Market
		icon:setFood(if row.lureId then self._lureById[row.lureId] else nil, row.lureId)
	else
		-- the clean money bag (#966, Derek: "The money bag ... too hard to understand what it is or too small")
		icon:set(nil, COIN_GLYPH, "Legendary", ShopIcons.clean("Bag"))
	end
end

-- One row of the Odds list: the prize picture, its name, a bar as long as its chance and the chance.
function SpinWheel._oddsRow(self: any, row: Types.SpinRow, order: number)
	local line: Frame = Create("Frame", {
		Name = "Slice" .. row.slice,
		LayoutOrder = order,
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ODDS_ROW),
		Parent = self._oddsList,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	local jackpot = row.jackpot == true
	if jackpot then
		line.BackgroundColor3 = PAL.goldCard -- #1500: the two jackpots in gold, so the rare chase stands out
	end
	local stroke = Outline.border(
		line,
		Theme.sizes.stroke,
		if jackpot then Theme.colors.gold else PAL.cardStroke
	)
	local icon = ItemIcon.new({
		parent = line,
		size = UDim2.fromOffset(ODDS_ICON, ODDS_ICON),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 8, 0.5, 0),
		badge = "gem",
	})
	local left = ODDS_ICON + 18
	local prize = text({
		Name = "Prize",
		Position = UDim2.fromOffset(left, 10),
		Size = UDim2.new(1, -(left + ODDS_CHANCE), 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Parent = line,
	})
	local track: Frame = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = PAL.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(left, 38),
		Size = UDim2.new(1, -(left + ODDS_CHANCE), 0, 12),
		Parent = line,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local share = math.clamp(SpinLogic.share(self._rows, row) / 100, 0, 1)
	Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = if jackpot then Theme.colors.gold else Theme.colors.berry,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(share, 1),
		Parent = track,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local chance = text({
		Name = "Chance",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(ODDS_CHANCE - 16, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = SpinLogic.chance(self._rows, row),
		Parent = line,
	})
	Outline.text(chance, 1)
	local tile: Tile =
		{ holder = line, stroke = stroke, icon = icon, row = row, crate = nil, prize = prize }
	self:_paint(tile)
	table.insert(self._oddsTiles, tile)
end

function SpinWheel._showOdds(self: any, on: boolean)
	self._odds.Visible = on
	if on then
		self:_refresh()
	end
end

-- Puts the wheel at `angle` degrees clockwise: each tile round the hub, each spoke between two tiles.
function SpinWheel._setAngle(self: any, angle: number)
	self._angle = angle
	local count = #self._tiles
	if count == 0 then
		return
	end
	-- a bar turns about its middle: halfway out along its ray, then half its width off the ray into its wedge
	for _, bar in self._bars do
		local offset = bar.width / 2
		local turn = bar.base + angle
		local theta = math.rad(turn)
		local sin, cos = math.sin(theta), math.cos(theta)
		bar.frame.Position = UDim2.fromScale(
			0.5 + 0.25 * sin + bar.side * offset * cos,
			0.5 - 0.25 * cos + bar.side * offset * sin
		)
		bar.frame.Rotation = turn
	end
	for index, tile: Tile in self._tiles do
		local theta = math.rad((self._centres[index] or 0) + angle)
		local radius = self._radii[index] or RADIUS
		tile.holder.Position =
			UDim2.fromScale(0.5 + radius * math.sin(theta), 0.5 - radius * math.cos(theta))
	end
	for index, spoke: Frame in self._spokes do
		local edge = (self._centres[index] or 0) + (self._spans[index] or 0) / 2 + angle
		local theta = math.rad(edge)
		spoke.Position = UDim2.fromScale(0.5 + 0.25 * math.sin(theta), 0.5 - 0.25 * math.cos(theta))
		spoke.Rotation = edge
	end
end

-- One frame of a spin: ease toward the landing angle, tick and blink as each slice passes the pointer.
function SpinWheel._step(self: any)
	local turn: Turn = self._turn
	local elapsed = os.clock() - turn.start
	if not turn.skippable and elapsed >= SpinLogic.SKIP_AFTER then
		turn.skippable = true
		self:_refresh()
	end
	local t = math.clamp(elapsed / turn.duration, 0, 1)
	-- Quad Out slows at a steady rate: no long crawl over the last slice edge (N127)
	local eased = TweenService:GetValue(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self:_setAngle(turn.from + (turn.to - turn.from) * eased)
	local slot = SpinLogic.slotAt(self._angle, self._spans)
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
		light.BackgroundColor3 = if on then RIM_LIGHT_COLOR else LIGHT_OFF_COLOR
	end
end

-- The wheel has stopped in the middle of the paid slice: pop it, burst, say the prize.
function SpinWheel._land(self: any, turn: Turn)
	self:_setAngle(turn.to % 360)
	self._slot = SpinLogic.slotAt(self._angle, self._spans)
	self:_blink(nil)
	self:_light(turn.index)
	local row: Types.SpinRow? = self._rows[turn.index]
	local jackpot = row ~= nil and row.jackpot == true
	local won = if row
		then (if jackpot then "Jackpot! " else "") .. "You won " .. self:_prize(row, turn.amount) .. "!"
		else "You won a prize!"
	self:_say(won, PAL.good)
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
		-- a jackpot's burst fills the whole wheel (#1500: "the wheel's biggest win effect")
		local reach = if jackpot then 1.1 else tile.holder.Size.X.Scale * 2.2
		Tween.to(burst, Tween.RISE, {
			Size = UDim2.fromScale(reach, reach),
			BackgroundTransparency = 1,
		}).Completed
			:Once(function()
				burst:Destroy()
			end)
	end
	Sound.play("uiSpinWin")
	-- a jackpot's toast comes from the server (SpinService, #1500), so the closed window does not add a second
	if not self.frame.Visible and not jackpot then
		self._callbacks.toast("Spin Wheel: " .. won)
	end
	self:_refresh()
	-- landed early (a Skip or a calm spin): Spin! comes back the moment the cooldown ends, not up to a second later
	local readyIn = self._readyAt - os.clock()
	if readyIn > 0 then
		task.delay(readyIn + 0.02, function()
			if self._tick.Connected and not self._turn then
				self:_refresh()
			end
		end)
	end
end

-- Rings the landed tile in gold until the next spin; nil clears it.
function SpinWheel._light(self: any, index: number?)
	self._landed = index
	for each, tile: Tile in self._tiles do
		local lit = each == index
		tile.stroke.Enabled = lit
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

-- A wheel tile's short line: the coins at the current day rate, else "x3".
function SpinWheel._amount(self: any, row: Types.SpinRow): string
	if row.kind == "coins" then
		return self:_prize(row, nil)
	end
	return "x" .. Format.short(row.count or 1)
end

function SpinWheel._press(self: any)
	local turn: Turn? = self._turn
	if turn then
		-- Skip: stop on the prize now (it is already paid); the next spin still waits out the cooldown
		if turn.skippable then
			self._turn = nil
			self:_land(turn)
		end
		return
	end
	if self._pressedAt or os.clock() < self._readyAt then
		return
	end
	self._pressedAt = os.clock()
	self:_say("", PAL.text)
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
	if self._pressedAt and os.clock() - self._pressedAt >= PENDING_SECONDS then
		self._pressedAt = nil
		self:_say("The wheel did not answer. Try again!", PAL.warn)
	end
	if not self.frame.Visible then
		return
	end
	for _, tile: Tile in self._tiles do
		local amount: TextLabel? = tile.amount
		if amount then
			amount.Text = self:_amount(tile.row)
		end
	end
	if self._odds.Visible then
		for _, tile: Tile in self._oddsTiles do
			local prize: TextLabel? = tile.prize
			if prize then
				local name = self:_prize(tile.row, nil)
				prize.Text = if tile.row.jackpot == true then "Jackpot: " .. name else name
			end
		end
	end

	local spins = SpinLogic.spins(spin, now)
	local banked = if spin then math.max(0, math.floor(spin.banked)) else 0
	self._spinsCount.Text = tostring(spins)
	self._spinsLabel.Text = if spins == 1 then "Spin" else "Spins"
	local freeLine = if SpinLogic.freeDue(spin, now)
		then "Free spin ready!"
		else "Next free spin in " .. SpinLogic.wait(SpinLogic.nextFreeIn(spin, now))
	if banked > 0 then
		freeLine ..= ("  ·  %d saved"):format(banked)
	end
	self._freeLabel.Text = freeLine
	local due = SpinLogic.freeDue(spin, now)
	self._freeLabel.TextColor3 = if due then PAL.good else PAL.subtext
	self._freeChip.BackgroundColor3 = if due then PAL.goldCard else PAL.line

	local turn: Turn? = self._turn
	local button = SpinLogic.button({
		turning = turn ~= nil,
		skippable = turn ~= nil and turn.skippable,
		waiting = self._pressedAt ~= nil,
		readyIn = math.max(0, self._readyAt - os.clock()),
		spins = spins,
		rows = #self._rows,
	})
	self._button:setText(button.text)
	self._button:setStyle(if button.skip then "secondary" else "gold")
	self._button:setEnabled(button.enabled)
	-- Use all (#1078): two or more spins, not while a spin turns or waits
	local allPending = self._allPending ~= nil and os.clock() - self._allPending < PENDING_SECONDS
	local all: Button.Button = self._allButton
	local showAll = self._callbacks.spinAll ~= nil and spins > 1
	all.instance.Visible = showAll
	self._oddsButton.instance.Size = if showAll
		then UDim2.new(0.5, -4, 1, 0)
		else UDim2.fromScale(1, 1)
	all:setText(if allPending then "..." else SpinLogic.allText(spins, (Config :: any).SpinAllMax))
	all:setEnabled(not allPending and turn == nil and self._pressedAt == nil)
end

function SpinWheel.destroy(self: any)
	self._tick:Disconnect()
	for _, tile in self._tiles do
		tile.icon:destroy()
	end
	table.clear(self._tiles)
	for _, tile in self._oddsTiles do
		tile.icon:destroy()
	end
	table.clear(self._oddsTiles)
	self._button:destroy()
	self._allButton:destroy()
	self._oddsButton:destroy()
	self._oddsBack:destroy()
	local card = self._allCard
	if card then
		card.chips:destroy()
		card.nice:destroy()
	end
	self._panel:destroy()
end

return SpinWheel
