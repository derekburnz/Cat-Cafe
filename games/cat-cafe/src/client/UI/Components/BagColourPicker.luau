--!strict
-- #3699 (shared/BagColours; Design-Agent's picks on the issue): the Backpack's colour picker, a page inside Juniper's
-- window. Top row: Reset, Save and Back. Left: a drawn bag that changes as the player taps. Right: two blocks of
-- twelve swatches, "Bag" and "Trim", six to a row. Nothing is sent until Save; Reset picks the built colours again
-- (and is saved by Save like any pick). Back returns to the shelf without saving.
--   BagColourPicker.new(parent, callbacks) -> picker
--   picker:open(saved)      show it, starting from the saved picks
--   picker:saved(saved)     the server's answer: the saved picks as they stand now
--   picker:close()
--   picker.frame, picker.shown

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BagColours = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BagColours"))
local Button = require(script.Parent.Button)
local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local PAL = Theme.dark

export type Callbacks = {
	save: (main: string, trim: string) -> (),
	back: () -> (),
}

export type BagColourPicker = {
	frame: Frame,
	shown: boolean,
	open: (self: BagColourPicker, saved: BagColours.Picks?) -> (),
	saved: (self: BagColourPicker, saved: BagColours.Picks?) -> (),
	close: (self: BagColourPicker) -> (),
	destroy: (self: BagColourPicker) -> (),
}

local BagColourPicker = {}
BagColourPicker.__index = BagColourPicker

BagColourPicker.SWATCH = 44 -- a thumb's width
BagColourPicker.COLUMNS = 6
BagColourPicker.TOUCH_COLUMNS = 4
local GAP = 6
local LEFT_W = 112
local PREVIEW = 104
local HEAD_W = 80 -- Reset, Save and Back in the top row
local PENDING_SECONDS = 5

local function label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function block(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	radius: number
): Frame
	return Create("Frame", {
		Name = name,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, radius) }) })
end

function BagColourPicker.new(parent: Instance, callbacks: Callbacks): BagColourPicker
	local self = setmetatable({}, BagColourPicker) :: any
	self._callbacks = callbacks
	self._picks = BagColours.picks(nil)
	self._saved = BagColours.picks(nil)
	self._pending = false
	self._token = 0
	self._swatches = { main = {}, trim = {} } :: { [string]: { [string]: TextButton } }
	self.shown = false

	local frame: Frame = Create("Frame", {
		Name = "BagColours",
		BackgroundColor3 = PAL.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	self.frame = frame
	-- it takes the presses that would reach the shelf under it
	Create("TextButton", {
		Name = "Shield",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})

	label({
		Name = "Title",
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -(3 * (HEAD_W + 6) + 16), 0, 24),
		TextSize = Theme.sizes.textLarge,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = BagColours.WORDS.title,
		Parent = frame,
	})
	local tap = Scale.tapHeight(36 + Theme.sizes.buttonDepth, Theme.sizes.buttonDepth)
	self._back = Button.new({
		name = "Back",
		text = "Back",
		style = "ghost",
		size = UDim2.fromOffset(HEAD_W, tap),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			callbacks.back()
		end,
	})

	-- the drawn bag: a handle, the body, its lighter flap, a pocket and a clasp, in the model's own steps
	local top = tap + 6
	local preview: Frame = Create("Frame", {
		Name = "Preview",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, top),
		Size = UDim2.fromOffset(PREVIEW, PREVIEW),
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
	self._parts = {
		{
			block(preview, "Handle", UDim2.fromOffset(34, 8), UDim2.fromOffset(36, 18), 9),
			"trim",
			1,
		},
		{
			block(preview, "Body", UDim2.fromOffset(16, 20), UDim2.fromOffset(72, 74), 14),
			"main",
			1,
		},
		{
			block(preview, "Flap", UDim2.fromOffset(16, 20), UDim2.fromOffset(72, 30), 14),
			"main",
			2,
		},
		{
			block(preview, "Pocket", UDim2.fromOffset(28, 58), UDim2.fromOffset(48, 28), 8),
			"trim",
			3,
		},
		{
			block(preview, "PocketTop", UDim2.fromOffset(28, 58), UDim2.fromOffset(48, 9), 4),
			"trim",
			1,
		},
	} :: { { any } }
	local clasp = block(preview, "Clasp", UDim2.fromOffset(46, 44), UDim2.fromOffset(12, 10), 3)
	clasp.BackgroundColor3 = Color3.fromHex("F2C14E")
	for _, part in self._parts do
		Outline.border(part[1], 2, Theme.colors.black)
	end

	self._save = Button.new({
		name = "Save",
		text = BagColours.WORDS.save,
		style = "primary",
		-- Save and Reset sit in the top row beside Back: under the bag they ran off a phone's short window
		size = UDim2.fromOffset(HEAD_W, tap),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -(8 + HEAD_W + 6), 0, 0),
		textSize = Theme.sizes.textBody,
		parent = frame,
		onClick = function()
			self:_pressSave()
		end,
	})
	self._reset = Button.new({
		name = "Reset",
		text = BagColours.WORDS.reset,
		style = "ghost",
		size = UDim2.fromOffset(HEAD_W, tap),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -(8 + 2 * (HEAD_W + 6)), 0, 0),
		textSize = Theme.sizes.textSmall,
		parent = frame,
		onClick = function()
			self._picks = BagColours.picks(nil)
			self:_paint()
		end,
	})

	-- the two blocks of swatches, in a list that scrolls where the window is short
	local list: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Swatches",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8 + LEFT_W + 6, top),
		Size = UDim2.new(1, -(8 + LEFT_W + 6 + 4), 1, -top),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.caramel,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Outline.listPadding(8, 8),
	})
	self._names = {} :: { [string]: TextLabel }
	-- a finger needs 44 px on screen, so on touch a swatch is drawn larger and the rows are four wide
	local swatch = Scale.tapHeight(BagColourPicker.SWATCH)
	local columns = if Scale.isTouch()
		then BagColourPicker.TOUCH_COLUMNS
		else BagColourPicker.COLUMNS
	local rows = math.ceil(#BagColours.LIST / columns)
	for order, slot in { "main", "trim" } do
		self._names[slot] = label({
			Name = slot .. "Name",
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = order * 2 - 1,
			Parent = list,
		})
		local grid: Frame = Create("Frame", {
			Name = slot,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(
				columns * swatch + (columns - 1) * GAP,
				rows * swatch + (rows - 1) * GAP
			),
			LayoutOrder = order * 2,
			Parent = list,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(swatch, swatch),
				CellPadding = UDim2.fromOffset(GAP, GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for index, row in BagColours.LIST do
			local id = row.id
			local button: TextButton = Create("TextButton", {
				Name = "Swatch_" .. id,
				AutoButtonColor = false,
				BackgroundColor3 = row.color,
				BorderSizePixel = 0,
				FontFace = Theme.fonts.display,
				TextSize = 24,
				TextColor3 = Theme.colors.white,
				Text = "",
				LayoutOrder = index,
				Parent = grid,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Create("UIStroke", {
					Name = "Ring",
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Theme.colors.black,
					Thickness = 2,
				}),
			})
			Outline.text(button, 2)
			button.Activated:Connect(function()
				local picks = table.clone(self._picks)
				picks[slot] = id
				self._picks = picks
				self:_paint()
			end)
			self._swatches[slot][id] = button
		end
	end
	self:_paint()
	return self :: BagColourPicker
end

function BagColourPicker._changed(self: any): boolean
	return self._picks.main ~= self._saved.main or self._picks.trim ~= self._saved.trim
end

function BagColourPicker._paint(self: any)
	local picks: BagColours.Picks = self._picks
	for _, part in self._parts do
		local frame: Frame, slot: string, step: number = part[1], part[2], part[3]
		frame.BackgroundColor3 = BagColours.colorFor(BagColours.BUILT[slot][step], picks)
	end
	for slot, buttons in self._swatches do
		local picked = if slot == "main" then picks.main else picks.trim
		for id, button: TextButton in buttons do
			local on = id == picked
			button.Text = if on then "✓" else ""
			local ring = button:FindFirstChild("Ring") :: UIStroke
			ring.Color = if on then Theme.colors.white else Theme.colors.black
			ring.Thickness = if on then 4 else 2
		end
		local row = BagColours.row(picked)
		local words = if slot == "main" then BagColours.WORDS.main else BagColours.WORDS.trim
		self._names[slot].Text = if row ~= nil then words .. ": " .. row.name else words
	end
	local defaults = BagColours.picks(nil)
	self._save:setText(if self._pending then "..." else BagColours.WORDS.save)
	self._save:setEnabled(self:_changed() and not self._pending)
	self._reset:setEnabled(picks.main ~= defaults.main or picks.trim ~= defaults.trim)
end

function BagColourPicker._pressSave(self: any)
	if self._pending or not self:_changed() then
		return
	end
	self._pending = true
	self._token += 1
	local token = self._token
	task.delay(PENDING_SECONDS, function()
		if self._token == token and self._pending then
			self._pending = false
			self:_paint()
		end
	end)
	self:_paint()
	self._callbacks.save(self._picks.main, self._picks.trim)
end

function BagColourPicker.open(self: any, saved: BagColours.Picks?)
	self._saved = BagColours.picks(saved)
	self._picks = BagColours.picks(saved)
	self._pending = false
	self._token += 1
	self.shown = true
	self.frame.Visible = true
	self:_paint()
end

-- Every ProfileSync says what is saved now; a Save that was out is answered by it.
function BagColourPicker.saved(self: any, saved: BagColours.Picks?)
	self._saved = BagColours.picks(saved)
	if self._pending then
		self._pending = false
		self._token += 1
	end
	if self.shown then
		self:_paint()
	end
end

function BagColourPicker.close(self: any)
	self.shown = false
	self.frame.Visible = false
	self._pending = false
	self._token += 1
end

function BagColourPicker.destroy(self: any)
	self._token += 1
	self._back:destroy()
	self._save:destroy()
	self._reset:destroy()
	self.frame:Destroy()
end

return BagColourPicker
