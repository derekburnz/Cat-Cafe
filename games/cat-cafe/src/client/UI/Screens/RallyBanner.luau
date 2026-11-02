--!strict
-- The Rescue Rally banner (F101, rescue-rally.md section 4) in the HUD's reserved event spot, top centre under
-- Roblox's top bar, while a Rally runs: "🏁 Rescue Rally" with a gold "Lap 2" chip from the second lap and the time
-- left in the weekend, the bar with its three step pictures (Components/RallyBar; the track is named RallyBar, where
-- VFX's Effects/Rally pops each "+1" and paw), and this player's line under it ("You: 7 points", "Score 3 points to
-- share the prizes", "You've done your laps this weekend"). It takes no input. Words from Components/RallyLogic; the
-- step cheers are Sound-Agent's and the step prizes' toasts the server's. On a phone the HUD's potion timers' row sits
-- level with the menu's top; when it grows long enough to reach the banner (Luck, three potions, pals), the banner
-- moves down just under it (`avoid`, checked with each redraw).

local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local RallyBar = require(script.Parent.Parent.Components.RallyBar)
local RallyLogic = require(script.Parent.Parent.Components.RallyLogic)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type RallyBanner = {
	screenGui: ScreenGui,
	set: (self: RallyBanner, state: Types.RallyState?) -> (),
	setVisible: (self: RallyBanner, visible: boolean) -> (),
	destroy: (self: RallyBanner) -> (),
}

local WIDTH = 320
local HEIGHT = 74
local PAD = 12
local TOP = 6 -- under Roblox's top bar
local CLEAR = 8 -- kept between the banner and anything it moves away from
local TICK_SECONDS = 1 -- the time left moves on, and the banner goes when the weekend ends

local RallyBanner = {}
RallyBanner.__index = RallyBanner

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- `avoid` gives the HUD pieces the banner must not cover (HUD:buffRow); nil keeps it at the top.
function RallyBanner.new(parent: Instance, avoid: (() -> { GuiObject })?): RallyBanner
	local self = setmetatable({}, RallyBanner) :: any
	self._avoid = avoid
	self._top = TOP
	self._state = nil :: Types.RallyState?
	self._visible = true
	self._shown = false
	self._alive = true
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeRally",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10, -- with the HUD, under the tip card (11) and the windows
		Enabled = false,
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
	self._root = root
	local banner: Frame = Create("Frame", {
		Name = "Rally",
		BackgroundColor3 = RallyBar.NAVY,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Parent = root,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	Outline.border(banner, 2)
	self._banner = banner

	local title: Frame = Create("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, 5),
		Size = UDim2.new(0.62, -PAD, 0, 22),
		Parent = banner,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local name = text({
		Name = "Name",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.None,
		Text = RallyLogic.ICON .. " " .. RallyLogic.TITLE,
		LayoutOrder = 1,
		Parent = title,
	})
	Outline.text(name, 2)
	local lap = text({
		Name = "Lap",
		Size = UDim2.fromOffset(54, 18), -- "Lap 12" fits
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.goldText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		LayoutOrder = 2,
		Parent = title,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lap })
	self._lap = lap
	self._left = text({
		Name = "Left",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 5),
		Size = UDim2.new(0.38, -PAD, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.chalk,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = banner,
	})
	self._bar = RallyBar.new({
		parent = banner,
		name = "RallyBar",
		size = UDim2.new(1, -(PAD * 2 + 10), 0, 16),
		position = UDim2.fromOffset(PAD, 32),
		marker = 24,
		textSize = Theme.sizes.textTiny,
	})
	self._mine = text({
		Name = "Mine",
		Position = UDim2.fromOffset(PAD, 52),
		Size = UDim2.new(1, -PAD * 2, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textTiny + 1,
		TextColor3 = Theme.chalk,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = banner,
	})

	task.spawn(function()
		while self._alive do
			task.wait(TICK_SECONDS)
			if self._alive and self._state ~= nil then
				self:_render()
			end
		end
	end)
	return self :: RallyBanner
end

-- How far down the banner sits (design px): TOP, or just under anything in `avoid` it would cover there.
function RallyBanner._clearTop(self: any): number
	local avoid: (() -> { GuiObject })? = self._avoid
	local banner: Frame = self._banner
	local scale = banner.AbsoluteSize.X / WIDTH
	if avoid == nil or scale <= 0 then
		return TOP
	end
	local rootTop = (self._root :: Frame).AbsolutePosition.Y
	local left = banner.AbsolutePosition.X - CLEAR * scale
	local right = banner.AbsolutePosition.X + banner.AbsoluteSize.X + CLEAR * scale
	local bottomAtTop = rootTop + (TOP + HEIGHT + CLEAR) * scale
	local top = TOP
	for _, object in avoid() do
		local size, at = object.AbsoluteSize, object.AbsolutePosition
		if
			object.Visible
			and size.X > 0
			and at.X < right
			and at.X + size.X > left
			and at.Y < bottomAtTop
		then
			top = math.max(top, math.ceil((at.Y + size.Y - rootTop) / scale) + CLEAR)
		end
	end
	return top
end

function RallyBanner._render(self: any)
	local view = RallyLogic.view(self._state, Workspace:GetServerTimeNow())
	local shown = view ~= nil
	if view ~= nil then
		self._lap.Text = view.lap or ""
		self._lap.Visible = view.lap ~= nil
		self._left.Text = view.left
		self._mine.Text = view.mine
		self._mine.TextColor3 = if view.done then Theme.colors.gold else Theme.chalk
		self._bar:set(view)
		local top = self:_clearTop()
		if top ~= self._top then
			self._top = top
			self._banner.Position = UDim2.new(0.5, 0, 0, top)
		end
	end
	if shown ~= self._shown then
		self._shown = shown
		if shown then
			Tween.popIn(self._banner, 0.85)
		end
	end
	self.screenGui.Enabled = shown and self._visible
end

-- RallyState from the server (through UI.rally.update), or nil.
function RallyBanner.set(self: any, state: Types.RallyState?)
	self._state = state
	self:_render()
end

-- UI.setVisible: the banner hides with the HUD (the intro, cutscenes).
function RallyBanner.setVisible(self: any, visible: boolean)
	self._visible = visible
	self.screenGui.Enabled = self._shown and visible
end

function RallyBanner.destroy(self: any)
	self._alive = false
	self._bar:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return RallyBanner
