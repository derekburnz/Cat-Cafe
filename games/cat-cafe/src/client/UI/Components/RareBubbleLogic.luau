--!strict
-- #4227 (Derek 2026-11-14, from a player's suggestion): how many wild Mythical and Secret cats are out in each area
-- now, for the bubbles on the Cat Cannon picker's area cards and the HUD's Cannon button (Components/RareBubbles).
-- The server keeps the ReplicatedStorage attribute shared/AreaRares.ATTRIBUTE (CatService); this reads it back
-- through AreaRares, so the client and the server share one shape.
--   decode(raw) -> { [areaId]: Counts }       a bad or missing value is an empty map; bad counts are 0
--   fromData(table) -> { [areaId]: Counts }   the same from an already decoded table (specs, the UI gate)
--   counts(map, areaId) -> Counts             one area's, 0 and 0 when it has none
--   totals(map, open) -> Counts               every area in `open` added up (the Cannon button)
--   text(count) -> string                     "3", "9+" past MAX

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaRares = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AreaRares"))

export type Counts = { m: number, s: number }

local RareBubbleLogic = {}

RareBubbleLogic.ATTRIBUTE = AreaRares.ATTRIBUTE
RareBubbleLogic.MAX = 9

function RareBubbleLogic.fromData(data: unknown): { [string]: Counts }
	return AreaRares.decode("table", function(): unknown
		return data
	end)
end

function RareBubbleLogic.decode(raw: unknown): { [string]: Counts }
	return AreaRares.decode(raw, function(text: string): unknown
		return HttpService:JSONDecode(text)
	end)
end

function RareBubbleLogic.counts(map: { [string]: Counts }, areaId: string): Counts
	local found = map[areaId]
	return if found ~= nil then found else { m = 0, s = 0 }
end

function RareBubbleLogic.totals(map: { [string]: Counts }, open: { [string]: boolean }): Counts
	local m, s = AreaRares.totals(map, open)
	return { m = m, s = s }
end

function RareBubbleLogic.text(count: number): string
	return if count > RareBubbleLogic.MAX
		then tostring(RareBubbleLogic.MAX) .. "+"
		else tostring(count)
end

return RareBubbleLogic
