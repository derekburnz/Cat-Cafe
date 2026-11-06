--!strict
-- Area title card (F39 P1, copied from Pet Simulator 99 and Fisch zone names): the area's name in big outlined
-- letters across the upper screen for two seconds when the player walks or travels into it, with a small line
-- under it. Sits above the HUD and under the modals; never takes input. `banner` shows a line as written (no
-- capitals forced) for the short night's dusk and sunrise (F66), with a picture left of the line when one is given
-- (#1737: the Night Market's cart in its pink circle, the same as its map marker, in place of the moon emoji).

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

export type AreaTitle = {
	show: (self: AreaTitle, key: string, title: string, subtitle: string?, color: Color3?) -> (),
	-- key, title, subtitle, colour, seconds held, picture (an rbxassetid) left of the title
	banner: (self: AreaTitle, string, string, string?, Color3?, number?, string?) -> (),
	destroy: (self: AreaTitle) -> (),
}

local HOLD = 2 -- seconds on screen before the fade
local PICTURE = 72 -- the banner picture's side, the title's height less a little
local PICTURE_GAP = 10
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
		-- the screen's width less a margin, so a small phone keeps the whole line (the words are centred)
		Size = UDim2.new(1, -32, 0, 120),
		Visible = false,
		Parent = root,
	})
	self._holder = holder
	-- #1737: the title's words and, for a banner that has one, a picture just left of them, centred as a pair
	local row: Frame = Create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 80),
		Parent = holder,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, PICTURE_GAP),
		}),
	})
	self._picture = Create("ImageLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(PICTURE, PICTURE),
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = 1,
		Visible = false,
		Parent = row,
	})
	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X, -- as wide as its words, so the picture sits right beside them
		Size = UDim2.fromOffset(0, 80),
		FontFace = Theme.fonts.display,
		TextSize = 72,
		TextColor3 = Theme.colors.white,
		TextTransparency = 1,
		Text = "",
		Parent = row,
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
	if self._picture.Visible then
		Tween.to(self._picture, info, { ImageTransparency = target })
	end
end

-- `key` identifies the area for the repeat check; `color` tints the subtitle (the area's own colour).
function AreaTitle.show(self: any, key: string, title: string, subtitle: string?, color: Color3?)
	self:_show(key, title:upper(), subtitle, color, HOLD, nil)
end

-- A line as written, held `hold` seconds (HOLD when nil): "Night falls in 15 s!", "Sunrise!".
function AreaTitle.banner(
	self: any,
	key: string,
	title: string,
	subtitle: string?,
	color: Color3?,
	hold: number?,
	picture: string?
)
	self:_show(key, title, subtitle, color, hold or HOLD, picture)
end

function AreaTitle._show(
	self: any,
	key: string,
	title: string,
	subtitle: string?,
	color: Color3?,
	hold: number,
	picture: string?
)
	local now = os.clock()
	if self._lastKey == key and now - self._lastAt < REPEAT_GAP then
		return
	end
	self._lastKey = key
	self._lastAt = now
	self._token += 1
	local token = self._token

	self._title.Text = title
	self._subtitle.Text = subtitle or ""
	self._subtitle.TextColor3 = color or Theme.colors.gold
	local hasPicture = picture ~= nil and picture ~= ""
	self._picture.Image = if hasPicture then picture :: string else ""
	self._picture.ImageTransparency = 0.99 -- drawn, so Roblox fetches it while the banner fades in (IconArt's WAITING)
	self._picture.Visible = hasPicture
	self._holder.Visible = true
	self._holder.Position = UDim2.new(0.5, 0, 0.3, -24)
	Tween.to(self._holder, IN, { Position = UDim2.fromScale(0.5, 0.3) })
	fade(self, true, IN)

	task.delay(hold, function()
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
