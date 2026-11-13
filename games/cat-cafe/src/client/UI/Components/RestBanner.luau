--!strict
-- #3701: the cafe rest banner. One cream pill with the dark outline, a round badge on the left, a big line and a
-- small line (RestBannerLogic.words). It is as wide as its words; past TEXT_MAX they wrap onto a second row, so
-- nothing is ever cut off. Green while the player rests. It fades in and out; nothing on it pulses, points or
-- makes a sound.
--   local banner = RestBanner.new()        a hidden banner; the caller parents banner.frame (Toasts:pin)
--   banner:set("welcome", doubled, 0)      shows a state; `doubled` false in a 2x party
--   banner:set("counting", true, 80)       "2x money in 1:20"
--   banner:set(nil)                        fades it out
--   banner:destroy()
-- The caller decides when: this never asks whether the player is resting.

local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local RestBannerLogic = require(script.Parent.RestBannerLogic)
local Theme = require(script.Parent.Parent.Theme)

local RestBanner = {}
RestBanner.__index = RestBanner

RestBanner.NAME = "RestBanner"
RestBanner.TEXT_MAX = 300 -- px: the lines' widest before they wrap
local BADGE = 38
local BIG, SMALL = 20, 14 -- text sizes
local PAD_LEFT, PAD_RIGHT, PAD_Y, GAP = 10, 16, 7, 10
local ROOM, SPARE = 1.2, 4 -- a line's box over its measured width: a fifth and 4 px
local RESTING = Color3.fromHex("D7F2D0") -- a soft green on which the ink reads as on the cream
local FADE = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

export type RestBanner = {
	frame: CanvasGroup,
	set: (
		self: RestBanner,
		state: RestBannerLogic.State?,
		doubled: boolean?,
		remaining: number?
	) -> (),
	destroy: (self: RestBanner) -> (),
}

local function line(name: string, size: number, order: number, face: Font): TextLabel
	return Create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = face,
		LayoutOrder = order,
		Text = "",
		TextColor3 = Theme.colors.ink,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

-- Sizes a line to its words: as wide as they are up to TEXT_MAX, on one row when they fit and wrapped onto more
-- rows when they do not. Sized by measuring, not AutomaticSize, so the pill is right on the first frame it shows.
-- The measure is of the plain face, so a line gets ROOM over it: a line a little too wide is still whole.
local function fit(label: TextLabel, text: string, size: number, font: Enum.Font): Vector2
	label.Text = text
	local far = Vector2.new(10000, 1000)
	local one = math.ceil(TextService:GetTextSize(text, size, font, far).X * ROOM) + SPARE
	local box: Vector2
	if one <= RestBanner.TEXT_MAX then
		label.TextWrapped = false
		box = Vector2.new(one, size + 2)
	else
		label.TextWrapped = true
		local narrow = Vector2.new(RestBanner.TEXT_MAX / ROOM - SPARE, 1000)
		local tall = math.ceil(TextService:GetTextSize(text, size, font, narrow).Y)
		-- a row to spare
		box = Vector2.new(RestBanner.TEXT_MAX, math.max(size + 2, tall + size))
	end
	label.Size = UDim2.fromOffset(box.X, box.Y)
	return box
end

function RestBanner.new(): RestBanner
	local self = setmetatable({}, RestBanner) :: any
	local big = line("Big", BIG, 1, Theme.fonts.display)
	local small = line("Small", SMALL, 2, Theme.fonts.body)
	local badge: TextLabel = Create("TextLabel", {
		Name = "Badge",
		BackgroundColor3 = Theme.colors.gold,
		FontFace = Theme.fonts.display,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(BADGE, BADGE),
		Text = "2x",
		TextColor3 = Theme.colors.ink,
		TextSize = 17,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	Outline.border(badge, 2)
	local frame: CanvasGroup = Create("CanvasGroup", {
		Name = RestBanner.NAME,
		Active = false,
		BackgroundColor3 = Theme.colors.cream,
		GroupTransparency = 1,
		LayoutOrder = 0,
		Visible = false,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Create("UIPadding", {
			PaddingBottom = UDim.new(0, PAD_Y),
			PaddingLeft = UDim.new(0, PAD_LEFT),
			PaddingRight = UDim.new(0, PAD_RIGHT),
			PaddingTop = UDim.new(0, PAD_Y),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		badge,
		Create("Frame", {
			Name = "Lines",
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			big,
			small,
		}),
	})
	Outline.border(frame, 3)
	self.frame = frame
	self._big = big
	self._small = small
	self._badge = badge
	self._lines = frame:FindFirstChild("Lines")
	self._showing = false
	self._tween = nil :: Tween?
	return self :: RestBanner
end

function RestBanner.set(
	self: any,
	state: RestBannerLogic.State?,
	doubled: boolean?,
	remaining: number?
)
	local frame: CanvasGroup = self.frame
	if state ~= nil then
		local big, small, badge = RestBannerLogic.words(state, doubled ~= false, remaining or 0)
		local top = fit(self._big, big, BIG, Enum.Font.FredokaOne)
		local under = fit(self._small, small, SMALL, Enum.Font.Nunito)
		local wide = math.max(top.X, under.X)
		local tall = top.Y + under.Y
		local lines: Frame = self._lines
		local mark: TextLabel = self._badge
		lines.Size = UDim2.fromOffset(wide, tall)
		mark.Text = badge
		local across = PAD_LEFT + BADGE + GAP + wide + PAD_RIGHT
		frame.Size = UDim2.fromOffset(across, math.max(BADGE, tall) + PAD_Y * 2)
		frame.BackgroundColor3 = if state == "resting" then RESTING else Theme.colors.cream
	end
	local showing = state ~= nil
	if showing == self._showing then
		return
	end
	self._showing = showing
	local before: Tween? = self._tween
	if before ~= nil then
		before:Cancel()
	end
	if showing then
		frame.Visible = true
	end
	local tween = TweenService:Create(frame, FADE, { GroupTransparency = if showing then 0 else 1 })
	self._tween = tween
	tween.Completed:Connect(function(played: Enum.PlaybackState)
		if played == Enum.PlaybackState.Completed and not self._showing then
			frame.Visible = false
		end
	end)
	tween:Play()
end

function RestBanner.destroy(self: any)
	local tween: Tween? = self._tween
	if tween ~= nil then
		tween:Cancel()
	end
	self.frame:Destroy()
end

return RestBanner
