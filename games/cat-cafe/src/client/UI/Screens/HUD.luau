--!strict
-- Always-on overlay in the simulator layout (docs/design/cat-cafe/ui-contract.md, HUD v3):
--   top left      money and income
--   top centre    cafe tier pill
--   top right     small icon buttons (Invite) and the day and night clock chip, the next goal card under them
--   left          big pill buttons: Cats, Index, Upgrades, Decor, with key caps and red "!" dots
--   bottom centre Equip Best, the big gold My Cafe teleport, Alley and Areas; above them the carry banner with
--                 its red Drop button, and the tutorial strip above that
--   bottom right  the bait bowl chip, once the Bait bowl upgrade is owned
-- Laid out in design pixels under one UIScale from Scale.bind.
--
-- Roblox terms: SocialService:PromptGameInvite opens Roblox's own invite-friends window; the game only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local GoalCard = require(script.Parent.GoalCard)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local Notices = require(script.Parent.Parent.Notices)
local Outline = require(script.Parent.Parent.Components.Outline)
local RankUp = require(script.Parent.RankUp)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	openScreen: (name: Types.ScreenName) -> (),
	travel: (destination: string) -> (), -- "home" or an AreaId
	openBait: () -> (), -- the bowl chip opens the bait bowl screen, or the cat waiting at the bowl
	openCollection: (tab: "Index" | "Room") -> (), -- the Collection screen on that tab
	equipBest: () -> (),
	dropCat: () -> (), -- the carry banner's Drop button
}

export type HUD = {
	screenGui: ScreenGui,
	setCatalog: (self: HUD, catalog: Types.Catalog) -> (),
	render: (self: HUD, state: Types.PlayerState) -> (),
	setCarrying: (self: HUD, info: Types.CarryInfo?) -> (),
	setTutorial: (self: HUD, text: string?) -> (),
	setClock: (self: HUD, clock: Types.ClockState?) -> (),
	setBait: (self: HUD, bait: Types.BaitView?, catWaiting: boolean) -> (),
	pressTravel: (self: HUD, destination: string) -> boolean,
	travelResult: (self: HUD, destination: string, ok: boolean) -> (),
	isCarrying: (self: HUD) -> boolean,
	setCatching: (self: HUD, active: boolean) -> (),
	screenOpened: (self: HUD, name: string?) -> (),
	setTipJar: (self: HUD, summary: { ready: number, nextIn: number?, left: number }?) -> (),
	setVisible: (self: HUD, visible: boolean) -> (),
	destroy: (self: HUD) -> (),
}

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local MARGIN = 16
local PILL_W = 176
local PILL_H = 54
local CAFE_HEIGHT = 56
local TRAVEL_W = 128
local TRAVEL_H = 50
local HOME_W = 176
local HOME_H = 62 -- My Cafe stands taller than the rest of the bottom row
local ICON = 52 -- top right icon buttons
local CARRY_W = 420
local CARRY_H = 56
local DROP_W = 104
local HOME_TEXT = "My Cafe"
local HOME_CARRYING_TEXT = "Walk it home" -- the server refuses trips while carrying, so the button says why
-- F19: the server allows one trip per 3 s; the row greys for the same time so a double tap is not refused
local TRAVEL_COOLDOWN: number = Config.TravelCooldownSeconds
-- right column: icon row (52), clock chip (40), then the next goal card; the night tips chip pushes it down
local CLOCK_TOP = MARGIN + ICON + Theme.sizes.gap
local GOAL_TOP = CLOCK_TOP + 40 + Theme.sizes.gap
local NIGHT_CHIP = 24 + 4
-- data-model NightIncomeMultiplier (0.6): tips pay this share at night (F31)
local NIGHT_TIPS: number = Config.NightIncomeMultiplier

local HUD = {}
HUD.__index = HUD

local function hudPanel(name: string, props: { [string]: any }): Frame
	local merged: { [string]: any } = {
		Name = name,
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame: Frame = Create("Frame", merged, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	Outline.border(frame, Theme.sizes.outline, Theme.hud.stroke)
	return frame
end

-- HUD text is the chunky display font with a dark outline, so it reads over any world colour. Wrapped
-- paragraphs (odds details) skip the outline, which muddies small multi-line text.
local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local text: TextLabel = Create("TextLabel", merged)
	if not text.TextWrapped then
		Outline.text(text)
	end
	return text
end

local function keycap(parent: Instance, text: string, position: UDim2, anchor: Vector2?): TextLabel
	local key: TextLabel = Create("TextLabel", {
		Name = "Key",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(22, 22),
		Position = position,
		AnchorPoint = anchor or Vector2.new(),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.ink,
		Text = text,
		ZIndex = 5,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	Outline.border(key, 2)
	return key
end

function HUD.new(parent: Instance, callbacks: Callbacks): HUD
	local self = setmetatable({}, HUD) :: any
	self._callbacks = callbacks
	self._connections = {} :: { RBXScriptConnection }
	self._clockConnection = nil :: RBXScriptConnection?
	self._buttons = {} :: { any }
	self._catalog = nil :: Types.Catalog?
	self._lastMoney = nil :: number?
	-- red dots on the menu tiles: keys seen when each screen was last open (Notices)
	self._dots = {} :: { [string]: Frame }
	self._seen =
		{ Upgrades = {}, Decor = {}, Collection = {} } :: { [string]: { [string]: boolean } }
	self._candidates = nil :: Notices.Candidates?
	self._indexReady = 0 -- Index rewards waiting to be claimed (F48)
	self._collectionPrimed = false
	self._openScreen = nil :: string?

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeHUD",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	})
	self.screenGui = screenGui

	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._root = root
	self._uiScale = Scale.bind(root)

	-- Money panel (top left)
	local money = hudPanel("Money", {
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.fromOffset(276, 80),
		Parent = root,
	})
	-- big gold coin with a dark outline and a shaded face, the simulator currency badge
	local coin: Frame = Create("Frame", {
		Name = "Coin",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(48, 48),
		Parent = money,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		label({
			Size = UDim2.fromScale(1, 1),
			TextSize = 28,
			TextColor3 = Theme.colors.white,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Theme.currencySymbol,
		}),
	})
	Outline.border(coin, Theme.sizes.outline)
	Outline.shade(coin, 0.2)
	self._moneyText = label({
		Name = "Amount",
		Position = UDim2.fromOffset(72, 8),
		Size = UDim2.new(1, -84, 0, 38),
		TextSize = 32,
		Text = Format.money(0),
		Parent = money,
	})
	self._incomeText = label({
		Name = "Income",
		Position = UDim2.fromOffset(72, 46),
		Size = UDim2.new(1, -84, 0, 22),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.income,
		Text = "",
		Parent = money,
	})

	-- Cafe pill (top centre)
	local cafe = hudPanel("Cafe", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, MARGIN),
		Size = UDim2.fromOffset(340, CAFE_HEIGHT),
		Parent = root,
	})
	self._cafeTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.new(1, -32, 0, 24),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Cafe Lv 1",
		Parent = cafe,
	})
	self._cafeSub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(16, 27),
		Size = UDim2.new(1, -32, 0, 15),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = cafe,
	})
	-- chunky XP-style bar: dark trough with an outline, shaded mint fill
	local track: Frame = Create("Frame", {
		Name = "Progress",
		BackgroundColor3 = Theme.colors.ink,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -32, 0, 8),
		Visible = false,
		Parent = cafe,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(track, 1.5)
	self._cafeTrack = track
	self._cafeFill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.mint,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.shade(self._cafeFill, 0.25)
	-- v0.3: with tiers the pill opens the rank up card, and a gold tag shows when it is ready
	local cafeButton: TextButton = Create("TextButton", {
		Name = "Open",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		ZIndex = 3,
		Parent = cafe,
	})
	self._cafeButton = cafeButton
	table.insert(
		self._connections,
		cafeButton.Activated:Connect(function()
			if self._tiersOn then
				callbacks.openScreen("RankUp")
			end
		end)
	)
	-- a tilted red sticker on the pill's corner, the simulator "something to claim" badge; the travel row
	-- sits right under the pill, so nothing hangs below it
	self._rankBadge = Create("TextLabel", {
		Name = "RankReady",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 2),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Rotation = 8,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		Text = "Rank up!",
		Visible = false,
		ZIndex = 4,
		Parent = cafe,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	Outline.text(self._rankBadge)
	self._tiersOn = false

	-- Icon row (top right): small square buttons like the calendar, mail and gear icons of popular simulators.
	-- Gifts opens the Tip Jar (F47) and counts down to the next playtime gift, the gear opens Settings, Invite
	-- opens Roblox's own invite window; Daily and Mail join them as they arrive.
	local icons: Frame = Create("Frame", {
		Name = "Icons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN),
		Size = UDim2.fromOffset(4 * ICON + 3 * Theme.sizes.gap, ICON),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local gifts = Button.new({
		name = "Gifts",
		text = "Gifts",
		icon = Theme.icons.gifts,
		layout = "tile",
		textSize = Theme.sizes.textTiny,
		style = "berry",
		size = UDim2.fromOffset(ICON, ICON),
		layoutOrder = 2,
		parent = icons,
		sound = false, -- the modal swish is the sound
		onClick = function()
			callbacks.openScreen("TipJar")
		end,
	})
	gifts.instance.Visible = false -- until the first TipJarState
	table.insert(self._buttons, gifts)
	self._gifts = gifts
	-- red count of gifts ready to claim, on the tile's top right corner
	local giftDot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		Visible = false,
		ZIndex = 6,
		Parent = gifts.instance,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(giftDot, 2)
	self._giftDot = giftDot
	self._giftCount = label({
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textSmall,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 7,
		Parent = giftDot,
	})
	table.insert(
		self._buttons,
		Button.new({
			name = "Settings",
			text = "Settings",
			icon = Theme.icons.settings,
			layout = "tile",
			textSize = Theme.sizes.textTiny,
			style = "ghost",
			size = UDim2.fromOffset(ICON, ICON),
			layoutOrder = 3,
			parent = icons,
			onClick = function()
				callbacks.openScreen("Settings")
			end,
		})
	)
	table.insert(
		self._buttons,
		Button.new({
			name = "Invite",
			text = "Invite",
			icon = Theme.icons.invite,
			layout = "tile",
			textSize = Theme.sizes.textTiny,
			style = "secondary",
			size = UDim2.fromOffset(ICON, ICON),
			layoutOrder = 4,
			parent = icons,
			onClick = function()
				task.spawn(function()
					local player = Players.LocalPlayer
					local ok, canInvite = pcall(function()
						return SocialService:CanSendGameInviteAsync(player)
					end)
					if ok and canInvite then
						pcall(function()
							SocialService:PromptGameInvite(player)
						end)
					end
				end)
			end,
		})
	)

	-- Clock chip (top right, under the icon row): sun or moon and the time to the next phase (F20)
	local clock = hudPanel("Clock", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP),
		Size = UDim2.fromOffset(150, 40),
		Visible = false,
		Parent = root,
	})
	self._clock = clock
	self._sun = Create("Frame", {
		Name = "Sun",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(24, 24),
		Parent = clock,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 2 }),
	})
	self._moon = Create("Frame", {
		Name = "Moon",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(24, 24),
		ClipsDescendants = true,
		Visible = false,
		Parent = clock,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		-- a second disc offset up and right turns the paper disc into a crescent
		Create("Frame", {
			Name = "Shadow",
			BackgroundColor3 = Theme.hud.panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, -5),
			Size = UDim2.fromOffset(22, 22),
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
	self._clockText = label({
		Name = "Phase",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextSize = 18,
		Text = "",
		Parent = clock,
	})
	-- v0.3 (F31): tips pay less at night, so the chip says by how much
	self._nightTips = hudPanel("NightTips", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, CLOCK_TOP + 40 + 4),
		Size = UDim2.fromOffset(150, 24),
		Visible = false,
		Parent = root,
	})
	label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.sky,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Tips " .. Format.percent(NIGHT_TIPS),
		Parent = self._nightTips,
	})

	-- Next goal card (right, under the clock): the next tier's requirements as bars; a tap opens rank up
	self._goal = GoalCard.new(root, UDim2.new(1, -MARGIN, 0, GOAL_TOP), function()
		callbacks.openScreen("RankUp")
	end)

	-- Menu (left, vertically centred): big pill buttons with an icon, the "Shop / Index" column of popular
	-- simulators. A key cap shows the keyboard shortcut and a red "!" dot says the screen has something new.
	local showKeys = UserInputService.KeyboardEnabled
	type MenuItem = {
		name: string,
		icon: string,
		key: string?,
		style: Button.Style,
		dot: Types.ScreenName?, -- the Notices screen whose news lights this pill's dot
		open: () -> (),
	}
	local menuItems: { MenuItem } = {
		{
			name = "Cats",
			icon = Theme.icons.cats,
			key = "C",
			style = "secondary",
			open = function()
				callbacks.openCollection("Room")
			end,
		},
		{
			name = "Index",
			icon = Theme.icons.collection,
			style = "primary",
			dot = "Collection",
			open = function()
				callbacks.openCollection("Index")
			end,
		},
		{
			name = "Upgrades",
			icon = Theme.icons.upgrades,
			key = "U",
			style = "danger",
			dot = "Upgrades",
			open = function()
				callbacks.openScreen("Upgrades")
			end,
		},
		{
			name = "Decor",
			icon = Theme.icons.decor,
			key = "B",
			style = "gold",
			dot = "Decor",
			open = function()
				callbacks.openScreen("Decor")
			end,
		},
	}
	local menu: Frame = Create("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(PILL_W, #menuItems * PILL_H + (#menuItems - 1) * Theme.sizes.gap),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, item in menuItems do
		local button = Button.new({
			name = item.name,
			text = item.name,
			icon = item.icon,
			style = item.style,
			size = UDim2.fromOffset(PILL_W, PILL_H),
			textSize = Theme.sizes.textLarge,
			layoutOrder = index,
			parent = menu,
			sound = false, -- the modal swish is the sound
			ears = true,
			onClick = item.open,
		})
		local key = item.key
		if showKeys and key then
			keycap(button.face, key, UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5))
		end
		local screen = item.dot
		if screen then
			-- red "!" dot on the pill's top left corner when the screen has something new
			local dot: Frame = Create("Frame", {
				Name = "Dot",
				BackgroundColor3 = Theme.colors.red,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.fromOffset(24, 24),
				Visible = false,
				ZIndex = 6,
				Parent = button.instance,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			Outline.border(dot, 2)
			label({
				Name = "Mark",
				Size = UDim2.fromScale(1, 1),
				TextSize = Theme.sizes.textBody,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "!",
				ZIndex = 7,
				Parent = dot,
			})
			self._dots[screen] = dot
		end
		if item.name == "Index" then
			-- cats found out of all cats, where the old top right cats pill had it
			self._indexCount = label({
				Name = "Count",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(52, 20),
				TextSize = Theme.sizes.textSmall,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = "",
				ZIndex = 5,
				Parent = button.face,
			})
		end
		table.insert(self._buttons, button)
	end

	-- Bait bowl chip (bottom right, F28): what is in the bowl and when the cat comes
	local bowlSlot: TextButton = Create("TextButton", {
		Name = "BowlSlot",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(150, 64),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	self._bowlBorder = Outline.border(bowlSlot, Theme.sizes.outline, Theme.hud.stroke)
	self._bowlSlot = bowlSlot
	self._bait = nil :: Types.BaitView?
	self._catWaiting = false
	self._baitLoop = nil :: RBXScriptConnection?
	self._baitReady = false
	self._bowlName = label({
		Name = "Name",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		Text = "Bait bowl",
		Parent = bowlSlot,
	})
	self._bowlSub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = "Empty · add food",
		Parent = bowlSlot,
	})
	if showKeys then
		keycap(bowlSlot, "F", UDim2.new(1, -6, 0, 6), Vector2.new(1, 0))
	end
	table.insert(
		self._connections,
		bowlSlot.Activated:Connect(function()
			-- the bait screen plays uiOpen itself
			self._callbacks.openBait()
		end)
	)

	-- Bottom row (bottom centre): Equip Best, the big gold My Cafe teleport, Alley and Areas, where Grow a Garden
	-- puts its teleport buttons (features.md F19). The three travel buttons grey out while carrying a cat, since
	-- walking it home is the loop and the server refuses those trips, and for the trip cooldown.
	local travelRow: Frame = Create("Frame", {
		Name = "Travel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		Size = UDim2.fromOffset(HOME_W + 3 * TRAVEL_W + 3 * Theme.sizes.gap, HOME_H),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._travelRow = travelRow
	self._travelButtons = {} :: { [string]: Button.Button }
	self._travelEnabled = {} :: { [string]: boolean }
	self._travelUntil = 0
	self._carryBanner = false
	self._carryState = false
	self._homeCarrying = false
	table.insert(
		self._buttons,
		Button.new({
			name = "EquipBest",
			text = "Equip Best",
			icon = Theme.icons.equipBest,
			style = "berry",
			size = UDim2.fromOffset(TRAVEL_W, TRAVEL_H),
			textSize = Theme.sizes.textBody,
			layoutOrder = 1,
			parent = travelRow,
			onClick = function()
				callbacks.equipBest()
			end,
		})
	)
	type TravelItem = { key: string, name: string, label: string, icon: string, style: Button.Style }
	local travelItems: { TravelItem } = {
		{ key = "home", name = "Cafe", label = HOME_TEXT, icon = Theme.icons.home, style = "gold" },
		{
			key = "alley",
			name = "Alley",
			label = "Alley",
			icon = Theme.icons.alley,
			style = "secondary",
		},
		{
			key = "areas",
			name = "Areas",
			label = "Areas",
			icon = Theme.icons.travel,
			style = "primary",
		},
	}
	for index, item in travelItems do
		local home = item.key == "home"
		local button = Button.new({
			name = item.name,
			text = item.label,
			icon = item.icon,
			style = item.style,
			size = if home
				then UDim2.fromOffset(HOME_W, HOME_H)
				else UDim2.fromOffset(TRAVEL_W, TRAVEL_H),
			textSize = if home then Theme.sizes.textLarge else Theme.sizes.textBody + 1,
			layoutOrder = index + 1,
			parent = travelRow,
			ears = home,
			-- Areas only opens the panel, which swishes; Cafe and Alley click
			sound = if item.key == "areas" then false else nil,
			onClick = function()
				if item.key == "areas" then
					callbacks.openScreen("Areas")
				else
					self:pressTravel(item.key)
				end
			end,
		})
		if showKeys and home then
			keycap(button.face, "H", UDim2.new(1, -6, 0, 6), Vector2.new(1, 0))
		end
		self._travelButtons[item.key] = button
		table.insert(self._buttons, button)
	end

	-- Carry banner (bottom centre, above the bottom row): the cat you carry and a red Drop button (G)
	local carry = hudPanel("Carry", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(MARGIN + HOME_H + Theme.sizes.gap)),
		Size = UDim2.fromOffset(CARRY_W, CARRY_H),
		Visible = false,
		Parent = root,
	})
	self._carry = carry
	self._carryArt = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(36, 36),
		Parent = carry,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._carryTitle = label({
		Name = "Title",
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -(68 + DROP_W), 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		Text = "Carrying a cat",
		Parent = carry,
	})
	self._carrySub = label({
		Name = "Sub",
		Position = UDim2.fromOffset(56, 30),
		Size = UDim2.new(1, -(68 + DROP_W), 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = "Walk home and check in at your door",
		Parent = carry,
	})
	local drop = Button.new({
		name = "Drop",
		text = "Drop",
		icon = Theme.icons.drop,
		style = "close",
		size = UDim2.fromOffset(DROP_W, 40),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = carry,
		onClick = function()
			callbacks.dropCat()
		end,
	})
	if showKeys then
		keycap(drop.face, "G", UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
	end
	table.insert(self._buttons, drop)

	-- Tutorial strip (bottom centre, above the carry banner when both show). It grows to 520 px wide, then wraps
	-- onto a second line (reviewer N94: the step hints run to about 100 characters), growing upwards from the
	-- bottom anchor so the carry banner stacking is unchanged.
	self._tutorial = label({
		Name = "Tutorial",
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Visible = false,
		Parent = root,
	})
	Outline.text(self._tutorial) -- label() skips the outline on wrapped text
	Create("UICorner", { CornerRadius = UDim.new(0, 20), Parent = self._tutorial })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 9),
		Parent = self._tutorial,
	})
	-- one line is 40 px tall; two lines stop at 64, and a longer hint truncates there
	Create(
		"UISizeConstraint",
		{ MinSize = Vector2.new(0, 40), MaxSize = Vector2.new(520, 64), Parent = self._tutorial }
	)

	self:_layoutBottom()

	if parent then
		screenGui.Parent = parent
	end
	return self :: HUD
end

-- What is in the bowl: nil when empty. catWaiting is true while the Tame or Let go card has a cat to show.
function HUD.setBait(self: any, bait: Types.BaitView?, catWaiting: boolean)
	self._bait = bait
	self._catWaiting = catWaiting
	self:_renderBowl()
	local loop: RBXScriptConnection? = self._baitLoop
	if bait == nil or self._baitReady then
		if loop then
			loop:Disconnect()
			self._baitLoop = nil
		end
		return
	end
	if loop then
		return
	end
	local accumulator = 0
	self._baitLoop = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		self:_renderBowl()
		if self._baitReady or self._bait == nil then
			local running: RBXScriptConnection? = self._baitLoop
			if running then
				running:Disconnect()
			end
			self._baitLoop = nil
		end
	end)
end

-- "Bait bowl / Empty · add food", "Tuna / Cat in 7m 42s", then "Cat waiting! / Tap to see it" on gold.
function HUD._renderBowl(self: any)
	local bait: Types.BaitView? = self._bait
	local wasReady = self._baitReady
	local ready = false
	local name = "Bait bowl"
	local sub = "Empty · add food"
	if bait then
		local left = bait.readyAt - Workspace:GetServerTimeNow()
		ready = left <= 0
		local catalog: Types.Catalog? = self._catalog
		if catalog then
			for _, lure in catalog.lures do
				if lure.id == bait.lureId then
					name = lure.name
				end
			end
		end
		if ready then
			name = "Cat waiting!"
			sub = if self._catWaiting then "Tap to see it" else "At your bowl"
		else
			sub = "Cat in " .. Format.duration(math.ceil(left))
		end
	end
	self._baitReady = ready
	self._bowlName.Text = name
	self._bowlName.TextColor3 = if ready then Theme.colors.gold else Theme.hud.text
	self._bowlSub.Text = sub
	self._bowlBorder.Color = if ready then Theme.colors.gold else Theme.hud.stroke
	if ready and not wasReady and self._bowlSlot.Visible then
		Tween.popIn(self._bowlSlot, 0.9)
	end
end

-- Fires the travel callback unless the row is greyed (carrying, or inside the trip cooldown). True when it fired.
function HUD.pressTravel(self: any, destination: string): boolean
	if self:isCarrying() or os.clock() < self._travelUntil then
		return false
	end
	self._callbacks.travel(destination)
	self._travelUntil = os.clock() + TRAVEL_COOLDOWN
	self:_renderTravel()
	task.delay(TRAVEL_COOLDOWN, function()
		if os.clock() >= self._travelUntil then
			self:_renderTravel()
		end
	end)
	return true
end

-- The server's answer (TravelResult). A refusal lifts the cooldown at once and wobbles the button that
-- asked; area trips from the Areas panel wobble the Areas button. The server's toast says why.
function HUD.travelResult(self: any, destination: string, ok: boolean)
	local button: Button.Button? = self._travelButtons[destination] or self._travelButtons.areas
	if not button then
		return
	end
	assert(button, "travel button missing")
	if ok then
		Tween.popIn(button.instance, 0.85)
		return
	end
	self._travelUntil = 0
	self:_renderTravel()
	button.instance.Rotation = -8
	Tween.to(
		button.instance,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Rotation = 0 }
	)
end

-- Carrying comes from two places: the carry banner (UI.setCarrying) and state.carrying.
function HUD.isCarrying(self: any): boolean
	return self._carryBanner or self._carryState
end

-- The server refuses a trip mid catch (N47) and the circles need the screen, so the bottom row steps aside
-- until the catch ends.
function HUD.setCatching(self: any, active: boolean)
	self._travelRow.Visible = not active
	self:_layoutBottom()
end

function HUD._renderTravel(self: any)
	local carrying = self:isCarrying()
	local cooling = os.clock() < self._travelUntil
	for key, button in self._travelButtons do
		-- render runs on every state push, so only touch buttons whose state changed (keeps hover colour)
		local enabled = not carrying and (key == "areas" or not cooling)
		if self._travelEnabled[key] ~= enabled then
			self._travelEnabled[key] = enabled
			button:setEnabled(enabled)
		end
	end
	if self._homeCarrying ~= carrying then
		self._homeCarrying = carrying
		self._travelButtons.home:setText(if carrying then HOME_CARRYING_TEXT else HOME_TEXT)
	end
end

function HUD.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_renderBowl()
end

function HUD.render(self: any, state: Types.PlayerState)
	local catalog: Types.Catalog? = self._catalog

	-- money with a little green flash when it goes up
	self._moneyText.Text = Format.money(state.money)
	if self._lastMoney and state.money > self._lastMoney then
		self._moneyText.TextColor3 = Theme.hud.income
		Tween.to(self._moneyText, Tween.RISE, { TextColor3 = Theme.hud.text })
	end
	self._lastMoney = state.money
	self._carryState = state.carrying ~= nil
	self:_renderTravel()

	-- income comes only from cats in a role slot, so with instances the count skips resting cats
	local catCount = 0
	local distinct = 0
	for _, owned in state.catsOwned do
		catCount += owned.count
		distinct += 1
	end
	if state.cats then
		catCount = 0
		for _, instance in state.cats :: { [string]: Types.CatInstance } do
			if instance.spotId then
				catCount += 1
			end
		end
	end
	if state.collection then
		distinct = 0
		for _ in state.collection :: { [string]: number } do
			distinct += 1
		end
	end
	self._incomeText.Text = ("%s from %d cat%s"):format(
		Format.rate(state.incomePerSecond),
		catCount,
		if catCount == 1 then "" else "s"
	)

	local tierProgress: RankUp.Progress? = nil
	if catalog and catalog.tiers and state.tier then
		tierProgress = RankUp.progress(catalog, state)
	end
	self._tiersOn = tierProgress ~= nil
	self._cafeButton.Active = tierProgress ~= nil
	self._goal:render(tierProgress)
	self:_layoutRight()
	if catalog then
		self:_renderDots(catalog, state)
	end
	if tierProgress then
		self:_renderTier(tierProgress)
		self:_renderBowlSlot(state)
		local total = if catalog then #catalog.cats else 0
		self._indexCount.Text = ("%d/%d"):format(distinct, total)
		return
	end
	self._rankBadge.Visible = false

	self._cafeTitle.Text = Format.tier(state.tier, if catalog then catalog.tiers else nil)
	local parts = {}
	if state.tables then
		table.insert(
			parts,
			("%d table%s"):format(state.tables, if state.tables == 1 then "" else "s")
		)
	end
	if state.customers then
		table.insert(
			parts,
			("%d customer%s"):format(state.customers, if state.customers == 1 then "" else "s")
		)
	end
	if state.cafeProgressText then
		table.insert(parts, state.cafeProgressText)
	end
	self._cafeSub.Text = table.concat(parts, "  ·  ")
	self._cafeSub.Visible = #parts > 0
	if state.cafeProgress then
		self._cafeTrack.Visible = true
		self._cafeFill.Size = UDim2.fromScale(math.clamp(state.cafeProgress, 0, 1), 1)
	else
		self._cafeTrack.Visible = false
	end

	local total = if catalog then #catalog.cats else 0
	self._indexCount.Text = ("%d/%d"):format(distinct, total)
	self:_renderBowlSlot(state)
end

-- v0.3 top pill: "Tier 2 · Cozy Cafe", what the next tier still needs, and a gold tag when ready.
function HUD._renderTier(self: any, progress: RankUp.Progress)
	local current = progress.current
	self._cafeTitle.Text = ("Tier %d%s"):format(
		progress.tier,
		if current then "  ·  " .. current.name else ""
	)
	local nextTier = progress.nextTier
	-- the next goal card lists the requirements, so the pill only names the next tier
	local sub = "Top tier"
	if nextTier then
		sub = "Next: " .. nextTier.name
	end
	self._cafeSub.Text = sub
	self._cafeSub.Visible = true
	self._cafeTrack.Visible = nextTier ~= nil
	self._cafeFill.Size = UDim2.fromScale(math.clamp(progress.fraction, 0, 1), 1)
	self._cafeFill.BackgroundColor3 = if progress.ready
		then Theme.colors.gold
		else Theme.colors.mint
	if progress.ready then
		self._cafeSub.Text = "Rank up ready! Tap to see "
			.. (if nextTier then nextTier.name else "")
	end
	local wasVisible = self._rankBadge.Visible
	self._rankBadge.Visible = progress.ready
	if progress.ready and not wasVisible then
		Tween.popIn(self._rankBadge, 0.7)
	end
	-- uiRankReady chimes once per tier, the first time that tier's requirements are all met
	if progress.ready and self._chimedTier ~= progress.tier then
		self._chimedTier = progress.tier
		Sound.play("uiRankReady")
	end
end

-- The bowl chip shows once the Bait bowl upgrade is owned.
function HUD._renderBowlSlot(self: any, state: Types.PlayerState)
	self._bowlSlot.Visible = (state.upgradeLevels.lure_bowl or 0) >= 1
	self:_renderBowl()
end

function HUD.setCarrying(self: any, info: Types.CarryInfo?)
	self._carryBanner = info ~= nil
	self._carryState = info ~= nil -- render agrees on the next state push, since UI.setCarrying clears state too
	self:_renderTravel()
	if info then
		assert(info, "carry info missing")
		local rarity: string = info.rarity or "Common"
		self._carry.Visible = true
		self._carryArt.BackgroundColor3 = Theme.rarityColor(rarity)
		self._carryTitle.Text = "Carrying " .. (info.catName or "a cat")
		self._carryTitle.TextColor3 = Theme.hud.text
		-- hudPanel's outline is the "Border" stroke from Components/Outline
		local border = self._carry:FindFirstChild("Border") :: UIStroke
		border.Color = Theme.rarityColor(rarity)
		Tween.popIn(self._carry, 0.92)
	else
		self._carry.Visible = false
	end
	self:_layoutBottom()
end

function HUD.setTutorial(self: any, text: string?)
	if text and text ~= "" then
		if not self._tutorial.Visible or self._tutorial.Text ~= text then
			Sound.play("uiHint")
		end
		self._tutorial.Text = text
		self._tutorial.Visible = true
		Tween.popIn(self._tutorial, 0.92)
	else
		self._tutorial.Visible = false
	end
	self:_layoutBottom()
end

-- Bottom up: the bottom row, the carry banner, then the tutorial strip, each above the ones showing below it.
function HUD._layoutBottom(self: any)
	local y = -MARGIN
	if self._travelRow.Visible then
		y -= HOME_H + Theme.sizes.gap
	end
	if self._carry.Visible then
		self._carry.Position = UDim2.new(0.5, 0, 1, y)
		y -= CARRY_H + Theme.sizes.gap
	end
	self._tutorial.Position = UDim2.new(0.5, 0, 1, y)
end

local function clockText(phase: Types.ClockPhase, remaining: number): string
	local seconds = math.max(0, math.floor(remaining + 0.5))
	return ("%s  %d:%02d"):format(
		if phase == "night" then "Night" else "Day",
		seconds // 60,
		seconds % 60
	)
end

-- Day and night chip. nil hides it. The countdown runs on Workspace:GetServerTimeNow(), the server's
-- synchronised epoch clock, so it compares with the server's os.time() in PhaseEndsAt and never trusts
-- the device clock (data-model section 1, reviewer S16).
function HUD.setClock(self: any, clock: Types.ClockState?)
	self:_stopClock()
	if not clock then
		self._clock.Visible = false
		self._nightTips.Visible = false
		self:_layoutRight()
		return
	end
	local current: Types.ClockState = clock
	local isNight = current.phase == "night"
	self._sun.Visible = not isNight
	self._moon.Visible = isNight
	self._clockText.TextColor3 = if isNight then Theme.colors.sky else Theme.hud.text
	self._clock.Visible = true
	self._nightTips.Visible = isNight
	self:_layoutRight()
	local function tick()
		self._clockText.Text =
			clockText(current.phase, current.phaseEndsAt - Workspace:GetServerTimeNow())
	end
	tick()
	local accumulated = 0
	self._clockConnection = RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		if accumulated >= 0.25 then
			accumulated = 0
			tick()
		end
	end)
end

-- The goal card sits under the clock, and under the night tips chip when it shows.
function HUD._layoutRight(self: any)
	local top = if self._clock.Visible then GOAL_TOP else CLOCK_TOP
	if self._nightTips.Visible then
		top += NIGHT_CHIP
	end
	self._goal.frame.Position = UDim2.new(1, -MARGIN, 0, top)
end

-- Red dots: a screen's dot shows while it has a key the player has not seen on that screen. Keys seen while
-- the screen is open count as seen, so buying the next level in the shop does not light the dot again.
function HUD._renderDots(self: any, catalog: Types.Catalog, state: Types.PlayerState)
	local candidates = Notices.candidates(catalog, state)
	self._candidates = candidates
	-- cats caught before this session are not news: the first collection we see is all seen
	if state.collection and not self._collectionPrimed then
		self._collectionPrimed = true
		Notices.markSeen(candidates.Collection, self._seen.Collection)
	end
	local open: string? = self._openScreen
	if open and (candidates :: any)[open] then
		Notices.markSeen((candidates :: any)[open], self._seen[open])
	end
	-- the Index's dot also stays lit while an Index reward waits to be claimed (F48), even after the Index is opened
	local _, indexReady = IndexRewards.claimable(catalog, state)
	self._indexReady = indexReady
	for screen, dot in self._dots do
		local keys: { string } = (candidates :: any)[screen] or {}
		local show = Notices.hasNew(keys, self._seen[screen])
			or (screen == "Collection" and indexReady > 0)
		if show and not dot.Visible then
			Tween.popIn(dot, 0.5)
		end
		dot.Visible = show
	end
end

-- The Gifts tile (F47): "Claim!" with a red count while gifts are ready, else the time to the next one, "Done"
-- once all twelve are claimed. nil hides the tile.
function HUD.setTipJar(self: any, summary: { ready: number, nextIn: number?, left: number }?)
	local gifts: Button.Button = self._gifts
	gifts.instance.Visible = summary ~= nil
	if summary == nil then
		return
	end
	local nextIn: number? = summary.nextIn
	local text = if summary.ready > 0
		then "Claim!"
		elseif nextIn ~= nil then TipJarLogic.clock(nextIn)
		else "Done"
	if text ~= self._giftText then
		self._giftText = text
		gifts:setText(text)
	end
	local ready = summary.ready > 0
	if ready and not self._giftDot.Visible then
		Tween.popIn(self._giftDot, 0.5)
	end
	self._giftDot.Visible = ready
	self._giftCount.Text = tostring(summary.ready)
end

-- From the modal's changed signal: opening a screen marks what it shows as seen and clears its dot.
function HUD.screenOpened(self: any, name: string?)
	self._openScreen = name
	local candidates: Notices.Candidates? = self._candidates
	if name and candidates and (candidates :: any)[name] then
		Notices.markSeen((candidates :: any)[name], self._seen[name])
		local dot: Frame? = self._dots[name]
		if dot then
			dot.Visible = name == "Collection" and (self._indexReady or 0) > 0
		end
	end
end

function HUD._stopClock(self: any)
	local connection: RBXScriptConnection? = self._clockConnection
	if connection then
		connection:Disconnect()
		self._clockConnection = nil
	end
end

function HUD.setVisible(self: any, visible: boolean)
	self.screenGui.Enabled = visible
end

function HUD.destroy(self: any)
	self:_stopClock()
	local baitLoop: RBXScriptConnection? = self._baitLoop
	if baitLoop then
		baitLoop:Disconnect()
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, button in self._buttons do
		button:destroy()
	end
	self._goal:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return HUD
