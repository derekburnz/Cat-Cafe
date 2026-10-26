--!strict
-- Short messages that drop in under the cafe pill and fade out. Max four on screen.

local Create = require(script.Parent.Parent.Components.Create)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Toasts = {
	screenGui: ScreenGui,
	show: (self: Toasts, text: string, kind: Types.ToastKind?) -> (),
	destroy: (self: Toasts) -> (),
}

local LIFETIME = 2.4
local MAX_VISIBLE = 4

local KIND_COLORS: { [string]: { bg: Color3, text: Color3 } } = {
	info = { bg = Theme.colors.cocoaDeep, text = Theme.colors.paper },
	good = { bg = Theme.colors.good, text = Theme.colors.goodText },
	warn = { bg = Theme.colors.warn, text = Theme.colors.paper },
	announce = { bg = Theme.colors.gold, text = Theme.colors.goldText },
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
		Position = UDim2.new(0.5, 0, 0, 80),
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
	self._alive = {} :: { TextLabel }
	if parent then
		screenGui.Parent = parent
	end
	return self :: Toasts
end

function Toasts.show(self: any, text: string, kind: Types.ToastKind?)
	local colors = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	self._order += 1
	local toast: TextLabel = Create("TextLabel", {
		Name = "Toast",
		BackgroundColor3 = colors.bg,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 38),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextColor3 = colors.text,
		TextTransparency = 1,
		Text = text,
		LayoutOrder = self._order,
		Parent = self._stack,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(420, 38) }),
	})
	table.insert(self._alive, toast)
	while #self._alive > MAX_VISIBLE do
		local oldest = table.remove(self._alive, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	Tween.to(toast, Tween.FAST, { BackgroundTransparency = 0.08, TextTransparency = 0 })
	task.delay(LIFETIME, function()
		if not toast.Parent then
			return
		end
		local out =
			Tween.to(toast, Tween.SETTLE, { BackgroundTransparency = 1, TextTransparency = 1 })
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
