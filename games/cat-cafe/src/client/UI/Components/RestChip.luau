--!strict
-- #3574 (Derek 2026-11-12: "a little gentle text saying something like 2x rewards while afk in cafe"): the small
-- chip that shows while a player rests in their own cafe. Soft cream with the dark outline, the words from
-- RestChipLogic, and three small z's that drift slowly up off its right end (one still z with Roblox's Reduce
-- Motion). It fades in and out; nothing on it is bright, pulses, counts down or points.
--   local chip = RestChip.new(parent)   a hidden chip in `parent`; the caller places chip.frame (it is as wide as
--                                       its words, HEIGHT px tall, anchored by its top left corner)
--   chip:set(true, doubled)             shows it; `doubled` false in a 2x party, where the chip names no number
--   chip:set(false)                     fades it out (the moment the player moves: the caller's call)
--   chip:destroy()
-- The caller decides when: this never asks whether the player is resting.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local RestChipLogic = require(script.Parent.RestChipLogic)
local Theme = require(script.Parent.Parent.Theme)

local RestChip = {}
RestChip.__index = RestChip

RestChip.NAME = "RestChip"
RestChip.HEIGHT = 28
local FADE = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local Z_ROOM = 28 -- px kept free right of the words for the z's

export type RestChip = {
	frame: CanvasGroup,
	set: (self: RestChip, showing: boolean, doubled: boolean?) -> (),
	destroy: (self: RestChip) -> (),
}

function RestChip.new(parent: Instance): RestChip
	local self = setmetatable({}, RestChip) :: any
	local words: TextLabel = Create("TextLabel", {
		Name = "Words",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		FontFace = Theme.fonts.display,
		Text = RestChipLogic.words(true),
		TextColor3 = Theme.colors.ink,
		TextSize = 15,
	})
	local zs: { TextLabel } = {}
	local room: Frame = Create("Frame", {
		Name = "Zs",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, Z_ROOM, 1, 0),
		LayoutOrder = 2,
	})
	for i = 1, RestChipLogic.Z_COUNT do
		zs[i] = Create("TextLabel", {
			Name = "Z" .. i,
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 2, 1, -RestChipLogic.Z_FLOOR),
			Size = UDim2.fromOffset(RestChipLogic.Z_BOX, RestChipLogic.Z_BOX),
			FontFace = Theme.fonts.display,
			Text = "z",
			TextColor3 = Theme.colors.ink,
			TextSize = RestChipLogic.Z_SMALL,
			TextTransparency = 1,
			Parent = room,
		})
	end
	local frame: CanvasGroup = Create("CanvasGroup", {
		Name = RestChip.NAME,
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.colors.cream,
		GroupTransparency = 1,
		Size = UDim2.fromOffset(0, RestChip.HEIGHT),
		Visible = false,
		Active = false,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 4) }),
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		words,
		room,
	})
	Outline.border(frame, 2)
	self.frame = frame
	self._words = words
	self._zs = zs
	self._showing = false
	self._tween = nil :: Tween?
	self._step = nil :: RBXScriptConnection?
	self._since = 0
	return self :: RestChip
end

function RestChip._drift(self: any)
	local zs: { TextLabel } = self._zs
	if GuiService.ReducedMotionEnabled then
		-- one still z, the others out of sight
		for i, label in zs do
			label.TextTransparency = if i == 1 then 0.2 else 1
			label.Position = UDim2.new(0, 3, 1, -6)
			label.TextSize = RestChipLogic.Z_SMALL + 2
		end
		return
	end
	local t = os.clock() - self._since
	for i, label in zs do
		local x, y, size, gone = RestChipLogic.z(i, t)
		label.Position = UDim2.new(0, 2 + x, 1, -RestChipLogic.Z_FLOOR + y)
		label.TextSize = size
		label.TextTransparency = gone
	end
end

function RestChip.set(self: any, showing: boolean, doubled: boolean?)
	local label: TextLabel = self._words
	if showing then
		label.Text = RestChipLogic.words(doubled ~= false)
	end
	if showing == self._showing then
		return
	end
	self._showing = showing
	local frame: CanvasGroup = self.frame
	local before: Tween? = self._tween
	if before ~= nil then
		before:Cancel()
	end
	local step: RBXScriptConnection? = self._step
	if showing then
		frame.Visible = true
		if step == nil then
			self._since = os.clock()
			self._step = RunService.Heartbeat:Connect(function()
				self:_drift()
			end)
		end
	end
	local tween = TweenService:Create(frame, FADE, { GroupTransparency = if showing then 0 else 1 })
	self._tween = tween
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not self._showing then
			frame.Visible = false
			local running: RBXScriptConnection? = self._step
			if running ~= nil then
				running:Disconnect()
				self._step = nil
			end
		end
	end)
	tween:Play()
end

function RestChip.destroy(self: any)
	local step: RBXScriptConnection? = self._step
	if step ~= nil then
		step:Disconnect()
		self._step = nil
	end
	local tween: Tween? = self._tween
	if tween ~= nil then
		tween:Cancel()
	end
	self.frame:Destroy()
end

return RestChip
