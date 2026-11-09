--!strict
-- The Rescue Rally banner (F101, rescue-rally.md section 4) in the HUD's reserved event spot, top centre under
-- Roblox's top bar, while a Rally runs: "🏁 Rescue Rally" with a gold "Lap 2" chip from the second lap and the time
-- left in the weekend, the bar with its three step pictures (Components/RallyBar; the track is named RallyBar, where
-- VFX's Effects/Rally pops each "+1" and paw), and this player's line under it ("You: 7 points", "Score 3 points to
-- share the prizes", "You've done your laps this weekend"). It takes no input. Words from Components/RallyLogic; the
-- step cheers are Sound-Agent's and the step prizes' toasts the server's. On a phone the HUD's potion timers' row sits
-- level with the menu's top; when it grows long enough to reach the banner (Luck, three potions, pals), the banner
-- moves down just under it (`avoid`, checked with each redraw). While a catch or rescue runs the banner steps aside
-- (setBusy), so the circles' and the rescue bar's headers under it are never covered (review S113).
-- #2098 (Derek2 11-07: "hidden and only pops up briefly when you catch a cat to progress the bar"): the banner stays
-- hidden. When this player's own points go up it pops in (once the catch or rescue screen has gone), the bar fills
-- from where it was to the new points, and it goes again PEEK_SECONDS later; more points meanwhile keep it up.

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
	-- a catch or rescue runs (HUD.catchingChanged): the banner hides until it ends
	setBusy: (self: RallyBanner, busy: boolean) -> (),
	destroy: (self: RallyBanner) -> (),
}

local WIDTH = 320
local NUMBER_SIZE = 12 -- the points each step pays at, under its marker (#2078)
local HEIGHT = 74 + NUMBER_SIZE + 2
local COUNT_W = 56 -- "120 / 300" past the bar's end
local PAD = 12
local TOP = 6 -- under Roblox's top bar
local CLEAR = 8 -- kept between the banner and anything it moves away from
local PEEK_SECONDS = 4 -- #2098: how long the banner stays up after this player scores
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
	self._busy = false
	self._alive = true
	self._mineSeen = nil :: number? -- this player's points as last seen, so a rise shows the banner (#2098)
	self._pending = false -- points went up; the banner pops up as soon as nothing covers its spot
	self._peekUntil = 0 -- os.clock() until which the banner is up
	self._primed = false -- the bar has been drawn once (else the first pop fills it from where it was)
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
	self._name = name
	-- #2608: "Lap 3: bigger prizes!", as wide as its words; the name steps down to the flag beside it
	local lap = text({
		Name = "Lap",
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
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
	Create(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = lap }
	)
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
		-- the track, the end marker's half and "120 / 300" past it (#2078)
		size = UDim2.new(1, -(PAD * 2 + 12 + 4 + COUNT_W), 0, 16),
		position = UDim2.fromOffset(PAD, 32),
		marker = 24,
		textSize = Theme.sizes.textTiny,
		countWidth = COUNT_W,
		numberSize = NUMBER_SIZE,
		textColor = Theme.chalk,
	})
	self._mine = text({
		Name = "Mine",
		Position = UDim2.fromOffset(PAD, 52 + NUMBER_SIZE + 2),
		Size = UDim2.new(1, -PAD * 2, 0, 18),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall, -- 10.5 px on a phone (device pass 2026-11-07: textTiny + 1 read as about 8)
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
	if view ~= nil then
		self._lap.Text = view.lap or ""
		self._lap.Visible = view.lap ~= nil
		self._name.Text = if view.lap ~= nil
			then RallyLogic.ICON
			else RallyLogic.ICON .. " " .. RallyLogic.TITLE
		self._left.Text = view.left
		self._mine.Text = view.mine
		self._mine.TextColor3 = if view.done then Theme.colors.gold else Theme.chalk
		local top = self:_clearTop()
		if top ~= self._top then
			self._top = top
			self._banner.Position = UDim2.new(0.5, 0, 0, top)
		end
	end
	local now = os.clock()
	if view == nil then
		-- no Rally running: nothing to show, and nothing waiting to pop up when the next one starts
		self._peekUntil = 0
		self._pending = false
	end
	local open = view ~= nil and self._visible and not self._busy
	if view ~= nil and open and self._pending then
		-- #2098: this player scored: pop up and fill the bar slowly to the new points
		self._pending = false
		if now >= self._peekUntil then
			Tween.popIn(self._banner, 0.85)
		end
		self._peekUntil = now + PEEK_SECONDS
		self._bar:set(view, true)
		self._primed = true
		local ends = self._peekUntil
		task.delay(PEEK_SECONDS, function()
			if self._alive and self._peekUntil == ends then
				Tween.popOut(self._banner, function()
					if self._alive and self._peekUntil == ends then
						self:_render()
					end
				end)
			end
		end)
	elseif view ~= nil and open and now < self._peekUntil then
		self._bar:set(view) -- other players' points while it is up
	elseif view ~= nil and not open and now < self._peekUntil then
		-- a catch, a rescue or a cutscene cut it short: it comes back once they end
		self._peekUntil = 0
		self._pending = true
	end
	self.screenGui.Enabled = open and now < self._peekUntil
end

-- RallyState from the server (through UI.rally.update), or nil. A rise in this player's points (myPoints) pops the
-- banner up (#2098); the first state only notes them.
function RallyBanner.set(self: any, state: Types.RallyState?)
	local mine = if state ~= nil then state.myPoints else nil
	local seen = self._mineSeen
	if type(mine) == "number" and type(seen) == "number" and mine > seen then
		self._pending = true
		if not self._primed then
			-- drawn hidden at the old points first, so the pop shows the bar moving on from there
			local before = RallyLogic.view(self._state, Workspace:GetServerTimeNow())
			if before ~= nil then
				self._bar:set(before)
				self._primed = true
			end
		end
	end
	if type(mine) == "number" then
		self._mineSeen = mine
	end
	self._state = state
	self:_render()
end

-- UI.setVisible: the banner hides with the HUD (the intro, cutscenes).
function RallyBanner.setVisible(self: any, visible: boolean)
	self._visible = visible
	self:_render()
end

function RallyBanner.setBusy(self: any, busy: boolean)
	self._busy = busy
	self:_render()
end

function RallyBanner.destroy(self: any)
	self._alive = false
	self._bar:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return RallyBanner
