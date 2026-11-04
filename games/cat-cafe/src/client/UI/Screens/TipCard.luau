--!strict
-- A context tip's card (F87, easy-start.md section 3): one line with a glyph, sliding down from the top centre under
-- Roblox's top bar, over the clear band the lighter HUD keeps and above the toasts. It needs no press: a thin bar
-- along its foot drains over the card's seconds and it slides away, or a tap anywhere on it sends it away at once.
-- Components/TipQueue decides which tip and when; this only shows one.
--   show(text, icon, seconds, onDone)   onDone(tapped) once the card has gone
--   hide()                              sends a showing card away as if its time ran out
--   isShowing() -> boolean

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

export type TipCard = {
	screenGui: ScreenGui,
	show: (
		self: TipCard,
		text: string,
		icon: string,
		seconds: number,
		onDone: (tapped: boolean) -> ()
	) -> (),
	hide: (self: TipCard) -> (),
	isShowing: (self: TipCard) -> boolean,
	destroy: (self: TipCard) -> (),
}

local CARD_W = 460
local CARD_H = 76
local TOP = 12 -- under the top bar (the ScreenGui keeps to the safe insets)
local ICON = 50
local BAR_H = 5
local SLIDE = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HIDDEN_Y = -(CARD_H + 20)

local TipCard = {}
TipCard.__index = TipCard

function TipCard.new(parent: Instance): TipCard
	local self = setmetatable({}, TipCard) :: any
	self._token = 0
	self._onDone = nil :: ((tapped: boolean) -> ())?
	self._drain = nil :: Tween?

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeTips",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 11, -- over the HUD (10), under the windows
		Parent = parent,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	local card: TextButton = Create("TextButton", {
		Name = "Card",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		ClipsDescendants = true,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		-- a phone held upright is narrower than the card: the card keeps 16 px from each edge
		Create("UISizeConstraint", { MinSize = Vector2.new(240, CARD_H) }),
	})
	Outline.border(card, Theme.sizes.outline + 1)
	self._card = card

	local disc: Frame = Create("Frame", {
		Name = "Icon",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -1),
		Size = UDim2.fromOffset(ICON, ICON),
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(disc, 2.5)
	self._disc = disc
	self._icon = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextSize = 28,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = disc,
	})
	self._line = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12 + ICON + 12, 0.5, -1),
		Size = UDim2.new(1, -(12 + ICON + 12 + 14), 1, -14),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
		Parent = card,
	})
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Theme.colors.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BAR_H),
		Parent = card,
	})
	self._bar = Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	})

	self._tap = card.Activated:Connect(function()
		if self._onDone ~= nil then
			Sound.play("uiClose")
			self:_close(true)
		end
	end)
	self._resize = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end)
	self:_fit()
	return self :: TipCard
end

-- The card is CARD_W wide, or the screen less 16 px a side when that is narrower.
function TipCard._fit(self: any)
	local scale = math.max(self._uiScale.Scale, 0.01)
	local width = self._card.Parent.AbsoluteSize.X / scale
	self._card.Size = UDim2.fromOffset(math.min(CARD_W, math.max(240, width - 32)), CARD_H)
end

function TipCard.show(
	self: any,
	text: string,
	icon: string,
	seconds: number,
	onDone: (tapped: boolean) -> ()
)
	if self._onDone ~= nil then
		self:_close(false)
	end
	self._token += 1
	local token = self._token
	self._onDone = onDone
	self._line.Text = text
	self._icon.Text = icon
	-- #1258: the luck tip shows the luck chip's look, the clean clover (black outline drawn in) on the dark green circle
	-- with no gold round it; the other tips keep their glyph on the gold disc
	local luck = icon == Theme.icons.luck
	self._disc.BackgroundColor3 = if luck then Theme.luck.circle else Theme.colors.gold
	IconArt.set(self._icon, if luck then icon else nil, 0.82)
	local card: TextButton = self._card
	card.Visible = true
	local bar: Frame = self._bar
	bar.Size = UDim2.fromScale(1, 1)
	if GuiService.ReducedMotionEnabled then
		card.Position = UDim2.new(0.5, 0, 0, TOP)
	else
		card.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
		TweenService:Create(card, SLIDE, { Position = UDim2.new(0.5, 0, 0, TOP) }):Play()
	end
	Sound.play("uiHint")
	local drain = TweenService:Create(
		bar,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	self._drain = drain
	drain:Play()
	task.delay(seconds, function()
		if self._token == token then
			self:_close(false)
		end
	end)
end

function TipCard._close(self: any, tapped: boolean)
	local onDone: ((tapped: boolean) -> ())? = self._onDone
	if onDone == nil then
		return
	end
	self._onDone = nil
	self._token += 1
	local token = self._token
	local drain: Tween? = self._drain
	if drain then
		drain:Cancel()
		self._drain = nil
	end
	local card: TextButton = self._card
	if GuiService.ReducedMotionEnabled then
		card.Visible = false
	else
		local out =
			TweenService:Create(card, SLIDE_OUT, { Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) })
		out.Completed:Once(function()
			if self._token == token then
				card.Visible = false
			end
		end)
		out:Play()
	end
	onDone(tapped)
end

function TipCard.hide(self: any)
	self:_close(false)
end

function TipCard.isShowing(self: any): boolean
	return self._onDone ~= nil
end

function TipCard.destroy(self: any)
	self._token += 1
	self._onDone = nil
	self._tap:Disconnect()
	self._resize:Disconnect()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return TipCard
