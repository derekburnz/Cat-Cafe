--!strict
-- #5502 the advent calendar board in the Town Square (Model-Agent's CatCafe_Square_AdventBoard), on this client. The
-- server places the board and tags it BOARD_TAG; once a second this gives it a ProximityPrompt (Roblox's "press E /
-- tap" button over a part) at its PromptAnchor that opens the calendar's card, and swings open the doors this
-- player has opened (each door is its own piece pivoted on its hinge, so a turn about Y opens it; the swing is local,
-- so every player sees their own doors). The prompt shows only while the server's view says the calendar is live
-- (both switches on and the dates come), so before Dec 1 a board that is somehow in the world is only a prop.
-- Nothing here opens a door: the card fires OpenAdventDoor and the server decides.

local CollectionService = game:GetService("CollectionService")

local AdventLogic = require(script.Parent.Parent.UI.Components.AdventLogic)
local Net = require(script.Parent.Parent.Net)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local AdventBoardController = {}

AdventBoardController.BOARD_TAG = "AdventBoard"

local TICK_SECONDS = 1
local PROMPT_DISTANCE = 12
local PROMPT_NAME = "AdventPrompt"
local ANCHOR = "PromptAnchor"
local DOOR_NAME = "CatCafe_Square_AdventBoard_Door%02d"
local OPEN_TURN = math.rad(-105) -- negative opens a door out to the front (assets/cat-cafe/blender/advent.py)

-- each door's closed place, kept the first time it is seen, and whether it is swung open now
local closed: { [Instance]: CFrame } = {}
local swung: { [Instance]: boolean } = {}

local function view(): AdventLogic.View?
	local state = UIController.state
	return if state ~= nil then (state :: any).advent else nil
end

local function promptOf(board: Instance): ProximityPrompt?
	local anchor = board:FindFirstChild(ANCHOR, true)
	if anchor == nil or not (anchor:IsA("BasePart") or anchor:IsA("Attachment")) then
		anchor = if board:IsA("Model")
			then (board :: Model).PrimaryPart or board:FindFirstChildWhichIsA("BasePart", true)
			else nil
	end
	if anchor == nil then
		return nil
	end
	local found = anchor:FindFirstChild(PROMPT_NAME)
	if found ~= nil and found:IsA("ProximityPrompt") then
		return found :: ProximityPrompt
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Open"
	prompt.ObjectText = "Advent Calendar"
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = false
	prompt.Triggered:Connect(function()
		if UI.advent.open() then
			Net.fire("TelemetryReport", "advent_board", "board")
		end
	end)
	prompt.Parent = anchor
	return prompt
end

local function swing(board: Instance, opened: number)
	for n = 1, AdventLogic.DOORS do
		local door = board:FindFirstChild(DOOR_NAME:format(n), true)
		if door == nil or not door:IsA("PVInstance") then
			continue
		end
		local piece = door :: PVInstance
		local open = n <= opened
		if swung[piece] == open then
			continue
		end
		local shut = closed[piece]
		if shut == nil then
			shut = piece:GetPivot()
			closed[piece] = shut
			piece.Destroying:Once(function()
				closed[piece] = nil
				swung[piece] = nil
			end)
		end
		piece:PivotTo(if open then shut * CFrame.Angles(0, OPEN_TURN, 0) else shut)
		swung[piece] = open
	end
end

local function tick()
	local now = view()
	local shows = AdventLogic.shows(now)
	for _, board in CollectionService:GetTagged(AdventBoardController.BOARD_TAG) do
		local prompt = promptOf(board)
		if prompt ~= nil then
			prompt.Enabled = shows
			prompt.ActionText = if now ~= nil and now.ready then "Open a door" else "Look"
		end
		swing(board, if shows and now ~= nil then now.opened else 0)
	end
end

function AdventBoardController.start()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local ok, problem = pcall(function()
				tick()
				return nil :: any
			end)
			if not ok then
				warn("[AdventBoard] " .. tostring(problem))
				task.wait(10)
			end
		end
	end)
end

return AdventBoardController
