--!strict
-- The late stations on this client (#2651 part 4, late-stations.md sections 1 and 2; shared/LateStations): the Oasis
-- Spa (Desert camp) and the Relic Museum (Ruins camp). Each station's prompt (LateStations.PROMPT on the model's
-- PromptAnchor, made by WorldBuilder once Config.LateStationsOpen) opens the UI's card, `UI.lateStations.open(id)`.
-- The server's LateStationsState goes to `UI.lateStations.update(state)` (the cards, the Cat Cannon picker's strips
-- and the stations' bubbles) and LateStationResult to `UI.lateStations.result(stationId, ok, detail)`. The cards'
-- presses come back as `UI.events.lateStation(remote, ...)` and go out as that remote; only the five station remotes
-- are forwarded. The server checks the tier, the range and every rule again (LateStationService).
--
-- Roblox terms: a ProximityPrompt's Triggered fires on the client of the player who pressed it as well as on the
-- server, so the card opens here with no round trip; the server never trusts that press, only the remotes after it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LateStations = require(Shared:WaitForChild("LateStations"))
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)

local LateStationsController = {}

LateStationsController.state = nil :: Types.LateStationsState?

-- The remotes a card may ask for (Remotes.luau), so a press can't name any other.
local REMOTES: { [string]: boolean } = {
	SpaPut = true,
	SpaTakeOut = true,
	SpaCollect = true,
	SpaBuySlot = true,
	MuseumDonate = true,
	MuseumFill = true, -- #3130
	BuyTicketPrize = true, -- #4061: the Ticket Booth's BUY (prize id)
}

local tracked: { [ProximityPrompt]: boolean } = {}

-- The UI's hook `name` (UI.lateStations.open, update or result), or nil while a rebuilt UI has none.
local function hook(name: string): ((...any) -> ())?
	local hooks = (UI :: any).lateStations
	local fn = if type(hooks) == "table" then hooks[name] else nil
	return if type(fn) == "function" then fn else nil
end

-- Picks up a placed station's prompt (again after its model streams back in).
local function track(instance: Instance)
	if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
		return
	end
	local stationId = instance:GetAttribute("StationId")
	if type(stationId) ~= "string" then
		return
	end
	local prompt = instance:FindFirstChild(LateStations.PROMPT, true)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		local waiting: RBXScriptConnection
		waiting = instance.DescendantAdded:Connect(function(child: Instance)
			if child.Name == LateStations.PROMPT and child:IsA("ProximityPrompt") then
				waiting:Disconnect()
				track(instance)
			end
		end)
		return
	end
	local found = prompt :: ProximityPrompt
	if tracked[found] then
		return
	end
	tracked[found] = true
	found.Triggered:Connect(function()
		local open = hook("open")
		if open ~= nil then
			open(stationId)
		end
	end)
	found.AncestryChanged:Connect(function()
		if not found:IsDescendantOf(Workspace) then
			tracked[found] = nil
		end
	end)
end

function LateStationsController.start()
	local uiEvents: any = UI.events
	if uiEvents.lateStation ~= nil then
		uiEvents.lateStation:Connect(function(remote: string, ...: any)
			if REMOTES[remote] then
				Net.fire(remote, ...)
			end
		end)
	end
	Net.on("LateStationsState", function(state: Types.LateStationsState)
		LateStationsController.state = state
		local update = hook("update")
		if update ~= nil then
			update(state)
		end
	end)
	Net.on("LateStationResult", function(stationId: string, ok: boolean, detail: any)
		local result = hook("result")
		if result ~= nil then
			result(stationId, ok, detail)
		end
	end)
	for _, instance in CollectionService:GetTagged(LateStations.TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(LateStations.TAG):Connect(track)
end

return LateStationsController
