--!strict
-- The stray waiting for your second cat (#3022, Derek2 2026-11-10: "make it obvious to go catch second cat"). From
-- the first customer served until the second catch, the server keeps one alley stray waiting for each new player,
-- its number attribute `WaitsFor` set to that player's UserId (shared/SecondCat, #3038). On that player's screen only,
-- a column of gold sparkles rises off it and a gold ring pulses out at its feet every few seconds, so it stands out
-- from across the alley where UI's GuideTrail leads. It starts `delay` seconds after the cat first shows and stops
-- after `seconds` (SecondCat's TRAIL_DELAY_SECONDS and TRAIL_SECONDS when present), or when it is caught or gone.
-- Reduce Motion keeps the sparkles without the rings; Low performance keeps the rings only. Listening only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local WaitingCat = {}

local started = false
local cat: Model? = nil
local seenAt = 0
local ringAt = 0
local anchor: Attachment? = nil
local emitter: ParticleEmitter? = nil

-- SecondCat's attribute name and timings, if that module is in, else Presets.waitingCat's.
local function rules(): (string, number, number)
	local p = Presets.waitingCat
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = if shared ~= nil then shared:FindFirstChild("SecondCat") else nil
	if module ~= nil and module:IsA("ModuleScript") then
		local ok, found = pcall(require, module)
		if ok and type(found) == "table" then
			local s = found :: any
			local attribute = if type(s.ATTRIBUTE) == "string" then s.ATTRIBUTE else p.attribute
			local delay = if type(s.TRAIL_DELAY_SECONDS) == "number"
				then s.TRAIL_DELAY_SECONDS
				else p.delay
			local seconds = if type(s.TRAIL_SECONDS) == "number" then s.TRAIL_SECONDS else p.seconds
			return attribute, delay, seconds
		end
	end
	return p.attribute, p.delay, p.seconds
end

local function drop()
	local made = anchor
	if made ~= nil then
		made:Destroy()
	end
	anchor, emitter = nil, nil
end

-- This player's waiting stray in the world, if any.
local function find(attribute: string): Model?
	local me = Players.LocalPlayer.UserId
	for _, instance in CollectionService:GetTagged("Stray") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute(attribute) == me
			and instance:FindFirstChildWhichIsA("BasePart", true) ~= nil
		then
			return instance :: Model
		end
	end
	return nil
end

local function step()
	local p = Presets.waitingCat
	local attribute, delay, seconds = rules()
	local found = find(attribute)
	if found ~= cat then
		drop()
		cat = found
		seenAt = os.clock()
	end
	local model = cat
	if model == nil then
		return
	end
	local age = os.clock() - seenAt
	local frame, size = model:GetBoundingBox()
	local feet = frame.Position - Vector3.new(0, size.Y / 2 - 0.1, 0)
	if age < delay or age > delay + seconds or Context.distance(feet) > p.within then
		drop()
		return
	end
	if not Context.lowPerformance then
		local made: Attachment? = anchor
		if made == nil then
			local fresh = Particles.anchor("WaitingCat", feet)
			anchor, emitter = fresh, Particles.attach(p.emitter, fresh)
		else
			made.Position = feet
		end
		local glow = emitter
		if glow ~= nil then
			Particles.switchOn(glow, p.emitter)
		end
	else
		drop()
	end
	if os.clock() - ringAt >= p.ringEvery then
		ringAt = os.clock()
		Particles.ring(feet, Presets.palette.golden, p.ring, p.ringSeconds) -- none with Reduce Motion
	end
end

function WaitingCat.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			step()
			task.wait(Presets.waitingCat.check)
		end
	end)
end

return WaitingCat
