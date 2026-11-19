--!strict
-- #5502 the advent calendar (shared/Advent, advent-calendar-spec.md). OpenAdventDoor() (no arguments, one a second)
-- opens the player's next door when the server says so: both switches on (adventCalendar and christmasEvent), the
-- server's own UTC clock past that door's date and before Jan 4 2027, doors in order, and today's catch-ups left.
-- The door is marked in the save before anything is paid, so a failure inside the payout never pays it twice, and the
-- save field moves with the player to any server. Prizes go through Payout (Snowflakes into profile.snowflakes); a cat
-- door adds its calendar cat like a spin cat (the cafe full: it waits in the cat room). Every call, opened or not,
-- answers with ProfileSync, so the board never drifts. Nothing here can be bought, sped up or skipped.
-- Studio only: Debug can move this server's calendar clock (AdventService.setStudioOffset) to walk the dates; a live
-- server always reads os.time().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Advent = require(ReplicatedStorage.Shared.Advent)
local CafeService = require(script.Parent.CafeService)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local DataService = require(script.Parent.DataService)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local Telemetry = require(script.Parent.Telemetry)

local AdventService = {}

local studioOffset = 0

-- The calendar's clock: the server's UTC time, moved only in Studio.
function AdventService.now(): number
	return os.time() + (if RunService:IsStudio() then studioOffset else 0)
end

function AdventService.setStudioOffset(seconds: number)
	if RunService:IsStudio() then
		studioOffset = seconds
	end
end

local function ageBucket(firstDay: number, now: number): string
	local days = now // Advent.DAY_SECONDS - firstDay
	return if days <= 0 then "first_day" elseif days < 7 then "first_week" else "older"
end

local function onOpen(player: Player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local now = AdventService.now()
	local state = Advent.fresh(profile.advent)
	local door, kind = Advent.check(
		state,
		now,
		LiveFlagService.on(Advent.FLAG),
		LiveFlagService.on(Advent.EVENT_FLAG)
	)
	if door == nil or kind == nil then
		CafeService.sync(player)
		return
	end
	local def = Advent.door(door)
	if def == nil then
		CafeService.sync(player)
		return
	end
	Advent.mark(state, door, kind :: any, now)
	profile.advent = state
	local words: { string } = {}
	local catId = def.cat
	local catDef = if catId ~= nil then Catalog.getCat(catId) else nil
	if catDef ~= nil then
		local cat = catDef :: any
		local instance, isNew =
			CafeService.addCaughtCat(player, cat, false, profile, nil, "bait", nil)
		table.insert(words, cat.name)
		task.delay(0.5, function() -- after the door's toast and sync, the new cat card
			if player.Parent == Players then
				Net.fire(player, "CatCaught", cat.id, isNew, instance.variant, "advent")
			end
		end)
	end
	if def.prize ~= nil then
		for _, line in Payout.pay(player, profile, table.clone(def.prize :: any), Advent.REASON) do
			table.insert(words, line)
		end
	end
	Telemetry.custom(player, "advent_door", door, {
		kind,
		Telemetry.device(player) or "unknown",
		ageBucket(profile.telemetry.firstDay, now),
	})
	CafeService.sync(player)
	Net.toast(player, string.format("Door %d! %s", door, table.concat(words, ", ")), "good")
end

function AdventService.start()
	Net.on("OpenAdventDoor", onOpen)
end

return AdventService
