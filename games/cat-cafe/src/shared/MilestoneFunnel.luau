--!strict
-- #5291 (part of #5285 E5): milestones_v1, a progression funnel to find the early wall. One run per account (the user
-- id is its funnel session), like playtime_v1. Each step is logged the first time it is reached and never again, with
-- two custom fields: the account's play minutes at that moment (as a minute mark, `minuteMark`) and the device. A step
-- reached before an earlier one is logged when it happens, so the report counts players per step and the minutes
-- field shows the order.
--
-- Only accounts that start on it are in: a save is seen first by Telemetry with ENTRY_SECONDS of play or less, or it
-- is out for good (mask OUT). The save keeps the steps logged as a bit mask (telemetry.milestoneMask), so a rejoin
-- never logs a step twice. Behind `milestoneFunnel` (LiveFlags.OFF_BY_DEFAULT): off, nothing is logged and no save
-- changes. It uses the funnel API (AnalyticsService:LogFunnelStepEvent), not custom events, so the custom event cap
-- is untouched.
--
-- Pure: Telemetry calls `reached` with the save (and the area step from the cannon's arrival event), `due` for what
-- to log, and `mark` after logging.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local Onboarding = require(script.Parent.Onboarding)
local Types = require(script.Parent.Types)

local MilestoneFunnel = {}

MilestoneFunnel.NAME = "milestones_v1"
MilestoneFunnel.FLAG = "milestoneFunnel"
MilestoneFunnel.ENTRY_SECONDS = 120 -- an account first seen with more play than this stays out
MilestoneFunnel.OUT = -1 -- the mask of a save that is not in the funnel

-- The step number is the index. Names never change once shipped. The issue's "Net 2, Net 3, Net 4" are the net's
-- first three buys here: upgrade level 1 (2,500), 2 (200,000 at Tier 3) and 3 (Tier 5), named by level.
MilestoneFunnel.STEPS = table.freeze({
	"joined",
	"first_catch", -- the onboarding ledger's first_catch (a net catch)
	"first_checkin", -- a cat working in the cafe (the ledger's first_checkin)
	"first_bowl_fill", -- food put in the bait bowl (the ledger's first_bait)
	"net_1", -- the first net upgrade
	"first_station_upgrade", -- the first buy of a cafe station: a table or the espresso machine past the start
	"first_rank_up", -- Tier 2
	"second_area_entered", -- the first landing in an area after the Alleyway (the Park or later)
	"net_2",
	"companion_picked", -- a Cat Companion chosen (follower.uid set, Tier 2 and up)
	"tier_3",
	"net_3",
})
MilestoneFunnel.COUNT = #MilestoneFunnel.STEPS
MilestoneFunnel.AREA_STEP = table.find(MilestoneFunnel.STEPS, "second_area_entered") :: number
MilestoneFunnel.FULL = bit32.lshift(1, MilestoneFunnel.COUNT) - 1

-- The cafe stations whose first buy past their start level is first_station_upgrade.
MilestoneFunnel.STATIONS = table.freeze({ "tables", "espresso" })

-- The areas after the Alleyway (cannon arrival events, Onboarding.arrivedEvent).
local LATER = table.freeze({
	"park",
	"neighbourhood",
	"woods",
	"sewer",
	"desert",
	"ruins",
	"snowy",
	"waterpark",
	"castle",
})

-- Whether a cannon arrival event (Onboarding.arrivedEvent) is a landing in an area after the Alleyway.
function MilestoneFunnel.isLaterArrival(event: string): boolean
	for _, area in LATER do
		if event == Onboarding.arrivedEvent(area) then
			return true
		end
	end
	return false
end

-- A save's mask from anything: a whole number from OUT to FULL, nil for none (Telemetry then decides on entry).
function MilestoneFunnel.sanitize(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw then
		return nil
	end
	local n = math.floor(raw)
	if n < 0 then
		return MilestoneFunnel.OUT
	end
	return math.min(n, MilestoneFunnel.FULL)
end

-- The mask for a save seen for the first time: in (0) with ENTRY_SECONDS of play or less, OUT after.
function MilestoneFunnel.entry(playSeconds: number): number
	return if playSeconds <= MilestoneFunnel.ENTRY_SECONDS then 0 else MilestoneFunnel.OUT
end

function MilestoneFunnel.has(mask: number, step: number): boolean
	return mask >= 0 and bit32.btest(mask, bit32.lshift(1, step - 1))
end

function MilestoneFunnel.mark(mask: number, step: number): number
	if mask < 0 then
		return mask
	end
	return bit32.bor(mask, bit32.lshift(1, step - 1))
end

local function stationBought(profile: Types.PlayerProfile): boolean
	for _, id in MilestoneFunnel.STATIONS do
		local level = profile.upgradeLevels[id]
		if level ~= nil then
			local def = Catalog.getUpgrade(id)
			local start = if def ~= nil then def.startLevel else 0
			if id == "tables" then
				start = math.max(start, Config.StartTables) -- #3660: a new save opens with its first table
			end
			if level > start then
				return true
			end
		end
	end
	return false
end

-- The steps the save has reached (step -> true). The area step comes from `arrivedLater` (a landing seen this call)
-- or the ledger's first_park_catch (a Park catch means the Park was entered).
function MilestoneFunnel.reached(
	profile: Types.PlayerProfile,
	arrivedLater: boolean?
): { [number]: boolean }
	local state = profile.telemetry
	local tier = Economy.tier(profile)
	local net = Economy.level(profile, "net")
	local follower = profile.follower
	local picked = follower ~= nil and follower.uid ~= ""
	local out: { [number]: boolean } = {}
	local function set(name: string, yes: boolean)
		if yes then
			out[table.find(MilestoneFunnel.STEPS, name) :: number] = true
		end
	end
	set("joined", true)
	set("first_catch", Onboarding.reached(state, "first_catch"))
	set("first_checkin", Onboarding.reached(state, "first_checkin"))
	set("first_bowl_fill", Onboarding.reached(state, "first_bait"))
	set("net_1", net >= 1)
	set("first_station_upgrade", stationBought(profile))
	set("first_rank_up", tier >= 2)
	set(
		"second_area_entered",
		arrivedLater == true or Onboarding.reached(state, "first_park_catch")
	)
	set("net_2", net >= 2)
	set("companion_picked", picked)
	set("tier_3", tier >= 3)
	set("net_3", net >= 3)
	return out
end

-- The steps to log now, in step order: reached and not yet in the mask. None for a save that is out.
function MilestoneFunnel.due(mask: number, reached: { [number]: boolean }): { number }
	local out = {}
	if mask < 0 then
		return out
	end
	for step = 1, MilestoneFunnel.COUNT do
		if reached[step] and not MilestoneFunnel.has(mask, step) then
			table.insert(out, step)
		end
	end
	return out
end

-- The minutes field: whole minutes to 60, then 5 minute marks to 180, then "180+", so the field stays a short list
-- and the report can still read the median minute.
function MilestoneFunnel.minuteMark(playSeconds: number): string
	local minutes = math.max(0, math.floor(playSeconds / 60))
	if minutes < 60 then
		return tostring(minutes)
	elseif minutes < 180 then
		return tostring(minutes - minutes % 5)
	end
	return "180+"
end

return MilestoneFunnel
