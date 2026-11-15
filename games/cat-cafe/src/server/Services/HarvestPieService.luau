--!strict
-- #4251 Harvest Hollow, the Feast Pie (harvest-hollow-spec section 5): every harvest cat caught in any server adds one
-- to one shared count. Each server adds its own catches up and folds them into a MemoryStore HashMap every
-- PUSH_SECONDS (one UpdateAsync with the sum, so the count is never faked or pushed down), and reads the total back.
--   ReplicatedStorage attributes for the Thankful Board: HarvestPieCount (the all-servers count), HarvestPieGoal
--   (HarvestSave.pieGoal, the harvestPieLow switch read live) and HarvestPieSlices (0 to 8).
--   A slice baked since this server's last read toasts everyone here (not in a quiet start): "The Feast Pie is 3/8 baked!" (the first read
--   in a server only sets the mark, so a new server does not toast old slices).
--   HarvestPieService.add(n): catches to count (HarvestService.caught).
-- Runs from the area's build time until PIE_SHOW_DAYS after it closes, so the board keeps its full pie for a while.
-- A push that fails keeps the catches for the next one. The reward when the pie is full is the next part.
--
-- Roblox terms: MemoryStore is a fast store shared by every server of the experience; an item lives at most 45 days
-- (EXPIRY_SECONDS keeps it past the close), and UpdateAsync changes it in one step even with many servers at once.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HarvestHollow = require(ReplicatedStorage.Shared.HarvestHollow)
local HarvestSave = require(ReplicatedStorage.Shared.HarvestSave)

local LiveFlagService = require(script.Parent.LiveFlagService)
local QuietStartService = require(script.Parent.QuietStartService)

local HarvestPieService = {}

local MAP = if RunService:IsStudio() then "HarvestPie2026_dev" else "HarvestPie2026"
local KEY = "count"
local PUSH_SECONDS = 30
local EARLY_SECONDS = 3600 -- as HarvestWorld.AREA_EARLY_SECONDS
local PIE_SHOW_DAYS = 7
local EXPIRY_SECONDS = 40 * 86400

local pending = 0
local count = 0
local markSlices: number? = nil -- the slices at this server's last read (nil before the first)

function HarvestPieService.add(n: number)
	if n > 0 and n == math.floor(n) then
		pending += n
	end
end

function HarvestPieService.count(): number
	return count
end

local function publish()
	local goal = HarvestSave.pieGoal(LiveFlagService.on(HarvestSave.PIE_LOW_FLAG))
	local slices = HarvestSave.pieSlices(count, goal)
	ReplicatedStorage:SetAttribute("HarvestPieCount", count)
	ReplicatedStorage:SetAttribute("HarvestPieGoal", goal)
	ReplicatedStorage:SetAttribute("HarvestPieSlices", slices)
	if markSlices ~= nil and slices > markSlices and slices > 0 then
		-- not to players in their quiet first minutes (#4005)
		QuietStartService.fireAll(
			nil,
			"Toast",
			string.format("The Feast Pie is %d/%d baked!", slices, HarvestSave.PIE_SLICES),
			"good"
		)
	end
	markSlices = slices
end

-- One push and read: the catches since the last push go in with the total; with none, the total is read.
local function sync()
	local map = MemoryStoreService:GetHashMap(MAP)
	local adding = pending
	local ok, result = pcall(function(): any
		if adding > 0 then
			return map:UpdateAsync(KEY, function(old: any): any
				local before = if type(old) == "number" and old == old and old >= 0 then old else 0
				return math.floor(before) + adding
			end, EXPIRY_SECONDS)
		end
		return map:GetAsync(KEY)
	end)
	if not ok then
		warn("[HarvestPie] sync failed, keeping " .. adding .. " to push: " .. tostring(result))
		return
	end
	pending -= adding
	if type(result) == "number" and result == result and result >= count then
		count = math.floor(result)
	end
	publish()
end

function HarvestPieService.start()
	local from = HarvestHollow.OPENS_AT - EARLY_SECONDS
	local untilAt = HarvestHollow.CLOSES_AT + PIE_SHOW_DAYS * 86400
	if os.time() >= untilAt then
		return
	end
	task.delay(math.max(0, from - os.time()), function()
		while os.time() < untilAt do
			sync()
			task.wait(PUSH_SECONDS)
		end
	end)
end

return HarvestPieService
