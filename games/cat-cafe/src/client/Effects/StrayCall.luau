--!strict
-- The waiting stray calls you over (#3022, Derek2 2026-11-10: "make it obvious to go catch second cat"; Gameplay's
-- read: most new players leave between the first customer and the second cat). On this player's screen only, the
-- stray the server keeps waiting for their second cat (number attribute `WaitsFor` = their UserId, shared/SecondCat)
-- does a "come here" every few seconds while they are within Presets.motion.beckon.near studs: a couple of small hops,
-- its head turned to them and tipped up, tail up and flicking (Logic.beckon, drawn by Cats). VFX-Agent's WaitingCat
-- draws the sparkles, rings and paw badge over the same cat. Off with Reduce Motion. Listening only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cats = require(script.Parent.Cats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local StrayCall = {}

local started = false
local lastAt = -math.huge

-- shared/SecondCat's attribute name when that module is in, else WaitingCat's preset.
local function attributeName(): string
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = if shared ~= nil then shared:FindFirstChild("SecondCat") else nil
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, found = pcall(require, module)
		if ok and type(found) == "table" and type((found :: any).ATTRIBUTE) == "string" then
			return (found :: any).ATTRIBUTE
		end
	end
	return Presets.waitingCat.attribute
end

-- The stray waiting for this player, if one is in the world.
local function find(attribute: string): Model?
	local me = Players.LocalPlayer.UserId
	for _, instance in CollectionService:GetTagged("Stray") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute(attribute) == me
		then
			return instance :: Model
		end
	end
	return nil
end

local function step(attribute: string)
	local b = Presets.motion.beckon
	local now = os.clock()
	if now - lastAt < b.every or Context.reducedMotion() then
		return
	end
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local cat = find(attribute)
	if cat == nil then
		return
	end
	local you = cat:GetPivot():PointToObjectSpace(focus)
	if Vector3.new(you.X, 0, you.Z).Magnitude > b.near then
		return
	end
	lastAt = now
	Cats.beckon(cat, Logic.lookYaw(you.X, you.Z, b.look))
end

function StrayCall.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local attribute = attributeName()
		while true do
			step(attribute)
			task.wait(Presets.motion.beckon.check)
		end
	end)
end

return StrayCall
