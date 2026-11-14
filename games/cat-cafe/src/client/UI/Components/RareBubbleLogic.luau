--!strict
-- #4227 (Derek 2026-11-14, from a player's suggestion): how many wild Mythical and Secret cats are out in each area
-- now, for the bubbles on the Cat Cannon picker's area cards and the HUD's Cannon button (Components/RareBubbles).
-- The server keeps the ReplicatedStorage attribute ATTRIBUTE, JSON { [areaId] = { m = mythicals, s = secrets } }.
-- Pure: no Theme, so the cloud spec runner can load it.
--   decode(raw) -> { [areaId]: Counts }       a bad or missing value is an empty map; bad counts are 0
--   fromData(table) -> { [areaId]: Counts }   the same from the decoded table
--   counts(map, areaId) -> Counts             one area's, 0 and 0 when it has none
--   totals(map, open) -> Counts               every area in `open` added up (the Cannon button)
--   text(count) -> string                     "3", "9+" past MAX

local HttpService = game:GetService("HttpService")

export type Counts = { m: number, s: number }

local RareBubbleLogic = {}

RareBubbleLogic.ATTRIBUTE = "AreaRares"
RareBubbleLogic.MAX = 9

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value < 0 then
		return 0
	end
	return math.floor(value)
end

-- The decoded table (pure, so the cloud runner can test it: it has no HttpService).
function RareBubbleLogic.fromData(data: unknown): { [string]: Counts }
	local out: { [string]: Counts } = {}
	if type(data) ~= "table" then
		return out
	end
	for areaId, row in data :: { [any]: any } do
		if type(areaId) == "string" and type(row) == "table" then
			local counts = { m = whole(row.m), s = whole(row.s) }
			if counts.m > 0 or counts.s > 0 then
				out[areaId] = counts
			end
		end
	end
	return out
end

function RareBubbleLogic.decode(raw: unknown): { [string]: Counts }
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return RareBubbleLogic.fromData(if ok then data else nil)
end

function RareBubbleLogic.counts(map: { [string]: Counts }, areaId: string): Counts
	local found = map[areaId]
	return if found ~= nil then found else { m = 0, s = 0 }
end

function RareBubbleLogic.totals(map: { [string]: Counts }, open: { [string]: boolean }): Counts
	local m, s = 0, 0
	for areaId, counts in map do
		if open[areaId] then
			m += counts.m
			s += counts.s
		end
	end
	return { m = m, s = s }
end

function RareBubbleLogic.text(count: number): string
	return if count > RareBubbleLogic.MAX
		then tostring(RareBubbleLogic.MAX) .. "+"
		else tostring(count)
end

return RareBubbleLogic
