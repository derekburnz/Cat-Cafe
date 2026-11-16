--!strict
-- Bowl Frenzy at your bait bowl (#4195, admin events): while a Bowl Frenzy runs (ReplicatedStorage's AdminEvent*
-- attributes with `bowlSpeed` over 1, Effects/AdminEventLogic) and food is in one of your bowls with its cat still on
-- the way, gold sparkles pop off the food every `every` seconds and every `ringEvery`th pop a small gold ring spreads
-- from the bowl, so the bowl you baited reads as working faster. The bowl's own timer (UI's BaitBowl) already counts
-- down at the frenzy's speed; this is only the world side.
--
-- The bowls are CafeService's: the Bait and Bait2 folders of your plot (tag Plot, OwnerUserId), with a `Food` model
-- while a cat is on its way and a `Cat` once it has come. Only within `within` studs of your view. Low performance:
-- a pop every `lowEvery` seconds, fewer sparkles, no ring; Reduce Motion: no ring (Particles.ring). Listening only.
-- Numbers in Presets.bowlFrenzy.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AdminEventLogic = require(script.Parent.AdminEventLogic)
local Context = require(script.Parent.Context)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local BowlFrenzyFx = {}

local started = false
local since = math.huge -- seconds since the last pop, so the first comes at once
local popped = 0

-- Whether a bowl pops: a frenzy is on and the bowl has food with its cat still on the way.
function BowlFrenzyFx.pops(frenzy: boolean, hasFood: boolean, hasCat: boolean): boolean
	return frenzy and hasFood and not hasCat
end

-- Seconds between pops: `every`, or `lowEvery` in Low performance.
function BowlFrenzyFx.gap(low: boolean, every: number, lowEvery: number): number
	return if low then lowEvery else every
end

-- Whether pop number `n` (from 1) also spreads a ring: every `ringEvery`th, never in Low performance.
function BowlFrenzyFx.rings(n: number, ringEvery: number, low: boolean): boolean
	return not low and ringEvery >= 1 and n % ringEvery == 0
end

local function decode(json: string): any
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok then data else nil
end

local function frenzyOn(): boolean
	local view = AdminEventLogic.read(function(name: string): any
		return ReplicatedStorage:GetAttribute(name)
	end, decode)
	return view ~= nil
		and view.bowlSpeed > 1
		and AdminEventLogic.runs(view, Workspace:GetServerTimeNow())
end

local function ownPlot(): Instance?
	for _, instance in CollectionService:GetTagged("Plot") do
		if
			instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		then
			return instance
		end
	end
	return nil
end

-- Where the food is in each of your bowls that pops (two at most).
local function foods(plot: Instance): { Vector3 }
	local out: { Vector3 } = {}
	for _, name in Presets.bowlFrenzy.folders do
		local folder = plot:FindFirstChild(name)
		local food = if folder ~= nil then folder:FindFirstChild("Food") else nil
		local hasCat = folder ~= nil and folder:FindFirstChild("Cat") ~= nil
		if food ~= nil and food:IsA("Model") and BowlFrenzyFx.pops(true, true, hasCat) then
			table.insert(out, (food :: Model):GetPivot().Position)
		end
	end
	return out
end

local function tick(dt: number)
	local p = Presets.bowlFrenzy
	since += dt
	local low = Context.lowPerformance
	if since < BowlFrenzyFx.gap(low, p.every, p.lowEvery) then
		return
	end
	if not frenzyOn() then
		popped = 0
		return
	end
	local plot = ownPlot()
	if plot == nil then
		return
	end
	local spots = foods(plot)
	if #spots == 0 then
		return
	end
	since = 0
	popped += 1
	local ring = BowlFrenzyFx.rings(popped, p.ringEvery, low)
	for _, at in spots do
		if Context.distance(at) <= p.within then
			local count = if low then p.lowCount else p.count
			Particles.burst(p.preset, at + Vector3.new(0, p.lift, 0), count, Presets.palette.golden)
			if ring then
				Particles.ring(at, Presets.palette.golden, p.ring)
			end
		end
	end
end

function BowlFrenzyFx.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local dt = task.wait(Presets.bowlFrenzy.check)
			tick(dt)
		end
	end)
end

return BowlFrenzyFx
