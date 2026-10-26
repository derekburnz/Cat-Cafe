--!strict
-- Centre-screen popups that sit above the modals: "Cat found" celebration and "While you were away".
-- Only one popup shows at a time; others queue.

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Popups = {
	screenGui: ScreenGui,
	showCatFound: (self: Popups, def: Types.CatDef, isNew: boolean?) -> (),
	showOffline: (self: Popups, amount: number, seconds: number, onClaim: () -> ()) -> (),
	dismiss: (self: Popups) -> (),
	destroy: (self: Popups) -> (),
}

local CAT_AUTO_CLOSE = 5
local SPARKLES = 10

local Popups = {}
Popups.__index = Popups

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

function Popups.new(parent: Instance): Popups
	local self = setmetatable({}, Popups) :: any
	self._queue = {} :: { () -> () }
	self._busy = false
	self._token = 0
	self._buttons = {} :: { any }

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafePopups",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 40,
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
	self._root = root
	self._uiScale = Scale.bind(root)

	-- Cat found card
	local catCard: Frame = Create("Frame", {
		Name = "CatFound",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 330),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 6) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = 3 }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(380, 330) }),
	})
	self._catCard = catCard
	self._catBanner = text({
		Name = "Banner",
		BackgroundColor3 = Theme.rarity.Common.color,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 44),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.colors.white,
		Text = "CAT FOUND",
		Parent = catCard,
	})
	Create(
		"UICorner",
		{ CornerRadius = UDim.new(0, Theme.sizes.radius + 6), Parent = self._catBanner }
	)
	self._catArt = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(96, 96),
		Parent = catCard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.paper, Thickness = 4 }),
	})
	self._catGlyph = text({
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 44,
		TextColor3 = Theme.colors.paper,
		Text = "",
		Parent = self._catArt,
	})
	self._catName = text({
		Name = "Name",
		Position = UDim2.fromOffset(16, 166),
		Size = UDim2.new(1, -32, 0, 32),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle,
		Text = "",
		Parent = catCard,
	})
	self._catMeta = text({
		Name = "Meta",
		Position = UDim2.fromOffset(16, 200),
		Size = UDim2.new(1, -32, 0, 22),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.good,
		FontFace = Theme.fonts.bodyBold,
		Text = "",
		Parent = catCard,
	})
	self._catDesc = text({
		Name = "Description",
		Position = UDim2.fromOffset(16, 224),
		Size = UDim2.new(1, -32, 0, 40),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "",
		Parent = catCard,
	})
	table.insert(
		self._buttons,
		Button.new({
			name = "Ok",
			text = "Nice!",
			style = "primary",
			size = UDim2.fromOffset(160, Theme.sizes.touchMin + 4),
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -14),
			parent = catCard,
			onClick = function()
				self:dismiss()
			end,
		})
	)
	self._sparkles = {} :: { Frame }
	for _ = 1, SPARKLES do
		table.insert(
			self._sparkles,
			Create("Frame", {
				Name = "Sparkle",
				BackgroundColor3 = Theme.colors.gold,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 108),
				Size = UDim2.fromOffset(10, 10),
				Rotation = 45,
				Visible = false,
				ZIndex = 3,
				Parent = catCard,
			})
		)
	end

	-- Offline earnings card
	local offlineCard: Frame = Create("Frame", {
		Name = "Offline",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 260),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 6) }),
		Create("UIStroke", { Color = Theme.colors.caramel, Thickness = 3 }),
	})
	self._offlineCard = offlineCard
	text({
		Name = "Title",
		Position = UDim2.fromOffset(16, 18),
		Size = UDim2.new(1, -32, 0, 30),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle - 2,
		Text = "While you were away",
		Parent = offlineCard,
	})
	self._offlineSub = text({
		Name = "Sub",
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 22),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "",
		Parent = offlineCard,
	})
	self._offlineAmount = text({
		Name = "Amount",
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.new(1, -32, 0, 54),
		FontFace = Theme.fonts.display,
		TextSize = 44,
		TextColor3 = Theme.colors.good,
		Text = "",
		Parent = offlineCard,
	})
	text({
		Name = "Note",
		Position = UDim2.fromOffset(16, 142),
		Size = UDim2.new(1, -32, 0, 40),
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.modal.subtext,
		Text = "Your cats kept serving at a quarter speed, for up to an hour.",
		Parent = offlineCard,
	})
	self._claimButton = Button.new({
		name = "Claim",
		text = "Claim",
		style = "gold",
		size = UDim2.fromOffset(180, Theme.sizes.touchMin + 4),
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -14),
		textSize = Theme.sizes.textBody + 2,
		parent = offlineCard,
		onClick = function()
			local onClaim = self._onClaim
			self._onClaim = nil
			if onClaim then
				onClaim()
			end
			self:dismiss()
		end,
	})
	table.insert(self._buttons, self._claimButton)

	if parent then
		screenGui.Parent = parent
	end
	return self :: Popups
end

function Popups._open(self: any, card: Frame)
	self._busy = true
	self._token += 1
	self.screenGui.Enabled = true
	card.Visible = true
	Tween.popIn(card, 0.8)
	return self._token
end

function Popups._next(self: any)
	self._busy = false
	local job = table.remove(self._queue, 1)
	if job then
		job()
	else
		self.screenGui.Enabled = false
	end
end

function Popups.dismiss(self: any)
	if not self._busy then
		return
	end
	self._token += 1
	self._onClaim = nil
	local card: Frame = if self._catCard.Visible then self._catCard else self._offlineCard
	Tween.popOut(card, function()
		card.Visible = false
		self:_next()
	end)
end

function Popups.showCatFound(self: any, def: Types.CatDef, isNew: boolean?)
	local function run()
		local token = self:_open(self._catCard)
		local rarity = def.rarity
		self._catBanner.Text = if isNew
			then ("NEW %s CAT!"):format(rarity:upper())
			else ("%s CAT CAUGHT"):format(rarity:upper())
		self._catBanner.BackgroundColor3 = Theme.rarityColor(rarity)
		self._catBanner.TextColor3 = Theme.rarityTextColor(rarity)
		self._catCard.UIStroke.Color = Theme.rarityColor(rarity)
		local rgb = def.color
		self._catArt.BackgroundColor3 = if rgb and #rgb >= 3
			then Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			else Theme.rarityColor(rarity)
		self._catGlyph.Text = def.name:sub(1, 1)
		self._catName.Text = def.name
		self._catMeta.Text = Format.rate(def.incomePerSecond)
			.. (if def.favoriteSpot then "  ·  loves the " .. def.favoriteSpot else "")
		self._catDesc.Text = def.description or ""
		-- sparkles burst from the portrait
		for index, sparkle in self._sparkles do
			sparkle.Visible = true
			sparkle.BackgroundColor3 = if index % 2 == 0
				then Theme.colors.gold
				else Theme.rarityColor(rarity)
			sparkle.BackgroundTransparency = 0
			sparkle.Position = UDim2.new(0.5, 0, 0, 108)
			local angle = (index / SPARKLES) * math.pi * 2
			local distance = 90 + (index % 3) * 20
			Tween.to(sparkle, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(
					0.5,
					math.cos(angle) * distance,
					0,
					108 + math.sin(angle) * distance * 0.6
				),
				BackgroundTransparency = 1,
				Rotation = 45 + 180,
			})
		end
		task.delay(CAT_AUTO_CLOSE, function()
			if self._token == token then
				self:dismiss()
			end
		end)
	end
	if self._busy then
		table.insert(self._queue, run)
	else
		run()
	end
end

function Popups.showOffline(self: any, amount: number, seconds: number, onClaim: () -> ())
	local function run()
		self:_open(self._offlineCard)
		self._onClaim = onClaim
		self._offlineSub.Text = ("Gone for %s"):format(Format.duration(seconds))
		self._offlineAmount.Text = "+" .. Format.money(amount)
	end
	if self._busy then
		table.insert(self._queue, run)
	else
		run()
	end
end

function Popups.destroy(self: any)
	for _, button in self._buttons do
		button:destroy()
	end
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return Popups
