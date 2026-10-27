--!strict
-- Centre-screen popups that sit above the modals: "Cat found" celebration and "While you were away".
-- Only one popup shows at a time; others queue. The cat found card is the Pet Simulator egg hatch reveal
-- (F39 P1): rays in the rarity colour, the cat's own 3D model popping in, a NEW sticker, its charm stars
-- filling one by one and the Purrfect charm bonus.

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Popups = {
	screenGui: ScreenGui,
	showCatFound: (
		self: Popups,
		def: Types.CatDef,
		isNew: boolean?,
		extra: Types.CatFoundExtra?
	) -> (),
	showOffline: (self: Popups, amount: number, seconds: number, onClaim: () -> ()) -> (),
	dismiss: (self: Popups) -> (),
	destroy: (self: Popups) -> (),
}

local CAT_AUTO_CLOSE = 5
local SPARKLES = 10
local RAY_BARS = 6 -- each bar crosses the centre, so 12 rays
local RAY_SPIN = TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
local CARD = Vector2.new(380, 372)
local ART_Y = 116 -- centre of the portrait disc
local STAR_COUNT = 5
local STAR_DELAY = 0.14 -- seconds between stars filling, after the cat pops in
local STAR_START = 0.35
local CAT_POP = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 6) }),
		Create("UIStroke", { Color = Theme.colors.gold, Thickness = Theme.sizes.outline + 1 }),
		Create("UISizeConstraint", { MaxSize = CARD }),
	})
	self._catCard = catCard
	-- slow spinning light rays behind the portrait, the classic simulator reveal
	local rays: Frame = Create("Frame", {
		Name = "Rays",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ART_Y),
		Size = UDim2.fromOffset(230, 230),
		ZIndex = 1,
		Parent = catCard,
	})
	for index = 1, RAY_BARS do
		Create("Frame", {
			Name = "Ray",
			BackgroundColor3 = Theme.colors.gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 22, 1, 0),
			Rotation = (index - 1) * (180 / RAY_BARS),
			ZIndex = 1,
			Parent = rays,
		}, {
			Create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	self._rays = rays
	self._raySpin = nil :: Tween?
	self._catBanner = text({
		Name = "Banner",
		BackgroundColor3 = Theme.rarity.Common.color,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 46),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Text = "CAT FOUND",
		ZIndex = 3,
		Parent = catCard,
	})
	Create(
		"UICorner",
		{ CornerRadius = UDim.new(0, Theme.sizes.radius + 6), Parent = self._catBanner }
	)
	Outline.text(self._catBanner, Theme.sizes.textOutline + 0.5)
	-- a rarity-coloured disc with the cat's own model standing in front of it, a little larger than the disc
	self._catArt = Create("Frame", {
		Name = "Art",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, ART_Y),
		Size = UDim2.fromOffset(112, 112),
		ZIndex = 2,
		Parent = catCard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = Theme.sizes.outline + 1 }),
	})
	Outline.shade(self._catArt, 0.28)
	self._portrait = CatPortrait.new({
		parent = catCard,
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.new(0.5, 0, 0, ART_Y),
		size = UDim2.fromOffset(150, 150),
		zIndex = 3,
	})
	self._portraitScale = Create("UIScale", { Parent = self._portrait.frame })
	-- the tilted red sticker the simulator hatch shows on a first find
	self._newSticker = text({
		Name = "New",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 62, 0, ART_Y - 46),
		Size = UDim2.fromOffset(70, 30),
		Rotation = 12,
		BackgroundColor3 = Theme.colors.red,
		BackgroundTransparency = 0,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.colors.white,
		Text = "NEW!",
		Visible = false,
		ZIndex = 4,
		Parent = catCard,
	})
	Create(
		"UICorner",
		{ CornerRadius = UDim.new(0, Theme.sizes.radiusSmall), Parent = self._newSticker }
	)
	Outline.border(self._newSticker, 2)
	Outline.text(self._newSticker, 2)
	-- the name takes the rarity colour with a dark outline
	self._catName = text({
		Name = "Name",
		Position = UDim2.fromOffset(16, 176),
		Size = UDim2.new(1, -32, 0, 36),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle + 4,
		TextColor3 = Theme.colors.white,
		Text = "",
		ZIndex = 2,
		Parent = catCard,
	})
	Outline.text(self._catName, Theme.sizes.textOutline + 0.5)
	-- charm stars: grey outlines that fill gold one by one
	local starRow: Frame = Create("Frame", {
		Name = "Stars",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 212),
		Size = UDim2.fromOffset(STAR_COUNT * 30, 28),
		Visible = false,
		ZIndex = 2,
		Parent = catCard,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._starRow = starRow
	self._stars = {} :: { TextLabel }
	for index = 1, STAR_COUNT do
		local star = text({
			Name = "Star" .. index,
			LayoutOrder = index,
			Size = UDim2.fromOffset(30, 28),
			FontFace = Theme.fonts.display,
			TextSize = 26,
			TextColor3 = Theme.colors.disabled,
			Text = "★",
			ZIndex = 2,
			Parent = starRow,
		})
		Outline.text(star, 2)
		Create("UIScale", { Parent = star })
		table.insert(self._stars, star)
	end
	self._catMeta = text({
		Name = "Meta",
		ZIndex = 2,
		Position = UDim2.fromOffset(16, 242),
		Size = UDim2.new(1, -32, 0, 22),
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.good,
		FontFace = Theme.fonts.bodyBold,
		Text = "",
		Parent = catCard,
	})
	self._catDesc = text({
		Name = "Description",
		ZIndex = 2,
		Position = UDim2.fromOffset(16, 266),
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
				Position = UDim2.new(0.5, 0, 0, ART_Y),
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
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = Theme.sizes.outline + 1 }),
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
		TextSize = 48,
		TextColor3 = Theme.colors.good,
		Text = "",
		Parent = offlineCard,
	})
	Outline.text(self._offlineAmount, Theme.sizes.textOutline + 1)
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
			local onClaim: (() -> ())? = self._onClaim
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
	local job: (() -> ())? = table.remove(self._queue, 1)
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
	local spin: Tween? = self._raySpin
	if spin then
		spin:Cancel()
		self._raySpin = nil
	end
	Tween.popOut(card, function()
		card.Visible = false
		if card == self._catCard then
			self._portrait:set(nil) -- drops the model and stops its sway
		end
		self:_next()
	end)
end

function Popups.showCatFound(
	self: any,
	def: Types.CatDef,
	isNew: boolean?,
	extra: Types.CatFoundExtra?
)
	local function run()
		local token = self:_open(self._catCard)
		local rarity = def.rarity
		local info: Types.CatFoundExtra = extra or {}
		local shiny = info.shiny == true
		local rarityColor = Theme.rarityColor(rarity)
		local label = (if shiny then "GOLD " else "") .. rarity:upper()
		self._catBanner.Text = if isNew
			then ("NEW %s CAT!"):format(label)
			else ("%s CAT CAUGHT"):format(label)
		self._catBanner.BackgroundColor3 = rarityColor
		self._catCard.UIStroke.Color = if shiny then Theme.colors.gold else rarityColor
		self._catName.TextColor3 = rarityColor
		-- rays in the rarity colour, pure gold for a gold cat
		for _, ray in self._rays:GetChildren() do
			if ray:IsA("Frame") then
				ray.BackgroundColor3 = if shiny
					then Theme.colors.gold
					else rarityColor:Lerp(Theme.colors.gold, 0.35)
			end
		end
		self._rays.Rotation = 0
		self._raySpin = Tween.to(self._rays, RAY_SPIN, { Rotation = 360 })
		self._catArt.BackgroundColor3 = rarityColor
		self._newSticker.Visible = isNew == true
		if isNew then
			Tween.popIn(self._newSticker, 0.4)
		end

		-- the cat pops in from nothing with a little overshoot
		self._portrait:set(def, shiny)
		self._portraitScale.Scale = 0
		Tween.to(self._portraitScale, CAT_POP, { Scale = 1 })

		self._catName.Text = def.name
		self._catMeta.Text = Format.rate(def.incomePerSecond)
			.. (
				if def.favoriteRole then "  ·  loves " .. Format.roleName(def.favoriteRole) else ""
			)
		local charmGain = info.charmGain or 0
		if charmGain > 0 then
			self._catDesc.Text = ("Purrfect catch!  Charm +%d"):format(charmGain)
			self._catDesc.TextColor3 = Theme.colors.goldDark
			self._catDesc.FontFace = Theme.fonts.display
		else
			self._catDesc.Text = def.description or ""
			self._catDesc.TextColor3 = Theme.modal.subtext
			self._catDesc.FontFace = Theme.fonts.body
		end

		-- charm stars fill one by one after the cat lands; without stars the row hides and the text moves up
		local stars = info.stars
		self._starRow.Visible = stars ~= nil
		local textTop = if stars ~= nil then 242 else 214
		self._catMeta.Position = UDim2.fromOffset(16, textTop)
		self._catDesc.Position = UDim2.fromOffset(16, textTop + 24)
		for index, star in self._stars do
			star.TextColor3 = Theme.colors.disabled
			if stars ~= nil and index <= stars then
				task.delay(STAR_START + (index - 1) * STAR_DELAY, function()
					if self._token ~= token then
						return
					end
					star.TextColor3 = Theme.colors.gold
					local scale = star:FindFirstChildOfClass("UIScale")
					if scale then
						scale.Scale = 1.6
						Tween.to(scale, CAT_POP, { Scale = 1 })
					end
				end)
			end
		end

		-- sparkles burst from the portrait
		for index, sparkle in self._sparkles do
			sparkle.Visible = true
			sparkle.BackgroundColor3 = if index % 2 == 0 then Theme.colors.gold else rarityColor
			sparkle.BackgroundTransparency = 0
			sparkle.Position = UDim2.new(0.5, 0, 0, ART_Y)
			local angle = (index / SPARKLES) * math.pi * 2
			local distance = 90 + (index % 3) * 20
			Tween.to(sparkle, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(
					0.5,
					math.cos(angle) * distance,
					0,
					ART_Y + math.sin(angle) * distance * 0.6
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
	self._portrait:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return Popups
