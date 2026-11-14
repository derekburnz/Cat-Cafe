--!strict
-- #4195 (Derek 2026-11-14, admin events on update days): the Admin Wheel's window. While an admin event with the
-- wheel runs, every account may spin it once, free. On the left the wheel: eight slices sized by their odds
-- (shared/AdminWheel.PRIZES, weights in percent), each with its short words and its odds, the pointer on top. On the
-- right every prize with its odds, the Spin button and a line (what is free, the time left, the prize once it lands).
-- Spin fires AdminWheelSpin; the server rolls, pays at once and answers AdminWheelResult(slice, prizeId, paid), and
-- the wheel turns SPIN_SECONDS to land in the middle of that slice (Components/SpinLogic's landing, as the Spin
-- Wheel). Slice 0 is a refusal. Nothing here is sold or mentions Robux (monetization-policy).
--
-- Roblox UI has no pie shape, so each slice is a fan of thin bars from the hub to the rim (the Spin Wheel's way,
-- #1109). Every piece that turns sits in one Face frame, and the wheel turns by that frame's Rotation: a child
-- GuiObject turns with its parent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AdminBarLogic = require(script.Parent.Parent.Components.AdminBarLogic)
local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local SpinLogic = require(script.Parent.Parent.Components.SpinLogic)
local Theme = require(script.Parent.Parent.Theme)

local AdminWheelShared =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AdminWheel")) :: any

export type Callbacks = {
	spin: () -> (),
	close: () -> (),
	toast: (text: string) -> (), -- a prize that lands while the window is closed
}

export type AdminWheel = {
	frame: Frame,
	setWheel: (self: AdminWheel, wheel: AdminBarLogic.Wheel?) -> (),
	result: (self: AdminWheel, slice: number, prizeId: string, paid: { string }) -> (),
	refresh: (self: AdminWheel) -> (),
	isOpen: (self: AdminWheel) -> boolean,
	destroy: (self: AdminWheel) -> (),
}

local CARD = MenuFamily.card
local FACE = 0.88 -- the turning face inside the rim
local WEDGE_STEP = 3
local SPOKE = 3
local HUB = 0.2
local LABEL_RADIUS = 0.3 -- a slice's words, their middle from the hub (of the face)
local LABEL_LONG = 0.34 -- the words' box along the ray (of the face)
local RIM_LIGHTS = 20
local ROW_H = 26
local SPIN_H = 50
local SPIN_SECONDS = 4.5
local SPIN_TURNS = 5
local RIM = Theme.colors.cocoa
local INK = Theme.colors.outline
local BULB = { Color3.fromHex("FFF096"), Color3.fromHex("FFFFFF") }

local AdminWheel = {}
AdminWheel.__index = AdminWheel

local function prizes(): { any }
	return AdminWheelShared.PRIZES
end

-- Each slice's angle, in degrees, from its weight in percent.
local function spans(): { number }
	local out = {}
	for index, prize in prizes() do
		out[index] = prize.weight * 3.6
	end
	return out
end

-- Text on a slice of `color`: dark ink on a light slice, white on a dark one.
local function onSlice(color: Color3): Color3
	local light = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if light > 0.5 then Theme.colors.ink else Theme.colors.white
end

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = CARD.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function AdminWheel.new(callbacks: Callbacks): AdminWheel
	local self = setmetatable({}, AdminWheel) :: any
	self._callbacks = callbacks
	self._wheel = nil :: AdminBarLogic.Wheel?
	self._spinning = false
	self._won = nil :: string?
	self._angle = 0
	self._spans = spans()

	local short = Scale.isShort()
	local panel = Panel.new({
		dark = true,
		name = "AdminWheel",
		title = "Admin Wheel",
		subtitle = "One free spin for everyone online",
		color = Theme.colors.cocoa,
		icon = "🎡",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = Vector2.new(720, 470), Parent = panel.frame })
	self._panel = panel
	self.frame = panel.frame

	-- the wheel on the left, as tall as the window's content
	local wheel: Frame = Create("Frame", {
		Name = "Wheel",
		BackgroundColor3 = RIM,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = panel.content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(wheel, Theme.sizes.outline + 1, INK)
	self._wheelFrame = wheel
	for index = 1, RIM_LIGHTS do
		local theta = math.rad((index - 1) * 360 / RIM_LIGHTS)
		local r = (1 + FACE) / 4
		Create("Frame", {
			Name = "Bulb",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + r * math.sin(theta), 0.5 - r * math.cos(theta)),
			Size = UDim2.fromScale(0.035, 0.035),
			BackgroundColor3 = BULB[(index - 1) % 2 + 1],
			BorderSizePixel = 0,
			Parent = wheel,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
	end
	local face: Frame = Create("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(FACE, FACE),
		BackgroundTransparency = 1,
		Parent = wheel,
	})
	self._face = face
	self:_buildSlices()
	-- the hub and the pointer stay still
	local hub: Frame = Create("Frame", {
		Name = "Hub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(HUB * FACE, HUB * FACE),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = wheel,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(hub, Theme.sizes.outline, INK)
	local paw = label({
		Name = "Paw",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Text = "🐾",
		ZIndex = 6,
		Parent = hub,
	})
	Create("UITextSizeConstraint", { MaxTextSize = 28, Parent = paw })
	local pointer = label({
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, -0.04),
		Size = UDim2.fromScale(0.14, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.red,
		Text = "▼",
		ZIndex = 7,
		Parent = wheel,
	})
	Outline.text(pointer, 3, INK)

	-- the side: every prize and its odds, Spin, and the line
	local side: Frame = Create("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Parent = panel.content,
	})
	self._side = side
	local rowH = if short then ROW_H - 8 else ROW_H
	label({
		Name = "Caption",
		Size = UDim2.new(1, 0, 0, rowH - 4),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = CARD.subtext,
		Text = "Odds for your one free spin",
		Parent = side,
	})
	local list: Frame = Create("Frame", {
		Name = "Odds",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, rowH - 2),
		Size = UDim2.new(1, 0, 0, #prizes() * (rowH + 2)),
		Parent = side,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	for index, prize in prizes() do
		local slice = AdminBarLogic.SLICES[index]
		local row: Frame = Create("Frame", {
			Name = "Row_" .. prize.id,
			BackgroundColor3 = CARD.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, rowH),
			LayoutOrder = index,
			Parent = list,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
		})
		local chip: Frame = Create("Frame", {
			Name = "Chip",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(rowH - 12, rowH - 12),
			BackgroundColor3 = if slice then slice.color else Theme.colors.gold,
			BorderSizePixel = 0,
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
		})
		Outline.border(chip, 1, INK)
		label({
			Name = "Name",
			Position = UDim2.fromOffset(rowH, 0),
			Size = UDim2.new(1, -rowH - 46, 1, 0),
			TextSize = if short then Theme.sizes.textTiny else Theme.sizes.textSmall,
			Text = prize.name,
			Parent = row,
		})
		label({
			Name = "Odds",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 0),
			Size = UDim2.new(0, 42, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = Theme.fonts.display,
			TextSize = if short then Theme.sizes.textSmall else Theme.sizes.textBody,
			Text = ("%d%%"):format(prize.weight),
			Parent = row,
		})
	end
	local listBottom = rowH - 2 + #prizes() * (rowH + 2)
	local spinH = Scale.tapHeight(if short then SPIN_H - 14 else SPIN_H, Theme.sizes.buttonDepth)
	local lineH = if short then 28 else 34
	self._spin = Button.new({
		name = "Spin",
		text = "SPIN (free)",
		style = "primary",
		size = UDim2.new(1, 0, 0, spinH),
		position = UDim2.fromOffset(0, listBottom + 6),
		textSize = if short then Theme.sizes.textLarge - 2 else Theme.sizes.textLarge,
		parent = side,
		onClick = function()
			self:_press()
		end,
	})
	self._line = label({
		Name = "Line",
		Position = UDim2.fromOffset(0, listBottom + 6 + spinH + 4),
		Size = UDim2.new(1, 0, 0, lineH),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = CARD.subtext,
		Parent = side,
	})
	self._sideH = listBottom + 6 + spinH + 4 + lineH
	-- the side's width follows the window: what the wheel leaves, past a gap (design px: AbsoluteSize over the scale)
	local function lay()
		local uiScale = math.max(Scale.get(), 0.01)
		local content = panel.content.AbsoluteSize / uiScale
		local wheelW = math.floor(math.min(content.Y, content.X * 0.48))
		wheel.Size = UDim2.fromOffset(wheelW, wheelW)
		side.Size = UDim2.fromOffset(math.max(0, content.X - wheelW - 12), self._sideH)
	end
	self._lay = lay
	panel.content:GetPropertyChangedSignal("AbsoluteSize"):Connect(lay)
	lay()
	self:refresh()
	return self :: AdminWheel
end

-- The slices: a fan of thin bars each, a spoke after each, and the slice's words along its middle.
function AdminWheel._buildSlices(self: any)
	local face: Frame = self._face
	local all = self._spans
	for index, prize in prizes() do
		local size = all[index]
		local centre = SpinLogic.centre(all, index)
		local slice = AdminBarLogic.SLICES[index]
		local color = if slice then slice.color else Theme.colors.gold
		local steps = math.max(2, math.ceil(size / WEDGE_STEP))
		local step = size / steps
		local width = 0.5 * math.sin(math.rad(step)) * 1.15
		local from = centre - size / 2
		local function add(base: number, sideOf: number)
			local theta = math.rad(base)
			local sin, cos = math.sin(theta), math.cos(theta)
			local offset = width / 2
			Create("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(
					0.5 + 0.25 * sin + sideOf * offset * cos,
					0.5 - 0.25 * cos + sideOf * offset * sin
				),
				Size = UDim2.fromScale(width, 0.5),
				Rotation = base,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 1,
				Parent = face,
			})
		end
		for k = 0, math.ceil(steps / 2) - 1 do
			add(from + k * step, 1)
		end
		for k = 0, math.ceil(steps / 2) - 1 do
			add(from + size - k * step, -1)
		end
		-- the spoke at the slice's far edge
		local edge = from + size
		local et = math.rad(edge)
		Create("Frame", {
			Name = "Spoke" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + 0.25 * math.sin(et), 0.5 - 0.25 * math.cos(et)),
			Size = UDim2.new(0, SPOKE, 0.5, 0),
			Rotation = edge,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = face,
		})
		-- the words along the slice's middle, reading outward on the right half and inward on the left
		local mid = centre % 360
		local theta = math.rad(mid)
		local chord = 2 * LABEL_RADIUS * math.sin(math.rad(math.min(size, 90) / 2))
		local narrow = prize.weight < 8
		local words = if narrow
			then ("%d%%"):format(prize.weight)
			else ((slice and slice.short or prize.name) .. "\n" .. ("%d%%"):format(
				prize.weight
			))
		local text = label({
			Name = "Slice_" .. prize.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(
				0.5 + (LABEL_RADIUS + 0.08) * math.sin(theta),
				0.5 - (LABEL_RADIUS + 0.08) * math.cos(theta)
			),
			Size = UDim2.fromScale(LABEL_LONG, math.min(0.17, chord * 0.9)),
			Rotation = if mid < 180 then mid - 90 else mid + 90,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			FontFace = Theme.fonts.display,
			TextColor3 = onSlice(color),
			Text = words,
			ZIndex = 3,
			Parent = face,
		})
		Create("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12, Parent = text })
	end
end

function AdminWheel._press(self: any)
	local view = AdminBarLogic.wheelView(
		self._wheel,
		Workspace:GetServerTimeNow(),
		self._spinning,
		self._won
	)
	if not view.enabled then
		return
	end
	self._spinning = true
	self:refresh()
	self._callbacks.spin()
	-- no answer within a while (a dropped remote): the button comes back
	task.delay(6, function()
		if self._spinning and self._landing == nil then
			self._spinning = false
			self:refresh()
		end
	end)
end

function AdminWheel.isOpen(self: any): boolean
	return self.frame.Visible
end

-- PlayerState.adminWheel.
function AdminWheel.setWheel(self: any, wheel: AdminBarLogic.Wheel?)
	local before = self._wheel
	self._wheel = wheel
	if wheel == nil or (before ~= nil and before.eventId ~= wheel.eventId) then
		self._won = nil -- a new wheel, or none: a new spin's words next time
	end
	self:refresh()
end

-- From AdminWheelResult: the wheel turns to `slice` and says what it paid. 0 is a refusal.
function AdminWheel.result(self: any, slice: number, prizeId: string, paid: { string })
	if slice < 1 or slice > #prizes() then
		self._spinning = false
		self:refresh()
		self._line.Text = "That spin did not go through. The wheel may be closed."
		return
	end
	local prize = prizes()[slice]
	local words = if type(paid) == "table" and #paid > 0
		then table.concat(paid, ", ")
		else prize.name
	local _ = prizeId
	if not self.frame.Visible then
		self._spinning = false
		self._won = words
		self:refresh()
		self._callbacks.toast("Admin Wheel: you won " .. words .. "!")
		return
	end
	self._spinning = true
	local target = SpinLogic.landing(self._angle, slice, self._spans, SPIN_TURNS)
	local holder = Instance.new("NumberValue")
	holder.Value = self._angle
	holder.Changed:Connect(function(value: number)
		self._angle = value
		self._face.Rotation = value
	end)
	local tween = TweenService:Create(
		holder,
		TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Value = target }
	)
	self._landing = tween
	tween.Completed:Once(function()
		holder:Destroy()
		self._landing = nil
		self._angle = target % 360
		self._face.Rotation = self._angle
		self._spinning = false
		self._won = words
		self:refresh()
	end)
	tween:Play()
end

-- The button and the line, now (the window's clock ticks it each second while open).
function AdminWheel.refresh(self: any)
	local view = AdminBarLogic.wheelView(
		self._wheel,
		Workspace:GetServerTimeNow(),
		self._spinning,
		self._won
	)
	self._spin:setText(view.button)
	self._spin:setEnabled(view.enabled)
	self._line.Text = view.line
end

function AdminWheel.destroy(self: any)
	local landing = self._landing
	if landing then
		landing:Cancel()
	end
	self._spin:destroy()
	self._panel:destroy()
end

return AdminWheel
