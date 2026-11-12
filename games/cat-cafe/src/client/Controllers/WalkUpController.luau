--!strict
-- Walk-up windows on this client (#2398; shared/WalkUp for the rules). Walking up to the Cat Cannons, the Spin Wheel,
-- the Golden Fish Market, the Corner Shop or Day Cart, at night the night market's cart, in the camps the Yard Sale,
-- the Oasis Spa, the Relic Museum and each Index Board (#3113) and, for its owner, the cafe's
-- bait bowl on the back step (#2476) opens its window, and
-- walking away closes it, as the Codes Cat's circle does (CodesController). #3114: a station with a ring has no click
-- prompt any more (its prompt's reach is set to nothing here, WalkUp.promptReach), so a window closed by hand opens
-- again by stepping out of the ring and back in; one without a ring keeps its prompt. #2910: each open, by ring or by prompt, is counted (StationOpened). Nothing opens during a catch or a rescue, while carrying a cat or flying,
-- during the intro or while another window is open. Every window still checks its range on the server.
-- #3066: the feedback stand's ring opens the Feedback window straight on its text box, without the cursor in it (a
-- held W would type into it); the cursor goes in once a keyboard player has stood still there for a moment
-- (shared/FeedbackStand.focusNow). A press of the stand's prompt puts it in at once, on a phone too (UIController).
-- Each station's glowing floor ring (World/WalkUpCircles, WalkUp.CIRCLE) is where its window opens: stepping inside the
-- ring opens it. A station without a ring falls back to its prompt's reach (WalkUp.RADIUS_SHARE).
--
-- Roblox terms: each station is the server's model, tagged (CollectionService) and Persistent, with a
-- ProximityPrompt floating on an Attachment or a part; the prompt's MaxActivationDistance is how close its pill shows.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arcade = require(Shared:WaitForChild("Arcade"))
local CampExtras = require(Shared:WaitForChild("CampExtras"))
local FeedbackStand = require(Shared:WaitForChild("FeedbackStand"))
local LateStations = require(Shared:WaitForChild("LateStations"))
local Net = require(script.Parent.Parent.Net)
local StationOpens = require(Shared:WaitForChild("StationOpens"))
local Traits = require(Shared:WaitForChild("Traits"))
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)
local WalkUp = require(Shared:WaitForChild("WalkUp"))

local WalkUpController = {}

local player = Players.LocalPlayer
local POLL_SECONDS = 0.15

-- A kind of station: its tag, its prompt's name, the window (the UI's modal name) and how to open it for `model`.
-- `only`, when given, picks which of the tag's models are this kind (#3113: one tag holds several camp stations).
type Kind = {
	tag: string,
	prompt: string,
	window: string,
	open: (model: Instance) -> (),
	only: ((model: Instance) -> boolean)?,
	-- true where the ring opens the window even without a prompt to be found (an Index Board whose model brought a
	-- prompt under another name)
	loose: boolean?,
}

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
		tag = "MysteryMarket", -- #2574: Juniper's cart in the Town Square, opened from the ring in front of it
		prompt = "MysteryPrompt",
		window = "MysteryMarket",
		open = function()
			UI.mystery.open()
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
	{
		tag = Arcade.TAG, -- #3338 (Derek2: "add a circle to open the station infront of it"): the Cat Arcade
		prompt = Arcade.PROMPT,
		window = "Arcade",
		open = function()
			UI.arcade.open()
		end,
	},
	{
		tag = Traits.TAG, -- #3196: the Mystic Pool, in the Park camp while the `traits` switch is on
		prompt = Traits.PROMPT,
		window = "MysticPool",
		open = function()
			UI.mysticPool.open()
		end,
	},
	{
		tag = FeedbackStand.TAG, -- #3066: the Town Square's post box opens the Feedback window on its text box
		prompt = FeedbackStand.PROMPT,
		window = FeedbackStand.WINDOW,
		open = function()
			UI.bugReport.open(FeedbackStand.KIND, "none")
		end,
	},
	-- #3113 (Derek2: "circle pads to walk into for all area stations also ... auto open menu when getting close"):
	-- the camps' stations with a card. The Picnic Basket, Fish Pond and Lost and Found have no card: stepping into
	-- their rings collects (CampExtrasController).
	{
		tag = CampExtras.TAG,
		prompt = CampExtras.PROMPT,
		window = "YardSale",
		only = function(model: Instance)
			return model:GetAttribute("ExtraId") == CampExtras.YARD_SALE
		end,
		open = function()
			UI.campExtras.openYardSale(nil)
		end,
	},
	{
		tag = LateStations.TAG,
		prompt = LateStations.PROMPT,
		window = "OasisSpa",
		only = function(model: Instance)
			return model:GetAttribute("StationId") == LateStations.SPA
		end,
		open = function()
			UI.lateStations.open(LateStations.SPA)
		end,
	},
	{
		tag = LateStations.TAG,
		prompt = LateStations.PROMPT,
		window = "RelicMuseum",
		only = function(model: Instance)
			return model:GetAttribute("StationId") == LateStations.MUSEUM
		end,
		open = function()
			UI.lateStations.open(LateStations.MUSEUM)
		end,
	},
	{
		tag = "IndexBoard", -- each area's board opens the Index on that area's page (Screens/IndexBoards)
		prompt = "IndexPrompt",
		window = "Collection",
		loose = true,
		open = function(model: Instance)
			local area = model:GetAttribute("Area")
			if type(area) == "string" then
				UI.openIndex(area)
			end
		end,
	},
}

-- Strong tables, cleared when the station is destroyed: a weak-keyed table by Instance lost its entries while the
-- model still stood (Laptop-Tester on #2427), the station took a new key, and the walk-up read that as walking away
-- and shut the window after a second
local prompts: { [Instance]: ProximityPrompt? } = {}
local keys: { [Instance]: string } = {}
-- #3114: the reach each prompt came with, so it is given back if its station's ring goes away
local ownReach: { [ProximityPrompt]: number } = {}

-- Silences a ringed station's click prompt, or gives a ringless one its own reach back.
local function setReach(prompt: ProximityPrompt, hasRing: boolean)
	local own = ownReach[prompt]
	if own == nil then
		own = prompt.MaxActivationDistance
		ownReach[prompt] = own
		prompt.Destroying:Connect(function()
			ownReach[prompt] = nil
		end)
	end
	local reach = WalkUp.promptReach(hasRing, own :: number)
	if prompt.MaxActivationDistance ~= reach then
		prompt.MaxActivationDistance = reach
	end
end
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
		model.Destroying:Connect(function()
			keys[model] = nil
			prompts[model] = nil
		end)
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

-- The station's ring: its centre and radius, or nil when it has none. `has` is false without a ring at all (the
-- prompt's reach is used then), true with one, even while the ring itself is streamed out.
local function ringOf(model: Instance): (boolean, Vector3?, number)
	local link = model:FindFirstChild(WalkUp.CIRCLE)
	if link == nil or not link:IsA("ObjectValue") then
		return false, nil, 0
	end
	local ring = (link :: ObjectValue).Value
	if ring == nil or not ring:IsA("BasePart") then
		return true, nil, 0
	end
	local radius = ring:GetAttribute("Radius")
	return true,
		(ring :: BasePart).Position,
		if type(radius) == "number" then radius else (ring :: BasePart).Size.X / 2
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

-- Whether the character stands still (no walk asked for), for the feedback stand's cursor.
local function standing(): boolean
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and (humanoid :: Humanoid).MoveDirection.Magnitude < 0.05
end

-- Whether the player last used a keyboard or a mouse: only then does a box take the cursor by itself.
local function onKeyboard(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Keyboard
		or last == Enum.UserInputType.MouseMovement
		or last == Enum.UserInputType.MouseButton1
		or last == Enum.UserInputType.MouseButton2
		or last == Enum.UserInputType.MouseWheel
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
	-- #2910: a press of a walk-up station's prompt, counted against the ring opens (shared/StationOpens)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local window = StationOpens.windowOfPrompt(prompt.Name)
		if window ~= nil then
			Net.fire("StationOpened", window, "prompt")
		end
	end)
	local state = WalkUp.new()
	-- #3066: looks stood still in the feedback stand's ring since it opened the window, and whether the box has had
	-- the cursor from that
	local stillLooks, standFocused = 0, false
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
			local windowOf: { [string]: string } = {} -- #2910: each station's window, for the ring count
			local function add(
				model: Instance,
				prompt: ProximityPrompt?,
				window: string,
				open: () -> (),
				loose: boolean?
			)
				-- a prompt that is off (during a flight, say) still measures, so landing inside a ring is not
				-- read as stepping in once the prompt comes back; it only cannot open the window (WalkUp.step)
				local hasRing, centre, ringRadius = ringOf(model)
				-- #3114: the ring is the only way in, so the click prompt of a station that has one never shows
				if prompt ~= nil then
					setReach(prompt, hasRing)
				end
				local off = if prompt == nil
					then not (loose == true and hasRing)
					else not (prompt :: ProximityPrompt).Enabled
				local position = if hasRing
					then centre
					elseif prompt ~= nil then promptPosition(prompt :: ProximityPrompt)
					else nil
				local distance = if at ~= nil and position ~= nil
					then Vector2.new(at.X - position.X, at.Z - position.Z).Magnitude
					else nil
				local key = keyOf(model)
				opener[key] = open
				windowOf[key] = window
				table.insert(stations, {
					key = key,
					window = window,
					distance = distance,
					off = off,
					radius = if hasRing
						then ringRadius
						elseif prompt ~= nil then (ownReach[prompt :: ProximityPrompt] or (
							prompt :: ProximityPrompt
						).MaxActivationDistance) * WalkUp.RADIUS_SHARE
						else 0,
				})
			end
			for _, kind in KINDS do
				for _, model in CollectionService:GetTagged(kind.tag) do
					if not model:IsDescendantOf(Workspace) then
						continue -- the templates in ReplicatedStorage.Assets carry the tags too
					end
					if kind.only ~= nil and not kind.only(model) then
						continue
					end
					add(model, promptOf(model, kind.prompt), kind.window, function()
						kind.open(model)
					end, kind.loose)
				end
			end
			-- #2476 (Derek2: "make the bait bowl to open if you walk outside the backdoor near it"): the own first
			-- bowl, whose prompt this client makes (UIController), so only the owner's opens
			local bowl = UIController.ownBowlModel()
			if bowl ~= nil then
				add(bowl, UIController.bowlPrompt(), "Bait", function()
					UIController.openBowl(1)
				end)
			end
			local ok, open, close = pcall(function()
				local current = UI.isOpen()
				local key, shut = WalkUp.step(state, stations, blocked(), current)
				return key, shut
			end)
			if not ok then
				continue -- a UI that is rebuilding misses one look
			end
			-- #3338: walking out of the arcade's ring mid game leaves the game running; it closes when it ends
			if close and not (UI.isOpen() == "Arcade" and UI.arcade.playing()) then
				UI.close()
			end
			local run = if open ~= nil then opener[open :: string] else nil
			if run ~= nil then
				run()
				local window = windowOf[open :: string]
				if window ~= nil then
					Net.fire("StationOpened", window, "ring") -- #2910
				end
				stillLooks, standFocused = 0, false
			end
			-- #3066: the stand's window, opened by its ring and still up: the cursor goes in once the player stands
			if
				state.openedWindow == FeedbackStand.WINDOW
				and UI.isOpen() == FeedbackStand.WINDOW
			then
				stillLooks = if standing() then stillLooks + 1 else 0
				if FeedbackStand.focusNow(stillLooks, standFocused, onKeyboard()) then
					standFocused = true
					UI.bugReport.focus()
				end
			end
		end
	end)
end

return WalkUpController
