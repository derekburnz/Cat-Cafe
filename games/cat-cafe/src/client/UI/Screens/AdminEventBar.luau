--!strict
-- #4195 (Derek 2026-11-14, admin events on update days): the admin event's two HUD pieces, top centre under the
-- HUD's top row (the counters and the Luck row on a phone, `avoid`, as the Rally banner does):
-- - the banner, big gold words for BANNER_SECONDS when the 2 minute warning starts ("ADMIN EVENT IN 2:00") and again
--   when the event starts ("ADMIN WHEEL NOW!"), with what it does under them;
-- - the timer, a slim cocoa pill the rest of the time: "Admin Wheel in 1:42", then "Admin Wheel 4:12 left", with a
--   green Spin button while the wheel is up and this account has not spun it (it opens the wheel's window).
-- Words from Components/AdminBarLogic. It never covers a catch: while a catch or rescue runs it steps aside
-- (setBusy). Nothing here is sold. It is the one banner and timer for an admin event: with it up, UI.cafeEvent.tick
-- skips Effects/EventBanner's admin cards and the admin line on the Cafe Event chip (#4202), and this bar plays their
-- two sounds; the chat line stays.

local AdminBarLogic = require(script.Parent.Parent.Components.AdminBarLogic)
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)

export type AdminEventBar = {
	screenGui: ScreenGui,
	set: (self: AdminEventBar, view: AdminBarLogic.View?, now: number) -> (),
	setBusy: (self: AdminEventBar, busy: boolean) -> (),
	destroy: (self: AdminEventBar) -> (),
}

local TOP = 6 -- under Roblox's top bar
local CLEAR = 6
local BANNER_W = 400
local BANNER_H = 74
local PILL_H = 40 -- at least; a touch screen's finger-high Spin button makes it taller
local SPIN_W = 70
local GOLD_TOP = Color3.fromHex("FFE07A")
local GOLD = Theme.colors.gold
local COCOA = Theme.colors.cocoa
local INK = Theme.colors.outline
local CREAM_GOLD = Color3.fromHex("FFE296")

local AdminEventBar = {}
AdminEventBar.__index = AdminEventBar

-- `avoid` gives the HUD pieces the bar must not cover; `spin` opens the wheel's window.
function AdminEventBar.new(
	parent: Instance,
	avoid: (() -> { GuiObject })?,
	spin: () -> ()
): AdminEventBar
	local self = setmetatable({}, AdminEventBar) :: any
	self._avoid = avoid
	self._busy = false
	self._view = nil :: AdminBarLogic.View?
	self._bannerKey = nil :: string?
	self._bannerUntil = 0
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeAdminEvent",
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
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.fromOffset(BANNER_W, BANNER_H),
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(GOLD_TOP, GOLD),
		}),
	})
	Outline.border(banner, Theme.sizes.outline, INK)
	self._banner = banner
	self._big = Create("TextLabel", {
		Name = "Big",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 38),
		FontFace = Theme.fonts.display,
		TextSize = 32,
		TextColor3 = Theme.colors.white,
		TextScaled = false,
		Text = "",
		Parent = banner,
	})
	Outline.text(self._big, 3, INK)
	self._sub = Create("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.colors.goldText,
		Text = "",
		Parent = banner,
	})

	local pill: Frame = Create("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.fromOffset(240, PILL_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COCOA,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 4),
		}),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	Outline.border(pill, Theme.sizes.outline, INK)
	self._pill = pill
	local function pillText(name: string, order: number, color: Color3): TextLabel
		local label: TextLabel = Create("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, PILL_H - 8),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody + 2,
			TextColor3 = color,
			LayoutOrder = order,
			Text = "",
			Parent = pill,
		})
		Outline.text(label, 2, INK)
		return label
	end
	self._pillWords = pillText("Words", 1, Theme.colors.white)
	self._pillTime = pillText("Time", 2, CREAM_GOLD)
	-- the gap after the clock when no Spin button follows
	Create("Frame", {
		Name = "End",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(6, 1),
		LayoutOrder = 4,
		Parent = pill,
	})
	local spinH = Scale.tapHeight(36, Theme.sizes.buttonDepth)
	self._pillH = math.max(PILL_H, spinH + 6)
	pill.Size = UDim2.fromOffset(240, self._pillH)
	self._spin = Button.new({
		name = "Spin",
		text = "Spin!",
		style = "primary",
		size = UDim2.fromOffset(SPIN_W, spinH),
		textSize = Theme.sizes.textBody,
		layoutOrder = 3,
		parent = pill,
		onClick = spin,
	})
	self._spin.instance.Visible = false
	return self :: AdminEventBar
end

-- How far down the bar sits (design px): TOP, or just under anything in `avoid` it would cover there.
function AdminEventBar._clearTop(self: any, piece: Frame, height: number): number
	local avoid: (() -> { GuiObject })? = self._avoid
	local scale = math.max(self._uiScale.Scale, 0.01)
	if avoid == nil then
		return TOP
	end
	local rootTop = (self._root :: Frame).AbsolutePosition.Y
	local half = piece.AbsoluteSize.X / 2 + CLEAR * scale
	local middle = (self._root :: Frame).AbsolutePosition.X
		+ (self._root :: Frame).AbsoluteSize.X / 2
	local left, right = middle - half, middle + half
	-- step down past every piece in the way, again until nothing is (a piece under the first can be in the way then)
	local top = TOP
	local objects = avoid()
	for _ = 1, #objects + 1 do
		local moved = false
		local from = rootTop + (top - CLEAR) * scale
		local to = rootTop + (top + height + CLEAR) * scale
		for _, object in objects do
			local size, at = object.AbsoluteSize, object.AbsolutePosition
			if
				object.Visible
				and size.X > 0
				and at.X < right
				and at.X + size.X > left
				and at.Y < to
				and at.Y + size.Y > from
			then
				top = math.ceil((at.Y + size.Y - rootTop) / scale) + CLEAR
				moved = true
				break
			end
		end
		if not moved then
			break
		end
	end
	return top
end

-- The view now (AdminBarLogic.view), every half second or so; nil puts both away.
function AdminEventBar.set(self: any, view: AdminBarLogic.View?, now: number)
	self._view = view
	self._now = now
	if view ~= nil and view.key ~= self._bannerKey then
		-- a new step (the warning, the start): the big banner comes up for a while
		self._bannerKey = view.key
		self._bannerUntil = now + AdminBarLogic.BANNER_SECONDS
		-- the cues Effects/EventBanner played for these steps before this bar took them over (#4202)
		Sound.play(if view.phase == "soon" then "uiGiftReady" else "stationReveal")
	end
	self:_paint(now)
end

function AdminEventBar._paint(self: any, now: number)
	local view: AdminBarLogic.View? = self._view
	local shown = view ~= nil and not self._busy
	self.screenGui.Enabled = shown
	if view == nil or not shown then
		return
	end
	local big = now < self._bannerUntil
	self._banner.Visible = big
	self._pill.Visible = not big
	if big then
		self._big.Text = view.big
		self._sub.Text = view.sub
		self._banner.Position = UDim2.new(0.5, 0, 0, self:_clearTop(self._banner, BANNER_H))
	else
		self._pillWords.Text = view.pill
		self._pillTime.Text = view.time
		self._spin.instance.Visible = view.spin
		self._pill.Position = UDim2.new(0.5, 0, 0, self:_clearTop(self._pill, self._pillH))
	end
end

-- A catch or rescue runs (HUD.catchingChanged): the bar steps aside until it ends.
function AdminEventBar.setBusy(self: any, busy: boolean)
	self._busy = busy
	self:_paint(self._now or 0)
end

function AdminEventBar.destroy(self: any)
	self._spin:destroy()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return AdminEventBar
