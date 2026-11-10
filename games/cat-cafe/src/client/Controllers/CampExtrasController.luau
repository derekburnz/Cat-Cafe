--!strict
-- The camp extras on this client (F100, camp-extras.md section 3; shared/CampExtras). The server's CampExtrasState is
-- kept in `CampExtrasController.state`, fired as Moments.CampExtrasState and handed to the UI's
-- `UI.campExtras.update(state)` once it has one (the cannon picker's lines come from CampExtras.pickerLine). Each
-- extra's prompt (CampExtras.PROMPT on the model's PromptAnchor, made by WorldBuilder) carries this player's lines
-- from CampExtras.promptText, refreshed every second. Pressing it sends CollectCampExtra; at the Yard Sale it opens
-- the UI's card, `UI.campExtras.openYardSale(view)`, whose buys come back as `UI.events.buyYardSale(crateId)`, and
-- until the UI has the card it buys the next crate on sale, the prompt naming it and its price and held for
-- YARD_SALE_HOLD seconds rather than WorldBuilder's 0.3, so a buy is never a tap (review N325). CampExtraResult ok
-- fires Moments.CampExtraCollect(extraId, anchor position) and shows what it paid with
-- `UI.campExtras.collected(extraId, paid, prize)`, else a toast; a refusal's toast comes from the server.
-- #2498 (Derek2: "auto claim when walking infront of it instead of needing a click"): standing in the floor ring in
-- front of an extra (#3113; within the prompt's reach where it has no ring) with something waiting (CampExtras.autoClaim) sends the same CollectCampExtra, or BuyYardSale for
-- the Yard Sale's free crate, as a press would, once until the server answers; the press still works. Nothing is
-- claimed during a catch, a rescue, a flight or the intro, or while the prompts are off. The server checks the range
-- and what waits, as for a press.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampExtras = require(Shared:WaitForChild("CampExtras"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)
local WalkUp = require(Shared:WaitForChild("WalkUp"))

local CampExtrasController = {}

CampExtrasController.state = nil :: Types.CampExtrasState?

local LABEL_SECONDS = 1
local YARD_SALE_HOLD = 1 -- seconds held to buy at the Yard Sale while it buys at once (no UI card yet)

local AUTO_SECONDS = 0.25 -- #2498: how often the walk-up claim looks
local AUTO_WAIT = 3 -- seconds a sent claim holds back the next one for that extra while no answer comes
local pending: { [string]: number } = {} -- #2498: os.clock() of each extra's claim still unanswered

local prompts: { [ProximityPrompt]: string } = {} -- each extra's prompt on this client and its extra id
local holds: { [ProximityPrompt]: number } = {} -- each prompt's HoldDuration as the server made it

-- The UI's camp extras hooks come with its picker lines and Yard Sale card; until then the module may not have them.
local function cardUI(): any
	return (UI :: any).campExtras
end

local function hook(name: string): ((...any) -> ())?
	local card = cardUI()
	local fn = if card ~= nil then card[name] else nil
	return if type(fn) == "function" then fn else nil
end

local function viewOf(extraId: string): Types.CampExtraView?
	local state = CampExtrasController.state
	return if state ~= nil then (state :: any)[extraId] :: Types.CampExtraView? else nil
end

local function crateName(crateId: string): string
	local crate = Catalog.getCrate(crateId)
	return if crate ~= nil then crate.name else crateId
end

-- This player's lines on one prompt.
local function label(prompt: ProximityPrompt, extraId: string)
	local view = viewOf(extraId)
	if view == nil then
		return
	end
	local object, action = CampExtras.promptText(extraId, view, Workspace:GetServerTimeNow())
	if extraId == CampExtras.YARD_SALE then
		local buysAtOnce = hook("openYardSale") == nil
		if view.open and buysAtOnce then
			local crate = CampExtras.nextYardCrate(view)
			if crate ~= nil then
				action = string.format("Buy %s, %d fish", crateName(crate.crateId), crate.price)
			end
		end
		local made = holds[prompt] or prompt.HoldDuration
		local hold = if buysAtOnce then math.max(made, YARD_SALE_HOLD) else made
		if prompt.HoldDuration ~= hold then
			prompt.HoldDuration = hold
		end
	end
	if prompt.ObjectText ~= object then
		prompt.ObjectText = object
	end
	if prompt.ActionText ~= action then
		prompt.ActionText = action
	end
end

local function labelAll()
	for prompt, extraId in prompts do
		label(prompt, extraId)
	end
end

-- Where an extra's prompt sits on this client, or nil while its model is streamed out.
local function anchorPosition(extraId: string): Vector3?
	for prompt, id in prompts do
		if id == extraId then
			local parent = prompt.Parent
			if parent ~= nil and parent:IsA("Attachment") then
				return (parent :: Attachment).WorldPosition
			elseif parent ~= nil and parent:IsA("BasePart") then
				return (parent :: BasePart).Position
			end
		end
	end
	return nil
end

local function onTriggered(extraId: string)
	if extraId ~= CampExtras.YARD_SALE then
		Net.fire("CollectCampExtra", extraId)
		return
	end
	local view = viewOf(extraId)
	if view == nil then
		return
	end
	local open = hook("openYardSale")
	if open ~= nil then
		open(view)
		return
	end
	local crate = if view.open then CampExtras.nextYardCrate(view) else nil
	if crate ~= nil then
		Net.fire("BuyYardSale", crate.crateId)
	else
		local _, action = CampExtras.promptText(extraId, view, Workspace:GetServerTimeNow())
		UI.toast(action, "info")
	end
end

-- #2498: whether the player is busy, as the walk-up windows see it (WalkUpController): nothing is taken then.
local function busy(): boolean
	local ui: any = UI
	local character = Players.LocalPlayer.Character
	return not ProximityPromptService.Enabled
		or (character ~= nil and (character:GetAttribute("Launching") == true or character:GetAttribute(
			"CloudHopAt"
		) ~= nil))
		or ui.catch.circlesActive()
		or ui.rescue.isActive()
		or ui.intro.playing()
end

-- #3113: the flat centre and radius of an extra's floor ring (World/WalkUpCircles), or nil while it has none or the
-- ring is streamed out.
local function ringOf(prompt: ProximityPrompt): (Vector3?, number)
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	while model ~= nil and not CollectionService:HasTag(model, CampExtras.TAG) do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	local link = if model ~= nil then model:FindFirstChild(WalkUp.CIRCLE) else nil
	local ring = if link ~= nil and link:IsA("ObjectValue")
		then (link :: ObjectValue).Value
		else nil
	if ring == nil or not ring:IsA("BasePart") then
		return nil, 0
	end
	local radius = ring:GetAttribute("Radius")
	return (ring :: BasePart).Position,
		if type(radius) == "number" then radius else (ring :: BasePart).Size.X / 2
end

-- #2498: takes what waits at each extra the player stands at: inside its floor ring (#3113), or within its prompt's
-- reach where it has no ring.
local function autoClaim()
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") or busy() then
		return
	end
	local at = (root :: BasePart).Position
	local now = os.clock()
	for prompt, extraId in prompts do
		local centre, radius = ringOf(prompt)
		local position = anchorPosition(extraId)
		local away = if centre ~= nil
			then Vector2.new(at.X - centre.X, at.Z - centre.Z).Magnitude > radius
			else position == nil or (position - at).Magnitude > prompt.MaxActivationDistance
		if away then
			if pending[extraId] == math.huge then
				pending[extraId] = nil -- walked away after a refusal: the next walk-up tries again
			end
			continue
		end
		local sent = pending[extraId]
		local view = viewOf(extraId)
		if (sent ~= nil and now - sent < AUTO_WAIT) or view == nil or not prompt.Enabled then
			continue
		end
		local how, crateId = CampExtras.autoClaim(extraId, view)
		if how == "collect" then
			pending[extraId] = now
			Net.fire("CollectCampExtra", extraId)
		elseif how == "yard" and crateId ~= nil then
			pending[extraId] = now
			Net.fire("BuyYardSale", crateId)
		end
	end
end

-- Picks up a placed camp extra's prompt (again after its model streams back in).
local function track(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return
	end
	local extraId = instance:GetAttribute("ExtraId")
	if type(extraId) ~= "string" then
		return
	end
	local prompt = instance:FindFirstChild(CampExtras.PROMPT, true)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		-- not here yet: take it when it arrives
		local waiting: RBXScriptConnection
		waiting = instance.DescendantAdded:Connect(function(child: Instance)
			if child.Name == CampExtras.PROMPT and child:IsA("ProximityPrompt") then
				waiting:Disconnect()
				track(instance)
			end
		end)
		return
	end
	local found = prompt :: ProximityPrompt
	if prompts[found] ~= nil then
		return
	end
	prompts[found] = extraId
	holds[found] = found.HoldDuration
	label(found, extraId)
	found.Triggered:Connect(function()
		onTriggered(extraId)
	end)
	found.AncestryChanged:Connect(function()
		if not found:IsDescendantOf(Workspace) then
			prompts[found] = nil
			holds[found] = nil
		end
	end)
end

function CampExtrasController.start()
	local uiEvents: any = UI.events
	if uiEvents.buyYardSale ~= nil then
		uiEvents.buyYardSale:Connect(function(crateId: string)
			Net.fire("BuyYardSale", crateId)
		end)
	end
	Net.on("CampExtrasState", function(state: Types.CampExtrasState)
		CampExtrasController.state = state
		table.clear(pending) -- #2498: the new view says what still waits
		Moments.CampExtrasState:Fire(state)
		local update = hook("update")
		if update ~= nil then
			update(state)
		end
		labelAll()
	end)
	Net.on(
		"CampExtraResult",
		function(extraId: string, ok: boolean, paid: { string }, prize: Types.IndexPrize?)
			if not ok then
				-- #2498: a refused walk-up claim is not sent again for this view (the state's next change frees it)
				pending[extraId] = math.huge
				local refused = hook("refused")
				if refused ~= nil then
					refused(extraId)
				end
				return
			end
			local position = anchorPosition(extraId)
			if position ~= nil then
				Moments.CampExtraCollect:Fire(extraId, position)
			end
			local collected = hook("collected")
			if collected ~= nil then
				collected(extraId, paid, prize)
				return
			end
			local def = Catalog.getCampExtra(extraId)
			local name = if def ~= nil then def.name else extraId
			UI.toast(string.format("%s: %s", name, table.concat(paid, ", ")), "good")
		end
	)

	for _, instance in CollectionService:GetTagged(CampExtras.TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(CampExtras.TAG):Connect(track)
	task.spawn(function()
		while true do
			task.wait(LABEL_SECONDS)
			labelAll()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTO_SECONDS)
			pcall(autoClaim) -- a UI that is rebuilding misses one look
		end
	end)
end

return CampExtrasController
