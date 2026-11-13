--!strict
-- #3955 (Derek 2026-11-13: "lost and found also needs changing it just doesnt do anything but walk on and give u smth
-- u cant even tell"): the words and rows of the Lost and Found's card (Screens/LostFound). Pure, so the specs read it.
--   LostFoundLogic.status(view, now)   the card's title, its line, the pill on the picture and whether Claim works:
--                                      "2 finds waiting" / "Claim to see what turned up" / "2 WAITING" / true
--   LostFoundLogic.button(view, now, pending)   the Claim button's words: "Claim 2", "Next find in 1 h 20 m", "..."
--   LostFoundLogic.rows()              what can turn up, from Config.LostFoundTable: each row's prize, the rarity of a
--                                      lost cat it brings (nil for none) and its chance as words ("30%")
--   LostFoundLogic.foundText(paid)     the reveal's banner from the server's paid lines: "25 golden fish"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CampExtras = require(Shared:WaitForChild("CampExtras")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any
local SharedTypes = require(Shared:WaitForChild("Types"))

local MarketLogic = require(script.Parent:WaitForChild("MarketLogic"))

local LostFoundLogic = {}

export type Row = {
	prize: SharedTypes.IndexPrize,
	lostCat: string?,
	chance: string,
}

function LostFoundLogic.status(
	view: SharedTypes.CampExtraView?,
	now: number
): (string, string, string, boolean)
	if view == nil or not view.open then
		return "Lost and Found", "Opens with the Sewer", "SHUT", false
	end
	local held = math.max(0, math.floor(view.held or 0))
	if held > 0 then
		local title = if held == 1
			then "1 find waiting"
			else string.format("%d finds waiting", held)
		return title, "Claim to see what turned up", string.format("%d WAITING", held), true
	end
	local line = if view.nextAt ~= nil
		then "Next find in " .. CampExtras.waitText(math.max(0, view.nextAt - now))
		else "Next find soon"
	return "Nothing found yet", line, "SOON", false
end

function LostFoundLogic.button(
	view: SharedTypes.CampExtraView?,
	now: number,
	pending: boolean
): string
	if pending then
		return "..."
	end
	local _, line, _, ready = LostFoundLogic.status(view, now)
	if not ready then
		return line
	end
	local held = if view ~= nil then math.floor(view.held or 0) else 0
	return if held > 1 then string.format("Claim %d", held) else "Claim"
end

function LostFoundLogic.rows(): { Row }
	local rows: { Row } = {}
	local total = 0
	for _, row in Config.LostFoundTable do
		-- the prize of this row, read through the shared table's own roll (the middle of the row's share)
		local prize, lostCat = CampExtras.lostFoundPrize(total + row.chance / 2)
		total += row.chance
		table.insert(
			rows,
			{ prize = prize, lostCat = lostCat, chance = MarketLogic.percent(row.chance * 100) }
		)
	end
	return rows
end

function LostFoundLogic.foundText(paid: { string }?): string
	if type(paid) ~= "table" or #paid == 0 then
		return "Something turned up!"
	end
	return table.concat(paid, ", ")
end

return LostFoundLogic
