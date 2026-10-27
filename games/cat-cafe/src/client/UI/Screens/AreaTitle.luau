--!strict
-- Area title card (F39 P1, copied from Pet Simulator 99 and Fisch zone names): the area's name in big outlined
-- letters across the upper screen for two seconds when the player walks or travels into it, with a small line
-- under it. Sits above the HUD and under the modals; never takes input.

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type AreaTitle = {
	show: (self: AreaTitle, key: string, title: string, subtitle: string?, color: Color3?) -> (),
	destroy: (self: AreaTitle) -> (),
}

local HOLD = 2 -- seconds on screen before the fade
local REPEAT_GAP = 4 -- the same area again within this many seconds is ignored (a walk and a travel both report it)
local IN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local AreaTitle = {}
AreaTitle.__index = AreaTitle

function AreaTitle.new(parent: Instance): AreaTitle
	local self = setmetatable({}, AreaTitle) :: any
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeAreaTitle",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 12,
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
	local holder: Frame = Create("Frame", {
		Name = "Card",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 120),
		Visible = false,
		Parent = root,
	})
	self._holder = holder
	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 80),
		FontFace = Theme.fonts.display,
		TextSize = 72,
		TextColor3 = Theme.colors.white,
		TextTransparency = 1,
		Text = "",
		Parent = holder,
	})
	self._titleStroke = Outline.text(self._title, 5)
	self._subtitle = Create("TextLabel", {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 32),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge + 2,
		TextColor3 = Theme.colors.gold,
		TextTransparency = 1,
		Text = "",
		Parent = holder,
	})
	self._subtitleStroke = Outline.text(self._subtitle, 3)
	self._token = 0
	self._lastKey = nil :: string?
	self._lastAt = 0
	return self :: AreaTitle
end

local function fade(self: any, visible: boolean, info: TweenInfo)
	local target = if visible then 0 else 1
	Tween.to(self._title, info, { TextTransparency = target })
	Tween.to(self._titleStroke, info, { Transparency = target })
	Tween.to(self._subtitle, info, { TextTransparency = target })
	Tween.to(self._subtitleStroke, info, { Transparency = target })
end

-- `key` identifies the area for the repeat check; `color` tints the subtitle (the area's own colour).
function AreaTitle.show(self: any, key: string, title: string, subtitle: string?, color: Color3?)
	local now = os.clock()
	if self._lastKey == key and now - self._lastAt < REPEAT_GAP then
		return
	end
	self._lastKey = key
	self._lastAt = now
	self._token += 1
	local token = self._token

	self._title.Text = title:upper()
	self._subtitle.Text = subtitle or ""
	self._subtitle.TextColor3 = color or Theme.colors.gold
	self._holder.Visible = true
	self._holder.Position = UDim2.new(0.5, 0, 0.3, -24)
	Tween.to(self._holder, IN, { Position = UDim2.fromScale(0.5, 0.3) })
	fade(self, true, IN)

	task.delay(HOLD, function()
		if self._token ~= token then
			return
		end
		fade(self, false, OUT)
		task.delay(OUT.Time, function()
			if self._token == token then
				self._holder.Visible = false
			end
		end)
	end)
end

function AreaTitle.destroy(self: any)
	self._token += 1
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return AreaTitle
