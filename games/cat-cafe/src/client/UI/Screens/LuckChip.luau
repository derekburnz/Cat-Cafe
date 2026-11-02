--!strict
-- The HUD's Luck chip and its card (F88, luck-and-rare-moments.md section 1d). The chip leads the potion timers' row
-- over the money (Screens/BuffChips), in their look: a round green tile with a four-leaf clover and "Luck x1.3" in
-- outlined white, no panel behind it. It shows from the first Luck source (hidden before that) and on a Lucky Day its
-- text turns gold and a gold ring pulses round the tile (a steady ring with Reduce Motion). A tap opens the card over
-- the counters, as the money's boosts card does: the Luck and what it does, each source with its share and time
-- left (Components/LuckLogic.rows), the food in your bag on your bowl and the next crate, both with the odds the roll
-- uses now (shared Bait.oddsFor then Luck.apply; MarketLogic.nextOdds with Luck). A tap on the card closes it, and
-- so does any window opening (HUD.screenOpened).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local FoodOdds = require(script.Parent.Parent.Components.FoodOdds)
local LuckLogic = require(script.Parent.Parent.Components.LuckLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Bait = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bait"))

export type LuckChip = {
	chip: TextButton,
	card: Frame,
	setCatalog: (self: LuckChip, catalog: Types.Catalog) -> (),
	render: (self: LuckChip, state: Types.PlayerState) -> (),
	toggle: (self: LuckChip) -> (),
	hide: (self: LuckChip) -> (),
	isShown: (self: LuckChip) -> boolean,
	isOpen: (self: LuckChip) -> boolean,
	destroy: (self: LuckChip) -> (),
}

local TILE = 28 -- the potion chips' tile
local CARD_W = 330
local ROW_H = 24
local GREEN = Color3.fromHex("4FAE5C") -- the clover's tile
local PULSE = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local LuckChip = {}
LuckChip.__index = LuckChip

-- outlined HUD text, as the HUD's own label (wrapped text skips the outline, which muddies small lines)
local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 6,
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

-- a rarity's colour as hex for the odds rows, the bright one, since the card is dark
local function rarityHex(rarity: string): string
	return Theme.rarityColor(rarity):ToHex()
end

-- `row`: the potion timers' row (BuffChips.frame), which the chip leads; `root`: the HUD's scaled root, for the
-- card; `cardPosition`: where the card's bottom left corner sits (over the counters, as the boosts card).
-- `onShown` hears when the chip shows or hides, `onOpen` when its card opens (the HUD closes the boosts card).
function LuckChip.new(
	row: Frame,
	root: Frame,
	cardPosition: UDim2,
	onShown: (shown: boolean) -> (),
	onOpen: () -> ()
): LuckChip
	local self = setmetatable({}, LuckChip) :: any
	self._onOpen = onOpen
	self._catalog = nil :: Types.Catalog?
	self._state = nil :: Types.PlayerState?
	self._shown = false
	self._lucky = false
	self._onShown = onShown
	self._said = nil :: string?
	self._loop = nil :: RBXScriptConnection?
	self._pulse = nil :: Tween?
	self._clock = 0

	-- the chip: the whole of it takes the tap, as tall as a potion chip's tap area
	local chip: TextButton = Create("TextButton", {
		Name = "Luck",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, Scale.tapHeight(36)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 0, -- before every potion chip
		Visible = false,
		Parent = row,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local tile: TextLabel = Create("TextLabel", {
		Name = "Tile",
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(TILE, TILE),
		FontFace = Theme.fonts.body,
		TextSize = 17,
		Text = LuckLogic.ICON,
		LayoutOrder = 1,
		Parent = chip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(tile, 2)
	-- the Lucky Day ring, a little wider than the tile
	local ring: Frame = Create("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 1, 8),
		Visible = false,
		Parent = tile,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._ringStroke =
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 3, Parent = ring })
	self._ring = ring
	self._text = label({
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 18,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.None,
		ZIndex = 1,
		LayoutOrder = 2,
		Parent = chip,
	})
	Outline.text(self._text, 2)
	self.chip = chip

	-- the card over the counters
	local card: Frame = Create("Frame", {
		Name = "LuckCard",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = cardPosition,
		Size = UDim2.fromOffset(CARD_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	})
	Outline.border(card, Theme.sizes.outline, Theme.hud.stroke)
	local list: Frame = Create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._title = label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.gold,
		LayoutOrder = 1,
		Parent = list,
	})
	label({
		Name = "Subtitle",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		Text = LuckLogic.SUBTITLE,
		LayoutOrder = 2,
		Parent = list,
	})
	self._rows = Create("Frame", {
		Name = "Sources",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		ZIndex = 6,
		Parent = list,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	local function heading(name: string, order: number): TextLabel
		return label({
			Name = name,
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = Theme.sizes.textSmall + 1,
			LayoutOrder = order,
			Parent = list,
		})
	end
	local function odds(name: string, order: number): TextLabel
		return label({
			Name = name,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			FontFace = Theme.fonts.bodyBold,
			TextSize = Theme.sizes.textSmall,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			RichText = true,
			LayoutOrder = order,
			Parent = list,
		})
	end
	self._foodTitle = heading("FoodTitle", 4)
	self._foodOdds = odds("FoodOdds", 5)
	self._crateTitle = heading("CrateTitle", 6)
	self._crateOdds = odds("CrateOdds", 7)
	label({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Tap to close",
		LayoutOrder = 8,
		Parent = list,
	})
	-- the card's whole content takes the closing tap; sized by scale alone, so the card's AutomaticSize stays put
	local close: TextButton = Create("TextButton", {
		Name = "Close",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = card,
	})
	self.card = card
	self._connections = {
		chip.Activated:Connect(function()
			self:toggle()
		end),
		close.Activated:Connect(function()
			self:hide()
		end),
	}
	return self :: LuckChip
end

function LuckChip.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self._said = nil
	if self.card.Visible then
		self:_renderCard()
	end
end

function LuckChip.isShown(self: any): boolean
	return self._shown
end

function LuckChip.isOpen(self: any): boolean
	return self.card.Visible
end

function LuckChip.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_draw()
end

-- The chip's text, its glow and whether it shows; the open card's rows; the once-a-second tick while a timed source
-- runs, so a potion's time counts down and the chip drops it when it ends.
function LuckChip._draw(self: any)
	local state: Types.PlayerState? = self._state
	local now = Workspace:GetServerTimeNow()
	local shown = state ~= nil and LuckLogic.shown(state, now)
	if state ~= nil and shown then
		self._text.Text = LuckLogic.text(LuckLogic.current(state, now))
		self:_setLucky(LuckLogic.lucky(state, now))
	else
		self:_setLucky(false)
	end
	self.chip.Visible = shown
	if shown ~= self._shown then
		self._shown = shown
		if not shown then
			self:hide()
		end
		self._onShown(shown)
	end
	if self.card.Visible then
		self:_renderCard()
	end
	local timed = false
	if state ~= nil and shown then
		for _, row in LuckLogic.rows(state, now) do
			if row.time ~= nil then
				timed = true
			end
		end
	end
	local loop: RBXScriptConnection? = self._loop
	if timed and loop == nil then
		self._loop = RunService.Heartbeat:Connect(function(dt: number)
			self._clock += dt
			if self._clock >= 1 then
				self._clock = 0
				self:_draw()
			end
		end)
	elseif not timed and loop then
		loop:Disconnect()
		self._loop = nil
	end
end

-- A Lucky Day: gold text and a gold ring round the tile, pulsing unless Reduce Motion is on.
function LuckChip._setLucky(self: any, lucky: boolean)
	if lucky == self._lucky then
		return
	end
	self._lucky = lucky
	self._text.TextColor3 = if lucky then Theme.colors.gold else Theme.colors.white
	self._ring.Visible = lucky
	local pulse: Tween? = self._pulse
	if pulse then
		pulse:Cancel()
		self._pulse = nil
	end
	self._ringStroke.Transparency = 0
	if lucky and not GuiService.ReducedMotionEnabled then
		self._pulse = Tween.to(self._ringStroke, PULSE, { Transparency = 0.75 })
	end
end

function LuckChip.toggle(self: any)
	if self.card.Visible then
		self:hide()
		return
	end
	if self._state == nil or not self._shown then
		return
	end
	self._said = nil
	self._onOpen()
	self:_renderCard()
	self.card.Visible = true
	Tween.popIn(self.card, 0.9)
	Sound.play("uiClick")
end

function LuckChip.hide(self: any)
	self.card.Visible = false
end

function LuckChip._renderCard(self: any)
	local state: Types.PlayerState? = self._state
	if state == nil then
		return
	end
	local catalog: Types.Catalog? = self._catalog
	local now = Workspace:GetServerTimeNow()
	local luck = LuckLogic.current(state, now)
	local rows = LuckLogic.rows(state, now)
	local bowlLevel: number = state.upgradeLevels.lure_bowl or 0
	local food = LuckLogic.food(catalog, state)
	local crate = LuckLogic.crate(catalog, state)
	local foodOdds = if food then FoodOdds.atBowl(food.odds, bowlLevel, luck) else nil
	local crateOdds = if crate then LuckLogic.crateOdds(catalog, state, crate, luck) else nil
	-- the card's words, so it is drawn again only when they change (the money ticks render the HUD five times a
	-- second)
	local parts: { string } = { tostring(luck), tostring(bowlLevel) }
	for _, row in rows do
		table.insert(parts, ("%s=%s=%s"):format(row.name, row.value, row.time or ""))
	end
	local foodTitle = ""
	if food then
		foodTitle = if bowlLevel >= 1
			then ("%s on your %s"):format(food.name, Bait.bowlName(bowlLevel))
			else ("%s in the Bait bowl"):format(food.name)
	end
	local foodText = if foodOdds then FoodOdds.rich(foodOdds, rarityHex) else ""
	local crateTitle = if crate then "Next " .. crate.name else ""
	local crateText = if crateOdds then FoodOdds.rich(crateOdds :: any, rarityHex) else ""
	table.insert(parts, foodTitle .. foodText .. crateTitle .. crateText)
	local said = table.concat(parts, ";")
	if said == self._said then
		return
	end
	self._said = said
	self._title.Text = LuckLogic.ICON .. " " .. LuckLogic.text(luck)
	self._foodTitle.Text = foodTitle
	self._foodTitle.Visible = food ~= nil
	self._foodOdds.Text = foodText
	self._foodOdds.Visible = food ~= nil
	self._crateTitle.Text = crateTitle
	self._crateTitle.Visible = crate ~= nil
	self._crateOdds.Text = crateText
	self._crateOdds.Visible = crate ~= nil
	local holder: Frame = self._rows
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, row in rows do
		local frame: Frame = Create("Frame", {
			Name = row.id,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_H),
			LayoutOrder = order,
			ZIndex = 6,
			Parent = holder,
		})
		label({
			Name = "Name",
			Size = UDim2.new(0.75, 0, 1, 0),
			TextSize = Theme.sizes.textSmall + 1,
			Text = if row.time then ("%s  %s"):format(row.name, row.time) else row.name,
			Parent = frame,
		})
		label({
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.25, 0, 1, 0),
			TextColor3 = Theme.hud.income,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = row.value,
			Parent = frame,
		})
	end
end

function LuckChip.destroy(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	local pulse: Tween? = self._pulse
	if pulse then
		pulse:Cancel()
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.card:Destroy()
	self.chip:Destroy()
end

return LuckChip
