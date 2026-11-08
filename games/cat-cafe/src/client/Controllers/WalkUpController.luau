--!strict
-- Walk-up windows on this client (#2398; shared/WalkUp for the rules). Walking up to the Cat Cannons, the Spin Wheel,
-- the Golden Fish Market, the Corner Shop or Day Cart and, at night, the night market's cart opens its window, and
-- walking away closes it, as the Codes Cat's circle does (CodesController). The stations' prompts stay, so a window
-- closed by hand opens again with a press. Nothing opens during a catch or a rescue, while carrying a cat or flying,
-- during the intro or while another window is open. Every window still checks its range on the server.
--
-- Roblox terms: each station is the server's model, tagged (CollectionService) and Persistent, with a
-- ProximityPrompt floating on an Attachment or a part; the prompt's MaxActivationDistance is how close its pill shows.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WalkUp = require(Shared:WaitForChild("WalkUp"))

local WalkUpController = {}

local player = Players.LocalPlayer
local POLL_SECONDS = 0.15

-- A kind of station: its tag, its prompt's name, the window (the UI's modal name) and how to open it for `model`.
type Kind = { tag: string, prompt: string, window: string, open: (model: Instance) -> () }

local KINDS: { Kind } = {
	{
		tag = "CatCannon",
		prompt = "CannonPrompt",
		window = "Cannon",
		open = function(model: Instance)
			local id = model:GetAttribute("CannonId")
			UI.cannon.open(if type(id) == "string" then id else nil)
		end,
	},
	{
		tag = "SpinWheel",
		prompt = "SpinPrompt",
		window = "Spin",
		open = function()
			UI.spin.open()
		end,
	},
	{
		tag = "FishMarket",
		prompt = "MarketPrompt",
		window = "Market",
		open = function()
			UI.market.open()
		end,
	},
	{
		tag = "CornerShop", -- the Corner Shop, or the Day Cart in the town square (#2398)
		prompt = "CornerShopPrompt",
		window = "CornerShop",
		open = function()
			UI.cornerShop.open()
		end,
	},
	{
		tag = "DealerCart", -- the night market: the cart is out only at night, so it opens only then
		prompt = "DealerPrompt",
		window = "Dealer",
		open = function()
			UI.dealer.open()
		end,
	},
}

local prompts: { [Instance]: ProximityPrompt? } = setmetatable({}, { __mode = "k" }) :: any
local keys: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local lastKey = 0

-- The station's prompt, found once and again if it streamed out.
local function promptOf(model: Instance, name: string): ProximityPrompt?
	local found: ProximityPrompt? = prompts[model]
	if found and found:IsDescendantOf(model) then
		return found
	end
	local look = model:FindFirstChild(name, true)
	if look ~= nil and look:IsA("ProximityPrompt") then
		prompts[model] = look :: ProximityPrompt
		return look :: ProximityPrompt
	end
	return nil
end

local function keyOf(model: Instance): string
	local key = keys[model]
	if key == nil then
		lastKey += 1
		key = tostring(lastKey)
		keys[model] = key
	end
	return key :: string
end

-- Where the prompt floats: its Attachment's or its part's position.
local function promptPosition(prompt: ProximityPrompt): Vector3?
	local holder = prompt.Parent
	if holder ~= nil and holder:IsA("Attachment") then
		return (holder :: Attachment).WorldPosition
	elseif holder ~= nil and holder:IsA("BasePart") then
		return (holder :: BasePart).Position
	end
	return nil
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root ~= nil and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

local function flying(): boolean
	local character = player.Character
	return character ~= nil
		and (
			character:GetAttribute("Launching") == true
			or character:GetAttribute("CloudHopAt") ~= nil
		)
end

-- Whether the player is busy: nothing pops up over a catch, a rescue, a carry, a flight or the intro.
local function blocked(): boolean
	local ui: any = UI
	local state = UIController.state
	return not ProximityPromptService.Enabled
		or (state ~= nil and state.carrying ~= nil)
		or flying()
		or ui.catch.circlesActive()
		or ui.rescue.isActive()
		or ui.intro.playing()
end

function WalkUpController.start()
	local state = WalkUp.new()
	-- a new character (a respawn) is looked at afresh, so spawning next to a station opens nothing
	player.CharacterAdded:Connect(function()
		table.clear(state.inside)
	end)
	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			local at = rootPosition()
			local stations: { WalkUp.Station } = {}
			local opener: { [string]: () -> () } = {}
			for _, kind in KINDS do
				for _, model in CollectionService:GetTagged(kind.tag) do
					if not model:IsDescendantOf(Workspace) then
						continue -- the templates in ReplicatedStorage.Assets carry the tags too
					end
					local prompt = promptOf(model, kind.prompt)
					local position = if prompt ~= nil and prompt.Enabled
						then promptPosition(prompt :: ProximityPrompt)
						else nil
					local distance = if at ~= nil and position ~= nil
						then Vector2.new(at.X - position.X, at.Z - position.Z).Magnitude
						else nil
					local key = keyOf(model)
					opener[key] = function()
						kind.open(model)
					end
					table.insert(stations, {
						key = key,
						window = kind.window,
						distance = distance,
						radius = if prompt ~= nil
							then (prompt :: ProximityPrompt).MaxActivationDistance * WalkUp.RADIUS_SHARE
							else 0,
					})
				end
			end
			local ok, open, close = pcall(function()
				local current = UI.isOpen()
				local key, shut = WalkUp.step(state, stations, blocked(), current)
				return key, shut
			end)
			if not ok then
				continue -- a UI that is rebuilding misses one look
			end
			if close then
				UI.close()
			end
			local run = if open ~= nil then opener[open :: string] else nil
			if run ~= nil then
				run()
			end
		end
	end)
end

return WalkUpController
