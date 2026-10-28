--!strict
-- Golden Fish Market window (F53, golden-fish.md sections 3 and 4): the fishmonger stall in the street plaza beside
-- the Spin Wheel. Holding E on its "Market" prompt opens it (UI.market.open), so it keeps the HUD clear like the
-- wheel. A fish chip at the top shows the player's golden fish.
--   Crates: one card per crate the player can open or owns: its picture, "You have 2" or its price, the lucky
--   twentieth countdown ("Epic or better in 4 more crates"), Odds and Open. An owned crate opens free; otherwise
--   Open buys one for its price. A zone crate opens with its zone ("Opens at Tier 3"); golden crates show only
--   while owned, since they are never sold.
--   Treats: the Star Treat and the perks, each with what it does, its level and what the next level costs.
-- Odds shows each rarity's chance and every piece's chance before opening (monetization-policy section 2), and
-- says when the next crate opens on the golden odds. Open fires events.openCrate(crateId); the server rolls with
-- its own Random, pays at once and answers CrateResult(crateId, decorId, duplicate, refund), which plays the
-- reveal: the won piece's rarity colour shows from the first frame and never a better one first, so nothing looks
-- like a near miss; a tap skips it and Reduce Motion makes it a short fade. A new style piece (wallpaper, floor,
-- paint, door set or cat flap) gets a
-- "Use it" button that fires callbacks.useDecor (ToggleDecor(decorId, true)). Leaving mid-reveal keeps the piece. A
-- refusal is CrateResult(crateId, "", false, 0) and the server's toast says why. Buying a treat or perk fires
-- events.buyFishItem(itemId). Golden fish are earned only: nothing here mentions Robux. Sums in
-- Components/MarketLogic; walking out of range closes the window (as the wheel, N132).

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local FishCoin = require(script.Parent.Parent.Components.FishCoin)
local Format = require(script.Parent.Parent.Components.Format)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local MarketLogic = require(script.Parent.Parent.Components.MarketLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	openCrate: (crateId: string) -> (),
	buyItem: (itemId: string) -> (),
	useDecor: (decorId: string) -> (), -- "Use it" on a new style piece in the reveal
	toast: (text: string) -> (), -- a crate result that lands while the window is closed
	close: () -> (),
}

export type FishMarket = {
	frame: Frame,
	setCatalog: (self: FishMarket, catalog: Types.Catalog) -> (),
	render: (self: FishMarket, state: Types.PlayerState) -> (),
	result: (
		self: FishMarket,
		crateId: string,
		decorId: string,
		duplicate: boolean,
		refund: number
	) -> (),
	destroy: (self: FishMarket) -> (),
}

type CrateCard = {
	crate: Types.CrateDef,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	owned: TextLabel,
	line: TextLabel,
	luck: TextLabel,
	odds: Button.Button,
	open: Button.Button,
}

type ItemRow = {
	row: Types.FishShopRow,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	level: TextLabel,
	buy: Button.Button,
	seen: number?, -- the perk level or food count at the last render, to tell when a buy has landed
}

local TAG = "FishMarket"
local RANGE: number = Config.FishMarketRange or 14
local CLOSE_SLACK = 2 -- studs past the server's range before the window closes
local LUCKY_EVERY: number = Config.CrateLuckyEvery or 20
local PENDING_SECONDS = 5 -- a pressed Open or Buy waits this long for the server before it can be pressed again
local REVEAL_SECONDS = 2
local CARD = Vector2.new(196, 244)
local ROW_HEIGHT = 76
local TOP_HEIGHT = 44

-- The Market's own goods: names and what they do, so the window reads without a catalog change.
local ITEMS: { [string]: { name: string, icon: string, blurb: string } } = {
	star_treat = {
		name = "Star Treat",
		icon = "⭐",
		blurb = "The best food. Set it in your bait bowl for a shot at Legendary and Mythical cats.",
	},
	golden_espresso = {
		name = "Golden Espresso",
		icon = "☕",
		blurb = "+5% tips a level, forever.",
	},
	big_bowl = {
		name = "Big Bowl",
		icon = "🥣",
		blurb = "Food in the bait bowl is ready in 8 minutes instead of 10, forever.",
	},
	extra_decor_spot = {
		name = "Extra Decor Spot",
		icon = "🪴",
		blurb = "One more spot for furniture or decorations a level.",
	},
}

local FishMarket = {}
FishMarket.__index = FishMarket

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

local function card(props: { [string]: any }): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame: Frame = Create("Frame", merged)
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius), Parent = frame })
	Create("UIStroke", {
		Color = Theme.modal.cardStroke,
		Thickness = Theme.sizes.stroke,
		Parent = frame,
	})
	return frame
end

-- Studs from the player's character to the nearest Market stall, or nil when either is missing.
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

function FishMarket.new(callbacks: Callbacks): FishMarket
	local self = setmetatable({}, FishMarket) :: any
	self._callbacks = callbacks
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._decorById = {} :: { [string]: Types.DecorDef }
	self._lureById = {} :: { [string]: Types.LureDef }
	self._goldenOdds = {} :: { [string]: { [string]: number } } -- pool -> its golden crate's odds
	self._crateCards = {} :: { CrateCard }
	self._itemRows = {} :: { ItemRow }
	self._pending = {} :: { [string]: number } -- crate or item id -> os.clock() of the press
	self._tab = "Crates"
	self._revealToken = 0

	local panel = Panel.new({
		name = "FishMarket",
		title = "Golden Fish Market",
		subtitle = "Spend golden fish · every crate shows its odds",
		color = Theme.colors.goldDark,
		icon = Theme.icons.goldenFish,
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(780, 540), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- the top bar: two tabs on the left, the player's golden fish on the right
	local top: Frame = Create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOP_HEIGHT),
		Parent = panel.content,
	})
	local tabs: Frame = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -170, 1, 0),
		Parent = top,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._cratesTab = Button.new({
		name = "CratesTab",
		text = "Crates",
		icon = Theme.icons.crate,
		style = "gold",
		size = UDim2.fromOffset(132, 40),
		textSize = Theme.sizes.textBody,
		layoutOrder = 1,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:_showTab("Crates")
		end,
	})
	self._treatsTab = Button.new({
		name = "TreatsTab",
		text = "Treats and perks",
		icon = "⭐",
		style = "ghost",
		size = UDim2.fromOffset(196, 40),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:_showTab("Treats")
		end,
	})
	local balance = card({
		Name = "Balance",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(160, 38),
		Parent = top,
	})
	FishCoin.new({
		parent = balance,
		size = 24,
		position = UDim2.new(0, 10, 0.5, 2),
		anchorPoint = Vector2.new(0, 0.5),
	})
	self._balance = text({
		Name = "Amount",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.goldDark,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = balance,
	})

	local listTop = TOP_HEIGHT + Theme.sizes.gap
	local function scroller(name: string): ScrollingFrame
		return Create("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, listTop),
			Size = UDim2.new(1, 0, 1, -listTop),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.colors.caramel,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Parent = panel.content,
		}, {
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 8),
			}),
		})
	end
	self._crateList = scroller("Crates")
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(Theme.sizes.gap, Theme.sizes.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self._crateList,
	})
	self._emptyCrates = text({
		Name = "Empty",
		Size = UDim2.fromOffset(CARD.X * 2, 40),
		TextWrapped = true,
		TextColor3 = Theme.modal.subtext,
		Text = "The crates arrive with the next update.",
		Visible = false,
		Parent = self._crateList,
	})
	self._itemList = scroller("Treats")
	self._itemList.Visible = false
	Create("UIListLayout", {
		Padding = UDim.new(0, Theme.sizes.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self._itemList,
	})

	self:_buildOdds(panel.body)
	self:_buildReveal(panel.body)

	-- four times a second the range check; once a second the pending presses
	local rangeClock, clock = 0, 0
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
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
	return self :: FishMarket
end

function FishMarket._showTab(self: any, tab: string)
	self._tab = tab
	self._crateList.Visible = tab == "Crates"
	self._itemList.Visible = tab == "Treats"
	self._cratesTab:setStyle(if tab == "Crates" then "gold" else "ghost")
	self._treatsTab:setStyle(if tab == "Treats" then "gold" else "ghost")
end

-- The odds card: a sheet over the window with the rarity table and every piece's chance.
function FishMarket._buildOdds(self: any, body: Frame)
	local cover: TextButton = Create("TextButton", {
		Name = "OddsCover",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Visible = false,
		Parent = body,
	})
	local sheet = card({
		Name = "Odds",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -40),
		ZIndex = 21,
		Parent = cover,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(480, 460), Parent = sheet })
	self._oddsTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		ZIndex = 22,
		Parent = sheet,
	})
	self._oddsNote = text({
		Name = "Note",
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		ZIndex = 22,
		Parent = sheet,
	})
	self._oddsList = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(1, -24, 1, -64 - 58),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ZIndex = 22,
		Parent = sheet,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	})
	self._oddsDone = Button.new({
		name = "Done",
		text = "Got it",
		style = "primary",
		size = UDim2.fromOffset(160, 44),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -8),
		textSize = Theme.sizes.textBody + 1,
		zIndex = 22,
		parent = sheet,
		onClick = function()
			cover.Visible = false
		end,
	})
	self._oddsCover = cover -- only Got it closes it: a tap on the card or beside it does nothing (Derek 2026-10-27)
end

-- One line of the odds card: a rarity dot, the name, a small line under it and the chance on the right. A rarity's
-- own line (name == rarity) is written in that rarity's colour (Derek 2026-10-28: "colored text of the rarity and %").
function FishMarket._oddsLine(
	self: any,
	order: number,
	rarity: string,
	name: string,
	sub: string?,
	percent: number
)
	local height = if sub then 40 else 28
	local ink = if name == rarity then Theme.rarityInk(rarity) else Theme.modal.text
	local line: Frame = Create("Frame", {
		Name = "Line" .. order,
		LayoutOrder = order,
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = 22,
		Parent = self._oddsList,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.rarityColor(rarity),
		BorderSizePixel = 0,
		ZIndex = 23,
		Parent = line,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 1.5)
	text({
		Name = "Name",
		Position = UDim2.fromOffset(30, if sub then 3 else 0),
		Size = UDim2.new(1, -110, 0, if sub then 20 else height),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall + 1,
		TextColor3 = ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
		ZIndex = 23,
		Parent = line,
	})
	if sub then
		text({
			Name = "Sub",
			Position = UDim2.fromOffset(30, 21),
			Size = UDim2.new(1, -110, 0, 16),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = sub,
			ZIndex = 23,
			Parent = line,
		})
	end
	text({
		Name = "Chance",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0, 80, 1, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = ink,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = MarketLogic.percent(percent),
		ZIndex = 23,
		Parent = line,
	})
end

function FishMarket._showOdds(self: any, crate: Types.CrateDef)
	for _, child in self._oddsList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local state: Types.PlayerState? = self._state
	local luck = if state and state.crateLuck then state.crateLuck[crate.area] else nil
	local odds = MarketLogic.nextOdds(crate, luck, LUCKY_EVERY, self._goldenOdds[crate.area])
	-- N167: the same test nextOdds makes, not a comparison of the odds tables
	local lucky = not crate.golden
		and self._goldenOdds[crate.area] ~= nil
		and MarketLogic.luckLeft(luck, LUCKY_EVERY) <= 1
	self._oddsTitle.Text = crate.name
	self._oddsNote.Text = if crate.golden
		then "Epic or better every time"
		elseif lucky then "Lucky! Your next crate opens on these golden odds"
		else MarketLogic.luckText(MarketLogic.luckLeft(luck, LUCKY_EVERY))
	self._oddsNote.TextColor3 = if lucky then Theme.colors.goldDark else Theme.modal.subtext
	local order = 0
	for _, row in MarketLogic.rarityRows(odds) do
		order += 1
		self:_oddsLine(order, row.rarity, row.rarity, nil, row.percent)
	end
	local chances = MarketLogic.pieceChances(crate.pieces, function(id: string): string?
		return DecorPieces.info(self._decorById[id]).rarity
	end, odds)
	order += 1
	text({
		Name = "PiecesTitle",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = if #chances > 0 then "Each piece" else "The pieces arrive with the next update.",
		ZIndex = 22,
		Parent = Create("Frame", {
			Name = "PiecesHeader",
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			ZIndex = 22,
			Parent = self._oddsList,
		}),
	})
	for _, piece in chances do
		order += 1
		local decor: Types.DecorDef? = self._decorById[piece.id]
		local kindName = DecorPieces.kindName(DecorPieces.info(decor).kind)
		local bonus = if decor then decor.bonus or 0 else 0
		self:_oddsLine(
			order,
			piece.rarity,
			if decor then decor.name else piece.id,
			("%s · +%s tips while in use"):format(kindName, Format.percent(bonus)),
			piece.percent
		)
	end
	self._oddsList.CanvasPosition = Vector2.zero
	self._oddsCover.Visible = true
end

-- The reveal: the won piece on a card in its rarity colour, "New!" or the duplicate's refund, then Done.
function FishMarket._buildReveal(self: any, body: Frame)
	local cover: TextButton = Create("TextButton", {
		Name = "RevealCover",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Visible = false,
		Parent = body,
	})
	local glow: Frame = Create("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 31,
		Parent = cover,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local sheet = card({
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 330),
		ZIndex = 32,
		Parent = cover,
	})
	local band: Frame = Create("Frame", {
		Name = "Band",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 33,
		Parent = sheet,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	local rarity = text({
		Name = "Rarity",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		ZIndex = 34,
		Parent = band,
	})
	Outline.text(rarity, 2)
	local icon = ItemIcon.new({
		parent = sheet,
		size = UDim2.fromOffset(120, 120),
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 52),
	})
	icon.frame.ZIndex = 33
	local name = text({
		Name = "Name",
		Position = UDim2.fromOffset(10, 178),
		Size = UDim2.new(1, -20, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		ZIndex = 33,
		Parent = sheet,
	})
	local detail = text({
		Name = "Detail",
		Position = UDim2.fromOffset(10, 206),
		Size = UDim2.new(1, -20, 0, 20),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		ZIndex = 33,
		Parent = sheet,
	})
	local status = text({
		Name = "Status",
		Position = UDim2.fromOffset(10, 228),
		Size = UDim2.new(1, -20, 0, 40),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 33,
		Parent = sheet,
	})
	local done = Button.new({
		name = "Done",
		text = "Nice!",
		style = "primary",
		size = UDim2.fromOffset(150, 44),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -10),
		textSize = Theme.sizes.textBody + 1,
		zIndex = 33,
		parent = sheet,
		onClick = function()
			self:_hideReveal()
		end,
	})
	-- a new style piece (wallpaper, floor, paint, door set or cat flap): "Use it" beside the Done button swaps it in
	local use = Button.new({
		name = "UseIt",
		text = "Use it",
		style = "primary",
		size = UDim2.fromOffset(130, 44),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(0.5, -4, 1, -10),
		textSize = Theme.sizes.textBody + 1,
		zIndex = 33,
		parent = sheet,
		onClick = function()
			local decorId: string? = self._revealId
			if decorId then
				self._callbacks.useDecor(decorId)
			end
			self:_hideReveal()
		end,
	})
	use.instance.Visible = false
	self._reveal = {
		cover = cover,
		glow = glow,
		sheet = sheet,
		band = band,
		rarity = rarity,
		icon = icon,
		name = name,
		detail = detail,
		status = status,
		done = done,
		use = use,
	}
	-- a tap while it plays skips to the end; after that only the card's own buttons close it
	cover.Activated:Connect(function()
		if self._revealing then
			self:_finishReveal()
		end
	end)
end

function FishMarket._hideReveal(self: any)
	self._revealToken += 1
	self._revealing = false
	self._reveal.cover.Visible = false
end

function FishMarket._finishReveal(self: any)
	self._revealToken += 1
	self._revealing = false
	local reveal = self._reveal
	reveal.sheet.Size = UDim2.fromOffset(300, 330)
	reveal.glow.Size = UDim2.fromOffset(300, 300)
	reveal.done.instance.Visible = true
	reveal.use.instance.Visible = self._revealUse == true
end

-- Plays the reveal for the won piece. Its rarity shows from the first frame: the band, the glow and the tile are
-- that colour at once and nothing better is ever shown first (no near miss).
function FishMarket._playReveal(self: any, decorId: string, duplicate: boolean, refund: number)
	local reveal = self._reveal
	local decor: Types.DecorDef? = self._decorById[decorId]
	local piece = DecorPieces.info(decor)
	local bonus = if decor then decor.bonus or 0 else 0
	local color = Theme.rarityColor(piece.rarity)
	reveal.band.BackgroundColor3 = color
	reveal.glow.BackgroundColor3 = color
	reveal.rarity.Text = piece.rarity or "New piece"
	reveal.icon:set(
		if decor then decor.asset else nil,
		DecorPieces.kindIcon(piece.kind, Theme.icons.decor),
		piece.rarity
	)
	reveal.name.Text = if decor then decor.name else decorId
	reveal.detail.Text = ("%s · +%s tips while in use"):format(
		DecorPieces.kindName(piece.kind),
		Format.percent(bonus)
	)
	-- a new style piece can go up now; furniture and decorations take a free spot by themselves
	local offerUse = not duplicate and DecorPieces.isStyle(piece.kind)
	self._revealId = decorId
	self._revealUse = offerUse
	reveal.status.Text = if duplicate
		then ("You had this one: +%s golden fish back"):format(Format.short(refund))
		elseif offerUse then "New! Use it now, or later in Decor."
		else "New! Find it in Decor."
	reveal.status.TextColor3 = if duplicate then Theme.colors.goldDark else Theme.colors.goodDark
	-- two buttons side by side when Use it is offered, else Nice! in the middle
	reveal.done:setText(if offerUse then "Later" else "Nice!")
	reveal.done:setStyle(if offerUse then "ghost" else "primary")
	reveal.done.instance.AnchorPoint = if offerUse then Vector2.new(0, 1) else Vector2.new(0.5, 1)
	reveal.done.instance.Position = if offerUse
		then UDim2.new(0.5, 4, 1, -10)
		else UDim2.new(0.5, 0, 1, -10)
	reveal.done.instance.Size = UDim2.fromOffset(if offerUse then 130 else 150, 44)
	reveal.cover.Visible = true
	reveal.done.instance.Visible = false
	reveal.use.instance.Visible = false
	self._revealToken += 1
	local token = self._revealToken
	self._revealing = true
	if GuiService.ReducedMotionEnabled then
		-- a short fade instead of the pop and the growing glow
		reveal.cover.BackgroundTransparency = 1
		Tween.to(reveal.cover, Tween.FAST, { BackgroundTransparency = 0.3 })
		self:_finishReveal()
		return
	end
	reveal.sheet.Size = UDim2.fromOffset(180, 198)
	reveal.glow.Size = UDim2.fromOffset(120, 120)
	Tween.to(reveal.sheet, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(300, 330),
	})
	Tween.to(
		reveal.glow,
		TweenInfo.new(REVEAL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(300, 300) }
	)
	task.delay(REVEAL_SECONDS, function()
		if self._revealToken == token then
			self:_finishReveal()
		end
	end)
end

function FishMarket.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	table.clear(self._decorById)
	for _, decor in catalog.decor do
		self._decorById[decor.id] = decor
	end
	-- the crate pieces live in Catalog.crateDecor; the five Index pieces in Catalog.decor are zone Epics too
	local pieces: { Types.DecorDef } = catalog.crateDecor or {}
	for _, decor in pieces do
		self._decorById[decor.id] = decor
	end
	table.clear(self._lureById)
	for _, lure in catalog.lures do
		self._lureById[lure.id] = lure
	end
	table.clear(self._goldenOdds)
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		if crate.golden then
			self._goldenOdds[crate.area] = crate.odds
		end
	end
	self:_build()
end

function FishMarket._build(self: any)
	for _, entry in self._crateCards do
		entry.icon:destroy()
		entry.odds:destroy()
		entry.open:destroy()
		entry.frame:Destroy()
	end
	table.clear(self._crateCards)
	for _, entry in self._itemRows do
		entry.icon:destroy()
		entry.buy:destroy()
		entry.frame:Destroy()
	end
	table.clear(self._itemRows)
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog")

	local crates: { Types.CrateDef } = catalog.crates or {}
	for index, crate in crates do
		local frame = card({
			Name = crate.id,
			LayoutOrder = index + (if crate.golden then 100 else 0),
			Parent = self._crateList,
		})
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(76, 76),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 8),
		})
		icon:set(
			(crate :: any).asset,
			Theme.icons.crate,
			if crate.golden then "Legendary" else "Rare",
			ShopIcons.crate(crate.id)
		)
		local owned = text({
			Name = "Owned",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(44, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.berry,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.white,
			Visible = false,
			ZIndex = 3,
			Parent = frame,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = owned })
		text({
			Name = "Name",
			Position = UDim2.fromOffset(6, 88),
			Size = UDim2.new(1, -12, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			Text = crate.name,
			Parent = frame,
		})
		local line = text({
			Name = "Line",
			Position = UDim2.fromOffset(6, 110),
			Size = UDim2.new(1, -12, 0, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Parent = frame,
		})
		local luck = text({
			Name = "Luck",
			Position = UDim2.fromOffset(8, 130),
			Size = UDim2.new(1, -16, 0, 34),
			TextSize = Theme.sizes.textTiny + 1,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextColor3 = Theme.modal.subtext,
			Parent = frame,
		})
		local odds = Button.new({
			name = "Odds",
			text = "Odds",
			style = "ghost",
			size = UDim2.new(1, -16, 0, 28),
			position = UDim2.fromOffset(8, 166),
			textSize = Theme.sizes.textSmall,
			parent = frame,
			onClick = function()
				self:_showOdds(crate)
			end,
		})
		local open = Button.new({
			name = "Open",
			text = "Open",
			style = "primary",
			size = UDim2.new(1, -16, 0, 40),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_open(crate)
			end,
		})
		table.insert(self._crateCards, {
			crate = crate,
			frame = frame,
			icon = icon,
			owned = owned,
			line = line,
			luck = luck,
			odds = odds,
			open = open,
		})
	end

	local rows: { Types.FishShopRow } = catalog.fishShop or {}
	for index, row in rows do
		if row.kind == "crate" then
			continue -- crates have their own cards
		end
		local info = ITEMS[row.id]
		local lure: Types.LureDef? = self._lureById[row.id]
		local frame = card({
			Name = row.id,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Parent = self._itemList,
		})
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(ROW_HEIGHT - 16, ROW_HEIGHT - 16),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 8, 0.5, 0),
		})
		local fallback = "🎁"
		if info then
			fallback = info.icon
		elseif lure then
			fallback = Theme.foodIcons[lure.id] or Theme.icons.food
		end
		icon:set(
			if lure then lure.asset else nil,
			fallback,
			if row.kind == "perk" then "Legendary" elseif lure then lure.attracts else nil,
			if row.kind == "perk" then ShopIcons.perk(row.id) else ShopIcons.food(row.id)
		)
		text({
			Name = "Name",
			Position = UDim2.fromOffset(ROW_HEIGHT, 8),
			Size = UDim2.new(1, -(ROW_HEIGHT + 170), 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if info then info.name elseif lure then lure.name else row.id,
			Parent = frame,
		})
		text({
			Name = "Blurb",
			Position = UDim2.fromOffset(ROW_HEIGHT, 30),
			Size = UDim2.new(1, -(ROW_HEIGHT + 170), 0, 36),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Text = if info then info.blurb else "",
			Parent = frame,
		})
		local level = text({
			Name = "Level",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.fromOffset(150, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = Theme.modal.subtext,
			Parent = frame,
		})
		local buy = Button.new({
			name = "Buy",
			text = "Buy",
			icon = Theme.icons.goldenFish,
			style = "gold",
			size = UDim2.fromOffset(150, 40),
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -10, 1, -8),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_buy(row)
			end,
		})
		table.insert(self._itemRows, {
			row = row,
			frame = frame,
			icon = icon,
			level = level,
			buy = buy,
		})
	end
	self:_refresh()
end

function FishMarket._pendingFor(self: any, id: string): boolean
	local pressedAt: number? = self._pending[id]
	return pressedAt ~= nil and os.clock() - pressedAt < PENDING_SECONDS
end

function FishMarket._open(self: any, crate: Types.CrateDef)
	if self:_pendingFor(crate.id) or self._revealing then
		return
	end
	self._pending[crate.id] = os.clock()
	self._callbacks.openCrate(crate.id)
	self:_refresh()
end

function FishMarket._buy(self: any, row: Types.FishShopRow)
	if self:_pendingFor(row.id) then
		return
	end
	self._pending[row.id] = os.clock()
	self._callbacks.buyItem(row.id)
	self:_refresh()
end

function FishMarket.render(self: any, state: Types.PlayerState)
	self._state = state
	-- a sync that changes a perk's level or a food count ends that row's wait for the server (the state table is
	-- the same one each time, so the counts are kept by value)
	for _, entry: ItemRow in self._itemRows do
		local id = entry.row.id
		local have = if entry.row.kind == "perk"
			then (if state.fishPerks then state.fishPerks[id] else nil) or 0
			else state.lures[id] or 0
		if entry.seen ~= nil and entry.seen ~= have then
			self._pending[id] = nil
		end
		entry.seen = have
	end
	self:_refresh()
end

function FishMarket._refresh(self: any)
	local state: Types.PlayerState? = self._state
	local catalog: Types.Catalog? = self._catalog
	if not self.frame.Visible or state == nil or catalog == nil then
		return
	end
	local fish = math.floor(state.goldenFish or 0)
	self._balance.Text = Format.short(fish)
	local areas: { MarketLogic.Area } = (catalog.areas or {}) :: any
	local shown = 0
	for _, entry: CrateCard in self._crateCards do
		local crate = entry.crate
		local count = if state.crates then math.floor(state.crates[crate.id] or 0) else 0
		local open = MarketLogic.isOpen(crate, state.tier, areas)
		local visible = count > 0 or (not crate.golden and crate.price ~= nil)
		entry.frame.Visible = visible
		if not visible then
			continue
		end
		shown += 1
		entry.owned.Visible = count > 0
		entry.owned.Text = "x" .. Format.short(count)
		local price = crate.price or 0
		local pending = self:_pendingFor(crate.id)
		if count > 0 then
			entry.line.Text = ("You have %s"):format(Format.commas(count))
			entry.open:setText(if pending then "..." else "Open")
			entry.open:setStyle("primary")
			entry.open:setEnabled(not pending)
		elseif not open then
			local tier = MarketLogic.openTier(crate, areas)
			entry.line.Text = if tier then ("Opens at Tier %d"):format(tier) else "Locked"
			entry.open:setText(Theme.icons.lock .. " Locked")
			entry.open:setEnabled(false)
		else
			entry.line.Text = ("%s golden fish"):format(Format.short(price))
			entry.open:setText(
				if pending then "..." else ("Open · %s"):format(Format.short(price))
			)
			entry.open:setStyle("gold")
			entry.open:setEnabled(not pending and fish >= price)
		end
		local luck = if state.crateLuck then state.crateLuck[crate.area] else nil
		local left = MarketLogic.luckLeft(luck, LUCKY_EVERY)
		entry.luck.Text = if crate.golden
			then "Epic or better every time"
			else MarketLogic.luckText(left)
		entry.luck.TextColor3 = if crate.golden or left <= 1
			then Theme.colors.goldDark
			else Theme.modal.subtext
	end
	self._emptyCrates.Visible = shown == 0

	for _, entry: ItemRow in self._itemRows do
		local row = entry.row
		local level = if state.fishPerks then state.fishPerks[row.id] else nil
		local cost = MarketLogic.cost(row, level)
		local pending = self:_pendingFor(row.id)
		if row.kind == "perk" then
			entry.level.Text = ("Level %d / %d"):format(level or 0, row.maxLevel or 1)
		else
			local have = state.lures[row.id]
			entry.level.Text = if have and have > 0 then ("You have %d"):format(have) else ""
		end
		if cost == nil then
			entry.buy:setText("Maxed")
			entry.buy:setEnabled(false)
		else
			entry.buy:setText(if pending then "..." else Format.short(cost))
			entry.buy:setEnabled(not pending and fish >= cost)
		end
	end
end

-- CrateResult from the server: the reveal for a piece, or a refusal ("" and no refund) that frees the button.
function FishMarket.result(
	self: any,
	crateId: string,
	decorId: string,
	duplicate: boolean,
	refund: number
)
	self._pending[crateId] = nil
	if decorId == "" then
		Sound.play("uiError")
		self:_refresh()
		return
	end
	if not self.frame.Visible then
		local decor: Types.DecorDef? = self._decorById[decorId]
		local name = if decor then decor.name else decorId
		self._callbacks.toast(
			if duplicate
				then ("%s again: +%s golden fish back"):format(name, Format.short(refund))
				else ("New piece: %s! Find it in Decor."):format(name)
		)
		return
	end
	self._oddsCover.Visible = false
	self:_playReveal(decorId, duplicate, refund)
	self:_refresh()
end

-- N132: walking away from the stall closes the window, so a press out of range cannot happen.
function FishMarket._checkRange(self: any)
	if not self.frame.Visible then
		return
	end
	local distance = stationDistance()
	if distance and distance > RANGE + CLOSE_SLACK then
		self._callbacks.close()
	end
end

function FishMarket.destroy(self: any)
	self._revealToken += 1
	if self._tick then
		self._tick:Disconnect()
	end
	for _, entry in self._crateCards do
		entry.icon:destroy()
		entry.odds:destroy()
		entry.open:destroy()
	end
	for _, entry in self._itemRows do
		entry.icon:destroy()
		entry.buy:destroy()
	end
	self._reveal.icon:destroy()
	self._reveal.done:destroy()
	self._reveal.use:destroy()
	self._oddsDone:destroy()
	self._cratesTab:destroy()
	self._treatsTab:destroy()
	self._panel:destroy()
end

return FishMarket
