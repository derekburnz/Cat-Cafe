--!strict
-- The Cafe Event board's face in the Town Square (#2487, live-events.md section 3): "Cafe Party in 2:59:10" from T-3h
-- with the window and one line per effect ("x2 cafe earnings", "8 rare cat showers", "Lucky, Golden and Rainbow Day",
-- "+0.5 Luck", "Free Party Bunting"); "Cafe Party!" with "Ends at 17:00 · 1:59:40 left" while it runs; "Thanks for
-- coming!" for an hour after; between events the next one's day and time (Components/EventLogic.board). The board is
-- Model-Agent's CatCafe_Square_EventBoard (#2488), tagged "EventBoard", with a part named "Screen" (or "..._Screen")
-- whose front (-Z) face carries the words. The face lays out by share of its size, so any face size works; it has no
-- background of its own and no animation (the sand in the hourglass frame is the model's, and Reduce Motion is VFX's).
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- board's Screen; when the board streams out and back in, the tag fires again and the face is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local EventLogic = require(script.Parent.Parent.Components.EventLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type EventBoards = {
	set: (self: EventBoards, view: EventLogic.View?, seen: EventLogic.Seen?) -> (),
	destroy: (self: EventBoards) -> (),
}

type Board = {
	model: Instance,
	gui: SurfaceGui,
	heading: TextLabel,
	sub: TextLabel,
	lines: { TextLabel },
}

local TAG = "EventBoard"
local PIXELS_PER_STUD = 50
local MAX_DISTANCE = 150 -- studs; past this the face is not drawn
local TICK_SECONDS = 1
local LINES = 5 -- one per effect at most
local HEADING = 0.2 -- shares of the face's height
local SUB = 0.13
local LINE = 0.12

local EventBoards = {}
EventBoards.__index = EventBoards
EventBoards.TAG = TAG
EventBoards.LINES = LINES

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

local function text(props: { [string]: any }, maxSize: number): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextScaled = true,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local label: TextLabel = Create("TextLabel", merged)
	Create("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = label })
	Outline.text(label, 3)
	return label
end

local function localTime(unix: number, pattern: string): string
	return os.date(pattern, math.floor(unix)) :: string
end

function EventBoards.new(parent: Instance): EventBoards
	local self = setmetatable({}, EventBoards) :: any
	self._parent = parent
	self._view = nil :: EventLogic.View?
	self._seen = nil :: EventLogic.Seen?
	self._boards = {} :: { [Instance]: Board }
	self._connections = {} :: { RBXScriptConnection }
	self._waiting = {} :: { [Instance]: RBXScriptConnection }
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
	return self :: EventBoards
end

function EventBoards._attach(self: any, model: Instance)
	if self._boards[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		-- the Screen part can stream in after the tag fires: wait for it, then attach
		if self._waiting[model] == nil then
			self._waiting[model] = model.DescendantAdded:Connect(function(child: Instance)
				if
					child:IsA("BasePart")
					and (child.Name == "Screen" or child.Name:match("_Screen$"))
				then
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
		Name = "EventBoardFace",
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
	local heading = text({
		Name = "Heading",
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.9, HEADING),
		TextColor3 = Theme.colors.gold,
		Parent = gui,
	}, 64)
	local sub = text({
		Name = "Sub",
		Position = UDim2.fromScale(0.05, 0.04 + HEADING),
		Size = UDim2.fromScale(0.9, SUB),
		FontFace = Theme.fonts.bodyBold,
		TextColor3 = Theme.chalk,
		Parent = gui,
	}, 36)
	local lines = {}
	for index = 1, LINES do
		lines[index] = text({
			Name = "Line" .. index,
			Position = UDim2.fromScale(0.08, 0.04 + HEADING + SUB + 0.03 + (index - 1) * LINE),
			Size = UDim2.fromScale(0.84, LINE - 0.01),
			FontFace = Theme.fonts.bodyBold,
			Visible = false,
			Parent = gui,
		}, 32)
	end
	local board: Board = { model = model, gui = gui, heading = heading, sub = sub, lines = lines }
	self._boards[model] = board
	self:_render(board)
end

function EventBoards._detach(self: any, model: Instance)
	local waiting = self._waiting[model]
	if waiting then
		waiting:Disconnect()
		self._waiting[model] = nil
	end
	local board: Board? = self._boards[model]
	if board then
		board.gui:Destroy()
		self._boards[model] = nil
	end
end

function EventBoards._render(self: any, board: Board)
	local face = EventLogic.board(self._view, self._seen, Workspace:GetServerTimeNow(), localTime)
	board.heading.Text = face.heading
	board.sub.Text = face.sub or ""
	board.sub.Visible = face.sub ~= nil
	for index, label in board.lines do
		local line = face.lines[index]
		label.Text = if line ~= nil then "• " .. line else ""
		label.Visible = line ~= nil
	end
end

function EventBoards._renderAll(self: any)
	for _, board in self._boards do
		self:_render(board)
	end
end

function EventBoards.set(self: any, view: EventLogic.View?, seen: EventLogic.Seen?)
	self._view = view
	self._seen = seen
	self:_renderAll()
end

function EventBoards.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, waiting in self._waiting do
		waiting:Disconnect()
	end
	table.clear(self._waiting)
	for model in self._boards do
		self:_detach(model)
	end
end

return EventBoards
