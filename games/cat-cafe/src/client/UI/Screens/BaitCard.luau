--!strict
-- The cat that came to your bait bowl (F28, data-model section 8): its own 3D model on a rarity disc, its name,
-- rarity, charm stars and a shiny sticker, with Tame and Let go. Tame adds it straight to your cat room; Let go
-- sends it on its way. The food is used either way, so Let go asks for a second tap. The server takes the choice
-- only from someone at the bowl (20 studs), so away from it the buttons grey out and the card says where to go.
-- The X hides the card; the bowl chip brings it back while the cat waits.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	resolve: (choice: Types.BaitChoice) -> (),
}

export type BaitCard = {
	screenGui: ScreenGui,
	show: (self: BaitCard, def: Types.CatDef, cat: Types.BaitCat, foodName: string?) -> (),
	hide: (self: BaitCard) -> (),
	isShowing: (self: BaitCard) -> boolean,
	-- true at the bowl, false away from it, nil when the bowl part is unknown (the server decides)
	setNear: (self: BaitCard, near: boolean?) -> (),
	destroy: (self: BaitCard) -> (),
}

local CARD = Vector2.new(360, 448)
local ART_Y = 150
local CONFIRM_SECONDS = 3 -- Let go's second tap must come within this
local PENDING_SECONDS = 6 -- the buttons come back if the server has not answered by then

local BaitCard = {}
BaitCard.__index = BaitCard

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function BaitCard.new(parent: Instance, callbacks: Callbacks): BaitCard
	local self = setmetatable({}, BaitCard) :: any
	self._callbacks = callbacks
	self._near = nil :: boolean?
	self._pending = false
	self._confirmUntil = 0
	self._token = 0

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeBaitCard",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 35, -- over the modals (20), under the cat found reveal (40) that a Tame brings
		Enabled = false,
	})
	self.screenGui = screenGui
	self._backdrop = Create("Frame", {
		Name = "Backdrop",
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 6) }),
	})
	self._card = card
	self._border = Outline.border(card, Theme.sizes.outline + 1)
	self._banner = text({
		Name = "Banner",
		BackgroundColor3 = Theme.rarity.Common.color,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 46),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.colors.white,
		Text = "A CAT CAME TO YOUR BOWL!",
		ZIndex = 3,
		Parent = card,
	})
	Create(
		"UICorner",
		{ CornerRadius = UDim.new(0, Theme.sizes.radius + 6), Parent = self._banner }
	)
	Outline.text(self._banner, Theme.sizes.textOutline + 0.5)
	self._close = Button.new({
		name = "Close",
		text = "X",
		style = "close",
		size = UDim2.fromOffset(Theme.sizes.touchMin, Theme.sizes.touchMin),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -6, 0, 23),
		textSize = Theme.sizes.textLarge + 2,
		zIndex = 5,
		sound = false,
		parent = card,
		onClick = function()
			self:hide()
		end,
	})

	self._disc = Create("Frame", {
		Name = "Disc",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ART_Y),
		Size = UDim2.fromOffset(120, 120),
		ZIndex = 2,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = Theme.sizes.outline + 1 }),
	})
	Outline.shade(self._disc, 0.28)
	self._portrait = CatPortrait.new({
		parent = card,
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.5, 0, 0, ART_Y),
		size = UDim2.fromOffset(170, 170),
		zIndex = 3,
	})
	self._shiny = text({
		Name = "Shiny",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 74, 0, ART_Y - 54),
		Size = UDim2.fromOffset(92, 30),
		Rotation = 12,
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.goldText,
		Text = "✨ SHINY",
		Visible = false,
		ZIndex = 4,
		Parent = card,
	})
	Create(
		"UICorner",
		{ CornerRadius = UDim.new(0, Theme.sizes.radiusSmall), Parent = self._shiny }
	)
	Outline.border(self._shiny, 2)

	self._name = text({
		Name = "Name",
		Position = UDim2.fromOffset(16, 226),
		Size = UDim2.new(1, -32, 0, 36),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle + 4,
		TextColor3 = Theme.colors.white,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
		Parent = card,
	})
	Outline.text(self._name, Theme.sizes.textOutline + 0.5)
	self._stars = text({
		Name = "Stars",
		Position = UDim2.fromOffset(16, 264),
		Size = UDim2.new(1, -32, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = 24,
		TextColor3 = Theme.colors.gold,
		ZIndex = 2,
		Parent = card,
	})
	Outline.text(self._stars, 2)
	self._meta = text({
		Name = "Meta",
		Position = UDim2.fromOffset(16, 294),
		Size = UDim2.new(1, -32, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		ZIndex = 2,
		Parent = card,
	})
	self._hint = text({
		Name = "Hint",
		Position = UDim2.fromOffset(16, 320),
		Size = UDim2.new(1, -32, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		ZIndex = 2,
		Parent = card,
	})

	self._tame = Button.new({
		name = "Tame",
		text = "Tame",
		style = "primary",
		size = UDim2.fromOffset(150, Theme.sizes.touchMin + 8),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(0.5, -6, 1, -16),
		textSize = Theme.sizes.textLarge - 2,
		parent = card,
		onClick = function()
			self:_choose("tame")
		end,
	})
	self._letGo = Button.new({
		name = "LetGo",
		text = "Let go",
		style = "secondary",
		size = UDim2.fromOffset(150, Theme.sizes.touchMin + 8),
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.new(0.5, 6, 1, -16),
		textSize = Theme.sizes.textBody,
		parent = card,
		onClick = function()
			self:_pressLetGo()
		end,
	})

	if parent then
		screenGui.Parent = parent
	end
	return self :: BaitCard
end

function BaitCard.show(self: any, def: Types.CatDef, cat: Types.BaitCat, foodName: string?)
	self._token += 1
	self._pending = false
	self._confirmUntil = 0
	local rarity = def.rarity
	local color = Theme.rarityColor(rarity)
	self._banner.BackgroundColor3 = color
	self._disc.BackgroundColor3 = color
	self._border.Color = color
	self._portrait:set(def)
	self._shiny.Visible = cat.variant == "shiny"
	self._name.Text = cat.name or def.name
	self._name.TextColor3 = if rarity == "Common" then Theme.colors.white else color
	self._stars.Text = Format.stars(cat.stars or 1)
	self._stars.Visible = cat.stars ~= nil
	local metaParts: { string } = { rarity }
	if cat.charm then
		table.insert(metaParts, ("Charm %d"):format(cat.charm))
	end
	table.insert(metaParts, Format.rate(def.incomePerSecond) .. " working")
	self._meta.Text = table.concat(metaParts, "  ·  ")
	self._meta.TextColor3 = Theme.colors.good
	self._foodName = foodName
	self:_renderButtons()

	local wasShowing = self.screenGui.Enabled
	self.screenGui.Enabled = true
	if not wasShowing then
		Sound.play("uiOpen")
		Tween.popIn(self._card, 0.8)
	end
end

function BaitCard._renderButtons(self: any)
	local away = self._near == false
	local foodName: string? = self._foodName
	if away then
		self._hint.Text = "Walk to your bowl by the door to choose."
		self._hint.TextColor3 = Theme.colors.warn
	else
		self._hint.Text = (if foodName then "It came for your " .. foodName .. ". " else "")
			.. "Tame it to add it to your cat room."
		self._hint.TextColor3 = Theme.modal.subtext
	end
	local open = not away and not self._pending
	self._tame:setEnabled(open)
	self._letGo:setEnabled(open)
	if not self._pending then
		self._tame:setText("Tame")
		local confirming = os.clock() < self._confirmUntil
		self._letGo:setText(if confirming then "Sure? Tap again" else "Let go")
		self._letGo:setStyle(if confirming then "danger" else "secondary")
	end
end

function BaitCard._pressLetGo(self: any)
	if os.clock() < self._confirmUntil then
		self:_choose("letgo")
		return
	end
	self._confirmUntil = os.clock() + CONFIRM_SECONDS
	self:_renderButtons()
	local token = self._token
	task.delay(CONFIRM_SECONDS, function()
		if self._token == token and not self._pending then
			self:_renderButtons()
		end
	end)
end

function BaitCard._choose(self: any, choice: Types.BaitChoice)
	if self._pending or self._near == false then
		return
	end
	self._pending = true
	self._confirmUntil = 0
	if choice == "tame" then
		self._tame:setText("Taming...")
	else
		self._letGo:setText("Letting go...")
	end
	self:_renderButtons()
	self._callbacks.resolve(choice)
	-- UI.bait.set(nil) or hideReady closes the card once the server answers; if it never does, try again
	local token = self._token
	task.delay(PENDING_SECONDS, function()
		if self._token == token and self._pending then
			self._pending = false
			self:_renderButtons()
		end
	end)
end

function BaitCard.setNear(self: any, near: boolean?)
	if self._near == near then
		return
	end
	self._near = near
	if self.screenGui.Enabled then
		self:_renderButtons()
	end
end

function BaitCard.isShowing(self: any): boolean
	return self.screenGui.Enabled
end

function BaitCard.hide(self: any)
	if not self.screenGui.Enabled then
		return
	end
	self._token += 1
	local token = self._token
	self._pending = false
	Sound.play("uiClose")
	Tween.popOut(self._card, function()
		if self._token == token then
			self.screenGui.Enabled = false
		end
	end)
end

function BaitCard.destroy(self: any)
	self._token += 1
	self._tame:destroy()
	self._letGo:destroy()
	self._close:destroy()
	self._portrait:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return BaitCard
