--!strict
-- The free Bellhop Cat's stand on this client (F96, starter-cat.md section 2; shared/StarterCat). Walking within
-- StarterCatRangeStuds (flat) of a BellhopStand under Workspace opens its card and walking a stud past it closes the
-- card, with no key press: `UI.starterCat.open(view)` and `close()`, the view refreshed with each ProfileSync while
-- open. The card's "Take me home" (`UI.events.claimStarterCat`) sends ClaimStarterCat, its "Join the group"
-- (`UI.events.joinGroup`) opens Roblox's join prompt (GroupService:PromptJoinAsync) once the game has a group, and
-- StarterCatResult(ok, reason) goes to `UI.starterCat.result`. The server checks range, the claim and the gate
-- again. Until the UI has the card, a plain "Take me home" prompt on the stand's PromptAnchor does the claim and a
-- refusal shows as a toast.

local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatStats = require(Shared:WaitForChild("CatStats"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(script.Parent.Parent.Net)
local StarterCat = require(Shared:WaitForChild("StarterCat"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local StarterCatController = {}

local player = Players.LocalPlayer
local POLL_SECONDS = 0.2

-- What the stand's card shows.
export type View = {
	claimed: boolean, -- "Already home with you"
	gate: StarterCat.Gate, -- "task": the first goals; "group": the group, with a Join button
	line: string?, -- why it cannot be claimed yet when the client can tell (the first goals), else nil
	rate: number, -- what it earns a second at the player's tier, before its role
}

-- The card comes with the UI's stand card; until then the module may not have it, so it is reached loosely.
local function cardUI(): any
	return (UI :: any).starterCat
end

local function view(): View
	local state: any = UIController.state
	local tier = if state ~= nil then state.tier else 1
	local claimed = state ~= nil and state.starterCatClaimed == true
	local gate: StarterCat.Gate = StarterCat.gate(Config.GroupId)
	local line: string? = nil
	if claimed then
		line = StarterCat.CLAIMED
	elseif
		gate == "task" and (state == nil or state.tutorialStep < Config.StarterCatTutorialStep)
	then
		line = StarterCat.NEEDS_GOALS
	end
	local preview = CatStats.newInstance("preview", StarterCat.CAT_ID, 0, Config.StarterCatCharm)
	return { claimed = claimed, gate = gate, line = line, rate = CatStats.rating(preview, tier) }
end

-- The flat distance to the nearest stand in the Workspace (the template in ReplicatedStorage.Assets carries the tag
-- too) and that stand, or nil without a character or a stand.
local function nearestStand(): (number?, Model?)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	local position = (root :: BasePart).Position
	local best: number?, stand: Model? = nil, nil
	for _, instance in CollectionService:GetTagged(StarterCat.TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local pivot = (instance :: Model):GetPivot().Position
			local distance = Vector2.new(position.X - pivot.X, position.Z - pivot.Z).Magnitude
			if best == nil or distance < best then
				best, stand = distance, instance :: Model
			end
		end
	end
	return best, stand
end

-- Until the UI has the card: a local "Take me home" prompt on each stand.
local function addFallbackPrompt(stand: Instance)
	if not stand:IsA("Model") or not stand:IsDescendantOf(Workspace) or cardUI() ~= nil then
		return
	end
	local model = stand :: Model
	local anchor = model:FindFirstChild("PromptAnchor", true)
	local parent: Instance? = if anchor ~= nil and anchor:IsA("Attachment")
		then anchor
		else model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if parent == nil or parent:FindFirstChild("StarterCatPrompt") ~= nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StarterCatPrompt"
	prompt.ActionText = "Take me home"
	prompt.ObjectText = "Bellhop Cat (free)"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = Config.StarterCatRangeStuds - 3
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		Net.fire("ClaimStarterCat")
	end)
	prompt.Parent = parent
end

function StarterCatController.start()
	local uiEvents: any = UI.events
	if uiEvents.claimStarterCat ~= nil then
		uiEvents.claimStarterCat:Connect(function()
			Net.fire("ClaimStarterCat")
		end)
	end
	if uiEvents.joinGroup ~= nil then
		uiEvents.joinGroup:Connect(function()
			if Config.GroupId == 0 then
				return
			end
			task.spawn(function()
				-- Closing the prompt or joining needs no line; a failed prompt (most often the account's group list
				-- is full) gets a kind one on the card, never a paid step (#999).
				local ok = pcall(function()
					GroupService:PromptJoinAsync(Config.GroupId)
				end)
				if ok then
					return
				end
				local card = cardUI()
				if card ~= nil and type(card.result) == "function" then
					(card.result :: any)(false, StarterCat.GROUP_FULL)
				else
					UI.toast(StarterCat.GROUP_FULL, "info")
				end
			end)
		end)
	end
	Net.on("StarterCatResult", function(ok: boolean, reason: string?)
		local card = cardUI()
		if card ~= nil and type(card.result) == "function" then
			(card.result :: any)(ok, reason)
		elseif not ok and type(reason) == "string" then
			UI.toast(reason, "warn")
		end
	end)

	for _, stand in CollectionService:GetTagged(StarterCat.TAG) do
		addFallbackPrompt(stand)
	end
	CollectionService:GetInstanceAddedSignal(StarterCat.TAG):Connect(addFallbackPrompt)

	task.spawn(function()
		local open = false
		while true do
			local distance = nearestStand()
			local range = Config.StarterCatRangeStuds
			local want = distance ~= nil and distance <= (if open then range + 1 else range)
			local card = cardUI()
			if card ~= nil then
				if want ~= open then
					open = want
					if open then
						card.open(view())
					else
						card.close()
					end
				elseif open and type(card.update) == "function" then
					(card.update :: any)(view())
				end
			end
			task.wait(POLL_SECONDS)
		end
	end)
end

return StarterCatController
