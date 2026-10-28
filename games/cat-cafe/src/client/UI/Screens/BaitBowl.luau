--!strict
-- Bait bowl screen (F28, data-model section 8): what is in your bowl and every food you can put in it. A food
-- goes in with Use from anywhere, F included (Derek 2026-10-28); the cat it brings is rolled then and arrives after
-- the wait, even while you are offline, and you choose Tame or Let go when it comes. Every food card shows its
-- five-rarity odds before Buy or Use as one short row, each rarity in its colour (Derek 2026-10-28: "make it simple
-- and easy can click info/details for more"), and Details opens the gold chance, the charm star odds and the
-- per-cat split (the growth thread's rules for random items). Use and Buy are the same size, and Use is the green
-- one, so the screen never nudges toward spending. F69: each food's picture wears its grade badge, its card a border
-- in the grade's colour, and the chip by its name says what it attracts; the bowl shows the food in it. F54: the gold
-- chance has the Index's gold luck in it, and the wait the Big Bowl perk and the Index's faster bait; F73 adds a
-- running Gold Rush, Lucky or Quick Bait Potion's, as the server rolls food set now. F60: food set
-- at night waits half, so by night the empty bowl's wait is the night one and a night bowl counts down behind a moon.
-- Opened by the bowl's prompt (UI.bait.openPicker), the HUD bowl chip or F.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local FoodGrade = require(script.Parent.Parent.Components.FoodGrade)
local FoodOdds = require(script.Parent.Parent.Components.FoodOdds)
local Format = require(script.Parent.Parent.Components.Format)
local IndexRewards = require(script.Parent.Parent.Components.IndexRewards)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PotionLogic = require(script.Parent.Parent.Components.PotionLogic)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	useLure: (lureId: string) -> (),
	buyLure: (lureId: string) -> (),
	openUpgrades: () -> (),
	showCat: () -> (), -- reopens the Tame or Let go card
	close: () -> (),
}

export type BaitBowl = {
	frame: Frame,
	setCatalog: (self: BaitBowl, catalog: Types.Catalog) -> (),
	render: (self: BaitBowl, state: Types.PlayerState) -> (),
	setBait: (self: BaitBowl, bait: Types.BaitView?, catWaiting: boolean) -> (),
	setNight: (self: BaitBowl, night: boolean) -> (),
	destroy: (self: BaitBowl) -> (),
}

local STATUS_HEIGHT = 92
local ROW_HEIGHT = 132 -- room for the odds row to wrap onto a second line on a narrow screen
local BUTTON = Vector2.new(112, Theme.sizes.touchMin)
local ICON = 84 -- the food's picture, as in the dealer's list and the Grow a Garden seed shop
local TEXT_LEFT = ICON + 28
local TEXT_WIDTH = -(TEXT_LEFT + BUTTON.X * 2 + 32)

local BaitBowl = {}
BaitBowl.__index = BaitBowl

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

-- a rarity's odds colour as hex, for FoodOdds.rich
local function rarityHex(rarity: string): string
	return Theme.rarityInk(rarity):ToHex()
end

-- "Attracts Epic": the rarity the food is known for, on paper with a border in that rarity's colour, so the solid
-- badge on the picture stays the food's own grade (F69)
local function attractsChip(parent: Instance, lure: Types.LureDef, order: number): TextLabel
	return Create("TextLabel", {
		Name = "Attracts",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.text,
		Text = FoodGrade.attracts(lure),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		Create("UIStroke", { Color = Theme.rarityColor(lure.attracts), Thickness = 2 }),
	})
end

function BaitBowl.new(callbacks: Callbacks): BaitBowl
	local self = setmetatable({}, BaitBowl) :: any
	self._callbacks = callbacks
	self._rows = {} :: { [string]: any }
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._bait = nil :: Types.BaitView?
	self._catWaiting = false
	self._tier = 0
	self._extras = "" -- the gold and charm line the Details were written with
	self._waitSeconds = FoodOdds.waitSeconds(false, 0)
	self._bigBowl = false
	self._speed = 0 -- the Index's faster bait (F54) plus a running Quick Bait Potion's (F73)
	self._night = false -- the clock's phase (F60: food set at night waits half)
	self._accumulator = 0

	local panel = Panel.new({
		name = "Bait",
		color = Theme.colors.mintDark,
		icon = Theme.upgradeIcons.lure_bowl,
		title = "Bait bowl",
		subtitle = "Put food in and a cat comes to your door",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- Status card: the bowl, what is in it and the countdown
	local status: Frame = Create("Frame", {
		Name = "Status",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, STATUS_HEIGHT),
		Parent = panel.content,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self._statusBorder = Outline.border(status, Theme.sizes.outline)
	local bowlTile: TextLabel = text({
		Name = "Bowl",
		BackgroundColor3 = Theme.colors.caramel,
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(64, 64),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 34,
		Text = Theme.icons.food,
		Parent = status,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bowlTile })
	Outline.border(bowlTile, 2)
	self._bowlTile = bowlTile
	-- F69: the food in the bowl, with its grade badge, in place of the bowl while it waits
	self._bowlFood = ItemIcon.new({
		parent = status,
		size = UDim2.fromOffset(64, 64),
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 12, 0.5, -4),
		name = "Food",
	})
	self._bowlFood.frame.Visible = false
	self._bowlLure = nil :: string?
	self._statusTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(90, 12),
		Size = UDim2.new(1, -250, 0, 26),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.colors.white,
		Parent = status,
	})
	Outline.text(self._statusTitle, 2)
	self._statusSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(90, 40),
		Size = UDim2.new(1, -250, 0, 36),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = status,
	})
	-- countdown bar along the bottom of the status card while a cat is on its way
	self._track = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.cocoa,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 90, 1, -10),
		Size = UDim2.new(1, -250, 0, 8),
		Visible = false,
		Parent = status,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = self._track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._action = Button.new({
		name = "Action",
		text = "",
		style = "gold",
		size = UDim2.fromOffset(140, Theme.sizes.touchMin + 4),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -12, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = status,
		onClick = function()
			self:_pressAction()
		end,
	})
	self._actionKind = nil :: string?

	self._list = Create("ScrollingFrame", {
		Name = "Foods",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, STATUS_HEIGHT + Theme.sizes.gap + 4),
		Size = UDim2.new(1, 0, 1, -(STATUS_HEIGHT + Theme.sizes.gap + 4)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }),
	})

	-- the countdown ticks once a second while the screen is open
	self._tick = RunService.Heartbeat:Connect(function(dt: number)
		if not self.frame.Visible or self._bait == nil then
			return
		end
		self._accumulator += dt
		if self._accumulator >= 1 then
			self._accumulator = 0
			self:_renderStatus()
		end
	end)
	return self :: BaitBowl
end

function BaitBowl._buildRows(self: any)
	for _, row in self._rows do
		row.use:destroy()
		row.buy:destroy()
		row.details:destroy()
		row.icon:destroy()
		row.frame:Destroy()
	end
	table.clear(self._rows)
	self._bowlLure = nil -- the bowl's picture follows the new catalog's food
	local catalog: Types.Catalog? = self._catalog
	if not catalog then
		return
	end
	assert(catalog, "catalog not set; call UI.init first")
	-- shop foods by price, then the night dealer's
	local foods: { Types.LureDef } = table.clone(catalog.lures)
	table.sort(foods, function(a: Types.LureDef, b: Types.LureDef): boolean
		local aDealer = a.source == "dealer"
		local bDealer = b.source == "dealer"
		if aDealer ~= bDealer then
			return bDealer
		end
		return a.cost < b.cost
	end)
	for index, lure in foods do
		local dealer = lure.source == "dealer"
		local row: Frame = Create("Frame", {
			Name = lure.id,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = index,
			Parent = self._list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			-- F69: the card's border in the food's grade colour, like its badge
			Create("UIStroke", {
				Color = Theme.rarityColor(FoodGrade.of(lure)),
				Thickness = Theme.sizes.stroke + 1,
			}),
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local top: Frame = Create("Frame", {
			Name = "Top",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			LayoutOrder = 1,
			Parent = row,
		})
		local icon = ItemIcon.new({
			parent = top,
			size = UDim2.fromOffset(ICON, ICON),
			position = UDim2.fromOffset(12, 12),
		})
		icon:setFood(lure)
		local heading: Frame = Create("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(TEXT_LEFT, 10),
			Size = UDim2.new(1, TEXT_WIDTH, 0, 26),
			Parent = top,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		text({
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textLarge - 2,
			Text = lure.name,
			LayoutOrder = 1,
			Parent = heading,
		})
		attractsChip(heading, lure, 2)
		local count = text({
			Name = "Count",
			Position = UDim2.fromOffset(TEXT_LEFT, 38),
			Size = UDim2.new(1, TEXT_WIDTH, 0, 18),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = Theme.modal.subtext,
			Parent = top,
		})
		local odds = text({
			Name = "Odds",
			Position = UDim2.fromOffset(TEXT_LEFT, 60),
			Size = UDim2.new(1, TEXT_WIDTH, 0, ROW_HEIGHT - 66),
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true,
			Text = FoodOdds.rich(lure.odds, rarityHex),
			Parent = top,
		})
		local use = Button.new({
			name = "Use",
			text = "Use",
			style = "primary",
			size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -(BUTTON.X + 20), 0, 12),
			textSize = Theme.sizes.textBody,
			parent = top,
			onClick = function()
				self._callbacks.useLure(lure.id)
			end,
		})
		-- dealer foods are only sold by the night dealer's cart, so their slot says where to get them
		local buy = Button.new({
			name = "Buy",
			text = if dealer then "Night dealer" else Format.money(lure.cost),
			style = "secondary",
			size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12),
			textSize = if dealer then Theme.sizes.textTiny else Theme.sizes.textBody,
			enabled = not dealer,
			parent = top,
			onClick = function()
				if not dealer then
					self._callbacks.buyLure(lure.id)
				end
			end,
		})
		local details = Button.new({
			name = "Details",
			text = "Details",
			style = "ghost",
			size = UDim2.fromOffset(BUTTON.X * 2 + 8, 34),
			anchorPoint = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 12 + BUTTON.Y + 10),
			textSize = Theme.sizes.textSmall,
			parent = top,
			onClick = function()
				self:_toggleDetail(lure.id)
			end,
		})
		local detail = text({
			Name = "Detail",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextSize = Theme.sizes.textTiny,
			TextColor3 = Theme.modal.subtext,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = "",
			Visible = false,
			LayoutOrder = 2,
			Parent = row,
		})
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 12),
			Parent = detail,
		})
		self._rows[lure.id] = {
			frame = row,
			icon = icon,
			count = count,
			use = use,
			buy = buy,
			details = details,
			detail = detail,
			odds = odds,
			split = nil :: string?, -- the per-cat split for the tier last drawn
			def = lure,
			dealer = dealer,
		}
	end
	self._tier = -1 -- rebuild the split text on the next render
	self._extras = ""
end

function BaitBowl._toggleDetail(self: any, lureId: string)
	local row = self._rows[lureId]
	if not row then
		return
	end
	row.detail.Visible = not row.detail.Visible
	row.details:setText(if row.detail.Visible then "Hide details" else "Details")
end

function BaitBowl.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self:_buildRows()
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

function BaitBowl.setBait(self: any, bait: Types.BaitView?, catWaiting: boolean)
	self._bait = bait
	self._catWaiting = catWaiting
	local state: Types.PlayerState? = self._state
	if state then
		self:render(state)
	end
end

-- F60: by night the empty bowl promises the night wait; a bowl already filling keeps its own readyAt.
function BaitBowl.setNight(self: any, night: boolean)
	if self._night == night then
		return
	end
	self._night = night
	self._waitSeconds = FoodOdds.waitSeconds(self._bigBowl, self._speed, night)
	if self.frame.Visible then
		self:_renderStatus()
	end
end

local function ownsBowl(state: Types.PlayerState): boolean
	return (state.upgradeLevels.lure_bowl or 0) >= 1
end

function BaitBowl.render(self: any, state: Types.PlayerState)
	self._state = state
	if not self.frame.Visible then
		return -- money ticks re-render every screen; this one catches up when it opens
	end
	local catalog: Types.Catalog? = self._catalog
	local tierChanged = catalog ~= nil and state.tier ~= self._tier
	if catalog and tierChanged then
		self._tier = state.tier
		for _, row in self._rows do
			row.split = FoodOdds.split(catalog, row.def, state.tier)
		end
	end
	local totals = if catalog then IndexRewards.totals(catalog, state) else nil
	local boosts = PotionLogic.boosts(catalog, state, Workspace:GetServerTimeNow())
	local fishPerks: { [string]: number } = state.fishPerks or {}
	self._bigBowl = (fishPerks.big_bowl or 0) >= 1
	self._speed = (if totals then totals.baitSpeed else 0) + boosts.baitSpeed
	self._waitSeconds = FoodOdds.waitSeconds(self._bigBowl, self._speed, self._night)
	-- Details: the gold chance with the Index's gold luck (F54) and the running potions (F73) in it and the charm
	-- stars, then the split
	local extras =
		FoodOdds.extras(if totals then totals.goldLuck else 0, boosts.goldLuck, boosts.goldScale)
	if tierChanged or extras ~= self._extras then
		self._extras = extras
		for _, row in self._rows do
			row.detail.Text = extras .. "\n" .. (row.split or "")
		end
	end
	local owned = ownsBowl(state)
	local empty = self._bait == nil
	for lureId, row in self._rows do
		local have = state.lures[lureId] or 0
		if row.dealer and have == 0 then
			row.count.Text = "Sold by the night dealer's cart"
		else
			row.count.Text = if have > 0 then ("You have %d"):format(have) else "None yet"
		end
		row.use:setEnabled(owned and empty and have > 0)
		if not row.dealer then
			row.buy:setEnabled(state.money >= row.def.cost)
		end
	end
	self:_renderStatus()
end

-- The status card's four states: no bowl yet, empty, a cat on its way, and a cat at the bowl.
function BaitBowl._renderStatus(self: any)
	local state: Types.PlayerState? = self._state
	if not state then
		return
	end
	local bait: Types.BaitView? = self._bait
	local title: string
	local sub: string
	local action: string? = nil
	local ready = false
	self._track.Visible = false
	if not ownsBowl(state) then
		title = "No bait bowl yet"
		sub = "Buy the Bait bowl in Upgrades, then put food in it to bring a cat to your door."
		action = "upgrades"
	elseif bait == nil then
		title = "Your bowl is empty"
		local wait = Format.duration(self._waitSeconds)
		sub = if self._night
			then ("%s Night bait: half the wait. Use a food now and a cat comes by in %s."):format(
				Theme.icons.moon,
				wait
			)
			else "Pick a food and press Use. A cat comes by in " .. wait .. ", even if you leave."
	else
		local left = bait.readyAt - Workspace:GetServerTimeNow()
		local foodName = bait.lureId
		local food: Types.LureDef? = nil
		for _, row in self._rows do
			if row.def.id == bait.lureId then
				foodName = row.def.name
				food = row.def
			end
		end
		if self._bowlLure ~= bait.lureId then
			self._bowlLure = bait.lureId
			self._bowlFood:setFood(food, bait.lureId)
		end
		if left > 0 then
			title = foodName .. " is in the bowl"
			local inTime = Format.duration(math.ceil(left))
			sub = if bait.night
				then ("%s Night bait: half the wait. A cat comes by in %s."):format(
					Theme.icons.moon,
					inTime
				)
				else ("A cat comes by in %s. You can leave; it waits for you."):format(inTime)
			-- the bowl's own wait from placedAt, else today's for its phase
			local total = if bait.placedAt
				then bait.readyAt - bait.placedAt
				else FoodOdds.waitSeconds(self._bigBowl, self._speed, bait.night)
			self._track.Visible = true
			self._fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(total, 1), 0, 1), 1)
		else
			ready = true
			title = "A cat is at your bowl!"
			sub = if self._catWaiting
				then "Tame it or let it go. The food is used either way."
				else "Go to your bowl by the door to see who came."
			if self._catWaiting then
				action = "cat"
			end
		end
	end
	self._bowlFood.frame.Visible = bait ~= nil and ownsBowl(state)
	self._bowlTile.Visible = not self._bowlFood.frame.Visible
	self._statusTitle.Text = title
	self._statusTitle.TextColor3 = if ready then Theme.colors.gold else Theme.colors.white
	self._statusSub.Text = sub
	self._statusBorder.Color = if ready then Theme.colors.gold else Theme.colors.outline
	self._actionKind = action
	self._action.instance.Visible = action ~= nil
	if action == "upgrades" then
		self._action:setText("Upgrades")
	elseif action == "cat" then
		self._action:setText("See the cat")
	end
end

function BaitBowl._pressAction(self: any)
	if self._actionKind == "upgrades" then
		self._callbacks.openUpgrades()
	elseif self._actionKind == "cat" then
		self._callbacks.showCat()
	end
end

function BaitBowl.destroy(self: any)
	self._tick:Disconnect()
	for _, row in self._rows do
		row.use:destroy()
		row.buy:destroy()
		row.details:destroy()
		row.icon:destroy()
	end
	self._action:destroy()
	self._bowlFood:destroy()
	self._panel:destroy()
end

return BaitBowl
