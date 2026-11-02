--!strict
-- The three leaderboards in town (F98, leaderboards.md section 2): chalkboards facing the Cat Cannon, Index,
-- Playtime and Money. Each face shows the top 10 of its all time list (rank, head picture, display name with a 👑
-- for an all time top 10, value), ranks 1 to 3 on gold, silver and bronze. Playtime and Money swap to This week every
-- 15 seconds with a gold "This week" ribbon. Under the ten, this player's own line: "You: #23" in the top 50, else
-- "You: 41 h 12 m". The board's name and icon are modelled above the face, so the face has no title.
--
-- Boards are Model-Agent's models tagged "Leaderboard" (CatCafe_Town_LeaderboardRow_Index, _Playtime and _Money),
-- each with a Screen part, 5 x 6.4 studs, whose Front face holds the list (a `Face` attribute on Screen turns it).
-- The face sits on the board's chalk green, so the gui has no background of its own. The lists come from the
-- server's LeaderboardSync through UI.leaderboards.sync.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. The "You" line differs per player, so the
-- SurfaceGui lives in PlayerGui with its Adornee set to the board's Screen; when the board streams out and back in,
-- the tag fires again and the face is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local LeaderboardLogic = require(script.Parent.Parent.Components.LeaderboardLogic)
local LeaderboardRow = require(script.Parent.Parent.Components.LeaderboardRow)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type LeaderboardBoards = {
	setSync: (self: LeaderboardBoards, sync: LeaderboardLogic.Sync?) -> (),
	destroy: (self: LeaderboardBoards) -> (),
}

local TAG = "Leaderboard"
local PIXELS_PER_STUD = 64 -- a 5 x 6.4 stud Screen is 320 x 410
local MAX_DISTANCE = 120 -- studs; past this the face is not drawn
local MARGIN = 8
local RIBBON_H = 30
local ROW_H = 30
local ROW_GAP = 2
local SWAP_CHECK = 1 -- seconds between looks at whether a face should swap its list

local ROW_LOOK: LeaderboardRow.Look = {
	height = ROW_H,
	textSize = 16,
	text = Theme.chalk,
	plain = Theme.colors.white,
	plainTransparency = 0.9,
	outlined = true,
}

type Board = {
	model: Instance,
	board: LeaderboardLogic.Board,
	gui: SurfaceGui,
	ribbon: TextLabel,
	rows: { LeaderboardRow.LeaderboardRow },
	empty: TextLabel,
	me: TextLabel,
	window: LeaderboardLogic.Window?,
	connections: { RBXScriptConnection },
}

local LeaderboardBoards = {}
LeaderboardBoards.__index = LeaderboardBoards

local FACES: { [string]: Enum.NormalId } = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
}

-- a look up rather than a == test against LeaderboardLogic.BOARDS, which would widen the board to a plain string
local KNOWN: { [string]: LeaderboardLogic.Board } =
	{ index = "index", playtime = "playtime", money = "money" }

-- "CatCafe_Town_LeaderboardRow_Playtime" -> "playtime"; a `Board` attribute wins when the model has one
local function boardOf(model: Instance): LeaderboardLogic.Board?
	local given = model:GetAttribute("Board")
	local name = if type(given) == "string" then given else model.Name:match("_(%a+)$")
	local id = if name ~= nil then name:lower() else nil
	return if id ~= nil then KNOWN[id] else nil
end

local function screenOf(model: Instance): BasePart?
	local screen = model:FindFirstChild("Screen", true)
	if screen == nil then
		-- Model-Agent's export names the part after its board ("..._Index_Screen")
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") and child.Name:match("_Screen$") then
				return child :: BasePart
			end
		end
		return nil
	end
	return if screen:IsA("BasePart") then screen :: BasePart else nil
end

local function faceOf(screen: BasePart): Enum.NormalId
	local face = screen:GetAttribute("Face")
	return if type(face) == "string" and FACES[face] then FACES[face] else Enum.NormalId.Front
end

function LeaderboardBoards.new(parent: Instance): LeaderboardBoards
	local self = setmetatable({}, LeaderboardBoards) :: any
	self._parent = parent
	self._sync = nil :: LeaderboardLogic.Sync?
	self._boards = {} :: { [Instance]: Board }
	self._connections = {} :: { RBXScriptConnection }
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
	-- Playtime and Money swap between All time and This week; every board looks once a second whether its turn came
	self._loop = task.spawn(function()
		while true do
			task.wait(SWAP_CHECK)
			for _, board in self._boards do
				if
					LeaderboardLogic.faceWindow(board.board, Workspace:GetServerTimeNow())
					~= board.window
				then
					self:_render(board)
				end
			end
		end
	end)
	return self :: LeaderboardBoards
end

function LeaderboardBoards._attach(self: any, model: Instance)
	-- only boards placed in the world: the tagged template in ReplicatedStorage.Assets gets no face
	if self._boards[model] or not model:IsDescendantOf(Workspace) then
		return
	end
	local id: LeaderboardLogic.Board? = boardOf(model)
	if id == nil then
		return
	end
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "Leaderboard_" .. id,
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		ClipsDescendants = true,
		Enabled = false,
	})
	local page: Frame = Create("Frame", {
		Name = "Page",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2),
		Parent = gui,
	})
	-- "All time", or a gold "This week" ribbon while the weekly list shows
	local ribbon: TextLabel = Create("TextLabel", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(150, RIBBON_H - 4),
		BackgroundColor3 = Theme.medals.gold,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextColor3 = Theme.chalk,
		Text = "All time",
		Parent = page,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.text(ribbon, 1.5)
	local list: Frame = Create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, RIBBON_H),
		Size = UDim2.new(
			1,
			0,
			0,
			LeaderboardLogic.BOARD_ROWS * ROW_H + (LeaderboardLogic.BOARD_ROWS - 1) * ROW_GAP
		),
		Parent = page,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local rows: { LeaderboardRow.LeaderboardRow } = {}
	for index = 1, LeaderboardLogic.BOARD_ROWS do
		local row = LeaderboardRow.new(list, ROW_LOOK, index)
		row.frame.Visible = false
		table.insert(rows, row)
	end
	local empty: TextLabel = Create("TextLabel", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, RIBBON_H + 40),
		Size = UDim2.new(1, 0, 0, 60),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = Theme.chalk,
		Text = "",
		Parent = page,
	})
	local me: TextLabel = Create("TextLabel", {
		Name = "You",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.colors.sky,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		FontFace = Theme.fonts.display,
		TextSize = 18,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Visible = false,
		Parent = page,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	Outline.text(me, 1.5)
	gui.Parent = self._parent
	local board: Board = {
		model = model,
		board = id,
		gui = gui,
		ribbon = ribbon,
		rows = rows,
		empty = empty,
		me = me,
		window = nil,
		connections = {},
	}
	self._boards[model] = board
	-- a board streamed in part by part: hang the face once its Screen arrives, and again if it is replaced
	table.insert(
		board.connections,
		model.DescendantAdded:Connect(function(child: Instance)
			if child:IsA("BasePart") then
				self:_hang(board)
			end
		end)
	)
	table.insert(
		board.connections,
		model.DescendantRemoving:Connect(function(child: Instance)
			if child == board.gui.Adornee then
				task.defer(function()
					self:_hang(board)
				end)
			end
		end)
	)
	self:_hang(board)
	self:_render(board)
end

function LeaderboardBoards._hang(_self: any, board: Board)
	local screen = screenOf(board.model)
	if screen ~= nil and screen.Parent == nil then
		screen = nil
	end
	board.gui.Adornee = screen :: any
	if screen ~= nil then
		board.gui.Face = faceOf(screen)
	end
	board.gui.Enabled = screen ~= nil
end

function LeaderboardBoards._render(self: any, board: Board)
	local sync: LeaderboardLogic.Sync? = self._sync
	local window: LeaderboardLogic.Window =
		LeaderboardLogic.faceWindow(board.board, Workspace:GetServerTimeNow())
	board.window = window
	local weekly = window == "week"
	board.ribbon.Text = if weekly then "This week" else "All time"
	board.ribbon.BackgroundTransparency = if weekly then 0 else 1
	board.ribbon.TextColor3 = if weekly then Theme.colors.white else Theme.chalk
	local rows = LeaderboardLogic.rows(sync, board.board, window, LeaderboardLogic.BOARD_ROWS)
	local userId = Players.LocalPlayer.UserId
	for index, view in board.rows do
		local row = rows[index]
		view:paint(row, board.board, row ~= nil and row.userId == userId)
	end
	board.empty.Text = if sync == nil
		then "Loading the board..."
		elseif #rows == 0 then (if weekly
			then "No one yet this week. Play to be first!"
			else "No one yet. Play to be first!")
		else ""
	board.empty.Visible = #rows == 0
	local line = if sync ~= nil
		then LeaderboardLogic.meLine(sync, board.board, window, userId)
		else nil
	board.me.Text = line or ""
	board.me.Visible = line ~= nil
end

function LeaderboardBoards.setSync(self: any, sync: LeaderboardLogic.Sync?)
	self._sync = sync
	for _, board in self._boards do
		self:_render(board)
	end
end

function LeaderboardBoards._detach(self: any, model: Instance)
	local board: Board? = self._boards[model]
	if board == nil then
		return
	end
	for _, connection in board.connections do
		connection:Disconnect()
	end
	for _, row in board.rows do
		row:destroy()
	end
	board.gui:Destroy()
	self._boards[model] = nil
end

function LeaderboardBoards.destroy(self: any)
	if self._loop then
		task.cancel(self._loop)
		self._loop = nil
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	local models: { Instance } = {}
	for model in self._boards do
		table.insert(models, model)
	end
	for _, model in models do
		self:_detach(model)
	end
end

return LeaderboardBoards
