--!strict
-- The Rescue Rally board's face in the Town Square (F101, rescue-rally.md section 4: "a big Rally board by the cannon
-- showing the bar"): "🏁 RESCUE RALLY" with a gold "Lap 2" chip from the second lap, the bar with its three step
-- pictures (Components/RallyBar) and the time left in the weekend, big enough to read from the cannon. The board is
-- Model-Agent's CatCafe_Square_RallyBoard (#759), tagged "RallyBoard" and parented into the square only while a Rally
-- runs; its Screen part, 10 x 4 studs, faces front (-Z) on a navy face, so the gui has no background of its own.
-- VFX's Effects/RallyBoard chases the bulbs round it.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- board's Screen; when the board streams out and back in, the tag fires again and the face is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local RallyBar = require(script.Parent.Parent.Components.RallyBar)
local RallyLogic = require(script.Parent.Parent.Components.RallyLogic)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

export type RallyBoards = {
	set: (self: RallyBoards, state: Types.RallyState?) -> (),
	destroy: (self: RallyBoards) -> (),
}

type Board = {
	model: Instance,
	gui: SurfaceGui,
	lap: TextLabel,
	left: TextLabel,
	bar: RallyBar.RallyBar,
}

local TAG = "RallyBoard"
local PIXELS_PER_STUD = 50 -- the 10 x 4 stud Screen is 500 x 200
local MAX_DISTANCE = 150 -- studs; past this the face is not drawn
local TICK_SECONDS = 1

local RallyBoards = {}
RallyBoards.__index = RallyBoards

local function screenOf(model: Instance): BasePart?
	local screen = model:FindFirstChild("Screen", true)
	if screen ~= nil and screen:IsA("BasePart") then
		return screen :: BasePart
	end
	-- an export may name the part after its board ("..._RallyBoard_Screen")
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name:match("_Screen$") then
			return child :: BasePart
		end
	end
	return nil
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function RallyBoards.new(parent: Instance): RallyBoards
	local self = setmetatable({}, RallyBoards) :: any
	self._parent = parent
	self._state = nil :: Types.RallyState?
	self._boards = {} :: { [Instance]: Board }
	self._connections = {} :: { RBXScriptConnection }
	self._alive = true
	for _, model in CollectionService:GetTagged(TAG) do
		self:_attach(model)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model: Instance)
			self:_attach(model)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model: Instance)
			self:_detach(model)
		end)
	)
	task.spawn(function()
		while self._alive do
			task.wait(TICK_SECONDS)
			if self._alive and next(self._boards) ~= nil then
				self:_renderAll()
			end
		end
	end)
	return self :: RallyBoards
end

function RallyBoards._attach(self: any, model: Instance)
	if self._boards[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		return
	end
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "RallyBoardFace",
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
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -150, 0, 42),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = RallyLogic.ICON .. " " .. string.upper(RallyLogic.TITLE),
		Parent = gui,
	})
	Outline.text(title, 3)
	local lap = text({
		Name = "Lap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 18),
		Size = UDim2.fromOffset(104, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		TextSize = 22,
		TextColor3 = Theme.colors.goldText,
		Visible = false,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lap })
	local bar = RallyBar.new({
		parent = gui,
		name = "RallyBoardBar", -- not RallyBar: VFX's pops look for the banner's
		size = UDim2.new(1, -96, 0, 40),
		position = UDim2.fromOffset(40, 82),
		marker = 62,
		textSize = 24,
	})
	local left = text({
		Name = "Left",
		Position = UDim2.fromOffset(24, 148),
		Size = UDim2.new(1, -48, 0, 34),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 24,
		TextColor3 = Theme.chalk,
		Parent = gui,
	})
	local board: Board = { model = model, gui = gui, lap = lap, left = left, bar = bar }
	self._boards[model] = board
	self:_render(board)
end

function RallyBoards._detach(self: any, model: Instance)
	local board: Board? = self._boards[model]
	if board then
		board.bar:destroy()
		board.gui:Destroy()
		self._boards[model] = nil
	end
end

function RallyBoards._render(self: any, board: Board)
	local view = RallyLogic.view(self._state, Workspace:GetServerTimeNow())
	board.gui.Enabled = view ~= nil
	if view == nil then
		return
	end
	board.lap.Text = view.lap or ""
	board.lap.Visible = view.lap ~= nil
	board.left.Text = view.left
	board.bar:set(view)
end

function RallyBoards._renderAll(self: any)
	for _, board in self._boards do
		self:_render(board)
	end
end

function RallyBoards.set(self: any, state: Types.RallyState?)
	self._state = state
	self:_renderAll()
end

function RallyBoards.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for model in self._boards do
		self:_detach(model)
	end
end

return RallyBoards
