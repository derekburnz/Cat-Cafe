--!strict
-- Pet a cat on this client (#3651, shared/Pet; switch `petCats`). While the switch is on and the tutorial is done,
-- each of the player's own working cats carries a "Pet" prompt (Pet.PROMPT, the UI's action pill). Pressing it asks
-- the server (PetCat), which decides; the heart on the cat's money tag follows the model's HappyUntil attribute
-- (UI/Screens/WorldTags) and the prompt's note reads "Happy for 42 m" while it runs. The server's CatPetted is
-- handed on as Moments.CatPetted for the reach, the hearts and the purr (Effects/PetCat), on every client.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Pet = require(Shared:WaitForChild("Pet"))

local PetController = {}

local CAT_TAG = "WorkingCat"
local TUTORIAL_DONE = 5 -- the tutorial's last step
local REACH_UNDER = 2 -- studs the prompt's reach stays inside the server's range
local NOTE_SECONDS = 20 -- how often a happy cat's note is brought up to date

local prompts: { [Instance]: ProximityPrompt } = {}
local lastPress = 0

local function on(): boolean
	return LiveFlags.shown(
		Pet.FLAG,
		ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. Pet.FLAG)
	)
end

local function inTutorial(): boolean
	local controller: any = require(script.Parent.UIController)
	local state: any = controller.state
	return state == nil
		or type(state.tutorialStep) ~= "number"
		or state.tutorialStep < TUTORIAL_DONE
end

local function mine(cat: Instance): boolean
	return cat:IsA("Model")
		and cat:IsDescendantOf(Workspace)
		and cat:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
end

local function note(cat: Instance, prompt: ProximityPrompt)
	local name = cat:GetAttribute("DisplayName")
	prompt.ObjectText = if type(name) == "string" then name else ""
	prompt:SetAttribute(
		"Note",
		Pet.label(cat:GetAttribute(Pet.ATTRIBUTE), Workspace:GetServerTimeNow())
	)
end

local function drop(cat: Instance)
	local prompt: ProximityPrompt? = prompts[cat]
	if prompt ~= nil then
		prompts[cat] = nil
		prompt:Destroy()
	end
end

local function press(cat: Instance)
	local uid = cat:GetAttribute("Uid")
	local now = os.clock()
	if type(uid) ~= "string" or now - lastPress < Config.PetCooldownSeconds then
		return
	end
	lastPress = now
	Net.fire("PetCat", uid)
end

-- Gives `cat` its prompt, or takes it away, as the switch, the tutorial and the cat stand now.
local function refresh(cat: Instance)
	if not (mine(cat) and CollectionService:HasTag(cat, CAT_TAG) and on() and not inTutorial()) then
		drop(cat)
		return
	end
	local model = cat :: Model
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local prompt: ProximityPrompt? = prompts[cat]
	if part == nil then
		drop(cat)
		return
	end
	if prompt == nil or prompt.Parent ~= part then
		drop(cat)
		local made = Instance.new("ProximityPrompt")
		made.Name = Pet.PROMPT
		made.Style = Enum.ProximityPromptStyle.Custom
		made.ActionText = Pet.ACTION
		made.HoldDuration = 0
		made.RequiresLineOfSight = false
		made.MaxActivationDistance = Config.PetRangeStuds - REACH_UNDER
		made.Triggered:Connect(function()
			press(cat)
		end)
		made.Parent = part
		prompts[cat] = made
		prompt = made
	end
	note(cat, prompt :: ProximityPrompt)
end

local function refreshAll()
	for cat in prompts do
		refresh(cat)
	end
	for _, cat in CollectionService:GetTagged(CAT_TAG) do
		refresh(cat)
	end
end

function PetController.start()
	Net.on("CatPetted", function(userId: unknown, cat: unknown, from: unknown)
		-- a cat that is not streamed in here arrives nil: nothing to show
		if
			type(userId) ~= "number"
			or typeof(cat) ~= "Instance"
			or not (cat :: Instance):IsA("Model")
		then
			return
		end
		local left = if typeof(from) == "Instance" and (from :: Instance):IsA("Model")
			then from :: Model
			else nil
		Moments.CatPetted:Fire(userId, cat :: Model, left)
	end)
	CollectionService:GetInstanceAddedSignal(CAT_TAG):Connect(function(cat: Instance)
		task.defer(refresh, cat) -- its attributes and parts are in a moment after the tag
		cat:GetAttributeChangedSignal(Pet.ATTRIBUTE):Connect(function()
			refresh(cat)
		end)
	end)
	CollectionService:GetInstanceRemovedSignal(CAT_TAG):Connect(drop)
	for _, cat in CollectionService:GetTagged(CAT_TAG) do
		cat:GetAttributeChangedSignal(Pet.ATTRIBUTE):Connect(function()
			refresh(cat)
		end)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. Pet.FLAG)
		:Connect(refreshAll)
	-- the tutorial ending and the notes' minutes: a slow pass is enough
	task.spawn(function()
		while true do
			refreshAll()
			task.wait(NOTE_SECONDS)
		end
	end)
end

return PetController
