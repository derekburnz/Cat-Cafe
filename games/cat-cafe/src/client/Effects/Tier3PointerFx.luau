--!strict
-- #5715 (part of #5686), switch tier3Pointer: the look of the Tier 3 coins pointer. Gameplay-Engineer's controller
-- picks one target a second (shared/Tier3Pointer) and hands it here with Tier3PointerFx.point(kind, target):
--   "picnic"  the player's Picnic Basket station while it is ready: the gold arrow over the basket, and a soft gold
--             ring on the ground at its trigger (the station's PromptAnchor, else its pivot) that breathes every
--             `period` seconds. Low performance, the lite budget and Reduce Motion hold the ring still and fainter.
--   "cat"     a free Park cat: the same gold arrow as parkCatArrow (Effects/PointerArrow) over it.
--   nil       nothing.
-- On a tablet (Context.tablet) the arrow draws `tabletScale` times as big. Everything hides while the switch is off.
-- Client only, listening only: it sends nothing. Numbers in Presets.tier3Pointer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local PointerArrow = require(script.Parent.PointerArrow)
local Presets = require(script.Parent.Presets)

local Tier3PointerFx = {}

export type Kind = "picnic" | "cat"

local kind: Kind? = nil
local target: Instance? = nil
local arrow: BillboardGui? = nil
local arrowScale = 0
local arrowPart: BasePart? = nil
local arrowOver = PointerArrow.ABOVE
local ring: Part? = nil
local stepping: RBXScriptConnection? = nil

-- The arrow's size: `tabletScale` on a tablet, else 1. Pure.
function Tier3PointerFx.arrowScale(tablet: boolean, tabletScale: number): number
	return if tablet then tabletScale else 1
end

-- The ring's transparency at `t` seconds: a slow breath between `low` and `high` once every `period` seconds, held
-- at `still` when `calm` (Low performance, the lite budget or Reduce Motion). Pure.
function Tier3PointerFx.ringFade(
	t: number,
	period: number,
	low: number,
	high: number,
	calm: boolean,
	still: number
): number
	if calm or period <= 0 then
		return still
	end
	local k = 0.5 - 0.5 * math.cos(2 * math.pi * (t % period) / period) -- 0, up to 1, back to 0
	return high + (low - high) * k
end

local function on(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. Presets.tier3Pointer.flag) == true
end

local function calm(): boolean
	return Context.lowPerformance or Context.lite or Context.reducedMotion()
end

local function dropArrow()
	if arrow ~= nil then
		(arrow :: BillboardGui):Destroy()
	end
	arrow, arrowPart, arrowScale = nil, nil, 0
end

local function dropRing()
	if ring ~= nil then
		(ring :: Part):Destroy()
	end
	ring = nil
end

local function groundUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { Context.folder() }
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(skip, character)
	end
	if target ~= nil then
		table.insert(skip, target :: Instance)
	end
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return if hit ~= nil then hit.Position else at
end

-- Where the basket's trigger is: its PromptAnchor part, else the station's pivot.
local function triggerOf(station: Instance): Vector3?
	local anchor = station:FindFirstChild("PromptAnchor", true)
	if anchor ~= nil and anchor:IsA("BasePart") then
		return (anchor :: BasePart).Position
	end
	return Context.positionOf(station)
end

local function placeRing()
	local p = Presets.tier3Pointer
	local station = target
	local at = if station ~= nil then triggerOf(station) else nil
	if at == nil then
		dropRing()
		return
	end
	local existing = ring
	local made: Part
	if existing ~= nil then
		made = existing
	else
		made = Context.effectPart(
			"Tier3PointerRing",
			Vector3.new(p.ringThick, p.ringSize, p.ringSize),
			p.gold
		)
		made.Shape = Enum.PartType.Cylinder
		made.Material = Enum.Material.Neon
		made.Parent = Context.folder()
		ring = made
	end
	local ground = groundUnder(at :: Vector3)
	-- a cylinder's axis is its X: lay it flat
	made.CFrame = CFrame.new(ground + Vector3.new(0, p.ringLift, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
end

local function placeArrow()
	local p = Presets.tier3Pointer
	local model = target
	if model == nil or not model:IsA("Model") or model.Parent == nil then
		dropArrow()
		return
	end
	local scale = Tier3PointerFx.arrowScale(Context.tablet, p.tabletScale)
	if arrow == nil or arrowScale ~= scale then
		dropArrow()
		local made = PointerArrow.build("Tier3PointerArrow", scale, p.reach)
		made.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		arrow, arrowScale = made, scale
	end
	local part = PointerArrow.partOf(model :: Model)
	local made = arrow :: BillboardGui
	if part == nil then
		made.Enabled = false
		return
	end
	if arrowPart ~= part then
		arrowPart = part
		made.Adornee = part
	end
	arrowOver = PointerArrow.over(model :: Model, part :: BasePart)
	made.Enabled = true
end

local function step()
	local p = Presets.tier3Pointer
	if not on() or kind == nil or target == nil or (target :: Instance).Parent == nil then
		dropArrow()
		dropRing()
		return
	end
	local made = arrow
	if made ~= nil and made.Enabled then
		made.StudsOffsetWorldSpace =
			Vector3.new(0, arrowOver + PointerArrow.bob(os.clock(), Context.reducedMotion()), 0)
	end
	local glow = ring
	if glow ~= nil then
		glow.Transparency = Tier3PointerFx.ringFade(
			os.clock(),
			p.period,
			p.ringLow,
			p.ringHigh,
			calm(),
			p.ringStill
		)
	end
end

-- Points at `newTarget` for `newKind` ("picnic": the basket station, "cat": a stray Model), or hides with nil.
-- The controller calls it on every target change; calling it again with the same target only re-places.
function Tier3PointerFx.point(newKind: Kind?, newTarget: Instance?)
	if newKind == nil or newTarget == nil then
		kind, target = nil, nil
		dropArrow()
		dropRing()
		return
	end
	kind, target = newKind, newTarget
	placeArrow()
	if newKind == "picnic" then
		placeRing()
	else
		dropRing()
	end
	if stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

return Tier3PointerFx
