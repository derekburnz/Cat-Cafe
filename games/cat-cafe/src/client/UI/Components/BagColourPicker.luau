--!strict
-- #3699 (shared/BagColours; Design-Agent's picks on the issue): the Backpack's colour picker, a page inside Juniper's
-- window. Top row: Reset, Save and Back. Left: a drawn bag that changes as the player taps. Right: two blocks of
-- twelve swatches, "Bag" and "Trim", six to a row. Nothing is sent until Save; Reset picks the built colours again
-- (and is saved by Save like any pick). Back returns to the shelf without saving.
-- On a short screen (a phone held sideways) the two blocks do not both fit beside the bag, so a Bag and Trim pair
-- of tabs under the drawn bag shows one block at a time and the list never needs a scroll to reach Trim.
-- #4049 (Derek 2026-11-13: the shoes too, "with a little side menu that shows an image of what they look like as
-- they are changing the color"): one picker for each kind of shared/BagColours ("bag", "shoes"). The left side shows
-- the real model in a ViewportFrame, tinted as the player taps (the drawn bag stays for a bag whose model is not
-- in Assets yet), and the swatches are the kind's own twelve.
--   BagColourPicker.new(parent, callbacks) -> picker
--   picker:open(saved, kind?)  show it for `kind` ("bag" when left out), starting from the saved picks
--   picker:saved(saved)     the server's answer: the saved picks as they stand now
--   picker:close()
--   picker.frame, picker.shown

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BagColours = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BagColours"))
local Button = require(script.Parent.Button)
local Create = require(script.Parent.Create)
local HeldCat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeldCat"))
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local SpeedShoes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpeedShoes"))
local Theme = require(script.Parent.Parent.Theme)

local PAL = Theme.dark

export type Callbacks = {
	save: (main: string, trim: string, kind: string) -> (),
	back: () -> (),
}

export type BagColourPicker = {
	frame: Frame,
	shown: boolean,
	open: (self: BagColourPicker, saved: BagColours.Picks?, kind: string?) -> (),
	saved: (self: BagColourPicker, saved: BagColours.Picks?) -> (),
	close: (self: BagColourPicker) -> (),
	destroy: (self: BagColourPicker) -> (),
}

local BagColourPicker = {}
BagColourPicker.__index = BagColourPicker

BagColourPicker.SWATCH = 44 -- a thumb's width
BagColourPicker.COLUMNS = 6
BagColourPicker.TOUCH_COLUMNS = 4
BagColourPicker.SLOTS = { "main", "trim" }
local GAP = 6
local LEFT_W = 112
local PREVIEW = 104
local HEAD_W = 80 -- Reset, Save and Back in the top row
local PENDING_SECONDS = 5
-- #4049: the model each kind shows in the preview, and the children of it that are the worn item
local MODELS: { [string]: { asset: string, keep: { string }? } } = {
	bag = { asset = HeldCat.PACK_ASSET },
	shoes = {
		asset = SpeedShoes.ASSET,
		keep = { SpeedShoes.ASSET .. "_Left", SpeedShoes.ASSET .. "_Right" },
	},
}

-- A copy of `kind`'s model with no scripts, only its worn parts, or nil while Assets lacks it.
local function previewModel(kind: string): Model?
	local spec = MODELS[kind]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if spec ~= nil and assets ~= nil then assets:FindFirstChild(spec.asset) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local copy: Model = (source :: Model):Clone() :: any
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	local keep = spec.keep
	if keep ~= nil then
		for _, child in copy:GetChildren() do
			if table.find(keep, child.Name) == nil then
				child:Destroy()
			end
		end
	end
	return copy
end

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
	self._kind = "bag"
	self._ids = { main = {}, trim = {} } :: { [string]: { [TextButton]: string } } -- #4049: each swatch's id now
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

	self._title = label({
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
	self._drawn = { clasp } :: { GuiObject }
	for _, part in self._parts do
		table.insert(self._drawn, part[1])
	end
	-- #4049: the real model, over the drawn bag, turned a little so both shoes or the bag's front and side show
	local camera: Camera = Create("Camera", { FieldOfView = 30 })
	local view: ViewportFrame = Create("ViewportFrame", {
		Name = "Model",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(200, 190, 180),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = 3,
		Visible = false,
		Parent = preview,
	})
	camera.Parent = view
	view.CurrentCamera = camera
	self._view = view
	self._camera = camera
	self._model = nil :: Model?

	-- a short screen: Bag and Trim tabs under the bag, one block of swatches at a time
	self._tabbed = Scale.isShort()
	self._slot = "main"
	self._tabs = {} :: { [string]: any }
	if self._tabbed then
		local tabW = math.floor((LEFT_W - 6) / 2)
		for index, slot in BagColourPicker.SLOTS do
			local words = if slot == "main" then BagColours.WORDS.main else BagColours.WORDS.trim
			self._tabs[slot] = Button.new({
				name = "Tab_" .. slot,
				text = words,
				style = "ghost",
				size = UDim2.fromOffset(tabW, tap),
				position = UDim2.fromOffset(8 + (index - 1) * (tabW + 6), top + PREVIEW + 6),
				textSize = Theme.sizes.textSmall,
				parent = frame,
				onClick = function()
					self._slot = slot
					self:_paint()
				end,
			})
		end
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
			self._picks = BagColours.picks(nil, self._kind)
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
	self._grids = {} :: { [string]: Frame }
	for order, slot in BagColourPicker.SLOTS do
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
		self._grids[slot] = grid
		for index, row in BagColours.LIST do
			local button: TextButton = Create("TextButton", {
				Name = "Swatch_" .. index,
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
				local id = self._ids[slot][button]
				if id == nil then
					return
				end
				local picks = table.clone(self._picks)
				picks[slot] = id
				self._picks = picks
				self:_paint()
			end)
			self._ids[slot][button] = row.id
		end
	end
	self:_setKind("bag")
	self:_paint()
	return self :: BagColourPicker
end

-- #4049: the swatches, title and preview for `kind`.
function BagColourPicker._setKind(self: any, kind: string)
	self._kind = kind
	local info = BagColours.info(kind)
	self._title.Text = info.title
	for slot, ids in self._ids do
		local byId: { [string]: TextButton } = {}
		local grid: Frame = self._grids[slot]
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") then
				local button = child :: TextButton
				local row = info.list[button.LayoutOrder]
				button.Visible = row ~= nil
				if row ~= nil then
					button.Name = "Swatch_" .. row.id
					button.BackgroundColor3 = row.color
					ids[button] = row.id
					byId[row.id] = button
				else
					ids[button] = nil
				end
			end
		end
		self._swatches[slot] = byId
	end
	local old: Model? = self._model
	if old ~= nil then
		old:Destroy()
	end
	local model = previewModel(kind)
	self._model = model
	if model ~= nil then
		local box, size = model:GetBoundingBox()
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(15)) * 1.05
		-- from the front left and a little above, the model's front being -Z
		local from = box.Position
			+ (CFrame.Angles(0, math.rad(-35), 0) * Vector3.new(0, 0.45, -1)).Unit * distance
		self._camera.CFrame = CFrame.lookAt(from, box.Position)
		model.Parent = self._view
	end
	self._view.Visible = model ~= nil
	local mainTab = self._tabs.main
	if mainTab ~= nil then
		mainTab:setText(info.mainWord)
	end
	for _, drawn in self._drawn do
		drawn.Visible = model == nil and kind == "bag"
	end
end

function BagColourPicker._changed(self: any): boolean
	return self._picks.main ~= self._saved.main or self._picks.trim ~= self._saved.trim
end

function BagColourPicker._paint(self: any)
	local picks: BagColours.Picks = self._picks
	local kind: string = self._kind
	for _, part in self._parts do
		local frame: Frame, slot: string, step: number = part[1], part[2], part[3]
		frame.BackgroundColor3 = BagColours.colorFor(BagColours.BUILT[slot][step], picks)
	end
	local model: Model? = self._model
	if model ~= nil then
		BagColours.tint(model, picks, kind)
	end
	local info = BagColours.info(kind)
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
		local words = if slot == "main" then info.mainWord else BagColours.WORDS.trim
		self._names[slot].Text = if row ~= nil then words .. ": " .. row.name else words
	end
	if self._tabbed then
		for slot, tab in self._tabs do
			local on = slot == self._slot
			tab:setStyle(if on then "primary" else "ghost")
			self._names[slot].Visible = on
			self._grids[slot].Visible = on
		end
	end
	local defaults = BagColours.picks(nil, kind)
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
	self._callbacks.save(self._picks.main, self._picks.trim, self._kind)
end

function BagColourPicker.open(self: any, saved: BagColours.Picks?, kind: string?)
	local wanted = if kind == "shoes" then "shoes" else "bag"
	if wanted ~= self._kind or self._model == nil then
		self:_setKind(wanted)
	end
	self._saved = BagColours.picks(saved, wanted)
	self._picks = BagColours.picks(saved, wanted)
	self._pending = false
	self._token += 1
	self._slot = "main"
	self.shown = true
	self.frame.Visible = true
	self:_paint()
end

-- Every ProfileSync says what is saved now; a Save that was out is answered by it.
function BagColourPicker.saved(self: any, saved: BagColours.Picks?)
	self._saved = BagColours.picks(saved, self._kind)
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
	for _, tab in self._tabs do
		tab:destroy()
	end
	self.frame:Destroy()
end

return BagColourPicker
