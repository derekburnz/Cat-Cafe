--!strict
-- #5502 the advent calendar board in the Town Square (Model-Agent's CatCafe_Square_AdventBoard), on this client. The
-- server places the board and tags it BOARD_TAG; once a second this gives it a ProximityPrompt (Roblox's "press E /
-- tap" button over a part) at its PromptAnchor that opens the calendar's card. The prompt shows only while the
-- server's view says the calendar is live (both switches on and the dates come), so before Dec 1 a board that is
-- somehow in the world is only a prop. The doors' swing is Effects/AdventFx's (#5514), not this file's.
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

local function tick()
	local now = view()
	local shows = AdventLogic.shows(now)
	for _, board in CollectionService:GetTagged(AdventBoardController.BOARD_TAG) do
		local prompt = promptOf(board)
		if prompt ~= nil then
			prompt.Enabled = shows
			prompt.ActionText = if now ~= nil and now.ready then "Open a door" else "Look"
		end
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
