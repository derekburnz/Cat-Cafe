--!strict
-- #4251 Harvest Hollow's note picker (harvest-hollow-spec section 6), opened by the "Pin a note" prompt on the Thankful
-- Board (tag HarvestBoard, prompt HarvestBoardPrompt). Six big buttons, one for each fixed thank-you note
-- (shared/HarvestSave.NOTES, no typed text, so nothing to filter). A tap pins it at once (PinHarvestNote(index)) and
-- the window closes; the board shows it with the player's avatar. The server takes one pin every 10 s, so for those
-- seconds after a pin the buttons are grey and a line says when the next can go ("Pinned! Pick again in 6 s").
-- Walking away from the board closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local MenuFamily = require(script.Parent.Parent.Components.MenuFamily)
local Panel = require(script.Parent.Parent.Components.Panel)
local Scale = require(script.Parent.Parent.Scale)
local ThankfulLogic = require(script.Parent.Parent.Components.ThankfulLogic)
local Theme = require(script.Parent.Parent.Theme)

local HarvestSave =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HarvestSave")) :: any

local PAL = MenuFamily.pal

export type Callbacks = {
	pin: (note: number) -> (),
	close: () -> (),
	far: (() -> boolean)?, -- true once the player has walked away from the board: the window closes
}

export type ThankfulNotes = {
	frame: Frame,
	opened: (self: ThankfulNotes) -> (),
	closed: (self: ThankfulNotes) -> (),
	destroy: (self: ThankfulNotes) -> (),
}

local MAX_SIZE = Vector2.new(520, 340)
local GAP = 8
local LINE_H = 26

local ThankfulNotes = {}
ThankfulNotes.__index = ThankfulNotes

function ThankfulNotes.new(callbacks: Callbacks): ThankfulNotes
	local self = setmetatable({}, ThankfulNotes) :: any
	self._callbacks = callbacks
	self._buttons = {} :: { Button.Button }
	self._lastPin = nil :: number?
	self._open = false
	self._tick = 0
	local panel = Panel.new({
		dark = true,
		name = "ThankfulNotes",
		title = ThankfulLogic.TITLE,
		subtitle = "Pin a thank-you note",
		color = Color3.fromHex("E8892B"),
		icon = "📌",
		size = UDim2.fromScale(1, 1),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content
	local grid: Frame = Create("Frame", {
		Name = "Notes",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -(LINE_H + GAP)),
		Parent = content,
	}, {
		Create("UIGridLayout", {
			CellPadding = UDim2.fromOffset(GAP, GAP),
			CellSize = UDim2.new(0.5, -GAP / 2, 1 / 3, -GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local noteH = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	for index, words in HarvestSave.NOTES :: { string } do
		local button = Button.new({
			name = "Note" .. index,
			text = words,
			style = "gold",
			size = UDim2.fromOffset(0, noteH),
			textSize = Theme.sizes.textBody,
			layoutOrder = index,
			parent = grid,
			onClick = function()
				self:_pin(index)
			end,
		})
		table.insert(self._buttons, button)
	end
	self._line = Create("TextLabel", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, LINE_H),
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Your avatar shows beside your note",
		Parent = content,
	})
	return self :: ThankfulNotes
end

function ThankfulNotes._pin(self: any, index: number)
	local now = Workspace:GetServerTimeNow()
	if ThankfulLogic.pickLine(now, self._lastPin) ~= nil then
		return
	end
	self._lastPin = now
	self._callbacks.pin(index)
	self:_paint()
	self._callbacks.close()
end

function ThankfulNotes._paint(self: any)
	local wait = ThankfulLogic.pickLine(Workspace:GetServerTimeNow(), self._lastPin)
	for _, button in self._buttons do
		button:setEnabled(wait == nil)
		button:setStyle(if wait == nil then "gold" else "ghost")
	end
	self._line.Text = wait or "Your avatar shows beside your note"
end

function ThankfulNotes.opened(self: any)
	self._open = true
	self._tick += 1
	local tick = self._tick
	self:_paint()
	task.spawn(function()
		while self._open and self._tick == tick do
			task.wait(1)
			if self._open and self._tick == tick then
				self:_paint()
				local callbacks: Callbacks = self._callbacks
				local far = callbacks.far
				if far ~= nil and far() then
					callbacks.close()
					return
				end
			end
		end
	end)
end

function ThankfulNotes.closed(self: any)
	self._open = false
	self._tick += 1
end

function ThankfulNotes.destroy(self: any)
	self._open = false
	self._tick += 1
	for _, button in self._buttons do
		button:destroy()
	end
	table.clear(self._buttons)
	self._panel:destroy()
end

return ThankfulNotes
