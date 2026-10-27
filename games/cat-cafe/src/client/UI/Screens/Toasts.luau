--!strict
-- Short messages that drop in under the tier pill and travel row and fade out. Max four on screen.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Toasts = {
	screenGui: ScreenGui,
	show: (self: Toasts, text: string, kind: Types.ToastKind?, quiet: boolean?) -> (),
	destroy: (self: Toasts) -> (),
}

local LIFETIME = 2.4
local ANNOUNCE_LIFETIME = 4 -- server shout-outs stay a little longer
local MAX_VISIBLE = 4

-- Every kind is white outlined text on a coloured pill with a dark border (simulator notifications).
local KIND_COLORS: { [string]: Color3 } = {
	info = Theme.colors.cocoaDeep,
	good = Theme.colors.good,
	warn = Theme.colors.warn,
	announce = Theme.colors.gold,
}

local Toasts = {}
Toasts.__index = Toasts

function Toasts.new(parent: Instance): Toasts
	local self = setmetatable({}, Toasts) :: any
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeToasts",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
	})
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)
	self._stack = Create("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 148), -- under the tier pill and the travel row
		Size = UDim2.fromOffset(420, 300),
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.screenGui = screenGui
	self._order = 0
	self._alive = {} :: { Frame }
	if parent then
		screenGui.Parent = parent
	end
	return self :: Toasts
end

-- Server shout-outs (Pet Simulator 99 style) take the colour of the first rarity they name, so "Derek caught a
-- Mythical Midnight!" shows on the Mythical colour.
local function announceColor(text: string): Color3?
	local best: Color3? = nil
	local bestAt = math.huge
	for _, rarity in Theme.rarityOrder do
		local at = text:find(rarity, 1, true)
		if at and at < bestAt then
			best = Theme.rarityColor(rarity)
			bestAt = at
		end
	end
	return best
end

-- quiet skips the toast's own sound when the moment already has one (a miss hisses).
function Toasts.show(self: any, text: string, kind: Types.ToastKind?, quiet: boolean?)
	local fill = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local lifetime = LIFETIME
	if kind == "announce" then
		fill = announceColor(text) or fill
		lifetime = ANNOUNCE_LIFETIME
	end
	-- warn covers can't afford, not allowed and bumps: the gentle bonk; everything else the small pop
	if not quiet then
		Sound.play(if kind == "warn" then "uiError" else "uiToast")
	end
	self._order += 1
	local toast: Frame = Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = fill,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		LayoutOrder = self._order,
		Parent = self._stack,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(460, 40) }),
	})
	local border = Outline.border(toast)
	border.Transparency = 1
	local message: TextLabel = Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 1,
		TextColor3 = Theme.colors.white,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		Parent = toast,
	}, { Create("UISizeConstraint", { MaxSize = Vector2.new(424, 40) }) })
	local textOutline = Outline.text(message)
	textOutline.Transparency = 1
	table.insert(self._alive, toast)
	while #self._alive > MAX_VISIBLE do
		local oldest = table.remove(self._alive, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	Tween.to(toast, Tween.FAST, { BackgroundTransparency = 0 })
	Tween.to(border, Tween.FAST, { Transparency = 0 })
	Tween.to(message, Tween.FAST, { TextTransparency = 0 })
	Tween.to(textOutline, Tween.FAST, { Transparency = 0 })
	Tween.popIn(toast, 0.8)
	task.delay(lifetime, function()
		if not toast.Parent then
			return
		end
		Tween.to(border, Tween.SETTLE, { Transparency = 1 })
		Tween.to(message, Tween.SETTLE, { TextTransparency = 1 })
		Tween.to(textOutline, Tween.SETTLE, { Transparency = 1 })
		local out = Tween.to(toast, Tween.SETTLE, { BackgroundTransparency = 1 })
		out.Completed:Once(function()
			local index = table.find(self._alive, toast)
			if index then
				table.remove(self._alive, index)
			end
			toast:Destroy()
		end)
	end)
end

function Toasts.destroy(self: any)
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return Toasts
