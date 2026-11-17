--!strict
-- #4251 Harvest Hollow's Thankful Board face (harvest-hollow-spec sections 5 and 6). Model-Agent's CatCafe_Harvest_Board
-- (tag HarvestBoard, placed by HarvestWorld) has a chalkboard Screen part, 10 x 5.6 studs, facing front (-Z) on a
-- dark navy face. On the left the Feast Pie: eight slices that bake gold as the all-servers count grows, "Feast Pie
-- 3/8 baked", "12,345 / 25,000 harvest cats" and whether this player has helped. On the right the last 12 thank-you
-- notes pinned in this server: each with the player's avatar picture and one of the six fixed notes (no names, no
-- typed text). The numbers are ReplicatedStorage's HarvestPieCount, HarvestPieGoal and HarvestPieSlices
-- (HarvestPieService); the notes are the board's HarvestNotes attribute (HarvestService). Rules: Components/ThankfulLogic.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- board's Screen; when the board streams out and back in, the tag fires again and the face is hung on the new copy.
-- Roblox UI has no pie shape, so each slice is a fan of thin bars from the middle to the rim (the Admin Wheel's way).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local ThankfulLogic = require(script.Parent.Parent.Components.ThankfulLogic)
local Theme = require(script.Parent.Parent.Theme)

export type ThankfulBoard = {
	destroy: (self: ThankfulBoard) -> (),
	refresh: (self: ThankfulBoard) -> (),
}

type Face = {
	model: Instance,
	gui: SurfaceGui,
	title: TextLabel,
	line: TextLabel,
	helped: TextLabel,
	slices: { { Frame } },
	notes: { Frame },
	empty: TextLabel,
	link: RBXScriptConnection,
}

local PIXELS_PER_STUD = 100 -- the 10 x 5.6 stud Screen is 1000 x 560
local MAX_DISTANCE = 120 -- studs; past this the face is not drawn
local TICK_SECONDS = 5 -- the helped line (PlayerState) between attribute changes
local PIE = 300 -- the pie's width in pixels
local WEDGE_STEP = 3 -- degrees a bar
local SPOKE = 4
local NOTE_W, NOTE_H = 224, 72
local BAKED = Color3.fromHex("F2B347") -- golden crust
local BAKED_DARK = Color3.fromHex("C9822B")
local UNBAKED = Color3.fromHex("3A4766") -- the empty pie tin on the navy board
local CHALK = Color3.fromHex("FFF6E5")
local INK = Theme.colors.outline

local ThankfulBoard = {}
ThankfulBoard.__index = ThankfulBoard

local function screenOf(model: Instance): BasePart?
	local screen = model:FindFirstChild("Screen", true)
	if screen ~= nil and screen:IsA("BasePart") then
		return screen :: BasePart
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name:match("_Screen$") then
			return child :: BasePart
		end
	end
	return nil
end

local function isScreen(child: Instance): boolean
	return child:IsA("BasePart") and (child.Name == "Screen" or child.Name:match("_Screen$") ~= nil)
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = CHALK,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

-- Eight slices, each a fan of bars, with a dark spoke after each and a rim round the tin.
local function buildPie(parent: Instance): { { Frame } }
	local face: Frame = Create("Frame", {
		Name = "Pie",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(250, 66),
		Size = UDim2.fromOffset(PIE, PIE),
		BackgroundColor3 = UNBAKED,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = BAKED_DARK, Thickness = 8 }),
	})
	local slices: { { Frame } } = {}
	local size = 360 / ThankfulLogic.SLICES
	local steps = math.max(2, math.ceil(size / WEDGE_STEP))
	local step = size / steps
	local width = 0.5 * math.sin(math.rad(step)) * 1.15
	for index = 1, ThankfulLogic.SLICES do
		local bars: { Frame } = {}
		local from = (index - 1) * size
		local function add(base: number, sideOf: number)
			local theta = math.rad(base)
			local sin, cos = math.sin(theta), math.cos(theta)
			local offset = width / 2
			table.insert(
				bars,
				Create("Frame", {
					Name = "Slice" .. index,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(
						0.5 + 0.235 * sin + sideOf * offset * cos,
						0.5 - 0.235 * cos + sideOf * offset * sin
					),
					Size = UDim2.fromScale(width, 0.47),
					Rotation = base,
					BackgroundColor3 = UNBAKED,
					BorderSizePixel = 0,
					ZIndex = 1,
					Parent = face,
				})
			)
		end
		for k = 0, math.ceil(steps / 2) - 1 do
			add(from + k * step, 1)
		end
		for k = 0, math.ceil(steps / 2) - 1 do
			add(from + size - k * step, -1)
		end
		local edge = math.rad(from + size)
		Create("Frame", {
			Name = "Spoke" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + 0.25 * math.sin(edge), 0.5 - 0.25 * math.cos(edge)),
			Size = UDim2.new(0, SPOKE, 0.5, 0),
			Rotation = from + size,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = face,
		})
		slices[index] = bars
	end
	return slices
end

function ThankfulBoard.new(parent: Instance, helped: () -> boolean?): ThankfulBoard
	local self = setmetatable({}, ThankfulBoard) :: any
	self._parent = parent
	self._helped = helped
	self._faces = {} :: { [Instance]: Face }
	self._waiting = {} :: { [Instance]: RBXScriptConnection }
	self._connections = {} :: { RBXScriptConnection }
	self._alive = true
	for _, model in CollectionService:GetTagged(ThankfulLogic.TAG) do
		self:_attach(model)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(ThankfulLogic.TAG)
			:Connect(function(model: Instance)
				self:_attach(model)
			end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(ThankfulLogic.TAG)
			:Connect(function(model: Instance)
				self:_detach(model)
			end)
	)
	for _, name in
		{
			ThankfulLogic.COUNT_ATTRIBUTE,
			ThankfulLogic.GOAL_ATTRIBUTE,
			ThankfulLogic.SLICES_ATTRIBUTE,
		}
	do
		table.insert(
			self._connections,
			ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
				self:refresh()
			end)
		)
	end
	task.spawn(function()
		while self._alive do
			task.wait(TICK_SECONDS)
			if self._alive and next(self._faces) ~= nil then
				self:refresh()
			end
		end
	end)
	return self :: ThankfulBoard
end

function ThankfulBoard._attach(self: any, model: Instance)
	if self._faces[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		-- the Screen part can stream in after the tag fires: wait for it, then attach
		if self._waiting[model] == nil then
			self._waiting[model] = model.DescendantAdded:Connect(function(child: Instance)
				if isScreen(child) then
					local waiting = self._waiting[model]
					if waiting then
						waiting:Disconnect()
						self._waiting[model] = nil
					end
					if self._alive then
						self:_attach(model)
					end
				end
			end)
		end
		return
	end
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "ThankfulBoardFace",
		Adornee = screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self._parent,
	})
	-- the left half: the Feast Pie
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.fromOffset(460, 46),
		TextSize = 38,
		TextColor3 = BAKED,
		Parent = gui,
	})
	Outline.text(title, 3)
	local slices = buildPie(gui)
	local line = text({
		Name = "Count",
		Position = UDim2.fromOffset(20, 382),
		Size = UDim2.fromOffset(460, 38),
		TextSize = 30,
		Parent = gui,
	})
	Outline.text(line, 2)
	local helpedLine = text({
		Name = "Helped",
		Position = UDim2.fromOffset(20, 426),
		Size = UDim2.fromOffset(460, 32),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 24,
		Parent = gui,
	})
	-- a chalk line down the middle
	Create("Frame", {
		Name = "Divider",
		Position = UDim2.fromOffset(499, 24),
		Size = UDim2.fromOffset(3, 512),
		BackgroundColor3 = CHALK,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = gui,
	})
	-- the right half: the notes
	local heading = text({
		Name = "NotesTitle",
		Position = UDim2.fromOffset(520, 12),
		Size = UDim2.fromOffset(460, 46),
		TextSize = 38,
		Text = "Thank you notes",
		Parent = gui,
	})
	Outline.text(heading, 3)
	local notes: { Frame } = {}
	for index = 1, 12 do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		local card: Frame = Create("Frame", {
			Name = "Note" .. index,
			Position = UDim2.fromOffset(520 + column * (NOTE_W + 12), 66 + row * (NOTE_H + 8)),
			Size = UDim2.fromOffset(NOTE_W, NOTE_H),
			BackgroundColor3 = CHALK,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Visible = false,
			Parent = gui,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		})
		Create("ImageLabel", {
			Name = "Avatar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = BAKED,
			BorderSizePixel = 0,
			Image = "",
			Parent = card,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		text({
			Name = "Words",
			Position = UDim2.fromOffset(72, 4),
			Size = UDim2.new(1, -78, 1, -8),
			FontFace = Theme.fonts.bodyBold,
			TextSize = 22,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		notes[index] = card
	end
	local empty = text({
		Name = "Empty",
		Position = UDim2.fromOffset(530, 220),
		Size = UDim2.fromOffset(440, 100),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 26,
		TextWrapped = true,
		Text = "No notes yet. Pin the first one!",
		Parent = gui,
	})
	local link = model:GetAttributeChangedSignal(ThankfulLogic.NOTES_ATTRIBUTE):Connect(function()
		local face = self._faces[model]
		if face then
			self:_paintNotes(face)
		end
	end)
	local face: Face = {
		model = model,
		gui = gui,
		title = title,
		line = line,
		helped = helpedLine,
		slices = slices,
		notes = notes,
		empty = empty,
		link = link,
	}
	self._faces[model] = face
	self:_paintPie(face)
	self:_paintNotes(face)
end

function ThankfulBoard._detach(self: any, model: Instance)
	local waiting = self._waiting[model]
	if waiting then
		waiting:Disconnect()
		self._waiting[model] = nil
	end
	local face: Face? = self._faces[model]
	if face then
		face.link:Disconnect()
		face.gui:Destroy()
		self._faces[model] = nil
	end
end

function ThankfulBoard._paintPie(self: any, face: Face)
	local pie = ThankfulLogic.pie(
		ReplicatedStorage:GetAttribute(ThankfulLogic.COUNT_ATTRIBUTE),
		ReplicatedStorage:GetAttribute(ThankfulLogic.GOAL_ATTRIBUTE),
		ReplicatedStorage:GetAttribute(ThankfulLogic.SLICES_ATTRIBUTE)
	)
	face.title.Text = pie.title
	face.line.Text = pie.line
	face.helped.Text = ThankfulLogic.helpedLine(self._helped())
	for index, bars in face.slices do
		local color = if index <= pie.slices then BAKED else UNBAKED
		for _, bar in bars do
			bar.BackgroundColor3 = color
		end
	end
end

function ThankfulBoard._paintNotes(_self: any, face: Face)
	local list = ThankfulLogic.notes(face.model:GetAttribute(ThankfulLogic.NOTES_ATTRIBUTE))
	for index, card in face.notes do
		local note = list[index]
		card.Visible = note ~= nil
		if note then
			local avatar = card:FindFirstChild("Avatar") :: ImageLabel
			avatar.Image = ThankfulLogic.headshot(note.userId)
			local words = card:FindFirstChild("Words") :: TextLabel
			words.Text = note.text
		end
	end
	face.empty.Visible = #list == 0
end

function ThankfulBoard.refresh(self: any)
	for _, face in self._faces do
		self:_paintPie(face)
	end
end

function ThankfulBoard.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, waiting in self._waiting do
		waiting:Disconnect()
	end
	table.clear(self._waiting)
	for model in self._faces do
		self:_detach(model)
	end
end

return ThankfulBoard
