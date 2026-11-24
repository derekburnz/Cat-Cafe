--!strict
-- #5715 (shared/Tier3Pointer, switch tier3Pointer): at Tier 2 in the Park, once Tier3Path's kinds and Rares are met
-- and while coins are under Tier 3's cost, it picks the one thing that gets coins next: the Picnic Basket while a
-- party waits, else the nearest free Park stray within CAT_STUDS. Checked every POLL seconds; nothing once Tier 3 is
-- funded. It picks only; the drawing is Motion-FX's Effects/Tier3PointerFx (#5716), handed each new target:
--   Tier3PointerFx.point(kind, target)   kind "picnic" (target the Picnic Basket station model) or "cat" (the stray
--                                        model), or nil to hide; looked up when called, so either PR may land first
-- Hook for the goal card (Design), read only:
--   UI.tier3Pointer.caption   "Picnic Party: 2x coins", "Catch cats: more coins", or nil
--   UI.tier3Pointer.kind      "picnic" | "cat" | nil
--   UI.tier3Pointer.changed   a BindableEvent fired after either changes
-- Each new target is reported (TelemetryReport tier3_pointer, logged as tier3_path coins_picnic or coins_cat, at
-- most LOG_MAX a session). Client only: it decides nothing the server trusts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local PicnicParty = require(Shared:WaitForChild("PicnicParty"))
local Tier3Path = require(Shared:WaitForChild("Tier3Path"))
local Tier3Pointer = require(Shared:WaitForChild("Tier3Pointer"))

local Net = require(script.Parent.Parent.Net)
local TutorialArrow = require(script.Parent.Parent.UI.Components.TutorialArrow)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local Tier3PointerController = {}

local STATION_TAG = "CampExtra"
local PICNIC_EXTRA = "picnic"
local FX_MODULE = "Tier3PointerFx"

local started = false

type Hook = {
	caption: string?,
	kind: Tier3Pointer.Target?,
	changed: BindableEvent,
}

local function flag(name: string): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. name) == true
end

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

local function basket(): Model?
	for _, instance in CollectionService:GetTagged(STATION_TAG) do
		if
			instance:IsA("Model")
			and instance:GetAttribute("ExtraId") == PICNIC_EXTRA
			and instance:IsDescendantOf(Workspace)
		then
			return instance :: Model
		end
	end
	return nil
end

-- The nearest free Park stray within CAT_STUDS: not running, not in someone else's catch, not someone's picnic cat.
local function nearestParkCat(root: BasePart): Model?
	local me = Players.LocalPlayer.UserId
	local now = Workspace:GetServerTimeNow()
	local best: Model?, bestDistance = nil, Tier3Pointer.CAT_STUDS
	for _, instance in CollectionService:GetTagged("Stray") do
		if not instance:IsA("Model") or not instance:IsDescendantOf(Workspace) then
			continue
		end
		local area = instance:GetAttribute("Area")
		local fleeing = instance:GetAttribute("FleeingUntil")
		local locked = instance:GetAttribute("LockedBy")
		local picnic = instance:GetAttribute("PicnicFor")
		if
			area ~= Tier3Pointer.AREA
			or (type(fleeing) == "number" and fleeing > now)
			or (type(locked) == "number" and locked ~= 0 and locked ~= me)
			or (type(picnic) == "number" and picnic ~= me)
		then
			continue
		end
		local model = instance :: Model
		local distance = (model:GetPivot().Position - root.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = model, distance
		end
	end
	return best
end

local function tier3Cost(): number?
	local def = Catalog.getTier(Tier3Path.TIER + 1)
	return if def ~= nil then def.cost else nil
end

-- What the pure rules need, from the server's state, the player's attributes and the world; and the near cat.
local function look(): (Tier3Pointer.Look, Model?)
	local state: any = UIController.state
	local me = Players.LocalPlayer
	local character = me.Character
	local root = rootPart()
	local endsAt = me:GetAttribute(PicnicParty.ENDS_AT)
	local cat = if root ~= nil then nearestParkCat(root) else nil
	local known = type(state) == "table"
	local value: Tier3Pointer.Look = {
		tier = if known and type(state.tier) == "number" then state.tier else 0,
		coins = if known and type(state.coins) == "number" then state.coins else 0,
		cost = tier3Cost(),
		-- Tier3Path on and no goal line left: its kinds and Rares are met (its own stray leads until then)
		pathMet = known and flag(Tier3Path.FLAG) and type(state.tier3Goal) ~= "table",
		area = (UI :: any).cannon.area,
		busy = character == nil
			or root == nil
			or character:GetAttribute("CarryingCatId") ~= nil
			or UI.isOpen() ~= nil
			or (UI :: any).intro.playing()
			or TutorialArrow.current() ~= nil,
		picnicReady = flag(PicnicParty.FLAG) and me:GetAttribute(PicnicParty.READY) == true,
		picnicRunning = type(endsAt) == "number" and endsAt > Workspace:GetServerTimeNow(),
		catNear = cat ~= nil,
	}
	return value, cat
end

-- Motion-FX's drawing, when its module is there (#5716).
local function draw(kind: Tier3Pointer.Target?, target: Model?)
	local folder = script.Parent
	local client: Instance? = if folder ~= nil then folder.Parent else nil
	local effects = if client ~= nil then client:FindFirstChild("Effects") else nil
	local fx = if effects ~= nil then effects:FindFirstChild(FX_MODULE) else nil
	if fx == nil or not fx:IsA("ModuleScript") then
		return
	end
	local module = fx :: ModuleScript
	local ok, problem = pcall(function()
		(require(module) :: any).point(kind, target)
	end)
	if not ok then
		warn("[Tier3Pointer] " .. tostring(problem))
	end
end

function Tier3PointerController.start()
	if started then
		return
	end
	started = true
	local hook: Hook = { caption = nil, kind = nil, changed = Instance.new("BindableEvent") }
	(UI :: any).tier3Pointer = hook
	local shown: Model? = nil
	local logged = 0
	task.spawn(function()
		while true do
			local kind: Tier3Pointer.Target? = nil
			local pick: Model? = nil
			if flag(Tier3Pointer.FLAG) then
				local now, cat = look()
				kind = Tier3Pointer.target(now)
				if kind == "picnic" then
					pick = basket()
				elseif kind == "cat" then
					pick = cat
				end
				if pick == nil then
					kind = nil -- the basket is not streamed in: nothing to stand over
				end
			end
			if kind ~= hook.kind or pick ~= shown then
				local field = Tier3Pointer.field(kind)
				if field ~= nil and kind ~= hook.kind and logged < Tier3Pointer.LOG_MAX then
					logged += 1
					Net.fire("TelemetryReport", Tier3Pointer.REPORT, field)
				end
				local captionChanged = kind ~= hook.kind
				hook.kind = kind
				hook.caption = Tier3Pointer.caption(kind)
				shown = pick
				draw(kind, pick)
				if captionChanged then
					hook.changed:Fire()
				end
			end
			task.wait(Tier3Pointer.POLL)
		end
	end)
end

return Tier3PointerController
