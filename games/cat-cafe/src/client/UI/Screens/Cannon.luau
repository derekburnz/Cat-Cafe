--!strict
-- The Cat Cannon picker (F84, hometown-cannon.md 3a and 3c; mockup approved by Derek 2026-10-28 13:55 and 14:04):
-- opened by holding "Hop in" at a cannon. One card per place the cannon can fire to, each with a picture of its
-- landmark, its name, how many of its cats the player has ("7/10 cats", no coin line: Derek 13:55) and Launch.
-- The Town Square cannon lists every area the player's tier has opened, the Alleyway from Tier 1; a camp's cannon
-- lists Town Square first, then the other opened areas. In the last DuskWarningSeconds of the day the area cards
-- read "Night soon" and at night a moon covers them, with the sunrise countdown under the title; Town Square
-- stays open. Every Launch greys while carrying. Rules and words in Components/CannonLogic.
-- F92 (playing-together.md section 5): while a joiner's pal marker is up, the pal's area card wears a gold "Sam is
-- here" tag on its picture (setPal).
-- F100 (camp-extras.md section 3): an area with a camp extra open gets a strip under "7/10 cats" with the extra's
-- icon, name and what waits ("1 ready", "14 fish", "Next in 2 h 10 m"), and a red "!" dot when something is ready to
-- claim (Components/CampExtrasLogic; never on the Yard Sale). The cards grow to fit it only while one shows, and the
-- strip stays clear of the night cover, so players plan their morning (setExtras). #3082: the strip has a button for
-- every opened station, so nobody has to fly there: Collect while a Picnic Basket, Fish Pond or Lost and Found holds
-- something (in place of the dot), Open for the Yard Sale, the Oasis Spa and the Relic Museum, which have a card of
-- their own (Components/CampExtrasLogic.remoteAction). Until then only a Golden Pond owner's pond had Collect (#1463).
-- F101 (rescue-rally.md section 4): while a Rescue Rally runs, at night every card wears a red "🏁 Rally: rescues x3"
-- tag along the foot of its picture, over the night cover in place of its "Closed until sunrise" (the header and the
-- button still say so), since a rescue scores three (setRally, RallyLogic).
-- #2915: setRing(areaId) puts the tutorial's pulsing gold ring and arrow (Components/StepTarget) on that card's Launch
-- while it can launch: "Fly to the Park" on the rank-up card opens the picker with the Park's ringed.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CampExtrasLogic = require(script.Parent.Parent.Components.CampExtrasLogic)
local CannonLogic = require(script.Parent.Parent.Components.CannonLogic)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local LateStationsLogic = require(script.Parent.Parent.Components.LateStationsLogic)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local MysticPoolLogic = require(script.Parent.Parent.Components.MysticPoolLogic)
local NightClock = require(script.Parent.Parent.Components.NightClock)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local RallyLogic = require(script.Parent.Parent.Components.RallyLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local StepTarget = require(script.Parent.Parent.Components.StepTarget)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = MenuFamily.pal
-- #3347 (Derek2: "make the spa symbol better and not some simple symbols"): a station's drawn picture on its picker
-- line, in place of its emoji (which shows until the picture loads)
local LINE_IMAGES: { [string]: string? } = { spa = ShopIcons.clean("Spa") }

export type Callbacks = {
	launch: (cannonId: string, destination: string) -> (),
	close: () -> (),
	-- #3082: Collect on a card's strip (CollectCampExtra from anywhere; #1463 had it for a Golden Pond owner's pond)
	collect: ((extraId: string) -> ())?,
	-- #3082: Open on a card's strip: the Yard Sale's, the Oasis Spa's or the Relic Museum's own card
	open: ((stationId: string) -> ())?,
}

export type Cannon = {
	frame: Frame,
	setCatalog: (self: Cannon, catalog: Types.Catalog) -> (),
	-- "town" or a camp's area id: the cannon the player hopped into
	setCannon: (self: Cannon, cannonId: string) -> (),
	setAreasOpen: (self: Cannon, open: boolean) -> (),
	setClock: (self: Cannon, phase: Types.ClockPhase?, phaseEndsAt: number?) -> (),
	-- F92: the area a joiner's pal is in and the pal's name, or nil to take the tag away
	setPal: (self: Cannon, areaId: string?, name: string?) -> (),
	setRing: (self: Cannon, areaId: string?) -> (), -- #2915
	-- F100: the last CampExtrasState, or nil before the first
	setExtras: (self: Cannon, extras: Types.CampExtrasState?) -> (),
	setTraits: (self: Cannon, traits: any) -> (), -- #3196: PlayerState.traits, for the Mystic Pool's strip
	setLate: (self: Cannon, late: any) -> (), -- #2651 part 4: LateStationsState, for the Desert and Ruins strips
	-- F101: the last RallyState, or nil
	setRally: (self: Cannon, rally: Types.RallyState?) -> (),
	render: (self: Cannon, state: Types.PlayerState, carrying: boolean) -> (),
	opened: (self: Cannon) -> (),
	closed: (self: Cannon) -> (),
	-- the server's answer: a refusal lifts the wait and wobbles the card's Launch
	result: (self: Cannon, ok: boolean, destination: string?) -> (),
	destroy: (self: Cannon) -> (),
}

local CARD = Vector2.new(226, 214)
local ART_H = 100
-- #2771 (Laptop-Tester, Galaxy A06: the second row cut off): on a phone held sideways (Scale.isPhone) the picture
-- band is a slim strip and the words and Launch sit closer, so both rows of cards fit the panel
local PHONE_ART_H, PHONE_CARD_H = 24, 128
local NAME_GAP = 14 -- the card's name sits this far under the picture (8 on a phone)
local LAUNCH_INSET = 10 -- Launch's gap to the card's bottom (6 on a phone)
local EXTRA_H = 40 -- F100: the camp extra's strip, added to the cards while one shows
-- #3082: the strip's button, as wide as its word needs, so the station's name and what waits keep their room on a
-- phone's slim cards (#1463: the Golden Pond's Collect was 84)
local BUTTON_W = { collect = 66, open = 52 } :: { [string]: number }
local COLLECT_REST = 2 -- seconds Collect hides after a press, while the server answers
local PENDING_SECONDS = 1 -- Launch greys this long after a press, so a double tap is one launch
local DUSK_SECONDS: number = 15
do
	local Config =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
	DUSK_SECONDS = (Config :: any).DuskWarningSeconds or DUSK_SECONDS
end
-- #2692: a new player before the first check-in holds the night pass (the server's NightPass player attribute), so
-- the cards stay open through dusk and the night for them, as the server flies them then
local NightPass =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("NightPass"))

local function hasNightPass(): boolean
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute(NightPass.ATTRIBUTE) == true
end

local Cannon = {}
Cannon.__index = Cannon

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

function Cannon.new(callbacks: Callbacks): Cannon
	local self = setmetatable({}, Cannon) :: any
	self._callbacks = callbacks
	if Scale.isPhone() then
		ART_H = PHONE_ART_H
		NAME_GAP = 8
		LAUNCH_INSET = 6
		CARD = Vector2.new(CARD.X, PHONE_CARD_H)
	end
	self._cards = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._cannonId = CannonLogic.TOWN
	self._areasOpen = true
	self._passConnection = nil :: RBXScriptConnection?
	if Players.LocalPlayer then
		self._passConnection = Players.LocalPlayer
			:GetAttributeChangedSignal(NightPass.ATTRIBUTE)
			:Connect(function()
				self:_rerender() -- #2692: the first check-in ends the pass
			end)
	end
	self._phase = nil :: Types.ClockPhase?
	self._phaseEndsAt = nil :: number?
	self._state = nil :: Types.PlayerState?
	self._carrying = false
	self._pendingUntil = 0
	self._open = false
	self._tick = 0
	self._pal = nil :: { areaId: string, name: string }?
	self._extras = nil :: Types.CampExtrasState?
	self._traits = nil :: any -- #3196: PlayerState.traits, for the Mystic Pool's strip
	self._late = nil :: any -- #2651 part 4: the last LateStationsState
	self._tall = false -- the cards have room for a camp extra's strip
	self._rally = nil :: Types.RallyState?
	self._ring = nil :: string? -- #2915: the area whose Launch wears the ring

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Cannon",
		color = Theme.colors.mintDark,
		icon = Theme.icons.cannon,
		title = "Cat Cannon",
		subtitle = "Pick where to fly",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(760, 540), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	local layout: UIGridLayout = Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(Theme.sizes.gap + 4, Theme.sizes.gap + 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self._layout = layout
	self._grid = Create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		layout :: Instance,
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 6),
		}),
	})

	return self :: Cannon
end

-- One card per place: Town Square and every catalog area. render shows the ones this cannon lists.
function Cannon._buildCards(self: any)
	for _, card in self._cards do
		card.launch:destroy()
		card.collect:destroy()
		card.frame:Destroy()
	end
	table.clear(self._cards)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	local places: { { id: string, name: string, tier: number } } =
		{ { id = CannonLogic.TOWN, name = CannonLogic.TOWN_NAME, tier = 0 } }
	local areaList: { Types.AreaDef } = catalog.areas or {}
	for _, area in areaList do
		table.insert(places, { id = area.id, name = area.name, tier = area.tier })
	end
	for _, place in places do
		local id = place.id
		local frame: Frame = Create("Frame", {
			Name = id,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			Visible = false,
			Parent = self._grid,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", { Color = PAL.cardStroke, Thickness = Theme.sizes.stroke }),
		})
		local art: Frame = Create("Frame", {
			Name = "Art",
			BackgroundColor3 = Theme.areaColors[id] or Theme.colors.caramel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, ART_H),
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		-- the emoji under the picture shows until the picture loads, and for good where there is none
		local icon = text({
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = (Theme.icons :: any)[id] or Theme.icons.travel,
			Parent = art,
		})
		-- #2771: the phone's slim band (ART_H under 60) keeps its emoji, moon and lock in it, and drops the covers'
		-- lines, which the header and the button already say
		local slim = ART_H < 60
		local mark = if slim then ART_H - 4 else 48
		Create("UIPadding", {
			PaddingTop = UDim.new(0, if slim then 2 else 16),
			PaddingBottom = UDim.new(0, if slim then 2 else 16),
			Parent = icon,
		})
		local picture = Theme.areaPictures[id]
		if picture then
			Create("ImageLabel", {
				Name = "Picture",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = picture,
				ScaleType = Enum.ScaleType.Crop,
				Parent = art,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		end
		-- the night cover: a moon and "Closed until sunrise" over the picture
		local night: Frame = Create("Frame", {
			Name = "Night",
			BackgroundColor3 = Theme.colors.skyText,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 3,
			Parent = art,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		text({
			Name = "Moon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, if slim then 2 else 10),
			Size = UDim2.fromOffset(mark, mark),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = Theme.icons.moon,
			ZIndex = 4,
			Parent = night,
		})
		local nightLine = text({
			Name = "Line",
			Position = UDim2.new(0, 6, 0, 62),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.colors.white,
			Text = "Closed until sunrise",
			Visible = not slim,
			ZIndex = 4,
			Parent = night,
		})
		Outline.text(nightLine, 2)
		-- #2682: the lock cover, shading an area the player's tier has not opened yet, with a lock and its tier
		local lock: Frame = Create("Frame", {
			Name = "Lock",
			BackgroundColor3 = Theme.colors.skyText,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 3,
			Parent = art,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		text({
			Name = "Padlock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, if slim then 2 else 10),
			Size = UDim2.fromOffset(mark, mark),
			FontFace = Theme.fonts.display,
			TextScaled = true,
			Text = Theme.icons.lock,
			ZIndex = 4,
			Parent = lock,
		})
		local lockLine = text({
			Name = "Line",
			Position = UDim2.new(0, 6, 0, 62),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.colors.white,
			Text = ("Opens at Tier %d"):format(place.tier),
			Visible = not slim,
			ZIndex = 4,
			Parent = lock,
		})
		Outline.text(lockLine, 2)
		Outline.border(art, 2)
		Outline.shade(art, 0.2)
		-- F92: the joiner's pal is here
		local pal = text({
			Name = "Pal",
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(0, 26),
			BackgroundColor3 = Theme.colors.gold,
			BackgroundTransparency = 0,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			TextColor3 = Theme.colors.goldText,
			TextTruncate = Enum.TextTruncate.None,
			Visible = false,
			ZIndex = 5,
			Parent = art,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pal })
		Create(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = pal }
		)
		Outline.border(pal, 2)
		-- F101: the Rally's night tag along the foot of the picture
		local rally = text({
			Name = "Rally",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, if slim then 0 else -6),
			Size = UDim2.fromOffset(0, math.min(24, ART_H)),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromHex("D9483B"), -- the Rally red (Components/RallyBar)
			BackgroundTransparency = 0,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.white,
			TextTruncate = Enum.TextTruncate.None,
			Visible = false,
			ZIndex = 5,
			Parent = art,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = rally })
		Create(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = rally }
		)
		Outline.border(rally, 2)
		Outline.text(rally, 1.5)
		text({
			Name = "Name",
			Position = UDim2.fromOffset(10, ART_H + NAME_GAP),
			Size = UDim2.new(1, -20, 0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = place.name,
			Parent = frame,
		})
		local count = text({
			Name = "Count",
			Position = UDim2.fromOffset(10, ART_H + NAME_GAP + 26),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			Text = if id == CannonLogic.TOWN then "Cafes and markets" else "",
			Parent = frame,
		})
		-- F100: the camp extra's strip, shown by render when the area's extra is open
		local extra: Frame = Create("Frame", {
			Name = "Extra",
			BackgroundColor3 = PAL.line,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, ART_H + NAME_GAP + 46),
			Size = UDim2.new(1, -20, 0, EXTRA_H - 4),
			Visible = false,
			Parent = frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		local extraIcon = text({
			Name = "Icon",
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.fromOffset(28, EXTRA_H - 4),
			FontFace = Theme.fonts.display,
			TextSize = 20,
			TextTruncate = Enum.TextTruncate.None,
			Parent = extra,
		})
		local extraName = text({
			Name = "Name",
			Position = UDim2.fromOffset(36, 2),
			Size = UDim2.new(1, -66, 0, 17),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = extra,
		})
		local extraState = text({
			Name = "State",
			Position = UDim2.fromOffset(36, 19),
			Size = UDim2.new(1, -66, 0, 15),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = extra,
		})
		local extraDot: Frame = Create("Frame", {
			Name = "Ready",
			BackgroundColor3 = Theme.colors.red,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			Visible = false,
			Parent = extra,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Outline.border(extraDot, 2)
		text({
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			TextColor3 = Theme.colors.white,
			TextTruncate = Enum.TextTruncate.None,
			Text = "!",
			Parent = extraDot,
		})
		-- #3082: Collect (in place of the red dot) or Open for the area's station; render sets the word
		local collect = Button.new({
			name = "Collect",
			text = "Collect",
			style = "secondary",
			size = UDim2.fromOffset(BUTTON_W.collect, EXTRA_H - 4), -- the strip's full height: a 36 px tap with a mouse
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -3, 0.5, 0),
			textSize = Theme.sizes.textSmall,
			parent = extra,
			onClick = function()
				self:_collect(id)
			end,
		})
		collect.instance.Visible = false
		local launch = Button.new({
			name = "Launch",
			text = "Launch",
			icon = Theme.icons.cannon,
			style = "primary",
			size = UDim2.new(1, -20, 0, 44),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -LAUNCH_INSET),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_press(id)
			end,
		})
		self._cards[id] = {
			frame = frame,
			pal = pal,
			rally = rally,
			night = night,
			nightLine = nightLine,
			lock = lock,
			tier = place.tier,
			count = count,
			extra = extra,
			extraIcon = extraIcon,
			extraName = extraName,
			extraState = extraState,
			extraDot = extraDot,
			collect = collect,
			collectWord = "collect",
			collectedAt = -math.huge,
			launch = launch,
			buttonState = nil :: CannonLogic.ButtonState?,
			pending = false,
		}
	end
end

-- The strip's line for area `id`: its camp extra's, else its late station's (the Desert and the Ruins).
function Cannon._line(self: any, id: string): CampExtrasLogic.Line?
	return MysticPoolLogic.pickerLine(self._traits, id)
		or CampExtrasLogic.pickerLine(self._extras, id, Workspace:GetServerTimeNow())
		or LateStationsLogic.pickerLine(self._late, id)
end

-- #3196: PlayerState.traits (nil while the Mystic Pool is shut), for the Park card's strip.
function Cannon.setTraits(self: any, traits: any)
	self._traits = if type(traits) == "table" then traits else nil
end

-- #3082: the strip's button. Collect sends CollectCampExtra and rests while the server answers; Open brings up the
-- station's own card in place of the picker.
function Cannon._collect(self: any, id: string)
	local card = self._cards[id]
	local line: CampExtrasLogic.Line? = self:_line(id)
	local action = CampExtrasLogic.remoteAction(line)
	if card == nil or line == nil or action == nil then
		return
	end
	if action == "open" then
		local open: ((string) -> ())? = self._callbacks.open
		if open ~= nil then
			open(line.extraId)
		end
		return
	end
	local collect: ((string) -> ())? = self._callbacks.collect
	if collect == nil or os.clock() - card.collectedAt < COLLECT_REST then
		return
	end
	card.collectedAt = os.clock()
	card.collect.instance.Visible = false
	collect(line.extraId)
end

-- #2915: the ring on `areaId`'s Launch, or none.
function Cannon.setRing(self: any, areaId: string?)
	if self._ring == areaId then
		return
	end
	self._ring = areaId
	self:_rerender()
end

-- F92: the gold "Sam is here" tag on the pal's area card, or none.
function Cannon.setPal(self: any, areaId: string?, name: string?)
	self._pal = if areaId ~= nil then { areaId = areaId, name = name or "Your pal" } else nil
	self:_paintPal()
end

function Cannon._paintPal(self: any)
	local pal: { areaId: string, name: string }? = self._pal
	for id, card in self._cards do
		local here = pal ~= nil and pal.areaId == id
		card.pal.Visible = here
		if pal ~= nil and here then
			card.pal.Text = ("👋 %s is here"):format(pal.name)
		end
	end
end

-- F100: CampExtrasState, kept for the strips; render redraws them (once a second while the picker is open).
function Cannon.setExtras(self: any, extras: Types.CampExtrasState?)
	self._extras = extras
	self:_rerender()
end

-- #2651 part 4: LateStationsState, kept for the Oasis Spa's and Relic Museum's strips.
function Cannon.setLate(self: any, late: any)
	self._late = late
	self:_rerender()
end

-- F101: RallyState, kept for the night tag; render shows it (once a second while the picker is open).
function Cannon.setRally(self: any, rally: Types.RallyState?)
	self._rally = rally
	self:_rerender()
end

function Cannon.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildCards()
	self:_paintPal()
	self:_rerender()
end

function Cannon.setCannon(self: any, cannonId: string)
	self._cannonId = cannonId
	self:_rerender()
end

-- F66: false from dusk to sunrise.
function Cannon.setAreasOpen(self: any, open: boolean)
	self._areasOpen = open
	self:_rerender()
end

function Cannon.setClock(self: any, phase: Types.ClockPhase?, phaseEndsAt: number?)
	self._phase, self._phaseEndsAt = phase, phaseEndsAt
	self:_rerender()
end

function Cannon._remaining(self: any): number?
	local endsAt: number? = self._phaseEndsAt
	if endsAt == nil then
		return nil
	end
	return endsAt - Workspace:GetServerTimeNow()
end

function Cannon._press(self: any, destination: string)
	if os.clock() < self._pendingUntil then
		return
	end
	local card = self._cards[destination]
	if card == nil or card.buttonState ~= "launch" then
		return
	end
	self._pendingUntil = os.clock() + PENDING_SECONDS
	self:_rerender()
	task.delay(PENDING_SECONDS, function()
		if os.clock() >= self._pendingUntil then
			self:_rerender()
		end
	end)
	self._callbacks.launch(self._cannonId, destination)
end

function Cannon._rerender(self: any)
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state, self._carrying)
	end
end

function Cannon.render(self: any, state: Types.PlayerState, carrying: boolean)
	self._state = state
	self._carrying = carrying
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	local areas: { Types.AreaDef } = catalog.areas or {}
	local tier = state.tier or 1
	local pass = hasNightPass()
	local closed = not NightPass.open(NightClock.areasOpen(self._areasOpen), pass)
	local remaining = self:_remaining()
	local dusk = not pass
		and self._phase ~= nil
		and remaining ~= nil
		and NightClock.isDusk(self._phase :: NightClock.Phase, remaining, DUSK_SECONDS)
	local pending = os.clock() < self._pendingUntil
	local rallyLine =
		RallyLogic.nightLine(self._rally, Workspace:GetServerTimeNow(), self._phase == "night")
	local list = CannonLogic.cards(areas :: any, tier, self._cannonId)
	local shown: { [string]: number } = {}
	local lockedIds: { [string]: boolean } = {}
	for index, destination in list do
		shown[destination.id] = index
		lockedIds[destination.id] = destination.locked == true
	end
	local tall = false
	for id, card in self._cards do
		local order = shown[id]
		card.frame.Visible = order ~= nil
		if order == nil then
			StepTarget.ui(card.launch.instance, false)
			continue
		end
		card.frame.LayoutOrder = order
		local locked = lockedIds[id]
		local buttonState: CannonLogic.ButtonState =
			CannonLogic.button(id, closed, dusk, carrying, locked)
		card.night.Visible = buttonState == "night"
		card.lock.Visible = locked
		-- the Town Square has no night cover and no rescues, so no tag (review N327); a locked area has none either
		local tag: string? = if id ~= CannonLogic.TOWN and not locked then rallyLine else nil
		card.rally.Visible = tag ~= nil
		-- the tag takes the cover's "Closed until sunrise" spot; the header and the button still say it
		card.nightLine.Visible = tag == nil and ART_H >= 60 -- #2771: not in the phone's slim band
		card.rally.Text = RallyLogic.ICON .. " " .. (tag or "")
		if id ~= CannonLogic.TOWN then
			local counts = IndexRewards.counts(catalog, state, id)
			card.count.Text = ("%d/%d cats"):format(counts.found, counts.total)
		end
		local line: CampExtrasLogic.Line? = if locked then nil else self:_line(id)
		card.extra.Visible = line ~= nil
		if line ~= nil then
			tall = true
			card.extraIcon.Text = line.icon
			IconArt.setImage(card.extraIcon, LINE_IMAGES[line.extraId], 0.95) -- #3347: drawn, not the emoji
			card.extraName.Text = line.name
			card.extraState.Text = line.state
			card.extraState.TextColor3 = if line.ready then PAL.good else PAL.subtext
			card.extraState.FontFace = if line.ready then Theme.fonts.bodyBold else Theme.fonts.body
			-- #3082: Collect in place of the dot (it rests a moment after a press, until the server's answer
			-- refreshes the strip), or Open for a station with its own card (green words say when something waits)
			local action = CampExtrasLogic.remoteAction(line)
			if
				(action == "collect" and self._callbacks.collect == nil)
				or (action == "open" and self._callbacks.open == nil)
			then
				action = nil
			end
			local resting = action == "collect" and os.clock() - card.collectedAt < COLLECT_REST
			local button = action ~= nil
			local width = BUTTON_W[action or "collect"]
			if action ~= nil and card.collectWord ~= action then
				card.collectWord = action
				card.collect:setText(CampExtrasLogic.REMOTE_WORDS[action])
				card.collect.instance.Size = UDim2.fromOffset(width, EXTRA_H - 4)
			end
			card.collect.instance.Visible = button and not resting
			card.extraDot.Visible = line.ready and not (button and not resting)
			card.extraName.Size = UDim2.new(1, if button then -(width + 42) else -66, 0, 17)
			card.extraState.Size = UDim2.new(1, if button then -(width + 42) else -66, 0, 15)
		end
		local enabled = buttonState == "launch" and not pending
		if card.buttonState ~= buttonState then
			card.buttonState = buttonState
			card.launch:setText(
				if buttonState == "locked"
					then ("%s Tier %d"):format(Theme.icons.lock :: string, card.tier :: number)
					elseif buttonState == "night" then Theme.icons.moon .. " Sunrise"
					elseif buttonState == "dusk" then "Night soon"
					else "Launch"
			)
		end
		if card.enabled ~= enabled then
			card.enabled = enabled
			card.launch:setEnabled(enabled)
		end
		StepTarget.ui(card.launch.instance, enabled and id == self._ring) -- #2915
	end
	if tall ~= self._tall then
		self._tall = tall
		self._layout.CellSize = UDim2.fromOffset(CARD.X, CARD.Y + (if tall then EXTRA_H else 0))
	end
	local notice = CannonLogic.notice(closed, dusk, carrying, if closed then remaining else nil)
	local plain = if self._cannonId == CannonLogic.TOWN
		then "Pick where to fly"
		else "Fly home to " .. CannonLogic.TOWN_NAME .. " or on to another area"
	self._panel:setTitle("Cat Cannon", notice or plain)
end

-- While the picker is open the sunrise countdown and the dusk warning move on their own, once a second.
function Cannon.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_rerender()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				self:_rerender()
			end
		end
	end)
end

function Cannon.closed(self: any)
	self._open = false
	self._tick += 1
end

function Cannon.result(self: any, ok: boolean, destination: string?)
	if ok then
		return
	end
	self._pendingUntil = 0
	self:_rerender()
	local card = if destination then self._cards[destination] else nil
	if card then
		local button: Frame = card.launch.instance
		button.Rotation = -8
		Tween.to(
			button,
			TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Rotation = 0 }
		)
	end
end

function Cannon.destroy(self: any)
	local passConnection: RBXScriptConnection? = self._passConnection
	if passConnection then
		passConnection:Disconnect()
	end
	self._open = false
	self._tick += 1
	for _, card in self._cards do
		card.launch:destroy()
		card.collect:destroy()
	end
	self._panel:destroy()
end

return Cannon
