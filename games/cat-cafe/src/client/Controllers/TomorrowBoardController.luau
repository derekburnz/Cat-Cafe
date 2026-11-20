--!strict
-- #5449 (shared/TomorrowBoard): the Daily Treat Board on your own cafe's right wall and the wrapped Tomorrow Gift
-- under it, local to this client, behind the tomorrowBoard switch. Once a second it puts both on the plot's
-- TreatBoardAnchor and TomorrowGiftAnchor (they move with the room as it grows), shows a red paw stamp for each
-- claimed day and lights day 2's gold edge while day 2 is tomorrow. A tap on either (a ProximityPrompt, Roblox's
-- "press E / tap" button over a part) opens the board's card once a session: tomorrow's prize and, when Roblox
-- will prompt, Remind me, which opens Roblox's own notification opt-in. Nothing opens by itself.
-- Reports tomorrow_board (tap, remind, ok, closed; the server keeps each once a session).

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage.Shared.LiveFlags)
local Net = require(script.Parent.Parent.Net)
local QuietStart = require(ReplicatedStorage.Shared.QuietStart)
local TomorrowBoard = require(ReplicatedStorage.Shared.TomorrowBoard)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local TomorrowBoardController = {}

local TICK_SECONDS = 1
local PROMPT_DISTANCE = 10

local startedAt = os.clock()
local board: Model? = nil
local gift: Model? = nil
local opened = false -- the card opened this session
local busy = false -- the card is up

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets ~= nil then assets:FindFirstChild(name) else nil
	if source == nil or not source:IsA("Model") then
		return nil
	end
	local model = (source :: Model):Clone() :: Model
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			local part = child :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	return model
end

local function clear()
	if board ~= nil then
		board:Destroy()
		board = nil
	end
	if gift ~= nil then
		gift:Destroy()
		gift = nil
	end
end

local function anchorOf(plot: Model, name: string): BasePart?
	local found = plot:FindFirstChild(name)
	return if found ~= nil and found:IsA("BasePart") then found :: BasePart else nil
end

-- Whether Roblox will show its notification opt-in to this player now (13 and up, not answered recently).
local function canRemind(): boolean
	local ok, can = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	return ok and can == true
end

local function report(outcome: string)
	Net.fire("TelemetryReport", "tomorrow_board", outcome)
end

local function openCard()
	if opened or busy then
		return
	end
	local state = UIController.state
	local view = if state ~= nil then (state :: any).dailyTreat else nil
	local hook = if state ~= nil then (state :: any).tomorrowHook else nil
	local giftTomorrow = type(hook) == "table" and hook.kind == "gift"
	local remind = canRemind()
	busy = true
	local shown = UI.tomorrowBoard.open(
		TomorrowBoard.title(view, giftTomorrow),
		TomorrowBoard.line(view),
		remind,
		function(outcome: string)
			busy = false
			report(outcome)
			if outcome == "remind" then
				pcall(function()
					ExperienceNotificationService:PromptOptIn()
				end)
			end
		end
	)
	if shown then
		opened = true
		report("tap")
	else
		busy = false
	end
end

local function addPrompt(model: Model, text: string)
	local holder = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if holder == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text
	prompt.ObjectText = TomorrowBoard.PROMPT_TEXT
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Triggered:Connect(openCard)
	prompt.Parent = holder
end

-- Shows or hides every part of `group` on this client (the model keeps its own Transparency).
local function showAll(group: Instance, show: boolean)
	local parts: { Instance } = group:GetDescendants()
	table.insert(parts, group)
	for _, child in parts do
		if child:IsA("BasePart") then
			(child :: BasePart).LocalTransparencyModifier = if show then 0 else 1
		end
	end
end

-- Shows each claimed day's stamp and day 2's gold edge.
local function dress(model: Model, view: any)
	local stamps = TomorrowBoard.stamps(view)
	for day = 1, 7 do
		local stamp = model:FindFirstChild(TomorrowBoard.STAMP_PREFIX .. day)
		if stamp ~= nil then
			showAll(stamp, day <= stamps)
		end
	end
	local glow = model:FindFirstChild(TomorrowBoard.GLOW)
	if glow ~= nil then
		showAll(glow, TomorrowBoard.glows(view))
	end
end

local function tick()
	local on = LiveFlags.shown(
		TomorrowBoard.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. TomorrowBoard.FLAG)
	)
	local plot = UIController.ownPlot()
	local state = UIController.state
	local shows = plot ~= nil
		and state ~= nil
		and (state.tier or 0) >= 1
		and TomorrowBoard.shows(
			on,
			Players.LocalPlayer:GetAttribute(QuietStart.DAY_ATTRIBUTE),
			Workspace:GetServerTimeNow(),
			os.clock() - startedAt
		)
	if not shows or plot == nil then
		clear()
		return
	end
	local boardAnchor = anchorOf(plot, TomorrowBoard.BOARD_ANCHOR)
	local giftAnchor = anchorOf(plot, TomorrowBoard.GIFT_ANCHOR)
	if boardAnchor == nil then
		clear()
		return
	end
	if board == nil or board.Parent ~= plot then
		clear()
		board = asset(TomorrowBoard.BOARD_ASSET)
		if board == nil then
			return
		end
		addPrompt(board, "Look")
		board.Parent = plot
		if giftAnchor ~= nil then
			gift = asset(TomorrowBoard.GIFT_ASSET)
			if gift ~= nil then
				addPrompt(gift, "Look")
				gift.Parent = plot
			end
		end
	end
	local placed = board :: Model
	placed:PivotTo(boardAnchor.CFrame)
	dress(placed, (state :: any).dailyTreat)
	if gift ~= nil and giftAnchor ~= nil then
		-- its bottom on the floor where the anchor stands, whatever height the model's pivot is at
		local present = gift :: Model
		present:PivotTo(giftAnchor.CFrame)
		local box, size = present:GetBoundingBox()
		local lift = giftAnchor.Position.Y - (box.Position.Y - size.Y / 2)
		present:PivotTo(giftAnchor.CFrame + Vector3.new(0, lift, 0))
	end
end

function TomorrowBoardController.start()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local ok, problem = pcall(function()
				tick()
				return nil :: any
			end)
			if not ok then
				warn("[TomorrowBoard] " .. tostring(problem))
				task.wait(10)
			end
		end
	end)
end

return TomorrowBoardController
