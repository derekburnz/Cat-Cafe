--!strict
-- #5594 (Derek 2026-11-20: "in the new version when loading into the game nothing pointing at catching the first cat
-- just put an arrow facing down above the nearest cats head until caught"), switch firstCatArrow: until the save's
-- first catch, a big gold arrow pointing down bobs over the head of the nearest stray that can be caught now (not
-- running, not in someone else's catch), within REACH studs. It moves to whichever stray is nearest, hides while the
-- player holds a cat or a window is open, and goes for good once the server counts the first catch (the goal card's
-- startGoals.caught, else stats.catsCaught). With Reduce Motion on it holds still. Client only: it sends nothing.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local FirstCatArrowController = {}

FirstCatArrowController.FLAG = "firstCatArrow"
local REACH = 150 -- studs, as the stall glow's (StartStallController)
local POLL = 0.25
local ABOVE = 2.6 -- studs over the top of the cat, clear of its name tag (Effects/CatNames)
local BOB = 0.45 -- studs up and down
local GOLD = Color3.fromRGB(255, 200, 40)
local OUTLINE = Color3.fromRGB(60, 35, 10)

local started = false

-- Whether the save still waits for its first catch, from the state the server sent (nil: not known yet).
function FirstCatArrowController.waiting(state: any): boolean
	if type(state) ~= "table" then
		return false
	end
	local goals = state.startGoals
	if type(goals) == "table" then
		return goals.caught ~= true
	end
	local stats = state.stats
	local caught = if type(stats) == "table" then stats.catsCaught else nil
	return type(caught) == "number" and caught <= 0
end

local function nearestStray(): Model?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local now = Workspace:GetServerTimeNow()
	local best: Model?, bestDistance = nil, REACH
	for _, instance in CollectionService:GetTagged("Stray") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local fleeing = instance:GetAttribute("FleeingUntil")
		local locked = instance:GetAttribute("LockedBy")
		if
			(type(fleeing) == "number" and fleeing > now)
			or (type(locked) == "number" and locked ~= 0 and locked ~= Players.LocalPlayer.UserId)
		then
			continue
		end
		local model = instance :: Model
		local distance = (model:GetPivot().Position - (root :: BasePart).Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = model, distance
		end
	end
	return best
end

local function build(): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FirstCatArrow"
	gui.Size = UDim2.fromOffset(64, 64)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.MaxDistance = REACH + 20
	gui.Enabled = false
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = GOLD
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.Parent = arrow
	arrow.Parent = gui
	return gui, arrow
end

-- How far over `model`'s pivot the arrow sits: the top of its box plus ABOVE.
local function heightOver(model: Model): number
	local box, size = model:GetBoundingBox()
	return box.Position.Y + size.Y / 2 - model:GetPivot().Position.Y + ABOVE
end

function FirstCatArrowController.start()
	if started then
		return
	end
	started = true
	local gui = build()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local target: Model? = nil
	local part: BasePart? = nil
	local over = ABOVE
	local done = false
	RunService.RenderStepped:Connect(function()
		if not gui.Enabled or target == nil then
			return
		end
		local bob = if GuiService.ReducedMotionEnabled then 0 else math.sin(os.clock() * 5) * BOB
		gui.StudsOffsetWorldSpace = Vector3.new(0, over + bob, 0)
	end)
	task.spawn(function()
		while not done do
			task.wait(POLL)
			local on = ReplicatedStorage:GetAttribute("LiveFlag_" .. FirstCatArrowController.FLAG)
				== true
			local state: any = UIController.state
			if on and state ~= nil and not FirstCatArrowController.waiting(state) then
				done = true -- the first catch is in: the arrow goes for good
				break
			end
			local character = Players.LocalPlayer.Character
			local busy = character == nil
				or character:GetAttribute("CarryingCatId") ~= nil
				or (UI :: any).isOpen() ~= nil
			local pick = if on and state ~= nil and not busy then nearestStray() else nil
			if pick ~= target then
				target = pick
				local found: Instance? = if pick ~= nil
					then pick:FindFirstChildWhichIsA("BasePart")
					else nil
				part = if pick ~= nil and pick.PrimaryPart ~= nil
					then pick.PrimaryPart
					elseif found ~= nil and found:IsA("BasePart") then found :: BasePart
					else nil
				gui.Adornee = part :: any
			end
			local model, at = target, part
			if model ~= nil and at ~= nil and at.Parent ~= nil then
				-- measured from the Adornee part, not the model's pivot
				over = heightOver(model) + model:GetPivot().Position.Y - at.Position.Y
				gui.Enabled = true
			else
				gui.Enabled = false
			end
		end
		gui:Destroy()
	end)
end

return FirstCatArrowController
