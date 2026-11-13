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
local PICK_RESULT_SECONDS = 5 -- #3615: a pick's CampExtraResult follows YardSalePicked at once; this is ample
local pickRolling: number? = nil -- os.clock() of a YardSalePicked whose CampExtraResult has not come yet
local pending: { [string]: number } = {} -- #2498: os.clock() of each extra's claim still unanswered
-- #3938: the extras whose square already acted this walk-up (claimed or opened a card), until the player walks off
local opened: { [string]: boolean } = {}

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
		local view = viewOf(extraId)
		if view ~= nil and view.treats ~= nil then
			-- #3715: Picnic Treats: the prompt opens the pick card, the player chooses there
			local openPicnic = hook("openPicnic")
			if openPicnic ~= nil then
				openPicnic()
			end
			return
		end
		-- #3955: the Lost and Found's card, where the player claims and sees what turned up
		local openLost = if extraId == "lostFound" then hook("openLostFound") else nil
		if openLost ~= nil then
			openLost()
			return
		end
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

-- #3114: the reach each extra's prompt came with
local ownReach: { [ProximityPrompt]: number } = {}

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
		-- #3114: an extra with a ring has no click prompt; stepping into the ring collects or opens its card. While
		-- the ring is away (streamed out) the prompt has the reach it came with again.
		local own = ownReach[prompt]
		if own == nil then
			own = prompt.MaxActivationDistance
			ownReach[prompt] = own
		end
		local reach = WalkUp.promptReach(centre ~= nil, own)
		if prompt.MaxActivationDistance ~= reach then
			prompt.MaxActivationDistance = reach
		end
		local position = anchorPosition(extraId)
		local away = if centre ~= nil
			then Vector2.new(at.X - centre.X, at.Z - centre.Z).Magnitude > radius
			else position == nil or (position - at).Magnitude > own
		if away then
			if pending[extraId] == math.huge then
				pending[extraId] = nil -- walked away after a refusal: the next walk-up tries again
			end
			if opened[extraId] then
				opened[extraId] = nil
				local closeInfo = hook("closeInfo") -- #3938: walking off the square closes its card
				if closeInfo ~= nil then
					closeInfo(extraId)
				end
			end
			continue
		end
		local sent = pending[extraId]
		local view = viewOf(extraId)
		if (sent ~= nil and now - sent < AUTO_WAIT) or view == nil or not prompt.Enabled then
			continue
		end
		-- #3938 (Derek: "the squares don't open menus if item not ready"): with nothing to claim the square opens
		-- the station's card, once a walk-up
		local how, crateId = CampExtras.walkUp(extraId, view)
		if how == "collect" then
			pending[extraId] = now
			opened[extraId] = true -- the card waits for the next walk-up, not the moment the claim lands
			Net.fire("CollectCampExtra", extraId)
		elseif how == "yard" and crateId ~= nil then
			pending[extraId] = now
			opened[extraId] = true
			Net.fire("BuyYardSale", crateId)
		elseif how == "info" and not opened[extraId] then
			-- the Yard Sale and Picnic Treats cards are WalkUpController's to open
			local openInfo = hook("openInfo")
			if openInfo ~= nil then
				opened[extraId] = true
				openInfo(extraId)
			end
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
			ownReach[found] = nil
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
	-- #3615: the Yard Sale's lucky pick, from its card; the answer rolls the card's board to the row
	-- #3715: Pick on the Picnic Treats card
	if uiEvents.pickPicnicTreat ~= nil then
		uiEvents.pickPicnicTreat:Connect(function(treatId: string)
			Net.fire("PickPicnicTreat", treatId)
		end)
	end
	if uiEvents.yardSalePick ~= nil then
		uiEvents.yardSalePick:Connect(function()
			Net.fire("YardSalePick")
		end)
	end
	-- The pick's CampExtraResult comes right behind it: its toast and the stall's moment wait for the board to land
	-- (Review-QA on #3669), so the roll is not given away. The card's landing fires yardSaleLanded.
	Net.on("YardSalePicked", function(index: number, crateId: string?)
		local picked = hook("picked")
		if picked ~= nil then
			pickRolling = os.clock()
			picked(index, crateId)
		end
	end)
	if uiEvents.yardSaleLanded ~= nil then
		uiEvents.yardSaleLanded:Connect(function()
			local position = anchorPosition(CampExtras.YARD_SALE)
			if position ~= nil then
				Moments.CampExtraCollect:Fire(CampExtras.YARD_SALE, position)
			end
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
			-- #3615: a lucky pick's result: the card's landing shows the prize and the moment
			if
				extraId == CampExtras.YARD_SALE
				and pickRolling ~= nil
				and os.clock() - pickRolling < PICK_RESULT_SECONDS
			then
				pickRolling = nil
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
