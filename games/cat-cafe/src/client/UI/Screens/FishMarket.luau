--!strict
-- Golden Fish Market window (F53, golden-fish.md sections 3 and 4): the fishmonger stall in the street plaza beside
-- the Spin Wheel. Holding E on its "Market" prompt opens it (UI.market.open), so it keeps the HUD clear like the
-- wheel. A fish chip at the top shows the player's golden fish.
--   Crates: one card per crate the player can open or owns: its picture, "You have 2" or its price, the lucky
--   twentieth countdown ("Epic or better in 4 more crates"), Odds and Open. An owned crate opens free; otherwise
--   Open buys one for its price. A zone crate opens with its zone ("Opens at Tier 3"); golden crates show only
--   while owned, since they are never sold.
--   Treats: the Star Treat and the perks, each with what it does, its level and what the next level costs.
--   Fresh Catch (F94, rewards-and-shops.md section 3): by day potions, and now and then a cheaper Classic Crate, for
--   golden fish, from a stock that rolls every 5 minutes, the same on every server (setFreshStock, from
--   FreshCatchStock). Each row shows how many are left for you, its chance of being in stock and Buy; the top card
--   counts down "Fresh catch in 3:12". At night (no stock) it reads "Back at sunrise". Buy fires
--   callbacks.buyFresh(itemId, window). The tab shows only once the shelf is on the server (Config.FreshCatchWindowSeconds).
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
-- F89 (luck-and-rare-moments.md 2b): a Legendary or Mythical piece also plays the big pull card (callbacks.bigPull,
-- Screens/BigPull) as the crate's lid blows open, with "Use it" on it for a new style piece.
-- F103 (crate-reel.md): once shared Config has the CrateReel* numbers, every crate opens with the reel
-- (Screens/CrateReel) instead of the growing card: the same length every time, landing dead centre on the won piece
-- with nothing rarer near the end, a tap skipping to the landing; the prize card pops in with its buttons after the
-- stop, and a Legendary or Mythical's big pull card follows the stop by the crate's shake. Reduce Motion keeps the
-- short fade with no reel.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BigPullLogic = require(script.Parent.Parent.Components.BigPullLogic)
local Button = require(script.Parent.Parent.Components.Button)
local CrateReel = require(script.Parent.CrateReel)
local CrateReelLogic = require(script.Parent.Parent.Components.CrateReelLogic)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local FishCoin = require(script.Parent.Parent.Components.FishCoin)
local Format = require(script.Parent.Parent.Components.Format)
local FreshCatchLogic = require(script.Parent.Parent.Components.FreshCatchLogic)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local MarketLogic = require(script.Parent.Parent.Components.MarketLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
-- #1146: Crates.openRefusal, the server's own in-flight and spam rule for OpenCrate
local Crates = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Crates"))

export type Callbacks = {
	openCrate: (crateId: string) -> (),
	-- Buy 5 on a crate card (#1051, crate-prices.md section 3): banks CrateBundleCount crates, opens none
	buyCrateBundle: ((crateId: string) -> ())?,
	buyItem: (itemId: string) -> (),
	useDecor: (decorId: string) -> (), -- "Use it" on a new style piece in the reveal
	toast: (text: string) -> (), -- a crate result that lands while the window is closed
	close: () -> (),
	buyFresh: ((itemId: string, window: number?) -> ())?, -- Buy on a Fresh Catch row (F94)
	-- a Legendary or Mythical piece's big pull card (F89), with onUse for "Use it" on a new style piece
	bigPull: ((decorId: string, onUse: (() -> ())?) -> ())?,
}

export type FishMarket = {
	frame: Frame,
	setCatalog: (self: FishMarket, catalog: Types.Catalog) -> (),
	render: (self: FishMarket, state: Types.PlayerState) -> (),
	setFreshStock: (self: FishMarket, stock: FreshCatchLogic.Stock?) -> (),
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
	tier: TextLabel, -- "Tier 3" on a zone crate, green once open
	line: TextLabel,
	luck: TextLabel,
	odds: Button.Button,
	open: Button.Button,
	bundle: Button.Button, -- Buy 5 (#1051)
	seen: number?, -- the crate count at the last render, to end a Buy 5 wait
}

type ItemRow = {
	row: Types.FishShopRow,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	level: TextLabel,
	buy: Button.Button,
	seen: number?, -- the perk level or food count at the last render, to tell when a buy has landed
}

type FreshRow = {
	itemId: string,
	frame: Frame,
	icon: ItemIcon.ItemIcon,
	name: TextLabel,
	blurb: TextLabel,
	stock: TextLabel,
	buy: Button.Button,
}

local TAG = "FishMarket"
-- the Fresh Catch shelf is on this server (F94): Gameplay-Engineer's #679 adds its Config
local FRESH_ON = Config.FreshCatchWindowSeconds ~= nil
local FRESH_HEAD = 58
local FRESH_MINUTES = math.max(1, math.floor((Config.FreshCatchWindowSeconds or 300) / 60))
local RANGE: number = Config.FishMarketRange or 14
local CLOSE_SLACK = 2 -- studs past the server's range before the window closes
local LUCKY_EVERY: number = Config.CrateLuckyEvery or 20
local PENDING_SECONDS = 5 -- a pressed Open or Buy waits this long for the server before it can be pressed again
local GATE_SLACK = 0.1 -- #1146: seconds the Open buttons wait past the server's crate spam limit, for network jitter
local REVEAL_SECONDS = 2
local CARD = Vector2.new(196, 300) -- 56 px taller than before #1051, for Buy 5 under Open
local CRATE_BUTTON_H = 42 -- Open and Buy 5: a 37 px face over the lip, a mouse's 36 px tap (#1051)
-- Buy 5 (#1051): CrateBundleCount crates for CrateBundlePrice golden fish, banked; hidden without the Config
local BUNDLE_COUNT: number? = Config.CrateBundleCount
local BUNDLE_PRICE: number? = Config.CrateBundlePrice
local BUNDLE_KEY = "bundle:" -- the pending key of a crate's Buy 5, apart from its Open
local ROW_HEIGHT = 76
local TOP_HEIGHT = 44
local TAB_H = 42 -- a tab or Buy face of 37 px with a mouse; Scale.tapHeight makes it 44 on a phone

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
		blurb = "+5% money a level, forever.", -- F94 section 5: "money", not "tips"
	},
	big_bowl = {
		name = "Big Bowl",
		icon = "🥣",
		-- F95 section 6b (Derek 2026-10-28 17:39: "lower it by 2 min perma"): Config.BigBowlWaitCutSeconds off any bowl
		blurb = "2 minutes off every bait wait, forever.",
	},
	extra_decor_spot = {
		name = "Extra Decor Spot",
		icon = "🪴",
		blurb = "One more spot for furniture or decorations a level.",
	},
}

local FishMarket = {}
FishMarket.__index = FishMarket

-- The gold fish before a price (F97 section 4), hidden when the button shows no price ("Maxed", "Sold out", "Open")
local function showFish(button: Button.Button, shown: boolean)
	local fish: TextLabel? = button.icon
	if fish then
		fish.Visible = shown
	end
end

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

local function card(props: { [string]: any }): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame: Frame = Create("Frame", merged)
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius), Parent = frame })
	Create("UIStroke", {
		Color = PAL.cardStroke,
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
	self._potionById = {} :: { [string]: PotionLogic.Potion }
	self._crateById = {} :: { [string]: Types.CrateDef }
	self._fresh = nil :: FreshCatchLogic.Stock?
	self._freshRows = {} :: { FreshRow }
	self._freshKey = "" -- the row ids the Fresh Catch list was built for
	self._tab = "Crates"
	self._revealToken = 0
	self._pullToken = 0 -- a newer open drops a big pull card still waiting for its crate's lid

	local panel = Panel.new({
		dark = true, -- #1028
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

	-- the top bar: the tabs on the left, the player's golden fish on the right; on a phone the tabs and the Buy
	-- buttons grow to a 44 px face and the bar with them
	local tabH = Scale.tapHeight(TAB_H, Theme.sizes.buttonDepth)
	local topHeight = math.max(TOP_HEIGHT, tabH + 2)
	self._buyH = tabH
	self._rowH = ROW_HEIGHT + tabH - TAB_H -- room for the stock line over a taller Buy
	local top: Frame = Create("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, topHeight),
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
		size = UDim2.fromOffset(132, tabH),
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
		size = UDim2.fromOffset(196, tabH),
		textSize = Theme.sizes.textBody,
		layoutOrder = 2,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:_showTab("Treats")
		end,
	})
	self._freshTab = Button.new({
		name = "FreshTab",
		text = "Fresh Catch",
		icon = Theme.icons.potion,
		style = "ghost",
		size = UDim2.fromOffset(164, tabH),
		textSize = Theme.sizes.textBody,
		layoutOrder = 3,
		parent = tabs,
		sound = "uiTab",
		onClick = function()
			self:_showTab("Fresh")
		end,
	})
	self._freshTab.instance.Visible = FRESH_ON
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
		TextColor3 = PAL.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = balance,
	})

	local listTop = topHeight + Theme.sizes.gap
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
			ScrollBarImageColor3 = PAL.caramel,
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
		TextColor3 = PAL.subtext,
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

	-- F94: the Fresh Catch shelf, a countdown card on top and a row per item in the window
	self._freshList = scroller("Fresh")
	self._freshList.Visible = false
	Create("UIListLayout", {
		Padding = UDim.new(0, Theme.sizes.gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self._freshList,
	})
	local head = card({
		Name = "Head",
		LayoutOrder = 0,
		BackgroundColor3 = Theme.colors.cocoa,
		Size = UDim2.new(1, 0, 0, FRESH_HEAD),
		Parent = self._freshList,
	})
	self._freshTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.paper,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
	})
	self._freshSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = head,
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
	self._freshList.Visible = tab == "Fresh"
	self._cratesTab:setStyle(if tab == "Crates" then "gold" else "ghost")
	self._treatsTab:setStyle(if tab == "Treats" then "gold" else "ghost")
	self._freshTab:setStyle(if tab == "Fresh" then "gold" else "ghost")
	if tab == "Fresh" then
		self:_renderFresh()
	end
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
		TextColor3 = PAL.subtext,
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
		ScrollBarImageColor3 = PAL.caramel,
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
	local ink = if name == rarity then Theme.rarityLight(rarity) else PAL.text
	local line: Frame = Create("Frame", {
		Name = "Line" .. order,
		LayoutOrder = order,
		BackgroundColor3 = PAL.card,
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
			TextColor3 = PAL.subtext,
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
	-- F88: a plain crate's odds with the player's Luck in them, as shared Crates.oddsFor rolls the next open
	local playerLuck = if state then LuckLogic.current(state, Workspace:GetServerTimeNow()) else 1
	local odds =
		MarketLogic.nextOdds(crate, luck, LUCKY_EVERY, self._goldenOdds[crate.area], playerLuck)
	-- N167: the same test nextOdds makes, not a comparison of the odds tables
	local lucky = not crate.golden
		and self._goldenOdds[crate.area] ~= nil
		and MarketLogic.luckLeft(luck, LUCKY_EVERY) <= 1
	self._oddsTitle.Text = crate.name
	self._oddsNote.Text = if crate.golden
		then "Epic or better every time"
		elseif lucky then "Lucky! Your next crate opens on these golden odds"
		elseif playerLuck > 1 then MarketLogic.luckText(
			MarketLogic.luckLeft(luck, LUCKY_EVERY)
		) .. ". " .. LuckLogic.ICON .. " " .. LuckLogic.text(playerLuck)
		else MarketLogic.luckText(MarketLogic.luckLeft(luck, LUCKY_EVERY))
	self._oddsNote.TextColor3 = if lucky then PAL.gold else PAL.subtext
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
			("%s · +%s money while in use"):format(kindName, Format.percent(bonus)),
			piece.percent
		)
	end
	self._oddsList.CanvasPosition = Vector2.zero
	self._oddsCover.Visible = true
end

-- The reveal: the won piece on a card in its rarity colour, "New!" or the duplicate's refund, then Done.
function FishMarket._buildReveal(self: any, body: Frame)
	-- Later, Nice! and Use it keep a 44 px face on a phone, and the card grows to hold them
	self._revealButtonH = Scale.tapHeight(44, Theme.sizes.buttonDepth)
	self._revealH = 330 + self._revealButtonH - 44
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
		Size = UDim2.fromOffset(300, self._revealH),
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
		TextColor3 = PAL.subtext,
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
		size = UDim2.fromOffset(150, self._revealButtonH),
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
		size = UDim2.fromOffset(130, self._revealButtonH),
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
	-- F103: the reel plays over the window before the card. Closing the window mid reel skips it to the stop
	-- (review N324), so its ticks end with the window and the toast says what was won at once.
	self._reelView = CrateReel.new(body)
	self.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not self.frame.Visible and self._reelView:playing() then
			self._reelView:skip()
		end
	end)
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
	reveal.sheet.Size = UDim2.fromOffset(300, self._revealH)
	reveal.glow.Size = UDim2.fromOffset(300, 300)
	reveal.done.instance.Visible = true
	reveal.use.instance.Visible = self._revealUse == true
end

-- Plays the reveal for the won piece. Its rarity shows from the first frame: the band, the glow and the tile are
-- that colour at once and nothing better is ever shown first (no near miss).
-- After the reel (F103) the card pops in with its buttons at once, and the big pull already left from the stop.
function FishMarket._playReveal(
	self: any,
	decorId: string,
	duplicate: boolean,
	refund: number,
	afterReel: boolean?
)
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
	reveal.detail.Text = ("%s · +%s money while in use"):format(
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
	reveal.status.TextColor3 = if duplicate then PAL.gold else PAL.good
	if not afterReel then
		self:_bigPull(decorId, piece.rarity, offerUse)
	end
	-- two buttons side by side when Use it is offered, else Nice! in the middle
	reveal.done:setText(if offerUse then "Later" else "Nice!")
	reveal.done:setStyle(if offerUse then "ghost" else "primary")
	reveal.done.instance.AnchorPoint = if offerUse then Vector2.new(0, 1) else Vector2.new(0.5, 1)
	reveal.done.instance.Position = if offerUse
		then UDim2.new(0.5, 4, 1, -10)
		else UDim2.new(0.5, 0, 1, -10)
	reveal.done.instance.Size = UDim2.fromOffset(if offerUse then 130 else 150, self._revealButtonH)
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
	reveal.sheet.Size = UDim2.fromOffset(180, math.floor(self._revealH * 0.6))
	reveal.glow.Size = UDim2.fromOffset(120, 120)
	Tween.to(reveal.sheet, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(300, self._revealH),
	})
	if afterReel then
		-- the reel already built up to it: the card pops in ready to press
		self._revealing = false
		reveal.glow.Size = UDim2.fromOffset(300, 300)
		reveal.done.instance.Visible = true
		reveal.use.instance.Visible = offerUse
		return
	end
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

-- F103: the reel for a crate the server already rolled and paid. The strip is drawn here from the crate's own
-- chances (its golden odds for a golden crate), display only. At the stop a Legendary or Mythical's big pull starts its
-- wait for the lid; CrateReelHoldSeconds later the prize card pops in, or a toast when the window closed meanwhile.
function FishMarket._playReel(
	self: any,
	crate: Types.CrateDef,
	decorId: string,
	duplicate: boolean,
	refund: number,
	timing: CrateReelLogic.Timing
)
	self:_hideReveal()
	self._pullToken += 1 -- an older open's big pull card still waiting stays away
	local function rarityOf(id: string): string?
		return DecorPieces.info(self._decorById[id]).rarity
	end
	local pieces = MarketLogic.pieceChances(crate.pieces, rarityOf, crate.odds)
	local won: CrateReelLogic.Tile = { id = decorId, rarity = rarityOf(decorId) or "Common" }
	self._reelView:play({
		tiles = CrateReelLogic.strip(pieces, won, Random.new(), timing),
		timing = timing,
		decorById = self._decorById,
		onLanded = function()
			if not self.frame.Visible then
				return -- closed mid reel: the toast says it, as a result that lands while closed does
			end
			local piece = DecorPieces.info(self._decorById[decorId])
			self:_bigPull(decorId, piece.rarity, not duplicate and DecorPieces.isStyle(piece.kind))
		end,
		onDone = function()
			if self.frame.Visible then
				self:_playReveal(decorId, duplicate, refund, true)
				return
			end
			local decor: Types.DecorDef? = self._decorById[decorId]
			local name = if decor then decor.name else decorId
			self._callbacks.toast(
				if duplicate
					then ("%s again: +%s golden fish back"):format(name, Format.short(refund))
					else ("New piece: %s! Find it in Decor."):format(name)
			)
		end,
	})
end

-- F89: a Legendary or Mythical piece's big pull card lands with the crate's lid, BigPullLogic.CRATE_HOLD after the
-- prize shows (Effects/Market glows and shakes the crate that long). Its "Use it" does what the reveal's does.
function FishMarket._bigPull(self: any, decorId: string, rarity: string?, offerUse: boolean)
	self._pullToken += 1
	local token = self._pullToken
	local callback: ((string, (() -> ())?) -> ())? = self._callbacks.bigPull
	if callback == nil or BigPullLogic.forPiece(rarity) == nil then
		return
	end
	local show: (string, (() -> ())?) -> () = callback
	local onUse = if offerUse
		then function()
			self._callbacks.useDecor(decorId)
			self:_hideReveal()
		end
		else nil
	task.delay(BigPullLogic.CRATE_HOLD, function()
		if self._pullToken == token then
			show(decorId, onUse)
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
	table.clear(self._crateById)
	local crates: { Types.CrateDef } = catalog.crates or {}
	for _, crate in crates do
		self._crateById[crate.id] = crate
		if crate.golden then
			self._goldenOdds[crate.area] = crate.odds
		end
	end
	table.clear(self._potionById)
	for _, potion in PotionLogic.list(catalog) do
		self._potionById[potion.id] = potion
	end
	self:_build()
	self._freshKey = "" -- names and pictures may have changed: rebuild the Fresh Catch rows
	self:_renderFresh()
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
			(crate :: any).asset or ShopIcons.crateModel(crate.id),
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
		-- the crate's tier, shown open or locked (Derek 2026-10-28: "show the Tier still beside even if unlocked it
		-- should be obvious")
		local tier = text({
			Name = "Tier",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.good,
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.colors.white,
			TextTruncate = Enum.TextTruncate.None,
			Visible = false,
			ZIndex = 3,
			Parent = frame,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = tier })
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			Parent = tier,
		})
		Outline.text(tier, 1.5)
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
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		local luck = text({
			Name = "Luck",
			Position = UDim2.fromOffset(8, 130),
			Size = UDim2.new(1, -16, 0, 34),
			TextSize = Theme.sizes.textTiny + 1,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextColor3 = PAL.subtext,
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
			icon = Theme.icons.goldenFish, -- the gold fish before a price, hidden while it opens free or is locked
			style = "primary",
			size = UDim2.new(1, -16, 0, CRATE_BUTTON_H),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -(CRATE_BUTTON_H + 14)),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_open(crate)
			end,
		})
		-- Buy 5 under Open: banks five, the player opens them one at a time with the reel (#1051)
		local bundle = Button.new({
			name = "Buy5",
			text = "Buy 5",
			icon = Theme.icons.goldenFish,
			style = "gold",
			size = UDim2.new(1, -16, 0, CRATE_BUTTON_H),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -8),
			textSize = Theme.sizes.textBody,
			parent = frame,
			onClick = function()
				self:_buyBundle(crate)
			end,
		})
		table.insert(self._crateCards, {
			crate = crate,
			frame = frame,
			icon = icon,
			owned = owned,
			tier = tier,
			line = line,
			luck = luck,
			odds = odds,
			open = open,
			bundle = bundle,
			seen = nil,
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
			Size = UDim2.new(1, 0, 0, self._rowH),
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
			"Legendary", -- F97 section 4: the treats and perks each on a gold tile
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
			TextColor3 = PAL.subtext,
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
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		local buy = Button.new({
			name = "Buy",
			text = "Buy",
			icon = Theme.icons.goldenFish,
			style = "gold",
			size = UDim2.fromOffset(150, self._buyH),
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

-- #1146: the server's OpenCrate rule (Crates.openRefusal) from here: "busy" while any crate's open is waiting for
-- its CrateResult, "spam" for CrateOpenCooldownSeconds after the last open started, else nil.
function FishMarket._crateGate(self: any): ("busy" | "spam")?
	local inFlight = false
	for _, entry: CrateCard in self._crateCards do
		if self:_pendingFor(entry.crate.id) then
			inFlight = true
			break
		end
	end
	return Crates.openRefusal(inFlight, self._lastOpenAt, os.clock(), GATE_SLACK)
end

-- Refreshes once the spam limit since the last open has passed, so the Open buttons stop showing busy on time.
function FishMarket._refreshAfterGate(self: any)
	local last: number? = self._lastOpenAt
	if last == nil then
		return
	end
	local wait = math.max(0, last + Config.CrateOpenCooldownSeconds + GATE_SLACK - os.clock())
		+ 0.02
	task.delay(wait, function()
		if not self._destroyed then
			self:_refresh()
		end
	end)
end

function FishMarket._open(self: any, crate: Types.CrateDef)
	if self._revealing then
		return
	end
	local gate = self:_crateGate()
	if gate == "busy" then
		return
	elseif gate == "spam" then
		-- #1146: a press just after the last open (a Quick open, then the next crate) waits out the short spam limit
		-- and goes then, instead of reaching the server early and being refused
		if self._queued == nil then
			self._queued = crate.id
			local last = self._lastOpenAt :: number
			task.delay(
				math.max(0, last + Config.CrateOpenCooldownSeconds + GATE_SLACK - os.clock()) + 0.02,
				function()
					local queued = self._queued
					self._queued = nil
					if not self._destroyed and queued == crate.id and self.frame.Visible then
						self:_open(crate)
					end
				end
			)
		end
		self:_refresh()
		return
	end
	self._pending[crate.id] = os.clock()
	self._lastOpenAt = os.clock()
	self._callbacks.openCrate(crate.id)
	self:_refresh()
	self:_refreshAfterGate()
end

function FishMarket._buyBundle(self: any, crate: Types.CrateDef)
	local callbacks: Callbacks = self._callbacks
	local buy = callbacks.buyCrateBundle
	local key = BUNDLE_KEY .. crate.id
	if buy == nil or self:_pendingFor(key) then
		return
	end
	self._pending[key] = os.clock()
	buy(crate.id)
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
	-- a crate count that changed ends that crate's Buy 5 wait (the bundle landed, or an open used one)
	for _, entry: CrateCard in self._crateCards do
		local count = if state.crates then state.crates[entry.crate.id] or 0 else 0
		if entry.seen ~= nil and entry.seen ~= count then
			self._pending[BUNDLE_KEY .. entry.crate.id] = nil
		end
		entry.seen = count
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
	local gate = self:_crateGate()
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
		local tier = MarketLogic.openTier(crate, areas)
		entry.tier.Visible = tier ~= nil
		-- grey once locked; the Locked button says the rest (a lock here covered the crate's picture, N306)
		entry.tier.Text = if tier then ("Tier %d"):format(tier) else ""
		entry.tier.BackgroundColor3 = if open then Theme.colors.good else Theme.colors.muted
		local price = crate.price or 0
		-- #1146: every Open shows busy while any crate is in flight or within the short spam limit
		local pending = self:_pendingFor(crate.id) or gate ~= nil or self._queued == crate.id
		showFish(entry.open, count <= 0 and open and not pending)
		if count > 0 then
			entry.line.Text = ("You have %s"):format(Format.commas(count))
			entry.open:setText(if pending then "..." else "Open")
			entry.open:setStyle("primary")
			entry.open:setEnabled(not pending)
		elseif not open then
			entry.line.Text = if tier then ("Opens at Tier %d"):format(tier) else "Locked"
			entry.open:setText(Theme.icons.lock .. " Locked")
			entry.open:setEnabled(false)
		else
			entry.line.Text = ("%s golden fish"):format(Format.short(price))
			-- short of fish: greyed, saying how many more (crate-prices.md section 3; no pop-up)
			local short = fish < price
			showFish(entry.open, open and not pending and not short)
			entry.open:setText(
				if pending
					then "..."
					elseif short then MarketLogic.needText(price - fish)
					else ("Open · %s"):format(Format.short(price))
			)
			entry.open:setStyle("gold")
			entry.open:setEnabled(not pending and not short)
		end
		-- Buy 5: a crate sold at the Market (not golden) whose zone is open
		local bundlePrice = BUNDLE_PRICE
		local canBundle = bundlePrice ~= nil
			and BUNDLE_COUNT ~= nil
			and self._callbacks.buyCrateBundle ~= nil
			and not crate.golden
			and crate.price ~= nil
			and open
		entry.bundle.instance.Visible = canBundle
		if canBundle and bundlePrice then
			local waiting = self:_pendingFor(BUNDLE_KEY .. crate.id)
			local short = fish < bundlePrice
			showFish(entry.bundle, not waiting and not short)
			entry.bundle:setText(
				if waiting
					then "..."
					elseif short then MarketLogic.needText(bundlePrice - fish)
					else ("Buy %d · %s"):format(
						BUNDLE_COUNT :: number,
						Format.short(bundlePrice)
					)
			)
			entry.bundle:setEnabled(not waiting and not short)
		end
		local luck = if state.crateLuck then state.crateLuck[crate.area] else nil
		local left = MarketLogic.luckLeft(luck, LUCKY_EVERY)
		entry.luck.Text = if crate.golden
			then "Epic or better every time"
			else MarketLogic.luckText(left)
		entry.luck.TextColor3 = if crate.golden or left <= 1 then PAL.gold else PAL.subtext
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
		showFish(entry.buy, cost ~= nil and not pending)
		if cost == nil then
			entry.buy:setText("Maxed")
			entry.buy:setEnabled(false)
		else
			entry.buy:setText(if pending then "..." else Format.short(cost))
			entry.buy:setEnabled(not pending and fish >= cost)
		end
	end
	if self._tab == "Fresh" then
		self:_renderFresh()
	end
end

-- Fresh Catch (F94) ---------------------------------------------------------------------------------------------

-- FreshCatchStock from the server: this player's stock by day, nil at night. It answers every buy, so it also ends
-- the row's wait.
function FishMarket.setFreshStock(self: any, stock: FreshCatchLogic.Stock?)
	self._fresh = stock
	if stock then
		for _, item in stock.stock do
			self._pending["fresh:" .. item.itemId] = nil
		end
	end
	self:_renderFresh()
end

function FishMarket._freshName(self: any, itemId: string): string
	local potion: PotionLogic.Potion? = self._potionById[itemId]
	if potion then
		return potion.name
	end
	local crate: Types.CrateDef? = self._crateById[itemId]
	return if crate then crate.name else itemId
end

-- What a row does: the potion's effect and how long it runs, or the crate and its discount off the Market price.
function FishMarket._freshBlurb(self: any, item: FreshCatchLogic.Item): string
	local potion: PotionLogic.Potion? = self._potionById[item.itemId]
	local line: string
	if potion then
		line = ("%s for %d min"):format(potion.effect, potion.minutes)
	else
		local crate: Types.CrateDef? = self._crateById[item.itemId]
		local off = if crate and crate.price then crate.price - item.fish else 0
		line = if off > 0
			then ("%d golden fish off the Market price"):format(off)
			else "A crate for your bank"
	end
	local weights = if Config.FreshCatchAmountWeights
		then Config.FreshCatchAmountWeights[item.itemId]
		else nil
	local chance = FreshCatchLogic.chanceText(FreshCatchLogic.inStock(weights))
	return if chance then line .. " · " .. chance else line
end

function FishMarket._clearFresh(self: any)
	for _, row: FreshRow in self._freshRows do
		row.icon:destroy()
		row.buy:destroy()
		row.frame:Destroy()
	end
	table.clear(self._freshRows)
end

function FishMarket._buildFresh(self: any, stock: FreshCatchLogic.Stock)
	self:_clearFresh()
	for index, item in stock.stock do
		local itemId = item.itemId
		local frame = card({
			Name = itemId,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, self._rowH),
			Parent = self._freshList,
		})
		local icon = ItemIcon.new({
			parent = frame,
			size = UDim2.fromOffset(ROW_HEIGHT - 16, ROW_HEIGHT - 16),
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.new(0, 8, 0.5, 0),
		})
		local potion: PotionLogic.Potion? = self._potionById[itemId]
		icon:set(
			nil,
			if potion then Theme.icons.potion else Theme.icons.crate,
			if potion then "Rare" else "Common",
			if potion then ShopIcons.potion(itemId) else ShopIcons.crate(itemId)
		)
		local name = text({
			Name = "Name",
			Position = UDim2.fromOffset(ROW_HEIGHT, 8),
			Size = UDim2.new(1, -(ROW_HEIGHT + 170), 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = self:_freshName(itemId),
			Parent = frame,
		})
		local blurb = text({
			Name = "Blurb",
			Position = UDim2.fromOffset(ROW_HEIGHT, 30),
			Size = UDim2.new(1, -(ROW_HEIGHT + 170), 0, 36),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Text = self:_freshBlurb(item),
			Parent = frame,
		})
		local stockLabel = text({
			Name = "Stock",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.fromOffset(150, 18),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textTiny + 1,
			TextColor3 = PAL.subtext,
			Parent = frame,
		})
		local buy = Button.new({
			name = "Buy",
			text = "Buy",
			icon = Theme.icons.goldenFish,
			style = "gold",
			size = UDim2.fromOffset(150, self._buyH),
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -10, 1, -8),
			textSize = Theme.sizes.textBody + 1,
			parent = frame,
			onClick = function()
				self:_buyFresh(itemId)
			end,
		})
		table.insert(self._freshRows, {
			itemId = itemId,
			frame = frame,
			icon = icon,
			name = name,
			blurb = blurb,
			stock = stockLabel,
			buy = buy,
		})
	end
end

function FishMarket._buyFresh(self: any, itemId: string)
	local key = "fresh:" .. itemId
	local stock: FreshCatchLogic.Stock? = self._fresh
	if stock == nil or self:_pendingFor(key) then
		return
	end
	local buy: ((itemId: string, window: number?) -> ())? = self._callbacks.buyFresh
	if buy then
		self._pending[key] = os.clock()
		buy(itemId, stock.window)
		self:_renderFresh()
	end
end

-- The countdown card and every row: what is left for you, Buy while you can afford it. At night only the card shows.
function FishMarket._renderFresh(self: any)
	if not self.frame.Visible or self._tab ~= "Fresh" then
		return
	end
	local stock: FreshCatchLogic.Stock? = self._fresh
	if stock == nil then
		self:_clearFresh()
		self._freshKey = ""
		self._freshTitle.Text = "Back at sunrise"
		self._freshSub.Text = "The Fresh Catch sells by day. At night the dealer's cart is in town."
		return
	end
	local current = stock :: FreshCatchLogic.Stock
	local ids: { string } = {}
	for _, item in current.stock do
		table.insert(ids, item.itemId)
	end
	local key = table.concat(ids, ",")
	if key ~= self._freshKey then
		self._freshKey = key
		self:_buildFresh(current)
	end
	local left = current.restocksAt - Workspace:GetServerTimeNow() -- the server's clock, as restocksAt is (S102)
	self._freshTitle.Text = if left > 0
		then FreshCatchLogic.countdown(left)
		else "Fresh catch coming..."
	self._freshSub.Text = ("The same stock on every server. New stock every %d minutes."):format(
		FRESH_MINUTES
	)
	local state: Types.PlayerState? = self._state
	local fish = if state then math.floor(state.goldenFish or 0) else 0
	for index, row: FreshRow in self._freshRows do
		local item = current.stock[index]
		if item == nil then
			continue
		end
		local can = FreshCatchLogic.left(item)
		local none = item.amount == 0
		row.stock.Text = if none
			then "None this time"
			elseif can > 0 then ("x%d left"):format(can)
			else ("You bought %d"):format(item.bought)
		row.stock.TextColor3 = if can > 0 then PAL.good else PAL.subtext
		row.blurb.Text = self:_freshBlurb(item)
		local pending = self:_pendingFor("fresh:" .. item.itemId)
		showFish(row.buy, not pending and not none and can > 0)
		row.buy:setText(
			if pending
				then "..."
				elseif none then "None"
				elseif can == 0 then "Sold out"
				else Format.short(item.fish)
		)
		row.buy:setEnabled(not pending and can > 0 and fish >= item.fish and left > 0)
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
	self:_refreshAfterGate() -- #1146: the Open buttons free up once the spam limit has passed too
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
	-- F103: the reel's shape from shared Config, nil until Config has the CrateReel* numbers
	local reel: CrateReelLogic.Timing? = CrateReelLogic.timing(Config)
	local crate: Types.CrateDef? = self._crateById[crateId]
	if reel ~= nil and crate ~= nil and not GuiService.ReducedMotionEnabled then
		self:_playReel(crate, decorId, duplicate, refund, reel)
	else
		self:_playReveal(decorId, duplicate, refund)
	end
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
	self._destroyed = true
	self._queued = nil
	self._revealToken += 1
	self._pullToken += 1
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
	self._reelView:destroy()
	self._reveal.icon:destroy()
	self._reveal.done:destroy()
	self._reveal.use:destroy()
	self._oddsDone:destroy()
	self._cratesTab:destroy()
	self._treatsTab:destroy()
	self._freshTab:destroy()
	self:_clearFresh()
	self._panel:destroy()
end

return FishMarket
